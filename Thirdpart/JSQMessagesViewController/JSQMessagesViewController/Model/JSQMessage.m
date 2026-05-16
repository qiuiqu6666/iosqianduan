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

#import "JSQMessage.h"
#import "ReceivedFileHelper.h"
#import "FileMeta.h"
#import "EVAToolKits.h"
#import "ContactMeta.h"
#import "IMClientManager.h"
#import "VoipRecordMeta.h"


@implementation JSQMessage

#pragma mark - Initialization

- (instancetype)initWithSenderId:(NSString *)senderId
               senderDisplayName:(NSString *)senderDisplayName
                            date:(NSDate *)date
                            text:(NSString *)text
                       andIsCome:(int)isComMsg
{
    // 服务端/同步路径可能传入 nil，JSQMessages 原实现会 NSParameterAssert 崩溃；统一用空串兜底
    NSString *safeText = text ?: @"";

    self = [self initWithSenderId:senderId senderDisplayName:senderDisplayName date:date andIsCome:isComMsg];
    if (self) {
        _text = [safeText copy];
        _forwardOutgoing = NO;
    }
    return self;
}

- (instancetype)initWithSenderId:(NSString *)senderId
               senderDisplayName:(NSString *)senderDisplayName
                            date:(NSDate *)date
//                         isMedia:(BOOL)isMedia
                       andIsCome:(int)isComMsg
{
    // 与 initWithSenderId:...text: 一致：服务端/同步/红包分支等可能传入 nil，原 NSParameterAssert 会直接闪退
    NSString *safeSenderId = senderId ?: @"";
    NSString *safeSenderDisplayName = senderDisplayName ?: @"";
    NSDate *safeDate = date ?: [NSDate date];

    self = [super init];
    if (self) {
        // 基本属性初始化
//        self.isComMeg = MsgType_TO_TEXT;
        _sendStatus = SendStatus_SNEDING;
        _sendStatusSecondary = SendStatusSecondary_NONE;
        _sendStatusSecondaryProgress = 0;

        _senderId = [safeSenderId copy];
        _senderDisplayName = [safeSenderDisplayName copy];
        _date = [safeDate copy];
//        _isMediaMessage = isMedia;

        _msgType = isComMsg;
        _showTopTime = NO;
        _highlightOnce = NO;
    }
    return self;
}

- (BOOL)isMediaMessage
{
    //## Bug Fix 250904: 由于界面上需要判断如果不是媒体消息就用文本消息形式显示，但以下判断如果没有包含不支
    //                   持的消息类型就会错误地判定为媒体消息，进而在ui显示时因没有mediaView而导致app崩溃。
//    return _msgType != TM_TYPE_TEXT
//    && _msgType != TM_TYPE_SYSTEAM_INFO
//    && _msgType != TM_TYPE_REVOKE
//    && _msgType != TM_TYPE_VOIP_RECORD
//    && _msgType != TM_TYPE_GIFT_SEND
//    && _msgType != TM_TYPE_GIFT_GET;
    
    // 注意：如果有新增的媒体消息时，记得在此处新增对应的消息类型判断！
    return _msgType == TM_TYPE_IMAGE
        || _msgType == TM_TYPE_VOICE
        || _msgType == TM_TYPE_FILE
        || _msgType == TM_TYPE_SHORTVIDEO
        || _msgType == TM_TYPE_CONTACT
        || _msgType == TM_TYPE_LOCATION;
}

- (BOOL)isControl
{
    return _msgType == TM_TYPE_SYSTEAM_INFO || _msgType == TM_TYPE_REVOKE;
}

// 是否"我"发出的消息
- (BOOL) isOutgoing
{
    return [JSQMessage isOutgoing:self.senderId];
}

/** 是否"我"发出的消息 */
+ (BOOL) isOutgoing:(NSString *)senderId
{
    if (senderId.length == 0) {
        return NO;
    }
    NSString *localUserId = [[ClientCoreSDK sharedInstance] currentLoginUserId];
    if (localUserId.length > 0 && [localUserId isEqualToString:senderId]) {
        return YES;
    }
    NSString *imu = [[IMClientManager sharedInstance].localUserInfo user_uid];
    if (imu.length > 0 && [imu isEqualToString:senderId]) {
        return YES;
    }
    return NO;
}

