#import "WalletModifyFundPasswordViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "IMClientManager.h"
#import "UserEntity.h"
#import "GetSMSButton.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"

@interface WalletModifyFundPasswordViewController ()
@property (nonatomic, strong) UITextField *editOldPsw;
@property (nonatomic, strong) UITextField *editNewPsw;
@property (nonatomic, strong) UITextField *editConfirmPsw;
@property (nonatomic, strong) UITextField *editSmsCode;
@property (nonatomic, strong) GetSMSButton *btnGetSMS;
@end

@implementation WalletModifyFundPasswordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"修改资金密码";
    
    // 检查登录状态和token
    if (![self checkLoginStatus]) {
        return;
    }
    
    // 构建微信风格密码修改界面
    [self buildPasswordEditUI];
    
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = @"";
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @""];
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (bar) {
        CGFloat pt0 = [BasicTool getAdjustedFontSize:17.f];
        bar.titleLabel.font = [UIFont boldSystemFontOfSize:pt0];
        bar.titleLabel.textColor = [UIColor labelColor];
        [bar setBackButtonTarget:self action:@selector(doBack)];
        [bar clearRightAccessorySubviews];
        UIButton *done = [UIButton buttonWithType:UIButtonTypeCustom];
        [done setTitle:@"完成" forState:UIControlStateNormal];
        done.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        [done setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [done setTitleColor:[UIColor colorWithWhite:0.55 alpha:1] forState:UIControlStateDisabled];
        [done addTarget:self action:@selector(doSave) forControlEvents:UIControlEventTouchUpInside];
        [done sizeToFit];
        CGFloat dw = MAX(44.f, CGRectGetWidth(done.bounds) + 12.f);
        done.bounds = CGRectMake(0, 0, dw, 44.f);
        [bar attachRightAccessoryView:done];
    }
    
    // 实现点击空白处取消键盘显示
    self.view.userInteractionEnabled = YES;
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)];
    [self.view addGestureRecognizer:singleTap];
    
    // 实现下滑手势隐藏输入键盘
    UISwipeGestureRecognizer *recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(fingerSwipeFrom:)];
    [recognizer setDirection:(UISwipeGestureRecognizerDirectionDown)];
    [self.view addGestureRecognizer:recognizer];
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

- (BOOL)checkLoginStatus
{
    // 检查用户是否已登录
    UserEntity *userInfo = [IMClientManager sharedInstance].localUserInfo;
    if (!userInfo || !userInfo.user_uid || userInfo.user_uid.length == 0) {
        [BasicTool showAlertInfo:@"请先登录" parent:self];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.navigationController popViewControllerAnimated:YES];
        });
        return NO;
    }
    
    // 检查token是否存在
    if (!userInfo.token || userInfo.token.length == 0) {
        [BasicTool showAlertInfo:@"登录已过期，请重新登录" parent:self];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.navigationController popViewControllerAnimated:YES];
        });
        return NO;
    }
    
    return YES;
}

