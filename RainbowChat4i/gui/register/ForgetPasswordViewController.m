//telegram @wz662
#import "ForgetPasswordViewController.h"
#import "BasicTool.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "IMClientManager.h"
#import "Default.h"


@interface ForgetPasswordViewController ()

// ========== Background ==========
@property (nonatomic, strong) UIImageView *bgImageView;

// ========== Header ==========
@property (nonatomic, strong) UILabel *lblTitle;
@property (nonatomic, strong) UILabel *lblSubtitle;

// ========== Form Area ==========
@property (nonatomic, strong) UIView *formContainer;

// --- 手机号 ---
@property (nonatomic, strong) UILabel *lblCountryCode;
@property (nonatomic, strong) UITextField *txtPhone;
@property (nonatomic, strong) UIView *phoneLineView;

// --- 验证码 ---
@property (nonatomic, strong) UITextField *txtSmsCode;
@property (nonatomic, strong) GetSMSButton *btnGetSMS;
@property (nonatomic, strong) UIView *smsLineView;

// --- 新密码 ---
@property (nonatomic, strong) UITextField *txtNewPassword;
@property (nonatomic, strong) UIButton *btnShowPassword;
@property (nonatomic, strong) UIView *passwordLineView;

// --- 确认新密码 ---
@property (nonatomic, strong) UITextField *txtConfirmPassword;
@property (nonatomic, strong) UIButton *btnShowConfirmPassword;
@property (nonatomic, strong) UIView *confirmPasswordLineView;

// --- 密码提示 ---
@property (nonatomic, strong) UILabel *lblPasswordHint;

// --- 提交按钮 ---
@property (nonatomic, strong) UIButton *btnResetPassword;

@end


@implementation ForgetPasswordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"重置密码";
    self.view.backgroundColor = [UIColor clearColor];
    
    // 实现点击空白处取消键盘显示
    self.view.userInteractionEnabled = YES;
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)];
    [self.view addGestureRecognizer:singleTap];
    
    [self buildUI];
    
    // 初始化验证码按钮
    self.btnGetSMS.parentVC = self;
    self.btnGetSMS.delegate = self;
    
    // 限制验证码输入长度为4位
    [self.txtSmsCode addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    
    // 检查用户是否已登录，自动填充手机号
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    if (localUser != nil && localUser.phoneNum != nil && localUser.phoneNum.length > 0) {
        self.txtPhone.text = localUser.phoneNum;
        self.txtPhone.enabled = NO;
        self.txtPhone.textColor = HexColor(0x999999);
    } else {
        self.txtPhone.enabled = YES;
    }
}

#pragma mark - 构建UI

- (void)buildUI
{
    [self buildHeaderArea];
    [self buildFormArea];
    [self buildSubmitButton];
}

- (void)buildHeaderArea
{
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    // --- 背景图 ---
    self.bgImageView = [[UIImageView alloc] init];
    self.bgImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgImageView.image = [UIImage imageNamed:@"main_login_form_bg_bottom32_v9_2"];
    self.bgImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.bgImageView.clipsToBounds = YES;
    [self.view addSubview:self.bgImageView];
    [self.view sendSubviewToBack:self.bgImageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.bgImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.bgImageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bgImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bgImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    
    // --- 标题 ---
    self.lblTitle = [[UILabel alloc] init];
    self.lblTitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblTitle.text = @"重置密码";
    self.lblTitle.font = [UIFont boldSystemFontOfSize:28];
    self.lblTitle.textColor = HexColor(0x1A1A1A);
    [self.view addSubview:self.lblTitle];
    
    // --- 副标题 ---
    self.lblSubtitle = [[UILabel alloc] init];
    self.lblSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblSubtitle.text = @"请输入注册手机号，获取验证码后重置密码";
    self.lblSubtitle.font = [UIFont systemFontOfSize:14];
    self.lblSubtitle.textColor = HexColor(0x999999);
    [self.view addSubview:self.lblSubtitle];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.lblTitle.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:20],
        [self.lblTitle.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        
        [self.lblSubtitle.topAnchor constraintEqualToAnchor:self.lblTitle.bottomAnchor constant:8],
        [self.lblSubtitle.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        [self.lblSubtitle.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-30],
    ]];
}

