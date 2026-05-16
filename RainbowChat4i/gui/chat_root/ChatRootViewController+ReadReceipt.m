//
//  ChatRootViewController+ReadReceipt.m
//  已读回执：上报、查询、MT61 与 SyncKey 同步回调。
//

#import "ChatRootViewController+ReadReceipt.h"
#import "ChatRootViewController.h"
#import "BasicTool.h"
#import "HttpRestHelper.h"
#import "JSQMessage.h"
#import "IMClientManager.h"
#import "AlarmsProvider.h"
#import "AlarmType.h"
#import "MsgBodyRoot.h"
#import "NotificationCenterFactory.h"
#import "CocoaLumberjack.h"
#import "SendDataHelper.h"
#import "UserProtocalsType.h"
#import "ClientCoreSDK.h"
#import "ErrorCode.h"
#import "TimeTool.h"
#import "MyDataBase.h"

static NSString *RBPartnerReadWatermarkDefaultsKey(NSString *ownerUid, NSString *peerUid, int chatType)
{
    if (ownerUid.length == 0 || peerUid.length == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"rb.prw.v1.%@.%@.%d", ownerUid, peerUid, chatType];
}

@interface ChatRootViewController (ReadReceiptPrivate)
@property (nonatomic, copy) NSString *partnerLastReadTime2;
@property (nonatomic, assign) NSTimeInterval lastReadReceiptReportTime;
/// 与 ChatRootViewController.m class extension 为同一 ivar（分类编译单元需前置声明）
@property (nonatomic, assign) NSTimeInterval lastPartnerReadReceiptQueryWallTime;
- (NSMutableArray<JSQMessage *> *)getChattingDatasList;
- (void)resetUnreadCount;
/// 收集 readByPartner 变化的 indexPath；outPaths 可为 nil（等价于仅返回 BOOL）
- (BOOL)rb_updateMessagesReadStatusCollectingChangedPaths:(NSMutableArray<NSIndexPath *> * _Nullable)outPaths;
/// 已读仅影响勾与时间展示，cell 高度不变：优先 reloadItems，批量过大时回退整表
- (void)rb_reloadCellsForReadReceiptChanges:(NSArray<NSIndexPath *> *)changedPaths;
/// 将当前水位对应的本会话 outgoing 已读状态写入 SQLite，下次进会话从库即可展示双勾
- (void)rb_persistOutgoingReadByPartnerWatermark:(long long)partnerReadMs;
- (NSString *)rb_partnerReadWatermarkDefaultsKeyForCurrentChat;
- (void)rb_savePartnerReadWatermarkIfHigher:(long long)ms;
@end

static const NSTimeInterval kPartnerReadReceiptQueryMinInterval = 3.0;

@implementation ChatRootViewController (ReadReceipt)

#pragma mark - 【v11.x 新增】已读回执相关方法

