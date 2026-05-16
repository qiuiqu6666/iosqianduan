// 全屏预览用户头像：图片用大图查看，视频用 RBAvatarView 播放
#import <UIKit/UIKit.h>

@interface RBAvatarPreviewViewController : UIViewController
- (instancetype)initWithUid:(NSString *)uid avatarFileName:(NSString *)fileName;
@end
