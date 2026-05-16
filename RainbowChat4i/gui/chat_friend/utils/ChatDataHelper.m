//telegram @wz662
#import "ChatDataHelper.h"
#import "IMClientManager.h"
#import "MessageHelper.h"
#import "CompletionDefine.h"
#import "AppDelegate.h"
#import "Protocal.h"
#import "ErrorCode.h"
#import "ClientCoreSDK.h"
#import "AlarmsProvider.h"
#import "IMClientManager.h"
#import "UserDefaultsToolKits.h"
#import "LocalPushHelper.h"
#import "EVAToolKits.h"
#import "FileMeta.h"
#import "MessageRevokingManager.h"
#import "JSQMessage.h"
#import "UserDefaultsToolKits.h"
#import "MessageRevokingManager.h"
#import "AlarmType.h"
#import "AlarmUnreadDebugTrace.h"

@implementation ChatDataHelper

// 添加一条通用群聊系统通知到聊天数据结构中
+ (void)addSystemInfoData:(UserEntity *)ree
              infoContent:(NSString *)systemInfo
                     date:(NSDate *)time
                playAudio:(BOOL)playPromtAudio
               showNotify:(BOOL)showNotification
{
    // 将该条系统通知加入到聊天消息中
    MsgBody4Friend *msgBody = [MsgBody4Friend constructFriendSystemMsgBody:ree.user_uid t:[[ClientCoreSDK sharedInstance] currentLoginUserId] m:systemInfo];
    [ChatDataHelper addChatMessageData_incoming:nil msgContent:msgBody.m withTime:time playAudio:playPromtAudio showNotify:showNotification msgType:msgBody.ty withRee:ree andQuote:nil];
}

+ (void)addSystemInfoData:(UserEntity *)ree
              infoContent:(NSString *)systemInfo
              fingerPrint:(NSString *)fingerPrint
                     date:(NSDate *)time
                playAudio:(BOOL)playPromtAudio
               showNotify:(BOOL)showNotification
{
    MsgBody4Friend *msgBody = [MsgBody4Friend constructFriendSystemMsgBody:ree.user_uid t:[[ClientCoreSDK sharedInstance] currentLoginUserId] m:systemInfo];
    [ChatDataHelper addChatMessageData_incoming:fingerPrint msgContent:msgBody.m withTime:time playAudio:playPromtAudio showNotify:showNotification msgType:msgBody.ty withRee:ree andQuote:nil];
}


// **************************************************************************** 以下方法仅为本收到的消息所准备 START
+ (void)addChatMessageData_incoming:(NSString *)fingerPrint
                         msgContent:(NSString *)messageContent
                           withTime:(NSDate *)time
                          playAudio:(BOOL)playPromtAudio
                         showNotify:(BOOL)showNotification
                            msgType:(int)msgType
                            withRee:(UserEntity *)ree
                           andQuote:(QuoteMeta *)quoteMeta
{
    [ChatDataHelper addChatMessageData_incoming:fingerPrint msgContent:messageContent withTime:time playAudio:playPromtAudio showNotify:showNotification msgType:msgType withRee:ree andQuote:quoteMeta suppressUnreadBump:NO];
}

