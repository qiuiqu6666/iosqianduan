//telegram @wz662
#import "ModifyPhoneViewController.h"
#import "BasicTool.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "IMClientManager.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"

// 旧手机号验证码按钮的 Delegate
@interface OldPhoneSMSDelegate : NSObject<GetSMSButtonDelegate>
@property (nonatomic, weak) ModifyPhoneViewController *parentVC;
@end

// 新手机号验证码按钮的 Delegate
@interface NewPhoneSMSDelegate : NSObject<GetSMSButtonDelegate>
@property (nonatomic, weak) ModifyPhoneViewController *parentVC;
@end

@interface ModifyPhoneViewController ()

@property (nonatomic, assign) BOOL hasOldPhone; // 用户是否已有手机号
@property (nonatomic, strong) OldPhoneSMSDelegate *oldPhoneSMSDelegate; // 旧手机号验证码按钮的 delegate
@property (nonatomic, strong) NewPhoneSMSDelegate *phoneCodeDelegate; // 新手机号验证码按钮的 delegate

- (void)rb_modifyPhoneApplyChromeNavigationBar;

@end

@implementation OldPhoneSMSDelegate

- (NSString *)getSmsBizType {
    return @"2"; // 旧手机号验证码：使用 biz_type="2"（重置密码类型，用于验证已注册的手机号）
}

- (NSString *)getPhoneNum {
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    return localUser.phoneNum ?: @"";
}

- (void)focusToInput {
    [self.parentVC.txtOldPhoneSmsCode becomeFirstResponder];
}

@end

@implementation NewPhoneSMSDelegate

- (NSString *)getSmsBizType {
    return @"4"; // 新手机号验证码：使用 biz_type="4"（修改/绑定手机号）
}

- (NSString *)getPhoneNum {
    return self.parentVC.txtNewPhone.text;
}

- (void)focusToInput {
    [self.parentVC.txtNewPhoneSmsCode becomeFirstResponder];
}

@end

@implementation ModifyPhoneViewController

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
    
    // 检查用户是否已有手机号
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    self.hasOldPhone = (localUser != nil && ![BasicTool isStringEmpty:localUser.phoneNum]);
    
    if (self.hasOldPhone) {
        self.title = @"修改手机号";
    } else {
        self.title = @"绑定手机号";
    }
    
    // 创建 delegate 对象
    self.oldPhoneSMSDelegate = [[OldPhoneSMSDelegate alloc] init];
    self.oldPhoneSMSDelegate.parentVC = self;
    
    self.phoneCodeDelegate = [[NewPhoneSMSDelegate alloc] init];
    self.phoneCodeDelegate.parentVC = self;
    
    // 程序化构建UI
    [self buildUI];
    
    // 设置新手机号输入框的限制
    self.txtNewPhone.delegate = self;
    self.txtNewPhone.keyboardType = UIKeyboardTypeNumberPad;
    
    // 限制验证码输入长度为4位
    [self.txtOldPhoneSmsCode addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    [self.txtNewPhoneSmsCode addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    
    // 实现点击空白处取消键盘显示
    self.view.userInteractionEnabled = YES;
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)];
    [self.view addGestureRecognizer:singleTap];
    
    [self rb_modifyPhoneApplyChromeNavigationBar];
}

