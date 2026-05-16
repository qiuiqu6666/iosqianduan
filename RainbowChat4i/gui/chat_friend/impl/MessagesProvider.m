//telegram @wz662
#import "MessagesProvider.h"
//#import "ChatMsgEntity.h"
//#import "JSQMessage.h"
#import "UserEntity.h"
#import "IMClientManager.h"
#import "ClientCoreSDK.h"
#import "MyDataBase.h"
#import "TimeTool.h"
#import "BasicTool.h"
#import "Default.h"
#import "GroupEntity.h"
#import "GroupsMessagesProvider.h"
#import "SendRetryManager.h"
#import "FriendsListProvider.h"
#import "JSQMessage+RBConversationSeq.h"
#import "MsgBodyRoot.h"
#import <objc/runtime.h>

extern void RBDrainGroupChatSaveHistoryQueue(void);

NSString * const RBChatObserverExtraReasonKey = @"reason";
NSString * const RBChatObserverReasonSqliteBootstrap = @"sqlite_bootstrap";

NSDictionary<NSString *, NSString *> * RBChatObserverExtraMake(NSString *reason)
{
    if (reason.length == 0) {
        return nil;
    }
    return @{ RBChatObserverExtraReasonKey : reason };
}

BOOL RBChatObserverExtraHasReason(id extraData, NSString *reason)
{
    if (reason.length == 0 || ![extraData isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    id value = [(NSDictionary *)extraData objectForKey:RBChatObserverExtraReasonKey];
    return [value isKindOfClass:[NSString class]] && [(NSString *)value isEqualToString:reason];
}

/// SyncKey 批量处理嵌套计数：>0 时 putMessage 不向 NSMutableArrayObservableEx 逐条 notify（由批次末尾 notifyAllObserver 统一刷新）
static NSInteger s_syncKeyBulkApplyDepth = 0;

static BOOL RBMessagesProviderInSyncKeyBulkApply(void)
{
    return s_syncKeyBulkApplyDepth > 0;
}

/// 串行队列：saveHistory 异步写库在此执行，避免主线程在 inDatabase 上阻塞导致 runloop hang
static dispatch_queue_t s_saveHistoryQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        q = dispatch_queue_create("com.rainbowchat.messagesprovider.saveHistory", DISPATCH_QUEUE_SERIAL);
    });
    return q;
}

/// 排空单聊 + 群聊两条异步写库队列（供需要与 DB 强一致的路径调用）
static void rb_drainChatSaveHistoryQueues(void)
{
    dispatch_sync(s_saveHistoryQueue(), ^{});
    RBDrainGroupChatSaveHistoryQueue();
}

void RBDrainAllChatSaveHistoryQueues(void)
{
    rb_drainChatSaveHistoryQueues();
}

static const void *kRBHttpHistoryRowMarkerKey = &kRBHttpHistoryRowMarkerKey;

