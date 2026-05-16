//telegram @wz662
#import "GroupInfoViewController.h"
#import "GroupEntity.h"
#import "GroupMemberEntity.h"
#import "GroupsProvider.h"
#import "UserDefaultsToolKits.h"
#import "BasicTool.h"
#import "ViewControllerFactory.h"
#import "GroupInfoEditViewController.h"
#import "QueryFriendInfoAsync.h"
#import "AppDelegate.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "NotificationCenterFactory.h"
#import "LPActionSheet.h"
#import "AlarmType.h"
#import "GroupSettingsViewController.h"
#import "GroupJoinRequestsViewController.h"
#import "GroupMutedMembersViewController.h"
#import "RBImagePickerWrapper.h"
#import "FileUploadHelper.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "FileTool.h"
#import "MBProgressHUD.h"
#import "GroupsViewController.h"
#import "ChatInfoViewController.h"
#import "ChatBackgroundViewController.h"
#import "MsgSummaryContentDTO.h"
#import "GroupManageViewController.h"
#import "GroupManageViewController.h"
#import "ClientCoreSDK.h"
#import "UIViewController+RBPlainCustomNav.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

// 成员网格参数
#define MEMBER_AVATAR_SIZE  56
#define MEMBER_GRID_PADDING 20
#define MEMBER_H_SPACING    15
#define MEMBER_V_SPACING    12
#define MEMBER_NAME_HEIGHT  18
#define MEMBER_ITEMS_PER_ROW 5
#define MEMBER_MAX_ROWS     4
/** 群资料页仅作头像网格预览，大群禁止拉全量成员（会巨量 JSON+内存+主线程排序导致闪退），与「查看更多群成员」分页列表一致用单页条数 */
#define GROUP_INFO_MEMBER_LIST_PAGE      1
#define GROUP_INFO_MEMBER_LIST_PAGE_SIZE 150

@interface GroupInfoViewController () <GroupManageDelegate>

@property (nonatomic, retain) GroupEntity *groupInfoForInit;

/** 当前用户在群中的角色：0=普通成员，1=管理员，2=群主 */
@property (nonatomic, assign) int myRoleInGroup;

/** 图片选择处理封装对象（用于修改群头像时从相机或相册中选择图片） */
@property (nonatomic, strong) RBImagePickerWrapper *imagePickerWrapper;

// UI Components
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

// 成员网格区域
@property (nonatomic, strong) UIView *memberGridSection;
@property (nonatomic, strong) UIView *memberGridContainer;
@property (nonatomic, strong) NSLayoutConstraint *memberGridHeightConstraint;
@property (nonatomic, strong) NSArray<GroupMemberEntity *> *membersList;
/** 仅用于忽略过期的群成员列表请求回调，避免快速进出子页时旧数据触发布局 */
@property (nonatomic, assign) NSUInteger groupMembersLoadGeneration;
@property (nonatomic, strong) UIView *viewMoreMembersRow;
@property (nonatomic, strong) UIView *viewMoreMembersSep;
@property (nonatomic, strong) NSLayoutConstraint *memberGridBottomToSection;     // grid直接到section底部
@property (nonatomic, strong) NSLayoutConstraint *viewMoreBottomToSection;       // viewMore到section底部
@property (nonatomic, assign) BOOL memberGridExpanded;  // 是否已展开全部成员
@property (nonatomic, strong) UILabel *viewMoreMembersLabel; // "查看更多群成员"/"收起" 文字标签

// 行内值标签（用于刷新）
@property (nonatomic, strong) UILabel *groupNameValueLabel;
@property (nonatomic, strong) UILabel *groupIdValueLabel;
@property (nonatomic, strong) UILabel *noticeValueLabel;
@property (nonatomic, strong) UILabel *nicknameInGroupValueLabel;
@property (nonatomic, strong) UIImageView *groupInfoAvatarView;

// 开关
@property (nonatomic, strong) UISwitch *switchMsgTone;
@property (nonatomic, strong) UISwitch *switchAlwaysTop;
@property (nonatomic, strong) UISwitch *switchShowMemberNickname;

// 群管理行（根据角色动态显隐）
@property (nonatomic, strong) UIView *adminRow;
@property (nonatomic, strong) UIView *adminSep;
@property (nonatomic, strong) NSLayoutConstraint *adminRowHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *adminSepHeightConstraint;

// 底部按钮区域
@property (nonatomic, strong) UIView *bottomSection;

@end


@implementation GroupInfoViewController

#pragma mark - Init & Lifecycle

- (id)initWithDatas:(GroupEntity *)groupInfo
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.groupInfoForInit = groupInfo;
    }
    return self;
}

// 兼容旧的调用方式
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withDatas:(GroupEntity *)groupInfo
{
    return [self initWithDatas:groupInfo];
}

- (void)loadView
{
    self.view = [[UIView alloc] init];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.myRoleInGroup = [self localUserIsGroupOwner] ? 2 : 0;

    self.view.backgroundColor = HexColor(0xF0F0F0);
    NSString *memberCount = self.groupInfoForInit.g_member_count ?: @"";
    NSString *navTitle = [NSString stringWithFormat:@"聊天信息 (%@)", memberCount];
    self.title = navTitle;
    self.navigationItem.titleView = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:navTitle];

    self.imagePickerWrapper = [[RBImagePickerWrapper alloc] initWithParent:self delegate:self crop:YES];

    [self buildUI];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
    [self refreshDatas];
    // 注意：不在此拉取群成员。从子页（如群成员列表）pop 时此时尚在转场，若 HTTP 先返回并执行 refreshMemberGrid（改约束+重建子视图），易与转场中的布局冲突导致闪退；改到 viewDidAppear
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
    [self refreshGroupInfoFromServerIfNeeded];
    [self loadGroupMembers];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self rb_plainCustomNavHostViewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

#pragma mark - Build UI