- (void)rb_modifyPhoneApplyChromeNavigationBar
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
    
    // ============ 旧手机号验证码区域（如果有旧手机号才显示） ============
    if (self.hasOldPhone) {
        UIView *section1 = [[UIView alloc] init];
        section1.translatesAutoresizingMaskIntoConstraints = NO;
        section1.backgroundColor = [UIColor whiteColor];
        [contentView addSubview:section1];
        self.layoutOldPhone = section1;
        
        // 提示标签
        UILabel *oldPhoneHint = [[UILabel alloc] init];
        oldPhoneHint.translatesAutoresizingMaskIntoConstraints = NO;
        oldPhoneHint.text = @"请先验证旧手机号";
        oldPhoneHint.font = [UIFont systemFontOfSize:13];
        oldPhoneHint.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        [contentView addSubview:oldPhoneHint];
        
        // 旧手机号验证码行
        UILabel *oldSmsLabel = [[UILabel alloc] init];
        oldSmsLabel.translatesAutoresizingMaskIntoConstraints = NO;
        oldSmsLabel.text = @"验证码";
        oldSmsLabel.font = [UIFont systemFontOfSize:17];
        oldSmsLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
        [section1 addSubview:oldSmsLabel];
        
        UITextField *oldSmsField = [[UITextField alloc] init];
        oldSmsField.translatesAutoresizingMaskIntoConstraints = NO;
        oldSmsField.placeholder = @"旧手机号验证码";
        oldSmsField.font = [UIFont systemFontOfSize:17];
        oldSmsField.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
        oldSmsField.keyboardType = UIKeyboardTypeNumberPad;
        oldSmsField.borderStyle = UITextBorderStyleNone;
        [section1 addSubview:oldSmsField];
        self.txtOldPhoneSmsCode = oldSmsField;
        
        GetSMSButton *oldSmsBtn = [[GetSMSButton alloc] init];
        oldSmsBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [oldSmsBtn setTitle:@"获取验证码" forState:UIControlStateNormal];
        oldSmsBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        [oldSmsBtn setTitleColor:[UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0] forState:UIControlStateNormal];
        [oldSmsBtn setTitleColor:[UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0] forState:UIControlStateDisabled];
        oldSmsBtn.backgroundColor = [UIColor clearColor];
        oldSmsBtn.layer.borderWidth = 0;
        oldSmsBtn.layer.cornerRadius = 0;
        oldSmsBtn.parentVC = self;
        oldSmsBtn.delegate = self.oldPhoneSMSDelegate;
        [section1 addSubview:oldSmsBtn];
        self.btnGetOldPhoneSMS = oldSmsBtn;
        
        [NSLayoutConstraint activateConstraints:@[
            [oldPhoneHint.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
            [oldPhoneHint.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
            [oldPhoneHint.topAnchor constraintEqualToAnchor:lastAnchor constant:lastSpacing],
            
            [section1.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
            [section1.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
            [section1.topAnchor constraintEqualToAnchor:oldPhoneHint.bottomAnchor constant:8],
            [section1.heightAnchor constraintEqualToConstant:56],
            
            [oldSmsLabel.leadingAnchor constraintEqualToAnchor:section1.leadingAnchor constant:20],
            [oldSmsLabel.centerYAnchor constraintEqualToAnchor:section1.centerYAnchor],
            [oldSmsLabel.widthAnchor constraintEqualToConstant:65],
            
            [oldSmsField.leadingAnchor constraintEqualToAnchor:oldSmsLabel.trailingAnchor constant:12],
            [oldSmsField.centerYAnchor constraintEqualToAnchor:section1.centerYAnchor],
            
            [oldSmsBtn.leadingAnchor constraintEqualToAnchor:oldSmsField.trailingAnchor constant:8],
            [oldSmsBtn.trailingAnchor constraintEqualToAnchor:section1.trailingAnchor constant:-16],
            [oldSmsBtn.centerYAnchor constraintEqualToAnchor:section1.centerYAnchor],
            [oldSmsBtn.widthAnchor constraintEqualToConstant:90],
        ]];
        
        lastAnchor = section1.bottomAnchor;
        lastSpacing = 10;
    }
    
    // ============ 新手机号 + 验证码区域 ============
    UIView *section2 = [[UIView alloc] init];
    section2.translatesAutoresizingMaskIntoConstraints = NO;
    section2.backgroundColor = [UIColor whiteColor];
    [contentView addSubview:section2];
    
    // 新手机号行
    UIView *phoneRow = [self createInputRowWithLabel:@"手机号" placeholder:@"请输入新手机号" keyboardType:UIKeyboardTypeNumberPad];
    phoneRow.translatesAutoresizingMaskIntoConstraints = NO;
    [section2 addSubview:phoneRow];
    self.txtNewPhone = [phoneRow viewWithTag:100];
    
    UIView *sep = [self createSeparatorView];
    [section2 addSubview:sep];
    
    // 验证码行
    UILabel *smsLabel = [[UILabel alloc] init];
    smsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    smsLabel.text = @"验证码";
    smsLabel.font = [UIFont systemFontOfSize:17];
    smsLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    [section2 addSubview:smsLabel];
    
    UITextField *smsField = [[UITextField alloc] init];
    smsField.translatesAutoresizingMaskIntoConstraints = NO;
    smsField.placeholder = @"新手机号验证码";
    smsField.font = [UIFont systemFontOfSize:17];
    smsField.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    smsField.keyboardType = UIKeyboardTypeNumberPad;
    smsField.borderStyle = UITextBorderStyleNone;
    [section2 addSubview:smsField];
    self.txtNewPhoneSmsCode = smsField;
    
    GetSMSButton *getSmsBtn = [[GetSMSButton alloc] init];
    getSmsBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [getSmsBtn setTitle:@"获取验证码" forState:UIControlStateNormal];
    getSmsBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [getSmsBtn setTitleColor:[UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0] forState:UIControlStateNormal];
    [getSmsBtn setTitleColor:[UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0] forState:UIControlStateDisabled];
    getSmsBtn.backgroundColor = [UIColor clearColor];
    getSmsBtn.layer.borderWidth = 0;
    getSmsBtn.layer.cornerRadius = 0;
    getSmsBtn.parentVC = self;
    getSmsBtn.delegate = self.phoneCodeDelegate;
    [section2 addSubview:getSmsBtn];
    self.btnGetNewPhoneSMS = getSmsBtn;
    
    [NSLayoutConstraint activateConstraints:@[
        [section2.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section2.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [section2.topAnchor constraintEqualToAnchor:lastAnchor constant:lastSpacing],
        
        [phoneRow.leadingAnchor constraintEqualToAnchor:section2.leadingAnchor],
        [phoneRow.trailingAnchor constraintEqualToAnchor:section2.trailingAnchor],
        [phoneRow.topAnchor constraintEqualToAnchor:section2.topAnchor],
        [phoneRow.heightAnchor constraintEqualToConstant:56],
        
        [sep.leadingAnchor constraintEqualToAnchor:section2.leadingAnchor constant:20],
        [sep.trailingAnchor constraintEqualToAnchor:section2.trailingAnchor],
        [sep.topAnchor constraintEqualToAnchor:phoneRow.bottomAnchor],
        [sep.heightAnchor constraintEqualToConstant:0.5],
        
        [smsLabel.leadingAnchor constraintEqualToAnchor:section2.leadingAnchor constant:20],
        [smsLabel.topAnchor constraintEqualToAnchor:sep.bottomAnchor],
        [smsLabel.heightAnchor constraintEqualToConstant:56],
        [smsLabel.centerYAnchor constraintEqualToAnchor:smsField.centerYAnchor],
        [smsLabel.widthAnchor constraintEqualToConstant:65],
        
        [smsField.leadingAnchor constraintEqualToAnchor:smsLabel.trailingAnchor constant:12],
        [smsField.topAnchor constraintEqualToAnchor:sep.bottomAnchor],
        [smsField.heightAnchor constraintEqualToConstant:56],
        
        [getSmsBtn.leadingAnchor constraintEqualToAnchor:smsField.trailingAnchor constant:8],
        [getSmsBtn.trailingAnchor constraintEqualToAnchor:section2.trailingAnchor constant:-16],
        [getSmsBtn.centerYAnchor constraintEqualToAnchor:smsField.centerYAnchor],
        [getSmsBtn.widthAnchor constraintEqualToConstant:90],
        
        [section2.bottomAnchor constraintEqualToAnchor:smsField.bottomAnchor],
    ]];
    
    // 提示文字
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.text = @"输入新手机号，获取验证码后完成修改/绑定。";
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
- (UIView *)createInputRowWithLabel:(NSString *)labelText placeholder:(NSString *)placeholder keyboardType:(UIKeyboardType)keyboardType
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
    textField.keyboardType = keyboardType;
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.returnKeyType = UIReturnKeyNext;
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

// 输入长度限制
- (void)textFieldInputLimit:(UITextField *)textField
{
    if(textField == self.txtOldPhoneSmsCode || textField == self.txtNewPhoneSmsCode) {
        [BasicTool textFieldInputLimit:textField maxLen:4];// 验证码限长4位
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

// 限制手机号输入框只能输入11位数字
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // 只对新手机号输入框进行限制
    if (textField == self.txtNewPhone) {
        // 限制只能输入数字
        NSCharacterSet *nonDigitCharacterSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        if ([string rangeOfCharacterFromSet:nonDigitCharacterSet].location != NSNotFound) {
            return NO; // 不允许输入非数字字符
        }
        
        // 限制最大长度为11位
        NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        if (newString.length > 11) {
            return NO; // 不允许超过11位
        }
        
        return YES;
    }
    
    // 其他输入框不限制
    return YES;
}

// 提交按钮事件处理
- (IBAction)clickSubmit:(id)sender
{
    NSString *newPhoneNum = [BasicTool trim:self.txtNewPhone.text];
    NSString *newPhoneSmsCode = [BasicTool trim:self.txtNewPhoneSmsCode.text];
    NSString *oldPhoneSmsCode = [BasicTool trim:self.txtOldPhoneSmsCode.text];
    
    // 验证新手机号
    if([BasicTool isStringEmpty:newPhoneNum]){
        [BasicTool showAlertInfo:@"请输入新手机号码!" parent:self];
        return;
    }
    
    if(![BasicTool verifyChineseMainlandPhone:newPhoneNum]){
        [BasicTool showAlertInfo:@"请输入正确的中国大陆手机号码!" parent:self];
        return;
    }
    
    // 验证新手机号验证码
    if([BasicTool isStringEmpty:newPhoneSmsCode]){
        [BasicTool showAlertInfo:@"请输入新手机号验证码!" parent:self];
        return;
    }
    
    if(newPhoneSmsCode.length != 4){
        [BasicTool showAlertInfo:@"验证码必须为4位数字!" parent:self];
        return;
    }
    
    // 如果用户已有手机号，需要验证旧手机号验证码
    if (self.hasOldPhone) {
        if([BasicTool isStringEmpty:oldPhoneSmsCode]){
            [BasicTool showAlertInfo:@"请输入旧手机号验证码!" parent:self];
            return;
        }
        
        if(oldPhoneSmsCode.length != 4){
            [BasicTool showAlertInfo:@"旧手机号验证码必须为4位数字!" parent:self];
            return;
        }
    }
    
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    
    // 调用修改/绑定手机号接口
    [[HttpRestHelper sharedInstance] submitModifyPhoneToServer:localUser.user_uid 
                                                    newPhoneNum:newPhoneNum 
                                              newPhoneSmsCode:newPhoneSmsCode 
                                              oldPhoneSmsCode:(self.hasOldPhone ? oldPhoneSmsCode : nil) 
                                                      complete:^(BOOL sucess, NSString *resultCode) {
        
        // 服务端处理成功完成
        if(sucess)
        {
            // 修改成功
            if([@"1" isEqualToString:resultCode])
            {
                // 更新本地用户信息
                localUser.phoneNum = newPhoneNum;
                
                // 修改成功后，显示一个提示Toast
                [APP showUserDefineToast_OK:self.hasOldPhone ? @"手机号修改成功" : @"手机号绑定成功"];
                // 退出当前界面
                [self.navigationController popViewControllerAnimated:YES];
            }
            // 错误码处理
            else if([@"0" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"修改失败，可能是新手机号格式不正确！" parent:safeSelf];
            }
            else if([@"2" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"新手机号已被使用！" parent:safeSelf];
            }
            else if([@"3" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"旧手机号验证码无效或已过期，请重新获取！" parent:safeSelf];
            }
            else if([@"4" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"新手机号验证码无效或已过期，请重新获取！" parent:safeSelf];
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

/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 获取验证码的GetSMSButtonDelegate实现
/////////////////////////////////////////////////////////////////////////////////////////////


@end
