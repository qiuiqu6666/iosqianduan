//telegram @wz662
#import <Foundation/Foundation.h>

@interface TimeTool : NSObject

///**
// 读取并返回指定文件路径处视频文件的视频时长（单位：秒）。
// 
// @param filePath 视频文件的绝对路径
// @return 视频时长（单位：秒），如果获取失败等则返回0
// @since 7.0
// */
//+ (int)getDurationFromVideoFile:(NSString *)filePath;

/**
 * 返回指定语音文件名中包含的语音时长数据（根据语音文件的生成规则，时长是包含在文件名里的）。
 * <p>
 * 注：此文件名指的是最终发送的和接收的语音文件名，而非临时文件名（临时文件名没有时长信息）.
 *
 * @param voiceFileName 形如：120000_ad3434fdsfsd432432fsdfs.amr的语音文件名，120000是语音时长（单位：毫秒）
 * @return 解析出的语音时长（单位：秒）
 */
+ (int)getDurationFromVoiceFileName:(NSString *)voiceFileName;

/**
 返回语音文件时长的人类友好可读形式的字符串。

 @param duration 文件时长（单位：秒）
 @return 友好字符串，形如：65''，表示65秒
 */
+ (NSString *)getVoiceDurationHuman:(int)duration;

/**
 传入秒数，得到“mm:ss”样的字符串。
 参考资料：https://www.jianshu.com/p/9c0479b50192

 @param durationWithSecond 秒数
 @return 友好字符串，形如：“mm:ss”
 */
+ (NSString *)getMMSSFromSS:(int)durationWithSecond;

/** 音视频通话时长：≤0→00:00，<1h→mm:ss，≥1h→hh:mm:ss */
+ (NSString *)getVoipDurationFromSS:(int)seconds;

///**
// 显示一个人性化的时间字串。
// 当此时间是当天时间则显示“时分”格式，如果是当年则显示“月时分”格式，如果是今年之前的则显示为“年月时分”格式。
// 本方法当前主要用于首页“消息界面”中显示离线消息的时间之用，目的是让时间显示尽可能短且人性化，仅此而已。
//
// @param dt NSDate对象
// @return 返回形如“12:01"、“03-01 12：01”、“2018-02-01 12：01”
// */
//+ (NSString *)getTimeStringAutoShort:(NSDate *)dt;

/**
 * 仿照微信中的消息时间显示逻辑，将时间戳（单位：毫秒）转换为友好的显示格式.
 *
 * 1）7天之内的日期显示逻辑是：今天(“HH:mm”)、昨天(-1d)、前天(-2d)、星期？（只显示总计7天之内的星期数，即<=-4d）；<br>
 * 2）7天之外（即>7天）的逻辑：当年(显示“M月/d日”)、去年及之前(显示“yy年/M月/d日”)。
 *
 * @param dt 日期时间对象（本次被判断对象）
 * @param mustIncludeTime true表示非“当天”的日期在需要时会附加“时间:分钟”等；为 false 时“当天”仍显示“HH:mm”，非当天按各段规则不单独拼时分（与历史实现一致）
 * @param timeWithSegmentStr 本参数仅在mustIncludeTime=true时有生效，表示在时间字符串前带上“上午”、“下午”、“晚上”这样的描述
 * @return 输出格式形如：“14:30”（当天）、“上午10:30”（mustIncludeTime 且当天）、“昨天”、“昨天 中午12:04”（mustIncludeTime）、“星期二”等
 * @since 1.3
 */
+ (NSString *)getTimeStringAutoShort2:(NSDate *)dt mustIncludeTime:(BOOL)mustIncludeTime timeWithSegment:(BOOL)timeWithSegmentStr;

/**
 * 获取仅包含“时间:分钟”部分的字符串，24小时制，且可以显示“上午”、“下午”、“晚上”这样的描述。
 *
 * @param srcDate 原始时间
 * @param timeWithSegmentStr 表示在时间字符串前带上“上午”、“下午”、“晚上”这样的描述
 * @return 如果成功则返回结果，否则返回空字符串（不是null）
 */
