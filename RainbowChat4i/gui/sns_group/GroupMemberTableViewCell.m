//telegram @wz662
#import "GroupMemberTableViewCell.h"

@implementation GroupMemberTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

// @Override：重写父类方法，解决当表格单元行被选择时组件的背景颜色消失的问题
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    UIColor *viewGroupOwnerFlagBackgroundColor = self.viewGroupOwnerFlag.backgroundColor;
//    UIColor *viewLeftFlagBackgroundColor = self.viewLeftFlag.backgroundColor;
    UIColor *viewMyselfFlagBackgroundColor = self.viewMyselfFlag.backgroundColor;

    [super setHighlighted:highlighted animated:animated];

    self.viewGroupOwnerFlag.backgroundColor = viewGroupOwnerFlagBackgroundColor;
//    self.viewLeftFlag.backgroundColor = viewLeftFlagBackgroundColor;
    self.viewMyselfFlag.backgroundColor = viewMyselfFlagBackgroundColor;
}

// @Override：重写父类方法，解决当表格单元行被选择时组件的背景颜色消失的问题
- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    UIColor *viewGroupOwnerFlagBackgroundColor = self.viewGroupOwnerFlag.backgroundColor;
//    UIColor *viewLeftFlagBackgroundColor = self.viewLeftFlag.backgroundColor;
    UIColor *viewMyselfFlagBackgroundColor = self.viewMyselfFlag.backgroundColor;

    [super setSelected:selected animated:animated];

    self.viewGroupOwnerFlag.backgroundColor = viewGroupOwnerFlagBackgroundColor;
//    self.viewLeftFlag.backgroundColor = viewLeftFlagBackgroundColor;
    self.viewMyselfFlag.backgroundColor = viewMyselfFlagBackgroundColor;
}

@end
