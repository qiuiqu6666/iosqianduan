//telegram @wz662
#import "AvatarHelper.h"
#import "AppDelegate.h"
#import "FileUploadHelper.h"
#import "IMClientManager.h"
#import "FileTool.h"

@implementation AvatarHelper

//--------------------------------------------------------------------------
#pragma mark - 头像上传相关方法

+ (NSString *)constructAvatarFileName:(NSString *)md5ForCachedAvatar uid:(NSString *)localUid
{
    return [AvatarHelper constructAvatarFileName:md5ForCachedAvatar uid:localUid extension:@"jpg"];
}

+ (NSString *)constructAvatarFileName:(NSString *)md5ForCachedAvatar uid:(NSString *)localUid extension:(NSString *)ext
{
    if(md5ForCachedAvatar == nil || localUid == nil)
    {
        DDLogWarn(@"[SendImageHelper] 无效的参数：md5ForImage == nil or localUid == nil!");
        return nil;
    }
    if (ext.length == 0) ext = @"jpg";
    return [NSString stringWithFormat:@"%@_%@.%@", localUid, md5ForCachedAvatar, ext];
}

+ (NSString *)getUserAvatarSavedDirHasSlash
{
    NSString *dir = [AvatarHelper getUserAvatarSavedDir];
    return dir ==  nil? nil : [NSString stringWithFormat:@"%@/", dir];
}

+ (NSString *)getUserAvatarSavedDir
{
    NSString *dir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_AVATART_RELATIVE_DIR];
    return dir;
}

+ (NSString *)preparedAvatarForUpload:(UIImage *)sourceImage
{
    @try
    {
        NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        NSString *savedDir = [AvatarHelper getUserAvatarSavedDir];

        //** 先压缩图片（缩小尺寸、压缩质量）
        // 加工处理完成前的临时文件名
        NSString *tempNameAfterCompress = @"_temp_local_avatar";
        NSString *filePathAfterCompress = [BasicTool imageCompressForQualityAndWidth:sourceImage
                                                                       targetQuality:LOCAL_AVATAR_IMAGE_QUALITY
                                                                         targetWidth:LOCAL_AVATAR_SIZE
                                                                           saveToDir:savedDir
                                                                           savedName:[AvatarHelper constructAvatarFileName:tempNameAfterCompress uid:localUid]];
        DDLogDebug(@"【本人头像的图片文件准备】图片压缩完成，压缩后保存的路径为：%@", filePathAfterCompress);

        //** 再用MD5码重命名该图片文件
        // 图片压缩成功
        if(filePathAfterCompress != nil)
        {
            //** 再获取该文件的MD5码文件名
            NSString *md5ForFile = [FileTool getFileMD5WithPath:filePathAfterCompress];
            NSString *newFileNameWithMD5 = [AvatarHelper constructAvatarFileName:md5ForFile uid:localUid];
            DDLogDebug(@"【本人头像的图片文件准备】已计算出压缩后的新图片文件MD5码文件名：%@", newFileNameWithMD5);

            //** 再重命名文件为MD5码的形式
            NSString *renamePath = [NSString stringWithFormat:@"%@/%@", savedDir, newFileNameWithMD5];
            BOOL renameSucess = [FileTool renameFile:filePathAfterCompress toFilePath:renamePath];
            DDLogDebug(@"【本人头像的图片文件准备】压缩后的图片文件重命名为%@ 是否成功？%d", renamePath, renameSucess);

            return newFileNameWithMD5;
        }
        else
        {
            return nil;
        }
    }
    @catch (NSException *exception)
    {
        DDLogError(@"【本人头像的图片文件准备】过程中发生了异常，Exception: %@", exception);
        AlertError(@"很抱歉，本人头像图片处理失败，请稍后重试！");
        return nil;
    }
}

