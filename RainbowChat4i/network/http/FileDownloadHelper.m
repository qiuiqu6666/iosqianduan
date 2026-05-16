//telegram @wz662
#import "FileDownloadHelper.h"
#import "AvatarHelper.h"
#import "SDWebImageManager.h"
#import "SDWebImageDefine.h"
#import "SDWebImageDownloaderRequestModifier.h"
#import "SDImageCache.h"
#import "UploadPhotoHelper.h"
#import "PhoneAlbumHelper.h"
#import "AFURLSessionManager.h"
#import "BasicTool.h"
#import "GroupsViewController.h"
#import "EVAToolKits.h"
#import "FileTool.h"
#import "IMClientManager.h"
#import "GroupEntity.h"
#import <AVFoundation/AVFoundation.h>

@implementation FileDownloadHelper

+ (BOOL)isVideoAvatarFileName:(NSString *)fileName
{
    if (fileName.length == 0) return NO;
    NSString *ext = [fileName pathExtension].lowercaseString;
    return [ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"] || [ext isEqualToString:@"webm"];
}

+ (UIImage *)getUserAvatarFromSDImageCache:(NSString *)avatarFileDownloadPath donotLoadFromDisk:(BOOL)donot
{
    UIImage *image = nil;
    // 不尝试从SD卡读取缓存（只从内存）
    if(donot)
    {
        //** 缓存加载顺序：内存 > 网络
        // 先看看该图片是否已在于SDWebImage的内存缓存中（仅查内存缓存哦，原因是头像加载url是uid固定样式
        // ，一旦SD卡中缓存后，就不能及时更新了，现在的缓存方式是可以保证重新启动app后可以重新刷新最新头像）
        image = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:avatarFileDownloadPath];
    }
    else
    {
        //** 缓存加载顺序：内存 > SD卡 > 网络
        image = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:avatarFileDownloadPath];
    }

    return image;
}

+ (void)getUserAvatarFromCacheAsync:(NSString *)avatarFileDownloadPath donotLoadFromDisk:(BOOL)donot completion:(void (^)(UIImage * _Nullable))completion
{
    if (!completion) return;
    UIImage *mem = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:avatarFileDownloadPath];
    if (mem) {
        completion(mem);
        return;
    }
    if (donot) {
        completion(nil);
        return;
    }
    [[SDImageCache sharedImageCache] queryCacheOperationForKey:avatarFileDownloadPath options:0 done:^(UIImage * _Nullable image, NSData * _Nullable data, SDImageCacheType cacheType) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(image); });
    }];
}

+ (NSString *)getUserAvatarDownloadURLExt:(BOOL)useAvatarFileName fileName:(NSString *)fileNameForAvatar uid:(NSString *)uidForAvatar
{
    // 正常情况下使用uid得到的图片下载完整URL地址
    NSString *fileDownloadPath = [AvatarHelper getUserAvatarDownloadURL:uidForAvatar];

    // 如果是使用文件名加载头像的方式，要在url尾巴上加上一个tag，以备本地缓存时能加上md5文件名特征，否则下次从缓存加载时如何区别该图片是否是最新的？
    // 其实Android上不需要这么做，因为ANdroid上的图片缓存机制是在指定下载URL时，URL只用于下载，而缓存的文件名是可以自已指定为它本身的md5文件名，
    // 但ios里用到的SDWebImage里的组存方式是直接用下载URL作为缓存key，如果像android一样不加个这个md5文件名tag的话，下次加载到组存时就不知是否最新了。
    // 目前loadUserAvatarWithUID和loadUserAvatarWithFileName的区别其实也就在于是否加了这个本地缓存tag的尾巴而已（原因是uid加载的场景下可能
    // 拿不到指定用户的头像文件名，详见 方法说明）
    if(useAvatarFileName)
        fileDownloadPath = [NSString stringWithFormat:@"%@&ioslocalcachetag=%@", fileDownloadPath, fileNameForAvatar];

    return fileDownloadPath;
}

