#import "GroupNotificationsViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "BasicTool.h"
#import "Default.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "GroupsProvider.h"
#import "GroupEntity.h"
#import "TimeTool.h"
#import "NotificationCenterFactory.h"
#import "FileDownloadHelper.h"
#import "ViewControllerFactory.h"
#import "GroupsViewController.h"
#import "GroupNotificationJoinRequestDetailViewController.h"
#import "SDImageCache.h"
#import "UserDefaultsToolKits.h"

static NSString *const kGroupNotificationsCellId = @"GroupNotificationsCell";
static NSInteger const kGroupNotificationsPageSize = 20;

static NSString *RBGroupNotificationAvatarURLFromItem(NSDictionary *item)
{
    if (![item isKindOfClass:[NSDictionary class]]) {
        return @"";
    }
    NSString *avatarURL = [item[@"avatar_url"] isKindOfClass:[NSString class]] ? item[@"avatar_url"] : @"";
    NSString *gid = [item[@"g_id"] respondsToSelector:@selector(stringValue)] ? [item[@"g_id"] stringValue] : @"";
    NSString *customAvatar = [item[@"g_custom_avatar"] isKindOfClass:[NSString class]] ? item[@"g_custom_avatar"] : @"";
    if (avatarURL.length == 0 && gid.length > 0) {
        if (customAvatar.length == 0) {
            GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];
            if (ge.g_custom_avatar.length > 0) {
                customAvatar = ge.g_custom_avatar;
            }
        }
        avatarURL = [GroupsViewController getGroupAvatarDownloadURL:gid customAvatar:customAvatar];
    }
    return avatarURL ?: @"";
}

static NSString *RBGroupNotificationNotifyTypeFromItem(NSDictionary *item)
{
    if (![item isKindOfClass:[NSDictionary class]]) {
        return @"";
    }
    id value = item[@"notify_type"];
    if (![value isKindOfClass:[NSString class]] || ((NSString *)value).length == 0) {
        NSDictionary *raw = [item[@"raw"] isKindOfClass:[NSDictionary class]] ? item[@"raw"] : nil;
        value = raw[@"notify_type"] ?: raw[@"notifyType"] ?: raw[@"type"];
    }
    return [value isKindOfClass:[NSString class]] ? [(NSString *)value lowercaseString] : @"";
}

static NSString *RBGroupNotificationStringFromValue(id value)
{
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    return @"";
}

static BOOL RBGroupNotificationBoolFromValue(id value, BOOL defaultValue)
{
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value boolValue];
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *lower = [((NSString *)value) lowercaseString];
        if ([lower isEqualToString:@"1"] || [lower isEqualToString:@"true"] || [lower isEqualToString:@"yes"]) {
            return YES;
        }
        if ([lower isEqualToString:@"0"] || [lower isEqualToString:@"false"] || [lower isEqualToString:@"no"]) {
            return NO;
        }
    }
    return defaultValue;
}

static NSString *RBGroupNotificationJoinStatusText(NSDictionary *item)
{
    NSString *notifyType = RBGroupNotificationNotifyTypeFromItem(item);
    if (notifyType.length == 0 || [notifyType rangeOfString:@"join"].location == NSNotFound) {
        return @"";
    }
    NSDictionary *raw = [item[@"raw"] isKindOfClass:[NSDictionary class]] ? item[@"raw"] : nil;
    NSString *statusDesc = RBGroupNotificationStringFromValue(item[@"status_desc"]);
    if (statusDesc.length == 0) {
        statusDesc = RBGroupNotificationStringFromValue(raw[@"status_desc"]);
    }
    if (statusDesc.length == 0) {
        statusDesc = RBGroupNotificationStringFromValue(item[@"statusDesc"]);
    }
    if (statusDesc.length == 0) {
        statusDesc = RBGroupNotificationStringFromValue(raw[@"statusDesc"]);
    }
    if (statusDesc.length > 0) {
        return statusDesc;
    }
    NSString *status = RBGroupNotificationStringFromValue(item[@"status"]);
    if (status.length == 0) {
        status = RBGroupNotificationStringFromValue(raw[@"status"]);
    }
    if ([status isEqualToString:@"0"]) {
        return @"待审核";
    }
    if ([status isEqualToString:@"1"]) {
        return @"已通过";
    }
    if ([status isEqualToString:@"2"]) {
        return @"已拒绝";
    }
    id approvedValue = item[@"approved"] ?: raw[@"approved"];
    if (approvedValue != nil) {
        return RBGroupNotificationBoolFromValue(approvedValue, NO) ? @"已通过" : @"已拒绝";
    }
    NSString *reviewTime = RBGroupNotificationStringFromValue(item[@"review_time"]);
    if (reviewTime.length == 0) {
        reviewTime = RBGroupNotificationStringFromValue(raw[@"review_time"]);
    }
    if (reviewTime.length > 0) {
        NSString *content = RBGroupNotificationStringFromValue(item[@"content"]);
        NSString *rejectReason = RBGroupNotificationStringFromValue(item[@"reject_reason"]);
        if (rejectReason.length == 0) {
            rejectReason = RBGroupNotificationStringFromValue(raw[@"reject_reason"]);
        }
        if (rejectReason.length > 0 || [content containsString:@"拒绝"]) {
            return @"已拒绝";
        }
        return @"已通过";
    }
    return @"待审核";
}

static BOOL RBGroupNotificationShouldShowJoinStatus(NSDictionary *item)
{
    NSString *statusText = RBGroupNotificationJoinStatusText(item);
    return [statusText isEqualToString:@"待审核"] || [statusText isEqualToString:@"待处理"];
}

@interface RBGroupNotificationCell : UITableViewCell

@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *groupNameLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIImageView *arrowImageView;
@property (nonatomic, strong) UIView *dividerView;
@property (nonatomic, copy) NSString *currentGid;

- (void)configureWithItem:(NSDictionary *)item hideDivider:(BOOL)hideDivider;

@end

