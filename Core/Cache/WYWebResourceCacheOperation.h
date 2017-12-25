//
//  WYWebResourceCacheOperation.h
//  WYWebResource
//
//  Created by wyan assert on 2017/8/15.
//  Copyright © 2017年 wyan assert. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WYWebResourceCache.h"
#import "SSZipArchive.h"

@interface WYWebResourceCacheOperation : NSOperation
NS_ASSUME_NONNULL_BEGIN

@property (strong, nonatomic, readonly) NSURL *url;
@property (strong, nonatomic, readonly) NSURL *resourcePath;
@property (strong, nonatomic, readonly) NSURL *extractDir;

- (instancetype)initWithUrl:(NSURL *)url
               resourcePath:(NSURL *)resourcePath
                 extractDir:(NSURL *)extractDir;

- (WYWebResourceExtractCancelToken _Nonnull)addHandlersForProgress:(void (^)(long entryNumber, long total))progressBlock
                                                          completed:(void (^)(NSString *path, BOOL succeeded, NSError * __nullable error))completedBlock
                                                        allExcuted:(WYWebResourceNoParamBlock)executedBlock;

- (BOOL)cancel:(WYWebResourceExtractCancelToken _Nonnull)token;

NS_ASSUME_NONNULL_END
@end
