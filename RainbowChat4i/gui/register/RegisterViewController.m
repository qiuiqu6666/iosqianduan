//telegram @wz662
#import "RegisterViewController.h"
#import "ViewControllerFactory.h"
#import "BasicTool.h"
#import "HttpRestHelper.h"
#import "NotificationCenterFactory.h"
#import "UserRegisterDTO.h"

// 性别常量：男
#define SELECT_SEX_MAN   1
// 性别常量：女
#define SELECT_SEX_WOMAN 0


@interface RegisterViewController () <UIGestureRecognizerDelegate>

// 调用者传入的参数
@property (nonatomic, assign) BOOL needSMS4Init;
@property (nonatomic, retain) NSString *phone4Init;
@property (nonatomic, retain) NSString *sms4Init;

// 当前选中的"性别"按钮
@property (nonatomic, retain) UIButton *currentSex;
// 用于存放注册成功后的完整注册信息
@property (nonatomic, retain) UserRegisterDTO *registerData;

// ========== Header UI ==========
@property (nonatomic, strong) UIImageView *bgImageView;
@property (nonatomic, strong) UILabel *lblTitle;
@property (nonatomic, strong) UILabel *lblSubtitle;

// ========== Form Area ==========
@property (nonatomic, strong) UIScrollView *formScrollView;
@property (nonatomic, strong) UIStackView *formStack;

// --- Phone + SMS ---
@property (nonatomic, strong) UIView *layoutPhoneAndSMS;
@property (nonatomic, strong) UILabel *lblCountryCode;
@property (nonatomic, strong) UITextField *txtPhone;
@property (nonatomic, strong) UITextField *txtSms;
@property (nonatomic, strong) GetSMSButton *btnGetSMS;

// --- Nickname ---
@property (nonatomic, strong) UITextField *txtNickname;
@property (nonatomic, strong) UILabel *lblNicknameAvailability;

// --- Password ---
@property (nonatomic, strong) UITextField *txtPassword;
@property (nonatomic, strong) UIButton *btnShowPassword;
@property (nonatomic, strong) UILabel *lblPasswordHint;

// --- Confirm Password ---
@property (nonatomic, strong) UITextField *txtConfirmPassword;
@property (nonatomic, strong) UIButton *btnShowConfirmPassword;

// --- Sex ---
@property (nonatomic, strong) UIButton *btnSexMan;
@property (nonatomic, strong) UIButton *btnSexWoman;

// --- Terms ---
@property (nonatomic, strong) UIButton *btnHasRead;
@property (nonatomic, strong) UIButton *btnSeeTerms;

// --- Submit ---
@property (nonatomic, strong) UIButton *btnSubmit;

// ========== Register Success Overlay ==========
@property (nonatomic, strong) UIView *layoutRgisterSucessContent;
@property (nonatomic, strong) UILabel *viewID_afterRegisterSucess;
@property (nonatomic, strong) UILabel *viewPhone_afterRegisterSucess;

@end


@implementation RegisterViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil needSMS:(BOOL)needSMS phone:(NSString *)phone sms:(NSString *)sms {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.needSMS4Init = needSMS;
        self.phone4Init = phone;
        self.sms4Init = sms;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"欢迎注册";
    
    // 构建程序化UI
    [self buildUI];
    
    // 设置"性别"Button的tag值
    self.btnSexMan.tag = SELECT_SEX_MAN;
    self.btnSexWoman.tag = SELECT_SEX_WOMAN;
    self.currentSex = self.btnSexMan;
    self.btnSexMan.selected = YES;
    
    // 点击空白处取消键盘
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)];
    singleTap.cancelsTouchesInView = NO;
    singleTap.delegate = self;
    [self.view addGestureRecognizer:singleTap];
    
    // 限制输入长度
    [self.txtNickname addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    [self.txtPassword addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    
    // 短信验证码相关的初始化
    [self initForSMS];
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 构建UI（程序化布局）
/////////////////////////////////////////////////////////////////////////////////////////////

- (void)buildUI
{
    self.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.95 blue:0.97 alpha:1.0];
    
    [self buildHeaderArea];
    [self buildFormArea];
}

- (void)buildHeaderArea
{
    // 全屏背景图
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
    self.lblTitle.text = @"注册账号";
    self.lblTitle.font = [UIFont boldSystemFontOfSize:28];
    self.lblTitle.textColor = HexColor(0x1A1A1A);
    [self.view addSubview:self.lblTitle];
    
    // 副标题
    self.lblSubtitle = [[UILabel alloc] init];
    self.lblSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblSubtitle.text = @"填写信息完成注册";
    self.lblSubtitle.font = [UIFont systemFontOfSize:14];
    self.lblSubtitle.textColor = HexColor(0x999999);
    [self.view addSubview:self.lblSubtitle];
    
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.bgImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.bgImageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bgImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bgImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.lblTitle.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.lblTitle.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:60],
        
        [self.lblSubtitle.leadingAnchor constraintEqualToAnchor:self.lblTitle.leadingAnchor],
        [self.lblSubtitle.topAnchor constraintEqualToAnchor:self.lblTitle.bottomAnchor constant:10],
    ]];
}

