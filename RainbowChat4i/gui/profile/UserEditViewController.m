//telegram @wz662
#import "UserEditViewController.h"
#import "UITextView+ZWPlaceHolder.h"
#import "UITextView+ZWLimitCounter.h"
#import "IMClientManager.h"
#import "ViewControllerFactory.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "BasicTool.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"

// 性别常量：男
#define SELECT_SEX_MAN   1
// 性别常量：女
#define SELECT_SEX_WOMAN 0

static NSString * const kNicknameCooldownEndKeyPrefix = @"nickname_cooldown_end_";
/// 「设置名字」页：最大字符数（与 UI 提示 x/15 一致）
static NSInteger const kUserNicknameMaxLength = 15;
/// 字数标签 tag（buildNicknameEditUI）
static NSInteger const kNicknameCountLabelTag = 2001;

@interface UserEditViewController ()
// 本次修改的内容
@property (nonatomic, assign) int changeType;
// 本字段仅在changeType为“修改性别“时有意义：表示当前选中的“性别”按钮
@property (nonatomic, retain) UIButton *currentSex;
/// 昵称是否可用（实时校验结果），仅名字编辑页使用
@property (nonatomic, assign) BOOL nicknameAvailable;
/// 自定义顶栏右侧「完成/保存」，供 updateDoneButtonState 启用/置灰
@property (nonatomic, weak) UIButton *rb_userEditDoneChromeButton;

- (void)rb_userEditInstallChromeNavigationBar;
@end

@implementation UserEditViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withChangeType:(int)changeType
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.changeType = changeType;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

     [self initGUI];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self rb_plainCustomNavHostViewWillAppear:animated];

    // 刷新字体大小（根据全局字体设置）
    [BasicTool refreshFontsForView:self.view];
    // 设置名字页：每次进入刷新「距离可再次修改」倒计时
    if (self.changeType == IS_CHANGE_NICKNAME) {
        UILabel *hint = [self.view viewWithTag:2000];
        if ([hint isKindOfClass:[UILabel class]]) hint.text = [self nicknameEditHintText];
        [self updateNicknameCharacterCountLabel];
    }
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

- (void)rb_userEditInstallChromeNavigationBar
{
    BOOL useChrome = (self.changeType == IS_CHANGE_SEX || self.changeType == IS_CHANGE_NICKNAME || self.changeType == IS_CHANGE_WHATSUP || self.changeType == IS_CHANGE_PASSWORD || self.changeType == IS_CHANGE_OTHERCAPTION);
    if (!useChrome) {
        return;
    }

    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = @"";

    NSString *titleStr = self.title ?: @"";
    [self rb_installPlainCustomNavigationBarWithTitle:titleStr];
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (!bar) {
        return;
    }

    [bar setBackButtonTarget:self action:@selector(doBack)];
    [bar clearRightAccessorySubviews];

    NSString *rightTitle = (self.changeType == IS_CHANGE_OTHERCAPTION) ? @"保存" : @"完成";
    UIButton *done = [UIButton buttonWithType:UIButtonTypeCustom];
    [done setTitle:rightTitle forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [done setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [done setTitleColor:[UIColor colorWithWhite:0.55 alpha:1] forState:UIControlStateDisabled];
    [done addTarget:self action:@selector(doSave:) forControlEvents:UIControlEventTouchUpInside];
    [done sizeToFit];
    CGFloat dw = MAX(44.f, CGRectGetWidth(done.bounds) + 12.f);
    done.bounds = CGRectMake(0, 0, dw, 44.f);
    self.rb_userEditDoneChromeButton = done;
    [bar attachRightAccessoryView:done];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - GUI相关的方法

- (void)initGUI
{
    switch(self.changeType)
    {
        case IS_CHANGE_SEX:
        {
            self.title = @"设置性别";
            
            // 程序化构建性别选择界面
            [self buildSexSelectionUI];
            
            // 初始化当前默认性别
            BOOL isMan = [[IMClientManager sharedInstance].localUserInfo isMan];
            self.currentSex = isMan ? self.btnSexMan : self.btnSexWoman;
            self.currentSex.selected = YES;
            [self refreshSexCheckmarks];

            break;
        }
        case IS_CHANGE_NICKNAME:
        {
            self.title = @"设置名字";
            
            // 程序化构建名字编辑界面
            [self buildNicknameEditUI];

            break;
        }
        case IS_CHANGE_WHATSUP:
        {
            self.title = @"设置个性签名";
            
            // 程序化构建签名编辑界面
            [self buildWhatsupEditUI];

            break;
        }
        case IS_CHANGE_OTHERCAPTION:
        {
            self.title = @"其它说明";
            // 将主view替换成此次要修改内容的view
            self.view = self.layoutEditOtherCaption;
            // 文本输入框的额外设置
            [self textViewSetup:self.editOtherCaption placeHolder:@"输入其它说明..." limitCount:250];
//            // 设置输入文本区的拉伸背景图（不然图片因组件在autolayout下自适配屏幕后而变形）
//            [BasicTool setStretchImage:self.editOtherCaptionBg capInsets:UIEdgeInsetsMake(7, 7, 7, 7) img:self.editOtherCaptionBg.image];
            // 数据初始化
            self.editOtherCaption.text = [IMClientManager sharedInstance].localUserInfo.userDesc;

            break;
        }
        case IS_CHANGE_PASSWORD:
        {
            self.title = @"修改密码";
            
            // 程序化构建微信风格密码修改界面
            [self buildPasswordEditUI];

            break;
        }
    }

    if (self.changeType == IS_CHANGE_NICKNAME) {
        [self.editNickname addTarget:self action:@selector(nicknameTextChanged:) forControlEvents:UIControlEventEditingChanged];
    }

    [self rb_userEditInstallChromeNavigationBar];

    if (self.changeType == IS_CHANGE_NICKNAME) {
        [self updateDoneButtonState];
    }

    // 实现点击空白处取消键盘显示
    self.view.userInteractionEnabled = YES;
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)];
    [self.view addGestureRecognizer:singleTap];

    // 实现下滑手势隐藏输入键盘
    UISwipeGestureRecognizer *recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(fingerSwipeFrom:)];
    [recognizer setDirection:(UISwipeGestureRecognizerDirectionDown)];
    [[self view] addGestureRecognizer:recognizer];
}

