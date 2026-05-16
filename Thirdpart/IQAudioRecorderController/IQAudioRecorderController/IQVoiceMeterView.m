//telegram @wz662
//
//  IQVoiceMeterView.m
//  RainbowChat4i
//
//  Created by JackJiang.
//  Copyright © 2018年 JackJiang. All rights reserved.
//

#import "IQVoiceMeterView.h"


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 静态变量
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static NSArray *_images = nil;


@interface IQVoiceMeterView ()
{
//    NSArray *_images;
}
@end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation IQVoiceMeterView


+ (void) preloadImages
{
    if(_images == nil)
    {
        NSTimeInterval s = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;

        _images = @[
                    [UIImage imageNamed:@"record_animate2_01"],//[UIImage imageNamed:@"record_animate_01"],
    //              [UIImage imageNamed:@"record_animate_02"],
                    [UIImage imageNamed:@"record_animate2_03"],
    //              UIImage imageNamed:@"record_animate_04"],
                    [UIImage imageNamed:@"record_animate2_05"],
    //              [UIImage imageNamed:@"record_animate_06"],
                    [UIImage imageNamed:@"record_animate2_07"],
    //              [UIImage imageNamed:@"record_animate_08"],
                    [UIImage imageNamed:@"record_animate2_09"],
    //              [UIImage imageNamed:@"record_animate_10"],
                    [UIImage imageNamed:@"record_animate2_11"],
    //              [UIImage imageNamed:@"record_animate_12"],
                    [UIImage imageNamed:@"record_animate2_13"],
                    [UIImage imageNamed:@"record_animate2_14"]
                    ];

        NSTimeInterval e = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
        NSLog(@"[IQVoiceMeterView-preloadImages] 图片预加载代码执行耗时：%f ms", (e - s));
    }
}

- (instancetype)initWithFrame:(CGRect)frame
{
    
    if (self = [super initWithFrame:frame]) {

        NSTimeInterval s = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;

//        _images                   = @[
//                                      [UIImage imageNamed:@"record_animate_01"],
////                                      [UIImage imageNamed:@"record_animate_02"],
//                                      [UIImage imageNamed:@"record_animate_03"],
////                                    [UIImage imageNamed:@"record_animate_04"],
//                                      [UIImage imageNamed:@"record_animate_05"],
////                                    [UIImage imageNamed:@"record_animate_06"],
//                                      [UIImage imageNamed:@"record_animate_07"],
////                                    [UIImage imageNamed:@"record_animate_08"],
//                                      [UIImage imageNamed:@"record_animate_09"],
////                                    [UIImage imageNamed:@"record_animate_10"],
//                                      [UIImage imageNamed:@"record_animate_11"],
////                                    [UIImage imageNamed:@"record_animate_12"],
//                                      [UIImage imageNamed:@"record_animate_13"],
//                                      [UIImage imageNamed:@"record_animate_14"]
//                                      ];

        [IQVoiceMeterView preloadImages];

         NSTimeInterval e = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;

        NSLog(@"以上代码执行耗时：%f ms", (e - s));
    }
    return self;
}

// 是0~160的音量值：160表示最高音量
- (void)setProgress:(CGFloat)progress
{
    _progress = MIN(MAX(progress, 0.f),160.f);
    [self updateImages];
}

- (void)updateImages
{
    if (_progress == 0) {
        self.image = _images[0];
        return;
    }

    if(_progress <= 115)
        self.image = _images[0];
    else if(_progress > 115 && _progress <= 125)
        self.image = _images[1];
//    else if(_progress > 120 && _progress <= 125)
//        self.image = _images[2];
    else if(_progress > 125 && _progress <= 130)
        self.image = _images[2];
    else if(_progress > 130 && _progress <= 135)
        self.image = _images[3];
    else if(_progress > 135 && _progress <= 140)
        self.image = _images[4];
    else if(_progress > 140 && _progress <= 145)
        self.image = _images[5];
    else if(_progress > 145 && _progress <= 150)
        self.image = _images[6];
    else if(_progress > 150 && _progress <= 160)
        self.image = _images[7];
//    else if(_progress > 155 && _progress <= 160)
//        self.image = _images[9];
}

@end
