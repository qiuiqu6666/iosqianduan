//
//  CallManager.m
//  RainbowChat4i
//
//  通话状态机管理器实现。
//

#import "CallManager.h"
#import "AgoraManager.h"
#import "IMClientManager.h"
#import "MessageHelper.h"
#import "SendDataHelper.h"
#import "UserProtocalsType.h"
#import "Default.h"
#import "VoipRecordMeta.h"
#import "ChatDataHelper.h"
#import "JSQMessage.h"
#import "EVAToolKits.h"
#import "AlarmsProvider.h"
#import "AlarmType.h"
#import "HttpRestHelper.h"
#import "CallSoundManager.h"
#import "CallKitManager.h"
#import "CallPiPManager.h"
#import "Protocal.h"
#import "MsgBodyRoot.h"
#import "MessagesProvider.h"

@interface CallManager ()

@property (nonatomic, assign, readwrite) CallState currentState;
@property (nonatomic, assign, readwrite) CallType currentCallType;
@property (nonatomic, copy, readwrite) NSString *remoteUserUid;
@property (nonatomic, copy, readwrite) NSString *remoteUserNickname;
@property (nonatomic, strong, readwrite) NSDate *callConnectedTime;
@property (nonatomic, assign, readwrite) BOOL isCaller;

/// 呼叫超时定时器
@property (nonatomic, strong) NSTimer *callTimeoutTimer;

@end

@implementation CallManager

static NSMutableSet<NSString *> *s_rbVoipScrollPendingUids(void)
{
    static NSMutableSet<NSString *> *set;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [[NSMutableSet alloc] init];
    });
    return set;
}

+ (NSString *)rb_notificationNameVoipRecordAppended
{
    return @"RBVoipRecordDidAppend";
}

+ (void)rb_markPendingScrollToBottomForChatUid:(NSString *)uid
{
    if (uid.length == 0) return;
    @synchronized (s_rbVoipScrollPendingUids()) {
        [s_rbVoipScrollPendingUids() addObject:uid];
    }
}

+ (BOOL)rb_consumePendingScrollToBottomForChatUid:(NSString *)uid
{
    if (uid.length == 0) return NO;
    BOOL existed = NO;
    @synchronized (s_rbVoipScrollPendingUids()) {
        existed = [s_rbVoipScrollPendingUids() containsObject:uid];
        if (existed) {
            [s_rbVoipScrollPendingUids() removeObject:uid];
        }
    }
    return existed;
}

#pragma mark - 单例

+ (instancetype)sharedInstance
{
    static CallManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CallManager alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _currentState = CallStateIdle;
        _isCaller = NO;
        // 注意：不在此处设置 AgoraManager.delegate，由 CallViewController 统一管理
        // Token 刷新回调由 CallViewController 转发给 CallManager
    }
    return self;
}

#pragma mark - 主叫方操作

- (void)startCall:(NSString *)remoteUid remoteNickname:(NSString *)remoteNickname callType:(CallType)callType
{
    if (self.currentState != CallStateIdle) {
        NSLog(@"【CallManager】当前已在通话状态中（state=%ld），无法发起新的呼叫！", (long)self.currentState);
        if ([self.delegate respondsToSelector:@selector(callManager:didOccurError:)]) {
            [self.delegate callManager:self didOccurError:@"当前已在通话中，请先结束当前通话"];
        }
        return;
    }
    
    self.remoteUserUid = remoteUid;
    self.remoteUserNickname = remoteNickname;
    self.currentCallType = callType;
    self.isCaller = YES;
    self.callConnectedTime = nil;
    
    // 获取本地用户UID
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    
    // 发送呼叫信令
    int result = 0;
    if (callType == CallTypeVideo) {
        result = [MessageHelper sendVideoAndVoiceRequest_Requestting_from_a:remoteUid local:localUid];
    } else {
        // 语音通话使用 MT31 协议
        result = [SendDataHelper sendMessageImpl:remoteUid
                                     withMessage:localUid
                                             qos:YES
                                        andTypeu:MT31_OF_REAL_TIME_VOICE_REQUEST_REQUESTING_FROM_A];
    }
    
    if (result == 0) {
        [self changeState:CallStateOutgoingCalling];
        NSLog(@"【CallManager】呼叫信令已发出：type=%@，remote=%@", (callType == CallTypeVideo ? @"视频" : @"语音"), remoteUid);
        
        // 启动超时定时器
        [self startCallTimeoutTimer];
    } else {
        NSLog(@"【CallManager】呼叫信令发送失败：result=%d", result);
        [self reset];
        if ([self.delegate respondsToSelector:@selector(callManager:didOccurError:)]) {
            [self.delegate callManager:self didOccurError:@"呼叫信令发送失败，请检查网络"];
        }
    }
}

