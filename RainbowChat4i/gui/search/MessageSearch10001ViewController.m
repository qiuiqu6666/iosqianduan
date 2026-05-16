//
//  MessageSearch10001ViewController.m
//  RainbowChat4i
//
//  10001 专用查找消息页面，参考设计图：导航栏标题+副标题、右侧搜索+更多、横向 Tab（对话/多媒体/文件/日期/语音/链接）、内容列表。
//

#import "MessageSearch10001ViewController.h"
#import "MsgSummaryContentDTO.h"
#import "MediaBrowserViewController.h"
#import "FileBrowserViewController.h"
#import "ContactList10001ViewController.h"
#import "LocationList10001ViewController.h"
#import "DateSearchViewController.h"
#import "IMClientManager.h"
#import "MsgBodyRoot.h"
#import "TypeFilteredMessagesViewController.h"
#import "ViewControllerFactory.h"
#import "ChatMessageModeMenu.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
#import <UIKit/UIGlassEffect.h>
#endif

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

#pragma mark - Tab 按钮（选中为浅灰圆角背景，未选中为纯文字）

@interface _MS10001TabButton : UIButton
@property (nonatomic, strong) UIView *pillBackground;
@end

@implementation _MS10001TabButton

- (instancetype)initWithTitle:(NSString *)title
{
    self = [super init];
    if (self) {
        [self setTitle:title forState:UIControlStateNormal];
        [self setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
        [self setTitleColor:HexColor(0x333333) forState:UIControlStateSelected];
        self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        self.translatesAutoresizingMaskIntoConstraints = NO;
        _pillBackground = [[UIView alloc] init];
        _pillBackground.backgroundColor = [UIColor clearColor];
        _pillBackground.layer.cornerRadius = 16;
        _pillBackground.hidden = YES;
        _pillBackground.userInteractionEnabled = NO;
        _pillBackground.translatesAutoresizingMaskIntoConstraints = NO;
        [self insertSubview:_pillBackground atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [_pillBackground.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_pillBackground.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_pillBackground.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:-10],
            [_pillBackground.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:10],
            [_pillBackground.heightAnchor constraintEqualToConstant:32],
        ]];
        // 选中态胶囊：液态玻璃（iOS 26）或模糊（iOS 13+）或纯色
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
        if (@available(iOS 26.0, *)) {
            UIGlassEffect *effect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
            UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:effect];
            glass.layer.cornerRadius = 16;
            glass.clipsToBounds = YES;
            glass.userInteractionEnabled = NO;
            glass.translatesAutoresizingMaskIntoConstraints = NO;
            [_pillBackground addSubview:glass];
            [NSLayoutConstraint activateConstraints:@[
                [glass.leadingAnchor constraintEqualToAnchor:_pillBackground.leadingAnchor],
                [glass.trailingAnchor constraintEqualToAnchor:_pillBackground.trailingAnchor],
                [glass.topAnchor constraintEqualToAnchor:_pillBackground.topAnchor],
                [glass.bottomAnchor constraintEqualToAnchor:_pillBackground.bottomAnchor],
            ]];
        } else
#endif
        if (@available(iOS 13.0, *)) {
            UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
            blur.layer.cornerRadius = 16;
            blur.clipsToBounds = YES;
            blur.userInteractionEnabled = NO;
            blur.translatesAutoresizingMaskIntoConstraints = NO;
            [_pillBackground addSubview:blur];
            [NSLayoutConstraint activateConstraints:@[
                [blur.leadingAnchor constraintEqualToAnchor:_pillBackground.leadingAnchor],
                [blur.trailingAnchor constraintEqualToAnchor:_pillBackground.trailingAnchor],
                [blur.topAnchor constraintEqualToAnchor:_pillBackground.topAnchor],
                [blur.bottomAnchor constraintEqualToAnchor:_pillBackground.bottomAnchor],
            ]];
        } else {
            _pillBackground.backgroundColor = HexColor(0xE8E8E8);
        }
    }
    return self;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    self.pillBackground.hidden = !selected;
    self.titleLabel.font = selected ? [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] : [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
}

@end

#pragma mark - 对话 Tab 占位（点击进入关键词搜索）

@interface _ConversationSearchPlaceholderView : UIView
@property (nonatomic, copy) void (^onTap)(void);
@end

