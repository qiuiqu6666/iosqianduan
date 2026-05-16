//telegram @wz662
#import "UploadPhotoHelper.h"
#import "IMClientManager.h"
#import "FileTool.h"

@implementation UploadPhotoHelper

+ (NSString *)getSendPhotoSavedDirHasSlash
{
    NSString *dir = [UploadPhotoHelper getSendPhotoSavedDir];
    return dir ==  nil? nil : [NSString stringWithFormat:@"%@/", dir];
}

+ (NSString *)getSendPhotoSavedDir
{
    NSString *dir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_PHOTO_RELATIVE_DIR];
    return dir;
}

+ (NSString *)getPhotoDownloadURL:(NSString *)file_name
{
    NSString *fileURL = nil;
    if( [[IMClientManager sharedInstance] localUserInfo] != nil)
    {
        fileURL = [NSString stringWithFormat:@"%@?action=photo_d&user_uid=%@&file_name=%@", BBONERAY_DOWNLOAD_CONTROLLER_URL_ROOT, [[IMClientManager sharedInstance] localUserInfo].user_uid, file_name];
    }

    DDLogDebug(@"[SendPhotoHelper] 拼接完成的个人相册图片下载地址是：%@", fileURL);

    return fileURL;
}

@end