- (void)cancelCall
{
    if (self.currentState != CallStateOutgoingCalling) {
        NSLog(@"【CallManager】当前不在呼出状态，无法取消呼叫。");
        return;
    }
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    
    // 发送取消呼叫信令
    if (self.currentCallType == CallTypeVideo) {
        [MessageHelper sendVideoAndVoiceRequest_Abort_from_a:self.remoteUserUid local:localUid];
    } else {
        [SendDataHelper sendMessageImpl:self.remoteUserUid
                            withMessage:localUid
                                    qos:YES
                               andTypeu:MT32_OF_REAL_TIME_VOICE_REQUEST_ABRORT_FROM_A];
    }
    
    NSLog(@"【CallManager】已发送取消呼叫信令。");
    
    // 保存通话记录：已取消
    [self saveCallRecordWithRecordType:VOIP_RECORD_TYPE_REQUEST_CANCEL];
    
    [self reset];
}

#pragma mark - 被叫方操作

- (void)onIncomingCall:(NSString *)remoteUid remoteNickname:(NSString *)remoteNickname callType:(CallType)callType
{
    if (self.currentState != CallStateIdle) {
        NSLog(@"【CallManager】收到来电但当前已在通话中，自动拒绝来电。");
        
        NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        
        // 自动拒绝
        if (callType == CallTypeVideo) {
            [MessageHelper sendVideoAndVoiceRequest_Reject_to_a:remoteUid local:localUid];
        } else {
            [SendDataHelper sendMessageImpl:remoteUid
                                withMessage:localUid
                                        qos:YES
                                   andTypeu:MT34_OF_REAL_TIME_VOICE_REQUEST_REJECT_TO_A];
        }
        return;
    }
    
    self.remoteUserUid = remoteUid;
    self.remoteUserNickname = remoteNickname;
    self.currentCallType = callType;
    self.isCaller = NO;
    self.callConnectedTime = nil;
    
    [self changeState:CallStateIncomingCalling];
    NSLog(@"【CallManager】收到来电：type=%@，from=%@(%@)", (callType == CallTypeVideo ? @"视频" : @"语音"), remoteNickname, remoteUid);
    
    // ========== 在线 IM 来电：根据"弹窗快捷接听"设置决定是否通过 CallKit 显示系统来电界面 ==========
    // 前台时由 in-app CallViewController 处理，避免 CallKit 来电界面和 in-app UI 同时出现
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    
    // 检查"语音和视频通话用弹窗快捷接听"开关（默认开启）
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL popupEnabled = ([ud objectForKey:@"APP_VOICE_VIDEO_POPUP_ENABLED"] == nil) ? YES : [ud boolForKey:@"APP_VOICE_VIDEO_POPUP_ENABLED"];
    
    if (popupEnabled && appState != UIApplicationStateActive && [CallKitManager sharedInstance].currentCallUUID == nil) {
        NSString *callTypeStr = (callType == CallTypeVideo) ? @"video" : @"voice";
        [[CallKitManager sharedInstance] reportIncomingCall:remoteUid
                                                callerName:remoteNickname
                                                  callType:callTypeStr
                                                completion:^(NSError *error) {
            if (error) {
                NSLog(@"【CallManager】在线来电报告 CallKit 失败: %@", error.localizedDescription);
            }
        }];
    }
}

- (void)acceptCall
{
    if (self.currentState != CallStateIncomingCalling) {
        NSLog(@"【CallManager】当前不在来电状态，无法接听。");
        return;
    }
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    
    // 发送同意信令
    if (self.currentCallType == CallTypeVideo) {
        [MessageHelper sendVideoAndVoiceRequest_Accept_to_a:self.remoteUserUid local:localUid];
    } else {
        [SendDataHelper sendMessageImpl:self.remoteUserUid
                            withMessage:localUid
                                    qos:YES
                               andTypeu:MT33_OF_REAL_TIME_VOICE_REQUEST_ACCEPT_TO_A];
    }
    
    NSLog(@"【CallManager】已发送接听信令。");
    
    // 先更新状态让 UI 立即响应（通话界面切换到"通话中"）
    self.callConnectedTime = [NSDate date];
    [self changeState:CallStateConnected];
    
    if (self.currentCallType == CallTypeVideo) {
        [[CallPiPManager sharedInstance] preparePiPForVideoCall];
    }
    
    // 异步请求 Token 并加入声网频道
    [self requestTokenAndJoinChannel];
}

