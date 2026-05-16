//telegram @wz662
#import "ContactViewController.h"
#import "IMClientManager.h"
#import "ContactTableViewCell.h"
#import "ClientCoreSDK.h"
#import "ChatBaseEventImpl.h"
#import "ClientCoreSDK.h"
#import "ChatDataHelper.h"
#import "ViewControllerFactory.h"
#import "BasicTool.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "LPActionSheet.h"
#import "UIBarButtonItem+XYMenu.h"
#import "AlarmType.h"
#import "NotificationCenterFactory.h"
#import "FriendCellDTO.h"
#import "FriendReqTableViewCell.h"
#import "AddFriendTableViewCell.h"
#import "MyGroupsTableViewCell.h"
#import "QueryFriendInfoAsync.h"
#import "UIViewController+RBAlarmsStyleMainTabNav.h"

/// 通讯录底部「N个好友」统计：不含 10000、10001、400069、400070（与 `BasicTool isSystemAdmin:` 一致）
static NSInteger rb_contactFriendCountExcludingSystemAccounts(NSArray<UserEntity *> *users) {
    if (users.count == 0) return 0;
    NSInteger n = 0;
    for (UserEntity *u in users) {
        NSString *uid = u.user_uid;
        if (uid.length > 0 && ![BasicTool isSystemAdmin:uid])
            n++;
    }
    return n;
}


@interface ContactViewController ()

/** 好友列表数据模型变动观察者实现block */
@property (nonatomic, copy) ObserverCompletion friendsDataObserver;
/** 好友的上线下观察者（此观察者通常用于上下线的情况下普通ui的通知的展现等）.  */
@property (nonatomic, copy) ObserverCompletion friendsLiveStatusChangeObs;
/** 添加至IMClientManger中的全局好友请求未读数缓存的变动观察者 */
@property (nonatomic, copy) ObserverCompletion unreadCountChangedObserver;

/** 好友数据集合（该集合将好友数据按首字母进行聚合（相同首字母的放入同个数组中））*/
@property(nonatomic, strong) NSDictionary<NSString *, NSArray<FriendCellDTO *> *> *friendsWithLetter;
/** 好友昵称首字母集合（所有好友昵称首字母并按字母顺序进行排序并去重后的结果）*/
@property(nonatomic, strong) NSArray<NSString *> *firstLetters;
/** 数据载入中标识，用于防止重复的加载请求 */
@property(nonatomic, assign)BOOL loading;
/** 表格底部：好友数文案 + 无好友时「添加好友」 */
@property(nonatomic, strong) UIView *contactFooterContainer;
@property(nonatomic, strong) UILabel *contactFooterLabel;
@property(nonatomic, strong) UIButton *contactFooterAddFriendButton;
/** 供旋转/布局后重算 footer 宽度 */
@property(nonatomic, assign) int rb_cachedContactFooterFriendCount;
/** 官方账号列表（显示在好友列表顶部，不参与字母排序） */
@property(nonatomic, strong) NSArray<UserEntity *> *officialAccounts;

@property(nonatomic, strong) NSTimer *onlineDurationTimer;

@end


@implementation ContactViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 初始化GUI
    [self initGUI];
    // 初始化观察者
    [self initObservers];
    // 注册通知：修改完成好友的备注后
    [NotificationCenterFactory friendRemarkChanged_ADD:self selector:@selector(friendRemarkChangedComplete:)];
}

// 根据UIViewController的生命周期，本方法将在每次本界面每次回到前台时被调用
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_alarmsStyleMainTabNavHostViewWillAppear:animated];
    // 底部 Tab 切换时先完成切换再执行观察者与刷新，避免主线程阻塞导致切换“很慢”
    __weak typeof(self) wself = self;
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{
        [wself rb_performViewWillAppearWork];
    });
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_alarmsStyleMainTabNavHostViewDidAppear:animated];
    [self rb_startOnlineDurationTimerIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self rb_alarmsStyleMainTabNavHostViewWillDisappear:animated];
    [self rb_stopOnlineDurationTimer];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self rb_alarmsStyleMainTabNavHostViewDidLayoutSubviews];
    if (self.contactFooterContainer != nil) {
        [self rb_setContactFooterFriendCount:self.rb_cachedContactFooterFriendCount];
    }
}

- (void)rb_performViewWillAppearWork
{
    [[[[IMClientManager sharedInstance] getFriendsListProvider] getFriendsData] addObserver:self.friendsDataObserver];
    [[IMClientManager sharedInstance] setLiveStatusChangeObs:self.friendsLiveStatusChangeObs];
    [[[IMClientManager sharedInstance] getFriendsReqProvider] addUnreadChangedObserver:self.unreadCountChangedObserver];
    [self refreshTable];
}

- (void)rb_startOnlineDurationTimerIfNeeded
{
    if (self.onlineDurationTimer != nil) return;
    self.onlineDurationTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(rb_tickOnlineDurationTimer) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.onlineDurationTimer forMode:NSRunLoopCommonModes];
}

