//telegram @wz662
/**
 * 指令body：群聊/世界频道聊天消息的数据内容封装类.
 * <p>
 * 即聊天数据从MobileIMSDK底层发送时，会将本对象转JSON字串后，作为
 * Protocal的dataContent数据进行传输。
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 * @version 1.0
 * @since 4.3
 */

#import "MsgBodyRoot.h"
#import "MsgBody4Guest.h"

@interface MsgBody4Group : MsgBody4Guest

/**
 * 群聊消息扩散写前原始消息的指纹码。
 * <p>
 * 此指纹码目前主要用于消息“撤回”功能时。
 * 且仅对由“人”发起的正常聊天消息有意义，对{@link MsgType#TYPE_SYSTEAM$INFO}类型的消息无意义。
 */
@property (nonatomic, retain) NSString *parentFp;

/**
 * 群聊消息的“@”对象数组（数组单元为被“@”者的uid），用于客户端实现特别提醒。
 *
 * @since 9.0
 */
@property (nonatomic, retain) NSArray<NSString *> *at;

/**
 * 大群读扩散（group_mode=2）：服务端为该条消息分配的 seq，与 1016-25-25 / MT45 轻量 pull 同源对齐（对接文档 v4.1）。
 * 在线全文推送时由服务端写入 MsgBody JSON；未设置时为 0。
 */
@property (nonatomic, assign) long long groupSeq;

/**
 * 构造世界频道/普通群聊系统消息协议体的DTO对象.
 *
 * @param toGid 要发送到的群id
 * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
 * @return 新的MsgBody4Group对象
 */
+ (MsgBody4Group *)constructGroupSystenMsgBody:(NSString *)toGid msg:(NSString *)msg;

/**
 * 构造世界频道/普通群聊消息协议体的DTO对象.
 *
 * @msgType 聊天消息类型
 * @param srcUserUid 发送方的uid
 * @param srcNickName 发送方的昵称
 * @param toGid 发发送到的群id
 * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
 * @param parentFp 群聊消息扩散写前原始消息的指纹码（此指纹码目前主要用于消息“撤回”功能时）
 * @param atUsers 群聊消息的“@”对象数组（数组单元为被“@”者的uid），用于客户端实现特别提醒
 * @return 新的MsgBody4Group对象
 */
+ (MsgBody4Group *)constructGroupChatMsgBody:(int)msgType srcUserUid:(NSString *)srcUserUid srcNickName:(NSString *)srcNickName toGid:(NSString *)toGid msg:(NSString *)msg parentFp:(NSString *)parentFp at:(NSArray<NSString *> *)atUsers;

@end
