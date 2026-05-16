//telegram @wz662
#import <UIKit/UIKit.h>
#import "ViewControllerResultDelegate.h"
#import "TargetEntity.h"
#import "ContactMeta.h"
#import "CommonViewController.h"
#import "AlarmDto.h"
#import "GroupEntity.h"
#import "TargetSourceFilterFactory.h"

///** 本界面用途之：本界面用途之：聊天界面中发送"个人名片"消息时选择被发送的用户 */
//#define USED_FOR_SEND_CONTACT_MESSAGE 0


/**
 * 数据来源常量定义。
 */
typedef NS_ENUM(NSInteger, TargetSource) {
    /* 来自"最近聊天" */
    TargetSourceLatestChatting = 0x0001, // 二进制001
    /* 我的好友 */
    TargetSourceFriend         = 0x0002, // 二进制010
    /* 我的群聊 */
    TargetSourceGroup          = 0x0004, // 二进制100
    /* 群成员（此数据源目前仅用于"@"功能中，它暂时不能用于其它通用场景哦） */
    TargetSourceGroupMember    = 0x0008, // 二进制1000
};


// 用户选择完成后的代理
@protocol UserChooseCompleteDelegate <NSObject>
@optional

/**
 * 用户选择结果代理方法（单选）：可以在此方法中处理从用户选择列表中选择的用户进行进一步处理。
 *
 * @param selectedTarget 选中的目标
 */
- (void)processTargetChooseComplete:(TargetEntity *)selectedTarget extraObj:(id)obj requestCode:(int)requestCode;

/**
 * 用户选择结果代理方法（多选）：可以在此方法中处理从用户选择列表中选择的多个目标进行进一步处理。
 *
 * @param selectedTargets 选中的目标数组
 */
- (void)processMultiTargetChooseComplete:(NSArray<TargetEntity *> *)selectedTargets extraObj:(id)obj requestCode:(int)requestCode;

@end


@interface TargetChooseViewController : CommonViewController<UITableViewDataSource,UITableViewDelegate>

@property (nonatomic, weak) id<UserChooseCompleteDelegate> chooseCompleteDelegate;

/* tab切换按钮的底部总的父view的高度约束（当不需要显示这些tab时，本值设为0即可）*/
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tabsMainLayoutHeightConstraint;
@property (weak, nonatomic) IBOutlet UIButton *latestChattingRadio;
@property (weak, nonatomic) IBOutlet UIButton *friendRadio;
@property (weak, nonatomic) IBOutlet UIButton *groupRadio;
@property (weak, nonatomic) IBOutlet UIButton *groupMemberRadio;

/* 列表 */
@property (weak, nonatomic) IBOutlet UITableView *tableView;
/* 表格数据为空时显示的提示UI */
@property (weak, nonatomic) IBOutlet UIView *layoutTableEmptyHint;

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
supportedTargetSource:(int)targetSource
 latestChattingFilter:(TargetSourceFilter4LatestChatting)targetSourceFilter4LatestChatting
         friendFilter:(TargetSourceFilter4Friend)targetSourceFilter4Friend
          groupFilter:(TargetSourceFilter4Group)targetSourceFilter4Group
    groupMemberFilter:(TargetSourceFilter4GroupMember)targetSourceFilter4GroupMember
             extraObj:(id)extraObj
                  gid:(NSString *)gid
          requestCode:(int)requestCode
             delegate:(id<UserChooseCompleteDelegate>)chooseCompleteDelegate;

@end
