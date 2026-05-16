//telegram @wz662
#import "AlarmsHistoryTable.h"
#import "BasicTool.h"
#import "AlarmType.h"
#import "TimeTool.h"
#import "MyDataBase.h"
#import "EVAToolKits.h"
#import "IMClientManager.h"


// COLUMN_KEY_UPDATE_TIME 字段的读取和更新时的SimpleDateFormat日期字串格式
#define SQLITE_UPDATE_TIME_DATE_PATTERN  @"yyyy-MM-dd HH:mm:ss"


/** 表格字段名：自增id（主键）（默认ident列，无需插入数据）*/
NSString const *AHT_COLUMN_KEY_ID = @"_id";
/** 表格字段名：本地数据所有者账号uid（联合主键之首要条件）*/
NSString const *AHT_COLUMN_KEY_ACOUNT_UID = @"_acount_uid";

/** 表格字段名：对应首页"消息"列表item的类型，@see  AlarmDto.h*/
NSString const *AHT_COLUMN_KEY_ALARM_TYPE = @"alarmType";
/**
 * 表格字段名：对应首页"消息"列表item数据的id：
 *  1）当是好友消息alarm时，此字段存放的是发送方的uid；
 *  2）当是陌生人消息alarm时，此字段存放的是发送方的uid；
 *  3）当是普通群聊消息alarm时，此字段存放的是该群的id（即gid）。 */
NSString const *AHT_COLUMN_KEY_DATA_ID = @"dataId";

/** 表格字段名：对应首页"消息"列表item标题，@see  AlarmDto.h */
NSString const *AHT_COLUMN_KEY_TITLE = @"title";
/** 表格字段名：对应首页"消息"列表item内容，@see  AlarmDto.h */
NSString const *AHT_COLUMN_ALARM_CONTENT = @"alarm_content";
/**
 * 表格字段名：对应首页"消息"列表item时间，@see  AlarmDto.h（此字段值目前仅用于UI显示，不作它用）。 */
NSString const *AHT_COLUMN_DATE = @"date";
/** 表格字段名：对应首页"消息"列表item未读数，@see  AlarmDto.h */
NSString const *AHT_COLUMN_FLAG_NUM = @"flag_num";

/** 表格字段名：对应首页"消息"列表item数据的扩展字段1，@see AlarmDto.h中的同名列 */
NSString const *AHT_COLUMN_EXTRA_STRING1 = @"extra_string1";

///** 表格字段名：@see  AlarmDto.h（对象转成的json文本） */
//NSString const *AHT_COLUMN_EXTRA_OBJ_JSON = @"extra_obj_json";
/**
 * 表格字段名：@see{AlarmDto.h中的alwaysTop字段。
 * 本字段中存放的是首页"消息"设置置顶时的标识，本字段不为空且值为"1"时即表示需要置顶，否则不需要置顶。
 * @since 4.3 */
NSString const *AHT_COLUMN_IS_ALWAYS_TOP  = @"is_always_top";
/** 表格字段名：@see AlarmDto#archived。会话归档后仅在归档列表显示。 */
NSString const *AHT_COLUMN_IS_ARCHIVED = @"is_archived";
/** 表格字段名：@see AlarmDto#archivedAt。归档时间（iOS 秒级时间戳）。 */
NSString const *AHT_COLUMN_ARCHIVED_AT = @"archived_at";

/**
 * 表格字段名：@see {@link AlarmDto#setAtMe(boolean)}字段。
 * 本字段中存放的是首页"消息"设置"[有人@我]"的提示标识，本字段不为空且值为"1"时即表示需要提示，否则不需要。
 * @since 11.0 */
NSString const *AHT_COLUMN_IS_AT_ME = @"is_at_me";

/** 1008-26-7 行末会话序号上界（与 conv_seq 一致）；未下发时为 0 */
NSString const *AHT_COLUMN_CONVERSATION_MSG_SEQ = @"conversation_msg_seq";

