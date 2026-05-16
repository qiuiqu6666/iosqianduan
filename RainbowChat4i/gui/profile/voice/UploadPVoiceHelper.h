//telegram @wz662
#import <Foundation/Foundation.h>

@interface UploadPVoiceHelper : NSObject

/**
 * 返回存储上传的个人语音的目录（结尾带反斜线）.
 *
 * @return 返回沙箱存储路径
 */
+ (NSString *)getSendVoiceSavedDirHasSlash;

/**
 * 返回存储上传的个人语音的目录（结尾不带反斜线）.
 *
 * @return 返回沙箱存储路径
 */
+ (NSString *)getSendVoiceSavedDir;

/**
 * 获得下载指定个人语音文件的2进制数据的完整http地址.
 * <p>
 * 形如：“http://192.168.88.138:8080/BinaryDownloadController?
 * action=pvoice_d&user_uid=400007&file_name=91c3e0d81b2039caa9c9899668b249e8.jpg”。
 *
 * @param file_name 要下载的照片文件名
 * @return 完整的http文件下载地址
 */
+ (NSString *)getVoiceDownloadURL:(NSString *)file_name;

@end
