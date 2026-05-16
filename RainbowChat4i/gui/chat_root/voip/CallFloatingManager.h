//
//  CallFloatingManager.h
//  RainbowChat4i
//
//  通话浮窗管理器（单例）。
//  当用户最小化通话界面时，显示浮窗继续通话，点击浮窗可恢复全屏通话界面。
//

#import <Foundation/Foundation.h>
#import "CallManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface CallFloatingManager : NSObject

/// 单例
+ (instancetype)sharedInstance;

/// 显示浮窗
/// @param callType 通话类型（语音/视频）
/// @param remoteUserUid 对方UID
/// @param remoteUserNickname 对方昵称
- (void)showWithCallType:(CallType)callType
           remoteUserUid:(NSString *)remoteUserUid
      remoteUserNickname:(NSString *)remoteUserNickname;

/// 隐藏浮窗（不恢复全屏）
- (void)hide;

/// 浮窗是否正在显示
@property (nonatomic, assign, readonly) BOOL isShowing;

@end

NS_ASSUME_NONNULL_END
