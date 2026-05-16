//telegram @wz662
/**
 * 指令body：一对一好友聊天消息的数据内容对象（原TextMessage）.
 * <p>
 * 即聊天数据从MobileIMSDK底层发送时，会将本对象转JSON字串后，作为
 * Protocal的dataContent数据进行传输。
 * <p>
 * TODO: 优化点
 * MsgBody4Friend里的t、f字段，对一mb v3来说是可以节省下来的，原先
 * 正式好友聊天时也要带上t和f的uid是因为mb v2里作为底层传输时的user_id是
 * 可变的！！而现在不是了，评估一下有没有必要改，如果改动较大则以后再动也不
 * 迟，必须只是多带了2个字段而已，每次多几10来个字节，一个小优化！
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 * @version 1.0
 * @since 2.0_rc11
 */

#import "MsgBody4Friend.h"

@implementation MsgBody4Friend

- (id)init
{
    if(self = [super init])
    {
        // 默认聊天类型设置
        self.cy = CHAT_TYPE_FREIDN_CHAT;
    }
    return self;
}

// 构造好友聊天系统通知(消息)协议体的DTO对象
+ (MsgBody4Friend *) constructFriendSystemMsgBody:(NSString *)f t:(NSString *)t m:(NSString *)m
{
    return [MsgBody4Friend constructFriendChatMsgBody:f t:t m:m ty:TM_TYPE_SYSTEAM_INFO];
}

// 构造好友聊天消息协议体的DTO对象
+ (MsgBody4Friend *) constructFriendChatMsgBody:(NSString *)f t:(NSString *)t m:(NSString *)m ty:(int)ty
{
    MsgBody4Friend * tm = [[MsgBody4Friend alloc] init];
    tm.f = f;
    tm.t = t;
    tm.m = m;
    tm.ty = ty;
    return tm;
}

@end
