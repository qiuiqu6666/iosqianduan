//telegram @wz662
#import <UIKit/UIKit.h>
#import "RBImagePickerWrapper.h"

@interface UserViewController : UIViewController<RBImagePickerCompleteDelegate>

// 用户头像
@property (weak, nonatomic) IBOutlet UIImageView *viewAvatar;

// 基本信息值标签
@property (weak, nonatomic) IBOutlet UILabel *viewNickname;
@property (weak, nonatomic) IBOutlet UILabel *viewUid;
@property (weak, nonatomic) IBOutlet UILabel *viewPhone;
@property (weak, nonatomic) IBOutlet UILabel *viewEmail;
@property (weak, nonatomic) IBOutlet UILabel *viewSex;
@property (weak, nonatomic) IBOutlet UILabel *viewWhatsup;

// 按钮事件
- (IBAction)clickAvatar:(id)sender;
- (IBAction)clickNickname:(id)sender;
- (IBAction)clickSex:(id)sender;
- (IBAction)clickPhone:(id)sender;
- (IBAction)clickEmail:(id)sender;
- (IBAction)clickWhatsup:(id)sender;
- (IBAction)clickMyQR:(id)sender;

@end
