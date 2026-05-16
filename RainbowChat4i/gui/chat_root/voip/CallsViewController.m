//telegram @wz662
//  通话记录列表页：展示单聊通话记录（全部 / 未接）
//

#import "CallsViewController.h"
#import "AppDelegate.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "Default.h"
#import "BasicTool.h"
#import "ViewControllerFactory.h"
#import "CallManager.h"
#import "TargetChooseViewController.h"
#import "MsgBodyRoot.h"
#import "LPActionSheet.h"
#import "UserEntity.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"
#import "MyDataBase.h"

/// 自定义 cell，在 layoutSubviews 中固定头像尺寸与上下留白，避免与行高连在一起
@interface CallRecordCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarImageView;   // 专用头像视图，用于 RBAvatarView，避免系统 imageView 不显示
@property (nonatomic, strong) UIImageView *callTypeIconView;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, assign) BOOL editingMode;
@end

@implementation CallRecordCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _avatarImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarImageView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1];
        _avatarImageView.clipsToBounds = YES;
        [self.contentView addSubview:_avatarImageView];

        _callTypeIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _callTypeIconView.contentMode = UIViewContentModeScaleAspectFit;
        _callTypeIconView.tintColor = [UIColor lightGrayColor];
        _callTypeIconView.hidden = YES;
        [self.contentView addSubview:_callTypeIconView];

        _deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _deleteButton.frame = CGRectZero;
        UIImage *delIcon = [[UIImage imageNamed:@"call_delete_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [_deleteButton setImage:delIcon forState:UIControlStateNormal];
        _deleteButton.tintColor = [UIColor redColor];
        _deleteButton.hidden = YES;
        [self.contentView addSubview:_deleteButton];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    const CGFloat avatarSize = 36.0f;
    const CGFloat typeIconSize = 28.0f;   // 拨出图标
    const CGFloat deleteSize = 36.0f;     // 删除图标与头像接近尺寸，更醒目
    const CGFloat leftPadding = 16.0f;
    const CGFloat gap = 8.0f;

    CGFloat x = leftPadding;

    // 左侧删除按钮（编辑模式下显示）
    if (self.editingMode) {
        CGFloat delY = (self.contentView.bounds.size.height - deleteSize) * 0.5f;
        self.deleteButton.frame = CGRectMake(x, delY, deleteSize, deleteSize);
        x += deleteSize + gap;
    } else {
        self.deleteButton.frame = CGRectZero;
    }

    // 拨出类型图标（如果有）
    CGFloat iconLeft = x;
    CGFloat iconY = (self.contentView.bounds.size.height - typeIconSize) * 0.5f;
    self.callTypeIconView.frame = CGRectMake(iconLeft, iconY, typeIconSize, typeIconSize);
    x += typeIconSize + gap;

    // 头像放在图标右侧（使用专用 avatarImageView，保证头像可见）
    CGFloat avatarLeft = x;
    CGFloat y = (self.contentView.bounds.size.height - avatarSize) * 0.5f;
    self.avatarImageView.frame = CGRectMake(avatarLeft, y, avatarSize, avatarSize);
    self.avatarImageView.layer.cornerRadius = avatarSize * 0.5f;
    self.avatarImageView.layer.masksToBounds = YES;
    self.imageView.hidden = YES;

    // 文字区域紧挨头像右侧，留出间距
    CGFloat textLeft = avatarLeft + avatarSize + 12.0f;
    CGFloat accessoryW = 0.0f;
    if (self.accessoryView) {
        accessoryW = CGRectGetWidth(self.accessoryView.bounds);
    }
    CGFloat textRight = self.contentView.bounds.size.width - MAX(80.0f, accessoryW) - 12.0f;
    if (self.textLabel) {
        self.textLabel.frame = CGRectMake(textLeft, 12.0f, textRight - textLeft, 22.0f);
    }
    if (self.detailTextLabel) {
        self.detailTextLabel.frame = CGRectMake(textLeft, 36.0f, textRight - textLeft, 16.0f);
    }
}
@end

static const int kRequestCodeStartNewCall = 200;
/// 「全部/未接」胶囊分段控件尺寸（略大于系统默认，便于点击与阅读）
static const CGFloat kCallsFilterSegmentWidth = 170.f;
static const CGFloat kCallsFilterSegmentHeight = 36.f;
/// 编辑态「删除所有」相对原位置的右移量（左槽 44pt 内居中时略偏左）
static const CGFloat kCallsDeleteAllNavOffsetX = 10.f;

@interface CallsViewController () <UserChooseCompleteDelegate>

@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) NSArray<NSDictionary *> *allRecords;
@property (nonatomic, strong) NSArray<NSDictionary *> *shownRecords;
@property (nonatomic, assign) CallsFilterType filterType;
/// P1-2：上次拉取是否失败（用于显示错误态与重试）
@property (nonatomic, assign) BOOL loadFailed;
/// 分页：当前已加载到的页码（从 1 开始）
@property (nonatomic, assign) NSInteger currentPage;
/// 分页：是否还有更多数据可拉取
@property (nonatomic, assign) BOOL hasMore;
/// 分页：是否正在加载更多，避免重复触发
@property (nonatomic, assign) BOOL isLoadingMore;
/// 是否处于编辑模式
@property (nonatomic, assign) BOOL isEditingList;
/// 交互式 Pop 取消等转场收尾中暂缓 `rb_plainCustomNavHostViewWillAppear`，避免 bringSubviewToFront/安全区与转场叠代导致整页「重建」抖动
@property (nonatomic, assign) BOOL calls_pendingPlainNavWillAppear;

- (void)calls_attachSegmentToChromeNavIfNeeded;
- (void)calls_updateChromeNavForListEditing:(BOOL)editing;
- (BOOL)calls_shouldDeferLayoutForNavigationTransition;

@end