- (void)rb_stopOnlineDurationTimer
{
    if (self.onlineDurationTimer == nil) return;
    [self.onlineDurationTimer invalidate];
    self.onlineDurationTimer = nil;
}

- (void)rb_tickOnlineDurationTimer
{
    if (self.tableView.window == nil) return;
    NSArray<NSIndexPath *> *paths = [self.tableView indexPathsForVisibleRows];
    if (paths.count == 0) return;
    [UIView performWithoutAnimation:^{
        [self.tableView reloadRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
    }];
}

- (NSString *)rb_formatOnlineDuration:(NSString *)onlineStartTime
{
    long long ms = [onlineStartTime longLongValue];
    if (ms <= 0) return @"在线";
    NSTimeInterval sec = ([NSDate date].timeIntervalSince1970 * 1000.0 - (double)ms) / 1000.0;
    if (sec < 60.0) return @"刚刚上线";
    NSInteger minutes = (NSInteger)(sec / 60.0);
    NSInteger hours = minutes / 60;
    NSInteger days = hours / 24;
    if (days > 0) {
        NSInteger h = hours % 24;
        if (h > 0) return [NSString stringWithFormat:@"%ld天%ld小时", (long)days, (long)h];
        return [NSString stringWithFormat:@"%ld天", (long)days];
    }
    if (hours > 0) {
        NSInteger m = minutes % 60;
        if (m > 0) return [NSString stringWithFormat:@"%ld小时%ld分钟", (long)hours, (long)m];
        return [NSString stringWithFormat:@"%ld小时", (long)hours];
    }
    return [NSString stringWithFormat:@"%ld分钟", (long)minutes];
}

- (NSString *)rb_formatLastSeenForOffline:(NSString *)timestamp
{
    if([BasicTool isStringEmpty:timestamp])
        return @"";
    
    NSDate *lastDate = [TimeTool convertJavaTimestampToiOSDate:timestamp];
    if(lastDate == nil)
        return @"";
    
    NSTimeInterval seconds = [[NSDate date] timeIntervalSinceDate:lastDate];
    if(seconds < 60)
        return @"刚刚在线";
    
    long minutes = (long)(seconds / 60);
    if(minutes < 60)
        return [NSString stringWithFormat:@"%ld分钟前在线", minutes];
    
    long hours = (long)(minutes / 60);
    if(hours < 24)
        return [NSString stringWithFormat:@"%ld小时前在线", hours];
    
    long days = (long)(hours / 24);
    if(days < 30)
        return [NSString stringWithFormat:@"%ld天内曾上线", days];
    
    if(days < 60)
        return @"一个月内曾上线";
    
    return @"很久没上线";
}

- (void)viewDidDisappear:(BOOL)animated
{
    // 取消设置好友列表数据模型变动观察者
    [[[[IMClientManager sharedInstance] getFriendsListProvider] getFriendsData] removeObserver:self.friendsDataObserver];
    // 取消设置好友上下线状态观察者
    [[IMClientManager sharedInstance] setLiveStatusChangeObs:nil];
    // 从IMClientManger中的全局好友请求未读数缓存上清除数据变动观察者
    [[[IMClientManager sharedInstance] getFriendsReqProvider] removeUnreadChangedObserver:self.unreadCountChangedObserver];

    [super viewDidDisappear:animated];
}

// “viewDidUnload:”方法已在ios6后被废弃（且它只在系统内存低时才被调用），资源释放等工作正确的方式是放到 “dealloc:"中处理
- (void)dealloc
{
    // 取消注册通知：修改完成好友的备注后的广播
    [NotificationCenterFactory friendRemarkChanged_REMOVE:self];
}

// @Override
- (void)initGUI
{
    [super initGUI];
    self.navigationItem.rightBarButtonItems = nil;

    [self rb_installAlarmsStyleMainTabNavigationBarWithLocalizedTitleKey:@"main_tabs_title_roster"];

//    // 添加导航栏右边的“更多”按钮（无背景图标样式）  @"common_more_ico"
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"roster_list_add_friend"]
//                                                                              style:UIBarButtonItemStylePlain
//                                                                             target:self
//                                                                             action:@selector(doOpenMoreFunctions:)];

    // 表格基本设置
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    // 设置搜索框 Header
    self.tableView.tableHeaderView = [self createSearchBarHeader];
    // 让表格行分隔线从左边指定像素处绘制
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 67, 0, 0);
    // 表格的背景色
    self.tableView.backgroundColor = UI_DEFAULT_BG;
    // 表格分隔线的颜色
    self.tableView.separatorColor = UI_DEFAULT_TABLE_VIEW_DIVIDER_GRAY;
    // 针对ios 26的优化：ios 26上这个分隔显示的又粗颜色又深，干脆就不要显示分隔线了
    if (@available(iOS 26, *)) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    if (@available(iOS 15, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    // 右侧字母索引的背景色（非透明，防止被 section header 背景遮盖）
    self.tableView.sectionIndexBackgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    self.tableView.sectionIndexColor = HexColor(0x4E4E4E);
    
    [self rb_setupContactTableFooter];
}

- (void)rb_setupContactTableFooter
{
    if (self.contactFooterContainer != nil) return;
    CGFloat w = CGRectGetWidth(self.tableView.bounds);
    if (w < 1) w = CGRectGetWidth([UIScreen mainScreen].bounds);
    UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 50)];
    c.backgroundColor = [UIColor clearColor];
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(67, 0, w, 0.5)];
    line.backgroundColor = HexColor(0xe8eaee);
    line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [c addSubview:line];

    UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(0, 14, w, 22)];
    lab.textAlignment = NSTextAlignmentCenter;
    lab.font = [BasicTool getSystemFontOfSize:14];
    lab.textColor = HexColor(0x979ca6);
    lab.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [c addSubview:lab];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"添加好友" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    btn.frame = CGRectMake(0, 42, w, 40);
    btn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    btn.hidden = YES;
    [btn addTarget:self action:@selector(rb_contactFooterAddFriendTapped) forControlEvents:UIControlEventTouchUpInside];
    [c addSubview:btn];

    self.contactFooterContainer = c;
    self.contactFooterLabel = lab;
    self.contactFooterAddFriendButton = btn;
    self.tableView.tableFooterView = c;
    [self rb_setContactFooterFriendCount:0];
}