- (void)reportReadReceiptIfNeededWithForce:(BOOL)forceReport
{
    NSString *luid = self.senderId;
    NSString *partnerId = self.toId;
    if ([BasicTool isStringEmpty:luid] || [BasicTool isStringEmpty:partnerId]) return;

    NSArray<JSQMessage *> *datasList = [self getChattingDatasList];
    if (datasList == nil || datasList.count == 0) return;

    if (!forceReport) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
            if (self.lastReadReceiptReportTime > 0 && (now - self.lastReadReceiptReportTime) < 5.0) {
                DDLogDebug(@"【已读回执】群聊节流：距上次上报仅 %.1f 秒，跳过本次", now - self.lastReadReceiptReportTime);
                return;
            }
        } else if (self.chatType == CHAT_TYPE_FREIDN_CHAT || self.chatType == CHAT_TYPE_GUEST_CHAT) {
            if (self.lastReadReceiptReportTime > 0 && (now - self.lastReadReceiptReportTime) < 3.0) {
                DDLogDebug(@"【已读回执】单聊节流：距上次上报仅 %.1f 秒，跳过本次", now - self.lastReadReceiptReportTime);
                return;
            }
        }
    }

    // last_read_time2：上报时刻（当前时间）的 Java 毫秒，非消息体 msg_time2；及服务端 GREATEST 语义不变
    long long reportTimeMs = [TimeTool javaMillisFromNSDate:[NSDate date]];
    NSString *lastReadTime2Str = [NSString stringWithFormat:@"%lld", reportTimeMs];

    NSString *chatTypeStr = @"0";
    if (self.chatType == CHAT_TYPE_GUEST_CHAT) {
        chatTypeStr = @"1";
    } else if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
        chatTypeStr = @"2";
    }

    self.lastReadReceiptReportTime = [[NSDate date] timeIntervalSince1970];

    BOOL isGroupChat = (self.chatType == CHAT_TYPE_GROUP_CHAT);

    void (^sendGroupReadReceiptHttp)(void) = ^{
        [[HttpRestHelper sharedInstance] submitReportReadReceiptToServer:luid partnerId:partnerId chatType:chatTypeStr lastReadTime2:lastReadTime2Str complete:^(BOOL sucess, NSString *resultCode) {
            if (sucess) {
                DDLogDebug(@"【已读回执】群聊 HTTP 上报成功 lastReadTime2=%@", lastReadTime2Str);
            } else {
                DDLogWarn(@"【已读回执】群聊 HTTP 上报失败");
            }
        } hudParentView:nil];
    };

    // 优先 IM MT64（dataContent JSON 与 HTTP 1008-4-24 字段一致）；群聊在 TCP 不可用或 MT64 失败时回退 HTTP，确保服务端未读水位可更新
    NSDictionary *mt64Payload = @{
        @"luid": luid ?: @"",
        @"partner_id": partnerId ?: @"",
        @"chat_type": chatTypeStr,
        @"last_read_time2": lastReadTime2Str
    };
    NSError *jsonErr = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:mt64Payload options:0 error:&jsonErr];
    NSString *jsonStr = (jsonData.length > 0)
        ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
        : nil;
    if (jsonErr || jsonStr.length == 0) {
        DDLogWarn(@"【已读回执】JSON 构造失败 %@，跳过 MT64", jsonErr);
        return;
    }
    if (![[ClientCoreSDK sharedInstance] connectedToServer]) {
        if (isGroupChat) {
            DDLogWarn(@"【已读回执】群聊 TCP 未连接，改用 HTTP 1008-4-24 上报");
            sendGroupReadReceiptHttp();
        } else {
            DDLogWarn(@"【已读回执】TCP 未连接，跳过 MT64（无 HTTP 回退）");
        }
        return;
    }
    int imCode = [SendDataHelper sendMessageImpl:@"0" withMessage:jsonStr qos:NO andTypeu:MT64_OF_READ_RECEIPT_CLIENT_TO_SERVER];
    if (imCode == COMMON_CODE_OK) {
        DDLogDebug(@"【已读回执】MT64 已发送 luid=%@, partnerId=%@, chatType=%@, lastReadTime2=%@", luid, partnerId, chatTypeStr, lastReadTime2Str);
    } else {
        DDLogWarn(@"【已读回执】MT64 发送失败 code=%d", imCode);
        if (isGroupChat) {
            DDLogWarn(@"【已读回执】群聊 MT64 失败，尝试 HTTP 1008-4-24");
            sendGroupReadReceiptHttp();
        }
    }
}

- (void)reportReadReceiptIfNeeded
{
    [self reportReadReceiptIfNeededWithForce:NO];
}

- (void)queryPartnerReadReceipt
{
    [self queryPartnerReadReceiptBypassThrottle:NO];
}

