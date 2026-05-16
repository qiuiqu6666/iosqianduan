//telegram @wz662
//
//  AbstractTableViewCell.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/18.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AbstractTableViewCell : UITableViewCell

// 名称/标题
@property (weak, nonatomic) IBOutlet UILabel *viewName;
// 头像/图标
@property (weak, nonatomic) IBOutlet UIImageView *viewAvadar;

// 基本配置方法
- (void)baseSetup;

@end
