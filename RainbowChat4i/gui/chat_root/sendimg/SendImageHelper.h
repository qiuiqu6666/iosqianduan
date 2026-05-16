//telegram @wz662
#import <Foundation/Foundation.h>

@interface SendImageHelper : NSObject

/**
 * 组织返回要发送的图片文件名.
 *
 * @param uid
 * @param md5ForCachedAvatar
 * @return
 */
+ (NSString *)constructImageFileName:(NSString *)md5ForCachedAvatar;

/**
 * 返回存储发送图片的目录（结尾带反斜线）.
 *
 * @return 如果SDCard等正常则返回目标路径，否则返回null
 */
+ (NSString *)getSendPicSavedDirHasSlash;

/**
 * 返回存储发送图片的目录（结尾不带反斜线）.
 *
 * @return 如果SDCard等正常则返回目标路径，否则返回null
 */
+ (NSString *)getSendPicSavedDir;

/**
 * 获得下载指定图片消息的图片2进制数据的完整http地址.
 * <p>
 * 形如：“http://192.168.88.138:8080/BinaryDownloadController?
 * action=image_d&user_uid=400007&file_name=91c3e0d81b2039caa9c9899668b249e8.jpg”。
 *
 * @param file_name 要下载的图片文件名
 * @param needDump 是否需要转储：true表示需要转储，否则不需要. 转储是用于图片消息接收方在打开了该图片消息完整图后
 * 通知服务端将此图进行转储（转储的可能性有2种：直接删除掉、移到其它存储位置），转储的目的是防止大量用户的大量图片
 * 被读过后还存储在服务器上，加大了服务器的存储压力。<b>注意：</b><u>读取缩略图时无需转储！</u>
 * @return 完整的http文件下载地址
 */
+ (NSString *)getImageDownloadURL:(NSString *)file_name dump:(BOOL)needDump;

/**
 图片上传到服务器前的准备：将指定的图片压缩并重命名为图片消息需要图片文件规格。

 @param sourceImage 作为图片消息发送的源图
 @param usedForUploadProfilePhoto YES表示用于用户照片上传时，否则用于图片消息的图片文件上传
 @return 返回nil表示图片准备失败，否则表示压缩、重命名（用压缩后的文件的MD5码）后的文件名（形如“0bfde8889d9439365e63d7fa81549e35.jpg”）
 */
+ (NSString *)preparedImageForUpload:(UIImage *)sourceImage forPhoto:(BOOL)usedForUploadProfilePhoto;

/**
 * 图片上传开始：本地用户（图片消息发送方）的图片消息中图片数据的上传实现方法.
 * <p>
 * 本方法中用关图片上传处理的任何结果都将试图通知参数{@link result}, 因而如果
 * 需要针对图片数据上传结果进行客外处理的请<b>一定要实现{@link SendStatusSecondaryResult}类并作
 * 为参数传过来</b>.
 *
 * @param imageFileName 服务端收到文件数据后要保存的文件名，<b>此参数为必须！</b>
 * @param usedForUploadProfilePhoto YES表示用于用户照片上传时，否则用于图片消息的图片文件上传
 */
+ (void)processImageUpload:(NSString *)imageFileName forPhoto:(BOOL)usedForUploadProfilePhoto
                processing:(void (^)())processing processFaild:(void (^)())processFaild processOk:(void (^)())processOk;

@end
