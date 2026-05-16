//telegram @wz662
#import "LoginViewController.h"
#import "AppDelegate.h"
#import "UIViewController+Ext.h"
#import "ConfigEntity.h"
#import "ClientCoreSDK.h"
#import "ChatBaseEventImpl.h"
#import "LocalDataSender.h"
#import "OnLoginProgress.h"
#import "IMClientManager.h"
#import "AlarmsProvider.h"
#import "LoginInfo2.h"
#import "HttpRestHelper.h"
#import "IMServerConnector.h"
#import "BasicTool.h"
#import "ViewControllerFactory.h"
#import "NotificationCenterFactory.h"
#import "Default.h"
#import "UserRegisterDTO.h"
#import "UserDefaultsToolKits.h"
#import "LoginInfoToSave.h"
#import "LaunchScreenWrapper.h"
#import "EVAToolKits.h"
#import "FileDownloadHelper.h"
#import "LPActionSheet.h"
#import <sys/utsname.h>


////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
////////////////////////////////////////////////////////////////////////////////////////////

@interface LoginViewController ()

// IM服务器连接逻辑封装对象
@property (nonatomic, retain) IMServerConnector *imServerConnector;
// 用于自动登陆时显示的闪屏UI(覆盖在登陆界面之上，提升自动登陆时的用户体验)
@property (nonatomic, retain) LaunchScreenWrapper *launchScreenWrapper;
/** 最近一次 beginLogin 是否为自动登录（仅手动登录成功时会标记会话列表首轮骨架） */
@property (nonatomic, assign) BOOL rb_lastBeginLoginWasAuto;

/** 登录方式（用于正常人工界面登录的情况下，不用于自动登录时） */
@property (nonatomic, retain) NSString *loginType;

/** 是否需要验证码（用于新设备登录验证） */
@property (nonatomic, assign) BOOL needVerificationCode;
/** 保存登录信息（用于需要验证码时再次登录） */
@property (nonatomic, retain) LoginInfo2 *pendingLoginInfo;
/** 服务端返回的脱敏手机号（如 "138****1234"） */
@property (nonatomic, retain) NSString *maskedPhone;

// ========== Header UI ==========
@property (nonatomic, strong) UIImageView *bgImageView;
@property (nonatomic, strong) UILabel *lblTitle;
@property (nonatomic, strong) UILabel *lblSubtitle;

// ========== Form Area ==========
@property (nonatomic, strong) UIStackView *formStack;

// --- SMS Login ---
@property (nonatomic, strong) UIView *layoutSms;
@property (nonatomic, strong) UILabel *lblCountryCode;
@property (nonatomic, strong) UITextField *loginPhone;
@property (nonatomic, strong) UIView *phoneLineView;
@property (nonatomic, strong) UITextField *loginSMS;
@property (nonatomic, strong) GetSMSButton *btnGetSMS;
@property (nonatomic, strong) UIView *smsLineView;

// --- Password Login ---
@property (nonatomic, strong) UIView *layoutPsw;
@property (nonatomic, strong) UITextField *loginName;
@property (nonatomic, strong) UIView *nameLineView;
@property (nonatomic, strong) UITextField *loginPsw;
@property (nonatomic, strong) UIButton *btnShowPassword;
@property (nonatomic, strong) UIView *pswLineView;

// --- Common ---
@property (nonatomic, strong) UIButton *btnLogin;

// ========== 输入框下方链接行（注册账号 + 忘记密码） ==========
@property (nonatomic, strong) UIView *upperLinksRow;
@property (nonatomic, strong) UIButton *btnRegister;
@property (nonatomic, strong) UIButton *btnForgetPwd;

// ========== 登录按钮下方链接行（密码登录 / 验证码登录 切换） ==========
@property (nonatomic, strong) UIView *linksRow;
@property (nonatomic, strong) UIButton *btnSwitchType;
@property (nonatomic, strong) UIButton *btnLowerForgetPwd; // 返回用户模式下在按钮下方显示的"忘记密码"
// ========== 导航返回箭头（从普通模式返回缓存用户模式） ==========
@property (nonatomic, strong) UIButton *btnBackToCache;
// ========== 右上角多语言按钮 ==========
@property (nonatomic, strong) UIButton *btnLanguage;

// ========== Bottom Area ==========
@property (nonatomic, strong) UIView *bottomContainer;
@property (nonatomic, strong) UIButton *btnAgreementCheck;
@property (nonatomic, strong) UILabel *lblVersion;
@property (nonatomic, strong) UIButton *btnOnlineService;
/** 在线客服按钮高度约束（隐藏时设为 0） */
@property (nonatomic, strong) NSLayoutConstraint *btnOnlineServiceHeightConstraint;

/** 协议是否已勾选 */
@property (nonatomic, assign) BOOL agreementChecked;

// ========== 返回用户模式 (有缓存登录记录时) ==========
@property (nonatomic, strong) UIView *returningUserHeader;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *lblAccountInfo;

// 密码表单内部行引用（用于隐藏用户名行）
@property (nonatomic, strong) UIView *pswRow;

// 约束切换
@property (nonatomic, strong) NSLayoutConstraint *formStackTopDefault;
@property (nonatomic, strong) NSLayoutConstraint *formStackTopReturning;
@property (nonatomic, strong) NSLayoutConstraint *pswRowTopDefault;
@property (nonatomic, strong) NSLayoutConstraint *pswRowTopCollapsed;

// 状态标记
@property (nonatomic, assign) BOOL hasCachedLogin;

// 缓存用户信息（用于从普通模式返回到缓存用户模式）
@property (nonatomic, retain) NSString *cachedLoginName;
@property (nonatomic, retain) NSString *cachedPhoneNum;

// ========== 账号冻结倒计时 ==========
@property (nonatomic, strong) NSTimer *freezeTimer;
@property (nonatomic, assign) NSInteger freezeRemainSeconds;

@end

/// Alert 内手机号/验证码输入框 tag（用于 UITextFieldDelegate 仅数字与长度限制）
static const NSInteger kRBLoginAlertTFResendPhone = 76002;
static const NSInteger kRBLoginAlertTFDeviceVerifyCode = 76003;


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
/////////////////////////////////////////////////////////////////////////////////////////////

@implementation LoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 默认是验证码登录（界面上默认显示验证码登录模式）
    self.loginType = LOGIN_TYPE_SMS;
    
    // 构建程序化UI
    [self buildUI];
    // 初始化界面UI设置
    [self initGUI];
    // 登陆/连接IM服务器有关的初始化工作
    [self initIMServerConnector];
    // 初始化自动登陆逻辑
    [self initAutoLogin];
    // 短信验证码相关的初始化
    [self initForSMS];

    // 注册通知：接收注册成功界面发回来的数据
    [NotificationCenterFactory registerSucessBack_ADD:self selector:@selector(showRegisterSucessData:)];
}

// "viewDidUnload:"方法已在ios6后被废弃
- (void)dealloc
{
    [self stopFreezeCountdown];
    [NotificationCenterFactory registerSucessBack_REMOVE:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [super viewWillDisappear:animated];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 构建UI（程序化布局）
/////////////////////////////////////////////////////////////////////////////////////////////

- (void)buildUI
{
    self.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.95 blue:0.97 alpha:1.0];
    
    [self buildHeaderArea];
    [self buildReturningUserHeader];
    [self buildFormArea];
    [self buildBottomArea];
    [self buildBackToCacheButton];
    [self buildLanguageButton];
}

/**
 * 构建左上角返回箭头按钮（导航栏风格），用于从普通登录模式返回缓存用户模式。
 * 默认隐藏，退出缓存用户模式后显示。
 */
- (void)buildBackToCacheButton
{
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    self.btnBackToCache = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnBackToCache.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 使用 SF Symbol "chevron.left" 作为返回箭头
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    UIImage *chevron = [UIImage systemImageNamed:@"chevron.left" withConfiguration:config];
    [self.btnBackToCache setImage:chevron forState:UIControlStateNormal];
    self.btnBackToCache.tintColor = HexColor(0x333333);
    
    // 圆形气泡背景
    self.btnBackToCache.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
    self.btnBackToCache.layer.cornerRadius = 22;
    self.btnBackToCache.clipsToBounds = YES;
    // 轻微阴影
    self.btnBackToCache.layer.masksToBounds = NO;
    self.btnBackToCache.layer.shadowColor = [UIColor blackColor].CGColor;
    self.btnBackToCache.layer.shadowOpacity = 0.1;
    self.btnBackToCache.layer.shadowOffset = CGSizeMake(0, 1);
    self.btnBackToCache.layer.shadowRadius = 3;
    
    [self.btnBackToCache addTarget:self action:@selector(doBackToReturningUserMode:) forControlEvents:UIControlEventTouchUpInside];
    self.btnBackToCache.hidden = YES; // 默认隐藏
    [self.view addSubview:self.btnBackToCache];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.btnBackToCache.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:10],
        [self.btnBackToCache.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.btnBackToCache.widthAnchor constraintEqualToConstant:44],
        [self.btnBackToCache.heightAnchor constraintEqualToConstant:44],
    ]];
}

/**
 * 构建右上角多语言切换按钮。
 */
