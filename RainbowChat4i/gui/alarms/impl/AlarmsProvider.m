//telegram @wz662
#import "AlarmsProvider.h"
#import "AlarmType.h"
#import "AlarmDto.h"
#import "IMClientManager.h"
#import "UserEntity.h"
#import "ChatDataHelper.h"
#import "TMessageHelper.h"
#import "AlarmsHistoryTable.h"
#import "AlarmType.h"
#import "MyDataBase.h"
#import "MsgBodyRoot.h"
#import "UserDefaultsToolKits.h"
#import "GChatDataHelper.h"
#import "GroupEntity.h"
#import "QoS4ReciveDaemon.h"
#import "JSQMessage.h"
#import "NotificationCenterFactory.h"
#import "AlarmUnreadDebugTrace.h"
#import "BasicTool.h"
#import "FriendsListProvider.h"
#import "HttpRestHelper.h"
#import "GroupMemberEntity.h"
#import "GroupsProvider.h"

#ifdef RB_DEBUG_UNREAD_GATES_ALWAYS_OPEN
#undef RB_DEBUG_UNREAD_GATES_ALWAYS_OPEN
#endif
#define RB_DEBUG_UNREAD_GATES_ALWAYS_OPEN 0

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface AlarmsProvider ()

/**
 * 通用Alarm数据结构，数据结构形如：<AlarmMessageDto *>。
 */
@property (strong, nonatomic) NSMutableArrayObservableEx *alarmMessageData;

/** BBS专用Alarm数据结构 */
@property (strong, nonatomic) BBSAlarmDataObservable *bbsAlarmDataObservable;

/**
 * 本字段用来确保方法 {@link #loadDatasOnce()}中的数据，在APP的
 * 生命周期中只被加载一次（也只需要加载一次，否则就重复罗） .
 */
@property (assign, nonatomic) BOOL datasHasLoaded;
@property (strong, nonatomic) NSMutableDictionary<NSString *, AlarmDto *> *rb_coalesceAlarmSqlitePending;
@property (copy, nonatomic) dispatch_block_t rb_coalesceAlarmSqliteFlushBlock;


- (void)rb_performSaveAlarmToSqliteOnDb:(FMDatabase *)db amd:(AlarmDto *)amd debugTag:(NSString *)tag;
- (void)rb_coalesceAlarmSqliteEnqueue:(AlarmDto *)amd;

@end


// 主线程上延迟执行 SQLite 写入的串行队列，避免 SyncManager 大量已读回执在主线程同步写库导致卡顿
static dispatch_queue_t s_alarmSqliteDeferQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        q = dispatch_queue_create("com.rainbowchat.alarms.sqlite.defer", DISPATCH_QUEUE_SERIAL);
    });
    return q;
}

// 会话列表首屏加载用的后台队列，避免主线程 inDatabase 阻塞首帧（秒开优化）
static dispatch_queue_t s_alarmFirstLoadQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        q = dispatch_queue_create("com.rainbowchat.alarms.firstload", DISPATCH_QUEUE_SERIAL);
    });
    return q;
}

static dispatch_queue_t s_alarmSqliteDeleteQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        q = dispatch_queue_create("com.rainbowchat.alarms.sqlite.delete", DISPATCH_QUEUE_SERIAL);
    });
    return q;
}

/// 首页消息列表内存模型（alarmMessageData）仅允许在主线程与 UIKit 同步访问；SyncManager 等在全局队列处理增量消息时也走此收口，避免与 UITableView 并发读写崩溃。
NS_INLINE void APRunAlarmModelOnMain(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation AlarmsProvider

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.alarmMessageData = [[NSMutableArrayObservableEx alloc] init];
        self.bbsAlarmDataObservable = [[BBSAlarmDataObservable alloc] init];
        self.datasHasLoaded = NO;
    }
    return self;
}


//--------------------------------------------------------------------------------------- START
#pragma mark - 【1】通用方法定义

- (void) clear
{
    APRunAlarmModelOnMain(^{
        if(self.alarmMessageData != nil)
            [self.alarmMessageData clear:NO];
#if RB_DEBUG_UNREAD_GATES_ALWAYS_OPEN
        [self rb_debug_openAllUnreadGates];
#endif
    });
    __weak typeof(self) wself = self;
    dispatch_async(s_alarmSqliteDeferQueue(), ^{
        AlarmsProvider *s = wself;
        if (!s) return;
        if (s.rb_coalesceAlarmSqlitePending) {
            [s.rb_coalesceAlarmSqlitePending removeAllObjects];
        }
        if (s.rb_coalesceAlarmSqliteFlushBlock) {
            dispatch_block_cancel(s.rb_coalesceAlarmSqliteFlushBlock);
            s.rb_coalesceAlarmSqliteFlushBlock = nil;
        }
    });
}

- (NSMutableArrayObservableEx *) getAlarmsData
{
    return self.alarmMessageData;
}

- (void) loadDatasOnce
{
    if(!self.datasHasLoaded)
    {
        // ** 载入系统预定义的APP中写死的首页”消息“
        [self loadSystemDefineAlarms];

        // ** 载入本地存储的离线首页”通知“历史记录
        // 在此时机下需要做其它事情: 把之前存储在本地的首页”通知“历史记录先放进来
        // ** 秒开优化：在后台队列载入本地会话列表，主线程只收结果并刷新，不执行 inDatabase
        [self loadAlarmHistoryInBackgroundWithCompletion:^{}];
    }
    else
    {
        DDLogDebug(@"[AlarmsProvider]【NOTE】loadDatasOnce方法再次被调用，但数据已被载入过，本次载入将被忽略。");
    }
}

- (void) loadSystemDefineAlarms
{
//    [self addFirstUseSystemAlarm];
//    [self addSystemQAndAAlarm];
}

/**
 * 载入首页”通知“历史记录（存放于本地数据库中的）.
 * <p>
 * 本方法目前是在首次{@link #getAlarmsData()}时，被调用.
 *
 * @param alarmArray
 */
- (void) loadAlarmHistory:(NSMutableArrayObservableEx *)alarmArray
{
    if(alarmArray != nil )
    {
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {

            // 从本地sqlite中读出首页"消息"历史记录（非置顶记录）：返回的结果是按更新时间顺序的
            NSArray<AlarmDto *> *cachedAlarmsHistoryData = [[MyDataBase sharedInstance].alarmsHistoryTable findHistory:db findHistotyType:AHT_FindHistotyType_OnlyNotAlwaysTopRecords];
            // for debug
            [MyDataBase printErrorForDebug:db tag:@"AlarmsProvider-loadAlarmHistory(OnlyNotAlwaysTopRecords)"];
            // 把"通知"历史记录放到数据结构中（两批共享 seenChatDataIds 去重）
            NSMutableSet<NSString *> *seenChatDataIds = [NSMutableSet set];
            [self insertAlarmsHistoryData:alarmArray data:cachedAlarmsHistoryData db:db seenChatDataIdsInOut:seenChatDataIds];

            // 从本地sqlite中读出首页"消息"历史记录（置顶记录）：返回的结果是按更新时间顺序的
            NSArray<AlarmDto *> *cachedAlarmsHistoryData_onlyAlwaysTop =[[MyDataBase sharedInstance].alarmsHistoryTable findHistory:db findHistotyType:AHT_FindHistotyType_OnlyAlwaysTopRecords];
            // for debug
            [MyDataBase printErrorForDebug:db tag:@"AlarmsProvider-loadAlarmHistory(OnlyAlwaysTopRecords)"];
            // 把"通知"历史记录放到数据结构中
            [self insertAlarmsHistoryData:alarmArray data:cachedAlarmsHistoryData_onlyAlwaysTop db:db seenChatDataIdsInOut:seenChatDataIds];

        }];
    }
    else
    {
        DDLogWarn(@"[AlarmsProvider] alarmArray is nil!");
    }
}

/// 在后台队列载入首页通知历史，完成后在主线程合并到 alarmMessageData 并通知观察者（秒开：主线程不执行 inDatabase）
- (void)loadAlarmHistoryInBackgroundWithCompletion:(void (^)(void))completion
{
    NSMutableArrayObservableEx *alarmArray = self.alarmMessageData;
    if (alarmArray == nil) {
        if (completion) completion();
        return;
    }
    __weak typeof(self) wself = self;
    dispatch_async(s_alarmFirstLoadQueue(), ^{
        __block NSArray<AlarmDto *> *cachedNotTop = nil;
        __block NSArray<AlarmDto *> *cachedAlwaysTop = nil;
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            cachedNotTop = [[MyDataBase sharedInstance].alarmsHistoryTable findHistory:db findHistotyType:AHT_FindHistotyType_OnlyNotAlwaysTopRecords];
            [MyDataBase printErrorForDebug:db tag:@"AlarmsProvider-loadAlarmHistoryInBackground(OnlyNotAlwaysTopRecords)"];
            cachedAlwaysTop = [[MyDataBase sharedInstance].alarmsHistoryTable findHistory:db findHistotyType:AHT_FindHistotyType_OnlyAlwaysTopRecords];
            [MyDataBase printErrorForDebug:db tag:@"AlarmsProvider-loadAlarmHistoryInBackground(OnlyAlwaysTopRecords)"];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            AlarmsProvider *self = wself;
            if (!self || !self.alarmMessageData) {
                if (completion) completion();
                return;
            }
            // 若已有会话（如 1008-26-7 已写入），不再插入，避免重复
            if ([self chatSessionCount] > 0) {
                self.datasHasLoaded = YES;
                [self.alarmMessageData notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
                if (completion) completion();
                return;
            }
            [self loadSystemDefineAlarms];
            NSMutableSet<NSString *> *seenChatDataIds = [NSMutableSet set];
            [self insertAlarmsHistoryData:self.alarmMessageData data:cachedNotTop db:nil seenChatDataIdsInOut:seenChatDataIds];
            [self insertAlarmsHistoryData:self.alarmMessageData data:cachedAlwaysTop db:nil seenChatDataIdsInOut:seenChatDataIds];
            [GChatDataHelper addSystenInfo_wordChatPortalForLocalUser];
            self.datasHasLoaded = YES;
            [self.alarmMessageData notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
            if (completion) completion();
        });
    });
}

- (void) insertAlarmsHistoryData:(NSMutableArrayObservableEx *)alarmArray
                            data:(NSArray<AlarmDto *> *)cachedAlarmsHistoryData
                              db:(FMDatabase *)db
         seenChatDataIdsInOut:(NSMutableSet<NSString *> * _Nullable)seenInOut
{
    // 注意：可能被 loadAlarmHistory 在 inDatabase 回调线程调用，此处禁止 dispatch_sync 主线程，否则与主线程 inDatabase 形成死锁；当前正式路径仅为 loadAlarmHistoryInBackground 已在主线程合并。
    // 把"通知"历史记录放到数据结构中
    if(cachedAlarmsHistoryData != nil && [cachedAlarmsHistoryData count] > 0)
    {
        // 【BUG FIX】用于去重检测：防止同一dataId出现好友+陌生人两条记录（含跨 NotTop/AlwaysTop 两批共享去重，避免冷启动有草稿时出现两条相同会话）
        // （此问题源于updateAlarmType曾未正确清理SQLite旧记录导致的脏数据，或同一 dataId 分属两批时未共享 seen 导致重复）
        NSMutableSet<NSString *> *seenChatDataIds = (seenInOut != nil) ? seenInOut : [NSMutableSet set];
        
        for(AlarmDto *cme in cachedAlarmsHistoryData)
        {
            // 冷启动首帧：可从本地 DB 载入非聊天类告警；聊天会话行仅由 1008-26-7 填充
            // 对一对一聊天消息进行去重：同一个dataId只保留一条（好友或陌生人）
            if(cme.alarmType == AMT_friendChatMessage || cme.alarmType == AMT_guestChatMessage)
            {
                if(cme.dataId != nil && [seenChatDataIds containsObject:cme.dataId])
                {
                    DDLogWarn(@"[AlarmsProvider] 去重：发现同一dataId=%@的重复聊天记录(alarmType=%d)，跳过", cme.dataId, cme.alarmType);
                    // 直接使用外层传入的db来清理SQLite中的脏数据（避免嵌套inDatabase导致死锁）；主线程回调时 db 为 nil 则不写库
                    if (db != nil) {
                        [[MyDataBase sharedInstance].alarmsHistoryTable deleteHistory:db alarmType:cme.alarmType dataId:cme.dataId];
                    }
                    continue;
                }
                if(cme.dataId != nil)
                    [seenChatDataIds addObject:cme.dataId];
            }
            
            // 一直插入到列表首位置（因为取出的消息本就是按逆序排列的，那
            // 么此处永远往表首插就能保证插完后的消息是按时间顺序显示的）
            [alarmArray add:0 withObj:cme needNotify:NO];// 一直往表首插的好处因为历史记录的读取是在异步线程中执行，当新消息插入时，可
                                                         // 以很大程度上保证历史消息不会排在刚新收到的消息的后面（极端情况下不能完全保证）
//            alarmArray.add(0, cme, false);
        }
        // 批量插入则很可能会让老消息显示在刚新收到的通知的后面，防止给用户出错的感觉
//      messageArray.putDataList(cachedChatMessageData, false);
    }
}