@implementation CallsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = HexColor(0xF0F0F0);
    self.filterType = CallsFilterTypeAll;
    
    self.currentPage = 1;
    self.hasMore = YES;
    self.isLoadingMore = NO;
    self.isEditingList = NO;
    // 中间「全部/未接」分段控件，安装到自定义顶栏（与设置等子页一致）
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"未接"]];
    seg.selectedSegmentIndex = 0;
    seg.frame = CGRectMake(0, 0, kCallsFilterSegmentWidth, kCallsFilterSegmentHeight);
    seg.layer.cornerRadius = kCallsFilterSegmentHeight * 0.5f;
    seg.layer.masksToBounds = YES;
    UIFont *segFont = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    [seg setTitleTextAttributes:@{ NSFontAttributeName: segFont } forState:UIControlStateNormal];
    [seg setTitleTextAttributes:@{ NSFontAttributeName: segFont } forState:UIControlStateSelected];
    [seg addTarget:self action:@selector(onSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.segmentedControl = seg;

    self.navigationItem.titleView = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.leftBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@""];
    [self calls_attachSegmentToChromeNavIfNeeded];
    [self calls_updateChromeNavForListEditing:NO];

    [self setupTableView];
    [self rb_loadCachedCallRecordsIfAny];
    [self loadCallRecords];
}

- (NSString *)rb_callsCacheKey
{
    return @"calls_v1";
}

- (void)rb_loadCachedCallRecordsIfAny
{
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (uid.length == 0) return;
    NSString *cacheKey = [self rb_callsCacheKey];
    __weak typeof(self) wself = self;
    [MyDataBase inDatabase:^(FMDatabase *db) {
        NSString *json = [[MyDataBase sharedInstance].callRecordsCacheTable queryJson:db ownerUid:uid cacheKey:cacheKey];
        if (json.length == 0) return;
        NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
        if (!data) return;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![obj isKindOfClass:[NSArray class]]) return;
        NSArray *arr = (NSArray *)obj;
        NSMutableArray<NSDictionary *> *records = [NSMutableArray array];
        for (id it in arr) {
            if ([it isKindOfClass:[NSDictionary class]]) {
                [records addObject:(NSDictionary *)it];
            }
        }
        if (records.count == 0) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            CallsViewController *s = wself;
            if (!s) return;
            if (s.allRecords.count > 0) return;
            s.loadFailed = NO;
            s.allRecords = [s sortRecordsByTimeDescending:[s deduplicateCallRecords:records]];
            [s applyFilterAndReload];
        });
    }];
}

- (void)rb_saveCallRecordsCacheIfNeeded:(NSArray<NSDictionary *> *)records ownerUid:(NSString *)uid
{
    if (uid.length == 0 || records.count == 0) return;
    NSArray *limited = records;
    if (records.count > 300) {
        limited = [records subarrayWithRange:NSMakeRange(0, 300)];
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:limited options:0 error:nil];
    if (!data) return;
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (json.length == 0) return;
    NSString *cacheKey = [self rb_callsCacheKey];
    long long ts = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    [MyDataBase inDatabase:^(FMDatabase *db) {
        [[MyDataBase sharedInstance].callRecordsCacheTable upsertJson:db ownerUid:uid cacheKey:cacheKey json:json updateTime2:ts];
    }];
}

- (BOOL)calls_shouldDeferLayoutForNavigationTransition
{
    UINavigationController *nav = self.navigationController;
    if (nav == nil) {
        return NO;
    }
    id<UIViewControllerTransitionCoordinator> tc = nav.transitionCoordinator;
    if (tc == nil || !tc.isAnimated) {
        return NO;
    }
    // 首次 push 进本页要正常布局，不能因导航转场动画而整段跳过
    if (self.isMovingToParentViewController) {
        return NO;
    }
    return YES;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if ([self calls_shouldDeferLayoutForNavigationTransition]) {
        return;
    }
    // 更新「开始新通话」头部宽度（旋转或分屏时）
    CGFloat tableWidth = CGRectGetWidth(self.tableView.bounds);
    if (tableWidth > 0 && self.tableView.tableHeaderView
        && fabs(CGRectGetWidth(self.tableView.tableHeaderView.bounds) - tableWidth) > 0.5) {
        UIView *header = self.tableView.tableHeaderView;
        header.frame = CGRectMake(0, 0, tableWidth, CGRectGetHeight(header.bounds));
        self.tableView.tableHeaderView = header;
    }
}

/// 构建列表顶部「开始新通话」白色圆角卡片（蓝图标 + 蓝文案）
- (UIView *)buildNewCallHeaderViewWithWidth:(CGFloat)width
{
    if (width <= 0) width = 320;
    static const CGFloat kHeaderHeight = 72;
    static const CGFloat kCardHorizontalMargin = 16;
    static const CGFloat kCardVerticalMargin = 10;
    static const CGFloat kCardCornerRadius = 26;
    static const CGFloat kIconLeft = 16;
    static const CGFloat kIconLabelGap = 12;
    static const CGFloat kIconSize = 24;
    UIColor *blueColor = HexColor(0x007AFF);

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, kHeaderHeight)];
    container.backgroundColor = [UIColor clearColor];

    CGFloat cardWidth = width - kCardHorizontalMargin * 2;
    CGFloat cardHeight = kHeaderHeight - kCardVerticalMargin * 2;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(kCardHorizontalMargin, kCardVerticalMargin, cardWidth, cardHeight)];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = kCardCornerRadius;
    card.layer.masksToBounds = YES;
    [container addSubview:card];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:kIconSize weight:UIImageSymbolWeightRegular];
    UIImage *iconImage = [UIImage systemImageNamed:@"phone.badge.plus" withConfiguration:config];
    if (iconImage) {
        UIImageView *iconView = [[UIImageView alloc] initWithImage:[iconImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        iconView.tintColor = blueColor;
        iconView.frame = CGRectMake(kIconLeft, (cardHeight - kIconSize) / 2, kIconSize, kIconSize);
        [card addSubview:iconView];
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = @"开始新通话";
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    label.textColor = blueColor;
    [label sizeToFit];
    CGFloat labelX = kIconLeft + kIconSize + kIconLabelGap;
    label.frame = CGRectMake(labelX, (cardHeight - label.bounds.size.height) / 2, label.bounds.size.width, label.bounds.size.height);
    [card addSubview:label];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onStartNewCallTapped)];
    [card addGestureRecognizer:tap];
    card.userInteractionEnabled = YES;

    return container;
}

