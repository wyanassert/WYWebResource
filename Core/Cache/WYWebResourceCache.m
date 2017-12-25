//
//  WYWebResourceCache.m
//  WYWebResource
//
//  Created by wyan assert on 2017/8/13.
//  Copyright © 2017年 wyan assert. All rights reserved.
//

#import "WYWebResourceCache.h"
#import "WYWebResourceManager.h"
#import <CommonCrypto/CommonDigest.h>
#import "WYWebResourceCacheOperation.h"

#define kWYWebResourceCacheErrorDomain @"com.wyanassert.WYWebResourceCache"
#define kWYWebResourceHomePath NSHomeDirectory()
#define kWYWebResourceMainBundlePath [NSBundle mainBundle].resourcePath

static NSString *kWYWebResourceIndexDat = @"index.dat";

static NSString *kWYWebResourceLocalUrlArray = @"kWYWebResourceLocalUrlArray";

@interface NSString (WYRelPath)

- (NSString *)stringByRelativeToHome;
- (NSString *)stringByPreAppendHomePath;

- (NSString *)stringByRelativeMianBundle;
- (NSString *)stringByPreAppendMainBundlePath;

@end

@implementation NSString (WYRelPath)

- (NSString *)stringByRelativeToHome {
    NSUInteger cutIndex = 0;
    NSRange range = [self rangeOfString:kWYWebResourceHomePath];
    if(range.length && range.location != NSNotFound) {
        cutIndex = range.location + range.length;
    } else {
        range = [self rangeOfString:@"/Library/" options:NSBackwardsSearch];
        if(range.length && range.location != NSNotFound) {
            cutIndex = range.location;
        }
    }
    NSString *result = [self substringFromIndex:cutIndex];
    if([result hasPrefix:@"/"]) {
        result = [result substringFromIndex:1];
    }
    return result;
}
- (NSString *)stringByPreAppendHomePath {
    return [kWYWebResourceHomePath stringByAppendingPathComponent:self];
}

- (NSString *)stringByRelativeMianBundle {
    NSUInteger cutIndex = 0;
    NSRange range = [self rangeOfString:kWYWebResourceMainBundlePath];
    if(range.length && range.location != NSNotFound) {
        cutIndex = range.location + range.length;
    } else {
        range = [self rangeOfString:@".app" options:NSBackwardsSearch];
        if(range.length && range.location != NSNotFound) {
            cutIndex = range.location + range.length;
        }
    }
    NSString *result = [self substringFromIndex:cutIndex];
    if([result hasPrefix:@"/"]) {
        result = [result substringFromIndex:1];
    }
    return result;
}

- (NSString *)stringByPreAppendMainBundlePath {
    return [kWYWebResourceMainBundlePath stringByAppendingPathComponent:self];
}

@end

@interface PhotoSubResourceUnit : NSObject <NSSecureCoding>

@property (nonatomic, strong, readonly) NSString *subType;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString * ,NSString *> *savePath;
@property (nonatomic, strong, readonly) id content;

- (instancetype)initWithKeyName:(NSString *)keyName content:(id)content;
- (BOOL)needSaveToCache;
- (id)getValue;

@end

@implementation PhotoSubResourceUnit

- (instancetype)initWithKeyName:(NSString *)keyName content:(id)content {
    if(self = [super init]) {
        _subType = keyName;
        if([self needSaveToCache]) {
            _savePath = [NSMutableDictionary dictionary];
        } else {
            _content = content;
        }
    }
    return self;
}

- (BOOL)needSaveToCache {
    NSArray<NSString *> *cacheList = [WYWebResourceManager sharedManager].cacheTypeList;
    
    for(NSString *str in cacheList) {
        if([self.subType isEqualToString:str]) {
            return YES;
        }
    }
    return NO;
}

- (id)getValue {
    if([self needSaveToCache]) {
        return [self.savePath copy];
    } else {
        return self.content;
    }
}

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.subType forKey:@"subType"];
    if(self.savePath) {
        NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
        for(NSString *key in self.savePath) {
            tmpDict[key] = [self.savePath[key] stringByRelativeToHome];
        }
        [aCoder encodeObject:[tmpDict copy] forKey:@"savePath"];
    }
    if(self.content) {
        [aCoder encodeObject:self.content forKey:@"content"];
    }
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if(self = [super init]) {
        _subType = [aDecoder decodeObjectForKey:@"subType"];
        _savePath = [aDecoder decodeObjectForKey:@"savePath"];
        if([_savePath isKindOfClass:[NSDictionary class]] && ![_savePath isKindOfClass:[NSMutableDictionary class]]) {
            NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
            for(NSString *key in _savePath) {
                tmpDict[key] = [_savePath[key] stringByPreAppendHomePath];
            }
            _savePath = tmpDict;
        }
        _content = [aDecoder decodeObjectForKey:@"content"];
    }
    return self;
}

