#import "StickerManager.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "SDWebImageManager.h"
#import "SDImageCache.h"
#import <CommonCrypto/CommonDigest.h>

@interface StickerManager ()

@property (nonatomic, strong, readwrite) NSArray<NSDictionary *> *stickerList;
@property (nonatomic, assign, readwrite) BOOL loaded;
@property (nonatomic, strong) NSCache *imageCache; // 内存缓存

@end

@implementation StickerManager

+ (instancetype)sharedInstance
{
    static StickerManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[StickerManager alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _stickerList = @[];
        _loaded = NO;
        _imageCache = [[NSCache alloc] init];
        _imageCache.countLimit = 200;
        
        // 确保缓存目录存在
        NSString *cacheDir = [self stickerCacheDirectory];
        if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return self;
}

#pragma mark - 公开方法

- (void)refreshStickersFromServer:(void (^)(BOOL success))complete
{
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!uid || uid.length == 0) {
        if (complete) complete(NO);
        return;
    }
    
    [[HttpRestHelper sharedInstance] submitGetStickersFromServer:uid complete:^(BOOL sucess, NSArray<NSDictionary *> *stickerList) {
        if (sucess) {
            // 按 sort_order 升序排列
            NSArray *sorted = [stickerList sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                int orderA = [[a objectForKey:@"sort_order"] intValue];
                int orderB = [[b objectForKey:@"sort_order"] intValue];
                return orderA - orderB;
            }];
            self.stickerList = sorted;
            self.loaded = YES;
            if (complete) complete(YES);
        } else {
            if (complete) complete(NO);
        }
    } hudParentView:nil];
}

- (void)uploadSticker:(UIImage *)image complete:(void (^)(BOOL success))complete
{
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!uid || uid.length == 0) {
        if (complete) complete(NO);
        return;
    }
    
    // 压缩图片并计算 MD5 命名
    NSData *imageData = UIImagePNGRepresentation(image);
    if (!imageData) {
        imageData = UIImageJPEGRepresentation(image, 0.8);
    }
    if (!imageData || imageData.length == 0) {
        if (complete) complete(NO);
        return;
    }
    
    // 限制 500KB
    if (imageData.length > 500 * 1024) {
        // 降质量压缩
        CGFloat quality = 0.5;
        imageData = UIImageJPEGRepresentation(image, quality);
        while (imageData.length > 500 * 1024 && quality > 0.1) {
            quality -= 0.1;
            imageData = UIImageJPEGRepresentation(image, quality);
        }
    }
    
    NSString *md5 = [self md5ForData:imageData];
    NSString *fileName = [NSString stringWithFormat:@"%@.png", md5];
    
    [[HttpRestHelper sharedInstance] uploadStickerToServer:uid fileName:fileName imageData:imageData complete:^(BOOL success) {
        if (success) {
            // 上传成功后刷新列表
            [self refreshStickersFromServer:^(BOOL refreshSuccess) {
                if (complete) complete(YES);
            }];
        } else {
            if (complete) complete(NO);
        }
    }];
}

- (void)deleteStickers:(NSArray<NSString *> *)ids complete:(void (^)(BOOL success))complete
{
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!uid || uid.length == 0 || ids.count == 0) {
        if (complete) complete(NO);
        return;
    }
    
    NSString *idsStr = [ids componentsJoinedByString:@","];
    
    [[HttpRestHelper sharedInstance] submitDeleteStickersToServer:uid ids:idsStr complete:^(BOOL sucess, NSString *resultCode) {
        if (sucess && [resultCode isEqualToString:@"1"]) {
            // 删除成功后刷新列表
            [self refreshStickersFromServer:^(BOOL refreshSuccess) {
                if (complete) complete(YES);
            }];
        } else {
            if (complete) complete(NO);
        }
    } hudParentView:nil];
}

- (NSString *)stickerDownloadURL:(NSDictionary *)stickerInfo
{
    // 优先使用 OSS 直链（原图）- 加 NSNull 安全检查
    id urlObj = [stickerInfo objectForKey:@"url"];
    if (urlObj && [urlObj isKindOfClass:[NSString class]] && [(NSString *)urlObj length] > 0) {
        return (NSString *)urlObj;
    }
    
    // 拼接 BinaryDownloader URL（最可靠的下载方式）
    NSString *fileName = [stickerInfo objectForKey:@"file_name"];
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    return [self stickerDownloadURLForFileName:fileName userUid:uid];
}

- (NSString *)stickerThumbnailURL:(NSDictionary *)stickerInfo
{
    // 优先使用 OSS 缩略图直链（120×120）- 加 NSNull 安全检查
    id thumbObj = [stickerInfo objectForKey:@"thumbnail_url"];
    if (thumbObj && [thumbObj isKindOfClass:[NSString class]] && [(NSString *)thumbObj length] > 0) {
        return (NSString *)thumbObj;
    }
    // 无缩略图时回退到原图 URL
    return [self stickerDownloadURL:stickerInfo];
}

