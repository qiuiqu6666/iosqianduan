// Copyright (C) 2026 即时通讯网(52im.net) & Jack Jiang.
// The RainbowChat Project. All rights reserved.
// 
// 【本产品为著作权产品，合法授权后请放心使用，禁止外传！】
// 【本次授权给：<MANEKI TECHNOLOGY>，授权编号：<NT260125160939>，代码指纹：<A.769328579.505>，技术对接人微信：<ID: Cqiu88-88>】
// 
// 【本系列产品在国家版权局的著作权登记信息如下】：
// 1）国家版权局登记名(简称)和权证号：RainbowChat    （证书号：软著登字第1220494号、登记号：2016SR041877）
// 2）国家版权局登记名(简称)和权证号：RainbowChat-Web（证书号：软著登字第3743440号、登记号：2019SR0322683）
// 3）国家版权局登记名(简称)和权证号：RainbowAV      （证书号：软著登字第2262004号、登记号：2017SR676720）
// 4）国家版权局登记名(简称)和权证号：MobileIMSDK-Web（证书号：软著登字第2262073号、登记号：2017SR676789）
// 5）国家版权局登记名(简称)和权证号：MobileIMSDK    （证书号：软著登字第1220581号、登记号：2016SR041964）
// 6）国家版权局登记名(简称)和权证号：RainbowTalk    （证书号：软著登字第15415925号、登记号：2025SR0759727）
// * 著作权所有人：苏州网际时代信息科技有限公司
// 
// 【违法或违规使用投诉和举报方式】：
// 联系邮件：jack.jiang@52im.net
// 联系微信：hellojackjiang
// 联系QQ号：413980957
// 授权说明：http://www.52im.net/thread-1115-1-1.html
// 官方社区：http://www.52im.net
#import "SettingsStorageViewController.h"
#import "FileTool.h"
#import "Default.h"
#import "MyDataBase.h"
#import "TableRoot.h"
#import "BasicTool.h"
#import "LPActionSheet.h"
#import "MBProgressHUD.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "AlarmsProvider.h"
#import "NSMutableArrayObservableEx.h"
#import "UserEntity.h"
#import "ChatHistoryTable.h"
#import "GroupChatHistoryTable.h"
#import "TimeTool.h"
#import <AVFoundation/AVFoundation.h>
#import "UIViewController+RBPlainCustomNav.h"

static const CGFloat kCardMarginH = 0.0;
static const CGFloat kCardPadding = 20.0;
static const CGFloat kCardCornerRadius = 0.0;
/// 区块之间细缝（灰底露出一道线，非卡片留白）
static const CGFloat kSectionSeparatorGap = 0.5;

@interface SettingsStorageViewController ()

// 数据
@property (nonatomic, assign) long long totalSize;
@property (nonatomic, assign) long long videoSize;
@property (nonatomic, assign) long long imageSize;
@property (nonatomic, assign) long long chatSize;
@property (nonatomic, assign) long long otherSize;
@property (nonatomic, assign) long long deviceTotalSize;
@property (nonatomic, assign) long long deviceFreeSize;

// 概览卡片
@property (nonatomic, strong) UILabel *totalSizeLabel;
@property (nonatomic, strong) UILabel *percentageLabel;
@property (nonatomic, strong) UIView *barContainer;
@property (nonatomic, strong) UIView *appBarView;
@property (nonatomic, strong) UIView *otherBarView;
@property (nonatomic, strong) NSLayoutConstraint *appBarWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *otherBarWidthConstraint;

// 分类卡片
@property (nonatomic, strong) UILabel *cacheSizeLabel;
@property (nonatomic, strong) UILabel *cacheSubDescLabel;
@property (nonatomic, strong) UILabel *chatSizeLabel;
@property (nonatomic, strong) UILabel *resourceSizeLabel;
@property (nonatomic, strong) UILabel *essentialSizeLabel;

@end

@implementation SettingsStorageViewController

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

    [self rb_installPlainCustomNavigationBarWithTitle:@"存储空间"];
    self.view.backgroundColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.941 alpha:1.0];

    [self getDeviceStorageInfo];
    [self buildUI];
    [self loadStorageInfo];
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

#pragma mark - 获取设备存储信息

