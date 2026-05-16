//telegram @wz662
//
//  MessageRevokingManager.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/11/13.
//  Copyright © 2021 JackJiang. All rights reserved.
//

#import "MessageRevokingManager.h"
#import "IMClientManager.h"
#import "UserEntity.h"
#import "NotificationCenterFactory.h"
#import "MyDataBase.h"
#import "MessagesProvider.h"


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface MessageRevokingManager ()

/** 正在被"撤回"的消息集合（虽然实际实用时，一般集合中只有一条，但技术实现上能支持多条，目的对用户的非正常操作进行最大限度的容错） */
@property (nonatomic, retain) NSMutableDictionary *beRevokingMessages;

@end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MessageRevokingManager

- (id)init
{
    if (![super init])
        return nil;
    
    NSLog(@"MessageRevokingManager已经init了！");
    
    self.beRevokingMessages = [[NSMutableDictionary alloc] init];
    return self;
}

// 开始撤回
- (void)revokeStart:(NSString *)fpForRevokeCmd messageBeRevoke:(MessageBeRevoke *)messageBeRevoke
{
    DDLogInfo(@"【消息撤回】[revokeStart]fpForRevokeCmd=%@, messageBeRevoke=%@", fpForRevokeCmd, messageBeRevoke);
    if(fpForRevokeCmd != nil && messageBeRevoke != nil) {
//      if (!messages.containsKey(fpForRevokeCmd))
        [self.beRevokingMessages setObject:messageBeRevoke forKey:fpForRevokeCmd];
    }
    else{
        DDLogWarn(@"【消息撤回】无效的参数，revokeStart无法继续，fpForRevokeCmd=%@、messageBeRevoke=%@", fpForRevokeCmd, messageBeRevoke);
    }
}

// 已收到撤回指令应答（可以认为将被或已被对方收到）
- (BOOL)revokeCmdBeRecieved:(NSString *)fpForRevokeCmd
{
    MessageBeRevoke *beRevoking = [self.beRevokingMessages objectForKey:fpForRevokeCmd];
    if(beRevoking != nil){
        DDLogInfo(@"【消息撤回】[revokeCmdBeRecieved]收到fpForRevokeCmd=%@的应答，且查【有】此fp，将继续往下执行消息撤回功能的余下逻辑.....", fpForRevokeCmd);
        // ★ 如果本端在发起撤回时已经执行过 fireRevokeSucess（消息已是撤回态），则 ACK 仅用于结束进度，不再重复执行撤回逻辑，避免出现两条撤回记录
        if (beRevoking.message && beRevoking.message.msgType == TM_TYPE_REVOKE) {
            DDLogInfo(@"【消息撤回】revokeCmdBeRecieved: 对应消息已是撤回态(msgType=TM_TYPE_REVOKE)，仅移除管理器记录，不再重复 fireRevokeSucess。");
        } else {
            [self fireRevokeSucess:fpForRevokeCmd messageBeRevoke:beRevoking];
        }
        [self.beRevokingMessages removeObjectForKey:fpForRevokeCmd];
        
        return YES;
    }
    else{
        DDLogInfo(@"【消息撤回】[revokeCmdBeRecieved]收到fpForRevokeCmd=%@的应答，且查【无!】此fp，此条应答将被忽额。", fpForRevokeCmd);
    }
    
    return NO;
}

// 消息"撤回"指令没有成功送出（可能是本地网络有问题）
- (BOOL)revokeCmdBeLost:(NSString *)fpForRevokeCmd
{
    MessageBeRevoke *beRevoking = [self.beRevokingMessages objectForKey:fpForRevokeCmd];
    if(beRevoking != nil){
        DDLogInfo(@"【消息撤回】【消息撤回】[revokeCmdBeLost]fpForRevokeCmd=%@无法送达，且查【有】此fp，将从本管理器中删除此条\"撤回中\"消息的对象应用哦。", fpForRevokeCmd);
        [self.beRevokingMessages removeObjectForKey:fpForRevokeCmd];
        
        return YES;
    }
    else{
        DDLogInfo(@"【消息撤回】[revokeCmdBeLost]fpForRevokeCmd=%@无法送达，且查【无!】此fp，什么也不用做。", fpForRevokeCmd);
    }
    
    return NO;
}