// 本方法将智能判断，从而决定是用头像文件名还是uid加载用户头像图片（头像文件名是头像图片的md5组成的，优先用文件名加载，则有利于在用户更改头像时及时更新显示）
+ (void)loadUserAvatarIntelligent:(NSString *)fileNameForAvatar uid:(NSString *)uid logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete donotLoadFromDisk:(BOOL)donot {
    // 头像文件名不为空的情况下，优先用文件名加载，这样可以在用户更改头像时（头像文件名是头像图片的md5组成的）能及时加载到最新的头像图片
    if(![BasicTool isStringEmpty:fileNameForAvatar])
    {
        [FileDownloadHelper loadUserAvatarWithFileName:fileNameForAvatar
                                                   uid:uid
                                                logTag:tag
                                              complete:complete];
    }
    // 否则，无法取得头像文件名的情况下就退而求其次，用uid加载头像
    else {
        [FileDownloadHelper loadUserAvatarWithUID:uid
                                           logTag:tag
                                         complete:complete
                                donotLoadFromDisk:donot];
    }
}

+ (void)loadUserAvatarWithFileName:(NSString *)fileNameForAvatar uid:(NSString *)uid logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete
{
    [FileDownloadHelper loadUserAvatar:YES fileName:fileNameForAvatar uid:uid logTag:tag complete:complete donotLoadFromDisk:NO];
}

+ (void)loadUserAvatarWithUID:(NSString *)uidForAvatar logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete donotLoadFromDisk:(BOOL)donot
{
    [FileDownloadHelper loadUserAvatar:NO fileName:nil uid:uidForAvatar logTag:tag complete:complete donotLoadFromDisk:donot];
}

+ (void) loadUserAvatar:(BOOL)useAvatarFileName fileName:(NSString *)fileNameForAvatar uid:(NSString *)uidForAvatar logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete donotLoadFromDisk:(BOOL)donot
{
    if((useAvatarFileName && fileNameForAvatar != nil && uidForAvatar != nil) || (!useAvatarFileName && uidForAvatar != nil))
    {
//        // 正常情况下使用uid得到的图片下载完整URL地址
//        NSString *fileDownloadPath = [AvatarHelper getUserAvatarDownloadURL:uidForAvatar];
//
//        // 如果是使用文件名加载头像的方式，要在url尾巴上加上一个tag，以备本地缓存时能加上md5文件名特征，否则下次从缓存加载时如何区别该图片是否是最新的？
//        // 其实Android上不需要这么做，因为ANdroid上的图片缓存机制是在指定下载URL时，URL只用于下载，而缓存的文件名是可以自已指定为它本身的md5文件名，
//        // 但ios里用到的SDWebImage里的组存方式是直接用下载URL作为缓存key，如果像android一样不加个这个md5文件名tag的话，下次加载到组存时就不知是否最新了。
//        // 目前loadUserAvatarWithUID和loadUserAvatarWithFileName的区别其实也就在于是否加了这个本地缓存tag的尾巴而已（原因是uid加载的场景下可能
//        // 拿不到指定用户的头像文件名，详见 方法说明）
//        if(useAvatarFileName)
//            fileDownloadPath = [NSString stringWithFormat:@"%@&ioslocalcachetag=%@", fileDownloadPath, fileNameForAvatar];

        // 头像图片下载完整URL地址
        NSString *fileDownloadPath = [FileDownloadHelper getUserAvatarDownloadURLExt:useAvatarFileName fileName:fileNameForAvatar uid:uidForAvatar];

        // 先查内存；若需磁盘则走异步解码，避免主线程 CGImageCreateDecoded 卡顿（P0-1）
        if (donot) {
            UIImage *image = [FileDownloadHelper loadUserAvatarFromCacheOnly:fileDownloadPath donotLoadFromDisk:YES];
            if (image) { complete(YES, image); return; }
            complete(NO, nil);
            return;
        }
        [FileDownloadHelper getUserAvatarFromCacheAsync:fileDownloadPath donotLoadFromDisk:NO completion:^(UIImage *image) {
            if (image != nil) {
                complete(YES, image);
                return;
            }
            // 该图片不存（则通过网络下载之）
            DDLogDebug(@"【%@】用户头像缓存为空，马上开始下载（url=%@）!", tag, fileDownloadPath);
            // 不支持视频头像，仅图片头像走下载
            if (useAvatarFileName && [FileDownloadHelper isVideoAvatarFileName:fileNameForAvatar]) {
                if (complete) complete(NO, nil);
            } else {
                __weak NSString *wUid = uidForAvatar;
                [FileDownloadHelper loadUserAvatarFromInternetOnly:fileDownloadPath logTag:tag complete:^(BOOL sucess, UIImage *img) {
                    if (sucess && img != nil && wUid.length > 0) {
                        // 同时用 uid-only key 存一份，列表仅带 uid（如 1008-26-7 未带 fileName）时也能从磁盘秒出
                        NSString *uidOnlyKey = [FileDownloadHelper getUserAvatarDownloadURLExt:NO fileName:nil uid:wUid];
                        if (uidOnlyKey.length > 0 && ![uidOnlyKey isEqualToString:fileDownloadPath])
                            [[SDImageCache sharedImageCache] storeImage:img forKey:uidOnlyKey toDisk:YES completion:nil];
                    }
                    if (complete) complete(sucess, img);
                }];
            }
        }];
    }
    else
    {
        DDLogDebug(@"【%@】载入用户头像失败，因为参数错误，不应为nil!", tag);
        complete(NO, nil);
    }
}

