//telegram @wz662
#import "ChatMessageEventProcessor.h"
#import "GMessageHelper.h"
#import "GroupsProvider.h"
#import "IMClientManager.h"
#import "GChatDataHelper.h"
#import "NotificationCenterFactory.h"
#import "BasicTool.h"
#import "LocalPushHelper.h"
#import "GroupEntity.h"
#import "AlarmsProvider.h"
#import "AlarmType.h"
#import "UserDefaultsToolKits.h"
#import "JSQSystemSoundPlayer+JSQMessages.h"
#import "HttpRestHelper.h"

const NSString *TAG = @"ChatTransDataEventProcessor";

static NSDictionary *RBParseGroupNotificationPayload(NSString *msg)
{
    if (![msg isKindOfClass:[NSString class]] || msg.length == 0) {
        return nil;
    }
    NSData *data = [msg dataUsingEncoding:NSUTF8StringEncoding];
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if ([json isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)json;
    }
    return nil;
}

static NSDictionary *RBParseJSONObjectString(NSString *text)
{
    if (![text isKindOfClass:[NSString class]] || text.length == 0) {
        return nil;
    }
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [json isKindOfClass:[NSDictionary class]] ? (NSDictionary *)json : nil;
}

static NSDictionary *RBNormalizedGroupSystemPayload(NSString *msg)
{
    NSDictionary *root = RBParseGroupNotificationPayload(msg);
    if (![root isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:root];
    id extra = payload[@"extraData"];
    if (![extra isKindOfClass:[NSDictionary class]]) {
        extra = payload[@"extra_data"];
    }
    NSDictionary *extraDict = nil;
    if ([extra isKindOfClass:[NSDictionary class]]) {
        extraDict = (NSDictionary *)extra;
    } else if ([extra isKindOfClass:[NSString class]]) {
        extraDict = RBParseJSONObjectString((NSString *)extra);
    }
    if ([extraDict isKindOfClass:[NSDictionary class]]) {
        [extraDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if (key != nil && payload[key] == nil && obj != nil) {
                payload[key] = obj;
            }
        }];
    }
    return payload;
}

static NSString *RBGroupNotificationPayloadGid(NSDictionary *payload)
{
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return @"";
    }
    id gid = payload[@"gid"];
    if (![gid isKindOfClass:[NSString class]] || ((NSString *)gid).length == 0) {
        gid = payload[@"g_id"];
    }
    if (![gid isKindOfClass:[NSString class]] || ((NSString *)gid).length == 0) {
        gid = payload[@"t"];
    }
    if (![gid isKindOfClass:[NSString class]] || ((NSString *)gid).length == 0) {
        gid = payload[@"to"];
    }
    return [gid isKindOfClass:[NSString class]] ? (NSString *)gid : @"";
}

static NSString *RBGroupNotificationPayloadParentFp(NSDictionary *payload)
{
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return @"";
    }
    id fp = payload[@"parent_fp"];
    if (![fp isKindOfClass:[NSString class]] || ((NSString *)fp).length == 0) {
        fp = payload[@"parentFp"];
    }
    if (![fp isKindOfClass:[NSString class]] || ((NSString *)fp).length == 0) {
        fp = payload[@"fp"];
    }
    return [fp isKindOfClass:[NSString class]] ? (NSString *)fp : @"";
}

static NSMutableSet<NSString *> *RBPendingSilentGroupInfoFetches(void)
{
    static NSMutableSet<NSString *> *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSMutableSet set];
    });
    return set;
}

@implementation ChatMessageEventProcessor

+ (GroupEntity *)rb_groupEntityForGid:(NSString *)gid
{
    if ([GroupEntity isWorldChat:gid]) {
        return [GroupsProvider getDefaultWordChatEntity];
    }
    return [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];
}

+ (NSString *)rb_existingConversationTitleForGid:(NSString *)gid
{
    if (gid.length == 0) {
        return @"";
    }
    AlarmDto *alarm = [[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmDto:AMT_groupChatMessage dataId:gid];
    NSString *title = [BasicTool trim:(alarm ? alarm.title : nil)];
    if (title.length > 0) {
        return title;
    }
    GroupEntity *ge = [self rb_groupEntityForGid:gid];
    title = [BasicTool trim:(ge ? ge.g_name : nil)];
    return title.length > 0 ? title : @"";
}

+ (NSString *)rb_resolvedGroupNameForGid:(NSString *)gid explicitName:(NSString *)explicitName
{
    NSString *name = [BasicTool trim:explicitName];
    if (name.length > 0) {
        return name;
    }
    name = [self rb_existingConversationTitleForGid:gid];
    if (name.length > 0) {
        return name;
    }
    return gid.length > 0 ? gid : @"群聊";
}

+ (NSString *)rb_payloadString:(NSDictionary *)payload keys:(NSArray<NSString *> *)keys
{
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return @"";
    }
    for (NSString *key in keys) {
        id value = payload[key];
        if ([value isKindOfClass:[NSString class]]) {
            NSString *trimmed = [BasicTool trim:(NSString *)value];
            if (trimmed.length > 0) {
                return trimmed;
            }
        } else if ([value respondsToSelector:@selector(description)]) {
            NSString *trimmed = [BasicTool trim:[value description]];
            if (trimmed.length > 0 && ![trimmed isEqualToString:@"<null>"]) {
                return trimmed;
            }
        }
    }
    return @"";
}

