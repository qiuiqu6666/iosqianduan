//telegram @wz662
#import "ChatHistoryTable.h"
#import "TimeTool.h"
#import "MyDataBase.h"
#import "IMClientManager.h"
#import "EVAToolKits.h"
#import "VoipRecordMeta.h"
#import "MsgBodyRoot.h"
#import "BasicTool.h"
#import "QuoteMeta.h"
#import "JSQMessage+RBConversationSeq.h"

/** 会话内消息序号（与接口 conversation_msg_seq / conv_seq 对齐）；未下发为 0 */
NSString const *COLUMN_CONVERSATION_MSG_SEQ = @"conversation_msg_seq";

/** 表字段名：自增id【主键】（默认ident列，无需插入数据）*/
NSString const *COLUMN_KEY_ID = @"_id";
/** 表字段名：本地数据所有者账号uid【联合主键之首要条件】*/
NSString const *COLUMN_KEY_ACOUNT_UID = @"_acount_uid";
/** 表字段名：对方的UID，即与“我”聊天者的uid【联合主键之次要条件】*/
NSString const *COLUMN_KEY_UID = @"_uid";

/** 表字段名：消息发送者的UID（通过此字段，可以区分是“我”还是“对方”发的消息），@see JSQMessage.h */
NSString const *COLUMN_KEY_SENDER_ID = @"senderId";// add since 4.0

/** 表字段名：消息发送者昵称，@see JSQMessage.h */
NSString const *COLUMN_KEY_SENDER_DISPLAY_NAME = @"senderDisplayName";
/** 表字段名：消息时间，@see JSQMessage.h 。此字段值目前仅用于UI显示，不作它用） */
NSString const *COLUMN_KEY_DATE = @"date";
/** 表字段名：消息内容，@see JSQMessage.h */
NSString const *COLUMN_KEY_TEXT = @"text";
/** 表字段名：消息类型，@see JSQMessage.h中的MsgType枚举 */
NSString const *COLUMN_KEY_MSG_TYPE = @"msgType";
/**
 * 表字段名：@see {@link JMessage}的同名列.
 * 补充说明：本消息指纹码字段目前仅用于"我"发出的消息的QoS送达判断机制，因而收到的消息是不需要存储的也没有存储哦. */
NSString const *COLUMN_FINGER_PRINT_OF_PROTOCAL = @"finger_print_of_protocal";
/** 表字段名：发送状态（0 发送中 1 已送达 2 发送失败），仅对发出消息有效，用于重启后恢复红点 */
NSString const *COLUMN_SEND_STATUS = @"send_status";
/** 对方是否已读本条（仅「我」发出的消息有意义；与 UI readByPartner / 水位一致，持久化后进会话无需等服务器再绘双勾） */
NSString const *COLUMN_READ_BY_PARTNER = @"read_by_partner";
NSString const *COLUMN_KEY_UPDATE_TIME = @"_update_time";

/** 存放于sqlLite数据库中的表名 */
NSString * const TABLE_NAME = @"chat_msg";