- (void)queryPartnerReadReceiptBypassThrottle:(BOOL)bypassThrottle
{
    if (self.chatType == CHAT_TYPE_GROUP_CHAT) return;

    NSString *luid = self.senderId;
    NSString *partnerId = self.toId;
    if ([BasicTool isStringEmpty:luid] || [BasicTool isStringEmpty:partnerId]) return;

    if (!bypassThrottle) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (self.lastPartnerReadReceiptQueryWallTime > 0 && (now - self.lastPartnerReadReceiptQueryWallTime) < kPartnerReadReceiptQueryMinInterval) {
            DDLogDebug(@"【已读回执】查询节流：距上次查询 %.2fs，跳过", now - self.lastPartnerReadReceiptQueryWallTime);
            return;
        }
        self.lastPartnerReadReceiptQueryWallTime = now;
    } else {
        self.lastPartnerReadReceiptQueryWallTime = [[NSDate date] timeIntervalSince1970];
    }

    NSString *chatTypeStr = @"0";
    if (self.chatType == CHAT_TYPE_GUEST_CHAT) {
        chatTypeStr = @"1";
    } else if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
        chatTypeStr = @"2";
    }

    __weak typeof(self) safeSelf = self;

    [[HttpRestHelper sharedInstance] submitQueryReadReceiptFromServer:luid
                                                           partnerId:partnerId
                                                            chatType:chatTypeStr
                                                            complete:^(BOOL sucess, NSString *lastReadTime2) {
        if (sucess && lastReadTime2 != nil) {
            DDLogDebug(@"【已读回执】查询成功，对方 lastReadTime2=%@", lastReadTime2);
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(safeSelf) strongSelf = safeSelf;
                if (!strongSelf) return;
                long long newT = [lastReadTime2 longLongValue];
                long long oldT = [strongSelf.partnerLastReadTime2 longLongValue];
                /// 26-8 / MT61 已写入更高或相等水位时，避免再批量子 reload outgoing（表现为进入会话已读勾全体闪一下）
                if (newT > 0 && oldT > 0 && newT <= oldT) {
                    DDLogDebug(@"【已读回执】查询水位不高于当前（new=%lld old=%lld），跳过 UI 刷新", newT, oldT);
                    /// 仍用当前内存水位回写 SQLite，避免库滞后（例如上次未落库、重装后仅内存有水位等）
                    [strongSelf rb_persistOutgoingReadByPartnerWatermark:oldT];
                    return;
                }
                strongSelf.partnerLastReadTime2 = lastReadTime2;
                NSMutableArray<NSIndexPath *> *paths = [NSMutableArray array];
                BOOL changed = [strongSelf rb_updateMessagesReadStatusCollectingChangedPaths:paths];
                if (changed) {
                    [strongSelf rb_reloadCellsForReadReceiptChanges:paths];
                }
            });
        } else {
            DDLogWarn(@"【已读回执】查询失败，luid=%@, partnerId=%@", luid, partnerId);
        }
    } hudParentView:nil];
}

- (BOOL)updateMessagesReadStatus
{
    return [self rb_updateMessagesReadStatusCollectingChangedPaths:nil];
}

- (BOOL)rb_updateMessagesReadStatusCollectingChangedPaths:(NSMutableArray<NSIndexPath *> *)outPaths
{
    if (self.chatType == CHAT_TYPE_GROUP_CHAT) return NO;

    if ([BasicTool isStringEmpty:self.partnerLastReadTime2] || [@"0" isEqualToString:self.partnerLastReadTime2]) return NO;
    long long partnerReadTime = [self.partnerLastReadTime2 longLongValue];
    if (partnerReadTime <= 0) return NO;

    NSArray<JSQMessage *> *datasList = [self getChattingDatasList];
    BOOL changed = NO;
    NSUInteger n = datasList.count;
    for (NSUInteger i = 0; i < n; i++) {
        JSQMessage *msg = datasList[i];
        if ([msg isOutgoing] && msg.date != nil) {
            long long msgTime2 = (long long)([msg.date timeIntervalSince1970] * 1000);
            BOOL shouldRead = (msgTime2 <= partnerReadTime);
            if (msg.readByPartner != shouldRead) {
                msg.readByPartner = shouldRead;
                changed = YES;
                if (outPaths != nil) {
                    [outPaths addObject:[NSIndexPath indexPathForItem:(NSInteger)i inSection:0]];
                }
            }
        }
    }
    if (partnerReadTime > 0) {
        [self rb_persistOutgoingReadByPartnerWatermark:partnerReadTime];
    }
    return changed;
}

