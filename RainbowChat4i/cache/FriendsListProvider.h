//telegram @wz662
#import <Foundation/Foundation.h>
#import "UserEntity.h"
#import "NSMutableArrayObservableEx.h"

/**
 * 好友列表数据提供者（即好友列表全局数据模型）.
 *
 * <p>
 * 本类的设计目标是实现好友列表界面与好友列表数据的解偶，从而使得界面的修改跟数据的管理
 * 完全分离，利于维护、重构、升级等。本类中只管实现对用户好友列表数据的各种管理，而无需
 * 理会任何UI的事（即使换套UI也无需改动本类任何代码，因为完全无耦合），而UI层只需设置好
 * 本类中数据变动的观察者即可实现数据跟UI的联动，就是这么简单。
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 * @version 1.0
 */

@interface FriendsListProvider : NSObject

/**
 * 加入一个新的好友信息对象.
 *
 * @param index
 * @param ree
 */
- (void)putFriend:(int)index withEntity:(UserEntity *)ree;

/**
 * @see #putFriend(int, RosterElementEntity)
 *
 * @param ree
 */
- (void)putFriend:(UserEntity *)ree;

/**
 * 移除列表中指定单元的元素.
 *
 * @param index
 * @param uid 本参数仅是为了方便从影子集合中移除对象，否则方法内就只能根据index再遍历集合取到uid了，这样就损失性能了！
 * @return
 */
- (BOOL)remove:(int)index uid:(NSString *)uid;

/**
 * 移除列表中指定单元的元素.
 *
 * @param index
 * @param uid 本参数仅是为了方便从影子集合中移除对象，否则方法内就只能根据index再遍历集合取到uid了，这样就损失性能了！
 * @param notifyObserver
 */
- (BOOL)remove:(int)index uid:(NSString *)uid notify:(BOOL)notifyObserver;

/**
 * 返回好友列表数据集合.
 *
 * @return
 */
- (NSMutableArrayObservableEx *)getFriendsData;

/**
 * @deprecated 本方法将于v4.3及以后版本中过时，请使用：{@link #getFriendInfoByUid2:}
 * 根据好友在业务系统中定义的UID找到它在好友列表中暂存的详细信息（通过遍历数组实现）.
 *
 * @param uid
 * @return 如果存在则返回指定好友的信息封装对象，否则返回null
 */
- (UserEntity *)getFriendInfoByUid:(NSString *)uid;

/**
 * 根据好友在业务系统中定义的UID找到它在好友列表中暂存的详细信息（通过高性能hash实现）.
 *
 * <b>注意：</b>
 * 本方法为v4.3中新增，对于{@link #rosterDataHash}集合的实际性能、稳定性、逻辑等还需经历时间考验
 * ，因而本方法建议暂时慎用，但日后将用于替代原 {@link #getFriendInfoByUid:}，以便在大量好友时提升性能。
 *
 * @param uid
 * @return
 */
- (UserEntity *)getFriendInfoByUid2:(NSString *)uid;

/**
 * @deprecated 本方法将于v4.3及以后版本中过时，请使用：{@link #getFriendInfoByUid2:}
 * 根据好友在聊天系统中定义的user_id找到它在好友列表中暂存的详细信息（通过遍历数组实现）.
 *
 * @param user_id
 * @return 如果存在则返回指定好友的信息封装对象，否则返回nil
 */
- (UserEntity *)getFriendInfoByUserId:(NSString *)user_id;

/**
 * @deprecated 本方法将于v4.3及以后版本中过时，请使用：{@link #isUserInRoster2:}
 * 指定uid用户是否在好友列表中（通过遍历数组实现）.
 *
 * @param uid
 */
- (BOOL)isUserInRoster:(NSString *)uid;

/**
 * 指定uid用户是否在好友列表中（通过高性能hash实现）.
 *
 * <b>注意：</b>
 * 本方法为v4.3中新增，对于{@link #rosterDataHash}集合的实际性能、稳定性、逻辑等还需经历时间考验
 * ，因而本方法建议暂时慎用，但日后将用于替代原 {@link #isUserInRoster:}，以便在大量好友时提升性能。
 *
 * @param uid
 * @return
 * @since 4.3
 */
- (BOOL)isUserInRoster2:(NSString *)uid;

/**
 * 返回指定用户所在好友列中的索引位置.
 *
 * @param uid
 * @return
 */
- (int)getIndex:(NSString *)uid;

/**
 * 返回指定用户所在好友列中的索引位置.
 *
 * @param r
 * @return
 */
- (int)getIndexWithObj:(UserEntity *)r;

/**
 * 当前在线的好友数。
 */
- (int)onlineCount;

- (NSInteger)size;

/**
 * 设置所有好友离线.
 * <p>
 * 此方法的应用场景目前是在网络掉线（准确地说是与服务端断开连接）时，
 * 目的是模仿QQ在掉线时的体验，在本APP中好久是设置离线后，本地用户就不可以发出消息了，
 * 否则在目前UDP的聊天框架下，这样也可以作为告之本地用户掉线的一种间接方式，否则怎么好
 * 提示他本地掉线了呢？不过，本方法的作用也仅限于配合UI的提示而已。
 */
- (void)offlineAll;

/**
 * 刷新好友列表.
 *
 * @param refreshComplete 刷新结果回调，不需要则可设为nil
 * @return true表示刷新成功，否则表示不成功
 */
- (void)refreshFriendsDataAsync:(void (^)(BOOL sucess))refreshComplete;


//- (int)getUnreadNum:(NSString *)visitorUid;
//
///**
// 获取列表中所有未读数之和。
//
// @return 未读数之和
// */
//- (int)getTotalUnreadNum;
//
//- (void)accumulateUnreadNum:(NSString *)visitorUid withNumToAdd:(int)numToAdd;
//
//- (RosterElementEntity *)resetUnreadNum:(NSString *)visitorUid;

@end
