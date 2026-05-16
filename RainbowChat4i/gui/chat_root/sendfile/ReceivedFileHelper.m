//telegram @wz662
#import "ReceivedFileHelper.h"
#import "IMClientManager.h"
#import "FileTool.h"

@implementation ReceivedFileHelper

// 返回存储收到的文件的目录（结尾带反斜线）
+ (NSString *)getReceivedFileSavedDirHasSlash
{
    NSString *dir = [ReceivedFileHelper getReceivedFileSavedDir];
    return dir ==  nil? nil : [NSString stringWithFormat:@"%@/", dir];
}

// 返回存储收到的文件的目录
+ (NSString *)getReceivedFileSavedDir
{
    NSString *dir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_FILE_RELATIVE_DIR];
    return dir;
}

// 获得大文件下载服务的完整http地址
+ (NSString *)getBigFileDownloadURL:(NSString *)fileMd5 skip:(long long)skipLength
{
    NSString *fileURL = nil;
    if( [[IMClientManager sharedInstance] localUserInfo] != nil)
    {
        fileURL = [NSString stringWithFormat:@"%@?user_uid=%@&file_md5=%@&skip_length=%lld"
                   , BIG_FILE_DOWNLOADER_CONTROLLER_URL_ROOT
                   , [[IMClientManager sharedInstance] localUserInfo].user_uid
                   , fileMd5, skipLength];
    }

    return fileURL;
}



@end
