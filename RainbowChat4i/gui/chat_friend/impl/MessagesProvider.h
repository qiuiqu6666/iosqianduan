//telegram @wz662
/**
 * 用户的一对一聊天（包括好友聊天、陌生人聊天）消息全局缓存提供者.
 * <p>
 * 本类中的好友或陌生人消息将按key=uid, value=与该人员的消息列表对象的方式存储在 {@link #allFriendsMessages}中。
 * <p>
 * 本类还附属提供了一个用于存储“发送中。。。”的消息列表{@link #allFriendsMessagesGhostForNoReceived}，
 * 用于表现层能在有限的消息中快速而高效地进行匹配（而不用遍历所有好友的所有消息）.
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 */

#import <Foundation/Foundation.h>
#import "NSMutableArrayObservableEx.h"
//#import "ChatMsgEntity.h"
#import "JSQMessage.h"
#import "FMDB.h"

@class FriendsListProvider;

/**
 * 用于在消息列表中查找消息的结果返回对象。
 */
@interface FindResult : NSObject

/** 查找到的消息对象引用 */
@property (nonatomic, retain) JSQMessage *message;
/** 消息对象所处消息列表数组的索引位置 */
@property (nonatomic, assign) int index;

@end


/**
 * 用于在消息列表中删除消息的结果返回对象。
 */
@interface RemoveResult : NSObject

/** 删除操作是否成功 */
@property (nonatomic, assign) BOOL deletedSucess;
/** 被删除消息对象的实例引用 */
@property (nonatomic, retain) JSQMessage *deletedMessage;
/** 被删除消息的前一条消息对象的实例引用（当被删除消息就是第一条消息时，则此对象应是null） */
@property (nonatomic, retain) JSQMessage *previousDeletedMessage;
/** 被删除消息的后一条消息对象的实例引用（当被删除消息就是最后一条消息时，则此对象应是null） */
@property (nonatomic, retain) JSQMessage *behindDeletedMessage;
/** 被删除的消息对象，删除前它是否是消息列表数组的最后一个？*/
@property (nonatomic, assign) BOOL last;

@end


@interface MessagesProvider : NSObject

/**
 * 收到和发出的所有訪客消息.
 * 数据结构为：key=uid、value=NSMutableArrayObservable<ChatMsgEntity *>.
 */
@property (nonatomic, retain) NSMutableDictionary<NSString *, NSMutableArrayObservableEx *> *allFriendsMessages;

/**
 * 【本字段用于聊天消息质量保证机制的表现层机制】13-12-18日新启用的此算法.
 * <p>
 * 对方尚未应答的消息列表（当然是仅限于发出的消息，本列是 {@link #allFriendsMessages}列表对象的有限引用 ）.
 * <p>
 * 本列表中的对象将在发送消息时被Put、在对方收到或者框架判定发送给对方失败时被remove，
 * 本列表的应用在于当接收到对方的应答或者发送失败时用于快速匹配，加快性能而已.
 */
@property (nonatomic, retain) NSMutableDictionary<NSString *, JSQMessage *> *allFriendsMessagesGhostForNoReceived;

- (void)clearMessages:(NSString *)uid;

/**
 * 搜索跳转：clearMessages 之后、用 26-8 解析结果逐条 putMessage 装配内存 **之前** 必须调用。
 * 否则 `getMessages:` 在桶为空时会自动 `loadHistory(limit:YES)`，装入库内「最新一页」而非锚点时间窗口，随后 putMessage 大量被去重跳过，表现为 serverParsed=200 仍找不到目标 fp。
 */
- (void)rb_prepareEmptyMessageBucketSkippingSqliteBootstrapForUid:(NSString *)uid;

/**
 * 用于聊天界面上下拉加载更新历史记录功能。
 */
- (NSMutableArrayObservableEx *) loadMoreMessages:(NSString *)uid afterAndFingerPrint:(NSString *)afterAndfp limit:(BOOL)limit complete:(void (^)(BOOL sucess))complete;

/**
 * 将内存中该会话消息列表裁剪至最多 maxCount 条（默认丢弃最早的消息）。须在主线程调用。
 * 用于 Telegram 式窗口，避免 10 万条消息进内存导致卡顿。
 * 不派发 NSMutableArrayObservableEx 观察者回调；调用方应在同一流程内自行 reload 列表并处理滚动。
 *
 * @param trimNewestFirst YES：丢弃最新的若干条（用户正在上拉看更早历史时，避免刚装入的更旧一页被从索引 0 裁掉）。
 */
