//telegram @wz662
#import "NotificationCenterFactory.h"
#import "Default.h"
#import "AlarmType.h"

@implementation NotificationCenterFactory

static NSString * const kNotificationCenter_For_FriendChatSendBlockedStateChanged = @"kNotificationCenter_For_FriendChatSendBlockedStateChanged";
static NSString * const kNotificationCenter_For_GroupNotificationsRealtime = @"kNotificationCenter_For_GroupNotificationsRealtime";

// 注册通知：强制刷新首页"消息"tab上的总未读数
+ (void)refreshMainPageTotalUnread_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_Refresh_TotalUnread
                                               object:nil];
}
// 取消注册通知：强制刷新"消息"tab上的总未读数
+ (void)refreshMainPageTotalUnread_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_Refresh_TotalUnread object:nil];
}
// 发出通知：强制首页的“消息”Tab上的总未读数
+ (void)refreshMainPageTotalUnread_POST
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_Refresh_TotalUnread object:nil];
}

// 注册通知：注册成功界面回来时（用于通知登陆界面显示刚才注册成功的用户名和密码，这样用户注册完就不用重复输入了）
+ (void)registerSucessBack_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_Register_Sucess_Back
                                               object:nil];
}
// 取消注册通知：注册成功界面回来时（用于通知登陆界面显示刚才注册成功的用户名的密码，这样用户注册完就不用重复输入了）
+ (void)registerSucessBack_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_Register_Sucess_Back object:nil];
}
// 发出通知：注册成功界面回来时（用于通知登陆界面显示刚才注册成功的用户名的密码，这样用户注册完就不用重复输入了）
+ (void)registerSucessBack_POST:(UserRegisterDTO *)userRegisterDTO
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_Register_Sucess_Back object:userRegisterDTO];
}

// 注册通知：好友请求处理界面回来时（用于通知前一个界面——即未处理验证通知列表界面中清除掉本条已处理完成的请求(而不需要再次从网络加载列表数据，提升体验））
+ (void)processCompleteFriendReq_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_ProcessCompleteFriendReq
                                               object:nil];
}
// 取消注册通知：好友请求处理界面回来时（用于通知前一个界面——即未处理验证通知列表界面中清除掉本条已处理完成的请求(而不需要再次从网络加载列表数据，提升体验））
+ (void)processCompleteFriendReq_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_ProcessCompleteFriendReq object:nil];
}
// 发出通知：好友请求处理界面回来时（用于通知前一个界面——即未处理验证通知列表界面中清除掉本条已处理完成的请求(而不需要再次从网络加载列表数据，提升体验））
+ (void)processCompleteFriendReq_POST:(NSString *)beProcessedFriendUID
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_ProcessCompleteFriendReq object:@{@"uid":beProcessedFriendUID, @"msgType":@(AMT_addFriendRequest)}];
}

// 注册通知：重置群组头像缓存，用于保证本地影响群头像生成的操作，能在其它UI界面中及时将群头像刷新为最新，因为删除群员
//          、邀请群员等操作会在服务端重新生成群头像，此广播就是以低耦合的方式实现本地聊头像UI刷新 的通知，如果没有此通知则因为
//          其它UI界面中为了提高性能而已缓存了的老的群头像，将不会得到及时更新，直到重启APP吧).
+ (void)resetGroupAvatarCache_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_ResetGroupAvatarCache
                                               object:nil];
}
// 取消注册通知：重置群组头像缓存，用于保证本地影响群头像生成的操作，能在其它UI界面中及时将群头像刷新为最新，因为删除群员
//          、邀请群员等操作会在服务端重新生成群头像，此广播就是以低耦合的方式实现本地聊头像UI刷新 的通知，如果没有此通知则因为
//          其它UI界面中为了提高性能而已缓存了的老的群头像，将不会得到及时更新，直到重启APP吧).
+ (void)resetGroupAvatarCache_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_ResetGroupAvatarCache object:nil];
}
// 发出通知：重置群组头像缓存，用于保证本地影响群头像生成的操作，能在其它UI界面中及时将群头像刷新为最新，因为删除群员
//          、邀请群员等操作会在服务端重新生成群头像，此广播就是以低耦合的方式实现本地聊头像UI刷新 的通知，如果没有此通知则因为
//          其它UI界面中为了提高性能而已缓存了的老的群头像，将不会得到及时更新，直到重启APP吧).
+ (void)resetGroupAvatarCache_POST:(NSString *)gid
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_ResetGroupAvatarCache object:gid];
}