- (void)setupTableView
{
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    tableView.tableHeaderView = [self buildNewCallHeaderViewWithWidth:CGRectGetWidth(self.view.bounds)];
    tableView.backgroundColor = HexColor(0xF0F0F0);
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(onPullToRefresh) forControlEvents:UIControlEventValueChanged];
    tableView.refreshControl = refresh;
    // 列表可穿过顶部导航栏滚动（内容延伸到导航栏下）
    if (@available(iOS 11.0, *)) {
        tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:tableView];
    self.tableView = tableView;
    
    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self calls_shouldDeferLayoutForNavigationTransition]) {
        self.calls_pendingPlainNavWillAppear = YES;
    } else {
        self.calls_pendingPlainNavWillAppear = NO;
        [self rb_plainCustomNavHostViewWillAppear:animated];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    BOOL hadDeferredPlainNav = self.calls_pendingPlainNavWillAppear;
    if (hadDeferredPlainNav) {
        self.calls_pendingPlainNavWillAppear = NO;
        [self rb_plainCustomNavHostViewWillAppear:animated];
    }
    [self rb_plainCustomNavHostViewDidAppear:animated];
    if (hadDeferredPlainNav) {
        // 转场协调器常在 didAppear 之后才完全释放；延后一帧再 layout，避免仍命中 defer 而漏同步列表 inset
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.view setNeedsLayout];
            [self.view layoutIfNeeded];
        });
    }
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

- (void)calls_attachSegmentToChromeNavIfNeeded
{
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (!bar || !self.segmentedControl || self.segmentedControl.superview) {
        return;
    }
    bar.titleLabel.hidden = YES;
    UIView *row = bar.titleLabel.superview;
    if (!row) {
        return;
    }
    [row addSubview:self.segmentedControl];
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.segmentedControl.centerXAnchor constraintEqualToAnchor:bar.titleLabel.centerXAnchor],
        [self.segmentedControl.centerYAnchor constraintEqualToAnchor:bar.titleLabel.centerYAnchor],
        [self.segmentedControl.widthAnchor constraintEqualToConstant:kCallsFilterSegmentWidth],
        [self.segmentedControl.heightAnchor constraintEqualToConstant:kCallsFilterSegmentHeight],
    ]];
}

- (UIButton *)calls_barButtonWithTitle:(NSString *)title action:(SEL)sel
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:17];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [btn sizeToFit];
    CGFloat w = MAX(44.f, CGRectGetWidth(btn.bounds) + 8.f);
    btn.bounds = CGRectMake(0, 0, w, 44.f);
    return btn;
}

- (void)calls_updateChromeNavForListEditing:(BOOL)editing
{
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (!bar) {
        return;
    }
    if (editing) {
        bar.backButton.hidden = YES;
        bar.multiSelectCancelButton.hidden = NO;
        [bar.multiSelectCancelButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [bar.multiSelectCancelButton setTitle:@"删除所有" forState:UIControlStateNormal];
        if (@available(iOS 13.0, *)) {
            bar.multiSelectCancelButton.tintColor = [UIColor systemRedColor];
        } else {
            bar.multiSelectCancelButton.tintColor = [UIColor redColor];
        }
        [bar.multiSelectCancelButton addTarget:self action:@selector(onDeleteAllTapped) forControlEvents:UIControlEventTouchUpInside];
        bar.multiSelectCancelButton.transform = CGAffineTransformMakeTranslation(kCallsDeleteAllNavOffsetX, 0.f);
        [bar clearRightAccessorySubviews];
        [bar attachRightAccessoryView:[self calls_barButtonWithTitle:@"完成" action:@selector(onDoneTapped)]];
    } else {
        bar.backButton.hidden = NO;
        bar.multiSelectCancelButton.hidden = YES;
        bar.multiSelectCancelButton.transform = CGAffineTransformIdentity;
        [bar.multiSelectCancelButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [bar.multiSelectCancelButton setTitle:NSLocalizedString(@"general_cancel", @"取消") forState:UIControlStateNormal];
        bar.multiSelectCancelButton.tintColor = nil;
        [bar clearRightAccessorySubviews];
        [bar attachRightAccessoryView:[self calls_barButtonWithTitle:@"编辑" action:@selector(onEditTapped)]];
    }
}

- (void)onPullToRefresh
{
    // 下拉刷新：回到第一页并重置更多标记
    self.currentPage = 1;
    self.hasMore = YES;
    [self loadCallRecordsAtPage:1 isLoadMore:NO];
}

- (void)loadCallRecords
{
    // 首次进入页面加载第一页
    self.currentPage = 1;
    self.hasMore = YES;
    [self loadCallRecordsAtPage:1 isLoadMore:NO];
}

/// 内部方法：按照指定页码拉取通话记录
- (void)loadCallRecordsAtPage:(NSInteger)page isLoadMore:(BOOL)isLoadMore
{
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (uid.length == 0) {
        if (!isLoadMore) {
            self.allRecords = @[];
            self.shownRecords = @[];
            [self.tableView reloadData];
        }
        return;
    }
    
    __weak typeof(self) safeSelf = self;
    if (!isLoadMore) {
        self.loadFailed = NO;
    }
    if (self.isLoadingMore) {
        return;
    }
    self.isLoadingMore = YES;
    [[HttpRestHelper sharedInstance] submitGetCallRecordsToServer:uid
                                                             page:page
                                                         pageSize:50
                                                          peerUid:nil
                                                       sinceTime2:nil
                                                          complete:^(BOOL sucess, NSArray<NSDictionary *> *records) {
        dispatch_async(dispatch_get_main_queue(), ^{
            safeSelf.isLoadingMore = NO;
            if (!isLoadMore) {
                [safeSelf.tableView.refreshControl endRefreshing];
            }
            
            if (!sucess || !records) {
                if (!isLoadMore) {
                    safeSelf.loadFailed = YES;
                    safeSelf.allRecords = @[];
                    safeSelf.shownRecords = @[];
                    [safeSelf applyFilterAndReload];
                } else {
                    // 加载更多失败时，不打断已加载的数据，只是认为没有更多了
                    safeSelf.hasMore = NO;
                }
                return;
            }
            
            // 根据返回条数判断是否还有更多：
            // 只要本次返回不为空，就认为还有更多，直到服务端返回空数组为止
            safeSelf.hasMore = (records.count > 0);
            safeSelf.currentPage = page;
            
            if (isLoadMore && safeSelf.allRecords.count > 0) {
                NSArray *merged = [safeSelf.allRecords arrayByAddingObjectsFromArray:records];
                NSArray *dedup = [safeSelf deduplicateCallRecords:merged];
                safeSelf.allRecords = [safeSelf sortRecordsByTimeDescending:dedup];
            } else {
                NSArray *dedup = [safeSelf deduplicateCallRecords:records];
                safeSelf.allRecords = [safeSelf sortRecordsByTimeDescending:dedup];
            }
            [safeSelf applyFilterAndReload];
            if (!isLoadMore) {
                [safeSelf rb_saveCallRecordsCacheIfNeeded:safeSelf.allRecords ownerUid:uid];
            }
        });
    } hudParentView:(isLoadMore ? nil : self.view)];
}

/// 按 collect_id 或 (sender_uid + receiver_uid + msg_time2 + direction + call_type) 去重，保留首次出现
- (NSArray<NSDictionary *> *)deduplicateCallRecords:(NSArray<NSDictionary *> *)records
{
    if (!records.count) return records;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:records.count];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSDictionary *rec in records) {
        NSString *key = nil;
        id collectId = rec[@"collect_id"];
        if (collectId != nil) {
            if ([collectId isKindOfClass:[NSNumber class]]) {
                key = [(NSNumber *)collectId stringValue];
            } else if ([collectId isKindOfClass:[NSString class]]) {
                key = (NSString *)collectId;
            }
        }
        if (key.length == 0) {
            NSString *s = rec[@"sender_uid"] ?: @"";
            NSString *r = rec[@"receiver_uid"] ?: @"";
            id mt = rec[@"msg_time2"];
            NSString *mtStr = mt ? [NSString stringWithFormat:@"%@", mt] : @"";
            NSString *dir = rec[@"direction"] ?: @"";
            NSString *ct = rec[@"call_type"] ?: @"";
            key = [NSString stringWithFormat:@"%@|%@|%@|%@|%@", s, r, mtStr, dir, ct];
        }
        if (key.length && ![seen containsObject:key]) {
            [seen addObject:key];
            [result addObject:rec];
        }
    }
    return [result copy];
}

