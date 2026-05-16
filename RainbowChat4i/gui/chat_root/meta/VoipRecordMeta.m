//telegram @wz662
//
//  VoipRecordMeta.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2023/10/12.
//  Copyright © 2023 JackJiang. All rights reserved.
//

#import "VoipRecordMeta.h"
#import "EVAToolKits.h"

@implementation VoipRecordMeta

- (id)init {
    if(self = [super init]) {
        // 默认语音；JSON 无 voipType 时会保留此默认，避免全部显示成视频
        self.voipType = VOIP_TYPE_VOICE;
        self.recordType = VOIP_RECORD_TYPE_CHATTING_DURATION;
        self.duration = 0;
    }
    return self;
}

+ (VoipRecordMeta *)initWith:(int)voipType recordType:(int)recordType {
    return [VoipRecordMeta initWith:voipType recordType:recordType duration:0];
}

+ (VoipRecordMeta *)initWith:(int)voipType recordType:(int)recordType duration:(int)duration {
    VoipRecordMeta *cm = [[VoipRecordMeta alloc] init];
    cm.voipType = voipType;
    cm.recordType = recordType;
    cm.duration = duration;
    return cm;
}

+ (VoipRecordMeta *)fromJSON:(NSString *)jsonOfContactMeta {
    if (jsonOfContactMeta == nil || jsonOfContactMeta.length == 0) return nil;
    VoipRecordMeta *meta = [EVAToolKits fromJSON:jsonOfContactMeta withClazz:VoipRecordMeta.class];
    if (meta == nil) return nil;
    // 兼容服务端或其它端使用 "type":"voice|video" 而非 "voipType" 的 JSON，确保语音/视频显示正确
    NSData *data = [jsonOfContactMeta dataUsingEncoding:NSUTF8StringEncoding];
    if (data) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([d isKindOfClass:[NSDictionary class]]) {
            NSString *typeStr = d[@"type"];
            if ([typeStr isKindOfClass:[NSString class]] && [typeStr isEqualToString:@"video"]) {
                meta.voipType = VOIP_TYPE_VIDEO;
            }
        }
    }
    return meta;
}

/// 解析服务端离线取消兜底格式：{"type":"voice|video","status":"cancelled","caller":"...","callee":"...","duration":0}，用于与客户端简版合并展示
+ (VoipRecordMeta *)fromServerCancelledJSON:(NSString *)json
{
    if (!json || json.length == 0) return nil;
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return nil;
    NSDictionary *d = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    NSString *type = d[@"type"];
    NSString *status = d[@"status"];
    if (![status isEqualToString:@"cancelled"]) return nil;
    int voipType = VOIP_TYPE_VOICE;
    if ([type isEqualToString:@"video"]) voipType = VOIP_TYPE_VIDEO;
    NSNumber *dur = d[@"duration"];
    int duration = dur ? [dur intValue] : 0;
    return [VoipRecordMeta initWith:voipType recordType:VOIP_RECORD_TYPE_REQUEST_CANCEL duration:duration];
}

@end
