//telegram @wz662
#import "ChatInfoViewController.h"
#import "UserEntity.h"
#import "IMClientManager.h"
#import "BasicTool.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "ViewControllerFactory.h"
#import "MoreViewController.h"
#import "ContactViewController.h"
#import "NotificationCenterFactory.h"
#import "LPActionSheet.h"
#import "AlarmType.h"
#import "GroupInfoViewController.h"
#import "UserDefaultsToolKits.h"
#import "QueryFriendInfoAsync.h"
#import "GroupsViewController.h"
#import "MBProgressHUD.h"
#import "MsgDetailContent.h"
#import "MsgSummaryContentDTO.h"
#import "ChatBackgroundViewController.h"
#import "ClientCoreSDK.h"
#import "UIViewController+RBPlainCustomNav.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

@interface ChatInfoViewController ()
@property (nonatomic, retain) NSString *uid;
@property (nonatomic, retain) NSString *nickname;
@end

@implementation ChatInfoViewController

#pragma mark - 初始化

- (id)initWithUid:(NSString *)uid andNick:(NSString *)nickname
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.uid = uid;
        self.nickname = nickname;
    }
    return self;
}

// 兼容旧的调用方式
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withUid:(NSString *)uid andNick:(NSString *)nickname
{
    return [self initWithUid:uid andNick:nickname];
}

- (void)loadView
{
    self.view = [[UIView alloc] init];
}

