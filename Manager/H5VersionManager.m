//
//  H5VersionManager.m
//  xiaodai
//
//  Created by liuguanchen on 2017/3/16.
//  Copyright © 2017年 liuguanchen. All rights reserved.
//

#import "H5VersionManager.h"
#import "SSZipArchive.h"
#import "TJUpdateClient.h"
#import "RSADecrypt.h"
#import "CommonMacro.h"
#import "ToolMacro.h"
#import "TJUpdateInfo.h"
#import "AFNetworking.h"
#import "PAFileSizeCheckClass.h"
#import "sys/xattr.h"

#define MIAOJIE_H5_CURRENT_VERSION @"20170425193351"

#define H5UpdateIntervalTime 60*3

@interface H5VersionManager()
{
    NSString * modelName;
    NSString * bundlPath;
    NSString * currentVersion;
    NSDate * lastUpdateTime;
}
@property (nonatomic, copy) void(^handBlock)();

@end

@implementation H5VersionManager

+ (instancetype)shareManager
{
    static H5VersionManager *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once (&onceToken, ^{
        _sharedClient = [[self alloc] init];
        
    });
    
    return _sharedClient;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self notUploadToiCloud];
        modelName = @"loan";
        currentVersion = [H5VersionManager getCurrentHtmlVersion];
        if ([currentVersion compare:MIAOJIE_H5_CURRENT_VERSION] == NSOrderedAscending) {
            [H5VersionManager setHtmlFileUnzip:NO];
        }
        bundlPath = [[NSBundle mainBundle] pathForResource: @"loan" ofType: @"zip"];
    }
    return self;
}

- (void)setupHtmlFileWithBlock:(void (^)())block {
    _handBlock = [block copy];
    BOOL hasUnzip = [H5VersionManager checkHtmlFileHasUnzip];
    if (hasUnzip) {
        [self checkIsNeedUpdateHtmlFile];
    }else{
        [self loadLocalHtmlFile];
    }
}

#pragma mark - unzip local file
- (void)loadLocalHtmlFile {
    [H5VersionManager clearH5Resource];
    __weak typeof(self) weakself = self;
    NSString *filePath = [bundlPath copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (filePath && [filePath length] > 0) {
            [weakself copyAndUnzipLocalFile];
        }else{
            
        }
    });
}

- (void)copyAndUnzipLocalFile {
    if (!bundlPath || [bundlPath length] ==0) {
        if (_handBlock) {
            DDLogError(@"bundle file not exit");
            _handBlock();
        }
        return;
    }
    //Tmp路径
    NSString *tempPath = NSTemporaryDirectory();
    NSString *zipTempPath = [tempPath stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.zip",currentVersion]];
    
    //判断文件是否存在
    NSError *copyError;
    if ([[NSFileManager defaultManager] fileExistsAtPath:zipTempPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:zipTempPath error: nil];
    }
    //复制文件
    [[NSFileManager defaultManager] copyItemAtPath:bundlPath toPath:zipTempPath error:&copyError];
    
    if (copyError)
    {
        if (_handBlock) {
            DDLogError(@"copy local h5 fail");
            _handBlock();
        }
        return;
    }
    
    //html5目录
    NSString *htmlPath = [self getDocumentVersionPathWith:currentVersion];
    
    //删除旧文件
    [[NSFileManager defaultManager] removeItemAtPath:htmlPath error:nil];
    
    //解压文件到Document目录
    BOOL isUnZip = [SSZipArchive unzipFileAtPath:zipTempPath toDestination:htmlPath];
    
    if (isUnZip)
    {
        [H5VersionManager saveCurrentHtmlVersion:currentVersion];
        [H5VersionManager setHtmlFileUnzip:YES];
    }
    else
    {
        DDLogError(@"unzip local file fail");
    }
    if (_handBlock) {
        _handBlock();
    }
}

#pragma mark - check version & download
- (void)checkHtmlFileWithTimeWithBlock:(void (^)())block {
    if (lastUpdateTime) {
        NSDate * updateTime = [NSDate dateWithTimeInterval:H5UpdateIntervalTime sinceDate:lastUpdateTime];
        if ([updateTime compare:[NSDate date]] == NSOrderedAscending) {
            _handBlock = block;
            [self checkIsNeedUpdateHtmlFile];
        }
    }else{
        _handBlock = block;
        [self checkIsNeedUpdateHtmlFile];
    }
    
}

- (void)checkIsNeedUpdateHtmlFile{
#ifdef NeedUpdateH5
    __weak typeof(self) weakself = self;
    [TJUpdateClient checkHtmlNeedUpdateWithH5Version:currentVersion andCompletion:^(BOOL success, TJUpdateInfo *info) {
        [weakself handCheckNeedUpdate:success andInfo:info];
    }];
#else
    if (_handBlock) {
        _handBlock();
    }
#endif
}

- (void)handCheckNeedUpdate:(BOOL)success andInfo:(TJUpdateInfo *)info{
    if (success) {
        lastUpdateTime = [NSDate date];
        if (info && info.updateUrl) {
            NSString * resultMD5 = info.updateMD5;
            info.updateMD5 = [RSADecrypt decryptString:_STR(resultMD5) publicKey:Miaojie_RSA_PublicKey];
            [self downloadHtmlFileWithInfo:info];
        }else{
            DDLogInfo(@"h5 file 已经是最新版");
            if (_handBlock) {
                _handBlock();
            }
        }
    }else{
        if (_handBlock) {
            _handBlock();
        }
    }
}

- (void)downloadHtmlFileWithInfo:(TJUpdateInfo *)info {
    //模块名_增量名  zed_1001-1002.zip
    NSString *tmpFileName = [[info.updateUrl componentsSeparatedByString:@"/"] lastObject];
    tmpFileName = [NSString stringWithFormat:@"%@_%@",modelName,tmpFileName];
    
    NSString *tempPath = NSTemporaryDirectory();
    NSString *tmpFilePath = [tempPath stringByAppendingPathComponent:tmpFileName];
    //删除temp里面的旧增量包
    [self deleteTmpRerouceFile:tmpFilePath];
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:info.updateUrl]];
    
    NSURLSessionDownloadTask *task = [manager downloadTaskWithRequest:request
                                                             progress:nil
                  destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                      return [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", tmpFilePath]];
          } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
              if(error == nil){
                  NSString *fileMD5 = [PAFileSizeCheckClass getDownLoadFileMD5WithPath:tmpFilePath];
                  //校验下载zip包的MD5值(如果md5的值返回的为空，就不做md5校验，直接做资源解压更新)
                  if (!info.updateMD5 || info.updateMD5.length == 0)
                  {
                      if (_handBlock)
                      {
                          DDLogError(@"md5 not find");
                          _handBlock();
                      }
                      return ;
                  }
                  
                  BOOL isUnzip = NO;
                  NSString * currentPath = [self getDocumentVersionPathWith:currentVersion];
                  [[NSFileManager defaultManager] removeItemAtPath:currentPath error:nil];
                  //校验下载zip包的MD5值(如果md5的值返回的为空，就不做md5校验，直接做资源解压更新)
                  if (![[fileMD5 lowercaseString] isEqualToString:[info.updateMD5 lowercaseString]])
                  {
                      if (_handBlock)
                      {
                          DDLogError(@"md5 not equal");
                          _handBlock();
                      }
                      return ;
                  }
                  isUnzip = [SSZipArchive unzipFileAtPath:tmpFilePath toDestination:[self getDocumentVersionPathWith:info.lastVersion]];
                  if (isUnzip)
                  {
                      currentVersion = info.lastVersion;
                      [H5VersionManager saveCurrentHtmlVersion:currentVersion];
                      [H5VersionManager setHtmlFileUnzip:YES];
                  }
                  else
                  {
                      DDLogError(@"unzip local file fail");
                  }
                  if (_handBlock) {
                      _handBlock();
                  }
              }
              else{
                  if (_handBlock) {
                      _handBlock();
                  }
              }
              
          }];
    [task resume];
}

