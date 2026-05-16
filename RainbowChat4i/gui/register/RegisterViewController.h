//telegram @wz662
#import <UIKit/UIKit.h>
#import "GetSMSButton.h"

@interface RegisterViewController : UIViewController<GetSMSButtonDelegate, UITextFieldDelegate>

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil needSMS:(BOOL)needSMS phone:(NSString *)phone sms:(NSString *)sms;

@end
