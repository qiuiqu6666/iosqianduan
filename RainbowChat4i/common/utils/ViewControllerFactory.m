//telegram @wz662
#import "ViewControllerFactory.h"
#import "ChatViewController.h"
#import "OfficialAccountChatViewController.h"
#import "FavoritesChatViewController.h"
#import "WebViewController.h"
#import "FindFriendViewController.h"
#import "FindFriendResultViewController.h"
#import "FriendInfoViewController.h"
#import "FriendReqSendViewController.h"
#import "RegisterViewController.h"
#import "ForgetPasswordViewController.h"
#import "InviteFriendViewController.h"
#import "FriendsReqViewController.h"
#import "FriendReqProcessViewController.h"
#import "UserViewController.h"
#import "UserEditViewController.h"
#import "AboutViewController.h"
#import "GroupChattingViewController.h"
#import "GroupInfoViewController.h"
#import "GroupEntity.h"
#import "GroupInfoEditViewController.h"
#import "TempChatViewController.h"
#import "VoicesViewController.h"
#import "BigFileViewerController.h"
#import "ShortVideoRecordViewController.h"
#import "ReceivedShortVideoHelper.h"
#import "GroupsViewController.h"
#import "JoinGroupViewController.h"
#import "QRCodeGenerateViewController.h"
#import "IMClientManager.h"
#import "QRCodeScheme.h"
#import "SearchViewController.h"
#import "AIViewController.h"
#import "MomentViewController.h"
#import "NearbyViewController.h"
#import "SettingsViewController.h"
#import "SettingsAccountSecurityViewController.h"
#import "SettingsFriendPermissionViewController.h"
#import "SettingsNotificationViewController.h"
#import "SettingsDisplayViewController.h"
#import "SettingsStorageViewController.h"
#import "SettingsDeviceRecordViewController.h"
#import "ModifyPhoneViewController.h"
#import "ModifyEmailViewController.h"
#import "BasicTool.h"
#import "ChatRootViewController.h"
#import "CallViewController.h"
#import "AppDelegate.h"
#import "ChatSearchMenuViewController.h"
#import "MessageSearch10001ViewController.h"
#import "JSQMessagesViewController.h"
#import "JSQMessagesBubbleImageFactory.h"

@implementation ViewControllerFactory

/// 聊天页 NIB 预加热：仅执行一次，下一 Run Loop 在主线程加载临时 VC 并释放，使系统解码 NIB，下次 push 时可能命中缓存（秒显优化：去掉 1 秒延迟）
+ (void)warmChatNibOnce
{
    static BOOL s_hasWarmed = NO;
    if (s_hasWarmed) return;
    s_hasWarmed = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        JSQMessagesViewController *dummy = [[JSQMessagesViewController alloc] initWithNibName:NSStringFromClass([JSQMessagesViewController class]) bundle:[NSBundle bundleForClass:[JSQMessagesViewController class]]];
        [dummy loadViewIfNeeded];
        (void)dummy;
    });
}

#pragma mark - 气泡图预创建（秒显：首帧一次 reload，无占位→真实闪烁）

static JSQMessagesBubbleImage *s_sharedOutgoingBubble = nil;
static JSQMessagesBubbleImage *s_sharedOutgoingBubbleLight = nil;
static JSQMessagesBubbleImage *s_sharedIncomingBubble = nil;
static JSQMessagesBubbleImage *s_sharedOutgoingBubbleLightWithoutTail = nil;
static JSQMessagesBubbleImage *s_sharedIncomingBubbleWithoutTail = nil;

+ (void)warmChatBubbleImagesOnce
{
    if (s_sharedOutgoingBubble != nil) return;
    JSQMessagesBubbleImageFactory *factory = [[JSQMessagesBubbleImageFactory alloc] init];
    s_sharedOutgoingBubble = [factory outgoingMessagesBubbleImage];
    s_sharedOutgoingBubbleLight = [factory outgoingMessagesBubbleImage_wechatGreen];
    s_sharedIncomingBubble = [factory incomingMessagesBubbleImage_white];
    s_sharedOutgoingBubbleLightWithoutTail = [factory outgoingMessagesBubbleImage_wechatGreenWithoutTail];
    s_sharedIncomingBubbleWithoutTail = [factory incomingMessagesBubbleImage_whiteWithoutTail];
}

+ (void)getSharedBubbleImagesOutgoing:(JSQMessagesBubbleImage * _Nullable * _Nullable)outgoing outgoingLight:(JSQMessagesBubbleImage * _Nullable * _Nullable)outgoingLight incoming:(JSQMessagesBubbleImage * _Nullable * _Nullable)incoming
{
    if (s_sharedOutgoingBubble == nil) {
        [self warmChatBubbleImagesOnce];
    }
    if (outgoing) *outgoing = s_sharedOutgoingBubble;
    if (outgoingLight) *outgoingLight = s_sharedOutgoingBubbleLight;
    if (incoming) *incoming = s_sharedIncomingBubble;
}

+ (void)getSharedBubbleImagesWithoutTailOutgoing:(JSQMessagesBubbleImage * _Nullable * _Nullable)outgoing incoming:(JSQMessagesBubbleImage * _Nullable * _Nullable)incoming
{
    if (s_sharedOutgoingBubble == nil) {
        [self warmChatBubbleImagesOnce];
    }
    if (outgoing) *outgoing = s_sharedOutgoingBubbleLightWithoutTail;
    if (incoming) *incoming = s_sharedIncomingBubbleWithoutTail;
}

// 进入用户注册界面
+ (void)goRegisterViewController:(UINavigationController *)navigationController needSMS:(BOOL)needSMS phone:(NSString *)phone sms:(NSString *)sms
{
    RegisterViewController *vc = [[RegisterViewController alloc] initWithNibName:@"RegisterViewController" bundle:nil needSMS:needSMS phone:phone sms:sms];
    [navigationController pushViewController:vc animated:YES];
}

