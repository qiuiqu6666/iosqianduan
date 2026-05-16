//telegram @wz662
#import "FriendInfoViewController.h"
#import "UserEntity.h"
#import "IMClientManager.h"
#import "FriendsListProvider.h"
#import "BasicTool.h"
#import "FileDownloadHelper.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "ViewControllerFactory.h"
#import "MoreViewController.h"
#import "ContactViewController.h"
#import "NotificationCenterFactory.h"
#import "LPActionSheet.h"
#import "AlarmType.h"
#import "CallManager.h"
#import "BlacklistViewController.h"
#import "ContactMeta.h"
#import "MessageHelper.h"
#import "TargetChooseViewController.h"
#import "MsgBodyRoot.h"
#import "UIViewController+RBPlainCustomNav.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]
/** 从资料页「把他推荐给好友」选择目标时的 requestCode */
static const int REQUEST_CODE_RECOMMEND_TO_FRIEND = 100;

@interface FriendInfoViewController () <UserChooseCompleteDelegate>
@property (nonatomic, retain) UserEntity *friendInfoForInit;
@property (nonatomic, assign) BOOL canOpenChat;
// 照片区域容器（用于动态显示/隐藏）
@property (nonatomic, strong) UIView *photosSection;
@property (nonatomic, strong) NSLayoutConstraint *photosSectionHeightConstraint;
// 备注区域容器（用于动态显示/隐藏）
@property (nonatomic, strong) UIView *remarkSection;
// 底部按钮区域
@property (nonatomic, strong) UIView *buttonsSection;
// 群成员信息显示
@property (nonatomic, strong) UILabel *viewJoinTime;
@property (nonatomic, strong) UILabel *viewInviter;
// 群成员信息区域（动态显示/隐藏）
@property (nonatomic, strong) UIView *groupMemberInfoSection;
// 星标图标（昵称行右上角，仅星标好友显示）
@property (nonatomic, strong) UIImageView *imgStarIcon;
@end

@implementation FriendInfoViewController

#pragma mark - 初始化

- (id)initWithDatas:(UserEntity *)userInfo canOpenChat:(BOOL)canOpenChat
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.friendInfoForInit = userInfo;
        self.canOpenChat = canOpenChat;
    }
    return self;
}

// 兼容旧的调用方式
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withDatas:(UserEntity *)userInfo canOpenChat:(BOOL)canOpenChat
{
    return [self initWithDatas:userInfo canOpenChat:canOpenChat];
}

- (void)loadView
{
    self.view = [[UIView alloc] init];
}