// 是否是被允许撤回的消息
- (BOOL) isRevokeEnabled
{
    // 必须是发出的消息且正常发送完成的消息才允许被撤回
    return ![self isControl] && [self isOutgoing] && self.sendStatus == SendStatus_BE_RECEIVED;
}

// 是否是被允许转发的消息（转账、音视频、红包不允许被转发）
- (BOOL) isForwardEnabled
{
    return ![self isControl] && self.msgType != TM_TYPE_VOIP_RECORD
            && self.msgType != TM_TYPE_RED_PACKET
            && self.msgType != TM_TYPE_TRANSFER
            // 发出的消息时，必须是正常发送完成的消息才允许转发
            && ((self.sendStatus == SendStatus_BE_RECEIVED && [self isOutgoing]) || ![self isOutgoing]);
}

// 是否是被允许收藏的消息（转账、音视频、红包不允许被收藏）
- (BOOL) isFavoriteEnabled
{
    return [self isForwardEnabled];
}

// 是否是被允许引用的消息
- (BOOL) isQuoteEnabled
{
    return [self isForwardEnabled];
}

- (NSUInteger)messageHash
{
    return self.hash;
}


#pragma mark - NSObject

- (NSUInteger)hash
{
    NSUInteger contentHash = self.isMediaMessage ? [self.media mediaHash] : self.text.hash;
    return self.senderId.hash ^ self.date.hash ^ contentHash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: senderId=%@, senderDisplayName=%@, date=%@, isMediaMessage=%@, text=%@, media=%@, fingerPringOfProtocal=%@, fingerPrintOfParent=%@>",
            [self class], self.senderId, self.senderDisplayName, self.date, @(self.isMediaMessage), self.text, self.media, self.fingerPrintOfProtocal, self.fingerPrintOfParent];
}

- (id)debugQuickLookObject
{
    return [self.media mediaView] ?: [self.media mediaPlaceholderView];
}


//-------------------------------------------------------------------------------------------
#pragma mark - 生成JSQMessage对象的实用方法

