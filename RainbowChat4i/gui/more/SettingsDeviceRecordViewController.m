// Copyright (C) 2026 即时通讯网(52im.net) & Jack Jiang.
// The RainbowChat Project. All rights reserved.
// 
// 【本产品为著作权产品，合法授权后请放心使用，禁止外传！】
// 【本次授权给：<MANEKI TECHNOLOGY>，授权编号：<NT260125160939>，代码指纹：<A.769328579.505>，技术对接人微信：<ID: Cqiu88-88>】
// 
// 【本系列产品在国家版权局的著作权登记信息如下】：
// 1）国家版权局登记名(简称)和权证号：RainbowChat    （证书号：软著登字第1220494号、登记号：2016SR041877）
// 2）国家版权局登记名(简称)和权证号：RainbowChat-Web（证书号：软著登字第3743440号、登记号：2019SR0322683）
// 3）国家版权局登记名(简称)和权证号：RainbowAV      （证书号：软著登字第2262004号、登记号：2017SR676720）
// 4）国家版权局登记名(简称)和权证号：MobileIMSDK-Web（证书号：软著登字第2262073号、登记号：2017SR676789）
// 5）国家版权局登记名(简称)和权证号：MobileIMSDK    （证书号：软著登字第1220581号、登记号：2016SR041964）
// 6）国家版权局登记名(简称)和权证号：RainbowTalk    （证书号：软著登字第15415925号、登记号：2025SR0759727）
// * 著作权所有人：苏州网际时代信息科技有限公司
// 
// 【违法或违规使用投诉和举报方式】：
// 联系邮件：jack.jiang@52im.net
// 联系微信：hellojackjiang
// 联系QQ号：413980957
// 授权说明：http://www.52im.net/thread-1115-1-1.html
// 官方社区：http://www.52im.net
#import "SettingsDeviceRecordViewController.h"
#import "BasicTool.h"
#import "Default.h"
#import "AppDelegate.h"
#import "TimeTool.h"
#import "HttpServiceFactory.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "UserEntity.h"
#import "MyProcessorConst.h"
#import "MBProgressHUD.h"
#import "DDLog.h"
#import "UIViewController+RBPlainCustomNav.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>

static const CGFloat kRowHeight = 80.0;
/** 左滑删除露出区域宽度（略大于纯文字「删除」的系统默认宽度） */
static const CGFloat kDeviceRecordDeleteSwipeWidth = 120.0;
static const CGFloat kCellPaddingH = 16.0;

/// 矩形红底 + 居中白字「删除」，用于加宽 `UIContextualAction` 的滑动区域（非圆角图块）
static UIImage *RBDeviceRecordWideDeleteSwipeImage(CGFloat widthPt, CGFloat heightPt)
{
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.opaque = YES;
    fmt.scale = [UIScreen mainScreen].scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(widthPt, heightPt) format:fmt];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        CGRect r = CGRectMake(0, 0, widthPt, heightPt);
        [[UIColor colorWithRed:0.88 green:0.18 blue:0.14 alpha:1.0] setFill];
        UIRectFill(r);
        NSString *t = @"删除";
        UIFont *font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
        NSDictionary *attrs = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: [UIColor whiteColor] };
        CGSize ts = [t sizeWithAttributes:attrs];
        [t drawAtPoint:CGPointMake((widthPt - ts.width) / 2.0, (heightPt - ts.height) / 2.0 - 1.0) withAttributes:attrs];
    }];
}
static const NSInteger kTagContainer = 1000, kTagName = 1001, kTagInfo = 1002, kTagCurrent = 1004, kTagTrusted = 1006, kTagHardwareId = 1007, kTagSeparator = 1005;

