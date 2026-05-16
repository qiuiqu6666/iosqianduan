//telegram @wz662
#import "TargetChooseViewController.h"
#import "NSMutableArrayObservableEx.h"
#import "BasicTool.h"
#import "AppDelegate.h"
#import "GroupsProvider.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "QueryFriendInfoAsync.h"
#import "QueryGroupInfoAsync.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "GChatDataHelper.h"
#import "ViewControllerFactory.h"
#import "AppDelegate.h"
#import "NotificationCenterFactory.h"
#import "EVAToolKits.h"
#import "MsgBodyRoot.h"
#import "TargetChooseTableViewCell.h"
#import "MBProgressHUD.h"
#import "AlarmType.h"
#import "EmojiUtil.h"
#import "ChatRootViewController.h"
#import "HanziPinyin.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"


@interface TargetChooseViewController () <UITextFieldDelegate>

/* 列表数据模型（形如<TargetEntity *>的1维数组） */
@property (nonatomic, retain) NSMutableArrayObservableEx *groupsDatas;
/* 数据模型变动观察者实现block */
@property (nonatomic, copy) ObserverCompletion tableDatasObserver;

/** 调用者传进来的目标数据源类型。本字段支持位运行进行数据源类型的设置。 */
@property (nonatomic, assign) int supportedTargetSource;

/** 调用者传进来的目标数据源过滤器，供开发者实现数据源的灵活过滤控制（本对象可为空）*/
@property (nonatomic, copy) TargetSourceFilter4LatestChatting targetSourceFilter4LatestChatting;
@property (nonatomic, copy) TargetSourceFilter4Friend targetSourceFilter4Friend;
@property (nonatomic, copy) TargetSourceFilter4Group targetSourceFilter4Group;
@property (nonatomic, copy) TargetSourceFilter4GroupMember targetSourceFilter4GroupMember;

/** 调用者传进来的额外对象，原则上本对象不用在本类中，用于选择目标结束后再回报给调用者，本对象可为空 */
@property (nonatomic, retain) id extraObjFromItent;

/** 调用者传进来的群id，仅当支持 {@link TargetSourceGroupMember} 时需要，且此时不能为空，其它情况请传空 */
@property (nonatomic, retain) NSString *gidFromItent;

/** 调用者传进来的请求标识，用于区分同一个调用界面中，不同的功能都需要使用目标选择能力时（不然一个delegate怎么区分呢？对吧），如果不需要，本参数可传-1 */
@property (nonatomic, assign) int requestCode;


/** 是否支持"最近聊天"数据源，false表示不支持（UI上将不显示对应的列表和ui） */
@property (nonatomic, assign) BOOL supportedLatestChattingTargetSource;
/** 是否支持"好友"数据源，false表示不支持（UI上将不显示对应的列表和ui） */
@property (nonatomic, assign) BOOL supportedFriendTargetSource;
/** 是否支持"群聊"数据源，false表示不支持（UI上将不显示对应的列表和ui） */
@property (nonatomic, assign) BOOL supportedGroupTargetSource;
/** 是否支持"群成 员"数据源，false表示不支持（UI上将不显示对应的列表和ui） */
@property (nonatomic, assign) BOOL supportedGroupMemberTargetSource;
// 是否显示选择框
@property (nonatomic, assign) BOOL showCheckBox;
// 是否支持单选
@property (nonatomic, assign) BOOL singleSelection;

@property (nonatomic, retain) UIButton *btnOK;

// 当前选中的Tab
@property (nonatomic, retain) UIButton *currentTab;

// 搜索相关
@property (nonatomic, strong) UITextField *searchTextField;
/** 搜索过滤后的数据（当搜索框有内容时使用此数组作为表格数据源） */
@property (nonatomic, strong) NSArray<TargetEntity *> *filteredDatas;
/** 当前是否正在搜索过滤 */
@property (nonatomic, assign) BOOL isSearching;

// 26字母索引相关
/** 是否启用字母索引 */
@property (nonatomic, assign) BOOL enableAlphabetIndex;
/** 按首字母分组后的数据：{ "A": [TargetEntity, ...], "B": [...], ... } */
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<TargetEntity *> *> *targetsWithLetter;
/** 排序后的首字母数组：["A", "B", "C", ...] */
@property (nonatomic, strong) NSArray<NSString *> *firstLetters;

@end

@implementation TargetChooseViewController

- (id)initWithNibName:(NSString *)nibNameOrNil 
               bundle:(NSBundle *)nibBundleOrNil
supportedTargetSource:(int)targetSource
 latestChattingFilter:(TargetSourceFilter4LatestChatting)targetSourceFilter4LatestChatting
         friendFilter:(TargetSourceFilter4Friend)targetSourceFilter4Friend
          groupFilter:(TargetSourceFilter4Group)targetSourceFilter4Group
          groupMemberFilter:(TargetSourceFilter4GroupMember)targetSourceFilter4GroupMember
             extraObj:(id)extraObj
                  gid:(NSString *)gid
          requestCode:(int)requestCode
             delegate:(id<UserChooseCompleteDelegate>)chooseCompleteDelegate
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.supportedLatestChattingTargetSource = NO;
        self.supportedFriendTargetSource = NO;
        self.supportedGroupTargetSource = NO;
        self.supportedGroupMemberTargetSource = NO;
        
        self.supportedTargetSource = targetSource;
        self.targetSourceFilter4LatestChatting = targetSourceFilter4LatestChatting;
        self.targetSourceFilter4Friend = targetSourceFilter4Friend;
        self.targetSourceFilter4Group = targetSourceFilter4Group;
        self.targetSourceFilter4GroupMember = targetSourceFilter4GroupMember;
        self.extraObjFromItent = extraObj;
        self.gidFromItent = gid;
        self.requestCode = requestCode;
        
