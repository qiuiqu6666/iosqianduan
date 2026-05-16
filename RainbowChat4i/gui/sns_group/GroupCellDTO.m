//
//  GroupCellDTO.m
//  RainbowChat4i
//

#import "GroupCellDTO.h"
#import "HanziPinyin.h"
#import "ToolKits.h"

@implementation GroupCellDTO

- (id)init {
    if (self = [super init]) {
        self.firstLetter = @"";
    }
    return self;
}

// 由原始群组数据生成 GroupCellDTO 对象
+ (GroupCellDTO *)fromGroupInfo:(GroupEntity *)ge {
    GroupCellDTO *info = [[GroupCellDTO alloc] init];
    NSString *displayName = ge.g_name;
    if (![BasicTool isStringEmpty:displayName]) {
        // 名称拼音
        NSString *pinyin = [HanziPinyin pinyinOfHanzi:displayName];
        // 名称拼音首字母
        NSString *firstLetter = [HanziPinyin getFirstUpperLetterFromPinyin:pinyin];
        
        info.nameWithPinyin = pinyin;
        info.firstLetter = firstLetter;
        info.groupInfo = ge;
    } else {
        info.nameWithPinyin = @"#";
        info.groupInfo = ge;
    }
    
    return info;
}

// 从原始的群组信息数据中创建 GroupCellDTO 对象数组，并按首字母分组排序
+ (NSMutableDictionary *)fromGroupInfos:(NSArray *)groupInfos {
    if (groupInfos != nil && [groupInfos count] > 0) {
        
        long t = [ToolKits getTimeStampWithMillisecond_l];
        
        //* 将群组数据按首字母进行聚合（相同首字母的放入同个数组中）
        NSMutableDictionary<NSString *, NSMutableArray<GroupCellDTO *> *> *infoDic = [[NSMutableDictionary alloc] init];
        for (GroupEntity *groupInfo in groupInfos) {
            // 排除世界频道
            if ([groupInfo isWorldChat])
                continue;
            
            // 先将原始群组数据转成群组列表ui中将要用到的 GroupCellDTO 对象
            GroupCellDTO *gcdto = [GroupCellDTO fromGroupInfo:groupInfo];
            
            // 取出该群名称首字母
            NSString *firstLetter = gcdto.firstLetter;
            // 看看在字典中是否存在这个首字母对应的数组集合
            NSMutableArray<GroupCellDTO *> *groupsWithLetter = [infoDic objectForKey:firstLetter];
            // 如果不存在则新建一个首字母对应的数组集合
            if (groupsWithLetter == nil) {
                groupsWithLetter = [NSMutableArray array];
                [infoDic setValue:groupsWithLetter forKey:firstLetter];
            }
            // 将该群组加入到该首字母对应的集合中
            [groupsWithLetter addObject:gcdto];
        }
        
        //* 取出所有首字母并按字母顺序进行排序（结果是数组对象）
        NSArray<NSString *> *keys = [[infoDic allKeys] sortedArrayUsingComparator:^NSComparisonResult(id o1, id o2) {
            return [o1 compare:o2 options:NSNumericSearch];
        }];
        NSMutableArray<NSString *> *allKeys = [[NSMutableArray alloc] initWithArray:keys];
        // 强行将"#"号放到数组的末尾
        if ([allKeys containsObject:@"#"]) {
            [allKeys removeObject:@"#"];
            [allKeys addObject:@"#"];
        }
        
        //* 对每个首字母对应的群组对象数据集合，按名称拼音进行排序
        [infoDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSMutableArray<GroupCellDTO *> *groupsWithLetter = (NSMutableArray<GroupCellDTO *> *)obj;
            [groupsWithLetter sortUsingComparator:^NSComparisonResult(GroupCellDTO *obj1, GroupCellDTO *obj2) {
                NSString *f1SortName = obj1.nameWithPinyin;
                NSString *f2SortName = obj2.nameWithPinyin;
                return [f1SortName compare:f2SortName];
            }];
        }];
        
        //* 将数据组合成字典对象并返回
        NSMutableDictionary *resultDic = [NSMutableDictionary new];
        [resultDic setObject:infoDic forKey:@"groupsWithLetter"];
        [resultDic setObject:allKeys forKey:@"firstLetters"];
        
        DDLogDebug(@"@@@@【GroupCellDTO】从原始群组列表组织Groups列表数据完成，耗时：%lu ms", ([ToolKits getTimeStampWithMillisecond_l] - t));
        
        return resultDic;
    } else {
        return nil;
    }
}

@end
