//telegram @wz662
#import "AlarmsViewController.h"
#import "Default.h"
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
#import <UIKit/UIGlassEffect.h>
#endif
#import "ChatBaseEventImpl.h"
#import "NSMutableArrayObservableEx.h"
#import "IMClientManager.h"
#import "AlarmsProvider.h"
#import "AlarmDto.h"
#import "AlarmsTableViewCell.h"
#import "AlarmType.h"
#import "BasicTool.h"
#import "SDImageCache.h"
#import "SDWebImageManager.h"
#import "AvatarHelper.h"
#import "ViewControllerFactory.h"
#import "AppDelegate.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "QueryOfflineBeAddFriendsReqAsync.h"
#import "NotificationCenterFactory.h"
#import "BBSAlarmUIWrapper.h"
#import "UserDefaultsToolKits.h"
#import "UIBarButtonItem+XYMenu.h"
#import "QueryFriendInfoAsync.h"
#import "EmojiUtil.h"
#import "QQLBXScanViewController.h"
#import "StyleDIY.h"
#import "QRCodeScheme.h"
#import "SearchViewController.h"
#import "FriendsContent.h"
#import "GroupsContent.h"
#import "MsgDetailContent.h"
#import "MsgSummaryContent.h"
#import "MsgBodyRoot.h"
#import "HttpRestHelper.h"
#import "ClientCoreSDK.h"
#import "QueryOfflineChatMsgAsync.h"
#import "MessagesProvider.h"
#import "GroupsMessagesProvider.h"
#import "MainTabsViewController.h"
#import "GroupNotificationsViewController.h"
#import "TimeTool.h"

@interface AlarmsViewController () <UITableViewDataSourcePrefetching>

/** "消息"列表数据模型变动观察者实现block */
@property (nonatomic, copy) ObserverCompletion alarmsDatasObserver;
/** 与IM服务器的网络连接状态观察者 */
@property (nonatomic, copy) ObserverCompletion networkStatusObserver;

// 【暂时禁用】世界频道功能
///** 封装类：世界频道的UI封装类实现对象（封装后可提高本类的代码可读性） */
//@property (nonatomic, retain) BBSAlarmUIWrapper *bbsAlarmUIWrapper;

/** 过滤后的消息列表（排除世界频道） */
@property (nonatomic, strong) NSMutableArray<AlarmDto *> *filteredAlarms;
/** 会话标题兜底补资料时，避免同一 uid 在列表滚动中重复并发查询。 */
@property (nonatomic, strong) NSMutableSet<NSString *> *rb_alarmTitleProfileFetchInFlightUids;
/** 本次页面生命周期内已经尝试过补资料的 uid，避免失败后每次 reload 都再次请求。 */
@property (nonatomic, strong) NSMutableSet<NSString *> *rb_alarmTitleProfileFetchAttemptedUids;

// ========== 🆕 定时刷新（多端同步兜底） ==========
/// GCD 定时器：每 3 秒刷新一次会话列表 UI（配合 SyncManager 定时同步，确保多端消息/已读状态及时反映）
@property (nonatomic, strong) dispatch_source_t refreshTimer;
/// 定时刷新是否正在运行
@property (nonatomic, assign) BOOL refreshTimerRunning;

// ========== 🆕 UI 刷新节流（防止批量消息导致 UI 卡死） ==========
/// 节流标记：YES 表示已有一个延迟刷新在排队，0.5 秒内重复调用会被合并
@property (nonatomic, assign) BOOL refreshTableScheduled;
/// debounce 定时器：每次 scheduleRefreshTable 时取消并重新排 0.5 秒后执行，实现「最后一次调用后 0.5 秒执行一次」
@property (nonatomic, strong) dispatch_source_t refreshTableDebounceSource;
/// 脏标记：数据源有变化，定时器仅在 dirty 时才执行 reloadData
@property (nonatomic, assign) BOOL tableDirty;
/// 左滑菜单是否正在显示（显示时禁止 reloadData，避免自动收起菜单）
@property (nonatomic, assign) BOOL swipeMenuVisible;

// ========== 自定义导航栏（与官方账号聊天页同风格：磨砂+渐变、毛玻璃圆钮，随页面平移） ==========
@property (nonatomic, strong) UIView *rb_customNavBar;
@property (nonatomic, strong) NSLayoutConstraint *rb_customNavBarHeightConstraint;
@property (nonatomic, strong) UIVisualEffectView *rb_customNavBarBackdropView;
/// 导航磨砂条渐变 mask，仅创建一次，layout 时只更新 frame，避免每次 layout 新建 CAGradientLayer
@property (nonatomic, strong) CAGradientLayer *rb_navBackdropMaskLayer;
@property (nonatomic, strong) UILabel *rb_customNavTitleLabel;
/// 与 Tab 一致：左侧「消息」/「群聊」纯文字（无一键已读）
@property (nonatomic, strong) UILabel *rb_customNavLeftTitleLabel;
/// 左侧标题 leading = safeArea.leading + constant（constant 与系统 UINavigationBar 栏按钮区内边距同步）
@property (nonatomic, strong) NSLayoutConstraint *rb_customNavLeftTitleLeadingConstraint;
/// 右侧胶囊 trailing = safeArea.trailing + constant（通常为负）
@property (nonatomic, strong) NSLayoutConstraint *rb_customNavRightPillTrailingConstraint;
/// 归档页右上角“全选/完成”按钮
@property (nonatomic, strong) UIButton *rb_archivedSelectAllButton;
/// 归档页底部批量操作栏
@property (nonatomic, strong) UIView *rb_archivedBatchActionBar;
@property (nonatomic, strong) NSLayoutConstraint *rb_archivedBatchActionBarHeightConstraint;
@property (nonatomic, strong) UIButton *rb_archivedBatchToggleSelectButton;
@property (nonatomic, strong) UIButton *rb_archivedBatchReadButton;
@property (nonatomic, strong) UIButton *rb_archivedBatchUnarchiveButton;
@property (nonatomic, strong) UIButton *rb_archivedBatchDeleteButton;
/// 归档页批量选择态
@property (nonatomic, assign) BOOL rb_archivedBatchEditing;
/// 表格原始 bottom inset，显示底部操作栏时在此基础上叠加
@property (nonatomic, assign) CGFloat rb_archivedBaseTableBottomInset;

/// 会话列表为空时「发起对话」：消息 Tab 去通讯录，群聊 Tab 去通讯录并打开「我的群组」
@property (nonatomic, strong) UIButton *rb_emptyStartConversationButton;
@property (nonatomic, copy) NSString *rb_groupNotifyEntryPreviewTextDynamic;
@property (nonatomic, copy) NSString *rb_groupNotifyEntryPreviewDateText;
@property (nonatomic, strong) NSDate *rb_groupNotifyEntryLatestDate;
@property (nonatomic, assign) NSInteger rb_groupNotifyUnreadCount;
@property (nonatomic, assign) BOOL rb_groupNotifyHasServerData;

@end

// 与官方账号一致：导航内容区高度 26、圆钮直径 44
static const CGFloat kAlarmsNavBarContentHeight = 26.0f;
static const CGFloat kAlarmsNavBarButtonSize = 44.0f;
static const CGFloat kAlarmsNavBarContentMargin = 12.0f;
/// 系统导航栏隐藏时读不到 margin 时的兜底（介于 8～16 之间，接近通讯录 UIBarButtonItem 可视起点）
static const CGFloat kMainTabNavSideInsetFallback = 12.0f;
static const CGFloat kAlarmsNavBarContentBottomOffset = 36.0f;  // 内容区相对 bar 底上移，导航标题行更靠上

// 与 AlarmsTableViewCell.xib 设计一致；用 BasicTool 以匹配「显示大小」缩放，cell 末尾统一设置，避免仅刷新导航区外控件时列表内标题字重来回跳
static const CGFloat kAlarmsCellTitleFontBase = 16.0f;
static const CGFloat kAlarmsCellDateFontBase = 11.0f;
static const CGFloat kAlarmsCellMsgFontBase = 12.0f;
static const CGFloat kAlarmsCellFlagFontBase = 11.0f;
/// 首轮同步累计消息条数超过此值才显示骨架屏（少量同步仅显示顶部「正在同步」提示）
static const CGFloat kAlarmsSyncBannerHeight = 38.0f;
static const CGFloat kArchivedBatchActionBarHeight = 72.0f;
static NSString *const kRbGroupNotifyEntryPreviewText = @"入群审核、群设置变更、转让群主、禁言提醒";
static NSString *const kRbGroupNotifyVirtualDataId = @"__rb_group_notify__";
static NSString *const kRbArchivedEntryVirtualDataId = @"__rb_archived_entry__";
static NSString *const kRbGroupNotifyAlwaysTopDefaultsKey = @"kRbGroupNotifyAlwaysTop";
static NSInteger const kRbGroupNotifyUnreadFetchPageSize = 50;
static NSInteger const kRbGroupNotifyUnreadFetchMaxPages = 10;

@implementation AlarmsViewController

- (NSMutableSet<NSString *> *)rb_alarmTitleProfileFetchInFlightUids
{
    if (_rb_alarmTitleProfileFetchInFlightUids == nil) {
        _rb_alarmTitleProfileFetchInFlightUids = [NSMutableSet set];
    }
    return _rb_alarmTitleProfileFetchInFlightUids;
}

- (NSMutableSet<NSString *> *)rb_alarmTitleProfileFetchAttemptedUids
{
    if (_rb_alarmTitleProfileFetchAttemptedUids == nil) {
        _rb_alarmTitleProfileFetchAttemptedUids = [NSMutableSet set];
    }
    return _rb_alarmTitleProfileFetchAttemptedUids;
}

- (BOOL)rb_shouldFetchProfileForAlarmTitle:(AlarmDto *)alarm displayedTitle:(NSString *)displayedTitle
{
    if (alarm == nil) return NO;
    if (!(alarm.alarmType == AMT_friendChatMessage || alarm.alarmType == AMT_guestChatMessage)) return NO;
    NSString *uid = [BasicTool trim:alarm.dataId];
    if (uid.length == 0) return NO;
    NSString *title = [BasicTool trim:displayedTitle];
    return (title.length == 0 || [title isEqualToString:uid]);
}

- (void)rb_fetchProfileAndUpdateAlarmTitleIfNeeded:(AlarmDto *)alarm displayedTitle:(NSString *)displayedTitle
{
    if (![self rb_shouldFetchProfileForAlarmTitle:alarm displayedTitle:displayedTitle]) {
        return;
    }

    NSString *uid = [BasicTool trim:alarm.dataId];
    @synchronized (self) {
        if ([self.rb_alarmTitleProfileFetchInFlightUids containsObject:uid]
            || [self.rb_alarmTitleProfileFetchAttemptedUids containsObject:uid]) {
            return;
        }
        [self.rb_alarmTitleProfileFetchInFlightUids addObject:uid];
        [self.rb_alarmTitleProfileFetchAttemptedUids addObject:uid];
    }

    __weak typeof(self) wself = self;
    [QueryFriendInfoAsync doIt:uid hudParentView:nil complete:^(BOOL sucess, UserEntity *userInfo) {
        __strong typeof(wself) sself = wself;
        if (!sself) return;

        @synchronized (sself) {
            [sself.rb_alarmTitleProfileFetchInFlightUids removeObject:uid];
        }

        NSString *nickname = [BasicTool trim:userInfo.nickname];
        if (!(sucess && userInfo != nil && nickname.length > 0)) {
            return;
        }

        AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
        if (ap == nil) return;
        NSString *newExtra1 = (alarm.alarmType == AMT_guestChatMessage ? userInfo.userAvatarFileName : nil);
        [ap updateAlarmTitleAndExtra1:alarm.alarmType
                               dataId:uid
                             newTitle:nickname
                            newExtra1:newExtra1
                      needUpdateSqlite:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!sself.tableView.window) return;
            [sself scheduleRefreshTable];
        });
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 初始化界面
    [self initGUI];
    [self rb_setupAlarmsCustomNavBar];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    // 初始化其它UI界面
    [self initOtherUI];
    [self rb_installEmptyStateStartConversationButton];
    [self rb_setupArchivedBatchActionBarIfNeeded];
    // 初始化观察者
    [self initObservers];
    // 初始化数据
    [self initDatas];

    // 注册通知：重置群组头像缓存
    [NotificationCenterFactory resetGroupAvatarCache_ADD:self selector:@selector(clearGroupAvatarCache:)];
    
    // 设置网络状态观察者（通过通知机制让所有AlarmsViewController实例都能收到网络状态变化）
    ChatBaseEventImpl * cb = (ChatBaseEventImpl *)[[IMClientManager sharedInstance] getBaseEventListener];
    cb.networkStatusObserver = self.networkStatusObserver;
    // 注册网络状态变化通知（支持多实例同时收到更新）
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshNetworkStatusShow) name:@"kAlarmsNetworkStatusChanged" object:nil];
    
    // 设置"消息"列表数据模型变动观察者
    [[[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmsData] addObserver:self.alarmsDatasObserver];
    
    // 注册通知：强制刷新"消息"tab上的总未读数（进入聊天界面时重置对象里的未读数这样的行为，是没有办法通过rosterUnreadNumObserver获得通知的，所
    // 以此时在进入聊天界面中重置该好友的未读数时，会手动发出此通知，使得标题上的未读数能及时刷新为最新，不然标题上的未读数就不同步了）
    [NotificationCenterFactory refreshMainPageTotalUnread_ADD:self selector:@selector(refreshUnreadNumOnTitle)];
    // 注册通知：修改完成好友的备注后
    [NotificationCenterFactory friendRemarkChanged_ADD:self selector:@selector(friendRemarkChangedComplete:)];
    // 未读清零由 AlarmsProvider resetFlagNum → notifyObservers 驱动；仅当前可见 Tab 在 alarmsDatasObserver 里 scheduleRefreshTable，另一 Tab 在 viewWillAppear 已 refreshTable。
    
    [NotificationCenterFactory groupNotificationsRealtime_ADD:self selector:@selector(rb_onGroupNotificationsRealtimePush:)];
    [self rb_fetchLatestGroupNotifyPreviewIfNeeded];
}

// @Override
- (void)initGUI
{
    [super initGUI];
   
//  UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"alarms_add_friends2"]
//                                                                  style:UIBarButtonItemStylePlain
//                                                                 target:self
//                                                                 action:@selector(doMores:)];
//    UIBarButtonItem *searchButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"alarms_search"]
//                                                                  style:UIBarButtonItemStylePlain
//                                                                 target:self
//                                                                 action:@selector(doSearch:)];
//    // 标题栏右边的“+”按钮、搜索按钮
//    self.navigationItem.rightBarButtonItems = @[addButton, searchButton];

    /* 会话列表隐藏系统导航栏，左侧标题在 rb_setupAlarmsCustomNavBar 中绘制，此处不再放置一键已读 */

    // 表格基本设置
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    // 必须注册 nib，否则 dequeue 长期不稳定；置顶图标等 outlet 依赖正确的 AlarmsTableViewCell 实例化路径
    UINib *alarmsCellNib = [UINib nibWithNibName:@"AlarmsTableViewCell" bundle:nil];
    [self.tableView registerNib:alarmsCellNib forCellReuseIdentifier:@"CellMain"];
    if (@available(iOS 10.0, *)) {
        self.tableView.prefetchDataSource = self;
    }
    // 设置搜索框 Header（消息/群聊列表在自定义导航下需多留顶部间距，搜索框往下一点）
    self.tableView.tableHeaderView = [self createSearchBarHeader];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    // 分隔线由 AlarmsTableViewCell 内 hairline（1 物理像素）绘制，比系统线更细；左起 76 与昵称列对齐
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    // 表格背景色
    self.tableView.backgroundColor = UI_DEFAULT_BG;
    self.rb_archivedBaseTableBottomInset = self.tableView.contentInset.bottom;
}

// 消息/群聊列表：搜索框整体下移一点，避免贴紧自定义导航
- (UIView *)createSearchBarHeader
{
    UIView *originalHeader = [super createSearchBarHeader];
    if (!originalHeader) return nil;
    static const CGFloat kSearchHeaderTopPadding = 12.0f;
    CGFloat w = [UIScreen mainScreen].bounds.size.width;
    CGFloat origH = originalHeader.frame.size.height;
    CGFloat wrapH = kSearchHeaderTopPadding + origH;
    UIView *wrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, wrapH)];
    wrapper.backgroundColor = [UIColor clearColor];
    originalHeader.frame = CGRectMake(0, kSearchHeaderTopPadding, w, origH);
    [wrapper addSubview:originalHeader];
    return wrapper;
}

