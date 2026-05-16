//telegram @wz662
//
//  IQVoiceMeterView.h
//  RainbowChat4i
//
//  Created by JackJiang.
//  Copyright © 2018年 JackJiang. All rights reserved.
//
//  录音时的声音频谱动画图片组件。

#import <UIKit/UIKit.h>

@interface IQVoiceMeterView : UIImageView

@property (nonatomic, assign) CGFloat progress;

/**
 根据Instrument性能调优化数据显示："UIImage imageNamed:"首次加载一个图片的耗时大约为20秒，
 在语音留言录音这种场景下，因为动画图片比较多，而且需要快递打开界面（否则用户会觉得“卡”），所以
 本方法的就目的就是提供在用户下次打开录音界面前就把图片加载好了，从而省下这100多毫秒的延迟，虽然不
 多，但积少成多，体验就是这样的努力中得到提升的。
 */
+ (void) preloadImages;

@end
