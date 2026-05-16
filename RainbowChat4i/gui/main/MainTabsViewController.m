//telegram @wz662
#import "MainTabsViewController.h"
#import <objc/runtime.h>
#import "AlarmsViewController.h"
#import "MallViewController.h"
#import "IMClientManager.h"
#import "NavigationController.h"
#import "ContactViewController.h"
#import "MoreViewController.h"
#import "IMClientManager.h"
#import "NotificationCenterFactory.h"
#import "AlarmsProvider.h"
#import "BasicTool.h"
#import "UserDefaultsToolKits.h"
#import "WalletHomeViewController.h"
#import "RootViewController.h"
#import "UIView+XYMenu.h"
#import "ViewControllerFactory.h"
#import "QRCodeScheme.h"
#if __has_include("RainbowChat4i-Swift.h")
#import "RainbowChat4i-Swift.h"
#endif

#define KISIphoneX \
({BOOL isPhoneX = NO;\
if (@available(iOS 11.0, *)) {\
isPhoneX = [[UIApplication sharedApplication] delegate].window.safeAreaInsets.bottom > 0.0;\
}\
(isPhoneX);})

/// FabBar+渐变占用底部区域的大致高度，供根页 additionalSafeArea / 钱包 scroll inset 预留（略小于实际像素亦可）
static const CGFloat kMainTabFabChromeBottomInset = 108.f;

@interface MainTabsViewController ()
/** "消息"（私聊）界面对应的主界面底部导航栏tab对象引用 */
@property (strong, nonatomic) UITabBarItem *itemAlarms;
@property (strong, nonatomic) UITabBarItem *itemGroupAlarms;
@property (strong, nonatomic) UITabBarItem *itemContact;
@property (nonatomic, copy) ObserverCompletion alarmsUnreadNumObserver;
@property (nonatomic, copy) ObserverCompletion friendsReqUnreadNumObserver;

/// iOS < 26：系统 TabBar，作为子 VC 使用
@property (nonatomic, strong) UITabBarController *legacyTabBarController;
/// iOS 26+：5 个导航栈
@property (nonatomic, strong) NSArray<NavigationController *> *childNavControllers;
@property (nonatomic, assign) NSUInteger selectedTabIndex;
@property (nonatomic, strong) UIView *contentContainerView;
@property (nonatomic, strong) UIViewController *currentFabBarChild;
@property (nonatomic, strong) UIViewController *fabBarHostingController;
@property (nonatomic, strong) UIView *fabBarBottomGradientView;
@property (nonatomic, weak) UIButton *myTabButton;
@property (nonatomic, copy) NSString *fabBarMyTitle;
@property (nonatomic, strong) UIImage *fabBarMyImage;
@property (nonatomic, strong) UIImage *fabBarMySelectedImage;
/// FabBar 角标定时同步（主 tab 可见时每 1s 补一次，避免切换/滑动后红点消失）
@property (nonatomic, strong) NSTimer *fabBarBadgeSyncTimer;
/// 加号是否已隐藏（未隐藏前 bar 保持 alpha=0，避免初始化时加号闪烁）
@property (nonatomic, assign) BOOL fabBarPlusButtonHidden;
/// 当前承载 FabBar 渐变+Hosting 视图的导航「根」页面（用于 Tab 切换时清理 additionalSafeArea）
@property (nonatomic, weak) UIViewController *fabChromeHostRoot;
/// 高频未读变更时合并到下一小段主线程空闲时间，只刷新一次 badge/UI。
@property (nonatomic, assign) BOOL rb_alarmsUnreadRefreshScheduled;
@end

static const NSInteger kFabBarBadgeContainerTag = 8888;
/// FabBar TabBarSegmentedControl 注入的 content view 的 tag，用其 superview 定位 segment（不依赖 UISegment 类名）
static const NSInteger kFabBarInjectedContentViewTag = 7777;
/// 与 NavigationController 的 push/pop 转场时长一致，用于底部导航淡入淡出
static const NSTimeInterval kFabBarTransitionDuration = 0.18;

@implementation MainTabsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initObservers];
    // 先构建 Tab/FabBar，再注册角标监听：否则首帧到达的 POST 早于 applyTabBarItemsToNavs，itemAlarms 仍为 nil，赋值 badge 无效。
    if (@available(iOS 26.0, *)) {
        [self setupFabBarGUI];
    } else {
        [self setupLegacyGUI];
    }
    // 未读角标必须长期监听：若仅在 viewWillAppear 注册、viewDidDisappear 移除，则主 Tab 被全屏页/模态挡住时会卸掉观察者，
    // refreshMainPageTotalUnread_POST 仍发出但无人刷新，表现为「来消息了 Tab/底栏角标不更新；回前台或关遮挡页才变」。
    [[[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmsData] addObserver:self.alarmsUnreadNumObserver];
    [[[IMClientManager sharedInstance] getFriendsReqProvider] addUnreadChangedObserver:self.friendsReqUnreadNumObserver];
    [NotificationCenterFactory refreshMainPageTotalUnread_ADD:self selector:@selector(refreshAlarmsUnreadNumShow)];
}

