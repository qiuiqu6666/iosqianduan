//
//  ChatSearchMenuViewController.m
//  RainbowChat4i
//
//  聊天记录搜索 — 横向Tab切换
//

#import "ChatSearchMenuViewController.h"
#import "MsgSummaryContentDTO.h"
#import "MsgDetailContent.h"
#import "ViewControllerFactory.h"
#import "MediaBrowserViewController.h"
#import "FileBrowserViewController.h"
#import "DateSearchViewController.h"
#import "MemberMessageViewController.h"
#import "UIViewController+RBPlainCustomNav.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

#pragma mark - TabButton（自定义Tab按钮）

@interface _CSMTabButton : UIButton
@property (nonatomic, strong) UIView *indicator;
@end

@implementation _CSMTabButton

- (instancetype)initWithTitle:(NSString *)title
{
    self = [super init];
    if (self) {
        [self setTitle:title forState:UIControlStateNormal];
        [self setTitleColor:HexColor(0x999999) forState:UIControlStateNormal];
        [self setTitleColor:HexColor(0x333333) forState:UIControlStateSelected];
        self.titleLabel.font = [UIFont systemFontOfSize:15];
        self.translatesAutoresizingMaskIntoConstraints = NO;
        
        _indicator = [[UIView alloc] init];
        _indicator.backgroundColor = HexColor(0x4A90D9);
        _indicator.layer.cornerRadius = 1.5;
        _indicator.translatesAutoresizingMaskIntoConstraints = NO;
        _indicator.hidden = YES;
        [self addSubview:_indicator];
        
        [NSLayoutConstraint activateConstraints:@[
            [_indicator.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_indicator.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_indicator.widthAnchor constraintEqualToConstant:24],
            [_indicator.heightAnchor constraintEqualToConstant:3],
        ]];
    }
    return self;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    self.indicator.hidden = !selected;
    self.titleLabel.font = selected
        ? [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]
        : [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
}

@end

#pragma mark - ChatSearchMenuViewController

@interface ChatSearchMenuViewController ()

@property (nonatomic, assign) int chatType;
@property (nonatomic, copy)   NSString *dataId;
@property (nonatomic, assign) BOOL isGroupChat;

// UI
@property (nonatomic, strong) UIView *searchBarContainer;
@property (nonatomic, strong) UIScrollView *tabBar;
@property (nonatomic, strong) UIView *tabSeparator;
@property (nonatomic, strong) UIView *containerView;

// Tab 数据
@property (nonatomic, strong) NSArray<NSString *> *tabTitles;
@property (nonatomic, strong) NSArray<NSString *> *tabActions;
@property (nonatomic, strong) NSMutableArray<_CSMTabButton *> *tabButtons;

// 子VC（懒加载，nil 表示还未创建）
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIViewController *> *childVCs;
@property (nonatomic, assign) NSInteger currentTabIndex;

@end

@implementation ChatSearchMenuViewController

- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId
                     isGroupChat:(BOOL)isGroupChat
{
    self = [super init];
    if (self) {
        _chatType = chatType;
        _dataId = dataId;
        _isGroupChat = isGroupChat;
        _childVCs = [NSMutableDictionary dictionary];
        _currentTabIndex = -1;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"查找本地聊天内容";
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @"查找本地聊天内容"];
    
    [self buildTabData];
    [self buildUI];
    
    // 默认选中第一个 Tab
    if (self.tabTitles.count > 0) {
        [self selectTabAtIndex:0 animated:NO];
    }
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

#pragma mark - Tab 数据

- (void)buildTabData
{
    NSMutableArray *titles = [NSMutableArray array];
    NSMutableArray *actions = [NSMutableArray array];
    
    [titles addObject:@"图片与视频"];  [actions addObject:@"media"];
    [titles addObject:@"文件"];       [actions addObject:@"file"];
    [titles addObject:@"日期"];       [actions addObject:@"date"];
    
    if (self.isGroupChat) {
        [titles addObject:@"群成员"];  [actions addObject:@"member"];
    }
    
    self.tabTitles = [titles copy];
    self.tabActions = [actions copy];
}

#pragma mark - 构建 UI

- (void)buildUI
{
    // ===== 搜索栏 =====
    self.searchBarContainer = [[UIView alloc] init];
    self.searchBarContainer.backgroundColor = HexColor(0xF5F5F5);
    self.searchBarContainer.layer.cornerRadius = 8;
    self.searchBarContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchBarContainer];
    
    UIImageView *searchIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]];
    searchIcon.tintColor = HexColor(0x999999);
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.searchBarContainer addSubview:searchIcon];
    
    UILabel *searchLabel = [[UILabel alloc] init];
    searchLabel.text = @"仅搜索本地聊天内容";
    searchLabel.textColor = HexColor(0x999999);
    searchLabel.font = [UIFont systemFontOfSize:15];
    searchLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.searchBarContainer addSubview:searchLabel];
    
    UITapGestureRecognizer *searchTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSearchBarTapped)];
    [self.searchBarContainer addGestureRecognizer:searchTap];
    
    // ===== 横向 Tab 栏 =====
    self.tabBar = [[UIScrollView alloc] init];
    self.tabBar.showsHorizontalScrollIndicator = NO;
    self.tabBar.showsVerticalScrollIndicator = NO;
    self.tabBar.bounces = YES;
    self.tabBar.backgroundColor = [UIColor whiteColor];
    self.tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tabBar];
    
    self.tabButtons = [NSMutableArray array];
    UIView *prevButton = nil;
    CGFloat tabPadding = 20;
    
    for (NSInteger i = 0; i < (NSInteger)self.tabTitles.count; i++) {
        _CSMTabButton *btn = [[_CSMTabButton alloc] initWithTitle:self.tabTitles[i]];
        btn.tag = i;
        [btn addTarget:self action:@selector(onTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabBar addSubview:btn];
        [self.tabButtons addObject:btn];
        
        [NSLayoutConstraint activateConstraints:@[
            [btn.topAnchor constraintEqualToAnchor:self.tabBar.topAnchor],
            [btn.bottomAnchor constraintEqualToAnchor:self.tabBar.bottomAnchor],
            [btn.heightAnchor constraintEqualToAnchor:self.tabBar.heightAnchor],
        ]];
        
        if (prevButton) {
            [btn.leadingAnchor constraintEqualToAnchor:prevButton.trailingAnchor constant:tabPadding].active = YES;
        } else {
            [btn.leadingAnchor constraintEqualToAnchor:self.tabBar.leadingAnchor constant:16].active = YES;
        }
        
        // 内容自适应宽度
        [btn.widthAnchor constraintGreaterThanOrEqualToConstant:40].active = YES;
        
        prevButton = btn;
    }
    
    // 最后一个按钮的 trailing
    if (prevButton) {
        [prevButton.trailingAnchor constraintEqualToAnchor:self.tabBar.trailingAnchor constant:-16].active = YES;
    }
    
    // Tab 底部分割线
    self.tabSeparator = [[UIView alloc] init];
    self.tabSeparator.backgroundColor = HexColor(0xE5E5E5);
    self.tabSeparator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tabSeparator];
    
    // ===== 内容容器 =====
    self.containerView = [[UIView alloc] init];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.containerView.clipsToBounds = YES;
    [self.view addSubview:self.containerView];
    
    // ===== Auto Layout =====
    UILayoutGuide *sa = self.view.safeAreaLayoutGuide;
    
    [NSLayoutConstraint activateConstraints:@[
        // 搜索栏
        [self.searchBarContainer.topAnchor constraintEqualToAnchor:sa.topAnchor constant:8],
        [self.searchBarContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.searchBarContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.searchBarContainer.heightAnchor constraintEqualToConstant:36],
        
        [searchIcon.leadingAnchor constraintEqualToAnchor:self.searchBarContainer.leadingAnchor constant:12],
        [searchIcon.centerYAnchor constraintEqualToAnchor:self.searchBarContainer.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:16],
        [searchIcon.heightAnchor constraintEqualToConstant:16],
        
        [searchLabel.leadingAnchor constraintEqualToAnchor:searchIcon.trailingAnchor constant:8],
        [searchLabel.centerYAnchor constraintEqualToAnchor:self.searchBarContainer.centerYAnchor],
        
        // Tab 栏
        [self.tabBar.topAnchor constraintEqualToAnchor:self.searchBarContainer.bottomAnchor constant:8],
        [self.tabBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tabBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tabBar.heightAnchor constraintEqualToConstant:44],
        
        // 分割线
        [self.tabSeparator.topAnchor constraintEqualToAnchor:self.tabBar.bottomAnchor],
        [self.tabSeparator.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tabSeparator.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tabSeparator.heightAnchor constraintEqualToConstant:0.5],
        
        // 内容容器
        [self.containerView.topAnchor constraintEqualToAnchor:self.tabSeparator.bottomAnchor],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

#pragma mark - Tab 切换

- (void)onTabTapped:(_CSMTabButton *)sender
{
    [self selectTabAtIndex:sender.tag animated:YES];
}

- (void)selectTabAtIndex:(NSInteger)index animated:(BOOL)animated
{
    if (index == self.currentTabIndex) return;
    
    NSInteger oldIndex = self.currentTabIndex;
    self.currentTabIndex = index;
    
    // 更新按钮状态
    for (NSInteger i = 0; i < (NSInteger)self.tabButtons.count; i++) {
        self.tabButtons[i].selected = (i == index);
    }
    
    // 确保选中的 Tab 按钮可见
    _CSMTabButton *selectedBtn = self.tabButtons[index];
    [self.tabBar scrollRectToVisible:CGRectInset(selectedBtn.frame, -20, 0) animated:animated];
    
    // 隐藏旧的子 VC
    if (oldIndex >= 0) {
        UIViewController *oldVC = self.childVCs[@(oldIndex)];
        if (oldVC) {
            oldVC.view.hidden = YES;
        }
    }
    
    // 显示/创建新的子 VC（懒加载）
    UIViewController *newVC = self.childVCs[@(index)];
    if (!newVC) {
        newVC = [self createChildVCForIndex:index];
        if (newVC) {
            self.childVCs[@(index)] = newVC;
            [self addChildViewController:newVC];
            newVC.view.frame = self.containerView.bounds;
            newVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self.containerView addSubview:newVC.view];
            [newVC didMoveToParentViewController:self];
        }
    } else {
        newVC.view.hidden = NO;
    }
}

- (UIViewController *)createChildVCForIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)self.tabActions.count) return nil;
    
    NSString *action = self.tabActions[index];
    
    if ([action isEqualToString:@"media"]) {
        return [[MediaBrowserViewController alloc] initWithChatType:self.chatType dataId:self.dataId];
    }
    else if ([action isEqualToString:@"file"]) {
        return [[FileBrowserViewController alloc] initWithChatType:self.chatType dataId:self.dataId];
    }
    else if ([action isEqualToString:@"date"]) {
        return [[DateSearchViewController alloc] initWithChatType:self.chatType dataId:self.dataId];
    }
    else if ([action isEqualToString:@"member"]) {
        return [[MemberMessageViewController alloc] initWithGid:self.dataId];
    }
    
    return nil;
}

#pragma mark - 搜索栏

- (void)onSearchBarTapped
{
    MsgSummaryContentDTO *dto = [[MsgSummaryContentDTO alloc] init];
    dto.chatType = self.chatType;
    dto.dataId = self.dataId;
    
    MsgDetailContent *c = [[MsgDetailContent alloc] init];
    c.msgSummaryContentDTO = dto;
    
    [ViewControllerFactory goSearchViewController:self.navigationController
                         supportedSearchableContens:@[c]
                                            keyword:nil
                                      showAllResult:YES];
}

@end