- (void)rb_persistOutgoingReadByPartnerWatermark:(long long)partnerReadMs
{
    if (self.chatType == CHAT_TYPE_GROUP_CHAT) return;

    if (partnerReadMs <= 0) return;
    if (![BasicTool isStringEmpty:self.toId]) {
        [self rb_savePartnerReadWatermarkIfHigher:partnerReadMs];
    }
    /// _acount_uid 与入库一致；senderId 匹配须覆盖 IM user_uid、会话页 senderId、ClientCore 登录 id，否则 UPDATE 命中 0 行会表现为重进会话丢双勾
    NSString *owner = [IMClientManager sharedInstance].localUserInfo.user_uid ?: @"";
    NSString *fallbackOwner = owner.length > 0 ? owner : (self.senderId ?: @"");
    if (fallbackOwner.length == 0) {
        fallbackOwner = [[ClientCoreSDK sharedInstance] currentLoginUserId] ?: @"";
    }
    if (owner.length == 0) {
        owner = fallbackOwner;
    }
    NSMutableOrderedSet *senderCandidates = [NSMutableOrderedSet orderedSet];
    NSString *imu = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (imu.length > 0) {
        [senderCandidates addObject:imu];
    }
    if (self.senderId.length > 0) {
        [senderCandidates addObject:self.senderId];
    }
    NSString *cid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
    if (cid.length > 0) {
        [senderCandidates addObject:cid];
    }
    NSArray<NSString *> *localSenderIds = [senderCandidates array];
    NSString *peer = self.toId;
    if (localSenderIds.count == 0 || [BasicTool isStringEmpty:peer]) return;

    [MyDataBase inDatabase:^(FMDatabase *db) {
        if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
            [[[MyDataBase sharedInstance] groupChatHistoryTable] markOutgoingReadByPartnerUpToWatermark:db
                                                                                       acountUidOfOwner:owner
                                                                                                      gid:peer
                                                                                          localSenderIds:localSenderIds
                                                                                     partnerReadTimeMs:partnerReadMs];
        } else if (self.chatType == CHAT_TYPE_FREIDN_CHAT || self.chatType == CHAT_TYPE_GUEST_CHAT) {
            [[[MyDataBase sharedInstance] chatHistoryTable] markOutgoingReadByPartnerUpToWatermark:db
                                                                                acountUidOfOwner:owner
                                                                                             uid:peer
                                                                                  localSenderIds:localSenderIds
                                                                               partnerReadTimeMs:partnerReadMs];
        }
    }];
}

- (NSString *)rb_partnerReadWatermarkDefaultsKeyForCurrentChat
{
    NSString *owner = [IMClientManager sharedInstance].localUserInfo.user_uid ?: @"";
    if (owner.length == 0) {
        owner = [[ClientCoreSDK sharedInstance] currentLoginUserId] ?: @"";
    }
    return RBPartnerReadWatermarkDefaultsKey(owner, self.toId, self.chatType);
}

- (void)rb_savePartnerReadWatermarkIfHigher:(long long)ms
{
    if (ms <= 0) return;
    if (self.chatType == CHAT_TYPE_GROUP_CHAT) return;
    if ([self.toId isEqualToString:@"10001"]) return;
    NSString *key = [self rb_partnerReadWatermarkDefaultsKeyForCurrentChat];
    if (key.length == 0) return;
    NSString *prevStr = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    long long prev = prevStr.length > 0 ? [prevStr longLongValue] : 0;
    if (ms > prev) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%lld", ms] forKey:key];
    }
}

