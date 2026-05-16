//telegram @wz662
#import "ChatViewController.h"
#import "IMClientManager.h"
#import "Default.h"
#import "ClientCoreSDK.h"
#import "Protocal.h"
#import "AppDelegate.h"
#import "SDImageCache.h"
#import "SDWebImageManager.h"
#import "MSSBrowseModel.h"
#import "MSSBrowseNetworkViewController.h"
#import "TZImagePickerController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import "TZImageManager.h"
#import "SendImageHelper.h"
#import "ChatDataHelper.h"
#include "amrFileCodec.h"
#import "SendVoiceHelper.h"
#import "ViewControllerFactory.h"
#import "ChatMessageModeMenu.h"
#import "UserEntity.h"
#import "CallManager.h"
#import "NotificationCenterFactory.h"
#import "kmMoreMenuItem.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "PromtHelper.h"
#import "MessageHelper.h"
#import "QueryFriendInfoAsync.h"
#import "LPActionSheet.h"
#import "FileTool.h"
#import "SendFileHelper.h"
#import "FileMeta.h"
#import "BigFileUploadManager.h"
#import "ReceivedFileHelper.h"
#import "SendShortVideoHelper.h"
#import "AlarmType.h"
#import "GetLocationViewController.h"
#import "LocationUtils.h"
#import "WalletTransferViewController.h"
#import "WalletRedPacketSendViewController.h"
#import "BasicTool.h"
#import "JSQMessages.h"
#import "MsgBodyRoot.h"
#import "AlarmsViewController.h"
#import "MessagesProvider.h"
#import "UserDefaultsToolKits.h"


// 发送图片消息（从图片）
const int MORE_ACTION_ID_IMAGE               = 1;
// 发送图片消息（从相机）
const int MORE_ACTION_ID_PHOTO               = 2;
// 实时语音聊天
const int MORE_ACTION_ID_REALTIME_VOICE_CHAT = 3;
// 实时视频聊天
const int MORE_ACTION_ID_REALTIME_VIDEO_CHAT = 4;
// 发送礼物
const int MORE_ACTION_ID_GIFT                = 5;
// 发送大文件
const int MORE_ACTION_ID_FILE                = 6;
// 发送短视频
const int MORE_ACTION_ID_SHORTVIDEO          = 7;
// 发送位置
const int MORE_ACTION_ID_LOCATION            = 8;
// 发送个人名片
const int MORE_ACTION_ID_CONTACT_FRIEND      = 9;
// 发送群名片
const int MORE_ACTION_ID_CONTACT_GROUP       = 10;
// 收藏
const int MORE_ACTION_ID_FAVORITES           = 11;
// 红包
const int MORE_ACTION_ID_RED_PACKET          = 12;
// 转账
const int MORE_ACTION_ID_TRANSFER            = 13;
// 语音/视频通话（点击后弹出选择语音通话或视频通话）
const int MORE_ACTION_ID_VOICE_VIDEO_CHAT    = 14;
// 名片（点击后在底部弹窗选择个人名片或群名片）
const int MORE_ACTION_ID_CONTACT_MERGED      = 15;


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface ChatViewController ()

// 聊天列表的消息数据集合
@property (nonatomic, retain) NSMutableArrayObservableEx *chattingDatas;

/// 右滑取消时避免导航栏动画导致闪烁
@property (nonatomic, assign) BOOL oac_hadWillDisappearWithoutDid;
/// 被子页覆盖时移除了聊天列表 observer，返回后需至少补一次强制刷新，避免系统消息已入内存但 cell 未重绘
@property (nonatomic, assign) BOOL rb_needForceRefreshAfterCoveredDisappear;
@property (nonatomic, strong) UIView *friendSendBlockedOverlayView;
@property (nonatomic, strong) UILabel *friendSendBlockedOverlayLabel;
@property (nonatomic, strong) UIButton *friendSendBlockedActionButton;
@property (nonatomic, assign) BOOL rb_friendSendBlocked;

// “我”的消息头像
@property (strong, nonatomic) UIImage *outgoingAvatarImage;
// 对方的消息头像
@property (strong, nonatomic) UIImage *incomingAvatarImage;

//// 聊天消息数据模型变动观察者实现block
//@property (nonatomic, copy) ObserverCompletion chattingDatasObserver;

//// 设置{@link BigFileUploadManager}中大文件任务状态改变观察者block(主要用于“我”发送的大文件消息)，
//// 用于UI及时刷新文件上传状态在界面上的显示（本观察者通常由对应的UI界面设置，界面退到后台消失时取消设置）
//@property (nonatomic, copy) ObserverCompletion fileStatusChangedObserver;

@end


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation ChatViewController

/// 刷新聊天头部标题；官方账号在昵称后追加图标。
- (void)rb_refreshChatNavTitle
{
    NSString *titleText = self.toName ?: @"";
    self.title = titleText;
    self.navigationItem.title = titleText;
    UILabel *titleLabel = self.rb_chromeNavigationBar.titleLabel;
    UIFont *titleFont = titleLabel.font ?: [BasicTool getBoldSystemFontOfSize:16.0f];
    UIColor *titleColor = titleLabel.textColor ?: UI_DEFAULT_TITLE_FONT_COLOR;
    titleLabel.attributedText = [BasicTool attributedName:titleText
                                      appendOfficialBadge:[BasicTool isSystemAdmin:self.toId]
                                                     font:titleFont
                                                textColor:titleColor
                                              badgeHeight:14.0f];
}