/// 仅将会话类型的 AlarmDto 插入列表（用于登录时先展示本地会话，不写 DB）。调用前需已 clearChatSessionAlarmsOnly。
- (void)insertChatSessionAlarmsOnly:(NSArray<AlarmDto *> *)list notify:(BOOL)notify
{
    APRunAlarmModelOnMain(^{
        if (list.count == 0) {
            if (notify) [[self getAlarmsData] notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
            return;
        }
        NSMutableArrayObservableEx *arr = [self getAlarmsData];
        for (AlarmDto *cme in list) {
            [arr add:0 withObj:cme needNotify:NO];
        }
        if (notify) [arr notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
    });
}

- (NSUInteger)chatSessionCount
{
    __block NSUInteger n = 0;
    APRunAlarmModelOnMain(^{
        NSArray *list = [[self getAlarmsData] getDataList];
        n = 0;
        for (AlarmDto *amd in list) {
            if (amd.alarmType == AMT_friendChatMessage || amd.alarmType == AMT_guestChatMessage || amd.alarmType == AMT_groupChatMessage)
                n++;
        }
    });
    return n;
}

- (NSUInteger)archivedChatSessionCount
{
    __block NSUInteger n = 0;
    APRunAlarmModelOnMain(^{
        NSArray *list = [[self getAlarmsData] getDataList];
        n = 0;
        for (AlarmDto *amd in list) {
            BOOL isChat = (amd.alarmType == AMT_friendChatMessage
                           || amd.alarmType == AMT_guestChatMessage
                           || amd.alarmType == AMT_groupChatMessage);
            if (isChat && amd.archived) {
                n++;
            }
        }
    });
    return n;
}

- (AlarmDto *)addAlarm:(AlarmDto *)amd
{
    // 把提示消息放到列表的首位置
    return [self addAlarm:amd notify:YES];
}

- (AlarmDto *)addAlarm:(AlarmDto *)amd notify:(BOOL)notifyObserver
{
    __block AlarmDto *result = nil;
    APRunAlarmModelOnMain(^{
        // 检查是否有草稿
        BOOL hasDraft = [self hasDraftForAlarm:amd];
        BOOL effectiveNotify = notifyObserver;
        // 把提示消息放到列表的合适位置（考虑置顶、草稿和时间排序）
        result = [self addAlarm:[self getFirstAvailableIndex:amd.alwaysTop hasDraft:hasDraft alarmDate:amd.date] withDto:amd notify:effectiveNotify];
    });
    return result;
}

- (AlarmDto *)addAlarm:(int) index withDto:(AlarmDto *)amd notify:(BOOL)notifyObserver
{
    __block AlarmDto *ret = amd;
    APRunAlarmModelOnMain(^{
        if(index != -1) {
            @try {
                [[self getAlarmsData] add:index withObj:amd needNotify:notifyObserver];
            } @catch (NSException *exception) {
#if DEBUG
                NSLog(@"%@",exception);
#endif
            }
        }
    });
    return ret;
}

- (void) removeAlarm:(int)index notify:(BOOL)notifyObserver
{
    [self removeAlarm:index notify:notifyObserver deleteAlarmLocalData:YES deleteLocalData:YES];
}

- (void) removeAlarm:(int)index
              notify:(BOOL)notifyObserver
deleteAlarmLocalData:(BOOL)deleteAlarmLocalData
     deleteLocalData:(BOOL)deleteChatMessageLocalDatas
{
    __block int deleteAlarmType = -1;
    __block NSString *deleteDataId = nil;
    __block BOOL deleteChatHistory = NO;
    APRunAlarmModelOnMain(^{
        if(![self checkIndexValid:index])
        {
            DDLogDebug(@"[AlarmsProvider] 无效的索引位置：index=%d，实际上当前列表数据个数=%lu"
                       , index, (unsigned long)[[[self getAlarmsData] getDataList] count]);
            return;
        }

        // ************************ 先尝试删除本地存储在sqlite中的数据
        if(deleteAlarmLocalData)// 是否删除首页"消息"存储在本地sqlite中的记录（即是否彻底删除）
        {
            AlarmDto *willRemove = (AlarmDto *)[[self getAlarmsData] get:index];
            UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
            if(localRee != nil && willRemove != nil)
            {
                // 正常聊天消息
                if(willRemove.alarmType == AMT_friendChatMessage
                   || willRemove.alarmType == AMT_guestChatMessage
                   || willRemove.alarmType == AMT_groupChatMessage)
                {
                    NSString *srcUid = willRemove.dataId;
                    if(srcUid != nil)
                    {
                        deleteAlarmType = willRemove.alarmType;
                        deleteDataId = [srcUid copy];
                        deleteChatHistory = deleteChatMessageLocalDatas;
                        if (deleteChatMessageLocalDatas) {
                            IMClientManager *imc = [IMClientManager sharedInstance];
                            if (willRemove.alarmType == AMT_friendChatMessage || willRemove.alarmType == AMT_guestChatMessage) {
                                [[imc getMessagesProvider] removeMessages:srcUid isDeleteLocalDatas:NO db:nil notify:notifyObserver];
                            } else if (willRemove.alarmType == AMT_groupChatMessage) {
                                [[imc getGroupsMessagesProvider] removeMessages:srcUid isDeleteLocalDatas:NO db:nil notify:notifyObserver];
                            }
                        }

                    }
                }
            }
        }

        // ************************ 再从内存数据中移除
        [[self getAlarmsData] remove:index needNotify:notifyObserver];
    });
    
    if (deleteAlarmLocalData && deleteDataId.length > 0 && deleteAlarmType != -1) {
        dispatch_async(s_alarmSqliteDeleteQueue(), ^{
            [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
                BOOL removeSucess = [[MyDataBase sharedInstance].alarmsHistoryTable deleteHistory:db alarmType:deleteAlarmType dataId:deleteDataId];
                if(!removeSucess) {
                    [MyDataBase printErrorForDebug:db tag:@"AlarmsProvider-removeAlarm(删除sqlite中的alarms)"];
                }
                if (deleteChatHistory) {
                    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
                    if (!localRee || deleteDataId.length == 0) return;
                    if (deleteAlarmType == AMT_friendChatMessage || deleteAlarmType == AMT_guestChatMessage) {
                        BOOL ok = [[MyDataBase sharedInstance].chatHistoryTable deleteHistory:db acountUidOfOwner:localRee.user_uid srcUid:deleteDataId];
                        if(!ok) [MyDataBase printErrorForDebug:db tag:@"AlarmsProvider-removeAlarm(删除sqlite中的chat_msg)"];
                    } else if (deleteAlarmType == AMT_groupChatMessage) {
                        BOOL ok = [[MyDataBase sharedInstance].groupChatHistoryTable deleteHistory:db acountUidOfOwner:localRee.user_uid gid:deleteDataId];
                        if(!ok) [MyDataBase printErrorForDebug:db tag:@"AlarmsProvider-removeAlarm(删除sqlite中的groupchat_msg)"];
                    }
                }
            }];
        });
    }
}

// 仅清空聊天消息记录
+ (void)clearHistoryMessages:(int)alarmType dataId:(NSString *)dataId deleteLocaleDatas:(BOOL)deleteLocaleDatas db:(FMDatabase *)db notify:(BOOL)notifyObserver
{
    IMClientManager *imc = [IMClientManager sharedInstance];
    // 如果删除的是一对聊天的
    if (alarmType == AMT_friendChatMessage || alarmType == AMT_guestChatMessage) {
        [[imc getMessagesProvider] removeMessages:dataId isDeleteLocalDatas:deleteLocaleDatas db:db notify:notifyObserver];
    }
    // 如果删除的是群聊的
    else if (alarmType == AMT_groupChatMessage) {
        [[imc getGroupsMessagesProvider] removeMessages:dataId isDeleteLocalDatas:deleteLocaleDatas db:db notify:notifyObserver];
    }
}

// 更新指定索引位置的“通知”上的标题（本方法只更新数据模型本身，不涉及sqlite的同步）
- (AlarmDto *)updateAlarmTitle:(int)index newTitle:(NSString *)newTitle
{
    __block AlarmDto *result = nil;
    APRunAlarmModelOnMain(^{
        if([self checkIndexValid:index] && ![BasicTool isStringEmpty:newTitle]) {
            AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];
            amd.title = newTitle;
            result = amd;
        }
        else{
            DDLogWarn(@"updateAlarmTitle时，无效的参数：index=%d，newTitle=%@", index, newTitle);
            result = nil;
        }
    });
    return result;
}

// 更新指定item上的标题（并支持是否更新sqlite）
- (void)updateAlarmTitle:(int)alarmType dataId:(NSString *)dataId newTitle:(NSString *)newTitle needUpdateSqlite:(BOOL)needUpdateSqlite
{
    __block AlarmDto *afterUpdate = nil;
    APRunAlarmModelOnMain(^{
        afterUpdate = [self updateAlarmTitle:[self getAlarmIndex:alarmType dataId:dataId] newTitle:newTitle];
    });
    if(needUpdateSqlite && afterUpdate != nil)
        [self saveAlarmToSqlite:afterUpdate debugTag:[NSString stringWithFormat:@"updateAlarmTitle中saveAlarmToSqlite:dataId=%@，alarmType=%d, newTitle=%@", dataId, alarmType, newTitle]];
}

// 更新指定索引位置的“通知”上的标题、extra1String字段（本方法只更新数据模型本身，不涉及sqlite的同步）
- (AlarmDto *)updateAlarmTitleAndExtra1:(int)index newTitle:(NSString *)newTitle newExtra1:(NSString *)newExtra1
{
    __block AlarmDto *result = nil;
    APRunAlarmModelOnMain(^{
        if([self checkIndexValid:index] && ![BasicTool isStringEmpty:newTitle]) {
            AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];
            amd.title = newTitle;
            amd.extraString1 = newExtra1;
            result = amd;
        }
        else{
            DDLogWarn(@"updateAlarmTitle时，无效的参数：index=%d，newTitle=%@，newExtra1=%@", index, newTitle, newExtra1);
            result = nil;
        }
    });
    return result;
}

// 更新指定item上的标题、extra1String字段（并支持是否更新sqlite）
- (void)updateAlarmTitleAndExtra1:(int)alarmType dataId:(NSString *)dataId newTitle:(NSString *)newTitle newExtra1:(NSString *)newExtra1 needUpdateSqlite:(BOOL)needUpdateSqlite
{
    __block AlarmDto *afterUpdate = nil;
    APRunAlarmModelOnMain(^{
        afterUpdate = [self updateAlarmTitleAndExtra1:[self getAlarmIndex:alarmType dataId:dataId] newTitle:newTitle newExtra1:newExtra1];
    });
    if(needUpdateSqlite && afterUpdate != nil)
        [self saveAlarmToSqlite:afterUpdate debugTag:[NSString stringWithFormat:@"updateAlarmTitleAndExtra1中saveAlarmToSqlite:dataId=%@，alarmType=%d, newTitle=%@，newExtra1=%@", dataId, alarmType, newTitle, newExtra1]];
}

// 读取extra1String字段，目前该字段主要是用于存放最新的临时聊正者的头像文件名。
- (NSString *)getExtra1String:(int)alarmType dataId:(NSString *)dataId
{
    __block NSString *ex = nil;
    APRunAlarmModelOnMain(^{
        AlarmDto *alarmDto = [self getAlarmDto:alarmType dataId:dataId];
        ex = alarmDto != nil ? alarmDto.extraString1 : nil;
    });
    return ex;
}

// 更新指定索引位置的“通知”上的内容和时间（本方法只更新数据模型本身，不涉及sqlite）
- (AlarmDto *)updateAlarmContentAndTime:(int)index newContent:(NSString *)newContent newDate:(NSDate *)newDate
{
    __block AlarmDto *result = nil;
    APRunAlarmModelOnMain(^{
        if([self checkIndexValid:index]) {
            AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];
            amd.alarmContent = (newContent == nil? @"": newContent);
            amd.date =  (newDate == nil?[TimeTool getIOSDefaultDate]:newDate);
            result = amd;
        }
        else{
            DDLogWarn(@"updateAlarmContentAndTime时，无效的参数：index=%d，newContent=%@", index, newContent);
            result = nil;
        }
    });
    return result;
}

