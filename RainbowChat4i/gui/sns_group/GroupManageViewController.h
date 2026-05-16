#import <UIKit/UIKit.h>
#import "GroupEntity.h"

@protocol GroupManageDelegate <NSObject>
@optional
/** 群头像设置完成后回调刷新 */
- (void)groupManageDidRequestSetAvatar;
@end

/**
 * 群管理页面：以列表方式展示群管理功能入口。
 * 包括：设置群头像、设置/取消管理员、全群禁言、禁言成员列表、入群审核列表、群设置、转让群。
 */
@interface GroupManageViewController : UIViewController

- (instancetype)initWithGroupInfo:(GroupEntity *)groupInfo myRole:(int)myRole;

@property (nonatomic, weak) id<GroupManageDelegate> delegate;

@end