- (void)buildFormArea
{
    // ScrollView 支持小屏幕滚动
    self.formScrollView = [[UIScrollView alloc] init];
    self.formScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.formScrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.formScrollView];
    
    // StackView 管理表单元素
    self.formStack = [[UIStackView alloc] init];
    self.formStack.axis = UILayoutConstraintAxisVertical;
    self.formStack.spacing = 0;
    self.formStack.alignment = UIStackViewAlignmentFill;
    self.formStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.formScrollView addSubview:self.formStack];
    
    // 构建各个表单部分
    [self buildPhoneAndSMSSection];
    [self buildNicknameSection];
    [self buildPasswordSection];
    [self buildSexSection];
    [self buildTermsSection];
    [self buildSubmitButton];
    
    // 添加到 formStack
    [self.formStack addArrangedSubview:self.layoutPhoneAndSMS];
    
    UIView *nicknameSection = [self wrapTextField:self.txtNickname line:nil];
    [self.formStack addArrangedSubview:nicknameSection];
    [self.formStack addArrangedSubview:self.lblNicknameAvailability];

    [self.formStack addArrangedSubview:self.lblPasswordHint];
    
    UIView *passwordSection = [self buildPasswordRow];
    [self.formStack addArrangedSubview:passwordSection];
    
    UIView *confirmPasswordSection = [self buildConfirmPasswordRow];
    [self.formStack addArrangedSubview:confirmPasswordSection];
    
    UIView *sexRow = [self buildSexRow];
    /// 界面不展示性别选择；默认仍为「男」(SELECT_SEX_MAN)，注册参数 user_sex 照常提交，见 viewDidLoad 与 getFormData
    sexRow.hidden = YES;
    [self.formStack addArrangedSubview:sexRow];
    
    UIView *termsRow = [self buildTermsRow];
    [self.formStack addArrangedSubview:termsRow];
    
    [self.formStack addArrangedSubview:self.btnSubmit];
    
    // 设置间距
    [self.formStack setCustomSpacing:15 afterView:self.layoutPhoneAndSMS];
    [self.formStack setCustomSpacing:15 afterView:nicknameSection];
    [self.formStack setCustomSpacing:6 afterView:self.lblNicknameAvailability];
    [self.formStack setCustomSpacing:8 afterView:self.lblPasswordHint];
    [self.formStack setCustomSpacing:0 afterView:passwordSection];
    [self.formStack setCustomSpacing:35 afterView:confirmPasswordSection];
    [self.formStack setCustomSpacing:25 afterView:termsRow];
    
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.formScrollView.topAnchor constraintEqualToAnchor:self.lblSubtitle.bottomAnchor constant:30],
        [self.formScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.formScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.formScrollView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
        
        [self.formStack.topAnchor constraintEqualToAnchor:self.formScrollView.topAnchor],
        [self.formStack.leadingAnchor constraintEqualToAnchor:self.formScrollView.leadingAnchor constant:40],
        [self.formStack.trailingAnchor constraintEqualToAnchor:self.formScrollView.trailingAnchor constant:-40],
        [self.formStack.bottomAnchor constraintEqualToAnchor:self.formScrollView.bottomAnchor constant:-20],
        [self.formStack.widthAnchor constraintEqualToAnchor:self.formScrollView.widthAnchor constant:-80],
    ]];
}

- (void)buildPhoneAndSMSSection
{
    self.layoutPhoneAndSMS = [[UIView alloc] init];
    self.layoutPhoneAndSMS.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 手机号输入行
    UIView *phoneRow = [[UIView alloc] init];
    phoneRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.layoutPhoneAndSMS addSubview:phoneRow];
    
    self.lblCountryCode = [[UILabel alloc] init];
    self.lblCountryCode.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblCountryCode.text = @"+86";
    self.lblCountryCode.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.lblCountryCode.textColor = HexColor(0x333333);
    [phoneRow addSubview:self.lblCountryCode];
    
    self.txtPhone = [[UITextField alloc] init];
    self.txtPhone.translatesAutoresizingMaskIntoConstraints = NO;
    self.txtPhone.placeholder = @"输入11位中国大陆手机号码";
    self.txtPhone.font = [UIFont systemFontOfSize:16];
    self.txtPhone.textColor = HexColor(0x333333);
    self.txtPhone.keyboardType = UIKeyboardTypeDefault;
    self.txtPhone.delegate = self;
    [phoneRow addSubview:self.txtPhone];
    
    UIView *phoneLine = [[UIView alloc] init];
    phoneLine.translatesAutoresizingMaskIntoConstraints = NO;
    phoneLine.backgroundColor = HexColor(0xE0E0E0);
    [self.layoutPhoneAndSMS addSubview:phoneLine];
    
    // 验证码输入行
    UIView *smsRow = [[UIView alloc] init];
    smsRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.layoutPhoneAndSMS addSubview:smsRow];
    
    self.txtSms = [[UITextField alloc] init];
    self.txtSms.translatesAutoresizingMaskIntoConstraints = NO;
    self.txtSms.placeholder = @"输入验证码";
    self.txtSms.font = [UIFont systemFontOfSize:16];
    self.txtSms.textColor = HexColor(0x333333);
    self.txtSms.keyboardType = UIKeyboardTypeDefault;
    self.txtSms.delegate = self;
    self.txtSms.textContentType = UITextContentTypeOneTimeCode;
    [smsRow addSubview:self.txtSms];
    
    self.btnGetSMS = [[GetSMSButton alloc] init];
    self.btnGetSMS.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnGetSMS setTitle:@"获取验证码" forState:UIControlStateNormal];
    self.btnGetSMS.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.btnGetSMS setTitleColor:HexColor(0xC6391E) forState:UIControlStateNormal];
    [self.btnGetSMS setTitleColor:HexColor(0x999999) forState:UIControlStateDisabled];
    self.btnGetSMS.backgroundColor = [UIColor clearColor];
    self.btnGetSMS.layer.borderWidth = 0;
    self.btnGetSMS.layer.cornerRadius = 0;
    [smsRow addSubview:self.btnGetSMS];
    
    UIView *smsLine = [[UIView alloc] init];
    smsLine.translatesAutoresizingMaskIntoConstraints = NO;
    smsLine.backgroundColor = HexColor(0xE0E0E0);
    [self.layoutPhoneAndSMS addSubview:smsLine];
    
    [NSLayoutConstraint activateConstraints:@[
        [phoneRow.topAnchor constraintEqualToAnchor:self.layoutPhoneAndSMS.topAnchor],
        [phoneRow.leadingAnchor constraintEqualToAnchor:self.layoutPhoneAndSMS.leadingAnchor],
        [phoneRow.trailingAnchor constraintEqualToAnchor:self.layoutPhoneAndSMS.trailingAnchor],
        [phoneRow.heightAnchor constraintEqualToConstant:50],
        
        [self.lblCountryCode.leadingAnchor constraintEqualToAnchor:phoneRow.leadingAnchor],
        [self.lblCountryCode.centerYAnchor constraintEqualToAnchor:phoneRow.centerYAnchor],
        [self.lblCountryCode.widthAnchor constraintEqualToConstant:40],
        
        [self.txtPhone.leadingAnchor constraintEqualToAnchor:self.lblCountryCode.trailingAnchor constant:5],
        [self.txtPhone.trailingAnchor constraintEqualToAnchor:phoneRow.trailingAnchor],
        [self.txtPhone.topAnchor constraintEqualToAnchor:phoneRow.topAnchor],
        [self.txtPhone.bottomAnchor constraintEqualToAnchor:phoneRow.bottomAnchor],
        
        [phoneLine.topAnchor constraintEqualToAnchor:phoneRow.bottomAnchor],
        [phoneLine.leadingAnchor constraintEqualToAnchor:self.layoutPhoneAndSMS.leadingAnchor],
        [phoneLine.trailingAnchor constraintEqualToAnchor:self.layoutPhoneAndSMS.trailingAnchor],
        [phoneLine.heightAnchor constraintEqualToConstant:0.5],
        
        [smsRow.topAnchor constraintEqualToAnchor:phoneLine.bottomAnchor constant:15],
        [smsRow.leadingAnchor constraintEqualToAnchor:self.layoutPhoneAndSMS.leadingAnchor],
        [smsRow.trailingAnchor constraintEqualToAnchor:self.layoutPhoneAndSMS.trailingAnchor],
        [smsRow.heightAnchor constraintEqualToConstant:50],
        
        [self.txtSms.leadingAnchor constraintEqualToAnchor:smsRow.leadingAnchor],
        [self.txtSms.topAnchor constraintEqualToAnchor:smsRow.topAnchor],
        [self.txtSms.bottomAnchor constraintEqualToAnchor:smsRow.bottomAnchor],
        [self.txtSms.trailingAnchor constraintEqualToAnchor:self.btnGetSMS.leadingAnchor constant:-8],
        
        [self.btnGetSMS.trailingAnchor constraintEqualToAnchor:smsRow.trailingAnchor],
        [self.btnGetSMS.centerYAnchor constraintEqualToAnchor:smsRow.centerYAnchor],
        [self.btnGetSMS.widthAnchor constraintEqualToConstant:110],
        [self.btnGetSMS.heightAnchor constraintEqualToConstant:34],
        
        [smsLine.topAnchor constraintEqualToAnchor:smsRow.bottomAnchor],
        [smsLine.leadingAnchor constraintEqualToAnchor:self.layoutPhoneAndSMS.leadingAnchor],
        [smsLine.trailingAnchor constraintEqualToAnchor:self.layoutPhoneAndSMS.trailingAnchor],
        [smsLine.heightAnchor constraintEqualToConstant:0.5],
        [smsLine.bottomAnchor constraintEqualToAnchor:self.layoutPhoneAndSMS.bottomAnchor],
    ]];
}