@implementation _ConversationSearchPlaceholderView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = HexColor(0xF5F5F5);
        UILabel *hint = [[UILabel alloc] init];
        hint.text = @"仅搜索本地聊天内容";
        hint.textColor = HexColor(0x999999);
        hint.font = [UIFont systemFontOfSize:15];
        hint.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:hint];
        UIImageView *searchIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]];
        searchIcon.tintColor = HexColor(0x999999);
        searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:searchIcon];
        [NSLayoutConstraint activateConstraints:@[
            [searchIcon.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:-40],
            [searchIcon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [searchIcon.widthAnchor constraintEqualToConstant:20],
            [searchIcon.heightAnchor constraintEqualToConstant:20],
            [hint.leadingAnchor constraintEqualToAnchor:searchIcon.trailingAnchor constant:8],
            [hint.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)tapped
{
    if (self.onTap) self.onTap();
}

@end

#pragma mark - MessageSearch10001ViewController

@interface MessageSearch10001ViewController () <UISearchBarDelegate>

@property (nonatomic, assign) int chatType;
@property (nonatomic, copy) NSString *dataId;
@property (nonatomic, copy) NSString *partnerName;

@property (nonatomic, strong) UIView *tabWrapper;
@property (nonatomic, strong) UIScrollView *tabBar;
@property (nonatomic, strong) UIView *tabSeparator;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) NSLayoutConstraint *tabWrapperTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *tabWrapperHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *tabSeparatorTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *tabSeparatorHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *containerViewTopToTabConstraint;
@property (nonatomic, strong) NSLayoutConstraint *containerViewTopToSafeAreaConstraint;

@property (nonatomic, strong) NSArray<NSString *> *tabTitles;
@property (nonatomic, strong) NSArray<NSString *> *tabActions;
@property (nonatomic, strong) NSMutableArray<_MS10001TabButton *> *tabButtons;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIViewController *> *childVCs;
@property (nonatomic, assign) NSInteger currentTabIndex;

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIView *searchContainer;
@property (nonatomic, copy)   NSString *currentKeyword;

@property (nonatomic, strong) UIView *searchResultStrip;           /// 键盘上方 accessory：共 N 条消息 + 以消息模式查看
@property (nonatomic, strong) UILabel *searchResultCountLabel;
@property (nonatomic, strong) UIButton *searchResultMessageModeButton;

@property (nonatomic, strong) NSLayoutConstraint *searchContainerTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *searchContainerHeightConstraint;
@property (nonatomic, assign) BOOL searchBarVisible;

@property (nonatomic, strong) UIView *navActionContainer;

@end

@implementation MessageSearch10001ViewController

- (instancetype)initWithChatType:(int)chatType dataId:(NSString *)dataId partnerName:(NSString *)partnerName
{
    self = [super init];
    if (self) {
        _chatType = chatType;
        _dataId = dataId ?: @"";
        _partnerName = partnerName ?: @"";
        _childVCs = [NSMutableDictionary dictionary];
        _currentTabIndex = -1;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    UIImage *backImage = [UIImage systemImageNamed:@"chevron.left"];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:backImage style:UIBarButtonItemStylePlain target:self action:@selector(doBack:)];
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;

    [self buildNavTitleView];
    [self buildTabData];
    [self buildUI];

    if (self.tabTitles.count > 0) {
        [self selectTabAtIndex:0 animated:NO];
    }
}

- (void)buildNavTitleView
{
    self.navigationItem.title = @"收藏夹";

    UIView *container = [ChatMessageModeMenu navSearchMoreCapsuleWithSearchTarget:self
                                                                    searchAction:@selector(onNavSearchTapped)
                                                                      moreTarget:self
                                                                       moreAction:@selector(onNavMoreTapped)];
    self.navActionContainer = container;
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:container];
    self.navigationItem.rightBarButtonItem = rightItem;
}

- (void)buildTabData
{
    self.tabTitles = @[ @"对话", @"多媒体", @"文件", @"名片", @"位置", @"语音", @"链接" ];
    self.tabActions = @[ @"conversation", @"media", @"file", @"contact", @"location", @"voice", @"link" ];
}

- (void)buildUI
{
    UILayoutGuide *sa = self.view.safeAreaLayoutGuide;

    // 顶部仅搜索框；「共 N 条消息」「以消息模式查看」在屏幕底部单独成条
    static const CGFloat kSearchBarHeight = 28.f;
    static const CGFloat kSearchStripHeight = 44.f;
    static const CGFloat kSearchContainerHeight = kSearchBarHeight;  // 仅 28
    self.searchContainer = [[UIView alloc] init];
    self.searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchContainer.backgroundColor = [UIColor clearColor];
    self.searchContainer.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [self.view addSubview:self.searchContainer];

    // 搜索框背景：液态玻璃（iOS 26）或模糊（iOS 13+）或半透明白
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *searchEffect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        UIVisualEffectView *searchGlass = [[UIVisualEffectView alloc] initWithEffect:searchEffect];
        searchGlass.translatesAutoresizingMaskIntoConstraints = NO;
        [self.searchContainer insertSubview:searchGlass atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [searchGlass.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor],
            [searchGlass.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor],
            [searchGlass.topAnchor constraintEqualToAnchor:self.searchContainer.topAnchor],
            [searchGlass.bottomAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor],
        ]];
    } else
