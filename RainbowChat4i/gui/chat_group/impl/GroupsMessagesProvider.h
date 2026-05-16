//telegram @wz662
/**
 * 世界频道（BBS）聊天时的数据模型.
 * <p>
 * 世界频道相当于传统的网络聊天室，在产品运营时用于提供陌生人的交流动力，
 * 不然只要加好友才能聊天，那从哪个渠道加呢？所以说，世界频道是基于产品运营
 * 而增加的功能而已，并非传统IM的必备功能哦！
 * </p>
 * <p>
 * 数据结构中：key=群组id、value=该群组的消息列表.
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 * @version 1.0
 * @since 2.4
 */

#import <Foundation/Foundation.h>
#import "MessagesProvider.h"

@interface GroupsMessagesProvider : MessagesProvider

///**
// * 用于聊天界面上下拉加载更新历史记录功能。
// */
//- (NSMutableArrayObservableEx *) loadMoreMessages:(NSString *)gid complete:(void (^)(BOOL sucess))complete;

/**
 * 按父指纹码查找对应用户的消息对象。
 *
 * @param gid 群id
 * @param fingerPrintOfParent 父消息的指纹码（每条群聊消息都是由消息发起者的这条消息扩散出来的，这条原始消息被称为"父"消息）
 * @return 找到则返回，否由返回null
 */
- (JSQMessage *)findMessageByParentFingerPrint:(NSString *)gid fp:(NSString *)fingerPrintOfParent;

@end