void RBMarkJSQMessageFromHttpHistoryRow(JSQMessage *msg)
{
    if (!msg) return;
    objc_setAssociatedObject(msg, kRBHttpHistoryRowMarkerKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

BOOL RBJSQMessageHasHttpHistoryRowMarker(JSQMessage *msg)
{
    if (!msg) return NO;
    return [objc_getAssociatedObject(msg, kRBHttpHistoryRowMarkerKey) boolValue];
}

BOOL RBFingerprintStringsEqual(NSString *a, NSString *b)
{
    if (a == nil || b == nil) {
        return NO;
    }
    NSString *ta = [[a stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    NSString *tb = [[b stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    return ta.length > 0 && tb.length > 0 && [ta isEqualToString:tb];
}

static NSString *rb_trimmedStringFromHistoryCell(id obj)
{
    if (obj == nil || [obj isKindOfClass:[NSNull class]]) {
        return nil;
    }
    NSString *s = nil;
    if ([obj isKindOfClass:[NSString class]]) {
        s = (NSString *)obj;
    } else if ([obj isKindOfClass:[NSNumber class]]) {
        s = [(NSNumber *)obj stringValue];
    } else {
        return nil;
    }
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return s.length > 0 ? s : nil;
}

/// 排除纯数字列，避免把非 UUID 的其它字段误当 msg_content2
static BOOL rb_cellLooksLikeMessageFingerprint(NSString *s)
{
    if (s.length < 8) {
        return NO;
    }
    static NSCharacterSet *nonDigit = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        nonDigit = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    });
    if ([s rangeOfCharacterFromSet:nonDigit].location == NSNotFound) {
        return NO;
    }
    return YES;
}

static BOOL RBStringIsAllDecimalDigits(NSString *s)
{
    if (s.length == 0) {
        return NO;
    }
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (c < '0' || c > '9') {
            return NO;
        }
    }
    return YES;
}

/// Java 毫秒时间戳字符串（服务端 messages 行里常见 13 位）
static BOOL RBStringLooksLikeJavaMillisString(NSString *s)
{
    if (s.length < 12 || s.length > 15) {
        return NO;
    }
    return RBStringIsAllDecimalDigits(s);
}

/**
 * 服务端 26-8 / 搜索 messages 数组常见格式：
 * [槽位, sender_uid, receiver_uid, chat_type?, msg_type, text, java_ms, fingerprint, parent_fp?, quote..., seq?, nick?]
 * 与旧版「sender 在 arr[0]、时间在 arr[5]」不同；旧解析会把 arr[0] 当成 uid、指纹落空（arr[6] 被当成 fp 却因纯数字被跳过）→ 落库无 fp → 搜索高亮永久 MISS。
 */
static BOOL RB26_8HistoryRowIsSlotSenderLayout(NSArray *arr)
{
    if (![arr isKindOfClass:[NSArray class]] || arr.count < 8) {
        return NO;
    }
    NSString *t5 = rb_trimmedStringFromHistoryCell(arr[5]);
    NSString *t6 = rb_trimmedStringFromHistoryCell(arr[6]);
    NSString *t7 = rb_trimmedStringFromHistoryCell(arr[7]);
    if (RBStringLooksLikeJavaMillisString(t5)) {
        return NO;
    }
    if (!RBStringLooksLikeJavaMillisString(t6)) {
        return NO;
    }
    if (!rb_cellLooksLikeMessageFingerprint(t7)) {
        return NO;
    }
    return YES;
}

/**
 * 聊天记录搜索等接口在首列带「会话内短序号」，发送者在 arr[1]：
 *   ["13","11974612","400069","0","0","好吧", ms, fp, ...]
 * 1008-26-8 直出无该列，首列即发送者 uid：
 *   ["11974612","400069","0","0", text, ms, fp, ...]
 * 若误把 26-8 行当 slot 且 sender 取 arr[1]，会把对方 uid 当成本人 → 指纹/去重错乱 → 搜索高亮永远 MISS（rizhi 已证实 HTTP 包内含目标 fp）。
 */
static BOOL RB26_8HistoryRowHasLeadingMessageSeqColumn(NSArray *arr)
{
    if (![arr isKindOfClass:[NSArray class]] || arr.count < 9) {
        return NO;
    }
    NSString *t0 = rb_trimmedStringFromHistoryCell(arr[0]);
    if (t0.length == 0 || t0.length > 4) {
        return NO;
    }
    if (!RBStringIsAllDecimalDigits(t0)) {
        return NO;
    }
    NSString *t1 = rb_trimmedStringFromHistoryCell(arr[1]);
    /// 发送者 uid 多为 ≥5 位数字；避免把 26-8 的首列 uid 当成序号
    if (t1.length < 5 || !RBStringIsAllDecimalDigits(t1)) {
        return NO;
    }
    return YES;
}

void RBHistoryArrayExtractFingerPrints(NSArray *arr, NSString **outFp, NSString **outParentFp)
{
    if (outFp != NULL) {
        *outFp = nil;
    }
    if (outParentFp != NULL) {
        *outParentFp = nil;
    }
    if (![arr isKindOfClass:[NSArray class]] || arr.count < 6) {
        return;
    }

    // 紧凑布局（26-8 等）：主指纹在 arr[6]、父指纹在 arr[7]。须优先于 legacy 的 arr[9]，否则 arr[9] 常为「引用 quote_fp」等非消息指纹，会导致落库 fp 与搜索接口不一致 → 高亮永远 MISS。
    NSString *compactFp = arr.count > 6 ? rb_trimmedStringFromHistoryCell(arr[6]) : nil;
    if (compactFp.length > 0 && rb_cellLooksLikeMessageFingerprint(compactFp)) {
        if (outFp != NULL) {
            *outFp = compactFp;
        }
        if (outParentFp != NULL) {
            NSString *p7 = arr.count > 7 ? rb_trimmedStringFromHistoryCell(arr[7]) : nil;
            *outParentFp = p7.length > 0 ? p7 : nil;
        }
        return;
    }

    NSString *legacyFp = arr.count > 9 ? rb_trimmedStringFromHistoryCell(arr[9]) : nil;
    NSString *legacyParent = arr.count > 10 ? rb_trimmedStringFromHistoryCell(arr[10]) : nil;
    if (legacyFp.length > 0) {
        if (outFp != NULL) {
            *outFp = legacyFp;
        }
        if (outParentFp != NULL) {
            *outParentFp = legacyParent.length > 0 ? legacyParent : nil;
        }
    }
}

long long RBHistoryArrayConversationMsgSeq(NSArray *arr)
{
    if (![arr isKindOfClass:[NSArray class]] || arr.count < 6) {
        return 0;
    }
    if (RB26_8HistoryRowIsSlotSenderLayout(arr) && arr.count > 16) {
        id v = arr[16];
        if (v != nil && ![v isKindOfClass:[NSNull class]]) {
            if ([v isKindOfClass:[NSNumber class]]) {
                return [(NSNumber *)v longLongValue];
            }
            if ([v isKindOfClass:[NSString class]]) {
                NSString *s = [(NSString *)v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (s.length > 0) {
                    return (long long)[s longLongValue];
                }
            }
        }
        return 0;
    }
    if (arr.count <= 15) {
        return 0;
    }
    id v = arr[15];
    if (v == nil || [v isKindOfClass:[NSNull class]]) {
        return 0;
    }
    if ([v isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)v longLongValue];
    }
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length == 0) {
            return 0;
        }
        return (long long)[s longLongValue];
    }
    return 0;
}

JSQMessage *RBParseJSQMessageFrom26_8HistoryRow(NSArray *arr, NSString *localUid, BOOL isGroupChat, FriendsListProvider *friendsProvider)
{
    if (![arr isKindOfClass:[NSArray class]] || arr.count < 6 || localUid.length == 0) {
        return nil;
    }

    NSString *srcUid = nil;
    int msgType = 0;
    id rawContent = nil;
    NSString *msgTime2 = nil;
    NSString *fp = nil;
    NSString *parentFp = nil;
    NSString *serverNick = nil;

    if (RB26_8HistoryRowIsSlotSenderLayout(arr)) {
        srcUid = rb_trimmedStringFromHistoryCell(RB26_8HistoryRowHasLeadingMessageSeqColumn(arr) ? arr[1] : arr[0]);
        msgType = arr.count > 4 ? [BasicTool getIntValue:rb_trimmedStringFromHistoryCell(arr[4]) defaultVal:0] : 0;
        rawContent = arr.count > 5 ? arr[5] : nil;
        msgTime2 = rb_trimmedStringFromHistoryCell(arr.count > 6 ? arr[6] : nil);
        fp = rb_trimmedStringFromHistoryCell(arr.count > 7 ? arr[7] : nil);
        parentFp = rb_trimmedStringFromHistoryCell(arr.count > 8 ? arr[8] : nil);
        if (arr.count > 17) {
            serverNick = rb_trimmedStringFromHistoryCell(arr[17]);
        }
        if (serverNick.length == 0 && arr.count > 16) {
            NSString *n16 = rb_trimmedStringFromHistoryCell(arr[16]);
            if (n16.length > 0 && [n16 rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location != NSNotFound) {
                serverNick = n16;
            }
        }
    } else {
        srcUid = rb_trimmedStringFromHistoryCell(arr[0]);
        if (arr.count > 3) {
            msgType = [BasicTool getIntValue:rb_trimmedStringFromHistoryCell(arr[3]) defaultVal:0];
        }
        rawContent = arr.count > 4 ? arr[4] : nil;
        msgTime2 = rb_trimmedStringFromHistoryCell(arr.count > 5 ? arr[5] : nil);
        RBHistoryArrayExtractFingerPrints(arr, &fp, &parentFp);
        serverNick = (arr.count > 16) ? rb_trimmedStringFromHistoryCell(arr[16]) : nil;
    }

    if (srcUid.length == 0) {
        return nil;
    }

    NSString *msgContent = RBNormalizeChatHistoryMsgContentString(rawContent);
    if (msgContent == nil) {
        msgContent = rb_trimmedStringFromHistoryCell(rawContent);
    }
    if (msgContent == nil) {
        msgContent = @"";
    }
    if (msgType == TM_TYPE_SHORTVIDEO || msgType == TM_TYPE_FILE) {
        NSString *fixedMeta = RBNormalizeFileMetaJSONStringForHistory(msgContent);
        if (fixedMeta.length > 0) {
            msgContent = fixedMeta;
        }
    }

    NSDate *msgDate = [TimeTool convertJavaTimestampToiOSDate:msgTime2];
    if (msgDate == nil) {
        msgDate = [NSDate date];
    }

    BOOL isOutgoing = [srcUid isEqualToString:localUid];

    NSString *displayName = nil;
    if (isOutgoing) {
        displayName = @"我";
    } else if (isGroupChat) {
        displayName = (serverNick.length > 0) ? serverNick : @"";
        if (friendsProvider != nil && srcUid.length > 0) {
            UserEntity *friendInfo = [friendsProvider getFriendInfoByUid2:srcUid];
            if (friendInfo != nil) {
                NSString *nk = [friendInfo getNickNameWithRemark];
                if (![BasicTool isStringEmpty:nk]) {
                    displayName = nk;
                }
            }
        }
    } else {
        displayName = (serverNick.length > 0) ? serverNick : @"";
        if (friendsProvider != nil && srcUid.length > 0) {
            UserEntity *friendInfo = [friendsProvider getFriendInfoByUid2:srcUid];
            if (friendInfo != nil) {
                NSString *nk = [friendInfo getNickNameWithRemark];
                if (![BasicTool isStringEmpty:nk]) {
                    displayName = nk;
                }
            }
        }
    }

    JSQMessage *msg = [[JSQMessage alloc] init];
    msg.senderId = srcUid;
    msg.senderDisplayName = displayName ?: @"";
    msg.date = msgDate;
    msg.text = msgContent;
    msg.msgType = msgType;
    msg.fingerPrintOfProtocal = fp.length > 0 ? [fp lowercaseString] : nil;
    msg.fingerPrintOfParent = parentFp.length > 0 ? [parentFp lowercaseString] : nil;
    msg.sendStatus = SendStatus_BE_RECEIVED;
    msg.sendStatusSecondary = SendStatusSecondary_NONE;

    if (arr.count > 14) {
        msg.quote_fp = rb_trimmedStringFromHistoryCell(arr[9]);
        msg.quote_sender_uid = rb_trimmedStringFromHistoryCell(arr[10]);
        msg.quote_sender_nick = rb_trimmedStringFromHistoryCell(arr[11]);
        msg.quote_status = [BasicTool getIntValue:rb_trimmedStringFromHistoryCell(arr[12]) defaultVal:0];
        msg.quote_content = rb_trimmedStringFromHistoryCell(arr[13]);
        msg.quote_type = [BasicTool getIntValue:rb_trimmedStringFromHistoryCell(arr[14]) defaultVal:0];
    }

    msg.rb_conversationMsgSeq = RBHistoryArrayConversationMsgSeq(arr);

    if (msgTime2.length > 0) {
        RBMarkJSQMessageFromHttpHistoryRow(msg);
    }

    return msg;
}

NSString *RBNormalizeChatHistoryMsgContentString(id raw)
{
    if (raw == nil || [raw isKindOfClass:[NSNull class]]) {
        return nil;
    }
    if ([raw isKindOfClass:[NSString class]]) {
        return (NSString *)raw;
    }
    if ([raw isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)raw stringValue];
    }
    if ([raw isKindOfClass:[NSDictionary class]] || [raw isKindOfClass:[NSArray class]]) {
        NSError *err = nil;
        NSData *d = [NSJSONSerialization dataWithJSONObject:raw options:0 error:&err];
        if (d != nil) {
            return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        }
        NSLog(@"【漫游解析】msg_content 序列化为 JSON 失败: %@", err);
        return nil;
    }
    return nil;
}

NSString *RBNormalizeFileMetaJSONStringForHistory(NSString *json)
{
    if (json == nil || json.length == 0) {
        return json;
    }
    NSData *d = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (d == nil) {
        return json;
    }
    NSError *err = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:&err];
    if (![obj isKindOfClass:[NSDictionary class]]) {
        return json;
    }
    NSMutableDictionary *m = (NSMutableDictionary *)obj;
    void (^alias)(NSString *, NSString *) = ^(NSString *canon, NSString *alt) {
        if (m[canon] == nil && m[alt] != nil) {
            m[canon] = m[alt];
        }
    };
    alias(@"fileName", @"file_name");
    alias(@"fileMd5", @"file_md5");
    alias(@"fileLength", @"file_length");
    NSData *out = [NSJSONSerialization dataWithJSONObject:m options:0 error:&err];
    if (out == nil) {
        return json;
    }
    return [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding];
}

