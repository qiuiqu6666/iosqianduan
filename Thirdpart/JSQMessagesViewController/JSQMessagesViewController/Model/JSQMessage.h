//telegram @wz662
//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import <Foundation/Foundation.h>

//#import "JSQMessageData.h"
#import "JSQMediaItem.h"
#import "ContactMeta.h"
#import "FileMeta.h"
#import "LocationMeta.h"
#import "RevokedMeta.h"
#import "VoipRecordMeta.h"
#import "QuoteMeta.h"


/*
 * 文字消息的发送状态常量.
 */
typedef NS_ENUM(NSInteger, SendStatus){
    /** 消息发送中 */
    SendStatus_SNEDING     = 0,
    /** 消息已被对方收到（我方已收到应答包） */
    SendStatus_BE_RECEIVED = 1,
    /** 消息发送失败（在超时重传的时间内未收到应答包） */
    SendStatus_SEND_FAILD  = 2,
};

/**
 * 辅助发送状态常量.
 * <p>
 * 此常量通常用于发送图片、语音留言场合，因为图片上传到服务端的过程是
 * 一个独立的处理过程，需要和文字消息分开处理.
 */
typedef NS_ENUM(NSInteger, SendStatusSecondary){
    /** 无需处理 */
    SendStatusSecondary_NONE          = 0,
    /** 等待处理 */
    SendStatusSecondary_PENDING       = 1,
    /** 处理中 */
    SendStatusSecondary_PROCESSING    = 2,
    /** 成功处理完成 */
    SendStatusSecondary_PROCESS_OK    = 3,
    /** 处理失败 */
    SendStatusSecondary_PROCESS_FAILD = 4,
};


@interface JSQMessage : QuoteMeta// <NSCoding, NSCopying>

//======================================================== 核心数据字段 START
@property (copy, nonatomic) NSString *senderId;
@property (copy, nonatomic) NSString *senderDisplayName;
@property (copy, nonatomic) NSDate *date;

/** 消息内容（根据消息内容类型的不同，它可能是个复合JSON字符串哦） */
@property (copy, nonatomic) NSString *text;

/**
 额外的多媒体数据(图片、语音留言消息需要的额外信息，这是区别于纯文本数据的额外需要).
 当此参数为nil时表示该消息还没有加载过额外的多媒体数据，加载通常在界面列表中显示时才需要，不然没必要浪费内存。
 */
@property (retain, nonatomic) JSQMediaItem *media;

/** 消息类型 */
@property (nonatomic, assign) int msgType;
/** 消息所对应的原始协议包指纹，目前只在发出的消息对象中有意义 */
@property (nonatomic, retain) NSString *fingerPrintOfProtocal;
/** 消息所对应的群聊发送者发出的原始包协议包指纹，目前只在收到的消息对象中有意义，且仅用于群聊消息时作为消息"撤回"功能的匹配依据 */
@property (nonatomic, retain) NSString *fingerPrintOfParent;
//======================================================== 核心数据字段 END

//======================================================== 辅助UI显示字段 START
/** 文字消息从网络发送的当前状态. 本字段仅针对发送的消息（而非收到的消息哦） */
@property (nonatomic, assign) int sendStatus;
/**
 * 辅助处理状态. 本字段仅针对发送的消息（而非收到的消息哦）.
 * <p>
 * 此常量通常用于发送图片、语音留言场合，因为图片上传到服务端的过程是
 * 一个独立的处理过程，需要和文字消息分开处理. */
@property (nonatomic, assign) int sendStatusSecondary;
/**
 * 辅助处理状态下的进度值（0~100整数）. 本字段仅针对发送的消息（而非收到的消息哦）.
 * <p>
 * 本字段当前仅用于大文件消息的文件数据传输时（当然，你也可以用于其它消息类型，
 * 这样的值仅辅助UI显示，并非关键数据）。
 * @since 2.1
 */
@property (nonatomic, assign) int sendStatusSecondaryProgress;

