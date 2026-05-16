//telegram @wz662
#import "GroupsMessagesProvider.h"
#import "MyDataBase.h"
#import "GroupEntity.h"
#import "IMClientManager.h"
#import "ClientCoreSDK.h"
#import "TimeTool.h"
#import "BasicTool.h"
#import "MessagesProvider.h"

//** 自v10.0开始，由于已在聊天界面启用分页加载机制，自动清除逻辑或可弃用，日后可以考虑删除对应的实现代码吧！
///** BBS/群聊内存消息裁剪控制：消息数据结构的最大页数（此“页”非准确意义上的UI分页哦） */
//static int const MAX_PAGE = 5;
///** BBS/群聊内存消息裁剪控制：每页消息数 */
//static int const LINE_PER_PAGE = 10;

/// 群聊 saveHistory 异步写库队列，与单聊一致，避免主线程/网络回调线程同步 inDatabase（秒开/丝滑）
static dispatch_queue_t s_groupSaveHistoryQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        q = dispatch_queue_create("com.rainbowchat.group.saveHistory", DISPATCH_QUEUE_SERIAL);
    });
    return q;
}

/// 进入会话合并 DB 前调用：等待此前 `saveHistory` 异步写入全部完成，避免读库时最新一条尚未落库
void RBDrainGroupChatSaveHistoryQueue(void)
{
    dispatch_sync(s_groupSaveHistoryQueue(), ^{});
}

@implementation GroupsMessagesProvider

- (NSArray<NSString *> *)rb_groupLocalSenderIdsForSendStatusPersistence
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

- (void)updateSendStatusForFp:(NSString *)fp sendStatus:(int)sendStatus
{
    if (!fp.length) return;
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if (!localRee.user_uid.length) return;
    [MyDataBase inDatabase:^(FMDatabase *db) {
        [[MyDataBase sharedInstance].groupChatHistoryTable updateSendStatus:db acountUidOfOwner:localRee.user_uid fp:fp sendStatus:sendStatus];
    }];
}

- (void)trimMessageWindowToMaxCount:(NSUInteger)maxCount forUid:(NSString *)uid
{
    [super trimMessageWindowToMaxCount:maxCount forUid:uid];
}

- (void)trimMessageWindowToMaxCount:(NSUInteger)maxCount forUid:(NSString *)uid trimNewestFirst:(BOOL)trimNewestFirst
{
    [super trimMessageWindowToMaxCount:maxCount forUid:uid trimNewestFirst:trimNewestFirst];
}

///**
// * @Override - 用于聊天界面上下拉加载更新历史记录功能。
// *
// *@since 10.0
// */
//- (NSMutableArrayObservableEx *) loadMoreMessages:(NSString *)gid complete:(void (^)(BOOL sucess))complete
//{
//    NSMutableArrayObservableEx *someoneMessages = [super.allFriendsMessages objectForKey:gid];//self.allFriendsMessages;
//    if(someoneMessages == nil)
//    {
//        // 首次使用时先实例化一个数据结构
//        someoneMessages = [[NSMutableArrayObservableEx alloc] init];
//    }
//    
//    NSString *afterFingerPrint = nil;
//    long afterDatetime = 0;
//    if([someoneMessages getDataList].count > 0) {
//        JSQMessage *firstMessage = (JSQMessage *)[someoneMessages get:0];
//        afterFingerPrint = firstMessage.fingerPrintOfProtocal;
//        // 如果指纹码不存在，则取时间
//        if(!afterFingerPrint) {
//            afterDatetime = [TimeTool getIOSTimeStamp_l:firstMessage.date];
//        }
//    }
//    
//    // 在此时机下可能需要做其它事情，比如把之前存储在本地的聊天记录先放进来
//    [self loadHistory:someoneMessages forUid:gid afterFingerPrint:afterFingerPrint afterDatetime:afterDatetime complete:complete];
//    // 把数据结构放入所集合
//    [self.allFriendsMessages setObject:someoneMessages forKey:gid];
//    
//    return someoneMessages;//[super.allFriendsMessages objectForKey:gid];
//}

