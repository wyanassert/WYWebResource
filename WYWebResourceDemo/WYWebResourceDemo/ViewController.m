//
//  ViewController.m
//  WYWebResourceDemo
//
//  Created by wyan assert on 25/12/2017.
//  Copyright © 2017 wyan assert. All rights reserved.
//

#import "ViewController.h"
#import "WYWebResourceManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [WYWebResourceManager sharedManager].cacheTypeList = @[@"overlay", @"image", @"filter", @"font"];
    
    {
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(50, 50, 100, 50)];
        [btn setBackgroundColor:[UIColor redColor]];
        [btn setTitle:@"Test" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(testForDownload) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
    {
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(160, 50, 100, 50)];
        [btn setBackgroundColor:[UIColor redColor]];
        [btn setTitle:@"Local file" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(testForLocalFile) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
    {
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(50, 160, 100, 50)];
        [btn setBackgroundColor:[UIColor redColor]];
        [btn setTitle:@"Delete" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(deleteResource) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
    {
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(160, 160, 100, 50)];
        [btn setBackgroundColor:[UIColor redColor]];
        [btn setTitle:@"All info" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(allResource) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
    
    {
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(50, 260, 100, 50)];
        [btn setBackgroundColor:[UIColor redColor]];
        [btn setTitle:@"Delete All" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(deleteAll) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
}

- (void)testForDownload {
    [self exeDownload];
}

- (void)exeDownload {
    [[WYWebResourceManager sharedManager] requestWYWebResource:[self testURL]
                                                      progress:^(NSProgress *progress, NSURL *targetURL) {
                                                          
                                                      }
                                                    completion:^(NSDictionary * resourceInfo, NSError *error, NSURL *url) {
                                                        NSLog(@"\nresource:\n%@, \nerror:%@, \nurl:%@", resourceInfo, error, url);
                                                    }];
}

- (void)deleteResource {
    NSURL *waitToDelete = [self testURL];
    NSLog(@"delete: %@", [waitToDelete lastPathComponent]);
    [[WYWebResourceManager sharedManager] deleteCache:waitToDelete];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"%@", [[WYWebResourceManager sharedManager] localResource:kWYWebResource withCheckFileExist:YES]);
    });
}

- (void)deleteAll {
    [[WYWebResourceManager sharedManager] deleteAllCache];
}

- (NSURL *)testURL {
    NSURL *result = [NSURL URLWithString:@"https://firebasestorage.googleapis.com/v0/b/wydemo-93c17.appspot.com/o/zip%2F1000.zip?alt=media&token=766cad4a-070f-4cc2-90de-6f7948c7d281"];
    return result;
}

- (void)testForLocalFile {
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"Test" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *resourcePath = [bundle pathForResource:@"3000" ofType:@"zip"];
    
    [[WYWebResourceManager sharedManager] requestWYWebResource:[NSURL fileURLWithPath:resourcePath]
                                                      progress:nil
                                                    completion:^(NSDictionary * _Nullable resourceInfo, NSError * _Nonnull error, NSURL * _Nonnull url) {
                                                        NSLog(@"resource:%@, \nerror:%@, \nurl:%@", resourceInfo, error, url);
                                                    }];
}

- (void)allResource {
    NSLog(@"%@", [[WYWebResourceManager sharedManager] localResource:kWYWebResource withCheckFileExist:YES]);
}


@end
