//telegram @wz662
/**
 * 首页“消息”数据提供者实现类.
 * <p>
 * 提供各种首页消息类型的数据组织和管理功能.
 *
 * @author Jack Jiang, 2017-11-15
 * @version 1.0
 */

#import <Foundation/Foundation.h>
#import "NSMutableArrayObservableEx.h"
#import "UserEntity.h"
#import "AlarmDto.h"
#import "BBSAlarmDataObservable.h"
#import "MyDataBase.h"

@interface AlarmsProvider : NSObject


//---------------------------------------------------------------------------------
#pragma mark - 【1】通用方法定义

- (void) clear;

/** 仅将会话类型的 AlarmDto 插入列表（用于登录时先展示本地会话）。调用前需已 clearChatSessionAlarmsOnly。 */
- (void)insertChatSessionAlarmsOnly:(NSArray<AlarmDto *> *)list notify:(BOOL)notify;

/** 当前列表中聊天会话（好友/陌生人/群聊）条数，用于判断是否已被云端/先本地覆盖，避免兜底本地加载覆盖已展示列表。 */
- (NSUInteger)chatSessionCount;

/** 当前列表中已归档聊天会话（好友/陌生人/群聊）条数。 */
- (NSUInteger)archivedChatSessionCount;

/**
 * 载入首页“消息”的历史数据。
 * <p>
 * 注意：本方法在APP登陆成后只需要调用1次即可，表示加载上次保存的数据、预定义数据等。
 */
- (void) loadDatasOnce;

/**
 * 本类中不推荐直接使用 {@link #alarmMessageData}，请务必使用本方法来获取之.
 * <p>
 * 约定：返回的列表与 UIKit 同线程访问；除通过本类实例方法改写外，不要在工作线程对
 * getDataList 等与列表相关的操作并发读写（本类公开实例方法已对非主线程调用做主线程收口）。
 *
 * @return
 */
- (NSMutableArrayObservableEx *) getAlarmsData;

/**
 * 载入系统预定义的APP中写死的首页”消息“.
 */
- (void) loadSystemDefineAlarms;

- (AlarmDto *)addAlarm:(AlarmDto *)amd;

/**
 *
 * @param amd
 * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所以可以将此参数理解为更新完数据模型后是否要刷新ui
 */
- (AlarmDto *)addAlarm:(AlarmDto *)amd notify:(BOOL)notifyObserver;

- (AlarmDto *)addAlarm:(int) index withDto:(AlarmDto *)amd notify:(BOOL)notifyObserver;

/**
 * 删除指定索引位置的消息.
 *
 * @param index 索引位置
 * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所
 * 以可以将此参数理解为更新完数据模型后是否要刷新ui
 */
- (void) removeAlarm:(int)index notify:(BOOL)notifyObserver;

/**
 * 删除指定索引位置的通知.
 *
 * @param index 通知数据所在数组的索引位置
 * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所
 * 以可以将此参数理解为更新完数据模型后是否要刷新ui
 * @param deleteAlarmLocalData true表示将首页"消息"的item从本地的sqlite中也删除（通常为了离线使用，首页"消息"的item
 *                             都要存放本地sqlite），否则表示仅删除内存模型（这种情况主要用于将此item移位，比如置顶
 *                             或取消置顶功能时）
 * @param deleteChatMessageLocalDatas 本参数仅在deleteAlarmLocalData==true时生效！本参数为true表示要删除存储
 *                                    在本地聊天消息sqlite的历史数据（注意：仅针对聊天消息哦），
 *                                    否则表示不删除。比如加好友成功后，之前临时聊天的消息已存储在本地此时就不需
 *                                    要删除了，这样正式聊天时就能看到之前的陌生人聊天消息，体验会好不少哦。
 */
- (void) removeAlarm:(int)index
              notify:(BOOL)notifyObserver
deleteAlarmLocalData:(BOOL)deleteAlarmLocalData
     deleteLocalData:(BOOL)deleteChatMessageLocalDatas;

/**
 * 仅清空聊天消息记录。
 *
 * @param alarmType 首而"消息"类型
 * @param dataId "消息"id
 * @param deleteLocaleDatas 是否只清除内存聊天消息，true表示不仅清内存还清sqlite中的聊天消息记录
 */
+ (void)clearHistoryMessages:(int)alarmType dataId:(NSString *)dataId deleteLocaleDatas:(BOOL)deleteLocaleDatas db:(FMDatabase *)db notify:(BOOL)notifyObserver;