- (void)dealloc
{
    [[[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmsData] removeObserver:self.alarmsUnreadNumObserver];
    [[[IMClientManager sharedInstance] getFriendsReqProvider] removeUnreadChangedObserver:self.friendsReqUnreadNumObserver];
    [NotificationCenterFactory refreshMainPageTotalUnread_REMOVE:self];
    [_fabBarBadgeSyncTimer invalidate];
}

- (NSArray<__kindof UIViewController *> *)viewControllers
{
    if (_legacyTabBarController != nil) {
        return _legacyTabBarController.viewControllers;
    }
    return _childNavControllers != nil ? (NSArray<__kindof UIViewController *> *)_childNavControllers : @[];
}

- (NSUInteger)selectedIndex
{
    if (_legacyTabBarController != nil) {
        return _legacyTabBarController.selectedIndex;
    }
    return _selectedTabIndex;
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
    if (_legacyTabBarController != nil) {
        _legacyTabBarController.selectedIndex = selectedIndex;
        return;
    }
    [self switchToFabBarTabIndex:selectedIndex];
}

- (UIViewController *)selectedViewController
{
    if (_legacyTabBarController != nil) {
        return _legacyTabBarController.selectedViewController;
    }
    if (_childNavControllers.count > _selectedTabIndex) {
        return _childNavControllers[_selectedTabIndex];
    }
    return nil;
}

/**
  * 界面将要显示前要做的事（包括从别的界面切换回来时）.
  *
  * * 因MainTabsViewController主Tab界面是基于UITabBarController实现，所以它的“viewWillAppear”方法
  * * 并不能像普通View controller一样被正常调用，所以当需要借助viewWillAppear方法来强制刷新未读数时在很多
  * * 情况是不能生效的，但因“首页”AlarmsViewController跟此tabitem的关系逻辑，借用它的viewWillAppear也
  * * 是完全符合逻辑的且不用折腾什么代码，详情见请 AlarmsViewController 中的viewWillAppear方法。
  */
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // 观察者与 refreshMainPageTotalUnread 在 viewDidLoad 注册、dealloc 移除（避免被遮挡时卸掉导致角标不更新）
    // 刷新首页"消息通知"未读总数的UI显示
    [self refreshAlarmsUnreadNumShow];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_childNavControllers != nil) {
        [self tryReplaceFabBarFABWithMyTab];
        if (_fabBarHostingController) {
            [self syncFabBarBadges];
            [self startFabBarBadgeSyncTimerIfNeeded];
        }
    }
}

// 界面已经消失、被覆盖、或者已经隐藏时要处理的事（包括被别的界面挡住时）
- (void)viewDidDisappear:(BOOL)animated
{
    [_fabBarBadgeSyncTimer invalidate];
    _fabBarBadgeSyncTimer = nil;

    [super viewDidDisappear:animated];
}

//** 以下代码可以解决iOS13后，自定义tabBar高度失效的问题
//-(void)viewDidLayoutSubviews
//{
//    [super viewDidLayoutSubviews];
//
//  if (@available(iOS 13.0, *))
//  {
//    CGRect frame =self.tabBar.frame;
//    frame.size.height=(KISIphoneX? 93 : 59);;
//    frame.origin.y = self.view.bounds.size.height - (KISIphoneX? 93 : 59);
//    self.tabBar.frame= frame;
//  }
//}

- (void)setupLegacyGUI
{
    UITabBarController *tbc = [[UITabBarController alloc] init];
    tbc.delegate = (id<UITabBarControllerDelegate>)self;
    _legacyTabBarController = tbc;
    if (@available(iOS 13.0, *)) {
        tbc.tabBar.tintColor = HexColor(0xc1342d);
        [[UITabBar appearance] setUnselectedItemTintColor:HexColor(0x2c2f36)];
    }
    if (@available(iOS 15.0, *)) {
        UITabBarAppearance *appearance = [UITabBarAppearance new];
        appearance.backgroundImage = [[UIImage imageNamed:@"main_tab_bg_img"] resizableImageWithCapInsets:UIEdgeInsetsMake(2,0,0,0) resizingMode:UIImageResizingModeStretch];
        tbc.tabBar.standardAppearance = appearance;
        tbc.tabBar.scrollEdgeAppearance = appearance;
    }
    if (!@available(iOS 26.0, *)) {
        CGFloat width = [UIScreen mainScreen].bounds.size.width;
        CGFloat height = [UIScreen mainScreen].bounds.size.height;
        CGFloat tabBarHeight = (KISIphoneX ? 83 : 49);
        tbc.tabBar.frame = CGRectMake(0, height - tabBarHeight, width, tabBarHeight);
        tbc.tabBar.clipsToBounds = YES;
        [tbc.tabBar setBackgroundImage:[[UIImage imageNamed:@"main_tab_bg_img"] resizableImageWithCapInsets:UIEdgeInsetsMake(2,0,0,0) resizingMode:UIImageResizingModeStretch]];
    }
    NSArray *navs = [self buildChildNavControllers];
    tbc.viewControllers = navs;
    [self addChildViewController:tbc];
    tbc.view.frame = self.view.bounds;
    tbc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:tbc.view];
    [tbc didMoveToParentViewController:self];
    [self applyTabBarItemsToNavs:navs];
}

- (void)setupFabBarGUI
{
#if __has_include("RainbowChat4i-Swift.h")
    self.view.backgroundColor = [UIColor clearColor];
    NSArray<NavigationController *> *navs = [self buildChildNavControllers];
    _childNavControllers = navs;
    _selectedTabIndex = 0;
    for (NavigationController *nav in navs) {
        [self addChildViewController:nav];
    }
    _contentContainerView = [[UIView alloc] initWithFrame:self.view.bounds];
    _contentContainerView.backgroundColor = [UIColor clearColor];
    _contentContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_contentContainerView];
    NavigationController *first = navs.firstObject;
    first.view.frame = _contentContainerView.bounds;
    first.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_contentContainerView addSubview:first.view];
    _currentFabBarChild = first;
    // FabBar 保留中间加号，外围 5 个 Tab 仍为：消息、群聊、通讯录、钱包、我的。
    NSArray<NSString *> *barTitles = @[
        NSLocalizedString(@"main_tabs_title_alarm", @""),
        NSLocalizedString(@"main_tabs_title_group", @""),
        NSLocalizedString(@"main_tabs_title_roster", @""),
        NSLocalizedString(@"main_tabs_title_wallet", @""),
        NSLocalizedString(@"main_tabs_title_more", @"")
    ];
    // 顺序：消息、群聊、通讯录、钱包、我的。钱包使用 main_portal_discover / main_portal_discover_select
    NSArray<NSString *> *barImgs = @[ @"main_portal_message", @"main_portal_group", @"main_portal_chat", @"main_portal_discover", @"main_portal_settings" ];
    NSArray<NSString *> *barSelImgs = @[ @"main_portal_message_select", @"main_portal_group_select", @"main_portal_chat_select", @"main_portal_discover_select", @"main_portal_settings_select" ];
    __weak typeof(self) wself = self;
    UIViewController *host = [MainTabFabBarFactory makeHostingControllerWithInitialSelection:0
                                                                                       titles:barTitles
                                                                                   imageNames:barImgs
                                                                              selectedImageNames:barSelImgs
                                                                                onSelectionChange:^(NSInteger idx) {
        [wself switchToFabBarTabIndex:(NSUInteger)idx];
    } onAddLongPress:^{
        [wself showFabBarPlusQuickMenu];
    }];
    _fabBarHostingController = host;
    host.view.backgroundColor = [UIColor clearColor];
    host.view.tintColor = HexColor(0xc1342d);  // 选中态图标与文字使用与原有 TabBar 一致的红色
    _fabBarPlusButtonHidden = YES; // 保留原生加号时，视为无需等待额外隐藏步骤，底栏可直接显示。
    [self setupFabBarBottomGradientView];
    _contentContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_contentContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_contentContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_contentContainerView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_contentContainerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    // FabBar 挂在当前 Tab 导航栈「根页」view 内：Pop 从聊天返回时与消息列表同属 toVC.view，底栏随列表一起被揭开（不再叠在 MainTabs 顶层）
    [self reparentFabBarChromeToNavigationRoot:first];
    host.view.alpha = 1;
    _fabBarBottomGradientView.alpha = 1;
    [self applyTabBarItemsToNavs:navs];
    [self setupFabBarVisibilityCallbackForNavs:navs];
    [self updateFabBarVisibilityForCurrentChild];