/// 根据 msg_time2 从新到旧排序（时间大的在前）
- (NSArray<NSDictionary *> *)sortRecordsByTimeDescending:(NSArray<NSDictionary *> *)records
{
    if (!records.count) return records;
    return [records sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        double ta = 0;
        id mtA = a[@"msg_time2"];
        if ([mtA isKindOfClass:[NSNumber class]]) {
            ta = [mtA doubleValue];
        } else if ([mtA isKindOfClass:[NSString class]]) {
            ta = [(NSString *)mtA doubleValue];
        }
        double tb = 0;
        id mtB = b[@"msg_time2"];
        if ([mtB isKindOfClass:[NSNumber class]]) {
            tb = [mtB doubleValue];
        } else if ([mtB isKindOfClass:[NSString class]]) {
            tb = [(NSString *)mtB doubleValue];
        }
        if (ta > tb) {
            return NSOrderedAscending; // 新时间在前
        } else if (ta < tb) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
}

- (void)onSegmentChanged:(UISegmentedControl *)seg
{
    self.filterType = (seg.selectedSegmentIndex == 1) ? CallsFilterTypeMissed : CallsFilterTypeAll;
    [self applyFilterAndReload];
}

- (void)applyFilterAndReload
{
    if (self.filterType == CallsFilterTypeMissed) {
        NSMutableArray *missed = [NSMutableArray array];
        for (NSDictionary *rec in self.allRecords) {
            NSString *status = rec[@"call_status"];
            if ([status isKindOfClass:[NSString class]] && [status isEqualToString:@"missed"]) {
                [missed addObject:rec];
            }
        }
        self.shownRecords = [self sortRecordsByTimeDescending:missed];
    } else {
        NSArray *all = self.allRecords ?: @[];
        self.shownRecords = [self sortRecordsByTimeDescending:all];
    }
    [self.tableView reloadData];
    [self updateEmptyOrErrorView];
}

- (void)updateEmptyOrErrorView
{
    if (self.loadFailed) {
        [self showErrorBackgroundWithRetry];
    } else if (self.shownRecords.count == 0) {
        [self showEmptyBackground];
    } else {
        self.tableView.backgroundView = nil;
    }
}

- (void)showEmptyBackground
{
    UIView *bg = [[UIView alloc] initWithFrame:self.tableView.bounds];
    bg.backgroundColor = HexColor(0xF0F0F0);
    bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UILabel *label = [[UILabel alloc] init];
    label.text = @"暂无通话记录";
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor grayColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [bg addSubview:label];

    UIButton *startBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [startBtn setTitle:@"发起通话" forState:UIControlStateNormal];
    startBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    startBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [startBtn addTarget:self action:@selector(onStartNewCallTapped) forControlEvents:UIControlEventTouchUpInside];
    [bg addSubview:startBtn];

    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:bg.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:bg.centerYAnchor constant:-28],
        [startBtn.centerXAnchor constraintEqualToAnchor:bg.centerXAnchor],
        [startBtn.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:16],
    ]];

    self.tableView.backgroundView = bg;
}

