//telegram @wz662
#import <UIKit/UIKit.h>

@interface RBBadgeView : UIView

@property (nonatomic, copy) NSString *badgeValue;

- (void)setBadgeTextFont:(UIFont *)f;

- (void)setBadgeBackgroundColor:(UIColor *)c;

- (void)setBadgeTextColor:(UIColor *)c;

//+ (instancetype)viewWithBadgeTip:(NSString *)badgeValue;

@end