#else
    [self setupLegacyGUI];
#endif
}

- (void)showFabBarPlusQuickMenu
{
    UIView *anchorView = [self findFabBarPlusButtonInView:self.fabBarHostingController.view];
    if (anchorView == nil) {
        anchorView = self.fabBarHostingController.view;
    }
    if (anchorView == nil) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    NSArray *imageArr = @[@"main_alarms_floatmenu_adduser", @"main_alarms_floatmenu_addgroup", @"main_alarms_floatmenu_scan"];
    NSArray *titleArr = @[@"添加好友", @"创建群聊", @"扫一扫"];
    [anchorView xy_showMenuWithImages:imageArr titles:titleArr menuType:XYMenuRightNormal withItemClickIndex:^(NSInteger index) {
        if (index == 1) {
            [weakSelf gotoFabBarAddFriends];
        } else if (index == 2) {
            [weakSelf gotoFabBarCreateGroup];
        } else if (index == 3) {
            [weakSelf gotoFabBarScan];
        }
    }];
}

- (UIButton *)findFabBarPlusButtonInView:(UIView *)view
{
    if (view == nil) return nil;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)sub;
            if ([btn.accessibilityLabel isEqualToString:@"Add"]) {
                return btn;
            }
        }
        UIButton *nested = [self findFabBarPlusButtonInView:sub];
        if (nested != nil) {
            return nested;
        }
    }
    return nil;
}

- (UINavigationController *)currentFabBarNavigationController
{
    if ([_currentFabBarChild isKindOfClass:[UINavigationController class]]) {
        return (UINavigationController *)_currentFabBarChild;
    }
    return self.navigationController;
}

- (UIViewController *)currentFabBarMenuContextViewController
{
    UINavigationController *nav = [self currentFabBarNavigationController];
    return nav.topViewController ?: nav.viewControllers.firstObject ?: self;
}

- (void)gotoFabBarAddFriends
{
    UINavigationController *nav = [self currentFabBarNavigationController];
    if (nav == nil) return;
    [ViewControllerFactory goFindFriendViewController:nav];
}

- (void)gotoFabBarCreateGroup
{
    UINavigationController *nav = [self currentFabBarNavigationController];
    if (nav == nil) return;
    [ViewControllerFactory goGroupMemberViewController:nav usedFor:USED_FOR_CREATE_GROUP gid:nil isGroupOwner:YES defaultSelectedUid:nil];
}

- (void)gotoFabBarScan
{
    UINavigationController *nav = [self currentFabBarNavigationController];
    UIViewController *contextVC = [self currentFabBarMenuContextViewController];
    if (nav == nil || contextVC == nil) return;

    __weak typeof(contextVC) weakContextVC = contextVC;
    [QRCodeScheme gotoQrCodeScan:nav scanComplete:^(NSString *qrResult) {
        DLogDebug(@"%@", [NSString stringWithFormat:@"2维码扫描的结果是：%@", qrResult]);
        [QRCodeScheme processQRCodeScanResult:qrResult nav:nav view:weakContextVC.view vc:weakContextVC];
    }];
}

- (void)clearFabChromeInsetOnRoot:(UIViewController *)root
{
    if (root == nil) return;
    if ([root isKindOfClass:[RootViewController class]]) {
        RootViewController *rv = (RootViewController *)root;
        rv.rb_mainTabFabBottomInset = 0;
    }
    if ([root isKindOfClass:[WalletHomeViewController class]]) {
        ((WalletHomeViewController *)root).rb_mainTabFabBottomInset = 0;
    }
    [root.view setNeedsLayout];
}

- (void)applyFabChromeBottomInsetToRoot:(UIViewController *)root inset:(CGFloat)inset
{
    if (root == nil) return;
    if ([root isKindOfClass:[RootViewController class]]) {
        RootViewController *rv = (RootViewController *)root;
        rv.rb_mainTabFabBottomInset = inset;
    } else if ([root isKindOfClass:[WalletHomeViewController class]]) {
        ((WalletHomeViewController *)root).rb_mainTabFabBottomInset = inset;
    }
    [root.view setNeedsLayout];
}

