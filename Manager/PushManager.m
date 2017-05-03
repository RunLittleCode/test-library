//
//  PushManager.m
//  com.qihoo.taojin
//
//  Created by liuguanchen on 16/11/22.
//  Copyright © 2016年 danjiang qu. All rights reserved.
//

#import "PushManager.h"
#import "JPUSHService.h"
#import <UserNotifications/UserNotifications.h>
#import "NetworkMacro.h"
#import <UIKit/UIKit.h>
#import "ToolMacro.h"
#import "UIWindow+XY.h"
#import "PAHybridViewController.h"

#ifdef DEBUG
static BOOL isProduction = YES;
#else
static BOOL isProduction = YES;
#endif

@interface PushManager()<JPUSHRegisterDelegate>

@property (nonatomic, assign) BOOL isLogOpen;

@end

@implementation PushManager

+ (instancetype)sharedManager
{
    static PushManager *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once (&onceToken, ^{
        _sharedClient = [[PushManager alloc] init];
    });
    
    return _sharedClient;
}

+ (void)setLogOpen:(BOOL)isOpen {
    [PushManager sharedManager].isLogOpen = isOpen;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults * userDefault = [NSUserDefaults standardUserDefaults];
        NSString * pushKey = @"taojin_registerid";
        _registerId = [userDefault stringForKey:pushKey];
    }
    return self;
}

- (void)setRegisterId:(NSString *)registerId {
    if (registerId && ![registerId isEqualToString:_registerId]) {
        _registerId = [registerId copy];
        NSUserDefaults * userDefault = [NSUserDefaults standardUserDefaults];
        NSString * pushKey = @"taojin_registerid";
        [userDefault setObject:_registerId forKey:pushKey];
        [userDefault synchronize];
    }
}

- (void)reigisterNotificationWithOption:(NSDictionary *)option {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0) {
#ifdef NSFoundationVersionNumber_iOS_9_x_Max
        JPUSHRegisterEntity * entity = [[JPUSHRegisterEntity alloc] init];
        entity.types = UNAuthorizationOptionAlert|UNAuthorizationOptionBadge|UNAuthorizationOptionSound;
        [JPUSHService registerForRemoteNotificationConfig:entity delegate:self];
#endif
    } else if ([[UIDevice currentDevice].systemVersion floatValue] >= 8.0) {
        //可以添加自定义categories
        [JPUSHService registerForRemoteNotificationTypes:(UIUserNotificationTypeBadge |
                                                          UIUserNotificationTypeSound |
                                                          UIUserNotificationTypeAlert)
                                              categories:nil];
    } else {
        //categories 必须为nil
        [JPUSHService registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                                          UIRemoteNotificationTypeSound |
                                                          UIRemoteNotificationTypeAlert)
                                              categories:nil];
    }
#pragma clang diagnostic pop
    [JPUSHService setLogOFF];
    [JPUSHService setupWithOption:option appKey:PUSH_SECRET_KEY
                          channel:@"appstore"
                 apsForProduction:isProduction];
    
    //2.1.9版本新增获取registration id block接口。
    [JPUSHService registrationIDCompletionHandler:^(int resCode, NSString *registrationID) {
        if(resCode == 0){
            [self setRegisterId:registrationID];
            DDLogInfo(@"registrationID获取成功：%@",registrationID);
        }else{
            DDLogError(@"registrationID获取失败，code：%d",resCode);
        }
    }];
}


#pragma mark - JPUSHRegisterDelegate
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(NSInteger options))completionHandler {
    
}
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)())completionHandler {
    NSDictionary * userInfo = response.notification.request.content.userInfo;
    UNNotificationRequest *request = response.notification.request; // 收到推送的请求
    UNNotificationContent *content = request.content; // 收到推送的消息内容
    
    NSNumber *badge = content.badge;  // 推送消息的角标
    NSString *body = content.body;    // 推送消息体
    UNNotificationSound *sound = content.sound;  // 推送消息的声音
    NSString *subtitle = content.subtitle;  // 推送消息的副标题
    NSString *title = content.title;  // 推送消息的标题
    
    if([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        [JPUSHService handleRemoteNotification:userInfo];
        DDLogInfo(@"iOS10 收到远程通知:%@", userInfo);
        [self handNotificationDic:userInfo];
    }
    else {
        // 判断为本地通知
        DDLogInfo(@"iOS10 收到本地通知:{\nbody:%@，\ntitle:%@,\nsubtitle:%@,\nbadge：%@，\nsound：%@，\nuserInfo：%@\n}",body,title,subtitle,badge,sound,userInfo);
    }
    
    completionHandler();  // 系统要求执行这个方法

}

- (void)handNotificationDic:(NSDictionary *)userInfo {
    DDLogError(@"notification userInfo:%@",userInfo);
    if (userInfo) {
        NSDictionary * notificationDic = _DIC(userInfo);
        NSString * page = [notificationDic validStringForKey:@"page"];
        if ([@"_link" isEqualToString:page]){
            NSString * path = [notificationDic validStringForKey:@"p"];
            PAHybridViewController *vc = [PAHybridViewController hybridViewControllerWithPage:path];
            [[UIWindow uxy_optimizedVisibleViewController].navigationController pushViewController:vc animated:YES];
        }
    }
}

- (UINavigationController *)showMainViewController {
    UIViewController * rootViewController = [[UIApplication sharedApplication] keyWindow].rootViewController;
    if (rootViewController.presentedViewController) {
        [rootViewController.presentedViewController dismissViewControllerAnimated:NO completion:nil];
    }
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController * tabController = (UITabBarController *)rootViewController;
        UIViewController * selectController = tabController.selectedViewController;
        if (selectController.presentedViewController) {
            [selectController.presentedViewController dismissViewControllerAnimated:NO completion:nil];
        }
        if ([selectController isKindOfClass:[UINavigationController class]]) {
            UINavigationController * navController = (UINavigationController *)selectController;
            [navController popToRootViewControllerAnimated:NO];
            return navController;
        }else{
            return nil;
        }
    }
    return nil;
}

+ (void)resetBadge {
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    [JPUSHService resetBadge];
}

@end
