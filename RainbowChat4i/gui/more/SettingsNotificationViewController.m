//telegram @wz662
#import "SettingsNotificationViewController.h"
#import "NotificationContentViewController.h"
#import "UserDefaultsToolKits.h"
#import "LPActionSheet.h"
#import "BasicTool.h"
#import "UIViewController+RBPlainCustomNav.h"

// UserDefaults keys
static NSString * const kSystemNotificationKey = @"APP_SYSTEM_NOTIFICATION_ENABLED";
static NSString * const kVoiceVideoNotificationKey = @"APP_VOICE_VIDEO_NOTIFICATION_ENABLED";
static NSString * const kVoiceVideoPopupKey = @"APP_VOICE_VIDEO_POPUP_ENABLED";
static NSString * const kMessageBannerKey = @"APP_MESSAGE_BANNER_ENABLED";
static NSString * const kVibrationKey = @"APP_VIBRATION_ENABLED";
static NSString * const kAudioVideoCallKey = @"APP_AUDIO_VIDEO_CALL_ENABLED";

@interface SettingsNotificationViewController ()

@end

@implementation SettingsNotificationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self rb_installPlainCustomNavigationBarWithTitle:@"通知"];

    // 缩小开关按钮
    CGAffineTransform switchTransform = CGAffineTransformMakeScale(0.9, 1);
    self.imgMessageNotification.transform = switchTransform;
    self.imgVoiceVideoNotification.transform = switchTransform;
    self.imgVoiceVideoPopup.transform = switchTransform;
    self.imgMessageBanner.transform = switchTransform;
    self.imgSound.transform = switchTransform;
    self.imgAudioVideoCall.transform = switchTransform;
    self.imgVibration.transform = switchTransform;
    
    // 禁用开关的直接交互，由按钮处理
    self.imgMessageNotification.userInteractionEnabled = NO;
    self.imgVoiceVideoNotification.userInteractionEnabled = NO;
    self.imgVoiceVideoPopup.userInteractionEnabled = NO;
    self.imgMessageBanner.userInteractionEnabled = NO;
    self.imgSound.userInteractionEnabled = NO;
    self.imgAudioVideoCall.userInteractionEnabled = NO;
    self.imgVibration.userInteractionEnabled = NO;
    
    // 初始化默认值
    [self initDefaultSettings];
    
    // 加载保存的设置
    [self refreshAllSwitchImages];
    
    // 刷新显示内容描述
    [self refreshContentDescriptions];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self rb_plainCustomNavHostViewWillAppear:animated];

    // 每次回到本页面时刷新描述文本（用户可能在子页面修改了选择）
    [self refreshContentDescriptions];
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

#pragma mark - 刷新显示内容描述

- (void)refreshContentDescriptions
{
    self.lblNotificationContentDesc.text = [NotificationContentViewController descriptionForContentType:NotificationContentTypeNotification];
    self.lblBannerContentDesc.text = [NotificationContentViewController descriptionForContentType:NotificationContentTypeBanner];
}

#pragma mark - 初始化默认设置

- (void)initDefaultSettings
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    if ([ud objectForKey:kSystemNotificationKey] == nil) {
        [ud setBool:YES forKey:kSystemNotificationKey];
    }
    if ([ud objectForKey:kVoiceVideoNotificationKey] == nil) {
        [ud setBool:YES forKey:kVoiceVideoNotificationKey];
    }
    if ([ud objectForKey:kVoiceVideoPopupKey] == nil) {
        [ud setBool:YES forKey:kVoiceVideoPopupKey];
    }
    if ([ud objectForKey:kMessageBannerKey] == nil) {
        [ud setBool:YES forKey:kMessageBannerKey];
    }
    if ([ud objectForKey:kVibrationKey] == nil) {
        [ud setBool:YES forKey:kVibrationKey];
    }
    if ([ud objectForKey:kAudioVideoCallKey] == nil) {
        [ud setBool:YES forKey:kAudioVideoCallKey];
    }
    [ud synchronize];
}

#pragma mark - 刷新所有开关状态

- (void)refreshAllSwitchImages
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    // Section 1
    BOOL sysNotiEnabled = ([ud objectForKey:kSystemNotificationKey] == nil) ? YES : [ud boolForKey:kSystemNotificationKey];
    [self.imgMessageNotification setOn:sysNotiEnabled animated:YES];
    [self.imgVoiceVideoNotification setOn:[ud boolForKey:kVoiceVideoNotificationKey] animated:YES];
    [self.imgVoiceVideoPopup setOn:[ud boolForKey:kVoiceVideoPopupKey] animated:YES];
    
    // Section 2
    [self.imgMessageBanner setOn:[ud boolForKey:kMessageBannerKey] animated:YES];
    [self.imgSound setOn:[UserDefaultsToolKits isAPPMsgToneOpen] animated:YES];
    [self.imgAudioVideoCall setOn:[ud boolForKey:kAudioVideoCallKey] animated:YES];
    [self.imgVibration setOn:[ud boolForKey:kVibrationKey] animated:YES];
}

#pragma mark - 关闭确认弹窗

- (void)showCloseConfirmWithMessage:(NSString *)message
                        actionTitle:(NSString *)actionTitle
                         completion:(void (^)(void))completion
{
    LPActionSheet *actionSheet = [LPActionSheet actionSheetWithTitle:message
                                                   cancelButtonTitle:@"取消"
                                              destructiveButtonTitle:actionTitle
                                                   otherButtonTitles:nil
                                                             handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == -1) {
            if (completion) {
                completion();
            }
        }
    }];
    [actionSheet show];
}