@end


@interface WYWebResourceUnit : NSObject <NSSecureCoding>

@property (nonatomic, strong, readonly) NSDictionary         *indexJson;
@property (nonatomic, strong, readonly) NSArray<PhotoSubResourceUnit *> *subUnitArray;
@property (nonatomic, strong, readonly) NSURL                *url;
@property (nonatomic, strong, readonly) NSString             *password;
@property (nonatomic, strong, readonly) NSURL                *zipPath;
@property (nonatomic, strong, readonly) NSURL                *extractPath;
@property (nonatomic, strong, readonly) NSURL                *moveToPath;

- (instancetype)initWithIndexJson:(NSDictionary *)indexJson
                              url:(NSURL *)url
                            zipPw:(NSString *)password
                          zipPath:(NSURL *)zipPath
                      extractPath:(NSURL *)extractPath
                       moveToPath:(NSURL *)moveToPath;
- (NSDictionary *)toDictionary;
- (BOOL)ifSubResourceExistWithIOQueue:(dispatch_queue_t)ioQueue;

@end

@implementation WYWebResourceUnit

- (instancetype)initWithIndexJson:(NSDictionary *)indexJson
                              url:(NSURL *)url
                            zipPw:(NSString *)password
                          zipPath:(NSURL *)zipPath
                      extractPath:(NSURL *)extractPath
                       moveToPath:(NSURL *)moveToPath {
    if(self = [super init]) {
        _indexJson = indexJson;
        _url = url;
        _zipPath = zipPath;
        _extractPath = extractPath;
        _moveToPath = moveToPath;
        NSMutableArray *tmpArray = [NSMutableArray array];
        for(NSString *key in indexJson) {
            if(key) {
                PhotoSubResourceUnit *subUnit = [[PhotoSubResourceUnit alloc] initWithKeyName:key content:indexJson[key]];
                if(subUnit) {
                    [tmpArray addObject:subUnit];
                }
            }
        }
        _subUnitArray = [tmpArray copy];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for(PhotoSubResourceUnit *subUnit in self.subUnitArray) {
        result[subUnit.subType] = subUnit.getValue;
    }
    return [result copy];
}

- (BOOL)ifSubResourceExistWithIOQueue:(dispatch_queue_t)ioQueue {
    __block BOOL result = YES;
    for(PhotoSubResourceUnit *subUnit in self.subUnitArray) {
        if([subUnit needSaveToCache]) {
            for(NSString *key in subUnit.savePath) {
                NSString *subResourcePath = subUnit.savePath[key];
                dispatch_sync(ioQueue, ^{
                    result = [[NSFileManager defaultManager] fileExistsAtPath:subResourcePath];
                });
                if(!result) {
                    break;
                }
            }
        }
        if(!result) {
            break;
        }
    }
    return result;
}

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.indexJson forKey:@"indexJson"];
    [aCoder encodeObject:self.subUnitArray forKey:@"subUnitArray"];
    [aCoder encodeObject:self.url forKey:@"url"];
    [aCoder encodeObject:[self.zipPath.path stringByRelativeToHome] forKey:@"zipPath"];
    [aCoder encodeObject:[self.extractPath.path stringByRelativeToHome] forKey:@"extractPath"];
    [aCoder encodeObject:[self.moveToPath.path stringByRelativeToHome] forKey:@"moveToPath"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if(self = [super init]) {
        _indexJson = [aDecoder decodeObjectForKey:@"indexJson"];
        _subUnitArray = [aDecoder decodeObjectForKey:@"subUnitArray"];
        _url = [aDecoder decodeObjectForKey:@"url"];
        _zipPath = [NSURL fileURLWithPath:[[aDecoder decodeObjectForKey:@"zipPath"] stringByPreAppendHomePath]];
        _extractPath = [NSURL fileURLWithPath:[[aDecoder decodeObjectForKey:@"extractPath"] stringByPreAppendHomePath]];
        _moveToPath = [NSURL fileURLWithPath:[[aDecoder decodeObjectForKey:@"moveToPath"] stringByPreAppendHomePath]];
    }
    return self;
}

