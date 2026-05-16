//telegram @wz662
#import <UIKit/UIKit.h>
#import "ViewControllerResultDelegate.h"
#import "RootViewController.h"

// 请求码：前往建群页面（用于ViewControllerResultBackDelegate中的数据改变结果回调通知时使用）
#define REQUEST_CODE_FOR_CREATE_GROUP   1


@interface GroupsViewController : RootViewController<UITableViewDataSource,UITableViewDelegate>//ViewControllerResultBackDelegate

/* 列表 */
@property (weak, nonatomic) IBOutlet UITableView *tableView;
/* 表格数据为空时显示的提示UI */
@property (weak, nonatomic) IBOutlet UIView *layoutTableEmptyHint;


//- (IBAction)gotoCreateGroup:(UIBarButtonItem *)sender;

/**
 * 获得下载指定群组头像的完整http地址.
 * <p>
 * 形如："http://192.168.88.138:8080/BinaryDownloader?
 * action=gavartar_d&user_uid=400007&file_name=0000000152.jpg"。
 *
 * @param gid 要下载群头像的群id
 * @return 完整的http文件下载地址
 */
+ (NSString *) getGroupAvatarDownloadURL:(NSString *)gid;

/**
 * 获得下载指定群组头像的完整http地址（支持自定义群头像）.
 *
 * 优先使用自定义群头像（g_custom_avatar），若为空则使用系统生成的九宫格头像。
 *
 * @param gid 要下载群头像的群id
 * @param customAvatar 自定义群头像文件名（nil=使用系统默认头像）
 * @return 完整的http文件下载地址
 */
+ (NSString *) getGroupAvatarDownloadURL:(NSString *)gid customAvatar:(NSString *)customAvatar;

/**
 * 创建群聊。
 */
+ (void)gotoCreateGroup:(UINavigationController *)nv defaultSelectedUid:(NSString *)defaultSelectedUid;

@end
