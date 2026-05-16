#import "GroupManageViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "BasicTool.h"
#import "ViewControllerFactory.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "LPActionSheet.h"
#import "GroupSettingsViewController.h"
#import "GroupJoinRequestsViewController.h"
#import "GroupMutedMembersViewController.h"
#import "GroupMemberViewController.h"
#import "RBImagePickerWrapper.h"
#import "FileUploadHelper.h"
#import "FileDownloadHelper.h"
#import "FileTool.h"
#import "NotificationCenterFactory.h"
#import "AppDelegate.h"
#import "Default.h"
#import "MBProgressHUD.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

// Switch tag
#define TAG_SWITCH_JOIN_MODE    100

#pragma mark - GroupManageViewController

@interface GroupManageViewController () <UITableViewDelegate, UITableViewDataSource, RBImagePickerCompleteDelegate>

@property (nonatomic, strong) GroupEntity *groupInfo;
@property (nonatomic, assign) int myRole;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) RBImagePickerWrapper *imagePickerWrapper;

// 设置项当前值
@property (nonatomic, assign) int joinMode;

@end

@implementation GroupManageViewController

- (instancetype)initWithGroupInfo:(GroupEntity *)groupInfo myRole:(int)myRole
{
    self = [super init];
    if (self) {
        _groupInfo = groupInfo;
        _myRole = myRole;
        _joinMode = groupInfo.g_join_mode;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.titleView = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"群管理"];
    self.view.backgroundColor = HexColor(0xEDEDED);
    
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    
    // 图片选择器（用于群头像设置）
    self.imagePickerWrapper = [[RBImagePickerWrapper alloc] initWithParent:self delegate:self crop:YES];
    
    [self buildUI];
    [self loadSettingsFromServer];
}

- (void)loadSettingsFromServer
{
    __weak typeof(self) weakSelf = self;
    [[HttpRestHelper sharedInstance] submitQueryGroupSettingsFromServer:self.groupInfo.g_id complete:^(BOOL sucess, NSDictionary *settings) {
        if (sucess && settings != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.joinMode = [[settings objectForKey:@"g_join_mode"] intValue];
                [weakSelf.tableView reloadData];
            });
        }
    } hudParentView:self.view];
}

#pragma mark - UI

- (void)buildUI
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
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

/*
 * ╔══════════════════════════════════════════════════╗
 * ║ Section 0: 开关设置                               ║
 * ║   - 进群需要群主/群管理员确认        [UISwitch]     ║
 * ╠══════════════════════════════════════════════════╣
 * ║ Section 1: 功能入口（导航项）                       ║
 * ║   - 设置群头像                           >        ║
 * ║   - 全群禁言                             >        ║
 * ║   - 禁言成员列表                          >        ║
 * ║   - 入群审核列表                          >        ║
 * ║   - 群设置                               >        ║
 * ╠══════════════════════════════════════════════════╣
 * ║ Section 2: 群主专属（仅群主可见）                    ║
 * ║   - 群主管理权转让                        >        ║
 * ║   - 设置管理员                            >        ║
 * ║   - 取消管理员                            >        ║
 * ╚══════════════════════════════════════════════════╝
 */

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.myRole >= 2) {
        return 3; // 开关 + 功能 + 群主专属
    }
    return 2; // 开关 + 功能
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0: return 1; // 进群需要确认
        case 1: return 5; // 设置群头像、全群禁言、禁言成员列表、入群审核列表、群设置
        case 2: return 3; // 群主管理权转让、设置管理员、取消管理员
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        // ── 开关类型 Cell ──
        NSString *cellId = @"SwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        
        UISwitch *sw = [[UISwitch alloc] init];
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        
        cell.textLabel.text = @"进群需要群主/群管理员确认";
        sw.tag = TAG_SWITCH_JOIN_MODE;
        sw.on = (self.joinMode == 1);
        cell.accessoryView = sw;
        
        return cell;
        
    } else if (indexPath.section == 1) {
        // ── 导航类型 Cell ──
        NSString *cellId = @"NavCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        switch (indexPath.row) {
            case 0: cell.textLabel.text = @"设置群头像";   break;
            case 1: cell.textLabel.text = @"全群禁言";     break;
            case 2: cell.textLabel.text = @"禁言成员列表"; break;
            case 3: cell.textLabel.text = @"入群审核列表"; break;
            case 4: cell.textLabel.text = @"群设置";       break;
            default: break;
        }
        
        return cell;
        
    } else {
        // ── Section 2: 群主专属导航 ──
        NSString *cellId = @"OwnerCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        switch (indexPath.row) {
            case 0: cell.textLabel.text = @"群主管理权转让"; break;
            case 1: cell.textLabel.text = @"设置管理员";     break;
            case 2: cell.textLabel.text = @"取消管理员";     break;
            default: break;
        }
        
        return cell;
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        return; // 开关行不响应点击
    }
    
    if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0: [self actionSetGroupAvatar]; break;
            case 1: [self actionMuteMode];       break;
            case 2: [self actionMutedMembers];   break;
            case 3: [self actionJoinRequests];    break;
            case 4: [self actionGroupSettings];   break;
            default: break;
        }
    } else if (indexPath.section == 2) {
        switch (indexPath.row) {
            case 0: [self actionTransferGroup]; break;
            case 1: [self actionSetAdmin];      break;
            case 2: [self actionCancelAdmin];   break;
            default: break;
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 52;
}

/// 缩小分组之间的默认大留白（系统 Grouped 默认 header/footer 较高）
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return section == 0 ? CGFLOAT_MIN : 3.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 3.0;
}