#endif
    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *searchBlur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
        searchBlur.translatesAutoresizingMaskIntoConstraints = NO;
        [self.searchContainer insertSubview:searchBlur atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [searchBlur.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor],
            [searchBlur.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor],
            [searchBlur.topAnchor constraintEqualToAnchor:self.searchContainer.topAnchor],
            [searchBlur.bottomAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor],
        ]];
    } else {
        self.searchContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    }

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.placeholder = @"仅搜索当前页面本地聊天记录";
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.showsCancelButton = NO;
    self.searchBar.tintColor = [UIColor blackColor];
    [self.searchContainer addSubview:self.searchBar];

    if (@available(iOS 13.0, *)) {
        UITextField *textField = self.searchBar.searchTextField;
        textField.backgroundColor = [UIColor clearColor];
        textField.layer.cornerRadius = 10.f;
        textField.layer.masksToBounds = YES;
        textField.font = [UIFont systemFontOfSize:14];
        textField.textColor = [UIColor blackColor];
        textField.leftView.tintColor = [UIColor grayColor];
        [self setupSearchResultStripAsInputAccessory];
    }

    self.tabWrapper = [[UIView alloc] init];
    self.tabWrapper.backgroundColor = [UIColor clearColor];
    self.tabWrapper.layer.cornerRadius = 22;
    self.tabWrapper.layer.shadowColor = [UIColor blackColor].CGColor;
    self.tabWrapper.layer.shadowOffset = CGSizeMake(0, 1);
    self.tabWrapper.layer.shadowRadius = 4;
    self.tabWrapper.layer.shadowOpacity = 0.08f;
    self.tabWrapper.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tabWrapper];

    // Tab 栏背景：液态玻璃（iOS 26）或模糊（iOS 13+）或纯白
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *tabEffect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        UIVisualEffectView *tabGlass = [[UIVisualEffectView alloc] initWithEffect:tabEffect];
        tabGlass.layer.cornerRadius = 22;
        tabGlass.clipsToBounds = YES;
        tabGlass.translatesAutoresizingMaskIntoConstraints = NO;
        [self.tabWrapper insertSubview:tabGlass atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [tabGlass.leadingAnchor constraintEqualToAnchor:self.tabWrapper.leadingAnchor],
            [tabGlass.trailingAnchor constraintEqualToAnchor:self.tabWrapper.trailingAnchor],
            [tabGlass.topAnchor constraintEqualToAnchor:self.tabWrapper.topAnchor],
            [tabGlass.bottomAnchor constraintEqualToAnchor:self.tabWrapper.bottomAnchor],
        ]];
    } else
