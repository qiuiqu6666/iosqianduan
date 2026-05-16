//
//  AgoraManager.m
//  RainbowChat4i
//
//  声网(Agora) RTC引擎封装管理器实现。
//

#import "AgoraManager.h"
#import "Default.h"

NSNotificationName const RBAgoraEngineDidRebuildNotification = @"com.rbchat.notification.agoraEngineDidRebuild";

@interface AgoraManager () <AgoraRtcEngineDelegate>

@property (nonatomic, strong, readwrite) AgoraRtcEngineKit *agoraKit;
@property (nonatomic, assign, readwrite) BOOL isInitialized;
@property (nonatomic, assign, readwrite) BOOL isInChannel;
@property (nonatomic, assign, readwrite) NSUInteger lastRemoteUid;
@property (nonatomic, copy, nullable) NSString *activeAppId;

@end

@implementation AgoraManager

#pragma mark - 单例

+ (instancetype)sharedInstance
{
    static AgoraManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AgoraManager alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _isInitialized = NO;
        _isInChannel = NO;
    }
    return self;
}

#pragma mark - 引擎生命周期

- (void)initialize
{
    [self initializeWithAppId:AGORA_APP_ID];
}

- (void)initializeWithAppId:(NSString *)appId
{
    [self ensureEngineWithAppId:appId];
}

/// 创建引擎后的通用配置（频道模式、音频等）
- (void)rb_configureEngineDefaults
{
    if (self.agoraKit == nil) {
        return;
    }
    [self.agoraKit setChannelProfile:AgoraChannelProfileCommunication];
    [self.agoraKit enableAudio];
    [self.agoraKit setAudioProfile:AgoraAudioProfileDefault
                          scenario:AgoraAudioScenarioDefault];
}

- (void)ensureEngineWithAppId:(NSString *)appId
{
    NSString *resolved = (appId != nil && appId.length > 0) ? [appId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : AGORA_APP_ID;
    if (resolved.length == 0 || [resolved isEqualToString:@"YOUR_AGORA_APP_ID"]) {
        NSLog(@"【AgoraManager】错误：AppId 无效，请配置 Default.h 的 AGORA_APP_ID 或确保服务端 Token 接口返回 app_id");
        return;
    }

    BOOL sameAsCurrent = (self.agoraKit != nil && self.activeAppId != nil && [self.activeAppId isEqualToString:resolved]);
    if (sameAsCurrent) {
        self.isInitialized = YES;
        return;
    }

    BOOL replacingExisting = (self.agoraKit != nil);
    if (replacingExisting) {
        if (self.isInChannel) {
            [self leaveChannel];
        }
        [AgoraRtcEngineKit destroy];
        self.agoraKit = nil;
        self.isInitialized = NO;
        self.activeAppId = nil;
        self.lastRemoteUid = 0;
        NSLog(@"【AgoraManager】已销毁旧引擎（AppId 与 Token 签发应用不一致时需切换，否则 joinChannel 易失败如错误码 -17）");
    }

    self.agoraKit = [AgoraRtcEngineKit sharedEngineWithAppId:resolved delegate:self];
    if (self.agoraKit != nil) {
        self.activeAppId = [resolved copy];
        self.isInitialized = YES;
        [self rb_configureEngineDefaults];
        NSLog(@"【AgoraManager】声网引擎就绪 AppId=%@***", [resolved substringToIndex:MIN(8, resolved.length)]);
        if (replacingExisting) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RBAgoraEngineDidRebuildNotification object:self];
            });
        }
    } else {
        self.isInitialized = NO;
        self.activeAppId = nil;
        NSLog(@"【AgoraManager】声网引擎创建失败！");
    }
}

- (void)destroy
{
    if (self.isInChannel) {
        [self leaveChannel];
    }
    
    if (self.agoraKit != nil) {
        [AgoraRtcEngineKit destroy];
        self.agoraKit = nil;
    }
    
    self.isInitialized = NO;
    self.activeAppId = nil;
    NSLog(@"【AgoraManager】声网引擎已销毁。");
}

#pragma mark - 频道操作

