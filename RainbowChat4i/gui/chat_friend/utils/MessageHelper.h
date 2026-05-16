//telegram @wz662
#import <Foundation/Foundation.h>
#import "MsgBody4Friend.h"
#import "UserEntity.h"
#import "CMDBody4AddFriendRequest.h"
#import "CMDBody4ProcessFriendRequest.h"
#import "UserProtocalsType.h"
#import "SendDataHelper.h"
#import "FileMeta.h"
#import "ContactMeta.h"
#import "LocationMeta.h"
#import "RevokedMeta.h"

FOUNDATION_EXPORT NSInteger const RBLocalSendCodeFriendshipRequired;

@interface MessageHelper : NSObject


//-------------------------------------------------------------------------------
#pragma mark - （1）解析接收的消息或指令的方法

/**
 * 解析由服务发过来的加好友被拒的实时信息（由服务端通知加好友发起人A）.
 *
 * <p>
 * 此场景一般是：A加B的好友请求被B拒绝了，服务器实时把此情况反馈给客户A，以便A
 * 能即时知会哦。
 *
 * @param originalMsg
 * @return 返回的是B的个人信息（此信息仅包含B存放在数据库中的数据，无其它在线状况信息描述）
 */
+ (UserEntity *)parseProcessAdd_Friend_Req_SERVER_TO_A_REJECT_RESULTMessage:(NSString *)originalMsg;

/**
 * 解析由服务发过来的好友个人信息.
 *
 * <p>
 * 此场景一般是：新好友已成功被添加完成，服务端将建立了好友关系的对方个人信息及时
 * 发送给本地用户（当然，前提是本地用户是在线的，否则没有必要传过来，以便能及时聊天）。
 *
 * @param originalMsg
 * @return
 */
+ (UserEntity *)parseProcessAdd_Friend_Req_friend_Info_Server_To_ClientMessage:(NSString *)originalMsg;

/**
 * 解析由服务端通知在线被加好友者：收到了加好友请求.
 *
 * @param originalMsg
 * @return
 */
+ (UserEntity *)parseAddFriendRequestInfo_server_to_b:(NSString *)originalMsg;

/**
 * 解析由服务端反馈给加好友发起人的错误信息头(出错的可能是：该好友
 * 已经存在于我的好友列表中、插入好友请求到db中时出错等)
 *
 * @param originalMsg
 * @return 错误信息（文本）
 */
+ (NSString *)parseAddFriendRequestResponse_for_error_server_to_a:(NSString *)originalMsg;

+ (NSString *)pareseRecieveOnlineNotivication:(NSString *)dwUserid withMsg:(NSString *)msg;

+ (NSString *)pareseRecieveOfflineNotivication:(NSString *)dwUserid withMsg:(NSString *)msg;


//-------------------------------------------------------------------------------
#pragma mark - （2）发出的消息或指令(异步)的方法

/**
 * 将指定的纯文消息发送给聊天中的好友
 * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param friendUID 接收者的uid
 * @param message 要发送的消息文本（如果该文本为null或空字符串则不会真正执行发送过程）
 * @param quoteMeta  消息引用信息（当前仅用于文本消息时），此字段可为空（表示本条无引用消息）
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 */
+ (void)sendPlainTextMessageAsync:(NSString *)friendUID withMessage:(NSString *)message quote:(QuoteMeta *)quoteMeta forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的图片消息发送给聊天中的好友
 * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param friendUID 接收者的uid
 * @param imageFileName 要发送的图片文件名
 * @param fingerPring 消息指纹码（即全局唯一ID）
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 */
+ (void)sendImageMessageAsync:(NSString *)friendUID withImage:(NSString *)imageFileName fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的语音消息发送给聊天中的好友
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param friendUID 接收者的uid
 * @param voiceFileName 要发送的语音留言录音文件名
 * @param fingerPring 消息指纹码（即全局唯一ID）
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 */
+ (void)sendVoiceMessageAsync:(NSString *)friendUID withVoice:(NSString *)voiceFileName fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的文件消息发送给聊天中的好友（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param friendUID 接收者的uid
 * @param content 文件消息的内容就是FileMeta对象
 * @param fingerPring 消息指纹码（即全局唯一ID）
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 2.1
 */