- (void)buildLanguageButton
{
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    self.btnLanguage = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnLanguage.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 获取当前语言显示名
    [self updateLanguageButtonTitle];
    
    self.btnLanguage.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.btnLanguage setTintColor:HexColor(0x333333)];
    
    // 添加地球图标
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    UIImage *globeIcon = [UIImage systemImageNamed:@"globe" withConfiguration:config];
    [self.btnLanguage setImage:globeIcon forState:UIControlStateNormal];
    
    // 图标在左，文字在右，间距4
    self.btnLanguage.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *btnConfig = [UIButtonConfiguration plainButtonConfiguration];
        btnConfig.imagePadding = 4;
        btnConfig.contentInsets = NSDirectionalEdgeInsetsMake(8, 14, 8, 14);
        self.btnLanguage.configuration = btnConfig;
        // 重新设置字体和颜色（configuration 模式下需要用 attributedTitle）
        [self updateLanguageButtonTitle];
    } else {
        self.btnLanguage.imageEdgeInsets = UIEdgeInsetsMake(0, -2, 0, 2);
        self.btnLanguage.titleEdgeInsets = UIEdgeInsetsMake(0, 2, 0, -2);
        self.btnLanguage.contentEdgeInsets = UIEdgeInsetsMake(8, 14, 8, 14);
    }
    
    // 圆角胶囊背景
    self.btnLanguage.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
    self.btnLanguage.layer.cornerRadius = 18;
    self.btnLanguage.clipsToBounds = YES;
    self.btnLanguage.layer.masksToBounds = NO;
    self.btnLanguage.layer.shadowColor = [UIColor blackColor].CGColor;
    self.btnLanguage.layer.shadowOpacity = 0.1;
    self.btnLanguage.layer.shadowOffset = CGSizeMake(0, 1);
    self.btnLanguage.layer.shadowRadius = 3;
    
    [self.btnLanguage addTarget:self action:@selector(doSelectLanguage:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnLanguage];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.btnLanguage.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:10],
        [self.btnLanguage.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.btnLanguage.heightAnchor constraintEqualToConstant:36],
    ]];
}

/**
 * 更新多语言按钮上的文字（显示当前语言名称）。
 */
- (void)updateLanguageButtonTitle
{
    NSString *languageCode = [BasicTool getAppLanguage];
    NSString *displayName;
    
    if ([languageCode isEqualToString:@"en"]) {
        displayName = @"English";
    } else if ([languageCode isEqualToString:@"zh-Hant"]) {
        displayName = @"繁體中文";
    } else {
        displayName = @"简体中文";
    }
    
    if (@available(iOS 15.0, *)) {
        if (self.btnLanguage.configuration) {
            UIButtonConfiguration *btnConfig = self.btnLanguage.configuration;
            NSDictionary *attrs = @{
                NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightMedium],
                NSForegroundColorAttributeName: HexColor(0x333333),
            };
            btnConfig.attributedTitle = [[NSAttributedString alloc] initWithString:displayName attributes:attrs];
            self.btnLanguage.configuration = btnConfig;
            return;
        }
    }
    
    [self.btnLanguage setTitle:displayName forState:UIControlStateNormal];
}

/**
 * 更新在线客服按钮的标题文字（多语言支持）。
 */
- (void)updateOnlineServiceButtonTitle:(NSString *)title
{
    if (@available(iOS 15.0, *)) {
        if (self.btnOnlineService.configuration) {
            UIButtonConfiguration *svcBtnConfig = self.btnOnlineService.configuration;
            NSDictionary *attrs = @{
                NSFontAttributeName: [UIFont systemFontOfSize:13],
                NSForegroundColorAttributeName: HexColor(0x666666),
            };
            svcBtnConfig.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attrs];
            self.btnOnlineService.configuration = svcBtnConfig;
            return;
        }
    }
    [self.btnOnlineService setTitle:title forState:UIControlStateNormal];
}

/**
 * 点击多语言按钮，弹出从底部往上的语言选择面板。
 */
- (void)doSelectLanguage:(UIButton *)sender
{
    __weak typeof(self) weakSelf = self;
    
    [LPActionSheet showActionSheetWithTitle:@"选择语言 / Select Language"
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"简体中文", @"繁體中文", @"English"]
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index > 0) {
            NSString *languageCode = nil;
            if (index == 1) {
                languageCode = @"zh-Hans";
            } else if (index == 2) {
                languageCode = @"zh-Hant";
            } else if (index == 3) {
                languageCode = @"en";
            }
            
            if (languageCode) {
                // 保存语言设置
                [BasicTool setAppLanguage:languageCode];
                // 更新按钮文字
                [weakSelf updateLanguageButtonTitle];
                // 刷新登录页面的文字
                [weakSelf refreshLoginPageTexts];
            }
        }
    }];
}

/**
 * 切换语言后刷新登录页面上的所有文字。
 */
- (void)refreshLoginPageTexts
{
    NSString *lang = [BasicTool getAppLanguage];
    
    if ([lang isEqualToString:@"en"]) {
        self.lblTitle.text = @"Login JingChat";
        self.lblSubtitle.text = @"Unregistered phone will auto register after verification";
        [self.btnLogin setTitle:@"Login" forState:UIControlStateNormal];
        [self.btnRegister setTitle:@"Register" forState:UIControlStateNormal];
        [self.btnForgetPwd setTitle:@"Forgot Password?" forState:UIControlStateNormal];
        if ([self.loginType isEqualToString:LOGIN_TYPE_SMS]) {
            [self.btnSwitchType setTitle:@"Password Login" forState:UIControlStateNormal];
        } else {
            [self.btnSwitchType setTitle:@"SMS Login" forState:UIControlStateNormal];
        }
        [self updateOnlineServiceButtonTitle:@"Online Support"];
    } else if ([lang isEqualToString:@"zh-Hant"]) {
        self.lblTitle.text = @"登錄精聊Chat";
        self.lblSubtitle.text = @"未註冊手機驗證後即自動註冊";
        [self.btnLogin setTitle:@"登錄" forState:UIControlStateNormal];
        [self.btnRegister setTitle:@"註冊賬號" forState:UIControlStateNormal];
        [self.btnForgetPwd setTitle:@"忘記密碼？" forState:UIControlStateNormal];
        if ([self.loginType isEqualToString:LOGIN_TYPE_SMS]) {
            [self.btnSwitchType setTitle:@"密碼登錄" forState:UIControlStateNormal];
        } else {
            [self.btnSwitchType setTitle:@"驗證碼登錄" forState:UIControlStateNormal];
        }
        [self updateOnlineServiceButtonTitle:@"線上客服"];
    } else {
        self.lblTitle.text = @"登录精聊Chat";
        self.lblSubtitle.text = @"未注册手机号码验证后即自动注册";
        [self.btnLogin setTitle:@"登录" forState:UIControlStateNormal];
        [self.btnRegister setTitle:@"注册账号" forState:UIControlStateNormal];
        [self.btnForgetPwd setTitle:@"忘记密码？" forState:UIControlStateNormal];
        if ([self.loginType isEqualToString:LOGIN_TYPE_SMS]) {
            [self.btnSwitchType setTitle:@"密码登录" forState:UIControlStateNormal];
        } else {
            [self.btnSwitchType setTitle:@"验证码登录" forState:UIControlStateNormal];
        }
        [self updateOnlineServiceButtonTitle:@"在线客服"];
    }
}

- (void)buildHeaderArea
{
    // --- 全屏背景图 ---
    self.bgImageView = [[UIImageView alloc] init];
    self.bgImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgImageView.image = [UIImage imageNamed:@"main_login_form_bg_bottom32_v9_2"];
    self.bgImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.bgImageView.clipsToBounds = YES;
    [self.view addSubview:self.bgImageView];
    [self.view sendSubviewToBack:self.bgImageView];
    
    // 标题
    self.lblTitle = [[UILabel alloc] init];
    self.lblTitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblTitle.text = @"登录精聊Chat";
    self.lblTitle.font = [UIFont boldSystemFontOfSize:28];
    self.lblTitle.textColor = HexColor(0x1A1A1A);
    [self.view addSubview:self.lblTitle];
    
    // 副标题
    self.lblSubtitle = [[UILabel alloc] init];
    self.lblSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblSubtitle.text = @"未注册手机号码验证后即自动注册";
    self.lblSubtitle.font = [UIFont systemFontOfSize:14];
    self.lblSubtitle.textColor = HexColor(0x999999);
    [self.view addSubview:self.lblSubtitle];
    
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    [NSLayoutConstraint activateConstraints:@[
        // 背景图铺满全屏
        [self.bgImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.bgImageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bgImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bgImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        // 标题（安全区域顶部 + 偏移，位于背景图吉祥物左侧）
        [self.lblTitle.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.lblTitle.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:80],
        
        [self.lblSubtitle.leadingAnchor constraintEqualToAnchor:self.lblTitle.leadingAnchor],
        [self.lblSubtitle.topAnchor constraintEqualToAnchor:self.lblTitle.bottomAnchor constant:10],
    ]];
}

- (void)buildReturningUserHeader
{
    self.returningUserHeader = [[UIView alloc] init];
    self.returningUserHeader.translatesAutoresizingMaskIntoConstraints = NO;
    self.returningUserHeader.hidden = YES; // 默认隐藏，有缓存时显示
    [self.view addSubview:self.returningUserHeader];
    
    // 用户头像（圆形，100x100）
    self.avatarImageView = [[UIImageView alloc] init];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.image = [UIImage imageNamed:@"default_avatar_yuan_40"];
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.layer.cornerRadius = 50;
    self.avatarImageView.layer.borderWidth = 2.0;
    self.avatarImageView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.6].CGColor;
    [self.returningUserHeader addSubview:self.avatarImageView];
    
    // 账号标签
    self.lblAccountInfo = [[UILabel alloc] init];
    self.lblAccountInfo.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblAccountInfo.text = @"";
    self.lblAccountInfo.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.lblAccountInfo.textColor = HexColor(0x333333);
    self.lblAccountInfo.textAlignment = NSTextAlignmentCenter;
    [self.returningUserHeader addSubview:self.lblAccountInfo];
    
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.returningUserHeader.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:70],
        [self.returningUserHeader.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.returningUserHeader.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.returningUserHeader.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        
        [self.avatarImageView.topAnchor constraintEqualToAnchor:self.returningUserHeader.topAnchor],
        [self.avatarImageView.centerXAnchor constraintEqualToAnchor:self.returningUserHeader.centerXAnchor],
        [self.avatarImageView.widthAnchor constraintEqualToConstant:100],
        [self.avatarImageView.heightAnchor constraintEqualToConstant:100],
        
        [self.lblAccountInfo.topAnchor constraintEqualToAnchor:self.avatarImageView.bottomAnchor constant:15],
        [self.lblAccountInfo.centerXAnchor constraintEqualToAnchor:self.returningUserHeader.centerXAnchor],
        [self.lblAccountInfo.bottomAnchor constraintEqualToAnchor:self.returningUserHeader.bottomAnchor],
    ]];
}

