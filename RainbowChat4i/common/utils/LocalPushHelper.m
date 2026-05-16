//telegram @wz662
#import "LocalPushHelper.h"
#import <UserNotifications/UserNotifications.h>
#import "AppDelegate.h"
#import "ChatDataHelper.h"
#import "BasicTool.h"
#import "AlarmType.h"

// 通知显示内容类型的 UserDefaults key（与 NotificationContentViewController 中一致）
static NSString * const kNotificationContentKey_LP = @"APP_NOTIFICATION_DISPLAY_CONTENT_TYPE";
// 横幅显示内容类型的 UserDefaults key（与 NotificationContentViewController 中一致）
static NSString * const kBannerContentKey_LP = @"APP_BANNER_DISPLAY_CONTENT_TYPE";
// 系统消息通知开关 key（与 SettingsNotificationViewController 中一致）
static NSString * const kSystemNotificationKey_LP = @"APP_SYSTEM_NOTIFICATION_ENABLED";

/** 收到了加好友请求时的提示 */
#define LOCAL_PUSH_UNIQE_IDENT_ID_ADD_FRIEND_REQUEST                                @"__LOCAL_PUSH__1"
/** 服务端反馈给请求发起者，加好友请求在服务端处理中出现的各种错误时的提示 */
#define LOCAL_PUSH_UNIQE_IDENT_ID_ADD_FRIEND_REQUEST_RESPONSE_FOR_ERROR_SERVER_TO_A @"__LOCAL_PUSH__2"
/** 好友请求被对方成功处理后时的提示（被加者同意后服务端会同时向请求者和被加者送出成功指令） */
#define LOCAL_PUSH_UNIQE_IDENT_ID_NEW_FRIEND_ADD_SUCESS                             @"__LOCAL_PUSH__3"
/** 加好友被拒绝时的提示 */
#define LOCAL_PUSH_UNIQE_IDENT_ID_ADD_FRIEND_BE_REJECT                              @"__LOCAL_PUSH__4"
/** 相关处理界面处于后台时接收到音视频聊天请求时的提示 */
#define LOCAL_PUSH_UNIQE_IDENT_ID_VOICE_VIDEO_CHAT_REQUEST                          @"__LOCAL_PUSH__5"
/** 相关处理界面处于后台时接收到好友发过来的角色指令时的提示 */
#define LOCAL_PUSH_UNIQE_IDENT_ID_RECIEVED_FRIEND_SCENSE_CMD                        @"__LOCAL_PUSH__6"
/** 相关处理界面处于后台时接收到好友发过来的聊天消息时的提示 */
#define LOCAL_PUSH_UNIQE_IDENT_ID_RECIEVED_FRIEND_MESSAGE                           @"__LOCAL_PUSH__7"

/** 相关处理界面处于后台时接收到实时语音聊天请求时的提示 */
#define LOCAL_PUSH_UNIQE_IDENT_ID_REAL_TIME_VOICE_CHAT_REQUEST                      @"__LOCAL_PUSH__9"

/** 相关处理界面处于后台时接收到好友发过来的临时聊天消息时的提示 */
#define LOCAL_PUSH_UNIQE_IDENT_ID_RECIEVED_TEMP_MESSAGE                             @"__LOCAL_PUSH__10"
/** 相关处理界面处于后台时接收到好友发过来的BBS聊天消息时的提示 */
#define LOCAL_PUSH_UNIQE_IDENT_ID_RECIEVED_BBS_MESSAGE                              @"__LOCAL_PUSH__11"

/** "我"被邀请成功加入群组的提示 */
#define LOCAL_PUSH_UNIQE_IDENT_ID_MYSELF_BE_INVITED                                 @"__LOCAL_PUSH__12"


@implementation LocalPushHelper

#pragma mark - 系统消息通知开关

/**
 * 判断"系统消息通知"是否开启（默认 YES）。
 * 关闭后，所有消息类本地推送将不再创建。
 */
+ (BOOL)isSystemNotificationEnabled
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud objectForKey:kSystemNotificationKey_LP] == nil) {
        return YES; // 默认开启
    }
    return [ud boolForKey:kSystemNotificationKey_LP];
}

#pragma mark - 通知显示内容等级