- (void)rejectCall
{
    if (self.currentState != CallStateIncomingCalling) {
        NSLog(@"【CallManager】当前不在来电状态，无法拒绝。");
        return;
    }
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    
    // 发送拒绝信令
    if (self.currentCallType == CallTypeVideo) {
        [MessageHelper sendVideoAndVoiceRequest_Reject_to_a:self.remoteUserUid local:localUid];
    } else {
        [SendDataHelper sendMessageImpl:self.remoteUserUid
                            withMessage:localUid
                                    qos:YES
                               andTypeu:MT34_OF_REAL_TIME_VOICE_REQUEST_REJECT_TO_A];
    }
    
    NSLog(@"【CallManager】已发送拒绝信令。");
    
    // 保存通话记录：已拒绝
    [self saveCallRecordWithRecordType:VOIP_RECORD_TYPE_REQUEST_REJECT];
    
    [self reset];
}

#pragma mark - 通话中操作

- (void)hangupCall
{
    if (self.currentState == CallStateIdle) {
        NSLog(@"【CallManager】当前不在通话中，无需挂断。");
        return;
    }
    
    // 如果是呼出中或来电中状态，分别调用对应的取消/拒绝方法
    if (self.currentState == CallStateOutgoingCalling) {
        [self cancelCall];
        return;
    }
    if (self.currentState == CallStateIncomingCalling) {
        [self rejectCall];
        return;
    }
    
    // 通话中状态 → 发送挂断信令
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    
    if (self.currentCallType == CallTypeVideo) {
        [MessageHelper sendVideoAndVoice_EndChatting_from_a:self.remoteUserUid local:localUid];
    } else {
        [SendDataHelper sendMessageImpl:self.remoteUserUid
                            withMessage:localUid
                                    qos:YES
                               andTypeu:MT35_OF_REAL_TIME_VOICE_END_CHATTING];
    }
    
    NSLog(@"【CallManager】已发送挂断信令，通话时长=%ld秒。", (long)[self getCallDuration]);
    
    // 保存通话记录：通话时长
    [self saveCallRecordWithRecordType:VOIP_RECORD_TYPE_CHATTING_DURATION];
    
    // 离开声网频道
    [[AgoraManager sharedInstance] leaveChannel];
    
    [self reset];
}

#pragma mark - IM 信令消息处理

- (void)onRemoteAccepted:(NSString *)remoteUid
{
    if (self.currentState != CallStateOutgoingCalling) {
        NSLog(@"【CallManager】收到对方同意信令但当前不在呼出状态，忽略。");
        return;
    }
    
    if (![remoteUid isEqualToString:self.remoteUserUid]) {
        NSLog(@"【CallManager】收到对方同意信令但UID不匹配（期望=%@，收到=%@），忽略。", self.remoteUserUid, remoteUid);
        return;
    }
    
    [self stopCallTimeoutTimer];
    
    NSLog(@"【CallManager】对方已接听！");
    
    // 先更新状态让 UI 立即响应
    self.callConnectedTime = [NSDate date];
    [self changeState:CallStateConnected];
    
    if (self.currentCallType == CallTypeVideo) {
        [[CallPiPManager sharedInstance] preparePiPForVideoCall];
    }
    
    if ([self.delegate respondsToSelector:@selector(callManagerDidRemoteAccept:)]) {
        [self.delegate callManagerDidRemoteAccept:self];
    }
    
    // 异步请求 Token 并加入声网频道
    [self requestTokenAndJoinChannel];
}

- (void)onRemoteRejected:(NSString *)remoteUid
{
    if (self.currentState != CallStateOutgoingCalling) {
        NSLog(@"【CallManager】收到对方拒绝信令但当前不在呼出状态，忽略。");
        return;
    }
    
    NSLog(@"【CallManager】对方已拒绝！");
    
    [self stopCallTimeoutTimer];
    
    // 保存通话记录：对方已拒绝
    [self saveCallRecordWithRecordType:VOIP_RECORD_TYPE_REQUEST_REJECT];
    
    [self reset];
    
    if ([self.delegate respondsToSelector:@selector(callManagerDidRemoteReject:)]) {
        [self.delegate callManagerDidRemoteReject:self];
    }
}

