//telegram @wz662
#import "ChatMessageEventImpl.h"
//#import "Toast+UIView.h"
#import "AppDelegate.h"
//#import "MainViewController.h"
#import "ChatDataHelper.h"
#import "MessageHelper.h"
#import "IMClientManager.h"
#import "QueryOfflineChatMsgAsync.h"
#import "PromtHelper.h"
#import "ChatMessageEventProcessor.h"
#import "TMessageHelper.h"
#import "TChatDataHelper.h"
#import "GChatDataHelper.h"
#import "LocalPushHelper.h"
#import "RealTimeVoiceMessageHelper.h"
#import "VoipRecordMeta.h"
#import "CallManager.h"
#import "CallKitManager.h"
#import "CallViewController.h"
#import "CallIncomingPopupManager.h"
#import "ViewControllerFactory.h"
#import "MessagesProvider.h"
#import "NSMutableArrayObservableEx.h"
#import "AlarmsProvider.h"
#import "NotificationCenterFactory.h"
#import "AlarmType.h"
#import "GroupsProvider.h"
#import "GroupEntity.h"
#import "GroupsMessagesProvider.h"
#import "FriendsListProvider.h"
#import "UserDefaultsToolKits.h"
#import "Protocal.h"
#import "JSQMessage.h"
#import "MsgBodyRoot.h"
#import "UserProtocalsType.h"
#import "MessageRevokingManager.h"
#import "TimeTool.h"
#import "ClientCoreSDK.h"
#import "FileMeta.h"
#import "ContactMeta.h"
#import "LocationMeta.h"
#import "EVAToolKits.h"


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface ChatMessageEventImpl ()
/**
 * 新增消息的观察者：当前主要用于好友列表中的用户消息未计条数的刷新和显示（通知UI及时进行刷新）.
 */
@property (nonatomic, copy) ObserverCompletion addMessagesObserver;
/// MT65 本人→对端：由 MsgBodyRoot 构造与本地发送路径一致的 outgoing JSQMessage（其它端已发出、本机无乐观插入时须落库）。
+ (JSQMessage *)rb_mt60_outgoingMessageFromBody:(MsgBodyRoot *)tm fingerPrint:(NSString *)fp;
@end


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation ChatMessageEventImpl

+ (JSQMessage *)rb_mt60_outgoingMessageFromBody:(MsgBodyRoot *)tm fingerPrint:(NSString *)fp
{
    if (tm == nil) {
        return nil;
    }
    NSString *m = tm.m ?: @"";
    int ty = tm.ty;
    NSString *safeFp = (fp.length > 0) ? fp : nil;
    JSQMessage *out = nil;

    switch (ty) {
        case TM_TYPE_TEXT:
            out = [JSQMessage createChatMsgEntity_OUTGO_TEXT:m withFingerPrint:safeFp];
            break;
        case TM_TYPE_IMAGE:
            out = [JSQMessage createChatMsgEntity_OUTGO_IMAGE:m withFingerPrint:safeFp];
            break;
        case TM_TYPE_VOICE:
            out = [JSQMessage createChatMsgEntity_OUTGO_VOICE:m withFingerPrint:safeFp];
            break;
        case TM_TYPE_FILE: {
            FileMeta *fm = [FileMeta fromJSON:m];
            if (fm == nil) {
                return nil;
            }
            out = [JSQMessage createChatMsgEntity_OUTGO_FILE:fm withFingerPrint:safeFp];
            break;
        }
        case TM_TYPE_SHORTVIDEO: {
            FileMeta *fm = [FileMeta fromJSON:m];
            if (fm == nil) {
                return nil;
            }
            out = [JSQMessage createChatMsgEntity_OUTGO_SHORTVIDEO:fm withFingerPrint:safeFp];
            break;
        }
        case TM_TYPE_CONTACT: {
            ContactMeta *cm = [ContactMeta fromJSON:m];
            if (cm == nil) {
                return nil;
            }
            out = [JSQMessage createChatMsgEntity_OUTGO_CONTACT:cm withFingerPrint:safeFp];
            break;
        }
        case TM_TYPE_LOCATION: {
            LocationMeta *lm = [LocationMeta fromJSON:m];
            if (lm == nil) {
                return nil;
            }
            out = [JSQMessage createChatMsgEntity_OUTGO_LOCATION:lm withFingerPrint:safeFp];
            break;
        }
        case TM_TYPE_VOIP_RECORD: {
            VoipRecordMeta *vrm = [VoipRecordMeta fromJSON:m];
            if (vrm == nil && m.length > 0) {
                vrm = [VoipRecordMeta fromServerCancelledJSON:m];
            }
            if (vrm == nil) {
                return nil;
            }
            out = [JSQMessage createChatMsgEntity_OUTGO_VOIPRECORD:vrm];
            if (safeFp.length > 0) {
                out.fingerPrintOfProtocal = safeFp;
            }
            break;
        }
        case TM_TYPE_RED_PACKET:
        case TM_TYPE_TRANSFER:
        case TM_TYPE_GIFT_SEND:
        case TM_TYPE_GIFT_GET:
            out = [JSQMessage createChatMsgEntity_OUTGO_JSONContent:m msgType:ty withFingerPrint:safeFp];
            break;
        case TM_TYPE_SYSTEAM_INFO:
            out = [[JSQMessage alloc] initWithSenderId:[[ClientCoreSDK sharedInstance] currentLoginUserId]
                                   senderDisplayName:@"我"
                                                date:[TimeTool getIOSDefaultDate]
                                                text:m
                                           andIsCome:TM_TYPE_SYSTEAM_INFO];
            out.fingerPrintOfProtocal = safeFp;
            break;
        case TM_TYPE_REVOKE:
            return nil;
        default:
            out = [JSQMessage createChatMsgEntity_OUTGO_JSONContent:m msgType:ty withFingerPrint:safeFp];
            break;
    }
    return out;
}

//-----------------------------------------------------------------------------------------
#pragma mark - 内部方法

