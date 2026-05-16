//
//  BlacklistViewController.m
//  RainbowChat4i
//
//  通讯录黑名单页面实现（微信风格，对接服务端接口）。
//

#import "BlacklistViewController.h"
#import "BasicTool.h"
#import "IMClientManager.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "HttpRestHelper.h"
#import "LPActionSheet.h"
#import "AppDelegate.h"
#import "Default.h"
#import "MBProgressHUD.h"
#import "DDLog.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static NSString *const kBlacklistLocalCacheKey = @"__contact_blacklist_cache__";

#pragma mark - BlacklistManager 实现

@implementation BlacklistManager

+ (instancetype)sharedInstance
{
    static BlacklistManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BlacklistManager alloc] init];
    });
    return instance;
}

- (void)addUserToBlacklist:(NSString *)uid nickname:(NSString *)nickname avatarFileName:(NSString *)avatarFileName
{
    if (!uid || uid.length == 0) return;
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!localUid) return;
    
    // 调用服务端接口拉黑
    [[HttpRestHelper sharedInstance] submitBlockUserToServer:localUid
                                                 blockedUid:uid
                                                   complete:^(BOOL sucess, NSString *resultCode) {
        if (sucess && [resultCode isEqualToString:@"1"]) {
            DDLogInfo(@"【黑名单】拉黑用户 %@ 成功", uid);
            // 同步更新本地缓存
            [self updateLocalCache_addUid:uid nickname:nickname avatarFileName:avatarFileName];
        } else {
            DDLogError(@"【黑名单】拉黑用户 %@ 失败: %@", uid, resultCode);
        }
    } hudParentView:nil];
    
    // 先乐观更新本地缓存（避免UI延迟）
    [self updateLocalCache_addUid:uid nickname:nickname avatarFileName:avatarFileName];
}

- (void)removeUserFromBlacklist:(NSString *)uid
{
    [self removeUserFromBlacklist:uid complete:nil hudParentView:nil];
}

- (void)removeUserFromBlacklist:(NSString *)uid complete:(void (^)(BOOL success))complete hudParentView:(UIView *)view
{
    if (!uid || uid.length == 0) {
        if (complete) complete(NO);
        return;
    }
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!localUid) {
        if (complete) complete(NO);
        return;
    }
    
    // 调用服务端接口取消拉黑
    [[HttpRestHelper sharedInstance] submitUnblockUserToServer:localUid
                                                   blockedUid:uid
                                                     complete:^(BOOL sucess, NSString *resultCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && [resultCode isEqualToString:@"1"]) {
                DDLogInfo(@"【黑名单】取消拉黑用户 %@ 成功", uid);
                [self updateLocalCache_removeUid:uid];
                if (complete) complete(YES);
            } else {
                DDLogError(@"【黑名单】取消拉黑用户 %@ 失败: %@", uid, resultCode);
                if (complete) complete(NO);
            }
        });
    } hudParentView:view];
}

- (NSArray<NSDictionary *> *)getBlacklist
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    return [ud objectForKey:kBlacklistLocalCacheKey] ?: @[];
}

- (BOOL)isUserInBlacklist:(NSString *)uid
{
    if (!uid || uid.length == 0) return NO;
    NSArray *list = [self getBlacklist];
    for (NSDictionary *item in list) {
        if ([item[@"user_uid"] isEqualToString:uid]) {
            return YES;
        }
    }
    return NO;
}

- (void)refreshBlacklistFromServer:(void (^)(BOOL success, NSArray<NSDictionary *> *list))complete hudParentView:(UIView *)view
{
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!localUid) {
        if (complete) complete(NO, nil);
        return;
    }
    
    [[HttpRestHelper sharedInstance] submitGetBlacklistFromServer:localUid
                                                        complete:^(BOOL sucess, NSArray<NSDictionary *> *blacklist) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && blacklist) {
                // 更新本地缓存
                NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                [ud setObject:blacklist forKey:kBlacklistLocalCacheKey];
                [ud synchronize];
                if (complete) complete(YES, blacklist);
            } else {
                if (complete) complete(NO, nil);
            }
        });
    } hudParentView:view];
}

