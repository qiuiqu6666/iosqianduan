//telegram @wz662
#import "GroupEntity.h"

@implementation GroupEntity

- (void)update:(GroupEntity *)newGe
{
    if(newGe != nil)
    {
        self.g_id = newGe.g_id;
        self.g_status = newGe.g_status;
        self.g_name = newGe.g_name;
        self.g_owner_user_uid = newGe.g_owner_user_uid;
        self.g_notice = newGe.g_notice;
        self.max_member_count = newGe.max_member_count;
        self.g_member_count = newGe.g_member_count;
        self.g_owner_name = newGe.g_owner_name;
        self.nickname_ingroup = newGe.nickname_ingroup;
        
        self.g_notice_updatetime = newGe.g_notice_updatetime;
        self.g_notice_updateuid = newGe.g_notice_updateuid;
        self.g_notice_updatenick = newGe.g_notice_updatenick;
        
        self.create_user_name = newGe.create_user_name;
        
        // 新增群管理字段
        self.g_mute_mode = newGe.g_mute_mode;
        self.g_custom_avatar = newGe.g_custom_avatar;
        self.g_join_mode = newGe.g_join_mode;
        self.g_invite_permission = newGe.g_invite_permission;
        self.g_new_member_history = newGe.g_new_member_history;
        self.g_member_privacy = newGe.g_member_privacy;
        
        // 大群读扩散
        self.group_mode = newGe.group_mode;
        self.last_seq = newGe.last_seq;
    }
}

- (BOOL) myselfIsInGroup
{
    return [@"1" isEqualToString:self.imIsInGroup];
//    return @"1".equals(this.imIsInGroup);
}

- (BOOL) isWorldChat
{
    return [GroupEntity isWorldChat:self.g_id];
}

+ (BOOL) isWorldChat:(NSString *)gid
{
    return [DEFAULT_GROUP_ID_FOR_BBS isEqualToString:gid];
}

- (BOOL)isLargeGroup
{
    return (self.group_mode == 2);
}

@end
