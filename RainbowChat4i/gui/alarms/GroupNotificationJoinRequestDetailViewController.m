#import "GroupNotificationJoinRequestDetailViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "BasicTool.h"
#import "RBAvatarView.h"
#import "Default.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"

@interface GroupNotificationJoinRequestDetailViewController ()

@property (nonatomic, strong) NSMutableDictionary *item;
@property (nonatomic, copy) void (^reviewCompletion)(NSDictionary *updatedItem);
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *profileCardView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nicknameLabel;
@property (nonatomic, strong) UILabel *uidLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *infoCardView;
@property (nonatomic, strong) UILabel *groupValueLabel;
@property (nonatomic, strong) UILabel *signatureValueLabel;
@property (nonatomic, strong) UILabel *sourceValueLabel;
@property (nonatomic, strong) UILabel *timeValueLabel;
@property (nonatomic, strong) UILabel *memoValueLabel;
@property (nonatomic, strong) UIButton *approveButton;
@property (nonatomic, strong) UIButton *rejectButton;
@property (nonatomic, strong) NSLayoutConstraint *buttonBarHeightConstraint;

@end

@implementation GroupNotificationJoinRequestDetailViewController

- (instancetype)initWithItem:(NSDictionary *)item
            reviewCompletion:(void (^)(NSDictionary *updatedItem))reviewCompletion
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.item = [NSMutableDictionary dictionaryWithDictionary:(item ?: @{})];
        self.reviewCompletion = reviewCompletion;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.titleView = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"申请详情"];
    self.view.backgroundColor = HexColor(0xF5F7FA);
    [self setupUI];
    [self refreshUI];
}

