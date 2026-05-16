//telegram @wz662
#import "OfflineMsgDTO.h"

@implementation OfflineMsgDTO

- (NSString *)getHistoryTime2ForDefaultTimeZone_hhmm
{
    return [TimeTool convertJavaTimestampToiOSTimeStr:self.history_time2 convertTo:@"HH:mm"];
}

- (NSString *)getHistoryTime2ForDefaultTimeZone
{
    return [TimeTool convertJavaTimestampToiOSTimeStr:self.history_time2 convertTo:@"MM-dd HH:mm"];
}

- (NSDate *)getHistoryTime2Date
{
    return [TimeTool convertJavaTimestampToiOSDate:self.history_time2];
}

@end
