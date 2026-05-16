//telegram @wz662
/**
 * 本系统的sqlLite数据表——一对一聊天消息(好友聊天或陌生人聊天)历史记录的辅助操作实
 * 现类（支持同一手机上切换不同的账号使用而不发生数据混乱）..
 * <p>
 * 本表中没有明确区分临时聊天消息或正式聊天消息，因为逻辑上讲同一个uid只有可能
 * 要么是正式聊天或要么是临时聊天消息
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 * @since 4.3
 */

#import "TableRoot.h"
#import "JSQMessage.h"
#import "RevokedMeta.h"
#import "MsgSummaryContentDTO.h"
#import "MsgDetailContentDTO.h"
#import "QuoteFields.h"

@interface ChatHistoryTable : QuoteFields

/**
 * 返回历史聊天记录（目前是读取7天内的消息）.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param uid 读取的是跟谁的聊天消息（即与“我”聊天者的uid）
 * @param afterAndfp 载入消息的额外条件（当前用于搜索消息结果中查看某条消息时），即只加载这条消息之后的消息（包含该条消息自身），这个条件是fp指纹码，当为 nil时表示本条件不生效
 * @param beforeFp 载入消息的额外条件（当前用于加载更多历史消息功能时），即只加载这条消息之前的消息（不含该条消息自身），这个条件是fp指纹码，当为 nil时表示本条件不生效
 * @param beforeDate 载入消息的额外条件（当前用于加载更多历史消息功能时），即只加载这条消息之前的消息（不含该条消息自身），这个条件是消息的时间戳，当为0时表示本条件不生效
 * @param limit YES表示只加载一页，否则加载所有的查询结果
 */
- (NSArray<JSQMessage *> *) findHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner uid:(NSString *)uid afterAndFingerPrint:(NSString *)afterAndfp beforeFingerPrint:(NSString *)beforeFp beforeDatetime:(long)beforeDate limit:(BOOL)limit;

- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   uid:(NSString *)uid
                   cme:(JSQMessage *)cme;

/// 同 `insertHistory:acountUidOfOwner:uid:cme:`；若 `outDidInsert` 非空，仅在本次真正执行 INSERT 时写入 YES（本地已有相同指纹则 NO，方法仍返回 YES 表示无需报错）。
- (BOOL) insertHistory:(FMDatabase *)db
      acountUidOfOwner:(NSString *)acountUidOfOwner
                   uid:(NSString *)uid
                   cme:(JSQMessage *)cme
             didInsert:(BOOL * _Nullable)outDidInsert;

/// 漫游/多端同步：同会话同 fp 已存在则按时间或撤回类型覆盖更新，否则插入。
- (BOOL) upsertHistoryMergeFromServer:(FMDatabase *)db
                     acountUidOfOwner:(NSString *)acountUidOfOwner
                                  uid:(NSString *)uid
                                  cme:(JSQMessage *)cme
                            didInsert:(BOOL * _Nullable)outDidInsert
                            didUpdate:(BOOL * _Nullable)outDidUpdate;

/**
 * 插入一行数据到表中.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @return `YES` upon success; `NO` upon failure.
 */
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
                quote:(QuoteMeta *)quoteMeta;

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
           didInsert:(BOOL * _Nullable)outDidInsert;

/**
 * 删除超出保存期限的老聊天消息.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param uid 与“我”聊天者的uid
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) deleteOldHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner uid:(NSString *)uid;

/**
 * 删除与某人的本地存储的所有聊天消息.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param srcUid 与“我”聊天者的uid
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) deleteHistory:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner srcUid:(NSString *)srcUid;

/**
 * 删除指定指纹码对应的聊天消息.
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param fpForMessage 被删除消息的指纹码
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) deleteHistoryWithFp:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fpForMessage;

/**
 * 消息撤回成功后，更新本地消息的数据。
 *
 * @param acountUidOfOwner 本地数据的所有者账号，本条件是读取本地数据的先决条件，否则就窜数据了！
 * @param fpForMessage 被撤回消息的指纹码
 * @param textObj 被撤回消息的新内容对象
 * @return `YES` upon success; `NO` upon failure.
 */
- (BOOL) updateForRevoke:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fpForMessage meta:(RevokedMeta *)textObj;

/**
 * 收到送达 ack 后更新该条消息的 send_status（如 BE_RECEIVED），避免再次进入会话从 DB 加载仍为 SNEDING 导致一直转圈。
 */
- (BOOL) updateSendStatus:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fp sendStatus:(int)sendStatus;

/// App 被杀或异常退出后，库里残留的「发送中」消息在下次进入会话时统一转为失败，避免一直显示转圈。
- (BOOL)markStaleOutgoingSendingMessagesAsFailed:(FMDatabase *)db
                                acountUidOfOwner:(NSString *)acountUidOfOwner
                                             uid:(NSString *)uid
                                  localSenderIds:(NSArray<NSString *> *)localSenderIds;

/// 将本会话内「我发出的」且消息时间（Java 毫秒）≤ partnerReadTimeMs 的行标记为对方已读，与内存水位一致并供下次进会话即时展示双勾。
/// localSenderIds：本地账号可能对应多条 senderId（如 IM user_uid 与 ClientCoreSDK 登录 id），须全部纳入匹配，否则 UPDATE 命中 0 行会导致重进会话丢双勾。
- (BOOL)markOutgoingReadByPartnerUpToWatermark:(FMDatabase *)db
                           acountUidOfOwner:(NSString *)acountUidOfOwner
                                        uid:(NSString *)uid
                             localSenderIds:(NSArray<NSString *> *)localSenderIds
                           partnerReadTimeMs:(long long)partnerReadTimeMs;

