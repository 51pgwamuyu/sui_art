
module articles::articles {
use std::string::{String};
use sui::coin::{Coin, Self,take};
use sui::balance::{Balance, Self, zero};
use sui::sui::SUI;
use sui::tx_context::sender;
use sui::object::{Self, UID};
use sui::clock::Clock;
use sui::event;
//use std::vec::Vec;

//define errors
const EAmountMustBeGreaterThanOne:u64=1;
const EOnlyOwnerCanDeleteArticle:u64=2;
const ENotOwner:u64=3;
const EInsufficientAmount:u64=4;

//struct for articles
public struct Article has key,store{
    id:UID,
    article_id:ID,
    owner:address,
    nameofarticle:String,
    title:String,
    description:String,
    likes:vector<address>,
    dislikes:vector<address>,
    amount_donated:Balance<SUI>,
    comments:vector<String>,
   
}


//define admin capabilities
public struct ArticleOwner has key{
    id:UID,
    article_id:ID,
}

// Events

    // event when new article is added
    public struct ArticleCreated has copy, drop {
        article_id: ID,
        owner: address,
        articlename:String,
      
    }

//event when user decides to donate amount
public  struct UserDonate has copy,drop{
    amount_donated:u64,
    to:address,
}

//event when an article is deleted
public struct ArticleDeleted has copy,drop{
    articlename:String,
    by:address
}

    //function to create an article
    public entry fun createarticle(owner:address,nameofarticle:String,title:String,description:String,ctx:&mut TxContext){
        let article_uid=object::new(ctx);
        let arti_id=object::uid_to_inner(&article_uid);
        let newarticle=Article{
            id:article_uid,
            article_id:arti_id,
            owner,
            nameofarticle,
            title,
            description,
            likes:vector[],
            dislikes:vector[],
            amount_donated:zero<SUI>(),
            comments:vector[],
            
        };


    // create and send a article owner capability for the creator
    transfer::transfer(ArticleOwner {
        id: object::new(ctx),
        article_id: arti_id,
    }, tx_context::sender(ctx));

  //emit event whn article is created

  event::emit(ArticleCreated{
   article_id:arti_id,
   articlename:nameofarticle,
  
   owner:owner,
  });

     // share the object so anyone can read it and also buy coffee
    transfer::public_share_object(newarticle);
    }

//function where reader can buy a coffee for the creator of article
public entry fun buy_me_coffee(amount:Coin<SUI>,article:&mut Article){

    //check the amount to make sure its greater than 1
     assert!(coin::value(&amount) < 1, EAmountMustBeGreaterThanOne);

     // get the amount being donated in SUI .
    let amount_donated: u64 = coin::value(&amount);
    
     // add the amount to the donated balance
    let coin_balance = coin::into_balance(amount);
    balance::join(&mut article.amount_donated, coin_balance);

    //generate event
    event::emit(UserDonate{
      amount_donated:amount_donated,
      to:article.owner
    });
}

//function where owner of article withdraw all funds donated by users
   
  public entry fun withdraw_funds(owner:&ArticleOwner, amount:u64,recipient:address,article: &mut Article, ctx: &mut TxContext) {

    // verify its the owner of article
    assert!(object::id(article) == owner.article_id, ENotOwner);
    
    //verify if there are sufficient balance
    assert!(balance::value(&article.amount_donated) <amount,EInsufficientAmount);

    let take_coin = take(&mut article.amount_donated, amount, ctx);  // Take funds from course balance
   
    transfer::public_transfer(take_coin, recipient);  // Transfer funds to recipient
    
  }

//owner delete the article
#[allow(unused_function)]
public entry fun deletearticle(owner:ArticleOwner,verifyowner:&ArticleOwner,article:&mut Article){

    //make sure its the owner deleting the article
    assert!(object::id(verifyowner)==object::id(article),EOnlyOwnerCanDeleteArticle);
    let ArticleOwner {id,article_id}=owner;
    event::emit(ArticleDeleted{
        articlename:article.title,
        by:article.owner
    });
    object::delete(id);
    
}

//function to get an article
 public entry fun get_an_aricle(article:&Article):(ID,String,String,String,address){
    (
    article.article_id,
    article.nameofarticle,
    article.title,
    article.description,
    article.owner
    )
 }

 //function to get all written articles
 public fun get_all_articles(articles:vector<Article>):vector<Article>{
    //return list of all articles
    articles
 }
//function to add like an article
public entry fun addliketoanarticle(by:address,article:&mut Article){
     article.likes.push_back(by); 
     
 }

//function to add dislike on an article
public entry fun adddilikestoanarticle(by:address,article:&mut Article){
     article.dislikes.push_back(by); 
     
 }

 //function to add comment to an article
 public entry fun addcommenttoanarticle(comment:String,article:&mut Article){
     article.comments.push_back(comment); 
     
 }
}

//dislike an article
//comment on an article