+ (JSQMessage *)createChatMsgEntity_OUTGO_TEXT:(NSString *)message withFingerPrint:(NSString *)fingerPrint
{
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:[[ClientCoreSDK sharedInstance] currentLoginUserId] senderDisplayName:@"我" date:[TimeTool getIOSDefaultDate] text:message andIsCome:TM_TYPE_TEXT];

    cme.fingerPrintOfProtocal = fingerPrint;
    return cme;
}
+ (JSQMessage *)createChatMsgEntity_OUTGO_IMAGE:(NSString *)fileName withFingerPrint:(NSString *)fingerPrint
{
    // 当是图片消息时，message里存放的就是图片所存放于服务端的文件名（原图而非缩略图的文件名哦）
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:[[ClientCoreSDK sharedInstance] currentLoginUserId] senderDisplayName:@"我" date:[TimeTool getIOSDefaultDate] text:fileName andIsCome:TM_TYPE_IMAGE];
    cme.sendStatusSecondary = SendStatusSecondary_PENDING;

    cme.fingerPrintOfProtocal = fingerPrint;
    return cme;
}
+ (JSQMessage *)createChatMsgEntity_OUTGO_VOICE:(NSString *)fileName withFingerPrint:(NSString *)fingerPrint
{
    // 当是语音留言消息时，message里存放的就是语音留言所存放于服务端的文件名（原图而非缩略图的文件名哦）
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:[[ClientCoreSDK sharedInstance] currentLoginUserId] senderDisplayName:@"我" date:[TimeTool getIOSDefaultDate] text:fileName andIsCome:TM_TYPE_VOICE];
    cme.sendStatusSecondary = SendStatusSecondary_PENDING;

    cme.fingerPrintOfProtocal = fingerPrint;
    return cme;
}
+ (JSQMessage *)createChatMsgEntity_OUTGO_FILE:(FileMeta *)fileMeta withFingerPrint:(NSString *)fingerPrint
{
//  FileMeta *fileMeta = [FileMeta initWith:fileName fileMd5:fileMd5 fileLength:fileLength];
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:[[ClientCoreSDK sharedInstance] currentLoginUserId] senderDisplayName:@"我" date:[TimeTool getIOSDefaultDate] text:[EVAToolKits toJSON:fileMeta] andIsCome:TM_TYPE_FILE];
    cme.sendStatusSecondary = SendStatusSecondary_PENDING;

    cme.fingerPrintOfProtocal = fingerPrint;
    return cme;
}
+ (JSQMessage *)createChatMsgEntity_OUTGO_SHORTVIDEO:(FileMeta *)fileMeta withFingerPrint:(NSString *)fingerPrint
{
//  FileMeta *fileMeta = [FileMeta initWith:fileName fileMd5:fileMd5 fileLength:fileLength];
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:[[ClientCoreSDK sharedInstance] currentLoginUserId] senderDisplayName:@"我" date:[TimeTool getIOSDefaultDate] text:[EVAToolKits toJSON:fileMeta] andIsCome:TM_TYPE_SHORTVIDEO];
    cme.sendStatusSecondary = SendStatusSecondary_PENDING;

    cme.fingerPrintOfProtocal = fingerPrint;
    return cme;
}
+ (JSQMessage *)createChatMsgEntity_OUTGO_CONTACT:(ContactMeta *)contactMeta withFingerPrint:(NSString *)fingerPrint
{
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:[[ClientCoreSDK sharedInstance] currentLoginUserId] senderDisplayName:@"我" date:[TimeTool getIOSDefaultDate] text:[EVAToolKits toJSON:contactMeta] andIsCome:TM_TYPE_CONTACT];

    cme.fingerPrintOfProtocal = fingerPrint;
    return cme;
}
+ (JSQMessage *)createChatMsgEntity_OUTGO_LOCATION:(LocationMeta *)locationMeta withFingerPrint:(NSString *)fingerPrint
{
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:[[ClientCoreSDK sharedInstance] currentLoginUserId] senderDisplayName:@"我" date:[TimeTool getIOSDefaultDate] text:[EVAToolKits toJSON:locationMeta] andIsCome:TM_TYPE_LOCATION];

    cme.fingerPrintOfProtocal = fingerPrint;
    return cme;
}

+ (JSQMessage *)createChatMsgEntity_OUTGO_JSONContent:(NSString *)jsonContent msgType:(int)msgType withFingerPrint:(NSString *)fingerPrint
{
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:[[ClientCoreSDK sharedInstance] currentLoginUserId] senderDisplayName:@"我" date:[TimeTool getIOSDefaultDate] text:(jsonContent ?: @"") andIsCome:msgType];
    cme.fingerPrintOfProtocal = fingerPrint;
    return cme;
}

+ (JSQMessage *)createChatMsgEntity_INCOME_TEXT:(NSString *)nickName withContent:(NSString *)message andTime:(NSDate *)time senderId:(NSString *)fid
{
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:fid senderDisplayName:nickName date:(time == nil?[TimeTool getIOSDefaultDate]:time) text:message andIsCome:TM_TYPE_TEXT];
    return cme;
}

+ (JSQMessage *)createChatMsgEntity_INCOME_IMAGE:(NSString *)nickName withContent:(NSString *)fileName andTime:(NSDate *)time senderId:(NSString *)fid
{
    // 当是图片消息时，message里存放的就是图片所存放于服务端的文件名（原图而非缩略图的文件名哦）
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:fid senderDisplayName:nickName date:(time == nil?[TimeTool getIOSDefaultDate]:time) text:fileName andIsCome:TM_TYPE_IMAGE];
    return cme;
}

+ (JSQMessage *)createChatMsgEntity_INCOME_VOICE:(NSString *)nickName withContent:(NSString *)fileName andTime:(NSDate *)time senderId:(NSString *)fid
{
    // 当是图片消息时，message里存放的就是语音留言所存放于服务端的文件名
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:fid senderDisplayName:nickName date:(time == nil?[TimeTool getIOSDefaultDate]:time) text:fileName andIsCome:TM_TYPE_VOICE];
    return cme;
}

