//telegram @wz662
//
//  FriendCellDTO.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/8/13.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UserEntity.h"

@interface FriendCellDTO : NSObject

/** 用于列表中UI上显示的排序分类字符，也就是好友昵称的首字母（比如：A~Z、#号符等）*/
@property (nonatomic, retain) NSString *firstLetter;
/** 用于列表中按昵称拼音排序的字段，昵称中如果是汉字则会转汉语拼音（此字段不用于ui显示，因为它可能是不友好的无意义字符）*/
@property (nonatomic, retain) NSString *nameWithPinyin;

/** 原始的用户信息数据 */
@property (nonatomic, retain) UserEntity *friendInfo;

/**
 * 生成FriendValue对象。
 *
 * @param ree 原始的用户信息数据
 * @return  返回新建的FriendValue对象
 */
+ (FriendCellDTO *) fromUserInfo:(UserEntity *)ree;

/**
 * 从原始的用户信息数据中创创建FriendValue对象数组。
 *
 * @param friendInfos 原始的用户信息对象数组
 * @return 如果用户信息对象数据不为空则返回FriendValue对象数组，否则返回null
 * @see #fromUserInfo(RosterElementEntity)
 */
+ (NSMutableDictionary *)fromUserInfos:(NSArray<UserEntity *> *)friendInfos;

@end
