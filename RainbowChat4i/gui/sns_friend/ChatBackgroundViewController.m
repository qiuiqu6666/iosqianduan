//telegram @wz662
#import "ChatBackgroundViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "BasicTool.h"
#import "FileTool.h"
#import "LPActionSheet.h"
#import "MBProgressHUD.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

// 预设背景图片名称列表
static NSArray *kPresetBackgroundNames = nil;

// 推荐背景（Bundle 内图片名，可后续在 Images.xcassets 中添加）
static NSArray<NSString *> *kRecommendedBackgroundNames = nil;
// 推荐背景每张图下方的标题（与 kRecommendedBackgroundNames 顺序一致）
static NSArray<NSString *> *kRecommendedBackgroundTitles = nil;

// 预设纯色背景
static NSArray *kPresetColors = nil;

@interface ChatBackgroundViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, copy) NSString *chatId;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, assign) NSInteger selectedIndex; // -1=无选中, 0=从相册, 1~N=预设

// 折叠：选择一个颜色 / 推荐背景
@property (nonatomic, assign) BOOL colorSectionExpanded;
@property (nonatomic, assign) BOOL recommendSectionExpanded;
@property (nonatomic, strong) NSLayoutConstraint *colorGridHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *recommendSectionHeightConstraint;
@property (nonatomic, strong) UIView *colorSectionContentView;
@property (nonatomic, strong) UIView *recommendSectionContentView;
@property (nonatomic, strong) UILabel *recommendSourceLabel;
@property (nonatomic, strong) NSLayoutConstraint *recommendSourceLabelHeightConstraint;
@property (nonatomic, strong) UIImageView *colorSectionChevron;
@property (nonatomic, strong) UIImageView *recommendSectionChevron;
@end

@implementation ChatBackgroundViewController

+ (void)initialize {
    if (self == [ChatBackgroundViewController class]) {
        // 推荐背景图（需在 Images.xcassets 中添加对应资源，如无则显示占位色）
        kRecommendedBackgroundNames = @[ @"chat_bg_recommend_1", @"chat_bg_recommend_2", @"chat_bg_recommend_3", @"chat_bg_recommend_4", @"chat_bg_recommend_5", @"chat_bg_recommend_6" ];
        kRecommendedBackgroundTitles = @[ @"夏日", @"星空", @"跑车", @"美女", @"速度", @"风景" ];
        // 预设纯色背景（微信风格）
        kPresetColors = @[
            @(0xEDEDED), // 默认浅灰（与聊天主背景一致）
            @(0xC8E6C9), // 淡绿
            @(0xBBDEFB), // 淡蓝
            @(0xFFCDD2), // 淡红/粉
            @(0xFFF9C4), // 淡黄
            @(0xE1BEE7), // 淡紫
            @(0xFFE0B2), // 淡橘
            @(0xB2DFDB), // 淡青
            @(0xD7CCC8), // 淡棕
        ];
    }
}

#pragma mark - 初始化

- (instancetype)initWithChatId:(NSString *)chatId {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _chatId = [chatId copy];
        _selectedIndex = -1;
        _colorSectionExpanded = NO;   // 选择一个颜色默认折叠
        _recommendSectionExpanded = YES;  // 推荐背景默认展开
    }
    return self;
}

- (void)loadView {
    self.view = [[UIView alloc] init];
}

#pragma mark - 生命周期

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"选择背景图";
    self.view.backgroundColor = HexColor(0xF0F0F0);
    self.navigationItem.titleView = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @"选择背景图"];
    
    [self buildUI];
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

