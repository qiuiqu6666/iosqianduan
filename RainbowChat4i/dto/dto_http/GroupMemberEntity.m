//telegram @wz662
#import "GroupMemberEntity.h"

@implementation GroupMemberEntity

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.selected = NO;
        self.editable = YES;
        self.role = 0; // 默认普通成员
    }
    return self;
}

@end
