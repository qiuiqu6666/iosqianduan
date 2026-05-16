//telegram @wz662
#import <UIKit/UIKit.h>

@interface FriendsReqTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *viewAvatar;

@property (weak, nonatomic) IBOutlet UILabel *viewTitle;
@property (weak, nonatomic) IBOutlet UILabel *viewMsgContent;
@property (weak, nonatomic) IBOutlet UILabel *viewDate;

@property (weak, nonatomic) IBOutlet UIImageView *viewArrowIco;
@property (weak, nonatomic) IBOutlet UIButton *btnAgree;
/** 拒绝按钮（与同意并列，仅在待处理请求时显示） */
@property (weak, nonatomic) IBOutlet UIButton *btnReject;

@end
