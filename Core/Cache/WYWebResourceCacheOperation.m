//
//  WYWebResourceCacheOperation.m
//  WYWebResource
//
//  Created by wyan assert on 2017/8/15.
//  Copyright © 2017年 wyan assert. All rights reserved.
//

#import "WYWebResourceCacheOperation.h"

static NSString *const kProgressCallbackKey = @"progress";
static NSString *const kExtractCallbackKey = @"extract";
static NSString *const kExecutedCallbackKey = @"executed";

@interface WYWebResourceCacheOperation()

@property (strong, nonatomic, readwrite) NSURL *url;
@property (strong, nonatomic, readwrite) NSURL *resourcePath;
@property (strong, nonatomic, readwrite) NSURL *extractDir;

@property (strong, nonatomic, nonnull ) NSMutableArray<WYWebResourceExtractCancelToken> *callbackBlocks;
@property (strong, nonatomic, nonnull ) dispatch_queue_t barrierQueue;

@end

@implementation WYWebResourceCacheOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

#pragma mark - LifeCycle
- (instancetype)initWithUrl:(NSURL *)url resourcePath:(NSURL *)resourcePath extractDir:(NSURL *)extractDir {
    if(self = [super init]) {
        _url = url;
        _resourcePath = resourcePath;
        _extractDir = extractDir;
        
        _callbackBlocks = [NSMutableArray array];
        _executing = NO;
        _finished = NO;
        
        _barrierQueue = dispatch_queue_create("com.wyanassert.WYWebResourceExtractOperation", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}


- (void)dealloc {
#ifndef OS_OBJECT_USE_OBJC
    dispatch_release(_downloadQueue);
#endif
}


#pragma mark - Public
- (WYWebResourceExtractCancelToken _Nonnull)addHandlersForProgress:(void (^)(long, long))progressBlock completed:(void (^)(NSString * _Nonnull, BOOL, NSError * _Nullable))completedBlock allExcuted:(nonnull WYWebResourceNoParamBlock)executedBlock {
    WYWebResourceDownloadCancelToken callbacks = [NSMutableDictionary new];
    if (progressBlock) callbacks[kProgressCallbackKey] = [progressBlock copy];
    if (completedBlock) callbacks[kExtractCallbackKey] = [completedBlock copy];
    if (executedBlock) callbacks[kExecutedCallbackKey] = [executedBlock copy];
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks addObject:callbacks];
    });
    return callbacks;
}

- (BOOL)cancel:(WYWebResourceExtractCancelToken _Nonnull)token {
    __block BOOL shouldCancel = NO;
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        [self.callbackBlocks removeObjectIdenticalTo:token];
        if (self.callbackBlocks.count == 0) {
            shouldCancel = YES;
        }
    });
    
    if (shouldCancel) {
        [self cancel];
    }
    return shouldCancel;
}


#pragma mark - Private
- (void)cancelInternal {
    if (self.isFinished) {
        return ;
    }
    [super cancel];
    
    if (self.isExecuting) {
        self.executing = NO;
    }
    if (!self.isFinished) {
        //system use KVO observe "isFinished" property, so, when finished changed to YES, will call completionBlock of NSOperation. Even if operation not start yet. PS. completionBlock can be called only once at all.
        self.finished = YES;
    }
    // cancel will not callback
    [self reset];
}

- (void)reset {
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks removeAllObjects];
    });
}

- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void)callCompletionBlocksWithPath:(NSString *)path
                             success:(BOOL)succeeded
                               error:(nullable NSError *)error {
    NSArray<void (^)(NSString * _Nonnull, BOOL, NSError * _Nullable)> *completionBlocks = [self callbacksForKey:kExtractCallbackKey];
    NSArray<WYWebResourceNoParamBlock> *executedBlocks = [self callbacksForKey:kExecutedCallbackKey];
    dispatch_main_async_safe(^{
        for(void (^downloadBlock)(NSString * _Nonnull, BOOL, NSError * _Nullable) in completionBlocks) {
            downloadBlock(path, succeeded, error);
        }
        if(executedBlocks.count > 0) {
            [executedBlocks lastObject]();
        }
    });
}

- (nullable NSArray<id> *)callbacksForKey:(NSString *)key {
    __block NSMutableArray<id> *callbacks = nil;
    dispatch_sync(self.barrierQueue, ^{
        // We need to remove [NSNull null] because there might not always be a progress block for each callback
        callbacks = [[self.callbackBlocks valueForKey:key] mutableCopy];
        [callbacks removeObjectIdenticalTo:[NSNull null]];
    });
    return [callbacks copy];
}


#pragma mark - Override
- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }
        __weak typeof(self)weakSelf = self;
        
        [SSZipArchive unzipFileAtPath:self.resourcePath.path
                        toDestination:self.extractDir.path
                      progressHandler:^(NSString * _Nonnull entry, unz_file_info zipInfo, long entryNumber, long total) {
                          
                      }
                    completionHandler:^(NSString * _Nonnull path, BOOL succeeded, NSError * _Nullable error) {
                        __strong typeof(weakSelf)self = weakSelf;
                        [self callCompletionBlocksWithPath:path success:succeeded error:error];
                        [self done];
                    }];
    }
}

- (void)cancel {
    @synchronized (self) {
        [self cancelInternal];
    }
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

#pragma mark - Getter


@end
