//telegram @wz662
#import "TempChatViewController.h"
#import "NSMutableArrayObservableEx.h"
#import "IMClientManager.h"
#import "Default.h"
#import "NotificationCenterFactory.h"
#import "AppDelegate.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "UserEntity.h"
#import "ViewControllerFactory.h"
#import "QueryFriendInfoAsync.h"
#import "BasicTool.h"
#import "SendImageHelper.h"
#import "TChatDataHelper.h"
#import "TMessageHelper.h"
#import "SendVoiceHelper.h"
#import "GroupChattingViewController.h"
#import "LPActionSheet.h"
#import "SendFileHelper.h"
#import "BigFileUploadManager.h"
#import "SendShortVideoHelper.h"
#import "AlarmType.h"
#import "LocationUtils.h"
#import "CallManager.h"
#import "ChatMessageModeMenu.h"
#import "WalletTransferViewController.h"
#import "WalletRedPacketSendViewController.h"
#import "MessagesProvider.h"

// 发送图片消息（从图片）
const int T_MORE_ACTION_ID_IMAGE          = 1;
// 发送图片消息（从相机）
const int T_MORE_ACTION_ID_PHOTO          = 2;
// 发送大文件
const int T_MORE_ACTION_ID_FILE           = 3;
// 发送短视频
const int T_MORE_ACTION_ID_SHORTVIDEO     = 4;
// 发送位置
const int T_MORE_ACTION_ID_LOCATION       = 5;
// 发送个人名片
const int T_MORE_ACTION_ID_CONTACT_FRIEND = 6;
// 发送群名片
const int T_MORE_ACTION_ID_CONTACT_GROUP  = 7;
// 收藏
const int T_MORE_ACTION_ID_FAVORITES      = 8;
// 名片（底部弹窗选择个人名片或群名片）
const int T_MORE_ACTION_ID_CONTACT_MERGED = 9;
// 语音/视频通话（点击后弹出选择语音通话或视频通话）
const int T_MORE_ACTION_ID_VOICE_VIDEO_CHAT = 10;
// 红包
const int T_MORE_ACTION_ID_RED_PACKET     = 11;
// 转账
const int T_MORE_ACTION_ID_TRANSFER       = 12;


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface TempChatViewController ()

// 暂存从Intent中传过来的陌生人信息数据（将要用于界面展现）
@property (nonatomic, assign) int tempChatMaxFriendForInit;

// 聊天列表的消息数据集合
@property (nonatomic, retain) NSMutableArrayObservableEx *chattingDatas;

// “我”的消息头像
@property (strong, nonatomic) UIImage *outgoingAvatarImage;
// 对方的消息头像
@property (strong, nonatomic) UIImage *incomingAvatarImage;
/// 右滑取消时避免导航栏动画导致闪烁
@property (nonatomic, assign) BOOL oac_hadWillDisappearWithoutDid;
/// 被子页覆盖时移除了聊天列表 observer，返回后需至少补一次强制刷新
@property (nonatomic, assign) BOOL rb_needForceRefreshAfterCoveredDisappear;

//// 聊天消息数据模型变动观察者实现block
//@property (nonatomic, copy) ObserverCompletion chattingDatasObserver;

//// 设置{@link BigFileUploadManager}中大文件任务状态改变观察者block(主要用于“我”发送的大文件消息)，
//// 用于UI及时刷新文件上传状态在界面上的显示（本观察者通常由对应的UI界面设置，界面退到后台消失时取消设置）
//@property (nonatomic, copy) ObserverCompletion fileStatusChangedObserver;

@end


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation TempChatViewController