- (void)buildFormArea
{
    // 使用 UIStackView 管理表单区域（hidden 的 arrangedSubview 自动折叠）
    self.formStack = [[UIStackView alloc] init];
    self.formStack.axis = UILayoutConstraintAxisVertical;
    self.formStack.spacing = 25;
    self.formStack.alignment = UIStackViewAlignmentFill;
    self.formStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.formStack];
    
    [self buildSMSForm];
    [self buildPasswordForm];
    [self buildUpperLinksRow];
    [self buildLoginButton];
    [self buildLinksRow];
    
    // 排列顺序：输入框 → 忘记密码（仅密码模式） → 登录按钮 → 注册账号+登录方式切换
    [self.formStack addArrangedSubview:self.layoutSms];
    [self.formStack addArrangedSubview:self.layoutPsw];
    [self.formStack addArrangedSubview:self.upperLinksRow];
    [self.formStack addArrangedSubview:self.btnLogin];
    [self.formStack addArrangedSubview:self.linksRow];
    
    // 保存formStack顶部约束引用，用于切换返回用户模式
    self.formStackTopDefault = [self.formStack.topAnchor constraintEqualToAnchor:self.lblSubtitle.bottomAnchor constant:80];
    self.formStackTopReturning = [self.formStack.topAnchor constraintEqualToAnchor:self.returningUserHeader.bottomAnchor constant:60];
    self.formStackTopDefault.active = YES;
    self.formStackTopReturning.active = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.formStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.formStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
    ]];
    
    // 默认：SMS模式可见，密码模式隐藏
    self.layoutPsw.hidden = YES;
}

- (void)buildSMSForm
{
    self.layoutSms = [[UIView alloc] init];
    self.layoutSms.translatesAutoresizingMaskIntoConstraints = NO;
    
    // --- 手机号输入行 ---
    UIView *phoneRow = [[UIView alloc] init];
    phoneRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.layoutSms addSubview:phoneRow];
    
    self.lblCountryCode = [[UILabel alloc] init];
    self.lblCountryCode.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblCountryCode.text = @"+86";
    self.lblCountryCode.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.lblCountryCode.textColor = HexColor(0x333333);
    [phoneRow addSubview:self.lblCountryCode];
    
    self.loginPhone = [[UITextField alloc] init];
    self.loginPhone.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginPhone.placeholder = @"输入11位手机号码";
    self.loginPhone.font = [UIFont systemFontOfSize:16];
    self.loginPhone.textColor = HexColor(0x333333);
    /// 勿用 NumberPad：系统强制数字键盘，第三方输入法无法介入；用 Default + delegate 仅允许数字
    self.loginPhone.keyboardType = UIKeyboardTypeDefault;
    self.loginPhone.delegate = self;
    self.loginPhone.returnKeyType = UIReturnKeyDone;
    [self.loginPhone addTarget:self action:@selector(E_textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [phoneRow addSubview:self.loginPhone];
    
    // 手机号下划线
    self.phoneLineView = [[UIView alloc] init];
    self.phoneLineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.phoneLineView.backgroundColor = HexColor(0xE0E0E0);
    [self.layoutSms addSubview:self.phoneLineView];
    
    // --- 验证码输入行 ---
    UIView *smsRow = [[UIView alloc] init];
    smsRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.layoutSms addSubview:smsRow];
    
    self.loginSMS = [[UITextField alloc] init];
    self.loginSMS.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginSMS.placeholder = @"输入验证码";
    self.loginSMS.font = [UIFont systemFontOfSize:16];
    self.loginSMS.textColor = HexColor(0x333333);
    self.loginSMS.keyboardType = UIKeyboardTypeDefault;
    self.loginSMS.delegate = self;
    self.loginSMS.textContentType = UITextContentTypeOneTimeCode;
    [self.loginSMS addTarget:self action:@selector(E_textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [smsRow addSubview:self.loginSMS];
    
    self.btnGetSMS = [[GetSMSButton alloc] init];
    self.btnGetSMS.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnGetSMS setTitle:@"获取验证码" forState:UIControlStateNormal];
    self.btnGetSMS.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.btnGetSMS setTitleColor:HexColor(0xC6391E) forState:UIControlStateNormal];
    [self.btnGetSMS setTitleColor:HexColor(0x999999) forState:UIControlStateDisabled];
    self.btnGetSMS.backgroundColor = [UIColor clearColor];
    // 覆盖 GetSMSButton 内部的 configureView 设置的边框
    self.btnGetSMS.layer.borderWidth = 0;
    self.btnGetSMS.layer.cornerRadius = 0;
    [smsRow addSubview:self.btnGetSMS];
    
    // 验证码下划线
    self.smsLineView = [[UIView alloc] init];
    self.smsLineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.smsLineView.backgroundColor = HexColor(0xE0E0E0);
    [self.layoutSms addSubview:self.smsLineView];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Phone row
        [phoneRow.topAnchor constraintEqualToAnchor:self.layoutSms.topAnchor],
        [phoneRow.leadingAnchor constraintEqualToAnchor:self.layoutSms.leadingAnchor],
        [phoneRow.trailingAnchor constraintEqualToAnchor:self.layoutSms.trailingAnchor],
        [phoneRow.heightAnchor constraintEqualToConstant:50],
        
        [self.lblCountryCode.leadingAnchor constraintEqualToAnchor:phoneRow.leadingAnchor],
        [self.lblCountryCode.centerYAnchor constraintEqualToAnchor:phoneRow.centerYAnchor],
        [self.lblCountryCode.widthAnchor constraintEqualToConstant:65],
        
        [self.loginPhone.leadingAnchor constraintEqualToAnchor:self.lblCountryCode.trailingAnchor constant:5],
        [self.loginPhone.trailingAnchor constraintEqualToAnchor:phoneRow.trailingAnchor],
        [self.loginPhone.topAnchor constraintEqualToAnchor:phoneRow.topAnchor],
        [self.loginPhone.bottomAnchor constraintEqualToAnchor:phoneRow.bottomAnchor],
        
        // Phone line
        [self.phoneLineView.topAnchor constraintEqualToAnchor:phoneRow.bottomAnchor],
        [self.phoneLineView.leadingAnchor constraintEqualToAnchor:self.layoutSms.leadingAnchor],
        [self.phoneLineView.trailingAnchor constraintEqualToAnchor:self.layoutSms.trailingAnchor],
        [self.phoneLineView.heightAnchor constraintEqualToConstant:0.5],
        
        // SMS code row
        [smsRow.topAnchor constraintEqualToAnchor:self.phoneLineView.bottomAnchor constant:15],
        [smsRow.leadingAnchor constraintEqualToAnchor:self.layoutSms.leadingAnchor],
        [smsRow.trailingAnchor constraintEqualToAnchor:self.layoutSms.trailingAnchor],
        [smsRow.heightAnchor constraintEqualToConstant:50],
        
        [self.loginSMS.leadingAnchor constraintEqualToAnchor:smsRow.leadingAnchor],
        [self.loginSMS.topAnchor constraintEqualToAnchor:smsRow.topAnchor],
        [self.loginSMS.bottomAnchor constraintEqualToAnchor:smsRow.bottomAnchor],
        [self.loginSMS.trailingAnchor constraintEqualToAnchor:self.btnGetSMS.leadingAnchor constant:-8],
        
        [self.btnGetSMS.trailingAnchor constraintEqualToAnchor:smsRow.trailingAnchor],
        [self.btnGetSMS.centerYAnchor constraintEqualToAnchor:smsRow.centerYAnchor],
        [self.btnGetSMS.widthAnchor constraintEqualToConstant:110],
        [self.btnGetSMS.heightAnchor constraintEqualToConstant:34],
        
        // SMS line
        [self.smsLineView.topAnchor constraintEqualToAnchor:smsRow.bottomAnchor],
        [self.smsLineView.leadingAnchor constraintEqualToAnchor:self.layoutSms.leadingAnchor],
        [self.smsLineView.trailingAnchor constraintEqualToAnchor:self.layoutSms.trailingAnchor],
        [self.smsLineView.heightAnchor constraintEqualToConstant:0.5],
        
        // layoutSms 高度由子视图撑起
        [self.smsLineView.bottomAnchor constraintEqualToAnchor:self.layoutSms.bottomAnchor],
    ]];
}

