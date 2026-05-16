//telegram @wz662
#import <UIKit/UIKit.h>
//#import "EGOImageView.h"
//#import "AddSpaceView.h"
#import "RootViewController.h"

@interface MoreViewController : RootViewController

// 个人信息区域
@property (weak, nonatomic) IBOutlet UIImageView *imgUserAvater;
@property (weak, nonatomic) IBOutlet UILabel *viewUserId;
@property (weak, nonatomic) IBOutlet UILabel *viewUserName;

// 二维码入口区域
@property (weak, nonatomic) IBOutlet UIView *layoutQRCode;

// 状态按钮
@property (weak, nonatomic) IBOutlet UIButton *btnStatus;

// 原有功能入口
- (IBAction)gotoWallet:(id)sender;
- (IBAction)gotoCalls:(id)sender;
- (IBAction)gotoMyProfile:(id)sender;
- (IBAction)gotoStatus:(id)sender;
- (IBAction)gotoFavorites:(id)sender;
- (IBAction)gotoMoments:(id)sender;
- (IBAction)gotoNotification:(id)sender;
- (IBAction)gotoShareApp:(id)sender;
- (IBAction)gotoSettings:(id)sender;

// 二维码入口
- (IBAction)gotoQRCode:(id)sender;

// 退出当前登陆状态并跳转到登际界面（以便重新登陆）
+ (void)exitAndGotoLogin:(BOOL)clearLoginName;
// 查看本地用户头像大图
+ (void)showLocalUserAvatarBigImage:(UIViewController *)parent;
// 查看用户头像大图
+ (void)showUserAvatarBigImage:(NSString *)uid avatarFileName:(NSString *)af withParent:(UIViewController *)parent;

@end