#pragma mark - 生命周期

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"详细资料";
    self.view.backgroundColor = HexColor(0xF0F0F0);
    self.navigationItem.titleView = nil;
    UIImage *moreImg = [UIImage imageNamed:@"common_more_ico"];
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @"详细资料"
                                    rightButtonImage:moreImg
                                              target:self
                                              action:@selector(gotoMore)];

    [self buildUI];
    [self initViews];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];

    if ([self isFriend]) {
        // 当界面每次回到前台时就及时刷新本界面中的有关好友备注信息的显示
        [self refreshViewsForRemark:[[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUserId:self.friendInfoForInit.user_uid]];
    }
    [self rb_refreshLatestLoginDisplay];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
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

#pragma mark - 构建UI

- (void)buildUI
{
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    if (@available(iOS 11.0, *)) {
        scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:scrollView];
    
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];
    
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],
    ]];
    
    UIView *lastAnchorView = nil;
    
    // ========== Section 0: 头像区域 ==========
    UIView *avatarSection = [self buildAvatarSection];
    avatarSection.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:avatarSection];
    [NSLayoutConstraint activateConstraints:@[
        [avatarSection.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:0],
        [avatarSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [avatarSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    lastAnchorView = avatarSection;
    
    // ========== Section 1: 设置备注和标签（仅好友可见）==========
    if ([self isFriend]) {
        self.remarkSection = [self buildRemarkSection];
        self.remarkSection.translatesAutoresizingMaskIntoConstraints = NO;
        [contentView addSubview:self.remarkSection];
        [NSLayoutConstraint activateConstraints:@[
            [self.remarkSection.topAnchor constraintEqualToAnchor:lastAnchorView.bottomAnchor constant:10],
            [self.remarkSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
            [self.remarkSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        ]];
        lastAnchorView = self.remarkSection;
    }
    
    // ========== Section 2: 基本信息 ==========
    UIView *infoSection = [self buildInfoSection];
    infoSection.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:infoSection];
    [NSLayoutConstraint activateConstraints:@[
        [infoSection.topAnchor constraintEqualToAnchor:lastAnchorView.bottomAnchor constant:10],
        [infoSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [infoSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    lastAnchorView = infoSection;
    
    // ========== Section 2.5: 群成员信息（入群时间、邀请人） ==========
    if (self.groupMemberInfo != nil) {
        self.groupMemberInfoSection = [self buildGroupMemberInfoSection];
        self.groupMemberInfoSection.translatesAutoresizingMaskIntoConstraints = NO;
        [contentView addSubview:self.groupMemberInfoSection];
        [NSLayoutConstraint activateConstraints:@[
            [self.groupMemberInfoSection.topAnchor constraintEqualToAnchor:lastAnchorView.bottomAnchor constant:10],
            [self.groupMemberInfoSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
            [self.groupMemberInfoSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        ]];
        lastAnchorView = self.groupMemberInfoSection;
    }
    
    // ========== Section 3: 相册 ==========
    self.photosSection = [self buildPhotosSection];
    self.photosSection.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.photosSection];
    [NSLayoutConstraint activateConstraints:@[
        [self.photosSection.topAnchor constraintEqualToAnchor:lastAnchorView.bottomAnchor constant:10],
        [self.photosSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [self.photosSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    lastAnchorView = self.photosSection;
    
    // ========== Section 4: 语音介绍 ==========
    UIView *voiceSection = [self buildVoiceSection];
    voiceSection.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:voiceSection];
    [NSLayoutConstraint activateConstraints:@[
        [voiceSection.topAnchor constraintEqualToAnchor:lastAnchorView.bottomAnchor constant:10],
        [voiceSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [voiceSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    ]];
    lastAnchorView = voiceSection;
    
    // ========== Section 5: 底部按钮 ==========
    if (self.canOpenChat) {
        self.buttonsSection = [self buildButtonsSection];
        self.buttonsSection.translatesAutoresizingMaskIntoConstraints = NO;
        [contentView addSubview:self.buttonsSection];
        [NSLayoutConstraint activateConstraints:@[
            [self.buttonsSection.topAnchor constraintEqualToAnchor:lastAnchorView.bottomAnchor constant:10],
            [self.buttonsSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
            [self.buttonsSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        ]];
        lastAnchorView = self.buttonsSection;
    }
    
    // 底部间距
    [NSLayoutConstraint activateConstraints:@[
        [lastAnchorView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-30],
    ]];
}

#pragma mark - 头像区域

- (UIView *)buildAvatarSection
{
    UIView *section = [[UIView alloc] init];
    section.backgroundColor = [UIColor whiteColor];
    
    // 头像
    self.imgAvadar = [[UIImageView alloc] init];
    self.imgAvadar.translatesAutoresizingMaskIntoConstraints = NO;
    self.imgAvadar.contentMode = UIViewContentModeScaleAspectFill;
    self.imgAvadar.clipsToBounds = YES;
    self.imgAvadar.layer.cornerRadius = 28.f; // 56×56 头像 → 圆形
    if (@available(iOS 13.0, *)) {
        self.imgAvadar.layer.cornerCurve = kCACornerCurveCircular;
    }
    self.imgAvadar.image = [UIImage imageNamed:@"default_avatar_70"];
    self.imgAvadar.userInteractionEnabled = YES;
    [section addSubview:self.imgAvadar];
    
    // 昵称容器（昵称 + 性别图标）
    UIView *nameContainer = [[UIView alloc] init];
    nameContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [section addSubview:nameContainer];
    
    self.viewNickname = [[UILabel alloc] init];
    self.viewNickname.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewNickname.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    self.viewNickname.textColor = [UIColor colorWithRed:0.208 green:0.216 blue:0.231 alpha:1.0];
    self.viewNickname.lineBreakMode = NSLineBreakByTruncatingTail;
    [nameContainer addSubview:self.viewNickname];
    
    self.imgSex = [[UIImageView alloc] init];
    self.imgSex.translatesAutoresizingMaskIntoConstraints = NO;
    self.imgSex.contentMode = UIViewContentModeScaleAspectFit;
    [nameContainer addSubview:self.imgSex];
    
    // 陌生人标签
    self.viewGuestFlag = [[UILabel alloc] init];
    self.viewGuestFlag.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewGuestFlag.text = @"陌生人";
    self.viewGuestFlag.font = [UIFont systemFontOfSize:11];
    self.viewGuestFlag.textColor = [UIColor whiteColor];
    self.viewGuestFlag.backgroundColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.2 alpha:1.0];
    self.viewGuestFlag.textAlignment = NSTextAlignmentCenter;
    self.viewGuestFlag.layer.cornerRadius = 3;
    self.viewGuestFlag.clipsToBounds = YES;
    self.viewGuestFlag.hidden = YES;
    // 给标签留一点内边距
    UIEdgeInsets padding = UIEdgeInsetsMake(2, 6, 2, 6);
    self.viewGuestFlag.layer.sublayerTransform = CATransform3DMakeTranslation(padding.left/2, 0, 0);
    [nameContainer addSubview:self.viewGuestFlag];

    // 星标图标（昵称行右上角，仅星标好友显示）
    self.imgStarIcon = [[UIImageView alloc] init];
    self.imgStarIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.imgStarIcon.image = [UIImage imageNamed:@"contact_star"];
    self.imgStarIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.imgStarIcon.hidden = YES;
    [nameContainer addSubview:self.imgStarIcon];
    
    // 原始昵称（有备注时才显示）
    self.viewOriginalNickname = [[UILabel alloc] init];
    self.viewOriginalNickname.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewOriginalNickname.font = [UIFont systemFontOfSize:14];
    self.viewOriginalNickname.textColor = [UIColor colorWithRed:0.6 green:0.608 blue:0.624 alpha:1.0];
    self.viewOriginalNickname.hidden = YES;
    [section addSubview:self.viewOriginalNickname];
    
    // UID（昵称下方）
    self.viewUid = [[UILabel alloc] init];
    self.viewUid.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewUid.font = [UIFont systemFontOfSize:13];
    self.viewUid.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    [section addSubview:self.viewUid];
    
    // 个性签名（UID下方，支持多行与换行完整显示）
    self.viewWhatsup = [[UILabel alloc] init];
    self.viewWhatsup.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewWhatsup.font = [UIFont systemFontOfSize:13];
    self.viewWhatsup.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    self.viewWhatsup.numberOfLines = 0;
    self.viewWhatsup.lineBreakMode = NSLineBreakByWordWrapping;
    [section addSubview:self.viewWhatsup];
    
    [NSLayoutConstraint activateConstraints:@[
        // 头像
        [self.imgAvadar.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [self.imgAvadar.topAnchor constraintEqualToAnchor:section.topAnchor constant:16],
        [self.imgAvadar.widthAnchor constraintEqualToConstant:56],
        [self.imgAvadar.heightAnchor constraintEqualToConstant:56],
        
        // 昵称容器
        [nameContainer.leadingAnchor constraintEqualToAnchor:self.imgAvadar.trailingAnchor constant:14],
        [nameContainer.trailingAnchor constraintLessThanOrEqualToAnchor:section.trailingAnchor constant:-20],
        [nameContainer.topAnchor constraintEqualToAnchor:self.imgAvadar.topAnchor constant:2],
        [nameContainer.heightAnchor constraintEqualToConstant:24],
        
        // 昵称
        [self.viewNickname.leadingAnchor constraintEqualToAnchor:nameContainer.leadingAnchor],
        [self.viewNickname.centerYAnchor constraintEqualToAnchor:nameContainer.centerYAnchor],
        
    // 性别图标
        [self.imgSex.leadingAnchor constraintEqualToAnchor:self.viewNickname.trailingAnchor constant:6],
        [self.imgSex.centerYAnchor constraintEqualToAnchor:nameContainer.centerYAnchor],
        [self.imgSex.widthAnchor constraintEqualToConstant:14],
        [self.imgSex.heightAnchor constraintEqualToConstant:14],
        
        // 陌生人标签
        [self.viewGuestFlag.leadingAnchor constraintEqualToAnchor:self.imgSex.trailingAnchor constant:6],
        [self.viewGuestFlag.centerYAnchor constraintEqualToAnchor:nameContainer.centerYAnchor],
        [self.viewGuestFlag.trailingAnchor constraintLessThanOrEqualToAnchor:self.imgStarIcon.leadingAnchor constant:-4],
        [self.viewGuestFlag.heightAnchor constraintEqualToConstant:18],
        [self.viewGuestFlag.widthAnchor constraintGreaterThanOrEqualToConstant:40],

        // 星标图标（昵称行右上角）
        [self.imgStarIcon.trailingAnchor constraintEqualToAnchor:nameContainer.trailingAnchor],
        [self.imgStarIcon.centerYAnchor constraintEqualToAnchor:nameContainer.centerYAnchor],
        [self.imgStarIcon.widthAnchor constraintEqualToConstant:40],
        [self.imgStarIcon.heightAnchor constraintEqualToConstant:40],
        
        // UID（昵称下方）
        [self.viewUid.leadingAnchor constraintEqualToAnchor:nameContainer.leadingAnchor],
        [self.viewUid.topAnchor constraintEqualToAnchor:nameContainer.bottomAnchor constant:4],
        [self.viewUid.trailingAnchor constraintLessThanOrEqualToAnchor:section.trailingAnchor constant:-20],
        
        // 个性签名（UID下方，固定 trailing 以便多行换行计算高度）
        [self.viewWhatsup.leadingAnchor constraintEqualToAnchor:nameContainer.leadingAnchor],
        [self.viewWhatsup.topAnchor constraintEqualToAnchor:self.viewUid.bottomAnchor constant:4],
        [self.viewWhatsup.trailingAnchor constraintEqualToAnchor:section.trailingAnchor constant:-20],

        // 原始昵称（有备注时显示在个性签名下方）
        [self.viewOriginalNickname.leadingAnchor constraintEqualToAnchor:nameContainer.leadingAnchor],
        [self.viewOriginalNickname.topAnchor constraintEqualToAnchor:self.viewWhatsup.bottomAnchor constant:4],
        [self.viewOriginalNickname.trailingAnchor constraintLessThanOrEqualToAnchor:section.trailingAnchor constant:-20],
        
        // section 底部由最下方元素决定，保证长签名时区域随内容增高
        [section.bottomAnchor constraintEqualToAnchor:self.viewOriginalNickname.bottomAnchor constant:16],
        
        // 头像底部约束（确保section高度足够）
        [self.imgAvadar.bottomAnchor constraintLessThanOrEqualToAnchor:section.bottomAnchor constant:-16],
    ]];
    
    // 设置昵称的内容压缩阻力
    [self.viewNickname setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.viewGuestFlag setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    return section;
}

#pragma mark - 设置备注和标签（仅好友）

- (UIView *)buildRemarkSection
{
    UIView *section = [[UIView alloc] init];
    section.backgroundColor = [UIColor whiteColor];
    
    UIView *remarkItem = [self createArrowItemWithTitle:@"设置备注和标签" value:nil action:@selector(gotoFriendRemarkEdit:)];
    remarkItem.translatesAutoresizingMaskIntoConstraints = NO;
    [section addSubview:remarkItem];
    
    [NSLayoutConstraint activateConstraints:@[
        [remarkItem.topAnchor constraintEqualToAnchor:section.topAnchor],
        [remarkItem.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [remarkItem.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [remarkItem.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
        [remarkItem.heightAnchor constraintEqualToConstant:56],
    ]];
    
    return section;
}

#pragma mark - 基本信息区域

- (UIView *)buildInfoSection
{
    UIView *section = [[UIView alloc] init];
    section.backgroundColor = [UIColor whiteColor];
    
    // 最近登录
    UIView *loginItem = [self createInfoItemWithTitle:@"最近登录" valueLabel:nil];
    self.viewLatestLoginTime = (UILabel *)[loginItem viewWithTag:1001];
    
    // 分隔线
    UIView *sep1 = [self createSeparator];
    
    // 其它说明
    UIView *captionItem = [self createInfoItemWithTitle:@"其它说明" valueLabel:nil];
    self.viewCaption = (UILabel *)[captionItem viewWithTag:1001];
    
    NSArray *subviews = @[loginItem, sep1, captionItem];
    UIView *prev = nil;
    for (UIView *v in subviews) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [section addSubview:v];
        [NSLayoutConstraint activateConstraints:@[
            [v.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
            [v.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        ]];
        if (prev == nil) {
            [v.topAnchor constraintEqualToAnchor:section.topAnchor].active = YES;
        } else {
            [v.topAnchor constraintEqualToAnchor:prev.bottomAnchor].active = YES;
        }
        prev = v;
    }
    [prev.bottomAnchor constraintEqualToAnchor:section.bottomAnchor].active = YES;
    
    return section;
}

#pragma mark - 群成员信息区域（入群时间、邀请人）

- (UIView *)buildGroupMemberInfoSection
{
    UIView *section = [[UIView alloc] init];
    section.backgroundColor = [UIColor whiteColor];
    
    NSMutableArray *subviews = [NSMutableArray array];
    
    // 入群时间
    if (![BasicTool isStringEmpty:self.groupMemberInfo.join_time]) {
        UIView *joinTimeItem = [self createInfoItemWithTitle:@"入群时间" valueLabel:nil];
        self.viewJoinTime = (UILabel *)[joinTimeItem viewWithTag:1001];
        self.viewJoinTime.text = self.groupMemberInfo.join_time;
        [subviews addObject:joinTimeItem];
    }
    
    // 邀请人
    if (![BasicTool isStringEmpty:self.groupMemberInfo.invite_by_uid]) {
        if (subviews.count > 0) {
            [subviews addObject:[self createSeparator]];
        }
        UIView *inviterItem = [self createInfoItemWithTitle:@"邀请人" valueLabel:nil];
        self.viewInviter = (UILabel *)[inviterItem viewWithTag:1001];
        NSString *inviterName = self.groupMemberInfo.invite_by_nickname ?: self.groupMemberInfo.invite_by_uid;
        self.viewInviter.text = inviterName;
        [subviews addObject:inviterItem];
    }
    
    // 如果没有任何信息，返回空section
    if (subviews.count == 0) {
        section.hidden = YES;
        return section;
    }
    
    UIView *prev = nil;
    for (UIView *v in subviews) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [section addSubview:v];
        [NSLayoutConstraint activateConstraints:@[
            [v.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
            [v.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        ]];
        if (prev == nil) {
            [v.topAnchor constraintEqualToAnchor:section.topAnchor].active = YES;
        } else {
            [v.topAnchor constraintEqualToAnchor:prev.bottomAnchor].active = YES;
        }
        prev = v;
    }
    [prev.bottomAnchor constraintEqualToAnchor:section.bottomAnchor].active = YES;
    
    return section;
}

#pragma mark - 相册区域

- (UIView *)buildPhotosSection
{
    UIView *section = [[UIView alloc] init];
    section.backgroundColor = [UIColor whiteColor];
    
    // 相册标题行
    UIView *titleRow = [[UIView alloc] init];
    titleRow.translatesAutoresizingMaskIntoConstraints = NO;
    [section addSubview:titleRow];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"相册";
    titleLabel.font = [UIFont systemFontOfSize:17];
    titleLabel.textColor = [UIColor blackColor];
    [titleRow addSubview:titleLabel];
    
    self.viewPhotosCount = [[UILabel alloc] init];
    self.viewPhotosCount.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewPhotosCount.font = [UIFont systemFontOfSize:15];
    self.viewPhotosCount.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    self.viewPhotosCount.hidden = YES;
    [titleRow addSubview:self.viewPhotosCount];
    
    UIImageView *arrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"common_list_rightarrow_icon_nor"]];
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    [titleRow addSubview:arrow];
    
    UIButton *photoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    photoBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [photoBtn addTarget:self action:@selector(gotoPhotos:) forControlEvents:UIControlEventTouchUpInside];
    [titleRow addSubview:photoBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleRow.topAnchor constraintEqualToAnchor:section.topAnchor],
        [titleRow.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [titleRow.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [titleRow.heightAnchor constraintEqualToConstant:56],
        
        [titleLabel.leadingAnchor constraintEqualToAnchor:titleRow.leadingAnchor constant:20],
        [titleLabel.centerYAnchor constraintEqualToAnchor:titleRow.centerYAnchor],
        
        [self.viewPhotosCount.trailingAnchor constraintEqualToAnchor:arrow.leadingAnchor constant:-8],
        [self.viewPhotosCount.centerYAnchor constraintEqualToAnchor:titleRow.centerYAnchor],
        
        [arrow.trailingAnchor constraintEqualToAnchor:titleRow.trailingAnchor constant:-16],
        [arrow.centerYAnchor constraintEqualToAnchor:titleRow.centerYAnchor],
        [arrow.widthAnchor constraintEqualToConstant:8],
        [arrow.heightAnchor constraintEqualToConstant:14],
        
        [photoBtn.topAnchor constraintEqualToAnchor:titleRow.topAnchor],
        [photoBtn.leadingAnchor constraintEqualToAnchor:titleRow.leadingAnchor],
        [photoBtn.trailingAnchor constraintEqualToAnchor:titleRow.trailingAnchor],
        [photoBtn.bottomAnchor constraintEqualToAnchor:titleRow.bottomAnchor],
    ]];
    
    // 照片预览区域
    self.layoutPhotosPreview = [[UIView alloc] init];
    self.layoutPhotosPreview.translatesAutoresizingMaskIntoConstraints = NO;
    self.layoutPhotosPreview.hidden = YES;
    [section addSubview:self.layoutPhotosPreview];
    
    CGFloat previewSize = 50;
    CGFloat previewSpacing = 8;
    
    self.imgPhotoPreview1 = [self createPhotoPreviewImageView];
    self.imgPhotoPreview2 = [self createPhotoPreviewImageView];
    self.imgPhotoPreview3 = [self createPhotoPreviewImageView];
    self.imgPhotoPreview4 = [self createPhotoPreviewImageView];
    
    [self.layoutPhotosPreview addSubview:self.imgPhotoPreview1];
    [self.layoutPhotosPreview addSubview:self.imgPhotoPreview2];
    [self.layoutPhotosPreview addSubview:self.imgPhotoPreview3];
    [self.layoutPhotosPreview addSubview:self.imgPhotoPreview4];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.layoutPhotosPreview.topAnchor constraintEqualToAnchor:titleRow.bottomAnchor],
        [self.layoutPhotosPreview.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [self.layoutPhotosPreview.trailingAnchor constraintEqualToAnchor:section.trailingAnchor constant:-20],
        [self.layoutPhotosPreview.heightAnchor constraintEqualToConstant:previewSize + 16],
        
        [self.imgPhotoPreview1.leadingAnchor constraintEqualToAnchor:self.layoutPhotosPreview.leadingAnchor],
        [self.imgPhotoPreview1.topAnchor constraintEqualToAnchor:self.layoutPhotosPreview.topAnchor],
        [self.imgPhotoPreview1.widthAnchor constraintEqualToConstant:previewSize],
        [self.imgPhotoPreview1.heightAnchor constraintEqualToConstant:previewSize],
        
        [self.imgPhotoPreview2.leadingAnchor constraintEqualToAnchor:self.imgPhotoPreview1.trailingAnchor constant:previewSpacing],
        [self.imgPhotoPreview2.topAnchor constraintEqualToAnchor:self.layoutPhotosPreview.topAnchor],
        [self.imgPhotoPreview2.widthAnchor constraintEqualToConstant:previewSize],
        [self.imgPhotoPreview2.heightAnchor constraintEqualToConstant:previewSize],
        
        [self.imgPhotoPreview3.leadingAnchor constraintEqualToAnchor:self.imgPhotoPreview2.trailingAnchor constant:previewSpacing],
        [self.imgPhotoPreview3.topAnchor constraintEqualToAnchor:self.layoutPhotosPreview.topAnchor],
        [self.imgPhotoPreview3.widthAnchor constraintEqualToConstant:previewSize],
        [self.imgPhotoPreview3.heightAnchor constraintEqualToConstant:previewSize],
        
        [self.imgPhotoPreview4.leadingAnchor constraintEqualToAnchor:self.imgPhotoPreview3.trailingAnchor constant:previewSpacing],
        [self.imgPhotoPreview4.topAnchor constraintEqualToAnchor:self.layoutPhotosPreview.topAnchor],
        [self.imgPhotoPreview4.widthAnchor constraintEqualToConstant:previewSize],
        [self.imgPhotoPreview4.heightAnchor constraintEqualToConstant:previewSize],
    ]];
    
    // section高度 = titleRow(56) + 照片预览(hidden by default)
    self.photosSectionHeightConstraint = [section.heightAnchor constraintEqualToConstant:56];
    self.photosSectionHeightConstraint.active = YES;
    
    return section;
}

- (UIImageView *)createPhotoPreviewImageView
{
    UIImageView *iv = [[UIImageView alloc] init];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    iv.layer.cornerRadius = 4;
    iv.hidden = YES;
    iv.image = [UIImage imageNamed:@"sns_friend_info_form_photo_preview_default_img"];
    return iv;
}

#pragma mark - 语音介绍区域

- (UIView *)buildVoiceSection
{
    UIView *section = [[UIView alloc] init];
    section.backgroundColor = [UIColor whiteColor];
    
    UIView *voiceItem = [[UIView alloc] init];
    voiceItem.translatesAutoresizingMaskIntoConstraints = NO;
    [section addSubview:voiceItem];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"语音介绍";
    titleLabel.font = [UIFont systemFontOfSize:17];
    titleLabel.textColor = [UIColor blackColor];
    [voiceItem addSubview:titleLabel];
    
    self.viewPVoicesCount = [[UILabel alloc] init];
    self.viewPVoicesCount.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewPVoicesCount.font = [UIFont systemFontOfSize:15];
    self.viewPVoicesCount.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    self.viewPVoicesCount.hidden = YES;
    [voiceItem addSubview:self.viewPVoicesCount];
    
    UIImageView *arrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"common_list_rightarrow_icon_nor"]];
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    [voiceItem addSubview:arrow];
    
    UIButton *voiceBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    voiceBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [voiceBtn addTarget:self action:@selector(gotoPVoices:) forControlEvents:UIControlEventTouchUpInside];
    [voiceItem addSubview:voiceBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [voiceItem.topAnchor constraintEqualToAnchor:section.topAnchor],
        [voiceItem.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [voiceItem.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [voiceItem.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
        [voiceItem.heightAnchor constraintEqualToConstant:56],
        
        [titleLabel.leadingAnchor constraintEqualToAnchor:voiceItem.leadingAnchor constant:20],
        [titleLabel.centerYAnchor constraintEqualToAnchor:voiceItem.centerYAnchor],
        
        [self.viewPVoicesCount.trailingAnchor constraintEqualToAnchor:arrow.leadingAnchor constant:-8],
        [self.viewPVoicesCount.centerYAnchor constraintEqualToAnchor:voiceItem.centerYAnchor],
        
        [arrow.trailingAnchor constraintEqualToAnchor:voiceItem.trailingAnchor constant:-16],
        [arrow.centerYAnchor constraintEqualToAnchor:voiceItem.centerYAnchor],
        [arrow.widthAnchor constraintEqualToConstant:8],
        [arrow.heightAnchor constraintEqualToConstant:14],
        
        [voiceBtn.topAnchor constraintEqualToAnchor:voiceItem.topAnchor],
        [voiceBtn.leadingAnchor constraintEqualToAnchor:voiceItem.leadingAnchor],
        [voiceBtn.trailingAnchor constraintEqualToAnchor:voiceItem.trailingAnchor],
        [voiceBtn.bottomAnchor constraintEqualToAnchor:voiceItem.bottomAnchor],
    ]];
    
    return section;
}

#pragma mark - 底部按钮区域

- (UIView *)buildButtonsSection
{
    UIView *section = [[UIView alloc] init];
    
    UIColor *btnTextColor = HexColor(0x576B95);
    UIFont *btnFont = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    
    if ([self isFriend]) {
        // ======= 好友状态：发消息 + 音视频通话 =======
        
        // 发消息按钮
        self.btnOpenChat = [UIButton buttonWithType:UIButtonTypeCustom];
        self.btnOpenChat.translatesAutoresizingMaskIntoConstraints = NO;
        [self.btnOpenChat setTitle:@"  发消息" forState:UIControlStateNormal];
        [self.btnOpenChat setTitleColor:btnTextColor forState:UIControlStateNormal];
        self.btnOpenChat.titleLabel.font = btnFont;
        self.btnOpenChat.backgroundColor = [UIColor whiteColor];
        // 聊天气泡图标
        UIImage *chatIcon = [UIImage systemImageNamed:@"message"];
        if (chatIcon) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
            chatIcon = [UIImage systemImageNamed:@"message" withConfiguration:config];
            chatIcon = [chatIcon imageWithTintColor:btnTextColor renderingMode:UIImageRenderingModeAlwaysOriginal];
            [self.btnOpenChat setImage:chatIcon forState:UIControlStateNormal];
        }
        [self.btnOpenChat addTarget:self action:@selector(gotoChat:) forControlEvents:UIControlEventTouchUpInside];
        [section addSubview:self.btnOpenChat];
        
        // 音视频通话按钮
        UIButton *btnVideoCall = [UIButton buttonWithType:UIButtonTypeCustom];
        btnVideoCall.translatesAutoresizingMaskIntoConstraints = NO;
        [btnVideoCall setTitle:@"  音视频通话" forState:UIControlStateNormal];
        [btnVideoCall setTitleColor:btnTextColor forState:UIControlStateNormal];
        btnVideoCall.titleLabel.font = btnFont;
        btnVideoCall.backgroundColor = [UIColor whiteColor];
        // 电话图标
        UIImage *callIcon = [UIImage systemImageNamed:@"phone"];
        if (callIcon) {
            UIImageSymbolConfiguration *configCall = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
            callIcon = [UIImage systemImageNamed:@"phone" withConfiguration:configCall];
            callIcon = [callIcon imageWithTintColor:btnTextColor renderingMode:UIImageRenderingModeAlwaysOriginal];
            [btnVideoCall setImage:callIcon forState:UIControlStateNormal];
        }
        [btnVideoCall addTarget:self action:@selector(gotoVideoCall:) forControlEvents:UIControlEventTouchUpInside];
        [section addSubview:btnVideoCall];
        
        // 分隔线
        UIView *btnSep = [[UIView alloc] init];
        btnSep.translatesAutoresizingMaskIntoConstraints = NO;
        btnSep.backgroundColor = HexColor(0xE6E6E6);
        [section addSubview:btnSep];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.btnOpenChat.topAnchor constraintEqualToAnchor:section.topAnchor],
            [self.btnOpenChat.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
            [self.btnOpenChat.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
            [self.btnOpenChat.heightAnchor constraintEqualToConstant:56],
            
            [btnSep.topAnchor constraintEqualToAnchor:self.btnOpenChat.bottomAnchor],
            [btnSep.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
            [btnSep.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
            [btnSep.heightAnchor constraintEqualToConstant:0.5],
            
            [btnVideoCall.topAnchor constraintEqualToAnchor:btnSep.bottomAnchor],
            [btnVideoCall.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
            [btnVideoCall.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
            [btnVideoCall.heightAnchor constraintEqualToConstant:56],
            [btnVideoCall.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
        ]];
    } else {
        // ======= 非好友状态：加为好友 按钮 =======
        self.btnSendFriendRequest = [UIButton buttonWithType:UIButtonTypeCustom];
        self.btnSendFriendRequest.translatesAutoresizingMaskIntoConstraints = NO;
        [self.btnSendFriendRequest setTitle:@"添加到通讯录" forState:UIControlStateNormal];
        [self.btnSendFriendRequest setTitleColor:btnTextColor forState:UIControlStateNormal];
        self.btnSendFriendRequest.titleLabel.font = btnFont;
        self.btnSendFriendRequest.backgroundColor = [UIColor whiteColor];
        [self.btnSendFriendRequest addTarget:self action:@selector(sendFriendRequest:) forControlEvents:UIControlEventTouchUpInside];
        [section addSubview:self.btnSendFriendRequest];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.btnSendFriendRequest.topAnchor constraintEqualToAnchor:section.topAnchor],
            [self.btnSendFriendRequest.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
            [self.btnSendFriendRequest.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
            [self.btnSendFriendRequest.heightAnchor constraintEqualToConstant:56],
            [self.btnSendFriendRequest.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
        ]];
    }
    
    return section;
}

#pragma mark - UI辅助方法

- (UIView *)createArrowItemWithTitle:(NSString *)title value:(NSString *)value action:(SEL)action
{
    UIView *item = [[UIView alloc] init];
    item.backgroundColor = [UIColor whiteColor];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:17];
    titleLabel.textColor = [UIColor blackColor];
    [item addSubview:titleLabel];
    
    UIImageView *arrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"common_list_rightarrow_icon_nor"]];
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    [item addSubview:arrow];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [item addSubview:btn];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:item.leadingAnchor constant:20],
        [titleLabel.centerYAnchor constraintEqualToAnchor:item.centerYAnchor],
        
        [arrow.trailingAnchor constraintEqualToAnchor:item.trailingAnchor constant:-16],
        [arrow.centerYAnchor constraintEqualToAnchor:item.centerYAnchor],
        [arrow.widthAnchor constraintEqualToConstant:8],
        [arrow.heightAnchor constraintEqualToConstant:14],
        
        [btn.topAnchor constraintEqualToAnchor:item.topAnchor],
        [btn.leadingAnchor constraintEqualToAnchor:item.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:item.trailingAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:item.bottomAnchor],
    ]];
    
    if (value) {
        UILabel *valLabel = [[UILabel alloc] init];
        valLabel.translatesAutoresizingMaskIntoConstraints = NO;
        valLabel.text = value;
        valLabel.font = [UIFont systemFontOfSize:15];
        valLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        [item addSubview:valLabel];
        [NSLayoutConstraint activateConstraints:@[
            [valLabel.trailingAnchor constraintEqualToAnchor:arrow.leadingAnchor constant:-8],
            [valLabel.centerYAnchor constraintEqualToAnchor:item.centerYAnchor],
        ]];
    }
    
    return item;
}

- (UIView *)createInfoItemWithTitle:(NSString *)title valueLabel:(UILabel *)existingLabel
{
    UIView *item = [[UIView alloc] init];
    item.backgroundColor = [UIColor whiteColor];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:17];
    titleLabel.textColor = [UIColor blackColor];
    [item addSubview:titleLabel];
    
    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [UIFont systemFontOfSize:15];
    valueLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    valueLabel.tag = 1001;
    [item addSubview:valueLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [item.heightAnchor constraintEqualToConstant:56],
        
        [titleLabel.leadingAnchor constraintEqualToAnchor:item.leadingAnchor constant:20],
        [titleLabel.centerYAnchor constraintEqualToAnchor:item.centerYAnchor],
        [titleLabel.widthAnchor constraintLessThanOrEqualToConstant:100],
        
        [valueLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:16],
        [valueLabel.trailingAnchor constraintEqualToAnchor:item.trailingAnchor constant:-20],
        [valueLabel.centerYAnchor constraintEqualToAnchor:item.centerYAnchor],
    ]];
    
    [titleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [valueLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    
    return item;
}

- (UIView *)createSeparator
{
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor whiteColor];
    
    UIView *line = [[UIView alloc] init];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    [container addSubview:line];
    
    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintEqualToConstant:0.5],
        [line.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [line.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [line.topAnchor constraintEqualToAnchor:container.topAnchor],
        [line.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    
    return container;
}

#pragma mark - 最近登录（与通讯录副标题语义对齐）

/// 好友时优先用好友列表里的实体（含 IM/2-7 同步的 liveStatus、latest_login_time）；否则用当前页传入对象
- (UserEntity *)rb_userEntityForPresenceAndLastLogin
{
    if (![self isFriend])
        return self.friendInfoForInit;
    UserEntity *roster = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:self.friendInfoForInit.user_uid];
    return roster ?: self.friendInfoForInit;
}

/// 通讯录：在线看 liveStatus；离线无时间戳显示「离线」。资料页原先仅看 latest_login_time，在线无时间戳会误显示「从未登陆」
- (void)rb_refreshLatestLoginDisplay
{
    BOOL canSeePrivateInfo = [self isFriend] || [BasicTool isSystemAdmin:[BasicTool getLocalUserUid]];
    if (!canSeePrivateInfo) {
        self.viewLatestLoginTime.text = @"好友可见";
        return;
    }
    UserEntity *src = [self rb_userEntityForPresenceAndLastLogin];
    if ([src isOnline]) {
        self.viewLatestLoginTime.text = @"在线";
        return;
    }
    NSString *lastLoginTimeStr = [src getLatestLoginTimeStr];
    self.viewLatestLoginTime.text = [BasicTool isStringEmpty:lastLoginTimeStr] ? @"离线" : lastLoginTimeStr;
}

#pragma mark - 初始化视图数据

- (void)initViews
{
    // * 如果该人员已经是好友了
    if ([self isFriend]) {
        // 隐藏陌生人标签
        self.viewGuestFlag.hidden = YES;
    } else {
        // 如果是系统账号则显示为"管理员"字样
        if ([BasicTool isSystemAdmin:self.friendInfoForInit.user_uid]) {
            self.viewGuestFlag.text = @"管理员";
        }
        self.viewGuestFlag.hidden = NO;
    }
    
    // 昵称信息
    self.viewNickname.text = [self.friendInfoForInit getNickNameWithRemark];
    self.viewOriginalNickname.text = [NSString stringWithFormat:@"昵称：%@", self.friendInfoForInit.nickname];
    
    // 是否有备注
    BOOL hasRemark = ![BasicTool isStringEmpty:self.friendInfoForInit.friendRemark];
    self.viewOriginalNickname.hidden = !hasRemark;
    
    // 性别图标
    [self.imgSex setImage:[UIImage imageNamed:[self.friendInfoForInit isMan] ? @"sns_friend_list_form_item_male_img" : @"sns_friend_list_form_item_female_img"]];
    
    // 个性签名：签名内容（优先 whatsUp，无则 userDesc，再无则 暂无）
    NSString *sig = [BasicTool trim:self.friendInfoForInit.whatsUp];
    if (sig.length == 0) sig = [BasicTool trim:self.friendInfoForInit.userDesc];
    self.viewWhatsup.text = [NSString stringWithFormat:@"个性签名：%@", (sig.length > 0 ? sig : @"此人超懒，什么都没留下")];
    
    // UID
    self.viewUid.text = [NSString stringWithFormat:@"ID: %@", self.friendInfoForInit.user_uid ?: @""];
    
    // 注册时间
    BOOL canSeePrivateInfo = [self isFriend] || [BasicTool isSystemAdmin:[BasicTool getLocalUserUid]];
    self.viewRegisterTime.text = canSeePrivateInfo ? self.friendInfoForInit.register_time : @"好友可见";
    
    // 最近登录：与通讯录一致——在线看 liveStatus；时间戳来自好友列表模型（3-8 接口常不带 latest_login_time）
    [self rb_refreshLatestLoginDisplay];
    
    // 其它说明
    self.viewCaption.text = [BasicTool isStringEmpty:self.friendInfoForInit.userDesc] ? @"此人没有留下更多说明。" : self.friendInfoForInit.userDesc;
    
    // 按需载入用户头像
    [self loadAvatar];
    
    // 加载并显示相册中的相片和个人介绍语音数量
    [self loadPhotosAndVoicesCount];
    
    // 加载个人相册预览图片
    [self loadPhotosPreview];
    
    // 为头像组件添加点击事件
    [BasicTool addFingerClick:self.imgAvadar action:@selector(fingerTappedUserAvatar:) target:self];
    
    // 关于好友备注的ui显示内容和逻辑
    if ([self isFriend]) {
        [self refreshViewsForRemark:self.friendInfoForInit];
    }
}

#pragma mark - 刷新好友备注

- (void)refreshViewsForRemark:(UserEntity *)friendInfo
{
    if (friendInfo == nil) {
        DDLogWarn(@"好友信息界面中，refreshViewsForRemark时，friendInfo == nil!");
        return;
    }
    
    // 昵称
    self.viewNickname.text = [self.friendInfoForInit getNickNameWithRemark];
    
    // 是否有备注
    BOOL hasRemark = ![BasicTool isStringEmpty:friendInfo.friendRemark];
    self.viewOriginalNickname.hidden = !hasRemark;

    // 星标图标：仅好友且为星标时显示在昵称行右上角
    self.imgStarIcon.hidden = ![self isFriend] || ![self isCurrentFriendStarred];
}

#pragma mark - 点击事件

// 点击用户头像，查看头像大图
- (void)fingerTappedUserAvatar:(UITapGestureRecognizer *)gestureRecognizer
{
    if ([BasicTool isSystemAdmin:self.friendInfoForInit.user_uid]) {
        [BasicTool showAlertInfo:@"系统账号，没有头像可看哦！" parent:self];
        return;
    }
    
    if ([BasicTool isStringEmpty:self.friendInfoForInit.userAvatarFileName]) {
        [BasicTool showAlertInfo:@"该用户没有设置头像！" parent:self];
    } else {
        [MoreViewController showUserAvatarBigImage:self.friendInfoForInit.user_uid avatarFileName:self.friendInfoForInit.userAvatarFileName withParent:self];
    }
}

// 点击"更多"按钮时调用的方法
- (void)gotoMore
{
    __weak typeof(self) safeSelf = self;
    BOOL isStarred = [self isCurrentFriendStarred];
    NSMutableArray<NSString *> *otherTitles = [NSMutableArray array];
    if ([self isFriend]) {
        [otherTitles addObject:isStarred ? @"取消星标" : @"标记为星标好友"];
    }
    [otherTitles addObject:@"举报此人"];
    [otherTitles addObject:@"把他推荐给好友"];
    if ([self isFriend]) {
        [otherTitles addObject:@"删除好友"];
    }
    
    LPActionSheetBlock moreActionSheetHandler = ^(LPActionSheet *actionSheet, NSInteger index) {
        if ([safeSelf isFriend] && index == 1) {
            [safeSelf doToggleStarFriend];
        }
        else if (([safeSelf isFriend] && index == 2) || (![safeSelf isFriend] && index == 1)) {
            [safeSelf doReport];
        }
        else if (([safeSelf isFriend] && index == 3) || (![safeSelf isFriend] && index == 2)) {
            [safeSelf doRecommendToFriends];
        }
        else if ([safeSelf isFriend] && index == 4) {
            [safeSelf doDeleteFriend];
        }
    };
    
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:otherTitles
                                    handler:moreActionSheetHandler];
}

- (void)gotoPhotos:(UIButton *)sender
{
    [ViewControllerFactory goPhotosViewController:self.navigationController withUid:self.friendInfoForInit.user_uid canMgr:NO];
}

- (void)gotoPVoices:(UIButton *)sender
{
    [ViewControllerFactory goVoicesViewController:self.navigationController withUid:self.friendInfoForInit.user_uid canMgr:NO];
}

// 打开一对一好友聊天界面
- (void)gotoChat:(UIButton *)sender
{
    if (![self checkValidForTempChat_checkIfMeself:YES andCheckIsFriend:NO])
        return;
    if ([BasicTool isOfficialAccountHideAvatarInChat:self.friendInfoForInit.user_uid]) {
        [ViewControllerFactory goOfficialAccountChatViewController:self.friendInfoForInit.user_uid nickname:[self.friendInfoForInit getNickNameWithRemark] toNav:self.navigationController popToRootFirst:YES highlight:nil];
        return;
    }
    [ViewControllerFactory goChatViewController:self.friendInfoForInit.user_uid andNickname:[self.friendInfoForInit getNickNameWithRemark] toNav:self.navigationController popToRootFirst:YES highlight:nil];
}

// 音视频通话
- (void)gotoVideoCall:(UIButton *)sender
{
    if (![self checkValidForTempChat_checkIfMeself:YES andCheckIsFriend:NO])
        return;

    __weak typeof(self) safeSelf = self;
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"语音通话", @"视频通话"]
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == 1) {
            // 语音通话
            [[CallManager sharedInstance] startCall:safeSelf.friendInfoForInit.user_uid
                                    remoteNickname:[safeSelf.friendInfoForInit getNickNameWithRemark]
                                          callType:CallTypeVoice];
            [ViewControllerFactory goCallViewController:safeSelf.friendInfoForInit.user_uid
                                     remoteUserNickname:[safeSelf.friendInfoForInit getNickNameWithRemark]
                                               callType:CallTypeVoice
                                               isCaller:YES];
        } else if (index == 2) {
            // 视频通话
            [[CallManager sharedInstance] startCall:safeSelf.friendInfoForInit.user_uid
                                    remoteNickname:[safeSelf.friendInfoForInit getNickNameWithRemark]
                                          callType:CallTypeVideo];
            [ViewControllerFactory goCallViewController:safeSelf.friendInfoForInit.user_uid
                                     remoteUserNickname:[safeSelf.friendInfoForInit getNickNameWithRemark]
                                               callType:CallTypeVideo
                                               isCaller:YES];
        }
    }];
}

// 打开好友备注编辑界面
- (void)gotoFriendRemarkEdit:(UIButton *)sender
{
    [ViewControllerFactory goFriendRemarkEditViewController:self.navigationController withUid:self.friendInfoForInit.user_uid];
}

// 加好友请求
- (void)sendFriendRequest:(UIButton *)sender
{
    [ViewControllerFactory goFriendReqSendViewController:self.navigationController withDatas:self.friendInfoForInit addSource:self.addSource];
}

#pragma mark - 网络数据加载

- (void)loadAvatar
{
    __weak typeof(self) safeSelf = self;
    
    if (![BasicTool isStringEmpty:self.friendInfoForInit.userAvatarFileName]) {
        NSString *fileDownloadPath = [FileDownloadHelper getUserAvatarDownloadURLExt:NO fileName:nil uid:self.friendInfoForInit.user_uid];
        UIImage *cachedImage = [FileDownloadHelper loadUserAvatarFromCacheOnly:fileDownloadPath donotLoadFromDisk:NO];
        if (cachedImage != nil) {
            [self.imgAvadar setImage:cachedImage];
        }
        
        DDLogDebug(@"【FriendInfoViewController】用户头像有缓存吗？%d，马上开始强制开始下载最新的（url=%@）!", (cachedImage != nil), fileDownloadPath);
        [FileDownloadHelper loadUserAvatarFromInternetOnly:fileDownloadPath
                                                    logTag:@"FriendInfoViewController-AvatarUID"
                                                  complete:^(BOOL sucess, UIImage *img) {
            if (sucess && img != nil)
                [safeSelf.imgAvadar setImage:img];
        }];
    }
}

- (void)loadPhotosAndVoicesCount
{
    [[HttpRestHelper sharedInstance] queryPhotosOrVoicesCountFromServer:self.friendInfoForInit.user_uid complete:^(BOOL sucess, int photosCount, int pvoiceCount) {
        if (sucess) {
            self.viewPhotosCount.hidden = (photosCount <= 0);
            self.viewPhotosCount.text = [NSString stringWithFormat:@"%d", photosCount > 0 ? photosCount : 0];
            self.viewPVoicesCount.hidden = (pvoiceCount <= 0);
            self.viewPVoicesCount.text = [NSString stringWithFormat:@"%d", pvoiceCount > 0 ? pvoiceCount : 0];
        } else {
            [APP showToastWarn:@"加载相片和个人语音数量失败了！"];
        }
    } hudParentView:nil];
}

- (void)loadPhotosPreview
{
    __weak typeof(self) safeSelf = self;
    
    [[HttpRestHelper sharedInstance] queryPhotosPreviewListFromServer:self.friendInfoForInit.user_uid complete:^(BOOL sucess, NSArray<NSArray<NSString *> *> *fileNameList) {
        
        BOOL showPhotoPreview = NO;
        
        if (fileNameList != nil) {
            NSArray<UIImageView *> *views = @[safeSelf.imgPhotoPreview1, safeSelf.imgPhotoPreview2, safeSelf.imgPhotoPreview3, safeSelf.imgPhotoPreview4];
            
            if (fileNameList != nil && [fileNameList count] > 0) {
                showPhotoPreview = YES;
                
                safeSelf.layoutPhotosPreview.hidden = NO;
                safeSelf.photosSectionHeightConstraint.constant = 56 + 50 + 16; // titleRow + preview + padding
                
                int i = 0;
                for (NSArray<NSString *> *row in fileNameList) {
                    if (i >= 4) break;
                    NSString *res_file_name = [row objectAtIndex:0];
                    
                    UIImageView *view = views[i++];
                    view.hidden = NO;
                    
                    [FileDownloadHelper loadUserPhoto:[NSString stringWithFormat:@"th_%@", res_file_name] logTag:@"FriendInfoViewController" complete:^(BOOL sucess, UIImage *img) {
                        if (sucess && img != nil) {
                            [view setImage:img];
                        } else {
                            [view setImage:[UIImage imageNamed:@"sns_friend_info_form_photo_preview_default_img"]];
                        }
                    }];
                }
            }
        } else {
            [APP showToastWarn:@"加载相片预览图片失败了！"];
        }
        
        if (!showPhotoPreview) {
            safeSelf.photosSectionHeightConstraint.constant = 56;
        }
        
    } hudParentView:nil];
}

#pragma mark - 删除好友

- (void)doDeleteFriend
{
    __weak typeof(self) safeSelf = self;
    UserEntity *ree = self.friendInfoForInit;
    
    [LPActionSheet showActionSheetWithTitle:[NSString stringWithFormat:@"将\"%@\"从好友列表中删除？聊天记录会保留。", [ree getNickNameWithRemark]]
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:@"确认删除好友"
                          otherButtonTitles:nil
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == -1) {
            if (ree != nil) {
                                                [ContactViewController doDeleteFriendImpl:safeSelf.view uidWillBeDelete:ree.user_uid complete:^(BOOL sucess) {
                    if (sucess) {
                        [APP showUserDefineToast_OK:@"已删除好友，对方的消息将被拦截"];
                                                        [safeSelf.navigationController popToRootViewControllerAnimated:YES];
                                                    } else {
                                                        NSString *info = [NSString stringWithFormat:@"删除%@失败!", [ree getNickNameWithRemark]];
                                                        [BasicTool showAlertInfo:info parent:safeSelf];
                                                    }
                                                }];
                                            }
                                        }
                                    }];
}

#pragma mark - 举报

- (void)doReport
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

#pragma mark - 星标好友

- (BOOL)isCurrentFriendStarred
{
    UserEntity *cached = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:self.friendInfoForInit.user_uid];
    return cached != nil && [cached.is_starred isEqualToString:@"1"];
}

- (void)doToggleStarFriend
{
    if (![self isFriend]) return;
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    NSString *friendUid = self.friendInfoForInit.user_uid;
    if (!localUid.length || !friendUid.length) return;
    __weak typeof(self) safeSelf = self;
    BOOL currentlyStarred = [self isCurrentFriendStarred];
    void (^doStar)(void) = ^{
        [[HttpRestHelper sharedInstance] submitStarFriendToServer:localUid friendUid:friendUid complete:^(BOOL sucess, NSString *resultCode) {
            if (sucess && [resultCode isEqualToString:@"1"]) {
                [APP showUserDefineToast_OK:@"已设为星标好友"];
                UserEntity *cached = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:friendUid];
                if (cached) cached.is_starred = @"1";
                [[[IMClientManager sharedInstance] getFriendsListProvider] refreshFriendsDataAsync:nil];
                [safeSelf refreshViewsForRemark:safeSelf.friendInfoForInit];
            } else {
                [BasicTool showAlertInfo:@"操作失败，请稍后重试" parent:safeSelf];
            }
        } hudParentView:safeSelf.view];
    };
    void (^doUnstar)(void) = ^{
        [[HttpRestHelper sharedInstance] submitUnstarFriendToServer:localUid friendUid:friendUid complete:^(BOOL sucess, NSString *resultCode) {
            if (sucess && [resultCode isEqualToString:@"1"]) {
                [APP showUserDefineToast_OK:@"已取消星标"];
                UserEntity *cached = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:friendUid];
                if (cached) cached.is_starred = @"0";
                [[[IMClientManager sharedInstance] getFriendsListProvider] refreshFriendsDataAsync:nil];
                [safeSelf refreshViewsForRemark:safeSelf.friendInfoForInit];
            } else {
                [BasicTool showAlertInfo:@"操作失败，请稍后重试" parent:safeSelf];
            }
        } hudParentView:safeSelf.view];
    };
    if (currentlyStarred) doUnstar(); else doStar();
}

#pragma mark - 把他推荐给好友

- (void)doRecommendToFriends
{
    if (self.friendInfoForInit == nil || self.friendInfoForInit.user_uid.length == 0) return;
    NSString *profileUid = self.friendInfoForInit.user_uid;
    NSString *profileName = [self.friendInfoForInit getNickNameWithRemark];
    if (!profileName.length) profileName = profileUid;
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid ?: @"";
    __weak typeof(self) safeSelf = self;
    TargetSourceFilter4Friend friendFilter = ^BOOL(UserEntity *originalData) {
        if (originalData == nil || originalData.user_uid.length == 0) return NO;
        if ([originalData.user_uid isEqualToString:localUid]) return NO;
        if ([originalData.user_uid isEqualToString:profileUid]) return NO;
        return YES;
    };
    [ViewControllerFactory goTargetChooseViewController:self.navigationController
                                supportedTargetSource:TargetSourceFriend
                                 latestChattingFilter:nil
                                         friendFilter:friendFilter
                                          groupFilter:nil
                                   groupMemberFilter:nil
                                            extraObj:nil
                                                 gid:nil
                                         requestCode:REQUEST_CODE_RECOMMEND_TO_FRIEND
                                            delegate:self];
}

- (void)processTargetChooseComplete:(TargetEntity *)te extraObj:(id)obj requestCode:(int)requestCode
{
    if (requestCode != REQUEST_CODE_RECOMMEND_TO_FRIEND || te == nil || self.friendInfoForInit == nil) return;
    if (te.targetChatType != CHAT_TYPE_FREIDN_CHAT) return;
    NSString *toUid = te.targetId;
    NSString *toName = te.targetName ?: toUid;
    ContactMeta *cm = [ContactMeta initWith:CONTACT_TYPE_USER
                                         uid:self.friendInfoForInit.user_uid
                                   nickname:[self.friendInfoForInit getNickNameWithRemark]
                                       desc:nil];
    [MessageHelper sendContactMessageAsync:toUid withMeta:cm forSucess:^(id observerble, id arg1) {
        [APP showUserDefineToast_OK:[NSString stringWithFormat:@"已向 %@ 推荐了TA", toName] atHide:nil];
    }];
}

#pragma mark - 加入黑名单

- (void)doAddBlacklist
{
    __weak typeof(self) safeSelf = self;
    
    LPActionSheetBlock laheiConfirmActionSheetHandler = ^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == -1) {
            if (safeSelf.friendInfoForInit != nil) {
                // 调用服务端拉黑接口（服务端会自动解除好友关系）
                [[BlacklistManager sharedInstance] addUserToBlacklist:safeSelf.friendInfoForInit.user_uid
                                                            nickname:safeSelf.friendInfoForInit.nickname
                                                      avatarFileName:safeSelf.friendInfoForInit.userAvatarFileName];
                
                // 本地好友列表也同步移除
                if ([[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster:safeSelf.friendInfoForInit.user_uid]) {
                    FriendsListProvider *flp = [[IMClientManager sharedInstance] getFriendsListProvider];
                    int idx = [flp getIndex:safeSelf.friendInfoForInit.user_uid];
                    if (idx >= 0) {
                        [flp remove:idx uid:safeSelf.friendInfoForInit.user_uid];
                    }
                }
                
                // 清理本地陌生人会话
                int alarmIndex = [[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmIndex:AMT_guestChatMessage dataId:safeSelf.friendInfoForInit.user_uid];
                if (alarmIndex >= 0) {
                    [[[IMClientManager sharedInstance] getAlarmsProvider] removeAlarm:alarmIndex notify:YES deleteAlarmLocalData:YES deleteLocalData:YES];
                }
                
                [APP showUserDefineToast_OK:@"拉黑成功！"];
                [safeSelf doBack:NO];
                [NotificationCenterFactory blockUserComplete_POST:safeSelf.friendInfoForInit.user_uid];
            }
        }
    };
    
    [LPActionSheet showActionSheetWithTitle:[NSString stringWithFormat:@"确定将\"%@\"加入黑名单吗？", self.friendInfoForInit.nickname]
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:@"拉黑此人"
                          otherButtonTitles:nil
                                    handler:laheiConfirmActionSheetHandler];
}

#pragma mark - 工具方法

- (BOOL)checkValidForTempChat_checkIfMeself:(BOOL)checkIfMeself andCheckIsFriend:(BOOL)checkIsFriend
{
    if (checkIfMeself && [self.friendInfoForInit.user_uid isEqualToString:[IMClientManager sharedInstance].localUserInfo.user_uid]) {
        [BasicTool showAlertInfo:@"自已不能发送消息给自已哦！" parent:self];
        return NO;
    }
    
    if (checkIsFriend && [self isFriend]) {
        NSString *hint = [NSString stringWithFormat:@"%@已经是你的好友了, 请关闭本界面本并进入 \"好友\"界面聊天哦！", self.friendInfoForInit.nickname];
        [BasicTool showAlertInfo:hint parent:self];
        return NO;
    }
    
    return YES;
}

- (void)doBack:(BOOL)animated
{
    [self.navigationController popViewControllerAnimated:animated];
}

- (BOOL)isFriend
{
    return (self.friendInfoForInit != nil
            && [[IMClientManager sharedInstance] getFriendsListProvider] != nil
            && [[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster:self.friendInfoForInit.user_uid]);
}

@end