/// 消息/群聊列表自定义顶栏：左为「消息」/「群聊」文字，右为“编辑”胶囊
- (void)rb_setupAlarmsCustomNavBar
{
    if (self.rb_customNavBar) return;
    UIView *view = self.view;
    UIView *bar = [[UIView alloc] init];
    bar.backgroundColor = [UIColor clearColor];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:bar];
    self.rb_customNavBar = bar;

    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *backdrop = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
        backdrop.translatesAutoresizingMaskIntoConstraints = NO;
        backdrop.userInteractionEnabled = NO;
        [bar insertSubview:backdrop atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [backdrop.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
            [backdrop.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
            [backdrop.topAnchor constraintEqualToAnchor:bar.topAnchor],
            [backdrop.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
        ]];
        self.rb_customNavBarBackdropView = backdrop;
    } else {
        bar.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.65f];
    }

    NSLayoutConstraint *heightConstraint = [bar.heightAnchor constraintEqualToConstant:kAlarmsNavBarContentHeight];
    [heightConstraint setActive:YES];
    self.rb_customNavBarHeightConstraint = heightConstraint;
    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:view.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
    ]];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.backgroundColor = [UIColor clearColor];
    [bar addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-kAlarmsNavBarContentBottomOffset],
        [content.heightAnchor constraintEqualToConstant:kAlarmsNavBarContentHeight],
    ]];

    NSString *leftTabKey = @"main_tabs_title_alarm";
    if (self.alarmFilterMode == ALARM_FILTER_GROUP) {
        leftTabKey = @"main_tabs_title_group";
    }
    UILabel *leftNavTitle = [[UILabel alloc] init];
    leftNavTitle.translatesAutoresizingMaskIntoConstraints = NO;
    leftNavTitle.text = self.showArchivedOnly ? @"已归档" : NSLocalizedString(leftTabKey, @"");
    CGFloat leftTitlePt = [BasicTool getAdjustedFontSize:22.f];
    leftNavTitle.font = [UIFont systemFontOfSize:leftTitlePt weight:UIFontWeightSemibold];
    if (@available(iOS 13.0, *)) {
        leftNavTitle.textColor = [UIColor labelColor];
    } else {
        leftNavTitle.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
    }
    leftNavTitle.backgroundColor = [UIColor clearColor];
    leftNavTitle.userInteractionEnabled = NO;
    [content addSubview:leftNavTitle];
    self.rb_customNavLeftTitleLabel = leftNavTitle;
    UIView *leftAnchorView = nil;
    if (self.showArchivedOnly) {
        UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        backBtn.translatesAutoresizingMaskIntoConstraints = NO;
        backBtn.tintColor = UI_DEFAULT_TITLE_FONT_COLOR;
        [backBtn setTitle:@"" forState:UIControlStateNormal];
        backBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        if (@available(iOS 13.0, *)) {
            UIImage *icon = [UIImage systemImageNamed:@"chevron.left"];
            [backBtn setImage:icon forState:UIControlStateNormal];
            backBtn.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        }
        [backBtn addTarget:self action:@selector(rb_onNavBackTapped:) forControlEvents:UIControlEventTouchUpInside];
        [content addSubview:backBtn];
        leftAnchorView = backBtn;
        if (@available(iOS 15.0, *)) {
            [NSLayoutConstraint activateConstraints:@[
                [backBtn.leadingAnchor constraintEqualToAnchor:view.readableContentGuide.leadingAnchor],
                [backBtn.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
                [backBtn.widthAnchor constraintEqualToConstant:24.0f],
                [backBtn.heightAnchor constraintEqualToConstant:32.0f],
            ]];
        } else if (@available(iOS 11.0, *)) {
            [NSLayoutConstraint activateConstraints:@[
                [backBtn.leadingAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.leadingAnchor constant:kMainTabNavSideInsetFallback],
                [backBtn.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
                [backBtn.widthAnchor constraintEqualToConstant:24.0f],
                [backBtn.heightAnchor constraintEqualToConstant:32.0f],
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [backBtn.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:kMainTabNavSideInsetFallback],
                [backBtn.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
                [backBtn.widthAnchor constraintEqualToConstant:24.0f],
                [backBtn.heightAnchor constraintEqualToConstant:32.0f],
            ]];
        }
    }
    /* 水平位置：iOS15+ 用 readableContentGuide 与系统导航栏内容区/通讯录左侧标题对齐；低版本用 safeArea + 与 UINavigationBar.layoutMargins 同步的 constant */
    CGFloat archivedTitleSpacing = self.showArchivedOnly ? 4.0f : 8.0f;
    if (@available(iOS 15.0, *)) {
        self.rb_customNavLeftTitleLeadingConstraint = leftAnchorView != nil
            ? [leftNavTitle.leadingAnchor constraintEqualToAnchor:leftAnchorView.trailingAnchor constant:archivedTitleSpacing]
            : [leftNavTitle.leadingAnchor constraintEqualToAnchor:view.readableContentGuide.leadingAnchor];
        [NSLayoutConstraint activateConstraints:@[
            self.rb_customNavLeftTitleLeadingConstraint,
            [leftNavTitle.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        ]];
    } else if (@available(iOS 11.0, *)) {
        self.rb_customNavLeftTitleLeadingConstraint = leftAnchorView != nil
            ? [leftNavTitle.leadingAnchor constraintEqualToAnchor:leftAnchorView.trailingAnchor constant:archivedTitleSpacing]
            : [leftNavTitle.leadingAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.leadingAnchor constant:kMainTabNavSideInsetFallback];
        [NSLayoutConstraint activateConstraints:@[
            self.rb_customNavLeftTitleLeadingConstraint,
            [leftNavTitle.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        ]];
    } else {
        self.rb_customNavLeftTitleLeadingConstraint = leftAnchorView != nil
            ? [leftNavTitle.leadingAnchor constraintEqualToAnchor:leftAnchorView.trailingAnchor constant:archivedTitleSpacing]
            : [leftNavTitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:kMainTabNavSideInsetFallback];
        [NSLayoutConstraint activateConstraints:@[
            self.rb_customNavLeftTitleLeadingConstraint,
            [leftNavTitle.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        ]];
    }

    // 右侧：胶囊（毛玻璃底）。消息页与归档页都显示单按钮“编辑”。
    static const CGFloat kPillHeight = 44.0f;
    static const CGFloat kPillCornerRadius = 22.0f;  // 高度一半 = 胶囊形
    static const CGFloat kPillBtnSize = 32.0f;
    static const CGFloat kEditPillWidth = 74.0f;
    UIView *rightPill = [[UIView alloc] init];
    rightPill.backgroundColor = [UIColor clearColor];
    rightPill.layer.cornerRadius = kPillCornerRadius;
    rightPill.clipsToBounds = YES;
    rightPill.translatesAutoresizingMaskIntoConstraints = NO;
    [rightPill setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [content addSubview:rightPill];
    UIButton *archiveSelectAllBtn = nil;
    archiveSelectAllBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    archiveSelectAllBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [archiveSelectAllBtn setTitle:@"编辑" forState:UIControlStateNormal];
    archiveSelectAllBtn.titleLabel.font = [UIFont systemFontOfSize:15.0f weight:UIFontWeightSemibold];
    [archiveSelectAllBtn setTitleColor:UI_DEFAULT_TITLE_FONT_COLOR forState:UIControlStateNormal];
    archiveSelectAllBtn.backgroundColor = [UIColor clearColor];
    [archiveSelectAllBtn addTarget:self action:@selector(rb_onArchivedSelectAllTapped:) forControlEvents:UIControlEventTouchUpInside];
    [rightPill addSubview:archiveSelectAllBtn];
    self.rb_archivedSelectAllButton = archiveSelectAllBtn;
    NSLayoutConstraint *pillWidthConstraint = [rightPill.widthAnchor constraintEqualToConstant:kEditPillWidth];
    pillWidthConstraint.priority = UILayoutPriorityRequired;
    if (@available(iOS 15.0, *)) {
        self.rb_customNavRightPillTrailingConstraint =
            [rightPill.trailingAnchor constraintEqualToAnchor:view.readableContentGuide.trailingAnchor];
    } else if (@available(iOS 11.0, *)) {
        self.rb_customNavRightPillTrailingConstraint =
            [rightPill.trailingAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.trailingAnchor constant:-kMainTabNavSideInsetFallback];
    } else {
        self.rb_customNavRightPillTrailingConstraint =
            [rightPill.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-kMainTabNavSideInsetFallback];
    }
    [NSLayoutConstraint activateConstraints:@[
        self.rb_customNavRightPillTrailingConstraint,
        [rightPill.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        pillWidthConstraint,
        [rightPill.heightAnchor constraintEqualToConstant:kPillHeight],
    ]];
    [NSLayoutConstraint activateConstraints:@[
        [archiveSelectAllBtn.leadingAnchor constraintEqualToAnchor:rightPill.leadingAnchor constant:12.0f],
        [archiveSelectAllBtn.trailingAnchor constraintEqualToAnchor:rightPill.trailingAnchor constant:-12.0f],
        [archiveSelectAllBtn.centerYAnchor constraintEqualToAnchor:rightPill.centerYAnchor],
        [archiveSelectAllBtn.heightAnchor constraintEqualToConstant:kPillBtnSize],
    ]];
    // 毛玻璃背景放在最底层，不遮挡编辑按钮
    UIVisualEffectView *pillBackdrop = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *effect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        pillBackdrop = [[UIVisualEffectView alloc] initWithEffect:effect];
    } else
#endif
    if (@available(iOS 13.0, *)) {
        pillBackdrop = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
    }
    if (pillBackdrop) {
        pillBackdrop.layer.cornerRadius = kPillCornerRadius;
        pillBackdrop.clipsToBounds = YES;
        pillBackdrop.userInteractionEnabled = NO;
        // 约束挂在普通 UIView 上，毛玻璃子视图用 autoresizing 贴合，避免 UIVisualEffectView 被系统施加 width≥44 与瞬时 width==0 冲突
        UIView *pillBlurHost = [[UIView alloc] init];
        pillBlurHost.translatesAutoresizingMaskIntoConstraints = NO;
        pillBlurHost.backgroundColor = [UIColor clearColor];
        pillBlurHost.userInteractionEnabled = NO;
        [rightPill insertSubview:pillBlurHost atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [pillBlurHost.leadingAnchor constraintEqualToAnchor:rightPill.leadingAnchor],
            [pillBlurHost.trailingAnchor constraintEqualToAnchor:rightPill.trailingAnchor],
            [pillBlurHost.topAnchor constraintEqualToAnchor:rightPill.topAnchor],
            [pillBlurHost.bottomAnchor constraintEqualToAnchor:rightPill.bottomAnchor],
        ]];
        pillBackdrop.translatesAutoresizingMaskIntoConstraints = YES;
        pillBackdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        pillBackdrop.frame = pillBlurHost.bounds;
        [pillBlurHost addSubview:pillBackdrop];
    } else {
        rightPill.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.9f];
    }

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"";
    titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    titleLabel.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:titleLabel];
    self.rb_customNavTitleLabel = titleLabel;
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [titleLabel.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:leftNavTitle.trailingAnchor constant:10.0f],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:rightPill.leadingAnchor constant:-10.0f],
    ]];

    [view bringSubviewToFront:bar];

    [self refreshUnreadNumOnTitle];
    [self rb_updateArchivedBatchActionUI];
}

- (void)rb_onNavBackTapped:(id)sender
{
    if (self.rb_archivedBatchEditing) {
        [self rb_setArchivedBatchEditing:NO selectAll:NO];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)rb_onArchivedSelectAllTapped:(id)sender
{
    if (self.rb_archivedBatchEditing) {
        [self rb_setArchivedBatchEditing:NO selectAll:NO];
        return;
    }
    [self rb_setArchivedBatchEditing:YES selectAll:NO];
}

- (void)rb_onArchivedBatchToggleSelectTapped:(id)sender
{
    (void)sender;
    NSArray<NSIndexPath *> *allIndexPaths = [self rb_allSelectableArchivedIndexPaths];
    if (allIndexPaths.count == 0) {
        return;
    }
    NSInteger selectedCount = [self rb_selectedArchivedAlarms].count;
    BOOL shouldSelectAll = (selectedCount != allIndexPaths.count);
    if (shouldSelectAll) {
        for (NSIndexPath *indexPath in allIndexPaths) {
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
    } else {
        for (NSIndexPath *indexPath in allIndexPaths) {
            [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
        }
    }
    [self rb_updateArchivedBatchActionUI];
}

- (void)rb_setupArchivedBatchActionBarIfNeeded
{
    if (self.rb_archivedBatchActionBar != nil) {
        return;
    }
    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.96f];
    bar.hidden = YES;
    if (@available(iOS 13.0, *)) {
        bar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    }
    [self.view addSubview:bar];
    self.rb_archivedBatchActionBar = bar;

    UIView *topLine = [[UIView alloc] init];
    topLine.translatesAutoresizingMaskIntoConstraints = NO;
    topLine.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.08f];
    [bar addSubview:topLine];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 10.0f;
    [bar addSubview:stack];

    UIButton *(^makeActionButton)(NSString *, SEL, UIColor *) = ^UIButton *(NSString *title, SEL action, UIColor *titleColor) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn setTitle:title forState:UIControlStateNormal];
        [btn setTitleColor:titleColor forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:15.0f weight:UIFontWeightSemibold];
        btn.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.04f];
        btn.layer.cornerRadius = 12.0f;
        btn.layer.masksToBounds = YES;
        [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
        return btn;
    };

    UIColor *normalColor = UI_DEFAULT_TITLE_FONT_COLOR;
    UIButton *toggleSelectBtn = makeActionButton(@"全选", @selector(rb_onArchivedBatchToggleSelectTapped:), normalColor);
    UIButton *readBtn = makeActionButton(@"标记已读", @selector(rb_onArchivedBatchReadTapped:), normalColor);
    NSString *archiveActionTitle = self.showArchivedOnly ? @"取消归档" : @"归档";
    UIButton *unarchiveBtn = makeActionButton(archiveActionTitle, @selector(rb_onArchivedBatchUnarchiveTapped:), normalColor);
    UIButton *deleteBtn = makeActionButton(@"删除", @selector(rb_onArchivedBatchDeleteTapped:), [UIColor colorWithRed:0.89f green:0.23f blue:0.19f alpha:1.0f]);
    self.rb_archivedBatchToggleSelectButton = toggleSelectBtn;
    self.rb_archivedBatchReadButton = readBtn;
    self.rb_archivedBatchUnarchiveButton = unarchiveBtn;
    self.rb_archivedBatchDeleteButton = deleteBtn;
    [stack addArrangedSubview:toggleSelectBtn];
    [stack addArrangedSubview:readBtn];
    [stack addArrangedSubview:unarchiveBtn];
    [stack addArrangedSubview:deleteBtn];

    NSLayoutConstraint *barHeightConstraint = [bar.heightAnchor constraintEqualToConstant:kArchivedBatchActionBarHeight];
    self.rb_archivedBatchActionBarHeightConstraint = barHeightConstraint;
    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        barHeightConstraint,
        [topLine.topAnchor constraintEqualToAnchor:bar.topAnchor],
        [topLine.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [topLine.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        [topLine.heightAnchor constraintEqualToConstant:1.0f],
        [stack.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:16.0f],
        [stack.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-16.0f],
        [stack.topAnchor constraintEqualToAnchor:bar.topAnchor constant:10.0f],
        [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10.0f],
    ]];
}

- (NSArray<NSIndexPath *> *)rb_allSelectableArchivedIndexPaths
{
    NSMutableArray<NSIndexPath *> *result = [NSMutableArray array];
    for (NSInteger section = 0; section < self.filteredAlarms.count; section++) {
        AlarmDto *alarm = [self rb_alarmForSection:section];
        if (alarm == nil || [self rb_isArchivedEntryAlarm:alarm] || [self rb_isGroupNotifyAlarm:alarm]) {
            continue;
        }
        [result addObject:[NSIndexPath indexPathForRow:0 inSection:section]];
    }
    return result;
}

- (NSArray<AlarmDto *> *)rb_selectedArchivedAlarms
{
    NSMutableArray<AlarmDto *> *result = [NSMutableArray array];
    NSArray<NSIndexPath *> *selectedIndexPaths = [[self.tableView indexPathsForSelectedRows] sortedArrayUsingSelector:@selector(compare:)];
    for (NSIndexPath *indexPath in selectedIndexPaths) {
        AlarmDto *alarm = [self rb_alarmForSection:indexPath.section];
        if (alarm == nil || [self rb_isArchivedEntryAlarm:alarm] || [self rb_isGroupNotifyAlarm:alarm]) {
            continue;
        }
        [result addObject:alarm];
    }
    return result;
}

- (void)rb_updateArchivedBatchActionUI
{
    NSInteger totalCount = [self rb_allSelectableArchivedIndexPaths].count;
    NSInteger selectedCount = [self rb_selectedArchivedAlarms].count;
    BOOL hasRows = totalCount > 0;
    BOOL allSelected = (hasRows && selectedCount == totalCount);
    if (self.rb_archivedSelectAllButton) {
        NSString *title = self.rb_archivedBatchEditing ? @"完成" : @"编辑";
        [self.rb_archivedSelectAllButton setTitle:title forState:UIControlStateNormal];
        self.rb_archivedSelectAllButton.enabled = hasRows || self.rb_archivedBatchEditing;
        self.rb_archivedSelectAllButton.alpha = self.rb_archivedSelectAllButton.enabled ? 1.0f : 0.45f;
    }
    if (self.rb_archivedBatchToggleSelectButton) {
        NSString *toggleTitle = allSelected ? @"取消全选" : @"全选";
        [self.rb_archivedBatchToggleSelectButton setTitle:toggleTitle forState:UIControlStateNormal];
        self.rb_archivedBatchToggleSelectButton.enabled = hasRows;
        self.rb_archivedBatchToggleSelectButton.alpha = hasRows ? 1.0f : 0.45f;
    }
    if (self.rb_archivedBatchUnarchiveButton) {
        NSString *archiveActionTitle = self.showArchivedOnly ? @"取消归档" : @"归档";
        [self.rb_archivedBatchUnarchiveButton setTitle:archiveActionTitle forState:UIControlStateNormal];
    }
    NSArray<UIButton *> *actionButtons = @[
        self.rb_archivedBatchReadButton ?: [UIButton new],
        self.rb_archivedBatchUnarchiveButton ?: [UIButton new],
        self.rb_archivedBatchDeleteButton ?: [UIButton new]
    ];
    BOOL actionsEnabled = (selectedCount > 0);
    for (UIButton *btn in actionButtons) {
        if (![btn isKindOfClass:[UIButton class]]) continue;
        btn.enabled = actionsEnabled;
        btn.alpha = actionsEnabled ? 1.0f : 0.45f;
    }
}

- (void)rb_updateArchivedBatchActionBarVisibilityAnimated:(BOOL)animated
{
    if (self.rb_archivedBatchActionBar == nil) {
        return;
    }
    BOOL shouldShow = self.rb_archivedBatchEditing;
    CGFloat targetAlpha = shouldShow ? 1.0f : 0.0f;
    if (shouldShow) {
        self.rb_archivedBatchActionBar.hidden = NO;
        [self.view bringSubviewToFront:self.rb_archivedBatchActionBar];
    }
    UIEdgeInsets inset = self.tableView.contentInset;
    inset.bottom = self.rb_archivedBaseTableBottomInset + (shouldShow ? (kArchivedBatchActionBarHeight + 8.0f) : 0.0f);
    UIEdgeInsets indicatorInset = self.tableView.scrollIndicatorInsets;
    indicatorInset.bottom = inset.bottom;
    self.tableView.contentInset = inset;
    self.tableView.scrollIndicatorInsets = indicatorInset;

    void (^animations)(void) = ^{
        self.rb_archivedBatchActionBar.alpha = targetAlpha;
    };
    void (^completion)(BOOL) = ^(BOOL finished) {
        (void)finished;
        if (!shouldShow) {
            self.rb_archivedBatchActionBar.hidden = YES;
        }
    };
    if (animated) {
        [UIView animateWithDuration:0.2 animations:animations completion:completion];
    } else {
        animations();
        completion(YES);
    }
}

- (void)rb_setArchivedBatchEditing:(BOOL)editing selectAll:(BOOL)selectAll
{
    [self rb_setupArchivedBatchActionBarIfNeeded];
    self.rb_archivedBatchEditing = editing;
    self.swipeMenuVisible = NO;
    [self.tableView setEditing:editing animated:YES];
    if (!editing) {
        NSArray<NSIndexPath *> *selectedIndexPaths = [[self.tableView indexPathsForSelectedRows] copy];
        for (NSIndexPath *indexPath in selectedIndexPaths) {
            [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
        }
    }
    [self rb_updateArchivedBatchActionBarVisibilityAnimated:YES];
    if (editing && selectAll) {
        NSArray<NSIndexPath *> *allIndexPaths = [self rb_allSelectableArchivedIndexPaths];
        for (NSIndexPath *indexPath in allIndexPaths) {
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
    }
    [self rb_updateArchivedBatchActionUI];
    if (!editing && self.tableDirty) {
        [self refreshTable];
        [self refreshUnreadNumOnTitle];
    }
}

- (void)rb_onArchivedBatchReadTapped:(id)sender
{
    NSArray<AlarmDto *> *targets = [self rb_selectedArchivedAlarms];
    if (targets.count == 0) {
        return;
    }
    [self rb_setArchivedBatchEditing:NO selectAll:NO];
    AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
    for (AlarmDto *alarm in targets) {
        [ap resetFlagNum:alarm.alarmType dataId:alarm.dataId flagNumToReset:0 needUpdateSqlite:YES];
    }
    [self refreshTable];
    [self refreshUnreadNumOnTitle];
}

- (void)rb_onArchivedBatchUnarchiveTapped:(id)sender
{
    NSArray<AlarmDto *> *targets = [self rb_selectedArchivedAlarms];
    if (targets.count == 0) {
        return;
    }
    [self rb_setArchivedBatchEditing:NO selectAll:NO];
    AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
    BOOL targetArchived = self.showArchivedOnly ? NO : YES;
    for (AlarmDto *alarm in targets) {
        AlarmDto *latest = [ap getAlarmDto:alarm.alarmType dataId:alarm.dataId];
        if (latest != nil) {
            [ap setArchived:targetArchived amd:latest];
        }
    }
    [self refreshTable];
    [self refreshUnreadNumOnTitle];
}

- (void)rb_applyArchivedBatchDeleteForTargets:(NSArray<AlarmDto *> *)targets
{
    if (targets.count == 0) {
        return;
    }
    [self rb_setArchivedBatchEditing:NO selectAll:NO];
    AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
    for (AlarmDto *alarm in targets) {
        int index = [ap getAlarmIndex:alarm.alarmType dataId:alarm.dataId];
        if (index != -1) {
            [ap removeAlarm:index notify:YES deleteAlarmLocalData:YES deleteLocalData:YES];
        }
    }
    [self refreshTable];
    [self refreshUnreadNumOnTitle];
}

- (void)rb_onArchivedBatchDeleteTapped:(id)sender
{
    NSArray<AlarmDto *> *targets = [self rb_selectedArchivedAlarms];
    if (targets.count == 0) {
        return;
    }
    NSString *message = self.showArchivedOnly
        ? [NSString stringWithFormat:@"确认删除已选中的 %ld 个归档会话吗？", (long)targets.count]
        : [NSString stringWithFormat:@"确认删除已选中的 %ld 个会话吗？", (long)targets.count];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除会话"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) wself = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        [sself rb_applyArchivedBatchDeleteForTargets:targets];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

static UILabel *rb_alarmsFindFirstLabelInSubviewTree(UIView *root)
{
    if (root == nil) return nil;
    if ([root isKindOfClass:[UILabel class]]) return (UILabel *)root;
    for (UIView *sub in root.subviews) {
        UILabel *f = rb_alarmsFindFirstLabelInSubviewTree(sub);
        if (f != nil) return f;
    }
    return nil;
}

- (void)rb_installEmptyStateStartConversationButton
{
    if (self.rb_emptyStartConversationButton != nil || self.layoutTableEmptyHint == nil) return;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"发起对话" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:@selector(rb_onEmptyStartConversationTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.layoutTableEmptyHint addSubview:btn];
    self.rb_emptyStartConversationButton = btn;

    UILabel *hintLabel = rb_alarmsFindFirstLabelInSubviewTree(self.layoutTableEmptyHint);
    if (hintLabel != nil) {
        [NSLayoutConstraint activateConstraints:@[
            [btn.topAnchor constraintEqualToAnchor:hintLabel.bottomAnchor constant:14],
            [btn.centerXAnchor constraintEqualToAnchor:self.layoutTableEmptyHint.centerXAnchor],
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [btn.centerXAnchor constraintEqualToAnchor:self.layoutTableEmptyHint.centerXAnchor],
            [btn.centerYAnchor constraintEqualToAnchor:self.layoutTableEmptyHint.centerYAnchor constant:36],
        ]];
    }
}

- (void)rb_onEmptyStartConversationTapped
{
    id app = [UIApplication sharedApplication].delegate;
    if (![app respondsToSelector:@selector(getMainViewController)]) return;
    MainTabsViewController *tabs = [(AppDelegate *)app getMainViewController];
    if (![tabs isKindOfClass:[MainTabsViewController class]]) return;
    tabs.selectedIndex = 2;
    UINavigationController *nav = (UINavigationController *)tabs.selectedViewController;
    if (![nav isKindOfClass:[UINavigationController class]]) return;
    if (self.alarmFilterMode == ALARM_FILTER_GROUP) {
        [ViewControllerFactory goGroupsViewController:nav];
    }
}

// 初始化其它UI
- (void) initOtherUI
{
    // 【暂时禁用】世界频道功能
//    //**** BBS消息提示UI包装实现类
//    self.bbsAlarmUIWrapper = [[BBSAlarmUIWrapper alloc] initWith:self];
//    // 设置BBS的提示消息观察者
//    ObserverCompletion bbsMsgObs = ^(id observerble ,id data) {
//        if(data != nil)
//            [self.bbsAlarmUIWrapper refreshData:(AlarmDto *)data];
//    };
//    // 设置BBS世界频道的数据变动观察者（通过此观察者可以在有新聊天消息或指令时
//    // 能及时刷新界面等，用观察者的目的是使得数据模型能与UI进行代码解偶）
//    [[[[IMClientManager sharedInstance] getAlarmsProvider] getBBSAlarmData] setObserver:bbsMsgObs];
}

- (void)initObservers
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;

    // 与im服务器的网络连接状态观察者（通过通知机制广播给所有AlarmsViewController实例）
    self.networkStatusObserver = ^(id observerble ,id data) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kAlarmsNetworkStatusChanged" object:nil];
    };

    // "消息"列表数据模型变动观察者
    self.alarmsDatasObserver = ^(id observerble ,id data) {
        // 高频（批量同步/未读对齐时可能连续触发）；默认日志级别不输出 Verbose
        DDLogVerbose(@"[AlarmsViewController]收到会话列表数据更新通知 (observerble=%@, data=%@)", observerble, data);

        // 顶栏 (N) 与底部 Tab：立即刷新
        [safeSelf refreshUnreadNumOnTitle];
        [NotificationCenterFactory refreshMainPageTotalUnread_POST];
        // 始终调用 scheduleRefreshTable：内部 cancel 旧 debounce timer 并安排新刷新。
        // 当 view.window == nil（用户在聊天页等子页）时，debounce timer 在 viewWillAppear 出现时触发 refreshTable，
        // 保证删除/收到消息后返回消息列表时立即看到最新列表。
        [safeSelf scheduleRefreshTable];
    };
}

- (void)initDatas
{
    // 首页载入首页的“消息”数据
    [[[IMClientManager sharedInstance] getAlarmsProvider] loadDatasOnce];

//    // 获取未读加好友请求数（包括好友发请求时我不在线的情况），并尝试在首页“消息”里放入一条验证消息的表格item
//    [QueryOfflineBeAddFriendsReqAsync doIt:nil];

    // 刷新表格数据显示
    [self refreshTable];
}

- (void)rb_prepareForUnderlyingPopDisplay
{
    // 供上层聊天页在 pop 动画开始前预热底层消息列表。
    // 若当前还没进 window，只更新内存和 dirty 标记，避免离屏 reload/layout 触发 UIKit warning。
    (void)self.view;
    [self rb_refreshTableAllowOffscreenReload:NO reason:@"prepare-under-pop"];
}

/// 父类 CommonViewController 在 `viewWillAppear` 中会 `refreshAllFonts` → `refreshFontsForView(self.view)`，递归进 UITableView 会把会话 cell 内标题 UILabel 从加粗改成常规体；切底部 Tab 回消息页时该调用先于 `reloadData`，仍会出现昵称字重闪一下。此处对 `tableView` 本身不向下遍历，仅刷新 `tableHeaderView`（搜索区），列表行仍由 `cellForRow` 末尾 `rb_applyAlarmsListCellTypography:` 统一设字重。
/// 另：父类传入的是 `self.view` 而非 `tableView`，若不调以下分支会直接整表递归（会话多时右滑返回首帧明显卡顿）。
- (void)refreshFontsForView:(UIView *)view
{
    if (self.tableView != nil && view == self.tableView) {
        UIView *header = self.tableView.tableHeaderView;
        if (header != nil) {
            [super refreshFontsForView:header];
        }
        return;
    }
    // 与 CommonViewController refreshAllFonts 中对 navigationBar 的处理对齐，但不递归 UITableView 子树
    if (self.tableView != nil && view == self.view) {
        if (self.rb_customNavBar) {
            [BasicTool refreshFontsForView:self.rb_customNavBar];
        }
        if (self.tableView.tableHeaderView) {
            [BasicTool refreshFontsForView:self.tableView.tableHeaderView];
        }
        if (self.navigationController && self.navigationController.navigationBar) {
            NSMutableDictionary *titleTextAttributes = [self.navigationController.navigationBar.titleTextAttributes mutableCopy];
            if (!titleTextAttributes) {
                titleTextAttributes = [NSMutableDictionary dictionary];
            }
            UIFont *currentFont = titleTextAttributes[NSFontAttributeName];
            if (currentFont) {
                CGFloat baseSize = currentFont.pointSize;
                titleTextAttributes[NSFontAttributeName] = [BasicTool getSystemFontOfSize:baseSize];
                self.navigationController.navigationBar.titleTextAttributes = titleTextAttributes;
            }
        }
        return;
    }
    [super refreshFontsForView:view];
}

// 根据UIViewController的生命周期，本方法将在每次本界面每次回到前台时被调用
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_fetchLatestGroupNotifyPreviewIfNeeded];
    // 会话列表隐藏系统栏、改用自定义顶栏。但若在 Pop 动画开始前就 setNavigationBarHidden:YES，
    // 会与下层聊天页共用同一 UINavigationBar，导致右滑/点返回过程中聊天顶栏被提前摘掉。
    // 仅在转场结束后再隐藏；交互式 Pop 取消时不隐藏（用户仍停留在聊天页）。
    BOOL inNavTransition = (self.transitionCoordinator != nil);
    if (inNavTransition && self.transitionCoordinator) {
        id<UIViewControllerTransitionCoordinator> tc = self.transitionCoordinator;
        __weak typeof(self) wself = self;
        [tc animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if ([context isCancelled]) {
                return;
            }
            __strong typeof(wself) sself = wself;
            if (!sself.navigationController) {
                return;
            }
            [sself.navigationController setNavigationBarHidden:YES animated:NO];
        }];
    } else {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
    if (self.rb_customNavBar) {
        [self.view bringSubviewToFront:self.rb_customNavBar];
        [self refreshUnreadNumOnTitle];
    }
    if (self.rb_archivedBatchActionBar && !self.rb_archivedBatchActionBar.hidden) {
        [self.view bringSubviewToFront:self.rb_archivedBatchActionBar];
    }
    if (self.rb_customNavLeftTitleLabel) {
        CGFloat pt = [BasicTool getAdjustedFontSize:22.f];
        self.rb_customNavLeftTitleLabel.font = [UIFont systemFontOfSize:pt weight:UIFontWeightSemibold];
    }
    /* 中间标题不设未读数字；refreshFontsForView 会改字体，此处恢复 */
    if (self.rb_customNavTitleLabel) self.rb_customNavTitleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    // 返回消息列表时，关键排序刷新前移到 viewWillAppear 当拍执行，确保 pop 首帧就使用最新顺序。
    __weak typeof(self) wself = self;
    void (^performCriticalAppearRefresh)(void) = ^{
        __strong typeof(wself) s = wself;
        if (!s) return;
        [s rb_refreshTableAllowOffscreenReload:NO reason:@"viewWillAppear-critical"];
    };
    performCriticalAppearRefresh();
    void (^scheduleDeferredAppearWork)(void) = ^{
        CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{
            __strong typeof(wself) s3 = wself;
            if (!s3) return;
            [s3 rb_performViewWillAppearWorkDeferred];
        });
    };
    id<UIViewControllerTransitionCoordinator> tc = self.transitionCoordinator;
    if (tc != nil) {
        [tc animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if ([context isCancelled]) return;
            scheduleDeferredAppearWork();
        }];
    } else {
        scheduleDeferredAppearWork();
    }
}