+ (NSString *)getTimeHH24Human:(NSDate *)srcDate timeWithSegment:(BOOL)timeWithSegmentStr;

/**
 * 将一个两位24小时时间的转换为上午、下午这样的描述。
 *
 * @param hh24 两位的24小时制时间的小时部分
 * @return 如果成功转换则返回形如：“凌晨”、“上午”等，否则返回空字符串（不是null）
 * @since 7.1
 */
+ (NSString *)getTimeSegmentStr:(NSString *)hh24;

+ (NSString *)getTimeString:(NSDate *)dt format:(NSString *)fmt;
+ (NSString*)getCurrentDatePartStr;//:(NSDate*)date;
+ (NSString*)getCurrentTimePartStr;

/*!
 *  返回时间戳（单位：毫秒）。
 *
 *  @return 形如：1414074342829.249023
 */
+ (NSTimeInterval) getTimeStampWithMillisecond:(NSDate *)dat;

/*!
 *  返回系统时间戳（单位：毫秒），long表示。
 *
 *  @return 形如：1414074342829
 */
+ (long) getTimeStampWithMillisecond_l:(NSDate *)dat;

/**
 * 获得iOS当前系统时间的NSDate对象。
 */
+ (NSDate*)getIOSDefaultDate;

/**
 * 获得iOS的当前系统时间戳（格式遵从ios的习惯，以秒为单位）。
 */
+ (NSTimeInterval) getIOSDefaultTimeStamp;
/**
 * 获得iOS的当前系统时间戳的long形式（格式遵从ios的习惯，以秒为单位，形如：1485159493）。
 */
+ (long) getIOSDefaultTimeStamp_l;

/**
 * 获得指定NSDate对象iOS时间戳（格式遵从ios的习惯，以秒为单位）。
 */
+ (NSTimeInterval) getIOSTimeStamp:(NSDate *)dat;
/**
 * 获得指定NSDate对象iOS时间戳的long形式（格式遵从ios的习惯，以秒为单位，形如：1485159493）。
 */
+ (long) getIOSTimeStamp_l:(NSDate *)dat;

/**
 * 将字符串形式的ios时间戳转成NSDate对象。
 *
 * @param iOSTimestamp 形如：“1485159493”字符串样式的ios时间戳
 */
+ (NSDate *)convertIOSTimestampStrToiOSDate:(NSString *)iOSTimestamp;

/**
 * 将long形式的ios时间戳转成NSDate对象。
 *
 * @param iOSTimestamp 形如：1485159493长整形的ios时间戳
 */
+ (NSDate *)convertIOSTimestampToiOSDate:(long)iOSTimestamp;

/**
 将Java语言的时间戳转成iOS上的NSDate对象。

 @param javaTimestamp java的时间戳形如：1489389496075（除1000后才是ios上的时间戳单位匹配）
 @return 如果转换失败则返回nil，否则返回ios的NSDate对象
 */
+ (NSDate *)convertJavaTimestampToiOSDate:(NSString *)javaTimestamp;

/// 与服务端 msg_time2 / Java 毫秒一致（用于已读水位、chat_msg.date 存库）
+ (long long)javaMillisFromNSDate:(NSDate *)date;

/// 读取 chat_msg / groupchat_msg 的 date 列：新库为 Java 毫秒整数，旧库为秒级整数（小于 1e11）
+ (NSDate *)dateFromChatHistoryStoredTime:(long long)stored;

/**
 将Java语言的时间戳转成iOS上的时间字符串。

 @param javaTimestamp java的时间戳形如：1489389496075（除1000后才是ios上的时间戳单位匹配）
 @param timePattern 形如“YYYY-MM-dd HH:mm:ss”等
 @return 如果转换失败则返回nil，否则返回ios的时间字符串
 */
+ (NSString *)convertJavaTimestampToiOSTimeStr:(NSString *)javaTimestamp convertTo:(NSString *)timePattern;

@end
