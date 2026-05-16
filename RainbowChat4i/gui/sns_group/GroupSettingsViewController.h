#import <UIKit/UIKit.h>
#import "GroupEntity.h"

/**
 * 群设置界面：入群方式、邀请权限、新成员历史消息、成员隐私保护。
 * 管理员和群主可修改设置。
 */
@interface GroupSettingsViewController : UIViewController

- (instancetype)initWithGroupInfo:(GroupEntity *)groupInfo myRole:(int)myRole;

@end
