//telegram @wz662
#import "GroupChattingViewController.h"
#import "NSMutableArrayObservableEx.h"
#import "GroupEntity.h"
#import "GroupMemberEntity.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "NotificationCenterFactory.h"
#import "UserDefaultsToolKits.h"
#import "AppDelegate.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "UserEntity.h"
#import "AppDelegate.h"
#import "GMessageHelper.h"
#import "SendImageHelper.h"
#import "GChatDataHelper.h"
#import "SendVoiceHelper.h"
#import "GMessageHelper.h"
#import "BasicTool.h"
#import "ViewControllerFactory.h"
#import "QueryFriendInfoAsync.h"
#import "QueryGroupInfoAsync.h"
#import "BBSAlarmUIWrapper.h"
#import "Masonry.h"
#import "LPActionSheet.h"
#import "BigFileUploadManager.h"
#import "FileMeta.h"
#import "SendFileHelper.h"
#import "SendShortVideoHelper.h"
#import "AlarmType.h"
#import "LocationUtils.h"
#import "GroupsProvider.h"
#import "TimeTool.h"
#import "Default.h"
#import "AlarmsProvider.h"
#import "TargetEntity.h"
#import "WalletTransferViewController.h"
#import "WalletRedPacketSendViewController.h"
#import "GroupMemberViewController.h"
#import "ClientCoreSDK.h"
#import "MessagesProvider.h"

@interface ChatRootViewController (MessageListPrivate)
- (void)rb_markChatCollectionItemCountSynced;
@end

// 发送图片消息（从图片）
const int G_MORE_ACTION_ID_IMAGE          = 1;
// 发送图片消息（从相机）
const int G_MORE_ACTION_ID_PHOTO          = 2;
// 发送大文件
const int G_MORE_ACTION_ID_FILE           = 3;
// 发送短视频
const int G_MORE_ACTION_ID_SHORTVIDEO     = 4;
// 发送个人名片
const int G_MORE_ACTION_ID_CONTACT_FRIEND = 5;
// 发送群名片
const int G_MORE_ACTION_ID_CONTACT_GROUP  = 6;
// 发送位置
const int G_MORE_ACTION_ID_LOCATION       = 7;
// 收藏
const int G_MORE_ACTION_ID_FAVORITES      = 9;
// 红包
const int G_MORE_ACTION_ID_RED_PACKET     = 10;
// 转账
const int G_MORE_ACTION_ID_TRANSFER       = 11;
// 名片（底部弹窗选择个人名片或群名片）
const int G_MORE_ACTION_ID_CONTACT_MERGED = 12;


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface GroupChattingViewController ()

// 聊天列表的消息数据集合
@property (nonatomic, retain) NSMutableArrayObservableEx *chattingDatas;

// "我"的消息头像
@property (strong, nonatomic) UIImage *outgoingAvatarImage;
// 对方的消息头像(群聊中，此变量存放的是默认头像哦)
@property (strong, nonatomic) UIImage *incomingDefaultAvatarImage;

// 用于世界频道聊天时静音设置按钮（仅在本界面用于世界频道时有意义），用于低于ios 26的版本
@property (nonatomic, retain) UIButton *btnSilentSetup;
// 用于世界频道聊天时静音设置按钮（仅在本界面用于世界频道时有意义），用于最新ios 26的版本
@property (nonatomic, retain) UIBarButtonItem *btnSilentSetup_ios26;

//// 聊天消息数据模型变动观察者实现block
//@property (nonatomic, copy) ObserverCompletion chattingDatasObserver;

//// 设置{@link BigFileUploadManager}中大文件任务状态改变观察者block(主要用于"我"发送的大文件消息)，
//// 用于UI及时刷新文件上传状态在界面上的显示（本观察者通常由对应的UI界面设置，界面退到后台消失时取消设置）
//@property (nonatomic, copy) ObserverCompletion fileStatusChangedObserver;

/** 禁言提示遮罩视图（覆盖在输入框上方，禁言时显示） */
@property (nonatomic, strong) UIView *muteOverlayView;
/** 禁言提示标签 */
@property (nonatomic, strong) UILabel *muteOverlayLabel;
/** 当前用户在群中的角色：0=普通成员，1=管理员，2=群主 */
@property (nonatomic, assign) int myRoleInGroup;
/** 是否已被禁言（全群禁言或单人禁言） */
@property (nonatomic, assign) BOOL isMuted;

/** 群成员缓存字典（uid → GroupMemberEntity），用于管理员/群主查看成员入群信息 */
@property (nonatomic, strong) NSMutableDictionary<NSString *, GroupMemberEntity *> *cachedMembersDict;
/** 首屏昵称预取是否已完成。 */
@property (nonatomic, assign) BOOL rb_initialGroupMembersBootstrapDone;
/** 当前是否已给 chattingDatas 挂上 observer。 */
@property (nonatomic, assign) BOOL rb_chattingObserverAttached;

/** iOS26下显示在导航栏下方的群公告卡片 */
@property (nonatomic, strong) UIView *groupNoticeFloatingView;
/** 当前展示公告版本签名（用于“关闭后仅隐藏当前版本”） */
@property (nonatomic, copy) NSString *currentNoticeSignature;
/** 进群公告弹层遮罩 */
@property (nonatomic, strong) UIControl *groupNoticePopupMaskView;
/** 进群公告弹层卡片 */
@property (nonatomic, strong) UIView *groupNoticePopupCardView;

/// 右滑取消时避免导航栏动画导致闪烁（与 ChatViewController 一致）
@property (nonatomic, assign) BOOL oac_hadWillDisappearWithoutDid;
/// 被子页覆盖时移除了聊天列表 observer，返回后需至少补一次强制刷新，避免系统消息已入内存但 cell 未重绘
@property (nonatomic, assign) BOOL rb_needForceRefreshAfterCoveredDisappear;

@end


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation GroupChattingViewController

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil gid:(NSString *)gid gname:(NSString *)gname
{
    if(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        super.chatType = CHAT_TYPE_GROUP_CHAT;
        // 界面创建时传进来的参数：群组id
        self.toId = gid;
        // 界面创建时传进来的参数：群组名称
        self.toName = gname;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 群聊/大群：只显示对方头像，不显示我方头像
    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    if ([flowLayout respondsToSelector:@selector(setOutgoingAvatarViewSize:)]) {
        [(id)flowLayout setOutgoingAvatarViewSize:CGSizeZero];
    }

    // 界面ui初始化
    [self initGUI];

    // 初始化数据模型观察者
    [self initObservers];

    [NotificationCenterFactory quitOrDismissGroupComplete_ADD:self selector:@selector(quitOrDismissGroupComplete:)];
    [NotificationCenterFactory groupNameChanged_ADD:self selector:@selector(groupNameChanged:)];
    [NotificationCenterFactory largeGroupPullNotify_ADD:self selector:@selector(rb_onLargeGroupPullNotify:)];

    [self initToGroup];
    [self rb_deferredSetupAfterFirstFrame];
    [self initAvatarImage];
}

// 根据UIViewController的生命周期，本方法将在每次本界面每次回到前台时被调用
- (void)viewWillAppear:(BOOL)animated
{
    BOOL isReappearAfterCancelledPop = self.oac_hadWillDisappearWithoutDid;
    if (isReappearAfterCancelledPop) self.oac_hadWillDisappearWithoutDid = NO;
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
    [super viewWillAppear:animated];
    DDLogInfo(@"[RBGroupSysTrace][GroupVC] viewWillAppear gid=%@ observerAttached=%@ listCount=%ld cvCount=%ld initialBootstrap=%@",
              self.toId,
              self.rb_chattingObserverAttached ? @"YES" : @"NO",
              (long)[self getChattingDatasList].count,
              (long)[self.collectionView numberOfItemsInSection:0],
              self.rb_initialGroupMembersBootstrapDone ? @"YES" : @"NO");

    // 设置当前正处于激话状态下的聊天好友uid
    [IMClientManager sharedInstance].currentFrontGroupChattingGroupID = self.toId;

    // 聊天列表观察者仅在「可见」时需要：viewDidDisappear 会移除，此处先移除再添加，避免与 initToGroup 重复注册逻辑混淆
    if (self.rb_chattingObserverAttached && self.chattingDatas && self.chattingDatasObserver) {
        [self.chattingDatas removeObserver:self.chattingDatasObserver];
        self.rb_chattingObserverAttached = NO;
        [self rb_attachChattingObserverIfNeeded];
    } else if (self.rb_initialGroupMembersBootstrapDone) {
        [self rb_attachChattingObserverIfNeeded];
    }
    
    // 设置大文件上传状态变更观察者(主要用于“我”发送的大文件消息)
    [[BigFileUploadManager sharedInstance] setFileStatusChangedObserver:self.fileStatusChangedObserver];

//    // 世界频道
//    if([self isWorldChat])
//    {
//        // APP中唯一重置未读BBS聊天消息的代码：最后确保重置APP首页“BBS消息”未读消息数字的显示
//        [[[[IMClientManager sharedInstance] getAlarmsProvider] getBBSAlarmData] resetFlagNum];
//    }
//    else
    {
        if (self.rb_initialSessionUnreadCount <= 0) {
            AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
            int idx = ap ? [ap getAlarmIndex:AMT_groupChatMessage dataId:self.toId] : -1;
            if (idx >= 0) {
                self.rb_initialSessionUnreadCount = [ap getFlagNum:idx];
            }
        }
        // APP中唯一重置未读普通群聊消息的代码：最后确保重置APP首页“消息”未读消息数字的显示
//      [[[IMClientManager sharedInstance] getAlarmsProvider] resetGroupChatMessageFlagNum:self.gidForInit];
        [[[IMClientManager sharedInstance] getAlarmsProvider] resetFlagNum:AMT_groupChatMessage dataId:self.toId flagNumToReset:0 needUpdateSqlite:YES];

        // 及时刷新标题显示（因为从标题修改界面返回、或者群组标题被群主修改的情况下，标题需要及时更新）
        GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.toId];
        if(ge != nil)
        {
            NSLog(@"聊天界面中刷新时，ge.hash=%ldl, ge.g_name=%@", (unsigned long)ge.hash, ge.g_name);
            [self updateTitle:ge.g_name];
        }
        // 导航栏下群公告跑马灯（无公告或已关闭当前版本则不显示）
        [self refreshGroupNoticeTopBar];
    }

    // 发出通知：强制首页的"消息"Tab上的总未读数
    // * 此时通知刷新首页的"消息"Tab上的总未读数（首页"消息"页面其实已经增加了观察者到"消息"通知数据模型里，但数据模型只能通知道
    // * 到关于数据的新增、删除、替换，而像重置对象里的未读数这样的行为（如进入聊天界面时）是没有办法细化到此粒度的，所以此时在进入
    // * 聊天界面中重置该好友的未读数时，尝试手动发出此通知，使得首页"消息"Tab上的未读数气泡能及时刷新为最新，不然tab上的未读数就不同步了）
    [NotificationCenterFactory refreshMainPageTotalUnread_POST];

    // 禁言检测改到 viewDidAppear：从群成员/群资料返回时 WillAppear 阶段 inputToolbar 可能尚未就绪，applyMuteUI 访问 contentView 会闪退
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    DDLogInfo(@"[RBGroupSysTrace][GroupVC] viewDidAppear gid=%@ observerAttached=%@ needForceRefresh=%@ listCount=%ld cvCount=%ld",
              self.toId,
              self.rb_chattingObserverAttached ? @"YES" : @"NO",
              self.rb_needForceRefreshAfterCoveredDisappear ? @"YES" : @"NO",
              (long)[self getChattingDatasList].count,
              (long)[self.collectionView numberOfItemsInSection:0]);
    if (![self isWorldChat]) {
        [self loadGroupAvatarForNav];
        [self checkAndApplyMuteStatus];
    }

    // 从群成员/群资料等子页返回时，期间本地系统消息可能已写入会话内存，
    // 但聊天页在被覆盖时移除了 observer，返回后需主动把 collectionView 与数据源重新对齐。
    NSInteger listCount = (NSInteger)[self getChattingDatasList].count;
    NSInteger cvCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
    BOOL shouldForceRefresh = self.rb_needForceRefreshAfterCoveredDisappear;
    if (self.collectionView.window && shouldForceRefresh) {
        CGFloat bottomTol = 72.0f;
        BOOL userWasAtBottom = [self isLastCellVisible]
            || [self rb_isChatScrolledToBottomApproximatelyWithTolerance:bottomTol];
        __weak typeof(self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (!sself || !sself.collectionView.window) return;
            [sself refreshCollectionView];
            [sself.collectionView layoutIfNeeded];
            sself.rb_needForceRefreshAfterCoveredDisappear = NO;
            if (userWasAtBottom) {
                [sself rb_scrollChatToBottomAfterEnsuringLayoutAnimated:NO];
            }
        });
    }

    if (![self isWorldChat]) {
        [self rb_tryPresentGroupNoticePopupIfNeeded];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    BOOL leavingStack = self.isMovingFromParentViewController || self.isBeingDismissed;
    if (leavingStack)
        self.oac_hadWillDisappearWithoutDid = YES;
    UINavigationController *nav = self.navigationController;
    if (nav && !leavingStack) {
        [nav setNavigationBarHidden:NO animated:animated];
    }
}

