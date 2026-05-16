//telegram @wz662
#import "MessageHelper.h"
#import "LocalDataSender.h"
#import "EVAToolKits.h"
#import "IMClientManager.h"
#import "AppDelegate.h"
#import "ChatDataHelper.h"
#import "AlarmType.h"
#import "SendRetryManager.h"
#import "AlarmsProvider.h"
#import "NotificationCenterFactory.h"
#import "UserDefaultsToolKits.h"
#import "MessagesProvider.h"

NSInteger const RBLocalSendCodeFriendshipRequired = 70070;

static inline double RBMessageHelperTraceNowMs(void)
{
    return CFAbsoluteTimeGetCurrent() * 1000.0;
}


@implementation MessageHelper

//-------------------------------------------------------------------------------
#pragma mark - （1）解析接收的消息或指令的方法

+ (UserEntity *)parseProcessAdd_Friend_Req_SERVER_TO_A_REJECT_RESULTMessage:(NSString *)originalMsg
{
    DDLogDebug(@"【MessageHelper】!!!!!!收到服务端发过来的好加友被拒信息：%@", originalMsg);
    return [EVAToolKits fromJSON:originalMsg withClazz:UserEntity.class];
}

+ (UserEntity *)parseProcessAdd_Friend_Req_friend_Info_Server_To_ClientMessage:(NSString *)originalMsg
{
    DDLogDebug(@"【MessageHelper】!!!!!!收到服务端发过来的新好友信息：%@", originalMsg);
    return [EVAToolKits fromJSON:originalMsg withClazz:UserEntity.class];
}

+ (UserEntity *)parseAddFriendRequestInfo_server_to_b:(NSString *)originalMsg
{
    DDLogDebug(@"【MessageHelper】!!!!!!收到服务端转发的加好友请求：%@", originalMsg);
    return [EVAToolKits fromJSON:originalMsg withClazz:UserEntity.class];
}

+ (NSString *)parseAddFriendRequestResponse_for_error_server_to_a:(NSString *)originalMsg
{
    return originalMsg;
}

+ (NSString *)pareseRecieveOnlineNotivication:(NSString *)dwUserid withMsg:(NSString *)msg
{
//    DDLogDebug(@"【MessageHelper】!!!!!!!!!!!!》》收到用户%@的上线通知！dwUserid=%@", msg, dwUserid);
    return msg;
}

+ (NSString *)pareseRecieveOfflineNotivication:(NSString *)dwUserid withMsg:(NSString *)msg
{
//    DDLogDebug(@"【MessageHelper】!!!!!!!!!!!!《《收到用户%@的下线通知！dwUserid=%@", msg, dwUserid);
    return msg;
}


//-------------------------------------------------------------------------------
#pragma mark - （2）发出的消息或指令(异步)的方法