#pragma mark - path tool
- (NSString *)getDocumentVersionPathWith:(NSString *)version
{
    NSString *html5Path = [[self getDocumentPath] stringByAppendingPathComponent:@"html5"];
    [self checkPath:html5Path];
    
    NSString * path = [html5Path stringByAppendingPathComponent:version];
    [self checkPath:path];
    
    return path;
}

- (NSString *)getDocumentPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docPath = [paths objectAtIndex:0];
    
    return docPath;
}

- (BOOL)checkPath:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path] )
    {
        return [[NSFileManager defaultManager] createDirectoryAtPath:path
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:NULL];
    }
    
    return YES;
}
#pragma mark - file manage
- (void)notUploadToiCloud
{
    NSString *docPath = [self getDocumentPath];
    NSString *htmlPath = [docPath stringByAppendingPathComponent:@"html5"];
    
    [self addSkipBackupAttributeToPath:htmlPath];
    
    //tmp目录中的zip也不上传
    NSString *tempPath = NSTemporaryDirectory();
    [self addSkipBackupAttributeToPath:tempPath];
}

- (void)addSkipBackupAttributeToPath:(NSString*)path {
    u_int8_t b = 1;
    setxattr([path fileSystemRepresentation], "com.apple.MobileBackup", &b, 1, 0, 0);
}

+ (void)clearH5Resource
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docPath = [paths objectAtIndex:0];
    NSString *htmlPath = [docPath stringByAppendingPathComponent:@"html5"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:htmlPath])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:htmlPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }
    [[NSFileManager defaultManager] removeItemAtPath:htmlPath error:nil];
}

- (void) deleteTmpRerouceFile: (NSString *)deleteFileName{
    if ([[NSFileManager defaultManager] fileExistsAtPath: deleteFileName])
    {
        [[NSFileManager defaultManager] removeItemAtPath: deleteFileName error: nil];
    }
}
#pragma mark - check unzip
#define kFileIsZip @"miaojie_has_unzip"
+ (BOOL)checkHtmlFileHasUnzip {
    NSUserDefaults * userdefault = [NSUserDefaults standardUserDefaults];
    BOOL hasUnzip = [userdefault boolForKey:kFileIsZip];
    return hasUnzip;
}

+ (void)setHtmlFileUnzip:(BOOL)isUnzip {
    NSUserDefaults * userdefault = [NSUserDefaults standardUserDefaults];
    [userdefault setBool:isUnzip forKey:kFileIsZip];
    [userdefault synchronize];
}

#pragma mark - version manage
#define kFileCurrentVersion @"current_html_file_version"
+ (NSString *)getCurrentHtmlVersion {
    NSUserDefaults * userdefault = [NSUserDefaults standardUserDefaults];
    NSString * version = [userdefault stringForKey:kFileCurrentVersion];
    if (!version || [version length] == 0) {
        version = MIAOJIE_H5_CURRENT_VERSION;
    }
    return version;
}

+ (void)saveCurrentHtmlVersion:(NSString *)version {
    if (!version || [version length] == 0) {
        return;
    }
    NSUserDefaults * userdefault = [NSUserDefaults standardUserDefaults];
    [userdefault setObject:version forKey:kFileCurrentVersion];
    [userdefault synchronize];
}

#pragma mark - update time manage
#define kUpdateHtmlTime @"update_html_file_second"

@end
