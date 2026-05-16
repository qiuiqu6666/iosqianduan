//telegram @wz662
/**
 * 本类的中的方法全面参考自一对一好友聊天的ChatHelper.
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 * @version 1.0
 * @since 4.3
 * @see ChatDataHelper
 */

#import <Foundation/Foundation.h>
#import "JSQMessage.h"
#import "MsgBody4Guest.h"

@interface TChatDataHelper : NSObject

/**
 * 添加一条临时聊天消息到临时聊天数据结构中.
 */
+ (void) addChatMessageData_incoming:(NSString *)fingerPrint
                             msgBody:(MsgBody4Guest *)tcmd
                                date:(NSDate *)time
                          showNotify:(BOOL)showNotification
                           playAudio:(BOOL)playPromtAudio
                            andQuote:(QuoteMeta *)quoteMeta;

//+ (void)addMsgItemToChat_TO_TEXT:(NSString *)friendUid withContent:(NSString *)message andFinger:(NSString *)fingerPring;
//+ (JSQMessage *)addMsgItemToChat_TO_IMAGE:(NSString *)friendUid withContent:(NSString *)imageFileName andFinger:(NSString *)fingerPring;
//+ (JSQMessage *)addMsgItemToChat_TO_VOICE:(NSString *)friendUid withContent:(NSString *)message andFinger:(NSString *)fingerPring;
//+ (JSQMessage *)addMsgItemToChat_TO_FILE:(NSString *)friendUid withContent:(FileMeta *)fileMeta andFinger:(NSString *)fingerPring;
//+ (JSQMessage *)addMsgItemToChat_TO_SHORTVIDEO:(NSString *)friendUid withContent:(FileMeta *)fileMeta andFinger:(NSString *)fingerPring;

+ (JSQMessage *)addChatMessageData_outgoing:(NSString *)friendUid withData:(JSQMessage *)entity;

@end