// 构建密码修改界面（微信风格，与修改登录密码页面一致）
- (void)buildPasswordEditUI
{
    UIView *pwdView = [[UIView alloc] initWithFrame:self.view.bounds];
    pwdView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    pwdView.backgroundColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.941 alpha:1.0]; // #F0F0F0
    
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    [pwdView addSubview:scrollView];
    
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];
    
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:pwdView.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:pwdView.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:pwdView.safeAreaLayoutGuide.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:pwdView.bottomAnchor],
        
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],
    ]];
    
    // ============ 第一组：旧密码 + 新密码 + 确认密码 ============
    UIView *section1 = [[UIView alloc] init];
    section1.translatesAutoresizingMaskIntoConstraints = NO;
    section1.backgroundColor = [UIColor whiteColor];
    [contentView addSubview:section1];
    
    // 旧密码行
    UIView *oldPswRow = [self createPasswordRowWithLabel:@"旧密码" placeholder:@"请输入旧资金密码"];
    oldPswRow.translatesAutoresizingMaskIntoConstraints = NO;
    [section1 addSubview:oldPswRow];
    self.editOldPsw = [oldPswRow viewWithTag:100];
    
    UIView *sep1 = [self createSeparatorView];
    [section1 addSubview:sep1];
    
    // 新密码行
    UIView *newPswRow = [self createPasswordRowWithLabel:@"新密码" placeholder:@"请输入新资金密码"];
    newPswRow.translatesAutoresizingMaskIntoConstraints = NO;
    [section1 addSubview:newPswRow];
    self.editNewPsw = [newPswRow viewWithTag:100];
    
    UIView *sep2 = [self createSeparatorView];
    [section1 addSubview:sep2];
    
    // 确认密码行
    UIView *confirmPswRow = [self createPasswordRowWithLabel:@"确认密码" placeholder:@"请再次确认新资金密码"];
    confirmPswRow.translatesAutoresizingMaskIntoConstraints = NO;
    [section1 addSubview:confirmPswRow];
    self.editConfirmPsw = [confirmPswRow viewWithTag:100];
    
    [NSLayoutConstraint activateConstraints:@[
        [section1.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section1.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [section1.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:0],
        
        [oldPswRow.leadingAnchor constraintEqualToAnchor:section1.leadingAnchor],
        [oldPswRow.trailingAnchor constraintEqualToAnchor:section1.trailingAnchor],
        [oldPswRow.topAnchor constraintEqualToAnchor:section1.topAnchor],
        [oldPswRow.heightAnchor constraintEqualToConstant:56],
        
        [sep1.leadingAnchor constraintEqualToAnchor:section1.leadingAnchor constant:20],
        [sep1.trailingAnchor constraintEqualToAnchor:section1.trailingAnchor],
        [sep1.topAnchor constraintEqualToAnchor:oldPswRow.bottomAnchor],
        [sep1.heightAnchor constraintEqualToConstant:0.5],
        
        [newPswRow.leadingAnchor constraintEqualToAnchor:section1.leadingAnchor],
        [newPswRow.trailingAnchor constraintEqualToAnchor:section1.trailingAnchor],
        [newPswRow.topAnchor constraintEqualToAnchor:sep1.bottomAnchor],
        [newPswRow.heightAnchor constraintEqualToConstant:56],
        
        [sep2.leadingAnchor constraintEqualToAnchor:section1.leadingAnchor constant:20],
        [sep2.trailingAnchor constraintEqualToAnchor:section1.trailingAnchor],
        [sep2.topAnchor constraintEqualToAnchor:newPswRow.bottomAnchor],
        [sep2.heightAnchor constraintEqualToConstant:0.5],
        
        [confirmPswRow.leadingAnchor constraintEqualToAnchor:section1.leadingAnchor],
        [confirmPswRow.trailingAnchor constraintEqualToAnchor:section1.trailingAnchor],
        [confirmPswRow.topAnchor constraintEqualToAnchor:sep2.bottomAnchor],
        [confirmPswRow.heightAnchor constraintEqualToConstant:56],
        [confirmPswRow.bottomAnchor constraintEqualToAnchor:section1.bottomAnchor],
    ]];
    
    // 密码要求提示
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.text = @"资金密码必须为6位数字。";
    hintLabel.font = [UIFont systemFontOfSize:13];
    hintLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    [contentView addSubview:hintLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [hintLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [hintLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [hintLabel.topAnchor constraintEqualToAnchor:section1.bottomAnchor constant:8],
    ]];
    
    // ============ 第二组：短信验证码 ============
    UIView *section2 = [[UIView alloc] init];
    section2.translatesAutoresizingMaskIntoConstraints = NO;
    section2.backgroundColor = [UIColor whiteColor];
    [contentView addSubview:section2];
    
    // 验证码标签
    UILabel *smsLabel = [[UILabel alloc] init];
    smsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    smsLabel.text = @"验证码";
    smsLabel.font = [UIFont systemFontOfSize:17];
    smsLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    [section2 addSubview:smsLabel];
    
    // 验证码输入框
    UITextField *smsField = [[UITextField alloc] init];
    smsField.translatesAutoresizingMaskIntoConstraints = NO;
    smsField.placeholder = @"请输入验证码";
    smsField.font = [UIFont systemFontOfSize:17];
    smsField.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    smsField.keyboardType = UIKeyboardTypeNumberPad;
    smsField.textContentType = UITextContentTypeOneTimeCode;
    smsField.borderStyle = UITextBorderStyleNone;
    smsField.textAlignment = NSTextAlignmentLeft;
    [section2 addSubview:smsField];
    self.editSmsCode = smsField;
    
    // 获取验证码按钮
    GetSMSButton *getSmsBtn = [[GetSMSButton alloc] init];
    getSmsBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [getSmsBtn setTitle:@"获取验证码" forState:UIControlStateNormal];
    getSmsBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [getSmsBtn setTitleColor:[UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0] forState:UIControlStateNormal];
    [getSmsBtn setTitleColor:[UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0] forState:UIControlStateDisabled];
    getSmsBtn.backgroundColor = [UIColor clearColor];
    // 覆盖 GetSMSButton 内部的 configureView 设置的边框
    getSmsBtn.layer.borderWidth = 0;
    getSmsBtn.layer.cornerRadius = 0;
    getSmsBtn.parentVC = self;
    getSmsBtn.delegate = self;
    [section2 addSubview:getSmsBtn];
    self.btnGetSMS = getSmsBtn;
    
    [NSLayoutConstraint activateConstraints:@[
        [section2.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section2.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [section2.topAnchor constraintEqualToAnchor:hintLabel.bottomAnchor constant:10],
        [section2.heightAnchor constraintEqualToConstant:56],
        
        [smsLabel.leadingAnchor constraintEqualToAnchor:section2.leadingAnchor constant:20],
        [smsLabel.centerYAnchor constraintEqualToAnchor:section2.centerYAnchor],
        [smsLabel.widthAnchor constraintEqualToConstant:65],
        
        [smsField.leadingAnchor constraintEqualToAnchor:smsLabel.trailingAnchor constant:12],
        [smsField.centerYAnchor constraintEqualToAnchor:section2.centerYAnchor],
        
        [getSmsBtn.leadingAnchor constraintEqualToAnchor:smsField.trailingAnchor constant:8],
        [getSmsBtn.trailingAnchor constraintEqualToAnchor:section2.trailingAnchor constant:-16],
        [getSmsBtn.centerYAnchor constraintEqualToAnchor:section2.centerYAnchor],
        [getSmsBtn.widthAnchor constraintEqualToConstant:90],
        
        [section2.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
    ]];
    
    // 限制验证码输入长度为4位数字
    [self.editSmsCode addTarget:self action:@selector(smsCodeFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    
    self.view = pwdView;
}

// 创建密码输入行（标签 + 密码输入框）
- (UIView *)createPasswordRowWithLabel:(NSString *)labelText placeholder:(NSString *)placeholder
{
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = [UIColor clearColor];
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = labelText;
    label.font = [UIFont systemFontOfSize:17];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    [row addSubview:label];
    
    UITextField *textField = [[UITextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.placeholder = placeholder;
    textField.font = [UIFont systemFontOfSize:17];
    textField.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    textField.secureTextEntry = YES;
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.returnKeyType = UIReturnKeyDone;
    textField.borderStyle = UITextBorderStyleNone;
    textField.keyboardType = UIKeyboardTypeNumberPad; // 资金密码是6位数字
    textField.tag = 100;
    // 限制输入长度为6位数字
    [textField addTarget:self action:@selector(passwordFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    [row addSubview:textField];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.widthAnchor constraintEqualToConstant:80],
        
        [textField.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:12],
        [textField.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [textField.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    
    return row;
}

// 创建分隔线
- (UIView *)createSeparatorView
{
    UIView *sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
    return sep;
}

// 触屏手势：点击空白关闭输入键盘
- (void)fingerTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    [self.view endEditing:YES];
}

// 下滑手势：下滑屏幕关闭输入键盘
- (void)fingerSwipeFrom:(UISwipeGestureRecognizer *)recognizer
{
    if (recognizer.direction == UISwipeGestureRecognizerDirectionDown) {
        [self.editOldPsw resignFirstResponder];
        [self.editNewPsw resignFirstResponder];
        [self.editConfirmPsw resignFirstResponder];
        [self.editSmsCode resignFirstResponder];
    }
}

// 资金密码输入限制（6位数字）
- (void)passwordFieldInputLimit:(UITextField *)textField
{
    // 只允许输入数字
    NSString *text = textField.text;
    NSCharacterSet *nonDigitSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSString *filtered = [[text componentsSeparatedByCharactersInSet:nonDigitSet] componentsJoinedByString:@""];
    
    // 限制长度为6位
    if (filtered.length > 6) {
        filtered = [filtered substringToIndex:6];
    }
    
    if (![text isEqualToString:filtered]) {
        textField.text = filtered;
    }
}

// 验证码输入限制（4位数字）
- (void)smsCodeFieldInputLimit:(UITextField *)textField
{
    // 只允许输入数字
    NSString *text = textField.text;
    NSCharacterSet *nonDigitSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSString *filtered = [[text componentsSeparatedByCharactersInSet:nonDigitSet] componentsJoinedByString:@""];
    
    // 限制长度为4位
    if (filtered.length > 4) {
        filtered = [filtered substringToIndex:4];
    }
    
    if (![text isEqualToString:filtered]) {
        textField.text = filtered;
    }
}

// 从当前界面回退
- (void)doBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

// 提交修改
- (void)doSave
{
    if (![self checkLoginStatus]) return;
    
    NSString *oldPsw = [self.editOldPsw.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *newPsw = [self.editNewPsw.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *confirmPsw = [self.editConfirmPsw.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // 验证输入
    if ([BasicTool isStringEmpty:oldPsw]) {
        [BasicTool showAlertInfo:@"旧密码不可为空！" parent:self];
        return;
    }
    
    if ([BasicTool isStringEmpty:newPsw]) {
        [BasicTool showAlertInfo:@"新密码不可为空！" parent:self];
        return;
    }
    
    if ([BasicTool isStringEmpty:confirmPsw]) {
        [BasicTool showAlertInfo:@"确认密码不可为空！" parent:self];
        return;
    }
    
    // 验证密码长度（6位数字）
    if (oldPsw.length != 6) {
        [BasicTool showAlertInfo:@"旧密码必须为6位数字！" parent:self];
        return;
    }
    
    if (newPsw.length != 6) {
        [BasicTool showAlertInfo:@"新密码必须为6位数字！" parent:self];
        return;
    }
    
    if (confirmPsw.length != 6) {
        [BasicTool showAlertInfo:@"确认密码必须为6位数字！" parent:self];
        return;
    }
    
    // 验证两次输入的新密码是否一致
    if (![newPsw isEqualToString:confirmPsw]) {
        [BasicTool showAlertInfo:@"确认密码与新密码不相符，请再次输入！" parent:self];
        return;
    }
    
    // 旧密码和新密码不能相同
    if ([oldPsw isEqualToString:newPsw]) {
        [BasicTool showAlertInfo:@"新密码和旧密码相同，请输入不同的密码！" parent:self];
        return;
    }
    
    // 验证码验证
    NSString *smsCode = [self.editSmsCode.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([BasicTool isStringEmpty:smsCode]) {
        [BasicTool showAlertInfo:@"请输入短信验证码！" parent:self];
        return;
    }
    
    if (smsCode.length != 4) {
        [BasicTool showAlertInfo:@"验证码必须为4位数字！" parent:self];
        return;
    }
    
    // 提交修改
    // 手机号自动从用户信息中获取，不需要用户输入
    __weak typeof(self) wself = self;
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    [[HttpRestHelper sharedInstance] submitWalletModifyFundPasswordWithOldPassword:oldPsw newPassword:newPsw uid:uid phoneNum:nil smsCode:smsCode complete:^(BOOL sucess, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess) {
                [BasicTool showAlertInfo:@"修改成功" parent:wself];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [wself.navigationController popViewControllerAnimated:YES];
                });
            } else {
                NSString *errorMsg = msg ?: @"修改失败";
                if ([msg isEqualToString:@"2"]) {
                    errorMsg = @"原资金密码不正确";
                } else if ([msg isEqualToString:@"3"]) {
                    errorMsg = @"新密码长度不足。本应用要求6位数字；若仍提示不足，请确认后台配置 PASSWORD_MIN_LENGTH=6。";
                } else if ([msg isEqualToString:@"4"]) {
                    errorMsg = @"短信验证码无效或已过期，请重新获取！";
                } else if ([msg isEqualToString:@"5"]) {
                    errorMsg = @"手机号不存在，请先绑定手机号！";
                } else if ([msg isEqualToString:@"6"]) {
                    errorMsg = @"尚未设置过资金密码，请先设置资金密码";
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [wself.navigationController popViewControllerAnimated:YES];
                    });
                }
                
                NSString *lowerMsg = [errorMsg lowercaseString];
                BOOL isTokenExpired = ([lowerMsg containsString:@"token已失效"] || [lowerMsg containsString:@"token无效"] || [lowerMsg containsString:@"请重新登录"]);
                if (isTokenExpired) {
                    [BasicTool showAlertInfo:@"登录已过期，请重新登录" parent:wself];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [wself.navigationController popViewControllerAnimated:YES];
                    });
                } else {
                    [BasicTool showAlertInfo:errorMsg parent:wself];
                }
            }
        });
    } hudParentView:self.view];
}

/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 获取验证码的GetSMSButtonDelegate实现
/////////////////////////////////////////////////////////////////////////////////////////////

/** 短信验证码用于的业务类型（0 表示用于验证码登录功能中，1 表示用于注册新账号功能中， 2 表示用于手机号+验证码重置密码功能中） */
- (NSString *)getSmsBizType {
    return @"2"; // 修改密码使用 biz_type="2"
}

/** 手机号码 */
- (NSString *)getPhoneNum {
    // 获取当前登录用户的手机号
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    return localUser.phoneNum ?: @"";
}

/** 验证码请求发出后，将输入焦点设置到验证码输入框里 */
- (void)focusToInput
{
    [self.editSmsCode becomeFirstResponder];
}

@end