- (void)showChatSearchBarAnimated:(BOOL)animated
{
    [super showChatSearchBarAnimated:animated];
}

- (void)hideChatSearchBarAnimated:(BOOL)animated
{
    [super hideChatSearchBarAnimated:animated];
}

// 根据UIViewController的生命周期，本方法将在每次本界面退至后台或者覆盖时被调用（生命周期中，本方法可能会被反复调用）
- (void)viewDidDisappear:(BOOL)animated
{
    // 取消设置当前正处于激话状态下的聊天好友uid
    [IMClientManager sharedInstance].currentFrontGroupChattingGroupID = nil;
    
    // 取消设置大文件上传状态变更观察者(主要用于“我”发送的大文件消息)
    [[BigFileUploadManager sharedInstance] setFileStatusChangedObserver:nil];

    // 进入子页（群信息/群成员等）时移除消息列表观察者，避免转场期间异步通知触发 collectionView 增量更新导致崩溃
    if (self.rb_chattingObserverAttached && self.chattingDatas && self.chattingDatasObserver) {
        DDLogInfo(@"[RBGroupSysTrace][GroupVC] viewDidDisappear-detach gid=%@ listCount=%ld cvCount=%ld",
                  self.toId,
                  (long)[self getChattingDatasList].count,
                  (long)[self.collectionView numberOfItemsInSection:0]);
        [self.chattingDatas removeObserver:self.chattingDatasObserver];
        self.rb_chattingObserverAttached = NO;
        self.rb_needForceRefreshAfterCoveredDisappear = YES;
    }

    [super viewDidDisappear:animated];
}

//// “viewDidUnload:”方法已在ios6后被废弃（且它只在系统内存低时才被调用），资源释放等工作正确的方式是放到 “dealloc:"中处理
//- (void)dealloc
////- (void)viewDidUnload
//{
////    // 取消注册通知：退群(作为普通群员时)或解散群(作为群主时)时，通知本群聊界面，以便群聊界面在收到通知后能自动关闭（因为已不在此群或群已不存在了嘛）
////    [NotificationCenterFactory quitOrDismissGroupComplete_REMOVE:self];
////    // 取消注册通知：收到群主修改群名称后，通知本群聊界面，以便群聊界面即时刷新最新标题显示
////    [NotificationCenterFactory groupNameChanged_REMOVE:self];
////
////    // 逆初始化：释放资源
////    [self deInitToGroup];
//
////    [super viewDidUnload];
//}

// Override - 界面退出时的清理动作
- (void)deallocImpl
{
    [super deallocImpl];
    
    // 取消注册通知：退群(作为普通群员时)或解散群(作为群主时)时，通知本群聊界面，以便群聊界面在收到通知后能自动关闭（因为已不在此群或群已不存在了嘛）
    [NotificationCenterFactory quitOrDismissGroupComplete_REMOVE:self];
    // 取消注册通知：收到群主修改群名称后，通知本群聊界面，以便群聊界面即时刷新最新标题显示
    [NotificationCenterFactory groupNameChanged_REMOVE:self];
    [NotificationCenterFactory largeGroupPullNotify_REMOVE:self];

    // 逆初始化：释放资源
    [self deInitToGroup];
}