- (void)showErrorBackgroundWithRetry
{
    UIView *bg = [[UIView alloc] initWithFrame:self.tableView.bounds];
    bg.backgroundColor = HexColor(0xF0F0F0);
    UILabel *label = [[UILabel alloc] init];
    label.text = @"加载失败，请重试";
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor grayColor];
    label.textAlignment = NSTextAlignmentCenter;
    [label sizeToFit];
    label.center = CGPointMake(bg.bounds.size.width * 0.5f, bg.bounds.size.height * 0.5f - 50.0f);
    label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [bg addSubview:label];
    
    UIButton *retryBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [retryBtn setTitle:@"重试" forState:UIControlStateNormal];
    retryBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [retryBtn addTarget:self action:@selector(onRetryLoadRecords) forControlEvents:UIControlEventTouchUpInside];
    [retryBtn sizeToFit];
    retryBtn.center = CGPointMake(bg.bounds.size.width * 0.5f, bg.bounds.size.height * 0.5f);
    retryBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [bg addSubview:retryBtn];
    
    self.tableView.backgroundView = bg;
}

- (void)onRetryLoadRecords
{
    self.loadFailed = NO;
    self.tableView.backgroundView = nil;
    [self loadCallRecords];
}

- (void)onStartNewCallTapped
{
    if ([[CallManager sharedInstance] isInCall]) {
        [BasicTool showAlertInfo:@"当前正在通话中，请先结束当前通话" parent:self];
        return;
    }
    // 选择好友时过滤系统/官方账号（不可发起通话）
    NSSet<NSString *> *excludedUids = [NSSet setWithObjects:@"10000", @"10001", @"400069", @"400070", nil];
    TargetSourceFilter4Friend friendFilter = ^BOOL(UserEntity *originalData) {
        if (originalData == nil || originalData.user_uid.length == 0) return NO;
        if ([excludedUids containsObject:originalData.user_uid]) return NO;
        return YES;
    };
    [ViewControllerFactory goTargetChooseViewController:self.navigationController
                                  supportedTargetSource:TargetSourceFriend
                                   latestChattingFilter:nil
                                           friendFilter:friendFilter
                                            groupFilter:nil
                                     groupMemberFilter:nil
                                              extraObj:nil
                                                   gid:nil
                                           requestCode:kRequestCodeStartNewCall
                                              delegate:self];
}

#pragma mark - UserChooseCompleteDelegate

- (void)processTargetChooseComplete:(TargetEntity *)selectedTarget extraObj:(id)obj requestCode:(int)requestCode
{
    if (requestCode != kRequestCodeStartNewCall || selectedTarget == nil) return;
    if (selectedTarget.targetChatType != CHAT_TYPE_FREIDN_CHAT) return;

    NSString *peerUid = selectedTarget.targetId;
    NSString *peerName = selectedTarget.targetName.length > 0 ? selectedTarget.targetName : peerUid;
    if (peerUid.length == 0) return;

    if ([[CallManager sharedInstance] isInCall]) {
        [BasicTool showAlertInfo:@"当前正在通话中，请先结束当前通话" parent:self];
        return;
    }

    __weak typeof(self) safeSelf = self;
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"语音通话", @"视频通话"]
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == 1) {
            [[CallManager sharedInstance] startCall:peerUid remoteNickname:peerName callType:CallTypeVoice];
            [ViewControllerFactory goCallViewController:peerUid
                                     remoteUserNickname:peerName
                                               callType:CallTypeVoice
                                               isCaller:YES];
        } else if (index == 2) {
            [[CallManager sharedInstance] startCall:peerUid remoteNickname:peerName callType:CallTypeVideo];
            [ViewControllerFactory goCallViewController:peerUid
                                     remoteUserNickname:peerName
                                               callType:CallTypeVideo
                                               isCaller:YES];
        }
    }];
}

- (void)onEditTapped
{
    if (!self.isEditingList) {
        // 进入编辑模式
        self.isEditingList = YES;
        [self calls_updateChromeNavForListEditing:YES];

        // 平滑动画：可见 cell 从左向右滑出，为删除按钮腾出空间，删除按钮渐显
        NSArray<UITableViewCell *> *visibleCells = [self.tableView visibleCells];
        for (UITableViewCell *cell in visibleCells) {
            if (![cell isKindOfClass:[CallRecordCell class]]) continue;
            CallRecordCell *c = (CallRecordCell *)cell;
            c.deleteButton.hidden = NO;
            c.deleteButton.alpha = 0.0f;
        }
        [UIView animateWithDuration:0.01
                              delay:0
             usingSpringWithDamping:0.01
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            for (UITableViewCell *cell in visibleCells) {
                if (![cell isKindOfClass:[CallRecordCell class]]) continue;
                CallRecordCell *c = (CallRecordCell *)cell;
                c.editingMode = YES;
                c.deleteButton.alpha = 1.0f;
                [c layoutIfNeeded];
            }
        } completion:^(BOOL finished) {
            // 动画结束后刷新一次，统一让 cell 按编辑状态重新布局（含右侧 accessoryView 隐藏信息按钮）
            [self.tableView reloadData];
        }];
    } else {
        // 已经是编辑状态时再次点击「编辑」不做处理
    }
}

- (void)onDoneTapped
{
    if (!self.isEditingList) return;
    self.isEditingList = NO;
    [self calls_updateChromeNavForListEditing:NO];

    // 平滑动画：可见 cell 从右向左回到正常位置，删除按钮渐隐
    NSArray<UITableViewCell *> *visibleCells = [self.tableView visibleCells];
    [UIView animateWithDuration:0.01
                          delay:0
         usingSpringWithDamping:0.01
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        for (UITableViewCell *cell in visibleCells) {
            if (![cell isKindOfClass:[CallRecordCell class]]) continue;
            CallRecordCell *c = (CallRecordCell *)cell;
            c.editingMode = NO;
            c.deleteButton.alpha = 0.0f;
            [c layoutIfNeeded];
        }
    } completion:^(BOOL finished) {
        for (UITableViewCell *cell in visibleCells) {
            if (![cell isKindOfClass:[CallRecordCell class]]) continue;
            CallRecordCell *c = (CallRecordCell *)cell;
            c.deleteButton.hidden = YES;
        }
        // 退出编辑后也刷新一次，让右侧 accessoryView 恢复带信息按钮的样式
        [self.tableView reloadData];
    }];
}