/**
 * 本字段不用作任何UI显示，仅用于记录排序时使用。
 * 本字段会在每个item数据插入、item的数据内容更新、置顶标识更新时，更新为当前的系统时间戳。
 *
 *  @deprecated 本字段于20250218日作废（原因是排序中并没有用到，因为不好用），日后删除
 */
NSString const *AHT_COLUMN_KEY_UPDATE_TIME  = @"_update_time";

/**
 * 本字段不用作任何UI显示，仅用于置顶排序时使用。
 * 本字段会在每个item数据插入（插入时是消息本身的时间），item的数据内容更新、置顶标识更新时更新为当前的系统时间戳（理论上一定大于消息时间本身的时间）。
 *
 * @since v9.2-250218
 */
NSString const *AHT_COLUMN_KEY_UPDATE_TIME2025 = @"_update_time2025";

/** 存放于sqlLite数据库中的表名 */
NSString * const AHT_TABLE_NAME = @"alarms_history";


@implementation AlarmsHistoryTable


//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#pragma mark - 查询数据

/**
 * 从本地sqlLite的表中查询所需数据.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param condition 查询条件
 * @return 游标结果集
 */
- (FMResultSet *)queryHistoryImpl:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner condition:(NSString *)condition
{


    NSArray<NSString *> *filedNames = @[AHT_COLUMN_KEY_ALARM_TYPE
                                        ,AHT_COLUMN_KEY_DATA_ID // add @since 4.0
                                        ,AHT_COLUMN_KEY_TITLE
                                        ,AHT_COLUMN_ALARM_CONTENT
                                        ,AHT_COLUMN_DATE
                                        ,AHT_COLUMN_FLAG_NUM
                                        ,AHT_COLUMN_EXTRA_STRING1
                                        ,AHT_COLUMN_IS_ALWAYS_TOP
                                        ,AHT_COLUMN_IS_ARCHIVED
                                        ,AHT_COLUMN_ARCHIVED_AT
                                        ,AHT_COLUMN_IS_AT_ME
                                        ,AHT_COLUMN_CONVERSATION_MSG_SEQ];

    NSString *where = [NSString stringWithFormat:@"%@='%@'%@"
                       , AHT_COLUMN_KEY_ACOUNT_UID
                       , acountUidOfOwner
                       , (condition == nil?@"": [NSString stringWithFormat:@" and %@", condition])];

    //获取结果集，返回参数就是查询结果
    FMResultSet *rs= [super query:db tableName:AHT_TABLE_NAME fieldNames:filedNames filterSQL:where debugTag:@"AlarmsHistoryTable.queryHistoryImpl"];

    return rs;
}

