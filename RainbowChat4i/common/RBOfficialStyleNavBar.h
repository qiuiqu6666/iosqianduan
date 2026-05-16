//
//  RBOfficialStyleNavBar.h
//  RainbowChat4i
//
//  可复用的「官方客服风格」导航栏：磨砂渐变到透明、液态/毛玻璃圆钮、中间胶囊标题。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RBOfficialStyleNavBar : UIView

/// 主标题（如用户名）
@property (nonatomic, copy) NSString *title;
/// 副标题（如「官方账号」），nil 则不显示副标题
@property (nonatomic, copy, nullable) NSString *subtitle;
/// 是否显示右侧按钮（默认 NO）
@property (nonatomic, assign) BOOL showRightButton;

/// 点击返回按钮回调
@property (nonatomic, copy, nullable) void (^onBackTap)(void);
/// 点击右侧按钮回调（仅当 showRightButton == YES 时有效）
@property (nonatomic, copy, nullable) void (^onRightTap)(void);

/// 导航内容区高度（用于 VC 计算 additionalSafeAreaInsets），默认 26
@property (nonatomic, assign, readonly) CGFloat contentHeight;

/// 设置整条导航栏高度（通常为 safeAreaInsets.top + contentHeight），由 VC 在 viewDidLayoutSubviews 中调用
- (void)setBarHeight:(CGFloat)height;

/// 根据滚动进度更新底部模糊渐变（0 = 已滚下去，1 = 顶到顶），由 VC 在 scrollViewDidScroll 中调用
- (void)updateBlurMaskForScrollProgress:(CGFloat)progress;

/// 恢复胶囊内标题/副标题字体（避免被 refreshFontsForView 覆盖），由 VC 在 viewDidAppear 中调用
- (void)restoreCapsuleFonts;

/// 添加到父视图并约束 top/leading/trailing；高度由 setBarHeight: 后续设置
- (void)addToView:(UIView *)containerView;

/// 将右侧按钮显示为头像（fileName/uid 为 nil 时恢复默认「更多」图标）
- (void)setRightButtonAvatarWithFileName:(nullable NSString *)fileName uid:(nullable NSString *)uid;
/// 将右侧按钮显示为指定图片（如群头像，image 为 nil 时恢复默认「更多」图标）
- (void)setRightButtonAvatarWithImage:(nullable UIImage *)image;

@end

NS_ASSUME_NONNULL_END