+ (UIImage *)loadUserAvatarFromCacheOnly:(NSString *)fileDownloadPath donotLoadFromDisk:(BOOL)donot
{
    return [FileDownloadHelper getUserAvatarFromSDImageCache:fileDownloadPath donotLoadFromDisk:donot];
}

+ (void)loadUserAvatarVideoFirstFrameWithURL:(NSString *)fileDownloadPath logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete
{
    NSURL *url = [NSURL URLWithString:fileDownloadPath];
    if (url == nil) {
        if (complete) complete(NO, nil);
        return;
    }
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    tempPath = [tempPath stringByAppendingPathExtension:@"mp4"];
    NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
    // 头像下载接口无需鉴权（见《用户头像-前端对接文档》）
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || data.length == 0) {
            DDLogDebug(@"【%@】短视频头像下载失败：%@", tag, error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{ if (complete) complete(NO, nil); });
            return;
        }
        NSError *writeErr = nil;
        if (![data writeToURL:tempURL options:NSDataWritingAtomic error:&writeErr]) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (complete) complete(NO, nil); });
            return;
        }
        AVURLAsset *asset = [AVURLAsset assetWithURL:tempURL];
        AVAssetImageGenerator *gen = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        gen.appliesPreferredTrackTransform = YES;
        gen.maximumSize = CGSizeMake(640, 640);
        CMTime t = CMTimeMakeWithSeconds(0, 600);
        NSError *imgErr = nil;
        CGImageRef cg = [gen copyCGImageAtTime:t actualTime:NULL error:&imgErr];
        [[NSFileManager defaultManager] removeItemAtURL:tempURL error:nil];
        if (cg == NULL) {
            DDLogDebug(@"【%@】短视频首帧提取失败：%@", tag, imgErr.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{ if (complete) complete(NO, nil); });
            return;
        }
        UIImage *image = [UIImage imageWithCGImage:cg];
        CGImageRelease(cg);
        if (image) {
            [[SDImageCache sharedImageCache] storeImage:image forKey:fileDownloadPath completion:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (complete) complete(image != nil, image);
        });
    }] resume];
}

#pragma mark - 短视频头像本地文件缓存（有则直接播放，不显示首帧）

