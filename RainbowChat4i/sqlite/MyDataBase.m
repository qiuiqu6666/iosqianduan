//telegram @wz662
#import "MyDataBase.h"
#import "UserDefaultsToolKits.h"

/**
 * 当前版本号，此版本将决定你的数据库是否会被重建（与手机上当前的版本比较）——
 * 如果本版本号高于你手机上的正在使用中的数据库版本号高则会被重构，否则不会。
 * 所以如要用户更新手机上数据库结构则需要修改此版本号（递增）.
 *
 * FMDB官方手册：https://ccgus.github.io/fmdb/html/index.html
 *
 * ver 1 -> 2018-06-09 by JS：第1个发布版本
 * ver 2 -> 2020-04-27 by JS：第2个发布版本，规范了ChatHistoryTable表中某些字段名并增加了“sendId字段”
 * ver 3 -> 2020-04-28 by JS：第3个发布版本，规范了GroupChatHistoryTable表中某些字段名并增加了“sendId字段”
 * ver 4 -> 2020-05-09 by JS：第4个发布版本，规范了AlarmsHistoryTable表中某些字段名等
 * ver 5 -> 2021-11-13 by JS:  第5个发布版本，GroupChatHistoryTable表中增加了字段"finger_print_of_parent"
 * ver 6 -> 2024-03-05 by JS:  第6个发布版本，GroupChatHistoryTable表中增加了字段"is_at_me"
 * ver 7 -> 2024-03-22 by JS:  第7个发布版本，ChatHistoryTable、GroupChatHistoryTable表中增加了消息引用相关字段
 * ver 8 -> 2025-02-18 by JS:  第8个发布版本，AlarmsHistoryTable新增“_update_time2025”字段
 */
int const DB_VERSION = 8;

static MyDataBase* instance;
static FMDatabaseQueue *queue = nil;

@implementation MyDataBase


- (instancetype)init
{
    if (self = [super init]) {

        int lastDBVersion = [UserDefaultsToolKits getDbVersion];

        DDLogDebug(@"[sqlite-MyDataBase] 当前APP中的库版本：%d, 目标库版本：%d, 需要重建数据库吗？%@", lastDBVersion, DB_VERSION, (DB_VERSION != lastDBVersion)?@"【是】":@"【否】");

        // 如果本地已创建的版本跟app中的目标版本不一致，则优先删除之前创建的表（以便接下来新建所有表结构）
        if(DB_VERSION != lastDBVersion)
        {
            DDLogDebug(@"[sqlite-MyDataBase] 为了升级到数据库版本：%d，先尝试删除所有的已建表。。。", DB_VERSION);
            [MyDataBase dropAllTables];
        }

        // 创建所有表
        [MyDataBase createAllTables];

        // 初始化对应的表操作封装类
        _chatHistoryTable = [[ChatHistoryTable alloc] init];
        _alarmsHistoryTable = [[AlarmsHistoryTable alloc] init];
        _groupChatHistoryTable = [[GroupChatHistoryTable alloc] init];
        _callRecordsCacheTable = [[CallRecordsCacheTable alloc] init];
    }
    return self;
}


+ (instancetype)sharedInstance
{
    @synchronized([MyDataBase class]) {
        if (instance == nil) {
            instance = [[MyDataBase alloc] init];
        }
        return instance;
    }
}

+(void)clean
{
    @synchronized([MyDataBase class]) {
        instance = nil;
        if (queue != nil) {
            [queue close];
            queue = nil;
        }
    }
}

+(FMDatabaseQueue*)getDbQueue
{
    @synchronized([MyDataBase class]) {
        if (queue == nil) {
            NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *dbPath = [docPath stringByAppendingPathComponent:DATABASE_PATH];
            DDLogDebug(@"[sqlite-MyDataBase] 数据库存储路径：%@", dbPath);
            queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
        }
        return queue;
    }
}

+(void)createTable:(NSString*)tableString
{
    [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db){
//        DDLogDebug(@"[sqlite-MyDataBase] 正在尝试建表：%@", tableString);
        BOOL sucess = [db executeUpdate:tableString];
        if(!sucess)
           [MyDataBase printErrorForDebug:db tag:@"MyDataBase-建表"];
    }];
}

