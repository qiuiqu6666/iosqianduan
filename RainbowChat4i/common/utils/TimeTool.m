//telegram @wz662
#import "TimeTool.h"
#import <math.h>
#import <AVFoundation/AVFoundation.h>

@implementation TimeTool

//// 读取并返回指定文件路径处视频文件的视频时长（单位：秒）
//+ (int)getDurationFromVideoFile:(NSString *)filePath
//{
//    int duration = 0;
//    @try {
//        NSURL *videoUrl = [NSURL URLWithString:filePath];
//        AVURLAsset *avUrl = [AVURLAsset assetWithURL:videoUrl];
//        CMTime time = [avUrl duration];
//        duration = ceil(time.value/time.timescale);
//    } @catch (NSException *exception) {
//        NSLog(@"getDurationFromVideoFile时出错了：%@",exception);
//    }
//    
//    return duration;
//}

// 返回指定语音文件名中包含的语音时长数据（根据语音文件的生成规则，时长是包含在文件名里的）
+ (int)getDurationFromVoiceFileName:(NSString *)voiceFileName
{
    int duration = 0;
    NSRange range = [voiceFileName rangeOfString:@"_"];
    if(voiceFileName != nil && range.location != NSNotFound)
    {
        NSString *durationStr = [voiceFileName substringToIndex:range.location];

        @try
        {
            long long durationInMillsecond = [durationStr longLongValue];

            // 返回的时长需要转换成秒（而非毫秒）
            duration = (int)(durationInMillsecond / 1000);
            
            // 防止不足1秒时，被舍入为0
            if(duration == 0)
                duration = 1;
        }
        @catch (NSException *exception)
        {
            NSLog(@"%@",exception);
        }
    }
    return duration;
}

// 返回语音文件时长的人类友好可读形式的字符串
+ (NSString *)getVoiceDurationHuman:(int)duration
{
    if(duration <0)
        duration = 0;

    // 显示语音时长（形如：65''，表示65秒）
    return [NSString stringWithFormat:@"%d''", duration];
}

// 传入秒数，得到“mm:ss”样的字符串
+ (NSString *)getMMSSFromSS:(int)durationWithSecond
{
    if(durationWithSecond < 0){
        return @"00:00";
    }

    //format of minute
    NSString *str_minute = [NSString stringWithFormat:@"%d", durationWithSecond / 60];
    //format of second
    NSString *str_second = [NSString stringWithFormat:@"%02d", durationWithSecond % 60];
    //format of time
    NSString *format_time = [NSString stringWithFormat:@"%@:%@", str_minute, str_second];
    return format_time;
}

/// 音视频通话时长展示：≤0 为 00:00，<1h 为 mm:ss，≥1h 为 hh:mm:ss（对接文档 v1.0 第五节）
+ (NSString *)getVoipDurationFromSS:(int)seconds
{
    if (seconds <= 0) return @"00:00";
    int h = seconds / 3600;
    int m = (seconds % 3600) / 60;
    int s = seconds % 60;
    if (h > 0) {
        return [NSString stringWithFormat:@"%02d:%02d:%02d", h, m, s];
    }
    return [NSString stringWithFormat:@"%02d:%02d", m, s];
}

//// 显示一个人性化的时间字串
//+ (NSString *)getTimeStringAutoShort:(NSDate *)dt
//{
//    NSString *ret = nil;
//
//    NSCalendar *calendar = [NSCalendar currentCalendar];
//
//    NSDate  *currentDate = [NSDate date];
//    NSDateComponents *curComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSWeekdayCalendarUnit fromDate:currentDate];
//    NSInteger currentYear=[curComponents year];
//    NSInteger currentMonth=[curComponents month];
//    NSInteger currentDay=[curComponents day];
////    NSLog(@"【DEBUG-getTimeStringAutoShort】currentDate = %@ ,year = %ld ,month=%ld, day=%ld",currentDate,currentYear,currentMonth,currentDay);
//
//    NSDateComponents *srcComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:dt];
//    NSInteger srcYear=[srcComponents year];
//    NSInteger srcMonth=[srcComponents month];
//    NSInteger srcDay=[srcComponents day];
////    NSLog(@"【DEBUG-getTimeStringAutoShort】dt = %@ ,year = %ld ,month=%ld, day=%ld",dt,srcYear,srcMonth,srcDay);
//
//    // 当年
//    if(currentYear == srcYear)
//    {
//        long currentTimestamp = [TimeTool getIOSTimeStamp_l:currentDate];
//        long srcTimestamp = [TimeTool getIOSTimeStamp_l:dt];
//
//        // 相差时间（单位：秒）
//        long delta = currentTimestamp - srcTimestamp;
//
//        // 当天
//        if(currentMonth == srcMonth && currentDay == srcDay)
//        {
//            // 时间相差60秒以内
//            if(delta < 60)
//            {
//                ret = @"刚刚";
//            }
//            else
//            {
//                ret = [TimeTool getTimeString:dt format:@"HH:mm"];
//            }
//        }
//        // 当年 && 当前之外的时间
//        else
//        {
//            if ((delta/3600) > 24 && (delta/3600) < 48)
//                ret = @"昨天";
//            else if ((delta/3600) > 48 && (delta/3600) < 72)
//                ret = @"前天";
//            else
//                ret = [TimeTool getTimeString:dt format:@"M/d"];
//        }
//    }
//    else
//    {
//        ret = [TimeTool getTimeString:dt format:@"yy/M/d"];
//    }
//
////    NSLog(@"【DEBUG-getTimeStringAutoShort】计算结果：%@ 【OK】", ret);
//
//    return ret;
//}

