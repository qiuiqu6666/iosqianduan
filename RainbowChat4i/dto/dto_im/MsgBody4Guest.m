//telegram @wz662
#import "MsgBody4Guest.h"

@implementation MsgBody4Guest

- (id)init
{
    if(self = [super init])
    {
        // 默认聊天类型设置
        self.cy = CHAT_TYPE_GUEST_CHAT;
    }
    return self;
}

+ (MsgBody4Guest *) constructGuestChatMsgBody:(int)msgType srcUserUid:(NSString *)srcUserUid srcNickName:(NSString *)srcNickName friendUid:(NSString *)friendUid msg:(NSString *)msg
{
    MsgBody4Guest *tcmd = [[MsgBody4Guest alloc] init];
    tcmd.f = srcUserUid;
    tcmd.nickName = srcNickName;
    tcmd.t = friendUid;
    tcmd.ty = msgType;
    tcmd.m = msg;

    return tcmd;
}

- (MsgBody4Guest *)clone
{
    MsgBody4Guest *cloneRee = [[MsgBody4Guest alloc] init];

    cloneRee.f = self.f;
    cloneRee.t = self.t;
    cloneRee.m = self.m;
    cloneRee.cy = self.cy;
    cloneRee.ty = self.ty;
    cloneRee.nickName = self.nickName;
//    cloneRee.userAvatarFileName = self.userAvatarFileName;

    return cloneRee;
}

@end
