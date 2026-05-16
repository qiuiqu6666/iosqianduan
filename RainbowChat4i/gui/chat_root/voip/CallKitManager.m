//
//  CallKitManager.m
//  RainbowChat4i
//
//  PushKit + CallKit 管理器实现。
//

#import "CallKitManager.h"
#import "CallManager.h"
#import "CallViewController.h"
#import "ViewControllerFactory.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "UserDefaultsToolKits.h"
#import "AgoraManager.h"

@interface CallKitManager ()

/// PushKit 注册表
@property (nonatomic, strong) PKPushRegistry *voipRegistry;

/// CallKit 提供者
@property (nonatomic, strong) CXProvider *callProvider;

/// P2-2：复用同一份配置，报告来电时仅更新 ringtoneSound
@property (nonatomic, strong) CXProviderConfiguration *providerConfiguration;

/// CallKit 呼叫控制器
@property (nonatomic, strong) CXCallController *callController;

/// 暂存的 VoIP Push 来电信息
@property (nonatomic, strong, nullable) NSDictionary *pendingCallPayload;

/// 标记：用户是否已通过 CallKit 接听（防止重复弹出 CallViewController）
@property (nonatomic, assign) BOOL hasAnsweredViaCallKit;

@end

@implementation CallKitManager

#pragma mark - 单例

+ (instancetype)sharedInstance
{
    static CallKitManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CallKitManager alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _hasAnsweredViaCallKit = NO;
    }
    return self;
}

#pragma mark - 初始化

- (void)setupCallKit
{
    CXProviderConfiguration *config = [[CXProviderConfiguration alloc] init];
    config.supportsVideo = YES;
    config.maximumCallsPerCallGroup = 1;
    config.supportedHandleTypes = [NSSet setWithObject:@(CXHandleTypeGeneric)];
    self.providerConfiguration = config;
    
    self.callProvider = [[CXProvider alloc] initWithConfiguration:config];
    [self.callProvider setDelegate:self queue:dispatch_get_main_queue()];
    
    self.callController = [[CXCallController alloc] init];
    
    NSLog(@"【CallKitManager】CallKit 已初始化。");
}

- (void)registerVoIPPush
{
    self.voipRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    self.voipRegistry.delegate = self;
    self.voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    
    NSLog(@"【CallKitManager】PushKit VoIP 注册已启动。");
}

#pragma mark - PKPushRegistryDelegate