// 返回所有的历史Alarm记录.
- (NSArray<AlarmDto *> *) findHistory:(FMDatabase *)db findHistotyType:(int)findHistotyType
{
    NSMutableArray<AlarmDto *> *cpList= [NSMutableArray array];
    
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee == nil)
        return cpList;
    
    NSString *acountUidOfOwner = localRee.user_uid;
    NSString *condition = @"";
    switch(findHistotyType)
    {
        case AHT_FindHistotyType_OnlyAlwaysTopRecords:
            condition = [NSString stringWithFormat:@" %@ is not null order by %@ asc", AHT_COLUMN_IS_ALWAYS_TOP, AHT_COLUMN_KEY_UPDATE_TIME2025];
            break;
        case AHT_FindHistotyType_OnlyNotAlwaysTopRecords:
            condition = [NSString stringWithFormat:@" %@ is null order by %@ asc", AHT_COLUMN_IS_ALWAYS_TOP, AHT_COLUMN_DATE];
            break;
        case AHT_FindHistotyType_IncludeAll:
            condition = [NSString stringWithFormat:@" 1=1 order by ifnull(%@,%@) asc", AHT_COLUMN_DATE, AHT_COLUMN_KEY_UPDATE_TIME];
            break;
    }

    FMResultSet *rs = [self queryHistoryImpl:db acountUidOfOwner:acountUidOfOwner condition:condition];
    if(rs != nil)
    {
        while (rs.next)
        {
            AlarmDto *cp = [[AlarmDto alloc] init];
            cp.alarmType = [BasicTool getIntValue:[rs stringForColumnIndex:0] defaultVal:AMT_undefine];
            cp.dataId = [rs stringForColumnIndex:1];
            cp.title = [rs stringForColumnIndex:2];
            cp.alarmContent = [rs stringForColumnIndex:3];
            cp.date = [TimeTool convertIOSTimestampToiOSDate:[rs longForColumnIndex:4]];
            cp.flagNum = [rs stringForColumnIndex:5];
            cp.extraString1 = [rs stringForColumnIndex:6];
            cp.alwaysTop = [@"1" isEqualToString:[rs stringForColumnIndex:7]];
            NSString *archivedStr = [rs stringForColumnIndex:8];
            cp.archived = [@"1" isEqualToString:archivedStr] || [BasicTool getIntValue:archivedStr defaultVal:0] == 1;
            cp.archivedAt = [rs longLongIntForColumnIndex:9];
            cp.atMe = [@"1" isEqualToString:[rs stringForColumnIndex:10]];
            cp.conversationMsgSeq = [rs longLongIntForColumnIndex:11];
            [cpList addObject:cp];
        }
    }
    else
    {
        [MyDataBase printErrorForDebug:db tag:@"AlarmsHistoryTable.findHistory"];
    }

    return cpList;
}

- (NSArray<AlarmDto *> *)findHistory:(FMDatabase *)db archivedOnly:(BOOL)archivedOnly findHistotyType:(int)findHistotyType
{
    NSMutableArray<AlarmDto *> *cpList= [NSMutableArray array];
    
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee == nil)
        return cpList;
    
    // 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
    NSString *acountUidOfOwner = localRee.user_uid;

    // 根据查询类型来决定最终的SQL查询条件
    NSString *condition = @"";
    switch(findHistotyType)
    {
        // 仅查询置顶的记录
        case AHT_FindHistotyType_OnlyAlwaysTopRecords:
        {
//          condition = [NSString stringWithFormat:@" %@ is not null order by ifnull(%@,%@) asc", AHT_COLUMN_IS_ALWAYS_TOP, AHT_COLUMN_DATE, AHT_COLUMN_KEY_UPDATE_TIME];
            // 20250218注：因COLUMN_DATE无法体现置顶操作的时间，所以用新字段替代！
            condition = [NSString stringWithFormat:@" %@ is not null order by %@ asc", AHT_COLUMN_IS_ALWAYS_TOP, AHT_COLUMN_KEY_UPDATE_TIME2025];
            break;
        }
        // 仅查询未置顶的记录
        case AHT_FindHistotyType_OnlyNotAlwaysTopRecords:
        {
//          condition = [NSString stringWithFormat:@" %@ is null order by ifnull(%@,%@) asc", AHT_COLUMN_IS_ALWAYS_TOP, AHT_COLUMN_DATE, AHT_COLUMN_KEY_UPDATE_TIME];
            // 最新备注：不置顶的消息，用消息本身的时间来排序（而不是更新时间，包括取消置顶更新时间），更符合用户直觉
            condition = [NSString stringWithFormat:@" %@ is null order by %@ asc", AHT_COLUMN_IS_ALWAYS_TOP, AHT_COLUMN_DATE];
            break;
        }
        // 查询所有记录
        case AHT_FindHistotyType_IncludeAll:
        {
            condition = [NSString stringWithFormat:@" 1=1 order by ifnull(%@,%@) asc", AHT_COLUMN_DATE, AHT_COLUMN_KEY_UPDATE_TIME];
            break;
        }
    }

    NSString *archiveSQL = archivedOnly
        ? [NSString stringWithFormat:@" and IFNULL(%@, 0) = 1", AHT_COLUMN_IS_ARCHIVED]
        : [NSString stringWithFormat:@" and IFNULL(%@, 0) = 0", AHT_COLUMN_IS_ARCHIVED];
    condition = [condition stringByAppendingString:archiveSQL];

    FMResultSet *rs = [self queryHistoryImpl:db acountUidOfOwner:acountUidOfOwner condition:condition];
    if(rs != nil)
    {
        while (rs.next)
        {
            AlarmDto *cp = [[AlarmDto alloc] init];

            cp.alarmType = [BasicTool getIntValue:[rs stringForColumnIndex:0] defaultVal:AMT_undefine];
            cp.dataId = [rs stringForColumnIndex:1];
            cp.title = [rs stringForColumnIndex:2];
            cp.alarmContent = [rs stringForColumnIndex:3];
            cp.date = [TimeTool convertIOSTimestampToiOSDate:[rs longForColumnIndex:4]];
            cp.flagNum = [rs stringForColumnIndex:5];
            
//            NSLog(@"AA-################ cp.dataId=%@, cp.title=%@", cp.dataId, cp.title);

            // 扩展字段
            NSString *extraString1 = [rs stringForColumnIndex:6];
            cp.extraString1 = extraString1;

            // 是否置顶标识
            NSString *alwaysTopStr = [rs stringForColumnIndex:7];
            cp.alwaysTop = [@"1" isEqualToString:alwaysTopStr];

            NSString *archivedStr = [rs stringForColumnIndex:8];
            cp.archived = [@"1" isEqualToString:archivedStr] || [BasicTool getIntValue:archivedStr defaultVal:0] == 1;
            cp.archivedAt = [rs longLongIntForColumnIndex:9];

            // 是否显示"[有人@我]"标识
            NSString *atMeStr = [rs stringForColumnIndex:10];
            cp.atMe = [@"1" isEqualToString:atMeStr];

            cp.conversationMsgSeq = [rs longLongIntForColumnIndex:11];

            [cpList addObject:cp];
        }
    }
    // fs返回为nil即表示查询出错了
    else
    {
        [MyDataBase printErrorForDebug:db tag:@"AlarmsHistoryTable.findHistory"];
    }

    return cpList;
}