/*!
 @Override
* 收到普通消息的回调事件通知。
* <br>
* 应用层可以将此消息进一步按自已的IM协议进行定义，从而实现完整的即时通信软件逻辑。
*
* @param fingerPrintOfProtocal 当该消息需要QoS支持时本回调参数为该消息的特征指纹码，否则为null
* @param userid 消息的发送者id（RainbowCore框架中规定发送者id=“0”即表示是由服务端主动发过的，否则表示的是其它客户端发过来的消息）
* @param dataContent 消息内容的文本表示形式
*/
- (void) onRecieveMessage:(NSString *)fingerPrintOfProtocal withUserId:(NSString *)userid andContent:(NSString *)dataContent andTypeu:(int)typeu
{
    NSLog(@"[ChatMessageEventImpl] [typeu=%d] IM通道收到来自对象%@的数据:%@", typeu, userid, dataContent);

    NSString *msg = dataContent;

    switch(typeu)
    {
        //---------------------------------------------------------------------------- 一般性指令解析 START
        // 好友上线通知
        case MT01_OF_ONLINE_NOTIVICATION:
        {
            NSString *uid = nil;
            NSString *onlineStartTime = nil;
            NSString *trimMsg = [msg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimMsg.length > 0 && [trimMsg hasPrefix:@"{"]) {
                NSData *d = [trimMsg dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *dic = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
                if ([dic isKindOfClass:[NSDictionary class]]) {
                    uid = [dic[@"uid"] description];
                    if (dic[@"onlineStartTime"] != nil && dic[@"onlineStartTime"] != [NSNull null]) {
                        onlineStartTime = [dic[@"onlineStartTime"] description];
                    }
                }
            }
            if (uid.length == 0) {
                uid = [MessageHelper pareseRecieveOnlineNotivication:userid withMsg:msg];
            }
            if (onlineStartTime.length == 0) {
                onlineStartTime = [NSString stringWithFormat:@"%.0f", [NSDate date].timeIntervalSince1970 * 1000.0];
            }

            DDLogDebug(@"[ChatMessageEventImpl] 好友%@上线了！", uid);

            // 设置上线状态
            UserEntity *friendRee = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid:(uid)];
            if(friendRee != nil) {
                friendRee.onlineStartTime = onlineStartTime;
                friendRee.offlineTime = nil;
                [friendRee online];
            }

            // 好友上线了就尝试获取该用户可能发过来的离线消息（此时离线消息可能会
            // 在网络情况复杂的情况下发生（比如对方在发时我被判定不在线，但实际我是在线的等等））
            [QueryOfflineChatMsgAsync doIt:uid hudParentView:nil];// FIXME: 20250211日jackjiang注 - 暂时看来收到上线通知就去尝试取离线消息不够经济，貌似也没有必要，可考虑注释掉以备长期观察，有必要再开放必行代码！

            break;
        }
        // 好友下线通知
        case MT02_OF_OFFLINE_NOTIVICATION:
        {
            NSString *uid = nil;
            NSString *offlineTime = nil;
            NSString *trimMsg = [msg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimMsg.length > 0 && [trimMsg hasPrefix:@"{"]) {
                NSData *d = [trimMsg dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *dic = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
                if ([dic isKindOfClass:[NSDictionary class]]) {
                    uid = [dic[@"uid"] description];
                    if (dic[@"offlineTime"] != nil && dic[@"offlineTime"] != [NSNull null]) {
                        offlineTime = [dic[@"offlineTime"] description];
                    }
                }
            }
            if (uid.length == 0) {
                uid = [MessageHelper pareseRecieveOfflineNotivication:userid withMsg:msg];
            }
            if (offlineTime.length == 0) {
                offlineTime = [NSString stringWithFormat:@"%.0f", [NSDate date].timeIntervalSince1970 * 1000.0];
            }

            DDLogDebug(@"[ChatMessageEventImpl] 好友%@下线了。。。", uid);

            // 设置下线状态
            UserEntity *friendRee = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid:(uid)];
            if(friendRee != nil) {
                friendRee.offlineTime = offlineTime;
                friendRee.onlineStartTime = nil;
                [friendRee offline];
            }
            
            break;
        }
        // 【临时聊天消息：由服务端转发给接收人B的【步骤2/2】】
        case MT43_OF_TEMP_CHAT_MSG_SERVER_TO_B:
        {
            // 来自发送方的临时聊天消息
            MsgBody4Guest *tcmd = [TMessageHelper parseTempChatMsg_SERVER_TO_B_Message:msg];
            // 将数据放入
            [TChatDataHelper addChatMessageData_incoming:fingerPrintOfProtocal msgBody:tcmd date:nil showNotify:YES playAudio:YES andQuote:tcmd];
            break;
        }
        // 普通一对一好友聊天消息（聊天消息可能是：文本、图片、语音留言、礼物等）
        case MT03_OF_CHATTING_MESSAGE:
        {
            UserEntity *ree = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUserId:userid];

            if(ree != nil)
            {
                // ** 如果收到的是对方赠送的礼品，则要单独处理
                // 自v2.0后，普通的原始文本消息再也不是简单的纯文本了，而是MsgBodyRoot及其子类的JSON对象文件（
                // 此对象中的uid其实就是发送方的uid，目前主要用于服务端的离线消息存储时使用，客户端的话随便用）
                MsgBodyRoot *tm = [MsgBodyRoot parseFromSender:msg];
                if(tm != nil && tm.ty == TM_TYPE_GIFT_SEND)
                {
                    // TODO: 收到礼物功能暂未实现，但为了用户体验，给出一条消息提示用户！
                    [ChatMessageEventImpl addUnsupportFriendCmdHint:fingerPrintOfProtocal uid:userid hint:@"[暂时不支持礼物消息，请在Android端接收和查看]"];
                    DDLogDebug(@"[收到消息]TM_TYPE_GIFT_SEND 类型消息尚未有代码实现！！！");
                    return;
                }
                // ** 如果收到的是对方索取礼品消息，因为暂时不支持此消息，单独给出友好提示！
                else if(tm != nil && tm.ty == TM_TYPE_GIFT_GET)
                {
                    // TODO: 收到索取礼物功能暂未实现，但为了用户体验，给出一条消息提示用户！
                    [ChatMessageEventImpl addUnsupportFriendCmdHint:fingerPrintOfProtocal uid:userid hint:@"[暂时不支持索取礼品消息，请在Android端接收和查看]"];
                    DDLogDebug(@"[收到消息]TM_TYPE_GIFT_GET 类型消息尚未有代码实现！！！");
                    return;
                }
                // ** 收到对方发来的实时音视频聊天记录消息 → 作为正常 VOIP_RECORD 类型消息存入聊天记录
                else if(tm != nil && tm.ty == TM_TYPE_VOIP_RECORD)
                {
                    VoipRecordMeta *vrm = [VoipRecordMeta fromJSON:tm.m];
                    if (vrm == nil && tm.m.length > 0) {
                        vrm = [VoipRecordMeta fromServerCancelledJSON:tm.m]; // 服务端离线取消兜底格式
                    }
                    DDLogDebug(@"【通话记录】收到对方通话记录消息: vrm.voipType=%d、vrm.recordType=%d", vrm.voipType, vrm.recordType);
                    
                    // 本条是否为「服务端 _cancelled」兜底（与客户端简版是不同状态，但只展示一条，优先用本条）
                    BOOL incomingIsServerCancelled = (fingerPrintOfProtocal.length > 0 && [fingerPrintOfProtocal hasSuffix:@"_cancelled"])
                        || (tm.m.length > 0 && [tm.m containsString:@"\"status\""] && [tm.m containsString:@"cancelled"]);
                    
                    // ★ 去重/合并：最近 120 秒内已有同 recordType 的通话记录时，不展示两条
                    @try {
                        NSMutableArrayObservableEx *msgs = [[[IMClientManager sharedInstance] getMessagesProvider] getMessages:userid];
                        NSArray *dataList = [msgs getDataList];
                        NSDate *now = [NSDate date];
                        NSInteger foundIndex = -1;
                        JSQMessage *existingMsg = nil;
                        for (NSInteger i = dataList.count - 1; i >= 0 && i >= (NSInteger)dataList.count - 15; i--) {
                            JSQMessage *msg = dataList[i];
                            if (msg.msgType != TM_TYPE_VOIP_RECORD || msg.date == nil) continue;
                            NSTimeInterval timeDiff = [now timeIntervalSinceDate:msg.date];
                            if (timeDiff < 0 || timeDiff >= 120) continue;
                            VoipRecordMeta *existVrm = msg.voipRecordMeta;
                            if (existVrm == nil && msg.text != nil && [msg.text hasPrefix:@"{"]) {
                                existVrm = [VoipRecordMeta fromJSON:msg.text];
                                if (existVrm == nil) existVrm = [VoipRecordMeta fromServerCancelledJSON:msg.text];
                            }
                            if (existVrm != nil && vrm != nil && existVrm.recordType == vrm.recordType) {
                                foundIndex = i;
                                existingMsg = msg;
                                break;
                            }
                        }
                        if (foundIndex >= 0 && existingMsg != nil) {
                            if (incomingIsServerCancelled) {
                                // 用服务端 _cancelled 状态覆盖已有的一条，只展示一条且状态更明确
                                existingMsg.text = tm.m;
                                existingMsg.voipRecordMeta = vrm ?: [VoipRecordMeta fromServerCancelledJSON:tm.m];
                                [msgs set:(NSUInteger)foundIndex withObj:existingMsg needNotify:YES];
                                NSLog(@"【通话记录】合并：已用服务端取消兜底更新同一条通话记录（不展示两条）");
                            } else {
                                NSLog(@"【通话记录】去重：本地已有相同 recordType 的通话记录，跳过此条 IM 消息。");
                            }
                            return;
                        }
                    } @catch (NSException *e) {
                        NSLog(@"【通话记录】去重/合并检查异常: %@", e);
                    }
                    
                    // 无重复，正常加入一条
                    [ChatDataHelper addChatMessageData_incoming:fingerPrintOfProtocal
                                                    msgContent:tm.m
                                                      withTime:nil
                                                     playAudio:NO
                                                    showNotify:NO
                                                       msgType:TM_TYPE_VOIP_RECORD
                                                       withRee:ree
                                                      andQuote:nil];
                    return;
                }
                // ** 其它正常消息使用正常逻辑处理就行了！
                else
                {
                    [ChatDataHelper addChatMessageData_incoming:fingerPrintOfProtocal msgContent:tm.m withTime:nil playAudio:YES showNotify:YES msgType:tm.ty withRee:ree andQuote:tm];
                }
            }
            else
            {
                DDLogDebug(@"[收到消息]来自userid=%@的一对一好友聊天消息虽收到，但此此人不在好友列表中，本条消息处将被忽略！", userid);
            }

            break;
        }
        // 【MT65】服务端同步的聊天消息体（与 MT03 JSON 同构；userid 常为 "0"），勿落入 default 丢弃
        case MT65_OF_CHATTING_MESSAGE_SERVER_SYNC:
        {
            MsgBodyRoot *tm = [MsgBodyRoot parseFromSender:msg];
            if (tm == nil) {
                DDLogDebug(@"[ChatMessageEventImpl] MT65 解析 MsgBodyRoot 失败");
                break;
            }
            NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
            if (myUid.length == 0) {
                break;
            }
            if (tm.cy != CHAT_TYPE_FREIDN_CHAT) {
                DDLogDebug(@"[ChatMessageEventImpl] MT65 非单聊 cy=%d，暂不处理", tm.cy);
                break;
            }
            NSString *fromUid = tm.f ?: @"";
            NSString *toUid = tm.t ?: @"";
            NSString *peerUid = nil;
            if ([fromUid isEqualToString:myUid] && toUid.length > 0) {
                peerUid = toUid;
            } else if ([toUid isEqualToString:myUid] && fromUid.length > 0) {
                peerUid = fromUid;
            }
            if (peerUid.length == 0) {
                DDLogDebug(@"[ChatMessageEventImpl] MT65 无法解析会话对端 f=%@ t=%@", fromUid, toUid);
                break;
            }
            if ([fromUid isEqualToString:myUid]) {
                // 本人→对端：含「其它端已发出、本机从未乐观插入」的多端同步。仅 notify 不会 putMessage，首进聊天页内存无此条、列表却有预览。
                UserEntity *peerRee = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUserId:peerUid];
                if (peerRee != nil) {
                    JSQMessage *outMsg = [ChatMessageEventImpl rb_mt60_outgoingMessageFromBody:tm fingerPrint:fingerPrintOfProtocal];
                    if (outMsg != nil) {
                        if (outMsg.sendStatus != SendStatus_BE_RECEIVED) {
                            outMsg.sendStatus = SendStatus_BE_RECEIVED;
                        }
                        [outMsg setQuoteMeta:tm];
                        [ChatDataHelper addChatMessageData_outgoing:peerUid withData:outMsg];
                        // 与本地发出一致：刷新首页「消息」会话列表预览与时间排序（addChatMessageData_outgoing 不会动 Alarms）
                        [AlarmsProvider addSingleChatMsgAlarmForLocal:peerUid friendName:[peerRee getNickNameWithRemark] withMsg:(tm.m ?: @"") andType:tm.ty withAlarmType:AMT_friendChatMessage];
                        ObserverCompletion addMessagesObs = [[[IMClientManager sharedInstance] getTransDataListener] getAddMessagesObserver];
                        if (addMessagesObs != nil) {
                            addMessagesObs(nil, nil);
                        }
                    }
                }
                // outgoing 的 ADD 通知在 ChatRoot 观察者里被刻意跳过（避免与 finishSending 双插）；补 UNKNOW 整表对齐当前会话。
                [[[IMClientManager sharedInstance] getMessagesProvider] notifyObserversForChatUid:peerUid];
            } else {
                UserEntity *ree = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUserId:fromUid];
                if (ree != nil) {
                    // MT65：与发送侧同 fp 的服务端同步；落库但不叠加未读、不响铃不弹本地推送（对齐 MT03 正常入站的差异）
                    [ChatDataHelper addChatMessageData_incoming:fingerPrintOfProtocal msgContent:tm.m withTime:nil playAudio:NO showNotify:NO msgType:tm.ty withRee:ree andQuote:tm suppressUnreadBump:YES];
                } else {
                    DDLogDebug(@"[ChatMessageEventImpl] MT65 来自%@但不在好友列表，忽略", fromUid);
                }
            }
            break;
        }
        //---------------------------------------------------------------------------- 一般性指令解析 END

        //---------------------------------------------------------------------------- 群聊指令解析 START
        // 【群聊/世界频道聊天消息：由服务端转发给接收人B的【步骤2/2】】
        case MT45_OF_GROUP_CHAT_MSG_SERVER_TO_B:
        {
            [ChatMessageEventProcessor processMT45_OF_GROUP_CHAT_MSG_SERVER_TO_B:fingerPrintOfProtocal msg:msg];
            break;
        }
        // 【群聊系统指令：加群成功后通知被加群者（由Server发出）】通知接收人可能是在创建群或群建好后邀请进入的
        case MT46_OF_GROUP_SYSCMD_MYSELF_BE_INVITE_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=46 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT46_OF_GROUP_SYSCMD_MYSELF_BE_INVITE_FROM_SERVER:fingerPrintOfProtocal msg:msg];
            break;
        }
        // 【群聊系统指令：通用的系统信息给指定群员（由Server发出，指定群员接收）】
        case MT47_OF_GROUP_SYSCMD_COMMON_INFO_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=47 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT47_OF_GROUP_SYSCMD_COMMON_INFO_FROM_SERVER:fingerPrintOfProtocal fromUid:userid withMsg:msg];
            break;
        }
        // 【群聊系统指令：群已被解散（由Server发出，除解散者外的所有人接收）】
        case MT48_OF_GROUP_SYSCMD_DISMISSED_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=48 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT48_OF_GROUP_SYSCMD_DISMISSED_FROM_SERVER:fingerPrintOfProtocal fromUid:userid withMsg:msg];
            break;
        }
        // 【群聊系统指令："你"被踢出群聊（由Server发出，被踢者接收） 】
        case MT49_OF_GROUP_SYSCMD_YOU_BE_KICKOUT_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=49 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT49_OF_GROUP_SYSCMD_YOU_BE_KICKOUT_FROM_SERVER:fingerPrintOfProtocal fromUid:userid withMsg:msg];
            break;
        }
        // 【群聊系统指令："别人"主动退出或被群主踢出群聊（由Server发出，其它群员接收）  】
        case MT50_OF_GROUP_SYSCMD_SOMEONEB_REMOVED_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=50 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT50_OF_GROUP_SYSCMD_SOMEONEB_REMOVED_FROM_SERVER:fingerPrintOfProtocal fromUid:userid withMsg:msg];
            break;
        }
        // 【群聊系统指令：群名被修改的系统通知（由Server发出，所有除修改者外的群员接收） 】
        case MT51_OF_GROUP_SYSCMD_GROUP_NAME_CHANGED_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=51 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT51_OF_GROUP_SYSCMD_GROUP_NAME_CHANGED_FROM_SERVER:fingerPrintOfProtocal msg:msg];
            break;
        }
        case MT52_OF_GROUP_NOTIFY_JOIN_REQUEST:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=52 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT52_OF_GROUP_NOTIFY_JOIN_REQUEST:fingerPrintOfProtocal msg:msg];
            break;
        }
        case MT53_OF_GROUP_NOTIFY_JOIN_REVIEW_RESULT:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=53 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT53_OF_GROUP_NOTIFY_JOIN_REVIEW_RESULT:fingerPrintOfProtocal msg:msg];
            break;
        }
        case MT54_OF_GROUP_NOTIFY_ADMIN_OPERATION:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=54 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT54_OF_GROUP_NOTIFY_ADMIN_OPERATION:fingerPrintOfProtocal msg:msg];
            break;
        }
        case MT55_OF_GROUP_SYSCMD_GROUP_AVATAR_CHANGED_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=55 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT55_OF_GROUP_SYSCMD_GROUP_AVATAR_CHANGED_FROM_SERVER:fingerPrintOfProtocal msg:msg];
            break;
        }
        case MT56_OF_GROUP_SYSCMD_GROUP_MUTE_MODE_CHANGED_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=56 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT56_OF_GROUP_SYSCMD_GROUP_MUTE_MODE_CHANGED_FROM_SERVER:fingerPrintOfProtocal msg:msg];
            break;
        }
        case MT57_OF_GROUP_SYSCMD_GROUP_INVITE_PERMISSION_CHANGED_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=57 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT57_OF_GROUP_SYSCMD_GROUP_INVITE_PERMISSION_CHANGED_FROM_SERVER:fingerPrintOfProtocal msg:msg];
            break;
        }
        case MT58_OF_GROUP_SYSCMD_GROUP_MEMBER_PRIVACY_CHANGED_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=58 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT58_OF_GROUP_SYSCMD_GROUP_MEMBER_PRIVACY_CHANGED_FROM_SERVER:fingerPrintOfProtocal msg:msg];
            break;
        }
        case MT59_OF_GROUP_SYSCMD_GROUP_ADMIN_CHANGED_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=59 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT59_OF_GROUP_SYSCMD_GROUP_ADMIN_CHANGED_FROM_SERVER:fingerPrintOfProtocal msg:msg];
            break;
        }
        case MT60_OF_GROUP_SYSCMD_GROUP_JOIN_MODE_CHANGED_FROM_SERVER:
        {
            DDLogInfo(@"[RBGroupSysTrace][Recv] mt=60 fp=%@ from=%@ payload=%@", fingerPrintOfProtocal, userid, msg);
            [ChatMessageEventProcessor processMT60_OF_GROUP_SYSCMD_GROUP_JOIN_MODE_CHANGED_FROM_SERVER:fingerPrintOfProtocal msg:msg];
            break;
        }
        //---------------------------------------------------------------------------- 群聊指令解析 END

        //---------------------------------------------------------------------------- 好友关系指令解析 START
        case MT70_OF_FRIENDSHIP_REQUIRED_SEND_FAIL_HINT:
        {
            NSString *hint = msg.length > 0 ? msg : @"对方已不是你的好友，消息发送失败。";
            MessagesProvider *mp = [[IMClientManager sharedInstance] getMessagesProvider];
            NSString *peerUid = [mp findPeerUidByMessageFingerPrint:fingerPrintOfProtocal];
            if (peerUid.length == 0) {
                peerUid = [IMClientManager sharedInstance].currentFrontChattingUserUID;
            }

            if (peerUid.length > 0) {
                BOOL wasBlocked = [UserDefaultsToolKits isFriendChatSendBlockedUid:peerUid];
                if (!wasBlocked) {
                    [UserDefaultsToolKits markFriendChatSendBlockedUid:peerUid];
                }

                FriendsListProvider *friendsProvider = [[IMClientManager sharedInstance] getFriendsListProvider];
                UserEntity *ree = [friendsProvider getFriendInfoByUid2:peerUid];
                int friendIndex = [friendsProvider getIndex:peerUid];
                if (friendIndex >= 0) {
                    [friendsProvider remove:friendIndex uid:peerUid notify:YES];
                }

                [NotificationCenterFactory friendChatSendBlockedStateChanged_POST:peerUid blocked:YES hint:hint];
                [mp markOutgoingMessageFailedForFp:fingerPrintOfProtocal preferredPeerUid:peerUid];

                if (ree == nil) {
                    ree = [[UserEntity alloc] init];
                    ree.user_uid = peerUid;
                    ree.nickname = peerUid;
                }
                if (!wasBlocked) {
                    NSString *localUid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
                    if (localUid.length == 0) localUid = @"0";
                    NSString *sysFp = [NSString stringWithFormat:@"SYS_FRIENDSHIP_REQUIRED_FAIL_%@_%@", localUid, peerUid];
                    [ChatDataHelper addSystemInfoData:ree infoContent:hint fingerPrint:sysFp date:nil playAudio:NO showNotify:NO];
                    [APP showToastWarn:hint];
                }
            }
            break;
        }
        // 【加好友错误提示】
        // 由服务端反馈给加好友发起人的错误信息(出错的可能是：该好友已经存在于我的好友列表中、插入好友请求到db中时出错等)
        case MT06_OF_ADD_FRIEND_REQUEST_RESPONSE_FOR_ERROR_SERVER_TO_A:
        {
            NSString *content = [MessageHelper parseAddFriendRequestResponse_for_error_server_to_a:msg];
            DDLogWarn(@"[ChatMessageEventImpl] 加好友错误提示：%@", content);
            [LocalPushHelper showAddFriendRequest_RESPONSE_FOR_ERROR_SERVER_TO_A_Push:content];
            break;
        }
        // 服务端通知在线被加好友者：收到了加好友请求
        case MT07_OF_ADD_FRIEND_REQUEST_INFO_SERVER_TO_B:
        {
            UserEntity *srcUserInfo = [MessageHelper parseAddFriendRequestInfo_server_to_b:msg];
            static NSSet<NSString *> *filteredUids;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                filteredUids = [NSSet setWithArray:@[@"10000", @"10001", @"400069", @"400070"]];
            });
            if ([filteredUids containsObject:srcUserInfo.user_uid ?: @""]) {
                break;
            }
            [UserDefaultsToolKits unmarkDeletedFriendReqUid:srcUserInfo.user_uid ?: @""];
            DDLogDebug(@"[ChatMessageEventImpl] 收到了来自%@(%@)的加好友请求！！！", srcUserInfo.nickname, srcUserInfo.user_uid);
            [LocalPushHelper showAddFriendRequestPush:srcUserInfo.nickname];

            // 根据约定：目前ex10字段仅用于存放“添加好友”请求时的发生时间java时间戳（由服务端设置的，
            // 详见：RosterElementEntity类），其不为空仅限于此场景下，其它场景下用默认系统时间即可
            // 自20180507 RBv4.3以后，本字段存放的是时间戳，而非人类可读的时间字串
            NSDate *reqTime = [TimeTool convertJavaTimestampToiOSDate:srcUserInfo.ex10];
            
            // 把提示消息放到列表的首位置
            [[[IMClientManager sharedInstance] getAlarmsProvider] addAddFriendReqMergeAlarm:srcUserInfo.user_uid
                                                                                 friendName:srcUserInfo.nickname
                                                                                    reqTime:reqTime
                                                                                   numToAdd:1   // 未读数字+1
                                                                                     notify:YES // 立即刷新ui显示
                                                                                      merge:YES];
            // 递增好友请求全局缓存中的总未读数
            [[[IMClientManager sharedInstance] getFriendsReqProvider] incrementUnreadCount:YES];
            break;
        }
        // 新好友已成功被添加后由服务端发给在线用户对方的个人信息（此场景是被请求用户
        // 同意了加好友的请求时，由服务端把双方的好友信息及时交给对方（如果双方有人在线的话））
        // ，加入到本地好友列表中了后，就可以及时聊天了（如果对方此时在线的话）
        case MT10_OF_PROCESS_ADD_FRIEND_REQ_FRIEND_INFO_SERVER_TO_CLIENT:
        {
            UserEntity *userInfoFromServer = [MessageHelper parseProcessAdd_Friend_Req_friend_Info_Server_To_ClientMessage:msg];
            NSString *friendUid = userInfoFromServer.user_uid;
            NSString *friendName = userInfoFromServer.nickname;
            DDLogDebug(@"[ChatMessageEventImpl] 新好友%@(%@)已成功添加在好友列表中，可以聊天了！", friendName, friendUid);
            [UserDefaultsToolKits unmarkFriendChatSendBlockedUid:friendUid];
            [NotificationCenterFactory friendChatSendBlockedStateChanged_POST:friendUid blocked:NO hint:nil];

            // 将该好友加入到好友列表中
            [[[IMClientManager sharedInstance] getFriendsListProvider] putFriend:userInfoFromServer];

            /*
            // 来一个声音提示
            [[PromtHelper sharedInstance] newFriendAddSucessPromt];

            // 来一个本地Push通知哦
            [LocalPushHelper showNewFriendAddSucessPush:userInfoFromServer.nickname];

            //## Bug FIX：20180111 by JackJiang
            //## > 未处理的好友请求数是显示在被请求方的界面里的，当被请求方“同意”好
            //## > 友请求时，会在同意完成时的逻辑里去将未读数-1，而不需要在这里（不然就重复减1了）
//            // 首页消息界面中加友请求alarms的“未读数”-1（成功加好友后，这个好友请求就以没意义了，未读数自然也要调整哦）
//            [[[IMClientManager sharedInstance] getAlarmsProvider] accumulateAddFriendReqAlarmFlagNum:-1];
            // Bug FIX：20180111 - END

            // 像微信等IM一样：被好加友同意加好友请求后，将入一条空消息到首页消息栏里，这样可以方便的点击此消息进入聊天界面
            [[[IMClientManager sharedInstance] getAlarmsProvider] addChatMsgAlarmForAddSuccess:friendUid friendName:friendName];
             */
            
            // 加入一条系统通知到聊天消息中（去重：多设备/重复推送 MT10 时只插入一条，加锁后二次检查）
            static NSString * const kAddFriendSuccessHint = @"你们已经是好友了，现在可以好友模式聊天了。";
            if ([ChatMessageEventImpl shouldInsertAddFriendSuccessHintForFriend:friendUid]) {
                NSString *localUid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
                if (localUid.length == 0) localUid = @"0";
                NSString *fp = [NSString stringWithFormat:@"SYS_ADD_FRIEND_OK_%@_%@", localUid, friendUid ?: @"0"];
                [ChatDataHelper addSystemInfoData:userInfoFromServer infoContent:kAddFriendSuccessHint fingerPrint:fp date:nil playAudio:YES showNotify:YES];
            } else {
                DDLogDebug(@"[ChatMessageEventImpl] 与%@的会话中已有「已是好友」系统提示，跳过重复插入。", friendUid);
            }
            break;
        }
        case MT13_OF_BE_ADDED_AS_FRIEND_NOTIFY_SERVER_TO_B:
        {
            UserEntity *userInfoFromServer = [EVAToolKits fromJSON:msg withClazz:UserEntity.class];
            NSString *friendUid = userInfoFromServer.user_uid;
            if (friendUid.length == 0) {
                friendUid = userid;
            }
            if (friendUid.length == 0) {
                break;
            }
            [UserDefaultsToolKits unmarkFriendChatSendBlockedUid:friendUid];
            [NotificationCenterFactory friendChatSendBlockedStateChanged_POST:friendUid blocked:NO hint:nil];
            [[[IMClientManager sharedInstance] getFriendsListProvider] putFriend:userInfoFromServer];
            static NSString * const kAddFriendSuccessHint = @"你们已经是好友了，现在可以好友模式聊天了。";
            if ([ChatMessageEventImpl shouldInsertAddFriendSuccessHintForFriend:friendUid]) {
                NSString *localUid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
                if (localUid.length == 0) localUid = @"0";
                NSString *fp = [NSString stringWithFormat:@"SYS_ADD_FRIEND_OK_%@_%@", localUid, friendUid ?: @"0"];
                [ChatDataHelper addSystemInfoData:userInfoFromServer infoContent:kAddFriendSuccessHint fingerPrint:fp date:nil playAudio:YES showNotify:YES];
            }
            break;
        }
        // 加好友被拒绝的实时消息(由服务端在B拒绝A的请求后实时通知A)
        case MT12_OF_PROCESS_ADD_FRIEND_REQ_SERVER_TO_A_REJECT_RESULT:
        {
            UserEntity *userInfoFromServer = [MessageHelper parseProcessAdd_Friend_Req_SERVER_TO_A_REJECT_RESULTMessage:msg];
            NSString *friendUid = userInfoFromServer.user_uid;
            NSString *friendName = userInfoFromServer.nickname;
            DDLogDebug(@"[ChatMessageEventImpl] %@(%@)拒绝了你的加好友请求哦！", friendName, friendUid);

            // 来一个声音提示
            [[PromtHelper sharedInstance] tixintPromt];
            // 来一个通知哦
            [LocalPushHelper showAddFriendBeRejectPush:userInfoFromServer.nickname];
            // 加一条提示到主界面的提示功能列表中
            [[[IMClientManager sharedInstance] getAlarmsProvider] addAddFriendBeRejectAlarm:friendUid friendName:friendName];
//          [[[IMClientManager sharedInstance] getAlarmsProvider] addAddFriendBeRejectAlarm:userInfoFromServer];
            break;
        }
        //---------------------------------------------------------------------------- 好友关系指令解析 END

        //---------------------------------------------------------------------------- 实时音视频指令解析 START
        // 处理视频聊天呼叫中：请求视频聊天(由发起方A发给接收方B的)
        case MT17_OF_VIDEO_VOICE_REQUEST_REQUESTING_FROM_A:
        {
            // 检查"语音和视频通话通知"开关
            NSUserDefaults *ud_vv = [NSUserDefaults standardUserDefaults];
            BOOL voiceVideoNotiEnabled = ([ud_vv objectForKey:@"APP_VOICE_VIDEO_NOTIFICATION_ENABLED"] == nil) ? YES : [ud_vv boolForKey:@"APP_VOICE_VIDEO_NOTIFICATION_ENABLED"];
            if (!voiceVideoNotiEnabled) {
                NSLog(@"【ChatMessageEventImpl】语音视频通话通知已关闭，忽略视频来电信令。");
                break;
            }
            
            NSString *friendUserUid = [MessageHelper pareseVideoAndVoiceRequest_Requestting_from_a:msg];
            if(friendUserUid != nil)
            {
                UserEntity *friendRee = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid:friendUserUid];
                if(friendRee != nil)
                {
                    // 收到视频通话请求 → 通知 CallManager 处理来电
                    // 防止 VoIP Push 已处理过的来电被重复弹出界面
                    NSString *nickname = [friendRee getNickNameWithRemark];
                    if (![[CallManager sharedInstance] isInCall]) {
                        [[CallManager sharedInstance] onIncomingCall:friendUserUid
                                                     remoteNickname:nickname
                                                           callType:CallTypeVideo];
                        // ★ 如果 CallKit 已通过 VoIP Push 显示来电界面，
                        //   不再创建 in-app UI，由 performAnswerCallAction: 统一处理
                        if ([CallKitManager sharedInstance].currentCallUUID != nil) {
                            NSLog(@"【ChatMessageEventImpl】CallKit 已处理此来电（VoIP Push），跳过创建来电卡片。");
                        } else {
                            // 在主线程弹出前台来电卡片，由用户决定是否进入全屏
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[CallIncomingPopupManager sharedInstance] showWithCallType:CallTypeVideo
                                                                               remoteUserUid:friendUserUid
                                                                          remoteUserNickname:nickname];
                            });
                        }
                    } else {
                        NSLog(@"【ChatMessageEventImpl】收到视频来电信令但已在通话中（可能VoIP Push已处理），忽略重复弹出。");
                    }
                }
                else
                {
                    DDLogDebug(@"收到来自userid=%@的一对一好友实时视频聊天指令，但此人不在好友列表中，本条指令将被忽略！", friendUserUid);
                }
            }
            else
            {
                DDLogDebug(@"收到了好友的实时视频聊天请求，但传过来的UID=%@,这中间肯定出错了！", friendUserUid);
            }
            break;
        }
        // 处理实时语音聊天呼叫中：请求实时语音聊天(由发起方A发给接收方B的)
        case MT31_OF_REAL_TIME_VOICE_REQUEST_REQUESTING_FROM_A:
        {
            // 检查"语音和视频通话通知"开关
            NSUserDefaults *ud_vv2 = [NSUserDefaults standardUserDefaults];
            BOOL voiceVideoNotiEnabled2 = ([ud_vv2 objectForKey:@"APP_VOICE_VIDEO_NOTIFICATION_ENABLED"] == nil) ? YES : [ud_vv2 boolForKey:@"APP_VOICE_VIDEO_NOTIFICATION_ENABLED"];
            if (!voiceVideoNotiEnabled2) {
                NSLog(@"【ChatMessageEventImpl】语音视频通话通知已关闭，忽略语音来电信令。");
                break;
            }
            
            NSString *friendUserUid = [RealTimeVoiceMessageHelper pareseRealTimeVoiceRequest_Requestting_from_a:msg];
            if(friendUserUid != nil)
            {
                UserEntity *friendRee = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid:friendUserUid];
                if(friendRee != nil)
                {
                    // 收到语音通话请求 → 通知 CallManager 处理来电
                    // 防止 VoIP Push 已处理过的来电被重复弹出界面
                    NSString *nickname = [friendRee getNickNameWithRemark];
                    if (![[CallManager sharedInstance] isInCall]) {
                        [[CallManager sharedInstance] onIncomingCall:friendUserUid
                                                     remoteNickname:nickname
                                                           callType:CallTypeVoice];
                        // ★ 如果 CallKit 已通过 VoIP Push 显示来电界面，
                        //   不再创建 in-app UI，由 performAnswerCallAction: 统一处理
                        if ([CallKitManager sharedInstance].currentCallUUID != nil) {
                            NSLog(@"【ChatMessageEventImpl】CallKit 已处理此来电（VoIP Push），跳过创建来电卡片。");
                        } else {
                            // 在主线程弹出前台来电卡片，由用户决定是否进入全屏
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[CallIncomingPopupManager sharedInstance] showWithCallType:CallTypeVoice
                                                                               remoteUserUid:friendUserUid
                                                                          remoteUserNickname:nickname];
                            });
                        }
                    } else {
                        NSLog(@"【ChatMessageEventImpl】收到语音来电信令但已在通话中（可能VoIP Push已处理），忽略重复弹出。");
                    }
                }
                else
                {
                    DDLogDebug(@"收到来自userid=%@的一对一好友实时语音聊天指令，但此人不在好友列表中，本条指令将被忽略！", friendUserUid);
                }
            }
            else
            {
                DDLogDebug(@"收到了好友的实时语音聊天请求，但传过来的UID=%@,这中间肯定出错了！", friendUserUid);
            }
            break;
        }

        // 处理视频聊天呼叫中：取消视频聊天请求(发起方A取消)(MT18)
        case MT18_OF_VIDEO_VOICE_REQUEST_ABRORT_FROM_A:
        {
            NSString *friendUserUid = [MessageHelper pareseVideoAndVoiceRequest_Abort_from_a:msg];
            if(friendUserUid != nil) {
                [[CallManager sharedInstance] onRemoteCancelled:friendUserUid];
            }
            break;
        }
        // 处理视频聊天呼叫中：同意视频聊天请求(接收方B同意)(MT19)
        case MT19_OF_VIDEO_VOICE_REQUEST_ACCEPT_TO_A:
        {
            NSString *friendUserUid = [MessageHelper pareseVideoAndVoiceRequest_Accept_to_a:msg];
            if(friendUserUid != nil) {
                [[CallManager sharedInstance] onRemoteAccepted:friendUserUid];
            }
            break;
        }
        // 处理视频聊天呼叫中：拒绝视频聊天请求(接收方B拒绝)(MT20)
        case MT20_OF_VIDEO_VOICE_REQUEST_REJECT_TO_A:
        {
            NSString *friendUserUid = [MessageHelper pareseVideoAndVoiceRequest_Reject_to_a:msg];
            if(friendUserUid != nil) {
                [[CallManager sharedInstance] onRemoteRejected:friendUserUid];
            }
            break;
        }
        // 视频聊天进行中：结束本次音视频聊天(MT14)
        case MT14_OF_VIDEO_VOICE_END_CHATTING:
        {
            NSString *friendUserUid = [MessageHelper pareseVideoAndVoice_EndChatting_from_a:msg];
            if(friendUserUid != nil) {
                [[CallManager sharedInstance] onRemoteHangup:friendUserUid];
            }
            break;
        }
        // 实时语音聊天呼叫中：取消请求(发起方A取消)(MT32)
        case MT32_OF_REAL_TIME_VOICE_REQUEST_ABRORT_FROM_A:
        {
            // 实时语音聊天信令的数据格式与视频聊天一致（消息内容就是对方的UID）
            NSString *friendUserUid = msg;
            if(friendUserUid != nil) {
                [[CallManager sharedInstance] onRemoteCancelled:friendUserUid];
            }
            break;
        }
        // 实时语音聊天呼叫中：同意请求(接收方B同意)(MT33)
        case MT33_OF_REAL_TIME_VOICE_REQUEST_ACCEPT_TO_A:
        {
            NSString *friendUserUid = msg;
            if(friendUserUid != nil) {
                [[CallManager sharedInstance] onRemoteAccepted:friendUserUid];
            }
            break;
        }
        // 实时语音聊天呼叫中：拒绝请求(接收方B拒绝)(MT34)
        case MT34_OF_REAL_TIME_VOICE_REQUEST_REJECT_TO_A:
        {
            NSString *friendUserUid = msg;
            if(friendUserUid != nil) {
                [[CallManager sharedInstance] onRemoteRejected:friendUserUid];
            }
            break;
        }
        // 实时语音聊天进行中：结束本次实时语音聊天(MT35)
        case MT35_OF_REAL_TIME_VOICE_END_CHATTING:
        {
            NSString *friendUserUid = msg;
            if(friendUserUid != nil) {
                [[CallManager sharedInstance] onRemoteHangup:friendUserUid];
            }
            break;
        }

        //---------------------------------------------------------------------------- 实时音视频指令解析 END

        //---------------------------------------------------------------------------- 已读与送达（IM 推送）START
        // 【MT61】已读回执实时通知：对方已读了我的消息
        case MT61_OF_READ_RECEIPT_NOTIFY:
        {
            [ChatMessageEventImpl handleReadReceiptNotify:msg];
            break;
        }
        // 【MT62】多端状态同步（read_receipt / delete_single / delete_conversation / clear_all 等）
        case MT62_OF_READ_RECEIPT_STATE_SYNC_FROM_SERVER:
        {
            [ChatMessageEventImpl handleMT62StateSyncFromServer:msg];
            break;
        }
        // 【MT63】消息已送达回执：对方设备已收到我发的消息
        case MT63_OF_DELIVERY_RECEIPT:
        {
            [ChatMessageEventImpl handleDeliveryReceipt:msg];
            break;
        }
        //---------------------------------------------------------------------------- 已读与送达（IM 推送）END

        // 暂时不支持的消息！
        default:
        {
//            [APP showToastWarn:[NSString stringWithFormat:@"收到%@发过来的消息(typeu=%d)，但本客户端尚不支持此类消息！", userid, typeu]];
            DDLogDebug(@"【非法】来自%@的未定义typeu=%d的数据包，但本客户端尚不支持此类消息，请核实协议定义！", userid, typeu);
            break;
        }
    }
}

