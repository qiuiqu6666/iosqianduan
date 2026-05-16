//telegram @wz662
#import "FindFriendViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "QueryFriendInfoAsync.h"
#import "ViewControllerFactory.h"
#import "QRCodeScheme.h"
#import "Default.h"

@interface FindFriendViewController ()

/** 微信风格：新的搜索输入框 */
@property (nonatomic, strong) UITextField *searchField;

@end

@implementation FindFriendViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.titleView = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"添加好友"];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // ── 隐藏 xib 中所有旧的 UI 元素 ──
    // Tab 切换区域
    UIView *tabLayout = self.tabRandomSearch.superview.superview;
    if (tabLayout) tabLayout.hidden = YES;
    // 随机查找布局
    self.layoutRandom.hidden = YES;
    // 精确查找布局
    self.layoutPrecise.hidden = YES;
    // 底部按钮区域
    self.layoutSubmit.hidden = YES;
    
    // ── 构建微信风格的 UI ──
    [self buildWeChatStyleUI];
    
    // ── 点击空白处收起键盘 ──
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
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
    // 自动弹出键盘
    [self.searchField becomeFirstResponder];
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

#pragma mark - 构建微信风格 UI

- (void)buildWeChatStyleUI
{
    // ============================
    // 1. 搜索栏容器（浅灰圆角背景）
    // ============================
    UIView *searchBg = [[UIView alloc] init];
    searchBg.backgroundColor = HexColor(0xF5F5F5);
    searchBg.layer.cornerRadius = 8;
    searchBg.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:searchBg];
    
    // ============================
    // 2. 搜索图标（放大镜）
    // ============================
    UIImageView *searchIcon = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
        searchIcon.image = [[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    searchIcon.tintColor = HexColor(0xB2B2B2);
    searchIcon.contentMode = UIViewContentModeScaleAspectFit;
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [searchBg addSubview:searchIcon];
    
    // ============================
    // 3. 搜索输入框
    // ============================
    UITextField *searchField = [[UITextField alloc] init];
    searchField.placeholder = @"ID号/手机号/邮箱";
    searchField.font = [UIFont systemFontOfSize:15];
    searchField.textColor = HexColor(0x333333);
    searchField.borderStyle = UITextBorderStyleNone;
    searchField.returnKeyType = UIReturnKeySearch;
    searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    searchField.autocorrectionType = UITextAutocorrectionTypeNo;
    searchField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    searchField.delegate = self;
    searchField.translatesAutoresizingMaskIntoConstraints = NO;
    [searchBg addSubview:searchField];
    self.searchField = searchField;
    
    // placeholder 颜色
    if (@available(iOS 13.0, *)) {
        searchField.attributedPlaceholder = [[NSAttributedString alloc]
            initWithString:@"ID号/手机号/邮箱"
            attributes:@{NSForegroundColorAttributeName: HexColor(0xB2B2B2),
                        NSFontAttributeName: [UIFont systemFontOfSize:15]}];
    }
    
    // ============================
    // 4.「我的ID号」提示
    // ============================
    NSString *myUid = [[IMClientManager sharedInstance] localUserInfo].user_uid ?: @"";
    UILabel *myIdLabel = [[UILabel alloc] init];
    myIdLabel.text = [NSString stringWithFormat:@"我的ID号：%@", myUid];
    myIdLabel.font = [UIFont systemFontOfSize:13];
    myIdLabel.textColor = HexColor(0xB2B2B2);
    myIdLabel.textAlignment = NSTextAlignmentCenter;
    myIdLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:myIdLabel];
    
    // ============================
    // 5. 分隔线
    // ============================
    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = HexColor(0xEDEDED);
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:separator];
    
    // ============================
    // 6. 功能入口列表（微信风格菜单项）
    // ============================
    // 仅展示扫一扫，隐藏「添加手机联系人」
    NSArray *menuItems = @[
        @{@"icon": @"qrcode.viewfinder",   @"title": @"扫一扫",     @"color": @(0x576B95)},
    ];
    
    UIView *lastItem = separator;
    
    for (NSUInteger i = 0; i < menuItems.count; i++) {
        NSDictionary *menuData = menuItems[i];
        UIView *menuRow = [self createMenuRow:menuData[@"icon"]
                                        title:menuData[@"title"]
                                     hexColor:[menuData[@"color"] unsignedIntValue]
                                          tag:(int)i];
        [self.view addSubview:menuRow];
        
        // 行间分隔线
        UIView *lineSep = [[UIView alloc] init];
        lineSep.backgroundColor = HexColor(0xF0F0F0);
        lineSep.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:lineSep];
        
        [NSLayoutConstraint activateConstraints:@[
            [menuRow.topAnchor constraintEqualToAnchor:lastItem.bottomAnchor constant:0],
            [menuRow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [menuRow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [menuRow.heightAnchor constraintEqualToConstant:56],
            
            [lineSep.topAnchor constraintEqualToAnchor:menuRow.bottomAnchor],
            [lineSep.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:56],
            [lineSep.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [lineSep.heightAnchor constraintEqualToConstant:(i < menuItems.count - 1 ? 0.5 : 0)],
        ]];
        
        lastItem = lineSep;
    }
    
    // ============================
    // 约束布局
    // ============================
    [NSLayoutConstraint activateConstraints:@[
        // 搜索栏
        [searchBg.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [searchBg.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [searchBg.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [searchBg.heightAnchor constraintEqualToConstant:40],
        
        // 搜索图标
        [searchIcon.leadingAnchor constraintEqualToAnchor:searchBg.leadingAnchor constant:12],
        [searchIcon.centerYAnchor constraintEqualToAnchor:searchBg.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:18],
        [searchIcon.heightAnchor constraintEqualToConstant:18],
        
        // 输入框
        [searchField.leadingAnchor constraintEqualToAnchor:searchIcon.trailingAnchor constant:8],
        [searchField.trailingAnchor constraintEqualToAnchor:searchBg.trailingAnchor constant:-12],
        [searchField.topAnchor constraintEqualToAnchor:searchBg.topAnchor],
        [searchField.bottomAnchor constraintEqualToAnchor:searchBg.bottomAnchor],
        
        // 我的ID号
        [myIdLabel.topAnchor constraintEqualToAnchor:searchBg.bottomAnchor constant:12],
        [myIdLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        
        // 分隔线
        [separator.topAnchor constraintEqualToAnchor:myIdLabel.bottomAnchor constant:20],
        [separator.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [separator.heightAnchor constraintEqualToConstant:8],
    ]];
}

#pragma mark - 创建菜单行

- (UIView *)createMenuRow:(NSString *)sfSymbol title:(NSString *)title hexColor:(unsigned int)colorHex tag:(int)tag
{
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = [UIColor whiteColor];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.tag = 100 + tag;
    
    // 图标背景圆角方块
    UIView *iconBg = [[UIView alloc] init];
    iconBg.backgroundColor = HexColor(colorHex);
    iconBg.layer.cornerRadius = 8;
    iconBg.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:iconBg];
    
    // SF Symbol 图标
    UIImageView *iconView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
        iconView.image = [[UIImage systemImageNamed:sfSymbol withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    iconView.tintColor = [UIColor whiteColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [iconBg addSubview:iconView];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:16];
    titleLabel.textColor = HexColor(0x333333);
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:titleLabel];
    
    // 右箭头
    UIImageView *arrowView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightMedium];
        arrowView.image = [[UIImage systemImageNamed:@"chevron.right" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    arrowView.tintColor = HexColor(0xC7C7CC);
    arrowView.contentMode = UIViewContentModeScaleAspectFit;
    arrowView.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:arrowView];
    
    // 点击手势
    row.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(menuRowTapped:)];
    [row addGestureRecognizer:tapGR];
    
    // 约束
    [NSLayoutConstraint activateConstraints:@[
        [iconBg.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [iconBg.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [iconBg.widthAnchor constraintEqualToConstant:36],
        [iconBg.heightAnchor constraintEqualToConstant:36],
        
        [iconView.centerXAnchor constraintEqualToAnchor:iconBg.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconBg.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:20],
        [iconView.heightAnchor constraintEqualToConstant:20],
        
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconBg.trailingAnchor constant:14],
        [titleLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        
        [arrowView.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [arrowView.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrowView.widthAnchor constraintEqualToConstant:12],
        [arrowView.heightAnchor constraintEqualToConstant:16],
    ]];
    
    return row;
}

#pragma mark - 菜单行点击

- (void)menuRowTapped:(UITapGestureRecognizer *)gesture
{
    int tag = (int)gesture.view.tag - 100;
    switch (tag) {
        case 0:
        {
            // 进入"扫一扫"界面
            __weak typeof(self) safeSelf = self;
            [QRCodeScheme gotoQrCodeScan:self.navigationController scanComplete:^(NSString *qrResult) {
                DLogDebug(@"%@", [NSString stringWithFormat:@"2维码扫描的结果是：%@", qrResult]);
                [QRCodeScheme processQRCodeScanResult:qrResult nav:safeSelf.navigationController view:safeSelf.view vc:safeSelf];
            }];
            break;
        }
        default:
            break;
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSString *keyword = [BasicTool trim:textField.text];
    // 空内容回车：仅收起键盘，不触发搜索
    if (keyword.length == 0) {
        [textField resignFirstResponder];
        return NO;
    }
    [self doSearch];
    return YES;
}

#pragma mark - 搜索逻辑

- (void)doSearch
{
    [self.view endEditing:YES];
    
    NSString *idOrMail = [BasicTool trim:self.searchField.text];
    
    // 非空验证
    if ([idOrMail length] == 0)
    {
        [APP showToastWarn:@"请输入ID号、手机号或邮箱进行查找"];
        return;
    }
    
    // 不是数字或邮件
    if(![BasicTool isFullNumber:idOrMail] && ![BasicTool isValidEmail:idOrMail])
    {
        [APP showToastWarn:@"无效的输入，请输入正确的ID号、手机号或邮箱"];
        return;
    }
    
    // 查找好友信息（并进入个人信息的UI显示界面）
    BOOL useMail = [BasicTool isValidEmail:idOrMail];
    BOOL isPhone = (!useMail && [BasicTool isFullNumber:idOrMail] && idOrMail.length > 10);
    NSString *addSource = useMail ? @"search_email" : (isPhone ? @"search_phone" : @"search_uid");
    if (isPhone) {
        [QueryFriendInfoAsync doItWithPhone:idOrMail hudParentView:self.view withNC:self.navigationController canOpenChat:YES addSource:addSource];
    } else {
        [QueryFriendInfoAsync doIt:useMail mail:useMail?idOrMail:@"" uid:useMail?@"":idOrMail hudParentView:self.view withNC:self.navigationController canOpenChat:YES addSource:addSource];
    }
}

#pragma mark - 点击空白处收起键盘

- (void)fingerTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    [self.view endEditing:YES];
}

@end