- (void)onDeleteAllTapped
{
    if (!self.isEditingList) return;
    if (self.shownRecords.count == 0) {
        [APP showToastWarn:@"暂无通话记录"];
        return;
    }
    __weak typeof(self) wself = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除所有通话记录？"
                                                                   message:@"确定要清空当前列表中的全部通话记录吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        if (!wself) return;
        NSString *user_uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        if (!user_uid.length) return;
        NSArray *recordsCopy = [wself.allRecords copy];
        for (NSDictionary *rec in recordsCopy) {
            NSString *fp = rec[@"fingerprint"];
            if ([fp isKindOfClass:[NSString class]] && fp.length > 0) {
                [[HttpRestHelper sharedInstance] submitDeleteCallRecordToServer:user_uid fingerprint:fp complete:nil hudParentView:nil];
            }
        }
        wself.allRecords = @[];
        wself.shownRecords = @[];
        wself.hasMore = NO;
        [wself.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

/// 与消息列表一致：对方在好友列表中有备注时显示备注，否则用接口下发的昵称（再退回 uid）
- (NSString *)rb_displayNameForCallPeerUid:(NSString *)peerUid apiNickname:(NSString *)apiNickname
{
    if (peerUid.length == 0) {
        return apiNickname.length > 0 ? apiNickname : @"-";
    }
    UserEntity *friend = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:peerUid];
    if (friend) {
        NSString *withRemark = [friend getNickNameWithRemark];
        if (withRemark.length > 0) {
            return withRemark;
        }
    }
    if (apiNickname.length > 0) {
        return apiNickname;
    }
    return peerUid;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.shownRecords.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellId = @"CallRecordCell";
    CallRecordCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[CallRecordCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }
    
    NSDictionary *rec = self.shownRecords[indexPath.row];
    NSString *direction = rec[@"direction"];
    NSString *callType = rec[@"call_type"];
    NSString *status = rec[@"call_status"];
    NSString *durationText = rec[@"duration_text"];
    NSString *senderName = rec[@"sender_nickname"];
    NSString *receiverName = rec[@"receiver_nickname"];
    NSString *senderAvatar = rec[@"sender_avatar"];
    NSString *receiverAvatar = rec[@"receiver_avatar"];
    
    NSString *peerName = nil;
    NSString *peerUid = nil;
    NSString *peerAvatarFileName = nil;
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    NSString *senderUid = rec[@"sender_uid"];
    NSString *receiverUid = rec[@"receiver_uid"];
    if ([direction isEqualToString:@"outgoing"]) {
        peerName = receiverName ?: receiverUid;
        peerUid = receiverUid;
        peerAvatarFileName = receiverAvatar;
    } else if ([direction isEqualToString:@"incoming"]) {
        peerName = senderName ?: senderUid;
        peerUid = senderUid;
        peerAvatarFileName = senderAvatar;
    } else {
        if ([senderUid isEqualToString:localUid]) {
            peerName = receiverName ?: receiverUid;
            peerUid = receiverUid;
            peerAvatarFileName = receiverAvatar;
        } else {
            peerName = senderName ?: senderUid;
            peerUid = senderUid;
            peerAvatarFileName = senderAvatar;
        }
    }
    if (!peerName) {
        peerName = @"-";
    }
    cell.textLabel.text = [self rb_displayNameForCallPeerUid:peerUid apiNickname:peerName];
    cell.editingMode = self.isEditingList;
    cell.deleteButton.hidden = !self.isEditingList;
    // 左侧删除按钮点击时，直接触发本行的删除逻辑
    cell.deleteButton.tag = indexPath.row;
    [cell.deleteButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.deleteButton addTarget:self action:@selector(onCellDeleteButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 头像（支持视频头像播放），使用 cell 专用 avatarImageView 确保显示
    UIImage *placeImg = [UIImage imageNamed:@"default_avatar_60"];
    [RBAvatarView setAvatarWithFileName:peerAvatarFileName uid:peerUid onImageView:cell.avatarImageView placeholder:placeImg];

    // 拨打类型图标：仅当当前用户为拨打方时，在头像左侧显示图标（语音/视频）
    // 只要这条记录在服务器标记为 outgoing（我方拨出），就显示拨出图标
    BOOL isOutgoingForMe = [direction isEqualToString:@"outgoing"];
    if (isOutgoingForMe) {
        NSString *iconName = [callType isEqualToString:@"video"] ? @"call_outgoing_video_icon" : @"call_outgoing_voice_icon";
        UIImage *icon = [[UIImage imageNamed:iconName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.callTypeIconView.image = icon;
        cell.callTypeIconView.hidden = NO;
    } else {
        cell.callTypeIconView.hidden = YES;
    }
    
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if ([direction isEqualToString:@"outgoing"]) {
        [parts addObject:@"拨出"];
    } else if ([direction isEqualToString:@"incoming"]) {
        if ([status isEqualToString:@"missed"]) {
            [parts addObject:@"未接"];
        } else {
            [parts addObject:@"接听"];
        }
    }
    if (durationText.length > 0 && ![status isEqualToString:@"missed"]) {
        // 时长展示逻辑：
        // 1) 原始 durationText 一般为 "mm:ss" 或 "ss"
        // 2) 小于 60 秒：显示为 "xx秒"
        // 3) 大于等于 60 秒：显示为 "x分钟"（向下取整）
        NSInteger totalSeconds = 0;
        if ([durationText containsString:@":"]) {
            // 解析 "mm:ss" 或 "hh:mm:ss"
            NSArray<NSString *> *components = [durationText componentsSeparatedByString:@":"];
            if (components.count == 2) {
                NSInteger m = [components[0] integerValue];
                NSInteger s = [components[1] integerValue];
                totalSeconds = m * 60 + s;
            } else if (components.count == 3) {
                NSInteger h = [components[0] integerValue];
                NSInteger m = [components[1] integerValue];
                NSInteger s = [components[2] integerValue];
                totalSeconds = h * 3600 + m * 60 + s;
            }
        } else {
            totalSeconds = [durationText integerValue];
        }

        if (totalSeconds > 0 && totalSeconds < 60) {
            NSString *secText = [NSString stringWithFormat:@"%ld秒", (long)totalSeconds];
            [parts addObject:secText];
        } else if (totalSeconds >= 60) {
            NSInteger minutes = totalSeconds / 60;
            if (minutes <= 0) minutes = 1; // 容错
            NSString *minText = [NSString stringWithFormat:@"%ld分钟", (long)minutes];
            [parts addObject:minText];
        }
    }
    cell.detailTextLabel.text = [parts componentsJoinedByString:@","];
    
    if ([status isEqualToString:@"missed"]) {
        cell.textLabel.textColor = [UIColor redColor];
    } else {
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    NSString *timeText = [self.class formatCallDateWithRecord:rec];
    if (timeText.length > 0) {
        UIFont *tf = [UIFont systemFontOfSize:12];
        CGFloat textW = [timeText boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, 16.0f)
                                              options:NSStringDrawingUsesLineFragmentOrigin
                                           attributes:@{ NSFontAttributeName : tf }
                                              context:nil].size.width;
        // 编辑模式：只显示时间，不显示蓝色信息按钮
        if (self.isEditingList) {
            CGFloat width = MAX(80.0f, MIN(140.0f, ceilf(textW) + 8.0f));
            CGFloat height = 64.0f;
            UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
            container.backgroundColor = [UIColor clearColor];
            
            UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width, 16.0f)];
            timeLabel.font = tf;
            timeLabel.textColor = [UIColor grayColor];
            timeLabel.textAlignment = NSTextAlignmentRight;
            timeLabel.text = timeText;
            CGRect tlFrame = timeLabel.frame;
            tlFrame.origin.x = 0;
            tlFrame.origin.y = (height - tlFrame.size.height) * 0.5f;
            tlFrame.size.width = width;
            timeLabel.frame = tlFrame;
            [container addSubview:timeLabel];
            
            cell.accessoryView = container;
        } else {
            // 非编辑模式：时间 + 蓝色信息按钮
            CGFloat btnSize = 24.0f;
            CGFloat width = MAX(80.0f, MIN(160.0f, ceilf(textW) + btnSize + 8.0f));
            CGFloat height = 64.0f;
            UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
            container.backgroundColor = [UIColor clearColor];

            UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
            timeLabel.font = tf;
            timeLabel.textColor = [UIColor grayColor];
            timeLabel.textAlignment = NSTextAlignmentRight;
            timeLabel.text = timeText;
            CGRect tlFrame = timeLabel.frame;
            tlFrame.origin.x = 0;
            tlFrame.origin.y = (height - tlFrame.size.height) * 0.5f;
            tlFrame.size.width = width - (btnSize + 4.0f);
            tlFrame.size.height = 16.0f;
            timeLabel.frame = tlFrame;
            [container addSubview:timeLabel];

            UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeCustom];
            infoButton.frame = CGRectMake(width - btnSize, (height - btnSize) * 0.5f, btnSize, btnSize);
            UIImage *wtIcon = [[UIImage imageNamed:@"call_info_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            [infoButton setImage:wtIcon forState:UIControlStateNormal];
            infoButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
            [infoButton addTarget:self action:@selector(onInfoTapped:) forControlEvents:UIControlEventTouchUpInside];
            infoButton.tag = indexPath.row;
            [container addSubview:infoButton];

            cell.accessoryView = container;
        }
    } else {
        cell.accessoryView = nil;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 编辑模式下点击行只用于点选/滑出删除，不触发拨打
    if (self.isEditingList || tableView.isEditing) {
        return;
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row >= (NSInteger)self.shownRecords.count) return;
    NSDictionary *rec = self.shownRecords[indexPath.row];
    NSString *callTypeStr = rec[@"call_type"];
    CallType callType = CallTypeVoice;
    if ([callTypeStr isEqualToString:@"video"]) {
        callType = CallTypeVideo;
    }
    
    NSString *peerUid = nil;
    NSString *peerName = nil;
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    NSString *direction = rec[@"direction"];
    NSString *senderUid = rec[@"sender_uid"];
    NSString *receiverUid = rec[@"receiver_uid"];
    NSString *senderName = rec[@"sender_nickname"];
    NSString *receiverName = rec[@"receiver_nickname"];
    if ([direction isEqualToString:@"outgoing"]) {
        peerUid = receiverUid;
        peerName = receiverName ?: receiverUid;
    } else if ([direction isEqualToString:@"incoming"]) {
        peerUid = senderUid;
        peerName = senderName ?: senderUid;
    } else {
        if ([senderUid isEqualToString:localUid]) {
            peerUid = receiverUid;
            peerName = receiverName ?: receiverUid;
        } else {
            peerUid = senderUid;
            peerName = senderName ?: senderUid;
        }
    }
    if (!peerUid.length) return;
    if (!peerName) peerName = peerUid;
    NSString *displayPeerName = [self rb_displayNameForCallPeerUid:peerUid apiNickname:peerName];
    
    if ([[CallManager sharedInstance] isInCall]) {
        [BasicTool showAlertInfo:@"当前正在通话中，请先结束当前通话" parent:self];
        return;
    }
    
    [[CallManager sharedInstance] startCall:peerUid remoteNickname:displayPeerName callType:callType];
    [ViewControllerFactory goCallViewController:peerUid
                           remoteUserNickname:displayPeerName
                                     callType:callType
                                     isCaller:YES];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 当滚动到当前数据的最后一行时，自动加载更多历史通话记录
    if (indexPath.row >= (NSInteger)self.shownRecords.count - 1) {
        if (self.hasMore && !self.isLoadingMore) {
            NSInteger nextPage = self.currentPage + 1;
            [self loadCallRecordsAtPage:nextPage isLoadMore:YES];
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 64.0;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 所有通话记录行都支持左滑/编辑删除
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    if (indexPath.row >= (NSInteger)self.shownRecords.count) return;

    NSDictionary *recToDelete = self.shownRecords[indexPath.row];
    NSString *fingerprint = recToDelete[@"fingerprint"];
    if (![fingerprint isKindOfClass:[NSString class]] || fingerprint.length == 0) {
        [APP showToastWarn:@"该记录无法删除（缺少标识）"];
        return;
    }
    NSString *user_uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!user_uid.length) {
        [APP showToastWarn:@"未登录，无法删除"];
        return;
    }

    __weak typeof(self) safeSelf = self;
    [[HttpRestHelper sharedInstance] submitDeleteCallRecordToServer:user_uid
                                                         fingerprint:fingerprint
                                                            complete:^(BOOL success, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                [APP showToastWarn:msg.length ? msg : @"删除失败"];
                return;
            }
            // 服务端删除成功，从本地列表移除（按对象查找索引，避免列表已变化）
            NSUInteger idx = [safeSelf.shownRecords indexOfObject:recToDelete];
            if (idx == NSNotFound) {
                return;
            }
            NSMutableArray *all = [safeSelf.allRecords mutableCopy];
            [all removeObject:recToDelete];
            safeSelf.allRecords = [all copy];

            NSMutableArray *shown = [safeSelf.shownRecords mutableCopy];
            [shown removeObjectAtIndex:idx];
            safeSelf.shownRecords = [shown copy];

            [safeSelf.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
        });
    } hudParentView:nil];
}

- (void)onCellDeleteButtonTapped:(UIButton *)sender
{
    NSInteger row = sender.tag;
    if (row < 0 || row >= (NSInteger)self.shownRecords.count) return;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    // 点击左侧删除按钮时，直接触发与右侧删除同样的删除逻辑
    [self tableView:self.tableView commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:indexPath];
}

- (void)onInfoTapped:(UIButton *)sender
{
    NSInteger row = sender.tag;
    if (row < 0 || row >= (NSInteger)self.shownRecords.count) {
        return;
    }
    NSDictionary *rec = self.shownRecords[row];
    NSString *direction = rec[@"direction"];
    NSString *senderUid = rec[@"sender_uid"];
    NSString *receiverUid = rec[@"receiver_uid"];
    NSString *senderName = rec[@"sender_nickname"];
    NSString *receiverName = rec[@"receiver_nickname"];
    NSString *senderAvatar = rec[@"sender_avatar"];
    NSString *receiverAvatar = rec[@"receiver_avatar"];
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    
    NSString *peerUid = nil;
    NSString *peerName = nil;
    NSString *peerAvatar = nil;
    if ([direction isEqualToString:@"outgoing"]) {
        peerUid = receiverUid;
        peerName = receiverName ?: receiverUid;
        peerAvatar = receiverAvatar;
    } else if ([direction isEqualToString:@"incoming"]) {
        peerUid = senderUid;
        peerName = senderName ?: senderUid;
        peerAvatar = senderAvatar;
    } else {
        if ([senderUid isEqualToString:localUid]) {
            peerUid = receiverUid;
            peerName = receiverName ?: receiverUid;
            peerAvatar = receiverAvatar;
        } else {
            peerUid = senderUid;
            peerName = senderName ?: senderUid;
            peerAvatar = senderAvatar;
        }
    }
    if (peerUid.length == 0) {
        return;
    }
    
    NSString *displayPeerName = [self rb_displayNameForCallPeerUid:peerUid apiNickname:(peerName ?: peerUid)];
    
    UserEntity *user = [[UserEntity alloc] init];
    user.user_uid = peerUid;
    user.nickname = displayPeerName.length > 0 ? displayPeerName : peerName;
    user.userAvatarFileName = peerAvatar;
    
    [ViewControllerFactory goFriendInfoViewController:self.navigationController withDatas:user canOpenChat:YES];
}

/// 今天/昨天显示具体时间，其它一周内显示「周几」，再往前显示日期（不含年份）
+ (NSString *)formatCallDateWithRecord:(NSDictionary *)rec
{
    NSNumber *msgTime2 = rec[@"msg_time2"];
    NSTimeInterval ts = 0;
    if ([msgTime2 isKindOfClass:[NSNumber class]]) {
        ts = [msgTime2 doubleValue] / 1000.0; // 毫秒转秒
    } else if ([msgTime2 isKindOfClass:[NSString class]]) {
        ts = [(NSString *)msgTime2 doubleValue] / 1000.0;
    }
    if (ts <= 0) {
        NSString *msgTime = rec[@"msg_time"];
        if ([msgTime isKindOfClass:[NSString class]] && msgTime.length > 0) {
            return msgTime; // 服务端已格式化的兜底
        }
        return @"";
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:ts];
    NSDate *now = [NSDate date];
    NSCalendar *cal = [NSCalendar currentCalendar];
    
    // 今天：仅显示时间 HH:mm
    if ([cal isDateInToday:date]) {
        NSDateFormatter *timeFmt = [[NSDateFormatter alloc] init];
        [timeFmt setLocale:[NSLocale localeWithLocaleIdentifier:@"zh_CN"]];
        [timeFmt setDateFormat:@"HH:mm"];
        return [timeFmt stringFromDate:date];
    }
    
    // 昨天：显示「昨天 HH:mm」
    if ([cal isDateInYesterday:date]) {
        NSDateFormatter *timeFmt = [[NSDateFormatter alloc] init];
        [timeFmt setLocale:[NSLocale localeWithLocaleIdentifier:@"zh_CN"]];
        [timeFmt setDateFormat:@"HH:mm"];
        NSString *timeStr = [timeFmt stringFromDate:date];
        return [NSString stringWithFormat:@"昨天 %@", timeStr];
    }
    
    NSTimeInterval diff = [now timeIntervalSinceDate:date];
    static const NSTimeInterval kSecondsPerDay = 24 * 3600;
    if (diff >= 0 && diff < 7 * kSecondsPerDay) {
        NSInteger weekday = [cal component:NSCalendarUnitWeekday fromDate:date];
        // 1=周日 2=周一 ... 7=周六
        NSArray *weekdays = @[@"", @"周日", @"周一", @"周二", @"周三", @"周四", @"周五", @"周六"];
        if (weekday >= 1 && weekday <= 7) {
            return weekdays[weekday];
        }
    }
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setLocale:[NSLocale localeWithLocaleIdentifier:@"zh_CN"]];
    [fmt setDateFormat:@"M月d日"];
    return [fmt stringFromDate:date];
}

@end