+ (NSString *)preparedAvatarForUploadGifAtURL:(NSURL *)gifFileURL
{
    if (gifFileURL == nil || !gifFileURL.isFileURL) {
        DDLogWarn(@"【本人头像GIF准备】无效的 fileURL");
        return nil;
    }
    NSString *path = gifFileURL.path;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        DDLogWarn(@"【本人头像GIF准备】GIF 文件不存在：%@", path);
        return nil;
    }
    @try {
        NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        NSString *savedDir = [AvatarHelper getUserAvatarSavedDir];
        if (![[NSFileManager defaultManager] fileExistsAtPath:savedDir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:savedDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSString *md5ForFile = [FileTool getFileMD5WithPath:path];
        if (md5ForFile.length == 0) {
            DDLogWarn(@"【本人头像GIF准备】MD5 计算失败");
            return nil;
        }
        NSString *fileName = [AvatarHelper constructAvatarFileName:md5ForFile uid:localUid extension:@"gif"];
        NSString *destPath = [NSString stringWithFormat:@"%@/%@", savedDir, fileName];
        NSError *err = nil;
        if ([[NSFileManager defaultManager] copyItemAtPath:path toPath:destPath error:&err]) {
            DDLogDebug(@"【本人头像GIF准备】已复制 GIF 到：%@", destPath);
            return fileName;
        }
        DDLogWarn(@"【本人头像GIF准备】复制失败：%@", err.localizedDescription);
        return nil;
    } @catch (NSException *exception) {
        DDLogError(@"【本人头像GIF准备】异常：%@", exception);
        return nil;
    }
}

+ (NSString *)preparedAvatarForUploadVideoAtPath:(NSString *)videoPath
{
    if (videoPath.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
        DDLogWarn(@"【本人头像短视频准备】无效或文件不存在：%@", videoPath);
        return nil;
    }
    @try {
        NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        NSString *savedDir = [AvatarHelper getUserAvatarSavedDir];
        if (![[NSFileManager defaultManager] fileExistsAtPath:savedDir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:savedDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSString *ext = [videoPath pathExtension].lowercaseString;
        if (ext.length == 0) ext = @"mp4";
        if (![ext isEqualToString:@"mp4"] && ![ext isEqualToString:@"mov"] && ![ext isEqualToString:@"webm"]) {
            ext = @"mp4";
        }
        NSString *md5ForFile = [FileTool getFileMD5WithPath:videoPath];
        if (md5ForFile.length == 0) {
            DDLogWarn(@"【本人头像短视频准备】MD5 计算失败");
            return nil;
        }
        NSString *fileName = [AvatarHelper constructAvatarFileName:md5ForFile uid:localUid extension:ext];
        NSString *destPath = [NSString stringWithFormat:@"%@/%@", savedDir, fileName];
        NSError *err = nil;
        if ([[NSFileManager defaultManager] copyItemAtPath:videoPath toPath:destPath error:&err]) {
            DDLogDebug(@"【本人头像短视频准备】已复制到：%@", destPath);
            return fileName;
        }
        DDLogWarn(@"【本人头像短视频准备】复制失败：%@", err.localizedDescription);
        return nil;
    } @catch (NSException *exception) {
        DDLogError(@"【本人头像短视频准备】异常：%@", exception);
        return nil;
    }
}

+ (void)processAvatarUpload:(NSString *)imageFileName
                processing:(void (^)())processing processFaild:(void (^)())processFaild processOk:(void (^)())processOk
{
    // 将处理结果通知观察者
    if(processing != nil)
        processing();

    if(imageFileName == nil)
    {
        DDLogWarn(@"【UploadAvatar】要上传的图片文件名居然是nil!");
        // 将处理结果通知观察者
        if(processFaild != nil)
            processFaild();
        return;
    }

    @try
    {
        NSString *fp = [NSString stringWithFormat:@"%@%@", [AvatarHelper getUserAvatarSavedDirHasSlash], imageFileName];
        long long fileSize = [FileTool fileSizeAtPath:fp];

        if(fileSize <= 0)
        {
            DDLogWarn(@"【UploadAvatar】要上传的头像大小为0，本次图片上传没有继续！");
            [APP showToastWarn:@"要上传的头像文件大小为0，上传失败！"];

            // 将处理结果通知观察者
            if(processFaild != nil)
                processFaild();

            return;
        }
        else
        {
            // 短视频头像允许 50MB（与《用户头像-前端对接文档》一致），静态图/GIF 仍按 2MB
            long long maxSize = LOCAL_AVATAR_FILE_DATA_MAX_LENGTH;
            NSString *ext = [imageFileName pathExtension].lowercaseString;
            if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"] || [ext isEqualToString:@"webm"]) {
                maxSize = 50LL * 1024 * 1024;
            }
            if (fileSize > maxSize)
            {
                DDLogWarn(@"【UploadAvatar】要上传的头像大小大于%lld字节，上传（到服务端）没有继续！", maxSize);
                [APP showToastWarn:@"要上传的头像过大，上传失败！"];
                if(processFaild != nil) processFaild();
                return;
            }
        }
        NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;

            // 正式开始文件上传
            [AvatarHelper uploadAvatarFileImpl:imageFileName localUid:localUid completeFail:^(NSError *error) {
                // 将处理结果通知观察者
                if(processFaild != nil)
                    processFaild();
            } completeSucess:^(id responseObject) {
                // 将处理结果通知观察者
                if(processOk != nil)
                    processOk();
            }];
    }
    @catch (NSException * e)
    {
        DDLogError(@"【UploadAvatar】Exception: %@", e);
        return;
    }
}

/**
 * 通过HTTP上传本人头像文件的实现方法.
 *
 * @param fileName 服务端收到文件数据后要保存的文件名
 * @param localUserUid 上传者的uid
 */
+ (void)uploadAvatarFileImpl:(NSString *)fileName localUid:(NSString *)localUserUid completeFail:(void (^)(NSError *error))failure completeSucess:(void (^)(id responseObject))success
{
    NSString *uid = localUserUid;

    // 原始文件路径
    NSString *fileFullPath = [NSString stringWithFormat:@"%@%@", [AvatarHelper getUserAvatarSavedDirHasSlash], fileName];
    DDLogDebug(@"【UploadAvatar】>>>>>>>>>>>>>> fileFullPath=%@", fileFullPath);

    // ** 注意：经反复测试，此url一定不能带参数，不然总是在上传时卡住（原因不清楚，可能是AF3的bug！）
    NSString *urlString = AVATAR_UPLOAD_CONTROLLER_URL_ROOT;

    // 额外参数
    NSMutableDictionary *parameter = [NSMutableDictionary dictionary];
    parameter[@"user_uid"] = uid;
    parameter[@"file_name"] = fileName;

    // 开始上传
    [FileUploadHelper uploadFileImpl:fileFullPath
                            withName:fileName
                              andUrl:urlString
                       andParameters:parameter
                            progress:^(NSProgress * _Nonnull uploadProgress) {
                                //打印下上传进度
                                DDLogDebug(@"【UploadAvatar】上传进度> %lf", 1.0 * uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
                            }
                             success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                                 //请求成功
                                 DDLogDebug(@"【UploadAvatar】请求成功：%@", responseObject);

                                 if(success)
                                     success(responseObject);
                             }
                             failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                 //请求失败
                                 DDLogDebug(@"【UploadAvatar】请求失败：%@", error);

                                 if(failure)
                                     failure(error);
                             }
     ];







//    // 额外参数
//    // NSDictionary *dict = @{@"user_uid":@"1234"};
//    NSMutableDictionary *parameter = [NSMutableDictionary dictionary];
//    parameter[@"user_uid"] = uid;
//    parameter[@"file_name"] = fileName;
//    parameter[@"token"] = @"999999999999999_token"; // just for test
//
//    [FileUploadHelper uploadFileImpl:fileFullPath
//                            withName:fileName
//                              andUrl:urlString
//                       andParameters:parameter
//                            progress:^(NSProgress * _Nonnull uploadProgress) {
//                                //打印下上传进度
//                                DDLogDebug(@"【SendPic】上传进度> %lf", 1.0 * uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
//                            }
//                             success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
//                                 //请求成功
//                                 DDLogDebug(@"【SendPic】请求成功：%@", responseObject);
//
//                                 if(success)
//                                     success(responseObject);
//                             }
//                             failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
//                                 //请求失败
//                                 DDLogDebug(@"【SendPic】请求失败：%@", error);
//
//                                 if(failure)
//                                     failure(error);
//                             }
//     ];
}



//--------------------------------------------------------------------------
#pragma mark - 头像下载相关方法

+ (NSString *)getUserAvatarDownloadURL:(NSString *)userUid localCurrentCached:(NSString *)userLocalCachedAvatar
{
    return [AvatarHelper getUserAvatarDownloadURL:userUid localCurrentCached:userLocalCachedAvatar enforceDawnload:NO];
}

+ (NSString *)getUserAvatarDownloadURL:(NSString *)userUid
{
    return [AvatarHelper getUserAvatarDownloadURL:userUid localCurrentCached:nil enforceDawnload:YES];
}

+ (NSString *)getUserAvatarDownloadURL:(NSString *)userUid localCurrentCached:(NSString *)userLocalCachedAvatar enforceDawnload:(BOOL)enforceDawnload
{
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"];
    NSString *encodedUid = (userUid.length > 0) ? [userUid stringByAddingPercentEncodingWithAllowedCharacters:allowed] : @"";
    NSString *cachePart = @"";
    if (userLocalCachedAvatar.length > 0) {
        NSString *encodedFile = [userLocalCachedAvatar stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        cachePart = [NSString stringWithFormat:@"&user_local_cached_avatar=%@", encodedFile];
    }
    NSString *fileURL = [NSString stringWithFormat:@"%@?action=ad&user_uid=%@%@&enforceDawnload=%@"
                         , AVATAR_DOWNLOAD_CONTROLLER_URL_ROOT
                         , encodedUid
                         , cachePart
                         , (enforceDawnload?@"1":@"0")];
    return fileURL;
}



@end