+(void)dropTable:(NSString*)dropSQL
{
    [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db){
        DDLogDebug(@"[sqlite-MyDataBase] 正在尝试删除表：%@", dropSQL);
        BOOL sucess = [db executeUpdate:dropSQL];
        if(!sucess)
            [MyDataBase printErrorForDebug:db tag:@"MyDataBase-删表"];
    }];
}

+(void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block {
    // 必须先完成单例 init（建表/迁移均会 inDatabase），严禁在「已在 FMDatabaseQueue 回调内」才首次触发 sharedInstance，否则嵌套 inDatabase 触发 FMDB 断言。
    (void)[MyDataBase sharedInstance];
    [[MyDataBase getDbQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        block(db, rollback);
    }];// finished:nil];
}

//+(void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block finished:(void (^)())finished{
//    [[TableRoot getDbQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
//        block(db, rollback);
//    } finished:finished];
//}

+(void)inDatabase:(void (^)(FMDatabase *db))block{
    (void)[MyDataBase sharedInstance];
    [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
        block(db);
    }];
}

/**
 * 本方法实现数据库表及其它结构的建立.<br>
 * <b>数据库需要的表则其建表语句应该放在本方法里，有多少表就要多少个建表语句.</b>
 *
 * {@inheritDoc}
 */
