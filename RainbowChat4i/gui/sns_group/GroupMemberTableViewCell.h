//telegram @wz662
#import <UIKit/UIKit.h>

@interface GroupMemberTableViewCell : UITableViewCell

//// 最左边的单元行装饰
//@property (weak, nonatomic) IBOutlet UIView *viewLeftFlag;

@property (weak, nonatomic) IBOutlet UIImageView *viewAvatar;
@property (weak, nonatomic) IBOutlet UILabel *viewName;
@property (weak, nonatomic) IBOutlet UILabel *viewId;
@property (weak, nonatomic) IBOutlet UIImageView *viewCheckIcon;

// "我"标签
@property (weak, nonatomic) IBOutlet UILabel *viewMyselfFlag;

// 群主标签
@property (weak, nonatomic) IBOutlet UILabel *viewGroupOwnerFlag;
// 群主标签的高度约束（当不需要显地此组件时，本值设为0即可，利于用此值的设置可以让AutoLayout下依赖于本组件的其它组件能自适应位置）
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *widthConstraintOfOwnerFlag;

// "我"标签
@property (weak, nonatomic) IBOutlet UILabel *viewIsMyselfFlag;

@end