- (void)rb_performViewWillAppearWorkDeferred
{

    [self rb_preloadAlarmAvatarsIntoMemory];
    [self rb_prefetchMessagesForVisibleConversations];
    [self refreshNetworkStatusShow];
    [NotificationCenterFactory refreshMainPageTotalUnread_POST];
    [self refreshUnreadNumOnTitle];
    [self startRefreshTimer];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    // viewWillAppear 阶段若仍未进 window，这里兜底补一次真正刷表，确保可见首帧后尽快使用最新排序。
    [self rb_tryFlushDirtyTableAfterScrollIfNeeded];
    // 进入聊天页 NIB 预加热（仅一次，下一 Run Loop 执行，秒显优化）
    [ViewControllerFactory warmChatNibOnce];
    // 气泡图预创建（仅一次），与 NIB 同机触发，首帧即可用共享气泡无占位闪烁
    [ViewControllerFactory warmChatBubbleImagesOnce];
}

// 🆕 页面离开时停止定时刷新（切换 Tab 或 push 到其他界面时）
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self stopRefreshTimer];
    if (self.rb_archivedBatchEditing) {
        [self rb_setArchivedBatchEditing:NO selectAll:NO];
    }
    // 本页使用自定义顶栏并隐藏系统导航栏；push 子页（加好友、群成员、验证、全局搜索等）时若不恢复，子页无标题/返回
    BOOL leavingStack = self.isMovingFromParentViewController || self.isBeingDismissed;
    if (!leavingStack && self.navigationController) {
        [self.navigationController setNavigationBarHidden:NO animated:animated];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (!self.rb_customNavBarHeightConstraint) return;
    CGFloat topInset = self.view.safeAreaInsets.top;
    CGFloat barHeight = topInset + kAlarmsNavBarContentHeight;
    self.rb_customNavBarHeightConstraint.constant = barHeight;
    // 预留高度用 44（与左侧圆钮/右侧胶囊一致），避免搜索框被导航遮挡
    // 底部 FabBar 占位不要写进 additionalSafeAreaInsets：iOS26 上 FabBar(UIHostingController) 是本子控制器的 child，
    // 子控制器会受父级 additionalSafeAreaInsets 影响，导致底栏内部布局被压缩、高度不对；只给 tableView 加 contentInset。
    self.additionalSafeAreaInsets = UIEdgeInsetsMake(kAlarmsNavBarButtonSize, 0, 0, 0);

    CGFloat fabBottom = self.rb_mainTabFabBottomInset;
    if (self.rb_archivedBatchActionBarHeightConstraint) {
        self.rb_archivedBatchActionBarHeightConstraint.constant = kArchivedBatchActionBarHeight + self.view.safeAreaInsets.bottom;
    }
    if (self.tableView) {
        self.rb_archivedBaseTableBottomInset = fabBottom;
        CGFloat targetBottom = fabBottom + (self.rb_archivedBatchEditing ? (kArchivedBatchActionBarHeight + 8.0f) : 0.0f);
        UIEdgeInsets ci = self.tableView.contentInset;
        if (fabs(ci.bottom - targetBottom) > 0.5) {
            self.tableView.contentInset = UIEdgeInsetsMake(ci.top, ci.left, targetBottom, ci.right);
        }
        if (@available(iOS 11.1, *)) {
            UIEdgeInsets vi = self.tableView.verticalScrollIndicatorInsets;
            if (fabs(vi.bottom - targetBottom) > 0.5) {
                self.tableView.verticalScrollIndicatorInsets = UIEdgeInsetsMake(vi.top, vi.left, targetBottom, vi.right);
            }
        } else {
            UIEdgeInsets si = self.tableView.scrollIndicatorInsets;
            self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(si.top, si.left, targetBottom, si.right);
        }
    }

    UIVisualEffectView *backdrop = self.rb_customNavBarBackdropView;
    if (backdrop && backdrop.superview && backdrop.bounds.size.height > 0) {
        CAGradientLayer *maskLayer = self.rb_navBackdropMaskLayer;
        if (!maskLayer) {
            maskLayer = [CAGradientLayer layer];
            maskLayer.colors = @[
                (id)[UIColor colorWithWhite:1.0f alpha:0.96f].CGColor,
                (id)[UIColor colorWithWhite:1.0f alpha:0.92f].CGColor,
                (id)[UIColor colorWithWhite:1.0f alpha:0.88f].CGColor,
                (id)[UIColor colorWithWhite:1.0f alpha:0.84f].CGColor,
                (id)[UIColor colorWithWhite:1.0f alpha:0.0f].CGColor
            ];
            maskLayer.locations = @[ @0.0f, @0.25f, @0.5f, @0.75f, @1.0f ];
            maskLayer.startPoint = CGPointMake(0.5, 0);
            maskLayer.endPoint = CGPointMake(0.5, 1);
            self.rb_navBackdropMaskLayer = maskLayer;
            backdrop.layer.mask = maskLayer;
        }
        if (!CGRectEqualToRect(maskLayer.frame, backdrop.bounds)) {
            maskLayer.frame = backdrop.bounds;
        }
    }

    [self rb_updateCustomNavHorizontalInsetsForNonReadableGuide];
    if (self.rb_archivedBatchActionBar && !self.rb_archivedBatchActionBar.hidden) {
        [self.view bringSubviewToFront:self.rb_archivedBatchActionBar];
    }
    [self.view bringSubviewToFront:self.rb_customNavBar];
}

/// iOS 15+ 已用 view.readableContentGuide 与系统内容区对齐；仅 11～14 用 UINavigationBar 的 margin 同步左右边距
- (void)rb_updateCustomNavHorizontalInsetsForNonReadableGuide
{
    if (@available(iOS 15.0, *)) {
        return;
    }
    if (!self.rb_customNavLeftTitleLeadingConstraint) {
        return;
    }
    CGFloat lead = kMainTabNavSideInsetFallback;
    CGFloat trail = kMainTabNavSideInsetFallback;
    UINavigationBar *nb = self.navigationController.navigationBar;
    if (nb != nil) {
        UIEdgeInsets m = nb.layoutMargins;
        if (m.left >= 4.f && m.left <= 48.f) {
            lead = m.left;
        }
        if (m.right >= 4.f && m.right <= 48.f) {
            trail = m.right;
        }
        if (@available(iOS 11.0, *)) {
            NSDirectionalEdgeInsets d = nb.directionalLayoutMargins;
            if (d.leading >= 4.f && d.leading <= 48.f) {
                lead = d.leading;
            }
            if (d.trailing >= 4.f && d.trailing <= 48.f) {
                trail = d.trailing;
            }
        }
    }
    self.rb_customNavLeftTitleLeadingConstraint.constant = lead;
    if (self.rb_customNavRightPillTrailingConstraint) {
        self.rb_customNavRightPillTrailingConstraint.constant = -trail;
    }
}

#pragma mark - 🆕 UI 刷新节流（防止批量消息导致卡死）

/// 节流延迟（秒）：0.5 秒内多次调用只执行一次 reloadData
static const NSTimeInterval kRefreshThrottleDelay = 0.5;

/**
 * Debounce 版 refreshTable 入口 —— 外部 Observer / 通知回调统一调用此方法。
 *
 * 核心逻辑：
 *  1. 标记 tableDirty = YES（供定时器检查）
 *  2. 若已有排队的刷新定时器，先取消
 *  3. 重新排一个 0.5 秒后的定时器，到时执行一次 refreshTable + refreshUnreadNumOnTitle
 *
 * 效果：500 条消息批量到达 → Observer 被触发 500 次 → 只在最后一次调用后 0.5 秒执行一次 reloadData
 */
- (void)scheduleRefreshTable
{
    self.tableDirty = YES;
    if (self.refreshTableDebounceSource) {
        dispatch_source_cancel(self.refreshTableDebounceSource);
        self.refreshTableDebounceSource = nil;
    }
    self.refreshTableScheduled = YES;
    dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(src, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kRefreshThrottleDelay * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, (uint64_t)(0.05 * NSEC_PER_SEC));
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(src, ^{
        dispatch_source_cancel(src);
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.refreshTableDebounceSource = nil;
        strongSelf.refreshTableScheduled = NO;
        if (strongSelf.swipeMenuVisible || strongSelf.tableView.isEditing) {
            strongSelf.tableDirty = YES;
            [strongSelf refreshUnreadNumOnTitle];
            [NotificationCenterFactory refreshMainPageTotalUnread_POST];
            return;
        }
        if (strongSelf.tableView.dragging || strongSelf.tableView.tracking || strongSelf.tableView.decelerating) {
            strongSelf.tableDirty = YES;
            [strongSelf refreshUnreadNumOnTitle];
            [NotificationCenterFactory refreshMainPageTotalUnread_POST];
            return;
        }
        strongSelf.tableDirty = NO;
        [strongSelf refreshTable];
        [strongSelf refreshUnreadNumOnTitle];
    });
    self.refreshTableDebounceSource = src;
    dispatch_resume(src);
}

#pragma mark - 🆕 定时刷新（多端同步兜底）

/// 定时刷新间隔（秒）：debounce 因滑动/左滑未执行 reload 时的兜底，间隔过长会感觉「未读延迟数秒」
static const NSTimeInterval kRefreshTimerInterval = 1.0;

/**
 * 启动会话列表定时刷新。
 *
 * 定时从内存数据模型尝试刷新表格（仅当 tableDirty；用户滑动会话列表时 debounce 会延迟 reload，此处缩短间隔减少「数秒才更新」的观感）。
 *
 * 此定时器仅在 viewWillAppear 时启动，viewWillDisappear 时停止，不会在后台空跑。
 */
- (void)startRefreshTimer
{
    if (self.refreshTimerRunning) return;
    
    self.refreshTimerRunning = YES;
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    uint64_t interval = (uint64_t)(kRefreshTimerInterval * NSEC_PER_SEC);
    uint64_t leeway   = (uint64_t)(0.5 * NSEC_PER_SEC);
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, interval),
                              interval,
                              leeway);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        // 仅当本页在窗口上可见时刷新，避免 push 到子页或切到其他 Tab 时仍定时 reloadData
        if (strongSelf.view.window == nil) return;
        if (strongSelf.tableDirty) {
            if (strongSelf.swipeMenuVisible || strongSelf.tableView.isEditing) return;
            if (strongSelf.tableView.dragging || strongSelf.tableView.tracking || strongSelf.tableView.decelerating) return;
            strongSelf.tableDirty = NO;
            [strongSelf refreshTable];
            [strongSelf refreshUnreadNumOnTitle];
        }
    });
    
    self.refreshTimer = timer;
    dispatch_resume(timer);
}

/// 停止会话列表定时刷新
- (void)stopRefreshTimer
{
    if (!self.refreshTimerRunning) return;
    
    if (self.refreshTimer) {
        dispatch_source_cancel(self.refreshTimer);
        self.refreshTimer = nil;
    }
    self.refreshTimerRunning = NO;
}

