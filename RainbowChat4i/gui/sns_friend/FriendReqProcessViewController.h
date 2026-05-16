//telegram @wz662
/**
 * 好友请求通知的处理界面.
 *
 * @author Jack Jiang, 2017-12-27
 * @version 1.0
 */

#import <UIKit/UIKit.h>
#import "UserEntity.h"

@interface FriendReqProcessViewController : UIViewController

/** 标签组件：好友的昵称 */
@property (weak, nonatomic) IBOutlet UILabel *viewNickname;
/** 标签组件：好友的uid */
@property (weak, nonatomic) IBOutlet UILabel *viewUid;

@property (weak, nonatomic) IBOutlet UIView *viewBzContainer;
/** 标签组件：验证说明 */
@property (weak, nonatomic) IBOutlet UITextView *viewBz;

///** 图片组件：验证说明的背景图（带圆角的文本框罗） */
//@property (weak, nonatomic) IBOutlet UIImageView *viewBzBg;
/** 图片组件：头像 */
@property (weak, nonatomic) IBOutlet UIImageView *viewFace;
/** 按钮组件：查看用户信息 */
@property (weak, nonatomic) IBOutlet UIButton *btnSeeFriendInfo;

@property (weak, nonatomic) IBOutlet UIView *btnContainer;
/** 按钮：同意*/
@property (weak, nonatomic) IBOutlet UIButton *btnAgree;
/** 按钮：拒绝*/
@property (weak, nonatomic) IBOutlet UIButton *btnReject;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withDatas:(UserEntity *)userInfo;

@end