- (void)onRemoteCancelled:(NSString *)remoteUid
{
    if (self.currentState != CallStateIncomingCalling) {
        NSLog(@"【CallManager】收到对方取消信令但当前不在来电状态，忽略。");
        return;
    }
    
    NSLog(@"【CallManager】对方已取消呼叫！");
    
    // 保存通话记录：对方已取消
    [self saveCallRecordWithRecordType:VOIP_RECORD_TYPE_REQUEST_CANCEL];
    
    [self reset];
    
    if ([self.delegate respondsToSelector:@selector(callManagerDidRemoteCancel:)]) {
        [self.delegate callManagerDidRemoteCancel:self];
    }
}

- (void)onRemoteHangup:(NSString *)remoteUid
{
    if (self.currentState != CallStateConnected) {
        NSLog(@"【CallManager】收到对方挂断信令但当前不在通话中，忽略。");
        return;
    }
    
    NSLog(@"【CallManager】对方已挂断！通话时长=%ld秒。", (long)[self getCallDuration]);
    
    // 保存通话记录：通话时长
    [self saveCallRecordWithRecordType:VOIP_RECORD_TYPE_CHATTING_DURATION];
    
    // 离开声网频道
    [[AgoraManager sharedInstance] leaveChannel];
    
    [self reset];
    
    if ([self.delegate respondsToSelector:@selector(callManagerDidRemoteHangup:)]) {
        [self.delegate callManagerDidRemoteHangup:self];
    }
}

#pragma mark - 保存通话记录到聊天对话中

/// 检查与该 peer 的最近消息中是否已有相同 recordType 的通话记录（时间窗内），用于避免一次通话写入两条
- (BOOL)hasRecentVoipRecordForPeer:(NSString *)peerUid recordType:(int)recordType withinSeconds:(NSTimeInterval)seconds
{
    if (!peerUid.length) return NO;
    MessagesProvider *mp = [[IMClientManager sharedInstance] getMessagesProvider];
    if (!mp) return NO;
    NSMutableArrayObservableEx *msgs = [mp getMessages:peerUid];
    if (!msgs) return NO;
    NSArray *dataList = [msgs getDataList];
    if (!dataList.count) return NO;
    NSDate *now = [NSDate date];
    NSInteger start = MAX(0, (NSInteger)dataList.count - 20);
    for (NSInteger i = (NSInteger)dataList.count - 1; i >= start; i--) {
        JSQMessage *msg = dataList[i];
        if (msg.msgType != TM_TYPE_VOIP_RECORD || msg.date == nil) continue;
        NSTimeInterval diff = [now timeIntervalSinceDate:msg.date];
        if (diff < 0 || diff > seconds) continue;
        VoipRecordMeta *vrm = msg.voipRecordMeta;
        if (vrm == nil && msg.text != nil && [msg.text hasPrefix:@"{"]) {
            vrm = [VoipRecordMeta fromJSON:msg.text];
        }
        if (vrm != nil && vrm.recordType == recordType) {
            return YES;
        }
    }
    return NO;
}