//////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
//////////////////////////////////////////////////////////////////////////////////////

@interface MessagesProvider ()

///**
// * 收到和发出的所有訪客消息.
// * 数据结构为：key=uid、value=NSMutableArrayObservable<ChatMsgEntity *>.
// */
//@property (nonatomic, retain) NSMutableDictionary<NSString *, NSMutableArrayObservableEx *> *allFriendsMessages;
//
///**
// * 【本字段用于聊天消息质量保证机制的表现层机制】2013-12-18日新启用的此算法.
// * <p>
// * 对方尚未应答的消息列表（当然是仅限于发出的消息，本列是 {@link #allFriendsMessages}列表对象的有限引用 ）.
// * <p>
// * 本列表中的对象将在发送消息时被Put、在对方收到或者框架判定发送给对方失败时被remove，
// * 本列表的应用在于当接收到对方的应答或者发送失败时用于快速匹配，加快性能而已.
// */
//@property (nonatomic, retain) NSMutableDictionary<NSString *, JSQMessage *> *allFriendsMessagesGhostForNoReceived;

@end


//////////////////////////////////////////////////////////////////////////////////////
#pragma mark - FindResult类
//////////////////////////////////////////////////////////////////////////////////////

@implementation FindResult

- (id)init
{
    if (![super init])
        return nil;

    DDLogVerbose(@"FindResult init");

    // 内部变量初始化
    self.index = -1;

    return self;
}

@end


//////////////////////////////////////////////////////////////////////////////////////
#pragma mark - RemoveResult类
//////////////////////////////////////////////////////////////////////////////////////

@implementation RemoveResult

- (id)init
{
    if (![super init])
        return nil;

    DDLogVerbose(@"RemoveResult init");

    // 内部变量初始化
    self.deletedSucess = NO;
    self.last = NO;

    return self;
}

@end


//////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
//////////////////////////////////////////////////////////////////////////////////////

@interface MessagesProvider ()
@property (nonatomic, strong) NSMutableSet<NSString *> *rb_skipSqliteLoadForEmptyBucketUids;
@property (nonatomic, strong) NSMutableSet<NSString *> *rb_bootstrappingSqliteLoadChatUids;
@end

@implementation MessagesProvider

+ (void)beginSyncKeyBulkMessageApply
{
    s_syncKeyBulkApplyDepth++;
}

+ (void)endSyncKeyBulkMessageApply
{
    if (s_syncKeyBulkApplyDepth > 0) {
        s_syncKeyBulkApplyDepth--;
    }
}


//-----------------------------------------------------------------------------------
#pragma mark - 仅内部可调用的方法

- (id)init
{
    if (![super init])
        return nil;

    // 内部变量初始化
    self.allFriendsMessages = [[NSMutableDictionary<NSString *, NSMutableArrayObservableEx *> alloc] init];
    self.allFriendsMessagesGhostForNoReceived = [[NSMutableDictionary<NSString *, JSQMessage *> alloc] init];
    self.rb_skipSqliteLoadForEmptyBucketUids = [NSMutableSet set];
    self.rb_bootstrappingSqliteLoadChatUids = [NSMutableSet set];

    return self;
}


//-----------------------------------------------------------------------------------
#pragma mark - 【1】外部可调用的方法

- (void)clearMessages:(NSString *)uid {
    [self.allFriendsMessages removeObjectForKey:uid];
    [self.allFriendsMessagesGhostForNoReceived removeObjectForKey:uid];
    if (uid.length > 0) {
        [self.rb_skipSqliteLoadForEmptyBucketUids removeObject:uid];
        [self.rb_bootstrappingSqliteLoadChatUids removeObject:uid];
    }
}

- (void)rb_prepareEmptyMessageBucketSkippingSqliteBootstrapForUid:(NSString *)uid
{
    if (uid.length == 0) {
        return;
    }
    [self.rb_skipSqliteLoadForEmptyBucketUids addObject:uid];
    NSMutableArrayObservableEx *bucket = [[NSMutableArrayObservableEx alloc] init];
    [self.allFriendsMessages setObject:bucket forKey:uid];
}

/**
 * 加载更多历史消息（用于聊天界面上下拉加载更新历史记录功能或者搜索聊天记录功能里从结果中点击进入聊天界面时在当前分页机制下需要将该条消息以及它之后的消息加载进来）。
 *
 * @param afterAndfp 载入消息的额外条件（当前用于搜索消息结果中查看某条消息时），即只加载这条消息之后的消息（包含该条消息自身），这个条件是fp指纹码，当为 nil时表示本条件不生效
 * @param limit YES表示只加载一页，否则加载所有的查询结果
 */
- (NSMutableArrayObservableEx *) loadMoreMessages:(NSString *)uid afterAndFingerPrint:(NSString *)afterAndfp limit:(BOOL)limit complete:(void (^)(BOOL sucess))complete
{
    NSMutableArrayObservableEx *someoneMessages = [self.allFriendsMessages objectForKey:uid];//self.allFriendsMessages;
    if(someoneMessages == nil)
    {
        // 首次使用时先实例化一个数据结构
        someoneMessages = [[NSMutableArrayObservableEx alloc] init];
    }
    
    NSString *beforeFingerPrint = nil;
    long beforeDatetime = 0;
    
    if([someoneMessages getDataList].count > 0) {
        // 当前已载入消息中的最前面的这条消息
        JSQMessage *firstMessage = (JSQMessage *)[someoneMessages get:0];
        beforeFingerPrint = firstMessage.fingerPrintOfProtocal;
        // 如果指纹码不存在，则取时间
        if(!beforeFingerPrint) {
            // 与 chat_msg.date 列一致：Java 毫秒（旧代码曾用秒，导致分页条件与库内毫秒不一致）
            beforeDatetime = (long)[TimeTool javaMillisFromNSDate:firstMessage.date];
        }
    }
    
    // 在此时机下可能需要做其它事情，比如把之前存储在本地的聊天记录先放进来（读取一页该条消息之前的消息，也就是before这条消息的这些消息）
    [self loadHistory:someoneMessages forUid:uid afterAndFingerPrint:afterAndfp beforeFingerPrint:beforeFingerPrint beforeDatetime:beforeDatetime limit:limit complete:complete];
    // 把数据结构放入所集合
    [self.allFriendsMessages setObject:someoneMessages forKey:uid];
    
    return someoneMessages;//[super.allFriendsMessages objectForKey:gid];
}

- (void)trimMessageWindowToMaxCount:(NSUInteger)maxCount forUid:(NSString *)uid
{
    [self trimMessageWindowToMaxCount:maxCount forUid:uid trimNewestFirst:NO];
}

- (void)trimMessageWindowToMaxCount:(NSUInteger)maxCount forUid:(NSString *)uid trimNewestFirst:(BOOL)trimNewestFirst
{
    if (uid.length == 0 || maxCount == 0) return;
    NSMutableArrayObservableEx *list = [self.allFriendsMessages objectForKey:uid];
    if (list == nil) return;
    NSUInteger count = [list getDataList].count;
    if (count <= maxCount) return;
    NSUInteger toRemove = count - maxCount;
    if (!trimNewestFirst) {
        for (NSUInteger i = 0; i < toRemove; i++) {
            [list remove:0 needNotify:NO];
        }
    } else {
        for (NSUInteger i = 0; i < toRemove; i++) {
            NSUInteger n = [list getDataList].count;
            if (n == 0) break;
            [list remove:n - 1 needNotify:NO];
        }
    }
    // 不向观察者发 notify：extra=nil 时 ChatRoot 会走 finishReceivingMessage(forceDontScroll)，整表 reload 但不滚到底，
    // 用户会卡在错误 contentOffset，表现为「列表底部不是最新消息」。裁剪须与 rb_sortAndTrimMessageList /
    // completeLoadMoreHistory 等同层逻辑里的 reloadData + scroll 策略绑定，此处仅改内存数组。
}

