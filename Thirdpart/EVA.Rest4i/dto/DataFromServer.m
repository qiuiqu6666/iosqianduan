//telegram @wz662
#import "DataFromServer.h"

@implementation DataFromServer

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.success = YES;
        // -1时表未设定（无意义）
        self.code = -1;
    }
    return self;
}




@end
