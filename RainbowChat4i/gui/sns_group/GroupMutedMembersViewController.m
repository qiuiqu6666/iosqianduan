#import "GroupMutedMembersViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "BasicTool.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "AppDelegate.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "LPActionSheet.h"

@interface GroupMutedMembersViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, copy) NSString *gid;
@property (nonatomic, assign) int myRole;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *mutedList;

@end

@implementation GroupMutedMembersViewController

- (instancetype)initWithGid:(NSString *)gid myRole:(int)myRole
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.gid = gid;
        self.myRole = myRole;
        self.mutedList = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.titleView = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"禁言成员列表"];
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
    self.emptyLabel.text = @"暂无被禁言的成员";
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = HexColor(0x999999);
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
}

- (void)loadData
{
    __weak typeof(self) safeSelf = self;

    [[HttpRestHelper sharedInstance] submitQueryMutedMembersFromServer:self.gid complete:^(BOOL sucess, NSArray<NSDictionary *> *mutedList) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && mutedList != nil) {
                [safeSelf.mutedList removeAllObjects];
                [safeSelf.mutedList addObjectsFromArray:mutedList];
            }
            [safeSelf refreshUI];
        });
    } hudParentView:self.view];
}

- (void)refreshUI
{
    [self.tableView reloadData];
    self.emptyLabel.hidden = (self.mutedList.count > 0);
    self.tableView.hidden = (self.mutedList.count == 0);
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.mutedList.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 72;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellId = @"MutedMemberCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        // 头像
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(16, 10, 52, 52)];
        avatar.tag = 400;
        avatar.layer.cornerRadius = 26;
        avatar.layer.masksToBounds = YES;
        avatar.contentMode = UIViewContentModeScaleAspectFill;
        avatar.image = [UIImage imageNamed:@"default_avatar"];
        [cell.contentView addSubview:avatar];

        // 昵称
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 12, 160, 22)];
        nameLabel.tag = 401;
        nameLabel.font = [UIFont boldSystemFontOfSize:15];
        nameLabel.textColor = [UIColor blackColor];
        [cell.contentView addSubview:nameLabel];

        // 禁言剩余时间
        UILabel *muteInfo = [[UILabel alloc] initWithFrame:CGRectMake(80, 36, 200, 18)];
        muteInfo.tag = 402;
        muteInfo.font = [UIFont systemFontOfSize:13];
        muteInfo.textColor = HexColor(0xFF6600);
        [cell.contentView addSubview:muteInfo];

        // 操作者
        UILabel *oprLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 54, 200, 14)];
        oprLabel.tag = 403;
        oprLabel.font = [UIFont systemFontOfSize:11];
        oprLabel.textColor = HexColor(0xBBBBBB);
        [cell.contentView addSubview:oprLabel];

        // 解除禁言按钮
        UIButton *unmuteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        unmuteBtn.frame = CGRectMake(self.view.bounds.size.width - 90, 20, 70, 32);
        unmuteBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        unmuteBtn.tag = 404;
        [unmuteBtn setTitle:@"解除禁言" forState:UIControlStateNormal];
        [unmuteBtn setTitleColor:HexColor(0x07C160) forState:UIControlStateNormal];
        unmuteBtn.titleLabel.font = [UIFont systemFontOfSize:13];
        unmuteBtn.backgroundColor = HexColor(0xF0FFF0);
        unmuteBtn.layer.cornerRadius = 6;
        unmuteBtn.layer.borderColor = HexColor(0x07C160).CGColor;
        unmuteBtn.layer.borderWidth = 0.5;
        [unmuteBtn addTarget:self action:@selector(unmuteClicked:) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:unmuteBtn];
    }

    NSDictionary *muted = self.mutedList[indexPath.row];

    UIImageView *avatar = [cell.contentView viewWithTag:400];
    UILabel *nameLabel = [cell.contentView viewWithTag:401];
    UILabel *muteInfo = [cell.contentView viewWithTag:402];
    UILabel *oprLabel = [cell.contentView viewWithTag:403];
    UIButton *unmuteBtn = [cell.contentView viewWithTag:404];

    nameLabel.text = [muted objectForKey:@"nickname"] ?: @"未知用户";

    // 禁言状态文字
    NSString *muteUntil2Str = [NSString stringWithFormat:@"%@", [muted objectForKey:@"mute_until2"]];
    long long muteUntil2 = [muteUntil2Str longLongValue];
    if (muteUntil2 == 0) {
        muteInfo.text = @"永久禁言";
    } else {
        long long remaining = muteUntil2 - (long long)([[NSDate date] timeIntervalSince1970] * 1000);
        if (remaining <= 0) {
            muteInfo.text = @"禁言已过期";
            muteInfo.textColor = HexColor(0x999999);
        } else {
            long long hours = remaining / (60 * 60 * 1000);
            long long minutes = (remaining % (60 * 60 * 1000)) / (60 * 1000);
            if (hours > 0) {
                muteInfo.text = [NSString stringWithFormat:@"剩余 %lld小时%lld分钟", hours, minutes];
            } else {
                muteInfo.text = [NSString stringWithFormat:@"剩余 %lld分钟", minutes];
            }
            muteInfo.textColor = HexColor(0xFF6600);
        }
    }

    NSString *muteByNick = [muted objectForKey:@"mute_by_nickname"];
    if (muteByNick && ![muteByNick isKindOfClass:[NSNull class]]) {
        oprLabel.text = [NSString stringWithFormat:@"操作者: %@", muteByNick];
    } else {
        oprLabel.text = @"";
    }

    // 加载头像（支持视频头像播放）
    NSString *avatarFile = [muted objectForKey:@"avatar"];
    NSString *userUid = [muted objectForKey:@"user_uid"];
    [RBAvatarView setAvatarWithFileName:avatarFile uid:userUid onImageView:avatar placeholder:nil];

    // 解除禁言按钮可见性
    unmuteBtn.hidden = (self.myRole < 1);
    unmuteBtn.accessibilityHint = [NSString stringWithFormat:@"%ld", (long)indexPath.row];

    return cell;
}

