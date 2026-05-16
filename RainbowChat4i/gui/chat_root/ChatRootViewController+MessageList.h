//
//  ChatRootViewController+MessageList.h
//  消息列表加载更多、排序与窗口裁剪（仅 SQLite）。
//

#import "ChatRootViewController.h"
#import "NSMutableArrayObservableEx.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChatRootViewController (MessageList)

/// 对当前会话消息列表按时间升序排序
- (void)rb_sortAndTrimMessageList;

/// 若当前会话内存消息条数超过 `CHATTING_MESSAGE_WINDOW_MAX`，按策略裁剪
- (void)rb_trimChattingMemoryWindowIfNeededKeepingOlderMessages:(BOOL)keepingOlderMessages;

/// 下拉加载更多历史（由 refreshControl 触发）
- (void)onLoadMoreHistory;

/// 滚动接近顶部时尝试预取更早历史
- (void)rb_tryPrefetchOlderHistoryForScrollView:(UIScrollView *)scrollView;

/// 加载更多完成回调的安全派发
- (void)completeLoadMoreHistorySafe;

/// 加载更多收尾：排序；reloadData
- (void)completeLoadMoreHistory;

/// 拖拽/惯性滚动结束且已在「最新消息」一侧时：超窗则从数组头部裁最旧
- (void)rb_maybeTrimOldestMemoryWhenViewingLatestAfterScrollEnd:(UIScrollView *)scrollView;

/// 处理顶部手动下拉释放：有历史则触发加载，无历史则提示
- (void)rb_handleOlderHistoryPullReleaseForScrollView:(UIScrollView *)scrollView;

/// 消费待处理的预取请求
- (void)rb_consumePendingPrefetchOlderHistoryIfNeeded;

/// 消费延后的加载完成
- (void)rb_applyDeferredOlderHistoryIfNeeded;

/// 排序当前会话消息（如需要）
- (void)sortCurrentSessionMessagesIfNeeded;

/// 漫游完成后恢复 CollectionView 透明度
- (void)roamingRestoreCollectionViewAlpha;

/// 对指定消息数组按时间升序排序
- (void)sortSomeoneMessagesByDateAscending:(NSMutableArrayObservableEx *)someoneMessages;

@end

NS_ASSUME_NONNULL_END
