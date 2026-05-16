//telegram @wz662
#import "QueryGroupInfoAsync.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "ViewControllerFactory.h"

@implementation QueryGroupInfoAsync

+ (void)doIt:(NSString *)gid myUserId:(NSString *)myUserId hudParentViewController:(UIViewController *)viewController
{
    [[HttpRestHelper sharedInstance] submitGetGroupInfoToServer:gid myUserId:myUserId complete:^(BOOL sucess, GroupEntity *groupInfo) {
        if(sucess)
        {
            BOOL needAlert = YES;
            
            if(groupInfo != nil)
            {
                // 在查到的信息里看看我是否还要此群中
                BOOL imIsInThisGroup = [groupInfo myselfIsInGroup];

                // 我已不在此群里了
                if(!imIsInThisGroup)
                {
                    DDLogInfo(@"[QueryGroupInfoAsync]【查询群信息】gid=%@, myUserId=%@ 【结果：NO-我已不在此群内！】(尝试清除群列表缓存中的记录）", gid, myUserId);

                    // 尝试更新一下本地群列表（这可能是网络延迟或网络不好的时候，没有加载到最新的群列表，正好此时更新一下）
                    [[[IMClientManager sharedInstance] getGroupsProvider] remove2:groupInfo.g_id];
                }
                // 我在此群里
                else
                {
                    DDLogInfo(@"[QueryGroupInfoAsync]【查询群信息】gid=%@, myUserId=%@ 【结果：YES-我在此群内】(尝试更新群列表缓存中的信息为最新）", gid, myUserId);

                    needAlert = NO;

                    // 将取到的最新群信息先更新到群列表模型中（注意：此时查出最新群信息对象只是把数据更新到了GroupsProvider，而且对象本身）
                    [[[IMClientManager sharedInstance] getGroupsProvider] updateGroup:groupInfo];

                    // 说明：此处应该使用GroupsProvider中的GroupEntity全局对象，那么后绪界面对此对象的修改将全局生效，
                    //      如果直接使用groupInfo这个新对象的话，则后绪界面中的修改就不可能同步到全局GroupsProvider中
                    //      了，因为它们是不同的对象嘛，这一点一定不要理解错了哦！
    //              GroupEntity *toUse = groupInfo;
                    GroupEntity *toUse = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];

                    // 转到群信息查看界面（注意：此GroupEntity是全局对象引用，接下来界面里的修改等都会直接影响此对象值哦）
                    [ViewControllerFactory goGroupInfoViewController:viewController.navigationController withDatas:toUse];
                }
            }

            if(needAlert)
            {
                // 该群不存在
                [BasicTool showAlertInfo:@"没有查到该群信息，该群已解散或您已不在群内！" parent:viewController];
            }
        }
    } hudParentView:viewController.view];
}

// 查看群信息（方法内部将根据有网、无网等情况智能判断并进行相应的信息加载逻辑，确保最大限度查看的是最新数据）
+ (void)gotoWatchGroupInfo:(NSString *)gid withInfo:(nullable GroupEntity *)ge nav:(UINavigationController *)nav view:(UIView *)v vc:(UIViewController *)vc  {
    
    // 有网络的情况下，优先从网络加载最新数据。
    // 即使已有本地缓存 ge，也不要直接使用旧对象进入详情页，
    // 否则普通成员在 app 存活期间会一直看到过期群公告，直到重启后群列表重新拉取。
    if([ClientCoreSDK sharedInstance].connectedToServer){
        UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
        if (localUserInfo != nil) {
            [QueryGroupInfoAsync doIt:gid myUserId:localUserInfo.user_uid hudParentViewController:vc];
        }
        return;
    }

    // 无网时才回退本地缓存数据
    if (ge != nil) {
        [ViewControllerFactory goGroupInfoViewController:nav withDatas:ge];
        return;
    }
    
    // 否则，就读取缓存数据
    GroupsProvider *gp = [[IMClientManager sharedInstance] getGroupsProvider];
    if (gp != nil) {
        GroupEntity *g = [gp getGroupInfoByGid:gid];
        if (g != nil) {
            // 转到转到群信息查看界面
            [ViewControllerFactory goGroupInfoViewController:nav withDatas:g];
            return;
        }
    }
    
    [BasicTool showAlertInfo:@"您的网络不给力，请稍后再试！" parent:vc];
}

@end
