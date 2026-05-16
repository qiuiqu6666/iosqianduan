//telegram @wz662
#import <UIKit/UIKit.h>
#import "CommonViewController.h"
#import "RootViewController.h"

@interface ContactViewController : RootViewController<UITableViewDataSource,UITableViewDelegate, UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
///* 表格数据为空时显示的提示UI */
//@property (weak, nonatomic) IBOutlet UIView *layoutTableEmptyHint;

/**
 提交一个网络请求：从好友列表中删除好友。

 @param parentView 本参数不为nil表示将显示进度提示菊花，否则不显示
 @param uid 将被删除的好友uid
 @param complete (参数YES表示删除成功，来吧则删除失败)
 */
+ (void) doDeleteFriendImpl:(UIView *)parentView uidWillBeDelete:(NSString *)uid complete:(void (^)(BOOL sucess))complete;

@end
