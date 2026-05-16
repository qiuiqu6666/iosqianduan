//
//  CallPiPManager.h
//  RainbowChat4i
//
//  视频通话画中画（PiP）：退到后台时系统小窗继续显示远端画面。
//  依赖 iOS 15+ AVPictureInPictureController + AVSampleBufferDisplayLayer。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CallPiPManager : NSObject

+ (instancetype)sharedInstance;

/// 是否正在显示画中画
@property (nonatomic, assign, readonly) BOOL isPiPActive;

/// 准备 PiP（视频通话接通后调用，开始接收远端帧到内部 layer，便于退后台时立即启动 PiP）
- (void)preparePiPForVideoCall;

/// 取消准备 / 停止 PiP（通话结束或回到前台时调用）
- (void)stopPiP;

/// 尝试启动画中画（通常在 applicationDidEnterBackground 且正在视频通话时调用）
- (void)startPiPWhenPossible;

/// 将 PiP 源视图挂到通话界面的 container 上，保证 layer 在可见层级被绘制（有画面）
- (void)attachPiPSourceViewToContainerView:(UIView *)containerView;

@end

NS_ASSUME_NONNULL_END
