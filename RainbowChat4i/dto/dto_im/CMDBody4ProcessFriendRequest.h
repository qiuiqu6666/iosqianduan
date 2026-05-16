//telegram @wz662
#import <Foundation/Foundation.h>

@interface CMDBody4ProcessFriendRequest : NSObject

/** 发起好友请求的源用户（A）UID  */
@property (nonatomic, retain) NSString *srcUserUid;
/**
 * 发起好友请求的源用户（A）Mail地址（此地址在服务端处理好友请求时尝试查找该人员的user_id时有用）  */
//@property (nonatomic, retain) NSString *srcUserMail;
/** 接收好友请求的目标用户（B）UID，也是本次处理好友请求的发起方  */
@property (nonatomic, retain) NSString *localUserUid;
/**
 * 接收好友请求的目标用户（B）Mail地址（此地址在服务端处理好友请求时尝试查找该人员的user_id时有用）
 * ，也是本次处理好友请求的发起方  */
//@property (nonatomic, retain) NSString *localUserMail;
/**
 * 处理者的昵称：此字段在"拒绝"操作时有用哦.
 */
@property (nonatomic, retain) NSString *localUserNickName;

@end
