//telegram @wz662
//
//  Quote4InputWrapper.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2024/3/14.
//  Copyright © 2024 JackJiang. All rights reserved.
//
/**
 * 聊天界面中输入框下方的被引用消息内容显示组件逻辑封装类。
 *
 * @author JackJiang
 * @since 11.0
 */

#import <Foundation/Foundation.h>
#import "JSQMessagesViewController.h"
#import "MsgBodyRoot.h"


@interface Quote4InputWrapper : NSObject

- (id)initWith:(JSQMessagesViewController *)messagesViewController;

/**
 * 点击消息气泡中"引用"菜单项后执行的消息引用逻辑。
 *
 * @param chatType 聊天类型
 * @param toId 聊天对象id
 * @param beQuoteMessage 被引用消息对象
 */
- (void)doQuote:(int)chatType to:(NSString *)toId with:(JSQMessage *)beQuoteMessage;

- (void)cancelQuote:(UITapGestureRecognizer *)gestureRecognizer;

/**
 * 返回本次引用消息的无数据对象（用于消息发送时使用）。
 *
 * @param chatType 聊天类型
 * @param toId 聊天对象id
 * @return 返回新的QuoteMeta对象
 */
- (QuoteMeta *)getQuoteMeta:(int)chatType with:(NSString *)toId;

+ (NSString *)getQuoteNick:(int)chatType to:(NSString *)toId quoteUid:(NSString *)quoteSenderId quoteNick:(NSString *)quoteSenderNick;
@end
