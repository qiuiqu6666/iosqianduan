//telegram @wz662
#import "QueryOfflineChatMsgAsync.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "AppDelegate.h"
#import "FriendsListProvider.h"
#import "EVAToolKits.h"
#import "ChatDataHelper.h"
#import "BasicTool.h"
#import "MsgBodyRoot.h"
#import "MsgBody4Group.h"
#import "GChatDataHelper.h"
#import "TMessageHelper.h"
#import "TChatDataHelper.h"
#import "TimeTool.h"
#import "QoS4ReciveDaemon.h"
#import "MessagesProvider.h"
#import "ClientCoreSDK.h"
#import "ChatMessageEventImpl.h"
#import "OfflineMsgDTO.h"


@implementation QueryOfflineChatMsgAsync

+ (void)doIt:(NSString *)fromUserUid hudParentView:(UIView *)view
{
    [self doIt:fromUserUid hudParentView:view completion:nil];
}

/// 处理一批 OfflineMsgDTO；`whenDone` 在列表刷新派发之后（或无需派发时同步）调用。
+ (void)rb_processOfflineMsgArray:(NSArray<OfflineMsgDTO *> *)offlineMsgList
                          localUid:(NSString *)localUid
                          whenDone:(void (^)(void))whenDone
{
    if (offlineMsgList == nil || offlineMsgList.count == 0) {
        if (whenDone) {
            whenDone();
        }
        return;
    }

    DDLogDebug(@"【QueryOfflineChatMsgAsync】离线消息读取成功，共有消息条数：%lu", (unsigned long)offlineMsgList.count);

    NSMutableOrderedSet<NSString *> *offlineTouchedFriendBuckets = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet<NSString *> *offlineTouchedGroupBuckets = [NSMutableOrderedSet orderedSet];

    for (OfflineMsgDTO *tcmd in offlineMsgList) {
        DDLogDebug(@"【QueryOfflineChatMsgAsync】正在处理离线消息数据DTO->%@, fp=%@, hasRecieved=%d", tcmd, tcmd.msg_content2, [[QoS4ReciveDaemon sharedInstance] hasRecieved:tcmd.msg_content2]);

        NSString *historyMsgFinterPrint = tcmd.msg_content2;

        if (![BasicTool isStringEmpty:historyMsgFinterPrint] && [[QoS4ReciveDaemon sharedInstance] hasRecieved:historyMsgFinterPrint]) {
            DDLogDebug(@"【QueryOfflineChatMsgAsync】.....->由\"%@(nick=%@)\"发来的消息内容为\"%@\"(fp=%@)的消息已被判定为重复，将被忽略哦", tcmd.user_uid, tcmd.nickName, tcmd.msg_content, historyMsgFinterPrint);
            continue;
        }

        if ([tcmd.user_uid isEqualToString:localUid]) {
            NSLog(@"【QueryOfflineChatMsgAsync】跳过自己发送的离线消息: fp=%@", tcmd.msg_content2);
            continue;
        }

        if (tcmd.msg_type == 13) {
            UserEntity *u = nil;
            if (tcmd.msg_content.length > 0) {
                u = [EVAToolKits fromJSON:tcmd.msg_content withClazz:UserEntity.class];
            }
            NSString *friendUid = u.user_uid.length > 0 ? u.user_uid : [BasicTool trim:tcmd.user_uid];
            if (friendUid.length > 0) {
                if (u == nil) {
                    u = [[UserEntity alloc] init];
                    u.user_uid = friendUid;
                    u.nickname = tcmd.nickName ?: @"";
                }
                [[[IMClientManager sharedInstance] getFriendsListProvider] putFriend:u];
                static NSString * const kAddFriendSuccessHint = @"你们已经是好友了，现在可以好友模式聊天了。";
                NSString *localUid2 = [[ClientCoreSDK sharedInstance] currentLoginUserId];
                if (localUid2.length == 0) {
                    localUid2 = @"0";
                }
                NSString *fp = [NSString stringWithFormat:@"SYS_ADD_FRIEND_OK_%@_%@", localUid2, friendUid ?: @"0"];
                if ([ChatMessageEventImpl shouldInsertAddFriendSuccessHintForFriend:friendUid]) {
                    [ChatDataHelper addSystemInfoData:u infoContent:kAddFriendSuccessHint fingerPrint:fp date:[tcmd getHistoryTime2Date] playAudio:NO showNotify:NO];
                }
            }
            continue;
        }

        int chatType = [BasicTool getIntValue:tcmd.chat_type defaultVal:-1];
        if (chatType == CHAT_TYPE_GROUP_CHAT) {
            MsgBody4Group *dd = [MsgBody4Group constructGroupChatMsgBody:tcmd.msg_type srcUserUid:tcmd.user_uid srcNickName:tcmd.nickName toGid:tcmd.group_id msg:tcmd.msg_content parentFp:tcmd.parent_fp at:tcmd.be_at];

            [GChatDataHelper addChatMessageDataIncoming:tcmd.msg_content2 gid:tcmd.group_id gname:tcmd.group_name withBody:dd date:[tcmd getHistoryTime2Date] showNotify:NO playAudio:NO andQuote:tcmd];
            if (tcmd.group_id.length > 0) {
                [offlineTouchedGroupBuckets addObject:tcmd.group_id];
            }
        } else {
            FriendsListProvider *rp = [[IMClientManager sharedInstance] getFriendsListProvider];
            if (rp != nil && [rp isUserInRoster:tcmd.user_uid]) {
                [ChatDataHelper addChatMessageData_incoming:tcmd.msg_content2
                                                 msgContent:tcmd.msg_content
                                                   withTime:[tcmd getHistoryTime2Date]
                                                  playAudio:NO
                                                 showNotify:NO
                                                    msgType:tcmd.msg_type
                                                    withRee:[rp getFriendInfoByUid:tcmd.user_uid]
                                                   andQuote:tcmd];
                if (tcmd.user_uid.length > 0) {
                    [offlineTouchedFriendBuckets addObject:tcmd.user_uid];
                }
            } else {
                MsgBody4Guest *dd = [TMessageHelper constructTempChatMsgDTO:tcmd.msg_type srcUserUid:tcmd.user_uid srcNickName:tcmd.nickName friendUid:tcmd.friend_user_uid withMsg:tcmd.msg_content];

                [TChatDataHelper addChatMessageData_incoming:tcmd.msg_content2 msgBody:dd date:[tcmd getHistoryTime2Date] showNotify:NO playAudio:NO andQuote:tcmd];
                NSString *guestKey = [BasicTool trim:tcmd.friend_user_uid];
                if (guestKey.length == 0) {
                    guestKey = [BasicTool trim:tcmd.user_uid];
                }
                if (guestKey.length > 0) {
                    [offlineTouchedFriendBuckets addObject:guestKey];
                }
            }
        }
    }

    if (offlineTouchedFriendBuckets.count > 0 || offlineTouchedGroupBuckets.count > 0) {
        NSArray<NSString *> *fBuckets = [offlineTouchedFriendBuckets array];
        NSArray<NSString *> *gBuckets = [offlineTouchedGroupBuckets array];
        dispatch_async(dispatch_get_main_queue(), ^{
            for (NSString *uid in fBuckets) {
                if (uid.length == 0) {
                    continue;
                }
                [[[IMClientManager sharedInstance] getMessagesProvider] notifyObserversForChatUid:uid];
            }
            for (NSString *gid in gBuckets) {
                if (gid.length == 0) {
                    continue;
                }
                [[[IMClientManager sharedInstance] getGroupsMessagesProvider] notifyObserversForChatUid:gid];
            }
            DDLogDebug(@"【QueryOfflineChatMsgAsync】离线投递后已补发会话刷新 friendBuckets=%lu groupBuckets=%lu",
                       (unsigned long)fBuckets.count, (unsigned long)gBuckets.count);
            if (whenDone) {
                whenDone();
            }
        });
    } else {
        if (whenDone) {
            whenDone();
        }
    }
}

