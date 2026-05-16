//telegram @wz662
#import "GroupMemberViewController.h"
#import "NSMutableArrayObservableEx.h"
#import "BasicTool.h"
#import "AppDelegate.h"
#import "GroupMemberEntity.h"
#import "UserEntity.h"
#import "GroupMemberTableViewCell.h"
#import "GroupsProvider.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "QueryFriendInfoAsync.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "GChatDataHelper.h"
#import "ViewControllerFactory.h"
#import "GroupsViewController.h"
#import "AppDelegate.h"
#import "NotificationCenterFactory.h"
#import "MBProgressHUD.h"
#import "HanziPinyin.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"
#import "CreateGroupProfileViewController.h"


//#define OK_BUTTON_BACKGROUP_IMG_NAME_NORMAL      @"n_common_btn_red_normal"


@interface GroupMemberViewController () <UITextFieldDelegate>

/* 列表数据模型（形如<GroupMemberEntity *>的1维数组） */
@property (nonatomic, retain) NSMutableArrayObservableEx *groupsDatas;
/* 数据模型变动观察者实现block */
@property (nonatomic, copy) ObserverCompletion tableDatasObserver;

/** 传进来的参数：本界面的用途 */
@property (nonatomic, assign) int usedForForInit;
/** 传进来的参数：本参数在 {@link #usedForForInit}==USED_FOR_CREATE_GROUP 时无意义 */
@property (nonatomic, retain) NSString *gidForInit;
/** 传进来的参数：打开本界面的是否是本群群主 */
@property (nonatomic, assign) BOOL isGroupOwnerForInit;
/** 传进来的参数：表示默认选中的uid，本参数当前主要用于{@link #usedForForInit}==USED_FOR_CREATE_GROUP 时 */
@property (nonatomic, retain) NSString *defaultSelectedUidForInit;

/** 当前用户在群中的角色：0=普通成员，1=管理员，2=群主。
 *  在 USED_FOR_VIEW_OR_MANAGER_MEMBERS 模式下从服务端成员列表中动态识别。 */
@property (nonatomic, assign) int myRoleInGroup;

// 是否显示选择框
@property (nonatomic, assign) BOOL showCheckBox;
// 是否支持单选
@property (nonatomic, assign) BOOL singleSelection;

@property (nonatomic, retain) UIButton *btnOK;

// ========== 搜索 + 字母索引相关 ==========
@property (nonatomic, strong) UITextField *searchTextField;
/** 是否启用字母索引（仅创建群和邀请入群模式启用） */
@property (nonatomic, assign) BOOL enableAlphabetIndex;
/** 是否正在搜索 */
@property (nonatomic, assign) BOOL isSearching;

/** 按字母分组后的数据：key=字母, value=该字母下的 GroupMemberEntity 数组 */
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<GroupMemberEntity *> *> *membersWithLetter;
/** 排序后的首字母数组 */
@property (nonatomic, strong) NSArray<NSString *> *firstLetters;
/** 搜索结果（扁平数组） */
@property (nonatomic, strong) NSArray<GroupMemberEntity *> *filteredDatas;

@end

@implementation GroupMemberViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil usedFor:(int)usedFor gid:(NSString *)gid isGroupOwner:(BOOL)isGroupOwner defaultSelectedUid:(NSString *)defaultSelectedUid
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.usedForForInit = usedFor;
        self.gidForInit = gid;
        self.isGroupOwnerForInit = isGroupOwner;
        self.defaultSelectedUidForInit = defaultSelectedUid;

        self.showCheckBox = YES;
        self.singleSelection = NO;

        DDLogDebug(@"【群成员查看】Intent传进来的参数：usedForForInit=%d, gidForInit=%@, isGroupOwnerForInit=%d"
                   , self.usedForForInit, self.gidForInit, self.isGroupOwnerForInit);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 初始化界面
    [self initGUI];

    // 始化观察者
    [self initObservers];

    // 初始化数据
    [self initDatas];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];

    // 设置列表数据模型变动观察者
    [self.groupsDatas addObserver:self.tableDatasObserver];

    // 刷新UI
    [self refreshUI:YES];
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

- (void)rb_groupMemberSyncPlainChromeNav
{
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @""];
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (!bar) {
        return;
    }
    if (self.btnOK.hidden) {
        [bar clearRightAccessorySubviews];
    } else {
        [bar attachRightAccessoryView:self.btnOK];
    }
}

- (void)initGUI
{
    // 表格基本设置
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    // 去掉空白行的显示
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    // 让表格行分隔线从左边指定像素处绘制
    [self.tableView setSeparatorInset:UIEdgeInsetsMake(0, 72, 0, 0)];
    // 表格背景色
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

    // ok按钮
//  self.btnOK = [self createCunstomNavigationBuntton:[self getStretchImageForSaveButton:OK_BUTTON_BACKGROUP_IMG_NAME_NORMAL] action:@selector(doSave:)];
    self.btnOK = [GroupMemberViewController createCunstomNavigationBuntton];
    [self.btnOK addTarget:self action:@selector(doSave:) forControlEvents:UIControlEventTouchUpInside];
    // 设置ok按钮的初始状态
    [self _setOkButtonEnable:NO];

    // 根据界面用途，进行相关设置
    if(self.usedForForInit == USED_FOR_CREATE_GROUP)
    {
        self.title = @"创建群组";
        self.btnOK.hidden = NO;
        
        self.showCheckBox = YES;
        self.enableAlphabetIndex = YES;
        [self createSearchBarHeader];
    }
    else if(self.usedForForInit == USED_FOR_VIEW_OR_MANAGER_MEMBERS)
    {
        // 管理员或群主（可以删除群员）
        if(self.isGroupOwnerForInit || self.myRoleInGroup >= 1)
        {
            self.title = @"管理群员";
            self.btnOK.hidden = NO;
            
            self.showCheckBox = YES;
        }
        // 普通群员（只能查看群组成员）
        else
        {
            self.title = @"查看群员";
            self.btnOK.hidden = YES;
            self.showCheckBox = NO;
        }
        
        self.enableAlphabetIndex = YES;
        [self createSearchBarHeader];
    }
    else if(self.usedForForInit == USED_FOR_INVITE_MEMBERS)
    {
        self.title = @"邀请入群";
        self.btnOK.hidden = NO;
        
        self.enableAlphabetIndex = YES;
        [self createSearchBarHeader];
    }
    else if(self.usedForForInit == USED_FOR_TRANSFER)
    {
        self.title = @"选择新群主";
        self.btnOK.hidden = NO;
        
        self.singleSelection = YES;
        self.enableAlphabetIndex = YES;
        [self createSearchBarHeader];
    }
    else if(self.usedForForInit == USED_FOR_SET_ADMIN)
    {
        self.title = @"设置管理员";
        self.btnOK.hidden = NO;
        
        self.singleSelection = YES;
        self.enableAlphabetIndex = YES;
        [self createSearchBarHeader];
    }
    else if(self.usedForForInit == USED_FOR_CANCEL_ADMIN)
    {
        self.title = @"取消管理员";
        self.btnOK.hidden = NO;
        
        self.singleSelection = YES;
        self.enableAlphabetIndex = YES;
        [self createSearchBarHeader];
    }
    else if(self.usedForForInit == USED_FOR_SELECT_FOR_WALLET_TRANSFER)
    {
        self.title = @"选择收款人";
        self.btnOK.hidden = NO;
        
        self.singleSelection = YES;
        self.enableAlphabetIndex = YES;
        [self createSearchBarHeader];
    }

    [self rb_groupMemberSyncPlainChromeNav];
}

- (void)initDatas
{
    // 初始化数组
    self.groupsDatas = [[NSMutableArrayObservableEx alloc] init];

    // 刷新UI
    [self refreshUI:YES];

    // 加载数据（从网络或全局数据模型中）
    [self loadDatas];
}

#pragma mark - 搜索框 + 字母索引