// 文本输入框的额外设置
- (void)textViewSetup:(UITextView *)editView placeHolder:(NSString *)placeHolderStr limitCount:(int)limitCount
{
    // 设置输入框的placeholder和输入字数限制
    editView.zw_placeHolder = placeHolderStr;
    // 设置输入字数限制
    editView.zw_limitCount = limitCount;
    // 设置字数限制提示ui的字体
    [editView.zw_inputLimitLabel setFont:[BasicTool getSystemFontOfSize:12]];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 手势事件处理

// 触屏手势：点击空白关闭输入键盘
-(void)fingerTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    [self.view endEditing:YES];
}

// 下滑手势：下滑屏幕关闭输入键盘
-(void)fingerSwipeFrom:(UISwipeGestureRecognizer *)recognizer
{
    if(recognizer.direction==UISwipeGestureRecognizerDirectionDown)
    {
        DDLogDebug(@"swipe down");

        // 关闭输入键盘
        switch(self.changeType)
        {
            case IS_CHANGE_NICKNAME:
            {
                [self.editNickname resignFirstResponder];
                break;
            }
            case IS_CHANGE_WHATSUP:
            {
                [self.editWhatsup resignFirstResponder];
                break;
            }
            case IS_CHANGE_OTHERCAPTION:
            {
                [self.editOtherCaption resignFirstResponder];
                break;
            }
            case IS_CHANGE_PASSWORD:
            {
                [self.editOldPsw resignFirstResponder];
                [self.editNewPsw resignFirstResponder];
                [self.editConfirmPsw resignFirstResponder];
                [self.editSmsCode resignFirstResponder];
                break;
            }
        }
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 按钮点击事件处理

// 构建密码修改界面（微信风格）
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
    UIView *oldPswRow = [self createPasswordRowWithLabel:@"旧密码" placeholder:@"请输入旧密码"];
    oldPswRow.translatesAutoresizingMaskIntoConstraints = NO;
    [section1 addSubview:oldPswRow];
    self.editOldPsw = [oldPswRow viewWithTag:100];
    
    UIView *sep1 = [self createSeparatorView];
    [section1 addSubview:sep1];
    
    // 新密码行
    UIView *newPswRow = [self createPasswordRowWithLabel:@"新密码" placeholder:@"请输入新密码"];
    newPswRow.translatesAutoresizingMaskIntoConstraints = NO;
    [section1 addSubview:newPswRow];
    self.editNewPsw = [newPswRow viewWithTag:100];
    
    UIView *sep2 = [self createSeparatorView];
    [section1 addSubview:sep2];
    
    // 确认密码行
    UIView *confirmPswRow = [self createPasswordRowWithLabel:@"确认密码" placeholder:@"请再次确认新密码"];
    confirmPswRow.translatesAutoresizingMaskIntoConstraints = NO;
    [section1 addSubview:confirmPswRow];
    self.editConfirmPsw = [confirmPswRow viewWithTag:100];
    
    [NSLayoutConstraint activateConstraints:@[
        [section1.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section1.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [section1.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        
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
    hintLabel.text = @"密码必须大于或等于8位，且包含英文和数字。";
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
    ]];
    
    // ============ 忘记旧密码链接 ============
    UIButton *forgotBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    forgotBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [forgotBtn setTitle:@"忘记旧密码？" forState:UIControlStateNormal];
    [forgotBtn setTitleColor:[UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0] forState:UIControlStateNormal];
    forgotBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    forgotBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [forgotBtn addTarget:self action:@selector(doForgotOldPassword:) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:forgotBtn];
    self.btnForgotPassword = forgotBtn;
    
    [NSLayoutConstraint activateConstraints:@[
        [forgotBtn.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [forgotBtn.topAnchor constraintEqualToAnchor:section2.bottomAnchor constant:12],
        [forgotBtn.heightAnchor constraintEqualToConstant:25],
        [forgotBtn.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
    ]];
    
    // 限制验证码输入长度为4位
    [self.editSmsCode addTarget:self action:@selector(textFieldInputLimit:) forControlEvents:UIControlEventEditingChanged];
    
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
    textField.textContentType = UITextContentTypeOneTimeCode;
    textField.tag = 100;
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

// 构建名字编辑界面（微信风格）
- (void)buildNicknameEditUI
{
    UIView *nameView = [[UIView alloc] initWithFrame:self.view.bounds];
    nameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    nameView.backgroundColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.941 alpha:1.0]; // #F0F0F0
    
    // 白色输入区域
    UIView *inputContainer = [[UIView alloc] init];
    inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
    inputContainer.backgroundColor = [UIColor whiteColor];
    [nameView addSubview:inputContainer];

    UILabel *countLabel = [[UILabel alloc] init];
    countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    countLabel.font = [UIFont systemFontOfSize:13];
    countLabel.textColor = [UIColor colorWithRed:0.55 green:0.55 blue:0.55 alpha:1.0];
    countLabel.textAlignment = NSTextAlignmentRight;
    countLabel.tag = kNicknameCountLabelTag;
    [nameView addSubview:countLabel];

    // 输入框
    UITextField *textField = [[UITextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.font = [UIFont systemFontOfSize:17];
    textField.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    NSString *initialNick = [IMClientManager sharedInstance].localUserInfo.nickname ?: @"";
    if ((NSInteger)initialNick.length > kUserNicknameMaxLength) {
        initialNick = [initialNick substringToIndex:(NSUInteger)kUserNicknameMaxLength];
    }
    textField.text = initialNick;
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.returnKeyType = UIReturnKeyDone;
    textField.borderStyle = UITextBorderStyleNone;
    textField.delegate = self;
    [inputContainer addSubview:textField];
    self.editNickname = textField;

    // 提示：名字一周只能修改一次；若在冷却期内则直接显示距离可再次修改的时间
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.font = [UIFont systemFontOfSize:13];
    hintLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    hintLabel.textAlignment = NSTextAlignmentLeft;
    hintLabel.numberOfLines = 0;
    hintLabel.tag = 2000;
    hintLabel.text = [self nicknameEditHintText];
    [nameView addSubview:hintLabel];

    // 昵称可用性提示（实时校验：可用 / 该昵称已被占用）
    UILabel *availabilityLabel = [[UILabel alloc] init];
    availabilityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    availabilityLabel.font = [UIFont systemFontOfSize:13];
    availabilityLabel.textAlignment = NSTextAlignmentLeft;
    availabilityLabel.tag = 2002;
    availabilityLabel.text = @"";
    [nameView addSubview:availabilityLabel];
    
    // 约束
    [NSLayoutConstraint activateConstraints:@[
        // 白色输入区域
        [inputContainer.leadingAnchor constraintEqualToAnchor:nameView.leadingAnchor],
        [inputContainer.trailingAnchor constraintEqualToAnchor:nameView.trailingAnchor],
        [inputContainer.topAnchor constraintEqualToAnchor:nameView.safeAreaLayoutGuide.topAnchor],
        [inputContainer.heightAnchor constraintEqualToConstant:56],
        
        // 输入框（全宽；字数在白条下方右侧）
        [textField.leadingAnchor constraintEqualToAnchor:inputContainer.leadingAnchor constant:16],
        [textField.trailingAnchor constraintEqualToAnchor:inputContainer.trailingAnchor constant:-16],
        [textField.centerYAnchor constraintEqualToAnchor:inputContainer.centerYAnchor],

        [countLabel.topAnchor constraintEqualToAnchor:inputContainer.bottomAnchor constant:6],
        [countLabel.trailingAnchor constraintEqualToAnchor:nameView.trailingAnchor constant:-16],

        // 提示文字
        [hintLabel.leadingAnchor constraintEqualToAnchor:nameView.leadingAnchor constant:16],
        [hintLabel.trailingAnchor constraintEqualToAnchor:nameView.trailingAnchor constant:-16],
        [hintLabel.topAnchor constraintEqualToAnchor:countLabel.bottomAnchor constant:8],

        // 可用性提示（在「一周只可修改一次」下方）
        [availabilityLabel.leadingAnchor constraintEqualToAnchor:nameView.leadingAnchor constant:16],
        [availabilityLabel.trailingAnchor constraintEqualToAnchor:nameView.trailingAnchor constant:-16],
        [availabilityLabel.topAnchor constraintEqualToAnchor:hintLabel.bottomAnchor constant:6],
    ]];
    
    self.view = nameView;
    self.nicknameAvailable = YES; // 初始与当前昵称相同时视为可用

    [self updateNicknameCharacterCountLabel];
    
    // 自动弹出键盘
    [textField becomeFirstResponder];
}

- (void)updateNicknameCharacterCountLabel
{
    UILabel *lab = [self.view viewWithTag:kNicknameCountLabelTag];
    if (![lab isKindOfClass:[UILabel class]] || self.editNickname == nil) {
        return;
    }
    NSInteger n = (NSInteger)self.editNickname.text.length;
    if (n > kUserNicknameMaxLength) {
        n = kUserNicknameMaxLength;
    }
    lab.text = [NSString stringWithFormat:@"%ld/%ld", (long)n, (long)kUserNicknameMaxLength];
}

/// 根据本地缓存的冷却结束时间，生成「一周只可修改一次」或「X天X小时后可再次修改」的提示文案
- (NSString *)nicknameEditHintText
{
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (uid.length == 0) return @"一周只可以修改一次";
    NSString *key = [kNicknameCooldownEndKeyPrefix stringByAppendingString:uid];
    NSTimeInterval end = [[NSUserDefaults standardUserDefaults] doubleForKey:key];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (end <= now) return @"一周只可以修改一次";
    NSInteger remainSeconds = (NSInteger)(end - now);
    if (remainSeconds <= 0) return @"一周只可以修改一次";
    NSInteger days = remainSeconds / 86400;
    NSInteger hours = (remainSeconds % 86400) / 3600;
    if (days > 0 || hours > 0) {
        return [NSString stringWithFormat:@"一周只可以修改一次，%ld天%ld小时后可再次修改", (long)days, (long)hours];
    }
    return @"一周只可以修改一次";
}

/// 保存昵称修改冷却结束时间（在 1008-1-8 返回 code=0 或 code=-2 且 remain_seconds>0 时调用）
+ (void)saveNicknameCooldownEndWithUid:(NSString *)uid remainSeconds:(NSInteger)remainSeconds
{
    if (uid.length == 0 || remainSeconds <= 0) return;
    NSTimeInterval end = [[NSDate date] timeIntervalSince1970] + (NSTimeInterval)remainSeconds;
    NSString *key = [kNicknameCooldownEndKeyPrefix stringByAppendingString:uid];
    [[NSUserDefaults standardUserDefaults] setDouble:end forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// 名字输入变化时更新完成按钮状态，并防抖触发昵称可用性校验
- (void)nicknameTextChanged:(UITextField *)textField
{
    if (textField.text.length > (NSUInteger)kUserNicknameMaxLength) {
        textField.text = [textField.text substringToIndex:(NSUInteger)kUserNicknameMaxLength];
    }
    [self updateNicknameCharacterCountLabel];
    [self updateDoneButtonState];

    // 防抖：取消上一次未执行的检查，延迟 0.4 秒再请求
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performNicknameAvailableCheck) object:nil];
    [self performSelector:@selector(performNicknameAvailableCheck) withObject:nil afterDelay:0.4];
}

// 执行昵称是否可用请求（1008-26-35），更新可用性标签
- (void)performNicknameAvailableCheck
{
    NSString *trimmed = [BasicTool trim:self.editNickname.text];
    UILabel *availabilityLabel = [self.view viewWithTag:2002];
    if (![availabilityLabel isKindOfClass:[UILabel class]]) return;

    if (trimmed.length == 0) {
        availabilityLabel.text = @"";
        availabilityLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        self.nicknameAvailable = YES;
        return;
    }

    NSString *currentNick = [IMClientManager sharedInstance].localUserInfo.nickname;
    if ([trimmed isEqualToString:currentNick]) {
        availabilityLabel.text = @"可用";
        availabilityLabel.textColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0];
        self.nicknameAvailable = YES;
        return;
    }

    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitNicknameAvailableCheck:[IMClientManager sharedInstance].localUserInfo.user_uid
                                                        nickname:trimmed
                                                        complete:^(BOOL sucess, BOOL available, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UILabel *label = [wself.view viewWithTag:2002];
            if (![label isKindOfClass:[UILabel class]]) return;
            wself.nicknameAvailable = available;
            if (available) {
                label.text = @"可用";
                label.textColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0];
            } else {
                label.text = msg.length > 0 ? msg : @"该昵称已被占用";
                label.textColor = [UIColor colorWithRed:0.95 green:0.3 blue:0.2 alpha:1.0];
            }
        });
    } hudParentView:nil];
}

// 文本输入限制：名字最多 15 个字符
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == self.editNickname) {
        NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
        if ((NSInteger)newText.length > kUserNicknameMaxLength) {
            textField.text = [newText substringToIndex:(NSUInteger)kUserNicknameMaxLength];
            [self updateNicknameCharacterCountLabel];
            [self updateDoneButtonState];
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performNicknameAvailableCheck) object:nil];
            [self performSelector:@selector(performNicknameAvailableCheck) withObject:nil afterDelay:0.4];
            return NO;
        }
    }
    return YES;
}

