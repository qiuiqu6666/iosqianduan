//telegram @wz662
/**
 * 与IM服务器的底层连接事件在此ChatBaseEvent子类中实现即可。
 * <p>
 *     本类是MobileIMSDK的基础通信消息的回调事件接口实现类（将接收如：登陆成功事件 通知、掉线事件通知等）。
 * </p>
 * <p>
 *     RaincowChat的IM通信底层是基于MobileIMSDK即时通讯框架实现，
 *     如需了解RainbowChat的通信层原理，详情请前往了解MobileIMSDK框架，
 *     地址是：http://www.52im.net/thread-52-1-1.html
 * </p>
 *
 * @author Jack Jiang
 * @since 1.0
 */

#import <Foundation/Foundation.h>
#import "ChatBaseEvent.h"
#import "CompletionDefine.h"

@interface ChatBaseEventImpl : NSObject <ChatBaseEvent>

/** 本Observer目前仅用于登陆时（因为登陆与收到服务端的登陆验证结果是异步的，所以有此观察者来完成收到验证后的处理）*/
@property (nonatomic, copy) ObserverCompletion loginOkForLaunchObserver;// block代码块一定要用copy属性，否则报错！

/**
 * 与IM服务器的网络连接状态观察者.
 *
 * @see [ClientCoreSDK isConnectedToServer]
 */
@property (nonatomic, copy) ObserverCompletion networkStatusObserver;// block代码块一定要用copy属性，否则报错！

@end