+ (void)sendFileMessageAsync:(NSString *)friendUID withMeta:(FileMeta *)content fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的短视频消息发送给聊天中的好友（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param friendUID 接收者的uid
 * @param fileMeta 文件消息的内容就是FileMeta对象
 * @param fingerPring 消息指纹码（即全局唯一ID）
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 2.1
 */
+ (void)sendShortVideoMessageAsync:(NSString *)friendUID withMeta:(FileMeta *)fileMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的短视频消息发送给聊天中的好友（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param friendUID 接收者的uid
 * @param contactMeta 名片消息的内容就是ContactMeta对象
 * @param sucessObsExtra 消息指令发送成功后要通知的观察者(block实现)，以便消息发送调用者的额外要做的事 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 4.0
*/
+ (void)sendContactMessageAsync:(NSString *)friendUID withMeta:(ContactMeta *)contactMeta forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的位置消息发送给聊天中的好友（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param friendUID 接收者的uid
 * @param locationMeta 位置消息的内容就是LocationMeta对象
 * @param sucessObsExtra 消息指令发送成功后要通知的观察者(block实现)，以便消息发送调用者的额外要做的事 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 4.0
*/
+ (void)sendLocationMessageAsync:(NSString *)friendUID withMeta:(LocationMeta *)locationMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * "撤回"消息（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param friendUID 接收者的uid
 * @param content 消息撤回指令的内容就是RevokedMeta对象
 * @param sucessObsExtra 消息指令发送成功后要通知的观察者(block实现)，以便消息发送调用者的额外要做的事 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 4.3
 */
+ (void)sendRevokeMessageAsync:(NSString *)fingerPrint friendUID:(NSString *)friendUID withMeta:(RevokedMeta *)content forSucess:(ObserverCompletion)sucessObsExtra;

//-------------------------------------------------------------------------------
#pragma mark - （3）发出的消息或指令(同步)的方法

/**
 * 发送聊天消息（包括普通文本、图片消息、语音留言消息等）给指定user_id的用户.
 * <b>注意：</b>目前普通文本消息为了提升用户体验，提供QoS支持.
 *
 * @param user_id 当user_id=0时表示发送给服务器，否则发送给指定用户
 * @param message 要发送的文本消息
 * @return
 */
+ (int)sendChatMessage:(NSString *)user_id withMessage:(MsgBody4Friend *)message finger:(NSString *)fingerPrint;

/**
 * 发送添加好友的请求到服务端(假设此时的发起人是A).
 *
 * @param arm
 * @return
 */
+ (int)sendAddFriendRequestToServerMessage:(CMDBody4AddFriendRequest *)arm;

/**
 * 发送添加好友的请求到服务端(假设此时的发起人是A).
 *
 * @param friendUid 被加者的UID
 * @param saySomethingToHim 加好友时的验证消息（本消息实际使用时是可能为null的哦）
 * @param addSource 添加来源（如 search_uid, search_email, search_phone, card, group, random, qrcode），可为nil
 * @return
 * @see {@link #sendAddFriendRequestToServerMessage(Context, AddFriendRequestMeta)}
 */
+ (int)sendAddFriendRequestToServerMessage:(NSString *)friendUid say:(NSString *)saySomethingToHim addSource:(NSString *)addSource;

/**
 * 发送处理添加好友（同意）的请求到服务端(假设此时的发起人是B（即之前A要添加的好友）).
 *
 * @param arm
 * @return
 */
+ (int)sendProcessAdd_Friend_Req_B_To_Server_AGREEMessage:(CMDBody4ProcessFriendRequest *)pfrm;

/**
 * 发送处理添加好友（拒绝）的请求到服务端(假设此时的发起人是B（即之前A要添加的好友）).
 *
 * @param arm
 * @return
 */
+ (int)sendProcessAdd_Friend_Req_B_To_Server_REJECTMessage:(CMDBody4ProcessFriendRequest *)pfrm;

/**
 * 视频聊天：结束本次音视频聊天 .
 *
 * @param to_user_id 要接收指令的目标好友
 * @return 0 表示指令发送成功，否则返回的是错误码
 */
+ (int)sendVideoAndVoice_EndChatting_from_a:(NSString *)to_user_id local:(NSString *)localUserUid;
/**
 * 解析视频聊天：结束本次音视频聊天 .
 *
 * @param originalMsg 包含指点协议头和内容本身的原始消息文本
 * @return 对方的用户uid
 */