- (void)putMessage:(NSString *)uid withData:(JSQMessage *)me
{
    DDLogDebug(@"[调用的是MessagesProvider.putMessage(uid=%@)方法]", uid);

    NSMutableArrayObservableEx *someoneMessages = [self getMessages:uid];
    // 快照枚举：SyncKey/会话等多路径可能重入 putMessage，避免对 NSMutableArray 边遍历边 add 触发 mutation exception
    NSArray *dataList = [[someoneMessages getDataList] copy];
    
    // ========== 去重1：fingerPrint ==========
    if (me.fingerPrintOfProtocal != nil && me.fingerPrintOfProtocal.length > 0) {
        for (JSQMessage *existingMsg in dataList) {
            if (RBFingerprintStringsEqual(existingMsg.fingerPrintOfProtocal, me.fingerPrintOfProtocal)) {
                DDLogDebug(@"[MessagesProvider] 消息已存在（fingerPrint=%@），跳过重复添加", me.fingerPrintOfProtocal);
                return;
            }
        }
    }

    // ========== 去重1b：同会话内同一毫秒 + 同一发送者 + 同一内容 + 同一类型（接收方/群已由 uid 限定）；覆盖异 fp 的重复投递 ==========
    // 发出消息每条均有唯一 fp（去重1）；快发同文易同一毫秒，再走 1b 会把后续合法发出整条 return，表现为无气泡。
    BOOL skipMillisDedupForOutgoingWithFp = [me isOutgoing] && me.fingerPrintOfProtocal.length > 0;
    if (!skipMillisDedupForOutgoingWithFp) {
        NSString *mscNew = [MessagesProvider dedupKeyMillisSenderContentType:me];
        if (mscNew.length > 0) {
            for (JSQMessage *existingMsg in dataList) {
                if (existingMsg == nil) continue;
                NSString *mscEx = [MessagesProvider dedupKeyMillisSenderContentType:existingMsg];
                if (mscEx.length > 0 && [mscEx isEqualToString:mscNew]) {
                    DDLogDebug(@"[MessagesProvider] 消息已存在（毫秒+发送者+内容+类型），跳过 uid=%@", uid);
                    return;
                }
            }
        }
    }

    // ========== 发出消息：仅当列表中已有「历史 HTTP 行」（含 history_time2 解析并打标）且 dedup 键一致时跳过，避免 IM 回显与漫游各一条 ==========
    if ([me isOutgoing]) {
        NSString *dk = [MessagesProvider dedupKeyForMessage:me];
        NSString *lk = (me.fingerPrintOfProtocal.length == 0) ? [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:me] : nil;
        for (JSQMessage *existingMsg in dataList) {
            if (existingMsg == nil || !RBJSQMessageHasHttpHistoryRowMarker(existingMsg)) continue;
            NSString *ek = [MessagesProvider dedupKeyForMessage:existingMsg];
            if (dk.length > 0 && ek.length > 0 && [ek isEqualToString:dk]) {
                DDLogDebug(@"[MessagesProvider] 发出消息与历史接口行重复（dedupKey），跳过 uid=%@", uid);
                return;
            }
            if (lk.length > 0 && existingMsg.fingerPrintOfProtocal.length == 0) {
                NSString *elk = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:existingMsg];
                if (elk.length > 0 && [elk isEqualToString:lk]) {
                    DDLogDebug(@"[MessagesProvider] 发出消息与历史接口行重复（dedupKeyLoose），跳过 uid=%@", uid);
                    return;
                }
            }
        }
    }
    
    // 原「去重2」5 秒窗口 + 同发送者同内容会把对方连发的合法短消息整条吞掉（聊天页偶发「收不到」），已移除；无 fp 时仍由下方 dedupKey / dedupKeyLoose 与毫秒键 1b 兜底重复投递。

    // ========== 去重3：与 loadHistory/roaming 一致的 dedupKey 全表扫描（仅非发出），避免近邻漏检 ==========
    if (![me isOutgoing]) {
        NSString *dk = [MessagesProvider dedupKeyForMessage:me];
        if (dk.length > 0) {
            for (JSQMessage *existingMsg in dataList) {
                if (existingMsg == nil) continue;
                NSString *ek = [MessagesProvider dedupKeyForMessage:existingMsg];
                if (ek.length > 0 && [ek isEqualToString:dk]) {
                    DDLogDebug(@"[MessagesProvider] dedupKey 已存在，跳过 uid=%@", uid);
                    return;
                }
            }
        }
        // ========== 去重4：无 fp 时秒级复合键（漫游/HTTP 与 IM 路径毫秒不一致时仍视为同一条）==========
        if (me.fingerPrintOfProtocal.length == 0) {
            NSString *lk = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:me];
            if (lk.length > 0) {
                for (JSQMessage *existingMsg in dataList) {
                    if (existingMsg == nil || existingMsg.fingerPrintOfProtocal.length > 0) continue;
                    NSString *elk = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:existingMsg];
                    if (elk.length > 0 && [elk isEqualToString:lk]) {
                        DDLogDebug(@"[MessagesProvider] dedupKeyLoose 已存在，跳过 uid=%@", uid);
                        return;
                    }
                }
            }
        }
    }
    
    // 以下代码用于判断并实现仿微信的只显示2分钟内聊天消息的时间标识（参考资料：http://www.52im.net/thread-3008-1-1.html#40）
    JSQMessage *previousMessage = nil;
    int messagesSize = (int)[[someoneMessages getDataList] count];
    if(messagesSize > 0) {
        previousMessage = (JSQMessage *)[someoneMessages get:messagesSize - 1];
    }
    [MessagesProvider setMessageShowTopTime:me previous:previousMessage];
    
    // 将此新消息对象放入数据模型(列表)；SyncKey 大批量入库时不逐条通知观察者，避免主线程卡顿
    [someoneMessages add:me needNotify:!RBMessagesProviderInSyncKeyBulkApply()];

    // 【本代码用于聊天消息质量保证机制的表现层机制】将此发出的消息对象引用也放入一份引用到“尚未应答的消息列表”中
    if(me.fingerPrintOfProtocal != nil)
    {
        [self.allFriendsMessagesGhostForNoReceived setObject:me forKey:me.fingerPrintOfProtocal];
        NSLog(@"[MessagesProvider]【QoS------------A0】fingerPrint=%@已发出，正在放入ghost列表中哦(size=%lu).", me.fingerPrintOfProtocal, (unsigned long)[self.allFriendsMessagesGhostForNoReceived count]);
    }

    // 消息的本地存储
    [self saveHistory:uid withData:me];
}

// 获得对应聊天对象的聊天消息列表（首次创建 bucket 时同步从 SQLite 加载一页，与初始对比版一致）
- (NSMutableArrayObservableEx *) getMessages:(NSString *)uid
{
    NSMutableArrayObservableEx *someoneMessages = [self.allFriendsMessages objectForKey:uid];
    if (someoneMessages == nil) {
        someoneMessages = [[NSMutableArrayObservableEx alloc] init];
        [self.allFriendsMessages setObject:someoneMessages forKey:uid];
        NSLog(@"[ChatEnter][MessagesProvider] uid=%@ bucket=nil -> create + bootstrap", uid ?: @"");
        if (uid.length > 0 && ![self.rb_skipSqliteLoadForEmptyBucketUids containsObject:uid]) {
            [self rb_scheduleLatestPageBootstrapIfNeededForChatUid:uid];
        } else if (uid.length > 0) {
            [self.rb_skipSqliteLoadForEmptyBucketUids removeObject:uid];
        }
    } else if ([[someoneMessages getDataList] count] == 0) {
        NSLog(@"[ChatEnter][MessagesProvider] uid=%@ bucketExistsButEmpty -> bootstrap", uid ?: @"");
        // bucket 已存在但内存仍为空时（例如列表预取/其它路径先放了空数组，或首次 load 时 GapHeal 尚未落库），须再从 SQLite 拉一次；否则首进聊天页一直空白，退出再进才命中。
        // 例外：搜索跳转已 `rb_prepareEmptyMessageBucketSkippingSqliteBootstrapForUid`，紧接着用 26-8 片段 putMessage 装配，禁止此处误读「库内最新一页」冲掉锚点上下文。
        if ([self.rb_skipSqliteLoadForEmptyBucketUids containsObject:uid]) {
            [self.rb_skipSqliteLoadForEmptyBucketUids removeObject:uid];
        } else {
            if (uid.length > 0) {
                [self rb_scheduleLatestPageBootstrapIfNeededForChatUid:uid];
            }
        }
    } else {
        NSLog(@"[ChatEnter][MessagesProvider] uid=%@ reuseMemoryBucket count=%ld",
              uid ?: @"",
              (long)[[someoneMessages getDataList] count]);
    }
    return someoneMessages;
}