// 更新指定item上的内容和时间（并支持是否更新sqlite）。
- (void)updateAlarmContentAndTime:(int)alarmType dataId:(NSString *)dataId newContent:(NSString *)newContent newDate:(NSDate *)newDate needUpdateSqlite:(BOOL)needUpdateSqlite
{
    __block AlarmDto *afterUpdate = nil;
    APRunAlarmModelOnMain(^{
        afterUpdate = [self updateAlarmContentAndTime:[self getAlarmIndex:alarmType dataId:dataId] newContent:newContent newDate:newDate];
    });
    if(needUpdateSqlite && afterUpdate != nil)
        [self saveAlarmToSqlite:afterUpdate debugTag:[NSString stringWithFormat:@"updateAlarmContentAndTime中saveAlarmToSqlite:dataId=%@，alarmType=%d, newContent=%@", dataId, alarmType, newContent]];
}

// 更新指定索引位置的“通知/会话”上的类型（本方法只更新数据模型本身，不涉及sqlite）
- (AlarmDto *)updateAlarmType:(int)index newType:(int)newAlarmType
{
    __block AlarmDto *result = nil;
    APRunAlarmModelOnMain(^{
        if([self checkIndexValid:index]) {
            AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];
            amd.alarmType = newAlarmType;
            result = amd;
        } else{
            DDLogWarn(@"updateAlarmType时，无效的参数：index=%d，newAlarmType=%d", index, newAlarmType);
            result = nil;
        }
    });
    return result;
}

// 更新指定item上的"通知/会话"上的类型（并支持是否更新sqlite）。
- (void)updateAlarmType:(int)alarmType dataId:(NSString *)dataId  newType:(int)newAlarmType needUpdateSqlite:(BOOL)needUpdateSqlite
{
    __block AlarmDto *afterUpdate = nil;
    APRunAlarmModelOnMain(^{
        afterUpdate = [self updateAlarmType:[self getAlarmIndex:alarmType dataId:dataId] newType:newAlarmType];
    });
    if(needUpdateSqlite && afterUpdate != nil)
    {
        if(alarmType != newAlarmType && dataId != nil)
        {
            [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
                [[MyDataBase sharedInstance].alarmsHistoryTable deleteHistory:db alarmType:alarmType dataId:dataId];
            }];
        }
        [self saveAlarmToSqlite:afterUpdate debugTag:[NSString stringWithFormat:@"updateAlarmType中saveAlarmToSqlite:dataId=%@，alarmType=%d, newAlarmType=%d", dataId, alarmType, newAlarmType]];
    }
}

- (AlarmDto *)resetFlagNum:(int)index
{
    return [self resetFlagNum:index flagNumToReset:0];
}

- (AlarmDto *)resetFlagNum:(int)index flagNumToReset:(int)flagNumToReset
{
    __block AlarmDto *out = nil;
    APRunAlarmModelOnMain(^{
        if([self checkIndexValid:index])
        {
            AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];
            amd.flagNum = [NSString stringWithFormat:@"%d", flagNumToReset];
            // 与会话列表 cell 一致：effectiveUnread = MAX(flagNum, unreadCount)。仅改 flagNum 会把 unreadCount（26-7 快照）留在内存里 → Tab 角标已消、行气泡仍在。
            amd.unreadCount = flagNumToReset;
            if([amd isAtMe]) {
                amd.atMe = (flagNumToReset > 0);
            }
            [[self getAlarmsData] notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
            out = amd;
        }
    });
    return out;
}

/**
 * 将会话内已有消息的 fp 标记为已收（QoS4ReciveDaemon），避免 SyncKey/重放 时再次累加未读。
 * 应在「未读清零」后调用（如进入聊天页、已读回执同步等）。
 */
- (void)markConversationFingerPrintsAsReceived:(int)alarmType dataId:(NSString *)dataId
{
    if (dataId.length == 0) return;
    id provider = (alarmType == AMT_groupChatMessage)
        ? (id)[[IMClientManager sharedInstance] getGroupsMessagesProvider]
        : (id)[[IMClientManager sharedInstance] getMessagesProvider];
    NSMutableArrayObservableEx *msgList = [provider getMessages:dataId];
    if (msgList == nil) return;
    for (id msg in [[msgList getDataList] copy]) {
        if (![msg isKindOfClass:[JSQMessage class]]) continue;
        NSString *fp = ((JSQMessage *)msg).fingerPrintOfProtocal;
        if (fp.length > 0)
            [[QoS4ReciveDaemon sharedInstance] addRecievedWithFingerPrint:fp];
    }
}

/**
 * 重置指定item上的未读数为指定整数（并支持是否更新sqlite）。
 */
- (void)resetFlagNum:(int)alarmType dataId:(NSString *)dataId flagNumToReset:(int)flagNumToReset needUpdateSqlite:(BOOL)needUpdateSqlite
{
    APRunAlarmModelOnMain(^{
        if ([AlarmUnreadDebugTrace isTargetUid:dataId]) {
            int idxBefore = [self getAlarmIndex:alarmType dataId:dataId];
            NSString *before = @"-";
            if (idxBefore != -1) {
                AlarmDto *a = (AlarmDto *)[[self getAlarmsData] get:idxBefore];
                before = a.flagNum ?: @"0";
            }
            [AlarmUnreadDebugTrace appendLine:[NSString stringWithFormat:@"reset -> %d (was %@) alarmType=%d sqlite=%@", flagNumToReset, before, alarmType, needUpdateSqlite ? @"Y" : @"N"]
                                       source:@"AlarmsProvider.reset"
                                       forUid:dataId];
        }
        AlarmDto *afterUpdate = [self resetFlagNum:[self getAlarmIndex:alarmType dataId:dataId] flagNumToReset:flagNumToReset];
        if(needUpdateSqlite && afterUpdate != nil)
           [self saveAlarmToSqlite:afterUpdate debugTag:[NSString stringWithFormat:@"resetFlagNum中saveAlarmToSqlite:dataId=%@，alarmType=%d", dataId, alarmType]];
        if (flagNumToReset == 0)
            [self markConversationFingerPrintsAsReceived:alarmType dataId:dataId];
    });
}

// 重置所有“通知”上的未读数为0（本方法只更新数据模型本身，不涉及sqlite的同步）。
- (void)resetAllFlagNum
{
    APRunAlarmModelOnMain(^{
        BOOL needNotifyObservers = NO;
        if([self getAlarmsData] != nil){
            for(AlarmDto *a in [[self getAlarmsData] getDataList]){
                if(a != nil && [BasicTool getIntValue:a.flagNum] > 0) {
                    a.flagNum = @"0";
                    a.atMe = NO;
                    needNotifyObservers = YES;
                }
            }
        }
        if(needNotifyObservers) {
            [[self getAlarmsData] notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
        }
    });
}

// 重置所有item上的未读数为0（并支持是否更新sqlite）。
- (void)resetAllFlagNum:(BOOL)needUpdateSqlite {
    APRunAlarmModelOnMain(^{
        [self resetAllFlagNum];
    });
    if (needUpdateSqlite)
    {
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            BOOL sucess = [[MyDataBase sharedInstance].alarmsHistoryTable clearAllUnread:db];
            if(!sucess)
                [MyDataBase printErrorForDebug:db tag:@"AlarmsProvider.resetAllFlagNum-clearAllUnread"];
        }];
    }
    else {
        DDLogWarn(@"AlarmsProvider-resetAllFlagNum时不需要更新sqlite(updateToSqlite==NO)!");
    }
}

- (void)accumulateFlagNum:(int)index withNum:(int)flagNumToAdd
{
    APRunAlarmModelOnMain(^{
        if([self checkIndexValid:index])
        {
            AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];
            if(amd != nil)
            {
                int result = [BasicTool getIntValue:amd.flagNum] + flagNumToAdd;
                amd.flagNum = [NSString stringWithFormat:@"%d", (result < 0 ? 0 : result)];
                if([amd isAtMe]) {
                    amd.atMe = (result > 0);
                }
            }
        }
    });
}

//叠加未读数为指定数字.
- (void)accumulateFlagNum:(int)alarmType dataId:(NSString *)dataId withNum:(int)flagNumToAdd
{
    APRunAlarmModelOnMain(^{
        int index = [self getAlarmIndex:alarmType dataId:dataId];
        if(index != -1) {
            [self accumulateFlagNum:index withNum:flagNumToAdd];
            if ([AlarmUnreadDebugTrace isTargetUid:dataId]) {
                AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];
                [AlarmUnreadDebugTrace appendLine:[NSString stringWithFormat:@"accumulate %+d -> flagNum=%@", flagNumToAdd, amd.flagNum ?: @"?"]
                                           source:@"AlarmsProvider.accumulate"
                                           forUid:dataId];
            }
        }
    });
}

- (int)getFlagNum:(int)index
{
    __block int n = 0;
    APRunAlarmModelOnMain(^{
        if([self checkIndexValid:index])
        {
            AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];
            if(amd != nil)
                n = [BasicTool getIntValue:amd.flagNum];
        }
    });
    return n;
}

// 会话未读 flagNum 仅由三类路径写入：①入站 addSingleChatMessageAlarm/addAGroupChatMsgAlarm ②resetFlagNum（已读/回执/进会话）③1008-26-7 内 resetFlagNum 对齐服务端 unread_count。勿再增加第四套覆盖逻辑。

- (int)getTotalFlagNum
{
    __block int total = 0;
    APRunAlarmModelOnMain(^{
        total = 0;
        if([self getAlarmsData] != nil)
        {
            for(AlarmDto *amd in [[self getAlarmsData] getDataList])
            {
                if(amd.alarmType == AMT_groupChatMessage && [GroupEntity isWorldChat:amd.dataId])
                    continue;
                if(amd.alarmType == AMT_addFriendRequest)
                    continue;
                if (amd.archived
                    && (amd.alarmType == AMT_friendChatMessage
                        || amd.alarmType == AMT_guestChatMessage
                        || amd.alarmType == AMT_groupChatMessage))
                    continue;
                int flagNum = [amd.flagNum intValue];
                if(flagNum < 0)
                {
                    flagNum = 0;
                    amd.flagNum = @"0";
                }
                if(amd.alarmType == AMT_friendChatMessage
                   || amd.alarmType == AMT_guestChatMessage
                   || amd.alarmType == AMT_groupChatMessage )
                {
                    if(![UserDefaultsToolKits isChatMsgToneOpen:amd.dataId])
                        flagNum = 0;
                }
                total += flagNum;
            }
        }
    });
    return total;
}

// 返回私聊消息的未读总数（不含群聊）
- (int)getPrivateFlagNum
{
    __block int total = 0;
    APRunAlarmModelOnMain(^{
        total = 0;
        if([self getAlarmsData] != nil)
        {
            for(AlarmDto *amd in [[self getAlarmsData] getDataList])
            {
                if(amd.alarmType == AMT_groupChatMessage)
                    continue;
                if(amd.alarmType == AMT_addFriendRequest)
                    continue;
                if (amd.archived
                    && (amd.alarmType == AMT_friendChatMessage
                        || amd.alarmType == AMT_guestChatMessage))
                    continue;
                int flagNum = [amd.flagNum intValue];
                if(flagNum < 0)
                {
                    flagNum = 0;
                    amd.flagNum = @"0";
                }
                if(amd.alarmType == AMT_friendChatMessage
                   || amd.alarmType == AMT_guestChatMessage)
                {
                    if(![UserDefaultsToolKits isChatMsgToneOpen:amd.dataId])
                        flagNum = 0;
                }
                total += flagNum;
            }
        }
    });
    return total;
}

// 返回群聊消息的未读总数（不含世界频道）
- (int)getGroupFlagNum
{
    __block int total = 0;
    APRunAlarmModelOnMain(^{
        total = 0;
        if([self getAlarmsData] != nil)
        {
            for(AlarmDto *amd in [[self getAlarmsData] getDataList])
            {
                if(amd.alarmType != AMT_groupChatMessage)
                    continue;
                if([GroupEntity isWorldChat:amd.dataId])
                    continue;
                if (amd.archived)
                    continue;
                int flagNum = [amd.flagNum intValue];
                if(flagNum < 0)
                {
                    flagNum = 0;
                    amd.flagNum = @"0";
                }
                if(![UserDefaultsToolKits isChatMsgToneOpen:amd.dataId])
                    flagNum = 0;
                total += flagNum;
            }
        }
    });
    return total;
}