- (void)getDeviceStorageInfo
{
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (attrs) {
        self.deviceTotalSize = [[attrs objectForKey:NSFileSystemSize] longLongValue];
        self.deviceFreeSize  = [[attrs objectForKey:NSFileSystemFreeSize] longLongValue];
    }
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
    
    // ========== 概览卡片 ==========
    UIView *overviewCard = [self buildOverviewCard];
    [contentView addSubview:overviewCard];
    
    // ========== 缓存卡片 ==========
    UIView *cacheCard = [self buildCacheCard];
    [contentView addSubview:cacheCard];
    
    // ========== 聊天记录卡片 ==========
    UIView *chatCard = [self buildChatCard];
    [contentView addSubview:chatCard];
    
    // ========== 资源文件卡片 ==========
    UIView *resourceCard = [self buildResourceCard];
    [contentView addSubview:resourceCard];
    
    // ========== 必要文件卡片 ==========
    UIView *essentialCard = [self buildEssentialCard];
    [contentView addSubview:essentialCard];
    
    // 布局
    [NSLayoutConstraint activateConstraints:@[
        [overviewCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:kCardMarginH],
        [overviewCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-kCardMarginH],
        [overviewCard.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        
        [cacheCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:kCardMarginH],
        [cacheCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-kCardMarginH],
        [cacheCard.topAnchor constraintEqualToAnchor:overviewCard.bottomAnchor constant:kSectionSeparatorGap],
        
        [chatCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:kCardMarginH],
        [chatCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-kCardMarginH],
        [chatCard.topAnchor constraintEqualToAnchor:cacheCard.bottomAnchor constant:kSectionSeparatorGap],
        
        [resourceCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:kCardMarginH],
        [resourceCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-kCardMarginH],
        [resourceCard.topAnchor constraintEqualToAnchor:chatCard.bottomAnchor constant:kSectionSeparatorGap],
        
        [essentialCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:kCardMarginH],
        [essentialCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-kCardMarginH],
        [essentialCard.topAnchor constraintEqualToAnchor:resourceCard.bottomAnchor constant:kSectionSeparatorGap],
        [essentialCard.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],
    ]];
}

#pragma mark - 概览卡片

- (UIView *)buildOverviewCard
{
    UIView *card = [self createCardView];
    
    // === 存储条 ===
    UIView *barContainer = [[UIView alloc] init];
    barContainer.translatesAutoresizingMaskIntoConstraints = NO;
    barContainer.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    barContainer.layer.cornerRadius = 4;
    barContainer.clipsToBounds = YES;
    [card addSubview:barContainer];
    self.barContainer = barContainer;
    
    UIView *appBar = [[UIView alloc] init];
    appBar.translatesAutoresizingMaskIntoConstraints = NO;
    appBar.backgroundColor = [UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0]; // 绿色
    [barContainer addSubview:appBar];
    self.appBarView = appBar;
    
    UIView *otherBar = [[UIView alloc] init];
    otherBar.translatesAutoresizingMaskIntoConstraints = NO;
    otherBar.backgroundColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0]; // 黄色
    [barContainer addSubview:otherBar];
    self.otherBarView = otherBar;
    
    self.appBarWidthConstraint = [appBar.widthAnchor constraintEqualToConstant:1];
    self.otherBarWidthConstraint = [otherBar.widthAnchor constraintEqualToConstant:1];
    
    [NSLayoutConstraint activateConstraints:@[
        [barContainer.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [barContainer.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
        [barContainer.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
        [barContainer.heightAnchor constraintEqualToConstant:8],
        
        [appBar.leadingAnchor constraintEqualToAnchor:barContainer.leadingAnchor],
        [appBar.topAnchor constraintEqualToAnchor:barContainer.topAnchor],
        [appBar.bottomAnchor constraintEqualToAnchor:barContainer.bottomAnchor],
        self.appBarWidthConstraint,
        
        [otherBar.leadingAnchor constraintEqualToAnchor:appBar.trailingAnchor],
        [otherBar.topAnchor constraintEqualToAnchor:barContainer.topAnchor],
        [otherBar.bottomAnchor constraintEqualToAnchor:barContainer.bottomAnchor],
        self.otherBarWidthConstraint,
    ]];
    
    // === 图例 ===
    UIView *legendView = [self buildLegendView];
    [card addSubview:legendView];
    
    // === "精聊已用空间" ===
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"精聊已用空间";
    titleLabel.font = [UIFont systemFontOfSize:14];
    titleLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
    [card addSubview:titleLabel];
    
    // === 总大小 ===
    UILabel *totalLabel = [[UILabel alloc] init];
    totalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    totalLabel.text = @"计算中...";
    totalLabel.font = [UIFont systemFontOfSize:36 weight:UIFontWeightBold];
    totalLabel.textColor = [UIColor blackColor];
    [card addSubview:totalLabel];
    self.totalSizeLabel = totalLabel;
    
    // === 占比 ===
    UILabel *percentLabel = [[UILabel alloc] init];
    percentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    percentLabel.text = @"";
    percentLabel.font = [UIFont systemFontOfSize:13];
    percentLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    [card addSubview:percentLabel];
    self.percentageLabel = percentLabel;
    
    [NSLayoutConstraint activateConstraints:@[
        [legendView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [legendView.topAnchor constraintEqualToAnchor:barContainer.bottomAnchor constant:12],
        
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [titleLabel.topAnchor constraintEqualToAnchor:legendView.bottomAnchor constant:16],
        
        [totalLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [totalLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        
        [percentLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [percentLabel.topAnchor constraintEqualToAnchor:totalLabel.bottomAnchor constant:4],
        [percentLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
    ]];
    
    return card;
}

- (UIView *)buildLegendView
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSArray *colors = @[
        [UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0],  // 绿色
        [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0],       // 黄色
        [UIColor colorWithRed:0.85 green:0.85 blue:0.85 alpha:1.0],    // 灰色
    ];
    NSArray *labels = @[@"精聊已用", @"其他 App 已用", @"手机剩余可用"];
    
    UIView *prevItem = nil;
    for (NSInteger i = 0; i < colors.count; i++) {
        UIView *dot = [[UIView alloc] init];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.backgroundColor = colors[i];
        dot.layer.cornerRadius = 3;
        [container addSubview:dot];
        
        UILabel *lbl = [[UILabel alloc] init];
        lbl.translatesAutoresizingMaskIntoConstraints = NO;
        lbl.text = labels[i];
        lbl.font = [UIFont systemFontOfSize:11];
        lbl.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
        [container addSubview:lbl];
        
        CGFloat leadingOffset = 0;
        if (prevItem) {
            [dot.leadingAnchor constraintEqualToAnchor:prevItem.trailingAnchor constant:12].active = YES;
        } else {
            [dot.leadingAnchor constraintEqualToAnchor:container.leadingAnchor].active = YES;
        }
        
        [NSLayoutConstraint activateConstraints:@[
            [dot.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
            [dot.widthAnchor constraintEqualToConstant:6],
            [dot.heightAnchor constraintEqualToConstant:6],
            [lbl.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:4],
            [lbl.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        ]];
        
        prevItem = lbl;
    }
    
    if (prevItem) {
        [prevItem.trailingAnchor constraintEqualToAnchor:container.trailingAnchor].active = YES;
    }
    
    [container.heightAnchor constraintEqualToConstant:16].active = YES;
    
    return container;
}

#pragma mark - 缓存卡片

- (UIView *)buildCacheCard
{
    UIView *card = [self createCardView];
    
    // 标题
    UILabel *titleLabel = [self createTitleLabel:@"缓存"];
    [card addSubview:titleLabel];
    
    // 清理按钮（绿色填充）
    UIButton *clearBtn = [self createGreenClearButton:@selector(clearCacheClicked:)];
    [card addSubview:clearBtn];
    
    // 大小
    UILabel *sizeLabel = [self createSizeLabel];
    sizeLabel.text = @"计算中...";
    [card addSubview:sizeLabel];
    self.cacheSizeLabel = sizeLabel;
    
    // 子说明（动态：包括聊天记录中 X 的原图、原视频）
    UILabel *subDesc = [[UILabel alloc] init];
    subDesc.translatesAutoresizingMaskIntoConstraints = NO;
    subDesc.text = @"";
    subDesc.font = [UIFont systemFontOfSize:13];
    subDesc.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    subDesc.numberOfLines = 0;
    [card addSubview:subDesc];
    self.cacheSubDescLabel = subDesc;
    
    // 描述
    UILabel *descLabel = [self createDescLabel:@"缓存是使用过程中产生的临时数据，清理缓存不会影响正常使用。"];
    [card addSubview:descLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
        
        [clearBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
        [clearBtn.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        
        [sizeLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [sizeLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
        
        [subDesc.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [subDesc.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
        [subDesc.topAnchor constraintEqualToAnchor:sizeLabel.bottomAnchor constant:8],
        
        [descLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [descLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
        [descLabel.topAnchor constraintEqualToAnchor:subDesc.bottomAnchor constant:8],
        [descLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
    ]];
    
    return card;
}

#pragma mark - 聊天记录卡片

- (UIView *)buildChatCard
{
    UIView *card = [self createCardView];
    
    UILabel *titleLabel = [self createTitleLabel:@"聊天记录"];
    [card addSubview:titleLabel];
    
    UIButton *clearBtn = [self createOutlineClearButton:@selector(clearChatClicked:)];
    [card addSubview:clearBtn];
    
    UILabel *sizeLabel = [self createSizeLabel];
    sizeLabel.text = @"计算中...";
    [card addSubview:sizeLabel];
    self.chatSizeLabel = sizeLabel;
    
    UILabel *descLabel = [self createDescLabel:@"可清理聊天记录里的图片、视频和文件，或者删除指定的聊天记录。"];
    [card addSubview:descLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
        
        [clearBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
        [clearBtn.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        
        [sizeLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [sizeLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
        
        [descLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [descLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
        [descLabel.topAnchor constraintEqualToAnchor:sizeLabel.bottomAnchor constant:8],
        [descLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
    ]];
    
    return card;
}

#pragma mark - 资源文件卡片

- (UIView *)buildResourceCard
{
    UIView *card = [self createCardView];
    
    UILabel *titleLabel = [self createTitleLabel:@"资源文件"];
    [card addSubview:titleLabel];
    
    UIButton *clearBtn = [self createOutlineClearButton:@selector(clearResourceClicked:)];
    [card addSubview:clearBtn];
    
    UILabel *sizeLabel = [self createSizeLabel];
    sizeLabel.text = @"计算中...";
    [card addSubview:sizeLabel];
    self.resourceSizeLabel = sizeLabel;
    
    UILabel *descLabel = [self createDescLabel:@"包含部分功能运行时所需的资源文件。"];
    [card addSubview:descLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
        
        [clearBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
        [clearBtn.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        
        [sizeLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [sizeLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
        
        [descLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [descLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
        [descLabel.topAnchor constraintEqualToAnchor:sizeLabel.bottomAnchor constant:8],
        [descLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
    ]];
    
    return card;
}

#pragma mark - 必要文件卡片

- (UIView *)buildEssentialCard
{
    UIView *card = [self createCardView];
    
    UILabel *titleLabel = [self createTitleLabel:@"必要文件"];
    [card addSubview:titleLabel];
    
    UILabel *sizeLabel = [self createSizeLabel];
    sizeLabel.text = @"计算中...";
    [card addSubview:sizeLabel];
    self.essentialSizeLabel = sizeLabel;
    
    UILabel *descLabel = [self createDescLabel:@"包含运行所需的必要文件，该类别的大小因当前使用状态而异。"];
    [card addSubview:descLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:kCardPadding],
        
        [sizeLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [sizeLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
        
        [descLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kCardPadding],
        [descLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kCardPadding],
        [descLabel.topAnchor constraintEqualToAnchor:sizeLabel.bottomAnchor constant:8],
        [descLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kCardPadding],
    ]];
    
    return card;
}

#pragma mark - UI 工厂方法

- (UIView *)createCardView
{
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = kCardCornerRadius;
    card.layer.masksToBounds = YES;
    return card;
}

- (UILabel *)createTitleLabel:(NSString *)title
{
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    return label;
}

- (UILabel *)createSizeLabel
{
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    label.textColor = [UIColor blackColor];
    return label;
}

- (UILabel *)createDescLabel:(NSString *)text
{
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont systemFontOfSize:13];
    label.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    label.numberOfLines = 0;
    return label;
}

- (UIButton *)createGreenClearButton:(SEL)action
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:@"清理" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    btn.backgroundColor = [UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0];
    btn.layer.cornerRadius = 15;
    btn.layer.masksToBounds = YES;
    btn.contentEdgeInsets = UIEdgeInsetsMake(6, 18, 6, 18);
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [btn.heightAnchor constraintEqualToConstant:30].active = YES;
    return btn;
}

- (UIButton *)createOutlineClearButton:(SEL)action
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:@"清理" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    btn.backgroundColor = [UIColor whiteColor];
    btn.layer.cornerRadius = 15;
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0].CGColor;
    btn.contentEdgeInsets = UIEdgeInsetsMake(6, 18, 6, 18);
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [btn.heightAnchor constraintEqualToConstant:30].active = YES;
    return btn;
}

#pragma mark - 加载存储空间信息

- (void)loadStorageInfo
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.videoSize = [self calculateDirectorySize:[self getVideoDirectory]];
        self.imageSize = [self calculateImageDirectorySize];
        self.chatSize  = [self calculateChatDatabaseSize];
        self.otherSize = [self calculateOtherFilesSize];
        self.totalSize = self.videoSize + self.imageSize + self.chatSize + self.otherSize;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStorageLabels];
            [self updateStorageBar];
        });
    });
}

- (void)updateStorageLabels
{
    // 概览
    self.totalSizeLabel.text = [FileTool getConvenientFileSize:self.totalSize];
    
    if (self.deviceTotalSize > 0) {
        double percent = (double)self.totalSize / (double)self.deviceTotalSize * 100.0;
        self.percentageLabel.text = [NSString stringWithFormat:@"占据手机 %.0f%% 存储空间", percent];
    }
    
    // 缓存（视频+图片）
    long long cacheSize = self.videoSize + self.imageSize;
    self.cacheSizeLabel.text = [FileTool getConvenientFileSize:cacheSize];
    self.cacheSubDescLabel.text = [NSString stringWithFormat:@"包括聊天记录中 %@ 的原图、原视频", [FileTool getConvenientFileSize:self.imageSize]];
    
    // 聊天记录
    self.chatSizeLabel.text = [FileTool getConvenientFileSize:self.chatSize];
    
    // 资源文件
    self.resourceSizeLabel.text = [FileTool getConvenientFileSize:self.otherSize];
    
    // 必要文件
    long long essentialSize = 0;
    // 尝试计算 App bundle 大小
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    essentialSize = [self calculateDirectorySize:bundlePath];
    self.essentialSizeLabel.text = [FileTool getConvenientFileSize:essentialSize];
}

- (void)updateStorageBar
{
    if (self.deviceTotalSize <= 0) return;
    
    CGFloat barWidth = self.barContainer.bounds.size.width;
    if (barWidth <= 0) {
        // 延迟更新
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self updateStorageBar];
        });
        return;
    }
    
    double appRatio = (double)self.totalSize / (double)self.deviceTotalSize;
    long long otherAppSize = self.deviceTotalSize - self.deviceFreeSize - self.totalSize;
    if (otherAppSize < 0) otherAppSize = 0;
    double otherRatio = (double)otherAppSize / (double)self.deviceTotalSize;
    
    // 最小宽度确保可见
    CGFloat appWidth = MAX(appRatio * barWidth, 2);
    CGFloat otherWidth = MAX(otherRatio * barWidth, 2);
    
    // 确保不超出
    if (appWidth + otherWidth > barWidth) {
        otherWidth = barWidth - appWidth;
    }
    
    self.appBarWidthConstraint.constant = appWidth;
    self.otherBarWidthConstraint.constant = otherWidth;
    
    [UIView animateWithDuration:0.3 animations:^{
        [self.barContainer layoutIfNeeded];
    }];
}

#pragma mark - 获取目录路径

- (NSString *)getVideoDirectory
{
    return [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_SHORTVIDEO_RELATIVE_DIR];
}

- (long long)calculateImageDirectorySize
{
    NSString *imageDir    = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_SENDPIC_RELATIVE_DIR];
    NSString *photoDir    = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_PHOTO_RELATIVE_DIR];
    NSString *phoneAlbumDir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_PHONE_ALBUM_RELATIVE_DIR];
    NSString *locationDir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_LOCATION_RELATIVE_DIR];
    
    long long totalSize = [self calculateDirectorySize:imageDir];
    totalSize += [self calculateDirectorySize:photoDir];
    totalSize += [self calculateDirectorySize:phoneAlbumDir];
    totalSize += [self calculateDirectorySize:locationDir];
    return totalSize;
}

- (NSString *)getImageDirectory
{
    return [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_SENDPIC_RELATIVE_DIR];
}

- (long long)calculateChatDatabaseSize
{
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *dbPath  = [docPath stringByAppendingPathComponent:DATABASE_PATH];
    long long totalSize = 0;
    
    if ([FileTool fileExists:dbPath]) {
        totalSize += [FileTool fileSizeAtPath:dbPath];
    }
    
    NSString *baseName = [DATABASE_PATH stringByDeletingPathExtension];
    NSArray *walFiles = @[
        [NSString stringWithFormat:@"%@-wal", baseName],
        [NSString stringWithFormat:@"%@-shm", baseName]
    ];
    for (NSString *walFile in walFiles) {
        NSString *walPath = [docPath stringByAppendingPathComponent:walFile];
        if ([FileTool fileExists:walPath]) {
            totalSize += [FileTool fileSizeAtPath:walPath];
        }
    }
    
    return totalSize;
}

- (long long)calculateOtherFilesSize
{
    NSString *basePath = [FileTool getCachedPath];
    NSString *workRoot = [basePath stringByAppendingPathComponent:DIR_KCHAT_WORK_RELATIVE_ROOT];
    
    long long totalSize = 0;
    NSArray *otherDirs = @[
        [workRoot stringByAppendingPathComponent:@"avatar"],
        [workRoot stringByAppendingPathComponent:@"voice"],
        [workRoot stringByAppendingPathComponent:@"pvoice"],
        [workRoot stringByAppendingPathComponent:@"file"],
    ];
    
    for (NSString *dir in otherDirs) {
        totalSize += [self calculateDirectorySize:dir];
    }
    
    return totalSize;
}

#pragma mark - 计算目录大小

- (long long)calculateDirectorySize:(NSString *)directoryPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    
    if (![fileManager fileExistsAtPath:directoryPath isDirectory:&isDirectory]) {
        return 0;
    }
    
    if (!isDirectory) {
        return [FileTool fileSizeAtPath:directoryPath];
    }
    
    long long totalSize = 0;
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:directoryPath];
    
    for (NSString *fileName in enumerator) {
        NSString *filePath = [directoryPath stringByAppendingPathComponent:fileName];
        BOOL isDir = NO;
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDir]) {
            if (!isDir) {
                totalSize += [FileTool fileSizeAtPath:filePath];
            }
        }
    }
    
    return totalSize;
}

#pragma mark - 清理操作

- (void)clearCacheClicked:(id)sender
{
    long long cacheSize = self.videoSize + self.imageSize;
    [BasicTool areYouSureAlert:@"清理缓存" 
                        content:[NSString stringWithFormat:@"确定要清理所有缓存文件吗？将释放 %@ 空间。", [FileTool getConvenientFileSize:cacheSize]]
                    okBtnTitle:@"确定"
                cancelBtnTitle:@"取消"
                        parent:self
                     okHandler:^(UIAlertAction * _Nullable action) {
                         [self clearCacheFiles];
                     }
                 cancelHandler:nil];
}

- (void)clearChatClicked:(id)sender
{
    NSArray *timeOptions = @[@"清理3个月前的数据", @"清理6个月前的数据", @"清理1年前的数据", @"清理全部聊天媒体"];
    
    [LPActionSheet showActionSheetWithTitle:@"选择清理方式"
                         cancelButtonTitle:@"取消"
                    destructiveButtonTitle:nil
                        otherButtonTitles:timeOptions
                                   handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index >= 1 && index <= (NSInteger)timeOptions.count) {
            NSInteger days = 0;
            NSString *timeDesc = @"";
            switch (index) {
                case 1: days = 90;  timeDesc = @"3个月"; break;
                case 2: days = 180; timeDesc = @"6个月"; break;
                case 3: days = 365; timeDesc = @"1年";   break;
                case 4: days = 0;   timeDesc = @"全部";   break;
                default: return;
            }
            
            NSString *msg = (days > 0)
                ? [NSString stringWithFormat:@"确定要清理%@前的聊天记录数据吗？", timeDesc]
                : @"确定要清理全部聊天媒体数据吗？此操作不可恢复。";
            
            [BasicTool areYouSureAlert:@"清理聊天记录"
                               content:msg
                           okBtnTitle:@"确定"
                       cancelBtnTitle:@"取消"
                               parent:self
                            okHandler:^(UIAlertAction * _Nullable action) {
                                if (days > 0) {
                                    [self clearFilesOlderThanDays:days];
                                } else {
                                    [self clearAllChatMedia];
                                }
                            }
                        cancelHandler:nil];
        }
    }];
}

- (void)clearResourceClicked:(id)sender
{
    [BasicTool areYouSureAlert:@"清理资源文件" 
                        content:[NSString stringWithFormat:@"确定要清理资源文件吗？将释放 %@ 空间。", [FileTool getConvenientFileSize:self.otherSize]]
                    okBtnTitle:@"确定"
                cancelBtnTitle:@"取消"
                        parent:self
                     okHandler:^(UIAlertAction * _Nullable action) {
                         [self clearOtherFiles];
                     }
                 cancelHandler:nil];
}

#pragma mark - 清理实现

- (void)clearCacheFiles
{
    [self showLoading:@"正在清理缓存..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self deleteDirectory:[self getVideoDirectory]];
        [self deleteDirectory:[self getImageDirectory]];
        
        NSString *photoDir    = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_PHOTO_RELATIVE_DIR];
        NSString *phoneAlbumDir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_PHONE_ALBUM_RELATIVE_DIR];
        NSString *locationDir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_LOCATION_RELATIVE_DIR];
        [self deleteDirectory:photoDir];
        [self deleteDirectory:phoneAlbumDir];
        [self deleteDirectory:locationDir];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideLoading];
            [BasicTool showAlertInfo:@"清理完成" parent:self];
            [self getDeviceStorageInfo];
            [self loadStorageInfo];
        });
    });
}