- (void)buildUI
{
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    if (@available(iOS 11.0, *)) {
        self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],
    ]];

    // ========== Section 0: 成员网格 ==========
    self.memberGridSection = [self buildMemberGridSection];
    [self.contentView addSubview:self.memberGridSection];
    [NSLayoutConstraint activateConstraints:@[
        [self.memberGridSection.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.memberGridSection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.memberGridSection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];

    // ========== Section 1: 群聊名称 / 群二维码 / 群公告 / 群管理 / 备注 ==========
    UIView *section1 = [self buildGroupInfoSection];
    [self.contentView addSubview:section1];
    [NSLayoutConstraint activateConstraints:@[
        [section1.topAnchor constraintEqualToAnchor:self.memberGridSection.bottomAnchor constant:10],
        [section1.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [section1.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];

    // ========== Section 2: 查找聊天内容 ==========
    UIView *section2 = [self buildArrowSection:@[@{@"title": @"查找聊天内容", @"action": NSStringFromSelector(@selector(clickSearchHistory))}]];
    [self.contentView addSubview:section2];
    [NSLayoutConstraint activateConstraints:@[
        [section2.topAnchor constraintEqualToAnchor:section1.bottomAnchor constant:10],
        [section2.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [section2.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];

    // ========== Section 3: 消息免打扰 / 置顶聊天 / 保存到通讯录 ==========
    UIView *section3 = [self buildSwitchSection1];
    [self.contentView addSubview:section3];
    [NSLayoutConstraint activateConstraints:@[
        [section3.topAnchor constraintEqualToAnchor:section2.bottomAnchor constant:10],
        [section3.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [section3.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];

    // ========== Section 4: 我在本群的昵称 / 显示群成员昵称 ==========
    UIView *section4 = [self buildMySettingsSection];
    [self.contentView addSubview:section4];
    [NSLayoutConstraint activateConstraints:@[
        [section4.topAnchor constraintEqualToAnchor:section3.bottomAnchor constant:10],
        [section4.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [section4.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];

    // ========== Section 5: 设置当前聊天背景 ==========
    UIView *section5 = [self buildArrowSection:@[@{@"title": @"设置当前聊天背景", @"action": NSStringFromSelector(@selector(clickChatBackground))}]];
    [self.contentView addSubview:section5];
    [NSLayoutConstraint activateConstraints:@[
        [section5.topAnchor constraintEqualToAnchor:section4.bottomAnchor constant:10],
        [section5.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [section5.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];

    // ========== Section 6: 清空聊天记录 / 投诉 ==========
    UIView *section6 = [self buildArrowSection:@[
        @{@"title": @"清空聊天记录", @"action": NSStringFromSelector(@selector(clickClearHistory))},
        @{@"title": @"投诉", @"action": NSStringFromSelector(@selector(clickComplaint))},
    ]];
    [self.contentView addSubview:section6];
    [NSLayoutConstraint activateConstraints:@[
        [section6.topAnchor constraintEqualToAnchor:section5.bottomAnchor constant:10],
        [section6.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [section6.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];

    // ========== Section 7: 底部按钮（退出/解散） ==========
    self.bottomSection = [self buildBottomSection];
    [self.contentView addSubview:self.bottomSection];
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomSection.topAnchor constraintEqualToAnchor:section6.bottomAnchor constant:10],
        [self.bottomSection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.bottomSection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.bottomSection.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-30],
    ]];
}

#pragma mark - Section Builders

// ===== 成员网格区域 =====
- (UIView *)buildMemberGridSection
{
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];

    self.memberGridContainer = [[UIView alloc] init];
    self.memberGridContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [section addSubview:self.memberGridContainer];

    self.memberGridHeightConstraint = [self.memberGridContainer.heightAnchor constraintEqualToConstant:MEMBER_AVATAR_SIZE + MEMBER_NAME_HEIGHT + MEMBER_V_SPACING + 10];

    // "查看更多群成员" 分隔线
    self.viewMoreMembersSep = [self buildSeparator];
    self.viewMoreMembersSep.hidden = YES;
    [section addSubview:self.viewMoreMembersSep];

    // "查看更多群成员" 行
    self.viewMoreMembersRow = [[UIView alloc] init];
    self.viewMoreMembersRow.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewMoreMembersRow.hidden = YES;

    UIButton *moreBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    moreBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [moreBtn addTarget:self action:@selector(clickViewAllMembers) forControlEvents:UIControlEventTouchUpInside];
    [self.viewMoreMembersRow addSubview:moreBtn];

    self.viewMoreMembersLabel = [[UILabel alloc] init];
    self.viewMoreMembersLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewMoreMembersLabel.text = @"查看更多群成员";
    self.viewMoreMembersLabel.font = [UIFont systemFontOfSize:15];
    self.viewMoreMembersLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
    self.viewMoreMembersLabel.textAlignment = NSTextAlignmentCenter;
    self.viewMoreMembersLabel.userInteractionEnabled = NO;
    [self.viewMoreMembersRow addSubview:self.viewMoreMembersLabel];

    UIImageView *moreArrow = [[UIImageView alloc] init];
    moreArrow.translatesAutoresizingMaskIntoConstraints = NO;
    moreArrow.image = [UIImage imageNamed:@"common_list_rightarrow_icon_nor"];
    moreArrow.contentMode = UIViewContentModeScaleAspectFit;
    moreArrow.userInteractionEnabled = NO;
    [self.viewMoreMembersRow addSubview:moreArrow];

    [NSLayoutConstraint activateConstraints:@[
        [moreBtn.leadingAnchor constraintEqualToAnchor:self.viewMoreMembersRow.leadingAnchor],
        [moreBtn.trailingAnchor constraintEqualToAnchor:self.viewMoreMembersRow.trailingAnchor],
        [moreBtn.topAnchor constraintEqualToAnchor:self.viewMoreMembersRow.topAnchor],
        [moreBtn.bottomAnchor constraintEqualToAnchor:self.viewMoreMembersRow.bottomAnchor],
        [self.viewMoreMembersLabel.centerXAnchor constraintEqualToAnchor:self.viewMoreMembersRow.centerXAnchor],
        [self.viewMoreMembersLabel.centerYAnchor constraintEqualToAnchor:self.viewMoreMembersRow.centerYAnchor],
        [moreArrow.leadingAnchor constraintEqualToAnchor:self.viewMoreMembersLabel.trailingAnchor constant:4],
        [moreArrow.centerYAnchor constraintEqualToAnchor:self.viewMoreMembersRow.centerYAnchor],
        [moreArrow.widthAnchor constraintEqualToConstant:8],
        [moreArrow.heightAnchor constraintEqualToConstant:14],
    ]];

    [section addSubview:self.viewMoreMembersRow];

    // memberGrid底部直接到section（无"查看更多"时使用）
    self.memberGridBottomToSection = [self.memberGridContainer.bottomAnchor constraintEqualToAnchor:section.bottomAnchor constant:-10];
    // viewMoreMembersRow底部到section（有"查看更多"时使用）
    self.viewMoreBottomToSection = [self.viewMoreMembersRow.bottomAnchor constraintEqualToAnchor:section.bottomAnchor constant:-5];

    // 初始：无查看更多
    self.memberGridBottomToSection.active = YES;
    self.viewMoreBottomToSection.active = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.memberGridContainer.topAnchor constraintEqualToAnchor:section.topAnchor constant:15],
        [self.memberGridContainer.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:MEMBER_GRID_PADDING],
        [self.memberGridContainer.trailingAnchor constraintEqualToAnchor:section.trailingAnchor constant:-MEMBER_GRID_PADDING],
        self.memberGridHeightConstraint,

        [self.viewMoreMembersSep.topAnchor constraintEqualToAnchor:self.memberGridContainer.bottomAnchor constant:5],
        [self.viewMoreMembersSep.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [self.viewMoreMembersSep.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [self.viewMoreMembersSep.heightAnchor constraintEqualToConstant:0.5],

        [self.viewMoreMembersRow.topAnchor constraintEqualToAnchor:self.viewMoreMembersSep.bottomAnchor],
        [self.viewMoreMembersRow.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [self.viewMoreMembersRow.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [self.viewMoreMembersRow.heightAnchor constraintEqualToConstant:44],
    ]];

    return section;
}

- (void)refreshMemberGrid
{
    if (self.memberGridContainer == nil || !self.isViewLoaded) return;

    // 先卸下挂载在头像 UIImageView 上的 RBAvatarView / SD 加载回调，再移除视图。
    // 否则从群成员页返回后会再次 refreshMemberGrid，异步头像回调仍可能访问已释放的 imageView（典型 EXC_BAD_ACCESS）。
    // 发红包选成员返回的是钱包页，不会走本页的网格刷新，故表现不一致。
    for (UIView *sub in [self.memberGridContainer.subviews copy]) {
        for (UIView *v in sub.subviews) {
            if ([v isKindOfClass:[UIImageView class]]) {
                UIImageView *iv = (UIImageView *)v;
                [RBAvatarView pauseVideoForAvatarInImageView:iv];
                [RBAvatarView removeAvatarFromImageView:iv];
            }
        }
        [sub removeFromSuperview];
    }

    CGFloat containerWidth = [UIScreen mainScreen].bounds.size.width - MEMBER_GRID_PADDING * 2;
    CGFloat itemWidth = MEMBER_AVATAR_SIZE;
    // 计算每行可放多少个
    NSInteger itemsPerRow = (NSInteger)((containerWidth + MEMBER_H_SPACING) / (itemWidth + MEMBER_H_SPACING));
    if (itemsPerRow < 4) itemsPerRow = 4;
    if (itemsPerRow > 5) itemsPerRow = 5;

    // 最多显示的成员数（留2个位置给+和-按钮）
    BOOL canManage = [self localUserIsGroupOwner] || self.myRoleInGroup >= 1;
    NSInteger buttonCount = canManage ? 2 : 1;

    NSArray *members = self.membersList ?: @[];

    // 4行最多能放的总项数
    NSInteger maxItemsIn4Rows = itemsPerRow * MEMBER_MAX_ROWS;
    // 在4行内最多能放的成员数（减去按钮占位）
    NSInteger maxMembersIn4Rows = maxItemsIn4Rows - buttonCount;

    // 是否显示「查看更多」：以群资料中的总人数为准（大群只拉了一页成员，members.count 远小于实际人数）
    NSInteger reportedTotal = [BasicTool getIntValue:(self.groupInfoForInit.g_member_count ?: @"") defaultVal:-1];
    if (reportedTotal < 0) {
        reportedTotal = (NSInteger)members.count;
    }
    BOOL hasMoreThan4Rows = (reportedTotal > maxMembersIn4Rows);

    // 聊天信息页仅显示最多4行成员，更多通过「查看更多群成员」进入列表模式（搜索+字母索引）
    NSInteger showCount = MIN(members.count, maxMembersIn4Rows);
    NSInteger maxRows = MEMBER_MAX_ROWS;

    NSInteger totalItems = showCount + buttonCount;
    NSInteger rows = (totalItems + itemsPerRow - 1) / itemsPerRow;
    if (maxRows != NSIntegerMax && rows > maxRows) rows = maxRows;

    // 显示/隐藏"查看更多"或"收起"按钮
    BOOL showToggleRow = hasMoreThan4Rows;
    self.viewMoreMembersRow.hidden = !showToggleRow;
    self.viewMoreMembersSep.hidden = !showToggleRow;

    self.viewMoreMembersLabel.text = @"查看更多群成员";

    // 切换底部约束
    self.memberGridBottomToSection.active = !showToggleRow;
    self.viewMoreBottomToSection.active = showToggleRow;

    CGFloat hSpacing = MEMBER_H_SPACING;
    if (itemsPerRow > 1) {
        hSpacing = (containerWidth - itemsPerRow * itemWidth) / (itemsPerRow - 1);
        if (hSpacing < 10) hSpacing = 10;
    }

    CGFloat rowHeight = MEMBER_AVATAR_SIZE + 4 + MEMBER_NAME_HEIGHT;

    for (NSInteger i = 0; i < totalItems; i++) {
        NSInteger row = i / itemsPerRow;
        NSInteger col = i % itemsPerRow;
        if (maxRows != NSIntegerMax && row >= maxRows) break;

        CGFloat x = col * (itemWidth + hSpacing);
        CGFloat y = row * (rowHeight + MEMBER_V_SPACING);

        if (i < showCount) {
            GroupMemberEntity *member = members[i];
            UIView *item = [self buildMemberItem:member atIndex:i];
            item.frame = CGRectMake(x, y, itemWidth, rowHeight);
            [self.memberGridContainer addSubview:item];
        } else {
            NSInteger btnIdx = i - showCount;
            UIView *btn = nil;
            if (btnIdx == 0) {
                btn = [self buildAddButton];
            } else {
                btn = [self buildRemoveButton];
            }
            btn.frame = CGRectMake(x, y, itemWidth, MEMBER_AVATAR_SIZE);
            [self.memberGridContainer addSubview:btn];
        }
    }

    // 更新高度
    CGFloat totalHeight = rows * (rowHeight + MEMBER_V_SPACING);
    if (totalHeight < rowHeight) totalHeight = rowHeight;
    self.memberGridHeightConstraint.constant = totalHeight;
}

- (UIView *)buildMemberItem:(GroupMemberEntity *)member atIndex:(NSInteger)index
{
    UIView *container = [[UIView alloc] init];

    UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, MEMBER_AVATAR_SIZE, MEMBER_AVATAR_SIZE)];
    avatar.image = [UIImage imageNamed:@"default_avatar_60"];
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.layer.cornerRadius = MEMBER_AVATAR_SIZE * 0.5f;
    avatar.layer.masksToBounds = YES;
    avatar.userInteractionEnabled = YES;
    avatar.tag = index;
    [container addSubview:avatar];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapMemberAvatar:)];
    [avatar addGestureRecognizer:tap];

    // 加载头像（支持视频头像播放）
    [RBAvatarView setAvatarWithFileName:member.userAvatarFileName uid:member.user_uid onImageView:avatar placeholder:nil];

    // 群主/管理员标签（右上角）
    if (member.role >= 1) {
        NSString *badgeText = (member.role == 2) ? @"群主" : @"管理";
        UIColor *badgeBg = (member.role == 2) ? [UIColor colorWithRed:1.0 green:0.65 blue:0.0 alpha:1.0] : [UIColor colorWithRed:0.3 green:0.65 blue:1.0 alpha:1.0];

        UILabel *badge = [[UILabel alloc] init];
        badge.text = badgeText;
        badge.font = [UIFont systemFontOfSize:8 weight:UIFontWeightMedium];
        badge.textColor = [UIColor whiteColor];
        badge.backgroundColor = badgeBg;
        badge.textAlignment = NSTextAlignmentCenter;
        badge.layer.cornerRadius = 2;
        badge.layer.masksToBounds = YES;
        [badge sizeToFit];

        CGFloat badgeW = badge.frame.size.width + 6;
        CGFloat badgeH = 14;
        badge.frame = CGRectMake(MEMBER_AVATAR_SIZE - badgeW + 2, -2, badgeW, badgeH);
        [container addSubview:badge];
        // 确保badge在avatar上层
        [container bringSubviewToFront:badge];
    }

    // 名字
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, MEMBER_AVATAR_SIZE + 4, MEMBER_AVATAR_SIZE, MEMBER_NAME_HEIGHT)];
    NSString *displayName = [GroupsProvider getNickNameInGroup:member.nickname and:member.nickname_ingroup];
    nameLabel.text = displayName ?: member.user_uid;
    nameLabel.font = [UIFont systemFontOfSize:10];
    nameLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [container addSubview:nameLabel];

    return container;
}

- (UIView *)buildAddButton
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, MEMBER_AVATAR_SIZE, MEMBER_AVATAR_SIZE);
    btn.layer.cornerRadius = MEMBER_AVATAR_SIZE * 0.5f;
    btn.layer.masksToBounds = YES;
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [UIColor colorWithRed:0.85 green:0.85 blue:0.85 alpha:1.0].CGColor;
    btn.backgroundColor = [UIColor whiteColor];
    [btn setImage:[self plusImage] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(clickInviteMembers) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (UIView *)buildRemoveButton
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, MEMBER_AVATAR_SIZE, MEMBER_AVATAR_SIZE);
    btn.layer.cornerRadius = MEMBER_AVATAR_SIZE * 0.5f;
    btn.layer.masksToBounds = YES;
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [UIColor colorWithRed:0.85 green:0.85 blue:0.85 alpha:1.0].CGColor;
    btn.backgroundColor = [UIColor whiteColor];
    [btn setImage:[self minusImage] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(clickViewMembers) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

// 程序化绘制 "+" 图标
- (UIImage *)plusImage
{
    CGFloat size = 24;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0].CGColor);
    CGContextSetLineWidth(ctx, 1.5);
    CGContextMoveToPoint(ctx, size/2, 4);
    CGContextAddLineToPoint(ctx, size/2, size - 4);
    CGContextMoveToPoint(ctx, 4, size/2);
    CGContextAddLineToPoint(ctx, size - 4, size/2);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

// 程序化绘制 "-" 图标
- (UIImage *)minusImage
{
    CGFloat size = 24;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0].CGColor);
    CGContextSetLineWidth(ctx, 1.5);
    CGContextMoveToPoint(ctx, 4, size/2);
    CGContextAddLineToPoint(ctx, size - 4, size/2);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

// ===== 群信息区域 =====
- (UIView *)buildGroupInfoSection
{
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];

    // 群聊ID + 群头像
    UIView *row1 = [self buildGroupIdAndAvatarRow];
    [section addSubview:row1];
    UIView *sep1 = [self buildSeparator];
    [section addSubview:sep1];

    // 群聊名称
    UIView *row2 = [self buildArrowRowWithTitle:@"群聊名称" valueLabel:&_groupNameValueLabel action:@selector(clickGroupName)];
    [section addSubview:row2];
    UIView *sep2 = [self buildSeparator];
    [section addSubview:sep2];

    // 群二维码
    UIView *row3 = [self buildQRCodeRow];
    [section addSubview:row3];
    UIView *sep3 = [self buildSeparator];
    [section addSubview:sep3];

    // 群公告
    UIView *row4 = [self buildArrowRowWithTitle:@"群公告" valueLabel:&_noticeValueLabel action:@selector(clickNotice)];
    [section addSubview:row4];
    UIView *sep4 = [self buildSeparator];
    [section addSubview:sep4];

    // 群管理（管理员/群主可见）
    self.adminRow = [self buildArrowRow:@"群管理" action:@selector(clickGroupManage)];
    self.adminRow.hidden = YES;
    [section addSubview:self.adminRow];
    self.adminSep = [self buildSeparator];
    self.adminSep.hidden = YES;
    [section addSubview:self.adminSep];

    // 群管理行高度约束（隐藏时为0，显示时为56）
    self.adminRowHeightConstraint = [self.adminRow.heightAnchor constraintEqualToConstant:0];
    self.adminRowHeightConstraint.active = YES;
    self.adminSepHeightConstraint = [self.adminSep.heightAnchor constraintEqualToConstant:0];
    self.adminSepHeightConstraint.active = YES;

    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [row1.topAnchor constraintEqualToAnchor:section.topAnchor],
        [row1.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row1.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row1.heightAnchor constraintEqualToConstant:68],

        [sep1.topAnchor constraintEqualToAnchor:row1.bottomAnchor],
        [sep1.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [sep1.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [sep1.heightAnchor constraintEqualToConstant:0.5],

        [row2.topAnchor constraintEqualToAnchor:sep1.bottomAnchor],
        [row2.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row2.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row2.heightAnchor constraintEqualToConstant:56],

        [sep2.topAnchor constraintEqualToAnchor:row2.bottomAnchor],
        [sep2.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [sep2.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [sep2.heightAnchor constraintEqualToConstant:0.5],

        [row3.topAnchor constraintEqualToAnchor:sep2.bottomAnchor],
        [row3.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row3.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row3.heightAnchor constraintEqualToConstant:56],

        [sep3.topAnchor constraintEqualToAnchor:row3.bottomAnchor],
        [sep3.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [sep3.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [sep3.heightAnchor constraintEqualToConstant:0.5],

        [row4.topAnchor constraintEqualToAnchor:sep3.bottomAnchor],
        [row4.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row4.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row4.heightAnchor constraintEqualToConstant:56],

        [sep4.topAnchor constraintEqualToAnchor:row4.bottomAnchor],
        [sep4.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [sep4.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [sep4.heightAnchor constraintEqualToConstant:0.5],

        [self.adminRow.topAnchor constraintEqualToAnchor:sep4.bottomAnchor],
        [self.adminRow.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [self.adminRow.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],

        [self.adminSep.topAnchor constraintEqualToAnchor:self.adminRow.bottomAnchor],
        [self.adminSep.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [self.adminSep.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [self.adminSep.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
    ]];

    return section;
}

// ===== 开关区域1: 消息免打扰 / 置顶聊天 / 保存到通讯录 =====
- (UIView *)buildSwitchSection1
{
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];

    UIView *row1 = [self buildSwitchRow:@"消息免打扰" switchRef:&_switchMsgTone action:@selector(switchMsgToneClicked)];
    [section addSubview:row1];
    UIView *sep1 = [self buildSeparator];
    [section addSubview:sep1];

    UIView *row2 = [self buildSwitchRow:@"置顶聊天" switchRef:&_switchAlwaysTop action:@selector(switchAlwaysTopClicked)];
    [section addSubview:row2];

    [NSLayoutConstraint activateConstraints:@[
        [row1.topAnchor constraintEqualToAnchor:section.topAnchor],
        [row1.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row1.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row1.heightAnchor constraintEqualToConstant:56],

        [sep1.topAnchor constraintEqualToAnchor:row1.bottomAnchor],
        [sep1.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [sep1.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [sep1.heightAnchor constraintEqualToConstant:0.5],

        [row2.topAnchor constraintEqualToAnchor:sep1.bottomAnchor],
        [row2.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row2.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row2.heightAnchor constraintEqualToConstant:56],

        [row2.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
    ]];

    return section;
}

// ===== 我的设置区域: 我在本群的昵称 / 显示群成员昵称 =====
- (UIView *)buildMySettingsSection
{
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];

    UIView *row1 = [self buildArrowRowWithTitle:@"我在本群的昵称" valueLabel:&_nicknameInGroupValueLabel action:@selector(clickNicknameInGroup)];
    [section addSubview:row1];
    UIView *sep = [self buildSeparator];
    [section addSubview:sep];

    UIView *row2 = [self buildSwitchRow:@"显示群成员昵称" switchRef:&_switchShowMemberNickname action:@selector(switchShowMemberNicknameClicked)];
    [section addSubview:row2];

    [NSLayoutConstraint activateConstraints:@[
        [row1.topAnchor constraintEqualToAnchor:section.topAnchor],
        [row1.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row1.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row1.heightAnchor constraintEqualToConstant:56],

        [sep.topAnchor constraintEqualToAnchor:row1.bottomAnchor],
        [sep.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [sep.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [sep.heightAnchor constraintEqualToConstant:0.5],

        [row2.topAnchor constraintEqualToAnchor:sep.bottomAnchor],
        [row2.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [row2.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [row2.heightAnchor constraintEqualToConstant:56],

        [row2.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
    ]];

    // 显示群成员昵称默认为YES
    BOOL showMemberNick = [UserDefaultsToolKits getShowGroupMemberNickname:self.groupInfoForInit.g_id];
    [self.switchShowMemberNickname setOn:showMemberNick animated:NO];

    return section;
}

// ===== 底部按钮区域 =====
- (UIView *)buildBottomSection
{
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];

    // 退出群聊 / 解散群聊
    UIButton *exitBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    exitBtn.translatesAutoresizingMaskIntoConstraints = NO;
    if ([self localUserIsGroupOwner]) {
        [exitBtn setTitle:@"解散该群聊" forState:UIControlStateNormal];
        [exitBtn addTarget:self action:@selector(clickDismissGroup) forControlEvents:UIControlEventTouchUpInside];
    } else {
        [exitBtn setTitle:@"退出群聊" forState:UIControlStateNormal];
        [exitBtn addTarget:self action:@selector(clickExitGroup) forControlEvents:UIControlEventTouchUpInside];
    }
    [exitBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    exitBtn.titleLabel.font = [UIFont systemFontOfSize:17];
    [section addSubview:exitBtn];

    [NSLayoutConstraint activateConstraints:@[
        [exitBtn.topAnchor constraintEqualToAnchor:section.topAnchor],
        [exitBtn.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [exitBtn.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [exitBtn.heightAnchor constraintEqualToConstant:56],
        [exitBtn.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
    ]];

    return section;
}

#pragma mark - Reusable Row Builders

// 带箭头的行（带右侧值标签）
- (UIView *)buildArrowRowWithTitle:(NSString *)title valueLabel:(UILabel *__strong *)valueLabelRef action:(SEL)action
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:btn];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:17];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    label.userInteractionEnabled = NO;
    [row addSubview:label];

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [UIFont systemFontOfSize:15];
    valueLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.userInteractionEnabled = NO;
    [row addSubview:valueLabel];

    UIImageView *arrow = [[UIImageView alloc] init];
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.image = [UIImage imageNamed:@"common_list_rightarrow_icon_nor"];
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    arrow.userInteractionEnabled = NO;
    [row addSubview:arrow];

    if (valueLabelRef) {
        *valueLabelRef = valueLabel;
    }

    [NSLayoutConstraint activateConstraints:@[
        [btn.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:row.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrow.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [arrow.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrow.widthAnchor constraintEqualToConstant:8],
        [arrow.heightAnchor constraintEqualToConstant:14],
        [valueLabel.trailingAnchor constraintEqualToAnchor:arrow.leadingAnchor constant:-8],
        [valueLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:label.trailingAnchor constant:10],
    ]];

    return row;
}

// 群聊ID + 群头像同一行
- (UIView *)buildGroupIdAndAvatarRow
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];

    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    copyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [copyButton addTarget:self action:@selector(clickGroupIdRow) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:copyButton];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"群聊ID";
    label.font = [UIFont systemFontOfSize:17];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    [row addSubview:label];

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [UIFont systemFontOfSize:14];
    valueLabel.textColor = HexColor(0x8E8E93);
    valueLabel.textAlignment = NSTextAlignmentRight;
    self.groupIdValueLabel = valueLabel;
    [row addSubview:valueLabel];

    UIImageView *avatarView = [[UIImageView alloc] init];
    avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarView.image = [UIImage imageNamed:@"groupchat_groups_icon_default"];
    avatarView.contentMode = UIViewContentModeScaleAspectFill;
    avatarView.layer.cornerRadius = 20.0f;
    avatarView.layer.masksToBounds = YES;
    avatarView.userInteractionEnabled = YES;
    self.groupInfoAvatarView = avatarView;
    [row addSubview:avatarView];

    UITapGestureRecognizer *avatarTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clickGroupAvatarPreview)];
    [avatarView addGestureRecognizer:avatarTap];

    UIImageView *arrow = [[UIImageView alloc] init];
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.image = [UIImage imageNamed:@"common_list_rightarrow_icon_nor"];
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    [row addSubview:arrow];

    UIButton *avatarButton = [UIButton buttonWithType:UIButtonTypeCustom];
    avatarButton.translatesAutoresizingMaskIntoConstraints = NO;
    [avatarButton addTarget:self action:@selector(clickGroupAvatarPreview) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:avatarButton];

    [NSLayoutConstraint activateConstraints:@[
        [copyButton.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [copyButton.topAnchor constraintEqualToAnchor:row.topAnchor],
        [copyButton.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [copyButton.trailingAnchor constraintEqualToAnchor:avatarView.leadingAnchor constant:-8],

        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],

        [arrow.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [arrow.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrow.widthAnchor constraintEqualToConstant:8],
        [arrow.heightAnchor constraintEqualToConstant:14],

        [avatarView.trailingAnchor constraintEqualToAnchor:arrow.leadingAnchor constant:-10],
        [avatarView.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [avatarView.widthAnchor constraintEqualToConstant:40],
        [avatarView.heightAnchor constraintEqualToConstant:40],

        [avatarButton.topAnchor constraintEqualToAnchor:row.topAnchor],
        [avatarButton.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [avatarButton.leadingAnchor constraintEqualToAnchor:avatarView.leadingAnchor constant:-8],
        [avatarButton.trailingAnchor constraintEqualToAnchor:arrow.trailingAnchor],

        [valueLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:label.trailingAnchor constant:12],
        [valueLabel.trailingAnchor constraintEqualToAnchor:avatarView.leadingAnchor constant:-12],
    ]];

    return row;
}

// 简单带箭头的行（无值标签）
- (UIView *)buildArrowRow:(NSString *)title action:(SEL)action
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:btn];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:17];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    label.userInteractionEnabled = NO;
    [row addSubview:label];

    UIImageView *arrow = [[UIImageView alloc] init];
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.image = [UIImage imageNamed:@"common_list_rightarrow_icon_nor"];
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    arrow.userInteractionEnabled = NO;
    [row addSubview:arrow];

    [NSLayoutConstraint activateConstraints:@[
        [btn.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:row.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrow.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [arrow.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrow.widthAnchor constraintEqualToConstant:8],
        [arrow.heightAnchor constraintEqualToConstant:14],
    ]];

    return row;
}

// 二维码行（右侧有二维码图标 + 箭头）
- (UIView *)buildQRCodeRow
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:@selector(clickQr) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:btn];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"群二维码";
    label.font = [UIFont systemFontOfSize:17];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    label.userInteractionEnabled = NO;
    [row addSubview:label];

    UIImageView *qrIcon = [[UIImageView alloc] init];
    qrIcon.translatesAutoresizingMaskIntoConstraints = NO;
    qrIcon.image = [UIImage imageNamed:@"sns_profile_qrcode"];
    qrIcon.contentMode = UIViewContentModeScaleAspectFit;
    qrIcon.userInteractionEnabled = NO;
    [row addSubview:qrIcon];

    UIImageView *arrow = [[UIImageView alloc] init];
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.image = [UIImage imageNamed:@"common_list_rightarrow_icon_nor"];
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    arrow.userInteractionEnabled = NO;
    [row addSubview:arrow];

    [NSLayoutConstraint activateConstraints:@[
        [btn.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:row.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrow.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [arrow.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [arrow.widthAnchor constraintEqualToConstant:8],
        [arrow.heightAnchor constraintEqualToConstant:14],
        [qrIcon.trailingAnchor constraintEqualToAnchor:arrow.leadingAnchor constant:-8],
        [qrIcon.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [qrIcon.widthAnchor constraintEqualToConstant:20],
        [qrIcon.heightAnchor constraintEqualToConstant:20],
    ]];

    return row;
}

// 开关行
- (UIView *)buildSwitchRow:(NSString *)title switchRef:(UISwitch *__strong *)switchRef action:(SEL)action
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor whiteColor];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:btn];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:17];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    label.userInteractionEnabled = NO;
    [row addSubview:label];

    UISwitch *sw = [[UISwitch alloc] init];
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    sw.onTintColor = [UIColor colorWithRed:0.2039 green:0.7804 blue:0.349 alpha:1.0];
    sw.transform = CGAffineTransformMakeScale(0.9, 0.9);
    sw.userInteractionEnabled = NO;
    [row addSubview:sw];

    if (switchRef) {
        *switchRef = sw;
    }

    [NSLayoutConstraint activateConstraints:@[
        [btn.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:row.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];

    return row;
}

// 箭头Section（通用）
- (UIView *)buildArrowSection:(NSArray<NSDictionary *> *)items
{
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.backgroundColor = [UIColor whiteColor];

    UIView *prev = nil;
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *item = items[i];
        UIView *row = [self buildArrowRow:item[@"title"] action:NSSelectorFromString(item[@"action"])];
        [section addSubview:row];

        [NSLayoutConstraint activateConstraints:@[
            [row.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
            [row.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
            [row.heightAnchor constraintEqualToConstant:56],
        ]];

        if (prev) {
            [row.topAnchor constraintEqualToAnchor:prev.bottomAnchor].active = YES;
            UIView *sep = [self buildSeparator];
            [section addSubview:sep];
            [NSLayoutConstraint activateConstraints:@[
                [sep.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
                [sep.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
                [sep.topAnchor constraintEqualToAnchor:prev.bottomAnchor],
                [sep.heightAnchor constraintEqualToConstant:0.5],
            ]];
        } else {
            [row.topAnchor constraintEqualToAnchor:section.topAnchor].active = YES;
        }
        prev = row;
    }

    if (prev) {
        [prev.bottomAnchor constraintEqualToAnchor:section.bottomAnchor].active = YES;
    }

    return section;
}

// 分隔线
- (UIView *)buildSeparator
{
    UIView *sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
    return sep;
}


#pragma mark - Data Loading & Refresh

- (void)refreshGroupInfoFromServerIfNeeded
{
    if (self.groupInfoForInit == nil || [BasicTool isStringEmpty:self.groupInfoForInit.g_id]) {
        return;
    }
    if (![ClientCoreSDK sharedInstance].connectedToServer) {
        return;
    }
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    if (localUserInfo == nil || [BasicTool isStringEmpty:localUserInfo.user_uid]) {
        return;
    }

    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitGetGroupInfoToServer:self.groupInfoForInit.g_id
                                                       myUserId:localUserInfo.user_uid
                                                       complete:^(BOOL sucess, GroupEntity *groupInfo) {
        __strong typeof(wself) self = wself;
        if (!self || !sucess || groupInfo == nil || ![groupInfo myselfIsInGroup]) {
            return;
        }
        [[[IMClientManager sharedInstance] getGroupsProvider] updateGroup:groupInfo];
        GroupEntity *latest = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.groupInfoForInit.g_id];
        if (latest != nil) {
            self.groupInfoForInit = latest;
            [self refreshDatas];
        }
    } hudParentView:nil];
}

- (void)refreshDatas
{
    if (self.groupInfoForInit == nil) {
        [BasicTool showAlertError:@"参数异常，请退出后再试！" parent:self];
        return;
    }

    // 标题（与自定义顶栏同步）
    NSString *memberCount = self.groupInfoForInit.g_member_count ?: @"";
    self.title = [NSString stringWithFormat:@"聊天信息 (%@)", memberCount];
    [self rb_installPlainCustomNavigationBarWithTitle:self.title];

    // 群名称（最多显示20个字符）
    NSString *gName = self.groupInfoForInit.g_name;
    if (![BasicTool isStringEmpty:gName] && gName.length > 20) {
        gName = [[gName substringToIndex:20] stringByAppendingString:@"..."];
    }
    self.groupIdValueLabel.text = [BasicTool isStringEmpty:self.groupInfoForInit.g_id] ? @"未设置" : self.groupInfoForInit.g_id;
    self.groupNameValueLabel.text = [BasicTool isStringEmpty:gName] ? @"未命名" : gName;

    // 群公告
    BOOL noticeIsEmpty = [BasicTool isStringEmpty:[BasicTool trim:self.groupInfoForInit.g_notice]];
    self.noticeValueLabel.text = noticeIsEmpty ? @"未设置" : self.groupInfoForInit.g_notice;

    // 我在本群的昵称
    self.nicknameInGroupValueLabel.text = [GroupsProvider getMyNickNameInGroup:self.groupInfoForInit.nickname_ingroup];

    // 刷新开关
    [self refreshMsgToneSwitch];
    [self refreshAlwaysTopSwitch];

    // 刷新管理区域可见性
    [self refreshAdminVisibility];

    self.groupInfoAvatarView.image = [UIImage imageNamed:@"groupchat_groups_icon_default"];
    if (![BasicTool isStringEmpty:self.groupInfoForInit.g_id]) {
        __weak typeof(self) weakSelf = self;
        [FileDownloadHelper loadGroupAvatar:self.groupInfoForInit.g_id logTag:@"GroupInfo-HeaderAvatar" complete:^(BOOL sucess, UIImage *img) {
            if (sucess && img != nil) {
                weakSelf.groupInfoAvatarView.image = img;
            }
        }];
    }
}

- (void)refreshAdminVisibility
{
    BOOL shouldShowAdmin = (self.myRoleInGroup >= 1);
    self.adminRow.hidden = !shouldShowAdmin;
    self.adminSep.hidden = !shouldShowAdmin;
    // 动态调整高度：普通用户完全不占用空间
    self.adminRowHeightConstraint.constant = shouldShowAdmin ? 56 : 0;
    self.adminSepHeightConstraint.constant = shouldShowAdmin ? 0.5 : 0;
    self.adminRow.clipsToBounds = YES;
    self.adminSep.clipsToBounds = YES;
}

- (void)refreshMsgToneSwitch
{
    BOOL isDisturb = ![UserDefaultsToolKits isChatMsgToneOpen:self.groupInfoForInit.g_id];
    [self.switchMsgTone setOn:isDisturb animated:YES];
}

- (void)refreshAlwaysTopSwitch
{
    BOOL isAlwaysTop = [[[IMClientManager sharedInstance] getAlarmsProvider] isAlwaysTop:AMT_groupChatMessage dataId:self.groupInfoForInit.g_id];
    [self.switchAlwaysTop setOn:isAlwaysTop animated:YES];
}

- (void)loadGroupMembers
{
    __weak typeof(self) safeSelf = self;
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (myUid == nil || self.groupInfoForInit == nil) return;
    // g_id 为空时 HTTP 层 @{@"gid": gid} 会触发 NSDictionary 插 nil 崩溃，此处直接跳过
    if (self.groupInfoForInit.g_id.length == 0) return;

    NSUInteger generation = ++self.groupMembersLoadGeneration;

    [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:self.groupInfoForInit.g_id
                                                              requestUid:myUid
                                                                    page:GROUP_INFO_MEMBER_LIST_PAGE
                                                                pageSize:GROUP_INFO_MEMBER_LIST_PAGE_SIZE
                                                                complete:^(BOOL sucess, NSMutableArray<GroupMemberEntity *> *groupMembersList) {
        if (!sucess || groupMembersList == nil) return;

        // HttpService 在 hudParentView 为 nil 时可能在网络线程回调；属性写入与 refreshMemberGrid 必须统一在主线程，避免与 UI 并发访问 membersList / myRoleInGroup
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(safeSelf) strongSelf = safeSelf;
            if (strongSelf == nil) return;
            if (strongSelf.groupMembersLoadGeneration != generation) return;

            for (GroupMemberEntity *member in groupMembersList) {
                if ([member.user_uid isEqualToString:myUid]) {
                    strongSelf.myRoleInGroup = member.role;
                    break;
                }
            }

            [groupMembersList sortUsingComparator:^NSComparisonResult(GroupMemberEntity *a, GroupMemberEntity *b) {
                if (a.role > b.role) return NSOrderedAscending;
                if (a.role < b.role) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            strongSelf.membersList = groupMembersList;

            [strongSelf refreshMemberGrid];
            [strongSelf refreshAdminVisibility];
        });
    } hudParentView:nil];
}


#pragma mark - Event Handlers

- (void)tapMemberAvatar:(UITapGestureRecognizer *)gesture
{
    NSInteger index = gesture.view.tag;
    if (self.membersList && index < (NSInteger)self.membersList.count) {
        GroupMemberEntity *member = self.membersList[index];
        // 带群成员信息跳转（显示入群时间和邀请人）
        [QueryFriendInfoAsync gotoWatchUserInfo:member.user_uid withInfo:nil nav:self.navigationController view:self.view vc:self addSource:@"group" groupMemberInfo:member];
    }
}

// 群聊名称
- (void)clickGroupName
{
    if (![GroupsProvider isGroupOwner:self.groupInfoForInit.g_owner_user_uid]) {
        [BasicTool showAlertInfo:@"只有群主可以修改群名称!" parent:self];
        return;
    }
    [ViewControllerFactory goGroupInfoEditViewController:self.navigationController withChangeType:IS_CHANGE_GROUP_NAME andGroupInfo:self.groupInfoForInit];
}

// 群二维码
- (void)clickQr
{
    [ViewControllerFactory goQRCodeGenerateGroupViewController:self.navigationController withId:self.groupInfoForInit.g_id];
}

// 群公告
- (void)clickNotice
{
    if (self.myRoleInGroup < 1 && [BasicTool isStringEmpty:self.groupInfoForInit.g_notice]) {
        [BasicTool showAlertInfo:@"只有管理员或群主可以编辑群公告!" parent:self];
        return;
    }
    GroupInfoEditViewController *vc = [ViewControllerFactory goGroupInfoEditViewController:self.navigationController withChangeType:IS_CHANGE_GROUP_NOTICE andGroupInfo:self.groupInfoForInit];
    vc.resultBackdelegate = self;
}

// 群聊ID行：复制群ID
- (void)clickGroupIdRow
{
    NSString *gid = self.groupInfoForInit.g_id ?: @"";
    if (gid.length == 0) {
        [APP showToastWarn:@"群聊ID为空"];
        return;
    }
    [UIPasteboard generalPasteboard].string = gid;
    [APP showUserDefineToast_OK:@"群聊ID已复制"];
}

// 群头像预览（管理员/群主可继续修改）
- (void)clickGroupAvatarPreview
{
    UIImage *avatarImage = self.groupInfoAvatarView.image;
    if (avatarImage == nil) {
        [APP showToastWarn:@"群头像加载中"];
        return;
    }

    BOOL canEditAvatar = (self.myRoleInGroup >= 1);
    if (!canEditAvatar) {
        [BasicTool showImage:avatarImage];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"查看头像", @"更换群头像"]
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (index == 1) {
            [BasicTool showImage:avatarImage];
        } else if (index == 2) {
            [strongSelf clickSetGroupAvatar];
        }
    }];
}

// 群管理（管理员/群主进入管理页面）
- (void)clickGroupManage
{
    GroupManageViewController *vc = [[GroupManageViewController alloc] initWithGroupInfo:self.groupInfoForInit myRole:self.myRoleInGroup];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - GroupManageDelegate

- (void)groupManageDidRequestSetAvatar
{
    // 群头像设置完成后，刷新群信息页面
    [self refreshDatas];
}

// 备注
- (void)clickRemark
{
    [ViewControllerFactory goGroupInfoEditViewController:self.navigationController withChangeType:IS_CHANGE_GROUP_REMARK andGroupInfo:self.groupInfoForInit];
}

// 查找聊天内容
- (void)clickSearchHistory
{
    [ViewControllerFactory goChatSearchMenuViewController:self.navigationController
                                                 chatType:MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP
                                                   dataId:self.groupInfoForInit.g_id
                                              isGroupChat:YES];
}

// 设置当前聊天背景
- (void)clickChatBackground
{
    ChatBackgroundViewController *vc = [[ChatBackgroundViewController alloc] initWithChatId:self.groupInfoForInit.g_id];
    [self.navigationController pushViewController:vc animated:YES];
}

// 消息免打扰（1008-4-38）
- (void)switchMsgToneClicked
{
    BOOL wasToneOpen = [UserDefaultsToolKits isChatMsgToneOpen:self.groupInfoForInit.g_id];
    BOOL targetMuteOn = wasToneOpen;
    NSString *luid = [[ClientCoreSDK sharedInstance] currentLoginUserId];
    if ([BasicTool isStringEmpty:luid]) {
        [APP showToastWarn:@"未登录"];
        [self refreshMsgToneSwitch];
        return;
    }

    [UserDefaultsToolKits setChatMsgToneOpen:!wasToneOpen chatId:self.groupInfoForInit.g_id];
    [self refreshMsgToneSwitch];

    __weak typeof(self) safeSelf = self;
    [[HttpRestHelper sharedInstance] submitConversationMsgMuteToServer:luid partnerId:self.groupInfoForInit.g_id chatType:@"2" muteOn:targetMuteOn complete:^(BOOL sucess, NSString *resultCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!sucess) {
                [UserDefaultsToolKits setChatMsgToneOpen:wasToneOpen chatId:safeSelf.groupInfoForInit.g_id];
                [safeSelf refreshMsgToneSwitch];
                [APP showToastWarn:@"免打扰设置同步失败"];
            }
        });
    } hudParentView:self.view];
}

// 置顶聊天
- (void)switchAlwaysTopClicked
{
    BOOL isAlwaysTopOld = [[[IMClientManager sharedInstance] getAlarmsProvider] isAlwaysTop:AMT_groupChatMessage dataId:self.groupInfoForInit.g_id];
    [AlarmsProvider doSetAlwaysTopNow:!isAlwaysTopOld alarmType:AMT_groupChatMessage dataId:self.groupInfoForInit.g_id title:self.groupInfoForInit.g_name];
    [self refreshAlwaysTopSwitch];
}

// 显示群成员昵称
- (void)switchShowMemberNicknameClicked
{
    BOOL current = self.switchShowMemberNickname.isOn;
    [self.switchShowMemberNickname setOn:!current animated:YES];
    [UserDefaultsToolKits setShowGroupMemberNickname:!current gid:self.groupInfoForInit.g_id];
}

// 我在本群的昵称
- (void)clickNicknameInGroup
{
    [ViewControllerFactory goGroupInfoEditViewController:self.navigationController withChangeType:IS_CHANGE_MY_NICKNAME_IN_GROUP andGroupInfo:self.groupInfoForInit];
}

// 邀请入群
- (void)clickInviteMembers
{
    [ViewControllerFactory goGroupMemberViewController:self.navigationController usedFor:USED_FOR_INVITE_MEMBERS gid:self.groupInfoForInit.g_id isGroupOwner:[self localUserIsGroupOwner] defaultSelectedUid:nil];
}

// 查看/管理群成员（传入群成员隐私保护，普通成员在开启隐私时不能查看他人资料）
- (void)clickViewMembers
{
    BOOL canManage = [self localUserIsGroupOwner] || self.myRoleInGroup >= 1;
    [ViewControllerFactory goGroupMemberViewController:self.navigationController usedFor:USED_FOR_VIEW_OR_MANAGER_MEMBERS gid:self.groupInfoForInit.g_id isGroupOwner:canManage defaultSelectedUid:nil memberPrivacy:self.groupInfoForInit.g_member_privacy];
}

// 查看更多群成员：跳转到列表模式（带搜索框和26字母索引），不再就地展开
- (void)clickViewAllMembers
{
    BOOL canManage = [self localUserIsGroupOwner] || self.myRoleInGroup >= 1;
    [ViewControllerFactory goGroupMemberViewController:self.navigationController usedFor:USED_FOR_VIEW_OR_MANAGER_MEMBERS gid:self.groupInfoForInit.g_id isGroupOwner:canManage defaultSelectedUid:nil memberPrivacy:self.groupInfoForInit.g_member_privacy];
}

// 清空聊天记录
- (void)clickClearHistory
{
    __weak typeof(self) safeSelf = self;
    [LPActionSheet showActionSheetWithTitle:@"确定清空本群的聊天记录吗？"
                          cancelButtonTitle:NSLocalizedString(@"general_cancel", @"")
                     destructiveButtonTitle:@"确认清空"
                          otherButtonTitles:nil
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == -1) {
            [ChatInfoViewController clearHistory:AMT_groupChatMessage dataId:safeSelf.groupInfoForInit.g_id viewForHud:safeSelf.view];
        }
    }];
}

// 投诉
- (void)clickComplaint
{
    LPActionSheetBlock jubaoCauseActionSheetHandler = ^(LPActionSheet *actionSheet, NSInteger index) {
        if (index > 0) {
            [APP showUserDefineToast_OK:@"举报成功!"];
        }
    };

    [LPActionSheet showActionSheetWithTitle:@"请选择举报原因："
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"色情", @"欺诈", @"广告骚扰", @"敏感信息", @"侵权", @"赌博", @"其它"]
                                    handler:jubaoCauseActionSheetHandler];
}


#pragma mark - 底部按钮事件

// 解散本群（群主可用）
- (void)clickDismissGroup
{
    if (![self localUserIsGroupOwner]) {
        [BasicTool showAlertInfo:@"只有群主才能解散群!" parent:self];
        return;
    }

    __weak typeof(self) safeSelf = self;

    [LPActionSheet showActionSheetWithTitle:@"解散群后，所有与此群有关的记录都会被删除。"
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:@"确认解散"
                          otherButtonTitles:nil
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == -1) {
            UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
            if (localUserInfo != nil) {
                [[HttpRestHelper sharedInstance] submitDismissGroupToServer:localUserInfo.user_uid owner_nickname:[GroupsProvider getMyNickNameInGroup:safeSelf.groupInfoForInit.nickname_ingroup] gid:safeSelf.groupInfoForInit.g_id complete:^(BOOL sucess, NSString *resultCode) {
                    if (sucess) {
                        if ([@"2" isEqualToString:resultCode]) {
                            [BasicTool showAlertInfo:@"解散发起人已不是群主，本次解散失败" parent:safeSelf];
                        } else if ([@"1" isEqualToString:resultCode]) {
                            [[[IMClientManager sharedInstance] getAlarmsProvider] removeGroupChatMessageAlarm:safeSelf.groupInfoForInit.g_id];
                            [[[IMClientManager sharedInstance] getGroupsProvider] remove:[[[IMClientManager sharedInstance] getGroupsProvider] getIndex:safeSelf.groupInfoForInit.g_id] notify:YES];
                            [APP showUserDefineToast_OK:@"群已解散" atHide:nil];
                            [safeSelf doBack:NO];
                            [NotificationCenterFactory quitOrDismissGroupComplete_POST];
                        } else {
                            [BasicTool showAlertInfo:@"解散失败，请稍后再试！" parent:safeSelf];
                        }
                    } else {
                        [BasicTool showAlertInfo:@"解散失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
                    }
                } hudParentView:safeSelf.view];
            }
        }
    }];
}

// 退出本群（普通群员可用）
- (void)clickExitGroup
{
    if ([self localUserIsGroupOwner]) {
        [BasicTool showAlertInfo:@"您是本群群主，请使用\"解散本群\"!" parent:self];
        return;
    }

    __weak typeof(self) safeSelf = self;

    [LPActionSheet showActionSheetWithTitle:@"一旦退群，与此群有关的聊天记录会同时被删除。"
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:@"确认退群"
                          otherButtonTitles:nil
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == -1) {
            UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
            if (localUserInfo != nil) {
                NSArray<NSArray *> *toServer = @[@[safeSelf.groupInfoForInit.g_id, localUserInfo.user_uid, [GroupsProvider getMyNickNameInGroupEx:safeSelf.groupInfoForInit.g_id]]];

                [[HttpRestHelper sharedInstance] submitDeleteOrQuitGroupToServer:localUserInfo.user_uid del_opr_nickname:localUserInfo.nickname gid:safeSelf.groupInfoForInit.g_id membersBeDelete:toServer complete:^(BOOL sucess, NSString *resultCode) {
                    if (sucess) {
                        if ([@"1" isEqualToString:resultCode]) {
                            [[[IMClientManager sharedInstance] getAlarmsProvider] removeGroupChatMessageAlarm:safeSelf.groupInfoForInit.g_id];
                            [[[IMClientManager sharedInstance] getGroupsProvider] remove:[[[IMClientManager sharedInstance] getGroupsProvider] getIndex:safeSelf.groupInfoForInit.g_id] notify:YES];
                            [APP showUserDefineToast_OK:@"退群成功" atHide:nil];
                            [safeSelf doBack:NO];
                            [NotificationCenterFactory quitOrDismissGroupComplete_POST];
                        } else {
                            [BasicTool showAlertInfo:@"退群失败，请稍后再试！" parent:safeSelf];
                        }
                    } else {
                        [BasicTool showAlertInfo:@"退群失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
                    }
                } hudParentView:safeSelf.view];
            }
        }
    }];
}


#pragma mark - 群管理 Action Handlers

- (void)clickTransferGroup
{
    [ViewControllerFactory goGroupMemberViewController:self.navigationController usedFor:USED_FOR_TRANSFER gid:self.groupInfoForInit.g_id isGroupOwner:[GroupsProvider isGroupOwner:self.groupInfoForInit.g_owner_user_uid] defaultSelectedUid:nil];
}

- (void)clickSetGroupAvatar
{
    if (self.myRoleInGroup < 1) {
        [BasicTool showAlertInfo:@"只有管理员或群主可以设置群头像!" parent:self];
        return;
    }
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"拍照", @"从手机相册选择"]
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == 1) {
            [self.imagePickerWrapper takePhoto];
        } else if (index == 2) {
            [self.imagePickerWrapper takeAlbum:NO];
        }
    }];
}

- (void)clickSetAdmin
{
    if (self.myRoleInGroup < 2) {
        [BasicTool showAlertInfo:@"只有群主可以设置管理员!" parent:self];
        return;
    }

    __weak typeof(self) safeSelf = self;
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;

    [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:self.groupInfoForInit.g_id requestUid:myUid complete:^(BOOL sucess, NSMutableArray<GroupMemberEntity *> *membersList) {
        if (!sucess || membersList == nil) {
            [BasicTool showAlertError:@"获取成员列表失败!" parent:safeSelf];
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray *titles = [NSMutableArray array];
            NSMutableArray *members = [NSMutableArray array];
            for (GroupMemberEntity *m in membersList) {
                if ([m.user_uid isEqualToString:myUid]) continue;
                if (m.role != 0) continue;
                NSString *displayName = [GroupsProvider getNickNameInGroup:m.nickname and:m.nickname_ingroup];
                [titles addObject:displayName];
                [members addObject:m];
            }

            if (titles.count == 0) {
                [BasicTool showAlertInfo:@"暂无可设置的普通成员" parent:safeSelf];
                return;
            }

            [LPActionSheet showActionSheetWithTitle:@"选择要设为管理员的成员"
                                  cancelButtonTitle:@"取消"
                             destructiveButtonTitle:nil
                                  otherButtonTitles:titles
                                            handler:^(LPActionSheet *actionSheet, NSInteger index) {
                if (index > 0 && (index - 1) < (NSInteger)members.count) {
                    GroupMemberEntity *target = members[index - 1];
                    [[HttpRestHelper sharedInstance] submitSetGroupAdminToServer:myUid targetUid:target.user_uid gid:safeSelf.groupInfoForInit.g_id role:1 complete:^(BOOL sucess2, NSString *resultCode) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (sucess2 && [@"1" isEqualToString:resultCode]) {
                                [APP showUserDefineToast_OK:@"设为管理员成功" atHide:nil];
                            } else if ([@"-2" isEqualToString:resultCode]) {
                                [BasicTool showAlertInfo:@"权限不足，仅群主可操作" parent:safeSelf];
                            } else if ([@"-4" isEqualToString:resultCode]) {
                                [BasicTool showAlertInfo:@"目标用户不在群中" parent:safeSelf];
                            } else {
                                [BasicTool showAlertInfo:@"设为管理员失败" parent:safeSelf];
                            }
                        });
                    } hudParentView:safeSelf.view];
                }
            }];
        });
    } hudParentView:self.view];
}

- (void)clickCancelAdmin
{
    if (self.myRoleInGroup < 2) {
        [BasicTool showAlertInfo:@"只有群主可以取消管理员!" parent:self];
        return;
    }

    __weak typeof(self) safeSelf = self;
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;

    [[HttpRestHelper sharedInstance] submitGetGroupMembersListFromServer:self.groupInfoForInit.g_id requestUid:myUid complete:^(BOOL sucess, NSMutableArray<GroupMemberEntity *> *membersList) {
        if (!sucess || membersList == nil) {
            [BasicTool showAlertError:@"获取成员列表失败!" parent:safeSelf];
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray *titles = [NSMutableArray array];
            NSMutableArray *members = [NSMutableArray array];
            for (GroupMemberEntity *m in membersList) {
                if ([m.user_uid isEqualToString:myUid]) continue;
                if (m.role != 1) continue;
                NSString *displayName = [GroupsProvider getNickNameInGroup:m.nickname and:m.nickname_ingroup];
                [titles addObject:[NSString stringWithFormat:@"%@ [管理员]", displayName]];
                [members addObject:m];
            }

            if (titles.count == 0) {
                [BasicTool showAlertInfo:@"当前没有管理员可取消" parent:safeSelf];
                return;
            }

            [LPActionSheet showActionSheetWithTitle:@"选择要取消管理员的成员"
                                  cancelButtonTitle:@"取消"
                             destructiveButtonTitle:nil
                                  otherButtonTitles:titles
                                            handler:^(LPActionSheet *actionSheet, NSInteger index) {
                if (index > 0 && (index - 1) < (NSInteger)members.count) {
                    GroupMemberEntity *target = members[index - 1];
                    [[HttpRestHelper sharedInstance] submitSetGroupAdminToServer:myUid targetUid:target.user_uid gid:safeSelf.groupInfoForInit.g_id role:0 complete:^(BOOL sucess2, NSString *resultCode) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (sucess2 && [@"1" isEqualToString:resultCode]) {
                                [APP showUserDefineToast_OK:@"取消管理员成功" atHide:nil];
                            } else if ([@"-2" isEqualToString:resultCode]) {
                                [BasicTool showAlertInfo:@"权限不足，仅群主可操作" parent:safeSelf];
                            } else if ([@"-4" isEqualToString:resultCode]) {
                                [BasicTool showAlertInfo:@"目标用户不在群中" parent:safeSelf];
                            } else {
                                [BasicTool showAlertInfo:@"取消管理员失败" parent:safeSelf];
                            }
                        });
                    } hudParentView:safeSelf.view];
                }
            }];
        });
    } hudParentView:self.view];
}

- (void)clickMuteMode
{
    __weak typeof(self) safeSelf = self;
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    NSArray *titles = @[@"正常（不禁言）", @"仅管理员和群主可发言", @"仅群主可发言"];

    [LPActionSheet showActionSheetWithTitle:@"设置全群禁言模式"
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:titles
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index > 0) {
            int muteMode = (int)(index - 1);
            [[HttpRestHelper sharedInstance] submitSetGroupMuteModeToServer:myUid gid:safeSelf.groupInfoForInit.g_id muteMode:muteMode complete:^(BOOL sucess, NSString *resultCode) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (sucess && [@"1" isEqualToString:resultCode]) {
                        safeSelf.groupInfoForInit.g_mute_mode = muteMode;
                        [APP showUserDefineToast_OK:@"禁言模式设置成功" atHide:nil];
                    } else if ([@"-2" isEqualToString:resultCode]) {
                        [BasicTool showAlertInfo:@"权限不足" parent:safeSelf];
                    } else {
                        [BasicTool showAlertInfo:@"设置失败，请稍后重试" parent:safeSelf];
                    }
                });
            } hudParentView:safeSelf.view];
        }
    }];
}

