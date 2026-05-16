//
//  FavoritesChatViewController.h
//  RainbowChat4i
//
//  收藏夹（10001）专用聊天页：会话列表与普通单聊一致，来自 MessagesProvider（SQLite/内存）。
//

#import "ChatRootViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface FavoritesChatViewController : ChatRootViewController

- (instancetype)initWithHighlight:(NSString *_Nullable)highlightOnceMsgFingerprint;
- (void)startFavoritesHistoryBackfillIfNeeded;

@end

NS_ASSUME_NONNULL_END
