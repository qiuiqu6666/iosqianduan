//telegram @wz662
//
//  MsgSummarySearchResult.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/22.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "MsgSummaryContentDTO.h"

/** 搜索结果常量：单聊类型（好友聊天、陌生人聊天）*/
int const MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE = 0;
/** 搜索结果常量：群聊类型 */
int const MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP = 1;

@implementation MsgSummaryContentDTO

- (id)init {
    if(self = [super init]) {
        // 属性初始化
        self.chatType = -1;
        self.resultCount = 0;
    }
    return self;
}

@end
