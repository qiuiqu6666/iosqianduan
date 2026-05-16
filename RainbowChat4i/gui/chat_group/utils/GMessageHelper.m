//telegram @wz662
#import "GMessageHelper.h"
#import "UserEntity.h"
#import "IMClientManager.h"
#import "SendDataHelper.h"
#import "EVAToolKits.h"
#import "AppDelegate.h"
#import "GChatDataHelper.h"
#import "AlarmsProvider.h"
#import "SendRetryManager.h"

static inline double RBGMessageHelperTraceNowMs(void)
{
    return CFAbsoluteTimeGetCurrent() * 1000.0;
}

@implementation GMessageHelper


//-------------------------------------------------------------------------------
#pragma mark - （1）收到的消息/协议解析方法

// 解析群聊聊天消息：由服务端转发给接收人B的【步骤2/2】.
// 当然，此消息被接收到的前提条件是B用户此时是在线的（否则临时聊天消息将服务端被存储到DB中（直到本地用户下次上线））。
+ (MsgBody4Group *)parseGroupChatMsg_SERVER_TO_B_Message:(NSString *)originalMsg
{
    DDLogDebug(@"!!!!!!收到服务端发过来的群聊聊天信息：%@" , originalMsg);
    return [EVAToolKits fromJSON:originalMsg withClazz:MsgBody4Group.class];
}

// 解析群聊系统指令：“我”加群成功后通知“我”（即被加群者）（由Server发出），通知接收人可能是在创建群或群建好后邀请进入的.
+ (CMDBody4MyselfBeInvitedGroupResponse *) parseResponse4GroupSysCMD4MyselfBeInvited:(NSString *)originalMsg
{
    DDLogDebug(@"!!!!!!收到服务端发过来的群聊指令be_invited：%@" , originalMsg);
    return [EVAToolKits fromJSON:originalMsg withClazz:CMDBody4MyselfBeInvitedGroupResponse.class];
}

// 解析群聊系统指令：群聊时，向所有(除修改者)的群员通知群名被修改的通知协议内容（由Server发出），通知接收人可能是在创建群或群建好后邀请进入的.
+ (CMDBody4GroupNameChangedNotification *) parseResponse4GroupSysCMD4GroupNameChanged:(NSString *)originalMsg
{
    DDLogDebug(@"!!!!!!收到服务端发过来的群聊指令gname_changed：%@", originalMsg);
    return [EVAToolKits fromJSON:originalMsg withClazz:CMDBody4GroupNameChangedNotification.class];
}


//-------------------------------------------------------------------------------
#pragma mark - （2）发出的消息或指令(异步)的方法

// * 将指定的纯文消息发送给聊天中的好友
// * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void) sendPlainTextMessageAsync:(NSString *)toGid
                       withMessage:(NSString *)message
                                at:(NSArray<NSString *> *)atUsers
                             quote:(QuoteMeta *)quoteMeta
                         forSucess:(ObserverCompletion)sucessObsExtra
{
    NSString *fingerPring = [Protocal genFingerPrint];
    DDLogInfo(@"[SendTrace][GroupHelperStart] t=%.3f fp=%@ toId=%@ len=%lu atCount=%lu",
              RBGMessageHelperTraceNowMs(),
              fingerPring ?: @"-",
              toGid ?: @"-",
              (unsigned long)message.length,
              (unsigned long)atUsers.count);
    JSQMessage *m = [JSQMessage createChatMsgEntity_OUTGO_TEXT:message withFingerPrint:fingerPring];
    [m setQuoteMeta:quoteMeta];
    // 乐观更新：先插入气泡再发网络
    [GChatDataHelper addChatMessageData_outgoing:toGid withData:m];
    DDLogInfo(@"[SendTrace][GroupHelperLocalInsertDone] t=%.3f fp=%@ toId=%@",
              RBGMessageHelperTraceNowMs(),
              fingerPring ?: @"-",
              toGid ?: @"-");

    // 立即更新会话列表预览和排序（避免等 ACK 才刷新，导致返回列表时排序不对）
    NSString *preview = [JSQMessage parseMessageContentPreview:message withType:TM_TYPE_TEXT];
    [AlarmsProvider addAGroupChatMsgAlarmForLocal:TM_TYPE_TEXT gid:toGid gname:nil msg:preview];

    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        DDLogInfo(@"[SendTrace][GroupHelperNetworkCallback] t=%.3f fp=%@ code=%d",
                  RBGMessageHelperTraceNowMs(),
                  fingerPring ?: @"-",
                  [arg1 intValue]);
        if (sucessObsExtra != nil) sucessObsExtra(observerble, arg1);
    };
    DDLogInfo(@"[SendTrace][GroupHelperSendAsyncInvoke] t=%.3f fp=%@ toId=%@",
              RBGMessageHelperTraceNowMs(),
              fingerPring ?: @"-",
              toGid ?: @"-");
    [GMessageHelper sendMessageAsync:TM_TYPE_TEXT gid:toGid withMessage:message at:atUsers finger:fingerPring quote:quoteMeta forSucess:sendSucessObs];
}

