//telegram @wz662
/**
 * 通过HTTP拉取服务端存放的离线消息（异步）.
 * 本类的作用与Android版的同名类用途一样！
 *
 * @author Jack Jiang, 2017-11-17
 * @version 1.0
 */

#import <Foundation/Foundation.h>

@class UIView;

@interface QueryOfflineChatMsgAsync : NSObject

+ (void)doIt:(NSString *)fromUserUid hudParentView:(UIView *)view;

/**
 * 拉取离线消息（带完成回调）。
 *
 * @param fromUserUid 指定用户UID（传nil表示拉取所有离线消息）
 * @param view        HUD父视图
 * @param completion  完成回调（在HTTP回调线程中触发）
 */
+ (void)doIt:(NSString *)fromUserUid hudParentView:(UIView *)view completion:(void (^)(void))completion;

/// 单机无漫游：1008-4-8 循环拉取直至服务端返回空批（每批最多 500 条，拉后服务端删除本批）。
+ (void)drainAllOfflineChatBatchesForHudParentView:(nullable UIView *)view completion:(void (^ _Nullable)(void))completion;

@end
