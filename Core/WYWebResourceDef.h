//
//  WYWebResourceDef.h
//  WYWebResource
//
//  Created by wyan assert on 2017/8/13.
//  Copyright © 2017年 wyan assert. All rights reserved.
//

#ifndef WYWebResourceDef_h
#define WYWebResourceDef_h

NS_ASSUME_NONNULL_BEGIN

#define kWYWebResourceErrorUrlIsNil                 -2001
#define kWYWebResourceErrorDownloadFail             -2002
#define kWYWebResourceErrorSerilizationFail         -2003
#define kWYWebResourceErrorExtractFail              -2004
#define kWYWebResourceErrorSaveFileFail             -2005
#define kWYWebResourceErrorIndexForResourceFail     -2006
#define kWYWebResourceErrorNotExistIndexJson        -2007
#define kWYWebResourceErrorIndexJsonIsEmpty         -2008

#define kWYWebResourceIndexFileName                 @"index.json"

#define WYWebResourceDownloadCancelToken NSMutableDictionary*
#define WYWebResourceExtractCancelToken NSMutableDictionary*

typedef void(^WYWebResourceProgressBlock)(NSProgress *progress, NSURL *url);
typedef void(^WYWebResourceDownloadBlock)(NSError *error, NSURL *_Nullable targetURL);
typedef void(^WYWebResourceCompletionBlock)(NSDictionary * _Nullable resourceInfo, NSError *error, NSURL *url);
typedef void(^WYWebResourceCacheQueryBlock)(NSDictionary * _Nullable resourceInfo, NSURL * _Nullable url, NSError * _Nullable error);

typedef void(^WYWebResourceNoParamBlock)(void);

NS_ASSUME_NONNULL_END

#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block)\
if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}
#endif


#endif /* WYWebResourceDef_h */