//---------------------------------------------------------------------------------------------------
#pragma mark - UIViewController相关方法重写

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil chatWith:(NSString *)friendUID andNickname:(NSString *)friendNickname;
{
    if(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        super.chatType = CHAT_TYPE_FREIDN_CHAT;
        // 初始化时传过来的好友UID
        self.toId = friendUID;
        // 初始化时传过来的好友昵称
        self.toName = friendNickname;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 单聊对话列表不显示双方头像
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
    [NotificationCenterFactory friendRemarkChanged_ADD:self selector:@selector(friendRemarkChangedComplete:)];
    [NotificationCenterFactory friendChatSendBlockedStateChanged_ADD:self selector:@selector(friendChatSendBlockedStateChanged:)];

    [self initToFriend];
    [self rb_deferredSetupAfterFirstFrame];

    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [wself initAvatarImage];
    });
}

// 根据UIViewController的生命周期，本方法将在每次本界面每次回到前台时被调用（生命周期中，本方法可能会被反复调用）
- (void)viewWillAppear:(BOOL)animated
{
    // 系统导航栏：右滑取消返回时避免与转场叠加导致闪烁
    BOOL isReappearAfterCancelledPop = self.oac_hadWillDisappearWithoutDid;
    if (isReappearAfterCancelledPop) self.oac_hadWillDisappearWithoutDid = NO;
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
    [super viewWillAppear:animated];

    // 设置当前正处于激话状态下的聊天好友uid
    [IMClientManager sharedInstance].currentFrontChattingUserUID = self.toId;

    if (self.chattingDatas && self.chattingDatasObserver) {
        [self.chattingDatas removeObserver:self.chattingDatasObserver];
        [self.chattingDatas addObserver:self.chattingDatasObserver];
    }
    
    // 设置大文件上传状态变更观察者(主要用于“我”发送的大文件消息)
    [[BigFileUploadManager sharedInstance] setFileStatusChangedObserver:self.fileStatusChangedObserver];

    if (self.rb_initialSessionUnreadCount <= 0) {
        AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
        int idx = ap ? [ap getAlarmIndex:AMT_friendChatMessage dataId:self.toId] : -1;
        if (idx >= 0) {
            self.rb_initialSessionUnreadCount = [ap getFlagNum:idx];
        }
    }

    // APP中唯一重置未读正式聊天消息的代码：最后确保重置APP首页“消息”未读消息数字的显示
    [[[IMClientManager sharedInstance] getAlarmsProvider] resetFlagNum:AMT_friendChatMessage dataId:self.toId flagNumToReset:0 needUpdateSqlite:YES];
    // 发出通知：强制首页的“消息”Tab上的总未读数
    // * 此时通知刷新首页的“消息”Tab上的总未读数（首页“消息”页面其实已经增加了观察者到“消息”通知数据模型里，但数据模型只能通知道
    // * 到关于数据的新增、删除、替换，而像重置对象里的未读数这样的行为（如进入聊天界面时）是没有办法细化到此粒度的，所以此时在进入
    // * 聊天界面中重置该好友的未读数时，尝试手动发出此通知，使得首页“消息”Tab上的未读数气泡能及时刷新为最新，不然tab上的未读数就不同步了）
    [NotificationCenterFactory refreshMainPageTotalUnread_POST];
    [self rb_applyFriendSendBlockedStateIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (![self.toId isEqualToString:@"10001"]) {
        [self loadPeerAvatarForNav];
    }
    [self rb_applyFriendSendBlockedStateIfNeeded];

    // 从资料页/好友关系相关子页返回时，本地系统消息可能已写入会话内存，
    // 但聊天页在被覆盖时移除了 observer，返回后需主动把 collectionView 与数据源重新对齐。
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
    if (leavingStack)
        self.oac_hadWillDisappearWithoutDid = YES;
    UINavigationController *nav = self.navigationController;
    if (!nav) return;
    // Push 子页面：下层聊天页隐藏栏时子页需系统栏
    if (!leavingStack) {
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
    self.oac_hadWillDisappearWithoutDid = NO;
    // 取消设置当前正处于激话状态下的聊天好友uid
    [IMClientManager sharedInstance].currentFrontChattingUserUID = nil;
    
    // 取消设置大文件上传状态变更观察者(主要用于“我”发送的大文件消息)
    [[BigFileUploadManager sharedInstance] setFileStatusChangedObserver:nil];

    if (self.chattingDatas && self.chattingDatasObserver) {
        [self.chattingDatas removeObserver:self.chattingDatasObserver];
        self.rb_needForceRefreshAfterCoveredDisappear = YES;
    }

    if ((self.isMovingFromParentViewController || self.isBeingDismissed) && self.navigationController.navigationBarHidden) {
        UIViewController *top = self.navigationController.topViewController;
        if (top && ![top isKindOfClass:[AlarmsViewController class]]) {
            [self.navigationController setNavigationBarHidden:NO animated:NO];
        }
    }
    [super viewDidDisappear:animated];
}

//// “viewDidUnload:”方法已在ios6后被废弃（且它只在系统内存低时才被调用），资源释放等工作正确的方式是放到 “dealloc:"中处理
//- (void)dealloc
////- (void)viewDidUnload
//{
////    // 逆初始化：释放资源
////    [self deInitToFriend];
////
////    // 取消注册通知：拉黑完成通知（通知聊天界面关闭，不然从聊天界面进来拉黑的话，拉黑完成又回到跟此人的聊天界面的话，体验就有点怪异了）
////    [NotificationCenterFactory blockUserComplete_REMOVE:self];
////    // 取消注册通知：修改完成好友的备注后的广播
////    [NotificationCenterFactory friendRemarkChanged_REMOVE:self];
//
////    [super viewDidUnload];
//}

// Override - 界面退出时的清理动作
- (void)deallocImpl
{
    [super deallocImpl];
    
    // 逆初始化：释放资源
    [self deInitToFriend];

    // 取消注册通知：拉黑完成通知（通知聊天界面关闭，不然从聊天界面进来拉黑的话，拉黑完成又回到跟此人的聊天界面的话，体验就有点怪异了）
    [NotificationCenterFactory blockUserComplete_REMOVE:self];
    // 取消注册通知：修改完成好友的备注后的广播
    [NotificationCenterFactory friendRemarkChanged_REMOVE:self];
    [NotificationCenterFactory friendChatSendBlockedStateChanged_REMOVE:self];
}

- (void)initGUI
{
    [self setupMinimalNavigationBar];
    if (@available(iOS 11.0, *)) {
        self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    // initMoreContentView（15+ imageNamed）已移至 ChatRootViewController rb_deferredSetupAfterFirstFrame，减轻首帧卡顿
}

- (void)initFriendSendBlockedOverlay
{
    if (self.friendSendBlockedOverlayView != nil || self.inputToolbar == nil) {
        return;
    }

    self.friendSendBlockedOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
    self.friendSendBlockedOverlayView.backgroundColor = HexColor(0xF5F5F5);
    self.friendSendBlockedOverlayView.hidden = YES;

    self.friendSendBlockedOverlayLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.friendSendBlockedOverlayLabel.text = @"对方已不是你的好友，当前不可发送消息";
    self.friendSendBlockedOverlayLabel.textColor = HexColor(0x999999);
    self.friendSendBlockedOverlayLabel.font = [UIFont systemFontOfSize:14];
    self.friendSendBlockedOverlayLabel.textAlignment = NSTextAlignmentCenter;
    [self.friendSendBlockedOverlayView addSubview:self.friendSendBlockedOverlayLabel];

    self.friendSendBlockedActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.friendSendBlockedActionButton setTitle:@"去添加好友" forState:UIControlStateNormal];
    self.friendSendBlockedActionButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.friendSendBlockedActionButton addTarget:self action:@selector(onFriendSendBlockedAddFriendTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.friendSendBlockedOverlayView addSubview:self.friendSendBlockedActionButton];

    UIView *topLine = [[UIView alloc] initWithFrame:CGRectZero];
    topLine.backgroundColor = HexColor(0xDDDDDD);
    [self.friendSendBlockedOverlayView addSubview:topLine];

    [self.inputToolbar addSubview:self.friendSendBlockedOverlayView];

    self.friendSendBlockedOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.friendSendBlockedOverlayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.friendSendBlockedActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    topLine.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.friendSendBlockedOverlayView.leadingAnchor constraintEqualToAnchor:self.inputToolbar.leadingAnchor],
        [self.friendSendBlockedOverlayView.trailingAnchor constraintEqualToAnchor:self.inputToolbar.trailingAnchor],
        [self.friendSendBlockedOverlayView.topAnchor constraintEqualToAnchor:self.inputToolbar.topAnchor],
        [self.friendSendBlockedOverlayView.bottomAnchor constraintEqualToAnchor:self.inputToolbar.bottomAnchor],

        [self.friendSendBlockedOverlayLabel.leadingAnchor constraintEqualToAnchor:self.friendSendBlockedOverlayView.leadingAnchor constant:16.0],
        [self.friendSendBlockedOverlayLabel.centerYAnchor constraintEqualToAnchor:self.friendSendBlockedOverlayView.centerYAnchor],
        [self.friendSendBlockedActionButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.friendSendBlockedOverlayLabel.trailingAnchor constant:8.0],
        [self.friendSendBlockedActionButton.trailingAnchor constraintEqualToAnchor:self.friendSendBlockedOverlayView.trailingAnchor constant:-16.0],
        [self.friendSendBlockedActionButton.centerYAnchor constraintEqualToAnchor:self.friendSendBlockedOverlayView.centerYAnchor],

        [topLine.leadingAnchor constraintEqualToAnchor:self.friendSendBlockedOverlayView.leadingAnchor],
        [topLine.trailingAnchor constraintEqualToAnchor:self.friendSendBlockedOverlayView.trailingAnchor],
        [topLine.topAnchor constraintEqualToAnchor:self.friendSendBlockedOverlayView.topAnchor],
        [topLine.heightAnchor constraintEqualToConstant:0.5],
    ]];
}

