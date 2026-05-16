//telegram @wz662
#import "MessageQoSEventImpl.h"
#import "MessageQoSHelper.h"
#import "JSQMessages.h"
#import "IMClientManager.h"

@implementation MessageQoSEventImpl

/**
 * MobileIMSDK框架的消息未送达的回调事件通知.
 * <p>
 * 发生场景：比如用户刚发完消息但网络已经断掉了的情况下，表现形式：就像手机qq或微信一样
 * 消息气泡边上会出现红色图标以示没有发送成功）.
 * </p>
 *
 * @param lostMessages 由MobileIMSDK QoS算法判定出来的未送达消息列表（此列表
 * 中的Protocal对象是原对象的clone（即原对象的深拷贝），请放心使用哦），应用层
 * 可通过指纹特征码找到原消息并可以UI上将其标记为”发送失败“以便即时告之用户
 */
- (void) messagesLost:(NSMutableArray*)lostMessages
{
    DDLogDebug(@"【QoS丢包通知】收到系统的未实时送达消息通知，当前共有%li个包QoS保证机制结束，判定为【无法实时送达】！", (unsigned long)[lostMessages count]);

    // 播一个声音提示
    [JSQSystemSoundPlayer jsq_playMessageSentSound];

    if(lostMessages != nil)
    {
        // 【关于处理丢包消息的逻辑说明】逻辑是按各种消息依次进行丢包列表减量处理（即该丢的包在前1种方法里
        // 匹配后会从丢包列表中移除，下1次丢包处理方法就不需要处理这个丢包了，因为已经处理过了）
        // ** 【第1种】：尝试作为普通聊天消息或临时聊天消息来处理哦
        if([lostMessages count] > 0)
            [MessageQoSHelper processMessagesLost:YES tag:@"单聊" lms:lostMessages];

        // ** 【第2种】：尝试作为BBS公聊消息或普通群聊消息来处理哦
        if([lostMessages count] > 0) // 前1种方法处理完成后，丢包列表还不是空的，则意味着还需要进入下一种方法中进一步处理哦
            [MessageQoSHelper processMessagesLost:NO tag:@"BBS/群聊" lms:lostMessages];
        
        // ** 【第3种】：尝试作为"消息"撤回指令的应答来处理哦
        // TODO: 此种情况以后处理，后果是会导致MessageRevokingManager中的集合增长，但指令未实时通送这种情况不常见（何况是撤回这种非常态功能）
        // TODO: ，日后要被充处理的话：先在此处实现与MessageRevokingManager中的匹配逻辑（匹配上后就从集合中删除），然后匹配上后发出广播（通知聊天界面按fp取消进度提示的显示）
    }
}

/**
 * MobileIMSDK框架的消息已被对方收到的回调事件通知.
 * <p>
 * <b>目前，判定消息被对方收到是有两种可能：</b><br>
 * 1) 对方确实是在线并且实时收到了；<br>
 * 2) 对方不在线或者服务端转发过程中出错了，由服务端进行离线存储成功后的反馈
 * （此种情况严格来讲不能算是“已被收到”，但对于应用层来说，离线存储了的消息
 * 原则上就是已送达了的消息：因为用户下次登陆时肯定能通过HTTP协议取到）。
 *
 * @param theFingerPrint 已被收到的消息的指纹特征码（唯一ID），应用层可据此ID
 * 来找到原先已发生的消息并可在UI是将其标记为”已送达“或”已读“以便提升用户体验
 */
- (void) messagesBeReceived:(NSString *)theFingerPrint
{
    if(theFingerPrint == nil) {
        return;
    }
    NSString *fpCopy = [theFingerPrint copy];
    void (^work)(void) = ^{
        DDLogDebug(@"【QoS应答通知】收到对方已收到消息事件的通知，fp=%@", fpCopy);

        BOOL beMatched = [MessageQoSHelper processMessagesBeReceived:YES tag:@"单聊" fp:fpCopy];

        if(!beMatched)
            beMatched = [MessageQoSHelper processMessagesBeReceived:NO tag:@"BBS/群聊" fp:fpCopy];

        if(!beMatched)
            beMatched = [[[IMClientManager sharedInstance] getMessageRevokingManager] revokeCmdBeRecieved:fpCopy];

        if(!beMatched)
            DDLogDebug(@"【QoS】指纹是%@的应答包没有找到匹配目标，意味着目前应用层不用理会此类应答包，忽略之...", fpCopy);
    };
    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_async(dispatch_get_main_queue(), work);
    }
}

@end
