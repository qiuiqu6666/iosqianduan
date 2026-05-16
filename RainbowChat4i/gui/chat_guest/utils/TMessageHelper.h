//telegram @wz662
#import <Foundation/Foundation.h>
#import "MsgBody4Guest.h"
#import "UserEntity.h"
#import "UserProtocalsType.h"
#import "FileMeta.h"
#import "ContactMeta.h"
#import "LocationMeta.h"
#import "RevokedMeta.h"

@interface TMessageHelper : NSObject


//-------------------------------------------------------------------------------
#pragma mark - （1）收到的消息/协议解析方法

/**
 * 解析临时聊天消息：由服务端转发给接收人B的【步骤2/2】.
 *
 * <p>
 * 当然，此消息被接收到的前提条件是B用户此时是在线的（否则临时聊天消息将服务端被存储到DB中（直到本地用户下次上线））。
 */
+ (MsgBody4Guest *)parseTempChatMsg_SERVER_TO_B_Message:(NSString *)originalMsg;


//-------------------------------------------------------------------------------
#pragma mark - （2）发出的消息或指令(异步)的方法

/**
 * 将指导定的图片消息发送给聊天中的陌生人（异步方式）.
 * <p>
 * 说明：安卓2.3及以后系统中规定：发送网络数据须在单独的线程中，因本方法的RainbowChat很常，因为
 * 默认为开发者提供了异步的实现，就无需单在代码中再使用AsyncTask来包装一遍了，仅此而已。
 * </p>
 *
 * @param tempChatFriendName 本参数用于已经加陌生人后的提示信息而已，本参数可为null哦（非必须）
 * @param message 文本消息，如果该文本为null或空字符串则不会真正执行发送过程
 */
+ (void) sendPlainTextMessageAsync:(NSString *)tempChatFriendUID
                            tuname:(NSString *)tempChatFriendName
                       withMessage:(NSString *)message
                             quote:(QuoteMeta *)quoteMeta
                         forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指导定的图片消息发送给聊天中的陌生人（异步方式）.
 *
 * @param tempChatFriendUID 对方的uid
 * @param tempChatFriendName 本参数用于已经加陌生人后的提示信息而已，本参数可为null哦（非必须）
 * @param imageFilePath 文本消息，也即是图片的文件名，如果该文本为null或空字符串则不会真正执行发送过程
 * @param quoteMeta  消息引用信息（当前仅用于文本消息时），此字段可为空（表示本条无引用消息）
 * @param sucessObsExtra 消息发送成功后要通知的观察者，本参数可为null
 */
+ (void) sendImageMessageAsync:(NSString *)tempChatFriendUID
                        tuname:(NSString *)tempChatFriendName
                     withImage:(NSString *)imageFilePath
                            fp:(NSString *)fingerPring
                     forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指导定的语音消息发送给聊天中的陌生人（异步方式）.
 *
 * @param tempChatFriendUID 对方的uid
 * @param tempChatFriendName 本参数用于已经加陌生人后的提示信息而已，本参数可为null哦（非必须）
 * @param voiceFileName 要发送的语音留言录音文件名
 * @param sucessObsExtra 消息发送成功后要通知的观察者，本参数可为null
 */
+ (void) sendVoiceMessageAsync:(NSString *)tempChatFriendUID
                        tuname:(NSString *)tempChatFriendName
                     withVoice:(NSString *)voiceFileName
                            fp:(NSString *)fingerPring
                     forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的文件消息发送给聊天中的陌生人（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param tempChatFriendUID 接收者的uid
 * @param tempChatFriendName 本参数用于已经加陌生人后的提示信息而已，本参数可为null哦（非必须）
 * @param content 文件消息的内容就是FileMeta对象
 * @param fingerPring 消息指纹码（即全局唯一ID）
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 2.1
 */
+ (void)sendFileMessageAsync:(NSString *)tempChatFriendUID tuname:(NSString *)tempChatFriendName withMeta:(FileMeta *)content fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的短视频消息发送给聊天中的陌生人（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param tempChatFriendUID 接收者的uid
 * @param tempChatFriendName 本参数用于已经加陌生人后的提示信息而已，本参数可为null哦（非必须）
 * @param fileMeta 文件消息的内容就是FileMeta对象
 * @param fingerPring 消息指纹码（即全局唯一ID）
 * @param sucessObsExtra 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 2.1
 */
