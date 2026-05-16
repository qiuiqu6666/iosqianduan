//telegram @wz662
#import "SendDataHelper.h"

@implementation SendDataHelper

+ (int)sendMessageImpl:(NSString *)user_id
           withMessage:(NSString *)message
                   qos:(BOOL)QoS
              andTypeu:(int)typeu
{
    return [SendDataHelper sendMessageImpl:user_id withMessage:message qos:QoS finger:QoS? [Protocal genFingerPrint]: nil andTypeu:typeu];
}

+ (int)sendMessageImpl:(NSString *)user_id
           withMessage:(NSString *)message
                   qos:(BOOL)QoS
                finger:(NSString *)fingerPrint
              andTypeu:(int)typeu
{
    int code = -1;

    if(message != nil && [message length] > 0)
    {
        // 发送消息
        code = [[LocalDataSender sharedInstance] sendCommonDataWithStr:message toUserId:user_id qos:QoS fp:fingerPrint withTypeu:typeu];
    }
    else
        NSLog(@"[MessageHelper] message为null或length<=0，请检查参数.");

    return code;
}

@end