+ (JSQMessage *)createChatMsgEntity_INCOME_FILE:(NSString *)nickName withContent:(FileMeta *)fileMeta andTime:(NSDate *)time senderId:(NSString *)fid
{
//    FileMeta *fileMeta = [FileMeta initWith:fileName fileMd5:fileMd5 fileLength:fileLength];
    // 当是文件消息时，message里存放的就是ComeFileMeta对象
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:fid senderDisplayName:nickName date:(time == nil?[TimeTool getIOSDefaultDate]:time) text:[EVAToolKits toJSON:fileMeta] andIsCome:TM_TYPE_FILE];
    return cme;
}

+ (JSQMessage *)createChatMsgEntity_INCOME_SHORTVIDEO:(NSString *)nickName withContent:(FileMeta *)fileMeta andTime:(NSDate *)time senderId:(NSString *)fid
{
//    FileMeta *fileMeta = [FileMeta initWith:fileName fileMd5:fileMd5 fileLength:fileLength];
    // 当是文件消息时，message里存放的就是FileMeta对象
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:fid senderDisplayName:nickName date:(time == nil?[TimeTool getIOSDefaultDate]:time) text:[EVAToolKits toJSON:fileMeta] andIsCome:TM_TYPE_SHORTVIDEO];
    return cme;
}

+ (JSQMessage *)createChatMsgEntity_INCOME_CONTACT:(NSString *)nickName withContent:(ContactMeta *)contactMeta andTime:(NSDate *)time senderId:(NSString *)fid
{
    // 当是文件消息时，message里存放的就是ContactMeta对象
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:fid senderDisplayName:nickName date:(time == nil?[TimeTool getIOSDefaultDate]:time) text:[EVAToolKits toJSON:contactMeta] andIsCome:TM_TYPE_CONTACT];
    return cme;
}

+ (JSQMessage *)createChatMsgEntity_INCOME_LOCATION:(NSString *)nickName withContent:(LocationMeta *)locationMeta andTime:(NSDate *)time senderId:(NSString *)fid
{
    // 当是位置消息时，message里存放的就是LocationMeta对象
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:fid senderDisplayName:nickName date:(time == nil?[TimeTool getIOSDefaultDate]:time) text:[EVAToolKits toJSON:locationMeta] andIsCome:TM_TYPE_LOCATION];
    return cme;
}

+ (JSQMessage *)createSystemMsgEntity_TEXT:(NSString *)message andTime:(NSDate *)time senderId:(NSString *)fid
{
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:fid senderDisplayName:@"" date:(time == nil?[TimeTool getIOSDefaultDate]:time) text:message andIsCome:TM_TYPE_SYSTEAM_INFO];
    return cme;
}

+ (JSQMessage *)createChatMsgEntity_INCOME_REVOKE:(NSString *)message andTime:(NSDate *)time senderId:(NSString *)fid
{
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:fid senderDisplayName:@"" date:(time == nil?[TimeTool getIOSDefaultDate]:time) text:message andIsCome:TM_TYPE_REVOKE];
    return cme;
}

+ (JSQMessage *)createChatMsgEntity_INCOME_VOIPRECORD:(NSString *)nickName withContent:(VoipRecordMeta *)vrm andTime:(NSDate *)time senderId:(NSString *)fid
{
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:fid senderDisplayName:nickName date:(time == nil?[TimeTool getIOSDefaultDate]:time) text:[EVAToolKits toJSON:vrm] andIsCome:TM_TYPE_VOIP_RECORD];
    cme.voipRecordMeta = vrm; // 缓存解析后的 VoipRecordMeta，避免后续依赖 text 解析
    return cme;
}

+ (JSQMessage *)createChatMsgEntity_OUTGO_VOIPRECORD:(VoipRecordMeta *)vrm
{
    JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:[[ClientCoreSDK sharedInstance] currentLoginUserId] senderDisplayName:@"我" date:[TimeTool getIOSDefaultDate] text:[EVAToolKits toJSON:vrm] andIsCome:TM_TYPE_VOIP_RECORD];
    cme.voipRecordMeta = vrm; // 缓存解析后的 VoipRecordMeta，避免后续依赖 text 解析
    // 通话记录不需要发送到服务器，标记为已接收
    cme.sendStatus = SendStatus_BE_RECEIVED;
    return cme;
}


