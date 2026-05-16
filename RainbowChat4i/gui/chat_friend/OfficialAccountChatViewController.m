//
//  OfficialAccountChatViewController.m
//  RainbowChat4i
//
//  只读官方账号（10000、400069、400070）专用聊天页，样式与单聊一致，仅无输入栏与更多入口。
//

#import "OfficialAccountChatViewController.h"
#import "AlarmsViewController.h"
#import "Default.h"
#import "IMClientManager.h"
#import "ClientCoreSDK.h"
#import "Protocal.h"
#import "BasicTool.h"
#import "NotificationCenterFactory.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "AlarmType.h"
#import "JSQMessages.h"
#import "MessagesProvider.h"
#import "UserEntity.h"
#import "kmMoreMenuItem.h"
#import "ChatMessageModeMenu.h"
#import "ViewControllerFactory.h"
#import "LPActionSheet.h"

// 与 ChatViewController 的 MORE_ACTION_ID_* 一致，用于更多菜单（客服 400069 有输入栏时显示）
static const int kMoreActionIdImage = 1;
static const int kMoreActionIdPhoto = 2;
static const int kMoreActionIdFile = 6;
static const int kMoreActionIdLocation = 8;
static const int kMoreActionIdContactFriend = 9;
static const int kMoreActionIdContactMerged = 15;

@interface OfficialAccountChatViewController () <kmMoreMenuViewDelegate>
@property (nonatomic, retain) NSMutableArrayObservableEx *chattingDatas;
@property (strong, nonatomic) UIImage *outgoingAvatarImage;
@property (strong, nonatomic) UIImage *incomingAvatarImage;
/** 是否已触发 viewWillDisappear 但尚未触发 viewDidDisappear（用于识别右滑取消后再次 viewWillAppear，避免导航栏动画导致闪烁） */
@property (nonatomic, assign) BOOL oac_hadWillDisappearWithoutDid;
/// 在线客服 400069：顶栏仅搜索，不要「更多」
- (UIView *)rb_officialNavRightCapsuleOrSearchOnly;
@end

@implementation OfficialAccountChatViewController

- (void)rb_refreshOfficialNavTitle
{
    NSString *titleText = self.toName ?: @"";
    self.title = titleText;
    self.navigationItem.title = titleText;
    UILabel *titleLabel = self.rb_chromeNavigationBar.titleLabel;
    UIFont *titleFont = titleLabel.font ?: [UIFont boldSystemFontOfSize:17.0f];
    UIColor *titleColor = titleLabel.textColor ?: UI_DEFAULT_TITLE_FONT_COLOR;
    titleLabel.attributedText = [BasicTool attributedName:titleText
                                      appendOfficialBadge:[BasicTool isSystemAdmin:self.toId]
                                                     font:titleFont
                                                textColor:titleColor
                                              badgeHeight:14.0f];
}

- (instancetype)initWithUid:(NSString *)uid nickname:(NSString *)nickname
{
    if (self = [super initWithNibName:nil bundle:nil]) {
        self.chatType = CHAT_TYPE_FREIDN_CHAT;
        self.toId = uid;
        self.toName = nickname ?: uid;
    }
    return self;
}

- (UIView *)rb_officialNavRightCapsuleOrSearchOnly
{
    if ([self.toId isEqualToString:@"400069"]) {
        return [ChatMessageModeMenu navSearchOnlyButtonWithTarget:self action:@selector(onOfficialNavSearchTapped)];
    }
    return [ChatMessageModeMenu navSearchMoreCapsuleWithSearchTarget:self
                                                        searchAction:@selector(onOfficialNavSearchTapped)
                                                          moreTarget:self
                                                           moreAction:@selector(onOfficialNavMoreTapped)];
}

/// 自定义顶栏：只读无右侧；客服 400069 仅搜索；其它可发消息的官方号右侧为搜索｜更多胶囊
- (void)setupMinimalNavigationBar
{
    [super setupMinimalNavigationBar];
    self.navigationItem.prompt = nil;
    if ([BasicTool isReadOnlyOfficialAccount:self.toId]) {
        [self rb_clearChatCustomNavRightHost];
    } else {
        UIView *container = [self rb_officialNavRightCapsuleOrSearchOnly];
        [self rb_attachViewToChatCustomNavRight:container];
    }
    [self rb_refreshOfficialNavTitle];
}

