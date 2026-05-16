#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol StickerManageDelegate <NSObject>
@optional
/// 表情列表发生变更（添加/删除），通知面板刷新
- (void)stickerManageDidChange;
@end

/**
 * 自定义表情管理页面
 * 支持：查看表情列表、从相册添加表情、长按删除表情
 */
@interface StickerManageViewController : UIViewController

@property (nonatomic, weak) id<StickerManageDelegate> manageDelegate;

@end

NS_ASSUME_NONNULL_END
