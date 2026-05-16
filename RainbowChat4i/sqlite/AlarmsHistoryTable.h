//telegram @wz662
#import "TableRoot.h"
#import "JSQMessage.h"
#import "AlarmDto.h"

/** 查询类型：只查询置顶的记录 */
#define AHT_FindHistotyType_OnlyAlwaysTopRecords    2
/** 查询类型：只查询置未置顶的记录 */
#define AHT_FindHistotyType_OnlyNotAlwaysTopRecords 1
/** 查询类型：查询所有记录 */
#define AHT_FindHistotyType_IncludeAll              0


@interface AlarmsHistoryTable : TableRoot

/**
 * 返回所有的历史Alarm记录.
 *
 * @param findHistotyType 查询条件，比如APP启动时加载数据，要把置顶和非置顶的数据区分出来，就要分两次查询了（因为1次SQL查询解决不了排序问题）
 */
- (NSArray<AlarmDto *> *) findHistory:(FMDatabase *)db findHistotyType:(int)findHistotyType;

/**
 * 返回指定归档状态的历史 Alarm 记录。
 *
 * @param archivedOnly YES 表示只取已归档；NO 表示只取未归档
 * @param findHistotyType 置顶/非置顶过滤方式
 */
- (NSArray<AlarmDto *> *)findHistory:(FMDatabase *)db archivedOnly:(BOOL)archivedOnly findHistotyType:(int)findHistotyType;

///**
// * 插入一行普通群组聊天的首页消息数据.
// *
// * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
// * @param gid 本次群消息对应的群id
// * @return `YES` upon success; `NO` upon failure.
// */
//- (BOOL) insertAlarmHistoryForGroupChat:(FMDatabase *)db
//                       acountUidOfOwner:(NSString *)acountUidOfOwner gid:(NSString *)gid amd:(AlarmMessageDto *)amd;
//
///**
// * 插入一行一对一好友聊天的首页消息数据.
// *
// * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
// * @param srcUid 正式消息的发送者uid
// * @return `YES` upon success; `NO` upon failure.
// */
//- (BOOL) insertAlarmHistoryForFriendChat:(FMDatabase *)db
//                        acountUidOfOwner:(NSString *)acountUidOfOwner
//                                  srcUid:(NSString *)srcUid
//                                     amd:(AlarmMessageDto *)amd;

/**
 * 插入一行首页消息数据.
 *
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) insertHistory:(FMDatabase *)db amd:(AlarmDto *)amd;

/**
 查询指定条件的数据行是否存在。

 @param db db description
 @param acountUidOfOwner acountUidOfOwner description
 @param alarmType alarmType description
 @param dataId dataId description
 @return 返回1表示存在该记录（即>=1行数据）、0表示不存在该记录、-1表示本次查询出错了（没有成功查出结果）
 */
- (int) existsAlarmHistoryCount:(FMDatabase *)db
               acountUidOfOwner:(NSString *)acountUidOfOwner
                      alarmType:(NSString *)alarmType
                         dataId:(NSString *)dataId;

///**
// * 更新一行普通群聊聊天的首页消息数据.
// *
// * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
// * @param gid 本次群消息对应的群id
// * @return `YES` upon success; `NO` upon failure.
// */
//- (BOOL) updateAlarmHistoryForGroupChat:(FMDatabase *)db
//                       acountUidOfOwner:(NSString *)acountUidOfOwner
//                                    gid:(NSString *)gid
//                                    amd:(AlarmMessageDto *)amd;
//
///**
// * 更新一行一对一好友聊天的首页消息数据.
// *
// * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
// * @param srcUid 正式消息的发送者uid
// * @return `YES` upon success; `NO` upon failure.
// */
//- (BOOL) updateAlarmHistoryForFriendChat:(FMDatabase *)db
//                        acountUidOfOwner:(NSString *)acountUidOfOwner
//                                  srcUid:(NSString *)srcUid
//                                     amd:(AlarmMessageDto *)amd;

/**
 * 更新一行首页消息数据.
 *
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) updateHistory:(FMDatabase *)db amd:(AlarmDto *)amd;

/**
 * 无差别更新当前账号下所有的未读数为0.
 *
 * @return YES表示更新成功
 * @since 6.0
 */
- (BOOL) clearAllUnread:(FMDatabase *)db;

/**
 * 更新是否置顶标识.
 *
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) updateAlwaysTop:(FMDatabase *)db amd:(AlarmDto *)amd;

/**
 * 更新是否归档标识.
 *
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL)updateArchived:(FMDatabase *)db amd:(AlarmDto *)amd;

/**
 * 删除一行首页”消息“.
 *
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) deleteHistory:(FMDatabase *)db alarmType:(int)alarmType dataId:(NSString *)dataId;


+ (NSString *) getCreateTableSQL;
+ (NSString *) getTableName;

@end
