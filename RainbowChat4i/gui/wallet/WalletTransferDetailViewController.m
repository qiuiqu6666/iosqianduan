#import "WalletTransferDetailViewController.h"
#import "WalletHomeViewController.h"
#import "WalletLedgerViewController.h"
#import "UIViewController+RBPlainCustomNav.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static NSString * const kTransferDetailTimeFormat = @"yyyy年MM月dd日 HH:mm:ss";

@interface WalletTransferDetailViewController ()
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *successIconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *amountLabel;
@property (nonatomic, strong) UIButton *balanceButton;
@property (nonatomic, strong) UILabel *transferTimeLabel;   // 左侧「转账时间」
@property (nonatomic, strong) UILabel *transferTimeValueLabel;
@property (nonatomic, strong) UILabel *receiptTimeLabel;     // 左侧「收款时间」
@property (nonatomic, strong) UILabel *receiptTimeValueLabel;
@property (nonatomic, strong) UIButton *billDetailButton;
@end

@implementation WalletTransferDetailViewController

- (NSString *)displayAssetType
{
    return (self.assetType.length > 0 ? self.assetType : @"CNY");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"转账详情"];

    _contentView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_contentView];

    // 成功图标：绿色圆 + 白色勾
    _successIconView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 56, 56)];
    _successIconView.backgroundColor = HexColor(0x07C160);
    _successIconView.layer.cornerRadius = 28;
    _successIconView.clipsToBounds = YES;
    [_contentView addSubview:_successIconView];
    if (@available(iOS 13.0, *)) {
        UIImageView *check = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"]];
        check.tintColor = [UIColor whiteColor];
        check.contentMode = UIViewContentModeScaleAspectFit;
        check.frame = CGRectMake(14, 14, 28, 28);
        [_successIconView addSubview:check];
    }

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    _titleLabel.textColor = HexColor(0x333333);
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.numberOfLines = 2;
    _titleLabel.text = self.isIncoming ? @"你已收款,资金已存入零钱" : @"已转出";
    [_contentView addSubview:_titleLabel];

    _amountLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _amountLabel.font = [UIFont systemFontOfSize:42 weight:UIFontWeightMedium];
    _amountLabel.textColor = HexColor(0x333333);
    _amountLabel.textAlignment = NSTextAlignmentCenter;
    NSString *amt = self.amount.length > 0 ? self.amount : @"0.00";
    _amountLabel.text = [NSString stringWithFormat:@"%@ %@", [self displayAssetType], amt];
    [_contentView addSubview:_amountLabel];

    _balanceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_balanceButton setTitle:@"零钱余额" forState:UIControlStateNormal];
    [_balanceButton setTitleColor:HexColor(0x576B95) forState:UIControlStateNormal];
    _balanceButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [_balanceButton addTarget:self action:@selector(onBalanceTapped) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:_balanceButton];

    _transferTimeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _transferTimeLabel.font = [UIFont systemFontOfSize:14];
    _transferTimeLabel.textColor = HexColor(0x999999);
    _transferTimeLabel.textAlignment = NSTextAlignmentLeft;
    _transferTimeLabel.text = @"转账时间";
    [_contentView addSubview:_transferTimeLabel];

    _transferTimeValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _transferTimeValueLabel.font = [UIFont systemFontOfSize:14];
    _transferTimeValueLabel.textColor = HexColor(0x333333);
    _transferTimeValueLabel.textAlignment = NSTextAlignmentRight;
    [_contentView addSubview:_transferTimeValueLabel];

    _receiptTimeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _receiptTimeLabel.font = [UIFont systemFontOfSize:14];
    _receiptTimeLabel.textColor = HexColor(0x999999);
    _receiptTimeLabel.textAlignment = NSTextAlignmentLeft;
    _receiptTimeLabel.text = @"收款时间";
    [_contentView addSubview:_receiptTimeLabel];

    _receiptTimeValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _receiptTimeValueLabel.font = [UIFont systemFontOfSize:14];
    _receiptTimeValueLabel.textColor = HexColor(0x333333);
    _receiptTimeValueLabel.textAlignment = NSTextAlignmentRight;
    [_contentView addSubview:_receiptTimeValueLabel];

    _billDetailButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_billDetailButton setTitle:@"账单详情" forState:UIControlStateNormal];
    [_billDetailButton setTitleColor:HexColor(0x576B95) forState:UIControlStateNormal];
    _billDetailButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [_billDetailButton addTarget:self action:@selector(onBillDetailTapped) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:_billDetailButton];

    [self updateTimeLabels];
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

- (void)updateTimeLabels
{
    NSDate *transfer = _transferTime ?: [NSDate date];
    NSDate *receipt = _receiptTime ?: _transferTime ?: [NSDate date];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = kTransferDetailTimeFormat;
    _transferTimeValueLabel.text = [fmt stringFromDate:transfer];
    _receiptTimeValueLabel.text = [fmt stringFromDate:receipt];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat safeTop = 0, safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = self.view.safeAreaInsets.top;
        safeBottom = self.view.safeAreaInsets.bottom;
    }
    CGFloat padding = 24;
    CGFloat y = safeTop + 32;

    _successIconView.center = CGPointMake(w / 2, y + 28);
    y += 56 + 20;

    _titleLabel.frame = CGRectMake(padding, y, w - padding * 2, 44);
    y += 48;

    _amountLabel.frame = CGRectMake(padding, y, w - padding * 2, 50);
    y += 56;

    [_balanceButton sizeToFit];
    _balanceButton.frame = CGRectMake((w - _balanceButton.bounds.size.width) / 2, y, _balanceButton.bounds.size.width, 36);
    y += 44;

    // 转账时间 / 收款时间：左标签（浅灰）+ 右时间（深色右对齐），两列布局
    CGFloat timeH = 22;
    CGFloat labelW = 80;
    CGFloat valueLeft = padding + labelW + 12;
    CGFloat valueW = w - valueLeft - padding;
    _transferTimeLabel.frame = CGRectMake(padding, y, labelW, timeH);
    _transferTimeValueLabel.frame = CGRectMake(valueLeft, y, valueW, timeH);
    y += timeH + 12;
    _receiptTimeLabel.frame = CGRectMake(padding, y, labelW, timeH);
    _receiptTimeValueLabel.frame = CGRectMake(valueLeft, y, valueW, timeH);
    y += timeH;

    // 账单详情：固定在页面最底部（安全区域内）
    [_billDetailButton sizeToFit];
    CGFloat billY = h - safeBottom - 44;
    _billDetailButton.frame = CGRectMake((w - _billDetailButton.bounds.size.width) / 2, billY, _billDetailButton.bounds.size.width, 44);

    _contentView.frame = self.view.bounds;
}

- (void)onBalanceTapped
{
    WalletHomeViewController *vc = [[WalletHomeViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onBillDetailTapped
{
    WalletLedgerViewController *vc = [[WalletLedgerViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
