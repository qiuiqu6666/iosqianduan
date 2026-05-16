//telegram @wz662
//
//  QuoteFields.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2024/3/22.
//  Copyright © 2024 JackJiang. All rights reserved.
//
/**
 * 被引用消息的相关字段。
 *
 * @author JackJiang
 * @since 9.0
 * @see  com.x52im.rainbowchat.im.dto.QuoteMeta
 */

#import <Foundation/Foundation.h>
#import "TableRoot.h"

/** 表格字段名：@see {@link JSQMessage#quote_fp}的同名列 */
FOUNDATION_EXPORT NSString const *COLUMN_KEY_QUOTE_FP;

/** 表格字段名：@see {@link JSQMessage#quote_sender_uid}的同名列 */
FOUNDATION_EXPORT NSString const *COLUMN_KEY_QUOTE_SENDER_UID;

/** 表格字段名：@see {@link JSQMessage#quote_sender_nick}的同名列 */
FOUNDATION_EXPORT NSString const *COLUMN_KEY_QUOTE_SENDER_NICK;

/** 表格字段名：@see {@link JSQMessage#quote_status}的同名列 */
FOUNDATION_EXPORT NSString const *COLUMN_KEY_QUOTE_STATUS;

/** 表格字段名：@see {@link JSQMessage#quote_content}的同名列 */
FOUNDATION_EXPORT NSString const *COLUMN_KEY_QUOTE_CONTENT;

/** 表格字段名：@see {@link JSQMessage#quote_type}的同名列 */
FOUNDATION_EXPORT NSString const *COLUMN_KEY_QUOTE_TYPE;

@interface QuoteFields : TableRoot

@end

