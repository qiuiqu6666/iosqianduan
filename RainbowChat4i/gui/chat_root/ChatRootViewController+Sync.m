//
//  ChatRootViewController+Sync.m
//  多端增量同步：静默拉取、去重合并。
//

#import "ChatRootViewController+Sync.h"
#import "ChatRootViewController+MessageList.h"
#import "ChatRootViewController.h"
#import "BasicTool.h"
#import "IMClientManager.h"
#import "MessagesProvider.h"
#import "GroupsMessagesProvider.h"
#import "NSMutableArrayObservableEx.h"
#import "JSQMessage.h"
#import "TimeTool.h"
#import "GroupEntity.h"
#import <objc/runtime.h>

@interface ChatRootViewController (SyncPrivate)
- (NSMutableSet<NSString *> *)buildExistingDedupSetForMessages:(NSMutableArray *)messages;
- (JSQMessage *)parseHistoryMsgFromDict:(NSDictionary *)dict localUid:(NSString *)localUid;
- (JSQMessage *)parseHistoryMsgFromArr:(NSArray *)arr localUid:(NSString *)localUid;
- (NSString *)roamingDedupKeyForMessage:(JSQMessage *)msg;
- (NSString *)compositeDedupKeyForMessage:(JSQMessage *)msg;
- (BOOL)rb_dedupSet:(NSMutableSet<NSString *> *)dedupSet hasFusionMatchForHistoryMessage:(JSQMessage *)msg localUid:(NSString *)localUid;
- (void)rb_dedupSet:(NSMutableSet<NSString *> *)dedupSet insertFusionKeysForHistoryMessage:(JSQMessage *)msg localUid:(NSString *)localUid;
- (BOOL)isLastCellVisible;
- (void)scrollToBottomAnimated:(BOOL)animated;
- (void)jsq_updateCollectionViewInsets;
- (BOOL)rb_isChatScrolledToBottomApproximatelyWithTolerance:(CGFloat)tolerance;
@end

@implementation ChatRootViewController (Sync)

#pragma mark - 去重键方法

- (NSMutableSet<NSString *> *)buildExistingDedupSetForMessages:(NSMutableArray *)messages
{
    NSMutableSet<NSString *> *dedupSet = [NSMutableSet set];
    if (!messages) return dedupSet;

    for (JSQMessage *msg in messages) {
        if (![msg isKindOfClass:[JSQMessage class]]) continue;

        NSString *fp = msg.fingerPrintOfProtocal;
        if (fp.length > 0) {
            [dedupSet addObject:[NSString stringWithFormat:@"fp:%@", fp]];
        }

        long long ts = (msg.date != nil) ? (long long)([msg.date timeIntervalSince1970] * 1000) : 0;
        NSString *contentPrefix = (msg.text.length > 32) ? [msg.text substringToIndex:32] : (msg.text ?: @"");
        [dedupSet addObject:[NSString stringWithFormat:@"ck:%@|%lld|%@", msg.senderId ?: @"", ts, contentPrefix]];

        NSString *cklKey = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:msg];
        if (cklKey.length > 0) [dedupSet addObject:cklKey];

        NSString *mscKey = [MessagesProvider dedupKeyMillisSenderContentType:msg];
        if (mscKey.length > 0) [dedupSet addObject:mscKey];

        if ([msg isOutgoing] && msg.date) {
            NSTimeInterval ti = [msg.date timeIntervalSince1970];
            long long sec = (long long)floor(ti);
            int mt = (int)msg.msgType;
            NSString *body = msg.text ?: @"";
            NSString *fuseKey = [NSString stringWithFormat:@"ogfuse_s|%lld|%d|%@", sec, mt, body];
            if (fuseKey.length > 0) [dedupSet addObject:fuseKey];
        }
    }
    return dedupSet;
}

#pragma mark - 消息解析