/// 将 FabBar + 渐变挂到指定导航栈的根页面 `view` 上。
/// UIHostingController 必须作为「根页」的子控制器，其 view 必须在 root.view 层级内；若错误地作为 MainTabs 的 child
/// 却把 view 挂在别的 VC 上，Tab 来回切换会触发 UIViewControllerHierarchyInconsistency 闪退。
- (void)reparentFabBarChromeToNavigationRoot:(NavigationController *)nav
{
    if (!_fabBarHostingController || !_fabBarBottomGradientView || nav == nil) return;
    UIViewController *root = nav.viewControllers.firstObject;
    if (root == nil) return;

    UIViewController *host = _fabBarHostingController;

    if (self.fabChromeHostRoot != nil && self.fabChromeHostRoot != root) {
        [self clearFabChromeInsetOnRoot:self.fabChromeHostRoot];
    }
    self.fabChromeHostRoot = root;

    UIView *gradientView = _fabBarBottomGradientView;
    UIView *rv = root.view;
    [gradientView removeFromSuperview];
    [host.view removeFromSuperview];

    BOOL needAdopt = (host.parentViewController != root);
    if (needAdopt) {
        if (host.parentViewController != nil) {
            [host removeFromParentViewController];
        }
        [root addChildViewController:host];
    }

    [rv addSubview:gradientView];
    [rv addSubview:host.view];
    [rv bringSubviewToFront:gradientView];
    [rv bringSubviewToFront:host.view];

    gradientView.translatesAutoresizingMaskIntoConstraints = NO;
    host.view.translatesAutoresizingMaskIntoConstraints = NO;

    static const CGFloat barH = 58.f;
    static const CGFloat barWidth = 370.f;
    // 必须锚定到根页 view 的 bottom，勿用 safeAreaLayoutGuide.bottom：additionalSafeAreaInsets 会抬高 safe area，
    // 若底栏再相对 safeAreaLayoutGuide 约束，整条 FabBar 会随 inset 上移，表现为「导航不在底部」。
    [NSLayoutConstraint activateConstraints:@[
        [gradientView.leadingAnchor constraintEqualToAnchor:rv.leadingAnchor],
        [gradientView.trailingAnchor constraintEqualToAnchor:rv.trailingAnchor],
        [gradientView.bottomAnchor constraintEqualToAnchor:rv.bottomAnchor],
        [gradientView.heightAnchor constraintEqualToConstant:100],
        [host.view.centerXAnchor constraintEqualToAnchor:rv.centerXAnchor],
        [host.view.bottomAnchor constraintEqualToAnchor:rv.bottomAnchor constant:-24],
        [host.view.widthAnchor constraintEqualToConstant:barWidth],
        [host.view.heightAnchor constraintEqualToConstant:barH]
    ]];

    if (needAdopt) {
        [host didMoveToParentViewController:root];
    }
}

/// 底部导航下方渐变：从透明（下）到不透明（上），内容穿过时呈清晰→模糊
- (void)setupFabBarBottomGradientView
{
    _fabBarBottomGradientView = [[UIView alloc] init];
    _fabBarBottomGradientView.userInteractionEnabled = NO;
    _fabBarBottomGradientView.backgroundColor = [UIColor clearColor];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0, 0, 1, 100);
    UIColor *clear = [UIColor colorWithWhite:1 alpha:0];
    UIColor *opaque = [UIColor colorWithWhite:1 alpha:1];
    if (@available(iOS 13.0, *)) {
        opaque = [UIColor systemBackgroundColor];
    }
    gradient.colors = @[ (id)clear.CGColor, (id)opaque.CGColor ];
    gradient.startPoint = CGPointMake(0.5, 0);
    gradient.endPoint = CGPointMake(0.5, 1);
    gradient.name = @"fabBarBottomGradient";
    [_fabBarBottomGradientView.layer addSublayer:gradient];
    _fabBarBottomGradientView.layer.needsDisplayOnBoundsChange = YES;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (_fabBarBottomGradientView && _fabBarBottomGradientView.superview) {
        NSArray<CALayer *> *sublayers = _fabBarBottomGradientView.layer.sublayers;
        if (sublayers.count) {
            for (CALayer *sublayer in sublayers) {
                if (sublayer.name && [sublayer.name isEqualToString:@"fabBarBottomGradient"]) {
                    sublayer.frame = _fabBarBottomGradientView.bounds;
                    break;
                }
            }
        }
    }
    if (_fabBarHostingController) [self scheduleFabBarBadgeSyncAfterLayout];
}

/// 布局后防抖同步角标（避免 layout 频繁触发）；立即同步一次 + 延迟再同步一次，覆盖 segment 重排
- (void)scheduleFabBarBadgeSyncAfterLayout
{
    static NSTimeInterval lastScheduleTime = 0;
    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (now - lastScheduleTime < 0.25) return;
    lastScheduleTime = now;
    [self syncFabBarBadges];
    __weak typeof(self) wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [wself syncFabBarBadges];
    });
}

/// 主 tab 可见时启动定时器，每 1 秒补一次角标，保证切换/滑动后红点稳定不丢
- (void)startFabBarBadgeSyncTimerIfNeeded
{
    if (_fabBarBadgeSyncTimer != nil) return;
    __weak typeof(self) wself = self;
    _fabBarBadgeSyncTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [wself syncFabBarBadges];
    }];
    [[NSRunLoop mainRunLoop] addTimer:_fabBarBadgeSyncTimer forMode:NSRunLoopCommonModes];
}

/// 多档延迟重试，避免 SwiftUI/UIHostingController 尚未完成 makeUIView 时找不到 FAB；成功隐藏加号后再显示整条 bar，避免加号闪烁
- (void)hideFabBarPlusButtonWithRetriesInView:(UIView *)hostView attempt:(NSInteger)attempt
{
    if (!hostView) return;
    static const NSTimeInterval delays[] = { 0, 0.1, 0.25, 0.5, 1.0 };
    const NSInteger maxAttempt = (NSInteger)(sizeof(delays) / sizeof(delays[0]));
    if ([self hideFabBarPlusButtonInView:hostView]) {
        _fabBarPlusButtonHidden = YES;
        hostView.alpha = 1;
        _fabBarBottomGradientView.alpha = 1;
        [self updateFabBarVisibilityForCurrentChild];  // 同步 alpha（若当前为主页则保持可见）
        __weak typeof(self) wself = self;
        void (^syncOnce)(void) = ^{ [wself syncFabBarBadges]; };
        dispatch_async(dispatch_get_main_queue(), syncOnce);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), syncOnce);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), syncOnce);
        return;
    }
    if (attempt + 1 < maxAttempt) {
        NSTimeInterval delay = delays[attempt + 1];
        __weak typeof(self) wself = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [wself hideFabBarPlusButtonWithRetriesInView:hostView attempt:attempt + 1];
        });
    } else {
        [MainTabsViewController dumpViewHierarchyForFabBarDebug:hostView prefix:@"[FabBar]"];
        _fabBarPlusButtonHidden = YES;  // 视为已处理，避免 bar 一直不显示
        hostView.alpha = 1;
        _fabBarBottomGradientView.alpha = 1;
        [self updateFabBarVisibilityForCurrentChild];
    }
}

