#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 转账详情页：展示收款成功（你已收款,资金已存入零钱）、金额、转账/收款时间，可跳转零钱余额与账单详情
@interface WalletTransferDetailViewController : UIViewController

/// 转账金额（元），如 @"200.00"
@property (nonatomic, copy) NSString *amount;
/// 币种，默认 CNY
@property (nonatomic, copy) NSString *assetType;
/// 转账时间（用于展示，若 nil 则不显示或使用当前时间）
@property (nonatomic, copy, nullable) NSDate *transferTime;
/// 收款时间（用于展示，若 nil 则与 transferTime 一致）
@property (nonatomic, copy, nullable) NSDate *receiptTime;
/// 是否为本方收款（YES 显示「你已收款」；NO 可显示「已转出」等，当前页按设计图仅实现收款态）
@property (nonatomic, assign) BOOL isIncoming;

@end

NS_ASSUME_NONNULL_END