/// 配置系统导航栏：仅用 UINavigationBar 的 blur，不叠 blurView、不设 backgroundColor，实现 iOS18 液态融合无分层
- (void)setupSystemLiquidNavigationBar
{
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    // 仅系统模糊，禁止设置 appearance.backgroundColor / navigationBar.backgroundColor
    appearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    appearance.shadowColor = nil;
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    self.navigationController.navigationBar.compactAppearance = appearance;
    self.navigationController.navigationBar.translucent = YES;
    // 确保没有块状背景导致分层
    self.navigationController.navigationBar.backgroundColor = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 官方账号对话列表不显示双方头像
    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    if ([flowLayout respondsToSelector:@selector(setIncomingAvatarViewSize:)]) {
        [(id)flowLayout setIncomingAvatarViewSize:CGSizeZero];
    }
    if ([flowLayout respondsToSelector:@selector(setOutgoingAvatarViewSize:)]) {
        [(id)flowLayout setOutgoingAvatarViewSize:CGSizeZero];
    }

    self.edgesForExtendedLayout = UIRectEdgeAll;
    [self setupMinimalNavigationBar];
    if (@available(iOS 11.0, *)) {
        self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    self.view.backgroundColor = [UIColor clearColor];
    self.collectionView.backgroundColor = [UIColor clearColor];
    [self initObservers];

    self.chattingDatas = [[[IMClientManager sharedInstance] getMessagesProvider] getMessages:self.toId];
    // 本类直接继承 ChatRootViewController，需主动调用首帧设置（气泡图 + reloadData），否则气泡无背景
    [self rb_deferredSetupAfterFirstFrame];
    // 保持透明，避免父类 applyChatBackground 等逻辑把 collectionView 设成实色导致导航栏交界分层
    self.collectionView.backgroundColor = [UIColor clearColor];
    // observer 在 viewWillAppear 中统一添加，与 ChatViewController 一致

    // 只读官方账号（10000、400070）隐藏输入框；客服 400069 保留输入框，允许发送
    if ([BasicTool isReadOnlyOfficialAccount:self.toId]) {
        self.inputToolbar.hidden = YES;
        self.toolbarHeightConstraint.constant = 0;
        [self.view setNeedsUpdateConstraints];
        [self.view layoutIfNeeded];
        [self jsq_updateCollectionViewInsets];
    }

    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [wself initAvatarImage];
    });
}

