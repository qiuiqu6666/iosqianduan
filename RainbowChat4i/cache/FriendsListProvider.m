//telegram @wz662
#import "FriendsListProvider.h"
#import "IMClientManager.h"
#import "AppDelegate.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "UserDefaultsToolKits.h"
// ⭐ v4: 已废弃 QueryOfflineChatMsgAsync
// #import "QueryOfflineChatMsgAsync.h"
#import "BasicTool.h"


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface FriendsListProvider ()

/* 数据结构形如：<RosterElementEntity *> */
@property (strong, nonatomic) NSMutableArrayObservableEx *friendsData;

/*
 * 好友列表数据影子集合（Hash表形式，即<String, RosterElementEntity>），主要用于按uid查找好友数据时，当好友数量较多时能提高查找性能。
 * <p>
 * 本集合中的好友数据对象引用的是 {@link #rosterData} 集合的同一个对象，属浅拷贝。
 * @since 4.3
 */
@property (strong, nonatomic) NSMutableDictionary<NSString *, UserEntity *> *rosterDataHash;

@end


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation FriendsListProvider

- (NSArray<UserEntity *> *)rb_filterBlockedFriends:(NSArray<UserEntity *> *)source
{
    if (source.count == 0) {
        return source;
    }
    NSMutableArray<UserEntity *> *filtered = [NSMutableArray arrayWithCapacity:source.count];
    for (UserEntity *ree in source) {
        if (ree.user_uid.length > 0 && [UserDefaultsToolKits isFriendChatSendBlockedUid:ree.user_uid]) {
            continue;
        }
        [filtered addObject:ree];
    }
    return filtered;
}

- (void)rb_mergePresenceStateFromCache:(NSArray<UserEntity *> *)newDatas
{
    if (newDatas.count == 0 || self.rosterDataHash.count == 0) return;
    for (UserEntity *n in newDatas) {
        if (n.user_uid.length == 0) continue;
        UserEntity *o = [self.rosterDataHash objectForKey:n.user_uid];
        if (!o) continue;
        long long oOnline = [o.onlineStartTime longLongValue];
        long long oOff = [o.offlineTime longLongValue];
        long long oEvent = (oOnline > oOff) ? oOnline : oOff;
        long long nOnline = [n.onlineStartTime longLongValue];
        long long nEvent = nOnline;
        if (oEvent > nEvent) {
            n.liveStatus = o.liveStatus;
            n.onlineStartTime = o.onlineStartTime;
            n.offlineTime = o.offlineTime;
        } else {
            n.offlineTime = nil;
            if (n.liveStatus == LIVE_STATUS_OFFLINE) {
                n.onlineStartTime = nil;
            }
        }
    }
}

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.friendsData = [[NSMutableArrayObservableEx alloc] init];
        self.rosterDataHash = [[NSMutableDictionary alloc] init];
    }
    return self;
}


//---------------------------------------------------------------------
#pragma mark - 訪客列表数据模型基本方法

- (void)putFriend:(int)index withEntity:(UserEntity *)ree
{
    NSString *uid = ree.user_uid;
    if (uid.length > 0 && [UserDefaultsToolKits isFriendChatSendBlockedUid:uid]) {
        return;
    }
    // 如果该好友已经存在于好友列表中（此种情况可能是服务端处理出错了
    // ，重复把好友信息发过来了，理论上此种边界问题不太可能存在），则
    // 发过来的对象覆盖上去（怎么说也算是最新数据了）
    if([self isUserInRoster:uid])
    {
        // 先从列表中移除（以便再次加入到时能加到列表首位置）
        [self remove:[self getIndex:uid] uid:uid notify:NO];
    }
    [self.friendsData add:index withObj:ree];
    
    // !加入影子集合中
    [self.rosterDataHash setObject:ree forKey:uid];
}

- (void)putFriend:(UserEntity *)ree
{
    // 默认将新好友加到列表头部
    [self putFriend:0 withEntity:ree];
}