+ (NSString *)avatarVideoCachePathForUid:(NSString *)uid fileName:(NSString *)fileName
{
    if (uid.length == 0 || fileName.length == 0) return nil;
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"AvatarVideo"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *safe = [[NSString stringWithFormat:@"%@_%@", uid, fileName] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [dir stringByAppendingPathComponent:safe];
}

+ (void)downloadAvatarVideoWithUid:(NSString *)uid fileName:(NSString *)fileName complete:(void (^)(BOOL success, NSURL * _Nullable localFileURL))complete
{
    NSString *path = [self avatarVideoCachePathForUid:uid fileName:fileName];
    if (path.length == 0) {
        if (complete) dispatch_async(dispatch_get_main_queue(), ^{ complete(NO, nil); });
        return;
    }
    NSString *urlString = [AvatarHelper getUserAvatarDownloadURL:uid localCurrentCached:fileName enforceDawnload:YES];
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil) {
        if (complete) dispatch_async(dispatch_get_main_queue(), ^{ complete(NO, nil); });
        return;
    }
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        BOOL ok = (error == nil && data.length > 0);
        if (ok) {
            NSError *writeErr = nil;
            ok = [data writeToFile:path options:NSDataWritingAtomic error:&writeErr];
        }
        NSURL *fileURL = ok ? [NSURL fileURLWithPath:path] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (complete) complete(ok, fileURL);
        });
    }] resume];
}

+ (void)loadUserAvatarFromInternetOnly:(NSString *)fileDownloadPath logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete
{
    SDWebImageManager *manager = [SDWebImageManager sharedManager];
    [manager loadImageWithURL:[NSURL URLWithString:fileDownloadPath]
                      options:SDWebImageRetryFailed | SDWebImageFromLoaderOnly
                     progress:nil
                    completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                        if (finished && image != nil) {
                            // 明确写入磁盘，保证下次冷启动可直接从磁盘读出头像，无需等接口
                            [[SDImageCache sharedImageCache] storeImage:image forKey:fileDownloadPath toDisk:YES completion:nil];
                            if (complete) complete(YES, image);
                        } else {
                            if (complete) complete(NO, nil);
                        }
                    }];
}

+ (void)loadUserPhoto:(NSString *)photoFileName logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete
{
    if(photoFileName != nil)
    {
        // 图片下载完整URL地址
        NSString *fileDownloadPath = [UploadPhotoHelper getPhotoDownloadURL:photoFileName];

        DDLogDebug(@"【%@】拼装完成的用户照片URL=%@", tag, fileDownloadPath);

        // 先看看该图片是否已在于SDWebImage有缓存中（内存或SD卡）
        UIImage *image = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:fileDownloadPath];
        // 该图片不存（则通过网络异常下载之）
        if(image == nil)
        {
            DDLogDebug(@"【%@】用户照片缓存为空，马上开始下载!", tag);

            // 异步下载此图片
            SDWebImageManager *manager = [SDWebImageManager sharedManager];
            [manager loadImageWithURL:[NSURL URLWithString:fileDownloadPath]
                                  options:SDWebImageRetryFailed progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL *targetURL) {
//                                      DDLogDebug(@"【%@】照片下载当前进度:%ld/%ld", tag, receivedSize, expectedSize);
                                  } completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                                      DDLogDebug(@"【%@】照片图片下载完成，finished？%d", tag, finished);

                                      // 下载完成
                                      if(finished)
                                      {
                                          // 显示下载完成的用户照片
                                          if(image != nil)
                                              complete(YES, image);
                                          else
                                              complete(NO, nil);
                                      }
                                      
//                                    // 成功下载完成
//                                    if(finished && image != nil)
//                                        complete(YES, image);
//                                    else
//                                        complete(NO, nil);
                                  }];
        }
        // 图片已存在缓存中则直接显示之
        else
        {
            DDLogDebug(@"【%@】用户照片缓存不为空，无需下载立即显示此照片图片。", tag);
            complete(YES, image);
        }
    }
    else
    {
        DDLogDebug(@"【%@】载入用户照片失败，因为参数错误，不应为nil!", tag);
        complete(NO, nil);
    }
}