- (void)clearAllChatMedia
{
    [self showLoading:@"正在清理聊天数据..."];
    
    // 先调用服务端接口1008-4-26清空所有消息记录（使服务端不再返回漫游消息）
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    NSString *uid = localUser ? localUser.user_uid : nil;
    
    if (uid) {
        [[HttpRestHelper sharedInstance] submitClearAllMessagesToServer:uid complete:^(BOOL sucess, long long clearTime) {
            if (sucess) {
                // 服务端清空成功，保存clear_time到本地以备后续使用
                if (clearTime > 0) {
                    [[NSUserDefaults standardUserDefaults] setObject:@(clearTime) forKey:@"last_clear_all_messages_time"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
                
                // 继续清理本地数据
                [self doLocalClearAllChatMedia];
            } else {
                // 服务端清空失败，提示用户但仍然清理本地
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideLoading];
                    
                    __weak typeof(self) safeSelf = self;
                    [BasicTool areYouSureAlert:@"提示"
                                       content:@"服务端清空失败，是否仍然清理本地聊天数据？\n（清理后漫游消息可能仍会恢复）"
                                   okBtnTitle:@"继续清理"
                               cancelBtnTitle:@"取消"
                                       parent:self
                                    okHandler:^(UIAlertAction * _Nullable action) {
                                        [safeSelf showLoading:@"正在清理本地数据..."];
                                        [safeSelf doLocalClearAllChatMedia];
                                    }
                                cancelHandler:nil];
                });
            }
        } hudParentView:nil];
    } else {
        // uid为空时直接清理本地
        [self doLocalClearAllChatMedia];
    }
}

