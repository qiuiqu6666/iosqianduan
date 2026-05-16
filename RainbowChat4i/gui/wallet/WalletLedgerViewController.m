#import "WalletLedgerViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "FileDownloadHelper.h"
#import "MonthYearPickerHelper.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]
static const CGFloat kLedgerPadding = 16.f;
static const CGFloat kLedgerSummaryCardHeight = 72.f;

@interface WalletLedgerViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *list;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger pageSize;
@property (nonatomic, assign) NSInteger total;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMore;
@property (nonatomic, assign) NSInteger selectedTransactionType;
@property (nonatomic, assign) double totalIncome;
@property (nonatomic, assign) double totalExpense;
@property (nonatomic, strong) NSDate *billMonth;
@property (nonatomic, strong) NSArray<NSString *> *billTabTitles;
@property (nonatomic, strong) NSArray<NSNumber *> *billTabTypes;
@property (nonatomic, strong) UIScrollView *billTabsScrollView;
@property (nonatomic, strong) UIView *billTabUnderlineView;
@property (nonatomic, strong) UIButton *monthButton;
@property (nonatomic, strong) UIView *billSummaryContainerView;
@property (nonatomic, strong) UIView *billSummaryInnerView;
@property (nonatomic, strong) UIView *expenseCardView;
@property (nonatomic, strong) UILabel *expenseCardLabel;
@property (nonatomic, strong) UIView *incomeCardView;
@property (nonatomic, strong) UILabel *incomeCardLabel;
@end

@implementation WalletLedgerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = HexColor(0xF5F5F5);
    self.navigationItem.title = @"账单记录";
    
    _list = [NSMutableArray array];
    _currentPage = 1;
    _pageSize = 20;
    _total = 0;
    _isLoading = NO;
    _hasMore = YES;
    _selectedTransactionType = 0;
    _totalIncome = 0;
    _totalExpense = 0;
    NSCalendar *cal = [NSCalendar currentCalendar];
    _billMonth = [cal dateFromComponents:[cal components:NSCalendarUnitYear|NSCalendarUnitMonth fromDate:[NSDate date]]];
    _billTabTitles = @[ @"全部", @"充值", @"提现", @"转账", @"红包" ];
    _billTabTypes = @[ @0, @1, @2, @3, @5 ];

    [self buildUI];
    [self refreshMonthButtonTitle];
    [self loadDataWithPage:1];
}

