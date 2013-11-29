//
//  ViewController.m
//  twitterIOS7
//
//  Created by 駿逸 陳 on 2013/11/29.
//  Copyright (c) 2013年 駿逸 陳. All rights reserved.
//

#import "ViewController.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import <Twitter/Twitter.h>
#import "twitterAPI.h"

@interface ViewController ()
@property (strong, nonatomic) NSArray *array;
@property (strong, nonatomic) NSArray *resultFollowersNameList;
@property (strong, nonatomic) ACAccount *twitterAccount;
@property(nonatomic, retain) NSMutableString *paramString;

@property (strong, nonatomic) ACAccountStore *accountStore;
@property (strong, nonatomic) NSArray        *accounts;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    NSLog(@"ver = %i", (int)[[[UIDevice currentDevice] systemVersion] integerValue]);
    [self getTwitterAccounts];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Table View Data Source Methods
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [self.array count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *cellID = @"cellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    }
    NSDictionary *tweet = self.array[indexPath.row];
    cell.textLabel.text = tweet[@"text"];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

/******To check whether More then Twitter Accounts setup on device or not *****/
-(void)getTwitterAccounts {
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    // Create an account type that ensures Twitter accounts are retrieved.
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    // let's request access and fetch the accounts
    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
        // check that the user granted us access and there were no errors (such as no accounts added on the users device)
        if (granted && !error && [[accountStore accountsWithAccountType:accountType] count] > 0) {
            NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
            if ([accountsArray count] > 1) {
                int NoOfAccounts = (int)[accountsArray count];
                // a user may have one or more accounts added to their device
                // you need to either show a prompt or a separate view to have a user select the account(s) you need to get the followers and friends for
                NSLog(@"device has more then one twitter accounts %i",NoOfAccounts);
                
                ACAccount *twitterAccount = [accountsArray lastObject];
                self.twitterAccount = twitterAccount; //取用最近使用的Twitter ID
            } else {
                self.twitterAccount = [accountsArray objectAtIndex:0];
                NSLog(@"device has single twitter account");
            }
            [self twitterTimeline:self.twitterAccount];
        } else {
            // handle error (show alert with information that the user has not granted your app access, etc.)
            // show alert with information that the user has not granted your app access, etc.
            NSLog(@"用戶沒有twitter帳戶");
        }
    }];
}

// 取得用戶的時間軸
- (void)twitterTimeline:(ACAccount*)account {
    NSLog(@"用戶帳號= %@", self.twitterAccount);
    NSURL *requestAPI = [NSURL URLWithString:@"http://api.twitter.com/1.1/statuses/user_timeline.json"];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setObject:@"100" forKey:@"count"];
    [parameters setObject:@"1" forKey:@"include_entities"];
    SLRequest *posts = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:requestAPI parameters:parameters];
    posts.account = account;
    [posts performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        self.array = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableLeaves error:&error];
        
        if (self.array.count != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }];
    
    [self getTwitterFriendsForAccount:self.twitterAccount]; //取得朋友的ID
}

