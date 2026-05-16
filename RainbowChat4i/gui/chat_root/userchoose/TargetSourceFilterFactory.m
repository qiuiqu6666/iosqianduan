//telegram @wz662
//
//  TargetSourceFilterFactory.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2023/9/28.
//  Copyright © 2023 JackJiang. All rights reserved.
//

#import "TargetSourceFilterFactory.h"
#import "AlarmType.h"
#import "IMClientManager.h"

@implementation TargetSourceFilterFactory

// 创建用于"个人名片"消息时，过滤好友目标数据源的过滤器对象
+ (TargetSourceFilter4Friend)createTargetSourceFilter4UserContact:(int)chatType toId:(NSString *)toId {
    return ^(UserEntity *originalData) {
        // 当是一对一聊天（好友或陌生人时），要对可选的名片列表去除接收者自已（向他发送他自已的名片就没意义了，微信也是这种逻辑）
        if ((chatType == CHAT_TYPE_FREIDN_CHAT || chatType == CHAT_TYPE_GUEST_CHAT)
            && toId != nil
            && [toId isEqualToString:originalData.user_uid]) {
            return NO;
        }
        return YES;
    };
}

// 创建用于"群名片"消息时，过滤群目标数据源的过滤器对象
+ (TargetSourceFilter4Group)createTargetSourceFilter4GroupContact:(int)chatType toId:(NSString *)toId {
    return ^(GroupEntity *originalData) {
        // 当是群聊），要对可选的名片列表去除接收者自已（向他发送他自已的名片就没意义了，微信也是这种逻辑）
        if ((chatType == CHAT_TYPE_GROUP_CHAT)
            && toId != nil
            && [toId isEqualToString:originalData.g_id]) {
            return NO;
        }
        return YES;
    };
}

// 创建用于消息转发功能时，过滤"最近聊天"目标数据源的过滤器对象
+ (TargetSourceFilter4LatestChatting)createTargetSourceFilterLatestChatting4MsgForward:(int)chatType toId:(NSString *)toId {
    return ^(AlarmDto *originalData) {
        // 在消息转发功能时，"最近聊天"列表中只需要显示以下类型的聊天
        if(originalData.alarmType == AMT_guestChatMessage
           || originalData.alarmType == AMT_friendChatMessage
           || originalData.alarmType == AMT_groupChatMessage) {
            // 消息转发目标中不允许出现世界频道
            if (originalData.alarmType == AMT_groupChatMessage
                && [GroupEntity isWorldChat:originalData.dataId]) {
                return NO;
            }
            // 选择的目标应该排除当前聊天界面对应的聊天对象（否则，难道自已转发给自已？）
            if([originalData.dataId isEqualToString:toId]) {
                return NO;
            }
            
            return YES;
        }
        return NO;
    };
}

// 创建用于消息转发功能时，过滤"好友"目标数据源的过滤器对象
+ (TargetSourceFilter4Friend)createTargetSourceFilterFriend4MsgForward:(int)chatType toId:(NSString *)toId {
    return ^(UserEntity *originalData) {
        // 选择的目标应该排除当前聊天界面对应的聊天对象（否则，难道自已转发给自已？）
        if([originalData.user_uid isEqualToString:toId]) {
            return NO;
        }
        return YES;
    };
}

// 创建用于消息转发功能时，过滤"好友"目标数据源的过滤器对象
+ (TargetSourceFilter4Group)createTargetSourceFilterGroup4MsgForward:(int)chatType toId:(NSString *)toId {
    return ^(GroupEntity *originalData) {
//        DLogDebug(@"##################originalData.getG_id()=%@, toId=%@", originalData.g_id, toId);
        // 消息转发目标中不允许出现世界频道
        if ([GroupEntity isWorldChat:originalData.g_id]) {
            return NO;
        }
        
        // 选择的目标应该排除当前聊天界面对应的聊天对象（否则，难道自已转发给自已？）
        if([originalData.g_id isEqualToString:toId]) {
            return NO;
        }
        return YES;
    };
}

// 创建用于群聊中的"@"功能时，过滤"群成员"目标数据源的过滤器对象
+ (TargetSourceFilter4GroupMember)createTargetSourceFilterGroupMember4At {
    return ^(GroupMemberEntity *originalData) {
        NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        // 选择的"@"目标时，应该排除"自已"（否则，难道自已"@"自已？）
        if([originalData.user_uid isEqualToString:localUid]) {
            return NO;
        }
        return YES;
    };
}

@end
