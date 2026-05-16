//telegram @wz662
/**
 * 本类用于显示通过“查找好友”功能查到的数据结果。
 * <p>
 * 支持下拉自动分页显示等。
 * <p>
 * <b>特别说明：</b>20170227日起，在RainbowChat只保留“随机查找”功能后，已去掉
 * 传统的可以分页查看所有用户，以下类中注释掉的代码就是这些作用，但暂时用不上了，
 * 为了简化代码可读性，已注释掉。
 *
 * @author Jack Jiang, 2017-12-01
 * @version 1.0
 */

#import <UIKit/UIKit.h>
#import "UserEntity.h"

@interface FindFriendResultViewController : UIViewController<UITableViewDataSource,UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
/* 表格数据为空时显示的提示UI */
@property (weak, nonatomic) IBOutlet UIView *layoutTableEmptyHint;


/**
 初始化方法。

 @param nibNameOrNil nib name
 @param nibBundleOrNil nil
 @param sex  "-1" - 表示不区分是否在线，"1" - 表示只查在线，"0" - 表示只查离线
 @param onlineStatus "-1" - 表示不区分性别，"1"  - 表示只查男性，"0" - 表示只查女性
 @return obj
 */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withSexCondition:(NSString *)sex withOnlineCondition:(NSString *)onlineStatus;//withDatas:(NSArray<RosterElementEntity *> *)usersList;

@end
