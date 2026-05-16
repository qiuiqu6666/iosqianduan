//telegram @wz662
#import <Foundation/Foundation.h>

@interface FileDownloadHelper : NSObject

/** 是否为短视频头像文件名（.mp4 / .mov / .webm） */
+ (BOOL)isVideoAvatarFileName:(NSString *)fileName;

/** 短视频头像本地缓存路径（若文件存在则可直接用 fileURL 播放，无需显示首帧） */
+ (NSString *)avatarVideoCachePathForUid:(NSString *)uid fileName:(NSString *)fileName;
/** 下载短视频头像到本地缓存，完成后回调本地 fileURL（主线程） */
+ (void)downloadAvatarVideoWithUid:(NSString *)uid fileName:(NSString *)fileName complete:(void (^)(BOOL success, NSURL * _Nullable localFileURL))complete;
/** 加载短视频头像首帧作为预览图（下载视频并取首帧，缓存为图片；用于未加载时显示预览图而非占位图） */
+ (void)loadUserAvatarVideoFirstFrameWithURL:(NSString *)fileDownloadPath logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete;

/**
 读取用户头像的本地缓存（从sd卡或内存中，但一定不从网络）。

 @param avatarFileDownloadPath 缓存时的url，此url就是SDImageCache缓存时的key，因为用户头从网络加载时就是以此为key的
 @param donot YES表示当内存中不存在缓存时不尝试从SD卡读取直接从网络加载，否则将按正常逻辑尝试从sd卡加载，一般情况下请用NO
 @return 头像图片缓存，为nil表示没有读取到缓存
 */
+ (UIImage *)getUserAvatarFromSDImageCache:(NSString *)avatarFileDownloadPath donotLoadFromDisk:(BOOL)donot;

/** 异步从缓存取头像（磁盘解码在后台队列，completion 在主线程回调，用于 cell 等避免主线程卡顿 P0-1） */
+ (void)getUserAvatarFromCacheAsync:(NSString *)avatarFileDownloadPath donotLoadFromDisk:(BOOL)donot completion:(void (^)(UIImage * _Nullable))completion;

/**
 获取用户头像图片下载完整URL地址。

 @param useAvatarFileName YES表示使用头像文件名的方式拼结成网络下载url，否则只使用uid方式
 @param fileNameForAvatar 本参数只在useAvatarFileName==YES时有意义，否则请用nil。要加载的用户头像存放于服务端的文
    件名（根据RainbowChar的设计，用户的头像文件名是他的头像头片文件计算出的MD5码组成的文件名，也就意味着如果用户更改了头像，则
    这个文件名也就变了，换句话说通过这个头像文件名也就能判定当前所缓存在本地的头像是否是最新的了——比对一下文件名就知道了）。
 @param uidForAvatar 要加载头像的用户uid
 @return 用户头像图片下载完整URL地址
 */
+ (NSString *)getUserAvatarDownloadURLExt:(BOOL)useAvatarFileName fileName:(NSString *)fileNameForAvatar uid:(NSString *)uidForAvatar;

/**
 本方法将智能判断，从而决定是用头像文件名还是uid加载用户头像图片（头像文件名是头像图片的md5组成的，优先用文件名加载，则有利于在用户更改头像时及时更新显示）。
 
 @param fileNameForAvatar 要加载的用户头像存放于服务端的文件名（根据RainbowChar的设计，用户的头像文件名是他的头像头片文件计算出的MD5码组成的文件名，
 也就意味着如果用户更改了头像，则这个文件名也就变了，换句话说通过这个头像文件名也就能判定当前所缓存在本地的头像是否是最新的了——比对一下文件名就知道了）
 @param uid 要加载头像的用户uid
 @param tag 日志tag
 @param complete 完成后的回调block
 @param donot YES表示当内存中不存在缓存时不尝试从SD卡读取直接从网络加载，否则将按正常逻辑尝试从sd卡加载，一般情况下请用NO
 @see loadUserAvatarWithFileName:
 @see loadUserAvatarWithUID:
 */
+ (void)loadUserAvatarIntelligent:(NSString *)fileNameForAvatar uid:(NSString *)uid logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete donotLoadFromDisk:(BOOL)donot;

/**
 使用用户最新头像文件名的方式载入用户头像（如果找到本地缓存则直接用缓存显示，否则自动从网络加载）。

 【使用用户UID和用户头像文件名的方式加载的区别：简单地说就是本地缓存时是否加上了文件名作为key的一部分】
 因为使用了SDImageCache缓存，而使用UID的方式只能判定该UID是否存在本地缓存（而该缓存头像是不是最新的就没法知道了）。而直接使用用户头像文件名的方式
 就不同，因为用户头像存放于服务端的文件名是按照头像图片MD5码的形式组织，所以只要能取到用户的最新数据，也就能取到最新的头像文件名（这个文件名是变动的，
 保存的是当前该用户的最新头像文件名），那么通过此文件名也就自然能取到最新头像了（而用像UID那样受缓存影响了）。

 【那为何还有使用UID的方式加载头像？】
 因为有些场景下并不是随时都能拿到用户最新头像文件名的，比如首页提醒“消息”界面中，有些消息的元数据就没有带着或取到用户头像文件名，所以只能用uid，至少能保证
 可以取到头像，但会不会受缓存影响也是有限的，必竟用户一旦进了其它界面就会自动刷新。

 @param fileNameForAvatar 要加载的用户头像存放于服务端的文件名（根据RainbowChar的设计，用户的头像文件名是他的头像头片文件计算出的MD5码组成的文件名，
 也就意味着如果用户更改了头像，则这个文件名也就变了，换句话说通过这个头像文件名也就能判定当前所缓存在本地的头像是否是最新的了——比对一下文件名就知道了）
 @param uid 要加载头像的用户uid
 @param tag 日志tag
 @param complete 完成后的回调block
 */
