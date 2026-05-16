//telegram @wz662
#import "SettingsAccountSecurityViewController.h"
#import "ViewControllerFactory.h"
#import "UserEditViewController.h"
#import "BasicTool.h"
#import "IMClientManager.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "HttpRestHelper.h"
#import "WalletFundPasswordViewController.h"
#import "WalletModifyFundPasswordViewController.h"

@interface SettingsAccountSecurityViewController ()
@property (nonatomic, assign) BOOL rb_fundPasswordHasSet;

@end

@implementation SettingsAccountSecurityViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self rb_installPlainCustomNavigationBarWithTitle:@"账号安全"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self rb_plainCustomNavHostViewWillAppear:animated];

    // 根据当前用户信息动态更新标签文本
    [self updateLabels];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self rb_plainCustomNavHostViewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

- (void)updateLabels
{
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    
    // 更新手机号标签：如果有手机号显示"修改手机号"，否则显示"绑定手机号"
    if (![BasicTool isStringEmpty:localUser.phoneNum]) {
        self.changePhoneLabel.text = @"修改手机号";
    } else {
        self.changePhoneLabel.text = @"绑定手机号";
    }
    
    // 更新邮箱标签：如果有邮箱显示"修改邮箱"，否则显示"绑定邮箱"
    if (![BasicTool isStringEmpty:localUser.user_mail]) {
        self.bindEmailLabel.text = @"修改邮箱";
    } else {
        self.bindEmailLabel.text = @"绑定邮箱";
    }
    
    [self rb_refreshFundPasswordStatusAndUpdateLabel];
}

- (void)rb_updateFundPasswordLabel
{
    self.fundPasswordLabel.text = self.rb_fundPasswordHasSet ? @"修改交易密码" : @"设置交易密码";
}

- (void)rb_refreshFundPasswordStatusAndUpdateLabel
{
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletCheckFundPasswordStatusWithComplete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL isSet = NO;
            if (sucess && data && [data isKindOfClass:[NSDictionary class]]) {
                id v = data[@"is_set"];
                if ([v isKindOfClass:[NSString class]]) {
                    NSString *s = [(NSString *)v lowercaseString];
                    isSet = [s isEqualToString:@"1"] || [s isEqualToString:@"true"] || [s isEqualToString:@"yes"];
                } else if ([v isKindOfClass:[NSNumber class]]) {
                    isSet = ([(NSNumber *)v intValue] == 1) || ([(NSNumber *)v boolValue] == YES);
                } else if (v != nil) {
                    NSString *s = [[v description] lowercaseString];
                    isSet = [s isEqualToString:@"1"] || ([s intValue] == 1) || [s isEqualToString:@"true"] || [s isEqualToString:@"yes"];
                }
            }
            wself.rb_fundPasswordHasSet = isSet;
            [wself rb_updateFundPasswordLabel];
        });
    } hudParentView:nil];
}

// 修改密码
- (IBAction)clickChangePassword:(id)sender
{
    // 跳转到修改密码页面（使用UserEditViewController）
    UserEditViewController *vc = [[UserEditViewController alloc] initWithNibName:@"UserEditViewController" bundle:nil withChangeType:IS_CHANGE_PASSWORD];
    [self.navigationController pushViewController:vc animated:YES];
}

// 设置/修改交易密码（资金密码）
- (IBAction)clickFundPassword:(id)sender
{
    UIViewController *vc = self.rb_fundPasswordHasSet ? (UIViewController *)[[WalletModifyFundPasswordViewController alloc] init] : (UIViewController *)[[WalletFundPasswordViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

// 修改手机号码
- (IBAction)clickChangePhone:(id)sender
{
    [ViewControllerFactory goModifyPhoneViewController:self.navigationController];
}

// 绑定邮箱
- (IBAction)clickBindEmail:(id)sender
{
    [ViewControllerFactory goModifyEmailViewController:self.navigationController];
}

// 设备记录
- (IBAction)clickDeviceRecord:(id)sender
{
    [ViewControllerFactory goSettingsDeviceRecordViewController:self.navigationController];
}

@end