- (void)setupUI
{
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = HexColor(0xF5F7FA);
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    [self.scrollView addSubview:self.contentView];

    self.profileCardView = [[UIView alloc] init];
    self.profileCardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.profileCardView.backgroundColor = UIColor.whiteColor;
    [self.contentView addSubview:self.profileCardView];

    self.avatarImageView = [[UIImageView alloc] init];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.layer.cornerRadius = 36.0f;
    self.avatarImageView.layer.masksToBounds = YES;
    self.avatarImageView.backgroundColor = HexColor(0xEAF2FF);
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.image = [UIImage imageNamed:@"default_avatar_60"];
    [self.profileCardView addSubview:self.avatarImageView];

    self.nicknameLabel = [[UILabel alloc] init];
    self.nicknameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nicknameLabel.font = [UIFont boldSystemFontOfSize:22.0f];
    self.nicknameLabel.textColor = HexColor(0x1F2329);
    self.nicknameLabel.numberOfLines = 1;
    [self.profileCardView addSubview:self.nicknameLabel];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.layer.cornerRadius = 11.0f;
    self.statusLabel.layer.masksToBounds = YES;
    [self.profileCardView addSubview:self.statusLabel];

    self.uidLabel = [[UILabel alloc] init];
    self.uidLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.uidLabel.font = [UIFont systemFontOfSize:14.0f];
    self.uidLabel.textColor = HexColor(0x8E8E93);
    self.uidLabel.numberOfLines = 1;
    [self.profileCardView addSubview:self.uidLabel];

    self.infoCardView = [[UIView alloc] init];
    self.infoCardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.infoCardView.backgroundColor = UIColor.whiteColor;
    [self.contentView addSubview:self.infoCardView];

    UIView *groupRow = [self createInfoItemWithTitle:@"群聊" valueLabel:&_groupValueLabel];
    UIView *sep1 = [self createSeparator];
    UIView *signatureRow = [self createInfoItemWithTitle:@"个性签名" valueLabel:&_signatureValueLabel];
    UIView *sep2 = [self createSeparator];
    UIView *sourceRow = [self createInfoItemWithTitle:@"来源" valueLabel:&_sourceValueLabel];
    UIView *sep3 = [self createSeparator];
    UIView *timeRow = [self createInfoItemWithTitle:@"申请时间" valueLabel:&_timeValueLabel];
    UIView *sep4 = [self createSeparator];
    UIView *memoRow = [self createInfoItemWithTitle:@"申请说明" valueLabel:&_memoValueLabel];

    NSArray<UIView *> *infoSubviews = @[groupRow, sep1, signatureRow, sep2, sourceRow, sep3, timeRow, sep4, memoRow];
    UIView *prevView = nil;
    for (UIView *subview in infoSubviews) {
        [self.infoCardView addSubview:subview];
        [NSLayoutConstraint activateConstraints:@[
            [subview.leadingAnchor constraintEqualToAnchor:self.infoCardView.leadingAnchor],
            [subview.trailingAnchor constraintEqualToAnchor:self.infoCardView.trailingAnchor],
        ]];
        if (prevView == nil) {
            [subview.topAnchor constraintEqualToAnchor:self.infoCardView.topAnchor].active = YES;
        } else {
            [subview.topAnchor constraintEqualToAnchor:prevView.bottomAnchor].active = YES;
        }
        prevView = subview;
    }
    [prevView.bottomAnchor constraintEqualToAnchor:self.infoCardView.bottomAnchor].active = YES;

    self.approveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.approveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.approveButton setTitle:@"通过" forState:UIControlStateNormal];
    [self.approveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.approveButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    self.approveButton.backgroundColor = HexColor(0x07C160);
    self.approveButton.layer.cornerRadius = 18.0f;
    [self.approveButton addTarget:self action:@selector(onApproveTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.approveButton];

    self.rejectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.rejectButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.rejectButton setTitle:@"拒绝" forState:UIControlStateNormal];
    [self.rejectButton setTitleColor:HexColor(0x1F2329) forState:UIControlStateNormal];
    self.rejectButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    self.rejectButton.backgroundColor = HexColor(0xE9E9E9);
    self.rejectButton.layer.cornerRadius = 18.0f;
    self.rejectButton.layer.borderWidth = 0.0f;
    [self.rejectButton addTarget:self action:@selector(onRejectTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.rejectButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    self.buttonBarHeightConstraint = [self.approveButton.heightAnchor constraintEqualToConstant:56.0f];
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.approveButton.topAnchor constant:-16.0f],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        [self.profileCardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.profileCardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.profileCardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],

        [self.avatarImageView.topAnchor constraintEqualToAnchor:self.profileCardView.topAnchor constant:22.0f],
        [self.avatarImageView.leadingAnchor constraintEqualToAnchor:self.profileCardView.leadingAnchor constant:20.0f],
        [self.avatarImageView.widthAnchor constraintEqualToConstant:72.0f],
        [self.avatarImageView.heightAnchor constraintEqualToConstant:72.0f],

        [self.nicknameLabel.topAnchor constraintEqualToAnchor:self.profileCardView.topAnchor constant:28.0f],
        [self.nicknameLabel.leadingAnchor constraintEqualToAnchor:self.avatarImageView.trailingAnchor constant:16.0f],
        [self.nicknameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusLabel.leadingAnchor constant:-10.0f],

        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.nicknameLabel.centerYAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.profileCardView.trailingAnchor constant:-16.0f],
        [self.statusLabel.heightAnchor constraintEqualToConstant:22.0f],
        [self.statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:58.0f],

        [self.uidLabel.topAnchor constraintEqualToAnchor:self.nicknameLabel.bottomAnchor constant:10.0f],
        [self.uidLabel.leadingAnchor constraintEqualToAnchor:self.nicknameLabel.leadingAnchor],
        [self.uidLabel.trailingAnchor constraintEqualToAnchor:self.profileCardView.trailingAnchor constant:-16.0f],
        [self.uidLabel.bottomAnchor constraintEqualToAnchor:self.profileCardView.bottomAnchor constant:-24.0f],

        [self.infoCardView.topAnchor constraintEqualToAnchor:self.profileCardView.bottomAnchor constant:12.0f],
        [self.infoCardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.infoCardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.infoCardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12.0f],

        [self.approveButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0f],
        [self.approveButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12.0f],
        self.buttonBarHeightConstraint,

        [self.rejectButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0f],
        [self.rejectButton.leadingAnchor constraintEqualToAnchor:self.approveButton.trailingAnchor constant:12.0f],
        [self.rejectButton.widthAnchor constraintEqualToAnchor:self.approveButton.widthAnchor],
        [self.rejectButton.centerYAnchor constraintEqualToAnchor:self.approveButton.centerYAnchor],
        [self.rejectButton.heightAnchor constraintEqualToAnchor:self.approveButton.heightAnchor],
    ]];
}