//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#pragma mark - 插入数据

// 插入一行一对一临时聊天(即陌生人聊天)的首页消息数据.
- (BOOL) insertHistory:(FMDatabase *)db amd:(AlarmDto *)amd
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee == nil)
        return NO;
    
    // 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
    NSString *acountUidOfOwner = localRee.user_uid;
    
    if(amd != nil)
    {
        return [self insertHistory:db
                  acountUidOfOwner:acountUidOfOwner
                         alarmType:[NSString stringWithFormat:@"%d", amd.alarmType]
                            dataId:amd.dataId
                             title:amd.title
                        msgContent:amd.alarmContent
                              date:[TimeTool getIOSTimeStamp_l:amd.date]
                           flagNum:amd.flagNum
                         archived:amd.archived
                        archivedAt:amd.archivedAt
                                at:[amd isAtMe]
                      extraString1:amd.extraString1
                conversationMsgSeq:amd.conversationMsgSeq];
    }
    return NO;
}

/**
 * 插入一行数据到表中.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
           alarmType:(NSString *)alarmType
                dataId:(NSString *)dataId
                 title:(NSString *)title
            msgContent:(NSString *)alarmContent
                  date:(long)date
               flagNum:(NSString *)flagNum
             archived:(BOOL)archived
            archivedAt:(long long)archivedAt
                    at:(BOOL)atMe
         extraString1:(NSString *)extraString1
    conversationMsgSeq:(long long)conversationMsgSeq
{
    NSString *sql = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@(%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)"
                             , AHT_TABLE_NAME

                             , AHT_COLUMN_KEY_ACOUNT_UID
                             , AHT_COLUMN_KEY_ALARM_TYPE
                             , AHT_COLUMN_KEY_DATA_ID
                             , AHT_COLUMN_KEY_TITLE
                             , AHT_COLUMN_ALARM_CONTENT
                             , AHT_COLUMN_DATE
                             , AHT_COLUMN_FLAG_NUM
                             , AHT_COLUMN_IS_ARCHIVED
                             , AHT_COLUMN_ARCHIVED_AT
                             , AHT_COLUMN_IS_AT_ME
                             , AHT_COLUMN_EXTRA_STRING1
                             , AHT_COLUMN_CONVERSATION_MSG_SEQ
                             , AHT_COLUMN_KEY_UPDATE_TIME2025
                            ];

    DDLogDebug(@"[sqlite-LarmsHistoryTable.insertHistory] 组织完成的SQL语句：%@", sql);

    NSString *safeTitle = title ?: @"";
    NSString *safeFlagNum = flagNum ?: @"0";
    return [db executeUpdate:sql withArgumentsInArray:@[
        acountUidOfOwner,
        alarmType,
        [MyDataBase nullSafe:dataId],
        safeTitle,
        [MyDataBase nullSafe:alarmContent],
        [NSNumber numberWithLong:date],
        safeFlagNum,
        archived ? @"1" : @"0",
        @(archivedAt),
        atMe ? @"1" : [MyDataBase nullSafe:nil],
        [MyDataBase nullSafe:extraString1],
        @(conversationMsgSeq),
        [NSNumber numberWithLong:date]
    ]];
}


//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#pragma mark - 更新数据

// 查询指定条件的数据行是否存在（SELECT 1 LIMIT 1，较 COUNT(*) 更易提前结束；依赖 idx_alarms_hist_acct_type_dataid 索引）。
- (int) existsAlarmHistoryCount:(FMDatabase *)db
               acountUidOfOwner:(NSString *)acountUidOfOwner
                      alarmType:(NSString *)alarmType
                         dataId:(NSString *)dataId
{
    NSString *where = [self constructUpdateCondition:acountUidOfOwner alarmType:alarmType dataId:dataId];
    NSString *sql = [NSString stringWithFormat:@"SELECT 1 FROM %@ WHERE %@ LIMIT 1", AHT_TABLE_NAME, where];
    FMResultSet *rs = [db executeQuery:sql];
    if (rs == nil) {
        [MyDataBase printErrorForDebug:db tag:@"AlarmsHistoryTable.existsAlarmHistoryCount"];
        return -1;
    }
    BOOL exists = [rs next];
    [rs close];
    return exists ? 1 : 0;
}

// 更新一行一对一临时聊天(即陌生人聊天)的首页消息数据.
- (BOOL) updateHistory:(FMDatabase *)db amd:(AlarmDto *)amd
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee == nil)
        return NO;
    
    // 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
    NSString *acountUidOfOwner = localRee.user_uid;
    
    if(amd != nil)
    {
        return [self updateHistory:db
                  acountUidOfOwner:acountUidOfOwner
                          newtitle:amd.title
                     newmsgContent:amd.alarmContent
                           newdate:[TimeTool getIOSTimeStamp_l:amd.date]
                        newflagNum:amd.flagNum
                   newextraString1:amd.extraString1
                       isAlwaysTop:amd.alwaysTop
                        isArchived:amd.archived
                       archivedAt:amd.archivedAt
                        at:[amd isAtMe]
             newConversationMsgSeq:amd.conversationMsgSeq
                         alarmType:[NSString stringWithFormat:@"%d", amd.alarmType]  // 更新条件：”首页消息/会话类型“
                            dataId:amd.dataId];   // 更新条件：消息发送者的uid
    }
    return NO;
}

- (BOOL) updateHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
              newtitle:(NSString *)newtitle
         newmsgContent:(NSString *)newmsgContent
               newdate:(long)newdate
            newflagNum:(NSString *)newflagNum
       newextraString1:(NSString *)newextraString1
           isAlwaysTop:(BOOL)isAlwaysTop
            isArchived:(BOOL)isArchived
           archivedAt:(long long)archivedAt
                    at:(BOOL)atMe
     newConversationMsgSeq:(long long)newConversationMsgSeq
             alarmType:(NSString *)alarmType
                dataId:(NSString *)dataId
{
    // 附加更新条件
    NSString *where = [self constructUpdateCondition:acountUidOfOwner alarmType:alarmType dataId:dataId];

    NSMutableString *sql = [NSMutableString stringWithFormat:
                            @"UPDATE %@ SET \
                                %@=?, \
                                %@=?, \
                                %@=?, \
                                %@=?, \
                                %@=?, \
                                %@=?, \
                                %@=?, \
                                %@=?, \
                                %@=?, \
                                %@=CASE WHEN ? > 0 THEN ? ELSE %@ END, \
                                %@=?, \
                                %@=datetime('now', 'localtime') \
                            WHERE %@"
                            , AHT_TABLE_NAME
                            , AHT_COLUMN_KEY_TITLE
                            , AHT_COLUMN_ALARM_CONTENT
                            , AHT_COLUMN_DATE
                            , AHT_COLUMN_FLAG_NUM
                            , AHT_COLUMN_EXTRA_STRING1
                            , AHT_COLUMN_IS_ALWAYS_TOP
                            , AHT_COLUMN_IS_ARCHIVED
                            , AHT_COLUMN_ARCHIVED_AT
                            , AHT_COLUMN_IS_AT_ME
                            , AHT_COLUMN_CONVERSATION_MSG_SEQ
                            , AHT_COLUMN_CONVERSATION_MSG_SEQ
                            , AHT_COLUMN_KEY_UPDATE_TIME2025
                            , AHT_COLUMN_KEY_UPDATE_TIME
                            , where];

    DDLogDebug(@"[sqlite-AlarmsHistoryTable.updateHistory] 组织完成的SQL语句：%@", sql);

    // 后面的数组单元是跟上面的"?"号一一对应的，在标准的SQL中“?”号的方式被称为预编译SQL，是后端开发中很常见的写法和用法
    NSString *safeTitle = newtitle ?: @"";
    NSString *safeFlagNum = newflagNum ?: @"0";
    NSNumber *seqArg = @(newConversationMsgSeq);
    return [db executeUpdate:sql withArgumentsInArray:@[
        safeTitle,
        [MyDataBase nullSafe:newmsgContent],
        [NSNumber numberWithLong:newdate],
        safeFlagNum,
        [MyDataBase nullSafe:newextraString1],
        isAlwaysTop?@"1":[MyDataBase nullSafe:nil],
        isArchived ? @"1" : @"0",
        @(archivedAt),
        atMe?@"1":[MyDataBase nullSafe:nil],
        seqArg,
        seqArg,
        [NSNumber numberWithLong:[TimeTool getIOSDefaultTimeStamp_l]]
    ]];
}

// 无差别更新当前账号下所有的未读数为0.
- (BOOL) clearAllUnread:(FMDatabase *)db
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee == nil)
        return NO;
    
    // 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
    NSString *acountUidOfOwner = localRee.user_uid;
    
    // 附加更新条件
    NSString *where = [self constructUpdateCondition:acountUidOfOwner alarmType:nil dataId:nil];

    NSMutableString *sql = [NSMutableString stringWithFormat:@"UPDATE %@ SET %@=?,%@=? WHERE %@"
                                , AHT_TABLE_NAME
                                , AHT_COLUMN_FLAG_NUM
                                , AHT_COLUMN_IS_AT_ME
                                , where];

    DDLogDebug(@"[sqlite-AlarmsHistoryTable.clearAllUnread] 组织完成的SQL语句：%@", sql);

    // 后面的数组单元是跟上面的"?"号一一对应的，在标准的SQL中“?”号的方式被称为预编译SQL，是后端开发中很常见的写法和用法
    return [db executeUpdate:sql withArgumentsInArray:@[@"0", @"0"]];
}

/**
 * 组织本SQLite表的行记录更新条件SQL语句。
 */
