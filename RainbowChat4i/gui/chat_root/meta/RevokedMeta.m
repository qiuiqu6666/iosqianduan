//telegram @wz662
//
//  RevokedMeta.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/11/13.
//  Copyright © 2021 JackJiang. All rights reserved.
//

#import "RevokedMeta.h"
#import "EVAToolKits.h"

@implementation RevokedMeta

+ (RevokedMeta *)initWith:(NSString *)uid nickname:(NSString *)nickname fp:(NSString *)fpForMessage
{
    RevokedMeta *cm = [[RevokedMeta alloc] init];
    cm.uid = uid;
    cm.nickName = nickname;
    cm.fpForMessage = fpForMessage;
    return cm;
}

+ (RevokedMeta *)fromJSON:(NSString *)jsonOfRevokedMeta
{
    if(jsonOfRevokedMeta != nil)
    {
        return [EVAToolKits fromJSON:jsonOfRevokedMeta withClazz:RevokedMeta.class];
    }
    return nil;
}

+ (NSString *)toJSON:(RevokedMeta *)meta
{
    return [EVAToolKits toJSON:meta];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: uid=%@, nickName=%@, beUid=%@, beNickName=%@, fpForMessage=%@>", [self class], self.uid, self.nickName, self.beUid, self.beNickName, self.fpForMessage];
}

@end