- (BOOL)rb_isSqliteBootstrapInProgressForChatUid:(NSString *)uid
{
    if (uid.length == 0) {
        return NO;
    }
    @synchronized (self.rb_bootstrappingSqliteLoadChatUids) {
        return [self.rb_bootstrappingSqliteLoadChatUids containsObject:uid];
    }
}

// 按指纹码查找对应用户的消息对象。
- (JSQMessage *)findMessageByFingerPrint:(NSString *)uid fp:(NSString *)fingerPrint
{
    FindResult *r = [self findMessageByFingerPrintX:uid fp:fingerPrint];
    if(r != nil)
        return r.message;
    return nil;
}

// 按指纹码查找对应用户的消息对象所处索引位置。
- (int)findIndexByFingerPrint:(NSString *)uid fp:(NSString *)fingerPrint
{
    FindResult *r = [self findMessageByFingerPrintX:uid fp:fingerPrint];
    if(r != nil)
        return r.index;
    return -1;
}

// 按指纹码查找对应用户的消息对象和消息对象索引位置。
- (FindResult *)findMessageByFingerPrintX:(NSString *)uid fp:(NSString *)fingerPrint
{
    if(fingerPrint != nil) {
        NSMutableArrayObservableEx *someoneMessages = [self.allFriendsMessages objectForKey:uid];
        if (someoneMessages != nil && [[someoneMessages getDataList] count] > 0) {
            for(int i = 0; i < [[someoneMessages getDataList] count]; i++ ){
//          for (JSQMessage *m in [someoneMessages getDataList]) {
                JSQMessage *m = [[someoneMessages getDataList] objectAtIndex:i];
                // 如果找到就跳出循环
                if (RBFingerprintStringsEqual(fingerPrint, m.fingerPrintOfProtocal)){
                    FindResult *result = [[FindResult alloc] init];
                    result.message = m;
                    result.index = i;
                    return result;
                }
            }
        }
    }
    
    return nil;
}

// 按引用指纹码查找所有引用了原消息的消息对象（目前用于消息"撤回"功能时）
- (NSArray<JSQMessage *> *) findMessagesByQuoteFingerPrint:(NSString *)uid beQuotedFp:(NSString *)beQuotedFingerPrint
{
    NSMutableArray<JSQMessage *> *result = [NSMutableArray array];
    if(beQuotedFingerPrint != nil) {
        NSMutableArrayObservableEx *someoneMessages = [self.allFriendsMessages objectForKey:uid];
        if (someoneMessages != nil && [[someoneMessages getDataList] count] > 0) {
            for (JSQMessage *m in [[someoneMessages getDataList] copy]) {
                if ([beQuotedFingerPrint isEqualToString:m.quote_fp]){
                    [result addObject:m];
                }
            }
        }
    }

    return result;
}

// 删除指定好友的消息指纹码对应的消息。
- (RemoveResult *)removeMessage:(NSString *)friendUid fp:(NSString *)fingerPrint isDeleteLocalDatas:(BOOL)deleteLocalData
{
    int index = [self findIndexByFingerPrint:friendUid fp:fingerPrint];
    RemoveResult *removeResult = [self removeMessage:friendUid index:index];
    // 内存中的消息对象删除成功后，才尝试去删除本地sqlite中的历史记录
    if(removeResult.deletedSucess){
        if(deleteLocalData) {
            [MyDataBase inDatabase:^(FMDatabase *db) {
                [self deleteHistoryWithFp:db fp:fingerPrint];
            }];
        }
    }
    else{
        NSLog(@"<%@:removeMessage:fp:isDeleteLocalDatas> removeResult.deletedSucess? %d", [self class], removeResult.deletedSucess);
    }
    
    return removeResult;
}

// 从内存模型中删除指定好友的指定索引处聊天消息对象（注：本方法仅删除内存中的消息对象哦）。
- (RemoveResult *)removeMessage:(NSString *)friendUid index:(int)index
{
    @synchronized(self) {
        RemoveResult *result = [[RemoveResult alloc] init];
            @try {
            if (index >= 0) {
                NSMutableArrayObservableEx *someoneMessages = [self.allFriendsMessages objectForKey:friendUid];
    //           ArrayListObservable<Message> someoneMessages = allFriendsMessages.get(friendUid);
                int dataListCount = (int)[[someoneMessages getDataList] count];
                // 索引合法性检查
                if (someoneMessages != nil && dataListCount > 0 && index <= ((dataListCount - 1))) {

                    // 当前被删除的消息是否是消息数组中的最后一个
                    BOOL isLast = (index == (dataListCount - 1));

                    // 被删除消息的前一条消息对象引用（用于当删除的是最后一条消息时，应用层可以及时更新首
                    // 页"消息"列表中的显示，不然显示的还是已被删除的消息内容，ui上看起来就很bug了！）
                    JSQMessage *previousRemovedMessage = nil;
                    // 被删除消息的后一条消息对象引用（用于当删除的消息显示消息时间时，应用层可以设置后一条
                    // 消息上显示时间，不然本条消息被删后，聊天界面上依赖于此消息上的显示时间的，就没有时间显示了）
                    JSQMessage *behingRemoveMessage = nil;
                    if (isLast) {
                        int previousRemovedIndex = index - 1;//dataListCount - 2;// 减1是最后一条消息，减2就是被删除前的倒数第2条
                        // 索引合法性检查
                        if (previousRemovedIndex >= 0) {
                            previousRemovedMessage = (JSQMessage *)[someoneMessages get:previousRemovedIndex];
                        }
                    } else {
                        int behingRemovedIndex = index + 1;
                        // 索引合法性检查
                        if (behingRemovedIndex <= (dataListCount - 1)) {
                            behingRemoveMessage = (JSQMessage *)[someoneMessages get:behingRemovedIndex];
                        }
                    }

                    JSQMessage *beRemoved = (JSQMessage *)[someoneMessages remove:index needNotify:YES];
                    // 删除成功
                    if (beRemoved != nil) {
                        // 删除结果信息
                        result.deletedSucess = YES;
                        result.deletedMessage = beRemoved;
                        // 被删除掉的索引是不是数据的最后一个
                        result.last = isLast;
                        result.previousDeletedMessage = previousRemovedMessage;
                        result.behindDeletedMessage = behingRemoveMessage;
                    }
                }
            } else {
                NSLog(@"<%@:removeMessage> 无效的index=%d，无法完成删除操作！", [self class], index);
            }
        
        }
        @catch (NSException *exception) {
            NSLog(@"<%@:removeMessage> with exception: %@", [self class], exception);
        }

        return result;
    }
}

// 删除指定人员的聊天记录（可同时指明是否也删除与该人员持久化存储在本地sqlite中的记录）。
- (void) removeMessages:(NSString *)uid isDeleteLocalDatas:(BOOL)deleteLocalDatas db:(FMDatabase *)db notify:(BOOL)notifyObserver
{
    // 先清除内存中的消息缓存哦（不然在重启app前，老的消息还是在缓存里的）
    NSMutableArrayObservableEx *someoneMessages = [self.allFriendsMessages objectForKey:uid];
    if(someoneMessages != nil)
        [someoneMessages clear:notifyObserver];

    // 再删除本地sqlite中的存储（如果需要删除的话）
    if(deleteLocalDatas) {
        if(db == nil){
            [MyDataBase inDatabase:^(FMDatabase *db) {
                [self deleteHistory:db uid:uid];
            }];
        } else {
            [self deleteHistory:db uid:uid];
        }
    }
}