- (void)buildUI {
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    if (@available(iOS 11.0, *)) {
        scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
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
    
    // ========== Section 1: 选择背景图 ==========
    UIView *section1 = [self buildMenuSection];
    [contentView addSubview:section1];
    [NSLayoutConstraint activateConstraints:@[
        [section1.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [section1.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section1.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // ========== 选择一个颜色（上方，可折叠）==========
    UIView *colorHeaderRow = [self buildFoldableSectionHeaderWithTitle:@"选择一个颜色"
                                                              expanded:_colorSectionExpanded
                                                          isColorSection:YES
                                                                 action:@selector(tapColorSectionHeader:)];
    [contentView addSubview:colorHeaderRow];
    [NSLayoutConstraint activateConstraints:@[
        [colorHeaderRow.topAnchor constraintEqualToAnchor:section1.bottomAnchor constant:20],
        [colorHeaderRow.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [colorHeaderRow.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [colorHeaderRow.heightAnchor constraintEqualToConstant:44],
    ]];
    
    UIView *section2 = [self buildColorGridSection];
    self.colorSectionContentView = section2;
    [contentView addSubview:section2];
    [NSLayoutConstraint activateConstraints:@[
        [section2.topAnchor constraintEqualToAnchor:colorHeaderRow.bottomAnchor constant:0],
        [section2.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [section2.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    // ========== 推荐背景（下方，可折叠）==========
    UIView *recommendHeaderRow = [self buildFoldableSectionHeaderWithTitle:@"推荐背景"
                                                                    expanded:_recommendSectionExpanded
                                                                isColorSection:NO
                                                                       action:@selector(tapRecommendSectionHeader:)];
    [contentView addSubview:recommendHeaderRow];
    [NSLayoutConstraint activateConstraints:@[
        [recommendHeaderRow.topAnchor constraintEqualToAnchor:section2.bottomAnchor constant:20],
        [recommendHeaderRow.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [recommendHeaderRow.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [recommendHeaderRow.heightAnchor constraintEqualToConstant:44],
    ]];
    
    UIView *recommendSection = [self buildRecommendedSection];
    self.recommendSectionContentView = recommendSection;
    [contentView addSubview:recommendSection];
    [NSLayoutConstraint activateConstraints:@[
        [recommendSection.topAnchor constraintEqualToAnchor:recommendHeaderRow.bottomAnchor constant:0],
        [recommendSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [recommendSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    
    UILabel *sourceLabel = [[UILabel alloc] init];
    sourceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    sourceLabel.text = @"来源: freepik.com";
    sourceLabel.font = [UIFont systemFontOfSize:12];
    sourceLabel.textColor = [UIColor colorWithRed:0.68 green:0.68 blue:0.70 alpha:1.0];
    [contentView addSubview:sourceLabel];
    self.recommendSourceLabel = sourceLabel;
    NSLayoutConstraint *sourceHeight = [sourceLabel.heightAnchor constraintEqualToConstant:20];
    sourceHeight.active = YES;
    self.recommendSourceLabelHeightConstraint = sourceHeight;
    [NSLayoutConstraint activateConstraints:@[
        [sourceLabel.topAnchor constraintEqualToAnchor:recommendSection.bottomAnchor constant:8],
        [sourceLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [sourceLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-30],
    ]];
    
    // 根据初始折叠状态更新显示
    [self updateColorSectionFoldAnimated:NO];
    [self updateRecommendSectionFoldAnimated:NO];
}

#pragma mark - 菜单区域

- (UIView *)buildMenuSection {
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];
    
    // 从手机相册选择
    UIView *row1 = [self buildArrowRow:@"从手机相册选择" action:@selector(clickChooseFromAlbum:)];
    [section addSubview:row1];
    
    UIView *sep = [self buildSeparator];
    [section addSubview:sep];
    
    // 恢复默认聊天背景
    UIView *row2 = [self buildArrowRow:@"恢复默认聊天背景" action:@selector(clickResetDefault:)];
    [section addSubview:row2];
    
    [NSLayoutConstraint activateConstraints:@[
        [row1.topAnchor constraintEqualToAnchor:section.topAnchor],
        [row1.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row1.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row1.heightAnchor constraintEqualToConstant:56],
        
        [sep.topAnchor constraintEqualToAnchor:row1.bottomAnchor],
        [sep.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [sep.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [sep.heightAnchor constraintEqualToConstant:0.5],
        
        [row2.topAnchor constraintEqualToAnchor:sep.bottomAnchor],
        [row2.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row2.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row2.heightAnchor constraintEqualToConstant:56],
        
        [row2.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
    ]];
    
    return section;
}

#pragma mark - 可折叠标题行

- (UIView *)buildFoldableSectionHeaderWithTitle:(NSString *)title
                                      expanded:(BOOL)expanded
                                isColorSection:(BOOL)isColorSection
                                        action:(SEL)action {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:14];
    label.textColor = [UIColor colorWithRed:0.56 green:0.56 blue:0.58 alpha:1.0];
    [row addSubview:label];
    
    UIImageView *chevron = [[UIImageView alloc] init];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) {
        chevron.image = [UIImage systemImageNamed:expanded ? @"chevron.down" : @"chevron.right"];
        chevron.tintColor = [UIColor colorWithRed:0.56 green:0.56 blue:0.58 alpha:1.0];
    }
    [row addSubview:chevron];
    if (isColorSection) {
        self.colorSectionChevron = chevron;
    } else {
        self.recommendSectionChevron = chevron;
    }
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:btn];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [chevron.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-20],
        [chevron.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:14],
        [chevron.heightAnchor constraintEqualToConstant:14],
        [btn.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:row.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
    ]];
    
    return row;
}

- (void)tapColorSectionHeader:(id)sender {
    _colorSectionExpanded = !_colorSectionExpanded;
    [self updateColorSectionFoldAnimated:YES];
}

- (void)tapRecommendSectionHeader:(id)sender {
    _recommendSectionExpanded = !_recommendSectionExpanded;
    [self updateRecommendSectionFoldAnimated:YES];
}

- (void)updateColorSectionFoldAnimated:(BOOL)animated {
    CGFloat targetHeight = _colorSectionExpanded ? (CGFloat)[self colorGridExpandedHeight] : 0;
    self.colorSectionContentView.hidden = !_colorSectionExpanded;
    self.colorGridHeightConstraint.constant = targetHeight;
    if (self.colorSectionChevron && @available(iOS 13.0, *)) {
        self.colorSectionChevron.image = [UIImage systemImageNamed:_colorSectionExpanded ? @"chevron.down" : @"chevron.right"];
    }
    if (animated) {
        [UIView animateWithDuration:0.25 animations:^{ [self.view layoutIfNeeded]; }];
    }
}

- (void)updateRecommendSectionFoldAnimated:(BOOL)animated {
    CGFloat targetHeight = _recommendSectionExpanded ? (CGFloat)[self recommendSectionExpandedHeight] : 0;
    self.recommendSectionContentView.hidden = !_recommendSectionExpanded;
    self.recommendSourceLabel.hidden = !_recommendSectionExpanded;
    self.recommendSourceLabelHeightConstraint.constant = _recommendSectionExpanded ? 20 : 0;
    self.recommendSectionHeightConstraint.constant = targetHeight;
    if (self.recommendSectionChevron && @available(iOS 13.0, *)) {
        self.recommendSectionChevron.image = [UIImage systemImageNamed:_recommendSectionExpanded ? @"chevron.down" : @"chevron.right"];
    }
    if (animated) {
        [UIView animateWithDuration:0.25 animations:^{ [self.view layoutIfNeeded]; }];
    }
}

- (CGFloat)colorGridExpandedHeight {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat padding = 20;
    CGFloat spacing = 12;
    int columns = 3;
    CGFloat cellSize = (screenWidth - padding * 2 - spacing * (columns - 1)) / columns;
    NSInteger count = kPresetColors.count;
    int rows = (int)ceil((double)count / columns);
    return rows * cellSize + (rows - 1) * spacing + padding * 2;
}

- (CGFloat)recommendSectionExpandedHeight {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat padding = 20;
    CGFloat spacing = 12;
    NSInteger count = kRecommendedBackgroundNames.count;
    NSInteger cols = 3;
    NSInteger rows = (count + cols - 1) / cols;
    CGFloat cellWidth = (screenWidth - padding * 2 - spacing * (cols - 1)) / (CGFloat)cols;
    CGFloat imageHeight = cellWidth * 0.78;
    CGFloat labelHeight = 20;
    CGFloat labelGap = 4;
    CGFloat cellHeight = imageHeight + labelGap + labelHeight;
    return padding * 2 + cellHeight * rows + spacing * (rows - 1);
}

#pragma mark - 推荐背景区域

- (UIView *)buildRecommendedSection {
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];
    
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat padding = 20;
    CGFloat spacing = 12;
    NSInteger count = kRecommendedBackgroundNames.count;
    NSInteger cols = 3;
    NSInteger rows = (count + cols - 1) / cols;
    CGFloat cellWidth = (screenWidth - padding * 2 - spacing * (cols - 1)) / (CGFloat)cols;
    CGFloat imageHeight = cellWidth * 0.78;
    CGFloat labelHeight = 20;
    CGFloat labelGap = 4;
    CGFloat cellHeight = imageHeight + labelGap + labelHeight;
    CGFloat totalHeight = padding * 2 + cellHeight * rows + spacing * (rows - 1);
    
    self.recommendSectionHeightConstraint = [section.heightAnchor constraintEqualToConstant:totalHeight];
    self.recommendSectionHeightConstraint.active = YES;
    
    for (NSInteger i = 0; i < count; i++) {
        NSString *imageName = kRecommendedBackgroundNames[i];
        NSString *title = (i < (NSInteger)kRecommendedBackgroundTitles.count) ? kRecommendedBackgroundTitles[i] : @"";
        UIImage *img = [UIImage imageNamed:imageName];
        
        NSInteger row = i / cols;
        NSInteger col = i % cols;
        CGFloat x = padding + (cellWidth + spacing) * (CGFloat)col;
        CGFloat y = padding + (cellHeight + spacing) * (CGFloat)row;
        
        UIView *cell = [[UIView alloc] init];
        cell.translatesAutoresizingMaskIntoConstraints = NO;
        cell.tag = 200 + i;
        cell.userInteractionEnabled = YES;
        
        UIView *imageContainer = [[UIView alloc] init];
        imageContainer.translatesAutoresizingMaskIntoConstraints = NO;
        imageContainer.layer.cornerRadius = 8;
        imageContainer.layer.masksToBounds = YES;
        [cell addSubview:imageContainer];
        
        if (img) {
            UIImageView *iv = [[UIImageView alloc] initWithImage:img];
            iv.translatesAutoresizingMaskIntoConstraints = NO;
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;
            [imageContainer addSubview:iv];
            [NSLayoutConstraint activateConstraints:@[
                [iv.leadingAnchor constraintEqualToAnchor:imageContainer.leadingAnchor],
                [iv.trailingAnchor constraintEqualToAnchor:imageContainer.trailingAnchor],
                [iv.topAnchor constraintEqualToAnchor:imageContainer.topAnchor],
                [iv.bottomAnchor constraintEqualToAnchor:imageContainer.bottomAnchor],
            ]];
        } else {
            imageContainer.backgroundColor = HexColor(0xE8E8E8);
        }
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:12];
        titleLabel.textColor = [UIColor colorWithRed:0.45 green:0.45 blue:0.47 alpha:1.0];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        [cell addSubview:titleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [imageContainer.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor],
            [imageContainer.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor],
            [imageContainer.topAnchor constraintEqualToAnchor:cell.topAnchor],
            [imageContainer.heightAnchor constraintEqualToConstant:imageHeight],
            [titleLabel.topAnchor constraintEqualToAnchor:imageContainer.bottomAnchor constant:labelGap],
            [titleLabel.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor],
            [titleLabel.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor],
            [titleLabel.heightAnchor constraintEqualToConstant:labelHeight],
        ]];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clickRecommendedBackground:)];
        [cell addGestureRecognizer:tap];
        [section addSubview:cell];
        
        [NSLayoutConstraint activateConstraints:@[
            [cell.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:x],
            [cell.topAnchor constraintEqualToAnchor:section.topAnchor constant:y],
            [cell.widthAnchor constraintEqualToConstant:cellWidth],
            [cell.heightAnchor constraintEqualToConstant:cellHeight],
        ]];
    }
    
    return section;
}

#pragma mark - 颜色网格区域

- (UIView *)buildColorGridSection {
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];
    
    // 使用简单的网格布局
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat padding = 20;
    CGFloat spacing = 12;
    int columns = 3;
    CGFloat cellSize = (screenWidth - padding * 2 - spacing * (columns - 1)) / columns;
    
    NSInteger count = kPresetColors.count;
    int rows = (int)ceil((double)count / columns);
    CGFloat totalHeight = rows * cellSize + (rows - 1) * spacing + padding * 2;
    
    self.colorGridHeightConstraint = [section.heightAnchor constraintEqualToConstant:totalHeight];
    self.colorGridHeightConstraint.active = YES;
    
    for (NSInteger i = 0; i < count; i++) {
        int row = (int)i / columns;
        int col = (int)i % columns;
        
        NSNumber *colorNum = kPresetColors[i];
        NSInteger hex = [colorNum integerValue];
        UIColor *color = [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                                         green:((hex >> 8) & 0xFF) / 255.0
                                          blue:(hex & 0xFF) / 255.0
                                         alpha:1.0];
        
        UIView *colorView = [[UIView alloc] init];
        colorView.translatesAutoresizingMaskIntoConstraints = NO;
        colorView.backgroundColor = color;
        colorView.layer.cornerRadius = 8;
        colorView.layer.masksToBounds = YES;
        colorView.tag = 100 + i;
        
        // 添加边框（如果是当前选中的背景颜色）
        colorView.layer.borderWidth = 0;
        colorView.layer.borderColor = [UIColor colorWithRed:0.2039 green:0.7804 blue:0.349 alpha:1.0].CGColor;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clickPresetColor:)];
        [colorView addGestureRecognizer:tap];
        colorView.userInteractionEnabled = YES;
        
        [section addSubview:colorView];
        
        CGFloat x = padding + col * (cellSize + spacing);
        CGFloat y = padding + row * (cellSize + spacing);
        
        [NSLayoutConstraint activateConstraints:@[
            [colorView.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:x],
            [colorView.topAnchor constraintEqualToAnchor:section.topAnchor constant:y],
            [colorView.widthAnchor constraintEqualToConstant:cellSize],
            [colorView.heightAnchor constraintEqualToConstant:cellSize],
        ]];
    }
    
    return section;
}

#pragma mark - 通用行构建器

- (UIView *)buildArrowRow:(NSString *)title action:(SEL)action {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:btn];
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:17];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    label.userInteractionEnabled = NO;
    [row addSubview:label];
    
    UIImageView *arrow = [[UIImageView alloc] init];
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.image = [UIImage imageNamed:@"common_list_rightarrow_icon_nor"];
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    arrow.userInteractionEnabled = NO;
    [row addSubview:arrow];
    
    [NSLayoutConstraint activateConstraints:@[
        [btn.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:row.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrow.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [arrow.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrow.widthAnchor constraintEqualToConstant:8],
        [arrow.heightAnchor constraintEqualToConstant:14],
    ]];
    
    return row;
}

- (UIView *)buildSeparator {
    UIView *sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
    return sep;
}

#pragma mark - 事件处理

// 从手机相册选择
- (void)clickChooseFromAlbum:(id)sender {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.allowsEditing = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

// 恢复默认聊天背景
- (void)clickResetDefault:(id)sender {
    __weak typeof(self) weakSelf = self;
    
    [LPActionSheet showActionSheetWithTitle:@"恢复默认聊天背景？"
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:@"恢复默认"
                          otherButtonTitles:nil
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == -1) {
            [ChatBackgroundViewController removeBackgroundForChatId:weakSelf.chatId];
            
            // 发送通知
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_ChatBackgroundChanged
                                                                object:nil
                                                              userInfo:@{@"chatId": weakSelf.chatId ?: @""}];
            
            [BasicTool showUserDefintToast:@"已恢复默认背景" view:weakSelf.view atHide:nil];
        }
    }];
}

// 点击推荐背景
- (void)clickRecommendedBackground:(UITapGestureRecognizer *)tap {
    NSInteger index = tap.view.tag - 200;
    if (index < 0 || index >= (NSInteger)kRecommendedBackgroundNames.count) return;
    NSString *imageName = kRecommendedBackgroundNames[index];
    UIImage *img = [UIImage imageNamed:imageName];
    if (!img) {
        [BasicTool showUserDefintToast:@"该推荐背景暂不可用" view:self.view atHide:nil];
        return;
    }
    [self saveBackgroundImage:img forChatId:self.chatId];
    NSString *typeKey = [NSString stringWithFormat:@"CHAT_BG_TYPE_%@", self.chatId];
    [[NSUserDefaults standardUserDefaults] setObject:@"image" forKey:typeKey];
    NSString *colorKey = [NSString stringWithFormat:@"CHAT_BG_COLOR_%@", self.chatId];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:colorKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_ChatBackgroundChanged object:nil userInfo:@{@"chatId": self.chatId ?: @""}];
    [self updateColorSelectionForIndex:-1];
    [BasicTool showUserDefintToast:@"已设置聊天背景" view:self.view atHide:nil];
}

// 点击预设颜色
- (void)clickPresetColor:(UITapGestureRecognizer *)tap {
    NSInteger index = tap.view.tag - 100;
    if (index < 0 || index >= (NSInteger)kPresetColors.count) return;
    
    NSNumber *colorNum = kPresetColors[index];
    NSInteger hex = [colorNum integerValue];
    
    // 创建纯色图片并保存
    UIColor *color = [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                                     green:((hex >> 8) & 0xFF) / 255.0
                                      blue:(hex & 0xFF) / 255.0
                                     alpha:1.0];
    
    CGRect rect = CGRectMake(0, 0, 1, 1);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, rect);
    UIImage *colorImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // 保存颜色hex到UserDefaults（用于以颜色方式恢复，性能更好）
    NSString *key = [NSString stringWithFormat:@"CHAT_BG_COLOR_%@", self.chatId];
    [[NSUserDefaults standardUserDefaults] setInteger:hex forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 同时保存图片文件
    [self saveBackgroundImage:colorImage forChatId:self.chatId];
    
    // 标记为颜色类型背景
    NSString *typeKey = [NSString stringWithFormat:@"CHAT_BG_TYPE_%@", self.chatId];
    [[NSUserDefaults standardUserDefaults] setObject:@"color" forKey:typeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 发送通知
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_ChatBackgroundChanged
                                                        object:nil
                                                      userInfo:@{@"chatId": self.chatId ?: @""}];
    
    // 更新选中状态
    [self updateColorSelectionForIndex:index];
    
    [BasicTool showUserDefintToast:@"已设置聊天背景" view:self.view atHide:nil];
}

- (void)updateColorSelectionForIndex:(NSInteger)selectedIdx {
    // 重置所有颜色方块的边框
    for (NSInteger i = 0; i < (NSInteger)kPresetColors.count; i++) {
        UIView *colorView = [self.view viewWithTag:100 + i];
        if (colorView) {
            colorView.layer.borderWidth = (i == selectedIdx) ? 3.0 : 0;
        }
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (!image) {
        [picker dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    [picker dismissViewControllerAnimated:YES completion:^{
        // 保存图片
        [weakSelf saveBackgroundImage:image forChatId:weakSelf.chatId];
        
        // 标记为图片类型背景
        NSString *typeKey = [NSString stringWithFormat:@"CHAT_BG_TYPE_%@", weakSelf.chatId];
        [[NSUserDefaults standardUserDefaults] setObject:@"image" forKey:typeKey];
        
        // 清除颜色记录
        NSString *colorKey = [NSString stringWithFormat:@"CHAT_BG_COLOR_%@", weakSelf.chatId];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:colorKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // 发送通知
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_ChatBackgroundChanged
                                                            object:nil
                                                          userInfo:@{@"chatId": weakSelf.chatId ?: @""}];
        
        // 重置颜色选中
        [weakSelf updateColorSelectionForIndex:-1];
        
        [BasicTool showUserDefintToast:@"已设置聊天背景" view:weakSelf.view atHide:nil];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 图片存储

- (void)saveBackgroundImage:(UIImage *)image forChatId:(NSString *)chatId {
    NSString *path = [ChatBackgroundViewController backgroundImagePathForChatId:chatId];
    
    // 确保目录存在
    NSString *dir = [path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    
    // 保存为JPEG（压缩率0.85，平衡质量和大小）
    NSData *imageData = UIImageJPEGRepresentation(image, 0.85);
    [imageData writeToFile:path atomically:YES];
}

#pragma mark - 静态方法

+ (UIImage *)backgroundImageForChatId:(NSString *)chatId {
    if (!chatId || chatId.length == 0) return nil;
    
    NSString *path = [self backgroundImagePathForChatId:chatId];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return [UIImage imageWithContentsOfFile:path];
    }
    return nil;
}

+ (void)removeBackgroundForChatId:(NSString *)chatId {
    if (!chatId || chatId.length == 0) return;
    
    NSString *path = [self backgroundImagePathForChatId:chatId];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    
    // 清除UserDefaults中的记录
    NSString *typeKey = [NSString stringWithFormat:@"CHAT_BG_TYPE_%@", chatId];
    NSString *colorKey = [NSString stringWithFormat:@"CHAT_BG_COLOR_%@", chatId];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:typeKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:colorKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)backgroundImagePathForChatId:(NSString *)chatId {
    NSString *docPath = [FileTool getCachedPath];
    NSString *bgDir = [docPath stringByAppendingPathComponent:@"chat_backgrounds"];
    NSString *fileName = [NSString stringWithFormat:@"bg_%@.jpg", chatId];
    return [bgDir stringByAppendingPathComponent:fileName];
}

+ (BOOL)isSolidColorChatBackgroundForChatId:(NSString *)chatId {
    if (!chatId.length) {
        return NO;
    }
    NSString *typeKey = [NSString stringWithFormat:@"CHAT_BG_TYPE_%@", chatId];
    NSString *type = [[NSUserDefaults standardUserDefaults] stringForKey:typeKey];
    return [type isEqualToString:@"color"];
}

+ (UIColor *)solidChatBackgroundColorForChatId:(NSString *)chatId {
    if (!chatId.length) {
        return nil;
    }
    NSString *colorKey = [NSString stringWithFormat:@"CHAT_BG_COLOR_%@", chatId];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud objectForKey:colorKey] == nil) {
        return nil;
    }
    NSInteger hex = [ud integerForKey:colorKey];
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1.0];
}

@end