+ (void) createAllTables
{
    NSLog(@"[sqlite-MyDataBase] 正在尝试新建数据库表结构.");

    //    db.execSQL(ChatHistoryTable.DB_CREATE);
    //    db.execSQL(AlarmsHistoryTable.DB_CREATE);
    //    db.execSQL(GroupChatHistoryTable.DB_CREATE);

    [MyDataBase createTable:[ChatHistoryTable getCreateTableSQL]];
    [MyDataBase createTable:[AlarmsHistoryTable getCreateTableSQL]];
    [MyDataBase createTable:[GroupChatHistoryTable getCreateTableSQL]];
    [MyDataBase createTable:[CallRecordsCacheTable getCreateTableSQL]];

    // 迁移：为已有表添加 send_status 列（新安装建表已包含；避免每次启动 ALTER 导致 duplicate column）
    [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *chatTable = [ChatHistoryTable getTableName];
        NSString *pragmaSql = [NSString stringWithFormat:@"PRAGMA table_info(%@)", chatTable];
        FMResultSet *colRs = [db executeQuery:pragmaSql];
        BOOL hasSendStatus = NO;
        while ([colRs next]) {
            if ([[colRs stringForColumn:@"name"] isEqualToString:@"send_status"]) {
                hasSendStatus = YES;
                break;
            }
        }
        [colRs close];
        if (!hasSendStatus) {
            NSString *alterSql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN send_status INTEGER DEFAULT 1", chatTable];
            if (![db executeUpdate:alterSql]) {
                [MyDataBase printErrorForDebug:db tag:@"MyDataBase-chat_msg_send_status"];
            }
        }
        FMResultSet *colRb = [db executeQuery:pragmaSql];
        BOOL hasReadByPartner = NO;
        while ([colRb next]) {
            if ([[colRb stringForColumn:@"name"] isEqualToString:@"read_by_partner"]) {
                hasReadByPartner = YES;
                break;
            }
        }
        [colRb close];
        if (!hasReadByPartner) {
            NSString *alterRb = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN read_by_partner INTEGER DEFAULT 0", chatTable];
            if (![db executeUpdate:alterRb]) {
                [MyDataBase printErrorForDebug:db tag:@"MyDataBase-chat_msg_read_by_partner"];
            }
        }
        NSString *groupTable = [GroupChatHistoryTable getTableName];
        NSString *pragmaG = [NSString stringWithFormat:@"PRAGMA table_info(%@)", groupTable];
        FMResultSet *colG = [db executeQuery:pragmaG];
        BOOL hasGrpSendStatus = NO;
        BOOL hasGrpRead = NO;
        while ([colG next]) {
            if ([[colG stringForColumn:@"name"] isEqualToString:@"send_status"]) {
                hasGrpSendStatus = YES;
            }
            if ([[colG stringForColumn:@"name"] isEqualToString:@"read_by_partner"]) {
                hasGrpRead = YES;
            }
        }
        [colG close];
        if (!hasGrpSendStatus) {
            NSString *alterGs = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN send_status INTEGER DEFAULT 1", groupTable];
            if (![db executeUpdate:alterGs]) {
                [MyDataBase printErrorForDebug:db tag:@"MyDataBase-groupchat_msg_send_status"];
            }
        }
        if (!hasGrpRead) {
            NSString *alterG = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN read_by_partner INTEGER DEFAULT 0", groupTable];
            if (![db executeUpdate:alterG]) {
                [MyDataBase printErrorForDebug:db tag:@"MyDataBase-groupchat_msg_read_by_partner"];
            }
        }
        FMResultSet *colChatConv = [db executeQuery:pragmaSql];
        BOOL hasChatConvSeq = NO;
        while ([colChatConv next]) {
            if ([[colChatConv stringForColumn:@"name"] isEqualToString:@"conversation_msg_seq"]) {
                hasChatConvSeq = YES;
                break;
            }
        }
        [colChatConv close];
        if (!hasChatConvSeq) {
            NSString *alterChatConv = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN conversation_msg_seq INTEGER DEFAULT 0", chatTable];
            if (![db executeUpdate:alterChatConv]) {
                [MyDataBase printErrorForDebug:db tag:@"MyDataBase-chat_msg_conversation_msg_seq"];
            }
        }
        FMResultSet *colChatUt = [db executeQuery:pragmaSql];
        BOOL hasChatUpdateTime = NO;
        while ([colChatUt next]) {
            if ([[colChatUt stringForColumn:@"name"] isEqualToString:@"_update_time"]) {
                hasChatUpdateTime = YES;
                break;
            }
        }
        [colChatUt close];
        if (!hasChatUpdateTime) {
            NSString *alterUt = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN _update_time TIMESTAMP", chatTable];
            if (![db executeUpdate:alterUt]) {
                [MyDataBase printErrorForDebug:db tag:@"MyDataBase-chat_msg_update_time"];
            }
        }
        FMResultSet *colGrpConv = [db executeQuery:pragmaG];
        BOOL hasGrpConvSeq = NO;
        while ([colGrpConv next]) {
            if ([[colGrpConv stringForColumn:@"name"] isEqualToString:@"conversation_msg_seq"]) {
                hasGrpConvSeq = YES;
                break;
            }
        }
        [colGrpConv close];
        if (!hasGrpConvSeq) {
            NSString *alterGrpConv = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN conversation_msg_seq INTEGER DEFAULT 0", groupTable];
            if (![db executeUpdate:alterGrpConv]) {
                [MyDataBase printErrorForDebug:db tag:@"MyDataBase-groupchat_msg_conversation_msg_seq"];
            }
        }
        NSString *alarmsTable = [AlarmsHistoryTable getTableName];
        NSString *pragmaAlarms = [NSString stringWithFormat:@"PRAGMA table_info(%@)", alarmsTable];
        FMResultSet *colAl = [db executeQuery:pragmaAlarms];
        BOOL hasConvSeqAl = NO;
        while ([colAl next]) {
            if ([[colAl stringForColumn:@"name"] isEqualToString:@"conversation_msg_seq"]) {
                hasConvSeqAl = YES;
                break;
            }
        }
        [colAl close];
        if (!hasConvSeqAl) {
            NSString *alterAl = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN conversation_msg_seq INTEGER DEFAULT 0", alarmsTable];
            if (![db executeUpdate:alterAl]) {
                [MyDataBase printErrorForDebug:db tag:@"MyDataBase-alarms_history_conversation_msg_seq"];
            }
        }
        FMResultSet *colAlArchived = [db executeQuery:pragmaAlarms];
        BOOL hasAlArchived = NO;
        BOOL hasAlArchivedAt = NO;
        while ([colAlArchived next]) {
            NSString *name = [colAlArchived stringForColumn:@"name"];
            if ([name isEqualToString:@"is_archived"]) {
                hasAlArchived = YES;
            } else if ([name isEqualToString:@"archived_at"]) {
                hasAlArchivedAt = YES;
            }
        }
        [colAlArchived close];
        if (!hasAlArchived) {
            NSString *alterArchived = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN is_archived INTEGER DEFAULT 0", alarmsTable];
            if (![db executeUpdate:alterArchived]) {
                [MyDataBase printErrorForDebug:db tag:@"MyDataBase-alarms_history_is_archived"];
            }
        }
        if (!hasAlArchivedAt) {
            NSString *alterArchivedAt = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN archived_at INTEGER DEFAULT 0", alarmsTable];
            if (![db executeUpdate:alterArchivedAt]) {
                [MyDataBase printErrorForDebug:db tag:@"MyDataBase-alarms_history_archived_at"];
            }
        }
        // alarms_history：按账号+会话类型+dataId 查询/更新极常见，复合索引加速 COUNT/UPDATE/DELETE
        if (![db executeUpdate:@"CREATE INDEX IF NOT EXISTS idx_alarms_hist_acct_type_dataid ON alarms_history (_acount_uid, alarmType, dataId)"]) {
            [MyDataBase printErrorForDebug:db tag:@"MyDataBase-alarms_history_index"];
        }
    }];

    // 保存当前的建库版本号
    [UserDefaultsToolKits saveDbVersion:DB_VERSION];
}