/**
 * 更新指定索引位置的“通知”上的标题（本方法只更新数据模型本身，不涉及sqlite的同步）。
 *
 * @param index 通知数据所在数组的索引位置
 * @param newTitle 新标题
 * @return 成功更新后返回更新后的AlarmDto对象引用，否则返回null
 * @since 4.3
 */
- (AlarmDto *)updateAlarmTitle:(int)index newTitle:(NSString *)newTitle;

/**
 * 更新指定item上的标题（并支持是否更新sqlite）。
 *
 * @param alarmType 类型
 * @param dataId id号
 * @param newTitle 新标题
 * @param needUpdateSqlite true表示需要同时更新本地sqlite，否则表示不需要
 * @since 4.3
 */
- (void)updateAlarmTitle:(int)alarmType dataId:(NSString *)dataId newTitle:(NSString *)newTitle needUpdateSqlite:(BOOL)needUpdateSqlite;

/**
 * 更新指定索引位置的“通知”上的标题、extra1String字段（本方法只更新数据模型本身，不涉及sqlite的同步）。
 * <p>
 * 注：本方法目前主要用于查看陌生人信息时，能及时用最新资料更新这两个字段，确保在不重启APP的情况下能及时显示最新。
 *
 * @param index 通知数据所在数组的索引位置
 * @param newTitle 新标题
 * @return 成功更新后返回更新后的AlarmDto对象引用，否则返回null
 */
- (AlarmDto *)updateAlarmTitleAndExtra1:(int)index newTitle:(NSString *)newTitle newExtra1:(NSString *)newExtra1;

/**
 * 更新指定item上的标题、extra1String字段（并支持是否更新sqlite）。
 * <p>
 * 注：本方法目前主要用于查看陌生人信息时，能及时用最新资料更新这两个字段，确保在不重启APP的情况下能及时显示最新。
 *
 * @param alarmType 类型
 * @param dataId id号
 * @param newTitle 新标题
 * @param needUpdateSqlite true表示需要同时更新本地sqlite，否则表示不需要
 */
- (void)updateAlarmTitleAndExtra1:(int)alarmType dataId:(NSString *)dataId newTitle:(NSString *)newTitle newExtra1:(NSString *)newExtra1 needUpdateSqlite:(BOOL)needUpdateSqlite;

/**
 * 读取extra1String字段，目前该字段主要是用于存放最新的临时聊正者的头像文件名。
 *
 * @param alarmType 类型
 * @param dataId id号
 * @return extra1String字段
 */
- (NSString *)getExtra1String:(int)alarmType dataId:(NSString *)dataId;

/**
 * 更新指定索引位置的“通知”上的内容和时间（本方法只更新数据模型本身，不涉及sqlite的同步）。
 *
 * @param index 通知数据所在数组的索引位置
 * @param newContent 新内容
 * @param newDate 时间
 * @return 成功更新后返回更新后的AlarmDto对象引用，否则返回null
 * @since 4.3
 */
- (AlarmDto *)updateAlarmContentAndTime:(int)index newContent:(NSString *)newContent newDate:(NSDate *)newDate;

/**
 * 更新指定item上的内容和时间（并支持是否更新sqlite）。
 *
 * @param alarmType 类型
 * @param dataId id号
 * @param newContent 新内容
 * @param newDate 时间
 * @return 成功更新后返回更新后的AlarmDto对象引用，否则返回null
 * @since 4.3
 */
- (void)updateAlarmContentAndTime:(int)alarmType dataId:(NSString *)dataId newContent:(NSString *)newContent newDate:(NSDate *)newDate needUpdateSqlite:(BOOL)needUpdateSqlite;

/**
 * 更新指定索引位置的“通知/会话”上的类型（本方法只更新数据模型本身，不涉及sqlite的同步）。
 *
 * @param index 通知数据所在数组的索引位置
 * @param newAlarmType 新类型
 * @return 成功更新后返回更新后的AlarmDto对象引用，否则返回null
 * @since 9.1
 */
- (AlarmDto *)updateAlarmType:(int)index newType:(int)newAlarmType;

/**
 * 更新指定item上的“通知/会话”上的类型（并支持是否更新sqlite）。
 *
 * @param alarmType 类型
 * @param dataId id号
 * @param newAlarmType 新类型
 * @return 成功更新后返回更新后的AlarmDto对象引用，否则返回null
 * @since 9.1
 */
- (void)updateAlarmType:(int)alarmType dataId:(NSString *)dataId newType:(int)newAlarmType needUpdateSqlite:(BOOL)needUpdateSqlite;

