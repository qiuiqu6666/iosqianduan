//telegram @wz662
//
//  LocationMeta.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2020/5/22.
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import "LocationMeta.h"
#import "EVAToolKits.h"

@implementation LocationMeta

+ (LocationMeta *)fromJSON:(NSString *)jsonOfLocationMeta
{
    return [EVAToolKits fromJSON:jsonOfLocationMeta withClazz:LocationMeta.class];
}

@end
