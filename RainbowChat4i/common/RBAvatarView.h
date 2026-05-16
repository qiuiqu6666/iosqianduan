//telegram @wz662
// 支持静态图 / GIF / 短视频的头像视图：图片用 UIImageView 显示，视频用 AVPlayer 循环静音播放。
#import <UIKit/UIKit.h>

@interface RBAvatarView : UIView
/** 占位图（无头像或加载前显示） */
@property (nonatomic, strong) UIImage *placeholderImage;
/** 圆角，默认 0 */
@property (nonatomic, assign) CGFloat cornerRadius;

/**
 设置头像：根据 fileName 扩展名自动判断为图片或视频，图片/GIF 走 SD 缓存展示，视频则用 AVPlayer 循环静音播放。
 @param fileName 服务端头像文件名（如 xxx.jpg / xxx.gif / xxx.mp4），nil 时只显示占位图并停止视频
 @param uid 用户 uid，用于拼下载 URL
 */
- (void)setAvatarWithFileName:(NSString *)fileName uid:(NSString *)uid;

/**
 在已有的 UIImageView 上显示/播放头像（图片或视频）。内部会挂一个 RBAvatarView 作为子视图并复用。
 适用于列表 cell、详情页等不想改 xib 的场景；二维码等仅需静态图的场景请继续用 loadUserAvatarWithFileName。
 @param fileName 服务端头像文件名，nil 时显示占位图
 @param uid 用户 uid
 @param imageView 用于展示头像的 imageView（会在此 view 上添加 RBAvatarView）
 @param placeholder 占位图，可为 nil
 */
+ (void)setAvatarWithFileName:(NSString *)fileName uid:(NSString *)uid onImageView:(UIImageView *)imageView placeholder:(UIImage *)placeholder;

/**
 同上，增加 staticPreviewOnly：为 YES 时动态头像只显示静态首帧，不播放视频（用于消息对话列表等场景）。
 */
+ (void)setAvatarWithFileName:(NSString *)fileName uid:(NSString *)uid onImageView:(UIImageView *)imageView placeholder:(UIImage *)placeholder staticPreviewOnly:(BOOL)staticPreviewOnly;

/** 暂停挂在该 imageView 上的视频头像播放（列表 cell 不可见时调用，避免离屏仍播放导致卡顿） */
+ (void)pauseVideoForAvatarInImageView:(UIImageView *)imageView;
/** 恢复挂在该 imageView 上的视频头像播放（列表 cell 即将可见时调用） */
+ (void)resumeVideoForAvatarInImageView:(UIImageView *)imageView;

/** 从 imageView 上移除挂载的 RBAvatarView 子视图并清除关联（用于单聊等场景下改用缓存的静态头像图，避免重复加载） */
+ (void)removeAvatarFromImageView:(UIImageView *)imageView;
@end