- (void)initGUI
{
    // 普通群：极简返回 + 标题 + 群头像；世界频道仍由 rb_deferredSetupCustomNavigationBar 接管
    [self setupMinimalNavigationBar];
    if (@available(iOS 11.0, *)) {
        self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    // initMoreContentView、initMuteOverlay 已移至 ChatRootViewController rb_deferredSetupAfterFirstFrame / rb_deferredSetupAfterMoreContent，减轻首帧卡顿
}

/// 自定义顶栏：普通群右侧群头像；世界频道右侧「⋯」占位，稍后被静音等覆盖
- (void)setupMinimalNavigationBar
{
    [super setupMinimalNavigationBar];
    self.navigationItem.prompt = nil;
    if ([self isWorldChat]) {
        UIBarButtonItem *m = [self rb_minimalRightBarButtonItem];
        if (m.customView) {
            [self rb_attachViewToChatCustomNavRight:m.customView];
        }
    } else {
        [self rb_rightCircularAvatarBarButtonItemWithAction:@selector(onNavAvatarTapped)];
        [self loadGroupAvatarForNav];
    }
    self.title = self.toName;
}

- (void)rb_deferredSetupCustomNavigationBar
{
    if ([self isWorldChat]) {
        self.topExtraContainer.backgroundColor = [UIColor clearColor];
        if (@available(iOS 26, *)) {
            [self initBtnSilentSetup_ios26];
        } else {
            [self initBtnSilentSetup];
        }
        [self refreshMsgToneImage];
        if (@available(iOS 26, *)) {
            [GroupChattingViewController attachTopExtraView_ios26:self hintText:@"在线可聊・离线不发・重启清空"];
        } else {
            [GroupChattingViewController attachTopExtraView:self hintText:@"欢迎来到世界频道，在线用户皆可收到您的消息。" view1:nil];
        }
        self.title = self.toName;
        return;
    }
    self.title = self.toName;
}

- (void)rb_didSetupCustomNavigationBar
{
    self.topExtraContainer.backgroundColor = [UIColor clearColor];
    if ([self isWorldChat]) {
        // 世界群聊已在 rb_deferredSetupCustomNavigationBar 中完成，此处无额外操作
    } else {
        self.navigationItem.prompt = nil;
        [self rb_rightCircularAvatarBarButtonItemWithAction:@selector(onNavAvatarTapped)];
        [self loadGroupAvatarForNav];
        [self refreshGroupNoticeTopBar];
    }
}

- (void)loadGroupAvatarForNav
{
    if (self.navAvatarImageView) {
        [RBAvatarView removeAvatarFromImageView:self.navAvatarImageView];
        self.navAvatarImageView.image = [UIImage imageNamed:@"groupchat_groups_icon_default"];
    }
    __weak typeof(self) safeSelf = self;
    [FileDownloadHelper loadGroupAvatar:self.toId logTag:@"GroupChatVC-NavAvatar" complete:^(BOOL sucess, UIImage *img) {
        if (sucess && img) {
            [safeSelf updateNavAvatarWithImage:img];
        }
    }];
}

- (UIBarButtonItem *)customRightBarButtonItemForRestore
{
    if ([self isWorldChat]) {
        return [self rb_minimalRightBarButtonItem];
    }
    return nil;
}

- (void)exitMultiSelectMode
{
    [super exitMultiSelectMode];
    if ([self isWorldChat]) {
        if (@available(iOS 26, *)) {
            [self initBtnSilentSetup_ios26];
        } else {
            [self initBtnSilentSetup];
        }
    } else {
        [self loadGroupAvatarForNav];
    }
}

- (void)rb_deferredSetupAfterMoreContent
{
    [super rb_deferredSetupAfterMoreContent];
    [self initMuteOverlay];
}

- (void)onNavAvatarTapped
{
    [self gotoGroupInfo:nil];
}

// 本群公告关闭状态的本地存储key
- (NSString *)noticeDismissedDefaultsKey
{
    return [NSString stringWithFormat:@"group_notice_dismissed_signature_%@", self.toId ?: @""];
}

// 生成公告版本签名：公告内容 + 更新时间（无更新时间则仅内容）
- (NSString *)buildNoticeSignature:(GroupEntity *)ge notice:(NSString *)notice
{
    NSString *updateTime = [BasicTool trim:(ge ? ge.g_notice_updatetime : nil)];
    if ([BasicTool isStringEmpty:updateTime]) {
        return notice ?: @"";
    }
    return [NSString stringWithFormat:@"%@|%@", notice ?: @"", updateTime];
}

// 关闭当前公告（仅当前版本）
- (void)onCloseGroupNoticeTapped:(UIButton *)sender
{
    [self rb_markCurrentNoticeDismissed];
    
    [self.groupNoticeFloatingView removeFromSuperview];
    self.groupNoticeFloatingView = nil;
    [self.topExtraContainer.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.topExtraContainerHeightConstraint.constant = 0;
}

- (void)rb_markCurrentNoticeDismissed
{
    if (![BasicTool isStringEmpty:self.currentNoticeSignature]) {
        [[NSUserDefaults standardUserDefaults] setObject:self.currentNoticeSignature forKey:[self noticeDismissedDefaultsKey]];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSString *)rb_formattedGroupNoticeTime:(GroupEntity *)ge
{
    NSString *raw = [BasicTool trim:(ge ? ge.g_notice_updatetime : nil)];
    if ([BasicTool isStringEmpty:raw]) {
        return @"";
    }

    NSArray<NSString *> *inputFormats = @[@"yyyy-MM-dd HH:mm:ss", @"yyyy-MM-dd HH:mm"];
    for (NSString *inputFormat in inputFormats) {
        NSDateFormatter *inputFormatter = [[NSDateFormatter alloc] init];
        inputFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
        inputFormatter.timeZone = [NSTimeZone localTimeZone];
        inputFormatter.dateFormat = inputFormat;
        NSDate *date = [inputFormatter dateFromString:raw];
        if (date != nil) {
            NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
            outputFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
            outputFormatter.timeZone = [NSTimeZone localTimeZone];
            outputFormatter.dateFormat = [inputFormat isEqualToString:@"yyyy-MM-dd HH:mm:ss"] ? @"yyyy年MM月dd日 HH:mm:ss" : @"yyyy年MM月dd日 HH:mm";
            return [outputFormatter stringFromDate:date] ?: raw;
        }
    }
    return raw;
}

- (NSString *)rb_formattedGroupNoticePublisher:(GroupEntity *)ge
{
    NSString *publisher = [BasicTool trim:(ge ? ge.g_notice_updatenick : nil)];
    if ([BasicTool isStringEmpty:publisher]) {
        publisher = [BasicTool trim:(ge ? ge.g_owner_name : nil)];
    }
    if ([BasicTool isStringEmpty:publisher]) {
        publisher = [BasicTool trim:(ge ? ge.g_notice_updateuid : nil)];
    }
    if ([BasicTool isStringEmpty:publisher]) {
        publisher = [BasicTool trim:(ge ? ge.g_owner_user_uid : nil)];
    }
    if ([BasicTool isStringEmpty:publisher]) {
        publisher = @"未知";
    }
    return [NSString stringWithFormat:@"发布人：%@", publisher];
}

- (void)rb_dismissGroupNoticePopupAnimated:(BOOL)animated
{
    if (self.groupNoticePopupMaskView == nil) {
        return;
    }
    UIControl *maskView = self.groupNoticePopupMaskView;
    UIView *cardView = self.groupNoticePopupCardView;
    self.groupNoticePopupMaskView = nil;
    self.groupNoticePopupCardView = nil;

    void (^cleanup)(void) = ^{
        [cardView removeFromSuperview];
        [maskView removeFromSuperview];
    };

    if (!animated) {
        cleanup();
        return;
    }

    [UIView animateWithDuration:0.22 animations:^{
        maskView.alpha = 0.0f;
        cardView.transform = CGAffineTransformMakeTranslation(0.0f, CGRectGetHeight(maskView.bounds));
    } completion:^(__unused BOOL finished) {
        cleanup();
    }];
}

- (void)onConfirmGroupNoticePopupTapped:(UIButton *)sender
{
    (void)sender;
    [self onCloseGroupNoticeTapped:nil];
    [self rb_dismissGroupNoticePopupAnimated:YES];
}

- (UIImage *)rb_imageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0, 0, 4, 4);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
    [color setFill];
    UIRectFill(rect);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)rb_tryPresentGroupNoticePopupIfNeeded
{
    if (self.groupNoticePopupMaskView != nil || self.view.window == nil) {        return;
    }

    GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.toId];
    NSString *notice = [BasicTool trim:ge.g_notice];
    if ([BasicTool isStringEmpty:notice]) {        return;
    }

    NSString *sig = [self buildNoticeSignature:ge notice:notice];
    NSString *dismissed = [[NSUserDefaults standardUserDefaults] stringForKey:[self noticeDismissedDefaultsKey]];
    if (sig.length > 0 && dismissed != nil && [sig isEqualToString:dismissed]) {        return;
    }
    self.currentNoticeSignature = sig;
    UIControl *maskView = [[UIControl alloc] initWithFrame:self.view.bounds];
    maskView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    maskView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.32f];
    maskView.alpha = 0.0f;
    [self.view addSubview:maskView];

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = [UIColor whiteColor];
    cardView.layer.cornerRadius = 24.0f;
    cardView.layer.masksToBounds = YES;
    if (@available(iOS 11.0, *)) {
        cardView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    }
    [maskView addSubview:cardView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"群公告";
    titleLabel.font = [UIFont boldSystemFontOfSize:[BasicTool getAdjustedFontSize:22.0f]];
    titleLabel.textColor = [UIColor blackColor];
    [cardView addSubview:titleLabel];

    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    timeLabel.text = [self rb_formattedGroupNoticeTime:ge];
    timeLabel.font = [UIFont systemFontOfSize:[BasicTool getAdjustedFontSize:13.0f]];
    timeLabel.textColor = HexColor(0xB6B6B6);
    [cardView addSubview:timeLabel];

    UILabel *publisherLabel = [[UILabel alloc] init];
    publisherLabel.translatesAutoresizingMaskIntoConstraints = NO;
    publisherLabel.text = [self rb_formattedGroupNoticePublisher:ge];
    publisherLabel.font = [UIFont systemFontOfSize:[BasicTool getAdjustedFontSize:13.0f]];
    publisherLabel.textColor = HexColor(0x8E8E93);
    publisherLabel.numberOfLines = 1;
    [cardView addSubview:publisherLabel];

    UITextView *contentView = [[UITextView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = [UIColor clearColor];
    contentView.text = notice;
    contentView.textColor = [UIColor blackColor];
    contentView.font = [UIFont systemFontOfSize:[BasicTool getAdjustedFontSize:19.0f]];
    contentView.editable = NO;
    contentView.selectable = NO;
    contentView.scrollEnabled = YES;
    contentView.textContainerInset = UIEdgeInsetsZero;
    contentView.textContainer.lineFragmentPadding = 0;
    [cardView addSubview:contentView];

    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
    [confirmButton setTitle:@"我知道了" forState:UIControlStateNormal];
    confirmButton.titleLabel.font = [UIFont boldSystemFontOfSize:[BasicTool getAdjustedFontSize:18.0f]];
    [confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    confirmButton.layer.cornerRadius = 26.0f;
    confirmButton.layer.masksToBounds = YES;
    UIImage *buttonBg = [self rb_imageWithColor:[UIColor colorWithRed:0.13f green:0.84f blue:0.66f alpha:1.0f]];
    [confirmButton setBackgroundImage:buttonBg forState:UIControlStateNormal];
    [confirmButton setBackgroundImage:buttonBg forState:UIControlStateHighlighted];
    [confirmButton addTarget:self action:@selector(onConfirmGroupNoticePopupTapped:) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:confirmButton];

    [NSLayoutConstraint activateConstraints:@[
        [cardView.leadingAnchor constraintEqualToAnchor:maskView.leadingAnchor],
        [cardView.trailingAnchor constraintEqualToAnchor:maskView.trailingAnchor],
        [cardView.bottomAnchor constraintEqualToAnchor:maskView.bottomAnchor],
        [cardView.heightAnchor constraintLessThanOrEqualToConstant:MIN(CGRectGetHeight(self.view.bounds) * 0.78f, 560.0f)],

        [titleLabel.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:34.0f],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:28.0f],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-28.0f],

        [timeLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10.0f],
        [timeLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [timeLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [publisherLabel.topAnchor constraintEqualToAnchor:timeLabel.bottomAnchor constant:6.0f],
        [publisherLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [publisherLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [contentView.topAnchor constraintEqualToAnchor:publisherLabel.bottomAnchor constant:20.0f],
        [contentView.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [contentView.heightAnchor constraintLessThanOrEqualToConstant:260.0f],
        [contentView.heightAnchor constraintGreaterThanOrEqualToConstant:88.0f],

        [confirmButton.topAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:28.0f],
        [confirmButton.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20.0f],
        [confirmButton.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20.0f],
        [confirmButton.heightAnchor constraintEqualToConstant:52.0f],
        [confirmButton.bottomAnchor constraintEqualToAnchor:cardView.safeAreaLayoutGuide.bottomAnchor constant:-34.0f],
    ]];

    self.groupNoticePopupMaskView = maskView;
    self.groupNoticePopupCardView = cardView;
    [maskView layoutIfNeeded];
    cardView.transform = CGAffineTransformMakeTranslation(0.0f, CGRectGetHeight(cardView.bounds) > 0 ? CGRectGetHeight(cardView.bounds) : CGRectGetHeight(maskView.bounds));

    [UIView animateWithDuration:0.24 animations:^{
        maskView.alpha = 1.0f;
        cardView.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {    }];
}

// 公告内容：短文本静态显示，长文本自动横向轮播
- (void)setupNoticeTickerInView:(UIView *)container text:(NSString *)text
{
    [container.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    container.clipsToBounds = YES;
    
    UIFont *font = [UIFont systemFontOfSize:[BasicTool getAdjustedFontSize:15.0f] weight:UIFontWeightRegular];
    UIColor *textColor = HexColor(0x111111);
    
    // 先放一个基础label，避免异步布局前出现空白
    UILabel *fallbackLabel = [[UILabel alloc] initWithFrame:container.bounds];
    fallbackLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    fallbackLabel.text = text;
    fallbackLabel.textColor = textColor;
    fallbackLabel.font = font;
    fallbackLabel.numberOfLines = 1;
    fallbackLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [container addSubview:fallbackLabel];
    
    __weak typeof(container) weakContainer = container;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *strongContainer = weakContainer;
        if (!strongContainer) return;
        
        [strongContainer layoutIfNeeded];
        CGFloat width = CGRectGetWidth(strongContainer.bounds);
        CGFloat height = CGRectGetHeight(strongContainer.bounds);
        if (width <= 0 || height <= 0) return;
        
        UIFont *attrsFont = font ?: [UIFont systemFontOfSize:15];
        NSDictionary *attrs = @{ NSFontAttributeName: attrsFont };
        CGFloat textWidth = ceil([text boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, height)
                                                    options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                                 attributes:attrs
                                                    context:nil].size.width);
        
        [strongContainer.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        
        // 文本不长：静态显示
        if (textWidth <= width) {
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width, height)];
            label.text = text;
            label.textColor = textColor;
            label.font = font;
            label.numberOfLines = 1;
            label.lineBreakMode = NSLineBreakByTruncatingTail;
            [strongContainer addSubview:label];
            return;
        }
        
        // 文本过长：双份内容循环滚动
        CGFloat gap = 36.0f;
        UIView *trackView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, textWidth * 2 + gap, height)];
        
        UILabel *label1 = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, textWidth, height)];
        label1.text = text;
        label1.textColor = textColor;
        label1.font = font;
        label1.numberOfLines = 1;
        
        UILabel *label2 = [[UILabel alloc] initWithFrame:CGRectMake(textWidth + gap, 0, textWidth, height)];
        label2.text = text;
        label2.textColor = textColor;
        label2.font = font;
        label2.numberOfLines = 1;
        
        [trackView addSubview:label1];
        [trackView addSubview:label2];
        [strongContainer addSubview:trackView];
        
        [trackView.layer removeAllAnimations];
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
        animation.fromValue = @(0);
        animation.toValue = @(-(textWidth + gap));
        animation.duration = MAX(6.0, (textWidth + gap) / 28.0);
        animation.repeatCount = HUGE_VALF;
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeForwards;
        [trackView.layer addAnimation:animation forKey:@"noticeTickerAnimation"];
    });
}