+ (void)rb_drainOfflineRecursive:(UIView *)view completion:(void (^)(void))completion
{
    NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid;
    if (localUid.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
        return;
    }

    [[HttpRestHelper sharedInstance] submitGetOfflineChatMessagesToServer:localUid
                                                                   friend:nil
                                                                 complete:^(BOOL sucess, NSArray<OfflineMsgDTO *> *offlineMsgList) {
        if (!sucess) {
            DDLogDebug(@"【QueryOfflineChatMsgAsync】drain 批次：HTTP 失败");
            if (view != nil) {
                [APP showToastWarn:@"网络故障，离线消息拉取失败！"];
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), completion);
            }
            return;
        }

        NSUInteger n = offlineMsgList != nil ? offlineMsgList.count : 0;
        DDLogDebug(@"【QueryOfflineChatMsgAsync】drain 本批条数=%lu", (unsigned long)n);
        if (n == 0) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), completion);
            }
            return;
        }

        [self rb_processOfflineMsgArray:offlineMsgList localUid:localUid whenDone:^{
            [self rb_drainOfflineRecursive:view completion:completion];
        }];
    } hudParentView:view];
}

+ (void)drainAllOfflineChatBatchesForHudParentView:(UIView *)view completion:(void (^)(void))completion
{
    [self rb_drainOfflineRecursive:view completion:completion];
}

+ (void)doIt:(NSString *)fromUserUid hudParentView:(UIView *)view completion:(void (^)(void))completion
{
    NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid;

    [[HttpRestHelper sharedInstance] submitGetOfflineChatMessagesToServer:localUid
                                                                   friend:fromUserUid
                                                                 complete:^(BOOL sucess, NSArray<OfflineMsgDTO *> *offlineMsgList) {
        if (sucess) {
            DDLogDebug(@"【QueryOfflineChatMsgAsync】正在拉取离线消息，原始列表数据长度：%lu", (unsigned long)[offlineMsgList count]);
            if (offlineMsgList != nil && offlineMsgList.count > 0) {
                [self rb_processOfflineMsgArray:offlineMsgList localUid:localUid whenDone:completion];
                return;
            }
        } else {
            DDLogDebug(@"【QueryOfflineChatMsgAsync】离线消息从服务端获取失败.");
            if (view != nil) {
                [APP showToastWarn:@"网络故障，离线消息拉取失败！"];
            }
        }

        if (completion) {
            completion();
        }
    } hudParentView:view];
}


@end