@implementation RBGroupNotificationCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UI_DEFAULT_BG;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentView.backgroundColor = UI_DEFAULT_BG;
    self.separatorInset = UIEdgeInsetsMake(0, 10000, 0, 0);
    self.layoutMargins = UIEdgeInsetsZero;
    self.preservesSuperviewLayoutMargins = NO;

    UIView *selectedBg = [[UIView alloc] initWithFrame:CGRectZero];
    selectedBg.backgroundColor = HexColor(0xEEF3FA);
    self.selectedBackgroundView = selectedBg;

    self.avatarImageView = [[UIImageView alloc] init];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.layer.cornerRadius = 24.0f;
    self.avatarImageView.layer.masksToBounds = YES;
    self.avatarImageView.backgroundColor = HexColor(0xEAF2FF);
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.clipsToBounds = YES;
    [self.contentView addSubview:self.avatarImageView];

    self.groupNameLabel = [[UILabel alloc] init];
    self.groupNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.groupNameLabel.textColor = HexColor(0x1F2329);
    self.groupNameLabel.font = [UIFont boldSystemFontOfSize:[BasicTool getAdjustedFontSize:16.0f]];
    self.groupNameLabel.numberOfLines = 1;
    [self.contentView addSubview:self.groupNameLabel];

    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.textColor = HexColor(0xB1B5BE);
    self.timeLabel.font = [UIFont systemFontOfSize:[BasicTool getAdjustedFontSize:12.0f]];
    self.timeLabel.numberOfLines = 1;
    [self.timeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.timeLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentView addSubview:self.timeLabel];

    self.contentLabel = [[UILabel alloc] init];
    self.contentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentLabel.textColor = HexColor(0x8E8E93);
    self.contentLabel.font = [UIFont systemFontOfSize:[BasicTool getAdjustedFontSize:14.0f]];
    self.contentLabel.numberOfLines = 2;
    [self.contentView addSubview:self.contentLabel];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont systemFontOfSize:[BasicTool getAdjustedFontSize:13.0f]];
    self.statusLabel.textColor = HexColor(0x07C160);
    self.statusLabel.numberOfLines = 1;
    [self.statusLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.statusLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentView addSubview:self.statusLabel];

    self.arrowImageView = [[UIImageView alloc] init];
    self.arrowImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.arrowImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.arrowImageView.image = [UIImage imageNamed:@"common_cell_arrow"];
    self.arrowImageView.tintColor = HexColor(0xC7CDD8);
    [self.contentView addSubview:self.arrowImageView];

    self.dividerView = [[UIView alloc] init];
    self.dividerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dividerView.backgroundColor = HexColor(0xEEF1F5);
    [self.contentView addSubview:self.dividerView];

    CGFloat dividerHeight = 1.0f / MAX(UIScreen.mainScreen.scale, 1.0f);
    [NSLayoutConstraint activateConstraints:@[
        [self.avatarImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0f],
        [self.avatarImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0f],
        [self.avatarImageView.widthAnchor constraintEqualToConstant:48.0f],
        [self.avatarImageView.heightAnchor constraintEqualToConstant:48.0f],

        [self.groupNameLabel.leadingAnchor constraintEqualToAnchor:self.avatarImageView.trailingAnchor constant:14.0f],
        [self.groupNameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0f],

        [self.timeLabel.leadingAnchor constraintEqualToAnchor:self.groupNameLabel.trailingAnchor constant:8.0f],
        [self.timeLabel.firstBaselineAnchor constraintEqualToAnchor:self.groupNameLabel.firstBaselineAnchor],
        [self.timeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusLabel.leadingAnchor constant:-8.0f],

        [self.contentLabel.leadingAnchor constraintEqualToAnchor:self.groupNameLabel.leadingAnchor],
        [self.contentLabel.topAnchor constraintEqualToAnchor:self.groupNameLabel.bottomAnchor constant:6.0f],
        [self.contentLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusLabel.leadingAnchor constant:-12.0f],

        [self.arrowImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0f],
        [self.arrowImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.arrowImageView.widthAnchor constraintEqualToConstant:7.0f],
        [self.arrowImageView.heightAnchor constraintEqualToConstant:12.0f],

        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.arrowImageView.leadingAnchor constant:-6.0f],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],

        [self.dividerView.leadingAnchor constraintEqualToAnchor:self.contentLabel.leadingAnchor],
        [self.dividerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.dividerView.topAnchor constraintEqualToAnchor:self.contentLabel.bottomAnchor constant:12.0f],
        [self.dividerView.heightAnchor constraintEqualToConstant:dividerHeight],
        [self.dividerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.currentGid = nil;
    self.avatarImageView.alpha = 1.0f;
    self.avatarImageView.image = [UIImage imageNamed:@"groupchat_groups_icon_default"];
    self.groupNameLabel.text = @"";
    self.timeLabel.text = @"";
    self.contentLabel.text = @"";
    self.statusLabel.text = @"";
    self.statusLabel.hidden = YES;
    self.arrowImageView.hidden = YES;
    self.dividerView.hidden = NO;
}

- (void)configureWithItem:(NSDictionary *)item hideDivider:(BOOL)hideDivider
{
    self.groupNameLabel.text = [item[@"groupName"] isKindOfClass:[NSString class]] ? item[@"groupName"] : @"群聊";
    self.timeLabel.text = [item[@"time"] isKindOfClass:[NSString class]] ? item[@"time"] : @"";
    self.contentLabel.text = [item[@"content"] isKindOfClass:[NSString class]] ? item[@"content"] : @"群通知";
    NSString *statusText = RBGroupNotificationJoinStatusText(item);
    self.statusLabel.text = statusText;
    self.statusLabel.hidden = (statusText.length == 0);
    self.arrowImageView.hidden = !RBGroupNotificationShouldShowJoinStatus(item);
    if ([statusText isEqualToString:@"已拒绝"]) {
        self.statusLabel.textColor = HexColor(0xFF4D4F);
    } else if ([statusText isEqualToString:@"待审核"] || [statusText isEqualToString:@"待处理"]) {
        self.statusLabel.textColor = HexColor(0xFF9F0A);
    } else {
        self.statusLabel.textColor = HexColor(0x07C160);
    }
    self.dividerView.hidden = hideDivider;

    NSString *gid = [item[@"g_id"] respondsToSelector:@selector(stringValue)] ? [item[@"g_id"] stringValue] : @"";
    self.currentGid = gid;
    self.avatarImageView.alpha = 1.0f;
    self.avatarImageView.image = [UIImage imageNamed:@"groupchat_groups_icon_default"];

    NSString *avatarURL = RBGroupNotificationAvatarURLFromItem(item);

    if (avatarURL.length > 0) {
        UIImage *cached = [FileDownloadHelper getUserAvatarFromSDImageCache:avatarURL donotLoadFromDisk:NO];
        if (cached != nil) {
            self.avatarImageView.image = cached;
            [[SDImageCache sharedImageCache] storeImage:cached forKey:avatarURL toDisk:NO completion:nil];
            return;
        }

        __weak typeof(self) weakSelf = self;
        [FileDownloadHelper loadChattingImgWithURL:avatarURL logTag:@"GroupNotificationsCell-AvatarURL" complete:^(BOOL sucess, UIImage *img) {
            dispatch_async(dispatch_get_main_queue(), ^{
                RBGroupNotificationCell *strongSelf = weakSelf;
                if (strongSelf == nil) return;
                if (![strongSelf.currentGid isEqualToString:gid]) return;
                if (sucess && img != nil) {
                    [UIView transitionWithView:strongSelf.avatarImageView
                                      duration:0.2
                                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                                    animations:^{
                                        strongSelf.avatarImageView.image = img;
                                    } completion:nil];
                }
            });
        }];
        return;
    }
}

@end

@interface GroupNotificationsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;
@property (nonatomic, copy) NSArray<NSDictionary *> *items;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL pendingRealtimeReload;
@property (nonatomic, assign) BOOL observingRealtimePush;

@end

@implementation GroupNotificationsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.titleView = nil;
    UIImage *moreImage = [UIImage imageNamed:@"common_more_ico"];
    [self rb_installPlainCustomNavigationBarWithTitle:@"群通知"
                                     rightButtonImage:moreImage
                                               target:self
                                               action:@selector(onMoreTapped)];
    self.view.backgroundColor = UI_DEFAULT_BG;

    [self setupUI];
    [self loadData];
}