// 导航栏下方群公告跑马灯（长文横向滚动）；世界频道不展示；用户关闭当前版本后不再展示直至公告更新
- (void)refreshGroupNoticeTopBar
{    if (@available(iOS 26, *)) {
        self.navigationItem.subtitle = nil;
    }
    if ([self isWorldChat]) {
        [self.groupNoticeFloatingView removeFromSuperview];
        self.groupNoticeFloatingView = nil;
        [self.topExtraContainer.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        self.topExtraContainerHeightConstraint.constant = 0;
        self.topExtraContainer.backgroundColor = [UIColor clearColor];        return;
    }

    GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.toId];
    NSString *notice = [BasicTool trim:ge.g_notice];
    if ([BasicTool isStringEmpty:notice]) {
        [self.groupNoticeFloatingView removeFromSuperview];
        self.groupNoticeFloatingView = nil;
        [self.topExtraContainer.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        self.topExtraContainerHeightConstraint.constant = 0;
        self.topExtraContainer.backgroundColor = [UIColor clearColor];        return;
    }

    NSString *sig = [self buildNoticeSignature:ge notice:notice];
    NSString *dismissed = [[NSUserDefaults standardUserDefaults] stringForKey:[self noticeDismissedDefaultsKey]];
    if (sig.length > 0 && dismissed != nil && [sig isEqualToString:dismissed]) {
        [self.groupNoticeFloatingView removeFromSuperview];
        self.groupNoticeFloatingView = nil;
        [self.topExtraContainer.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        self.topExtraContainerHeightConstraint.constant = 0;
        self.topExtraContainer.backgroundColor = [UIColor clearColor];        return;
    }
    if (self.topExtraContainer.subviews.count > 0
        && self.topExtraContainerHeightConstraint.constant > 0.0f
        && self.currentNoticeSignature.length > 0
        && [self.currentNoticeSignature isEqualToString:sig]) {        return;
    }

    [self.groupNoticeFloatingView removeFromSuperview];
    self.groupNoticeFloatingView = nil;
    [self.topExtraContainer.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.topExtraContainerHeightConstraint.constant = 0;
    self.topExtraContainer.backgroundColor = [UIColor clearColor];
    self.currentNoticeSignature = sig;

    const CGFloat barH = 36.f;
    const CGFloat padX = 12.f;
    const CGFloat gap = 8.f;
    const CGFloat closeBtnW = 32.f;

    self.topExtraContainerHeightConstraint.constant = barH;
    self.topExtraContainer.backgroundColor = [UIColor colorWithRed:255/255.0 green:251/255.0 blue:230/255.0 alpha:1.0];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"群公告";
    titleLabel.font = [UIFont systemFontOfSize:[BasicTool getAdjustedFontSize:13.f] weight:UIFontWeightSemibold];
    titleLabel.textColor = HexColor(0x333333);
    titleLabel.numberOfLines = 1;
    [self.topExtraContainer addSubview:titleLabel];
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.topExtraContainer).offset(padX);
        make.centerY.equalTo(self.topExtraContainer);
    }];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setTitle:@"×" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:[BasicTool getAdjustedFontSize:18.f] weight:UIFontWeightMedium];
    closeBtn.tintColor = HexColor(0x888888);
    [closeBtn addTarget:self action:@selector(onCloseGroupNoticeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.topExtraContainer addSubview:closeBtn];
    [closeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.topExtraContainer).offset(-4);
        make.centerY.equalTo(self.topExtraContainer);
        make.width.mas_equalTo(closeBtnW);
        make.height.mas_equalTo(barH);
    }];

    UIView *tickerWrap = [[UIView alloc] init];
    tickerWrap.backgroundColor = [UIColor clearColor];
    [self.topExtraContainer addSubview:tickerWrap];
    [tickerWrap mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(titleLabel.mas_right).offset(gap);
        make.right.equalTo(closeBtn.mas_left).offset(-2);
        make.top.bottom.equalTo(self.topExtraContainer);
    }];

    [self setupNoticeTickerInView:tickerWrap text:notice];

    [self.topExtraContainer layoutIfNeeded];}

// 初始化静音设置按钮（用于低于ios 26的系统）
- (void)initBtnSilentSetup {
    self.btnSilentSetup = [BBSAlarmUIWrapper createCunstomNavigationBunttonForBBSChatting:[UIImage imageNamed:@"multi_chatting_list_view_silence_off"] action:@selector(gotoDoSetupSilentForBBS:) target:self];

    // 将btnSilentSetup放置于多一层的view的目的是，实现导航栏按钮的x位置设置（参考：https://www.jianshu.com/p/5f3eae0c0bd9）
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.btnSilentSetup.frame.size.width, self.btnSilentSetup.frame.size.height)];
    [view addSubview:self.btnSilentSetup];

    // 定制导航栏按钮；展示在自定义顶栏右侧（系统导航栏已隐藏）
    self.navigationItem.rightBarButtonItem = nil;
    [self rb_attachViewToChatCustomNavRight:view];
}

// 初始化静音设置按钮（用于ios 26）
- (void)initBtnSilentSetup_ios26 {
    UIView *wrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setImage:[UIImage imageNamed:@"multi_chatting_list_view_silence_off_ios26"] forState:UIControlStateNormal];
    btn.tintColor = [UIColor blackColor];
    btn.frame = wrap.bounds;
    btn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [btn addTarget:self action:@selector(gotoDoSetupSilentForBBS:) forControlEvents:UIControlEventTouchUpInside];
    [wrap addSubview:btn];
    self.btnSilentSetup_ios26 = [[UIBarButtonItem alloc] initWithCustomView:wrap];
    self.navigationItem.rightBarButtonItem = nil;
    [self rb_attachViewToChatCustomNavRight:wrap];
}


// 初始化“（+）更多”内容面板
- (void)initMoreContentView
{
    // 设置代理以便在本类中处理面板中的点击事件
    self.bottomBoxMoreView.delegate = self;

    NSMutableArray *moreMenuItems = [NSMutableArray array];

    kmMoreMenuItem *shareMenuItem1 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_img"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_img"] title:@"照片" actionId:G_MORE_ACTION_ID_IMAGE];
    kmMoreMenuItem *shareMenuItem2 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_camra"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_camra"] title:@"拍摄" actionId:G_MORE_ACTION_ID_PHOTO];
    kmMoreMenuItem *shareMenuItem3 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_file"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_file"] title:@"文件" actionId:G_MORE_ACTION_ID_FILE];
    
    kmMoreMenuItem *shareMenuItem5 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_location"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_location"] title:@"位置" actionId:G_MORE_ACTION_ID_LOCATION];
    
    kmMoreMenuItem *shareMenuItemContact = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_user"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_user"] title:@"名片" actionId:G_MORE_ACTION_ID_CONTACT_MERGED];
    // 收藏按钮
    kmMoreMenuItem *shareMenuItemFavorites = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"scc"]  highlightIconImage:[UIImage imageNamed:@"scc"] title:@"收藏" actionId:G_MORE_ACTION_ID_FAVORITES];
    shareMenuItemFavorites.usesCompactMenuIcon = YES;
    // 红包按钮
    kmMoreMenuItem *shareMenuItemRedPacket = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"wallet_icon2"]  highlightIconImage:[UIImage imageNamed:@"wallet_icon2"] title:@"红包" actionId:G_MORE_ACTION_ID_RED_PACKET];
    shareMenuItemRedPacket.usesCompactMenuIcon = YES;
    // 群聊中不显示转账（仅单聊显示）

    // 与单聊一致：基础功能在前，收藏/红包在后；不含短视频入口
    [moreMenuItems addObject:shareMenuItem1];
    [moreMenuItems addObject:shareMenuItem2];
    [moreMenuItems addObject:shareMenuItem3];
    [moreMenuItems addObject:shareMenuItem5];
    [moreMenuItems addObject:shareMenuItemContact];
    [moreMenuItems addObject:shareMenuItemFavorites];
    [moreMenuItems addObject:shareMenuItemRedPacket];

    self.bottomBoxMoreView.shareMenuItems = moreMenuItems;
}


/**
 * 初始化与该好友的聊天相关设置.
 */
- (void)initToGroup
{
    if(self.toId == nil)
    {
        [APP showToastError:@"切换到群聊界面失败了，原因是无效参数！"];
        return;
    }

    // 与单聊一致：仅 SQLite 同步首屏 + 观察者；历史与漫游由父类 ChatRoot（下拉 / HTTP 更早消息等）处理，不使用大群 1016 seq 增量拉取
    GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.toId];
    NSLog(@"【GroupChattingVC】initToGroup: gid=%@, group_mode=%d", self.toId, ge ? ge.group_mode : -1);

    if (RB_CHAT_PAGE_DB_ONLY) {
        [[[IMClientManager sharedInstance] getGroupsMessagesProvider] clearMessages:self.toId];
    }
    MessagesProvider *provider = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
    self.chattingDatas = [provider getMessages:self.toId];
    self.rb_chattingObserverAttached = NO;
    self.rb_initialGroupMembersBootstrapDone = [self isWorldChat];
    BOOL changedBeforeFirstPaint = [self rb_applyGroupMemberNicknamesToMessages];
    BOOL sqliteBootstrapping = [provider rb_isSqliteBootstrapInProgressForChatUid:self.toId];
    BOOL shouldDelayInitialRenderForMembers = ![self isWorldChat];    self.rb_shouldDeferInitialChatListReloadUntilSqliteBootstrap =
        (shouldDelayInitialRenderForMembers || ([self.chattingDatas getDataList].count == 0 && sqliteBootstrapping));
    if (shouldDelayInitialRenderForMembers) {
        [self rb_prefetchGroupMembersForInitialRender];
    } else {
        [self rb_attachChattingObserverIfNeeded];
    }
}

- (NSString *)rb_groupDisplayNameForUser:(NSString *)userId fallback:(NSString *)fallbackName
{
    if ([BasicTool isStringEmpty:userId]) {
        return fallbackName ?: @"";
    }

    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (localUid.length > 0 && [localUid isEqualToString:userId]) {
        NSString *myGroupNickname = [GroupsProvider getMyNickNameInGroupEx:self.toId];
        if (![BasicTool isStringEmpty:myGroupNickname]) {
            return myGroupNickname;
        }
    }

    GroupMemberEntity *memberInfo = [self.cachedMembersDict objectForKey:userId];
    if (memberInfo != nil) {
        NSString *groupNickname = [GroupsProvider getNickNameInGroup:memberInfo.nickname and:memberInfo.nickname_ingroup];
        if (![BasicTool isStringEmpty:groupNickname]) {
            return groupNickname;
        }
    }

    if (![BasicTool isStringEmpty:fallbackName]) {
        return fallbackName;
    }
    return userId;
}

- (BOOL)rb_applyGroupMemberNicknamesToMessages
{
    NSMutableArray<JSQMessage *> *messages = [self getChattingDatasList];
    if (messages.count == 0) {        return NO;
    }

    BOOL didChange = NO;
    NSInteger changedCount = 0;
    NSMutableArray<NSString *> *samples = [NSMutableArray array];

    for (JSQMessage *message in messages) {
        if (message == nil || [message isControl]) {
            continue;
        }

        NSString *oldDisplayName = message.senderDisplayName ?: @"";
        NSString *resolvedDisplayName = [self rb_groupDisplayNameForUser:message.senderId fallback:message.senderDisplayName];
        if (![BasicTool isStringEmpty:resolvedDisplayName] && ![resolvedDisplayName isEqualToString:(message.senderDisplayName ?: @"")]) {
            message.senderDisplayName = resolvedDisplayName;
            didChange = YES;
            changedCount++;
            if (samples.count < 5) {
                [samples addObject:[NSString stringWithFormat:@"msg sender=%@ %@->%@", message.senderId ?: @"", oldDisplayName, resolvedDisplayName]];
            }
        }

        if (![BasicTool isStringEmpty:message.quote_sender_uid]) {
            NSString *oldQuoteNick = message.quote_sender_nick ?: @"";
            NSString *resolvedQuoteNick = [self rb_groupDisplayNameForUser:message.quote_sender_uid fallback:message.quote_sender_nick];
            if (![BasicTool isStringEmpty:resolvedQuoteNick] && ![resolvedQuoteNick isEqualToString:(message.quote_sender_nick ?: @"")]) {
                message.quote_sender_nick = resolvedQuoteNick;
                didChange = YES;
                changedCount++;
                if (samples.count < 5) {
                    [samples addObject:[NSString stringWithFormat:@"quote sender=%@ %@->%@", message.quote_sender_uid ?: @"", oldQuoteNick, resolvedQuoteNick]];
                }
            }
        }
    }    return didChange;
}

