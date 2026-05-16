//telegram @wz662
#import <Foundation/Foundation.h>
#import "AlarmDto.h"

@interface BBSAlarmDataObservable : NSObject

@property (nonatomic, retain) AlarmDto *data;
@property (nonatomic, copy) ObserverCompletion observer;

- (void) setData:(NSString *)title msg:(NSString *)msg date:(NSDate *)date fid:(NSString *)friendUID flagNum:(NSString *)flagNum;
- (int) getFlagNum;
- (void) resetFlagNum;
- (void) notifyObserver;

@end
