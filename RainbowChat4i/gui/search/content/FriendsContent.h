//telegram @wz662
//
//  FriendsContent.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/22.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 * 好友可搜索内容实现类。
 * <p>
 * 该类是为了拆解并分散搜索功能的复杂性，同时提高不同搜索内容的可重用性等，主要是基于设计模式考虑。
 * <p>
 * 该类将实现搜索逻辑、搜索结果的UITableView里的显示效果、点击事件处理等。
 *
 * @author JackJiang
 * @since 6.0
 */

#import <Foundation/Foundation.h>
#import "SearchableContent.h"

@interface FriendsContent : SearchableContent


@end