- (void)joinChannel:(NSString *)channelName uid:(NSUInteger)uid token:(NSString *)token
{
    if (!self.isInitialized) {
        NSLog(@"【AgoraManager】错误：引擎尚未初始化，无法加入频道！");
        return;
    }
    
    if (self.isInChannel) {
        NSLog(@"【AgoraManager】当前已在频道中，先离开再加入新频道。");
        [self leaveChannel];
    }
    
    NSLog(@"【AgoraManager】正在加入频道：%@，uid=%lu，token=%@", channelName, (unsigned long)uid, (token ? @"有Token" : @"无Token"));
    
    int result = [self.agoraKit joinChannelByToken:token
                                         channelId:channelName
                                              info:nil
                                               uid:uid
                                       joinSuccess:^(NSString * _Nonnull channel, NSUInteger uid, NSInteger elapsed) {
        NSLog(@"【AgoraManager】✅ 成功加入频道：%@，uid=%lu，耗时=%ldms", channel, (unsigned long)uid, (long)elapsed);
        self.isInChannel = YES;
        
        if ([self.delegate respondsToSelector:@selector(agoraManager:didJoinChannel:withUid:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate agoraManager:self didJoinChannel:channel withUid:uid];
            });
        }
    }];
    
    if (result != 0) {
        NSLog(@"【AgoraManager】❌ joinChannelByToken 调用失败！错误码=%d（常见：Token 与引擎 AppId 不一致、频道名/uid 不匹配、或无效 Token；请确认服务端返回的 app_id 与 ensureEngineWithAppId 一致）", result);
        // 通知代理发生错误
        if ([self.delegate respondsToSelector:@selector(agoraManager:didOccurError:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate agoraManager:self didOccurError:result];
            });
        }
    }
}

- (void)leaveChannel
{
    if (!self.isInChannel) {
        return;
    }
    
    [self.agoraKit leaveChannel:^(AgoraChannelStats * _Nonnull stat) {
        NSLog(@"【AgoraManager】已离开频道，通话时长=%ld秒", (long)stat.duration);
    }];
    
    self.isInChannel = NO;
}

#pragma mark - 音视频控制

- (void)enableVideo:(BOOL)enable
{
    if (!self.isInitialized) return;
    
    if (enable) {
        [self.agoraKit enableVideo];
        NSLog(@"【AgoraManager】视频模块已启用。");
    } else {
        [self.agoraKit disableVideo];
        NSLog(@"【AgoraManager】视频模块已禁用。");
    }
}

- (void)muteLocalAudio:(BOOL)mute
{
    if (!self.isInitialized) return;
    [self.agoraKit muteLocalAudioStream:mute];
    NSLog(@"【AgoraManager】本地音频%@。", mute ? @"已静音" : @"已取消静音");
}

- (void)muteLocalVideo:(BOOL)mute
{
    if (!self.isInitialized) return;
    [self.agoraKit muteLocalVideoStream:mute];
    NSLog(@"【AgoraManager】本地视频%@。", mute ? @"已关闭" : @"已开启");
}

- (void)switchCamera
{
    if (!self.isInitialized) return;
    [self.agoraKit switchCamera];
    NSLog(@"【AgoraManager】已切换摄像头。");
}

- (void)setupLocalVideoView:(UIView *)view
{
    if (!self.isInitialized) return;
    
    AgoraRtcVideoCanvas *canvas = [[AgoraRtcVideoCanvas alloc] init];
    canvas.view = view;
    canvas.renderMode = AgoraVideoRenderModeHidden;
    canvas.uid = 0; // 0 代表本地用户
    [self.agoraKit setupLocalVideo:canvas];
    
    if (view != nil) {
        [self.agoraKit startPreview];
    } else {
        [self.agoraKit stopPreview];
    }
}

- (void)setupRemoteVideoView:(UIView *)view forUid:(NSUInteger)uid
{
    if (!self.isInitialized) return;
    
    AgoraRtcVideoCanvas *canvas = [[AgoraRtcVideoCanvas alloc] init];
    canvas.view = view;
    canvas.renderMode = AgoraVideoRenderModeHidden;
    canvas.uid = uid;
    [self.agoraKit setupRemoteVideo:canvas];
}