- (void)notifyAllObserver
{
    for (NSString *key in self.allFriendsMessages) {
        NSMutableArrayObservableEx *aol = [self.allFriendsMessages objectForKey:key];
        if(aol != nil) {
            // 注意：因是批量处理，这里就没法指明通知的是关于哪个消息的更新哦
            [aol notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
        }
    }
}

- (void)notifyObserversForChatUid:(NSString *)uid
{
    if (uid.length == 0) {
        return;
    }
    NSMutableArrayObservableEx *aol = [self.allFriendsMessages objectForKey:uid];
    if (aol != nil) {
        [aol notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
    }
}

- (void)rb_notifyObserversForChatUid:(NSString *)uid extra:(NSObject *)extraData
{
    if (uid.length == 0) {
        return;
    }
    NSMutableArrayObservableEx *aol = [self.allFriendsMessages objectForKey:uid];
    if (aol != nil) {
        [aol notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:extraData];
    }
}

- (BOOL)rb_markSqliteBootstrapStartedForChatUid:(NSString *)uid
{
    if (uid.length == 0) {
        return NO;
    }
    @synchronized (self.rb_bootstrappingSqliteLoadChatUids) {
        if ([self.rb_bootstrappingSqliteLoadChatUids containsObject:uid]) {
            return NO;
        }
        [self.rb_bootstrappingSqliteLoadChatUids addObject:uid];
        return YES;
    }
}

- (void)rb_markSqliteBootstrapFinishedForChatUid:(NSString *)uid
{
    if (uid.length == 0) {
        return;
    }
    @synchronized (self.rb_bootstrappingSqliteLoadChatUids) {
        [self.rb_bootstrappingSqliteLoadChatUids removeObject:uid];
    }
}

- (void)rb_scheduleLatestPageBootstrapIfNeededForChatUid:(NSString *)uid
{
    if (![self rb_markSqliteBootstrapStartedForChatUid:uid]) {
        NSLog(@"[ChatEnter][SQLiteBootstrap] uid=%@ skip duplicate bootstrap request", uid ?: @"");
        return;
    }
    NSLog(@"[ChatEnter][SQLiteBootstrap] uid=%@ schedule bootstrap", uid ?: @"");
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        [sself rb_reloadLatestPageFromDatabaseAndNotifyForChatUid:uid];
    });
}

- (void)rb_reloadLatestPageFromDatabaseAndNotifyForChatUid:(NSString *)uid
{
    if (uid.length == 0) {
        return;
    }
    CFAbsoluteTime beginTime = CFAbsoluteTimeGetCurrent();
    NSMutableArrayObservableEx *bucket = [self.allFriendsMessages objectForKey:uid];
    if (bucket == nil) {
        [self rb_markSqliteBootstrapFinishedForChatUid:uid];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self loadHistory:bucket forUid:uid afterAndFingerPrint:nil beforeFingerPrint:nil beforeDatetime:0 limit:YES complete:^(__unused BOOL success) {
        MessagesProvider *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        [strongSelf rb_markSqliteBootstrapFinishedForChatUid:uid];
        if (!success) {
            NSLog(@"[ChatEnter][SQLiteBootstrap] uid=%@ failed cost=%.2fms",
                  uid ?: @"",
                  (CFAbsoluteTimeGetCurrent() - beginTime) * 1000.0);
            return;
        }
        NSLog(@"[ChatEnter][SQLiteBootstrap] uid=%@ success count=%ld cost=%.2fms",
              uid ?: @"",
              (long)[[bucket getDataList] count],
              (CFAbsoluteTimeGetCurrent() - beginTime) * 1000.0);
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf rb_notifyObserversForChatUid:uid extra:RBChatObserverExtraMake(RBChatObserverReasonSqliteBootstrap)];
        });
    }];
}

/// 发出消息 QoS 送达：仅刷新该行 UI（sendStatus 已在内存更新；UNKNOW+nil 走 finishReceiving 时若条数未变可能不落 reload，表现为一直转圈）。
- (void)rb_notifyOutgoingRowRefreshForUid:(NSString *)uid message:(JSQMessage *)msg
{
    if (uid.length == 0 || msg == nil) {
        return;
    }
    NSMutableArrayObservableEx *aol = [self.allFriendsMessages objectForKey:uid];
    if (aol != nil) {
        [aol notifyObservers:UpdateTypeToObserverSET whithExtra:msg];
    }
}

// 为当前的消息对象，设置是否显示消息时间标识。
// 仅按「天数」分组：只有换日（或首条）时显示时间条，不再按多少分钟弹一次；气泡内已有小时级别时间，分组只做今天/昨天/周几/月日即可。
+ (void)setMessageShowTopTime:(JSQMessage *)theMessage  previous:(JSQMessage *)previousMessage
{
    if (theMessage == nil) return;
    if (previousMessage == nil) {
        theMessage.showTopTime = YES;
        return;
    }
    NSDate *d1 = theMessage.date;
    NSDate *d0 = previousMessage.date;
    if (d1 == nil || d0 == nil) return;
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *c1 = [cal components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:d1];
    NSDateComponents *c0 = [cal components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:d0];
    BOOL sameDay = (c1.year == c0.year && c1.month == c0.month && c1.day == c0.day);
    if (!sameDay)
        theMessage.showTopTime = YES;
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 【2】有关sqlite持久化存储的处理方法

// 将消息保存到本地数据库中作为历史聊天消息保存下来.
// 使用异步写库，避免在 main runloop 上同步等 DB（如 SyncKey 拉取回调在主线程）导致 runloop hang。
- (void)saveHistory:(NSString *)uid withData:(JSQMessage *)me
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee == nil)
        return;
    NSString *acountUid = [localRee.user_uid copy];
    JSQMessage *meCopy = me; // 仅在本方法及 block 内读属性，不跨线程写

    dispatch_async(s_saveHistoryQueue(), ^{
        [MyDataBase inDatabase:^(FMDatabase *db) {
            // 使用 upsert：与登录预拉/漫游同一 fp 时合并为一行，避免「在线一条、下次登录再一条」
            BOOL sucess = [[MyDataBase sharedInstance].chatHistoryTable upsertHistoryMergeFromServer:db acountUidOfOwner:acountUid uid:uid cme:meCopy didInsert:NULL didUpdate:NULL];
            DDLogDebug(@"[sqlite-MessagesProvider] 将uid=%@的消息写入sqlite(upsert)完成，sucess？%d", uid, sucess);
            if(!sucess)
                [MyDataBase printErrorForDebug:db tag:@"MessagesProvider-saveToSqlite"];
        }];
    });
}

/// 收到送达 ack 后把该条消息的 send_status 写回 DB，避免再次进入会话从 DB 加载仍为 SNEDING 导致一直转圈
- (void)updateSendStatusForFp:(NSString *)fp sendStatus:(int)sendStatus
{
    if (!fp.length) return;
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if (!localRee.user_uid.length) return;
    [MyDataBase inDatabase:^(FMDatabase *db) {
        [[MyDataBase sharedInstance].chatHistoryTable updateSendStatus:db acountUidOfOwner:localRee.user_uid fp:fp sendStatus:sendStatus];
    }];
}

- (NSArray<NSString *> *)rb_localSenderIdsForSendStatusPersistence
{
    NSMutableOrderedSet<NSString *> *ids = [NSMutableOrderedSet orderedSet];
    NSString *sdkUid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
    if (sdkUid.length > 0) {
        [ids addObject:sdkUid];
    }
    NSString *imu = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (imu.length > 0) {
        [ids addObject:imu];
    }
    return ids.array ?: @[];
}

- (void)rb_markStaleOutgoingSendingMessagesAsFailedForUid:(NSString *)uid
{
    if (uid.length == 0 || [self isKindOfClass:[GroupsMessagesProvider class]]) {
        return;
    }
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if (!localRee.user_uid.length) {
        return;
    }
    NSArray<NSString *> *localSenderIds = [self rb_localSenderIdsForSendStatusPersistence];
    if (localSenderIds.count == 0) {
        return;
    }
    [MyDataBase inDatabase:^(FMDatabase *db) {
        [[MyDataBase sharedInstance].chatHistoryTable markStaleOutgoingSendingMessagesAsFailed:db
                                                                               acountUidOfOwner:localRee.user_uid
                                                                                            uid:uid
                                                                                 localSenderIds:localSenderIds];
    }];
}