// 进入“邀请朋友”界面
+ (void)goInviteFriendViewController:(UINavigationController *)navigationController withMail:(NSString *)mail
{
    InviteFriendViewController *vc = [[InviteFriendViewController alloc] initWithNibName:@"InviteFriendViewController" bundle:nil withMail:mail];
    [navigationController pushViewController:vc animated:YES];
}

// 进入"验证通知"界面
+ (void)goVerificationsViewController:(UINavigationController *)navigationController
{
    FriendsReqViewController *vc = [[FriendsReqViewController alloc] initWithNibName:@"FriendsReqViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 进入加好友请求处理界面
+ (void)goFriendReqProcessViewController:(UINavigationController *)navigationController withDatas:(UserEntity *)userInfo
{
    FriendReqProcessViewController *vc = [[FriendReqProcessViewController alloc] initWithNibName:@"FriendReqProcessViewController" bundle:nil withDatas:userInfo];
    [navigationController pushViewController:vc animated:YES];
}

// 进入“忘记密码”界面
+ (void)goForgetPasswordViewController:(UINavigationController *)navigationController
{
    ForgetPasswordViewController *vc = [[ForgetPasswordViewController alloc] initWithNibName:@"ForgetPasswordViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 打开一个网页界面
+ (void)goWebViewController:(NSString *)webURL title:(NSString *)title toNav:(UINavigationController *)navigationController
{
    WebViewController* webView = [[WebViewController alloc] initWithNibName:@"WebViewController" bundle:nil];
    webView.webUrl = webURL;
    webView.title = title;
    [navigationController pushViewController:webView animated:YES];
}

// 栈顶最多检查层数，避免栈很深时 O(n) 遍历拖慢进入聊天页
static const NSInteger kMaxStackSearchForExistingChat = 12;

/// 会话列表等页面会隐藏系统导航栏（自定义顶栏）。在 push/回到已有聊天前预先显示系统栏，
/// 避免转场动画全程看不到顶部导航。
static void rbEnsureNavigationBarVisibleBeforeChatTransition(UINavigationController *nav)
{
    if (!nav || !nav.navigationBarHidden) {
        return;
    }
    [nav setNavigationBarHidden:NO animated:NO];
}

// 进入一对一好友聊天界面
+ (void)goChatViewController:(NSString *)friendUid andNickname:(NSString *)friendNickname toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *)highlightOnceMsgFingerprint
{
    [self goChatViewController:friendUid
                  andNickname:friendNickname
                        toNav:navigationController
               popToRootFirst:popToRoot
                    highlight:highlightOnceMsgFingerprint
            anchorMessageDate:nil];
}

+ (void)goChatViewController:(NSString *)friendUid andNickname:(NSString *)friendNickname toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *)anchorMessageDate
{
    // 收藏夹 10001：进入专用页面，减轻首帧与单聊/群聊共用 ChatViewController 的开销
    if ([friendUid isEqualToString:@"10001"]) {
        [self goFavoritesChatViewController:navigationController
                           popToRootFirst:popToRoot
                                highlight:highlightOnceMsgFingerprint
                        anchorMessageDate:anchorMessageDate];
        return;
    }

    [ChatRootViewController rb_syncPendingSearchJumpHighlightFingerprint:highlightOnceMsgFingerprint fpForUid:friendUid];
    [ChatRootViewController rb_syncPendingSearchJumpAnchorMessageDate:anchorMessageDate forUid:friendUid];

    // 当来自搜索结果（highlightOnceMsgFingerprint非空）时，不pop到已有的聊天界面，
    // 而是push新实例，确保按返回键能回到搜索页面
    if ([BasicTool isStringEmpty:highlightOnceMsgFingerprint]) {
        NSArray *stack = navigationController.viewControllers;
        NSInteger count = stack.count;
        // 从栈顶往栈底只查最近 kMaxStackSearchForExistingChat 层，减轻栈深时的延迟
        for (NSInteger i = count - 1; i >= 0 && (count - 1 - i) < kMaxStackSearchForExistingChat; i--) {
            UIViewController *vc = stack[i];
            if ([vc isKindOfClass:[ChatViewController class]]) {
                ChatViewController *old = (ChatViewController*)vc;
                if (old.toId != nil && [old.toId isEqualToString:friendUid]) {
                    rbEnsureNavigationBarVisibleBeforeChatTransition(navigationController);
                    [navigationController popToViewController:vc animated:YES];
                    return;
                }
            }
        }
    }
    
    // 先回到栈顶
    if(popToRoot) {
        [navigationController popToRootViewControllerAnimated:NO];
    }
    
    ChatViewController *vcNew = [[ChatViewController alloc] initWithNibName:nil bundle:nil chatWith:friendUid andNickname:friendNickname];
    vcNew.highlightOnceMsgFingerprint = highlightOnceMsgFingerprint;
    vcNew.highlightAnchorMessageDate = anchorMessageDate;
//  vcNew.hidesBottomBarWhenPushed = YES;
    // 再进入聊天界面
    rbEnsureNavigationBarVisibleBeforeChatTransition(navigationController);
    if (![BasicTool isStringEmpty:highlightOnceMsgFingerprint]) {
        NSLog(@"【RB-SEARCH-JUMP】Factory PUSH ChatViewController uid=%@ fp=%@", friendUid, [BasicTool trim:highlightOnceMsgFingerprint]);
    }
    [navigationController pushViewController:vcNew animated:YES];
}

// 进入收藏夹（10001）专用聊天页
+ (void)goFavoritesChatViewController:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *)highlightOnceMsgFingerprint
{
    [self goFavoritesChatViewController:navigationController
                        popToRootFirst:popToRoot
                             highlight:highlightOnceMsgFingerprint
                     anchorMessageDate:nil];
}

+ (void)goFavoritesChatViewController:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *)anchorMessageDate
{
    [ChatRootViewController rb_syncPendingSearchJumpHighlightFingerprint:highlightOnceMsgFingerprint fpForUid:@"10001"];
    [ChatRootViewController rb_syncPendingSearchJumpAnchorMessageDate:anchorMessageDate forUid:@"10001"];

    if ([BasicTool isStringEmpty:highlightOnceMsgFingerprint]) {
        NSArray *stack = navigationController.viewControllers;
        NSInteger count = stack.count;
        for (NSInteger i = count - 1; i >= 0 && (count - 1 - i) < kMaxStackSearchForExistingChat; i--) {
            UIViewController *vc = stack[i];
            if ([vc isKindOfClass:[FavoritesChatViewController class]]) {
                rbEnsureNavigationBarVisibleBeforeChatTransition(navigationController);
                [navigationController popToViewController:vc animated:YES];
                return;
            }
        }
    }
    if (popToRoot) {
        [navigationController popToRootViewControllerAnimated:NO];
    }
    FavoritesChatViewController *vcNew = [[FavoritesChatViewController alloc] initWithHighlight:highlightOnceMsgFingerprint];
    vcNew.highlightAnchorMessageDate = anchorMessageDate;
    rbEnsureNavigationBarVisibleBeforeChatTransition(navigationController);
    if (![BasicTool isStringEmpty:highlightOnceMsgFingerprint]) {
        NSLog(@"【RB-SEARCH-JUMP】Factory PUSH Favorites fp=%@", [BasicTool trim:highlightOnceMsgFingerprint]);
    }
    [navigationController pushViewController:vcNew animated:YES];
}