// 取得用戶的Twitter朋友 ID
-(void)getTwitterFriendsForAccount:(ACAccount*)account {
    // In this case I am creating a dictionary for the account
    // Add the account screen name
    NSMutableDictionary *accountDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:account.username, @"screen_name", nil];
    // Add the user id (I needed it in my case, but it's not necessary for doing the requests)
    [accountDictionary setObject:[[[account dictionaryWithValuesForKeys:[NSArray arrayWithObject:@"properties"]] objectForKey:@"properties"] objectForKey:@"user_id"] forKey:@"user_id"];
    // Setup the URL, as you can see it's just Twitter's own API url scheme. In this case we want to receive it in JSON
    NSURL *followingURL = [NSURL URLWithString:@"http://api.twitter.com/1.1/friends/ids.json"];
    // Pass in the parameters (basically '.ids.json?screen_name=[screen_name]')
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:account.username, @"screen_name", nil];
    // Setup the request
    SLRequest *twitterRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:followingURL parameters:parameters];
    // This is important! Set the account for the request so we can do an authenticated request. Without this you cannot get the followers for private accounts and Twitter may also return an error if you're doing too many requests
    [twitterRequest setAccount:account];
    // Perform the request for Twitter friends
    [twitterRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (error) {
            // deal with any errors - keep in mind, though you may receive a valid response that contains an error, so you may want to look at the response and ensure no 'error:' key is present in the dictionary
        }
        NSError *jsonError = nil;
        // Convert the response into a dictionary
        NSDictionary *twitterFriends = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&jsonError];
        // Grab the Ids that Twitter returned and add them to the dictionary we created earlier
        [accountDictionary setObject:[twitterFriends objectForKey:@"ids"] forKey:@"friends_ids"];
        
        /* 透過ID取得用戶名稱 */
        NSArray *IDlist = [twitterFriends objectForKey:@"ids"];
        NSLog(@"response value is: %@", IDlist); //NSString格式
        int count = (int)IDlist.count;
        for (int i=0; i<count; i++ ) {
            [self.paramString appendFormat:@"%@",[IDlist objectAtIndex:i]];
            if (i <count-1) {
                NSString *delimeter = @",";
                [self.paramString appendString:delimeter];
            }
            [self getFollowerNameFromID:[NSString stringWithFormat:@"%@",[IDlist objectAtIndex:i]] AndMyAccount:self.twitterAccount];
        }
    }];
}

// 取得朋友名字等資料
-(void) getFollowerNameFromID:(NSString *)FriendID AndMyAccount:(ACAccount*)account{
    NSURL *getLookUpurl = [NSURL URLWithString:@"http://api.twitter.com/1.1/users/lookup.json"];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:FriendID, @"user_id",nil];
    NSLog(@"make a request for ID = %@",[parameters objectForKey:@"user_id"]);
    
    SLRequest *twitterRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:getLookUpurl parameters:parameters];
    [twitterRequest setAccount:account];
    
    [twitterRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (error) {
        }
        NSError *jsonError = nil;
        NSDictionary *friendsdata = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&jsonError];
        self.resultFollowersNameList = [friendsdata valueForKey:@"name"];  /* 撈取什麼資料請參考行以下的 JSON
                                                                            比較有用的大概就是 id, id_str, name, screen_name. */
        NSLog(@"resultNameList value is %@", [self.resultFollowersNameList objectAtIndex:0]);
        
    }];
}

/********************** 透過朋友ID 撈取該朋友的資料 JSON *****************************
 {
 "contributors_enabled" = 0;
 "created_at" = "Fri Oct 18 05:33:55 +0000 2013";
 "default_profile" = 1;
 "default_profile_image" = 1;
 description = "";
 entities = {
 description = {
 urls = (
 );
 };
 };
 "favourites_count" = 0;
 "follow_request_sent" = 0;
 "followers_count" = 1;
 following = 1;
 "friends_count" = 1;
 "geo_enabled" = 0;
 id = 1968261337;
 "id_str" = 1968261337;
 "is_translator" = 0;
 lang = "zh-tw";
 "listed_count" = 0;
 location = "";
 name = "\U6e6f\U5305";
 notifications = 0;
 "profile_background_color" = C0DEED;
 "profile_background_image_url" = "http://abs.twimg.com/images/themes/theme1/bg.png";
 "profile_background_image_url_https" = "https://abs.twimg.com/images/themes/theme1/bg.png";
 "profile_background_tile" = 0;
 "profile_image_url" = "http://abs.twimg.com/sticky/default_profile_images/default_profile_0_normal.png";
 "profile_image_url_https" = "https://abs.twimg.com/sticky/default_profile_images/default_profile_0_normal.png";
 "profile_link_color" = 0084B4;
 "profile_sidebar_border_color" = C0DEED;
 "profile_sidebar_fill_color" = DDEEF6;
 "profile_text_color" = 333333;
 "profile_use_background_image" = 1;
 protected = 0;
 "screen_name" = cutesnow0816;
 "statuses_count" = 0;
 "time_zone" = "";
 url = "";
 "utc_offset" = "";
 verified = 0;
 }
 */


