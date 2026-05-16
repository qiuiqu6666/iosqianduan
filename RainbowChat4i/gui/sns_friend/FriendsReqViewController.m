//telegram @wz662
#import "FriendsReqViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"
#import "FriendsReqCellValue.h"
#import "FriendsReqTableViewCell.h"
#import "AlarmType.h"
#import "UserEntity.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "AppDelegate.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "AlarmsProvider.h"
#import "ViewControllerFactory.h"
#import "NotificationCenterFactory.h"
#import "EVAToolKits.h"
#import "UserDefaultsToolKits.h"
#import "FriendsReqCellValue.h"
#import "TimeTool.h"
#import "BasicTool.h"
#import "QueryFriendInfoAsync.h"
#import "MessageHelper.h"
#import "CMDBody4ProcessFriendRequest.h"
#import "Default.h"

/** 时间分组标题（从新到旧），仅展示有数据的分组 */
static NSArray<NSString *> * const kFriendReqTimeGroupTitles(void) {
    static NSArray *titles;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        titles = @[ @"近三天", @"3天前", @"7天前", @"30天前", @"3月前", @"半年前", @"1年前", @"3年前" ];
    });
    return titles;
}

/** 根据请求日期得到时间分组下标 0~7 */
static NSInteger friendReqTimeGroupIndexForDate(NSDate *date) {
    if (!date) return 0;
    NSTimeInterval t = [date timeIntervalSince1970];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval day = 24 * 3600.0;
    NSTimeInterval diff = now - t;
    if (diff <= 3 * day) return 0;       // 3天内
    if (diff <= 7 * day) return 1;       // 3天前
    if (diff <= 30 * day) return 2;      // 7天前
    if (diff <= 90 * day) return 3;      // 30天前
    if (diff <= 180 * day) return 4;     // 3月前
    if (diff <= 365 * day) return 5;     // 半年前
    if (diff <= 3 * 365 * day) return 6; // 1年前
    return 7;                             // 3年前
}

@interface FriendsReqViewController ()
/* 列表数据模型（形如<AlarmMessageDto *>的1维数组） */
@property (nonatomic, retain) NSMutableArrayObservableEx *verificationDatas;
/** 按时间分组后的数据，元素为 @{ @"title" : NSString, @"items" : NSArray<FriendsReqCellValue *> }，仅含非空分组 */
@property (nonatomic, copy) NSArray<NSDictionary *> *groupedSections;
/** 数据模型变动观察者实现block */
@property (nonatomic, copy) ObserverCompletion tableDatasObserver;
/** 已请求过头像的 uid 集合，避免重复请求（1008-4-31 不返回头像时按 uid 拉取用户信息） */
@property (nonatomic, strong) NSMutableSet<NSString *> *requestedAvatarUids;
/** 顶部查找框容器（与添加好友页同款样式，点击进入添加好友页面） */
@property (nonatomic, strong) UIView *searchBoxHeaderView;
@end

@implementation FriendsReqViewController

- (void)rb_loadOfflinePendingFriendReqs:(NSString *)localUid
{
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitGetOfflineAddFriendsReqToServer:localUid complete:^(BOOL sucess2, NSArray<UserEntity *> *reqList) {
        if (!(sucess2 && reqList != nil)) {
            [BasicTool showAlertError:@"数据加载失败！" parent:wself];
            return;
        }
        [wself.verificationDatas clear:NO];
        [wself.requestedAvatarUids removeAllObjects];
        NSSet<NSString *> *filteredUids = [NSSet setWithArray:@[@"10000", @"10001", @"400069", @"400070"]];
        for (UserEntity *u in reqList) {
            if (u == nil) continue;
            NSString *peer_uid = u.user_uid ?: @"";
            if (peer_uid.length == 0) continue;
            if ([filteredUids containsObject:peer_uid]) continue;
            [UserDefaultsToolKits unmarkDeletedFriendReqUid:peer_uid];
            if ([FriendsReqViewController isFriendReqDeleted:peer_uid]) continue;
            NSDate *reqTime = [TimeTool convertJavaTimestampToiOSDate:u.ex10];
            if (!reqTime) reqTime = [NSDate date];
            long reqTimestamp = [TimeTool getTimeStampWithMillisecond_l:reqTime];
            UserEntity *ue = [[UserEntity alloc] init];
            ue.user_uid = peer_uid;
            ue.nickname = u.nickname ?: @"";
            ue.ex1 = u.ex1;
            ue.ex10 = [NSString stringWithFormat:@"%ld", reqTimestamp];
            ue.ex12 = @"pending_in";
            FriendsReqCellValue *cellValue = [[FriendsReqCellValue alloc] init];
            NSString *content = [BasicTool trim:u.ex1].length > 0 ? u.ex1 : @"请求加你为好友";
            cellValue.content = content;
            cellValue.date = reqTime;
            cellValue.unread = NO;
            cellValue.userInfo = ue;
            cellValue.friendReqStatus = @"pending_in";
            [wself.verificationDatas add:cellValue];
        }
        NSMutableArray *list = [wself.verificationDatas getDataList];
        [list sortUsingComparator:^NSComparisonResult(FriendsReqCellValue *a, FriendsReqCellValue *b) {
            NSDate *da = a.date ?: [NSDate dateWithTimeIntervalSince1970:0];
            NSDate *db = b.date ?: [NSDate dateWithTimeIntervalSince1970:0];
            return [db compare:da];
        }];
        if (list.count > 0) {
            FriendsReqCellValue *firstCell = (FriendsReqCellValue *)[wself.verificationDatas get:0];
            UserEntity *latestRee = firstCell.userInfo;
            NSDate *latestReqTime = firstCell.date;
            if (latestRee != nil) {
                [[[IMClientManager sharedInstance] getAlarmsProvider] addAddFriendReqMergeAlarm:latestRee.user_uid friendName:latestRee.nickname reqTime:latestReqTime numToAdd:0 notify:YES merge:NO];
            }
            [[[IMClientManager sharedInstance] getFriendsReqProvider] setUnreadCount:0 needNotify:YES];
            if (latestReqTime != nil) {
                [UserDefaultsToolKits setHasReadLatestFriendReqTimestamp:latestReqTime];
            }
        } else {
            [[[IMClientManager sharedInstance] getAlarmsProvider] resetAddFriendReqAlarmFlagNum];
            [[[IMClientManager sharedInstance] getFriendsReqProvider] clearUnreadCount:YES];
        }
        [wself refreshUI];
    } hudParentView:self.view];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.rightBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"好友请求"];
    [self friendsReq_attachDeleteAllToChromeNav];

    // 初始化界面
    [self initGUI];
    
    // 初始化各种事件处理
    [self initActions];

    // 初始化数据
    [self initDatas];

    // 始化观察者
    [self initObservers];

    // 注册通知：好友请求处理界面回来时（用于通知前一个界面——即未处理验证通知列表界面中清除掉本条已处理完成的请求(而不需要再次从网络加载列表数据，提升体验））
    [NotificationCenterFactory processCompleteFriendReq_ADD:self selector:@selector(clearAddFriendReqItems:)];
}