// 更新完成按钮的可用状态
- (void)updateDoneButtonState
{
    UIButton *doneBtn = self.rb_userEditDoneChromeButton;
    if (doneBtn) {
        BOOL hasText = self.editNickname.text.length > 0;
        NSString *originalName = [IMClientManager sharedInstance].localUserInfo.nickname;
        BOOL changed = ![self.editNickname.text isEqualToString:originalName];
        doneBtn.enabled = hasText && changed;
        doneBtn.alpha = (hasText && changed) ? 1.0 : 0.5;
    }
}

// 构建个性签名编辑界面（微信风格）
- (void)buildWhatsupEditUI
{
    UIView *whatsupView = [[UIView alloc] initWithFrame:self.view.bounds];
    whatsupView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    whatsupView.backgroundColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.941 alpha:1.0]; // #F0F0F0
    
    // 白色输入区域
    UIView *inputContainer = [[UIView alloc] init];
    inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
    inputContainer.backgroundColor = [UIColor whiteColor];
    [whatsupView addSubview:inputContainer];
    
    // 多行文本输入框
    UITextView *textView = [[UITextView alloc] init];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.font = [UIFont systemFontOfSize:17];
    textView.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    textView.text = [IMClientManager sharedInstance].localUserInfo.whatsUp;
    textView.backgroundColor = [UIColor clearColor];
    textView.textContainerInset = UIEdgeInsetsMake(0, 0, 0, 0);
    textView.textContainer.lineFragmentPadding = 0;
    [inputContainer addSubview:textView];
    self.editWhatsup = textView;
    
    // 字数限制标签
    UILabel *countLabel = [[UILabel alloc] init];
    countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    countLabel.font = [UIFont systemFontOfSize:15];
    countLabel.textColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1.0];
    countLabel.textAlignment = NSTextAlignmentRight;
    countLabel.tag = 2001;
    [inputContainer addSubview:countLabel];
    
    // 计算剩余字数（个性签名最大 50 字）
    NSInteger maxLen = 50;
    NSInteger remaining = maxLen - (textView.text ? textView.text.length : 0);
    countLabel.text = [NSString stringWithFormat:@"%ld", (long)remaining];
    
    // 约束
    [NSLayoutConstraint activateConstraints:@[
        // 白色输入区域
        [inputContainer.leadingAnchor constraintEqualToAnchor:whatsupView.leadingAnchor],
        [inputContainer.trailingAnchor constraintEqualToAnchor:whatsupView.trailingAnchor],
        [inputContainer.topAnchor constraintEqualToAnchor:whatsupView.safeAreaLayoutGuide.topAnchor],
        [inputContainer.heightAnchor constraintEqualToConstant:100],
        
        // 文本输入框
        [textView.leadingAnchor constraintEqualToAnchor:inputContainer.leadingAnchor constant:16],
        [textView.trailingAnchor constraintEqualToAnchor:inputContainer.trailingAnchor constant:-16],
        [textView.topAnchor constraintEqualToAnchor:inputContainer.topAnchor constant:12],
        [textView.bottomAnchor constraintEqualToAnchor:countLabel.topAnchor constant:-4],
        
        // 字数限制标签
        [countLabel.trailingAnchor constraintEqualToAnchor:inputContainer.trailingAnchor constant:-16],
        [countLabel.bottomAnchor constraintEqualToAnchor:inputContainer.bottomAnchor constant:-8],
        [countLabel.heightAnchor constraintEqualToConstant:18],
    ]];
    
    self.view = whatsupView;
    
    // 监听文本变化
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(whatsupTextDidChange:)
                                                 name:UITextViewTextDidChangeNotification
                                               object:textView];
    
    // 自动弹出键盘
    [textView becomeFirstResponder];
}