// "viewDidUnload:"方法已在ios6后被废弃（且它只在系统内存低时才被调用），资源释放等工作正确的方式是放到 "dealloc:"中处理
- (void)dealloc
{
    // 取消注册通知：重置群组头像缓存
    [NotificationCenterFactory resetGroupAvatarCache_REMOVE:self];
    // 取消设置网络状态观察者
    ((ChatBaseEventImpl *)[[IMClientManager sharedInstance] getBaseEventListener]).networkStatusObserver = nil;
    // 取消注册网络状态变化通知
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kAlarmsNetworkStatusChanged" object:nil];
    // 取消设置"消息"列表数据模型变动观察者
    [[[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmsData] removeObserver:self.alarmsDatasObserver];
    // 【暂时禁用】世界频道功能
//    // ## 取消设置BBS世界频道消息的数据变动观察者（防止对象被引用而导致本ViewController不能被系统回收）
//    // ## 即时解除对象引用，否则observer中引用了bbsAlarmUIWrapper，而bbsAlarmUIWrapper又引用
//    // ## 了本类，不解除就会导致Activity无法被回收而浪费内存。
//    // 此观察者是在上方的 initViews或其调用的方法中调置的
//    [[[[IMClientManager sharedInstance] getAlarmsProvider] getBBSAlarmData] setObserver:nil];
    
    // 取消注册通知：强制刷新标题上的总未读数（一定要记得通知是不能只add不remove哦）
    [NotificationCenterFactory refreshMainPageTotalUnread_REMOVE:self];
    // 取消注册通知：修改完成好友的备注后的广播
    [NotificationCenterFactory friendRemarkChanged_REMOVE:self];
    
    [NotificationCenterFactory groupNotificationsRealtime_REMOVE:self];
    
    // 🆕 停止定时刷新
    [self stopRefreshTimer];
}

#pragma mark - 首轮 SyncKey 同步 UI（横幅 + 大批量时骨架）

#pragma mark - Table view delegate

- (BOOL)rb_shouldShowGroupNotifyEntry
{
    return self.alarmFilterMode == ALARM_FILTER_PRIVATE && self.rb_groupNotifyHasServerData;
}

- (BOOL)rb_shouldShowArchivedEntry
{
    if (self.showArchivedOnly) {
        return NO;
    }
    if (!(self.alarmFilterMode == ALARM_FILTER_PRIVATE || self.alarmFilterMode == ALARM_FILTER_GROUP)) {
        return NO;
    }
    return ([self rb_archivedConversationCountForCurrentFilter] > 0);
}

- (BOOL)rb_isGroupNotifyEntrySection:(NSInteger)section
{
    AlarmDto *alarm = [self rb_alarmForSection:section];
    return [self rb_isGroupNotifyAlarm:alarm];
}

- (NSInteger)rb_firstAlarmSection
{
    return 0;
}

- (NSInteger)rb_alarmIndexForSection:(NSInteger)section
{
    NSInteger index = section - [self rb_firstAlarmSection];
    if (index < 0 || index >= (NSInteger)self.filteredAlarms.count) {
        return NSNotFound;
    }
    return index;
}

- (AlarmDto *)rb_alarmForSection:(NSInteger)section
{
    NSInteger index = [self rb_alarmIndexForSection:section];
    if (index == NSNotFound) {
        return nil;
    }
    return self.filteredAlarms[index];
}

- (NSInteger)rb_totalSectionCount
{
    return self.filteredAlarms.count;
}

- (BOOL)rb_isGroupNotifyAlarm:(AlarmDto *)alarm
{
    return (alarm != nil
            && alarm.alarmType == AMT_undefine
            && [alarm.dataId isEqualToString:kRbGroupNotifyVirtualDataId]);
}

- (BOOL)rb_isArchivedEntryAlarm:(AlarmDto *)alarm
{
    return (alarm != nil
            && alarm.alarmType == AMT_undefine
            && [alarm.dataId isEqualToString:kRbArchivedEntryVirtualDataId]);
}

- (NSInteger)rb_archivedConversationCountForCurrentFilter
{
    NSInteger count = 0;
    NSArray<AlarmDto *> *allAlarms = [[[[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmsData] getDataList] copy];
    for (AlarmDto *alarm in allAlarms) {
        if (!alarm.archived) {
            continue;
        }
        BOOL matches = NO;
        if (self.alarmFilterMode == ALARM_FILTER_PRIVATE) {
            matches = (alarm.alarmType == AMT_friendChatMessage || alarm.alarmType == AMT_guestChatMessage);
        } else if (self.alarmFilterMode == ALARM_FILTER_GROUP) {
            matches = (alarm.alarmType == AMT_groupChatMessage);
        }
        if (matches) {
            count++;
        }
    }
    return count;
}

- (NSArray<AlarmDto *> *)rb_archivedConversationAlarmsForCurrentFilter
{
    NSMutableArray<AlarmDto *> *result = [NSMutableArray array];
    NSArray<AlarmDto *> *allAlarms = [[[[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmsData] getDataList] copy];
    for (AlarmDto *alarm in allAlarms) {
        if (!alarm.archived) {
            continue;
        }
        BOOL matches = NO;
        if (self.alarmFilterMode == ALARM_FILTER_PRIVATE) {
            matches = (alarm.alarmType == AMT_friendChatMessage || alarm.alarmType == AMT_guestChatMessage);
        } else if (self.alarmFilterMode == ALARM_FILTER_GROUP) {
            matches = (alarm.alarmType == AMT_groupChatMessage);
        }
        if (matches) {
            [result addObject:alarm];
        }
    }
    return result;
}

- (NSString *)rb_archivedConversationPreviewTextForCurrentFilter
{
    NSArray<AlarmDto *> *archivedAlarms = [self rb_archivedConversationAlarmsForCurrentFilter];
    if (archivedAlarms.count == 0) {
        return @"被归档的对话";
    }

    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    NSInteger maxPreviewCount = 4;
    for (AlarmDto *alarm in archivedAlarms) {
        NSString *title = [BasicTool trim:alarm.title];
        if (title.length == 0) {
            continue;
        }
        [titles addObject:title];
        if (titles.count >= maxPreviewCount) {
            break;
        }
    }

    if (titles.count == 0) {
        return @"被归档的对话";
    }

    NSString *joined = [titles componentsJoinedByString:@"、"];
    if (archivedAlarms.count > titles.count) {
        return [NSString stringWithFormat:@"%@ 等%ld个", joined, (long)archivedAlarms.count];
    }
    return [NSString stringWithFormat:@"%@", joined];
}

- (NSInteger)rb_archivedVisibleUnreadCountForCurrentFilter
{
    NSInteger unreadCount = 0;
    NSArray<AlarmDto *> *archivedAlarms = [self rb_archivedConversationAlarmsForCurrentFilter];
    for (AlarmDto *alarm in archivedAlarms) {
        if ([self isSilent:alarm.alarmType dataId:alarm.dataId]) {
            continue;
        }
        NSInteger unreadFlag = MAX([BasicTool getIntValue:alarm.flagNum defaultVal:0], 0);
        NSInteger unreadSrv = MAX((NSInteger)alarm.unreadCount, 0);
        unreadCount += MAX(unreadFlag, unreadSrv);
    }
    return unreadCount;
}

- (BOOL)rb_groupNotifyEntryAlwaysTop
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:kRbGroupNotifyAlwaysTopDefaultsKey];
}

- (void)rb_setGroupNotifyEntryAlwaysTop:(BOOL)alwaysTop
{
    [[NSUserDefaults standardUserDefaults] setBool:alwaysTop forKey:kRbGroupNotifyAlwaysTopDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (long long)rb_groupNotifyReadTimestampMs
{
    return [UserDefaultsToolKits getHasReadLatestGroupNotificationTimestamp];
}

- (void)rb_markGroupNotifyEntryReadWithDate:(NSDate *)date
{
    if (date == nil) {
        return;
    }
    long long currentReadTs = [self rb_groupNotifyReadTimestampMs];
    long long targetTs = (long long)([date timeIntervalSince1970] * 1000.0);
    if (targetTs <= currentReadTs) {
        return;
    }
    [UserDefaultsToolKits setHasReadLatestGroupNotificationTimestamp:date];
    self.rb_groupNotifyUnreadCount = 0;
    [UserDefaultsToolKits setGroupNotificationUnreadCount:0];
    [NotificationCenterFactory refreshMainPageTotalUnread_POST];
}

- (BOOL)rb_shouldExcludeGroupNoticeRaw:(NSDictionary *)raw content:(NSString *)content
{
    if (![raw isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSString *notifyType = [[self rb_stringValue:(raw[@"notify_type"] ?: raw[@"notifyType"] ?: raw[@"type"])] lowercaseString];
    if ([notifyType containsString:@"notice"]) {
        return YES;
    }
    NSString *display = [BasicTool trim:[self rb_stringValue:content]];
    if (display.length == 0) {
        display = [BasicTool trim:[self rb_stringValue:raw[@"content"]]];
    }
    if (display.length == 0) {
        display = [BasicTool trim:[self rb_stringValue:raw[@"notification_content"]]];
    }
    if (display.length == 0) {
        display = [BasicTool trim:[self rb_stringValue:raw[@"notificationContent"]]];
    }
    if (display.length == 0) {
        display = [BasicTool trim:[self rb_stringValue:raw[@"m"]]];
    }
    if (display.length == 0) {
        return NO;
    }
    if ([display containsString:@"【群公告】"]) {
        return YES;
    }
    if (([display containsString:@"@所有人"] || [display containsString:@"所有人"])
        && [display containsString:@"群公告"]) {
        return YES;
    }
    if ([display hasPrefix:@"群公告："] || [display hasPrefix:@"群公告:"] || [display hasPrefix:@"[群公告]"]) {
        return YES;
    }
    return NO;
}

- (NSInteger)rb_groupNotifyUnreadCountFromNotifications:(NSArray<NSDictionary *> *)notifications
                              stopAtOrBeforeTimestampMs:(long long)readTimestampMs
                                    reachedReadBoundary:(BOOL *)reachedReadBoundary
{
    NSInteger unreadCount = 0;
    BOOL reachedBoundary = NO;
    for (NSDictionary *raw in notifications) {
        if (![raw isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDate *date = [self rb_groupNotifyDateFromRawTimeValue:(raw[@"create_time"] ?: raw[@"createTime"])];
        long long itemTimestampMs = 0;
        if (date != nil) {
            itemTimestampMs = (long long)([date timeIntervalSince1970] * 1000.0);
        }
        if (readTimestampMs > 0 && itemTimestampMs > 0 && itemTimestampMs <= readTimestampMs) {
            reachedBoundary = YES;
            break;
        }
        if ([self rb_shouldExcludeGroupNoticeRaw:raw content:nil]) {
            continue;
        }
        unreadCount++;
    }
    if (reachedReadBoundary != NULL) {
        *reachedReadBoundary = reachedBoundary;
    }
    return unreadCount;
}

- (AlarmDto *)rb_buildGroupNotifyVirtualAlarm
{
    if (![self rb_shouldShowGroupNotifyEntry]) {
        return nil;
    }
    AlarmDto *alarm = [[AlarmDto alloc] init];
    alarm.alarmType = AMT_undefine;
    alarm.dataId = kRbGroupNotifyVirtualDataId;
    alarm.title = @"群通知";
    alarm.alarmContent = self.rb_groupNotifyEntryPreviewTextDynamic.length > 0 ? self.rb_groupNotifyEntryPreviewTextDynamic : kRbGroupNotifyEntryPreviewText;
    alarm.date = self.rb_groupNotifyEntryLatestDate ?: [NSDate distantPast];
    NSInteger unreadCount = MAX(self.rb_groupNotifyUnreadCount, 0);
    alarm.flagNum = [NSString stringWithFormat:@"%ld", (long)unreadCount];
    alarm.unreadCount = unreadCount;
    alarm.alwaysTop = [self rb_groupNotifyEntryAlwaysTop];
    return alarm;
}

- (AlarmDto *)rb_buildArchivedVirtualAlarm
{
    if (![self rb_shouldShowArchivedEntry]) {
        return nil;
    }
    AlarmDto *alarm = [[AlarmDto alloc] init];
    alarm.alarmType = AMT_undefine;
    alarm.dataId = kRbArchivedEntryVirtualDataId;
    alarm.title = @"已归档会话";
    alarm.alarmContent = [self rb_archivedConversationPreviewTextForCurrentFilter];
    alarm.date = [NSDate distantPast];
    NSInteger unreadCount = MAX([self rb_archivedVisibleUnreadCountForCurrentFilter], 0);
    alarm.flagNum = unreadCount > 0 ? [NSString stringWithFormat:@"%ld", (long)unreadCount] : @"0";
    alarm.unreadCount = unreadCount;
    return alarm;
}

- (void)rb_configureGroupNotifyEntryCell:(AlarmsTableViewCell *)cell
{
    [RBAvatarView removeAvatarFromImageView:cell.viewIcon];

    BOOL alwaysTop = [self rb_groupNotifyEntryAlwaysTop];
    NSInteger unreadCount = MAX(self.rb_groupNotifyUnreadCount, 0);
    BOOL noUnread = (unreadCount <= 0);
    cell.backgroundColor = alwaysTop ? HexColor(0xF0F0F0) : [UIColor clearColor];
    cell.viewTitle.text = @"群通知";
    cell.viewDate.text = self.rb_groupNotifyEntryPreviewDateText ?: @"";
    cell.viewDate.hidden = NO;
    NSString *previewText = self.rb_groupNotifyEntryPreviewTextDynamic.length > 0 ? self.rb_groupNotifyEntryPreviewTextDynamic : kRbGroupNotifyEntryPreviewText;
    cell.viewMsgContent.textColor = HexColor(0x8E8E93);
    cell.viewMsgContent.attributedText = [[NSAttributedString alloc] initWithString:previewText
                                                                         attributes:@{
        NSForegroundColorAttributeName: HexColor(0x8E8E93),
        NSFontAttributeName: [BasicTool getSystemFontOfSize:kAlarmsCellMsgFontBase]
    }];
    cell.viewMsgPrefix.hidden = YES;
    cell.viewMsgPrefix.text = nil;
    cell.viewMsgPrefix_rightGapConstraint.constant = 0;
    if (noUnread) {
        cell.viewFlagNum2.hidden = YES;
    } else {
        UIColor *badgeRed = [UIColor colorWithRed:247.f/255.f green:76.f/255.f blue:49.f/255.f alpha:1.f];
        [cell.viewFlagNum2 setBadgeBackgroundColor:badgeRed];
        [cell.viewFlagNum2 setBadgeTextColor:[UIColor whiteColor]];
        [cell.viewFlagNum2 setBadgeValue:[NSString stringWithFormat:@"%ld", (long)unreadCount]];
        cell.viewFlagNum2.hidden = NO;
    }
    cell.viewFlagDot.hidden = YES;
    BOOL showPinIcon = (alwaysTop && noUnread);
    cell.viewAlwaystopIcon.hidden = !showPinIcon;
    if (showPinIcon && cell.viewAlwaystopIcon != nil) {
        UIImage *pinImg = [UIImage imageNamed:@"main_alarms_list_item_alwaytop"];
        if (pinImg != nil) {
            cell.viewAlwaystopIcon.image = [pinImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            cell.viewAlwaystopIcon.tintColor = nil;
        }
    }
    cell.viewTitleLeftFlagContainer_widthConstraint.constant = 0;
    cell.viewTitleRightFlagContainer_widthConstraint.constant = 0;
    cell.viewTitleRightFlag.hidden = YES;
    cell.viewTitleRightFlagImageView.hidden = YES;
    cell.viewSilentIcon.hidden = YES;
    if (cell.viewSilentIconWidthConstraint != nil) {
        cell.viewSilentIconWidthConstraint.constant = 0.0;
    }
    if (cell.viewSilentIconLeadingConstraint != nil) {
        cell.viewSilentIconLeadingConstraint.constant = 0.0;
    }
    if (cell.viewMsgContentTopFromTitleConstraint != nil) {
        cell.viewMsgContentTopFromTitleConstraint.constant = 3.0;
    }
    if (cell.viewMsgPrefixTopFromTitleConstraint != nil) {
        cell.viewMsgPrefixTopFromTitleConstraint.constant = 3.0;
    }

    cell.viewIcon.layer.cornerRadius = 24.0f;
    cell.viewIcon.layer.masksToBounds = YES;
    cell.viewIcon.backgroundColor = HexColor(0xEAF2FF);
    cell.viewIcon.contentMode = UIViewContentModeCenter;
    UIImage *entryIcon = [UIImage imageNamed:@"main_alarms_list_item_icon_notify"];
    if (entryIcon == nil) {
        entryIcon = [UIImage imageNamed:@"main_alarms_system_message_icon"];
    }
    if (entryIcon != nil) {
        cell.viewIcon.image = [entryIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.viewIcon.tintColor = HexColor(0x257CFF);
    } else {
        cell.viewIcon.image = nil;
        cell.viewIcon.tintColor = nil;
    }

    [self rb_applyAlarmsListCellTypography:cell];
    [cell setNeedsLayout];
    [cell.contentView setNeedsLayout];
    [cell.contentView layoutIfNeeded];
    [cell layoutIfNeeded];
}

- (void)rb_configureArchivedEntryCell:(AlarmsTableViewCell *)cell
{
    [RBAvatarView removeAvatarFromImageView:cell.viewIcon];

    NSInteger unreadCount = MAX([self rb_archivedVisibleUnreadCountForCurrentFilter], 0);
    cell.backgroundColor = [UIColor clearColor];
    cell.viewTitle.text = @"已归档会话";
    cell.viewDate.text = @"";
    cell.viewDate.hidden = YES;
    NSString *previewText = [self rb_archivedConversationPreviewTextForCurrentFilter];
    cell.viewMsgContent.textColor = HexColor(0x8E8E93);
    cell.viewMsgContent.attributedText = [[NSAttributedString alloc] initWithString:previewText
                                                                         attributes:@{
        NSForegroundColorAttributeName: HexColor(0x8E8E93),
        NSFontAttributeName: [BasicTool getSystemFontOfSize:kAlarmsCellMsgFontBase]
    }];
    cell.viewMsgPrefix.hidden = YES;
    cell.viewMsgPrefix.text = nil;
    cell.viewMsgPrefix_rightGapConstraint.constant = 0;
    if (unreadCount > 0) {
        UIColor *badgeGray = HexColor(0xAEAEB2);
        [cell.viewFlagNum2 setBadgeBackgroundColor:badgeGray];
        [cell.viewFlagNum2 setBadgeTextColor:[UIColor whiteColor]];
        [cell.viewFlagNum2 setBadgeValue:[NSString stringWithFormat:@"%ld", (long)unreadCount]];
        cell.viewFlagNum2.hidden = NO;
    } else {
        cell.viewFlagNum2.hidden = YES;
    }
    cell.viewFlagDot.hidden = YES;
    cell.viewAlwaystopIcon.hidden = YES;
    cell.viewTitleLeftFlagContainer_widthConstraint.constant = 0;
    cell.viewTitleRightFlagContainer_widthConstraint.constant = 0;
    cell.viewTitleRightFlag.hidden = YES;
    cell.viewTitleRightFlagImageView.hidden = YES;
    cell.viewSilentIcon.hidden = YES;
    if (cell.viewSilentIconWidthConstraint != nil) {
        cell.viewSilentIconWidthConstraint.constant = 0.0;
    }
    if (cell.viewSilentIconLeadingConstraint != nil) {
        cell.viewSilentIconLeadingConstraint.constant = 0.0;
    }
    if (cell.viewMsgContentTopFromTitleConstraint != nil) {
        cell.viewMsgContentTopFromTitleConstraint.constant = 3.0;
    }
    if (cell.viewMsgPrefixTopFromTitleConstraint != nil) {
        cell.viewMsgPrefixTopFromTitleConstraint.constant = 3.0;
    }

    cell.viewIcon.layer.cornerRadius = 24.0f;
    cell.viewIcon.layer.masksToBounds = YES;
    cell.viewIcon.backgroundColor = HexColor(0xF5F1FF);
    cell.viewIcon.contentMode = UIViewContentModeCenter;
    UIImage *entryIcon = [UIImage imageNamed:@"main_alarms_system_message_icon"];
    if (@available(iOS 13.0, *)) {
        UIImage *symbol = [UIImage systemImageNamed:@"archivebox.fill"];
        if (symbol != nil) {
            entryIcon = symbol;
        }
    }
    if (entryIcon != nil) {
        cell.viewIcon.image = [entryIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.viewIcon.tintColor = HexColor(0x7B61FF);
    } else {
        cell.viewIcon.image = nil;
        cell.viewIcon.tintColor = nil;
    }

    [self rb_applyAlarmsListCellTypography:cell];
    [cell setNeedsLayout];
    [cell.contentView setNeedsLayout];
    [cell.contentView layoutIfNeeded];
    [cell layoutIfNeeded];
}

- (void)rb_onGroupNotificationsRealtimePush:(NSNotification *)notification
{
    (void)notification;
    [self rb_fetchLatestGroupNotifyPreviewIfNeeded];
}

- (void)rb_fetchLatestGroupNotifyPreviewIfNeeded
{
    if (self.alarmFilterMode != ALARM_FILTER_PRIVATE) {
        self.rb_groupNotifyEntryPreviewTextDynamic = nil;
        self.rb_groupNotifyEntryPreviewDateText = nil;
        self.rb_groupNotifyEntryLatestDate = nil;
        self.rb_groupNotifyUnreadCount = 0;
        self.rb_groupNotifyHasServerData = NO;
        return;
    }
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid ?: @"";
    if (uid.length == 0) {
        self.rb_groupNotifyEntryPreviewTextDynamic = nil;
        self.rb_groupNotifyEntryPreviewDateText = nil;
        self.rb_groupNotifyEntryLatestDate = nil;
        self.rb_groupNotifyUnreadCount = 0;
        self.rb_groupNotifyHasServerData = NO;
        return;
    }

    long long readTimestampMs = [self rb_groupNotifyReadTimestampMs];
    __weak typeof(self) weakSelf = self;
    __block NSString *latestPreviewText = nil;
    __block NSString *latestPreviewDateText = nil;
    __block NSDate *latestDate = nil;
    __block NSInteger unreadCount = 0;
    __block BOOL hasAnyNotificationData = NO;
    __block void (^fetchPage)(NSInteger);
    void (^applyResult)(BOOL) = ^(BOOL sucess) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSString *newPreviewText = sucess ? latestPreviewText : nil;
        NSString *newPreviewDateText = sucess ? latestPreviewDateText : nil;
        NSDate *newLatestDate = sucess ? latestDate : nil;
        NSInteger newUnreadCount = sucess ? unreadCount : 0;
        BOOL newHasServerData = sucess ? hasAnyNotificationData : self.rb_groupNotifyHasServerData;
        BOOL changed = !((self.rb_groupNotifyEntryPreviewTextDynamic ?: @"").length == (newPreviewText ?: @"").length
                         && ((self.rb_groupNotifyEntryPreviewTextDynamic == newPreviewText) || [self.rb_groupNotifyEntryPreviewTextDynamic isEqualToString:newPreviewText ?: @""])
                         && ((self.rb_groupNotifyEntryPreviewDateText == newPreviewDateText) || [self.rb_groupNotifyEntryPreviewDateText isEqualToString:newPreviewDateText ?: @""])
                         && ((self.rb_groupNotifyEntryLatestDate == newLatestDate) || [self.rb_groupNotifyEntryLatestDate isEqualToDate:newLatestDate])
                         && self.rb_groupNotifyUnreadCount == newUnreadCount
                         && self.rb_groupNotifyHasServerData == newHasServerData);
        self.rb_groupNotifyEntryPreviewTextDynamic = newPreviewText;
        self.rb_groupNotifyEntryPreviewDateText = newPreviewDateText;
        self.rb_groupNotifyEntryLatestDate = newLatestDate;
        self.rb_groupNotifyUnreadCount = newUnreadCount;
        self.rb_groupNotifyHasServerData = newHasServerData;
        [UserDefaultsToolKits setGroupNotificationUnreadCount:newUnreadCount];
        [NotificationCenterFactory refreshMainPageTotalUnread_POST];
        if (changed && self.tableView != nil) {
            [self refreshTable];
        }
    };
    fetchPage = ^(NSInteger page) {
        [[HttpRestHelper sharedInstance] submitQueryAllGroupNotificationsFromServer:uid
                                                                               page:page
                                                                           pageSize:kRbGroupNotifyUnreadFetchPageSize
                                                                           complete:^(BOOL sucess, NSDictionary *result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                if (!sucess) {
                    applyResult(NO);
                    return;
                }
                NSArray *notifications = [result[@"notifications"] isKindOfClass:[NSArray class]] ? result[@"notifications"] : @[];
                if (latestDate == nil) {
                    for (NSDictionary *raw in notifications) {
                        if (![raw isKindOfClass:[NSDictionary class]]) {
                            continue;
                        }
                        if ([self rb_shouldExcludeGroupNoticeRaw:raw content:nil]) {
                            continue;
                        }
                        hasAnyNotificationData = YES;
                        latestPreviewText = [self rb_groupNotifyEntryPreviewTextFromRaw:raw];
                        latestPreviewDateText = [self rb_groupNotifyEntryPreviewDateTextFromRaw:raw];
                        latestDate = [self rb_groupNotifyDateFromRawTimeValue:(raw[@"create_time"] ?: raw[@"createTime"])];
                        break;
                    }
                } else {
                    for (NSDictionary *raw in notifications) {
                        if (![raw isKindOfClass:[NSDictionary class]]) {
                            continue;
                        }
                        if ([self rb_shouldExcludeGroupNoticeRaw:raw content:nil]) {
                            continue;
                        }
                        hasAnyNotificationData = YES;
                        break;
                    }
                }
                BOOL reachedBoundary = NO;
                unreadCount += [self rb_groupNotifyUnreadCountFromNotifications:notifications
                                                     stopAtOrBeforeTimestampMs:readTimestampMs
                                                           reachedReadBoundary:&reachedBoundary];
                BOOL hasMore = (notifications.count >= kRbGroupNotifyUnreadFetchPageSize
                                && !reachedBoundary
                                && page < kRbGroupNotifyUnreadFetchMaxPages);
                if (hasMore) {
                    fetchPage(page + 1);
                } else {
                    applyResult(YES);
                }
            });
        } hudParentView:nil];
    };
    fetchPage(1);
}

- (NSString *)rb_groupNotifyEntryPreviewTextFromRaw:(NSDictionary *)raw
{
    if (![raw isKindOfClass:[NSDictionary class]]) {
        return kRbGroupNotifyEntryPreviewText;
    }
    NSInteger msgType = 54;
    NSString *content = [self rb_stringValue:raw[@"content"]];
    if (content.length == 0) {
        content = [self rb_stringValue:raw[@"notification_content"]];
    }
    NSString *notifyType = [self rb_stringValue:raw[@"notify_type"]];
    if (notifyType.length == 0) {
        notifyType = [self rb_stringValue:raw[@"notifyType"]];
    }
    NSString *type = [self rb_stringValue:raw[@"type"]];
    if ([type isEqualToString:@"join_request"]) {
        msgType = 52;
    } else if ([type isEqualToString:@"join_review_result"]) {
        msgType = 53;
    } else if (notifyType.length > 0) {
        msgType = 54;
    }
    if (content.length == 0) {
        content = [self rb_fallbackGroupNotifyContentForRaw:raw msgType:msgType];
    }
    content = [self rb_normalizedGroupNotifyContentForDisplay:content raw:raw];
    return content.length > 0 ? content : kRbGroupNotifyEntryPreviewText;
}

- (NSString *)rb_groupNotifyEntryPreviewDateTextFromRaw:(NSDictionary *)raw
{
    if (![raw isKindOfClass:[NSDictionary class]]) {
        return @"";
    }
    id rawTimeValue = raw[@"create_time"];
    if (rawTimeValue == nil) {
        rawTimeValue = raw[@"createTime"];
    }
    NSDate *date = [self rb_groupNotifyDateFromRawTimeValue:rawTimeValue];
    if (date == nil) {
        return @"";
    }
    return [TimeTool getTimeStringAutoShort2:date mustIncludeTime:NO timeWithSegment:NO];
}

- (NSString *)rb_fallbackGroupNotifyContentForRaw:(NSDictionary *)raw msgType:(NSInteger)msgType
{
    if (![raw isKindOfClass:[NSDictionary class]]) {
        return @"群通知";
    }
    if (msgType == 52) {
        NSString *nickname = [self rb_stringValue:raw[@"applicant_nickname"]];
        return nickname.length > 0 ? [NSString stringWithFormat:@"%@申请加入群聊", nickname] : @"入群申请";
    }
    if (msgType == 53) {
        BOOL approved = [self rb_boolValue:raw[@"approved"] defaultValue:NO];
        NSString *rejectReason = [self rb_stringValue:raw[@"reject_reason"]];
        if (approved) {
            return @"你的入群申请已通过审核";
        }
        return rejectReason.length > 0 ? [NSString stringWithFormat:@"你的入群申请已被拒绝：%@", rejectReason] : @"你的入群申请已被拒绝";
    }

    NSString *notifyType = [self rb_stringValue:raw[@"notifyType"]];
    if (notifyType.length == 0) {
        notifyType = [self rb_stringValue:raw[@"notify_type"]];
    }
    NSString *operatorNickname = [self rb_stringValue:raw[@"operatorNickname"]];
    if (operatorNickname.length == 0) {
        operatorNickname = [self rb_stringValue:raw[@"operator_nickname"]];
    }
    NSString *targetNickname = [self rb_stringValue:raw[@"targetNickname"]];
    if (targetNickname.length == 0) {
        targetNickname = [self rb_stringValue:raw[@"target_nickname"]];
    }
    if ([notifyType isEqualToString:@"admin_set"]) {
        return (operatorNickname.length > 0 && targetNickname.length > 0) ? [NSString stringWithFormat:@"%@将%@设为管理员", operatorNickname, targetNickname] : @"管理员设置通知";
    }
    if ([notifyType isEqualToString:@"admin_remove"]) {
        return (operatorNickname.length > 0 && targetNickname.length > 0) ? [NSString stringWithFormat:@"%@取消了%@的管理员身份", operatorNickname, targetNickname] : @"管理员移除通知";
    }
    if ([notifyType isEqualToString:@"transfer_owner"]) {
        return @"你已成为群主";
    }
    if ([notifyType isEqualToString:@"dismiss_group"]) {
        return @"该群已解散";
    }
    return @"群通知";
}

- (NSString *)rb_normalizedGroupNotifyContentForDisplay:(NSString *)content raw:(NSDictionary *)raw
{
    NSString *display = [self rb_stringValue:content];
    if (display.length == 0) {
        return @"";
    }
    NSString *currentUid = [self rb_stringValue:[IMClientManager sharedInstance].localUserInfo.user_uid];
    NSString *currentNickname = [BasicTool trim:[self rb_stringValue:[IMClientManager sharedInstance].localUserInfo.nickname]];
    NSMutableOrderedSet<NSString *> *candidates = [NSMutableOrderedSet orderedSet];
    if (currentNickname.length > 0) {
        [candidates addObject:currentNickname];
    }
    [self rb_appendCandidateNameFromRaw:raw uidKey:@"applicant_uid" nameKey:@"applicant_nickname" currentUid:currentUid toSet:candidates];
    [self rb_appendCandidateNameFromRaw:raw uidKey:@"reviewer_uid" nameKey:@"reviewer_nickname" currentUid:currentUid toSet:candidates];
    [self rb_appendCandidateNameFromRaw:raw uidKey:@"operator_uid" nameKey:@"operator_nickname" currentUid:currentUid toSet:candidates];
    [self rb_appendCandidateNameFromRaw:raw uidKey:@"operatorUid" nameKey:@"operatorNickname" currentUid:currentUid toSet:candidates];
    [self rb_appendCandidateNameFromRaw:raw uidKey:@"target_uid" nameKey:@"target_nickname" currentUid:currentUid toSet:candidates];
    [self rb_appendCandidateNameFromRaw:raw uidKey:@"targetUid" nameKey:@"targetNickname" currentUid:currentUid toSet:candidates];
    for (NSString *name in candidates) {
        if (name.length == 0) continue;
        NSString *quotedName = [NSString stringWithFormat:@"\"%@\"", name];
        display = [display stringByReplacingOccurrencesOfString:quotedName withString:@"你"];
        display = [display stringByReplacingOccurrencesOfString:name withString:@"你"];
    }
    display = [display stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    display = [display stringByReplacingOccurrencesOfString:@"“" withString:@""];
    display = [display stringByReplacingOccurrencesOfString:@"”" withString:@""];
    NSString *notifyType = [self rb_stringValue:raw[@"notifyType"]];
    if (notifyType.length == 0) {
        notifyType = [self rb_stringValue:raw[@"notify_type"]];
    }
    if (([notifyType isEqualToString:@"admin_set"] || [notifyType isEqualToString:@"admin_remove"]) && [display hasPrefix:@"群主"]) {
        display = [display substringFromIndex:2];
    }
    return display;
}

- (void)rb_appendCandidateNameFromRaw:(NSDictionary *)raw
                               uidKey:(NSString *)uidKey
                              nameKey:(NSString *)nameKey
                           currentUid:(NSString *)currentUid
                                toSet:(NSMutableOrderedSet<NSString *> *)set
{
    if (![raw isKindOfClass:[NSDictionary class]] || currentUid.length == 0 || set == nil) return;
    NSString *uid = [self rb_stringValue:raw[uidKey]];
    if (![uid isEqualToString:currentUid]) return;
    NSString *name = [BasicTool trim:[self rb_stringValue:raw[nameKey]]];
    if (name.length > 0) {
        [set addObject:name];
    }
}

- (NSDate *)rb_groupNotifyDateFromRawTimeValue:(id)rawTimeValue
{
    if ([rawTimeValue isKindOfClass:[NSNumber class]]) {
        double ts = [(NSNumber *)rawTimeValue doubleValue];
        if (ts > 1000000000000.0) ts = ts / 1000.0;
        if (ts > 0) return [NSDate dateWithTimeIntervalSince1970:ts];
    }
    if ([rawTimeValue isKindOfClass:[NSString class]]) {
        NSString *timeString = [(NSString *)rawTimeValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (timeString.length == 0) return nil;
        BOOL allDigits = YES;
        for (NSUInteger i = 0; i < timeString.length; i++) {
            unichar ch = [timeString characterAtIndex:i];
            if (ch < '0' || ch > '9') {
                allDigits = NO;
                break;
            }
        }
        if (allDigits) {
            double ts = [timeString doubleValue];
            if (ts > 1000000000000.0) ts = ts / 1000.0;
            if (ts > 0) return [NSDate dateWithTimeIntervalSince1970:ts];
        }
        static NSDateFormatter *formatterSec = nil;
        static NSDateFormatter *formatterMin = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            formatterSec = [[NSDateFormatter alloc] init];
            formatterSec.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatterSec.timeZone = [NSTimeZone localTimeZone];
            formatterSec.dateFormat = @"yyyy-MM-dd HH:mm:ss";

            formatterMin = [[NSDateFormatter alloc] init];
            formatterMin.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatterMin.timeZone = [NSTimeZone localTimeZone];
            formatterMin.dateFormat = @"yyyy-MM-dd HH:mm";
        });
        NSDate *date = [formatterSec dateFromString:timeString];
        if (date == nil) date = [formatterMin dateFromString:timeString];
        return date;
    }
    return nil;
}

- (NSString *)rb_stringValue:(id)value
{
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    return @"";
}

- (BOOL)rb_boolValue:(id)value defaultValue:(BOOL)defaultValue
{
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value boolValue];
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *lower = [(NSString *)value lowercaseString];
        if ([lower isEqualToString:@"true"] || [lower isEqualToString:@"1"]) return YES;
        if ([lower isEqualToString:@"false"] || [lower isEqualToString:@"0"]) return NO;
    }
    return defaultValue;
}

// 表格行数
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    (void)tableView;
    return [self rb_totalSectionCount];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    AlarmDto *alarm = [self rb_alarmForSection:indexPath.section];
    if (alarm == nil || [self rb_isGroupNotifyAlarm:alarm] || [self rb_isArchivedEntryAlarm:alarm]) {
        return NO;
    }
    return YES;
}

// 表格行高
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 68;
}

/// 列表正在滑动时 scheduleRefreshTable / 定时器会刻意不 reloadData（避免卡顿），仅置 tableDirty；
/// 若缺少滚动结束后的补刷，会话行未读气泡会一直停在旧值，直到偶发定时器命中。
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView != self.tableView) return;
    [self rb_tryFlushDirtyTableAfterScrollIfNeeded];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView != self.tableView) return;
    if (!decelerate) {
        [self rb_tryFlushDirtyTableAfterScrollIfNeeded];
    }
}