//      self.usedForForInit = usedFor;
//      self.chatTypeForInit = chatType;
//      self.toIdForInit = toId;
        self.chooseCompleteDelegate = chooseCompleteDelegate;

//        self.showCheckBox = YES;
//        self.singleSelection = NO;

        // 支持的目标数据类型
        self.supportedLatestChattingTargetSource = ((self.supportedTargetSource & TargetSourceLatestChatting) == TargetSourceLatestChatting);
        self.supportedFriendTargetSource = ((self.supportedTargetSource & TargetSourceFriend) == TargetSourceFriend);
        self.supportedGroupTargetSource = ((self.supportedTargetSource & TargetSourceGroup) == TargetSourceGroup);
        self.supportedGroupMemberTargetSource = ((self.supportedTargetSource & TargetSourceGroupMember) == TargetSourceGroupMember);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 初始化界面
    [self initGUI];
    // 初始化事件处理
    [self initActions];
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
    [self refreshUI:NO];
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

- (void)rb_targetChooseSyncPlainChromeNav
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
    
    // 字母索引样式设置（非透明背景，防止被 section header 背景遮盖）
    self.tableView.sectionIndexColor = HexColor(0x4E4E4E);
    self.tableView.sectionIndexBackgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    
    // 创建搜索框并设为tableHeaderView
    [self createSearchBarHeader];

    // ok按钮
    self.btnOK = [GroupMemberViewController createCunstomNavigationBuntton];
    // 设置ok按钮的初始状态
    [self _setOkButtonEnable:NO];
    
    // 如果没有设置目标源类型，让直接退出当前界面
    if(!self.supportedLatestChattingTargetSource && !self.supportedFriendTargetSource && !self.supportedGroupTargetSource && !self.supportedGroupMemberTargetSource) {
        [self promtAndFinish:[NSString stringWithFormat:@"不支持的目标数据源类型%d", self.supportedTargetSource]];
    }
    
    // 设置tab切换Button的tag值
    self.latestChattingRadio.tag = TargetSourceLatestChatting;
    self.friendRadio.tag = TargetSourceFriend;
    self.groupRadio.tag = TargetSourceGroup;
    self.groupMemberRadio.tag = TargetSourceGroupMember;

    // 仅设置目标数据源为"最近聊天"时
    if(self.supportedTargetSource == TargetSourceLatestChatting) {
        self.title = [NSString stringWithFormat:@"选择%@", [self.latestChattingRadio titleForState:UIControlStateNormal]];
        self.btnOK.hidden = NO;
        self.showCheckBox = YES;
        self.singleSelection = YES;
        self.tabsMainLayoutHeightConstraint.constant = 0;
        self.enableAlphabetIndex = NO;
    }
    // 仅设置目标数据源为"好友"时
    else if(self.supportedTargetSource == TargetSourceFriend) {
        self.title = [NSString stringWithFormat:@"选择%@", [self.friendRadio titleForState:UIControlStateNormal]];
        self.btnOK.hidden = NO;
        self.showCheckBox = YES;
        self.singleSelection = YES;
        self.tabsMainLayoutHeightConstraint.constant = 0;
        self.enableAlphabetIndex = YES; // 好友列表启用26字母索引
    }
    // 仅设置目标数据源为"群聊"时
    else if(self.supportedTargetSource == TargetSourceGroup){
        self.title = [NSString stringWithFormat:@"选择%@", [self.groupRadio titleForState:UIControlStateNormal]];
        self.btnOK.hidden = NO;
        self.showCheckBox = YES;
        self.singleSelection = YES;
        self.tabsMainLayoutHeightConstraint.constant = 0;
        self.enableAlphabetIndex = YES; // 群聊列表启用26字母索引
    }
    // 仅设置目标数据源为"群成员"时
    else if(self.supportedTargetSource == TargetSourceGroupMember){
        self.title = [NSString stringWithFormat:@"选择%@", [self.groupMemberRadio titleForState:UIControlStateNormal]];
        self.btnOK.hidden = NO;
        self.showCheckBox = YES;
        self.singleSelection = YES;
        self.tabsMainLayoutHeightConstraint.constant = 0;
        self.enableAlphabetIndex = YES; // 群成员列表启用26字母索引
    }
    // 已设置多种目标数据源时
    else {
        self.title = @"选择目标";
        self.btnOK.hidden = NO;
        self.showCheckBox = YES;
        self.singleSelection = YES;
//      self.tabsMainLayoutHeightConstraint.constant = 89;
    }
    
    // 消息转发和@用户时支持多选
    if (self.requestCode == TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD
        || self.requestCode == TARGET_CHOOSE_REQUEST_CODE_FOR_AT) {
        self.singleSelection = NO;
    }

    [self rb_targetChooseSyncPlainChromeNav];
}