- (void)buildFormArea
{
    self.formContainer = [[UIView alloc] init];
    self.formContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.formContainer];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.formContainer.topAnchor constraintEqualToAnchor:self.lblSubtitle.bottomAnchor constant:40],
        [self.formContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        [self.formContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-30],
    ]];
    
    // === 手机号输入行 ===
    UIView *phoneRow = [[UIView alloc] init];
    phoneRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.formContainer addSubview:phoneRow];
    
    self.lblCountryCode = [[UILabel alloc] init];
    self.lblCountryCode.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblCountryCode.text = @"+86";
    self.lblCountryCode.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.lblCountryCode.textColor = HexColor(0x333333);
    [phoneRow addSubview:self.lblCountryCode];
    
    self.txtPhone = [[UITextField alloc] init];
    self.txtPhone.translatesAutoresizingMaskIntoConstraints = NO;
    self.txtPhone.placeholder = @"输入手机号码";
    self.txtPhone.font = [UIFont systemFontOfSize:16];
    self.txtPhone.textColor = HexColor(0x333333);
    self.txtPhone.keyboardType = UIKeyboardTypeDefault;
    self.txtPhone.delegate = self;
    self.txtPhone.textContentType = UITextContentTypeTelephoneNumber;
    [phoneRow addSubview:self.txtPhone];
    
    self.phoneLineView = [[UIView alloc] init];
    self.phoneLineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.phoneLineView.backgroundColor = HexColor(0xE0E0E0);
    [self.formContainer addSubview:self.phoneLineView];
    
    // === 验证码输入行 ===
    UIView *smsRow = [[UIView alloc] init];
    smsRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.formContainer addSubview:smsRow];
    
    self.txtSmsCode = [[UITextField alloc] init];
    self.txtSmsCode.translatesAutoresizingMaskIntoConstraints = NO;
    self.txtSmsCode.placeholder = @"输入验证码";
    self.txtSmsCode.font = [UIFont systemFontOfSize:16];
    self.txtSmsCode.textColor = HexColor(0x333333);
    self.txtSmsCode.keyboardType = UIKeyboardTypeDefault;
    self.txtSmsCode.delegate = self;
    [smsRow addSubview:self.txtSmsCode];
    
    self.btnGetSMS = [[GetSMSButton alloc] init];
    self.btnGetSMS.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnGetSMS.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.btnGetSMS setTitle:@"获取验证码" forState:UIControlStateNormal];
    [self.btnGetSMS setTitleColor:HexColor(0x4CD9A5) forState:UIControlStateNormal];
    [self.btnGetSMS setTitleColor:HexColor(0x999999) forState:UIControlStateDisabled];
    [self.btnGetSMS setTitleColor:[HexColor(0x4CD9A5) colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
    self.btnGetSMS.backgroundColor = [UIColor clearColor];
    // 覆盖 GetSMSButton 内部 configureView 设置的边框和圆角
    self.btnGetSMS.layer.borderWidth = 0;
    self.btnGetSMS.layer.cornerRadius = 0;
    [smsRow addSubview:self.btnGetSMS];
    
    self.smsLineView = [[UIView alloc] init];
    self.smsLineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.smsLineView.backgroundColor = HexColor(0xE0E0E0);
    [self.formContainer addSubview:self.smsLineView];
    
    // === 新密码输入行 ===
    UIView *passwordRow = [[UIView alloc] init];
    passwordRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.formContainer addSubview:passwordRow];
    
    self.txtNewPassword = [[UITextField alloc] init];
    self.txtNewPassword.translatesAutoresizingMaskIntoConstraints = NO;
    self.txtNewPassword.placeholder = @"请输入新密码";
    self.txtNewPassword.font = [UIFont systemFontOfSize:16];
    self.txtNewPassword.textColor = HexColor(0x333333);
    self.txtNewPassword.secureTextEntry = YES;
    self.txtNewPassword.textContentType = UITextContentTypeNewPassword;
    self.txtNewPassword.delegate = self;
    [passwordRow addSubview:self.txtNewPassword];
    
    self.btnShowPassword = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnShowPassword.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *eyeOff = [UIImage systemImageNamed:@"eye.slash"];
    UIImage *eyeOn  = [UIImage systemImageNamed:@"eye"];
    [self.btnShowPassword setImage:eyeOff forState:UIControlStateNormal];
    [self.btnShowPassword setImage:eyeOn  forState:UIControlStateSelected];
    self.btnShowPassword.tintColor = HexColor(0xBBBBBB);
    [self.btnShowPassword addTarget:self action:@selector(clickShowPassword:) forControlEvents:UIControlEventTouchUpInside];
    [passwordRow addSubview:self.btnShowPassword];
    
    self.passwordLineView = [[UIView alloc] init];
    self.passwordLineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.passwordLineView.backgroundColor = HexColor(0xE0E0E0);
    [self.formContainer addSubview:self.passwordLineView];
    
    // === 确认新密码输入行 ===
    UIView *confirmPasswordRow = [[UIView alloc] init];
    confirmPasswordRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.formContainer addSubview:confirmPasswordRow];
    
    self.txtConfirmPassword = [[UITextField alloc] init];
    self.txtConfirmPassword.translatesAutoresizingMaskIntoConstraints = NO;
    self.txtConfirmPassword.placeholder = @"请再次输入新密码";
    self.txtConfirmPassword.font = [UIFont systemFontOfSize:16];
    self.txtConfirmPassword.textColor = HexColor(0x333333);
    self.txtConfirmPassword.secureTextEntry = YES;
    self.txtConfirmPassword.textContentType = UITextContentTypeNewPassword;
    self.txtConfirmPassword.delegate = self;
    [confirmPasswordRow addSubview:self.txtConfirmPassword];
    
    self.btnShowConfirmPassword = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnShowConfirmPassword.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *cfEyeOff = [UIImage systemImageNamed:@"eye.slash"];
    UIImage *cfEyeOn  = [UIImage systemImageNamed:@"eye"];
    [self.btnShowConfirmPassword setImage:cfEyeOff forState:UIControlStateNormal];
    [self.btnShowConfirmPassword setImage:cfEyeOn  forState:UIControlStateSelected];
    self.btnShowConfirmPassword.tintColor = HexColor(0xBBBBBB);
    [self.btnShowConfirmPassword addTarget:self action:@selector(clickShowConfirmPassword:) forControlEvents:UIControlEventTouchUpInside];
    [confirmPasswordRow addSubview:self.btnShowConfirmPassword];
    
    self.confirmPasswordLineView = [[UIView alloc] init];
    self.confirmPasswordLineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.confirmPasswordLineView.backgroundColor = HexColor(0xE0E0E0);
    [self.formContainer addSubview:self.confirmPasswordLineView];
    
    // === 密码提示 ===
    self.lblPasswordHint = [[UILabel alloc] init];
    self.lblPasswordHint.translatesAutoresizingMaskIntoConstraints = NO;
    self.lblPasswordHint.text = @"密码必须大于或等于8位，且包含英文和数字";
    self.lblPasswordHint.font = [UIFont systemFontOfSize:12];
    self.lblPasswordHint.textColor = HexColor(0x999999);
    [self.formContainer addSubview:self.lblPasswordHint];
    
    // === 约束 ===
    [NSLayoutConstraint activateConstraints:@[
        // 手机号行
        [phoneRow.topAnchor constraintEqualToAnchor:self.formContainer.topAnchor],
        [phoneRow.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor],
        [phoneRow.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor],
        [phoneRow.heightAnchor constraintEqualToConstant:50],
        
        [self.lblCountryCode.leadingAnchor constraintEqualToAnchor:phoneRow.leadingAnchor],
        [self.lblCountryCode.centerYAnchor constraintEqualToAnchor:phoneRow.centerYAnchor],
        [self.lblCountryCode.widthAnchor constraintEqualToConstant:40],
        
        [self.txtPhone.leadingAnchor constraintEqualToAnchor:self.lblCountryCode.trailingAnchor constant:8],
        [self.txtPhone.trailingAnchor constraintEqualToAnchor:phoneRow.trailingAnchor],
        [self.txtPhone.topAnchor constraintEqualToAnchor:phoneRow.topAnchor],
        [self.txtPhone.bottomAnchor constraintEqualToAnchor:phoneRow.bottomAnchor],
        
        [self.phoneLineView.topAnchor constraintEqualToAnchor:phoneRow.bottomAnchor],
        [self.phoneLineView.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor],
        [self.phoneLineView.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor],
        [self.phoneLineView.heightAnchor constraintEqualToConstant:0.5],
        
        // 验证码行
        [smsRow.topAnchor constraintEqualToAnchor:self.phoneLineView.bottomAnchor constant:15],
        [smsRow.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor],
        [smsRow.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor],
        [smsRow.heightAnchor constraintEqualToConstant:50],
        
        [self.txtSmsCode.leadingAnchor constraintEqualToAnchor:smsRow.leadingAnchor],
        [self.txtSmsCode.topAnchor constraintEqualToAnchor:smsRow.topAnchor],
        [self.txtSmsCode.bottomAnchor constraintEqualToAnchor:smsRow.bottomAnchor],
        [self.txtSmsCode.trailingAnchor constraintEqualToAnchor:self.btnGetSMS.leadingAnchor constant:-8],
        
        [self.btnGetSMS.trailingAnchor constraintEqualToAnchor:smsRow.trailingAnchor],
        [self.btnGetSMS.centerYAnchor constraintEqualToAnchor:smsRow.centerYAnchor],
        [self.btnGetSMS.widthAnchor constraintEqualToConstant:110],
        [self.btnGetSMS.heightAnchor constraintEqualToConstant:34],
        
        [self.smsLineView.topAnchor constraintEqualToAnchor:smsRow.bottomAnchor],
        [self.smsLineView.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor],
        [self.smsLineView.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor],
        [self.smsLineView.heightAnchor constraintEqualToConstant:0.5],
        
        // 新密码行
        [passwordRow.topAnchor constraintEqualToAnchor:self.smsLineView.bottomAnchor constant:15],
        [passwordRow.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor],
        [passwordRow.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor],
        [passwordRow.heightAnchor constraintEqualToConstant:50],
        
        [self.txtNewPassword.leadingAnchor constraintEqualToAnchor:passwordRow.leadingAnchor],
        [self.txtNewPassword.topAnchor constraintEqualToAnchor:passwordRow.topAnchor],
        [self.txtNewPassword.bottomAnchor constraintEqualToAnchor:passwordRow.bottomAnchor],
        [self.txtNewPassword.trailingAnchor constraintEqualToAnchor:self.btnShowPassword.leadingAnchor constant:-8],
        
        [self.btnShowPassword.trailingAnchor constraintEqualToAnchor:passwordRow.trailingAnchor],
        [self.btnShowPassword.centerYAnchor constraintEqualToAnchor:passwordRow.centerYAnchor],
        [self.btnShowPassword.widthAnchor constraintEqualToConstant:30],
        [self.btnShowPassword.heightAnchor constraintEqualToConstant:30],
        
        [self.passwordLineView.topAnchor constraintEqualToAnchor:passwordRow.bottomAnchor],
        [self.passwordLineView.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor],
        [self.passwordLineView.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor],
        [self.passwordLineView.heightAnchor constraintEqualToConstant:0.5],
        
        // 确认新密码行
        [confirmPasswordRow.topAnchor constraintEqualToAnchor:self.passwordLineView.bottomAnchor],
        [confirmPasswordRow.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor],
        [confirmPasswordRow.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor],
        [confirmPasswordRow.heightAnchor constraintEqualToConstant:50],
        
        [self.txtConfirmPassword.leadingAnchor constraintEqualToAnchor:confirmPasswordRow.leadingAnchor],
        [self.txtConfirmPassword.topAnchor constraintEqualToAnchor:confirmPasswordRow.topAnchor],
        [self.txtConfirmPassword.bottomAnchor constraintEqualToAnchor:confirmPasswordRow.bottomAnchor],
        [self.txtConfirmPassword.trailingAnchor constraintEqualToAnchor:self.btnShowConfirmPassword.leadingAnchor constant:-8],
        
        [self.btnShowConfirmPassword.trailingAnchor constraintEqualToAnchor:confirmPasswordRow.trailingAnchor],
        [self.btnShowConfirmPassword.centerYAnchor constraintEqualToAnchor:confirmPasswordRow.centerYAnchor],
        [self.btnShowConfirmPassword.widthAnchor constraintEqualToConstant:30],
        [self.btnShowConfirmPassword.heightAnchor constraintEqualToConstant:30],
        
        [self.confirmPasswordLineView.topAnchor constraintEqualToAnchor:confirmPasswordRow.bottomAnchor],
        [self.confirmPasswordLineView.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor],
        [self.confirmPasswordLineView.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor],
        [self.confirmPasswordLineView.heightAnchor constraintEqualToConstant:0.5],
        
        // 密码提示
        [self.lblPasswordHint.topAnchor constraintEqualToAnchor:self.confirmPasswordLineView.bottomAnchor constant:10],
        [self.lblPasswordHint.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor],
        [self.lblPasswordHint.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor],
        
        // formContainer 底部
        [self.lblPasswordHint.bottomAnchor constraintEqualToAnchor:self.formContainer.bottomAnchor],
    ]];
}