- (JSQMessage *)parseHistoryMsgFromDict:(NSDictionary *)dict localUid:(NSString *)localUid
{
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    NSString *content = nil;
    id rawContent = dict[@"msg_content"];
    if ([rawContent isKindOfClass:[NSString class]]) {
        content = (NSString *)rawContent;
    } else if (rawContent != nil) {
        content = [[rawContent description] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (content.length == 0) content = dict[@"text"];
    if (content.length == 0) content = dict[@"m"];

    NSString *nick = @"";
    id rawNick = dict[@"nickname"];
    if ([rawNick isKindOfClass:[NSString class]]) {
        nick = (NSString *)rawNick;
    }

    NSDate *dt = nil;
    id rawTime = dict[@"history_time2"];
    if ([rawTime isKindOfClass:[NSString class]] || [rawTime isKindOfClass:[NSNumber class]]) {
        long long t2 = [rawTime isKindOfClass:[NSNumber class]] ? [(NSNumber *)rawTime longLongValue] : [rawTime longLongValue];
        dt = [TimeTool dateFromChatHistoryStoredTime:t2];
    }
    if (!dt) {
        id rawDate = dict[@"date"];
        if ([rawDate isKindOfClass:[NSDate class]]) {
            dt = (NSDate *)rawDate;
        } else if ([rawDate isKindOfClass:[NSNumber class]]) {
            dt = [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)rawDate doubleValue]];
        }
    }
    if (!dt) dt = [NSDate date];

    int msgType = 1;
    id rawType = dict[@"msg_type"];
    if ([rawType isKindOfClass:[NSNumber class]]) {
        msgType = [(NSNumber *)rawType intValue];
    } else if ([rawType isKindOfClass:[NSString class]]) {
        msgType = [(NSString *)rawType intValue];
    }

    NSString *senderId = @"";
    id rawSender = dict[@"user_uid"];
    if ([rawSender isKindOfClass:[NSString class]]) {
        senderId = (NSString *)rawSender;
    } else if (rawSender != nil) {
        senderId = [[rawSender description] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (senderId.length == 0) senderId = dict[@"senderId"];

    int chatType = [dict[@"chat_type"] intValue];
    BOOL isGroup = (chatType == CHAT_TYPE_GROUP_CHAT);

    if (isGroup) {
        NSString *srcUid = [BasicTool trim:senderId];
        NSString *localUid2 = localUid ?: @"";
        if (srcUid.length > 0 && [srcUid isEqualToString:localUid2]) {
            id rawDest = dict[@"friend_user_uid"];
            if ([rawDest isKindOfClass:[NSString class]] && [(NSString *)rawDest length] > 0) {
                senderId = (NSString *)rawDest;
            }
        }
    } else {
        NSString *srcUid = [BasicTool trim:senderId];
        NSString *localUid2 = localUid ?: @"";
        if (srcUid.length > 0 && ![srcUid isEqualToString:localUid2]) {
            senderId = srcUid;
        } else {
            id rawDest = dict[@"friend_user_uid"];
            if ([rawDest isKindOfClass:[NSString class]] && [(NSString *)rawDest length] > 0) {
                senderId = (NSString *)rawDest;
            }
        }
    }

    JSQMessage *msgObj = [JSQMessage prepareChatMessageData_incoming:content
                                                        withNickName:nick
                                                             andTime:dt
                                                          andMsgType:msgType
                                                            senderId:senderId];
    if (!msgObj) return nil;

    NSString *fpRaw = [BasicTool trim:[dict[@"fp"] description]];
    NSString *parentFp = [BasicTool trim:[dict[@"parent_fp"] description]];
    NSString *stableFp = fpRaw;
    if (isGroup && parentFp.length > 0) stableFp = parentFp;
    msgObj.fingerPrintOfProtocal = stableFp;
    msgObj.fingerPrintOfParent = parentFp;

    id rawQuoteFp = dict[@"quote_fp"];
    if ([rawQuoteFp isKindOfClass:[NSString class]] && [(NSString *)rawQuoteFp length] > 0) {
        QuoteMeta *qm = [[QuoteMeta alloc] init];
        qm.quote_fp = (NSString *)rawQuoteFp;
        id rawQuoteSenderUid = dict[@"quote_sender_uid"];
        qm.quote_sender_uid = [rawQuoteSenderUid isKindOfClass:[NSString class]] ? (NSString *)rawQuoteSenderUid : @"";
        id rawQuoteSenderNick = dict[@"quote_sender_nick"];
        qm.quote_sender_nick = [rawQuoteSenderNick isKindOfClass:[NSString class]] ? (NSString *)rawQuoteSenderNick : @"";
        qm.quote_status = [dict[@"quote_status"] intValue];
        id rawQuoteContent = dict[@"quote_content"];
        qm.quote_content = [rawQuoteContent isKindOfClass:[NSString class]] ? (NSString *)rawQuoteContent : @"";
        qm.quote_type = [dict[@"quote_type"] intValue];
        [msgObj setQuoteMeta:qm];
    }

    msgObj.sendStatus = SendStatus_BE_RECEIVED;
    msgObj.sendStatusSecondary = SendStatusSecondary_NONE;
    msgObj.sendStatusSecondaryProgress = 0;

    return msgObj;
}

- (JSQMessage *)parseHistoryMsgFromArr:(NSArray *)arr localUid:(NSString *)localUid
{
    if ([arr isKindOfClass:[NSArray class]] && arr.count > 0) {
        id first = arr.firstObject;
        if ([first isKindOfClass:[NSDictionary class]]) {
            return [self parseHistoryMsgFromDict:(NSDictionary *)first localUid:localUid];
        }
    }
    return nil;
}

- (NSString *)roamingDedupKeyForMessage:(JSQMessage *)msg
{
    if (![BasicTool isStringEmpty:msg.fingerPrintOfProtocal]) {
        return [NSString stringWithFormat:@"fp:%@", msg.fingerPrintOfProtocal];
    }
    return [self compositeDedupKeyForMessage:msg];
}

- (NSString *)compositeDedupKeyForMessage:(JSQMessage *)msg
{
    long long ts = (msg.date != nil) ? (long long)([msg.date timeIntervalSince1970] * 1000) : 0;
    NSString *contentPrefix = (msg.text.length > 32) ? [msg.text substringToIndex:32] : (msg.text ?: @"");
    return [NSString stringWithFormat:@"ck:%@|%lld|%@", msg.senderId ?: @"", ts, contentPrefix];
}

- (NSArray<NSString *> *)rb_outgoingHistoryFusionDedupKeysForMessage:(JSQMessage *)msg localUid:(NSString *)localUid
{
    if (msg == nil || localUid.length == 0) {
        return @[];
    }
    if (![msg.senderId isEqualToString:localUid]) {
        return @[];
    }
    if (![msg isOutgoing]) {
        return @[];
    }
    NSTimeInterval ti = msg.date ? [msg.date timeIntervalSince1970] : 0;
    long long sec = (long long)floor(ti);
    NSString *body = msg.text ?: @"";
    int mt = (int)msg.msgType;
    NSString *k = [NSString stringWithFormat:@"ogfuse_s|%lld|%d|%@", sec, mt, body];
    return (k.length > 0) ? @[ k ] : @[];
}

- (BOOL)rb_dedupSet:(NSMutableSet<NSString *> *)dedupSet hasFusionMatchForHistoryMessage:(JSQMessage *)msg localUid:(NSString *)localUid
{
    for (NSString *k in [self rb_outgoingHistoryFusionDedupKeysForMessage:msg localUid:localUid]) {
        if (k.length > 0 && [dedupSet containsObject:k]) {
            return YES;
        }
    }
    return NO;
}

- (void)rb_dedupSet:(NSMutableSet<NSString *> *)dedupSet insertFusionKeysForHistoryMessage:(JSQMessage *)msg localUid:(NSString *)localUid
{
    for (NSString *k in [self rb_outgoingHistoryFusionDedupKeysForMessage:msg localUid:localUid]) {
        if (k.length > 0) {
            [dedupSet addObject:k];
        }
    }
}

#pragma mark - 多端增量同步

- (void)silentSyncFromServer
{
}

- (void)silentProcessChatHistory:(NSArray *)chatHistoryList wasAtBottom:(BOOL)wasAtBottom
{
    if (self.toId.length == 0) {
        NSLog(@"【增量同步-UI】toId 为空，跳过处理");
        return;
    }

    NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid ?: @"";
    if (localUid.length == 0) {
        NSLog(@"【增量同步-UI】localUid 为空，跳过处理");
        return;
    }

    if (![chatHistoryList isKindOfClass:[NSArray class]] || chatHistoryList.count == 0) {
        NSLog(@"【增量同步-UI】chatHistoryList 为空，跳过处理");
        return;
    }

    MessagesProvider *mp = [MessagesProvider getMessageProiderInstance:self.chatType];
    if (!mp) {
        NSLog(@"【增量同步-UI】MessagesProvider 为空，跳过处理");
        return;
    }

    NSMutableArrayObservableEx *someoneMessages = [mp getMessages:self.toId];
    if (!someoneMessages) {
        NSLog(@"【增量同步-UI】someoneMessages 为空，跳过处理");
        return;
    }
    NSArray<JSQMessage *> *existingSnapshot = [[someoneMessages getDataList] copy];
    NSInteger existingCount = (NSInteger)existingSnapshot.count;

    BOOL isAtBottom = wasAtBottom;
    if (!isAtBottom) {
        isAtBottom = [self isLastCellVisible] || [self rb_isChatScrolledToBottomApproximatelyWithTolerance:44.0];
    }

    int addedCount = 0;
    int skippedDup = 0;
    NSMutableArray<JSQMessage *> *msgsToPersist = [NSMutableArray array];

    NSMutableSet<NSString *> *dedupSet = [self buildExistingDedupSetForMessages:[someoneMessages getDataList]];

    NSArray *reversedList = [[chatHistoryList reverseObjectEnumerator] allObjects];

    for (id row in reversedList) {
        @try {
            JSQMessage *msg = nil;
            if ([row isKindOfClass:[NSDictionary class]]) {
                msg = [self parseHistoryMsgFromDict:(NSDictionary *)row localUid:localUid];
            } else if ([row isKindOfClass:[NSArray class]]) {
                msg = [self parseHistoryMsgFromArr:(NSArray *)row localUid:localUid];
            } else {
                continue;
            }
            if (msg == nil) continue;

            NSString *dedupKey = [self roamingDedupKeyForMessage:msg];
            NSString *ckKey = [self compositeDedupKeyForMessage:msg];
            NSString *cklKey = [MessagesProvider dedupKeyForMessageLooseNoFingerPrint:msg];
            NSString *mscKey = [MessagesProvider dedupKeyMillisSenderContentType:msg];
            BOOL isDup = NO;
            if (dedupKey.length > 0 && [dedupSet containsObject:dedupKey]) isDup = YES;
            if (!isDup && ckKey.length > 0 && [dedupSet containsObject:ckKey]) isDup = YES;
            if (!isDup && cklKey.length > 0 && [dedupSet containsObject:cklKey]) isDup = YES;
            if (!isDup && mscKey.length > 0 && [dedupSet containsObject:mscKey]) isDup = YES;
            if (!isDup && [self rb_dedupSet:dedupSet hasFusionMatchForHistoryMessage:msg localUid:localUid]) isDup = YES;

            if (isDup) {
                skippedDup++;
                continue;
            }

            if (dedupKey.length > 0) [dedupSet addObject:dedupKey];
            if (ckKey.length > 0) [dedupSet addObject:ckKey];
            if (cklKey.length > 0) [dedupSet addObject:cklKey];
            if (mscKey.length > 0) [dedupSet addObject:mscKey];
            [self rb_dedupSet:dedupSet insertFusionKeysForHistoryMessage:msg localUid:localUid];

            JSQMessage *previousMessage = nil;
            int messagesSize = (int)[[someoneMessages getDataList] count];
            if (messagesSize > 0) {
                previousMessage = (JSQMessage *)[someoneMessages get:messagesSize - 1];
            }
            [MessagesProvider setMessageShowTopTime:msg previous:previousMessage];

            [someoneMessages add:msg needNotify:NO];
            [msgsToPersist addObject:msg];
            addedCount++;
        } @catch (NSException *exception) {
            NSLog(@"【增量同步-UI】处理消息异常: %@", exception);
        }
    }

    NSLog(@"【增量同步-UI】处理完成: 新增 %d 条, 去重跳过 %d 条, 会话 %@", addedCount, skippedDup, self.toId);

    if (addedCount > 0) {
        [self sortSomeoneMessagesByDateAscending:someoneMessages];
        NSArray<JSQMessage *> *sortedMessages = [someoneMessages getDataList];
        NSInteger afterCount = (NSInteger)sortedMessages.count;
        NSInteger visibleItemCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
        BOOL canIncrementalAppend = self.collectionView.window
            && visibleItemCount == existingCount
            && afterCount == existingCount + addedCount;
        if (canIncrementalAppend) {
            for (NSInteger i = 0; i < existingCount; i++) {
                if (sortedMessages[i] != existingSnapshot[i]) {
                    canIncrementalAppend = NO;
                    break;
                }
            }
        }

        if (isAtBottom) {
            [self rb_trimChattingMemoryWindowIfNeededKeepingOlderMessages:NO];
        }
        [self rb_invalidateChattingListLayoutCache];

        if (canIncrementalAppend) {
            NSMutableArray<NSIndexPath *> *insertedPaths = [NSMutableArray arrayWithCapacity:(NSUInteger)addedCount];
            for (NSInteger i = existingCount; i < afterCount; i++) {
                [insertedPaths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
            }
            [UIView performWithoutAnimation:^{
                [self.collectionView performBatchUpdates:^{
                    [self.collectionView insertItemsAtIndexPaths:insertedPaths];
                } completion:^(BOOL finished) {
                    [self.collectionView layoutIfNeeded];
                    [self jsq_updateCollectionViewInsets];
                    if (isAtBottom) {
                        [self scrollToBottomAnimated:YES];
                    }
                }];
            }];
        } else {
            [self.collectionView reloadData];
            [self.collectionView layoutIfNeeded];
            [self jsq_updateCollectionViewInsets];

            if (isAtBottom) {
                [self scrollToBottomAnimated:YES];
                __weak typeof(self) wself = self;
                CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{
                    __strong typeof(wself) s = wself;
                    if (!s) return;
                    [s.collectionView layoutIfNeeded];
                    [s jsq_updateCollectionViewInsets];
                    if ([s.collectionView numberOfItemsInSection:0] > 0) {
                        [UIView performWithoutAnimation:^{ [s scrollToBottomAnimated:NO]; }];
                    }
                });
            }
        }

        NSString *toIdCopy = [self.toId copy];
        int chatTypeCopy = self.chatType;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            MessagesProvider *bgMp = [MessagesProvider getMessageProiderInstance:chatTypeCopy];
            if (!bgMp) {
                NSLog(@"【增量同步-UI】后台持久化失败: MessagesProvider 为空");
                return;
            }
            for (JSQMessage *msg in msgsToPersist) {
                if (msg) {
                    [bgMp saveHistory:toIdCopy withData:msg];
                }
            }
            NSLog(@"【增量同步-UI】后台持久化完成，共 %lu 条", (unsigned long)msgsToPersist.count);
        });
    }
}

@end
