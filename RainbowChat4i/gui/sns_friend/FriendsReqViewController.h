//telegram @wz662
/**
 * “验证通知”列表Activity实现类。
 * <p>
 * 截止20171226日，本界面中暂时只处理好友请求这样的通知（列出的是服务端
 * 记录的未处理的加好友请求），日后实现群聊等（比如群聊中的加群请求），相
 * 应地扩展本类中的“验证通知”类型即可.
 *
 * @author Jack Jiang, 2017-12-26
 * @see AlarmsViewController
 */

#import <UIKit/UIKit.h>

@interface FriendsReqViewController : UIViewController<UITableViewDataSource,UITableViewDelegate>

/* 列表 */
@property (weak, nonatomic) IBOutlet UITableView *tableView;
/* 表格数据为空时显示的提示UI */
@property (weak, nonatomic) IBOutlet UIView *layoutTableEmptyHint;

/** 将添加来源原始值（如 search_uid）翻译为中文显示文本 */
+ (NSString *)addSourceDisplayText:(NSString *)addSource;

@end
