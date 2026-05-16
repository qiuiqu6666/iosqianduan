//telegram @wz662
#import "ModifyEmailViewController.h"
#import "BasicTool.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "IMClientManager.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"

@interface ModifyEmailViewController () <UITextFieldDelegate>

@property (nonatomic, assign) BOOL hasOldEmail; // 用户是否已有邮箱
@property (nonatomic, assign) int oldEmailCodeCountdown; // 旧邮箱验证码倒计时
@property (nonatomic, assign) int emailCodeCountdown; // 新邮箱验证码倒计时
@property (nonatomic, strong) NSTimer *oldEmailCodeTimer; // 旧邮箱验证码倒计时定时器
@property (nonatomic, strong) NSTimer *emailCodeTimer; // 新邮箱验证码倒计时定时器

- (void)rb_modifyEmailApplyChromeNavigationBar;

@end

@implementation ModifyEmailViewController

- (instancetype)init
{
    self = [super initWithNibName:nil bundle:nil];
    return self;
}

- (void)loadView
{
    // 覆写 loadView 阻止 iOS 自动加载同名 XIB 文件
    self.view = [[UIView alloc] init];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 检查用户是否已有邮箱
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    self.hasOldEmail = (localUser != nil && ![BasicTool isStringEmpty:localUser.user_mail]);
    
    if (self.hasOldEmail) {
        self.title = @"修改邮箱";
    } else {
        self.title = @"绑定邮箱";
    }
    
    // 初始化倒计时
    self.oldEmailCodeCountdown = 0;
    self.emailCodeCountdown = 0;
    
    // 程序化构建UI
    [self buildUI];
    
    // 限制验证码输入长度为8位
    [self.txtOldEmailCode addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    [self.txtNewEmailCode addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    
    // 实现点击空白处取消键盘显示
    self.view.userInteractionEnabled = YES;
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)];
    [self.view addGestureRecognizer:singleTap];
    
    [self rb_modifyEmailApplyChromeNavigationBar];
}