+(NSString *)pareseVideoAndVoice_EndChatting_from_a:(NSString *)originalMsg;

/**
 * 视频聊天：切换到纯音频聊天模式 .
 *
 * @param to_user_id 要接收指令的目标好友
 * @return 0 表示指令发送成功，否则返回的是错误码
 */
+ (int)sendVideoAndVoice_SwitchToVoiceOnly_from_a:(NSString *)to_user_id local:(NSString *)localUserUid;
/**
 * 解析视频聊天：切换到纯音频聊天模式 .
 *
 * @param originalMsg 包含指点协议头和内容本身的原始消息文本
 * @return 对方的用户uid
 */
+(NSString *)pareseVideoAndVoice_SwitchToVoiceOnly_from_a:(NSString *)originalMsg;

/**
 * 视频聊天：切换回音视频聊天模式 .
 *
 * @param to_user_id 要接收指令的目标好友
 * @return 0 表示指令发送成功，否则返回的是错误码
 */
+ (int)sendVideoAndVoice_SwitchToVoiceAndVideo_from_a:(NSString *)to_user_id local:(NSString *)localUserUid;
/**
 * 解析视频聊天：切换回音视频聊天模式 .
 *
 * @param originalMsg 包含指点协议头和内容本身的原始消息文本
 * @return 对方的用户uid
 */
+ (NSString *)pareseVideoAndVoice_SwitchToVoiceAndVideo_from_a:(NSString *)originalMsg;

/**
 * 视频聊天呼叫中：请求视频聊天(发起方A) .
 *
 * @param to_user_id 要接收指令的目标好友
 * @return 0 表示指令发送成功，否则返回的是错误码
 */
+ (int)sendVideoAndVoiceRequest_Requestting_from_a:(NSString *)to_user_id local:(NSString *)localUserUid;
/**
 * 解析视频聊天呼叫中：请求视频聊天(发起方A) .
 *
 * @param originalMsg 包含指点协议头和内容本身的原始消息文本
 * @return 对方的用户uid
 */
+ (NSString *)pareseVideoAndVoiceRequest_Requestting_from_a:(NSString *)originalMsg;

/**
 * 视频聊天呼叫中：取消视频聊天请求(发起发A).
 *
 * @param to_user_id 要接收指令的目标好友
 * @return 0 表示指令发送成功，否则返回的是错误码
 */
+ (int)sendVideoAndVoiceRequest_Abort_from_a:(NSString *)to_user_id local:(NSString *)localUserUid;
/**
 * 解析视频聊天呼叫中：取消视频聊天请求(发起发A).
 *
 * @param originalMsg 包含指点协议头和内容本身的原始消息文本
 * @return 对方的用户uid
 */
+ (NSString *)pareseVideoAndVoiceRequest_Abort_from_a:(NSString *)originalMsg;

/**
 * 视频聊天呼叫中：同意视频聊天请求(接收方B).
 *
 * @param to_user_id 要接收指令的目标好友
 * @return 0 表示指令发送成功，否则返回的是错误码
 */
+ (int)sendVideoAndVoiceRequest_Accept_to_a:(NSString *)to_user_id local:(NSString *)localUserUid;
/**
 * 解析视频聊天呼叫中：同意视频聊天请求(接收方B).
 *
 * @param originalMsg 包含指点协议头和内容本身的原始消息文本
 * @return 对方的用户uid
 */
+ (NSString *)pareseVideoAndVoiceRequest_Accept_to_a:(NSString *)originalMsg;

/**
 * 视频聊天呼叫中：拒绝视频聊天请求(接收方B).
 *
 * @param context
 * @param to_user_id 要接收指令的目标好友
 * @return 0 表示指令发送成功，否则返回的是错误码
 * @throws Exception
 */
+ (int)sendVideoAndVoiceRequest_Reject_to_a:(NSString *)to_user_id local:(NSString *)localUserUid;
/**
 * 解析视频聊天呼叫中：拒绝视频聊天请求(接收方B).
 *
 * @param originalMsg 包含指点协议头和内容本身的原始消息文本
 * @return 对方的用户uid
 */
+ (NSString *)pareseVideoAndVoiceRequest_Reject_to_a:(NSString *)originalMsg;

@end
