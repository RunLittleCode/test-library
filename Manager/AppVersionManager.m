//
//  AppVersionManager.m
//  xiaodai
//
//  Created by liuguanchen on 2017/3/16.
//  Copyright © 2017年 liuguanchen. All rights reserved.
//

#import "AppVersionManager.h"
#import "TJNormalAlertView.h"
#import "TJUpdateInfo.h"
#import "TJUpdateClient.h"

typedef NS_ENUM(NSInteger, UpdateStatusType) {
    NeedUpdateType = 0,
    NeedForceUpdateType = 1,
};

@interface AppVersionManager()<TJNormalAlertViewDelegate>
{
    TJUpdateInfo * updateInfo;
    BOOL isLoading;
}

@end

@implementation AppVersionManager

+ (instancetype)sharedManager
{
    static AppVersionManager *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once (&onceToken, ^{
        _sharedClient = [[AppVersionManager alloc] init];
        
    });
    
    return _sharedClient;
}

- (void)checkShouldUpdateVersion {
    if (updateInfo) {
        if (updateInfo.updateStatus == NeedForceUpdateType) {
            TJNormalAlertView * alertView = [[TJNormalAlertView alloc] initWithMessage:updateInfo.updateDesc cancelButton:@"去升级" confirmButton:nil andDelegate:self];
            [alertView showAlert];
        }
        return;
    }
    if (isLoading) {
        return;
    }
    isLoading = YES;
    __weak typeof(self) weakslef = self;
    [TJUpdateClient checkAppNeedUpdateVersionWithCompletion:^(BOOL success, TJUpdateInfo * info) {
        [weakslef handCheckUpdateRequestWithSuccess:success andUpdateInfo:info];
    }];
}

- (void)handCheckUpdateRequestWithSuccess:(BOOL)success andUpdateInfo:(TJUpdateInfo *)update {
    isLoading = NO;
    if (success && update) {
        if (update.updateUrl && [update.updateUrl length] > 0) {
            updateInfo = update;
            if (updateInfo.updateStatus == NeedUpdateType) {
                TJNormalAlertView * alertView = [[TJNormalAlertView alloc] initWithMessage:updateInfo.updateDesc cancelButton:@"去升级" confirmButton:@"取消" andDelegate:self];
                [alertView showAlert];
            }else if (updateInfo.updateStatus == NeedForceUpdateType){
                TJNormalAlertView * alertView = [[TJNormalAlertView alloc] initWithMessage:updateInfo.updateDesc cancelButton:@"去升级" confirmButton:nil andDelegate:self];
                [alertView showAlert];
            }
        }
    }
}


#pragma mark - TJNormalAlertViewDelegate
- (void)alertViewClickCancelButton:(TJNormalAlertView *)alertView {
    if ([UIDevice currentDevice].systemVersion.floatValue > 10.0f) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:updateInfo.updateUrl] options:@{} completionHandler:nil];
    }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:updateInfo.updateUrl]];
#pragma clang diagnostic pop
    }
    
}

- (void)alertViewClickConfirmButton:(TJNormalAlertView *)alertView {
    
}

@end