@end


@interface WYWebResourceCache()

@property (strong, nonatomic, nullable) dispatch_queue_t ioQueue;

@property (strong, nonatomic, nullable) dispatch_queue_t barrierQueue;
@property (nonatomic, strong, nonnull ) NSMutableDictionary         *indexDict;
@property (nonatomic, strong, nonnull ) NSMutableArray<NSString *>  *localUrlArray;
@property (strong, nonatomic, nonnull ) NSMutableDictionary<NSURL *, WYWebResourceCacheOperation *> *URLOperations;

@property (strong, nonatomic, nonnull ) NSOperationQueue *extractQueue;


@end

@implementation WYWebResourceCache

#pragma mark - LifeCycle
- (instancetype)init {
    if(self = [super init]) {
        _ioQueue = dispatch_queue_create("com.wyanassert.WYWebResourceCacheIO", DISPATCH_QUEUE_SERIAL);
        _barrierQueue = dispatch_queue_create("com.wyanassert.WYWebResourceCacheBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        
        _extractQueue = [NSOperationQueue new];
        _extractQueue.maxConcurrentOperationCount = 5;
        _extractQueue.name = @"com.wyanassert.WYWebResourceCacheExtract";
    }
    return self;
}

- (void)dealloc {
#ifndef OS_OBJECT_USE_OBJC
    dispatch_release(_ioQueue);
    dispatch_release(_barrierQueue);
#endif
}

#pragma mark - Public
+ (instancetype)sharedCache {
    static WYWebResourceCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [WYWebResourceCache new];
    });
    return instance;
}

- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSURL *)url
                                        zipPassword:(NSString *)password
                                               done:(WYWebResourceCacheQueryBlock _Nullable)doneBlock {
    if(!url) {
        if(doneBlock) {
            doneBlock(nil, url, [NSError errorWithDomain:kWYWebResourceCacheErrorDomain code:kWYWebResourceErrorUrlIsNil userInfo:@{@"message":@"parameter url should not be nil"}]);
        }
        return nil;
    }
    
    NSDictionary *resourceInfo = [self resourceInfoFromIndexForKey:url];
    if(resourceInfo) {
        if(doneBlock) {
            doneBlock(resourceInfo, url, nil);
        }
        return nil;
    }
    
    NSOperation *operation = [NSOperation new];
    dispatch_async(self.ioQueue, ^{
        if(operation.cancelled) {
            
            return ;
        }
        [self resourceInfoFromResourceBundle:url
                                  completion:^(NSDictionary * _Nullable resourceInfo, NSURL * _Nullable url, NSError * _Nullable error) {
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          if(doneBlock) {
                                              doneBlock(resourceInfo, url, error);
                                          }
                                      });
                                  }];
    });
    
    return operation;
}

- (NSDictionary *_Nullable)resourceInfoFromIndexForKey:(NSURL *_Nonnull)url {
    NSAssert(url, @"Parameter url should not be nil");
    __block WYWebResourceUnit *resourceUnit = nil;
    dispatch_barrier_sync(self.barrierQueue, ^{
        resourceUnit = self.indexDict[[self  keyForIndexDict:url]];
    });
    if([resourceUnit ifSubResourceExistWithIOQueue:self.ioQueue]) {
        return resourceUnit.toDictionary;
    } else {
        return nil;
    }
}

- (void)resourceInfoFromResourceBundle:(NSURL *_Nonnull)url completion:(WYWebResourceCacheQueryBlock _Nullable)block {
    NSAssert(url, @"Parameter url should not be nil");
    __block WYWebResourceUnit *resourceUnit = nil;
    dispatch_barrier_sync(self.barrierQueue, ^{
        resourceUnit = self.indexDict[[self keyForIndexDict:url]];
    });
    if(resourceUnit && resourceUnit.zipPath && resourceUnit.extractPath && resourceUnit.moveToPath) {
        [self extractResource:url
                         path:resourceUnit.zipPath
                    extraPath:resourceUnit.extractPath
              moveToDirectory:resourceUnit.moveToPath
                        zipPw:resourceUnit.password
                   completion:block];
    } else {
        if(block) {
            block(nil, url, [NSError errorWithDomain:kWYWebResourceCacheErrorDomain code:kWYWebResourceErrorIndexForResourceFail userInfo:@{@"message" : @"not find index"}]);
        }
    }
}