+ (NSInteger)rb_payloadInteger:(NSDictionary *)payload keys:(NSArray<NSString *> *)keys defaultValue:(NSInteger)defaultValue
{
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return defaultValue;
    }
    for (NSString *key in keys) {
        id value = payload[key];
        if ([value respondsToSelector:@selector(integerValue)]) {
            return [value integerValue];
        }
    }
    return defaultValue;
}

+ (BOOL)rb_payloadBool:(NSDictionary *)payload keys:(NSArray<NSString *> *)keys defaultValue:(BOOL)defaultValue
{
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return defaultValue;
    }
    for (NSString *key in keys) {
        id value = payload[key];
        if ([value isKindOfClass:[NSNumber class]]) {
            return [(NSNumber *)value boolValue];
        }
        if ([value isKindOfClass:[NSString class]]) {
            NSString *normalized = [[(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
            if ([normalized isEqualToString:@"1"] || [normalized isEqualToString:@"true"] || [normalized isEqualToString:@"yes"]) {
                return YES;
            }
            if ([normalized isEqualToString:@"0"] || [normalized isEqualToString:@"false"] || [normalized isEqualToString:@"no"]) {
                return NO;
            }
        }
    }
    return defaultValue;
}

+ (NSString *)rb_extendedGroupSystemFallbackContentForPayload:(NSDictionary *)payload msgType:(NSInteger)msgType
{
    NSString *operatorNickname = [self rb_payloadString:payload keys:@[@"operator_nickname", @"operatorNickname", @"changed_by_nickname", @"changedByNickname"]];
    NSString *targetNickname = [self rb_payloadString:payload keys:@[@"target_nickname", @"targetNickname"]];
    switch (msgType) {
        case MT55_OF_GROUP_SYSCMD_GROUP_AVATAR_CHANGED_FROM_SERVER:
            return operatorNickname.length > 0 ? [NSString stringWithFormat:@"%@修改了群头像", operatorNickname] : @"群头像已修改";
        case MT56_OF_GROUP_SYSCMD_GROUP_MUTE_MODE_CHANGED_FROM_SERVER: {
            NSInteger muteMode = [self rb_payloadInteger:payload keys:@[@"mute_mode", @"muteMode"] defaultValue:0];
            if (muteMode == 1) {
                return operatorNickname.length > 0 ? [NSString stringWithFormat:@"%@开启了全员禁言", operatorNickname] : @"已开启全员禁言";
            }
            if (muteMode == 2) {
                return operatorNickname.length > 0 ? [NSString stringWithFormat:@"%@开启了仅群主可发言模式", operatorNickname] : @"已开启仅群主可发言模式";
            }
            return operatorNickname.length > 0 ? [NSString stringWithFormat:@"%@解除了群禁言", operatorNickname] : @"已解除群禁言";
        }
        case MT57_OF_GROUP_SYSCMD_GROUP_INVITE_PERMISSION_CHANGED_FROM_SERVER: {
            NSInteger invitePermission = [self rb_payloadInteger:payload keys:@[@"invite_permission", @"invitePermission"] defaultValue:0];
            if (invitePermission == 1) {
                return operatorNickname.length > 0 ? [NSString stringWithFormat:@"%@开启了仅管理员和群主可邀请模式", operatorNickname] : @"邀请权限已改为仅管理员和群主可邀请";
            }
            return operatorNickname.length > 0 ? [NSString stringWithFormat:@"%@开启了所有人可邀请模式", operatorNickname] : @"邀请权限已改为所有人可邀请";
        }
        case MT58_OF_GROUP_SYSCMD_GROUP_MEMBER_PRIVACY_CHANGED_FROM_SERVER: {
            NSInteger memberPrivacy = [self rb_payloadInteger:payload keys:@[@"member_privacy", @"memberPrivacy"] defaultValue:0];
            if (memberPrivacy == 1) {
                return operatorNickname.length > 0 ? [NSString stringWithFormat:@"%@开启了成员隐私保护", operatorNickname] : @"已开启成员隐私保护";
            }
            return operatorNickname.length > 0 ? [NSString stringWithFormat:@"%@关闭了成员隐私保护", operatorNickname] : @"已关闭成员隐私保护";
        }
        case MT59_OF_GROUP_SYSCMD_GROUP_ADMIN_CHANGED_FROM_SERVER: {
            BOOL isSetAdmin = [self rb_payloadBool:payload keys:@[@"is_set_admin", @"isSetAdmin"] defaultValue:NO];
            if (operatorNickname.length > 0 && targetNickname.length > 0) {
                return isSetAdmin ? [NSString stringWithFormat:@"%@设置了%@为管理员", operatorNickname, targetNickname]
                                  : [NSString stringWithFormat:@"%@取消了%@的管理员身份", operatorNickname, targetNickname];
            }
            return isSetAdmin ? @"管理员已设置" : @"管理员身份已取消";
        }
        case MT60_OF_GROUP_SYSCMD_GROUP_JOIN_MODE_CHANGED_FROM_SERVER: {
            NSInteger joinMode = [self rb_payloadInteger:payload keys:@[@"join_mode", @"joinMode"] defaultValue:0];
            if (joinMode == 1) {
                return operatorNickname.length > 0 ? [NSString stringWithFormat:@"%@设置了加群需管理员确认", operatorNickname] : @"入群方式已改为需管理员确认";
            }
            return operatorNickname.length > 0 ? [NSString stringWithFormat:@"%@设置了自由加入模式", operatorNickname] : @"入群方式已改为自由加入";
        }
        default:
            return @"群系统通知";
    }
}

+ (void)rb_applyExtendedGroupStateFromPayload:(NSDictionary *)payload msgType:(NSInteger)msgType gid:(NSString *)gid
{
    gid = [BasicTool trim:gid];
    if (gid.length == 0) {
        return;
    }
    GroupEntity *ge = [self rb_groupEntityForGid:gid];
    if (ge == nil) {
        [self rb_fetchGroupInfoSilentlyIfNeeded:gid preferredName:[self rb_existingConversationTitleForGid:gid]];
    }
    switch (msgType) {
        case MT55_OF_GROUP_SYSCMD_GROUP_AVATAR_CHANGED_FROM_SERVER: {
            NSString *avatarURL = [self rb_payloadString:payload keys:@[@"new_avatar", @"avatar_url", @"g_avatar_url", @"group_avatar_url", @"g_custom_avatar"]];
            if (ge != nil && avatarURL.length > 0) {
                ge.g_custom_avatar = avatarURL;
            }
            [NotificationCenterFactory resetGroupAvatarCache_POST:gid];
            break;
        }
        case MT56_OF_GROUP_SYSCMD_GROUP_MUTE_MODE_CHANGED_FROM_SERVER:
            if (ge != nil) {
                ge.g_mute_mode = (int)[self rb_payloadInteger:payload keys:@[@"mute_mode", @"muteMode"] defaultValue:ge.g_mute_mode];
            }
            break;
        case MT57_OF_GROUP_SYSCMD_GROUP_INVITE_PERMISSION_CHANGED_FROM_SERVER:
            if (ge != nil) {
                ge.g_invite_permission = (int)[self rb_payloadInteger:payload keys:@[@"invite_permission", @"invitePermission"] defaultValue:ge.g_invite_permission];
            }
            break;
        case MT58_OF_GROUP_SYSCMD_GROUP_MEMBER_PRIVACY_CHANGED_FROM_SERVER:
            if (ge != nil) {
                ge.g_member_privacy = (int)[self rb_payloadInteger:payload keys:@[@"member_privacy", @"memberPrivacy"] defaultValue:ge.g_member_privacy];
            }
            break;
        case MT60_OF_GROUP_SYSCMD_GROUP_JOIN_MODE_CHANGED_FROM_SERVER:
            if (ge != nil) {
                ge.g_join_mode = (int)[self rb_payloadInteger:payload keys:@[@"join_mode", @"joinMode"] defaultValue:ge.g_join_mode];
            }
            break;
        default:
            break;
    }
}

+ (void)rb_postGroupNotificationRealtimeRefreshWithMsgType:(NSInteger)msgType payload:(NSDictionary *)payload
{
    NSString *gid = RBGroupNotificationPayloadGid(payload);
    DDLogInfo(@"[RBGroupSysTrace][NotifyGroupNotice] mt=%ld gid=%@ payload=%@", (long)msgType, gid, payload);
    [NotificationCenterFactory groupNotificationsRealtime_POST:gid msgType:msgType raw:payload];
}

+ (void)rb_processExtendedGroupSystemPayload:(NSDictionary *)payload
                                   msgType:(NSInteger)msgType
                      fingerPrintOfProtocal:(NSString *)fingerPrintOfProtocal
{
    if (![payload isKindOfClass:[NSDictionary class]]) {
        DDLogWarn(@"[RBGroupSysTrace][MT%ld] skip reason=nil_payload fp=%@", (long)msgType, fingerPrintOfProtocal);
        return;
    }
    NSString *gid = [BasicTool trim:RBGroupNotificationPayloadGid(payload)];
    if (gid.length == 0) {
        DDLogWarn(@"[RBGroupSysTrace][MT%ld] skip reason=empty_gid fp=%@ payload=%@", (long)msgType, fingerPrintOfProtocal, payload);
        return;
    }
    NSString *explicitName = [self rb_payloadString:payload keys:@[@"gname", @"g_name", @"newGroupName", @"new_group_name"]];
    NSString *groupName = [self rb_resolvedGroupNameForGid:gid explicitName:explicitName];
    NSString *content = [self rb_payloadString:payload keys:@[@"content", @"notificationContent", @"notification_content", @"m"]];
    if (content.length == 0) {
        content = [self rb_extendedGroupSystemFallbackContentForPayload:payload msgType:msgType];
    }
    NSString *stableFp = [BasicTool trim:RBGroupNotificationPayloadParentFp(payload)];
    if (stableFp.length == 0) {
        stableFp = [BasicTool trim:fingerPrintOfProtocal];
    }
    if (stableFp.length == 0) {
        NSString *localUid = [[ClientCoreSDK sharedInstance] currentLoginUserId] ?: @"0";
        stableFp = [NSString stringWithFormat:@"SYS_G_EXT_%@_%ld_%@_%@", localUid, (long)msgType, gid ?: @"0", content ?: @""];
    }
    NSString *senderUid = [self rb_payloadString:payload keys:@[@"operator_uid", @"operatorUid", @"changed_by_uid", @"changedByUid", @"target_uid", @"targetUid", @"f", @"from"]];
    NSString *senderNick = [self rb_payloadString:payload keys:@[@"operator_nickname", @"operatorNickname", @"changed_by_nickname", @"changedByNickname", @"nickName", @"nickname"]];
    DDLogInfo(@"[RBGroupSysTrace][MT%ld] gid=%@ fp=%@ stableFp=%@ sender=%@ msg=%@ payload=%@",
              (long)msgType, gid, fingerPrintOfProtocal, stableFp, senderUid, content, payload);
    MsgBody4Group *msgBody = [MsgBody4Group constructGroupChatMsgBody:TM_TYPE_SYSTEAM_INFO
                                                          srcUserUid:(senderUid.length > 0 ? senderUid : @"0")
                                                         srcNickName:(senderNick ?: @"")
                                                               toGid:gid
                                                                 msg:content
                                                            parentFp:stableFp
                                                                  at:nil];
    [self rb_consumeIncomingGroupSystemMessage:msgBody
                         fingerPrintOfProtocal:stableFp
                              explicitGroupName:groupName
                                     showNotify:YES
                                      playAudio:YES];
    [self rb_applyExtendedGroupStateFromPayload:payload msgType:msgType gid:gid];
    [self rb_postGroupNotificationRealtimeRefreshWithMsgType:msgType payload:payload];
}

+ (void)rb_fetchGroupInfoSilentlyIfNeeded:(NSString *)gid preferredName:(NSString *)preferredName
{
    gid = [BasicTool trim:gid];
    if (gid.length == 0 || [GroupEntity isWorldChat:gid]) {
        DDLogInfo(@"[RBGroupSysTrace][FetchGroupInfo] skip gid=%@ preferred=%@ reason=empty_or_world", gid, preferredName);
        return;
    }
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid ?: @"";
    if (localUid.length == 0) {
        DDLogInfo(@"[RBGroupSysTrace][FetchGroupInfo] skip gid=%@ preferred=%@ reason=no_local_uid", gid, preferredName);
        return;
    }
    @synchronized (RBPendingSilentGroupInfoFetches()) {
        if ([RBPendingSilentGroupInfoFetches() containsObject:gid]) {
            DDLogInfo(@"[RBGroupSysTrace][FetchGroupInfo] dedup gid=%@ preferred=%@", gid, preferredName);
            return;
        }
        [RBPendingSilentGroupInfoFetches() addObject:gid];
    }
    DDLogInfo(@"[RBGroupSysTrace][FetchGroupInfo] start gid=%@ preferred=%@", gid, preferredName);
    [[HttpRestHelper sharedInstance] submitGetGroupInfoToServer:gid myUserId:localUid complete:^(BOOL sucess, GroupEntity *groupInfo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            @synchronized (RBPendingSilentGroupInfoFetches()) {
                [RBPendingSilentGroupInfoFetches() removeObject:gid];
            }
            DDLogInfo(@"[RBGroupSysTrace][FetchGroupInfo] finish gid=%@ success=%@ group=%@ inGroup=%@ resolvedName=%@",
                      gid,
                      sucess ? @"YES" : @"NO",
                      groupInfo ? @"YES" : @"NO",
                      (groupInfo && [groupInfo myselfIsInGroup]) ? @"YES" : @"NO",
                      groupInfo.g_name);
            if (!sucess || groupInfo == nil) {
                return;
            }
            BOOL imIsInThisGroup = [groupInfo myselfIsInGroup];
            GroupsProvider *gp = [[IMClientManager sharedInstance] getGroupsProvider];
            if (!imIsInThisGroup) {
                [gp remove2:gid notify:NO];
                return;
            }
            NSString *resolvedName = [BasicTool trim:groupInfo.g_name];
            if (resolvedName.length == 0) {
                resolvedName = [BasicTool trim:preferredName];
                groupInfo.g_name = resolvedName;
            }
            if ([gp getGroupInfoByGid:gid] != nil) {
                [gp updateGroup:groupInfo];
            } else {
                [gp putGroup:groupInfo];
            }
            if (resolvedName.length > 0) {
                [NotificationCenterFactory groupNameChanged_POST:gid newGroupName:resolvedName];
                [[[IMClientManager sharedInstance] getAlarmsProvider] updateAlarmTitle:AMT_groupChatMessage
                                                                                dataId:gid
                                                                              newTitle:resolvedName
                                                                      needUpdateSqlite:YES];
            }
            [NotificationCenterFactory resetGroupAvatarCache_POST:gid];
        });
    } hudParentView:nil];
}

