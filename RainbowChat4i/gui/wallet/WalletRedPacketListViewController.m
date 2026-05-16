#import "WalletRedPacketListViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "WalletRedPacketDetailViewController.h"
#import "UIViewController+RBPlainCustomNav.h"

@interface WalletRedPacketListViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *list;
@property (nonatomic, assign) int currentPage;
@property (nonatomic, assign) BOOL hasMore;
@end

@implementation WalletRedPacketListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"红包记录"];

    _currentPage = 1;
    _hasMore = YES;
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
    
    [self loadRedPackets];
}

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

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat t = 0, b = 0;
    if (@available(iOS 11.0, *)) {
        t = self.view.safeAreaInsets.top;
        b = self.view.safeAreaInsets.bottom;
    }
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    _tableView.frame = CGRectMake(0, t, w, h - t - b);
}

- (void)loadRedPackets
{
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletGetRedPacketList:_currentPage pageSize:20 type:-1 complete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && data) {
                NSArray *list = data[@"list"];
                if (list) {
                    if (wself.currentPage == 1) {
                        wself.list = list;
                    } else {
                        wself.list = [wself.list arrayByAddingObjectsFromArray:list];
                    }
                    wself.hasMore = ([list count] == 20);
                    [wself.tableView reloadData];
                }
            }
        });
    } hudParentView:self.view];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _list.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cid = @"redpacket_cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    NSDictionary *item = _list[indexPath.row];
    
    // 显示红包信息
    NSString *amount = item[@"total_amount"] ? [item[@"total_amount"] description] : @"0.00";
    NSString *status = @"";
    int statusValue = [item[@"status"] intValue];
    switch (statusValue) {
        case 0: status = @"进行中"; break;
        case 1: status = @"已抢完"; break;
        case 2: status = @"已过期"; break;
        default: break;
    }
    
    cell.textLabel.text = [NSString stringWithFormat:@"¥%@ - %@", amount, status];
    cell.detailTextLabel.text = item[@"message"] ?: @"";
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *item = _list[indexPath.row];
    NSString *packetId = item[@"id"] ? [item[@"id"] description] : item[@"packet_id"] ? [item[@"packet_id"] description] : nil;
    
    if (packetId) {
        WalletRedPacketDetailViewController *vc = [[WalletRedPacketDetailViewController alloc] init];
        vc.packetId = packetId;
        vc.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:vc animated:YES];
    }
}

@end