/**
 * 根据 App 当前状态自动选择内容等级：
 *   - 前台（Active）→ 使用"横幅显示内容"设置（APP_BANNER_DISPLAY_CONTENT_TYPE）
 *   - 后台/未激活   → 使用"通知显示内容"设置（APP_NOTIFICATION_DISPLAY_CONTENT_TYPE）
 *
 * 等级说明：
 *   0 = 仅显示「你收到了一条消息」
 *   1 = 显示朋友名称、群聊名
 *   2 = 显示朋友名称、群聊名及消息内容（默认）
 */
+ (NSInteger)notificationContentLevel
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    // 判断 App 是否在前台
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    NSString *key = (appState == UIApplicationStateActive) ? kBannerContentKey_LP : kNotificationContentKey_LP;
    
    if ([ud objectForKey:key] != nil) {
        return [ud integerForKey:key];
    }
    return 2; // 默认显示全部内容
}

// 收到了加好友请求时的提示（由服务端通知被请求者）.
+ (void) showAddFriendRequestPush:(NSString *)fromNickname
{
    if (![self isSystemNotificationEnabled]) return;
    [APP showLocalPush:nil body:[NSString stringWithFormat:@"%@ 请求加你为好友.", fromNickname] withIdentifier:LOCAL_PUSH_UNIQE_IDENT_ID_ADD_FRIEND_REQUEST playSoud:YES];
}

// 服务端反馈给请求发起者，加好友请求在服务端处理中出现的各种错误时的提示（由服务端通知请求发起者）.
+ (void) showAddFriendRequest_RESPONSE_FOR_ERROR_SERVER_TO_A_Push:(NSString *)errorMsg
{
    if (![self isSystemNotificationEnabled]) return;
    [APP showLocalPush:nil body:errorMsg withIdentifier:LOCAL_PUSH_UNIQE_IDENT_ID_ADD_FRIEND_REQUEST_RESPONSE_FOR_ERROR_SERVER_TO_A playSoud:YES];
}

// 新添加的好友成列加入到好友列表了（由服务端通知请求发起者和
// 被请求者：被加者同意后服务端会同时向请求者和被加者送出成功指令）.
+ (void) showNewFriendAddSucessPush:(NSString *)newFriendNickName
{
    if (![self isSystemNotificationEnabled]) return;
    [APP showLocalPush:nil body:[NSString stringWithFormat:@"%@ 已经是你的好友了，点击进入聊天界面.",newFriendNickName] withIdentifier:LOCAL_PUSH_UNIQE_IDENT_ID_NEW_FRIEND_ADD_SUCESS playSoud:YES];
}

// "我"被邀请进入了群聊的系统通知.
+ (void) showMyselfBeInvitedGroupPush:(NSString *)groupName beInvitedNickname:(NSString *)beNickname
{
    if (![self isSystemNotificationEnabled]) return;
    [APP showLocalPush:nil body:[NSString stringWithFormat:@"您已被\"%@\"邀请加入群组\"%@\"，点击进入聊天界面.", beNickname,groupName] withIdentifier:LOCAL_PUSH_UNIQE_IDENT_ID_MYSELF_BE_INVITED playSoud:YES];
}

// 加好友被拒绝时的提示（由服务端提示加好友发起人A）.
+ (void) showAddFriendBeRejectPush:(NSString *)beRejectNickmame
{
    if (![self isSystemNotificationEnabled]) return;
    [APP showLocalPush:nil body:[NSString stringWithFormat:@"对不起, %@拒绝了您的加好友请求.",beRejectNickmame] withIdentifier:LOCAL_PUSH_UNIQE_IDENT_ID_ADD_FRIEND_BE_REJECT playSoud:YES];
}

// 相关处理界面处于后台时接收到音视频聊天请求时的提示（来自发起人A）. -- AnyChat
+ (void) showVoiceAndVideoRequestPush:(NSString *)friendNickName
{
    [APP showLocalPush:nil body:[NSString stringWithFormat:@"%@向您发起了视频聊天请求，点击进入.",friendNickName] withIdentifier:LOCAL_PUSH_UNIQE_IDENT_ID_VOICE_VIDEO_CHAT_REQUEST playSoud:YES];
}