- (void)rb_setContactFooterFriendCount:(int)cnt
{
    self.rb_cachedContactFooterFriendCount = cnt;
    if (self.contactFooterContainer == nil) {
        [self rb_setupContactTableFooter];
    }
    BOOL noFriends = cnt <= 0;
    self.contactFooterLabel.text = noFriends ? @"暂无好友" : [NSString stringWithFormat:@"%d个好友", cnt];
    self.contactFooterAddFriendButton.hidden = !noFriends;
    CGFloat w = CGRectGetWidth(self.tableView.bounds);
    if (w < 1) w = CGRectGetWidth([UIScreen mainScreen].bounds);
    CGFloat h = noFriends ? 92 : 50;
    self.contactFooterContainer.frame = CGRectMake(0, 0, w, h);
    if (noFriends) {
        self.contactFooterLabel.frame = CGRectMake(0, 12, w, 22);
        self.contactFooterAddFriendButton.frame = CGRectMake(0, 40, w, 44);
    } else {
        self.contactFooterLabel.frame = CGRectMake(0, 0, w, 50);
    }
    self.tableView.tableFooterView = self.contactFooterContainer;
}

- (void)rb_contactFooterAddFriendTapped
{
    [ViewControllerFactory goFindFriendViewController:self.navigationController];
}

// 与 AlarmsViewController 消息列表一致：搜索框整体下移，避免贴紧自定义顶栏
- (UIView *)createSearchBarHeader
{
    UIView *originalHeader = [super createSearchBarHeader];
    if (!originalHeader) {
        return nil;
    }
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

- (void)initObservers
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;

    // 好友列表数据模型变动观察者
    self.friendsDataObserver = ^(id observerble ,id data) {
        DDLogDebug(@"【ContactViewController】收到好友列表UI数据更新通知了...(observerble=%@, UpdateTypeToObserverADD=%ld, data=%@)", observerble, (long)UpdateTypeToObserverADD, data);

        // 刷新表格数据显示
        [safeSelf refreshTable];
    };

    // 好友上下线状态变动观察者
    self.friendsLiveStatusChangeObs = ^(id observerble ,id data) {
        if(data != nil){
            // 根据约定：data中传递的是String数组，目前长度=3：第0元素是好友昵称、第1单元是在线状态（0表示下线、1表示上线）、第2单元是好友的uid
            NSArray *ii = (NSArray *)data;

            NSString *nickName =  [ii objectAtIndex:0];
            NSString *status = [ii objectAtIndex:1];
            NSString *friendUid = [ii objectAtIndex:2];

            // 无论如何，只要有状态变动就及时刷新表格UI
//          [safeSelf refreshTable];
            [safeSelf.tableView reloadData];

            // 上线了
            if([status isEqualToString:[NSString stringWithFormat:@"%d", LIVE_STATUS_ONLINE]])
                DDLogDebug(@"【ContactViewController】好友%@(%@)上线了！", nickName, friendUid);
            // 下线了
            else if([status isEqualToString:[NSString stringWithFormat:@"%d", LIVE_STATUS_OFFLINE]])
                DDLogDebug(@"【ContactViewController】好友%@(%@)下线了。", nickName, friendUid);
        } else {
            DDLogDebug(@"【ContactViewController】好友上下线状态变动观察者收到传递过来的data==nil！");
        }
    };
    
    // 全局好友请求未读数的变动观察者
    self.unreadCountChangedObserver = ^(id observerble, id data) {
        long unreadCount = (data != nil)? ((NSInteger)data) : 0;
        DDLogDebug(@"【ContactViewController】全局好友请求未读数观察者通知：data==%lu，马上刷新ui显示！", unreadCount);
        // 刷新表格中的固定的表格行——“好友请求”上显示的未处理好友请求数量的ui显示
        [safeSelf refreshUnreadFriendsReqCount];
    };
}


#pragma mark - Table view delegate