// * 将指导定的图片消息发送给指定群组（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
  + (void) sendImageMessageAsync:(NSString *)toGid
                       withImage:(NSString *)imageFileName
                              fp:(NSString *)fingerPring
                       forSucess:(ObserverCompletion)sucessObsExtra
{
    // 消息指令通过网络发送成功后要通知的观察者
    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        // 发送图片消息成功后什么也不用做（其它在本异步线程执行前图片消息就已经放入到聊天列表了，这是与普通消息最大的区别哦）
        // do nothing
        
        // 消息发送调用者的额外要做的事
        if(sucessObsExtra !=  nil)
            sucessObsExtra(observerble, arg1);
    };
    
    // 调用真正的消息指令发送方法
    [GMessageHelper sendMessageAsync:TM_TYPE_IMAGE gid:toGid withMessage:imageFileName at:nil finger:fingerPring forSucess:sendSucessObs];
}

// * 将指导定的语音消息发送给指定群组（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void) sendVoiceMessageAsync:(NSString *)toGid
                     withVoice:(NSString *)voiceFileName
                            fp:(NSString *)fingerPring
                     forSucess:(ObserverCompletion)sucessObsExtra
{
    // 消息指令通过网络发送成功后要通知的观察者
    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        // 发送语音消息成功后什么也不用做（其它在本异步线程执行前语音消息就已经放入到聊天列表了，这是与普通消息最大的区别哦）
        // do nothing
        
        // 消息发送调用者的额外要做的事
        if(sucessObsExtra !=  nil)
            sucessObsExtra(observerble, arg1);
    };
    
    // 调用真正的消息指令发送方法
    [GMessageHelper sendMessageAsync:TM_TYPE_VOICE gid:toGid withMessage:voiceFileName at:nil finger:fingerPring forSucess:sendSucessObs];
}

// 将指定的文件消息发送给群（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendFileMessageAsync:(NSString *)toGid withMeta:(FileMeta *)fileMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra
{
    // 消息指令通过网络发送成功后要通知的观察者
    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        // 发送文件消息成功后什么也不用做（其它在本异步线程执行前语音消息就已经放入到聊天列表了，这是与普通消息最大的区别哦）
        // do nothing
        
        // 消息发送调用者的额外要做的事
        if(sucessObsExtra !=  nil)
            sucessObsExtra(observerble, arg1);
    };
    
    // 调用真正的消息指令发送方法
    [GMessageHelper sendMessageAsync:TM_TYPE_FILE gid:toGid withMessage:[EVAToolKits toJSON:fileMeta] at:nil finger:fingerPring forSucess:sendSucessObs];
}

// 将指定的短视频消息发送给群（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendShortVideoMessageAsync:(NSString *)toGid withMeta:(FileMeta *)fileMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra
{
    // 消息指令通过网络发送成功后要通知的观察者
    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        // 发送文件消息成功后什么也不用做（其它在本异步线程执行前语音消息就已经放入到聊天列表了，这是与普通消息最大的区别哦）
        // do nothing
        
        // 消息发送调用者的额外要做的事
        if(sucessObsExtra !=  nil)
            sucessObsExtra(observerble, arg1);
    };
    
    // 调用真正的消息指令发送方法
    [GMessageHelper sendMessageAsync:TM_TYPE_SHORTVIDEO gid:toGid withMessage:[EVAToolKits toJSON:fileMeta] at:nil finger:fingerPring forSucess:sendSucessObs];
}