// 签名文本变化时更新字数
- (void)whatsupTextDidChange:(NSNotification *)notification
{
    // 个性签名最大 50 字
    NSInteger maxLen = 50;
    UITextView *textView = notification.object;
    
    // 限制字数
    if (textView.text.length > maxLen) {
        textView.text = [textView.text substringToIndex:maxLen];
    }
    
    // 更新剩余字数
    NSInteger remaining = maxLen - textView.text.length;
    UILabel *countLabel = [self.view viewWithTag:2001];
    countLabel.text = [NSString stringWithFormat:@"%ld", (long)remaining];
}

// 构建性别选择界面（微信风格）
- (void)buildSexSelectionUI
{
    UIView *sexView = [[UIView alloc] initWithFrame:self.view.bounds];
    sexView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    sexView.backgroundColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.941 alpha:1.0]; // #F0F0F0
    
    // 白色区域容器
    UIView *whiteSection = [[UIView alloc] init];
    whiteSection.translatesAutoresizingMaskIntoConstraints = NO;
    whiteSection.backgroundColor = [UIColor whiteColor];
    [sexView addSubview:whiteSection];
    
    // 男 行
    UIButton *manRow = [UIButton buttonWithType:UIButtonTypeCustom];
    manRow.translatesAutoresizingMaskIntoConstraints = NO;
    manRow.tag = SELECT_SEX_MAN;
    manRow.backgroundColor = [UIColor clearColor];
    [manRow addTarget:self action:@selector(clickSexCondition:) forControlEvents:UIControlEventTouchUpInside];
    [whiteSection addSubview:manRow];
    self.btnSexMan = manRow;
    
    UILabel *manLabel = [[UILabel alloc] init];
    manLabel.translatesAutoresizingMaskIntoConstraints = NO;
    manLabel.text = @"男";
    manLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    manLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    manLabel.userInteractionEnabled = NO;
    [manRow addSubview:manLabel];
    
    UIImageView *manCheck = [[UIImageView alloc] init];
    manCheck.translatesAutoresizingMaskIntoConstraints = NO;
    manCheck.tag = 1001;
    manCheck.hidden = YES;
    manCheck.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
        manCheck.image = [UIImage systemImageNamed:@"checkmark" withConfiguration:config];
        manCheck.tintColor = [UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0]; // #34C759
    }
    [manRow addSubview:manCheck];
    
    // 分隔线
    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
    [whiteSection addSubview:separator];
    
    // 女 行
    UIButton *womanRow = [UIButton buttonWithType:UIButtonTypeCustom];
    womanRow.translatesAutoresizingMaskIntoConstraints = NO;
    womanRow.tag = SELECT_SEX_WOMAN;
    womanRow.backgroundColor = [UIColor clearColor];
    [womanRow addTarget:self action:@selector(clickSexCondition:) forControlEvents:UIControlEventTouchUpInside];
    [whiteSection addSubview:womanRow];
    self.btnSexWoman = womanRow;
    
    UILabel *womanLabel = [[UILabel alloc] init];
    womanLabel.translatesAutoresizingMaskIntoConstraints = NO;
    womanLabel.text = @"女";
    womanLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    womanLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    womanLabel.userInteractionEnabled = NO;
    [womanRow addSubview:womanLabel];
    
    UIImageView *womanCheck = [[UIImageView alloc] init];
    womanCheck.translatesAutoresizingMaskIntoConstraints = NO;
    womanCheck.tag = 1002;
    womanCheck.hidden = YES;
    womanCheck.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
        womanCheck.image = [UIImage systemImageNamed:@"checkmark" withConfiguration:config];
        womanCheck.tintColor = [UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0]; // #34C759
    }
    [womanRow addSubview:womanCheck];
    
    // 约束
    [NSLayoutConstraint activateConstraints:@[
        // 白色区域
        [whiteSection.leadingAnchor constraintEqualToAnchor:sexView.leadingAnchor],
        [whiteSection.trailingAnchor constraintEqualToAnchor:sexView.trailingAnchor],
        [whiteSection.topAnchor constraintEqualToAnchor:sexView.safeAreaLayoutGuide.topAnchor],
        
        // 男 行
        [manRow.leadingAnchor constraintEqualToAnchor:whiteSection.leadingAnchor],
        [manRow.trailingAnchor constraintEqualToAnchor:whiteSection.trailingAnchor],
        [manRow.topAnchor constraintEqualToAnchor:whiteSection.topAnchor],
        [manRow.heightAnchor constraintEqualToConstant:56],
        
        [manLabel.leadingAnchor constraintEqualToAnchor:manRow.leadingAnchor constant:20],
        [manLabel.centerYAnchor constraintEqualToAnchor:manRow.centerYAnchor],
        
        [manCheck.trailingAnchor constraintEqualToAnchor:manRow.trailingAnchor constant:-20],
        [manCheck.centerYAnchor constraintEqualToAnchor:manRow.centerYAnchor],
        [manCheck.widthAnchor constraintEqualToConstant:22],
        [manCheck.heightAnchor constraintEqualToConstant:22],
        
        // 分隔线
        [separator.leadingAnchor constraintEqualToAnchor:whiteSection.leadingAnchor constant:20],
        [separator.trailingAnchor constraintEqualToAnchor:whiteSection.trailingAnchor],
        [separator.topAnchor constraintEqualToAnchor:manRow.bottomAnchor],
        [separator.heightAnchor constraintEqualToConstant:0.5],
        
        // 女 行
        [womanRow.leadingAnchor constraintEqualToAnchor:whiteSection.leadingAnchor],
        [womanRow.trailingAnchor constraintEqualToAnchor:whiteSection.trailingAnchor],
        [womanRow.topAnchor constraintEqualToAnchor:manRow.bottomAnchor],
        [womanRow.heightAnchor constraintEqualToConstant:56],
        [womanRow.bottomAnchor constraintEqualToAnchor:whiteSection.bottomAnchor],
        
        [womanLabel.leadingAnchor constraintEqualToAnchor:womanRow.leadingAnchor constant:20],
        [womanLabel.centerYAnchor constraintEqualToAnchor:womanRow.centerYAnchor],
        
        [womanCheck.trailingAnchor constraintEqualToAnchor:womanRow.trailingAnchor constant:-20],
        [womanCheck.centerYAnchor constraintEqualToAnchor:womanRow.centerYAnchor],
        [womanCheck.widthAnchor constraintEqualToConstant:22],
        [womanCheck.heightAnchor constraintEqualToConstant:22],
    ]];
    
    self.view = sexView;
}