- (void)trimMessageWindowToMaxCount:(NSUInteger)maxCount forUid:(NSString *)uid;
- (void)trimMessageWindowToMaxCount:(NSUInteger)maxCount forUid:(NSString *)uid trimNewestFirst:(BOOL)trimNewestFirst;

- (void)putMessage:(NSString *)uid withData:(JSQMessage *)me;

/// SyncKey 等大批量入库前调用，期间 putMessage 不向观察者逐条派发（避免主线程被成千上万次刷新拖死）；处理结束后须 `endSyncKeyBulkMessageApply` 再 `notifyAllObserver`。
+ (void)beginSyncKeyBulkMessageApply;
+ (void)endSyncKeyBulkMessageApply;

/**
 获得对应聊天对象的聊天消息列表；首次为该 uid 建桶时同步从 SQLite 加载一页（与初始对比版一致）。

 @param uid 单聊为好友 uid，群聊为 gid
 @return 非空 NSMutableArrayObservableEx 引用
 */
- (NSMutableArrayObservableEx *) getMessages:(NSString *)uid;

/// 当前会话是否正在执行「SQLite 最新一页 bootstrap」；聊天页可据此跳过首帧空列表 reload，避免先空后灌。
- (BOOL)rb_isSqliteBootstrapInProgressForChatUid:(NSString *)uid;

/**
 * 按指纹码查找对应用户的消息对象。
 *
 * @param uid 聊天好友uid
 * @param fingerPrint 消息的指纹码
 * @return 找到则返回，否由返回null
 */
- (JSQMessage *)findMessageByFingerPrint:(NSString *)uid fp:(NSString *)fingerPrint;

/**
 * 按指纹码查找对应用户的消息对象所处索引位置。
 *
 * @param uid 聊天好友uid
 * @param fingerPrint 消息的指纹码
 * @return 找到则返回，否由返回null
 */
- (int)findIndexByFingerPrint:(NSString *)uid fp:(NSString *)fingerPrint;

/**
 * 按指纹码查找对应用户的消息对象和消息对象索引位置。
 *
 * @param uid 聊天好友uid
 * @param fingerPrint 消息的指纹码
 * @return 找到则返回，否由返回null
 */
- (FindResult *)findMessageByFingerPrintX:(NSString *)uid fp:(NSString *)fingerPrint;

/**
 * 按引用指纹码查找所有引用了原消息的消息对象（目前用于消息"撤回"功能时）。
 *
 * @param uid 聊天对象的id
 * @param beQuotedFingerPrint 被引用消息的指纹码
 * @return 找到则返回，否由返回null
 * @since 9.0
 */
- (NSArray<JSQMessage *> *) findMessagesByQuoteFingerPrint:(NSString *)uid beQuotedFp:(NSString *)beQuotedFingerPrint;

/**
 * 删除指定好友的消息指纹码对应的消息。
 *
 * @param friendUid 聊天好友的uid
 * @param fingerPrint 被删除消息的指纹码
 * @param deleteLocalData  本参数为true表示将同时删除存储在本地sqlite中的历史聊天消息
 * @return true表示删除成功
 */
- (RemoveResult *)removeMessage:(NSString *)friendUid fp:(NSString *)fingerPrint isDeleteLocalDatas:(BOOL)deleteLocalData;

/**
 * 从内存模型中删除指定好友的指定索引处聊天消息对象（注：本方法仅删除内存中的消息对象哦）。
 *
 * @param friendUid 聊天好友的uid
 * @param index 被删除消息的索引号
 * @return true表示成功删除，否则表示不成功
 */
- (RemoveResult *)removeMessage:(NSString *)friendUid index:(int)index;

/**
 * 删除指定人员的聊天记录（可同时指明是否也删除与该人员持久化存储在本地sqlite中的记录）。
 *
 * @param uid 要删除的好友uid
 * @param deleteLocalDatas 本参数为YES表示将同时删除存储在本地sqlite中的历史聊天消息
 * @param db FMDB的db操作封装对象，本对象只当deleteLocalDatas==YES不应为空，否则请传nil
 */
- (void) removeMessages:(NSString *)uid isDeleteLocalDatas:(BOOL)deleteLocalDatas db:(FMDatabase *)db notify:(BOOL)notifyObserver;

/**
 * 通知所有观察者.
 *
 * <p>
 * 某些场景下，无法确知应该告之哪个观察者（其实是不知道对应的uid）.
 * 比如：新算法实现的丢包判断逻辑，因为了提高算法性能而无法知道uid，
 * 但丢包的消息状态变更后希望ui也能刷新，那么就干脆就这样尝试通知所有
 * 息所有者的观察者吧，性能也没有多大损失，但UI更新的目的也达到了！
 */
- (void)notifyAllObserver;