/// 保存通话记录到聊天消息列表中，方便用户在对话中看到通话历史
- (void)saveCallRecordWithRecordType:(int)recordType
{
    if (self.remoteUserUid == nil) {
        NSLog(@"【CallManager】无法保存通话记录：remoteUserUid 为空。");
        return;
    }
    
    // 判断voipType
    int voipType = (self.currentCallType == CallTypeVideo) ? VOIP_TYPE_VIDEO : VOIP_TYPE_VOICE;
    
    // 计算通话时长
    int duration = 0;
    if (recordType == VOIP_RECORD_TYPE_CHATTING_DURATION) {
        duration = (int)[self getCallDuration];
    }
    
    // ★ 主叫方：仅在同一通电话的极短时间窗（2 秒）内已存在相同 recordType 时才跳过，避免同一次挂断被双写；超过 2 秒视为新一次通话，正常写入
    if (self.isCaller && [self hasRecentVoipRecordForPeer:self.remoteUserUid recordType:recordType withinSeconds:2.0]) {
        NSLog(@"【CallManager】跳过重复保存通话记录：与 %@ 的 recordType=%d 在 2 秒内已存在（同一次通话防双写）。", self.remoteUserUid, recordType);
        // 仍更新首页预览
        NSString *typeStr0 = (voipType == VOIP_TYPE_VOICE) ? @"语音通话" : @"视频通话";
        NSString *content0 = @"";
        switch (recordType) {
            case VOIP_RECORD_TYPE_REQUEST_CANCEL: content0 = @"已取消"; break;
            case VOIP_RECORD_TYPE_REQUEST_REJECT: content0 = @"对方已拒绝"; break;
            case VOIP_RECORD_TYPE_CALLING_TIMEOUT: content0 = @"对方无应答"; break;
            case VOIP_RECORD_TYPE_CHATTING_DURATION: content0 = duration > 0 ? [NSString stringWithFormat:@"通话时长 %02d:%02d", duration/60, duration%60] : @"通话已结束"; break;
            default: break;
        }
        NSString *messageContentForShow0 = [NSString stringWithFormat:@"%@ · %@", typeStr0, content0];
        NSString *remoteNick0 = self.remoteUserNickname ?: self.remoteUserUid;
        [[[IMClientManager sharedInstance] getAlarmsProvider] addSingleChatMessageAlarm:self.remoteUserUid
                                                                            friendName:remoteNick0
                                                                    withConcentForShow:messageContentForShow0
                                                                             flagNumToAdd:0
                                                                                 withDate:nil
                                                                            withAlarmType:AMT_friendChatMessage
                                                                           fingerPrint:nil];
        return;
    }
    // ★ 若本次要保存的是「通话已结束」，但 90 秒内已有「已取消」或「对方无应答」，则不再写入第二条（避免同一次通话出现「已取消」+「通话已结束」两条）
    if (recordType == VOIP_RECORD_TYPE_CHATTING_DURATION && self.isCaller) {
        if ([self hasRecentVoipRecordForPeer:self.remoteUserUid recordType:VOIP_RECORD_TYPE_REQUEST_CANCEL withinSeconds:90.0] ||
            [self hasRecentVoipRecordForPeer:self.remoteUserUid recordType:VOIP_RECORD_TYPE_CALLING_TIMEOUT withinSeconds:90.0]) {
            NSLog(@"【CallManager】跳过保存「通话已结束」：与 %@ 在 90 秒内已有取消/超时记录，不重复写入。", self.remoteUserUid);
            // 仍更新首页预览
            NSString *typeStr = (voipType == VOIP_TYPE_VOICE) ? @"语音通话" : @"视频通话";
            NSString *content = duration > 0 ? [NSString stringWithFormat:@"通话时长 %02d:%02d", duration/60, duration%60] : @"通话已结束";
            NSString *messageContentForShow = [NSString stringWithFormat:@"%@ · %@", typeStr, content];
            NSString *remoteNick = self.remoteUserNickname ?: self.remoteUserUid;
            [[[IMClientManager sharedInstance] getAlarmsProvider] addSingleChatMessageAlarm:self.remoteUserUid
                                                                                friendName:remoteNick
                                                                        withConcentForShow:messageContentForShow
                                                                                 flagNumToAdd:0
                                                                                     withDate:nil
                                                                                withAlarmType:AMT_friendChatMessage
                                                                               fingerPrint:nil];
            return;
        }
    }
    
    // 创建通话记录元数据
    VoipRecordMeta *vrm = [VoipRecordMeta initWith:voipType recordType:recordType duration:duration];
    
    // ★ 生成消息指纹码，用于去重和服务端持久化
    NSString *fingerPrint = [Protocal genFingerPrint];
    
    // 创建JSQMessage实体并放入聊天消息列表
    // ★ 设计目标：无论是谁挂断，聊天对话中的通话记录气泡都应视为“拨打方发送”的一条记录。
    //   因此，仅由主叫方负责在本地写入聊天消息并发送 IM；被叫方只接收主叫方发来的记录。
    if (self.isCaller) {
        JSQMessage *entity = [JSQMessage createChatMsgEntity_OUTGO_VOIPRECORD:vrm];
        entity.fingerPrintOfProtocal = fingerPrint;
        [ChatDataHelper addChatMessageData_outgoing:self.remoteUserUid withData:entity];
        [CallManager rb_markPendingScrollToBottomForChatUid:self.remoteUserUid];
        [[NSNotificationCenter defaultCenter] postNotificationName:[CallManager rb_notificationNameVoipRecordAppended]
                                                            object:nil
                                                          userInfo:@{ @"uid" : self.remoteUserUid ?: @"" }];
        [self sendVoipRecordToServer:vrm fingerPrint:fingerPrint];
    } else {
        if (![self hasRecentVoipRecordForPeer:self.remoteUserUid recordType:recordType withinSeconds:5.0]) {
            NSString *nick = self.remoteUserNickname ?: self.remoteUserUid;
            JSQMessage *entity = [JSQMessage createChatMsgEntity_INCOME_VOIPRECORD:nick withContent:vrm andTime:[NSDate date] senderId:self.remoteUserUid];
            entity.fingerPrintOfProtocal = fingerPrint;
            [[[IMClientManager sharedInstance] getMessagesProvider] putMessage:self.remoteUserUid withData:entity];
            [CallManager rb_markPendingScrollToBottomForChatUid:self.remoteUserUid];
            [[NSNotificationCenter defaultCenter] postNotificationName:[CallManager rb_notificationNameVoipRecordAppended]
                                                                object:nil
                                                              userInfo:@{ @"uid" : self.remoteUserUid ?: @"" }];
        }
    }
    
    NSString *typeStr = (voipType == VOIP_TYPE_VOICE) ? @"语音通话" : @"视频通话";
    NSString *content = @"";
    switch (recordType) {
        case VOIP_RECORD_TYPE_REQUEST_CANCEL:
            content = self.isCaller ? @"已取消" : @"对方已取消";
            break;
        case VOIP_RECORD_TYPE_REQUEST_REJECT:
            content = self.isCaller ? @"对方已拒绝" : @"已拒绝";
            break;
        case VOIP_RECORD_TYPE_CALLING_TIMEOUT:
            content = self.isCaller ? @"对方无应答" : @"未接听";
            break;
        case VOIP_RECORD_TYPE_CHATTING_DURATION:
            if (duration > 0) {
                int mins = duration / 60;
                int secs = duration % 60;
                content = [NSString stringWithFormat:@"通话时长 %02d:%02d", mins, secs];
            } else {
                content = @"通话已结束";
            }
            break;
    }
    NSString *messageContentForShow = [NSString stringWithFormat:@"%@ · %@", typeStr, content];
    
    // 更新首页"消息"列表显示
    NSString *remoteNick = self.remoteUserNickname ?: self.remoteUserUid;
    [[[IMClientManager sharedInstance] getAlarmsProvider] addSingleChatMessageAlarm:self.remoteUserUid
                                                                        friendName:remoteNick
                                                                withConcentForShow:messageContentForShow
                                                                     flagNumToAdd:0
                                                                         withDate:nil
                                                                    withAlarmType:AMT_friendChatMessage
                                                                   fingerPrint:nil];
    
    NSLog(@"【CallManager】通话记录已保存：%@（fingerPrint=%@）", messageContentForShow, fingerPrint);
}

