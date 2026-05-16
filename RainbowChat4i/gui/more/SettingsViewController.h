//telegram @wz662
#import <UIKit/UIKit.h>

@class RBChromeNavigationBar;

@interface SettingsViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *versionValueLabel;
@property (weak, nonatomic) IBOutlet UIView *contentView;

/// 转场标题动画解析用（与 PlainCustomNav 子页同属 RBChromeNavigationBar）
@property (nonatomic, readonly, nullable) RBChromeNavigationBar *rb_transitionChromeNavigationBar;

@end