- (BOOL)isSubResourceExist:(NSString *)path {
    __block BOOL result = NO;
    dispatch_sync(self.ioQueue, ^{
        result = [[NSFileManager defaultManager] fileExistsAtPath:path];
    });
    return result;
}

- (void)storeData:(NSURL *_Nonnull)url
         fromPath:(NSURL *_Nonnull)resourcePath
 extractDirectory:(NSURL *_Nonnull)extractDir
  moveToDirectory:(NSURL *_Nonnull)moveToDir
            zipPw:(NSString *)password
       completion:(WYWebResourceCacheQueryBlock _Nullable)block {
    [self extractResource:url
                     path:resourcePath
                extraPath:extractDir
          moveToDirectory:moveToDir
                    zipPw:password
               completion:block];
}

- (void)deleteResource:(NSURL *)url {
    if(![self keyForIndexDict:url]) {
        return ;
    }
    dispatch_barrier_async(self.barrierQueue, ^{
        WYWebResourceUnit *resourceUnit = self.indexDict[[self keyForIndexDict:url]];
        if(resourceUnit) {
            dispatch_async(self.ioQueue, ^{
                NSError *error = nil;
                [[NSFileManager defaultManager] removeItemAtURL:resourceUnit.zipPath error:&error];
            });
            for(PhotoSubResourceUnit *subUnit in resourceUnit.subUnitArray) {
                if(![subUnit needSaveToCache]) {
                    continue ;
                }
                for(NSString *waitToDeletePath in subUnit.savePath.allValues) {
                    BOOL found = NO;
                    //look for units in indexDict
                    for (WYWebResourceUnit *tmpUnit in self.indexDict.allValues) {
                        if(tmpUnit == resourceUnit) {
                            continue ;
                        }
                        for(PhotoSubResourceUnit *tmpSubUnit in tmpUnit.subUnitArray) {
                            if([tmpSubUnit needSaveToCache]) {
                                for(NSString *tmpPath in tmpSubUnit.savePath.allValues) {
                                    if([waitToDeletePath isEqualToString:tmpPath]) {
                                        found = YES;
                                        break;
                                    }
                                }
                            }
                            if(found) {
                                break;
                            }
                        }
                        if(found) {
                            break;
                        }
                    }
                    if(found) {
                        continue;
                    } else {
                        dispatch_async(self.ioQueue, ^{
                            NSError *error = nil;
                            [[NSFileManager defaultManager] removeItemAtPath:waitToDeletePath error:&error];
                        });
                    }
                }
            }
            
            [self.indexDict removeObjectForKey:[self keyForIndexDict:url]];
            [self saveIndex];
        }
    });
}

- (void)deleteAllResource:(NSString *)workDir {
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.indexDict removeAllObjects];
        [self saveIndex];
    });
    dispatch_async(self.ioQueue, ^{
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:workDir error:&error];
    });
}

- (BOOL)copyResourceTo:(NSURL *)resourcePath fromMainBundle:(NSURL *)url {
    __block BOOL result = NO;
    dispatch_sync(self.ioQueue, ^{
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtURL:url toURL:resourcePath error:&error];
        if(!error) {
            result = YES;
        }
    });
    return result;
}

- (NSDictionary<NSURL *,NSDictionary *> *_Nullable)localResource:(NSString *)resourceType withCheckFileExist:(BOOL)willCheck {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    dispatch_barrier_sync(self.barrierQueue, ^{
        [self.indexDict enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull key, WYWebResourceUnit * _Nonnull resourceUnit, BOOL * _Nonnull stop) {
            if(willCheck && ![resourceUnit ifSubResourceExistWithIOQueue:self.ioQueue]) {
                //do nothine
            } else if([resourceUnit.indexJson[@"type"] isKindOfClass:[NSString class]] &&
                      [resourceUnit.indexJson[@"type"] isEqualToString:resourceType]) {
                if([self.localUrlArray indexOfObject:key] != NSNotFound) {
                    key = [key stringByPreAppendMainBundlePath];
                }
                [result setObject:resourceUnit.toDictionary forKey:key];
            }
        }];
    });
    return [result copy];
}

