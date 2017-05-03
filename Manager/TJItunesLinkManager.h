//
//  TJItunesLinkManager.h
//  xiaodai
//
//  Created by liuguanchen on 2017/4/27.
//  Copyright © 2017年 liuguanchen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TJItunesLinkManager : NSObject

+ (instancetype)sharedInstance;

- (void)updateItunesWhiteListRequest;

- (BOOL)checkIsAllowOpenUrl:(NSURL *)itunesUrl;

@end