+ (void)rb_consumeIncomingGroupSystemMessage:(MsgBody4Group *)msgBody
                      fingerPrintOfProtocal:(NSString *)fingerPrintOfProtocal
                           explicitGroupName:(NSString *)explicitGroupName
                                  showNotify:(BOOL)showNotify
                                   playAudio:(BOOL)playAudio
{
    if (msgBody == nil) {
        DDLogWarn(@"[RBGroupSysTrace][Consume] skip reason=nil_msg_body fp=%@", fingerPrintOfProtocal);
        return;
    }
    NSString *gid = [BasicTool trim:msgBody.t];
    if (gid.length == 0) {
        DDLogWarn(@"[RBGroupSysTrace][Consume] skip reason=empty_gid fp=%@ body=%@", fingerPrintOfProtocal, msgBody);
        return;
    }
    NSString *groupName = [self rb_resolvedGroupNameForGid:gid explicitName:explicitGroupName];
    GroupEntity *ge = [self rb_groupEntityForGid:gid];
    DDLogInfo(@"[RBGroupSysTrace][Consume] gid=%@ gname=%@ fp=%@ parentFp=%@ msgType=%d sender=%@ ge=%@ showNotify=%@ playAudio=%@ msg=%@",
              gid,
              groupName,
              fingerPrintOfProtocal,
              msgBody.parentFp,
              msgBody.ty,
              msgBody.f,
              ge ? @"YES" : @"NO",
              showNotify ? @"YES" : @"NO",
              playAudio ? @"YES" : @"NO",
              msgBody.m);
    [GChatDataHelper addChatMessageDataIncoming:fingerPrintOfProtocal
                                            gid:gid
                                          gname:groupName
                                       withBody:msgBody
                                           date:nil
                                     showNotify:showNotify
                                      playAudio:playAudio
                                       andQuote:msgBody];
    if (ge == nil) {
        [self rb_fetchGroupInfoSilentlyIfNeeded:gid preferredName:groupName];
    }
}

