//telegram @wz662
#import "TMessageHelper.h"
#import "IMClientManager.h"
#import "EVAToolKits.h"
#import "SendDataHelper.h"
#import "IMClientManager.h"
#import "AppDelegate.h"
#import "AlarmsProvider.h"
#import "TChatDataHelper.h"
#import "AlarmType.h"

static inline double RBTMessageHelperTraceNowMs(void)
{
    return CFAbsoluteTimeGetCurrent() * 1000.0;
}

@implementation TMessageHelper


//-------------------------------------------------------------------------------
#pragma mark - （1）收到的消息/协议解析方法

// 解析临时聊天消息：由服务端转发给接收人B的【步骤2/2】.
+ (MsgBody4Guest *)parseTempChatMsg_SERVER_TO_B_Message:(NSString *)originalMsg
{
    DDLogDebug(@"!!!!!!收到服务端发过来的临时聊天信息：%@" , originalMsg);
    return [EVAToolKits fromJSON:originalMsg withClazz:MsgBody4Guest.class];
}


//-------------------------------------------------------------------------------
#pragma mark - （2）发出的消息或指令(异步)的方法

// 将指导定的图片消息发送给聊天中的陌生人（异步方式）.
+ (void) sendPlainTextMessageAsync:(NSString *)tempChatFriendUID
                            tuname:(NSString *)tempChatFriendName
                       withMessage:(NSString *)message
                             quote:(QuoteMeta *)quoteMeta
                         forSucess:(ObserverCompletion)sucessObsExtra
{
    NSString *fingerPring = [Protocal genFingerPrint];
    DDLogInfo(@"[SendTrace][GuestHelperStart] t=%.3f fp=%@ toId=%@ len=%lu",
              RBTMessageHelperTraceNowMs(),
              fingerPring ?: @"-",
              tempChatFriendUID ?: @"-",
              (unsigned long)message.length);
    JSQMessage *m = [JSQMessage createChatMsgEntity_OUTGO_TEXT:message withFingerPrint:fingerPring];
    [m setQuoteMeta:quoteMeta];
    // 乐观更新：先插入气泡再发网络
    [TChatDataHelper addChatMessageData_outgoing:tempChatFriendUID withData:m];
    DDLogInfo(@"[SendTrace][GuestHelperLocalInsertDone] t=%.3f fp=%@ toId=%@",
              RBTMessageHelperTraceNowMs(),
              fingerPring ?: @"-",
              tempChatFriendUID ?: @"-");

    // 立即更新会话列表预览和排序（避免等 ACK 才刷新，导致返回列表时排序不对）
    NSString *preview = [JSQMessage parseMessageContentPreview:message withType:TM_TYPE_TEXT];
    [AlarmsProvider addSingleChatMsgAlarmForLocal:tempChatFriendUID friendName:tempChatFriendName withMsg:preview andType:TM_TYPE_TEXT withAlarmType:AMT_guestChatMessage];

    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        DDLogInfo(@"[SendTrace][GuestHelperNetworkCallback] t=%.3f fp=%@ code=%d",
                  RBTMessageHelperTraceNowMs(),
                  fingerPring ?: @"-",
                  [arg1 intValue]);
        if (sucessObsExtra != nil) sucessObsExtra(observerble, arg1);
    };
    DDLogInfo(@"[SendTrace][GuestHelperSendAsyncInvoke] t=%.3f fp=%@ toId=%@",
              RBTMessageHelperTraceNowMs(),
              fingerPring ?: @"-",
              tempChatFriendUID ?: @"-");
    [TMessageHelper sendMessageAsync:TM_TYPE_TEXT tuid:tempChatFriendUID tuname:tempChatFriendName withMessage:message fp:fingerPring quote:quoteMeta forSucess:sendSucessObs];
}

// 将指导定的图片消息发送给聊天中的陌生人（异步方式）.
+ (void) sendImageMessageAsync:(NSString *)tempChatFriendUID
                        tuname:(NSString *)tempChatFriendName
                     withImage:(NSString *)imageFilePath
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
    [TMessageHelper sendMessageAsync:TM_TYPE_IMAGE tuid:tempChatFriendUID tuname:tempChatFriendName withMessage:imageFilePath fp:fingerPring forSucess:sendSucessObs];
}