- (void)buildNicknameSection
{
    self.txtNickname = [[UITextField alloc] init];
    self.txtNickname.translatesAutoresizingMaskIntoConstraints = NO;
    self.txtNickname.placeholder = @"请输入您的昵称";
    self.txtNickname.font = [UIFont systemFontOfSize:16];
    self.txtNickname.textColor = HexColor(0x333333);
    self.txtNickname.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.txtNickname.returnKeyType = UIReturnKeyDone;
    self.txtNickname.delegate = self;

    // 昵称是否可用提示（实时校验：可用 / 该昵称已被占用）
    self.lblNicknameAvailability = [[UILabel alloc] init];
    self.lblNicknameAvailability.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblNicknameAvailability.font = [UIFont systemFontOfSize:13];
    self.lblNicknameAvailability.text = @"";
    [self.lblNicknameAvailability.heightAnchor constraintEqualToConstant:20].active = YES;
}

- (void)buildPasswordSection
{
    // 密码提示
    self.lblPasswordHint = [[UILabel alloc] init];
    self.lblPasswordHint.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblPasswordHint.text = @"* 密码至少8位，需包含英文和数字，可使用特殊符号";
    self.lblPasswordHint.font = [UIFont systemFontOfSize:11];
    self.lblPasswordHint.textColor = HexColor(0x999999);
    [self.lblPasswordHint.heightAnchor constraintEqualToConstant:20].active = YES;
    
    // 密码输入框
    self.txtPassword = [[UITextField alloc] init];
    self.txtPassword.translatesAutoresizingMaskIntoConstraints = NO;
    self.txtPassword.placeholder = @"请输入您的登录密码";
    self.txtPassword.font = [UIFont systemFontOfSize:16];
    self.txtPassword.textColor = HexColor(0x333333);
    self.txtPassword.secureTextEntry = YES;
    /// 勿用 OneTimeCode：会走 OTP/Emoji 搜索管线，易与第三方输入法叠加卡顿（见 rizhi RTIInputSystemClient）
    self.txtPassword.textContentType = UITextContentTypeNewPassword;
    self.txtPassword.returnKeyType = UIReturnKeyDone;
    self.txtPassword.delegate = self;
    
    // 显示/隐藏密码按钮
    self.btnShowPassword = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnShowPassword.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnShowPassword setImage:[UIImage imageNamed:@"login_showpass_off"] forState:UIControlStateNormal];
    [self.btnShowPassword setImage:[UIImage imageNamed:@"login_showpass_on"] forState:UIControlStateSelected];
    [self.btnShowPassword addTarget:self action:@selector(clickShowPassword:) forControlEvents:UIControlEventTouchUpInside];
    
    // 确认密码输入框
    self.txtConfirmPassword = [[UITextField alloc] init];
    self.txtConfirmPassword.translatesAutoresizingMaskIntoConstraints = NO;
    self.txtConfirmPassword.placeholder = @"请再次输入密码";
    self.txtConfirmPassword.font = [UIFont systemFontOfSize:16];
    self.txtConfirmPassword.textColor = HexColor(0x333333);
    self.txtConfirmPassword.secureTextEntry = YES;
    self.txtConfirmPassword.textContentType = UITextContentTypeNewPassword;
    self.txtConfirmPassword.returnKeyType = UIReturnKeyDone;
    self.txtConfirmPassword.delegate = self;
    
    // 显示/隐藏确认密码按钮
    self.btnShowConfirmPassword = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnShowConfirmPassword.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnShowConfirmPassword setImage:[UIImage imageNamed:@"login_showpass_off"] forState:UIControlStateNormal];
    [self.btnShowConfirmPassword setImage:[UIImage imageNamed:@"login_showpass_on"] forState:UIControlStateSelected];
    [self.btnShowConfirmPassword addTarget:self action:@selector(clickShowConfirmPassword:) forControlEvents:UIControlEventTouchUpInside];
}

