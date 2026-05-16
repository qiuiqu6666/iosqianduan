//telegram @wz662
/**
 * 用于封装用户添加好友请求的元数据类.
 *
 * <p>
 * 本类目前用于客户端A发起加好友请求时向服务端发送的数据对象.
 *
 * @author Jack Jiang, 2017-11-16
 * @version 1.0
 */

#import <Foundation/Foundation.h>

@interface CMDBody4AddFriendRequest : NSObject

/** 发起请求的好友uid（本地用户） */
@property (nonatomic, retain) NSString *localUserUid;
/** 将要被添加的好友uid */
@property (nonatomic, retain) NSString *friendUserUid;

/** 加好友时的验证说明（由请求发出方填写，像QQ一样） */
@property (nonatomic, retain) NSString *desc;

/** 添加来源（如 search_uid, search_email, search_phone, card, group, random, qrcode）。 @since 12.0 */
@property (nonatomic, retain) NSString *addSource;

@end