// 显示一条提示消息，此提示用于不支持的消息或指令类型时（比如ios版尚不支持但android版已经实现了的消息或指令时），为了提升用户体验而加的提示消息文字
+ (void)addUnsupportFriendCmdHint:fingerPrintOfProtocal uid:(NSString *)friendUid hint:(NSString *)hint
{
    UserEntity *ree = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUserId:friendUid];
    if(ree != nil)
    {
        [ChatDataHelper addChatMessageData_incoming:fingerPrintOfProtocal msgContent:hint withTime:nil playAudio:YES showNotify:YES msgType:TM_TYPE_TEXT withRee:ree andQuote:nil];
    }
    else
    {
        DDLogDebug(@"[收到不支持的消息或指令]来自userid=%@的一对一好友聊天消息或指令虽收到，但此此人不在好友列表中，本条消息或指令处将被忽略！", friendUid);
    }
}

/*!
 @Override
* 服务端反馈的出错信息回调事件通知。
*
* @param errorCode 错误码，定义在常量表 ErrorCode 中有关服务端错误码的定义
* @param errorMsg 描述错误内容的文本信息
* @see ErrorCode
*/
- (void) onErrorResponse:(int)errorCode withErrorMsg:(NSString *)errorMsg
{
    NSLog(@"【ChatMessageEventImpl】收到服务端错误消息，errorCode=%d, errorMsg=%@", errorCode, errorMsg);

    // UI显示
//    NSString *content = [NSString stringWithFormat:@"Server反馈错误码：%d,errorMsg=%@", errorCode, errorMsg];
//    [APP showToastError:content];
}


