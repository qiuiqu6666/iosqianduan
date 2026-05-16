//
//  PuzzleSliderCaptchaViewController.h
//  RainbowChat4i
//
//  拼图滑块验证弹窗：展示拼图滑块，验证成功后通过 completion 回调。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PuzzleSliderCaptchaViewController : UIViewController

@property (nonatomic, copy, nullable) void(^onVerifySuccess)(void);
@property (nonatomic, copy, nullable) void(^onCancel)(void);

@end

NS_ASSUME_NONNULL_END
