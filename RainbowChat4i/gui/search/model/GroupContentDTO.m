//telegram @wz662
//
//  GroupSearchResult.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/22.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "GroupContentDTO.h"


/** 搜索匹配类型常量定义——群名称匹配 */
int const GSR_MACHED_TYPE_GNAME = 0;
/** 搜索匹配类型常量定义——群成员昵称匹配 */
int const GSR_MACHED_TYPE_MNAME = 1;
/** 搜索匹配类型常量定义——群名称和群成员昵称都匹配 */
int const GSR_MACHED_TYPE_ALL   = 2;


@interface GroupContentDTO ()

@end


@implementation GroupContentDTO

- (id)init {
    if(self = [super init]) {
        // 属性初始化
        self.machedType = GSR_MACHED_TYPE_GNAME;
    }
    return self;
}


//+ (id)initWith:(GroupEntity *)groupInfo machedType:(int)machedType
//{
//    GroupSearchResult * tm = [[GroupSearchResult alloc] init];
//
//    tm.groupInfo = groupInfo;
//    tm.machedType = machedType;
//
//    return tm;
//}

@end