+ (void) processMT45_OF_GROUP_CHAT_MSG_SERVER_TO_B:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    //** 特别注意：因群聊消息是由服务端发的（不像一对一聊天消息是通过client to client消息模式），所以
    //**         此处的消息发送者user_id字段的值是服务器（即"0"），而非消息真正的源头用户id哦，但
    //**         Protocal的dataContent里MsgBody4Guest对象里的f字段才是真正的用户源id哦！

    // 来自发送方的群组聊天消息
    MsgBody4Group *msgBody = [GMessageHelper parseGroupChatMsg_SERVER_TO_B_Message:msg];
    // v4.1：groupSeq 可能在顶层 JSON；若 DTO 未映射则从原始串兜底（与 1016-25-25 的 seq 对齐）
    if (msgBody != nil && msgBody.groupSeq == 0 && msg.length > 0) {
        NSData *raw = [msg dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *root = [NSJSONSerialization JSONObjectWithData:raw options:0 error:nil];
        if ([root isKindOfClass:[NSDictionary class]]) {
            long long gs = [root[@"groupSeq"] longLongValue];
            if (gs > 0) {
                msgBody.groupSeq = gs;
            }
        }
    }

    // 在群聊消息时，本字段存放的是群组id，普通一对的聊天时才是用户uid
    NSString *toGid = msgBody.t;

    // 找到源用户要发送到的群组基本信息
    GroupEntity *ge = nil;
    // 如果是世界频道
    if([GroupEntity isWorldChat:toGid])
        ge = [GroupsProvider getDefaultWordChatEntity];
    // 否则是普通群聊
    else
        ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:toGid];

    if(ge != nil)
    {
        // ====== 大群（读扩散）=====
        // A) 轻量：m 为 JSON {"pull":1,"seq":888} → 仅更新会话/通知 + HTTP 补缺（不发正文）。
        // B) v4.1 在线全文：与普通群相同 MsgBody（含 ty、m、f…），并带 groupSeq；可直接渲染，不必再打 1016-25-25。
        if ([ge isLargeGroup] && msgBody.m.length > 0)
        {
            NSData *jsonData = [msgBody.m dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *pullInfo = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            if ([pullInfo isKindOfClass:[NSDictionary class]] && [pullInfo[@"pull"] intValue] == 1)
            {
                long long seq = [pullInfo[@"seq"] longLongValue];
                NSLog(@"【MT45-大群】收到大群 %@ 的拉取通知, seq=%lld", toGid, seq);
                if (seq > 0) {
                    [GroupsProvider saveLastSeq:seq forGroup:toGid];
                }

                // 判断当前是否在该大群聊天界面中
                BOOL isInThisGroupChat = ([IMClientManager sharedInstance].currentFrontGroupChattingGroupID != nil
                                          && [[IMClientManager sharedInstance].currentFrontGroupChattingGroupID isEqualToString:toGid]);

                // 更新首页"消息"列表（AlarmsProvider）—— 确保会话列表能显示"有新消息"
                if (!isInThisGroupChat) {
                    AlarmsProvider *alarmsProvider = [[IMClientManager sharedInstance] getAlarmsProvider];
                    [alarmsProvider addAGroupChatMsgAlarm:TM_TYPE_TEXT
                                                      gid:toGid
                                                    gname:ge.g_name ?: toGid
                                         fromUserNickName:@""
                                                      msg:@"[新消息]"
                                                     date:nil
                                             flagNumToAdd:1
                                                       at:NO
                                               fingerPrint:nil];

                    if (![alarmsProvider isArchived:AMT_groupChatMessage dataId:toGid]
                        && [UserDefaultsToolKits isChatMsgToneOpen:toGid]) {
                        [JSQSystemSoundPlayer jsq_playMessageReceivedSound];
                        [LocalPushHelper showAGroupChatMsgPush:NO msgType:TM_TYPE_TEXT msg:@"[新消息]" fromNickName:@"" toGid:toGid toGname:ge.g_name ?: toGid];
                    }
                }

                [NotificationCenterFactory largeGroupPullNotify_POST:toGid seq:seq];
                return;
            }
        }

        // 大群在线全文：顶层 MsgBody 带 groupSeq（JSON 反序列化填入），更新本地 seq 指针与 HTTP 拉取对齐
        if ([ge isLargeGroup] && msgBody.groupSeq > 0) {
            [GroupsProvider saveLastSeq:msgBody.groupSeq forGroup:ge.g_id];
        }

        // 普通群 / 大群全文：将数据放入
        [GChatDataHelper addChatMessageDataIncoming:fingerPrintOfProtocal gid:ge.g_id gname:ge.g_name withBody:msgBody date:nil showNotify:YES playAudio:YES andQuote:msgBody];
    }
    else
    {
        DDLogWarn(@"【%@】来自userid=%@的群聊消息虽收到，但目标群组%@并不在我的群组列表里，本条群消息将被忽略！！", TAG, msgBody.f, toGid);
    }
}