- (void)viewWillAppear:(BOOL)animated
{
    BOOL isReappearAfterCancelledPop = self.oac_hadWillDisappearWithoutDid;
    if (isReappearAfterCancelledPop) self.oac_hadWillDisappearWithoutDid = NO;
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
    [super viewWillAppear:animated];
    [IMClientManager sharedInstance].currentFrontChattingUserUID = self.toId;
    if (self.chattingDatas && self.chattingDatasObserver) {
        [self.chattingDatas removeObserver:self.chattingDatasObserver];
        [self.chattingDatas addObserver:self.chattingDatasObserver];
    }
    if (self.rb_initialSessionUnreadCount <= 0) {
        AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
        int idx = ap ? [ap getAlarmIndex:AMT_friendChatMessage dataId:self.toId] : -1;
        if (idx >= 0) {
            self.rb_initialSessionUnreadCount = [ap getFlagNum:idx];
        }
    }
    [[[IMClientManager sharedInstance] getAlarmsProvider] resetFlagNum:AMT_friendChatMessage dataId:self.toId flagNumToReset:0 needUpdateSqlite:YES];
    [NotificationCenterFactory refreshMainPageTotalUnread_POST];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
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

- (void)viewDidDisappear:(BOOL)animated
{
    self.oac_hadWillDisappearWithoutDid = NO;
    [IMClientManager sharedInstance].currentFrontChattingUserUID = nil;
    if (self.chattingDatas && self.chattingDatasObserver) {
        [self.chattingDatas removeObserver:self.chattingDatasObserver];
    }
    if ((self.isMovingFromParentViewController || self.isBeingDismissed) && self.navigationController.navigationBarHidden) {
        UIViewController *top = self.navigationController.topViewController;
        if (![top isKindOfClass:[AlarmsViewController class]]) {
            [self.navigationController setNavigationBarHidden:NO animated:NO];
        }
    }
    [super viewDidDisappear:animated];
}

- (void)deallocImpl
{
    [super deallocImpl];
    [self deInitToFriend];
}

- (void)rb_deferredSetupCustomNavigationBar
{
    [self rb_refreshOfficialNavTitle];
}

- (void)rb_didSetupCustomNavigationBar
{
    self.navigationItem.prompt = nil;
    if ([BasicTool isReadOnlyOfficialAccount:self.toId]) {
        [self rb_clearChatCustomNavRightHost];
        self.navAvatarButton = nil;
        self.navAvatarImageView = nil;
    } else {
        UIView *container = [self rb_officialNavRightCapsuleOrSearchOnly];
        [self rb_attachViewToChatCustomNavRight:container];
        self.navAvatarButton = nil;
        self.navAvatarImageView = nil;
    }
    [self rb_refreshOfficialNavTitle];
}

- (void)onOfficialNavSearchTapped
{
    [self showChatSearchBarAnimated:YES];
}

- (void)onOfficialNavMoreTapped
{
    UserEntity *peer = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:self.toId];
    if (peer) {
        [ViewControllerFactory goFriendInfoViewController:self.navigationController withDatas:peer canOpenChat:NO];
    } else {
        [BasicTool showAlertInfo:@"暂无账号资料" parent:self];
    }
}

- (UIBarButtonItem *)customRightBarButtonItemForRestore
{
    if ([BasicTool isReadOnlyOfficialAccount:self.toId]) {
        return nil;
    }
    UIView *container = [self rb_officialNavRightCapsuleOrSearchOnly];
    return [[UIBarButtonItem alloc] initWithCustomView:container];
}

- (void)rb_deferredSetupAfterFirstFrame
{
    [super rb_deferredSetupAfterFirstFrame];
}

