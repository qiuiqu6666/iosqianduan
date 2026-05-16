//telegram @wz662
//  通话记录列表页：展示单聊通话记录（全部 / 未接）
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CallsFilterType) {
    CallsFilterTypeAll = 0,
    CallsFilterTypeMissed = 1,
};

@interface CallsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

@end

NS_ASSUME_NONNULL_END