- (void)initActions
{
    [self.btnOK addTarget:self action:@selector(doSave:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)initDatas
{
    // 初始化数组
    self.groupsDatas = [[NSMutableArrayObservableEx alloc] init];
    // 刷新UI
    [self refreshUI:YES];
    
    // 界面显示后默认选中第一个，并加载其对应的数据（因无法通过setChecked触发它的OnCheckedChange，所以只能代码显示调用loadData了）
    if(self.supportedLatestChattingTargetSource) {
        self.latestChattingRadio.selected = YES;
        // 设置当前选中的tab按钮
        self.currentTab = self.latestChattingRadio;
        // 加载对应源数据类型的数据
        [self loadDatas:TargetSourceLatestChatting];
    } else if(self.supportedFriendTargetSource) {
        self.friendRadio.selected = YES;
        // 设置当前选中的tab按钮
        self.currentTab = self.friendRadio;
        // 加载对应源数据类型的数据
        [self loadDatas:TargetSourceFriend];
    } else if(self.supportedGroupTargetSource) {
        self.groupRadio.selected = YES;
        // 设置当前选中的tab按钮
        self.currentTab = self.groupRadio;
        // 加载对应源数据类型的数据
        [self loadDatas:TargetSourceGroup];
    } else if(self.supportedGroupMemberTargetSource) {
        self.groupMemberRadio.selected = YES;
        // 设置当前选中的tab按钮
        self.currentTab = self.groupMemberRadio;
        // 加载对应源数据类型的数据
        [self loadDatas:TargetSourceGroupMember];
    }
    
//    // 加载数据（从网络或全局数据模型中）
//    [self loadDatas];
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
- (void)loadDatas:(TargetSource)targetSource
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    [self.groupsDatas clear:NO];

    long t = [TimeTool getIOSDefaultTimeStamp_l];
    
    // 加载"最近聊天"数据（数据来源于首页"消息"列表）
    if(targetSource == TargetSourceLatestChatting){
        NSMutableArrayObservableEx *alarmDatas = [[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmsData];
        if(alarmDatas != nil && [[alarmDatas getDataList] count] > 0) {
            for (AlarmDto *ad in [alarmDatas getDataList]) {
                if(self.targetSourceFilter4LatestChatting != nil){
                    // 如果过滤器的过滤条件判断结果为"不允许"，则跳过该条数据，以便继续循环遍历余下的数据
                    if(!self.targetSourceFilter4LatestChatting(ad)) {
                        continue;
                    }
                }
                
                TargetEntity *m = [self constructFromLatestChatting:ad];
                if(m != nil) {
                    // 单条插入的时候不通知观察者
                    [self.groupsDatas add:m needNotify:NO];
                }
            }
        }
        
        // 整个列表循环结束时才通知一次观察者，提升ui性能
        [self.groupsDatas notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
    }
    // 加载"好友"数据（数据来源于"好友"列表）
    else if(targetSource == TargetSourceFriend) {
        // 我的好友列表数据
        NSMutableArrayObservableEx *myRoster = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendsData];
        if (myRoster != nil && [[myRoster getDataList] count] > 0) {            
            for (UserEntity *ree in [myRoster getDataList]) {
                if(self.targetSourceFilter4Friend != nil){
                    // 如果过滤器的过滤条件判断结果为"不允许"，则跳过该条数据，以便继续循环遍历余下的数据
                    if(!self.targetSourceFilter4Friend(ree)) {
                        continue;
                    }
                }
                
                TargetEntity *m = [self constructFromRosterElement:ree];
                if(m != nil) {
                    // 单条插入的时候不通知观察者
                    [self.groupsDatas add:m needNotify:NO];
                }
            }
            
            // 构建字母索引数据
            if (self.enableAlphabetIndex) {
                [self rebuildAlphabetSections];
            }
            
            // 整个列表循环结束时才通知一次观察者，提升ui性能
            [self.groupsDatas notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
        }
    }
    // 加载"群聊"数据（数据来源于"群聊"列表）
    else if(targetSource == TargetSourceGroup) {
        // 读取原始群列表数据
        NSMutableArrayObservableEx *groupsData = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupsListData];
        if (groupsData != nil && [[groupsData getDataList] count] > 0) {
            for (GroupEntity *ge in [groupsData getDataList]) {
                if(self.targetSourceFilter4Group != nil){
                    // 如果过滤器的过滤条件判断结果为"不允许"，则跳过该条数据，以便继续循环遍历余下的数据
                    if(!self.targetSourceFilter4Group(ge)) {
                        continue;
                    }
                }

                TargetEntity *m = [self constructFromGroupEntity:ge];
                if(m != nil) {
                    // 单条插入的时候不通知观察者
                    [self.groupsDatas add:m needNotify:NO];
                }
            }
        }
        
        // 构建字母索引数据
        if (self.enableAlphabetIndex) {
            [self rebuildAlphabetSections];
        }
        
        // 整个列表循环结束时才通知一次观察者，提升ui性能
        [self.groupsDatas notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
    }
    // 加载"群成员"数据（数据来源于"群成员"列表）
    else if(targetSource == TargetSourceGroupMember) {
        // 直接从服务器查询群成员列表
        [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:self.gidFromItent requestUid:nil complete:^(BOOL sucess, NSMutableArray<GroupMemberEntity *> *groupMembers) {
            // 取数据成功
            if(sucess && groupMembers != nil)  {
//                RosterElementEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
//                if(localUserInfo != nil) {
                    if ([groupMembers count] > 0) {
                        for (GroupMemberEntity *ge in groupMembers) {
                            if(self.targetSourceFilter4GroupMember != nil){
                                // 如果过滤器的过滤条件判断结果为"不允许"，则跳过该条数据，以便继续循环遍历余下的数据
                                if(!self.targetSourceFilter4GroupMember(ge)) {
                                    continue;
                                }
                            }

                            TargetEntity *m = [self constructFromGroupMember:ge];
                            if(m != nil) {
                                // 单条插入的时候不通知观察者
                                [self.groupsDatas add:m needNotify:NO];
                            }
                        }
                    }
//                }
                
                /*
                 构建"@所有人"item数据：
                 目前 TargetSource.groupMember 暂时是专用于"@"功能时选择被"@"的成员时，暂时为了简化代码，
                 "@所有人"这个选项只能在 TargetChooseActivity 另用代码写死，暂时就不考虑"@"功能之外使用了，特此说明！
                 */
                // 如果本地用户是该群的群主
                if([GroupsProvider isThisGroupOwner:self.gidFromItent]) {
                    [self.groupsDatas add:0 withObj:[self constructAtAll] needNotify:NO];
                }
                
                // 构建字母索引数据
                if (self.enableAlphabetIndex) {
                    [self rebuildAlphabetSections];
                }
                
                // 整个列表循环结束时才通知一次观察者，提升ui性能
                [self.groupsDatas notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
            } else {
                [BasicTool showAlertError:@"数据加载失败！" parent:safeSelf];
            }

        } hudParentView:self.view];
    }
        
    DLogInfo(@"数据加载完成，本次耗时：%ld 毫秒。", [TimeTool getIOSDefaultTimeStamp_l] - t);
    
    // 刷新界面显示
    [self refreshUI:NO];
}

- (TargetEntity *)constructFromLatestChatting:(AlarmDto *)ad {
    if(ad != nil) {
        int targetChatType = -1;
        switch (ad.alarmType){
            case AMT_guestChatMessage:
                targetChatType = CHAT_TYPE_GUEST_CHAT;
                break;
            case AMT_friendChatMessage:
                targetChatType = CHAT_TYPE_FREIDN_CHAT;
                break;
            case AMT_groupChatMessage:
                targetChatType = CHAT_TYPE_GROUP_CHAT;
                break;
        }
        
        TargetEntity *m =  [[TargetEntity alloc] init];
        m.targetChatType = targetChatType;
        m.targetId = ad.dataId;
        m.targetName = ad.title;
        m.targetOtherInfo = ad.alarmContent;
        m.userAvatarFileName = ad.extraString1;
        
        m.selected = NO;
        
        return m;
    }
    return nil;
}

- (TargetEntity *)constructFromRosterElement:(UserEntity *)ree {
    if(ree != nil) {
        TargetEntity *m =  [[TargetEntity alloc] init];
        m.targetChatType = CHAT_TYPE_FREIDN_CHAT;
        m.targetId = ree.user_uid;
        m.targetName = [ree getNickNameWithRemark];
        m.targetOtherInfo = [NSString stringWithFormat:@"ID：%@", ree.user_uid];
        m.userAvatarFileName = ree.userAvatarFileName;
        
        m.selected = NO;
        return m;
    }
    return nil;
}

- (TargetEntity *)constructFromGroupEntity:(GroupEntity *)ge {
    if(ge != nil) {
        TargetEntity *m =  [[TargetEntity alloc] init];
        m.targetChatType = CHAT_TYPE_GROUP_CHAT;
        m.targetId = ge.g_id;
        m.targetName = ge.g_name;
        m.targetOtherInfo = [NSString stringWithFormat:@"创建于 %@", ge.create_time];//+"，当前"+ge.getG_member_count()+"人");
        
        m.selected = NO;
        return m;
    }
    return nil;
}

- (TargetEntity *)constructFromGroupMember:(GroupMemberEntity *)ge {
    if(ge != nil) {
        int targetChatType = -1;
        if([[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster2:ge.user_uid]) {
            targetChatType = CHAT_TYPE_FREIDN_CHAT;
        } else {
            targetChatType = CHAT_TYPE_GUEST_CHAT;
        }
        
        TargetEntity *m =  [[TargetEntity alloc] init];
        m.targetChatType = targetChatType;
        m.targetId = ge.user_uid;
        m.targetName = [GroupsProvider getNickNameInGroup:ge.nickname and:ge.nickname_ingroup]; // 由于昵称的复杂性：原昵称、群内昵称、好友备注等多重情况，为了简化逻辑，此处跟微信一样，被 @ 者任何时候都用他原本的昵称
        m.targetOtherInfo = [NSString stringWithFormat:@"ID：%@", ge.user_uid];
        m.userAvatarFileName = ge.userAvatarFileName;
        
        m.selected = NO;
        return m;
    }
    return nil;
}

/**
 * 构建"@所有人"item数据。
 *
 * 目前 TargetSource.groupMember 暂时是专用于"@"功能时选择被"@"的成员时，暂时为了简化代码，
 * "@所有人"这个选项只能在 TargetChooseActivity 另用代码写死，暂时就不考虑"@"功能之外使用了，特此说明！
 */
- (TargetEntity *)constructAtAll {
    int targetChatType = TARGET_CHAT_TYPE_FOR_AT_ALL;
    
    TargetEntity *m =  [[TargetEntity alloc] init];
    m.targetChatType = targetChatType;
    m.targetId = @"0";// "@"功能中定义的被"@"uid为"0"时即表示"@"所有人
    m.targetName = @"所有人";
    m.targetOtherInfo = @"群主权限";
    
    m.selected = NO;
    return m;
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 搜索框相关

- (void)createSearchBarHeader
{
    CGFloat headerHeight = 52;
    CGFloat vPadding = 8;
    
    UIView *headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, headerHeight)];
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
    
    // 搜索输入框（使用 UITextField 替换 UISearchBar，更简洁美观）
    self.searchTextField = [[UITextField alloc] init];
    self.searchTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchTextField.delegate = self;
    self.searchTextField.placeholder = @"搜索";
    self.searchTextField.font = [UIFont systemFontOfSize:15];
    self.searchTextField.textColor = [UIColor blackColor];
    self.searchTextField.backgroundColor = [UIColor clearColor];
    self.searchTextField.borderStyle = UITextBorderStyleNone;
    self.searchTextField.returnKeyType = UIReturnKeySearch;
    self.searchTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self.searchTextField addTarget:self action:@selector(searchTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [searchBg addSubview:self.searchTextField];
    
    // 约束
    [NSLayoutConstraint activateConstraints:@[
        [searchBg.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor constant:16],
        [searchBg.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor constant:-16],
        [searchBg.topAnchor constraintEqualToAnchor:headerContainer.topAnchor constant:vPadding],
        [searchBg.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor constant:-vPadding],
        
        [searchIcon.leadingAnchor constraintEqualToAnchor:searchBg.leadingAnchor constant:12],
        [searchIcon.centerYAnchor constraintEqualToAnchor:searchBg.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:18],
        [searchIcon.heightAnchor constraintEqualToConstant:18],
        
        [self.searchTextField.leadingAnchor constraintEqualToAnchor:searchIcon.trailingAnchor constant:8],
        [self.searchTextField.trailingAnchor constraintEqualToAnchor:searchBg.trailingAnchor constant:-12],
        [self.searchTextField.topAnchor constraintEqualToAnchor:searchBg.topAnchor],
        [self.searchTextField.bottomAnchor constraintEqualToAnchor:searchBg.bottomAnchor],
    ]];
    
    self.tableView.tableHeaderView = headerContainer;
}

/** 根据搜索关键字过滤当前数据 */
- (void)filterDataWithSearchText:(NSString *)searchText
{
    if (searchText == nil || searchText.length == 0) {
        self.isSearching = NO;
        self.filteredDatas = nil;
    } else {
        self.isSearching = YES;
        NSString *lowercaseSearch = [searchText lowercaseString];
        NSMutableArray<TargetEntity *> *filtered = [NSMutableArray array];
        for (TargetEntity *te in (NSArray<TargetEntity *> *)[self.groupsDatas getDataList]) {
            // 匹配名称、ID、其它信息
            NSString *name = [te.targetName lowercaseString] ?: @"";
            NSString *tid = [te.targetId lowercaseString] ?: @"";
            NSString *info = [te.targetOtherInfo lowercaseString] ?: @"";
            if ([name containsString:lowercaseSearch]
                || [tid containsString:lowercaseSearch]
                || [info containsString:lowercaseSearch]) {
                [filtered addObject:te];
            }
        }
        self.filteredDatas = filtered;
    }
    [self.tableView reloadData];
    
    // 更新OK按钮状态
    [self setOkButtonForSelected:[self getSelectedCount]];
}

/** 获取当前用于表格显示的数据列表（搜索时返回过滤后的数据，否则返回全量数据） */
- (NSArray<TargetEntity *> *)currentDisplayDatas
{
    if (self.isSearching) {
        return self.filteredDatas ?: @[];
    }
    return [self.groupsDatas getDataList] ?: @[];
}

//-----------------------------------------------------------------------------------------------
#pragma mark - 26字母索引

/** 将 groupsDatas 按名称首字母分组并排序 */
- (void)rebuildAlphabetSections
{
    NSArray<TargetEntity *> *allTargets = [self.groupsDatas getDataList];
    if (allTargets == nil || allTargets.count == 0) {
        self.targetsWithLetter = @{};
        self.firstLetters = @[];
        return;
    }
    
    NSMutableDictionary<NSString *, NSMutableArray<TargetEntity *> *> *dict = [NSMutableDictionary dictionary];
    
    for (TargetEntity *te in allTargets) {
        // "@所有人"特殊项放在最前面（不参与字母分组）
        if (te.targetChatType == TARGET_CHAT_TYPE_FOR_AT_ALL) {
            NSMutableArray *arr = dict[@"★"];
            if (arr == nil) {
                arr = [NSMutableArray array];
                dict[@"★"] = arr;
            }
            [arr addObject:te];
            continue;
        }
        
        NSString *displayName = te.targetName ?: @"";
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
        [arr addObject:te];
    }
    
    // 每个字母内按拼音排序
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSMutableArray<TargetEntity *> *arr, BOOL *stop) {
        if ([key isEqualToString:@"★"]) return; // "@所有人"不需要排序
        [arr sortUsingComparator:^NSComparisonResult(TargetEntity *a, TargetEntity *b) {
            NSString *nameA = a.targetName ?: @"";
            NSString *nameB = b.targetName ?: @"";
            NSString *pinyinA = [HanziPinyin pinyinOfHanzi:nameA] ?: @"";
            NSString *pinyinB = [HanziPinyin pinyinOfHanzi:nameB] ?: @"";
            return [pinyinA compare:pinyinB];
        }];
    }];
    
    // 排序首字母
    NSMutableArray *keys = [[[dict allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [a compare:b options:NSNumericSearch];
    }] mutableCopy];
    
    // ★放在最前面（"@所有人"）
    if ([keys containsObject:@"★"]) {
        [keys removeObject:@"★"];
        [keys insertObject:@"★" atIndex:0];
    }
    
    // #号放到最后
    if ([keys containsObject:@"#"]) {
        [keys removeObject:@"#"];
        [keys addObject:@"#"];
    }
    
    self.targetsWithLetter = dict;
    self.firstLetters = keys;
}

/** 根据 indexPath 获取对应的 TargetEntity（兼容字母索引和搜索模式） */
- (TargetEntity *)targetForIndexPath:(NSIndexPath *)indexPath
{
    // 搜索模式：使用扁平列表
    if (self.isSearching) {
        NSArray<TargetEntity *> *datas = self.filteredDatas ?: @[];
        if (indexPath.section < (NSInteger)datas.count) {
            return datas[indexPath.section];
        }
        return nil;
    }
    
    // 字母索引模式
    if (self.enableAlphabetIndex && self.firstLetters.count > 0) {
        if (indexPath.section < (NSInteger)self.firstLetters.count) {
            NSString *letter = self.firstLetters[indexPath.section];
            NSArray<TargetEntity *> *targets = self.targetsWithLetter[letter];
            if (indexPath.row < (NSInteger)targets.count) {
                return targets[indexPath.row];
            }
        }
        return nil;
    }
    
    // 普通模式：每个section一行
    NSArray<TargetEntity *> *datas = [self currentDisplayDatas];
    if (indexPath.section < (NSInteger)datas.count) {
        return datas[indexPath.section];
    }
    return nil;
}

#pragma mark - UITextFieldDelegate & 搜索框事件

- (void)searchTextFieldDidChange:(UITextField *)textField
{
    [self filterDataWithSearchText:textField.text];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    [self filterDataWithSearchText:@""];
    return YES;
}


//-----------------------------------------------------------------------------------------------
#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // 搜索模式：使用扁平列表（每个section一行）
    if (self.isSearching) {
        return [self.filteredDatas count];
    }
    
    // 字母索引模式：每个字母一个section
    if (self.enableAlphabetIndex && self.firstLetters.count > 0) {
        return self.firstLetters.count;
    }
    
    // 普通模式：每个数据项一个section
    return [[self currentDisplayDatas] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // 搜索模式：扁平列表
    if (self.isSearching) {
        return 1;
    }
    
    // 字母索引模式：该字母下的成员数
    if (self.enableAlphabetIndex && self.firstLetters.count > 0) {
        if (section < (NSInteger)self.firstLetters.count) {
            NSString *letter = self.firstLetters[section];
            return [self.targetsWithLetter[letter] count];
        }
        return 0;
    }
    
    // 普通模式
    return 1;
}

// 字母section header标题
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (!self.isSearching && self.enableAlphabetIndex && self.firstLetters.count > 0 && section < (NSInteger)self.firstLetters.count) {
        return self.firstLetters[section];
    }
    return nil;
}

// 自定义section header样式
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (!self.isSearching && self.enableAlphabetIndex && self.firstLetters.count > 0 && section < (NSInteger)self.firstLetters.count) {
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 20)];
        headerView.backgroundColor = HexColor(0xF5F5F5);
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, tableView.frame.size.width - 32, 20)];
        titleLabel.font = [BasicTool getSystemFontOfSize:12.0f];
        titleLabel.textColor = HexColor(0x999999);
        titleLabel.text = self.firstLetters[section];
        [headerView addSubview:titleLabel];
        
        return headerView;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (!self.isSearching && self.enableAlphabetIndex && self.firstLetters.count > 0) {
        return 20;
    }
    return 0;
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