#pragma mark - Section 1: 未打开时

// 系统消息通知
- (IBAction)switchMessageNotificationClicked:(id)sender
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL currentState = ([ud objectForKey:kSystemNotificationKey] == nil) ? YES : [ud boolForKey:kSystemNotificationKey];
    
    if (currentState) {
        [self showCloseConfirmWithMessage:@"关闭后，手机将不再接收系统消息通知"
                             actionTitle:@"关闭系统消息通知"
                              completion:^{
            [ud setBool:NO forKey:kSystemNotificationKey];
            [ud synchronize];
            [self refreshAllSwitchImages];
        }];
    } else {
        [ud setBool:YES forKey:kSystemNotificationKey];
        [ud synchronize];
        [self refreshAllSwitchImages];
    }
}

// 语音和视频通话通知
- (IBAction)switchVoiceVideoNotificationClicked:(id)sender
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL currentState = [ud boolForKey:kVoiceVideoNotificationKey];
    
    if (currentState) {
        [self showCloseConfirmWithMessage:@"关闭后，将不再接收语音和视频通话通知"
                             actionTitle:@"关闭语音视频通知"
                              completion:^{
            [ud setBool:NO forKey:kVoiceVideoNotificationKey];
            [ud synchronize];
            [self refreshAllSwitchImages];
        }];
    } else {
        [ud setBool:YES forKey:kVoiceVideoNotificationKey];
        [ud synchronize];
        [self refreshAllSwitchImages];
    }
}

// 语音和视频通话用弹窗快捷接听
- (IBAction)switchVoiceVideoPopupClicked:(id)sender
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL currentState = [ud boolForKey:kVoiceVideoPopupKey];
    
    if (currentState) {
        [self showCloseConfirmWithMessage:@"关闭后，语音和视频通话将不再使用弹窗快捷接听"
                             actionTitle:@"关闭弹窗接听"
                              completion:^{
            [ud setBool:NO forKey:kVoiceVideoPopupKey];
            [ud synchronize];
            [self refreshAllSwitchImages];
        }];
    } else {
        [ud setBool:YES forKey:kVoiceVideoPopupKey];
        [ud synchronize];
        [self refreshAllSwitchImages];
    }
}

// 通知显示内容（可导航）
- (IBAction)clickNotificationContent:(id)sender
{
    NotificationContentViewController *vc = [[NotificationContentViewController alloc] init];
    vc.contentType = NotificationContentTypeNotification;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Section 2: 打开时

// 消息横幅
- (IBAction)switchMessageBannerClicked:(id)sender
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL currentState = [ud boolForKey:kMessageBannerKey];
    
    if (currentState) {
        [self showCloseConfirmWithMessage:@"关闭后，应用内将不再显示消息横幅通知"
                             actionTitle:@"关闭消息横幅"
                              completion:^{
            [ud setBool:NO forKey:kMessageBannerKey];
            [ud synchronize];
            [self refreshAllSwitchImages];
        }];
    } else {
        [ud setBool:YES forKey:kMessageBannerKey];
        [ud synchronize];
        [self refreshAllSwitchImages];
    }
}

// 横幅显示内容（可导航）
- (IBAction)clickBannerContent:(id)sender
{
    NotificationContentViewController *vc = [[NotificationContentViewController alloc] init];
    vc.contentType = NotificationContentTypeBanner;
    [self.navigationController pushViewController:vc animated:YES];
}

// 消息提示音
- (IBAction)switchSoundClicked:(id)sender
{
    BOOL currentState = [UserDefaultsToolKits isAPPMsgToneOpen];
    
    if (currentState) {
        [self showCloseConfirmWithMessage:@"关闭后，将不再播放消息提示音"
                             actionTitle:@"关闭消息提示音"
                              completion:^{
            [UserDefaultsToolKits setAPPMsgToneOpen:NO];
            [self refreshAllSwitchImages];
        }];
    } else {
        [UserDefaultsToolKits setAPPMsgToneOpen:YES];
        [self refreshAllSwitchImages];
    }
}

// 语音和视频通话来电铃声
- (IBAction)switchRingtoneClicked:(id)sender
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL currentState = [ud boolForKey:kAudioVideoCallKey];
    
    if (currentState) {
        [self showCloseConfirmWithMessage:@"关闭后，语音和视频通话将不再播放来电铃声"
                             actionTitle:@"关闭来电铃声"
                              completion:^{
            [ud setBool:NO forKey:kAudioVideoCallKey];
            [ud synchronize];
            [self refreshAllSwitchImages];
        }];
    } else {
        [ud setBool:YES forKey:kAudioVideoCallKey];
        [ud synchronize];
        [self refreshAllSwitchImages];
    }
}

// 振动
- (IBAction)switchVibrationClicked:(id)sender
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL currentState = [ud boolForKey:kVibrationKey];
    
    if (currentState) {
        [self showCloseConfirmWithMessage:@"关闭后，收到消息将不再震动"
                             actionTitle:@"关闭振动"
                              completion:^{
            [ud setBool:NO forKey:kVibrationKey];
            [ud synchronize];
            [self refreshAllSwitchImages];
        }];
    } else {
        [ud setBool:YES forKey:kVibrationKey];
        [ud synchronize];
        [self refreshAllSwitchImages];
    }
}

@end