/**
 * @Override-重写父类方法
 *
 * 向数据模型中放入一条新消息。
 * <p>
 * 本方法Override了父类的方法后，因父类方法是针对一对一聊天的，
 * 所以原先的key=uid，在本类里的意义已经变成了key=gid了，但从
 * 数据模型的角度来说，都一样，因为就是个key而已，只是表达的意义
 * 不一样（一对一聊天是对"个人"、群聊是对"群"）。
 *
 * @param gid 群id
 * @param me 消息数据封装实体
 */
- (void)putMessage:(NSString *)gid withData:(JSQMessage *)me
{
    DDLogDebug(@"[调用的是GroupsMessagesProvider.putMessage方法]");

    // ★ 群聊多端/拉取去重：先按 fp；无 fp 时再按 sender+时间+类型+内容兜底（有 fp 的两条同内容合法消息勿在此处合并）
    NSMutableArrayObservableEx *list = [self getMessages:gid];
    NSArray *dataList = [[list getDataList] copy];
    for (NSInteger i = dataList.count - 1; i >= 0 && (dataList.count - 1 - i) < MIN(80, (NSInteger)dataList.count); i--) {
        JSQMessage *existing = dataList[i];
        if (existing == nil) continue;
        BOOL sameFp = (me.fingerPrintOfProtocal.length > 0 && existing.fingerPrintOfProtocal.length > 0
                        && [existing.fingerPrintOfProtocal isEqualToString:me.fingerPrintOfProtocal]);
        if (sameFp) {
            DDLogDebug(@"[GroupsMessagesProvider] 群聊消息已存在（fp=%@），跳过重复添加", me.fingerPrintOfProtocal);
            return;
        }
    }

    if ([me isOutgoing]) {
        NSString *dk = [MessagesProvider dedupKeyForMessage:me];
        NSString *lk = (me.fingerPrintOfProtocal.length == 0) ? [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:me] : nil;
        for (JSQMessage *existingMsg in dataList) {
            if (existingMsg == nil || !RBJSQMessageHasHttpHistoryRowMarker(existingMsg)) continue;
            NSString *ek = [MessagesProvider dedupKeyForMessage:existingMsg];
            if (dk.length > 0 && ek.length > 0 && [ek isEqualToString:dk]) {
                DDLogDebug(@"[GroupsMessagesProvider] 发出消息与历史接口行重复（dedupKey），跳过 gid=%@", gid);
                return;
            }
            if (lk.length > 0 && existingMsg.fingerPrintOfProtocal.length == 0) {
                NSString *elk = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:existingMsg];
                if (elk.length > 0 && [elk isEqualToString:lk]) {
                    DDLogDebug(@"[GroupsMessagesProvider] 发出消息与历史接口行重复（dedupKeyLoose），跳过 gid=%@", gid);
                    return;
                }
            }
        }
    }

    // 原 5 秒同发送者同内容窗口易误吞连发相同短消息，与单聊 MessagesProvider 一致已移除；无 fp 时仍由下方 dedupKey / dedupKeyLoose 与父类 putMessage 内逻辑兜底。

    if (![me isOutgoing]) {
        NSString *dk = [MessagesProvider dedupKeyForMessage:me];
        if (dk.length > 0) {
            for (JSQMessage *existingMsg in dataList) {
                if (existingMsg == nil) continue;
                NSString *ek = [MessagesProvider dedupKeyForMessage:existingMsg];
                if (ek.length > 0 && [ek isEqualToString:dk]) {
                    DDLogDebug(@"[GroupsMessagesProvider] dedupKey 已存在，跳过 gid=%@", gid);
                    return;
                }
            }
        }
        if (me.fingerPrintOfProtocal.length == 0) {
            NSString *lk = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:me];
            if (lk.length > 0) {
                for (JSQMessage *existingMsg in dataList) {
                    if (existingMsg == nil || existingMsg.fingerPrintOfProtocal.length > 0) continue;
                    NSString *elk = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:existingMsg];
                    if (elk.length > 0 && [elk isEqualToString:lk]) {
                        DDLogDebug(@"[GroupsMessagesProvider] dedupKeyLoose 已存在，跳过 gid=%@", gid);
                        return;
                    }
                }
            }
        }
    }

    // 注意：调用父类方法
    [super putMessage:gid withData:me];
}