#pragma mark - Private
- (WYWebResourceCacheToken *)extractResource:(NSURL *)url path:(NSURL *)zipPath extraPath:(NSURL *)extraPath moveToDirectory:(NSURL *_Nonnull)moveToDir zipPw:(NSString *)password completion:(WYWebResourceCacheQueryBlock)block {
    NSString *extraDir = [self extractResourceToUniqueFile:extraPath.path url:url];
    
    __block WYWebResourceCacheToken *token = nil;
    dispatch_barrier_sync(self.barrierQueue, ^{
        WYWebResourceCacheOperation *operation = self.URLOperations[url];
        if(!operation) {
            operation = [[WYWebResourceCacheOperation alloc] initWithUrl:url resourcePath:zipPath extractDir:[NSURL fileURLWithPath:extraDir] password:password];
            [self.extractQueue addOperation:operation];
            self.URLOperations[url] = operation;
            __weak WYWebResourceCacheOperation *woperation = operation;
            operation.completionBlock = ^{
                WYWebResourceCacheOperation *soperation = woperation;
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
        __weak typeof(self)weakSelf = self;
        WYWebResourceExtractCancelToken extractCancelToken = [operation addHandlersForProgress:^(long entryNumber, long total) { } completed:^(NSString * _Nonnull path, BOOL succeeded, NSError * _Nullable error) {
            __block NSError *tmpError = error;
            __strong typeof(weakSelf)self = weakSelf;
            if(succeeded && !tmpError) {
                dispatch_async(self.ioQueue, ^{
                    NSDictionary *tmpDictionary = nil;
                    NSString *indexFilePath = [extraDir stringByAppendingPathComponent:kWYWebResourceIndexFileName];
                    if(![[NSFileManager defaultManager] fileExistsAtPath:indexFilePath]) {
                        tmpError = [NSError errorWithDomain:kWYWebResourceCacheErrorDomain code:kWYWebResourceErrorNotExistIndexJson userInfo:@{@"message" : @"Not fount index.json after extra"}];
                    } else {
                        NSData *indexData = [NSData dataWithContentsOfFile:indexFilePath];
                        NSDictionary *indexDict = [NSJSONSerialization JSONObjectWithData:indexData options:kNilOptions error:&tmpError];
                        if(!tmpError) {
                            if(![indexDict isKindOfClass:[NSDictionary class]] || indexDict.count == 0) {
                                tmpError = [NSError errorWithDomain:kWYWebResourceCacheErrorDomain code:kWYWebResourceErrorIndexJsonIsEmpty userInfo:@{@"message" : @"index.json contains nothing"}];
                            } else {
                                WYWebResourceUnit *unit = [[WYWebResourceUnit alloc] initWithIndexJson:indexDict url:url zipPw:password zipPath:zipPath extractPath:extraPath moveToPath:moveToDir];
                                for(PhotoSubResourceUnit *subResourceUnit in unit.subUnitArray) {
                                    if([subResourceUnit needSaveToCache]) {
                                        NSArray *array = [indexDict objectForKey:subResourceUnit.subType];
                                        if([array isKindOfClass:[NSArray class]] && array.count) {
                                            for(NSString *fileName in array) {
                                                NSString *subFilePath = [extraDir stringByAppendingPathComponent:fileName];
                                                if([[NSFileManager defaultManager] fileExistsAtPath:subFilePath]) {
                                                    NSURL *fromURL = [NSURL fileURLWithPath:subFilePath];
                                                    NSURL *moveToURL = [self getMoveToURL:moveToDir resourceType:subResourceUnit.subType fromPath:subFilePath];
                                                    NSError *moveError;
                                                    if([[NSFileManager defaultManager] fileExistsAtPath:moveToURL.path]) {
                                                        [[NSFileManager defaultManager] removeItemAtURL:moveToURL error:&moveError];
                                                    }
                                                    [[NSFileManager defaultManager] copyItemAtURL:fromURL toURL:moveToURL error:&moveError];
                                                    if(!moveError) {
                                                        [subResourceUnit.savePath setObject:moveToURL.path forKey:fileName];
                                                    }
                                                }
                                            }
                                        } else {
                                            //this subResource is Empty, do nothing
                                        }
                                    } else {
                                        //this subResource did not need to deal
                                    }
                                }
                                tmpDictionary = unit.toDictionary;
                                dispatch_barrier_sync(self.barrierQueue, ^{
                                    [self.indexDict setObject:unit forKey:[self keyForIndexDict:url]];
                                    [self saveIndex];
                                });
                            }
                        }
                    }
                    dispatch_main_async_safe(^() {
                        if(block) {
                            block(tmpDictionary, url, tmpError);
                        }
                    });
                });
            } else {
                dispatch_main_async_safe(^() {
                    if(block) {
                        block(nil, url, error);
                    }
                });
            }
        } allExcuted:^{
            dispatch_async(self.ioQueue, ^{
                [[NSFileManager defaultManager] removeItemAtPath:extraDir error:nil];
            });
        }];
        token.url = url;
        token.extractOperationCancelToken = extractCancelToken;
    });
    return token;
}

- (NSString *)extractResourceToUniqueFile:(NSString *)extraPath url:(NSURL *)url {
    
    return [extraPath stringByAppendingPathComponent:[self md5HexDigest:[self keyForIndexDict:url]]];
}

- (NSString *)md5HexDigest:(NSString *)originStr
{
    const char *original_str = [originStr UTF8String];
    
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(original_str, strlen(original_str), result);
    
    NSMutableString *hash = [NSMutableString string];
    
    for (int i = 0; i < 16; i++)
        [hash appendFormat:@"%02X", result[i]];
    
    return [hash lowercaseString];
}

- (NSURL *)getMoveToURL:(NSURL *)moveToDir resourceType:(NSString *)resourceType fromPath:(NSString *)fromPath {
    NSString *basePath = moveToDir.path;
    basePath = moveToDir.path;
    basePath = [basePath stringByAppendingPathComponent:resourceType];
    if(![[NSFileManager defaultManager] fileExistsAtPath:basePath]) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:basePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
    }
    basePath = [basePath stringByAppendingPathComponent:[fromPath lastPathComponent]];
    
    return [NSURL fileURLWithPath:basePath];
}

- (void)saveIndex {
    dispatch_async(self.ioQueue, ^{
        [NSKeyedArchiver archiveRootObject:[self.indexDict copy]
                                    toFile:[self.indexSavePath stringByAppendingPathComponent:kWYWebResourceIndexDat]];
    });
}

- (NSString *)keyForIndexDict:(NSURL *)url {
    if(url.isFileURL) {
        NSString *tmpKey = [url.absoluteString stringByRelativeMianBundle];
        if([self.localUrlArray indexOfObject:tmpKey] == NSNotFound) {
            [self.localUrlArray addObject:tmpKey];
            [[NSUserDefaults standardUserDefaults] setObject:self.localUrlArray forKey:kWYWebResourceLocalUrlArray];
        }
        return tmpKey;
    } else {
        return url.absoluteString;
    }
}

#pragma mark - Getter
- (NSMutableDictionary *)indexDict {
    if(!_indexDict) {
        NSString *indexSourcePath = [self.indexSavePath stringByAppendingPathComponent:kWYWebResourceIndexDat];
        NSData *data = [NSData dataWithContentsOfFile:indexSourcePath];
        if(data) {
            NSDictionary *tmpDict = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            if(tmpDict && [tmpDict isKindOfClass:[NSDictionary class]]) {
                _indexDict = [NSMutableDictionary dictionaryWithDictionary:tmpDict];
            }
        }
        if(!_indexDict) {
            _indexDict = [NSMutableDictionary dictionary];
        }
    }
    return _indexDict;
}

- (NSString *)indexSavePath {
    if(!_indexSavePath) {
        _indexSavePath = (NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]);
    }
    return _indexSavePath;
}

- (NSMutableDictionary<NSURL *,WYWebResourceCacheOperation *> *)URLOperations {
    if(!_URLOperations) {
        _URLOperations = [NSMutableDictionary dictionary];
    }
    return _URLOperations;
}

- (NSMutableArray<NSString *> *)localUrlArray {
    if(!_localUrlArray){
        NSArray *array = [[NSUserDefaults standardUserDefaults] objectForKey:kWYWebResourceLocalUrlArray];
        if(array && [array isKindOfClass:[NSArray class]]) {
            _localUrlArray = [NSMutableArray arrayWithArray:array];
        } else {
            _localUrlArray = [NSMutableArray array];
        }
    }
    return _localUrlArray;
}

@end