+ (void) processMT46_OF_GROUP_SYSCMD_MYSELF_BE_INVITE_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    CMDBody4MyselfBeInvitedGroupResponse *cmdBody = [GMessageHelper parseResponse4GroupSysCMD4MyselfBeInvited:msg];

//    Log.d(TAG, cmdBody != null?cmdBody.toString(): null);

    // 群组基本信息
    GroupEntity *ge = cmdBody;

    if(ge != nil)
    {
        // 将新加入的群信息加入到本地的群缓存列表中
        [[[IMClientManager sharedInstance] getGroupsProvider] putGroup:ge];

        // 来一个本地Push系统通知哦
        [LocalPushHelper showMyselfBeInvitedGroupPush:ge.g_name beInvitedNickname:cmdBody.initveBeNickName];

        NSString *hintTex = [NSString stringWithFormat:@"\"%@\"邀请您加入了群聊", cmdBody.initveBeNickName];
        // 将该条系统通知加入到聊天消息中
        NSString *localUid = [[ClientCoreSDK sharedInstance] currentLoginUserId] ?: @"0";
        NSString *fp = [NSString stringWithFormat:@"SYS_G_INVITE_%@_%@_%@", localUid, ge.g_id ?: @"0", cmdBody.inviteBeUid ?: @"0"];
        [GChatDataHelper addSystemInfoData:ge.g_id gname:ge.g_name infoContent:hintTex fingerPrint:fp date:nil showNotify:NO playAudio:YES];
        [self rb_postGroupNotificationRealtimeRefreshWithMsgType:MT46_OF_GROUP_SYSCMD_MYSELF_BE_INVITE_FROM_SERVER rawMsg:msg];
    }
    else
    {
        DDLogWarn(@"【%@】来自gid=%@的加群成功后通知，但ge==null，本条通知将被忽略！！", TAG, cmdBody.g_id);
    }
}

