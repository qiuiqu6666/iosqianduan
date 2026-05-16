//telegram @wz662
/**
 * “我”被在功邀请加入到群聊的系统通知协议数据体。
 */

#import "GroupEntity.h"

@interface CMDBody4MyselfBeInvitedGroupResponse : GroupEntity

/** 邀请人的UID（此字段可为空，为空则表示并非邀请而是主动加入的）. */
@property (nonatomic, retain) NSString *inviteBeUid;
/** 邀请人的昵称（此字段可为空，为空则表示并非邀请而是主动加入的）. */
@property (nonatomic, retain) NSString *initveBeNickName;

@end