// “viewDidUnload:”方法已在ios6后被废弃（且它只在系统内存低时才被调用），资源释放等工作正确的方式是放到 “dealloc:"中处理
- (void)dealloc
//- (void)viewDidUnload
{
    // 取消注册通知：好友请求处理界面回来时（用于通知前一个界面——即未处理验证通知列表界面中清除掉本条已处理完成的请求(而不需要再次从网络加载列表数据，提升体验））
    [NotificationCenterFactory processCompleteFriendReq_REMOVE:self];
//  [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];

    // 设置列表数据模型变动观察者
    [self.verificationDatas addObserver:self.tableDatasObserver];

    // 刷新UI
    [self refreshUI];
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
    // 取消设置列表数据模型变动观察者
    [self.verificationDatas removeObserver:self.tableDatasObserver];

    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    // 使搜索框 header 与 tableView 同宽（避免 init 时宽度不准）
    if (self.searchBoxHeaderView && self.tableView.bounds.size.width > 0) {
        CGRect fr = self.searchBoxHeaderView.frame;
        if (fabs(fr.size.width - self.tableView.bounds.size.width) > 0.5f) {
            fr.size.width = self.tableView.bounds.size.width;
            self.searchBoxHeaderView.frame = fr;
            UIView *searchBg = self.searchBoxHeaderView.subviews.firstObject;
            if (searchBg && [searchBg isKindOfClass:[UIView class]]) {
                CGRect bg = searchBg.frame;
                bg.size.width = fr.size.width - 32.0f;
                searchBg.frame = bg;
            }
        }
    }
}

- (void)initGUI
{
    // 表格基本设置
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    // 去掉空白行的显示
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    //  // 让表格行分隔线从左边0像素处绘制（默认左边会有一点空白，不好看）
    //  [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    // 让表格行分隔线从左边指定像素处绘制
    [self.tableView setSeparatorInset:UIEdgeInsetsMake(0, 76, 0, 0)];
    // 表格背景色
    self.tableView.backgroundColor = UI_DEFAULT_BG;
    // 表格分隔线的颜色与样式（好友请求列表需要分割线）
    self.tableView.separatorColor = UI_DEFAULT_TABLE_VIEW_DIVIDER_GRAY;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;

    // 顶部查找框：与添加好友页同款样式（浅灰圆角+放大镜+占位文），点击进入添加好友页面
    self.searchBoxHeaderView = [self createAddFriendStyleSearchBoxView];
    self.tableView.tableHeaderView = self.searchBoxHeaderView;
}

- (void)friendsReq_attachDeleteAllToChromeNav
{
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (!bar) {
        return;
    }
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"删除所有" forState:UIControlStateNormal];
    if (@available(iOS 13.0, *)) {
        btn.tintColor = [UIColor systemRedColor];
    } else {
        btn.tintColor = [UIColor redColor];
    }
    [btn addTarget:self action:@selector(deleteAllFriendRequests:) forControlEvents:UIControlEventTouchUpInside];
    [btn sizeToFit];
    CGFloat w = MAX(72.f, CGRectGetWidth(btn.bounds) + 8.f);
    btn.bounds = CGRectMake(0, 0, w, 44.f);
    [bar attachRightAccessoryView:btn];
}

