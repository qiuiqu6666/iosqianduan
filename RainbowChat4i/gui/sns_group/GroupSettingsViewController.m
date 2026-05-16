#import "GroupSettingsViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "BasicTool.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "AppDelegate.h"
#import "GroupInfoViewController.h"

@interface GroupSettingsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) GroupEntity *groupInfo;
@property (nonatomic, assign) int myRole;
@property (nonatomic, strong) UITableView *tableView;

// 当前设置值（可变，用于开关切换）
@property (nonatomic, assign) int joinMode;
@property (nonatomic, assign) int invitePermission;
@property (nonatomic, assign) int newMemberHistory;
@property (nonatomic, assign) int memberPrivacy;

@end

@implementation GroupSettingsViewController

- (instancetype)initWithGroupInfo:(GroupEntity *)groupInfo myRole:(int)myRole
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.groupInfo = groupInfo;
        self.myRole = myRole;

        // 初始化设置值
        self.joinMode = groupInfo.g_join_mode;
        self.invitePermission = groupInfo.g_invite_permission;
        self.newMemberHistory = groupInfo.g_new_member_history;
        self.memberPrivacy = groupInfo.g_member_privacy;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.titleView = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"群设置"];
    // 与「群管理」页一致的浅灰底
    self.view.backgroundColor = HexColor(0xEDEDED);

    [self setupTableView];
    [self loadSettingsFromServer];
}

- (void)setupTableView
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = HexColor(0xEDEDED);
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
}

- (void)loadSettingsFromServer
{
    __weak typeof(self) safeSelf = self;
    [[HttpRestHelper sharedInstance] submitQueryGroupSettingsFromServer:self.groupInfo.g_id complete:^(BOOL sucess, NSDictionary *settings) {
        if (sucess && settings != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                safeSelf.joinMode = [[settings objectForKey:@"g_join_mode"] intValue];
                safeSelf.invitePermission = [[settings objectForKey:@"g_invite_permission"] intValue];
                safeSelf.newMemberHistory = [[settings objectForKey:@"g_new_member_history"] intValue];
                safeSelf.memberPrivacy = [[settings objectForKey:@"g_member_privacy"] intValue];
                [safeSelf.tableView reloadData];
            });
        }
    } hudParentView:self.view];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 3;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 34.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *wrap = [[UIView alloc] init];
    wrap.backgroundColor = [UIColor clearColor];
    UILabel *lab = [[UILabel alloc] init];
    lab.translatesAutoresizingMaskIntoConstraints = NO;
    lab.text = @"群管理设置";
    lab.font = [UIFont systemFontOfSize:13];
    lab.textColor = [UIColor colorWithWhite:0.45 alpha:1];
    [wrap addSubview:lab];
    [NSLayoutConstraint activateConstraints:@[
        [lab.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:20],
        [lab.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-20],
        [lab.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-6],
    ]];
    return wrap;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 44.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView *wrap = [[UIView alloc] init];
    wrap.backgroundColor = [UIColor clearColor];
    UILabel *lab = [[UILabel alloc] init];
    lab.translatesAutoresizingMaskIntoConstraints = NO;
    lab.text = @"以上设置仅管理员和群主可修改。";
    lab.font = [UIFont systemFontOfSize:13];
    lab.textColor = [UIColor colorWithWhite:0.45 alpha:1];
    lab.numberOfLines = 2;
    [wrap addSubview:lab];
    [NSLayoutConstraint activateConstraints:@[
        [lab.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:20],
        [lab.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-20],
        [lab.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:6],
    ]];
    return wrap;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 52.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellId = @"GroupSettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    }
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.textLabel.textColor = [UIColor blackColor];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1];

    // 移除旧的 accessoryView
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    switch (indexPath.row) {
        case 0: {
            cell.textLabel.text = @"邀请权限";
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = (self.invitePermission == 1);
            sw.tag = 101;
            [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.detailTextLabel.text = (self.invitePermission == 1) ? @"仅管理员/群主" : @"所有人";
            break;
        }
        case 1: {
            cell.textLabel.text = @"新成员查看历史";
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = (self.newMemberHistory == 1);
            sw.tag = 102;
            [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.detailTextLabel.text = (self.newMemberHistory == 1) ? @"可查看" : @"不可查看";
            break;
        }
        case 2: {
            cell.textLabel.text = @"成员隐私保护";
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = (self.memberPrivacy == 1);
            sw.tag = 103;
            [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.detailTextLabel.text = (self.memberPrivacy == 1) ? @"仅管理员可见" : @"所有人可见";
            break;
        }
        default:
            break;
    }

    return cell;
}

#pragma mark - Switch Events

- (void)switchChanged:(UISwitch *)sender
{
    __weak typeof(self) safeSelf = self;
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;

    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    NSString *settingKey = nil;
    int newValue = sender.on ? 1 : 0;

    switch (sender.tag) {
        case 100:
            settingKey = @"g_join_mode";
            self.joinMode = newValue;
            break;
        case 101:
            settingKey = @"g_invite_permission";
            self.invitePermission = newValue;
            break;
        case 102:
            settingKey = @"g_new_member_history";
            self.newMemberHistory = newValue;
            break;
        case 103:
            settingKey = @"g_member_privacy";
            self.memberPrivacy = newValue;
            break;
        default:
            return;
    }

    [settings setObject:[NSString stringWithFormat:@"%d", newValue] forKey:settingKey];

    [[HttpRestHelper sharedInstance] submitModifyGroupSettingsToServer:myUid gid:self.groupInfo.g_id settings:settings complete:^(BOOL sucess, NSString *resultCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && [@"1" isEqualToString:resultCode]) {
                // 更新本地 GroupEntity 的对应字段
                if ([settingKey isEqualToString:@"g_join_mode"]) {
                    safeSelf.groupInfo.g_join_mode = newValue;
                } else if ([settingKey isEqualToString:@"g_invite_permission"]) {
                    safeSelf.groupInfo.g_invite_permission = newValue;
                } else if ([settingKey isEqualToString:@"g_new_member_history"]) {
                    safeSelf.groupInfo.g_new_member_history = newValue;
                } else if ([settingKey isEqualToString:@"g_member_privacy"]) {
                    safeSelf.groupInfo.g_member_privacy = newValue;
                }
                [safeSelf.tableView reloadData];
                [APP showUserDefineToast_OK:@"设置已保存" atHide:nil];
            } else if ([@"-2" isEqualToString:resultCode]) {
                // 恢复开关状态
                sender.on = !sender.on;
                [BasicTool showAlertInfo:@"权限不足" parent:safeSelf];
            } else {
                sender.on = !sender.on;
                [BasicTool showAlertInfo:@"设置失败，请稍后重试" parent:safeSelf];
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
