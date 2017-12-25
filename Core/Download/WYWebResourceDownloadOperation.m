//
//  WYWebResourceDownloadOperation.m
//  WYWebResource
//
//  Created by wyan assert on 2017/8/11.
//  Copyright © 2017年 wyan assert. All rights reserved.
//

#import "WYWebResourceDownloadOperation.h"
#import "AFNetWorking.h"

static NSString *const kProgressCallbackKey = @"progress";
static NSString *const kDownloadCallbackKey = @"download";

@interface WYWebResourceDownloadOperation()

@property (strong, nonatomic, readwrite, nullable) NSURLRequest *request;

@property (strong, nonatomic, nonnull ) NSMutableArray<WYWebResourceDownloadCancelToken> *callbackBlocks;
@property (strong, nonatomic, nonnull ) dispatch_queue_t barrierQueue;
@property (strong, nonatomic, nullable) NSURLSessionTask *dataTask;
@property (nonatomic, strong, nullable) NSString         *savePath;

@end

@implementation WYWebResourceDownloadOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

#pragma mark - lifeCycle
- (instancetype)initWithRequest:(NSURLRequest *)request savePath:(NSString *)savePath {
    if (self = [super init]) {
        _request = request;
        _savePath = savePath;
        _callbackBlocks = [NSMutableArray array];
        _executing = NO;
        _finished = NO;
        _barrierQueue = dispatch_queue_create("com.wyanassert.WYWebResourceDownloadOperation", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)dealloc {
#ifndef OS_OBJECT_USE_OBJC
    dispatch_release(_downloadQueue);
#endif
}

#pragma mark - Public

- (WYWebResourceDownloadCancelToken _Nonnull)addHandlersForProgress:(WYWebResourceProgressBlock)progressBlock
                                                          completed:(WYWebResourceDownloadBlock)completedBlock {
    WYWebResourceDownloadCancelToken callbacks = [NSMutableDictionary new];
    if (progressBlock) callbacks[kProgressCallbackKey] = [progressBlock copy];
    if (completedBlock) callbacks[kDownloadCallbackKey] = [completedBlock copy];
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks addObject:callbacks];
    });
    return callbacks;
}

- (BOOL)cancel:(WYWebResourceDownloadCancelToken _Nonnull)token {
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
    
    if (self.dataTask) {
        [self.dataTask cancel];
        
        if (self.isExecuting) {
            self.executing = NO;
        }
        if (!self.isFinished) {
            //system use KVO observe "isFinished" property, so, when finished changed to YES, will call completionBlock of NSOperation. Even if operation not start yet. PS. completionBlock can be called only once at all.
            self.finished = YES;
        }
    }
    // cancel will not callback
    [self reset];
}

- (void)reset {
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks removeAllObjects];
    });
    self.dataTask = nil;
}

- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void)callCompletionBlocksWithTargetURL:(nullable NSURL *)targetURL
                                    error:(nullable NSError *)error {
    NSArray<WYWebResourceDownloadBlock> *completionBlocks = [self callbacksForKey:kDownloadCallbackKey];
    dispatch_main_async_safe(^{
        for(WYWebResourceDownloadBlock downloadBlock in completionBlocks) {
            downloadBlock(error, targetURL);
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
        self.dataTask = [[AFHTTPSessionManager manager] downloadTaskWithRequest:self.request
                                                                       progress:^(NSProgress * _Nonnull downloadProgress) {
                                                                           __strong typeof(weakSelf)self = weakSelf;
                                                                           for (WYWebResourceProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
                                                                               progressBlock(downloadProgress, self.request.URL);
                                                                           }
                                                                       }
                                                                    destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                                                                        __strong typeof(weakSelf)self = weakSelf;
                                                                        return [NSURL fileURLWithPath:[self.savePath stringByAppendingPathComponent:[self.request.URL lastPathComponent]]];
                                                                        
                                                                    }
                                                              completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                                                                  __strong typeof(weakSelf)self = weakSelf;
                                                                  [self callCompletionBlocksWithTargetURL:filePath error:error];
                                                                  [self done];
                                                              }];
        [self.dataTask resume];
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

@end