// 创建搜索框（添加到 tableHeaderView）
- (void)createSearchBarHeader
{
    CGFloat headerHeight = 60;
    CGFloat vPadding = 8;
    
    UIView *headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, headerHeight)];
    headerContainer.backgroundColor = [UIColor clearColor];
    
    // 搜索框外部圆角背景
    UIView *searchBg = [[UIView alloc] init];
    searchBg.translatesAutoresizingMaskIntoConstraints = NO;
    searchBg.backgroundColor = HexColor(0xF5F7FA);
    searchBg.layer.cornerRadius = (headerHeight - vPadding * 2) / 2.0;
    searchBg.layer.masksToBounds = YES;
    [headerContainer addSubview:searchBg];
    
    // 搜索图标
    UIImageView *searchIcon = [[UIImageView alloc] init];
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
        searchIcon.image = [[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    searchIcon.tintColor = HexColor(0x979CA6);
    searchIcon.contentMode = UIViewContentModeScaleAspectFit;
    [searchBg addSubview:searchIcon];
    
    // 搜索输入框
    UITextField *tf = [[UITextField alloc] init];
    tf.translatesAutoresizingMaskIntoConstraints = NO;
    tf.delegate = self;
    tf.placeholder = @"搜索";
    tf.font = [UIFont systemFontOfSize:15];
    tf.textColor = [UIColor blackColor];
    tf.backgroundColor = [UIColor clearColor];
    tf.borderStyle = UITextBorderStyleNone;
    tf.returnKeyType = UIReturnKeySearch;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    [tf addTarget:self action:@selector(searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [searchBg addSubview:tf];
    
    // 约束
    [NSLayoutConstraint activateConstraints:@[
        // 搜索框背景
        [searchBg.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor constant:16],
        [searchBg.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor constant:-16],
        [searchBg.topAnchor constraintEqualToAnchor:headerContainer.topAnchor constant:vPadding],
        [searchBg.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor constant:-vPadding],
        
        // 搜索图标
        [searchIcon.leadingAnchor constraintEqualToAnchor:searchBg.leadingAnchor constant:12],
        [searchIcon.centerYAnchor constraintEqualToAnchor:searchBg.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:18],
        [searchIcon.heightAnchor constraintEqualToConstant:18],
        
        // 搜索输入框
        [tf.leadingAnchor constraintEqualToAnchor:searchIcon.trailingAnchor constant:8],
        [tf.trailingAnchor constraintEqualToAnchor:searchBg.trailingAnchor constant:-12],
        [tf.topAnchor constraintEqualToAnchor:searchBg.topAnchor],
        [tf.bottomAnchor constraintEqualToAnchor:searchBg.bottomAnchor],
    ]];
    
    self.searchTextField = tf;
    self.tableView.tableHeaderView = headerContainer;
}

// 搜索文字变化
- (void)searchTextChanged:(UITextField *)textField
{
    NSString *keyword = textField.text;
    if ([BasicTool isStringEmpty:keyword]) {
        self.isSearching = NO;
        self.filteredDatas = nil;
    } else {
        self.isSearching = YES;
        [self filterDataWithSearchText:keyword];
    }
    [self.tableView reloadData];
}

// 搜索过滤
- (void)filterDataWithSearchText:(NSString *)searchText
{
    NSString *lowered = [searchText lowercaseString];
    NSMutableArray *results = [NSMutableArray array];
    
    for (GroupMemberEntity *m in [self.groupsDatas getDataList]) {
        NSString *name = [GroupsProvider getNickNameInGroup:m.nickname and:m.nickname_ingroup] ?: @"";
        NSString *uid = m.user_uid ?: @"";
        NSString *pinyin = [HanziPinyin pinyinOfHanzi:name] ?: @"";
        
        if ([[name lowercaseString] containsString:lowered]
            || [[uid lowercaseString] containsString:lowered]
            || [[pinyin lowercaseString] containsString:lowered]) {
            [results addObject:m];
        }
    }
    self.filteredDatas = results;
}

// 将 groupsDatas 按昵称首字母分组
- (void)rebuildAlphabetSections
{
    NSArray<GroupMemberEntity *> *allMembers = [self.groupsDatas getDataList];
    if (allMembers == nil || allMembers.count == 0) {
        self.membersWithLetter = @{};
        self.firstLetters = @[];
        return;
    }
    
    NSMutableDictionary<NSString *, NSMutableArray<GroupMemberEntity *> *> *dict = [NSMutableDictionary dictionary];
    
    for (GroupMemberEntity *m in allMembers) {
        NSString *displayName = [GroupsProvider getNickNameInGroup:m.nickname and:m.nickname_ingroup] ?: @"";
        NSString *firstLetter = @"#";
        
        if (![BasicTool isStringEmpty:displayName]) {
            NSString *pinyin = [HanziPinyin pinyinOfHanzi:displayName];
            NSString *fl = [HanziPinyin getFirstUpperLetterFromPinyin:pinyin];
            if (![BasicTool isStringEmpty:fl]) {
                firstLetter = fl;
            }
        }
        
        NSMutableArray *arr = dict[firstLetter];
        if (arr == nil) {
            arr = [NSMutableArray array];
            dict[firstLetter] = arr;
        }
        [arr addObject:m];
    }
    
    // 每个字母内按拼音排序
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSMutableArray<GroupMemberEntity *> *arr, BOOL *stop) {
        [arr sortUsingComparator:^NSComparisonResult(GroupMemberEntity *a, GroupMemberEntity *b) {
            NSString *nameA = [GroupsProvider getNickNameInGroup:a.nickname and:a.nickname_ingroup] ?: @"";
            NSString *nameB = [GroupsProvider getNickNameInGroup:b.nickname and:b.nickname_ingroup] ?: @"";
            NSString *pinyinA = [HanziPinyin pinyinOfHanzi:nameA] ?: @"";
            NSString *pinyinB = [HanziPinyin pinyinOfHanzi:nameB] ?: @"";
            return [pinyinA compare:pinyinB];
        }];
    }];
    
    // 排序首字母
    NSMutableArray *keys = [[[dict allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [a compare:b options:NSNumericSearch];
    }] mutableCopy];
    
    // #号放到最后
    if ([keys containsObject:@"#"]) {
        [keys removeObject:@"#"];
        [keys addObject:@"#"];
    }
    
    self.membersWithLetter = dict;
    self.firstLetters = keys;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    self.isSearching = NO;
    self.filteredDatas = nil;
    [self.tableView reloadData];
    return YES;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self.searchTextField resignFirstResponder];
}

- (void)initObservers
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;

    // 列表数据模型变动观察者
    self.tableDatasObserver = ^(id observerble ,id data) {
        // 刷新UI显示
        [safeSelf refreshUI:NO];
    };
}