- (void)setupUI
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[RBGroupNotificationCell class] forCellReuseIdentifier:kGroupNotificationsCellId];
    self.tableView.backgroundColor = UI_DEFAULT_BG;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.estimatedRowHeight = 82.0f;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 12.0f, 0.0f);
    if (@available(iOS 11.0, *)) {
        self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.text = @"暂无群通知";
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = HexColor(0x9AA0A6);
    self.emptyLabel.font = [UIFont systemFontOfSize:[BasicTool getAdjustedFontSize:15.0f]];
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-20.0f],
    ]];

    self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingView.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingView];
    [NSLayoutConstraint activateConstraints:@[
        [self.loadingView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-56.0f],
    ]];
}

- (void)loadData
{
    if (self.loading) {
        self.pendingRealtimeReload = YES;
        return;
    }

    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid ?: @"";
    if (myUid.length == 0) {
        [self rb_finishLoadingWithItems:@[]];
        return;
    }

    self.loading = YES;
    [self refreshUI];
    [self fetchAggregatedNotificationsForRequestUid:myUid];
}

- (void)fetchAggregatedNotificationsForRequestUid:(NSString *)requestUid
{
    __weak typeof(self) weakSelf = self;
    [[HttpRestHelper sharedInstance] submitQueryAllGroupNotificationsFromServer:requestUid
                                                                           page:1
                                                                       pageSize:kGroupNotificationsPageSize
                                                                       complete:^(BOOL sucess, NSDictionary *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!weakSelf) return;

            if (!sucess) {
                [weakSelf rb_finishLoadingWithItems:weakSelf.items ?: @[]];
                return;
            }

            NSArray *notifications = [result[@"notifications"] isKindOfClass:[NSArray class]] ? result[@"notifications"] : @[];
            NSMutableArray<NSDictionary *> *normalizedItems = [NSMutableArray arrayWithCapacity:notifications.count];
            for (NSDictionary *raw in notifications) {
                NSDictionary *item = [weakSelf normalizedAggregatedNotificationItem:raw];
                if (item != nil) {
                    [normalizedItems addObject:item];
                }
            }

            [weakSelf rb_finishLoadingWithItems:[weakSelf rb_sortedItemsFromItems:normalizedItems]];
        });
    } hudParentView:nil];
}

- (void)refreshUI
{
    BOOL hasItems = (self.items.count > 0);
    if (self.loading) {
        [self.loadingView startAnimating];
    } else {
        [self.loadingView stopAnimating];
    }
    self.tableView.hidden = (!hasItems && !self.loading);
    self.emptyLabel.hidden = (hasItems || self.loading);
    [self.tableView reloadData];
}

- (void)onMoreTapped
{
    [self loadData];
}

- (void)rb_finishLoadingWithItems:(NSArray<NSDictionary *> *)items
{
    self.loading = NO;
    self.items = items ?: @[];
    [self rb_markCurrentItemsAsReadIfNeeded];
    [self rb_prewarmGroupAvatarsForItems:self.items];
    [self refreshUI];
    if (self.pendingRealtimeReload) {
        self.pendingRealtimeReload = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadData];
        });
    }
}

