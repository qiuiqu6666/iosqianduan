//telegram @wz662
#import "QueryOfflineBeAddFriendsReqAsync.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "AlarmsProvider.h"
#import "ToolKits.h"
#import "UserDefaultsToolKits.h"
#import "TimeTool.h"

@implementation QueryOfflineBeAddFriendsReqAsync

+ (void)doIt:(UIView *)hudParentView
{
    [self doIt:hudParentView completion:nil];
}

+ (void)doIt:(UIView *)hudParentView completion:(void (^)(void))completion
{
    NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid;

    // 查询离线加好友请求数据.
    [[HttpRestHelper sharedInstance] submitGetOfflineAddFriendsReqToServer:localUid complete:^(BOOL sucess, NSArray<UserEntity *> *reqList) {
        // 取离线加好友请求数据成功
        if(sucess && reqList != nil){
            NSSet<NSString *> *filteredUids = [NSSet setWithArray:@[@"10000", @"10001", @"400069", @"400070"]];
            NSMutableArray<UserEntity *> *filtered = [NSMutableArray array];
            for (UserEntity *u in reqList) {
                if (u.user_uid.length == 0) continue;
                if ([filteredUids containsObject:u.user_uid]) continue;
                [UserDefaultsToolKits unmarkDeletedFriendReqUid:u.user_uid];
                [filtered addObject:u];
            }
            if([filtered count] > 0){
                DDLogDebug(@"【QueryOfflineBeAddFriendsReqAsync】离线好友请求读取成功，共有请求数：%lu", (unsigned long)[filtered count]);

                // 最新一条好友请求的数据（服务端返回的加好友请求通知是按发起时间DESC逆序排列的，索引0就是最新的请求，详见HTTP接口说明）
                UserEntity *latestRee = (UserEntity *)[filtered objectAtIndex:0];
                // 根据约定：目前ex10字段仅用于存放“添加好友”请求时的发生时间java时间戳（由服务端设置的，
                // 详见：RosterElementEntity类），其不为空仅限于此场景下，其它场景下用默认系统时间即可
                // 自20180507 RBv4.3以后，本字段存放的是时间戳，而非人类可读的时间字串
                NSDate *latestReqTime = [TimeTool convertJavaTimestampToiOSDate:latestRee.ex10];
//              long latestReqTimestamp = (latestReqTime != nil?[TimeTool getTimeStampWithMillisecond_l:latestReqTime]:0);
                
                // 计算未读的好友请求（当用户点击进入好友请求列表时，此时间点之前的所有请求表示"已读"，
                                // 且会同时存储此次查看时最新的那条请求的时间戳，下次在未进入请求列表界面的情况下，将
                                // 据此值计算未读条数（计算方法是：当目前所有服务端同步过来的未处理请求中，时间戳大于
                                // 上次存储的，即表示这是此后"未读"的，累加起来便是当前的"未读"总数啦）
                int unreadTotlaCount = [QueryOfflineBeAddFriendsReqAsync calculateUnreadFriendReqCount:filtered];
                
                // 添加到首页通知的数据模型中
                [[[IMClientManager sharedInstance] getAlarmsProvider] addAddFriendReqMergeAlarm:latestRee.user_uid friendName:latestRee.nickname reqTime:latestReqTime numToAdd:unreadTotlaCount notify:YES merge:NO];
                // 设置好友请求全局缓存中的总未读数
                [[[IMClientManager sharedInstance] getFriendsReqProvider] setUnreadCount:unreadTotlaCount needNotify:YES];
            } else {
                [[[IMClientManager sharedInstance] getAlarmsProvider] resetAddFriendReqAlarmFlagNum];
                [[[IMClientManager sharedInstance] getFriendsReqProvider] clearUnreadCount:YES];
            }
        }
        void (^cb)(void) = completion;
        if (cb) {
            dispatch_async(dispatch_get_main_queue(), ^{
                cb();
            });
        }
    } hudParentView:hudParentView];
}

/**
 * 从从服务端http接口中加载过来的全部未处理好友请求数据中，计算出当前"未读"总数。
 * <p>
 * 具体的计算和实现逻辑是：当用户点击进入好友请求列表时，此时间点之前的所有请求表示"已读"，且会同时存储此次查
 * 看时最新的那条请求的时间戳，下次在未进入请求列表界面的情况下，将据此值计算未读条数（计算方法是：当目前所有
 * 服务端同步过来的未处理请求中，时间戳大于上次存储的，即表示这是此后"未读"的，累加起来便是当前的"未读"总数啦。
 * </p>
 *
 * @param srcFriendsReqs 未处理的所有好友请求列表（服务端返回的是按DESC请求时间逆序排列的）
 * @return 大于或等于0的整数
 */
+ (int)calculateUnreadFriendReqCount:(NSArray<UserEntity *> *)srcFriendsReqs {

//  long t = System.currentTimeMillis();
    // 返回系统时间戳（单位：毫秒），long表示，形如：1414074342829
    long t = [ToolKits getTimeStampWithMillisecond_l];

    int unreadTotlaCount = 0;
    
    long lastLatestReqTimestamp = [UserDefaultsToolKits getHasReadLatestFriendReqTimestamp];
    // 当不存在已读记录时，直接就把整个未处理数当作未读数
    if (lastLatestReqTimestamp <= 0) {
        unreadTotlaCount = (int)[srcFriendsReqs count];
    }
    else {
        for (UserEntity *req in srcFriendsReqs) {
//          long theTimestamp = CommonUtils.getLongValue(req.getEx10(), 0L);
            NSDate *theTime = [TimeTool convertJavaTimestampToiOSDate:req.ex10];
            long theTimestamp = (theTime != nil?[TimeTool getTimeStampWithMillisecond_l:theTime]:0);
            // 如果服务端返回的请求数据中，不存在或不正确的时间戳，就跳过此条
            if (theTimestamp <= 0) {
                continue;
            }

            // 当请求时间戳大于上次已读的，就表示这是新的"未读"，未读总数+1
            if (theTimestamp > lastLatestReqTimestamp) {
                unreadTotlaCount += 1;
            }
            // 当请求时间戳小于或等于上次的时，表示这些已是上次已读过的，由于整个未
            // 处理列表是是按时间逆序排列，所以可以认为没有必要再继续余下的循环判断了
            else {
                break;
            }
        }
    }

    DDLogDebug(@"【QueryOfflineBeAddFriendsReqAsync】计算出的本次\"未读\"加好友请求总数是 %d，总耗时 %lu ms !", unreadTotlaCount, ([ToolKits getTimeStampWithMillisecond_l]-t));

    return unreadTotlaCount;
}

//+ (void)refreshAddFriendReqAlarm:(RosterElementEntity *)latestReeOfRequest count:(int)unProcessAddFriendReqCout
//{
//    if(unProcessAddFriendReqCout > 0)
//    {
//        if(latestReeOfRequest != nil)
//        {
//            // 添加到首页通知的数据模型中
//            [[[IMClientManager sharedInstance] getAlarmsProvider] addAddFriendReqMergeAlarm:latestReeOfRequest numToAdd:unProcessAddFriendReqCout notify:YES merge:NO];
//        }
//    }
//    else
//    {
//        [[[IMClientManager sharedInstance] getAlarmsProvider] resetAddFriendReqAlarmFlagNum];
//    }
//}

@end