- (void)rb_restorePartnerReadWatermarkAndApplyToCurrentListIfNeeded
{
    if (self.chatType != CHAT_TYPE_FREIDN_CHAT && self.chatType != CHAT_TYPE_GUEST_CHAT) return;
    if (self.toId.length == 0 || [self.toId isEqualToString:@"10001"]) return;
    NSString *key = [self rb_partnerReadWatermarkDefaultsKeyForCurrentChat];
    if (key.length == 0) return;
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    if (stored.length == 0) return;
    long long diskMs = [stored longLongValue];
    if (diskMs <= 0) return;
    long long memMs = [self.partnerLastReadTime2 longLongValue];
    if (diskMs > memMs) {
        self.partnerLastReadTime2 = stored;
    }
    (void)[self rb_updateMessagesReadStatusCollectingChangedPaths:nil];
}

/// 单次刷新条数过大时仍走整表，避免 batch 过大带来的调度开销；正常水位推进仅一条或少量 outgoing 变化
- (void)rb_reloadCellsForReadReceiptChanges:(NSArray<NSIndexPath *> *)changedPaths
{
    if (changedPaths.count == 0 || self.collectionView == nil) return;
    NSInteger total = [self.collectionView numberOfItemsInSection:0];
    if (total <= 0) return;

    static const NSUInteger kMaxReadReceiptReloadItemsBatch = 120;
    NSMutableArray<NSIndexPath *> *valid = [NSMutableArray arrayWithCapacity:changedPaths.count];
    for (NSIndexPath *ip in changedPaths) {
        if (ip.section != 0) continue;
        if (ip.item < 0 || ip.item >= total) continue;
        [valid addObject:ip];
    }
    if (valid.count == 0) return;

    if (valid.count > kMaxReadReceiptReloadItemsBatch) {
        [self rb_invalidateChattingListLayoutCache];
        [self.collectionView reloadData];
        return;
    }
    if (!self.collectionView.window) {
        [self rb_invalidateChattingListLayoutCache];
        [self.collectionView reloadData];
        return;
    }
    [UIView performWithoutAnimation:^{
        [self.collectionView reloadItemsAtIndexPaths:valid];
    }];
}

- (void)onReadReceiptUpdated:(NSNotification *)notification
{
    if (self.chatType == CHAT_TYPE_GROUP_CHAT) return;

    NSDictionary *info = notification.userInfo;
    if (![info isKindOfClass:[NSDictionary class]]) return;
    NSString *readerUid = info[@"reader_uid"] ?: @"";
    NSString *lastReadTime2 = info[@"last_read_time2"] ?: @"0";
    if ([BasicTool isStringEmpty:readerUid] || ![readerUid isEqualToString:self.toId]) return;

    DDLogDebug(@"【MT61-实时通知】对方 %@ 已读到 %@，更新聊天气泡已读状态", readerUid, lastReadTime2);
    long long newTime = [lastReadTime2 longLongValue];
    long long oldTime = [self.partnerLastReadTime2 longLongValue];
    if (newTime > oldTime) {
        self.partnerLastReadTime2 = lastReadTime2;
    }
    NSMutableArray<NSIndexPath *> *paths = [NSMutableArray array];
    if ([self rb_updateMessagesReadStatusCollectingChangedPaths:paths]) {
        [self rb_reloadCellsForReadReceiptChanges:paths];
    }
}

- (void)resetUnreadCount
{
    // 先恢复 JSQ 父类逻辑：会话内「X条新消息」计数归零（滚动贴底 / 点击气泡时会调到此入口）
    [super resetUnreadCount];

    NSString *pid = self.toId;
    if ([BasicTool isStringEmpty:pid]) return;
    AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
    if (!ap) return;

    int alarmType;
    if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
        alarmType = AMT_groupChatMessage;
    } else if (self.chatType == CHAT_TYPE_GUEST_CHAT) {
        alarmType = AMT_guestChatMessage;
    } else {
        alarmType = AMT_friendChatMessage;
    }

    int idx = [ap getAlarmIndex:alarmType dataId:pid];
    if (idx >= 0 && [ap getFlagNum:idx] == 0) {
        return;
    }

    [ap resetFlagNum:alarmType dataId:pid flagNumToReset:0 needUpdateSqlite:YES];
    [NotificationCenterFactory refreshMainPageTotalUnread_POST];
}

@end