- (NSString *)constructUpdateCondition:(NSString *)acountUidOfOwner
                           alarmType:(NSString *)alarmType
                                  dataId:(NSString *)dataId
{
    // 附加更新条件(本地数据所属账号+Alarm类型是首要条件)
    NSMutableString *where = [NSMutableString stringWithFormat:@"%@='%@'", AHT_COLUMN_KEY_ACOUNT_UID, acountUidOfOwner];
//  NSMutableString *where = [NSMutableString stringWithFormat:@"%@='%@' and %@='%@' and %@='%@'"
//                              , AHT_COLUMN_KEY_ACOUNT_UID, acountUidOfOwner
//                              , AHT_COLUMN_KEY_ALARM_TYPE, alarmType
//                              , AHT_COLUMN_KEY_DATA_ID, dataId];
    
    if(alarmType != nil) {
        [where appendFormat:@" and %@='%@'", AHT_COLUMN_KEY_ALARM_TYPE, alarmType];
    }
    
    if(dataId != nil) {
        [where appendFormat:@" and %@='%@'", AHT_COLUMN_KEY_DATA_ID, dataId];
    }

    return where;
}


//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#pragma mark - 更新置顶标识

// 更新是否置顶标识.
- (BOOL) updateAlwaysTop:(FMDatabase *)db amd:(AlarmDto *)amd
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee == nil)
        return NO;
    
    // 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
    NSString *acountUidOfOwner = localRee.user_uid;
    
    if(amd != nil)
    {
        return [self updateAlwaysTop:db acountUidOfOwner:acountUidOfOwner
                         isAlwaysTop:amd.alwaysTop

                           alarmType:[NSString stringWithFormat:@"%d", amd.alarmType] // 更新条件：”消息类型“
                              dataId:amd.dataId]; // 更新条件：消息发送者的uid或者群聊发生的群id
    }
    return NO;
}

