//telegram @wz662
#import <Foundation/Foundation.h>
#import "UserProtocalsType.h"
#import "CompletionDefine.h"
//#import "ChatMsgEntity.h"
#import "MessagesProvider.h"
#import "JSQSystemSoundPlayer+JSQMessages.h"
#import "UserEntity.h"
#import "JSQMessage.h"
#import "RevokedMeta.h"

@interface ChatDataHelper : NSObject

/**
 * 添加一条通用群聊系统通知到聊天数据结构中.
 *
 * @param systemInfo
 * @param showNotification
 */
+ (void)addSystemInfoData:(UserEntity *)ree
              infoContent:(NSString *)systemInfo
                     date:(NSDate *)time
                playAudio:(BOOL)playPromtAudio
               showNotify:(BOOL)showNotification;

+ (void)addSystemInfoData:(UserEntity *)ree
              infoContent:(NSString *)systemInfo
              fingerPrint:(NSString *)fingerPrint
                     date:(NSDate *)time
                playAudio:(BOOL)playPromtAudio
               showNotify:(BOOL)showNotification;

/**
 处理收到的聊天文本消息.

 @param fingerPrint 收到的消息的指纹码
 @param messageContent 真正的聊天文本内容（该内容可能是扁平文本（文本聊天消息）、文件（语音留言、图片消息）），是TextMessage中的m内容
 @param time 该消息的发出时间（NSDate对象），实时消息可直接传nil值（代码中将自动使用当前时间），比如离线消息则此值肯定就是它最后一条离线消息的时间了
 @param playPromtAudio 是否播放新消息声音提示
 @param showNotification 是否弹出本地系统通知
 @param msgType 真正的聊天消息类型（是TextMessage对象中的ty内容）
 @param ree 该用户的个人信息传输对象
 @param quoteMeta 消息引用信息（当前仅用于文本消息时），此字段可为空（表示本条无引用消息）
 */
+ (void)addChatMessageData_incoming:(NSString *)fingerPrint msgContent:(NSString *)messageContent withTime:(NSDate *)time playAudio:(BOOL)playPromtAudio showNotify:(BOOL)showNotification msgType:(int)msgType withRee:(UserEntity *)ree andQuote:(QuoteMeta *)quoteMeta;

/**
 * 与不带 `suppressUnreadBump` 的版本相同；`suppressUnreadBump=YES` 时不叠加会话未读、不记 SyncManager 入站未读、不弹本地推送（MT60 等同 fp 落库）。
 */
+ (void)addChatMessageData_incoming:(NSString *)fingerPrint msgContent:(NSString *)messageContent withTime:(NSDate *)time playAudio:(BOOL)playPromtAudio showNotify:(BOOL)showNotification msgType:(int)msgType withRee:(UserEntity *)ree andQuote:(QuoteMeta *)quoteMeta suppressUnreadBump:(BOOL)suppressUnreadBump;

+ (JSQMessage *)addChatMessageData_outgoing:(NSString *)friendUid withData:(JSQMessage *)entity;

@end