+ (void)dumpViewHierarchyForFabBarDebug:(UIView *)view prefix:(NSString *)prefix
{
    if (!view) return;
    NSString *label = view.accessibilityLabel.length ? view.accessibilityLabel : @"";
    NSLog(@"%@ %@ label=%@ frame=%@", prefix, NSStringFromClass([view class]), label, NSStringFromCGRect(view.frame));
    for (UIView *sub in view.subviews) {
        [self dumpViewHierarchyForFabBarDebug:sub prefix:[prefix stringByAppendingString:@"  "]];
    }
}

- (BOOL)hideFabBarPlusButtonInView:(UIView *)view
{
    if (!view) return NO;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)sub;
            if ([btn.accessibilityLabel isEqualToString:@"Add"]) {
                btn.hidden = YES;
                btn.alpha = 0;
                // FabBar: fabButton.superview = contentView, superview.superview = fabGlassView（蓝色玻璃容器）
                UIView *contentView = btn.superview;
                if (contentView) {
                    contentView.hidden = YES;
                    contentView.alpha = 0;
                }
                UIView *fabGlassView = contentView.superview;
                if (fabGlassView) {
                    fabGlassView.hidden = YES;
                    fabGlassView.alpha = 0;
                    // 将 FAB 区域宽度改为 0，否则仍占位导致右侧「我的」被挤、无法正确显示
                    [self collapseFabGlassViewWidth:fabGlassView];
                }
                return YES;
            }
        }
        if ([self hideFabBarPlusButtonInView:sub]) return YES;
    }
    return NO;
}

/// 把 FabBar 的 fabGlassView 宽度约束改为 0，让 5 个 tab 占满整条 bar，右侧「我的」正常显示
- (void)collapseFabGlassViewWidth:(UIView *)fabGlassView
{
    UIView *container = fabGlassView.superview;
    NSLayoutConstraint *toDeactivate = nil;
    for (NSLayoutConstraint *c in container.constraints) {
        if ((c.firstItem == fabGlassView && c.firstAttribute == NSLayoutAttributeWidth) ||
            (c.secondItem == fabGlassView && c.secondAttribute == NSLayoutAttributeWidth)) {
            toDeactivate = c;
            break;
        }
    }
    if (!toDeactivate && fabGlassView.constraints.count > 0) {
        for (NSLayoutConstraint *c in fabGlassView.constraints) {
            if (c.firstItem == fabGlassView && c.firstAttribute == NSLayoutAttributeWidth) {
                toDeactivate = c;
                break;
            }
        }
    }
    if (toDeactivate) toDeactivate.active = NO;
    NSLayoutConstraint *zeroWidth = [fabGlassView.widthAnchor constraintEqualToConstant:0];
    zeroWidth.active = YES;
}

/// 在 view 子树中递归查找 tag 为 kFabBarInjectedContentViewTag 的视图，收集其 superview（即 segment 容器）
- (void)collectSegmentViewsFromInjectedViewsInView:(UIView *)view into:(NSMutableArray<UIView *> *)outSegments
{
    if (view.tag == kFabBarInjectedContentViewTag && view.superview) {
        [outSegments addObject:view.superview];
        return;
    }
    for (UIView *sub in view.subviews) {
        [self collectSegmentViewsFromInjectedViewsInView:sub into:outSegments];
    }
}

/// 备用：按类名 UISegment 收集（当 tag 方式未找到时）
- (void)collectSegmentViewsByClassInView:(UIView *)view into:(NSMutableArray<UIView *> *)outSegments
{
    for (UIView *sub in view.subviews) {
        if ([NSStringFromClass([sub class]) containsString:@"UISegment"]) {
            [outSegments addObject:sub];
        } else {
            [self collectSegmentViewsByClassInView:sub into:outSegments];
        }
    }
}

- (NSArray<UIView *> *)fabBarSegmentViewsOrderedByX
{
    UIView *hostView = _fabBarHostingController.view;
    if (!hostView) return @[];
    NSMutableArray<UIView *> *segments = [NSMutableArray array];
    [self collectSegmentViewsFromInjectedViewsInView:hostView into:segments];
    if (segments.count == 0) {
        [self collectSegmentViewsByClassInView:hostView into:segments];
    }
    if (segments.count == 0) return @[];
    [segments sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat xa = a.frame.origin.x;
        CGFloat xb = b.frame.origin.x;
        if (xa < xb) return NSOrderedAscending;
        if (xa > xb) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return segments;
}

/// 在 segment 视图右上角添加或更新红点/数字角标（badgeValue 为 nil 或 @"0" 则隐藏）
- (void)applyBadgeValue:(NSString *)badgeValue toSegmentView:(UIView *)segmentView
{
    NSString *normValue = (badgeValue.length > 0 && ![badgeValue isEqualToString:@"0"]) ? badgeValue : nil;
    UIView *container = [segmentView viewWithTag:kFabBarBadgeContainerTag];
    BOOL shouldShow = (normValue != nil);
    if (!shouldShow) {
        if (container) {
            container.hidden = YES;
            container.accessibilityValue = nil;
        }
        return;
    }
    if (container && !container.hidden && [container.accessibilityValue isEqual:normValue]) {
        [segmentView bringSubviewToFront:container];
        return;
    }
    const CGFloat badgeMinSize = 20;
    const CGFloat fontSize = 12;
    if (!container) {
        container = [[UIView alloc] init];
        container.tag = kFabBarBadgeContainerTag;
        container.backgroundColor = HexColor(0xf74c31);
        container.layer.cornerRadius = badgeMinSize / 2;
        container.clipsToBounds = YES;
        container.userInteractionEnabled = NO;
        [segmentView addSubview:container];
    }
    container.hidden = NO;
    UILabel *label = nil;
    for (UIView *sub in container.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            label = (UILabel *)sub;
            break;
        }
    }
    CGFloat badgeWidth = badgeMinSize;
    int num = [badgeValue intValue];
    if (num > 0) {
        if (!label) {
            label = [[UILabel alloc] init];
            label.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium];
            label.textColor = [UIColor whiteColor];
            label.textAlignment = NSTextAlignmentCenter;
            label.hidden = NO;
            label.backgroundColor = [UIColor clearColor];
            [container addSubview:label];
        }
        label.hidden = NO;
        label.text = (num > 99) ? @"99+" : [NSString stringWithFormat:@"%d", num];
        [label sizeToFit];
        badgeWidth = MAX(badgeMinSize, (CGFloat)label.bounds.size.width + 8);
        container.bounds = CGRectMake(0, 0, badgeWidth, badgeMinSize);
        container.layer.cornerRadius = badgeMinSize / 2;
        // 让 label 填满容器并居中显示文字，避免 Auto Layout 后 frame 错位导致数字不可见
        label.frame = CGRectMake(0, 0, badgeWidth, badgeMinSize);
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    } else {
        container.bounds = CGRectMake(0, 0, badgeMinSize, badgeMinSize);
        if (label) [label removeFromSuperview];
    }
    container.translatesAutoresizingMaskIntoConstraints = NO;
    if (container.superview != segmentView) {
        [segmentView addSubview:container];
    }
    NSMutableArray<NSLayoutConstraint *> *toRemove = [NSMutableArray array];
    for (NSLayoutConstraint *c in segmentView.constraints) {
        if (c.firstItem == container || c.secondItem == container) [toRemove addObject:c];
    }
    for (NSLayoutConstraint *c in toRemove) { c.active = NO; }
    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:segmentView.topAnchor constant:2],
        [container.trailingAnchor constraintEqualToAnchor:segmentView.trailingAnchor constant:-8],
        [container.widthAnchor constraintEqualToConstant:badgeWidth],
        [container.heightAnchor constraintEqualToConstant:badgeMinSize]
    ]];
    container.accessibilityValue = normValue;
    [segmentView bringSubviewToFront:container];
}

