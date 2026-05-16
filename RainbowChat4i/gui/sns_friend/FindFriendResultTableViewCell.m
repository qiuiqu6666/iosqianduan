//telegram @wz662
#import "FindFriendResultTableViewCell.h"

@implementation FindFriendResultTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

// @Override：重写父类方法，解决当表格单元行被选择时组件的背景颜色消失的问题
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
//    UIColor *viewLeftFlagBackgroundColor = self.viewLeftFlag.backgroundColor;
    [super setHighlighted:highlighted animated:animated]; // 保持父类方法的调用，此行不能丢
//    self.viewLeftFlag.backgroundColor = viewLeftFlagBackgroundColor;
}

// @Override：重写父类方法，解决当表格单元行被选择时组件的背景颜色消失的问题
- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
//    UIColor *viewLeftFlagBackgroundColor = self.viewLeftFlag.backgroundColor;
    [super setSelected:selected animated:animated]; // 保持父类方法的调用，此行不能丢
//    self.viewLeftFlag.backgroundColor = viewLeftFlagBackgroundColor;
}

//- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
//    [super setSelected:selected animated:animated];
//
//    // Configure the view for the selected state
//}

@end