//-----------------------------------------------------------------------------------------
#pragma mark - 公开的方法

/// 该好友会话中是否在近期（5 分钟内）已有「你们已经是好友了」系统提示，用于 MT10 去重
+ (BOOL)hasRecentAddFriendSuccessHintForFriend:(NSString *)friendUid
{
    if (friendUid.length == 0) return NO;
    NSMutableArrayObservableEx *list = [[[IMClientManager sharedInstance] getMessagesProvider] getMessages:friendUid];
    NSArray *dataList = [list getDataList];
    if (dataList.count == 0) return NO;
    NSDate *now = [NSDate date];
    NSTimeInterval windowSeconds = 300.0; // 5 分钟
    NSString *keyword = @"你们已经是好友了";
    for (NSInteger i = dataList.count - 1; i >= 0 && i >= (NSInteger)dataList.count - 30; i--) {
        id obj = dataList[i];
        if (![obj isKindOfClass:[JSQMessage class]]) continue;
        JSQMessage *m = (JSQMessage *)obj;
        if (m.msgType != TM_TYPE_SYSTEAM_INFO) continue;
        if (m.date != nil && [now timeIntervalSinceDate:m.date] > windowSeconds) continue;
        if (m.text.length > 0 && [m.text containsString:keyword]) return YES;
    }
    return NO;
}

