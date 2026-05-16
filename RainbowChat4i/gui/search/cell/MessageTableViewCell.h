//telegram @wz662
#import <UIKit/UIKit.h>
#import "AbstractTableViewCell.h"

@interface MessageTableViewCell : AbstractTableViewCell

// 时间组件
@property (weak, nonatomic) IBOutlet UILabel *viewDate;
// 详细内容组件
@property (weak, nonatomic) IBOutlet UILabel *viewDesc;

@end