- (void)buildPasswordForm
{
    self.layoutPsw = [[UIView alloc] init];
    self.layoutPsw.translatesAutoresizingMaskIntoConstraints = NO;
    
    // --- 用户名输入框 ---
    self.loginName = [[UITextField alloc] init];
    self.loginName.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginName.placeholder = @"请输入您的手机号/UID";
    self.loginName.font = [UIFont systemFontOfSize:16];
    self.loginName.textColor = HexColor(0x333333);
    self.loginName.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.loginName.returnKeyType = UIReturnKeyDone;
    [self.loginName addTarget:self action:@selector(E_textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [self.layoutPsw addSubview:self.loginName];
    
    self.nameLineView = [[UIView alloc] init];
    self.nameLineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLineView.backgroundColor = HexColor(0xE0E0E0);
    [self.layoutPsw addSubview:self.nameLineView];
    
    // --- 密码输入行 ---
    self.pswRow = [[UIView alloc] init];
    self.pswRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.layoutPsw addSubview:self.pswRow];
    
    self.loginPsw = [[UITextField alloc] init];
    self.loginPsw.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginPsw.placeholder = @"请输入您的密码";
    self.loginPsw.font = [UIFont systemFontOfSize:16];
    self.loginPsw.textColor = HexColor(0x333333);
    self.loginPsw.secureTextEntry = YES;
    self.loginPsw.textContentType = UITextContentTypeOneTimeCode;
    self.loginPsw.returnKeyType = UIReturnKeyDone;
    [self.loginPsw addTarget:self action:@selector(E_textFieldDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [self.pswRow addSubview:self.loginPsw];
    
    self.btnShowPassword = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnShowPassword.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnShowPassword setImage:[UIImage imageNamed:@"login_showpass_off"] forState:UIControlStateNormal];
    [self.btnShowPassword setImage:[UIImage imageNamed:@"login_showpass_on"] forState:UIControlStateSelected];
    [self.btnShowPassword addTarget:self action:@selector(clickShowPassword:) forControlEvents:UIControlEventTouchUpInside];
    [self.pswRow addSubview:self.btnShowPassword];
    
    self.pswLineView = [[UIView alloc] init];
    self.pswLineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pswLineView.backgroundColor = HexColor(0xE0E0E0);
    [self.layoutPsw addSubview:self.pswLineView];
    
    // 保存可切换的约束引用（用于返回用户模式隐藏用户名行）
    self.pswRowTopDefault = [self.pswRow.topAnchor constraintEqualToAnchor:self.nameLineView.bottomAnchor constant:15];
    self.pswRowTopCollapsed = [self.pswRow.topAnchor constraintEqualToAnchor:self.layoutPsw.topAnchor];
    self.pswRowTopDefault.active = YES;
    self.pswRowTopCollapsed.active = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.loginName.topAnchor constraintEqualToAnchor:self.layoutPsw.topAnchor],
        [self.loginName.leadingAnchor constraintEqualToAnchor:self.layoutPsw.leadingAnchor],
        [self.loginName.trailingAnchor constraintEqualToAnchor:self.layoutPsw.trailingAnchor],
        [self.loginName.heightAnchor constraintEqualToConstant:50],
        
        [self.nameLineView.topAnchor constraintEqualToAnchor:self.loginName.bottomAnchor],
        [self.nameLineView.leadingAnchor constraintEqualToAnchor:self.layoutPsw.leadingAnchor],
        [self.nameLineView.trailingAnchor constraintEqualToAnchor:self.layoutPsw.trailingAnchor],
        [self.nameLineView.heightAnchor constraintEqualToConstant:0.5],
        
        [self.pswRow.leadingAnchor constraintEqualToAnchor:self.layoutPsw.leadingAnchor],
        [self.pswRow.trailingAnchor constraintEqualToAnchor:self.layoutPsw.trailingAnchor],
        [self.pswRow.heightAnchor constraintEqualToConstant:50],
        
        [self.loginPsw.leadingAnchor constraintEqualToAnchor:self.pswRow.leadingAnchor],
        [self.loginPsw.topAnchor constraintEqualToAnchor:self.pswRow.topAnchor],
        [self.loginPsw.bottomAnchor constraintEqualToAnchor:self.pswRow.bottomAnchor],
        [self.loginPsw.trailingAnchor constraintEqualToAnchor:self.btnShowPassword.leadingAnchor constant:-8],
        
        [self.btnShowPassword.trailingAnchor constraintEqualToAnchor:self.pswRow.trailingAnchor],
        [self.btnShowPassword.centerYAnchor constraintEqualToAnchor:self.pswRow.centerYAnchor],
        [self.btnShowPassword.widthAnchor constraintEqualToConstant:30],
        [self.btnShowPassword.heightAnchor constraintEqualToConstant:30],
        
        [self.pswLineView.topAnchor constraintEqualToAnchor:self.pswRow.bottomAnchor],
        [self.pswLineView.leadingAnchor constraintEqualToAnchor:self.layoutPsw.leadingAnchor],
        [self.pswLineView.trailingAnchor constraintEqualToAnchor:self.layoutPsw.trailingAnchor],
        [self.pswLineView.heightAnchor constraintEqualToConstant:0.5],
        
        // layoutPsw 高度由子视图撑起
        [self.pswLineView.bottomAnchor constraintEqualToAnchor:self.layoutPsw.bottomAnchor],
    ]];
}

- (void)buildLoginButton
{
    self.btnLogin = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnLogin.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnLogin setTitle:@"登录" forState:UIControlStateNormal];
    [self.btnLogin setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.btnLogin setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.8] forState:UIControlStateHighlighted];
    self.btnLogin.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.btnLogin.backgroundColor = HexColor(0x4CD9A5);
    self.btnLogin.layer.cornerRadius = 25;
    self.btnLogin.clipsToBounds = YES;
    [self.btnLogin addTarget:self action:@selector(signIn:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.btnLogin.heightAnchor constraintEqualToConstant:50].active = YES;
}

// 输入框下方的链接行：注册账号（左） + 忘记密码（右）
- (void)buildUpperLinksRow
{
    self.upperLinksRow = [[UIView alloc] init];
    self.upperLinksRow.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 忘记密码（仅密码登录模式下显示，右对齐）
    self.btnForgetPwd = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnForgetPwd.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnForgetPwd setTitle:@"忘记密码？" forState:UIControlStateNormal];
    [self.btnForgetPwd setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
    self.btnForgetPwd.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.btnForgetPwd addTarget:self action:@selector(doForgetPassword:) forControlEvents:UIControlEventTouchUpInside];
    [self.upperLinksRow addSubview:self.btnForgetPwd];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.upperLinksRow.heightAnchor constraintEqualToConstant:30],
        
        [self.btnForgetPwd.trailingAnchor constraintEqualToAnchor:self.upperLinksRow.trailingAnchor],
        [self.btnForgetPwd.centerYAnchor constraintEqualToAnchor:self.upperLinksRow.centerYAnchor],
    ]];
    
    // 默认隐藏（SMS模式不需要忘记密码）
    self.upperLinksRow.hidden = YES;
}

// 登录按钮下方的链接行：注册账号（左） + 密码登录/验证码登录（右）
- (void)buildLinksRow
{
    self.linksRow = [[UIView alloc] init];
    self.linksRow.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 左侧：注册账号按钮（正常模式显示，返回用户模式隐藏）
    self.btnRegister = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnRegister.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnRegister setTitle:@"注册账号" forState:UIControlStateNormal];
    [self.btnRegister setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
    self.btnRegister.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.btnRegister addTarget:self action:@selector(doRegister:) forControlEvents:UIControlEventTouchUpInside];
    [self.linksRow addSubview:self.btnRegister];
    
    // 右侧：登录方式切换按钮
    self.btnSwitchType = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnSwitchType.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnSwitchType setTitle:@"密码登录" forState:UIControlStateNormal];
    [self.btnSwitchType setTitleColor:HexColor(0x4CD9A5) forState:UIControlStateNormal];
    self.btnSwitchType.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.btnSwitchType addTarget:self action:@selector(doSwitchLoginType:) forControlEvents:UIControlEventTouchUpInside];
    [self.linksRow addSubview:self.btnSwitchType];
    
    // 忘记密码按钮（仅返回用户模式下显示，靠左，替换注册账号的位置）
    self.btnLowerForgetPwd = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnLowerForgetPwd.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnLowerForgetPwd setTitle:@"忘记密码？" forState:UIControlStateNormal];
    [self.btnLowerForgetPwd setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
    self.btnLowerForgetPwd.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.btnLowerForgetPwd addTarget:self action:@selector(doForgetPassword:) forControlEvents:UIControlEventTouchUpInside];
    self.btnLowerForgetPwd.hidden = YES; // 默认隐藏
    [self.linksRow addSubview:self.btnLowerForgetPwd];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.linksRow.heightAnchor constraintEqualToConstant:30],
        
        // 注册账号 - 左对齐
        [self.btnRegister.leadingAnchor constraintEqualToAnchor:self.linksRow.leadingAnchor],
        [self.btnRegister.centerYAnchor constraintEqualToAnchor:self.linksRow.centerYAnchor],
        
        // 切换登录方式 - 右对齐
        [self.btnSwitchType.trailingAnchor constraintEqualToAnchor:self.linksRow.trailingAnchor],
        [self.btnSwitchType.centerYAnchor constraintEqualToAnchor:self.linksRow.centerYAnchor],
        
        // 忘记密码（返回用户模式） - 左对齐
        [self.btnLowerForgetPwd.leadingAnchor constraintEqualToAnchor:self.linksRow.leadingAnchor],
        [self.btnLowerForgetPwd.centerYAnchor constraintEqualToAnchor:self.linksRow.centerYAnchor],
    ]];
}