// 将指定的纯文消息发送给聊天中的好友
// * 说明：乐观更新——先插入气泡再发网络，发送时气泡已显示，体验更丝滑。
+ (void)sendPlainTextMessageAsync:(NSString *)friendUID withMessage:(NSString *)message quote:(QuoteMeta *)quoteMeta forSucess:(ObserverCompletion)sucessObsExtra
{
    NSString *fingerPring = [Protocal genFingerPrint];
    DDLogInfo(@"[SendTrace][FriendHelperStart] t=%.3f fp=%@ toId=%@ len=%lu",
              RBMessageHelperTraceNowMs(),
              fingerPring ?: @"-",
              friendUID ?: @"-",
              (unsigned long)message.length);
    JSQMessage *m = [JSQMessage createChatMsgEntity_OUTGO_TEXT:message withFingerPrint:fingerPring];
    [m setQuoteMeta:quoteMeta];
    if (quoteMeta != nil && friendUID != nil && [friendUID isEqualToString:@"10001"]) {
        if (quoteMeta.quote_sender_uid.length > 0) m.senderId = quoteMeta.quote_sender_uid;
        if (quoteMeta.quote_sender_nick.length > 0) m.senderDisplayName = quoteMeta.quote_sender_nick;
    }
    // 先插入气泡，再发网络（气泡立即显示“发送中”，收到 ack 后会自动更新为已送达）
    [ChatDataHelper addChatMessageData_outgoing:friendUID withData:m];
    DDLogInfo(@"[SendTrace][FriendHelperLocalInsertDone] t=%.3f fp=%@ toId=%@",
              RBMessageHelperTraceNowMs(),
              fingerPring ?: @"-",
              friendUID ?: @"-");

    // 立即更新会话列表预览和排序（避免等 ACK 才刷新，导致返回列表时排序不对）
    NSString *preview = [JSQMessage parseMessageContentPreview:message withType:TM_TYPE_TEXT];
    [AlarmsProvider addSingleChatMsgAlarmForLocal:friendUID friendName:nil withMsg:preview andType:TM_TYPE_TEXT withAlarmType:AMT_friendChatMessage];

    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        DDLogInfo(@"[SendTrace][FriendHelperNetworkCallback] t=%.3f fp=%@ code=%d",
                  RBMessageHelperTraceNowMs(),
                  fingerPring ?: @"-",
                  [arg1 intValue]);
        if ([arg1 intValue] != COMMON_CODE_OK) {
            [[SendRetryManager sharedInstance] startRetryForTextFp:fingerPring toId:friendUID text:message quoteMeta:quoteMeta];
            DDLogError(@"%@", [NSString stringWithFormat:@"网络发送数据失败，错误信息 code=%d", [arg1 intValue]]);
        } else {
            // 本次接口返回成功仍启动 60 秒超时：若未收到 ack 则标记失败并显示红点，避免一直转圈（不触发 2s/5s 重发，避免重复）
            [[SendRetryManager sharedInstance] startGiveUpTimerOnlyForTextFp:fingerPring toId:friendUID];
        }
        if (sucessObsExtra != nil) sucessObsExtra(observerble, arg1);
    };
    DDLogInfo(@"[SendTrace][FriendHelperSendAsyncInvoke] t=%.3f fp=%@ toId=%@",
              RBMessageHelperTraceNowMs(),
              fingerPring ?: @"-",
              friendUID ?: @"-");
    [MessageHelper sendMessageAsync:TM_TYPE_TEXT to:friendUID withMessage:message finger:fingerPring quote:quoteMeta forSucess:sendSucessObs];
}

// 将指定的图片消息发送给聊天中的好友
// * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendImageMessageAsync:(NSString *)friendUID withImage:(NSString *)imageFileName fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra
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
    [MessageHelper sendMessageAsync:TM_TYPE_IMAGE to:friendUID withMessage:imageFileName finger:fingerPring forSucess:sendSucessObs];
}

// 将指定的语音消息发送给聊天中的好友
// * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendVoiceMessageAsync:(NSString *)friendUID withVoice:(NSString *)voiceFileName fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra
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
    [MessageHelper sendMessageAsync:TM_TYPE_VOICE to:friendUID withMessage:voiceFileName finger:fingerPring forSucess:sendSucessObs];
}

// 将指定的文件消息发送给聊天中的好友（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendFileMessageAsync:(NSString *)friendUID withMeta:(FileMeta *)fileMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra
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
    [MessageHelper sendMessageAsync:TM_TYPE_FILE to:friendUID withMessage:[EVAToolKits toJSON:fileMeta] finger:fingerPring forSucess:sendSucessObs];
}

// 将指定的短视频消息发送给聊天中的好友（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendShortVideoMessageAsync:(NSString *)friendUID withMeta:(FileMeta *)fileMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra
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
    [MessageHelper sendMessageAsync:TM_TYPE_SHORTVIDEO to:friendUID withMessage:[EVAToolKits toJSON:fileMeta] finger:fingerPring forSucess:sendSucessObs];
}

// 将指定的名片消息发送给聊天中的好友（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendContactMessageAsync:(NSString *)friendUID withMeta:(ContactMeta *)contactMeta forSucess:(ObserverCompletion)sucessObsExtra
{
    // 先生成指纹码
    NSString *fingerPring = [Protocal genFingerPrint];
    NSString *rawContent = [EVAToolKits toJSON:contactMeta];
    [AlarmsProvider addSingleChatMsgAlarmForLocal:friendUID friendName:nil withMsg:(rawContent ?: @"") andType:TM_TYPE_CONTACT withAlarmType:AMT_friendChatMessage];
    
    // 消息指令通过网络发送成功后要通知的观察者
    ObserverCompletion sendSucessObs = ^(id observerble, id arg1) {
        // 消息发送成功后，将此消息数据放到聊天列表的数据模型中（让UI进行显示）
        [ChatDataHelper addChatMessageData_outgoing:friendUID withData:[JSQMessage createChatMsgEntity_OUTGO_CONTACT:contactMeta withFingerPrint:fingerPring]];
        
        // 消息发送调用者的额外要做的事
        if(sucessObsExtra !=  nil)
            sucessObsExtra(observerble, arg1);
    };
    
    // 调用真正的消息指令发送方法
    [MessageHelper sendMessageAsync:TM_TYPE_CONTACT to:friendUID withMessage:[EVAToolKits toJSON:contactMeta] finger:fingerPring forSucess:sendSucessObs];
}

