//telegram @wz662
//
//  QuoteMeta.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2024/3/12.
//  Copyright © 2024 JackJiang. All rights reserved.
//

#import "QuoteMeta.h"

@implementation QuoteMeta

- (id)init
{
    if(self = [super init])
    {
        // 默认属性初始化
        self.quote_status = 0;
        self.quote_type = 0;
    }
    return self;
}

// 一次性设置所有字段值
- (void)setQuoteMeta:(QuoteMeta *)qm
{
    if(qm != nil) {
        self.quote_fp = qm.quote_fp;
        self.quote_sender_uid = qm.quote_sender_uid;
        self.quote_sender_nick = qm.quote_sender_nick;
        self.quote_status = qm.quote_status;
        self.quote_content = qm.quote_content;
        self.quote_type = qm.quote_type;
    }
}

@end
