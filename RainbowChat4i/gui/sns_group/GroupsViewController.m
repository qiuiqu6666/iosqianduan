//telegram @wz662
#import "GroupsViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"
#import "UIView+XYMenu.h"
#import "UserEntity.h"
#import "IMClientManager.h"
#import "GroupEntity.h"
#import "NotificationCenterFactory.h"
#import "FileDownloadHelper.h"
#import "IMClientManager.h"
#import "GroupsTableViewCell.h"
#import "UserDefaultsToolKits.h"
#import "ViewControllerFactory.h"
#import "AppDelegate.h"
#import "GroupCellDTO.h"
#import "HanziPinyin.h"

@interface GroupsViewController ()

/* 列表数据模型（形如<GroupEntity *>的1维数组） */
@property (nonatomic, retain) NSMutableArrayObservableEx *groupsDatas;
/** 数据模型变动观察者实现block */
@property (nonatomic, copy) ObserverCompletion tableDatasObserver;

/** 群组数据集合（该集合将群组数据按首字母进行聚合）*/
@property(nonatomic, strong) NSDictionary<NSString *, NSArray<GroupCellDTO *> *> *groupsWithLetter;
/** 群名称首字母集合（所有群名称首字母并按字母顺序进行排序并去重后的结果）*/
@property(nonatomic, strong) NSArray<NSString *> *firstLetters;
/** 数据载入中标识 */
@property(nonatomic, assign) BOOL loading;
/** 表格底部的提示信息控件 */
@property(nonatomic, strong) UILabel *tableFooterLabel;

@end


@implementation GroupsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.titleView = nil;
    self.navigationItem.rightBarButtonItems = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"群组"];
    [self groups_installPlainNavChromeRight];

    // 初始化界面
    [self initGUI];

    // 初始化数据
    [self initDatas];

    // 始化观察者
    [self initObservers];

    // 注册通知：重置群组头像缓存
    [NotificationCenterFactory resetGroupAvatarCache_ADD:self selector:@selector(clearGroupAvatarCache:)];
}

// "viewDidUnload:"方法已在ios6后被废弃（且它只在系统内存低时才被调用），资源释放等工作正确的方式是放到 "dealloc:"中处理
- (void)dealloc
//- (void)viewDidUnload
{
    // 取消注册通知：重置群组头像缓存
    [NotificationCenterFactory resetGroupAvatarCache_REMOVE:self];
//    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"[GroupsViewController]的viewWillAppear方法已被调用！");

    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];

    // 设置列表数据模型变动观察者
    [self.groupsDatas addObserver:self.tableDatasObserver];

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
    [self.groupsDatas removeObserver:self.tableDatasObserver];

    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

// @Override
- (void)initGUI
{
    // 表格基本设置（右侧 +/搜索 已挂到 RBChrome 顶栏，不再走 navigationItem）
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    // 设置搜索框 Header
    self.tableView.tableHeaderView = [self createSearchBarHeader];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    // 分隔线由 GroupsTableViewCell 内 hairline 绘制，比系统线更细；左起 68 与群名列对齐
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (@available(iOS 15, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    // 右侧字母索引的背景色（非透明，防止被 section header 背景遮盖）
    self.tableView.sectionIndexBackgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    self.tableView.sectionIndexColor = HexColor(0x4E4E4E);
    // 表格背景色
    self.tableView.backgroundColor = UI_DEFAULT_BG;
    // 表格分隔线的颜色
    self.tableView.separatorColor = UI_DEFAULT_TABLE_VIEW_DIVIDER_GRAY;

    // 在表格下方显示一个label，显示内容形如："99个群聊"
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(68, 0, self.tableView.frame.size.width, 0.5)];
    line.backgroundColor = HexColor(0xe8eaee);
    self.tableFooterLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 50)];
    self.tableFooterLabel.textAlignment = NSTextAlignmentCenter;
    self.tableFooterLabel.font = [BasicTool getSystemFontOfSize:14];
    self.tableFooterLabel.textColor = HexColor(0x979ca6);
    [self.tableFooterLabel addSubview:line];
    self.tableView.tableFooterView = self.tableFooterLabel;

    // 为列表为空的情况下加上点击事件
    UITapGestureRecognizer *tapGesturRecognizer=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(gotoCreateGroup:)];
    [self.layoutTableEmptyHint addGestureRecognizer:tapGesturRecognizer];
}