/// 获取到 VoIP Token
- (void)pushRegistry:(PKPushRegistry *)registry
didUpdatePushCredentials:(PKPushCredentials *)pushCredentials
              forType:(PKPushType)type
{
    if (![type isEqualToString:PKPushTypeVoIP]) return;
    
    // 将 NSData 转为十六进制字符串
    NSData *tokenData = pushCredentials.token;
    NSMutableString *tokenString = [NSMutableString stringWithCapacity:tokenData.length * 2];
    const unsigned char *bytes = tokenData.bytes;
    for (NSUInteger i = 0; i < tokenData.length; i++) {
        [tokenString appendFormat:@"%02x", bytes[i]];
    }
    
    NSLog(@"【CallKitManager】获取到 VoIP Token: %@", tokenString);
    
    // 缓存 Token
    self.cachedVoIPToken = [tokenString copy];
    
    // 保存到 NSUserDefaults 以备后用
    [[NSUserDefaults standardUserDefaults] setObject:self.cachedVoIPToken forKey:@"voip_push_token"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 如果已登录，立即上传
    [self uploadCachedVoIPTokenIfNeeded];
}

/// VoIP Token 失效
- (void)pushRegistry:(PKPushRegistry *)registry
didInvalidatePushTokenForType:(PKPushType)type
{
    NSLog(@"【CallKitManager】VoIP Token 已失效。");
    self.cachedVoIPToken = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"voip_push_token"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/// ⭐ 核心回调：收到 VoIP Push
- (void)pushRegistry:(PKPushRegistry *)registry
didReceiveIncomingPushWithPayload:(PKPushPayload *)payload
              forType:(PKPushType)type
withCompletionHandler:(void (^)(void))completion
{
    if (![type isEqualToString:PKPushTypeVoIP]) {
        completion();
        return;
    }
    
    NSDictionary *data = payload.dictionaryPayload;
    NSLog(@"【CallKitManager】收到 VoIP Push: %@", data);
    
    // 解析 Payload
    NSString *callerUid  = data[@"caller_uid"] ?: @"Unknown";
    NSString *callerName = data[@"caller_name"] ?: @"Unknown";
    NSString *callType   = data[@"call_type"] ?: @"voice";
    NSNumber *timestamp  = data[@"timestamp"];
    
    // 检查来电是否过期（60 秒）
    if (timestamp != nil) {
        NSTimeInterval pushTime = [timestamp doubleValue] / 1000.0;
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (now - pushTime > 60) {
            NSLog(@"【CallKitManager】VoIP Push 来电已过期（超过60秒），忽略。");
            // iOS 13+ 必须调用 reportNewIncomingCall，即使要拒绝
            [self reportAndImmediatelyEndExpiredCallWithCompletion:completion];
            return;
        }
    }
    
    // 暂存来电信息
    self.pendingCallPayload = @{
        @"caller_uid": callerUid,
        @"caller_name": callerName,
        @"call_type": callType
    };
    self.hasAnsweredViaCallKit = NO;
    
    // ⚠️ iOS 13+ 强制要求：必须在此回调中调用 reportNewIncomingCall，否则 App 会被系统终止！
    [self reportIncomingCall:callerUid
                 callerName:callerName
                   callType:callType
                 completion:^(NSError *error) {
        if (error) {
            NSLog(@"【CallKitManager】报告来电失败: %@", error.localizedDescription);
        } else {
            NSLog(@"【CallKitManager】CallKit 来电界面已显示: %@ (%@)", callerName, callType);
        }
        completion();
    }];
}

/// 辅助方法：对已过期的 VoIP Push，先报告来电再立即结束（满足 iOS 13+ 的强制要求）
- (void)reportAndImmediatelyEndExpiredCallWithCompletion:(void (^)(void))completion
{
    NSUUID *expiredUUID = [NSUUID UUID];
    CXCallUpdate *update = [[CXCallUpdate alloc] init];
    update.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"expired"];
    update.localizedCallerName = @"已过期的来电";
    update.hasVideo = NO;
    
    [self.callProvider reportNewIncomingCallWithUUID:expiredUUID
                                             update:update
                                         completion:^(NSError * _Nullable error) {
        // 立即结束这个"假来电"
        [self.callProvider reportCallWithUUID:expiredUUID
                                  endedAtDate:[NSDate date]
                                       reason:CXCallEndedReasonUnanswered];
        completion();
    }];
}

#pragma mark - CXProviderDelegate

/// 用户点击"接听"
- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action
{
    NSLog(@"【CallKitManager】用户通过 CallKit 接听来电。");
    
    // ★ Guard 1: 如果通话已接通（用户已通过 in-app UI 接听），直接 fulfill
    CallState currentState = [CallManager sharedInstance].currentState;
    if (currentState == CallStateConnected) {
        NSLog(@"【CallKitManager】通话已接通（in-app 先接听），直接 fulfill。");
        self.hasAnsweredViaCallKit = YES;
        [action fulfill];
        return;
    }
    
    // 获取来电信息：优先从 pendingCallPayload，fallback 到 CallManager
    NSDictionary *callInfo = self.pendingCallPayload;
    if (!callInfo) {
        NSLog(@"【CallKitManager】pendingCallPayload 为空，尝试从 CallManager 获取来电信息...");
        if (currentState == CallStateIncomingCalling &&
            [CallManager sharedInstance].remoteUserUid != nil) {
            callInfo = @{
                @"caller_uid": [CallManager sharedInstance].remoteUserUid,
                @"caller_name": [CallManager sharedInstance].remoteUserNickname ?: @"Unknown",
                @"call_type": ([CallManager sharedInstance].currentCallType == CallTypeVideo) ? @"video" : @"voice"
            };
        } else {
            NSLog(@"【CallKitManager】无法获取来电信息，接听失败。");
            [action fail];
            return;
        }
    }
    
    NSString *callerUid  = callInfo[@"caller_uid"];
    NSString *callerName = callInfo[@"caller_name"];
    NSString *callTypeStr = callInfo[@"call_type"];
    BOOL isVideo = [callTypeStr isEqualToString:@"video"];
    CallType callType = isVideo ? CallTypeVideo : CallTypeVoice;
    
    self.hasAnsweredViaCallKit = YES;
    
    // 1. 通知 CallManager 设置来电状态（如果还未设置，例如 VoIP Push 场景）
    if (currentState == CallStateIdle) {
        [[CallManager sharedInstance] onIncomingCall:callerUid
                                      remoteNickname:callerName
                                            callType:callType];
    }
    
    // 2. ★ 先同步弹出 CallViewController（确保 delegate 在 acceptCall 之前设置好）
    //    performAnswerCallAction 已在主线程执行（CXProvider delegate queue = main），可同步调用
    if ([CallManager sharedInstance].delegate == nil) {
        [ViewControllerFactory goCallViewController:callerUid
                                 remoteUserNickname:callerName
                                           callType:callType
                                           isCaller:NO];
    } else {
        NSLog(@"【CallKitManager】CallViewController 已显示，跳过重复弹出。");
    }
    
    // 3. ★ 延迟到下一个 run loop 再 acceptCall，确保 CallViewController.viewDidLoad 已完成
    //    （delegate 和视频视图已就绪，Agora 回调不会丢失）
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([CallManager sharedInstance].currentState == CallStateIncomingCalling) {
            [[CallManager sharedInstance] acceptCall];
        }
    });
    
    self.pendingCallPayload = nil;
    
    [action fulfill];
}

