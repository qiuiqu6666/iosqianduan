//telegram @wz662
/**
 * 首页通知数据的封装类（注意：此数据仅用于UI显示，无需赋予复杂业务逻辑）.
 *
 * 数据的唯一性：以目前的数据定义，alarmType + dataId 即可定位该对象。
 *
 * @author Jack Jiang
 * @version 1.0
 */

#import <Foundation/Foundation.h>
#import "MsgBody4Guest.h"
#import "UserEntity.h"

@interface AlarmDto : NSObject

/** 首页"消息"item的类型 */
@property (nonatomic, assign) int alarmType;

/** 首页"消息"item对应的数据id（可以保存该类alarm的唯一id） */
@property (nonatomic, retain) NSString *dataId;

/** 首页"消息"item的标题文本 */
@property (nonatomic, retain) NSString *title;
/** 首页"消息"item的内容文本 */
@property (nonatomic, retain) NSString *alarmContent;

//@property (nonatomic, retain) NSString *date;
/** 首页"消息"item的日期时间，此字段值目前仅用于UI显示，不作它用 */
@property (nonatomic, retain) NSDate *date;
/** 首页"消息"item的未读数 */
@property (nonatomic, retain) NSString *flagNum;

///** 首页"消息"item的中存储的额外对象：此参数不是必须的 */
//// 注意：本对象是存放备用的，如果用assign的话，因深度拷贝后的新对象没有被使用，就会被
////      ARC释放，因而本对象应该使用retain，否则将发生对象被释放的问题。
//@property (nonatomic, retain) id extraObj;

/**
 * 本字段不作固定用途，对于不同类型的item，具体存放的数据内容可能有所不同，本字段可为null，并非必须字段！
 * <p>
 * 本字段当前用途记录：<br>
 * 【1】[v4.4]陌生人聊天消息时，存放的是对方头像文件名(md5的样式)，实现头像url相同情况下，在对方更新头像后能即时加载到新头像(而非仍用缓存)；
 *     该字段非必须，不为空时仅利于及时更新可能的最新头像而已，并无别的影响。
 */
@property (nonatomic, retain) NSString *extraString1;

/**
 * 服务端返回的未读消息数（通过接口 1008-26-7 查询会话列表时获得）。
 * <p>
 * 计算逻辑：统计"对方发给我的消息中，时间戳 > 我对该会话的已读水位线"的数量。
 * @since 11.x
 */
@property (nonatomic, assign) int unreadCount;

/// 1008-26-7 行末 `conversation_msg_seq`（与 `conv_seq` 同义，本会话最近一条消息序号上界）；持久化于 `alarms_history.conversation_msg_seq`。
@property (nonatomic, assign) long long conversationMsgSeq;

/** 首页"消息"item是否需要置顶（默认false，true表示需要置顶） */
@property (nonatomic, assign, getter = isAlwaysTop) BOOL alwaysTop;

/** 首页"消息"item是否已归档（默认false，true表示仅在归档列表显示） */
@property (nonatomic, assign, getter = isArchived) BOOL archived;

/** 首页"消息"item归档时间（iOS 秒级时间戳；未归档时为 0） */
@property (nonatomic, assign) long long archivedAt;

/**
 * 首页"消息"item是否需要显示"[有人@我]"提示标识（默认false，true表示需要显示）.
 */
@property (nonatomic, assign, getter = isAtMe) BOOL atMe;


///**
// * 陌生人（临时）聊天消息中，首页"消息"的item数据对象中extraObj里存放的就是MsgBody4Guest对象.
// *
// * @return
// */
//- (MsgBody4Guest *) getExtraObj_for_tempChatMessage;
//- (void) setExtraObj_for_tempChatMessage:(NSString *)extraObjJason;
//
///**
// * 一对一好友聊天消息中，首页"消息"的item数据对象中extraObj里存放的就是好友的个人信息对象.
// *
// * @return
// */
//- (RosterElementEntity *) getExtraObj_for_reviceMessage;
//- (void) setExtraObj_for_reviceMessage:(NSString *)extraObjJason;
//
///**
// * 添加好友被拒时，首页"消息"的item数据对象中extraObj里存放的就是拒者信息.
// *
// * @return
// */
//- (RosterElementEntity *) getExtraObj_for_addFriendBeReject;
//
///**
// * 群组聊天时，首页"消息"的item数据对象中extraObj里存放的就是群组id.
// *
// * @return
// */
//- (NSString *)getExtraObj_for_groupChatMessage;
//- (void) setExtraObj_for_groupChatMessage:(NSString *)extraObjJason;

@end