/**
 * 查询指定会话在本地 SQLite 中的最新消息时间戳（秒级）。
 * 用于多端增量同步时与服务端的 msg_time2 进行比对。
 *
 * @param acountUidOfOwner 本地数据的所有者账号
 * @param uid 与"我"聊天者的 uid
 * @return 最新消息的 iOS 秒级时间戳，无记录时返回 0
 */
- (long)getLatestMessageTimestamp:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner uid:(NSString *)uid;

/**
 * 检查指定指纹码的消息是否已存在于本地 SQLite 中。
 * 用于增量同步时去重判断。
 *
 * @param acountUidOfOwner 本地数据的所有者账号
 * @param fp 消息指纹码
 * @return YES 表示已存在，NO 表示不存在
 */
- (BOOL)hasMessageWithFingerprint:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner fp:(NSString *)fp;

/// 本会话本地已持久化的最大 `conversation_msg_seq`（无列或全 0 时返回 0）。
- (long long)maxConversationMsgSeq:(FMDatabase *)db acountUidOfOwner:(NSString *)acountUidOfOwner uid:(NSString *)uid;

#pragma mark - 专用聊天记录搜索功能增加的方法

/**
 * 搜索带有指定关键字的单聊、群聊消息（本方法的查询会将结果按聊天对象进行聚合，比如结果可
 * 能是：某某人有多少条消息包含此结果、某群有多少条消息包含此结果，不过当结果只有一条时会显示该唯一消息内容）.
 *
 * @param keyword 要查询的关键字
 * @param limit 显定返回的查询结果数（如果是大于0则起效，否则表示不限定）
 * @return 返回查询结果，如果为空也会返回空集合对象而不是null
 */
- (NSMutableArray<MsgSummaryContentDTO *> *) searchMessagesSummery:(FMDatabase *)db keyword:(NSString *)keyword limit:(int)limit;

/**
 * 搜索指定聊天对象（单聊或群聊）内带有指定关键字的所有消息（本方法的查询结果不会聚合，有多少条就显示多少条）.
 *
 * @param searchResultChatType 搜索结果类型，见 {@link MsgSummarySearchResult}
 * @param uidOrGid 聊天对象的id（单聊时本参数为对方的uid、群聊时为所在群的gid）
 * @param keyword 要查询的关键字
 * @return 返回查询结果，如果为空也会返回空集合对象而不是null
 */
- (NSMutableArray<MsgDetailContentDTO *> *) searchMessagesDetail:(FMDatabase *)db chatType:(int)searchResultChatType uidOrGid:(NSString *) uidOrGid keyword:(NSString *)keyword;

/**
 * 按消息类型搜索（用于图片/视频/文件浏览）.
 *
 * @param searchResultChatType 搜索结果类型（单聊或群聊）
 * @param uidOrGid 聊天对象的id（单聊为uid、群聊为gid）
 * @param msgTypes 消息类型数组（如 @[@1, @6] 表示图片和短视频）
 * @return 返回查询结果
 */
- (NSMutableArray<MsgDetailContentDTO *> *)searchMessagesByTypes:(FMDatabase *)db
                                                        chatType:(int)searchResultChatType
                                                        uidOrGid:(NSString *)uidOrGid
                                                        msgTypes:(NSArray<NSNumber *> *)msgTypes
                                                           limit:(int)limit
                                                          offset:(int)offset;

/** 同上，且当 excludeTextContainingURL 为 YES 时排除文本内容含 http(s):// 的消息（用于收藏夹「对话」Tab，与链接 Tab 不重复） */
- (NSMutableArray<MsgDetailContentDTO *> *)searchMessagesByTypes:(FMDatabase *)db
                                                        chatType:(int)searchResultChatType
                                                        uidOrGid:(NSString *)uidOrGid
                                                        msgTypes:(NSArray<NSNumber *> *)msgTypes
                                        excludeTextContainingURL:(BOOL)excludeTextContainingURL
                                                           limit:(int)limit
                                                          offset:(int)offset;

/**
 * 按「文本内容包含 URL」搜索消息（用于收藏夹链接 Tab），仅查文本消息且 content 含 http(s)://.
 */
- (NSMutableArray<MsgDetailContentDTO *> *)searchTextMessagesContainingURL:(FMDatabase *)db
                                                                  chatType:(int)searchResultChatType
                                                                  uidOrGid:(NSString *)uidOrGid
                                                                     limit:(int)limit
                                                                    offset:(int)offset;

/**
 * 按日期范围搜索消息.
 *
 * @param searchResultChatType 搜索结果类型（单聊或群聊）
 * @param uidOrGid 聊天对象的id（单聊为uid、群聊为gid）
 * @param fromDate 起始时间戳（iOS秒级）
 * @param toDate 结束时间戳（iOS秒级）
 * @return 返回查询结果
 */
- (NSMutableArray<MsgDetailContentDTO *> *)searchMessagesByDateRange:(FMDatabase *)db
                                                            chatType:(int)searchResultChatType
                                                            uidOrGid:(NSString *)uidOrGid
                                                            fromDate:(long)fromDate
                                                              toDate:(long)toDate
                                                               limit:(int)limit
                                                              offset:(int)offset;

/**
 * 按发送者搜索群聊消息（群聊专用）.
 *
 * @param gid 群组id
 * @param senderUid 发送者uid
 * @return 返回查询结果
 */
- (NSMutableArray<MsgDetailContentDTO *> *)searchMessagesBySender:(FMDatabase *)db
                                                              gid:(NSString *)gid
                                                        senderUid:(NSString *)senderUid
                                                            limit:(int)limit
                                                           offset:(int)offset;


#pragma mark - 静态类方法

+ (NSString *) getCreateTableSQL;
+ (NSString *) getTableName;

@end
