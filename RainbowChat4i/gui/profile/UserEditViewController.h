//telegram @wz662
#import <UIKit/UIKit.h>
#import "GetSMSButton.h"

#define IS_CHANGE_PASSWORD     1
#define IS_CHANGE_NICKNAME     2
#define IS_CHANGE_SEX          3
#define IS_CHANGE_WHATSUP      4
#define IS_CHANGE_OTHERCAPTION 5

@interface UserEditViewController : UIViewController<UITextFieldDelegate, GetSMSButtonDelegate>

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withChangeType:(int)changeType;


//-----------------------------------------------------------
#pragma mark - 修改昵称相关组件

@property (strong, nonatomic) IBOutlet UIView *layoutEditNickname;
/* 修改昵称的输入框 */
@property (weak, nonatomic) IBOutlet UITextField *editNickname;
//@property (weak, nonatomic) IBOutlet UIImageView *editNicknameBg;


//-----------------------------------------------------------
#pragma mark - 修改性别相关组件

@property (strong, nonatomic) IBOutlet UIView *layoutEditSex;
@property (weak, nonatomic) IBOutlet UIButton *btnSexMan;
@property (weak, nonatomic) IBOutlet UIButton *btnSexWoman;


//-----------------------------------------------------------
#pragma mark - 修改其它说明相关组件

@property (strong, nonatomic) IBOutlet UIView *layoutEditOtherCaption;
/* 修改其它说明的输入框 */
@property (weak, nonatomic) IBOutlet UITextView *editOtherCaption;
//@property (weak, nonatomic) IBOutlet UIImageView *editOtherCaptionBg;


//-----------------------------------------------------------
#pragma mark - 修改个性签名相关组件

@property (strong, nonatomic) IBOutlet UIView *layoutEditWhatsup;
/* 修改个性签名的输入框 */
@property (weak, nonatomic) IBOutlet UITextView *editWhatsup;
//@property (weak, nonatomic) IBOutlet UIImageView *editWhatsupBg;


//-----------------------------------------------------------
#pragma mark - 修改密码相关组件

@property (strong, nonatomic) IBOutlet UIView *layoutEditPassword;
/* 原密码输入框 */
@property (weak, nonatomic) IBOutlet UITextField *editOldPsw;
//@property (weak, nonatomic) IBOutlet UIImageView *editOldPswBg;
/* 新密码输入框 */
@property (weak, nonatomic) IBOutlet UITextField *editNewPsw;
//@property (weak, nonatomic) IBOutlet UIImageView *editNewPswBg;
/* 确认密码输入框 */
@property (weak, nonatomic) IBOutlet UITextField *editConfirmPsw;
//@property (weak, nonatomic) IBOutlet UIImageView *editConfirmPswBg;

/* 短信验证码输入框 */
@property (weak, nonatomic) IBOutlet UITextField *editSmsCode;
/* 获取验证码按钮 */
@property (weak, nonatomic) IBOutlet GetSMSButton *btnGetSMS;

/** 忘记旧密码按钮 */
@property (weak, nonatomic) IBOutlet UIButton *btnForgotPassword;


@end