+ (void)addChatMessageData_incoming:(NSString *)fingerPrint
                         msgContent:(NSString *)messageContent
                           withTime:(NSDate *)time
                          playAudio:(BOOL)playPromtAudio
                         showNotify:(BOOL)showNotification
                            msgType:(int)msgType
                            withRee:(UserEntity *)ree
                           andQuote:(QuoteMeta *)quoteMeta
             suppressUnreadBump:(BOOL)suppressUnreadBump
{
    // SyncManager 等在全局队列回调：必须在主线程更新 MessagesProvider / AlarmsProvider，否则与 UI 观察者竞态，表现为实时无角标、杀进程后主线程载入后才正常。
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ChatDataHelper addChatMessageData_incoming:fingerPrint msgContent:messageContent withTime:time playAudio:playPromtAudio showNotify:showNotification msgType:msgType withRee:ree andQuote:quoteMeta suppressUnreadBump:suppressUnreadBump];
        });
        return;
    }

    // 如果收到的消息"撤回指令"，则需要单独特殊处理（因为"撤回"指令不是普通的聊天消息哦）
    if(msgType == TM_TYPE_REVOKE){
        DDLogInfo(@"【这是消息撤回指令，马上处理撤回逻辑】 ==> msgType=%d，fingerPrint = %@，messageContent=%@", msgType, fingerPrint, messageContent);
        
        // 开始处理撤回指令完整逻辑
        [MessageRevokingManager processRevokeMessage_incoming:CHAT_TYPE_FREIDN_CHAT fpForRevokeCMD:fingerPrint fromId:ree.user_uid messageContent:messageContent];
        
        // 消息内容的显示（比如图片消息会显示"[图片]"这样的字串）
        NSString *messageContentForShow = [JSQMessage parseMessageContentPreview:messageContent withType:msgType];
        // 更新首页消息列表中的显示
        [[[IMClientManager sharedInstance] getAlarmsProvider] addSingleChatMessageAlarm:ree.user_uid friendName:[ree getNickNameWithRemark]
                                                               withConcentForShow:messageContentForShow flagNumToAdd:0 withDate:time withAlarmType:AMT_friendChatMessage fingerPrint:fingerPrint];
        return;
    }

    //----------------------------------------------------------------- 加入数据结构中
    BOOL priorFpExisted = NO;
    JSQMessage *cme = nil;
    if(ree != nil)
    {
        if (fingerPrint.length > 0) {
            priorFpExisted = ([[[IMClientManager sharedInstance] getMessagesProvider] findMessageByFingerPrint:ree.user_uid fp:fingerPrint] != nil);
        }
        // 将一条消息放到该好友的消息列表中（放进去时会自动通知列表的观察者，而观察者将会实现ui的刷新）
        cme = [JSQMessage prepareChatMessageData_incoming:messageContent
                                        withNickName:[ree getNickNameWithRemark]
                                             andTime:time
                                          andMsgType:msgType
                                            senderId:ree.user_uid];
        // 消息的指纹码（也就是唯一ID啦）
        cme.fingerPrintOfProtocal = fingerPrint;
        // 尝试设置引用的消息信息（quoteMeta为null则表示无引用消息则）
        [cme setQuoteMeta:quoteMeta];
        // 将收到的消息数据放到聊天消息全局数据模型中
        [[[IMClientManager sharedInstance] getMessagesProvider] putMessage:ree.user_uid withData:cme];
    }
    AlarmsProvider *alarmsProvider = [[IMClientManager sharedInstance] getAlarmsProvider];
    BOOL archivedConversation = [alarmsProvider isArchived:AMT_friendChatMessage dataId:ree.user_uid];

    //----------------------------------------------------------------- 声音提示
    if(!archivedConversation && playPromtAudio && [UserDefaultsToolKits isChatMsgToneOpen:ree.user_uid])
    {
        // 来一个声音提示
        [JSQSystemSoundPlayer jsq_playMessageReceivedSound];
    }

    //----------------------------------------------------------------- 首页消息和系统Notification提示
    int flagNumToAdd = 0;
    // 消息内容的显示（比如图片消息会显示"[图片]"这样的字串）
    NSString *messageContentForShow = [JSQMessage parseMessageContentPreview:messageContent withType:msgType];
    // 当前聊天的界面处于后台时的消息提示 或者 不处于后台但当前聊天的并不是此用户时
    if (!suppressUnreadBump
        && ([IMClientManager sharedInstance].currentFrontChattingUserUID == nil
           || ![[IMClientManager sharedInstance].currentFrontChattingUserUID isEqualToString:ree.user_uid]))
    {
        // 未读 +1 的去重在 AlarmsProvider effectiveFlagNumToAdd + QoS4ReciveDaemon
        flagNumToAdd += 1;

        if(!archivedConversation && showNotification && [UserDefaultsToolKits isChatMsgToneOpen:ree.user_uid])
        {
            // 显示一个本地Push通知（携带 uid 以支持点击通知跳转）
            [LocalPushHelper showRecievedFriendMessagePush:ree.user_uid nickName:[ree getNickNameWithRemark] msg:messageContentForShow];
        }
    }
    if ([AlarmUnreadDebugTrace isTargetUid:ree.user_uid]) {
        NSString *front = [IMClientManager sharedInstance].currentFrontChattingUserUID ?: @"(nil)";
        [AlarmUnreadDebugTrace appendLine:[NSString stringWithFormat:@"入站 reqUnread=%d frontUid=%@ fp=%@", flagNumToAdd, front, fingerPrint.length ? fingerPrint : @"-"]
                                   source:@"ChatDataHelper"
                                   forUid:ree.user_uid];
    }
    // 无条件加一个提示到首页消息列表中（就像主流IM微信一样，可以很方便的找到最近聊天的人）
    [[[IMClientManager sharedInstance] getAlarmsProvider] addSingleChatMessageAlarm:ree.user_uid friendName:[ree getNickNameWithRemark]
                                                           withConcentForShow:messageContentForShow flagNumToAdd:flagNumToAdd withDate:time withAlarmType:AMT_friendChatMessage withNotify:YES fingerPrint:fingerPrint priorFingerPrintExistedInMemory:priorFpExisted];

    //----------------------------------------------------------------- 通知观察者
    // 通知好友列表的好友消息数更新观察者
    ObserverCompletion addMessagesObs = [[[IMClientManager sharedInstance] getTransDataListener] getAddMessagesObserver];
    if(addMessagesObs != nil)
        addMessagesObs(nil, nil);
}

// **************************************************************************** 以下方法仅为本收到的消息所准备 END


// **************************************************************************** 以下方法仅为本发出的消息所准备 START
+ (JSQMessage *)addChatMessageData_outgoing:(NSString *)friendUid withData:(JSQMessage *)entity
{
    // 将一条消息放到该好友的消息列表中（放进去时会自动通知列表的观察者，而观察者将会实现ui的刷新）
    // ，不推荐像上面被注释地代码样直接操作消息列表数据集合，因为通过putMessage(..)方法可以通知观察者
    // 完成ui的刷新等工作，这样能提升编码的质量并统一该项业务的实现
    [[[IMClientManager sharedInstance] getMessagesProvider] putMessage:friendUid withData:entity];
    return entity;
}
// **************************************************************************** 以下方法仅为本发出的消息所准备 END

@end
