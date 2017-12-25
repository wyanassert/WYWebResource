//
//  WYWebResourceManager.h
//  WYWebResource
//
//  Created by wyan assert on 2017/8/11.
//  Copyright © 2017年 wyan assert. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WYWebResourceDownloader.h"
#import "WYWebResourceDef.h"
#import "WYWebResourceOperation.h"

extern NSString *const kWYWebResource;
extern NSString *const kOverlayFilter;
extern NSString *const kPhotoFilter;

extern NSString * const kPhotoSubResourceFont;
extern NSString * const kPhotoSubResourceImage;
extern NSString * const kPhotoSubResourceFilter;
extern NSString * const kPhotoSubResourceOverlay;

@interface WYWebResourceManager : NSObject

@property (nonatomic, strong) NSString         *storePath;
@property (nonatomic, strong) NSArray<NSString *> *cacheTypeList;

+ (instancetype)sharedManager;

- (void)requestWYWebResource:(NSURL *)url
                    progress:(WYWebResourceProgressBlock)progressBlock
                  completion:(WYWebResourceCompletionBlock)completionBlock;

- (void)requestWYWebResource:(NSURL *)url
                       zipPw:(NSString *)password
                    progress:(WYWebResourceProgressBlock)progressBlock
                  completion:(WYWebResourceCompletionBlock)completionBlock;

- (NSDictionary<NSURL *, NSDictionary *> *)localResource:(NSString *)resourceType withCheckFileExist:(BOOL)willCheck;

- (void)cancelRequestForResource:(NSURL *)url;

- (void)cancelAllRequest;

- (BOOL)isResourceAvailable:(NSURL *)url;

- (BOOL)isSubResourceAvailable:(NSString *)type subResourceName:(NSString *)resourceName;

- (void)deleteCache:(NSURL *)url;

- (void)deleteAllCache;

@end