@interface DeviceRecord : NSObject
@property (nonatomic, strong) NSString *history_id;
@property (nonatomic, assign) int device_type;
@property (nonatomic, strong) NSString *device_type_name;
@property (nonatomic, strong) NSString *device_token;
@property (nonatomic, strong) NSString *device_info;
@property (nonatomic, strong) NSString *login_ip;
@property (nonatomic, strong) NSString *login_time;
@property (nonatomic, strong) NSString *login_time2;
@property (nonatomic, strong) NSString *logout_time;
@property (nonatomic, strong) NSString *logout_time2;
@property (nonatomic, strong) NSString *http_token;
@property (nonatomic, assign) BOOL is_current;
@property (nonatomic, assign) int status;
/** 稳定设备标识（如 IDFV），服务端返回；最早绑定该 ID 的设备为信任设备 */
@property (nonatomic, strong) NSString *hardware_id;
/** 是否为该 hardware_id 下的信任设备（同 ID 中登录时间最早的一台） */
@property (nonatomic, assign) BOOL is_trusted;
@end

@implementation DeviceRecord
@end

@interface SettingsDeviceRecordViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSMutableArray<DeviceRecord *> *deviceList;
@property (nonatomic, assign) BOOL currentCanManage;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

@end

@implementation SettingsDeviceRecordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = @"";
    self.title = @"设备记录";
    [self rb_installPlainCustomNavigationBarWithTitle:@"设备记录"];
    
    self.deviceList = [NSMutableArray array];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = HexColor(0xF0F0F0);
    self.tableView.tableFooterView = [[UIView alloc] init];
    self.view.backgroundColor = HexColor(0xF0F0F0);
    
    [self setupRefreshControl];
    [self setupEmptyStateView];
    [self loadDeviceRecords];
}

- (void)setupRefreshControl
{
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(onPullRefresh) forControlEvents:UIControlEventValueChanged];
    if (@available(iOS 10.0, *)) {
        self.tableView.refreshControl = self.refreshControl;
    } else {
        [self.tableView addSubview:self.refreshControl];
    }
}

- (void)onPullRefresh
{
    [self loadDeviceRecords];
}

- (void)setupEmptyStateView
{
    self.emptyStateView = [[UIView alloc] init];
    self.emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateView.hidden = YES;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"暂无设备记录";
    titleLabel.font = [BasicTool getSystemFontOfSize:17];
    titleLabel.textColor = HexColor(0x333333);
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.emptyStateView addSubview:titleLabel];
    
    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.text = @"登录过的设备将显示在这里";
    subLabel.font = [BasicTool getSystemFontOfSize:14];
    subLabel.textColor = HexColor(0x999999);
    subLabel.textAlignment = NSTextAlignmentCenter;
    [self.emptyStateView addSubview:subLabel];
    
    [self.tableView addSubview:self.emptyStateView];
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyStateView.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
        [self.emptyStateView.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor constant:-40],
        [self.emptyStateView.leadingAnchor constraintEqualToAnchor:self.tableView.leadingAnchor constant:40],
        [self.emptyStateView.trailingAnchor constraintEqualToAnchor:self.tableView.trailingAnchor constant:-40],
        [titleLabel.topAnchor constraintEqualToAnchor:self.emptyStateView.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor],
        [subLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [subLabel.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor],
        [subLabel.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor],
        [subLabel.bottomAnchor constraintEqualToAnchor:self.emptyStateView.bottomAnchor],
    ]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
    [BasicTool refreshFontsForView:self.view];
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

#pragma mark - 加载设备记录

- (void)loadDeviceRecords
{
    BOOL isPullRefresh = self.refreshControl.isRefreshing;
    if (!isPullRefresh) [self showLoading:@"加载中..."];
    
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    if (!localUser || !localUser.user_uid) {
        if (!isPullRefresh) [self hideLoading];
        [self.refreshControl endRefreshing];
        [BasicTool showAlertInfo:@"用户信息获取失败" parent:self];
        return;
    }
    
    // 调用查询设备历史接口 (1008-1-31)
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:1
                                                  andAction:31
                                                withNewData:@{
                                                        @"uid": localUser.user_uid
                                                    }
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
                                                       BOOL wasPull = self.refreshControl.isRefreshing;
                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                           [self.refreshControl endRefreshing];
                                                           if (!wasPull) [self hideLoading];
                                                           if (sucess) {
                                                               [self parseDeviceRecords:returnValue];
                                                           } else {
                                                               [BasicTool showAlertInfo:@"加载设备记录失败" parent:self];
                                                           }
                                                       });
                                                   }
                                              hudParentView:nil
                                        showLocalErrorAlert:NO
                                      completeForLocalError:nil];
}