#pragma mark - 本地缓存辅助方法

- (void)updateLocalCache_addUid:(NSString *)uid nickname:(NSString *)nickname avatarFileName:(NSString *)avatarFileName
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSMutableArray *list = [([ud objectForKey:kBlacklistLocalCacheKey] ?: @[]) mutableCopy];
    
    // 去重
    NSMutableArray *filtered = [NSMutableArray array];
    for (NSDictionary *item in list) {
        if (![item[@"user_uid"] isEqualToString:uid]) {
            [filtered addObject:item];
        }
    }
    
    // 添加新的
    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    entry[@"user_uid"] = uid;
    entry[@"nickname"] = nickname ?: @"未知用户";
    if (avatarFileName) {
        entry[@"avatar"] = avatarFileName;
    }
    
    // 格式化当前时间为 block_time
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm";
    entry[@"block_time"] = [fmt stringFromDate:[NSDate date]];
    
    [filtered insertObject:entry atIndex:0];
    
    [ud setObject:filtered forKey:kBlacklistLocalCacheKey];
    [ud synchronize];
}

- (void)updateLocalCache_removeUid:(NSString *)uid
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSMutableArray *list = [([ud objectForKey:kBlacklistLocalCacheKey] ?: @[]) mutableCopy];
    
    NSMutableArray *filtered = [NSMutableArray array];
    for (NSDictionary *item in list) {
        if (![item[@"user_uid"] isEqualToString:uid]) {
            [filtered addObject:item];
        }
    }
    
    [ud setObject:filtered forKey:kBlacklistLocalCacheKey];
    [ud synchronize];
}

@end

#pragma mark - BlacklistCell

@interface BlacklistCell : UITableViewCell

@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nicknameLabel;
@property (nonatomic, strong) UILabel *uidLabel;

@end

@implementation BlacklistCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor whiteColor];
        
        // 头像
        self.avatarView = [[UIImageView alloc] init];
        self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        self.avatarView.layer.cornerRadius = 6;
        self.avatarView.clipsToBounds = YES;
        self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
        self.avatarView.image = [UIImage imageNamed:@"default_avatar_70"];
        [self.contentView addSubview:self.avatarView];
        
        // 昵称
        self.nicknameLabel = [[UILabel alloc] init];
        self.nicknameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.nicknameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
        self.nicknameLabel.textColor = [UIColor blackColor];
        [self.contentView addSubview:self.nicknameLabel];
        
        // UID（灰色小字）
        self.uidLabel = [[UILabel alloc] init];
        self.uidLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.uidLabel.font = [UIFont systemFontOfSize:12];
        self.uidLabel.textColor = [UIColor grayColor];
        [self.contentView addSubview:self.uidLabel];
        
        CGFloat avatarSize = 44;
        [NSLayoutConstraint activateConstraints:@[
            [self.avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [self.avatarView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.avatarView.widthAnchor constraintEqualToConstant:avatarSize],
            [self.avatarView.heightAnchor constraintEqualToConstant:avatarSize],
            
            [self.nicknameLabel.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:12],
            [self.nicknameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [self.nicknameLabel.bottomAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-1],
            
            [self.uidLabel.leadingAnchor constraintEqualToAnchor:self.nicknameLabel.leadingAnchor],
            [self.uidLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [self.uidLabel.topAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:3],
        ]];
    }
    return self;
}

@end

#pragma mark - BlacklistViewController

@interface BlacklistViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *dataList;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, assign) BOOL isLoading;

@end

@implementation BlacklistViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"通讯录黑名单";
    self.view.backgroundColor = HexColor(0xF0F0F0);
    
    [self setupUI];
    
    // 先显示本地缓存
    [self loadLocalData];
    
    // 从服务端刷新
    [self refreshFromServer];
}

