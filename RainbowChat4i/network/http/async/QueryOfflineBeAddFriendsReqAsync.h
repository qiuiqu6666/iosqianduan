//telegram @wz662
#import <Foundation/Foundation.h>

/**
 * 获取未读加好友请求数（包括好友发请求时我不在线的情况）（异步）.
 * <p>
 * 本类目前仅用于登陆成功后，首页上刷新离线的“加好友请求”未读数及列表中的Alarm的显示。
 *
 * @author Jack Jiang, 2017-12-26
 * @version 1.0
 */
@interface QueryOfflineBeAddFriendsReqAsync : NSObject

+ (void)doIt:(UIView *)hudParentView;

/// 与 `doIt:` 相同，HTTP 结束后在主线程调用 `completion`（失败或无数据也会调用）。
+ (void)doIt:(UIView *)hudParentView completion:(void (^ _Nullable)(void))completion;

@end