// 仿照微信的逻辑，显示一个人性化的时间字串
+ (NSString *)getTimeStringAutoShort2:(NSDate *)dt mustIncludeTime:(BOOL)mustIncludeTime timeWithSegment:(BOOL)timeWithSegmentStr
{
    NSString *ret = nil;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    // 当前时间
    NSDate  *currentDate = [NSDate date];
    NSDateComponents *curComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekday fromDate:currentDate];
    NSInteger currentYear=[curComponents year];
    NSInteger currentMonth=[curComponents month];
    NSInteger currentDay=[curComponents day];
//    NSLog(@"【[1] DEBUG-getTimeStringAutoShort】currentDate = %@ ,year = %ld ,month=%ld, day=%ld,  星期=%ld,B=%ld"
//          ,currentDate,currentYear,currentMonth,currentDay, [curComponents weekday], [curComponents weekdayOrdinal]);
    
    // 目标判断时间
    NSDateComponents *srcComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekday fromDate:dt];
    NSInteger srcYear=[srcComponents year];
    NSInteger srcMonth=[srcComponents month];
    NSInteger srcDay=[srcComponents day];
//    NSLog(@"【[2] DEBUG-getTimeStringAutoShort】dt = %@ ,year = %ld ,month=%ld, day=%ld,  星期=%ld,B=%ld"
//          ,dt,srcYear,srcMonth,srcDay, [curComponents weekday], [curComponents weekdayOrdinal]);
    
    // 要额外显示的时间分钟
    NSString *timeExtraStr = @"";
    if(mustIncludeTime)
    {
//      NSString *timeExtraStr = (mustIncludeTime?[TimeTool getTimeString:dt format:@" HH:mm"]:@"");// TODO
        timeExtraStr = [NSString stringWithFormat:@" %@", [TimeTool getTimeHH24Human:dt timeWithSegment:timeWithSegmentStr]];
    }
    
    // 当年
    if(currentYear == srcYear)
    {
        long currentTimestamp = [TimeTool getIOSTimeStamp_l:currentDate];
        long srcTimestamp = [TimeTool getIOSTimeStamp_l:dt];
        
        // 相差时间（单位：秒）
        long delta = currentTimestamp - srcTimestamp;
        
        // 当天（月份和日期一致才是）
        if(currentMonth == srcMonth && currentDay == srcDay) {
            if (mustIncludeTime) {
                // 需要显示时分时：当天显示时间分钟 + 上午/下午描述
                ret = [TimeTool getTimeHH24Human:dt timeWithSegment:YES];
            } else {
                // 首页消息列表等：当天不显示“今天”，直接显示 时:分，便于区分当日各条
                ret = [TimeTool getTimeHH24Human:dt timeWithSegment:NO];
            }
        }
        // 当年 && 当天之外的时间（即昨天及以前的时间）
        else {
            // 昨天（以“现在”的时候为基准-1天）
            NSDate *yesterdayDate = [NSDate date];
            yesterdayDate = [NSDate dateWithTimeInterval:-24*60*60 sinceDate:yesterdayDate];
            
            NSDateComponents *yesterdayComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:yesterdayDate];
            NSInteger yesterdayMonth=[yesterdayComponents month];
            NSInteger yesterdayDay=[yesterdayComponents day];
            
            // 前天（以“现在”的时候为基准-2天）
            NSDate *beforeYesterdayDate = [NSDate date];
            beforeYesterdayDate = [NSDate dateWithTimeInterval:-48*60*60 sinceDate:beforeYesterdayDate];

            NSDateComponents *beforeYesterdayComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:beforeYesterdayDate];
            NSInteger beforeYesterdayMonth=[beforeYesterdayComponents month];
            NSInteger beforeYesterdayDay=[beforeYesterdayComponents day];
            
            // 用目标日期的“月”和“天”跟上方计算出来的“昨天”进行比较，是最为准确的（如果用时间戳差值
            // 的形式，是不准确的，比如：现在时刻是2019年02月22日1:00、而srcDate是2019年02月21日23:00，
            // 这两者间只相差2小时，直接用“delta/3600” > 24小时来判断是否昨天，就完全是扯蛋的逻辑了）
            if(srcMonth == yesterdayMonth && srcDay == yesterdayDay)
                ret = [NSString stringWithFormat:@"昨天%@", timeExtraStr];// -1d
            // “前天”判断逻辑同上
            else if(srcMonth == beforeYesterdayMonth && srcDay == beforeYesterdayDay)
                ret = [NSString stringWithFormat:@"前天%@", timeExtraStr];// -2d
            else{
                // 跟当前时间相差的小时数
                long deltaHour = (delta/3600);
                
                // 如果小于或等 7*24小时就显示星期几
                if (deltaHour <= 7*24){
                    NSArray<NSString *> *weekdayAry = [NSArray arrayWithObjects:@"星期日", @"星期一", @"星期二", @"星期三", @"星期四", @"星期五", @"星期六", nil];
                    NSInteger srcWeekday=[srcComponents weekday]; // 取出的星期数：1表示星期天，2表示星期一，3表示星期二。。。。 6表示星期五，7表示星期六

                    // 取出当前是星期几
                    NSString *weedayDesc = [weekdayAry objectAtIndex:(srcWeekday-1)];
                    ret = [NSString stringWithFormat:@"%@%@", weedayDesc, timeExtraStr];
                }
                // 否则直接显示完整日期时间
                else
                    ret = [NSString stringWithFormat:@"%@%@", [TimeTool getTimeString:dt format:([BasicTool isChinese]?@"M月d日":@"M/d")], timeExtraStr];
            }
        }
    }
    // 往年
    else{
        ret = [NSString stringWithFormat:@"%@%@", [TimeTool getTimeString:dt format:@"yy/M/d"], timeExtraStr];
    }
    
