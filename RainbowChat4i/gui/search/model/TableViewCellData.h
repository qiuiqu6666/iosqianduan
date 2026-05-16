//telegram @wz662
//
//  SearchResultCellDTO.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/20.
//  Copyright © 2022 JackJiang. All rights reserved.
//

/**
 * 搜索结果表格列表的item数据对象。
 *
 * @author Jack Jiang
 * @since 6.0
 */

#import <Foundation/Foundation.h>

@interface TableViewCellData : NSObject

/** 内容数据对象（根据搜索内容类型的不同，该对象可能不尽相同） */
@property (nonatomic, retain) id contentData;
/** 是否是“查看更多”表格单元 */
@property (nonatomic, assign, getter=isSeeMoreCell) BOOL seeMoreCell;

@end

