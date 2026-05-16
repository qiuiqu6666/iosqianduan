//telegram @wz662
#import <UIKit/UIKit.h>
#import "GetSMSButton.h"

@interface LoginViewController : UIViewController<UIAlertViewDelegate, GetSMSButtonDelegate, UITextFieldDelegate>

/*!
 *  登陆事件处理。
 */
- (IBAction)signIn:(id)sender;

// "密码或短信验证码登录"切换按钮事件处理
- (IBAction)doSwitchLoginType:(id)sender;

// "忘记密码"按钮事件处理
- (IBAction)doForgetPassword:(id)sender;

@end
