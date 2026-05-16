//telegram @wz662
//
//  Utils.m
//  RainbowChat4i
//
//  Created by JackJiang on 2018/3/20.
//  Copyright © 2018年 JackJiang. All rights reserved.
//

#import "Utils.h"

@implementation Utils


//+ (int)getDurationFromVoiceFileName:(NSString *)voiceFileName
//{
//    int duration = 0;
//    NSRange range = [voiceFileName rangeOfString:@"_"];
//    if(voiceFileName != nil && range.location != NSNotFound)
//    {
//        NSString *durationStr = [voiceFileName substringToIndex:range.location];
//
//        @try
//        {
//            long durationInMillsecond = [durationStr longLongValue];
//
//            // 返回的时长需要转换成秒（而非毫秒）
//            duration = (int)(durationInMillsecond / 1000);
//        }
//        @catch (NSException *exception)
//        {
//            NSLog(@"%@",exception);
//        }
//    }
//    return duration;
//}

//+ (NSString *)timestampString:(NSTimeInterval)currentTime forDuration:(NSTimeInterval)duration
//{
//    // print the time as 0:ss or ss.x up to 59 seconds
//    // print the time as m:ss up to 59:59 seconds
//    // print the time as h:mm:ss for anything longer
//    if (duration < 60) {
//        //        if (self.audioViewAttributes.showFractionalSeconds)
//        //        {
//        //            return [NSString stringWithFormat:@"%.01f", currentTime];
//        //        }
//        //        else
//        if (currentTime < duration) {
//            return [NSString stringWithFormat:@"0:%02d", (int)round(currentTime)];
//        }
//        return [NSString stringWithFormat:@"0:%02d", (int)ceil(currentTime)];
//    }
//    else if (duration < 3600) {
//        return [NSString stringWithFormat:@"%d:%02d", (int)currentTime / 60, (int)currentTime % 60];
//    }
//    return [NSString stringWithFormat:@"%d:%02d:%02d", (int)currentTime / 3600, (int)currentTime / 60, (int)currentTime % 60];
//}



@end