/// 将 itemAlarms / itemGroupAlarms / itemContact 的 badgeValue 同步到 FabBar 前 3 个 segment 上
- (void)syncFabBarBadges
{
    if (!_fabBarHostingController.view || !_childNavControllers.count) return;
    NSArray<UIView *> *segments = [self fabBarSegmentViewsOrderedByX];
    if (segments.count < 3) return;
    [self applyBadgeValue:_itemAlarms.badgeValue toSegmentView:segments[0]];
    [self applyBadgeValue:_itemGroupAlarms.badgeValue toSegmentView:segments[1]];
    [self applyBadgeValue:_itemContact.badgeValue toSegmentView:segments[2]];
}

/// 切换 tab（含按住滑动）后分多档延迟同步角标，覆盖手势/动画导致的 segment 重排
- (void)scheduleFabBarBadgeSyncAfterTabSwitch
{
    if (!_fabBarHostingController) return;
    [self syncFabBarBadges];
    __weak typeof(self) wself = self;
    NSTimeInterval delays[] = { 0.03, 0.1, 0.2, 0.35, 0.55, 0.8, 1.15, 1.6 };
    for (size_t i = 0; i < sizeof(delays) / sizeof(delays[0]); i++) {
        NSTimeInterval d = delays[i];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [wself syncFabBarBadges];
        });
    }
}

- (void)tryReplaceFabBarFABWithMyTab
{
    if (!_fabBarHostingController.view || !_fabBarMyTitle || !_fabBarMyImage) return;
    if (_myTabButton) return;
    __weak UIView *hostView = _fabBarHostingController.view;
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [wself replaceFabBarFABWithMyTabInView:hostView title:wself.fabBarMyTitle image:wself.fabBarMyImage selectedImage:wself.fabBarMySelectedImage];
        if (!wself.myTabButton) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [wself replaceFabBarFABWithMyTabInView:hostView title:wself.fabBarMyTitle image:wself.fabBarMyImage selectedImage:wself.fabBarMySelectedImage];
            });
        }
    });
}

/// 在 FAB 位置用「我的」按钮替换加号
- (void)replaceFabBarFABWithMyTabInView:(UIView *)view title:(NSString *)title image:(UIImage *)image selectedImage:(UIImage *)selectedImage
{
    if (!view || _myTabButton) return;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)sub;
            if ([btn.accessibilityLabel isEqualToString:@"Add"]) {
                UIView *fabContainer = btn.superview;
                [btn removeFromSuperview];
                if (!fabContainer) return;
                fabContainer.backgroundColor = [UIColor clearColor];
                if ([fabContainer isKindOfClass:[UIVisualEffectView class]]) {
                    ((UIVisualEffectView *)fabContainer).effect = nil;
                }
                UIButton *myBtn = [UIButton buttonWithType:UIButtonTypeSystem];
                myBtn.translatesAutoresizingMaskIntoConstraints = NO;
                myBtn.backgroundColor = [UIColor clearColor];
                [myBtn setImage:[image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
                [myBtn setImage:[selectedImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateSelected];
                [myBtn setTitle:title forState:UIControlStateNormal];
                myBtn.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
                [myBtn setTitleColor:HexColor(0x2c2f36) forState:UIControlStateNormal];
                [myBtn setTitleColor:HexColor(0xc1342d) forState:UIControlStateSelected];
                myBtn.accessibilityLabel = title;
                __weak typeof(self) wself = self;
                [myBtn addAction:[UIAction actionWithHandler:^(__unused UIAction * _Nonnull action) {
                    [wself switchToFabBarTabIndex:4];
                }] forControlEvents:UIControlEventTouchUpInside];
                [fabContainer addSubview:myBtn];
                [NSLayoutConstraint activateConstraints:@[
                    [myBtn.centerXAnchor constraintEqualToAnchor:fabContainer.centerXAnchor],
                    [myBtn.centerYAnchor constraintEqualToAnchor:fabContainer.centerYAnchor],
                    [myBtn.leadingAnchor constraintGreaterThanOrEqualToAnchor:fabContainer.leadingAnchor],
                    [myBtn.trailingAnchor constraintLessThanOrEqualToAnchor:fabContainer.trailingAnchor]
                ]];
                self.myTabButton = myBtn;
                myBtn.selected = (_selectedTabIndex == 4);
                return;
            }
        }
        [self replaceFabBarFABWithMyTabInView:sub title:title image:image selectedImage:selectedImage];
        if (_myTabButton) return;
    }
}