#pragma mark - 发送通话记录到服务端

/// 主叫方将通话记录作为 TM_TYPE_VOIP_RECORD 类型的 IM 消息发送给被叫方
/// 这样服务端能存储通话记录，多端同步和消息漫游时也能看到
/// ★ 注意：使用低级 API 发送，不触发 AlarmsProvider 更新（saveCallRecordWithRecordType: 已处理过）
- (void)sendVoipRecordToServer:(VoipRecordMeta *)vrm fingerPrint:(NSString *)fingerPrint
{
    if (self.remoteUserUid == nil || vrm == nil) return;
    
    NSString *jsonContent = [EVAToolKits toJSON:vrm];
    if (jsonContent == nil || jsonContent.length == 0) {
        NSLog(@"【CallManager】VoIP 记录 JSON 序列化失败，无法发送到服务端。");
        return;
    }
    
    NSString *remoteUid = [self.remoteUserUid copy];
    
    NSLog(@"【CallManager】正在将通话记录发送到服务端... remoteUid=%@, fp=%@", remoteUid, fingerPrint);
    
    // 在后台线程构建消息体并发送（低级 API，不会触发 AlarmsProvider 更新）
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *localUid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
        MsgBody4Friend *msgBody = [MsgBody4Friend constructFriendChatMsgBody:localUid t:remoteUid m:jsonContent ty:TM_TYPE_VOIP_RECORD];
        int code = [MessageHelper sendChatMessage:remoteUid withMessage:msgBody finger:fingerPrint];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (code == COMMON_CODE_OK) {
                NSLog(@"【CallManager】✅ 通话记录已成功发送到服务端，fp=%@", fingerPrint);
            } else {
                NSLog(@"【CallManager】❌ 通话记录发送到服务端失败，code=%d, fp=%@", code, fingerPrint);
            }
        });
    });
}

