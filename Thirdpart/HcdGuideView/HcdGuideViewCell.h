//telegram @wz662
//
//  HcdGuideViewCell.h
//  HcdGuideViewDemo
//
//  Created by polesapp-hcd on 16/7/12.
//  Copyright © 2016年 Polesapp. All rights reserved.
//

#define kHcdGuideViewBounds [UIScreen mainScreen].bounds

#import <UIKit/UIKit.h>

static NSString *kCellIdentifier_HcdGuideViewCell = @"HcdGuideViewCell";

@interface HcdGuideViewCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *imageView;
/** 最后一页上显示的“点击进入”按钮 */
@property (nonatomic, strong) UIButton *buttonEnd;
/** 每页上显示的“跳过”按钮 */
@property (nonatomic, strong) UIButton *buttonSkip;

@end