#endif
    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *tabBlur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
        tabBlur.layer.cornerRadius = 22;
        tabBlur.clipsToBounds = YES;
        tabBlur.translatesAutoresizingMaskIntoConstraints = NO;
        [self.tabWrapper insertSubview:tabBlur atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [tabBlur.leadingAnchor constraintEqualToAnchor:self.tabWrapper.leadingAnchor],
            [tabBlur.trailingAnchor constraintEqualToAnchor:self.tabWrapper.trailingAnchor],
            [tabBlur.topAnchor constraintEqualToAnchor:self.tabWrapper.topAnchor],
            [tabBlur.bottomAnchor constraintEqualToAnchor:self.tabWrapper.bottomAnchor],
        ]];
    } else {
        self.tabWrapper.backgroundColor = [UIColor whiteColor];
    }

    self.tabBar = [[UIScrollView alloc] init];
    self.tabBar.showsHorizontalScrollIndicator = NO;
    self.tabBar.backgroundColor = [UIColor clearColor];
    self.tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tabWrapper addSubview:self.tabBar];

    self.tabButtons = [NSMutableArray array];
    UIView *prevButton = nil;
    CGFloat tabPadding = 16;
    for (NSInteger i = 0; i < (NSInteger)self.tabTitles.count; i++) {
        _MS10001TabButton *btn = [[_MS10001TabButton alloc] initWithTitle:self.tabTitles[i]];
        btn.tag = i;
        [btn addTarget:self action:@selector(onTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabBar addSubview:btn];
        [self.tabButtons addObject:btn];
        [NSLayoutConstraint activateConstraints:@[
            [btn.topAnchor constraintEqualToAnchor:self.tabBar.topAnchor],
            [btn.bottomAnchor constraintEqualToAnchor:self.tabBar.bottomAnchor],
            [btn.heightAnchor constraintEqualToConstant:44],
        ]];
        if (prevButton) {
            [btn.leadingAnchor constraintEqualToAnchor:prevButton.trailingAnchor constant:tabPadding].active = YES;
        } else {
            [btn.leadingAnchor constraintEqualToAnchor:self.tabBar.leadingAnchor constant:12].active = YES;
        }
        [btn.widthAnchor constraintGreaterThanOrEqualToConstant:36].active = YES;
        prevButton = btn;
    }
    if (prevButton) {
        [prevButton.trailingAnchor constraintEqualToAnchor:self.tabBar.trailingAnchor constant:-12].active = YES;
    }

    self.tabSeparator = [[UIView alloc] init];
    self.tabSeparator.backgroundColor = HexColor(0xE5E5E5);
    self.tabSeparator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tabSeparator];

    self.containerView = [[UIView alloc] init];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.containerView.clipsToBounds = YES;
    [self.view addSubview:self.containerView];

    self.searchContainerTopConstraint = [self.searchContainer.topAnchor constraintEqualToAnchor:sa.topAnchor constant:4];
    self.searchContainerHeightConstraint = [self.searchContainer.heightAnchor constraintEqualToConstant:kSearchContainerHeight];

    [NSLayoutConstraint activateConstraints:@[
        self.searchContainerTopConstraint,
        [self.searchContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.searchContainerHeightConstraint,

        [self.searchBar.topAnchor constraintEqualToAnchor:self.searchContainer.topAnchor constant:1],
        [self.searchBar.heightAnchor constraintEqualToConstant:kSearchBarHeight],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor constant:12],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor constant:-12],

        (self.tabWrapperTopConstraint = [self.tabWrapper.topAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor constant:8]),
        [self.tabWrapper.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.tabWrapper.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        (self.tabWrapperHeightConstraint = [self.tabWrapper.heightAnchor constraintEqualToConstant:44]),
        [self.tabBar.topAnchor constraintEqualToAnchor:self.tabWrapper.topAnchor],
        [self.tabBar.leadingAnchor constraintEqualToAnchor:self.tabWrapper.leadingAnchor],
        [self.tabBar.trailingAnchor constraintEqualToAnchor:self.tabWrapper.trailingAnchor],
        [self.tabBar.bottomAnchor constraintEqualToAnchor:self.tabWrapper.bottomAnchor],
        (self.tabSeparatorTopConstraint = [self.tabSeparator.topAnchor constraintEqualToAnchor:self.tabWrapper.bottomAnchor constant:8]),
        [self.tabSeparator.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tabSeparator.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        (self.tabSeparatorHeightConstraint = [self.tabSeparator.heightAnchor constraintEqualToConstant:0.5]),
        (self.containerViewTopToTabConstraint = [self.containerView.topAnchor constraintEqualToAnchor:self.tabSeparator.bottomAnchor]),
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // 备用约束：搜索模式下，列表顶到安全区顶部（让内容可“穿过”搜索框）
    self.containerViewTopToSafeAreaConstraint = [self.containerView.topAnchor constraintEqualToAnchor:sa.topAnchor];

    // 初始隐藏搜索栏
    self.searchBarVisible = NO;
    self.searchContainer.hidden = YES;
    self.searchContainerHeightConstraint.constant = 0;
}

- (void)setupSearchResultStripAsInputAccessory
{
    if (self.searchResultStrip) return;
    if (!self.searchBar.searchTextField) return;
    static const CGFloat kStripHeight = 44.f;
    static const CGFloat kPillHeight = 34.f;
    static const CGFloat kLeftMargin = 12.f;
    static const CGFloat kRightMargin = 12.f;
    static const CGFloat kListBtnWidth = 130.f;
    UIView *strip = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 400, kStripHeight)];
    strip.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    strip.backgroundColor = [UIColor clearColor];
    self.searchResultStrip = strip;

    void (^addGlass)(UIView *, CGFloat) = ^(UIView *container, CGFloat radius) {
        UIVisualEffectView *ev = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
        if (@available(iOS 26.0, *)) {
            ev = [[UIVisualEffectView alloc] initWithEffect:[UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular]];
        } else
#endif
        if (@available(iOS 13.0, *)) {
            ev = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
        }
        if (ev) {
            ev.frame = container.bounds;
            ev.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            ev.layer.cornerRadius = radius;
            ev.clipsToBounds = YES;
            ev.userInteractionEnabled = NO;
            [container insertSubview:ev atIndex:0];
        }
    };

    CGFloat rowY = (kStripHeight - kPillHeight) / 2;
    UIView *countPill = [[UIView alloc] initWithFrame:CGRectMake(kLeftMargin, rowY, 120, kPillHeight)];
    countPill.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    countPill.layer.cornerRadius = kPillHeight / 2;
    countPill.layer.masksToBounds = YES;
    addGlass(countPill, kPillHeight / 2);
    [strip addSubview:countPill];

    self.searchResultCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, countPill.bounds.size.width - 24, kPillHeight)];
    self.searchResultCountLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.searchResultCountLabel.textColor = HexColor(0x333333);
    self.searchResultCountLabel.text = @"共 0 条消息";
    self.searchResultCountLabel.numberOfLines = 1;
    [countPill addSubview:self.searchResultCountLabel];

    CGFloat btnX = strip.bounds.size.width - kRightMargin - kListBtnWidth;
    UIButton *msgBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    msgBtn.frame = CGRectMake(btnX, rowY, kListBtnWidth, kPillHeight);
    msgBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    msgBtn.layer.cornerRadius = kPillHeight / 2;
    msgBtn.layer.masksToBounds = YES;
    addGlass(msgBtn, kPillHeight / 2);
    [msgBtn setTitle:@"以消息模式查看" forState:UIControlStateNormal];
    [msgBtn setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
    msgBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [msgBtn addTarget:self action:@selector(onSearchResultMessageMode:) forControlEvents:UIControlEventTouchUpInside];
    [strip addSubview:msgBtn];
    self.searchResultMessageModeButton = msgBtn;

    self.searchBar.searchTextField.inputAccessoryView = strip;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // 从子页 pop 回来且仍处于「搜索展开」态时，需再次隐藏系统导航栏（push 走时曾在 viewWillDisappear 里打开）
    if (self.searchBarVisible && self.navigationController && !self.navigationController.navigationBarHidden) {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    BOOL leavingStack = self.isMovingFromParentViewController || self.isBeingDismissed;
    if (!leavingStack && self.searchBarVisible && self.navigationController && self.navigationController.navigationBarHidden) {
        [self.navigationController setNavigationBarHidden:NO animated:animated];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.showSearchBarOnAppear) {
        self.showSearchBarOnAppear = NO;
        NSString *keyword = [self.initialSearchKeyword copy];
        self.initialSearchKeyword = nil;
        __weak typeof(self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [wself showSearchBarAnimated:YES];
            if (keyword.length > 0) {
                wself.searchBar.text = keyword;
                wself.currentKeyword = keyword;
                [wself applyKeywordToCurrentChild];
            }
        });
    }
}

