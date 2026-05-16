//telegram @wz662
/**
 * "我"的群组列表数据提供者（即我的群组列表全局数据模型）.
 *
 * <p>
 * 本类的设计目标是实现群组列表界面与群组列表数据的解偶，从而使得界面的修改跟数据的管理
 * 完全分离，利于维护、重构、升级等。本类中只管实现对用户群组列表数据的各种管理，而GroupsList无需
 * 理会任何UI的事（即使换套UI也无需改动本类任何代码，因为完全无耦合），而UI层只需设置好
 * 本类中数据变动的观察者即可实现数据跟UI的联动，就是这么简单。
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 * @since 4.3
 */

#import <Foundation/Foundation.h>
#import "NSMutableArrayObservableEx.h"
#import "GroupEntity.h"

@interface GroupsProvider : NSObject

/**
 * 更新指定群组的信息（如果老的群信息不存在则本方法什么也不做）。
 *
 * @param newGe
 */
- (void)updateGroup:(GroupEntity *)newGe;

/**
 * 加入一个新的群组信息对象.
 *
 * @param index
 * @param ree
 */
- (void)putGroup:(int)index withEntity:(GroupEntity *)ree;

/**
 * @see #putGroup(int, GroupEntity)
 *
 * @param ree
 */
- (void)putGroup:(GroupEntity *)ree;

/**
 * 用新的群组列表数据集合覆盖原有的数据。
 *
 * @param newDatas 数据集合
 */
- (void)putGroups:(NSArray<GroupEntity *> *)newDatas;

- (BOOL) remove:(int)index;

/**
 * 移除列表中指定单元的元素.
 *
 * @param index
 * @param notifyObserver
 */
- (BOOL) remove:(int)index notify:(BOOL)notifyObserver;

- (BOOL) remove2:(NSString *)gid;

- (BOOL) remove2:(NSString *)gid notify:(BOOL)notifyObserver;

/**
 * 指定gid群组是否在群组列表中.
 *
 * @param gid
 */
- (BOOL) isUserInGroupList:(NSString *)gid;

/**
 * 返回"我"群组列表数据集合.
 * <p>
 * <b>注意：</b>如果群组列表为null则本方法将尝试先去服务端读取，然后再返回.
 *
 * @param activity
 * @return
 */
- (NSMutableArrayObservableEx *)getGroupsListData;

/**
 * 根据gid找到群组列表数据模型中的群组基本信息数据。
 *
 * @param gid
 * @return 如果存在则返回指定好友的信息封装对象，否则返回null
 */
- (GroupEntity *) getGroupInfoByGid:(NSString *)gid;

/**
 * 返回指定群组在列中的索引位置.
 *
 * @param gid 要查找的群id
 * @return 返回指定群所在的行索引值，如果没有找到该群组则返回-1
 */
- (int) getIndex:(NSString *)gid;

/**
 * 返回指定群组在列表中的索引位置.
 *
 * @param r
 * @return
 */
- (int) getIndexWithObj:(GroupEntity *)r;

/**
 * 检查索引值是否合法（有无超过数据合法索引）。
 *
 * @param index 数据所在数组的索引位置
 * @return YES表示此索引值没有越界，否则已越界或不合法
 */
- (BOOL) checkIndexValid:(int)index;

- (NSInteger) size;

/**
 * 世界频道（即原BBS）本来是没有GroupEntity信息的，但为了兼容真正的群聊数据
 * ，本方法将返回默认的世界频道（即原BBS）的GroupEntity对象。暂无大用途，保
 * 持接口兼容而已。
 *
 * @return
 */
+ (GroupEntity *)getDefaultWordChatEntity;

/**
 * 本地用户是否是指定群的群主。
 *
 * @param gid 群id
 * @return YES表示是，否则不是
 */
+ (BOOL) isThisGroupOwner:(NSString *)gid;

/**
 * 本地用户是否群主。
 *
 * @param ownerUid 群主的uid
 * @return YES表示是，否则不是
 */
+ (BOOL) isGroupOwner:(NSString *)ownerUid;

/**
 * 返回本地用户"我"在指定gid群内的昵称。
 *
 * @param gid 群id
 * @return 如果正确取到昵称则返回之，否则返回null
 * @since 9.0
 */
+ (NSString *) getMyNickNameInGroupEx:(NSString *)gid;

/**
 * 返回"我"在群内的昵称(如果参数不为空，就直接返回，否则返回"我"的默认昵称作为群内昵称)。
 *
 * @param nickname_ingroup
 * @return
 */
+ (NSString *) getMyNickNameInGroup:(NSString *)nickname_ingroup;

/**
 * 返回群内昵称（如果群内昵称为空，则返回默认昵称，否则返回群内昵称）。
 *
 * @param nickName
 * @param nickname_ingroup
 * @return
 */
+ (NSString *) getNickNameInGroup:(NSString *)nickName and:(NSString *)nickname_ingroup;

- (void)refreshGroupsList:(void (^)(BOOL sucess))refreshComplete;


// ========== 大群（读扩散）本地 seq 管理 ==========

/**
 * 读取指定大群在本地缓存的最大 seq（用于增量拉取消息）。
 *
 * @param gid 群 ID
 * @return 本地已展示的最大 seq，如果没有缓存则返回 0
 */
+ (long long)getLastSeqForGroup:(NSString *)gid;

/**
 * 保存指定大群在本地的最大 seq。
 *
 * @param seq 最新的 seq 值
 * @param gid 群 ID
 */
+ (void)saveLastSeq:(long long)seq forGroup:(NSString *)gid;

/// 1016-25-25 单行 → 与漫游/SyncKey 一致的键（聊天页拉取与登录增量共用）
+ (NSDictionary *)rb_normalizedDictFromLargeGroupFetchRow:(NSDictionary *)raw gid:(NSString *)gid;

/// 大群归一化字典 → JSQMessage（不依赖当前 Chat VC，供登录同步与 HTTP 拉取共用）
+ (nullable JSQMessage *)rb_jsqMessageFromLargeGroupNormalizedDict:(NSDictionary *)norm localUid:(NSString *)localUid;

/// 从指纹 `lg_<gid>_<seq>` 解析 seq（与 rb_jsqMessageFromLargeGroupNormalizedDict 一致）；gid 段允许与当前 gid 数值相等即可（前导零等）；不匹配返回 -1
+ (long long)rb_largeGroupSeqFromFingerPrint:(NSString *)fp gid:(NSString *)gid;

@end