/**
 * 重置指定索引位置的“通知”上的未读数为0（本方法只更新数据模型本身，不涉及sqlite的同步）。
 *
 * @param index 通知数据所在数组的索引位置
 * @return
 */
- (AlarmDto *)resetFlagNum:(int)index;

/**
 * 重置指定索引位置的“通知”上的未读数为指定整数（本方法只更新数据模型本身，不涉及sqlite的同步）。
 *
 * @param index 通知数据所在数组的索引位置
 * @return
 */
- (AlarmDto *)resetFlagNum:(int)index flagNumToReset:(int)flagNumToReset;

/**
 * 重置指定item上的未读数为指定整数（并支持是否更新sqlite）。
 * 当 flagNumToReset==0 时，会同时将会话内已有消息的 fp 标记为已收，避免 SyncKey 等重放时再次累加未读。
 */
- (void)resetFlagNum:(int)alarmType dataId:(NSString *)dataId flagNumToReset:(int)flagNumToReset needUpdateSqlite:(BOOL)needUpdateSqlite;

/** 将会话内已有消息的 fp 标记为已收（供未读清零等场景下复用，通常由 resetFlagNum:...flagNumToReset:0 内部自动调用） */
- (void)markConversationFingerPrintsAsReceived:(int)alarmType dataId:(NSString *)dataId;

/**
 * 重置所有“通知”上的未读数为0（本方法只更新数据模型本身，不涉及sqlite的同步）。
 *
 * @since 6.0
 */
- (void)resetAllFlagNum;

/**
 * 重置所有item上的未读数为0（并支持是否更新sqlite）。
 * @since 6.0
 */
- (void)resetAllFlagNum:(BOOL)needUpdateSqlite;

/**
 * 修改未读数.
 *
 * @param index
 * @param flagNumToAdd 为正数表示+，为负数表示-
 */
- (void)accumulateFlagNum:(int)index withNum:(int)flagNumToAdd;

/**
 * 叠加未读数为指定数字.
 *
 * @param flagNumToAdd 为正数表示+，为负数表示-
 */
- (void)accumulateFlagNum:(int)alarmType dataId:(NSString *)dataId withNum:(int)flagNumToAdd;

- (int)getFlagNum:(int)index;

/**
 * 返回数据模型中所有"未读数"的总数。
 *
 * @return  总未读数
 */
- (int)getTotalFlagNum;

/**
 * 返回私聊消息（好友/陌生人/系统等，不含群聊）的"未读数"总数。
 *
 * @return 私聊未读总数
 */
- (int)getPrivateFlagNum;

/**
 * 返回群聊消息的"未读数"总数（不含世界频道）。
 *
 * @return 群聊未读总数
 */
- (int)getGroupFlagNum;

- (BOOL) checkIndexValid:(int)index;

/**
 * 获得显示在首页消息列中的item它所位于列表的索引位置
 *
 * @return 找到则返回索引值，否则返回-1
 */
- (int) getAlarmIndex:(int)alarmType dataId:(NSString *)dataId;

/**
 * 获得显示在首页消息列中收到的指定群组聊天消息的Alarm dto对象引用.
 *
 * @return 找到则返回dto对象引用，否则返回null
 * @since 4.4
 */
- (AlarmDto *)getAlarmDto:(int)alarmType dataId:(NSString *)dataId;

/** 该聊天的 Alarm 是否已归档。 */
- (BOOL)isArchived:(int)alarmType dataId:(NSString *)dataId;


//--------------------------------------------------------------------------------------- START
#pragma mark - 【a】BBS专用方法相关

- (BBSAlarmDataObservable *)getBBSAlarmData;

/**
 * 设置"BBS聊天消息"类型的alarm.
 */
- (void) setBBSMsgAlarm:(MsgBody4Guest *)tcmd flagNumToAdd:(int)flagNumToAdd;


