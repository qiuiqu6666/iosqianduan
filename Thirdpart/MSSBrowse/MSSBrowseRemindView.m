//telegram @wz662
//
//  MSSBrowseRemindView.m
//  MSSBrowse
//
//  Created by 于威 on 16/2/14.
//  Copyright © 2016年 于威. All rights reserved.
//

#import "MSSBrowseRemindView.h"
#import "UIView+MSSLayout.h"

@interface MSSBrowseRemindView ()

@property (nonatomic,strong)UILabel *remindLabel;
@property (nonatomic,strong)UIView *maskViewX;// Bug FIX 20250218：将原maskView重命名为maskViewX，解决ios18.1上查看图片就崩溃的问题，详见：https://www.jianshu.com/p/9c02234cdbef

@end

@implementation MSSBrowseRemindView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        [self createRemindView];
    }
    return self;
}

- (void)createRemindView
{
    self.alpha = 0;
    
    _maskViewX = [[UIView alloc]init];
    _maskViewX.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    _maskViewX.backgroundColor = [UIColor blackColor];
    _maskViewX.alpha = 0.5f;
    _maskViewX.layer.cornerRadius = 5.0f;
    _maskViewX.layer.masksToBounds = YES;
    [self addSubview:_maskViewX];
    
    _remindLabel = [[UILabel alloc]init];
    _remindLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    _remindLabel.font = [UIFont boldSystemFontOfSize:14.0f];
    _remindLabel.textColor = [UIColor whiteColor];
    [self addSubview:_remindLabel];
}

- (void)showRemindViewWithText:(NSString *)text
{
    CGRect textRect = [text boundingRectWithSize:CGSizeMake(MAXFLOAT,MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:_remindLabel.font} context:nil];
    CGSize size = textRect.size;
    [_maskViewX mss_setFrameInSuperViewCenterWithSize:CGSizeMake(size.width + 20, size.height + 40)];
    [_remindLabel mss_setFrameInSuperViewCenterWithSize:CGSizeMake(size.width, size.height)];
    _remindLabel.text = text;
    self.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 1;
    }];
}

- (void)hideRemindView
{
    self.alpha = 1;
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
    }completion:^(BOOL finished) {
        
    }];
}

@end
