//telegram @wz662
//
//  FriendCellDTO.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/8/13.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "FriendCellDTO.h"
#import "HanziPinyin.h"
#import "ToolKits.h"

@implementation FriendCellDTO

- (id)init{
    if(self = [super init]){
        // 属性初始化
        self.firstLetter = @"";
    }
    return self;
}

// 由原始数据生成FriendCellDTO对象
+ (FriendCellDTO *) fromUserInfo:(UserEntity *)ree {
    FriendCellDTO *info = [[FriendCellDTO alloc] init];
    // 好友昵称
    NSString *displayName = [ree getNickNameWithRemark];
    if (![BasicTool isStringEmpty:displayName]) {
        // 昵称拼音
        NSString *pinyin = [HanziPinyin pinyinOfHanzi:displayName];
        // 昵称拼音首字母
        NSString *firstLetter = [HanziPinyin getFirstUpperLetterFromPinyin:pinyin];
        
        info.nameWithPinyin = pinyin;
        info.firstLetter = firstLetter;
        info.friendInfo = ree;
    } else {
        info.nameWithPinyin = @"#";
    }
    
    return info;
}

// 从原始的用户信息数据中创创建FriendValue对象数组
+ (NSMutableDictionary *)fromUserInfos:(NSArray<UserEntity *> *)friendInfos {
    if (friendInfos != nil && [friendInfos count] > 0) {
        
        long t = [ToolKits getTimeStampWithMillisecond_l];
        
        //* 将好友数据按首字母进行聚合（相同首字母的放入同个数组中）
        NSMutableDictionary<NSString *, NSMutableArray<FriendCellDTO *> *> *infoDic = [[NSMutableDictionary alloc] init];
        for (UserEntity *friendInfo in friendInfos) {
            // 先将原始好友数据转成好友列表ui中将要用到的FriendCellDTO对象
            FriendCellDTO *fcdto = [FriendCellDTO fromUserInfo:friendInfo];
            
            // 取出该好友名称首字母
            NSString *firstLetter = fcdto.firstLetter;
            // 看看在字典中是否存在这个首字母对应的数组集合
            NSMutableArray<FriendCellDTO *> *friendsWithLetter = [infoDic objectForKey:firstLetter];
            // 如果不存在则新建一个首字母对应的数组集合
            if(friendsWithLetter == nil){
                friendsWithLetter = [NSMutableArray array];
                // 将该首字母对应的集合，放入到首字母字典对象中
                [infoDic setValue:friendsWithLetter forKey:firstLetter];
            }
            // 将该好友加入到该首字母对应的集合中
            [friendsWithLetter addObject:fcdto];
        }
        
        //* 取出所有首字母并按字母顺序进行排序（结果是数组对象）
        NSArray<NSString *> *keys = [[infoDic allKeys] sortedArrayUsingComparator:^NSComparisonResult(id o1, id o2) {
            return [o1 compare:o2 options:NSNumericSearch];
        }];
        NSMutableArray<NSString *> *allKeys = [[NSMutableArray alloc] initWithArray:keys];
        // 强行将“↑”答号放到数组的最前面
        [allKeys insertObject:@"↑" atIndex:0];
        // 强行将“#”号放到数组的末尾
        if ([allKeys containsObject:@"#"]) {
            [allKeys removeObject:@"#"];
            [allKeys insertObject:@"#" atIndex:allKeys.count];
        }
        
        //* 对每个首字母对应的好友对象数据集合，按昵称拼音进行排序（确保最终显示的UITableView的section中时是有顺序的）
        [infoDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSMutableArray<FriendCellDTO *> *friendsWithLetter = (NSMutableArray<FriendCellDTO *> *)obj;
            [friendsWithLetter sortUsingComparator:^NSComparisonResult(FriendCellDTO *obj1, FriendCellDTO *obj2) {
                FriendCellDTO *f1 = (FriendCellDTO *)obj1;
                FriendCellDTO *f2 = (FriendCellDTO *)obj2;
                NSString *f1SortName = f1.nameWithPinyin;
                NSString *f2SortName = f2.nameWithPinyin;
                return [f1SortName compare:f2SortName];
            }];
        }];
        
        //* 将数据结合组合成字母对象并返回
        NSMutableDictionary *resultDic = [NSMutableDictionary new];
        [resultDic setObject:infoDic forKey:@"friendsWithLetter"];
        [resultDic setObject:allKeys forKey:@"firstLetters"];
        
        DDLogDebug(@"@@@@【FriendCellDTO】从原始好友列表组织Concat列表数据完成，耗时：%lu ms", ([ToolKits getTimeStampWithMillisecond_l] - t));
        
        return resultDic;
    } else {
        return nil;
    }
}

@end
