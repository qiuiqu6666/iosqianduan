//telegram @wz662
/**
 * 与IM服务器的底层数据交互事件在此ChatTransDataEvent子类中实现即可。
 * <p>
 *     本类是MobileIMSDK的通用数据通信消息的回调事件接口实现类（接收的事件
 *     如：收到聊天数据事件 通知、服务端返回的错误信息事件通知等）。
 * </p>
 * <p>
 *     RainbowChat的IM通信底层是基于MobileIMSDK即时通讯框架实现，
 *     如需了解RainbowChat的通信层原理，详情请前往了解MobileIMSDK框架，
 *     地址是：http://www.52im.net/thread-52-1-1.html
 * </p>
 *
 * @author Jack Jiang
 * @since 1.0
 */

#import <Foundation/Foundation.h>
#import "ChatMessageEvent.h"
#import "UserEntity.h"

@interface ChatMessageEventImpl : NSObject <ChatMessageEvent>

///**
// * 处理收到的聊天文本消息.
// *
// * @param ree
// * @param jsonStrOfTextMessage
// * @param playPromtAudio
// * @param showNotification
// */
//+ (void)addChatMessageData:(NSString *)msg withTime:(NSString *)time playAudio:(BOOL)playPromtAudio showNotify:(BOOL)showNotification msgType:(int)msgType withRee:(RosterElementEntity *)ree;

- (ObserverCompletion)getAddMessagesObserver;

- (void)setAddMessagesObserver:(ObserverCompletion)addMessagesObserver;

// 显示一条提示消息，此提示用于不支持的消息或指令类型时（比如ios版尚不支持但android版已经实现了的消息或指令时），为了提升用户体验而加的提示消息文字
+ (void)addUnsupportFriendCmdHint:fingerPrintOfProtocal uid:(NSString *)friendUid hint:(NSString *)hint;

+ (BOOL)shouldInsertAddFriendSuccessHintForFriend:(NSString *)friendUid;

@end
