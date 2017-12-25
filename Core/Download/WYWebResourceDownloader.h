//
//  WYWebResourceDownloader.h
//  WYWebResource
//
//  Created by wyan assert on 2017/8/11.
//  Copyright © 2017年 wyan assert. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WYWebResourceDef.h"

NS_ASSUME_NONNULL_BEGIN

@interface WYWebResourceDownloadToken : NSObject

@property (nonatomic, strong, nullable) NSURL *url;
@property (nonatomic, strong, nullable) WYWebResourceDownloadCancelToken downloadOperationCancelToken;

@end

@interface WYWebResourceDownloader : NSObject

+ (instancetype)sharedDownloader;

- (WYWebResourceDownloadToken *)requestWYWebResourceWithResourceId:(NSURL *)url
                                                        saveFolder:(NSString *)savePath
                                                          progress:(WYWebResourceProgressBlock)progressBlock
                                                        comloetion:(WYWebResourceDownloadBlock)completionBlock;

- (void)cancelRequestForResource:(WYWebResourceDownloadToken *)token;

- (void)cancelAllRequest;

NS_ASSUME_NONNULL_END

@end