- (void)switchToFabBarTabIndex:(NSUInteger)index
{
    if (index >= _childNavControllers.count || index == _selectedTabIndex) return;
    [_currentFabBarChild.view removeFromSuperview];
    _selectedTabIndex = index;
    if (_myTabButton) _myTabButton.selected = (index == 4);
    NavigationController *nav = _childNavControllers[index];
    nav.view.frame = _contentContainerView.bounds;
    nav.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_contentContainerView addSubview:nav.view];
    _currentFabBarChild = nav;
    [self reparentFabBarChromeToNavigationRoot:nav];
    [self updateFabBarVisibilityForCurrentChild];
    // 切换 tab（含按住滑动）后多次延迟同步角标，FabBar 手势/动画重排后 segment 可能重建，需重新挂角标
    [self scheduleFabBarBadgeSyncAfterTabSwitch];
}

/// 仅当当前导航栈为根（5 个主页面）时显示底部导航，push 到子页面时隐藏；didShow 时同步最终状态（含转场取消时恢复 alpha）
- (void)updateFabBarVisibilityForCurrentChild
{
    if (!_fabBarHostingController || !_fabBarBottomGradientView) return;
    UINavigationController *nav = (UINavigationController *)_currentFabBarChild;
    BOOL isRootOnly = (nav.viewControllers.count <= 1);
    UIViewController *root = nav.viewControllers.firstObject;
    if (isRootOnly) {
        [self applyFabChromeBottomInsetToRoot:root inset:kMainTabFabChromeBottomInset];
    } else if (root != nil) {
        [self clearFabChromeInsetOnRoot:root];
    }
    _fabBarHostingController.view.hidden = !isRootOnly;
    _fabBarBottomGradientView.hidden = !isRootOnly;
    // 保留中间加号时直接显示；非根页仍由 hidden 控制整体隐藏。
    CGFloat barAlpha = (_fabBarPlusButtonHidden || !isRootOnly) ? 1 : 0;
    _fabBarHostingController.view.alpha = barAlpha;
    _fabBarBottomGradientView.alpha = barAlpha;
}

/// 为 5 个 NavigationController 设置 willShow/didShow 回调：转场时底部导航与左右平移同步淡入淡出，不直接显隐
- (void)setupFabBarVisibilityCallbackForNavs:(NSArray<NavigationController *> *)navs
{
    __weak typeof(self) wself = self;
    for (NavigationController *nav in navs) {
        nav.onWillShowViewController = ^(UINavigationController *navArg, UIViewController *viewController, BOOL animated) {
            if (wself.currentFabBarChild != navArg || !wself.fabBarHostingController || !wself.fabBarBottomGradientView) return;
            BOOL willShowRoot = (viewController == navArg.viewControllers.firstObject);
            UIView *barView = wself.fabBarHostingController.view;
            UIView *gradientView = wself.fabBarBottomGradientView;
            if (animated) {
                if (willShowRoot) {
                    barView.hidden = NO;
                    gradientView.hidden = NO;
                    barView.alpha = 0;
                    gradientView.alpha = 0;
                    [UIView animateWithDuration:kFabBarTransitionDuration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                        barView.alpha = 1;
                        gradientView.alpha = 1;
                    } completion:nil];
                } else {
                    [UIView animateWithDuration:kFabBarTransitionDuration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                        barView.alpha = 0;
                        gradientView.alpha = 0;
                    } completion:^(BOOL finished) {
                        if (finished) {
                            barView.hidden = YES;
                            gradientView.hidden = YES;
                            barView.alpha = 1;
                            gradientView.alpha = 1;
                        }
                    }];
                }
            } else {
                barView.hidden = !willShowRoot;
                gradientView.hidden = !willShowRoot;
                barView.alpha = 1;
                gradientView.alpha = 1;
            }
        };
        nav.onDidShowViewController = ^(UINavigationController *navArg, UIViewController *shownVC) {
            if (wself.currentFabBarChild != navArg) return;
            [wself updateFabBarVisibilityForCurrentChild];
        };
    }
}

- (NSArray<NavigationController *> *)buildChildNavControllers
{
    AlarmsViewController *privateAlarmsVC = [[AlarmsViewController alloc] initWithNibName:@"AlarmsViewController" bundle:nil];
    privateAlarmsVC.alarmFilterMode = ALARM_FILTER_PRIVATE;
    NavigationController *nav1 = [[NavigationController alloc] initWithRootViewController:privateAlarmsVC];
    nav1.tabBarItem.title = NSLocalizedString(@"main_tabs_title_alarm", @"");
    
    AlarmsViewController *groupAlarmsVC = [[AlarmsViewController alloc] initWithNibName:@"AlarmsViewController" bundle:nil];
    groupAlarmsVC.alarmFilterMode = ALARM_FILTER_GROUP;
    NavigationController *nav2 = [[NavigationController alloc] initWithRootViewController:groupAlarmsVC];
    nav2.tabBarItem.title = NSLocalizedString(@"main_tabs_title_group", @"");

    ContactViewController *contactVC = [[ContactViewController alloc] initWithNibName:@"ContactViewController" bundle:nil];
    NavigationController *nav3 = [[NavigationController alloc] initWithRootViewController:contactVC];
    nav3.tabBarItem.title = NSLocalizedString(@"main_tabs_title_roster", @"");

    WalletHomeViewController *walletVC = [[WalletHomeViewController alloc] init];
    NavigationController *nav4 = [[NavigationController alloc] initWithRootViewController:walletVC];
    nav4.tabBarItem.title = NSLocalizedString(@"main_tabs_title_wallet", @"");

    MoreViewController *moreVC = [[MoreViewController alloc] initWithNibName:@"MoreViewController" bundle:nil];
    NavigationController *nav5 = [[NavigationController alloc] initWithRootViewController:moreVC];
    nav5.tabBarItem.title = NSLocalizedString(@"main_tabs_title_more", @"");

    return @[ nav1, nav2, nav3, nav4, nav5 ];
}