- (void)applyFriendSendBlockedUI:(BOOL)blocked reason:(NSString *)reason
{
    if (self.inputToolbar == nil || self.inputToolbar.contentView == nil) {
        return;
    }
    if (self.friendSendBlockedOverlayView == nil || self.friendSendBlockedOverlayLabel == nil) {
        [self initFriendSendBlockedOverlay];
    }
    if (self.friendSendBlockedOverlayView == nil || self.friendSendBlockedOverlayLabel == nil) {
        return;
    }

    self.rb_friendSendBlocked = blocked;
    if (blocked) {
        self.friendSendBlockedOverlayLabel.text = reason.length > 0 ? reason : @"对方已不是你的好友，当前不可发送消息";
        self.friendSendBlockedOverlayView.hidden = NO;
        self.friendSendBlockedActionButton.hidden = NO;
        self.inputToolbar.contentView.textView.editable = NO;
        self.inputToolbar.contentView.textView.text = @"";
        self.inputToolbar.contentView.leftBarButtonItem.enabled = NO;
        self.inputToolbar.contentView.leftBarButton2Item.enabled = NO;
        self.inputToolbar.contentView.rightBarButtonItem.enabled = NO;
        [self.inputToolbar.contentView.textView resignFirstResponder];
    } else {
        self.friendSendBlockedOverlayView.hidden = YES;
        self.friendSendBlockedActionButton.hidden = YES;
        self.inputToolbar.contentView.textView.editable = YES;
        self.inputToolbar.contentView.leftBarButtonItem.enabled = YES;
        self.inputToolbar.contentView.leftBarButton2Item.enabled = YES;
        self.inputToolbar.contentView.rightBarButtonItem.enabled = YES;
    }
}