- (BOOL) checkIndexValid:(int)index
{
    __block BOOL ok = NO;
    APRunAlarmModelOnMain(^{
        ok = (index >=0 && index <= ([[[self getAlarmsData] getDataList] count] - 1));
    });
    return ok;
}

/**
 * 获得可用的列表首位置索引号(智能判断置顶和非置顶情况)。
 * <p>
 * 本方法将自动根据列表中的置顶情况，尽量返回"0"索引位置：即当存在置顶item时，普通的item只能放到置顶的item后面，
 * 否则才可以放到真正的0索引位置！
 *
 * @param forAlwayTop YES表示本次要获得的是置顶item的插入索引值，否则是普通item的插入索引值
 * @param hasDraft YES表示本次要插入的item有草稿，需要放在置顶消息之后
 * @return 列表的最前面可插入位置索引值（如果是置顶则一直返回0，如果有草稿则返回置顶消息之后，否则返回所有置顶和有草稿item之后的第1个索引）
 */
- (int) getFirstAvailableIndex:(BOOL)forAlwayTop hasDraft:(BOOL)hasDraft alarmDate:(NSDate *)alarmDate
{
    __block int resultIndex = 0;
    APRunAlarmModelOnMain(^{
    int index = 0;//-1;
    NSMutableArrayObservableEx *dataList = [self getAlarmsData];
    int totalCount = (int)[[dataList getDataList] count];

    // 如果本次是为了置顶item，需要在置顶区域内按时间排序
    if(forAlwayTop)
    {
        // 在置顶区域内找到按时间排序的插入位置（时间越新越靠前，即时间越晚越靠前）
        for(int i = 0; i < totalCount; i++)
        {
            AlarmDto *amd = [[dataList getDataList] objectAtIndex:i];
            if(amd.alwaysTop)
            {
                // 如果当前消息的时间比要插入的消息时间早（或相等），则插入到当前位置
                if(alarmDate != nil && amd.date != nil && [alarmDate compare:amd.date] != NSOrderedAscending)
                {
                    index = i;
                    break;
                }
            }
    else
    {
                // 已经超出置顶区域，插入到最后一个置顶消息之后
                if(i > 0)
                {
                    index = i;
                }
                break;
            }
        }
        // 如果所有置顶消息的时间都比要插入的消息新，则插入到置顶区域的最后
        if(index == 0 && totalCount > 0)
        {
            // 检查最后一个置顶消息
            AlarmDto *lastTop = nil;
            for(int i = totalCount - 1; i >= 0; i--)
            {
                AlarmDto *amd = [[dataList getDataList] objectAtIndex:i];
                if(amd.alwaysTop)
                {
                    lastTop = amd;
                    break;
                }
            }
            if(lastTop != nil)
            {
                // 找到最后一个置顶消息的位置，插入到它之后
                for(int i = 0; i < totalCount; i++)
                {
                    AlarmDto *amd = [[dataList getDataList] objectAtIndex:i];
                    if(amd == lastTop)
                    {
                        index = i + 1;
                        break;
                    }
                }
            }
        }
    }
    else if(hasDraft)
    {
        // 如果有草稿，需要放在置顶消息之后，在草稿区域内按时间排序
        int topCount = 0;
        int draftStartIndex = -1;
        
        // 先找到置顶消息的数量和草稿区域的起始位置
        for(int i = 0; i < totalCount; i++)
        {
            AlarmDto *amd = [[dataList getDataList] objectAtIndex:i];
            if(amd.alwaysTop)
            {
                topCount++;
            }
            else
            {
                BOOL currentHasDraft = [self hasDraftForAlarm:amd];
                if(currentHasDraft && draftStartIndex == -1)
                {
                    draftStartIndex = i;
                }
                else if(!currentHasDraft && draftStartIndex != -1)
                {
                    // 已经超出草稿区域，插入到草稿区域的最后
                    index = i;
                    break;
                }
            }
        }
        
        // 如果在草稿区域内，按时间找到正确的插入位置
        if(draftStartIndex != -1)
        {
            for(int i = draftStartIndex; i < totalCount; i++)
            {
                AlarmDto *amd = [[dataList getDataList] objectAtIndex:i];
                if(amd.alwaysTop)
                {
                    continue;
                }
                BOOL currentHasDraft = [self hasDraftForAlarm:amd];
                if(!currentHasDraft)
                {
                    // 已经超出草稿区域
                    index = i;
                    break;
                }
                // 在草稿区域内，按时间排序（时间越新越靠前）
                if(alarmDate != nil && amd.date != nil && [alarmDate compare:amd.date] != NSOrderedAscending)
                {
                    index = i;
                    break;
                }
            }
        }
        
        // 如果没有找到草稿区域，或者所有草稿消息的时间都比要插入的消息新，则插入到置顶消息之后
        if(index == 0 || (draftStartIndex == -1 && topCount > 0))
        {
            index = topCount;
        }
        else if(draftStartIndex != -1 && index == 0)
        {
            // 找到最后一个草稿消息的位置，插入到它之后
            for(int i = draftStartIndex; i < totalCount; i++)
            {
                AlarmDto *amd = [[dataList getDataList] objectAtIndex:i];
                if(amd.alwaysTop)
                {
                    break;
                }
                BOOL currentHasDraft = [self hasDraftForAlarm:amd];
                if(!currentHasDraft)
                {
                    index = i;
                    break;
                }
                if(i == totalCount - 1 || (i + 1 < totalCount))
                {
                    AlarmDto *nextAmd = (AlarmDto *)[[dataList getDataList] objectAtIndex:i + 1];
                    if(!nextAmd.alwaysTop && ![self hasDraftForAlarm:nextAmd])
                    {
                        index = i + 1;
                        break;
                    }
                }
            }
        }
    }
    else
    {
        // 普通消息，需要放在置顶和草稿消息之后，在普通消息区域内按时间排序
        //## Bug FIX START: 20220811 by Jack Jiang
        index = totalCount;
        //## Bug FIX END
        
        int normalStartIndex = -1;
        // 先找到普通消息区域的起始位置
        for(int i = 0; i < totalCount; i++)
        {
            AlarmDto *amd = [[dataList getDataList] objectAtIndex:i];
            if(!amd.alwaysTop)
        {
                BOOL currentHasDraft = [self hasDraftForAlarm:amd];
                if(!currentHasDraft && normalStartIndex == -1)
                {
                    normalStartIndex = i;
                }
            }
        }
        
        // 如果在普通消息区域内，按时间找到正确的插入位置
        if(normalStartIndex != -1)
        {
            for(int i = normalStartIndex; i < totalCount; i++)
            {
                AlarmDto *amd = [[dataList getDataList] objectAtIndex:i];
            if(amd.alwaysTop)
            {
                continue;
            }
                BOOL currentHasDraft = [self hasDraftForAlarm:amd];
                if(currentHasDraft)
                {
                    continue;
                }
                // 在普通消息区域内，按时间排序（时间越新越靠前）
                if(alarmDate != nil && amd.date != nil && [alarmDate compare:amd.date] != NSOrderedAscending)
            {
                index = i;
                break;
            }
        }
        }
        else
        {
            // 如果没有普通消息区域，插入到列表最后
            index = totalCount;
        }
    }

    DDLogInfo(@"【首页\"消息\"的可插入索引】当前计算的可插入index=%d, forAlwayTop=%d, hasDraft=%d, date=%@", index, forAlwayTop, hasDraft, alarmDate);

    resultIndex = index;
    });
    return resultIndex;
}

// 获得显示在首页消息列中收到的指定好友临时聊天消息时它所位于的索引位置.
- (int) getAlarmIndex:(int)alarmType dataId:(NSString *)dataId
{
    __block int index = -1;
    APRunAlarmModelOnMain(^{
        index = -1;
        for(int i = 0; i < [[[self getAlarmsData] getDataList] count]; i++)
        {
            AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:i];
            if(amd.alarmType == alarmType)
            {
                if(dataId != nil) {
                    if ([amd.dataId isEqualToString:dataId]) {
                        index = i;
                        break;
                    }
                }
                else {
                    index = i;
                    break;
                }
            }
        }
    });
    return index;
}

// 获得显示在首页消息列中收到的指定群组聊天消息的Alarm dto对象引用.
- (AlarmDto *)getAlarmDto:(int)alarmType dataId:(NSString *)dataId
{
    __block AlarmDto *dto = nil;
    APRunAlarmModelOnMain(^{
        dto = nil;
        for(int i = 0; i < [[[self getAlarmsData] getDataList] count]; i++){
            AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:i];
            if(amd.alarmType == alarmType){
                if(dataId != nil) {
                    if (amd.dataId != nil && [amd.dataId isEqualToString:dataId]) {
                        dto = amd;
                        break;
                    }
                }
                else {
                    dto = amd;
                    break;
                }
            }
        }
    });
    return dto;
}

/**
 * 将首页”消息“保存到本地sqlite中.
 */
- (void)rb_performSaveAlarmToSqliteOnDb:(FMDatabase *)db amd:(AlarmDto *)amd debugTag:(NSString *)tag
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if (localRee == nil)
        return;
    int exists = [[MyDataBase sharedInstance].alarmsHistoryTable existsAlarmHistoryCount:db acountUidOfOwner:localRee.user_uid alarmType:[NSString stringWithFormat:@"%d", amd.alarmType] dataId:amd.dataId];
    if (exists != -1) {
        if (exists == 1) {
            BOOL sucess = [[MyDataBase sharedInstance].alarmsHistoryTable updateHistory:db amd:amd];
            if (!sucess)
                [MyDataBase printErrorForDebug:db tag:tag];
        } else {
            BOOL insertOrReplaceSucess = [[MyDataBase sharedInstance].alarmsHistoryTable insertHistory:db amd:amd];
            if (!insertOrReplaceSucess)
                [MyDataBase printErrorForDebug:db tag:tag];
        }
    } else {
        DDLogWarn(@"[%@] 查询出错了。", tag);
    }
}

- (void)rb_coalesceAlarmSqliteEnqueue:(AlarmDto *)amd
{
    if (!self.rb_coalesceAlarmSqlitePending) {
        self.rb_coalesceAlarmSqlitePending = [NSMutableDictionary dictionary];
    }
    NSString *key = [NSString stringWithFormat:@"%d|%@", amd.alarmType, amd.dataId ?: @""];
    [self.rb_coalesceAlarmSqlitePending setObject:amd forKey:key];

    dispatch_block_t prev = self.rb_coalesceAlarmSqliteFlushBlock;
    if (prev) {
        dispatch_block_cancel(prev);
    }
    __weak typeof(self) wself = self;
    dispatch_block_t flush = dispatch_block_create(0, ^{
        AlarmsProvider *s = wself;
        if (!s) return;
        NSDictionary<NSString *, AlarmDto *> *batch = [s.rb_coalesceAlarmSqlitePending copy];
        [s.rb_coalesceAlarmSqlitePending removeAllObjects];
        s.rb_coalesceAlarmSqliteFlushBlock = nil;
        if (batch.count == 0) return;
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            [db beginTransaction];
            for (AlarmDto *dto in batch.allValues) {
                [s rb_performSaveAlarmToSqliteOnDb:db amd:dto debugTag:@"saveAlarmToSqlite(batch)"];
            }
            [db commit];
        }];
    });
    self.rb_coalesceAlarmSqliteFlushBlock = flush;
    dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC));
    dispatch_after(t, s_alarmSqliteDeferQueue(), flush);
}

- (void) saveAlarmToSqlite:(AlarmDto *)amd debugTag:(NSString *)tag
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if (localRee == nil)
        return;
    
    // 世界频道作为特殊的群聊，产品定位是作为在线聊天室，所以不需要存储聊天记录到本地sqlite哦 @since v10.2
    if (amd.alarmType == AMT_groupChatMessage && [GroupEntity isWorldChat:amd.dataId])
        return;
    
    if ([NSThread isMainThread]) {
        __weak typeof(self) wself = self;
        dispatch_async(s_alarmSqliteDeferQueue(), ^{
            [wself rb_coalesceAlarmSqliteEnqueue:amd];
        });
    } else {
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            [self rb_performSaveAlarmToSqliteOnDb:db amd:amd debugTag:tag];
        }];
    }
}

//--------------------------------------------------------------------------------------- END


//--------------------------------------------------------------------------------------- START
#pragma mark - 【a】BBS专用方法相关

- (BBSAlarmDataObservable *)getBBSAlarmData
{
    return self.bbsAlarmDataObservable;
}

/**
 * 设置"BBS聊天消息"类型的alarm.
 */
