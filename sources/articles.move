module articles::articles {
    use std::string::{String, concat};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance, zero};
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::vector;
    use sui::error;
    use sui::transfer::{Self, transfer, public_transfer};
    use sui::address::address;
    use sui::math::{Self, abs};

    /// Error codes for the Articles module
    const E_AMOUNT_MUST_BE_GREATER_THAN_ZERO: u64 = 1;
    const E_ONLY_OWNER_CAN_DELETE_ARTICLE: u64 = 2;
    const E_NOT_OWNER: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_ARTICLE_NOT_FOUND: u64 = 5;
    const E_ALREADY_LIKED: u64 = 6;
    const E_ALREADY_DISLIKED: u64 = 7;
    const E_INVALID_AMOUNT: u64 = 8;

    /// Struct representing an Article
    public struct Article has key, store {
        id: UID,
        owner: address,
        title: String,
        content: String,
        timestamp: u64,
        likes: vector<address>,
        dislikes: vector<address>,
        amount_donated: Balance<SUI>,
        comments: vector<String>,
    }

    /// Table to store all articles with their IDs
    struct ArticlesTable has key, store {
        articles: Table<u64, Article>,
        counter: u64, // Auto-incrementing counter for article IDs
    }

    /// Events emitted by the Articles module
    public struct ArticleCreated has copy, drop {
        article_id: u64,
        owner: address,
        title: String,
        timestamp: u64,
    }

    public struct DonationReceived has copy, drop {
        article_id: u64,
        donor: address,
        amount: u64,
        timestamp: u64,
    }

    public struct FundsWithdrawn has copy, drop {
        article_id: u64,
        owner: address,
        amount: u64,
        recipient: address,
        timestamp: u64,
    }

    public struct ArticleDeleted has copy, drop {
        article_id: u64,
        owner: address,
        timestamp: u64,
    }

    public struct ArticleLiked has copy, drop {
        article_id: u64,
        user: address,
        timestamp: u64,
    }

    public struct ArticleDisliked has copy, drop {
        article_id: u64,
        user: address,
        timestamp: u64,
    }

    public struct CommentAdded has copy, drop {
        article_id: u64,
        user: address,
        comment: String,
        timestamp: u64,
    }

    /// Initializes the ArticlesTable. This should be called once during deployment.
    public entry fun init(ctx: &mut TxContext) {
        let articles_table = ArticlesTable {
            articles: Table::new(ctx),
            counter: 0,
        };
        transfer::share_object(articles_table);
    }

    /// Creates a new article and adds it to the ArticlesTable
    public entry fun create_article(
        articles_table: &mut ArticlesTable,
        title: String,
        content: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let timestamp = clock::now_ms(clock);

        let article_id = articles_table.counter;
        articles_table.counter = articles_table.counter + 1;

        let article = Article {
            id: object::new(ctx),
            owner: sender,
            title: title.clone(),
            content: content.clone(),
            timestamp,
            likes: vector::empty(),
            dislikes: vector::empty(),
            amount_donated: balance::zero<SUI>(),
            comments: vector::empty(),
        };

        Table::add(&mut articles_table.articles, article_id, article);

        event::emit(ArticleCreated {
            article_id,
            owner: sender,
            title,
            timestamp,
        });
    }

    /// Allows users to donate SUI to an article
    public entry fun donate(
        articles_table: &mut ArticlesTable,
        article_id: u64,
        amount: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let donor = tx_context::sender(ctx);
        let timestamp = clock::now_ms(clock);
        let donation_amount = coin::value(&amount);

        assert!(donation_amount > 0, error::invalid_argument(E_AMOUNT_MUST_BE_GREATER_THAN_ZERO));

        let article = Table::borrow_mut(&mut articles_table.articles, &article_id);
        assert!(article != &mut nil(), error::not_found(E_ARTICLE_NOT_FOUND));

        let coin_balance = coin::into_balance(amount);
        balance::join(&mut article.amount_donated, coin_balance);

        event::emit(DonationReceived {
            article_id,
            donor,
            amount: donation_amount,
            timestamp,
        });
    }

    /// Allows article owners to withdraw donated funds
    public entry fun withdraw_funds(
        articles_table: &mut ArticlesTable,
        article_id: u64,
        amount: u64,
        recipient: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let timestamp = clock::now_ms(clock);

        let article = Table::borrow_mut(&mut articles_table.articles, &article_id);
        assert!(article != &mut nil(), error::not_found(E_ARTICLE_NOT_FOUND));
        assert!(article.owner == sender, error::permission_denied(E_NOT_OWNER));
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));

        let available_balance = balance::value(&article.amount_donated);
        assert!(available_balance >= amount, error::insufficient_balance(E_INSUFFICIENT_BALANCE));

        let withdrawn_coin = balance::take(&mut article.amount_donated, amount, ctx);
        public_transfer(withdrawn_coin, recipient);

        event::emit(FundsWithdrawn {
            article_id,
            owner: sender,
            amount,
            recipient,
            timestamp,
        });
    }

    /// Allows article owners to delete their articles
    public entry fun delete_article(
        articles_table: &mut ArticlesTable,
        article_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let timestamp = clock::now_ms(clock);

        let article = Table::borrow_mut(&mut articles_table.articles, &article_id);
        assert!(article != &mut nil(), error::not_found(E_ARTICLE_NOT_FOUND));
        assert!(article.owner == sender, error::permission_denied(E_ONLY_OWNER_CAN_DELETE_ARTICLE));

        // Refund any remaining donations back to the owner
        let remaining_balance = balance::value(&article.amount_donated);
        if remaining_balance > 0 {
            let refund_coin = balance::take(&mut article.amount_donated, remaining_balance, ctx);
            public_transfer(refund_coin, sender);
        }

        Table::remove(&mut articles_table.articles, &article_id);

        event::emit(ArticleDeleted {
            article_id,
            owner: sender,
            timestamp,
        });
    }

    /// Retrieves an article by its ID
    public fun get_article(articles_table: &ArticlesTable, article_id: u64): &Article {
        let article = Table::borrow(&articles_table.articles, &article_id);
        assert!(article != &nil(), error::not_found(E_ARTICLE_NOT_FOUND));
        article
    }

    /// Retrieves all articles
    public fun get_all_articles(articles_table: &ArticlesTable): vector<Article> {
        Table::values(&articles_table.articles)
    }

    /// Adds a like to an article
    public entry fun like_article(
        articles_table: &mut ArticlesTable,
        article_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let timestamp = clock::now_ms(clock);

        let article = Table::borrow_mut(&mut articles_table.articles, &article_id);
        assert!(article != &mut nil(), error::not_found(E_ARTICLE_NOT_FOUND));

        // Check if user already liked the article
        for addr in &article.likes {
            assert!(*addr != user, error::invalid_argument(E_ALREADY_LIKED));
        }

        // Remove dislike if present
        let mut new_dislikes = vector::empty<address>();
        for addr in &article.dislikes {
            if *addr != user {
                vector::push_back(&mut new_dislikes, *addr);
            }
        }
        article.dislikes = new_dislikes;

        vector::push_back(&mut article.likes, user);

        event::emit(ArticleLiked {
            article_id,
            user,
            timestamp,
        });
    }

    /// Adds a dislike to an article
    public entry fun dislike_article(
        articles_table: &mut ArticlesTable,
        article_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let timestamp = clock::now_ms(clock);

        let article = Table::borrow_mut(&mut articles_table.articles, &article_id);
        assert!(article != &mut nil(), error::not_found(E_ARTICLE_NOT_FOUND));

        // Check if user already disliked the article
        for addr in &article.dislikes {
            assert!(*addr != user, error::invalid_argument(E_ALREADY_DISLIKED));
        }

        // Remove like if present
        let mut new_likes = vector::empty<address>();
        for addr in &article.likes {
            if *addr != user {
                vector::push_back(&mut new_likes, *addr);
            }
        }
        article.likes = new_likes;

        vector::push_back(&mut article.dislikes, user);

        event::emit(ArticleDisliked {
            article_id,
            user,
            timestamp,
        });
    }

    /// Adds a comment to an article
    public entry fun add_comment(
        articles_table: &mut ArticlesTable,
        article_id: u64,
        comment: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let timestamp = clock::now_ms(clock);

        let article = Table::borrow_mut(&mut articles_table.articles, &article_id);
        assert!(article != &mut nil(), error::not_found(E_ARTICLE_NOT_FOUND));

        let formatted_comment = concat(user.to_string(), concat(": ", comment));

        vector::push_back(&mut article.comments, formatted_comment.clone());

        event::emit(CommentAdded {
            article_id,
            user,
            comment: formatted_comment,
            timestamp,
        });
    }
}
