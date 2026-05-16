//
//  GroupCellDTO.h
//  RainbowChat4i
//

#import <Foundation/Foundation.h>
#import "GroupEntity.h"

@interface GroupCellDTO : NSObject

/** 用于列表中UI上显示的排序分类字符，也就是群名称的首字母（比如：A~Z、#号符等）*/
@property (nonatomic, retain) NSString *firstLetter;
/** 用于列表中按名称拼音排序的字段，名称中如果是汉字则会转汉语拼音（此字段不用于ui显示）*/
@property (nonatomic, retain) NSString *nameWithPinyin;

/** 原始的群组信息数据 */
@property (nonatomic, retain) GroupEntity *groupInfo;

/**
 * 由原始群组数据生成 GroupCellDTO 对象。
 *
 * @param ge 原始的群组信息数据
 * @return 返回新建的 GroupCellDTO 对象
 */
+ (GroupCellDTO *) fromGroupInfo:(GroupEntity *)ge;

/**
 * 从原始的群组信息数据中创建 GroupCellDTO 对象数组，并按首字母分组排序。
 *
 * @param groupInfos 原始的群组信息对象数组
 * @return 包含 "groupsWithLetter" 和 "firstLetters" 的字典，如果群组数据为空则返回 nil
 */
+ (NSMutableDictionary *)fromGroupInfos:(NSArray *)groupInfos;

@end
