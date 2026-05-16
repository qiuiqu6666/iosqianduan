//telegram @wz662
/**
 * 群成员信息封装类。
 * <p>
 * 本类中的大部分字段意义与服务端数据库字典中“群成员/group_members”表保持一致。
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 * @since 4.3
 */

#import <Foundation/Foundation.h>

@interface GroupMemberEntity : NSObject

/** 用户id */
@property (nonatomic, retain) NSString *user_uid;

/** 所属群id */
@property (nonatomic, retain) NSString *g_id;
/** 本群昵称 */
@property (nonatomic, retain) NSString *nickname_ingroup;

/** 用户昵称 */
@property (nonatomic, retain) NSString *nickname;          // 注：本字段非“群成员/group_members”表中的字段
/** 用户最新头像缓存文件名 */
@property (nonatomic, retain) NSString *userAvatarFileName;// 注：本字段非“群成员/group_members”表中的字段

/**
 * 本字段仅用于客户端UI界面使用，与服务端无关，也无需在服务端和客户端间传递。表示UI界面上的选中情况。
 */
@property (nonatomic, assign, getter=isSelected) BOOL selected;

/**
 * 本字段仅用于客户端UI界面使用，与服务端无关。表示UI界面上的选中情况，默认true。
 * @since 4.4
 */
@property (nonatomic, assign, getter=isEditable) BOOL editable;

/** 角色：0=普通成员，1=管理员，2=群主 */
@property (nonatomic, assign) int role;

/** 入群时间（服务端返回的可读格式，如 "2026-02-09 15:00:00"） */
@property (nonatomic, retain) NSString *join_time;

/** 邀请人UID（如果是被邀请入群的，null=主动加入或创建） */
@property (nonatomic, retain) NSString *invite_by_uid;

/** 邀请人昵称 */
@property (nonatomic, retain) NSString *invite_by_nickname;

@end
