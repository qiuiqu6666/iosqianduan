//telegram @wz662
#import "MsgBody4Group.h"

@implementation MsgBody4Group

- (id)init
{
    if(self = [super init])
    {
        // 默认聊天类型设置
        self.cy = CHAT_TYPE_GROUP_CHAT;
    }
    return self;
}

+ (MsgBody4Group *)constructGroupSystenMsgBody:(NSString *)toGid msg:(NSString *)msg
{
    return [MsgBody4Group constructGroupChatMsgBody:TM_TYPE_SYSTEAM_INFO
                                        // 此值一定是"0"，因为是服务端发给客户端的嘛
                                         srcUserUid:@"0"
                                        // 服务端发送的系统级消息，没昵称
                                        srcNickName:@""
                                              toGid:toGid
                                                msg:msg
                                           parentFp:nil
                                                 at:nil];
}

+ (MsgBody4Group *)constructGroupChatMsgBody:(int)msgType srcUserUid:(NSString *)srcUserUid srcNickName:(NSString *)srcNickName toGid:(NSString *)toGid msg:(NSString *)msg parentFp:(NSString *)parentFp at:(NSArray<NSString *> *)atUsers
{
    MsgBody4Group *tcmd = [[MsgBody4Group alloc] init];
    tcmd.f = srcUserUid;
    tcmd.nickName = srcNickName;
    tcmd.t = toGid;
    tcmd.m = msg;
    tcmd.ty = msgType;
    tcmd.parentFp = parentFp;
    tcmd.at = atUsers;
    return tcmd;
}

@end
