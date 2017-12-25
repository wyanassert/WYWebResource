//
//  WYWebResourceManager.m
//  WYWebResource
//
//  Created by wyan assert on 2017/8/11.
//  Copyright © 2017年 wyan assert. All rights reserved.
//

#import "WYWebResourceManager.h"
#import "WYWebResourceDownloader.h"
#import "WYWebResourceCache.h"

NSString *const kWYWebResource                                = @"resource";
NSString *const kOverlayFilter                                = @"overlay";
NSString *const kPhotoFilter                                  = @"filter";

NSString *const kPhotoSubResourceFont                         = @"font";
NSString *const kPhotoSubResourceImage                        = @"image";
NSString *const kPhotoSubResourceFilter                       = @"filter";
NSString *const kPhotoSubResourceOverlay                      = @"overlay";

#define kWYWebResourceFolder        @"WYWebResource"
#define kResourceFolder             @"resourceFolder"
#define kResourceExtractFolder      @"extractFolder"
#define kResourceIndexFolder        @"indexFolder"

#define kCachePath (NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0])
#define kLibraryPath (NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0])

@interface WYWebResourceCombinedOperation : NSObject <WYWebResourceOperation>

@property (strong, nonatomic, nullable) NSURL *url;
@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
@property (copy  , nonatomic, nullable) WYWebResourceNoParamBlock cancelBlock;
@property (strong, nonatomic, nullable) NSOperation *cacheOperation;

@end

@implementation WYWebResourceCombinedOperation

- (void)setCancelBlock:(nullable WYWebResourceNoParamBlock)cancelBlock {
    // check if the operation is already cancelled, then we just call the cancelBlock
    if (self.isCancelled) {
        if (cancelBlock) {
            cancelBlock();
        }
        _cancelBlock = nil;
    } else {
        _cancelBlock = [cancelBlock copy];
    }
}

- (void)cancel {
    self.cancelled = YES;
    if (self.cacheOperation) {
        [self.cacheOperation cancel];
        self.cacheOperation = nil;
    }
    if (self.cancelBlock) {
        self.cancelBlock();
        _cancelBlock = nil;
    }
}

@end

@interface WYWebResourceManager()

@property (nonatomic, strong) WYWebResourceDownloader         *downloader;
@property (nonatomic, strong) WYWebResourceCache              *cache;
@property (strong, nonatomic, nonnull) NSMutableArray<WYWebResourceCombinedOperation *> *runningOperations;

@end

@implementation WYWebResourceManager

+ (instancetype)sharedManager {
    static WYWebResourceManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [WYWebResourceManager new];
    });
    return instance;
}

- (void)requestWYWebResource:(NSURL *)url
                    progress:(WYWebResourceProgressBlock)progressBlock
                  completion:(WYWebResourceCompletionBlock)completionBlock {
    __block WYWebResourceCombinedOperation *operation = [WYWebResourceCombinedOperation new];
    __weak WYWebResourceCombinedOperation *weakOperation = operation;
    operation.url = url;
    @synchronized (self.runningOperations) {
        [self.runningOperations addObject:operation];
    }
    
    operation.cacheOperation = [self.cache queryCacheOperationForKey:url done:^(NSDictionary * _Nullable resourceInfo, NSURL * _Nullable url, NSError * _Nullable error) {
        __strong __typeof(weakOperation) strongOperation = weakOperation;
        if(operation.isCancelled) {
            [self safelyRemoveOperationFromRunning:strongOperation];
        }
        
        if(!resourceInfo) {
            if([url isFileURL]) {
                NSURL *resourcePath = url;
                if([self.cache copyResourceTo:[NSURL fileURLWithPath:[[self subResourcePath:kResourceFolder]
                                                                      stringByAppendingPathComponent:[url lastPathComponent]]]
                               fromMainBundle:url]) {
                    resourcePath = [NSURL fileURLWithPath:[[self subResourcePath:kResourceFolder]
                                                           stringByAppendingPathComponent:[url lastPathComponent]]];
                }
                __weak typeof(self)weakSelf = self;
                [self.cache storeData:url
                             fromPath:resourcePath
                     extractDirectory:[NSURL fileURLWithPath:[self subResourcePath:kResourceExtractFolder]]
                      moveToDirectory:[NSURL fileURLWithPath:[self downloadWorkspacePath]]
                           completion:^(NSDictionary * _Nullable resourceInfo, NSURL * _Nullable url, NSError * _Nonnull error) {
                               __strong typeof(weakSelf)self = weakSelf;
                               [self callCompletionBlockForOperation:strongOperation
                                                          completion:completionBlock
                                                        resourceInfo:resourceInfo
                                                               error:error
                                                            finished:YES
                                                                 url:url];
                           }];
            } else {
                __weak typeof(self)weakSelf = self;
                WYWebResourceDownloadToken *downloadToken = [self.downloader requestWYWebResourceWithResourceId:url saveFolder:[self subResourcePath:kResourceFolder] progress:progressBlock comloetion:^(NSError *error, NSURL *targetURL) {
                    __strong typeof(weakSelf)self = weakSelf;
                    if(!error && targetURL.absoluteString.length) {
                        //extract resource bundle here, call cache module
                        __weak typeof(self)weakSelf = self;
                        [self.cache storeData:url
                                     fromPath:targetURL
                             extractDirectory:[NSURL fileURLWithPath:[self subResourcePath:kResourceExtractFolder]]
                              moveToDirectory:[NSURL fileURLWithPath:[self downloadWorkspacePath]]
                                   completion:^(NSDictionary * _Nullable resourceInfo, NSURL * _Nullable url, NSError * _Nonnull error) {
                                       __strong typeof(weakSelf)self = weakSelf;
                                       [self callCompletionBlockForOperation:strongOperation
                                                                  completion:completionBlock
                                                                resourceInfo:resourceInfo
                                                                       error:error
                                                                    finished:YES
                                                                         url:url];
                                   }];
                    } else {
                        [self callCompletionBlockForOperation:strongOperation
                                                   completion:completionBlock
                                                 resourceInfo:nil
                                                        error:error
                                                     finished:NO
                                                          url:url];
                    }
                }];
                operation.cancelBlock = ^{
                    [self.downloader cancelRequestForResource:downloadToken];
                    __strong __typeof(weakOperation) strongOperation = weakOperation;
                    [self safelyRemoveOperationFromRunning:strongOperation];
                };
            }
        } else if(resourceInfo && !error) {
            // find cache success.
            [self callCompletionBlockForOperation:strongOperation completion:completionBlock resourceInfo:resourceInfo error:error finished:YES url:url];
            [self safelyRemoveOperationFromRunning:strongOperation];
        } else {
            // resource and error are not nil. nerer reach
            [self callCompletionBlockForOperation:strongOperation completion:completionBlock resourceInfo:nil error:error finished:NO url:url];
            [self safelyRemoveOperationFromRunning:strongOperation];
        }
    }];
}