+ (void) processMT47_OF_GROUP_SYSCMD_COMMON_INFO_FROM_SERVER:(NSString *)fingerPrintOfProtocal fromUid:(NSString *)fromUid withMsg:(NSString *)msg
{
    // 群组的系统通知，本质还是个群聊消息体（用类型区分就可以了）
    MsgBody4Group *cmdBody = [GMessageHelper parseGroupChatMsg_SERVER_TO_B_Message:msg];

//    Log.d(TAG, cmdBody != null?cmdBody.toString(): null);

    // 在群聊消息时，本字段存放的是群组id，普通一对的聊天时才是用户uid
    NSString *toGid = cmdBody.t;
    DDLogInfo(@"[RBGroupSysTrace][MT47] from=%@ gid=%@ fp=%@ parentFp=%@ msg=%@", fromUid, toGid, fingerPrintOfProtocal, cmdBody.parentFp, cmdBody.m);

    NSString *fallbackName = [self rb_existingConversationTitleForGid:toGid];
    [self rb_consumeIncomingGroupSystemMessage:cmdBody
                         fingerPrintOfProtocal:fingerPrintOfProtocal
                              explicitGroupName:fallbackName
                                     showNotify:YES
                                      playAudio:YES];
    [self rb_postGroupNotificationRealtimeRefreshWithMsgType:MT47_OF_GROUP_SYSCMD_COMMON_INFO_FROM_SERVER rawMsg:msg];
    if ([self rb_groupEntityForGid:toGid] == nil) {
        DDLogWarn(@"【%@】来自userid=%@的群聊系统MT47在 ge==null 时已按兜底路径落地，gid=%@", TAG, fromUid, toGid);
    }
}

+ (void) processMT48_OF_GROUP_SYSCMD_DISMISSED_FROM_SERVER:(NSString *)fingerPrintOfProtocal fromUid:(NSString *)fromUid withMsg:(NSString *)msg
{
    // 群组的系统通知，本质还是个群聊消息体（用类型区分就可以了）
    MsgBody4Group *cmdBody = [GMessageHelper parseGroupChatMsg_SERVER_TO_B_Message:msg];

//    Log.d(TAG, cmdBody != null?cmdBody.toString(): null);

    // 在群聊消息时，本字段存放的是群组id，普通一对的聊天时才是用户uid
    NSString *toGid = cmdBody.t;
    DDLogInfo(@"[RBGroupSysTrace][MT48] from=%@ gid=%@ fp=%@ parentFp=%@ msg=%@", fromUid, toGid, fingerPrintOfProtocal, cmdBody.parentFp, cmdBody.m);

    NSString *fallbackName = [self rb_existingConversationTitleForGid:toGid];
    [self rb_consumeIncomingGroupSystemMessage:cmdBody
                         fingerPrintOfProtocal:fingerPrintOfProtocal
                              explicitGroupName:fallbackName
                                     showNotify:YES
                                      playAudio:YES];
    [[[IMClientManager sharedInstance] getGroupsProvider] remove2:toGid];
}