/// 创建与添加好友页（FindFriendViewController）同款的搜索框视图，点击后进入添加好友页
- (UIView *)createAddFriendStyleSearchBoxView
{
    CGFloat width = self.tableView.bounds.size.width > 0 ? self.tableView.bounds.size.width : [UIScreen mainScreen].bounds.size.width;
    CGFloat topPad = 12.0f;
    CGFloat boxHeight = 40.0f;
    CGFloat bottomPad = 8.0f;
    CGFloat totalHeight = topPad + boxHeight + bottomPad;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, totalHeight)];
    container.backgroundColor = [UIColor whiteColor];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UIView *searchBg = [[UIView alloc] initWithFrame:CGRectMake(16, topPad, width - 32, boxHeight)];
    searchBg.backgroundColor = HexColor(0xF5F5F5);
    searchBg.layer.cornerRadius = 8;
    searchBg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [container addSubview:searchBg];

    UIImageView *searchIcon = [[UIImageView alloc] initWithFrame:CGRectMake(12, (boxHeight - 18) / 2.0f, 18, 18)];
    searchIcon.contentMode = UIViewContentModeScaleAspectFit;
    searchIcon.tintColor = HexColor(0xB2B2B2);
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
        searchIcon.image = [[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [searchBg addSubview:searchIcon];

    CGFloat labelLeft = 12 + 18 + 8;
    CGFloat labelRight = 12;
    UILabel *placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelLeft, 0, (width - 32) - labelLeft - labelRight, boxHeight)];
    placeholderLabel.text = @"ID号/手机号/邮箱";
    placeholderLabel.font = [UIFont systemFontOfSize:15];
    placeholderLabel.textColor = HexColor(0xB2B2B2);
    placeholderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [searchBg addSubview:placeholderLabel];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSearchBoxTapped:)];
    [container addGestureRecognizer:tap];
    container.userInteractionEnabled = YES;

    return container;
}

- (void)onSearchBoxTapped:(UITapGestureRecognizer *)sender
{
    [ViewControllerFactory goFindFriendViewController:self.navigationController];
}

- (void)initActions
{
    [BasicTool addFingerClick:self.layoutTableEmptyHint action:@selector(gotoForEmptyOnClick:) target:self];
}

- (void)initDatas
{
    // 初始化数组
    self.verificationDatas = [[NSMutableArrayObservableEx alloc] init];
    self.groupedSections = @[];
    self.requestedAvatarUids = [NSMutableSet set];

    // 刷新UI
    [self refreshUI];

    // 从网络加载数据
    [self loadDatas];
}

- (void)initObservers
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak FriendsReqViewController *safeSelf = self;

    // 列表数据模型变动观察者
    self.tableDatasObserver = ^(id observerble ,id data) {
//        DDLogDebug(@"[VerificationsViewController]收到\"消息\"列表UI数据更新通知了...(observerble=%@, data=%@)", observerble, data);
        // 刷新UI显示
        [safeSelf refreshUI];
    };
}


//-----------------------------------------------------------------------------------------------
#pragma mark - Table view delegate

// 表格行数（按时间分组，仅显示有数据的分组）
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.groupedSections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section < 0 || section >= (NSInteger)[self.groupedSections count]) return 0;
    return [(NSArray *)self.groupedSections[section][@"items"] count];
}

// 表格行高
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 68;
}

// 时间分组 section 标题（使用自定义样式，与列表内容区分）
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section < 0 || section >= (NSInteger)[self.groupedSections count]) return nil;
    return self.groupedSections[section][@"title"];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section < 0 || section >= (NSInteger)[self.groupedSections count]) return nil;
    NSString *title = self.groupedSections[section][@"title"];
    if (!title.length) return nil;

    CGFloat w = tableView.bounds.size.width;
    CGFloat h = 32.0f;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    header.backgroundColor = HexColor(0xF5F5F5);

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, w - 32, h)];
    label.text = title;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    label.textColor = HexColor(0x8E8E93);
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:label];

    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 32.0f;
}