- (void)rb_tryFlushDirtyTableAfterScrollIfNeeded
{
    if (!self.tableDirty) return;
    if (self.swipeMenuVisible || self.tableView.isEditing) return;
    if (self.tableView.dragging || self.tableView.tracking || self.tableView.decelerating) return;
    self.tableDirty = NO;
    [self refreshTable];
    [self refreshUnreadNumOnTitle];
}

// 左滑菜单开始显示
- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.swipeMenuVisible = YES;
}

// 左滑菜单结束显示（收起后再补一次静默刷新）
- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(nullable NSIndexPath *)indexPath
{
    self.swipeMenuVisible = NO;
    if (self.tableDirty) {
        self.tableDirty = NO;
        [self refreshTable];
        [self refreshUnreadNumOnTitle];
    }
}

/// 若会话需要用户头像则返回其 SD 缓存 key，否则返回 nil（与 cellForRow 中 path 一致）
- (NSString *)rb_avatarPathForAlarm:(AlarmDto *)ree
{
    if (!ree) return nil;
    NSString *uid = nil;
    NSString *fileName = nil;
    if (ree.alarmType == AMT_friendChatMessage && ree.dataId.length > 0) {
        UserEntity *friendRee = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:ree.dataId];
        if (friendRee) fileName = friendRee.userAvatarFileName;
        uid = ree.dataId;
    } else if (ree.alarmType == AMT_guestChatMessage && ree.dataId.length > 0) {
        fileName = ree.extraString1;
        uid = ree.dataId;
    }
    if (!uid.length) return nil;
    if ([FileDownloadHelper isVideoAvatarFileName:fileName]) return nil;
    return [FileDownloadHelper getUserAvatarDownloadURLExt:![BasicTool isStringEmpty:fileName] fileName:fileName ?: @"" uid:uid];
}

/// 首屏头像同步从磁盘读入内存（主线程），供 refreshTable 在 reloadData 前调用，使第一帧即真实头像。会同时尝试 path 与 uid-only key，兼容列表未带 fileName 时仅用 uid 存的缓存。
- (void)rb_preloadFirstScreenAvatarsSync
{
    NSArray<AlarmDto *> *alarms = self.filteredAlarms;
    if (!alarms.count) return;
    static const NSUInteger kFirstScreenUserAvatarCount = 20;
    static const NSUInteger kMaxScanCount = 50;
    NSUInteger loaded = 0;
    NSUInteger scanLimit = MIN(alarms.count, kMaxScanCount);
    for (NSUInteger i = 0; i < scanLimit && loaded < kFirstScreenUserAvatarCount; i++) {
        AlarmDto *alarm = alarms[i];
        NSString *path = [self rb_avatarPathForAlarm:alarm];
        if (!path.length) continue;
        UIImage *img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:path];
        if (!img && alarm.dataId.length > 0 && (alarm.alarmType == AMT_friendChatMessage || alarm.alarmType == AMT_guestChatMessage)) {
            NSString *uidOnlyPath = [FileDownloadHelper getUserAvatarDownloadURLExt:NO fileName:nil uid:alarm.dataId];
            if (uidOnlyPath.length > 0) img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:uidOnlyPath];
        }
        if (img) {
            [[SDImageCache sharedImageCache] storeImage:img forKey:path toDisk:NO completion:nil];
            loaded++;
        }
    }
}

/// 首屏头像在后台队列从磁盘解码并写入内存缓存，完成后在主线程仅刷新本次成功加载头像的行（缩小主线程刷新范围）。
- (void)rb_preloadFirstScreenAvatarsAsync
{
    NSArray<AlarmDto *> *alarms = self.filteredAlarms;
    if (!alarms.count) return;
    static const NSUInteger kFirstScreenUserAvatarCount = 20;
    static const NSUInteger kMaxScanCount = 50;
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSNumber *> *loadedSections = [NSMutableArray array];
        NSUInteger loaded = 0;
        NSUInteger scanLimit = MIN(alarms.count, kMaxScanCount);
        for (NSUInteger i = 0; i < scanLimit && loaded < kFirstScreenUserAvatarCount; i++) {
            AlarmDto *alarm = alarms[i];
            NSString *path = [wself rb_avatarPathForAlarm:alarm];
            if (!path.length) continue;
            UIImage *img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:path];
            if (!img && alarm.dataId.length > 0 && (alarm.alarmType == AMT_friendChatMessage || alarm.alarmType == AMT_guestChatMessage)) {
                NSString *uidOnlyPath = [FileDownloadHelper getUserAvatarDownloadURLExt:NO fileName:nil uid:alarm.dataId];
                if (uidOnlyPath.length > 0) img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:uidOnlyPath];
            }
            if (img) {
                [[SDImageCache sharedImageCache] storeImage:img forKey:path toDisk:NO completion:nil];
                [loadedSections addObject:@(i)];
                loaded++;
            }
        }
        if (loadedSections.count == 0) return;
        NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray arrayWithCapacity:loadedSections.count];
        for (NSNumber *sec in loadedSections) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:0 inSection:sec.unsignedIntegerValue]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!wself.tableView.window) return;
            NSArray *visible = [wself.tableView indexPathsForVisibleRows];
            NSMutableArray *toReload = [NSMutableArray array];
            for (NSIndexPath *ip in indexPaths) {
                if ([visible containsObject:ip]) [toReload addObject:ip];
            }
            if (toReload.count) {
                [UIView performWithoutAnimation:^{
                    [wself.tableView reloadRowsAtIndexPaths:toReload withRowAnimation:UITableViewRowAnimationNone];
                }];
            }
        });
    });
}

/// 冷启动时在后台把可见会话的用户头像从磁盘预入内存，仅刷新本次成功加载头像的可见行；会同时尝试 uid-only key。
- (void)rb_preloadAlarmAvatarsIntoMemory
{
    NSArray<AlarmDto *> *alarms = self.filteredAlarms;
    if (!alarms.count) return;
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSNumber *> *loadedSections = [NSMutableArray array];
        NSUInteger limit = MIN(alarms.count, 40);
        for (NSUInteger i = 0; i < limit; i++) {
            AlarmDto *alarm = alarms[i];
            NSString *path = [wself rb_avatarPathForAlarm:alarm];
            if (!path.length) continue;
            UIImage *img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:path];
            if (!img && alarm.dataId.length > 0 && (alarm.alarmType == AMT_friendChatMessage || alarm.alarmType == AMT_guestChatMessage)) {
                NSString *uidOnlyPath = [FileDownloadHelper getUserAvatarDownloadURLExt:NO fileName:nil uid:alarm.dataId];
                if (uidOnlyPath.length > 0) img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:uidOnlyPath];
            }
            if (img) {
                [[SDImageCache sharedImageCache] storeImage:img forKey:path toDisk:NO completion:nil];
                [loadedSections addObject:@(i)];
            }
        }
        if (loadedSections.count == 0) return;
        NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray arrayWithCapacity:loadedSections.count];
        for (NSNumber *sec in loadedSections) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:0 inSection:sec.unsignedIntegerValue]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!wself.tableView.window) return;
            NSArray *visible = [wself.tableView indexPathsForVisibleRows];
            NSMutableArray *toReload = [NSMutableArray array];
            for (NSIndexPath *ip in indexPaths) {
                if ([visible containsObject:ip]) [toReload addObject:ip];
            }
            if (toReload.count) {
                [UIView performWithoutAnimation:^{
                    [wself.tableView reloadRowsAtIndexPaths:toReload withRowAnimation:UITableViewRowAnimationNone];
                }];
            }
        });
    });
}

/// 预取可见/前 N 条会话的聊天消息到内存，使从列表点进聊天页时 getMessages 直接命中缓存，实现秒进（仿 Telegram）。
/// 仅处理会进入聊天页的类型：好友聊、陌生人聊、群聊。在主线程调用 getMessages 触发后台 loadHistory。
static const NSUInteger kPrefetchConversationLimit = 8;

- (void)rb_prefetchMessagesForVisibleConversations
{
    NSArray<AlarmDto *> *alarms = self.filteredAlarms;
    if (!alarms.count) return;
    NSUInteger limit = MIN(alarms.count, kPrefetchConversationLimit);
    MessagesProvider *mp = [[IMClientManager sharedInstance] getMessagesProvider];
    GroupsMessagesProvider *gmp = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
    for (NSUInteger i = 0; i < limit; i++) {
        AlarmDto *alarm = alarms[i];
        if ([self rb_isGroupNotifyAlarm:alarm] || [self rb_isArchivedEntryAlarm:alarm]) continue;
        if ([BasicTool isStringEmpty:alarm.dataId]) continue;
        if (alarm.alarmType == AMT_friendChatMessage || alarm.alarmType == AMT_guestChatMessage) {
            (void)[mp getMessages:alarm.dataId];
        } else if (alarm.alarmType == AMT_groupChatMessage) {
            (void)[gmp getMessages:alarm.dataId];
        }
    }
}

/// 会话列表 cell  typography：在好友昵称等覆盖标题文本之后调用，保证标题始终为加粗基准字号。
- (void)rb_applyAlarmsListCellTypography:(AlarmsTableViewCell *)cell
{
    cell.viewTitle.font = [BasicTool getBoldSystemFontOfSize:kAlarmsCellTitleFontBase];
    cell.viewDate.font = [BasicTool getSystemFontOfSize:kAlarmsCellDateFontBase];
    cell.viewMsgPrefix.font = [BasicTool getSystemFontOfSize:kAlarmsCellMsgFontBase];
    cell.viewTitleLeftFlag.font = [BasicTool getSystemFontOfSize:kAlarmsCellFlagFontBase];
    cell.viewTitleRightFlag.font = [BasicTool getSystemFontOfSize:kAlarmsCellFlagFontBase];
    UIFont *msgFont = [BasicTool getSystemFontOfSize:kAlarmsCellMsgFontBase];
    if (cell.viewMsgContent.attributedText.length == 0) {
        cell.viewMsgContent.font = msgFont;
    }
}