/**
 * 仅通知指定 uid 对应会话消息桶的观察者（单聊/临时会话 key 为对端 uid）。
 * 用于 MT60 等只影响单会话的刷新，避免 `notifyAllObserver` 遍历所有好友桶。
 */
- (void)notifyObserversForChatUid:(NSString *)uid;

/**
 * 用户停留在聊天页时 IM 重连后：若该会话桶已在内存中，再从 SQLite 合并「最新一页」并入当前列表并 UNKNOW 通知聊天页，避免界面一直停在断网前的内存快照。
 * 群聊对 `GroupsMessagesProvider` 调用同样方法即可（`uid` 传 gid）。
 */
- (void)rb_reloadLatestPageFromDatabaseAndNotifyForChatUid:(NSString *)uid;

/**
 * 为当前的消息对象，设置是否显示消息时间标识。
 * <p>
 * 此时间显示逻辑是与微信保持一致的：即只显示5分钟内聊天消息的时间标识，
 * 参考资料：http://www.52im.net/thread-3008-1-1.html#40
 *
 * @param theMessage 当前消息对象，不可为null
 * @param previousMessage 当前消息的自然时间的上一条消息，此消息可为空（此为空即表示当前消息就是消息集合中的第一条消息）
 */
+ (void)setMessageShowTopTime:(JSQMessage *)theMessage  previous:(JSQMessage *)previousMessage;


/**
 * 将消息保存到本地数据库中作为历史聊天消息保存下来.
 *
 * @param uid
 * @param me
 * @see #putMessage(Context, String, ChatMsgEntity)
 */
- (void)saveHistory:(NSString *)uid withData:(JSQMessage *)me;

/** 收到送达 ack 后把该条消息的 send_status 写回 DB，避免再次进入会话从 DB 加载仍为 SNEDING 导致一直转圈 */
- (void)updateSendStatusForFp:(NSString *)fp sendStatus:(int)sendStatus;

/// QoS 超时或重试耗尽：将该条发出消息标记为发送失败，并在单聊场景写回 DB。
- (BOOL)markOutgoingMessageFailedForFp:(NSString *)fingerPrint preferredPeerUid:(NSString *)preferredPeerUid;
- (NSString *)findPeerUidByMessageFingerPrint:(NSString *)fingerPrint;

/**
 * QoS / MT63：将内存里该 fp 的「发出」消息标为已送达，写 DB、清 ghost、取消 SendRetry 计时，并通知对应会话观察者。
 * @param preferredPeerUid 单聊一般为会话对方 uid（MT63 的 receiver_uid）；若已在该桶找到则不必全表扫。
 * @return 是否找到并处理（含已为已送达的幂等清理 ghost）。
 */
- (BOOL)markOutgoingMessageDeliveredForFp:(NSString *)fingerPrint preferredPeerUid:(NSString *)preferredPeerUid;

/**
 * 载入历史聊天记录（存放于本地数据库中的）.
 * <p>
 * 本方法目前是在首次{@link #getMessages(String)}时，被调用.
 *
 * @param messageArray 即NSMutableArrayObservable<ChatMsgEntity>数组
 * @see #getMessages(String)
 */
- (void)loadHistory:(NSMutableArrayObservableEx *) messageArray forUid:(NSString *)uid afterAndFingerPrint:(NSString *)afterAndfp  beforeFingerPrint:(NSString *)afterFp beforeDatetime:(long)afterDate limit:(BOOL)limit complete:(void (^)(BOOL sucess))complete;

/**
 * 删除与指定好友的sqlite本地存储的聊天记录数据。
 *
 * @param friendUid 好友的uid
 */
- (void)deleteHistory:(FMDatabase *)db uid:(NSString *)friendUid;

/**
 * 删除指定指纹码对应的聊天记录数据。
 *
 * @param fpForMessage 被删除消息的指纹码
 */
- (void)deleteHistoryWithFp:(FMDatabase *)db fp:(NSString *)fpForMessage;

/**
 * 【本方法用于聊天消息质量保证机制的表现层机制】当对方确实收到包时（判定的标准
 * 是本地收到应答包）.
 *
 * @param fingerPrint 消息的指纹码
 */
- (void)friendReceivedMessage:(NSString *)fingerPrint;

/**
 * 【本方法用于聊天消息质量保证机制的表现层机制】直接从待决列表中匹配，而非遍历所有
 * 好友的所有消息，则计算效率要高很多罗.
 *
 * @return 返回的是“NSMutableDictionary<NSString *, ChatMsgEntity *>”字典对象指针
 */
- (NSMutableDictionary<NSString *, JSQMessage *> *)getAllFriendsMessagesGhostForNoReceived;