// 刷新性别选择的勾选状态
- (void)refreshSexCheckmarks
{
    UIImageView *manCheck = [self.view viewWithTag:1001];
    UIImageView *womanCheck = [self.view viewWithTag:1002];
    manCheck.hidden = (self.currentSex != self.btnSexMan);
    womanCheck.hidden = (self.currentSex != self.btnSexWoman);
}

// 本事件处理仅在changeType为"修改性别"时有意义："性别"选择按钮事件处理（实现性别男、女的单选效果）
- (IBAction)clickSexCondition:(id)sender
{
    UIButton *b = (UIButton *)sender;
    if(self.currentSex != b)
    {
        self.currentSex.selected = NO;
        self.currentSex = b;
        self.currentSex.selected = YES;
        [self refreshSexCheckmarks];
    }
}

// 处理修改密码界面上的忘记旧密码按钮事件
-(void)doForgotOldPassword:(UIButton *) button
{
    [ViewControllerFactory goForgetPasswordViewController:self.navigationController];
}

// 处理右上角保存按钮事件
- (void)doSave:(UIButton*)sender
{
    switch(self.changeType)
    {
        case IS_CHANGE_SEX:
        {
            [self doSaveForSex];
            break;
        }
        case IS_CHANGE_NICKNAME:
        {
            [self doSaveForNickname];
            break;
        }
        case IS_CHANGE_WHATSUP:
        {
            [self doSaveForWhatsup];
            break;
        }
        case IS_CHANGE_OTHERCAPTION:
        {
            [self doSaveForOtherCaption];
            break;
        }
        case IS_CHANGE_PASSWORD:
        {
            [self doSaveForChangepassword];
            break;
        }
    }
}

