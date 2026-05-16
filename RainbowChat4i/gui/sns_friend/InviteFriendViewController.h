//telegram @wz662
/**
 * 通过邮件邀请朋友下载APP（功能就是向指定邮箱发送邀请下载APP的链接等信息，此功能
 * 的存在相当于为尚未使用本APP的人提供一个知道和下载APP的渠道，等于是借助用户的力
 * 量来推广，仅此而已，没什么高深的）.
 *
 * @author Jack Jiang, 2017-12-23
 * @version 1.0
 */

#import <UIKit/UIKit.h>

@interface InviteFriendViewController : UIViewController

//@property (weak, nonatomic) IBOutlet UIImageView *editSendToMailBg;
/** 标签组件：要邀请的好友的邮件地址 */
@property (weak, nonatomic) IBOutlet UITextField *editSendToMail;

@property (weak, nonatomic) IBOutlet UIButton *btnInvite;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withMail:(NSString *)mail;

@end
