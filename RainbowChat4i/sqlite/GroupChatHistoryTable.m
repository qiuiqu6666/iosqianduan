//telegram @wz662
#import "GroupChatHistoryTable.h"
#import "IMClientManager.h"
#import "MyDataBase.h"
#import "EVAToolKits.h"
#import "TimeTool.h"
#import "BasicTool.h"
#import "MsgBodyRoot.h"
#import "QuoteMeta.h"
#import "JSQMessage+RBConversationSeq.h"

/** 会话内消息序号（与接口 conversation_msg_seq / conv_seq 对齐）；未下发为 0 */
NSString const *GCHT_COLUMN_CONVERSATION_MSG_SEQ = @"conversation_msg_seq";

/** 表字段名：自增id（主键）（默认ident列，无需插入数据）*/
NSString const *GCHT_COLUMN_KEY_ID = @"_id";
/** 表字段名：本地数据所有者账号uid（联合主键之首要条件）*/
NSString const *GCHT_COLUMN_KEY_ACOUNT_UID = @"_acount_uid";
/** 表字段名：群组id（联合主键之次要条件）*/
NSString const *GCHT_COLUMN_KEY_GID = @"_gid";

/** 表字段名：消息发送者的uid ，@see JSQMessage.h*/
NSString const *GCHT_COLUMN_KEY_SENDER_ID = @"senderId";// add since 4.0

/** 表字段名：消息发送者昵称，@see JSQMessage.h  */
NSString const *GCHT_COLUMN_KEY_SENDER_DISPLAY_NAME = @"senderDisplayName";
/** 表字段名：消息时间，@see JSQMessage.h 。此字段值目前仅用于UI显示，不作它用） */
NSString const *GCHT_COLUMN_KEY_DATE = @"date";
/** 表字段名：消息内容，@see JSQMessage.h */
NSString const *GCHT_COLUMN_KEY_TEXT = @"text";
/** 表字段名：消息类型，@see JSQMessage.h中的MsgType枚举 */
NSString const *GCHT_COLUMN_KEY_MSG_TYPE = @"msgType";
/**
 * 表字段名：@see {@link JSQMessage}的同名列.
 * 补充说明：本消息指纹码字段目前仅用于"我"发出的消息的QoS送达判断机制，因而收到的消息是不需要存储的也没有存储哦. */
NSString const *GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL = @"finger_print_of_protocal";
/**
 * 表格字段名：@see {@link JSQMessage}的同名列.
 * 补充说明：消息所对应的群聊发送者发出的原始包协议包指纹，目前只在收到的消息对象中有意义，且仅用于群聊消息时作为消息"撤回"功能的匹配依据.
 * */
NSString const *GCHT_COLUMN_FINGER_PRINT_OF_PARENT = @"finger_print_of_parent";
/** 表字段名：发送状态（0 发送中 1 已送达 2 发送失败），仅对发出消息有效。 */
NSString const *GCHT_COLUMN_SEND_STATUS = @"send_status";

NSString const *GCHT_COLUMN_READ_BY_PARTNER = @"read_by_partner";

NSString const *GCHT_COLUMN_KEY_UPDATE_TIME = @"_update_time";

/** 存放于sqlLite数据库中的表名 */
NSString * const GCHT_TABLE_NAME = @"groupchat_msg";


@implementation GroupChatHistoryTable

/**
 * 从本地sqlLite的表中查询所需数据.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param condition 查询条件
 * @return 游标结果集
 */
- (FMResultSet *)queryHistoryImpl:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner condition:(NSString *)condition
{
    NSArray<NSString *> *filedNames = @[  GCHT_COLUMN_KEY_SENDER_ID
                                        , GCHT_COLUMN_KEY_SENDER_DISPLAY_NAME
                                        , GCHT_COLUMN_KEY_DATE
                                        , GCHT_COLUMN_KEY_TEXT
                                        , GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL
                                        , GCHT_COLUMN_FINGER_PRINT_OF_PARENT
                                        , GCHT_COLUMN_KEY_MSG_TYPE
                                        , GCHT_COLUMN_SEND_STATUS
                                          
                                        , COLUMN_KEY_QUOTE_FP
                                        , COLUMN_KEY_QUOTE_SENDER_UID
                                        , COLUMN_KEY_QUOTE_SENDER_NICK
                                        , COLUMN_KEY_QUOTE_STATUS
                                        , COLUMN_KEY_QUOTE_CONTENT
                                        , COLUMN_KEY_QUOTE_TYPE
                                        , GCHT_COLUMN_READ_BY_PARTNER
                                        , GCHT_COLUMN_CONVERSATION_MSG_SEQ];

    NSString *where = [NSString stringWithFormat:@"%@='%@'%@"
                       , GCHT_COLUMN_KEY_ACOUNT_UID
                       , acountUidOfOwner
                       , (condition == nil?@"": [NSString stringWithFormat:@" and %@", condition])];

    //获取结果集，返回参数就是查询结果
    FMResultSet *rs= [super query:db tableName:GCHT_TABLE_NAME fieldNames:filedNames filterSQL:where debugTag:@"GroupChatHistoryTable.queryHistoryImpl"];

    return rs;
}