// 进入只读官方账号聊天界面（10000、400069、400070），样式与单聊一致，仅无输入栏
+ (void)goOfficialAccountChatViewController:(NSString *)uid nickname:(NSString *)nickname toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *)highlightOnceMsgFingerprint
{
    [self goOfficialAccountChatViewController:uid
                                     nickname:nickname
                                        toNav:navigationController
                               popToRootFirst:popToRoot
                                    highlight:highlightOnceMsgFingerprint
                            anchorMessageDate:nil];
}

+ (void)goOfficialAccountChatViewController:(NSString *)uid nickname:(NSString *)nickname toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *)anchorMessageDate
{
    if ([BasicTool isStringEmpty:uid]) return;

    [ChatRootViewController rb_syncPendingSearchJumpHighlightFingerprint:highlightOnceMsgFingerprint fpForUid:uid];
    [ChatRootViewController rb_syncPendingSearchJumpAnchorMessageDate:anchorMessageDate forUid:uid];

    if ([BasicTool isStringEmpty:highlightOnceMsgFingerprint]) {
        NSArray *stack = navigationController.viewControllers;
        NSInteger count = stack.count;
        for (NSInteger i = count - 1; i >= 0 && (count - 1 - i) < kMaxStackSearchForExistingChat; i--) {
            UIViewController *vc = stack[i];
            if ([vc isKindOfClass:[OfficialAccountChatViewController class]]) {
                OfficialAccountChatViewController *old = (OfficialAccountChatViewController *)vc;
                if (old.toId != nil && [old.toId isEqualToString:uid]) {
                    rbEnsureNavigationBarVisibleBeforeChatTransition(navigationController);
                    [navigationController popToViewController:vc animated:YES];
                    return;
                }
            }
        }
    }
    if (popToRoot) {
        [navigationController popToRootViewControllerAnimated:NO];
    }
    OfficialAccountChatViewController *vcNew = [[OfficialAccountChatViewController alloc] initWithUid:uid nickname:nickname];
    vcNew.highlightOnceMsgFingerprint = highlightOnceMsgFingerprint;
    vcNew.highlightAnchorMessageDate = anchorMessageDate;
    rbEnsureNavigationBarVisibleBeforeChatTransition(navigationController);
    if (![BasicTool isStringEmpty:highlightOnceMsgFingerprint]) {
        NSLog(@"【RB-SEARCH-JUMP】Factory PUSH Official uid=%@ fp=%@", uid, [BasicTool trim:highlightOnceMsgFingerprint]);
    }
    [navigationController pushViewController:vcNew animated:YES];
}

/**
 进入一对一陌生人/临时聊天界面

 @param guestUid guestUid description
 @param guestName guestName description
 @param maxFriend 当<=0时，数据解析者将忽略本参数（表示无效）
 @param navigationController navigationController description
 */
+ (void)goTempChatViewController:(NSString *)guestUid guestName:(NSString *)guestName maxFriend:(int)maxFriend toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *)highlightOnceMsgFingerprint
{
    [self goTempChatViewController:guestUid
                         guestName:guestName
                         maxFriend:maxFriend
                             toNav:navigationController
                    popToRootFirst:popToRoot
                         highlight:highlightOnceMsgFingerprint
                 anchorMessageDate:nil];
}

