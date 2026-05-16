//telegram @wz662
//
//  HWVideoProgress.h
//  AVFoundationTest
//
//  Created by sxmaps_w on 2017/8/25.
//  Copyright © 2017年 wqb. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HWVideoProgress : UIView

- (void)set:(UIColor *)bgColor progressColor:(UIColor *)progressColor cornerRadius:(CGFloat)cornerRadius;

- (void)setProgress:(CGFloat)progress duration:(CGFloat)duration;

@end
