//telegram @wz662
//
// 切回系统默认 UINavigationController push/pop 动画。
// 仅保留：导航栏样式、willShow/didShow 回调、聊天页 pop 前清理。
//

#import "NavigationController.h"
#import "BasicTool.h"
#import "AlarmsViewController.h"
#import "SettingsViewController.h"
#import "ChatRootViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "UIViewController+RBAlarmsStyleMainTabNav.h"

static BOOL RBShouldHideSystemNavigationBarForViewController(UIViewController *viewController)
{
    if (viewController == nil) {
        return NO;
    }
    if ([viewController isKindOfClass:[AlarmsViewController class]]) {
        return YES;
    }
    if ([viewController isKindOfClass:[SettingsViewController class]]) {
        return YES;
    }
    if ([viewController isKindOfClass:[ChatRootViewController class]]) {
        return YES;
    }
    if ([viewController respondsToSelector:@selector(rb_plainChromeNavigationBarIfInstalled)] &&
        [viewController rb_plainChromeNavigationBarIfInstalled] != nil) {
        return YES;
    }
    if ([viewController respondsToSelector:@selector(rb_alarmsStyleMainTabNavigationBarIfInstalled)] &&
        [viewController rb_alarmsStyleMainTabNavigationBarIfInstalled] != nil) {
        return YES;
    }
    return NO;
}

static UIViewController *RBCurrentNavigationBarDecisionAnchorVC(UINavigationController *nav)
{
    UIViewController *vc = nav.visibleViewController;
    if (vc == nil) {
        vc = nav.topViewController;
    }
    return vc;
}

@implementation NavigationController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 保留 delegate，用于 willShow/didShow 回调和导航栏显隐控制；不再提供自定义 Animator。
    self.delegate = self;

    // 使用系统默认侧滑返回，不再使用自定义全屏 Pan 返回。
    self.interactivePopGestureRecognizer.enabled = YES;
    self.interactivePopGestureRecognizer.delegate = self;

    // 适配ios 26：不设置tabbar的背景时，tabbar将自动浮动于整个容器之前，这样它的液态玻璃就更明显了
    if (@available(iOS 26.0, *)) {
        // 什么也不做
        // 设置默认左右按钮的颜色
//        self.navigationBar.tintColor = UI_DEFAULT_HILIGHT_COLOR; // 此代码在ios 26不起效！
    }
    // 当系统版本低于ios 26时需要做的处理
    else {
        self.navigationBar.translucent = NO;

        // 标题栏背景色
        self.navigationBar.barTintColor = UI_DEFAULT_TITLE_BG_COLOR;
        // 设置默认左右按钮的颜色
        self.navigationBar.tintColor = UI_DEFAULT_HILIGHT_COLOR;
//      self.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName:UI_DEFAULT_HILIGHT_COLOR};

        // 标题栏字体大小和标题颜色
        [self.navigationBar setTitleTextAttributes:@{NSFontAttributeName:[BasicTool getSystemFontOfSize:UI_DEFAULT_TITLE_FONT_SIZE],
                                                     NSForegroundColorAttributeName:UI_DEFAULT_TITLE_FONT_COLOR}];

        // 设置 navigationBar 下面的横线
        [self.navigationBar setShadowImage:[UIImage imageNamed:@"navigation_bar_shadow_image"]];

        // 适配iOS15，如不适配则每个界面标题栏都会变黑色，很难看
        if (@available(iOS 13.0, *)) {
            UINavigationBarAppearance *barApp = [UINavigationBarAppearance new];
            barApp.backgroundColor = UI_DEFAULT_TITLE_BG_COLOR;
            barApp.backgroundEffect = nil;
            barApp.shadowImage = [UIImage imageNamed:@"navigation_bar_shadow_image"];
            self.navigationBar.scrollEdgeAppearance = barApp;
            self.navigationBar.standardAppearance = barApp;
        }
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated
{
    // 兼容旧页面里的遗留逻辑：很多自定义头部页面会在 viewWillDisappear / viewDidDisappear 中主动调用
    // setNavigationBarHidden:NO，系统默认 push/pop 下这会在转场边界把系统返回键提前放出来。
    // 这里把“页面侧的显示请求”拦住，只允许导航器自己的 willShow/didShow 根据目标页做最终裁决。
    if (!hidden) {
        UIViewController *anchorVC = RBCurrentNavigationBarDecisionAnchorVC(self);
        if (RBShouldHideSystemNavigationBarForViewController(anchorVC)) {
            [super setNavigationBarHidden:YES animated:NO];
            return;
        }
    }
    [super setNavigationBarHidden:hidden animated:animated];
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (self.viewControllers.count > 0) {
        viewController.hidesBottomBarWhenPushed = YES;
    }
    [super pushViewController:viewController animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    UIViewController *fromVC = self.topViewController;
    UIViewController *toVC = (self.viewControllers.count >= 2) ? self.viewControllers[self.viewControllers.count - 2] : nil;
    if ([fromVC isKindOfClass:[ChatRootViewController class]]) {
        [(ChatRootViewController *)fromVC rb_prepareForNavigationPopToViewController:toVC reason:@"nav-pop"];
    }
    return [super popViewControllerAnimated:animated];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    // 系统动画下，转场开始前就要根据目标页是否使用自定义头部来同步隐藏/显示系统导航栏，
    // 否则 push/pop 边界会短暂闪出系统返回键。
    BOOL shouldHideSystemNavBar = RBShouldHideSystemNavigationBarForViewController(viewController);
    [super setNavigationBarHidden:shouldHideSystemNavBar animated:NO];
    if (self.onWillShowViewController) {
        self.onWillShowViewController(navigationController, viewController, animated);
    }
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    BOOL shouldHideSystemNavBar = RBShouldHideSystemNavigationBarForViewController(viewController);
    [super setNavigationBarHidden:shouldHideSystemNavBar animated:NO];

    // 使用系统默认导航动画后，仍在 didShow 里同步一次 TabBar 显隐，避免个别系统版本与自定义底栏状态不同步。
    if (self.tabBarController != nil) {
        BOOL isRoot = (viewController == navigationController.viewControllers.firstObject);
        self.tabBarController.tabBar.hidden = !isRoot;
    }
    if (self.onDidShowViewController) {
        self.onDidShowViewController(navigationController, viewController);
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == self.interactivePopGestureRecognizer) {
        if (self.viewControllers.count <= 1) {
            return NO;
        }
        if (self.transitionCoordinator != nil) {
            return NO;
        }
    }
    return YES;
}

@end