- (void)refreshUI
{
    NSDictionary *raw = [self.item[@"raw"] isKindOfClass:[NSDictionary class]] ? self.item[@"raw"] : nil;
    NSString *statusText = [self statusText];
    NSString *applicant = [self applicantNickname];
    NSString *applicantUid = [self applicantUid];
    NSString *groupName = [self stringValue:(self.item[@"groupName"] ?: raw[@"g_name"] ?: raw[@"gname"])];
    NSString *time = [self applicationTimeText];
    NSString *content = [self detailMemoText];

    self.nicknameLabel.text = applicant.length > 0 ? applicant : @"未知用户";
    self.uidLabel.text = applicantUid.length > 0 ? [NSString stringWithFormat:@"UID: %@", applicantUid] : @"UID: 暂无";
    self.statusLabel.text = statusText;
    self.statusLabel.textColor = [statusText isEqualToString:@"已拒绝"] ? HexColor(0xFF4D4F) : ([statusText isEqualToString:@"待审核"] ? HexColor(0xFF9F0A) : HexColor(0x07C160));
    self.statusLabel.backgroundColor = [statusText isEqualToString:@"已拒绝"] ? HexColor(0xFFF1F0) : ([statusText isEqualToString:@"待审核"] ? HexColor(0xFFF7E6) : HexColor(0xE9F9EE));
    self.groupValueLabel.text = groupName.length > 0 ? groupName : @"群聊";
    self.signatureValueLabel.text = [self applicantSignatureText];
    self.sourceValueLabel.text = [self sourceText];
    self.timeValueLabel.text = time.length > 0 ? time : @"";
    self.memoValueLabel.text = content.length > 0 ? content : @"无";
    [self loadApplicantAvatar];

    BOOL canReview = [self canReview];
    self.approveButton.hidden = !canReview;
    self.rejectButton.hidden = !canReview;
    self.buttonBarHeightConstraint.constant = canReview ? 46.0f : 0.0f;
}

- (NSString *)stringValue:(id)value
{
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    return @"";
}

- (BOOL)boolValue:(id)value defaultValue:(BOOL)defaultValue
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

- (NSString *)statusText
{
    NSDictionary *raw = [self.item[@"raw"] isKindOfClass:[NSDictionary class]] ? self.item[@"raw"] : nil;
    NSString *statusDesc = [BasicTool trim:[self stringValue:(self.item[@"status_desc"] ?: raw[@"status_desc"] ?: self.item[@"statusDesc"] ?: raw[@"statusDesc"])]];
    if (statusDesc.length > 0) {
        return statusDesc;
    }
    NSString *status = [self stringValue:(self.item[@"status"] ?: raw[@"status"])];
    if ([status isEqualToString:@"0"]) {
        return @"待审核";
    }
    if ([status isEqualToString:@"1"]) {
        return @"已通过";
    }
    if ([status isEqualToString:@"2"]) {
        return @"已拒绝";
    }
    id approvedValue = self.item[@"approved"] ?: raw[@"approved"];
    if (approvedValue != nil) {
        return [self boolValue:approvedValue defaultValue:NO] ? @"已通过" : @"已拒绝";
    }
    NSString *reviewTime = [self stringValue:(self.item[@"review_time"] ?: raw[@"review_time"])];
    if (reviewTime.length > 0) {
        NSString *rejectReason = [self stringValue:(self.item[@"reject_reason"] ?: raw[@"reject_reason"])];
        NSString *content = [self stringValue:self.item[@"content"]];
        if (rejectReason.length > 0 || [content containsString:@"拒绝"]) {
            return @"已拒绝";
        }
        return @"已通过";
    }
    return @"待审核";
}

- (BOOL)canReview
{
    NSString *statusText = [self statusText];
    if (![statusText isEqualToString:@"待审核"]) {
        return NO;
    }
    NSString *notifyType = [[self stringValue:self.item[@"notify_type"]] lowercaseString];
    if (notifyType.length == 0) {
        NSDictionary *raw = [self.item[@"raw"] isKindOfClass:[NSDictionary class]] ? self.item[@"raw"] : nil;
        notifyType = [[self stringValue:(raw[@"notify_type"] ?: raw[@"notifyType"])] lowercaseString];
    }
    return [notifyType containsString:@"join_request"];
}