/**
 * 这是一个特殊的标识：用于记录该条"发出"的消息是"我"转发出去的，而不是正常发出的。
 * <p>
 * 本标识目前仅用于：因网络原因发送失败的消息，由用户点失败小图标再次重传时。
 * <p>
 * 添加本标识的原因：让此消息在用户点重传时走"转发"逻辑而不是正常的"重传"逻辑，因为存在一种情况：就是"我"转发
 * 收到的消息（比如大文件消息）失败，如果点重传图标走正常的"重传"逻辑时，会先进行文件的上传完整逻辑完成后再发
 * 送重传消息，但因此文件本身就是从收到的消息中转发而来，文件自然还没有被下载下来，则此时的重传不可能成功。而
 * 如果此条消息再走的是"转发"逻辑的话，就不会有问题，因为转发不需要对文件进行上传处理（因为转发的逻辑前提是，
 * 这条消息本身已是正常发出的消息，文件什么的早以由原发生者上传到服务器了）。
 *
 * @since 8.0
 */
@property (nonatomic, assign) int forwardOutgoing;

/**
 * 是否显示消息气泡上方的时间。
 * 参照微信的逻辑：http://www.52im.net/thread-3008-1-1.html#40，5分钟内的聊天消息才会在上方显示时间。
 *
 * @since 4.1
 */
@property (nonatomic, assign) BOOL showTopTime;

/**
 * 是否高亮显示一次。
 * <p>
 * 本参数非持久化变量，仅在由搜索功能进入聊天界面时，用于1次高亮显示该条搜索到消息时使用（高亮动画完成后会重新置为false）。
 *
 * @since 6.0
 */
@property (nonatomic, assign, getter=isHighlightOnce) BOOL highlightOnce;

/**
 * 该消息是否 @了我（仅用于群聊收到的消息）。
 * <p>
 * 用于聊天界面中浮动提示"有人@我"并跳转到对应消息位置。
 */
@property (nonatomic, assign, getter=isAtMe) BOOL atMe;

/**
 * 对方是否已读此消息（仅对"我"发出的消息有意义，用于显示 ✓✓ 已读状态）。
 * <p>
 * 已读判定逻辑：msg_time2 <= 对方的 last_read_time2 则为已读。
 * @since 11.x
 */
@property (nonatomic, assign) BOOL readByPartner;

/**
 * 缓存解析后的 VoipRecordMeta 对象（仅 msgType==TM_TYPE_VOIP_RECORD 时有效）。
 * <p>
 * 用于避免对 entity.text 进行破坏性修改后丢失原始通话类型信息。
 * 首次解析 JSON text 后缓存，后续渲染和点击直接读取此属性。
 * 非持久化字段，不会存入 SQLite。
 */
@property (nonatomic, strong) VoipRecordMeta *voipRecordMeta;

//======================================================== 辅助UI显示字段 END


#pragma mark - Initialization

- (instancetype)initWithSenderId:(NSString *)senderId
               senderDisplayName:(NSString *)senderDisplayName
                            date:(NSDate *)date
                            text:(NSString *)text
                       andIsCome:(int)isComMsg;

- (instancetype)initWithSenderId:(NSString *)senderId
               senderDisplayName:(NSString *)senderDisplayName
                            date:(NSDate *)date
                       andIsCome:(int)isComMsg;

#pragma mark - 其它方法

- (BOOL)isMediaMessage;

/** 时间/已读叠在气泡内容右下角（图、语音、短视频）；文件/位置/名片等与文本一样在气泡外下方 */
- (BOOL)rb_showsBubbleTimeStatusInsideBubble;

/**
 * 是否是控制类消息（这主要用于区分普通的聊天消息，用于聊天界面中判定是否可以删除、撤回逻辑时）。
 *
 * @return true表示是，否则不是
 */
- (BOOL)isControl;

/** 是否"我"发出的消息 */
- (BOOL) isOutgoing;

/** 是否"我"发出的消息 */
+ (BOOL) isOutgoing:(NSString *)senderId;

/**
 * 是否是被允许撤回的消息。
 *
 * @return true表示是，否则不是
 */
- (BOOL) isRevokeEnabled;

/**
 * 是否是被允许转发的消息。
 *
 * @return true表示是，否则不是
 */
- (BOOL) isForwardEnabled;

/**
 * 是否是被允许收藏的消息。
 *
 * @return true表示是，否则不是
 */
- (BOOL) isFavoriteEnabled;

/**
 * 是否是被允许引用的消息。
 *
 * @return true表示是，否则不是
 */
- (BOOL) isQuoteEnabled;

- (NSUInteger)messageHash;


#pragma mark - 生成JSQMessage对象的实用方法