- (void)buildUI
{
    CGFloat w = self.view.bounds.size.width;
    CGFloat p = kLedgerPadding;
    CGFloat tabH = 44.f;

    _billTabsScrollView = [[UIScrollView alloc] init];
    _billTabsScrollView.showsHorizontalScrollIndicator = NO;
    _billTabsScrollView.backgroundColor = HexColor(0xF5F5F5);
    [self.view addSubview:_billTabsScrollView];
    for (NSUInteger i = 0; i < _billTabTitles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:_billTabTitles[i] forState:UIControlStateNormal];
        [btn setTitleColor:HexColor(0x666666) forState:UIControlStateNormal];
        [btn setTitleColor:HexColor(0x34C759) forState:UIControlStateSelected];
        btn.titleLabel.font = [UIFont systemFontOfSize:15];
        btn.tag = 8000 + (NSInteger)i;
        [btn addTarget:self action:@selector(onBillTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_billTabsScrollView addSubview:btn];
    }
    _billTabUnderlineView = [[UIView alloc] init];
    _billTabUnderlineView.backgroundColor = HexColor(0x34C759);
    _billTabUnderlineView.layer.cornerRadius = 1.5f;
    [_billTabsScrollView addSubview:_billTabUnderlineView];
    [self updateBillTabSelection];

    _monthButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _monthButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [_monthButton setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
    if (@available(iOS 13.0, *)) {
        UIImage *chevron = [UIImage systemImageNamed:@"chevron.down"];
        [_monthButton setImage:[chevron imageWithConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
        _monthButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        _monthButton.imageEdgeInsets = UIEdgeInsetsMake(0, 4, 0, -4);
    }
    [_monthButton addTarget:self action:@selector(onMonthTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_monthButton];

    _billSummaryContainerView = [[UIView alloc] init];
    _billSummaryContainerView.backgroundColor = [UIColor whiteColor];
    _billSummaryContainerView.layer.shadowColor = [UIColor blackColor].CGColor;
    _billSummaryContainerView.layer.shadowOffset = CGSizeMake(0, 2);
    _billSummaryContainerView.layer.shadowRadius = 6;
    _billSummaryContainerView.layer.shadowOpacity = 0.08;
    _billSummaryContainerView.layer.cornerRadius = 10;
    [self.view addSubview:_billSummaryContainerView];

    _billSummaryInnerView = [[UIView alloc] init];
    _billSummaryInnerView.backgroundColor = [UIColor clearColor];
    _billSummaryInnerView.layer.cornerRadius = 10;
    _billSummaryInnerView.clipsToBounds = YES;
    [_billSummaryContainerView addSubview:_billSummaryInnerView];

    _expenseCardView = [[UIView alloc] init];
    _expenseCardView.backgroundColor = [UIColor colorWithRed:1.0 green:0.95 blue:0.9 alpha:1.0];
    [_billSummaryInnerView addSubview:_expenseCardView];
    UILabel *expenseTitle = [[UILabel alloc] init];
    expenseTitle.text = @"↑ 支出";
    expenseTitle.font = [UIFont systemFontOfSize:13];
    expenseTitle.textColor = HexColor(0x666666);
    expenseTitle.tag = 9001;
    [_expenseCardView addSubview:expenseTitle];
    _expenseCardLabel = [[UILabel alloc] init];
    _expenseCardLabel.text = @"¥ 0";
    _expenseCardLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    _expenseCardLabel.textColor = HexColor(0x333333);
    [_expenseCardView addSubview:_expenseCardLabel];

    _incomeCardView = [[UIView alloc] init];
    _incomeCardView.backgroundColor = HexColor(0xE9F3EE);
    [_billSummaryInnerView addSubview:_incomeCardView];
    UILabel *incomeTitle = [[UILabel alloc] init];
    incomeTitle.text = @"↓ 收入";
    incomeTitle.font = [UIFont systemFontOfSize:13];
    incomeTitle.textColor = HexColor(0x666666);
    incomeTitle.tag = 9002;
    [_incomeCardView addSubview:incomeTitle];
    _incomeCardLabel = [[UILabel alloc] init];
    _incomeCardLabel.text = @"¥ 0";
    _incomeCardLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    _incomeCardLabel.textColor = HexColor(0x333333);
    [_incomeCardView addSubview:_incomeCardLabel];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = HexColor(0xF5F5F5);
    _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _tableView.separatorColor = HexColor(0xE5E5E5);
    _tableView.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0);
    [self.view addSubview:_tableView];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat safeTop = 0, safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = self.view.safeAreaInsets.top;
        safeBottom = self.view.safeAreaInsets.bottom;
    }
    CGFloat w = self.view.bounds.size.width;
    CGFloat p = kLedgerPadding;
    CGFloat y = safeTop;
    CGFloat tabH = 44.f;

    _billTabsScrollView.frame = CGRectMake(0, y, w, tabH);
    CGFloat tabX = p;
    for (NSUInteger i = 0; i < _billTabTitles.count; i++) {
        UIButton *btn = [_billTabsScrollView viewWithTag:8000 + (NSInteger)i];
        if ([btn isKindOfClass:[UIButton class]]) {
            [btn sizeToFit];
            CGFloat bw = btn.bounds.size.width + 24;
            btn.frame = CGRectMake(tabX, 8, bw, 28);
            tabX += bw;
        }
    }
    _billTabsScrollView.contentSize = CGSizeMake(MAX(w, tabX + p), tabH);
    NSInteger selIdx = 0;
    for (NSUInteger i = 0; i < _billTabTypes.count; i++) {
        if ([_billTabTypes[i] integerValue] == _selectedTransactionType) { selIdx = (NSInteger)i; break; }
    }
    for (NSUInteger i = 0; i < _billTabTitles.count; i++) {
        UIButton *b = [_billTabsScrollView viewWithTag:8000 + (NSInteger)i];
        if ([b isKindOfClass:[UIButton class]]) b.selected = (i == (NSUInteger)selIdx);
    }
    UIButton *selTab = [_billTabsScrollView viewWithTag:8000 + selIdx];
    if ([selTab isKindOfClass:[UIButton class]] && _billTabUnderlineView) {
        _billTabUnderlineView.frame = CGRectMake(CGRectGetMinX(selTab.frame) + 12, 36, CGRectGetWidth(selTab.frame) - 24, 2);
    }
    y += tabH;

    _monthButton.frame = CGRectMake(p, y, 140, 36);
    y += 44;

    CGFloat cardW = (w - p * 2) / 2;
    _billSummaryContainerView.frame = CGRectMake(p, y, w - p * 2, kLedgerSummaryCardHeight);
    _billSummaryInnerView.frame = _billSummaryContainerView.bounds;
    _expenseCardView.frame = CGRectMake(0, 0, cardW, kLedgerSummaryCardHeight);
    _incomeCardView.frame = CGRectMake(cardW, 0, cardW, kLedgerSummaryCardHeight);
    UILabel *expenseTitle = [_expenseCardView viewWithTag:9001];
    if (expenseTitle) expenseTitle.frame = CGRectMake(12, 10, cardW - 24, 18);
    _expenseCardLabel.frame = CGRectMake(12, 32, cardW - 24, 28);
    UILabel *incomeTitle = [_incomeCardView viewWithTag:9002];
    if (incomeTitle) incomeTitle.frame = CGRectMake(12, 10, cardW - 24, 18);
    _incomeCardLabel.frame = CGRectMake(12, 32, cardW - 24, 28);
    y += kLedgerSummaryCardHeight + 12;

    _tableView.frame = CGRectMake(0, y, w, self.view.bounds.size.height - y - safeBottom);
}

- (void)refreshMonthButtonTitle
{
    NSDateFormatter *fm = [[NSDateFormatter alloc] init];
    fm.dateFormat = @"yyyy年M月";
    [_monthButton setTitle:[fm stringFromDate:_billMonth] forState:UIControlStateNormal];
}

- (void)updateBillTabSelection
{
    for (NSUInteger i = 0; i < _billTabTypes.count; i++) {
        UIButton *btn = [_billTabsScrollView viewWithTag:8000 + (NSInteger)i];
        if ([btn isKindOfClass:[UIButton class]]) {
            btn.selected = ([_billTabTypes[i] integerValue] == _selectedTransactionType);
        }
    }
    [self viewDidLayoutSubviews];
}

- (void)onBillTabTapped:(UIButton *)sender
{
    NSInteger idx = sender.tag - 8000;
    if (idx < 0 || idx >= (NSInteger)_billTabTypes.count) return;
    _selectedTransactionType = [_billTabTypes[idx] integerValue];
    [self updateBillTabSelection];
    _currentPage = 1;
    _hasMore = YES;
    [_list removeAllObjects];
    [self loadDataWithPage:1];
}

- (void)onMonthTapped
{
    __weak typeof(self) wself = self;
    [MonthYearPickerHelper showInView:self.view currentDate:_billMonth minYear:2024 completion:^(NSDate * _Nullable selectedDate) {
        if (!selectedDate || !wself) return;
        wself.billMonth = selectedDate;
        [wself refreshMonthButtonTitle];
        wself.currentPage = 1;
        wself.hasMore = YES;
        [wself.list removeAllObjects];
        [wself loadDataWithPage:1];
    }];
}

// 根据交易类型与金额判断是否为收入（1=充值, 4=转账接收, 6=红包接收, 7=红包退回；2=提现, 3=转账发出, 5=红包发出为支出）
- (BOOL)isIncomeTransactionType:(NSInteger)transactionType amount:(double)amount
{
    switch (transactionType) {
        case 1: return YES;  // 充值
        case 2: return NO;   // 提现
        case 3: return NO;   // 转账发出
        case 4: return YES;  // 转账接收
        case 5: return NO;   // 红包发出
        case 6: return YES;  // 红包接收
        case 7: return YES;  // 红包退回
        default:
            // 未区分类型时按金额正负：正=收入，负=支出
            return (amount >= 0);
    }
}

- (void)loadDataWithPage:(NSInteger)page
{
    if (_isLoading) return;
    _isLoading = YES;
    
    __weak typeof(self) wself = self;
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comp = [cal components:NSCalendarUnitYear|NSCalendarUnitMonth fromDate:_billMonth];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"page": @(page),
        @"page_size": @(_pageSize),
        @"year": @(comp.year),
        @"month": @(comp.month)
    }];
    // 转账(3)、红包(5)不传类型参数，与「全部」一样拉全量，由客户端按类型过滤，避免服务端不支持多类型时返回空
    if (_selectedTransactionType > 0 && _selectedTransactionType != 3 && _selectedTransactionType != 5) {
        params[@"transaction_type"] = @(_selectedTransactionType);
    }
    
    NSLog(@"【交易记录】加载第%ld页数据，交易类型=%ld", (long)page, (long)_selectedTransactionType);
    
    [[HttpRestHelper sharedInstance] submitWalletLedgerListWithParams:params complete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            wself.isLoading = NO;
            
            if (sucess && data && [data isKindOfClass:[NSDictionary class]]) {
                // 解析分页信息
                if (data[@"total"]) {
                    wself.total = [data[@"total"] integerValue];
                }
                if (data[@"page"]) {
                    wself.currentPage = [data[@"page"] integerValue];
                }
                if (data[@"page_size"]) {
                    wself.pageSize = [data[@"page_size"] integerValue];
                }
                
                // 解析列表数据
                NSArray *newList = nil;
                if (data[@"list"] && [data[@"list"] isKindOfClass:[NSArray class]]) {
                    newList = data[@"list"];
                } else if ([data isKindOfClass:[NSArray class]]) {
                    // 兼容旧接口：直接返回数组
                    newList = (NSArray *)data;
                }
                // 若服务端未按类型筛选，客户端再过滤：转账只保留 3、4，红包只保留 5、6、7
                if (newList.count > 0 && (wself.selectedTransactionType == 3 || wself.selectedTransactionType == 5)) {
                    NSArray *allowed = (wself.selectedTransactionType == 3) ? @[@3, @4] : @[@5, @6, @7];
                    newList = [newList filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, id _) {
                        NSInteger t = item[@"transaction_type"] ? [[item[@"transaction_type"] description] integerValue] : 0;
                        return [allowed containsObject:@(t)];
                    }]];
                }
                
                if (newList && newList.count > 0) {
                    if (page == 1) {
                        // 第一页，替换数据
                        [wself.list removeAllObjects];
                        wself.totalIncome = 0;
                        wself.totalExpense = 0;
                    }
                    [wself.list addObjectsFromArray:newList];
                    
                    // 计算收支统计（仅第一页）：根据 transaction_type 判断收入/支出，服务端可能只返回正数金额
                    if (page == 1) {
                        for (NSDictionary *item in newList) {
                            double amount = 0.0;
                            if (item[@"amount"]) {
                                NSString *amountValue = [item[@"amount"] description];
                                amount = [amountValue doubleValue];
                            } else if (item[@"amount_cent"]) {
                                long long amountCent = [item[@"amount_cent"] longLongValue];
                                amount = amountCent / 100.0;
                            }
                            NSInteger txType = item[@"transaction_type"] ? [[item[@"transaction_type"] description] integerValue] : 0;
                            BOOL isIncome = [wself isIncomeTransactionType:txType amount:amount];
                            double absAmount = fabs(amount);
                            if (absAmount > 0) {
                                if (isIncome) {
                                    wself.totalIncome += absAmount;
                                } else {
                                    wself.totalExpense += absAmount;
                                }
                            }
                        }
                        
                        wself.expenseCardLabel.text = [NSString stringWithFormat:@"¥ %@", [wself formatAmount:wself.totalExpense]];
                        wself.incomeCardLabel.text = [NSString stringWithFormat:@"¥ %@", [wself formatAmount:wself.totalIncome]];
                    }
                    
                    wself.hasMore = wself.list.count < wself.total;
                } else {
                    wself.hasMore = NO;
                    if (page == 1) {
                        [wself.list removeAllObjects];
                        wself.totalIncome = 0;
                        wself.totalExpense = 0;
                        wself.expenseCardLabel.text = @"¥ 0";
                        wself.incomeCardLabel.text = @"¥ 0";
                    }
                }
                
                NSLog(@"【交易记录】加载完成：total=%ld, currentPage=%ld, list.count=%lu, hasMore=%d", 
                      (long)wself.total, (long)wself.currentPage, (unsigned long)wself.list.count, wself.hasMore);
                
                [wself.tableView reloadData];
            } else {
                NSLog(@"【交易记录】加载失败：success=%d, data=%@", sucess, data);
                if (wself.list.count == 0) {
                    // 首次加载失败，显示错误提示
                    [BasicTool showAlertInfo:@"加载失败，请稍后重试" parent:wself];
                }
            }
        });
    } hudParentView:self.view];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _list.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 70.f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cid = @"WalletLedgerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    
    UIImageView *iconView = nil;
    UILabel *titleLabel = nil;
    UILabel *timeLabel = nil;
    UILabel *amountLabel = nil;
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor whiteColor];
        
        // 左侧图标
        iconView = [[UIImageView alloc] init];
        iconView.tag = 1001;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        [cell.contentView addSubview:iconView];
        
        titleLabel = [[UILabel alloc] init];
        titleLabel.tag = 1002;
        titleLabel.font = [UIFont systemFontOfSize:16];
        titleLabel.textColor = HexColor(0x333333);
        titleLabel.numberOfLines = 1;
        titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell.contentView addSubview:titleLabel];
        
        // 时间标签
        timeLabel = [[UILabel alloc] init];
        timeLabel.tag = 1003;
        timeLabel.font = [UIFont systemFontOfSize:12];
        timeLabel.textColor = HexColor(0x999999);
        [cell.contentView addSubview:timeLabel];
        
        // 金额标签
        amountLabel = [[UILabel alloc] init];
        amountLabel.tag = 1004;
        amountLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
        amountLabel.textAlignment = NSTextAlignmentRight;
        [cell.contentView addSubview:amountLabel];
    } else {
        iconView = (UIImageView *)[cell.contentView viewWithTag:1001];
        titleLabel = (UILabel *)[cell.contentView viewWithTag:1002];
        timeLabel = (UILabel *)[cell.contentView viewWithTag:1003];
        amountLabel = (UILabel *)[cell.contentView viewWithTag:1004];
    }
    
    if (indexPath.row >= _list.count) {
        return cell;
    }
    
    NSDictionary *item = _list[indexPath.row];
    if (![item isKindOfClass:[NSDictionary class]]) {
        return cell;
    }
    
    // 解析金额
    double amount = 0.0;
    if (item[@"amount"]) {
        NSString *amountValue = [item[@"amount"] description];
        amount = [amountValue doubleValue];
    } else if (item[@"amount_cent"]) {
        long long amountCent = [item[@"amount_cent"] longLongValue];
        amount = amountCent / 100.0;
    }
    
    // 解析交易类型
    NSString *typeName = @"未知";
    NSInteger transactionType = 0;
    if (item[@"transaction_type"]) {
        transactionType = [item[@"transaction_type"] integerValue];
        switch (transactionType) {
            case 1: typeName = @"充值"; break;
            case 2: typeName = @"提现"; break;
            case 3: typeName = @"转账"; break;
            case 4: typeName = @"转账"; break;
            case 5: typeName = @"红包"; break;
            case 6: typeName = @"红包"; break;
            case 7: typeName = @"红包退回"; break;
            default: typeName = @"未知"; break;
        }
    }
    
    // 重置图标状态（防止cell重用问题）
    iconView.image = nil;
    iconView.backgroundColor = nil;
    
    // 设置图标
    UIColor *iconBgColor = HexColor(0xFF3B30);
    NSString *iconName = @"";
    
    // 对于转账类型，尝试加载用户头像
    BOOL isTransferType = (transactionType == 3 || transactionType == 4);
    NSString *relatedUserId = nil;
    
    if (isTransferType && item[@"related_user_uid"]) {
        relatedUserId = [item[@"related_user_uid"] description];
        if (relatedUserId.length > 0 && ![relatedUserId isEqualToString:@"(null)"] && ![relatedUserId isEqualToString:@"null"]) {
            // 先显示默认图标（占位）
            iconBgColor = HexColor(0x34C759);
            if (@available(iOS 13.0, *)) {
                iconName = @"arrow.left.right.circle.fill";
                iconView.image = [UIImage systemImageNamed:iconName];
                iconView.tintColor = [UIColor whiteColor];
            }
            iconView.backgroundColor = iconBgColor;
            iconView.contentMode = UIViewContentModeScaleAspectFill;
            
            // 异步加载用户头像
            __weak typeof(self) wself = self;
            __weak typeof(cell) wcell = cell;
            NSIndexPath *currentIndexPath = indexPath; // 保存当前indexPath
            
            [FileDownloadHelper loadUserAvatarWithUID:relatedUserId 
                                               logTag:@"WalletLedger" 
                                             complete:^(BOOL sucess, UIImage *img) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 检查cell是否还在使用（防止重用问题）
                    NSIndexPath *cellIndexPath = [wself.tableView indexPathForCell:wcell];
                    if (cellIndexPath && cellIndexPath.row == currentIndexPath.row && cellIndexPath.section == currentIndexPath.section) {
                        UIImageView *currentIconView = (UIImageView *)[wcell.contentView viewWithTag:1001];
                        if (currentIconView) {
                            if (sucess && img) {
                                // 设置头像
                                currentIconView.image = img;
                                currentIconView.backgroundColor = [UIColor clearColor];
                                currentIconView.contentMode = UIViewContentModeScaleAspectFill;
                            } else {
                                // 加载失败，保持默认图标
                                // 默认图标已经在上面设置了
                            }
                        }
                    }
                });
            } donotLoadFromDisk:NO];
        } else {
            // 没有用户ID，使用默认图标
            iconBgColor = HexColor(0x34C759);
            if (@available(iOS 13.0, *)) {
                iconName = @"arrow.left.right.circle.fill";
                iconView.image = [UIImage systemImageNamed:iconName];
                iconView.tintColor = [UIColor whiteColor];
            }
            iconView.backgroundColor = iconBgColor;
            iconView.contentMode = UIViewContentModeScaleAspectFit;
        }
    } else {
        // 非转账类型
        switch (transactionType) {
            case 1: { // 充值 - 使用零钱页面的图标
                UIImage *rechargeImg = [UIImage imageNamed:@"action_recharge"];
                if (rechargeImg) {
                    iconView.image = [rechargeImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
                    iconView.backgroundColor = [UIColor whiteColor];
                    iconView.contentMode = UIViewContentModeScaleAspectFit;
                } else {
                    // 如果图标不存在，使用系统图标作为后备
                    iconBgColor = HexColor(0x1674FF);
                    if (@available(iOS 13.0, *)) {
                        iconView.image = [UIImage systemImageNamed:@"plus.circle.fill"];
                        iconView.tintColor = [UIColor whiteColor];
                    }
                    iconView.backgroundColor = iconBgColor;
                    iconView.contentMode = UIViewContentModeScaleAspectFit;
                }
                break;
            }
            case 2: { // 提现 - 使用零钱页面的图标
                UIImage *withdrawImg = [UIImage imageNamed:@"action_withdraw"];
                if (withdrawImg) {
                    iconView.image = [withdrawImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
                    iconView.backgroundColor = [UIColor whiteColor];
                    iconView.contentMode = UIViewContentModeScaleAspectFit;
                } else {
                    // 如果图标不存在，使用系统图标作为后备
                    iconBgColor = HexColor(0xFF3B30);
                    if (@available(iOS 13.0, *)) {
                        iconView.image = [UIImage systemImageNamed:@"minus.circle.fill"];
                        iconView.tintColor = [UIColor whiteColor];
                    }
                    iconView.backgroundColor = iconBgColor;
                    iconView.contentMode = UIViewContentModeScaleAspectFit;
                }
                break;
            }
            case 5: case 6: case 7: { // 红包 - 与首页一致使用 wallet_bill_red_packet
                UIImage *redPacketImg = [UIImage imageNamed:@"wallet_bill_red_packet"];
                if (redPacketImg) {
                    iconView.image = redPacketImg;
                    iconView.backgroundColor = [UIColor whiteColor];
                    iconView.contentMode = UIViewContentModeScaleAspectFit;
                } else {
                    iconBgColor = HexColor(0xFF3B30);
                    if (@available(iOS 13.0, *)) {
                        iconView.image = [UIImage systemImageNamed:@"envelope.fill"];
                        iconView.tintColor = [UIColor whiteColor];
                    } else {
                        iconView.image = nil;
                    }
                    iconView.backgroundColor = iconBgColor;
                    iconView.contentMode = UIViewContentModeScaleAspectFit;
                }
                break;
            }
            default: {
                iconBgColor = HexColor(0x999999);
                if (@available(iOS 13.0, *)) {
                    iconView.image = [UIImage systemImageNamed:@"circle.fill"];
                    iconView.tintColor = [UIColor whiteColor];
                } else {
                    iconView.image = nil;
                }
                iconView.backgroundColor = iconBgColor;
                iconView.contentMode = UIViewContentModeScaleAspectFit;
                break;
            }
        }
    }
    
    // 设置图标样式：方形圆角（与钱包首页账单一致）
    iconView.layer.cornerRadius = 8.f;
    iconView.clipsToBounds = YES;
    
    // 解析备注
    NSString *remark = item[@"remark"] ? [item[@"remark"] description] : @"";
    if (remark.length > 0 && ![remark isEqualToString:typeName]) {
        titleLabel.text = [NSString stringWithFormat:@"%@-%@", typeName, remark];
    } else {
        titleLabel.text = typeName;
    }
    
    // 解析时间（毫秒时间戳）
    NSString *timeStr = @"";
    if (item[@"create_time"]) {
        NSString *timeValue = [item[@"create_time"] description];
        long long timestamp = [timeValue longLongValue];
        if (timestamp > 0) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp / 1000.0];
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"M月d日 HH:mm";
            timeStr = [formatter stringFromDate:date];
        }
    } else if (item[@"created_at"]) {
        timeStr = [item[@"created_at"] description];
    }
    timeLabel.text = timeStr;
    
    // 格式化金额显示：根据 transaction_type 判断收入/支出（服务端可能只返回正数）
    BOOL isIncome = [self isIncomeTransactionType:transactionType amount:amount];
    double absAmount = fabs(amount);
    if (isIncome) {
        amountLabel.text = [NSString stringWithFormat:@"+%.2f", absAmount];
        amountLabel.textColor = HexColor(0x34C759); // 收入绿色
    } else {
        amountLabel.text = [NSString stringWithFormat:@"-%.2f", absAmount];
        amountLabel.textColor = HexColor(0x333333); // 支出深色
    }
    if (absAmount == 0) {
        amountLabel.text = @"0.00";
        amountLabel.textColor = HexColor(0x333333);
    }
    
    // 布局（在willDisplayCell中更新frame）
    CGFloat padding = 16.0;
    CGFloat iconSize = 40.0;
    iconView.frame = CGRectMake(padding, 15, iconSize, iconSize);
    
    CGFloat leftMargin = padding + iconSize + 12;
    CGFloat rightMargin = 120.0;
    CGFloat titleHeight = 20.0;
    CGFloat timeHeight = 16.0;
    CGFloat cellWidth = self.view.bounds.size.width;
    
    titleLabel.frame = CGRectMake(leftMargin, 18, 
                                  cellWidth - leftMargin - rightMargin, 
                                  titleHeight);
    timeLabel.frame = CGRectMake(leftMargin, 40, 
                                  cellWidth - leftMargin - rightMargin, 
                                  timeHeight);
    amountLabel.frame = CGRectMake(cellWidth - padding - 100, 20, 
                                   100, 30);
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 更新单元格布局（确保在不同屏幕尺寸下正确显示）
    UILabel *titleLabel = (UILabel *)[cell.contentView viewWithTag:1002];
    UILabel *timeLabel = (UILabel *)[cell.contentView viewWithTag:1003];
    UILabel *amountLabel = (UILabel *)[cell.contentView viewWithTag:1004];
    
    if (titleLabel && timeLabel && amountLabel) {
        CGFloat padding = 16.0;
        CGFloat iconSize = 40.0;
        CGFloat leftMargin = padding + iconSize + 12;
        CGFloat rightMargin = 120.0;
        CGFloat cellWidth = self.view.bounds.size.width;
        
        titleLabel.frame = CGRectMake(leftMargin, 18, 
                                      cellWidth - leftMargin - rightMargin, 
                                      20);
        timeLabel.frame = CGRectMake(leftMargin, 40, 
                                      cellWidth - leftMargin - rightMargin, 
                                      16);
        amountLabel.frame = CGRectMake(cellWidth - padding - 100, 20, 
                                       100, 30);
    }
    
    // 加载更多：当显示倒数第3条时，加载下一页
    if (indexPath.row >= _list.count - 3 && _hasMore && !_isLoading) {
        [self loadDataWithPage:_currentPage + 1];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // 可以在这里添加点击详情功能
    if (indexPath.row < _list.count) {
        NSDictionary *item = _list[indexPath.row];
        // TODO: 跳转到交易详情页面
    }
}

- (NSString *)formatAmount:(double)amount
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;
    formatter.groupingSeparator = @",";
    formatter.usesGroupingSeparator = YES;
    
    NSNumber *number = [NSNumber numberWithDouble:amount];
    NSString *formattedString = [formatter stringFromNumber:number];
    return formattedString;
}

@end
