#import "GroupJoinRequestsViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "BasicTool.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "AppDelegate.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "LPActionSheet.h"

@interface GroupJoinRequestsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, copy) NSString *gid;
@property (nonatomic, assign) int myRole;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *requestList;

@end

@implementation GroupJoinRequestsViewController

- (instancetype)initWithGid:(NSString *)gid myRole:(int)myRole
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.gid = gid;
        self.myRole = myRole;
        self.requestList = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.titleView = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"入群审核列表"];
    self.view.backgroundColor = HexColor(0xF5F7FA);

    [self setupUI];
    [self loadData];
}

- (void)setupUI
{
    // 表格
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = HexColor(0xF5F7FA);
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.separatorColor = HexColor(0xEEEEEE);
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

    // 空数据提示
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 200, self.view.bounds.size.width, 40)];
    self.emptyLabel.text = @"暂无待审核的入群申请";
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = HexColor(0x999999);
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
}

- (void)loadData
{
    __weak typeof(self) safeSelf = self;
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;

    [[HttpRestHelper sharedInstance] submitQueryJoinRequestsFromServer:self.gid oprUid:myUid complete:^(BOOL sucess, NSArray<NSDictionary *> *requestList) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && requestList != nil) {
                [safeSelf.requestList removeAllObjects];
                [safeSelf.requestList addObjectsFromArray:requestList];
            }
            [safeSelf refreshUI];
        });
    } hudParentView:self.view];
}

- (void)refreshUI
{
    [self.tableView reloadData];
    self.emptyLabel.hidden = (self.requestList.count > 0);
    self.tableView.hidden = (self.requestList.count == 0);
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.requestList.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellId = @"JoinRequestCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        // 头像
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(16, 14, 52, 52)];
        avatar.tag = 300;
        avatar.layer.cornerRadius = 26;
        avatar.layer.masksToBounds = YES;
        avatar.contentMode = UIViewContentModeScaleAspectFill;
        avatar.image = [UIImage imageNamed:@"default_avatar"];
        [cell.contentView addSubview:avatar];

        // 昵称
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 14, 180, 22)];
        nameLabel.tag = 301;
        nameLabel.font = [UIFont boldSystemFontOfSize:15];
        nameLabel.textColor = [UIColor blackColor];
        [cell.contentView addSubview:nameLabel];

        // 说明
        UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 38, 180, 18)];
        descLabel.tag = 302;
        descLabel.font = [UIFont systemFontOfSize:13];
        descLabel.textColor = HexColor(0x999999);
        [cell.contentView addSubview:descLabel];

        // 时间
        UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 58, 180, 16)];
        timeLabel.tag = 303;
        timeLabel.font = [UIFont systemFontOfSize:11];
        timeLabel.textColor = HexColor(0xBBBBBB);
        [cell.contentView addSubview:timeLabel];

        // 通过按钮
        UIButton *approveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        approveBtn.frame = CGRectMake(self.view.bounds.size.width - 130, 20, 50, 36);
        approveBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        approveBtn.tag = 304;
        [approveBtn setTitle:@"通过" forState:UIControlStateNormal];
        [approveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        approveBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        approveBtn.backgroundColor = HexColor(0x07C160);
        approveBtn.layer.cornerRadius = 6;
        [approveBtn addTarget:self action:@selector(approveClicked:) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:approveBtn];

        // 拒绝按钮
        UIButton *rejectBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        rejectBtn.frame = CGRectMake(self.view.bounds.size.width - 70, 20, 50, 36);
        rejectBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        rejectBtn.tag = 305;
        [rejectBtn setTitle:@"拒绝" forState:UIControlStateNormal];
        [rejectBtn setTitleColor:HexColor(0xFF4444) forState:UIControlStateNormal];
        rejectBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        rejectBtn.backgroundColor = HexColor(0xF5F5F5);
        rejectBtn.layer.cornerRadius = 6;
        [rejectBtn addTarget:self action:@selector(rejectClicked:) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:rejectBtn];
    }

    NSDictionary *req = self.requestList[indexPath.row];

    UIImageView *avatar = [cell.contentView viewWithTag:300];
    UILabel *nameLabel = [cell.contentView viewWithTag:301];
    UILabel *descLabel = [cell.contentView viewWithTag:302];
    UILabel *timeLabel = [cell.contentView viewWithTag:303];
    UIButton *approveBtn = [cell.contentView viewWithTag:304];
    UIButton *rejectBtn = [cell.contentView viewWithTag:305];

    nameLabel.text = [req objectForKey:@"nickname"] ?: @"未知用户";

    // 显示申请来源
    NSString *inviteNick = [req objectForKey:@"invite_nickname"];
    NSString *requestDesc = [req objectForKey:@"request_desc"];
    if (inviteNick != nil && ![inviteNick isKindOfClass:[NSNull class]] && inviteNick.length > 0) {
        descLabel.text = [NSString stringWithFormat:@"由 %@ 邀请加入", inviteNick];
    } else if (requestDesc != nil && ![requestDesc isKindOfClass:[NSNull class]] && requestDesc.length > 0) {
        descLabel.text = requestDesc;
    } else {
        descLabel.text = @"申请加入群聊";
    }

    timeLabel.text = [req objectForKey:@"create_time"] ?: @"";

    // 加载头像（支持视频头像播放）
    NSString *avatarFile = [req objectForKey:@"avatar"];
    NSString *userUid = [req objectForKey:@"user_uid"];
    [RBAvatarView setAvatarWithFileName:avatarFile uid:userUid onImageView:avatar placeholder:nil];

    // 审核按钮状态
    int status = [[req objectForKey:@"status"] intValue];
    BOOL canReview = (self.myRole >= 1 && status == 0);
    approveBtn.hidden = !canReview;
    rejectBtn.hidden = !canReview;

    // 存储 row index
    approveBtn.accessibilityHint = [NSString stringWithFormat:@"%ld", (long)indexPath.row];
    rejectBtn.accessibilityHint = [NSString stringWithFormat:@"%ld", (long)indexPath.row];

    return cell;
}

