//telegram @wz662
#import <Foundation/Foundation.h>

@interface AvatarHelper : NSObject

/**
 * 构造用户头像的图片文件名.
 *
 * @param uid
 * @param md5ForCachedAvatar
 * @return 返回形如“400069_43j4j3kjk3assdsdsdss.jpg”的头像保存文件名
 */
+ (NSString *)constructAvatarFileName:(NSString *)md5ForCachedAvatar uid:(NSString *)localUid;

/**
 * 返回存储头像图片的目录（结尾带反斜线）.
 *
 * @return 如果SDCard等正常则返回目标路径，否则返回null
 */
+ (NSString *)getUserAvatarSavedDirHasSlash;

/**
 * 返回存储头像图片的目录（结尾不带反斜线）.
 *
 * @return 如果SDCard等正常则返回目标路径，否则返回null
 */
+ (NSString *)getUserAvatarSavedDir;

/**
 头像上传前的准备：将指定的图片压缩并重命名为本人头像需要的图片文件规格等。

 @param sourceImage 作为本人头像的源图
 @return 返回nil表示图片准备失败，否则表示压缩、重命名（用压缩后的文件的MD5码）后的文件名（形如“400069_0bfde8889d9439365e63d7fa81549e35.jpg”）
 */
+ (NSString *)preparedAvatarForUpload:(UIImage *)sourceImage;

/**
 头像上传前的准备：GIF 动图直接复制并按 uid_md5.gif 命名，不转 JPG。
 @param gifFileURL 本地 GIF 文件 URL（如相册导出的临时文件）
 @return 返回 nil 表示准备失败，否则为最终文件名（形如 "400069_xxx.gif"）
 */
+ (NSString *)preparedAvatarForUploadGifAtURL:(NSURL *)gifFileURL;

/**
 头像上传前的准备：短视频（≤5s）直接复制并按 uid_md5.ext 命名，支持 .mp4/.mov/.webm。
 @param videoPath 本地视频文件路径（如相册导出后的沙盒路径）
 @return 返回 nil 表示准备失败，否则为最终文件名（形如 "400069_xxx.mp4"）
 */
+ (NSString *)preparedAvatarForUploadVideoAtPath:(NSString *)videoPath;

/**
 * 头像上传开始：图片数据的上传实现方法.
 *
 * @param imageFileName 服务端收到文件数据后要保存的文件名，<b>此参数为必须！</b>
 */
+ (void)processAvatarUpload:(NSString *)imageFileName
                processing:(void (^)())processing processFaild:(void (^)())processFaild processOk:(void (^)())processOk;


/**
 * 获得下载指定用户头像的URL（<b>服务端将根据用户本地缓存图片来
 * 智能判断是否要下载</b>（服务器的文件名称与本地一样当然就不需要下载了））.
 *
 * @param userUid 要下载头像的用户uid
 * @param userLocalCachedAvatar 缓存在本地的用户头像文件名称
 * @return
 */
+ (NSString *)getUserAvatarDownloadURL:(NSString *)userUid localCurrentCached:(NSString *)userLocalCachedAvatar;

/**
 * 获得<b>无条件（不管该用户有无本地头像缓存）</b>下载指定用户头像的URL.
 *
 * @param userUid 要下载头像的用户uid
 * @return
 */
+ (NSString *)getUserAvatarDownloadURL:(NSString *)userUid;

/**
 * 获得下载指定用户头像的完整http地址.
 * <p>
 * 形如：“http://192.168.88.138:8080/rainbowchat/UserAvatarDownloadController?
 * action=ad&user_uid=400007&user_local_cached_avatar=400007_91c3e0d81b2039caa9c9899668b249e8.jpg
 * &enforceDawnload=0”。
 *
 * @param userUid 要下载头像的用户uid
 * @param userLocalCachedAvatar 用户缓存在本地的头像文件名（本参数只在enforceDawnload==false时有意义）
 * @param enforceDawnload true表示无论客户端有无提交缓存图片名称本方法都将无条件返回该用户头像（如果头像确实存在的话），否则
 * 将据客户端提交上来的可能的本地缓存文件来判断是否需要下载用户头像（用户头像没有被更新过当然就不需要下载了！）
 * @return 完整的http文件下载地址
 */
+ (NSString *)getUserAvatarDownloadURL:(NSString *)userUid localCurrentCached:(NSString *)userLocalCachedAvatar enforceDawnload:(BOOL)enforceDawnload;

@end