- (void)rb_attachChattingObserverIfNeeded
{
    if (self.rb_chattingObserverAttached || self.chattingDatas == nil || self.chattingDatasObserver == nil) {
        DDLogInfo(@"[RBGroupSysTrace][GroupVC] attachObserver-skip gid=%@ attached=%@ chattingDatas=%@ observer=%@",
                  self.toId,
                  self.rb_chattingObserverAttached ? @"YES" : @"NO",
                  self.chattingDatas ? @"YES" : @"NO",
                  self.chattingDatasObserver ? @"YES" : @"NO");
        return;
    }
    [self.chattingDatas addObserver:self.chattingDatasObserver];
    self.rb_chattingObserverAttached = YES;
    DDLogInfo(@"[RBGroupSysTrace][GroupVC] attachObserver-done gid=%@ listCount=%ld cvCount=%ld",
              self.toId,
              (long)[self getChattingDatasList].count,
              (long)[self.collectionView numberOfItemsInSection:0]);
}

- (void)rb_tryPresentInitialChatMessagesIfReadyWithReason:(NSString *)reason
{
    if ([self isWorldChat]) {
        [self rb_attachChattingObserverIfNeeded];
        return;
    }
    if (!self.rb_initialGroupMembersBootstrapDone) {        return;
    }

    MessagesProvider *provider = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
    BOOL sqliteBootstrapping = [provider rb_isSqliteBootstrapInProgressForChatUid:self.toId];
    NSUInteger listCount = [self getChattingDatasList].count;
    NSInteger visibleCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];

    [self rb_attachChattingObserverIfNeeded];

    if (sqliteBootstrapping && listCount == 0) {        return;
    }

    if (visibleCount == 0 && listCount > 0) {        self.rb_shouldDeferInitialChatListReloadUntilSqliteBootstrap = NO;
        [self refreshCollectionView];
        [self.collectionView layoutIfNeeded];
        [self rb_markChatCollectionItemCountSynced];
        if ([BasicTool trim:self.highlightOnceMsgFingerprint].length == 0) {
            [self rb_scrollChatToBottomAfterEnsuringLayoutAnimated:NO];
        }
    }
}

- (void)rb_prefetchGroupMembersForInitialRender
{
    if ([self isWorldChat]) {
        self.rb_initialGroupMembersBootstrapDone = YES;
        [self rb_attachChattingObserverIfNeeded];
        return;
    }

    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (myUid.length == 0) {
        self.rb_initialGroupMembersBootstrapDone = YES;
        [self rb_attachChattingObserverIfNeeded];
        return;
    }

    __weak typeof(self) weakSelf = self;    [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:self.toId requestUid:myUid complete:^(BOOL sucess, NSMutableArray<GroupMemberEntity *> *membersList) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            NSMutableDictionary<NSString *, GroupMemberEntity *> *membersCache = [NSMutableDictionary dictionary];
            int myRole = strongSelf.myRoleInGroup;
            if (sucess && membersList != nil) {
                for (GroupMemberEntity *m in membersList) {
                    if (m.user_uid != nil) {
                        membersCache[m.user_uid] = m;
                    }
                    if ([m.user_uid isEqualToString:myUid]) {
                        myRole = m.role;
                    }
                }
            }

            if (membersCache.count > 0) {
                strongSelf.cachedMembersDict = membersCache;
            }
            strongSelf.myRoleInGroup = myRole;
            strongSelf.rb_initialGroupMembersBootstrapDone = YES;

            BOOL changed = [strongSelf rb_applyGroupMemberNicknamesToMessages];            [strongSelf rb_tryPresentInitialChatMessagesIfReadyWithReason:@"membersPrefetched"];
        });
    } hudParentView:nil];
}

/**
 加载用户头像。
 */
- (void)initAvatarImage
{
    // 先设置好用户头像默认值（默认头像缓存起来，接下来聊天显示时就不需要每次加载了，提升性能）
    self.outgoingAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:[UIImage imageNamed:@"chat_avatar_default"] diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
    self.incomingDefaultAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:[UIImage imageNamed:@"chat_avatar_default"] diameter:kJSQMessagesCollectionViewAvatarSizeDefault];

    // 本地用户头像在气泡中通过 RBAvatarView 按需加载
    UserEntity *curUser = [IMClientManager sharedInstance].localUserInfo;
    if (curUser && ![BasicTool isStringEmpty:curUser.userAvatarFileName]) {
        self.outgoingAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:[UIImage imageNamed:@"chat_avatar_default"] diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
    }

    // 因群聊为一对多聊天方式，其它群友的头像加载逻辑请见[self rb_collectionView: cellForItemAtIndexPath_avatar: withImageView:]方法的代码！
}

/**
 * 逆初始化群聊天相关设置.
 * <p>
 * 本方法在资源回收时调用，是方法 {@link #initToGroup:}的逆方法.
 */
- (void)deInitToGroup
{
    // 取消设置聊天消息数据模型观察者
    [self.chattingDatas removeObserver:self.chattingDatasObserver];
}

// @Override-重写父类方法：返回聊天列表的消息数据集合对象引用
- (NSMutableArray<JSQMessage *> *) getChattingDatasList
{
    return [self.chattingDatas getDataList];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (![self isWorldChat]
        && self.rb_shouldDeferInitialChatListReloadUntilSqliteBootstrap
        && !self.rb_initialGroupMembersBootstrapDone) {        return 0;
    }
    return [super collectionView:collectionView numberOfItemsInSection:section];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - Actions

// 标题栏右边“查看好友”按钮的点击事件处理（仅用于普通群聊）
- (void)gotoGroupInfo:(UIBarButtonItem *)sender
{
    // 查看群基本信息：有缓存时直接传 ge 做同步 push，避免 doIt 异步回调时本 VC 已不在栈顶导致返回时误退到群聊列表（大群等场景易复现 1～2 次）
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    if (localUserInfo == nil) return;
    GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.toId];
    [QueryGroupInfoAsync gotoWatchGroupInfo:self.toId withInfo:ge nav:self.navigationController view:self.view vc:self];
}

// 设置或取消设置静音（仅用于世界频道，1008-4-38）
- (void)gotoDoSetupSilentForBBS:(UIBarButtonItem *)sender
{
    BOOL wasToneOpen = [UserDefaultsToolKits isChatMsgToneOpen:self.toId];
    BOOL targetMuteOn = wasToneOpen;
    NSString *luid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
    if ([BasicTool isStringEmpty:luid]) {
        [APP showToastWarn:@"未登录"];
        return;
    }
    [UserDefaultsToolKits setChatMsgToneOpen:!wasToneOpen chatId:self.toId];
    [self refreshMsgToneImage];
    [APP showToastInfo:(targetMuteOn ? @"世界频道已开启免打扰。" : @"世界频道已关闭免打扰。")];

    __weak typeof(self) safeSelf = self;
    [[HttpRestHelper sharedInstance] submitConversationMsgMuteToServer:luid partnerId:self.toId chatType:@"2" muteOn:targetMuteOn complete:^(BOOL sucess, NSString *resultCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!sucess) {
                [UserDefaultsToolKits setChatMsgToneOpen:wasToneOpen chatId:safeSelf.toId];
                [safeSelf refreshMsgToneImage];
                [APP showToastWarn:@"免打扰设置同步失败"];
            }
        });
    } hudParentView:nil];
}