/**
 * 【本方法用于聊天消息质量保证机制的表现层机制】当确实因网络等原因没有发送成功时（
 * 判定的标准是本地在超时的时间间隔内没有收到应答包：即客户决的QoS质量保证机制）.
 *
 * @param fingerPrint 消息的指纹码
 */
- (void)sendToFriendFaild:(NSString *)fingerPrint;

// 根据聊天类型返回对应的MessagesProvider实例引用
+ (MessagesProvider *)getMessageProiderInstance:(int)chatType;

/// 按 msg.date 升序排序会话消息列表（断线重连/漫游合并后与服务端顺序一致）
+ (void)sortMessagesByDateAscending:(NSMutableArrayObservableEx *)someoneMessages;

/// loadHistory / putMessage / 漫游 共用的去重键（有 fp 用 fp，否则毫秒时间戳复合键）
+ (NSString *)dedupKeyForMessage:(JSQMessage *)msg;
/// 无 fp 时秒级 + msgType，与 HTTP/IM 路径时间戳毫秒不一致时仍可识别为同一条
+ (NSString *)dedupKeyForMessageLooseNoFingerPrint:(JSQMessage *)msg;
/// 同一会话（外层 uid/gid 已限定接收方或群）：同一 Java 毫秒 + 同一发送者 + 同一内容体 + 同一 msgType（异 fp 重复投递时仍能合并）
+ (NSString *)dedupKeyMillisSenderContentType:(JSQMessage *)msg;

@end

/** 历史接口字典含 `history_time2`（或数组格式时间列非空）解析成功后调用，便于发出消息与漫游行按 dedupKey 合并 */
void RBMarkJSQMessageFromHttpHistoryRow(JSQMessage *msg);
BOOL RBJSQMessageHasHttpHistoryRowMarker(JSQMessage *msg);

/// 合并本地 DB / 漫游预入库前调用：排空单聊与群聊异步 saveHistory 队列，避免读到旧快照或竞态
void RBDrainAllChatSaveHistoryQueues(void);

/// 消息指纹比较：trim + 大小写不敏感（搜索 26-41 与漫游 26-8 / 本地库可能对 UUID 大小写不一致，会导致高亮查找失败、界面滚到底部看起来像「没显示」）。
FOUNDATION_EXPORT BOOL RBFingerprintStringsEqual(NSString * _Nullable a, NSString * _Nullable b);

/// 漫游/历史接口的 msg_content 可能是 JSON 字符串或已解析的 NSDictionary/NSArray；需转为可供 FileMeta.fromJSON 等使用的字符串（勿用 description）。
NSString * _Nullable RBNormalizeChatHistoryMsgContentString(id _Nullable raw);

/// 1008-26-8 等返回的「数组行」：旧版指纹在索引 9、父指纹在 10；新版紧凑列在时间与正文之后指纹在索引 6（父在 7）。两处解析必须一致，否则 fp 为空会导致 upsert 退化为重复 INSERT、与 IM 同条双显。
void RBHistoryArrayExtractFingerPrints(NSArray * _Nonnull arr, NSString * _Nullable __autoreleasing * _Nullable outFp, NSString * _Nullable __autoreleasing * _Nullable outParentFp);

/// 手册 §3.4：`messages` 定长数组下标 **15** 为 `conv_seq`（与 26-7 `conversation_msg_seq` 同源）；列数不足或未下发时返回 0。
long long RBHistoryArrayConversationMsgSeq(NSArray * _Nonnull arr);

/// 将 26-8 `messages` 数组行解析为 `JSQMessage`（含引用列 9–14、昵称列 16、`rb_conversationMsgSeq`）；失败返回 nil。
JSQMessage * _Nullable RBParseJSQMessageFrom26_8HistoryRow(NSArray * _Nonnull arr, NSString * _Nonnull localUid, BOOL isGroupChat, FriendsListProvider * _Nullable friendsProvider);

/// 服务端可能使用 file_name/file_md5/file_length，映射为 FileMeta 属性名后再序列化。
NSString * _Nullable RBNormalizeFileMetaJSONStringForHistory(NSString * _Nullable json);

/// 观察者 extra.reason：当前通知来自 SQLite 首屏/bootstrap 回灌，而不是单条消息增量。
FOUNDATION_EXPORT NSString * const RBChatObserverExtraReasonKey;
FOUNDATION_EXPORT NSString * const RBChatObserverReasonSqliteBootstrap;
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> * _Nullable RBChatObserverExtraMake(NSString * _Nullable reason);
FOUNDATION_EXPORT BOOL RBChatObserverExtraHasReason(id _Nullable extraData, NSString * _Nonnull reason);