- (void) setBBSMsgAlarm:(MsgBody4Guest *)tcmd flagNumToAdd:(int)flagNumToAdd
{
    if (tcmd == nil)
        return;

    BBSAlarmDataObservable *ado = [self getBBSAlarmData];
    [ado setData:tcmd.nickName
             msg:[JSQMessage parseMessageContentPreview:tcmd.m withType:tcmd.ty]
            date:[TimeTool getIOSDefaultDate]
             fid:tcmd.f
         flagNum:[NSString stringWithFormat:@"%d", (flagNumToAdd + [ado getFlagNum])]];
}
//--------------------------------------------------------------------------------------- END


////--------------------------------------------------------------------------------------- START
//#pragma mark - 【2】临天聊天消息相关
//
//// 将本地用户主动发出的临时聊天消息也入到首页消息栏里.
//+ (AlarmDto *) addATempChatMsgAlarmForLocal:(int)msgType
//                            friendUid:(NSString *)friendUid
//                           friendName:(NSString *)friendName
//                              withMsg:(NSString *)msg
//{
//    // 把临时聊天消息放到消息列表的首位置
//    return [[[IMClientManager sharedInstance] getAlarmsProvider] addATempChatMsgAlarm:msgType friendUid:friendUid friendName:friendName
//                                                                       withMsg:msg withDate:nil flagNumToAdd:0];
//}
//
//// 添好"临时聊天消息"类型的alarm.
//- (AlarmDto *) addATempChatMsgAlarm:(int)msgType friendUid:(NSString *)friendUid friendName:(NSString *)friendName
//                      withMsg:(NSString *)msg withDate:(NSDate *)time flagNumToAdd:(int)flagNumToAdd
//{
//    if (friendUid == nil)
//        return nil;
//
//    // 既然现在要显示的陌生人首页"消息"，则首先尝试删除之前正式聊天时在首页留
//    // 下的消息item，否则用户会认为是bug（又是临时聊天的又是正式聊天的）
//    int exitstsFriendChatIndex = [[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmIndex:AMT_friendChatMessage dataId:friendUid];
//    [[[IMClientManager sharedInstance] getAlarmsProvider] removeAlarm:exitstsFriendChatIndex notify:YES deleteAlarmLocalData:YES deleteLocalData:NO];
//
//    // 如果已经存在过该人员的消息则合并之
//    if ([self addSameTempChatMsgDTO:msgType friendUid:friendUid friendName:friendName
//                            withMsg:msg withDate:time flagNumToAdd:flagNumToAdd])
//        return nil;
//
//    // 否则添加一条新的（因为之前没有过）
//    AlarmDto *amd = [[AlarmDto alloc] init];
//    amd.alarmType = AMT_guestChatMessage;
//    amd.dataId = friendUid;
//    amd.title = ([BasicTool isStringEmpty:friendName]?@"": friendName);
//    amd.alarmContent = [JSQMessage parseMessageContentPreview:msg withType:msgType];
//    // 如果指定了时间则显示给定的时间，否则默认显示当前时间
//    amd.date = (time == nil? [TimeTool getIOSDefaultDate]: time);
//    amd.flagNum = [NSString stringWithFormat:@"%d", flagNumToAdd];
//    
//    [self addAlarm:amd];
//
//    // 更新本地db的存储
//    [self saveAlarmToSqlite:amd debugTag:@"addATempChatMsgAlarm中的saveAlarmToSqlite:"];
//    
//    return amd;
//}
//
//- (BOOL) addSameTempChatMsgDTO:(int)msgType friendUid:(NSString *)friendUid friendName:(NSString *)friendName
//                       withMsg:(NSString *)msg withDate:(NSDate *)time flagNumToAdd:(int)flagNumToAdd
//{
//    int index = [self getAlarmIndex:AMT_guestChatMessage dataId:friendUid];
//    if(index != -1)
//    {
//        AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];
//        amd.alarmContent = [JSQMessage parseMessageContentPreview:msg withType:msgType];
//        amd.date = (time == nil? [TimeTool getIOSDefaultDate]: time);// 更新时间
//        amd.flagNum = [NSString stringWithFormat:@"%d", ([BasicTool getIntValue:amd.flagNum] + flagNumToAdd)]; // 更新总数
//        
//        // @since 4.1：确保title是最新的
//        amd.title = ([BasicTool isStringEmpty:friendName]?@"": friendName);
//        
//        // 将此人的陌生人消息放在系统消息列表的首位置，以便提示用户查看哦
//        [[self getAlarmsData] remove:index needNotify:NO];
//        [self addAlarm:amd];
//
//        // 更新本地db的存储
//        [self saveAlarmToSqlite:amd debugTag:@"addSameTempChatMsgDTO中的saveAlarmToSqlite:"];
//
//        return YES;
//    }
//    return NO;
//}
////--------------------------------------------------------------------------------------- END


//--------------------------------------------------------------------------------------- START
#pragma mark - 【3】系统预定义相关

- (void)addSystemQAndAAlarm
{
    [self addSystemDefineAlarm:AMT_systemQNA
                     withTitle:@"常见问题（FAQ）"
                    andContent:@"RainbowChat 常见问题列表。"];
}

- (void)addFirstUseSystemAlarm
{
    [self addSystemDefineAlarm:AMT_systemDevTeam
                     withTitle:@"使用帮助"
                    andContent:@"RainbowChat团队欢迎您使用！"];
}

- (void) addSystemDefineAlarm:(int)type withTitle:(NSString *)title andContent:(NSString *)messageContent
{
    APRunAlarmModelOnMain(^{
        AlarmDto *amd = [[AlarmDto alloc] init];
        amd.alarmType = type;
        amd.title = title;
        amd.alarmContent = messageContent;
        amd.date = [TimeTool getIOSDefaultDate];
        int inserIndex = 0;
        if([[[self getAlarmsData] getDataList] count] > 0)
            inserIndex = [[[self getAlarmsData] getDataList] count] -1;
        [self addAlarm:inserIndex withDto:amd notify:YES];
    });
}

+ (BOOL) isSystemDefineAlarm:(int)alarmMessageType dataId:(NSString *)did
{
    if(alarmMessageType == AMT_systemDevTeam
       || alarmMessageType == AMT_systemQNA
//     || (alarmMessageType == AMT_groupChatMessage && [GroupEntity isWorldChat:did])
       )
        return YES;
    return NO;
}
//--------------------------------------------------------------------------------------- END


//--------------------------------------------------------------------------------------- START
#pragma mark - 【4】正式（好友）聊天消息相关 START

- (void)addChatMsgAlarmForAddSuccess:(NSString *)friendUid friendName:(NSString *)friendName
{
    if(friendUid != nil)
    {
        // 再加一个提示到首页消息列表中
        AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
        [ap addSingleChatMessageAlarm:friendUid friendName:friendName
             withConcentForShow:[NSString stringWithFormat:@"%@已是您的好友了，点击开始聊天吧...", friendName] flagNumToAdd:0 withDate:nil withAlarmType:AMT_friendChatMessage fingerPrint:nil];// 这是一条空的模拟消息，当然不需要叠加（未读）数量的显示
    }
}

- (int)getChatMessageFlagNum:(NSString *)uid
{
    __block int n = 0;
    APRunAlarmModelOnMain(^{
        n = [self getFlagNum:[self getAlarmIndex:AMT_friendChatMessage dataId:uid]];
    });
    return n;
}
//--------------------------------------------------------------------------------------- END


//--------------------------------------------------------------------------------------- START
#pragma mark - 【5】单聊（好友或陌生人）聊天消息相关 START
/// priorFingerPrintExistedInMemory：须在 putMessage 之前传入。若在 putMessage 之后再 findMessage，会把本条刚插入的消息误判为「重复」→ eff 恒为 0。
- (int)effectiveFlagNumToAdd:(int)flagNumToAdd forFingerPrint:(NSString *)fingerPrint conversationDataId:(NSString *)dataId alarmType:(int)alarmType priorFingerPrintExistedInMemory:(BOOL)priorFpExisted
{
    if (fingerPrint == nil || fingerPrint.length == 0) return flagNumToAdd;
    // ★ 不累加未读时（预览更新、撤回指令、已读同步插入等）不要在 QoS 登记 fp。
    // 否则同一 fp 若先以 flagNumToAdd=0 调用本方法，会先 addRecieved，随后真实入站 +1 时被误判「已收」→ 未读永远不加，会话无红点。
    if (flagNumToAdd <= 0) return flagNumToAdd;
    if ([[QoS4ReciveDaemon sharedInstance] hasRecieved:fingerPrint]) {
        BOOL chatSession = (alarmType == AMT_friendChatMessage || alarmType == AMT_guestChatMessage || alarmType == AMT_groupChatMessage);
        if (!chatSession) return 0;
        if (priorFpExisted) {
            return 0;
        }
        return flagNumToAdd;
    }
    [[QoS4ReciveDaemon sharedInstance] addRecievedWithFingerPrint:fingerPrint];
    return flagNumToAdd;
}

+ (AlarmDto *)addSingleChatMsgAlarmForLocal:(NSString *)friendUid friendName:(NSString *)friendName
                        withMsg:(NSString *)message andType:(int)messageType withAlarmType:(int)alarmType
{

    NSString *messageContentForShow = [JSQMessage parseMessageContentPreview:message withType:messageType];
    // 再加一个提示到首页消息列表中
   return [[[IMClientManager sharedInstance] getAlarmsProvider] addSingleChatMessageAlarm:friendUid friendName:friendName
         withConcentForShow:messageContentForShow flagNumToAdd:0 withDate:nil withAlarmType:alarmType fingerPrint:nil]; // 自已发的消息就不需要叠加（未读）数量的显示了
}

- (AlarmDto *)addSingleChatMessageAlarm:(NSString *)friendUid friendName:(NSString *)friendName
         withConcentForShow:(NSString *)messageContentForShow flagNumToAdd:(int)flagNumToAdd withDate:(NSDate *)time  withAlarmType:(int)alarmType fingerPrint:(NSString *)fingerPrint
{
    return [self addSingleChatMessageAlarm:friendUid friendName:friendName withConcentForShow:messageContentForShow flagNumToAdd:flagNumToAdd withDate:time withAlarmType:alarmType withNotify:YES fingerPrint:fingerPrint priorFingerPrintExistedInMemory:NO];
}

- (AlarmDto *)addSingleChatMessageAlarm:(NSString *)friendUid friendName:(NSString *)friendName
         withConcentForShow:(NSString *)messageContentForShow flagNumToAdd:(int)flagNumToAdd withDate:(NSDate *)time withAlarmType:(int)alarmType withNotify:(BOOL)notify fingerPrint:(NSString *)fingerPrint
{
    return [self addSingleChatMessageAlarm:friendUid friendName:friendName withConcentForShow:messageContentForShow flagNumToAdd:flagNumToAdd withDate:time withAlarmType:alarmType withNotify:notify fingerPrint:fingerPrint priorFingerPrintExistedInMemory:NO];
}