- (void)finishReceivingMessageAnimated:(BOOL)animated forceDontScrollToBottom:(BOOL)forceDontScrollToBottom
{
    BOOL changed = [self rb_applyGroupMemberNicknamesToMessages];    [super finishReceivingMessageAnimated:animated forceDontScrollToBottom:forceDontScrollToBottom];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - kmMoreMenuViewDelegate（ “(+)更多”功能的item点击代理方法 ）

- (void)didSelecteMoreMenuItem:(kmMoreMenuItem *)shareMenuItem atIndex:(NSInteger)index
{
    switch (shareMenuItem.actionId)
    {
            // 发送图片消息（从图片）
        case G_MORE_ACTION_ID_IMAGE:
        {
            // 进入相册选择图片并发送图片消息
            [super.imagePickerWrapper takeAlbum:YES];
            break;
        }
            // 发送图片消息（从相机）
        case G_MORE_ACTION_ID_PHOTO:
        {
            // 进入相机拍照并发送图片消息
            [super.imagePickerWrapper takePhoto];
            break;
        }
        // 发送大文件（先收起键盘，避免关闭文件选择器后系统自动恢复输入框为第一响应者导致键盘弹出）
        case G_MORE_ACTION_ID_FILE:
        {
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            [super openFilePicker];
            break;
        }
        // 发送短视频消息
        case G_MORE_ACTION_ID_SHORTVIDEO:
        {
            [super openShortVideoRecorder];
            break;
        }
        // 发送位置消息
        case G_MORE_ACTION_ID_LOCATION:
        {
            [super openLocationChoose];
            break;
        }
        // 名片：更多面板收起后再弹 LPActionSheet（与红包一致）
        case G_MORE_ACTION_ID_CONTACT_MERGED:
        {
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            __weak typeof(self) wself = self;
            [self hideBottomBoxAnim:YES completion:^{
                __strong typeof(wself) s = wself;
                if (!s) return;
                [LPActionSheet showActionSheetWithTitle:nil
                                      cancelButtonTitle:@"取消"
                                 destructiveButtonTitle:nil
                                      otherButtonTitles:@[@"个人名片", @"群名片"]
                                    otherButtonImages:nil
                                                handler:^(LPActionSheet *actionSheet, NSInteger index) {
                    __strong typeof(wself) ss = wself;
                    if (!ss) return;
                    if (index == 0) return;
                    if (index == 1) {
                        [ss openUserChoose];
                    } else if (index == 2) {
                        [ss openGroupChoose];
                    }
                }];
            }];
            return;
        }
        // 发送个人名片消息
        case G_MORE_ACTION_ID_CONTACT_FRIEND:
        {
            [self openUserChoose];
            break;
        }
        // 发送群名片消息
        case G_MORE_ACTION_ID_CONTACT_GROUP:
        {
            [super openGroupChoose];
            break;
        }
        // 收藏（先收起键盘，避免关闭收藏选择器后系统自动恢复输入框为第一响应者导致键盘弹出）
        case G_MORE_ACTION_ID_FAVORITES:
        {
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            [self openFavoritesPicker];
            break;
        }
        // 红包：更多面板完全收起后再弹 LPActionSheet（避免与悬浮菜单重叠）
        case G_MORE_ACTION_ID_RED_PACKET:
        {
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            __weak typeof(self) wself = self;
            [self hideBottomBoxAnim:YES completion:^{
                __strong typeof(wself) s = wself;
                if (!s) return;
                [LPActionSheet showActionSheetWithTitle:nil
                                      cancelButtonTitle:@"取消"
                                 destructiveButtonTitle:nil
                                      otherButtonTitles:@[@"拼手气红包", @"普通红包", @"专属红包"]
                                                handler:^(LPActionSheet *actionSheet, NSInteger index) {
                    if (index == 0) return; // 取消
                    int packetType = (index == 1) ? 2 : (index == 2) ? 1 : 3; // 拼手气/普通/专属
                    WalletRedPacketSendViewController *vc = [[WalletRedPacketSendViewController alloc] init];
                    vc.receiverType = 2;
                    vc.groupId = s.toId;
                    vc.initialPacketType = packetType;
                    vc.hidesBottomBarWhenPushed = YES;
                    [s.navigationController pushViewController:vc animated:YES];
                }];
            }];
            return;
        }
        // 转账（群聊中可从群成员列表选择收款人）
        case G_MORE_ACTION_ID_TRANSFER:
        {
            WalletTransferViewController *vc = [[WalletTransferViewController alloc] init];
            vc.groupId = self.toId;
            vc.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        default:
        {
            [BasicTool showAlertInfo:@"未实现的功能，敬请关注！" parent:self];
            break;
        }
    }

    // 并关闭"(+)更多"功能面板
    [self hideBottomBoxAnim:YES];
}


////---------------------------------------------------------------------------------------------------
//#pragma mark - JSQMessagesViewController method overrides
//
///**
// * 消息输入框上触发的软键盘“Send”按钮事件。
// * @text The message text.
// */
//- (void)didPressSendButtonInKeybord:(NSString *)text
//{
//    if(text != nil && [text length] > 0)
//    {
//        [JSQSystemSoundPlayer jsq_playMessageSentSound];
//        
//        // 将数据通过网络发出去
//        [self sendPlainTextMessage:text forSucess:^(id observerble, id arg1) {
//            int code = [arg1 intValue];
//            // 为0表示消息已成功送出！
//            if(code != 0)
//                [APP showToastWarn:[NSString stringWithFormat:@"聊天消息没有成功送出，原因是：code=%d", code]];
//
//            [self finishSendingMessageAnimated:YES];
//        }];
//    }
//    else
//    {
//        [APP showToastInfo:@"请输入要发送的文字！"];
//    }
//}
//
//// 按钮事件：语音留言消息的录制与发送实现方法
//- (void)didPressLeftButton:(UIButton *)sender
//{
//    // 录制语音并发送语音消息的实现方法
//    [self gotoVoiceRecord];
//}


//---------------------------------------------------------------------------------------------------
#pragma mark - Responding to collection view tap events

// 点击消息气泡边上的头像事件处理方法
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapAvatarImageView:(UIImageView *)avatarImageView atIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *entity = [[self getChattingDatasList] objectAtIndex:indexPath.item];
    if(entity != nil)
    {
        // 点击的是本地用户头像 → 查看本地用户的"个人中心"
        if ([entity.senderId isEqualToString:self.senderId])
        {
            [ViewControllerFactory goUserViewController:self.navigationController];
        }
        else
        {
            // 【成员隐私保护】当群开启 g_member_privacy=1 且当前用户是普通成员时，
            // 不允许查看其他成员资料（管理员和群主不受限制）
            GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.toId];
            if (ge != nil && ge.g_member_privacy == 1 && self.myRoleInGroup < 1) {
                [APP showToastWarn:@"该群已开启成员隐私保护"];
                return;
            }

            // 获取该用户的群成员信息（用于传递入群时间和邀请人等）
            GroupMemberEntity *memberInfo = [self.cachedMembersDict objectForKey:entity.senderId];

            // 【管理员/群主】显示成员入群信息后可查看资料
            if (self.myRoleInGroup >= 1) {
                [self showMemberInfoSheet:entity.senderId];
            } else {
                // 普通成员直接查看用户资料（带群成员信息）
                [QueryFriendInfoAsync gotoWatchUserInfo:entity.senderId withInfo:nil nav:self.navigationController view:self.view vc:self addSource:@"group" groupMemberInfo:memberInfo];
            }
        }
    }
}

/**
 * 管理员/群主点击群成员头像时，弹出ActionSheet显示入群来源信息。
 */
- (void)showMemberInfoSheet:(NSString *)targetUid
{
    GroupMemberEntity *member = [self.cachedMembersDict objectForKey:targetUid];

    // 构建成员信息描述
    NSMutableString *infoText = [NSMutableString string];

    // 成员昵称
    NSString *displayName = nil;
    if (member != nil) {
        displayName = [GroupsProvider getNickNameInGroup:member.nickname and:member.nickname_ingroup];
    }
    if ([BasicTool isStringEmpty:displayName]) {
        displayName = targetUid;
    }

    // 角色
    if (member != nil) {
        NSString *roleName = @"普通成员";
        if (member.role == 2) roleName = @"群主";
        else if (member.role == 1) roleName = @"管理员";
        [infoText appendFormat:@"角色：%@\n", roleName];
    }

    // 入群时间
    if (member != nil && ![BasicTool isStringEmpty:member.join_time]) {
        [infoText appendFormat:@"入群时间：%@\n", member.join_time];
    }

    // 入群来源（邀请人）
    if (member != nil && ![BasicTool isStringEmpty:member.invite_by_uid]) {
        NSString *inviterName = member.invite_by_nickname ?: member.invite_by_uid;
        [infoText appendFormat:@"入群来源：由 %@ 邀请\n", inviterName];
    } else if (member != nil && [BasicTool isStringEmpty:member.invite_by_uid]) {
        // 没有邀请人信息 → 可能是创建群时的成员或主动加入
        if (member.role == 2) {
            [infoText appendString:@"入群来源：群创建者\n"];
        }
    }

    // 如果缓存中没有该成员（如已退群但有历史消息）
    if (member == nil) {
        [infoText appendString:@"该用户可能已不在群中\n"];
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
    [alert addAction:[UIAlertAction actionWithTitle:@"查看详细资料" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        // 带群成员信息跳转（显示入群时间和邀请人）
        [QueryFriendInfoAsync gotoWatchUserInfo:targetUid withInfo:nil nav:safeSelf.navigationController view:safeSelf.view vc:safeSelf addSource:@"group" groupMemberInfo:member];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

/**
 * 处理头像长按手势：弹出选择框 @对方、发送专属红包，管理员还有禁言、踢出群聊
 */
- (void)handleAvatarLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }
    if ([self isWorldChat]) {
        return;
    }
    
    UIImageView *avatarView = (UIImageView *)gestureRecognizer.view;
    NSInteger itemIndex = avatarView.tag;
    NSArray<JSQMessage *> *messagesList = [self getChattingDatasList];
    if (itemIndex < 0 || itemIndex >= messagesList.count) return;
    
    JSQMessage *entity = [messagesList objectAtIndex:itemIndex];
    if (entity == nil) return;
    if ([entity.senderId isEqualToString:self.senderId]) return;
    
    NSString *targetUid = entity.senderId;
    NSString *displayName = [self getDisplayNameForUser:targetUid inMessage:entity];
    BOOL isAdminOrOwner = (self.myRoleInGroup >= 1);
    
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:displayName message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) wself = self;
    
    [sheet addAction:[UIAlertAction actionWithTitle:@"@对方" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        TargetEntity *targetEntity = [[TargetEntity alloc] init];
        targetEntity.targetId = targetUid;
        targetEntity.targetName = displayName;
        NSMutableString *prefix = [[NSMutableString alloc] initWithString:@"@"];
        UITextView *composer = [wself rb_currentComposerTextView];
        [wself.atCache addAtUser:targetEntity prefix:prefix target:composer];
        if (![composer isFirstResponder]) {
            [composer becomeFirstResponder];
        }
    }]];
    
    [sheet addAction:[UIAlertAction actionWithTitle:@"发送专属红包" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        WalletRedPacketSendViewController *vc = [[WalletRedPacketSendViewController alloc] init];
        vc.receiverType = 2;
        vc.groupId = wself.toId;
        vc.initialPacketType = 3;
        vc.initialExclusiveReceiverUid = targetUid;
        vc.initialExclusiveReceiverDisplayName = displayName;
        vc.hidesBottomBarWhenPushed = YES;
        [wself.navigationController pushViewController:vc animated:YES];
    }]];
    
    if (isAdminOrOwner) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"禁言" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [wself showMuteDurationSheetForTargetUid:targetUid displayName:displayName];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"踢出群聊" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [wself confirmKickMemberUid:targetUid displayName:displayName];
        }]];
    }
    
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:sheet animated:YES completion:nil];
}

/** 禁言时长选择（10分钟/1小时/1天/永久），然后提交禁言 */
- (void)showMuteDurationSheetForTargetUid:(NSString *)targetUid displayName:(NSString *)displayName
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"禁言 %@", displayName] message:@"选择禁言时长" preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) wself = self;
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!myUid.length) return;
    
    void (^muteWithMs)(long long) = ^(long long muteUntil2) {
        [[HttpRestHelper sharedInstance] submitMuteGroupMemberToServer:myUid targetUid:targetUid gid:wself.toId muteUntil2:muteUntil2 complete:^(BOOL sucess, NSString *resultCode) {
            if (sucess) {
                [APP showUserDefineToast_OK:@"禁言已设置" atHide:nil];
                [wself checkAndApplyMuteStatus];
            } else {
                [BasicTool showAlertInfo:@"禁言失败，请稍后重试" parent:wself];
            }
        } hudParentView:wself.view];
    };
    
    [sheet addAction:[UIAlertAction actionWithTitle:@"10分钟" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        long long endMs = (long long)([[NSDate date] timeIntervalSince1970] * 1000) + 10 * 60 * 1000;
        muteWithMs(endMs);
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"1小时" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        long long endMs = (long long)([[NSDate date] timeIntervalSince1970] * 1000) + 60 * 60 * 1000;
        muteWithMs(endMs);
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"1天" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        long long endMs = (long long)([[NSDate date] timeIntervalSince1970] * 1000) + 24 * 60 * 60 * 1000;
        muteWithMs(endMs);
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"永久" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        muteWithMs(0);
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

/** 确认后踢出群成员 */
- (void)confirmKickMemberUid:(NSString *)targetUid displayName:(NSString *)displayName
{
    NSString *msg = [NSString stringWithFormat:@"确定将「%@」踢出群聊？", displayName];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"踢出群聊" message:msg preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) wself = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        NSString *myNick = [IMClientManager sharedInstance].localUserInfo.nickname ?: @"";
        if (!myUid.length) return;
        NSArray<NSArray *> *membersBeDelete = @[ @[ wself.toId, targetUid, displayName ?: targetUid ] ];
        [[HttpRestHelper sharedInstance] submitDeleteOrQuitGroupToServer:myUid del_opr_nickname:myNick gid:wself.toId membersBeDelete:membersBeDelete complete:^(BOOL sucess, NSString *resultCode) {
            if (sucess && [@"1" isEqualToString:resultCode]) {
                GroupMemberEntity *removed = [[GroupMemberEntity alloc] init];
                removed.user_uid = targetUid;
                removed.nickname = displayName;
                GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:wself.toId];
                if (ge) {
                    [GChatDataHelper addSystenInfo_removeMembersSucessForLocalUser:@[ removed ] gid:wself.toId gname:ge.g_name];
                }
                [GroupMemberViewController updateCurrentGroupMemberGroupAfterSubmit:wself.toId deltaCount:-1];
                [NotificationCenterFactory resetGroupAvatarCache_POST:wself.toId];
                [APP showUserDefineToast_OK:@"已踢出群聊" atHide:nil];
            } else {
                [BasicTool showAlertInfo:@"操作失败，请稍后重试" parent:wself];
            }
        } hudParentView:wself.view];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

/**
 * 获取用户在群聊中的显示名称
 * 优先级：群内昵称 > 好友备注 > senderId
 */
- (NSString *)getDisplayNameForUser:(NSString *)userId inMessage:(JSQMessage *)message
{
    if ([BasicTool isStringEmpty:userId]) {
        return @"";
    }

    NSString *messageFallback = message.senderDisplayName;
    NSString *displayName = [self rb_groupDisplayNameForUser:userId fallback:messageFallback];
    if (![BasicTool isStringEmpty:displayName]) {
        return displayName;
    }

    // 其次从好友列表获取好友备注
    UserEntity *friendInfo = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:userId];
    if (friendInfo != nil) {
        NSString *friendNickname = [friendInfo getNickNameWithRemark];
        if (![BasicTool isStringEmpty:friendNickname]) {
            return friendNickname;
        }
    }

    // 最后使用 senderId 作为默认值
    return userId;
}