- (void)buildBottomArea
{
    self.bottomContainer = [[UIView alloc] init];
    self.bottomContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomContainer];
    
    // --- 在线客服按钮 ---
    self.btnOnlineService = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnOnlineService.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnOnlineService setTitle:@"在线客服" forState:UIControlStateNormal];
    [self.btnOnlineService setTitleColor:HexColor(0x666666) forState:UIControlStateNormal];
    self.btnOnlineService.titleLabel.font = [UIFont systemFontOfSize:13];
    // 添加耳机图标
    UIImageSymbolConfiguration *serviceIconConfig = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightRegular];
    UIImage *serviceIcon = [UIImage systemImageNamed:@"headphones" withConfiguration:serviceIconConfig];
    [self.btnOnlineService setImage:serviceIcon forState:UIControlStateNormal];
    [self.btnOnlineService setTintColor:HexColor(0x666666)];
    self.btnOnlineService.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *svcBtnConfig = [UIButtonConfiguration plainButtonConfiguration];
        svcBtnConfig.imagePadding = 4;
        svcBtnConfig.contentInsets = NSDirectionalEdgeInsetsMake(6, 12, 6, 12);
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont systemFontOfSize:13],
            NSForegroundColorAttributeName: HexColor(0x666666),
        };
        svcBtnConfig.attributedTitle = [[NSAttributedString alloc] initWithString:@"在线客服" attributes:attrs];
        self.btnOnlineService.configuration = svcBtnConfig;
    } else {
        self.btnOnlineService.imageEdgeInsets = UIEdgeInsetsMake(0, -2, 0, 2);
        self.btnOnlineService.titleEdgeInsets = UIEdgeInsetsMake(0, 2, 0, -2);
    }
    [self.btnOnlineService addTarget:self action:@selector(doOpenOnlineService:) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomContainer addSubview:self.btnOnlineService];
    
    // --- 协议勾选行 ---
    UIView *agreementRow = [[UIView alloc] init];
    agreementRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomContainer addSubview:agreementRow];
    
    UIImageSymbolConfiguration *checkConfig = [UIImageSymbolConfiguration configurationWithPointSize:16];
    self.btnAgreementCheck = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnAgreementCheck.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnAgreementCheck addTarget:self action:@selector(doToggleAgreement:) forControlEvents:UIControlEventTouchUpInside];
    [agreementRow addSubview:self.btnAgreementCheck];
    
    // 从 NSUserDefaults 恢复之前的同意状态
    self.agreementChecked = [[NSUserDefaults standardUserDefaults] boolForKey:@"kHasAgreedPrivacyPolicy"];
    [self updateAgreementCheckUI];
    
    UILabel *lblPrefix = [[UILabel alloc] init];
    lblPrefix.translatesAutoresizingMaskIntoConstraints = NO;
    lblPrefix.text = @"我已阅读并同意";
    lblPrefix.font = [UIFont systemFontOfSize:12];
    lblPrefix.textColor = HexColor(0x999999);
    [agreementRow addSubview:lblPrefix];
    
    UIButton *btnAgreement = [UIButton buttonWithType:UIButtonTypeSystem];
    btnAgreement.translatesAutoresizingMaskIntoConstraints = NO;
    [btnAgreement setTitle:@"《用户使用协议》" forState:UIControlStateNormal];
    [btnAgreement setTitleColor:HexColor(0xC6391E) forState:UIControlStateNormal];
    btnAgreement.titleLabel.font = [UIFont systemFontOfSize:12];
    [btnAgreement addTarget:self action:@selector(doOpenAgreement:) forControlEvents:UIControlEventTouchUpInside];
    [agreementRow addSubview:btnAgreement];
    
    UIButton *btnPrivacy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnPrivacy.translatesAutoresizingMaskIntoConstraints = NO;
    [btnPrivacy setTitle:@"《隐私政策》" forState:UIControlStateNormal];
    [btnPrivacy setTitleColor:HexColor(0xC6391E) forState:UIControlStateNormal];
    btnPrivacy.titleLabel.font = [UIFont systemFontOfSize:12];
    [btnPrivacy addTarget:self action:@selector(doOpenPrivacy:) forControlEvents:UIControlEventTouchUpInside];
    [agreementRow addSubview:btnPrivacy];
    
    // --- 版本号标签 ---
    self.lblVersion = [[UILabel alloc] init];
    self.lblVersion.translatesAutoresizingMaskIntoConstraints = NO;
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *versionStr = [NSString stringWithFormat:@"v%@", [[mainBundle infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    self.lblVersion.text = versionStr;
    self.lblVersion.font = [UIFont systemFontOfSize:11];
    self.lblVersion.textColor = HexColor(0xBBBBBB);
    self.lblVersion.textAlignment = NSTextAlignmentCenter;
    [self.bottomContainer addSubview:self.lblVersion];
    
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    self.btnOnlineServiceHeightConstraint = [self.btnOnlineService.heightAnchor constraintEqualToConstant:0];
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomContainer.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-10],
        
        // 在线客服按钮 - 居中显示（注册/登录页不展示，高度置 0）
        [self.btnOnlineService.topAnchor constraintEqualToAnchor:self.bottomContainer.topAnchor],
        [self.btnOnlineService.centerXAnchor constraintEqualToAnchor:self.bottomContainer.centerXAnchor],
        self.btnOnlineServiceHeightConstraint,
        
        // 协议勾选行 - 在客服按钮下方
        [agreementRow.topAnchor constraintEqualToAnchor:self.btnOnlineService.bottomAnchor constant:6],
        [agreementRow.centerXAnchor constraintEqualToAnchor:self.bottomContainer.centerXAnchor],
        [agreementRow.heightAnchor constraintEqualToConstant:25],
        
        [self.btnAgreementCheck.leadingAnchor constraintEqualToAnchor:agreementRow.leadingAnchor],
        [self.btnAgreementCheck.centerYAnchor constraintEqualToAnchor:agreementRow.centerYAnchor],
        [self.btnAgreementCheck.widthAnchor constraintEqualToConstant:20],
        [self.btnAgreementCheck.heightAnchor constraintEqualToConstant:20],
        
        [lblPrefix.leadingAnchor constraintEqualToAnchor:self.btnAgreementCheck.trailingAnchor constant:4],
        [lblPrefix.centerYAnchor constraintEqualToAnchor:agreementRow.centerYAnchor],
        
        [btnAgreement.leadingAnchor constraintEqualToAnchor:lblPrefix.trailingAnchor],
        [btnAgreement.centerYAnchor constraintEqualToAnchor:agreementRow.centerYAnchor],
        
        [btnPrivacy.leadingAnchor constraintEqualToAnchor:btnAgreement.trailingAnchor],
        [btnPrivacy.centerYAnchor constraintEqualToAnchor:agreementRow.centerYAnchor],
        [btnPrivacy.trailingAnchor constraintEqualToAnchor:agreementRow.trailingAnchor],
        
        // 版本号 - 在协议行下方
        [self.lblVersion.topAnchor constraintEqualToAnchor:agreementRow.bottomAnchor constant:6],
        [self.lblVersion.centerXAnchor constraintEqualToAnchor:self.bottomContainer.centerXAnchor],
        [self.lblVersion.bottomAnchor constraintEqualToAnchor:self.bottomContainer.bottomAnchor],
    ]];
    // 注册/登录页不显示在线客服
    self.btnOnlineService.hidden = YES;
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 初始化
/////////////////////////////////////////////////////////////////////////////////////////////