- (void)parseDeviceRecords:(NSString *)jsonString
{
    [self.deviceList removeAllObjects];
    
    if (!jsonString || jsonString.length == 0) {
        [self.tableView reloadData];
        return;
    }
    
    // 解析JSON数组
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSArray *deviceArray = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
    
    if (error || ![deviceArray isKindOfClass:[NSArray class]]) {
        DDLogWarn(@"解析设备记录失败: %@", error);
        [BasicTool showAlertInfo:@"解析设备记录失败" parent:self];
        [self.tableView reloadData];
        return;
    }
    
    // 转换为 DeviceRecord，并过滤重复（按 history_id 去重；无 history_id 时按 device_token+login_time 去重）
    NSMutableSet<NSString *> *seenIds = [NSMutableSet set];
    for (NSDictionary *deviceDict in deviceArray) {
        DeviceRecord *device = [[DeviceRecord alloc] init];
        device.history_id = [deviceDict objectForKey:@"history_id"];
        device.device_type = [[deviceDict objectForKey:@"device_type"] intValue];
        device.device_type_name = [deviceDict objectForKey:@"device_type_name"] ?: @"未知";
        device.device_token = [deviceDict objectForKey:@"device_token"];
        device.device_info = [deviceDict objectForKey:@"device_info"] ?: @"未知设备";
        device.login_ip = [deviceDict objectForKey:@"login_ip"];
        device.login_time = [deviceDict objectForKey:@"login_time"];
        device.login_time2 = [deviceDict objectForKey:@"login_time2"];
        device.logout_time = [deviceDict objectForKey:@"logout_time"];
        device.logout_time2 = [deviceDict objectForKey:@"logout_time2"];
        device.http_token = [deviceDict objectForKey:@"http_token"];
        device.is_current = [[deviceDict objectForKey:@"is_current"] boolValue];
        device.status = [[deviceDict objectForKey:@"status"] intValue];
        device.hardware_id = [deviceDict objectForKey:@"hardware_id"];
        
        if (device.status != 1) continue;
        
        NSString *dedupeKey = nil;
        if (device.history_id.length > 0) {
            dedupeKey = device.history_id;
        } else {
            dedupeKey = [NSString stringWithFormat:@"%@|%@", device.device_token ?: @"", device.login_time ?: @""];
        }
        if (dedupeKey.length > 0 && [seenIds containsObject:dedupeKey]) continue;
        if (dedupeKey.length > 0) [seenIds addObject:dedupeKey];
        
        [self.deviceList addObject:device];
    }
    
    [self markTrustedDevices];
    [self updateCurrentCanManage];
    [self.tableView reloadData];
    self.emptyStateView.hidden = (self.deviceList.count > 0);
    if (self.deviceList.count == 0) {
        self.tableView.tableHeaderView = nil;
    }
}

- (void)markTrustedDevices
{
    // 按 hardware_id 分组，同组内按 login_time 升序，最早的一台标记为 is_trusted
    NSMutableDictionary<NSString *, NSMutableArray<DeviceRecord *> *> *byHwid = [NSMutableDictionary dictionary];
    for (DeviceRecord *d in self.deviceList) {
        NSString *hwid = d.hardware_id.length > 0 ? d.hardware_id : nil;
        if (!hwid) continue;
        NSMutableArray *arr = byHwid[hwid];
        if (!arr) {
            arr = [NSMutableArray array];
            byHwid[hwid] = arr;
        }
        [arr addObject:d];
    }
    for (NSString *hwid in byHwid) {
        NSMutableArray *arr = byHwid[hwid];
        [arr sortUsingComparator:^NSComparisonResult(DeviceRecord *a, DeviceRecord *b) {
            NSString *ta = a.login_time.length > 0 ? a.login_time : @"";
            NSString *tb = b.login_time.length > 0 ? b.login_time : @"";
            return [ta compare:tb options:NSNumericSearch];
        }];
        if (arr.count > 0) ((DeviceRecord *)arr.firstObject).is_trusted = YES;
    }
}

