//telegram @wz662
/**
 * 离线消息的数据包装传输类。
 * <p>
 * <b>此DTO传输的数据基本对应于数据库表“离线聊天记录/MISSU_OFFLINE_HISTORY”.</b>
 *
 * @author Jack Jiang
 * @since 4.3
 */

#import <Foundation/Foundation.h>
#import "QuoteMeta.h"

@interface OfflineMsgDTO : QuoteMeta

/** 消息发送人的用户id */
@property (nonatomic, retain) NSString *user_uid;

/**
 * 消息发送人的昵称。
 * <p>
 * 为何要把消息发送人的昵称取出来呢？原因是当用户取到离线消息前，可能已经把该好友从好友列表
 * 中删除了，那么此条离线消息到达客户端时将自动以陌生人消息的形式显示出来（好友列表里没这个人了嘛），
 * 此时这个昵称就有用了。
 */
@property (nonatomic, retain) NSString *nickName;

/** 消息接收人的用户id */
@property (nonatomic, retain) NSString *friend_user_uid;

/**
 * 聊天消息类型.
 *
 * @see MsgBodyRoot
 */
@property (nonatomic, assign) int msg_type;

/**
 * 消息内容.
 */
@property (nonatomic, retain) NSString *msg_content;

/**
 * 消息发生时间戳。
 * <p>
 * 本时间戳为GMT标准时间，解决跨国跨时区问题，用于UI时客户端需要转换成自已
 * 的时区后再使用哦，此字段存放的是java版无时区时间戳，形如：1510491984536，此值除以1000后即是ios系统上的标准时间戳值哦） 。
 */
@property (nonatomic, retain) NSString *history_time2;

/**
 * 聊天模型类型。
 * @see MsgBodyRoot
 */
@property (nonatomic, retain) NSString *chat_type;

/**
 * 消息发生的群组id。
 * <p>
 * 本字段只在聊天类型为群组时有意义，否则它的值应该是null.
 */
@property (nonatomic, retain) NSString *group_id;
/**
 * 消息发生的群组名称。
 * <p>
 * 本字段只在聊天类型为群组时有意义，否则它的值应该是null.
 */
@property (nonatomic, retain) NSString *group_name;

/**
 * 消息内容2.
 *
 * <p>
 * 目前用途：自2013-12-19日起，一对一正式聊天中的普通文本、图片
 * 等消息的离线消息存放在本字段的是QoS的指纹码。
 *
 * <p>
 * 说明：目前本字段仅用在iOS端（详见ios端的说明字段）、Android端，Web端暂无需使用。iOS端之所以要使用，
 * 是因为有一种特殊情况下需要对离线消息作去重，这个情况发生于：当APP退到后台的5秒周期内(iOS系统允许的现场保存时间)，
 * 对方恰好来消息时，而在这5秒内iOS系统允许收网络数据但不允许发网络数据即ACK确认包，导致对方的QoS送达算法判定为不可
 * 达而重传，且在重传时本用户在服务端的会话恰好已到超时时间——即离线，所以此条消息又被存入了离线消息——那么此条消息对于
 * 手机端来说已无意义了。这个情况的发生窗口期只有5秒，且跟服务端的超时时间是重叠在一起的，属于非常极端的bug。
 */
@property (nonatomic, retain) NSString *msg_content2;

/**
 * 群聊消息扩散写前原始消息的指纹码。
 * <p>
 * 此指纹码目前主要用于消息“撤回”功能时。
 * 且仅对由“人”发起的正常聊天消息有意义，对{@link MsgType#TYPE_SYSTEAM$INFO}类型的消息无意义。
 *
 * @see MsgBody4Group
 * @since 7.3
 */
@property (nonatomic, retain) NSString *parent_fp;

/**
 * 此条消息的"@"对象数组（数组单元是被“@”者的uid）。
 * <p>
 * 本字段只在聊天类型为群组时有意义，否则它的值应该是null.
 *
 * @since 11.0
 */
@property (nonatomic, retain) NSArray<NSString *> *be_at;


/** 返回消息发出时间的”HH:mm“形式（使用本地默认时区） */
- (NSString *)getHistoryTime2ForDefaultTimeZone_hhmm;

/** 返回消息发出时间的”MM-dd HH:mm“形式（使用本地默认时区） */
- (NSString *)getHistoryTime2ForDefaultTimeZone;

/** 返回消息发出时间的ios NSDate对象形式 */
- (NSDate *)getHistoryTime2Date;


@end