/**
 返回历史聊天记录（目前是读取7天内的消息）.
 
 @param afterAndfp 载入消息的额外条件（当前用于搜索消息结果中查看某条消息时），即只加载这条消息之后的消息（包含该条消息自身），这个条件是fp指纹码，当为 nil时表示本条件不生效
 @param beforeFp 载入消息的额外条件（当前用于加载更多历史消息功能时），即只加载这条消息之前的消息（不含该条消息自身），这个条件是fp指纹码，当为 nil时表示本条件不生效
 @param beforeDate 载入消息的额外条件（当前用于加载更多历史消息功能时），即只加载这条消息之前的消息（不含该条消息自身），这个条件是消息的时间戳，当为0时表示本条件不生效
 @param limit YES表示只加载一页，否则加载所有的查询结果
 */
- (NSArray<JSQMessage *> *) findHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner gid:(NSString *)gid afterAndFingerPrint:(NSString *)afterAndfp beforeFingerPrint:(NSString *)beforeFp beforeDatetime:(long)beforeDate limit:(BOOL)limit
{
    NSMutableArray<JSQMessage *> *cpList= [NSMutableArray array];
    NSString *safeAu = acountUidOfOwner != nil ? acountUidOfOwner : @"";
    NSString *safeGid = gid != nil ? gid : @"";
    NSString *auEsc = [safeAu stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
    NSString *gidEsc = [safeGid stringByReplacingOccurrencesOfString:@"'" withString:@"''"];

    // 载入消息的额外条件，即只加载这条消息之前的消息，这个条件可以是fp指纹码也可以是消息的时间戳
    NSString *extraSQL = @"";
    if(beforeFp != nil) {
        NSString *bf = [beforeFp stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
        NSMutableString *fpScope = [NSMutableString string];
        [fpScope appendFormat:@"%@='%@' and %@='%@' and lower(", GCHT_COLUMN_KEY_ACOUNT_UID, auEsc, GCHT_COLUMN_KEY_GID, gidEsc];
        [fpScope appendString:(NSString *)GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL];
        [fpScope appendString:@")=lower('"];
        [fpScope appendString:bf];
        [fpScope appendString:@"')"];
        extraSQL = [NSString stringWithFormat:@" and ( %@ < IFNULL((select %@ from %@ where %@), 9223372036854775807) or ( %@ = IFNULL((select %@ from %@ where %@), 0) and %@ < IFNULL((select %@ from %@ where %@), 9223372036854775807) ) ) ",
                     GCHT_COLUMN_KEY_DATE, GCHT_COLUMN_KEY_DATE, GCHT_TABLE_NAME, (NSString *)fpScope,
                     GCHT_COLUMN_KEY_DATE, GCHT_COLUMN_KEY_DATE, GCHT_TABLE_NAME, (NSString *)fpScope,
                     GCHT_COLUMN_KEY_ID, GCHT_COLUMN_KEY_ID, GCHT_TABLE_NAME, (NSString *)fpScope];
    }
    else if (beforeDate > 0) {
        // 小于（<）该条消息时间的消息
        extraSQL = [NSString stringWithFormat:@" and %@ < %ld ", GCHT_COLUMN_KEY_DATE, beforeDate];
//      extraSQL = (" and "+GroupChatHistoryTable.COLUMN_KEY_DATE+" < "+afterFingerPrintOrDatetime);
    }
    
    // 载入消息的额外条件，即只加载这条消息之后的消息，这个条件是fp指纹码
    if(afterAndfp != nil) {
        NSString *af = [afterAndfp stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
        NSMutableString *fpScopeAfter = [NSMutableString string];
        [fpScopeAfter appendFormat:@"%@='%@' and %@='%@' and lower(", GCHT_COLUMN_KEY_ACOUNT_UID, auEsc, GCHT_COLUMN_KEY_GID, gidEsc];
        [fpScopeAfter appendString:(NSString *)GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL];
        [fpScopeAfter appendString:@")=lower('"];
        [fpScopeAfter appendString:af];
        [fpScopeAfter appendString:@"')"];
        extraSQL = [NSString stringWithFormat:@" and ( %@ > IFNULL((select %@ from %@ where %@), 0) or ( %@ = IFNULL((select %@ from %@ where %@), 0) and %@ >= IFNULL((select %@ from %@ where %@), 0) ) ) %@",
                     GCHT_COLUMN_KEY_DATE, GCHT_COLUMN_KEY_DATE, GCHT_TABLE_NAME, (NSString *)fpScopeAfter,
                     GCHT_COLUMN_KEY_DATE, GCHT_COLUMN_KEY_DATE, GCHT_TABLE_NAME, (NSString *)fpScopeAfter,
                     GCHT_COLUMN_KEY_ID, GCHT_COLUMN_KEY_ID, GCHT_TABLE_NAME, (NSString *)fpScopeAfter,
                     extraSQL];
    }
    

    // 与 ChatHistoryTable 一致：允许 _update_time IS NULL 的行参与查询，避免重进会话时最新记录被时间条件误过滤
    //条件是 where _uid ='1002' and "_update_time>datetime('2014-04-19','-7 day')，默认只取（当前）起7天内的消息（注意这里的结果是逆序的哦）
    NSString *condition = [NSString stringWithFormat:@"%@='%@' and (%@ IS NULL OR %@>datetime('%@','-%d day')) %@ order by %@ desc, %@ desc %@"
                           , GCHT_COLUMN_KEY_GID
                           , gid
                           , GCHT_COLUMN_KEY_UPDATE_TIME
                           , GCHT_COLUMN_KEY_UPDATE_TIME
                           , [TimeTool getCurrentDatePartStr]
                           , SQLITE_CHAT_MESSAGE_SOTRE_RANGE
                           , extraSQL
                           , GCHT_COLUMN_KEY_DATE
                           , GCHT_COLUMN_KEY_ID
                           , (limit ? [NSString stringWithFormat:@"LIMIT %d", CHATTING_MESSAGE_LOAD_ONECE] : @"")
                          ];

    FMResultSet *rs = [self queryHistoryImpl:db acountUidOfOwner:acountUidOfOwner condition:condition];

    if(rs != nil)
    {
        while (rs.next)
        {
            JSQMessage *cp = [[JSQMessage alloc] init];

            cp.senderId = [rs stringForColumnIndex:0];
            cp.senderDisplayName = [rs stringForColumnIndex:1];
            cp.date = [TimeTool dateFromChatHistoryStoredTime:[rs longLongIntForColumnIndex:2]];
            cp.text = [rs stringForColumnIndex:3];
            cp.fingerPrintOfProtocal = [rs stringForColumnIndex:4];
            cp.fingerPrintOfParent = [rs stringForColumnIndex:5];
            // 即消息类型，同android版的msgType
            cp.msgType = [BasicTool getIntValue:[rs stringForColumnIndex:6] defaultVal:-1];
            int savedSendStatus = [rs intForColumnIndex:7];
            
            cp.quote_fp = [rs stringForColumnIndex:8];
            cp.quote_sender_uid = [rs stringForColumnIndex:9];
            cp.quote_sender_nick = [rs stringForColumnIndex:10];
            cp.quote_status = [BasicTool getIntValue:[rs stringForColumnIndex:11] defaultVal:0];
            cp.quote_content = [rs stringForColumnIndex:12];
            cp.quote_type = [BasicTool getIntValue:[rs stringForColumnIndex:13] defaultVal:0];
            if ([cp isOutgoing]) {
                cp.readByPartner = ([rs intForColumnIndex:14] != 0);
            }
            cp.rb_conversationMsgSeq = [rs longLongIntForColumnIndex:15];

            cp.sendStatus = (savedSendStatus == SendStatus_SEND_FAILD || savedSendStatus == SendStatus_SNEDING) ? savedSendStatus : SendStatus_BE_RECEIVED;
            cp.sendStatusSecondary = SendStatusSecondary_NONE;
//          cp.getDownloadStatus().setStatus(DownloadStatus.NONE);

            [cpList addObject:cp];
        }
    }
    // fs返回为nil即表示查询出错了
    else
    {
        [MyDataBase printErrorForDebug:db tag:@"GroupChatHistoryTable.findHistory"];
    }

    return cpList;
}

- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   gid:(NSString *)gid
                   cme:(JSQMessage *)cme
{
    return [self insertHistory:db acountUidOfOwner:acountUidOfOwner gid:gid cme:cme didInsert:NULL];
}

- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   gid:(NSString *)gid
                   cme:(JSQMessage *)cme
             didInsert:(BOOL *)outDidInsert
{
    if(cme != nil && (cme.text == nil || [cme.text isKindOfClass:NSString.class]))
    {
        NSString *luid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        int readCol = ([luid length] > 0 && [cme.senderId isEqualToString:luid] && cme.readByPartner) ? 1 : 0;
        return [self insertHistory:db
                  acountUidOfOwner:acountUidOfOwner
                               gid:gid
                          senderId:cme.senderId
                   sendDisplayName:cme.senderDisplayName
                              date:[TimeTool javaMillisFromNSDate:cme.date]
                              text:cme.text
                           msgType:[NSString stringWithFormat:@"%d",cme.msgType]
             fingerPrintOfProtocal:cme.fingerPrintOfProtocal
               fingerPrintOfParent:cme.fingerPrintOfParent
                         sendStatus:cme.sendStatus
                     readByPartner:(readCol != 0)
                conversationMsgSeq:cme.rb_conversationMsgSeq
                             quote:cme
                         didInsert:outDidInsert];
    }
    else
    {
        DDLogDebug(@"[sqlite-GroupChatHistoryTable] 未知的text类型：%@", cme.text);
        return NO;
    }
}

// 插入一行数据到表中.
- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   gid:(NSString *)gid
              senderId:(NSString *)senderId
       sendDisplayName:(NSString *)sendDisplayName
                  date:(long long)dateMillis
                  text:(NSString *)text
               msgType:(NSString *)msgType
 fingerPrintOfProtocal:(NSString *)fingerPrintOfProtocal
   fingerPrintOfParent:(NSString *)fingerPrintOfParent
             sendStatus:(int)sendStatus
                 quote:(QuoteMeta *)quoteMeta

{
    return [self insertHistory:db acountUidOfOwner:acountUidOfOwner gid:gid senderId:senderId sendDisplayName:sendDisplayName date:dateMillis text:text msgType:msgType fingerPrintOfProtocal:fingerPrintOfProtocal fingerPrintOfParent:fingerPrintOfParent sendStatus:sendStatus readByPartner:NO conversationMsgSeq:0 quote:quoteMeta didInsert:NULL];
}

- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   gid:(NSString *)gid
              senderId:(NSString *)senderId
       sendDisplayName:(NSString *)sendDisplayName
                  date:(long long)dateMillis
                  text:(NSString *)text
               msgType:(NSString *)msgType
 fingerPrintOfProtocal:(NSString *)fingerPrintOfProtocal
   fingerPrintOfParent:(NSString *)fingerPrintOfParent
             sendStatus:(int)sendStatus
         readByPartner:(BOOL)readByPartner
    conversationMsgSeq:(long long)conversationMsgSeq
                 quote:(QuoteMeta *)quoteMeta
             didInsert:(BOOL *)outDidInsert
{
    if (outDidInsert != NULL) {
        *outDidInsert = NO;
    }
    // 同一群下相同指纹的消息视为同一条，避免重复插入导致拉取时出现重复消息
    if (fingerPrintOfProtocal != nil && fingerPrintOfProtocal.length > 0) {
        NSString *checkSql = [NSString stringWithFormat:@"SELECT 1 FROM %@ WHERE %@=? AND %@=? AND %@=? LIMIT 1",
                             GCHT_TABLE_NAME, GCHT_COLUMN_KEY_ACOUNT_UID, GCHT_COLUMN_KEY_GID, GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL];
        FMResultSet *rs = [db executeQuery:checkSql withArgumentsInArray:@[acountUidOfOwner, gid, fingerPrintOfProtocal]];
        if (rs != nil && [rs next]) {
            [rs close];
            DDLogVerbose(@"[sqlite-GroupChatHistoryTable.insertHistory] 已存在相同指纹消息，跳过插入 fp=%@", fingerPrintOfProtocal);
            return YES;
        }
        if (rs) [rs close];
    }

    NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
                     , GCHT_TABLE_NAME

                     , GCHT_COLUMN_KEY_ACOUNT_UID
                     , GCHT_COLUMN_KEY_GID
                     , GCHT_COLUMN_KEY_SENDER_ID
                     , GCHT_COLUMN_KEY_SENDER_DISPLAY_NAME
                     , GCHT_COLUMN_KEY_DATE
                     , GCHT_COLUMN_KEY_TEXT
                     , GCHT_COLUMN_KEY_MSG_TYPE
                     , GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL
                     , GCHT_COLUMN_FINGER_PRINT_OF_PARENT
                     , GCHT_COLUMN_SEND_STATUS
                     , GCHT_COLUMN_READ_BY_PARTNER
                     , GCHT_COLUMN_CONVERSATION_MSG_SEQ
                     
                     , COLUMN_KEY_QUOTE_FP
                     , COLUMN_KEY_QUOTE_SENDER_UID
                     , COLUMN_KEY_QUOTE_SENDER_NICK
                     , COLUMN_KEY_QUOTE_STATUS
                     , COLUMN_KEY_QUOTE_CONTENT
                     , COLUMN_KEY_QUOTE_TYPE];


    DDLogVerbose(@"[sqlite-GroupChatHistoryTable.insertHistory] 组织完成的SQL语句：%@", sql);

    int readCol = readByPartner ? 1 : 0;
    BOOL ok = [db executeUpdate:sql withArgumentsInArray:@[acountUidOfOwner
                                                        , gid
                                                        , senderId
                                                        , sendDisplayName
                                                        , [NSNumber numberWithLongLong:dateMillis]
                                                        , [MyDataBase nullSafe:text]
                                                        , msgType
                                                        , [MyDataBase nullSafe:fingerPrintOfProtocal]
                                                        , [MyDataBase nullSafe:fingerPrintOfParent]
                                                        , @(sendStatus)
                                                        , [NSNumber numberWithInt:readCol]
                                                        , @(conversationMsgSeq)
                                                        
                                                        , [MyDataBase nullSafe:quoteMeta.quote_fp]
                                                        , [MyDataBase nullSafe:quoteMeta.quote_sender_uid]
                                                        , [MyDataBase nullSafe:quoteMeta.quote_sender_nick]
                                                        , [NSNumber numberWithInt:quoteMeta.quote_status]
                                                        , [MyDataBase nullSafe:quoteMeta.quote_content]
                                                        , [NSNumber numberWithInt:quoteMeta.quote_type]
                                                      ]];
    if (ok && outDidInsert != NULL) {
        *outDidInsert = YES;
    }
    return ok;
}

- (BOOL) upsertHistoryMergeFromServer:(FMDatabase *)db
                     acountUidOfOwner:(NSString *)acountUidOfOwner
                                  gid:(NSString *)gid
                                  cme:(JSQMessage *)cme
                            didInsert:(BOOL *)outDidInsert
                            didUpdate:(BOOL *)outDidUpdate
{
    if (outDidInsert != NULL) {
        *outDidInsert = NO;
    }
    if (outDidUpdate != NULL) {
        *outDidUpdate = NO;
    }
    if (db == nil || acountUidOfOwner.length == 0 || gid.length == 0 || cme == nil) {
        return NO;
    }
    if (!(cme.text == nil || [cme.text isKindOfClass:[NSString class]])) {
        return NO;
    }

    NSString *fp = cme.fingerPrintOfProtocal;
    if (fp.length == 0) {
        return [self insertHistory:db acountUidOfOwner:acountUidOfOwner gid:gid cme:cme didInsert:outDidInsert];
    }

    long long newMillis = [TimeTool javaMillisFromNSDate:cme.date];
    NSString *sel = [NSString stringWithFormat:@"SELECT %@, %@, %@, %@ FROM %@ WHERE %@=? AND %@=? AND %@=? LIMIT 1",
                     GCHT_COLUMN_KEY_DATE, GCHT_COLUMN_KEY_MSG_TYPE, GCHT_COLUMN_READ_BY_PARTNER, GCHT_COLUMN_CONVERSATION_MSG_SEQ, GCHT_TABLE_NAME,
                     GCHT_COLUMN_KEY_ACOUNT_UID, GCHT_COLUMN_KEY_GID, GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL];
    FMResultSet *rs = [db executeQuery:sel withArgumentsInArray:@[acountUidOfOwner, gid, fp]];
    BOOL exists = (rs != nil && [rs next]);
    long long oldMillis = exists ? [rs longLongIntForColumnIndex:0] : 0;
    int oldType = exists ? [BasicTool getIntValue:[rs stringForColumnIndex:1] defaultVal:-1] : -1;
    int oldReadByPartner = exists ? [rs intForColumnIndex:2] : 0;
    long long oldConvSeq = exists ? [rs longLongIntForColumnIndex:3] : 0;
    if (rs) {
        [rs close];
    }

    if (!exists) {
        return [self insertHistory:db acountUidOfOwner:acountUidOfOwner gid:gid cme:cme didInsert:outDidInsert];
    }

    BOOL incomingRevoke = (cme.msgType == TM_TYPE_REVOKE);
    BOOL existingRevoke = (oldType == TM_TYPE_REVOKE);
    BOOL preferNew = NO;
    if (incomingRevoke) {
        preferNew = YES;
    } else if (existingRevoke) {
        preferNew = NO;
    } else {
        preferNew = (newMillis >= oldMillis);
    }

    if (!preferNew) {
        return YES;
    }

    QuoteMeta *qm = (QuoteMeta *)cme;
    NSString *parentFp = cme.fingerPrintOfParent;
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    BOOL outgoing = (localUid.length > 0 && [cme.senderId isEqualToString:localUid]);
    int mergedRead = outgoing ? ((oldReadByPartner != 0 || cme.readByPartner) ? 1 : 0) : 0;
    long long newSeq = cme.rb_conversationMsgSeq;
    long long mergedSeq = (newSeq > 0) ? ((oldConvSeq > 0) ? MAX(oldConvSeq, newSeq) : newSeq) : oldConvSeq;

    // SET 共 15 列（与下方 withArgumentsInArray 一致）；勿多写一个 %@=?，否则 stringWithFormat 与 WHERE 列名错位会报错或生成非法 SQL。
    NSString *upd = [NSString stringWithFormat:
                     @"UPDATE %@ SET %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=? WHERE %@=? AND %@=? AND %@=?",
                     GCHT_TABLE_NAME,
                     GCHT_COLUMN_KEY_SENDER_ID, GCHT_COLUMN_KEY_SENDER_DISPLAY_NAME, GCHT_COLUMN_KEY_DATE, GCHT_COLUMN_KEY_TEXT, GCHT_COLUMN_KEY_MSG_TYPE,
                     GCHT_COLUMN_FINGER_PRINT_OF_PARENT,
                     GCHT_COLUMN_SEND_STATUS,
                     GCHT_COLUMN_READ_BY_PARTNER,
                     GCHT_COLUMN_CONVERSATION_MSG_SEQ,
                     COLUMN_KEY_QUOTE_FP, COLUMN_KEY_QUOTE_SENDER_UID, COLUMN_KEY_QUOTE_SENDER_NICK,
                     COLUMN_KEY_QUOTE_STATUS, COLUMN_KEY_QUOTE_CONTENT, COLUMN_KEY_QUOTE_TYPE,
                     GCHT_COLUMN_KEY_ACOUNT_UID, GCHT_COLUMN_KEY_GID, GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL];
    BOOL ok = [db executeUpdate:upd withArgumentsInArray:@[
        cme.senderId ?: @"",
        cme.senderDisplayName ?: @"",
        @(newMillis),
        [MyDataBase nullSafe:cme.text],
        [NSString stringWithFormat:@"%d", cme.msgType],
        [MyDataBase nullSafe:parentFp],
        @((int)cme.sendStatus),
        @(mergedRead),
        @(mergedSeq),
        [MyDataBase nullSafe:qm.quote_fp],
        [MyDataBase nullSafe:qm.quote_sender_uid],
        [MyDataBase nullSafe:qm.quote_sender_nick],
        @(qm.quote_status),
        [MyDataBase nullSafe:qm.quote_content],
        @(qm.quote_type),
        acountUidOfOwner,
        gid,
        fp
    ]];
    if (ok && outDidUpdate != NULL) {
        *outDidUpdate = YES;
    }
    return ok;
}

// 删除超出保存期限的老聊天消息.
- (BOOL) deleteOldHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner gid:(NSString *)gid
{
    // 删除7天前的所有聊天消息
    NSString *where = [NSString stringWithFormat:@"%@='%@' and %@='%@' and %@<=datetime('%@','-%d day')"
                       , GCHT_COLUMN_KEY_ACOUNT_UID, acountUidOfOwner
                       , GCHT_COLUMN_KEY_GID, gid
                       , GCHT_COLUMN_KEY_UPDATE_TIME, [TimeTool getCurrentDatePartStr], SQLITE_CHAT_MESSAGE_SOTRE_RANGE
                       ];

    return [super delete:db tableName:GCHT_TABLE_NAME filterSQL:where debugTag:@"ChatHistoryTable.deleteOldHistory"];
}

// 删除与某人的本地存储的所有聊天消息.
- (long) deleteHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner gid:(NSString *)gid
{
    // 指定消息发送者的本地记录
    NSString *where = [NSString stringWithFormat:@"%@='%@' and %@='%@'"
                       , GCHT_COLUMN_KEY_ACOUNT_UID, acountUidOfOwner
                       , GCHT_COLUMN_KEY_GID, gid
                       ];

    return [super delete:db tableName:GCHT_TABLE_NAME filterSQL:where debugTag:@"GroupChatHistoryTable.deleteHistory"];
}

- (long) deleteHistoryWithFp:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fpForMessage
{
    // 指定消息发送者的本地记录
    NSString *where = [NSString stringWithFormat:@"%@='%@' and %@='%@'"
                       , GCHT_COLUMN_KEY_ACOUNT_UID, acountUidOfOwner
                       , GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL, fpForMessage
                       ];

    return [super delete:db tableName:GCHT_TABLE_NAME filterSQL:where debugTag:@"GroupChatHistoryTable.deleteHistoryWithFp"];
}

// 消息撤回成功后，更新本地消息的数据
- (BOOL) updateForRevoke:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)parentFpForMessage meta:(RevokedMeta *)textObj
{
    /* ------------------- 先更新被撤回消息本身 ---------------------- */
    // 指纹码列条件语句
    NSString *fpField = [NSString stringWithFormat:@"%@='%@'", GCHT_COLUMN_FINGER_PRINT_OF_PARENT, parentFpForMessage];
    // 附加更新条件
    NSString *where = [NSString stringWithFormat:@"%@='%@' and %@", GCHT_COLUMN_KEY_ACOUNT_UID, acountUidOfOwner, fpField];
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"UPDATE %@ SET %@=?, %@=? WHERE %@"
                            , GCHT_TABLE_NAME
                            , GCHT_COLUMN_KEY_MSG_TYPE
                            , GCHT_COLUMN_KEY_TEXT
                            , where];
    
    DDLogDebug(@"********************************** updateForRevoke-群聊 START");
    DDLogDebug(@"[sqlite-GroupChatHistoryTable.updateForRevoke]【消息撤回 1/2开始】组织完成的SQL语句：%@", sql);
    BOOL updateSucess = [db executeUpdate:sql withArgumentsInArray:@[[NSString stringWithFormat:@"%d",TM_TYPE_REVOKE], [MyDataBase nullSafe:[EVAToolKits toJSON:textObj]]]];
    DDLogDebug(@"[sqlite-GroupChatHistoryTable.updateForRevoke]【消息撤回 1/2完成】updateSucess1=%d", updateSucess);
    
    
    /* ------------------- 再更新"引用"了被撤回消息的那些消息 ------------ */
    // 指纹码列条件语句
    NSString *fpField2 = [NSString stringWithFormat:@"%@='%@'", COLUMN_KEY_QUOTE_FP, parentFpForMessage];
    // 附加更新条件
    NSString *where2 = [NSString stringWithFormat:@"%@='%@' and %@", GCHT_COLUMN_KEY_ACOUNT_UID, acountUidOfOwner, fpField2];
    
    NSMutableString *sql2 = [NSMutableString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@"
                            , GCHT_TABLE_NAME
                            , COLUMN_KEY_QUOTE_STATUS
                            , where2];
    
    DDLogDebug(@"[sqlite-GroupChatHistoryTable.updateForRevoke]【消息撤回 2/2开始】组织完成的SQL语句：%@", sql2);
    // 设置引用状态为1（表示原消息已被撤回）
    BOOL updateSucess2 = [db executeUpdate:sql2 withArgumentsInArray:@[@"1"]];
    DDLogDebug(@"[sqlite-GroupChatHistoryTable.updateForRevoke]【消息撤回 2/2完成】updateSucess2=%d", updateSucess2);
    DDLogDebug(@"********************************** updateForRevoke-群聊 END");
    
    return updateSucess;
}