+ (void) processMT49_OF_GROUP_SYSCMD_YOU_BE_KICKOUT_FROM_SERVER:(NSString *)fingerPrintOfProtocal fromUid:(NSString *)fromUid withMsg:(NSString *)msg
{
    // 群组的系统通知，本质还是个群聊消息体（用类型区分就可以了）
    MsgBody4Group *cmdBody = [GMessageHelper parseGroupChatMsg_SERVER_TO_B_Message:msg];

//    Log.d(TAG, cmdBody != null?cmdBody.toString(): null);

    // 在群聊消息时，本字段存放的是群组id，普通一对的聊天时才是用户uid
    NSString *toGid = cmdBody.t;
    DDLogInfo(@"[RBGroupSysTrace][MT49] from=%@ gid=%@ fp=%@ parentFp=%@ msg=%@", fromUid, toGid, fingerPrintOfProtocal, cmdBody.parentFp, cmdBody.m);

    NSString *fallbackName = [self rb_existingConversationTitleForGid:toGid];
    [self rb_consumeIncomingGroupSystemMessage:cmdBody
                         fingerPrintOfProtocal:fingerPrintOfProtocal
                              explicitGroupName:fallbackName
                                     showNotify:YES
                                      playAudio:YES];
    [[[IMClientManager sharedInstance] getGroupsProvider] remove2:toGid];
}

+ (void) processMT50_OF_GROUP_SYSCMD_SOMEONEB_REMOVED_FROM_SERVER:(NSString *)fingerPrintOfProtocal fromUid:(NSString *)fromUid withMsg:(NSString *)msg
{
    // 群组的系统通知，本质还是个群聊消息体（用类型区分就可以了）
    MsgBody4Group *cmdBody = [GMessageHelper parseGroupChatMsg_SERVER_TO_B_Message:msg];

//    Log.d(TAG, cmdBody != null?cmdBody.toString(): null);

    // 在群聊消息时，本字段存放的是群组id，普通一对的聊天时才是用户uid
    NSString *toGid = cmdBody.t;
    DDLogInfo(@"[RBGroupSysTrace][MT50] from=%@ gid=%@ fp=%@ parentFp=%@ msg=%@", fromUid, toGid, fingerPrintOfProtocal, cmdBody.parentFp, cmdBody.m);

    NSString *fallbackName = [self rb_existingConversationTitleForGid:toGid];
    [self rb_consumeIncomingGroupSystemMessage:cmdBody
                         fingerPrintOfProtocal:fingerPrintOfProtocal
                              explicitGroupName:fallbackName
                                     showNotify:YES
                                      playAudio:YES];
    [NotificationCenterFactory resetGroupAvatarCache_POST:toGid];
    [self rb_postGroupNotificationRealtimeRefreshWithMsgType:MT50_OF_GROUP_SYSCMD_SOMEONEB_REMOVED_FROM_SERVER rawMsg:msg];
    if ([self rb_groupEntityForGid:toGid] == nil) {
        DDLogWarn(@"【%@】来自userid=%@的群聊系统MT50在 ge==null 时已按兜底路径落地，gid=%@", TAG, fromUid, toGid);
    }
}

+ (void) processMT51_OF_GROUP_SYSCMD_GROUP_NAME_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    CMDBody4GroupNameChangedNotification *cmdBody = [GMessageHelper parseResponse4GroupSysCMD4GroupNameChanged:msg];
    NSString *toGid = cmdBody.gid;
    NSString *newGroupName = [BasicTool trim:cmdBody.nnewGroupName];
    GroupEntity *ge = [self rb_groupEntityForGid:toGid];
    if (ge != nil && newGroupName.length > 0) {
        ge.g_name = newGroupName;
    }
    NSString *hintTex = [BasicTool trim:cmdBody.notificationContent];
    if (hintTex.length == 0) {
        hintTex = newGroupName.length > 0 ? [NSString stringWithFormat:@"群名称已修改为%@", newGroupName] : @"群名称已修改";
    }
    NSDictionary *rawPayload = RBParseGroupNotificationPayload(msg);
    NSString *stableFp = RBGroupNotificationPayloadParentFp(rawPayload);
    if (stableFp.length == 0) {
        stableFp = [BasicTool trim:fingerPrintOfProtocal];
    }
    if (stableFp.length == 0) {
        NSString *localUid = [[ClientCoreSDK sharedInstance] currentLoginUserId] ?: @"0";
        stableFp = [NSString stringWithFormat:@"SYS_G_RENAME_%@_%@_%@_%@", localUid, toGid ?: @"0", cmdBody.changedByUid ?: @"0", newGroupName ?: @""];
    }
    DDLogInfo(@"[RBGroupSysTrace][MT51] gid=%@ fp=%@ stableFp=%@ changedBy=%@ newName=%@ msg=%@ ge=%@",
              toGid,
              fingerPrintOfProtocal,
              stableFp,
              cmdBody.changedByUid,
              newGroupName,
              hintTex,
              ge ? @"YES" : @"NO");
    MsgBody4Group *msgBody = [MsgBody4Group constructGroupChatMsgBody:TM_TYPE_SYSTEAM_INFO
                                                          srcUserUid:cmdBody.changedByUid ?: @"0"
                                                         srcNickName:@""
                                                               toGid:toGid
                                                                 msg:hintTex
                                                            parentFp:stableFp
                                                                  at:nil];
    [self rb_consumeIncomingGroupSystemMessage:msgBody
                         fingerPrintOfProtocal:stableFp
                              explicitGroupName:newGroupName
                                     showNotify:YES
                                      playAudio:YES];
    if (newGroupName.length > 0) {
        [NotificationCenterFactory groupNameChanged_POST:toGid newGroupName:newGroupName];
    }
    [self rb_postGroupNotificationRealtimeRefreshWithMsgType:MT51_OF_GROUP_SYSCMD_GROUP_NAME_CHANGED_FROM_SERVER rawMsg:msg];
    if ([self rb_groupEntityForGid:toGid] == nil) {
        DDLogWarn(@"【%@】来自gid=%@的群名被改通知在 ge==null 时已按兜底路径落地", TAG, toGid);
    }
}

