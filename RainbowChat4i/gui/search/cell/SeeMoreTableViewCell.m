//telegram @wz662
#import "SeeMoreTableViewCell.h"

@implementation SeeMoreTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)baseSetup {    
    // 表格单元选中时的颜色
    self.selectedBackgroundView = [[UIView alloc] initWithFrame:self.frame];
    self.selectedBackgroundView.backgroundColor = UI_DEFAULT_TABLE_VIEW_SELECTED_BG_COLOR;
    // 为了跟表格背景色一致，cell的背景设为透明
    self.backgroundColor=[UIColor clearColor];
}

@end