/**
 * 消息撤回成功后要做的事。
 *
 * @param fpForRevokeCmd 发出的消息"撤回"指令对应的指纹码
 * @param messageBeRevoke 要撤回的消息位于聊天列表数据模型中的消息对象
 * @throws Exception
 */
- (void)fireRevokeSucess:(NSString *)fpForRevokeCmd messageBeRevoke:(MessageBeRevoke *)messageBeRevoke
{
    DDLogInfo(@"【消息撤回】消息撤回成功，马上开始执行真正的撤回逻辑 ==> messageBeRevoke = %@", messageBeRevoke);
    
    if(messageBeRevoke == nil) {
        DDLogWarn(@"【消息撤回】messageBeRevoke == null！");
        return;
    }
    
    // 被撤回消息来自于哪种聊天模式
    int chatType = messageBeRevoke.chatType;
    // 被撤回消息所处聊天列表中的数据模型对象引用
    JSQMessage *message = messageBeRevoke.message;
    
    BOOL isGroupChat = (chatType == CHAT_TYPE_GROUP_CHAT);
    // 被撤回消息的指纹码（如果是群聊消息，则这是被撤回消息的父指纹码）
    NSString *fpForMessage = (isGroupChat ? message.fingerPrintOfParent : message.fingerPrintOfProtocal);
    // 构造被撤回消息内容对象（后续发出的指令内容等，就是这个对象）
    RevokedMeta *content = [MessageRevokingManager constructRevokedMetaForOperator:fpForMessage
                                                                            // 是群聊 且 撤回的是别人的消息时，需要传入被撤回消息发送者的uid
                                                                             beUid:(isGroupChat && ![message isOutgoing]?message.senderId:nil)
                                                                            // 是群聊 且 撤回的是别人的消息时，需要传入被撤回消息发送者的昵称
                                                                        beNickName:(isGroupChat && ![message isOutgoing]?message.senderDisplayName:nil)
    ];
    
    //*** 更新本地sqlite数据库
    [MessageRevokingManager updateSQLiteForMessage:chatType fpForMessage:fpForMessage textObj:content];
    
    //*** 更新消息列表数据对象内容
    BOOL sucess = [MessageRevokingManager updateModelForMessage:content message:message fpForRevokeCmd:fpForRevokeCmd fpForMessage:fpForMessage];
    if (sucess) {
        DDLogInfo(@"【消息撤回】主动撤回消息时，updateModelForMessage成功了。(content=%@，message=%@，fpForRevokeCmd=%@)", content, message, fpForRevokeCmd);
    }
    else{
        DDLogWarn(@"【消息撤回】主动撤回消息时，updateModelForMessage失败了！(content=%@，message=%@，fpForRevokeCmd=%@)", content, message, fpForRevokeCmd);
    }
    
    //*** 更新消息列表中"引用"了被撤回消息的这些消息上的引用状态字段值
    [MessageRevokingManager updateModelForQuoteMessages:chatType fromId:messageBeRevoke.toId fp:fpForMessage];
    
    //*** 通知UI层刷新显示
    [NotificationCenterFactory revokeCMDRecieved_POST:fpForRevokeCmd fpForRMessage:fpForMessage];
}

- (void)clear
{
    if(self.beRevokingMessages != nil)
        [self.beRevokingMessages removeAllObjects];
}

// 更新本地数据库
+ (BOOL)updateSQLiteForMessage:(int)chatType fpForMessage:(NSString *)fpForMessage textObj:(RevokedMeta *)textObj
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee == nil) {
        DDLogWarn(@"【消息撤回】localRee == null，updateSQLiteForMessage不能继续！");
        return NO;
    }

    if(textObj == nil) {
        DDLogWarn(@"【消息撤回】textObj == null，updateSQLiteForMessage不能继续！");
        return NO;
    }

    if(chatType == CHAT_TYPE_FREIDN_CHAT || chatType == CHAT_TYPE_GUEST_CHAT){
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            BOOL sucess = [[MyDataBase sharedInstance].chatHistoryTable updateForRevoke:db acountUidOfOwner:localRee.user_uid fp:fpForMessage meta:textObj];
            if(!sucess)
                [MyDataBase printErrorForDebug:db tag:@"updateSQLiteForMessage"];
        }];
    }
    else if(chatType == CHAT_TYPE_GROUP_CHAT){
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            BOOL sucess = [[MyDataBase sharedInstance].groupChatHistoryTable updateForRevoke:db acountUidOfOwner:localRee.user_uid fp:fpForMessage meta:textObj];
            if(!sucess)
                [MyDataBase printErrorForDebug:db tag:@"updateSQLiteForMessage群聊"];
        }];
    }
    
    return YES;
}

