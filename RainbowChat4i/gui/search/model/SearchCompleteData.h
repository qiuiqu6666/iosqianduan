//telegram @wz662
//
//  SearchResult.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/21.
//  Copyright © 2022 JackJiang. All rights reserved.
//

/**
 * 搜索完成时的结果数据包装对象。
 *
 * @author Jack Jiang
 * @since 6.0
 */

#import <Foundation/Foundation.h>
#import "SearchableContent.h"

@interface SearchCompleteData : NSObject

/** 可搜索内容对象 */
@property (nonatomic, retain) SearchableContent *searchableContent;
/** 搜索返回结果数据集合 */
@property (nonatomic, retain) NSMutableArray *searchedCompleteDatas;

- (int)getSearchedCompleteDatas;

@end
