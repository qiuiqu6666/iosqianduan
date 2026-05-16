#import <UIKit/UIKit.h>

/**
 * 入群审核列表界面：显示待审核的入群申请，管理员和群主可审核通过或拒绝。
 */
@interface GroupJoinRequestsViewController : UIViewController

- (instancetype)initWithGid:(NSString *)gid myRole:(int)myRole;

@end
