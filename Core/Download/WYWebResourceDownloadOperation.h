//
//  WYWebResourceDownloadOperation.h
//  WYWebResource
//
//  Created by wyan assert on 2017/8/11.
//  Copyright © 2017年 wyan assert. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WYWebResourceDownloader.h"

@interface WYWebResourceDownloadOperation : NSOperation
NS_ASSUME_NONNULL_BEGIN

@property (strong, nonatomic, readonly, nullable) NSURLRequest *request;

- (instancetype _Nonnull)initWithRequest:(NSURLRequest *_Nonnull)request savePath:(NSString *_Nonnull)savePath;

- (WYWebResourceDownloadCancelToken _Nonnull)addHandlersForProgress:(WYWebResourceProgressBlock)progressBlock
                                                             completed:(WYWebResourceDownloadBlock)completedBlock;

- (BOOL)cancel:(WYWebResourceDownloadCancelToken _Nonnull)token;

NS_ASSUME_NONNULL_END

@end