// 右侧字母索引
- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if (!self.isSearching && self.enableAlphabetIndex && self.firstLetters.count > 0) {
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
    TargetEntity *ree = [self targetForIndexPath:indexPath];
    if (ree == nil) return [[UITableViewCell alloc] init];
    
    //------------------------------------------------------ 【1】UI初始化
    UITableViewCell *theCell = nil;
    
    // 表格单元可重用ui
    static NSString *idenfity=@"CellMain";
    TargetChooseTableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:idenfity];
    if(cell==nil) {
        NSArray* arr = [[NSBundle mainBundle] loadNibNamed:@"TargetChooseTableViewCell" owner:self options:nil];
        for (id obj in arr) {
            if ([obj isKindOfClass:[TargetChooseTableViewCell class]]) {
                cell = (TargetChooseTableViewCell *)obj;
            }
        }
    }
    theCell = cell;
    
    // 表格单元选中时的颜色
    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cell.selectedBackgroundView.backgroundColor = UI_DEFAULT_TABLE_VIEW_SELECTED_BG_COLOR;
    // 为了跟表格背景色一致，cell的背景设为透明
    cell.backgroundColor = [UIColor clearColor];
    
    
    //------------------------------------------------------ 【2】UI值设置
    // 设置选择框的可见性
    cell.viewCheckIcon.hidden = !self.showCheckBox;
    cell.viewCheckIcon.image = [UIImage imageNamed:([ree selected]?@"common_check_box_solid_20dp_on":@"common_check_box_solid_20dp_off")];
    
    // 利表格单元对应的数据对象对ui进行设置
    cell.viewName.text = ree.targetName;
    // 群成员列表（如@用户选择）不显示用户ID
    if (self.supportedGroupMemberTargetSource && self.currentTab == self.groupMemberRadio) {
        cell.viewId.text = @"";
        cell.viewId.hidden = YES;
    } else {
        cell.viewId.text = ree.targetOtherInfo;
        cell.viewId.hidden = NO;
    }
    
    // 当前显示的是“最近聊天”tab时，尝试对进行表情显示处理
    if(self.currentTab == self.latestChattingRadio && ![BasicTool isStringEmpty:cell.viewId.text]) {
        // 【无效代码】：参考首页“消息”中显示表情的办法，会导致表情图标显示大小变的很大（跟控件本身的字体大小完全不一致）
//       NSDictionary *attributes = [cell.quoteContentLabel.attributedText attributesAtIndex:0 effectiveRange:nil];

        // 【有效代码】：参考聊天气泡中显示表情的办法，表情图标显示大小正常
        UIFont *vidFont = cell.viewId.font ?: [BasicTool getSystemFontOfSize:16.0f];
        NSDictionary *attributes = @{ NSFontAttributeName: vidFont };
        
        // 上述两种设置attributes的方式，会导致表情的显示效果不一致（为何第一种方法在首页“消息”中显示无异常，暂时原因未知）
        cell.viewId.attributedText = [EmojiUtil replaceEmojiWithPlanString:cell.viewId.text attributes:attributes];
    }
    
    if(ree.targetChatType != TARGET_CHAT_TYPE_FOR_AT_ALL) {
        cell.viewId.textColor = HexColor(0x999b9f);

        // 当前显示的是否是“最近聊天”数据源列表
        BOOL isLatestChattingChecked = self.latestChattingRadio.selected;
        BOOL isGroupTabChecked = self.groupRadio.selected;
        // 头像圆角半径
        CGFloat cornerRadius = 0;
        NSString *defaultAvatarName = @"";
        // 根据列表数据类型不同设置对应的圆角和默认头像文件名
        if(ree.targetChatType == CHAT_TYPE_GUEST_CHAT){
            cornerRadius = 22.0f;
            defaultAvatarName = @"main_alarms_tenpchat_message_icon";
        } else if(ree.targetChatType == CHAT_TYPE_FREIDN_CHAT) {
            cornerRadius = 22.0f;
            defaultAvatarName = @"main_alarms_chat_message_icon";
        } else if(ree.targetChatType == CHAT_TYPE_GROUP_CHAT) {
            cornerRadius = (isLatestChattingChecked || isGroupTabChecked) ? 22.0f : UI_DEFAULT_TABLE_VIEW_ICON_CORNER_RADIUS;
            defaultAvatarName = [GroupEntity isWorldChat:ree.targetId]? @"main_alarms_bbschat_message_icon" : @"groupchat_groups_icon_default";
        }
        // 图片圆角
        cell.viewAvatar.layer.cornerRadius = cornerRadius;
        cell.viewAvatar.layer.masksToBounds = YES;
        // 先设默认图标
        [cell.viewAvatar setImage:[UIImage imageNamed:defaultAvatarName]];
        
        // 根据列表数据类型不同异步加载网络头像（用户/陌生人支持视频头像播放）
        if(ree.targetChatType == CHAT_TYPE_GUEST_CHAT || ree.targetChatType == CHAT_TYPE_FREIDN_CHAT){
            [RBAvatarView setAvatarWithFileName:ree.userAvatarFileName uid:ree.targetId onImageView:cell.viewAvatar placeholder:[UIImage imageNamed:defaultAvatarName]];
        } else if(ree.targetChatType == CHAT_TYPE_GROUP_CHAT) {
            // 尝试为群组加载群头像
            [FileDownloadHelper loadGroupAvatar:ree.targetId logTag:@"TargetChooseViewController"
                                       complete:^(BOOL sucess, UIImage *img) {
                if(sucess && img != nil)
                    [cell.viewAvatar setImage:img];
            }];
        }
        
        
        //------------------------------------------------------ 【3】单元点击事件
        // 头像点击事件
        [BasicTool addFingerClick:cell.viewAvatar action:@selector(clickAvatarEvent:) target:self];
        // 将行索引号保存到tag里，在点击事件里就可以取到了（见 clickAvatarEvent: ）
        // 使用编码将section和row信息存储到tag中
        cell.viewAvatar.tag = indexPath.section * 10000 + indexPath.row;
    } else {
        // 针对"@所有人"item的说明：
        //  目前 TargetSourceGroupMember 暂时是专用于"@"功能时选择被"@"的成员时，暂时为了简化代码，
        // "@所有人"这个选项只能在 TargetChooseViewController 另用代码写死，暂时就不考虑"@"功能之外使用了，特此说明！
        cell.viewId.textColor = HexColor(0xff6432);
        [cell.viewAvatar setImage:[UIImage imageNamed:@"contact_list_header_my_groups_ico_45dp_y"]];
    }

    return theCell;
}

