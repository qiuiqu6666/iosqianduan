//telegram @wz662
#import "AboutViewController.h"
#import "ViewControllerFactory.h"
#import "BasicTool.h"
#import "UIViewController+RBPlainCustomNav.h"

@interface AboutViewController ()

@property (nonatomic, strong) UILabel *versionLabel;

@end

@implementation AboutViewController

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

    [self rb_installPlainCustomNavigationBarWithTitle:@"关于我们"];
    self.view.backgroundColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.941 alpha:1.0]; // #F0F0F0

    [self buildUI];

    // 显示程序的版本号
    NSBundle *mainBundle = [NSBundle mainBundle];
    self.versionLabel.text = [NSString stringWithFormat:@"专业版 v%@(%@)",
                              [[mainBundle infoDictionary] objectForKey:@"CFBundleShortVersionString"],
                              [[mainBundle infoDictionary] objectForKey:@"CFBundleVersion"]];
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
    
    // ============ 顶部 Logo 区域 ============
    UIView *logoArea = [[UIView alloc] init];
    logoArea.translatesAutoresizingMaskIntoConstraints = NO;
    logoArea.backgroundColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.941 alpha:1.0];
    [contentView addSubview:logoArea];
    
    // App 图标
    UIImageView *appIcon = [[UIImageView alloc] init];
    appIcon.translatesAutoresizingMaskIntoConstraints = NO;
    appIcon.image = [UIImage imageNamed:@"about_logo"];
    appIcon.contentMode = UIViewContentModeScaleAspectFit;
    appIcon.layer.cornerRadius = 16;
    appIcon.layer.masksToBounds = YES;
    [logoArea addSubview:appIcon];
    
    // App 名称
    UILabel *appNameLabel = [[UILabel alloc] init];
    appNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    appNameLabel.text = @"精聊Chat";
    appNameLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    appNameLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    appNameLabel.textAlignment = NSTextAlignmentCenter;
    [logoArea addSubview:appNameLabel];
    
    // 版本号
    UILabel *versionLbl = [[UILabel alloc] init];
    versionLbl.translatesAutoresizingMaskIntoConstraints = NO;
    versionLbl.text = @"";
    versionLbl.font = [UIFont systemFontOfSize:13];
    versionLbl.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    versionLbl.textAlignment = NSTextAlignmentCenter;
    [logoArea addSubview:versionLbl];
    self.versionLabel = versionLbl;
    
    [NSLayoutConstraint activateConstraints:@[
        [logoArea.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [logoArea.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [logoArea.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        
        [appIcon.centerXAnchor constraintEqualToAnchor:logoArea.centerXAnchor],
        [appIcon.topAnchor constraintEqualToAnchor:logoArea.topAnchor constant:30],
        [appIcon.widthAnchor constraintEqualToConstant:80],
        [appIcon.heightAnchor constraintEqualToConstant:80],
        
        [appNameLabel.centerXAnchor constraintEqualToAnchor:logoArea.centerXAnchor],
        [appNameLabel.topAnchor constraintEqualToAnchor:appIcon.bottomAnchor constant:12],
        
        [versionLbl.centerXAnchor constraintEqualToAnchor:logoArea.centerXAnchor],
        [versionLbl.topAnchor constraintEqualToAnchor:appNameLabel.bottomAnchor constant:4],
        [versionLbl.bottomAnchor constraintEqualToAnchor:logoArea.bottomAnchor constant:-20],
    ]];
    
    // ============ Section 1: 服务条款 / 隐私政策 ============
    UIView *section1 = [self createSectionWithItems:@[
        @{@"title": @"服务条款", @"action": NSStringFromSelector(@selector(gotoFuwutiaokuan:))},
        @{@"title": @"隐私政策", @"action": NSStringFromSelector(@selector(gotoPrivacy:))},
    ]];
    [contentView addSubview:section1];
    
    [NSLayoutConstraint activateConstraints:@[
        [section1.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section1.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [section1.topAnchor constraintEqualToAnchor:logoArea.bottomAnchor constant:10],
    ]];
    
    // ============ Section 2: 官方网站 / 邮件反馈（不再显示 Facebook / Twitter / Tumblr）============
    UIView *section2 = [self createSectionWithItems:@[
        @{@"title": @"官方网站", @"action": NSStringFromSelector(@selector(gotoMainSite:))},
        @{@"title": @"邮件反馈", @"action": NSStringFromSelector(@selector(gotoFeedback:))},
    ]];
    [contentView addSubview:section2];
    
    [NSLayoutConstraint activateConstraints:@[
        [section2.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section2.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [section2.topAnchor constraintEqualToAnchor:section1.bottomAnchor constant:10],
    ]];
    
    // ============ Footer: 版权信息 ============
    UILabel *copyrightLabel = [[UILabel alloc] init];
    copyrightLabel.translatesAutoresizingMaskIntoConstraints = NO;
    copyrightLabel.text = @"© 2026 精聊Chat";
    copyrightLabel.font = [UIFont systemFontOfSize:12];
    copyrightLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    copyrightLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:copyrightLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [copyrightLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [copyrightLabel.topAnchor constraintEqualToAnchor:section2.bottomAnchor constant:30],
        [copyrightLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-30],
    ]];
}

#pragma mark - 创建Section

- (UIView *)createSectionWithItems:(NSArray<NSDictionary *> *)items
{
    UIView *sectionView = [[UIView alloc] init];
    sectionView.translatesAutoresizingMaskIntoConstraints = NO;
    sectionView.backgroundColor = [UIColor whiteColor];
    
    UIView *previousItem = nil;
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *itemData = items[i];
        
        // 创建行
        UIView *itemView = [self createItemViewWithTitle:itemData[@"title"]
                                               subtitle:itemData[@"subtitle"]
                                                 action:NSSelectorFromString(itemData[@"action"])];
        itemView.translatesAutoresizingMaskIntoConstraints = NO;
        [sectionView addSubview:itemView];
        
        [NSLayoutConstraint activateConstraints:@[
            [itemView.leadingAnchor constraintEqualToAnchor:sectionView.leadingAnchor],
            [itemView.trailingAnchor constraintEqualToAnchor:sectionView.trailingAnchor],
            [itemView.heightAnchor constraintEqualToConstant:56],
        ]];
        
        if (previousItem) {
            [itemView.topAnchor constraintEqualToAnchor:previousItem.bottomAnchor].active = YES;
            
            // 添加分隔线
            UIView *separator = [[UIView alloc] init];
            separator.translatesAutoresizingMaskIntoConstraints = NO;
            separator.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
            [sectionView addSubview:separator];
            
            [NSLayoutConstraint activateConstraints:@[
                [separator.leadingAnchor constraintEqualToAnchor:sectionView.leadingAnchor constant:20],
                [separator.trailingAnchor constraintEqualToAnchor:sectionView.trailingAnchor],
                [separator.topAnchor constraintEqualToAnchor:previousItem.bottomAnchor],
                [separator.heightAnchor constraintEqualToConstant:0.5],
            ]];
        } else {
            [itemView.topAnchor constraintEqualToAnchor:sectionView.topAnchor].active = YES;
        }
        previousItem = itemView;
    }
    
    if (previousItem) {
        [previousItem.bottomAnchor constraintEqualToAnchor:sectionView.bottomAnchor].active = YES;
    }
    
    return sectionView;
}

#pragma mark - 创建单行

- (UIView *)createItemViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(SEL)action
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
    
    // 副标题（如果有）
    if (subtitle && subtitle.length > 0) {
        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        subtitleLabel.text = subtitle;
        subtitleLabel.font = [UIFont systemFontOfSize:15];
        subtitleLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        subtitleLabel.textAlignment = NSTextAlignmentRight;
        subtitleLabel.userInteractionEnabled = NO;
        [itemView addSubview:subtitleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [subtitleLabel.trailingAnchor constraintEqualToAnchor:arrowView.leadingAnchor constant:-8],
            [subtitleLabel.centerYAnchor constraintEqualToAnchor:itemView.centerYAnchor],
        ]];
    }
    
    return itemView;
}