// 每个section中有多少个cell
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // 0 section里放的是几个固定的cell（好友请求、添加好友、群组）
    if (section == 0) {
        return 3;
    } else {
        // 数据结构边界判断很重要，保持代码健壮性
        if(self.friendsWithLetter != nil && self.firstLetters != nil && section < [self.firstLetters count] && self.firstLetters[section] != nil){
            NSArray *dataSource = self.friendsWithLetter[self.firstLetters[section]];
            return dataSource.count;
        } else {
            DDLogDebug(@"【ContactViewController】tableView:numberOfRowsInSection中，无效的参数！(allFriendSectionDic=%@, allKeys=%@, section=%ld, allKeys[section]=%@)", self.friendsWithLetter, self.firstLetters, (long)section, (self.firstLetters != nil? self.firstLetters[section]:nil));
            return 0;
        }
    }
}

// 表格中共有多少个section
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (self.firstLetters != nil ? self.firstLetters.count : 0);
}

// 每个section对应的标题集合（右侧字母索引栏，过滤掉 "☆"）
-(NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    if (self.firstLetters == nil) return nil;
    NSMutableArray *filtered = [NSMutableArray array];
    for (NSString *letter in self.firstLetters) {
        if (![letter isEqualToString:@"☆"]) {
            [filtered addObject:letter];
        }
    }
    return filtered;
}

// 点击右侧索引时，映射到正确的 section
- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    if (self.firstLetters == nil) return 0;
    NSUInteger sectionIndex = [self.firstLetters indexOfObject:title];
    return (sectionIndex != NSNotFound) ? sectionIndex : 0;
}

// section标题的高度
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    // 固定的那几个cell就不需要显示标题栏了
    if(section == 0)
        return 0;
    // 好友信息的cell才需要显示标题栏
    return 20;
}

// section标题的显示内容
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title;
    if (section == 0) {
        title = nil;
    } else if (self.firstLetters != nil && section < self.firstLetters.count
               && [self.firstLetters[section] isEqualToString:@"☆"]) {
        title = @"星标好友";
    } else {
        title = self.firstLetters[section];
    }
    
    if (title == nil || title.length == 0) {
        return nil;
    }

    // section标题栏父布局
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 20)];
    view.backgroundColor = HexColor(0xf5f7fa);
    CGFloat labelLeft = 16.0f;
    // 星标分组左侧显示黄色星形图标
    if ([title isEqualToString:@"星标好友"]) {
        UIImage *starImage = [UIImage imageNamed:@"contact_star"];
        if (starImage) {
            CGFloat iconSize = 28.0f;
            UIImageView *starIcon = [[UIImageView alloc] initWithFrame:CGRectMake(16, (20 - iconSize) / 2.0f, iconSize, iconSize)];
            starIcon.image = starImage;
            starIcon.contentMode = UIViewContentModeScaleAspectFit;
            [view addSubview:starIcon];
            labelLeft = 16.0f + iconSize + 4.0f;
        }
    }
    // section标题栏文本组件（用于显示首字母的）
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(labelLeft, 0, self.view.frame.size.width - labelLeft, 20)];
    label.font = [BasicTool getSystemFontOfSize:14.0f];
    label.textColor = HexColor(0x979ca6);
    label.textAlignment = NSTextAlignmentLeft;
    label.text = [NSString stringWithFormat:@"%@", title];
    [view addSubview:label];
    return view;
}

// 设置表格右边的快速索引ui
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    // 设置表格右边快捷索引组件的ui效果（可以设置的属性有限，参考资料：https://www.jianshu.com/p/112c6a6338d5/
    // ，备选方案：https://blog.csdn.net/zyx612423zyx/article/details/74980351）
    for (UIView *subview in [tableView subviews]) {
        if ([subview isKindOfClass:[NSClassFromString(@"UITableViewIndex") class]]) {
            CGFloat adjustedSize = [BasicTool getAdjustedFontSize:12.0];
            [subview setValue:[UIFont systemFontOfSize:adjustedSize weight:UIFontWeightRegular] forKey:@"_font"];
            [subview setValue:HexColor(0x4E4E4E) forKey:@"_indexColor"];
            // ★ 用 layer.zPosition 确保字母索引渲染在 section header 之上
            subview.layer.zPosition = 999;
            break;
        }
    }
}

// 数据cell的高度
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