#pragma mark - 多端增量同步相关方法

- (long)getLatestMessageTimestamp:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner gid:(NSString *)gid
{
    if (db == nil || acountUidOfOwner == nil || gid == nil) return 0;

    NSString *sql = [NSString stringWithFormat:
                     @"SELECT MAX(%@) FROM %@ WHERE %@=? AND %@=?",
                     GCHT_COLUMN_KEY_DATE, GCHT_TABLE_NAME, GCHT_COLUMN_KEY_ACOUNT_UID, GCHT_COLUMN_KEY_GID];

    FMResultSet *rs = [db executeQuery:sql withArgumentsInArray:@[acountUidOfOwner, gid]];
    long result = 0;
    if (rs && [rs next]) {
        result = [rs longForColumnIndex:0];
    }
    [rs close];
    return result;
}

- (long long)maxConversationMsgSeq:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner gid:(NSString *)gid
{
    if (!db || acountUidOfOwner.length == 0 || gid.length == 0) {
        return 0;
    }
    NSString *sql = [NSString stringWithFormat:@"SELECT MAX(%@) FROM %@ WHERE %@=? AND %@=?",
                     GCHT_COLUMN_CONVERSATION_MSG_SEQ, GCHT_TABLE_NAME, GCHT_COLUMN_KEY_ACOUNT_UID, GCHT_COLUMN_KEY_GID];
    FMResultSet *rs = [db executeQuery:sql withArgumentsInArray:@[acountUidOfOwner, gid]];
    long long v = 0;
    if (rs != nil && [rs next] && ![rs columnIndexIsNull:0]) {
        v = [rs longLongIntForColumnIndex:0];
    }
    if (rs) {
        [rs close];
    }
    return v;
}