// 注册通知：退群(作为普通群员时)或解散群(作为群主时)时，通知群聊界面，以便群聊界面在收到通知后能自动关闭（因为已不在此群或群已不存在了嘛）
//        （补充说明：目前退群或解散群是在群信息查看界面中操作，而群信息查看界面是从群聊天界面进入的）
+ (void)quitOrDismissGroupComplete_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_QuitOrDismissGroupComplete
                                               object:nil];
}
// 取消注册通知：退群(作为普通群员时)或解散群(作为群主时)时，通知群聊界面，以便群聊界面在收到通知后能自动关闭（因为已不在此群或群已不存在了嘛）
//        （补充说明：目前退群或解散群是在群信息查看界面中操作，而群信息查看界面是从群聊天界面进入的）
+ (void)quitOrDismissGroupComplete_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_QuitOrDismissGroupComplete object:nil];
}
// 发出通知：退群(作为普通群员时)或解散群(作为群主时)时，通知群聊界面，以便群聊界面在收到通知后能自动关闭（因为已不在此群或群已不存在了嘛）
//        （补充说明：目前退群或解散群是在群信息查看界面中操作，而群信息查看界面是从群聊天界面进入的）
+ (void)quitOrDismissGroupComplete_POST//:(NSString *)hintContent
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_QuitOrDismissGroupComplete object:nil];
}

// 注册通知：拉黑用户时，通知前面的界面，以便之前界面在收到通知后能自动关闭（比如跟此人的聊天界面，因已拉黑，跟它的聊天界面就没必要显示了嘛）
//        （补充说明：目前此通知主要用于从聊天界面进入到此人的信息查看界面中进行拉黑操作时，从而让聊天界面能自动关闭，不然体验就有点怪异了）
+ (void)blockUserComplete_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_BlockUserComplete
                                               object:nil];
}
// 取消注册通知：拉黑用户时，通知前面的界面，以便之前界面在收到通知后能自动关闭（比如跟此人的聊天界面，因已拉黑，跟它的聊天界面就没必要显示了嘛）
//        （补充说明：目前此通知主要用于从聊天界面进入到此人的信息查看界面中进行拉黑操作时，从而让聊天界面能自动关闭，不然体验就有点怪异了）
+ (void)blockUserComplete_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_BlockUserComplete object:nil];
}
// 发出通知：拉黑用户时，通知前面的界面，以便之前界面在收到通知后能自动关闭（比如跟此人的聊天界面，因已拉黑，跟它的聊天界面就没必要显示了嘛）
//        （补充说明：目前此通知主要用于从聊天界面进入到此人的信息查看界面中进行拉黑操作时，从而让聊天界面能自动关闭，不然体验就有点怪异了）
+ (void)blockUserComplete_POST:(NSString *)uidBeBlocked
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_BlockUserComplete object:uidBeBlocked];
}

// 注册通知：短视频录制成功完成后，从录制界面回来时（用于通知前一个界面——继续进行短视频的文件上传等后续处理）
+ (void)shortVideoRecordComplete_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_RecordCompleteShortVideo
                                               object:nil];
}
// 取消注册通知：短视频录制成功完成后，从录制界面回来时（用于通知前一个界面——继续进行短视频的文件上传等后续处理）
+ (void)shortVideoRecordComplete_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_RecordCompleteShortVideo object:nil];
}
// 发出通知：短视频录制成功完成后，从录制界面回来时（用于通知前一个界面——继续进行短视频的文件上传等后续处理）
+ (void)shortVideoRecordComplete_POST:(ShortVideoRecordedDTO *)dto
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_RecordCompleteShortVideo object:dto];
}

