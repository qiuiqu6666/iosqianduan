//telegram @wz662
//
//  MessageBeRevoke.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/11/13.
//  Copyright © 2021 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JSQMessage.h"

/**
 * 本数据传输类目前仅用于消息撤回开始时，保存于全局消息撤回管理器中，以备管理器方便读取被撤回消息的关键数据之用。
 *
 * @since 4.3
 * @author JackJiang
 */
@interface MessageBeRevoke : NSObject

@property (nonatomic, assign) int chatType;
@property (nonatomic, retain) NSString *toId;
@property (nonatomic, retain) JSQMessage *message;

+ (id)initWith:(int)chatType toId:(NSString *)toId message:(JSQMessage *)message;

@end