+ (void)goTempChatViewController:(NSString *)guestUid guestName:(NSString *)guestName maxFriend:(int)maxFriend toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *)anchorMessageDate
{
    [ChatRootViewController rb_syncPendingSearchJumpHighlightFingerprint:highlightOnceMsgFingerprint fpForUid:guestUid];
    [ChatRootViewController rb_syncPendingSearchJumpAnchorMessageDate:anchorMessageDate forUid:guestUid];

    // 当来自搜索结果（highlightOnceMsgFingerprint非空）时，不pop到已有的聊天界面，
    // 而是push新实例，确保按返回键能回到搜索页面
    if ([BasicTool isStringEmpty:highlightOnceMsgFingerprint]) {
        NSArray *stack = navigationController.viewControllers;
        NSInteger count = stack.count;
        for (NSInteger i = count - 1; i >= 0 && (count - 1 - i) < kMaxStackSearchForExistingChat; i--) {
            UIViewController *vc = stack[i];
            if ([vc isKindOfClass:[TempChatViewController class]]) {
                TempChatViewController *old = (TempChatViewController*)vc;
                if (old.toId != nil && [old.toId isEqualToString:guestUid]) {
                    rbEnsureNavigationBarVisibleBeforeChatTransition(navigationController);
                    [navigationController popToViewController:vc animated:YES];
                    return;
                }
            }
        }
    }
    
    // 先回到栈顶
    if(popToRoot) {
        [navigationController popToRootViewControllerAnimated:NO];
    }
    
    TempChatViewController *vcNew = [[TempChatViewController alloc] initWithNibName:nil bundle:nil guestUid:guestUid guestName:guestName maxFriend:maxFriend];
    vcNew.highlightOnceMsgFingerprint = highlightOnceMsgFingerprint;
    vcNew.highlightAnchorMessageDate = anchorMessageDate;
//  vcNew.hidesBottomBarWhenPushed = YES;
    // 再进入聊天界面
    rbEnsureNavigationBarVisibleBeforeChatTransition(navigationController);
    if (![BasicTool isStringEmpty:highlightOnceMsgFingerprint]) {
        NSLog(@"【RB-SEARCH-JUMP】Factory PUSH TempChat guest=%@ fp=%@", guestUid, [BasicTool trim:highlightOnceMsgFingerprint]);
    }
    [navigationController pushViewController:vcNew animated:YES];
}