// 表格cell的ui显示相关设置
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *theCell = nil;
    
    // 固定的几个表格单元
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            theCell = [self tableCell:tableView withIdenfity:@"friendReqCell" xibName:@"FriendReqTableViewCell" c:[FriendReqTableViewCell class]];
            if(theCell != nil){
                FriendReqTableViewCell *frtCell = (FriendReqTableViewCell *)theCell;
                // 示处理好友请求意数
                int unreadFriendsReqCount = [[[IMClientManager sharedInstance] getFriendsReqProvider] getUnreadCount];
                // 角标数字显示文本处理
                NSString *mBadgeText = [BasicTool getBadgeViewString:unreadFriendsReqCount];
                
                [frtCell.viewFlagNum2 setBadgeValue:mBadgeText];
                frtCell.viewFlagNum2.hidden = (unreadFriendsReqCount <= 0);
            }
        } else if(indexPath.row == 1) {
            theCell = [self tableCell:tableView withIdenfity:@"addFriendCell" xibName:@"AddFriendTableViewCell" c:[AddFriendTableViewCell class]];
        } else {
            theCell = [self tableCell:tableView withIdenfity:@"myGroupsCell" xibName:@"MyGroupsTableViewCell" c:[MyGroupsTableViewCell class]];
        }
    }
    // 好友信息表格单元
    else {
        if(self.friendsWithLetter == nil || self.firstLetters == nil || indexPath.section >= [self.firstLetters count]){
            DDLogDebug(@"【ContactViewController】tableView:cellForRowAtIndexPath中，无效的参数1！(allFriendSectionDic=%@, allKeys=%@, indexPath.section=%lu, allKeys.count=%lu", self.friendsWithLetter, self.firstLetters, indexPath.section, (self.firstLetters != nil? [self.firstLetters count]:0));
            return nil;
        }

        UserEntity *ree = nil;
        NSArray<FriendCellDTO *> *friendsWithLetter = self.friendsWithLetter[self.firstLetters[indexPath.section]];
        if(friendsWithLetter != nil && [friendsWithLetter count] > 0 && indexPath.row < [friendsWithLetter count]){
            FriendCellDTO *friendCellDTO = friendsWithLetter[indexPath.row];
            if(friendCellDTO != nil){
                ree = friendCellDTO.friendInfo;
            } else {
                DDLogDebug(@"【ContactViewController】tableView:cellForRowAtIndexPath中，无效的参数2：取出的friendCellDTO=nil ！(friendsWithLetter=%@, friendsWithLetter.count=%lu, indexPath.row=%lu)", friendsWithLetter, [friendsWithLetter count], indexPath.row);
            }
        } else {
            DDLogDebug(@"【ContactViewController】tableView:cellForRowAtIndexPath中，无效的参数3！(friendsWithLetter=%@, friendsWithLetter.count=%lu, indexPath.row=%lu)", friendsWithLetter, [friendsWithLetter count], indexPath.row);
            return nil;
        }
        
        // 表格单元可重用ui
        id cellInstance = [self tableCell:tableView withIdenfity:@"friendCell" xibName:@"ContactTableViewCell" c:[ContactTableViewCell class]];
        if(cellInstance == nil){
            DDLogDebug(@"【ContactViewController】tableView:cellForRowAtIndexPath中，cellInstance=nil！(indexPath.section=%lu, indexPath.row=%lu)", indexPath.section, indexPath.row);
            return nil;
        }
        ContactTableViewCell *cell = (ContactTableViewCell *)cellInstance;
        theCell = cell;
        
        // 通讯录列表头像：xib 中为 40×40，圆角半径取半边长即为圆形
        CGFloat avatarSide = MIN(CGRectGetWidth(cell.viewAvadar.bounds), CGRectGetHeight(cell.viewAvadar.bounds));
        if (avatarSide <= 0) {
            avatarSide = 40.f;
        }
        cell.viewAvadar.layer.cornerRadius = avatarSide * 0.5f;
        cell.viewAvadar.layer.masksToBounds = YES;
        
        // 表格单元选中时的颜色
        cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
        cell.selectedBackgroundView.backgroundColor = UI_DEFAULT_TABLE_VIEW_SELECTED_BG_COLOR;
        // 为了跟表格背景色一致，cell的背景设为透明
        cell.backgroundColor=[UIColor clearColor];
        
        BOOL isOfficialAccount = [BasicTool isSystemAdmin:ree.user_uid];
        cell.viewNickname2.attributedText = [BasicTool attributedName:[ree getNickNameWithRemark]
                                                  appendOfficialBadge:isOfficialAccount
                                                                 font:(cell.viewNickname2.font ?: [UIFont systemFontOfSize:17.0f])
                                                            textColor:(cell.viewNickname2.textColor ?: [UIColor blackColor])
                                                          badgeHeight:15.0f];
        
        // 隐藏旧的在线/离线状态标签
        cell.viewFlagStatus.hidden = YES;
        
        if (isOfficialAccount) {
            // 官方账号：隐藏副标题，昵称垂直居中
            cell.viewLastSeen.hidden = YES;
            for (NSLayoutConstraint *c in cell.viewNickname2.superview.constraints) {
                if (c.firstItem == cell.viewNickname2 && c.firstAttribute == NSLayoutAttributeTop) {
                    c.constant = 20; // (60 - 20) / 2 = 20，使昵称在60高的cell中垂直居中
                    break;
                }
            }
        }
        else {
            // 非官方账号：恢复副标题显示和昵称位置
            cell.viewLastSeen.hidden = NO;
            for (NSLayoutConstraint *c in cell.viewNickname2.superview.constraints) {
                if (c.firstItem == cell.viewNickname2 && c.firstAttribute == NSLayoutAttributeTop) {
                    c.constant = 11; // 恢复xib中的默认top偏移
                    break;
                }
            }
        }
        
        // 昵称下方显示最近上线时间（相对时间），官方账号不显示
        if (!isOfficialAccount) {
            if (ree.liveStatus == LIVE_STATUS_ONLINE)
            {
                cell.viewLastSeen.text = [self rb_formatOnlineDuration:ree.onlineStartTime];
                cell.viewLastSeen.textColor = HexColor(0x4CD9A5);
            }
            else
            {
                NSString *ts = ree.offlineTime;
                if (ts.length == 0) ts = ree.latest_login_time;
                NSString *lastSeenText = [self rb_formatLastSeenForOffline:ts];
                if (lastSeenText.length == 0)
                    lastSeenText = @"离线";
                cell.viewLastSeen.text = lastSeenText;
                cell.viewLastSeen.textColor = HexColor(0x999999);
            }
        }
        
        // 支持视频头像播放
        [RBAvatarView setAvatarWithFileName:ree.userAvatarFileName uid:ree.user_uid onImageView:cell.viewAvadar placeholder:[UIImage imageNamed:@"default_avatar_for_chattingui_40"]];
        
//      // 删除按钮点击事件
//      [cell.btnDel addTarget:self action:@selector(doDeleteFriend:) forControlEvents:UIControlEventTouchUpInside];
//      // 将行索引号保存到tag里，在点击事件里就可以取到了
//      cell.btnDel.tag = indexPath.section;//[ree.user_uid intValue];
    }
    
    return theCell;
}