- (void)groups_installPlainNavChromeRight
{
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (!bar) {
        return;
    }
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 88, 44)];
    UIColor *iconTint = [UIColor blackColor];
    UIImage *searchImg = [UIImage imageNamed:@"alarms_search"];
    UIImage *addImg = [UIImage imageNamed:@"alarms_add_friends2"];
    if (searchImg) {
        searchImg = [searchImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    if (addImg) {
        addImg = [addImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    // 顺序：靠标题一侧为「搜索」，靠屏幕边缘为「+」
    UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [searchBtn setImage:searchImg forState:UIControlStateNormal];
    searchBtn.tintColor = iconTint;
    searchBtn.frame = CGRectMake(0, 0, 44, 44);
    [searchBtn addTarget:self action:@selector(groups_plainNavSearchTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [addBtn setImage:addImg forState:UIControlStateNormal];
    addBtn.tintColor = iconTint;
    addBtn.frame = CGRectMake(44, 0, 44, 44);
    if (@available(iOS 26.0, *)) {
        UIMenu *m = [self createMoresMenu_ios26];
        if (m) {
            addBtn.menu = m;
            addBtn.showsMenuAsPrimaryAction = YES;
        }
    }
    if (!@available(iOS 26.0, *) || addBtn.menu == nil) {
        [addBtn addTarget:self action:@selector(groups_plainNavAddTapped:) forControlEvents:UIControlEventTouchUpInside];
    }

    [container addSubview:searchBtn];
    [container addSubview:addBtn];
    [bar attachRightAccessoryView:container];
}

- (void)groups_plainNavAddTapped:(UIButton *)sender
{
    __weak typeof(self) ws = self;
    NSArray *imageArr = @[@"main_alarms_floatmenu_adduser", @"main_alarms_floatmenu_addgroup", @"main_alarms_floatmenu_scan"];
    NSArray *titleArr = @[@"添加好友", @"创建群聊", @"扫一扫"];
    [sender xy_showMenuWithImages:imageArr titles:titleArr menuType:XYMenuRightNavBar withItemClickIndex:^(NSInteger index) {
        __strong typeof(ws) selfStrong = ws;
        if (!selfStrong) {
            return;
        }
        if (index == 1) {
            [selfStrong gotoAddFriends];
        } else if (index == 2) {
            [selfStrong gotoCreateGroup];
        } else if (index == 3) {
            [selfStrong gotoScan];
        }
    }];
}

- (void)groups_plainNavSearchTapped:(UIButton *)sender
{
    [self doSearch:nil];
}

- (void)initDatas
{
    // 初始化数组
    self.groupsDatas = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupsListData];

    // 刷新UI
    [self refreshUI];
}

- (void)initObservers
{
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak GroupsViewController *safeSelf = self;

    // 列表数据模型变动观察者
    self.tableDatasObserver = ^(id observerble ,id data) {
        // 刷新UI显示
        [safeSelf refreshUI];
    };
}


//-----------------------------------------------------------------------------------------------
#pragma mark - Table view data source

// 表格中共有多少个section
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (self.firstLetters != nil ? self.firstLetters.count : 0);
}

// 每个section中有多少个cell
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.groupsWithLetter != nil && self.firstLetters != nil && section < [self.firstLetters count] && self.firstLetters[section] != nil) {
        NSArray *dataSource = self.groupsWithLetter[self.firstLetters[section]];
        return dataSource.count;
    } else {
        return 0;
    }
}

// 每个section对应的标题集合（右侧快速索引）
- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.firstLetters;
}