+ (void)loadPhoneAlbumPhoto:(NSString *)photoFileName ownerUid:(NSString *)ownerUid logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete
{
    if (photoFileName != nil && ownerUid.length > 0)
    {
        NSString *fileDownloadPath = [PhoneAlbumHelper phoneAlbumDownloadURLForOwnerUid:ownerUid fileName:photoFileName];
        DDLogDebug(@"【%@】手机相册图片 URL=%@", tag, fileDownloadPath);
        UIImage *image = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:fileDownloadPath];
        if (image == nil)
        {
            SDWebImageManager *manager = [SDWebImageManager sharedManager];
            [manager loadImageWithURL:[NSURL URLWithString:fileDownloadPath]
                              options:SDWebImageRetryFailed
                             progress:nil
                            completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                                DDLogDebug(@"【%@】手机相册图片下载完成 finished？%d", tag, finished);
                                if (finished)
                                {
                                    if (image != nil) {
                                        complete(YES, image);
                                    } else {
                                        complete(NO, nil);
                                    }
                                }
                            }];
        }
        else
        {
            DDLogDebug(@"【%@】手机相册图片命中缓存", tag);
            complete(YES, image);
        }
    }
    else
    {
        DDLogDebug(@"【%@】载入手机相册图片失败，参数无效", tag);
        complete(NO, nil);
    }
}

// 清空指定群组头像的缓存（同时清除系统默认头像和自定义头像的缓存）
+ (void)clearGroupAvatarCache:(NSString *)gid
{
    if(gid != nil)
    {
        // 1. 清除系统默认群头像缓存（gavartar_d + {gid}.jpg）
        NSString *defaultKey = [GroupsViewController getGroupAvatarDownloadURL:gid customAvatar:nil];
        [[SDImageCache sharedImageCache] removeImageForKey:defaultKey withCompletion:^{
            NSLog(@"【SDImageCache】removeImageForKey(default) %@ complete!", defaultKey);
        }];

        // 2. 清除自定义群头像缓存（image_d + g_custom_avatar）
        GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];
        if(ge != nil && ge.g_custom_avatar != nil && ge.g_custom_avatar.length > 0)
        {
            NSString *customKey = [GroupsViewController getGroupAvatarDownloadURL:gid customAvatar:ge.g_custom_avatar];
            [[SDImageCache sharedImageCache] removeImageForKey:customKey withCompletion:^{
                NSLog(@"【SDImageCache】removeImageForKey(custom) %@ complete!", customKey);
            }];
        }
    }
}

