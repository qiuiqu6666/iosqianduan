//telegram @wz662
//
//  MsgDetailSearchResult.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/22.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 * 聊天记录搜索结果数据封装对象（搜索结果是不聚合的详细形式，有多少条消息就是多少条）。
 *
 * @author JackJiang
 * @since 6.0
 */

#import <Foundation/Foundation.h>
#import "MsgSummaryContentDTO.h"


@interface MsgDetailContentDTO : MsgSummaryContentDTO

/** 消息发送者uid */
@property (nonatomic, retain) NSString *senderId;
/** 消息发送者昵称（用于单聊陌生人消息和群聊消息时）*/
@property (nonatomic, retain) NSString *senderDisplayName;

/** 引用消息的发送者uid（用于收藏夹 10001 显示来源头像）*/
@property (nonatomic, retain) NSString *quoteSenderUid;
/** 引用消息的发送者昵称（用于收藏夹 10001 显示来源昵称）*/
@property (nonatomic, retain) NSString *quoteSenderNick;

/** 消息类型（0=文本,1=图片,2=语音,5=文件,6=短视频,9=通话记录等） */
@property (nonatomic, assign) int msgType;

@end

