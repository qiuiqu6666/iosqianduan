//telegram @wz662
/**
 * 查找好友功能主界面（微信风格）.
 */

#import <UIKit/UIKit.h>

@interface FindFriendViewController : UIViewController <UITextFieldDelegate>

/* xib 旧控件（保留 IBOutlet 连接，代码中隐藏） */
@property (weak, nonatomic) IBOutlet UIButton *tabRandomSearch;
@property (weak, nonatomic) IBOutlet UIButton *tabPreciseSearch;
@property (weak, nonatomic) IBOutlet UIView *layoutRandom;
@property (weak, nonatomic) IBOutlet UIImageView *statusLayoutBg;
@property (weak, nonatomic) IBOutlet UIButton *btnOnlineCondition_all;
@property (weak, nonatomic) IBOutlet UIButton *btnOnlineCondition_online;
@property (weak, nonatomic) IBOutlet UIButton *btnOnlineCondition_offline;
@property (weak, nonatomic) IBOutlet UIImageView *sexesLayoutBg;
@property (weak, nonatomic) IBOutlet UIButton *btnSexCondition_all;
@property (weak, nonatomic) IBOutlet UIButton *btnSexCondition_man;
@property (weak, nonatomic) IBOutlet UIButton *btnSexCondition_woman;
@property (weak, nonatomic) IBOutlet UIView *layoutPrecise;
@property (weak, nonatomic) IBOutlet UITextField *editIdOrMail;
@property (weak, nonatomic) IBOutlet UIView *layoutSubmit;
@property (weak, nonatomic) IBOutlet UIButton *viewMaxFriendHint;
@property (weak, nonatomic) IBOutlet UIButton *btnSubmit;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *layoutSubmitTopConstraint;

@end