// 表示行的UI显示内容
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FriendsReqCellValue *cellValue = [self cellValueForGroupedSection:indexPath.section row:indexPath.row];
    if (cellValue == nil) {
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    }

    //------------------------------------------------------ 【1】UI初始化
    UITableViewCell *theCell = nil;

    // 表格单元可重用ui
    static NSString *idenfity=@"CellMain";
    FriendsReqTableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:idenfity];
    if(cell==nil) {
        NSArray* arr = [[NSBundle mainBundle] loadNibNamed:@"FriendsReqTableViewCell" owner:self options:nil];
        for (id obj in arr) {
            if ([obj isKindOfClass:[FriendsReqTableViewCell class]]) {
                cell = (FriendsReqTableViewCell *)obj;
            }
        }
    }
    theCell = cell;

    // 表格单元选中时的颜色
    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cell.selectedBackgroundView.backgroundColor = UI_DEFAULT_TABLE_VIEW_SELECTED_BG_DARK_COLOR;
    // 为了跟表格背景色一致，cell的背景设为透明
    cell.backgroundColor=[UIColor clearColor];

    // 头像：50×50 圆形（与 FriendsReqTableViewCell.xib 一致）
    cell.viewAvatar.layer.cornerRadius = 25.f;
    cell.viewAvatar.layer.masksToBounds = YES;


    //------------------------------------------------------ 【2】UI值设置
    // 利表格单元对应的数据对象对ui进行设置
    cell.viewTitle.text = cellValue.userInfo.nickname;
    cell.viewMsgContent.text = cellValue.content;
    // 右侧：待处理显示时间；已通过显示「已通过」（参考微信的「已添加」）
    if ([cellValue.friendReqStatus isEqualToString:@"accepted_current"]) {
        cell.viewDate.text = @"已通过";
        cell.viewDate.textColor = [UIColor colorWithRed:0.55 green:0.55 blue:0.57 alpha:1.0];
    } else {
        cell.viewDate.text = [TimeTool getTimeStringAutoShort2:cellValue.date mustIncludeTime:NO timeWithSegment:NO];
        cell.viewDate.textColor = [UIColor colorWithRed:0.73 green:0.74 blue:0.76 alpha:1.0];
    }
    // 「对方发起、待我处理」时在列表直接显示同意+拒绝，不跳转验证请求页
    BOOL showAgreeReject = [cellValue.friendReqStatus isEqualToString:@"pending_in"];
    if (showAgreeReject) {
        cell.btnAgree.hidden = NO;
        cell.btnReject.hidden = NO;
        cell.viewArrowIco.superview.hidden = YES;
        cell.btnAgree.userInteractionEnabled = YES;
        cell.btnReject.userInteractionEnabled = YES;
        cell.btnAgree.tag = (NSInteger)(indexPath.section * 1000 + indexPath.row);
        cell.btnReject.tag = (NSInteger)(indexPath.section * 1000 + indexPath.row);
        [cell.btnAgree removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];
        [cell.btnReject removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];
        [cell.btnAgree addTarget:self action:@selector(clickAgreeInList:) forControlEvents:UIControlEventTouchUpInside];
        [cell.btnReject addTarget:self action:@selector(clickRejectInList:) forControlEvents:UIControlEventTouchUpInside];
    } else {
        cell.btnAgree.hidden = YES;
        cell.btnReject.hidden = YES;
        cell.viewArrowIco.superview.hidden = NO;
    }
    
    // 先设默认图标
    [cell.viewAvatar setImage:[UIImage imageNamed:@"default_avatar_yuan_50"]];

    // 以下代码用于设置要显示的图标
    BOOL needAvatar = NO;
    NSString *uidForAvatar = nil;
    NSString *fileNameForAvatar = nil;
    if(cellValue.userInfo != nil){
        //** 再来看看此人有无设置过头像
        // 此字段中存放的是用户对应的头像文件名，为空即表示没有设置头像，否则表示此人设置过头像
        fileNameForAvatar = cellValue.userInfo.userAvatarFileName;
        // 正式好友聊天消息时，用户信息里肯定会带着用户头像存放于服务端的文件
        // 名的，如果该字段为空即意味着该用户没有头像，那就不用尝试去服务端取
        // 用户头像了（它跟临天聊天消息的处理是不一样的哦）
        if(![BasicTool isStringEmpty:fileNameForAvatar]){
            needAvatar = YES;
            uidForAvatar = cellValue.userInfo.user_uid;
        } else if (![BasicTool isStringEmpty:cellValue.userInfo.user_uid]) {
            // 1008-4-31 列表无头像字段时：按 uid 拉取用户信息，拿到头像后再刷新该行
            [self requestAvatarIfNeededForUid:cellValue.userInfo.user_uid];
        }
    }


    //------------------------------------------------------【3】 按需载入用户头像（支持视频头像播放）
    if (needAvatar && uidForAvatar != nil) {
        [RBAvatarView setAvatarWithFileName:fileNameForAvatar uid:uidForAvatar onImageView:cell.viewAvatar placeholder:nil];
    }

    return theCell;
}


//-----------------------------------------------------------------------------------------------
#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexP
// 点击表格行：统一进入用户个人资料页，不再跳转验证请求页
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    FriendsReqCellValue *cellValue = [self cellValueForGroupedSection:indexPath.section row:indexPath.row];
    if (cellValue == nil) {
        [APP showToastWarn:@"此\"消息\"类型尚未实现！"];
        return;
    }
    if ([cellValue.friendReqStatus isEqualToString:@"pending_in"]) {
        return;
    }
    [QueryFriendInfoAsync gotoWatchUserInfo:cellValue.userInfo.user_uid withInfo:cellValue.userInfo nav:self.navigationController view:self.view vc:self];
}

// 左滑行显示「删除」按钮
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __weak typeof(self) weakSelf = self;
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                             title:@"删除"
                                                                           handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf removeFriendReqItemAtGroupedSection:section row:row];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 其它方法

