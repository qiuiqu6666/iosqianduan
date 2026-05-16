//telegram @wz662
#import "GChatDataHelper.h"
#import "IMClientManager.h"
#import "ChatDataHelper.h"
#import "UserDefaultsToolKits.h"
#import "GroupEntity.h"
#import "LocalPushHelper.h"
#import "UserDefaultsToolKits.h"
#import "JoinGroupViewController.h"
#import "MessageRevokingManager.h"
#import "AlarmsProvider.h"
#import "AlarmType.h"
#import "QoS4ReciveDaemon.h"
#import <CommonCrypto/CommonDigest.h>

@implementation GChatDataHelper

static NSString *rb_md5String(NSString *s) {
    if (s.length == 0) return @"";
    const char *cStr = [s UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

static NSString *rb_groupSystemInfoFp(NSString *gid, NSString *systemInfo) {
    NSString *localUid = [[ClientCoreSDK sharedInstance] currentLoginUserId] ?: @"";
    NSString *raw = [NSString stringWithFormat:@"%@|%@|%@", localUid, gid ?: @"", systemInfo ?: @""];
    NSString *md5 = rb_md5String(raw);
    return [NSString stringWithFormat:@"SYS_G_SYSINFO_%@_%@", localUid.length > 0 ? localUid : @"0", md5.length > 0 ? md5 : @"0"];
}


// **************************************************************************** 以下方法仅为本收到的消息所准备 START

// * 往聊天界面中显示一条被世界频道提示信息，以便给用户提供打开世界频道的入口（通知并非服务器发出，而是本地准备好的，仅用UI显示）。
+ (void) addSystenInfo_wordChatPortalForLocalUser
{
    NSString *hint = [NSString stringWithFormat:@"没人聊天？快来%@试试人气吧！",DEFAULT_GROUP_NAME_FOR_BBS];
    [GChatDataHelper addSystemInfoData:DEFAULT_GROUP_ID_FOR_BBS gname:DEFAULT_GROUP_NAME_FOR_BBS infoContent:hint date:nil showNotify:NO playAudio:NO];
}

// * 往聊天界面中显示一条"我"通过扫描二维码加入群聊成功的提示信息（此通知并非服务器发出，而是本地准备好的，仅用UI显示）。
+ (void) addSystemInfo_joinGroupSucess:(int)joinBy
                                sharedByNickname:(NSString *)sharedByNickname
                                             gid:(NSString *)gid
                                           gname:(NSString *)gname
                                     memberCount:(int) memberCount
{
    NSString *hint = @"";
    if(joinBy == JOIN_BY_SCAN_QRCODE) {
        hint = [NSString stringWithFormat:@"你通过扫描%@二维码加入群聊%@。", (![BasicTool isStringEmpty:[BasicTool trim:sharedByNickname]])?[NSString stringWithFormat:@"\"%@\"分享的", sharedByNickname]:@"", (memberCount>0?[NSString stringWithFormat:@"，当前群聊参与者共%d人", memberCount]:@"")];
    } else {
        hint = [NSString stringWithFormat:@"你通过%@群名片加入群聊%@。", (![BasicTool isStringEmpty:[BasicTool trim:sharedByNickname]])?[NSString stringWithFormat:@"\"%@\"分享的", sharedByNickname]:@"", (memberCount>0?[NSString stringWithFormat:@"，当前群聊参与者共%d人", memberCount]:@"")];
    }

    [GChatDataHelper addSystemInfoData:gid gname:gname infoContent:hint date:nil showNotify:NO playAudio:NO];
}

// * 往聊天界面中显示一条被"我"(我就是群主自已了，不然哪有转让权限)转让群主权限成功的系统通知给"自已"看（此
// * 通知并非服务器发出，而是本地准备好的，仅用UI显示）。
+ (void) addSystenInfo_transferSucessForLocalUser:(NSString *)beTransferNickname
                                              gid:(NSString *)gid
                                            gname:(NSString *)gname
{
    if(beTransferNickname != nil)
    {
        NSString *hint = [NSString stringWithFormat:@"你以将群主权限转让给\"%@\"", beTransferNickname];
        [GChatDataHelper addSystemInfoData:gid gname:gname infoContent:hint date:nil showNotify:NO playAudio:NO];
    }
}

// * 往聊天界面中显示一条被"我"(我就是群主自已了，不然哪有移除权限)删除群员成功的系统通知给"自已"看（此
// * 通知并非服务器发出，而是本地准备好的，仅用UI显示）。
+ (void) addSystenInfo_removeMembersSucessForLocalUser:(NSArray<GroupMemberEntity *> *)beRemovedMembers
                                                   gid:(NSString *)gid
                                                 gname:(NSString *)gname
{
    NSInteger size = [beRemovedMembers count];
    if(beRemovedMembers != nil && size > 0)
    {
        NSString *beInvitedNames = nil;
        if (size > 1)
            beInvitedNames = [NSString stringWithFormat:@"\"%@ 等\" %ld人", [beRemovedMembers objectAtIndex:0].nickname, (long)size];
        else
            beInvitedNames = [NSString stringWithFormat:@"\"%@\"", [beRemovedMembers objectAtIndex:0].nickname];

        NSString *hint = [NSString stringWithFormat:@"你将%@移出了本群", beInvitedNames];
        [GChatDataHelper addSystemInfoData:gid gname:gname infoContent:hint date:nil showNotify:NO playAudio:NO];
    }
}

// 往聊天界面中显示一条被"我"邀请入群成功的系统通知给"自已"看（此通知并非服务器发出，而是本地准备好的，仅用UI显示）。
+ (void) addSystenInfo_inviteMembersSucessForLocalUser:(NSArray<GroupMemberEntity *> *)beInvitedMembers
                                                   gid:(NSString *)gid
                                                 gname:(NSString *)gname
{
    NSInteger size = [beInvitedMembers count];
    if(beInvitedMembers != nil && size > 0)
    {
        NSString *beInvitedNames = nil;
        if (size > 1)
            beInvitedNames = [NSString stringWithFormat:@"\"%@ 等\" %ld人", [beInvitedMembers objectAtIndex:0].nickname, (long)size];
        else
            beInvitedNames = [NSString stringWithFormat:@"\"%@\"", [beInvitedMembers objectAtIndex:0].nickname];

        NSString *hint = [NSString stringWithFormat:@"你邀请%@加入了群聊", beInvitedNames];
        [GChatDataHelper addSystemInfoData:gid gname:gname infoContent:hint date:nil showNotify:NO playAudio:NO];
    }
}

// 往聊天界面中显示一条群名被"我"自已修改的系统通知给"自已"看（此通知并非服务器发出，而是本地准备好的，仅用UI显示）。
+ (void) addSystemInfo_groupNameChangedForLocalUser:(NSString *)gid newGroupname:(NSString *)newGroupname
{
    NSString *hint = [NSString stringWithFormat:@"你已将群名修改为\"%@\"", newGroupname];
    [GChatDataHelper addSystemInfoData:gid gname:newGroupname infoContent:hint date:nil showNotify:NO playAudio:NO];
}

// 添加一条通用群聊系统通知到聊天数据结构中.
+ (void) addSystemInfoData:(NSString *)gid
                     gname:(NSString *)gname
               infoContent:(NSString *)systemInfo
                      date:(NSDate *)time
                showNotify:(BOOL)showNotification
                 playAudio:(BOOL)playPromtAudio
{
    [GChatDataHelper addSystemInfoData:gid gname:gname infoContent:systemInfo fingerPrint:nil date:time showNotify:showNotification playAudio:playPromtAudio];
}

+ (void) addSystemInfoData:(NSString *)gid
                     gname:(NSString *)gname
               infoContent:(NSString *)systemInfo
               fingerPrint:(NSString *)fingerPrint
                      date:(NSDate *)time
                showNotify:(BOOL)showNotification
                 playAudio:(BOOL)playPromtAudio
{
    NSString *fp = (fingerPrint.length > 0) ? fingerPrint : rb_groupSystemInfoFp(gid, systemInfo);
    MsgBody4Group *msgBody = [MsgBody4Group constructGroupChatMsgBody:TM_TYPE_SYSTEAM_INFO
                                                          srcUserUid:@"0"
                                                         srcNickName:@""
                                                               toGid:gid
                                                                 msg:systemInfo
                                                            parentFp:fp
                                                                  at:nil];
    [GChatDataHelper addChatMessageDataIncoming:fp gid:gid gname:gname withBody:msgBody date:time showNotify:showNotification playAudio:playPromtAudio andQuote:msgBody];
}

// 添加一条群聊/频道普通聊天消息到数据结构中.
+ (void) addChatMessageDataIncoming:(NSString *)fingerPrint
                                gid:(NSString *)gid
                              gname:(NSString *)gname
                           withBody:(MsgBody4Group *)msgBody
                               date:(NSDate *)time
                         showNotify:(BOOL)showNotification
                          playAudio:(BOOL)playPromtAudio
                           andQuote:(QuoteMeta *)quoteMeta
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [GChatDataHelper addChatMessageDataIncoming:fingerPrint gid:gid gname:gname withBody:msgBody date:time showNotify:showNotification playAudio:playPromtAudio andQuote:quoteMeta];
        });
        return;
    }

    int msgType = msgBody.ty;
    
    // 如果收到的消息"撤回指令"，则需要单独特殊处理
    if(msgType == TM_TYPE_REVOKE){
        DDLogInfo(@"【这是消息撤回指令，马上处理撤回逻辑】 ==> msgType=%d，fingerPrint = %@，messageContent=%@", msgType, fingerPrint, msgBody.m);
        
        // 开始处理撤回指令完整逻辑
        [MessageRevokingManager processRevokeMessage_incoming:CHAT_TYPE_GROUP_CHAT fpForRevokeCMD:fingerPrint fromId:gid messageContent:msgBody.m];
        
//        // 世界频道的
//        if([GroupEntity isWorldChat:gid]) {
//            // 无条件加一个提示到首页消息界面中
//            [[[IMClientManager sharedInstance] getAlarmsProvider] setBBSMsgAlarm:msgBody flagNumToAdd:0];
//        }
        // 普通群聊的
//        else
        {
            // 更新首页消息列表中的显示
            NSString *previewNick = [AlarmsProvider rb_resolvedGroupConversationPreviewSenderNick:msgBody.nickName senderUid:msgBody.f];
            [[[IMClientManager sharedInstance] getAlarmsProvider] addAGroupChatMsgAlarm:msgBody.ty
                                                                                    gid:gid gname:gname
                                                                       fromUserNickName:previewNick
                                                                                    msg:msgBody.m
                                                                                   date:time
                                                                           flagNumToAdd:0 at:NO
                                                                   fingerPrint:fingerPrint];
            if ([BasicTool isStringEmpty:[BasicTool trim:previewNick]]) {
                NSString *u = [BasicTool trim:msgBody.f];
                if (u.length > 0 && ![u isEqualToString:@"0"]) {
                    [[[IMClientManager sharedInstance] getAlarmsProvider] rb_scheduleResolveGroupPreviewSenderNickForGid:gid senderUid:u msgType:msgBody.ty rawMsg:msgBody.m];
                }
            }
        }
        return;
    }
    
    //***************************************************************** 加入数据结构中
    // 与 SyncKey 增量里的 fp 对齐：MT45 通道传入的 fingerPrint 常为 QoS 包级指纹，协议体 parentFp 才是服务端/DB 侧消息 id；仅用前者会导致「实时一条 + 增量一条」双条。
    NSString *stableFp = (msgBody.parentFp.length > 0) ? msgBody.parentFp : fingerPrint;
    DDLogInfo(@"[RBGroupSysTrace][StoreBegin] gid=%@ gname=%@ inputFp=%@ stableFp=%@ parentFp=%@ msgType=%d sender=%@ frontVisible=%@ msg=%@",
              gid,
              gname,
              fingerPrint,
              stableFp,
              msgBody.parentFp,
              msgBody.ty,
              msgBody.f,
              (([IMClientManager sharedInstance].currentFrontGroupChattingGroupID != nil
                && [[IMClientManager sharedInstance].currentFrontGroupChattingGroupID isEqualToString:gid]) ? @"YES" : @"NO"),
              msgBody.m);

    BOOL priorFpExisted = NO;
    if (stableFp.length > 0) {
        priorFpExisted = ([[[IMClientManager sharedInstance] getGroupsMessagesProvider] findMessageByFingerPrint:gid fp:stableFp] != nil);
    }
    BOOL isFrontVisibleGroup = ([IMClientManager sharedInstance].currentFrontGroupChattingGroupID != nil
                                && [[IMClientManager sharedInstance].currentFrontGroupChattingGroupID isEqualToString:gid]);
    if (priorFpExisted) {
        if (isFrontVisibleGroup && stableFp.length > 0) {
            [[QoS4ReciveDaemon sharedInstance] addRecievedWithFingerPrint:stableFp];
        }
        DDLogDebug(@"[GChatDataHelper] 群系统/群聊消息已存在（gid=%@, fp=%@），跳过重复提示与重复未读累加", gid, stableFp);
        return;
    }
    JSQMessage *cme = [JSQMessage prepareChatMessageData_incoming:msgBody.m
                                                // 消息发送人的昵称
                                                withNickName:msgBody.nickName
                                                     andTime:time
                                                  andMsgType:msgBody.ty
                                                    senderId:msgBody.f];

    if(cme != nil)
    {
        // 消息的指纹码（也就是唯一ID啦）
        cme.fingerPrintOfProtocal = stableFp;
        // 群聊消息需要记录下扩散写前由消息发起者发出消息的原始指纹码（以便消息"撤回"功能时使用）
        cme.fingerPrintOfParent = msgBody.parentFp;
        // 尝试设置引用的消息信息（quoteMeta为null则表示无引用消息则）
        [cme setQuoteMeta:quoteMeta];
        
        // 无论聊天界面是否在前台，都标记该消息是否@了我（用于聊天界面中的"有人@我"浮动提示）
        cme.atMe = [BasicTool isAtMe:msgBody.at];
        
        // 将"收到的"消息放入数据结构
        [[[IMClientManager sharedInstance] getGroupsMessagesProvider] putMessage:gid withData:cme];
        DDLogInfo(@"[RBGroupSysTrace][StorePut] gid=%@ stableFp=%@ sender=%@ msgType=%d atMe=%@",
                  gid,
                  stableFp,
                  msgBody.f,
                  msgBody.ty,
                  cme.atMe ? @"YES" : @"NO");
        if (isFrontVisibleGroup && stableFp.length > 0) {
            [[QoS4ReciveDaemon sharedInstance] addRecievedWithFingerPrint:stableFp];
        }
    }
    AlarmsProvider *alarmsProvider = [[IMClientManager sharedInstance] getAlarmsProvider];
    BOOL archivedConversation = [alarmsProvider isArchived:AMT_groupChatMessage dataId:gid];

    //***************************************************************** 声音提示
    if(!archivedConversation && playPromtAudio && [UserDefaultsToolKits isChatMsgToneOpen:gid])
    {
        DDLogInfo(@"[RBGroupSysTrace][StoreAudio] gid=%@ stableFp=%@ willPlay=%@", gid, stableFp, @"YES");
        // 来一个声音提示
        [JSQSystemSoundPlayer jsq_playMessageReceivedSound];
    }

    //***************************************************************** 首页消息和系统Notification提示
    int flagNumToAdd = 0;
    BOOL atMe = NO;
    // 当前群聊天的界面处于后台时的消息提示
    if(!isFrontVisibleGroup)
    {
        // 未读消息数+1（当且仅当聊天界面处于后台时）
        flagNumToAdd += 1;
        // 有人 @ 我（当且仅当聊天界面处于后台时）
        atMe = [BasicTool isAtMe:msgBody.at];

        if(!archivedConversation && showNotification && [UserDefaultsToolKits isChatMsgToneOpen:gid])
        {
            DDLogInfo(@"[RBGroupSysTrace][StorePush] gid=%@ stableFp=%@ localPush=%@ unreadBump=%d atMe=%@", gid, stableFp, @"YES", flagNumToAdd, atMe ? @"YES" : @"NO");
            [LocalPushHelper showAGroupChatMsgPush:[GroupEntity isWorldChat:gid] msgType:msgBody.ty msg:msgBody.m fromNickName:msgBody.nickName toGid:gid toGname:gname];
        }
    }
    else {
        DDLogInfo(@"[RBGroupSysTrace][StorePush] gid=%@ stableFp=%@ localPush=%@ unreadBump=%d reason=front_visible",
                  gid, stableFp, @"NO", 0);
    }

