//
//  QHRouter.h
//  qihooloan_ios
//
//  Created by liangzusheng on 16/4/6.
//  Copyright © 2016年 qihoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 页面路由类
// copy from https://github.com/uxyheaven/XYRouter


/// 页面路由协议, 实现这个协议的类会在启动的时候被自动调用
@protocol QHRouterAutoRegister <NSObject>
+ (void)registerViewControllerRouter;
@optional
+ (instancetype)newDefaultInstance;
@end

typedef UIViewController *  (^QHRouterBlock)();

@interface QHRouter : NSObject

+ (instancetype)sharedInstance;
+ (void)purgeSharedInstance;

@property (nonatomic, weak, readonly) UIViewController *rootViewController;
@property (nonatomic, copy, readonly) NSString *currentPath;

- (void)mapKey:(NSString *)key toControllerClassName:(NSString *)className;
- (void)mapKey:(NSString *)key toControllerInstance:(UIViewController *)viewController;
- (void)mapKey:(NSString *)key toBlock:(QHRouterBlock)block;

// 当取出ViewController的时候, 如果有单例[ViewController sharedInstance], 默认返回单例, 如果没有, 返回[[ViewController alloc] init].
- (id)viewControllerForKey:(NSString *)key;

// 返回当前的NavigationController
+ (UINavigationController *)currentNavigationController;

/// 关闭一个viewController, 如果栈里有viewCotroller就pop, 没有就dismiss
+ (void)closeViewController:(UIViewController *)viewController animated:(BOOL)flag completion:(void (^)(void))completion;

@end
