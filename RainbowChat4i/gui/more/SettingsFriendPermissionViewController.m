//telegram @wz662
#import "SettingsFriendPermissionViewController.h"
#import "BasicTool.h"
#import "HttpServiceFactory.h"
#import "IMClientManager.h"
#import "UserEntity.h"
#import "MyProcessorConst.h"
#import "MBProgressHUD.h"
#import "EVAToolKits.h"
#import "DDLog.h"
#import "LPActionSheet.h"
#import "AddMethodViewController.h"
#import "BlacklistViewController.h"
#import "UIViewController+RBPlainCustomNav.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

@interface SettingsFriendPermissionViewController ()

/** 当前权限设置 */
@property (nonatomic, assign) int requireVerification;
@property (nonatomic, assign) int allowSearchByEmail;
@property (nonatomic, assign) int allowSearchByUid;
@property (nonatomic, assign) int allowSearchByPhone;
@property (nonatomic, assign) int allowViewAlbum;
@property (nonatomic, assign) int allowViewVoice;
@property (nonatomic, assign) int allowReadReceipt;
@property (nonatomic, assign) int allowAddByCard;
@property (nonatomic, assign) int allowAddByGroup;
@property (nonatomic, assign) int allowAddByQrcode;

/** UI 控件 */
@property (nonatomic, strong) UISwitch *switchRequireVerification;
@property (nonatomic, strong) UISwitch *switchViewAlbum;
@property (nonatomic, strong) UISwitch *switchViewVoice;
@property (nonatomic, strong) UISwitch *switchReadReceipt;

/** 是否已完成首次加载 */
@property (nonatomic, assign) BOOL hasLoadedOnce;

@end

@implementation SettingsFriendPermissionViewController

- (instancetype)init
{
    self = [super initWithNibName:nil bundle:nil];
    return self;
}

