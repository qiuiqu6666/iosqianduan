#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 资金密码输入弹窗：6 位密码格 + 自定义数字键盘（类似微信红包支付）
@interface WalletFundPasswordInputViewController : UIViewController

@property (nonatomic, copy) NSString *titleText;       ///< 弹窗标题，默认「输入资金密码」
@property (nonatomic, copy) NSString *amountText;     ///< 金额展示，如 @"¥100.00"，可为空不显示
@property (nonatomic, copy) void (^onComplete)(NSString *password);  ///< 输入完成（6位），password 为明文
@property (nonatomic, copy) void (^onCancel)(void);    ///< 用户点击关闭

@end

NS_ASSUME_NONNULL_END