//---------------------------------------------------------------------------------------------------
#pragma mark - UIViewController相关方法重写

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil guestUid:(NSString *)uid guestName:(NSString *)name maxFriend:(int)maxFriend
{
    if(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        super.chatType = CHAT_TYPE_GUEST_CHAT;
        // 初始化时传过来的陌生人UID
        self.toId = uid;
        // 初始化时传过来的陌生人昵称
        self.toName = name;
        self.tempChatMaxFriendForInit = maxFriend;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    if ([flowLayout respondsToSelector:@selector(setIncomingAvatarViewSize:)]) {
        [(id)flowLayout setIncomingAvatarViewSize:CGSizeZero];
    }
    if ([flowLayout respondsToSelector:@selector(setOutgoingAvatarViewSize:)]) {
        [(id)flowLayout setOutgoingAvatarViewSize:CGSizeZero];
    }

    // 界面ui初始化
    [self initGUI];

    // 初始化数据模型观察者
    [self initObservers];

    [NotificationCenterFactory blockUserComplete_ADD:self selector:@selector(blockUserComplete:)];

    [self initToGuest];
    [self rb_deferredSetupAfterFirstFrame];
    [self initAvatarImage];
}

// 根据UIViewController的生命周期，本方法将在每次本界面每次回到前台时被调用（生命周期中，本方法可能会被反复调用）
- (void)viewWillAppear:(BOOL)animated
{
    BOOL isReappearAfterCancelledPop = self.oac_hadWillDisappearWithoutDid;
    if (isReappearAfterCancelledPop) self.oac_hadWillDisappearWithoutDid = NO;
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
    [super viewWillAppear:animated];

    // 设置当前正处于激话状态下的聊天陌生人id
    [IMClientManager sharedInstance].currentFrontTempChattingUserUID = self.toId;

    if (self.chattingDatas && self.chattingDatasObserver) {
        [self.chattingDatas removeObserver:self.chattingDatasObserver];
        [self.chattingDatas addObserver:self.chattingDatasObserver];
    }
    
    // 设置大文件上传状态变更观察者(主要用于“我”发送的大文件消息)
    [[BigFileUploadManager sharedInstance] setFileStatusChangedObserver:self.fileStatusChangedObserver];

    if (self.rb_initialSessionUnreadCount <= 0) {
        AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
        int idx = ap ? [ap getAlarmIndex:AMT_guestChatMessage dataId:self.toId] : -1;
        if (idx >= 0) {
            self.rb_initialSessionUnreadCount = [ap getFlagNum:idx];
        }
    }

    // APP中唯一重置未读正式聊天消息的代码：最后确保重置APP首页“消息”未读消息数字的显示
    [[[IMClientManager sharedInstance] getAlarmsProvider] resetFlagNum:AMT_guestChatMessage dataId:self.toId flagNumToReset:0 needUpdateSqlite:YES];
//    [[[IMClientManager sharedInstance] getAlarmsProvider] resetChatMessageFlagNum:self.friendForInit.user_uid];
    // 发出通知：强制首页的“消息”Tab上的总未读数
    // * 此时通知刷新首页的“消息”Tab上的总未读数（首页“消息”页面其实已经增加了观察者到“消息”通知数据模型里，但数据模型只能通知道
    // * 到关于数据的新增、删除、替换，而像重置对象里的未读数这样的行为（如进入聊天界面时）是没有办法细化到此粒度的，所以此时在进入
    // * 聊天界面中重置该好友的未读数时，尝试手动发出此通知，使得首页“消息”Tab上的未读数气泡能及时刷新为最新，不然tab上的未读数就不同步了）
    [NotificationCenterFactory refreshMainPageTotalUnread_POST];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (![self.toId isEqualToString:@"10001"]) {
        [self loadPeerAvatarForNav];
    }

    NSInteger listCount = (NSInteger)[self getChattingDatasList].count;
    NSInteger cvCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
    BOOL shouldForceRefresh = self.rb_needForceRefreshAfterCoveredDisappear;
    if (self.collectionView.window && (shouldForceRefresh || listCount != cvCount)) {
        CGFloat bottomTol = 22.0f;
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
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    BOOL leavingStack = self.isMovingFromParentViewController || self.isBeingDismissed;
    if (leavingStack) {
        self.oac_hadWillDisappearWithoutDid = YES;
    }
    UINavigationController *nav = self.navigationController;
    if (!nav) return;
    if (!leavingStack) {
        [nav setNavigationBarHidden:NO animated:animated];
    }
}

// 根据UIViewController的生命周期，本方法将在每次本界面退至后台或者覆盖时被调用（生命周期中，本方法可能会被反复调用）
- (void)viewDidDisappear:(BOOL)animated
{
    self.oac_hadWillDisappearWithoutDid = NO;
    // 取消设置当前正处于激话状态下的聊天陌生人uid
    [IMClientManager sharedInstance].currentFrontTempChattingUserUID = nil;
    
    // 取消设置大文件上传状态变更观察者(主要用于“我”发送的大文件消息)
    [[BigFileUploadManager sharedInstance] setFileStatusChangedObserver:nil];

    if (self.chattingDatas && self.chattingDatasObserver) {
        [self.chattingDatas removeObserver:self.chattingDatasObserver];
        self.rb_needForceRefreshAfterCoveredDisappear = YES;
    }

    if ((self.isMovingFromParentViewController || self.isBeingDismissed) && self.navigationController.navigationBarHidden) {
        UIViewController *top = self.navigationController.topViewController;
        if (top) {
            [self.navigationController setNavigationBarHidden:NO animated:NO];
        }
    }

//    // 逆初始化：释放资源
//    [self deInitToGuest];

    [super viewDidDisappear:animated];
}

//// “viewDidUnload:”方法已在ios6后被废弃（且它只在系统内存低时才被调用），资源释放等工作正确的方式是放到 “dealloc:"中处理
//- (void)dealloc
////- (void)viewDidUnload
//{
//    DDLogDebug(@"!!! dealloc有被调用吗？");
////    // 逆初始化：释放资源
////    [self deInitToGuest];
////    
////    // 取消注册通知：拉黑完成通知（通知聊天界面关闭，不然从聊天界面进来拉黑的话，拉黑完成又回到跟此人的聊天界面的话，体验就有点怪异了）
////    [NotificationCenterFactory blockUserComplete_REMOVE:self];
//
////    [super viewDidUnload];
//}

// Override - 界面退出时的清理动作
- (void)deallocImpl
{
    [super deallocImpl];
    
    // 逆初始化：释放资源
    [self deInitToGuest];
    // 取消注册通知：拉黑完成通知（通知聊天界面关闭，不然从聊天界面进来拉黑的话，拉黑完成又回到跟此人的聊天界面的话，体验就有点怪异了）
    [NotificationCenterFactory blockUserComplete_REMOVE:self];
}

//// 注意：本类中的dealloc方法可能并不会被最终调用，为了实现界面退出时的清理动作，目前是借助本回调中通过（ [self isMovingFromParentViewController] || [self.navigationController isBeingDismissed]）这样的判断来实现检测页面真正的退出动作的
//- (void)viewWillDisappear:(BOOL)animated {
//    [super viewWillDisappear:animated];
//
//    // 本界面退出时执行清理操作
//    if ([self isMovingFromParentViewController] || [self.navigationController isBeingDismissed]) {
//        DDLogDebug((@"!!! viewWillDisappear中检查到本页面正在被pop或dismiss，即将执行清理动作！");
//       [self deallocImpl];
//    }
//}

- (void)initGUI
{
    [self setupMinimalNavigationBar];
    if (@available(iOS 11.0, *)) {
        self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
}

- (void)setupMinimalNavigationBar
{
    [super setupMinimalNavigationBar];
    self.navigationItem.prompt = nil;
    if ([self.toId isEqualToString:@"10001"]) {
        UIBarButtonItem *item = [self rightBarButtonItemFor10001];
        if (item.customView) {
            [self rb_attachViewToChatCustomNavRight:item.customView];
        }
        self.navAvatarButton = nil;
        self.navAvatarImageView = nil;
    } else {
        [self rb_rightCircularAvatarBarButtonItemWithAction:@selector(onNavAvatarTapped)];
        [self loadPeerAvatarForNav];
    }
    self.rb_chromeNavigationBar.titleLabel.text = self.toName ?: @"";
}

- (void)rb_deferredSetupCustomNavigationBar
{
    self.rb_chromeNavigationBar.titleLabel.text = self.toName ?: @"";
}

- (void)rb_didSetupCustomNavigationBar
{
    self.navigationItem.prompt = nil;
    if ([self.toId isEqualToString:@"10001"]) {
        UIBarButtonItem *item = [self rightBarButtonItemFor10001];
        if (item.customView) {
            [self rb_attachViewToChatCustomNavRight:item.customView];
        }
        self.navAvatarButton = nil;
        self.navAvatarImageView = nil;
    } else {
        [self rb_rightCircularAvatarBarButtonItemWithAction:@selector(onNavAvatarTapped)];
        [self loadPeerAvatarForNav];
    }
}

- (void)rb_deferredSetupAfterMoreContent
{
    [super rb_deferredSetupAfterMoreContent];
    [self _initMoreContentView];
}

- (void)loadPeerAvatarForNav
{
    UserEntity *peer = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:self.toId];
    NSString *avatarFileName = peer ? peer.userAvatarFileName : nil;
    if (self.navAvatarImageView) {
        [RBAvatarView setAvatarWithFileName:avatarFileName uid:self.toId onImageView:self.navAvatarImageView placeholder:[UIImage imageNamed:@"default_avatar_60"]];
    }
}

- (void)loadPeerOnlineStatusForNav
{
    UserEntity *peer = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:self.toId];
    if (!peer) {
        [self updateNavSubtitle:@""];
        return;
    }
    NSString *subtitle = [ChatRootViewController navSubtitleForOnline:[peer isOnline] latestLoginTime2:peer.latest_login_time];
    [self updateNavSubtitle:subtitle];
}

- (void)onNavAvatarTapped
{
    if ([self.toId isEqualToString:@"10001"]) {
        [ViewControllerFactory goMessageSearch10001ViewController:self.navigationController
                                                        chatType:CHAT_TYPE_GUEST_CHAT
                                                          dataId:self.toId
                                                     partnerName:self.toName
                                          showSearchBarWhenPushed:NO
                                             initialSearchKeyword:nil];
        return;
    }
    if (![BasicTool isOfficialAccountHideAvatarInChat:self.toId]) {
        [self gotoGuestInfo:nil];
    }
}

- (void)onNavSearchTapped
{
    [self showChatSearchBarAnimated:YES];
}

- (void)onNavMoreTappedFor10001
{
    UIView *anchorView = [self rb_anchorViewForChatNavMoreMenu] ?: (UIView *)self.navigationItem.rightBarButtonItem.customView;
    if (!anchorView) return;
    __weak typeof(self) wself = self;
    [ChatMessageModeMenu showFromViewController:self
                                    anchorView:anchorView
                                 onSelectIndex:^(NSInteger index) {
        if (index == 0) {
            [ViewControllerFactory goMessageSearch10001ViewController:wself.navigationController
                                                            chatType:CHAT_TYPE_GUEST_CHAT
                                                              dataId:wself.toId
                                                         partnerName:wself.toName
                                              showSearchBarWhenPushed:NO
                                                 initialSearchKeyword:nil];
            return;
        }
    }];
}

- (UIBarButtonItem *)rightBarButtonItemFor10001
{
    UIView *container = [ChatMessageModeMenu navSearchMoreCapsuleWithSearchTarget:self
                                                                     searchAction:@selector(onNavSearchTapped)
                                                                       moreTarget:self
                                                                        moreAction:@selector(onNavMoreTappedFor10001)];
    return [[UIBarButtonItem alloc] initWithCustomView:container];
}

- (UIBarButtonItem *)customRightBarButtonItemForRestore
{
    if ([self.toId isEqualToString:@"10001"]) {
        return [self rightBarButtonItemFor10001];
    }
    return nil;
}

// 初始化“（+）更多”内容面板
- (void)exitMultiSelectMode
{
    [super exitMultiSelectMode];
    if ([self.toId isEqualToString:@"10001"]) return;
    [self loadPeerAvatarForNav];
}

- (void)_initMoreContentView
{
    // 设置代理以便在本类中处理面板中的点击事件
    self.bottomBoxMoreView.delegate = self;

    NSMutableArray *moreMenuItems = [NSMutableArray array];

    kmMoreMenuItem *shareMenuItem1 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_img"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_img"] title:@"照片" actionId:T_MORE_ACTION_ID_IMAGE];
    kmMoreMenuItem *shareMenuItem2 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_camra"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_camra"] title:@"拍摄" actionId:T_MORE_ACTION_ID_PHOTO];
    kmMoreMenuItem *shareMenuItem3 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_file"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_file"] title:@"文件" actionId:T_MORE_ACTION_ID_FILE];
    kmMoreMenuItem *shareMenuItem5 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_location"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_location"] title:@"位置" actionId:T_MORE_ACTION_ID_LOCATION];
    kmMoreMenuItem *shareMenuItemContact = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_user"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_user"] title:@"名片" actionId:T_MORE_ACTION_ID_CONTACT_MERGED];
    kmMoreMenuItem *shareMenuItemVoiceVideo = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"yy"]  highlightIconImage:[UIImage imageNamed:@"yy"] title:@"音视频" actionId:T_MORE_ACTION_ID_VOICE_VIDEO_CHAT];
    kmMoreMenuItem *shareMenuItemFavorites = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"scc"]  highlightIconImage:[UIImage imageNamed:@"scc"] title:@"收藏" actionId:T_MORE_ACTION_ID_FAVORITES];
    shareMenuItemFavorites.usesCompactMenuIcon = YES;
    kmMoreMenuItem *shareMenuItemRedPacket = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"wallet_icon2"]  highlightIconImage:[UIImage imageNamed:@"wallet_icon2"] title:@"红包" actionId:T_MORE_ACTION_ID_RED_PACKET];
    shareMenuItemRedPacket.usesCompactMenuIcon = YES;
    kmMoreMenuItem *shareMenuItemTransfer = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"wallet_icon1"]  highlightIconImage:[UIImage imageNamed:@"wallet_icon1"] title:@"转账" actionId:T_MORE_ACTION_ID_TRANSFER];
    shareMenuItemTransfer.usesWalletStyleIcon = YES;

    BOOL is10001 = [self.toId isEqualToString:@"10001"];
    [moreMenuItems addObject:shareMenuItem1];
    [moreMenuItems addObject:shareMenuItem2];
    [moreMenuItems addObject:shareMenuItemContact];
    if (!is10001) [moreMenuItems addObject:shareMenuItemVoiceVideo];
    if (!is10001) [moreMenuItems addObject:shareMenuItemRedPacket];
    if (!is10001) [moreMenuItems addObject:shareMenuItemTransfer];
    if (!is10001) [moreMenuItems addObject:shareMenuItemFavorites];
    [moreMenuItems addObject:shareMenuItem5];
    [moreMenuItems addObject:shareMenuItem3];

    self.bottomBoxMoreView.shareMenuItems = moreMenuItems;
}

