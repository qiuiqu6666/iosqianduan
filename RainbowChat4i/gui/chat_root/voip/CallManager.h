//
//  CallManager.h
//  RainbowChat4i
//
//  通话状态机管理器（单例）。
//  负责通话全生命周期管理：发起呼叫、接听来电、拒绝来电、取消呼叫、挂断通话，
//  以及与MobileIMSDK信令的对接和声网引擎的调度。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 通话类型
typedef NS_ENUM(NSInteger, CallType) {
    CallTypeVoice = 0,   ///< 语音通话
    CallTypeVideo = 1    ///< 视频通话
};

/// 通话状态
typedef NS_ENUM(NSInteger, CallState) {
    CallStateIdle = 0,           ///< 空闲（无通话）
    CallStateOutgoingCalling,    ///< 呼出中（等待对方接听）
    CallStateIncomingCalling,    ///< 来电中（等待本地用户接听）
    CallStateConnected           ///< 通话中（已接通）
};

/// 通话状态变更回调协议
@protocol CallManagerDelegate <NSObject>
@optional

/// 通话状态变更
- (void)callManager:(id)manager didChangeState:(CallState)newState;

/// 对方已接听
- (void)callManagerDidRemoteAccept:(id)manager;

/// 对方已拒绝
- (void)callManagerDidRemoteReject:(id)manager;

/// 对方已取消呼叫
- (void)callManagerDidRemoteCancel:(id)manager;

/// 对方已挂断
- (void)callManagerDidRemoteHangup:(id)manager;

/// 呼叫超时（对方未接听）
- (void)callManagerDidTimeout:(id)manager;

/// 发生错误
- (void)callManager:(id)manager didOccurError:(NSString *)errorMsg;

@end


@interface CallManager : NSObject

/// 单例
+ (instancetype)sharedInstance;

+ (void)rb_markPendingScrollToBottomForChatUid:(NSString *)uid;
+ (BOOL)rb_consumePendingScrollToBottomForChatUid:(NSString *)uid;

+ (NSString *)rb_notificationNameVoipRecordAppended;

/// 代理
@property (nonatomic, weak, nullable) id<CallManagerDelegate> delegate;

/// 当前通话状态
@property (nonatomic, assign, readonly) CallState currentState;

/// 当前通话类型
@property (nonatomic, assign, readonly) CallType currentCallType;

/// 当前通话对方的UID
@property (nonatomic, copy, readonly, nullable) NSString *remoteUserUid;

/// 当前通话对方的昵称
@property (nonatomic, copy, readonly, nullable) NSString *remoteUserNickname;

/// 通话开始时间（接通时刻）
@property (nonatomic, strong, readonly, nullable) NSDate *callConnectedTime;

/// 是否是主叫方
@property (nonatomic, assign, readonly) BOOL isCaller;

#pragma mark - 主叫方操作

/// 发起呼叫
/// @param remoteUid 对方UID
/// @param remoteNickname 对方昵称
/// @param callType 通话类型
- (void)startCall:(NSString *)remoteUid
   remoteNickname:(NSString *)remoteNickname
         callType:(CallType)callType;

/// 取消呼叫（呼出方在对方接听前取消）
- (void)cancelCall;

#pragma mark - 被叫方操作

/// 收到来电（由 ChatMessageEventImpl 调用）
/// @param remoteUid 来电方UID
/// @param remoteNickname 来电方昵称
/// @param callType 通话类型
- (void)onIncomingCall:(NSString *)remoteUid
        remoteNickname:(NSString *)remoteNickname
              callType:(CallType)callType;

/// 接听来电
- (void)acceptCall;

/// 拒绝来电
- (void)rejectCall;

#pragma mark - 通话中操作

/// 挂断通话
- (void)hangupCall;

#pragma mark - IM 信令消息处理（由 ChatMessageEventImpl 调用）

/// 收到对方同意通话的信令（MT19 / MT33）
- (void)onRemoteAccepted:(NSString *)remoteUid;

/// 收到对方拒绝通话的信令（MT20 / MT34）
- (void)onRemoteRejected:(NSString *)remoteUid;

/// 收到对方取消呼叫的信令（MT18 / MT32）
- (void)onRemoteCancelled:(NSString *)remoteUid;

/// 收到对方结束通话的信令（MT14 / MT35）
- (void)onRemoteHangup:(NSString *)remoteUid;

#pragma mark - 工具

/// 是否正在通话中（包括呼叫中和已接通）
- (BOOL)isInCall;

/// 获取当前通话时长（秒）
- (NSInteger)getCallDuration;

/// 重置到空闲状态
- (void)reset;

/// 声网 Token 即将过期时，由 CallViewController 转发调用，自动向后端请求新 Token 续期
- (void)refreshTokenIfNeeded;

/// P2-3：重试加入声网频道（Token/加入失败后由 VC 调用）
- (void)retryJoinChannel;

@end

NS_ASSUME_NONNULL_END