// section标题的高度
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20;
}

// section标题的显示内容
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = nil;
    if (self.firstLetters != nil && section < [self.firstLetters count]) {
        title = self.firstLetters[section];
    }
    
    if (title == nil || title.length == 0) {
        return nil;
    }

    // section标题栏父布局
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 20)];
    view.backgroundColor = HexColor(0xf5f7fa);
    // section标题栏文本组件（用于显示首字母的）
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, self.view.frame.size.width, 20)];
    label.font = [BasicTool getSystemFontOfSize:12.0f];
    label.textColor = HexColor(0x979ca6);
    label.textAlignment = NSTextAlignmentLeft;
    label.text = [NSString stringWithFormat:@"%@", title];
    [view addSubview:label];
    return view;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return index;
}

// 设置表格右边的快速索引ui
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
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

// 表格行高
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (@available(iOS 26, *)) {
        return 60;
    } else {
        return 68;
    }
}

// 表示行的UI显示内容
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.groupsWithLetter == nil || self.firstLetters == nil || indexPath.section >= [self.firstLetters count]) {
        DDLogDebug(@"【GroupsViewController】tableView:cellForRowAtIndexPath中，无效的参数1！");
        return [[UITableViewCell alloc] init];
    }
    
    GroupEntity *ree = nil;
    NSArray<GroupCellDTO *> *groupsInSection = self.groupsWithLetter[self.firstLetters[indexPath.section]];
    if (groupsInSection != nil && [groupsInSection count] > 0 && indexPath.row < [groupsInSection count]) {
        GroupCellDTO *gcdto = groupsInSection[indexPath.row];
        if (gcdto != nil) {
            ree = gcdto.groupInfo;
        }
    }
    
    if (ree == nil) {
        DDLogDebug(@"【GroupsViewController】tableView:cellForRowAtIndexPath中，取出的 GroupEntity=nil！");
        return [[UITableViewCell alloc] init];
    }

    //------------------------------------------------------ 【1】UI初始化
    // 表格单元可重用ui
    static NSString *idenfity = @"CellMain";
    GroupsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:idenfity];
    if (cell == nil) {
        NSArray* arr = [[NSBundle mainBundle] loadNibNamed:@"GroupsTableViewCell" owner:self options:nil];
        for (id obj in arr) {
            if ([obj isKindOfClass:[GroupsTableViewCell class]]) {
                cell = (GroupsTableViewCell *)obj;
            }
        }
    }

    // 表格单元选中时的颜色
    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cell.selectedBackgroundView.backgroundColor = UI_DEFAULT_TABLE_VIEW_SELECTED_BG_COLOR;
    // 为了跟表格背景色一致，cell的背景设为透明
    cell.backgroundColor = [UIColor clearColor];

    // 群头像：40×40 圆形（与 GroupsTableViewCell.xib 一致）
    cell.viewGroupIcon.layer.cornerRadius = 20.f;
    cell.viewGroupIcon.layer.masksToBounds = YES;
    NSString *previousBoundGroupId = cell.rb_boundGroupId;
    BOOL keepCurrentGroupAvatar = (ree.g_id.length > 0 && [previousBoundGroupId isEqualToString:ree.g_id] && cell.viewGroupIcon.image != nil);
    cell.rb_boundGroupId = ree.g_id;


    //------------------------------------------------------ 【2】UI值设置
    cell.viewGroupName.text = ree.g_name;
    cell.viewMemberCount.text = [NSString stringWithFormat:@"(%@人)", ree.g_member_count];
    cell.viewOwnerIcon.hidden = ([GroupsProvider isGroupOwner:ree.g_owner_user_uid] ? NO : YES);
    cell.viewCreateTime.text = [NSString stringWithFormat:@"创建于：%@", ree.create_time];
    // 消息提示是否静音的图标显示
    cell.viewSilentIcon.hidden = ([UserDefaultsToolKits isChatMsgToneOpen:ree.g_id] ? YES : NO);
    // 同一 gid 重绑时保留当前真实头像，避免列表刷新时先闪回默认群头像。
    if (!keepCurrentGroupAvatar) {
        [cell.viewGroupIcon setImage:[UIImage imageNamed:@"groupchat_groups_icon_default"]];
    }

    // 尝试为群组加载群头像
    __weak GroupsTableViewCell *weakCell = cell;
    NSString *gid = [ree.g_id copy];
    [FileDownloadHelper loadGroupAvatar:gid logTag:@"GroupsViewController"
                               complete:^(BOOL sucess, UIImage *img) {
                                   if (!sucess || img == nil) return;
                                   void (^applyAvatar)(void) = ^{
                                       GroupsTableViewCell *visibleCell = weakCell;
                                       if (visibleCell && [visibleCell.rb_boundGroupId isEqualToString:gid]) {
                                           [visibleCell.viewGroupIcon setImage:img];
                                       }
                                   };
                                   if ([NSThread isMainThread]) {
                                       applyAvatar();
                                   } else {
                                       dispatch_async(dispatch_get_main_queue(), applyAvatar);
                                   }
                               }];

    BOOL isLastSection = (self.firstLetters.count > 0) && (indexPath.section == (NSInteger)self.firstLetters.count - 1);
    BOOL hideBottomSep = NO;
    if (isLastSection) {
        NSArray *g = self.groupsWithLetter[self.firstLetters[indexPath.section]];
        hideBottomSep = (g != nil && indexPath.row == (NSInteger)g.count - 1);
    }
    [cell rb_setHairlineBottomSeparatorHidden:hideBottomSep];

    return cell;
}