// 加载群组头像（优先使用自定义群头像 g_custom_avatar）
+ (void)loadGroupAvatar:(NSString *)gid logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete
{
    if(gid != nil)
    {
        // 从群组数据中查找自定义头像文件名
        NSString *customAvatar = nil;
        GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];
        if(ge != nil)
            customAvatar = ge.g_custom_avatar;

        // 图片下载完整URL地址（优先使用自定义群头像）
        NSString *fileDownloadPath = [GroupsViewController getGroupAvatarDownloadURL:gid customAvatar:customAvatar];

//        DDLogDebug(@"【%@】拼装完成的群组头像URL=%@", tag, fileDownloadPath);

        // 先查内存缓存；冷启动时再查磁盘缓存，避免先占位图再替换导致闪烁
        UIImage *image = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:fileDownloadPath];
        if (image == nil) {
            image = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:fileDownloadPath];
            if (image != nil) {
                [[SDImageCache sharedImageCache] storeImage:image forKey:fileDownloadPath toDisk:NO completion:nil]; // 仅入内存，避免下次再读盘
            }
        }
        if (image != nil) {
            complete(YES, image);
            return;
        }
        // 内存和磁盘都没有，则异步下载
        {
            DDLogDebug(@"【%@】群组头像缓存为空，马上开始下载（url=%@）!", tag, fileDownloadPath);

            // 异步下载此图片
            SDWebImageManager *manager = [SDWebImageManager sharedManager];
            [manager loadImageWithURL:[NSURL URLWithString:fileDownloadPath]
                                  options:SDWebImageRetryFailed | SDWebImageFromLoaderOnly// 注意：SDWebImageFromLoaderOnly将强迫通过网络下载，因为上面已经提前检查过缓存了
                             progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL *targetURL) {
//                                      DDLogDebug(@"【%@】群组头像下载当前进度:%ld/%ld", tag, (long)receivedSize, expectedSize);
                                  } completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                                      DDLogDebug(@"【%@】群组头像图片下载完成，finished？%d (%@)", tag, finished, imageURL);

                                      // 下载完成
                                      if(finished)
                                      {
                                          // 显示下载完成的群组头像
                                          if(image != nil)
                                              complete(YES, image);
                                          else
                                              complete(NO, nil);
                                      }
                                      
//                                      // 成功下载完成
//                                      if(finished && image != nil)
//                                          complete(YES, image);
//                                      else
//                                          complete(NO, nil);
                                  }];
        }
    }
    else
    {
        DDLogDebug(@"【%@】载入群组头像失败，因为参数错误，不应为nil!", tag);
        complete(NO, nil);
    }
}

+ (void)loadChattingImgWithURL:(NSString *)fileDownloadPath logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete
{
    // 异步下载此图片
    SDWebImageManager *manager = [SDWebImageManager sharedManager];
    [manager loadImageWithURL:[NSURL URLWithString:fileDownloadPath]
                          options:SDWebImageRetryFailed progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL *targetURL) {
        //DDLogDebug(@"【收到图片消息】显示当前进度:%ld/%ld", receivedSize, expectedSize);
    } completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
        DDLogDebug(@"【%@】图片下载完成，finished？%d, image=%@, （%@）", tag, finished, image, imageURL);
        
        // 保证在主线程回调，便于列表 UI 正确刷新与渲染
        dispatch_async(dispatch_get_main_queue(), ^{
            if (complete) {
                if (finished && image != nil)
                    complete(YES, image);
                else
                    complete(NO, nil);
            }
        });
    }];
}

+ (void)loadChattingShortVideoPreviewImgWithURL:(NSString *)fileDownloadPath logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete
{
    if (fileDownloadPath.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (complete) complete(NO, nil);
        });
        return;
    }
    NSURL *url = [NSURL URLWithString:fileDownloadPath];
    if (url == nil) {
        DDLogWarn(@"【%@】预览图 URL 无法解析: %@", tag, fileDownloadPath);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (complete) complete(NO, nil);
        });
        return;
    }

    // ShortVideoThumbDownloader 等业务下行若启用鉴权，须与 FileUploadHelper / HttpRestHelper 一致附带 Authorization（SDWebImage 默认不带）
    NSString *token = [IMClientManager sharedInstance].localUserInfo.token;
    NSDictionary *context = nil;
    if (token.length > 0) {
        SDWebImageDownloaderRequestModifier *modifier = [SDWebImageDownloaderRequestModifier requestModifierWithBlock:^NSURLRequest *_Nonnull(NSURLRequest *_Nonnull request) {
            NSMutableURLRequest *m = [request mutableCopy];
            [m setValue:token forHTTPHeaderField:@"Authorization"];
            return m;
        }];
        context = @{SDWebImageContextDownloadRequestModifier: modifier};
    }

    SDWebImageManager *manager = [SDWebImageManager sharedManager];
    [manager loadImageWithURL:url
                      options:SDWebImageRetryFailed
                      context:context
                     progress:nil
                    completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
        DDLogDebug(@"【%@】预览图片下载完成，finished？%d，image=%@，error=%@，（%@）", tag, finished, image, error, imageURL);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (complete) {
                if (finished && image != nil)
                    complete(YES, image);
                else
                    complete(NO, nil);
            }
        });
    }];
}


