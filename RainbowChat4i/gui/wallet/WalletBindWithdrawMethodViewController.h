#import <UIKit/UIKit.h>

@class WalletBindWithdrawMethodViewController;

/**
 * 绑定/编辑提款方式页面
 * @param method 如果传入，则为编辑模式；如果为nil，则为添加模式
 */
@interface WalletBindWithdrawMethodViewController : UIViewController

// 编辑模式：传入要编辑的提款方式数据
@property (nonatomic, strong) NSDictionary *methodToEdit;

@end