- (BOOL)markOutgoingMessageDeliveredForFp:(NSString *)fingerPrint preferredPeerUid:(NSString *)preferredPeerUid
{
    if (fingerPrint.length == 0) {
        return NO;
    }
    JSQMessage *target = nil;
    NSString *foundUid = nil;
    if (preferredPeerUid.length > 0) {
        target = [self findMessageByFingerPrint:preferredPeerUid fp:fingerPrint];
        if (target != nil) {
            foundUid = preferredPeerUid;
        }
    }
    if (target == nil) {
        for (NSString *uid in self.allFriendsMessages) {
            JSQMessage *m = [self findMessageByFingerPrint:uid fp:fingerPrint];
            if (m != nil) {
                target = m;
                foundUid = uid;
                break;
            }
        }
    }
    if (target == nil || ![target isOutgoing]) {
        return NO;
    }

    [self.allFriendsMessagesGhostForNoReceived removeObjectForKey:fingerPrint];

    if (target.sendStatus == SendStatus_BE_RECEIVED) {
        if (foundUid.length > 0) {
            [self rb_notifyOutgoingRowRefreshForUid:foundUid message:target];
        }
        return YES;
    }

    target.sendStatus = SendStatus_BE_RECEIVED;
    [self updateSendStatusForFp:fingerPrint sendStatus:SendStatus_BE_RECEIVED];
    [[SendRetryManager sharedInstance] cancelRetryForFp:fingerPrint];

    if (foundUid.length > 0) {
        [self rb_notifyOutgoingRowRefreshForUid:foundUid message:target];
    } else {
        [self notifyAllObserver];
    }
    return YES;
}

- (BOOL)markOutgoingMessageFailedForFp:(NSString *)fingerPrint preferredPeerUid:(NSString *)preferredPeerUid
{
    if (fingerPrint.length == 0) {
        return NO;
    }
    JSQMessage *target = nil;
    NSString *foundUid = nil;
    if (preferredPeerUid.length > 0) {
        target = [self findMessageByFingerPrint:preferredPeerUid fp:fingerPrint];
        if (target != nil) {
            foundUid = preferredPeerUid;
        }
    }
    if (target == nil) {
        for (NSString *uid in self.allFriendsMessages) {
            JSQMessage *m = [self findMessageByFingerPrint:uid fp:fingerPrint];
            if (m != nil) {
                target = m;
                foundUid = uid;
                break;
            }
        }
    }
    if (target == nil || ![target isOutgoing]) {
        return NO;
    }

    [self.allFriendsMessagesGhostForNoReceived removeObjectForKey:fingerPrint];

    if (target.sendStatus != SendStatus_SEND_FAILD) {
        target.sendStatus = SendStatus_SEND_FAILD;
    }
    [self updateSendStatusForFp:fingerPrint sendStatus:SendStatus_SEND_FAILD];
    [[SendRetryManager sharedInstance] cancelRetryForFp:fingerPrint];

    if (foundUid.length > 0) {
        [self rb_notifyOutgoingRowRefreshForUid:foundUid message:target];
    } else {
        [self notifyAllObserver];
    }
    return YES;
}

- (NSString *)findPeerUidByMessageFingerPrint:(NSString *)fingerPrint
{
    if (fingerPrint.length == 0) {
        return nil;
    }
    for (NSString *uid in self.allFriendsMessages) {
        JSQMessage *m = [self findMessageByFingerPrint:uid fp:fingerPrint];
        if (m != nil) {
            return uid;
        }
    }
    return nil;
}

// 载入历史聊天记录（存放于本地数据库中的）.
- (void)loadHistory:(NSMutableArrayObservableEx *) messageArray forUid:(NSString *)uid afterAndFingerPrint:(NSString *)afterAndfp beforeFingerPrint:(NSString *)beforeFp beforeDatetime:(long)beforeDate limit:(BOOL)limit complete:(void (^)(BOOL sucess))complete
{
    if(messageArray != nil)
    {
        UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
        if(localRee == nil) {
            if(complete) {
                complete(NO);
            }
            return;
        }

        /// 仅以实际并入内存为准；DB 有行但全被去重时须返回 NO，否则会跳过漫游/大群 HTTP 更早一页
        __block BOOL mergedAnyFromSqlite = NO;

        [self rb_markStaleOutgoingSendingMessagesAsFailedForUid:uid];

        [MyDataBase inDatabase:^(FMDatabase *db) {

            BOOL tryDeleteOldSucess = [[MyDataBase sharedInstance].chatHistoryTable deleteOldHistory:db acountUidOfOwner:localRee.user_uid uid:uid];
            DDLogVerbose(@"[sqlite-MessagesProvider] 尝试删除与uid:%@的超出存储期限的老聊天消息完成，成功完成？%d", uid, tryDeleteOldSucess);
            if(!tryDeleteOldSucess)
                [MyDataBase printErrorForDebug:db tag:@"MessagesProvider-tryDeleteOldSucess"];

            // 从本地sqlite中读出历史聊天记录
            NSArray<JSQMessage *> *cachedChatMessageData = [[MyDataBase sharedInstance].chatHistoryTable findHistory:db acountUidOfOwner:localRee.user_uid uid:uid afterAndFingerPrint:afterAndfp beforeFingerPrint:beforeFp beforeDatetime:beforeDate limit:limit];// 返回的结果是按时间逆序的
            if(cachedChatMessageData == nil || [cachedChatMessageData count] == 0)
                [MyDataBase printErrorForDebug:db tag:@"MessagesProvider-findHistory"];

            // 把历史聊天记录放到数据结构中
            if(cachedChatMessageData != nil && [cachedChatMessageData count] > 0)
            {
                // ====== START
                // 以下代码用于判断并实现仿微信的只显示5分钟内聊天消息的时间标识
                // （参考资料：http://www.52im.net/thread-3008-1-1.html#40）
                // 注意：因当前cachedChatMessageData中按消息时间的逆序队列，所以本次遍历是逆序的哦
                for(int i = (int)[cachedChatMessageData count] - 1; i >= 0; i--)
                {
                    JSQMessage *theMessage =[ cachedChatMessageData objectAtIndex:i];
    
                    JSQMessage *previousMessage = nil;
                    // 时间倒序第一个，则它的前一个消息是不存在的（它自已就是绝对时间的"第一条消息"）
                    if(i == [cachedChatMessageData count] - 1)
                        previousMessage = nil;
                    // 否则取列表中的下一个单元，就是它的绝对时间的"上一条消息"
                    else
                        previousMessage = [cachedChatMessageData objectAtIndex:(i + 1)];
                    
                    // 设置标识
                    [MessagesProvider setMessageShowTopTime:theMessage previous:previousMessage];
                }
                // ====== END
                
                // 构建当前内存中已有消息的去重键（避免先 putMessage 再 loadHistory 导致最后一条重复）
                NSMutableSet<NSString *> *existingKeys = [NSMutableSet set];
                for (JSQMessage *existing in [[messageArray getDataList] copy]) {
                    NSString *pk = [MessagesProvider dedupKeyForMessage:existing];
                    if (pk.length > 0) [existingKeys addObject:pk];
                    NSString *pl = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:existing];
                    if (pl.length > 0) [existingKeys addObject:pl];
                    NSString *pm = [MessagesProvider dedupKeyMillisSenderContentType:existing];
                    if (pm.length > 0) [existingKeys addObject:pm];
                }
                // 把历史聊天记录放到数据结构中
                for (JSQMessage *cme in cachedChatMessageData)
                {
                    NSString *key = [MessagesProvider dedupKeyForMessage:cme];
                    NSString *loose = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:cme];
                    NSString *msc = [MessagesProvider dedupKeyMillisSenderContentType:cme];
                    BOOL dup = (key.length > 0 && [existingKeys containsObject:key])
                        || (loose.length > 0 && [existingKeys containsObject:loose])
                        || (msc.length > 0 && [existingKeys containsObject:msc]);
                    if (dup) {
                        DDLogVerbose(@"[MessagesProvider-loadHistory] 消息已存在于内存（key=%@ loose=%@ msc=%@），跳过避免重复", key, loose, msc);
                        continue;
                    }
                    if (key.length > 0) [existingKeys addObject:key];
                    if (loose.length > 0) [existingKeys addObject:loose];
                    if (msc.length > 0) [existingKeys addObject:msc];
                    // 一直插入到列表首位置（因为取出的消息本就是按逆序排列的，那么此处永远往表首插就能保证插完后的消息是按时间顺序显示的）
                    [messageArray add:0 withObj:cme needNotify:NO];
                    mergedAnyFromSqlite = YES;
                }
                // 按 date（UTC 时间戳）升序重排，避免手机端与服务器/多端时区不一致时 DB 按 id 顺序与真实时间序错乱
                [MessagesProvider sortMessagesByDateAscending:messageArray];

                DDLogVerbose(@"[sqlite-MessagesProvider] 尝试载入与uid:%@的本地历史记录读取完成，读取的行数为：%ld", uid, [cachedChatMessageData count]);
            }
            else
            {
                DDLogVerbose(@"[sqlite-MessagesProvider] 尝试载入与uid:%@本地历史记录读取完成，但没有数据记录.", uid);
            }
        }];

        if(complete) {
            complete(mergedAnyFromSqlite);
        }
    }
    else
    {
        DDLogWarn(@"[sqlite-MessagesProvider] messageArray is nil!");
        if(complete) {
            complete(NO);
        }
    }
}

