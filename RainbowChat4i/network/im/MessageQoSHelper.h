//telegram @wz662
#import <Foundation/Foundation.h>

@interface MessageQoSHelper : NSObject

/**
 * 处理发送失败的消息.
 *
 * @param lostMessages
 * @return
 */
+ (void)processMessagesLost:(BOOL)forSingleChat tag:(NSString *)logTag lms:(NSMutableArray*)lostMessages;

///**
// * BBS公聊消息或普通群聊消息的丢包处理.
// * <p>
// * <b>重要说明：</b>本方法完全copy自 {@link #processMessagesLost_forLoverChat(Context, ArrayList)}，请注意同步！
// *
// * @param lostMessages
// * @return
// */
//+ (void) processMessagesLost_forGroupChat:(NSMutableArray*)lostMessages;

/**
 * 收到正式聊天消息的应答包时的处理.
 *
 * @param theFingerPrint
 * @return
 */
+ (BOOL)processMessagesBeReceived:(BOOL)forSingleChat tag:(NSString *)logTag fp:(NSString *)theFingerPrint;

///**
// * 收到BBS聊天消息或普通群聊消息的应答包时的处理.
// * <p>
// * <b>重要说明：</b>本方法完全copy自 {@link #processMessagesBeReceived_forLoverChat(Context, String)}，请注意同步！
// *
// * @param theFingerPrint
// * @return
// * @see #processMessagesBeReceived_forLoverChat(Context, String)
// */
//+ (BOOL)processMessagesBeReceived_forGroupChat:(NSString *)theFingerPrint;

@end