+ (BOOL)shouldInsertAddFriendSuccessHintForFriend:(NSString *)friendUid
{
    if (friendUid.length == 0) return NO;
    static NSLock *s_lock = nil;
    static NSMutableDictionary<NSString *, NSDate *> *s_lastMark = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_lock = [[NSLock alloc] init];
        s_lastMark = [NSMutableDictionary dictionary];
    });
    NSDate *now = [NSDate date];
    NSTimeInterval windowSeconds = 300.0;
    [s_lock lock];
    NSDate *marked = s_lastMark[friendUid];
    if (marked != nil && [now timeIntervalSinceDate:marked] < windowSeconds) {
        [s_lock unlock];
        return NO;
    }
    BOOL existed = [ChatMessageEventImpl hasRecentAddFriendSuccessHintForFriend:friendUid];
    if (existed) {
        s_lastMark[friendUid] = now;
        [s_lock unlock];
        return NO;
    }
    s_lastMark[friendUid] = now;
    [s_lock unlock];
    return YES;
}

//// 处理收到的聊天文本消息.
//+ (void)addChatMessageData:(NSString *)msg withTime:(NSString *)time playAudio:(BOOL)playPromtAudio showNotify:(BOOL)showNotification msgType:(int)msgType withRee:(RosterElementEntity *)ree
//{
//    [ChatHelper addChatMessageData:msg withTime:time playAudio:playPromtAudio showNotify:showNotification msgType:msgType withrecivedMessagesObserver:nil withRee:ree];
//}

