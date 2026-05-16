//telegram @wz662
//
//  MsgDetailContent.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/23.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 * 聊天记录可搜索内容实现类（数据不聚合显示，有多少条就显示多少条）。
 * <p>
 * 该类是为了拆解并分散搜索功能的复杂性，同时提高不同搜索内容的可重用性等，主要是基于设计模式考虑。
 * <p>
 * 该类将实现搜索逻辑、搜索结果的UITableView里的显示效果、点击事件处理等。
 *
 * @author JackJiang
 * @since 6.0
 */

#import "SearchableContent.h"
#import "MsgSummaryContentDTO.h"

@interface MsgDetailContent : SearchableContent

/** 注意此参数，它将决定子级页面里搜索的消息范围为该item指定的聊天对象范围内的消息记录 */
@property (nonatomic, retain)MsgSummaryContentDTO *msgSummaryContentDTO;

@end