- (BOOL)hasMessageWithFingerprint:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fp
{
    if (db == nil || acountUidOfOwner == nil || fp == nil || fp.length == 0) return NO;

    NSString *sql = [NSString stringWithFormat:
                     @"SELECT COUNT(*) FROM %@ WHERE %@=? AND %@=?",
                     GCHT_TABLE_NAME, GCHT_COLUMN_KEY_ACOUNT_UID, GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL];

    FMResultSet *rs = [db executeQuery:sql withArgumentsInArray:@[acountUidOfOwner, fp]];
    BOOL exists = NO;
    if (rs && [rs next]) {
        exists = [rs intForColumnIndex:0] > 0;
    }
    [rs close];
    return exists;
}

- (BOOL)markOutgoingReadByPartnerUpToWatermark:(FMDatabase *)db
                           acountUidOfOwner:(NSString *)acountUidOfOwner
                                          gid:(NSString *)gid
                             localSenderIds:(NSArray<NSString *> *)localSenderIds
                           partnerReadTimeMs:(long long)partnerReadTimeMs
{
    if (!db || acountUidOfOwner.length == 0 || gid.length == 0 || partnerReadTimeMs <= 0) {
        return NO;
    }
    NSMutableOrderedSet *uniq = [NSMutableOrderedSet orderedSet];
    for (NSString *s in localSenderIds) {
        if ([s isKindOfClass:[NSString class]] && s.length > 0) {
            [uniq addObject:s];
        }
    }
    if (uniq.count == 0) {
        return NO;
    }
    NSMutableArray *ph = [NSMutableArray arrayWithCapacity:uniq.count];
    for (NSUInteger i = 0; i < uniq.count; i++) {
        [ph addObject:@"?"];
    }
    NSString *inList = [ph componentsJoinedByString:@","];
    NSString *sql = [NSString stringWithFormat:
                     @"UPDATE %@ SET %@=1 WHERE %@=? AND %@=? AND %@ IN (%@) AND IFNULL(%@,0)=0 AND ((%@ >= 100000000000 AND %@ <= ?) OR (%@ > 0 AND %@ < 100000000000 AND (%@ * 1000) <= ?))",
                     GCHT_TABLE_NAME,
                     GCHT_COLUMN_READ_BY_PARTNER,
                     GCHT_COLUMN_KEY_ACOUNT_UID,
                     GCHT_COLUMN_KEY_GID,
                     GCHT_COLUMN_KEY_SENDER_ID,
                     inList,
                     GCHT_COLUMN_READ_BY_PARTNER,
                     GCHT_COLUMN_KEY_DATE,
                     GCHT_COLUMN_KEY_DATE,
                     GCHT_COLUMN_KEY_DATE,
                     GCHT_COLUMN_KEY_DATE,
                     GCHT_COLUMN_KEY_DATE];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:acountUidOfOwner, gid, nil];
    [args addObjectsFromArray:[uniq array]];
    [args addObject:@(partnerReadTimeMs)];
    [args addObject:@(partnerReadTimeMs)];
    return [db executeUpdate:sql withArgumentsInArray:args];
}