+ (void)rb_postGroupNotificationRealtimeRefreshWithMsgType:(NSInteger)msgType rawMsg:(NSString *)msg
{
    NSDictionary *payload = RBParseGroupNotificationPayload(msg);
    NSString *gid = RBGroupNotificationPayloadGid(payload);
    DDLogInfo(@"[RBGroupSysTrace][NotifyGroupNotice] mt=%ld gid=%@ payload=%@", (long)msgType, gid, payload);
    [NotificationCenterFactory groupNotificationsRealtime_POST:gid msgType:msgType raw:payload];
}

+ (void) processMT52_OF_GROUP_NOTIFY_JOIN_REQUEST:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    (void)fingerPrintOfProtocal;
    [self rb_postGroupNotificationRealtimeRefreshWithMsgType:MT52_OF_GROUP_NOTIFY_JOIN_REQUEST rawMsg:msg];
}

+ (void) processMT53_OF_GROUP_NOTIFY_JOIN_REVIEW_RESULT:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    (void)fingerPrintOfProtocal;
    [self rb_postGroupNotificationRealtimeRefreshWithMsgType:MT53_OF_GROUP_NOTIFY_JOIN_REVIEW_RESULT rawMsg:msg];
}

+ (void) processMT54_OF_GROUP_NOTIFY_ADMIN_OPERATION:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    (void)fingerPrintOfProtocal;
    [self rb_postGroupNotificationRealtimeRefreshWithMsgType:MT54_OF_GROUP_NOTIFY_ADMIN_OPERATION rawMsg:msg];
}

+ (void) processMT55_OF_GROUP_SYSCMD_GROUP_AVATAR_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    [self rb_processExtendedGroupSystemPayload:RBNormalizedGroupSystemPayload(msg)
                                     msgType:MT55_OF_GROUP_SYSCMD_GROUP_AVATAR_CHANGED_FROM_SERVER
                        fingerPrintOfProtocal:fingerPrintOfProtocal];
}

+ (void) processMT56_OF_GROUP_SYSCMD_GROUP_MUTE_MODE_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    [self rb_processExtendedGroupSystemPayload:RBNormalizedGroupSystemPayload(msg)
                                     msgType:MT56_OF_GROUP_SYSCMD_GROUP_MUTE_MODE_CHANGED_FROM_SERVER
                        fingerPrintOfProtocal:fingerPrintOfProtocal];
}

+ (void) processMT57_OF_GROUP_SYSCMD_GROUP_INVITE_PERMISSION_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    [self rb_processExtendedGroupSystemPayload:RBNormalizedGroupSystemPayload(msg)
                                     msgType:MT57_OF_GROUP_SYSCMD_GROUP_INVITE_PERMISSION_CHANGED_FROM_SERVER
                        fingerPrintOfProtocal:fingerPrintOfProtocal];
}

+ (void) processMT58_OF_GROUP_SYSCMD_GROUP_MEMBER_PRIVACY_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    [self rb_processExtendedGroupSystemPayload:RBNormalizedGroupSystemPayload(msg)
                                     msgType:MT58_OF_GROUP_SYSCMD_GROUP_MEMBER_PRIVACY_CHANGED_FROM_SERVER
                        fingerPrintOfProtocal:fingerPrintOfProtocal];
}

+ (void) processMT59_OF_GROUP_SYSCMD_GROUP_ADMIN_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    [self rb_processExtendedGroupSystemPayload:RBNormalizedGroupSystemPayload(msg)
                                     msgType:MT59_OF_GROUP_SYSCMD_GROUP_ADMIN_CHANGED_FROM_SERVER
                        fingerPrintOfProtocal:fingerPrintOfProtocal];
}

+ (void) processMT60_OF_GROUP_SYSCMD_GROUP_JOIN_MODE_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg
{
    [self rb_processExtendedGroupSystemPayload:RBNormalizedGroupSystemPayload(msg)
                                     msgType:MT60_OF_GROUP_SYSCMD_GROUP_JOIN_MODE_CHANGED_FROM_SERVER
                        fingerPrintOfProtocal:fingerPrintOfProtocal];
}

@end