- (void)setEnableSpeakerphone:(BOOL)enable
{
    if (!self.isInitialized) return;
    [self.agoraKit setEnableSpeakerphone:enable];
    NSLog(@"【AgoraManager】扬声器%@。", enable ? @"已开启" : @"已关闭");
}

- (void)renewToken:(NSString *)token
{
    if (!self.isInitialized || self.agoraKit == nil) {
        NSLog(@"【AgoraManager】renewToken 失败：引擎未初始化。");
        return;
    }
    if (token == nil || token.length == 0) {
        NSLog(@"【AgoraManager】renewToken 失败：token 为空。");
        return;
    }
    int ret = [self.agoraKit renewToken:token];
    NSLog(@"【AgoraManager】renewToken 结果：%d（0=成功）", ret);
}

- (void)setPipVideoFrameDelegate:(id<AgoraVideoFrameDelegate>)delegate
{
    [self.agoraKit setVideoFrameDelegate:delegate];
}

#pragma mark - AgoraRtcEngineDelegate

/// 远端用户加入频道回调
- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinedOfUid:(NSUInteger)uid elapsed:(NSInteger)elapsed
{
    NSLog(@"【AgoraManager】远端用户加入频道：uid=%lu，耗时=%ldms", (unsigned long)uid, (long)elapsed);
    
    // 记录远端用户UID（用于浮窗恢复视频渲染）
    self.lastRemoteUid = uid;
    
    if ([self.delegate respondsToSelector:@selector(agoraManager:didJoinedOfUid:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate agoraManager:self didJoinedOfUid:uid];
        });
    }
}

/// 远端用户离开频道回调
- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOfflineOfUid:(NSUInteger)uid reason:(AgoraUserOfflineReason)reason
{
    NSLog(@"【AgoraManager】远端用户离开频道：uid=%lu，原因=%ld", (unsigned long)uid, (long)reason);
    
    if ([self.delegate respondsToSelector:@selector(agoraManager:didOfflineOfUid:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate agoraManager:self didOfflineOfUid:uid];
        });
    }
}

/// 发生错误回调
- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOccurError:(AgoraErrorCode)errorCode
{
    NSLog(@"【AgoraManager】声网引擎错误：errorCode=%ld", (long)errorCode);
    
    if ([self.delegate respondsToSelector:@selector(agoraManager:didOccurError:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate agoraManager:self didOccurError:errorCode];
        });
    }
}

/// 远端首帧视频已解码回调
- (void)rtcEngine:(AgoraRtcEngineKit *)engine firstRemoteVideoDecodedOfUid:(NSUInteger)uid size:(CGSize)size elapsed:(NSInteger)elapsed
{
    NSLog(@"【AgoraManager】远端首帧视频已解码：uid=%lu", (unsigned long)uid);
    
    if ([self.delegate respondsToSelector:@selector(agoraManager:firstRemoteVideoDecodedOfUid:size:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate agoraManager:self firstRemoteVideoDecodedOfUid:uid size:size];
        });
    }
}

/// Token即将过期回调（声网SDK会在Token过期前30秒触发此回调）
- (void)rtcEngine:(AgoraRtcEngineKit *)engine tokenPrivilegeWillExpire:(NSString *)token
{
    NSLog(@"【AgoraManager】Token即将过期，需要刷新！");
    
    if ([self.delegate respondsToSelector:@selector(agoraManagerTokenWillExpire:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate agoraManagerTokenWillExpire:self];
        });
    }
}

#pragma mark - 工具方法

+ (NSString *)generateChannelNameWithLocalUid:(NSString *)localUid remoteUid:(NSString *)remoteUid
{
    // 双方UID排序后拼接，确保双方生成相同的频道名
    NSString *first = nil;
    NSString *second = nil;
    if ([localUid compare:remoteUid options:NSNumericSearch] == NSOrderedAscending) {
        first = localUid;
        second = remoteUid;
    } else {
        first = remoteUid;
        second = localUid;
    }
    return [NSString stringWithFormat:@"call_%@_%@", first, second];
}

@end
