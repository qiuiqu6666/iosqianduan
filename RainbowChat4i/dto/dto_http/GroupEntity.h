//telegram @wz662
/**
 * 群组信息封装类。
 * <p>
 * 本类中的大部分字段意义与服务端数据字典中“群基本信息/group_base”表保持一致。
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 * @since 4.3
 */

#import <Foundation/Foundation.h>

/**
 * BBS聊天（即世界频道）所对应的群组聊天id（因为世界频道是个特殊
 * 的群聊，属系统默认无需创建，所以给它一个默认的固定id，以便跟普
 * 通群聊区分开来）. */
#define DEFAULT_GROUP_ID_FOR_BBS @"-1"
#define DEFAULT_GROUP_NAME_FOR_BBS @"世界频道"


@interface GroupEntity : NSObject

/** 群id */
@property (nonatomic, retain) NSString *g_id;
/** 群状态 */
@property (nonatomic, retain) NSString *g_status;
/** 群名字 */
@property (nonatomic, retain) NSString *g_name;
/** 群主uid */
@property (nonatomic, retain) NSString *g_owner_user_uid;
/** 群公告 */
@property (nonatomic, retain) NSString *g_notice;
/** 最大群员数 */
@property (nonatomic, retain) NSString *max_member_count;
/** 当前群员数 */
@property (nonatomic, retain) NSString *g_member_count;
/** 群创建时间 */
@property (nonatomic, retain) NSString *create_time;

/** 群主昵称 */
@property (nonatomic, retain) NSString *g_owner_name;      // 注：本字段非服务端“群基本信息/group_base”表中的字段
/** "我"在本群中的昵称（本字段只在针对”我“的群组信息查询时才有意义） */
@property (nonatomic, retain) NSString *nickname_ingroup;  // 注：本字段非服务端“群基本信息/group_base”表中的字段
/** ”我“是否在此群里（存在则返回1，不存在则返回0，返回-1表示不需要查询此值）*/
@property (nonatomic, retain) NSString *imIsInGroup;       // 注：本字段非服务端“群基本信息/group_base”表中的字段

/** 群公告更新时间 */
@property (nonatomic, retain) NSString *g_notice_updatetime;
/** 群公告更新者 */
@property (nonatomic, retain) NSString *g_notice_updateuid;
/** 群公告更新者昵称 */
@property (nonatomic, retain) NSString *g_notice_updatenick;// 注：本字段非服务端"群基本信息/group_base"表中的字段

/** 创建者昵称 */
@property (nonatomic, retain) NSString *create_user_name;

// ===== 新增群管理字段 =====

/** 禁言模式：0=正常，1=仅管理员和群主可发言，2=仅群主可发言 */
@property (nonatomic, assign) int g_mute_mode;
/** 自定义群头像URL（nil=使用系统生成的头像） */
@property (nonatomic, retain) NSString *g_custom_avatar;
/** 入群方式：0=自由加入，1=需管理员/群主审核 */
@property (nonatomic, assign) int g_join_mode;
/** 邀请权限：0=所有人可邀请，1=仅管理员和群主可邀请 */
@property (nonatomic, assign) int g_invite_permission;
/** 新成员可查看历史：0=不可查看（从入群时间起），1=可查看最近1000条消息 */
@property (nonatomic, assign) int g_new_member_history;
/** 成员隐私保护：0=关闭（所有人可见），1=仅管理员和群主可查看完整成员列表 */
@property (nonatomic, assign) int g_member_privacy;

/** 群模式：1=普通群（写扩散，离线消息走 1008-4-8），2=大群（读扩散，按 seq 拉取消息） */
@property (nonatomic, assign) int group_mode;
/** 大群最新消息 seq（仅 group_mode=2 时有效），由群列表/群详情接口返回 */
@property (nonatomic, assign) long long last_seq;


/**
 * 使用新的对象内容来更新旧对象，从而保证旧对象内容的更新但保持旧对象的存在。
 *
 * @param newGe 新的对象
 */
- (void)update:(GroupEntity *)newGe;

/**
 * ”我“是否在此群里.
 *
 * @return YES表示是，否则不是
 */
- (BOOL) myselfIsInGroup;

/**
 * 是否是“世界频道”（或者说是bbs聊天）。
 *
 * @return YES表示是世界频道，否则不是
 */
- (BOOL) isWorldChat;

/**
 * 指定id是否是“世界频道”（或者说是bbs聊天）。
 *
 * @param gid 群id
 * @return YES表示是世界频道，否则不是
 */
+ (BOOL) isWorldChat:(NSString *)gid;

/**
 * 是否为"大群"（读扩散模式）。
 * group_mode=2 时返回 YES。
 */
- (BOOL)isLargeGroup;

@end