- (void)rb_applyFriendSendBlockedStateIfNeeded
{
    BOOL blocked = [UserDefaultsToolKits isFriendChatSendBlockedUid:self.toId];
    [self applyFriendSendBlockedUI:blocked reason:(blocked ? @"对方已不是你的好友，当前不可发送消息" : nil)];
}

- (void)friendChatSendBlockedStateChanged:(NSNotification *)notification
{
    NSDictionary *payload = [notification.object isKindOfClass:[NSDictionary class]] ? (NSDictionary *)notification.object : nil;
    NSString *uid = payload[@"uid"];
    if (uid.length == 0 || ![uid isEqualToString:self.toId]) {
        return;
    }
    BOOL blocked = [payload[@"blocked"] boolValue];
    NSString *hint = payload[@"hint"];
    [self applyFriendSendBlockedUI:blocked reason:hint];
}

- (void)onFriendSendBlockedAddFriendTapped
{
    [QueryFriendInfoAsync gotoAddFriendRequestPage:self.toId
                                               nav:self.navigationController
                                              view:self.view
                                                vc:self
                                         addSource:@"chat_blocked"];
}

/// 自定义顶栏：左返回 + 标题；10001 为搜索｜更多胶囊，其它单聊右侧为对方圆形头像（点击进入资料）
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
    [self rb_refreshChatNavTitle];
}

- (void)rb_deferredSetupCustomNavigationBar
{
    [self rb_refreshChatNavTitle];
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
    [self rb_refreshChatNavTitle];
}

- (void)loadPeerAvatarForNav
{
    UserEntity *friendInfo = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:self.toId];
    NSString *avatarFileName = friendInfo ? friendInfo.userAvatarFileName : nil;
    if (self.navAvatarImageView) {
        [RBAvatarView setAvatarWithFileName:avatarFileName uid:self.toId onImageView:self.navAvatarImageView placeholder:[UIImage imageNamed:@"default_avatar_60"]];
    }
}

- (void)exitMultiSelectMode
{
    [super exitMultiSelectMode];
    if ([self.toId isEqualToString:@"10001"]) return;
    [self loadPeerAvatarForNav];
}

- (void)onNavAvatarTapped
{
    if ([self.toId isEqualToString:@"10001"]) {
        [ViewControllerFactory goMessageSearch10001ViewController:self.navigationController
                                                        chatType:CHAT_TYPE_FREIDN_CHAT
                                                          dataId:self.toId
                                                     partnerName:self.toName
                                          showSearchBarWhenPushed:NO
                                             initialSearchKeyword:nil];
        return;
    }
    if (![BasicTool isOfficialAccountHideAvatarInChat:self.toId]) {
        [self gotoFriendInfo:nil];
    }
}

