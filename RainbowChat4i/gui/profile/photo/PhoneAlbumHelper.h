//telegram @wz662
#import <Foundation/Foundation.h>

@interface PhoneAlbumHelper : NSObject

+ (NSString *)getPhoneAlbumSavedDir;
+ (NSString *)getPhoneAlbumSavedDirHasSlash;

/** 手机相册原图/缩略图下载 URL（BinaryDownloader?action=phone_album_d） */
+ (NSString *)phoneAlbumDownloadURLForOwnerUid:(NSString *)ownerUid fileName:(NSString *)fileName;

/** 上传地址：PhoneAlbumUploader?user_uid=... */
+ (NSString *)phoneAlbumUploadURLForUserUid:(NSString *)userUid;

@end
