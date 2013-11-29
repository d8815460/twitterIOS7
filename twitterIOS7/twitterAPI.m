//
//  twitterAPI.m
//  Timeline
//
//  Created by 駿逸 陳 on 2013/11/29.
//  Copyright (c) 2013年 駿逸 陳. All rights reserved.
//

#import "twitterAPI.h"

@implementation twitterAPI

/*
 if ([SomeClass isSocialAvailable]) {
 // code to tweet with SLComposeViewController
 } else if ([SomeClass isTwitterAvailable]) {
 // code to tweet with TWTweetComposeViewController
 } else {
 // Twitter not available, or open a url like https://twitter.com/intent/tweet?text=tweet%20text
 }
 */
+(BOOL)isTwitterAvailable {
    return NSClassFromString(@"TWTweetComposeViewController") != nil;
}
+(BOOL)isSocialAvailable {
    return NSClassFromString(@"SLComposeViewController") != nil;
}


@end