- (BOOL) updateAlwaysTop:(FMDatabase *)db
        acountUidOfOwner:(NSString *)acountUidOfOwner
             isAlwaysTop:(BOOL)isAlwaysTop
               alarmType:(NSString *)alarmType
                  dataId:(NSString *)dataId
{
    // 附加更新条件
    NSString *where = [self constructUpdateCondition:acountUidOfOwner alarmType:alarmType dataId:dataId];

    NSMutableString *sql = [NSMutableString stringWithFormat:@"UPDATE %@ SET %@=?, %@=?, %@=datetime('now', 'localtime') WHERE %@"
                                , AHT_TABLE_NAME
                                , AHT_COLUMN_IS_ALWAYS_TOP
                                , AHT_COLUMN_KEY_UPDATE_TIME2025
                                , AHT_COLUMN_KEY_UPDATE_TIME
                                , where];

    DDLogDebug(@"[sqlite-AlarmsHistoryTable.updateAlwaysTop] 组织完成的SQL语句：%@", sql);

    // 后面的数组单元是跟上面的"?"号一一对应的，在标准的SQL中“?”号的方式被称为预编译SQL，是后端开发中很常见的写法和用法
    return [db executeUpdate:sql withArgumentsInArray:@[isAlwaysTop?@"1":[MyDataBase nullSafe:nil], [NSNumber numberWithLong:[TimeTool getIOSDefaultTimeStamp_l]] ]];
}