// 加载数据（从网络或全局数据模型中）
- (void)loadDatas
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    // 准备创建群数据（直接取我的本地好友列表即可）
    if(self.usedForForInit == USED_FOR_CREATE_GROUP)
    {
        // 我的好友列表数据
        NSMutableArrayObservableEx *myRoster = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendsData];
        if (myRoster != nil && [[myRoster getDataList] count] > 0)
        {
            [self.groupsDatas clear:NO];
            
            for (UserEntity *ree in [myRoster getDataList]) {
                GroupMemberEntity *m = [safeSelf constructFromRosterElement:ree];
                if(m != nil) {
                    // 设置默认选中的uid，且不允许编辑，当前用于从"聊天信息"界面中的"+"号图标点进来创建群时
                    if (safeSelf.defaultSelectedUidForInit != nil && [safeSelf.defaultSelectedUidForInit isEqualToString:m.user_uid]) {
                        m.selected = YES;
                        m.editable = NO;
                    }
                    // 加入集合
                    [safeSelf.groupsDatas add:m];
                }
            }
        }
        
        // 构建字母索引数据
        if (self.enableAlphabetIndex) {
            [self rebuildAlphabetSections];
        }
        
        // 刷新界面显示
        [self refreshUI:NO];
    }
    // 准备查看群成员数据：首页带 loading，后续页静默分页拉取，每页到达后立即追加并刷新列表
    else if(self.usedForForInit == USED_FOR_VIEW_OR_MANAGER_MEMBERS)
    {
        NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        NSMutableArray<GroupMemberEntity *> *accumulated = [NSMutableArray array];
        const int pageSize = 500;
        __block int page = 1;
        __block BOOL roleDetected = NO;

        __block void (^fetchNextPage)(void);
        fetchNextPage = ^{
            BOOL isFirstPage = (page == 1);
            UIView *hudParent = isFirstPage ? safeSelf.view : nil; // 仅首页显示 loading，后续页静默
            [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:safeSelf.gidForInit requestUid:myUid page:page pageSize:pageSize complete:^(BOOL sucess, NSMutableArray<GroupMemberEntity *> *groupMembersList) {
                if (!sucess || groupMembersList == nil) {
                    if (isFirstPage) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [BasicTool showAlertError:@"数据加载失败！" parent:safeSelf];
                        });
                    }
                    return;
                }
                [accumulated addObjectsFromArray:groupMembersList];
                NSArray<GroupMemberEntity *> *currentList = [accumulated copy];
                int detectedRole = -1;
                if (!roleDetected) {
                    for (GroupMemberEntity *member in currentList) {
                        if ([member.user_uid isEqualToString:myUid]) {
                            detectedRole = (int)member.role;
                            break;
                        }
                    }
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!roleDetected && detectedRole >= 0) {
                        safeSelf.myRoleInGroup = detectedRole;
                        roleDetected = YES;
                    }
                    if (roleDetected && safeSelf.myRoleInGroup >= 1 && !safeSelf.isGroupOwnerForInit) {
                        safeSelf.title = @"管理群员";
                        safeSelf.btnOK.hidden = NO;
                        safeSelf.showCheckBox = YES;
                        [safeSelf rb_groupMemberSyncPlainChromeNav];
                    }
                    [safeSelf.groupsDatas clear:NO];
                    [safeSelf.groupsDatas putDataList:currentList needNotify:NO];
                    if (safeSelf.enableAlphabetIndex) {
                        [safeSelf rebuildAlphabetSections];
                    }
                    [safeSelf refreshUI:NO];
                });
                if (groupMembersList.count >= pageSize) {
                    page++;
                    fetchNextPage();
                }
            } hudParentView:hudParent];
        };
        fetchNextPage();
    }
    // 准备邀请入群数据
    else if(self.usedForForInit == USED_FOR_INVITE_MEMBERS)
    {
        // 直接从服务器查询群成员列表
        [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:self.gidForInit requestUid:nil complete:^(BOOL sucess, NSArray<GroupMemberEntity *> *currentGroupMembers) {

            // 取数据成功
            if(sucess && currentGroupMembers != nil)
            {
                // 可以被邀请的好友
                NSMutableArray<GroupMemberEntity *> *willBeInvite = [NSMutableArray array];

                // 我的当前所有好友列表数据
                NSMutableArrayObservableEx *myRoster = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendsData];

                // 遍历我的好友列表，如果该好友不当前群成员列表里，就表示可以被邀请入群
                for(UserEntity *friend in [myRoster getDataList])
                {
                    // 看该好友是否已经存在服务端返回的当前成员列表里
                    for(int i=0;i< [currentGroupMembers count] ; i++)
                    {
                        GroupMemberEntity *member = [currentGroupMembers objectAtIndex:i];

                        // 是否已在存在？
                        BOOL isMatched = [friend.user_uid isEqualToString:member.user_uid];
                        // 已经存在（直接跳出本次的成员列表匹配循环，接着开始上一层循环——即看下一个好友是否在列表里）
                        if(isMatched)
                        {
//                            DDLogInfo(@"[GroupMemberViewCOntroller][i=%d]A正在匹配friend.getUser_uid()=%@，member.getUser_uid()=%@， 匹配了吗？%d", i, friend.user_uid, member.user_uid, isMatched);

                            break;
                        }
                        // 还不存在列表里
                        else
                        {
//                            DDLogInfo(@"[GroupMemberViewCOntroller][i=%d]B正在匹配friend.getUser_uid()=%@，member.getUser_uid()=%@， 匹配了吗？%d", i, friend.user_uid, member.user_uid, isMatched);

                            // 已经查找到了成员列表的最后一个还没有匹配上：那这个好友肯定就不在成员列表里（就是我们要找的）
                            if(i == [currentGroupMembers count] - 1)
                            {
                                // 将此好友加入我的可以被邀请数据集合中
                                GroupMemberEntity *m = [self constructFromRosterElement:friend];
                                if(m != nil)
                                   [willBeInvite addObject:m];
                            }
                        }
                    }
                }

                // 先清空原先的数据
                [self.groupsDatas clear:NO];
                // 用新数据填充列表
                [self.groupsDatas putDataList:willBeInvite needNotify:NO];

                // 构建字母索引数据
                if (safeSelf.enableAlphabetIndex) {
                    [safeSelf rebuildAlphabetSections];
                }
                
                // 刷新界面显示
                [self refreshUI:NO];
            }
            else
            {
                [BasicTool showAlertError:@"数据加载失败！" parent:safeSelf];
            }

        } hudParentView:self.view];
    }
    // 准备转让群数据(群主可以转让给本群内除已之外的其他人)
    else if(self.usedForForInit == USED_FOR_TRANSFER)
    {
        // 直接从服务器查询群成员列表
        [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:self.gidForInit requestUid:nil complete:^(BOOL sucess, NSMutableArray<GroupMemberEntity *> *groupMembers) {

            // 取数据成功
            if(sucess && groupMembers != nil)
            {
                UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;

                if(localUserInfo != nil)
                {
                    if ([groupMembers count] > 0)
                    {
                        // 以下代码用来找到"我"在群成员列表中的索引
                        int indexOfMe = -1;
                        for(int i=0; i<[groupMembers count]; i++)
                        {
                            NSString *localUid = localUserInfo.user_uid;

                            GroupMemberEntity *gme = [groupMembers objectAtIndex:i];
                            NSString *groupMembersUid =  gme.user_uid;
                            if([localUid isEqualToString:groupMembersUid])
                            {
                                indexOfMe = i;
                                break;
                            }
                        }

                        // 将"我"从群成员列表数据集合中删除
                        if(indexOfMe != -1)
                           [groupMembers removeObjectAtIndex:indexOfMe];

                        // 先清空原先的数据
                        [self.groupsDatas clear:NO];
                        // 用新数据填充列表
                        [self.groupsDatas putDataList:groupMembers needNotify:NO];

                        if (self.enableAlphabetIndex) {
                            [self rebuildAlphabetSections];
                        }
                        // 刷新界面显示
                        [self refreshUI:NO];
                    }
                }
            }
            else
            {
                [BasicTool showAlertError:@"数据加载失败！" parent:safeSelf];
            }

        } hudParentView:self.view];
    }
    // 准备选择转账收款人数据（群成员列表，排除自己）
    else if(self.usedForForInit == USED_FOR_SELECT_FOR_WALLET_TRANSFER)
    {
        [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:self.gidForInit requestUid:nil complete:^(BOOL sucess, NSMutableArray<GroupMemberEntity *> *groupMembers) {
            if(sucess && groupMembers != nil)
            {
                UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
                if(localUserInfo != nil && groupMembers.count > 0)
                {
                    int indexOfMe = -1;
                    for (int i = 0; i < (int)groupMembers.count; i++) {
                        if ([localUserInfo.user_uid isEqualToString:[groupMembers objectAtIndex:i].user_uid]) {
                            indexOfMe = i;
                            break;
                        }
                    }
                    if (indexOfMe >= 0)
                        [groupMembers removeObjectAtIndex:indexOfMe];
                }
                [self.groupsDatas clear:NO];
                [self.groupsDatas putDataList:groupMembers needNotify:NO];
                if (self.enableAlphabetIndex)
                    [self rebuildAlphabetSections];
                [self refreshUI:NO];
            }
            else
                [BasicTool showAlertError:@"数据加载失败！" parent:safeSelf];
        } hudParentView:self.view];
    }
    // 准备设置管理员数据(只显示普通成员，排除自己和已有管理员)
    else if(self.usedForForInit == USED_FOR_SET_ADMIN)
    {
        [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:self.gidForInit requestUid:nil complete:^(BOOL sucess, NSMutableArray<GroupMemberEntity *> *groupMembers) {
            if(sucess && groupMembers != nil)
            {
                UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
                if(localUserInfo != nil)
                {
                    // 只保留普通成员(role==0)，排除自己
                    NSMutableArray *filtered = [NSMutableArray array];
                    for(GroupMemberEntity *gme in groupMembers)
                    {
                        if([gme.user_uid isEqualToString:localUserInfo.user_uid]) continue;
                        if(gme.role != 0) continue; // 只保留普通成员
                        [filtered addObject:gme];
                    }
                    
                    [self.groupsDatas clear:NO];
                    [self.groupsDatas putDataList:filtered needNotify:NO];
                    if (self.enableAlphabetIndex) {
                        [self rebuildAlphabetSections];
                    }
                    [self refreshUI:NO];
                }
            }
            else
            {
                [BasicTool showAlertError:@"数据加载失败！" parent:safeSelf];
            }
        } hudParentView:self.view];
    }
    // 准备取消管理员数据(只显示管理员，排除自己)
    else if(self.usedForForInit == USED_FOR_CANCEL_ADMIN)
    {
        [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:self.gidForInit requestUid:nil complete:^(BOOL sucess, NSMutableArray<GroupMemberEntity *> *groupMembers) {
            if(sucess && groupMembers != nil)
            {
                UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
                if(localUserInfo != nil)
                {
                    // 只保留管理员(role==1)，排除自己
                    NSMutableArray *filtered = [NSMutableArray array];
                    for(GroupMemberEntity *gme in groupMembers)
                    {
                        if([gme.user_uid isEqualToString:localUserInfo.user_uid]) continue;
                        if(gme.role != 1) continue; // 只保留管理员
                        [filtered addObject:gme];
                    }
                    
                    [self.groupsDatas clear:NO];
                    [self.groupsDatas putDataList:filtered needNotify:NO];
                    if (self.enableAlphabetIndex) {
                        [self rebuildAlphabetSections];
                    }
                    [self refreshUI:NO];
                }
            }
            else
            {
                [BasicTool showAlertError:@"数据加载失败！" parent:safeSelf];
            }
        } hudParentView:self.view];
    }
}