#pragma mark - Table view delegate

// 点击表格行时要调用的方法
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 点的是固定的几个cell 或 官方账号
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            // 进入好友请求列表管理界面
            [ViewControllerFactory goVerificationsViewController:self.navigationController];
        } else if(indexPath.row == 1) {
            // 进入查找好友界面
            [ViewControllerFactory goFindFriendViewController:self.navigationController];
        } else if(indexPath.row == 2) {
            // 进入"我的群组"界面
            [ViewControllerFactory goGroupsViewController:self.navigationController];
        }
        return;
    }
    // 点击的是好友cell或官方账号cell
    else {
        if(self.friendsWithLetter == nil || self.firstLetters == nil || indexPath.section >= [self.firstLetters count]){
            DDLogDebug(@"【ContactViewController】tableView:didSelectRowAtIndexPath中，无效的数据1！(friendsWithLetter=%@, firstLetters=%@, indexPath.section=%lu, indexPath.row=%lu, firstLetters.count=%lu", self.friendsWithLetter, self.firstLetters, indexPath.section, indexPath.row,(self.firstLetters != nil? [self.firstLetters count]:0));
            return;
        }
        
        NSArray<FriendCellDTO *> *friendsWithLetter = self.friendsWithLetter[self.firstLetters[indexPath.section]];
        FriendCellDTO *friendCellDTO = friendsWithLetter[indexPath.row];
        if(friendCellDTO != nil){
        UserEntity *friendInfo = friendCellDTO.friendInfo;
            if(friendInfo != nil){
        BOOL isOfficialAccount = [BasicTool isSystemAdmin:friendInfo.user_uid];
                
                if (isOfficialAccount) {
                    if ([BasicTool isOfficialAccountHideAvatarInChat:friendInfo.user_uid]) {
                        [ViewControllerFactory goOfficialAccountChatViewController:friendInfo.user_uid nickname:[friendInfo getNickNameWithRemark] toNav:self.navigationController popToRootFirst:NO highlight:nil];
                    } else {
                        [ViewControllerFactory goChatViewController:friendInfo.user_uid andNickname:[friendInfo getNickNameWithRemark] toNav:self.navigationController popToRootFirst:NO highlight:nil];
                    }
                } else {
                    // 普通好友：直接带本地好友数据进入资料页，避免转圈；资料页内可自行拉最新
                    [QueryFriendInfoAsync gotoWatchUserInfo:friendInfo.user_uid withInfo:friendInfo nav:self.navigationController view:self.view vc:self];
                }
            } else {
                DDLogDebug(@"【ContactViewController】tableView:didSelectRowAtIndexPath中，无效的数据2：取出的friendInfo=nil，cell点击事件无法继续处理！");
            }
        } else {
            DDLogDebug(@"【ContactViewController】tableView:didSelectRowAtIndexPath中，无效的数据3：取出的friendCellDTO=nil ！(friendsWithLetter=%@, friendsWithLetter.count=%lu, indexPath.row=%lu)", friendsWithLetter, [friendsWithLetter count], indexPath.row);
        }
    }
}


#pragma mark - 其它方法

// 刷新表格中的固定的表格行——“好友请求”上显示的未处理好友请求数量的ui显示
- (void)refreshUnreadFriendsReqCount{
    NSIndexPath *indexPath_1=[NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView reloadRowsAtIndexPaths:@[indexPath_1] withRowAnimation:UITableViewRowAnimationNone];
}