// 提交修改：其它说明
- (void)doSaveForOtherCaption
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;

    NSString *newOtherCaption = [BasicTool trim:self.editOtherCaption.text];
    NSString *oldOtherCaption = localRee.userDesc;
    
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;

    // 修改后的内容跟修改前的不相等才需要提交哦
    if([BasicTool isStringEmpty:oldOtherCaption] || ![oldOtherCaption isEqualToString:newOtherCaption])
    {
        [[HttpRestHelper sharedInstance] submitUserOtherCaptionModifiyToServer:localRee.user_uid otherCaption:newOtherCaption complete:^(BOOL sucess, NSString *resultCode) {

            // 服务端处理成功完成
            if(sucess && [@"1" isEqualToString:resultCode])
            {
                // 将本次修改后的最新内容更新到本地用户的个人信息全局变量
                localRee.userDesc = newOtherCaption;

                // 保存成功后，显示一个提示Toast
                [APP showUserDefineToast_OK:@"保存成功"];
                // 退出当前界面
                [self doBack];
            }
            else
            {
                [BasicTool showAlertInfo:@"保存失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
            }
        } hudParentView:self.view];
    }
    // 没有修改，不需要提交到服务端，直接退出当前界面即可
    else
    {
        [self doBack];
    }
}

// 提交修改：昵称
- (void)doSaveForNickname
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;

    NSString *newNickname = [BasicTool trim:self.editNickname.text];
    NSString *oldNickname = localRee.nickname;
    
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;

    if(![BasicTool isStringEmpty:newNickname])
    {
        // 修改后的内容跟修改前的不相等才需要提交哦
        if(![oldNickname isEqualToString:newNickname])
        {
            // 因此处只需要更新Nickname，但接口是同时更新包括性别在内的两个字段，为了到服务端更新时不会把sex置空，这里把它未修改的值也原样传过去就好了
            [[HttpRestHelper sharedInstance] submitUserBaseInfoModifiyToServer:localRee.user_uid nick:newNickname sex:localRee.user_sex complete:^(BOOL sucess, NSString *resultCode) {
                if (!sucess) {
                    [BasicTool showAlertInfo:@"保存失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
                    return;
                }
                NSInteger code = 0;
                NSInteger remainSeconds = 0;
                NSString *msg = nil;
                if (resultCode.length > 0) {
                    NSData *data = [resultCode dataUsingEncoding:NSUTF8StringEncoding];
                    NSError *err = nil;
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
                    if (!err && [json isKindOfClass:[NSDictionary class]]) {
                        if ([json[@"code"] isKindOfClass:[NSNumber class]]) code = [json[@"code"] integerValue];
                        else if ([json[@"code"] isKindOfClass:[NSString class]]) code = [json[@"code"] integerValue];
                        if ([json[@"remain_seconds"] isKindOfClass:[NSNumber class]]) remainSeconds = [json[@"remain_seconds"] integerValue];
                        else if ([json[@"remain_seconds"] isKindOfClass:[NSString class]]) remainSeconds = [json[@"remain_seconds"] integerValue];
                        if ([json[@"msg"] isKindOfClass:[NSString class]]) msg = json[@"msg"];
                    } else if ([@"1" isEqualToString:resultCode]) { code = 0; }
                } else {
                    [BasicTool showAlertInfo:@"保存失败，请稍后重试！" parent:safeSelf];
                    return;
                }
                if (code == 0) {
                    localRee.nickname = newNickname;
                    if (remainSeconds > 0) {
                        [UserEditViewController saveNicknameCooldownEndWithUid:localRee.user_uid remainSeconds:remainSeconds];
                    }
                    [APP showUserDefineToast_OK:@"完成"];
                    [safeSelf doBack];
                } else if (code == -2) {
                    if (remainSeconds > 0) {
                        [UserEditViewController saveNicknameCooldownEndWithUid:localRee.user_uid remainSeconds:remainSeconds];
                    }
                    NSInteger days = remainSeconds / 86400;
                    NSInteger hours = (remainSeconds % 86400) / 3600;
                    NSString *tip = msg.length > 0 ? msg : @"昵称 7 天内仅可修改一次";
                    if (remainSeconds > 0) tip = [NSString stringWithFormat:@"%@，%ld天%ld小时后可再次修改", tip, (long)days, (long)hours];
                    [BasicTool showAlertInfo:tip parent:safeSelf];
                } else if (code == -3) {
                    [BasicTool showAlertInfo:(msg.length > 0 ? msg : @"该昵称已被占用，请换一个") parent:safeSelf];
                } else {
                    [BasicTool showAlertInfo:(msg.length > 0 ? msg : @"保存失败，请稍后重试！") parent:safeSelf];
                }
            } hudParentView:self.view];
        }
        // 没有修改，不需要提交到服务端，直接退出当前界面即可
        else
        {
            [self doBack];
        }
    }
    else
    {
        [BasicTool showAlertInfo:@"昵称不能为空" parent:self];
    }
}

