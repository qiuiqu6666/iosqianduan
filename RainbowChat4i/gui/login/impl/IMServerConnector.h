//telegram @wz662
/**
 * 连接IM服务器的封装类。
 * 本类中封装了连接IM服务器的完整逻辑，简化开发者的理解。
 */
#import <Foundation/Foundation.h>

@interface IMServerConnector : NSObject<UIAlertViewDelegate>

- (id)initWith:(UIViewController *)parentViewController;

/**
 * IM服务器连接的相关配置初始化代码，在真正连接IM之前，本方法必须首先被调用。
 */
- (void)initConnectToIMServer;

/**
 * 本方法是本IM中唯一正确的连接到IM服务器的途径。
 *
 * @param loginUserId 用于连接IM服务器时作为唯一用户id使用
 * @param loginToken 用于连接IM服务器时作为身份验证之用（此token通常由先前的SSO单点登陆接口返回并定义接下来的验证策略）
 */
- (void)doLoginIMServer:(NSString *)loginUserId andToken:(NSString *)loginToken;

/**
 * 设置登陆socket长连接服务端结束时要通知的观察者（无论是登陆成功、失败还是出错等，反正本次登陆有结果了都会通知） 。
 *
 * @param onLoginEndObserver 观察者
 */
- (void)setOnLoginEndObserver:(ObserverCompletion)onLoginEndObserver;

///**
// 进入一对一聊天界面。
// */
//- (void)gotoChatViewController;

@end
