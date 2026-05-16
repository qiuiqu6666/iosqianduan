//telegram @wz662
#import "UserDefaultsToolKits.h"
#import "IMClientManager.h"

/** 存储用户最近登陆用户名的key标识常量 */
#define kSHARED_PREFERENCES_KEY_LOGIN_NAME                           @"__last_login_name__"
/** 存储用户最近设置的全局APP“是否开启消息声音提醒”的key标识常量 */
#define kSHARED_PREFERENCES_KEY_APP_MSG_TONE                         @"__app_message_tone__"
/** 存储“是否开启指定聊天会话的消息声音提醒”的key标识常量 */
#define kSHARED_PREFERENCES_KEY_CHAT_MSG_TONE                       @"__chat_message_tone__"
/** 存储当前程序的sqlite数据库建库版本号的key标识常量 */
#define kSHARED_PREFERENCES_KEY_DB_VERSION                           @"__current_db_version__"
/** 存储当前程序的device token（用于APNS推送）的key标识常量 */
#define kSHARED_PREFERENCES_KEY_DEVICE_TOKEN_FOR_PUSH                @"__device_token_for_push__"
/**  存储“个人相册”新功能提示的Shared Preferences key标识常量 */
#define kSHARED_PREFERENCES_KEY_MY_PROFILE_PHOTO_NEW                 @"__my_profile_photo_new__"
/**  存储“语音介绍”新功能提示的Shared Preferences key标识常量 */
#define kSHARED_PREFERENCES_KEY_MY_PROFILE_VOICE_NEW                 @"__my_profile_voice_new__"
/** 存储“最近一次查看的好友请求列表中，已读的最新一条请求的时间戳”的key标识常量 */
#define kSHARED_PREFERENCES_KEY_HAS_READ_LATEST_FRIEND_REQ_TIMESTAMP @"__l_f_r_t2__";
/** 存储“最近一次查看的群通知列表中，已读的最新一条通知时间戳”的key标识常量 */
#define kSHARED_PREFERENCES_KEY_HAS_READ_LATEST_GROUP_NOTIFY_TIMESTAMP @"__l_g_n_t2__"
/** 存储当前用户群通知未读数的key标识常量 */
#define kSHARED_PREFERENCES_KEY_GROUP_NOTIFY_UNREAD_COUNT @"__g_n_u_c__"

static NSString *TAG = @"UserDefaultsToolKits";

static NSString * RBBlockedFriendSendKeyForCurrentUser(void)
{
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (localUid.length == 0) {
        localUid = @"_default_";
    }
    return [NSString stringWithFormat:@"APP_FRIEND_SEND_BLOCKED_UIDS_%@", localUid];
}

static NSString *RBGroupNotificationReadKeyForCurrentUser(void)
{
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (localUid.length == 0) {
        localUid = @"_default_";
    }
    return [NSString stringWithFormat:@"%@_%@", kSHARED_PREFERENCES_KEY_HAS_READ_LATEST_GROUP_NOTIFY_TIMESTAMP, localUid];
}

static NSString *RBGroupNotificationUnreadCountKeyForCurrentUser(void)
{
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (localUid.length == 0) {
        localUid = @"_default_";
    }
    return [NSString stringWithFormat:@"%@_%@", kSHARED_PREFERENCES_KEY_GROUP_NOTIFY_UNREAD_COUNT, localUid];
}


@implementation UserDefaultsToolKits

+ (LoginInfoToSave *)getDefaultLoginName
{
    //取出最近登陆过的用户名
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSString *loginInfoJSON = [userDefaultes stringForKey:kSHARED_PREFERENCES_KEY_LOGIN_NAME];
    
    return  [LoginInfoToSave fromJSON:loginInfoJSON];
}
+ (void)setAutoLogin:(BOOL)autoLogin
{
    LoginInfoToSave *li = [UserDefaultsToolKits getDefaultLoginName];
    if(li != nil)
        li.autoLogin = autoLogin;

    // 重新保存
    [UserDefaultsToolKits saveDefaultLoginName:li];
}
+ (void)saveDefaultLoginName:(LoginInfoToSave *)loginInfoToSave
{
    if(loginInfoToSave != nil)
    {
        NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
        [userDefaultes setObject:[LoginInfoToSave toJSON:loginInfoToSave] forKey:kSHARED_PREFERENCES_KEY_LOGIN_NAME];
        // 同步存储到磁盘中
        [userDefaultes synchronize];
    }
}
+ (void)removeDefaultLoginName
{
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    [userDefaultes removeObjectForKey:kSHARED_PREFERENCES_KEY_LOGIN_NAME];
    // 同步存储到磁盘中
    [userDefaultes synchronize];
}