// 表示行的UI显示内容
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *theCell = nil;

    // 表格单元可重用ui
    static NSString *idenfity=@"CellMain";
    AlarmsTableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:idenfity];
    if(cell==nil) {
        NSArray* arr = [[NSBundle mainBundle] loadNibNamed:@"AlarmsTableViewCell" owner:self options:nil];
        for (id obj in arr) {
            if ([obj isKindOfClass:[AlarmsTableViewCell class]]) {
                cell = (AlarmsTableViewCell *)obj;
            }
        }
    }
    theCell = cell;

    AlarmDto *ree = [self rb_alarmForSection:indexPath.section];
    if ([self rb_isGroupNotifyAlarm:ree]) {
        [self rb_configureGroupNotifyEntryCell:cell];
        BOOL hideBottomSep = ([self rb_totalSectionCount] == 0) || (indexPath.section == [self rb_totalSectionCount] - 1);
        [cell rb_setHairlineBottomSeparatorHidden:hideBottomSep];
        return theCell;
    }
    if ([self rb_isArchivedEntryAlarm:ree]) {
        [self rb_configureArchivedEntryCell:cell];
        BOOL hideBottomSep = ([self rb_totalSectionCount] == 0) || (indexPath.section == [self rb_totalSectionCount] - 1);
        [cell rb_setHairlineBottomSeparatorHidden:hideBottomSep];
        return theCell;
    }
    if (ree == nil) return [[UITableViewCell alloc] init];
    // 是否已设置"消息免打扰"
    BOOL isSilent = [self isSilent:ree.alarmType dataId:ree.dataId];
    // 是否存在消息未读（YES = 没有未读）。flagNum 与 unreadCount 取较大值作为有效未读，避免一侧为 0、另一侧仍 >0 时出现「红色气泡里显示 0」或已读仍显示气泡。
    int unreadFlag = [BasicTool getIntValue:ree.flagNum defaultVal:0];
    if (unreadFlag < 0) unreadFlag = 0;
    int unreadSrv = (int)ree.unreadCount;
    if (unreadSrv < 0) unreadSrv = 0;
    int effectiveUnread = MAX(unreadFlag, unreadSrv);
    BOOL noUnread = (effectiveUnread <= 0);

    // 复用前先重置 textColor 和 attributedText，避免草稿红色样式泄漏到其它对话
    cell.viewMsgContent.textColor = HexColor(0x999b9f);
    cell.viewMsgContent.attributedText = nil;
    cell.viewIcon.backgroundColor = [UIColor clearColor];
    cell.viewIcon.contentMode = UIViewContentModeScaleAspectFill;
    cell.viewIcon.tintColor = nil;

    // 置顶对话背景加深，普通对话背景透明
    if(ree.alwaysTop) {
        cell.backgroundColor = HexColor(0xF0F0F0);
    } else {
        cell.backgroundColor = [UIColor clearColor];
    }

    // 利表格单元对应的数据对象对ui进行设置
    BOOL msgContentEmpty = (ree.alarmContent == nil);
    cell.viewTitle.text = ree.title;
    cell.viewDate.text = [TimeTool getTimeStringAutoShort2:ree.date mustIncludeTime:NO timeWithSegment:NO];//ree.date;
    UIFont *alarmsMsgFont = [BasicTool getSystemFontOfSize:kAlarmsCellMsgFontBase];
    UIColor *alarmsMsgColor = HexColor(0x999b9f);
    NSDictionary *alarmsMsgAttrs = @{
        NSForegroundColorAttributeName: alarmsMsgColor,
        NSFontAttributeName: alarmsMsgFont
    };
    cell.viewDate.hidden = NO;
//  cell.viewMsgContent.text = (msgContentEmpty ? @"No more messages" : ree.alarmContent);
    
    // 检查是否有草稿内容
    NSString *draftText = [self getDraftForAlarm:ree];
    if (draftText && draftText.length > 0) {
        // 如果有草稿，显示草稿（"草稿："前缀红色，内容正常颜色）
        // 先创建完整的草稿文本（包含表情处理）
        NSString *draftContent = [NSString stringWithFormat:@"草稿：%@", draftText];
        NSMutableAttributedString *draftAttributedString = [EmojiUtil replaceEmojiWithPlanString:draftContent attributes:alarmsMsgAttrs];
        
        // 只将"草稿："前缀设置为红色
        if (draftAttributedString) {
            NSString *prefix = @"草稿：";
            NSRange prefixRange = NSMakeRange(0, prefix.length);
            if (prefixRange.location + prefixRange.length <= draftAttributedString.length) {
                [draftAttributedString addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:prefixRange];
            }
        }
        
        cell.viewMsgContent.attributedText = draftAttributedString;
    } else if (!msgContentEmpty) {
        // 如果没有草稿，显示最后一条消息（正常颜色）
        cell.viewMsgContent.attributedText = [EmojiUtil replaceEmojiWithPlanString:ree.alarmContent attributes:alarmsMsgAttrs];
    } else {
        cell.viewMsgContent.text = @"No more messages";
    }
    
    
    // 未读消息数的显示
    if(noUnread) {
        cell.viewFlagNum2.hidden = YES;
        cell.viewFlagDot.hidden = YES;
    }
    else {
        // 免打扰与普通会话均显示数字气泡；免打扰时使用灰色气泡（红点与前缀「[xx条]」不再用于免打扰）
        UIColor *badgeRed = [UIColor colorWithRed:247.f/255.f green:76.f/255.f blue:49.f/255.f alpha:1.f];
        UIColor *badgeGray = HexColor(0xAEAEB2);
        if (isSilent) {
            [cell.viewFlagNum2 setBadgeBackgroundColor:badgeGray];
            [cell.viewFlagNum2 setBadgeTextColor:[UIColor whiteColor]];
        } else {
            [cell.viewFlagNum2 setBadgeBackgroundColor:badgeRed];
            [cell.viewFlagNum2 setBadgeTextColor:[UIColor whiteColor]];
        }
        [cell.viewFlagNum2 setBadgeValue:[NSString stringWithFormat:@"%d", effectiveUnread]];
        cell.viewFlagNum2.hidden = NO;
        cell.viewFlagDot.hidden = YES;
    }
    
    // 设置消息前缀的显示内容
    NSString *msgPrefix = @"";
    UIColor *msgPrefixColor = HexColor(0x999b9f);
    BOOL msgPrefixVisible = NO;
    BOOL atMePrefixInContent = NO; // 将“有@我的消息”拼进消息内容前缀，而不是单独左侧标签
    if([ree isAtMe]) {
        atMePrefixInContent = YES;
    }
    // TODO: 稍后实现草稿功能！（注：Jack建议草稿状态单独存放于其它途径，比如preference中，因草稿特性不属于消息本身，因而不应存放于消息记录中！）
//  else if([ree isHasDraft]) {
//      msgPrefixVisible = YES;
//      msgPrefixColor = HexColor(0xe9655f);
//      msgPrefix = @"[草稿]";
//  }
    cell.viewMsgPrefix.hidden = !msgPrefixVisible;
    cell.viewMsgPrefix_rightGapConstraint.constant = (cell.viewMsgPrefix.hidden ? 0 : 4);
    cell.viewMsgPrefix.text = cell.viewMsgPrefix.hidden ? nil : msgPrefix;
    cell.viewMsgPrefix.textColor = msgPrefixColor;

    // “有@我的消息”固定放在最前面，后面仍正常显示群聊消息内容
    if (atMePrefixInContent) {
        NSString *contentText = @"";
        if (draftText.length > 0) {
            contentText = [NSString stringWithFormat:@"草稿：%@", draftText];
        } else if (!msgContentEmpty) {
            contentText = ree.alarmContent ?: @"";
        }
        NSMutableAttributedString *prefixAndContent = [[NSMutableAttributedString alloc] initWithString:@"有@我的消息 "];
        [prefixAndContent addAttribute:NSForegroundColorAttributeName value:HexColor(0xe9655f) range:NSMakeRange(0, prefixAndContent.length)];
        [prefixAndContent addAttribute:NSFontAttributeName value:alarmsMsgFont range:NSMakeRange(0, prefixAndContent.length)];
        
        NSDictionary *normalAttrs = @{
            NSForegroundColorAttributeName: alarmsMsgColor,
            NSFontAttributeName: alarmsMsgFont
        };
        NSAttributedString *normalContent = [EmojiUtil replaceEmojiWithPlanString:contentText attributes:normalAttrs];
        if (normalContent != nil) {
            [prefixAndContent appendAttributedString:normalContent];
        } else {
            [prefixAndContent appendAttributedString:[[NSAttributedString alloc] initWithString:contentText attributes:normalAttrs]];
        }
        cell.viewMsgContent.attributedText = prefixAndContent;
        
        // @我场景不再使用左侧独立前缀，避免重复
        cell.viewMsgPrefix.hidden = YES;
        cell.viewMsgPrefix.text = nil;
        cell.viewMsgPrefix_rightGapConstraint.constant = 0;
    }


    // 【注意】以下代码解决在表格行处于选中状态时在XIB设置的UILabel的背景色会消失的问题
    cell.viewTitleLeftFlag.backgroundColor = [UIColor clearColor];
    cell.viewTitleLeftFlag.layer.backgroundColor = HexColor(0xFEA356).CGColor;

    // 置顶图标：仅「置顶且无未读」时显示；置顶且有未读时只显示右侧未读数/红点（与 AlarmsTableViewCell layoutSubviews 槽位一致）
    BOOL showAlarmsPinIcon = (ree.alwaysTop && noUnread);
    cell.viewAlwaystopIcon.hidden = !showAlarmsPinIcon;
    if (showAlarmsPinIcon && cell.viewAlwaystopIcon != nil) {
        // 资源名为 main_alarms_list_item_alwaytop（勿写成 alwaystop），否则 imageNamed 恒为 nil
        UIImage *pinImg = [UIImage imageNamed:@"main_alarms_list_item_alwaytop"];
        if (pinImg != nil) {
            cell.viewAlwaystopIcon.image = [pinImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            cell.viewAlwaystopIcon.tintColor = nil;
        } else {
            UIImage *sym = [UIImage systemImageNamed:@"pin.fill"];
            if (sym != nil) {
                cell.viewAlwaystopIcon.image = [sym imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                cell.viewAlwaystopIcon.tintColor = [UIColor labelColor];
            }
        }
    }
    [cell setNeedsLayout];
    {
        CGFloat secondRowGap = 3.0;
        if (cell.viewMsgContentTopFromTitleConstraint != nil) {
            cell.viewMsgContentTopFromTitleConstraint.constant = secondRowGap;
        }
        if (cell.viewMsgPrefixTopFromTitleConstraint != nil) {
            cell.viewMsgPrefixTopFromTitleConstraint.constant = secondRowGap;
        }
    }
    
    // 消息提示是否静音的图标显示（与昵称同一行，紧邻昵称右侧）
    cell.viewSilentIcon.hidden = (isSilent ? NO : YES);
    if (cell.viewSilentIconWidthConstraint != nil) {
        cell.viewSilentIconWidthConstraint.constant = isSilent ? 14.0 : 0.0;
    }
    if (cell.viewSilentIconLeadingConstraint != nil) {
        cell.viewSilentIconLeadingConstraint.constant = isSilent ? 4.0 : 0.0;
    }

    // 消息列表头像：48×48 圆形（与 AlarmsTableViewCell.xib 一致）
    cell.viewIcon.layer.cornerRadius = 24.f;
    cell.viewIcon.layer.masksToBounds = YES;

    // 以下代码用于设置要显示的图标
    BOOL needUserAvatar = NO;
    NSString *uidForUserAvatar = nil;
    NSString *fileNameForAvatar = nil;
    
    // 标题栏左、右边的标签默认是不需要显示的
    cell.viewTitleLeftFlagContainer_widthConstraint.constant = 0;
    cell.viewTitleRightFlagContainer_widthConstraint.constant = 0;
    
    if(ree.alarmType == AMT_addFriendBeReject)
    {
        [cell.viewIcon setImage:[UIImage imageNamed:@"main_alarms_sns_addfriendreject2r_message_icon"]];
    }
    // 正常的好友聊天消息
    else if(ree.alarmType == AMT_friendChatMessage)
    {
        NSString *friendUid = ree.dataId;
        // 先设定一个默认图标
        [cell.viewIcon setImage:[UIImage imageNamed:@"main_alarms_chat_message_icon"]];
        // 设置标题右标签的显示
        [self setupTitleRightFlagInTableView:ree.alarmType dataId:friendUid cell:cell];

        if(friendUid != nil)
        {
            UserEntity *friendRee = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:friendUid];
            if(friendRee != nil){
                fileNameForAvatar = friendRee.userAvatarFileName;
                // 优先使用好友列表中的昵称，确保首页"消息"列表中显示的好友聊天item标题能尽可能保持最新数据 @since 7.3
                NSString *friendNicknameWithRemark = [friendRee getNickNameWithRemark];
                if(![BasicTool isStringEmpty:[BasicTool trim:friendNicknameWithRemark]])
                    cell.viewTitle.text = friendNicknameWithRemark;
            }
            
            needUserAvatar = YES;
            uidForUserAvatar = friendUid;
        }
    }
    // 陌生人/临时聊天
    else if(ree.alarmType == AMT_guestChatMessage)
    {
        NSString *fromUid = ree.dataId;
        
        //** 自v10.2起，原陌生人标签ui及代码已废弃，日后将删除相关代码和逻辑
//        // 是系统通知账号，就不显示陌生人标签
//        if(![BasicTool isSystemAdmin:fromUid]) {
//            // 标题左边的"陌"标签显示（ 此值请与.xib里的设置保持一致哦（方便可视化调整ui时与代码保持一致））
//            cell.viewTitleLeftFlagContainer_widthConstraint.constant = 19;
//            cell.viewTitleLeftFlag.layer.cornerRadius = 3;
//            cell.viewTitleLeftFlag.layer.masksToBounds = YES;
//        }
        
        // 先设定一个默认图标（如果有头像的话接下来会在异步线程里更新掉的）
        [cell.viewIcon setImage:[UIImage imageNamed:@"main_alarms_tenpchat_message_icon"]];
        // 设置标题右标签的显示
        [self setupTitleRightFlagInTableView:ree.alarmType dataId:fromUid cell:cell];

        if(fromUid != nil){
            // 对于陌生人来说，extra1String中，存放的就是可能最新头像文件名（在查看最新用户资料时设置进来的）
            fileNameForAvatar = ree.extraString1;

            needUserAvatar = YES;
            uidForUserAvatar = fromUid;
        }
    }
    // 群组聊天
    else if(ree.alarmType == AMT_groupChatMessage)
    {
        // dataId中存放在就是群组id
        NSString *gid = ree.dataId;
        NSString *previousBoundGroupId = cell.rb_boundGroupId;
        BOOL keepCurrentGroupAvatar = (gid.length > 0 && [previousBoundGroupId isEqualToString:gid] && cell.viewIcon.image != nil);
        cell.rb_boundGroupId = gid;

        // 同一 gid 重绑时保留当前真实头像，避免 reloadData 后先回退默认群头像造成闪烁。
        if ([GroupEntity isWorldChat:gid]) {
            [cell.viewIcon setImage:[UIImage imageNamed:@"main_alarms_bbschat_message_icon"]];
        } else if (!keepCurrentGroupAvatar) {
            [cell.viewIcon setImage:[UIImage imageNamed:@"groupchat_groups_icon_default"]];
        }
        // 设置标题右标签的显示
        [self setupTitleRightFlagInTableView:ree.alarmType dataId:gid cell:cell];

        if(gid != nil && ![GroupEntity isWorldChat:gid])
        {
            // 尝试为群组加载群头像
            __weak AlarmsTableViewCell *weakCell = cell;
            [FileDownloadHelper loadGroupAvatar:gid logTag:@"AlarmsViewController"
                complete:^(BOOL sucess, UIImage *img) {
                    if (!sucess || img == nil) return;
                    void (^applyAvatar)(void) = ^{
                        AlarmsTableViewCell *c = weakCell;
                        if (c && [c.rb_boundGroupId isEqualToString:gid]) {
                            [c.viewIcon setImage:img];
                        }
                    };
                    if ([NSThread isMainThread]) {
                        applyAvatar();
                    } else {
                        dispatch_async(dispatch_get_main_queue(), applyAvatar);
                    }
            }];
        }
    }
    else if(ree.alarmType == AMT_addFriendRequest)
        [cell.viewIcon setImage:[UIImage imageNamed:@"main_alarms_sns_addfriendrequest_message_icon"]];
    else if(ree.alarmType == AMT_systemDevTeam)
    {
        [cell.viewIcon setImage:[UIImage imageNamed:@"main_alarms_sns_undefine_icon"]];
//      cell.viewDate.hidden = YES;
    }
    else if(ree.alarmType == AMT_systemQNA)
    {
        [cell.viewIcon setImage:[UIImage imageNamed:@"main_alarms_sns_undefine_icon"]];
//      cell.viewDate.hidden = YES;
    }
    else
        [cell.viewIcon setImage:[UIImage imageNamed:@"main_alarms_system_message_icon"]];

    // 按需载入用户头像：列表热路径只读内存缓存，磁盘回源放到后台，避免滚动时同步读盘。
    if (needUserAvatar && uidForUserAvatar != nil) {
        [RBAvatarView removeAvatarFromImageView:cell.viewIcon];
        NSString *avatarPath = [FileDownloadHelper getUserAvatarDownloadURLExt:![BasicTool isStringEmpty:fileNameForAvatar] fileName:fileNameForAvatar ?: @"" uid:uidForUserAvatar];
        UIImage *cached = [FileDownloadHelper getUserAvatarFromSDImageCache:avatarPath donotLoadFromDisk:YES];
        if (!cached && avatarPath.length > 0) {
            NSString *uidOnlyPath = [FileDownloadHelper getUserAvatarDownloadURLExt:NO fileName:nil uid:uidForUserAvatar];
            if (uidOnlyPath.length > 0 && ![uidOnlyPath isEqualToString:avatarPath])
                cached = [FileDownloadHelper getUserAvatarFromSDImageCache:uidOnlyPath donotLoadFromDisk:YES];
        }
        if (cached) {
            cell.viewIcon.image = cached;
        } else {
            UIImage *placeIcon = [UIImage imageNamed:@"default_avatar_60"];
            cell.viewIcon.image = placeIcon;
            UITableView *wTable = tableView;
            NSIndexPath *wPath = [indexPath copy];
            NSString *wFileName = [fileNameForAvatar copy];
            NSString *wUid = [uidForUserAvatar copy];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                [FileDownloadHelper loadUserAvatarIntelligent:wFileName uid:wUid logTag:@"AlarmsList" complete:^(BOOL succ, UIImage *img) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!img) return;
                        AlarmsTableViewCell *c = (AlarmsTableViewCell *)[wTable cellForRowAtIndexPath:wPath];
                        if (c) {
                            [RBAvatarView removeAvatarFromImageView:c.viewIcon];
                            c.viewIcon.image = img;
                        }
                    });
                } donotLoadFromDisk:NO];
            });
        }
    }

    [self rb_fetchProfileAndUpdateAlarmTitleIfNeeded:ree displayedTitle:cell.viewTitle.text];

    [self rb_applyAlarmsListCellTypography:cell];

    BOOL hideBottomSep = ([self rb_totalSectionCount] == 0) || (indexPath.section == [self rb_totalSectionCount] - 1);
    [cell rb_setHairlineBottomSeparatorHidden:hideBottomSep];

    return theCell;
}

// 设置表格单标题右标签的显示
- (void)setupTitleRightFlagInTableView:(int)alarmType dataId:(NSString *)did cell:(AlarmsTableViewCell *)c
{
    c.viewTitleRightFlag.hidden = NO;
    c.viewTitleRightFlagImageView.hidden = YES;
    c.viewTitleRightFlagImageView.transform = CGAffineTransformIdentity;

    // 是系统通知账号，就不显示陌生人标签
    if(alarmType == AMT_guestChatMessage || alarmType == AMT_friendChatMessage) {
        if([BasicTool isOfficialAccountShowFlagInConversationList:did]) {
            UIImage *officialFlagImage = [BasicTool officialBadgeImage];
            if (officialFlagImage != nil && officialFlagImage.size.height > 0.0f) {
                CGFloat flagWidth = ceil(20.0f * officialFlagImage.size.width / officialFlagImage.size.height);
                c.viewTitleRightFlagContainer_widthConstraint.constant = flagWidth;
                c.viewTitleRightFlag.hidden = YES;
                c.viewTitleRightFlagImageView.hidden = NO;
                c.viewTitleRightFlagImageView.image = officialFlagImage;
                c.viewTitleRightFlagImageView.transform = CGAffineTransformMakeScale(0.82f, 0.82f);
            } else {
                c.viewTitleRightFlagContainer_widthConstraint.constant = 48;
                c.viewTitleRightFlag.text = @"官方";
                c.viewTitleRightFlag.textColor = HexColor(0xa57c29);
                c.viewTitleRightFlag.backgroundColor = HexColor(0xf9f2dd);
                c.viewTitleRightFlagImageView.image = nil;
            }
        }
        else if(alarmType == AMT_guestChatMessage) {
            // 标题右边的标签显示（ 此值请与.xib里的设置保持一致哦（方便可视化调整ui时与代码保持一致））
            c.viewTitleRightFlagContainer_widthConstraint.constant = 48;
            c.viewTitleRightFlag.text = @"陌生";
            c.viewTitleRightFlag.textColor = HexColor(0xb9bbbf);
            c.viewTitleRightFlag.backgroundColor = HexColor(0xf3f5f9);
            c.viewTitleRightFlagImageView.image = nil;
        }
    }
    else if(alarmType == AMT_groupChatMessage && [GroupEntity isWorldChat:did]) {
        // 标题右边的标签显示（ 此值请与.xib里的设置保持一致哦（方便可视化调整ui时与代码保持一致））
        c.viewTitleRightFlagContainer_widthConstraint.constant = 48;
        c.viewTitleRightFlag.text = @"系统";
        c.viewTitleRightFlag.textColor = HexColor(0x007DFF);
        c.viewTitleRightFlag.backgroundColor = HexColor(0xddf2f9);
        c.viewTitleRightFlagImageView.image = nil;
    }
}