- (void)loadView
{
    self.view = [[UIView alloc] init];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self rb_installPlainCustomNavigationBarWithTitle:@"朋友权限"];

    // 初始化默认值（全部开启）
    self.requireVerification = 1;
    self.allowSearchByEmail = 1;
    self.allowSearchByUid = 1;
    self.allowSearchByPhone = 1;
    self.allowViewAlbum = 1;
    self.allowViewVoice = 1;
    self.allowReadReceipt = 1;
    self.allowAddByCard = 1;
    self.allowAddByGroup = 1;
    self.allowAddByQrcode = 1;
    
    [self buildUI];
    [self loadPrivacySettings];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self rb_plainCustomNavHostViewWillAppear:animated];

    // 从子页面返回时重新加载权限设置（跳过首次加载，因为 viewDidLoad 已经调用过）
    if (self.hasLoadedOnce) {
        [self loadPrivacySettings];
    }
    self.hasLoadedOnce = YES;
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
    self.view.backgroundColor = HexColor(0xF0F0F0);
    
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
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
    
    // ============ Section 1: 加我为朋友时需要验证 (switch) ============
    UIView *section1 = [self createSwitchRowWithTitle:@"加我为朋友时需要验证"
                                               action:@selector(switchRequireVerificationClicked:)];
    [contentView addSubview:section1];
    [NSLayoutConstraint activateConstraints:@[
        [section1.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [section1.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section1.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // ============ Section 2: 添加我的方式 (arrow) ============
    UIView *section2 = [self createArrowSectionWithItems:@[
        @{@"title": @"添加我的方式", @"action": NSStringFromSelector(@selector(clickAddMethod:))},
    ]];
    [contentView addSubview:section2];
    [NSLayoutConstraint activateConstraints:@[
        [section2.topAnchor constraintEqualToAnchor:section1.bottomAnchor constant:10],
        [section2.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section2.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // ============ Section header: 朋友权限 ============
    UIView *header = [self createSectionHeaderWithTitle:@"朋友权限"];
    [contentView addSubview:header];
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:section2.bottomAnchor],
        [header.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // ============ Section 3: 朋友权限 items (switches) ============
    UISwitch *swAlbum = nil, *swVoice = nil, *swReceipt = nil;
    UIView *row3_1 = [self createSwitchRowWithTitle:@"相册" action:@selector(clickViewAlbum:) switchOut:&swAlbum];
    UIView *row3_2 = [self createSwitchRowWithTitle:@"语音介绍" action:@selector(clickViewVoice:) switchOut:&swVoice];
    UIView *row3_3 = [self createSwitchRowWithTitle:@"已读回执" action:@selector(clickReadReceipt:) switchOut:&swReceipt];
    self.switchViewAlbum = swAlbum;
    self.switchViewVoice = swVoice;
    self.switchReadReceipt = swReceipt;
    
    UIView *section3 = [[UIView alloc] init];
    section3.translatesAutoresizingMaskIntoConstraints = NO;
    section3.backgroundColor = [UIColor whiteColor];
    [section3 addSubview:row3_1];
    [section3 addSubview:row3_2];
    [section3 addSubview:row3_3];
    
    // 分隔线 1（相册与语音介绍之间）
    UIView *sep3_1 = [[UIView alloc] init];
    sep3_1.translatesAutoresizingMaskIntoConstraints = NO;
    sep3_1.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
    [section3 addSubview:sep3_1];
    
    // 分隔线 2（语音介绍与已读回执之间）
    UIView *sep3_2 = [[UIView alloc] init];
    sep3_2.translatesAutoresizingMaskIntoConstraints = NO;
    sep3_2.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
    [section3 addSubview:sep3_2];
    
    [NSLayoutConstraint activateConstraints:@[
        [row3_1.topAnchor constraintEqualToAnchor:section3.topAnchor],
        [row3_1.leadingAnchor constraintEqualToAnchor:section3.leadingAnchor],
        [row3_1.trailingAnchor constraintEqualToAnchor:section3.trailingAnchor],
        
        [sep3_1.topAnchor constraintEqualToAnchor:row3_1.bottomAnchor],
        [sep3_1.leadingAnchor constraintEqualToAnchor:section3.leadingAnchor constant:20],
        [sep3_1.trailingAnchor constraintEqualToAnchor:section3.trailingAnchor],
        [sep3_1.heightAnchor constraintEqualToConstant:0.5],
        
        [row3_2.topAnchor constraintEqualToAnchor:row3_1.bottomAnchor],
        [row3_2.leadingAnchor constraintEqualToAnchor:section3.leadingAnchor],
        [row3_2.trailingAnchor constraintEqualToAnchor:section3.trailingAnchor],
        
        [sep3_2.topAnchor constraintEqualToAnchor:row3_2.bottomAnchor],
        [sep3_2.leadingAnchor constraintEqualToAnchor:section3.leadingAnchor constant:20],
        [sep3_2.trailingAnchor constraintEqualToAnchor:section3.trailingAnchor],
        [sep3_2.heightAnchor constraintEqualToConstant:0.5],
        
        [row3_3.topAnchor constraintEqualToAnchor:row3_2.bottomAnchor],
        [row3_3.leadingAnchor constraintEqualToAnchor:section3.leadingAnchor],
        [row3_3.trailingAnchor constraintEqualToAnchor:section3.trailingAnchor],
        
        [row3_3.bottomAnchor constraintEqualToAnchor:section3.bottomAnchor],
    ]];
    
    [contentView addSubview:section3];
    [NSLayoutConstraint activateConstraints:@[
        [section3.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [section3.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section3.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // 通讯录黑名单入口已隐藏
    [NSLayoutConstraint activateConstraints:@[
        [contentView.bottomAnchor constraintEqualToAnchor:section3.bottomAnchor constant:20],
    ]];
}

#pragma mark - UI 辅助方法

/// 创建带开关的行（通用版本，通过 switchOut 返回创建的 UISwitch 引用）
- (UIView *)createSwitchRowWithTitle:(NSString *)title action:(SEL)action switchOut:(UISwitch **)switchOut
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];
    
    // 透明按钮覆盖整行
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = [UIColor clearColor];
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
    if (switchOut) {
        *switchOut = sw;
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:56],
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

/// 创建带开关的行（向后兼容的便捷方法，用于 Section 1 "加我为朋友时需要验证"）
- (UIView *)createSwitchRowWithTitle:(NSString *)title action:(SEL)action
{
    UISwitch *sw = nil;
    UIView *row = [self createSwitchRowWithTitle:title action:action switchOut:&sw];
    self.switchRequireVerification = sw;
    return row;
}

/// 创建带箭头的 Section（多行）
- (UIView *)createArrowSectionWithItems:(NSArray<NSDictionary *> *)items
{
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];
    
    UIView *previousItem = nil;
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *itemData = items[i];
        NSString *title = itemData[@"title"];
        SEL action = NSSelectorFromString(itemData[@"action"]);
        
        UIView *itemView = [self createArrowRowWithTitle:title action:action];
        itemView.translatesAutoresizingMaskIntoConstraints = NO;
        [section addSubview:itemView];
        
        [NSLayoutConstraint activateConstraints:@[
            [itemView.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
            [itemView.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
            [itemView.heightAnchor constraintEqualToConstant:56],
        ]];
        
        if (previousItem) {
            [itemView.topAnchor constraintEqualToAnchor:previousItem.bottomAnchor].active = YES;
            
            // 分隔线
            UIView *sep = [[UIView alloc] init];
            sep.translatesAutoresizingMaskIntoConstraints = NO;
            sep.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
            [section addSubview:sep];
            [NSLayoutConstraint activateConstraints:@[
                [sep.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
                [sep.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
                [sep.topAnchor constraintEqualToAnchor:previousItem.bottomAnchor],
                [sep.heightAnchor constraintEqualToConstant:0.5],
            ]];
        } else {
            [itemView.topAnchor constraintEqualToAnchor:section.topAnchor].active = YES;
        }
        previousItem = itemView;
    }
    
    if (previousItem) {
        [previousItem.bottomAnchor constraintEqualToAnchor:section.bottomAnchor].active = YES;
    }
    
    return section;
}

/// 创建单行（标题 + 箭头）
- (UIView *)createArrowRowWithTitle:(NSString *)title action:(SEL)action
{
    UIView *itemView = [[UIView alloc] init];
    itemView.backgroundColor = [UIColor whiteColor];
    
    // 透明按钮覆盖整行
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor clearColor];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [itemView addSubview:button];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:17];
    titleLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    titleLabel.userInteractionEnabled = NO;
    [itemView addSubview:titleLabel];
    
    // 箭头
    UIImageView *arrowView = [[UIImageView alloc] init];
    arrowView.translatesAutoresizingMaskIntoConstraints = NO;
    arrowView.image = [UIImage imageNamed:@"common_list_rightarrow_icon_nor"];
    arrowView.contentMode = UIViewContentModeScaleAspectFit;
    arrowView.userInteractionEnabled = NO;
    [itemView addSubview:arrowView];
    
    [NSLayoutConstraint activateConstraints:@[
        [button.leadingAnchor constraintEqualToAnchor:itemView.leadingAnchor],
        [button.trailingAnchor constraintEqualToAnchor:itemView.trailingAnchor],
        [button.topAnchor constraintEqualToAnchor:itemView.topAnchor],
        [button.bottomAnchor constraintEqualToAnchor:itemView.bottomAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:itemView.leadingAnchor constant:20],
        [titleLabel.centerYAnchor constraintEqualToAnchor:itemView.centerYAnchor],
        [arrowView.trailingAnchor constraintEqualToAnchor:itemView.trailingAnchor constant:-16],
        [arrowView.centerYAnchor constraintEqualToAnchor:itemView.centerYAnchor],
        [arrowView.widthAnchor constraintEqualToConstant:8],
        [arrowView.heightAnchor constraintEqualToConstant:14],
    ]];
    
    return itemView;
}

/// 创建分组标题
- (UIView *)createSectionHeaderWithTitle:(NSString *)title
{
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = HexColor(0xF0F0F0);
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:14];
    label.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    [header addSubview:label];
    
    [NSLayoutConstraint activateConstraints:@[
        [header.heightAnchor constraintEqualToConstant:40],
        [label.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [label.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-8],
    ]];
    
    return header;
}

#pragma mark - 刷新UI

- (void)refreshUI
{
    [self.switchRequireVerification setOn:(self.requireVerification == 1) animated:YES];
    [self.switchViewAlbum setOn:(self.allowViewAlbum == 1) animated:YES];
    [self.switchViewVoice setOn:(self.allowViewVoice == 1) animated:YES];
    [self.switchReadReceipt setOn:(self.allowReadReceipt == 1) animated:YES];
}

#pragma mark - 关闭确认弹窗

- (void)showCloseConfirmWithMessage:(NSString *)message
                        actionTitle:(NSString *)actionTitle
                         completion:(void (^)(void))completion
{
    LPActionSheet *actionSheet = [LPActionSheet actionSheetWithTitle:message
                                                   cancelButtonTitle:@"取消"
                                              destructiveButtonTitle:actionTitle
                                                   otherButtonTitles:nil
                                                             handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == -1) {
            if (completion) {
                completion();
            }
        }
    }];
    [actionSheet show];
}

#pragma mark - 开关点击事件

- (void)switchRequireVerificationClicked:(id)sender
{
    if (self.requireVerification == 1) {
        [self showCloseConfirmWithMessage:@"关闭后，其他人添加你为好友时将不需要验证"
                             actionTitle:@"关闭添加验证"
                              completion:^{
            self.requireVerification = 0;
            [self refreshUI];
            [self savePrivacySettings];
        }];
    } else {
        self.requireVerification = 1;
        [self refreshUI];
        [self savePrivacySettings];
    }
}

#pragma mark - 箭头点击事件

- (void)clickAddMethod:(id)sender
{
    AddMethodViewController *vc = [[AddMethodViewController alloc] init];
    // 传递全部10项权限值
    vc.requireVerification = self.requireVerification;
    vc.allowSearchByEmail = self.allowSearchByEmail;
    vc.allowSearchByUid = self.allowSearchByUid;
    vc.allowSearchByPhone = self.allowSearchByPhone;
    vc.allowViewAlbum = self.allowViewAlbum;
    vc.allowViewVoice = self.allowViewVoice;
    vc.allowReadReceipt = self.allowReadReceipt;
    vc.allowAddByCard = self.allowAddByCard;
    vc.allowAddByGroup = self.allowAddByGroup;
    vc.allowAddByQrcode = self.allowAddByQrcode;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)clickBlacklist:(id)sender
{
    BlacklistViewController *vc = [[BlacklistViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)clickViewAlbum:(id)sender
{
    if (self.allowViewAlbum == 1) {
        [self showCloseConfirmWithMessage:@"关闭后，其他人将无法查看你的相册"
                             actionTitle:@"关闭查看相册"
                              completion:^{
            self.allowViewAlbum = 0;
            [self refreshUI];
            [self savePrivacySettings];
        }];
    } else {
        self.allowViewAlbum = 1;
        [self refreshUI];
        [self savePrivacySettings];
    }
}

- (void)clickViewVoice:(id)sender
{
    if (self.allowViewVoice == 1) {
        [self showCloseConfirmWithMessage:@"关闭后，其他人将无法查看你的语音介绍"
                             actionTitle:@"关闭查看语音介绍"
                              completion:^{
            self.allowViewVoice = 0;
            [self refreshUI];
            [self savePrivacySettings];
        }];
    } else {
        self.allowViewVoice = 1;
        [self refreshUI];
        [self savePrivacySettings];
    }
}

- (void)clickReadReceipt:(id)sender
{
    if (self.allowReadReceipt == 1) {
        [self showCloseConfirmWithMessage:@"关闭后，对方将不会看到消息已读状态"
                             actionTitle:@"关闭已读回执"
                              completion:^{
            self.allowReadReceipt = 0;
            [self refreshUI];
            [self savePrivacySettings];
        }];
    } else {
        self.allowReadReceipt = 1;
        [self refreshUI];
        [self savePrivacySettings];
    }
}

#pragma mark - 加载权限设置

- (void)loadPrivacySettings
{
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    if (!localUser || !localUser.user_uid) {
        DDLogError(@"加载权限设置失败：用户信息获取失败");
        [BasicTool showAlertInfo:@"用户信息获取失败" parent:self];
        return;
    }
    
    if (!localUser.token || localUser.token.length == 0) {
        DDLogError(@"加载权限设置失败：用户token为空");
        [BasicTool showAlertInfo:@"用户未登录，请先登录" parent:self];
        return;
    }
    
    DDLogInfo(@"开始加载权限设置，uid=%@", localUser.user_uid);
    
    [self showLoading:@"加载中..."];
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:26
                                                  andAction:34
                                                withNewData:@{
                                                        @"uid": localUser.user_uid
                                                    }
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                           [self hideLoading];
                                                           
                                                           if (sucess) {
                                                               DDLogInfo(@"权限设置加载成功，返回数据：%@", returnValue);
                                                               [self parsePrivacySettings:returnValue];
                                                           } else {
                                                               DDLogError(@"权限设置加载失败，返回数据：%@", returnValue);
                                                               NSString *errorMsg = @"加载权限设置失败";
                                                               if (returnValue && returnValue.length > 0) {
                                                                   errorMsg = [NSString stringWithFormat:@"加载权限设置失败：%@", returnValue];
                                                               }
                                                               [BasicTool showAlertInfo:errorMsg parent:self];
                                                               [self refreshUI];
                                                           }
                                                       });
                                                   }
                                              hudParentView:nil
                                        showLocalErrorAlert:NO
                                      completeForLocalError:nil];
}

- (void)parsePrivacySettings:(NSString *)jsonString
{
    if (!jsonString || jsonString.length == 0) {
        [self refreshUI];
        return;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSDictionary *settingsDict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
    
    if (error || ![settingsDict isKindOfClass:[NSDictionary class]]) {
        DDLogWarn(@"解析权限设置失败: %@", error);
        [self refreshUI];
        return;
    }
    
    self.requireVerification = [[settingsDict objectForKey:@"require_verification"] intValue];
    if (self.requireVerification != 0 && self.requireVerification != 1) {
        self.requireVerification = 1;
    }
    
    self.allowSearchByEmail = [[settingsDict objectForKey:@"allow_search_by_email"] intValue];
    if (self.allowSearchByEmail != 0 && self.allowSearchByEmail != 1) {
        self.allowSearchByEmail = 1;
    }
    
    self.allowSearchByUid = [[settingsDict objectForKey:@"allow_search_by_uid"] intValue];
    if (self.allowSearchByUid != 0 && self.allowSearchByUid != 1) {
        self.allowSearchByUid = 1;
    }
    
    self.allowSearchByPhone = [[settingsDict objectForKey:@"allow_search_by_phone"] intValue];
    if (self.allowSearchByPhone != 0 && self.allowSearchByPhone != 1) {
        self.allowSearchByPhone = 1;
    }
    
    self.allowViewAlbum = [[settingsDict objectForKey:@"allow_view_album"] intValue];
    if (self.allowViewAlbum != 0 && self.allowViewAlbum != 1) {
        self.allowViewAlbum = 1;
    }
    
    self.allowViewVoice = [[settingsDict objectForKey:@"allow_view_voice"] intValue];
    if (self.allowViewVoice != 0 && self.allowViewVoice != 1) {
        self.allowViewVoice = 1;
    }
    
    self.allowReadReceipt = [[settingsDict objectForKey:@"allow_read_receipt"] intValue];
    if (self.allowReadReceipt != 0 && self.allowReadReceipt != 1) {
        self.allowReadReceipt = 1;
    }
    
    self.allowAddByCard = [[settingsDict objectForKey:@"allow_add_by_card"] intValue];
    if (self.allowAddByCard != 0 && self.allowAddByCard != 1) {
        self.allowAddByCard = 1;
    }
    
    self.allowAddByGroup = [[settingsDict objectForKey:@"allow_add_by_group"] intValue];
    if (self.allowAddByGroup != 0 && self.allowAddByGroup != 1) {
        self.allowAddByGroup = 1;
    }
    
    self.allowAddByQrcode = [[settingsDict objectForKey:@"allow_add_by_qrcode"] intValue];
    if (self.allowAddByQrcode != 0 && self.allowAddByQrcode != 1) {
        self.allowAddByQrcode = 1;
    }
    
    // 缓存已读回执开关状态到 NSUserDefaults（供聊天页面读取使用）
    [[NSUserDefaults standardUserDefaults] setBool:(self.allowReadReceipt == 1) forKey:@"privacy_allow_read_receipt"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self refreshUI];
}

#pragma mark - 保存权限设置

- (void)savePrivacySettings
{
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    if (!localUser || !localUser.user_uid) {
        DDLogError(@"保存权限设置失败：用户信息获取失败");
        return;
    }
    
    if (!localUser.token || localUser.token.length == 0) {
        DDLogError(@"保存权限设置失败：用户token为空");
        [BasicTool showAlertInfo:@"用户未登录，请先登录" parent:self];
        return;
    }
    
    NSDictionary *settingsData = @{
        @"uid": localUser.user_uid,
        @"require_verification": @(self.requireVerification),
        @"allow_search_by_email": @(self.allowSearchByEmail),
        @"allow_search_by_uid": @(self.allowSearchByUid),
        @"allow_search_by_phone": @(self.allowSearchByPhone),
        @"allow_view_album": @(self.allowViewAlbum),
        @"allow_view_voice": @(self.allowViewVoice),
        @"allow_read_receipt": @(self.allowReadReceipt),
        @"allow_add_by_card": @(self.allowAddByCard),
        @"allow_add_by_group": @(self.allowAddByGroup),
        @"allow_add_by_qrcode": @(self.allowAddByQrcode)
    };
    
    DDLogInfo(@"开始保存权限设置，uid=%@, settings=%@", localUser.user_uid, settingsData);
    
    // 同步缓存已读回执开关状态到 NSUserDefaults
    [[NSUserDefaults standardUserDefaults] setBool:(self.allowReadReceipt == 1) forKey:@"privacy_allow_read_receipt"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:26
                                                  andAction:33
                                                withNewData:settingsData
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                           if (sucess) {
                                                               DDLogInfo(@"权限设置保存成功，返回数据：%@", returnValue);
                                                               if ([returnValue isEqualToString:@"1"]) {
                                                                   DDLogDebug(@"隐私权限设置成功");
                                                               } else {
                                                                   DDLogWarn(@"权限设置保存失败，返回数据：%@", returnValue);
                                                                   NSString *errorMsg = @"权限设置失败，请稍后重试";
                                                                   if (returnValue && returnValue.length > 0) {
                                                                       errorMsg = [NSString stringWithFormat:@"权限设置失败：%@", returnValue];
                                                                   }
                                                                   [BasicTool showAlertInfo:errorMsg parent:self];
                                                                   [self loadPrivacySettings];
                                                               }
                                                           } else {
                                                               DDLogError(@"权限设置保存失败，返回数据：%@", returnValue);
                                                               NSString *errorMsg = @"权限设置失败，请稍后重试";
                                                               if (returnValue && returnValue.length > 0) {
                                                                   errorMsg = [NSString stringWithFormat:@"权限设置失败：%@", returnValue];
                                                               }
                                                               [BasicTool showAlertInfo:errorMsg parent:self];
                                                               [self loadPrivacySettings];
                                                           }
                                                       });
                                                   }
                                              hudParentView:nil
                                        showLocalErrorAlert:NO
                                      completeForLocalError:nil];
}

#pragma mark - 辅助方法

- (void)showLoading:(NSString *)message
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = message;
    hud.mode = MBProgressHUDModeIndeterminate;
}

- (void)hideLoading
{
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

@end