- (BOOL)updateArchived:(FMDatabase *)db amd:(AlarmDto *)amd
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee == nil)
        return NO;

    NSString *acountUidOfOwner = localRee.user_uid;

    if (amd != nil) {
        return [self updateArchived:db
                    acountUidOfOwner:acountUidOfOwner
                          isArchived:amd.archived
                         archivedAt:amd.archivedAt
                          alarmType:[NSString stringWithFormat:@"%d", amd.alarmType]
                             dataId:amd.dataId];
    }
    return NO;
}

- (BOOL)updateArchived:(FMDatabase *)db
       acountUidOfOwner:(NSString *)acountUidOfOwner
             isArchived:(BOOL)isArchived
            archivedAt:(long long)archivedAt
             alarmType:(NSString *)alarmType
                dataId:(NSString *)dataId
{
    NSString *where = [self constructUpdateCondition:acountUidOfOwner alarmType:alarmType dataId:dataId];
    NSMutableString *sql = [NSMutableString stringWithFormat:@"UPDATE %@ SET %@=?, %@=?, %@=datetime('now', 'localtime') WHERE %@"
                                , AHT_TABLE_NAME
                                , AHT_COLUMN_IS_ARCHIVED
                                , AHT_COLUMN_ARCHIVED_AT
                                , AHT_COLUMN_KEY_UPDATE_TIME
                                , where];

    DDLogDebug(@"[sqlite-AlarmsHistoryTable.updateArchived] 组织完成的SQL语句：%@", sql);
    return [db executeUpdate:sql withArgumentsInArray:@[isArchived ? @"1" : @"0", @(archivedAt)]];
}