#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexP
// 点击表格行时要调用的方法
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.rb_archivedBatchEditing) {
        [self rb_updateArchivedBatchActionUI];
        return;
    }
    AlarmDto *amd = [self rb_alarmForSection:indexPath.section];
    if ([self rb_isArchivedEntryAlarm:amd]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        AlarmsViewController *vc = [[AlarmsViewController alloc] initWithNibName:@"AlarmsViewController" bundle:nil];
        vc.alarmFilterMode = self.alarmFilterMode;
        vc.showArchivedOnly = YES;
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if ([self rb_isGroupNotifyAlarm:amd]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self rb_markGroupNotifyEntryReadWithDate:self.rb_groupNotifyEntryLatestDate];
        [self refreshTable];
        GroupNotificationsViewController *vc = [[GroupNotificationsViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if(amd != nil)
    {
        // 是加好友的请求：进入好友请求处理页面中
        if(amd.alarmType == AMT_addFriendRequest)
        {
            // 进入好友请求列表管理界面
            [ViewControllerFactory goVerificationsViewController:self.navigationController];
        }
        // 陌生人/临时聊天消息查看
        else if(amd.alarmType == AMT_guestChatMessage)
        {
            NSString *fromUid = amd.dataId;
            NSString *fromNickname = amd.title;
            
            // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
            __weak typeof(self) safeSelf = self;
            
            // 如果这条陌生人聊天信息对应的人，已经是好友了，则先给于提示，并删除这条遗留的陌生人聊天记录后，自动进入正常的好友聊天界面
            if([[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster2:fromUid]) {
                // 显示一个信息提示对话框
                NSString *hintContent = [NSString stringWithFormat:@"\"%@\"已经是你的好友了，将自动删除遗留的陌生人聊天信息后进入好友聊天界面。", fromNickname];
                [BasicTool showAlert:NSLocalizedString(@"general_prompt", @"") content:hintContent btnTitle:NSLocalizedString(@"general_got_it", @"") parent:safeSelf handler:^(UIAlertAction *action) {
//                    // 从本界面的列表中数据删除此行遗留的陌生人聊天信息
//                    [[[IMClientManager sharedInstance] getAlarmsProvider] removeAlarm:(int)indexPath.section notify:YES deleteAlarmLocalData:YES deleteLocalData:NO];
                    
                    // 修改首页"消息"界面列表中的陌生聊天信息item为好友聊天
                    [[[IMClientManager sharedInstance] getAlarmsProvider] updateAlarmType:amd.alarmType dataId:amd.dataId newType:AMT_friendChatMessage needUpdateSqlite:YES];
                    
                    // 进入聊天界面
                    [AlarmsViewController gotoSingleChattingViewController:self.navigationController fromUid:fromUid fromNickname:fromNickname highlight:nil];
                }];
            } else {
                // 正常进入聊天界面
                [AlarmsViewController gotoSingleChattingViewController:self.navigationController fromUid:fromUid fromNickname:fromNickname highlight:nil];
            }
        }
        //收到聊天信息
        else if(amd.alarmType == AMT_friendChatMessage)
        {
            NSString *fromUid = amd.dataId;
            NSString *fromNickname = amd.title;

            // 删除好友后，会话列表中的历史单聊仍应保留，并继续进入正式单聊页。
            [AlarmsViewController gotoSingleChattingViewController:self.navigationController fromUid:fromUid fromNickname:fromNickname highlight:nil];

            //** 注意：目前重置首页“消息”、“好友”列表里的未读消息数是在聊天界面的代码里实现的，这样才是最准的！
        }
        else if(amd.alarmType == AMT_addFriendBeReject)
        {
            // 查询并查看该用户的最新信息
            if(amd.dataId != nil) {
                // 进入用户资料界面
                [QueryFriendInfoAsync gotoWatchUserInfo:amd.dataId withInfo:nil nav:self.navigationController view:self.view vc:self];
//              [QueryFriendInfoAsync doIt:NO mail:nil uid:amd.dataId hudParentView:self.view withNC:self.navigationController canOpenChat:YES];
            }
        }
        // 加好友请求在服务端处理时的各种出错信息提示（出错了总得告诉请求发起方，不然请求有没有成功处理？请求去哪了呢？）
        else if(amd.alarmType == AMT_addFriendThrowError)
        {
            [BasicTool showAlert:amd.title content:amd.alarmContent btnTitle:@"知道了" parent:self];
        }
        // 群聊消息
        else if(amd.alarmType == AMT_groupChatMessage)
        {
            NSString *gid = amd.dataId;
            NSString *gname = amd.title;

            NSString *log = [NSString stringWithFormat:@"gid=%@, gname=%@", gid, gname ];
            DDLogDebug(@"从首页点击进入群聊：%@", log);

            if(gid != nil && gname != nil)
                // 点此进入群聊界面（popToRootFirst:NO 避免多余 pop，从列表根进入时秒进）
                [ViewControllerFactory goGroupChattingViewController:self.navigationController gid:gid gname:gname animated:YES popToRootFirst:NO highlight:nil];
        }
        else if(amd.alarmType == AMT_systemDevTeam)
        {
            [APP showGuideView];
        }
        // 打开常见问题网页
        else if(amd.alarmType == AMT_systemQNA)
        {
            [ViewControllerFactory goWebViewController:[BasicTool isChineseSimple]?RBCHAT_QNA_CN_URL:RBCHAT_QNA_EN_URL
                                                 title:[BasicTool isChineseSimple]?@"常见问题":@"FAQ"
                                                 toNav:self.navigationController];
        }
        else
        {
            [APP showToastWarn:@"此\"消息\"类型尚未实现！"];
        }
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    (void)indexPath;
    if (self.rb_archivedBatchEditing) {
        [self rb_updateArchivedBatchActionUI];
    }
}

#pragma mark - UITableViewDataSourcePrefetching（滚动时预取即将出现的会话消息，进一步保证秒进）

- (void)tableView:(UITableView *)tableView prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    NSArray<AlarmDto *> *alarms = self.filteredAlarms;
    if (!alarms.count) return;
    MessagesProvider *mp = [[IMClientManager sharedInstance] getMessagesProvider];
    GroupsMessagesProvider *gmp = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
    for (NSIndexPath *ip in indexPaths) {
        NSInteger alarmIndex = [self rb_alarmIndexForSection:ip.section];
        if (alarmIndex == NSNotFound || alarmIndex >= (NSInteger)alarms.count) continue;
        AlarmDto *alarm = alarms[alarmIndex];
        if ([self rb_isGroupNotifyAlarm:alarm] || [self rb_isArchivedEntryAlarm:alarm]) continue;
        if ([BasicTool isStringEmpty:alarm.dataId]) continue;
        if (alarm.alarmType == AMT_friendChatMessage || alarm.alarmType == AMT_guestChatMessage) {
            (void)[mp getMessages:alarm.dataId];
        } else if (alarm.alarmType == AMT_groupChatMessage) {
            (void)[gmp getMessages:alarm.dataId];
        }
    }
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"删除";
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0))
{
    AlarmDto *willEdit = [self rb_alarmForSection:indexPath.section];
    if (willEdit == nil || [self rb_isGroupNotifyAlarm:willEdit] || [self rb_isArchivedEntryAlarm:willEdit]) {
        UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[]];
        config.performsFirstActionWithFullSwipe = NO;
        return config;
    }

    BOOL supportsArchive = (willEdit.alarmType == AMT_groupChatMessage
                            || willEdit.alarmType == AMT_friendChatMessage
                            || willEdit.alarmType == AMT_guestChatMessage);
    if (!supportsArchive) {
        UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[]];
        config.performsFirstActionWithFullSwipe = NO;
        return config;
    }

    __weak typeof(self) safeSelf = self;
    __weak UITableView *wTable = tableView;
    NSString *archiveTitle = willEdit.archived ? @"取消归档" : @"归档";
    UIContextualAction *archiveAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:archiveTitle handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        completionHandler(YES);
        UITableView *t = wTable;
        if (t) [t setEditing:NO animated:NO];
        [[[IMClientManager sharedInstance] getAlarmsProvider] setArchived:willEdit.archived ? NO : YES amd:willEdit];
        safeSelf.swipeMenuVisible = NO;
        [safeSelf refreshTable];
        [safeSelf refreshUnreadNumOnTitle];
    }];
    archiveAction.backgroundColor = HexColor(0x7b61ff);

    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[archiveAction]];
    config.performsFirstActionWithFullSwipe = NO;
    return config;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (@available(iOS 11.0, *)) {
        AlarmDto *willEdit = [self rb_alarmForSection:indexPath.section];
        if (willEdit == nil) {
            UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[]];
            config.performsFirstActionWithFullSwipe = NO;
            return config;
        }
        __weak typeof(self) safeSelf = self;
        __weak UITableView *wTable = tableView;
        BOOL isGroupNotifyAlarm = [self rb_isGroupNotifyAlarm:willEdit];
        BOOL isArchivedEntryAlarm = [self rb_isArchivedEntryAlarm:willEdit];
        if (isArchivedEntryAlarm) {
            UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[]];
            config.performsFirstActionWithFullSwipe = NO;
            return config;
        }
        
        UIContextualAction *alwaystopAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:(willEdit.alwaysTop ? @"取消置顶" : @"置顶") handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            completionHandler(YES);
            UITableView *t = wTable;
            if (t) [t setEditing:NO animated:NO];
            if (isGroupNotifyAlarm) {
                [safeSelf rb_setGroupNotifyEntryAlwaysTop:willEdit.alwaysTop ? NO : YES];
            } else {
                [[[IMClientManager sharedInstance] getAlarmsProvider] setAlwaysTop:willEdit.alwaysTop ? NO : YES amd:willEdit];
            }
            safeSelf.swipeMenuVisible = NO;
            [safeSelf refreshTable];
            [safeSelf refreshUnreadNumOnTitle];
            if (!willEdit.alwaysTop && safeSelf.filteredAlarms.count > 0) {
                NSIndexPath *topPath = [NSIndexPath indexPathForRow:0 inSection:[safeSelf rb_firstAlarmSection]];
                [safeSelf.tableView scrollToRowAtIndexPath:topPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
            }
        }];
        
        if (isGroupNotifyAlarm) {
            UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[alwaystopAction]];
            config.performsFirstActionWithFullSwipe = NO;
            return config;
        }

        BOOL previousToneOpen = [UserDefaultsToolKits isChatMsgToneOpen:willEdit.dataId];
        BOOL targetMuteOn = previousToneOpen;
        NSString *muteTitle = targetMuteOn ? @"免打扰" : @"关闭免打扰";
        UIContextualAction *muteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:muteTitle handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            completionHandler(YES);
            UITableView *t = wTable;
            if (t) [t setEditing:NO animated:NO];
            NSString *luid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
            if ([BasicTool isStringEmpty:luid]) {
                safeSelf.swipeMenuVisible = NO;
                [APP showToastWarn:@"未登录"];
                return;
            }
            NSString *chatTypeStr = @"0";
            if (willEdit.alarmType == AMT_guestChatMessage) {
                chatTypeStr = @"1";
            } else if (willEdit.alarmType == AMT_groupChatMessage) {
                chatTypeStr = @"2";
            }
            [UserDefaultsToolKits setChatMsgToneOpen:!targetMuteOn chatId:willEdit.dataId];
            safeSelf.swipeMenuVisible = NO;
            [safeSelf refreshTable];
            [[HttpRestHelper sharedInstance] submitConversationMsgMuteToServer:luid partnerId:willEdit.dataId chatType:chatTypeStr muteOn:targetMuteOn complete:^(BOOL sucess, NSString *resultCode) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!sucess) {
                        [UserDefaultsToolKits setChatMsgToneOpen:previousToneOpen chatId:willEdit.dataId];
                        [safeSelf refreshTable];
                        [APP showToastWarn:@"免打扰设置同步失败"];
                    }
                });
            } hudParentView:nil];
        }];
        muteAction.backgroundColor = HexColor(0xfc9b27);
        
        UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            completionHandler(YES);
            UITableView *t = wTable;
            if (t) [t setEditing:NO animated:YES];
            if([AlarmsProvider isSystemDefineAlarm:willEdit.alarmType dataId:willEdit.dataId]) {
                [APP showToastInfo:@"这是系统消息，无法删除！"];
                return;
            }
            NSString *luid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
            BOOL isChatAlarm = (willEdit.alarmType == AMT_friendChatMessage
                                || willEdit.alarmType == AMT_guestChatMessage
                                || willEdit.alarmType == AMT_groupChatMessage);
            if (isChatAlarm && ![BasicTool isStringEmpty:luid]) {
                NSString *ruid = nil;
                NSString *gid = nil;
                if (willEdit.alarmType == AMT_groupChatMessage) {
                    gid = willEdit.dataId;
                } else {
                    ruid = willEdit.dataId;
                }
                [[HttpRestHelper sharedInstance] submitDeleteConversationToServer:luid ruid:ruid gid:gid complete:^(BOOL sucess, NSString *resultCode) {
                    if (!sucess) {
                        DDLogWarn(@"【会话删除】服务端软删除接口调用失败，仍继续本地删除。dataId=%@", willEdit.dataId);
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        int originalIndex = [[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmIndex:willEdit.alarmType dataId:willEdit.dataId];
                        if (originalIndex != -1)
                            [[[IMClientManager sharedInstance] getAlarmsProvider] removeAlarm:originalIndex notify:YES];
                    });
                } hudParentView:nil];
            } else {
                int originalIndex = [[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmIndex:willEdit.alarmType dataId:willEdit.dataId];
                if (originalIndex != -1)
                    [[[IMClientManager sharedInstance] getAlarmsProvider] removeAlarm:originalIndex notify:YES];
            }
        }];
        deleteAction.backgroundColor = HexColor(0xfb3d3a);
        
        UISwipeActionsConfiguration *config = nil;
        if(willEdit.alarmType == AMT_groupChatMessage || willEdit.alarmType == AMT_friendChatMessage || willEdit.alarmType == AMT_guestChatMessage) {
            config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, muteAction, alwaystopAction]];
        } else if(willEdit.alarmType == AMT_addFriendRequest) {
            config = [UISwipeActionsConfiguration configurationWithActions:@[]];
        } else {
            config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
        }
        config.performsFirstActionWithFullSwipe = NO;
        return config;
    }
    return nil;
}

// 实现左滑菜单功能（支持多个菜单项）
- (NSArray*)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    AlarmDto *willEdit = [self rb_alarmForSection:indexPath.section];

    if(willEdit == nil)
        return [NSArray array];

    BOOL isGroupNotifyAlarm = [self rb_isGroupNotifyAlarm:willEdit];
    if ([self rb_isArchivedEntryAlarm:willEdit]) {
        return @[];
    }

    // 设置置顶或取消置顶功能
    UITableViewRowAction *alwaystopAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:(willEdit.alwaysTop?@"取消置顶":@"置顶") handler:^(UITableViewRowAction *action, NSIndexPath *indexPath)
                                          {
                                              // animated:NO 更快收起左滑，避免等系统动画结束 didEndEditing 才刷表
                                              [tableView setEditing:NO animated:NO];
                                              if (isGroupNotifyAlarm) {
                                                  [self rb_setGroupNotifyEntryAlwaysTop:willEdit.alwaysTop?NO:YES];
                                              } else {
                                                  [[[IMClientManager sharedInstance] getAlarmsProvider] setAlwaysTop:willEdit.alwaysTop?NO:YES amd:willEdit];
                                              }
                                              // willBeginEditing 把 swipeMenuVisible 置 YES，在 didEndEditing 之前 refreshTable 会一直 return，置顶要等很久才重排
                                              self.swipeMenuVisible = NO;
                                              [self refreshTable];
                                              [self refreshUnreadNumOnTitle];
                                              // 本次为「置顶」时立刻滚到列表顶，否则仍保留原 offset，体感像「没到顶部」
                                              if (!willEdit.alwaysTop && self.filteredAlarms.count > 0) {
                                                  NSIndexPath *topPath = [NSIndexPath indexPathForRow:0 inSection:[self rb_firstAlarmSection]];
                                                  [self.tableView scrollToRowAtIndexPath:topPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
                                              }
                                          }];
    if (isGroupNotifyAlarm) {
        return @[alwaystopAction];
    }

    BOOL supportsArchive = (willEdit.alarmType == AMT_groupChatMessage
                            || willEdit.alarmType == AMT_friendChatMessage
                            || willEdit.alarmType == AMT_guestChatMessage);
    UITableViewRowAction *archiveAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:(willEdit.archived ? @"取消归档" : @"归档") handler:^(UITableViewRowAction *action, NSIndexPath *indexPath)
                                           {
                                               (void)action;
                                               (void)indexPath;
                                               [tableView setEditing:NO animated:NO];
                                               [[[IMClientManager sharedInstance] getAlarmsProvider] setArchived:willEdit.archived ? NO : YES amd:willEdit];
                                               self.swipeMenuVisible = NO;
                                               [self refreshTable];
                                               [self refreshUnreadNumOnTitle];
                                           }];
    archiveAction.backgroundColor = HexColor(0x7b61ff);

    // 消息免打扰 / 关闭免打扰（1008-4-38；本地与 ChatInfo/GroupInfo 共用 UserDefaultsToolKits）
    BOOL previousToneOpen = [UserDefaultsToolKits isChatMsgToneOpen:willEdit.dataId];
    BOOL targetMuteOn = previousToneOpen;
    NSString *muteTitle = targetMuteOn ? @"免打扰" : @"关闭免打扰";
    UITableViewRowAction *muteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:muteTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath)
                                        {
                                            [tableView setEditing:NO animated:NO];
                                            NSString *luid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
                                            if ([BasicTool isStringEmpty:luid]) {
                                                self.swipeMenuVisible = NO;
                                                [APP showToastWarn:@"未登录"];
                                                return;
                                            }
                                            NSString *chatTypeStr = @"0";
                                            if (willEdit.alarmType == AMT_guestChatMessage) {
                                                chatTypeStr = @"1";
                                            } else if (willEdit.alarmType == AMT_groupChatMessage) {
                                                chatTypeStr = @"2";
                                            }
                                            [UserDefaultsToolKits setChatMsgToneOpen:!targetMuteOn chatId:willEdit.dataId];
                                            self.swipeMenuVisible = NO;
                                            [self refreshTable];
                                            __weak typeof(self) safeSelf = self;
                                            [[HttpRestHelper sharedInstance] submitConversationMsgMuteToServer:luid partnerId:willEdit.dataId chatType:chatTypeStr muteOn:targetMuteOn complete:^(BOOL sucess, NSString *resultCode) {
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    if (!sucess) {
                                                        [UserDefaultsToolKits setChatMsgToneOpen:previousToneOpen chatId:willEdit.dataId];
                                                        [safeSelf refreshTable];
                                                        [APP showToastWarn:@"免打扰设置同步失败"];
                                                    }
                                                });
                                            } hudParentView:nil];
                                        }];
    muteAction.backgroundColor = HexColor(0xfc9b27);

    // 删除功能（v11.x 变更：先调用服务端 1008-4-22 软删除接口，再执行本地删除）
    UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"删除" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
                                            [tableView setEditing:NO animated:YES];  // 这句很重要，退出编辑模式，隐藏左滑菜单

                                             // 系统预定义"消息"无法删除提示
                                            if([AlarmsProvider isSystemDefineAlarm:willEdit.alarmType dataId:willEdit.dataId])
                                            {
                                                [APP showToastInfo:@"这是系统消息，无法删除！"];
                                                return;
                                            }

                                            // ① 判断是否是聊天类型会话，若是则先调用服务端软删除
                                            NSString *luid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
                                            BOOL isChatAlarm = (willEdit.alarmType == AMT_friendChatMessage
                                                                || willEdit.alarmType == AMT_guestChatMessage
                                                                || willEdit.alarmType == AMT_groupChatMessage);

                                            if (isChatAlarm && ![BasicTool isStringEmpty:luid]) {
                                                NSString *ruid = nil;
                                                NSString *gid = nil;
                                                if (willEdit.alarmType == AMT_groupChatMessage) {
                                                    gid = willEdit.dataId;
                                                } else {
                                                    ruid = willEdit.dataId;
                                                }

                                                // 调用服务端 1008-4-22 软删除
                                                [[HttpRestHelper sharedInstance] submitDeleteConversationToServer:luid
                                                                                                            ruid:ruid
                                                                                                             gid:gid
                                                                                                        complete:^(BOOL sucess, NSString *resultCode) {
                                                    if (!sucess) {
                                                        DDLogWarn(@"【会话删除】服务端软删除接口调用失败，仍继续本地删除。dataId=%@", willEdit.dataId);
                                                    }
                                                    // ② 回到主线程执行本地删除
                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                            int originalIndex = [[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmIndex:willEdit.alarmType dataId:willEdit.dataId];
                                            if (originalIndex != -1)
                                                [[[IMClientManager sharedInstance] getAlarmsProvider] removeAlarm:originalIndex notify:YES];
                                                    });
                                                } hudParentView:nil];
                                            }
                                            // 非聊天类型会话，直接本地删除
                                            else {
                                                int originalIndex = [[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmIndex:willEdit.alarmType dataId:willEdit.dataId];
                                                if (originalIndex != -1)
                                                    [[[IMClientManager sharedInstance] getAlarmsProvider] removeAlarm:originalIndex notify:YES];
                                            }
                                        }];
    deleteAction.backgroundColor = HexColor(0xfb3d3a);

    if(willEdit.alarmType == AMT_groupChatMessage || willEdit.alarmType == AMT_friendChatMessage || willEdit.alarmType == AMT_guestChatMessage)
    {
        return @[deleteAction, muteAction, alwaystopAction, archiveAction];
    } else if(willEdit.alarmType == AMT_addFriendRequest) {
        return @[];
    } else {
        return @[deleteAction];
    }
}


#pragma mark - 其它方法

// 【暂时禁用】世界频道功能
- (IBAction)clickGotoBBSChatting:(id)sender
{
    // 世界频道功能暂时禁用
//    [self.bbsAlarmUIWrapper gotoBBSChatting];
}