- (void)onTabTapped:(_MS10001TabButton *)sender
{
    [self selectTabAtIndex:sender.tag animated:YES];
}

- (void)selectTabAtIndex:(NSInteger)index animated:(BOOL)animated
{
    if (index == self.currentTabIndex) return;
    NSInteger oldIndex = self.currentTabIndex;
    self.currentTabIndex = index;

    for (NSInteger i = 0; i < (NSInteger)self.tabButtons.count; i++) {
        self.tabButtons[i].selected = (i == index);
    }
    _MS10001TabButton *selectedBtn = self.tabButtons[index];
    [self.tabBar scrollRectToVisible:CGRectInset(selectedBtn.frame, -20, 0) animated:animated];

    if (oldIndex >= 0) {
        UIViewController *oldVC = self.childVCs[@(oldIndex)];
        if (oldVC) oldVC.view.hidden = YES;
    }

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

    // 切换 Tab 后，把当前搜索关键字同步给新的子控制器，并更新数量条
    if (self.currentKeyword.length > 0) {
        [self applyKeywordToCurrentChild];
    }
    [self updateSearchStripCount];
}

- (UIViewController *)createChildVCForIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)self.tabActions.count) return nil;
    NSString *action = self.tabActions[index];

    if ([action isEqualToString:@"conversation"]) {
        // 对话：统一使用本地消息搜索与分类
        NSArray<NSNumber *> *types = @[
            @(TM_TYPE_TEXT),
            @(TM_TYPE_GIFT_SEND),
            @(TM_TYPE_GIFT_GET),
            @(TM_TYPE_VOIP_RECORD),
            @(TM_TYPE_RED_PACKET),
            @(TM_TYPE_TRANSFER)
        ];
        TypeFilteredMessagesViewController *vc = [[TypeFilteredMessagesViewController alloc] initWithChatType:self.chatType
                                                                                                       dataId:self.dataId
                                                                                                     msgTypes:types
                                                                                                    emptyText:@"暂无对话消息"
                                                                                     excludeTextContainingURL:YES];
        return vc;
    }
    if ([action isEqualToString:@"media"]) {
        MediaBrowserViewController *vc = [[MediaBrowserViewController alloc] initWithChatType:self.chatType dataId:self.dataId];
        return vc;
    }
    if ([action isEqualToString:@"file"]) {
        FileBrowserViewController *vc = [[FileBrowserViewController alloc] initWithChatType:self.chatType dataId:self.dataId];
        return vc;
    }
    if ([action isEqualToString:@"contact"]) {
        return [[ContactList10001ViewController alloc] initWithChatType:self.chatType dataId:self.dataId];
    }
    if ([action isEqualToString:@"location"]) {
        LocationList10001ViewController *vc = [[LocationList10001ViewController alloc] initWithChatType:self.chatType dataId:self.dataId];
        return vc;
    }
    if ([action isEqualToString:@"voice"]) {
        NSArray<NSNumber *> *types = @[ @(TM_TYPE_VOICE) ];
        TypeFilteredMessagesViewController *vc = [[TypeFilteredMessagesViewController alloc] initWithChatType:self.chatType
                                                                                                     dataId:self.dataId
                                                                                                   msgTypes:types
                                                                                                  emptyText:@"暂无语音消息"];
        return vc;
    }
    if ([action isEqualToString:@"link"]) {
        TypeFilteredMessagesViewController *vc = [[TypeFilteredMessagesViewController alloc] initWithChatType:self.chatType
                                                                                                     dataId:self.dataId
                                                                                                  emptyText:@"暂无链接"
                                                                                                   linkOnly:YES];
        return vc;
    }
    return nil;
}

