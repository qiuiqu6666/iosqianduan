//telegram @wz662
#import <UIKit/UIKit.h>

@interface ModifyEmailViewController : UIViewController

/** 旧邮箱验证码输入框（如果用户已有邮箱） */
@property (nonatomic, strong) UITextField *txtOldEmailCode;
/** 旧邮箱获取验证码按钮（如果用户已有邮箱） */
@property (nonatomic, strong) UIButton *btnGetOldEmailCode;
/** 旧邮箱布局（如果用户已有邮箱） */
@property (nonatomic, strong) UIView *layoutOldEmail;

/** 新邮箱输入框 */
@property (nonatomic, strong) UITextField *txtNewEmail;
/** 新邮箱验证码输入框 */
@property (nonatomic, strong) UITextField *txtNewEmailCode;
/** 新邮箱获取验证码按钮 */
@property (nonatomic, strong) UIButton *btnGetNewEmailCode;

@end
