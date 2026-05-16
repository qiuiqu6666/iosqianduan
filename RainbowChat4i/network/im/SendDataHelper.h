//telegram @wz662
/**
 * 整个RainbowChat的IM消息、指令数据发送辅助类。
 * 本类是对MobileIMSDK框架的 LocalUDPDataSender 类中实用方法的进一步封装，方便应用层使用。
 *
 * @author Jack Jiang
 * @since 4.3
 * @see net.openmob.mobileimsdk.android.core.LocalUDPDataSender
 */

#import <Foundation/Foundation.h>

@interface SendDataHelper : NSObject

/**
 * 发送消息给指定user_id的用户（根方法实现）.
 * <b>说明：</b>默认情况下如果需要QoS，将自动生成一个指纹码而无需传入参数哦.
 *
 * @param user_id 当user_id=0时表示发送给服务器，否则发送给指定用户
 * @param message 要发送的文本消息
 * @return 返回发送状态码，参见 ErrorCode.h 的定义
 */
+ (int)sendMessageImpl:(NSString *)user_id
           withMessage:(NSString *)message
                   qos:(BOOL)QoS
              andTypeu:(int)typeu;

/**
 * 发送消息给指定user_id的用户（根方法实现）.
 *
 * @param user_id 当user_id=0时表示发送给服务器，否则发送给指定用户
 * @param message 要发送的文本消息
 * @return 返回发送状态码，参见 ErrorCode.h 的定义
 */
+ (int)sendMessageImpl:(NSString *)user_id
           withMessage:(NSString *)message
                   qos:(BOOL)QoS
                finger:(NSString *)fingerPrint
              andTypeu:(int)typeu;

@end