- (GroupMemberEntity *)constructFromRosterElement:(UserEntity *)ree
{
    if(ree != nil)
    {
        GroupMemberEntity *m = [[GroupMemberEntity alloc] init];
        m.g_id = self.gidForInit;
        m.user_uid = ree.user_uid;
        m.nickname = ree.nickname;
        m.selected = NO;
        m.userAvatarFileName = ree.userAvatarFileName;
        return m;
    }
    return nil;
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 获取当前显示行对应的 GroupMemberEntity

// 根据 indexPath 获取对应的 GroupMemberEntity（兼容搜索模式和字母索引模式）
- (GroupMemberEntity *)memberForIndexPath:(NSIndexPath *)indexPath
{
    // 搜索模式
    if (self.isSearching && self.filteredDatas) {
        if (indexPath.row < self.filteredDatas.count) {
            return self.filteredDatas[indexPath.row];
        }
        return nil;
    }

    // 字母索引待分组：单 section 多行（与 numberOfSections/numberOfRows 一致）
    if (self.enableAlphabetIndex && self.firstLetters.count == 0) {
        NSArray *list = [self.groupsDatas getDataList];
        if (list.count > 0 && indexPath.section == 0 && indexPath.row < (NSInteger)list.count) {
            return list[(NSUInteger)indexPath.row];
        }
        return nil;
    }

    // 字母索引模式
    if (self.enableAlphabetIndex && self.firstLetters.count > 0) {
        if (indexPath.section < self.firstLetters.count) {
            NSString *letter = self.firstLetters[indexPath.section];
            NSArray<GroupMemberEntity *> *members = self.membersWithLetter[letter];
            if (indexPath.row < members.count) {
                return members[indexPath.row];
            }
        }
        return nil;
    }
    
    // 原始扁平模式（每个 section 1行）
    return (GroupMemberEntity *)[self.groupsDatas get:indexPath.section];
}

//-----------------------------------------------------------------------------------------------
#pragma mark - Table view data source

// 表格 section 数
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // 搜索模式：1个 section
    if (self.isSearching && self.filteredDatas) {
        return 1;
    }
    NSInteger memberCount = (NSInteger)[[self.groupsDatas getDataList] count];
    // 字母索引模式（已生成分组）
    if (self.enableAlphabetIndex && self.firstLetters.count > 0) {
        return self.firstLetters.count;
    }
    // 字母索引已开启但尚未 rebuild（或个别分支漏调 rebuild）：严禁按 memberCount 返回 section 数，
    // 否则大群会构造「每人一节」上万 section，UITableView 会异常/巨量内存导致闪退。
    if (self.enableAlphabetIndex) {
        return memberCount > 0 ? 1 : 0;
    }
    // 原始扁平模式（每 section 一行；仅 enableAlphabetIndex=NO 时使用）
    return memberCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // 搜索模式
    if (self.isSearching && self.filteredDatas) {
        return self.filteredDatas.count;
    }
    // 字母索引模式（已生成分组）
    if (self.enableAlphabetIndex && self.firstLetters.count > 0) {
        if (section < self.firstLetters.count) {
            NSString *letter = self.firstLetters[section];
            return [self.membersWithLetter[letter] count];
        }
        return 0;
    }
    // 字母索引待分组：单 section 多行
    if (self.enableAlphabetIndex && self.firstLetters.count == 0) {
        return [[self.groupsDatas getDataList] count];
    }
    // 原始扁平模式（每 section 一行）
    return 1;
}

// section 标题（字母）
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (self.isSearching) return nil;
    if (self.enableAlphabetIndex && self.firstLetters.count > 0 && section < self.firstLetters.count) {
        return self.firstLetters[section];
    }
    return nil;
}

// section header 高度
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (self.isSearching) return 0;
    if (self.enableAlphabetIndex && self.firstLetters.count > 0) {
        return 20;
    }
    return 0;
}

// section header 视图
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (self.isSearching) return nil;
    if (self.enableAlphabetIndex && self.firstLetters.count > 0 && section < self.firstLetters.count) {
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 20)];
        headerView.backgroundColor = HexColor(0xf5f7fa);
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 200, 20)];
        titleLabel.font = [BasicTool getSystemFontOfSize:12.0f];
        titleLabel.textColor = HexColor(0x999999);
        titleLabel.text = self.firstLetters[section];
        [headerView addSubview:titleLabel];
        
        return headerView;
    }
    return nil;
}

// 用 layer.zPosition 确保字母索引渲染在 section header 之上
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    for (UIView *subview in [tableView subviews]) {
        if ([subview isKindOfClass:[NSClassFromString(@"UITableViewIndex") class]]) {
            subview.layer.zPosition = 999;
            break;
        }
    }
}

// 右侧字母索引条
- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if (self.isSearching) return nil;
    if (self.enableAlphabetIndex && self.firstLetters.count > 0) {
        return self.firstLetters;
    }
    return nil;
}

// 表格行高
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 56;
}

