//telegram @wz662
//
//  GroupSearchResult.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/22.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 * 群组搜索结果数据封装对象。
 *
 * @author JackJiang
 * @since 6.0
 */

#import <Foundation/Foundation.h>
#import "GroupEntity.h"

/** 搜索匹配类型常量定义——群名称匹配 */
extern int const GSR_MACHED_TYPE_GNAME;
/** 搜索匹配类型常量定义——群成员昵称匹配 */
extern int const GSR_MACHED_TYPE_MNAME;
/** 搜索匹配类型常量定义——群名称和群成员昵称都匹配 */
extern int const GSR_MACHED_TYPE_ALL;

@interface GroupContentDTO : NSObject

/** 群基本信息对象引用 */
@property (nonatomic, retain) GroupEntity *groupInfo;
/** 搜索匹配类型 */
@property (nonatomic, assign) int machedType;

//+ (id)initWith:(GroupEntity *)groupInfo machedType:(int)machedType;

@end

