//telegram @wz662
/**
 * 群聊天相关消息/指令的发送和解析方法。
 */

#import <Foundation/Foundation.h>
#import "MsgBody4Group.h"
#import "UserProtocalsType.h"
#import "CMDBody4GroupNameChangedNotification.h"
#import "CMDBody4MyselfBeInvitedGroupResponse.h"
#import "FileMeta.h"
#import "ContactMeta.h"
#import "LocationMeta.h"
#import "RevokedMeta.h"

@interface GMessageHelper : NSObject


//-------------------------------------------------------------------------------
#pragma mark - （1）收到的消息/协议解析方法

/**
 * 解析群聊聊天消息：由服务端转发给接收人B的【步骤2/2】.
 *
 * <p>
 * 当然，此消息被接收到的前提条件是B用户此时是在线的（否则临时聊天消息将服务端被存储到DB中（直到本地用户下次上线））。
 *
 * @param originalMsg
 * @return
 */
+ (MsgBody4Group *)parseGroupChatMsg_SERVER_TO_B_Message:(NSString *)originalMsg;

/**
 * 解析群聊系统指令：“我”加群成功后通知“我”（即被加群者）（由Server发出），
 * 通知接收人可能是在创建群或群建好后邀请进入的.
 *
 * @param originalMsg
 * @return
 */
+ (CMDBody4MyselfBeInvitedGroupResponse *) parseResponse4GroupSysCMD4MyselfBeInvited:(NSString *)originalMsg;

/**
 * 解析群聊系统指令：群聊时，向所有(除修改者)的群员通知群名被修改的通知协议内容（由Server发出），
 * 通知接收人可能是在创建群或群建好后邀请进入的.
 *
 * @param originalMsg
 * @return
 */
+ (CMDBody4GroupNameChangedNotification *) parseResponse4GroupSysCMD4GroupNameChanged:(NSString *)originalMsg;


//-------------------------------------------------------------------------------
#pragma mark - （2）发出的消息或指令(异步)的方法

/**
 * 将指定的纯文消息发送给聊天中的好友
 * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param toGid 群id
 * @param message 要发送的消息文本（如果该文本为null或空字符串则不会真正执行发送过程）
 * @param atUsers 群聊消息的“@”对象数组（数组单元为被“@”者的uid），用于客户端实现特别提醒
 * @param quoteMeta  消息引用信息（当前仅用于文本消息时），此字段可为空（表示本条无引用消息）
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 */
+ (void) sendPlainTextMessageAsync:(NSString *)toGid
                       withMessage:(NSString *)message
                                at:(NSArray<NSString *> *)atUsers
                             quote:(QuoteMeta *)quoteMeta
                         forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指导定的图片消息发送给指定群组（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param imageFileName 要发送的图片文件名
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 */
+ (void) sendImageMessageAsync:(NSString *)toGid
                     withImage:(NSString *)imageFileName
                            fp:(NSString *)fingerPring
                     forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指导定的语音消息发送给指定群组（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param voiceFileName 要发送的语音留言录音文件名
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 */
+ (void) sendVoiceMessageAsync:(NSString *)toGid
                     withVoice:(NSString *)voiceFileName
                            fp:(NSString *)fingerPring
                     forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的文件消息发送给群（异步方式））.
 * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param fileMeta 要发送的文件元数据
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
*/
+ (void)sendFileMessageAsync:(NSString *)toGid withMeta:(FileMeta *)fileMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;

/**
* 将指定的短视频消息发送给聊天中的群（异步方式）.
* 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
*
* @param toGid 目标群
* @param fileMeta 文件消息的内容就是FileMeta对象
* @param fingerPring 消息指纹码（即全局唯一ID）
* @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
* @since 2.1
*/
+ (void)sendShortVideoMessageAsync:(NSString *)toGid withMeta:(FileMeta *)fileMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的短视频消息发送给聊天中的群（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param toGid 目标群
 * @param contactMeta 名片消息的内容就是ContactMeta对象
 * @param sucessObsExtra 消息指令发送成功后要通知的观察者(block实现)，以便消息发送调用者的额外要做的事 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 4.0
