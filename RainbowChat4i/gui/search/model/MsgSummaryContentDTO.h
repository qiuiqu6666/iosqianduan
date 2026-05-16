//telegram @wz662
//
//  MsgSummarySearchResult.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/22.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 * 聊天记录搜索结果数据封装对象（搜索结果是聚合汇总的形式，多于一条记录的显示一个汇总）。
 *
 * @author JackJiang
 * @since 6.0
 */

#import <Foundation/Foundation.h>


/** 搜索结果常量：单聊类型（好友聊天、陌生人聊天）*/
extern int const MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE;
/** 搜索结果常量：群聊类型 */
extern int const MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP;


@interface MsgSummaryContentDTO : NSObject

/** 聊天类型 */
@property (nonatomic, assign) int chatType;
/** 搜索到的结果数量 */
@property (nonatomic, assign) int resultCount;

/** 聊天id（单聊时本参数为对方的uid、群聊时为所在群的gid）*/
@property (nonatomic, retain) NSString *dataId;

/** 消息时间戳（当resultCount>1时，表示的是group by 结果下的最后一条消息的时间戳） */
@property (nonatomic, retain) NSDate *date;
/** 消息文本内容（当resultCount>1时，表示的是group by 结果下的最后一条消息文本内容） */
@property (nonatomic, retain) NSString *text;

/** 消息指纹码/唯一id（当resultCount>1时，表示的是group by 结果下的最后一条消息指纹） */
@property (nonatomic, retain) NSString *fp;

@end