#pragma mark - 声网频道管理（Token鉴权）

/// 异步请求服务端Token并加入声网频道，失败时降级为无Token模式加入
- (void)requestTokenAndJoinChannel
{
    // ⚠️ 不要在此处设置 AgoraManager.delegate！
    // delegate 由 CallViewController 统一管理（否则会覆盖 CallViewController 的 delegate，
    // 导致 didJoinedOfUid/firstRemoteVideoDecoded 等回调无法到达 CallViewController，远端视频无法渲染）
    // Token 刷新回调由 CallViewController 转发给 CallManager.refreshTokenIfNeeded
    //
    // 不在此处 initialize / enableVideo：Token 回调里会 ensureEngineWithAppId（服务端 app_id），避免与本地 AGORA_APP_ID 不一致导致 join 失败。

    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    NSString *remoteUid = self.remoteUserUid;
    
    NSLog(@"【CallManager】正在向服务端请求声网Token... localUid=%@, remoteUid=%@", localUid, remoteUid);
    
    // 异步请求服务端 Agora Token（接口 1008-1-35）
    [[HttpRestHelper sharedInstance] requestAgoraToken:localUid calleeUid:remoteUid complete:^(BOOL success, NSString *token, NSString *channelName, NSString *appId, NSUInteger agoraUid) {
        
        // 如果在等待 Token 期间用户已挂断，不再加入频道
        if (self.currentState == CallStateIdle) {
            NSLog(@"【CallManager】Token返回时通话已结束，不再加入频道。");
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[CallSoundManager sharedInstance] stopAll];
            
            if (success && token != nil && token.length > 0) {
                NSLog(@"【CallManager】✅ Token获取成功！channelName=%@, agoraUid=%lu", channelName, (unsigned long)agoraUid);
                
                // 必须用服务端签发 Token 时使用的 AppId 创建引擎，否则 joinChannel 会失败（如返回 -17）
                [[AgoraManager sharedInstance] ensureEngineWithAppId:appId];
                
                if (self.currentCallType == CallTypeVideo) {
                    [[AgoraManager sharedInstance] enableVideo:YES];
                } else {
                    [[AgoraManager sharedInstance] enableVideo:NO];
                }
                
                [[AgoraManager sharedInstance] joinChannel:channelName uid:agoraUid token:token];
                
            } else {
                NSLog(@"【CallManager】⚠️ Token获取失败，降级为无Token模式加入频道。");
                
                [[AgoraManager sharedInstance] ensureEngineWithAppId:nil];
                
                NSString *fallbackChannelName = [AgoraManager generateChannelNameWithLocalUid:localUid remoteUid:remoteUid];
                NSUInteger fallbackAgoraUid = (NSUInteger)[localUid integerValue];
                
                NSLog(@"【CallManager】降级加入声网频道：%@，agoraUid=%lu", fallbackChannelName, (unsigned long)fallbackAgoraUid);
                
                if (self.currentCallType == CallTypeVideo) {
                    [[AgoraManager sharedInstance] enableVideo:YES];
                } else {
                    [[AgoraManager sharedInstance] enableVideo:NO];
                }
                
                [[AgoraManager sharedInstance] joinChannel:fallbackChannelName uid:fallbackAgoraUid token:nil];
            }
        });
    }];
}

- (void)retryJoinChannel
{
    if (self.currentState != CallStateConnected && self.currentState != CallStateOutgoingCalling && self.currentState != CallStateIncomingCalling) {
        NSLog(@"【CallManager】retryJoinChannel 忽略：当前状态非通话中。");
        return;
    }
    NSLog(@"【CallManager】重试加入声网频道...");
    [self requestTokenAndJoinChannel];
}

#pragma mark - Token 刷新（由 CallViewController 转发调用）

/// Token 即将过期时，向服务端请求新 Token 续期（由 CallViewController 的 agoraManagerTokenWillExpire 转发调用）
- (void)refreshTokenIfNeeded
{
    NSLog(@"【CallManager】收到 Token 即将过期回调，正在请求新 Token...");
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    NSString *remoteUid = self.remoteUserUid;
    
    if (localUid == nil || remoteUid == nil) {
        NSLog(@"【CallManager】Token刷新失败：localUid 或 remoteUid 为空。");
        return;
    }
    
    [[HttpRestHelper sharedInstance] requestAgoraToken:localUid calleeUid:remoteUid complete:^(BOOL success, NSString *token, NSString *channelName, NSString *appId, NSUInteger agoraUid) {
        if (success && token != nil && token.length > 0) {
            NSLog(@"【CallManager】Token刷新成功，正在续期...");
            [[AgoraManager sharedInstance] renewToken:token];
        } else {
            NSLog(@"【CallManager】Token刷新失败！通话可能在Token过期后断开。");
        }
    }];
}