//-----------------------------------------------------------------------------------------------
#pragma mark - Table view delegate

// 点击表格行时要调用的方法
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.groupsWithLetter == nil || self.firstLetters == nil || indexPath.section >= [self.firstLetters count]) {
        return;
    }
    
    NSArray<GroupCellDTO *> *groupsInSection = self.groupsWithLetter[self.firstLetters[indexPath.section]];
    if (groupsInSection != nil && indexPath.row < [groupsInSection count]) {
        GroupCellDTO *gcdto = groupsInSection[indexPath.row];
        if (gcdto != nil && gcdto.groupInfo != nil) {
            GroupEntity *amd = gcdto.groupInfo;
            // 进入群聊界面：勿 popToRoot，否则会把本页（通讯录式群组列表）从栈里清掉，返回键落到通讯录根而非群组列表
            [ViewControllerFactory goGroupChattingViewController:self.navigationController gid:amd.g_id gname:amd.g_name animated:YES popToRootFirst:NO highlight:nil];
        }
    }
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 数据处理方法

// 加载群组数据到界面的表格中（包括：将原始数据转换、生成拼音、按拼音首字母排序并分组等）
- (void)reloadGroupsData:(NSArray *)groupList {
    
    __weak typeof(self) safeSelf = self;
    
    if (groupList != nil && [groupList count] > 0) {
        self.loading = YES;
        // 异步线程中执行，提升体验
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSMutableDictionary *resultDic = [GroupCellDTO fromGroupInfos:groupList];
            // 回到主线程处理ui显示
            dispatch_async(dispatch_get_main_queue(), ^{
                if (resultDic != nil) {
                    safeSelf.groupsWithLetter = (NSDictionary<NSString *, NSArray<GroupCellDTO *> *> *)resultDic[@"groupsWithLetter"];
                    safeSelf.firstLetters = (NSArray<NSString *> *)resultDic[@"firstLetters"];
                    
                    // 统计有效群组数（排除世界频道）
                    int validCount = 0;
                    for (NSString *key in safeSelf.groupsWithLetter) {
                        validCount += (int)[safeSelf.groupsWithLetter[key] count];
                    }
                    [safeSelf.tableFooterLabel setText:[NSString stringWithFormat:@"%d个群聊", validCount]];
                    
                    [safeSelf.tableView reloadData];
                    safeSelf.loading = NO;
                } else {
                    safeSelf.firstLetters = @[];
                    [safeSelf.tableFooterLabel setText:@"暂无群聊"];
                    [safeSelf.tableView reloadData];
                }
            });
        });
    } else {
        self.firstLetters = @[];
        [self.tableFooterLabel setText:@"暂无群聊"];
        [self.tableView reloadData];
    }
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 其它方法