- (void)rb_prewarmGroupAvatarsForItems:(NSArray<NSDictionary *> *)items
{
    if (items.count == 0) {
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (NSDictionary *item in items) {
            if (![item isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            NSString *avatarURL = RBGroupNotificationAvatarURLFromItem(item);
            if (avatarURL.length > 0) {
                UIImage *cached = [FileDownloadHelper getUserAvatarFromSDImageCache:avatarURL donotLoadFromDisk:NO];
                if (cached != nil) {
                    [[SDImageCache sharedImageCache] storeImage:cached forKey:avatarURL toDisk:NO completion:nil];
                }
                continue;
            }

            NSString *gid = [self rb_stringValue:item[@"g_id"]];
            if (gid.length == 0) {
                continue;
            }
            // loadGroupAvatar 内部会同步检查内存/磁盘缓存，并在命中磁盘时回灌内存。
            [FileDownloadHelper loadGroupAvatar:gid logTag:@"GroupNotifications-Prewarm" complete:^(BOOL sucess, UIImage *img) {
                (void)sucess;
                (void)img;
            }];
        }
    });
}

- (void)rb_registerRealtimeObserverIfNeeded
{
    if (self.observingRealtimePush) {
        return;
    }
    self.observingRealtimePush = YES;
    [NotificationCenterFactory groupNotificationsRealtime_ADD:self selector:@selector(rb_onGroupNotificationsRealtimePush:)];
}

- (void)rb_unregisterRealtimeObserverIfNeeded
{
    if (!self.observingRealtimePush) {
        return;
    }
    self.observingRealtimePush = NO;
    [NotificationCenterFactory groupNotificationsRealtime_REMOVE:self];
}

- (void)rb_onGroupNotificationsRealtimePush:(NSNotification *)notification
{
    NSDictionary *payload = [notification.object isKindOfClass:[NSDictionary class]] ? (NSDictionary *)notification.object : nil;
    if (payload != nil) {
        DDLogDebug(@"[GroupNotifications] 收到实时推送 msgType=%@ gid=%@", payload[@"msgType"], payload[@"gid"]);
    }

    NSDictionary *item = [self normalizedRealtimeNotificationItemFromPayload:payload];
    if (item == nil) {
        [self loadData];
        return;
    }

    if (self.loading) {
        self.pendingRealtimeReload = YES;
        return;
    }

    [self rb_mergeRealtimeNotificationItem:item];
}

- (void)rb_mergeRealtimeNotificationItem:(NSDictionary *)item
{
    if (![item isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSMutableArray<NSDictionary *> *mutableItems = [NSMutableArray arrayWithArray:self.items ?: @[]];
    NSString *itemId = [self rb_stringValue:item[@"id"]];
    if (itemId.length > 0) {
        NSInteger existingIndex = NSNotFound;
        for (NSInteger i = 0; i < mutableItems.count; i++) {
            NSString *existingId = [self rb_stringValue:mutableItems[i][@"id"]];
            if ([existingId isEqualToString:itemId]) {
                existingIndex = i;
                break;
            }
        }
        if (existingIndex != NSNotFound) {
            [mutableItems removeObjectAtIndex:existingIndex];
        }
    }
    [mutableItems insertObject:item atIndex:0];
    self.items = [self rb_sortedItemsFromItems:mutableItems];
    [self rb_markCurrentItemsAsReadIfNeeded];
    [self refreshUI];
}

- (NSDate *)rb_latestNotificationDateFromItems:(NSArray<NSDictionary *> *)items
{
    NSDictionary *latestItem = [items.firstObject isKindOfClass:[NSDictionary class]] ? items.firstObject : nil;
    if (latestItem == nil) {
        return nil;
    }
    id sortTsValue = latestItem[@"sort_ts"];
    if ([sortTsValue respondsToSelector:@selector(longLongValue)]) {
        long long sortTs = [sortTsValue longLongValue];
        if (sortTs > 0) {
            return [NSDate dateWithTimeIntervalSince1970:(sortTs / 1000.0)];
        }
    }
    return [self dateFromRawTimeValue:(latestItem[@"create_time"] ?: latestItem[@"createTime"])];
}

- (void)rb_markCurrentItemsAsReadIfNeeded
{
    if (self.view.window == nil) {
        return;
    }
    NSDate *latestDate = [self rb_latestNotificationDateFromItems:self.items];
    if (latestDate == nil) {
        return;
    }
    long long currentReadTs = [UserDefaultsToolKits getHasReadLatestGroupNotificationTimestamp];
    long long latestTs = (long long)([latestDate timeIntervalSince1970] * 1000.0);
    if (latestTs <= currentReadTs) {
        return;
    }
    [UserDefaultsToolKits setHasReadLatestGroupNotificationTimestamp:latestDate];
    [UserDefaultsToolKits setGroupNotificationUnreadCount:0];
    [NotificationCenterFactory refreshMainPageTotalUnread_POST];
}

- (NSArray<NSDictionary *> *)rb_sortedItemsFromItems:(NSArray<NSDictionary *> *)items
{
    return [items sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        long long ts1 = [obj1[@"sort_ts"] respondsToSelector:@selector(longLongValue)] ? [obj1[@"sort_ts"] longLongValue] : 0;
        long long ts2 = [obj2[@"sort_ts"] respondsToSelector:@selector(longLongValue)] ? [obj2[@"sort_ts"] longLongValue] : 0;
        if (ts1 != ts2) {
            return ts1 < ts2 ? NSOrderedDescending : NSOrderedAscending;
        }
        NSString *time1 = [self rb_stringValue:obj1[@"sort_time"]];
        NSString *time2 = [self rb_stringValue:obj2[@"sort_time"]];
        return [time2 compare:time1 options:NSNumericSearch];
    }];
}

- (NSDictionary *)normalizedAggregatedNotificationItem:(NSDictionary *)raw
{
    if (![raw isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSString *gid = [self rb_stringValue:raw[@"g_id"]];
    if (gid.length == 0) {
        gid = [self rb_stringValue:raw[@"gid"]];
    }
    if (gid.length == 0) {
        gid = [self rb_stringValue:raw[@"t"]];
    }
    if (gid.length == 0) {
        gid = [self rb_stringValue:raw[@"to"]];
    }
    NSString *groupName = [self rb_stringValue:raw[@"g_name"]];
    if (groupName.length == 0) {
        groupName = [self rb_stringValue:raw[@"gname"]];
    }
    if (groupName.length == 0) {
        groupName = [self groupNameForGid:gid fallback:@"群聊"];
    }

    id createTimeValue = raw[@"create_time"];
    if (createTimeValue == nil) {
        createTimeValue = raw[@"createTime"];
    }
    NSString *createTime = [self stringTimeFromRawTimeValue:createTimeValue];
    NSString *content = [self rb_stringValue:raw[@"content"]];
    if (content.length == 0) {
        content = [self rb_stringValue:raw[@"notification_content"]];
    }
    if (content.length == 0) {
        content = [self rb_stringValue:raw[@"notificationContent"]];
    }
    if (content.length == 0) {
        content = [self rb_stringValue:raw[@"m"]];
    }
    NSString *customAvatar = [self rb_stringValue:raw[@"g_custom_avatar"]];
    NSString *avatarURL = [self rb_stringValue:raw[@"avatar_url"]];
    if (avatarURL.length == 0) {
        avatarURL = [self rb_stringValue:raw[@"g_avatar_url"]];
    }
    if (avatarURL.length == 0) {
        avatarURL = [self rb_stringValue:raw[@"group_avatar_url"]];
    }
    NSString *itemId = [self notificationIdentifierFromRaw:raw msgType:0];
    NSString *notifyType = [self rb_stringValue:raw[@"notify_type"]];
    if (notifyType.length == 0) {
        notifyType = [self rb_stringValue:raw[@"notifyType"]];
    }
    if (notifyType.length == 0) {
        notifyType = [self rb_stringValue:raw[@"type"]];
    }
    if (content.length == 0) {
        content = [self fallbackNotificationContentForRaw:raw msgType:54];
    }
    if ([self rb_shouldExcludeGroupNoticeRaw:raw content:content]) {
        return nil;
    }
    content = [self normalizedNotificationContentForDisplay:content raw:raw];
    NSDate *date = [self dateFromRawTimeValue:createTimeValue];

    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:@{
        @"id": itemId ?: @"",
        @"g_id": gid ?: @"",
        @"groupName": groupName ?: @"群聊",
        @"time": [self displayTimeForDate:date fallback:createTime],
        @"content": content.length > 0 ? content : @"群通知",
        @"sort_time": createTime ?: @"",
        @"sort_ts": @([self sortTimestampFromRawTimeValue:createTimeValue fallbackDate:date]),
        @"notify_type": notifyType ?: @""
    }];
    item[@"raw"] = raw;
    NSString *status = [self rb_stringValue:raw[@"status"]];
    NSString *statusDesc = [self rb_stringValue:(raw[@"status_desc"] ?: raw[@"statusDesc"])];
    NSString *reviewTime = [self rb_stringValue:raw[@"review_time"]];
    NSString *reviewByUid = [self rb_stringValue:(raw[@"review_by_uid"] ?: raw[@"reviewer_uid"] ?: raw[@"operator_uid"])];
    NSString *reviewByNickname = [self rb_stringValue:(raw[@"review_by_nickname"] ?: raw[@"reviewer_nickname"] ?: raw[@"operator_nickname"])];
    if (status.length > 0) {
        item[@"status"] = status;
    }
    if (statusDesc.length > 0) {
        item[@"status_desc"] = statusDesc;
    }
    if (reviewTime.length > 0) {
        item[@"review_time"] = reviewTime;
    }
    if (reviewByUid.length > 0) {
        item[@"review_by_uid"] = reviewByUid;
    }
    if (reviewByNickname.length > 0) {
        item[@"review_by_nickname"] = reviewByNickname;
    }
    if (customAvatar.length > 0) {
        item[@"g_custom_avatar"] = customAvatar;
    }
    if (avatarURL.length > 0) {
        item[@"avatar_url"] = avatarURL;
    }
    return item;
}

- (NSDictionary *)normalizedRealtimeNotificationItemFromPayload:(NSDictionary *)payload
{
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *raw = [payload[@"raw"] isKindOfClass:[NSDictionary class]] ? payload[@"raw"] : nil;
    if (![raw isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSInteger msgType = [payload[@"msgType"] respondsToSelector:@selector(integerValue)] ? [payload[@"msgType"] integerValue] : 0;
    NSString *gid = [self rb_stringValue:payload[@"gid"]];
    if (gid.length == 0) {
        gid = [self rb_stringValue:raw[@"gid"]];
    }
    if (gid.length == 0) {
        gid = [self rb_stringValue:raw[@"g_id"]];
    }
    if (gid.length == 0) {
        gid = [self rb_stringValue:raw[@"t"]];
    }
    if (gid.length == 0) {
        gid = [self rb_stringValue:raw[@"to"]];
    }

    NSString *groupName = [self rb_stringValue:raw[@"gname"]];
    if (groupName.length == 0) {
        groupName = [self rb_stringValue:raw[@"g_name"]];
    }
    if (groupName.length == 0) {
        groupName = [self groupNameForGid:gid fallback:@"群聊"];
    }

    NSString *content = [self rb_stringValue:raw[@"content"]];
    if (content.length == 0) {
        content = [self rb_stringValue:raw[@"notification_content"]];
    }
    NSString *customAvatar = [self rb_stringValue:raw[@"g_custom_avatar"]];
    NSString *avatarURL = [self rb_stringValue:raw[@"avatar_url"]];
    if (avatarURL.length == 0) {
        avatarURL = [self rb_stringValue:raw[@"g_avatar_url"]];
    }
    if (avatarURL.length == 0) {
        avatarURL = [self rb_stringValue:raw[@"group_avatar_url"]];
    }
    if (content.length == 0 && msgType == 46) {
        NSString *nickname = [self rb_stringValue:raw[@"initveBeNickName"]];
        content = nickname.length > 0 ? [NSString stringWithFormat:@"\"%@\"邀请您加入了群聊", nickname] : @"你已加入群聊";
    } else if (content.length == 0 && msgType == 52) {
        NSString *nickname = [self rb_stringValue:raw[@"applicant_nickname"]];
        content = nickname.length > 0 ? [NSString stringWithFormat:@"\"%@\"申请加入群聊", nickname] : @"入群申请";
    } else if (content.length == 0 && msgType == 53) {
        BOOL approved = [self rb_boolValue:raw[@"approved"] defaultValue:NO];
        NSString *rejectReason = [self rb_stringValue:raw[@"reject_reason"]];
        if (approved) {
            content = @"你的入群申请已通过审核";
        } else {
            content = rejectReason.length > 0 ? [NSString stringWithFormat:@"你的入群申请已被拒绝：%@", rejectReason] : @"你的入群申请已被拒绝";
        }
    }

    id rawTimeValue = raw[@"create_time"];
    if (rawTimeValue == nil) {
        rawTimeValue = raw[@"createTime"];
    }
    NSDate *date = [self dateFromRawTimeValue:rawTimeValue];
    if (date == nil) {
        date = [NSDate date];
    }

    NSString *sortTime = [self serverTimeStringFromDate:date];
    NSString *itemId = [self notificationIdentifierFromRaw:raw msgType:msgType];
    NSString *notifyType = [self rb_stringValue:raw[@"notifyType"]];
    if (notifyType.length == 0) {
        notifyType = [self rb_stringValue:raw[@"notify_type"]];
    }
    if (notifyType.length == 0) {
        notifyType = [self rb_stringValue:raw[@"type"]];
    }
    if (content.length == 0) {
        content = [self fallbackNotificationContentForRaw:raw msgType:msgType];
    }
    if ([self rb_shouldExcludeGroupNoticeRaw:raw content:content]) {
        return nil;
    }
    content = [self normalizedNotificationContentForDisplay:content raw:raw];

    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:@{
        @"id": itemId ?: @"",
        @"g_id": gid ?: @"",
        @"groupName": groupName ?: @"群聊",
        @"time": [self displayTimeForDate:date fallback:sortTime],
        @"content": content.length > 0 ? content : @"群通知",
        @"sort_time": sortTime ?: @"",
        @"sort_ts": @([self sortTimestampFromRawTimeValue:rawTimeValue fallbackDate:date]),
        @"notify_type": notifyType ?: @""
    }];
    item[@"raw"] = raw;
    NSString *status = [self rb_stringValue:raw[@"status"]];
    NSString *statusDesc = [self rb_stringValue:(raw[@"status_desc"] ?: raw[@"statusDesc"])];
    NSString *reviewTime = [self rb_stringValue:raw[@"review_time"]];
    NSString *reviewByUid = [self rb_stringValue:(raw[@"review_by_uid"] ?: raw[@"reviewer_uid"] ?: raw[@"operator_uid"])];
    NSString *reviewByNickname = [self rb_stringValue:(raw[@"review_by_nickname"] ?: raw[@"reviewer_nickname"] ?: raw[@"operator_nickname"])];
    if (status.length > 0) {
        item[@"status"] = status;
    }
    if (statusDesc.length > 0) {
        item[@"status_desc"] = statusDesc;
    } else if (msgType == 52) {
        item[@"status_desc"] = @"待审核";
    }
    if (reviewTime.length > 0) {
        item[@"review_time"] = reviewTime;
    }
    if (reviewByUid.length > 0) {
        item[@"review_by_uid"] = reviewByUid;
    }
    if (reviewByNickname.length > 0) {
        item[@"review_by_nickname"] = reviewByNickname;
    }
    if (customAvatar.length > 0) {
        item[@"g_custom_avatar"] = customAvatar;
    }
    if (avatarURL.length > 0) {
        item[@"avatar_url"] = avatarURL;
    }
    return item;
}

- (BOOL)rb_shouldExcludeGroupNoticeRaw:(NSDictionary *)raw content:(NSString *)content
{
    if (![raw isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSString *notifyType = [[self rb_stringValue:(raw[@"notify_type"] ?: raw[@"notifyType"] ?: raw[@"type"])] lowercaseString];
    if ([notifyType containsString:@"notice"]) {
        return YES;
    }
    NSString *display = [BasicTool trim:[self rb_stringValue:content]];
    if (display.length == 0) {
        display = [BasicTool trim:[self rb_stringValue:raw[@"content"]]];
    }
    if (display.length == 0) {
        display = [BasicTool trim:[self rb_stringValue:raw[@"notification_content"]]];
    }
    if (display.length == 0) {
        display = [BasicTool trim:[self rb_stringValue:raw[@"notificationContent"]]];
    }
    if (display.length == 0) {
        display = [BasicTool trim:[self rb_stringValue:raw[@"m"]]];
    }
    if (display.length == 0) {
        return NO;
    }
    if ([display containsString:@"【群公告】"]) {
        return YES;
    }
    if (([display containsString:@"@所有人"] || [display containsString:@"所有人"])
        && [display containsString:@"群公告"]) {
        return YES;
    }
    if ([display hasPrefix:@"群公告："] || [display hasPrefix:@"群公告:"] || [display hasPrefix:@"[群公告]"]) {
        return YES;
    }
    return NO;
}

- (NSString *)fallbackNotificationContentForRaw:(NSDictionary *)raw msgType:(NSInteger)msgType
{
    if (![raw isKindOfClass:[NSDictionary class]]) {
        return @"群通知";
    }

    NSString *notifyType = [self rb_stringValue:raw[@"notifyType"]];
    if (notifyType.length == 0) {
        notifyType = [self rb_stringValue:raw[@"notify_type"]];
    }
    if (notifyType.length == 0) {
        notifyType = [self rb_stringValue:raw[@"type"]];
    }
    NSString *groupName = [self rb_stringValue:(raw[@"g_name"] ?: raw[@"gname"])];
    if (groupName.length == 0) {
        NSString *gid = [self rb_stringValue:(raw[@"g_id"] ?: raw[@"gid"] ?: raw[@"t"] ?: raw[@"to"])];
        groupName = [self groupNameForGid:gid fallback:@"群聊"];
    }
    NSString *operatorNickname = [self rb_stringValue:(raw[@"operatorNickname"] ?: raw[@"operator_nickname"] ?: raw[@"invite_by_nickname"])];
    NSString *targetNickname = [self rb_stringValue:(raw[@"targetNickname"] ?: raw[@"target_nickname"] ?: raw[@"inviteBeNickName"] ?: raw[@"initveBeNickName"])];
    NSString *applicantNickname = [self rb_stringValue:(raw[@"applicant_nickname"] ?: raw[@"nickname"] ?: raw[@"target_nickname"])];

    if (msgType == 46) {
        if (operatorNickname.length > 0 && targetNickname.length > 0) {
            return [NSString stringWithFormat:@"%@邀请%@加入群聊", operatorNickname, targetNickname];
        }
        NSString *nickname = targetNickname.length > 0 ? targetNickname : [self rb_stringValue:raw[@"initveBeNickName"]];
        return nickname.length > 0 ? [NSString stringWithFormat:@"%@加入了群聊", nickname] : @"有人加入了群聊";
    }
    if (msgType == 47 || msgType == 50) {
        NSString *message = [self rb_stringValue:raw[@"m"]];
        return message.length > 0 ? message : @"群系统通知";
    }
    if (msgType == 51) {
        NSString *notificationContent = [self rb_stringValue:raw[@"notificationContent"]];
        if (notificationContent.length > 0) {
            return notificationContent;
        }
        NSString *newGroupName = [self rb_stringValue:raw[@"nnewGroupName"]];
        return newGroupName.length > 0 ? [NSString stringWithFormat:@"群名称已修改为%@", newGroupName] : @"群名称已修改";
    }
    if (msgType == 52) {
        if (applicantNickname.length > 0 && groupName.length > 0) {
            return [NSString stringWithFormat:@"%@申请加入%@", applicantNickname, groupName];
        }
        return applicantNickname.length > 0 ? [NSString stringWithFormat:@"%@申请加入群聊", applicantNickname] : @"入群申请";
    }
    if (msgType == 53) {
        BOOL approved = [self rb_boolValue:raw[@"approved"] defaultValue:NO];
        NSString *rejectReason = [self rb_stringValue:raw[@"reject_reason"]];
        if (approved) {
            return @"你的入群申请已通过审核";
        }
        return rejectReason.length > 0 ? [NSString stringWithFormat:@"你的入群申请已被拒绝：%@", rejectReason] : @"你的入群申请已被拒绝";
    }
    if (msgType == 55) {
        NSString *nickname = [self rb_stringValue:(raw[@"changed_by_nickname"] ?: raw[@"operator_nickname"])];
        return nickname.length > 0 ? [NSString stringWithFormat:@"%@修改了群头像", nickname] : @"群头像已修改";
    }
    if (msgType == 56) {
        NSString *nickname = [self rb_stringValue:raw[@"operator_nickname"]];
        NSInteger muteMode = [raw[@"mute_mode"] respondsToSelector:@selector(integerValue)] ? [raw[@"mute_mode"] integerValue] : 0;
        if (muteMode == 1) {
            return nickname.length > 0 ? [NSString stringWithFormat:@"%@开启了全员禁言", nickname] : @"已开启全员禁言";
        }
        if (muteMode == 2) {
            return nickname.length > 0 ? [NSString stringWithFormat:@"%@开启了仅群主可发言模式", nickname] : @"已开启仅群主可发言模式";
        }
        return nickname.length > 0 ? [NSString stringWithFormat:@"%@解除了群禁言", nickname] : @"已解除群禁言";
    }
    if (msgType == 57) {
        NSString *nickname = [self rb_stringValue:raw[@"operator_nickname"]];
        NSInteger invitePermission = [raw[@"invite_permission"] respondsToSelector:@selector(integerValue)] ? [raw[@"invite_permission"] integerValue] : 0;
        if (invitePermission == 1) {
            return nickname.length > 0 ? [NSString stringWithFormat:@"%@开启了仅管理员和群主可邀请模式", nickname] : @"邀请权限已改为仅管理员和群主可邀请";
        }
        return nickname.length > 0 ? [NSString stringWithFormat:@"%@开启了所有人可邀请模式", nickname] : @"邀请权限已改为所有人可邀请";
    }
    if (msgType == 58) {
        NSString *nickname = [self rb_stringValue:raw[@"operator_nickname"]];
        NSInteger memberPrivacy = [raw[@"member_privacy"] respondsToSelector:@selector(integerValue)] ? [raw[@"member_privacy"] integerValue] : 0;
        if (memberPrivacy == 1) {
            return nickname.length > 0 ? [NSString stringWithFormat:@"%@开启了成员隐私保护", nickname] : @"已开启成员隐私保护";
        }
        return nickname.length > 0 ? [NSString stringWithFormat:@"%@关闭了成员隐私保护", nickname] : @"已关闭成员隐私保护";
    }
    if (msgType == 59) {
        NSString *operatorNickname = [self rb_stringValue:raw[@"operator_nickname"]];
        NSString *targetNickname = [self rb_stringValue:raw[@"target_nickname"]];
        BOOL isSetAdmin = [self rb_boolValue:(raw[@"is_set_admin"] ?: raw[@"isSetAdmin"]) defaultValue:NO];
        if (operatorNickname.length > 0 && targetNickname.length > 0) {
            return isSetAdmin ? [NSString stringWithFormat:@"%@设置了%@为管理员", operatorNickname, targetNickname]
                              : [NSString stringWithFormat:@"%@取消了%@的管理员身份", operatorNickname, targetNickname];
        }
        return isSetAdmin ? @"管理员已设置" : @"管理员身份已取消";
    }
    if (msgType == 60) {
        NSString *nickname = [self rb_stringValue:raw[@"operator_nickname"]];
        NSInteger joinMode = [raw[@"join_mode"] respondsToSelector:@selector(integerValue)] ? [raw[@"join_mode"] integerValue] : 0;
        if (joinMode == 1) {
            return nickname.length > 0 ? [NSString stringWithFormat:@"%@设置了加群需管理员确认", nickname] : @"入群方式已改为需管理员确认";
        }
        return nickname.length > 0 ? [NSString stringWithFormat:@"%@设置了自由加入模式", nickname] : @"入群方式已改为自由加入";
    }

    if ([notifyType containsString:@"invite"]) {
        if (operatorNickname.length > 0 && targetNickname.length > 0) {
            return [NSString stringWithFormat:@"%@邀请%@加入群聊", operatorNickname, targetNickname];
        }
        if (operatorNickname.length > 0 && applicantNickname.length > 0) {
            return [NSString stringWithFormat:@"%@邀请%@加入群聊", operatorNickname, applicantNickname];
        }
        if (operatorNickname.length > 0) {
            return [NSString stringWithFormat:@"%@邀请成员加入群聊", operatorNickname];
        }
        return @"邀请成员加入群聊";
    }
    if ([notifyType isEqualToString:@"join_request"]) {
        if (applicantNickname.length > 0 && groupName.length > 0) {
            return [NSString stringWithFormat:@"%@申请加入%@", applicantNickname, groupName];
        }
        return applicantNickname.length > 0 ? [NSString stringWithFormat:@"%@申请加入群聊", applicantNickname] : @"入群申请";
    }
    if ([notifyType isEqualToString:@"admin_set"]) {
        if (operatorNickname.length > 0 && targetNickname.length > 0) {
            return [NSString stringWithFormat:@"%@将%@设为管理员", operatorNickname, targetNickname];
        }
        return @"管理员设置通知";
    }
    if ([notifyType isEqualToString:@"admin_remove"]) {
        if (operatorNickname.length > 0 && targetNickname.length > 0) {
            return [NSString stringWithFormat:@"%@取消了%@的管理员身份", operatorNickname, targetNickname];
        }
        return @"管理员移除通知";
    }
    if ([notifyType isEqualToString:@"transfer_owner"]) {
        return @"你已成为群主";
    }
    if ([notifyType isEqualToString:@"dismiss_group"]) {
        return @"该群已解散";
    }

    return @"群通知";
}

- (NSString *)normalizedNotificationContentForDisplay:(NSString *)content raw:(NSDictionary *)raw
{
    NSString *display = [self rb_stringValue:content];
    if (display.length == 0) {
        return @"";
    }

    NSString *currentUid = [self rb_stringValue:[IMClientManager sharedInstance].localUserInfo.user_uid];
    NSString *currentNickname = [BasicTool trim:[self rb_stringValue:[IMClientManager sharedInstance].localUserInfo.nickname]];

    NSMutableOrderedSet<NSString *> *candidates = [NSMutableOrderedSet orderedSet];
    if (currentNickname.length > 0) {
        [candidates addObject:currentNickname];
    }

    [self appendCandidateNameFromRaw:raw uidKey:@"applicant_uid" nameKey:@"applicant_nickname" currentUid:currentUid toSet:candidates];
    [self appendCandidateNameFromRaw:raw uidKey:@"reviewer_uid" nameKey:@"reviewer_nickname" currentUid:currentUid toSet:candidates];
    [self appendCandidateNameFromRaw:raw uidKey:@"operator_uid" nameKey:@"operator_nickname" currentUid:currentUid toSet:candidates];
    [self appendCandidateNameFromRaw:raw uidKey:@"operatorUid" nameKey:@"operatorNickname" currentUid:currentUid toSet:candidates];
    [self appendCandidateNameFromRaw:raw uidKey:@"target_uid" nameKey:@"target_nickname" currentUid:currentUid toSet:candidates];
    [self appendCandidateNameFromRaw:raw uidKey:@"targetUid" nameKey:@"targetNickname" currentUid:currentUid toSet:candidates];

    for (NSString *name in candidates) {
        if (name.length == 0) {
            continue;
        }
        NSString *quotedName = [NSString stringWithFormat:@"\"%@\"", name];
        display = [display stringByReplacingOccurrencesOfString:quotedName withString:@"你"];
        display = [display stringByReplacingOccurrencesOfString:name withString:@"你"];
    }

    display = [display stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    display = [display stringByReplacingOccurrencesOfString:@"“" withString:@""];
    display = [display stringByReplacingOccurrencesOfString:@"”" withString:@""];

    NSString *notifyType = [self rb_stringValue:raw[@"notifyType"]];
    if (notifyType.length == 0) {
        notifyType = [self rb_stringValue:raw[@"notify_type"]];
    }
    if ([notifyType isEqualToString:@"join_request"]) {
        NSString *groupName = [self rb_stringValue:(raw[@"g_name"] ?: raw[@"gname"])];
        if (groupName.length == 0) {
            NSString *gid = [self rb_stringValue:(raw[@"g_id"] ?: raw[@"gid"] ?: raw[@"t"] ?: raw[@"to"])];
            groupName = [self groupNameForGid:gid fallback:@"群聊"];
        }
        NSString *applicantNickname = [self rb_stringValue:(raw[@"applicant_nickname"] ?: raw[@"target_nickname"] ?: raw[@"nickname"])];
        NSString *reviewerNickname = [self rb_stringValue:(raw[@"review_by_nickname"] ?: raw[@"reviewer_nickname"] ?: raw[@"operator_nickname"])];
        NSString *status = [self rb_stringValue:(raw[@"status"] ?: raw[@"approved_status"])];
        if ([status isEqualToString:@"1"]) {
            if (reviewerNickname.length > 0 && applicantNickname.length > 0) {
                return [NSString stringWithFormat:@"%@已通过%@的入群申请", reviewerNickname, applicantNickname];
            }
            if (reviewerNickname.length > 0) {
                return [NSString stringWithFormat:@"%@已通过入群申请", reviewerNickname];
            }
            if (applicantNickname.length > 0) {
                return [NSString stringWithFormat:@"%@的入群申请已通过", applicantNickname];
            }
            return @"入群申请已通过";
        }
        if ([status isEqualToString:@"2"]) {
            if (reviewerNickname.length > 0 && applicantNickname.length > 0) {
                return [NSString stringWithFormat:@"%@已拒绝%@的入群申请", reviewerNickname, applicantNickname];
            }
            if (reviewerNickname.length > 0) {
                return [NSString stringWithFormat:@"%@已拒绝入群申请", reviewerNickname];
            }
            if (applicantNickname.length > 0) {
                return [NSString stringWithFormat:@"%@的入群申请已拒绝", applicantNickname];
            }
            return @"入群申请已拒绝";
        }
        NSString *baseText = @"";
        if (applicantNickname.length > 0 && groupName.length > 0) {
            baseText = [NSString stringWithFormat:@"%@申请加入%@", applicantNickname, groupName];
        } else if (applicantNickname.length > 0) {
            baseText = [NSString stringWithFormat:@"%@申请加入群聊", applicantNickname];
        } else {
            baseText = groupName.length > 0 ? [NSString stringWithFormat:@"申请加入%@", groupName] : @"入群申请";
        }
        return baseText;
    }
    if ([notifyType containsString:@"invite"] || [notifyType isEqualToString:@"join_request"]) {
        display = [display stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        display = [display stringByReplacingOccurrencesOfString:@"“" withString:@""];
        display = [display stringByReplacingOccurrencesOfString:@"”" withString:@""];
        return display;
    }
    if ([notifyType isEqualToString:@"admin_set"] || [notifyType isEqualToString:@"admin_remove"]) {
        if ([display hasPrefix:@"群主"]) {
            display = [display substringFromIndex:2];
        }
    }

    return display;
}

- (void)appendCandidateNameFromRaw:(NSDictionary *)raw
                            uidKey:(NSString *)uidKey
                           nameKey:(NSString *)nameKey
                        currentUid:(NSString *)currentUid
                             toSet:(NSMutableOrderedSet<NSString *> *)set
{
    if (![raw isKindOfClass:[NSDictionary class]] || currentUid.length == 0 || set == nil) {
        return;
    }

    NSString *uid = [self rb_stringValue:raw[uidKey]];
    if (![uid isEqualToString:currentUid]) {
        return;
    }

    NSString *name = [BasicTool trim:[self rb_stringValue:raw[nameKey]]];
    if (name.length > 0) {
        [set addObject:name];
    }
}

- (NSString *)stringTimeFromRawTimeValue:(id)rawTimeValue
{
    if ([rawTimeValue isKindOfClass:[NSString class]]) {
        return [self rb_stringValue:rawTimeValue];
    }
    NSDate *date = [self dateFromRawTimeValue:rawTimeValue];
    if (date != nil) {
        return [self serverTimeStringFromDate:date];
    }
    return @"";
}

- (NSString *)notificationIdentifierFromRaw:(NSDictionary *)raw msgType:(NSInteger)msgType
{
    if (![raw isKindOfClass:[NSDictionary class]]) {
        return @"";
    }

    NSArray *directKeys = @[@"id", @"notification_id", @"notificationId", @"request_id", @"requestId", @"parent_fp", @"parentFp"];
    for (NSString *key in directKeys) {
        NSString *value = [self rb_stringValue:raw[key]];
        if (value.length > 0) {
            return value;
        }
    }

    NSString *gid = [self rb_stringValue:raw[@"gid"]];
    if (gid.length == 0) {
        gid = [self rb_stringValue:raw[@"g_id"]];
    }
    if (gid.length == 0) {
        gid = [self rb_stringValue:raw[@"t"]];
    }
    if (gid.length == 0) {
        gid = [self rb_stringValue:raw[@"to"]];
    }
    NSString *type = [self rb_stringValue:raw[@"notifyType"]];
    if (type.length == 0) {
        type = [self rb_stringValue:raw[@"notify_type"]];
    }
    if (type.length == 0) {
        type = [self rb_stringValue:raw[@"type"]];
    }
    NSString *time = [self rb_stringValue:raw[@"create_time"]];
    if (time.length == 0) {
        time = [self rb_stringValue:raw[@"createTime"]];
    }
    NSString *actor = [self rb_stringValue:raw[@"operatorUid"]];
    if (actor.length == 0) {
        actor = [self rb_stringValue:raw[@"operator_uid"]];
    }
    if (actor.length == 0) {
        actor = [self rb_stringValue:raw[@"applicant_uid"]];
    }
    return [NSString stringWithFormat:@"rt_%ld_%@_%@_%@_%@", (long)msgType, gid ?: @"", type ?: @"", actor ?: @"", time ?: @""];
}

- (NSString *)groupNameForGid:(NSString *)gid fallback:(NSString *)fallback
{
    if (gid.length == 0) {
        return fallback ?: @"群聊";
    }

    GroupEntity *group = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];
    if (group.g_name.length > 0) {
        return group.g_name;
    }
    return fallback ?: gid;
}

- (NSString *)displayTimeForServerTime:(NSString *)serverTime
{
    return [self displayTimeForDate:[self dateFromServerTime:serverTime] fallback:serverTime];
}

- (NSString *)displayTimeForDate:(NSDate *)date fallback:(NSString *)fallback
{
    if (date != nil) {
        return [TimeTool getTimeStringAutoShort2:date mustIncludeTime:NO timeWithSegment:NO];
    }
    return fallback ?: @"";
}

- (NSString *)serverTimeStringFromDate:(NSDate *)date
{
    if (date == nil) {
        return @"";
    }
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone localTimeZone];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    });
    return [formatter stringFromDate:date] ?: @"";
}

- (NSDate *)dateFromRawTimeValue:(id)rawTimeValue
{
    if ([rawTimeValue isKindOfClass:[NSNumber class]]) {
        double ts = [(NSNumber *)rawTimeValue doubleValue];
        if (ts > 1000000000000.0) {
            ts = ts / 1000.0;
        }
        if (ts > 0) {
            return [NSDate dateWithTimeIntervalSince1970:ts];
        }
    }

    if ([rawTimeValue isKindOfClass:[NSString class]]) {
        NSString *timeString = [(NSString *)rawTimeValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (timeString.length == 0) {
            return nil;
        }
        BOOL allDigits = YES;
        for (NSUInteger i = 0; i < timeString.length; i++) {
            unichar ch = [timeString characterAtIndex:i];
            if (ch < '0' || ch > '9') {
                allDigits = NO;
                break;
            }
        }
        if (allDigits) {
            double ts = [timeString doubleValue];
            if (ts > 1000000000000.0) {
                ts = ts / 1000.0;
            }
            if (ts > 0) {
                return [NSDate dateWithTimeIntervalSince1970:ts];
            }
        }
        return [self dateFromServerTime:timeString];
    }

    return nil;
}

- (long long)sortTimestampFromRawTimeValue:(id)rawTimeValue fallbackDate:(NSDate *)fallbackDate
{
    NSDate *date = [self dateFromRawTimeValue:rawTimeValue];
    if (date == nil) {
        date = fallbackDate;
    }
    if (date == nil) {
        return 0;
    }
    return (long long)([date timeIntervalSince1970] * 1000.0);
}

- (NSDate *)dateFromServerTime:(NSString *)serverTime
{
    if (![serverTime isKindOfClass:[NSString class]] || serverTime.length == 0) {
        return nil;
    }
    static NSDateFormatter *formatterSec = nil;
    static NSDateFormatter *formatterMin = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatterSec = [[NSDateFormatter alloc] init];
        formatterSec.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatterSec.timeZone = [NSTimeZone localTimeZone];
        formatterSec.dateFormat = @"yyyy-MM-dd HH:mm:ss";

        formatterMin = [[NSDateFormatter alloc] init];
        formatterMin.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatterMin.timeZone = [NSTimeZone localTimeZone];
        formatterMin.dateFormat = @"yyyy-MM-dd HH:mm";
    });
    NSDate *date = [formatterSec dateFromString:serverTime];
    if (date == nil) {
        date = [formatterMin dateFromString:serverTime];
    }
    return date;
}

- (NSString *)rb_stringValue:(id)value
{
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    return @"";
}

- (BOOL)rb_boolValue:(id)value defaultValue:(BOOL)defaultValue
{
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value boolValue];
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *lower = [(NSString *)value lowercaseString];
        if ([lower isEqualToString:@"true"] || [lower isEqualToString:@"1"]) {
            return YES;
        }
        if ([lower isEqualToString:@"false"] || [lower isEqualToString:@"0"]) {
            return NO;
        }
    }
    return defaultValue;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    return self.items.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    (void)indexPath;
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    RBGroupNotificationCell *cell = [tableView dequeueReusableCellWithIdentifier:kGroupNotificationsCellId forIndexPath:indexPath];
    NSDictionary *item = self.items[indexPath.row];
    [cell configureWithItem:item hideDivider:(indexPath.row == self.items.count - 1)];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < 0 || indexPath.row >= self.items.count) {
        return;
    }

    NSDictionary *item = self.items[indexPath.row];
    NSString *notifyType = RBGroupNotificationNotifyTypeFromItem(item);
    if ([notifyType rangeOfString:@"join"].location != NSNotFound) {
        NSString *statusText = RBGroupNotificationJoinStatusText(item);
        if (![statusText isEqualToString:@"待审核"] && ![statusText isEqualToString:@"待处理"]) {
            return;
        }
        __weak typeof(self) weakSelf = self;
        GroupNotificationJoinRequestDetailViewController *vc = [[GroupNotificationJoinRequestDetailViewController alloc] initWithItem:item reviewCompletion:^(NSDictionary *updatedItem) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf == nil || updatedItem == nil) {
                return;
            }
            NSMutableArray *mutableItems = [strongSelf.items mutableCopy];
            if (indexPath.row >= 0 && indexPath.row < (NSInteger)mutableItems.count) {
                mutableItems[indexPath.row] = updatedItem;
                strongSelf.items = [strongSelf rb_sortedItemsFromItems:mutableItems];
                [strongSelf refreshUI];
            }
        }];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    NSString *gid = [self rb_stringValue:item[@"g_id"]];
    if (gid.length == 0 || self.navigationController == nil) {
        return;
    }

    NSString *gname = [self rb_stringValue:item[@"groupName"]];
    [ViewControllerFactory goGroupChattingViewController:self.navigationController
                                                     gid:gid
                                                   gname:gname
                                                animated:YES
                                          popToRootFirst:NO
                                               highlight:nil];
}

#pragma mark - RBPlainCustomNav

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_registerRealtimeObserverIfNeeded];
    [self rb_plainCustomNavHostViewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_markCurrentItemsAsReadIfNeeded];
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
    [self rb_unregisterRealtimeObserverIfNeeded];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

- (void)dealloc
{
    [self rb_unregisterRealtimeObserverIfNeeded];
}

@end
