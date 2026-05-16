//
//  ChatRootViewController+MessageMenu.h
//  长按菜单、多选、撤回/删除实现。
//

#import "ChatRootViewController.h"

NS_ASSUME_NONNULL_BEGIN

// 服务端收藏类型，与 FavoritesViewController 一致（主文件 / Send 调用 submitFavoriteToServerWithContent 时使用）
#define kFavTypeText 0
#define kFavTypeImage 1
#define kFavTypeVoice 2
#define kFavTypeVideo 3
#define kFavTypeFile 4
#define kFavTypeLocation 5

@interface ChatRootViewController (MessageMenu)

/// 进入多选模式（长按菜单「选择」或主文件 dealloc 前需退出时调用）
- (void)enterMultiSelectMode;
/// 退出多选模式
- (void)exitMultiSelectMode;
/// 更新多选工具栏按钮启用状态（主文件点击头像/气泡等时调用）
- (void)updateMultiSelectToolbarState;
/// 将内容同步写入服务端收藏（供发送到 10001 / 多端同步），成功后回调 onSyncSuccess
- (void)submitFavoriteToServerWithContent:(NSString *)content favType:(int)favType sourceChatType:(int)sourceChatType onSyncSuccess:(void (^)(void))onSyncSuccess;
/// 10001 收藏同步到服务端成功后刷新收藏列表（子类可重写）
- (void)refresh10001FavoritesListIfNeeded;

@end

NS_ASSUME_NONNULL_END
