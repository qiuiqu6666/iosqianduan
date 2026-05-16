//telegram @wz662
#import "TChatDataHelper.h"
#import "IMClientManager.h"
#import "ChatDataHelper.h"
#import "TimeTool.h"
#import "LocalPushHelper.h"
#import "UserDefaultsToolKits.h"
#import "MessageRevokingManager.h"
#import "AlarmType.h"
#import "AlarmsProvider.h"
#import "AlarmUnreadDebugTrace.h"

@implementation TChatDataHelper


// **************************************************************************** 以下方法仅为本收到的消息所准备 START
/**
 * 添加一条临时聊天消息到临时聊天数据结构中.
 */
+ (void) addChatMessageData_incoming:(NSString *)fingerPrint
                             msgBody:(MsgBody4Guest *)tcmd
                                date:(NSDate *)time
                          showNotify:(BOOL)showNotification
                           playAudio:(BOOL)playPromtAudio
                            andQuote:(QuoteMeta *)quoteMeta
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [TChatDataHelper addChatMessageData_incoming:fingerPrint msgBody:tcmd date:time showNotify:showNotification playAudio:playPromtAudio andQuote:quoteMeta];
        });
        return;
    }

    int msgType = tcmd.ty;
    // 如果收到的消息"撤回指令"，则需要单独特殊处理（因为"撤回"指令不是普通的聊天消息哦）
    if(msgType == TM_TYPE_REVOKE){
        DDLogInfo(@"【这是消息撤回指令，马上处理撤回逻辑】 ==> msgType=%d，fingerPrint = %@，messageContent=%@", msgType, fingerPrint, tcmd.m);
        
        // 开始处理撤回指令完整逻辑
        [MessageRevokingManager processRevokeMessage_incoming:CHAT_TYPE_GUEST_CHAT fpForRevokeCMD:fingerPrint fromId:tcmd.f messageContent:tcmd.m];
        
        
        // 消息内容的显示（比如图片消息会显示"[图片]"这样的字串）
        NSString *messageContentForShow = [JSQMessage parseMessageContentPreview:tcmd.m withType:tcmd.ty];
        // 更新首页消息列表中的显示
//        [[[IMClientManager sharedInstance] getAlarmsProvider] addATempChatMsgAlarm:tcmd.ty friendUid:tcmd.f friendName:tcmd.nickName
//                                                                           withMsg:tcmd.m withDate:time flagNumToAdd:0];
        [[[IMClientManager sharedInstance] getAlarmsProvider] addSingleChatMessageAlarm:tcmd.f friendName:tcmd.nickName withConcentForShow:messageContentForShow flagNumToAdd:0 withDate:time withAlarmType:AMT_guestChatMessage fingerPrint:fingerPrint];
        return;
    }

    //----------------------------------------------------------------- 加入数据结构中
    BOOL priorFpExisted = NO;
    if (fingerPrint.length > 0) {
        priorFpExisted = ([[[IMClientManager sharedInstance] getMessagesProvider] findMessageByFingerPrint:tcmd.f fp:fingerPrint] != nil);
    }
    JSQMessage *cme = [JSQMessage prepareChatMessageData_incoming:tcmd.m
                            // 消息发送人的昵称
                              withNickName:tcmd.nickName
                                   andTime:time == nil?[TimeTool getIOSDefaultDate]:time
                                andMsgType:tcmd.ty
                                  senderId:tcmd.f];
    if(cme != nil){
        // 消息的指纹码（也就是唯一ID啦）
        cme.fingerPrintOfProtocal = fingerPrint;
        // 尝试设置引用的消息信息（quoteMeta为null则表示无引用消息则）
        [cme setQuoteMeta:quoteMeta];
        // 将消息放入数据结构
        [[[IMClientManager sharedInstance] getMessagesProvider] putMessage:tcmd.f withData:cme];
    }
    AlarmsProvider *alarmsProvider = [[IMClientManager sharedInstance] getAlarmsProvider];
    BOOL archivedConversation = [alarmsProvider isArchived:AMT_guestChatMessage dataId:tcmd.f];

    //----------------------------------------------------------------- 声音提示
    if(!archivedConversation && playPromtAudio && [UserDefaultsToolKits isChatMsgToneOpen:tcmd.f])
    {
        // 来一个声音提示
        [JSQSystemSoundPlayer jsq_playMessageReceivedSound];
    }

    //----------------------------------------------------------------- 首页消息和系统Notification提示
    int flagNumToAdd = 0;
    // 当前临时聊天的界面处于后台时的消息提示
    if(([IMClientManager sharedInstance].currentFrontTempChattingUserUID == nil
           || ![[IMClientManager sharedInstance].currentFrontTempChattingUserUID isEqualToString:tcmd.f]))
    {
        flagNumToAdd += 1;

        if(!archivedConversation && showNotification && [UserDefaultsToolKits isChatMsgToneOpen:tcmd.f])
        {
            // 来一个本地Push通知哦（携带 uid 以支持点击通知跳转）
            [LocalPushHelper showATempChatMsgPush:tcmd.ty msg:tcmd.m fromUid:tcmd.f fromNickName:tcmd.nickName];
        }
    }
    
    // 消息内容的显示（比如图片消息会显示"[图片]"这样的字串）
    NSString *messageContentForShow = [JSQMessage parseMessageContentPreview:tcmd.m withType:tcmd.ty];
    if ([AlarmUnreadDebugTrace isTargetUid:tcmd.f]) {
        NSString *front = [IMClientManager sharedInstance].currentFrontTempChattingUserUID ?: @"(nil)";
        [AlarmUnreadDebugTrace appendLine:[NSString stringWithFormat:@"陌生人入站 reqUnread=%d frontTempUid=%@ fp=%@", flagNumToAdd, front, fingerPrint.length ? fingerPrint : @"-"]
                                   source:@"TChatDataHelper"
                                   forUid:tcmd.f];
    }
    // 无条件加一个提示到首页消息列表中（就像主流IM微信一样，可以很方便的找到最近聊天的人）
//    [[[IMClientManager sharedInstance] getAlarmsProvider] addATempChatMsgAlarm:tcmd.ty friendUid:tcmd.f friendName:tcmd.nickName
//                                                                       withMsg:tcmd.m withDate:time flagNumToAdd:flagNumToAdd];// 未读临时消息数+1
    [[[IMClientManager sharedInstance] getAlarmsProvider] addSingleChatMessageAlarm:tcmd.f friendName:tcmd.nickName withConcentForShow:messageContentForShow flagNumToAdd:flagNumToAdd withDate:time withAlarmType:AMT_guestChatMessage withNotify:YES fingerPrint:fingerPrint priorFingerPrintExistedInMemory:priorFpExisted];// 未读临时消息数+1
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