- (void)clickMutedMembers
{
    GroupMutedMembersViewController *vc = [[GroupMutedMembersViewController alloc] initWithGid:self.groupInfoForInit.g_id myRole:self.myRoleInGroup];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)clickJoinRequests
{
    GroupJoinRequestsViewController *vc = [[GroupJoinRequestsViewController alloc] initWithGid:self.groupInfoForInit.g_id myRole:self.myRoleInGroup];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)clickGroupSettings
{
    GroupSettingsViewController *vc = [[GroupSettingsViewController alloc] initWithGroupInfo:self.groupInfoForInit myRole:self.myRoleInGroup];
    [self.navigationController pushViewController:vc animated:YES];
}


#pragma mark - ViewControllerResultBackDelegate

- (void)onViewControllerResultBack:(int)requestCode resultCode:(int)resultCode withData:(id)data
{
    DDLogDebug(@"[GroupInfoViewController]收到result回调：requestCode=%d, resultCode=%d ,data=%@", requestCode, resultCode, data);

    switch (requestCode) {
        case REQUEST_CODE_FOR_VIEW_MEMBERS:
        case REQUEST_CODE_FOR_INVITE_MEMBERS:
        {
            if (resultCode == ViewControllerResultBack_RESULT_OK) {
                NSString *currentGroupMemberCount = (NSString *)data;
                if (currentGroupMemberCount != nil)
                    self.groupInfoForInit.g_member_count = currentGroupMemberCount;
                [self refreshDatas];
                [self loadGroupMembers];
            }
            break;
        }
        case REQUEST_CODE_FOR_TRANSFER:
        {
            if (resultCode == ViewControllerResultBack_RESULT_OK) {
                GroupEntity *updatedGe = (GroupEntity *)data;
                if (updatedGe != nil) {
                    self.groupInfoForInit = updatedGe;
                    [self refreshDatas];
                }
            }
            break;
        }
        case REQUEST_CODE_FOR_EDIT_NOTICE:
        {
            if (resultCode == ViewControllerResultBack_RESULT_OK) {
                GroupEntity *updatedGe = [data isKindOfClass:[GroupEntity class]] ? (GroupEntity *)data : nil;
                if (updatedGe != nil) {
                    self.groupInfoForInit = updatedGe;
                }
                [self refreshDatas];
            }
            break;
        }
        default:
            DDLogWarn(@"[GroupInfoViewController]!!! onViewControllerResultBack-> requestCode=%d", requestCode);
            break;
    }
}