// 初始化界面UI设置
- (void)initGUI
{
    self.title = @"登陆";
    
    // 限制输入长度
    [self.loginName addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    
    // 默认显示验证码登录模式
    [self loginTypeChangeTo:LOGIN_TYPE_SMS];
}

// 短信验证码相关的初始化
-(void)initForSMS
{
    self.loginPhone.keyboardType = UIKeyboardTypeDefault;
    self.loginSMS.keyboardType = UIKeyboardTypeDefault;
    self.loginSMS.textContentType = UITextContentTypeOneTimeCode;
    
    // 设置获取验证码功能的delegate
    self.btnGetSMS.parentVC = self;
    self.btnGetSMS.delegate = self;
    
    // 限制输入长度
    [self.loginPhone addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    [self.loginSMS addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
}

/**
 * 文本输入框输入长度限制。
 */
- (void)textFieldInputLimit:(UITextField *)textField
{
    if(textField == self.loginName) {
        [BasicTool textFieldInputLimit:textField maxLen:50];
    }
    else if(textField == self.loginPhone) {
        [BasicTool textFieldInputLimit:textField maxLen:11];
    }
    else if(textField == self.loginSMS) {
        [BasicTool textFieldInputLimit:textField maxLen:4];
    }
}

- (void)initIMServerConnector
{
    self.imServerConnector = [[IMServerConnector alloc] initWith:self];
    [self.imServerConnector initConnectToIMServer];
}

/**
 * 初始化自动登陆逻辑。
 */
- (void) initAutoLogin
{
    //初始化默认登陆用户名，之前登陆成功时会自动把最新登陆用户名记下来的
    if([self.loginName.text length] <= 0)
    {
        // 读取上次的登陆账号信息
        LoginInfoToSave *lastLoginInfo = [UserDefaultsToolKits getDefaultLoginName];
        if(lastLoginInfo != nil)
        {
            self.loginName.text = lastLoginInfo.loginName;
            self.loginPsw.text = lastLoginInfo.loginPsw;
            
            // 有缓存登录记录时，切换到返回用户模式（显示头像+手机号）
            [self switchToReturningUserMode:lastLoginInfo.loginName phoneNum:lastLoginInfo.phoneNum];
            
            // 开始自动登陆
            if(lastLoginInfo.autoLogin)
            {
                // 自动登录使用密码方式
                self.loginType = LOGIN_TYPE_PASSWORD;
                
                // 自动登陆时将显示闪屏UI，提升用户体验
                self.launchScreenWrapper = [[LaunchScreenWrapper alloc] init];
                [self.launchScreenWrapper show:self.view];
                
                // 为了在block代码中安全地使用本类"self"
                __weak typeof(self) safeSelf = self;
                [self.imServerConnector setOnLoginEndObserver:^(id observerble, id arg1) {
                    // 结束自动登陆时的闪屏显示
                    if(safeSelf.launchScreenWrapper != nil)
                        [safeSelf.launchScreenWrapper hide];
                    // 自动登录失败后保持返回用户模式（不再切换到验证码模式）
                }];
                
                // 开始登陆
                [self beginLogin:YES];
            }
        }
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 返回用户模式切换
/////////////////////////////////////////////////////////////////////////////////////////////

/**
 * 切换到返回用户模式（有缓存登录记录时显示头像+手机号+密码）。
 *
 * @param cachedLoginName 缓存的登录名（uid）
 * @param phoneNum 缓存的手机号码（可能为nil）
 */
- (void)switchToReturningUserMode:(NSString *)cachedLoginName phoneNum:(NSString *)phoneNum
{
    self.hasCachedLogin = YES;
    
    // 保存缓存数据，用于从普通模式返回
    self.cachedLoginName = cachedLoginName;
    self.cachedPhoneNum = phoneNum;
    
    // 隐藏"返回"按钮（当前已在缓存用户模式，不需要返回按钮）
    self.btnBackToCache.hidden = YES;
    
    // 显示返回用户头部，隐藏普通标题
    self.returningUserHeader.hidden = NO;
    self.lblTitle.hidden = YES;
    self.lblSubtitle.hidden = YES;
    
    // 设置账号信息显示：优先显示手机号（带+86前缀），没有手机号则直接显示uid
    if (![BasicTool isStringEmpty:phoneNum]) {
        self.lblAccountInfo.text = [NSString stringWithFormat:@"+86 %@", phoneNum];
    } else {
        self.lblAccountInfo.text = cachedLoginName;
    }
    
    // 切换formStack顶部约束
    self.formStackTopDefault.active = NO;
    self.formStackTopReturning.active = YES;
    
    // 切换到密码登录模式，隐藏用户名行
    self.loginType = LOGIN_TYPE_PASSWORD;
    self.layoutSms.hidden = YES;
    self.layoutPsw.hidden = NO;
    
    // 隐藏用户名输入和下划线
    self.loginName.hidden = YES;
    self.nameLineView.hidden = YES;
    self.pswRowTopDefault.active = NO;
    self.pswRowTopCollapsed.active = YES;
    
    // 修改密码框的placeholder
    self.loginPsw.placeholder = @"输入密码";
    
    // 预填充用户名（虽然隐藏了，但登录时需要用到）
    self.loginName.text = cachedLoginName;
    
    // 更新链接按钮
    // 上方链接行：返回用户模式下完全隐藏
    self.upperLinksRow.hidden = YES;
    
    // 下方链接行：隐藏注册账号，显示"忘记密码？"（左）和"验证码登录"（右）
    self.btnRegister.hidden = YES;
    self.btnLowerForgetPwd.hidden = NO;
    [self.btnSwitchType setTitle:@"验证码登录" forState:UIControlStateNormal];
    [self.btnSwitchType removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [self.btnSwitchType addTarget:self action:@selector(doExitReturningUserMode:) forControlEvents:UIControlEventTouchUpInside];
    
    // 将 linksRow 移到登录按钮前面（输入框下方）
    [self.formStack removeArrangedSubview:self.linksRow];
    NSUInteger btnLoginIndex = [self.formStack.arrangedSubviews indexOfObject:self.btnLogin];
    [self.formStack insertArrangedSubview:self.linksRow atIndex:btnLoginIndex];
    
    // 异步加载用户头像
    __weak typeof(self) safeSelf = self;
    [FileDownloadHelper loadUserAvatarWithUID:cachedLoginName
                                       logTag:@"LoginVC-ReturningUser"
                                     complete:^(BOOL sucess, UIImage *img) {
        if (sucess && img != nil) {
            safeSelf.avatarImageView.image = img;
        }
    } donotLoadFromDisk:NO];
    
    [self.view setNeedsLayout];
}

/**
 * 退出返回用户模式，恢复普通登录界面。
 */
- (void)switchToNormalMode
{
    self.hasCachedLogin = NO;
    
    // 隐藏返回用户头部，显示普通标题
    self.returningUserHeader.hidden = YES;
    self.lblTitle.hidden = NO;
    self.lblSubtitle.hidden = NO;
    
    // 恢复formStack顶部约束
    self.formStackTopReturning.active = NO;
    self.formStackTopDefault.active = YES;
    
    // 恢复用户名输入行
    self.loginName.hidden = NO;
    self.nameLineView.hidden = NO;
    self.pswRowTopCollapsed.active = NO;
    self.pswRowTopDefault.active = YES;
    
    // 恢复密码框的placeholder
    self.loginPsw.placeholder = @"请输入您的密码";
    
    // 如果有缓存数据，显示"返回"按钮
    if (![BasicTool isStringEmpty:self.cachedLoginName]) {
        self.btnBackToCache.hidden = NO;
    }
    
    // 恢复下方链接行：显示注册账号，隐藏"忘记密码"
    self.btnRegister.hidden = NO;
    self.btnLowerForgetPwd.hidden = YES;
    
    // 将 linksRow 恢复到登录按钮后面（正常模式下 linksRow 在按钮下方）
    [self.formStack removeArrangedSubview:self.linksRow];
    [self.formStack addArrangedSubview:self.linksRow];
    
    // 恢复登录方式切换按钮的默认行为
    [self.btnSwitchType removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [self.btnSwitchType addTarget:self action:@selector(doSwitchLoginType:) forControlEvents:UIControlEventTouchUpInside];
    
    // 切换到验证码登录模式
    [self loginTypeChangeTo:LOGIN_TYPE_SMS];
    
    [self.view setNeedsLayout];
}

/**
 * 退出返回用户模式的按钮事件（"验证码登录"）。
 */
- (void)doExitReturningUserMode:(id)sender
{
    [BasicTool hideSoftInputMethod];
    [self switchToNormalMode];
}

/**
 * "返回"按钮事件 —— 从普通登录模式返回到缓存用户模式。
 */
- (void)doBackToReturningUserMode:(id)sender
{
    [BasicTool hideSoftInputMethod];
    [self switchToReturningUserMode:self.cachedLoginName phoneNum:self.cachedPhoneNum];
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 登录事件
/////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)signIn:(id)sender
{
    // 检查是否已同意协议
    if (!self.agreementChecked) {
        [BasicTool showAlertInfo:@"请先阅读并同意用户使用协议和隐私政策" parent:self];
        return;
    }
    
    [self beginLogin:NO];
}

// "密码或短信验证码登录"切换按钮事件处理
- (IBAction)doSwitchLoginType:(id)sender
{
    [BasicTool hideSoftInputMethod];
    [self loginTypeChangeAuto];
}

// "忘记密码"按钮事件处理
- (IBAction)doForgetPassword:(id)sender
{
    [BasicTool hideSoftInputMethod];
    [ViewControllerFactory goForgetPasswordViewController:self.navigationController];
}

// "显示密码"按钮的事件处理
- (IBAction)clickShowPassword:(id)sender
{
    UIButton *b = (UIButton *)sender;
    
    // 设置选中状态
    b.selected = !b.selected;
    // 设置密码是明文还是密文显示
    self.loginPsw.secureTextEntry = !self.loginPsw.secureTextEntry;
    // 解决当切换密文secureTextEntry后，再次输入内容，明文时输入的内容自动清空
    if (self.loginPsw.secureTextEntry) {
        [self.loginPsw insertText:self.loginPsw.text];
    }
}

/**
 * 实施登陆的方法.
 */
- (void)beginLogin:(BOOL)forAutoLogin
{
    self.rb_lastBeginLoginWasAuto = forAutoLogin;

    // 验证码登录
    if([self.loginType isEqualToString: LOGIN_TYPE_SMS]) {
        NSString *loginPhone = self.loginPhone.text;
        NSString *loginSms = self.loginSMS.text;
        
        if([BasicTool isStringEmpty:loginPhone]) {
            [BasicTool showAlertWarn:@"请输入手机号码！" parent:self];
            return;
        }
        if(![BasicTool verifyChineseMainlandPhone:loginPhone]) {
            [BasicTool showAlertWarn:@"请输入正确的中国大陆手机号码！" parent:self];
            return;
        }
        if([BasicTool isStringEmpty:loginSms]) {
            [BasicTool showAlertWarn:@"请输入短信验证码！" parent:self];
            return;
        }
        
        // 提交用户登陆信息认证
        [self doLoginAuthToHTTPServer:[LoginViewController constructLoginInfo:forAutoLogin loginType:self.loginType loginName:loginPhone loginPsw:loginSms loginPswCrypt:nil]];
    }
    // 密码登录
    else {
        NSString *loginName = self.loginName.text;
        NSString *loginPsw = self.loginPsw.text;
        
        NSString *loginPswCrypt = nil;
        
        if(forAutoLogin) {
            LoginInfoToSave *lastLoginInfo = [UserDefaultsToolKits getDefaultLoginName];
            if(lastLoginInfo != nil)
            {
                loginPswCrypt = lastLoginInfo.loginPswCrypt;
            }
            
            DDLogDebug(@"################# 自动登录情况下，已读取出loginPswCrypt=%@", loginPswCrypt);
        }
        
        //** 登陆名的非空验证
        if ([loginName length] == 0)
        {
            [APP showToastWarn:@"请输入登陆名！"];
            return;
        }

        //** 登陆密码的非空验证
        if ((!forAutoLogin && [BasicTool isStringEmpty:loginPsw]) || (forAutoLogin && [BasicTool isStringEmpty:loginPswCrypt]))
        {
            [APP showToastWarn:@"请输入登密码！"];
            return;
        }

        // 登陆名有效性检查
        if(![BasicTool isFullNumber:loginName] && ![BasicTool isValidEmail:loginName])
        {
            [APP showToastWarn:@"请输入合法的账号（目前只允许用户ID号或邮箱登陆）！"];
            return;
        }
        
        // 提交用户登陆信息认证
        [self doLoginAuthToHTTPServer:[LoginViewController constructLoginInfo:forAutoLogin loginType:self.loginType loginName:loginName loginPsw:loginPsw loginPswCrypt:loginPswCrypt]];
    }
}

- (void)doLoginAuthToHTTPServer:(LoginInfo2 *)loginInfo
{
    [[IMClientManager sharedInstance] initMobileIMSDK];

    // 为了在block代码中安全地使用本类"self"
    __weak typeof(self) safeSelf = self;
    
    void (^completeForLocalError)(NSString *) = ^(NSString *errorLog) {
        if(safeSelf.launchScreenWrapper != nil)
            [safeSelf.launchScreenWrapper hide];
    };
    
    [[HttpRestHelper sharedInstance] submitLoginToServerV2:loginInfo complete:^(BOOL sucess, NSDictionary *retMap) {
        if(sucess)
        {
            if(retMap != nil)
            {
                NSString *userInfoJson = [retMap objectForKey:@"authed_info"];
                if(userInfoJson != nil)
                {
                    UserEntity *userInfo = [EVAToolKits fromJSON:userInfoJson withClazz:UserEntity.class];
                    if(userInfo != nil)
                    {
                        NSLog(@">> 登陆完成，服务端返回的个人信息：nickname=%@,user_mail=%@,user_uid=%@,user_sex=%@,register_time=%@...."
                              , [userInfo nickname], [userInfo user_mail], [userInfo user_uid], [userInfo user_sex], [userInfo register_time]);
                        
                        [IMClientManager sharedInstance].localUserInfo = userInfo;

                        [UserDefaultsToolKits saveDefaultLoginName:[LoginInfoToSave initWith:userInfo.user_uid
                                                                                             psw:[loginInfo isSMSLogin] ? nil : loginInfo.loginPsw
                                                                                        pswCrypt:userInfo.userPsw
                                                                                           phone:userInfo.phoneNum]];
                        [self.imServerConnector doLoginIMServer:userInfo.user_uid andToken:userInfo.token];
                    }
                    else
                    {
                        [BasicTool showAlertError:NSLocalizedString(@"login_form_error_psw_message", @"") parent:safeSelf];
                        if(safeSelf.launchScreenWrapper != nil)
                            [safeSelf.launchScreenWrapper hide];
                    }
                }
                else
                {
                    NSString *authedCode = [retMap objectForKey:@"authed_code"];
                    NSString *authedCodeDesc = @"";
                    if([@"-1" isEqualToString:authedCode]) {
                        authedCodeDesc = @"应用密钥无效，登录失败，请联系管理员！";
                    }
                    else if([@"-2" isEqualToString:authedCode]) {
                        authedCodeDesc = @"该手机号尚未注册，请先注册账号！";
                    }
                    else if([@"-3" isEqualToString:authedCode]) {
                        authedCodeDesc = @"短信验证码无效，请重新输入！";
                    }
                    else if([@"-4" isEqualToString:authedCode]) {
                        authedCodeDesc = @"短信验证码已过期，请重新获取！";
                    }
                    else if([@"-5" isEqualToString:authedCode]) {
                        authedCodeDesc = @"手机号格式不正确，请检查后重试！";
                    }
                    else if([@"-6" isEqualToString:authedCode]) {
                        NSNumber *remainingAttempts = [retMap objectForKey:@"remaining_attempts"];
                        if (remainingAttempts != nil) {
                            authedCodeDesc = [NSString stringWithFormat:@"密码错误，还可尝试 %@ 次", remainingAttempts];
                        } else {
                            authedCodeDesc = @"账号不存在或密码错误，登录失败，请稍后再试！";
                        }
                    }
                    else if([@"-7" isEqualToString:authedCode]) {
                        // 新设备登录：服务端已自动发送验证码短信，直接弹出输入框
                        safeSelf.needVerificationCode = YES;
                        safeSelf.pendingLoginInfo = loginInfo;
                        safeSelf.maskedPhone = [retMap objectForKey:@"masked_phone"];
                        NSLog(@"【登录】新设备验证触发，服务端已自动发送验证码，masked_phone=%@", safeSelf.maskedPhone);
                        [safeSelf showVerificationCodeInputAlert];
                        return;
                    }
                    else if([@"-8" isEqualToString:authedCode]) {
                        authedCodeDesc = @"验证码无效或已过期，请重新输入！";
                        // 重新弹出验证码输入框让用户重试
                        if (safeSelf.pendingLoginInfo) {
                            [BasicTool showAlertInfo:authedCodeDesc parent:safeSelf];
                            [safeSelf showVerificationCodeInputAlert];
                            return;
                        }
                    }
                    else if([@"-9" isEqualToString:authedCode]) {
                        NSNumber *freezeSeconds = [retMap objectForKey:@"freeze_remain_seconds"];
                        NSInteger seconds = [freezeSeconds integerValue];
                        if (seconds <= 0) seconds = 300; // 默认5分钟
                        NSInteger minutes = (seconds + 59) / 60; // 向上取整
                        authedCodeDesc = [NSString stringWithFormat:@"账号已冻结，请 %ld 分钟后再试", (long)minutes];
                        
                        // 禁用登录按钮并启动倒计时
                        [safeSelf startFreezeCountdown:seconds];
                        
                        [BasicTool showAlertInfo:authedCodeDesc parent:safeSelf];
                        if(safeSelf.launchScreenWrapper != nil)
                            [safeSelf.launchScreenWrapper hide];
                        return;
                    }
                    else {
                        authedCodeDesc = [NSString stringWithFormat:@"未知错误(错误码:%@)，登录失败，请稍后再试！", authedCode];
                    }

                    [BasicTool showAlertInfo:authedCodeDesc parent:safeSelf];
                    if(safeSelf.launchScreenWrapper != nil)
                        [safeSelf.launchScreenWrapper hide];
                }
            }
            else
            {
                [BasicTool showAlertError:@"服务器响应异常，接口返回result.retrunValue是空，登录失败，请稍后再试！" parent:safeSelf];
                if(safeSelf.launchScreenWrapper != nil)
                    [safeSelf.launchScreenWrapper hide];
            }
        }
        else
        {
            [BasicTool showAlertError:NSLocalizedString(@"general_http_reponse_exception", @"") parent:safeSelf];
            if(safeSelf.launchScreenWrapper != nil)
                [safeSelf.launchScreenWrapper hide];
        }
    } hudParentView:self.view showLocalErrorAlert:YES completeForLocalError:completeForLocalError];
}

+ (LoginInfo2 *)constructLoginInfo:(BOOL)forAutoLogin loginType:(NSString *)loginType loginName:(NSString *)loginName loginPsw:(NSString *)loginPsw loginPswCrypt:(NSString *)loginPswCrypt
{
    LoginInfo2 *ai = [[LoginInfo2 alloc] init];
    ai.loginType = loginType;
    ai.loginName = loginName;
    ai.loginPsw = loginPsw;
    ai.clientVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    NSString *deviceInfo = [LoginViewController getDeviceInfoString];
    ai.deviceInfo = deviceInfo;
    
    ai.osType = @"1";
    ai.deviceID = [UserDefaultsToolKits getDeviceTokenForPush];
    // 可选：稳定设备 ID（IDFV），供服务端新设备判断时优先识别同一设备
    NSString *idfv = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (idfv && idfv.length > 0) {
        ai.hardware_id = idfv;
    }
    ai.appKey = APPKey;
    ai.loginPswCrypt = loginPswCrypt;

    return ai;
}

// 获取设备信息字符串
+ (NSString *)getDeviceInfoString
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    NSDictionary *deviceNames = @{
        @"iPhone14,2": @"iPhone 13 Pro",
        @"iPhone14,3": @"iPhone 13 Pro Max",
        @"iPhone14,4": @"iPhone 13 mini",
        @"iPhone14,5": @"iPhone 13",
        @"iPhone15,2": @"iPhone 14 Pro",
        @"iPhone15,3": @"iPhone 14 Pro Max",
        @"iPhone15,4": @"iPhone 14 Plus",
        @"iPhone15,5": @"iPhone 14",
        @"iPhone16,1": @"iPhone 15 Pro",
        @"iPhone16,2": @"iPhone 15 Pro Max",
        @"iPhone16,3": @"iPhone 15 Plus",
        @"iPhone16,4": @"iPhone 15",
        @"iPhone17,1": @"iPhone 16 Pro",
        @"iPhone17,2": @"iPhone 16 Pro Max",
        @"iPhone17,3": @"iPhone 16 Plus",
        @"iPhone17,4": @"iPhone 16",
    };
    
    NSString *friendlyName = [deviceNames objectForKey:deviceModel];
    if (!friendlyName) {
        friendlyName = deviceModel ?: @"iPhone";
    }
    
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
    return [NSString stringWithFormat:@"%@ iOS %@", friendlyName, systemVersion];
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UI切换逻辑
/////////////////////////////////////////////////////////////////////////////////////////////

/**
 * 切换到指定的登录类型。
 */
- (void)loginTypeChangeTo:(NSString *)toLoginType
{
    self.loginType = toLoginType;
    
    // 如果处于返回用户模式，不走普通的切换逻辑
    if (self.hasCachedLogin) {
        return;
    }
    
    if([toLoginType isEqualToString:LOGIN_TYPE_PASSWORD]) {
        self.layoutSms.hidden = YES;
        self.layoutPsw.hidden = NO;
        
        // 确保用户名行可见（非返回用户模式）
        self.loginName.hidden = NO;
        self.nameLineView.hidden = NO;
        self.pswRowTopCollapsed.active = NO;
        self.pswRowTopDefault.active = YES;
        self.loginPsw.placeholder = @"请输入您的密码";
        
        // 更新登录方式切换按钮
        [self.btnSwitchType setTitle:@"验证码登录" forState:UIControlStateNormal];
        
        // 密码登录模式：显示忘记密码行（在输入框和登录按钮之间）
        self.upperLinksRow.hidden = NO;
        
        // linksRow 中：注册账号（左）+ 验证码登录（右）
        self.btnRegister.hidden = NO;
        
    } else if([toLoginType isEqualToString:LOGIN_TYPE_SMS]) {
        self.layoutPsw.hidden = YES;
        self.layoutSms.hidden = NO;
        
        // 更新登录方式切换按钮
        [self.btnSwitchType setTitle:@"密码登录" forState:UIControlStateNormal];
        
        // 验证码登录模式：隐藏忘记密码行
        self.upperLinksRow.hidden = YES;
        
        // linksRow 中：注册账号（左）+ 密码登录（右）
        self.btnRegister.hidden = NO;
    }
}

/**
 * 自动切换"密码"和"验证码"登录。
 */
- (void)loginTypeChangeAuto
{
    if([self.loginType isEqualToString:LOGIN_TYPE_PASSWORD]) {
        [self loginTypeChangeTo:LOGIN_TYPE_SMS];
    } else if ([self.loginType isEqualToString:LOGIN_TYPE_SMS]) {
        [self loginTypeChangeTo:LOGIN_TYPE_PASSWORD];
    }
}

// 用于将注册成功后将注册信息显示在登陆界面上，并自动静默登录
- (void)showRegisterSucessData:(NSNotification*)notification
{
    UserRegisterDTO *userRegisterDTO = (UserRegisterDTO *)notification.object;

    DDLogDebug(@"################# back to login userRegisterDTO=%@", userRegisterDTO);

    if(userRegisterDTO != nil)
    {
        // 如果处于返回用户模式，先退出
        if (self.hasCachedLogin) {
            [self switchToNormalMode];
        }
        
        self.loginName.text = userRegisterDTO.user_uid;
        self.loginPsw.text = userRegisterDTO.user_psw;
        self.loginType = LOGIN_TYPE_PASSWORD;
        
        // 确保协议已勾选（注册时已同意过）
        if (!self.agreementChecked) {
            self.agreementChecked = YES;
            [self updateAgreementCheckUI];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kHasAgreedPrivacyPolicy"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        // 注册成功后自动静默登录
        [self beginLogin:NO];
    }
}

// "注册"按钮事件处理
- (void)doRegister:(id)sender
{
    [BasicTool hideSoftInputMethod];
    [ViewControllerFactory goRegisterViewController:self.navigationController needSMS:YES phone:nil sms:nil];
}

/**
 * 新设备验证流程:
 * 服务端检测到新设备时已自动发送短信验证码，前端收到 -7 后直接弹出验证码输入框。
 * 用户输入验证码后带 deviceVerifyCode 重新登录。
 * 如用户未收到验证码，可点击"重新发送"手动触发。
 */
- (void)showVerificationCodeInputAlert
{
    NSString *maskedPhoneDisplay = self.maskedPhone ?: @"您的手机";
    NSString *message = [NSString stringWithFormat:@"检测到新设备登录，验证码已发送至 %@\n请输入收到的短信验证码（10分钟内有效）", maskedPhoneDisplay];
    
    UIAlertController *codeAlert = [UIAlertController alertControllerWithTitle:@"新设备验证"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
    
    [codeAlert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"请输入验证码";
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.delegate = self;
        textField.tag = kRBLoginAlertTFDeviceVerifyCode;
    }];
    
    __weak typeof(self) safeSelf = self;
    
    // 确定按钮：带验证码重新登录
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
        UITextField *codeField = codeAlert.textFields.firstObject;
        NSString *verifyCode = [BasicTool trim:codeField.text];
        
        if ([BasicTool isStringEmpty:verifyCode]) {
            [BasicTool showAlertInfo:@"请输入验证码！" parent:safeSelf];
            return;
        }
        
        if (safeSelf.pendingLoginInfo) {
            NSLog(@"【新设备验证】用户输入验证码: %@，准备重新登录", verifyCode);
            safeSelf.pendingLoginInfo.deviceVerifyCode = verifyCode;
            [safeSelf doLoginAuthToHTTPServer:safeSelf.pendingLoginInfo];
        }
    }];
    
    // 重新发送按钮：让用户输入完整手机号后调用 1008-1-27 重新发送
    UIAlertAction *resendAction = [UIAlertAction actionWithTitle:@"重新发送"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [safeSelf showResendVerifyCodeAlert];
    }];
    
    // 取消按钮
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {
        safeSelf.needVerificationCode = NO;
        safeSelf.pendingLoginInfo = nil;
        safeSelf.maskedPhone = nil;
        if(safeSelf.launchScreenWrapper != nil)
            [safeSelf.launchScreenWrapper hide];
    }];
    
    [codeAlert addAction:confirmAction];
    [codeAlert addAction:resendAction];
    [codeAlert addAction:cancelAction];
    
    [self presentViewController:codeAlert animated:YES completion:nil];
}

/**
 * 重新发送验证码：让用户输入完整手机号后调用 1008-1-27 (biz_type="5") 重新发送。
 * 发送成功后重新弹出验证码输入框。
 */
- (void)showResendVerifyCodeAlert
{
    NSString *maskedPhoneDisplay = self.maskedPhone ?: @"您的手机";
    NSString *message = [NSString stringWithFormat:@"请输入完整手机号以重新发送验证码\n（脱敏号：%@）", maskedPhoneDisplay];
    
    UIAlertController *phoneAlert = [UIAlertController alertControllerWithTitle:@"重新发送验证码"
                                                                        message:message
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    
    [phoneAlert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"请输入完整手机号";
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.delegate = self;
        textField.tag = kRBLoginAlertTFResendPhone;
    }];
    
    __weak typeof(self) safeSelf = self;
    
    UIAlertAction *sendAction = [UIAlertAction actionWithTitle:@"发送"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        UITextField *phoneField = phoneAlert.textFields.firstObject;
        NSString *fullPhone = [BasicTool trim:phoneField.text];
        
        if ([BasicTool isStringEmpty:fullPhone]) {
            [BasicTool showAlertInfo:@"请输入手机号码！" parent:safeSelf];
            return;
        }
        
        if (fullPhone.length < 6) {
            [BasicTool showAlertInfo:@"请输入正确的手机号！" parent:safeSelf];
            return;
        }
        
        NSLog(@"【新设备验证】重新发送验证码到手机号: %@", fullPhone);
        [[HttpRestHelper sharedInstance] submitGetSMS:fullPhone
                                             bizType:@"5"
                                            complete:^(BOOL sucess, NSString *resultCode) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (sucess && [@"1" isEqualToString:resultCode]) {
                    NSLog(@"【新设备验证】验证码重新发送成功");
                    [BasicTool showAlertInfo:@"验证码已重新发送" parent:safeSelf];
                    // 重新弹出验证码输入框
                    [safeSelf showVerificationCodeInputAlert];
                } else {
                    NSLog(@"【新设备验证】验证码重新发送失败, resultCode=%@", resultCode);
                    [BasicTool showAlertInfo:@"验证码发送失败，请稍后重试" parent:safeSelf];
                    // 回到验证码输入界面
                    [safeSelf showVerificationCodeInputAlert];
                }
            });
        } hudParentView:safeSelf.view showLocalErrorAlert:YES completeForLocalError:^(NSString *errorLog) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // 回到验证码输入界面
                [safeSelf showVerificationCodeInputAlert];
            });
        }];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {
        // 回到验证码输入界面
        [safeSelf showVerificationCodeInputAlert];
    }];
    
    [phoneAlert addAction:sendAction];
    [phoneAlert addAction:cancelAction];
    
    [self presentViewController:phoneAlert animated:YES completion:nil];
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 账号冻结倒计时
/////////////////////////////////////////////////////////////////////////////////////////////