- (NSString *)applicantNickname
{
    NSDictionary *raw = [self.item[@"raw"] isKindOfClass:[NSDictionary class]] ? self.item[@"raw"] : nil;
    NSString *nickname = [self stringValue:(raw[@"target_nickname"] ?: self.item[@"target_nickname"])];
    if (nickname.length == 0) {
        nickname = [self stringValue:(raw[@"applicant_nickname"] ?: self.item[@"applicant_nickname"])];
    }
    if (nickname.length == 0) {
        nickname = [self stringValue:(raw[@"nickname"] ?: self.item[@"nickname"])];
    }
    return nickname;
}

- (NSString *)applicantUid
{
    NSDictionary *raw = [self.item[@"raw"] isKindOfClass:[NSDictionary class]] ? self.item[@"raw"] : nil;
    NSString *uid = [self stringValue:(raw[@"target_uid"] ?: self.item[@"target_uid"])];
    if (uid.length == 0) {
        uid = [self stringValue:(raw[@"applicant_uid"] ?: self.item[@"applicant_uid"])];
    }
    if (uid.length == 0) {
        uid = [self stringValue:(raw[@"user_uid"] ?: self.item[@"user_uid"])];
    }
    return uid;
}

- (NSString *)sourceText
{
    NSDictionary *raw = [self.item[@"raw"] isKindOfClass:[NSDictionary class]] ? self.item[@"raw"] : nil;
    NSString *joinMethod = [BasicTool trim:[self stringValue:(raw[@"join_method"] ?: self.item[@"join_method"])]];
    NSString *inviterNickname = [BasicTool trim:[self stringValue:(raw[@"inviter_nickname"] ?: raw[@"invite_by_nickname"] ?: self.item[@"inviter_nickname"] ?: self.item[@"invite_by_nickname"])]];
    id requestTypeValue = raw[@"request_type"] ?: self.item[@"request_type"];
    NSInteger requestType = [requestTypeValue respondsToSelector:@selector(integerValue)] ? [requestTypeValue integerValue] : 0;

    if (requestType == 1) {
        if (inviterNickname.length > 0) {
            return [NSString stringWithFormat:@"成员%@的邀请", inviterNickname];
        }
        return joinMethod.length > 0 ? joinMethod : @"邀请入群";
    }
    if (requestType == 2) {
        return joinMethod.length > 0 ? joinMethod : @"扫码添加";
    }
    if (requestType == 3) {
        return joinMethod.length > 0 ? joinMethod : @"群查找";
    }
    if (joinMethod.length > 0) {
        return joinMethod;
    }
    return @"无";
}

- (NSString *)applicationTimeText
{
    NSDictionary *raw = [self.item[@"raw"] isKindOfClass:[NSDictionary class]] ? self.item[@"raw"] : nil;
    NSString *time = [BasicTool trim:[self stringValue:(raw[@"create_time"] ?: self.item[@"create_time"] ?: raw[@"createTime"] ?: self.item[@"createTime"] ?: self.item[@"time"])]];
    return time.length > 0 ? time : @"无";
}

- (NSString *)applicantSignatureText
{
    NSDictionary *raw = [self.item[@"raw"] isKindOfClass:[NSDictionary class]] ? self.item[@"raw"] : nil;
    NSString *sig = [BasicTool trim:[self stringValue:(raw[@"whatsUp"] ?: raw[@"whats_up"] ?: raw[@"userDesc"] ?: raw[@"user_desc"] ?: raw[@"signature"] ?: self.item[@"whatsUp"] ?: self.item[@"whats_up"] ?: self.item[@"userDesc"] ?: self.item[@"user_desc"] ?: self.item[@"signature"])]];
    return sig.length > 0 ? sig : @"此人超懒，什么都没留下";
}

- (NSString *)detailMemoText
{
    NSDictionary *raw = [self.item[@"raw"] isKindOfClass:[NSDictionary class]] ? self.item[@"raw"] : nil;
    NSString *requestDesc = [BasicTool trim:[self stringValue:(raw[@"request_desc"]
                                                              ?: raw[@"apply_desc"]
                                                              ?: raw[@"apply_reason"]
                                                              ?: raw[@"join_reason"]
                                                              ?: raw[@"memo"]
                                                              ?: raw[@"remark"]
                                                              ?: self.item[@"request_desc"]
                                                              ?: self.item[@"apply_desc"]
                                                              ?: self.item[@"apply_reason"]
                                                              ?: self.item[@"join_reason"]
                                                              ?: self.item[@"memo"]
                                                              ?: self.item[@"remark"])]];
    if (requestDesc.length > 0) {
        return requestDesc;
    }
    NSString *rejectReason = [BasicTool trim:[self stringValue:(raw[@"reject_reason"] ?: self.item[@"reject_reason"])]];
    if (rejectReason.length > 0) {
        return rejectReason;
    }
    NSString *content = [BasicTool trim:[self stringValue:(raw[@"content"]
                                                           ?: raw[@"notification_content"]
                                                           ?: raw[@"notificationContent"]
                                                           ?: self.item[@"content"])]];
    if (content.length > 0) {
        return content;
    }
    return @"";
}