// 通用文件下载实用方法（兼容旧版本）
+ (NSURLSessionDownloadTask *)downloadCommonFile:(NSString *)fileURL toDir:(NSString *)saveDir pg:(void (^)(NSProgress *dp))downloadProgressBlock complete:(void (^)(BOOL sucess, NSURL *fileSavedPath))complete
{
    return [self downloadCommonFile:fileURL toDir:saveDir fileName:nil pg:downloadProgressBlock complete:complete];
}

// 通用文件下载实用方法（支持指定文件名）
+ (NSURLSessionDownloadTask *)downloadCommonFile:(NSString *)fileURL toDir:(NSString *)saveDir fileName:(NSString *)fileName pg:(void (^)(NSProgress *dp))downloadProgressBlock complete:(void (^)(BOOL sucess, NSURL *fileSavedPath))complete
{
    NSLog(@"[EVA.Download] ➡ 本次要下载的文件URL=%@, saveDir=%@, fileName=%@", fileURL, saveDir, fileName);

    // 1. 创建会话管理者
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    // 使用的是https
    if([EVAToolKits isHttps:fileURL])
    {
        // 支持https需要的额外设置
        [EVAToolKits setupHttps:manager];
    }

    // 2. 创建下载路径和请求对象
    NSURL *URL = [NSURL URLWithString:fileURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];

    // 3. 创建下载任务
    /**
     * 第一个参数 - request：请求对象
     * 第二个参数 - progress：下载进度block
     *      其中： downloadProgress.completedUnitCount：已经完成的大小
     *            downloadProgress.totalUnitCount：文件的总大小
     * 第三个参数 - destination：自动完成文件剪切操作
     *      其中： 返回值:该文件应该被剪切到哪里
     *            targetPath：临时路径 tmp NSURL
     *            response：响应头
     * 第四个参数 - completionHandler：下载完成回调
     *      其中： filePath：真实路径 == 第三个参数的返回值
     *            error:错误信息
     */
    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request
        progress:^(NSProgress *downloadProgress) {

        // 下载进度：0~1.0f
        float pv = 1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount;
        NSLog(@"[EVA.Download] 》》》》数据下载进度> %lf", pv);

        if(downloadProgressBlock){
            downloadProgressBlock(downloadProgress);
        }

        // 回到主队列刷新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            // 设置进度条的百分比
            // TODO: UI refresh!
        });
            
    } destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {

        // 优先使用指定的文件名，如果没有指定则使用服务器返回的文件名
        NSString *finalFileName = fileName;
        if(finalFileName == nil || finalFileName.length == 0)
        {
            finalFileName = [response suggestedFilename];
            // 如果服务器也没有返回文件名，则从URL中提取
            if(finalFileName == nil || finalFileName.length == 0)
            {
                finalFileName = [fileURL lastPathComponent];
            }
        }
        
        NSString *saveToFullPath = [saveDir stringByAppendingPathComponent:finalFileName];

        NSLog(@"[EVA.Download] 》》》》要保存的文件路径全名为：%@", saveToFullPath);

        // 如果要保存的目录不存在，则尝试创建之
        [FileTool tryCreateDirs:saveDir];

        // 返回本次要保存文件的绝对路径
        return [NSURL fileURLWithPath:saveToFullPath];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {

        NSLog(@"[EVA.Download] 下载完成：File downloaded to \"%@\"", filePath);

        if (error)
        {
            NSLog(@"[EVA.Download] 出错了Error=%@", error);

            if(complete)
            {
                complete(NO, nil);
            }
        }
        else
        {
            NSLog(@"[EVA.Download] 下载成功完成了，response=%@", response);
            complete(YES, filePath); // 补充：下载出问题的情况下，filePath会是nil
        }
    }];

    [downloadTask resume];
    
    return downloadTask;
}

@end
