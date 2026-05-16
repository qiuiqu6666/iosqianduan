//
//  RBChromeNavigationBar.h
//  RainbowChat4i
//
//  可复用顶栏：背景 #EDEDED + 44pt 内容行（左返回、居中标题、右侧容器）。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, RBChromeNavigationBarBottomPinStyle) {
    /// 与 ChatRoot 一致：底边 = 宿主 safeAreaLayoutGuide.top + contentRowHeight（不依赖 additionalSafeAreaInsets）
    RBChromeNavigationBarBottomPinStyleBelowSystemSafeArea = 0,
    /// 宿主对根视图设置了 additionalSafeAreaInsets.top = contentRowHeight 时：底边对齐扩展后的 safeArea 顶（constant 0）
    RBChromeNavigationBarBottomPinStyleExtendedSafeAreaTop = 1,
};

@interface RBChromeNavigationBar : UIView

@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UIButton *backButton;
@property (nonatomic, readonly) UIButton *multiSelectCancelButton;
@property (nonatomic, readonly) UIView *leftAccessoryContainer;
@property (nonatomic, readonly) UIView *rightAccessoryContainer;
@property (nonatomic, readonly, nullable) UIView *backdropView;

/// 主 Tab 根页（无返回）：`rb_applyMainTabRootChromeStyle` 置 YES，转场结束后不强制显示返回键
@property (nonatomic, assign) BOOL rb_isMainTabRootChromeStyle;

/// 底部内容行高度，默认 44（与 UINavigationBar 内容区一致）
@property (nonatomic, assign) CGFloat contentRowHeight;

- (instancetype)initWithBottomPinStyle:(RBChromeNavigationBarBottomPinStyle)pinStyle NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;

/// 约束到 hostView 顶/左右到底边（由 pinStyle 决定相对 safeArea）；并 bringSubviewToFront
- (void)installInHostView:(UIView *)hostView;

/// 移除 back 上全部 target 后重新绑定
- (void)setBackButtonTarget:(nullable id)target action:(nullable SEL)action;

/// 聊天页顶栏：浅色磨砂底 + 白色半透明叠层（替代默认 #EDEDED 不透明白灰底）
- (void)rb_applyChatWhiteTranslucentBackdrop;

- (void)clearRightAccessorySubviews;
/// 与聊天 rb_attachViewToChatCustomNavRight 一致：固定宽高 + trailing + 垂直居中
- (void)attachRightAccessoryView:(UIView *)view;

- (void)attachCircularRightAccessoryView:(UIView *)container sideLength:(CGFloat)side trailingInsetFromRight:(CGFloat)trailingInset;

/// 多选：隐藏返回、显示「取消」
- (void)setMultiSelectModeVisualActive:(BOOL)active;

/// 主 Tab 根页：去掉左侧 44 槽占位、隐藏返回与多选取消，标题可居中
- (void)rb_applyMainTabRootChromeStyle;

@end

NS_ASSUME_NONNULL_END
