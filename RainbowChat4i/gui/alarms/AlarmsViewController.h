//telegram @wz662
#import <UIKit/UIKit.h>
#import "RBBadgeView.h"
#import "GroupEntity.h"
#import "RootViewController.h"

@class IMClientManager;

// 消息列表过滤模式
#define ALARM_FILTER_ALL      0  // 显示所有消息（不过滤）
#define ALARM_FILTER_PRIVATE  1  // 仅显示私聊消息（好友/陌生人/系统等）
#define ALARM_FILTER_GROUP    2  // 仅显示群聊消息

@interface AlarmsViewController : RootViewController<UITableViewDataSource,UITableViewDelegate>

/** 消息列表过滤模式（默认ALARM_FILTER_ALL） */
@property (nonatomic, assign) int alarmFilterMode;
/** YES 表示当前页面仅显示已归档会话。 */
@property (nonatomic, assign) BOOL showArchivedOnly;

/** 消息列表 */
@property (weak, nonatomic) IBOutlet UITableView *tableView;
/* 表格数据为空时显示的提示UI */
@property (weak, nonatomic) IBOutlet UIView *layoutTableEmptyHint;

// 注意：此ui组件废目前用于低于ios 26的系统中（因为ios26系统导航栏行为的变更，它会浮在内容层的上方而导致ui被挡住）
/** 网络不好时显示的UI组件 */
@property (weak, nonatomic) IBOutlet UIView *layoutNetbadHint;
/** 网络断开提示内容的显示组件父view的高度约束（当不需要显地此组件时，本值设为0即可） */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *heightConstraintOfLayoutNetbadHint;

/** BBS消息提示组件：用户头像 */
@property (weak, nonatomic) IBOutlet UIImageView *viewMessageAlarmHeadIconForBBS;
/** BBS消息提示组件：日期 */
@property (weak, nonatomic) IBOutlet UILabel *viewMessageAlarmDateForBBS;
///** BBS消息提示组件：未读消息条数 */
//@property (weak, nonatomic) IBOutlet UIButton *viewMessageAlarmFlagNumForBBS;
/** BBS消息提示组件：未读消息条数(新) */
@property (weak, nonatomic) IBOutlet RBBadgeView *viewMessageAlarmFlagNum2ForBBS;
/** BBS消息提示组件：标题 */
@property (weak, nonatomic) IBOutlet UILabel *viewMessageAlarmTitleForBBS;
/** BBS消息提示组件：消息内容 */
@property (weak, nonatomic) IBOutlet UILabel *viewMessageAlarmMsgForBBS;
/** BBS消息提示组件：是否静音 */
@property (weak, nonatomic) IBOutlet UIImageView *viewSilenceForBBS;

/**
 * 打开单聊聊天界面。
 *
 * @param fromUid 对方的uid
 * @param fromNickname 对方的昵称（当对方是好友时，本参数无效可设null）
 * @param highlightOnceMsgFingerprint 该指纹码的消息将高亮显示一次（当前用于搜索功能中进到聊天界面时）
 */
+ (void)gotoSingleChattingViewController:(UINavigationController *)nv fromUid:(NSString *)fromUid fromNickname:(NSString *)fromNickname highlight:(NSString *)highlightOnceMsgFingerprint;
+ (void)gotoSingleChattingViewController:(UINavigationController *)nv fromUid:(NSString *)fromUid fromNickname:(NSString *)fromNickname highlight:(NSString *)highlightOnceMsgFingerprint anchorMessageDate:(NSDate * _Nullable)anchorMessageDate;

/**
 * 打开群聊聊天界面。
 *
 * @param gid 群id
 * @param g 群基本信息（当本参数为空时，将会根据参数gid从群缓存列表中读取群基本信息缓存数据）
 * @param highlightOnceMsgFingerprint 该指纹码的消息将高亮显示一次（当前用于搜索功能中进到聊天界面时）
 */
+ (void)gotoGroupChattingViewController:(UINavigationController *)nv gid:(NSString *)gid ge:(GroupEntity *)g highlight:(NSString *)highlightOnceMsgFingerprint;
+ (void)gotoGroupChattingViewController:(UINavigationController *)nv gid:(NSString *)gid ge:(GroupEntity *)g highlight:(NSString *)highlightOnceMsgFingerprint anchorMessageDate:(NSDate * _Nullable)anchorMessageDate;

/** 在上层聊天页开始 pop 动画前，预先把底层消息列表刷新到最新顺序，避免返回动画里先看到旧排序。 */
- (void)rb_prepareForUnderlyingPopDisplay;

@end