- (AlarmDto *)addSingleChatMessageAlarm:(NSString *)friendUid friendName:(NSString *)friendName
         withConcentForShow:(NSString *)messageContentForShow flagNumToAdd:(int)flagNumToAdd withDate:(NSDate *)time withAlarmType:(int)alarmType withNotify:(BOOL)notify fingerPrint:(NSString *)fingerPrint priorFingerPrintExistedInMemory:(BOOL)priorFpExisted
{
    __block AlarmDto *result = nil;
    APRunAlarmModelOnMain(^{
        @synchronized(self) {
            if (friendUid == nil) { result = nil; return; }
            int effective = [self effectiveFlagNumToAdd:flagNumToAdd forFingerPrint:fingerPrint conversationDataId:friendUid alarmType:alarmType priorFingerPrintExistedInMemory:priorFpExisted];
            if (alarmType == AMT_friendChatMessage) {
                int index = [self getAlarmIndex:AMT_guestChatMessage dataId:friendUid];
                if (index != -1) [self removeAlarm:index notify:notify deleteAlarmLocalData:YES deleteLocalData:NO];
            } else if (alarmType == AMT_guestChatMessage) {
                int index = [self getAlarmIndex:AMT_friendChatMessage dataId:friendUid];
                if (index != -1) [self removeAlarm:index notify:notify deleteAlarmLocalData:YES deleteLocalData:NO];
            }
            if ([self updateSingleChatMessageAlarm:friendUid friendName:friendName withConcentForShow:messageContentForShow flagNumToAdd:effective withDate:time withAlarmType:alarmType fingerPrint:nil]) {
                if ([AlarmUnreadDebugTrace isTargetUid:friendUid]) {
                    int idx = [self getAlarmIndex:alarmType dataId:friendUid];
                    int fv = -1;
                    if (idx != -1)
                        fv = [BasicTool getIntValue:((AlarmDto *)[[self getAlarmsData] get:idx]).flagNum];
                    [AlarmUnreadDebugTrace appendLine:[NSString stringWithFormat:@"更新已有行 req=%d eff=%d fp=%@ alarmType=%d finalFlag=%d", flagNumToAdd, effective, fingerPrint.length ? fingerPrint : @"-", alarmType, fv]
                                               source:@"AlarmsProvider.addSingle"
                                               forUid:friendUid];
                }
                result = nil;
                if (notify) {
                    [NotificationCenterFactory refreshMainPageTotalUnread_POST];
                }
                return;
            }
            AlarmDto *amd = [[AlarmDto alloc] init];
            amd.alarmType = alarmType;
            amd.dataId = friendUid;
            amd.title = ([BasicTool isStringEmpty:friendName] ? @"" : friendName);
            amd.alarmContent = messageContentForShow;
            amd.date = (time == nil ? [TimeTool getIOSDefaultDate] : time);
            amd.flagNum = [NSString stringWithFormat:@"%d", effective];
            [self addAlarm:amd notify:notify];
            [self saveAlarmToSqlite:amd debugTag:@"addChatMessageAlarm中的saveAlarmToSqlite:"];
            result = amd;
            if ([AlarmUnreadDebugTrace isTargetUid:friendUid]) {
                [AlarmUnreadDebugTrace appendLine:[NSString stringWithFormat:@"新建行 req=%d eff=%d fp=%@ alarmType=%d finalFlag=%@", flagNumToAdd, effective, fingerPrint.length ? fingerPrint : @"-", alarmType, amd.flagNum ?: @"?"]
                                           source:@"AlarmsProvider.addSingle"
                                           forUid:friendUid];
            }
            if (notify) {
                [NotificationCenterFactory refreshMainPageTotalUnread_POST];
            }
        }
    });
    return result;
}

/**
 * 更新“好友聊天消息”的item：当数据模型中已经存在好友请求通知时，就只需要更新
 * 数据模型中的此条Item，否则什么也不做。
 * @param fingerPrint 可选；用于单聊去重时由外层在调用前已做 effectiveFlagNumToAdd，此处传 nil 即可。
 */
- (BOOL)updateSingleChatMessageAlarm:(NSString *)friendUid friendName:(NSString *)friendName
                  withConcentForShow:(NSString *)messageContentForShow flagNumToAdd:(int) flagNumToAdd withDate:(NSDate *)alarmOriginalDate withAlarmType:(int)alarmType fingerPrint:(NSString *)fingerPrint
{
    int index = [self getAlarmIndex:alarmType dataId:friendUid];
    if(index != -1)
    {
        AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];
        amd.alarmContent = messageContentForShow;
        // 更新时间（如果指定了时间则显示给定的时间，否则默认显示当前时间）
        amd.date = (alarmOriginalDate == nil?[TimeTool getIOSDefaultDate]:alarmOriginalDate);
        amd.flagNum = [NSString stringWithFormat:@"%d", [BasicTool getIntValue:amd.flagNum] + flagNumToAdd]; // 更新总数

        // @since4.1：确保title是最新的
        amd.title = ([BasicTool isStringEmpty:friendName]?@"": friendName);

        // 将此人的陌生人消息放在系统消息列表的首位置，以便提示用户查看哦
        [[self getAlarmsData] remove:index needNotify:NO];
        [self addAlarm:amd];

        // 更新本地db的存储
        [self saveAlarmToSqlite:amd debugTag:@"updateChatMessageAlarm中的saveAlarmToSqlite:"];

        return YES;
    }
    return NO;
}
//--------------------------------------------------------------------------------------- END


//--------------------------------------------------------------------------------------- START
#pragma mark - 【7】好友请求相关

- (void)addAddFriendBeRejectAlarm:(NSString *)friendUid friendName:(NSString *)friendName
{
    if(friendUid == nil)
        return;

    APRunAlarmModelOnMain(^{
        AlarmDto *amd = [[AlarmDto alloc] init];
        amd.alarmType = AMT_addFriendBeReject;
        amd.dataId = friendUid;
        amd.title = @"加好友请求被拒";
        amd.alarmContent = [NSString stringWithFormat:@"对不起， %@ 拒绝了您的添加好友请求.", friendName];
        amd.date = [TimeTool getIOSDefaultDate];
        [self addAlarm:amd];
    });
}

/**
 * 添好"加好友失败信息"的alarm（这些错误信息可能是：比如服务端在执行的过程中出错等等，这肯定是要让好友请求发起方知道的，不然这请求到底去哪里了？对方有没有收到呢？）.
 *
 * @param errorContent 错误信息内容
 */
- (void)addAddFriendThrowErrorAlarm:(NSString *)errorContent
{
    if(errorContent == nil)
        return;

    APRunAlarmModelOnMain(^{
        AlarmDto *amd = [[AlarmDto alloc] init];
        amd.alarmType = AMT_addFriendThrowError;
        amd.title = @"加好友失败信息";
        amd.alarmContent = errorContent;
        amd.date = [TimeTool getIOSDefaultDate];
        [self addAlarm:amd];
    });
}

// 新增一条“加好友确认提醒”的item到数据模型中：此方法将自动判定该item是否已存在于数据模型中，如果已存在则更新之，否则新建之
- (AlarmDto *)addAddFriendReqMergeAlarm:(NSString *)friendUid friendName:(NSString *)friendName reqTime:(NSDate *)reqTime numToAdd:(int)flagNumToAdd notify:(BOOL)notifyObserver merge:(BOOL)mergeIfExsits
{
    if(friendUid == nil)
        return nil;

    __block AlarmDto *out = nil;
    APRunAlarmModelOnMain(^{
        AlarmDto *amd = nil;
        if((amd = [self updateAddFriendReqMergeAlarm:friendUid friendName:friendName reqTime:reqTime numToAdd:flagNumToAdd notify:notifyObserver merge:mergeIfExsits]) != nil) {
            out = amd;
            return;
        }
        amd = [AlarmsProvider constructAddFriendReqAlarm:friendUid friendName:friendName reqTime:reqTime extraString1:nil numToAdd:flagNumToAdd];
        out = [self addAlarm:amd notify:notifyObserver];
    });
    return out;
}

/**
 * 更新“加好友确认提醒”的item：当数据模型中已经存在好友请求通知时，就只需要更新数据模型中的此条Item，否则什么也不做.
 *
 * @param flagNumToAdd 本次传过来的未处理数
 * @param notifyObserver true表示要通知观察者，此观察者通常用于刷新UI之用，所以可以将此参数理解为更新完数据模型后是否要刷新ui
 * @param mergeTheNum YES表示当要添加的alarm已存在于数据模型时就合并它们的总数，否则不合并只替换（即未读数用本次的数量而不是叠加）
 * @return 非nil表示已存在于数据模型中且本次更新成功，否则表示该Alarm尚不存在于数据模型中
 */
- (AlarmDto *)updateAddFriendReqMergeAlarm:(NSString *)friendUid friendName:(NSString *)friendName reqTime:(NSDate *)reqTime numToAdd:(int)flagNumToAdd notify:(BOOL)notifyObserver merge:(BOOL)mergeTheNum
{
    int index = [self getAlarmIndex:AMT_addFriendRequest dataId:nil];
    if(index != -1)
    {
        AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];
        amd.alarmContent = [NSString stringWithFormat:@"%@ 邀请您成为好友", friendName];
        amd.date = (reqTime == nil?[TimeTool getIOSDefaultDate]:reqTime);
        amd.flagNum = [NSString stringWithFormat:@"%d"
                       , mergeTheNum?([BasicTool getIntValue:amd.flagNum] + flagNumToAdd):flagNumToAdd];
        [[self getAlarmsData] remove:index needNotify:NO];
        return [self addAlarm:amd  notify:notifyObserver];
    }
    return nil;
}

+ (AlarmDto *)constructAddFriendReqAlarm:(NSString *)friendUid friendName:(NSString *)friendName reqTime:(NSDate *)reqTime extraString1:(NSString *)extraString1 numToAdd:(int)flagNumToAdd
{
    AlarmDto *amd = [[AlarmDto alloc] init];
    amd.alarmType = AMT_addFriendRequest;
    amd.dataId = friendUid;
    amd.title = @"确认提醒";
    amd.alarmContent = [NSString stringWithFormat:@"%@ 邀请您成为好友", friendName];

//    // 根据约定：目前ex10字段仅用于存放“添加好友”请求时的发生时间java时间戳（由服务端设置的，
//    // 详见：RosterElementEntity类），其不为空仅限于此场景下，其它场景下用默认系统时间即可
//    // 自20180507 RBv4.3以后，本字段存放的是时间戳，而非人类可读的时间字串
////    BOOL dateIsEmpty = [BasicTool isStringEmpty:srcUserInfo.ex10];
////    amd.date = dateIsEmpty?[BasicTool getCurrentTimePartStr]:srcUserInfo.ex10;
//    NSDate *reqTime = [TimeTool convertJavaTimestampToiOSDate:srcUserInfo.ex10];
    // 目前当且仅当用于构建好加友请求的“通知”时本字段不为空且为加好友请求发起时间
    amd.date = (reqTime == nil?[TimeTool getIOSDefaultDate]:reqTime);

    amd.extraString1 = extraString1;
    
    amd.flagNum = [NSString stringWithFormat:@"%d", flagNumToAdd];

//    // 把请求的源好友信息也保存起来备用
//    // 注意：为了防止发生野指针错误（即“exc_bad_access(code=1,address=0x0)”问题发生，
//    //      此处务必保证保存的对象是其深度克隆体，而此处存放的目的仅是为了点击列表Item时使
//    //      用该数据，而非故意浅拷贝（或持有该对象指针），所以此处的克隆是完全合情合理！！
//    amd.extraObj = [srcUserInfo clone];
    return amd;
}

- (void)resetAddFriendReqAlarmFlagNum
{
    APRunAlarmModelOnMain(^{
        (void)[self resetFlagNum:[self getAlarmIndex:AMT_addFriendRequest dataId:nil]];
    });
}
//--------------------------------------------------------------------------------------- END


//--------------------------------------------------------------------------------------- START
#pragma mark - 【8】群组聊天消息相关

+ (NSString *)rb_displayNameForLocalUserGroupPreview {
    UserEntity *loc = [IMClientManager sharedInstance].localUserInfo;
    if (loc != nil) {
        NSString *nn = [loc getNickNameWithRemark];
        if (![BasicTool isStringEmpty:[BasicTool trim:nn]]) {
            return nn;
        }
        if (![BasicTool isStringEmpty:[BasicTool trim:loc.nickname]]) {
            return loc.nickname;
        }
    }
    return @"我";
}

+ (NSString *)rb_resolvedGroupConversationPreviewSenderNick:(NSString *)serverNick senderUid:(NSString *)senderUid
{
    NSString *t = [BasicTool trim:serverNick];
    if (t.length > 0 && ![t isEqualToString:@"0"]) {
        return t;
    }
    NSString *uid = [BasicTool trim:senderUid];
    if (uid.length == 0 || [uid isEqualToString:@"0"]) {
        return @"";
    }
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (localUid.length > 0 && [uid isEqualToString:localUid]) {
        return [AlarmsProvider rb_displayNameForLocalUserGroupPreview];
    }
    @try {
        FriendsListProvider *flp = [[IMClientManager sharedInstance] getFriendsListProvider];
        if (flp != nil && [flp isUserInRoster2:uid]) {
            UserEntity *ree = [flp getFriendInfoByUid2:uid];
            if (ree != nil) {
                NSString *nk = [BasicTool trim:[ree getNickNameWithRemark]];
                if (nk.length > 0) {
                    return nk;
                }
            }
        }
    } @catch (__unused NSException *e) {
    }
    return @"";
}

// 将本地用户主动发出的群组聊天消息也入到首页消息栏里。
+ (AlarmDto *) addAGroupChatMsgAlarmForLocal:(int)msgType gid:(NSString *)toGid gname:(NSString *)toGname msg:(NSString *)msg
{
    NSString *fromNick = [AlarmsProvider rb_displayNameForLocalUserGroupPreview];
    return [[[IMClientManager sharedInstance] getAlarmsProvider] addAGroupChatMsgAlarm:msgType
                                                                            gid:toGid
                                                                          gname:toGname
                                                               fromUserNickName:fromNick
                                                                            msg:msg
                                                                           date:nil
                                                                   flagNumToAdd:0
                                                                            at:NO
                                                                   fingerPrint:nil];
}

