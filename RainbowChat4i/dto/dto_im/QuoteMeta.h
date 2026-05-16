//telegram @wz662
//
//  QuoteMeta.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2024/3/12.
//  Copyright © 2024 JackJiang. All rights reserved.
//
/**
 * 消息“引用”元数据对象。用于存放消息“引用”功能时的被引用消息相关信息。
 *
 * <p>
 * <b>此DTO传输的数据对应于“离线聊天记录/MISSU_OFFLINE_HISTORY”等数据库表中的相关字段.</b>
 *
 * @author JackJiang
 * @since 9.0
 */

#import <Foundation/Foundation.h>

@interface QuoteMeta : NSObject

/** 引用消息的指纹码（注：如果是群聊，则存放的是被引用群聊消息被服务端扩散写前的原始指纹码（也就是群成员收到的此条群聊消息的父指纹码）） */
@property (nonatomic, retain) NSString *quote_fp;

/** 引用消息的发送者uid */
@property (nonatomic, retain) NSString *quote_sender_uid;

/** 引用消息的发送者昵称 */
@property (nonatomic, retain) NSString *quote_sender_nick;

/** 引用消息的状态（0 原消息正常，1 原消息已被撤回。默认0） */
@property (nonatomic, assign) int quote_status;

/** 引用消息的内容 */
@property (nonatomic, retain) NSString *quote_content;

/** 引用消息的类型 */
@property (nonatomic, assign) int quote_type;

/**
 * 一次性设置所有字段值。
 *
 * @param qm 引用信息临时对象
 */
- (void)setQuoteMeta:(QuoteMeta *)qm;

@end

