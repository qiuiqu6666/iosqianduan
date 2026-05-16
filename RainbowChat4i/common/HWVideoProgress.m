//telegram @wz662
//
//  HWVideoProgress.m
//  AVFoundationTest
//
//  Created by sxmaps_w on 2017/8/25.
//  Copyright © 2017年 wqb. All rights reserved.
//

#import "HWVideoProgress.h"
#import "Masonry.h"

#define KProgressColor [UIColor whiteColor]

@interface HWVideoProgress ()

@property (nonatomic, weak) UIView *back;
@property (nonatomic, weak) UIView *tView;

@end

@implementation HWVideoProgress

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
        
    [self initVideoProgress];
}

//- (instancetype)initWithFrame:(CGRect)frame
- (void)initVideoProgress
{
//    if (self = [super initWithFrame:frame])
    {
            
        //背景
        UIView *back = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
        back.backgroundColor = [KProgressColor colorWithAlphaComponent:0.3f];
        back.layer.cornerRadius = self.bounds.size.height * 0.5;
        back.layer.masksToBounds = YES;
        [self addSubview:back];
        self.back = back;
        [self.back mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(self);
            make.height.equalTo(self);
        }];
        
        //进度
        UIView *tView = [[UIView alloc] init];
        tView.backgroundColor = KProgressColor;
        tView.layer.cornerRadius = self.bounds.size.height * 0.5;
        tView.layer.masksToBounds = YES;
        [self addSubview:tView];
        self.tView = tView;
    }
    
//    return self;
}

- (void) set:(UIColor *)bgColor progressColor:(UIColor *)progressColor cornerRadius:(CGFloat)cornerRadius
{
    self.back.backgroundColor = bgColor;
    self.tView.backgroundColor = progressColor;
    self.back.layer.cornerRadius = cornerRadius;
    self.tView.layer.cornerRadius = cornerRadius;
}

- (void)setProgress:(CGFloat)progress duration:(CGFloat)duration
{
    if (progress > 1) progress = 1;
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        _tView.frame = CGRectMake(0, 0, self.bounds.size.width * progress, self.bounds.size.height);
    } completion:nil];
}

@end