//  NSLog(@"【DEBUG-getTimeStringAutoShort】计算结果：%@ 【OK】", ret);
    
    return ret;
}

// 获取仅包含“时间:分钟”部分的字符串，24小时制，且可以显示“上午”、“下午”、“晚上”这样的描述。
+ (NSString *)getTimeHH24Human:(NSDate *)srcDate timeWithSegment:(BOOL)timeWithSegmentStr
{
    NSString *ret = @"";
        
    NSString *timePattern = @"HH:mm";
    // 原始的时间分钟字符串
    NSString *timeStr = [TimeTool getTimeString:srcDate format:timePattern];

    // 时间段描述（形如：“上午”、“下午”、“晚上”这样的描述），只在中文语言下生效
    NSString *timeSegmentStr = @"";
    if(timeWithSegmentStr)
        timeSegmentStr = ([BasicTool isChinese]? [TimeTool getTimeSegmentStr:timeStr]:@"");
                
    // 组合成最终的人性化时间分钟字符串形式
    ret = [NSString stringWithFormat:@"%@%@",timeSegmentStr, timeStr];
    
    return ret;
}

// 将一个两位24小时时间的转换为上午、下午这样的描述。
+ (NSString *)getTimeSegmentStr:(NSString *)hh24
{
    NSString *ret = @"";
    if(hh24 != nil && [hh24 length] >= 2)
    {
        // 取出“小时”部分
        int a = [BasicTool getIntValue:[hh24 substringToIndex:2] defaultVal:0];
        if (a >= 0 && a <= 6) {
            ret = @"凌晨";
        }
        else if (a > 6 && a <= 12) {
            ret = @"上午";
        }
        else if (a > 12 && a <= 13) {
            ret = @"中午";
        }
        else if (a > 13 && a <= 18) {
            ret = @"下午";
        }
        else if (a > 18 && a <= 24) {
            ret = @"晚上";
        }
    }
    
    return ret;
}



+ (NSString *)getTimeString:(NSDate *)dt format:(NSString *)fmt
{
    NSDateFormatter* format = [[NSDateFormatter alloc] init];
    [format setDateFormat:fmt];
    return [format stringFromDate:(dt==nil?[TimeTool getIOSDefaultDate]:dt)];
}

+ (NSString*)getCurrentDatePartStr//:(NSDate*)date
{
    //    NSDateFormatter* format = [[NSDateFormatter alloc] init];
    //    [format setDateFormat:@"yyyy-MM-dd"];
    //    return [format stringFromDate:[NSDate date]];//date];
    return [TimeTool getTimeString:[NSDate date] format:@"yyyy-MM-dd"];
}

