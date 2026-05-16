//telegram @wz662
// 【用途】：本类是本地Push（通知）辅助类。
// 【注意】：将勿将本类中的“通知”（即系统提示通知）与iOS的NSNotificationCenter机制中的“通知”（即KVO机制）混为一谈。
// 【补充】：根据ios的要求，向用户推送push“通知”（包括本地push）都需要先进行注册，本类的使用是在开发者已经完成注册的情况下才能正常工作的，
//         RainbowChat中的push注册逻辑代码请前往AppDelegate.m中查看。也可参考资料：https://blog.csdn.net/cloudox_/article/details/75116240

#import <Foundation/Foundation.h>

@interface LocalPushHelper : NSObject

/**
 * 收到了加好友请求时的提示（由服务端通知被请求者）.
 */
+ (void) showAddFriendRequestPush:(NSString *)fromNickname;

/**
 * 服务端反馈给请求发起者，加好友请求在服务端处理中出现的各种错误时的提示（由服务端通知请求发起者）.
 */
+ (void) showAddFriendRequest_RESPONSE_FOR_ERROR_SERVER_TO_A_Push:(NSString *)errorMsg;

/**
 * 新添加的好友成列加入到好友列表了（由服务端通知请求发起者和
 * 被请求者：被加者同意后服务端会同时向请求者和被加者送出成功指令）.
 */
+ (void) showNewFriendAddSucessPush:(NSString *)newFriendNickName;

/**
 * "我"被邀请进入了群聊的系统通知.
 */
+ (void) showMyselfBeInvitedGroupPush:(NSString *)groupName beInvitedNickname:(NSString *)beNickname;

/**
 * 加好友被拒绝时的提示（由服务端提示加好友发起人A）.
 *
 * @param beRejectNickmame 拒绝好友请求者的昵称
 */
+ (void) showAddFriendBeRejectPush:(NSString *)beRejectNickmame;

/**
 * 相关处理界面处于后台时接收到音视频聊天请求时的提示（来自发起人A）. -- AnyChat
 *
 * @param friendNickName 昵称
 */
+ (void) showVoiceAndVideoRequestPush:(NSString *)friendNickName;

/**
 * 相关处理界面处于后台时接收到好友发过来的聊天消息时的提示（来自发起人A）.
 *
 * @param friendUid 消息发送者的 UID（用于点击通知时跳转）
 * @param friendNickName 消息发送者的昵称
 * @param message 消息内容
 */
+ (void) showRecievedFriendMessagePush:(NSString *)friendUid nickName:(NSString *)friendNickName msg:(NSString *)message;

/**
 * 收到一个临时聊天消息哦.
 *
 * @param fromUid 消息发送者的 UID（用于点击通知时跳转）
 * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
 */
+ (void) showATempChatMsgPush:(int)msgType msg:(NSString *)msg fromUid:(NSString *)fromUid fromNickName:(NSString *)fromNickName;

/**
 * 收到一个群聊天消息哦.
 *
 * @param gid 群组 ID（用于点击通知时跳转）
 */
+ (void) showAGroupChatMsgPush:(BOOL)isWordChat msgType:(int)msgType msg:(NSString *)msg fromNickName:(NSString *)fromNickName toGid:(NSString *)gid toGname:(NSString *)toGname;

/**
 * 【收到实时语音请求处理方式3】相关处理界面处于后台时接收实时语音聊天请求时的提示（来自发起人A）.
 *
 * @param friendNickName 昵称
 */
+ (void) showRealTimeVoiceRequestPush:(NSString *)friendNickName;

/**
 * 尝试清除本除程序产生的所有本地通知。
 */
+ (void) cancalAllLocalPush;












@end
