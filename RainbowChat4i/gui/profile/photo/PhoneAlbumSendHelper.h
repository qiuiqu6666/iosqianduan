//telegram @wz662
#import <UIKit/UIKit.h>

@interface PhoneAlbumSendHelper : NSObject

+ (NSString *)preparedPhoneAlbumImageForUpload:(UIImage *)sourceImage;

+ (void)processPhoneAlbumImageUpload:(NSString *)imageFileName
                          processing:(void (^)(void))processing
                        processFaild:(void (^)(void))processFaild
                           processOk:(void (^)(void))processOk;

@end
