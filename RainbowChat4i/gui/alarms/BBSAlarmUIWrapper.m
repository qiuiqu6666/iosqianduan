//telegram @wz662
#import "BBSAlarmUIWrapper.h"
#import "GroupsProvider.h"
#import "ViewControllerFactory.h"
#import "UserDefaultsToolKits.h"
#import "BasicTool.h"
#import "FileDownloadHelper.h"
#import "EmojiUtil.h"


@interface BBSAlarmUIWrapper ()

/** 寄生的主类AlarmsViewController的引用 */
@property (nonatomic, strong) AlarmsViewController *alarmsViewController;

@end


@implementation BBSAlarmUIWrapper

- (id)initWith:(AlarmsViewController *)alarmsViewController
{
    if(self = [super init])
    {
        self.alarmsViewController = alarmsViewController;
    }
    return self;
}

// 进入BBS聊天界面
- (void) gotoBBSChatting
{
    GroupEntity *bbsGe = [GroupsProvider getDefaultWordChatEntity];
    [ViewControllerFactory goGroupChattingViewController:self.alarmsViewController.navigationController gid:bbsGe.g_id gname:bbsGe.g_name animated:YES popToRootFirst:YES highlight:nil];
}

- (void) refreshSilenceUI
{
    // 设置静态图标的显示与否
    if(![UserDefaultsToolKits isChatMsgToneOpen:DEFAULT_GROUP_ID_FOR_BBS])
        self.alarmsViewController.viewSilenceForBBS.image = [UIImage imageNamed:@"bbs_chatting_layout_silence_icon"];
    else
        self.alarmsViewController.viewSilenceForBBS.image = [UIImage imageNamed:@"bbs_chatting_layout_member_icon2"];
}

- (void) onParentViewWillAppear
{
    // 设置静态图标的显示与否
    [self refreshSilenceUI];
}

- (void) refreshData:(AlarmDto *)data
{
    if(data != nil)
    {
        self.alarmsViewController.viewMessageAlarmDateForBBS.text = [TimeTool getTimeStringAutoShort2:data.date mustIncludeTime:NO timeWithSegment:NO];
        self.alarmsViewController.viewMessageAlarmTitleForBBS.text = data.title;
//        self.alarmsViewController.viewMessageAlarmMsgForBBS.text = data.alarmContent;
        
        // 含有emoji表情图片的富文本支持
        UILabel *alarmMsgLabel = self.alarmsViewController.viewMessageAlarmMsgForBBS;
        NSDictionary *attributes = @{
            NSFontAttributeName:alarmMsgLabel.font
        };
        alarmMsgLabel.attributedText = [EmojiUtil replaceEmojiWithPlanString:data.alarmContent attributes:attributes];

        self.alarmsViewController.viewMessageAlarmDateForBBS.hidden = NO;

//        [self.alarmsViewController.viewMessageAlarmFlagNumForBBS setTitle:data.flagNum forState:UIControlStateNormal];
//        if([BasicTool getIntValue:data.flagNum] <= 0)
//            self.alarmsViewController.viewMessageAlarmFlagNumForBBS.hidden = YES;
//        else
//            self.alarmsViewController.viewMessageAlarmFlagNumForBBS.hidden = NO;
        
        [self.alarmsViewController.viewMessageAlarmFlagNum2ForBBS setBadgeTextFont:[BasicTool getSystemFontOfSize:10]];
        if([BasicTool getIntValue:data.flagNum] <= 0)
        {
            [self.alarmsViewController.viewMessageAlarmFlagNum2ForBBS setBadgeValue:@"0"];
            self.alarmsViewController.viewMessageAlarmFlagNum2ForBBS.hidden = YES;
        }
        else
        {
            [self.alarmsViewController.viewMessageAlarmFlagNum2ForBBS setBadgeValue:data.flagNum];
            self.alarmsViewController.viewMessageAlarmFlagNum2ForBBS.hidden = NO;
            
            // 并根据新消息数的ui组件大小，来决定组件的显示坐标（目的是实现当大于1位数时
            // ，能保持右边不变而向左显示，而这种效果在xib里的autolayout是实现不了的，
            // 所以只能在代码里进行动态计算并设置x、y显示坐标，从而实现右不动、向左移的效果）
            CGRect badgeViewFrame = self.alarmsViewController.viewMessageAlarmFlagNum2ForBBS.frame;
            badgeViewFrame.origin.y = 2;                                  // 2是个视觉偏移量，可根据自已设定的字体等来调整
            badgeViewFrame.origin.x = 40 - badgeViewFrame.size.width + 3; // 40是图标的大小，3是个视觉偏移量、可根据自已设定的字体等来调整
            self.alarmsViewController.viewMessageAlarmFlagNum2ForBBS.frame = badgeViewFrame;
        }

        // 实现发消息人头像的设置(先设置默认头像)
        self.alarmsViewController.viewMessageAlarmHeadIconForBBS.image = [UIImage imageNamed:@"default_avatar_yuan_50"];
        // 再尝试加载真正的头像
        NSString *userUID = data.dataId;
        if(userUID != nil)
        {
            [FileDownloadHelper loadUserAvatarWithUID:userUID logTag:@"BBSAlarmUIWrapper-UID" complete:^(BOOL sucess, UIImage *img) {
                if(sucess && img != nil)
                    [self.alarmsViewController.viewMessageAlarmHeadIconForBBS setImage:img];
            } donotLoadFromDisk:NO];// 优先从磁盘缓存读取，打开即显示；后台异步拉取最新头像更新
        }

//        // 设置ui可见性
//        setMessageAlarmVisible(true);
    }
//    else
//        setMessageAlarmVisible(false);
}

// 创建BBS聊天界面中导航栏上自定义静音设置按钮的方法
+ (UIButton *)createCunstomNavigationBunttonForBBSChatting:(UIImage *)btnImg action:(SEL)btnAction target:(nullable id)target
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
//    button.titleLabel.font = [UIFont systemFontOfSize: 13.0];
//    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    [button setBackgroundImage:btnImg forState:UIControlStateNormal];
    button.frame = CGRectMake(0, 0, 58, 28);// 5, 0, 58, 28 向右偏移10像素（注意：此偏移，必须要在本按钮再放置于一个view时才会生效）
    // 让按钮内部的所有内容居中对齐
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [button addTarget:target action:btnAction forControlEvents:UIControlEventTouchUpInside];
    return button;
}

@end