- (void)startFreezeCountdown:(NSInteger)seconds
{
    // 先停止之前可能存在的倒计时
    [self stopFreezeCountdown];
    
    self.freezeRemainSeconds = seconds;
    
    // 禁用登录按钮并更新文字
    self.btnLogin.enabled = NO;
    self.btnLogin.backgroundColor = HexColor(0xCCCCCC);
    [self updateFreezeButtonTitle];
    
    // 启动每秒倒计时
    self.freezeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                       target:self
                                                     selector:@selector(freezeTimerTick)
                                                     userInfo:nil
                                                      repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.freezeTimer forMode:NSRunLoopCommonModes];
}

- (void)freezeTimerTick
{
    self.freezeRemainSeconds--;
    
    if (self.freezeRemainSeconds <= 0) {
        [self stopFreezeCountdown];
        // 恢复登录按钮
        self.btnLogin.enabled = YES;
        self.btnLogin.backgroundColor = HexColor(0x4CD9A5);
        [self.btnLogin setTitle:@"登录" forState:UIControlStateNormal];
    } else {
        [self updateFreezeButtonTitle];
    }
}

- (void)updateFreezeButtonTitle
{
    NSInteger minutes = self.freezeRemainSeconds / 60;
    NSInteger secs = self.freezeRemainSeconds % 60;
    NSString *title = [NSString stringWithFormat:@"账号已冻结 (%02ld:%02ld)", (long)minutes, (long)secs];
    [self.btnLogin setTitle:title forState:UIControlStateNormal];
}