- (void)rb_modifyEmailApplyChromeNavigationBar
{
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = @"";

    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @""];
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (!bar) {
        return;
    }
    [bar setBackButtonTarget:self action:@selector(doBack)];
    [bar clearRightAccessorySubviews];
    UIButton *done = [UIButton buttonWithType:UIButtonTypeCustom];
    [done setTitle:@"完成" forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [done setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [done setTitleColor:[UIColor colorWithWhite:0.55 alpha:1] forState:UIControlStateDisabled];
    [done addTarget:self action:@selector(clickSubmit:) forControlEvents:UIControlEventTouchUpInside];
    [done sizeToFit];
    done.bounds = CGRectMake(0, 0, MAX(44.f, CGRectGetWidth(done.bounds) + 12.f), 44.f);
    [bar attachRightAccessoryView:done];
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

- (void)dealloc
{
    if (self.oldEmailCodeTimer) {
        [self.oldEmailCodeTimer invalidate];
        self.oldEmailCodeTimer = nil;
    }
    if (self.emailCodeTimer) {
        [self.emailCodeTimer invalidate];
        self.emailCodeTimer = nil;
    }
}

#pragma mark - 构建UI

- (void)buildUI
{
    UIView *mainView = [[UIView alloc] initWithFrame:self.view.bounds];
    mainView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    mainView.backgroundColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.941 alpha:1.0]; // #F0F0F0
    
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    [mainView addSubview:scrollView];
    
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];
    
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:mainView.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:mainView.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:mainView.safeAreaLayoutGuide.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:mainView.bottomAnchor],
        
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],
    ]];
    
    // 上一个锚点，用于动态链接约束
    NSLayoutAnchor *lastAnchor = contentView.topAnchor;
    CGFloat lastSpacing = 10;
    
    // ============ 旧邮箱验证码区域（如果有旧邮箱才显示） ============
    if (self.hasOldEmail) {
        UIView *section1 = [[UIView alloc] init];
        section1.translatesAutoresizingMaskIntoConstraints = NO;
        section1.backgroundColor = [UIColor whiteColor];
        [contentView addSubview:section1];
        self.layoutOldEmail = section1;
        
        // 提示标签
        UILabel *oldEmailHint = [[UILabel alloc] init];
        oldEmailHint.translatesAutoresizingMaskIntoConstraints = NO;
        oldEmailHint.text = @"请先验证旧邮箱";
        oldEmailHint.font = [UIFont systemFontOfSize:13];
        oldEmailHint.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        [contentView addSubview:oldEmailHint];
        
        // 旧邮箱验证码行
        UILabel *oldCodeLabel = [[UILabel alloc] init];
        oldCodeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        oldCodeLabel.text = @"验证码";
        oldCodeLabel.font = [UIFont systemFontOfSize:17];
        oldCodeLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
        [section1 addSubview:oldCodeLabel];
        
        UITextField *oldCodeField = [[UITextField alloc] init];
        oldCodeField.translatesAutoresizingMaskIntoConstraints = NO;
        oldCodeField.placeholder = @"旧邮箱验证码";
        oldCodeField.font = [UIFont systemFontOfSize:17];
        oldCodeField.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
        oldCodeField.borderStyle = UITextBorderStyleNone;
        oldCodeField.delegate = self;
        oldCodeField.returnKeyType = UIReturnKeyDone;
        [section1 addSubview:oldCodeField];
        self.txtOldEmailCode = oldCodeField;
        
        UIButton *oldCodeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        oldCodeBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [oldCodeBtn setTitle:@"获取验证码" forState:UIControlStateNormal];
        oldCodeBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        [oldCodeBtn setTitleColor:[UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0] forState:UIControlStateNormal];
        [oldCodeBtn setTitleColor:[UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0] forState:UIControlStateDisabled];
        [oldCodeBtn addTarget:self action:@selector(clickGetOldEmailCode:) forControlEvents:UIControlEventTouchUpInside];
        [section1 addSubview:oldCodeBtn];
        self.btnGetOldEmailCode = oldCodeBtn;
        
        [NSLayoutConstraint activateConstraints:@[
            [oldEmailHint.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
            [oldEmailHint.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
            [oldEmailHint.topAnchor constraintEqualToAnchor:lastAnchor constant:lastSpacing],
            
            [section1.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
            [section1.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
            [section1.topAnchor constraintEqualToAnchor:oldEmailHint.bottomAnchor constant:8],
            [section1.heightAnchor constraintEqualToConstant:56],
            
            [oldCodeLabel.leadingAnchor constraintEqualToAnchor:section1.leadingAnchor constant:20],
            [oldCodeLabel.centerYAnchor constraintEqualToAnchor:section1.centerYAnchor],
            [oldCodeLabel.widthAnchor constraintEqualToConstant:65],
            
            [oldCodeField.leadingAnchor constraintEqualToAnchor:oldCodeLabel.trailingAnchor constant:12],
            [oldCodeField.centerYAnchor constraintEqualToAnchor:section1.centerYAnchor],
            
            [oldCodeBtn.leadingAnchor constraintEqualToAnchor:oldCodeField.trailingAnchor constant:8],
            [oldCodeBtn.trailingAnchor constraintEqualToAnchor:section1.trailingAnchor constant:-16],
            [oldCodeBtn.centerYAnchor constraintEqualToAnchor:section1.centerYAnchor],
            [oldCodeBtn.widthAnchor constraintEqualToConstant:90],
        ]];
        
        lastAnchor = section1.bottomAnchor;
        lastSpacing = 10;
    }
    
    // ============ 新邮箱 + 验证码区域 ============
    UIView *section2 = [[UIView alloc] init];
    section2.translatesAutoresizingMaskIntoConstraints = NO;
    section2.backgroundColor = [UIColor whiteColor];
    [contentView addSubview:section2];
    
    // 新邮箱行
    UIView *emailRow = [self createInputRowWithLabel:@"邮箱" placeholder:@"请输入新邮箱地址"];
    emailRow.translatesAutoresizingMaskIntoConstraints = NO;
    [section2 addSubview:emailRow];
    self.txtNewEmail = [emailRow viewWithTag:100];
    self.txtNewEmail.keyboardType = UIKeyboardTypeEmailAddress;
    self.txtNewEmail.textContentType = UITextContentTypeEmailAddress;
    
    UIView *sep = [self createSeparatorView];
    [section2 addSubview:sep];
    
    // 验证码行
    UILabel *codeLabel = [[UILabel alloc] init];
    codeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    codeLabel.text = @"验证码";
    codeLabel.font = [UIFont systemFontOfSize:17];
    codeLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    [section2 addSubview:codeLabel];
    
    UITextField *codeField = [[UITextField alloc] init];
    codeField.translatesAutoresizingMaskIntoConstraints = NO;
    codeField.placeholder = @"新邮箱验证码";
    codeField.font = [UIFont systemFontOfSize:17];
    codeField.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    codeField.borderStyle = UITextBorderStyleNone;
    codeField.delegate = self;
    codeField.returnKeyType = UIReturnKeyDone;
    [section2 addSubview:codeField];
    self.txtNewEmailCode = codeField;
    
    UIButton *getCodeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    getCodeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [getCodeBtn setTitle:@"获取验证码" forState:UIControlStateNormal];
    getCodeBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [getCodeBtn setTitleColor:[UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0] forState:UIControlStateNormal];
    [getCodeBtn setTitleColor:[UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0] forState:UIControlStateDisabled];
    [getCodeBtn addTarget:self action:@selector(clickGetNewEmailCode:) forControlEvents:UIControlEventTouchUpInside];
    [section2 addSubview:getCodeBtn];
    self.btnGetNewEmailCode = getCodeBtn;
    
    [NSLayoutConstraint activateConstraints:@[
        [section2.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section2.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [section2.topAnchor constraintEqualToAnchor:lastAnchor constant:lastSpacing],
        
        [emailRow.leadingAnchor constraintEqualToAnchor:section2.leadingAnchor],
        [emailRow.trailingAnchor constraintEqualToAnchor:section2.trailingAnchor],
        [emailRow.topAnchor constraintEqualToAnchor:section2.topAnchor],
        [emailRow.heightAnchor constraintEqualToConstant:56],
        
        [sep.leadingAnchor constraintEqualToAnchor:section2.leadingAnchor constant:20],
        [sep.trailingAnchor constraintEqualToAnchor:section2.trailingAnchor],
        [sep.topAnchor constraintEqualToAnchor:emailRow.bottomAnchor],
        [sep.heightAnchor constraintEqualToConstant:0.5],
        
        [codeLabel.leadingAnchor constraintEqualToAnchor:section2.leadingAnchor constant:20],
        [codeLabel.topAnchor constraintEqualToAnchor:sep.bottomAnchor],
        [codeLabel.heightAnchor constraintEqualToConstant:56],
        [codeLabel.centerYAnchor constraintEqualToAnchor:codeField.centerYAnchor],
        [codeLabel.widthAnchor constraintEqualToConstant:65],
        
        [codeField.leadingAnchor constraintEqualToAnchor:codeLabel.trailingAnchor constant:12],
        [codeField.topAnchor constraintEqualToAnchor:sep.bottomAnchor],
        [codeField.heightAnchor constraintEqualToConstant:56],
        
        [getCodeBtn.leadingAnchor constraintEqualToAnchor:codeField.trailingAnchor constant:8],
        [getCodeBtn.trailingAnchor constraintEqualToAnchor:section2.trailingAnchor constant:-16],
        [getCodeBtn.centerYAnchor constraintEqualToAnchor:codeField.centerYAnchor],
        [getCodeBtn.widthAnchor constraintEqualToConstant:90],
        
        [section2.bottomAnchor constraintEqualToAnchor:codeField.bottomAnchor],
    ]];
    
    // 提示文字
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.text = @"输入新邮箱地址，获取验证码后完成修改/绑定。";
    hintLabel.font = [UIFont systemFontOfSize:13];
    hintLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    hintLabel.numberOfLines = 0;
    [contentView addSubview:hintLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [hintLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [hintLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [hintLabel.topAnchor constraintEqualToAnchor:section2.bottomAnchor constant:8],
        [hintLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
    ]];
    
    self.view = mainView;
}

// 创建输入行（标签 + 输入框）
- (UIView *)createInputRowWithLabel:(NSString *)labelText placeholder:(NSString *)placeholder
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
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.returnKeyType = UIReturnKeyDone;
    textField.delegate = self;
    textField.borderStyle = UITextBorderStyleNone;
    textField.tag = 100;
    [row addSubview:textField];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.widthAnchor constraintEqualToConstant:65],
        
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

- (void)doBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

-(void)fingerTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    [self.view endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

// 输入长度限制
- (void)textFieldInputLimit:(UITextField *)textField
{
    if(textField == self.txtOldEmailCode || textField == self.txtNewEmailCode) {
        [BasicTool textFieldInputLimit:textField maxLen:8];// 邮箱验证码限长8位
    }
}

// 发送旧邮箱验证码
- (IBAction)clickGetOldEmailCode:(id)sender
{
    if (self.oldEmailCodeCountdown > 0) {
        [BasicTool showAlertWarn:@"验证码正在发送中，请稍后再试！" parent:self];
        return;
    }
    
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    NSString *oldEmail = localUser.user_mail;
    
    if ([BasicTool isStringEmpty:oldEmail]) {
        [BasicTool showAlertWarn:@"无法获取旧邮箱地址！" parent:self];
        return;
    }
    
    if (![BasicTool isValidEmail:oldEmail]) {
        [BasicTool showAlertWarn:@"旧邮箱格式不正确！" parent:self];
        return;
    }
    
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    // 开始倒计时
    self.oldEmailCodeCountdown = 60;
    [self.btnGetOldEmailCode setTitle:@"60秒后重试" forState:UIControlStateNormal];
    self.btnGetOldEmailCode.enabled = NO;
    
    self.oldEmailCodeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateOldEmailCodeCountdown:) userInfo:nil repeats:YES];
    
    // 调用发送邮箱验证码接口
    [[HttpRestHelper sharedInstance] submitGetEmailCode:oldEmail 
                                                      uid:localUser.user_uid 
                                                  bizType:@"3" 
                                                 complete:^(BOOL sucess, NSString *resultCode) {
        
        // 服务端处理成功完成
        if(sucess && ![BasicTool isStringEmpty:resultCode])
        {
            // 将JSON转成OC的Dictionary
            NSData *rdata = [resultCode dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary* jsonData = [NSJSONSerialization JSONObjectWithData:rdata options:NSJSONReadingMutableContainers error:nil];
            
            // 服务返回的查询结果码
            NSString *code = [jsonData objectForKey:@"code"];
            NSString *desc = [jsonData objectForKey:@"desc"];
            
            // 邮箱验证码发送成功
            if([@"1" isEqualToString:code]) {
                [APP showUserDefineToast_OK:@"验证码已发送至您的旧邮箱，请查收"];
                // 验证码输入框获得焦点
                [safeSelf.txtOldEmailCode becomeFirstResponder];
            }
            // 错误处理
            else {
                // 停止倒计时
                [safeSelf.oldEmailCodeTimer invalidate];
                safeSelf.oldEmailCodeTimer = nil;
                safeSelf.oldEmailCodeCountdown = 0;
                [safeSelf.btnGetOldEmailCode setTitle:@"获取验证码" forState:UIControlStateNormal];
                safeSelf.btnGetOldEmailCode.enabled = YES;
                
                NSString *errorMsg = desc ?: @"验证码发送失败";
                [BasicTool showAlertWarn:errorMsg parent:safeSelf];
            }
        }
        else
        {
            // 停止倒计时
            [safeSelf.oldEmailCodeTimer invalidate];
            safeSelf.oldEmailCodeTimer = nil;
            safeSelf.oldEmailCodeCountdown = 0;
            [safeSelf.btnGetOldEmailCode setTitle:@"获取验证码" forState:UIControlStateNormal];
            safeSelf.btnGetOldEmailCode.enabled = YES;
            
            [BasicTool showAlertWarn:@"验证码发送失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
        }
    } hudParentView:self.view];
}

// 发送新邮箱验证码
- (IBAction)clickGetNewEmailCode:(id)sender
{
    if (self.emailCodeCountdown > 0) {
        [BasicTool showAlertWarn:@"验证码正在发送中，请稍后再试！" parent:self];
        return;
    }
    
    NSString *newEmail = [BasicTool trim:self.txtNewEmail.text];
    
    if ([BasicTool isStringEmpty:newEmail]) {
        [BasicTool showAlertWarn:@"请输入新邮箱地址！" parent:self];
        return;
    }
    
    if (![BasicTool isValidEmail:newEmail]) {
        [BasicTool showAlertWarn:@"请输入正确的邮箱格式！" parent:self];
        return;
    }
    
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    // 开始倒计时
    self.emailCodeCountdown = 60;
    [self.btnGetNewEmailCode setTitle:@"60秒后重试" forState:UIControlStateNormal];
    self.btnGetNewEmailCode.enabled = NO;
    
    self.emailCodeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateEmailCodeCountdown:) userInfo:nil repeats:YES];
    
    // 调用发送邮箱验证码接口
    [[HttpRestHelper sharedInstance] submitGetEmailCode:newEmail 
                                                      uid:localUser.user_uid 
                                                  bizType:@"3" 
                                                 complete:^(BOOL sucess, NSString *resultCode) {
        
        // 服务端处理成功完成
        if(sucess && ![BasicTool isStringEmpty:resultCode])
        {
            // 将JSON转成OC的Dictionary
            NSData *rdata = [resultCode dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary* jsonData = [NSJSONSerialization JSONObjectWithData:rdata options:NSJSONReadingMutableContainers error:nil];
            
            // 服务返回的查询结果码
            NSString *code = [jsonData objectForKey:@"code"];
            NSString *desc = [jsonData objectForKey:@"desc"];
            
            // 邮箱验证码发送成功
            if([@"1" isEqualToString:code]) {
                [APP showUserDefineToast_OK:@"验证码已发送至您的新邮箱，请查收"];
                // 验证码输入框获得焦点
                [safeSelf.txtNewEmailCode becomeFirstResponder];
            }
            // 错误处理
            else {
                // 停止倒计时
                [safeSelf.emailCodeTimer invalidate];
                safeSelf.emailCodeTimer = nil;
                safeSelf.emailCodeCountdown = 0;
                [safeSelf.btnGetNewEmailCode setTitle:@"获取验证码" forState:UIControlStateNormal];
                safeSelf.btnGetNewEmailCode.enabled = YES;
                
                NSString *errorMsg = desc ?: @"验证码发送失败";
                [BasicTool showAlertWarn:errorMsg parent:safeSelf];
            }
        }
        else
        {
            // 停止倒计时
            [safeSelf.emailCodeTimer invalidate];
            safeSelf.emailCodeTimer = nil;
            safeSelf.emailCodeCountdown = 0;
            [safeSelf.btnGetNewEmailCode setTitle:@"获取验证码" forState:UIControlStateNormal];
            safeSelf.btnGetNewEmailCode.enabled = YES;
            
            [BasicTool showAlertWarn:@"验证码发送失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
        }
    } hudParentView:self.view];
}

// 旧邮箱验证码倒计时更新
- (void)updateOldEmailCodeCountdown:(NSTimer *)timer
{
    self.oldEmailCodeCountdown--;
    if (self.oldEmailCodeCountdown <= 0) {
        [self.oldEmailCodeTimer invalidate];
        self.oldEmailCodeTimer = nil;
        [self.btnGetOldEmailCode setTitle:@"获取验证码" forState:UIControlStateNormal];
        self.btnGetOldEmailCode.enabled = YES;
    } else {
        [self.btnGetOldEmailCode setTitle:[NSString stringWithFormat:@"%d秒后重试", self.oldEmailCodeCountdown] forState:UIControlStateNormal];
    }
}

// 新邮箱验证码倒计时更新
- (void)updateEmailCodeCountdown:(NSTimer *)timer
{
    self.emailCodeCountdown--;
    if (self.emailCodeCountdown <= 0) {
        [self.emailCodeTimer invalidate];
        self.emailCodeTimer = nil;
        [self.btnGetNewEmailCode setTitle:@"获取验证码" forState:UIControlStateNormal];
        self.btnGetNewEmailCode.enabled = YES;
    } else {
        [self.btnGetNewEmailCode setTitle:[NSString stringWithFormat:@"%d秒后重试", self.emailCodeCountdown] forState:UIControlStateNormal];
    }
}

// 提交按钮事件处理
- (IBAction)clickSubmit:(id)sender
{
    NSString *newEmail = [BasicTool trim:self.txtNewEmail.text];
    NSString *newEmailCode = [BasicTool trim:self.txtNewEmailCode.text];
    NSString *oldEmailCode = [BasicTool trim:self.txtOldEmailCode.text];
    
    // 验证新邮箱
    if([BasicTool isStringEmpty:newEmail]){
        [BasicTool showAlertInfo:@"请输入新邮箱地址!" parent:self];
        return;
    }
    
    if(![BasicTool isValidEmail:newEmail]){
        [BasicTool showAlertInfo:@"请输入正确的邮箱格式!" parent:self];
        return;
    }
    
    // 验证新邮箱验证码
    if([BasicTool isStringEmpty:newEmailCode]){
        [BasicTool showAlertInfo:@"请输入新邮箱验证码!" parent:self];
        return;
    }
    
    if(newEmailCode.length != 8){
        [BasicTool showAlertInfo:@"验证码必须为8位字符!" parent:self];
        return;
    }
    
    // 如果用户已有邮箱，需要验证旧邮箱验证码
    if (self.hasOldEmail) {
        if([BasicTool isStringEmpty:oldEmailCode]){
            [BasicTool showAlertInfo:@"请输入旧邮箱验证码!" parent:self];
            return;
        }
        
        if(oldEmailCode.length != 8){
            [BasicTool showAlertInfo:@"旧邮箱验证码必须为8位字符!" parent:self];
            return;
        }
    }
    
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    
    // 调用修改/绑定邮箱接口
    [[HttpRestHelper sharedInstance] submitModifyEmailToServer:localUser.user_uid 
                                                       newEmail:newEmail 
                                                   newEmailCode:newEmailCode 
                                                   oldEmailCode:(self.hasOldEmail ? oldEmailCode : nil) 
                                                       complete:^(BOOL sucess, NSString *resultCode) {
        
        // 服务端处理成功完成
        if(sucess)
        {
            // 修改成功
            if([@"1" isEqualToString:resultCode])
            {
                // 更新本地用户信息
                localUser.user_mail = newEmail;
                
                // 修改成功后，显示一个提示Toast
                [APP showUserDefineToast_OK:safeSelf.hasOldEmail ? @"邮箱修改成功" : @"邮箱绑定成功"];
                // 退出当前界面
                [safeSelf.navigationController popViewControllerAnimated:YES];
            }
            // 错误码处理
            else if([@"0" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"修改失败，可能是新邮箱格式不正确！" parent:safeSelf];
            }
            else if([@"2" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"新邮箱已被使用！" parent:safeSelf];
            }
            else if([@"3" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"旧邮箱验证码无效或已过期，请重新获取！" parent:safeSelf];
            }
            else if([@"4" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"新邮箱验证码无效或已过期，请重新获取！" parent:safeSelf];
            }
            else if([@"5" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"用户不存在！" parent:safeSelf];
            }
            else
            {
                [BasicTool showAlertInfo:@"修改失败，您可稍后重试！" parent:safeSelf];
            }
        }
        else
        {
            [BasicTool showAlertInfo:@"修改失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
        }
    } hudParentView:self.view];
}

@end