/**
 * 按父指纹码查找对应用户的消息对象。
 *
 * @param gid 群id
 * @param fingerPrintOfParent 父消息的指纹码（每条群聊消息都是由消息发起者的这条消息扩散出来的，这条原始消息被称为"父"消息）
 * @return 找到则返回，否由返回null
 */
- (JSQMessage *)findMessageByParentFingerPrint:(NSString *)gid fp:(NSString *)fingerPrintOfParent
{
    JSQMessage *getIt = nil;
    if(fingerPrintOfParent != nil) {
        NSMutableArrayObservableEx *someoneMessages = [self getMessages:gid];
        if (someoneMessages != nil && [[someoneMessages getDataList] count] > 0) {
//          for(int i = 0; i < someoneMessages.getDataList().size(); i++ )
            for (JSQMessage *m in [[someoneMessages getDataList] copy]) {
                
                NSLog(@"》fingerPrintOfParent=%@, m.fingerPrintOfParent=%@", fingerPrintOfParent, m.fingerPrintOfParent);
                
                // 如果找到就跳出循环
                if ([fingerPrintOfParent isEqualToString:m.fingerPrintOfParent]){
                    getIt = m;
                    return getIt;
                }
            }
        }
    }
    
    return getIt;
}

/**
 * @Override - 重写父类方法，实现群组聊天的消息sqlite存储逻辑。
 *
 * 将消息保存到本地数据库中作为历史聊天消息保存下来.
 *
 * @param gid 要保存消息的所在群id
 * @param me 消息内容封装对象
 * @see #putMessage(Context, String, JSQMessage)
 */
- (void)saveHistory:(NSString *)gid withData:(JSQMessage *)me
{
    DDLogDebug(@"[GroupsMessagesProvider-saveHistory] 调用了子类而非父类MessagesProvider的方法！");

    // 世界频道作为特殊的群聊，产品定位是作为在线聊天室，所以不需要存储聊天记录到本地sqlite哦
    if(![GroupEntity isWorldChat:gid])
    {
        UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
        if (localRee == nil)
            return;

        NSString *uid = localRee.user_uid;
        JSQMessage *msgCopy = me;
        dispatch_async(s_groupSaveHistoryQueue(), ^{
            [MyDataBase inDatabase:^(FMDatabase *db) {
                BOOL sucess = [[MyDataBase sharedInstance].groupChatHistoryTable upsertHistoryMergeFromServer:db acountUidOfOwner:uid gid:gid cme:msgCopy didInsert:NULL didUpdate:NULL];
                DDLogDebug(@"[sqlite-GroupsMessagesProvider] 将gid=%@的消息写入sqlite(upsert)完成，sucess？%d", gid, sucess);
                if(!sucess)
                    [MyDataBase printErrorForDebug:db tag:@"GroupsMessagesProvider-saveHistory"];
            }];
        });
    }
}

/**
 * @Override - 重写父类方法，实现群组聊天的消息sqlite载入逻辑。
 *
 * 载入历史聊天记录（存放于本地数据库中的）.
 * <p>
 * 本方法目前是在首次{@link #getMessages(String)}时，被调用.
 *
 * @param messageArray
 * @see #getMessages(String)
 */
