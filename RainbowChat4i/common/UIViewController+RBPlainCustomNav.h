//
//  UIViewController+RBPlainCustomNav.h
//  子页「白底标题 + 返回」顶栏：复用 RBChromeNavigationBar，与设置页风格一致。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class RBChromeNavigationBar;

@interface UIViewController (RBPlainCustomNav)

- (void)rb_installPlainCustomNavigationBarWithTitle:(NSString *)title;

/// 可选右侧图标（如语音列表「添加」）；image/target/action 任一无效则不显示右侧
- (void)rb_installPlainCustomNavigationBarWithTitle:(NSString *)title
                                  rightButtonImage:(nullable UIImage *)image
                                            target:(nullable id)target
                                            action:(nullable SEL)action;

/// 主 Tab 根页：居中标题、无返回、左侧不占位；`rightAccessoryView` 为 nil 则无右侧控件
- (void)rb_installPlainCustomNavigationBarForMainTabRootWithLocalizedTitleKey:(NSString *)key
                                                           rightAccessoryView:(nullable UIView *)rightAccessoryView;

- (void)rb_plainCustomNavHostViewWillAppear:(BOOL)animated;
- (void)rb_plainCustomNavHostViewDidAppear:(BOOL)animated;
- (void)rb_plainCustomNavHostViewWillDisappear:(BOOL)animated;
/// 在 viewDidDisappear: 中调用：仅在真正 pop 出栈时清零 additionalSafeAreaInsets，避免 push 子页时列表与安全区抖动
- (void)rb_plainCustomNavHostViewDidDisappear:(BOOL)animated;

/// 标题字号/颜色；安装顶栏时已应用，且 `rb_plainCustomNavHostViewDidAppear` 内会再应用一次（避免 push 转场中与幽灵标题叠代导致抖动）。动态改字号时可再调。
- (void)rb_plainCustomNavUpdateTitleFont;

/// 若已安装 PlainCustomNav 的 RBChromeNavigationBar 则返回，否则 nil（供导航转场标题动画解析）
- (nullable RBChromeNavigationBar *)rb_plainChromeNavigationBarIfInstalled;

/// 已弃用：双返回箭头改由 `rb_plainCustomNavHostViewWillAppear:` / `WillDisappear:` 内根据转场 from/to 自动处理（仅藏转出页的箭头）。
/// 若个别页面仍需单独压制，可继续调用。
- (void)rb_plainCustomNavSetBackHiddenDuringNavigationTransitionIfAnimated;

@end

NS_ASSUME_NONNULL_END