// 将指定的位置消息发送给聊天中的好友（异步方式）.
// * 说明：本方法及其变种方法属于聊天界面中可能用户被频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
+ (void)sendLocationMessageAsync:(NSString *)friendUID withMeta:(LocationMeta *)locationMeta fp:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObsExtra
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
    [MessageHelper sendMessageAsync:TM_TYPE_LOCATION to:friendUID withMessage:[EVAToolKits toJSON:locationMeta] finger:fingerPring forSucess:sendSucessObs];
}

/**
 * "撤回"消息（异步方式）.
 *
 * @param content 消息撤回指令的内容就是RevokedMeta对象
 */
+ (void)sendRevokeMessageAsync:(NSString *)fingerPrint friendUID:(NSString *)friendUID withMeta:(RevokedMeta *)content forSucess:(ObserverCompletion)sucessObsExtra
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
    [MessageHelper sendMessageAsync:TM_TYPE_REVOKE to:friendUID withMessage:[EVAToolKits toJSON:content] finger:fingerPrint forSucess:sendSucessObs];
}

/**
 * 将指定的文本发送给聊天中的好友.
 * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param messageType 参见  {@link TextMessage}中的文本消息类型
 * @param friendUID 接收者的uid
 * @param message 文本消息，如果该文本为null或空字符串则不会真正执行发送过程
 * @param fingerPring 消息指纹码（即全局唯一ID）
 * @param sucessObs 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 */
+ (void)sendMessageAsync:(int)messageType to:(NSString *)friendUID withMessage:(NSString *)message finger:(NSString *)fingerPring forSucess:(ObserverCompletion)sucessObs
{
    [MessageHelper sendMessageAsync:messageType to:friendUID withMessage:message finger:fingerPring quote:nil forSucess:sucessObs];
}

/**
 * 将指定的文本发送给聊天中的好友.
 * 说明：本方法及其变种方法属于聊天界面中可能被用户频繁调用的方法，为了提升界面交互体验，使用了GCD异步实现。
 *
 * @param messageType 参见  {@link TextMessage}中的文本消息类型
 * @param friendUID 接收者的uid
 * @param message 文本消息，如果该文本为null或空字符串则不会真正执行发送过程
 * @param fingerPring 消息指纹码（即全局唯一ID）
 * @param quoteMeta  消息引用信息（当前仅用于文本消息时），此字段可为空（表示本条无引用消息）
 * @param sucessObs 数据发出成功与否的回调（注意：因UDP的无连接特性，能“成功”发出的消息只表示从APP成功送出，至于对方对不能收到UDP是无法知道了（这就涉及到MobileIMSDK消息送机制的应答机制了，详情请上52im.net论坛查阅查关资料））
 */
