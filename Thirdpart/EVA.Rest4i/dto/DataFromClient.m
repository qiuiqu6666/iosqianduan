//telegram @wz662
#import "DataFromClient.h"

@implementation DataFromClient

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.doInput = YES;
        self.processorId = -9999999;
        self.jobDispatchId = -9999999;
        self.actionId = -9999999;
        self.device = -1;
    }
    return self;
}



@end