- (BOOL)updateSendStatus:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fp sendStatus:(int)sendStatus
{
    if (!db || !acountUidOfOwner.length || !fp.length) return NO;
    NSString *where = [NSString stringWithFormat:@"%@='%@' and %@='%@'",
                       GCHT_COLUMN_KEY_ACOUNT_UID, acountUidOfOwner,
                       GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL, fp];
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@",
                     GCHT_TABLE_NAME, GCHT_COLUMN_SEND_STATUS, where];
    return [db executeUpdate:sql withArgumentsInArray:@[@(sendStatus)]];
}

- (BOOL)markStaleOutgoingSendingMessagesAsFailed:(FMDatabase *)db
                                acountUidOfOwner:(NSString *)acountUidOfOwner
                                             gid:(NSString *)gid
                                  localSenderIds:(NSArray<NSString *> *)localSenderIds
{
    if (!db || !acountUidOfOwner.length || !gid.length || localSenderIds.count == 0) return NO;

    NSMutableArray<NSString *> *uniqSenderIds = [NSMutableArray array];
    for (NSString *senderId in localSenderIds) {
        if (![senderId isKindOfClass:[NSString class]] || senderId.length == 0) continue;
        if (![uniqSenderIds containsObject:senderId]) {
            [uniqSenderIds addObject:senderId];
        }
    }
    if (uniqSenderIds.count == 0) return NO;

    NSMutableArray<NSString *> *placeholders = [NSMutableArray array];
    for (__unused NSString *senderId in uniqSenderIds) {
        [placeholders addObject:@"?"];
    }

    NSString *sql = [NSString stringWithFormat:
                     @"UPDATE %@ SET %@=? WHERE %@=? AND %@=? AND %@=? AND %@ IN (%@)",
                     GCHT_TABLE_NAME,
                     GCHT_COLUMN_SEND_STATUS,
                     GCHT_COLUMN_KEY_ACOUNT_UID,
                     GCHT_COLUMN_KEY_GID,
                     GCHT_COLUMN_SEND_STATUS,
                     GCHT_COLUMN_KEY_SENDER_ID,
                     [placeholders componentsJoinedByString:@","]];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:
                            @(SendStatus_SEND_FAILD),
                            acountUidOfOwner,
                            gid,
                            @(SendStatus_SNEDING), nil];
    [args addObjectsFromArray:uniqSenderIds];
    return [db executeUpdate:sql withArgumentsInArray:args];
}