//-------------------------------------------------------------------------------------------
#pragma mark - “收到”的消息的一些实用方法

// 仅通过 content 判断是否为红包 JSON（消息列表等预览用，与 ChatRootViewController 逻辑一致）
static BOOL _isRedPacketPreviewContent(NSString *text) {
    if (!text || text.length == 0 || ![text hasPrefix:@"{"]) return NO;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return NO;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![obj isKindOfClass:[NSDictionary class]]) return NO;
    id pid = [(NSDictionary *)obj objectForKey:@"packet_id"];
    return (pid != nil && ![pid isKindOfClass:[NSNull class]]);
}
// 仅通过 content 判断是否为转账 JSON（如 {"amount":"11.00","to_uid":"400204","remark":""}）
static BOOL _isTransferPreviewContent(NSString *text) {
    if (!text || text.length == 0 || ![text hasPrefix:@"{"]) return NO;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return NO;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![obj isKindOfClass:[NSDictionary class]]) return NO;
    id amt = [(NSDictionary *)obj objectForKey:@"amount"];
    return (amt != nil && ![amt isKindOfClass:[NSNull class]]);
}

+ (NSString *)parseMessageContentPreview:(NSString *)messageContent withType:(int)msgType
{
    if(messageContent == nil)
        return @"";

    // 自kchat2.2(20140212)后，此字段将用于消息内容的显示
    NSString *messageContentForShow = @"";

    switch(msgType)
    {
        case TM_TYPE_IMAGE:
            messageContentForShow = @"[图片]";
            break;
        case TM_TYPE_VOICE:
        {
            messageContentForShow = @"[语音]";
            NSString *voiceFileName = messageContent;
            if (voiceFileName != nil) {
                // 从文件名中解析出语音时长（单位：秒）
                int duration = [TimeTool getDurationFromVoiceFileName:voiceFileName];
                if(duration > 0) {
                    // 显示语音时长
                    messageContentForShow = [NSString stringWithFormat:@"%@ %d''", messageContentForShow, duration];
                }
            }
            break;
        }
        case TM_TYPE_GIFT_SEND:
            messageContentForShow = @"[收到礼物]";
            break;
        case TM_TYPE_GIFT_GET:
            messageContentForShow = @"[能送我个礼物吗？]";
            break;
        case TM_TYPE_FILE:
        {
            // 文件消息的内容体是FileMeta对象的JSON形式
            FileMeta *fm = [FileMeta fromJSON:messageContent];
            messageContentForShow = [NSString stringWithFormat:@"[文件]%@", (fm != nil?[NSString stringWithFormat:@" %@", fm.fileName]:@"")];
            break;
        }
        case TM_TYPE_SHORTVIDEO:
            messageContentForShow = @"[短视频]";
            break;
        case TM_TYPE_CONTACT:
        {
            // 名片消息的内容体是ContactMeta对象的JSON形式
            ContactMeta *cm = [ContactMeta fromJSON:messageContent];
            messageContentForShow = (cm.type == CONTACT_TYPE_USER ? @"[个人名片]" : @"[群名片]");
            break;
        }
        case TM_TYPE_LOCATION:
        {
            // 位置消息的内容体是LocationMeta对象的JSON形式
            LocationMeta *lm = [LocationMeta fromJSON:messageContent];
            NSString *extra = ([BasicTool isStringEmpty:lm.locationTitle]?@"":lm.locationTitle);
            messageContentForShow = [NSString stringWithFormat:@"[位置]%@", extra];
            break;
        }
        case TM_TYPE_REVOKE:
        {
            // 位置消息的内容体是LocationMeta对象的JSON形式
            RevokedMeta *rm = [RevokedMeta fromJSON:messageContent];
            messageContentForShow = [JSQMessage getMessageContentPreviewForRevoked:rm];
            break;
        }
        case TM_TYPE_RED_PACKET:
            messageContentForShow = @"[红包]";
            break;
        case TM_TYPE_TRANSFER:
            messageContentForShow = @"[转账]";
            break;
        case TM_TYPE_VOIP_RECORD:
        {
            // 实时音视频聊天记录消息（对接文档 v1.0）
            VoipRecordMeta *vrm = [VoipRecordMeta fromJSON:messageContent];
            NSString *typeStr = (vrm.voipType == VOIP_TYPE_VIDEO) ? @"视频通话" : @"语音通话";
            NSString *content = nil;
            switch (vrm.recordType) {
                case VOIP_RECORD_TYPE_REQUEST_CANCEL:
                    content = [NSString stringWithFormat:@"已取消%@", typeStr];
                    break;
                case VOIP_RECORD_TYPE_REQUEST_REJECT:
                    content = [NSString stringWithFormat:@"已拒绝%@", typeStr];
                    break;
                case VOIP_RECORD_TYPE_CALLING_TIMEOUT:
                    content = [NSString stringWithFormat:@"对方无应答（%@）", typeStr];
                    break;
                case VOIP_RECORD_TYPE_CHATTING_DURATION:
                    content = vrm.duration > 0
                        ? [NSString stringWithFormat:@"%@ %@", typeStr, [TimeTool getVoipDurationFromSS:vrm.duration]]
                        : [NSString stringWithFormat:@"%@ 00:00", typeStr];
                    break;
                default:
                    content = typeStr;
                    break;
            }
            messageContentForShow = content ?: typeStr;
            break;
        }
        default:
            // msg_type 为 0 或其它时，按 content 兜底：红包/转账 JSON 在消息列表中显示 [红包]/[转账] 而非原始 JSON
            if (_isRedPacketPreviewContent(messageContent)) {
                messageContentForShow = @"[红包]";
            } else if (_isTransferPreviewContent(messageContent)) {
                messageContentForShow = @"[转账]";
            } else {
                messageContentForShow = messageContent;
            }
            break;
    }

    return messageContentForShow;
}