// 相关处理界面处于后台时接收到好友发过来的聊天消息时的提示（来自发起人A）.
+ (void) showRecievedFriendMessagePush:(NSString *)friendUid nickName:(NSString *)friendNickName msg:(NSString *)message
{
    if (![self isSystemNotificationEnabled]) return;
    NSString *body;
    NSInteger level = [self notificationContentLevel];
    switch (level) {
        case 0:
            body = @"你收到了一条消息";
            break;
        case 1:
            body = friendNickName;
            break;
        default: // 2
            body = [NSString stringWithFormat:@"%@ 说:%@.", friendNickName, message];
            break;
    }
    // 携带会话数据，支持点击通知跳转到聊天界面
    NSDictionary *userInfo = @{
        @"fromUid": friendUid ?: @"",
        @"fromNickname": friendNickName ?: @"",
        @"chatType": @(AMT_friendChatMessage)
    };
    [APP showLocalPush:nil body:body withIdentifier:LOCAL_PUSH_UNIQE_IDENT_ID_RECIEVED_FRIEND_MESSAGE playSoud:YES userInfo:userInfo];
}

// 收到一个临时聊天消息哦.
+ (void) showATempChatMsgPush:(int)msgType msg:(NSString *)msg fromUid:(NSString *)fromUid fromNickName:(NSString *)fromNickName
{
    if (![self isSystemNotificationEnabled]) return;
    NSString *body;
    NSInteger level = [self notificationContentLevel];
    switch (level) {
        case 0:
            body = @"你收到了一条消息";
            break;
        case 1:
            body = [NSString stringWithFormat:@"[陌生人]%@", fromNickName];
            break;
        default: { // 2
            NSString *messageContentForShow = [JSQMessage parseMessageContentPreview:msg withType:msgType];
            body = [NSString stringWithFormat:@"[陌生人]%@ 说:%@.", fromNickName, messageContentForShow];
            break;
        }
    }
    // 携带会话数据，支持点击通知跳转到聊天界面
    NSDictionary *userInfo = @{
        @"fromUid": fromUid ?: @"",
        @"fromNickname": fromNickName ?: @"",
        @"chatType": @(AMT_guestChatMessage)
    };
    [APP showLocalPush:nil body:body withIdentifier:LOCAL_PUSH_UNIQE_IDENT_ID_RECIEVED_TEMP_MESSAGE playSoud:YES userInfo:userInfo];
}

// 收到一个群聊天消息哦.
+ (void) showAGroupChatMsgPush:(BOOL)isWordChat msgType:(int)msgType msg:(NSString *)msg fromNickName:(NSString *)fromNickName toGid:(NSString *)gid toGname:(NSString *)toGname
{
    if (![self isSystemNotificationEnabled]) return;
    // 昵称是空的（这应该是群的系统通知）
    BOOL nicknameIsEmpty = [BasicTool isStringEmpty:[BasicTool trim:fromNickName]];
    NSString *groupDisplayName = isWordChat ? @"世界频道" : toGname;

    NSString *body;
    NSInteger level = [self notificationContentLevel];
    switch (level) {
        case 0:
            body = @"你收到了一条消息";
            break;
        case 1:
            body = [NSString stringWithFormat:@"%@(%@)", nicknameIsEmpty ? @"" : fromNickName, groupDisplayName];
            break;
        default: { // 2
            NSString *messageContentForShow = [JSQMessage parseMessageContentPreview:msg withType:msgType];
            body = [NSString stringWithFormat:@"%@(%@):%@", nicknameIsEmpty ? @"" : fromNickName, groupDisplayName, messageContentForShow];
            break;
        }
    }
    // 携带会话数据，支持点击通知跳转到群聊界面
    NSDictionary *userInfo = @{
        @"fromUid": gid ?: @"",
        @"fromNickname": groupDisplayName ?: @"",
        @"chatType": @(AMT_groupChatMessage)
    };
    [APP showLocalPush:nil body:body withIdentifier:LOCAL_PUSH_UNIQE_IDENT_ID_RECIEVED_BBS_MESSAGE playSoud:YES userInfo:userInfo];
}

// 【收到实时语音请求处理方式3】相关处理界面处于后台时接收实时语音聊天请求时的提示（来自发起人A）.
+ (void) showRealTimeVoiceRequestPush:(NSString *)friendNickName
{
    [APP showLocalPush:nil body:[NSString stringWithFormat:@"%@ 向您发起了实时语音聊天请求，点击进入.", friendNickName] withIdentifier:LOCAL_PUSH_UNIQE_IDENT_ID_REAL_TIME_VOICE_CHAT_REQUEST playSoud:YES];
}

// 尝试清除本除程序产生的所有本地通知。
+ (void) cancalAllLocalPush
{
    [[UIApplication sharedApplication] cancelAllLocalNotifications]; //清除APP所有通知消息
}


@end
