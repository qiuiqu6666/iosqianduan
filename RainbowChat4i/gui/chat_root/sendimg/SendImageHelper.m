//telegram @wz662
#import "SendImageHelper.h"
#import "IMClientManager.h"
#import "ClientCoreSDK.h"
#import "BasicTool.h"
#import "AppDelegate.h"
#import "ToolKits.h"
#import "FileUploadHelper.h"
#import "UploadPhotoHelper.h"
#import "FileTool.h"

@implementation SendImageHelper

+ (NSString *)constructImageFileName:(NSString *)md5ForCachedAvatar
{
    if(md5ForCachedAvatar == nil)
    {
        DDLogWarn(@"[SendImageHelper] 无效的参数：md5ForImage == null!");
        return nil;
    }
    return [NSString stringWithFormat:@"%@.jpg", md5ForCachedAvatar ];
}

+ (NSString *)getSendPicSavedDirHasSlash
{
    NSString *dir = [SendImageHelper getSendPicSavedDir];
    return dir ==  nil? nil : [NSString stringWithFormat:@"%@/", dir];
}

+ (NSString *)getSendPicSavedDir
{
    NSString *dir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_SENDPIC_RELATIVE_DIR];
    return dir;
}

+ (NSString *)getImageDownloadURL:(NSString *)file_name dump:(BOOL)needDump
{
//    NSLog(@"[ClientCoreSDK sharedInstance].currentLoginExtra=%@", [ClientCoreSDK sharedInstance].currentLoginExtra);

    NSString *fileURL = nil;
    if( [[IMClientManager sharedInstance] localUserInfo] != nil)
//    if( [ClientCoreSDK sharedInstance].currentLoginUserId != nil)
    {
       fileURL = [NSString stringWithFormat:@"%@?action=image_d&user_uid=%@&file_name=%@&need_dump=%@"
                  , BBONERAY_DOWNLOAD_CONTROLLER_URL_ROOT
//                  , [ClientCoreSDK sharedInstance].currentLoginUserId
                  , [[IMClientManager sharedInstance] localUserInfo].user_uid
                  , file_name, (needDump?@"1":@"0")];
    }

    return fileURL;
}

+ (NSString *)preparedImageForUpload:(UIImage *)sourceImage forPhoto:(BOOL)usedForUploadProfilePhoto
{
    @try
    {
        NSString *savedDir = usedForUploadProfilePhoto?[UploadPhotoHelper getSendPhotoSavedDir]:[SendImageHelper getSendPicSavedDir];

        //** 先压缩图片（缩小尺寸、压缩质量）
        // 压缩后的文件名用一个以时间戳命名的临时文件名（因为稍后会被正式重命名为MD5码文件
        // 名，现在的名只是临时的，且为了防止多线程出现临时文件名碰撞的可能，所以用了时间戳）
        NSString *compressFileTempName = [NSString stringWithFormat:@"%ld",[ToolKits getTimeStampWithMillisecond_l]];
        NSString *filePathAfterCompress = [BasicTool imageCompressForQualityAndWidth:sourceImage
                                                                       targetQuality:usedForUploadProfilePhoto?LOCAL_PHOTO_FILE_COMPRESS_QUALITY:LOCAL_IMAGE_FILE_COMPRESS_QUALITY
                                                                         targetWidth:usedForUploadProfilePhoto?LOCAL_IMAGE_FILE_COMPRESS_MAX_WIDTH:LOCAL_PHOTO_FILE_COMPRESS_MAX_WIDTH
                                                                           saveToDir:savedDir
                                                                           savedName:[SendImageHelper constructImageFileName:compressFileTempName]];
        DDLogDebug(@"【图片消息的图片文件准备%@】图片压缩完成，压缩后保存的路径为：%@", usedForUploadProfilePhoto?@"-照片":@"", filePathAfterCompress);

        //** 再用MD5码重命名该图片文件
        // 图片压缩成功
        if(filePathAfterCompress != nil)
        {
            //** 再获取该文件的MD5码文件名
            NSString *md5ForFile = [FileTool getFileMD5WithPath:filePathAfterCompress];
            NSString *newFileNameWithMD5 = [SendImageHelper constructImageFileName:md5ForFile];
            DDLogDebug(@"【图片消息的图片文件准备%@】已计算出压缩后的新图片文件MD5码文件名：%@", usedForUploadProfilePhoto?@"-照片":@"", newFileNameWithMD5);

            //** 再重命名文件为MD5码的形式
            NSString *renamePath = [NSString stringWithFormat:@"%@/%@", savedDir, newFileNameWithMD5];
            BOOL renameSucess = [FileTool renameFile:filePathAfterCompress toFilePath:renamePath];
            DDLogDebug(@"【图片消息的图片文件准备%@】压缩后的图片文件重命名为%@ 是否成功？%d", usedForUploadProfilePhoto?@"-照片":@"", renamePath, renameSucess);
            
            return newFileNameWithMD5;
        }
        else
        {
            return nil;
        }
    }
    @catch (NSException *exception)
    {
        DDLogError(@"【图片消息的图片文件准备%@】过程中发生了异常，Exception: %@", usedForUploadProfilePhoto?@"-照片":@"", exception);
        AlertError(@"很抱歉，图片处理失败，请稍后重试！");
        return nil;
    }
}

