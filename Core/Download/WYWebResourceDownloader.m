//
//  WYWebResourceDownloader.m
//  WYWebResource
//
//  Created by wyan assert on 2017/8/11.
//  Copyright © 2017年 wyan assert. All rights reserved.
//

#import "WYWebResourceDownloader.h"
#import "AFNetworking.h"
#import "WYWebResourceDownloadOperation.h"

@interface WYWebResourceDownloader()

@property (strong, nonatomic, nonnull ) NSOperationQueue *downloadQueue;
@property (strong, nonatomic, nonnull ) NSMutableDictionary<NSURL *, WYWebResourceDownloadOperation *> *URLOperations;
@property (strong, nonatomic, nullable) dispatch_queue_t barrierQueue;

@end

@implementation WYWebResourceDownloader

#pragma mark - LifeCycle
- (instancetype)init {
    if(self = [super init]) {
        _downloadQueue = [NSOperationQueue new];
        _downloadQueue.maxConcurrentOperationCount = 5;
        _downloadQueue.name = @"com.wyanassert.WYWebResourceDownloader";
        
        _URLOperations = [NSMutableDictionary dictionary];
        
        _barrierQueue = dispatch_queue_create("com.wyanassert.WYWebResourceDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)dealloc {
    [_downloadQueue cancelAllOperations];
#ifndef OS_OBJECT_USE_OBJC
    dispatch_release(_barrierQueue);
#endif
}

#pragma mark - Public
+ (instancetype)sharedDownloader {
    static WYWebResourceDownloader *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [WYWebResourceDownloader new];
    });
    return instance;
}

- (WYWebResourceDownloadToken *)requestWYWebResourceWithResourceId:(NSURL *)url
                                                        saveFolder:(NSString *)savePath
                                                          progress:(WYWebResourceProgressBlock)progressBlock
                                                        comloetion:(WYWebResourceDownloadBlock)completionBlock {
    __weak typeof(self)weakSelf = self;
   return [self addProgressCallback:progressBlock
                   downloadCallback:completionBlock
                             forURL:url
                     createCallback:^WYWebResourceDownloadOperation *{
                         
                         WYWebResourceDownloadOperation *operation = [[WYWebResourceDownloadOperation alloc] initWithRequest:[NSURLRequest requestWithURL:url] savePath:savePath];
                         operation.queuePriority = NSOperationQueuePriorityHigh;
                         
                         [weakSelf.downloadQueue addOperation:operation];
                         //Do more with operation if need in the future. -- wyan
                         
                         return operation;
                     }];
}

- (void)cancelRequestForResource:(WYWebResourceDownloadToken *)token {
    if(token) {
        dispatch_barrier_async(self.barrierQueue, ^{
            WYWebResourceDownloadOperation *operation = self.URLOperations[token.url];
            BOOL canceled = [operation cancel:token.downloadOperationCancelToken];
            if (canceled) {
                [self.URLOperations removeObjectForKey:token.url];
            }
        });
    }
}

- (void)cancelAllRequest {
    /*  Canceling the operations does not automatically remove them from the queue or stop those that are currently executing.
        For operations that are queued and waiting execution, the queue must still attempt to execute the operation before recognizing that it is canceled and moving it to the finished state.
        For operations that are already executing, the operation object itself must check for cancellation and stop what it is doing so that it can move to the finished state.
        In both cases, a finished (or canceled) operation is still given a chance to execute its completion block before it is removed from the queue.*/
    [self.downloadQueue cancelAllOperations];
}


#pragma mark - Private
- (WYWebResourceDownloadToken *)addProgressCallback:(WYWebResourceProgressBlock)progressBlock
                                       downloadCallback:(WYWebResourceDownloadBlock)downloadBlock
                                                 forURL:(NSURL *)url
                                         createCallback:(WYWebResourceDownloadOperation *(^)(void))createCallback {
    if(url == nil) {
        if(downloadBlock) {
            downloadBlock([NSError errorWithDomain:@"com.wyanassert.WYWebResourceDownloader" code:kWYWebResourceErrorUrlIsNil userInfo:@{@"message" : @"url should not be nil"}], nil);
        }
        return nil;
    }
    
    __block WYWebResourceDownloadToken  *token = nil;
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        WYWebResourceDownloadOperation *operation = self.URLOperations[url];
        if(!operation) {
            operation = createCallback();
            self.URLOperations[url] = operation;
            __weak WYWebResourceDownloadOperation *woperation = operation;
            operation.completionBlock = ^{
                WYWebResourceDownloadOperation *soperation = woperation;
                if (!soperation) {
                    return ;
                }
                dispatch_barrier_async(self.barrierQueue, ^{
                    if (self.URLOperations[url] == soperation) {
                        [self.URLOperations removeObjectForKey:url];
                    };
                });
            };
        }

        WYWebResourceDownloadCancelToken downloadCancelToken = [operation addHandlersForProgress:progressBlock
                                                                                       completed:downloadBlock];
        token.url = url;
        token.downloadOperationCancelToken = downloadCancelToken;
    });

    return token;
}

@end
