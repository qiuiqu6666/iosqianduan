//telegram @wz662
#import "UserEntity.h"
#import "BasicTool.h"
#import "IMClientManager.h"

@implementation UserEntity

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.liveStatus = LIVE_STATUS_OFFLINE;
    }
    return self;
}

- (void)online
{
    [self updateLiveStatus:LIVE_STATUS_ONLINE];
}

- (void)offline
{
    // 服务端 1008-2-7 接口现在返回权威的 latest_login_time，
    // 客户端不再在本地覆写此字段，避免 offlineAll 或 MT07 时用本机时间
    // 把服务端真实的"最近登录时间"覆盖掉。
    [self updateLiveStatus:LIVE_STATUS_OFFLINE];
}

- (void)updateLiveStatus:(int)liveStatus
{
    _liveStatus = liveStatus;

    // 并把上下线状态改变通知给观察者
    ObserverCompletion liveStatusChangeObs = [[IMClientManager sharedInstance] getLiveStatusChangeObs];
    if(liveStatusChangeObs != nil)
    {
        liveStatusChangeObs(nil
                // 通知的数据是一个String[]数组：元素0是昵称、元素1是上下线状态、元素2是uid
                , @[self.nickname, [NSString stringWithFormat:@"%d", self.liveStatus], self.user_uid]);
    }
}

- (BOOL)isOnline
{
    return self.liveStatus == LIVE_STATUS_ONLINE;
}

- (BOOL)isMan
{
    return [self.user_sex isEqualToString:@SEX_MAN];
}

// 获取好友的备注昵称，当设置了好友备注时则返回的是备注，否则返回的是原昵称
- (NSString *)getNickNameWithRemark
{
    if([BasicTool isStringEmpty: [BasicTool trim:self.friendRemark]])
        return self.nickname;
    return self.friendRemark;
}

- (UserEntity *)clone
{
    UserEntity *cloneRee = [[UserEntity alloc] init];

    cloneRee.ex1 = self.ex1;
    cloneRee.ex10 = self.ex10;
    cloneRee.ex11 = self.ex11;
    cloneRee.ex12 = self.ex12;
    cloneRee.ex13 = self.ex13;
    cloneRee.ex14 = self.ex14;
    cloneRee.ex15 = self.ex15;
    cloneRee.userAvatarFileName = self.userAvatarFileName;
    cloneRee.whatsUp = self.whatsUp;
    cloneRee.maxFriend = self.maxFriend;
    cloneRee.userDesc = self.userDesc;
    cloneRee.userType = self.userType;
    cloneRee.user_uid = self.user_uid;
    cloneRee.user_mail = self.user_mail;
    cloneRee.nickname = self.nickname;
    cloneRee.user_sex = self.user_sex;
    cloneRee.register_time = self.register_time;
    cloneRee.latest_login_time = self.latest_login_time;
    cloneRee.liveStatus = self.liveStatus;
    cloneRee.onlineStartTime = self.onlineStartTime;
    cloneRee.offlineTime = self.offlineTime;
    cloneRee.token = self.token;
    
    cloneRee.friendRemark = self.friendRemark;
    cloneRee.friendMobileNum = self.friendMobileNum;
    cloneRee.friendMoreDesc = self.friendMoreDesc;
    cloneRee.friendPicFileName = self.friendPicFileName;
    cloneRee.is_starred = self.is_starred;
    cloneRee.userPsw = self.userPsw;
    cloneRee.phoneNum = self.phoneNum;

    return cloneRee;
}

// 将服务端的保存的最近登陆时间（是Java服务端生成的无时区时间戳长整数）转成iOS上的本地时区时间字符串（解决此时间在跨国用户的客户端显示问题）
- (NSString *)getLatestLoginTimeStr
{
    NSString *timestampWithGMT = self.latest_login_time;
    if(![BasicTool isStringEmpty:timestampWithGMT])
        return [TimeTool convertJavaTimestampToiOSTimeStr:timestampWithGMT convertTo:@"yyyy-MM-dd HH:mm"];
    return nil;
}

@end
