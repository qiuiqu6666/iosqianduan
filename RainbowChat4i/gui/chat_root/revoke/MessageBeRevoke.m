//telegram @wz662
//
//  MessageBeRevoke.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/11/13.
//  Copyright © 2021 JackJiang. All rights reserved.
//

#import "MessageBeRevoke.h"

@implementation MessageBeRevoke

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.chatType = -1;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: chatType=%d, toId=%@, message=%@,>", [self class], self.chatType, self.toId, self.message];
}

+ (id)initWith:(int)chatType toId:(NSString *)toId message:(JSQMessage *)message
{
    MessageBeRevoke * tm = [[MessageBeRevoke alloc] init];
    tm.chatType = chatType;
    tm.toId = toId;
    tm.message = message;
    return tm;
}

@end