// 进入查找好友界面
+ (void)goFindFriendViewController:(UINavigationController *)navigationController
{
    FindFriendViewController *vc = [[FindFriendViewController alloc] initWithNibName:@"FindFriendViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 进入“查找好友”结果查看界面
//+ (void)goFindFriendResultViewController:(NSArray<RosterElementEntity *> *)usersList toNav:(UINavigationController *)navigationController
+ (void)goFindFriendResultViewController:(NSString *)sexCondition withOnlineCondition:(NSString *)onlineStatus toNav:(UINavigationController *)navigationController
{
    FindFriendResultViewController *vc = [[FindFriendResultViewController alloc] initWithNibName:nil bundle:nil withSexCondition:sexCondition withOnlineCondition:onlineStatus];
    [navigationController pushViewController:vc animated:YES];
}

// 进入个人信息查看界面
+ (void)goFriendInfoViewController:(UINavigationController *)navigationController withDatas:(UserEntity *)userInfo canOpenChat:(BOOL)canOpenChat
{
    [self goFriendInfoViewController:navigationController withDatas:userInfo canOpenChat:canOpenChat addSource:nil];
}

// 进入个人信息查看界面（带添加来源透传）
+ (void)goFriendInfoViewController:(UINavigationController *)navigationController withDatas:(UserEntity *)userInfo canOpenChat:(BOOL)canOpenChat addSource:(NSString *)addSource
{
    [self goFriendInfoViewController:navigationController withDatas:userInfo canOpenChat:canOpenChat addSource:addSource groupMemberInfo:nil];
}

// 进入个人信息查看界面（带群成员信息，用于显示入群时间和邀请人）
+ (void)goFriendInfoViewController:(UINavigationController *)navigationController withDatas:(UserEntity *)userInfo canOpenChat:(BOOL)canOpenChat addSource:(NSString *)addSource groupMemberInfo:(GroupMemberEntity *)memberInfo
{
    FriendInfoViewController *vc = [[FriendInfoViewController alloc] initWithDatas:userInfo canOpenChat:canOpenChat];
    vc.addSource = addSource;
    vc.groupMemberInfo = memberInfo;
    [navigationController pushViewController:vc animated:YES];
}

// 进入发出好友请求界面
+ (void)goFriendReqSendViewController:(UINavigationController *)navigationController withDatas:(UserEntity *)userInfo addSource:(NSString *)addSource
{
    FriendReqSendViewController *vc = [[FriendReqSendViewController alloc] initWithNibName:@"FriendReqSendViewController" bundle:nil withDatas:userInfo addSource:addSource];
    [navigationController pushViewController:vc animated:YES];
}

// 进入本地用户的"关于我们"查看界面
+ (void)goAboutViewController:(UINavigationController *)navigationController
{
    AboutViewController *vc = [[AboutViewController alloc] init];
    [navigationController pushViewController:vc animated:YES];
}

// 进入本地用户的"个人信息"查看界面
+ (void)goUserViewController:(UINavigationController *)navigationController
{
    UserViewController *vc = [[UserViewController alloc] initWithNibName:@"UserViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 进入"个人信息"的相关编辑界面
+ (void)goUserEditViewController:(UINavigationController *)navigationController withChangeType:(int)changeType
{
    UserEditViewController *vc = [[UserEditViewController alloc] initWithNibName:@"UserEditViewController" bundle:nil withChangeType:changeType];
    [navigationController pushViewController:vc animated:YES];
}

// 进入世界频道或群聊聊天界面
+ (void)goGroupChattingViewController:(UINavigationController *)navigationController gid:(NSString *)gid gname:(NSString *)gname animated:(BOOL)animated popToRootFirst:(BOOL)popToRoot highlight:(NSString *)highlightOnceMsgFingerprint
{
    [self goGroupChattingViewController:navigationController
                                    gid:gid
                                  gname:gname
                               animated:animated
                         popToRootFirst:popToRoot
                              highlight:highlightOnceMsgFingerprint
                      anchorMessageDate:nil];
}

+ (void)goGroupChattingViewController:(UINavigationController *)navigationController gid:(NSString *)gid gname:(NSString *)gname animated:(BOOL)animated popToRootFirst:(BOOL)popToRoot highlight:(NSString *)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *)anchorMessageDate
{
    [ChatRootViewController rb_syncPendingSearchJumpHighlightFingerprint:highlightOnceMsgFingerprint fpForUid:gid];
    [ChatRootViewController rb_syncPendingSearchJumpAnchorMessageDate:anchorMessageDate forUid:gid];

    // 当来自搜索结果（highlightOnceMsgFingerprint非空）时，不pop到已有的聊天界面，
    // 而是push新实例，确保按返回键能回到搜索页面
    if ([BasicTool isStringEmpty:highlightOnceMsgFingerprint]) {
        NSArray *stack = navigationController.viewControllers;
        NSInteger count = stack.count;
        for (NSInteger i = count - 1; i >= 0 && (count - 1 - i) < kMaxStackSearchForExistingChat; i--) {
            UIViewController *vc = stack[i];
            if ([vc isKindOfClass:[GroupChattingViewController class]]) {
                GroupChattingViewController *old = (GroupChattingViewController*)vc;
                if (old.toId != nil && [old.toId isEqualToString:gid]) {
                    rbEnsureNavigationBarVisibleBeforeChatTransition(navigationController);
                    [navigationController popToViewController:vc animated:animated];
                    return;
                }
            }
        }
    }
    
    // 先回到栈顶
    if(popToRoot) {
        [navigationController popToRootViewControllerAnimated:NO];
    }
    
    GroupChattingViewController *vcNew =[[GroupChattingViewController alloc] initWithNibName:nil bundle:nil gid:gid gname:gname];
    vcNew.highlightOnceMsgFingerprint = highlightOnceMsgFingerprint;
    vcNew.highlightAnchorMessageDate = anchorMessageDate;
    
//  vcNew.hidesBottomBarWhenPushed = YES;
    // 再进入聊天界面
    rbEnsureNavigationBarVisibleBeforeChatTransition(navigationController);
    if (![BasicTool isStringEmpty:highlightOnceMsgFingerprint]) {
        NSLog(@"【RB-SEARCH-JUMP】Factory PUSH Group gid=%@ fp=%@", gid, [BasicTool trim:highlightOnceMsgFingerprint]);
    }
    [navigationController pushViewController:vcNew animated:animated];//YES
}

// 进入群信息查看界面
+ (void)goGroupInfoViewController:(UINavigationController *)navigationController withDatas:(GroupEntity *)groupInfo
{
    GroupInfoViewController *vc = [[GroupInfoViewController alloc] initWithDatas:groupInfo];
    [navigationController pushViewController:vc animated:YES];
}

// 进入"群信息"的相关编辑界面
+ (GroupInfoEditViewController *)goGroupInfoEditViewController:(UINavigationController *)navigationController withChangeType:(int)changeType andGroupInfo:(GroupEntity *)groupInfo
{
    GroupInfoEditViewController *vc = [[GroupInfoEditViewController alloc] initWithChangeType:changeType andGroupInfo:groupInfo];
    [navigationController pushViewController:vc animated:YES];

    return vc;
}

// 进入群成员查看、群成员管理、建群等操作界面
+ (GroupMemberViewController *)goGroupMemberViewController:(UINavigationController *)navigationController usedFor:(int)usedFor gid:(NSString *)gid isGroupOwner:(BOOL)isGroupOwner defaultSelectedUid:(NSString *)defaultSelectedUid
{
    return [self goGroupMemberViewController:navigationController usedFor:usedFor gid:gid isGroupOwner:isGroupOwner defaultSelectedUid:defaultSelectedUid memberPrivacy:0];
}

+ (GroupMemberViewController *)goGroupMemberViewController:(UINavigationController *)navigationController usedFor:(int)usedFor gid:(NSString *)gid isGroupOwner:(BOOL)isGroupOwner defaultSelectedUid:(NSString *)defaultSelectedUid memberPrivacy:(int)memberPrivacy
{
    GroupMemberViewController *vc = [[GroupMemberViewController alloc] initWithNibName:@"GroupMemberViewController" bundle:nil usedFor:usedFor gid:gid isGroupOwner:isGroupOwner defaultSelectedUid:defaultSelectedUid];
    vc.groupMemberPrivacy = memberPrivacy;
    [navigationController pushViewController:vc animated:YES];
    return vc;
}

// 进入"个人相册"查看界面
+ (void)goPhotosViewController:(UINavigationController *)navigationController withUid:(NSString *)photoOfUid canMgr:(BOOL)canMgr
{
    PhotosViewController *vc = [[PhotosViewController alloc] initWithNibName:@"PhotosViewController" bundle:nil withUid:photoOfUid canMgr:canMgr];
    [navigationController pushViewController:vc animated:YES];
}

+ (void)goPhonePhotosViewController:(UINavigationController *)navigationController withUid:(NSString *)photoOfUid canMgr:(BOOL)canMgr
{
    PhotosViewController *vc = [[PhotosViewController alloc] initWithNibName:@"PhotosViewController" bundle:nil withUid:photoOfUid canMgr:canMgr phoneAlbumMode:YES];
    [navigationController pushViewController:vc animated:YES];
}

// 进入"个人语音"查看界面
+ (void)goVoicesViewController:(UINavigationController *)navigationController withUid:(NSString *)photoOfUid canMgr:(BOOL)canMgr
{
    VoicesViewController *vc = [[VoicesViewController alloc] initWithNibName:@"VoicesViewController" bundle:nil withUid:photoOfUid canMgr:canMgr];
    [navigationController pushViewController:vc animated:YES];
}

// 进入"大文件下载和查看"界面
+ (void)goBigFileViewerController:(UINavigationController *)navigationController fileName:(NSString *)fileName fileDir:(NSString *)fileDir fileMd5:(NSString *)fileMd5 fileLength:(long)fileLength canDownload:(BOOL)canDownload
{
    BigFileViewerController *vc = [[BigFileViewerController alloc] initWithNibName:@"BigFileViewerController" bundle:nil fileName:fileName fileDir:fileDir fileMd5:fileMd5 fileLength:fileLength canDownload:canDownload];
    [navigationController pushViewController:vc animated:YES];
}

// 进入“短视频录制”界面
+ (void)goShortVideoRecorderViewController:(UINavigationController *)navigationController
{
    ShortVideoRecordViewController *vc = [[ShortVideoRecordViewController alloc] initWithNibName:@"ShortVideoRecordViewController" bundle:nil withSaveDir:[ReceivedShortVideoHelper getReceivedFileSavedDirHasSlash]];
    [navigationController pushViewController:vc animated:YES];
}

// 进入“短视频播放”界面（用于从远程网络读取短视频时）
+ (void)goShortVideoPlayerViewController_fromUrl:(UINavigationController *)navigationController duaration:(int)durationWithSecond httpUrl:(NSString *)httpUrl
{
    [self goShortVideoPlayerViewController:navigationController duaration:durationWithSecond videoDataType:VideoDataType_URL videoDataSrc:httpUrl];
}

// 进入“短视频播放”界面（用于从本地文件缓存读取短视频时）
+ (void)goShortVideoPlayerViewController_fromFile:(UINavigationController *)navigationController duaration:(int)durationWithSecond videoFilePath:(NSString *)videoFilePath
{
    [self goShortVideoPlayerViewController:navigationController duaration:durationWithSecond videoDataType:VideoDataType_FILE_PATH videoDataSrc:videoFilePath];
}

// 进入"短视频播放"界面
+ (void)goShortVideoPlayerViewController:(UINavigationController *)navigationController duaration:(int)durationWithSecond videoDataType:(VideoDataType)videoDataType videoDataSrc:(NSString *)videoDataSrc
{
    if (navigationController == nil) {
        DDLogError(@"【视频播放】navigationController为nil，无法跳转到播放界面");
        return;
    }
    
    if (videoDataSrc == nil || videoDataSrc.length == 0) {
        DDLogError(@"【视频播放】videoDataSrc为空，无法跳转到播放界面");
        return;
    }
    
    if (durationWithSecond <= 0) {
        DDLogError(@"【视频播放】duration无效（%d），无法跳转到播放界面", durationWithSecond);
        return;
    }
    
    ShortVideoPlayViewController *vc = [[ShortVideoPlayViewController alloc] initWithNibName:@"ShortVideoPlayViewController" bundle:nil duaration:durationWithSecond videoDataType:videoDataType videoDataSrc:videoDataSrc savedDir:[ReceivedShortVideoHelper getReceivedFileSavedDirHasSlash]];
    if (vc != nil) {
        [navigationController pushViewController:vc animated:YES];
    } else {
        DDLogError(@"【视频播放】ShortVideoPlayViewController初始化失败");
    }
}

// 进入"短视频播放"界面（支持多个视频的左右滑动切换）
+ (void)goShortVideoPlayerViewController_withVideoArray:(UINavigationController *)navigationController videoDataArray:(NSArray<NSDictionary *> *)videoDataArray currentIndex:(NSInteger)currentIndex
{
    if (videoDataArray == nil || videoDataArray.count == 0) {
        DDLogError(@"【视频播放】videoDataArray为空，无法跳转到播放界面");
        return;
    }
    
    if (navigationController == nil) {
        DDLogError(@"【视频播放】navigationController为nil，无法跳转到播放界面");
        return;
    }
    
    // 确保 currentIndex 在有效范围内
    if (currentIndex < 0 || currentIndex >= videoDataArray.count) {
        currentIndex = 0;
    }
    
    // 验证视频数据有效性
    for (NSDictionary *videoData in videoDataArray) {
        NSString *videoDataSrc = [videoData objectForKey:@"videoDataSrc"];
        int duration = [[videoData objectForKey:@"duration"] intValue];
        if (videoDataSrc == nil || videoDataSrc.length == 0 || duration <= 0) {
            DDLogError(@"【视频播放】视频数据无效，videoDataSrc=%@, duration=%d", videoDataSrc, duration);
        }
    }
    
    // 如果只有一个视频，直接播放
    if (videoDataArray.count == 1) {
        NSDictionary *videoData = [videoDataArray objectAtIndex:0];
        int duration = [[videoData objectForKey:@"duration"] intValue];
        VideoDataType videoType = [[videoData objectForKey:@"videoType"] intValue];
        NSString *videoDataSrc = [videoData objectForKey:@"videoDataSrc"];
        
        if (videoDataSrc == nil || videoDataSrc.length == 0 || duration <= 0) {
            DDLogError(@"【视频播放】视频数据无效，无法播放");
            return;
        }
        
        if (videoType == VideoDataType_FILE_PATH) {
            [self goShortVideoPlayerViewController_fromFile:navigationController duaration:duration videoFilePath:videoDataSrc];
        } else if (videoType == VideoDataType_URL) {
            [self goShortVideoPlayerViewController_fromUrl:navigationController duaration:duration httpUrl:videoDataSrc];
        }
        return;
    }
    
    // 多个视频时，使用支持多视频的初始化方法
    ShortVideoPlayViewController *vc = [[ShortVideoPlayViewController alloc] initWithNibName:@"ShortVideoPlayViewController" bundle:nil videoDataArray:videoDataArray currentIndex:currentIndex savedDir:[ReceivedShortVideoHelper getReceivedFileSavedDirHasSlash]];
    if (vc != nil) {
        [navigationController pushViewController:vc animated:YES];
    } else {
        DDLogError(@"【视频播放】ShortVideoPlayViewController初始化失败");
    }
}

// 进入目录选择界面
+ (void)goTargetChooseViewController:(UINavigationController *)navigationController
               supportedTargetSource:(int)targetSource
                latestChattingFilter:(TargetSourceFilter4LatestChatting)targetSourceFilter4LatestChatting
                        friendFilter:(TargetSourceFilter4Friend)targetSourceFilter4Friend
                         groupFilter:(TargetSourceFilter4Group)targetSourceFilter4Group
                   groupMemberFilter:(TargetSourceFilter4GroupMember)targetSourceFilter4GroupMember
                            extraObj:(id)extraObj
                                 gid:(NSString *)gid
                         requestCode:(int)requestCode
                            delegate:(id<UserChooseCompleteDelegate>)userChooseCompleteDelegate
{
    TargetChooseViewController *vc = [[TargetChooseViewController alloc]
                                      initWithNibName:@"TargetChooseViewController"
                                      bundle:nil
                                      supportedTargetSource:targetSource
                                      latestChattingFilter:targetSourceFilter4LatestChatting
                                      friendFilter:targetSourceFilter4Friend
                                      groupFilter:targetSourceFilter4Group
                                      groupMemberFilter:targetSourceFilter4GroupMember
                                      extraObj:extraObj
                                      gid:gid
                                      requestCode:requestCode
                                      delegate:userChooseCompleteDelegate];
    [navigationController pushViewController:vc animated:YES];
}

// 进入位置选择界面
+ (void)goLocationChooseViewController:(UINavigationController *)navigationController delegate:(id<LocationChooseCompleteDelegate>)locationChooseCompleteDelegate
{
    GetLocationViewController *vc = [[GetLocationViewController alloc] initWithNibName:@"GetLocationViewController" bundle:nil delegate:locationChooseCompleteDelegate];
    [navigationController pushViewController:vc animated:YES];
}

// 进入位置查看界面
+ (void)goViewLocationViewController:(UINavigationController *)navigationController dest:(LocationMeta *)destLocationMeta
{
    ViewLocationViewController *vc = [[ViewLocationViewController alloc] initWithNibName:@"ViewLocationViewController" bundle:nil dest:destLocationMeta];
    [navigationController pushViewController:vc animated:YES];
}

// 进入"设置好友备注"的相关编辑界面
+ (void)goFriendRemarkEditViewController:(UINavigationController *)navigationController withUid:(NSString *)uid
{
    FriendRemarkEditViewController *vc = [[FriendRemarkEditViewController alloc] initWithUid:uid];
    [navigationController pushViewController:vc animated:YES];
}

// 进入“我的群组”界面
+ (void)goGroupsViewController:(UINavigationController *)navigationController
{
    GroupsViewController *vc = [[GroupsViewController alloc] initWithNibName:@"GroupsViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 进入"聊天信息"的界面
+ (void)goChatInfoViewController:(UINavigationController *)navigationController withUid:(NSString *)uid andNick:(NSString *)nickname
{
    ChatInfoViewController *vc = [[ChatInfoViewController alloc] initWithUid:uid andNick:nickname];
    [navigationController pushViewController:vc animated:YES];
}

// 进入"加入群聊"的界面
+ (void)goJoinGroupViewController:(UINavigationController *)navigationController with:(NSString *)qrcodeValue joinBy:(int)joinBy
{
    JoinGroupViewController *vc = [[JoinGroupViewController alloc] initWithNibName:@"JoinGroupViewController" bundle:nil with:qrcodeValue joinBy:joinBy];
    [navigationController pushViewController:vc animated:YES];
}

// 进入"我的二维码"的界面
+ (void)goQRCodeGenerateMyViewController:(UINavigationController *)navigationController
{
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    if(localUserInfo != nil)
       [ViewControllerFactory goQRCodeGenerateViewController:navigationController withScheme:QR_CODE_SCHEME_ADD_USER andId:localUserInfo.user_uid];
}

// 进入"群聊二维码"的界面
+ (void)goQRCodeGenerateGroupViewController:(UINavigationController *)navigationController withId:(NSString *)theId
{
    [ViewControllerFactory goQRCodeGenerateViewController:navigationController withScheme:QR_CODE_PSCHEME_JOIN_GROUP andId:theId];
}

+ (void)goQRCodeGenerateViewController:(UINavigationController *)navigationController withScheme:(NSString *)scheme andId:(NSString *)theId
{
//    // 先回到栈顶
//    [navigationController popToRootViewControllerAnimated:NO];
    
    QRCodeGenerateViewController *vc = [[QRCodeGenerateViewController alloc] initWithNibName:@"QRCodeGenerateViewController" bundle:nil withScheme:scheme andId:theId];
    [navigationController pushViewController:vc animated:YES];
}

// 进入"搜索"界面
+ (void)goSearchViewController:(UINavigationController *)navigationController supportedSearchableContens:(NSArray<SearchableContent *> *)searchableContens keyword:(NSString *)keyword showAllResult:(BOOL)showAllResult
{
    SearchViewController *vc = [[SearchViewController alloc] initWithNibName:@"SearchViewController" bundle:nil supportedSearchableContens:searchableContens keyword:keyword showAllResult:showAllResult];
    [navigationController pushViewController:vc animated:YES];
}

// 进入AI机器人界面
+ (void)goAIViewController:(UINavigationController *)navigationController
{
    AIViewController *vc = [[AIViewController alloc] initWithNibName:@"AIViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 进入朋友圈界面
+ (void)goMomentViewController:(UINavigationController *)navigationController
{
    MomentViewController *vc = [[MomentViewController alloc] initWithNibName:@"MomentViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 进入附近的人界面
+ (void)goNearbyViewController:(UINavigationController *)navigationController
{
    NearbyViewController *vc = [[NearbyViewController alloc] initWithNibName:@"NearbyViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 进入设置界面
+ (void)goSettingsViewController:(UINavigationController *)navigationController
{
    SettingsViewController *vc = [[SettingsViewController alloc] initWithNibName:@"SettingsViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 进入账号安全设置界面
+ (void)goSettingsAccountSecurityViewController:(UINavigationController *)navigationController
{
    SettingsAccountSecurityViewController *vc = [[SettingsAccountSecurityViewController alloc] initWithNibName:@"SettingsAccountSecurityViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 进入朋友权限设置界面
+ (void)goSettingsFriendPermissionViewController:(UINavigationController *)navigationController
{
    SettingsFriendPermissionViewController *vc = [[SettingsFriendPermissionViewController alloc] init];
    [navigationController pushViewController:vc animated:YES];
}

// 进入通知设置界面
+ (void)goSettingsNotificationViewController:(UINavigationController *)navigationController
{
    SettingsNotificationViewController *vc = [[SettingsNotificationViewController alloc] initWithNibName:@"SettingsNotificationViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 进入界面与显示设置界面
+ (void)goSettingsDisplayViewController:(UINavigationController *)navigationController
{
    SettingsDisplayViewController *vc = [[SettingsDisplayViewController alloc] initWithNibName:@"SettingsDisplayViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 进入储存空间设置界面
+ (void)goSettingsStorageViewController:(UINavigationController *)navigationController
{
    SettingsStorageViewController *vc = [[SettingsStorageViewController alloc] init];
    [navigationController pushViewController:vc animated:YES];
}

// 进入修改/绑定手机号界面
+ (void)goModifyPhoneViewController:(UINavigationController *)navigationController
{
    ModifyPhoneViewController *vc = [[ModifyPhoneViewController alloc] init];
    [navigationController pushViewController:vc animated:YES];
}

// 进入修改/绑定邮箱界面
+ (void)goModifyEmailViewController:(UINavigationController *)navigationController
{
    ModifyEmailViewController *vc = [[ModifyEmailViewController alloc] init];
    [navigationController pushViewController:vc animated:YES];
}

// 进入设备记录界面
+ (void)goSettingsDeviceRecordViewController:(UINavigationController *)navigationController
{
    SettingsDeviceRecordViewController *vc = [[SettingsDeviceRecordViewController alloc] initWithNibName:@"SettingsDeviceRecordViewController" bundle:nil];
    [navigationController pushViewController:vc animated:YES];
}

// 获取当前最顶层的 ViewController（兼容 iOS 13+ UIWindowScene）
+ (UIViewController *)topMostViewController
{
    UIWindow *window = nil;
    
    // iOS 13+：通过 UIWindowScene 获取活跃窗口
    if (@available(iOS 13.0, *)) {
        // 优先查找前台活跃的 scene
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive ||
                scene.activationState == UISceneActivationStateForegroundInactive) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                if (window) break;
            }
        }
        // fallback：遍历所有 scene 的 keyWindow
        if (!window) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                if (window) break;
            }
        }
    }
    
    // 最终 fallback
    if (!window) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    }
    if (!window) {
        window = [UIApplication sharedApplication].windows.firstObject;
    }
    
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

// 进入音视频通话界面
+ (void)goCallViewController:(NSString *)remoteUserUid
           remoteUserNickname:(NSString *)remoteUserNickname
                     callType:(CallType)callType
                     isCaller:(BOOL)isCaller
{
    CallViewController *vc = [[CallViewController alloc] initWithCallType:callType
                                                            remoteUserUid:remoteUserUid
                                                       remoteUserNickname:remoteUserNickname
                                                                 isCaller:isCaller];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    
    // 使用可靠的 topMostViewController 方法获取顶层 VC
    UIViewController *topVC = [self topMostViewController];
    
    if (topVC == nil) {
        NSLog(@"【ViewControllerFactory】⚠️ topMostViewController 返回 nil，无法弹出通话界面！");
        return;
    }
    
    // 如果顶层VC有导航栈，使用push方式（这样能用导航栏返回）
    if (topVC.navigationController) {
        [topVC.navigationController pushViewController:vc animated:YES];
    } else if ([topVC isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)topVC pushViewController:vc animated:YES];
    } else if ([topVC isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabVC = (UITabBarController *)topVC;
        UINavigationController *navVC = (UINavigationController *)tabVC.selectedViewController;
        if ([navVC isKindOfClass:[UINavigationController class]]) {
            [navVC pushViewController:vc animated:YES];
        } else {
            [topVC presentViewController:vc animated:YES completion:nil];
        }
    } else {
        [topVC presentViewController:vc animated:YES completion:nil];
    }
}

+ (void)goChatSearchMenuViewController:(UINavigationController *)navigationController
                               chatType:(int)chatType
                                 dataId:(NSString *)dataId
                            isGroupChat:(BOOL)isGroupChat
{
    ChatSearchMenuViewController *vc = [[ChatSearchMenuViewController alloc] initWithChatType:chatType
                                                                                        dataId:dataId
                                                                                   isGroupChat:isGroupChat];
    [navigationController pushViewController:vc animated:YES];
}

+ (void)goMessageSearch10001ViewController:(UINavigationController *)navigationController
                                 chatType:(int)chatType
                                   dataId:(NSString *)dataId
                              partnerName:(NSString *)partnerName
                   showSearchBarWhenPushed:(BOOL)showSearchBarWhenPushed
                      initialSearchKeyword:(NSString *)initialSearchKeyword
{
    MessageSearch10001ViewController *vc = [[MessageSearch10001ViewController alloc] initWithChatType:chatType
                                                                                               dataId:dataId
                                                                                          partnerName:partnerName];
    vc.showSearchBarOnAppear = showSearchBarWhenPushed;
    if (initialSearchKeyword.length > 0) {
        vc.initialSearchKeyword = [initialSearchKeyword copy];
    }
    [navigationController pushViewController:vc animated:YES];
}

@end