// 初始化聊天界面顶部的信息提示组件
- (void)_initTopExtraView
{
    // 陌生人聊天页收敛为与好友页一致，不再显示额外顶部提示条。
}

/**
 * 初始化与该陌生人的聊天相关设置.
 */
- (void)initToGuest
{
    if(self.toId == nil)
    {
        [APP showToastError:@"切换到陌生人的聊天界面失败了，原因是此人信息数据不存在！"];
        return;
    }

    self.title = [NSString stringWithFormat:@"%@", self.toName];

    // 聊天数据模型，对应于ColectionView的数据Model
    if (RB_CHAT_PAGE_DB_ONLY) {
        [[[IMClientManager sharedInstance] getMessagesProvider] clearMessages:self.toId];
    }
    MessagesProvider *provider = [[IMClientManager sharedInstance] getMessagesProvider];
    self.chattingDatas = [provider getMessages:self.toId];
    [self.chattingDatas addObserver:self.chattingDatasObserver];
    self.rb_shouldDeferInitialChatListReloadUntilSqliteBootstrap =
        ([self.chattingDatas getDataList].count == 0 && [provider rb_isSqliteBootstrapInProgressForChatUid:self.toId]);
}

/**
 加载用户头像。
 */
- (void)initAvatarImage
{
    // 先设置好用户头像默认值
    self.outgoingAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:[UIImage imageNamed:@"chat_avatar_default"]
                                                                          diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
    self.incomingAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:[UIImage imageNamed:@"chat_avatar_default"]
                                                                          diameter:kJSQMessagesCollectionViewAvatarSizeDefault];

    // 本地用户头像在气泡中通过 RBAvatarView 按需加载
    UserEntity *curUser = [IMClientManager sharedInstance].localUserInfo;
    if (curUser && ![BasicTool isStringEmpty:curUser.userAvatarFileName]) {
        self.outgoingAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:[UIImage imageNamed:@"chat_avatar_default"] diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
    }
}