#pragma mark - 搜索联动

- (void)applyKeywordToCurrentChild
{
    UIViewController *vc = self.childVCs[@(self.currentTabIndex)];
    if (!vc) return;
    if ([vc isKindOfClass:[TypeFilteredMessagesViewController class]]) {
        TypeFilteredMessagesViewController *tfvc = (TypeFilteredMessagesViewController *)vc;
        [tfvc updateSearchKeyword:self.currentKeyword];
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    self.currentKeyword = searchText ?: @"";
    [self applyKeywordToCurrentChild];
    [self updateSearchStripCount];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    self.currentKeyword = searchBar.text ?: @"";
    [searchBar resignFirstResponder];
    [self applyKeywordToCurrentChild];
    [self updateSearchStripCount];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    self.currentKeyword = @"";
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [self applyKeywordToCurrentChild];

    [self hideSearchBarAnimated:YES];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:(self.currentKeyword.length > 0) animated:YES];
}

#pragma mark - 顶部按钮事件 & 搜索栏显隐

- (void)onNavSearchTapped
{
    if (!self.searchBarVisible) {
        [self showSearchBarAnimated:YES];
    } else {
        [self.searchBar becomeFirstResponder];
    }
}

- (void)onNavMoreTapped
{
    __weak typeof(self) wself = self;
    [ChatMessageModeMenu showFromViewController:self
                                    anchorView:self.navActionContainer
                                 onSelectIndex:^(NSInteger index) {
        if (index == 0) {
            // 以聊天模式查看 = 收藏夹页面 → 当前即收藏夹页，无需跳转
            return;
        }
        // 以消息模式查看 = 与10001的对话 → 跳到聊天页
        [ViewControllerFactory goChatViewController:wself.dataId
                                        andNickname:wself.partnerName
                                             toNav:wself.navigationController
                                     popToRootFirst:NO
                                           highlight:nil];
    }];
}

