#import <UIKit/UIKit.h>

/**
 * 群禁言成员列表界面：显示当前被禁言的成员，管理员和群主可解除禁言。
 */
@interface GroupMutedMembersViewController : UIViewController

- (instancetype)initWithGid:(NSString *)gid myRole:(int)myRole;

@end
