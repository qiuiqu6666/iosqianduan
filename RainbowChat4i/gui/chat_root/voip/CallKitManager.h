//
//  CallKitManager.h
//  RainbowChat4i
//
//  PushKit + CallKit 管理器（单例）。
//  负责 VoIP 推送注册、来电界面显示、以及通话状态与系统 CallKit 的同步。
//

#import <Foundation/Foundation.h>
#import <PushKit/PushKit.h>
#import <CallKit/CallKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CallKitManager : NSObject <PKPushRegistryDelegate, CXProviderDelegate>

/// 单例
+ (instancetype)sharedInstance;

/// 当前来电的 UUID（nil 表示无活跃来电）
@property (nonatomic, strong, nullable) NSUUID *currentCallUUID;

/// 缓存的 VoIP Token（十六进制字符串），登录后上传到服务端
@property (nonatomic, copy, nullable) NSString *cachedVoIPToken;

#pragma mark - 初始化

/// 初始化 CallKit CXProvider（在 AppDelegate didFinishLaunchingWithOptions 中调用）
- (void)setupCallKit;

/// 注册 PushKit VoIP 推送（在 AppDelegate didFinishLaunchingWithOptions 中调用）
- (void)registerVoIPPush;

#pragma mark - CallKit 报告

/// 向 CallKit 报告一个来电（用于在线 IM 来电信令场景）
/// @param callerUid 呼叫方 UID
/// @param callerName 呼叫方昵称
/// @param callType "video" 或 "voice"
/// @param completion 报告完成回调
- (void)reportIncomingCall:(NSString *)callerUid
                callerName:(NSString *)callerName
                  callType:(NSString *)callType
                completion:(void (^ _Nullable)(NSError * _Nullable error))completion;

/// 向 CallKit 报告通话已接通
- (void)reportCallConnected;

/// 向 CallKit 报告通话已结束
/// @param reason 结束原因
- (void)reportCallEnded:(CXCallEndedReason)reason;

#pragma mark - VoIP Token 管理

/// 上传缓存的 VoIP Token 到服务端（登录/重连成功后调用）
- (void)uploadCachedVoIPTokenIfNeeded;

@end

NS_ASSUME_NONNULL_END