/** 按分组取某 section 某 row 的 cellValue */
- (FriendsReqCellValue *)cellValueForGroupedSection:(NSInteger)section row:(NSInteger)row
{
    if (section < 0 || section >= (NSInteger)[self.groupedSections count]) return nil;
    NSArray *items = self.groupedSections[section][@"items"];
    if (row < 0 || row >= (NSInteger)[items count]) return nil;
    return items[row];
}

/** 从列表中移除指定 cellValue 的请求项并同步首页未读数 */
- (void)removeFriendReqItemByCellValue:(FriendsReqCellValue *)cellValue
{
    if (cellValue == nil || cellValue.userInfo == nil) return;
    NSArray *list = [self.verificationDatas getDataList];
    NSInteger index = -1;
    for (NSInteger i = 0; i < (NSInteger)[list count]; i++) {
        if ((FriendsReqCellValue *)list[i] == cellValue) {
            index = i;
            break;
        }
    }
    if (index < 0) return;
    NSString *uid = cellValue.userInfo.user_uid;
    [UserDefaultsToolKits markDeletedFriendReqUid:uid];
    [self.verificationDatas remove:index needNotify:YES];
    [[[IMClientManager sharedInstance] getAlarmsProvider] accumulateFlagNum:AMT_addFriendRequest dataId:nil withNum:-1];
    [[[IMClientManager sharedInstance] getFriendsReqProvider] addUnreadCount:-1 needNotify:YES];
    [NotificationCenterFactory processCompleteFriendReq_POST:uid];
    [self refreshUI];
}

/// 将请求标记为“已通过”并保留在列表中（显示历史记录），同时同步未读数
- (void)markFriendReqAcceptedByCellValue:(FriendsReqCellValue *)cellValue
{
    if (cellValue == nil || cellValue.userInfo == nil) return;
    cellValue.friendReqStatus = @"accepted_current";
    cellValue.unread = NO;
    cellValue.content = @"已添加为好友";
    [UserDefaultsToolKits unmarkDeletedFriendReqUid:cellValue.userInfo.user_uid ?: @""];
    [[[IMClientManager sharedInstance] getAlarmsProvider] accumulateFlagNum:AMT_addFriendRequest dataId:nil withNum:-1];
    [[[IMClientManager sharedInstance] getFriendsReqProvider] addUnreadCount:-1 needNotify:YES];
    [NotificationCenterFactory processCompleteFriendReq_POST:cellValue.userInfo.user_uid];
    [self refreshUI];
}

+ (void)markFriendReqDeleted:(NSString *)uid {
    [UserDefaultsToolKits markDeletedFriendReqUid:uid];
}

+ (BOOL)isFriendReqDeleted:(NSString *)uid {
    return [UserDefaultsToolKits isDeletedFriendReqUid:uid];
}

/** 按分组位置移除一条（左滑删除等） */
- (void)removeFriendReqItemAtGroupedSection:(NSInteger)section row:(NSInteger)row
{
    FriendsReqCellValue *cv = [self cellValueForGroupedSection:section row:row];
    [self removeFriendReqItemByCellValue:cv];
}

/** 当 1008-4-31 未返回头像时，按 uid 拉取用户信息并更新该行头像（去重：同一 uid 只请求一次） */
- (void)requestAvatarIfNeededForUid:(NSString *)uid
{
    if ([BasicTool isStringEmpty:uid]) return;
    @synchronized (self.requestedAvatarUids) {
        if ([self.requestedAvatarUids containsObject:uid]) return;
        [self.requestedAvatarUids addObject:uid];
    }
    __weak FriendsReqViewController *wself = self;
    [[HttpRestHelper sharedInstance] submitGetFriendInfoToServer:NO mail:nil uid:uid complete:^(BOOL sucess, UserEntity *userInfo) {
        @synchronized (wself.requestedAvatarUids) {
            [wself.requestedAvatarUids removeObject:uid];
        }
        if (!sucess || userInfo == nil || [BasicTool isStringEmpty:userInfo.userAvatarFileName]) return;
        // 找到该 uid 在分组中的 (section, row) 并更新对应 cellValue，刷新该行
        NSIndexPath *idx = nil;
        for (NSInteger s = 0; s < (NSInteger)[wself.groupedSections count]; s++) {
            NSArray *items = wself.groupedSections[s][@"items"];
            for (NSInteger r = 0; r < (NSInteger)[items count]; r++) {
                FriendsReqCellValue *cv = items[r];
                if (cv.userInfo != nil && [cv.userInfo.user_uid isEqualToString:uid]) {
                    cv.userInfo.userAvatarFileName = userInfo.userAvatarFileName;
                    if (![BasicTool isStringEmpty:userInfo.nickname]) cv.userInfo.nickname = userInfo.nickname;
                    idx = [NSIndexPath indexPathForRow:r inSection:s];
                    break;
                }
            }
            if (idx != nil) break;
        }
        if (idx != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself.tableView reloadRowsAtIndexPaths:@[idx] withRowAnimation:UITableViewRowAnimationNone];
            });
        }
    } hudParentView:nil];
}