- (NSString *)stickerDownloadURLForFileName:(NSString *)fileName userUid:(NSString *)userUid
{
    return [NSString stringWithFormat:@"%@?action=sticker_d&file_name=%@&user_uid=%@",
            STICKER_DOWNLOADER_CONTROLLER_URL_ROOT, fileName, userUid];
}

- (void)loadStickerThumbnail:(NSDictionary *)stickerInfo complete:(void (^)(UIImage * _Nullable image))complete
{
    NSString *fileName = [stickerInfo objectForKey:@"file_name"];
    if (!fileName || ![fileName isKindOfClass:[NSString class]] || fileName.length == 0) {
        if (complete) complete(nil);
        return;
    }
    
    // 缩略图 key = "th_" + fileName，区分原图缓存
    NSString *thumbKey = [NSString stringWithFormat:@"th_%@", fileName];
    
    // 1. 检查内存缓存（快速路径）
    UIImage *cached = [self.imageCache objectForKey:thumbKey];
    if (cached) {
        if (complete) complete(cached);
        return;
    }
    
    // 2. 使用 SDWebImageManager 下载缩略图（与应用其他图片下载机制一致）
    NSString *urlStr = [self stickerThumbnailURL:stickerInfo];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        NSLog(@"【StickerManager】缩略图 URL 无效: %@", urlStr);
        // URL 无效时直接尝试 BinaryDownloader URL
        NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        NSString *fallbackUrlStr = [self stickerDownloadURLForFileName:fileName userUid:uid];
        url = [NSURL URLWithString:fallbackUrlStr];
    if (!url) {
        if (complete) complete(nil);
        return;
    }
    }
    
    NSLog(@"【StickerManager】开始下载缩略图: %@", url);
    
    SDWebImageManager *manager = [SDWebImageManager sharedManager];
    [manager loadImageWithURL:url
                      options:SDWebImageRetryFailed
                     progress:nil
                    completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        if (finished && image) {
            // 缓存到自定义内存缓存（加速后续访问）
            [self.imageCache setObject:image forKey:thumbKey];
            NSLog(@"【StickerManager】缩略图加载成功: %@ (cacheType=%ld)", fileName, (long)cacheType);
            if (complete) complete(image);
        } else if (finished) {
            // 缩略图下载失败 → 回退到原图
            NSLog(@"【StickerManager】缩略图下载失败(error=%@)，回退到原图: %@", error, fileName);
            [self loadStickerImage:stickerInfo complete:complete];
        }
    }];
}

- (void)loadStickerImage:(NSDictionary *)stickerInfo complete:(void (^)(UIImage * _Nullable image))complete
{
    NSString *fileName = [stickerInfo objectForKey:@"file_name"];
    if (!fileName || ![fileName isKindOfClass:[NSString class]] || fileName.length == 0) {
        if (complete) complete(nil);
        return;
    }
    
    // 1. 检查内存缓存（快速路径）
    UIImage *cached = [self.imageCache objectForKey:fileName];
    if (cached) {
        if (complete) complete(cached);
        return;
    }
    
    // 2. 构造下载 URL：始终使用 BinaryDownloader URL（最可靠）
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    NSString *urlStr = [self stickerDownloadURLForFileName:fileName userUid:uid];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        NSLog(@"【StickerManager】原图 URL 无效: %@", urlStr);
        if (complete) complete(nil);
        return;
    }
    
    NSLog(@"【StickerManager】开始下载原图: %@", url);
    
    // 3. 使用 SDWebImageManager 下载原图（与应用其他图片下载机制一致）
    SDWebImageManager *manager = [SDWebImageManager sharedManager];
    [manager loadImageWithURL:url
                      options:SDWebImageRetryFailed
                     progress:nil
                    completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        if (finished && image) {
            // 缓存到自定义内存缓存（加速后续访问）
            [self.imageCache setObject:image forKey:fileName];
            NSLog(@"【StickerManager】原图加载成功: %@ (cacheType=%ld)", fileName, (long)cacheType);
            if (complete) complete(image);
        } else if (finished) {
            NSLog(@"【StickerManager】原图下载失败: %@, error=%@", fileName, error);
            if (complete) complete(nil);
        }
    }];
}

- (NSString *)stickerCacheDirectory
{
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [cachePath stringByAppendingPathComponent:@"CustomStickers"];
}

#pragma mark - 工具方法

- (NSString *)md5ForData:(NSData *)data
{
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

@end