// 表示行的UI显示内容
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    GroupMemberEntity *ree = [self memberForIndexPath:indexPath];
    if (ree == nil) {
        return [[UITableViewCell alloc] init];
    }

    //------------------------------------------------------ 【1】UI初始化
    UITableViewCell *theCell = nil;

    // 表格单元可重用ui
    static NSString *idenfity=@"CellMain";
    GroupMemberTableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:idenfity];
    if(cell==nil) {
        NSArray* arr = [[NSBundle mainBundle] loadNibNamed:@"GroupMemberTableViewCell" owner:self options:nil];
        for (id obj in arr) {
            if ([obj isKindOfClass:[GroupMemberTableViewCell class]]) {
                cell = (GroupMemberTableViewCell *)obj;
            }
        }
    }
    theCell = cell;

    // 表格单元选中时的颜色
    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cell.selectedBackgroundView.backgroundColor = UI_DEFAULT_TABLE_VIEW_SELECTED_BG_COLOR;
    // 为了跟表格背景色一致，cell的背景设为透明
    cell.backgroundColor = [UIColor clearColor];

    // 图片圆角
    cell.viewAvatar.layer.cornerRadius = 22;
    cell.viewAvatar.layer.masksToBounds = YES;

    // 设置选择框的可见性
    if(self.showCheckBox)
    {
        // 在删除群员的模下，群主不能删除自已！
        if([self isGroupOwnerCanNotDeleteHimself:ree])
            cell.viewCheckIcon.hidden = YES;
        else
            cell.viewCheckIcon.hidden = NO;
    }
    else
    {
        cell.viewCheckIcon.hidden = YES;
    }


    //------------------------------------------------------ 【2】UI值设置
    // 利表格单元对应的数据对象对ui进行设置
    cell.viewName.text = [GroupsProvider getNickNameInGroup:ree.nickname and:ree.nickname_ingroup];
    
    // 后端已根据隐私保护设置过滤了成员列表，返回的成员均可查看
    cell.viewId.text = [NSString stringWithFormat:@"ID：%@", ree.user_uid];
    cell.viewId.hidden = NO;
    
    cell.viewCheckIcon.image = [UIImage imageNamed:([ree isSelected]?([ree isEditable]?@"common_check_box_solid_20dp_on":@"common_check_box_solid_20dp_disable"):@"common_check_box_solid_20dp_off")];

    // 如果当前行是群主或管理员，则显示对应角色标签
    if (ree.role == 2) {
        // 群主：显示群主标签
        cell.widthConstraintOfOwnerFlag.constant = 29;
        cell.viewGroupOwnerFlag.text = @"群主";
        cell.viewGroupOwnerFlag.backgroundColor = HexColor(0xFF6347);
    }
    else if (ree.role == 1) {
        // 管理员：复用群主标签显示管理员标识
        cell.widthConstraintOfOwnerFlag.constant = 38;
        cell.viewGroupOwnerFlag.text = @"管理员";
        cell.viewGroupOwnerFlag.backgroundColor = HexColor(0x4A90D9);
    }
    else
    {
        // 当不需要显地此组件时，本值设为0即可，利于用此值的设置可以让AutoLayout下依赖于本组件的其它组件能自适应位置
        cell.widthConstraintOfOwnerFlag.constant = 0;
    }

    // 如果是“我”则显示“我”标签
    cell.viewIsMyselfFlag.hidden = ([self isMyself:ree] ? NO:YES);

    // 支持视频头像播放
    [RBAvatarView setAvatarWithFileName:ree.userAvatarFileName uid:ree.user_uid onImageView:cell.viewAvatar placeholder:nil];
    
    
    //------------------------------------------------------ 【3】单元点击事件
    // 头像点击事件
    [BasicTool addFingerClick:cell.viewAvatar action:@selector(clickAvatarEvent:) target:self];
    // 将 section 和 row 编码到 tag 中（section * 10000 + row）
    cell.viewAvatar.tag = indexPath.section * 10000 + indexPath.row;

    return theCell;
}

// 头像图片的点击事件
- (void)clickAvatarEvent:(UITapGestureRecognizer *)tap
{
    // 从 tag 中解码 section 和 row
    NSInteger tag = tap.view.tag;
    NSInteger section = tag / 10000;
    NSInteger row = tag % 10000;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
    GroupMemberEntity *ree = [self memberForIndexPath:indexPath];
    if (ree == nil) return;
    
    // 管理员/群主点击成员显示入群信息
    [self showMemberInfoOrProfile:ree];
}


//-----------------------------------------------------------------------------------------------
#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexP
// 点击表格行时要调用的方法
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    GroupMemberEntity *amd = [self memberForIndexPath:indexPath];

    if(amd != nil) {
        // 显示选择框的情况下
        if(self.showCheckBox) {
            // 处于禁用状态就不需要响应点击逻辑
            if(![amd isEditable]) {
                return;
            }
            
            // 如果当前模式是删除群员，且该行是群主自已时，就不允许响应选择状态的改变哦
            if(![self isGroupOwnerCanNotDeleteHimself:amd]) {
                // 支持多选
                if(!self.singleSelection) {
                    amd.selected = !amd.selected;
                }
                // 支持单选
                else  {
                    // 先取消其它的选中
                    [self deSelectedAll];
                    // 再选中当前
                    amd.selected = YES;
                }
            }

            // 并通知刷新列表ui
            [self refreshUI:NO];
        } else {
            // 管理员/群主点击成员显示入群信息
            [self showMemberInfoOrProfile:amd];
        }
    }
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 成员入群信息展示

/** 用群成员列表中的信息构造 UserEntity，便于在开启成员隐私保护时直接打开资料页而不再请求可能被服务端拒绝的“获取用户信息”接口。 */
- (UserEntity *)userEntityFromGroupMember:(GroupMemberEntity *)member
{
    if (member == nil) return nil;
    UserEntity *u = [[UserEntity alloc] init];
    u.user_uid = member.user_uid;
    NSString *displayName = [GroupsProvider getNickNameInGroup:member.nickname and:member.nickname_ingroup];
    u.nickname = [BasicTool isStringEmpty:displayName] ? (member.nickname ?: member.user_uid) : displayName;
    u.userAvatarFileName = member.userAvatarFileName;
    return u;
}

/**
 * 管理员/群主点击成员时，显示入群信息的ActionSheet；普通成员直接查看资料。
 * 群开启成员隐私保护时，普通成员不能查看其他成员资料页，仅能查看自己。
 */