//---------------------------------------------------------------------------------------------------
#pragma mark - Collection view data source（消息列表数据源代理方法）

// @Override - 重写父类方法：单独的方法里处理头像显示逻辑，方便群聊子类界面中以更大的自由度实现自已的显示逻辑 - 20180528 by JackJiang
// 特别说明：本方法的重写代码，陌生人、群聊、好友聊 3个子聊天界面的实现中，均保持一致，视未来的扩展，如果一直趋同，可考虑提炼到父类中重用之，尽可能减少代码冗余
- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath_avatar:(NSIndexPath *)indexPath withImageView:(UIImageView *)avatarView
{
    avatarView.layer.cornerRadius = kJSQMessagesCollectionViewAvatarSizeDefault * 0.5f;
    avatarView.layer.masksToBounds = YES;

    JSQMessage *entity = [[self getChattingDatasList] objectAtIndex:indexPath.item];

    // 消息对话中动态头像只显示静态首帧，不播放视频
    UIImage *placeImg = [UIImage imageNamed:@"chat_avatar_default"];
    BOOL isOutgoing = [entity.senderId isEqualToString:self.senderId];
    if (isOutgoing) {
        UserEntity *curUser = [IMClientManager sharedInstance].localUserInfo;
        [RBAvatarView setAvatarWithFileName:curUser.userAvatarFileName uid:curUser.user_uid onImageView:avatarView placeholder:placeImg staticPreviewOnly:YES];
    } else {
        NSString *avatarFileName = nil;
        UserEntity *friendInfo = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:entity.senderId];
        if (friendInfo != nil) {
            avatarFileName = friendInfo.userAvatarFileName;
        } else {
            avatarFileName = [[[IMClientManager sharedInstance] getAlarmsProvider] getExtra1String:AMT_guestChatMessage dataId:entity.senderId];
        }
        [RBAvatarView setAvatarWithFileName:avatarFileName uid:entity.senderId onImageView:avatarView placeholder:placeImg staticPreviewOnly:YES];

        // 为非自己的头像添加长按手势，用于@功能（仅群聊，非世界频道）
        if (![self isWorldChat]) {
            // 移除可能存在的旧手势
            NSArray *gestures = [avatarView.gestureRecognizers copy];
            for (UIGestureRecognizer *gesture in gestures) {
                if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]]) {
                    [avatarView removeGestureRecognizer:gesture];
                }
            }
            
            // 添加长按手势识别器
            UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleAvatarLongPress:)];
            longPressGesture.minimumPressDuration = 0.5; // 0.5秒长按
            longPressGesture.numberOfTouchesRequired = 1;
            // 将 indexPath 的 item 索引存储到 view 的 tag 中，以便在长按事件中获取
            avatarView.tag = indexPath.item;
            avatarView.userInteractionEnabled = YES;
            [avatarView addGestureRecognizer:longPressGesture];
        }
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - Responding to collection view tap events（聊天列表的其它相关代理方法）

// @Override - 重写父类方法：实现群聊关于消息撤回功能权限的特殊逻辑
// 方法用途：该消息是否可被撤回（子类可重写本方法实现自已的“撤回”功能权限可用逻辑）
-(BOOL)messageCanBeRevoke:(JSQMessage *)d
{
    if(d != nil){
        // 除系统消息、已被撤回的消息
        if(d.msgType != TM_TYPE_SYSTEAM_INFO && d.msgType != TM_TYPE_REVOKE ){
            if (d.msgType == TM_TYPE_RED_PACKET || d.msgType == TM_TYPE_TRANSFER || d.msgType == TM_TYPE_VOIP_RECORD) {
                return NO;
            }
            if(d.fingerPrintOfProtocal != nil){
                // 时间与单聊一致：超过 CHATTING_MESSAGE_CAN_BE_REVOKE_TIME 分钟均不可撤回
                if (![ChatRootViewController messageIsNotTimeoutForRevoke:d]) {
                    return NO;
                }
                BOOL isGroupOwner = [GroupsProvider isThisGroupOwner:self.toId];
                // 群主/管理员可撤回群内任意成员消息（仍须在时限内）；普通成员仅能撤回自己发出的
                if(isGroupOwner)
                    return YES;
                return [d isOutgoing];
            }
        }
    }
    
    return NO;
}

- (NSString *) getImageMessageDownloadURL:(NSString *)fileName
{
    return [SendImageHelper getImageDownloadURL:fileName dump:NO]; // 注意：dump参数设为NO，表本示本图片消息读取后将不需要从服务端的unread文件夹转储
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 其它方法

// 切换静音开关按钮的背景图片显示（仅用于世界频道时）
- (void)refreshMsgToneImage
{
    BOOL open = [UserDefaultsToolKits isChatMsgToneOpen:self.toId];
    
    if(self.btnSilentSetup) {
        UIButton *btnSilentSetup = self.btnSilentSetup;//(UIButton *)self.navigationItem.rightBarButtonItem.customView;
        [btnSilentSetup setBackgroundImage:(open?[UIImage imageNamed:@"multi_chatting_list_view_silence_off"]:[UIImage imageNamed:@"multi_chatting_list_view_silence_on"]) forState:UIControlStateNormal];
    }
    else if(self.btnSilentSetup_ios26) {
        [self.btnSilentSetup_ios26 setImage: (open?[UIImage imageNamed:@"multi_chatting_list_view_silence_off_ios26"]:[UIImage imageNamed:@"multi_chatting_list_view_silence_on_ios26"])];
    }
}

/** 是否是世界频道 */
- (BOOL) isWorldChat
{
    return [GroupEntity isWorldChat:self.toId];
}

/** 刷新界面标题的显示 */
- (void) updateTitle:(NSString *)gname
{
    self.toName = gname;
    self.title = self.toName;
    self.navigationItem.title = @"";
}

// 退群(作为普通群员时)或解散群(作为群主时)时，通知本群聊界面，以便群聊界面在收到通知后能自动关闭（因为已不在此群或群已不存在了嘛）
- (void) quitOrDismissGroupComplete:(NSNotification*)notification
{
//    NSString *hintContent = (NSString *)notification.object;
    DDLogDebug(@"【群聊天界面】-收到退出群或解散群的通知！");

//    [BasicTool showUserDefintToast:hintContent
//                              view:self.view
//                            // Toast消失时的回调
//                            atHide:^(void){
                                // 并在Toast消失时退出添加好友界面
                                [self doBack:NO];
//                            }];
}

// 收到群主修改群名称后，通知本群聊界面，以便群聊界面即时刷新最新标题显示
- (void) groupNameChanged:(NSNotification*)notification
{
    NSDictionary *map = (NSDictionary *)notification.object;
    if(map == nil){
        [BasicTool showAlertError:@"无效数据 map=nil ！" parent:self];
        return;
    }
    
    NSString *gid = [map objectForKey:@"gid"];
    NSString *newGroupName = [map objectForKey:@"newGroupName"];
    DDLogDebug(@"【群名称被修改】收到 (gid=%@，newGroupName=%@) 已被修改的广播通知！", gid, newGroupName);
    
    if(gid != nil && [gid isEqualToString:self.toId]) {
        // 更新聊天界面上的标题栏
        [self updateTitle:newGroupName];
        DDLogDebug(@"【好友备注更新】当前聊天界面标题更新成功！");
    }
}

// 从当前界面回退
- (void)doBack:(BOOL)animated
{
    [self.navigationController popViewControllerAnimated:animated];
}

//---------------------------------------------------------------------------------------------------
#pragma mark - 禁言状态检查与UI控制

/**
 * 初始化禁言提示遮罩视图（覆盖在输入框工具栏上方）
 */
- (void)initMuteOverlay
{
    if (self.muteOverlayView != nil) {
        return;
    }
    if (self.inputToolbar == nil) {
        return;
    }

    // 获取输入框工具栏的高度
    CGFloat toolbarHeight = self.inputToolbar.preferredDefaultHeight_noQuote;
    if (toolbarHeight <= 0) toolbarHeight = 50;

    // 创建遮罩视图（初始隐藏，与输入框工具栏大小一致）
    self.muteOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
    self.muteOverlayView.backgroundColor = HexColor(0xF5F5F5);
    self.muteOverlayView.hidden = YES;

    // 禁言提示文本
    self.muteOverlayLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.muteOverlayLabel.text = @"当前处于禁言状态";
    self.muteOverlayLabel.textColor = HexColor(0x999999);
    self.muteOverlayLabel.font = [UIFont systemFontOfSize:14];
    self.muteOverlayLabel.textAlignment = NSTextAlignmentCenter;
    [self.muteOverlayView addSubview:self.muteOverlayLabel];

    // 顶部分隔线
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectZero];
    topLine.backgroundColor = HexColor(0xDDDDDD);
    topLine.tag = 9999;
    [self.muteOverlayView addSubview:topLine];

    // 将遮罩覆盖在输入框工具栏上
    [self.inputToolbar addSubview:self.muteOverlayView];

    // 使用 Auto Layout
    self.muteOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.muteOverlayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    topLine.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.muteOverlayView.leadingAnchor constraintEqualToAnchor:self.inputToolbar.leadingAnchor],
        [self.muteOverlayView.trailingAnchor constraintEqualToAnchor:self.inputToolbar.trailingAnchor],
        [self.muteOverlayView.topAnchor constraintEqualToAnchor:self.inputToolbar.topAnchor],
        [self.muteOverlayView.bottomAnchor constraintEqualToAnchor:self.inputToolbar.bottomAnchor],

        [self.muteOverlayLabel.centerXAnchor constraintEqualToAnchor:self.muteOverlayView.centerXAnchor],
        [self.muteOverlayLabel.centerYAnchor constraintEqualToAnchor:self.muteOverlayView.centerYAnchor],

        [topLine.leadingAnchor constraintEqualToAnchor:self.muteOverlayView.leadingAnchor],
        [topLine.trailingAnchor constraintEqualToAnchor:self.muteOverlayView.trailingAnchor],
        [topLine.topAnchor constraintEqualToAnchor:self.muteOverlayView.topAnchor],
        [topLine.heightAnchor constraintEqualToConstant:0.5],
    ]];
}

