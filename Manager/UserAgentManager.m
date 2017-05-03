//
//  UserAgentManager.m
//  com.qihoo.taojin
//
//  Created by liuguanchen on 2016/12/30.
//  Copyright © 2016年 danjiang qu. All rights reserved.
//

#import "UserAgentManager.h"
#import <UIKit/UIKit.h>

@implementation UserAgentManager

+ (void)showCustomUserAgent {
    UIWebView * webView = [UIWebView new];
    NSString * currentAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    NSString * version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString * build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString * appendAgent = [NSString stringWithFormat:@" PDLApp_%@.%@ PDLH5ENV_DEV",version,build];
    if ([currentAgent rangeOfString:appendAgent].location == NSNotFound) {
        NSString * newAgent = [currentAgent stringByAppendingString:appendAgent];
        NSDictionary * dictionary = @{@"UserAgent":newAgent};
        [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    }
}

@end