/// 用户点击"拒接" 或 通话结束
- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action
{
    NSLog(@"【CallKitManager】用户通过 CallKit 结束/拒接来电。");
    
    // ★ 先清除 UUID 和暂存数据，这样 CallManager.reset() 内部调用 reportCallEnded 时
    // 发现 currentCallUUID == nil 会直接 return，不会重复向 CallKit 报告结束
    self.currentCallUUID = nil;
    self.pendingCallPayload = nil;
    self.hasAnsweredViaCallKit = NO;
    
    CallState currentState = [CallManager sharedInstance].currentState;
    
    if (currentState == CallStateIncomingCalling) {
        [[CallManager sharedInstance] rejectCall];
    } else if (currentState == CallStateConnected) {
        [[CallManager sharedInstance] hangupCall];
    } else if (currentState == CallStateOutgoingCalling) {
        [[CallManager sharedInstance] cancelCall];
    }
    
    // 如果 CallViewController 还在显示，关闭它
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *topVC = [ViewControllerFactory topMostViewController];
        if ([topVC isKindOfClass:[CallViewController class]]) {
            [topVC dismissViewControllerAnimated:YES completion:nil];
        } else if (topVC.navigationController) {
            for (UIViewController *vc in topVC.navigationController.viewControllers) {
                if ([vc isKindOfClass:[CallViewController class]]) {
                    [topVC.navigationController popToViewController:vc animated:NO];
                    [topVC.navigationController popViewControllerAnimated:YES];
                    break;
                }
            }
        }
    });
    
    [action fulfill];
}

/// 用户通过 CallKit 切换静音
- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action
{
    NSLog(@"【CallKitManager】CallKit 静音切换: muted=%d", action.isMuted);
    [[AgoraManager sharedInstance] muteLocalAudio:action.isMuted];
    [action fulfill];
}

/// CXProvider 被重置
- (void)providerDidReset:(CXProvider *)provider
{
    NSLog(@"【CallKitManager】CXProvider 已重置。");
    
    // 先清除 UUID（与 performEndCallAction 同理，避免 reset 内重复 reportCallEnded）
    self.currentCallUUID = nil;
    self.pendingCallPayload = nil;
    self.hasAnsweredViaCallKit = NO;
    
    // 清理所有通话状态
    if ([CallManager sharedInstance].currentState != CallStateIdle) {
        [[CallManager sharedInstance] reset];
    }
}

