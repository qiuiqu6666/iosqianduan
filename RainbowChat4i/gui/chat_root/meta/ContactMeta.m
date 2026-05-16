//telegram @wz662
//
//  ContactMeta.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2020/4/23.
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import "ContactMeta.h"
#import "EVAToolKits.h"

@implementation ContactMeta

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.type = CONTACT_TYPE_USER;
    }
    return self;
}

+ (ContactMeta *)initWith:(int)type uid:(NSString *)uid nickname:(NSString *)nickname desc:(NSString *)desc
{
    ContactMeta *cm = [[ContactMeta alloc] init];
    
    cm.type = type;
    cm.uid = uid;
    cm.nickName = nickname;
    cm.desc = desc;
    return cm;
}

+ (ContactMeta *)fromJSON:(NSString *)jsonOfContactMeta
{
    if(jsonOfContactMeta != nil)
    {
        return [EVAToolKits fromJSON:jsonOfContactMeta withClazz:ContactMeta.class];
    }
    return nil;
}

@end
