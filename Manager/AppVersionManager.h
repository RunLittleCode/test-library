//
//  AppVersionManager.h
//  xiaodai
//
//  Created by liuguanchen on 2017/3/16.
//  Copyright © 2017年 liuguanchen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AppVersionManager : NSObject

+ (instancetype)sharedManager;

- (void)checkShouldUpdateVersion;
@end