// 将指导定的语音消息发送给聊天中的陌生人（异步方式）.
+ (void) sendVoiceMessageAsync:(NSString *)tempChatFriendUID
                        tuname:(NSString *)tempChatFriendName
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
    [TMessageHelper sendMessageAsync:TM_TYPE_VOICE tuid:tempChatFriendUID tuname:tempChatFriendName withMessage:voiceFileName fp:fingerPring forSucess:sendSucessObs];
}

// 将指定的文件消息发送给聊天中的陌生人（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendFileMessageAsync:(NSString *)tempChatFriendUID tuname:(NSString *)tempChatFriendName withMeta:(FileMeta *)fileMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra
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
    [TMessageHelper sendMessageAsync:TM_TYPE_FILE tuid:tempChatFriendUID tuname:tempChatFriendName withMessage:[EVAToolKits toJSON:fileMeta] fp:fingerPring forSucess:sendSucessObs];
}

// 将指定的短视频消息发送给聊天中的陌生人（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendShortVideoMessageAsync:(NSString *)tempChatFriendUID tuname:(NSString *)tempChatFriendName withMeta:(FileMeta *)fileMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra
{
    // 消息指令通过网络发送成功后要通知的观察者
    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        // 发送短视频消息成功后什么也不用做（其它在本异步线程执行前语音消息就已经放入到聊天列表了，这是与普通消息最大的区别哦）
        // do nothing
        
        // 消息发送调用者的额外要做的事
        if(sucessObsExtra !=  nil)
            sucessObsExtra(observerble, arg1);
    };
    
    // 调用真正的消息指令发送方法
    [TMessageHelper sendMessageAsync:TM_TYPE_SHORTVIDEO tuid:tempChatFriendUID tuname:tempChatFriendName withMessage:[EVAToolKits toJSON:fileMeta] fp:fingerPring forSucess:sendSucessObs];
}

// 将指定的名片消息发送给聊天中的陌生人（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendContactMessageAsync:(NSString *)tempChatFriendUID tuname:(NSString *)tempChatFriendName withMeta:(ContactMeta *)contactMeta forSucess:(ObserverCompletion)sucessObsExtra
{
    // 先生成指纹码
    NSString *fingerPring = [Protocal genFingerPrint];
    NSString *rawContent = [EVAToolKits toJSON:contactMeta];
    [AlarmsProvider addSingleChatMsgAlarmForLocal:tempChatFriendUID friendName:tempChatFriendName withMsg:(rawContent ?: @"") andType:TM_TYPE_CONTACT withAlarmType:AMT_guestChatMessage];
    
    // 消息指令通过网络发送成功后要通知的观察者
    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        // 消息发送成功后，将此消息数据放到聊天列表的数据模型中（让UI进行显示）
        [TChatDataHelper addChatMessageData_outgoing:tempChatFriendUID withData:[JSQMessage createChatMsgEntity_OUTGO_CONTACT:contactMeta withFingerPrint:fingerPring]];
        
        // 消息发送调用者的额外要做的事
        if(sucessObsExtra !=  nil)
            sucessObsExtra(observerble, arg1);
    };
    
    // 调用真正的消息指令发送方法
    [TMessageHelper sendMessageAsync:TM_TYPE_CONTACT tuid:tempChatFriendUID tuname:tempChatFriendName withMessage:[EVAToolKits toJSON:contactMeta] fp:fingerPring forSucess:sendSucessObs];
}

// 将指定的位置消息发送给聊天中的陌生人（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendLocationMessageAsync:(NSString *)tempChatFriendUID tuname:(NSString *)tempChatFriendName withMeta:(LocationMeta *)locationMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra
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
    [TMessageHelper sendMessageAsync:TM_TYPE_LOCATION tuid:tempChatFriendUID tuname:tempChatFriendName withMessage:[EVAToolKits toJSON:locationMeta] fp:fingerPring forSucess:sendSucessObs];
}