+ (JSQMessage *)prepareChatMessageData_incoming:(NSString *)msg withNickName:(NSString *)nickName
                                  andTime:(NSDate *)time andMsgType:(int)msgType senderId:(NSString *)senderId
{
    switch(msgType)
    {
        case TM_TYPE_IMAGE:
            return [JSQMessage createChatMsgEntity_INCOME_IMAGE:nickName withContent:msg andTime:time senderId:senderId];
        case TM_TYPE_VOICE:
            return [JSQMessage createChatMsgEntity_INCOME_VOICE:nickName withContent:msg andTime:time senderId:senderId];
        case TM_TYPE_FILE:
        {
            // 文件消息的内容体是FileMeta对象的JSON形式
            FileMeta *fm = [FileMeta fromJSON:msg];
            return [JSQMessage createChatMsgEntity_INCOME_FILE:nickName withContent:fm andTime:time senderId:senderId];
        }
        case TM_TYPE_SHORTVIDEO:
        {
            // 短视频消息的内容体是FileMeta对象的JSON形式
            FileMeta *fm = [FileMeta fromJSON:msg];
            return [JSQMessage createChatMsgEntity_INCOME_SHORTVIDEO:nickName withContent:fm andTime:time senderId:senderId];
        }
        case TM_TYPE_CONTACT:
        {
            // 名片消息的内容体是ContactMeta对象的JSON形式
            ContactMeta *cm = [ContactMeta fromJSON:msg];
            return [JSQMessage createChatMsgEntity_INCOME_CONTACT:nickName withContent:cm andTime:time senderId:senderId];
        }
        case TM_TYPE_LOCATION:
        {
            // 位置消息的内容体是LocationMeta对象的JSON形式
            LocationMeta *lm = [LocationMeta fromJSON:msg];
            return [JSQMessage createChatMsgEntity_INCOME_LOCATION:nickName withContent:lm andTime:time senderId:senderId];
        }
        case TM_TYPE_SYSTEAM_INFO:
            return [JSQMessage createSystemMsgEntity_TEXT:msg andTime:time senderId:senderId];
        case TM_TYPE_REVOKE:
            return [JSQMessage createChatMsgEntity_INCOME_REVOKE:msg andTime:time senderId:senderId];
        case TM_TYPE_VOIP_RECORD:
        {
            // 位置消息的内容体是VoipRecordMeta对象的JSON形式
            VoipRecordMeta *vrm = [VoipRecordMeta fromJSON:msg];
            return [JSQMessage createChatMsgEntity_INCOME_VOIPRECORD:nickName withContent:vrm andTime:time senderId:senderId];
        }
        case TM_TYPE_RED_PACKET:
        case TM_TYPE_TRANSFER:
        {
            JSQMessage *cme = [[JSQMessage alloc] initWithSenderId:senderId senderDisplayName:nickName date:(time == nil ? [TimeTool getIOSDefaultDate] : time) text:msg andIsCome:msgType];
            return cme;
        }
        default:
            return [JSQMessage createChatMsgEntity_INCOME_TEXT:nickName withContent:msg andTime:time senderId:senderId];
    }
}

