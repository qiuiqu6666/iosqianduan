//
//  ChatRootViewController+ReadReceipt.h
//  已读回执：上报、查询、MT61 与 SyncKey 同步回调。
//

#import "ChatRootViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChatRootViewController (ReadReceipt)

/// 上报已读回执（可选强制，用于进入/退出聊天）
- (void)reportReadReceiptIfNeededWithForce:(BOOL)forceReport;
/// 上报已读回执（受节流限制）
- (void)reportReadReceiptIfNeeded;
/// 查询对方已读回执（默认 3 秒内不重复请求，避免与每条新消息叠加）
- (void)queryPartnerReadReceipt;

/// bypassThrottle 为 YES 时（如 viewDidAppear）立即拉一次，不受 3 秒节流限制。
- (void)queryPartnerReadReceiptBypassThrottle:(BOOL)bypassThrottle;

/// 根据对方水位线更新「我」发出消息的已读状态；无变化时返回 NO，可避免整表 reload。
- (BOOL)updateMessagesReadStatus;

/// 从本地缓存恢复对方已读水位并应用到当前内存列表（须在 SQLite 并入后、首帧或整表 reload 之前调用，保证双勾不闪、不重依赖网络）。
- (void)rb_restorePartnerReadWatermarkAndApplyToCurrentListIfNeeded;

@end

NS_ASSUME_NONNULL_END