/// 来电音频会话已激活（CallKit 会自动管理音频会话）
- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession
{
    NSLog(@"【CallKitManager】CallKit 音频会话已激活。");
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession
{
    NSLog(@"【CallKitManager】CallKit 音频会话已停用。");
}

#pragma mark - CallKit 报告

- (void)reportIncomingCall:(NSString *)callerUid
                callerName:(NSString *)callerName
                  callType:(NSString *)callType
                completion:(void (^ _Nullable)(NSError * _Nullable error))completion
{
    NSUUID *callUUID = [NSUUID UUID];
    self.currentCallUUID = callUUID;
    
    // ★ 关键修复：无论是 VoIP Push 还是在线 IM 来电，都保存来电信息
    // 这样 performAnswerCallAction 才能获取到来电方的 UID、昵称、通话类型
    self.pendingCallPayload = @{
        @"caller_uid": callerUid ?: @"Unknown",
        @"caller_name": callerName ?: @"Unknown",
        @"call_type": callType ?: @"voice"
    };
    self.hasAnsweredViaCallKit = NO;
    
    BOOL isVideo = [callType isEqualToString:@"video"];
    
    // 检查"语音和视频通话来电铃声"开关（默认开启）
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL ringtoneEnabled = ([ud objectForKey:@"APP_AUDIO_VIDEO_CALL_ENABLED"] == nil) ? YES : [ud boolForKey:@"APP_AUDIO_VIDEO_CALL_ENABLED"];
    
    // P2-2：复用同一份配置，仅按需更新 ringtoneSound
    if (!ringtoneEnabled) {
        self.providerConfiguration.ringtoneSound = @"silence";
    } else {
        self.providerConfiguration.ringtoneSound = nil;
    }
    [self.callProvider setConfiguration:self.providerConfiguration];
    
    CXCallUpdate *update = [[CXCallUpdate alloc] init];
    update.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:callerUid];
    update.localizedCallerName = callerName;
    update.hasVideo = isVideo;
    update.supportsGrouping = NO;
    update.supportsHolding = NO;
    update.supportsUngrouping = NO;
    update.supportsDTMF = NO;
    
    [self.callProvider reportNewIncomingCallWithUUID:callUUID
                                             update:update
                                         completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"【CallKitManager】reportNewIncomingCall 失败: %@", error.localizedDescription);
            self.currentCallUUID = nil;
        }
        if (completion) completion(error);
    }];
}

- (void)reportCallConnected
{
    if (self.currentCallUUID == nil) return;
    
    if (self.hasAnsweredViaCallKit) {
        // 已通过 CallKit "接听"按钮接听 → [action fulfill] 已告知 CallKit，无需重复
        NSLog(@"【CallKitManager】通话已通过 CallKit 接听，无需额外报告。");
        return;
    }
    
    // ★ 通过 in-app UI 接听 → 告知 CallKit "来电已在别处接听"，立即关闭 CallKit 来电界面
    NSLog(@"【CallKitManager】通过 in-app UI 接听，关闭 CallKit 来电界面（AnsweredElsewhere）...");
    [self.callProvider reportCallWithUUID:self.currentCallUUID
                              endedAtDate:[NSDate date]
                                   reason:CXCallEndedReasonAnsweredElsewhere];
    
    // 清除 UUID（后续 CallManager.reset 中的 reportCallEnded 不会重复操作）
    self.currentCallUUID = nil;
    self.pendingCallPayload = nil;
    self.hasAnsweredViaCallKit = NO;
}

- (void)reportCallEnded:(CXCallEndedReason)reason
{
    if (self.currentCallUUID == nil) return;
    
    NSLog(@"【CallKitManager】报告通话已结束: UUID=%@, reason=%ld", self.currentCallUUID, (long)reason);
    [self.callProvider reportCallWithUUID:self.currentCallUUID
                              endedAtDate:[NSDate date]
                                   reason:reason];
    
    self.currentCallUUID = nil;
    self.pendingCallPayload = nil;
    self.hasAnsweredViaCallKit = NO;
}

#pragma mark - VoIP Token 管理

- (void)uploadCachedVoIPTokenIfNeeded
{
    // 优先使用内存缓存，其次从 NSUserDefaults 读取
    NSString *token = self.cachedVoIPToken;
    if (token == nil || token.length == 0) {
        token = [[NSUserDefaults standardUserDefaults] stringForKey:@"voip_push_token"];
    }
    
    if (token == nil || token.length == 0) {
        NSLog(@"【CallKitManager】无可用的 VoIP Token，跳过上传。");
        return;
    }
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (localUid == nil || localUid.length == 0) {
        NSLog(@"【CallKitManager】用户未登录，跳过 VoIP Token 上传。");
        return;
    }
    
    NSLog(@"【CallKitManager】正在上传 VoIP Token... uid=%@, token长度=%lu", localUid, (unsigned long)token.length);
    
    [[HttpRestHelper sharedInstance] uploadVoIPToken:localUid voipToken:token complete:^(BOOL success) {
        if (success) {
            NSLog(@"【CallKitManager】VoIP Token 上传成功！");
        } else {
            NSLog(@"【CallKitManager】VoIP Token 上传失败。");
        }
    }];
}

@end