+ (void)loadUserAvatarWithFileName:(NSString *)fileNameForAvatar  uid:(NSString *)uid logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete;

/**
 使用用户UID的方式载入用户头像（如果找到本地缓存则直接用缓存显示，否则自动从网络加载）。

 【使用用户UID和用户头像文件名的方式加载的区别：简单地说就是本地缓存时是否加上了文件名作为key的一部分】
 因为使用了SDImageCache缓存，而使用UID的方式只能判定该UID是否存在本地缓存（而该缓存头像是不是最新的就没法知道了）。而直接使用用户头像文件名的方式
 就不同，因为用户头像存放于服务端的文件名是按照头像图片MD5码的形式组织，所以只要能取到用户的最新数据，也就能取到最新的头像文件名（这个文件名是变动的，
 保存的是当前该用户的最新头像文件名），那么通过此文件名也就自然能取到最新头像了（而不用像UID那样受缓存影响了）。

 【那为何还有使用UID的方式加载头像？】
 因为有些场景下并不是随时都能拿到用户最新头像文件名的，比如首页提醒“消息”界面中，有些消息的元数据就没有带着或取到用户头像文件名，所以只能用uid，至少能保证
 可以取到头像，但会不会受缓存影响也是有限的，必竟用户一旦进了其它界面就会自动刷新。

 @param uidForAvatar 要加载头像的用户uid
 @param tag 日志tag
 @param complete 完成后的回调block
 @param donot YES表示当内存中不存在缓存时不尝试从SD卡读取直接从网络加载，否则将按正常逻辑尝试从sd卡加载，一般情况下请用NO
 */
+ (void)loadUserAvatarWithUID:(NSString *)uidForAvatar logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete donotLoadFromDisk:(BOOL)donot;

/**
 加载用户头像图片（仅从本地缓存）。
  
 @param fileDownloadPath 头像加载url
 @param donot YES表示当内存中不存在缓存时不尝试从SD卡读取直接从网络加载，否则将按正常逻辑尝试从sd卡加载，一般情况下请用NO
 */
+ (UIImage *)loadUserAvatarFromCacheOnly:(NSString *)fileDownloadPath donotLoadFromDisk:(BOOL)donot;

/**
 加载用户头像图片（强制从网络服务器）。
  
 @param fileDownloadPath 头像加载url
 @param tag 日志tag
 @param complete 完成后的回调block
 */
+ (void)loadUserAvatarFromInternetOnly:(NSString *)fileDownloadPath logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete;

/**
 载入用户照片（如果找到本地缓存则直接用缓存显示，否则自动从网络加载）。

 @param photoFileName 要加载的照片文件名
 @param tag 日志tag
 @param complete 完成后的回调block
 */
+ (void)loadUserPhoto:(NSString *)photoFileName logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete;

/**
 载入手机相册图片（BinaryDownloader?action=phone_album_d），缓存键为完整 URL。
 */
+ (void)loadPhoneAlbumPhoto:(NSString *)photoFileName ownerUid:(NSString *)ownerUid logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete;

/**
 清空指定群组头像的缓存
 @param gid 要清除群组头像的群id
 */
+ (void)clearGroupAvatarCache:(NSString *)gid;

/**
 载入群组头像（如果内存缓存中存在则直接用缓存显示，否则自动从网络加载）。

 @param gid 要加载的群组id
 @param tag 日志tag
 @param complete 完成后的回调block
 */
+ (void)loadGroupAvatar:(NSString *)gid logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete;

/**
载入聊天界面上图片消息的图片文件（如果内存缓存中存在则直接用缓存显示，否则自动从网络加载）。

@param fileDownloadPath 图片文件下载url
@param tag 日志tag
@param complete 完成后的回调block
*/
+ (void)loadChattingImgWithURL:(NSString *)fileDownloadPath logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete;

/**
载入聊天界面上短p视频消息的预览图片文件（如果内存缓存中存在则直接用缓存显示，否则自动从网络加载）。

@param fileDownloadPath 图片文件下载url
@param tag 日志tag
@param complete 完成后的回调block
*/
+ (void)loadChattingShortVideoPreviewImgWithURL:(NSString *)fileDownloadPath logTag:(NSString *)tag complete:(void (^)(BOOL sucess, UIImage *img))complete;

/**
 通用文件下载实用方法。

 @param fileURL 要下载的完整文件http url
 @param saveDir 要保存到的本地沙箱目录（注意：此参数不需要带"/"结尾哦！）
 @param fileName 指定的文件名（如果为nil，则使用服务器返回的文件名）
 @param downloadProgressBlock 下载进度block
 @param complete 下载完成后的回调
 */
+ (NSURLSessionDownloadTask *)downloadCommonFile:(NSString *)fileURL toDir:(NSString *)saveDir fileName:(NSString *)fileName pg:(void (^)(NSProgress *dp))downloadProgressBlock complete:(void (^)(BOOL sucess, NSURL *fileSavedPath))complete;

/**
 通用文件下载实用方法（兼容旧版本，使用服务器返回的文件名）。

 @param fileURL 要下载的完整文件http url
 @param saveDir 要保存到的本地沙箱目录（注意：此参数不需要带"/"结尾哦！）
 @param downloadProgressBlock 下载进度block
 @param complete 下载完成后的回调
 */
+ (NSURLSessionDownloadTask *)downloadCommonFile:(NSString *)fileURL toDir:(NSString *)saveDir pg:(void (^)(NSProgress *dp))downloadProgressBlock complete:(void (^)(BOOL sucess, NSURL *fileSavedPath))complete;

@end
