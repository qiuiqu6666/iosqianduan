//
//  ChatRootViewController+Sync.h
//  多端增量同步：静默拉取、去重合并。
//

#import "ChatRootViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChatRootViewController (Sync)

/// 静默从服务端拉取最新消息并追加到当前会话（增量同步回调触发）
- (void)silentSyncFromServer;
/// 静默处理服务端返回的聊天记录（去重、追加、智能滚动）
- (void)silentProcessChatHistory:(NSArray *)chatHistoryList wasAtBottom:(BOOL)wasAtBottom;

@end

NS_ASSUME_NONNULL_END
