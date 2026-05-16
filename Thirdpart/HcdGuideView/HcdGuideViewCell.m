//telegram @wz662
//
//  HcdGuideViewCell.m
//  HcdGuideViewDemo
//
//  Created by polesapp-hcd on 16/7/12.
//  Copyright © 2016年 Polesapp. All rights reserved.
//

#import "HcdGuideViewCell.h"
#import "HcdGuideView.h"

@interface HcdGuideViewCell()

@end

@implementation HcdGuideViewCell

- (instancetype)init {
    if (self = [super init]) {
        [self initView];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initView];
    }
    return self;
}

- (void)initView {
    self.layer.masksToBounds = YES;
    self.imageView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, kHcdGuideViewBounds.size.width, kHcdGuideViewBounds.size.height)];
    self.imageView.contentMode = UIViewContentModeScaleToFill;//UIViewContentModeScaleAspectFit;
    
    // 留海屏的安全区上方衬距
    CGFloat safeAreaInsets_top = [BasicTool getSafeAreaInsets_top];
    NSLog(@"【HcdGuideView】safeAreaInsets_top=%f", safeAreaInsets_top);

    // 设置引导页上的跳过按钮
    UIButton *skipButton = [[UIButton alloc]initWithFrame:CGRectMake(kHcdGuideViewBounds.size.width - 84, 26+safeAreaInsets_top, 64, 30)];
    [skipButton setTitle:@"跳过" forState:UIControlStateNormal];
    [skipButton.titleLabel setFont:[UIFont systemFontOfSize:14.0]];
    // 按钮背景色是半透明灰色
    [skipButton setBackgroundColor:[UIColor colorWithRed:128/255.0f green:128/255.0f blue:128/255.0f alpha:200/255.0f]];
    // [skipButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    [skipButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [skipButton.layer setCornerRadius:(skipButton.frame.size.height * 0.5)];
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:skipButton];
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:skipButton];

    self.buttonSkip = skipButton;

    // 设置引导页上的“点击进入”按钮（用于最后一页中）
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    // 最后一页的按钮默认不可见
    button.hidden = YES;
    // 按钮字体
    button.titleLabel.font=[UIFont systemFontOfSize:15];
    // 按钮大小
    [button setFrame:CGRectMake(0, 0, 170, 40)];// 0, 0, 150, 40
    [button setTitle:@"点击进入" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:RGBACOLOR(255, 255, 255, 128) forState:UIControlStateHighlighted];
    [button.layer setCornerRadius:20];// 10
    [button.layer setBorderColor:[UIColor grayColor].CGColor];
    [button.layer setBorderWidth:1.0f];
    [button setBackgroundColor:[UIColor whiteColor]];
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:button];
    
    self.buttonEnd = button;
    
    [self.contentView addSubview:self.imageView];
    [self.contentView addSubview:self.buttonEnd];
    [self.contentView addSubview:self.buttonSkip];

    // “点击进入”按钮的显示位置
    [self.buttonEnd setCenter:CGPointMake(kHcdGuideViewBounds.size.width / 2, kHcdGuideViewBounds.size.height - 80)];
}

@end