- (void)showMemberInfoOrProfile:(GroupMemberEntity *)member
{
    if (member == nil) return;

    // 群成员隐私保护：普通成员不能查看他人资料，仅能查看自己
    if (self.usedForForInit == USED_FOR_VIEW_OR_MANAGER_MEMBERS && self.groupMemberPrivacy == 1 && self.myRoleInGroup < 1 && ![self isMyself:member]) {
        [BasicTool showAlertInfo:@"群已开启成员隐私保护，无法查看其他成员资料" parent:self];
        return;
    }

    // 管理员或群主 → 显示入群信息 ActionSheet
    if (self.myRoleInGroup >= 1 && ![self isMyself:member]) {
        NSString *displayName = [GroupsProvider getNickNameInGroup:member.nickname and:member.nickname_ingroup];
        if ([BasicTool isStringEmpty:displayName]) displayName = member.user_uid;

        NSMutableString *infoText = [NSMutableString string];

        // 角色
        NSString *roleName = @"普通成员";
        if (member.role == 2) roleName = @"群主";
        else if (member.role == 1) roleName = @"管理员";
        [infoText appendFormat:@"角色：%@\n", roleName];

        // 入群时间
        if (![BasicTool isStringEmpty:member.join_time]) {
            [infoText appendFormat:@"入群时间：%@\n", member.join_time];
        }

        // 入群来源
        if (![BasicTool isStringEmpty:member.invite_by_uid]) {
            NSString *inviterName = member.invite_by_nickname ?: member.invite_by_uid;
            [infoText appendFormat:@"入群来源：由 %@ 邀请\n", inviterName];
        } else {
            if (member.role == 2) {
                [infoText appendString:@"入群来源：群创建者\n"];
            }
        }

        // 去掉末尾换行
        if (infoText.length > 0 && [infoText characterAtIndex:infoText.length - 1] == '\n') {
            [infoText deleteCharactersInRange:NSMakeRange(infoText.length - 1, 1)];
        }

        NSString *title = [NSString stringWithFormat:@"成员信息 - %@", displayName];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                      message:infoText
                                                               preferredStyle:UIAlertControllerStyleActionSheet];

        __weak typeof(self) safeSelf = self;
        UserEntity *memberAsUser = [self userEntityFromGroupMember:member];
        GroupMemberEntity *memberCopy = member;
        [alert addAction:[UIAlertAction actionWithTitle:@"查看详细资料" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [QueryFriendInfoAsync gotoWatchUserInfo:memberCopy.user_uid withInfo:memberAsUser nav:safeSelf.navigationController view:safeSelf.view vc:safeSelf addSource:@"group" groupMemberInfo:memberCopy];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

        [self presentViewController:alert animated:YES completion:nil];
    } else {
        // 普通成员或点击自己 → 直接进入资料页（使用列表中的成员信息，隐私保护下不依赖“获取用户信息”接口）
        UserEntity *memberAsUser = [self userEntityFromGroupMember:member];
        [QueryFriendInfoAsync gotoWatchUserInfo:member.user_uid withInfo:memberAsUser nav:self.navigationController view:self.view vc:self addSource:@"group" groupMemberInfo:member];
    }
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 数据提交相关方法

- (void)doSave:(UIBarButtonItem *)sender
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;

    // 执行建群信息的提交和处理结果的读取
    if(self.usedForForInit == USED_FOR_CREATE_GROUP)
    {
        if ([[self getSelectedItems] count] > 0)
        {
            CreateGroupProfileViewController *vc = [[CreateGroupProfileViewController alloc] initWithMembersForCreate:[self constructMembersForCreateGroup:YES] membersWithoutLocal:[self constructMembersForCreateGroup:NO]];
            [self.navigationController pushViewController:vc animated:YES];
        }
        else
        {
//            AlertInfo(@"请选择要加入群聊的好友！");
            [BasicTool showAlertInfo:@"请选择要加入群聊的好友！" parent:self];
        }
    }
    // 管理/删除群成员（管理员和群主可操作）
    else if(self.usedForForInit == USED_FOR_VIEW_OR_MANAGER_MEMBERS)
    {
        // 管理员或群主才能提交
        if(self.isGroupOwnerForInit || self.myRoleInGroup >= 1)
        {
            NSArray<NSArray *> *willBeDelete = [self getSelectedItemsSimple];
            if(willBeDelete != nil && [willBeDelete count] > 0 )
            {
                // 该群信息
                GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.gidForInit];
                if(ge != nil && localUserInfo != nil)
                {
                    [[HttpRestHelper sharedInstance] submitDeleteOrQuitGroupToServer:localUserInfo.user_uid del_opr_nickname:localUserInfo.nickname gid:self.gidForInit membersBeDelete:willBeDelete complete:^(BOOL sucess, NSString *resultCode) {

                        // 服务端处理成功完成
                        if(sucess && [@"1" isEqualToString:resultCode])
                        {
                            NSArray<GroupMemberEntity *> *beRemovedMembers = [safeSelf getSelectedItems];

                            // 删除群成员后更新群信息里的群成员数
                            [GroupMemberViewController updateCurrentGroupMemberGroupAfterSubmit:safeSelf.gidForInit deltaCount:(-[beRemovedMembers count])];

                            GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:safeSelf.gidForInit];
                            if(ge != nil)
                            {
                                // 往聊天界面中显示一条被"我"(我就是群主自已了，不然哪有移除权限)删除群员成功
                                // 的系统通知给"自已"看（此通知并非服务器发出，而是本地准备好的，仅用UI显示）
                                [GChatDataHelper addSystenInfo_removeMembersSucessForLocalUser:beRemovedMembers gid:safeSelf.gidForInit gname:ge.g_name];

                                // 发送通知：重置群组头像缓存(用于保证本地影响群头像生成的操作，能在其它UI界面中及时将群头像刷新为最新，因为删除群员
                                //         、邀请群员等操作会在服务端重新生成群头像，此广播就是以低耦合的方式实现本地聊头像UI刷新的通知，仅此而已)
                                [NotificationCenterFactory resetGroupAvatarCache_POST:safeSelf.gidForInit];
                            }

                            // 提示信息
                            [APP showUserDefineToast_OK:@"删除成功" atHide:nil];
                            // 退出当前界面
                            [safeSelf doBack:YES];
                        }
                        else
                        {
//                            AlertInfo(@"保存失败，可能是网络原因导致，您可稍后重试！");
                            [BasicTool showAlertInfo:@"保存失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
                        }

                    } hudParentView:self.view];
                }
            }
            else
            {
    //            AlertInfo(@"请选择要加入群聊的好友！");
                [BasicTool showAlertInfo:@"请选择要删除的群成员！" parent:self];
            }
        }
    }
    // 邀请入群
    else if(self.usedForForInit == USED_FOR_INVITE_MEMBERS)
    {
        NSArray<NSArray *> *willBeInvite = [self getSelectedItemsSimple];
        if(willBeInvite != nil && [willBeInvite count] > 0 )
        {
            [[HttpRestHelper sharedInstance] submitInviteToGroupToServer:@"0" invite_uid:localUserInfo.user_uid invite_nickname:localUserInfo.nickname invite_to_gid:self.gidForInit members:willBeInvite complete:^(BOOL sucess, NSString *resultCode) {

                // 服务端处理成功完成——直接入群
                if(sucess && [@"1" isEqualToString:resultCode])
                {
                    NSArray<GroupMemberEntity *> *beInvitedMembers = [safeSelf getSelectedItems];

                    // 邀请群成员后更新群信息里的群成员数
                    [GroupMemberViewController updateCurrentGroupMemberGroupAfterSubmit:safeSelf.gidForInit deltaCount:[beInvitedMembers count]];

                    GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:safeSelf.gidForInit];
                    if(ge != nil)
                    {
                        // 往聊天界面中显示一条被"我"邀请入群成功的系统通知给"自已"看（此通知并非服务器发出，而是本地准备好的，仅用UI显示）
                        [GChatDataHelper addSystenInfo_inviteMembersSucessForLocalUser:beInvitedMembers gid:safeSelf.gidForInit gname:ge.g_name];

                        // 发送通知：重置群组头像缓存(用于保证本地影响群头像生成的操作，能在其它UI界面中及时将群头像刷新为最新，因为删除群员
                        //         、邀请群员等操作会在服务端重新生成群头像，此广播就是以低耦合的方式实现本地聊头像UI刷新的通知，仅此而已)
                        [NotificationCenterFactory resetGroupAvatarCache_POST:safeSelf.gidForInit];

                        // 提示信息
                        [APP showUserDefineToast_OK:@"邀请成功" atHide:nil];
                        // 退出当前界面
                        [safeSelf doBack:YES];
                    }
                }
                // 已提交审核（群设置了需管理员审核入群）
                else if (sucess && [@"2" isEqualToString:resultCode])
                {
                    [APP showUserDefineToast_OK:@"已提交审核，等待管理员/群主审批" atHide:nil];
                    [safeSelf doBack:YES];
                }
                // 无权限邀请（群设置了仅管理员和群主可邀请）
                else if (sucess && [@"-2" isEqualToString:resultCode])
                {
                    [BasicTool showAlertInfo:@"邀请失败，该群仅管理员和群主可邀请新成员" parent:safeSelf];
                }
                else
                {
                    [BasicTool showAlertInfo:@"保存失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
                }
            } hudParentView:self.view];
        }
        else {
            [BasicTool showAlertInfo:@"请选择要邀请的好友！" parent:self];
        }
        
    }
    // 转让群
    else if(self.usedForForInit == USED_FOR_TRANSFER)
    {
        GroupMemberEntity *transferTo = [self getSingleSelectedUser];
        // 该群信息
        GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.gidForInit];

        if(transferTo != nil && ge != nil)
        {
            DDLogDebug(@"[GroupMemberViewController]【转让群主-DEBUG-B】HTTP请求已经提交了！！！");

            [[HttpRestHelper sharedInstance] submitTransferGroupToServer:localUserInfo.user_uid new_owner_uid:transferTo.user_uid new_owner_nickname:[GroupsProvider getNickNameInGroup:transferTo.nickname and:transferTo.nickname_ingroup] gid:self.gidForInit complete:^(BOOL sucess, NSString *resultCode) {

                // 服务端处理成功完成
                if(sucess && [@"1" isEqualToString:resultCode])
                {
                    // 更新新群主uid
                    ge.g_owner_user_uid = transferTo.user_uid;
                    // 更新新群主昵称
                    ge.g_owner_name = [GroupsProvider getNickNameInGroup:transferTo.nickname and:transferTo.nickname_ingroup];
                    // 重置本界面中的群主标识
                    safeSelf.isGroupOwnerForInit = NO;

//                    res = "群主权限已成功转让给"+ge.getG_owner_name()+"！";

                    // 往聊天界面中显示一条被"我"(我就是群主自已了，不然哪有转让权限)转让群主权限
                    //成功的系统通知给"自已"看（此通知并非服务器发出，而是本地准备好的，仅用UI显示）
                    [GChatDataHelper addSystenInfo_transferSucessForLocalUser:ge.g_owner_name gid:safeSelf.gidForInit gname:ge.g_name];

                    // 提示信息
                    [APP showUserDefineToast_OK:[NSString stringWithFormat:@"转让成功！"] atHide:nil];
                    // 退出当前界面
                    [safeSelf doBack:YES];
                }
                else
                {
                    if ([@"2" isEqualToString:resultCode])
                    {
//                        AlertInfo(@"您已不是群主，本次转让失败");
                        [BasicTool showAlertInfo:@"您已不是群主，本次转让失败" parent:safeSelf];
                    }
                    else if ([@"3" isEqualToString:resultCode])
                    {
                        NSString *hint = [NSString stringWithFormat:@"%@不在群内，本次转让失败！"
                                          , [GroupsProvider getNickNameInGroup:transferTo.nickname and:transferTo.nickname_ingroup]];
//                        AlertInfo(hint);
                        [BasicTool showAlertInfo:hint parent:safeSelf];
                    }
                    else
                    {
//                        AlertInfo(@"转让失败，可能是网络原因导致，您可稍后重试！");
                        [BasicTool showAlertInfo:@"转让失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
                    }
                }

            } hudParentView:self.view];
        }
        else {
            [BasicTool showAlertInfo:@"请选择要转让的目标！" parent:self];
        }
    }
    // 从群成员中选择转账收款人
    else if(self.usedForForInit == USED_FOR_SELECT_FOR_WALLET_TRANSFER)
    {
        GroupMemberEntity *selected = [self getSingleSelectedUser];
        if (self.onSingleMemberSelected) {
            self.onSingleMemberSelected(selected);
        }
        [self doBack:YES];
    }
    // 设置管理员
    else if(self.usedForForInit == USED_FOR_SET_ADMIN)
    {
        GroupMemberEntity *target = [self getSingleSelectedUser];
        if(target != nil)
        {
            [[HttpRestHelper sharedInstance] submitSetGroupAdminToServer:localUserInfo.user_uid targetUid:target.user_uid gid:self.gidForInit role:1 complete:^(BOOL sucess, NSString *resultCode) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (sucess && [@"1" isEqualToString:resultCode]) {
                        [APP showUserDefineToast_OK:@"设为管理员成功" atHide:nil];
                        [safeSelf doBack:YES];
                    } else if ([@"-2" isEqualToString:resultCode]) {
                        [BasicTool showAlertInfo:@"权限不足，仅群主可操作" parent:safeSelf];
                    } else if ([@"-4" isEqualToString:resultCode]) {
                        [BasicTool showAlertInfo:@"目标用户不在群中" parent:safeSelf];
                    } else {
                        [BasicTool showAlertInfo:@"设为管理员失败" parent:safeSelf];
                    }
                });
            } hudParentView:self.view];
        }
        else {
            [BasicTool showAlertInfo:@"请选择要设为管理员的成员！" parent:self];
        }
    }
    // 取消管理员
    else if(self.usedForForInit == USED_FOR_CANCEL_ADMIN)
    {
        GroupMemberEntity *target = [self getSingleSelectedUser];
        if(target != nil)
        {
            [[HttpRestHelper sharedInstance] submitSetGroupAdminToServer:localUserInfo.user_uid targetUid:target.user_uid gid:self.gidForInit role:0 complete:^(BOOL sucess, NSString *resultCode) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (sucess && [@"1" isEqualToString:resultCode]) {
                        [APP showUserDefineToast_OK:@"取消管理员成功" atHide:nil];
                        [safeSelf doBack:YES];
                    } else if ([@"-2" isEqualToString:resultCode]) {
                        [BasicTool showAlertInfo:@"权限不足，仅群主可操作" parent:safeSelf];
                    } else if ([@"-4" isEqualToString:resultCode]) {
                        [BasicTool showAlertInfo:@"目标用户不在群中" parent:safeSelf];
                    } else {
                        [BasicTool showAlertInfo:@"取消管理员失败" parent:safeSelf];
                    }
                });
            } hudParentView:self.view];
        }
        else {
            [BasicTool showAlertInfo:@"请选择要取消管理员的成员！" parent:self];
        }
    }
}