#pragma mark - 静态类方法

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
                         '%@' INTEGER ,\
                         '%@' TEXT ,\
                         '%@' TEXT ,\
                         '%@' TEXT ,\
                         '%@' INTEGER DEFAULT 1,\
                         '%@' INTEGER DEFAULT 0,\
                         '%@' INTEGER DEFAULT 0,\
                         '%@' TEXT ,\
                         '%@' TEXT ,\
                         '%@' TEXT ,\
                         '%@' INTEGER ,\
                         '%@' TEXT ,\
                         '%@' INTEGER ,\
                         '%@' TEXT ,\
                         '%@' TIMESTAMP default (datetime('now', 'localtime'))\
                     )"
                     , GCHT_TABLE_NAME
                     , GCHT_COLUMN_KEY_ID
                     , GCHT_COLUMN_KEY_ACOUNT_UID
                     , GCHT_COLUMN_KEY_GID
                     , GCHT_COLUMN_KEY_SENDER_ID
                     , GCHT_COLUMN_KEY_SENDER_DISPLAY_NAME
                     , GCHT_COLUMN_KEY_DATE
                     , GCHT_COLUMN_KEY_MSG_TYPE
                     , GCHT_COLUMN_FINGER_PRINT_OF_PROTOCAL
                     , GCHT_COLUMN_FINGER_PRINT_OF_PARENT
                     , GCHT_COLUMN_SEND_STATUS
                     , GCHT_COLUMN_READ_BY_PARTNER
                     , GCHT_COLUMN_CONVERSATION_MSG_SEQ
                     
                     , COLUMN_KEY_QUOTE_FP
                     , COLUMN_KEY_QUOTE_SENDER_UID
                     , COLUMN_KEY_QUOTE_SENDER_NICK
                     , COLUMN_KEY_QUOTE_STATUS
                     , COLUMN_KEY_QUOTE_CONTENT
                     , COLUMN_KEY_QUOTE_TYPE
                     
                     , GCHT_COLUMN_KEY_TEXT
                     , GCHT_COLUMN_KEY_UPDATE_TIME
                     ];

    return sql;
}

+ (NSString *) getTableName
{
    return GCHT_TABLE_NAME;
}

@end