- (void)loadApplicantAvatar
{
    NSDictionary *raw = [self.item[@"raw"] isKindOfClass:[NSDictionary class]] ? self.item[@"raw"] : nil;
    NSString *avatarFile = [self stringValue:(raw[@"avatar"] ?: raw[@"userAvatarFileName"] ?: self.item[@"avatar"] ?: self.item[@"userAvatarFileName"])];
    NSString *uid = [self applicantUid];
    UIImage *placeholder = [UIImage imageNamed:@"default_avatar_60"];
    [RBAvatarView setAvatarWithFileName:avatarFile uid:uid onImageView:self.avatarImageView placeholder:placeholder staticPreviewOnly:YES];
}

- (UIView *)createInfoItemWithTitle:(NSString *)title valueLabel:(UILabel * __strong *)valueLabel
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = UIColor.whiteColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:16.0f];
    titleLabel.textColor = HexColor(0x1F2329);
    titleLabel.text = title;
    [row addSubview:titleLabel];

    UILabel *detailLabel = [[UILabel alloc] init];
    detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    detailLabel.font = [UIFont systemFontOfSize:15.0f];
    detailLabel.textColor = HexColor(0x8E8E93);
    detailLabel.numberOfLines = 0;
    detailLabel.textAlignment = NSTextAlignmentRight;
    [row addSubview:detailLabel];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:56.0f],
        [titleLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16.0f],
        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:16.0f],
        [titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor constant:-16.0f],

        [detailLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:titleLabel.trailingAnchor constant:12.0f],
        [detailLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16.0f],
        [detailLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:16.0f],
        [detailLabel.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-16.0f],
    ]];

    if (valueLabel != NULL) {
        *valueLabel = detailLabel;
    }
    return row;
}

- (UIView *)createSeparator
{
    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = HexColor(0xEEEEEE);
    [separator.heightAnchor constraintEqualToConstant:(1.0f / MAX(UIScreen.mainScreen.scale, 1.0f))].active = YES;
    return separator;
}

- (void)onApproveTapped
{
    [self reviewWithDecision:1];
}

- (void)onRejectTapped
{
    [self reviewWithDecision:2];
}