// 头像图片的点击事件
- (void)clickAvatarEvent:(UITapGestureRecognizer *)tap
{
    // tag里存放的是编码后的 section*10000+row
    NSInteger tag = tap.view.tag;
    NSInteger section = tag / 10000;
    NSInteger row = tag % 10000;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
    TargetEntity *ree = [self targetForIndexPath:indexPath];
    if (ree == nil) return;
    // 进入个人信息查看界面
    [self gotoWatchInfo:ree];
}


//-----------------------------------------------------------------------------------------------
#pragma mark - UITableViewDelegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexP
// 点击表格行时要调用的方法
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    TargetEntity *amd = [self targetForIndexPath:indexPath];

    if(amd != nil)
    {
        // 显示选择框的情况下
        if(self.showCheckBox)
        {
            BOOL isForwardChoose = (self.requestCode == TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD);
            // 支持多选
            if(!self.singleSelection && !isForwardChoose)
                amd.selected = !amd.selected;
            // 支持单选
            else
            {
                // 先取消其它的选中
                [self deSelectedAll];
                // 再选中当前
                amd.selected = YES;
            }
            
            // 并通知刷新列表ui
            [self refreshUI:NO];

            // 消息转发场景：点中目标后立刻完成，不再等待右上角“确定”
            if (isForwardChoose
                && self.chooseCompleteDelegate != nil) {
                if ([self.chooseCompleteDelegate respondsToSelector:@selector(processTargetChooseComplete:extraObj:requestCode:)]) {
                    [self.chooseCompleteDelegate processTargetChooseComplete:amd extraObj:self.extraObjFromItent requestCode:self.requestCode];
                }
                return;
            }
        }
        else
        {
            [self gotoWatchInfo:amd];
        }
    }
}

