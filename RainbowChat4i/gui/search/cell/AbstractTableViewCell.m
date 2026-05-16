//telegram @wz662
//
//  AbstractTableViewCell.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/18.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "AbstractTableViewCell.h"

@implementation AbstractTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)baseSetup {
    // 图片圆角(圆角半径是当前头像组件的1/2，即变成圆形)
    self.viewAvadar.layer.cornerRadius = 7;//25;//4;
    self.viewAvadar.layer.masksToBounds = YES;
    
    // 表格单元选中时的颜色
    self.selectedBackgroundView = [[UIView alloc] initWithFrame:self.frame];
    self.selectedBackgroundView.backgroundColor = UI_DEFAULT_TABLE_VIEW_SELECTED_BG_COLOR;
    // 为了跟表格背景色一致，cell的背景设为透明
    self.backgroundColor=[UIColor clearColor];
}

@end
