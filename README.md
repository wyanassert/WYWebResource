# WYWebResource
Download and unzip resource from web server.


1. 初始化

	path是调用者预设的存储路径,(若该路径不存在, 则会使用模块默认的路径), 会在下面生成若干个目录来存放, 资源包(从服务器下载), 字体, 滤镜, 遮罩, 资源索引等资源, 每个文件夹只放一类资源.

	```
	- (instance)initWithStorePath:(NSString *)path folder:(NSString *)name;
	```

1. 请求资源

	url是访问资源的唯一标志, 会先检测是否有资源的资料, 没有的话去服务器下载, 并解压, 为资源建立索引. 如果找到本地有相关的资源, 则会直接把需要的字体,遮罩等资源的url传出去, 若是这些资源并不全, 则解压源资源包, 更新索引, 并将文件传出去. 若资源包不存在, 则重新冲服务器下载, 并根新资源.

	```
	- (void)requestWYWebResourceWithResourceId:(NSURL *)url progress:(BLOCK)progressBlock comloetion:(BLOCK)completionBlock;
	```

2. 取消一次资源的下载

	取消下载请求.

	```
	- (void)cancelRequestForResource:(NSURL *)url;
	```

3. 取消当前所有的下载

	```
	- (void)cancelAllRequest;
	```

3. 某个资源包是否可用

	检查资源包各个子文件是否存在, 若不存在, 检查资源包是否存在

	```
	- (BOOL)isResourceAvailable:(NSURL *)url;
	```

4. 某个具体的资源是否可用

	在索引中找资源是否存在, 找到索引, 根据所以找文件是否存在与该目录.

	```
	- (BOOL)isSubResourceAvailable:(SubResourceType)type subResourceName:(NSString *)resourceName;
	```

5. 清除某个资源包的缓存(清除功能请谨慎使用, 清楚后应当告诉`XQPhotoDesigner`重新获取资源)

	删除该资源包, 并根据索引确认是否删除资源文件,

	```
	- (void)deleteCache:(NSURL *)url;
	```

6. 清除所有的缓存(只适合在App启动的时候使用)

	```
	- (void)deleteAllCache;
	```

---
### WYWebResourceDownloader

1. 把资源包下载到指定位置, 并调用Cache存储子资源, 建立索引.

	```
	- (void)requestWYWebResourceWithResourceId:(NSURL *)url comloetion:(BLOCK)block;
	```

2. 取消一次资源的下载操作

	```
	- (void)cancelRequestForResource:(NSURL *)url;
	```

3. 取消所有当前下载

	```
	- (void)cancelAllRequest;
	```

### WYWebResourceDownloadOperation

1. 每次调用生成一次回调的Token返回, 避免同时下载多个请求

	```
	- (Token)addHandlersForProgress:(BLOCK)progressBlock completed:(BLOCK)completedBlock;
	```
4. 取消一次下载

	```
	 - (void)cancel:(Token)token;
	```

2. - (void)start;
3. - (void)cancel;

---

### WYWebResourceCache

1. 下载解压
	根据资源包解压资源并将子资源放到相应位置, 应该单独开一个线程写文件, 并保持同步操作

	```
	- (void)storeData:(NSURL *)url path:(NSURL *)resourcePath extractDirectory:(NSURL *) extractDir completion:(BLOCK)block;
	```
2. 删除特定的资源, 可能是资源包, 也可能是某个子资源

	```
	- (void)deleteResourceWithPath:(NSURL *)resourcePath;
	```

---
### WYWebResourceIndex

1. 下载解压完成之后, 建立索引, 索引应该用url作为主键, 包含资源包的地址,

	```
	- (void)addResource:(NSURL *)url path:(NSURL *)pathUrl subResources:(NSDictonary<SubResourceType, NSURL *> *)subResources;
	```
2. 删除一个资源包的索引

	```
	- (void)deleteResource:(NSURL *)url;
	```
3. 根据资源包名字获取地址

	```
	- (NSURL *)getResourcePath:(NSURL *)url;
	```
4. 获取子资源的地址

	```
	- (NSURL *)getSubResource:(SubResourceType)type WithName:(NSString *)resourceName;
	```