+ (void)processImageUpload:(NSString *)imageFileName forPhoto:(BOOL)usedForUploadProfilePhoto
                processing:(void (^)())processing processFaild:(void (^)())processFaild processOk:(void (^)())processOk
{
    // 将处理结果通知观察者
    if(processing != nil)
        processing();

    if(imageFileName == nil)
    {
        DDLogWarn(@"【SendPic%@】要上传的图片文件名居然是null!", usedForUploadProfilePhoto?@"-照片":@"");
        // 将处理结果通知观察者
        if(processFaild != nil)
            processFaild();
        return;
    }

    @try
    {
        NSString *fp = usedForUploadProfilePhoto?[NSString stringWithFormat:@"%@%@", [UploadPhotoHelper getSendPhotoSavedDirHasSlash], imageFileName]:[NSString stringWithFormat:@"%@%@", [SendImageHelper getSendPicSavedDirHasSlash], imageFileName];

        long long fileSize = [FileTool fileSizeAtPath:fp];

        // 为了app的健壮性，优先检查要上传的图片文件大小是否超限
        if(fileSize <= 0)
        {
            DDLogWarn(@"【SendPic%@】图片大小为0，本次图片上传没有继续！", usedForUploadProfilePhoto?@"-照片":@"");
            [APP showToastWarn:usedForUploadProfilePhoto?@"上传的照片文件大小为0，上传失败！":@"发送的图片文件大小为0，发送失败！"];

            // 将处理结果通知观察者
            if(processFaild != nil)
                processFaild();

            return;
        }
        else if(fileSize > (usedForUploadProfilePhoto?LOCAL_PHOTO_FILE_DATA_MAX_LENGTH:LOCAL_IMAGE_FILE_DATA_MAX_LENGTH) )
        {
            DDLogWarn(@"【SendPic%@】图片大小大于%d字节，上传（到服务端）没有继续！", usedForUploadProfilePhoto?@"-照片":@"", (usedForUploadProfilePhoto?LOCAL_PHOTO_FILE_DATA_MAX_LENGTH:LOCAL_IMAGE_FILE_DATA_MAX_LENGTH) );
            [APP showToastWarn:usedForUploadProfilePhoto?@"上传的图片过大，上传失败！":@"发送的图片过大，发送失败！"];

            // 将处理结果通知观察者
            if(processFaild != nil)
                processFaild();

            return;
        }
        else
        {
            NSString *localUid = [ClientCoreSDK sharedInstance].currentLoginUserId;
            // 正式开始文件上传
            [SendImageHelper uploadMsgImageFile:imageFileName localUid:localUid usedFor:usedForUploadProfilePhoto completeFail:^(NSError *error) {
                // 将处理结果通知观察者
                if(processFaild != nil)
                    processFaild();
            } completeSucess:^(id responseObject) {
                // 将处理结果通知观察者
                if(processOk != nil)
                    processOk();
            }];
        }
    }
    @catch (NSException * e)
    {
        DDLogError(@"【SendPic%@】Exception: %@", usedForUploadProfilePhoto?@"-照片":@"", e);
        return;
    }
}

/**
 * 通过HTTP上传图片消息的图片文件的实现方法.
 *
 * @param fileName 服务端收到文件数据后要保存的文件名
 * @param localUserUid 上传者的uid（上传者也即是图片消息的发起人）
 * @param usedForUploadProfilePhoto YES表示用于用户照片上传时，否则用于图片消息的图片文件上传
 */
+ (void)uploadMsgImageFile:(NSString *)fileName localUid:(NSString *)localUserUid usedFor:(BOOL)usedForUploadProfilePhoto completeFail:(void (^)(NSError *error))failure completeSucess:(void (^)(id responseObject))success
{
    NSString *uid = localUserUid;

    // 原始文件路径
    NSString *fileFullPath = usedForUploadProfilePhoto?[NSString stringWithFormat:@"%@%@", [UploadPhotoHelper getSendPhotoSavedDirHasSlash], fileName]:[NSString stringWithFormat:@"%@%@", [SendImageHelper getSendPicSavedDirHasSlash], fileName];
    DDLogDebug(@"【SendPic%@】>>>>>>>>>>>>>> fileFullPath=%@", usedForUploadProfilePhoto?@"-照片":@"", fileFullPath);

    // ** 注意：经反复测试，此url一定不能带参数，不然总是在上传时卡住（原因不清楚，可能是AF3的bug！）
    NSString *urlString = usedForUploadProfilePhoto?MY_PHOTO_UPLOAD_CONTROLLER_URL_ROOT:MSG_IMG_UPLODER_URL_ROOT;

    // 额外参数
    // NSDictionary *dict = @{@"user_uid":@"1234"};
    NSMutableDictionary *parameter = [NSMutableDictionary dictionary];
    parameter[@"user_uid"] = uid;
    parameter[@"file_name"] = fileName;
    // 通过 Authorization header 传递 token（由 FileUploadHelper 中 setupAuthorization 设置）

    [FileUploadHelper uploadFileImpl:fileFullPath
                      withName:fileName
                        andUrl:urlString
                 andParameters:parameter
                      progress:^(NSProgress * _Nonnull uploadProgress) {
                          //打印下上传进度
                          DDLogDebug(@"【SendPic%@】上传进度> %lf", usedForUploadProfilePhoto?@"-照片":@"", 1.0 * uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
                      }
                       success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                           //请求成功
                           DDLogDebug(@"【SendPic%@】请求成功：%@", usedForUploadProfilePhoto?@"-照片":@"", responseObject);

                           if(success)
                               success(responseObject);
                       }
                       failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                           //请求失败
                           DDLogDebug(@"【SendPic%@】请求失败：%@", usedForUploadProfilePhoto?@"-照片":@"", error);

                           if(failure)
                               failure(error);
                       }
     ];
}


@end