- (ObserverCompletion)getAddMessagesObserver
{
    return self.addMessagesObserver;
}
- (void)setAddMessagesObserver:(ObserverCompletion)addMessagesObserver
{
    _addMessagesObserver = addMessagesObserver;
}


//-----------------------------------------------------------------------------------------
#pragma mark - 已读与送达（IM 推送）

/**
 * 【MT61】已读回执实时通知。
 *
 * 对方已读我的消息后，服务端实时推送通知。
 * dataContent 格式：
 *   {"reader_uid":"400070","chat_partner_id":"400069","chat_type":0,"last_read_time2":"1770780477215"}
 */
+ (NSDictionary *)mt62_parseInnerPayloadFromRoot:(NSDictionary *)root
{
    NSDictionary *inner = nil;
    id dataField = root[@"data"];
    if ([dataField isKindOfClass:[NSDictionary class]]) {
        inner = (NSDictionary *)dataField;
    } else if ([dataField isKindOfClass:[NSString class]]) {
        NSString *dataStr = (NSString *)dataField;
        NSData *innerBytes = [dataStr dataUsingEncoding:NSUTF8StringEncoding];
        inner = [NSJSONSerialization JSONObjectWithData:innerBytes options:0 error:nil];
    }
    if (![inner isKindOfClass:[NSDictionary class]] && [root objectForKey:@"partner_id"] != nil) {
        inner = root;
    }
    return [inner isKindOfClass:[NSDictionary class]] ? inner : nil;
}