/**
 * 构建要提交到服务端的建群群成员保合（已将"自已"加入到集合中）。
 *
 * @param containMyself 是否把我自已也加入（把自已加入是用于建群时，因为群成员是包括我自已的呀）
 */
- (NSArray<GroupMemberEntity *> *) constructMembersForCreateGroup:(BOOL)containMyself
{
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    NSMutableArray<GroupMemberEntity *> *members = [self getSelectedItems];

    if(containMyself)
    {
        if (localUser != nil)
        {
            // 创建群时，群成员要加上"我自已"啊
            if ([members count] > 0)
            {
                GroupMemberEntity *myself = [[GroupMemberEntity alloc] init];
                myself.nickname = [GroupsProvider getMyNickNameInGroupEx:self.gidForInit];//localUser.nickname;
                myself.user_uid = localUser.user_uid;
                myself.userAvatarFileName = localUser.userAvatarFileName;

                [members addObject:myself];
            }
        }
    }

    return members;
}

// 本方法用于删除群成员、邀请群成员后更新群信息里的群成员数
+ (void) updateCurrentGroupMemberGroupAfterSubmit:(NSString *)gid deltaCount:(long)deltaCount
{
    GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];
    if(ge != nil)
    {
        // 该群删除成员前的总成员数
        int currentMemberCount =  [BasicTool getIntValue:ge.g_member_count defaultVal:1];
        // 新的总数
        long newCount = currentMemberCount + deltaCount;

        // 更新本地缓存里现在群的总人数
        NSString *currentGroupMemberCount = [NSString stringWithFormat:@"%ld", (newCount < 1 ? 1 : newCount)];
        ge.g_member_count = currentGroupMemberCount;
    }
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 其它数据操作方法

/**
 * 判断当前行成员是否不可被删除。
 * 规则：
 *  1. 管理员/群主管理模式下，自己不可删除自己
 *  2. 管理员不可删除同级管理员或群主
 *  3. 群主不可删除自己（只能解散群或转让）
 *
 * @param currentRow 当前行数据
 * @return YES表示该行不可被选中删除
 */
- (BOOL) isGroupOwnerCanNotDeleteHimself:(GroupMemberEntity *)currentRow
{
    // 此判断表示是否是处于管理群成员的界面模式下
    if(self.usedForForInit == USED_FOR_VIEW_OR_MANAGER_MEMBERS && (self.isGroupOwnerForInit || self.myRoleInGroup >= 1))
    {
        // 自己不能删除自己
        if([self isMyself:currentRow])
            return YES;

        // 管理员不能删除同级管理员和群主（只有群主才能踢管理员）
        if(self.myRoleInGroup == 1 && currentRow.role >= 1)
            return YES;

        // 群主不能删除自己（已在上面处理）
    }

    return NO;
}

/**
 * 该行群成员是不是"我"自已。
 *
 * @param currentRow 行数据
 * @return true表示是，否则不是
 */
- (BOOL) isMyself:(GroupMemberEntity *)currentRow
{
    BOOL s = NO;

    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;

    // 如果当前显示行就是自已
    if (localUserInfo != nil
        && currentRow != nil
        && [currentRow.user_uid isEqualToString:localUserInfo.user_uid])
    {
        s = YES;
    }

    return s;
}

// 成员隐私保护已由后端 API (1016-25-9) 通过 request_uid 参数实现过滤，
// 前端无需再做额外权限检查。所有从 API 返回的成员均可查看其资料。

/**
 * 获得单选模型下被选中的用户.
 */
- (GroupMemberEntity *)getSingleSelectedUser
{
    GroupMemberEntity *retGme = nil;

    for(GroupMemberEntity *gme in (NSArray<GroupMemberEntity *> *)([self.groupsDatas getDataList]))
    {
        if(gme.selected)
        {
            retGme = gme;
            break;
        }
    }

    return retGme;
}

/**
 * 获得选中的行（只包含简单的列，主要用于提交到服务端，不必要的字段就没有必要一起发过去浪费流量）。
 * <b>注意：</b>本方法返回的集合，通常用于提交到服务端的http接口，因而要与对应的接口要求字段保持一致哦！！！
 */
- (NSArray<NSArray *> *) getSelectedItemsSimple
{
    NSMutableArray<NSArray *> *items = [NSMutableArray array];
    for(GroupMemberEntity *gme in (NSArray<GroupMemberEntity *> *)([self.groupsDatas getDataList]))
    {
        if(gme.selected)
        {
            // 以下字段及顺序请确保与http服务端的接口保持一致！
            NSArray *row = @[gme.g_id, gme.user_uid, gme.nickname];
            [items addObject:row];
        }
    }

    return items;
}

