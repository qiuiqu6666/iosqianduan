//telegram @wz662
#import <Foundation/Foundation.h>
#import "LoginInfoToSave.h"

@interface UserDefaultsToolKits : NSObject

/**
 * 返回最近陆的用户名.
 * 它是上次成功登陆使用ios的NSUserDefaults机制进行存放的.
 *
 * @return 登陆账号（没有设置过则返回nil）
 */
+ (LoginInfoToSave *)getDefaultLoginName;

/**
 * 设置"自动登陆"开关量。
 *
 * @param autoLogin YES表示允许自动登陆，否由不允许
 */
+ (void)setAutoLogin:(BOOL)autoLogin;

/**
 * 调用本方法实现对用户名的保存(以备下次登陆时无需再次输入).
 *
 * @param loginInfoToSave 用户的登陆账号信息
 */
+ (void)saveDefaultLoginName:(LoginInfoToSave *)loginInfoToSave;

/**
 * 调用本方法实现删除之前保存过的最近登陆用户名.
 */
+ (void)removeDefaultLoginName;

/**
 * 用户最近设置的APP全局“是否开启消息声音提醒”开关值。
 * 注意：本开关是全局开关，一旦关闭，单独的群聊、世界频道、好友消息等的提醒都会无条件被关闭。
 *
 * @return YES表示已开启，否则表示已关闭
 */
+ (BOOL)isAPPMsgToneOpen;

/**
 * 设置的APP全局“是否开启消息声音提醒”开关值。
 * 注意：本开关是全局开关，一旦关闭，单独的群聊、世界频道、好友消息等的提醒都会无条件被关闭。
 */
+ (void)setAPPMsgToneOpen:(BOOL)msgToneOpen;

/**
 * 是否指定聊天会话的消息提示音打开（区别是全局消息提醒，这个是指具体到某人、某群的聊天消息提醒）.
 *
 * @param chatId 聊天id，对应用于首页"消息"列表中的dataId，即当聊天类型是单聊时表示对方的uid、群聊时是gid
 * @return YES表示开启提醒（也就是关闭"消息勿扰）"，否则表示关闭（也就是打开"消息勿扰"）
 */
+ (BOOL)isChatMsgToneOpen:(NSString *)chatId;
/**
 * 设置指定聊天会话的消息消息提示音开关量（区别是全局消息提醒，这个是指具体到某人、某群的聊天消息提醒）.
 *
 * @param msgToneOpen YES表示开启提醒（也就是关闭"消息勿扰）"，否则表示关闭（也就是打开"消息勿扰"）
 * @param chatId 聊天id，对应用于首页"消息"列表中的dataId，即当聊天类型是单聊时表示对方的uid、群聊时是gid
 */
+ (void) setChatMsgToneOpen:(BOOL)msgToneOpen chatId:(NSString *)chatId;


/**
 获得当前app创建的sqlite数据库表版本号。

 @return 如果创建过库则返回对应的版本号，否则返回-1（表示未创建过数据库）
 */
+ (int)getDbVersion;
/**
 保存app当前创建的sqlite库版本号。
 此版本号目前用于升级本地数据库表结构时使用，详见 MyDataBase.m文件中的代码逻辑。

 @param db_ver 当前创建库的版本号
 */
+ (void) saveDbVersion:(int)db_ver;


/**
 获得保存的设备token，用于登陆时提交给服务端，从而实现APNs的离线消息推送。

 @return 如果不存在则返回Nil，否则返回token
 */
+ (NSString *)getDeviceTokenForPush;

/**
 保存设备token，用于登陆时提交给服务端，从而实现APNs的离线消息推送。

 @param deviceToken 当前设备的device token
 */
+ (void)saveDeviceTokenForPush:(NSString *)deviceToken;

/** “个人相册”新功能标识 */
+ (BOOL)isProfilePhotoFuncNew;
/**  关闭“个人相册”新功能标识 */
+ (void) closeProfilePhotoFuncNew;

/**  “语音介绍”新功能标识 */
+ (BOOL)isProfilePVoiceFuncNew;
/**  关闭“语音介绍”新功能标识 */
+ (void) closeProfilePVoiceFuncNew;

/**
 * 获取“最近一次查看的好友请求列表中，已读的最新一条请求的时间戳”.
 *
 * @return 存在则正常返回时间戳（否则返回0），形如：1479250540110，单位：毫秒，兼容java的时间戳
 */
+ (long)getHasReadLatestFriendReqTimestamp;
/**
 * 设置“最近一次查看的好友请求列表中，已读的最新一条请求的时间戳”.
 *
 * @param tm 日期对象
 */
+ (void)setHasReadLatestFriendReqTimestamp:(NSDate *)tm;

/**
 * 获取“最近一次查看的群通知列表中，已读的最新一条通知时间戳”.
 *
 * @return 存在则返回毫秒时间戳，否则返回0
 */
+ (long long)getHasReadLatestGroupNotificationTimestamp;
/**
 * 设置“最近一次查看的群通知列表中，已读的最新一条通知时间戳”.
 *
 * @param tm 日期对象
 */
+ (void)setHasReadLatestGroupNotificationTimestamp:(NSDate *)tm;
/**
 * 获取当前用户的群通知未读数量。
 */
+ (NSInteger)getGroupNotificationUnreadCount;
/**
 * 设置当前用户的群通知未读数量。
 */
+ (void)setGroupNotificationUnreadCount:(NSInteger)count;

+ (void)markDeletedFriendReqUid:(NSString *)uid;
+ (void)unmarkDeletedFriendReqUid:(NSString *)uid;
+ (BOOL)isDeletedFriendReqUid:(NSString *)uid;

+ (void)markFriendChatSendBlockedUid:(NSString *)uid;
+ (void)unmarkFriendChatSendBlockedUid:(NSString *)uid;
+ (BOOL)isFriendChatSendBlockedUid:(NSString *)uid;

/**
 * 获取是否显示群成员昵称设置。
 *
 * @param gid 群ID
 * @return YES表示显示群成员昵称，默认YES
 */
+ (BOOL)getShowGroupMemberNickname:(NSString *)gid;

/**
 * 设置是否显示群成员昵称。
 *
 * @param show YES表示显示
 * @param gid 群ID
 */
+ (void)setShowGroupMemberNickname:(BOOL)show gid:(NSString *)gid;

/**
 * 获取清空所有消息的时间戳。
 *
 * @return 清空时间戳（毫秒），0表示未清空过
 */
+ (long long)getClearAllMessagesTimestamp;

/**
 * 设置清空所有消息的时间戳。
 *
 * @param timestamp 清空时间戳（毫秒）
 */
+ (void)setClearAllMessagesTimestamp:(long long)timestamp;

@end