// "撤回"消息（异步方式）..
// * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendRevokeMessageAsync:(NSString *)fingerPrint tuid:(NSString *)tempChatFriendUID tuname:(NSString *)tempChatFriendName
                      withMeta:(RevokedMeta *)content forSucess:(ObserverCompletion)sucessObsExtra
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
    [TMessageHelper sendMessageAsync:TM_TYPE_REVOKE tuid:tempChatFriendUID tuname:tempChatFriendName withMessage:[EVAToolKits toJSON:content] fp:fingerPrint forSucess:sendSucessObs];
}

/**
 * 将指定的消息发送给聊天中的陌生人（异步方式）.
 *
 * @param messageType 参见  {@link MsgBody4Friend}中的文本消息类型
 * @param tempChatFriendName 本参数用于已经加好友后的提示信息而已，本参数可为null哦（非必须）
 * @param message 文本消息，如果该文本为null或空字符串则不会真正执行发送过程
 */
+ (void) sendMessageAsync:(int)messageType
                     tuid:(NSString *)tempChatFriendUID
                   tuname:(NSString *)tempChatFriendName // 本参数目前有两个用途：用于提示已成为正式好友时、用于本地发送消息时显示的首页消息页里
              withMessage:(NSString *)message
                       fp:(NSString *)fingerPring
                forSucess:(ObserverCompletion)sucessObs
{
    [TMessageHelper sendMessageAsync:messageType tuid:tempChatFriendUID tuname:tempChatFriendName withMessage:message fp:fingerPring quote:nil forSucess:sucessObs];
}

/**
 * 将指定的消息发送给聊天中的陌生人（异步方式）.
 *
 * @param messageType 参见  {@link MsgBody4Friend}中的文本消息类型
 * @param tempChatFriendName 本参数用于已经加好友后的提示信息而已，本参数可为null哦（非必须）
 * @param message 文本消息，如果该文本为null或空字符串则不会真正执行发送过程
 */
+ (void) sendMessageAsync:(int)messageType
                     tuid:(NSString *)tempChatFriendUID
                   tuname:(NSString *)tempChatFriendName // 本参数目前有两个用途：用于提示已成为正式好友时、用于本地发送消息时显示的首页消息页里
              withMessage:(NSString *)message
                       fp:(NSString *)fingerPring
                    quote:(QuoteMeta *)quoteMeta
                forSucess:(ObserverCompletion)sucessObs
{
    if (message != nil && [message length] > 0)
    {
        // 如果与该陌生人已经是好友了，就提示当前聊天用户进入正式聊天界面中（再行聊天）
        if([[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster:tempChatFriendUID])
        {
            NSString *hint = [NSString stringWithFormat:@"%@ 已是你的好友了, 请关闭此陌生人聊天界面后前往\"好友\"界面继续聊天。"
                              , tempChatFriendName == nil ?@"He/She":tempChatFriendName];
            [APP showToastInfo:hint];
            return;
        }

        // 网络数据发送放到异步线程里提升体验
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),^{

            MsgBody4Guest *tcmd = [self constructTempChatMsgDTOForSend:messageType friendUid:tempChatFriendUID withMsg:message];
            // 尝试设置消息引用信息
            [tcmd setQuoteMeta:quoteMeta];
            
//          int code = [TMessageHelper sendChatMessage:messageType to:tempChatFriendUID msg:message fp:fingerPring];
            int code = [TMessageHelper sendTempChatMsg_A_TO_SERVER_Message:tcmd qos:YES fp:fingerPring];

            dispatch_async(dispatch_get_main_queue(), ^{
                // 消息发送成功
                if(code == COMMON_CODE_OK)
                {
                    if(sucessObs != nil)
                        sucessObs(nil, @(COMMON_CODE_OK));

                    // 将本地用户主动发出的临时聊天消息也入到首页消息栏里.
                    // * <p>
                    // * 2.2版之前，首页消息栏只在收到消息时才会放入，但像微信这样的IM里，
                    // * 为了方便下次查看，自已主动发的消息也放到了首页消息栏（而不限于收到的消息），自已发的消息放到首页消息栏仅仅是为了方便，别无他用。
//                    [AlarmsProvider addATempChatMsgAlarmForLocal:messageType friendUid:tempChatFriendUID friendName:tempChatFriendName withMsg:message];
                    [AlarmsProvider addSingleChatMsgAlarmForLocal:tempChatFriendUID friendName:tempChatFriendName withMsg:message andType:messageType withAlarmType:AMT_guestChatMessage];
                }
                else
                {
                    if(sucessObs != nil)
                        sucessObs(nil, @(COMMON_UNKNOW_ERROR));
                    // 发送失败不弹窗，仅通过气泡前红色感叹号提示
                    DDLogError(@"%@", [NSString stringWithFormat:@"网络发送数据失败，错误信息 code=%d", code]);
                }
            });
        });
    }
}


