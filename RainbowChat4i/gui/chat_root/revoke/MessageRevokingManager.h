//telegram @wz662
//
//  MessageRevokingManager.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/11/13.
//  Copyright © 2021 JackJiang. All rights reserved.
//
/**
 * 消息"撤回"全局管理器。
 * <p>
 * 【该管理器的作用】：
 * 由于实时消息撤回指令跟其它实时指令一样，都是异步发出和异步应答的（消息撤回指令等待应答的目的是
 * 确保消息撤回指令已送达，否则将影响撤回功能的用户体验，这很重要），所以本类中使用一个Map管理当前
 * 正在被撤回中的消息（即key=撤回指令的fp指纹码，value=当前正在被撤回消息在消息列表中的Message
 * 数据模型对象），当收到撤回指令的的ACK应答包时，就表示撤回指令已送达，UI上就可以取消跟微信\QQ
 * 一样的菊花进度提示框架、同时进行本地消息撤回的余下逻辑（sqlite更新、ui显示更新等）。
 * <p>
 * 【一个疑问】：
 * 既然消息撤回指令使用实时指令，因为异步应答让事情应该的稍难处理，那干嘛不像其它需要即时得到反馈的
 * 指令那样通过http接口发出呢？原因是消息撤回涉及到陌生人聊天、好友聊天、群聊天，http接口到服务端后
 * ，服务端那头再进行撤回的下行逻辑（即通知被撤回方、以及一些离线处理逻辑等等），需要区分3种聊天模式
 * 的话，就会多很多额外的代码，会把事情搞的更复杂。所以目前这样，利用聊天通道，以实时指令方式送出，作
 * 为一种特殊的"聊天"消息，就可以借用现有的完整消息发送、应答、离线逻辑、消息记录处理逻辑，就能少掉很
 * 多额外代码，代码实现上也更优雅。
 * <p>
 * 【跟UI层的解耦合】：
 * 由于撤回功能，需要像微信、qq那样在撤回成功应答前需要显示一个菊花进度提示框，当收到应答后需要取消进
 * 度的显示，而本管理器作为数据模型和核心逻辑层面的实现，不应跟UI产生耦合，所以目前的实现思路就是：当
 * 撤回动作开始时就由聊天界面来显示一个进度提示框架，到后台收到撤回应时，再通过系统广播（当然也可以
 * EventBus这种框架）通知聊天界面取消进度提示的显示，这样就能跟UI进行优雅解偶了！
 *
 * @author JackJiang
 * @since 4.3
 */

#import <Foundation/Foundation.h>
#import "MessageBeRevoke.h"
#import "RevokedMeta.h"

@interface MessageRevokingManager : NSObject

// 开始撤回
- (void)revokeStart:(NSString *)fpForRevokeCmd messageBeRevoke:(MessageBeRevoke *)messageBeRevoke;

/// 撤回成功后执行本地更新（sqlite + 内存 + UI 通知）
- (void)fireRevokeSucess:(NSString *)fpForRevokeCmd messageBeRevoke:(MessageBeRevoke *)messageBeRevoke;

// 已收到撤回指令应答（可以认为将被或已被对方收到）
- (BOOL)revokeCmdBeRecieved:(NSString *)fpForRevokeCmd;

/**
 * 消息"撤回"指令没有成功送出（可能是本地网络有问题）。
 *
 * @param fpForRevokeCmd 发出的消息"撤回"指令对应的指纹码
 * @return true表示集合中存在该fp
 */
- (BOOL)revokeCmdBeLost:(NSString *)fpForRevokeCmd;

- (void)clear;

/**
 * 更新本地数据库。
 *
 * @param chatType 聊天模式
 * @param fpForMessage 被撤回消息的指纹码（如果是群聊消息，则此值应取它的fingerPringOfParent值哦）
 * @param textObj 被撤回消息的新内容对象
 * @return 是否更新成功
 */
+ (BOOL)updateSQLiteForMessage:(int)chatType fpForMessage:(NSString *)fpForMessage textObj:(RevokedMeta *)textObj;

/**
 * 更新消息列表数据对象内容。
 *
 * @param content 更新内容
 * @param message 要撤回的消息位于聊天列表数据模型中的消息对象
 * @return true表示更新成功，否则不成功
 */
+ (BOOL)updateModelForMessage:(RevokedMeta *)content message:(JSQMessage *)message fpForRevokeCmd:(NSString *)fpForRevokeCmd fpForMessage:(NSString *)fpForMessage;

/**
 * 更新消息列表中"引用"了被撤回消息的这些消息上的引用状态字段值。
 *
 * @param fromId 聊天对象id（单聊uid或群id）
 * @param fpForOriginalMessage 被引用消息的指纹码
 * @return true表示更新成功，否则不成功
 */
+ (BOOL)updateModelForQuoteMessages:(int)chatType fromId:(NSString *)fromId fp:(NSString *)fpForOriginalMessage;

/**
 * 为消息"撤回"发起者构建撤回指令内容对象。
 *
 * @param fpForMessage 被撤回消息的指纹码（如果是群聊消息，则此值应取它的fingerPringOfParent值哦）
 * @param beUid 被"撤回"者的uid（当前用于群聊时，由管理员撤回其它群员消息时存入被撤回消息的发送者uid，其它余情况下本参数为空！）
 * @param beNickName 被"撤回"者的昵称（当前用于群聊时，由管理员撤回其它群员消息时存入被撤回消息的发送者uid，其它余情况下本参数为空！）
 * @return 新对象
 */
+ (RevokedMeta *)constructRevokedMetaForOperator:(NSString *)fpForMessage beUid:(NSString *)beUid beNickName:(NSString *)beNickName;

/**
 * 处时收到的消息"撤回"指令逻辑。
 *
 * @param chatType 聊天类型，see {@link ChatType}
 * @param fpForRevokeCMD 撤回指令本身的指纹码
 * @param fromId 一对一聊天时此参数表示对方的uid，群聊时表示是群id
 * @param messageContent 消息撤回指令的内容
 */
+ (void)processRevokeMessage_incoming:(int)chatType fpForRevokeCMD:(NSString *)fpForRevokeCMD fromId:(NSString *)fromId messageContent:(NSString *) messageContent;

@end
