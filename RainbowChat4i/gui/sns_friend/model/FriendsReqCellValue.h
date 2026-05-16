//telegram @wz662
//
//  FriendsReqCellValue.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/8/19.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UserEntity.h"

@interface FriendsReqCellValue : NSObject

/** item的内容文本 */
@property (nonatomic, retain) NSString *content;
/** item的日期时间戳（GMT默认时区） */
@property (nonatomic, retain) NSDate *date;
/** 当前"未读"的好友请求标记（内容为"1"时表示未读，否则表示已读） */
@property (nonatomic, assign) BOOL unread;
/** 添加好友记录状态：pending_out=我发起待对方处理，pending_in=对方发起待我处理，accepted_current=已是好友（接口1008-4-31） */
@property (nonatomic, copy) NSString *friendReqStatus;
/** 加好友请求用户的个人信息 */
@property (nonatomic, retain) UserEntity *userInfo;

@end
