//telegram @wz662
#import "MoreViewController.h"
#import "BasicTool.h"
#import "WebViewController.h"
#import "IMClientManager.h"
#import "AppDelegate.h"
#import "UserDefaultsToolKits.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "RBAvatarPreviewViewController.h"
#import "ViewControllerFactory.h"
#import "HcdGuideView.h"
#import "AvatarHelper.h"
#import "SDImageCache.h"
#import "LPActionSheet.h"
#import "FriendsListProvider.h"
#import "UserEntity.h"
#import "QRCodeGenerateViewController.h"
#import "QRCodeScheme.h"
#import "FavoritesViewController.h"
#import "WalletHomeViewController.h"
#import "FriendsContent.h"
#import "GroupsContent.h"
#import "MsgSummaryContent.h"
#import "UIBarButtonItem+XYMenu.h"
#import "GroupMemberViewController.h"
#import "CallsViewController.h"
#import "Default.h"

@interface MoreViewController ()

/// 「我的」Tab：自定义顶栏（白底 + 左上「我的」标题）
@property (nonatomic, strong) UIView *rb_moreBlankNavBar;
@property (nonatomic, strong) NSLayoutConstraint *rb_moreBlankNavHeightConstraint;
@property (nonatomic, strong) UILabel *rb_moreNavTitleLabel;

@end

@implementation MoreViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self initGUI];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    BOOL inNavTransition = (self.transitionCoordinator != nil);
    if (inNavTransition && self.transitionCoordinator) {
        id<UIViewControllerTransitionCoordinator> tc = self.transitionCoordinator;
        __weak typeof(self) wself = self;
        [tc animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if ([context isCancelled]) {
                return;
            }
            __strong typeof(wself) sself = wself;
            if (!sself.navigationController) {
                return;
            }
            [sself.navigationController setNavigationBarHidden:YES animated:NO];
        }];
    } else {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
    if (self.rb_moreNavTitleLabel) {
        CGFloat pt = [BasicTool getAdjustedFontSize:22.f];
        self.rb_moreNavTitleLabel.font = [UIFont systemFontOfSize:pt weight:UIFontWeightSemibold];
    }
    __weak typeof(self) wself = self;
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{
        [wself refreshDatas];
    });
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    BOOL leavingStack = self.isMovingFromParentViewController || self.isBeingDismissed;
    if (!leavingStack && self.navigationController) {
        [self.navigationController setNavigationBarHidden:NO animated:animated];
    }
}