- (void)applyTabBarItemsToNavs:(NSArray<NavigationController *> *)navs
{
    NSArray *titles = @[
        NSLocalizedString(@"main_tabs_title_alarm", @""),
        NSLocalizedString(@"main_tabs_title_group", @""),
        NSLocalizedString(@"main_tabs_title_roster", @""),
        NSLocalizedString(@"main_tabs_title_wallet", @""),
        NSLocalizedString(@"main_tabs_title_more", @"")
    ];
    // 与 setupFabBarGUI 一致：钱包(index 3) 使用 main_portal_discover_select
    NSArray *imgs = @[ @"main_portal_message", @"main_portal_group", @"main_portal_chat", @"main_portal_discover", @"main_portal_settings" ];
    NSArray *selImgs = @[ @"main_portal_message_select", @"main_portal_group_select", @"main_portal_chat_select", @"main_portal_discover_select", @"main_portal_settings_select" ];
    for (NSUInteger i = 0; i < navs.count && i < titles.count; i++) {
        UITabBarItem *item = navs[i].tabBarItem;
        item.title = titles[i];
        item.image = [[UIImage imageNamed:imgs[i]] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        item.selectedImage = [[UIImage imageNamed:selImgs[i]] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        [item setTitleTextAttributes:@{ NSForegroundColorAttributeName: HexColor(0x2c2f36) } forState:UIControlStateNormal];
        [item setTitleTextAttributes:@{ NSForegroundColorAttributeName: HexColor(0xc1342d) } forState:UIControlStateSelected];
    }
    if (navs.count > 0) {
        self.itemAlarms = navs[0].tabBarItem;
        self.itemAlarms.badgeColor = [self extracted];
    }
    if (navs.count > 1) {
        self.itemGroupAlarms = navs[1].tabBarItem;
        self.itemGroupAlarms.badgeColor = [self extracted];
    }
    if (navs.count > 2) {
        self.itemContact = navs[2].tabBarItem;
        self.itemContact.badgeColor = [self extracted];
    }
}

// 初始化本界面中需要的观察者
- (void) initObservers
{
    //** 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak MainTabsViewController *safeSelf = self;
    //** 首页“消息”未读总数的观察者实现block
    self.alarmsUnreadNumObserver = ^(id observerble ,id data) {
        [safeSelf refreshAlarmsUnreadNumShow];
    };
    //** 设置“好友”未处理请求总数变动的观察者实现block
    self.friendsReqUnreadNumObserver = ^(id observerble ,id data) {
        [safeSelf refreshFriendsReqUnreadNumShow];
    };
}

- (UIColor * _Nonnull)extracted {
    return HexColor(0xf74c31);//RGBCOLOR(255,102,0);
}

// 向主tab界面中加一个tab子界面
- (void)addTab:(UIViewController *)vc title:(NSString *)title imgName:(NSString *)imageName selectedImgName:(NSString *)selectedImageName
{
    vc.title = title;
    NavigationController *nav = [[NavigationController alloc] initWithRootViewController:vc];

    UITabBarItem *item = nav.tabBarItem;
    item.title = title;
    // 使用UIImageRenderingModeAlwaysOriginal选项关闭默认渲染，否则图片会变的有点灰灰的
    item.image = [[UIImage imageNamed:imageName] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    item.selectedImage = [[UIImage imageNamed:selectedImageName] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    // 设置tab item未选中时的字体颜色
    [item setTitleTextAttributes:@{NSForegroundColorAttributeName : HexColor(0x2c2f36)} forState:UIControlStateNormal];
    // 设置tab item选中时的字体颜色（主题红 c1342d）
    [item setTitleTextAttributes:@{NSForegroundColorAttributeName : HexColor(0xc1342d)} forState:UIControlStateSelected];

    // tab上需要显示未读数的item
    if([vc isKindOfClass:[AlarmsViewController class]])
    {
        AlarmsViewController *avc = (AlarmsViewController *)vc;
        if (avc.alarmFilterMode == ALARM_FILTER_GROUP) {
            // 群聊消息tab
            self.itemGroupAlarms = item;
            self.itemGroupAlarms.badgeColor = [self extracted];
        } else {
            // 私聊消息tab（默认或ALARM_FILTER_PRIVATE）
            self.itemAlarms = item;
            self.itemAlarms.badgeColor = [self extracted];
        }
    } else if([vc isKindOfClass:[ContactViewController class]]){
        self.itemContact = item;
        self.itemContact.badgeColor = [self extracted];
    }
    
    [self addChildViewController:nav];
}

// 刷新"消息"和"群聊"tabitem上的未读消息总数的UI显示（下一 runloop 执行，避免通知回调内同步角标 XPC 阻塞主线程）
- (void)refreshAlarmsUnreadNumShow {
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (wself.rb_alarmsUnreadRefreshScheduled) {
            return;
        }
        wself.rb_alarmsUnreadRefreshScheduled = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            wself.rb_alarmsUnreadRefreshScheduled = NO;
            [wself doActualRefreshAlarmsUnreadNumShow];
        });
    });
}

- (void)doActualRefreshAlarmsUnreadNumShow {
    AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
    int privateUnreadNum = [ap getPrivateFlagNum];
    int groupUnreadNum = [ap getGroupFlagNum];
    NSInteger groupNotifyUnreadNum = [UserDefaultsToolKits getGroupNotificationUnreadCount];
    int totalPrivateUnreadNum = privateUnreadNum + (int)MAX(groupNotifyUnreadNum, 0);
    if (totalPrivateUnreadNum > 0) {
        self.itemAlarms.badgeValue = [NSString stringWithFormat:@"%d", totalPrivateUnreadNum];
    } else {
        self.itemAlarms.badgeValue = nil;
    }
    if (groupUnreadNum > 0) {
        self.itemGroupAlarms.badgeValue = [NSString stringWithFormat:@"%d", groupUnreadNum];
    } else {
        self.itemGroupAlarms.badgeValue = nil;
    }
    int totalUnreadNum = totalPrivateUnreadNum + groupUnreadNum;
    if (totalUnreadNum > 0) {
        [UIApplication sharedApplication].applicationIconBadgeNumber = totalUnreadNum;
    } else {
        [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    }
    if (_fabBarHostingController) [self syncFabBarBadges];
}

// 刷新“好友”tabitem上的未处理好友请求总数的UI显示
- (void)refreshFriendsReqUnreadNumShow {
    int totalUnreadNum = [[[IMClientManager sharedInstance] getFriendsReqProvider] getUnreadCount];
    if(totalUnreadNum > 0) {
        self.itemContact.badgeValue = [NSString stringWithFormat:@"%d", totalUnreadNum];
    } else {
        self.itemContact.badgeValue = nil;
    }
    if (_fabBarHostingController) [self syncFabBarBadges];
}

@end