#pragma mark - 按钮事件

- (void)gotoFuwutiaokuan:(id)sender
{
    // 查看服务条款
    [ViewControllerFactory goWebViewController:[BasicTool isChineseSimple]?RBCHAT_REGISTER_AGREEMENT_CN_URL:RBCHAT_REGISTER_AGREEMENT_EN_URL
                                         title:[BasicTool isChineseSimple]?@"服务条款":@"Terms of Service"
                                         toNav:self.navigationController];
}

- (void)gotoPrivacy:(id)sender
{
    // 查看隐私政策
    [ViewControllerFactory goWebViewController:[BasicTool isChineseSimple]?RBCHAT_PRIVACY_CN_URL:RBCHAT_PRIVACY_EN_URL
                                         title:[BasicTool isChineseSimple]?@"隐私政策":@"Privacy Policy"
                                         toNav:self.navigationController];
}

- (void)gotoMainSite:(id)sender
{
    [ViewControllerFactory goWebViewController:RBCHAT_OFFICAL_WEBSITE title:@"官方网站" toNav:self.navigationController];
}

- (void)gotoFeedback:(id)sender
{
    NSString *m = [NSString stringWithFormat:@"邮箱发送至：%@", RBCHAT_OFFICAL_MAIL];
    [BasicTool showAlertInfo:m parent:self];
}

@end