// 更新消息列表数据对象内容
+ (BOOL)updateModelForMessage:(RevokedMeta *)content message:(JSQMessage *)message fpForRevokeCmd:(NSString *)fpForRevokeCmd fpForMessage:(NSString *)fpForMessage
{
    if (content != nil) {
        // 当是文本消息时就不清理消息内容了（以便稍后实现消息撤回后的"重新编辑"功能）
        if (message.msgType == TM_TYPE_TEXT) {
            content.originalContent = message.text;
        }
        message.text = [RevokedMeta toJSON:content];
        message.msgType = TM_TYPE_REVOKE;
        
//      //*** 通知UI层刷新显示
//      [NotificationCenterFactory revokeCMDRecieved_POST:fpForRevokeCmd fpForRMessage:fpForMessage];
        
        return YES;
    }
    return NO;
}

// 更新消息列表中"引用"了被撤回消息的这些消息上的引用状态字段值
+ (BOOL)updateModelForQuoteMessages:(int)chatType fromId:(NSString *)fromId fp:(NSString *)fpForOriginalMessage
{
    @try {
        IMClientManager *imc = [IMClientManager sharedInstance];
        MessagesProvider *messagesProvider = nil;
        if (chatType == CHAT_TYPE_FREIDN_CHAT || chatType == CHAT_TYPE_GUEST_CHAT) {
            messagesProvider = [imc getMessagesProvider];
        } else if (chatType == CHAT_TYPE_GROUP_CHAT) {
            messagesProvider = [imc getGroupsMessagesProvider];
        }

        if(messagesProvider == nil) {
            DDLogWarn(@"【消息撤回-更新引用消息状态】未知的chatType=%d，它对应的messagesProvider==null, updateModelForQuoteMessages 无法继续！", chatType);
            return NO;
        }

        // 查找所有引用了原消息的消息对象
        NSArray<JSQMessage *> *allQuoteMessages = [messagesProvider findMessagesByQuoteFingerPrint:fromId beQuotedFp:fpForOriginalMessage];
        if ([allQuoteMessages count] > 0) {
            for (JSQMessage *m in allQuoteMessages) {
                if (m != nil) {
                    // 更新引用状态为1（表示原消息已被撤回）
                    m.quote_status = 1;
                }
            }

            DDLogWarn(@"【消息撤回-更新引用消息状态】被撤回消息时，updateModelForQuoteMessage成功了（影响消息条数=%ld）。", [allQuoteMessages count]);
        } else {
            DDLogWarn(@"【消息撤回-更新引用消息状态】被撤回消息时，updateModelForQuoteMessage完成了，但引用消息数为空，没有找到引用它的消息哦。");
        }

        return YES;
    } @catch (NSException *exception) {
        DDLogWarn(@"【消息撤回-更新引用消息状态】updateModelForQuoteMessages failed with exception: %@", exception);
    }

    return NO;
}

// 为消息"撤回"发起者构建撤回指令内容对象
+ (RevokedMeta *)constructRevokedMetaForOperator:(NSString *)fpForMessage beUid:(NSString *)beUid beNickName:(NSString *)beNickName
{
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if(localRee == nil)
        return nil;
    
    RevokedMeta *rm = [RevokedMeta initWith:localRee.user_uid nickname:localRee.nickname fp:fpForMessage];
    rm.beUid = beUid;
    rm.beNickName = beNickName;
    return rm;
}

/**
 * 处里收到的消息"撤回"指令逻辑。
 *
 * @param chatType 聊天类型，see {@link ChatType}
 * @param fpForRevokeCMD 撤回指令本身的指纹码
 * @param fromId 一对一聊天时此参数表示对方的uid，群聊时表示是群id
 * @param messageContent 消息撤回指令的内容
 */
