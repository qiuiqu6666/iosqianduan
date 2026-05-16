//telegram @wz662
#import <UIKit/UIKit.h>

/// 主界面底部 Tab：iOS 26+ 使用 FabBar 自定义导航，否则使用系统 UITabBarController。
/// 对外统一提供与 UITabBarController 兼容的 viewControllers / selectedIndex / selectedViewController。
@interface MainTabsViewController : UIViewController <UITabBarControllerDelegate>
/// 各 Tab 对应的子 VC 数组（与 UITabBarController.viewControllers 语义一致）
@property (nonatomic, readonly) NSArray<__kindof UIViewController *> *viewControllers;
/// 当前选中的 Tab 下标
@property (nonatomic) NSUInteger selectedIndex;
/// 当前选中的子 VC（与 UITabBarController 的 selectedViewController 语义一致）
@property (nonatomic, readonly) UIViewController *selectedViewController;
@end
