#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 转账页：支持从聊天传入收款人，或从钱包首页进入后手动输入收款方
@interface WalletTransferViewController : UIViewController

/// 收款方用户 UID（从聊天进入时由调用方设置）
@property (nonatomic, copy, nullable) NSString *toUid;
/// 收款方展示名，如 "J(*星)"（从聊天进入时设为对方昵称）
@property (nonatomic, copy, nullable) NSString *recipientDisplayName;
/// 收款方微信号/Chat ID 展示，如 "KinguYume"（可选，不设则用 toUid 显示）
@property (nonatomic, copy, nullable) NSString *recipientWechatId;
/// 群聊时传入群 id，用于从群成员列表选择收款人
@property (nonatomic, copy, nullable) NSString *groupId;
/// 可选：预设币种（当前仅前端界面与本地消息展示使用）
@property (nonatomic, copy, nullable) NSString *presetAssetType;

@end

NS_ASSUME_NONNULL_END