#pragma mark - login

- (IBAction)login_twitter:(id)sender {
    NSLog(@"login 0");
    [self fetchData];
}

- (void)fetchData
{
    if (_accounts == nil)
    {
        if(_accountStore == nil)
        {
            self.accountStore = [[ACAccountStore alloc] init];
        }
        ACAccountType *accountTypeTwitter = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
        
        [self.accountStore requestAccessToAccountsWithType:accountTypeTwitter options:nil completion:^(BOOL granted, NSError *error) {
            if(granted)
            {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    self.accounts = [self.accountStore accountsWithAccountType:accountTypeTwitter];
                });
            }else {
                // User denied access to his Twitter accounts
                NSLog(@"用戶拒絕使用twitter帳戶連接app");
            }
        }];
    }
    else
    {
        // This iOS verion doesn't support Twitter. Use 3rd party library
        NSLog(@"This iOS verion doesn't support Twitter. Use 3rd party library");
    }
    
}

#pragma mark - tweet

- (void)send_tweet
{
    if ([twitterAPI isSocialAvailable]) {
        // code to tweet with SLComposeViewController
        //建立viewcontroller
        SLComposeViewController *composeViewController = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
        //設定推文的內容
        [composeViewController setInitialText:@"Twitter API 測試 with SLComposeViewController。"];
        
        //推文中加入圖片資訊
        [composeViewController addImage:[UIImage imageNamed:@"logo.png"]];
        
        //推文中加入網址超連結資訊
        [composeViewController addURL:[NSURL URLWithString:@"http://n11studio.blogspot.tw/"]];
        
        //顯示viewcontroller
        [self presentViewController:composeViewController animated:YES completion:nil];
        
        //按下Send或是Cancel時的處理動作(block)
        [composeViewController setCompletionHandler:^(TWTweetComposeViewControllerResult result) {
            NSString *tweet_action;
            switch (result) {
                case TWTweetComposeViewControllerResultCancelled:
                    tweet_action = @"取消";
                    break;
                case TWTweetComposeViewControllerResultDone:
                    tweet_action = @"完成";
                    break;
                default:
                    break;
            }
            NSLog(@"%@", tweet_action);
            
            //移除viewcontroller
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
        
    }
    //    else if ([twitterAPI isTwitterAvailable]){
    //        // code to tweet with TWTweetComposeViewController
    //        //建立viewcontroller
    //        TWTweetComposeViewController *tweetTOtwitter = [[TWTweetComposeViewController alloc] init];
    //
    //        //設定推文的內容
    //        [tweetTOtwitter setInitialText:@"Twitter API 測試 with TWTweetComposeViewController。"];
    //
    //        //推文中加入圖片資訊
    //        [tweetTOtwitter addImage:[UIImage imageNamed:@"logo.png"]];
    //
    //        //推文中加入網址超連結資訊
    //        [tweetTOtwitter addURL:[NSURL URLWithString:@"http://n11studio.blogspot.tw/"]];
    //
    //        //顯示viewcontroller
    //        [self presentViewController:tweetTOtwitter animated:YES completion:nil];
    //
    //        //按下Send或是Cancel時的處理動作(block)
    //        [tweetTOtwitter setCompletionHandler:^(TWTweetComposeViewControllerResult result) {
    //            NSString *tweet_action;
    //
    //            switch (result) {
    //                case TWTweetComposeViewControllerResultCancelled:
    //                    tweet_action = @"取消";
    //                    break;
    //
    //                case TWTweetComposeViewControllerResultDone:
    //                    tweet_action = @"完成";
    //                    break;
    //
    //                default:
    //                    break;
    //            }
    //
    //
    //            NSLog(@"%@", tweet_action);
    //
    //            //移除viewcontroller
    //            [self dismissViewControllerAnimated:YES completion:nil];
    //        }];
    //    }
    else{
        // Twitter not available, or open a url like https://twitter.com/intent/tweet?text=tweet%20text
    }
}
@end