- (NSDictionary<NSURL *, NSDictionary *> *)localResource:(NSString *)resourceType withCheckFileExist:(BOOL)willCheck {
    return [self.cache localResource:resourceType withCheckFileExist:willCheck];
}

- (void)cancelRequestForResource:(NSURL *)url {
    @synchronized (self.runningOperations) {
        for (WYWebResourceCombinedOperation *combinedOperation in self.runningOperations) {
            if([combinedOperation.url.absoluteString isEqualToString:url.absoluteString]) {
                [combinedOperation cancel];
            }
        }
    }
}

- (void)cancelAllRequest {
    @synchronized (self.runningOperations) {
        NSArray<WYWebResourceCombinedOperation *> *copiedOperations = [self.runningOperations copy];
        [copiedOperations makeObjectsPerformSelector:@selector(cancel)];
        [self.runningOperations removeObjectsInArray:copiedOperations];
    }
}

- (BOOL)isResourceAvailable:(NSURL *)url {
    return [self.cache resourceInfoFromIndexForKey:url] != nil;
}

- (BOOL)isSubResourceAvailable:(NSString *)type subResourceName:(NSString *)resourceName {
    NSString *subResourcePath = [[self subResourcePath:type] stringByAppendingPathComponent:resourceName];
    return [self.cache isSubResourceExist:subResourcePath];
}

- (void)deleteCache:(NSURL *)url {
    [self.cache deleteResource:url];
}

- (void)deleteAllCache {
    [self.cache deleteAllResource:[self downloadWorkspacePath]];
}


#pragma mark - Private
- (NSString *)downloadWorkspacePath {
    NSString *workPath = [self.storePath stringByAppendingPathComponent:kWYWebResourceFolder];
    if(![[NSFileManager defaultManager] fileExistsAtPath:workPath]) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:workPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
    }
    return workPath;
}

- (NSString *)subResourcePath:(NSString *)subResourceType {
    NSString *workPath = [self downloadWorkspacePath];
    NSString *subResourcePath = [workPath stringByAppendingPathComponent:subResourceType];
    if(![[NSFileManager defaultManager] fileExistsAtPath:subResourcePath]) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:subResourcePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
    }
    return subResourcePath;
}

- (void)safelyRemoveOperationFromRunning:(nullable WYWebResourceCombinedOperation*)operation {
    @synchronized (self.runningOperations) {
        if (operation) {
            [self.runningOperations removeObject:operation];
        }
    }
}

- (void)callCompletionBlockForOperation:(nullable WYWebResourceCombinedOperation*)operation
                             completion:(nullable WYWebResourceCompletionBlock)completionBlock
                           resourceInfo:(nullable NSDictionary *)resourceInfo
                                  error:(nullable NSError *)error
                               finished:(BOOL)finished
                                    url:(nullable NSURL *)url {
    dispatch_main_async_safe(^{
        if (operation && !operation.isCancelled && completionBlock) {
            completionBlock(resourceInfo, error, url);
        }
    });
}

#pragma mark - Getter
- (NSString *)storePath {
    if(!_storePath) {
        _storePath = kLibraryPath;
    }
    return _storePath;
}

- (NSArray<NSString *> *)cacheTypeList {
    if(!_cacheTypeList) {
        _cacheTypeList = @[kPhotoSubResourceFont, kPhotoSubResourceImage, kPhotoSubResourceOverlay, kPhotoSubResourceFilter];
    }
    return _cacheTypeList;
}

- (WYWebResourceDownloader *)downloader {
    if(!_downloader) {
        _downloader = [WYWebResourceDownloader sharedDownloader];
    }
    return _downloader;
}

- (WYWebResourceCache *)cache {
    if(!_cache) {
        _cache = [WYWebResourceCache sharedCache];
        _cache.indexSavePath = [self subResourcePath:kResourceIndexFolder];
    }
    return _cache;
}

- (NSMutableArray<WYWebResourceCombinedOperation *> *)runningOperations {
    if(!_runningOperations) {
        _runningOperations = [NSMutableArray array];
    }
    return _runningOperations;
}

@end