- (void)loadHistory:(NSMutableArrayObservableEx *) messageArray forUid:(NSString *)gid afterAndFingerPrint:(NSString *)afterAndfp  beforeFingerPrint:(NSString *)beforeFp beforeDatetime:(long)beforeDate limit:(BOOL)limit complete:(void (^)(BOOL sucess))complete
{
    DDLogVerbose(@"[GroupsMessagesProvider-loadHistory] 调用了子类而非父类MessagesProvider的方法！");

    if(messageArray != nil)
    {
        UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
        if(localRee == nil) {
            if(complete) {
                complete(NO);
            }
            return;
        }

        /// 仅以「实际并入内存的新行」为准；若 DB 有行但全被去重仍返回 NO，否则不会走 HTTP 更早一页（大群尤其明显）
        __block BOOL mergedAnyFromSqlite = NO;

        [MyDataBase inDatabase:^(FMDatabase *db) {
            NSArray<NSString *> *localSenderIds = [self rb_groupLocalSenderIdsForSendStatusPersistence];
            if (localSenderIds.count > 0) {
                [[MyDataBase sharedInstance].groupChatHistoryTable markStaleOutgoingSendingMessagesAsFailed:db
                                                                                      acountUidOfOwner:localRee.user_uid
                                                                                                   gid:gid
                                                                                        localSenderIds:localSenderIds];
            }

            BOOL tryDeleteOldSucess = [[MyDataBase sharedInstance].groupChatHistoryTable deleteOldHistory:db acountUidOfOwner:localRee.user_uid gid:gid];
            DDLogVerbose(@"[sqlite-MessagesProvider] 尝试删除群gid:%@的超出存储期限的老聊天消息完成，成功完成？%d", gid, tryDeleteOldSucess);
            if(!tryDeleteOldSucess)
                [MyDataBase printErrorForDebug:db tag:@"GroupsMessagesProvider-tryDeleteOldSucess"];

            // 从本地sqlite中读出历史聊天记录
            NSArray<JSQMessage *> *cachedChatMessageData = [[MyDataBase sharedInstance].groupChatHistoryTable findHistory:db acountUidOfOwner:localRee.user_uid gid:gid afterAndFingerPrint:afterAndfp beforeFingerPrint:beforeFp beforeDatetime:beforeDate limit:limit];// 返回的结果是按时间逆序的
            if(cachedChatMessageData == nil || [cachedChatMessageData count] == 0)
                [MyDataBase printErrorForDebug:db tag:@"GroupsMessagesProvider-findHistory"];

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
                
                // 与单聊 loadHistory 一致：fp / loose / 毫秒+发送者+内容，避免异 fp 或 DB 重复行插两条
                NSMutableSet<NSString *> *existingKeys = [NSMutableSet set];
                for (JSQMessage *existing in [[messageArray getDataList] copy]) {
                    NSString *pk = [MessagesProvider dedupKeyForMessage:existing];
                    if (pk.length > 0) [existingKeys addObject:pk];
                    NSString *pl = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:existing];
                    if (pl.length > 0) [existingKeys addObject:pl];
                    NSString *pm = [MessagesProvider dedupKeyMillisSenderContentType:existing];
                    if (pm.length > 0) [existingKeys addObject:pm];
                }
                for (JSQMessage *cme in cachedChatMessageData) {
                    NSString *key = [MessagesProvider dedupKeyForMessage:cme];
                    NSString *loose = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:cme];
                    NSString *msc = [MessagesProvider dedupKeyMillisSenderContentType:cme];
                    BOOL dup = (key.length > 0 && [existingKeys containsObject:key])
                        || (loose.length > 0 && [existingKeys containsObject:loose])
                        || (msc.length > 0 && [existingKeys containsObject:msc]);
                    if (dup) {
                        DDLogVerbose(@"[GroupsMessagesProvider-loadHistory] 消息已存在于内存，跳过避免重复");
                        continue;
                    }
                    if (key.length > 0) [existingKeys addObject:key];
                    if (loose.length > 0) [existingKeys addObject:loose];
                    if (msc.length > 0) [existingKeys addObject:msc];
                    [messageArray add:0 withObj:cme needNotify:NO];
                    mergedAnyFromSqlite = YES;
                }
                // 按 date（UTC 时间戳）升序重排，避免手机端与服务器/多端时区不一致时顺序错乱
                [MessagesProvider sortMessagesByDateAscending:messageArray];
                
                DDLogVerbose(@"[sqlite-GroupMessagesProvider] 尝试载入与群gid:%@的本地历史记录读取完成，读取的行数为：%ld", gid, (unsigned long)[cachedChatMessageData count]);
            }
            else
            {
                NSLog(@"[sqlite-GroupsMessagesProvider] 尝试载入群gid:%@本地历史记录读取完成，但没有数据记录.", gid);
            }
        }];

        if(complete) {
            complete(mergedAnyFromSqlite);
        }
    }
    else
    {
        NSLog(@"[sqlite-GroupsMessagesProvider] messageArray is nil!");
        if(complete) {
            complete(NO);
        }
    }
}

