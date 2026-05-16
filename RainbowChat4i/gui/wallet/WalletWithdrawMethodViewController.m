#import "WalletWithdrawMethodViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "WalletBindWithdrawMethodViewController.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

@interface WalletWithdrawMethodViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *methods;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) UIView *emptyStateView;
@end

@implementation WalletWithdrawMethodViewController

static NSString *RCMSafeString(id value) {
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : @"";
}

static NSInteger RCMSafeInteger(id value) {
    if ([value isKindOfClass:[NSNumber class]]) return [(NSNumber *)value integerValue];
    if ([value isKindOfClass:[NSString class]]) return [(NSString *)value integerValue];
    return 0;
}

static BOOL RCMSafeBool(id value) {
    if ([value isKindOfClass:[NSNumber class]]) return [(NSNumber *)value boolValue];
    if ([value isKindOfClass:[NSString class]]) return [(NSString *)value boolValue];
    return NO;
}

static NSString *RCMTypeName(NSInteger type) {
    if (type == 1) return @"支付宝";
    if (type == 2) return @"微信";
    if (type == 3) return @"银行卡";
    return @"未知";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = HexColor(0xF6F7FB);
    self.navigationItem.title = @"提款方式管理(新版)";
    self.methods = @[];
    self.isLoading = NO;

    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                   target:self
                                                   action:@selector(onAdd)];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = HexColor(0xF6F7FB);
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.tableFooterView = [UIView new];
    [self.view addSubview:self.tableView];

    self.emptyStateView = [[UIView alloc] init];
    self.emptyStateView.hidden = YES;
    [self.view addSubview:self.emptyStateView];

    UILabel *emptyLabel = [[UILabel alloc] init];
    emptyLabel.tag = 9001;
    emptyLabel.text = @"暂无提款方式";
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.textColor = HexColor(0x6B7280);
    emptyLabel.font = [UIFont systemFontOfSize:15];
    [self.emptyStateView addSubview:emptyLabel];

    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addBtn.tag = 9002;
    [addBtn setTitle:@"添加提款方式" forState:UIControlStateNormal];
    [addBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    addBtn.backgroundColor = HexColor(0x1674FF);
    addBtn.layer.cornerRadius = 8;
    [addBtn addTarget:self action:@selector(onAdd) forControlEvents:UIControlEventTouchUpInside];
    [self.emptyStateView addSubview:addBtn];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.tableView.frame = self.view.bounds;
    self.emptyStateView.frame = self.view.bounds;

    UILabel *emptyLabel = (UILabel *)[self.emptyStateView viewWithTag:9001];
    UIButton *addBtn = (UIButton *)[self.emptyStateView viewWithTag:9002];
    CGFloat w = self.view.bounds.size.width;
    emptyLabel.frame = CGRectMake(20, 220, w - 40, 24);
    addBtn.frame = CGRectMake((w - 160) * 0.5, 260, 160, 40);
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self reloadMethodsSafely];
}

- (void)reloadMethodsSafely
{
    if (self.isLoading || !self.view.window) return;
    self.isLoading = YES;

    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletGetWithdrawMethodsWithComplete:^(BOOL sucess, NSArray *methods) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!wself) return;
            wself.isLoading = NO;
            wself.methods = [methods isKindOfClass:[NSArray class]] ? methods : @[];
            [wself.tableView reloadData];
            BOOL hasData = (wself.methods.count > 0);
            wself.tableView.hidden = !hasData;
            wself.emptyStateView.hidden = hasData;
        });
    } hudParentView:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.methods.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cid = @"withdraw_method_cell_stable";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if (indexPath.row >= self.methods.count) {
        cell.textLabel.text = @"";
        cell.detailTextLabel.text = @"";
        return cell;
    }

    NSDictionary *method = self.methods[indexPath.row];
    if (![method isKindOfClass:[NSDictionary class]]) {
        cell.textLabel.text = @"";
        cell.detailTextLabel.text = @"";
        return cell;
    }

    NSInteger type = RCMSafeInteger(method[@"method_type"]);
    NSString *name = RCMSafeString(method[@"account_name"]);
    NSString *number = RCMSafeString(method[@"account_number"]);
    cell.textLabel.text = [NSString stringWithFormat:@"%@ - %@", RCMTypeName(type), name];
    cell.detailTextLabel.text = number;
    cell.accessoryType = RCMSafeBool(method[@"is_default"]) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.methods.count) return;
    NSDictionary *method = self.methods[indexPath.row];
    if (![method isKindOfClass:[NSDictionary class]]) return;

    NSString *methodId = RCMSafeString(method[@"id"]);
    if (methodId.length == 0) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) wself = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"编辑" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (!wself.navigationController) return;
        WalletBindWithdrawMethodViewController *vc = [[WalletBindWithdrawMethodViewController alloc] init];
        vc.methodToEdit = method;
        [wself.navigationController pushViewController:vc animated:YES];
    }]];

    if (!RCMSafeBool(method[@"is_default"])) {
        [alert addAction:[UIAlertAction actionWithTitle:@"设为默认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[HttpRestHelper sharedInstance] submitWalletSetDefaultWithdrawMethod:methodId complete:^(BOOL sucess, NSString *msg) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [BasicTool showAlertInfo:sucess ? @"设置成功" : (msg ?: @"设置失败") parent:wself];
                    if (sucess) [wself reloadMethodsSafely];
                });
            } hudParentView:nil];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[HttpRestHelper sharedInstance] submitWalletDeleteWithdrawMethod:methodId complete:^(BOOL sucess, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [BasicTool showAlertInfo:sucess ? @"删除成功" : (msg ?: @"删除失败") parent:wself];
                if (sucess) [wself reloadMethodsSafely];
            });
        } hudParentView:nil];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = tableView;
        alert.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onAdd
{
    if (!self.navigationController) return;
    WalletBindWithdrawMethodViewController *vc = [[WalletBindWithdrawMethodViewController alloc] init];
    vc.methodToEdit = nil;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
