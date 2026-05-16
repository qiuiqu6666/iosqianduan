//telegram @wz662
/**
 * IM底层消息送达相关事件（由QoS机制通知上来的）在此MessageQoSEvent子类中实现即可。
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
#import "MessageQoSEvent.h"

@interface MessageQoSEventImpl : NSObject <MessageQoSEvent>

@end