// 执行本地聊天数据清理（清理媒体文件+数据库记录+会话列表）
- (void)doLocalClearAllChatMedia
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 清理所有媒体目录
        [self deleteDirectory:[self getVideoDirectory]];
        [self deleteDirectory:[self getImageDirectory]];
        NSString *photoDir    = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_PHOTO_RELATIVE_DIR];
        NSString *phoneAlbumDir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_PHONE_ALBUM_RELATIVE_DIR];
        NSString *locationDir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_LOCATION_RELATIVE_DIR];
        NSString *voiceDir    = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_SENDVOICE_RELATIVE_DIR];
        NSString *fileDir     = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_FILE_RELATIVE_DIR];
        [self deleteDirectory:photoDir];
        [self deleteDirectory:phoneAlbumDir];
        [self deleteDirectory:locationDir];
        [self deleteDirectory:voiceDir];
        [self deleteDirectory:fileDir];
        
        // 清理数据库记录
        UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
        if (localUser) {
            [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
                NSString *where = [NSString stringWithFormat:@"_acount_uid='%@'", localUser.user_uid];
                [[MyDataBase sharedInstance].chatHistoryTable delete:db tableName:@"chat_msg" filterSQL:where debugTag:@"clearAllChatMedia"];
                [[MyDataBase sharedInstance].groupChatHistoryTable delete:db tableName:@"groupchat_msg" filterSQL:where debugTag:@"clearAllChatMedia.group"];
            }];
        }
        
        // 清理会话列表中的所有对话（使首页消息列表变空）
        AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
        NSMutableArrayObservableEx *alarms = [ap getAlarmsData];
        NSInteger count = [[alarms getDataList] count];
        for (NSInteger i = count - 1; i >= 0; i--) {
            // 最后一个移除时发送通知，触发UI刷新
            BOOL isLast = (i == 0);
            [ap removeAlarm:(int)i notify:isLast deleteAlarmLocalData:YES deleteLocalData:YES];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideLoading];
            [BasicTool showAlertInfo:@"清理完成" parent:self];
            [self getDeviceStorageInfo];
            [self loadStorageInfo];
        });
    });
}