// 滚动时收起键盘
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self.searchTextField resignFirstResponder];
}

- (void)gotoWatchInfo:(TargetEntity *)amd {
    if(amd.targetChatType == CHAT_TYPE_GROUP_CHAT) {
        // 进入群资料界面
        [QueryGroupInfoAsync gotoWatchGroupInfo:amd.targetId withInfo:nil nav:self.navigationController view:self.view vc:self];
    } else {
        // 进入用户资料界面
        [QueryFriendInfoAsync gotoWatchUserInfo:amd.targetId withInfo:nil nav:self.navigationController view:self.view vc:self];
//      [QueryFriendInfoAsync doIt:NO mail:nil uid:amd.targetId hudParentView:self.view withNC:self.navigationController canOpenChat:YES];
    }
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 按钮事件相关处理方法

- (void)doSave:(UIBarButtonItem *)sender
{
    // 多选模式
    if (!self.singleSelection) {
        NSMutableArray<TargetEntity *> *selectedItems = [self getSelectedItems];
        if (selectedItems != nil && selectedItems.count > 0) {
            DLogDebug(@"【目标选择-多选】选择完成，共选中 %lu 个目标", (unsigned long)selectedItems.count);
            
            if (self.chooseCompleteDelegate != nil) {
                // 优先使用多选代理方法
                if ([self.chooseCompleteDelegate respondsToSelector:@selector(processMultiTargetChooseComplete:extraObj:requestCode:)]) {
                    [self.chooseCompleteDelegate processMultiTargetChooseComplete:selectedItems extraObj:self.extraObjFromItent requestCode:self.requestCode];
                }
                // 兼容旧的单选代理方法（逐个回调）
                else if ([self.chooseCompleteDelegate respondsToSelector:@selector(processTargetChooseComplete:extraObj:requestCode:)]) {
                    for (TargetEntity *te in selectedItems) {
                        [self.chooseCompleteDelegate processTargetChooseComplete:te extraObj:self.extraObjFromItent requestCode:self.requestCode];
                    }
                }
                if (self.requestCode != TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD) {
                    [self doBack:YES];
                }
            }
        } else {
            [BasicTool showAlertWarn:@"请至少选择一个目标！" parent:self];
        }
    }
    // 单选模式
    else {
        TargetEntity *ue = [self getSingleSelectedUser];
        if(ue != nil )
        {
            DLogDebug(@"【目标选择】选择完成，id=%@, name=%@", ue.targetId, ue.targetName);
            
            // 通知代理
            if(self.chooseCompleteDelegate != nil)
            {
                [self.chooseCompleteDelegate processTargetChooseComplete:ue extraObj:self.extraObjFromItent requestCode:self.requestCode];
                [self doBack:YES];
            }
        } else {
            [BasicTool showAlertWarn:@"选择的目标是空的！" parent:self];
        }
    }
}

// "随机查找"和"精确查找"Tab切换按钮事件处理
- (IBAction)clickTab:(id)sender
{
    UIButton *b = (UIButton *)sender;
    if(b.selected == NO)
    {
        // 切换Tab时清空搜索状态
        self.searchTextField.text = @"";
        [self.searchTextField resignFirstResponder];
        self.isSearching = NO;
        self.filteredDatas = nil;
        
        // 切换Tab时清空字母索引数据
        self.targetsWithLetter = nil;
        self.firstLetters = nil;
        
        // 根据当前Tab决定是否启用字母索引（好友、群聊、群成员均启用）
        if (b.tag == TargetSourceFriend || b.tag == TargetSourceGroup || b.tag == TargetSourceGroupMember) {
            self.enableAlphabetIndex = YES;
        } else {
            self.enableAlphabetIndex = NO;
        }
        
        // 设置tab按钮的选中的状态
        self.currentTab.selected = NO;
        self.currentTab = b;
        self.currentTab.selected = YES;
        
        // 加载对应源数据类型的数据
        [self loadDatas:self.currentTab.tag];

        self.title = [NSString stringWithFormat:@"选择%@", [b titleForState:UIControlStateNormal]];
        [self rb_targetChooseSyncPlainChromeNav];
    }
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 其它数据操作方法

/**
 * 获得单选模型下被选中的用户.
 */
- (TargetEntity *)getSingleSelectedUser
{
    TargetEntity *retGme = nil;

    for(TargetEntity *gme in (NSArray<TargetEntity *> *)([self.groupsDatas getDataList]))
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
 * 获得当前选中的行。
 */
- (NSMutableArray<TargetEntity *> *) getSelectedItems
{
    NSMutableArray<TargetEntity *> *items = [NSMutableArray array];
    for(TargetEntity *gme in (NSArray<TargetEntity *> *)([self.groupsDatas getDataList]))
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
    for(TargetEntity *gme in (NSArray<TargetEntity *> *)([self.groupsDatas getDataList]))
    {
        if(gme.selected)
            cnt += 1;
    }
    return cnt;
}


// 取消把在的选中状态
- (void) deSelectedAll
{
    for(TargetEntity *gme in (NSArray<TargetEntity *> *)([self.groupsDatas getDataList]))
    {
        gme.selected = NO;
    }
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 其它UI处理方法

// 刷新UI，当列表数据为空时显示提示信息UI，否则显示列表
- (void)refreshUI:(BOOL)forInit
{
    // 如果当前有搜索关键字，重新过滤数据
    if (self.isSearching && self.searchTextField.text.length > 0) {
        [self filterDataWithSearchText:self.searchTextField.text];
    }
    
    // 刷新表格数据显示
    [self.tableView reloadData];

    DDLogDebug(@"【用户选择界面】界面刷新了哦！forInit=%d, cnt=%ld", forInit, [[self.groupsDatas getDataList] count]);

    // 刷新UI布局（基于全量数据判断是否为空）
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

        if(self.singleSelection)
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

@end
