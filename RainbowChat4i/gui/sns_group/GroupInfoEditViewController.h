//telegram @wz662
#import <UIKit/UIKit.h>
#import "GroupEntity.h"
#import "ViewControllerResultDelegate.h"

/** 操作常量定义之：修改群名（群主可用）*/
#define IS_CHANGE_GROUP_NAME            0
/** 操作常量定义之：修改群内昵称（普通群员可用） */
#define IS_CHANGE_MY_NICKNAME_IN_GROUP  1
/** 操作常量定义之：编辑公告（普通群员可用） */
#define IS_CHANGE_GROUP_NOTICE          2
/** 操作常量定义之：备注（与群内昵称同一编辑逻辑，仅标题区分） */
#define IS_CHANGE_GROUP_REMARK          3


@interface GroupInfoEditViewController : UIViewController

- (id)initWithChangeType:(int)changeType andGroupInfo:(GroupEntity *)groupInfo;

// 兼容旧的调用方式
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withChangeType:(int)changeType andGroupInfo:(GroupEntity *)groupInfo;

// 申明一个回调代码，仿Android的Activity result机制和原理实现，用于通知前一个ViewController本界面中被改变的数据等
@property (nonatomic, weak) id<ViewControllerResultBackDelegate> resultBackdelegate;

@end
