#import <UIKit/UIKit.h>
#import "GroupMemberEntity.h"

@interface CreateGroupProfileViewController : UIViewController

- (id)initWithMembersForCreate:(NSArray<GroupMemberEntity *> *)membersForCreate membersWithoutLocal:(NSArray<GroupMemberEntity *> *)membersWithoutLocal;

@end

