//telegram @wz662
#import <Foundation/Foundation.h>
#import "MsgBody4Group.h"

@interface ChatMessageEventProcessor : NSObject

+ (void) processMT45_OF_GROUP_CHAT_MSG_SERVER_TO_B:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

+ (void) processMT46_OF_GROUP_SYSCMD_MYSELF_BE_INVITE_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

+ (void) processMT47_OF_GROUP_SYSCMD_COMMON_INFO_FROM_SERVER:(NSString *)fingerPrintOfProtocal fromUid:(NSString *)fromUid withMsg:(NSString *)msg;

+ (void) processMT48_OF_GROUP_SYSCMD_DISMISSED_FROM_SERVER:(NSString *)fingerPrintOfProtocal fromUid:(NSString *)fromUid withMsg:(NSString *)msg;

+ (void) processMT49_OF_GROUP_SYSCMD_YOU_BE_KICKOUT_FROM_SERVER:(NSString *)fingerPrintOfProtocal fromUid:(NSString *)fromUid withMsg:(NSString *)msg;

+ (void) processMT50_OF_GROUP_SYSCMD_SOMEONEB_REMOVED_FROM_SERVER:(NSString *)fingerPrintOfProtocal fromUid:(NSString *)fromUid withMsg:(NSString *)msg;

+ (void) processMT51_OF_GROUP_SYSCMD_GROUP_NAME_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

+ (void) processMT52_OF_GROUP_NOTIFY_JOIN_REQUEST:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

+ (void) processMT53_OF_GROUP_NOTIFY_JOIN_REVIEW_RESULT:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

+ (void) processMT54_OF_GROUP_NOTIFY_ADMIN_OPERATION:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

+ (void) processMT55_OF_GROUP_SYSCMD_GROUP_AVATAR_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

+ (void) processMT56_OF_GROUP_SYSCMD_GROUP_MUTE_MODE_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

+ (void) processMT57_OF_GROUP_SYSCMD_GROUP_INVITE_PERMISSION_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

+ (void) processMT58_OF_GROUP_SYSCMD_GROUP_MEMBER_PRIVACY_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

+ (void) processMT59_OF_GROUP_SYSCMD_GROUP_ADMIN_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

+ (void) processMT60_OF_GROUP_SYSCMD_GROUP_JOIN_MODE_CHANGED_FROM_SERVER:(NSString *)fingerPrintOfProtocal msg:(NSString *)msg;

@end