/**
 * 检查当前用户在群中的禁言状态，并相应地启用/禁用输入框。
 * 检查逻辑：
 *  1. 全群禁言 g_mute_mode=1 且角色<1（普通成员）→ 禁言
 *  2. 全群禁言 g_mute_mode=2 且角色<2（非群主）→ 禁言
 *  3. 单人禁言（在禁言列表中且未过期）→ 禁言
 */
- (void)checkAndApplyMuteStatus
{
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (myUid == nil) return;    __weak typeof(self) safeSelf = self;
    [[HttpRestHelper sharedInstance] submitGetGroupInfoToServer:self.toId myUserId:myUid complete:^(BOOL sucess0, GroupEntity *groupInfo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(safeSelf) strongSelf = safeSelf;
            if (!strongSelf) return;
            GroupEntity *effectiveGroupInfo = groupInfo;
            if (sucess0 && groupInfo != nil) {
                [[[IMClientManager sharedInstance] getGroupsProvider] updateGroup:groupInfo];
                GroupEntity *latest = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:strongSelf.toId];
                if (latest != nil) {
                    effectiveGroupInfo = latest;
                }
            } else {
                effectiveGroupInfo = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:strongSelf.toId];
            }

            if (effectiveGroupInfo == nil) {                [strongSelf applyMuteUI:YES reason:@"该群已不可发消息"];
                return;
            }
            if (![effectiveGroupInfo myselfIsInGroup]) {                [strongSelf applyMuteUI:YES reason:@"你已不在该群，无法发送消息"];
                return;
            }
            if (effectiveGroupInfo.g_status.length > 0 && ![effectiveGroupInfo.g_status isEqualToString:@"1"]) {                [strongSelf applyMuteUI:YES reason:@"该群已解散，无法发送消息"];
                return;
            }

            // 第二步：查询群成员列表获取当前用户角色
            [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:strongSelf.toId requestUid:myUid complete:^(BOOL sucess, NSMutableArray<GroupMemberEntity *> *membersList) {
                if (!sucess || membersList == nil) {                    return;
                }

                // 先在回调线程整理好数据；写 VC 属性与 UI 一律回主线程（回调线程可能是全局队列，否则易与 view 生命周期打架闪退）
                int myRole = 0;
                NSMutableDictionary<NSString *, GroupMemberEntity *> *membersCache = [NSMutableDictionary dictionary];
                for (GroupMemberEntity *m in membersList) {
                    if (m.user_uid != nil) {
                        [membersCache setObject:m forKey:m.user_uid];
                    }
                    if ([m.user_uid isEqualToString:myUid]) {
                        myRole = m.role;
                    }
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(safeSelf) innerStrongSelf = safeSelf;
                    if (!innerStrongSelf) return;
                    innerStrongSelf.myRoleInGroup = myRole;
                    innerStrongSelf.cachedMembersDict = membersCache;
                    BOOL changedAfterMembersLoaded = [innerStrongSelf rb_applyGroupMemberNicknamesToMessages];                    if (changedAfterMembersLoaded) {                    }

                    void (^applyMuteStateWithMode)(int) = ^(int muteMode) {
                        NSString *muteReason = nil;
                        if (muteMode == 1 && myRole < 1) {
                            muteReason = @"全员禁言中，仅管理员和群主可发言";
                        } else if (muteMode == 2 && myRole < 2) {
                            muteReason = @"全员禁言中，仅群主可发言";
                        }

                        if (muteReason != nil) {
                            [innerStrongSelf applyMuteUI:YES reason:muteReason];
                            return;
                        }

                        [[HttpRestHelper sharedInstance] submitQueryMutedMembersFromServer:innerStrongSelf.toId complete:^(BOOL sucess2, NSArray<NSDictionary *> *mutedList) {
                            NSString *individualMuteReason = nil;

                            if (sucess2 && mutedList != nil) {
                                for (NSDictionary *muted in mutedList) {
                                    NSString *mutedUid = [muted objectForKey:@"user_uid"];
                                    if ([mutedUid isEqualToString:myUid]) {
                                        NSString *muteUntil2Str = [muted objectForKey:@"mute_until2"];
                                        long long muteUntil2 = [muteUntil2Str longLongValue];
                                        if (muteUntil2 == 0 || muteUntil2 > (long long)([[NSDate date] timeIntervalSince1970] * 1000)) {
                                            individualMuteReason = @"你已被禁言";
                                        }
                                        break;
                                    }
                                }
                            }
                            dispatch_async(dispatch_get_main_queue(), ^{
                                __strong typeof(safeSelf) ss = safeSelf;
                                if (!ss) return;
                                if (individualMuteReason != nil) {
                                    [ss applyMuteUI:YES reason:individualMuteReason];
                                } else {
                                    [ss applyMuteUI:NO reason:nil];
                                }
                            });
                        } hudParentView:nil];
                    };

                    int localMuteMode = effectiveGroupInfo.g_mute_mode;
                    [[HttpRestHelper sharedInstance] submitQueryGroupSettingsFromServer:innerStrongSelf.toId complete:^(BOOL sucess3, NSDictionary *settings) {
                        int resolvedMuteMode = localMuteMode;
                        if (sucess3 && [settings isKindOfClass:[NSDictionary class]]) {
                            id muteModeObj = [settings objectForKey:@"g_mute_mode"];
                            if (muteModeObj != nil && ![muteModeObj isKindOfClass:[NSNull class]]) {
                                resolvedMuteMode = [muteModeObj intValue];
                            }
                            dispatch_async(dispatch_get_main_queue(), ^{
                                GroupEntity *latestGroup = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:innerStrongSelf.toId];
                                if (latestGroup != nil) {
                                    latestGroup.g_mute_mode = resolvedMuteMode;
                                }
                            });
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong typeof(safeSelf) ss = safeSelf;
                            if (!ss) return;
                            applyMuteStateWithMode(resolvedMuteMode);
                        });
                    } hudParentView:nil];
                });
            } hudParentView:nil];
        });
    } hudParentView:nil];
}

/**
 * 应用禁言/解除禁言的UI状态
 * @param muted YES=禁言状态，NO=正常状态
 * @param reason 禁言原因提示文本
 */
- (void)applyMuteUI:(BOOL)muted reason:(NSString *)reason
{
    if (self.inputToolbar == nil || self.inputToolbar.contentView == nil) {
        return;
    }
    if (self.muteOverlayView == nil || self.muteOverlayLabel == nil) {
        [self initMuteOverlay];
    }
    if (self.muteOverlayView == nil || self.muteOverlayLabel == nil) {
        return;
    }
    self.isMuted = muted;
    if (muted) {
        // 显示禁言遮罩
        self.muteOverlayLabel.text = reason ?: @"当前处于禁言状态";
        self.muteOverlayView.hidden = NO;

        // 禁用输入框
        self.inputToolbar.contentView.textView.editable = NO;
        self.inputToolbar.contentView.textView.text = @"";
        self.inputToolbar.contentView.leftBarButtonItem.enabled = NO;
        self.inputToolbar.contentView.leftBarButton2Item.enabled = NO;
        self.inputToolbar.contentView.rightBarButtonItem.enabled = NO;

        // 收起键盘
        [self.inputToolbar.contentView.textView resignFirstResponder];
    } else {
        // 隐藏禁言遮罩
        self.muteOverlayView.hidden = YES;

        // 启用输入框
        self.inputToolbar.contentView.textView.editable = YES;
        self.inputToolbar.contentView.leftBarButtonItem.enabled = YES;
        self.inputToolbar.contentView.leftBarButton2Item.enabled = YES;
        self.inputToolbar.contentView.rightBarButtonItem.enabled = YES;
    }
}


// 以下代码用于往聊天界面上显示并组织消息列表上部的信息提示UI（用于高于iOS 26的系统中）
+ (void)attachTopExtraView_ios26:(JSQMessagesViewController *)parent hintText:(NSString *)hint
{
    parent.navigationItem.subtitle = hint;
}

// 以下代码用于往聊天界面上显示并组织消息列表上部的信息提示UI（用于低于iOS 26的系统中）
+ (void)attachTopExtraView:(JSQMessagesViewController *)parent hintText:(NSString *)hint view1:(UIView *)view1
{
    // 显示顶部的bbs提示信息父组件
    parent.topExtraContainerHeightConstraint.constant = 34;

    // 总体组件与整个窗体左右的空白
    CGFloat leftAndRightPadding = 15;//8;
    // 组件间的间隙
    CGFloat gap = 5;

    // 信息提示组件图标
    UIImageView *infoIconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    infoIconView.image = [UIImage imageNamed:@"common_info_blue_icon"];//@"widget_unduplitoast_icon"];
    // 图标的相对显示位置
    [parent.topExtraContainer addSubview:infoIconView];
    [infoIconView mas_makeConstraints:^(MASConstraintMaker *make) {
        // 垂直居中于父组件
        make.centerY.equalTo(parent.topExtraContainer);
        // 左边相对于父组件+8（即向右移8像素）的位置处
        make.left.equalTo(parent.view).with.offset(leftAndRightPadding);
        // 本组件的真正大小
        make.size.mas_equalTo(CGSizeMake(15, 15));//(18, 18));
    }];

    // 信息提示文本组件
    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    infoLabel.text = hint;
    CGFloat adjustedSize = [BasicTool getAdjustedFontSize:12.0f];
    infoLabel.font = [UIFont systemFontOfSize:adjustedSize weight:UIFontWeightMedium];
    infoLabel.textColor = HexColor(0xffbf00);//HexColor(0x5C6B8A);//0x555555);
    // 文本组件的相对显示位置
    [parent.topExtraContainer addSubview:infoLabel];
    [infoLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        // 垂直居中于父组件
        make.centerY.equalTo(parent.topExtraContainer);
        // 左边接着前一个组件的右边+gap间隙的位置处
        make.left.equalTo(infoIconView.mas_right).with.offset(gap);
//      make.right.equalTo(parent.topExtraContainer).with.offset(-padding);
    }];

    // 调用者传入的组件（接着前面的组件相对位置显示）
    if(view1 != nil)
    {
        [parent.topExtraContainer addSubview:view1];
        [view1 mas_makeConstraints:^(MASConstraintMaker *make) {
            // 垂直居中于父组件
            make.centerY.equalTo(parent.topExtraContainer);
            // 左边相对于父组件+8（即向右移8像素）的位置处
            make.left.equalTo(infoLabel.mas_right).with.offset(gap);
            // 本组件的真正大小
            make.size.mas_equalTo(view1.frame.size);
        }];
    }
}

@end