- (void)showSearchBarAnimated:(BOOL)animated
{
    if (self.searchBarVisible) return;
    self.searchBarVisible = YES;
    self.searchContainer.hidden = NO;
    self.searchContainerHeightConstraint.constant = 28.f;  // 仅搜索框
    self.searchContainerTopConstraint.constant = 0;
    [self.view bringSubviewToFront:self.searchContainer];

    // 列表顶部改为贴紧安全区，让内容可以“穿过”搜索框
    self.containerViewTopToTabConstraint.active = NO;
    self.containerViewTopToSafeAreaConstraint.active = YES;

    self.tabWrapperTopConstraint.constant = 0;
    self.tabWrapperHeightConstraint.constant = 0;
    self.tabSeparatorTopConstraint.constant = 0;
    self.tabSeparatorHeightConstraint.constant = 0;
    self.tabWrapper.hidden = YES;
    self.tabSeparator.hidden = YES;

    void (^animations)(void) = ^{
        [self.view layoutIfNeeded];
    };
    if (animated) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        [UIView animateWithDuration:0.32 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:animations completion:nil];
    } else {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
        animations();
    }
    [self.searchBar becomeFirstResponder];
    [self updateSearchStripCount];  // 键盘弹出后 accessory 会显示在键盘上方
}

- (void)updateSearchStripCount
{
    NSInteger count = 0;
    UIViewController *vc = self.childVCs[@(self.currentTabIndex)];
    if ([vc isKindOfClass:[TypeFilteredMessagesViewController class]]) {
        TypeFilteredMessagesViewController *tfvc = (TypeFilteredMessagesViewController *)vc;
        count = [tfvc currentDisplayedCount];
        if (count > 0) {
            self.searchResultCountLabel.text = [NSString stringWithFormat:@"共 %ld 条消息", (long)count];
            return;
        }
    }
    if (self.currentTabIndex == 0 && self.dataId.length > 0 &&
        (self.chatType == CHAT_TYPE_FREIDN_CHAT || self.chatType == CHAT_TYPE_GUEST_CHAT)) {
        id msgProvider = [[IMClientManager sharedInstance] getMessagesProvider];
        if (msgProvider && [msgProvider respondsToSelector:@selector(getMessages:)]) {
            id list = [msgProvider getMessages:self.dataId];
            if (list && [list respondsToSelector:@selector(getDataList)]) {
                count = (NSInteger)[[list getDataList] count];
            }
        }
    }
    self.searchResultCountLabel.text = [NSString stringWithFormat:@"共 %ld 条消息", (long)count];
}

- (void)onSearchResultMessageMode:(UIButton *)sender
{
    [self hideSearchBarAnimated:YES];
    [ViewControllerFactory goChatViewController:self.dataId
                                    andNickname:self.partnerName
                                         toNav:self.navigationController
                             popToRootFirst:NO
                                   highlight:nil];
}

- (void)hideSearchBarAnimated:(BOOL)animated
{
    if (!self.searchBarVisible) return;
    self.searchBarVisible = NO;
    self.searchContainerHeightConstraint.constant = 0;
    self.searchContainerTopConstraint.constant = 4;

    self.tabWrapperTopConstraint.constant = 8;
    self.tabWrapperHeightConstraint.constant = 44;
    self.tabSeparatorTopConstraint.constant = 8;
    self.tabSeparatorHeightConstraint.constant = 0.5;
    self.tabWrapper.hidden = NO;
    self.tabSeparator.hidden = NO;

    // 列表顶部恢复到 Tab 下方
    self.containerViewTopToSafeAreaConstraint.active = NO;
    self.containerViewTopToTabConstraint.active = YES;

    [self.navigationController setNavigationBarHidden:NO animated:animated];

    void (^animations)(void) = ^{
        [self.view layoutIfNeeded];
    };
    void (^completion)(BOOL) = ^(BOOL finished) {
        self.searchContainer.hidden = YES;
    };

    if (animated) {
        [UIView animateWithDuration:0.32 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:animations completion:completion];
    } else {
        animations();
        completion(YES);
    }
}

@end