- (void)buildSubmitButton
{
    self.btnResetPassword = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnResetPassword.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btnResetPassword setTitle:@"重置密码" forState:UIControlStateNormal];
    [self.btnResetPassword setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.btnResetPassword setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
    self.btnResetPassword.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    self.btnResetPassword.backgroundColor = HexColor(0x4CD9A5);
    self.btnResetPassword.layer.cornerRadius = 24;
    self.btnResetPassword.clipsToBounds = YES;
    [self.btnResetPassword addTarget:self action:@selector(clickResetPassword:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnResetPassword];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.btnResetPassword.topAnchor constraintEqualToAnchor:self.formContainer.bottomAnchor constant:30],
        [self.btnResetPassword.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        [self.btnResetPassword.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-30],
        [self.btnResetPassword.heightAnchor constraintEqualToConstant:48],
    ]];
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 事件处理
/////////////////////////////////////////////////////////////////////////////////////////////

-(void)fingerTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    [self.view endEditing:YES];
}

// 输入长度限制
- (void)textFieldInputLimit:(UITextField *)textField
{
    if(textField == self.txtSmsCode) {
        [BasicTool textFieldInputLimit:textField maxLen:4];
    }
}

// "显示密码"按钮的事件处理
- (void)clickShowPassword:(id)sender
{
    UIButton *b = (UIButton *)sender;
    b.selected = !b.selected;
    self.txtNewPassword.secureTextEntry = !self.txtNewPassword.secureTextEntry;
    if (self.txtNewPassword.secureTextEntry) {
        [self.txtNewPassword insertText:self.txtNewPassword.text];
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

// 重置密码按钮事件处理
- (void)clickResetPassword:(id)sender
{
    NSString *phoneNum = [BasicTool trim:self.txtPhone.text];
    NSString *smsCode = [BasicTool trim:self.txtSmsCode.text];
    NSString *newPassword = [BasicTool trim:self.txtNewPassword.text];
    
    // 验证手机号
    if([BasicTool isStringEmpty:phoneNum]){
        [BasicTool showAlertInfo:@"请输入手机号码!" parent:self];
        return;
    }
    
    if(![BasicTool verifyChineseMainlandPhone:phoneNum]){
        [BasicTool showAlertInfo:@"请输入正确的中国大陆手机号码!" parent:self];
        return;
    }
    
    // 验证验证码
    if([BasicTool isStringEmpty:smsCode]){
        [BasicTool showAlertInfo:@"请输入短信验证码!" parent:self];
        return;
    }
    
    if(smsCode.length != 4){
        [BasicTool showAlertInfo:@"验证码必须为4位数字!" parent:self];
        return;
    }
    
    // 验证新密码
    if([BasicTool isStringEmpty:newPassword]){
        [BasicTool showAlertInfo:@"请输入新密码!" parent:self];
        return;
    }
    
    // 新密码长度必须大于或等于8位
    if(newPassword.length < 8){
        [BasicTool showAlertInfo:@"密码长度必须大于或等于8位！" parent:self];
        return;
    }
    
    // 验证密码必须包含英文和数字
    BOOL hasLetter = NO;
    BOOL hasDigit = NO;
    
    for (int i = 0; i < newPassword.length; i++) {
        unichar c = [newPassword characterAtIndex:i];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
            hasLetter = YES;
        }
        if (c >= '0' && c <= '9') {
            hasDigit = YES;
        }
        if (hasLetter && hasDigit) {
            break;
        }
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
    NSString *confirmPassword = [BasicTool trim:self.txtConfirmPassword.text];
    if([BasicTool isStringEmpty:confirmPassword]){
        [BasicTool showAlertInfo:@"请再次输入新密码!" parent:self];
        return;
    }
    if(![newPassword isEqualToString:confirmPassword]){
        [BasicTool showAlertInfo:@"两次输入的密码不一致！" parent:self];
        return;
    }
    
    // 为了在block代码中安全地使用本类"self"
    __weak typeof(self) safeSelf = self;
    
    // 调用重置密码接口
    [[HttpRestHelper sharedInstance] submitResetPasswordByPhoneToServer:phoneNum smsCode:smsCode newPassword:newPassword complete:^(BOOL sucess, NSString *resultCode) {
        
        // 服务端处理成功完成
        if(sucess)
        {
            // 密码重置成功
            if([@"1" isEqualToString:resultCode])
            {
                [APP showUserDefineToast_OK:@"密码重置成功，请使用新密码登录"];
                [self.navigationController popViewControllerAnimated:YES];
            }
            else if([@"2" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"手机号未注册或格式不正确！" parent:safeSelf];
            }
            else if([@"3" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"短信验证码无效或已过期，请重新获取！" parent:safeSelf];
            }
            else if([@"4" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"新密码不能为空！" parent:safeSelf];
            }
            else
            {
                [BasicTool showAlertInfo:@"密码重置失败，您可稍后重试！" parent:safeSelf];
            }
        }
        else
        {
            [BasicTool showAlertInfo:@"重置失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
        }
    } hudParentView:self.view];
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 获取验证码的GetSMSButtonDelegate实现
/////////////////////////////////////////////////////////////////////////////////////////////

/** 短信验证码用于的业务类型（0 表示用于验证码登录功能中，1 表示用于注册新账号功能中， 2 表示用于手机号+验证码重置密码功能中） */
- (NSString *)getSmsBizType {
    return @"2";
}

/** 手机号码 */
- (NSString *)getPhoneNum {
    return self.txtPhone.text;
}

/** 验证码请求发出后，将输入焦点设置到验证码输入框里 */
- (void)focusToInput
{
    [self.txtSmsCode becomeFirstResponder];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSInteger maxLen = 0;
    if (textField == self.txtPhone) {
        maxLen = 11;
    } else if (textField == self.txtSmsCode) {
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
