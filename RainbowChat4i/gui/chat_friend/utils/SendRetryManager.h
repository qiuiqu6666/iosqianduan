//telegram @wz662
// 单聊文本发送失败后的前端退避重试：1 分钟内按 2s/5s/10s/20s/40s 重试，超 1 分钟标记为失败（红点）
#import <Foundation/Foundation.h>

@class QuoteMeta;

@interface SendRetryManager : NSObject
+ (instancetype)sharedInstance;

/// 开始对单聊文本消息进行退避重试（仅当首次发送失败时调用，消息已以 SNEDING 加入列表）
- (void)startRetryForTextFp:(NSString *)fp toId:(NSString *)toId text:(NSString *)text quoteMeta:(QuoteMeta *)quoteMeta;

/// 仅启动 60 秒超时：发送接口已返回成功但未收到 ack 时用，超时标记失败并显示红点（不触发 2s/5s 重发，避免重复）
- (void)startGiveUpTimerOnlyForTextFp:(NSString *)fp toId:(NSString *)toId;

/// 群聊/大群：退避重试（1s/2s/4s/8s/15s/30s）+ 60s 放弃，网络恢复可尽快发出
- (void)startRetryForGroupFp:(NSString *)fp gid:(NSString *)gid text:(NSString *)text atUsers:(NSArray<NSString *> *)atUsers quoteMeta:(QuoteMeta *)quoteMeta;

/// 群聊/大群：仅启动 60 秒超时（发送接口已返回成功时用），超时未收到 ack 则标记失败并显示红点
- (void)startGiveUpTimerOnlyForGroupFp:(NSString *)fp gid:(NSString *)gid;

/// 收到该 fp 的 ack 时取消重试（单聊/群聊共用）
- (void)cancelRetryForFp:(NSString *)fp;
@end
