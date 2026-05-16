//telegram @wz662
//
//  VoipRecordMeta.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2023/10/12.
//  Copyright © 2023 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>

/** 实时语音聊天 */
#define VOIP_TYPE_VOICE                    0
/** 实时视频聊天 */
#define VOIP_TYPE_VIDEO                    1

/** 记录类型：取消了呼叫 */
#define VOIP_RECORD_TYPE_REQUEST_CANCEL    0
/** 记录类型：拒绝了呼叫 */
#define VOIP_RECORD_TYPE_REQUEST_REJECT    1
/** 记录类型：呼叫超时 */
#define VOIP_RECORD_TYPE_CALLING_TIMEOUT   2
/** 记录类型：通话记录（通话时长） */
#define VOIP_RECORD_TYPE_CHATTING_DURATION 3


@interface VoipRecordMeta : NSObject

/** 聊天类型 */
@property (nonatomic, assign) int voipType;
/** 记录类型 */
@property (nonatomic, assign) int recordType;
/** 通话时长（单位：秒），本字段仅在 recordType 为{@link VOIP_TYPE_CHATTING_DURATION} 时有效 */
@property (nonatomic, assign) int duration;

+ (VoipRecordMeta *)initWith:(int)voipType recordType:(int)recordType;
+ (VoipRecordMeta *)initWith:(int)voipType recordType:(int)recordType duration:(int)duration;
+ (VoipRecordMeta *)fromJSON:(NSString *)jsonOfContactMeta;
/** 解析服务端离线取消兜底 JSON（type/status/caller/callee），用于与客户端简版合并展示 */
+ (VoipRecordMeta *)fromServerCancelledJSON:(NSString *)json;

@end