/**
 * <p>
 * 本方法实现数据库表及其它结构的删除.<br>
 * <b>数据库需要的表则其删除语句应该放在本方法里，有多少表就要多少个删除语句.</b> <br>
 * <br>
 *
 * 数据库升级时为确保数据库表结构的完整，本方法是简单的先尝试删除存在的表，然后再把所有表重建一次.
 * 这样带来的后果是历史数据将丢失，所幸本系统的历史数据没有意义，因为每登陆1次都要要至少确保自动重置缓存1次
 * 以尽量确保数据是最新的(缓存数据当然无法完全保证数据是最新的，只是在性能和数据的最新性方面作出的权衡选择).
 * </p>
 *
 * {@inheritDoc}
 */
+ (void) dropAllTables
{
    NSLog(@"[sqlite-MyDataBase] 删除之前的数据库表结构.");

    //    db.execSQL("DROP TABLE IF EXISTS " + ChatHistoryTable.TABLE_NAME);
    //    db.execSQL("DROP TABLE IF EXISTS " + AlarmsHistoryTable.TABLE_NAME);
    //    db.execSQL("DROP TABLE IF EXISTS " + GroupChatHistoryTable.TABLE_NAME);

    [MyDataBase dropTable:[NSString stringWithFormat:@"DROP TABLE IF EXISTS '%@'", [ChatHistoryTable getTableName]]];
    [MyDataBase dropTable:[NSString stringWithFormat:@"DROP TABLE IF EXISTS '%@'", [AlarmsHistoryTable getTableName]]];
    [MyDataBase dropTable:[NSString stringWithFormat:@"DROP TABLE IF EXISTS '%@'", [GroupChatHistoryTable getTableName]]];
    [MyDataBase dropTable:[NSString stringWithFormat:@"DROP TABLE IF EXISTS '%@'", [CallRecordsCacheTable getTableName]]];
}

// 用于安全的返回nil对象（用于NSArray等不能为nil的场景下）
+ (NSObject *)nullSafe:(NSObject *)o
{
    if(o == nil)
        return [NSNull null];
    else return o;
}

+ (void)printErrorForDebug:(FMDatabase *)db tag:(NSString *)TAG
{
    if(db != nil)
    {
        DDLogDebug(@"[sqlite-ErrorDebug-%@] errorMsg=%@, errorCode=%d", TAG, db.lastErrorMessage, db.lastErrorCode);
    }
}

@end