#pragma mark - 生命周期

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"聊天详情";
    self.view.backgroundColor = HexColor(0xF0F0F0);
    self.navigationItem.titleView = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @"聊天详情"];

    [self buildUI];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
    [self refreshViewsData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self rb_plainCustomNavHostViewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

#pragma mark - 构建UI

- (void)buildUI
{
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    if (@available(iOS 11.0, *)) {
        scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:scrollView];
    
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];
    
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],
    ]];
    
    // ========== Section 0: 头像区域 ==========
    UIView *avatarSection = [self buildAvatarSection];
    [contentView addSubview:avatarSection];
    [NSLayoutConstraint activateConstraints:@[
        // 紧贴 safeArea 顶（自定义导航栏下沿），避免与顶栏之间出现一条灰缝
        [avatarSection.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [avatarSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [avatarSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // ========== Section 1: 查找聊天内容 ==========
    UIView *section1 = [self buildArrowSection:@[@{@"title": @"查找聊天内容", @"action": NSStringFromSelector(@selector(clickSearchHistory:))}]];
    [contentView addSubview:section1];
    [NSLayoutConstraint activateConstraints:@[
        [section1.topAnchor constraintEqualToAnchor:avatarSection.bottomAnchor constant:10],
        [section1.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section1.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // ========== Section 2: 消息免打扰 / 置顶聊天 / 提醒 ==========
    UIView *section2 = [self buildSwitchSection];
    [contentView addSubview:section2];
    [NSLayoutConstraint activateConstraints:@[
        [section2.topAnchor constraintEqualToAnchor:section1.bottomAnchor constant:10],
        [section2.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section2.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // ========== Section 3: 设置当前聊天背景 ==========
    UIView *section3 = [self buildArrowSection:@[@{@"title": @"设置当前聊天背景", @"action": NSStringFromSelector(@selector(clickChatBackground:))}]];
    [contentView addSubview:section3];
    [NSLayoutConstraint activateConstraints:@[
        [section3.topAnchor constraintEqualToAnchor:section2.bottomAnchor constant:10],
        [section3.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section3.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // ========== Section 4: 清空聊天记录 ==========
    UIView *section4 = [self buildPlainSection:@[@{@"title": @"清空聊天记录", @"action": NSStringFromSelector(@selector(clickClearHistory:))}]];
    [contentView addSubview:section4];
    [NSLayoutConstraint activateConstraints:@[
        [section4.topAnchor constraintEqualToAnchor:section3.bottomAnchor constant:10],
        [section4.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section4.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // ========== Section 5: 投诉 ==========
    UIView *section5 = [self buildArrowSection:@[@{@"title": @"投诉", @"action": NSStringFromSelector(@selector(clickComplaint:))}]];
    [contentView addSubview:section5];
    [NSLayoutConstraint activateConstraints:@[
        [section5.topAnchor constraintEqualToAnchor:section4.bottomAnchor constant:10],
        [section5.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section5.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [section5.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
    ]];
}

#pragma mark - 头像区域

- (UIView *)buildAvatarSection
{
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];
    
    // 头像
    self.imgAvadar = [[UIImageView alloc] init];
    self.imgAvadar.translatesAutoresizingMaskIntoConstraints = NO;
    self.imgAvadar.image = [UIImage imageNamed:@"default_avatar_60"];
    self.imgAvadar.contentMode = UIViewContentModeScaleAspectFill;
    self.imgAvadar.layer.cornerRadius = 28.f;
    self.imgAvadar.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.imgAvadar.layer.cornerCurve = kCACornerCurveCircular;
    }
    self.imgAvadar.userInteractionEnabled = YES;
    [section addSubview:self.imgAvadar];
    
    // 头像点击事件
    UITapGestureRecognizer *avatarTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTappedUserAvatar:)];
    [self.imgAvadar addGestureRecognizer:avatarTap];
    
    // 昵称
    self.viewNickname = [[UILabel alloc] init];
    self.viewNickname.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewNickname.font = [UIFont systemFontOfSize:11];
    self.viewNickname.textColor = [UIColor colorWithRed:0.208 green:0.216 blue:0.231 alpha:1.0];
    self.viewNickname.textAlignment = NSTextAlignmentCenter;
    [section addSubview:self.viewNickname];
    
    // 陌生人标签
    self.viewGuestFlag = [[UILabel alloc] init];
    self.viewGuestFlag.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewGuestFlag.text = @"陌";
    self.viewGuestFlag.font = [UIFont systemFontOfSize:10];
    self.viewGuestFlag.textColor = [UIColor whiteColor];
    self.viewGuestFlag.textAlignment = NSTextAlignmentCenter;
    self.viewGuestFlag.backgroundColor = [UIColor colorWithRed:0.996 green:0.639 blue:0.337 alpha:1.0];
    self.viewGuestFlag.layer.cornerRadius = 3;
    self.viewGuestFlag.layer.masksToBounds = YES;
    self.viewGuestFlag.hidden = YES;
    [section addSubview:self.viewGuestFlag];
    
    // "+" 创建群聊按钮
    UIButton *createGroupBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    createGroupBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [createGroupBtn setBackgroundImage:[UIImage imageNamed:@"jhh"] forState:UIControlStateNormal];
    [createGroupBtn setBackgroundImage:[UIImage imageNamed:@"jhh"] forState:UIControlStateHighlighted];
    [createGroupBtn addTarget:self action:@selector(clickCretaeGroup:) forControlEvents:UIControlEventTouchUpInside];
    // 与左侧头像同为 56×56，裁成圆形
    createGroupBtn.layer.cornerRadius = 28.f;
    createGroupBtn.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        createGroupBtn.layer.cornerCurve = kCACornerCurveCircular;
    }
    [section addSubview:createGroupBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [section.heightAnchor constraintEqualToConstant:120],
        
        // 头像
        [self.imgAvadar.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [self.imgAvadar.topAnchor constraintEqualToAnchor:section.topAnchor constant:18],
        [self.imgAvadar.widthAnchor constraintEqualToConstant:56],
        [self.imgAvadar.heightAnchor constraintEqualToConstant:56],
        
        // 昵称（头像下方居中）
        [self.viewNickname.centerXAnchor constraintEqualToAnchor:self.imgAvadar.centerXAnchor],
        [self.viewNickname.topAnchor constraintEqualToAnchor:self.imgAvadar.bottomAnchor constant:6],
        [self.viewNickname.widthAnchor constraintLessThanOrEqualToConstant:70],
        
        // 陌生人标签
        [self.viewGuestFlag.trailingAnchor constraintEqualToAnchor:self.viewNickname.leadingAnchor constant:-2],
        [self.viewGuestFlag.centerYAnchor constraintEqualToAnchor:self.viewNickname.centerYAnchor],
        [self.viewGuestFlag.widthAnchor constraintEqualToConstant:16],
        [self.viewGuestFlag.heightAnchor constraintEqualToConstant:14],
        
        // 创建群聊按钮
        [createGroupBtn.leadingAnchor constraintEqualToAnchor:self.imgAvadar.trailingAnchor constant:15],
        [createGroupBtn.topAnchor constraintEqualToAnchor:self.imgAvadar.topAnchor],
        [createGroupBtn.widthAnchor constraintEqualToConstant:56],
        [createGroupBtn.heightAnchor constraintEqualToConstant:56],
    ]];
    
    return section;
}

#pragma mark - 开关区域

- (UIView *)buildSwitchSection
{
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];
    
    // 消息免打扰
    UIView *row1 = [self buildSwitchRow:@"消息免打扰" switchRef:&_switchMsgTone action:@selector(switchMsgToneClicked:)];
    [section addSubview:row1];
    
    UIView *sep1 = [self buildSeparator];
    [section addSubview:sep1];
    
    // 置顶聊天
    UIView *row2 = [self buildSwitchRow:@"置顶聊天" switchRef:&_switchAlwaysTop action:@selector(switchAlwaysTopClicked:)];
    [section addSubview:row2];
    
    [NSLayoutConstraint activateConstraints:@[
        [row1.topAnchor constraintEqualToAnchor:section.topAnchor],
        [row1.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row1.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row1.heightAnchor constraintEqualToConstant:56],
        
        [sep1.topAnchor constraintEqualToAnchor:row1.bottomAnchor],
        [sep1.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [sep1.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [sep1.heightAnchor constraintEqualToConstant:0.5],
        
        [row2.topAnchor constraintEqualToAnchor:sep1.bottomAnchor],
        [row2.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row2.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row2.heightAnchor constraintEqualToConstant:56],
        
        [row2.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
    ]];
    
    return section;
}

- (UIView *)buildSwitchRow:(NSString *)title switchRef:(UISwitch *__strong *)switchRef action:(SEL)action
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];
    
    // 透明按钮覆盖整行
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:btn];
    
    // 标题
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:17];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    label.userInteractionEnabled = NO;
    [row addSubview:label];
    
    // 开关
    UISwitch *sw = [[UISwitch alloc] init];
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    sw.onTintColor = [UIColor colorWithRed:0.2039 green:0.7804 blue:0.349 alpha:1.0];
    sw.transform = CGAffineTransformMakeScale(0.9, 1);
    sw.userInteractionEnabled = NO;
    [row addSubview:sw];
    
    if (switchRef) {
        *switchRef = sw;
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [btn.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:row.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    
    return row;
}

#pragma mark - 箭头行区域

- (UIView *)buildArrowSection:(NSArray<NSDictionary *> *)items
{
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];
    
    UIView *prev = nil;
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *item = items[i];
        UIView *row = [self buildArrowRow:item[@"title"] action:NSSelectorFromString(item[@"action"])];
        [section addSubview:row];
        
        [NSLayoutConstraint activateConstraints:@[
            [row.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
            [row.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
            [row.heightAnchor constraintEqualToConstant:56],
        ]];
        
        if (prev) {
            [row.topAnchor constraintEqualToAnchor:prev.bottomAnchor].active = YES;
            UIView *sep = [self buildSeparator];
            [section addSubview:sep];
            [NSLayoutConstraint activateConstraints:@[
                [sep.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
                [sep.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
                [sep.topAnchor constraintEqualToAnchor:prev.bottomAnchor],
                [sep.heightAnchor constraintEqualToConstant:0.5],
            ]];
        } else {
            [row.topAnchor constraintEqualToAnchor:section.topAnchor].active = YES;
        }
        prev = row;
    }
    
    if (prev) {
        [prev.bottomAnchor constraintEqualToAnchor:section.bottomAnchor].active = YES;
    }
    
    return section;
}

- (UIView *)buildArrowRow:(NSString *)title action:(SEL)action
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:btn];
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:17];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    label.userInteractionEnabled = NO;
    [row addSubview:label];
    
    UIImageView *arrow = [[UIImageView alloc] init];
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.image = [UIImage imageNamed:@"common_list_rightarrow_icon_nor"];
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    arrow.userInteractionEnabled = NO;
    [row addSubview:arrow];
    
    [NSLayoutConstraint activateConstraints:@[
        [btn.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:row.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrow.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [arrow.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrow.widthAnchor constraintEqualToConstant:8],
        [arrow.heightAnchor constraintEqualToConstant:14],
    ]];
    
    return row;
}

#pragma mark - 纯文字行区域

- (UIView *)buildPlainSection:(NSArray<NSDictionary *> *)items
{
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];
    
    UIView *prev = nil;
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *item = items[i];
        UIView *row = [self buildPlainRow:item[@"title"] action:NSSelectorFromString(item[@"action"])];
        [section addSubview:row];
        
        [NSLayoutConstraint activateConstraints:@[
            [row.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
            [row.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
            [row.heightAnchor constraintEqualToConstant:56],
        ]];
        
        if (prev) {
            [row.topAnchor constraintEqualToAnchor:prev.bottomAnchor].active = YES;
        } else {
            [row.topAnchor constraintEqualToAnchor:section.topAnchor].active = YES;
        }
        prev = row;
    }
    
    if (prev) {
        [prev.bottomAnchor constraintEqualToAnchor:section.bottomAnchor].active = YES;
    }
    
    return section;
}

- (UIView *)buildPlainRow:(NSString *)title action:(SEL)action
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:btn];
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:17];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    label.userInteractionEnabled = NO;
    [row addSubview:label];
    
    [NSLayoutConstraint activateConstraints:@[
        [btn.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:row.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    
    return row;
}

#pragma mark - 分隔线

- (UIView *)buildSeparator
{
    UIView *sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
    return sep;
}

#pragma mark - 事件处理

// 点击用户头像
- (void)fingerTappedUserAvatar:(UITapGestureRecognizer *)gestureRecognizer
{
    [QueryFriendInfoAsync gotoWatchUserInfo:self.uid withInfo:nil nav:self.navigationController view:self.view vc:self];
}

// 创建群聊
- (void)clickCretaeGroup:(id)sender
{
    __weak typeof(self) safeSelf = self;
    
    if ([self isFriend]) {
        [GroupsViewController gotoCreateGroup:self.navigationController defaultSelectedUid:self.uid];
    } else {
        NSString *content = [NSString stringWithFormat:@"对方还不是你的好友，无法创建群聊。点击\"%@\"按钮进入用户资料页面，可进行加好友操作！", NSLocalizedString(@"general_ok", @"")];
        [BasicTool areYouSureAlert:NSLocalizedString(@"general_are_u_sure", @"") content:content okBtnTitle:NSLocalizedString(@"general_ok", @"") cancelBtnTitle:NSLocalizedString(@"general_cancel", @"") parent:safeSelf okHandler:^(UIAlertAction * _Nullable action) {
            [QueryFriendInfoAsync gotoWatchUserInfo:self.uid withInfo:nil nav:safeSelf.navigationController view:safeSelf.view vc:safeSelf];
        } cancelHandler:^(UIAlertAction * _Nullable action) {
        } cencelActionStyle:UIAlertActionStyleCancel];
    }
}

// 查找聊天内容
- (void)clickSearchHistory:(id)sender
{
    [ViewControllerFactory goChatSearchMenuViewController:self.navigationController
                                                 chatType:MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE
                                                   dataId:self.uid
                                              isGroupChat:NO];
}

// 消息免打扰（1008-4-38）
- (void)switchMsgToneClicked:(id)sender
{
    BOOL wasToneOpen = [UserDefaultsToolKits isChatMsgToneOpen:self.uid];
    BOOL targetMuteOn = wasToneOpen;
    NSString *luid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
    if ([BasicTool isStringEmpty:luid]) {
        [APP showToastWarn:@"未登录"];
        [self refreshMsgToneSwitch];
        return;
    }
    NSString *chatTypeStr = [self isFriend] ? @"0" : @"1";

    [UserDefaultsToolKits setChatMsgToneOpen:!wasToneOpen chatId:self.uid];
    [self refreshMsgToneSwitch];

    __weak typeof(self) safeSelf = self;
    [[HttpRestHelper sharedInstance] submitConversationMsgMuteToServer:luid partnerId:self.uid chatType:chatTypeStr muteOn:targetMuteOn complete:^(BOOL sucess, NSString *resultCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!sucess) {
                [UserDefaultsToolKits setChatMsgToneOpen:wasToneOpen chatId:safeSelf.uid];
                [safeSelf refreshMsgToneSwitch];
                [APP showToastWarn:@"免打扰设置同步失败"];
            }
        });
    } hudParentView:self.view];
}

// 置顶聊天
- (void)switchAlwaysTopClicked:(id)sender
{
    BOOL isAlwaysTopOld = [[[IMClientManager sharedInstance] getAlarmsProvider] isAlwaysTop4Single:self.uid];
    [AlarmsProvider doSetAlwaysTopNow:!isAlwaysTopOld alarmType:([self isFriend] ? AMT_friendChatMessage : AMT_guestChatMessage) dataId:self.uid title:self.viewNickname.text];
    [self refreshAlwaysTopSwitch];
}

// 设置当前聊天背景
- (void)clickChatBackground:(id)sender
{
    ChatBackgroundViewController *vc = [[ChatBackgroundViewController alloc] initWithChatId:self.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

// 清空聊天记录
- (void)clickClearHistory:(id)sender
{
    __weak typeof(self) safeSelf = self;

    NSString *content = [NSString stringWithFormat:@"确定清空和\"%@\"的所有聊天记录吗？", self.nickname];
    
    [LPActionSheet showActionSheetWithTitle:content
                          cancelButtonTitle:NSLocalizedString(@"general_cancel", @"")
                     destructiveButtonTitle:@"确认清空"
                          otherButtonTitles:nil
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
                                        if (index == -1) {
                                            [ChatInfoViewController clearHistory:([safeSelf isFriend] ? AMT_friendChatMessage : AMT_guestChatMessage) dataId:safeSelf.uid viewForHud:safeSelf.view];
                                        }
                                    }];
}

// 投诉
- (void)clickComplaint:(id)sender
{
    LPActionSheetBlock jubaoCauseActionSheetHandler = ^(LPActionSheet *actionSheet, NSInteger index) {
        if (index > 0) {
            [APP showUserDefineToast_OK:@"举报成功!"];
        }
    };
    
    [LPActionSheet showActionSheetWithTitle:@"请选择举报原因："
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"色情", @"欺诈", @"广告骚扰", @"敏感信息", @"侵权", @"赌博", @"其它"]
                                    handler:jubaoCauseActionSheetHandler];
}

#pragma mark - 刷新数据

- (void)refreshViewsData
{
    __weak typeof(self) safeSelf = self;
    
    if (self.uid != nil && self.nickname != nil) {
        
        UserEntity *friendInfo = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:self.uid];
                    
        NSString *userAvatarFileName = nil;
        NSString *nickname = self.nickname;
        BOOL isFriend = (friendInfo != nil);
        
        if (isFriend) {
            userAvatarFileName = friendInfo.userAvatarFileName;
            nickname = [friendInfo getNickNameWithRemark];
            self.viewGuestFlag.hidden = YES;
        } else {
            userAvatarFileName = [[[IMClientManager sharedInstance] getAlarmsProvider] getExtra1String:AMT_guestChatMessage dataId:self.uid];
            self.viewGuestFlag.hidden = ([BasicTool isSystemAdmin:self.uid] ? YES : NO);
        }
        
        self.viewNickname.text = nickname;
        
        // 刷新开关状态
        [self refreshMsgToneSwitch];
        [self refreshAlwaysTopSwitch];
        
        // 加载头像（支持视频头像播放）
        [RBAvatarView setAvatarWithFileName:userAvatarFileName uid:self.uid onImageView:safeSelf.imgAvadar placeholder:nil];
    } else {
        [BasicTool showAlertWarn:[NSString stringWithFormat:@"无效的数据：uid=%@, nickname=%@", self.uid, self.nickname] parent:self];
        [self doBack:YES];
        return;
    }
}

- (void)refreshMsgToneSwitch
{
    BOOL isDisturb = ![UserDefaultsToolKits isChatMsgToneOpen:self.uid];
    [self.switchMsgTone setOn:isDisturb animated:YES];
}

- (void)refreshAlwaysTopSwitch
{
    BOOL isAlwaysTop = [[[IMClientManager sharedInstance] getAlarmsProvider] isAlwaysTop4Single:self.uid];
    [self.switchAlwaysTop setOn:isAlwaysTop animated:YES];
}

- (void)doBack:(BOOL)animated
{
    [self.navigationController popViewControllerAnimated:animated];
}

- (BOOL)isFriend
{
    return (self.uid != nil
            && [[IMClientManager sharedInstance] getFriendsListProvider] != nil
            && [[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster:self.uid]);
}

#pragma mark - 静态方法

+ (void)clearHistory:(int)alarmType dataId:(NSString *)dataId viewForHud:(UIView *)v
{
    MBProgressHUD *hud = nil;
    if (v != nil) {
        hud = [MBProgressHUD showHUDAddedTo:v animated:YES];
        hud.label.text = @"处理中，请稍候..";
    }
    
    // 先调用服务端接口1008-4-22删除该会话的聊天记录（使服务端不再返回该会话的漫游消息）
    NSString *luid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    NSString *ruid = nil;
    NSString *gid = nil;
    
    if (alarmType == AMT_groupChatMessage) {
        gid = dataId;
    } else {
        ruid = dataId;
    }
    
    [[HttpRestHelper sharedInstance] submitDeleteConversationToServer:luid ruid:ruid gid:gid complete:^(BOOL sucess, NSString *resultCode) {
        // 无论服务端是否成功，都继续清理本地数据（保证本地体验）
        if (!sucess) {
            NSLog(@"【警告】服务端删除会话记录失败（dataId=%@），仍继续清理本地数据", dataId);
        }
        
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            @try {
            [AlarmsProvider clearHistoryMessages:alarmType dataId:dataId deleteLocaleDatas:YES db:nil notify:YES];
            [[[IMClientManager sharedInstance] getAlarmsProvider] updateAlarmContentAndTime:alarmType dataId:dataId newContent:nil newDate:nil needUpdateSqlite:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [BasicTool showUserDefintToast:@"清空成功" view:v atHide:nil];
            });
            } @catch (NSException *exception) {
                NSLog(@"%@", exception);
            dispatch_async(dispatch_get_main_queue(), ^{
                AlertInfo(@"清空失败，请稍后再试！");
            });
        } @finally {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [hud hideAnimated:NO];
                });
                } else {
                [hud hideAnimated:NO];
            }
        }
    });
    } hudParentView:nil];
}

+ (void)searhHistory:(UINavigationController *)nc searchResultChatType:(int)searchResultChatType dataId:(NSString *)dataId
{
    MsgSummaryContentDTO *currentSummaryResult = [[MsgSummaryContentDTO alloc] init];
    currentSummaryResult.chatType = searchResultChatType;
    currentSummaryResult.dataId = dataId;
    
    MsgDetailContent *c = [[MsgDetailContent alloc] init];
    c.msgSummaryContentDTO = currentSummaryResult;
    
    [ViewControllerFactory goSearchViewController:nc supportedSearchableContens:@[c] keyword:nil showAllResult:YES];
}

@end