// 列表内点击「同意」
- (void)clickAgreeInList:(UIButton *)sender
{
    NSInteger section = sender.tag / 1000;
    NSInteger row = sender.tag % 1000;
    FriendsReqCellValue *cellValue = [self cellValueForGroupedSection:section row:row];
    if (cellValue == nil || cellValue.userInfo == nil) return;
    UserEntity *ue = cellValue.userInfo;

    UserEntity *local = [IMClientManager sharedInstance].localUserInfo;
    int maxFriend = [BasicTool getIntValue:local.maxFriend defaultVal:1];
    if ([[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster:ue.user_uid]) {
        [APP showUserDefineToast_OK:@"此账号已经是你的好友了" atHide:nil];
        return;
    }
    if ([[[IMClientManager sharedInstance] getFriendsListProvider] size] >= maxFriend) {
        NSString *content = [NSString stringWithFormat:@"当前最多只允许拥有%d个好友, 您可删除不常联系的好友后再试", maxFriend];
        [BasicTool showAlertError:content parent:self];
        return;
    }

    CMDBody4ProcessFriendRequest *pfrm = [[CMDBody4ProcessFriendRequest alloc] init];
    pfrm.localUserUid = local.user_uid;
    pfrm.srcUserUid = ue.user_uid;
    pfrm.localUserNickName = local.nickname;

    int code = [MessageHelper sendProcessAdd_Friend_Req_B_To_Server_AGREEMessage:pfrm];
    if (code == COMMON_CODE_OK) {
        [APP showUserDefineToast_OK:@"已同意" atHide:nil];
        [self markFriendReqAcceptedByCellValue:cellValue];
    } else {
        [BasicTool showAlertError:[NSString stringWithFormat:@"出错了，错误码：%d", code] parent:self];
    }
}

// 列表内点击「拒绝」
- (void)clickRejectInList:(UIButton *)sender
{
    NSInteger section = sender.tag / 1000;
    NSInteger row = sender.tag % 1000;
    FriendsReqCellValue *cellValue = [self cellValueForGroupedSection:section row:row];
    if (cellValue == nil || cellValue.userInfo == nil) return;
    UserEntity *ue = cellValue.userInfo;

    UserEntity *local = [IMClientManager sharedInstance].localUserInfo;
    CMDBody4ProcessFriendRequest *pfrm = [[CMDBody4ProcessFriendRequest alloc] init];
    pfrm.localUserUid = local.user_uid;
    pfrm.srcUserUid = ue.user_uid;
    pfrm.localUserNickName = local.nickname;

    int code = [MessageHelper sendProcessAdd_Friend_Req_B_To_Server_REJECTMessage:pfrm];
    if (code == COMMON_CODE_OK) {
        [APP showUserDefineToast_OK:[NSString stringWithFormat:@"已拒绝 %@ 的好友请求", ue.nickname ?: ue.user_uid] atHide:nil];
        [self removeFriendReqItemByCellValue:cellValue];
    } else {
        [BasicTool showAlertError:[NSString stringWithFormat:@"拒绝失败，错误码：%d", code] parent:self];
    }
}

// 右上角「删除所有」：确认后清空列表并重置未读数
- (void)deleteAllFriendRequests:(id)sender
{
    NSInteger count = (NSInteger)[[self.verificationDatas getDataList] count];
    if (count <= 0) {
        [APP showToastWarn:@"当前没有好友请求"];
        return;
    }
    __weak typeof(self) wself = self;
    [BasicTool areYouSureAlert:@"确定清空所有好友请求？" content:nil okBtnTitle:@"清空" cancelBtnTitle:@"取消" parent:self okHandler:^(UIAlertAction *action) {
        NSArray *list = [wself.verificationDatas getDataList];
        for (FriendsReqCellValue *cv in list) {
            if (cv.userInfo.user_uid.length > 0) {
                [FriendsReqViewController markFriendReqDeleted:cv.userInfo.user_uid];
            }
        }
        [wself.verificationDatas clear:YES];
        [[[IMClientManager sharedInstance] getAlarmsProvider] resetAddFriendReqAlarmFlagNum];
        [[[IMClientManager sharedInstance] getFriendsReqProvider] clearUnreadCount:YES];
        [wself refreshUI];
        [APP showUserDefineToast_OK:@"已清空" atHide:nil];
    } cancelHandler:nil okActionStyle:UIAlertActionStyleDestructive cencelActionStyle:UIAlertActionStyleCancel];
}

// 按时间分组：从 verificationDatas 生成 groupedSections，仅包含有数据的分组（3天内、3天前、7天前…3年前）
- (void)rebuildGroupedSections
{
    NSArray *list = [self.verificationDatas getDataList];
    NSMutableArray<NSMutableArray<FriendsReqCellValue *> *> *buckets = [NSMutableArray arrayWithCapacity:8];
    for (NSInteger i = 0; i < 8; i++) {
        [buckets addObject:[NSMutableArray array]];
    }
    for (id obj in list) {
        FriendsReqCellValue *cv = (FriendsReqCellValue *)obj;
        NSInteger idx = friendReqTimeGroupIndexForDate(cv.date);
        if (idx >= 0 && idx < 8) [buckets[idx] addObject:cv];
    }
    NSArray *titles = kFriendReqTimeGroupTitles();
    NSMutableArray *result = [NSMutableArray array];
    for (NSInteger i = 0; i < 8; i++) {
        if ([buckets[i] count] > 0) {
            [result addObject:@{ @"title": titles[i], @"items": [buckets[i] copy] }];
        }
    }
    self.groupedSections = [result copy];
}

// 刷新UI，当列表数据为空时显示提示信息UI，否则显示列表
- (void)refreshUI
{
    [self rebuildGroupedSections];
    [self.tableView reloadData];

    if ([[self.verificationDatas getDataList] count] > 0) {
        self.tableView.hidden = NO;
        self.layoutTableEmptyHint.hidden = YES;
    } else {
        self.tableView.hidden = YES;
        self.layoutTableEmptyHint.hidden = NO;
    }
}

// 清除界面列表中指定的item：
// 用于好友请求处理界面回来时（用于通知前一个界面——即未处理验证通知列表界面中清除掉本条已处理完成的请求(而不需要再次从网络加载列表数据，提升体验））
- (void)clearAddFriendReqItems:(NSNotification*)notification
{
    NSDictionary *map = (NSDictionary *)notification.object;
    if(map == nil){
        [BasicTool showAlertError:@"无效数据 map=nil ！" parent:self];
        return;
    }

    // 要被移除的用户Uid
    NSString *uid = [map objectForKey:@"uid"];
    // 要被移除的通知类型（当前只处理了好友请求通知类型，日后支持的可能更多，比如群聊中的加群验证通知等）
    int msgType = [[NSString stringWithFormat:@"%@", map[@"msgType"]] intValue];

    DDLogDebug(@"################# back to FriendsReqViewCOntroller uid=%@, msgType=%d", uid, msgType);

    // 删除一个数组内容时应从尾往前删除哦（否则会出现经典逻辑bug哦）
    for(int i = (int)([[self.verificationDatas getDataList] count]) - 1; i >=0; i--) {
        FriendsReqCellValue *amd = (FriendsReqCellValue *)[self.verificationDatas get:i];
        if(amd.userInfo != nil && [amd.userInfo.user_uid isEqualToString:uid]) {
            // 先从列表中删除匹配到的该条item
            [self.verificationDatas remove:i needNotify:YES];
            // 首页“消息”界面中的“验证消息”未读数-1（此界面列表中的1个item其实就对应于首页消息里的未读数1）
            [[[IMClientManager sharedInstance] getAlarmsProvider] accumulateFlagNum:AMT_addFriendRequest dataId:nil withNum:-1];
            // 设置好友请求全局缓存中的总未读数
            [[[IMClientManager sharedInstance] getFriendsReqProvider] addUnreadCount:-1 needNotify:YES];
        }
    }
    [self refreshUI];
}

// 从网络加载列表数据（使用接口1008-4-31 添加好友记录总览，显示全部：待我处理/我发起的待对方处理/已是好友）
- (void)loadDatas
{
    NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid;
    if ([BasicTool isStringEmpty:localUid]) {
        [BasicTool showAlertError:@"数据加载失败！" parent:self];
        return;
    }

    [[HttpRestHelper sharedInstance] submitGetAllAddFriendRecordsToServer:localUid complete:^(BOOL sucess, NSArray<NSDictionary *> *records) {
        if (sucess && records != nil) {
            [self.verificationDatas clear:NO];
            [self.requestedAvatarUids removeAllObjects];

            if (records.count > 0) {
                long lastLatestReqTimestamp = [UserDefaultsToolKits getHasReadLatestFriendReqTimestamp];
                NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
                [fmt setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                [fmt setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];

                // 过滤不展示的账号（系统/测试账号等）
                NSSet<NSString *> *filteredUids = [NSSet setWithArray:@[@"10000", @"10001", @"400069", @"400070"]];

                for (NSDictionary *rec in records) {
                    NSString *status = [rec[@"status"] isKindOfClass:[NSString class]] ? rec[@"status"] : @"";
                    NSString *peer_uid = [rec[@"peer_uid"] isKindOfClass:[NSString class]] ? rec[@"peer_uid"] : @"";
                    if ([filteredUids containsObject:peer_uid]) continue;

                    NSString *peer_nickname = [rec[@"peer_nickname"] isKindOfClass:[NSString class]] ? rec[@"peer_nickname"] : @"";
                    NSString *be_desc = [rec[@"be_desc"] isKindOfClass:[NSString class]] ? rec[@"be_desc"] : @"";
                    NSString *add_source = [rec[@"add_source"] isKindOfClass:[NSString class]] ? rec[@"add_source"] : @"";
                    NSString *event_time_str = [rec[@"event_time"] isKindOfClass:[NSString class]] ? rec[@"event_time"] : @"";

                    NSDate *reqTime = nil;
                    if (event_time_str.length > 0) {
                        reqTime = [fmt dateFromString:event_time_str];
                    }
                    if (!reqTime) reqTime = [NSDate date];
                    long reqTimestamp = [TimeTool getTimeStampWithMillisecond_l:reqTime];

                    BOOL unread = NO;
                    if ([status isEqualToString:@"pending_in"] && reqTimestamp > lastLatestReqTimestamp) {
                        unread = YES;
                    }

                    NSString *content = [BasicTool trim:be_desc].length > 0 ? be_desc : @"请求加你为好友";
                    NSString *sourceText = [FriendsReqViewController addSourceDisplayText:add_source];
                    if (sourceText.length > 0) {
                        content = [NSString stringWithFormat:@"%@（%@）", content, sourceText];
                    }
                    if ([status isEqualToString:@"pending_out"]) {
                        content = @"等待对方验证";
                    } else if ([status isEqualToString:@"accepted_current"]) {
                        content = @"已添加为好友";
                    }

                    UserEntity *ue = [[UserEntity alloc] init];
                    ue.user_uid = peer_uid;
                    ue.nickname = peer_nickname.length > 0 ? peer_nickname : @"";
                    ue.ex1 = be_desc;
                    ue.ex11 = add_source;
                    ue.ex10 = [NSString stringWithFormat:@"%ld", reqTimestamp];
                    ue.ex12 = status;  // 供验证请求页区分：pending_out 时不显示拒绝/通过按钮

                    if ([status isEqualToString:@"pending_in"] || [status isEqualToString:@"accepted_current"]) {
                        [UserDefaultsToolKits unmarkDeletedFriendReqUid:peer_uid];
                    }
                    if ([FriendsReqViewController isFriendReqDeleted:peer_uid]) continue;

                    FriendsReqCellValue *cellValue = [[FriendsReqCellValue alloc] init];
                    cellValue.content = content;
                    cellValue.date = reqTime;
                    cellValue.unread = unread;
                    cellValue.userInfo = ue;
                    cellValue.friendReqStatus = status;

                    [self.verificationDatas add:cellValue];
                }

                // 按接口返回的 event_time 时间倒序排列（最新的在前）
                NSMutableArray *list = [self.verificationDatas getDataList];
                [list sortUsingComparator:^NSComparisonResult(FriendsReqCellValue *a, FriendsReqCellValue *b) {
                    NSDate *da = a.date ?: [NSDate dateWithTimeIntervalSince1970:0];
                    NSDate *db = b.date ?: [NSDate dateWithTimeIntervalSince1970:0];
                    return [db compare:da]; // 降序：时间晚的在前
                }];

                // 同步首页未处理好友请求：进入本页视为已读，未读数置 0（仅当列表非空时取首条，避免空列表 get:0 越界闪退）
                if ([list count] > 0) {
                    FriendsReqCellValue *firstCell = (FriendsReqCellValue *)[self.verificationDatas get:0];
                    UserEntity *latestRee = firstCell.userInfo;
                    NSDate *latestReqTime = firstCell.date;
                    if (latestRee != nil) {
                        [[[IMClientManager sharedInstance] getAlarmsProvider] addAddFriendReqMergeAlarm:latestRee.user_uid friendName:latestRee.nickname reqTime:latestReqTime numToAdd:0 notify:YES merge:NO];
                    }
                    [[[IMClientManager sharedInstance] getFriendsReqProvider] setUnreadCount:0 needNotify:YES];
                    if (latestReqTime != nil) {
                        [UserDefaultsToolKits setHasReadLatestFriendReqTimestamp:latestReqTime];
                    }
                } else {
                    [[[IMClientManager sharedInstance] getAlarmsProvider] resetAddFriendReqAlarmFlagNum];
                    [[[IMClientManager sharedInstance] getFriendsReqProvider] clearUnreadCount:YES];
                }
            } else {
                [[[IMClientManager sharedInstance] getAlarmsProvider] resetAddFriendReqAlarmFlagNum];
                [[[IMClientManager sharedInstance] getFriendsReqProvider] clearUnreadCount:YES];
            }
            [self refreshUI];
        } else {
            [self rb_loadOfflinePendingFriendReqs:localUid];
        }
    } hudParentView:self.view];
}

// 点击没有数据时的ui后进行的处理
- (void)gotoForEmptyOnClick:(UIView *)v
{
    // 进入"邀请朋友"界面
    [ViewControllerFactory goInviteFriendViewController:self.navigationController withMail:nil];
//    // 进入"查找/添加好友"界面
//    [ViewControllerFactory goFindFriendViewController:self.navigationController];
}

/**
 * 将添加来源枚举值（ex11）翻译为可读的中文文本。
 * @param addSource 原始枚举值（如 search_uid, card, group, qrcode 等）
 * @return 可读中文文本，未知来源返回 nil
 */
+ (NSString *)addSourceDisplayText:(NSString *)addSource
{
    if ([BasicTool isStringEmpty:[BasicTool trim:addSource]]) return nil;

    static NSDictionary *sourceMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sourceMap = @{
            @"search_uid"   : @"通过UID搜索",
            @"search_email" : @"通过邮箱搜索",
            @"search_phone" : @"通过手机号搜索",
            @"card"         : @"通过名片推荐",
            @"group"        : @"通过群聊",
            @"random"       : @"通过随机推荐",
            @"qrcode"       : @"通过扫描二维码",
            @"temp_chat"    : @"通过临时聊天",
        };
    });

    NSString *text = sourceMap[addSource];
    return text ?: nil;
}

@end