#pragma mark - 超时定时器

- (void)startCallTimeoutTimer
{
    [self stopCallTimeoutTimer];
    __weak typeof(self) wself = self;
    self.callTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:VOIP_CALL_TIMEOUT_SECONDS repeats:NO block:^(NSTimer * _Nonnull timer) {
        [wself callTimeoutFired:timer];
    }];
}

- (void)stopCallTimeoutTimer
{
    if (self.callTimeoutTimer) {
        [self.callTimeoutTimer invalidate];
        self.callTimeoutTimer = nil;
    }
}

- (void)callTimeoutFired:(NSTimer *)timer
{
    if (self.currentState == CallStateOutgoingCalling) {
        NSLog(@"【CallManager】呼叫超时（%d秒），自动取消呼叫。", VOIP_CALL_TIMEOUT_SECONDS);
        
        NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        
        // 发送取消呼叫信令（不通过 cancelCall 以避免保存重复的 CANCEL 记录）
        if (self.currentCallType == CallTypeVideo) {
            [MessageHelper sendVideoAndVoiceRequest_Abort_from_a:self.remoteUserUid local:localUid];
        } else {
            [SendDataHelper sendMessageImpl:self.remoteUserUid
                                withMessage:localUid
                                        qos:YES
                                   andTypeu:MT32_OF_REAL_TIME_VOICE_REQUEST_ABRORT_FROM_A];
        }
        
        // 保存通话记录：呼叫超时（不是"已取消"）
        [self saveCallRecordWithRecordType:VOIP_RECORD_TYPE_CALLING_TIMEOUT];
        
        [self reset];
        
        if ([self.delegate respondsToSelector:@selector(callManagerDidTimeout:)]) {
            [self.delegate callManagerDidTimeout:self];
        }
    }
}

#pragma mark - 状态管理

- (void)changeState:(CallState)newState
{
    CallState oldState = self.currentState;
    self.currentState = newState;
    
    NSLog(@"【CallManager】通话状态变更：%@ → %@", [self stateDescription:oldState], [self stateDescription:newState]);
    
    // ========== 同步状态到 CallKit ==========
    if (newState == CallStateConnected) {
        [[CallKitManager sharedInstance] reportCallConnected];
        // 视频接通时统一准备 PiP（兜底：避免仅 acceptCall/onRemoteAccepted 未跑到的路径漏掉）
        if (self.currentCallType == CallTypeVideo) {
            [[CallPiPManager sharedInstance] preparePiPForVideoCall];
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(callManager:didChangeState:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate callManager:self didChangeState:newState];
        });
    }
}

- (NSString *)stateDescription:(CallState)state
{
    switch (state) {
        case CallStateIdle:              return @"空闲";
        case CallStateOutgoingCalling:   return @"呼出中";
        case CallStateIncomingCalling:   return @"来电中";
        case CallStateConnected:         return @"通话中";
    }
}

#pragma mark - 工具

- (BOOL)isInCall
{
    return self.currentState != CallStateIdle;
}

- (NSInteger)getCallDuration
{
    if (self.callConnectedTime == nil) {
        return 0;
    }
    return (NSInteger)[[NSDate date] timeIntervalSinceDate:self.callConnectedTime];
}

- (void)reset
{
    [self stopCallTimeoutTimer];
    
    // 离开声网频道（如果在频道中）
    if ([AgoraManager sharedInstance].isInChannel) {
        [[AgoraManager sharedInstance] leaveChannel];
    }
    
    // ========== 通知 CallKit 通话已结束 ==========
    if ([CallKitManager sharedInstance].currentCallUUID != nil) {
        [[CallKitManager sharedInstance] reportCallEnded:CXCallEndedReasonRemoteEnded];
    }
    
    self.currentState = CallStateIdle;
    self.remoteUserUid = nil;
    self.remoteUserNickname = nil;
    self.callConnectedTime = nil;
    self.isCaller = NO;

    [[CallPiPManager sharedInstance] stopPiP];

    NSLog(@"【CallManager】已重置到空闲状态。");
}

@end