- (void)setupUI
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = HexColor(0xF0F0F0);
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 72, 0, 0);
    self.tableView.rowHeight = 64;
    [self.tableView registerClass:[BlacklistCell class] forCellReuseIdentifier:@"BlacklistCell"];
    [self.view addSubview:self.tableView];
    
    // 下拉刷新
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(pullToRefresh:) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refreshControl;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    
    // 空状态提示
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.text = @"黑名单为空";
    self.emptyLabel.textColor = [UIColor grayColor];
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
    ]];
}

- (void)loadLocalData
{
    self.dataList = [[[BlacklistManager sharedInstance] getBlacklist] mutableCopy];
    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)refreshFromServer
{
    if (self.isLoading) return;
    self.isLoading = YES;
    
    __weak typeof(self) weakSelf = self;
    [[BlacklistManager sharedInstance] refreshBlacklistFromServer:^(BOOL success, NSArray<NSDictionary *> *list) {
        weakSelf.isLoading = NO;
        [weakSelf.tableView.refreshControl endRefreshing];
        
        if (success && list) {
            weakSelf.dataList = [list mutableCopy];
            [weakSelf.tableView reloadData];
        }
        [weakSelf updateEmptyState];
    } hudParentView:self.view];
}

- (void)pullToRefresh:(UIRefreshControl *)sender
{
    [self refreshFromServer];
}

- (void)updateEmptyState
{
    self.emptyLabel.hidden = (self.dataList.count > 0);
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.dataList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BlacklistCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlacklistCell" forIndexPath:indexPath];
    
    NSDictionary *item = self.dataList[indexPath.row];
    NSString *uid = item[@"user_uid"];
    NSString *nickname = item[@"nickname"];
    NSString *avatarFileName = item[@"avatar"];
    
    cell.nicknameLabel.text = nickname ?: @"未知用户";
    cell.uidLabel.text = [NSString stringWithFormat:@"ID: %@", uid ?: @""];
    // 支持视频头像播放
    [RBAvatarView setAvatarWithFileName:avatarFileName uid:uid onImageView:cell.avatarView placeholder:[UIImage imageNamed:@"default_avatar_70"]];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *item = self.dataList[indexPath.row];
    NSString *uid = item[@"user_uid"];
    NSString *nickname = item[@"nickname"];
    
    __weak typeof(self) weakSelf = self;
    
    LPActionSheetBlock handler = ^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == -1) {
            [weakSelf doUnblockUser:uid nickname:nickname];
        }
    };
    
    [LPActionSheet showActionSheetWithTitle:[NSString stringWithFormat:@"将\"%@\"从黑名单中移除？\n移除后，对方可以重新给你发送消息和加好友请求。", nickname]
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:@"解除拉黑"
                          otherButtonTitles:nil
                                    handler:handler];
}

- (void)doUnblockUser:(NSString *)uid nickname:(NSString *)nickname
{
    __weak typeof(self) weakSelf = self;
    
    [[BlacklistManager sharedInstance] removeUserFromBlacklist:uid complete:^(BOOL success) {
        if (success) {
            [weakSelf loadLocalData];
            [APP showUserDefineToast_OK:[NSString stringWithFormat:@"已将\"%@\"移出黑名单", nickname]];
        } else {
            [BasicTool showAlertError:@"解除拉黑失败，请稍后重试" parent:weakSelf];
        }
    } hudParentView:weakSelf.view];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __weak typeof(self) weakSelf = self;
    NSDictionary *item = self.dataList[indexPath.row];
    NSString *uid = item[@"user_uid"];
    NSString *nickname = item[@"nickname"];
    
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:@"解除拉黑"
                                                                             handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf doUnblockUser:uid nickname:nickname];
        completionHandler(YES);
    }];
    
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (self.dataList.count > 0) {
        return [NSString stringWithFormat:@"共 %lu 人", (unsigned long)self.dataList.count];
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 10;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return [[UIView alloc] init];
}

@end