//    // 世界频道的
//    if([GroupEntity isWorldChat:gid])
//    {
//        // 无条件加一个提示到首页消息界面中
//        [[[IMClientManager sharedInstance] getAlarmsProvider] setBBSMsgAlarm:msgBody flagNumToAdd:flagNumToAdd];
//    }
//    // 普通群聊的
//    else
    {
        // 无条件加一个提示到首页消息列表中（就像主流IM微信一样，可以很方便的找到最近聊天的人）
        NSString *previewNick = [AlarmsProvider rb_resolvedGroupConversationPreviewSenderNick:msgBody.nickName senderUid:msgBody.f];
        [[[IMClientManager sharedInstance] getAlarmsProvider] addAGroupChatMsgAlarm:msgBody.ty
                                                                                gid:gid gname:gname
                                                                   fromUserNickName:previewNick
                                                                                msg:msgBody.m
                                                                               date:time
                                                                       flagNumToAdd:flagNumToAdd at:atMe withNotify:YES fingerPrint:stableFp priorFingerPrintExistedInMemory:priorFpExisted];
        DDLogInfo(@"[RBGroupSysTrace][AlarmUpdate] gid=%@ stableFp=%@ flagNumToAdd=%d atMe=%@ previewNick=%@ priorExisted=%@",
                  gid, stableFp, flagNumToAdd, atMe ? @"YES" : @"NO", previewNick, priorFpExisted ? @"YES" : @"NO");
        if ([BasicTool isStringEmpty:[BasicTool trim:previewNick]]) {
            NSString *u = [BasicTool trim:msgBody.f];
            if (u.length > 0 && ![u isEqualToString:@"0"]) {
                [[[IMClientManager sharedInstance] getAlarmsProvider] rb_scheduleResolveGroupPreviewSenderNickForGid:gid senderUid:u msgType:msgBody.ty rawMsg:msgBody.m];
            }
        }
    }
}
// **************************************************************************** 以下方法仅为本收到的消息所准备 END


// **************************************************************************** 以下方法仅为本发出的消息所准备 START

+ (JSQMessage *)addChatMessageData_outgoing:(NSString *)gid withData:(JSQMessage *)entity
{
    // 本地发出的群聊消息作为到服务端被扩散写为其它群员消息的"父"消息，是没有"父"指纹码的，为了
    // 让处理本地发出的和收到的群聊消息在撤回逻辑上的代码，所以把自身的这条消息的指纹码也填到了
    // fingerPrintOfParent字段里，这在逻辑上并没有什么问题，可以放心处理
    entity.fingerPrintOfParent = entity.fingerPrintOfProtocal;
    
    // 将一条（”发出的“）消息放到该好友的消息列表中（放进去时会自动通知列表的观察者，而观察者将会实现ui的刷新）
    [[[IMClientManager sharedInstance] getGroupsMessagesProvider] putMessage:gid withData:entity];

    return entity;
}
// **************************************************************************** 以下方法仅为本发出的消息所准备 END

@end
