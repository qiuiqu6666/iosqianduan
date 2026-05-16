//telegram @wz662
#import "TableRoot.h"
#import "JSQMessage.h"
#import "QuoteFields.h"

@interface GroupChatHistoryTable : QuoteFields

/**
 * 返回历史聊天记录（目前是读取7天内的消息）.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param gid 读取的是哪个群的聊天消息
 * @param afterAndfp 载入消息的额外条件（当前用于搜索消息结果中查看某条消息时），即只加载这条消息之后的消息（包含该条消息自身），这个条件是fp指纹码，当为 nil时表示本条件不生效
 * @param beforeFp 载入消息的额外条件（当前用于加载更多历史消息功能时），即只加载这条消息之前的消息（不含该条消息自身），这个条件是fp指纹码，当为 nil时表示本条件不生效
 * @param beforeDate 载入消息的额外条件（当前用于加载更多历史消息功能时），即只加载这条消息之前的消息（不含该条消息自身），这个条件是消息的时间戳，当为0时表示本条件不生效
 * @param limit YES表示只加载一页，否则加载所有的查询结果
 */
- (NSArray<JSQMessage *> *) findHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner gid:(NSString *)gid afterAndFingerPrint:(NSString *)afterAndfp beforeFingerPrint:(NSString *)beforeFp beforeDatetime:(long)beforeDate limit:(BOOL)limit;

- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   gid:(NSString *)gid
                   cme:(JSQMessage *)cme;

- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   gid:(NSString *)gid
                   cme:(JSQMessage *)cme
             didInsert:(BOOL * _Nullable)outDidInsert;

/// 漫游/多端同步：同群同 fp 已存在则合并更新，否则插入。
- (BOOL) upsertHistoryMergeFromServer:(FMDatabase *)db
                     acountUidOfOwner:(NSString *)acountUidOfOwner
                                  gid:(NSString *)gid
                                  cme:(JSQMessage *)cme
                            didInsert:(BOOL * _Nullable)outDidInsert
                            didUpdate:(BOOL * _Nullable)outDidUpdate;

/// 将本群内「我发出的」且消息时间（Java 毫秒）≤ partnerReadTimeMs 的行标记为对方已读（群场景下同水位语义）。
- (BOOL)markOutgoingReadByPartnerUpToWatermark:(FMDatabase *)db
                           acountUidOfOwner:(NSString *)acountUidOfOwner
                                          gid:(NSString *)gid
                             localSenderIds:(NSArray<NSString *> *)localSenderIds
                           partnerReadTimeMs:(long long)partnerReadTimeMs;

/// 群聊发出消息的发送状态持久化（0 发送中 1 已送达 2 发送失败）。
- (BOOL)updateSendStatus:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fp sendStatus:(int)sendStatus;

/// App 被杀或异常退出后，库里残留的群聊「发送中」消息在下次进入会话时统一转为失败。
- (BOOL)markStaleOutgoingSendingMessagesAsFailed:(FMDatabase *)db
                                acountUidOfOwner:(NSString *)acountUidOfOwner
                                             gid:(NSString *)gid
                                  localSenderIds:(NSArray<NSString *> *)localSenderIds;

/**
 * 插入一行数据到表中.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @return `YES` upon success; `NO` upon failure.
 */
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
                 quote:(QuoteMeta *)quoteMeta;

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
             didInsert:(BOOL * _Nullable)outDidInsert;

/**
 * 删除超出保存期限的老聊天消息.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param gid 群id
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) deleteOldHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner gid:(NSString *)gid;

/**
 * 删除与某人的本地存储的所有聊天消息.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param gid 群id
 * @return `YES` upon success; `NO` upon failure.
 */
- (long) deleteHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner gid:(NSString *)gid;

/**
 * 删除指定指纹码对应的聊天消息.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param fpForMessage 被删除消息的指纹码
 * @return `YES` upon success; `NO` upon failure.
 */
- (long) deleteHistoryWithFp:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fpForMessage;

/**
 * 消息撤回成功后，更新本地消息的数据。
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param parentFpForMessage 被撤回消息的父指纹码
 * @param textObj 被撤回消息的新内容对象
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) updateForRevoke:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)parentFpForMessage meta:(RevokedMeta *)textObj;

/**
 * 查询指定群会话在本地 SQLite 中的最新消息时间戳（秒级）。
 * 用于多端增量同步时与服务端的 msg_time2 进行比对。
 *
 * @param acountUidOfOwner 本地数据的所有者账号
 * @param gid 群 ID
 * @return 最新消息的 iOS 秒级时间戳，无记录时返回 0
 */
- (long)getLatestMessageTimestamp:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner gid:(NSString *)gid;

/**
 * 检查指定指纹码的消息是否已存在于本地 SQLite 中。
 * 用于增量同步时去重判断。
 *
 * @param acountUidOfOwner 本地数据的所有者账号
 * @param fp 消息指纹码
 * @return YES 表示已存在，NO 表示不存在
 */
- (BOOL)hasMessageWithFingerprint:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fp;

/// 本群会话本地已持久化的最大 `conversation_msg_seq`（无列或全 0 时返回 0）。
- (long long)maxConversationMsgSeq:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner gid:(NSString *)gid;

+ (NSString *) getCreateTableSQL;
+ (NSString *) getTableName;

@end