////--------------------------------------------------------------------------------------- START
//#pragma mark - 【2】临天聊天消息相关
//
///**
// * 将本地用户主动发出的临时聊天消息也入到首页消息栏里.
// * <p>
// * 2.2版之前，首页消息栏只在收到消息时才会放入，但像微信这样的IM里，
// * 为了方便下次查看，自已主动发的消息也放到了首页消息栏（而不限于收到的消息），
// * 自已发的消息放到首页消息栏仅仅是为了方便，别无他用。
// *
// * @param friendUid 好友的uid
// * @param friendName 好友的昵称
// * @param avatarFileName 对方头像文件名(md5的样式)，以便实现头像url相同情况下，在对方更新头像后能即时加载到新头像(而非仍用缓存)；
// * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
// * @since 2.2
// */
//+ (AlarmDto *) addATempChatMsgAlarmForLocal:(int)msgType
//                            friendUid:(NSString *)friendUid
//                           friendName:(NSString *)friendName
////                       avatarFileName:(NSString *)avatarFileName
//                              withMsg:(NSString *)msg;
//
///**
// * 添好"临时聊天消息"类型的alarm.
// */
//- (AlarmDto *) addATempChatMsgAlarm:(int)msgType friendUid:(NSString *)friendUid friendName:(NSString *)friendName
//                      withMsg:(NSString *)msg withDate:time flagNumToAdd:(int)flagNumToAdd;


//---------------------------------------------------------------------------------
#pragma mark - 【3】系统预定义相关

/**
 * 添加系统预定义的"Q & A"alarm.
 */
- (void)addSystemQAndAAlarm;

/**
 * 添加系统预定义的"Help"alarm.
 */
- (void)addFirstUseSystemAlarm;

/**
 * 添加系统预定义的alarm.
 */
- (void) addSystemDefineAlarm:(int)type withTitle:(NSString *)title andContent:(NSString *)messageContent;

/**
 是否是系统预设的“消息”类型。

 @param alarmMessageType
 @return
 */
+ (BOOL) isSystemDefineAlarm:(int)alarmMessageType dataId:(NSString *)did;


//---------------------------------------------------------------------------------
#pragma mark - 【4】正式（好友）聊天消息相关 START

/**
 * 被好加友同意加好友请求后，将入一条空消息到首页消息栏里.
 * <p>
 * 目的是像微信等IM一样，加好友成功后，可以方便的点击此消息进入聊天界面。
 *
 * @since 3.0
 */
- (void)addChatMsgAlarmForAddSuccess:(NSString *)friendUid friendName:(NSString *)friendName
;

/**
 * 获得正式聊天消息的未读数量.
 *
 * @param uid
 * @return
 */
- (int)getChatMessageFlagNum:(NSString *)uid;


//--------------------------------------------------------------------------------------- START
#pragma mark - 【5】单聊（好友或陌生人）聊天消息相关 START
/**
 * 将本地用户主动发出的聊天消息也入到首页消息栏里.
 * <p>
 * 2.2版之前，首页消息栏只在收到消息时才会放入，但像微信这样的IM里，
 * 为了方便下次查看，自已主动发的消息也放到了首页消息栏（而不限于收到的消息），
 * 自已发的消息放到首页消息栏仅仅是为了方便，别无他用。
 *
 * @param message 聊天文本（纯文本而非TextMessage的JSON文本哦）
 * @param messageType 消息类型
 * @since 2.2
 */
+ (AlarmDto *)addSingleChatMsgAlarmForLocal:(NSString *)friendUid friendName:(NSString *)friendName
                        withMsg:(NSString *)message andType:(int)messageType  withAlarmType:(int)alarmType;

/**
 * 新增一条“好友聊天消息”的item到数据模型中：此方法将自动判定该item是否已
 * 存在于数据模型中，如果已存在则更新之，否则新建之。
 *
 * @param messageContentForShow 内容
 * @param flagNumToAdd 叠加数量（通常是>=1，或者0），用于首页消息列表中数字标签的显示
 * @param time 此通知的真正产生时间（比如离线消息的通知肯定是最新那条离线消息的时间），本参为可为nil，为nil时将自动显示为当前时间
 */
/** fingerPrint 可选，非空时在内部按 fp 去重（同一条消息只计一次未读），传 nil 则不做去重 */
- (AlarmDto *)addSingleChatMessageAlarm:(NSString *)friendUid friendName:(NSString *)friendName
         withConcentForShow:(NSString *)messageContentForShow flagNumToAdd:(int)flagNumToAdd withDate:(NSDate *)time withAlarmType:(int)alarmType fingerPrint:(NSString *)fingerPrint;

/** 同上，withNotify:NO 用于批量写入时避免逐条刷新导致闪烁 */
- (AlarmDto *)addSingleChatMessageAlarm:(NSString *)friendUid friendName:(NSString *)friendName
         withConcentForShow:(NSString *)messageContentForShow flagNumToAdd:(int)flagNumToAdd withDate:(NSDate *)time withAlarmType:(int)alarmType withNotify:(BOOL)notify fingerPrint:(NSString *)fingerPrint;