/**
 * 逆初始化与该陌生人的聊天相关设置.
 * <p>
 * 本方法在资源回收时调用，是方法 {@link #initToFriend(RosterElementEntity)}的逆方法.
 */
- (void)deInitToGuest
{
    // 取消设置聊天消息数据模型观察者
    [self.chattingDatas removeObserver:self.chattingDatasObserver];
}

// @Override-重写父类方法：返回聊天列表的消息数据集合对象引用
- (NSMutableArray<JSQMessage *> *) getChattingDatasList
{
    return [self.chattingDatas getDataList];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - Actions

// 标题栏下方“添加好友”按钮的点击事件处理
- (void)gotoFriendReqSend:(UIBarButtonItem *)sender
{
    // 查询并进入添加好友界面
    [QueryFriendInfoAsync doIt:self.toId hudParentView:self.view complete:^(BOOL sucess, UserEntity *userInfo) {
        if(sucess && userInfo != nil)
        {
            // go to 发送好友请求界面
            [ViewControllerFactory goFriendReqSendViewController:self.navigationController withDatas:userInfo addSource:@"temp_chat"];
        }
        else
        {
            [BasicTool showAlertInfo:@"查询没有成功，可能是网络故障或用户信息不存！" parent:self];
        }
    }];
}

// 标题栏右边“用户信息”按钮的点击事件处理
- (void)gotoGuestInfo:(UIBarButtonItem *)sender
{
    [QueryFriendInfoAsync gotoWatchUserInfo:self.toId withInfo:nil nav:self.navigationController view:self.view vc:self addSource:@"temp_chat_session"];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - kmMoreMenuViewDelegate（ “(+)更多”功能的item点击代理方法 ）

- (void)didSelecteMoreMenuItem:(kmMoreMenuItem *)shareMenuItem atIndex:(NSInteger)index
{
    switch (shareMenuItem.actionId)
    {
        // 发送图片消息（从图片）
        case T_MORE_ACTION_ID_IMAGE:
        {
            // 进入相册选择图片并发送图片消息
            [super.imagePickerWrapper takeAlbum:YES];
            break;
        }
        // 发送图片消息（从相机）
        case T_MORE_ACTION_ID_PHOTO:
        {
            // 进入相机拍照并发送图片消息
            [super.imagePickerWrapper takePhoto];
            break;
        }
        // 发送大文件消息
        case T_MORE_ACTION_ID_FILE:
        {
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            [super openFilePicker];
            break;
        }
        // 发送短视频消息
        case T_MORE_ACTION_ID_SHORTVIDEO:
        {
            [super openShortVideoRecorder];
            break;
        }
        // 发送位置消息
        case T_MORE_ACTION_ID_LOCATION:
        {
            [super openLocationChoose];
            break;
        }
        case T_MORE_ACTION_ID_CONTACT_MERGED:
        {
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            __weak typeof(self) safeSelf = self;
            [self hideBottomBoxAnim:YES completion:^{
                __strong typeof(safeSelf) strongSelf = safeSelf;
                if (!strongSelf) return;
                [LPActionSheet showActionSheetWithTitle:nil
                                      cancelButtonTitle:@"取消"
                                 destructiveButtonTitle:nil
                                      otherButtonTitles:@[@"个人名片", @"群名片"]
                                    otherButtonImages:nil
                                                handler:^(LPActionSheet *actionSheet, NSInteger index) {
                    __strong typeof(safeSelf) s = safeSelf;
                    if (!s) return;
                    if (index == 0) return;
                    if (index == 1) {
                        [s openUserChoose];
                    } else if (index == 2) {
                        [s openGroupChoose];
                    }
                }];
            }];
            return;
        }
        // 发送个人名片消息
        case T_MORE_ACTION_ID_CONTACT_FRIEND:
        {
            [self openUserChoose];
            break;
        }
        // 发送群名片消息
        case T_MORE_ACTION_ID_CONTACT_GROUP:
        {
            [super openGroupChoose];
            break;
        }
        // 收藏（弹出选择器，点击直接发送）
        case T_MORE_ACTION_ID_FAVORITES:
        {
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            [self openFavoritesPicker];
            break;
        }
        case T_MORE_ACTION_ID_VOICE_VIDEO_CHAT:
        {
            if ([[CallManager sharedInstance] isInCall]) {
                [BasicTool showAlertInfo:@"当前正在通话中，请先结束当前通话" parent:self];
                break;
            }
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            __weak typeof(self) safeSelf = self;
            [self hideBottomBoxAnim:YES completion:^{
                __strong typeof(safeSelf) strongSelf = safeSelf;
                if (!strongSelf) return;
                [LPActionSheet showActionSheetWithTitle:nil
                                      cancelButtonTitle:@"取消"
                                 destructiveButtonTitle:nil
                                      otherButtonTitles:@[@"语音通话", @"视频通话"]
                                    otherButtonImages:nil
                                                handler:^(LPActionSheet *actionSheet, NSInteger index) {
                    __strong typeof(safeSelf) s = safeSelf;
                    if (!s) return;
                    if (index == 1) {
                        [[CallManager sharedInstance] startCall:s.toId remoteNickname:s.toName callType:CallTypeVoice];
                        [ViewControllerFactory goCallViewController:s.toId
                                                 remoteUserNickname:s.toName
                                                           callType:CallTypeVoice
                                                           isCaller:YES];
                    } else if (index == 2) {
                        [[CallManager sharedInstance] startCall:s.toId remoteNickname:s.toName callType:CallTypeVideo];
                        [ViewControllerFactory goCallViewController:s.toId
                                                 remoteUserNickname:s.toName
                                                           callType:CallTypeVideo
                                                           isCaller:YES];
                    }
                }];
            }];
            return;
        }
        case T_MORE_ACTION_ID_RED_PACKET:
        {
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            __weak typeof(self) wself = self;
            [self hideBottomBoxAnim:YES completion:^{
                __strong typeof(wself) s = wself;
                if (!s) return;
                WalletRedPacketSendViewController *vc = [[WalletRedPacketSendViewController alloc] init];
                vc.receiverType = 1;
                vc.receiverUid = s.toId;
                vc.initialPacketType = 1;
                vc.hidesBottomBarWhenPushed = YES;
                [s.navigationController pushViewController:vc animated:YES];
            }];
            return;
        }
        case T_MORE_ACTION_ID_TRANSFER:
        {
            WalletTransferViewController *vc = [[WalletTransferViewController alloc] init];
            vc.toUid = self.toId;
            vc.recipientDisplayName = (self.title.length > 0 ? self.title : nil) ?: self.toName;
            vc.recipientWechatId = nil;
            vc.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        default:
        {
            [BasicTool showAlertInfo:@"此功能暂未开放，敬请关注！" parent:self];
            break;
        }
    }

    // 并关闭“(+)更多”功能面板
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
#pragma mark - Collection view data source（消息列表数据源代理方法）

// @Override - 重写父类方法：单独的方法里处理头像显示逻辑，方便群聊子类界面中以更大的自由度实现自已的显示逻辑
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
        NSString *avatarFileName = [[[IMClientManager sharedInstance] getAlarmsProvider] getExtra1String:AMT_guestChatMessage dataId:entity.senderId];
        [RBAvatarView setAvatarWithFileName:avatarFileName uid:entity.senderId onImageView:avatarView placeholder:placeImg staticPreviewOnly:YES];
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - Responding to collection view tap events

// 点击消息气泡边上的头像事件处理方法
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapAvatarImageView:(UIImageView *)avatarImageView atIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *entity = [[self getChattingDatasList] objectAtIndex:indexPath.item];
    if(entity != nil)
    {
        // 点击的是本地用户头像
        if ([entity.senderId isEqualToString:self.senderId])
        {
            // 查看本地用户的"个人中心"
            [ViewControllerFactory goUserViewController:self.navigationController];
        }
        else
        {
            // 特殊：与 10001 的对话里，左侧头像代表“来源用户”，应跳到来源人的资料
            if ([self.toId isEqualToString:@"10001"]
                && entity.quote_sender_uid != nil
                && entity.quote_sender_uid.length > 0) {

                NSString *sourceUid = entity.quote_sender_uid;
                NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;

                if (localUid != nil && [sourceUid isEqualToString:localUid]) {
                    [ViewControllerFactory goUserViewController:self.navigationController];
                    return;
                }

                FriendsListProvider *flp = [[IMClientManager sharedInstance] getFriendsListProvider];
                if (flp != nil && [flp isUserInRoster2:sourceUid]) {
                    [QueryFriendInfoAsync gotoWatchUserInfo:sourceUid
                                                   withInfo:nil
                                                        nav:self.navigationController
                                                       view:self.view
                                                         vc:self];
                }
                return;
            }

            // 只读官方账号（10000、400070）：不允许查看个人主页；10001、400069 可跳转
            if ([BasicTool isOfficialAccountHideAvatarInChat:self.toId]) {
                return;
            }
            // 查询并查看该用户的最新信息
            [QueryFriendInfoAsync gotoWatchUserInfo:self.toId withInfo:nil nav:self.navigationController view:self.view vc:self];
//            [QueryFriendInfoAsync doIt:NO mail:nil uid:self.tempChatUIDForInit hudParentView:self.view withNC:self.navigationController canOpenChat:NO];
        }
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 其它方法

// 处理拉黑完成通知（通知聊天界面关闭，不然从聊天界面进来拉黑的话，拉黑完成又回到跟此人的聊天界面的话，体验就有点怪异了）
- (void) blockUserComplete:(NSNotification*)notification
{
    NSString *uidBeBlocked = (NSString *)notification.object;
    DDLogDebug(@"【陌生人聊天界面】-收到此人(%@)被拉黑的通知！", uidBeBlocked);

    if([self.toId isEqualToString:uidBeBlocked])
    {
        // 并在Toast消失时退出添加好友界面
        [self doBack:NO];
    }
}

@end