+ (void)sendMessageAsync:(int)messageType to:(NSString *)friendUID withMessage:(NSString *)message finger:(NSString *)fingerPring quote:(QuoteMeta *)quoteMeta forSucess:(ObserverCompletion)sucessObs
{
    if (message != nil && [message length] > 0)
    {
        UserEntity *currentChattingUser = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid:friendUID];

        // 出现此种情形的可能发生于：我已把对方删除，但从首先对方原先发过来的Alram点到ChatActivity时就会出现这种情况哦！
        if(currentChattingUser == nil)
        {
            NSString *hint = @"对方已不是你的好友，当前不可发送消息，请先重新添加好友。";
            BOOL wasBlocked = [UserDefaultsToolKits isFriendChatSendBlockedUid:friendUID];
            if (!wasBlocked) {
                [UserDefaultsToolKits markFriendChatSendBlockedUid:friendUID];
            }
            [NotificationCenterFactory friendChatSendBlockedStateChanged_POST:friendUID blocked:YES hint:hint];

            MessagesProvider *mp = [[IMClientManager sharedInstance] getMessagesProvider];
            if (fingerPring.length > 0) {
                [mp markOutgoingMessageFailedForFp:fingerPring preferredPeerUid:friendUID];
            }

            if (!wasBlocked) {
                UserEntity *ree = [[UserEntity alloc] init];
                ree.user_uid = friendUID;
                ree.nickname = friendUID;
                NSString *localUid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
                if (localUid.length == 0) localUid = @"0";
                NSString *sysFp = [NSString stringWithFormat:@"SYS_FRIENDSHIP_REQUIRED_FAIL_%@_%@", localUid, friendUID];
                [ChatDataHelper addSystemInfoData:ree infoContent:hint fingerPrint:sysFp date:nil playAudio:NO showNotify:NO];
                [APP showToastWarn:hint];
            }

            if (sucessObs != nil) {
                sucessObs(nil, @(RBLocalSendCodeFriendshipRequired));
            }
            return;
        }

        // 网络数据发送放到异步线程里提升体验
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),^{
            MsgBody4Friend *msgBody = [MsgBody4Friend constructFriendChatMsgBody:[[ClientCoreSDK sharedInstance] currentLoginUserId] t:friendUID m:message ty:messageType];
            // 尝试设置消息引用信息
            [msgBody setQuoteMeta:quoteMeta];
            int code = [MessageHelper sendChatMessage:friendUID withMessage:msgBody finger:fingerPring];

            dispatch_async(dispatch_get_main_queue(), ^{
                // 消息发送成功
                if(code == COMMON_CODE_OK)
                {
                    if(sucessObs != nil)
                        sucessObs(nil, @(COMMON_CODE_OK));

                    // 将本地用户主动发出的临时聊天消息也入到首页消息栏里(像微信这样的IM里，
                    // 为了方便下次查看，自已主动发的消息也放到了首页消息栏（而不限于收到的消息），自已发的消息放到首页消息栏仅仅是为了方便，别无他用。)
                    [AlarmsProvider addSingleChatMsgAlarmForLocal:currentChattingUser.user_uid friendName:[currentChattingUser getNickNameWithRemark]  withMsg:message andType:messageType withAlarmType:AMT_friendChatMessage];
                }
                else
                {
                    if(sucessObs != nil)
                        sucessObs(nil, @(COMMON_UNKNOW_ERROR));
                    // 发送失败不弹窗，仅通过气泡前红色感叹号提示，用户可点击重发
                    DDLogError(@"%@", [NSString stringWithFormat:@"网络发送数据失败，错误信息 code=%d", code]);
                }
            });
        });
    }
}


//-------------------------------------------------------------------------------
#pragma mark - （3）发出的消息或指令(同步)的方法

+ (int)sendChatMessage:(NSString *)user_id withMessage:(MsgBody4Friend *)message finger:(NSString *)fingerPrint
{
    return [SendDataHelper sendMessageImpl:user_id withMessage:[EVAToolKits toJSON:message] qos:YES finger:fingerPrint andTypeu:MT03_OF_CHATTING_MESSAGE];
}

+ (int)sendAddFriendRequestToServerMessage:(CMDBody4AddFriendRequest *)arm
{
    // 发送消息时，user_id=0即表示发送给服务端
    return [SendDataHelper sendMessageImpl:@"0"
                              // 注意：加好友的请求是由服务端代发的哦，因为发起人此时不知道对方的user_id
                              // 此时开启了QoS==true，目的是保证我发起的加好友请求在丢包的情况下可以重传
                              withMessage:[EVAToolKits toJSON:arm] qos:YES andTypeu:MT05_OF_ADD_FRIEND_REQUEST_A_TO_SERVER];
}

+ (int)sendAddFriendRequestToServerMessage:(NSString *)friendUid say:(NSString *)saySomethingToHim addSource:(NSString *)addSource
{
    // 加好友请求原数据（将要发送给服务端的）
    CMDBody4AddFriendRequest *arm = [[CMDBody4AddFriendRequest alloc] init];
    arm.localUserUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    arm.friendUserUid= friendUid;
//  arm.setFriendUserMail(friendMail);// 此mail用于发往服务端转发时从在线列表中判断该用户是否在线之用，本参数不可为null哦
    arm.desc = saySomethingToHim;
    arm.addSource = addSource;

    // 发送消息时，user_id=0即表示发送给服务端
    return [MessageHelper sendAddFriendRequestToServerMessage:arm];
}

+ (int)sendProcessAdd_Friend_Req_B_To_Server_AGREEMessage:(CMDBody4ProcessFriendRequest *)pfrm
{
    // 发送消息时，user_id=0即表示发送给服务端
    return [SendDataHelper sendMessageImpl:@"0"
                              withMessage:[EVAToolKits toJSON:pfrm] qos:YES andTypeu:MT08_OF_PROCESS_ADD_FRIEND_REQ_B_TO_SERVER_AGREE];
}

