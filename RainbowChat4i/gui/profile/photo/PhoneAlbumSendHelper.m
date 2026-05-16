//telegram @wz662
#import "PhoneAlbumSendHelper.h"
#import "PhoneAlbumHelper.h"
#import "SendImageHelper.h"
#import "IMClientManager.h"
#import "ClientCoreSDK.h"
#import "BasicTool.h"
#import "AppDelegate.h"
#import "ToolKits.h"
#import "FileUploadHelper.h"
#import "FileTool.h"
#import "Default.h"

@implementation PhoneAlbumSendHelper

+ (NSString *)preparedPhoneAlbumImageForUpload:(UIImage *)sourceImage
{
    @try
    {
        NSString *savedDir = [PhoneAlbumHelper getPhoneAlbumSavedDir];
        NSString *compressFileTempName = [NSString stringWithFormat:@"%ld", [ToolKits getTimeStampWithMillisecond_l]];
        NSString *filePathAfterCompress = [BasicTool imageCompressForQualityAndWidth:sourceImage
                                                                       targetQuality:LOCAL_PHOTO_FILE_COMPRESS_QUALITY
                                                                         targetWidth:LOCAL_PHOTO_FILE_COMPRESS_MAX_WIDTH
                                                                           saveToDir:savedDir
                                                                           savedName:[SendImageHelper constructImageFileName:compressFileTempName]];
        DDLogDebug(@"【手机相册】图片压缩完成，路径：%@", filePathAfterCompress);
        if (filePathAfterCompress != nil)
        {
            NSString *md5ForFile = [FileTool getFileMD5WithPath:filePathAfterCompress];
            NSString *newFileNameWithMD5 = [SendImageHelper constructImageFileName:md5ForFile];
            NSString *renamePath = [NSString stringWithFormat:@"%@/%@", savedDir, newFileNameWithMD5];
            BOOL renameSucess = [FileTool renameFile:filePathAfterCompress toFilePath:renamePath];
            DDLogDebug(@"【手机相册】重命名 %@ 成功？%d", renamePath, renameSucess);
            return newFileNameWithMD5;
        }
        return nil;
    }
    @catch (NSException *exception)
    {
        DDLogError(@"【手机相册】准备图片异常：%@", exception);
        AlertError(@"很抱歉，图片处理失败，请稍后重试！");
        return nil;
    }
}

+ (void)processPhoneAlbumImageUpload:(NSString *)imageFileName
                          processing:(void (^)(void))processing
                        processFaild:(void (^)(void))processFaild
                           processOk:(void (^)(void))processOk
{
    if (processing != nil) {
        processing();
    }
    if (imageFileName == nil)
    {
        DDLogWarn(@"【手机相册】文件名为空");
        if (processFaild != nil) {
            processFaild();
        }
        return;
    }
    NSString *fp = [NSString stringWithFormat:@"%@%@", [PhoneAlbumHelper getPhoneAlbumSavedDirHasSlash], imageFileName];
    long long fileSize = [FileTool fileSizeAtPath:fp];
    if (fileSize <= 0)
    {
        [APP showToastWarn:@"上传的照片文件大小为0，上传失败！"];
        if (processFaild != nil) {
            processFaild();
        }
        return;
    }
    if (fileSize > LOCAL_PHOTO_FILE_DATA_MAX_LENGTH)
    {
        [APP showToastWarn:@"上传的图片过大，上传失败！"];
        if (processFaild != nil) {
            processFaild();
        }
        return;
    }
    NSString *uid = [ClientCoreSDK sharedInstance].currentLoginUserId;
    NSString *urlString = [PhoneAlbumHelper phoneAlbumUploadURLForUserUid:uid];
    NSMutableDictionary *parameter = [NSMutableDictionary dictionary];
    parameter[@"user_uid"] = uid;
    parameter[@"file_name"] = imageFileName;
    if ([IMClientManager sharedInstance].localUserInfo.token.length > 0) {
        parameter[@"token"] = [IMClientManager sharedInstance].localUserInfo.token;
    }
    [FileUploadHelper uploadFileImpl:fp
                            withName:imageFileName
                              andUrl:urlString
                       andParameters:parameter
                            progress:^(NSProgress * _Nonnull uploadProgress) {
                                DDLogDebug(@"【手机相册】上传进度> %lf", 1.0 * uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
                            }
                             success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                                 DDLogDebug(@"【手机相册】上传成功：%@", responseObject);
                                 if (processOk != nil) {
                                     processOk();
                                 }
                             }
                             failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                 DDLogDebug(@"【手机相册】上传失败：%@", error);
                                 if (processFaild != nil) {
                                     processFaild();
                                 }
                             }];
}

@end
