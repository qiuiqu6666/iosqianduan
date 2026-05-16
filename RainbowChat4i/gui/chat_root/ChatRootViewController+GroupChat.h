//
//  ChatRootViewController+GroupChat.h
//  群聊（展示分组已关闭，每条独立）、@ 功能、@我 悬浮提示、回到底部按钮。
//

#import "ChatRootViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChatRootViewController (GroupChat)

/// 布局占位：恒为 0（已不再做多人多条合并分组）
- (NSInteger)rb_messageGroupPositionForItemAtIndex:(NSInteger)index;
/// 布局占位：恒等于 index（每条自成一组）
- (NSInteger)rb_groupStartIndexForItemAtIndex:(NSInteger)index;

/// 初始化「有人@我」悬浮提示 UI
- (void)initAtMeHintUI;
/// 初始化「回到底部」浮动按钮
- (void)initScrollToBottomButton;
/// 刷新@我提示显示（主文件 viewDidAppear 等调用）
- (void)refreshAtMeHintVisibility;
/// 根据滚动位置更新回到底部按钮可见性
- (void)updateScrollToBottomButtonVisibility;
/// 从当前消息列表重建@我追踪（进入会话时调用）
- (void)rebuildAtMeTrackingFromCurrentMessagesIfNeeded;
/// 延迟刷新@我提示
- (void)scheduleAtMeHintRefresh;
/// 收到新消息时检查并记录@我
- (void)checkAndTrackAtMeMessage:(JSQMessage *)message atIndex:(NSInteger)index;
/// 主控制器滚动回调中转入群聊附加逻辑
- (void)rb_groupChat_scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)rb_groupChat_scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)rb_groupChat_scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (void)rb_groupChat_scrollViewDidEndDecelerating:(UIScrollView *)scrollView;

/// 将待插入的 @ 用户写入输入框（主文件 viewWillDisappear 等调用）
- (void)flushPendingAtUserInsertIfNeeded;
/// 取消待插入的 @（主文件 viewDidDisappear 等调用）
- (void)cancelPendingAtUserInsert;

@end

NS_ASSUME_NONNULL_END
