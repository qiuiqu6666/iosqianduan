//telegram @wz662
/**
 * 收到文件消息的大文件实用工具类。
 *
 * @author JackJiang
 * @since 4.4
 */

#import <Foundation/Foundation.h>

@interface ReceivedFileHelper : NSObject

/**
 * 返回存储收到的文件的目录（结尾带反斜线）.
 *
 * @return 如果SDCard等正常则返回目标路径，否则返回null
 */
+ (NSString *)getReceivedFileSavedDirHasSlash;

/**
 * 返回存储收到的文件的目录.
 *
 * @return 如果SDCard等正常则返回目标路径，否则返回null
 */
+ (NSString *)getReceivedFileSavedDir;

/**
 * 获得大文件下载服务的完整http地址.
 * <p>
 * 形如：““http://192.168.1.195:8080/rainbowchat/BigFileDownloader?user_uid=400007
 * &file_md5=1aa7e1cc0405e3d5a52ae25d9eb6fbbb&skip_length=100”。
 *
 * @param fileMd5 要下载的文件md5码
 * @param skipLength 要跳过的字节数（在断点续传时，如果已经下载完成N字节，则本参数就可以设为
 *                   N——表示跳过已下载的N字节），如无需跳过则请设为0将重新下载整个文件。
 * @return 完整的http文件下载地址
 */
+ (NSString *)getBigFileDownloadURL:(NSString *)fileMd5 skip:(long long)skipLength;


@end