- (UIView *)buildPasswordRow
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIView *pswRow = [[UIView alloc] init];
    pswRow.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:pswRow];
    
    [pswRow addSubview:self.txtPassword];
    [pswRow addSubview:self.btnShowPassword];
    
    UIView *pswLine = [[UIView alloc] init];
    pswLine.translatesAutoresizingMaskIntoConstraints = NO;
    pswLine.backgroundColor = HexColor(0xE0E0E0);
    [container addSubview:pswLine];
    
    [NSLayoutConstraint activateConstraints:@[
        [pswRow.topAnchor constraintEqualToAnchor:container.topAnchor],
        [pswRow.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [pswRow.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [pswRow.heightAnchor constraintEqualToConstant:50],
        
        [self.txtPassword.leadingAnchor constraintEqualToAnchor:pswRow.leadingAnchor],
        [self.txtPassword.topAnchor constraintEqualToAnchor:pswRow.topAnchor],
        [self.txtPassword.bottomAnchor constraintEqualToAnchor:pswRow.bottomAnchor],
        [self.txtPassword.trailingAnchor constraintEqualToAnchor:self.btnShowPassword.leadingAnchor constant:-8],
        
        [self.btnShowPassword.trailingAnchor constraintEqualToAnchor:pswRow.trailingAnchor],
        [self.btnShowPassword.centerYAnchor constraintEqualToAnchor:pswRow.centerYAnchor],
        [self.btnShowPassword.widthAnchor constraintEqualToConstant:30],
        [self.btnShowPassword.heightAnchor constraintEqualToConstant:30],
        
        [pswLine.topAnchor constraintEqualToAnchor:pswRow.bottomAnchor],
        [pswLine.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [pswLine.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [pswLine.heightAnchor constraintEqualToConstant:0.5],
        [pswLine.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    
    return container;
}

- (UIView *)buildConfirmPasswordRow
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:row];
    
    [row addSubview:self.txtConfirmPassword];
    [row addSubview:self.btnShowConfirmPassword];
    
    UIView *line = [[UIView alloc] init];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.backgroundColor = HexColor(0xE0E0E0);
    [container addSubview:line];
    
    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:container.topAnchor],
        [row.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [row.heightAnchor constraintEqualToConstant:50],
        
        [self.txtConfirmPassword.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [self.txtConfirmPassword.topAnchor constraintEqualToAnchor:row.topAnchor],
        [self.txtConfirmPassword.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [self.txtConfirmPassword.trailingAnchor constraintEqualToAnchor:self.btnShowConfirmPassword.leadingAnchor constant:-8],
        
        [self.btnShowConfirmPassword.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [self.btnShowConfirmPassword.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [self.btnShowConfirmPassword.widthAnchor constraintEqualToConstant:30],
        [self.btnShowConfirmPassword.heightAnchor constraintEqualToConstant:30],
        
        [line.topAnchor constraintEqualToAnchor:row.bottomAnchor],
        [line.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [line.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [line.heightAnchor constraintEqualToConstant:0.5],
        [line.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    
    return container;
}

- (UIView *)wrapTextField:(UITextField *)textField line:(UIView **)outLine
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    
    [container addSubview:textField];
    
    UIView *line = [[UIView alloc] init];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.backgroundColor = HexColor(0xE0E0E0);
    [container addSubview:line];
    
    [NSLayoutConstraint activateConstraints:@[
        [textField.topAnchor constraintEqualToAnchor:container.topAnchor],
        [textField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [textField.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [textField.heightAnchor constraintEqualToConstant:50],
        
        [line.topAnchor constraintEqualToAnchor:textField.bottomAnchor],
        [line.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [line.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [line.heightAnchor constraintEqualToConstant:0.5],
        [line.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    
    if (outLine) *outLine = line;
    return container;
}

- (void)buildSexSection
{
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16];
    
    self.btnSexMan = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnSexMan.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnSexMan setTitle:@" 男" forState:UIControlStateNormal];
    [self.btnSexMan setTitleColor:HexColor(0x666666) forState:UIControlStateNormal];
    [self.btnSexMan setTitleColor:HexColor(0x333333) forState:UIControlStateSelected];
    self.btnSexMan.titleLabel.font = [UIFont systemFontOfSize:15];
    [self.btnSexMan setImage:[UIImage systemImageNamed:@"circle" withConfiguration:config] forState:UIControlStateNormal];
    [self.btnSexMan setImage:[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:config] forState:UIControlStateSelected];
    self.btnSexMan.tintColor = HexColor(0x4CD9A5);
    [self.btnSexMan addTarget:self action:@selector(clickSexCondition:) forControlEvents:UIControlEventTouchUpInside];
    self.btnSexMan.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.btnSexMan.tag = SELECT_SEX_MAN;
    
    self.btnSexWoman = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnSexWoman.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnSexWoman setTitle:@" 女" forState:UIControlStateNormal];
    [self.btnSexWoman setTitleColor:HexColor(0x666666) forState:UIControlStateNormal];
    [self.btnSexWoman setTitleColor:HexColor(0x333333) forState:UIControlStateSelected];
    self.btnSexWoman.titleLabel.font = [UIFont systemFontOfSize:15];
    [self.btnSexWoman setImage:[UIImage systemImageNamed:@"circle" withConfiguration:config] forState:UIControlStateNormal];
    [self.btnSexWoman setImage:[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:config] forState:UIControlStateSelected];
    self.btnSexWoman.tintColor = HexColor(0x4CD9A5);
    [self.btnSexWoman addTarget:self action:@selector(clickSexCondition:) forControlEvents:UIControlEventTouchUpInside];
    self.btnSexWoman.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.btnSexWoman.tag = SELECT_SEX_WOMAN;
}

- (UIView *)buildSexRow
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    
    [row addSubview:self.btnSexMan];
    [row addSubview:self.btnSexWoman];
    
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:30],
        
        [self.btnSexMan.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [self.btnSexMan.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [self.btnSexMan.widthAnchor constraintEqualToConstant:60],
        
        [self.btnSexWoman.leadingAnchor constraintEqualToAnchor:self.btnSexMan.trailingAnchor constant:20],
        [self.btnSexWoman.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [self.btnSexWoman.widthAnchor constraintEqualToConstant:60],
    ]];
    
    return row;
}

- (void)buildTermsSection
{
    self.btnHasRead = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnHasRead.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *checkConfig = [UIImageSymbolConfiguration configurationWithPointSize:16];
    [self.btnHasRead setImage:[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:checkConfig] forState:UIControlStateSelected];
    [self.btnHasRead setImage:[UIImage systemImageNamed:@"circle" withConfiguration:checkConfig] forState:UIControlStateNormal];
    self.btnHasRead.tintColor = HexColor(0x4CD9A5);
    self.btnHasRead.selected = YES;
    [self.btnHasRead setTitle:@" 我已阅读并接受" forState:UIControlStateNormal];
    [self.btnHasRead setTitleColor:HexColor(0x999999) forState:UIControlStateNormal];
    self.btnHasRead.titleLabel.font = [UIFont systemFontOfSize:13];
    self.btnHasRead.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.btnHasRead addTarget:self action:@selector(clickHasReadTerms:) forControlEvents:UIControlEventTouchUpInside];
    
    self.btnSeeTerms = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnSeeTerms.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnSeeTerms setTitle:@"《服务条款》" forState:UIControlStateNormal];
    [self.btnSeeTerms setTitleColor:HexColor(0xC6391E) forState:UIControlStateNormal];
    self.btnSeeTerms.titleLabel.font = [UIFont systemFontOfSize:13];
    [self.btnSeeTerms addTarget:self action:@selector(clickReadTerms:) forControlEvents:UIControlEventTouchUpInside];
}

- (UIView *)buildTermsRow
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    
    [row addSubview:self.btnHasRead];
    [row addSubview:self.btnSeeTerms];
    
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:30],
        
        [self.btnHasRead.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [self.btnHasRead.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        
        [self.btnSeeTerms.leadingAnchor constraintEqualToAnchor:self.btnHasRead.trailingAnchor],
        [self.btnSeeTerms.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    
    return row;
}

- (void)buildSubmitButton
{
    self.btnSubmit = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnSubmit.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnSubmit setTitle:@"提交注册" forState:UIControlStateNormal];
    [self.btnSubmit setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.btnSubmit setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.8] forState:UIControlStateHighlighted];
    self.btnSubmit.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.btnSubmit.backgroundColor = HexColor(0x4CD9A5);
    self.btnSubmit.layer.cornerRadius = 25;
    self.btnSubmit.clipsToBounds = YES;
    [self.btnSubmit addTarget:self action:@selector(clickSubmit:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.btnSubmit.heightAnchor constraintEqualToConstant:50].active = YES;
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 初始化
/////////////////////////////////////////////////////////////////////////////////////////////

- (void)initForSMS
{
    if(self.needSMS4Init) {
        self.txtPhone.keyboardType = UIKeyboardTypeDefault;
        self.txtSms.keyboardType = UIKeyboardTypeDefault;
        self.txtSms.textContentType = UITextContentTypeOneTimeCode;
        
        self.btnGetSMS.parentVC = self;
        self.btnGetSMS.delegate = self;
        
        self.txtPhone.text = self.phone4Init;
        self.txtSms.text = self.sms4Init;
        
        self.layoutPhoneAndSMS.hidden = NO;
        
        [self.txtPhone addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
        [self.txtSms addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    } else {
        self.layoutPhoneAndSMS.hidden = YES;
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 输入控制
/////////////////////////////////////////////////////////////////////////////////////////////

- (void)textFieldInputLimit:(UITextField *)textField
{
    if(textField == self.txtPhone) {
        [BasicTool textFieldInputLimit:textField maxLen:11];
    }
    else if(textField == self.txtSms) {
        [BasicTool textFieldInputLimit:textField maxLen:4];
    }
    else if(textField == self.txtNickname) {
        [BasicTool textFieldInputLimit:textField maxLen:50];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performRegisterNicknameAvailableCheck) object:nil];
        [self performSelector:@selector(performRegisterNicknameAvailableCheck) withObject:nil afterDelay:0.4];
    }
    else if(textField == self.txtPassword) {
        [BasicTool textFieldInputLimit:textField maxLen:16];
    }
}

- (void)performRegisterNicknameAvailableCheck
{
    NSString *trimmed = [BasicTool trim:self.txtNickname.text];
    if (trimmed.length == 0) {
        self.lblNicknameAvailability.text = @"";
        self.lblNicknameAvailability.textColor = HexColor(0x999999);
        return;
    }
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitNicknameAvailableCheck:nil
                                                        nickname:trimmed
                                                        complete:^(BOOL sucess, BOOL available, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!wself.lblNicknameAvailability) return;
            if (available) {
                wself.lblNicknameAvailability.text = @"可用";
                wself.lblNicknameAvailability.textColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0];
            } else {
                wself.lblNicknameAvailability.text = (msg.length > 0 ? msg : @"该昵称已被占用");
                wself.lblNicknameAvailability.textColor = [UIColor colorWithRed:0.95 green:0.3 blue:0.2 alpha:1.0];
            }
        });
    } hudParentView:nil];
}

- (void)fingerTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    [self.view endEditing:YES];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    UIView *v = touch.view;
    while (v) {
        if ([v isKindOfClass:[UITextField class]] || [v isKindOfClass:[UITextView class]] || [v isKindOfClass:[UIControl class]]) {
            return NO;
        }
        v = v.superview;
    }
    return YES;
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 按钮事件
/////////////////////////////////////////////////////////////////////////////////////////////

// "性别"选择
- (void)clickSexCondition:(id)sender
{
    UIButton *b = (UIButton *)sender;
    if(b.selected == NO) {
        self.currentSex.selected = NO;
        self.currentSex = b;
        self.currentSex.selected = YES;
    }
}

// "我已阅读服务条款"
- (void)clickHasReadTerms:(id)sender
{
    self.btnHasRead.selected = !self.btnHasRead.selected;
}

// "服务条款"链接
- (void)clickReadTerms:(id)sender
{
    [ViewControllerFactory goWebViewController:[BasicTool isChineseSimple]?RBCHAT_REGISTER_AGREEMENT_CN_URL:RBCHAT_REGISTER_AGREEMENT_EN_URL
                                         title:[BasicTool isChineseSimple]?@"服务条款":@"Terms of Service"
                                         toNav:self.navigationController];
}

// "显示密码"
- (void)clickShowPassword:(id)sender
{
    UIButton *b = (UIButton *)sender;
    b.selected = !b.selected;
    self.txtPassword.secureTextEntry = !self.txtPassword.secureTextEntry;
    if (self.txtPassword.secureTextEntry) {
        [self.txtPassword insertText:self.txtPassword.text];
    }
}

- (void)clickShowConfirmPassword:(id)sender
{
    UIButton *b = (UIButton *)sender;
    b.selected = !b.selected;
    self.txtConfirmPassword.secureTextEntry = !self.txtConfirmPassword.secureTextEntry;
    if (self.txtConfirmPassword.secureTextEntry) {
        [self.txtConfirmPassword insertText:self.txtConfirmPassword.text];
    }
}

// "提交注册"
- (IBAction)clickSubmit:(id)sender
{
    [BasicTool hideSoftInputMethod];
    
    __weak typeof(self) safeSelf = self;
    
    // 启用了手机号和验证码注册的情况下
    if(self.needSMS4Init) {
        if([BasicTool isStringEmpty:self.txtPhone.text]) {
            [BasicTool showAlertInfo:@"请输入手机号码！" parent:self];
            return;
        }
        if(![BasicTool verifyChineseMainlandPhone:self.txtPhone.text]) {
            [BasicTool showAlertInfo:@"请输入正确的中国大陆手机号码！" parent:self];
            return;
        }
        if([BasicTool isStringEmpty:self.txtSms.text]) {
            [BasicTool showAlertInfo:@"请输入短信验证码！" parent:self];
            return;
        }
    }
    
    if([BasicTool isStringEmpty:self.txtNickname.text]) {
        [BasicTool showAlertInfo:@"昵称不能为空！" parent:self];
        return;
    }
    if([BasicTool isStringEmpty:self.txtPassword.text]) {
        [BasicTool showAlertInfo:@"密码不能为空！" parent:self];
        return;
    }
    if(self.txtPassword.text.length < 8) {
        [BasicTool showAlertInfo:@"密码长度必须大于或等于8位！" parent:self];
        return;
    }
    if(self.txtPassword.text.length > 16) {
        [BasicTool showAlertInfo:@"密码长度不能大于16位！" parent:self];
        return;
    }
    
    // 验证密码必须包含英文和数字
    NSString *password = self.txtPassword.text;
    BOOL hasLetter = NO;
    BOOL hasDigit = NO;
    for (int i = 0; i < password.length; i++) {
        unichar c = [password characterAtIndex:i];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) hasLetter = YES;
        if (c >= '0' && c <= '9') hasDigit = YES;
        if (hasLetter && hasDigit) break;
    }
    if (!hasLetter) {
        [BasicTool showAlertInfo:@"密码必须包含至少一个英文字母！" parent:self];
        return;
    }
    if (!hasDigit) {
        [BasicTool showAlertInfo:@"密码必须包含至少一个数字！" parent:self];
        return;
    }
    
    // 验证确认密码
    if([BasicTool isStringEmpty:self.txtConfirmPassword.text]) {
        [BasicTool showAlertInfo:@"请输入确认密码！" parent:self];
        return;
    }
    if(![self.txtPassword.text isEqualToString:self.txtConfirmPassword.text]) {
        [BasicTool showAlertInfo:@"两次输入的密码不一致！" parent:self];
        return;
    }

    if(!self.btnHasRead.selected) {
        [BasicTool showAlertInfo:@"注册之前请确认已阅读服务条款！" parent:self];
        return;
    }

    self.registerData = [self getFormData];
    
    [[HttpRestHelper sharedInstance] submitRegisterToServer:self.registerData complete:^(BOOL sucess, NSDictionary *registerResult) {
        if(registerResult != nil) {
            NSString *uid = [registerResult objectForKey:@"new_uid"];
            int code = [BasicTool getIntValue:uid];
            
            if(code <= 0) {
                if([@"-4" isEqualToString:uid]) {
                    [BasicTool showAlertInfo:[NSString stringWithFormat:@"手机号 %@ 格式不正确，请检查！", self.registerData.phoneNum] parent:safeSelf];
                    return;
                }
                else if([@"-3" isEqualToString:uid]) {
                    [BasicTool showAlertInfo:[NSString stringWithFormat:@"手机号 %@ 已经注册，请返回登录界面使用\"验证码登录\"功能登录！", self.registerData.phoneNum] parent:safeSelf];
                    return;
                }
                else if([@"-2" isEqualToString:uid]) {
                    [BasicTool showAlertInfo:[NSString stringWithFormat:@"无效的短信验证码 %@ ", self.registerData.phoneSms] parent:safeSelf];
                    return;
                }
                else if([@"-1" isEqualToString:uid]) {
                    [BasicTool showAlertInfo:[NSString stringWithFormat:@"邮箱 %@ 格式不正确，请检查！", self.registerData.user_mail] parent:safeSelf];
                    return;
                }
                else if([@"0" isEqualToString:uid]) {
                    [BasicTool showAlertInfo:[NSString stringWithFormat:@"邮箱 %@ 已被人注册，请更换邮箱后再试！", self.registerData.user_mail] parent:safeSelf];
                    return;
                }
            } else {
                self.registerData.user_uid = uid;
                // 注册成功后直接静默登录：发送通知给登录页面并返回
                [NotificationCenterFactory registerSucessBack_POST:self.registerData];
                [self.navigationController popViewControllerAnimated:YES];
                return;
            }
        } else {
            [BasicTool showAlertInfo:@"注册失败，未知错误！" parent:self];
            return;
        }
    } hudParentView:self.view];
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 注册成功
/////////////////////////////////////////////////////////////////////////////////////////////

- (void)showRegisterSucessHint:(UserRegisterDTO *)userRegisterData
{
    if(userRegisterData == nil) return;
    
    // 创建注册成功覆盖层
    self.layoutRgisterSucessContent = [[UIView alloc] initWithFrame:self.view.bounds];
    self.layoutRgisterSucessContent.backgroundColor = [UIColor clearColor];
    
    // --- 背景图（与登录/注册页面一致）---
    UIImageView *bgImg = [[UIImageView alloc] init];
    bgImg.translatesAutoresizingMaskIntoConstraints = NO;
    bgImg.image = [UIImage imageNamed:@"main_login_form_bg_bottom32_v9_2"];
    bgImg.contentMode = UIViewContentModeScaleAspectFill;
    bgImg.clipsToBounds = YES;
    [self.layoutRgisterSucessContent addSubview:bgImg];
    [self.layoutRgisterSucessContent sendSubviewToBack:bgImg];
    
    [NSLayoutConstraint activateConstraints:@[
        [bgImg.topAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.topAnchor],
        [bgImg.leadingAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.leadingAnchor],
        [bgImg.trailingAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.trailingAnchor],
        [bgImg.bottomAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.bottomAnchor],
    ]];
    
    // --- 成功图标（使用 SF Symbol 绿色勾选圆圈）---
    UIImageView *tickIcon = [[UIImageView alloc] init];
    tickIcon.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:60 weight:UIImageSymbolWeightLight];
    tickIcon.image = [UIImage systemImageNamed:@"checkmark.circle" withConfiguration:iconConfig];
    tickIcon.tintColor = HexColor(0x4CD9A5);
    tickIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.layoutRgisterSucessContent addSubview:tickIcon];
    
    // --- "注册成功" 标题 ---
    UILabel *successTitle = [[UILabel alloc] init];
    successTitle.translatesAutoresizingMaskIntoConstraints = NO;
    successTitle.text = @"注册成功";
    successTitle.font = [UIFont boldSystemFontOfSize:26];
    successTitle.textColor = HexColor(0x1A1A1A);
    successTitle.textAlignment = NSTextAlignmentCenter;
    [self.layoutRgisterSucessContent addSubview:successTitle];
    
    // --- 描述文字 ---
    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    descLabel.text = @"恭喜，您已拥有登录账号！\n点击下方按钮前往登录，邀请好友开始聊天吧！";
    descLabel.font = [UIFont systemFontOfSize:14];
    descLabel.textColor = HexColor(0x999999);
    descLabel.textAlignment = NSTextAlignmentCenter;
    descLabel.numberOfLines = 0;
    [self.layoutRgisterSucessContent addSubview:descLabel];
    
    // --- 信息卡片（毛玻璃白色半透明）---
    UIView *infoCard = [[UIView alloc] init];
    infoCard.translatesAutoresizingMaskIntoConstraints = NO;
    infoCard.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
    infoCard.layer.cornerRadius = 16;
    infoCard.clipsToBounds = YES;
    infoCard.layer.borderWidth = 0.5;
    infoCard.layer.borderColor = HexColor(0xE0E0E0).CGColor;
    [self.layoutRgisterSucessContent addSubview:infoCard];
    
    // UID 行图标
    UIImageView *uidIcon = [[UIImageView alloc] init];
    uidIcon.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *smallConfig = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    uidIcon.image = [UIImage systemImageNamed:@"person.fill" withConfiguration:smallConfig];
    uidIcon.tintColor = HexColor(0x4CD9A5);
    [infoCard addSubview:uidIcon];
    
    UILabel *uidTitle = [[UILabel alloc] init];
    uidTitle.translatesAutoresizingMaskIntoConstraints = NO;
    uidTitle.text = @"用户UID";
    uidTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    uidTitle.textColor = HexColor(0x666666);
    [infoCard addSubview:uidTitle];
    
    self.viewID_afterRegisterSucess = [[UILabel alloc] init];
    self.viewID_afterRegisterSucess.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewID_afterRegisterSucess.text = userRegisterData.user_uid;
    self.viewID_afterRegisterSucess.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.viewID_afterRegisterSucess.textColor = HexColor(0x1A1A1A);
    self.viewID_afterRegisterSucess.textAlignment = NSTextAlignmentRight;
    [infoCard addSubview:self.viewID_afterRegisterSucess];
    
    // 分割线
    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = HexColor(0xF0F0F0);
    [infoCard addSubview:divider];
    
    // 手机号行图标
    UIImageView *phoneIcon = [[UIImageView alloc] init];
    phoneIcon.translatesAutoresizingMaskIntoConstraints = NO;
    phoneIcon.image = [UIImage systemImageNamed:@"phone.fill" withConfiguration:smallConfig];
    phoneIcon.tintColor = HexColor(0x4CD9A5);
    [infoCard addSubview:phoneIcon];
    
    UILabel *phoneTitle = [[UILabel alloc] init];
    phoneTitle.translatesAutoresizingMaskIntoConstraints = NO;
    phoneTitle.text = @"注册手机";
    phoneTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    phoneTitle.textColor = HexColor(0x666666);
    [infoCard addSubview:phoneTitle];
    
    self.viewPhone_afterRegisterSucess = [[UILabel alloc] init];
    self.viewPhone_afterRegisterSucess.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewPhone_afterRegisterSucess.text = userRegisterData.phoneNum;
    self.viewPhone_afterRegisterSucess.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.viewPhone_afterRegisterSucess.textColor = HexColor(0x1A1A1A);
    self.viewPhone_afterRegisterSucess.textAlignment = NSTextAlignmentRight;
    [infoCard addSubview:self.viewPhone_afterRegisterSucess];
    
    // --- "前往登录" 按钮 ---
    UIButton *btnGo = [UIButton buttonWithType:UIButtonTypeCustom];
    btnGo.translatesAutoresizingMaskIntoConstraints = NO;
    [btnGo setTitle:@"前往登录" forState:UIControlStateNormal];
    [btnGo setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btnGo setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
    btnGo.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    btnGo.backgroundColor = HexColor(0x4CD9A5);
    btnGo.layer.cornerRadius = 25;
    btnGo.clipsToBounds = YES;
    [btnGo addTarget:self action:@selector(clickStartNow:) forControlEvents:UIControlEventTouchUpInside];
    [self.layoutRgisterSucessContent addSubview:btnGo];
    
    // === 约束 ===
    UILayoutGuide *safeArea = self.layoutRgisterSucessContent.safeAreaLayoutGuide;
    
    [NSLayoutConstraint activateConstraints:@[
        // 成功图标
        [tickIcon.centerXAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.centerXAnchor],
        [tickIcon.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:60],
        [tickIcon.widthAnchor constraintEqualToConstant:80],
        [tickIcon.heightAnchor constraintEqualToConstant:80],
        
        // 标题
        [successTitle.centerXAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.centerXAnchor],
        [successTitle.topAnchor constraintEqualToAnchor:tickIcon.bottomAnchor constant:20],
        
        // 描述
        [descLabel.centerXAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.centerXAnchor],
        [descLabel.topAnchor constraintEqualToAnchor:successTitle.bottomAnchor constant:10],
        [descLabel.leadingAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.leadingAnchor constant:40],
        [descLabel.trailingAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.trailingAnchor constant:-40],
        
        // 信息卡片
        [infoCard.topAnchor constraintEqualToAnchor:descLabel.bottomAnchor constant:30],
        [infoCard.leadingAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.leadingAnchor constant:30],
        [infoCard.trailingAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.trailingAnchor constant:-30],
        
        // UID 行
        [uidIcon.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:20],
        [uidIcon.topAnchor constraintEqualToAnchor:infoCard.topAnchor constant:20],
        [uidIcon.widthAnchor constraintEqualToConstant:20],
        [uidIcon.heightAnchor constraintEqualToConstant:20],
        
        [uidTitle.leadingAnchor constraintEqualToAnchor:uidIcon.trailingAnchor constant:8],
        [uidTitle.centerYAnchor constraintEqualToAnchor:uidIcon.centerYAnchor],
        
        [self.viewID_afterRegisterSucess.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-20],
        [self.viewID_afterRegisterSucess.centerYAnchor constraintEqualToAnchor:uidIcon.centerYAnchor],
        
        // 分割线
        [divider.topAnchor constraintEqualToAnchor:uidIcon.bottomAnchor constant:16],
        [divider.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:20],
        [divider.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-20],
        [divider.heightAnchor constraintEqualToConstant:0.5],
        
        // 手机号行
        [phoneIcon.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:20],
        [phoneIcon.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:16],
        [phoneIcon.widthAnchor constraintEqualToConstant:20],
        [phoneIcon.heightAnchor constraintEqualToConstant:20],
        [phoneIcon.bottomAnchor constraintEqualToAnchor:infoCard.bottomAnchor constant:-20],
        
        [phoneTitle.leadingAnchor constraintEqualToAnchor:phoneIcon.trailingAnchor constant:8],
        [phoneTitle.centerYAnchor constraintEqualToAnchor:phoneIcon.centerYAnchor],
        
        [self.viewPhone_afterRegisterSucess.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-20],
        [self.viewPhone_afterRegisterSucess.centerYAnchor constraintEqualToAnchor:phoneIcon.centerYAnchor],
        
        // 前往登录按钮
        [btnGo.topAnchor constraintEqualToAnchor:infoCard.bottomAnchor constant:35],
        [btnGo.leadingAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.leadingAnchor constant:30],
        [btnGo.trailingAnchor constraintEqualToAnchor:self.layoutRgisterSucessContent.trailingAnchor constant:-30],
        [btnGo.heightAnchor constraintEqualToConstant:50],
    ]];
    
    [self.view addSubview:self.layoutRgisterSucessContent];
}

- (IBAction)clickStartNow:(id)sender
{
    [NotificationCenterFactory registerSucessBack_POST:self.registerData];
    [self.navigationController popViewControllerAnimated:YES];
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 表单数据
/////////////////////////////////////////////////////////////////////////////////////////////

- (UserRegisterDTO *)getFormData
{
    UserRegisterDTO *u = [[UserRegisterDTO alloc] init];
    u.neadPhone  = self.needSMS4Init;
    u.phoneNum = self.txtPhone.text;
    u.phoneSms = self.txtSms.text;
    u.nickname = self.txtNickname.text;
    u.user_mail = @"";
    u.user_psw = self.txtPassword.text;
    u.user_sex = [NSString stringWithFormat:@"%ld", (long)self.currentSex.tag];
    return u;
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 获取验证码的GetSMSButtonDelegate实现
/////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)getSmsBizType {
    return @"1";
}

- (NSString *)getPhoneNum {
    return self.txtPhone.text;
}

- (void)gotoRegisterPage {
    // do nothing
}

- (void)focusToInput
{
    [self.txtSms becomeFirstResponder];
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UITextFieldDelegate
/////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSInteger maxLen = 0;
    if (textField == self.txtPhone) {
        maxLen = 11;
    } else if (textField == self.txtSms) {
        maxLen = 4;
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

@end