#pragma mark - Switch Events

- (void)switchChanged:(UISwitch *)sender
{
    if (sender.tag != TAG_SWITCH_JOIN_MODE) return;
    
    __weak typeof(self) weakSelf = self;
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    int newValue = sender.on ? 1 : 0;
    NSDictionary *settings = @{@"g_join_mode": [NSString stringWithFormat:@"%d", newValue]};
    
    [[HttpRestHelper sharedInstance] submitModifyGroupSettingsToServer:myUid gid:self.groupInfo.g_id settings:settings complete:^(BOOL sucess, NSString *resultCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && [@"1" isEqualToString:resultCode]) {
                weakSelf.joinMode = newValue;
                weakSelf.groupInfo.g_join_mode = newValue;
                [APP showUserDefineToast_OK:@"设置已保存" atHide:nil];
            } else {
                sender.on = !sender.on;
                [BasicTool showAlertInfo:([@"-2" isEqualToString:resultCode] ? @"权限不足" : @"设置失败，请稍后重试") parent:weakSelf];
            }
        });
    } hudParentView:self.view];
}

#pragma mark - Action: 设置群头像

- (void)actionSetGroupAvatar
{
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

#pragma mark - RBImagePickerCompleteDelegate（群头像上传）

- (void)processImagePickerComplete:(UIImage *)photo withTag:(NSString *)tag
{
    if (photo == nil) {
        [BasicTool showAlertError:@"图片选择失败!" parent:self];
        return;
    }
    
    NSString *gid = self.groupInfo.g_id;
    if (gid == nil) {
        [BasicTool showAlertError:@"群信息异常，请退出后重试!" parent:self];
        return;
    }
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = @"图片处理中..";
    
    __weak typeof(self) weakSelf = self;
    
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
                [BasicTool showAlertError:@"图片压缩失败，请重试!" parent:weakSelf];
            });
            return;
        }
        
        NSString *md5ForFile = [FileTool getFileMD5WithPath:filePathAfterCompress];
        if (md5ForFile == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [hud hideAnimated:YES];
                [BasicTool showAlertError:@"图片处理失败，请重试!" parent:weakSelf];
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
                        weakSelf.groupInfo.g_custom_avatar = groupAvatarFileName;
                        [FileDownloadHelper clearGroupAvatarCache:gid];
                        [NotificationCenterFactory resetGroupAvatarCache_POST:gid];
                        [APP showUserDefineToast_OK:@"群头像设置成功" atHide:nil];
                        if ([weakSelf.delegate respondsToSelector:@selector(groupManageDidRequestSetAvatar)]) {
                            [weakSelf.delegate groupManageDidRequestSetAvatar];
                        }
                    } else if ([@"-2" isEqualToString:resultCode]) {
                        [BasicTool showAlertInfo:@"权限不足，仅管理员或群主可操作" parent:weakSelf];
                    } else {
                        [BasicTool showAlertInfo:@"群头像设置失败，请稍后重试" parent:weakSelf];
                    }
                });
            } hudParentView:nil];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [hud hideAnimated:YES];
                [BasicTool showAlertError:@"群头像上传失败，请检查网络后重试!" parent:weakSelf];
            });
        }];
    });
}

