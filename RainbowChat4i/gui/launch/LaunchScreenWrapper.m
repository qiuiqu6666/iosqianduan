//telegram @wz662
//
//  LaunchScreenView.m
//  RainbowChat4i
//
//  Created by Jack Jiang
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import "LaunchScreenWrapper.h"

@interface LaunchScreenWrapper ()
@property (nonatomic, retain) UIView *launchView;
@end

@implementation LaunchScreenWrapper

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.launchView = [[[NSBundle mainBundle] loadNibNamed:@"LaunchScreen" owner:self options:nil] lastObject];
    }
    return self;
}

- (void)show:(UIView *)parentView
{
    // 加到主界面中
    [self.launchView setFrame:CGRectMake(parentView.frame.origin.x, parentView.frame.origin.x
                                         , parentView.frame.size.width, parentView.frame.size.height)];
    
    [parentView addSubview:self.launchView];
    [parentView bringSubviewToFront:self.launchView];
}

- (void)hide
{
    [self.launchView removeFromSuperview];
}


@end