#pragma mark - RBImagePickerCompleteDelegate（群头像上传）

- (void)processImagePickerComplete:(UIImage *)photo withTag:(NSString *)tag
{
    if (photo == nil) {
        [BasicTool showAlertError:@"图片选择失败!" parent:self];
        return;
    }

    NSString *gid = self.groupInfoForInit.g_id;
    if (gid == nil) {
        [BasicTool showAlertError:@"群信息异常，请退出后重试!" parent:self];
        return;
    }

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = @"图片处理中..";

    __weak typeof(self) safeSelf = self;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *savedDir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_AVATART_RELATIVE_DIR];
        [FileTool tryCreateDirs:savedDir];

        NSString *tempFileName = [NSString stringWithFormat:@"_temp_group_avatar_%@", gid];
        NSString *filePathAfterCompress = [BasicTool imageCompressForQualityAndWidth:photo
                                                                       targetQuality:LOCAL_AVATAR_IMAGE_QUALITY
                                                                         targetWidth:LOCAL_AVATAR_SIZE
                                                                           saveToDir:savedDir
                                                                           savedName:tempFileName];

        if (filePathAfterCompress == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [hud hideAnimated:YES];
                [BasicTool showAlertError:@"图片压缩失败，请重试!" parent:safeSelf];
            });
            return;
        }

        NSString *md5ForFile = [FileTool getFileMD5WithPath:filePathAfterCompress];
        if (md5ForFile == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [hud hideAnimated:YES];
                [BasicTool showAlertError:@"图片处理失败，请重试!" parent:safeSelf];
            });
            return;
        }

        NSString *groupAvatarFileName = [NSString stringWithFormat:@"group_avatar_%@_%@.jpg", gid, md5ForFile];
        NSString *renamedPath = [NSString stringWithFormat:@"%@/%@", savedDir, groupAvatarFileName];
        [FileTool renameFile:filePathAfterCompress toFilePath:renamedPath];

        dispatch_async(dispatch_get_main_queue(), ^{
            hud.label.text = @"群头像上传中..";
        });

        NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        NSString *uploadUrl = MSG_IMG_UPLODER_URL_ROOT;

        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"user_uid"] = localUid;
        params[@"file_name"] = groupAvatarFileName;

        [FileUploadHelper uploadFileImpl:renamedPath
                                withName:groupAvatarFileName
                                  andUrl:uploadUrl
                           andParameters:params
                                progress:nil
                                 success:^(NSURLSessionDataTask *task, id responseObject) {
            dispatch_async(dispatch_get_main_queue(), ^{
                hud.label.text = @"设置群头像中..";
            });

            [[HttpRestHelper sharedInstance] submitSetGroupAvatarToServer:localUid
                                                                     gid:gid
                                                               avatarUrl:groupAvatarFileName
                                                                complete:^(BOOL sucess, NSString *resultCode) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [hud hideAnimated:YES];
                    if (sucess && [@"1" isEqualToString:resultCode]) {
                        safeSelf.groupInfoForInit.g_custom_avatar = groupAvatarFileName;
                        [FileDownloadHelper clearGroupAvatarCache:gid];
                        [NotificationCenterFactory resetGroupAvatarCache_POST:gid];
                        [APP showUserDefineToast_OK:@"群头像设置成功" atHide:nil];
                    } else if ([@"-2" isEqualToString:resultCode]) {
                        [BasicTool showAlertInfo:@"权限不足，仅管理员或群主可操作" parent:safeSelf];
                    } else {
                        [BasicTool showAlertInfo:@"群头像设置失败，请稍后重试" parent:safeSelf];
                    }
                });
            } hudParentView:nil];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [hud hideAnimated:YES];
                [BasicTool showAlertError:@"群头像上传失败，请检查网络后重试!" parent:safeSelf];
            });
        }];
    });
}


#pragma mark - Utility

- (BOOL)localUserIsGroupOwner
{
    return [GroupsProvider isGroupOwner:self.groupInfoForInit.g_owner_user_uid];
}

- (void)doBack:(BOOL)animated
{
    [self.navigationController popViewControllerAnimated:animated];
}

@end
