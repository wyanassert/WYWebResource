# WYWebResource
Download and unzip resource from web server.

下载一个zip资源包, 解压缩, 对压缩包中的特定资源建立磁盘缓存. 有如下优点:

1. 避免反复调用导致重复下载.

2. 支持多个任务并发与线程安全.

3. 多个资源包中有同一个资源时只会保留一份该资源. 删除资源包时, 该资源包包含的资源也会被一起删除, 避免浪费磁盘空间(如果该资源被某个未被删除的资源包包含的话, 则不会被删除).


---

## 引入方法
	1. 手动导入
	将Core文件夹重命名为WYWebResource, 再拖到工程中, 添加`AFNetworking`和`SSZipArchive`的引用

	2. Pod

	pod 'WYWebResource'

---

## 使用方法

1. 资源包的结构

  * 资源包应为一系列文件全选并右键压缩, 请不要放到一个文件夹再对文件夹进行压缩(并没有做这方面的错误处理).
  * 资源包中要有一个`index.json`的文件, 其他的资源也直接放在同一目录下(暂时不支持文件夹嵌套寻找资源).
  * 同种资源的文件名记录在`index.json`中, 资源包的结构与index.json的一个示例如下所示.

  **资源包目录**

	```
	index.json
	blend.jpg       
	blend_light2.jpg
	blend_light1.jpg
	blend_light3.jpg
	```

  **index.json**

		```
		{
	  	"id": "3000",
	  	"type": "overlay",
	  	"overlay": [
	    	"blend.jpg",
	   	 	"blend_light1.jpg",
	    	"blend_light2.jpg",
	    	"blend_light3.jpg"
	  		]
		}
		```

	`overlay`中记录了四张图片, 这四张图片在资源包的根目录, 此模块会将这四张图片放在一个`overlay`目录下, 并且将`index.json`作下处理并返回, 处理之后的字典如下所示(`index.json`中只有`overlay`的value会被处理, 还要注意不要存储这个地址, 这个地址是会变动的).

	```
	{
    "id" = "3000";
    "type" = "overlay";
   	"overlay" =     {
        "blend.jpg": "/var/mobile/Containers/Data/Application/4BD2BE89-EFAA-4D56-90B2-EE25FEFB7FB3/Library/WYWebResource/overlay/blend.jpg",
        "blend_light1.jpg" : "/var/mobile/Containers/Data/Application/4BD2BE89-EFAA-4D56-90B2-EE25FEFB7FB3/Library/WYWebResource/overlay/blend_light1.jpg",
        "blend_light2.jpg" : "/var/mobile/Containers/Data/Application/4BD2BE89-EFAA-4D56-90B2-EE25FEFB7FB3/Library/WYWebResource/overlay/blend_light2.jpg",
        "blend_light3.jpg" : "/var/mobile/Containers/Data/Application/4BD2BE89-EFAA-4D56-90B2-EE25FEFB7FB3/Library/WYWebResource/overlay/blend_light3.jpg"
    };
    }

	```

2. 代码引用
	* 设定哪些资源需要处理
		`[WYWebResourceManager sharedManager].cacheTypeList = @[@"overlay", @"image", @"filter", @"font"];`
		`overlay ` `image ` `filter ` `font ` 就是index.json中需要处理的资源的key名.
		不设置默认的话是如上四种类型.
	* 从远程下载 先下载然后解压缩并处理资源

	```
	[[WYWebResourceManager sharedManager] requestWYWebResource: @"remote URL"
                                                      progress:^(NSProgress *progress, NSURL *targetURL) {

                                                      }
                                                    completion:^(NSDictionary * resourceInfo, NSError *error, NSURL *url) {
                                                        NSLog(@"\nresource:\n%@, \nerror:%@, \nurl:%@", resourceInfo, error, url);
                                                    }];

	```

	* 从MainBundle加载

	```
	NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"Test" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *resourcePath = [bundle pathForResource:@"3000" ofType:@"zip"];

    [[WYWebResourceManager sharedManager] requestWYWebResource:[NSURL fileURLWithPath:resourcePath]
                                                      progress:nil
                                                    completion:^(NSDictionary * _Nullable resourceInfo, NSError * _Nonnull error, NSURL * _Nonnull url) {
                                                        NSLog(@"resource:%@, \nerror:%@, \nurl:%@", resourceInfo, error, url);
                                                    }];
	```

	* 需要解压密码

	```
	[[WYWebResourceManager sharedManager] requestWYWebResource:[NSURL URLWithString:@"https://firebasestorage.googleapis.com/v0/b/wydemo-93c17.appspot.com/o/zip%2F111.zip?alt=media&token=ca883d44-46e5-4ca7-9f5b-11521b63d293"] zipPw:@"111" progress:nil completion:^(NSDictionary * _Nullable resourceInfo, NSError * _Nonnull error, NSURL * _Nonnull url) {

    }];
	```

**注意 demo中的资源放在Google的Firebase上, 所以,,,**

---
## 代码结构

### WYWebResourceManager
1. 初始化

	path是调用者预设的存储路径,(若该路径不存在, 则会使用模块默认的路径), 会在下面生成若干个目录来存放, 资源包(从服务器下载), 字体, 滤镜, 遮罩, 资源索引等资源, 每个文件夹只放一类资源.

	```
	- (instance)initWithStorePath:(NSString *)path folder:(NSString *)name;
	```

2. 设定需要处理的资源类型

	参数是一个string数组, 每一项表示一个需要处理的资源类型, 比如相片,视频,遮罩等, 此模块会读取压缩包中的`index.json`, 将这些资源放到Cache目录下并返回该资源的地址. 不在这个数组中的数据不会被处理.
	```
	@property (nonatomic, strong) NSArray<NSString *> *cacheTypeList;
	```

2. 请求资源

	url是访问资源的唯一标志, 会先检测是否有资源的资料, 没有的话去服务器下载, 并解压, 为资源建立索引. 如果找到本地有相关的资源, 则会直接把需要的字体,遮罩等资源的url传出去, 若是这些资源并不全, 则解压源资源包, 更新索引, 并将文件传出去. 若资源包不存在, 则重新从服务器下载, 并更新资源.

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

5. 清除某个资源包的缓存

	删除该资源包, 并根据索引确认是否删除资源文件,

	```
	- (void)deleteCache:(NSURL *)url;
	```

6. 清除所有的缓存, 谨慎使用

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

2. \- (void)start;
3. \- (void)cancel;

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
