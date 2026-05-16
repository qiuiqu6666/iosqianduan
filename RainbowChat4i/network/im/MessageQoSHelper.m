//telegram @wz662
#import "MessageQoSHelper.h"
#import "Protocal.h"
#import "ProtocalType.h"
#import "IMClientManager.h"
#import "MessagesProvider.h"
#import "SendRetryManager.h"

static NSString *TAG = @"MessageQoSHelper";

@implementation MessageQoSHelper

//---------------------------------------------------------------------------------- 处理丢包相关方法 START
// 处理发送失败的消息
+ (void)processMessagesLost:(BOOL)forSingleChat tag:(NSString *)logTag lms:(NSMutableArray*)lostMessages
{
    MessagesProvider *mp;
    if(forSingleChat) {
        mp = [[IMClientManager sharedInstance] getMessagesProvider];
    } else {
        mp = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
    }
    
    // 遍历丢包列表
    for(int i = [lostMessages count] - 1; i >= 0; i--) // 注意：匹配的同时又要删除集后的话，通常是从列表尾遍历，否则会产生bug哦！
    {
        Protocal *lostP = (Protocal *)lostMessages[i];
        if(lostP != nil)
        {
            // 找到该应答包对应的目标消息了吗？
            BOOL beMatched = NO;

            // ** 通用数据（除聊天框架的保留指令外的所有消都都属通用数据）
            if(lostP.type == FROM_CLIENT_TYPE_OF_COMMON_DATA)
            {
                NSUInteger noReceviedCnt = [[mp getAllFriendsMessagesGhostForNoReceived] count];
                DDLogDebug(@"%@【QoS】[%@]====当前待决消息ghost列表中共有%lu条未决的消息=====", TAG, logTag, (unsigned long)noReceviedCnt);

                // 2013-12-18日新启用的此算法（直接从待决列表中匹配；单聊/群聊均用当前选中的 mp）
                JSQMessage *cme = [[mp getAllFriendsMessagesGhostForNoReceived] objectForKey:lostP.fp];

                if(cme != nil)
                {
                    // 找到了
                    beMatched = YES;
                    // 本次匹配结束
                    DDLogDebug(@"%@【QoS】[%@]指纹是%@的丢包在待决消息ghost列表里，本次成功匹配到丢包目标哦.", TAG, logTag, lostP.fp);
                }
                else
                    DDLogDebug(@"%@【QoS】[%@]指纹是%@的丢包不在AllFriendsMessagesGhostForNoReceived的消息记录里.", TAG, logTag, lostP.fp);
            }
            else
                DDLogDebug(@"%@【QoS】[%@]目前不能支持协议类型=%d的丢包处理哦~！！", TAG, logTag, lostP.type);

            if(beMatched)
            {
                // 移除丢包列表中已匹配的（已处理完成的）
                [lostMessages removeObjectAtIndex:i];// 注意：匹配的同时又要删除集后的话，通常是从列表尾遍历，否则会产生bug哦！

                // 移除待决列表中的包（单聊/群聊均用当前选中的 mp）
                [mp sendToFriendFaild:lostP.fp];
            }
        }
    }

//	return beMatched;
}

//// BBS公聊消息或普通群聊消息的丢包处理.
//+ (void) processMessagesLost_forGroupChat:(NSMutableArray*)lostMessages
//{
//    // 是否需要更新ui
//    BOOL needUpdateUI = NO;
//
//    MessagesProvider *mp = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
//
//    // 非null检查
//    if(mp == nil)
//        return;
//
//    // 遍历丢包列表
//    for(int i = [lostMessages count] - 1; i >= 0; i--)// 注意：匹配的同时又要删除集后的话，通常是从列表尾遍历，否则会产生bug哦！
//    {
//        Protocal *lostP = (Protocal *)lostMessages[i];
//        if(lostP != nil)
//        {
//            // 找到该应答包对应的目标消息了吗？
//            BOOL beMatched = NO;
//
//            // ** 通用数据（除聊天框架的保留指令外的所有消都都属通用数据）
//            if(lostP.type == FROM_CLIENT_TYPE_OF_COMMON_DATA)
//            {
//                NSUInteger noReceviedCnt = [[mp getAllFriendsMessagesGhostForNoReceived] count];
//                DDLogDebug(@"%@【QoS】[BBS/群聊]====当前待决消息ghost列表中共有%lu条未决的消息=====", TAG, (unsigned long)noReceviedCnt);
//
//                // 2013-12-18日新启用的此算法（直接从待决列表中匹配，而非遍历所有好友的所有消息，则计算效率要高很多罗!）
//                JSQMessage *cme = [[mp getAllFriendsMessagesGhostForNoReceived] objectForKey:lostP.fp];
//
//                if(cme != nil)
//                {
//                    // 找到了
//                    beMatched = YES;
//                    // 更新UI标识对方已收到消息了！！
//                    cme.sendStatus = SendStatus_SEND_FAILD;
//
//                    // 需要更新Ui
//                    needUpdateUI = YES;
//
//                    // 本次匹配结束
//                    DDLogDebug(@"%@【QoS】[BBS/群聊]指纹是%@的丢包在待决消息ghost列表里，本次成功匹配到丢包目标哦.", TAG, lostP.fp);
//                }
//                else
//                    DDLogDebug(@"%@【QoS】[BBS/群聊][正式聊天]指纹是%@的丢包不在AllFriendsMessagesGhostForNoReceived的消息记录里.", TAG, lostP.fp);
//            }
//            else
//                DDLogDebug(@"%@【QoS】[BBS/群聊]目前不能支持协议类型=%d的丢包处理哦~！！", TAG, lostP.type);
//
//            if(beMatched)
//            {
//                // 移除丢包列表中已匹配的（已处理完成的）
//                [lostMessages removeObjectAtIndex:i]; // 注意：匹配的同时又要删除集后的话，通常是从列表尾遍历，否则会产生bug哦！
//
//                // 移除待决列表中的包
//                [mp sendToFriendFaild:lostP.fp];
//            }
//        }
//    }
//
//    // 本批丢包消息处理完成了，但要及时通知UI更新哦
//    if(needUpdateUI)
//    {
////      // 本批丢包消息处理完成了，但要及时通知UI更新哦
////      if(lostMessages.size() > 0)
//        {
//            // 遍历所有好友的消息
//            // 因为目前为了提丢包消息匹配的效率，所以不用对所有好友消息进行遍历，而
//            // 只需要像上面代码一样只要针对未决包列表进行匹配即可，而这样就无法找到丢包的消息对
//            // 应的是谁的消息，那么也就没办法精确通知它的Ui观察者了。不过干脆就这样尝试通知所有
//            // 消息所有者的观察者吧，性能也没有多大损失，但UI更新的目的也达到了！
//            [mp notifyAllObserver];
//        }
//    }
//
////  return beMatched;
//}
//---------------------------------------------------------------------------------- 处理丢包相关方法 END