// @override
- (void)initGUI
{
    [super initGUI];
    self.navigationItem.rightBarButtonItems = nil;
    self.navigationItem.leftBarButtonItem = nil;

    // 设置背景色（仿微信浅灰色，不再使用背景图）
    self.view.backgroundColor = HexColor(0xF0F0F0);

    if (!self.rb_moreBlankNavBar) {
        UIView *blank = [[UIView alloc] init];
        blank.translatesAutoresizingMaskIntoConstraints = NO;
        blank.backgroundColor = [UIColor whiteColor];
        blank.userInteractionEnabled = NO;
        [self.view insertSubview:blank atIndex:0];
        self.rb_moreBlankNavBar = blank;
        self.rb_moreBlankNavHeightConstraint = [blank.heightAnchor constraintEqualToConstant:64.f];
        [NSLayoutConstraint activateConstraints:@[
            [blank.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [blank.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [blank.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            self.rb_moreBlankNavHeightConstraint,
        ]];

        UILabel *titleLab = [[UILabel alloc] init];
        titleLab.translatesAutoresizingMaskIntoConstraints = NO;
        titleLab.text = NSLocalizedString(@"main_tabs_title_more", nil);
        CGFloat titlePt = [BasicTool getAdjustedFontSize:22.f];
        titleLab.font = [UIFont systemFontOfSize:titlePt weight:UIFontWeightSemibold];
        if (@available(iOS 13.0, *)) {
            titleLab.textColor = [UIColor labelColor];
        } else {
            titleLab.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
        }
        titleLab.backgroundColor = [UIColor clearColor];
        [blank addSubview:titleLab];
        self.rb_moreNavTitleLabel = titleLab;
        if (@available(iOS 15.0, *)) {
            [NSLayoutConstraint activateConstraints:@[
                [titleLab.leadingAnchor constraintEqualToAnchor:self.view.readableContentGuide.leadingAnchor],
                [titleLab.centerYAnchor constraintEqualToAnchor:blank.bottomAnchor constant:-22.f],
            ]];
        } else if (@available(iOS 11.0, *)) {
            [NSLayoutConstraint activateConstraints:@[
                [titleLab.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:12.f],
                [titleLab.centerYAnchor constraintEqualToAnchor:blank.bottomAnchor constant:-22.f],
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [titleLab.leadingAnchor constraintEqualToAnchor:blank.leadingAnchor constant:12.f],
                [titleLab.centerYAnchor constraintEqualToAnchor:blank.bottomAnchor constant:-22.f],
            ]];
        }
    }
    self.navigationItem.title = @"";
    /// 仅下移内容 44pt（与系统导航内容区一致）；勿再与「相对 safeAreaLayoutGuide 的底约束」叠加，否则顶栏会越撑越高盖住内容
    self.additionalSafeAreaInsets = UIEdgeInsetsMake(44.f, 0, 0, 0);

    
    // 头像：65×65 圆形（与 MoreViewController.xib 一致）
    self.imgUserAvater.layer.cornerRadius = 65.f * 0.5f;
    self.imgUserAvater.layer.masksToBounds = YES;

    // 为头像组件添加点击事件
    [BasicTool addFingerClick:self.imgUserAvater action:@selector(fingerTappedUserAvatar:) target:self];
    
    // 设置二维码区域点击（置于最前，避免被整块「个人信息」按钮遮挡）
    if (self.layoutQRCode) {
        [self.layoutQRCode.superview bringSubviewToFront:self.layoutQRCode];
        self.layoutQRCode.userInteractionEnabled = YES;
        [BasicTool addFingerClick:self.layoutQRCode action:@selector(gotoQRCode:) target:self];
    }
    
    // 个性签名：单行显示，起始位置在 Chat ID 下方
    if (self.btnStatus) {
        self.btnStatus.backgroundColor = [UIColor clearColor];
        self.btnStatus.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        self.btnStatus.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        self.btnStatus.titleLabel.numberOfLines = 1;
        self.btnStatus.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        self.btnStatus.titleEdgeInsets = UIEdgeInsetsZero;
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (self.rb_moreBlankNavHeightConstraint) {
        CGFloat statusH = 0;
        UIWindow *win = self.view.window;
        if (@available(iOS 11.0, *)) {
            if (win) {
                statusH = win.safeAreaInsets.top;
            } else if (self.view.superview) {
                statusH = self.view.superview.safeAreaInsets.top;
            }
        } else {
            statusH = [UIApplication sharedApplication].statusBarFrame.size.height;
        }
        self.rb_moreBlankNavHeightConstraint.constant = statusH + 44.f;
    }
}

// 点击用户头像，查看头像大图
-(void)fingerTappedUserAvatar:(UITapGestureRecognizer *)gestureRecognizer
{
    [MoreViewController showLocalUserAvatarBigImage:self];
}

// 用户本界面中的主要数据显示（建议本方法在界面每次处于前台时都被调用，这样将可使得诸如用户信息等数据在别的界面被改动时在本界面中能即时显示最新的结果）
- (void)refreshDatas
{
    // 个人信息的显示
    UserEntity * curUser = [IMClientManager sharedInstance].localUserInfo;
    [self.viewUserName setText:curUser.nickname];
    [self.viewUserId setText:[NSString stringWithFormat:@"Chat ID: %@", curUser.user_uid]];

    // 个性签名：签名内容（我的页最多 2 行，过长省略）
    if (self.btnStatus) {
        NSString *sig = [BasicTool trim:curUser.whatsUp];
        if (sig.length == 0) sig = [BasicTool trim:curUser.userDesc];
        [self.btnStatus setTitle:[NSString stringWithFormat:@"个性签名：%@", (sig.length > 0 ? sig : @"暂无")] forState:UIControlStateNormal];
        CGFloat maxW = (self.view.bounds.size.width > 0 ? self.view.bounds.size.width - 100 - 60 : 233);
        self.btnStatus.titleLabel.preferredMaxLayoutWidth = maxW;
    }

    // 尝试异步加载本地用户头像（支持视频头像播放）
    [RBAvatarView setAvatarWithFileName:curUser.userAvatarFileName uid:curUser.user_uid onImageView:self.imgUserAvater placeholder:nil];
}

- (IBAction)gotoMyProfile:(id)sender
{
    [ViewControllerFactory goUserViewController:self.navigationController];
}

// 状态
- (IBAction)gotoStatus:(id)sender
{
    // TODO: 实现状态功能
    [BasicTool showAlertInfo:@"状态功能即将上线，敬请期待！" parent:self];
}

// 钱包
- (IBAction)gotoWallet:(id)sender
{
    WalletHomeViewController *vc = [[WalletHomeViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

// 通话记录
- (IBAction)gotoCalls:(id)sender
{
    CallsViewController *vc = [[CallsViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

// 收藏
- (IBAction)gotoFavorites:(id)sender
{
    // 收藏入口：直接进入与 10001 的对话（作为收藏夹）
    [ViewControllerFactory goChatViewController:@"10001"
                                    andNickname:@"收藏夹"
                                          toNav:self.navigationController
                                  popToRootFirst:NO
                                       highlight:nil];
}

- (IBAction)gotoMoments:(id)sender
{
    // 进入朋友圈界面
    [ViewControllerFactory goMomentViewController:self.navigationController];
}

- (IBAction)gotoNotification:(id)sender
{
    [ViewControllerFactory goSettingsNotificationViewController:self.navigationController];
}

- (IBAction)gotoShareApp:(id)sender
{
    NSURL *url = [NSURL URLWithString:RBCHAT_OFFICAL_WEBSITE];
    if (url) {
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        } else {
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}

- (IBAction)gotoSettings:(id)sender
{
    // 进入设置界面
    [ViewControllerFactory goSettingsViewController:self.navigationController];
}

// 创建标题导航栏右边"+"按钮的菜单 (用于iOS 26)
- (UIMenu *)createMoresMenu_ios26 API_AVAILABLE(ios(13.0))
{
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    if (@available(iOS 14, *)) {
        UIAction *action1 = [UIAction actionWithTitle:@"添加好友" image:[UIImage imageNamed:@"main_alarms_floatmenu_adduser_ios26"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [safeSelf gotoAddFriends];
        }];
        
        UIAction *action2 = [UIAction actionWithTitle:@"创建群聊" image:[UIImage imageNamed:@"main_alarms_floatmenu_addgroup_ios26"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [safeSelf gotoCreateGroup];
        }];
        
        UIAction *action3 = [UIAction actionWithTitle:@"扫一扫" image:[UIImage imageNamed:@"main_alarms_floatmenu_scan_ios26"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [safeSelf gotoScan];
        }];
        
        UIMenu *menu = [UIMenu menuWithChildren:@[action1, action2, action3]];
        
        return menu;
    }
    
    return nil;
}

- (void)gotoAddFriends
{
    [ViewControllerFactory goFindFriendViewController:self.navigationController];
}

- (void)gotoCreateGroup
{
    [ViewControllerFactory goGroupMemberViewController:self.navigationController usedFor:USED_FOR_CREATE_GROUP gid:nil isGroupOwner:YES defaultSelectedUid:nil];
}

- (void)gotoScan
{
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    // 进入"扫一扫"界面
    [QRCodeScheme gotoQrCodeScan:self.navigationController scanComplete:^(NSString *qrResult) {
        DLogDebug(@"%@", [NSString stringWithFormat:@"2维码扫描的结果是：%@", qrResult]);
        // 开始解析2维码内容并进入相应的处理逻辑
        [QRCodeScheme processQRCodeScanResult:qrResult nav:safeSelf.navigationController view:safeSelf.view vc:safeSelf];
    }];
}

// 进入二维码界面
- (IBAction)gotoQRCode:(id)sender
{
    [ViewControllerFactory goQRCodeGenerateMyViewController:self.navigationController];
}

// 退出当前登陆状态并跳转到登际界面（以便重新登陆）
+ (void)exitAndGotoLogin:(BOOL)clearLoginName
{
    // 退出登陆时，取消"自动登陆"的开关量设置
    [UserDefaultsToolKits setAutoLogin:NO];
    if(clearLoginName) {
        // 清除默认登陆账号
        [UserDefaultsToolKits removeDefaultLoginName];
    }
    
    // 执行退出逻辑
    [APP logout:NO];
    // 并跳转到登陆界面
    [APP switchToLoginViewController];
}

// 查看用户头像大图
+ (void)showLocalUserAvatarBigImage:(UIViewController *)parent
{
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    [MoreViewController showUserAvatarBigImage:localUserInfo.user_uid avatarFileName:localUserInfo.userAvatarFileName withParent:parent];
}
// 查看用户头像大图（图片用大图浏览，视频用全屏播放）
+ (void)showUserAvatarBigImage:(NSString *)uid avatarFileName:(NSString *)af withParent:(UIViewController *)parent
{
    if ([BasicTool isStringEmpty:uid]) {
        [BasicTool showAlertInfo:@"无效的参数，无法查看头像！" parent:parent];
        return;
    }
    if ([BasicTool isStringEmpty:af]) {
        [BasicTool showAlertInfo:@"还没有设置头像！" parent:parent];
        return;
    }

    if ([FileDownloadHelper isVideoAvatarFileName:af]) {
        [BasicTool showAlertInfo:@"暂不支持视频头像预览" parent:parent];
        return;
    }

    NSString *avatarImageURL = [FileDownloadHelper getUserAvatarDownloadURLExt:YES fileName:af uid:uid];
    UIImage *image = [FileDownloadHelper getUserAvatarFromSDImageCache:avatarImageURL donotLoadFromDisk:NO];
    if (image == nil)
        [BasicTool showImageWithURL:avatarImageURL];
    else
        [BasicTool showImage:image];
}

@end
