//telegram @wz662
#import <UIKit/UIKit.h>
#import "GroupEntity.h"
#import "ViewControllerResultDelegate.h"
#import "RBImagePickerWrapper.h"

// 请求码：前往群成员管理(可删除群员)页面（用于ViewControllerResultBackDelegate中的数据改变结果回调通知时使用）
#define REQUEST_CODE_FOR_VIEW_MEMBERS   1
// 请求码：前往群成员邀请页面（用于ViewControllerResultBackDelegate中的数据改变结果回调通知时使用）
#define REQUEST_CODE_FOR_INVITE_MEMBERS 2
// 请求码：前往群转让页面（即选择新群主页面）（用于ViewControllerResultBackDelegate中的数据改变结果回调通知时使用）
#define REQUEST_CODE_FOR_TRANSFER       3
// 请求码：前往群公告页面（用于ViewControllerResultBackDelegate中的数据改变结果回调通知时使用）
#define REQUEST_CODE_FOR_EDIT_NOTICE    4


@interface GroupInfoViewController : UIViewController<ViewControllerResultBackDelegate, RBImagePickerCompleteDelegate>

- (id)initWithDatas:(GroupEntity *)groupInfo;

// 兼容旧的调用方式
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withDatas:(GroupEntity *)groupInfo;

@end
