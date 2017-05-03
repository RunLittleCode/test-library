//
//  H5VersionManager.h
//  xiaodai
//
//  Created by liuguanchen on 2017/3/16.
//  Copyright © 2017年 liuguanchen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface H5VersionManager : NSObject

+ (instancetype)shareManager;

+ (NSString *)getCurrentHtmlVersion;

/*
 * 加载html文件
 */
- (void)setupHtmlFileWithBlock:(void (^)())block;


- (void)checkHtmlFileWithTimeWithBlock:(void (^)())block;
@end
