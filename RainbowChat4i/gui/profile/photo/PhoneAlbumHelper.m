//telegram @wz662
#import "PhoneAlbumHelper.h"
#import "Default.h"
#import "FileTool.h"

@implementation PhoneAlbumHelper

+ (NSString *)getPhoneAlbumSavedDir
{
    return [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_PHONE_ALBUM_RELATIVE_DIR];
}

+ (NSString *)getPhoneAlbumSavedDirHasSlash
{
    NSString *dir = [PhoneAlbumHelper getPhoneAlbumSavedDir];
    return dir == nil ? nil : [NSString stringWithFormat:@"%@/", dir];
}

+ (NSString *)phoneAlbumDownloadURLForOwnerUid:(NSString *)ownerUid fileName:(NSString *)fileName
{
    if (ownerUid.length == 0 || fileName.length == 0) {
        return nil;
    }
    NSCharacterSet *allowed = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSString *encName = [fileName stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    return [NSString stringWithFormat:@"%@?action=phone_album_d&owner_uid=%@&file_name=%@",
            BBONERAY_DOWNLOAD_CONTROLLER_URL_ROOT, ownerUid, encName ?: @""];
}

+ (NSString *)phoneAlbumUploadURLForUserUid:(NSString *)userUid
{
    if (userUid.length == 0) {
        return PHONE_ALBUM_UPLOAD_CONTROLLER_URL_ROOT;
    }
    return [NSString stringWithFormat:@"%@?user_uid=%@", PHONE_ALBUM_UPLOAD_CONTROLLER_URL_ROOT, userUid];
}

@end