- (void)reviewWithDecision:(int)decision
{
    NSDictionary *raw = [self.item[@"raw"] isKindOfClass:[NSDictionary class]] ? self.item[@"raw"] : nil;
    NSString *gid = [self stringValue:(self.item[@"g_id"] ?: raw[@"g_id"] ?: raw[@"gid"])];
    NSString *applicantUid = [self applicantUid];
    NSString *requestId = [self stringValue:(raw[@"request_id"] ?: self.item[@"request_id"] ?: raw[@"requestId"] ?: self.item[@"requestId"] ?: raw[@"id"] ?: self.item[@"id"])];
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (gid.length == 0 || applicantUid.length == 0 || myUid.length == 0) {
        [BasicTool showAlertInfo:@"缺少必要参数，无法处理该申请" parent:self];
        return;
    }
    __weak typeof(self) weakSelf = self;
    NSString *actionName = (decision == 1) ? @"通过" : @"拒绝";
    [self resolvePendingRequestIdForGid:gid applicantUid:applicantUid oprUid:myUid fallbackRequestId:requestId complete:^(NSString *resolvedRequestId) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            if (resolvedRequestId.length == 0) {
                [BasicTool showAlertInfo:@"未找到待审核申请，请先刷新后重试" parent:strongSelf];
                return;
            }
            [[HttpRestHelper sharedInstance] submitReviewJoinRequestToServer:myUid
                                                                         gid:gid
                                                                   requestId:resolvedRequestId
                                                                    decision:decision
                                                                    complete:^(BOOL sucess, NSString *resultCode) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) innerStrongSelf = weakSelf;
                    if (innerStrongSelf == nil) {
                        return;
                    }
                    if (sucess && [@"1" isEqualToString:resultCode]) {
                        innerStrongSelf.item[@"approved"] = @(decision == 1);
                        innerStrongSelf.item[@"status"] = [NSString stringWithFormat:@"%d", decision];
                        innerStrongSelf.item[@"status_desc"] = (decision == 1 ? @"已通过" : @"已拒绝");
                        innerStrongSelf.item[@"request_id"] = resolvedRequestId;
                        NSMutableDictionary *rawMutable = [NSMutableDictionary dictionaryWithDictionary:raw ?: @{}];
                        rawMutable[@"approved"] = @(decision == 1);
                        rawMutable[@"status"] = [NSString stringWithFormat:@"%d", decision];
                        rawMutable[@"status_desc"] = (decision == 1 ? @"已通过" : @"已拒绝");
                        rawMutable[@"request_id"] = resolvedRequestId;
                        NSString *myUidText = [innerStrongSelf stringValue:myUid];
                        NSString *myNickname = [BasicTool trim:[innerStrongSelf stringValue:[IMClientManager sharedInstance].localUserInfo.nickname]];
                        if (myUidText.length > 0) {
                            innerStrongSelf.item[@"review_by_uid"] = myUidText;
                            rawMutable[@"review_by_uid"] = myUidText;
                        }
                        if (myNickname.length > 0) {
                            innerStrongSelf.item[@"review_by_nickname"] = myNickname;
                            rawMutable[@"review_by_nickname"] = myNickname;
                        }
                        NSString *reviewTime = [innerStrongSelf stringValue:rawMutable[@"review_time"]];
                        if (reviewTime.length == 0) {
                            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                            formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
                            reviewTime = [formatter stringFromDate:[NSDate date]];
                            rawMutable[@"review_time"] = reviewTime;
                        }
                        if (reviewTime.length > 0) {
                            innerStrongSelf.item[@"review_time"] = reviewTime;
                        }
                        innerStrongSelf.item[@"raw"] = rawMutable;
                        [innerStrongSelf refreshUI];
                        if (innerStrongSelf.reviewCompletion != nil) {
                            innerStrongSelf.reviewCompletion([innerStrongSelf.item copy]);
                        }
                        [innerStrongSelf.navigationController popViewControllerAnimated:YES];
                    } else if ([@"-2" isEqualToString:resultCode]) {
                        [BasicTool showAlertInfo:@"权限不足" parent:innerStrongSelf];
                    } else {
                        [BasicTool showAlertInfo:[NSString stringWithFormat:@"%@失败，请稍后重试", actionName] parent:innerStrongSelf];
                    }
                });
            } hudParentView:strongSelf.view];
        });
    }];
}

- (void)resolvePendingRequestIdForGid:(NSString *)gid
                         applicantUid:(NSString *)applicantUid
                               oprUid:(NSString *)oprUid
                    fallbackRequestId:(NSString *)fallbackRequestId
                             complete:(void (^)(NSString *resolvedRequestId))complete
{
    if (gid.length == 0 || applicantUid.length == 0 || oprUid.length == 0) {
        if (complete != nil) {
            complete(@"");
        }
        return;
    }
    [[HttpRestHelper sharedInstance] submitQueryJoinRequestsFromServer:gid oprUid:oprUid complete:^(BOOL sucess, NSArray<NSDictionary *> *requestList) {
        NSString *resolved = @"";
        if (sucess && [requestList isKindOfClass:[NSArray class]]) {
            for (NSDictionary *req in requestList) {
                if (![req isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSString *uid = [self stringValue:req[@"user_uid"]];
                NSString *status = [self stringValue:req[@"status"]];
                if (![uid isEqualToString:applicantUid]) {
                    continue;
                }
                if (status.length > 0 && ![status isEqualToString:@"0"]) {
                    continue;
                }
                resolved = [self stringValue:req[@"id"]];
                if (resolved.length > 0) {
                    break;
                }
            }
        }
        if (resolved.length == 0) {
            NSString *fallback = [self stringValue:fallbackRequestId];
            if (fallback.length > 0 && ![fallback hasPrefix:@"-"]) {
                resolved = fallback;
            }
        }
        if (complete != nil) {
            complete(resolved);
        }
    } hudParentView:nil];
}

#pragma mark - RBPlainCustomNav

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
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

@end
