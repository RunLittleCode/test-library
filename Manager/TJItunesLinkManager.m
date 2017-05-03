//
//  TJItunesLinkManager.m
//  xiaodai
//
//  Created by liuguanchen on 2017/4/27.
//  Copyright © 2017年 liuguanchen. All rights reserved.
//

#import "TJItunesLinkManager.h"
#import "HttpNetworkClient.h"

@interface TJItunesLinkManager()
{
    NSMutableArray<NSString *> * whiteArray;
}
@end

@implementation TJItunesLinkManager

+ (instancetype)sharedInstance
{
    static TJItunesLinkManager *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once (&onceToken, ^{
        _sharedClient = [[TJItunesLinkManager alloc] init];
    });
    
    return _sharedClient;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        whiteArray = [NSMutableArray new];
    }
    return self;
}

- (void)updateItunesWhiteListRequest {
    HttpNetworkClient * client = [HttpNetworkClient sharedClient];
    [client setBaseUrl:TJ_BaseUrl];
    
    NSMutableDictionary * param = [NSMutableDictionary dictionary];
    [param setSafeObject:APP_ID forKey:@"app_id"];
    
    [client getUrl:@"Safewindow/whitelist" parameters:param progressBlock:^(NSProgress *uploadProgress) {
        
    } successBlock:^(NSURLSessionDataTask *task, id responseObject) {
        NSDictionary * resultDic = _DIC(responseObject);
        NSString * statusCode = resultDic[@"code"];
        if ([_STR(statusCode) isEqualToString:TJ_OK_CODE]) {
            NSArray * list = [resultDic validArrayForKey:@"data"];
            [whiteArray removeAllObjects];
            [whiteArray addObjectsFromArray:list];
        }
    } failureBlock:^(NSURLSessionDataTask *task, NSError *error) {

    }];
}

- (BOOL)checkIsAllowOpenUrl:(NSURL *)itunesUrl {
    __block BOOL isAllow = NO;
    NSString * fullUrl = itunesUrl.absoluteString;
    [whiteArray enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([fullUrl rangeOfString:obj].location != NSNotFound) {
            isAllow = YES;
            *stop = YES;
        }
    }];
    return isAllow;
}

@end