// 删除与指定好友的sqlite本地存储的聊天记录数据。
- (void)deleteHistory:(FMDatabase *)db uid:(NSString *)friendUid
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee != nil && friendUid != nil) {
        // 删除聊天记录
        BOOL sucess = [[MyDataBase sharedInstance].chatHistoryTable deleteHistory:db acountUidOfOwner:localRee.user_uid srcUid:friendUid];
        // 如果sqlite删除失败，则打出debug信息
        if(!sucess)
            [MyDataBase printErrorForDebug:db tag:@"MessagesProvider-deleteHistory(删除一对一聊天消息)"];
    }
}

// 删除指定指纹码对应的聊天记录数据。
- (void)deleteHistoryWithFp:(FMDatabase *)db fp:(NSString *)fpForMessage
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee != nil && fpForMessage != nil) {
        // 删除聊天记录
        BOOL sucess = [[MyDataBase sharedInstance].chatHistoryTable deleteHistoryWithFp:db acountUidOfOwner:localRee.user_uid fp:fpForMessage];
        // 如果sqlite删除失败，则打出debug信息
        if(!sucess)
            [MyDataBase printErrorForDebug:db tag:@"MessagesProvider-deleteHistoryWithFp(删除一对一聊天消息)"];
    }
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 【3】有关聊天消息质量保证机制的表现层的处理方法

- (void)friendReceivedMessage:(NSString *)fingerPrint
{
    if(fingerPrint != nil)
    {
        if([self.allFriendsMessagesGhostForNoReceived objectForKey:fingerPrint] != nil)
        {
            [self.allFriendsMessagesGhostForNoReceived removeObjectForKey:fingerPrint];
            NSLog(@"[MessagesProvider]【QoS------------R1】fingerPrint=%@已收到应答，已从ghost中删除(size=%lu)！"
                  , fingerPrint, (unsigned long)[self.allFriendsMessagesGhostForNoReceived count]);
        }
        else
        {
            NSLog(@"[MessagesProvider]【QoS------------R1】fingerPrint=%@应答包对应的包不在self.allFriendsMessagesGhostForNoReceived里了？！", fingerPrint);
        }
    }
}

- (NSMutableDictionary<NSString *, JSQMessage *> *)getAllFriendsMessagesGhostForNoReceived
{
    return self.allFriendsMessagesGhostForNoReceived;
}

- (void)sendToFriendFaild:(NSString *)fingerPrint
{
    if(fingerPrint != nil)
    {
        (void)[self markOutgoingMessageFailedForFp:fingerPrint preferredPeerUid:nil];
        NSLog(@"[MessagesProvider]【QoS------------R2】fingerPrint=%@未收到应答且超时了，已从ghost中删除(size=%lu)！"
              , fingerPrint, (unsigned long)[self.allFriendsMessagesGhostForNoReceived count]);
    }
}

//***************************************************** 有关聊天消息质量保证机制的表现层的处理方法 END

/// 用于 loadHistory 与内存列表去重的键：有 fp 用 fp，否则用 senderId|时间戳|内容前32字符（无 fp 如系统消息也可去重）
+ (NSString *)dedupKeyForMessage:(JSQMessage *)msg
{
    if (msg == nil) return nil;
    if (msg.fingerPrintOfProtocal.length > 0) {
        return [NSString stringWithFormat:@"fp:%@", msg.fingerPrintOfProtocal];
    }
    long long ts = (msg.date != nil) ? (long long)([msg.date timeIntervalSince1970] * 1000) : 0;
    NSString *prefix = (msg.text.length > 32) ? [msg.text substringToIndex:32] : (msg.text ?: @"");
    return [NSString stringWithFormat:@"ck:%@|%lld|%@", msg.senderId ?: @"", ts, prefix];
}

/// 无 fp 时用秒级时间 + msgType，与漫游/接口解析毫秒不一致时仍能合并同一条；有 fp 时与 fp 键一致便于集合统一查找
+ (NSString *)dedupKeyForMessageLooseNoFingerPrint:(JSQMessage *)msg
{
    if (msg == nil) return nil;
    if (msg.fingerPrintOfProtocal.length > 0) {
        return [NSString stringWithFormat:@"fp:%@", msg.fingerPrintOfProtocal];
    }
    long long tsSec = (msg.date != nil) ? (long long)[msg.date timeIntervalSince1970] : 0;
    NSString *prefix = (msg.text.length > 32) ? [msg.text substringToIndex:32] : (msg.text ?: @"");
    return [NSString stringWithFormat:@"ckl:%@|%lld|%@|%d", msg.senderId ?: @"", tsSec, prefix, (int)msg.msgType];
}

+ (NSString *)dedupKeyMillisSenderContentType:(JSQMessage *)msg
{
    if (msg == nil) return nil;
    long long ms = [TimeTool javaMillisFromNSDate:msg.date];
    NSString *body = msg.text ?: @"";
    return [NSString stringWithFormat:@"msc|%lld|%@|%@|%d", ms, msg.senderId ?: @"", body, (int)msg.msgType];
}

// 根据聊天类型返回对应的MessagesProvider实例引用
+ (MessagesProvider *)getMessageProiderInstance:(int)chatType {
    MessagesProvider *mp = nil;
    if(chatType == CHAT_TYPE_GROUP_CHAT) {
        mp = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
    } else {
        mp = [[IMClientManager sharedInstance] getMessagesProvider];
    }
    
    return mp;
}

#pragma mark - 按服务端顺序排序（断线重连后与漫游合并用）

static const void *kMPMessageSortOrderHintKey = &kMPMessageSortOrderHintKey;

/// 按 msg.date 升序排序会话消息列表，使顺序与服务端一致。同秒按原下标稳定排序。
+ (void)sortMessagesByDateAscending:(NSMutableArrayObservableEx *)someoneMessages
{
    if (someoneMessages == nil) return;
    NSMutableArray *arr = [someoneMessages getDataList];
    if (arr.count <= 1) return;
    for (NSUInteger i = 0; i < arr.count; i++) {
        objc_setAssociatedObject(arr[i], kMPMessageSortOrderHintKey, @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [arr sortUsingComparator:^NSComparisonResult(JSQMessage *a, JSQMessage *b) {
        NSDate *da = a.date;
        NSDate *db = b.date;
        if (da == nil && db == nil) {
            NSUInteger ia = [objc_getAssociatedObject(a, kMPMessageSortOrderHintKey) unsignedIntegerValue];
            NSUInteger ib = [objc_getAssociatedObject(b, kMPMessageSortOrderHintKey) unsignedIntegerValue];
            return (ia < ib) ? NSOrderedAscending : ((ia > ib) ? NSOrderedDescending : NSOrderedSame);
        }
        if (da == nil) return NSOrderedDescending;
        if (db == nil) return NSOrderedAscending;
        NSComparisonResult cr = [da compare:db];
        if (cr != NSOrderedSame) return cr;
        NSUInteger ia = [objc_getAssociatedObject(a, kMPMessageSortOrderHintKey) unsignedIntegerValue];
        NSUInteger ib = [objc_getAssociatedObject(b, kMPMessageSortOrderHintKey) unsignedIntegerValue];
        return (ia < ib) ? NSOrderedAscending : ((ia > ib) ? NSOrderedDescending : NSOrderedSame);
    }];
    for (id obj in arr) {
        objc_setAssociatedObject(obj, kMPMessageSortOrderHintKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (int i = 0; i < (int)arr.count; i++) {
        JSQMessage *prev = (i > 0) ? arr[i - 1] : nil;
        [MessagesProvider setMessageShowTopTime:arr[i] previous:prev];
    }
}

@end