//// 获取可重用的table cell
//- (id)tableCell:(UITableView *)tableView withIdenfity:(NSString *)idenfity xibName:(NSString *)xibName c:(Class)c {
//    id cell = [tableView dequeueReusableCellWithIdentifier:idenfity];
//    if(cell == nil) {
//        NSArray* arr = [[NSBundle mainBundle] loadNibNamed:xibName owner:self options:nil];
//        for (id obj in arr) {
//            if ([obj isKindOfClass:c]) {
//                cell = obj;
//            }
//        }
//    }
//    
//    return cell;
//}

// 加载好友数据到界面的表格中（其它逻辑包括：将原始的好友数据转换成本列表中的数据、生成昵称字母和拼音、按拼音首字母排序并集合等）
- (void)reloadFriendsData:(NSArray<UserEntity *> *)friendList {
    
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    NSMutableArray<UserEntity *> *normalFriendList = [NSMutableArray array];
    if (friendList != nil) {
        [normalFriendList addObjectsFromArray:friendList];
    }
    self.officialAccounts = @[];
    // 星标好友单独成组，置顶显示，不参与字母排序
    NSMutableArray<UserEntity *> *starredList = [NSMutableArray array];
    NSMutableArray<UserEntity *> *nonStarredList = [NSMutableArray array];
    for (UserEntity *user in normalFriendList) {
        if ([user.is_starred isEqualToString:@"1"]) {
            [starredList addObject:user];
        } else {
            [nonStarredList addObject:user];
        }
    }
    friendList = nonStarredList;
    
    if(friendList != nil && [friendList count] > 0){
        // 重置加载标识（防止重复加载）
        self.loading = YES;
        // 异步线程中执行，提升体验
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            // 仅对非星标好友按首字母分组排序；星标好友单独一组显示在最上方
            NSMutableDictionary *resultDic = [FriendCellDTO fromUserInfos:friendList];
            dispatch_async(dispatch_get_main_queue(), ^{
                if(resultDic != nil){
                    NSMutableDictionary<NSString *, NSMutableArray<FriendCellDTO *> *> *friendsDic = (NSMutableDictionary *)resultDic[@"friendsWithLetter"];
                    NSMutableArray<NSString *> *letters = (NSMutableArray *)resultDic[@"firstLetters"];
                    
                    // ☆ 星标好友单独一组，紧接在官方账号后、字母分组前，不按字母排序
                    if (starredList.count > 0) {
                        NSMutableArray<FriendCellDTO *> *starredDTOs = [NSMutableArray array];
                        for (UserEntity *user in starredList) {
                            FriendCellDTO *dto = [FriendCellDTO fromUserInfo:user];
                            dto.firstLetter = @"☆";
                            [starredDTOs addObject:dto];
                        }
                        [friendsDic setObject:starredDTOs forKey:@"☆"];
                        if (![letters containsObject:@"☆"]) {
                            [letters insertObject:@"☆" atIndex:1];
                        }
                    }
                    
                    safeSelf.friendsWithLetter = friendsDic;
                    safeSelf.firstLetters = letters;
                    
                    int footerFriendCount = (int)rb_contactFriendCountExcludingSystemAccounts(friendList)
                        + (int)rb_contactFriendCountExcludingSystemAccounts(starredList);
                    [safeSelf rb_setContactFooterFriendCount:footerFriendCount];
                    
                    // 刷新表格显示
                    [safeSelf.tableView reloadData];
                    // 重置加载标识
                    safeSelf.loading = NO;
                    
    //              [self.activityIndicator stopAnimating];
    //              self.activityIndicator.hidden = YES;
                } else {
                    // 加入一个空的letter，否则section为0的那几个固定cell是无法在tableView中显示的（因为无数据无法触到tableview的delegate方法）
                    safeSelf.firstLetters = @[@""];
                    // 显示无好友的提示信息
                    [safeSelf rb_setContactFooterFriendCount:0];
                    // 刷新表格ui
                    [safeSelf.tableView reloadData];
                }
            });
        });
    } else {
        // 无普通（非星标）好友，但可能有星标好友
        NSMutableDictionary<NSString *, NSMutableArray<FriendCellDTO *> *> *friendsDic = [NSMutableDictionary dictionary];
        NSMutableArray<NSString *> *letters = [NSMutableArray arrayWithObject:@"↑"];
        NSUInteger totalCount = 0;
        if (starredList.count > 0) {
            NSMutableArray<FriendCellDTO *> *starredDTOs = [NSMutableArray array];
            for (UserEntity *user in starredList) {
                FriendCellDTO *dto = [FriendCellDTO fromUserInfo:user];
                dto.firstLetter = @"☆";
                [starredDTOs addObject:dto];
            }
            [friendsDic setObject:starredDTOs forKey:@"☆"];
            [letters addObject:@"☆"];
            totalCount += (NSUInteger)rb_contactFriendCountExcludingSystemAccounts(starredList);
        }
        if (friendsDic.count > 0) {
            self.friendsWithLetter = friendsDic;
            self.firstLetters = letters;
            [self rb_setContactFooterFriendCount:(int)totalCount];
        } else {
            self.firstLetters = @[@""];
            [self rb_setContactFooterFriendCount:0];
        }
        [self.tableView reloadData];
    }
}