+ (NSString*)getCurrentTimePartStr//:(NSDate*)time
{
    //    NSDateFormatter* format = [[NSDateFormatter alloc] init];
    //    [format setDateFormat:@"HH:mm"];
    //    return [format stringFromDate:[NSDate date]];//time];
    return [TimeTool getTimeString:[NSDate date] format:@"HH:mm"];
}

+ (NSTimeInterval) getTimeStampWithMillisecond:(NSDate *)dat
{
//    NSDate* dat = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval a = [dat timeIntervalSince1970] * 1000;
    return a;
}

+ (long) getTimeStampWithMillisecond_l:(NSDate *)dat
{
    return [[NSNumber numberWithDouble:[TimeTool getTimeStampWithMillisecond:dat]] longValue];
}

+ (NSDate*)getIOSDefaultDate
{
    return [NSDate date];
}

+ (NSTimeInterval) getIOSDefaultTimeStamp
{
//    NSDate* dat = [NSDate dateWithTimeIntervalSinceNow:0];
    NSDate *dat = [TimeTool getIOSDefaultDate];
    NSTimeInterval a = [dat timeIntervalSince1970];
    return a;
}
+ (long) getIOSDefaultTimeStamp_l
{
    return [[NSNumber numberWithDouble:[TimeTool getIOSDefaultTimeStamp]] longValue];
}

+ (NSTimeInterval) getIOSTimeStamp:(NSDate *)dat
{
    //    NSDate* dat = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval a = [dat timeIntervalSince1970];
    return a;
}
+ (long) getIOSTimeStamp_l:(NSDate *)dat
{
    return [[NSNumber numberWithDouble:[TimeTool getIOSTimeStamp:dat]] longValue];
}

+ (NSDate *)convertIOSTimestampStrToiOSDate:(NSString *)iOSTimestamp
{
    NSDate *dt = nil;
    if(iOSTimestamp != nil)
    {
        // ios的时间戳形如：1489389496.075
        long tmForiOS = [iOSTimestamp doubleValue];
        dt = [TimeTool convertIOSTimestampToiOSDate:tmForiOS];
//      NSLog(@"时间戳转化时间date对象 >>> %@", [dt description]);
    }

    return dt;
}

+ (NSDate *)convertIOSTimestampToiOSDate:(long)iOSTimestamp
{
    NSDate *dt = nil;
    dt = [NSDate dateWithTimeIntervalSince1970:(iOSTimestamp)];
//  NSLog(@"时间戳转化时间date对象 >>> %@", [dt description]);

    return dt;
}

+ (NSDate *)convertJavaTimestampToiOSDate:(NSString *)javaTimestamp
{
    NSDate *dt = nil;
    if(javaTimestamp != nil)
    {
        // java的时间戳形如：1489389496075，除1000后才是ios上的时间戳单位匹配
        // 使用 double 运算保留精度（long 在32位设备上可能溢出）
        double tmForiOS = [javaTimestamp doubleValue] / 1000.0;
        dt = [NSDate dateWithTimeIntervalSince1970:tmForiOS];
//      NSLog(@"时间戳转化时间date对象 >>> javaTimestamp=%@, tmForiOS=%f, date=%@", javaTimestamp, tmForiOS, [dt description]);
    }

    return dt;
}

+ (NSString *)convertJavaTimestampToiOSTimeStr:(NSString *)javaTimestamp convertTo:(NSString *)timePattern
{
    NSString *timeStr = nil;
    if(javaTimestamp != nil)
    {
        //获取系统时间
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        //获取系统时区 **此时不设置时区是默认为系统时区
        formatter.timeZone = [NSTimeZone systemTimeZone];
        //指定时间显示样式: HH表示24小时制 hh表示12小时制
        [formatter setDateFormat:timePattern];//@"YYYY-MM-dd HH:mm:ss"];

        NSDate *stampDate2 = [TimeTool convertJavaTimestampToiOSDate:javaTimestamp];

//        NSLog(@"时间戳转化时间 >>> %@",[formatter stringFromDate:stampDate2]);

        timeStr = [formatter stringFromDate:stampDate2];
    }

    return timeStr;
}

+ (long long)javaMillisFromNSDate:(NSDate *)date
{
    if (date == nil) return 0;
    return (long long)llround([date timeIntervalSince1970] * 1000.0);
}

+ (NSDate *)dateFromChatHistoryStoredTime:(long long)stored
{
    if (stored <= 0) {
        return [NSDate date];
    }
    // 旧版写入为「秒」整数（约 1.7e9）；新版为「Java 毫秒」（约 1.7e12），与 missu_msg.msg_time2 / 已读水位对齐
    if (stored < 100000000000LL) {
        return [NSDate dateWithTimeIntervalSince1970:(double)stored];
    }
    return [NSDate dateWithTimeIntervalSince1970:(double)stored / 1000.0];
}

@end