// 添加"群组聊天消息"类型的alarm.
- (AlarmDto *) addAGroupChatMsgAlarm:(int)msgType
                           gid:(NSString *)toGid
                         gname:(NSString *)toGname
              fromUserNickName:(NSString *)fromUserNickName
                           msg:(NSString *)msg
                          date:(NSDate *)time
                  flagNumToAdd:(int)flagNumToAdd
                            at:(BOOL)atMe
                   fingerPrint:(NSString *)fingerPrint
{
    return [self addAGroupChatMsgAlarm:msgType gid:toGid gname:toGname fromUserNickName:fromUserNickName msg:msg date:time flagNumToAdd:flagNumToAdd at:atMe withNotify:YES fingerPrint:fingerPrint priorFingerPrintExistedInMemory:NO];
}

- (AlarmDto *)addAGroupChatMsgAlarm:(int)msgType gid:(NSString *)toGid gname:(NSString *)toGname
              fromUserNickName:(NSString *)fromUserNickName msg:(NSString *)msg date:(NSDate *)time
                  flagNumToAdd:(int)flagNumToAdd at:(BOOL)atMe withNotify:(BOOL)notify fingerPrint:(NSString *)fingerPrint
{
    return [self addAGroupChatMsgAlarm:msgType gid:toGid gname:toGname fromUserNickName:fromUserNickName msg:msg date:time flagNumToAdd:flagNumToAdd at:atMe withNotify:notify fingerPrint:fingerPrint priorFingerPrintExistedInMemory:NO];
}

- (AlarmDto *)addAGroupChatMsgAlarm:(int)msgType gid:(NSString *)toGid gname:(NSString *)toGname
              fromUserNickName:(NSString *)fromUserNickName msg:(NSString *)msg date:(NSDate *)time
                  flagNumToAdd:(int)flagNumToAdd at:(BOOL)atMe withNotify:(BOOL)notify fingerPrint:(NSString *)fingerPrint priorFingerPrintExistedInMemory:(BOOL)priorFpExisted
{
    __block AlarmDto *result = nil;
    APRunAlarmModelOnMain(^{
        int effective = [self effectiveFlagNumToAdd:flagNumToAdd forFingerPrint:fingerPrint conversationDataId:toGid alarmType:AMT_groupChatMessage priorFingerPrintExistedInMemory:priorFpExisted];
        if ([self addSameGroupChatMsgDTO:msgType gid:toGid gname:toGname fromUserNickName:fromUserNickName msg:msg date:time flagNumToAdd:effective at:atMe]) {
            result = nil;
            if (notify) {
                [NotificationCenterFactory refreshMainPageTotalUnread_POST];
            }
            return;
        }
        AlarmDto *amd = [[AlarmDto alloc] init];
        amd.alarmType = AMT_groupChatMessage;
        amd.dataId = toGid;
        amd.title = (toGname ?: @"");
        NSString *msgContent = @"";
        if (msgType == TM_TYPE_REVOKE)
            msgContent = [JSQMessage parseMessageContentPreview:msg withType:msgType];
        else
            msgContent = [NSString stringWithFormat:@"%@%@", ([BasicTool isStringEmpty:[BasicTool trim:fromUserNickName]] ? @"" : [NSString stringWithFormat:@"%@: ", fromUserNickName]), [JSQMessage parseMessageContentPreview:msg withType:msgType]];
        amd.alarmContent = msgContent;
        amd.date = (time == nil ? [TimeTool getIOSDefaultDate] : time);
        amd.flagNum = [NSString stringWithFormat:@"%d", effective];
        amd.atMe = atMe;
        [self addAlarm:amd notify:notify];
        [self saveAlarmToSqlite:amd debugTag:@"addAGroupChatMsgAlarm中的saveAlarmToSqlite:"];
        result = amd;
        if (notify) {
            [NotificationCenterFactory refreshMainPageTotalUnread_POST];
        }
    });
    return result;
}

// 如此该条Alarm已经存在于首页列表里，则合并之并移到列表首位置。
- (BOOL) addSameGroupChatMsgDTO:(int)msgType
                            gid:(NSString *)toGid
                          gname:(NSString *)toGname
               fromUserNickName:(NSString *)fromUserNickName
                            msg:(NSString *)msg
                           date:(NSDate *)time
                   flagNumToAdd:(int)flagNumToAdd
                             at:(BOOL)atMe
{
    // 找到这条Alarm目前处于列表的索引位置
    int index = [self getAlarmIndex:AMT_groupChatMessage dataId:toGid];
    if(index != -1)
    {
        //** 以下代码将用最新的数据更新此条Alarm（注意是更新不是新增哦！）
        AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:index];

        amd.title = (toGname ?: @"");

        NSString *msgContent = @"";
        if(msgType == TM_TYPE_REVOKE)
            msgContent = [JSQMessage parseMessageContentPreview:msg withType:msgType];
        else
            msgContent = [NSString stringWithFormat:@"%@%@", ([BasicTool isStringEmpty:[BasicTool trim:fromUserNickName]]?@"":[NSString stringWithFormat:@"%@: ", fromUserNickName]), [JSQMessage parseMessageContentPreview:msg withType:msgType]];
        
        amd.alarmContent = msgContent;
        amd.date = (time == nil? [TimeTool getIOSDefaultDate]: time); // 更新时间
        amd.flagNum = [NSString stringWithFormat:@"%d", ([BasicTool getIntValue:amd.flagNum] + flagNumToAdd)]; // 更新未读总数
        amd.atMe = (![amd isAtMe] ? atMe : [amd isAtMe]); // 确保如果之前有"有人@我"标识时，不被清除掉！

//        amd.extraObj = toGid;

        // 将此消息放在系统消息列表的首位置，以便提示用户查看哦
        [[self getAlarmsData] remove:index needNotify:NO];
        [self addAlarm:amd];

        // 更新本地db的存储
        [self saveAlarmToSqlite:amd debugTag:@"addSameGroupChatMsgDTO中的saveAlarmToSqlite:"];

        return YES;
    }
    return NO;
}

// 获得群聊聊天消息的未读数量.
- (int) getGroupChatMessageFlagNum:(NSString *)gid
{
    __block int n = 0;
    APRunAlarmModelOnMain(^{
        n = [self getFlagNum:[self getAlarmIndex:AMT_groupChatMessage dataId:gid]];
    });
    return n;
}

// 移除群聊在首页"消息"列表上的item.
- (void) removeGroupChatMessageAlarm:(NSString *)gid
{
    APRunAlarmModelOnMain(^{
        int index = [self getAlarmIndex:AMT_groupChatMessage dataId:gid];
        if([self checkIndexValid:index])
            [self removeAlarm:index notify:YES deleteAlarmLocalData:YES deleteLocalData:YES];
    });
}

static NSCache<NSString *, NSString *> *sRBGroupPreviewNickCache;
static NSMutableSet<NSString *> *sRBGroupPreviewInflightKeys;
static NSObject *sRBGroupPreviewNickLock;

static void RBGroupPreviewNickEnsureStatics(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sRBGroupPreviewNickCache = [[NSCache alloc] init];
        sRBGroupPreviewNickCache.countLimit = 800;
        sRBGroupPreviewInflightKeys = [[NSMutableSet alloc] init];
        sRBGroupPreviewNickLock = [[NSObject alloc] init];
    });
}

/// 1008-3-8 返回的用户展示昵称
static NSString *RBDisplayNickFromUserEntity(UserEntity *u)
{
    if (u == nil) return @"";
    NSString *nk = [BasicTool trim:[u getNickNameWithRemark]];
    if (nk.length > 0) return nk;
    return [BasicTool trim:u.nickname];
}

- (void)rb_applyResolvedGroupPreviewNick:(NSString *)nick gid:(NSString *)gid msgType:(int)msgType rawMsg:(NSString *)rawMsg
{
    NSString *t = [BasicTool trim:nick];
    if (t.length == 0 || gid.length == 0) return;
    NSString *bare = [JSQMessage parseMessageContentPreview:rawMsg withType:msgType];
    APRunAlarmModelOnMain(^{
        int idx = [self getAlarmIndex:AMT_groupChatMessage dataId:gid];
        if (![self checkIndexValid:idx]) return;
        AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:idx];
        if (amd == nil) return;
        NSString *cur = [BasicTool trim:amd.alarmContent];
        NSString *trimRaw = [BasicTool trim:rawMsg];
        NSString *trimBare = [BasicTool trim:bare];
        BOOL stillBare = (cur.length == 0)
            || [cur isEqualToString:trimBare]
            || [cur isEqualToString:trimRaw];
        if (!stillBare) return;
        amd.alarmContent = [NSString stringWithFormat:@"%@: %@", t, bare.length ? bare : @""];
        [self saveAlarmToSqlite:amd debugTag:@"rb_applyResolvedGroupPreviewNick"];
        [[self getAlarmsData] notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];
        [NotificationCenterFactory refreshMainPageTotalUnread_POST];
    });
}

- (void)rb_scheduleResolveGroupPreviewSenderNickForGid:(NSString *)gid senderUid:(NSString *)senderUid msgType:(int)msgType rawMsg:(NSString *)rawMsg
{
    RBGroupPreviewNickEnsureStatics();
    NSString *gidTrim = [BasicTool trim:gid];
    NSString *uid = [BasicTool trim:senderUid];
    if (gidTrim.length == 0 || uid.length == 0 || [uid isEqualToString:@"0"]) return;
    NSString *loc = [BasicTool trim:[[IMClientManager sharedInstance].localUserInfo user_uid]];
    if (loc.length > 0 && [uid isEqualToString:loc]) return;

    NSString *cached = [sRBGroupPreviewNickCache objectForKey:uid];
    if (cached.length > 0) {
        [self rb_applyResolvedGroupPreviewNick:cached gid:gidTrim msgType:msgType rawMsg:rawMsg];
        return;
    }

    NSString *inflightKey = [NSString stringWithFormat:@"%@|%@", gidTrim, uid];
    @synchronized (sRBGroupPreviewNickLock) {
        if ([sRBGroupPreviewInflightKeys containsObject:inflightKey]) return;
        [sRBGroupPreviewInflightKeys addObject:inflightKey];
    }

    void (^finish)(NSString *nick) = ^(NSString *nick) {
        @synchronized (sRBGroupPreviewNickLock) {
            [sRBGroupPreviewInflightKeys removeObject:inflightKey];
        }
        NSString *nk = [BasicTool trim:nick];
        if (nk.length > 0) {
            [sRBGroupPreviewNickCache setObject:nk forKey:uid];
        }
        AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
        if (ap != nil && nk.length > 0) {
            [ap rb_applyResolvedGroupPreviewNick:nk gid:gidTrim msgType:msgType rawMsg:rawMsg];
        }
    };

    [[HttpRestHelper sharedInstance] submitGetFriendInfoToServer:NO mail:nil uid:uid complete:^(BOOL sucess, UserEntity *userInfo) {
        NSString *nk = (sucess ? RBDisplayNickFromUserEntity(userInfo) : @"");
        if (nk.length > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ finish(nk); });
            return;
        }
        NSString *reqUid = [BasicTool trim:[[IMClientManager sharedInstance].localUserInfo user_uid]] ?: @"";
        [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:gidTrim requestUid:reqUid page:1 pageSize:500 complete:^(BOOL sucess2, NSMutableArray<GroupMemberEntity *> *groupMembersList) {
            NSString *nk2 = @"";
            if (sucess2 && groupMembersList.count > 0) {
                for (GroupMemberEntity *m in groupMembersList) {
                    if (![[BasicTool trim:m.user_uid] isEqualToString:uid]) continue;
                    nk2 = [BasicTool trim:[GroupsProvider getNickNameInGroup:m.nickname and:m.nickname_ingroup]];
                    break;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{ finish(nk2); });
        } hudParentView:nil];
    } hudParentView:nil];
}
//--------------------------------------------------------------------------------------- END


//--------------------------------------------------------------------------------------- START
#pragma mark - 【9】置顶和取消置顶相关