- (void)onNavSearchTapped
{
    // 消息对话页点击搜索：在当前页弹出搜索框，与收藏夹页行为一致
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
            // 以聊天模式查看 = 收藏夹页面 → 跳转到收藏夹
            [ViewControllerFactory goMessageSearch10001ViewController:wself.navigationController
                                                            chatType:CHAT_TYPE_FREIDN_CHAT
                                                              dataId:wself.toId
                                                         partnerName:wself.toName
                                              showSearchBarWhenPushed:NO
                                                 initialSearchKeyword:nil];
            return;
        }
        // 以消息模式查看 = 与10001的对话 → 当前即聊天页，无需跳转
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
- (void)initMoreContentView
{
    // 设置代理以便在本类中处理面板中的点击事件
    self.bottomBoxMoreView.delegate = self;

    NSMutableArray *moreMenuItems = [NSMutableArray array];

    kmMoreMenuItem *shareMenuItem1 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_img"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_img"] title:@"照片" actionId:MORE_ACTION_ID_IMAGE];
    kmMoreMenuItem *shareMenuItem2 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_camra"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_camra"] title:@"拍摄" actionId:MORE_ACTION_ID_PHOTO];
    kmMoreMenuItem *shareMenuItem3 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_file"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_file"] title:@"文件" actionId:MORE_ACTION_ID_FILE];
    
    kmMoreMenuItem *shareMenuItem5 = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_location"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_location"] title:@"位置" actionId:MORE_ACTION_ID_LOCATION];
    kmMoreMenuItem *shareMenuItemContact = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_user"]  highlightIconImage:[UIImage imageNamed:@"chatting_more_func_user"] title:@"名片" actionId:MORE_ACTION_ID_CONTACT_MERGED];
    
    // 语音/视频通话（点击后弹出选择语音通话或视频通话）
    kmMoreMenuItem *shareMenuItemVoiceVideo = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"yy"]  highlightIconImage:[UIImage imageNamed:@"yy"] title:@"音视频" actionId:MORE_ACTION_ID_VOICE_VIDEO_CHAT];
    // 收藏按钮
    kmMoreMenuItem *shareMenuItemFavorites = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"scc"]  highlightIconImage:[UIImage imageNamed:@"scc"] title:@"收藏" actionId:MORE_ACTION_ID_FAVORITES];
    shareMenuItemFavorites.usesCompactMenuIcon = YES;
    // 红包按钮
    kmMoreMenuItem *shareMenuItemRedPacket = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"wallet_icon2"]  highlightIconImage:[UIImage imageNamed:@"wallet_icon2"] title:@"红包" actionId:MORE_ACTION_ID_RED_PACKET];
    shareMenuItemRedPacket.usesCompactMenuIcon = YES;
    // 转账按钮
    kmMoreMenuItem *shareMenuItemTransfer = [[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"wallet_icon1"]  highlightIconImage:[UIImage imageNamed:@"wallet_icon1"] title:@"转账" actionId:MORE_ACTION_ID_TRANSFER];
    shareMenuItemTransfer.usesWalletStyleIcon = YES;

    // 10001 官方账号不显示：音视频、红包、转账、收藏
    BOOL is10001 = [self.toId isEqualToString:@"10001"];
    // 网格 4 列×多行顺序：第1行 照片｜拍摄｜名片｜音视频 → 第2行 红包｜转账｜收藏｜位置 → 第3行 文件（与 kmMoreMenuView 从左到右、先上后下一致）
    [moreMenuItems addObject:shareMenuItem1];   // 照片
    [moreMenuItems addObject:shareMenuItem2];   // 拍摄
    [moreMenuItems addObject:shareMenuItemContact]; // 名片（弹窗选个人/群）
    if (!is10001) [moreMenuItems addObject:shareMenuItemVoiceVideo];
    if (!is10001) [moreMenuItems addObject:shareMenuItemRedPacket];
    if (!is10001) [moreMenuItems addObject:shareMenuItemTransfer];
    if (!is10001) [moreMenuItems addObject:shareMenuItemFavorites];
    [moreMenuItems addObject:shareMenuItem5];   // 位置
    [moreMenuItems addObject:shareMenuItem3];   // 文件

    self.bottomBoxMoreView.shareMenuItems = moreMenuItems;
}

//- (void)initObservers
//{
//    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
//    __weak typeof(self) safeSelf = self;
//
//    self.chattingDatasObserver = ^(id observerble, id arg1) {
//        NSLog(@"收到聊天列表UI数据更新通知了...(observerble=%@, arg1=%@)", observerble, arg1);
//
//        // 没有此行则表格的ui显示内容不会刷新哦
//        [safeSelf finishReceivingMessageAnimated:YES];
//    };
//    
//    self.fileStatusChangedObserver = ^(id observerble, id arg1) {
//        NSLog(@"收到大文件发送状态数据UI更新通知了...");
//
//        // 没有此行则表格的ui显示内容不会刷新哦
//        [safeSelf finishSendingMessageAnimated:YES];
//    };
//}

/**
 * 初始化与该好友的聊天相关设置.
 */