- (BOOL)remove:(int)index uid:(NSString *)uid
{
    return [self remove:index uid:uid notify:YES];
}

- (BOOL)remove:(int)index uid:(NSString *)uid notify:(BOOL)notifyObserver
{
    BOOL ok = [self.friendsData remove:index needNotify:notifyObserver] != nil;
    // !从影子集合中移除
    [self.rosterDataHash removeObjectForKey:uid];
    return ok;
}

// @deprecated 本方法将于v4.3及以后版本中过时，请使用：{@link #getFriendInfoByUid2:}
- (UserEntity *)getFriendInfoByUid:(NSString *)uid
{
    return [self getFriendInfoByUserId:uid];
}

- (UserEntity *)getFriendInfoByUid2:(NSString *)uid
{
    return [self.rosterDataHash objectForKey:uid];
}

// @deprecated 本方法将于v4.3及以后版本中过时，请使用：{@link #getFriendInfoByUid2:}
- (UserEntity *)getFriendInfoByUserId:(NSString *)user_id
{
    if(self.friendsData != nil)
    {
        for(UserEntity *ree in [self.friendsData getDataList])
        {
            if([ree.user_uid isEqualToString:user_id])
                return ree;
        }
    }

    return nil;
}

- (NSMutableArrayObservableEx *)getFriendsData
{
    return self.friendsData;
}

// @deprecated 本方法将于v4.3及以后版本中过时，请使用：{@link #isUserInRoster2:}
- (BOOL)isUserInRoster:(NSString *)uid
{
    if(self.friendsData != nil)
    {
        for(UserEntity *ree in [self.friendsData getDataList])
        {
            if([ree.user_uid isEqualToString:uid])
                return YES;
        }
    }
    return NO;
}

- (BOOL)isUserInRoster2:(NSString *)uid
{
    return [self.rosterDataHash objectForKey:uid] != nil;
}

- (int)getIndex:(NSString *)uid
{
    int index = -1;
    if(self.friendsData != nil)
    {
        for(int i = 0; i < [[self.friendsData getDataList] count]; i++)
        {
            UserEntity *ree = (UserEntity *)[self.friendsData get:i];
            if([ree.user_uid isEqualToString:uid])
            {
                index = i;
                break;
            }
        }
    }
    return index;
}

/**
 * 返回指定用户所在好友列中的索引位置.
 *
 * @param r
 * @return
 */
- (int)getIndexWithObj:(UserEntity *)r
{
    return [self getIndex:r.user_uid];
}

- (int)onlineCount
{
    int onlineCount = 0;
    if(self.friendsData != nil)
    {
        for(UserEntity *ree in [self.friendsData getDataList])
        {
            if([ree isOnline])
                onlineCount += 1;
        }
    }
    return onlineCount;
}

- (NSInteger)size
{
    return [[self.friendsData getDataList] count];
}

- (void)offlineAll
{
    if(self.friendsData != nil)
    {
        for(UserEntity *ree in [self.friendsData getDataList])
            // 只更新在线状态为离线，不覆盖 latest_login_time（服务端是权威数据源）
            [ree updateLiveStatus:LIVE_STATUS_OFFLINE];
    }
}

/**
 * 用新的好友列表数据集合覆盖原有的数据。
 */
- (void)putFriends:(NSArray<UserEntity *> *)newDatas
{
    newDatas = [self rb_filterBlockedFriends:newDatas];
    [self rb_mergePresenceStateFromCache:newDatas];
    // 批量数据插入时先不更新ui（防止浪费性能）
    [self.friendsData putDataList:newDatas needNotify:NO];

    UserEntity *lastEntity = nil;
    if([[self.friendsData getDataList] count] > 0)
    {
        // 取出最后一个数据单元
        lastEntity = (UserEntity *)[[self.friendsData getDataList] objectAtIndex:([[self.friendsData getDataList] count] - 1)];
    }

    // 数据全部插完后再更新UI（在好友很多的情况下可以提升性能撒）
    [self.friendsData notifyObservers:UpdateTypeToObserverUNKNOW
                          whithExtra:lastEntity];// 用最后一个数据单元来通知观察者哦（观察者会不会使用这个data那是它的事）
    
    // !加入影子集合中
    [self.rosterDataHash removeAllObjects];
    for(UserEntity *ree in newDatas) {
        if(ree != nil) {
            [self.rosterDataHash setObject:ree forKey:ree.user_uid];
        }
    }
}


