//telegram @wz662
#import <UIKit/UIKit.h>
#import "GetSMSButton.h"

@interface ModifyPhoneViewController : UIViewController<GetSMSButtonDelegate, UITextFieldDelegate>

/** 旧手机号验证码输入框（如果用户已有手机号） */
@property (nonatomic, strong) UITextField *txtOldPhoneSmsCode;
/** 旧手机号获取验证码按钮（如果用户已有手机号） */
@property (nonatomic, strong) GetSMSButton *btnGetOldPhoneSMS;
/** 旧手机号布局（如果用户已有手机号） */
@property (nonatomic, strong) UIView *layoutOldPhone;

/** 新手机号输入框 */
@property (nonatomic, strong) UITextField *txtNewPhone;
/** 新手机号验证码输入框 */
@property (nonatomic, strong) UITextField *txtNewPhoneSmsCode;
/** 新手机号获取验证码按钮 */
@property (nonatomic, strong) GetSMSButton *btnGetNewPhoneSMS;

@end
