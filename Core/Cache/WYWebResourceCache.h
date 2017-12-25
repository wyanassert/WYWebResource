//
//  WYWebResourceCache.h
//  WYWebResource
//
//  Created by wyan assert on 2017/8/13.
//  Copyright © 2017年 wyan assert. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WYWebResourceDef.h"

@interface WYWebResourceCacheToken : NSObject

@property (nonatomic, strong, nullable) NSURL *url;
@property (nonatomic, strong, nullable) WYWebResourceExtractCancelToken extractOperationCancelToken;

@end

@interface WYWebResourceCache : NSObject

@property (nonatomic, strong) NSString * _Nullable indexSavePath;

+ (instancetype _Nonnull)sharedCache;

- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSURL *)url
                                               done:(WYWebResourceCacheQueryBlock _Nullable)doneBlock;

- (void)storeData:(NSURL *_Nonnull)url
         fromPath:(NSURL *_Nonnull)resourcePath
 extractDirectory:(NSURL *_Nonnull)extractDir
  moveToDirectory:(NSURL *_Nonnull)moveToDir
       completion:(WYWebResourceCacheQueryBlock _Nullable)block;

- (NSDictionary *_Nullable)resourceInfoFromIndexForKey:(NSURL *_Nonnull)url;

- (void)resourceInfoFromResourceBundle:(NSURL *_Nonnull)url completion:(WYWebResourceCacheQueryBlock _Nullable)block;

- (BOOL)isSubResourceExist:(NSString *_Nonnull)path;

- (void)deleteResource:(NSURL *_Nonnull)url;

- (void)deleteAllResource:(NSString *_Nonnull)workDir;

- (BOOL)copyResourceTo:(NSURL *_Nonnull)resourcePath fromMainBundle:(NSURL *_Nonnull)url;

- (NSDictionary<NSURL *,NSDictionary *> *_Nullable)localResource:(NSString *)resourceType withCheckFileExist:(BOOL)willCheck;

@end