// 被撤回的消息，预览内容显示
+ (NSString *)getMessageContentPreviewForRevoked:(RevokedMeta *)rm
{
    NSString *ret = @"撤回了一条消息";
    if(rm != nil){
        NSString *uidForOperator = rm.uid;
        NSString *nickeNameForOperator = rm.nickName;
        
        // 被"撤回"者的uid（当前用于群聊时，由管理员撤回其它群员消息时存入被撤回消息的发送者uid，其它余情况下本参数为空！）
        NSString *beUid = rm.beUid;
        // 被"撤回"者的昵称（当前用于群聊时，由管理员撤回其它群员消息时存入被撤回消息的发送者uid，其它余情况下本参数为空！）
        NSString *beNickname = rm.beNickName;
        
        UserEntity *localRee = [[IMClientManager sharedInstance] localUserInfo];
        
        NSString *revokedOperatorNick = @"";
        NSString *beRevokesOperatorNick = @"";
        
        // 撤回者昵称显示内容（判断是否为空时尽量使用isStringEmpty方法，因ios端JSON库的逻辑，Web传过来的null字段可能不会被解析成nil而是NSNull对象）
        if(localRee != nil && ![BasicTool isStringEmpty:uidForOperator] && [uidForOperator isEqualToString:localRee.user_uid]){
            revokedOperatorNick = @"你";
        }
        else{
            revokedOperatorNick = [NSString stringWithFormat:@"\"%@\" ", nickeNameForOperator];
        }
        
        // 被撤回者昵称显示内容（判断是否为空时尽量使用isStringEmpty方法，因ios端JSON库的逻辑，Web传过来的null字段可能不会被解析成nil而是NSNull对象）
        if(![BasicTool isStringEmpty:beUid]){
            if(![BasicTool isStringEmpty:uidForOperator] && ![beUid isEqualToString:uidForOperator]) {
                if(localRee != nil && [beUid isEqualToString:localRee.user_uid])
                    beRevokesOperatorNick= @"你的";
                else
                    beRevokesOperatorNick = [NSString stringWithFormat:@" \"%@\" 的", beNickname];
            }
            else
                beRevokesOperatorNick = @"";
        }
        else {
            beRevokesOperatorNick = @"";
        }
        
        // 注意：同一条撤回提示，在不同的人看到时，显示的结果是一样的：
        // (通过上述逻辑之后，组合成的结果有以下5种可能)
        //   1）" 你撤回了一条消息 "            （单聊或群聊时）
        //   2）" "李四"撤回了一条消息 "        （单聊或群聊时）
        //   3）" 你撤回了"张三"的一条消息 "     （群聊时）
        //   4）" "李四"撤回了你的一条消息 "     （群聊时）
        //   5）" "李四"撤回了"张三"的一条消息 " （群聊时）
        ret = [NSString stringWithFormat:@"%@撤回了%@一条消息", revokedOperatorNick, beRevokesOperatorNick];
    }
    
    return ret;
}

@end