//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#pragma mark - 删除数据

/**
 * 删除一行首页”消息“.
 *
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) deleteHistory:(FMDatabase *)db alarmType:(int)alarmType dataId:(NSString *)dataId
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee == nil)
        return NO;
    
    // 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
    NSString *acountUidOfOwner = localRee.user_uid;
    
    // 删除的条件
    NSString *where = [NSString stringWithFormat:@"%@='%@' and %@='%@' and %@='%@'"
                           , AHT_COLUMN_KEY_ACOUNT_UID, acountUidOfOwner
                           , AHT_COLUMN_KEY_ALARM_TYPE, [NSString stringWithFormat:@"%d", alarmType]
                           , AHT_COLUMN_KEY_DATA_ID, dataId
                       ];

    return [super delete:db tableName:AHT_TABLE_NAME filterSQL:where debugTag:@"AlarmsHistoryTable.deleteHistory"];
}


//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#pragma mark - 实用方法

+ (NSString *) getCreateTableSQL
{
    // date('now')或CURRENT_TIMESTAMP 时间是以格林尼治标准时间为基准的，因此在中国使用的话会正好早8个小时，所以需要'localtime'参数
    NSString *sql = [NSString stringWithFormat:
                     @"\
                     CREATE TABLE IF NOT EXISTS '%@' (\
                         '%@' INTEGER PRIMARY KEY AUTOINCREMENT,\
                         '%@' TEXT ,\
                         '%@' TEXT ,\
                         '%@' TEXT ,\
                         '%@' TEXT ,\
                         '%@' TEXT ,\
                         '%@' INTEGER ,\
                         '%@' TEXT ,\
                         '%@' TEXT ,\
                         '%@' TEXT ,\
                         '%@' INTEGER DEFAULT 0,\
                         '%@' INTEGER DEFAULT 0,\
                         '%@' TEXT ,\
                         '%@' INTEGER DEFAULT 0,\
                         '%@' INTEGER ,\
                         '%@' TIMESTAMP default (datetime('now', 'localtime'))\
                     )"
                     , AHT_TABLE_NAME
                     
                     , AHT_COLUMN_KEY_ID
                     , AHT_COLUMN_KEY_ACOUNT_UID
                     , AHT_COLUMN_KEY_ALARM_TYPE
                     , AHT_COLUMN_KEY_DATA_ID
                     , AHT_COLUMN_KEY_TITLE
                     , AHT_COLUMN_ALARM_CONTENT
                     , AHT_COLUMN_DATE
                     , AHT_COLUMN_FLAG_NUM
                     , AHT_COLUMN_EXTRA_STRING1
                     , AHT_COLUMN_IS_ALWAYS_TOP
                     , AHT_COLUMN_IS_ARCHIVED
                     , AHT_COLUMN_ARCHIVED_AT
                     , AHT_COLUMN_IS_AT_ME
                     , AHT_COLUMN_CONVERSATION_MSG_SEQ
                     , AHT_COLUMN_KEY_UPDATE_TIME2025
                     , AHT_COLUMN_KEY_UPDATE_TIME
                     ];

    return sql;
}

+ (NSString *) getTableName
{
    return AHT_TABLE_NAME;
}

@end
