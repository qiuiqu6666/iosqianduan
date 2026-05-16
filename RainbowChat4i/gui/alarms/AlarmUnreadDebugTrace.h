//telegram @wz662
#import <Foundation/Foundation.h>

/// 仅用于会话列表页调试：追踪指定 UID 的未读写入链路（默认 400069）
FOUNDATION_EXPORT NSString * const AlarmUnreadDebugTargetUid;
FOUNDATION_EXPORT NSString * const AlarmUnreadDebugTraceDidAppendNotification;

@interface AlarmUnreadDebugTrace : NSObject

+ (BOOL)isTargetUid:(NSString *)uid;

/// line 为简短说明；仅当 uid 与 AlarmUnreadDebugTargetUid 一致时才会广播并显示
+ (void)appendLine:(NSString *)line source:(NSString *)source forUid:(NSString *)uid;

@end
