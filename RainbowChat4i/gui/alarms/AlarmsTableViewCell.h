//telegram @wz662
#import <UIKit/UIKit.h>
#import "RBBadgeView.h"

@interface AlarmsTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *viewTitle;

//------------- 以下左侧的陌生人标签相关变量以于v10.2废弃，日后将删除相关ui和代码
// 标题左侧的陌生人标签（当对方是陌生人时显示）
@property (weak, nonatomic) IBOutlet UILabel *viewTitleLeftFlag;
// 标题左侧的陌生人标签的父容器组件
@property (weak, nonatomic) IBOutlet UIView *viewTitleLeftFlagContainer;
// 标题左边的标签宽度约束（当不需要显示此组件时，本值设为0即可，利于用此值的设置可以让AutoLayout下依赖于本组件的其它组件能自适应位置）
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *viewTitleLeftFlagContainer_widthConstraint;
//------------- END

// 标题右侧的标签（当对方是陌生人、系统、官方时显示）
@property (weak, nonatomic) IBOutlet UILabel *viewTitleRightFlag;
@property (weak, nonatomic) IBOutlet UIImageView *viewTitleRightFlagImageView;
// 标题右侧的标签的父容器组件
@property (weak, nonatomic) IBOutlet UIView *viewTitleRightFlagContainer;
// 标题右边的标签宽度约束（当不需要显示此组件时，本值设为0即可，利于用此值的设置可以让AutoLayout下依赖于本组件的其它组件能自适应位置）
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *viewTitleRightFlagContainer_widthConstraint;

// 消息时间
@property (weak, nonatomic) IBOutlet UILabel *viewDate;

// 显示“x条消息”这样的未读消息提示信息（当设置消息免打扰时显示）
@property (weak, nonatomic) IBOutlet UILabel *viewMsgPrefix;
// 显示“x条消息”这样的未读消息提示信息的右侧衬距（当）不需要显示此组件时，本值设为0即可，利于
// 用此值的设置可以让AutoLayout下依赖于本组件的其它组件能自适应位置）
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *viewMsgPrefix_rightGapConstraint;

// 消息内容、消息前缀：相对标题底部的间距（置顶时加大，避免与右上角「置顶」标重叠）
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *viewMsgContentTopFromTitleConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *viewMsgPrefixTopFromTitleConstraint;

// 消息内容
@property (weak, nonatomic) IBOutlet UILabel *viewMsgContent;
// 头像
@property (weak, nonatomic) IBOutlet UIImageView *viewIcon;

// 置顶图标
@property (weak, nonatomic) IBOutlet UIImageView *viewAlwaystopIcon;
// 消息免打扰图标（约束在昵称右侧；隐藏时宽度置 0 以免卡住右侧标签）
@property (weak, nonatomic) IBOutlet UIImageView *viewSilentIcon;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *viewSilentIconWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *viewSilentIconLeadingConstraint;

// 未读消息数组件（当未设置消息免打扰时显示）
@property (weak, nonatomic) IBOutlet RBBadgeView *viewFlagNum2;
// 未读消息小红点（当设置消息免打扰时显示）
@property (weak, nonatomic) IBOutlet UIView *viewFlagDot;

/// 当前 cell 绑定的群头像 gid；用于复用/异步回调时校验，避免群头像回闪或错绑。
@property (nonatomic, copy, nullable) NSString *rb_boundGroupId;

/// 底部分隔线（hairline，比系统 UITableView 分隔线更细）；末行传 YES 隐藏。
- (void)rb_setHairlineBottomSeparatorHidden:(BOOL)hidden;

@end