- (void)stopFreezeCountdown
{
    if (self.freezeTimer) {
        [self.freezeTimer invalidate];
        self.freezeTimer = nil;
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 底部功能按钮事件
/////////////////////////////////////////////////////////////////////////////////////////////

// 切换协议勾选状态
- (void)doToggleAgreement:(id)sender
{
    self.agreementChecked = !self.agreementChecked;
    [self updateAgreementCheckUI];
    
    // 持久化保存同意状态
    [[NSUserDefaults standardUserDefaults] setBool:self.agreementChecked forKey:@"kHasAgreedPrivacyPolicy"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// 更新协议勾选按钮的 UI 状态
- (void)updateAgreementCheckUI
{
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16];
    if (self.agreementChecked) {
        [self.btnAgreementCheck setImage:[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:config] forState:UIControlStateNormal];
        self.btnAgreementCheck.tintColor = HexColor(0xC1342D);
    } else {
        [self.btnAgreementCheck setImage:[UIImage systemImageNamed:@"circle" withConfiguration:config] forState:UIControlStateNormal];
        self.btnAgreementCheck.tintColor = HexColor(0xCCCCCC);
    }
}

// 打开用户使用协议
- (void)doOpenAgreement:(id)sender
{
    [ViewControllerFactory goWebViewController:RBCHAT_REGISTER_AGREEMENT_CN_URL title:@"用户使用协议" toNav:self.navigationController];
}

// 打开隐私政策
- (void)doOpenPrivacy:(id)sender
{
    [ViewControllerFactory goWebViewController:RBCHAT_PRIVACY_CN_URL title:@"隐私政策" toNav:self.navigationController];
}

// 在线客服 - 打开 Telegram 客服
- (void)doOpenOnlineService:(id)sender
{
    NSString *telegramUrl = @"https://t.me/wz662";
    NSURL *url = [NSURL URLWithString:telegramUrl];
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        [[UIApplication sharedApplication] openURL:url];
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - <UITextFieldDelegate>（手机号/验证码支持第三方输入法，仅允许数字）
/////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSInteger maxLen = 0;
    if (textField == self.loginPhone) {
        maxLen = 11;
    } else if (textField == self.loginSMS) {
        maxLen = 4;
    } else if (textField.tag == kRBLoginAlertTFResendPhone) {
        maxLen = 11;
    } else if (textField.tag == kRBLoginAlertTFDeviceVerifyCode) {
        maxLen = 8;
    } else {
        return YES;
    }
    for (NSUInteger i = 0; i < string.length; i++) {
        unichar c = [string characterAtIndex:i];
        if (c < '0' || c > '9') {
            return NO;
        }
    }
    if ((NSInteger)(textField.text.length - range.length + string.length) > maxLen) {
        return NO;
    }
    return YES;
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 获取验证码的GetSMSButtonDelegate实现
/////////////////////////////////////////////////////////////////////////////////////////////

/** 短信验证码用于的业务类型 */
- (NSString *)getSmsBizType {
    return @"0";
}
/** 手机号码 */
- (NSString *)getPhoneNum {
    return self.loginPhone.text;
}

/** 跳转到注册页面 */
- (void)gotoRegisterPage {
    [ViewControllerFactory goRegisterViewController:self.navigationController needSMS:YES phone:self.loginPhone.text sms:self.loginSMS.text];
}

/** 验证码请求发出后，将输入焦点设置到验证码输入框里 */
- (void)focusToInput
{
    [self.loginSMS becomeFirstResponder];
}

@end