// 提交修改：性别
- (void)doSaveForSex
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;

    NSString *newSex = [NSString stringWithFormat:@"%ld", (long)self.currentSex.tag];
    NSString *oldSex = localRee.user_sex;
    
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;

        // 修改后的内容跟修改前的不相等才需要提交哦
        if(![oldSex isEqualToString:newSex])
        {
            // 因此处只需要更新性别，但接口是同时更新包括昵称在内的两个字段，为了到服务端更新时不会把nickname置空，这里把它未修改的值也原样传过去就好了
            [[HttpRestHelper sharedInstance] submitUserBaseInfoModifiyToServer:localRee.user_uid nick:localRee.nickname sex:newSex complete:^(BOOL sucess, NSString *resultCode) {

                if (!sucess) {
                    [BasicTool showAlertInfo:@"保存失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
                    return;
                }
                // 与 1008-1-8 实际返回一致：retValue 为 JSON（如 {"msg":"OK","code":0,...}），勿再用字面量 @"1" 判断
                NSInteger code = NSIntegerMin;
                NSString *msg = nil;
                if (resultCode.length > 0) {
                    NSData *data = [resultCode dataUsingEncoding:NSUTF8StringEncoding];
                    NSError *err = nil;
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
                    if (!err && [json isKindOfClass:[NSDictionary class]]) {
                        if ([json[@"code"] isKindOfClass:[NSNumber class]]) code = [json[@"code"] integerValue];
                        else if ([json[@"code"] isKindOfClass:[NSString class]]) code = [json[@"code"] integerValue];
                        if ([json[@"msg"] isKindOfClass:[NSString class]]) msg = json[@"msg"];
                    } else if ([@"1" isEqualToString:resultCode]) {
                        code = 0;
                    }
                }
                if (code == NSIntegerMin) {
                    [BasicTool showAlertInfo:@"保存失败，请稍后重试！" parent:safeSelf];
                    return;
                }
                if (code == 0) {
                    localRee.user_sex = newSex;
                    [APP showUserDefineToast_OK:@"保存成功"];
                    [safeSelf doBack];
                } else {
                    [BasicTool showAlertInfo:(msg.length > 0 ? msg : @"保存失败，请稍后重试！") parent:safeSelf];
                }
            } hudParentView:self.view];
        }
        // 没有修改，不需要提交到服务端，直接退出当前界面即可
        else
        {
            [self doBack];
        }
}

