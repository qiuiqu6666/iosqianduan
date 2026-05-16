//telegram @wz662
//
//  LoginInfoToSave.m
//  RainbowChat4i
//
//  Created by Jack Jiang
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import "LoginInfoToSave.h"
#import "EVAToolKits.h"

@implementation LoginInfoToSave

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.autoLogin = YES;
    }
    return self;
}

+ (id)initWith:(NSString *)loginName psw:(NSString *)loginPsw pswCrypt:(NSString *)loginPswCrypt
{
    return [LoginInfoToSave initWith:loginName psw:loginPsw pswCrypt:loginPswCrypt phone:nil];
}

+ (id)initWith:(NSString *)loginName psw:(NSString *)loginPsw pswCrypt:(NSString *)loginPswCrypt phone:(NSString *)phoneNum
{
    LoginInfoToSave *li = [[LoginInfoToSave alloc] init];
    li.loginName = loginName;
    li.loginPsw = loginPsw;
    li.loginPswCrypt = loginPswCrypt;
    li.phoneNum = phoneNum;
    return li;
}

+ (NSString *)toJSON:(LoginInfoToSave *)li
{
    if(li != nil)
        return [EVAToolKits toJSON:li];
    return nil;
}

+ (LoginInfoToSave *)fromJSON:(NSString *)json
{
    if(json != nil)
        return [EVAToolKits fromJSON:json withClazz:LoginInfoToSave.class];
    return nil;
}

@end