#pragma mark - Action: 全群禁言（3种模式选择）

- (void)actionMuteMode
{
    __weak typeof(self) weakSelf = self;
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    NSArray<NSString *> *titles = @[@"正常（不禁言）", @"仅管理员和群主可发言", @"仅群主可发言"];
    UIImage *checkImage = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        checkImage = [UIImage systemImageNamed:@"checkmark" withConfiguration:config];
    }
    NSMutableArray *rightImages = [NSMutableArray arrayWithCapacity:titles.count];
    for (NSInteger i = 0; i < titles.count; i++) {
        [rightImages addObject:((NSInteger)self.groupInfo.g_mute_mode == i && checkImage != nil) ? (id)checkImage : (id)[NSNull null]];
    }
    
    [LPActionSheet showActionSheetWithTitle:@"设置全群禁言模式"
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:titles
                   otherButtonRightImages:rightImages
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index > 0) {
            int muteMode = (int)(index - 1);
            [[HttpRestHelper sharedInstance] submitSetGroupMuteModeToServer:myUid gid:weakSelf.groupInfo.g_id muteMode:muteMode complete:^(BOOL sucess, NSString *resultCode) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (sucess && [@"1" isEqualToString:resultCode]) {
                        weakSelf.groupInfo.g_mute_mode = muteMode;
                        [APP showUserDefineToast_OK:@"禁言模式设置成功" atHide:nil];
                    } else if ([@"-2" isEqualToString:resultCode]) {
                        [BasicTool showAlertInfo:@"权限不足" parent:weakSelf];
                    } else {
                        [BasicTool showAlertInfo:@"设置失败，请稍后重试" parent:weakSelf];
                    }
                });
            } hudParentView:weakSelf.view];
        }
    }];
}

#pragma mark - Action: 禁言成员列表

- (void)actionMutedMembers
{
    GroupMutedMembersViewController *vc = [[GroupMutedMembersViewController alloc] initWithGid:self.groupInfo.g_id myRole:self.myRole];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Action: 入群审核列表

- (void)actionJoinRequests
{
    GroupJoinRequestsViewController *vc = [[GroupJoinRequestsViewController alloc] initWithGid:self.groupInfo.g_id myRole:self.myRole];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Action: 群设置

- (void)actionGroupSettings
{
    GroupSettingsViewController *vc = [[GroupSettingsViewController alloc] initWithGroupInfo:self.groupInfo myRole:self.myRole];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Action: 群主管理权转让

- (void)actionTransferGroup
{
    [ViewControllerFactory goGroupMemberViewController:self.navigationController usedFor:USED_FOR_TRANSFER gid:self.groupInfo.g_id isGroupOwner:YES defaultSelectedUid:nil];
}

#pragma mark - Action: 设置管理员

- (void)actionSetAdmin
{
    [ViewControllerFactory goGroupMemberViewController:self.navigationController usedFor:USED_FOR_SET_ADMIN gid:self.groupInfo.g_id isGroupOwner:YES defaultSelectedUid:nil];
}

#pragma mark - Action: 取消管理员

- (void)actionCancelAdmin
{
    [ViewControllerFactory goGroupMemberViewController:self.navigationController usedFor:USED_FOR_CANCEL_ADMIN gid:self.groupInfo.g_id isGroupOwner:YES defaultSelectedUid:nil];
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