- (void)initToFriend
{
    if(self.toId == nil)
    {
        [APP showToastError:@"切换到好友的聊天界面失败了，原因是好友信息数据不存在！"];
        return;
    }

    [self rb_refreshChatNavTitle];

    MessagesProvider *provider = [[IMClientManager sharedInstance] getMessagesProvider];
    NSLog(@"[ChatEnter][initToFriend] uid=%@ begin", self.toId ?: @"");
    self.chattingDatas = [provider getMessages:self.toId];
    [self.chattingDatas addObserver:self.chattingDatasObserver];
    self.rb_shouldDeferInitialChatListReloadUntilSqliteBootstrap =
        ([self.chattingDatas getDataList].count == 0 && [provider rb_isSqliteBootstrapInProgressForChatUid:self.toId]);
    NSLog(@"[ChatEnter][initToFriend] uid=%@ count=%ld bootstrapping=%d deferInitialReload=%d",
          self.toId ?: @"",
          (long)[self.chattingDatas getDataList].count,
          [provider rb_isSqliteBootstrapInProgressForChatUid:self.toId],
          self.rb_shouldDeferInitialChatListReloadUntilSqliteBootstrap);
}

/**
 加载用户头像。单聊仅我方与对方两个头像，在此各加载一次并缓存，避免每条消息 cell 都重复调 RBAvatarView 导致主线程卡顿。
 */
- (void)initAvatarImage
{
    __weak typeof(self) wself = self;
    // 先不设默认图，留 nil；加载完成后再赋值并仅刷新可见 cell 头像，避免 reloadData 导致整表闪烁
    self.outgoingAvatarImage = nil;
    self.incomingAvatarImage = nil;

    UserEntity *curUser = [IMClientManager sharedInstance].localUserInfo;
    UserEntity *friendInfo = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:self.toId];
    NSString *partnerFileName = friendInfo.userAvatarFileName;

    // 我方头像：后台取缓存或异步下载，只加载一次（不支持视频头像，视频不加载）
    if (curUser && ![BasicTool isStringEmpty:curUser.userAvatarFileName]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *path = [FileDownloadHelper getUserAvatarDownloadURLExt:YES fileName:curUser.userAvatarFileName uid:curUser.user_uid];
            UIImage *img = [FileDownloadHelper loadUserAvatarFromCacheOnly:path donotLoadFromDisk:NO];
            if (img == nil) {
                [FileDownloadHelper loadUserAvatarWithFileName:curUser.userAvatarFileName uid:curUser.user_uid logTag:@"ChatVC-OutAvatar" complete:^(BOOL succ, UIImage *img) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (wself && img) {
                            wself.outgoingAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:img diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
                            [wself rb_updateVisibleAvatarImages];
                        }
                    });
                }];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (wself) {
                        wself.outgoingAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:img diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
                        [wself rb_updateVisibleAvatarImages];
                    }
                });
            }
        });
    }

    // 对方头像：同上，只加载一次（不支持视频头像，视频则跳过不请求）
    // 收藏夹（10001）不预加载“对方”头像，左侧每条消息按收藏来源 uid 单独加载
    if ([self.toId isEqualToString:@"10001"]) {
        return;
    }
    if (self.toId.length > 0 && ![FileDownloadHelper isVideoAvatarFileName:partnerFileName]) {
        NSString *fileName = partnerFileName ?: @"";
        NSString *uid = self.toId;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *path = [FileDownloadHelper getUserAvatarDownloadURLExt:![BasicTool isStringEmpty:fileName] fileName:fileName uid:uid];
            UIImage *img = [FileDownloadHelper loadUserAvatarFromCacheOnly:path donotLoadFromDisk:NO];
            if (img == nil) {
                [FileDownloadHelper loadUserAvatarIntelligent:fileName uid:uid logTag:@"ChatVC-InAvatar" complete:^(BOOL succ, UIImage *img) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (wself && img) {
                            wself.incomingAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:img diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
                            [wself rb_updateVisibleAvatarImages];
                        }
                    });
                } donotLoadFromDisk:NO];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (wself) {
                        wself.incomingAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:img diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
                        [wself rb_updateVisibleAvatarImages];
                    }
                });
            }
        });
    }
}

/// 仅更新当前可见 cell 的头像 image，不 reloadData，避免整表重绘导致头像闪烁
- (void)rb_updateVisibleAvatarImages
{
    if (!self.collectionView.window) return;
    NSArray *list = [self getChattingDatasList];
    if (!list.count) return;
    UIImage *outImg = self.outgoingAvatarImage ?: [UIImage imageNamed:@"chat_avatar_default"];
    UIImage *inImg = self.incomingAvatarImage ?: [UIImage imageNamed:@"chat_avatar_default"];
    NSString *myId = self.senderId ?: @"";
    BOOL is10001 = [self.toId isEqualToString:@"10001"];
    for (NSIndexPath *path in [self.collectionView indexPathsForVisibleItems]) {
        if (path.section != 0 || path.item >= list.count) continue;
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:path];
        if (![cell isKindOfClass:[JSQMessagesCollectionViewCell class]]) continue;
        JSQMessagesCollectionViewCell *msgCell = (JSQMessagesCollectionViewCell *)cell;
        UIImageView *avatarView = msgCell.avatarImageView;
        if (!avatarView) continue;
        JSQMessage *msg = list[path.item];
        BOOL isOutgoing = [msg.senderId isEqualToString:myId];
        [RBAvatarView removeAvatarFromImageView:avatarView];
        if (isOutgoing) {
            avatarView.image = outImg;
        } else if (is10001) {
            NSString *sourceUid = (msg.senderId.length > 0 && ![msg.senderId isEqualToString:@"0"]) ? msg.senderId : msg.quote_sender_uid;
            if (sourceUid.length > 0 && ![sourceUid isEqualToString:myId]) {
                // 收藏夹左侧头像由 cell 配置时走数据源统一处理（缓存+异步），此处不再覆盖，避免把已显示的头像又改成占位
                continue;
            } else {
                avatarView.image = outImg;
            }
        } else {
            avatarView.image = inImg;
        }
        avatarView.layer.cornerRadius = kJSQMessagesCollectionViewAvatarSizeDefault * 0.5f;
        avatarView.layer.masksToBounds = YES;
    }
}