- (void)clearOtherFiles
{
    [self showLoading:@"正在清理资源文件..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *basePath = [FileTool getCachedPath];
        NSString *workRoot = [basePath stringByAppendingPathComponent:DIR_KCHAT_WORK_RELATIVE_ROOT];
        
        NSArray *otherDirs = @[
            [workRoot stringByAppendingPathComponent:@"avatar"],
            [workRoot stringByAppendingPathComponent:@"voice"],
            [workRoot stringByAppendingPathComponent:@"pvoice"],
            [workRoot stringByAppendingPathComponent:@"file"]
        ];
        
        for (NSString *dir in otherDirs) {
            [self deleteDirectory:dir];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideLoading];
            [BasicTool showAlertInfo:@"清理完成" parent:self];
            [self getDeviceStorageInfo];
            [self loadStorageInfo];
        });
    });
}

- (void)clearFilesOlderThanDays:(NSInteger)days
{
    [self showLoading:@"正在按时间清理..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDate *cutoffDate = [NSDate dateWithTimeIntervalSinceNow:-days * 24 * 60 * 60];
        long long totalDeleted = 0;
        
        totalDeleted += [self deleteFilesBeforeDate:cutoffDate inDirectory:[self getVideoDirectory]];
        totalDeleted += [self deleteFilesBeforeDate:cutoffDate inDirectory:[self getImageDirectory]];
        
        NSString *basePath = [FileTool getCachedPath];
        NSString *workRoot = [basePath stringByAppendingPathComponent:DIR_KCHAT_WORK_RELATIVE_ROOT];
        NSArray *otherDirs = @[
            [workRoot stringByAppendingPathComponent:@"avatar"],
            [workRoot stringByAppendingPathComponent:@"voice"],
            [workRoot stringByAppendingPathComponent:@"pvoice"],
            [workRoot stringByAppendingPathComponent:@"file"]
        ];
        
        for (NSString *dir in otherDirs) {
            totalDeleted += [self deleteFilesBeforeDate:cutoffDate inDirectory:dir];
        }
        
        UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
        if (localUser) {
            [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
                NSString *where = [NSString stringWithFormat:@"_acount_uid='%@' and _update_time<=datetime('%@','-%ld day')"
                                   , localUser.user_uid
                                   , [TimeTool getCurrentDatePartStr], (long)days];
                [[MyDataBase sharedInstance].chatHistoryTable delete:db tableName:@"chat_msg" filterSQL:where debugTag:@"clearFilesOlderThanDays"];
                
                NSString *groupWhere = [NSString stringWithFormat:@"_acount_uid='%@' and _update_time<=datetime('%@','-%ld day')"
                                        , localUser.user_uid
                                        , [TimeTool getCurrentDatePartStr], (long)days];
                [[MyDataBase sharedInstance].groupChatHistoryTable delete:db tableName:@"groupchat_msg" filterSQL:groupWhere debugTag:@"clearFilesOlderThanDays.group"];
            }];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideLoading];
            [BasicTool showAlertInfo:[NSString stringWithFormat:@"清理完成，已释放 %@ 空间", [FileTool getConvenientFileSize:totalDeleted]] parent:self];
            [self getDeviceStorageInfo];
            [self loadStorageInfo];
        });
    });
}