- (void)updateCurrentCanManage
{
    self.currentCanManage = NO;
    DeviceRecord *current = nil;
    for (DeviceRecord *d in self.deviceList) {
        if (d.is_current) { current = d; break; }
    }
    if (!current) return;
    if (!current.hardware_id || current.hardware_id.length == 0) {
        // 无 hardware_id 时保持原逻辑：当前设备可删除其他设备
        self.currentCanManage = YES;
        return;
    }
    NSInteger sameHwidCount = 0;
    for (DeviceRecord *d in self.deviceList) {
        if ([d.hardware_id isEqualToString:current.hardware_id]) sameHwidCount++;
    }
    self.currentCanManage = (sameHwidCount == 1) || current.is_trusted;
}

- (void)showLoading:(NSString *)message
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = message;
    hud.mode = MBProgressHUDModeIndeterminate;
}

- (void)hideLoading
{
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.deviceList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"DeviceRecordCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = HexColor(0xF0F0F0);
        cell.contentView.backgroundColor = HexColor(0xF0F0F0);
        
        UIView *containerView = [[UIView alloc] init];
        containerView.translatesAutoresizingMaskIntoConstraints = NO;
        containerView.backgroundColor = [UIColor whiteColor];
        [cell.contentView addSubview:containerView];
        
        UILabel *deviceNameLabel = [[UILabel alloc] init];
        deviceNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        deviceNameLabel.font = [BasicTool getSystemFontOfSize:17];
        deviceNameLabel.textColor = HexColor(0x1A1A1A);
        deviceNameLabel.tag = kTagName;
        [containerView addSubview:deviceNameLabel];
        
        UILabel *deviceInfoLabel = [[UILabel alloc] init];
        deviceInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
        deviceInfoLabel.font = [BasicTool getSystemFontOfSize:13];
        deviceInfoLabel.textColor = HexColor(0x999999);
        deviceInfoLabel.tag = kTagInfo;
        [containerView addSubview:deviceInfoLabel];
        
        UILabel *currentLabel = [[UILabel alloc] init];
        currentLabel.translatesAutoresizingMaskIntoConstraints = NO;
        currentLabel.font = [BasicTool getSystemFontOfSize:11];
        currentLabel.textColor = HexColor(0x2E7D32);
        currentLabel.text = @"当前设备";
        currentLabel.tag = kTagCurrent;
        currentLabel.backgroundColor = HexColor(0xE8F5E9);
        currentLabel.layer.cornerRadius = 4.0;
        currentLabel.clipsToBounds = YES;
        currentLabel.textAlignment = NSTextAlignmentCenter;
        [containerView addSubview:currentLabel];
        
        UILabel *trustedLabel = [[UILabel alloc] init];
        trustedLabel.translatesAutoresizingMaskIntoConstraints = NO;
        trustedLabel.font = [BasicTool getSystemFontOfSize:11];
        trustedLabel.textColor = HexColor(0x3949AB);
        trustedLabel.text = @"信任设备";
        trustedLabel.tag = kTagTrusted;
        trustedLabel.backgroundColor = HexColor(0xE8EAF6);
        trustedLabel.layer.cornerRadius = 4.0;
        trustedLabel.clipsToBounds = YES;
        trustedLabel.textAlignment = NSTextAlignmentCenter;
        [containerView addSubview:trustedLabel];
        
        UILabel *hardwareIdLabel = [[UILabel alloc] init];
        hardwareIdLabel.translatesAutoresizingMaskIntoConstraints = NO;
        hardwareIdLabel.font = [BasicTool getSystemFontOfSize:12];
        hardwareIdLabel.textColor = HexColor(0x808080);
        hardwareIdLabel.tag = kTagHardwareId;
        [containerView addSubview:hardwareIdLabel];
        
        UIView *separator = [[UIView alloc] init];
        separator.translatesAutoresizingMaskIntoConstraints = NO;
        separator.tag = kTagSeparator;
        separator.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
        [containerView addSubview:separator];
        
        [NSLayoutConstraint activateConstraints:@[
            [containerView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
            [containerView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
            [containerView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
            [containerView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
            [deviceNameLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:kCellPaddingH],
            [deviceNameLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:12],
            [deviceNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:currentLabel.leadingAnchor constant:-8],
            [deviceInfoLabel.leadingAnchor constraintEqualToAnchor:deviceNameLabel.leadingAnchor],
            [deviceInfoLabel.topAnchor constraintEqualToAnchor:deviceNameLabel.bottomAnchor constant:4],
            [deviceInfoLabel.trailingAnchor constraintLessThanOrEqualToAnchor:trustedLabel.leadingAnchor constant:-8],
            [hardwareIdLabel.leadingAnchor constraintEqualToAnchor:deviceNameLabel.leadingAnchor],
            [hardwareIdLabel.topAnchor constraintEqualToAnchor:deviceInfoLabel.bottomAnchor constant:2],
            [hardwareIdLabel.trailingAnchor constraintLessThanOrEqualToAnchor:trustedLabel.leadingAnchor constant:-8],
            [currentLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-12],
            [currentLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:12],
            [currentLabel.widthAnchor constraintEqualToConstant:56],
            [currentLabel.heightAnchor constraintEqualToConstant:22],
            [trustedLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-12],
            [trustedLabel.topAnchor constraintEqualToAnchor:currentLabel.bottomAnchor constant:4],
            [trustedLabel.widthAnchor constraintEqualToConstant:56],
            [trustedLabel.heightAnchor constraintEqualToConstant:22],
            [separator.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:kCellPaddingH],
            [separator.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
            [separator.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
            [separator.heightAnchor constraintEqualToConstant:0.5],
        ]];
    }
    
    DeviceRecord *device = self.deviceList[indexPath.row];
    UILabel *deviceNameLabel = [cell.contentView viewWithTag:kTagName];
    UILabel *deviceInfoLabel = [cell.contentView viewWithTag:kTagInfo];
    UILabel *currentLabel = [cell.contentView viewWithTag:kTagCurrent];
    UILabel *trustedLabel = [cell.contentView viewWithTag:kTagTrusted];
    UILabel *hardwareIdLabel = [cell.contentView viewWithTag:kTagHardwareId];
    UIView *separator = [cell.contentView viewWithTag:kTagSeparator];
    
    NSString *deviceName = device.device_info;
    if (!deviceName || deviceName.length == 0) {
        deviceName = device.device_type_name;
    }
    deviceNameLabel.text = deviceName;
    
    NSString *infoText = device.device_type_name;
    if (device.login_ip && device.login_ip.length > 0) {
        infoText = [NSString stringWithFormat:@"%@ • %@", infoText, device.login_ip];
    }
    if (device.login_time && device.login_time.length > 0) {
        NSString *timeStr = [self formatLoginTime:device.login_time];
        infoText = [NSString stringWithFormat:@"%@ • %@", infoText, timeStr];
    }
    deviceInfoLabel.text = infoText;
    
    if (device.hardware_id.length > 0) {
        NSString *showId = device.hardware_id.length > 12
            ? [NSString stringWithFormat:@"…%@", [device.hardware_id substringFromIndex:device.hardware_id.length - 8]]
            : device.hardware_id;
        hardwareIdLabel.text = [NSString stringWithFormat:@"硬件ID: %@", showId];
        hardwareIdLabel.hidden = NO;
    } else {
        hardwareIdLabel.text = nil;
        hardwareIdLabel.hidden = YES;
    }
    
    currentLabel.hidden = !device.is_current;
    trustedLabel.hidden = !device.is_trusted;
    separator.hidden = (indexPath.row == (NSInteger)self.deviceList.count - 1);
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    [BasicTool refreshFontsForView:cell.contentView];
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kRowHeight;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    DeviceRecord *d = self.deviceList[indexPath.row];
    return !d.is_current && self.currentCanManage;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 删除仅通过 trailingSwipeActions 呈现，避免与系统 Delete 样式叠用
    return UITableViewCellEditingStyleNone;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DeviceRecord *d = self.deviceList[indexPath.row];
    if (d.is_current || !self.currentCanManage) {
        return nil;
    }
    __weak typeof(self) weakSelf = self;
    NSIndexPath *pathCopy = [indexPath copy];
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:@""
                                                                             handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        SettingsDeviceRecordViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            completionHandler(NO);
            return;
        }
        if (pathCopy.row < 0 || pathCopy.row >= (NSInteger)strongSelf.deviceList.count) {
            completionHandler(NO);
            return;
        }
        DeviceRecord *device = strongSelf.deviceList[pathCopy.row];
        [strongSelf rb_presentDeleteConfirmForDevice:device indexPath:pathCopy];
        completionHandler(YES);
    }];
    deleteAction.image = RBDeviceRecordWideDeleteSwipeImage(kDeviceRecordDeleteSwipeWidth, kRowHeight);
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    config.performsFirstActionWithFullSwipe = NO;
    return config;
}

- (void)rb_presentDeleteConfirmForDevice:(DeviceRecord *)device indexPath:(NSIndexPath *)indexPath
{
    if (!self.currentCanManage) {
        [BasicTool showAlertInfo:@"仅信任设备可移除其他设备。当前设备不是该硬件ID下的信任设备或唯一设备，无法踢出或删除其他设备。" parent:self];
        return;
    }
    NSString *deviceName = device.device_info;
    if (!deviceName || deviceName.length == 0) {
        deviceName = device.device_type_name;
    }
    NSIndexPath *pathCopy = [indexPath copy];
    [BasicTool areYouSureAlert:@"删除设备"
                        content:[NSString stringWithFormat:@"确定要删除设备\"%@\"吗？删除后该设备将无法继续使用此账号。", deviceName]
                    okBtnTitle:@"删除"
                cancelBtnTitle:@"取消"
                        parent:self
                     okHandler:^(UIAlertAction *_Nullable action) {
                         [self deleteDevice:device atIndexPath:pathCopy];
                     }
                 cancelHandler:^(UIAlertAction *_Nullable action) {
                         [self.tableView reloadRowsAtIndexPaths:@[pathCopy] withRowAnimation:NO];
                     }];
}

- (void)deleteDevice:(DeviceRecord *)device atIndexPath:(NSIndexPath *)indexPath
{
    [self showLoading:@"删除中..."];
    
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    if (!localUser || !localUser.user_uid) {
        [self hideLoading];
        [BasicTool showAlertInfo:@"用户信息获取失败" parent:self];
        return;
    }
    
    // 调用踢出设备接口 (1008-1-32)
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:1
                                                  andAction:32
                                                withNewData:@{
                                                        @"uid": localUser.user_uid,
                                                        @"history_id": device.history_id
                                                    }
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                           [self hideLoading];
                                                           
                                                           if (sucess) {
                                                               if ([returnValue isEqualToString:@"1"]) {
                                                                   [self.deviceList removeObject:device];
                                                                   [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                                                                   self.emptyStateView.hidden = (self.deviceList.count > 0);
                                                                   [APP showToastInfo:@"已移除该设备"];
                                                               } else if ([returnValue isEqualToString:@"2"]) {
                                                                   [BasicTool showAlertInfo:@"设备记录不存在或不属于当前用户" parent:self];
                                                               } else {
                                                                   [BasicTool showAlertInfo:@"删除失败" parent:self];
                                                               }
                                                           } else {
                                                               [BasicTool showAlertInfo:@"删除失败" parent:self];
                                                           }
                                                       });
                                                   }
                                              hudParentView:nil
                                        showLocalErrorAlert:NO
                                      completeForLocalError:nil];
}

- (NSString *)formatLoginTime:(NSString *)timeString
{
    if (!timeString || timeString.length == 0) {
        return @"未知时间";
    }
    
    // 解析时间字符串 "2026-02-03 10:30:00"
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSDate *date = [formatter dateFromString:timeString];
    
    if (!date) {
        return timeString;
    }
    
    // 计算时间差
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:date];
    NSInteger days = (NSInteger)(timeInterval / (24 * 60 * 60));
    NSInteger hours = (NSInteger)(timeInterval / (60 * 60));
    NSInteger minutes = (NSInteger)(timeInterval / 60);
    
    if (days > 0) {
        return [NSString stringWithFormat:@"%ld天前", (long)days];
    } else if (hours > 0) {
        return [NSString stringWithFormat:@"%ld小时前", (long)hours];
    } else if (minutes > 0) {
        return [NSString stringWithFormat:@"%ld分钟前", (long)minutes];
    } else {
        return @"刚刚";
    }
}

@end

