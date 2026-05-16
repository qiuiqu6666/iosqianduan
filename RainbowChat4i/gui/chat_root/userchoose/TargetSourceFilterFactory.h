//telegram @wz662
//
//  TargetSourceFilterFactory.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2023/9/28.
//  Copyright © 2023 JackJiang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UserEntity.h"
#import "AlarmDto.h"
#import "GroupEntity.h"
#import "GroupMemberEntity.h"

typedef BOOL (^TargetSourceFilter4LatestChatting)(AlarmDto *originalData);
typedef BOOL (^TargetSourceFilter4Friend)(UserEntity *originalData);
typedef BOOL (^TargetSourceFilter4Group)(GroupEntity *originalData);
typedef BOOL (^TargetSourceFilter4GroupMember)(GroupMemberEntity *originalData);

@interface TargetSourceFilterFactory : NSObject

/**
 * 创建用于"个人名片"消息时，过滤好友目标数据源的过滤器对象。
 *
 * @param chatType 聊天类型（比如：用于一对一聊还是群聊中）
 * @param toId 数据要发送给的目标id
 * @return 过滤器对象
 */
+ (TargetSourceFilter4Friend)createTargetSourceFilter4UserContact:(int)chatType toId:(NSString *)toId;

/**
 * 创建用于"群名片"消息时，过滤群目标数据源的过滤器对象。
 *
 * @param chatType 聊天类型（比如：用于一对一聊还是群聊中）
 * @param toId 数据要发送给的目标id
 * @return 过滤器对象
 */
+ (TargetSourceFilter4Group)createTargetSourceFilter4GroupContact:(int)chatType toId:(NSString *)toId;

/**
 * 创建用于消息转发功能时，过滤"最近聊天"目标数据源的过滤器对象。
 *
 * @return 过滤器对象
 */
+ (TargetSourceFilter4LatestChatting)createTargetSourceFilterLatestChatting4MsgForward:(int)chatType toId:(NSString *)toId;

/**
 * 创建用于消息转发功能时，过滤"好友"目标数据源的过滤器对象。
 *
 * @return 过滤器对象
 */
+ (TargetSourceFilter4Friend)createTargetSourceFilterFriend4MsgForward:(int)chatType toId:(NSString *)toId;

/**
 * 创建用于消息转发功能时，过滤"好友"目标数据源的过滤器对象。
 *
 * @return 过滤器对象
 */
+ (TargetSourceFilter4Group)createTargetSourceFilterGroup4MsgForward:(int)chatType toId:(NSString *)toId;

/**
 * 创建用于群聊中的"@"功能时，过滤"群成员"目标数据源的过滤器对象。
 *
 * @return 过滤器对象
 * @since 9.0
 */
+ (TargetSourceFilter4GroupMember)createTargetSourceFilterGroupMember4At;

@end

