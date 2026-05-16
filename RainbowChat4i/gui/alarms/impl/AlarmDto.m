//telegram @wz662
#import "AlarmDto.h"
#import "AlarmType.h"
#import "EVAToolKits.h"
#import "MsgBody4Guest.h"

@implementation AlarmDto

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.alarmType = AMT_undefine;
        self.alwaysTop = NO;
        self.atMe = NO;
        self.conversationMsgSeq = 0;
    }
    return self;
}

//- (MsgBody4Guest *) getExtraObj_for_tempChatMessage
//{
//    if(self.extraObj != nil && [self.extraObj isKindOfClass:[MsgBody4Guest class]])
//        return (MsgBody4Guest *)self.extraObj;
//    return nil;
//}
//- (void) setExtraObj_for_tempChatMessage:(NSString *)extraObjJason
//{
//    self.extraObj = [EVAToolKits fromJSON:extraObjJason withClazz:MsgBody4Guest.class];
//}
//
//- (RosterElementEntity *) getExtraObj_for_reviceMessage
//{
//    if(self.extraObj != nil && [self.extraObj isKindOfClass:[RosterElementEntity class]])
//        return (RosterElementEntity *)self.extraObj;
//    return nil;
//}
//- (void) setExtraObj_for_reviceMessage:(NSString *)extraObjJason
//{
//    self.extraObj = [EVAToolKits fromJSON:extraObjJason withClazz:RosterElementEntity.class];
//}
//
//- (RosterElementEntity *) getExtraObj_for_addFriendBeReject
//{
//    return [self getExtraObj_for_reviceMessage];
//}
//
//- (NSString *)getExtraObj_for_groupChatMessage
//{
//    if(self.extraObj != nil && [self.extraObj isKindOfClass:[NSString class]])
//        return (NSString *)self.extraObj;
//    return nil;
//}
//- (void) setExtraObj_for_groupChatMessage:(NSString *)extraObjJason
//{
//    self.extraObj = extraObjJason;
//}

@end