// 将指定的名片消息发送给群（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendContactMessageAsync:(NSString *)toGid withMeta:(ContactMeta *)contactMeta forSucess:(ObserverCompletion)sucessObsExtra
{
    // 先生成指纹码
    NSString *fingerPring = [Protocal genFingerPrint];
    NSString *rawContent = [EVAToolKits toJSON:contactMeta];
    [AlarmsProvider addAGroupChatMsgAlarmForLocal:TM_TYPE_CONTACT gid:toGid gname:nil msg:(rawContent ?: @"")];
    
    // 消息指令通过网络发送成功后要通知的观察者
    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        // 消息发送成功后，将此消息数据放到聊天列表的数据模型中（让UI进行显示）
        [GChatDataHelper addChatMessageData_outgoing:toGid withData:[JSQMessage createChatMsgEntity_OUTGO_CONTACT:contactMeta withFingerPrint:fingerPring]];
        
        // 消息发送调用者的额外要做的事
        if(sucessObsExtra !=  nil)
            sucessObsExtra(observerble, arg1);
    };
    
    // 调用真正的消息指令发送方法
    [GMessageHelper sendMessageAsync:TM_TYPE_CONTACT gid:toGid withMessage:[EVAToolKits toJSON:contactMeta] at:nil finger:fingerPring forSucess:sendSucessObs];
}

// 将指定的位置消息发送给群（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendLocationMessageAsync:(NSString *)toGid withMeta:(LocationMeta *)locationMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra
{
    //##Bug FIX：特别注意：请确保消息在生成JSQMessage对象时使用的fingerPrint跟此处要发出的fingerPrint是一样的，否则将导致消息撤回功能失效哦！
    
    // 消息指令通过网络发送成功后要通知的观察者
    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        
        // 发送位置消息成功后什么也不用做（其它在本异步线程执行前语音消息就已经放入到聊天列表了，这是与普通消息最大的区别哦）
        // do nothing
        
        // 消息发送调用者的额外要做的事
        if(sucessObsExtra !=  nil)
            sucessObsExtra(observerble, arg1);
    };
    
    // 调用真正的消息指令发送方法
    [GMessageHelper sendMessageAsync:TM_TYPE_LOCATION gid:toGid withMessage:[EVAToolKits toJSON:locationMeta] at:nil finger:fingerPring forSucess:sendSucessObs];
}

// "撤回"消息（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendRevokeMessageAsync:(NSString *)fingerPrint gid:(NSString *)toGid withMeta:(RevokedMeta *)content forSucess:(ObserverCompletion)sucessObsExtra
{
    // 消息指令通过网络发送成功后要通知的观察者
    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        
        // 注意：由于消息"撤回"指令需要等对方的应答回来（也就是对方收到撤回指令后）才能做本地的真正"撤回"逻辑，
        //      所以此观察者中无法立即进行"撤回"处理，余下的本地撤回逻辑将由 MessageRevoingManager来实现！
        
        // 消息发送调用者的额外要做的事
        if(sucessObsExtra !=  nil)
            sucessObsExtra(observerble, arg1);
    };

    // 调用真正的消息指令发送方法
    [GMessageHelper sendMessageAsync:TM_TYPE_REVOKE gid:toGid withMessage:[EVAToolKits toJSON:content] at:nil finger:fingerPrint forSucess:sendSucessObs];
}

// * 将指定的消息发送给指定群组（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void) sendMessageAsync:(int)messageType gid:(NSString *)toGid withMessage:(NSString *)message at:(NSArray<NSString *> *)atUsers finger:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObs
{
    [GMessageHelper sendMessageAsync:messageType gid:toGid withMessage:message at:atUsers finger:fingerPring quote:nil forSucess:sucessObs];
}

