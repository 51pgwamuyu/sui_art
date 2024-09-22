
module articles::articles {
use std::string::{String};
use sui::coin::{Coin, Self,take};
use sui::balance::{Balance, Self, zero};
use sui::sui::SUI;
//
//use sui::object::{Self, UID};
//use sui::clock::Clock;
use sui::event;
//use std::vec::Vec;

//define errors
const EAmountMustBeGreaterThanOne:u64=1;
const EOnlyOwnerCanDeleteArticle:u64=2;
const ENotOwner:u64=3;
const EArticleNotAvailable:u64=5;
const Error_Invalid_WithdrawalAmount:u64=6;
//struct for articles
public struct Article has store{
    id:u64,
    owner:String,
    nameofarticle:String,
    title:String,
    description:String,
    likes:vector<address>,
    dislikes:vector<address>,
    comments:vector<String>,
   
}
public struct BlogSite has key,store{

    id: UID,
    usercap:ID,
    name:String,
    balance:Balance<SUI>,
    articles:vector<Article>,
    articlecount:u64
}

//define admin capabilities
public struct BlogOwner has key{
    id:UID,
    blog_id:ID,
}

// Events

public struct BlogCreated has copy,drop{
    name:String,
    blog_id:ID
}

    // event when new article is added
    public struct ArticleCreated has copy, drop {
        by: String,
        title:String,
         id:u64
      
    }

//event when user decides to donate amount
public  struct UserDonate has copy,drop{
    amount_donated:u64,
    to:String,
}

public struct AmountWithdrawn has copy,drop{
    recipient:address,
    amount:u64
}

//event when an article is deleted
public struct ArticleDeleted has copy,drop{
    by:String,
    articleid:u64
}
public entry fun register_blogSite(name:String,ctx:&mut TxContext){

     // assert!(ctx.caller == recipient, Error_Not_Librarian);
        // let library_uid = object::new(ctx); 
        // let librarian_cap_uid = object::new(ctx); 

        // let library_id = object::uid_to_inner(&library_uid);
        // let librarian_cap_id = object::uid_to_inner(&librarian_cap_uid);



    let userid=object::new(ctx);
    let user_id=object::uid_to_inner(&userid);
    let newblogpage=BlogSite {
        id:userid,
        usercap:user_id,
        name,
        balance:zero<SUI>(),
        articles:vector::empty(),
        articlecount:0,
    };

     transfer::transfer(BlogOwner {
        id: object::new(ctx),
        blog_id: user_id,
    }, tx_context::sender(ctx));

    event::emit(BlogCreated{
        name:name,
        blog_id:user_id
    });

     transfer::share_object(newblogpage);
}


    //function to create an article
public entry fun createarticle(user:&mut BlogSite,nameofarticle:String,title:String,description:String,ctx:&mut TxContext){
        
        let article_count=user.articles.length();

      //   let article_uid=object::new(ctx);
    //    let arti_id=object::uid_to_inner(&article_uid);

        let newarticle=Article{
            id:article_count,
            owner:user.name,
            nameofarticle,
            title,
            description,
            likes:vector[],
            dislikes:vector[],
            comments:vector[],
            
        };
        user.articles.push_back(newarticle);
        user.articlecount = user.articlecount + 1;


  //emit event whn article is created

  event::emit(ArticleCreated{
    by:user.name,
    title,
   id:article_count
  });

}

//function where reader can buy a coffee for the creator of article
public entry fun buy_me_coffee(article_id:u64,amount:Coin<SUI>,blog:&mut BlogSite){

    //check the amount to make sure its greater than 1
     assert!(coin::value(&amount) >1, EAmountMustBeGreaterThanOne);
  //check if article is availabel
  assert!(blog.articlecount>=article_id,EArticleNotAvailable);
     // get the amount being donated in SUI .
    let amount_donated: u64 = coin::value(&amount);
    
     // add the amount to the donated balance
    let coin_balance = coin::into_balance(amount);
    balance::join(&mut blog.balance, coin_balance);

    //generate event
    event::emit(UserDonate{
      amount_donated:amount_donated,
      to:blog.name
    });
}

//function where owner of article withdraw all funds donated by users
   
  public entry fun withdraw_funds(user_cap:&BlogOwner, amount:u64,recipient:address,blog: &mut BlogSite, ctx: &mut TxContext) {

    // verify its the owner of article
    assert!(object::id(blog)==user_cap.blog_id, ENotOwner);
    
    //verify amount
      assert!(amount > 0 && amount <= blog.balance.value(), Error_Invalid_WithdrawalAmount);


    let take_coin = take(&mut blog.balance, amount, ctx);  // Take funds from course balance
   
    transfer::public_transfer(take_coin, recipient);  // Transfer funds to recipient

    event::emit( AmountWithdrawn{
        recipient:recipient,
        amount:amount
    });
    
  }

//owner delete the article
#[allow(unused_function)]
public entry fun delete_article( owner_cap: &BlogOwner,blog:&mut BlogSite,articleid:u64){

    //make sure its the owner deleting the article
    //assert!(object::id(verifyowner)==object::id(article),EOnlyOwnerCanDeleteArticle);
 assert!(
        object::id(blog) == owner_cap.blog_id,
      EOnlyOwnerCanDeleteArticle
    );
      
assert!(articleid <= blog.articles.length(),  EArticleNotAvailable);


//get article
let Article{id:_,owner:_,nameofarticle:_,title:_,description:_,likes:_,dislikes:_,comments:_}=&blog.articles[articleid];
//let Article{id,article_id:_,owner:_,nameofarticle:_,title:_, description:_,likes:_,dislikes:_,amount_donated:_,comments:_}=art;
    //let ArticleOwner {id,article_id}=owner;
    event::emit(ArticleDeleted{
        by:blog.name,
        articleid
    });
   //  object::delete(art.id);

   // object::delete(article_id);
    
}

//function to get an article
 public entry fun get_an_aricle(blog:&BlogSite,article_id:u64):(String,String,String,String){
assert!(article_id <= blog.articles.length(),  EArticleNotAvailable);
    let article=&blog.articles[article_id];
    (
    article.nameofarticle,
    article.title,
    article.description,
    article.owner
    )
 }

 //function to get all written articles
 public fun get_all_articles(blog:&BlogSite):&vector<Article>{
    //return list of all articles
    let allarticles=&blog.articles;
    allarticles
 }
//function to add like an article
public entry fun addliketoanarticle(blog:&mut BlogSite,by:address,article_id:u64){
    assert!(article_id <= blog.articles.length(),  EArticleNotAvailable);
     blog.articles[article_id].likes.push_back(by);
     
 }

//function to add dislike on an article
public entry fun adddilikestoanarticle(blog:&mut BlogSite,by:address,article_id:u64){
     assert!(article_id <= blog.articles.length(),  EArticleNotAvailable);
     blog.articles[article_id].dislikes.push_back(by);
     
 }

 //function to add comment to an article
 public entry fun addcommenttoanarticle(blog:&mut BlogSite,comment:String,article_id:u64){
    assert!(article_id <= blog.articles.length(),  EArticleNotAvailable);
     blog.articles[article_id].comments.push_back(comment);
     
 }
}

//dislike an article
//comment on an article
