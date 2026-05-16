//telegram @wz662
#import "AddMethodViewController.h"
#import "BasicTool.h"
#import "HttpServiceFactory.h"
#import "IMClientManager.h"
#import "UserEntity.h"
#import "MyProcessorConst.h"
#import "DDLog.h"
#import "LPActionSheet.h"
#import "UIViewController+RBPlainCustomNav.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

@interface AddMethodViewController ()

/** 6 个开关控件 */
@property (nonatomic, strong) UISwitch *swGroup;
@property (nonatomic, strong) UISwitch *swQrcode;
@property (nonatomic, strong) UISwitch *swCard;
@property (nonatomic, strong) UISwitch *swEmail;
@property (nonatomic, strong) UISwitch *swPhone;
@property (nonatomic, strong) UISwitch *swUid;

@end

@implementation AddMethodViewController

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
    
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = @"";
    self.title = @"添加我的方式";
    [self rb_installPlainCustomNavigationBarWithTitle:@"添加我的方式"];
    
    [self buildUI];
    [self refreshSwitches];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
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
    
    // ============ Section: 6 个开关项 ============
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];
    [contentView addSubview:section];
    
    [NSLayoutConstraint activateConstraints:@[
        [section.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [section.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // 开关行数据
    NSArray *items = @[
        @{@"title": @"群聊", @"key": @"group", @"action": NSStringFromSelector(@selector(switchGroupClicked:))},
        @{@"title": @"二维码", @"key": @"qrcode", @"action": NSStringFromSelector(@selector(switchQrcodeClicked:))},
        @{@"title": @"名片", @"key": @"card", @"action": NSStringFromSelector(@selector(switchCardClicked:))},
        @{@"title": @"邮箱", @"key": @"email", @"action": NSStringFromSelector(@selector(switchEmailClicked:))},
        @{@"title": @"手机号码", @"key": @"phone", @"action": NSStringFromSelector(@selector(switchPhoneClicked:))},
        @{@"title": @"UID查询", @"key": @"uid", @"action": NSStringFromSelector(@selector(switchUidClicked:))},
    ];
    
    UIView *previousRow = nil;
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *item = items[i];
        NSString *title = item[@"title"];
        NSString *key = item[@"key"];
        SEL action = NSSelectorFromString(item[@"action"]);
        
        UIView *row = [self createSwitchRowWithTitle:title key:key action:action inSection:section];
        
        [NSLayoutConstraint activateConstraints:@[
            [row.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
            [row.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
            [row.heightAnchor constraintEqualToConstant:56],
        ]];
        
        if (previousRow) {
            [row.topAnchor constraintEqualToAnchor:previousRow.bottomAnchor].active = YES;
            
            // 分隔线
            UIView *sep = [[UIView alloc] init];
            sep.translatesAutoresizingMaskIntoConstraints = NO;
            sep.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
            [section addSubview:sep];
            [NSLayoutConstraint activateConstraints:@[
                [sep.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
                [sep.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
                [sep.topAnchor constraintEqualToAnchor:previousRow.bottomAnchor],
                [sep.heightAnchor constraintEqualToConstant:0.5],
            ]];
        } else {
            [row.topAnchor constraintEqualToAnchor:section.topAnchor].active = YES;
        }
        previousRow = row;
    }
    
    if (previousRow) {
        [previousRow.bottomAnchor constraintEqualToAnchor:section.bottomAnchor].active = YES;
    }
    
    [section.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20].active = YES;
}

/// 创建单行（标题 + 开关）
- (UIView *)createSwitchRowWithTitle:(NSString *)title key:(NSString *)key action:(SEL)action inSection:(UIView *)section
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];
    [section addSubview:row];
    
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
    
    // 保存开关引用
    if ([key isEqualToString:@"group"])  self.swGroup = sw;
    if ([key isEqualToString:@"qrcode"]) self.swQrcode = sw;
    if ([key isEqualToString:@"card"])   self.swCard = sw;
    if ([key isEqualToString:@"email"])  self.swEmail = sw;
    if ([key isEqualToString:@"phone"])  self.swPhone = sw;
    if ([key isEqualToString:@"uid"])    self.swUid = sw;
    
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

#pragma mark - 刷新开关状态

- (void)refreshSwitches
{
    [self.swGroup setOn:(self.allowAddByGroup == 1) animated:NO];
    [self.swQrcode setOn:(self.allowAddByQrcode == 1) animated:NO];
    [self.swCard setOn:(self.allowAddByCard == 1) animated:NO];
    [self.swEmail setOn:(self.allowSearchByEmail == 1) animated:NO];
    [self.swPhone setOn:(self.allowSearchByPhone == 1) animated:NO];
    [self.swUid setOn:(self.allowSearchByUid == 1) animated:NO];
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

- (void)switchGroupClicked:(id)sender
{
    if (self.allowAddByGroup == 1) {
        [self showCloseConfirmWithMessage:@"关闭后，其他人将无法通过群聊添加你"
                             actionTitle:@"关闭群聊添加"
                              completion:^{
            self.allowAddByGroup = 0;
            [self refreshSwitches];
            [self savePrivacySettings];
        }];
    } else {
        self.allowAddByGroup = 1;
        [self refreshSwitches];
        [self savePrivacySettings];
    }
}

- (void)switchQrcodeClicked:(id)sender
{
    if (self.allowAddByQrcode == 1) {
        [self showCloseConfirmWithMessage:@"关闭后，其他人将无法通过二维码添加你"
                             actionTitle:@"关闭二维码添加"
                              completion:^{
            self.allowAddByQrcode = 0;
            [self refreshSwitches];
            [self savePrivacySettings];
        }];
    } else {
        self.allowAddByQrcode = 1;
        [self refreshSwitches];
        [self savePrivacySettings];
    }
}

- (void)switchCardClicked:(id)sender
{
    if (self.allowAddByCard == 1) {
        [self showCloseConfirmWithMessage:@"关闭后，其他人将无法通过名片添加你"
                             actionTitle:@"关闭名片添加"
                              completion:^{
            self.allowAddByCard = 0;
            [self refreshSwitches];
            [self savePrivacySettings];
        }];
    } else {
        self.allowAddByCard = 1;
        [self refreshSwitches];
        [self savePrivacySettings];
    }
}

- (void)switchEmailClicked:(id)sender
{
    if (self.allowSearchByEmail == 1) {
        [self showCloseConfirmWithMessage:@"关闭后，其他人将无法通过邮箱查询到你"
                             actionTitle:@"关闭邮箱查询"
                              completion:^{
            self.allowSearchByEmail = 0;
            [self refreshSwitches];
            [self savePrivacySettings];
        }];
    } else {
        self.allowSearchByEmail = 1;
        [self refreshSwitches];
        [self savePrivacySettings];
    }
}

- (void)switchPhoneClicked:(id)sender
{
    if (self.allowSearchByPhone == 1) {
        [self showCloseConfirmWithMessage:@"关闭后，其他人将无法通过手机号查询到你"
                             actionTitle:@"关闭手机号查询"
                              completion:^{
            self.allowSearchByPhone = 0;
            [self refreshSwitches];
            [self savePrivacySettings];
        }];
    } else {
        self.allowSearchByPhone = 1;
        [self refreshSwitches];
        [self savePrivacySettings];
    }
}

- (void)switchUidClicked:(id)sender
{
    if (self.allowSearchByUid == 1) {
        [self showCloseConfirmWithMessage:@"关闭后，其他人将无法通过UID查询到你"
                             actionTitle:@"关闭UID查询"
                              completion:^{
            self.allowSearchByUid = 0;
            [self refreshSwitches];
            [self savePrivacySettings];
        }];
    } else {
        self.allowSearchByUid = 1;
        [self refreshSwitches];
        [self savePrivacySettings];
    }
}

#pragma mark - 保存权限设置（全部10项一起保存）

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
    
    DDLogInfo(@"[AddMethod] 保存权限设置，settings=%@", settingsData);
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:26
                                                  andAction:33
                                                withNewData:settingsData
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                           if (sucess) {
                                                               DDLogInfo(@"[AddMethod] 权限设置保存成功");
                                                           } else {
                                                               DDLogError(@"[AddMethod] 权限设置保存失败：%@", returnValue);
                                                               [BasicTool showAlertInfo:@"保存失败，请稍后重试" parent:self];
                                                           }
                                                       });
                                                   }
                                              hudParentView:nil
                                        showLocalErrorAlert:NO
                                      completeForLocalError:nil];
}

@end