// 实现首页"消息"置顶的完整逻辑实现
+ (void)doSetAlwaysTopNow:(BOOL)alwaysTop alarmType:(int)alarmType dataId:(NSString *)dataId title:(NSString *)title {
    APRunAlarmModelOnMain(^{
        AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
        if (ap == nil)
            return;

        AlarmDto *amd = [ap getAlarmDto:alarmType dataId:dataId];
        if (amd == nil) {
            if(alarmType == AMT_groupChatMessage)
                amd = [AlarmsProvider addAGroupChatMsgAlarmForLocal:TM_TYPE_TEXT gid:dataId gname:title msg:@"点此随时可开始群聊。"];
            else if(alarmType == AMT_friendChatMessage)
                amd = [AlarmsProvider addSingleChatMsgAlarmForLocal:dataId friendName:title withMsg:@"点此随时可开始聊天。" andType:TM_TYPE_TEXT withAlarmType:AMT_friendChatMessage];
            else if(alarmType == AMT_guestChatMessage)
                amd = [AlarmsProvider addSingleChatMsgAlarmForLocal:dataId friendName:title withMsg:@"点此随时可开始聊天。" andType:TM_TYPE_TEXT withAlarmType:AMT_guestChatMessage];
            else
                DDLogWarn(@"AlarmsProvider-doSetAlwaysTopNow时无效的alarmType类型，alarmType=%d", alarmType);
        }

        [ap setAlwaysTop:alwaysTop amd:amd];
    });
}

// 该单聊聊天的Alarm是否是置顶的
- (BOOL)isAlwaysTop4Single:(NSString *)dataId {
    return [self isAlwaysTop4Friend:dataId] || [self isAlwaysTop4Guest:dataId];
}

/**
 * 该好友聊天的Alarm是否是置顶的。
 *
 * @param dataId id值
 * @return true表示是，否则不是
 */
- (BOOL)isAlwaysTop4Friend:(NSString *)dataId {
    return [self isAlwaysTop:AMT_friendChatMessage dataId:dataId];
}

/**
 * 该陌生人聊天的Alarm是否是置顶的。
 *
 * @param dataId id值
 * @return true表示是，否则不是
 */
- (BOOL)isAlwaysTop4Guest:(NSString *)dataId {
    return [self isAlwaysTop:AMT_guestChatMessage dataId:dataId];
}

// 该聊天的Alarm是否是置顶的 
- (BOOL)isAlwaysTop:(int)alarmType dataId:(NSString *)dataId {
    __block BOOL top = NO;
    APRunAlarmModelOnMain(^{
        AlarmDto *dto = [self getAlarmDto:alarmType dataId:dataId];
        top = (dto != nil && [dto isAlwaysTop]);
    });
    return top;
}

// 设置指定的首页"消息"item数据对象的置顶标识（默认更新到sqlite中）。
- (void) setAlwaysTop:(BOOL)alwaysTop amd:(AlarmDto *)amd
{
    [self setAlwaysTop:alwaysTop amd:amd updateToSqlite:YES];
}
- (void) setAlwaysTop:(BOOL)alwaysTop amd:(AlarmDto *)amd updateToSqlite:(BOOL)updateToSqlite
{
    APRunAlarmModelOnMain(^{
        if(amd != nil)
        {
            if(amd.alarmType == AMT_groupChatMessage
               || amd.alarmType == AMT_friendChatMessage
               || amd.alarmType == AMT_guestChatMessage)
            {
                amd.alwaysTop = alwaysTop;
                NSString *srcUidOrGid = amd.dataId;
                int currentIndex = [self getAlarmIndex:amd.alarmType dataId:srcUidOrGid];
                if(currentIndex != -1)
                    [self removeAlarm:currentIndex notify:NO deleteAlarmLocalData:NO deleteLocalData:NO];
                [self addAlarm:amd];
                if (updateToSqlite)
                {
                    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
                    if (localRee == nil)
                        return;
                    if (srcUidOrGid != nil)
                    {
                        [self saveAlarmToSqlite:amd debugTag:@"AlarmsProvider.setAlwaysTop-saveAlarmToSqlite"];
                    }
                    else
                        DDLogWarn(@"AlarmsProvider-setAlwaysTop时srcUidOrGid=%@", srcUidOrGid);
                }
                else
                    DDLogWarn(@"AlarmsProvider-setAlwaysTop时不需要更新sqlite(updateToSqlite==false)!");
            }
            else
                DDLogWarn(@"AlarmsProvider-setAlwaysTop时不支持的messsageType!");
        }
        else
            DDLogWarn(@"AlarmsProvider-setAlwaysTop时amd=null!");
    });
}

- (BOOL)isArchived:(int)alarmType dataId:(NSString *)dataId
{
    __block BOOL archived = NO;
    APRunAlarmModelOnMain(^{
        AlarmDto *dto = [self getAlarmDto:alarmType dataId:dataId];
        archived = (dto != nil && dto.archived);
    });
    return archived;
}

- (void)setArchived:(BOOL)archived amd:(AlarmDto *)amd
{
    [self setArchived:archived amd:amd updateToSqlite:YES];
}

- (void)setArchived:(BOOL)archived amd:(AlarmDto *)amd updateToSqlite:(BOOL)updateToSqlite
{
    APRunAlarmModelOnMain(^{
        if (amd == nil) {
            DDLogWarn(@"AlarmsProvider-setArchived时amd=null!");
            return;
        }
        if (!(amd.alarmType == AMT_groupChatMessage
              || amd.alarmType == AMT_friendChatMessage
              || amd.alarmType == AMT_guestChatMessage)) {
            DDLogWarn(@"AlarmsProvider-setArchived时不支持的messsageType!");
            return;
        }

        amd.archived = archived;
        amd.archivedAt = archived ? [TimeTool getIOSDefaultTimeStamp_l] : 0;
        [[self getAlarmsData] notifyObservers:UpdateTypeToObserverUNKNOW whithExtra:nil];

        if (updateToSqlite) {
            UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
            if (localRee == nil) {
                return;
            }
            [self saveAlarmToSqlite:amd debugTag:@"AlarmsProvider.setArchived-saveAlarmToSqlite"];
        }
    });
}
//--------------------------------------------------------------------------------------- END


//--------------------------------------------------------------------------------------- START
#pragma mark - 【10】已读和未读设置相关

// 设置已读或未读（本方法自动同步到sqlite中对应的数据，以便离线或下次app启动时保留现在的设置）。
- (void) setupReadOrUnread:(AlarmDto *)amd hasRead:(BOOL)hasRead
{
    APRunAlarmModelOnMain(^{
        if(amd != nil)
        {
            int flagNumToRest = hasRead?0:1;
            if (amd.alarmType == AMT_groupChatMessage
                || amd.alarmType == AMT_friendChatMessage
                || amd.alarmType == AMT_guestChatMessage)
                [self resetFlagNum:amd.alarmType dataId:amd.dataId flagNumToReset:flagNumToRest needUpdateSqlite:YES];
            else
                DDLogWarn(@"AlarmsProvider-【设置已读和未读】时不支持的messsageType!");
        }
        else
            DDLogWarn(@"AlarmsProvider-【设置已读和未读】时amd=null!");
    });
}
//--------------------------------------------------------------------------------------- END

#pragma mark - 【1008-26-7】后台解析后主线程批量应用

- (AlarmDto *)rb_getAlarmDtoDirect:(int)alarmType dataId:(NSString *)dataId
{
    for (int i = 0; i < [[[self getAlarmsData] getDataList] count]; i++) {
        AlarmDto *amd = (AlarmDto *)[[self getAlarmsData] get:i];
        if (amd.alarmType == alarmType) {
            if (dataId != nil) {
                if (amd.dataId != nil && [amd.dataId isEqualToString:dataId]) {
                    return amd;
                }
            } else {
                return amd;
            }
        }
    }
    return nil;
}

- (void)rb_internalAddSingleChat26_7WithFriendUid:(NSString *)friendUid
                                       friendName:(NSString *)friendName
                                   contentForShow:(NSString *)messageContentForShow
                                             date:(NSDate *)time
                                        alarmType:(int)alarmType
                                           notify:(BOOL)notify
{
    @synchronized(self) {
        if (friendUid == nil) { return; }
        int effective = [self effectiveFlagNumToAdd:0 forFingerPrint:nil conversationDataId:friendUid alarmType:alarmType priorFingerPrintExistedInMemory:NO];
        if (alarmType == AMT_friendChatMessage) {
            int index = [self getAlarmIndex:AMT_guestChatMessage dataId:friendUid];
            if (index != -1) [self removeAlarm:index notify:notify deleteAlarmLocalData:YES deleteLocalData:NO];
        } else if (alarmType == AMT_guestChatMessage) {
            int index = [self getAlarmIndex:AMT_friendChatMessage dataId:friendUid];
            if (index != -1) [self removeAlarm:index notify:notify deleteAlarmLocalData:YES deleteLocalData:NO];
        }
        if ([self updateSingleChatMessageAlarm:friendUid friendName:friendName withConcentForShow:messageContentForShow flagNumToAdd:effective withDate:time withAlarmType:alarmType fingerPrint:nil]) {
            if (notify) {
                [NotificationCenterFactory refreshMainPageTotalUnread_POST];
            }
            return;
        }
        AlarmDto *amd = [[AlarmDto alloc] init];
        amd.alarmType = alarmType;
        amd.dataId = friendUid;
        amd.title = ([BasicTool isStringEmpty:friendName] ? @"" : friendName);
        amd.alarmContent = messageContentForShow;
        amd.date = (time == nil ? [TimeTool getIOSDefaultDate] : time);
        amd.flagNum = [NSString stringWithFormat:@"%d", effective];
        [self addAlarm:amd notify:notify];
        [self saveAlarmToSqlite:amd debugTag:@"addChatMessageAlarm中的saveAlarmToSqlite:"];
        if (notify) {
            [NotificationCenterFactory refreshMainPageTotalUnread_POST];
        }
    }
}

- (void)rb_internalAddGroupChat26_7WithMsgType:(int)msgType
                                           gid:(NSString *)toGid
                                         gname:(NSString *)toGname
                              fromUserNickName:(NSString *)fromUserNickName
                                           msg:(NSString *)msg
                                          date:(NSDate *)time
                                         notify:(BOOL)notify
{
    int effective = [self effectiveFlagNumToAdd:0 forFingerPrint:nil conversationDataId:toGid alarmType:AMT_groupChatMessage priorFingerPrintExistedInMemory:NO];
    if ([self addSameGroupChatMsgDTO:msgType gid:toGid gname:toGname fromUserNickName:fromUserNickName msg:msg date:time flagNumToAdd:effective at:NO]) {
        if (notify) {
            [NotificationCenterFactory refreshMainPageTotalUnread_POST];
        }
        return;
    }
    AlarmDto *amd = [[AlarmDto alloc] init];
    amd.alarmType = AMT_groupChatMessage;
    amd.dataId = toGid;
    amd.title = (toGname ?: @"");
    NSString *msgContent = @"";
    if (msgType == TM_TYPE_REVOKE)
        msgContent = [JSQMessage parseMessageContentPreview:msg withType:msgType];
    else
        msgContent = [NSString stringWithFormat:@"%@%@", ([BasicTool isStringEmpty:[BasicTool trim:fromUserNickName]] ? @"" : [NSString stringWithFormat:@"%@: ", fromUserNickName]), [JSQMessage parseMessageContentPreview:msg withType:msgType]];
    amd.alarmContent = msgContent;
    amd.date = (time == nil ? [TimeTool getIOSDefaultDate] : time);
    amd.flagNum = [NSString stringWithFormat:@"%d", effective];
    amd.atMe = NO;
    [self addAlarm:amd notify:notify];
    [self saveAlarmToSqlite:amd debugTag:@"addAGroupChatMsgAlarm中的saveAlarmToSqlite:"];
    if (notify) {
        [NotificationCenterFactory refreshMainPageTotalUnread_POST];
    }
}

#pragma mark - 草稿相关方法

/**
 * 检查指定 alarm 是否有草稿
 */
- (BOOL)hasDraftForAlarm:(AlarmDto *)alarm
{
    if (!alarm || !alarm.dataId || alarm.dataId.length == 0) {
        return NO;
    }
    
    // 根据 alarmType 获取对应的 chatType
    int chatType = -1;
    if (alarm.alarmType == AMT_friendChatMessage) {
        chatType = CHAT_TYPE_FREIDN_CHAT;
    } else if (alarm.alarmType == AMT_guestChatMessage) {
        chatType = CHAT_TYPE_GUEST_CHAT;
    } else if (alarm.alarmType == AMT_groupChatMessage) {
        chatType = CHAT_TYPE_GROUP_CHAT;
    } else {
        return NO; // 不支持的 alarmType
    }
    
    // 生成草稿 key
    NSString *draftKey = [NSString stringWithFormat:@"chat_draft_%d_%@", chatType, alarm.dataId];
    
    // 从 NSUserDefaults 读取草稿
    NSString *draftText = [[NSUserDefaults standardUserDefaults] objectForKey:draftKey];
    if (draftText && draftText.length > 0) {
        // 去除首尾空白字符
        draftText = [draftText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (draftText.length > 0) {
            return YES;
        }
    }
    
    return NO;
}

@end
