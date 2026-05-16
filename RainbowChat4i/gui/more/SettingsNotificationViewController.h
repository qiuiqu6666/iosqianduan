//telegram @wz662
#import <UIKit/UIKit.h>

@interface SettingsNotificationViewController : UIViewController

// Section 1: 未打开时
/** 系统消息通知开关 */
@property (weak, nonatomic) IBOutlet UISwitch *imgMessageNotification;
/** 语音和视频通话通知开关 */
@property (weak, nonatomic) IBOutlet UISwitch *imgVoiceVideoNotification;
/** 语音和视频通话用弹窗快捷接听开关 */
@property (weak, nonatomic) IBOutlet UISwitch *imgVoiceVideoPopup;
/** 通知显示内容描述 */
@property (weak, nonatomic) IBOutlet UILabel *lblNotificationContentDesc;

// Section 2: 打开时
/** 消息横幅开关 */
@property (weak, nonatomic) IBOutlet UISwitch *imgMessageBanner;
/** 横幅显示内容描述 */
@property (weak, nonatomic) IBOutlet UILabel *lblBannerContentDesc;
/** 消息提示音开关 */
@property (weak, nonatomic) IBOutlet UISwitch *imgSound;
/** 语音和视频通话来电铃声开关 */
@property (weak, nonatomic) IBOutlet UISwitch *imgAudioVideoCall;
/** 振动开关 */
@property (weak, nonatomic) IBOutlet UISwitch *imgVibration;

@end
