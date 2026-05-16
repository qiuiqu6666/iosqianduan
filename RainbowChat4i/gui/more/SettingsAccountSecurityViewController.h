//telegram @wz662
#import <UIKit/UIKit.h>

@interface SettingsAccountSecurityViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *changePhoneLabel;
@property (weak, nonatomic) IBOutlet UILabel *bindEmailLabel;
@property (weak, nonatomic) IBOutlet UILabel *fundPasswordLabel;

- (IBAction)clickFundPassword:(id)sender;
- (IBAction)clickDeviceRecord:(id)sender;

@end
