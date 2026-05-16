//telegram @wz662
#import <UIKit/UIKit.h>

@interface GroupsTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *viewGroupName;
@property (weak, nonatomic) IBOutlet UILabel *viewCreateTime;
@property (weak, nonatomic) IBOutlet UILabel *viewMemberCount;

@property (weak, nonatomic) IBOutlet UIImageView *viewGroupIcon;
@property (weak, nonatomic) IBOutlet UIImageView *viewOwnerIcon;
@property (weak, nonatomic) IBOutlet UIImageView *viewSilentIcon;

/// 当前 cell 绑定的群头像 gid；用于复用/异步回调时校验，避免群头像回闪或错绑。
@property (nonatomic, copy, nullable) NSString *rb_boundGroupId;

/// 底部分隔线（hairline）；末行传 YES 隐藏。
- (void)rb_setHairlineBottomSeparatorHidden:(BOOL)hidden;

@end