//---------------------------------------------------------------------
#pragma mark - 訪客列表数据加载和处理方法

- (void)refreshFriendsDataAsync:(void (^)(BOOL sucess))refreshComplete
{
    NSString *localServicerUid = [[IMClientManager sharedInstance] localUserInfo].user_uid;

    [[HttpRestHelper sharedInstance] submitGetRosterToServer:localServicerUid complete:^(BOOL sucess, NSArray<UserEntity *> *newRosterList) {

        if(sucess)
        {
            [self rb_mergePresenceStateFromCache:newRosterList];
//            DDLogDebug(@"【RosterProvider】正在刷新好友列表，原始列表数据长度：%lu", (unsigned long)[newRosterList count]);

            // ############################## 无条件更新一下好友的在线状态，从而触发通知上下线观察者
            // ############################## ，此举是为了解决掉线重陆后取到的好友列表时在线状态被设置时
            // ############################## （在服务端设置的（从DB中取出）），观察者还未被设置的情况，
            // ############################## ，此情况若不处理，将导致当打开了与该好友的聊天界面时，掉线重
            // ############################## 登将不能触发上下线通知哦
            if(newRosterList != nil && [newRosterList count] > 0)
            {
                for(UserEntity *newRee in newRosterList) {
//                  newRee.liveStatus = newRee.liveStatus;
                    [newRee updateLiveStatus:newRee.liveStatus];// 20250127??
                }
            }

            // 从服务端获取到最新好友列表后，补充和缓存 latest_login_time
            [self mergeAndCacheLatestLoginTime:newRosterList];
            
            // 用最新的好友表数据刷新好友列表
            [self putFriends:newRosterList];

            DDLogDebug(@"【RosterProvider】好友列表读取成功，共有好友数：%ld", newRosterList != nil ? [newRosterList count] : 0);

//            // 更新好友列表数据成功后，尝试获取本人可能收到的离线消息（更新）
//            // 更新好友列表有2种情况：第1是在首次登陆成功时、第2是在中途掉线重登成功时
//            // 好友上线了就尝试获取该用户可能发过来的离线消息（此时离线消息可能会
//            // 在网络情况复杂的情况下发生（比如对方在发时我被判定不在线，但实际我是在线的等等））
////            new QueryOfflineChatMsgAsync(context).execute();
//            [QueryOfflineChatMsgAsync doIt:nil hudParentView:nil];

            // 刷新成功回调
            if(refreshComplete != nil)
                refreshComplete(YES);
        }
        else
        {
            DDLogDebug(@"【RosterProvider】好友列表从服务端获取失败.");

            // 刷新失败
            if(refreshComplete != nil)
                refreshComplete(NO);
        }
    } hudParentView:nil];
}

/**
 * 处理好友的 latest_login_time 字段。
 * 
 * 逻辑：服务端 1008-2-7 接口现在返回权威的 latest_login_time，
 * 直接使用服务端返回的值，不再与本地缓存做比较（本地缓存已不再写入）。
 * 服务端未返回时，该字段保持 nil，UI 上显示"离线"。
 */
- (void)mergeAndCacheLatestLoginTime:(NSArray<UserEntity *> *)rosterList
{
    // 服务端现在是 latest_login_time 的权威数据源，
    // EVAToolKits fromDictionaryToObject 已经自动将服务端字段映射到 UserEntity，
    // 此处无需额外处理。保留方法签名以减少对调用方的改动。
}

@end