// 刷新UI，当列表数据为空时显示提示信息UI，否则显示列表
- (void)refreshUI
{
    DDLogDebug(@"【群组列表界面】界面刷新了哦！！！！！！！！！！！");

    NSArray *dataList = [[self.groupsDatas getDataList] copy];
    
    // 刷新表格有数据与无数据时的UI显示
    if ([dataList count] > 0)
    {
        self.tableView.hidden = NO;
        self.layoutTableEmptyHint.hidden = YES;
    }
    else
    {
        self.tableView.hidden = YES;
        self.layoutTableEmptyHint.hidden = NO;
    }
    
    // 处理群组数据并生成UI界面需要的数据结构
    [self reloadGroupsData:dataList];
}

- (void)gotoCreateGroup:(UIBarButtonItem *)sender
{
    [GroupsViewController gotoCreateGroup:self.navigationController defaultSelectedUid:nil];
}

// 尝试从图片缓存中清除指定群组的头像缓存（以便下次刷新列表时能及时显示最新的群头像）.
- (void) clearGroupAvatarCache:(NSNotification*)notification
{
    NSString *gid = (NSString *)notification.object;
    DDLogDebug(@"【群组列表界面】-收到重置群组%@头像缓存的通知！", gid);
    if(gid != nil)
        [FileDownloadHelper clearGroupAvatarCache:gid];
}

// 获得下载指定群组头像的完整http地址（不带自定义头像参数，使用系统默认头像URL）.
+ (NSString *) getGroupAvatarDownloadURL:(NSString *)gid
{
    return [GroupsViewController getGroupAvatarDownloadURL:gid customAvatar:nil];
}

// 获得下载指定群组头像的完整http地址（支持自定义群头像）.
+ (NSString *) getGroupAvatarDownloadURL:(NSString *)gid customAvatar:(NSString *)customAvatar
{
    NSString *fileURL = nil;
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;

    if(localUserInfo != nil)
    {
        // 优先使用自定义群头像
        if(customAvatar != nil && customAvatar.length > 0)
        {
            // 自定义群头像通过 MsgImageUploader 上传，存储在图片目录中，使用 image_d 下载
            fileURL = [NSString stringWithFormat:@"%@?action=image_d&user_uid=%@&file_name=%@"
                        , BBONERAY_DOWNLOAD_CONTROLLER_URL_ROOT
                        , localUserInfo.user_uid
                        , customAvatar];
        }
        else
        {
            // 系统自动生成的九宫格群头像
            fileURL = [NSString stringWithFormat:@"%@?action=gavartar_d&user_uid=%@&file_name=%@.jpg"
                        , BBONERAY_DOWNLOAD_CONTROLLER_URL_ROOT
                        , localUserInfo.user_uid
                        , gid];
        }
    }

    return fileURL;
}

+ (void)gotoCreateGroup:(UINavigationController *)nv defaultSelectedUid:(NSString *)defaultSelectedUid
{
    [ViewControllerFactory goGroupMemberViewController:nv usedFor:USED_FOR_CREATE_GROUP gid:nil isGroupOwner:YES defaultSelectedUid:defaultSelectedUid];
}

@end