+ (BOOL)isAPPMsgToneOpen
{
    NSString *key = kSHARED_PREFERENCES_KEY_APP_MSG_TONE;
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSString *v = [userDefaultes stringForKey:key];
    // 如果没有设置，则默认是YES（即意味着APP默认是进行声音等通知的，直到用户设置为NO）
    return  v == nil ? YES: [userDefaultes boolForKey:key];
}
+ (void)setAPPMsgToneOpen:(BOOL)msgToneOpen
{
    NSString *key = kSHARED_PREFERENCES_KEY_APP_MSG_TONE;
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    [userDefaultes setBool:msgToneOpen forKey:key];
    // 同步存储到磁盘中
    [userDefaultes synchronize];
}

+ (BOOL)isChatMsgToneOpen:(NSString *)chatId
{
    NSString *key = [NSString stringWithFormat:@"%@%@", kSHARED_PREFERENCES_KEY_CHAT_MSG_TONE, chatId];
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSString *v = [userDefaultes stringForKey:key];
    // 如果没有设置，则默认是YES
    return  v == nil ? YES: [userDefaultes boolForKey:key];
}
+ (void) setChatMsgToneOpen:(BOOL)msgToneOpen chatId:(NSString *)chatId
{
    NSString *key = [NSString stringWithFormat:@"%@%@", kSHARED_PREFERENCES_KEY_CHAT_MSG_TONE, chatId];
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    [userDefaultes setBool:msgToneOpen forKey:key];
    // 同步存储到磁盘中
    [userDefaultes synchronize];
}

+ (int)getDbVersion
{
    NSString *key = kSHARED_PREFERENCES_KEY_DB_VERSION;
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSString *v = [userDefaultes stringForKey:key];
    // 如果没有设置，则默认是-1
    return v == nil ? -1: (int)[userDefaultes integerForKey:key];
}
+ (void)saveDbVersion:(int)db_ver
{
    NSString *key = kSHARED_PREFERENCES_KEY_DB_VERSION;
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    [userDefaultes setObject:[NSString stringWithFormat:@"%d",db_ver] forKey:key];
    // 同步存储到磁盘中
    [userDefaultes synchronize];
}

+ (NSString *)getDeviceTokenForPush
{
    // 取出最近一次保存的device token
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    return  [userDefaultes stringForKey:kSHARED_PREFERENCES_KEY_DEVICE_TOKEN_FOR_PUSH];
}
+ (void)saveDeviceTokenForPush:(NSString *)deviceToken
{
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    [userDefaultes setObject:deviceToken forKey:kSHARED_PREFERENCES_KEY_DEVICE_TOKEN_FOR_PUSH];
    // 同步存储到磁盘中
    [userDefaultes synchronize];
}

/** “个人相册”新功能标识 */
+ (BOOL)isProfilePhotoFuncNew
{
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSString *v = [userDefaultes stringForKey:kSHARED_PREFERENCES_KEY_MY_PROFILE_PHOTO_NEW];
    // 如果没有设置，则默认是YES
    return  v == nil ? YES: [userDefaultes boolForKey:kSHARED_PREFERENCES_KEY_MY_PROFILE_PHOTO_NEW];
}
/**  关闭“个人相册”新功能标识 */
+ (void) closeProfilePhotoFuncNew
{
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    [userDefaultes setBool:NO forKey:kSHARED_PREFERENCES_KEY_MY_PROFILE_PHOTO_NEW];
    // 同步存储到磁盘中
    [userDefaultes synchronize];
}

/**  “语音介绍”新功能标识 */
+ (BOOL)isProfilePVoiceFuncNew
{
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSString *v = [userDefaultes stringForKey:kSHARED_PREFERENCES_KEY_MY_PROFILE_VOICE_NEW];
    // 如果没有设置，则默认是YES
    return  v == nil ? YES: [userDefaultes boolForKey:kSHARED_PREFERENCES_KEY_MY_PROFILE_VOICE_NEW];
}
/**  关闭“语音介绍”新功能标识 */
+ (void) closeProfilePVoiceFuncNew
{
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    [userDefaultes setBool:NO forKey:kSHARED_PREFERENCES_KEY_MY_PROFILE_VOICE_NEW];
    // 同步存储到磁盘中
    [userDefaultes synchronize];
}

/** 获取“最近一次查看的好友请求列表中，已读的最新一条请求的时间戳”. */
+ (long)getHasReadLatestFriendReqTimestamp
{
    NSString *key = kSHARED_PREFERENCES_KEY_HAS_READ_LATEST_FRIEND_REQ_TIMESTAMP;
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    id v = [userDefaultes objectForKey:key];
        
    // 如果没有设置，则默认是0
//    return v == nil ? 0L: (long long)[userDefaultes integerForKey:key];
    return v == nil ? 0L : [TimeTool getTimeStampWithMillisecond_l:(NSDate *)v];
}
/** 设置“最近一次查看的好友请求列表中，已读的最新一条请求的时间戳”. */
+ (void)setHasReadLatestFriendReqTimestamp:(NSDate *)tm
{
    if(tm == nil)
        return;
    
    NSString *key = kSHARED_PREFERENCES_KEY_HAS_READ_LATEST_FRIEND_REQ_TIMESTAMP;
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
//    [userDefaultes setObject:[NSString stringWithFormat:@"%llu",tm] forKey:key];
    
    [userDefaultes setObject:tm forKey:key];
    // 同步存储到磁盘中
    [userDefaultes synchronize];
}