// 注册通知：消息"撤回"功能中当收到撤回指令的应答
+ (void)revokeCMDRecieved_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_RevokeCMDRecieved
                                               object:nil];
}
// 取消注册通知：消息"撤回"功能中当收到撤回指令的应答
+ (void)revokeCMDRecieved_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_RevokeCMDRecieved object:nil];
}
// 发出通知：消息"撤回"功能中当收到撤回指令的应答时。
+ (void)revokeCMDRecieved_POST:(NSString *)fpForRevokeCMD fpForRMessage:(NSString *)fpForRMessage
{
    RevokeCMDRecievedDTO *dto = [[RevokeCMDRecievedDTO alloc] init];
    dto.fpForRevokeCMD = fpForRevokeCMD;
    dto.fpForRMessage = fpForRMessage;
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_RevokeCMDRecieved object:dto];
}

// 注册通知：修改完成好友的备注后
+ (void)friendRemarkChanged_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_FriendRemarkChanged
                                               object:nil];
}
// 取消注册通知：修改完成好友的备注后
+ (void)friendRemarkChanged_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_FriendRemarkChanged object:nil];
}
// 发出通知：修改完成好友的备注后
+ (void)friendRemarkChanged_POST:(UserEntity *)latestRee
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_FriendRemarkChanged object:latestRee];
}

// 注册通知：收到群主修改群名称后
+ (void)groupNameChanged_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_GroupNameChanged
                                               object:nil];
}
// 取消注册通知：收到群主修改群名称后
+ (void)groupNameChanged_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_GroupNameChanged object:nil];
}
// 发出通知：收到群主修改群名称后
+ (void)groupNameChanged_POST:(NSString *)gid newGroupName:(NSString *)newGroupName
{
    DDLogDebug(@"【群名称更新】开始广播通知群名称被修改了。(gid=%@，newGroupName=%@)", gid, newGroupName);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_GroupNameChanged object:@{@"gid":gid, @"newGroupName":newGroupName}];
}

// ========== 大群（读扩散）新消息拉取通知 ==========

static NSString * const kNotificationCenter_For_LargeGroupPull = @"kNotificationCenter_For_LargeGroupPull";

+ (void)largeGroupPullNotify_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_LargeGroupPull
                                               object:nil];
}

+ (void)largeGroupPullNotify_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_LargeGroupPull object:nil];
}

+ (void)largeGroupPullNotify_POST:(NSString *)gid seq:(long long)seq
{
    NSLog(@"【大群读扩散】广播拉取通知: gid=%@, seq=%lld", gid, seq);
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_LargeGroupPull
                                                        object:@{@"gid": gid ?: @"", @"seq": @(seq)}];
}

+ (void)groupNotificationsRealtime_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_GroupNotificationsRealtime
                                               object:nil];
}

+ (void)groupNotificationsRealtime_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_GroupNotificationsRealtime object:nil];
}

+ (void)groupNotificationsRealtime_POST:(NSString *)gid msgType:(NSInteger)msgType raw:(NSDictionary *)raw
{
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"gid"] = gid ?: @"";
    payload[@"msgType"] = @(msgType);
    if ([raw isKindOfClass:[NSDictionary class]]) {
        payload[@"raw"] = raw;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_GroupNotificationsRealtime
                                                        object:payload];
}

+ (void)friendChatSendBlockedStateChanged_ADD:(id)observer selector:(SEL)sel
{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel
                                                 name:kNotificationCenter_For_FriendChatSendBlockedStateChanged
                                               object:nil];
}

+ (void)friendChatSendBlockedStateChanged_REMOVE:(id)observer
{
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:kNotificationCenter_For_FriendChatSendBlockedStateChanged object:nil];
}

+ (void)friendChatSendBlockedStateChanged_POST:(NSString *)uid blocked:(BOOL)blocked hint:(NSString *)hint
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_FriendChatSendBlockedStateChanged
                                                        object:@{
                                                            @"uid": uid ?: @"",
                                                            @"blocked": @(blocked),
                                                            @"hint": hint ?: @""
                                                        }];
}

@end
