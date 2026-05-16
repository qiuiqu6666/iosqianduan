//telegram @wz662
#import <UIKit/UIKit.h>

@interface NavigationController : UINavigationController <UINavigationControllerDelegate, UIGestureRecognizerDelegate>

/// 转场即将开始时的回调（与左右平移同步显隐底部导航用）。参数：当前 nav、即将展示的 VC、是否带动画。
@property (nonatomic, copy) void (^onWillShowViewController)(UINavigationController *nav, UIViewController *viewController, BOOL animated);
/// 每次栈顶 VC 展示后回调（push/pop 动画结束），用于主界面同步自定义底部导航显隐（iOS 26 FabBar）。参数：当前 nav、刚展示的 VC。
@property (nonatomic, copy) void (^onDidShowViewController)(UINavigationController *nav, UIViewController *shownVC);

@end