#pragma mark - Actions

- (void)approveClicked:(UIButton *)sender
{
    NSInteger row = [sender.accessibilityHint integerValue];
    [self reviewRequest:row decision:1];
}

- (void)rejectClicked:(UIButton *)sender
{
    NSInteger row = [sender.accessibilityHint integerValue];
    [self reviewRequest:row decision:2];
}

- (void)reviewRequest:(NSInteger)row decision:(int)decision
{
    if (row < 0 || row >= (NSInteger)self.requestList.count) return;

    NSDictionary *req = self.requestList[row];
    NSString *requestId = [NSString stringWithFormat:@"%@", [req objectForKey:@"id"]];
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;

    __weak typeof(self) safeSelf = self;
    NSString *actionName = (decision == 1) ? @"通过" : @"拒绝";

    [[HttpRestHelper sharedInstance] submitReviewJoinRequestToServer:myUid gid:self.gid requestId:requestId decision:decision complete:^(BOOL sucess, NSString *resultCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && [@"1" isEqualToString:resultCode]) {
                [APP showUserDefineToast_OK:[NSString stringWithFormat:@"已%@", actionName] atHide:nil];
                // 移除已处理的申请
                if (row < (NSInteger)safeSelf.requestList.count) {
                    [safeSelf.requestList removeObjectAtIndex:row];
                    [safeSelf refreshUI];
                }
            } else if ([@"-2" isEqualToString:resultCode]) {
                [BasicTool showAlertInfo:@"权限不足" parent:safeSelf];
            } else {
                [BasicTool showAlertInfo:[NSString stringWithFormat:@"%@失败，请稍后重试", actionName] parent:safeSelf];
            }
        });
    } hudParentView:self.view];
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