// 提交修改：个人签名
- (void)doSaveForWhatsup
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;

    NSString *newWhatsup = [BasicTool trim:self.editWhatsup.text];
    NSString *oldWhatsup = localRee.whatsUp;

    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    // 修改后的内容跟修改前的不相等才需要提交哦
    if([BasicTool isStringEmpty:oldWhatsup] || ![oldWhatsup isEqualToString:newWhatsup])
    {
        [[HttpRestHelper sharedInstance] submitUserWhatsUpModifiyToServer:localRee.user_uid whatsUp:newWhatsup complete:^(BOOL sucess, NSString *resultCode) {

            // 服务端处理成功完成
            if(sucess && [@"1" isEqualToString:resultCode])
            {
                // 将本次修改后的最新内容更新到本地用户的个人信息全局变量
                localRee.whatsUp = newWhatsup;

                // 保存成功后，显示一个提示Toast
                [APP showUserDefineToast_OK:@"保存成功"];
                // 退出当前界面
                [self doBack];
            }
            else
            {
                [BasicTool showAlertInfo:@"保存失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
            }
        } hudParentView:self.view];
    }
    // 没有修改，不需要提交到服务端，直接退出当前界面即可
    else
    {
        [self doBack];
    }
}

// 提交修改：修改密码
- (void)doSaveForChangepassword
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;

    NSString *newPsw = self.editNewPsw.text;
    NSString *oldPsw = self.editOldPsw.text;
    
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;

    // 检查密码合法性
    if([self checkPasswordValide])
    {
        NSString *smsCode = self.editSmsCode.text;
        [[HttpRestHelper sharedInstance] submitUserPasswordModifiyToServer:localRee.user_uid old:oldPsw new:newPsw smsCode:smsCode complete:^(BOOL sucess, NSString *resultCode) {

            // 服务端处理成功完成
            if(sucess)
            {
                // 密码修改成功（具体接口返回值意义请参见【接口1008-1-9】的文档说明）
                if([@"1" isEqualToString:resultCode])
                {
                    // 保存成功后，显示一个提示Toast
                    [APP showUserDefineToast_OK:@"保存成功"];
                    // 退出当前界面
                    [self doBack];
                }
                // （具体接口返回值意义请参见【接口1008-1-9】的文档说明）
                else if([@"2" isEqualToString:resultCode])
                {
                    [BasicTool showAlertInfo:@"原密码输入有误，请确认！" parent:safeSelf];
                }
                else if([@"3" isEqualToString:resultCode])
                {
                    [BasicTool showAlertInfo:@"手机号不存在，请先绑定手机号！" parent:safeSelf];
                }
                else if([@"4" isEqualToString:resultCode])
                {
                    [BasicTool showAlertInfo:@"短信验证码无效或已过期，请重新获取！" parent:safeSelf];
                }
                else
                {
                    [BasicTool showAlertInfo:@"密码修改失败，您可稍后重试！" parent:safeSelf];
                }
            }
            else
            {
                [BasicTool showAlertInfo:@"保存失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
            }
        } hudParentView:self.view];
    }
}

// 从当前界面回退
- (void)doBack
{
    // 并在Toast消失时退出添加好友界面
    [self.navigationController popViewControllerAnimated:YES];
}

// 修改密码时的合法性检查
- (BOOL) checkPasswordValide
{
    NSString *oldPsw = self.editOldPsw.text;
    NSString *newPsw = self.editNewPsw.text;
    NSString *reNewPsw = self.editConfirmPsw.text;

    // 当前密码是否为空
    if ([BasicTool isStringEmpty:oldPsw])
    {
        [BasicTool showAlertInfo:@"旧密码不可为空！" parent:self];
        return NO;
    }

    // 新密码是否为空
    if ([BasicTool isStringEmpty:newPsw])
    {
        [BasicTool showAlertInfo:@"新密码不可为空！" parent:self];
        return NO;
    }

    // 确认密码是否为空
    if([BasicTool isStringEmpty:reNewPsw])
    {
        [BasicTool showAlertInfo:@"确认密码不可为空！" parent:self];
        return NO;
    }
    
    // 验证码是否为空
    if([BasicTool isStringEmpty:self.editSmsCode.text])
    {
        [BasicTool showAlertInfo:@"请输入短信验证码！" parent:self];
        return NO;
    }
    
    // 验证码长度验证（4位）
    if(self.editSmsCode.text.length != 4)
    {
        [BasicTool showAlertInfo:@"验证码必须为4位数字！" parent:self];
        return NO;
    }

    // 两次输入新密码是否一致
    if (![newPsw isEqualToString:reNewPsw])
    {
        [BasicTool showAlertInfo:@"确认密码与新密码不相符，请再次输入！" parent:self];
        return NO;
    }

    // 新密码长度必须大于或等于8位（至少8位）
    if ([newPsw length] < 8)
    {
        [BasicTool showAlertInfo:@"密码长度必须大于或等于8位！" parent:self];
        return NO;
    }
    
    // 验证密码必须包含英文和数字
    BOOL hasLetter = NO;
    BOOL hasDigit = NO;
    
    for (int i = 0; i < newPsw.length; i++) {
        unichar c = [newPsw characterAtIndex:i];
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
        return NO;
    }
    if (!hasDigit) {
        [BasicTool showAlertInfo:@"密码必须包含至少一个数字！" parent:self];
        return NO;
    }

    // 旧登录密码与新密码是相同的（未修改！）
    if ([oldPsw isEqualToString:newPsw])
    {
        [BasicTool showAlertInfo:@"新密码和旧密码相同，请输入不同的密码！" parent:self];
        return NO;
    }

    return YES;
}

// 输入长度限制
- (void)textFieldInputLimit:(UITextField *)textField
{
    if(textField == self.editSmsCode) {
        [BasicTool textFieldInputLimit:textField maxLen:4];// 验证码限长4位
    }
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
