//telegram @wz662
//
//  TargetEntity.m
//  RainbowChat4i
//
//  Created by Jack Jiang.
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import "TargetEntity.h"

@implementation TargetEntity

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.targetChatType = -1;
        self.selected = NO;
    }
    return self;
}



@end