//---------------------------------------------------------------------------------- 处理应答包相关方法 START
// 收到正式聊天消息的应答包时的处理
+ (BOOL)processMessagesBeReceived:(BOOL)forSingleChat tag:(NSString *)logTag fp:(NSString *)theFingerPrint
{
    MessagesProvider *mp;
    if(forSingleChat) {
        mp = [[IMClientManager sharedInstance] getMessagesProvider];
    } else {
        mp = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
    }
    if (mp == nil || theFingerPrint.length == 0) {
        return NO;
    }

    // 统一走 mark：ghost 未命中时仍可按 fp 扫会话内存（仅 IM QoS、无 ghost 时不再一直转圈）；并在主线程由调用方保证
    BOOL beMatched = [mp markOutgoingMessageDeliveredForFp:theFingerPrint preferredPeerUid:nil];
    if (beMatched) {
        DDLogDebug(@"%@【QoS】[%@]指纹是%@的应答包已处理为已送达（ghost 或列表匹配）.", TAG, logTag, theFingerPrint);
    } else {
        DDLogDebug(@"%@【QoS】[%@]指纹是%@的应答包未找到对应发出消息.", TAG, logTag, theFingerPrint);
    }
    return beMatched;
}

//// 收到BBS聊天消息或普通群聊消息的应答包时的处理.
//+ (BOOL)processMessagesBeReceived_forGroupChat:(NSString *)theFingerPrint
//{
//    // 找到该应答包对应的目标消息了吗？
//    BOOL beMatched = NO;
//
//    MessagesProvider *mp = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
//
//    // 非null检查
//    if(mp == nil)
//        return beMatched;
//
//    // 2013-12-18日新启用的此算法（直接从待决列表中匹配，而非遍历所有好友的所有消息，则计算效率要高很多罗!）
//    JSQMessage *cme = [[mp getAllFriendsMessagesGhostForNoReceived] objectForKey:theFingerPrint];
//    if(cme != nil)
//    {
//        // 找到了
//        beMatched = YES;
//        // 更新UI标识对方已收到消息了！！
//        cme.sendStatus = SendStatus_BE_RECEIVED;
//        // 遍历所有好友的消息
//        // 因为目前为了提丢包消息匹配的效率，所以不用对所有好友消息进行遍历，而
//        // 只需要像上面代码一样只要针对未决包列表进行匹配即可，而这样就无法找到丢包的消息对
//        // 应的是谁的消息，那么也就没办法精确通知它的Ui观察者了。不过干脆就这样尝试通知所有
//        // 消息所有者的观察者吧，性能也没有多大损失，但UI更新的目的也达到了！
//        [mp notifyAllObserver];
//
//        // 本次匹配结束
//        DDLogDebug(@"%@【QoS】[BBS/群聊]指纹是%@的应答包在待决聊天消息ghost列表里，本次成功匹配到应答包目标哦.", TAG, theFingerPrint);
//    }
//    else
//        DDLogDebug(@"%@【QoS】[BBS/群聊]指纹是%@的应答包不在待决聊天消息ghost列表里.", TAG, theFingerPrint);
//
//    if(beMatched)
//        // 移除待决列表中的包，收到消息了就把它从待决列表中去掉哦
//        [mp friendReceivedMessage:theFingerPrint];
//
//    return beMatched;
//}
//---------------------------------------------------------------------------------- 处理应答包相关方法 END

@end
