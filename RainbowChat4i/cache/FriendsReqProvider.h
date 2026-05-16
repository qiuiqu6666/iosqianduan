//telegram @wz662
//
//  FriendsReqProvider.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/8/18.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 * 加好友请求的数据全局缓存提供者实现类.
 * <p>
 * <b>补充说明：</b>目前为了保持未处理好友请求数据的最新和多端同步，以及减少缓存导致的数据不一致问题，好友请求数
 * 据没有采用本地全局缓存方式，需要最新的好友请求数据时应通过http接口实时全量拉取。当前本缓存类中，暂时只缓存了自
 * app启动以来的未处理好友请求总数。日后，如需实现绝对的离线能力，可考虑将http接口拉取的请求数据全量缓存至本地（
 * sqlite和内存），当前暂时不用考虑。
 *
 * @author JackJiang
 * @since 5.0
 */

#import <Foundation/Foundation.h>
#import "Observers.h"

@interface FriendsReqProvider : NSObject

/**
 * 当前未读好友请求总数。
 *
 * @return 未读好友请求总数
 */
- (int)getUnreadCount;

/**
 * 设置好友请求数为请值。
 *
 * @param newValue 新值
 * @param notify   是否需要通知观察者
 */
- (void)setUnreadCount:(int)newValue needNotify:(BOOL)notify;

/**
 * 清除未读好友请求总数（就是设置为0）。
 *
 * @param notify 是否需要通知观察者
 */
- (void)clearUnreadCount:(BOOL)notify;

/**
 * 累加未读好友请求数.
 *
 * @param delta  the value to add
 * @param notify 是否需要通知观察者
 * @return the updated value
 */
- (int)addUnreadCount:(int)delta needNotify:(BOOL)notify;

/**
 * 未读好友请求数+1.
 *
 * @param notify 是否需要通知观察者
 * @return the updated value
 */
- (int)incrementUnreadCount:(BOOL)notify;

/**
 * 添加好友请求未读数变动观察者。
 *
 * @param o 观察者对象
 */
- (void)addUnreadChangedObserver:(ObserverCompletion)o;

/**
 * 移除好友请求未读数变动观察者。
 *
 * @param o 将要被移除的观察者对象
 */
- (void)removeUnreadChangedObserver:(ObserverCompletion)o;

@end
