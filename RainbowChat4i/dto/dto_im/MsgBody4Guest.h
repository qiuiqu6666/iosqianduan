//telegram @wz662
#import "MsgBodyRoot.h"

@interface MsgBody4Guest : MsgBodyRoot

/** 消息发送人的昵称 */
@property (nonatomic, retain) NSString *nickName;

//// 非持久化字段：本字段不对应于DB中的任何字段，仅用于客户端使用
//// 用途描述：目前用于APP首页系统消息栏里收到临时消息时，从服务端下载了
////             用户头像后，把服务端同时返回的该用户头像文件名存起来（以便
////            查找客户端的本地缓存时使用）。为什么在在此时存起来呢？因为
////            临时聊天的用户之间没有把发送人存放于服务端的头像文件名传过
////            去(可以传，但每1条消息都得传就太订烦了)，为了从服务端取到用
////            户头像后下次只需要从SD卡缓存中取，所以就有了本属性用于保存它
////            了仅此而已
//@property (nonatomic, retain) NSString *userAvatarFileName;

/**
 * 构造陌生人聊天（临时聊天）消息协议体的DTO对象.
 *
 * @msgType 聊天消息类型
 * @param srcUserUid 发送方的uid
 * @param srcNickName 发送方的昵称
 * @param friendUid 要发送到的用户id
 * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
 * @return 新的MsgBody4Guest对象
 */
+ (MsgBody4Guest *) constructGuestChatMsgBody:(int)msgType srcUserUid:(NSString *)srcUserUid srcNickName:(NSString *)srcNickName friendUid:(NSString *)friendUid msg:(NSString *)msg;

/**
 * MsgBody4Guest 深度对象克隆方法实现。
 *
 * @return 克隆完成后的新对象
 * @since 4.3
 */
- (MsgBody4Guest *)clone;

@end