// * 将指定的消息发送给指定群组（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void) sendMessageAsync:(int)messageType gid:(NSString *)toGid withMessage:(NSString *)message at:(NSArray<NSString *> *)atUsers finger:(NSString *)fingerPring quote:(QuoteMeta *)quoteMeta forSucess:(ObserverCompletion)sucessObs
{
    if (message != nil && [message length] > 0)
    {
        GroupEntity *currentChattingGe = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:toGid];
        // 是普通群聊消息
        if(![GroupEntity isWorldChat:toGid])
        {
            // 出现此种情形的可能发生于：我已被踢出或从群聊中删除，但仍从首页"消息"列表中点击遗留的Alarms进来的！
            if(currentChattingGe == nil)
            {
                [APP showToastWarn:@"您已不在该群组中，无法发送消息哦！"];
                return;
            }
        }
        // 是世界频道
        else {
            currentChattingGe = [GroupsProvider getDefaultWordChatEntity];
        }

        // 网络数据发送放到异步线程里提升体验
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),^{

            MsgBody4Group *body = [self constructGroupChatMsgBodyForSend:fingerPring msgType:messageType gid:toGid msg:message at:atUsers];
            // 尝试设置消息引用信息
            [body setQuoteMeta:quoteMeta];
            int code = [GMessageHelper sendBBSChatMsg_A_TO_SERVER_Message:body qos:YES fp:fingerPring];
//          int code = [GMessageHelper sendChatMessage:messageType gid:toGid msg:message fp:fingerPring];

            dispatch_async(dispatch_get_main_queue(), ^{
                if(code == COMMON_CODE_OK)
                {
                    // 接口已成功：仅启动 60 秒超时，未收到 ack 则标失败（不重发避免重复）
                    [[SendRetryManager sharedInstance] startGiveUpTimerOnlyForGroupFp:fingerPring gid:toGid];
                    if(sucessObs != nil)
                        sucessObs(nil, @(COMMON_CODE_OK));
                    {
                        [AlarmsProvider addAGroupChatMsgAlarmForLocal:messageType gid:toGid gname:currentChattingGe.g_name msg:message];
                    }
                }
                else
                {
                    // 发送失败：1s/2s/4s/8s/15s/30s 密集重试 + 60s 放弃，网络恢复一瞬间就能发出
                    [[SendRetryManager sharedInstance] startRetryForGroupFp:fingerPring gid:toGid text:message atUsers:atUsers quoteMeta:quoteMeta];
                    if(sucessObs != nil)
                        sucessObs(nil, @(COMMON_UNKNOW_ERROR));
                    DDLogError(@"%@", [NSString stringWithFormat:@"网络发送数据失败，错误信息 code=%d", code]);
                }
            });
        });
    }
}


//------------------------------------------------------------------------
#pragma mark - （3）消息发送同步实现方法

//// 发送聊天消息（包括普通文本、图片消息、语音留言消息等）给指定user_id的用户.
//+ (int) sendChatMessage:(int)msgType gid:(NSString *)toGid msg:(NSString *)msg fp:(NSString *)fingerPrint
//{
//    return [GMessageHelper sendBBSChatMsg_A_TO_SERVER_Message:msgType gid:toGid msg:msg qos:YES fp:fingerPrint];;
//}

//// 发送临时聊天消息：由发送人A发给服务端【步骤1/2】.
//+ (int) sendBBSChatMsg_A_TO_SERVER_Message:(int)msgType
//                                       gid:(NSString *)toGid
//                                       msg:(NSString *)msg
//                                       qos:(BOOL)QoS
//                                        fp:(NSString *)fingerPrint
//{
//    // 发送消息时，user_id=0即表示发送给服务端
//    MsgBody4Group *body = [self constructGroupChatMsgBodyForSend:fingerPrint msgType:msgType gid:toGid msg:msg];
//    return [GMessageHelper sendBBSChatMsg_A_TO_SERVER_Message:body qos:QoS fp:fingerPrint];
//}

// 发送临时聊天消息：由发送人A发给服务端【步骤1/2】.
+ (int) sendBBSChatMsg_A_TO_SERVER_Message:(MsgBody4Group *)tcmd qos:(BOOL)QoS fp:(NSString *)fingerPrint
{
    // 发送消息（群聊/世界频道消息是通过服务端再扩散发送出去的）
    return [GMessageHelper sendMessage:[EVAToolKits toJSON:tcmd] qos:QoS fp:fingerPrint typeu:MT44_OF_GROUP_CHAT_MSG_A_TO_SERVER];
}

// 发送消息给指定user_id的用户.
+ (int) sendMessage:(NSString *)message qos:(BOOL)QoS fp:(NSString *)fingerPrint typeu:(int)typeu
{
    // 群聊消息是通过服务端发送出去的，所以此处的目标接收用户id="0"(MobileIMSDK框架中将"0"保留作为服务器)
    return [SendDataHelper sendMessageImpl:@"0" withMessage:message qos:QoS finger:fingerPrint andTypeu:typeu];
}


//------------------------------------------------------------------------
#pragma mark - （4）其它方法

// 构造临时聊天DTO对象.
+ (MsgBody4Group *) constructGroupChatMsgBodyForSend:(NSString *)parentFp msgType:(int)msgType gid:(NSString *)toGid msg:(NSString *)msg at:(NSArray<NSString *> *)atUsers
{
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    NSString *displayName = [GroupsProvider getMyNickNameInGroupEx:toGid];
    if ([BasicTool isStringEmpty:displayName]) {
        displayName = localUserInfo.nickname;
    }
    return [MsgBody4Group constructGroupChatMsgBody:msgType srcUserUid:localUserInfo.user_uid srcNickName:displayName toGid:toGid msg:msg parentFp:parentFp at:atUsers];
}

@end
