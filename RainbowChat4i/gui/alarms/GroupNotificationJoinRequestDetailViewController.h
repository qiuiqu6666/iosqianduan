#import "RootViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface GroupNotificationJoinRequestDetailViewController : RootViewController

- (instancetype)initWithItem:(NSDictionary *)item
            reviewCompletion:(void (^ _Nullable)(NSDictionary *updatedItem))reviewCompletion;

@end

NS_ASSUME_NONNULL_END
