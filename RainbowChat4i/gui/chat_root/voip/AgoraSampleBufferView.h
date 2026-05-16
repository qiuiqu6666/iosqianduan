//
//  AgoraSampleBufferView.h
//  RainbowChat4i
//
//  用于 PiP：基于 AVSampleBufferDisplayLayer 的视图，接收 CVPixelBuffer 并渲染。
//

#import <UIKit/UIKit.h>

@class AVSampleBufferDisplayLayer;

NS_ASSUME_NONNULL_BEGIN

@interface AgoraSampleBufferView : UIView

/// PiP 用：底层 AVSampleBufferDisplayLayer
@property (nonatomic, readonly) AVSampleBufferDisplayLayer *sampleBufferDisplayLayer;

/// 将 Agora 远端视频帧（CVPixelBuffer）入队渲染（用于画中画）
/// 主线程或 Agora 回调线程调用均可，内部会序列化到后台队列
- (void)enqueuePixelBuffer:(CVPixelBufferRef)pixelBuffer;

/// 清空当前显示内容（离开频道或停止 PiP 时调用）
- (void)flush;

@end

NS_ASSUME_NONNULL_END
