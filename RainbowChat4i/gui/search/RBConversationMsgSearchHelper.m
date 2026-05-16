//
//  RBConversationMsgSearchHelper.m
//

#import "RBConversationMsgSearchHelper.h"
#import "MsgDetailContentDTO.h"
#import "MsgSummaryContentDTO.h"
#import "TimeTool.h"

/// 文档 v1.2：keyword/q 在 trim 后若全部为字符 `*`（如 `"*"`、`"**"`），服务端不按正文子串过滤，仅会话范围 + 可选 msg_types/时间/发送人。
/// 客户端「无输入关键词」的浏览场景传单个 `*`。
static NSString *const kRBConversationBrowseKeywordSentinel = @"*";

static NSString *RBConvSearchCellStr(id v)
{
    if (v == nil || v == [NSNull null]) {
        return @"";
    }
    if ([v isKindOfClass:[NSString class]]) {
        return (NSString *)v;
    }
    if ([v isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)v stringValue];
    }
    return [v description];
}

@implementation RBConversationMsgSearchHelper

+ (NSMutableDictionary *)buildSearchNewDataWithLuid:(NSString *)luid
                                             chatType:(int)chatType
                                               dataId:(NSString *)dataId
                                                 page:(int)page
                                            pageSize:(int)pageSize
                                              keyword:(NSString *)kwOrNil
                                             msgTypes:(NSArray<NSNumber *> *)msgTypes
                                          startTimeMs:(long long)startTimeMs
                                            endTimeMs:(long long)endTimeMs
                                            senderUid:(NSString *)senderUid
{
    NSMutableDictionary *newData = [NSMutableDictionary dictionary];
    if (luid.length) {
        newData[@"luid"] = luid;
    }
    if (chatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP) {
        newData[@"gid"] = dataId ?: @"";
    } else {
        newData[@"ruid"] = dataId ?: @"";
    }
    newData[@"page"] = [NSString stringWithFormat:@"%d", MAX(1, page)];
    int ps = MAX(1, MIN(50, pageSize));
    newData[@"page_size"] = [NSString stringWithFormat:@"%d", ps];

    NSString *trimSrc = kwOrNil != nil ? kwOrNil : @"";
    NSString *kw = [trimSrc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (kw.length == 0) {
        kw = kRBConversationBrowseKeywordSentinel;
    } else if (kw.length > 120) {
        kw = [kw substringToIndex:120];
    }
    newData[@"keyword"] = kw;
    newData[@"q"] = kw;

    if (msgTypes.count > 0) {
        newData[@"msg_types"] = msgTypes;
    }
    if (startTimeMs > 0) {
        newData[@"start_time2"] = @(startTimeMs);
    }
    if (endTimeMs > 0) {
        newData[@"end_time2"] = @(endTimeMs);
    }
    if (senderUid.length > 0) {
        newData[@"sender_uid"] = senderUid;
        newData[@"src_uid"] = senderUid;
    }
    return newData;
}

+ (MsgDetailContentDTO *)detailDTOFromSearchRow:(NSArray *)row
                                       chatType:(int)chatType
                                         dataId:(NSString *)dataId
{
    if (row == nil) {
        return nil;
    }
    MsgDetailContentDTO *cp = [[MsgDetailContentDTO alloc] init];
    cp.chatType = chatType;
    cp.dataId = dataId ?: @"";
    cp.resultCount = 1;
    cp.senderId = RBConvSearchCellStr(row.count > 1 ? row[1] : nil);
    cp.senderDisplayName = row.count > 17 ? RBConvSearchCellStr(row[17]) : @"";
    cp.msgType = [RBConvSearchCellStr(row.count > 4 ? row[4] : nil) intValue];
    cp.text = RBConvSearchCellStr(row.count > 5 ? row[5] : nil);
    cp.date = [TimeTool convertJavaTimestampToiOSDate:RBConvSearchCellStr(row.count > 6 ? row[6] : @"0")];
    cp.fp = RBConvSearchCellStr(row.count > 7 ? row[7] : nil);
    return cp;
}

+ (NSMutableArray<MsgDetailContentDTO *> *)detailDTOsFromSearchMessages:(NSArray *)messages
                                                               chatType:(int)chatType
                                                                 dataId:(NSString *)dataId
{
    NSMutableArray<MsgDetailContentDTO *> *out = [NSMutableArray array];
    if (![messages isKindOfClass:[NSArray class]]) {
        return out;
    }
    for (id rowObj in messages) {
        if (![rowObj isKindOfClass:[NSArray class]]) {
            continue;
        }
        MsgDetailContentDTO *dto = [self detailDTOFromSearchRow:(NSArray *)rowObj chatType:chatType dataId:dataId];
        if (dto) {
            [out addObject:dto];
        }
    }
    return out;
}

@end