// 加载数据并刷新表格的ui显示
- (void)refreshTable
{
    DDLogDebug(@"【好友列表界面】列表数据刷新了哦！");

    int friendsCount = (int)[[[[[IMClientManager sharedInstance] getFriendsListProvider] getFriendsData] getDataList] count];
    // 刷新表格有数据与无数据时的UI显示
    if (friendsCount <= 0) {
        [self rb_setContactFooterFriendCount:0];
    }
    
    // 处理好友数据并生成UI界面需要的数据结构（生成拼音、取首字母、按首字母进行聚合并排序等）
    NSArray<UserEntity *> *friendOriginalDatas = (NSArray<UserEntity *> *)[[[[IMClientManager sharedInstance] getFriendsListProvider] getFriendsData] getDataList];
    [self reloadFriendsData:friendOriginalDatas];
}

// 点击“打开礼品包”按钮时调用的方法
- (void)doOpenGiftsPackage
{
    [BasicTool showAlertInfo:@"RainbowChat的iOS版暂未实现礼品功能，无法打开礼品包裹哦！" parent:self];
}

// 点击“更多”按钮时调用的方法
- (void)doOpenMoreFunctions:(UIBarButtonItem *)sender
{
    NSArray *imageArr = @[@"roster_more_ivnvite_ico", @"roster_more_adduser_ico"];
    NSArray *titleArr = @[@"邀请朋友", @"添加好友"];
    
    // 显示一个仿微信的的顶部弹出菜单（选中的index是从1开始的哦）
    [sender xy_showMenuWithImages:imageArr titles:titleArr menuType:XYMenuRightNavBar currentNavVC:self.navigationController withItemClickIndex:^(NSInteger index) {
        if(index == 1){
            // 进入“邀请朋友”界面
            [ViewControllerFactory goInviteFriendViewController:self.navigationController withMail:nil];
        }
        else if(index == 2){
            // 进入“查找/添加好友“界面
            [ViewControllerFactory goFindFriendViewController:self.navigationController];
        }
    }];
}


#pragma mark - 其它实用方法

// 提交一个网络请求：从好友列表中删除好友。
+ (void) doDeleteFriendImpl:(UIView *)parentView uidWillBeDelete:(NSString *)uid complete:(void (^)(BOOL sucess))complete
{
    // 提交http删除请求到服务器
    [[HttpRestHelper sharedInstance] submitDeleteFriendToServer:[[IMClientManager sharedInstance] localUserInfo].user_uid friend:uid complete:^(BOOL sucess) {
        // 删除成功
        if(sucess) {
            // 新逻辑：删除好友只移出好友列表，不删除会话与聊天记录。
            FriendsListProvider *rp = [[IMClientManager sharedInstance] getFriendsListProvider];
            if([rp remove:[rp getIndex:uid] uid:uid notify:YES]){
                if(complete)
                    complete(YES);
            }
        }
        // 删除失败
        else {
            if(complete)
                complete(NO);
        }
    } hudParentView:parentView];
}

// 别的界面中对好友备注等信息更新完后，本界面中要做的事，这是通过通知实现的
- (void)friendRemarkChangedComplete:(NSNotification*)notification
{
    UserEntity *latestRee = (UserEntity *)notification.object;
    
    NSString *friendUid = latestRee.user_uid;
    NSString *friendNicknameWithRemark = [latestRee getNickNameWithRemark];
    DDLogDebug(@"【好友备注更新】好友列表界面收到 (friendUid=%@，friendNicknameWithRemark=%@) 已修改完成的通知！", friendUid, friendNicknameWithRemark);
    
    // 当列表中存在该好友的item时才刷新（不要浪费性能嘛）
    if([[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmIndex:AMT_friendChatMessage dataId:friendUid] != -1) {
        // 更新列表
        [self refreshTable];
    }
}

#pragma mark - 格式化"多久未上线"

/// 将 Java 时间戳（毫秒）格式化：在线 / X分钟前曾上线 / X小时前曾上线 / X天内曾上线 / 一个月内曾上线 / 很久没上线
- (NSString *)formatLastSeenTime:(NSString *)javaTimestamp
{
    if([BasicTool isStringEmpty:javaTimestamp])
        return @"";
    
    NSDate *lastDate = [TimeTool convertJavaTimestampToiOSDate:javaTimestamp];
    if(lastDate == nil)
        return @"";
    
    NSTimeInterval seconds = [[NSDate date] timeIntervalSinceDate:lastDate];
    
    if(seconds < 60)
        return @"在线";
    
    long minutes = (long)(seconds / 60);
    if(minutes < 60)
        return [NSString stringWithFormat:@"%ld分钟前在线", minutes];
    
    long hours = (long)(minutes / 60);
    if(hours < 24)
        return [NSString stringWithFormat:@"%ld小时前在线", hours];
    
    long days = (long)(hours / 24);
    if(days < 30)
        return [NSString stringWithFormat:@"%ld天内曾上线", days];
    
    if(days < 60)
        return @"一个月内曾上线";
    
    return @"很久没上线";
}

@end