/**
 * 逆初始化与该好友的聊天相关设置.
 * <p>
 * 本方法在资源回收时调用，是方法 {@link #initToFriend(RosterElementEntity)}的逆方法.
 */
- (void)deInitToFriend
{
    // 取消设置聊天消息数据模型观察者
    [self.chattingDatas removeObserver:self.chattingDatasObserver];
}

// @Override-重写父类方法：返回聊天列表的消息数据集合对象引用（含 10001，与普通单聊一致为 IM 会话列表）
- (NSMutableArray<JSQMessage *> *) getChattingDatasList
{
    return [self.chattingDatas getDataList];
}

/// 10001 收藏同步到服务端成功后刷新界面（消息已由 putMessage 写入会话，此处补一轮 layout 即可）
- (void)refresh10001FavoritesListIfNeeded
{
    if (![self.toId isEqualToString:@"10001"]) return;
    [self refreshCollectionView];
}

// 别的界面中对好友备注等信息更新完后，本界面中要做的事，这是通过通知实现的
- (void)friendRemarkChangedComplete:(NSNotification*)notification
{
    UserEntity *latestRee = (UserEntity *)notification.object;
    
    NSString *friendUid = latestRee.user_uid;
    NSString *friendNicknameWithRemark = [latestRee getNickNameWithRemark];
    DDLogDebug(@"【好友备注更新】聊天界面收到 (friendUid=%@，friendNicknameWithRemark=%@) 已修改完成的通知！", friendUid, friendNicknameWithRemark);
    
    if(friendUid != nil && [friendUid isEqualToString:self.toId]) {
        self.toName = friendNicknameWithRemark;
        [self rb_refreshChatNavTitle];
        DDLogDebug(@"【好友备注更新】当前聊天界面标题更新成功！");
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - Actions

// 标题栏右边“查看好友”按钮的点击事件处理
- (void)gotoFriendInfo:(UIBarButtonItem *)sender
{
    if (![[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster2:self.toId]) {
        // 已解除好友关系但消息列表仍保留时，右上资料入口直接进入资料页，资料页底部可直接「添加到通讯录」。
        [QueryFriendInfoAsync gotoWatchUserInfo:self.toId withInfo:nil nav:self.navigationController view:self.view vc:self addSource:@"chat_session"];
        return;
    }

    // 仍是好友时维持原来的聊天信息页入口。
    [ViewControllerFactory goChatInfoViewController:self.navigationController withUid:self.toId andNick:self.toName];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - kmMoreMenuViewDelegate（ “(+)更多”功能的item点击代理方法 ）

- (void)didSelecteMoreMenuItem:(kmMoreMenuItem *)shareMenuItem atIndex:(NSInteger)index
{
    switch (shareMenuItem.actionId)
    {
        // 发送图片消息（从图片）
        case MORE_ACTION_ID_IMAGE:
        {
            // 进入相册选择图片并发送图片消息
            [super.imagePickerWrapper takeAlbum:YES];
            break;
        }
        // 发送图片消息（从相机）
        case MORE_ACTION_ID_PHOTO:
        {
            // 进入相机拍照并发送图片消息
            [super.imagePickerWrapper takePhoto];
            break;
        }
        // 发送大文件消息（先收起键盘，避免关闭文件选择器后系统自动恢复输入框为第一响应者导致键盘弹出）
        case MORE_ACTION_ID_FILE:
        {
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            [super openFilePicker];
            break;
        }
        // 发送短视频消息
        case MORE_ACTION_ID_SHORTVIDEO:
        {
            [super openShortVideoRecorder];
            break;
        }
        // 发送位置消息
        case MORE_ACTION_ID_LOCATION:
        {
            [super openLocationChoose];
            break;
        }
        // 名片：更多面板收起后再弹 LPActionSheet（与红包/音视频一致）
        case MORE_ACTION_ID_CONTACT_MERGED:
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
        case MORE_ACTION_ID_CONTACT_FRIEND:
        {
            [super openUserChoose];
            break;
        }
        // 发送群名片消息
        case MORE_ACTION_ID_CONTACT_GROUP:
        {
            [super openGroupChoose];
            break;
        }
        // 语音/视频通话：须在悬浮更多面板 0.25s 收起完成后再弹 LPActionSheet（原先 0.2s 早于动画结束，弹窗会叠在菜单下层）
        case MORE_ACTION_ID_VOICE_VIDEO_CHAT:
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
        // 收藏（先收起键盘，避免关闭收藏选择器后系统自动恢复输入框为第一响应者导致键盘弹出）
        case MORE_ACTION_ID_FAVORITES:
        {
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            [self openFavoritesPicker];
            break;
        }
        // 红包：收起悬浮更多面板完成后再 push（避免与语音/视频相同的 0.2s < 0.25s 遮挡）
        case MORE_ACTION_ID_RED_PACKET:
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
                vc.initialPacketType = 1;  // 私信固定为普通红包
                vc.hidesBottomBarWhenPushed = YES;
                [s.navigationController pushViewController:vc animated:YES];
            }];
            return;
        }
        // 转账
        case MORE_ACTION_ID_TRANSFER:
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

    // 并关闭"(+)更多"功能面板
    [self hideBottomBoxAnim:YES];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - Collection view data source（消息列表数据源代理方法）

// @Override - 重写父类方法：单独的方法里处理头像显示逻辑，方便群聊子类界面中以更大的自由度实现自已的显示逻辑
// 特别说明：本方法的重写代码，陌生人、群聊、好友聊 3个子聊天界面的实现中，均保持一致，视未来的扩展，如果一直趋同，可考虑提炼到父类中重用之，尽可能减少代码冗余
- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath_avatar:(NSIndexPath *)indexPath withImageView:(UIImageView *)avatarView
{
    avatarView.layer.cornerRadius = kJSQMessagesCollectionViewAvatarSizeDefault * 0.5f;
    avatarView.layer.masksToBounds = YES;

    JSQMessage *entity = [[self getChattingDatasList] objectAtIndex:indexPath.item];
    UIImage *placeImg = [UIImage imageNamed:@"chat_avatar_default"];
    BOOL isOutgoing = [entity.senderId isEqualToString:self.senderId];

    if (isOutgoing) {
        [RBAvatarView removeAvatarFromImageView:avatarView];
        avatarView.image = (self.outgoingAvatarImage != nil ? self.outgoingAvatarImage : placeImg);
        return;
    }
    // 收藏夹（10001）左侧：必须走数据源，按 source_from_uid 取缓存/占位并触发异步拉取；本类重写里不再用 incomingAvatarImage（10001 未设）
    if ([self.toId isEqualToString:@"10001"]) {
        [RBAvatarView removeAvatarFromImageView:avatarView];
        UIImage *img = [collectionView.dataSource collectionView:collectionView avatarImageDataForItemAtIndexPath:indexPath];
        avatarView.image = (img != nil ? img : placeImg);
        return;
    }
    // 单聊仅两个头像，只用缓存或占位
    [RBAvatarView removeAvatarFromImageView:avatarView];
    avatarView.image = (self.incomingAvatarImage != nil ? self.incomingAvatarImage : placeImg);
}


//---------------------------------------------------------------------------------------------------
#pragma mark - Responding to collection view tap events

// 点击消息气泡边上的头像事件处理方法
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapAvatarImageView:(UIImageView *)avatarImageView atIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *entity = [[self getChattingDatasList] objectAtIndex:indexPath.item];
    if (entity == nil) return;

    // 点击的是本地用户头像（右侧气泡）
    if ([entity.senderId isEqualToString:self.senderId]) {
        [ViewControllerFactory goUserViewController:self.navigationController];
        return;
    }

    // 10001 收藏夹：左侧头像为“来源人”，只显示来源人资料；且仅当来源人与我方是好友时才跳转资料页，否则不跳转
    if ([self.toId isEqualToString:@"10001"]) {
        NSString *sourceUid = (entity.quote_sender_uid.length > 0) ? entity.quote_sender_uid : (entity.senderId.length > 0 && ![entity.senderId isEqualToString:@"0"] ? entity.senderId : nil);
        if (sourceUid.length == 0) return;
        NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        if (localUid != nil && [sourceUid isEqualToString:localUid]) {
            [ViewControllerFactory goUserViewController:self.navigationController];
            return;
        }
        FriendsListProvider *flp = [[IMClientManager sharedInstance] getFriendsListProvider];
        if (flp != nil && [flp isUserInRoster2:sourceUid]) {
            [QueryFriendInfoAsync gotoWatchUserInfo:sourceUid withInfo:nil nav:self.navigationController view:self.view vc:self];
        }
        return;
    }

    // 其它普通会话：跳转对方（toId）资料
    if ([BasicTool isOfficialAccountHideAvatarInChat:self.toId]) return;
    [QueryFriendInfoAsync gotoWatchUserInfo:self.toId withInfo:nil nav:self.navigationController view:self.view vc:self];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 其它方法

// 处理拉黑完成通知（通知聊天界面关闭，不然从聊天界面进来拉黑的话，拉黑完成又回到跟此人的聊天界面的话，体验就有点怪异了）
- (void) blockUserComplete:(NSNotification*)notification
{
    NSString *uidBeBlocked = (NSString *)notification.object;
    DDLogDebug(@"【好友聊天界面】-收到此人(%@)被拉黑的通知！", uidBeBlocked);

    if([self.toId isEqualToString:uidBeBlocked])
    {
        // 并在Toast消失时退出添加好友界面
        [self doBack:NO];
    }
}

@end
