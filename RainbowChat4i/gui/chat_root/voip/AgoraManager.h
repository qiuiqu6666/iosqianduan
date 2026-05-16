//
//  AgoraManager.h
//  RainbowChat4i
//
//  声网(Agora) RTC引擎封装管理器（单例）。
//  负责封装声网SDK的初始化、加入/离开频道、音视频控制等底层操作。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AgoraRtcKit/AgoraRtcEngineKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 声网引擎因 AppId 切换被销毁并重建后发出（需在通话页重新 bind 本地预览等）
FOUNDATION_EXPORT NSNotificationName const RBAgoraEngineDidRebuildNotification;

/// 声网引擎事件回调协议
@protocol AgoraManagerDelegate <NSObject>
@optional

/// 远端用户加入频道
- (void)agoraManager:(id)manager didJoinedOfUid:(NSUInteger)uid;

/// 远端用户离开频道
- (void)agoraManager:(id)manager didOfflineOfUid:(NSUInteger)uid;

/// 本地用户加入频道成功
- (void)agoraManager:(id)manager didJoinChannel:(NSString *)channel withUid:(NSUInteger)uid;

/// 发生错误
- (void)agoraManager:(id)manager didOccurError:(NSInteger)errorCode;

/// 远端首帧视频已渲染
- (void)agoraManager:(id)manager firstRemoteVideoDecodedOfUid:(NSUInteger)uid size:(CGSize)size;

/// 网络质量回调
- (void)agoraManager:(id)manager networkQuality:(NSUInteger)uid txQuality:(NSUInteger)txQuality rxQuality:(NSUInteger)rxQuality;

/// Token即将过期，需要刷新（由AgoraRtcEngineDelegate回调触发）
- (void)agoraManagerTokenWillExpire:(id)manager;

@end


@interface AgoraManager : NSObject

/// 单例
+ (instancetype)sharedInstance;

/// 事件回调代理
@property (nonatomic, weak, nullable) id<AgoraManagerDelegate> delegate;

/// 声网引擎实例（供外部直接访问高级功能时使用）
@property (nonatomic, strong, readonly, nullable) AgoraRtcEngineKit *agoraKit;

/// 是否已初始化
@property (nonatomic, assign, readonly) BOOL isInitialized;

/// 是否已加入频道
@property (nonatomic, assign, readonly) BOOL isInChannel;

/// 最近一次远端用户的Agora UID（用于浮窗恢复视频渲染）
@property (nonatomic, assign, readonly) NSUInteger lastRemoteUid;

#pragma mark - 引擎生命周期

/// 初始化声网引擎（使用Default.h中配置的AGORA_APP_ID）
- (void)initialize;

/// 使用指定的AppId初始化声网引擎
- (void)initializeWithAppId:(NSString *)appId;

/// 保证引擎使用指定 AppId：`appId` 为空则用 Default.h 的 AGORA_APP_ID；若与当前引擎不一致则销毁后重建（须与 Token 签发应用一致，否则会 join 失败如 -17）
- (void)ensureEngineWithAppId:(NSString * _Nullable)appId;

/// 销毁声网引擎，释放资源
- (void)destroy;

#pragma mark - 频道操作

/// 加入频道
/// @param channelName 频道名称
/// @param uid 用户ID（传0则由SDK自动分配）
/// @param token 鉴权Token（测试阶段可传nil）
- (void)joinChannel:(NSString *)channelName uid:(NSUInteger)uid token:(NSString *_Nullable)token;

/// 离开频道
- (void)leaveChannel;

#pragma mark - 音视频控制

/// 启用/禁用视频模块
- (void)enableVideo:(BOOL)enable;

/// 静音/取消静音本地音频
- (void)muteLocalAudio:(BOOL)mute;

/// 开启/关闭本地视频发送
- (void)muteLocalVideo:(BOOL)mute;

/// 切换前后摄像头
- (void)switchCamera;

/// 设置本地视频预览视图
- (void)setupLocalVideoView:(UIView *_Nullable)view;

/// 设置远端视频显示视图
- (void)setupRemoteVideoView:(UIView *_Nullable)view forUid:(NSUInteger)uid;

/// 设置是否使用扬声器（免提模式）
- (void)setEnableSpeakerphone:(BOOL)enable;

/// 刷新Token（在Token即将过期时调用）
- (void)renewToken:(NSString *)token;

/// PiP 画中画用：设置后会在 onRenderVideoFrame 收到远端帧（只读，不影响正常渲染）。传 nil 取消。
- (void)setPipVideoFrameDelegate:(id<AgoraVideoFrameDelegate> _Nullable)delegate;

#pragma mark - 工具方法

/// 根据双方UID生成频道名称（排序后拼接，确保双方一致）
+ (NSString *)generateChannelNameWithLocalUid:(NSString *)localUid remoteUid:(NSString *)remoteUid;

@end

NS_ASSUME_NONNULL_END