/**
 * @Override - 重写父类方法，实现群组聊天消息的sqlite删除逻辑。
 *
 * 删除与指定好友的sqlite本地存储的聊天记录数据。
 *
 * @param gid
 */
- (void)deleteHistory:(FMDatabase *)db uid:(NSString *)gid
{
    DDLogDebug(@"[GroupsMessagesProvider-deleteHistory] 调用了子类而非父类MessagesProvider的方法！");

    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee != nil) {
        // 删除群聊天记录(注意：群聊时，本局部变量srcUid里存放的是gid哦)
        BOOL sucess = [[MyDataBase sharedInstance].groupChatHistoryTable deleteHistory:db acountUidOfOwner:localRee.user_uid gid:gid];
        // 如果sqlite删除失败，则打出debug信息
        if(!sucess)
            [MyDataBase printErrorForDebug:db tag:@"GroupsMessagesProvider-deleteHistory(删除群聊天历史消息)"];
    }
}

/**
 * @Override - 重写父类方法，实现删除指定指纹码对应的聊天记录数据。
 *
 * 删除与指定好友的sqlite本地存储的聊天记录数据。
 *
 * @param fpForMessage 被删除消息的指纹码
 */
- (void)deleteHistoryWithFp:(FMDatabase *)db fp:(NSString *)fpForMessage
{
    DDLogDebug(@"[GroupsMessagesProvider-deleteHistoryWithFp] 调用了子类而非父类MessagesProvider的方法！");

    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee != nil) {
        // 删除群聊天记录(注意：群聊时，本局部变量srcUid里存放的是gid哦)
        BOOL sucess = [[MyDataBase sharedInstance].groupChatHistoryTable deleteHistoryWithFp:db acountUidOfOwner:localRee.user_uid fp:fpForMessage];
        // 如果sqlite删除失败，则打出debug信息
        if(!sucess)
            [MyDataBase printErrorForDebug:db tag:@"GroupsMessagesProvider-deleteHistoryWithFp(删除群聊天历史消息)"];
    }
}

///**
// * 指定群id的消息是否超过最大页数.
// *
// * @param groupId 群组id
// * @return true表示超过，否则没超过
// */
//- (BOOL) isOverflow:(NSString *)groupId
//{
//    // 总消息数 / 每页条数 再与允许的最大页数相比（比的是页数的好处就是溢出处理只在满页时处理而不是插一条处理一条，这样可以提升效率）
//    return ((int)([[[self getMessages:groupId] getDataList] count] / LINE_PER_PAGE)) > MAX_PAGE;
//}
//
///**
// * 移除多出来的老消息（从0索引开始至超过的消息数-1的索引所对应的元素）.
// * <p>
// * 否则理论上来说，随着数据模型中数据的无限积累的话，APP内存终有耗完的一刻。
// * <p>
// * 注意：本方法仅仅是用于裁剪内存数据模型，不需要处理sqlite里已经持久化的数据哦。
// *
// * @param groupId 群组id
// */
//- (void)trimForOverflow:(NSString *)groupId
//{
//    NSMutableArrayObservableEx *al = [self getMessages:groupId];
//
//    if(al == nil)
//        return;
//
//    DDLogDebug(@"【群聊】trim前的消息总数=%ld [1]", (unsigned long)[[al getDataList] count]);
////    Log.d(TAG, "【群聊】trim前的消息总数="+getMessages(context, groupId).getDataList().size()
////          +"[1]");
//
//    // 计算出需要移除的消息条数
//    long willToTrimCount = ([[al getDataList] count] - (MAX_PAGE * LINE_PER_PAGE));
//    if(willToTrimCount > 0)
//    {
//        //** 将越出的数据裁剪掉
//        // 移除列表中索引在 0（包括）和 willToTrimCount（不包括）之间的所有元素
//        // 如要移除的条数是5（即willToTrimCount=5），则本次移除的索引会是：0、1、2、3、4
//        [[al getDataList] removeObjectsInRange:NSMakeRange(0, willToTrimCount)];
//    }
//    DDLogDebug(@"【群聊】trim后的消息总数=%ld [2]", (unsigned long)[[al getDataList] count]);
//}


@end
