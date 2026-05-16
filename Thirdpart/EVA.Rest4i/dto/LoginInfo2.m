//telegram @wz662
#import "LoginInfo2.h"

@implementation LoginInfo2

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.loginType = LOGIN_TYPE_PASSWORD;
    }
    return self;
}

- (BOOL)isSMSLogin
{
    return [LOGIN_TYPE_SMS isEqualToString:self.loginType];
}

@end