+ (void)sendShortVideoMessageAsync:(NSString *)tempChatFriendUID tuname:(NSString *)tempChatFriendName withMeta:(FileMeta *)fileMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的短视频消息发送给聊天中的陌生人（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param tempChatFriendUID 接收者的uid
 * @param tempChatFriendName 本参数用于已经加陌生人后的提示信息而已，本参数可为null哦（非必须）
 * @param contactMeta 名片消息的内容就是ContactMeta对象
 * @param sucessObsExtra 消息指令发送成功后要通知的观察者(block实现)，以便消息发送调用者的额外要做的事 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 4.0
*/
+ (void)sendContactMessageAsync:(NSString *)tempChatFriendUID tuname:(NSString *)tempChatFriendName withMeta:(ContactMeta *)contactMeta forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * 将指定的位置消息发送给聊天中的陌生人（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param tempChatFriendUID 接收者的uid
 * @param tempChatFriendName 本参数用于已经加陌生人后的提示信息而已，本参数可为null哦（非必须）
 * @param locationMeta 位置消息的内容就是LocationMeta对象
 * @param sucessObsExtra 消息指令发送成功后要通知的观察者(block实现)，以便消息发送调用者的额外要做的事 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 4.0
*/
+ (void)sendLocationMessageAsync:(NSString *)tempChatFriendUID tuname:(NSString *)tempChatFriendName withMeta:(LocationMeta *)locationMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra;

/**
 * "撤回"消息（异步方式）.
 * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param tempChatFriendUID 接收者的uid
 * @param tempChatFriendName 本参数用于已经加陌生人后的提示信息而已，本参数可为null哦（非必须）
 * @param content 消息撤回指令的内容就是RevokedMeta对象
 * @param sucessObsExtra 消息指令发送成功后要通知的观察者(block实现)，以便消息发送调用者的额外要做的事 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 * @since 4.3
 */
+ (void)sendRevokeMessageAsync:(NSString *)fingerPrint tuid:(NSString *)tempChatFriendUID tuname:(NSString *)tempChatFriendName
                      withMeta:(RevokedMeta *)content forSucess:(ObserverCompletion)sucessObsExtra;


//------------------------------------------------------------------------
#pragma mark - （3）消息发送同步实现方法

///**
// * 发送聊天消息（包括普通文本、图片消息、语音留言消息等）给指定user_id的用户.
// * <b>注意：</b>目前普通文本消息为了提升用户体验，提供QoS支持.
// *
// * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
// * @return 返回发送状态码，参见 ErrorCode.h 的定义
// */
//+ (int)sendChatMessage:(int)msgType to:(NSString *)friendUid msg:(NSString *)msg fp:(NSString *)fingerPrint;
//
///**
// * 发送临时聊天消息：由发送人A发给服务端【步骤1/2】.
// *
// * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
// * @return 返回发送状态码，参见 ErrorCode.h 的定义
// */
//+ (int)sendTempChatMsg_A_TO_SERVER_Message:(int)msgType to:(NSString *)friendUid msg:(NSString *)msg qos:(BOOL)QoS fp:(NSString *)fingerPrint;

/**
 * 发送临时聊天消息：由发送人A发给服务端【步骤1/2】.
 *
 * @param tcmd 临时聊天消息体数据封装对象
 * @return 返回发送状态码，参见 ErrorCode.h 的定义
 */
+ (int)sendTempChatMsg_A_TO_SERVER_Message:(MsgBody4Guest *)tcmd qos:(BOOL)QoS fp:(NSString *)fingerPrint;


//------------------------------------------------------------------------
#pragma mark - （4）其它方法

/**
 * 构造临时聊天DTO对象.
 *
 * @param friendUid 对方的uid
 * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
 * @return 新对象
 */
+ (MsgBody4Guest *) constructTempChatMsgDTOForSend:(int)msgType
                                         friendUid:(NSString *)friendUid
                                           withMsg:(NSString *)msg;

/**
 * 构造临时聊天DTO对象.
 *
 * @param srcUserUid 发送方的uid
 * @param srcNickName 发送方的昵称
 * @param friendUid 接收方的uid
 * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
 * @return 新对象
 */
+ (MsgBody4Guest *) constructTempChatMsgDTO:(int)msgType
                                 srcUserUid:(NSString *)srcUserUid
                                srcNickName:(NSString *)srcNickName
                                  friendUid:(NSString *)friendUid
                                    withMsg:(NSString *)msg;

@end