//------------------------------------------------------------------------
#pragma mark - （3）消息发送同步实现方法

//// 发送聊天消息（包括普通文本、图片消息、语音留言消息等）给指定user_id的用户.
//+ (int)sendChatMessage:(int)msgType to:(NSString *)friendUid msg:(NSString *)msg fp:(NSString *)fingerPrint
//{
//    return [TMessageHelper sendTempChatMsg_A_TO_SERVER_Message:msgType to:friendUid msg:msg qos:YES fp:fingerPrint];
//}
//
//// 发送临时聊天消息：由发送人A发给服务端【步骤1/2】.
//+ (int)sendTempChatMsg_A_TO_SERVER_Message:(int)msgType to:(NSString *)friendUid msg:(NSString *)msg qos:(BOOL)QoS fp:(NSString *)fingerPrint
//{
//    MsgBody4Guest *tcmd = [self constructTempChatMsgDTOForSend:msgType friendUid:friendUid withMsg:msg];
//    // 发送消息时，user_id=0即表示发送给服务端
//    return [TMessageHelper sendTempChatMsg_A_TO_SERVER_Message:tcmd qos:QoS fp:fingerPrint];
//}

// 发送临时聊天消息：由发送人A发给服务端【步骤1/2】.
+ (int)sendTempChatMsg_A_TO_SERVER_Message:(MsgBody4Guest *)tcmd qos:(BOOL)QoS fp:(NSString *)fingerPrint
{
    // 发送消息时，user_id=0即表示发送给服务端
    // 【说明：】自rbchat2.2(2014-02-12)起，临时聊天也启用了QoS机制
    return [SendDataHelper sendMessageImpl:@"0" withMessage:[EVAToolKits toJSON:tcmd] qos:QoS finger:fingerPrint andTypeu:MT42_OF_TEMP_CHAT_MSG_A_TO_SERVER];
}


//------------------------------------------------------------------------
#pragma mark - （4）其它方法

// 构造临时聊天DTO对象.
+ (MsgBody4Guest *) constructTempChatMsgDTOForSend:(int)msgType
                                         friendUid:(NSString *)friendUid
                                           withMsg:(NSString *)msg
{
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    return [self constructTempChatMsgDTO:msgType srcUserUid:localUserInfo.user_uid srcNickName:localUserInfo.nickname friendUid:friendUid withMsg:msg];
}

// 构造临时聊天DTO对象.
+ (MsgBody4Guest *) constructTempChatMsgDTO:(int)msgType
                                 srcUserUid:(NSString *)srcUserUid
                                srcNickName:(NSString *)srcNickName
                                  friendUid:(NSString *)friendUid
                                    withMsg:(NSString *)msg
{
    MsgBody4Guest *tcmd = [[MsgBody4Guest alloc] init];
    tcmd.f = srcUserUid;
    tcmd.nickName = srcNickName;
    tcmd.t = friendUid;
    tcmd.ty = msgType;
    tcmd.m = msg;
    tcmd.cy = CHAT_TYPE_GUEST_CHAT;
    return tcmd;
}

@end