+ (JSQMessage *)createChatMsgEntity_OUTGO_TEXT:(NSString *)message withFingerPrint:(NSString *)fingerPrint;
+ (JSQMessage *)createChatMsgEntity_OUTGO_IMAGE:(NSString *)fileName withFingerPrint:(NSString *)fingerPrint;
+ (JSQMessage *)createChatMsgEntity_OUTGO_VOICE:(NSString *)fileName withFingerPrint:(NSString *)fingerPrint;
+ (JSQMessage *)createChatMsgEntity_OUTGO_FILE:(FileMeta *)fileMeta withFingerPrint:(NSString *)fingerPrint;
+ (JSQMessage *)createChatMsgEntity_OUTGO_SHORTVIDEO:(FileMeta *)fileMeta withFingerPrint:(NSString *)fingerPrint;
+ (JSQMessage *)createChatMsgEntity_OUTGO_CONTACT:(ContactMeta *)contactMeta withFingerPrint:(NSString *)fingerPrint;
+ (JSQMessage *)createChatMsgEntity_OUTGO_LOCATION:(LocationMeta *)locationMeta withFingerPrint:(NSString *)fingerPrint;

/** 发出红包/转账等 ty=10 或 11 的聊天消息（m 为 JSON 字符串） */
+ (JSQMessage *)createChatMsgEntity_OUTGO_JSONContent:(NSString *)jsonContent msgType:(int)msgType withFingerPrint:(NSString *)fingerPrint;

+ (JSQMessage *)createChatMsgEntity_INCOME_TEXT:(NSString *)nickName withContent:(NSString *)message andTime:(NSDate *)time senderId:(NSString *)fid;
+ (JSQMessage *)createChatMsgEntity_INCOME_IMAGE:(NSString *)nickName withContent:(NSString *)fileName andTime:(NSDate *)time senderId:(NSString *)fid;
+ (JSQMessage *)createChatMsgEntity_INCOME_VOICE:(NSString *)nickName withContent:(NSString *)fileName andTime:(NSDate *)time senderId:(NSString *)fid;
+ (JSQMessage *)createChatMsgEntity_INCOME_FILE:(NSString *)nickName withContent:(FileMeta *)fileMeta andTime:(NSDate *)time senderId:(NSString *)fid;
+ (JSQMessage *)createChatMsgEntity_INCOME_SHORTVIDEO:(NSString *)nickName withContent:(FileMeta *)fileMeta andTime:(NSDate *)time senderId:(NSString *)fid;
+ (JSQMessage *)createChatMsgEntity_INCOME_CONTACT:(NSString *)nickName withContent:(ContactMeta *)contactMeta andTime:(NSDate *)time senderId:(NSString *)fid;

+ (JSQMessage *)createSystemMsgEntity_TEXT:(NSString *)message andTime:(NSDate *)time senderId:(NSString *)fid;
+ (JSQMessage *)createChatMsgEntity_INCOME_REVOKE:(NSString *)message andTime:(NSDate *)time senderId:(NSString *)fid;

+ (JSQMessage *)createChatMsgEntity_INCOME_VOIPRECORD:(NSString *)nickName withContent:(VoipRecordMeta *)vrm andTime:(NSDate *)time senderId:(NSString *)fid;

+ (JSQMessage *)createChatMsgEntity_OUTGO_VOIPRECORD:(VoipRecordMeta *)vrm;


#pragma mark - “收到”的消息的一些实用方法
/**
 * 尝试从从TextMessage的JSON文本中解析出可以显示给用户看的消息文本.
 *
 * @param messageContent 真正的聊天文本内容（该内容可能是扁平文本（文本聊天消息）、文件（语音留言、图片消息）），是TextMessage中的m内容
 * @return 返回消息文本（仅用于ui显示哦）
 */
+ (NSString *)parseMessageContentPreview:(NSString *)messageContent withType:(int)msgType;

+ (JSQMessage *)prepareChatMessageData_incoming:(NSString *)msg withNickName:(NSString *)nickName andTime:(NSDate *)time andMsgType:(int)msgType senderId:(NSString *)senderId;

/**
 * 被撤回的消息，预览内容显示。
 *
 * @param rm 被撤回消息的内容体对象
 * @return 返回内容预览
 */
+ (NSString *)getMessageContentPreviewForRevoked:(RevokedMeta *)rm;

@end
