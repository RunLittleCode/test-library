//
//  PushManager.h
//  com.qihoo.taojin
//
//  Created by liuguanchen on 16/11/22.
//  Copyright © 2016年 danjiang qu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PushManager : NSObject

@property (nonatomic, copy) NSString * registerId;


+ (instancetype)sharedManager;

- (void)reigisterNotificationWithOption:(NSDictionary *)option;

+ (void)resetBadge;

+ (void)setLogOpen:(BOOL)isOpen;
@end
