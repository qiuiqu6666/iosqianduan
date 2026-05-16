//telegram @wz662
#import "BBSAlarmDataObservable.h"
#import "BasicTool.h"

@implementation BBSAlarmDataObservable


- (void) setData:(NSString *)title msg:(NSString *)msg date:(NSDate *)date fid:(NSString *)friendUID flagNum:(NSString *)flagNum
{
    if(self.data == nil)
        self.data = [[AlarmDto alloc] init];

    self.data.dataId = friendUID;
    self.data.title = title;
    self.data.alarmContent = msg;
    self.data.date = date;
//    self.data.extraObj = friendUID; // 额外对象字段存放的是发消息人的uid
    self.data.flagNum = flagNum;

    [self notifyObserver];
}

- (int) getFlagNum
{
    return [BasicTool getIntValue:self.data == nil ? @"0": self.data.flagNum];
}

- (void) resetFlagNum
{
    if(self.data != nil)
    {
        self.data.flagNum = @"0";
        [self notifyObserver];
    }
}

- (void) notifyObserver
{
    if(self.observer != nil)
        self.observer(nil, self.data);
    //  observer.update(null, data);
}

@end
