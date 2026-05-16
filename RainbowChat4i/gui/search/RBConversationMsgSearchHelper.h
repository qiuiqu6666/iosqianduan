//
//  RBConversationMsgSearchHelper.h
//  RainbowChat4i
//
//  会话内 1008-26-41 搜索请求组装与结果行解析（供「查找聊天内容」各 Tab 复用）。
//  与服务端约定对齐见 network 文档：《聊天记录搜索 HTTP 前端对接说明》v1.2（keyword/q 全为 * 表示不按正文过滤）。
//

#import <Foundation/Foundation.h>

@class MsgDetailContentDTO;

NS_ASSUME_NONNULL_BEGIN

@interface RBConversationMsgSearchHelper : NSObject

/// 组装 newData。若 keyword 为空（含仅空白）则传单个 `*`（文档：trim 后全为 `*` 不按 msg_content 子串过滤，仅会话 + 可选 msg_types/时间/发送人）。
/// 同时写入 keyword 与 q；page_size 限制 1～50。
+ (NSMutableDictionary *)buildSearchNewDataWithLuid:(NSString *)luid
                                             chatType:(int)chatType
                                               dataId:(NSString *)dataId
                                                 page:(int)page
                                            pageSize:(int)pageSize
                                              keyword:(nullable NSString *)kwOrNil
                                             msgTypes:(nullable NSArray<NSNumber *> *)msgTypes
                                          startTimeMs:(long long)startTimeMs
                                            endTimeMs:(long long)endTimeMs
                                            senderUid:(nullable NSString *)senderUid;

/// 将 messages 单行转为 MsgDetailContentDTO；列顺序同文档 §六（0=collect_id，1=src_uid，…，17=nickname）。
+ (nullable MsgDetailContentDTO *)detailDTOFromSearchRow:(NSArray *)row
                                                  chatType:(int)chatType
                                                    dataId:(NSString *)dataId;

/// 批量转换。
+ (NSMutableArray<MsgDetailContentDTO *> *)detailDTOsFromSearchMessages:(NSArray *)messages
                                                               chatType:(int)chatType
                                                                 dataId:(NSString *)dataId;

@end

NS_ASSUME_NONNULL_END