*/
+ (void)sendContactMessageAsync:(NSString *)toGid withMeta:(ContactMeta *)contactMeta forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的位置消息发送给聊天中的群（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param toGid 目标群
 * @param locationMeta 位置消息的内容就是LocationMeta对象
 * @param sucessObsExtra 消息指令发送成功后要通知的观察者(block实现)，以便消息发送调用者的额外要做的事 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 4.0
*/
+ (void)sendLocationMessageAsync:(NSString *)toGid withMeta:(LocationMeta *)locationMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * "撤回"消息（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param content 消息撤回指令的内容就是RevokedMeta对象
 * @since 4.3
 */
+ (void)sendRevokeMessageAsync:(NSString *)fingerPrint gid:(NSString *)toGid withMeta:(RevokedMeta *)content forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的消息发送给指定群组（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param messageType 参见  {@link MsgBody4Root}中的文本消息类型
 * @param gid 要发送到的群id
 * @param message 文本消息，如果该文本为null或空字符串则不会真正执行发送过程
 * @param atUsers 群聊消息的“@”对象数组（数组单元为被“@”者的uid），用于客户端实现特别提醒
 * @param fingerPring 消息指纹码（即全局唯一ID）
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 */
+ (void)sendMessageAsync:(int)messageType gid:(NSString *)toGid withMessage:(NSString *)message at:(NSArray<NSString *> *)atUsers finger:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;


//------------------------------------------------------------------------
#pragma mark - （3）消息发送同步实现方法

///**
// * 发送聊天消息（包括普通文本、图片消息、语音留言消息等）给指定user_id的用户.
// * <b>注意：</b>目前普通文本消息为了提升用户体验，提供QoS支持.
// *
// * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
// * @return 返回发送状态码，参见 ErrorCode.h 的定义
// */
//+ (int) sendChatMessage:(int)msgType gid:(NSString *)toGid msg:(NSString *)msg fp:(NSString *)fingerPrint;
///**
// * 发送临时聊天消息：由发送人A发给服务端【步骤1/2】.
// *
// * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
// * @return 返回发送状态码，参见 ErrorCode.h 的定义
// */
//+ (int) sendBBSChatMsg_A_TO_SERVER_Message:(int)msgType
//                                       gid:(NSString *)toGid
//                                       msg:(NSString *)msg
//                                       qos:(BOOL)QoS
//                                        fp:(NSString *)fingerPrint;
/**
 * 发送临时聊天消息：由发送人A发给服务端【步骤1/2】.
 *
 * @return 返回发送状态码，参见 ErrorCode.h 的定义
 */
+ (int) sendBBSChatMsg_A_TO_SERVER_Message:(MsgBody4Group *)tcmd qos:(BOOL)QoS fp:(NSString *)fingerPrint;

/**
 * 发送消息给指定user_id的用户.
 *
 * @param message 要发送的文本消息
 * @return 返回发送状态码，参见 ErrorCode.h 的定义
 */
+ (int) sendMessage:(NSString *)message qos:(BOOL)QoS fp:(NSString *)fingerPrint typeu:(int)typeu;


//------------------------------------------------------------------------
#pragma mark -（4）其它方法

/**
 * 构造临时聊天DTO对象.
 *
 * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
 * @param atUsers 群聊消息的“@”对象数组（数组单元为被“@”者的uid），用于客户端实现特别提醒
 * @return 构建新的对象
 */
+ (MsgBody4Group *) constructGroupChatMsgBodyForSend:(NSString *)parentFp msgType:(int)msgType gid:(NSString *)toGid msg:(NSString *)msg at:(NSArray<NSString *> *)atUsers;

@end