+ (NSString *)mt62_fingerPrintFromInner:(NSDictionary *)inner
{
    NSArray<NSString *> *keys = @[ @"finger_print_of_protocal", @"finger_print", @"fp", @"fingerPrint" ];
    for (NSString *k in keys) {
        id v = inner[k];
        if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) {
            return (NSString *)v;
        }
        if ([v isKindOfClass:[NSNumber class]]) {
            NSString *s = [(NSNumber *)v stringValue];
            if (s.length > 0) {
                return s;
            }
        }
    }
    return @"";
}

+ (int)mt62_alarmTypeFromChatType:(int)chatType
{
    if (chatType == CHAT_TYPE_GUEST_CHAT) {
        return AMT_guestChatMessage;
    }
    if (chatType == CHAT_TYPE_GROUP_CHAT) {
        return AMT_groupChatMessage;
    }
    return AMT_friendChatMessage;
}

/// 服务端对同一撤回连发 `revoke_message` + `message_revoke`：短时内同 partner+fp 只处理一次，避免双次 UI 刷新。
+ (BOOL)mt62_shouldDedupDoubleRevokeAction:(NSString *)partnerId fpCmd:(NSString *)fpCmd
{
    if (partnerId.length == 0 || fpCmd.length == 0) {
        return NO;
    }
    static NSString *lastKey;
    static CFAbsoluteTime lastAt;
    NSString *k = [NSString stringWithFormat:@"%@|%@", partnerId, fpCmd];
    @synchronized([ChatMessageEventImpl class]) {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (lastKey != nil && [lastKey isEqualToString:k] && (now - lastAt) < 2.5) {
            return YES;
        }
        lastKey = k;
        lastAt = now;
    }
    return NO;
}

/**
 * 【MT62】多端状态同步（服务端 IM）。
 * action：`read_receipt`、`delete_single`、`delete_conversation`、`clear_all` 等；`data` 常为 JSON 字符串需二次解析。
 */