/**
 * 获得当前选中的行。
 */
- (NSMutableArray<GroupMemberEntity *> *) getSelectedItems
{
    NSMutableArray<GroupMemberEntity *> *items = [NSMutableArray array];
    for(GroupMemberEntity *gme in (NSArray<GroupMemberEntity *> *)([self.groupsDatas getDataList]))
    {
        if(gme.selected)
        {
            [items addObject:gme];
        }
    }

    return items;
}

/**
 * 返回选中的单元数。
 */
- (int) getSelectedCount
{
    int cnt = 0;
    for(GroupMemberEntity *gme in (NSArray<GroupMemberEntity *> *)([self.groupsDatas getDataList]))
    {
        if(gme.selected)
            cnt += 1;
    }
    return cnt;
}


// 取消把在的选中状态
- (void) deSelectedAll
{
    for(GroupMemberEntity *gme in (NSArray<GroupMemberEntity *> *)([self.groupsDatas getDataList]))
    {
        gme.selected = NO;
    }
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 其它UI处理方法

// 刷新UI，当列表数据为空时显示提示信息UI，否则显示列表
- (void)refreshUI:(BOOL)forInit
{
    // 刷新表格数据显示
    [self.tableView reloadData];

    DDLogDebug(@"【群成员管理界面】界面刷新了哦！");

    // 刷新UI布局
    if([[self.groupsDatas getDataList] count] > 0)
    {
        self.tableView.hidden = NO;
        self.layoutTableEmptyHint.hidden = YES;
    }
    else
    {
        self.tableView.hidden = YES;
        if(forInit) {
            self.layoutTableEmptyHint.hidden = YES;
        } else {
            self.layoutTableEmptyHint.hidden = NO;
        }
    }

    // 设置确认按钮的显示
    [self setOkButtonForSelected:[self getSelectedCount]];
}

/**
 * 重置确认为初始状态：不可点击、文字内容显示为"确定"、以及按钮的UI样式为半透明效果。
 */
- (void) _resetOkButton
{
    UIColor *c = nil;
    // 针对ios 26的优化：更好地适配液态玻璃效果
    if (@available(iOS 26, *)) {
        c = RGBACOLOR(0, 0, 0, 100);
    } else {
        c = RGBACOLOR(255, 255, 255, 150);
    }
    
    [self.btnOK setTitleColor:c forState:UIControlStateNormal]; // 半透明的白色字体颜色
    [self.btnOK setEnabled:NO]; // 当设置按钮禁用时，系统会自动让其背景变成半透明效果，不需要单独设置禁用状态下的按钮背景图

    // 管理员或群主使用管理群员功能时，确认按钮显示为删除
    if(self.usedForForInit == USED_FOR_VIEW_OR_MANAGER_MEMBERS && (self.isGroupOwnerForInit || self.myRoleInGroup >= 1))
       [self.btnOK setTitle:@"删除" forState:UIControlStateNormal];
    else
       [self.btnOK setTitle:@"确定" forState:UIControlStateNormal];
}

/**
 * 决置确认按钮的可用性。
 *
 * @param enabled YES表示可用状态
 */
- (void) _setOkButtonEnable:(BOOL)enabled
{
    if(enabled)
    {
        UIColor *c = nil;
        // 针对ios 26的优化：更好地适配液态玻璃效果
        if (@available(iOS 26, *)) {
            c = [UIColor blackColor];
        } else {
            c = [UIColor whiteColor];
        }
        
        [self.btnOK setTitleColor:c forState:UIControlStateNormal];
        [self.btnOK setEnabled:YES];
    }
    else
    {
        [self _resetOkButton];
    }
}

/**
 * 设置确认按钮上的选中数量，并根据选中数据量决定按钮是否可点击。
 *
 * @param selectedCount 选中的数量
 */
- (void) setOkButtonForSelected:(int)selectedCount
{
    if(selectedCount > 0)
    {
        [self _setOkButtonEnable:YES];

        // 管理员或群主使用管理群员功能时，确认按钮显示为删除
        if(self.usedForForInit == USED_FOR_VIEW_OR_MANAGER_MEMBERS && (self.isGroupOwnerForInit || self.myRoleInGroup >= 1))
            [self.btnOK setTitle:[NSString stringWithFormat:@"删除(%d)", selectedCount] forState:UIControlStateNormal];
        else if(self.usedForForInit == USED_FOR_TRANSFER
                || self.usedForForInit == USED_FOR_SET_ADMIN
                || self.usedForForInit == USED_FOR_CANCEL_ADMIN
                || self.usedForForInit == USED_FOR_SELECT_FOR_WALLET_TRANSFER)
            [self.btnOK setTitle:@"确定" forState:UIControlStateNormal];
        else
            [self.btnOK setTitle:[NSString stringWithFormat:@"确定(%d)", selectedCount] forState:UIControlStateNormal];
    }
    else
    {
        [self _setOkButtonEnable:NO];
    }
}

// 从当前界面回退
- (void)doBack:(BOOL)animated
{
    [self.navigationController popViewControllerAnimated:animated];
}

//
//+ (UIImage *)getStretchImageForSaveButton:(NSString *)imaName
//{
//    return [[UIImage imageNamed:imaName] resizableImageWithCapInsets:UIEdgeInsetsMake(6, 6, 6, 6) resizingMode:UIImageResizingModeStretch];
//}

// 创建导航样上自定义按钮的方法
+ (UIButton *)createCunstomNavigationBuntton
{
    UIImage *c = nil;
    // 针对ios 26的优化：使用透明背景能更好地支持液态玻璃效果
    if (@available(iOS 26, *)) {
        c = [BasicTool imageWithColor:[UIColor clearColor] withSize:CGSizeMake(1.0f, 1.0f)];//RGBACOLOR(255, 255, 255, 255)
    }
    // 老系统中保持扁平化效果
    else {
        c = [BasicTool imageWithColor:UI_DEFAULT_BTN_BG_COLOR withSize:CGSizeMake(1.0f, 1.0f)];
    }
    
    return [GroupMemberViewController createCunstomNavigationBuntton:c];
}

// 创建导航样上自定义按钮的方法
+ (UIButton *)createCunstomNavigationBuntton:(UIImage *)btnImg// action:(SEL)btnAction
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
//    button.titleLabel.font = [UIFont systemFontOfSize: 13.0];
    [button setBackgroundImage:btnImg forState:UIControlStateNormal];
//    button.frame = CGRectMake(0, 0, 60, 10);
    
    // 宽度随文案（如「确定(12)」「删除(3)」）自适应；固定宽度会导致自定义顶栏右侧文字显示不全
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 10.f, 0, 10.f);
    // 优先完整展示字号，避免靠缩小字体糊成一小块
    button.titleLabel.adjustsFontSizeToFitWidth = NO;

    // 针对ios 26的优化：使用透明背景能更好地支持液态玻璃效果
    if (@available(iOS 26, *)) {
        CGFloat adjustedSize = [BasicTool getAdjustedFontSize:14.0];
        button.titleLabel.font = [UIFont systemFontOfSize:adjustedSize weight:UIFontWeightMedium];
        button.frame = CGRectMake(0, 0, 64, 30);
        [button.heightAnchor constraintEqualToConstant:30].active = YES;
    } else {
        button.titleLabel.font = [BasicTool getSystemFontOfSize: 13.0];
        button.frame = CGRectMake(0, 0, 60, 30);
        [button.heightAnchor constraintEqualToConstant:30].active = YES;
    }
    
    
    // 让按钮内部的所有内容居中对齐
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
//    [button addTarget:self action:btnAction forControlEvents:UIControlEventTouchUpInside];
    
//    // 设置UIBarButtonItem的大小，参考资料：https://www.jianshu.com/p/12ea17755a3c
//    [button.widthAnchor constraintEqualToConstant:55].active = YES;
//    [button.heightAnchor constraintEqualToConstant:30].active = YES;
    
    // 图片圆角
    button.layer.cornerRadius = 10;
    button.layer.masksToBounds = YES;
    
    return button;
}

@end
