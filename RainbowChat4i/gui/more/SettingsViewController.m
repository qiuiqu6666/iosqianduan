//telegram @wz662
#import "SettingsViewController.h"
#import "ViewControllerFactory.h"
#import "BasicTool.h"
#import "IMClientManager.h"
#import "UserEntity.h"
#import "MoreViewController.h"
#import "LPActionSheet.h"
#import "AppDelegate.h"
#import "Default.h"
#import "RBChromeNavigationBar.h"

/// 与 RBChromeNavigationBar 的 contentRowHeight 一致；用于 additionalSafeAreaInsets，使 XIB 内 scroll 顶对齐扩展后的安全区
static const CGFloat kRBSettingsChromeNavContentRow = 44.0f;

@interface SettingsViewController ()

@property (nonatomic, strong, nullable) RBChromeNavigationBar *rb_settingsChromeNavBar;

@end

@implementation SettingsViewController

- (RBChromeNavigationBar *)rb_transitionChromeNavigationBar
{
    return self.rb_settingsChromeNavBar;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.title = @"";

    RBChromeNavigationBar *nav = [[RBChromeNavigationBar alloc] initWithBottomPinStyle:RBChromeNavigationBarBottomPinStyleExtendedSafeAreaTop];
    nav.contentRowHeight = kRBSettingsChromeNavContentRow;
    nav.titleLabel.text = @"设置";
    [nav setBackButtonTarget:self action:@selector(rb_onSettingsBackTap)];
    self.rb_settingsChromeNavBar = nav;
    self.additionalSafeAreaInsets = UIEdgeInsetsMake(kRBSettingsChromeNavContentRow, 0, 0, 0);
    [nav installInHostView:self.view];
    CGFloat pt0 = [BasicTool getAdjustedFontSize:17.f];
    nav.titleLabel.font = [UIFont boldSystemFontOfSize:pt0];
    nav.titleLabel.textColor = [UIColor labelColor];
}

- (void)rb_onSettingsBackTap
{
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [UIView performWithoutAnimation:^{
        UIEdgeInsets insetNeed = UIEdgeInsetsMake(kRBSettingsChromeNavContentRow, 0, 0, 0);
        if (!UIEdgeInsetsEqualToEdgeInsets(self.additionalSafeAreaInsets, insetNeed)) {
            self.additionalSafeAreaInsets = insetNeed;
        }
        if (self.rb_settingsChromeNavBar) {
            self.rb_settingsChromeNavBar.hidden = NO;
            if (!self.rb_settingsChromeNavBar.superview) {
                [self.rb_settingsChromeNavBar installInHostView:self.view];
            }
            [self.view bringSubviewToFront:self.rb_settingsChromeNavBar];
        }
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }];

    [BasicTool refreshFontsForView:self.view];

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *version = [NSString stringWithFormat:@"v%@(%@)"
                        , [[mainBundle infoDictionary] objectForKey:@"CFBundleShortVersionString"]
                        , [[mainBundle infoDictionary] objectForKey:@"CFBundleVersion"]];
    if (self.versionValueLabel) {
        self.versionValueLabel.text = version;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [UIView performWithoutAnimation:^{
        [self.navigationController setNavigationBarHidden:YES animated:NO];
        if (self.rb_settingsChromeNavBar) {
            CGFloat pt = [BasicTool getAdjustedFontSize:17.f];
            self.rb_settingsChromeNavBar.titleLabel.font = [UIFont boldSystemFontOfSize:pt];
            self.rb_settingsChromeNavBar.titleLabel.textColor = [UIColor labelColor];
        }
    }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    BOOL leavingStack = self.isMovingFromParentViewController || self.isBeingDismissed;
    BOOL coveredByChildPush = (self.navigationController != nil && !leavingStack && self.navigationController.viewControllers.lastObject != self);
    if (coveredByChildPush) {
        self.rb_settingsChromeNavBar.hidden = YES;
    }

    if (leavingStack && self.navigationController) {
        UIViewController *toVC = nil;
        if (self.transitionCoordinator) {
            toVC = [self.transitionCoordinator viewControllerForKey:UITransitionContextToViewControllerKey];
        }
        if (!toVC && self.navigationController.viewControllers.count >= 2) {
            toVC = self.navigationController.viewControllers[self.navigationController.viewControllers.count - 2];
        }
        BOOL toMore = [toVC isKindOfClass:[MoreViewController class]];
        if (!toMore) {
            [self.navigationController setNavigationBarHidden:NO animated:animated];
            if (@available(iOS 13.0, *)) {
                UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
                [appearance configureWithDefaultBackground];
                self.navigationController.navigationBar.standardAppearance = appearance;
                self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
            }
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        self.additionalSafeAreaInsets = UIEdgeInsetsZero;
    }
}

// 个人资料
- (IBAction)clickProfile:(id)sender
{
    [ViewControllerFactory goUserViewController:self.navigationController];
}

// 账号安全
- (IBAction)clickAccountSecurity:(id)sender
{
    [ViewControllerFactory goSettingsAccountSecurityViewController:self.navigationController];
}

// 朋友权限
- (IBAction)clickFriendPermission:(id)sender
{
    [ViewControllerFactory goSettingsFriendPermissionViewController:self.navigationController];
}

// 相册
- (IBAction)clickPhotos:(id)sender
{
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    [ViewControllerFactory goPhotosViewController:self.navigationController withUid:localUser.user_uid canMgr:YES];
}

// 语音介绍
- (IBAction)clickVoices:(id)sender
{
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    [ViewControllerFactory goVoicesViewController:self.navigationController withUid:localUser.user_uid canMgr:YES];
}

// 通知（入口已移至「我的」页）
- (IBAction)clickNotification:(id)sender
{
    [ViewControllerFactory goSettingsNotificationViewController:self.navigationController];
}

// 界面与显示
- (IBAction)clickDisplay:(id)sender
{
    [ViewControllerFactory goSettingsDisplayViewController:self.navigationController];
}

// 储存空间
- (IBAction)clickStorage:(id)sender
{
    [ViewControllerFactory goSettingsStorageViewController:self.navigationController];
}

// 关于我们
- (IBAction)clickAbout:(id)sender
{
    [ViewControllerFactory goAboutViewController:self.navigationController];
}

// 帮助中心
- (IBAction)clickHelp:(id)sender
{
    [ViewControllerFactory goWebViewController:RBCHAT_HELP_CN_URL title:@"帮助中心" toNav:self.navigationController];
}

// 当前版本（已移除点击功能，版本号直接显示在右侧）
- (IBAction)clickVersion:(id)sender
{
    // 不再需要点击功能
}

// 退出登录
- (IBAction)clickLogout:(id)sender
{
    //### 仿微信的弹出菜单
    [LPActionSheet showActionSheetWithTitle:@"退出后将不会收到此账号的离线消息通知。"
                          cancelButtonTitle:@"取消"    // index==0
                     destructiveButtonTitle:@"确认退出" // index==-1
                          otherButtonTitles:nil
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if(index == -1){
            // 退出当前登陆状态并跳转到登际界面（以便重新登陆）
            [MoreViewController exitAndGotoLogin:NO];
        }
    }];
}

@end
