//telegram @wz662
/**
 * 好友聊天详情界面.
 *
 * @author Jack Jiang, 2017-12-01
 * @version 1.0
 */

#import <UIKit/UIKit.h>
#import "UserEntity.h"

@interface ChatInfoViewController : UIViewController

// 用户头像
@property (strong, nonatomic) UIImageView *imgAvadar;

// 好友的昵称显示（优先显示备注）
@property (strong, nonatomic) UILabel *viewNickname;

// 标签组件：陌生人标签
@property (strong, nonatomic) UILabel *viewGuestFlag;

// 开关
@property (strong, nonatomic) UISwitch *switchMsgTone;
@property (strong, nonatomic) UISwitch *switchAlwaysTop;

- (id)initWithUid:(NSString *)uid andNick:(NSString *)nickname;

/**
 * 清空聊天记录。
 *
 * @param alarmType 首页"消息"类型
 * @param dataId 聊天对象id
 */
+ (void)clearHistory:(int)alarmType dataId:(NSString *)dataId viewForHud:(UIView *)v;

/**
 * 查找聊天记录。
 *
 * @param searchResultChatType 搜索聊天类型
 * @param dataId 聊天对象id
 */
+ (void)searhHistory:(UINavigationController *)nc searchResultChatType:(int)searchResultChatType dataId:(NSString *)dataId;

@end