#pragma mark - Actions

- (void)unmuteClicked:(UIButton *)sender
{
    NSInteger row = [sender.accessibilityHint integerValue];
    if (row < 0 || row >= (NSInteger)self.mutedList.count) return;

    NSDictionary *muted = self.mutedList[row];
    NSString *targetUid = [muted objectForKey:@"user_uid"];
    NSString *nickname = [muted objectForKey:@"nickname"] ?: @"该用户";
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;

    __weak typeof(self) safeSelf = self;

    NSString *msg = [NSString stringWithFormat:@"确定解除 %@ 的禁言?", nickname];
    [LPActionSheet showActionSheetWithTitle:msg
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:@"解除禁言"
                          otherButtonTitles:nil
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == -1) {
            [[HttpRestHelper sharedInstance] submitUnmuteGroupMemberToServer:myUid targetUid:targetUid gid:safeSelf.gid complete:^(BOOL sucess, NSString *resultCode) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (sucess && [@"1" isEqualToString:resultCode]) {
                        [APP showUserDefineToast_OK:@"已解除禁言" atHide:nil];
                        if (row < (NSInteger)safeSelf.mutedList.count) {
                            [safeSelf.mutedList removeObjectAtIndex:row];
                            [safeSelf refreshUI];
                        }
                    } else if ([@"-2" isEqualToString:resultCode]) {
                        [BasicTool showAlertInfo:@"权限不足" parent:safeSelf];
                    } else {
                        [BasicTool showAlertInfo:@"操作失败，请稍后重试" parent:safeSelf];
                    }
                });
            } hudParentView:safeSelf.view];
        }
    }];
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