+ (long long)getHasReadLatestGroupNotificationTimestamp
{
    NSString *key = RBGroupNotificationReadKeyForCurrentUser();
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    id v = [userDefaultes objectForKey:key];
    return v == nil ? 0LL : (long long)[TimeTool getTimeStampWithMillisecond_l:(NSDate *)v];
}

+ (void)setHasReadLatestGroupNotificationTimestamp:(NSDate *)tm
{
    if (tm == nil) {
        return;
    }
    NSString *key = RBGroupNotificationReadKeyForCurrentUser();
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    [userDefaultes setObject:tm forKey:key];
    [userDefaultes synchronize];
}

+ (NSInteger)getGroupNotificationUnreadCount
{
    NSString *key = RBGroupNotificationUnreadCountKeyForCurrentUser();
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    return MAX((NSInteger)[userDefaultes integerForKey:key], 0);
}

+ (void)setGroupNotificationUnreadCount:(NSInteger)count
{
    NSString *key = RBGroupNotificationUnreadCountKeyForCurrentUser();
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    [userDefaultes setInteger:MAX(count, 0) forKey:key];
    [userDefaultes synchronize];
}

+ (void)markDeletedFriendReqUid:(NSString *)uid
{
    if (uid.length == 0) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSMutableArray *deleted = [[ud arrayForKey:@"APP_DELETED_FRIEND_REQ_UIDS"] mutableCopy] ?: [NSMutableArray array];
    if (![deleted containsObject:uid]) {
        [deleted addObject:uid];
        [ud setObject:deleted forKey:@"APP_DELETED_FRIEND_REQ_UIDS"];
        [ud synchronize];
    }
}

+ (void)unmarkDeletedFriendReqUid:(NSString *)uid
{
    if (uid.length == 0) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSMutableArray *deleted = [[ud arrayForKey:@"APP_DELETED_FRIEND_REQ_UIDS"] mutableCopy];
    if (deleted.count == 0) return;
    if ([deleted containsObject:uid]) {
        [deleted removeObject:uid];
        [ud setObject:deleted forKey:@"APP_DELETED_FRIEND_REQ_UIDS"];
        [ud synchronize];
    }
}

+ (BOOL)isDeletedFriendReqUid:(NSString *)uid
{
    if (uid.length == 0) return NO;
    NSArray *deleted = [[NSUserDefaults standardUserDefaults] arrayForKey:@"APP_DELETED_FRIEND_REQ_UIDS"];
    return [deleted containsObject:uid];
}

+ (void)markFriendChatSendBlockedUid:(NSString *)uid
{
    if (uid.length == 0) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *key = RBBlockedFriendSendKeyForCurrentUser();
    NSMutableArray *uids = [[ud arrayForKey:key] mutableCopy] ?: [NSMutableArray array];
    if (![uids containsObject:uid]) {
        [uids addObject:uid];
        [ud setObject:uids forKey:key];
        [ud synchronize];
    }
}

+ (void)unmarkFriendChatSendBlockedUid:(NSString *)uid
{
    if (uid.length == 0) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *key = RBBlockedFriendSendKeyForCurrentUser();
    NSMutableArray *uids = [[ud arrayForKey:key] mutableCopy];
    if (uids.count == 0) return;
    if ([uids containsObject:uid]) {
        [uids removeObject:uid];
        [ud setObject:uids forKey:key];
        [ud synchronize];
    }
}

+ (BOOL)isFriendChatSendBlockedUid:(NSString *)uid
{
    if (uid.length == 0) return NO;
    NSString *key = RBBlockedFriendSendKeyForCurrentUser();
    NSArray *uids = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
    return [uids containsObject:uid];
}

#pragma mark - 群成员昵称显示设置

+ (BOOL)getShowGroupMemberNickname:(NSString *)gid
{
    if (gid == nil) return YES;
    NSString *key = [NSString stringWithFormat:@"__show_group_member_nickname_%@__", gid];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    id val = [ud objectForKey:key];
    if (val == nil) return YES; // 默认显示
    return [ud boolForKey:key];
}

+ (void)setShowGroupMemberNickname:(BOOL)show gid:(NSString *)gid
{
    if (gid == nil) return;
    NSString *key = [NSString stringWithFormat:@"__show_group_member_nickname_%@__", gid];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:show forKey:key];
    [ud synchronize];
}

#pragma mark - 清空所有消息时间戳

+ (long long)getClearAllMessagesTimestamp
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    return [[ud objectForKey:@"__clear_all_messages_timestamp__"] longLongValue];
}

+ (void)setClearAllMessagesTimestamp:(long long)timestamp
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:@(timestamp) forKey:@"__clear_all_messages_timestamp__"];
    [ud synchronize];
}

@end