+ (int)sendProcessAdd_Friend_Req_B_To_Server_REJECTMessage:(CMDBody4ProcessFriendRequest *)pfrm
{
    // 发送消息时，user_id=0即表示发送给服务端
    return [SendDataHelper sendMessageImpl:@"0"
                              withMessage:[EVAToolKits toJSON:pfrm] qos:YES andTypeu:MT09_OF_PROCESS_ADD_FRIEND_REQ_B_TO_SERVER_REJECT];
}

+ (int)sendVideoAndVoice_EndChatting_from_a:(NSString *)to_user_id local:(NSString *)localUserUid
{
    return [SendDataHelper sendMessageImpl:to_user_id
                              withMessage:localUserUid qos:YES andTypeu:MT14_OF_VIDEO_VOICE_END_CHATTING];// 此消息需要质量保证
}
+(NSString *)pareseVideoAndVoice_EndChatting_from_a:(NSString *)originalMsg
{
    return originalMsg;
}

+ (int)sendVideoAndVoice_SwitchToVoiceOnly_from_a:(NSString *)to_user_id local:(NSString *)localUserUid
{
    return [SendDataHelper sendMessageImpl:to_user_id
                              withMessage:localUserUid qos:YES andTypeu:MT15_OF_VIDEO_VOICE_SWITCH_TO_VOICE_ONLY];// 此消息需要质量保证
}
+(NSString *)pareseVideoAndVoice_SwitchToVoiceOnly_from_a:(NSString *)originalMsg
{
    return originalMsg;
}

+ (int)sendVideoAndVoice_SwitchToVoiceAndVideo_from_a:(NSString *)to_user_id local:(NSString *)localUserUid
{
    return [SendDataHelper sendMessageImpl:to_user_id
                              withMessage:localUserUid qos:YES andTypeu:MT16_OF_VIDEO_VOICE_SWITCH_TO_VOICE_AND_VIDEO];// 此消息需要质量保证
}
+ (NSString *)pareseVideoAndVoice_SwitchToVoiceAndVideo_from_a:(NSString *)originalMsg
{
    return originalMsg;
}

+ (int)sendVideoAndVoiceRequest_Requestting_from_a:(NSString *)to_user_id local:(NSString *)localUserUid
{
    return [SendDataHelper sendMessageImpl:to_user_id
                              withMessage:localUserUid qos:YES andTypeu:MT17_OF_VIDEO_VOICE_REQUEST_REQUESTING_FROM_A];// 此消息需要质量保证
}
+ (NSString *)pareseVideoAndVoiceRequest_Requestting_from_a:(NSString *)originalMsg
{
    return originalMsg;
}

+ (int)sendVideoAndVoiceRequest_Abort_from_a:(NSString *)to_user_id local:(NSString *)localUserUid
{
    return [SendDataHelper sendMessageImpl:to_user_id
                              withMessage:localUserUid qos:YES andTypeu:MT18_OF_VIDEO_VOICE_REQUEST_ABRORT_FROM_A];// 此消息需要质量保证
}
+ (NSString *)pareseVideoAndVoiceRequest_Abort_from_a:(NSString *)originalMsg
{
    return originalMsg;
}

+ (int)sendVideoAndVoiceRequest_Accept_to_a:(NSString *)to_user_id local:(NSString *)localUserUid
{
    return [SendDataHelper sendMessageImpl:to_user_id
                              withMessage:localUserUid qos:YES andTypeu:MT19_OF_VIDEO_VOICE_REQUEST_ACCEPT_TO_A];// 此消息需要质量保证
}
+ (NSString *)pareseVideoAndVoiceRequest_Accept_to_a:(NSString *)originalMsg
{
    return originalMsg;
}

+ (int)sendVideoAndVoiceRequest_Reject_to_a:(NSString *)to_user_id local:(NSString *)localUserUid
{
    return [SendDataHelper sendMessageImpl:to_user_id
                              withMessage:localUserUid qos:YES andTypeu:MT20_OF_VIDEO_VOICE_REQUEST_REJECT_TO_A];// 此消息需要质量保证
}
+ (NSString *)pareseVideoAndVoiceRequest_Reject_to_a:(NSString *)originalMsg
{
    return originalMsg;
}

@end
