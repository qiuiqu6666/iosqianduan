//telegram @wz662
/**
 * 一对一好友实时语音聊天相关消息/指令的发送和解析方法。
 */

#import <Foundation/Foundation.h>

@interface RealTimeVoiceMessageHelper : NSObject

/**
 * 解析实时语音聊天呼叫中：请求实时语音聊天(发起方A) .
 *
 * @param originalMsg 包含指点协议头和内容本身的原始消息文本
 * @return 对方的用户uid
 */
+ (NSString *)pareseRealTimeVoiceRequest_Requestting_from_a:(NSString *)originalMsg;

@end
