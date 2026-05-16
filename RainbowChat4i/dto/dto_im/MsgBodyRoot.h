//telegram @wz662
/**
 * 消息body根类：普通聊天消息（指的是区别于非聊天消息的指令）中提炼出来的共有
 * 消息体字段属性。
 * <p>
 * 即聊天数据从MobileIMSDK底层发送时，会将本对象转JSON字串后，作为
 * Protocal的dataContent数据进行传输。
 * <p>
 * <b>理论上：</b>RainbowChat中用户可读的聊天消息（包括单聊、陌生人聊、世界频道、群聊）
 * 的消息body都应是本类的子类，否则服务端的离线处理将不会进行离线消息持久化（前提
 * 是需要离线存储的话，比如世界频道已经从逻辑上不需要支持离线的）。
 *
 * @author Jack Jiang
 * @since 4.3
 */

#import <Foundation/Foundation.h>
#import "QuoteMeta.h"

//************************************************* 聊天模式常量定义 START
/** 聊天模式类型：正常聊天 */
#define CHAT_TYPE_FREIDN_CHAT  0

/** 聊天模式类型：临时聊天(陌生人聊天) */
#define CHAT_TYPE_GUEST_CHAT   1

/** 聊天模式类型：普通群聊或世界频道（当groupid=-1时就是世界频道聊天） */
#define CHAT_TYPE_GROUP_CHAT   2
//************************************************* 聊天模式常量定义 END

//************************************************* 消息类型常量定义 START
/** 聊天消息类型之：普通文字消息 */
#define TM_TYPE_TEXT          0

/** 聊天消息类型之：图片消息（即消息内容就是存放于服务端的磁盘图片文件名） */
#define TM_TYPE_IMAGE         1

/** 聊天消息类型之：语音留言消息（即消息内容就是存放于服务端的语音留言文件名） */
#define TM_TYPE_VOICE         2

/**
 * 聊天消息类型之：赠送的礼品消息（即消息内容就是对应礼品的ident字符串）。
 * 真正赠送的礼品，这个过程是要扣积分的哦。
 * @since 2.5 */
#define TM_TYPE_GIFT_SEND     3

/**
 * 聊天消息类型之：索取礼品消息（即消息内容就是对应礼品的ident字符串） 。
 * 只是索取礼品，跟普通文本消息是等同的，它不步及积分及相关。
 * @since 2.5 */
#define TM_TYPE_GIFT_GET      4

/**
 * 聊天消息类型之：文件消息.
 * @since 2.1 */
#define TM_TYPE_FILE          5

/**
 * 聊天消息类型之：短视频消息.
 * @since 2.1 */
#define TM_TYPE_SHORTVIDEO    6

/**
 * 聊天消息类型之：名片消息（包括个人名片、群名片）.
 * @since 4.0 */
#define TM_TYPE_CONTACT       7

/**
 * 聊天消息类型之：位置消息.
 * @since 4.0 */
#define TM_TYPE_LOCATION      8

/**
 * 聊天消息类型之：实时音视频记录消息（用于聊天界面中显示实时音视频的主叫、被叫等结果情况）.
 * @since 8.0 */
#define TM_TYPE_VOIP_RECORD      9

/** 聊天消息类型之：红包消息（点击可抢红包）. @since 钱包对接 */
#define TM_TYPE_RED_PACKET       10

/** 聊天消息类型之：转账消息. @since 钱包对接 */
#define TM_TYPE_TRANSFER         11

/**
 * 聊天消息类型之：系统消息或提示信息（此类消息通常由服务器即f="0"的用户发出）.
 * @since 1.2 */
#define TM_TYPE_SYSTEAM_INFO  90

/**
 * 聊天消息类型之：“消息撤回”消息，这是一个特殊的“消息”，对于客户端而言，
 * 收到此消息后，可以理解为——先删掉原消息并用本消息“替换”之.
 * @since 7.3 */
#define TM_TYPE_REVOKE        91
//************************************************* 消息类型常量定义 END


@interface MsgBodyRoot : QuoteMeta

/**
 * From user uid（即消息发送者的id）. */
@property (nonatomic, retain) NSString *f;
/**
 * To user id or group id。
 * <p>
 * <b>即消息接收者的id：</b><br>
 *  1）在群聊消息时，本字段存放的是群组id；<br>
 *  2）普通一对的聊天时才是用户uid。 */
@property (nonatomic, retain) NSString *t;
/**
 * 消息内容字段（为了简化复杂性，建议保证只放纯文本）。 */
@property (nonatomic, retain) NSString *m;

/**
 * 聊天模式类型（默认值为 {@link #CHAT_TYPE_FREIDN$CHAT} ）.
 * @since RainbowChat 4.3 */
@property (nonatomic, assign) int cy;

/**
 * 聊天消息类型（默认值为 {@link #TYPE_TEXT} ）.
 * @since RainbowChat 2.2 */
@property (nonatomic, assign) int ty;


+ (MsgBodyRoot *)parseFromSender:(NSString *)originalMsg;

@end