/**
 * priorFingerPrintExistedInMemory：须在 putMessage 之前计算。YES 表示 Sync/漫游已插入同 fp，QoS 若也已登记则本条不累加未读；NO 且 QoS 已登记时表示陈旧 QoS，仍允许累加。
 */
- (AlarmDto *)addSingleChatMessageAlarm:(NSString *)friendUid friendName:(NSString *)friendName
         withConcentForShow:(NSString *)messageContentForShow flagNumToAdd:(int)flagNumToAdd withDate:(NSDate *)time withAlarmType:(int)alarmType withNotify:(BOOL)notify fingerPrint:(NSString *)fingerPrint priorFingerPrintExistedInMemory:(BOOL)priorFpExisted;

//---------------------------------------------------------------------------------
#pragma mark - 【7】好友请求相关 START

/**
 * 添好"加好友被拒绝"的alarm.
 *
 * @param srcUserInfo
 */
- (void)addAddFriendBeRejectAlarm:(NSString *)friendUid friendName:(NSString *)friendName;

/**
 * 添好"加好友失败信息"的alarm（这些错误信息可能是：比如服务端在执行的过程中出错等等，这肯定是要让好友请求发起方知道的，不然这请求到底去哪里了？对方有没有收到呢？）.
 *
 * @param errorContent 错误信息内容
 */
- (void)addAddFriendThrowErrorAlarm:(NSString *)errorContent;

/**
 * 添好好友请求类型的alarm.
 *
 * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所以可以将此参数理解为更新完数据模型后是否要刷新ui
 * @param mergeIfExsits YES表示当要添加的alarm已存在于数据模型时就合并它们的总数，否则不合并只替换（即未读数用本次的数量而不是叠加）
 */
- (AlarmDto *)addAddFriendReqMergeAlarm:(NSString *)friendUid friendName:(NSString *)friendName reqTime:(NSDate *)reqTime numToAdd:(int)flagNumToAdd notify:(BOOL)notifyObserver merge:(BOOL)mergeIfExsits;

+ (AlarmDto *)constructAddFriendReqAlarm:(NSString *)friendUid friendName:(NSString *)friendName reqTime:(NSDate *)reqTime extraString1:(NSString *)extraString1 numToAdd:(int)flagNumToAdd;

/**
 * 重置“首页”添加好友请求的item的未读数为0.
 */
- (void)resetAddFriendReqAlarmFlagNum;


//---------------------------------------------------------------------------------------
#pragma mark - 【8】群组聊天消息相关

/**
 * 将本地用户主动发出的群组聊天消息也入到首页消息栏里。
 *
 * @param msg 消息内容，纯文本字串，可能是聊天文字、图片文件名或语音文件名等，但一定不是JSON字串
 * @since 4.3
 */
+ (AlarmDto *) addAGroupChatMsgAlarmForLocal:(int)msgType gid:(NSString *)toGid gname:(NSString *)toGname msg:(NSString *)msg;

/// 群聊会话列表预览里表示「当前用户」的名称（优先本地资料昵称，否则「我」）
+ (NSString *)rb_displayNameForLocalUserGroupPreview;

/// 服务端昵称为空时，用发送者 uid 解析好友备注/昵称，避免会话列表预览缺少「发送人：」前缀
+ (NSString *)rb_resolvedGroupConversationPreviewSenderNick:(NSString *)serverNick senderUid:(NSString *)senderUid;

/**
 * 会话列表群预览仍缺发送者昵称时（禁止展示裸 uid），异步串行：1008-3-8 查用户资料 → 未果则 1016-25-9 首屏成员列表匹配 uid，成功后写回该会话 alarmContent。
 * @param rawMsg 与写入预览时一致的原始 msg_content（用于竞态判断与解析预览后缀）
 */
- (void)rb_scheduleResolveGroupPreviewSenderNickForGid:(NSString *)gid senderUid:(NSString *)senderUid msgType:(int)msgType rawMsg:(NSString *)rawMsg;

/** fingerPrint 可选，非空时在内部按 fp 去重（同一条消息只计一次未读），传 nil 则不做去重 */
- (AlarmDto *) addAGroupChatMsgAlarm:(int)msgType
                           gid:(NSString *)toGid
                         gname:(NSString *)toGname
              fromUserNickName:(NSString *)fromUserNickName
                           msg:(NSString *)msg
                          date:(NSDate *)time
                  flagNumToAdd:(int)flagNumToAdd
                            at:(BOOL)atMe
                   fingerPrint:(NSString *)fingerPrint;