+ (void)handleMT62StateSyncFromServer:(NSString *)dataContent
{
    NSLog(@"【MT62-状态同步】收到状态同步指令: %@", dataContent);

    @try {
        NSData *topBytes = [dataContent dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *root = [NSJSONSerialization JSONObjectWithData:topBytes options:0 error:nil];
        if (![root isKindOfClass:[NSDictionary class]]) {
            DDLogDebug(@"【MT62】顶层 JSON 解析失败");
            return;
        }
        NSString *action = [[root[@"action"] description] lowercaseString];
        NSDictionary *inner = [ChatMessageEventImpl mt62_parseInnerPayloadFromRoot:root];
        if (inner == nil && [action isEqualToString:@"delete_single"]) {
            id dataField = root[@"data"];
            NSString *fpOnly = nil;
            if ([dataField isKindOfClass:[NSString class]]) {
                fpOnly = (NSString *)dataField;
            } else if ([dataField isKindOfClass:[NSNumber class]]) {
                fpOnly = [(NSNumber *)dataField stringValue];
            }
            if (fpOnly.length > 0) {
                NSMutableDictionary *compat = [NSMutableDictionary dictionary];
                compat[@"fp"] = fpOnly;
                compat[@"finger_print_of_protocal"] = fpOnly;
                id partnerId = root[@"partner_id"] ?: root[@"chat_partner_id"] ?: root[@"to_id"] ?: root[@"gid"];
                if (partnerId != nil && partnerId != [NSNull null]) {
                    compat[@"partner_id"] = [partnerId description];
                }
                id chatType = root[@"chat_type"];
                if (chatType != nil && chatType != [NSNull null]) {
                    compat[@"chat_type"] = chatType;
                }
                inner = [compat copy];
                DDLogInfo(@"【MT62】delete_single 使用裸 fp payload 兼容解析 fp=%@", fpOnly);
            }
        }
        if (inner == nil) {
            DDLogDebug(@"【MT62】内层 data 解析失败");
            return;
        }
        if (action.length == 0 && inner[@"last_read_time2"] != nil) {
            action = @"read_receipt";
        }

        if ([action isEqualToString:@"read_receipt"]) {
            NSString *partnerId = [inner[@"partner_id"] description];
            if (partnerId.length == 0 || [partnerId isEqualToString:@"(null)"]) {
                DDLogDebug(@"【MT62】read_receipt 缺少 partner_id");
                return;
            }
            int chatType = [inner[@"chat_type"] intValue];
            id lrObj = inner[@"last_read_time2"];
            NSString *lastReadTime2 = @"0";
            if ([lrObj isKindOfClass:[NSString class]]) {
                lastReadTime2 = (NSString *)lrObj;
            } else if ([lrObj isKindOfClass:[NSNumber class]]) {
                lastReadTime2 = [(NSNumber *)lrObj stringValue];
            }
            NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid ?: @"";
            NSDictionary *readInfo = @{
                @"reader_uid": partnerId,
                @"chat_partner_id": myUid,
                @"chat_type": @(chatType),
                @"last_read_time2": lastReadTime2
            };
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"kNotificationReadReceiptUpdated"
                                                                    object:nil
                                                                  userInfo:readInfo];
            });
            return;
        }

        if ([action isEqualToString:@"delete_single"]) {
            NSString *partnerId = [inner[@"partner_id"] description];
            NSString *fp = [ChatMessageEventImpl mt62_fingerPrintFromInner:inner];
            int chatType = [inner[@"chat_type"] intValue];
            if (partnerId.length == 0 || fp.length == 0) {
                DDLogDebug(@"【MT62】delete_single 缺少 partner_id 或 fp");
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (chatType == CHAT_TYPE_GROUP_CHAT) {
                    [[[IMClientManager sharedInstance] getGroupsMessagesProvider] removeMessage:partnerId fp:fp isDeleteLocalDatas:YES];
                } else {
                    [[[IMClientManager sharedInstance] getMessagesProvider] removeMessage:partnerId fp:fp isDeleteLocalDatas:YES];
                }
            });
            return;
        }

        if ([action isEqualToString:@"delete_conversation"]) {
            NSString *partnerId = [inner[@"partner_id"] description];
            int chatType = [inner[@"chat_type"] intValue];
            if (partnerId.length == 0) {
                DDLogDebug(@"【MT62】delete_conversation 缺少 partner_id");
                return;
            }
            int alarmType = [ChatMessageEventImpl mt62_alarmTypeFromChatType:chatType];
            dispatch_async(dispatch_get_main_queue(), ^{
                [AlarmsProvider clearHistoryMessages:alarmType dataId:partnerId deleteLocaleDatas:YES db:nil notify:YES];
            });
            return;
        }

        if ([action isEqualToString:@"clear_all"]) {
            long long clearTs = 0;
            NSArray *keys = @[ @"clear_time2", @"clear_time", @"clear_time_ms" ];
            for (NSString *k in keys) {
                id t = inner[k];
                if ([t isKindOfClass:[NSNumber class]]) {
                    clearTs = [(NSNumber *)t longLongValue];
                    if (clearTs != 0) {
                        break;
                    }
                } else if ([t isKindOfClass:[NSString class]]) {
                    clearTs = [(NSString *)t longLongValue];
                    if (clearTs != 0) {
                        break;
                    }
                }
            }
            if (clearTs > 0) {
                [UserDefaultsToolKits setClearAllMessagesTimestamp:clearTs];
            }
            DDLogDebug(@"【MT62】clear_all 已处理（clear_time2=%lld）", clearTs);
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"kNotificationMT62ClearAllMessagesFromServer"
                                                                    object:nil
                                                                  userInfo:(clearTs > 0 ? @{ @"clear_time2": @(clearTs) } : nil)];
            });
            return;
        }

        if ([action isEqualToString:@"revoke_message"] || [action isEqualToString:@"message_revoke"]) {
            NSString *partnerId = [inner[@"partner_id"] description];
            if ([partnerId isEqualToString:@"(null)"]) {
                partnerId = @"";
            }
            int chatType = [inner[@"chat_type"] intValue];
            NSString *fpCmd = [ChatMessageEventImpl mt62_fingerPrintFromInner:root];
            if (fpCmd.length == 0) {
                fpCmd = [ChatMessageEventImpl mt62_fingerPrintFromInner:inner];
            }
            if ([ChatMessageEventImpl mt62_shouldDedupDoubleRevokeAction:partnerId fpCmd:fpCmd]) {
                DDLogVerbose(@"【MT62】revoke 双 action 幂等跳过 partner=%@ fp=%@", partnerId, fpCmd);
                return;
            }
            NSString *metaJSON = nil;
            id rm = inner[@"revoked_meta"] ?: inner[@"revoke_meta"] ?: inner[@"message_content"] ?: inner[@"meta"];
            if ([rm isKindOfClass:[NSString class]]) {
                metaJSON = (NSString *)rm;
            } else if ([rm isKindOfClass:[NSDictionary class]]) {
                NSData *d = [NSJSONSerialization dataWithJSONObject:rm options:0 error:nil];
                if (d != nil) {
                    metaJSON = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                }
            }
            if (partnerId.length == 0 || metaJSON.length == 0) {
                DDLogDebug(@"【MT62】revoke_message 缺少 partner_id 或可解析的 revoked_meta");
                return;
            }
            NSString *cmdFp = fpCmd.length ? fpCmd : @"mt62_revoke";
            dispatch_async(dispatch_get_main_queue(), ^{
                [MessageRevokingManager processRevokeMessage_incoming:chatType fpForRevokeCMD:cmdFp fromId:partnerId messageContent:metaJSON];
            });
            return;
        }

        DDLogDebug(@"【MT62】未实现的 action=%@，payload=%@", action.length ? action : @"(空)", dataContent);
    } @catch (NSException *e) {
        NSLog(@"【MT62】处理异常: %@", e);
    }
}

+ (void)handleReadReceiptNotify:(NSString *)dataContent
{
    NSLog(@"【MT61-已读回执】收到已读回执通知: %@", dataContent);
    
    @try {
        NSData *jsonData = [dataContent dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *data = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        
        if (![data isKindOfClass:[NSDictionary class]]) {
            NSLog(@"【MT61-已读回执】⚠️ 数据解析失败");
            return;
        }
        
        NSString *readerUid = data[@"reader_uid"] ?: @"";
        NSString *chatPartnerId = data[@"chat_partner_id"] ?: @"";
        NSString *lastReadTime2 = data[@"last_read_time2"] ?: @"";
        int chatType = [data[@"chat_type"] intValue];
        
        NSLog(@"【MT61-已读回执】%@ 已读到 time=%@, chatType=%d", readerUid, lastReadTime2, chatType);
        
        // 通知 UI 层更新消息的已读状态（双勾变蓝）
        NSDictionary *readInfo = @{
            @"reader_uid": readerUid,
            @"chat_partner_id": chatPartnerId,
            @"chat_type": @(chatType),
            @"last_read_time2": lastReadTime2
        };
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"kNotificationReadReceiptUpdated"
                                                                object:nil
                                                              userInfo:readInfo];
        });
    } @catch (NSException *e) {
        NSLog(@"【MT61-已读回执】处理异常: %@", e);
    }
}

/**
 * 【MT63】消息已送达回执。
 *
 * 消息被对方设备接收（QoS ACK 确认后）或被服务端成功存为离线消息时触发。
 * dataContent 格式：
 *   {"fp":"ABC123-DEF456","receiver_uid":"400069","delivered_time":"1770787500000"}
 */
+ (void)handleDeliveryReceipt:(NSString *)dataContent
{
    NSLog(@"【MT63-送达回执】收到消息送达回执: %@", dataContent);
    
    @try {
        NSData *jsonData = [dataContent dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *data = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        
        if (![data isKindOfClass:[NSDictionary class]]) {
            NSLog(@"【MT63-送达回执】⚠️ 数据解析失败");
            return;
        }
        
        NSString *fp = data[@"fp"] ?: @"";
        NSString *receiverUid = data[@"receiver_uid"] ?: @"";
        NSString *deliveredTime = data[@"delivered_time"] ?: @"";
        
        NSLog(@"【MT63-送达回执】消息 fp=%@ 已送达 receiver=%@, time=%@", fp, receiverUid, deliveredTime);
        
        // 通知 UI 更新消息的送达状态（单勾 ✓）
        NSDictionary *deliveryInfo = @{
            @"fp": fp,
            @"receiver_uid": receiverUid,
            @"delivered_time": deliveredTime
        };
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // MT63：服务端送达回执；此前仅发通知无监听者，QoS 若未走 ghost 时气泡会一直转圈
            MessagesProvider *mp = [[IMClientManager sharedInstance] getMessagesProvider];
            BOOL ok = [mp markOutgoingMessageDeliveredForFp:fp preferredPeerUid:receiverUid];
            if (!ok) {
                GroupsMessagesProvider *gmp = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
                (void)[gmp markOutgoingMessageDeliveredForFp:fp preferredPeerUid:receiverUid];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:@"kNotificationDeliveryReceiptUpdated"
                                                                object:nil
                                                              userInfo:deliveryInfo];
        });
    } @catch (NSException *e) {
        NSLog(@"【MT63-送达回执】处理异常: %@", e);
    }
}


@end