// 重建过滤后的消息列表（根据过滤模式过滤）
- (void)rebuildFilteredAlarms
{
    NSArray *dataList = [[[[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmsData] getDataList] copy];
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:dataList.count];
    for (AlarmDto *amd in dataList) {
        // 排除世界频道的群聊消息
        if (amd.alarmType == AMT_groupChatMessage && [GroupEntity isWorldChat:amd.dataId])
            continue;
        // 排除 10001 系统账号
        if ([@"10001" isEqualToString:amd.dataId])
            continue;
        // 列表中不显示确认提醒（加好友请求）
        if (amd.alarmType == AMT_addFriendRequest)
            continue;

        BOOL isChatAlarm = (amd.alarmType == AMT_friendChatMessage
                            || amd.alarmType == AMT_guestChatMessage
                            || amd.alarmType == AMT_groupChatMessage);
        if (self.showArchivedOnly) {
            if (!isChatAlarm || !amd.archived)
                continue;
        } else {
            if (amd.archived)
                continue;
        }
        
        // 根据过滤模式过滤
        if (self.alarmFilterMode == ALARM_FILTER_PRIVATE) {
            // 私聊模式：排除群聊消息
            if (amd.alarmType == AMT_groupChatMessage)
                continue;
        } else if (self.alarmFilterMode == ALARM_FILTER_GROUP) {
            // 群聊模式：只保留群聊消息
            if (amd.alarmType != AMT_groupChatMessage)
                continue;
        }
        
        [filtered addObject:amd];
    }
    AlarmDto *groupNotifyAlarm = self.showArchivedOnly ? nil : [self rb_buildGroupNotifyVirtualAlarm];
    if (groupNotifyAlarm != nil) {
        [filtered addObject:groupNotifyAlarm];
    }

    // 分离置顶、有草稿的非置顶、无草稿的非置顶对话
    AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
    NSMutableArray *pinnedItems = [NSMutableArray array];
    NSMutableArray *draftItems = [NSMutableArray array];
    NSMutableArray *normalItems = [NSMutableArray array];
    for (AlarmDto *amd in filtered) {
        if (amd.alwaysTop) {
            [pinnedItems addObject:amd];
        } else {
            // 仅判断是否存在草稿（hasDraft），避免每条会话 getDraftForAlarm 分配字符串并 trim（列表很长时减压主线程）
            if (![self rb_isGroupNotifyAlarm:amd] && ![self rb_isArchivedEntryAlarm:amd] && [ap hasDraftForAlarm:amd]) {
                [draftItems addObject:amd];
            } else {
                [normalItems addObject:amd];
            }
        }
    }
    
    if (self.alarmFilterMode == ALARM_FILTER_GROUP) {
        // 群聊列表模式：置顶对话按群名称字母排序，非置顶按时间排列
        [pinnedItems sortUsingComparator:^NSComparisonResult(AlarmDto *a, AlarmDto *b) {
            NSString *nameA = a.title ?: @"";
            NSString *nameB = b.title ?: @"";
            return [nameA localizedCaseInsensitiveCompare:nameB];
        }];
        // 有草稿的非置顶也按群名称字母排序
        [draftItems sortUsingComparator:^NSComparisonResult(AlarmDto *a, AlarmDto *b) {
            NSString *nameA = a.title ?: @"";
            NSString *nameB = b.title ?: @"";
            return [nameA localizedCaseInsensitiveCompare:nameB];
        }];
    } else {
        // 消息列表模式（私聊/全部）：置顶对话按最新消息时间排列（最新的在前面）
        [pinnedItems sortUsingComparator:^NSComparisonResult(AlarmDto *a, AlarmDto *b) {
            // date 是字符串格式的时间戳，按降序排列（最新的在前面）
            return [b.date compare:a.date];
        }];
        // 有草稿的非置顶也按最新消息时间排列（最新的在前面）
        [draftItems sortUsingComparator:^NSComparisonResult(AlarmDto *a, AlarmDto *b) {
            return [b.date compare:a.date];
        }];
        // 普通消息列表也按时间统一排序，确保虚拟的群通知会话与真实会话一起参与时间重排。
        [normalItems sortUsingComparator:^NSComparisonResult(AlarmDto *a, AlarmDto *b) {
            return [b.date compare:a.date];
        }];
    }
    
    // 合并：置顶在前，有草稿的非置顶在中间，无草稿的非置顶在后（非置顶已由 AlarmsProvider 按时间排好）
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:filtered.count];
    AlarmDto *archivedEntryAlarm = [self rb_buildArchivedVirtualAlarm];
    if (archivedEntryAlarm != nil) {
        [result addObject:archivedEntryAlarm];
    }
    [result addObjectsFromArray:pinnedItems];
    [result addObjectsFromArray:draftItems];
    [result addObjectsFromArray:normalItems];
    filtered = result;
    
    self.filteredAlarms = filtered;
}

/// 与 UITableView 实际可滚动的最大 `contentOffset.y` 一致，需包含 `adjustedContentInset`（如底部 Tab/Fab 的 `contentInset.bottom`），
/// 否则少算 `maxY` 会在 `MIN(savedY, maxY)` 时把接近底部的位置误钳成小偏移，表现为「在底部一刷新就回顶」。
- (CGFloat)rb_tableMaxContentOffsetY
{
    UITableView *tv = self.tableView;
    if (!tv) return 0;
    UIEdgeInsets ai = tv.adjustedContentInset;
    CGFloat maxY = tv.contentSize.height - tv.bounds.size.height + ai.bottom;
    CGFloat minY = -ai.top;
    if (maxY < minY) {
        return minY;
    }
    return maxY;
}

/// 用户是否停在本可滚动列表的底部附近（用于全量 reload 后维持「在底部看老会话」而不是被误夹到顶）
- (BOOL)rb_tableOffsetWasNearBottom:(CGPoint)offset tolerance:(CGFloat)tolerance
{
    CGFloat maxY = [self rb_tableMaxContentOffsetY];
    if (maxY <= 0) {
        return NO;
    }
    return offset.y >= maxY - tolerance;
}

- (void)rb_updateEmptyStateForCurrentFilteredAlarms
{
    if (self.rb_emptyStartConversationButton != nil) {
        self.rb_emptyStartConversationButton.hidden = self.showArchivedOnly;
    }

    BOOL skeletonCovering = NO;
    BOOL hasVisibleSections = ([self rb_totalSectionCount] > 0);

    // 刷新表格有数据与无数据时的UI显示（使用过滤后的数据）
    if(hasVisibleSections)
    {
        self.tableView.hidden = NO;
        self.layoutTableEmptyHint.hidden = YES;
    }
    else
    {
        if (skeletonCovering) {
            self.tableView.hidden = NO;
            self.layoutTableEmptyHint.hidden = YES;
        } else {
            self.tableView.hidden = YES;
            self.layoutTableEmptyHint.hidden = NO;
        }
    }
}

- (void)rb_refreshTableAllowOffscreenReload:(BOOL)allowOffscreenReload reason:(NSString *)reason
{
    // 无条件重置 dirty 标志：防止上一次调用因 window==nil early return 时留下的 tableDirty=YES
    // 阻塞后续刷新。例如：数据变化时 scheduleRefreshTable → refreshTable(window=nil) → tableDirty=YES；
    // 之后 viewWillAppear 的 scheduleRefreshTable cancel 旧 timer → 新 timer → 再次 early return，
    // tableDirty 永远是 YES，列表永远不刷新。加这一行后，每次 refreshTable 调用都从干净状态开始。
    self.tableDirty = NO;
    // 与 scheduleRefreshTable 的 0.5s 防抖协调：任何一次全量刷新都取消未触发的定时器，避免 didEndEditing/主路径已 reload 后 0.5s 再全表刷一次（置顶、已读等左滑操作会因此「顿一下」或双次重排）
    if (self.refreshTableDebounceSource) {
        dispatch_source_cancel(self.refreshTableDebounceSource);
        self.refreshTableDebounceSource = nil;
        self.refreshTableScheduled = NO;
    }
    // 左滑菜单打开时，禁止刷新以保持操作菜单状态
    if (self.swipeMenuVisible || self.tableView.isEditing) {
        self.tableDirty = YES;
        return;
    }
    
    // 先重建过滤后的数据（未进 window 的 VC 也更新内存，切 Tab 时数据已就绪）
    [self rebuildFilteredAlarms];
    // 预热返回首帧时，即使尚未进 window，也要先把 table 的 section/row 数据源切到最新顺序；
    // 避免 pop 动画露出底层真实 toVC.view 时仍看到上一次绘制的旧 cell 排列。
    if (!self.tableView.window) {
        if (allowOffscreenReload) {
            [UIView performWithoutAnimation:^{
                [self.tableView reloadData];
            }];
            [self rb_updateEmptyStateForCurrentFilteredAlarms];
            [self rb_updateArchivedBatchActionUI];
            self.tableDirty = NO;
        } else {
            self.tableDirty = YES;
        }
        return;
    }
    
    // 保存当前滚动位置，reload 后恢复，避免列表跳动
    CGPoint savedOffset = self.tableView.contentOffset;
    static const CGFloat kAlarmsScrollBottomPinTolerance = 40.0f;
    BOOL pinToBottom = [self rb_tableOffsetWasNearBottom:savedOffset tolerance:kAlarmsScrollBottomPinTolerance];
    
    [self.tableView reloadData];

    // 首屏头像在后台解码后刷新可见行，避免主线程被读盘+解码阻塞
    [self rb_preloadFirstScreenAvatarsAsync];
    
    // 恢复滚动位置（须按 adjustedContentInset 计算最大偏移；在底部时钉住底部，避免 reload 瞬间 contentSize 偏小时被夹到 0）
    [self.tableView layoutIfNeeded];
    UIEdgeInsets ai = self.tableView.adjustedContentInset;
    CGFloat minY = -ai.top;
    CGFloat maxY = [self rb_tableMaxContentOffsetY];
    CGFloat targetY;
    if (pinToBottom) {
        targetY = maxY;
    } else {
        targetY = MIN(MAX(savedOffset.y, minY), maxY);
    }
    self.tableView.contentOffset = CGPointMake(savedOffset.x, targetY);
    // reload 后偶发下一帧 contentSize 才涨满，仅在「原在底部」时再钉一次底，避免仍被夹成较小 offset
    if (pinToBottom) {
        __weak typeof(self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (!sself || !sself.tableView.window) return;
            [sself.tableView layoutIfNeeded];
            CGFloat maxY2 = [sself rb_tableMaxContentOffsetY];
            CGPoint cur = sself.tableView.contentOffset;
            sself.tableView.contentOffset = CGPointMake(cur.x, maxY2);
        });
    }
#if DEBUG
    DDLogDebug(@"【首页[消息]界面】列表数据刷新了哦！！");
#endif

    [self rb_updateEmptyStateForCurrentFilteredAlarms];
    [self rb_updateArchivedBatchActionUI];

    self.tableDirty = NO;
}

// 刷新列表数据显示
- (void)refreshTable
{
    [self rb_refreshTableAllowOffscreenReload:NO reason:@"default"];
}

// 点击标题导航栏右边“+”按钮的事件处理（自定义导航右栏添加按钮）
- (void)doMores:(id)sender
{
    __weak typeof(self) safeSelf = self;
    NSArray *imageArr = @[@"main_alarms_floatmenu_adduser", @"main_alarms_floatmenu_addgroup", @"main_alarms_floatmenu_scan"];
    NSArray *titleArr = @[@"添加好友", @"创建群聊", @"扫一扫"];
    UIBarButtonItem *item = [sender isKindOfClass:[UIView class]] ? [[UIBarButtonItem alloc] initWithCustomView:(UIView *)sender] : nil;
    if (!item) return;
    [item xy_showMenuWithImages:imageArr titles:titleArr menuType:XYMenuRightNavBar currentNavVC:self.navigationController withItemClickIndex:^(NSInteger index) {
        if (index == 1) {
            [ViewControllerFactory goFindFriendViewController:self.navigationController];
        } else if (index == 2) {
            [ViewControllerFactory goGroupMemberViewController:self.navigationController usedFor:USED_FOR_CREATE_GROUP gid:nil isGroupOwner:YES defaultSelectedUid:nil];
        } else if (index == 3) {
            [QRCodeScheme gotoQrCodeScan:safeSelf.navigationController scanComplete:^(NSString *qrResult) {
                DLogDebug(@"%@", [NSString stringWithFormat:@"2维码扫描的结果是：%@", qrResult]);
                [QRCodeScheme processQRCodeScanResult:qrResult nav:safeSelf.navigationController view:safeSelf.view vc:safeSelf];
            }];
        }
    }];
}

// 点击标题导航栏右边“搜索”按钮的事件处理（自定义导航右栏搜索按钮）
- (void)doSearch:(id)sender
{
    [ViewControllerFactory goSearchViewController:self.navigationController supportedSearchableContens:@[[[FriendsContent alloc] init], [[GroupsContent alloc] init], [[MsgSummaryContent alloc] init]] keyword:nil showAllResult:NO];
}

// 刷新网络状态的ui显示
- (void)refreshNetworkStatusShow
{
    // 网络状态通过导航栏标题体现（断网时显示"连接中..."，正常时显示"消息"）
    [self refreshUnreadNumOnTitle];
    
    // 隐藏旧的XIB中的断网提示UI（低于iOS 26时）
    if (!(@available(iOS 26, *))) {
        [self showNetbadHintLayout:NO];
    }
}

// 显示网络不可用时的提示ui，当前用于低于ios 26的系统中（已废弃，保留仅用于隐藏XIB中的旧UI）
- (void)showNetbadHintLayout:(BOOL)show
{
    // 组件的可见性是通过控制高度约束来实现的，这种方式能让列表的Y轴显示位置自动适应于本组件的显示
    if(show)
        self.heightConstraintOfLayoutNetbadHint.constant = 41;// 此高度值与xib中的高度一致即可！
    else
        self.heightConstraintOfLayoutNetbadHint.constant = 0;
}

// 尝试从图片缓存中清除指定群组的头像缓存（以便下次刷新列表时能及时显示最新的群头像）.
- (void) clearGroupAvatarCache:(NSNotification*)notification
{
    NSString *gid = (NSString *)notification.object;
    DDLogDebug(@"【首页\"消息\"界面】-收到重置群组%@头像缓存的通知！", gid);
    if(gid != nil)
        [FileDownloadHelper clearGroupAvatarCache:gid];
}

// 左侧为「消息」/「群聊」；未连接时在同位置显示「加载中...」。中间不设未读汇总（会话行气泡与 Tab 角标仍保留）
- (void)refreshUnreadNumOnTitle
{
    self.navigationItem.title = @"";

    NSString *leftTabKey = @"main_tabs_title_alarm";
    if (self.showArchivedOnly) {
        leftTabKey = nil;
    } else if (self.alarmFilterMode == ALARM_FILTER_GROUP) {
        leftTabKey = @"main_tabs_title_group";
    }
    NSString *defaultLeftTitle = self.showArchivedOnly ? @"已归档" : NSLocalizedString(leftTabKey, @"");

    if (!self.showArchivedOnly && ![ClientCoreSDK sharedInstance].connectedToServer) {
        if (self.rb_customNavLeftTitleLabel) self.rb_customNavLeftTitleLabel.text = @"加载中...";
        if (self.rb_customNavTitleLabel) self.rb_customNavTitleLabel.text = @"";
        return;
    }

    if (self.rb_customNavLeftTitleLabel) self.rb_customNavLeftTitleLabel.text = defaultLeftTitle;
    if (self.rb_customNavTitleLabel) self.rb_customNavTitleLabel.text = @"";
    [self rb_updateArchivedBatchActionUI];
}

// 别的界面中对好友备注等信息更新完后，本界面中要做的事，这是通过通知实现的
- (void)friendRemarkChangedComplete:(NSNotification*)notification
{
    UserEntity *latestRee = (UserEntity *)notification.object;
    
    NSString *friendUid = latestRee.user_uid;
    NSString *friendNicknameWithRemark = [latestRee getNickNameWithRemark];
    DDLogDebug(@"【好友备注更新】首页[消息]收到 (friendUid=%@，friendNicknameWithRemark=%@) 已修改完成的通知！", friendUid, friendNicknameWithRemark);
    
    // 当列表中存在该好友的item时才刷新（不要浪费性能嘛）
    if([[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmIndex:AMT_friendChatMessage dataId:friendUid] != -1) {
        // 🆕 使用节流版刷新
        [self scheduleRefreshTable];
        DDLogInfo(@"【好友备注更新】当前alarms列表item ui显示刷新成功！");
    }
}

/**
 * 是否设置"消息免打扰"。
 *
 * @param alarmType 聊天item类型
 * @param dataId id
 * @return true表示是，否则不是
 */
- (BOOL)isSilent:(int)alarmType dataId:(NSString *)dataId {
    BOOL isSilent = NO;
    // 注意：目前"消息免打扰"设置只针对聊天消息哦
    if(![BasicTool isStringEmpty:dataId] && (alarmType == AMT_guestChatMessage || alarmType == AMT_friendChatMessage || alarmType == AMT_groupChatMessage)){
        isSilent = ![UserDefaultsToolKits isChatMsgToneOpen:dataId];
    }
    return isSilent;
}

// 打开单聊聊天界面
+ (void)gotoSingleChattingViewController:(UINavigationController *)nv fromUid:(NSString *)fromUid fromNickname:(NSString *)fromNickname highlight:(NSString *)highlightOnceMsgFingerprint {
    [self gotoSingleChattingViewController:nv
                                   fromUid:fromUid
                              fromNickname:fromNickname
                                 highlight:highlightOnceMsgFingerprint
                         anchorMessageDate:nil];
}

+ (void)gotoSingleChattingViewController:(UINavigationController *)nv fromUid:(NSString *)fromUid fromNickname:(NSString *)fromNickname highlight:(NSString *)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *)anchorMessageDate {
    if(fromUid == nil) return;
    if ([BasicTool trim:highlightOnceMsgFingerprint].length > 0) {
        NSLog(@"【RB-SEARCH-JUMP】Alarms gotoSingle uid=%@ fp=%@", fromUid, [BasicTool trim:highlightOnceMsgFingerprint]);
    }
    if ([BasicTool isOfficialAccountHideAvatarInChat:fromUid]) {
        [ViewControllerFactory goOfficialAccountChatViewController:fromUid
                                                          nickname:fromNickname
                                                             toNav:nv
                                                    popToRootFirst:NO
                                                         highlight:highlightOnceMsgFingerprint
                                                 anchorMessageDate:anchorMessageDate];
        return;
    }
    BOOL isFriend = [[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster:fromUid];
    BOOL hasFriendSession = ([[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmIndex:AMT_friendChatMessage dataId:fromUid] != -1);
    BOOL keepFormalChatSession = isFriend || hasFriendSession || [UserDefaultsToolKits isFriendChatSendBlockedUid:fromUid];
    if (keepFormalChatSession) {
        [ViewControllerFactory goChatViewController:fromUid
                                        andNickname:fromNickname
                                              toNav:nv
                                     popToRootFirst:NO
                                          highlight:highlightOnceMsgFingerprint
                                  anchorMessageDate:anchorMessageDate];
    } else {
        [ViewControllerFactory goTempChatViewController:fromUid
                                              guestName:fromNickname
                                              maxFriend:0
                                                  toNav:nv
                                         popToRootFirst:NO
                                              highlight:highlightOnceMsgFingerprint
                                      anchorMessageDate:anchorMessageDate];
    }
}

// 打开群聊聊天界面
+ (void)gotoGroupChattingViewController:(UINavigationController *)nv gid:(NSString *)gid ge:(GroupEntity *)g highlight:(NSString *)highlightOnceMsgFingerprint {
    [self gotoGroupChattingViewController:nv
                                      gid:gid
                                       ge:g
                                highlight:highlightOnceMsgFingerprint
                        anchorMessageDate:nil];
}

+ (void)gotoGroupChattingViewController:(UINavigationController *)nv gid:(NSString *)gid ge:(GroupEntity *)g highlight:(NSString *)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *)anchorMessageDate {
    if ([BasicTool trim:highlightOnceMsgFingerprint].length > 0) {
        NSLog(@"【RB-SEARCH-JUMP】Alarms gotoGroup gid=%@ fp=%@", gid ?: @"-", [BasicTool trim:highlightOnceMsgFingerprint]);
    }

    if(g == nil){
        g = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];
    }
        
    if(g != nil) {
        NSString *gname = g.g_name;
        if (gid != nil && gname != nil) {
            // 进入群聊界面
            [ViewControllerFactory goGroupChattingViewController:nv
                                                             gid:gid
                                                           gname:gname
                                                        animated:YES
                                                  popToRootFirst:NO
                                                       highlight:highlightOnceMsgFingerprint
                                               anchorMessageDate:anchorMessageDate];
        }
    }
}

#pragma mark - 草稿相关方法

/**
 * 根据 alarmType 获取对应的 chatType
 */
- (int)getChatTypeFromAlarmType:(int)alarmType
{
    if (alarmType == AMT_friendChatMessage) {
        return CHAT_TYPE_FREIDN_CHAT;
    } else if (alarmType == AMT_guestChatMessage) {
        return CHAT_TYPE_GUEST_CHAT;
    } else if (alarmType == AMT_groupChatMessage) {
        return CHAT_TYPE_GROUP_CHAT;
    }
    return -1; // 未知类型
}

/**
 * 获取指定 alarm 的草稿内容
 */
- (NSString *)getDraftForAlarm:(AlarmDto *)alarm
{
    if (!alarm || !alarm.dataId || alarm.dataId.length == 0) {
        return nil;
    }
    
    // 根据 alarmType 获取对应的 chatType
    int chatType = [self getChatTypeFromAlarmType:alarm.alarmType];
    if (chatType == -1) {
        return nil; // 不支持的 alarmType
    }
    
    // 生成草稿 key
    NSString *draftKey = [NSString stringWithFormat:@"chat_draft_%d_%@", chatType, alarm.dataId];
    
    // 从 NSUserDefaults 读取草稿
    NSString *draftText = [[NSUserDefaults standardUserDefaults] objectForKey:draftKey];
    if (draftText && draftText.length > 0) {
        // 去除首尾空白字符
        draftText = [draftText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (draftText.length > 0) {
            return draftText;
        }
    }
    
    return nil;
}

@end
