//telegram @wz662
//
//  RevokedMeta.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/11/13.
//  Copyright © 2021 JackJiang. All rights reserved.
//

/**
 * 消息"撤回"指令的信息元数据.
 *
 * @author JackJiang
 */

#import <Foundation/Foundation.h>

@interface RevokedMeta : NSObject

/** "撤回"者的uid */
@property (nonatomic, retain) NSString *uid;
/** 撤回"者的昵称 */
@property (nonatomic, retain) NSString *nickName;
/**
 * 被"撤回"者的uid。
 * <p>
 * 注：用于群聊时，由管理员撤回其它群员消息时存入被撤回消息的发送者uid，其它余情况下本参数为空！
 */
@property (nonatomic, retain) NSString *beUid;
/**
 * 被"撤回"者的昵称。
 * <p>
 * 注：用于群聊时，由管理员撤回其它群员消息时存入被撤回消息的发送者uid，其它余情况下本参数为空！
 */
@property (nonatomic, retain) NSString *beNickName;

/** 将要被撤回的消息的指纹码（也就是唯一ID啦） */
@property (nonatomic, retain) NSString *fpForMessage;
/** 未撤回前的原始消内容（当前仅用于文本消息时，用于撤回后的"重新编辑"功能时使用） */
@property (nonatomic, retain) NSString *originalContent;

+ (RevokedMeta *)initWith:(NSString *)uid nickname:(NSString *)nickname fp:(NSString *)fpForMessage;
+ (RevokedMeta *)fromJSON:(NSString *)jsonOfRevokedMeta;
+ (NSString *)toJSON:(RevokedMeta *)meta;

@end