/// 初始化「+」更多面板（仅客服 400069 有输入栏，只读官方 10000/400070 无输入栏不显示加号）
- (void)initMoreContentView
{
    self.bottomBoxMoreView.delegate = self;
    NSMutableArray *moreMenuItems = [NSMutableArray array];
    [moreMenuItems addObject:[[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_img"] highlightIconImage:[UIImage imageNamed:@"chatting_more_func_img"] title:@"照片" actionId:kMoreActionIdImage]];
    [moreMenuItems addObject:[[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_camra"] highlightIconImage:[UIImage imageNamed:@"chatting_more_func_camra"] title:@"拍摄" actionId:kMoreActionIdPhoto]];
    [moreMenuItems addObject:[[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_file"] highlightIconImage:[UIImage imageNamed:@"chatting_more_func_file"] title:@"文件" actionId:kMoreActionIdFile]];
    [moreMenuItems addObject:[[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_location"] highlightIconImage:[UIImage imageNamed:@"chatting_more_func_location"] title:@"位置" actionId:kMoreActionIdLocation]];
    [moreMenuItems addObject:[[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_user"] highlightIconImage:[UIImage imageNamed:@"chatting_more_func_user"] title:@"名片" actionId:kMoreActionIdContactMerged]];
    self.bottomBoxMoreView.shareMenuItems = moreMenuItems;
}

- (void)didSelecteMoreMenuItem:(kmMoreMenuItem *)shareMenuItem atIndex:(NSInteger)index
{
    switch (shareMenuItem.actionId) {
        case kMoreActionIdImage:
            [self.imagePickerWrapper takeAlbum:YES];
            break;
        case kMoreActionIdPhoto:
            [self.imagePickerWrapper takePhoto];
            break;
        case kMoreActionIdFile:
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            [self openFilePicker];
            break;
        case kMoreActionIdLocation:
            [self openLocationChoose];
            break;
        case kMoreActionIdContactMerged:
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
                    if (index == 1) [ss openUserChoose];
                    else if (index == 2) [ss openGroupChoose];
                }];
            }];
            return;
        }
        case kMoreActionIdContactFriend:
            [self openUserChoose];
            break;
        default:
            [BasicTool showAlertInfo:@"此功能暂未开放，敬请关注！" parent:self];
            break;
    }
    [self hideBottomBoxAnim:YES];
}

- (NSMutableArray<JSQMessage *> *)getChattingDatasList
{
    return [self.chattingDatas getDataList];
}

/// 返回我方/对方头像，使列表显示真实头像而非占位图（基类对 incoming 固定返回占位图）
- (UIImage *)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *list = [self getChattingDatasList];
    if (indexPath.item >= list.count) return nil;
    JSQMessage *entity = list[indexPath.item];
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    BOOL isOutgoing = (localUid != nil && [entity.senderId isEqualToString:localUid]);
    UIImage *placeImg = [UIImage imageNamed:@"default_avatar_60"];
    if (isOutgoing) {
        return self.outgoingAvatarImage ?: placeImg;
    }
    return self.incomingAvatarImage ?: placeImg;
}

- (void)initAvatarImage
{
    __weak typeof(self) wself = self;
    self.outgoingAvatarImage = nil;
    self.incomingAvatarImage = nil;

    UserEntity *curUser = [IMClientManager sharedInstance].localUserInfo;
    UserEntity *peer = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:self.toId];
    NSString *partnerFileName = peer ? peer.userAvatarFileName : nil;

    if (curUser && ![BasicTool isStringEmpty:curUser.userAvatarFileName]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *path = [FileDownloadHelper getUserAvatarDownloadURLExt:YES fileName:curUser.userAvatarFileName uid:curUser.user_uid];
            UIImage *img = [FileDownloadHelper loadUserAvatarFromCacheOnly:path donotLoadFromDisk:NO];
            if (img == nil) {
                [FileDownloadHelper loadUserAvatarWithFileName:curUser.userAvatarFileName uid:curUser.user_uid logTag:@"OfficialChat-OutAvatar" complete:^(BOOL succ, UIImage *img) {
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

    // 对方头像：有 fileName 用 fileName 拉取，无则用 uid 拉取（官方账号可能不在好友列表或暂无 userAvatarFileName）
    if (self.toId.length > 0 && ![FileDownloadHelper isVideoAvatarFileName:partnerFileName]) {
        NSString *fileName = (partnerFileName.length > 0) ? partnerFileName : nil;
        NSString *uid = self.toId;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage *img = nil;
            if (fileName.length > 0) {
                NSString *path = [FileDownloadHelper getUserAvatarDownloadURLExt:YES fileName:fileName uid:uid];
                img = [FileDownloadHelper loadUserAvatarFromCacheOnly:path donotLoadFromDisk:NO];
            }
            if (img == nil) {
                [FileDownloadHelper loadUserAvatarIntelligent:fileName uid:uid logTag:@"OfficialChat-InAvatar" complete:^(BOOL succ, UIImage *img) {
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

- (void)deInitToFriend
{
    [self.chattingDatas removeObserver:self.chattingDatasObserver];
}

/// 仅更新当前可见 cell 的头像，与 ChatViewController 逻辑一致（官方账号非 10001，无收藏夹分支）
- (void)rb_updateVisibleAvatarImages
{
    if (!self.collectionView.window) return;
    NSArray *list = [self getChattingDatasList];
    if (!list.count) return;
    UIImage *outImg = self.outgoingAvatarImage ?: [UIImage imageNamed:@"chat_avatar_default"];
    UIImage *inImg = self.incomingAvatarImage ?: [UIImage imageNamed:@"chat_avatar_default"];
    NSString *myId = self.senderId ?: @"";
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
        avatarView.image = isOutgoing ? outImg : inImg;
        avatarView.layer.cornerRadius = kJSQMessagesCollectionViewAvatarSizeDefault * 0.5f;
        avatarView.layer.masksToBounds = YES;
    }
}

@end
