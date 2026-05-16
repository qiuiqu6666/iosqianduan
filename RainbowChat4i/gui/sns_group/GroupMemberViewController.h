//telegram @wz662
#import <UIKit/UIKit.h>
#import "ViewControllerResultDelegate.h"

@class GroupMemberEntity;

/** 本界面用途之：创建群 */
#define USED_FOR_CREATE_GROUP              0
/** 本界面用途之：查看群成员(普通群员可用)或管理群成员(群主可用，群主有删除功能) */
#define USED_FOR_VIEW_OR_MANAGER_MEMBERS   1
/** 本界面用途之：邀请入群 */
#define USED_FOR_INVITE_MEMBERS            2
/** 本界面用途之：转让群 */
#define USED_FOR_TRANSFER                  3
/** 本界面用途之：设置管理员 */
#define USED_FOR_SET_ADMIN                 4
/** 本界面用途之：取消管理员 */
#define USED_FOR_CANCEL_ADMIN              5
/** 本界面用途之：从群成员中选择转账收款人 */
#define USED_FOR_SELECT_FOR_WALLET_TRANSFER 6


@interface GroupMemberViewController : UIViewController<UITableViewDataSource,UITableViewDelegate>

//// 申明一个回调代码，仿Android的Activity result机制和原理实现，用于通知前一个ViewController本界面中被改变的数据
//@property (nonatomic, weak) id<ViewControllerResultBackDelegate> resultBackDelegate;

/* 列表 */
@property (weak, nonatomic) IBOutlet UITableView *tableView;
/* 表格数据为空时显示的提示UI */
@property (weak, nonatomic) IBOutlet UIView *layoutTableEmptyHint;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil usedFor:(int)usedFor gid:(NSString *)gid isGroupOwner:(BOOL)isGroupOwner defaultSelectedUid:(NSString *)defaultSelectedUid;

/** 群成员隐私保护：0=所有人可见，1=仅管理员/群主可见。仅 USED_FOR_VIEW_OR_MANAGER_MEMBERS 时有效，为 1 时普通成员不能查看他人资料页。默认 0。 */
@property (nonatomic, assign) int groupMemberPrivacy;

/** 当 usedFor == USED_FOR_SELECT_FOR_WALLET_TRANSFER 时，选择一名成员并点击确定后回调（传入选中的成员，未选则传 nil） */
@property (nonatomic, copy, nullable) void(^onSingleMemberSelected)(GroupMemberEntity * _Nullable member);

/**
 * 本方法用于删除群成员、邀请群成员后更新群信息里的群成员数，并通过Activity的result回调机制通知前一个Activity.
 *
 * @param gid 更新的群
 * @param deltaCount 变动的数据，正数表示加入了群员、负数表示删除了群员
 */
+ (void) updateCurrentGroupMemberGroupAfterSubmit:(NSString *)gid deltaCount:(long)deltaCount;

// 创建导航样上自定义按钮的方法
+ (UIButton *)createCunstomNavigationBuntton;

@end
