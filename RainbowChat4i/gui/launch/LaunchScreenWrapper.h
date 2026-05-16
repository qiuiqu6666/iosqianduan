//telegram @wz662
/**
 * 闪屏UI封装类。
 * 本类目前仅用于登陆界面中的自动登陆功能时。
 *
 * @author Jack Jiang
 * @since 4.0
 */
#import <UIKit/UIKit.h>

@interface LaunchScreenWrapper : UIView

- (void)show:(UIView *)parentView;
- (void)hide;

@end

