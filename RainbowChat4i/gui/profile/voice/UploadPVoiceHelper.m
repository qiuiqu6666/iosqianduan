//telegram @wz662
#import "UploadPVoiceHelper.h"
#import "IMClientManager.h"
#import "FileTool.h"

@implementation UploadPVoiceHelper

// 返回存储上传的个人语音的目录（结尾带反斜线）
+ (NSString *)getSendVoiceSavedDirHasSlash
{
    NSString *dir = [UploadPVoiceHelper getSendVoiceSavedDir];
    return dir ==  nil? nil : [NSString stringWithFormat:@"%@/", dir];
}

// 返回存储上传的个人语音的目录（结尾不带反斜线）
+ (NSString *)getSendVoiceSavedDir
{
    NSString *dir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_PVOICE_RELATIVE_DIR];
    return dir;
}

// 获得下载指定个人语音文件的2进制数据的完整http地址
+ (NSString *)getVoiceDownloadURL:(NSString *)file_name
{
    NSString *fileURL = nil;
    if( [[IMClientManager sharedInstance] localUserInfo] != nil)
    {
        fileURL = [NSString stringWithFormat:@"%@?action=pvoice_d&user_uid=%@&file_name=%@", BBONERAY_DOWNLOAD_CONTROLLER_URL_ROOT, [[IMClientManager sharedInstance] localUserInfo].user_uid, file_name];
    }

    DDLogDebug(@"[UploadPVoiceHelper] 拼接完成的个人语音文件下载地址是：%@", fileURL);

    return fileURL;
}

@end