static NSString *RBNormalizedFingerprintForSqlLookup(NSString *fp)
{
    if (fp == nil) return nil;
    NSString *trimmed = [[fp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    return trimmed.length > 0 ? trimmed : nil;
}

@implementation ChatHistoryTable

/**
 * 从本地sqlLite的表中查询所需数据.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param condition 查询条件
 * @return 游标结果集
 */
- (FMResultSet *)queryHistoryImpl:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner condition:(NSString *)condition
{
    NSArray<NSString *> *filedNames = @[  COLUMN_KEY_SENDER_ID
                                        , COLUMN_KEY_SENDER_DISPLAY_NAME
                                        , COLUMN_KEY_DATE
                                        , COLUMN_KEY_TEXT
                                        , COLUMN_FINGER_PRINT_OF_PROTOCAL
                                        , COLUMN_KEY_MSG_TYPE
                                        , COLUMN_SEND_STATUS
                                        , COLUMN_KEY_QUOTE_FP
                                        , COLUMN_KEY_QUOTE_SENDER_UID
                                        , COLUMN_KEY_QUOTE_SENDER_NICK
                                        , COLUMN_KEY_QUOTE_STATUS
                                        , COLUMN_KEY_QUOTE_CONTENT
                                        , COLUMN_KEY_QUOTE_TYPE
                                        , COLUMN_READ_BY_PARTNER
                                        , COLUMN_CONVERSATION_MSG_SEQ];

    NSString *where = [NSString stringWithFormat:@"%@='%@'%@"
                       , COLUMN_KEY_ACOUNT_UID
                       , acountUidOfOwner
                       , (condition == nil?@"": [NSString stringWithFormat:@" and %@", condition])];

    //获取结果集，返回参数就是查询结果
    FMResultSet *rs= [super query:db tableName:TABLE_NAME fieldNames:filedNames filterSQL:where debugTag:@"ChatHistoryTable.queryHistoryImpl"];

    return rs;
}

/**
 返回历史聊天记录（目前是读取7天内的消息）.

 @param afterAndfp 载入消息的额外条件（当前用于搜索消息结果中查看某条消息时），即只加载这条消息之后的消息（包含该条消息自身），这个条件是fp指纹码，当为 nil时表示本条件不生效
 @param beforeFp 载入消息的额外条件（当前用于加载更多历史消息功能时），即只加载这条消息之前的消息（不含该条消息自身），这个条件是fp指纹码，当为 nil时表示本条件不生效
 @param beforeDate 载入消息的额外条件（当前用于加载更多历史消息功能时），即只加载这条消息之前的消息（不含该条消息自身），这个条件是消息的时间戳，当为0时表示本条件不生效
 @param limit YES表示只加载一页，否则加载所有的查询结果
 */
- (NSArray<JSQMessage *> *) findHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner uid:(NSString *)uid afterAndFingerPrint:(NSString *)afterAndfp beforeFingerPrint:(NSString *)beforeFp beforeDatetime:(long)beforeDate limit:(BOOL)limit
{
    NSMutableArray<JSQMessage *> *cpList= [NSMutableArray array];
    NSString *safeAu = acountUidOfOwner != nil ? acountUidOfOwner : @"";
    NSString *safeUid = uid != nil ? uid : @"";
    NSString *auEsc = [safeAu stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
    NSString *uidEsc = [safeUid stringByReplacingOccurrencesOfString:@"'" withString:@"''"];

    // 载入消息的额外条件，即只加载这条消息之前的消息，这个条件可以是fp指纹码也可以是消息的时间戳
    NSString *extraSQL = @"";
    if(beforeFp != nil) {
        NSString *bf = [beforeFp stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
        NSMutableString *fpScope = [NSMutableString string];
        [fpScope appendFormat:@"%@='%@' and %@='%@' and lower(", COLUMN_KEY_ACOUNT_UID, auEsc, COLUMN_KEY_UID, uidEsc];
        [fpScope appendString:(NSString *)COLUMN_FINGER_PRINT_OF_PROTOCAL];
        [fpScope appendString:@")=lower('"];
        [fpScope appendString:bf];
        [fpScope appendString:@"')"];
        // lower(...)：搜索接口 fp 与库内大小写可能不一致；子查询须带账号/会话，避免误匹配其它会话同 fp
        extraSQL = [NSString stringWithFormat:@" and ( %@ < IFNULL((select %@ from %@ where %@), 9223372036854775807) or ( %@ = IFNULL((select %@ from %@ where %@), 0) and %@ < IFNULL((select %@ from %@ where %@), 9223372036854775807) ) ) ",
                     COLUMN_KEY_DATE, COLUMN_KEY_DATE, TABLE_NAME, (NSString *)fpScope,
                     COLUMN_KEY_DATE, COLUMN_KEY_DATE, TABLE_NAME, (NSString *)fpScope,
                     COLUMN_KEY_ID, COLUMN_KEY_ID, TABLE_NAME, (NSString *)fpScope];
    }
    else if (beforeDate > 0) {
        // 小于（<）该条消息时间的消息
        extraSQL = [NSString stringWithFormat:@" and %@ < %ld ", COLUMN_KEY_DATE, beforeDate];
//      extraSQL = (" and "+ChatHistoryTable.COLUMN_KEY_DATE+" < "+afterFingerPrintOrDatetime);
    }
    
    // 载入消息的额外条件，即只加载这条消息之后的消息，这个条件是fp指纹码
    if(afterAndfp != nil) {
        NSString *af = [afterAndfp stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
        NSMutableString *fpScopeAfter = [NSMutableString string];
        [fpScopeAfter appendFormat:@"%@='%@' and %@='%@' and lower(", COLUMN_KEY_ACOUNT_UID, auEsc, COLUMN_KEY_UID, uidEsc];
        [fpScopeAfter appendString:(NSString *)COLUMN_FINGER_PRINT_OF_PROTOCAL];
        [fpScopeAfter appendString:@")=lower('"];
        [fpScopeAfter appendString:af];
        [fpScopeAfter appendString:@"')"];
        extraSQL = [NSString stringWithFormat:@" and ( %@ > IFNULL((select %@ from %@ where %@), 0) or ( %@ = IFNULL((select %@ from %@ where %@), 0) and %@ >= IFNULL((select %@ from %@ where %@), 0) ) ) %@",
                     COLUMN_KEY_DATE, COLUMN_KEY_DATE, TABLE_NAME, (NSString *)fpScopeAfter,
                     COLUMN_KEY_DATE, COLUMN_KEY_DATE, TABLE_NAME, (NSString *)fpScopeAfter,
                     COLUMN_KEY_ID, COLUMN_KEY_ID, TABLE_NAME, (NSString *)fpScopeAfter,
                     extraSQL];
    }

    
    // 条件：uid 匹配 +（_update_time 为空则保留该行，避免旧数据/异常插入导致「仅按时间筛」把未写 update_time 的新消息排除，重进会话读库看不到最新）
    //条件是 where _uid ='1002' and "_update_time>datetime('2014-04-19','-7 day')，默认只取（当前）起7天内的消息（注意这里的结果是逆序的哦）
    // 排序：优先按消息时间 date（业务上的「远近」），再以 _id 区分同毫秒/同秒插入顺序；禁止仅用 _id，否则同步/补录会导致「屏上最新一条」不是库里 date 最大的行
    NSString *condition = [NSString stringWithFormat:@"%@='%@' and (%@ IS NULL OR %@>datetime('%@','-%d day')) %@ order by %@ desc, %@ desc %@"
                           , COLUMN_KEY_UID
                           , uid
                           , COLUMN_KEY_UPDATE_TIME
                           , COLUMN_KEY_UPDATE_TIME
                           , [TimeTool getCurrentDatePartStr]
                           , SQLITE_CHAT_MESSAGE_SOTRE_RANGE
                           , extraSQL
                           , COLUMN_KEY_DATE
                           , COLUMN_KEY_ID
                           // 是否只读取一页数据（否则不显示结果行数——即读取全部结果）
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
            // 即消息类型，同android版的msgType
            cp.msgType = [BasicTool getIntValue:[rs stringForColumnIndex:5] defaultVal:-1];
            int savedSendStatus = [rs intForColumnIndex:6];
            cp.sendStatus = (savedSendStatus == SendStatus_SEND_FAILD || savedSendStatus == SendStatus_SNEDING) ? savedSendStatus : SendStatus_BE_RECEIVED;
            cp.sendStatusSecondary = SendStatusSecondary_NONE;

            cp.quote_fp = [rs stringForColumnIndex:7];
            cp.quote_sender_uid = [rs stringForColumnIndex:8];
            cp.quote_sender_nick = [rs stringForColumnIndex:9];
            cp.quote_status = [BasicTool getIntValue:[rs stringForColumnIndex:10] defaultVal:0];
            cp.quote_content = [rs stringForColumnIndex:11];
            cp.quote_type = [BasicTool getIntValue:[rs stringForColumnIndex:12] defaultVal:0];
            if ([cp isOutgoing]) {
                cp.readByPartner = ([rs intForColumnIndex:13] != 0);
            }
            cp.rb_conversationMsgSeq = [rs longLongIntForColumnIndex:14];

            // 通话记录消息：从 text 解析 VoipRecordMeta 并缓存，便于 UI 正确显示语音/视频（含服务端返回 "type":"video" 的兼容）
            if (cp.msgType == TM_TYPE_VOIP_RECORD && cp.text.length > 0 && [cp.text hasPrefix:@"{"]) {
                cp.voipRecordMeta = [VoipRecordMeta fromJSON:cp.text];
            }
//          cp.getDownloadStatus().setStatus(DownloadStatus.NONE);

//            // 这是“我”发出的消息
//            if([cp isOutgoing])
//                // 正确地设置聊天界面中列表行数据封装对确的“发送者”uid
//                cp.senderId = [IMClientManager sharedInstance].localUserInfo.user_uid;
//            else
//                cp.senderId = uid;

            [cpList addObject:cp];
        }
    }
    // fs返回为nil即表示查询出错了
    else
    {
        [MyDataBase printErrorForDebug:db tag:@"ChatHistoryTable.findHistory"];
    }

    return cpList;
}

- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   uid:(NSString *)uid
                   cme:(JSQMessage *)cme
{
    return [self insertHistory:db acountUidOfOwner:acountUidOfOwner uid:uid cme:cme didInsert:NULL];
}

- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   uid:(NSString *)uid
                   cme:(JSQMessage *)cme
             didInsert:(BOOL *)outDidInsert
{
    if(cme != nil && (cme.text == nil || [cme.text isKindOfClass:NSString.class]))
    {
        NSString *luid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        int readCol = ([luid length] > 0 && [cme.senderId isEqualToString:luid] && cme.readByPartner) ? 1 : 0;
        return [self insertHistory:db
                  acountUidOfOwner:acountUidOfOwner
                               uid:uid
                          senderId:cme.senderId
                              senderDisplayName:cme.senderDisplayName
                              date:[TimeTool javaMillisFromNSDate:cme.date]
                              text:cme.text
                           msgType:[NSString stringWithFormat:@"%d",cme.msgType]
             fingerPrintOfProtocal:cme.fingerPrintOfProtocal
                        sendStatus:cme.sendStatus
                   readByPartner:(readCol != 0)
                conversationMsgSeq:cme.rb_conversationMsgSeq
                             quote:cme
                         didInsert:outDidInsert];
    }
    else
    {
        DDLogDebug(@"[sqlite-ChatHistoryTable] 未知的text类型：%@", cme.text);
        return NO;
    }
}

// 插入一行数据到表中.
- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   uid:(NSString *)uid
              senderId:(NSString *)senderId
     senderDisplayName:(NSString *)senderDisplayName
                  date:(long long)dateMillis
                  text:(NSString *)text
               msgType:(NSString *)msgType
 fingerPrintOfProtocal:(NSString *)fingerPrintOfProtocal
            sendStatus:(int)sendStatus
                 quote:(QuoteMeta *)quoteMeta
{
    return [self insertHistory:db acountUidOfOwner:acountUidOfOwner uid:uid senderId:senderId senderDisplayName:senderDisplayName date:dateMillis text:text msgType:msgType fingerPrintOfProtocal:fingerPrintOfProtocal sendStatus:sendStatus readByPartner:NO conversationMsgSeq:0 quote:quoteMeta didInsert:NULL];
}

- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   uid:(NSString *)uid
              senderId:(NSString *)senderId
     senderDisplayName:(NSString *)senderDisplayName
                  date:(long long)dateMillis
                  text:(NSString *)text
               msgType:(NSString *)msgType
 fingerPrintOfProtocal:(NSString *)fingerPrintOfProtocal
            sendStatus:(int)sendStatus
         readByPartner:(BOOL)readByPartner
    conversationMsgSeq:(long long)conversationMsgSeq
                 quote:(QuoteMeta *)quoteMeta
             didInsert:(BOOL *)outDidInsert
{
    if (outDidInsert != NULL) {
        *outDidInsert = NO;
    }
    // 与群聊表一致：同会话下同指纹只保留一行，避免预拉/漫游重复 INSERT
    NSString *normalizedFp = RBNormalizedFingerprintForSqlLookup(fingerPrintOfProtocal);
    if (normalizedFp.length > 0) {
        NSString *checkSql = [NSString stringWithFormat:@"SELECT 1 FROM %@ WHERE %@=? AND %@=? AND lower(trim(%@))=? LIMIT 1",
                             TABLE_NAME, COLUMN_KEY_ACOUNT_UID, COLUMN_KEY_UID, COLUMN_FINGER_PRINT_OF_PROTOCAL];
        FMResultSet *rs = [db executeQuery:checkSql withArgumentsInArray:@[acountUidOfOwner, uid, normalizedFp]];
        if (rs != nil && [rs next]) {
            [rs close];
            DDLogVerbose(@"[sqlite-ChatHistoryTable.insertHistory] 已存在相同指纹消息，跳过插入 fp=%@", fingerPrintOfProtocal);
            return YES;
        }
        if (rs) [rs close];
    }

    NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
                            , TABLE_NAME

                            , COLUMN_KEY_ACOUNT_UID
                            , COLUMN_KEY_UID
                            , COLUMN_KEY_SENDER_ID
                            , COLUMN_KEY_SENDER_DISPLAY_NAME
                            , COLUMN_KEY_DATE
                            , COLUMN_KEY_TEXT
                            , COLUMN_KEY_MSG_TYPE
                            , COLUMN_FINGER_PRINT_OF_PROTOCAL
                            , COLUMN_SEND_STATUS
                            , COLUMN_READ_BY_PARTNER
                            , COLUMN_CONVERSATION_MSG_SEQ
                            , COLUMN_KEY_QUOTE_FP
                            , COLUMN_KEY_QUOTE_SENDER_UID
                            , COLUMN_KEY_QUOTE_SENDER_NICK
                            , COLUMN_KEY_QUOTE_STATUS
                            , COLUMN_KEY_QUOTE_CONTENT
                            , COLUMN_KEY_QUOTE_TYPE];

#if DEBUG
    DDLogVerbose(@"[sqlite-ChatHistoryTable.insertHistory] 组织完成的SQL语句：%@", sql);
#endif

    int readCol = readByPartner ? 1 : 0;
    BOOL ok = [db executeUpdate:sql withArgumentsInArray:@[acountUidOfOwner
                                                        , uid
                                                        , senderId
                                                        , senderDisplayName
                                                        , [NSNumber numberWithLongLong:dateMillis]
                                                        , [MyDataBase nullSafe:text]
                                                        , msgType
                                                        , [MyDataBase nullSafe:fingerPrintOfProtocal]
                                                        , [NSNumber numberWithInt:sendStatus]
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
                                  uid:(NSString *)uid
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
    if (db == nil || acountUidOfOwner.length == 0 || uid.length == 0 || cme == nil) {
        return NO;
    }
    if (!(cme.text == nil || [cme.text isKindOfClass:[NSString class]])) {
        return NO;
    }

    NSString *fp = cme.fingerPrintOfProtocal;
    NSString *normalizedFp = RBNormalizedFingerprintForSqlLookup(fp);
    if (normalizedFp.length == 0) {
        return [self insertHistory:db acountUidOfOwner:acountUidOfOwner uid:uid cme:cme didInsert:outDidInsert];
    }

    long long newMillis = [TimeTool javaMillisFromNSDate:cme.date];
    NSString *sel = [NSString stringWithFormat:@"SELECT %@, %@, %@, %@ FROM %@ WHERE %@=? AND %@=? AND lower(trim(%@))=? LIMIT 1",
                     COLUMN_KEY_DATE, COLUMN_KEY_MSG_TYPE, COLUMN_READ_BY_PARTNER, COLUMN_CONVERSATION_MSG_SEQ, TABLE_NAME,
                     COLUMN_KEY_ACOUNT_UID, COLUMN_KEY_UID, COLUMN_FINGER_PRINT_OF_PROTOCAL];
    FMResultSet *rs = [db executeQuery:sel withArgumentsInArray:@[acountUidOfOwner, uid, normalizedFp]];
    BOOL exists = (rs != nil && [rs next]);
    long long oldMillis = exists ? [rs longLongIntForColumnIndex:0] : 0;
    int oldType = exists ? [BasicTool getIntValue:[rs stringForColumnIndex:1] defaultVal:-1] : -1;
    int oldReadByPartner = exists ? [rs intForColumnIndex:2] : 0;
    long long oldConvSeq = exists ? [rs longLongIntForColumnIndex:3] : 0;
    if (rs) {
        [rs close];
    }

    if (!exists) {
        return [self insertHistory:db acountUidOfOwner:acountUidOfOwner uid:uid cme:cme didInsert:outDidInsert];
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
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    BOOL outgoing = (localUid.length > 0 && [cme.senderId isEqualToString:localUid]);
    int mergedRead = outgoing ? ((oldReadByPartner != 0 || cme.readByPartner) ? 1 : 0) : 0;
    long long newSeq = cme.rb_conversationMsgSeq;
    long long mergedSeq = (newSeq > 0) ? ((oldConvSeq > 0) ? MAX(oldConvSeq, newSeq) : newSeq) : oldConvSeq;

    NSString *upd = [NSString stringWithFormat:
                      @"UPDATE %@ SET %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=? WHERE %@=? AND %@=? AND %@=?",
                      TABLE_NAME,
                      COLUMN_KEY_SENDER_ID, COLUMN_KEY_SENDER_DISPLAY_NAME, COLUMN_KEY_DATE, COLUMN_KEY_TEXT, COLUMN_KEY_MSG_TYPE,
                      COLUMN_SEND_STATUS,
                      COLUMN_READ_BY_PARTNER,
                      COLUMN_CONVERSATION_MSG_SEQ,
                      COLUMN_KEY_QUOTE_FP, COLUMN_KEY_QUOTE_SENDER_UID, COLUMN_KEY_QUOTE_SENDER_NICK,
                      COLUMN_KEY_QUOTE_STATUS, COLUMN_KEY_QUOTE_CONTENT, COLUMN_KEY_QUOTE_TYPE,
                      COLUMN_KEY_ACOUNT_UID, COLUMN_KEY_UID, COLUMN_FINGER_PRINT_OF_PROTOCAL];
    BOOL ok = [db executeUpdate:upd withArgumentsInArray:@[
        cme.senderId ?: @"",
        cme.senderDisplayName ?: @"",
        @(newMillis),
        [MyDataBase nullSafe:cme.text],
        [NSString stringWithFormat:@"%d", cme.msgType],
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
        uid,
        fp
    ]];
    if (ok && outDidUpdate != NULL) {
        *outDidUpdate = YES;
    }
    return ok;
}

// 删除超出保存期限的老聊天消息.
- (BOOL) deleteOldHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner uid:(NSString *)uid
{
    // 删除7天前的所有聊天消息
    NSString *where = [NSString stringWithFormat:@"%@='%@' and %@='%@' and %@<=datetime('%@','-%d day')"
                           , COLUMN_KEY_ACOUNT_UID, acountUidOfOwner
                           , COLUMN_KEY_UID, uid
                           , COLUMN_KEY_UPDATE_TIME, [TimeTool getCurrentDatePartStr], SQLITE_CHAT_MESSAGE_SOTRE_RANGE
                       ];

    return [super delete:db tableName:TABLE_NAME filterSQL:where debugTag:@"ChatHistoryTable.deleteOldHistory"];
}

// 删除与某人的本地存储的所有聊天消息.
- (BOOL) deleteHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner srcUid:(NSString *)srcUid
{
    // 指定消息发送者的本地记录
    NSString *where = [NSString stringWithFormat:@"%@='%@' and %@='%@'"
                           , COLUMN_KEY_ACOUNT_UID, acountUidOfOwner
                           , COLUMN_KEY_UID, srcUid
                       ];

    return [super delete:db tableName:TABLE_NAME filterSQL:where debugTag:@"ChatHistoryTable.deleteHistory"];
}

// 删除指定指纹码对应的聊天消息.
- (BOOL) deleteHistoryWithFp:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fpForMessage
{
    // 指定消息发送者的本地记录
    NSString *where = [NSString stringWithFormat:@"%@='%@' and %@='%@'"
                           , COLUMN_KEY_ACOUNT_UID, acountUidOfOwner
                           , COLUMN_FINGER_PRINT_OF_PROTOCAL, fpForMessage
                       ];

    return [super delete:db tableName:TABLE_NAME filterSQL:where debugTag:@"ChatHistoryTable.deleteHistoryWithFp"];
}

// 消息撤回成功后，更新本地消息的数据
- (BOOL) updateForRevoke:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fpForMessage meta:(RevokedMeta *)textObj
{
    /* ------------------- 先更新被撤回消息本身 ---------------------- */
    // 指纹码列条件语句
    NSString *fpField = [NSString stringWithFormat:@"%@='%@'", COLUMN_FINGER_PRINT_OF_PROTOCAL, fpForMessage];
    // 附加更新条件
    NSString *where = [NSString stringWithFormat:@"%@='%@' and %@", COLUMN_KEY_ACOUNT_UID, acountUidOfOwner, fpField];
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"UPDATE %@ SET %@=?, %@=? WHERE %@"
                            , TABLE_NAME
                            , COLUMN_KEY_MSG_TYPE
                            , COLUMN_KEY_TEXT
                            , where];
    
    DDLogDebug(@"********************************** updateForRevoke-单聊 START");
    DDLogDebug(@"[sqlite-ChatHistoryTable.updateForRevoke]【消息撤回 1/2开始】组织完成的SQL语句：%@", sql);
    BOOL updateSucess = [db executeUpdate:sql withArgumentsInArray:@[[NSString stringWithFormat:@"%d",TM_TYPE_REVOKE], [MyDataBase nullSafe:[EVAToolKits toJSON:textObj]]]];
    DDLogDebug(@"[sqlite-ChatHistoryTable.updateForRevoke]【消息撤回 1/2完成】updateSucess1=%d", updateSucess);
    
    
    /* ------------------- 再更新"引用"了被撤回消息的那些消息 ------------ */
    // 指纹码列条件语句
    NSString *fpField2 = [NSString stringWithFormat:@"%@='%@'", COLUMN_KEY_QUOTE_FP, fpForMessage];
    // 附加更新条件
    NSString *where2 = [NSString stringWithFormat:@"%@='%@' and %@", COLUMN_KEY_ACOUNT_UID, acountUidOfOwner, fpField2];
    
    NSMutableString *sql2 = [NSMutableString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@"
                            , TABLE_NAME
                            , COLUMN_KEY_QUOTE_STATUS
                            , where2];
    
    DDLogDebug(@"[sqlite-ChatHistoryTable.updateForRevoke]【消息撤回 2/2开始】组织完成的SQL语句：%@", sql2);
    // 设置引用状态为1（表示原消息已被撤回）
    BOOL updateSucess2 = [db executeUpdate:sql2 withArgumentsInArray:@[@"1"]];
    DDLogDebug(@"[sqlite-ChatHistoryTable.updateForRevoke]【消息撤回 2/2完成】updateSucess2=%d", updateSucess2);
    DDLogDebug(@"********************************** updateForRevoke-单聊 END");
    
    return updateSucess;
}

- (BOOL)markOutgoingReadByPartnerUpToWatermark:(FMDatabase *)db
                           acountUidOfOwner:(NSString *)acountUidOfOwner
                                        uid:(NSString *)uid
                             localSenderIds:(NSArray<NSString *> *)localSenderIds
                           partnerReadTimeMs:(long long)partnerReadTimeMs
{
    if (!db || acountUidOfOwner.length == 0 || uid.length == 0 || partnerReadTimeMs <= 0) {
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
    /* date 列：新版为 Java 毫秒（≥1e11），旧版曾为秒（＜1e11），与 TimeTool dateFromChatHistoryStoredTime 一致；仅用 date<=毫秒水位会漏掉旧秒级行与边界语义不一致 */
    NSString *sql = [NSString stringWithFormat:
                     @"UPDATE %@ SET %@=1 WHERE %@=? AND %@=? AND %@ IN (%@) AND IFNULL(%@,0)=0 AND ((%@ >= 100000000000 AND %@ <= ?) OR (%@ > 0 AND %@ < 100000000000 AND (%@ * 1000) <= ?))",
                     TABLE_NAME,
                     COLUMN_READ_BY_PARTNER,
                     COLUMN_KEY_ACOUNT_UID,
                     COLUMN_KEY_UID,
                     COLUMN_KEY_SENDER_ID,
                     inList,
                     COLUMN_READ_BY_PARTNER,
                     COLUMN_KEY_DATE,
                     COLUMN_KEY_DATE,
                     COLUMN_KEY_DATE,
                     COLUMN_KEY_DATE,
                     COLUMN_KEY_DATE];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:acountUidOfOwner, uid, nil];
    [args addObjectsFromArray:[uniq array]];
    [args addObject:@(partnerReadTimeMs)];
    [args addObject:@(partnerReadTimeMs)];
    return [db executeUpdate:sql withArgumentsInArray:args];
}

- (BOOL) updateSendStatus:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fp sendStatus:(int)sendStatus
{
    if (!db || !acountUidOfOwner.length || !fp.length) return NO;
    NSString *where = [NSString stringWithFormat:@"%@='%@' and %@='%@'",
                      COLUMN_KEY_ACOUNT_UID, acountUidOfOwner,
                      COLUMN_FINGER_PRINT_OF_PROTOCAL, fp];
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@",
                     TABLE_NAME, COLUMN_SEND_STATUS, where];
    return [db executeUpdate:sql withArgumentsInArray:@[@(sendStatus)]];
}

- (BOOL)markStaleOutgoingSendingMessagesAsFailed:(FMDatabase *)db
                                acountUidOfOwner:(NSString *)acountUidOfOwner
                                             uid:(NSString *)uid
                                  localSenderIds:(NSArray<NSString *> *)localSenderIds
{
    if (!db || !acountUidOfOwner.length || !uid.length || localSenderIds.count == 0) return NO;

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
                     TABLE_NAME,
                     COLUMN_SEND_STATUS,
                     COLUMN_KEY_ACOUNT_UID,
                     COLUMN_KEY_UID,
                     COLUMN_SEND_STATUS,
                     COLUMN_KEY_SENDER_ID,
                     [placeholders componentsJoinedByString:@","]];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:
                            @(SendStatus_SEND_FAILD),
                            acountUidOfOwner,
                            uid,
                            @(SendStatus_SNEDING), nil];
    [args addObjectsFromArray:uniqSenderIds];
    return [db executeUpdate:sql withArgumentsInArray:args];
}

#pragma mark - 多端增量同步相关方法

- (long)getLatestMessageTimestamp:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner uid:(NSString *)uid
{
    if (db == nil || acountUidOfOwner == nil || uid == nil) return 0;

    NSString *sql = [NSString stringWithFormat:
                     @"SELECT MAX(%@) FROM %@ WHERE %@=? AND %@=?",
                     COLUMN_KEY_DATE, TABLE_NAME, COLUMN_KEY_ACOUNT_UID, COLUMN_KEY_UID];

    FMResultSet *rs = [db executeQuery:sql withArgumentsInArray:@[acountUidOfOwner, uid]];
    long result = 0;
    if (rs && [rs next]) {
        result = [rs longForColumnIndex:0];
    }
    [rs close];
    return result;
}

- (long long)maxConversationMsgSeq:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner uid:(NSString *)uid
{
    if (!db || acountUidOfOwner.length == 0 || uid.length == 0) {
        return 0;
    }
    NSString *sql = [NSString stringWithFormat:@"SELECT MAX(%@) FROM %@ WHERE %@=? AND %@=?",
                     COLUMN_CONVERSATION_MSG_SEQ, TABLE_NAME, COLUMN_KEY_ACOUNT_UID, COLUMN_KEY_UID];
    FMResultSet *rs = [db executeQuery:sql withArgumentsInArray:@[acountUidOfOwner, uid]];
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
                     TABLE_NAME, COLUMN_KEY_ACOUNT_UID, COLUMN_FINGER_PRINT_OF_PROTOCAL];

    FMResultSet *rs = [db executeQuery:sql withArgumentsInArray:@[acountUidOfOwner, fp]];
    BOOL exists = NO;
    if (rs && [rs next]) {
        exists = [rs intForColumnIndex:0] > 0;
    }
    [rs close];
    return exists;
}

#pragma mark - 专用聊天记录搜索功能增加的方法

// 搜索带有指定关键字的单聊、群聊消息（本方法的查询会将结果按聊天对象进行聚合，比如结果可
// 能是：某某人有多少条消息包含此结果、某群有多少条消息包含此结果，不过当结果只有一条时会显示该唯一消息内容）.
- (NSMutableArray<MsgSummaryContentDTO *> *) searchMessagesSummery:(FMDatabase *)db keyword:(NSString *)keyword limit:(int)limit
{
    NSMutableArray<MsgSummaryContentDTO *> *cpList= [NSMutableArray array];
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if(![BasicTool isStringEmpty:[BasicTool trim:keyword]] && localUid != nil) {
        
        NSArray<NSString *> *filedNames = @[@"chatType"
                                            , @"cnt"
                                            , @"dataId"
                                            , @"date"
                                            , @"text"
                                            , @"fp"];
        
//      NSString *subCondition = [NSString stringWithFormat:@"        WHERE _acount_uid='%@' AND msgType=0 AND text like '%%%@%%' ", localUid, keyword];
        
        // 组织SQL中的tablename（这是一个复杂的子查询）
        NSString *tableName = @"("
                            "        SELECT 0 as chatType, count(_uid) AS cnt, _uid as dataId, date, text, finger_print_of_protocal as fp"
                            "        FROM chat_msg "
                            "        WHERE _acount_uid='{{1}}' AND msgType=0 AND text like '%{{2}}%' "
                            "        GROUP BY _uid "// LIMIT "+limit  (注：sqlite中不支持union all中的子查询用limit，可能得再写一层子查询，这样就搞复杂了，为了简洁易懂，此限制可以后再视情况再考虑)

                            "        UNION all "

                            "        SELECT 1 as chatType, count(_gid) AS cnt, _gid as dataId, date, text, finger_print_of_protocal as fp"
                            "        FROM groupchat_msg "
                            "        WHERE _acount_uid='{{1}}' AND msgType=0 AND text like '%{{2}}%' "
                            "        GROUP BY _gid "// LIMIT "+limit
                            ")";
        // 替换占位符
        tableName = [tableName stringByReplacingOccurrencesOfString:@"{{1}}" withString:localUid];
        tableName = [tableName stringByReplacingOccurrencesOfString:@"{{2}}" withString:keyword];
        
        //获取结果集，返回参数就是查询结果
        FMResultSet *rs= [super query:db tableName:tableName fieldNames:filedNames filterSQL:@"1=1 ORDER BY date DESC" debugTag:@"ChatHistoryTable.searchMessagesSummery"];
        
        if(rs != nil) {
            while (rs.next)  {
                MsgSummaryContentDTO *cp = [[MsgSummaryContentDTO alloc] init];

                cp.chatType = [BasicTool getIntValue:[rs stringForColumnIndex:0] defaultVal:0];
                cp.resultCount = [BasicTool getIntValue:[rs stringForColumnIndex:1] defaultVal:0];
                cp.dataId = [rs stringForColumnIndex:2];
                cp.date = [TimeTool dateFromChatHistoryStoredTime:[rs longLongIntForColumnIndex:3]];
                cp.text = [rs stringForColumnIndex:4];
                cp.fp = [rs stringForColumnIndex:5];

                [cpList addObject:cp];
            }
        }
        // fs返回为nil即表示查询出错了
        else {
            [MyDataBase printErrorForDebug:db tag:@"ChatHistoryTable.searchMessagesSummery"];
        }
    } else {
        DLogWarn(@"searchAllMessagesSummery()时，无效的参数：keyword=%@, localUid=%@", keyword, localUid);
    }
    
    return cpList;
}

// 搜索指定聊天对象（单聊或群聊）内带有指定关键字的所有消息（本方法的查询结果不会聚合，有多少条就显示多少条）
- (NSMutableArray<MsgDetailContentDTO *> *) searchMessagesDetail:(FMDatabase *)db chatType:(int)searchResultChatType uidOrGid:(NSString *) uidOrGid keyword:(NSString *)keyword {

    NSMutableArray<MsgDetailContentDTO *> *cpList= [NSMutableArray array];

    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if(![BasicTool isStringEmpty:[BasicTool trim:keyword]] && localUid != nil) {
            
        NSArray<NSString *> *filedNames = nil;
        NSString *tableName = nil;
        NSString *where = nil;
        NSString *orderBy = @"1=1 ORDER BY date DESC";
        
        if(searchResultChatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE) {
            filedNames = @[@"_uid", @"senderId", @"senderDisplayName", @"date", @"text" , @"finger_print_of_protocal"];
            tableName = @"chat_msg";
            where = [NSString stringWithFormat:@"_acount_uid='%@' and _uid='%@' AND msgType=0 AND text like '%%%@%%'", localUid, uidOrGid, keyword];
        }
        else if(searchResultChatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP) {
            filedNames = @[@"_gid", @"senderId", @"senderDisplayName", @"date", @"text", @"finger_print_of_protocal" ];
            tableName = @"groupchat_msg";
            where = [NSString stringWithFormat:@"_acount_uid='%@' and _gid='%@' AND msgType=0 AND text like '%%%@%%'", localUid, uidOrGid, keyword];
        }
        else{
            DLogWarn(@"searchSomeoneMessages()时，无效的searchResultChatType=%d", searchResultChatType);
            return cpList;
        }
        
        //获取结果集，返回参数就是查询结果
        FMResultSet *rs= [super query:db tableName:tableName fieldNames:filedNames filterSQL:[NSString stringWithFormat:@"%@ ORDER BY date DESC", where] debugTag:@"ChatHistoryTable.searchMessagesDetail"];
        
        if(rs != nil) {
            while (rs.next)  {
                MsgDetailContentDTO *cp = [[MsgDetailContentDTO alloc] init];

                cp.chatType = searchResultChatType;
                cp.resultCount = 1;
                cp.dataId = [rs stringForColumnIndex:0];
                cp.senderId = [rs stringForColumnIndex:1];
                cp.senderDisplayName = [rs stringForColumnIndex:2];
                cp.date = [TimeTool dateFromChatHistoryStoredTime:[rs longLongIntForColumnIndex:3]];
                cp.text = [rs stringForColumnIndex:4];
                cp.fp = [rs stringForColumnIndex:5];

                [cpList addObject:cp];
            }
        }
        // fs返回为nil即表示查询出错了
        else {
            [MyDataBase printErrorForDebug:db tag:@"ChatHistoryTable.searchMessagesDetail"];
        }
        
    } else {
            DLogWarn(@"searchSomeoneMessages()时，无效的参数：keyword=%@, uidOrGid=%@, localUid=%@", keyword, uidOrGid, localUid);
    }

    return cpList;
}

// 按消息类型搜索（用于图片/视频/文件浏览），支持分页
- (NSMutableArray<MsgDetailContentDTO *> *)searchMessagesByTypes:(FMDatabase *)db
                                                        chatType:(int)searchResultChatType
                                                        uidOrGid:(NSString *)uidOrGid
                                                        msgTypes:(NSArray<NSNumber *> *)msgTypes
                                                           limit:(int)limit
                                                          offset:(int)offset
{
    NSMutableArray<MsgDetailContentDTO *> *cpList = [NSMutableArray array];
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (localUid == nil || uidOrGid == nil || msgTypes == nil || [msgTypes count] == 0) {
        DLogWarn(@"searchMessagesByTypes: 无效的参数！");
        return cpList;
    }
    
    // 构建 msgType IN (...) 条件
    NSMutableArray *typeStrs = [NSMutableArray array];
    for (NSNumber *t in msgTypes) {
        [typeStrs addObject:[t stringValue]];
    }
    NSString *typesIn = [typeStrs componentsJoinedByString:@","];
    
    NSArray<NSString *> *filedNames = nil;
    NSString *tableName = nil;
    NSString *where = nil;
    
    if (searchResultChatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE) {
        filedNames = @[@"_uid", @"senderId", @"senderDisplayName", @"date", @"text", @"finger_print_of_protocal", @"msgType", @"quote_sender_uid", @"quote_sender_nick"];
        tableName = @"chat_msg";
        where = [NSString stringWithFormat:@"_acount_uid='%@' AND _uid='%@' AND msgType IN (%@)", localUid, uidOrGid, typesIn];
    }
    else if (searchResultChatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP) {
        filedNames = @[@"_gid", @"senderId", @"senderDisplayName", @"date", @"text", @"finger_print_of_protocal", @"msgType", @"quote_sender_uid", @"quote_sender_nick"];
        tableName = @"groupchat_msg";
        where = [NSString stringWithFormat:@"_acount_uid='%@' AND _gid='%@' AND msgType IN (%@)", localUid, uidOrGid, typesIn];
    }
    else {
        DLogWarn(@"searchMessagesByTypes: 无效的searchResultChatType=%d", searchResultChatType);
        return cpList;
    }
    
    FMResultSet *rs = [super query:db tableName:tableName fieldNames:filedNames filterSQL:[NSString stringWithFormat:@"%@ ORDER BY date DESC LIMIT %d OFFSET %d", where, limit, offset] debugTag:@"ChatHistoryTable.searchMessagesByTypes"];
    
    if (rs != nil) {
        while (rs.next) {
            MsgDetailContentDTO *cp = [[MsgDetailContentDTO alloc] init];
            cp.chatType = searchResultChatType;
            cp.resultCount = 1;
            cp.dataId = [rs stringForColumnIndex:0];
            cp.senderId = [rs stringForColumnIndex:1];
            cp.senderDisplayName = [rs stringForColumnIndex:2];
            cp.date = [TimeTool dateFromChatHistoryStoredTime:[rs longLongIntForColumnIndex:3]];
            cp.text = [rs stringForColumnIndex:4];
            cp.fp = [rs stringForColumnIndex:5];
            cp.msgType = [BasicTool getIntValue:[rs stringForColumnIndex:6] defaultVal:0];
            cp.quoteSenderUid = [rs stringForColumnIndex:7];
            cp.quoteSenderNick = [rs stringForColumnIndex:8];
            [cpList addObject:cp];
        }
    } else {
        [MyDataBase printErrorForDebug:db tag:@"ChatHistoryTable.searchMessagesByTypes"];
    }
    
    return cpList;
}

// 按消息类型搜索，可选排除「文本内容含 URL」的消息（用于收藏夹「对话」Tab）
- (NSMutableArray<MsgDetailContentDTO *> *)searchMessagesByTypes:(FMDatabase *)db
                                                        chatType:(int)searchResultChatType
                                                        uidOrGid:(NSString *)uidOrGid
                                                        msgTypes:(NSArray<NSNumber *> *)msgTypes
                                        excludeTextContainingURL:(BOOL)excludeTextContainingURL
                                                           limit:(int)limit
                                                          offset:(int)offset
{
    NSMutableArray<MsgDetailContentDTO *> *cpList = [NSMutableArray array];
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (localUid == nil || uidOrGid == nil || msgTypes == nil || [msgTypes count] == 0) {
        DLogWarn(@"searchMessagesByTypes:excludeTextContainingURL: 无效的参数！");
        return cpList;
    }
    NSMutableArray *typeStrs = [NSMutableArray array];
    for (NSNumber *t in msgTypes) {
        [typeStrs addObject:[t stringValue]];
    }
    NSString *typesIn = [typeStrs componentsJoinedByString:@","];
    NSArray<NSString *> *filedNames = nil;
    NSString *tableName = nil;
    NSString *where = nil;
    if (searchResultChatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE) {
        filedNames = @[@"_uid", @"senderId", @"senderDisplayName", @"date", @"text", @"finger_print_of_protocal", @"msgType", @"quote_sender_uid", @"quote_sender_nick"];
        tableName = @"chat_msg";
        where = [NSString stringWithFormat:@"_acount_uid='%@' AND _uid='%@' AND msgType IN (%@)", localUid, uidOrGid, typesIn];
    } else if (searchResultChatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP) {
        filedNames = @[@"_gid", @"senderId", @"senderDisplayName", @"date", @"text", @"finger_print_of_protocal", @"msgType", @"quote_sender_uid", @"quote_sender_nick"];
        tableName = @"groupchat_msg";
        where = [NSString stringWithFormat:@"_acount_uid='%@' AND _gid='%@' AND msgType IN (%@)", localUid, uidOrGid, typesIn];
    } else {
        DLogWarn(@"searchMessagesByTypes:excludeTextContainingURL: 无效的 searchResultChatType=%d", searchResultChatType);
        return cpList;
    }
    if (excludeTextContainingURL) {
        where = [where stringByAppendingString:@" AND (msgType != 0 OR (text NOT LIKE '%%http://%%' AND text NOT LIKE '%%https://%%'))"];
    }
    FMResultSet *rs = [super query:db tableName:tableName fieldNames:filedNames filterSQL:[NSString stringWithFormat:@"%@ ORDER BY date DESC LIMIT %d OFFSET %d", where, limit, offset] debugTag:@"ChatHistoryTable.searchMessagesByTypes_excludeLink"];
    if (rs != nil) {
        while (rs.next) {
            MsgDetailContentDTO *cp = [[MsgDetailContentDTO alloc] init];
            cp.chatType = searchResultChatType;
            cp.resultCount = 1;
            cp.dataId = [rs stringForColumnIndex:0];
            cp.senderId = [rs stringForColumnIndex:1];
            cp.senderDisplayName = [rs stringForColumnIndex:2];
            cp.date = [TimeTool dateFromChatHistoryStoredTime:[rs longLongIntForColumnIndex:3]];
            cp.text = [rs stringForColumnIndex:4];
            cp.fp = [rs stringForColumnIndex:5];
            cp.msgType = [BasicTool getIntValue:[rs stringForColumnIndex:6] defaultVal:0];
            cp.quoteSenderUid = [rs stringForColumnIndex:7];
            cp.quoteSenderNick = [rs stringForColumnIndex:8];
            [cpList addObject:cp];
        }
    } else {
        [MyDataBase printErrorForDebug:db tag:@"ChatHistoryTable.searchMessagesByTypes_excludeLink"];
    }
    return cpList;
}

// 按「文本内容包含 URL」搜索消息（用于收藏夹链接 Tab）
- (NSMutableArray<MsgDetailContentDTO *> *)searchTextMessagesContainingURL:(FMDatabase *)db
                                                                  chatType:(int)searchResultChatType
                                                                  uidOrGid:(NSString *)uidOrGid
                                                                     limit:(int)limit
                                                                    offset:(int)offset
{
    NSMutableArray<MsgDetailContentDTO *> *cpList = [NSMutableArray array];
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (localUid == nil || uidOrGid == nil) {
        DLogWarn(@"searchTextMessagesContainingURL: 无效的参数");
        return cpList;
    }
    NSArray<NSString *> *filedNames = nil;
    NSString *tableName = nil;
    NSString *where = nil;
    if (searchResultChatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE) {
        filedNames = @[@"_uid", @"senderId", @"senderDisplayName", @"date", @"text", @"finger_print_of_protocal", @"msgType", @"quote_sender_uid", @"quote_sender_nick"];
        tableName = @"chat_msg";
        where = [NSString stringWithFormat:@"_acount_uid='%@' AND _uid='%@' AND msgType=0 AND (text LIKE '%%http://%%' OR text LIKE '%%https://%%')", localUid, uidOrGid];
    } else if (searchResultChatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP) {
        filedNames = @[@"_gid", @"senderId", @"senderDisplayName", @"date", @"text", @"finger_print_of_protocal", @"msgType", @"quote_sender_uid", @"quote_sender_nick"];
        tableName = @"groupchat_msg";
        where = [NSString stringWithFormat:@"_acount_uid='%@' AND _gid='%@' AND msgType=0 AND (text LIKE '%%http://%%' OR text LIKE '%%https://%%')", localUid, uidOrGid];
    } else {
        DLogWarn(@"searchTextMessagesContainingURL: 无效的 searchResultChatType=%d", searchResultChatType);
        return cpList;
    }
    FMResultSet *rs = [super query:db tableName:tableName fieldNames:filedNames filterSQL:[NSString stringWithFormat:@"%@ ORDER BY date DESC LIMIT %d OFFSET %d", where, limit, offset] debugTag:@"ChatHistoryTable.searchTextMessagesContainingURL"];
    if (rs != nil) {
        while (rs.next) {
            MsgDetailContentDTO *cp = [[MsgDetailContentDTO alloc] init];
            cp.chatType = searchResultChatType;
            cp.resultCount = 1;
            cp.dataId = [rs stringForColumnIndex:0];
            cp.senderId = [rs stringForColumnIndex:1];
            cp.senderDisplayName = [rs stringForColumnIndex:2];
            cp.date = [TimeTool dateFromChatHistoryStoredTime:[rs longLongIntForColumnIndex:3]];
            cp.text = [rs stringForColumnIndex:4];
            cp.fp = [rs stringForColumnIndex:5];
            cp.msgType = [BasicTool getIntValue:[rs stringForColumnIndex:6] defaultVal:0];
            cp.quoteSenderUid = [rs stringForColumnIndex:7];
            cp.quoteSenderNick = [rs stringForColumnIndex:8];
            [cpList addObject:cp];
        }
    } else {
        [MyDataBase printErrorForDebug:db tag:@"ChatHistoryTable.searchTextMessagesContainingURL"];
    }
    return cpList;
}

// 按日期范围搜索消息，支持分页
- (NSMutableArray<MsgDetailContentDTO *> *)searchMessagesByDateRange:(FMDatabase *)db
                                                            chatType:(int)searchResultChatType
                                                            uidOrGid:(NSString *)uidOrGid
                                                            fromDate:(long)fromDate
                                                              toDate:(long)toDate
                                                               limit:(int)limit
                                                              offset:(int)offset
{
    NSMutableArray<MsgDetailContentDTO *> *cpList = [NSMutableArray array];
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (localUid == nil || uidOrGid == nil) {
        DLogWarn(@"searchMessagesByDateRange: 无效的参数！");
        return cpList;
    }
    
    long long normalizedFrom = (long long)fromDate;
    long long normalizedTo = (long long)toDate;
    BOOL rangeInMillis = (normalizedFrom >= 100000000000LL || normalizedTo >= 100000000000LL);
    long long fromMillis = rangeInMillis ? normalizedFrom : (normalizedFrom * 1000LL);
    long long toMillis = rangeInMillis ? normalizedTo : (normalizedTo * 1000LL);
    long long fromSeconds = rangeInMillis ? (normalizedFrom / 1000LL) : normalizedFrom;
    long long toSeconds = rangeInMillis ? (normalizedTo / 1000LL) : normalizedTo;
    NSString *dateRangeSQL = [NSString stringWithFormat:
                              @"((date >= %lld AND date < %lld) OR "
                              @"(date < 100000000000 AND date >= %lld AND date < %lld))",
                              fromMillis, toMillis, fromSeconds, toSeconds];

    NSArray<NSString *> *filedNames = nil;
    NSString *tableName = nil;
    NSString *where = nil;
    
    if (searchResultChatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE) {
        filedNames = @[@"_uid", @"senderId", @"senderDisplayName", @"date", @"text", @"finger_print_of_protocal", @"msgType"];
        tableName = @"chat_msg";
        where = [NSString stringWithFormat:@"_acount_uid='%@' AND _uid='%@' AND %@ AND msgType<>%d AND msgType<>%d",
                 localUid, uidOrGid, dateRangeSQL, TM_TYPE_SYSTEAM_INFO, TM_TYPE_REVOKE];
    }
    else if (searchResultChatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP) {
        filedNames = @[@"_gid", @"senderId", @"senderDisplayName", @"date", @"text", @"finger_print_of_protocal", @"msgType"];
        tableName = @"groupchat_msg";
        where = [NSString stringWithFormat:@"_acount_uid='%@' AND _gid='%@' AND %@ AND msgType<>%d AND msgType<>%d",
                 localUid, uidOrGid, dateRangeSQL, TM_TYPE_SYSTEAM_INFO, TM_TYPE_REVOKE];
    }
    else {
        DLogWarn(@"searchMessagesByDateRange: 无效的searchResultChatType=%d", searchResultChatType);
        return cpList;
    }
    
    FMResultSet *rs = [super query:db tableName:tableName fieldNames:filedNames filterSQL:[NSString stringWithFormat:@"%@ ORDER BY date DESC LIMIT %d OFFSET %d", where, limit, offset] debugTag:@"ChatHistoryTable.searchMessagesByDateRange"];
    
    if (rs != nil) {
        while (rs.next) {
            MsgDetailContentDTO *cp = [[MsgDetailContentDTO alloc] init];
            cp.chatType = searchResultChatType;
            cp.resultCount = 1;
            cp.dataId = [rs stringForColumnIndex:0];
            cp.senderId = [rs stringForColumnIndex:1];
            cp.senderDisplayName = [rs stringForColumnIndex:2];
            cp.date = [TimeTool dateFromChatHistoryStoredTime:[rs longLongIntForColumnIndex:3]];
            cp.text = [rs stringForColumnIndex:4];
            cp.fp = [rs stringForColumnIndex:5];
            cp.msgType = [BasicTool getIntValue:[rs stringForColumnIndex:6] defaultVal:0];
            [cpList addObject:cp];
        }
    } else {
        [MyDataBase printErrorForDebug:db tag:@"ChatHistoryTable.searchMessagesByDateRange"];
    }
    
    return cpList;
}

// 按发送者搜索群聊消息（群聊专用），支持分页
- (NSMutableArray<MsgDetailContentDTO *> *)searchMessagesBySender:(FMDatabase *)db
                                                              gid:(NSString *)gid
                                                        senderUid:(NSString *)senderUid
                                                            limit:(int)limit
                                                           offset:(int)offset
{
    NSMutableArray<MsgDetailContentDTO *> *cpList = [NSMutableArray array];
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (localUid == nil || gid == nil || senderUid == nil) {
        DLogWarn(@"searchMessagesBySender: 无效的参数！");
        return cpList;
    }
    
    NSArray<NSString *> *filedNames = @[@"_gid", @"senderId", @"senderDisplayName", @"date", @"text", @"finger_print_of_protocal", @"msgType"];
    NSString *tableName = @"groupchat_msg";
    NSString *where = [NSString stringWithFormat:@"_acount_uid='%@' AND _gid='%@' AND senderId='%@' AND msgType<>%d AND msgType<>%d",
                       localUid, gid, senderUid, TM_TYPE_SYSTEAM_INFO, TM_TYPE_REVOKE];
    
    FMResultSet *rs = [super query:db tableName:tableName fieldNames:filedNames filterSQL:[NSString stringWithFormat:@"%@ ORDER BY date DESC LIMIT %d OFFSET %d", where, limit, offset] debugTag:@"ChatHistoryTable.searchMessagesBySender"];
    
    if (rs != nil) {
        while (rs.next) {
            MsgDetailContentDTO *cp = [[MsgDetailContentDTO alloc] init];
            cp.chatType = MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP;
            cp.resultCount = 1;
            cp.dataId = [rs stringForColumnIndex:0];
            cp.senderId = [rs stringForColumnIndex:1];
            cp.senderDisplayName = [rs stringForColumnIndex:2];
            cp.date = [TimeTool dateFromChatHistoryStoredTime:[rs longLongIntForColumnIndex:3]];
            cp.text = [rs stringForColumnIndex:4];
            cp.fp = [rs stringForColumnIndex:5];
            cp.msgType = [BasicTool getIntValue:[rs stringForColumnIndex:6] defaultVal:0];
            [cpList addObject:cp];
        }
    } else {
        [MyDataBase printErrorForDebug:db tag:@"ChatHistoryTable.searchMessagesBySender"];
    }
    
    return cpList;
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
                        '%@' INTEGER ,\
                        '%@' INTEGER DEFAULT 0,\
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
                     , TABLE_NAME
                     , COLUMN_KEY_ID
                     , COLUMN_KEY_ACOUNT_UID
                     , COLUMN_KEY_UID
                     
                     , COLUMN_KEY_SENDER_ID
                     
                     , COLUMN_KEY_SENDER_DISPLAY_NAME
                     , COLUMN_KEY_DATE
                     , COLUMN_KEY_MSG_TYPE
                     , COLUMN_FINGER_PRINT_OF_PROTOCAL
                     , COLUMN_SEND_STATUS
                     , COLUMN_READ_BY_PARTNER
                     , COLUMN_CONVERSATION_MSG_SEQ
                     , COLUMN_KEY_QUOTE_FP
                     , COLUMN_KEY_QUOTE_SENDER_UID
                     , COLUMN_KEY_QUOTE_SENDER_NICK
                     , COLUMN_KEY_QUOTE_STATUS
                     , COLUMN_KEY_QUOTE_CONTENT
                     , COLUMN_KEY_QUOTE_TYPE
                     
                     , COLUMN_KEY_TEXT
                     , COLUMN_KEY_UPDATE_TIME
                     ];

    return sql;
}

+ (NSString *) getTableName
{
    return TABLE_NAME;
}

@end