/** 同上，withNotify:NO 用于批量写入时避免逐条刷新导致闪烁 */
- (AlarmDto *)addAGroupChatMsgAlarm:(int)msgType gid:(NSString *)toGid gname:(NSString *)toGname
              fromUserNickName:(NSString *)fromUserNickName msg:(NSString *)msg date:(NSDate *)time
                  flagNumToAdd:(int)flagNumToAdd at:(BOOL)atMe withNotify:(BOOL)notify fingerPrint:(NSString *)fingerPrint;

/** priorFingerPrintExistedInMemory：须在 putMessage 之前计算（群列表内是否已有同 fp）。 */
- (AlarmDto *)addAGroupChatMsgAlarm:(int)msgType gid:(NSString *)toGid gname:(NSString *)toGname
              fromUserNickName:(NSString *)fromUserNickName msg:(NSString *)msg date:(NSDate *)time
                  flagNumToAdd:(int)flagNumToAdd at:(BOOL)atMe withNotify:(BOOL)notify fingerPrint:(NSString *)fingerPrint priorFingerPrintExistedInMemory:(BOOL)priorFpExisted;

/**
 * 如此该条Alarm已经存在于首页列表里，则合并之并移到列表首位置。
 */
- (BOOL) addSameGroupChatMsgDTO:(int)msgType
                            gid:(NSString *)toGid
                          gname:(NSString *)toGname
               fromUserNickName:(NSString *)fromUserNickName
                            msg:(NSString *)msg
                           date:(NSDate *)time
                   flagNumToAdd:(int)flagNumToAdd
                             at:(BOOL)atMe;

/**
 * 获得群聊聊天消息的未读数量.
 *
 * @param gid
 * @return
 */
- (int) getGroupChatMessageFlagNum:(NSString *)gid;

/**
 * 移动群聊在首页"消息"列表上的item.
 *
 * @param gid
 */
- (void) removeGroupChatMessageAlarm:(NSString *)gid;


//---------------------------------------------------------------------------------------
#pragma mark - 【9】置顶和取消置顶相关

/**
 * 实现首页"消息"置顶的完整逻辑实现。
 *
 * @param alwaysTop true表示置顶，否则表示取消息置顶
 * @param alarmType 首页"消息"的类型，见 {@link AlarmType}
 * @param dataId 首页"消息"的id
 * @param title 首页"消息"的title（如果不存在这条item的话，就用此title插入一条新的）
 */
+ (void)doSetAlwaysTopNow:(BOOL)alwaysTop alarmType:(int)alarmType dataId:(NSString *)dataId title:(NSString *)title;

/**
 * 该单聊聊天的Alarm是否是置顶的。
 *
 * @param dataId id值
 * @return true表示是，否则不是
 */
- (BOOL)isAlwaysTop4Single:(NSString *)dataId;

/**
 * 该聊天的Alarm是否是置顶的。
 *
 * @param dataId id值
 * @return true表示是，否则不是
 */
- (BOOL)isAlwaysTop:(int)alarmType dataId:(NSString *)dataId;

/**
 * 设置指定的首页"消息"item数据对象的置顶标识（默认更新到sqlite中）。
 *
 * @param alwaysTop YES表示本次是置顶，否则是取消置顶
 * @param amd 本次置顶的item的数据
 */
- (void) setAlwaysTop:(BOOL)alwaysTop amd:(AlarmDto *)amd;

/**
 * 设置指定的首页"消息"item数据对象的归档标识（默认更新到sqlite中）。
 *
 * @param archived YES 表示归档，否则表示取消归档
 * @param amd 本次归档的 item 数据
 */
- (void)setArchived:(BOOL)archived amd:(AlarmDto *)amd;


//--------------------------------------------------------------------------------------- START
#pragma mark - 【10】已读和未读设置相关

/**
 * 设置已读或未读（本方法自动同步到sqlite中对应的数据，以便离线或下次app启动时保留现在的设置）。
 *
 * @param amd amd 本次设置的item的数据
 * @param hasRead true表示设置已读，否则表示设置未读
 */
- (void) setupReadOrUnread:(AlarmDto *)amd hasRead:(BOOL)hasRead;


//---------------------------------------------------------------------------------------
#pragma mark - 【11】草稿

/** 会话是否有未发送草稿（与本地 chat_draft_* key 一致；供列表分组排序使用） */
- (BOOL)hasDraftForAlarm:(AlarmDto *)alarm;


@end