+ (void)processRevokeMessage_incoming:(int)chatType fpForRevokeCMD:(NSString *)fpForRevokeCMD fromId:(NSString *)fromId messageContent:(NSString *) messageContent
{
    RevokedMeta *messageContentObj = [RevokedMeta fromJSON:messageContent];
    if(messageContentObj != nil && messageContentObj.fpForMessage != nil) {
        // ★ 本机在会话内主动撤回时，IM 会再推一条「撤回者=自己」的指令：跳过以免双写。
        // ★ MT62 多端同步（fp 带 _mt62_revoke）时，同账号另一台设备上撤回者仍是自己，不得跳过，否则 B 端不更新。
        BOOL fromMt62MultiDevice = (fpForRevokeCMD != nil && [fpForRevokeCMD rangeOfString:@"_mt62_revoke"].location != NSNotFound);
        UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
        if (!fromMt62MultiDevice && localUser != nil && [messageContentObj.uid isKindOfClass:[NSString class]]) {
            if ([messageContentObj.uid isEqualToString:localUser.user_uid]) {
                DDLogInfo(@"【消息撤回】收到来自本端(uid=%@)的撤回指令同步包，已由主动撤回处理，跳过 processRevokeMessage_incoming。", messageContentObj.uid);
                return;
            }
        }
        //*** 更新本地sqlite数据库
        BOOL row = [MessageRevokingManager updateSQLiteForMessage:chatType fpForMessage:messageContentObj.fpForMessage textObj:messageContentObj];
        DDLogInfo(@"【消息撤回】被撤回消息时，updateSQLiteForMessage完成，影响row=%d。(messageContentObj=%@，fpForRevokeCmd=%@)", row, messageContentObj, fpForRevokeCMD);
        
        JSQMessage *originalMessage = nil;
        //*** 更新消息列表数据对象内容
        if(chatType == CHAT_TYPE_FREIDN_CHAT || chatType == CHAT_TYPE_GUEST_CHAT) {
            
            originalMessage = [[[IMClientManager sharedInstance] getMessagesProvider] findMessageByFingerPrint:fromId fp:messageContentObj.fpForMessage];
        }
        else if(chatType == CHAT_TYPE_GROUP_CHAT){
            originalMessage = [[[IMClientManager sharedInstance] getGroupsMessagesProvider] findMessageByParentFingerPrint:fromId fp:messageContentObj.fpForMessage];
        }
        else{
            DDLogWarn(@"【消息撤回】未知的chatType=%d, processRevokeMessage_incoming无法继续！", chatType);
        }
//      Log.i(TAG, "【=A=】被撤回消息updateModelForMessage前，originalMessage="+originalMessage);
        
        if(originalMessage != nil){
            BOOL sucess = [MessageRevokingManager updateModelForMessage:messageContentObj message:originalMessage fpForRevokeCmd:fpForRevokeCMD fpForMessage:messageContentObj.fpForMessage];
            if (sucess) {
                DDLogInfo(@"【消息撤回】被撤回消息时，updateModelForMessage成功了。(messageContentObj=%@，fpForRevokeCmd=%@)", messageContentObj, fpForRevokeCMD);
            }
            else{
                DDLogWarn(@"【消息撤回】被撤回消息时，updateModelForMessage失败了！(messageContentObj=%@，originalMessage=%@，fpForRevokeCmd=%@)", messageContentObj, originalMessage, fpForRevokeCMD);
            }
        }
        else{
            DDLogWarn(@"【消息撤回】被撤回消息时，正准备updateModelForMessage，但数据为空，originalMessage=null");
        }
        
        //*** 更新消息列表中"引用"了被撤回消息的这些消息上的引用状态字段值
        [MessageRevokingManager updateModelForQuoteMessages:chatType fromId:fromId fp:messageContentObj.fpForMessage];
        
        //*** 通知UI层刷新显示
        [NotificationCenterFactory revokeCMDRecieved_POST:fpForRevokeCMD fpForRMessage:messageContentObj.fpForMessage];
    }
    else{
        DDLogWarn(@"【消息撤回】被撤回消息时，正准备updateSQLiteForMessage等，但数据为空，messageContentObj=%@", messageContentObj);
    }
}

@end
