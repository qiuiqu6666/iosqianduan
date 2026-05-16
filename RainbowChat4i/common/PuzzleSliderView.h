//telegram @wz662
//
//  PuzzleSliderView.h
//  RainbowChat4i
//
//  旋转校正验证：用户拖动滑块旋转中央图片到正确角度（±tolerance°）完成验证。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PuzzleSliderView;

@protocol PuzzleSliderViewDelegate <NSObject>
@optional
/// 验证成功时回调
- (void)puzzleSliderViewDidVerifySuccess:(PuzzleSliderView *)view;
/// 验证失败（松手时角度未在容差内）
- (void)puzzleSliderViewDidVerifyFail:(PuzzleSliderView *)view;
@end

@interface PuzzleSliderView : UIView

@property (nonatomic, weak, nullable) id<PuzzleSliderViewDelegate> delegate;
/// 角度允许误差（度），默认 5
@property (nonatomic, assign) CGFloat tolerance;
/// 是否已验证成功
@property (nonatomic, assign, readonly) BOOL verified;

/// 重新生成（新的目标角度）
- (void)reset;

@end

NS_ASSUME_NONNULL_END