#pragma mark - 文件操作

- (void)deleteDirectory:(NSString *)directoryPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:directoryPath]) {
        NSError *error = nil;
        [fileManager removeItemAtPath:directoryPath error:&error];
        if (error) {
            DDLogWarn(@"删除目录失败: %@, 错误: %@", directoryPath, error);
        }
    }
}

- (long long)deleteFilesBeforeDate:(NSDate *)cutoffDate inDirectory:(NSString *)directoryPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    
    if (![fileManager fileExistsAtPath:directoryPath isDirectory:&isDirectory] || !isDirectory) {
        return 0;
    }
    
    long long deletedSize = 0;
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:directoryPath];
    NSMutableArray *filesToDelete = [NSMutableArray array];
    
    for (NSString *fileName in enumerator) {
        NSString *filePath = [directoryPath stringByAppendingPathComponent:fileName];
        BOOL isDir = NO;
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDir] && !isDir) {
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
            NSDate *fileDate = [attributes objectForKey:NSFileModificationDate];
            
            if (fileDate && [fileDate compare:cutoffDate] == NSOrderedAscending) {
                long long fileSize = [FileTool fileSizeAtPath:filePath];
                [filesToDelete addObject:filePath];
                deletedSize += fileSize;
            }
        }
    }
    
    for (NSString *filePath in filesToDelete) {
        NSError *error = nil;
        [fileManager removeItemAtPath:filePath error:&error];
        if (error) {
            DDLogWarn(@"删除文件失败: %@, 错误: %@", filePath, error);
        }
    }
    
    return deletedSize;
}

#pragma mark - 加载提示

- (void)showLoading:(NSString *)message
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = message;
    hud.mode = MBProgressHUDModeIndeterminate;
}

- (void)hideLoading
{
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

@end
