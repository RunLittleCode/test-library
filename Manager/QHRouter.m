//
//  QHRouter.m
//  qihooloan_ios
//
//  Created by liangzusheng on 16/4/6.
//  Copyright © 2016年 qihoo. All rights reserved.
//


#import "QHRouter.h"
#import "XYRuntime.h"
#import "AppDelegate.h"
#import "UIWindow+XY.h"
#import <objc/runtime.h>

#pragma mark - UIViewController_private
@interface UIViewController (UIViewController_private)
@property (nonatomic, copy) NSString *router_path;
@end

#pragma mark -
@interface QHRouter ()

@property (nonatomic, strong) NSMutableDictionary *map;
@property (nonatomic, strong) UIViewController *currentViewRoute;       // 当前的控制器
@property (nonatomic, copy) NSString *currentPath;

@end


@implementation QHRouter
static dispatch_once_t __singletonToken;
static id __singleton__;
+ (instancetype)sharedInstance
{
    dispatch_once( &__singletonToken, ^{ __singleton__ = [[self alloc] init]; } );
    return __singleton__;
}
+ (void)purgeSharedInstance
{
    __singleton__ = nil;
    __singletonToken = 0;
}

+ (void)initialize
{
    // 默认用类名注册所有的vc
    NSArray *classes  = [UIViewController uxy_subClasses];
    [classes enumerateObjectsUsingBlock:^(NSString *classType, NSUInteger idx, BOOL *stop) {
        [[QHRouter sharedInstance] mapKey:classType toControllerClassName:classType];
    }];
    
    // 调用所有的注册方法
    classes = [NSObject uxy_classesWithProtocol:@"PARouterAutoRegister"];
    [classes enumerateObjectsUsingBlock:^(NSString *classType, NSUInteger idx, BOOL *stop) {
        [NSClassFromString(classType) registerViewControllerRouter];
    }];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _map = [@{} mutableCopy];
    }
    return self;
}

- (NSString *)currentPath
{
    __block NSString *string = @"";
    UINavigationController *nvc = [[self class] __visibleNavigationController];
    if (nvc)
    {
        [nvc.viewControllers enumerateObjectsUsingBlock:^(UIViewController *vc, NSUInteger idx, BOOL *stop) {
            string = [NSString stringWithFormat:@"%@/%@", string, vc.router_path];
        }];
    }
    else
    {
        UIViewController *vc = [[self class] __visibleViewController];
        string = [NSString stringWithFormat:@"%@/%@", string, vc.router_path];
    }
    
    _currentPath = string;
    return _currentPath;
}

- (UIViewController *)rootViewController
{
    return UIWindow.uxy_mainWindow.rootViewController;
}
- (void)mapKey:(NSString *)key toControllerClassName:(NSString *)className
{
    if (key.length == 0)
    {
        return;
    }
    
    _map[key] = className;
}

- (void)mapKey:(NSString *)key toControllerInstance:(UIViewController *)viewController
{
    if (key.length == 0)
    {
        return;
    }
    
    _map[key] = viewController;
}


- (void)mapKey:(NSString *)key toBlock:(QHRouterBlock)block
{
    if (key.length == 0)
    {
        return;
    }
    
    _map[key] = block;
}

- (id)viewControllerForKey:(NSString *)key
{
    NSObject *obj = nil;
    
    if (key.length > 0)
    {
        obj = [_map objectForKey:key];
    }
    
    if (obj == nil) return nil;
    
    UIViewController *vc = nil;
    
    if ([obj isKindOfClass:[NSString class]])
    {
        Class classType = NSClassFromString((NSString *)obj);
#ifdef DEBUG
        NSString *error = [NSString stringWithFormat:@"%@ must be  a subclass of UIViewController class", obj];
        NSAssert([classType isSubclassOfClass:[UIViewController class]], error);
#endif
        if ([classType respondsToSelector:@selector(sharedInstance)])
        {
            vc = [classType sharedInstance];
        }
        else if ([classType conformsToProtocol:@protocol(QHRouterAutoRegister)] && [classType respondsToSelector:@selector(newDefaultInstance)])
        {
            vc = [classType newDefaultInstance];
        }
        else
        {
            vc = [[classType alloc] init];
        }
    }
    else if ([obj isKindOfClass:[UIViewController class]])
    {
        vc = (UIViewController *)obj;
    }
    else
    {
        QHRouterBlock objBlock = (QHRouterBlock)obj;
        vc = objBlock();
    }
    
    if ([vc isKindOfClass:[UINavigationController class]])
    {
        ((UINavigationController *)vc).visibleViewController.router_path = key;
    }
    else
    {
        vc.router_path = key;
    }
    
    return vc;
}

// 返回当前的NavigationController
+ (UINavigationController *)currentNavigationController
{
    UINavigationController *nvc = [UIWindow uxy_optimizedVisibleViewController].navigationController;
    return nvc;
}

+ (void)closeViewController:(UIViewController *)viewController animated:(BOOL)flag completion:(void (^)(void))completion
{
    NSArray *viewControllers = [viewController.navigationController viewControllers];
    if (viewControllers.count <= 1)
    {
        [viewController dismissViewControllerAnimated:flag completion:completion];
    }
    else
    {
        [viewController.navigationController popViewControllerAnimated:flag];
    }
}
#pragma mark - private
+ (UINavigationController *)__visibleNavigationController
{
    UIViewController *vc = [self __visibleViewControllerWithRootViewController:[UIApplication sharedApplication].delegate.window.rootViewController];
    UINavigationController *nvc = (UINavigationController *)([vc isKindOfClass:[UINavigationController class]] ? vc : vc.navigationController);
    return nvc;
}

+ (UIViewController *)__visibleViewController
{
    UIViewController *vc = [self __visibleViewControllerWithRootViewController:[UIApplication sharedApplication].delegate.window.rootViewController];
    return vc;
}

+ (UIViewController*)__visibleViewControllerWithRootViewController:(UIViewController*)rootViewController
{
    if ([rootViewController isKindOfClass:[UITabBarController class]])
    {
        UITabBarController *tbc = (UITabBarController*)rootViewController;
        return [self __visibleViewControllerWithRootViewController:tbc.selectedViewController];
    }
    else if ([rootViewController isKindOfClass:[UINavigationController class]])
    {
        UINavigationController *nvc = (UINavigationController*)rootViewController;
        return [self __visibleViewControllerWithRootViewController:nvc.visibleViewController];
    }
    else if (rootViewController.presentedViewController)
    {
        UIViewController *presentedVC = rootViewController.presentedViewController;
        return [self __visibleViewControllerWithRootViewController:presentedVC];
    }
    else
    {
        return rootViewController;
    }
}

@end


#pragma mark -
static const char *PARouter_router_path = "PA.UIViewController.routerPath";

@implementation UIViewController (QHRouter)

- (NSString *)router_path
{
    return objc_getAssociatedObject(self, PARouter_router_path);
}

- (void)setRouter_path:(NSString *)router_path
{
    objc_setAssociatedObject(self, PARouter_router_path, router_path, OBJC_ASSOCIATION_COPY_NONATOMIC);
}


@end
