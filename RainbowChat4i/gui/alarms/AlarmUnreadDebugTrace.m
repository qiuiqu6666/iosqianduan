//telegram @wz662
#import "AlarmUnreadDebugTrace.h"

NSString * const AlarmUnreadDebugTargetUid = @"400069";
NSString * const AlarmUnreadDebugTraceDidAppendNotification = @"AlarmUnreadDebugTraceDidAppendNotification";

@implementation AlarmUnreadDebugTrace

+ (BOOL)isTargetUid:(NSString *)uid
{
    return uid.length > 0 && [uid isEqualToString:AlarmUnreadDebugTargetUid];
}

+ (void)appendLine:(NSString *)line source:(NSString *)source forUid:(NSString *)uid
{
    if (![self isTargetUid:uid]) return;

    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm:ss.SSS";
    NSString *ts = [fmt stringFromDate:[NSDate date]];
    NSString *src = (source.length > 0) ? source : @"?";
    NSString *body = (line.length > 0) ? line : @"";
    NSString *full = [NSString stringWithFormat:@"[%@] %@ | %@", ts, src, body];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:AlarmUnreadDebugTraceDidAppendNotification
                                                              object:nil
                                                            userInfo:@{ @"text": full }];
    });
}

@end
