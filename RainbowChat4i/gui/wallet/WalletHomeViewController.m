//telegram @wz662
// 我的零钱页面：大余额 + 充值/提现 + 服务入口(银行卡/亲属卡/支付分/安全保障) + 账单(分类/月/收支/列表)

#import "WalletHomeViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "IMClientManager.h"
#import "WalletLedgerViewController.h"
#import "WalletFundPasswordViewController.h"
#import "WalletModifyFundPasswordViewController.h"
#import "WalletTransferViewController.h"
#import "WalletReceiveCodeViewController.h"
#import "WalletRechargeViewController.h"
#import "WalletWithdrawViewController.h"
#import "WalletWithdrawMethodViewController.h"
#import "WalletCardWalletViewController.h"
#import "FileDownloadHelper.h"
#import "FriendsListProvider.h"
#import "UserEntity.h"
#import "MonthYearPickerHelper.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "UIViewController+RBPlainCustomNav.h"
#import "UIViewController+RBAlarmsStyleMainTabNav.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static const CGFloat kPadding = 16.f;
static const CGFloat kBalanceFontSize = 36.f;
static const CGFloat kServiceIconSize = 40.f;
static const CGFloat kBillRowHeight = 64.f;
static const CGFloat kBillSummaryCardHeight = 72.f;

/// 按用户隔离的余额展示文案本地缓存（与接口返回的带 ¥ 前缀一致）
static NSString *RBCachedWalletBalanceKey(NSString *uid) {
    if (uid.length == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"rc_wallet_balance_display_v1_%@", uid];
}

static NSString *RBCachedWalletTrxAddressKey(NSString *uid) {
    if (uid.length == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"rc_wallet_trx_address_v1_%@", uid];
}

static NSNumberFormatter *RBWalletTwoDecimalFormatter(void) {
    static NSNumberFormatter *f = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        f = [[NSNumberFormatter alloc] init];
        f.numberStyle = NSNumberFormatterDecimalStyle;
        f.minimumIntegerDigits = 1;
        f.minimumFractionDigits = 2;
        f.maximumFractionDigits = 2;
        f.usesGroupingSeparator = NO;
    });
    return f;
}

static NSString *RBWalletFormatCNY(NSDecimalNumber *n) {
    if (!n || [n isEqualToNumber:[NSDecimalNumber notANumber]]) {
        return @"¥--";
    }
    NSString *s = [RBWalletTwoDecimalFormatter() stringFromNumber:n];
    if (s.length == 0) {
        s = n.stringValue ?: @"--";
    }
    return [NSString stringWithFormat:@"¥%@", s];
}

@interface WalletHomeViewController () <UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
// 顶部余额区
@property (nonatomic, strong) UILabel *balanceLabel;
@property (nonatomic, strong) UIButton *eyeButton;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *rechargeButton;
@property (nonatomic, strong) UIButton *withdrawButton;
@property (nonatomic, strong) UIActivityIndicatorView *balanceLoadingView;
// 服务入口（银行卡/亲属卡/支付分/安全保障）
@property (nonatomic, strong) UIView *serviceSectionView;
@property (nonatomic, strong) NSArray<UIButton *> *serviceButtons;
// 账单区
@property (nonatomic, strong) UILabel *billTitleLabel;
@property (nonatomic, strong) UIScrollView *billTabsScrollView;
@property (nonatomic, strong) UIView *billTabUnderlineView;
@property (nonatomic, strong) UIView *billSummaryContainerView;
@property (nonatomic, strong) UIView *billSummaryInnerView;
@property (nonatomic, strong) NSArray<NSString *> *billTabTitles;
@property (nonatomic, strong) NSArray<NSNumber *> *billTabTypes; // 0=全部, 1=充值, 2=提现, 3=转账, 5=红包
@property (nonatomic, assign) NSInteger selectedBillTabIndex;
@property (nonatomic, strong) UIButton *monthButton;
@property (nonatomic, strong) UIButton *statisticsButton;
@property (nonatomic, strong) UIView *expenseCardView;
@property (nonatomic, strong) UILabel *expenseCardLabel;
@property (nonatomic, strong) UIView *incomeCardView;
@property (nonatomic, strong) UILabel *incomeCardLabel;
@property (nonatomic, strong) UITableView *billTableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *ledgerList;
@property (nonatomic, assign) double totalExpense;
@property (nonatomic, assign) double totalIncome;
@property (nonatomic, strong) NSDate *billMonth;
@property (nonatomic, assign) BOOL balanceHidden;
/// 已成功结束过至少一次余额请求后，再次进入页面时保留上次数字并静默刷新（避免 "--" 与菊花反复触发闪烁）
@property (nonatomic, assign) BOOL rb_walletBalanceFetchedOnce;
/// 地址接口(104)是否已成功拉取过一次；避免每次进入钱包都重复打接口，同时能在首次进入时校正本地缓存
@property (nonatomic, assign) BOOL rb_walletAddressFetchedOnce;
@property (nonatomic, assign) BOOL fundPasswordHasSet;
@property (nonatomic, strong) UIView *moreSheetOverlay;
@property (nonatomic, strong) UIView *moreSheetPanel;
@property (nonatomic, strong) UIView *topCardView;
@property (nonatomic, strong) UILabel *addressTitleLabel;
@property (nonatomic, strong) UILabel *addressValueLabel;
@property (nonatomic, strong) UIButton *addressCopyButton;
@property (nonatomic, strong) UIView *menuSectionView;
@property (nonatomic, strong) UIButton *receiveButton;
@property (nonatomic, strong) UIButton *transferButton;
@property (nonatomic, strong) UIButton *swapButton;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIView *tokensSectionView;
@property (nonatomic, strong) UILabel *tokensTitleLabel;
@property (nonatomic, strong) NSArray<UIView *> *tokenRowViews;
@property (nonatomic, strong) NSArray<UILabel *> *tokenValueLabels;
@property (nonatomic, strong) NSArray<UILabel *> *tokenFiatLabels;
@property (nonatomic, strong) NSArray<UILabel *> *tokenPriceLabels;
@property (nonatomic, copy) NSString *trxAddress;
@property (nonatomic, strong) CAGradientLayer *topCardGradientLayer;
@property (nonatomic, strong) CALayer *topCardGlowLayer;
@end

@implementation WalletHomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = HexColor(0xF5F5F5);
    BOOL isRootOfNav = (self.navigationController != nil && self.navigationController.viewControllers.firstObject == self);
    if (isRootOfNav) {
        [self rb_installAlarmsStyleMainTabNavigationBarWithLocalizedTitleKey:@"main_tabs_title_wallet"];
    } else {
        [self rb_installPlainCustomNavigationBarWithTitle:NSLocalizedString(@"main_tabs_title_wallet", nil)];
    }

    self.balanceHidden = NO;
    self.rb_walletBalanceFetchedOnce = NO;
    self.rb_walletAddressFetchedOnce = NO;
    self.fundPasswordHasSet = NO;
    self.ledgerList = [NSMutableArray array];
    self.billTabTitles = @[@"全部", @"充值", @"提现", @"转账", @"红包"];
    self.billTabTypes = @[@0, @1, @2, @3, @5];
    self.selectedBillTabIndex = 0;
    self.billMonth = [NSDate date];
    self.totalExpense = 0;
    self.totalIncome = 0;
    self.trxAddress = @"--";

    [self buildImTokenStyleContent];
    [self rb_applyCachedBalanceToLabel];
    [self rb_applyCachedTrxAddressToLabel];
    [self loadBalanceAndStatus];
    [self checkFundPasswordStatus];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if ([self rb_alarmsStyleMainTabNavigationBarIfInstalled]) {
        [self rb_alarmsStyleMainTabNavHostViewDidLayoutSubviews];
    }
    CGFloat w = self.view.bounds.size.width;
    CGFloat safeBottom = 0;
    CGFloat topInset = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = self.view.safeAreaInsets.bottom;
        topInset = self.view.safeAreaInsets.top;
    }
    _scrollView.frame = CGRectMake(0, topInset, w, CGRectGetHeight(self.view.bounds) - topInset);
    _scrollView.contentInset = UIEdgeInsetsMake(0, 0, safeBottom + 20 + self.rb_mainTabFabBottomInset, 0);

    CGFloat p = kPadding;
    CGFloat y = 16.f;
    CGFloat cardW = w - p * 2;

    CGFloat topCardH = 168.f;
    self.topCardView.frame = CGRectMake(p, y, cardW, topCardH);
    self.topCardGradientLayer.frame = self.topCardView.bounds;
    if (self.topCardGlowLayer) {
        CGFloat glowSize = MIN(cardW, topCardH) * 0.95f;
        self.topCardGlowLayer.frame = CGRectMake(-glowSize * 0.35f, -glowSize * 0.45f, glowSize, glowSize);
    }
    self.subtitleLabel.frame = CGRectMake(16, 16, cardW - 32 - 60, 18);
    self.balanceLabel.frame = CGRectMake(16, 38, cardW - 32 - 36, 46);
    self.eyeButton.frame = CGRectMake(cardW - 16 - 36, 42, 36, 36);
    self.addressTitleLabel.frame = CGRectMake(16, 92, 120, 18);
    self.addressCopyButton.frame = CGRectMake(cardW - 16 - 54, 88, 54, 26);
    self.addressValueLabel.frame = CGRectMake(16, 112, cardW - 32 - 60, 22);
    self.balanceLoadingView.center = CGPointMake(cardW / 2, 58);
    y += topCardH + 14.f;

    CGFloat menuH = 92.f;
    self.menuSectionView.frame = CGRectMake(p, y, cardW, menuH);
    CGFloat itemW = cardW / 4.f;
    self.receiveButton.frame = CGRectMake(0, 0, itemW, menuH);
    self.transferButton.frame = CGRectMake(itemW, 0, itemW, menuH);
    self.swapButton.frame = CGRectMake(itemW * 2.f, 0, itemW, menuH);
    self.recordButton.frame = CGRectMake(itemW * 3.f, 0, itemW, menuH);
    for (UIButton *b in @[self.receiveButton, self.transferButton, self.swapButton, self.recordButton]) {
        UIImageView *iv = [b viewWithTag:9102];
        UILabel *t = (UILabel *)[b viewWithTag:9101];
        if (iv) {
            iv.frame = CGRectMake((itemW - 26) * 0.5f, 18, 26, 26);
        }
        if (t) {
            t.frame = CGRectMake(0, 54, itemW, 18);
        }
    }
    y += menuH + 14.f;

    CGFloat rowH = 68.f;
    CGFloat tokensH = 44.f + rowH * 3.f;
    self.tokensSectionView.frame = CGRectMake(p, y, cardW, tokensH);
    self.tokensTitleLabel.frame = CGRectMake(16, 0, cardW - 32, 44);
    CGFloat rowTop = 44.f;
    for (NSInteger i = 0; i < self.tokenRowViews.count; i++) {
        UIView *row = self.tokenRowViews[i];
        row.frame = CGRectMake(0, rowTop + rowH * (CGFloat)i, cardW, rowH);
        UIImageView *dot = (UIImageView *)[row viewWithTag:9201];
        UILabel *s = (UILabel *)[row viewWithTag:9202];
        UILabel *p = (UILabel *)[row viewWithTag:9205];
        UILabel *v = (UILabel *)[row viewWithTag:9203];
        UILabel *fiat = (UILabel *)[row viewWithTag:9206];
        UIView *sep = [row viewWithTag:9204];
        if (dot) dot.frame = CGRectMake(16, (rowH - 40.f) * 0.5f, 40, 40);
        if (s) s.frame = CGRectMake(16 + 36 + 12, 14, 140, 18);
        if (p) p.frame = CGRectMake(16 + 36 + 12, 38, 180, 18);
        if (v) v.frame = CGRectMake(cardW - 16 - 160, 12, 160, 20);
        if (fiat) fiat.frame = CGRectMake(cardW - 16 - 160, 38, 160, 18);
        if (sep) {
            sep.hidden = (i == self.tokenRowViews.count - 1);
            sep.frame = CGRectMake(16, rowH - 0.5f, cardW - 16, 0.5f);
        }
    }
    y += tokensH + 20.f;
    _scrollView.contentSize = CGSizeMake(w, y);
}

- (void)buildImTokenStyleContent
{
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scrollView.showsVerticalScrollIndicator = YES;
    _scrollView.backgroundColor = HexColor(0xF5F5F5);
    [self.view addSubview:_scrollView];

    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    card.backgroundColor = [UIColor clearColor];
    card.layer.cornerRadius = 16.f;
    card.clipsToBounds = YES;
    [_scrollView addSubview:card];
    self.topCardView = card;
    
    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors = @[ (id)HexColor(0xFF4D4F).CGColor, (id)HexColor(0xD60000).CGColor ];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint = CGPointMake(1, 1);
    g.cornerRadius = 16.f;
    [card.layer insertSublayer:g atIndex:0];
    self.topCardGradientLayer = g;
    
    CALayer *glow = [CALayer layer];
    glow.backgroundColor = [UIColor whiteColor].CGColor;
    glow.opacity = 0.22f;
    glow.cornerRadius = 120.f;
    [card.layer insertSublayer:glow above:g];
    self.topCardGlowLayer = glow;

    _balanceLabel = [[UILabel alloc] init];
    _balanceLabel.text = @"--";
    _balanceLabel.font = [UIFont systemFontOfSize:34 weight:UIFontWeightSemibold];
    _balanceLabel.textColor = [UIColor whiteColor];
    [card addSubview:_balanceLabel];

    _eyeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_eyeButton setImage:[UIImage systemImageNamed:@"eye"] forState:UIControlStateNormal];
    [_eyeButton setImage:[UIImage systemImageNamed:@"eye.slash"] forState:UIControlStateSelected];
    _eyeButton.tintColor = [UIColor whiteColor];
    [_eyeButton addTarget:self action:@selector(toggleBalanceVisible:) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:_eyeButton];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.text = @"总资产（CNY）";
    _subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    _subtitleLabel.textColor = [UIColor colorWithWhite:1 alpha:0.8];
    [card addSubview:_subtitleLabel];

    self.addressTitleLabel = [[UILabel alloc] init];
    self.addressTitleLabel.text = @"TRX 地址";
    self.addressTitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.addressTitleLabel.textColor = [UIColor colorWithWhite:1 alpha:0.7];
    [card addSubview:self.addressTitleLabel];

    self.addressValueLabel = [[UILabel alloc] init];
    self.addressValueLabel.text = @"--";
    if (@available(iOS 13.0, *)) {
        self.addressValueLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    } else {
        self.addressValueLabel.font = [UIFont systemFontOfSize:13];
    }
    self.addressValueLabel.textColor = [UIColor whiteColor];
    self.addressValueLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [card addSubview:self.addressValueLabel];

    self.addressCopyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.addressCopyButton setTitle:@"复制" forState:UIControlStateNormal];
    self.addressCopyButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [self.addressCopyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.addressCopyButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    self.addressCopyButton.layer.cornerRadius = 8.f;
    [self.addressCopyButton addTarget:self action:@selector(onTapCopyAddress) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.addressCopyButton];

    _balanceLoadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _balanceLoadingView.hidesWhenStopped = YES;
    _balanceLoadingView.color = [UIColor whiteColor];
    [card addSubview:_balanceLoadingView];

    UIView *menu = [[UIView alloc] initWithFrame:CGRectZero];
    menu.backgroundColor = [UIColor whiteColor];
    menu.layer.cornerRadius = 16.f;
    menu.clipsToBounds = YES;
    [_scrollView addSubview:menu];
    self.menuSectionView = menu;

    self.receiveButton = [self rb_walletMenuButtonWithTitle:@"收款" systemImage:@"qrcode" action:@selector(onTapReceive)];
    self.transferButton = [self rb_walletMenuButtonWithTitle:@"转账" systemImage:@"arrow.left.arrow.right" action:@selector(onTapTransfer)];
    self.swapButton = [self rb_walletMenuButtonWithTitle:@"闪对" systemImage:@"arrow.triangle.2.circlepath" action:@selector(onTapSwap)];
    self.recordButton = [self rb_walletMenuButtonWithTitle:@"记录" systemImage:@"list.bullet" action:@selector(onTapRecord)];
    [menu addSubview:self.receiveButton];
    [menu addSubview:self.transferButton];
    [menu addSubview:self.swapButton];
    [menu addSubview:self.recordButton];

    UIView *tokens = [[UIView alloc] initWithFrame:CGRectZero];
    tokens.backgroundColor = [UIColor whiteColor];
    tokens.layer.cornerRadius = 16.f;
    tokens.clipsToBounds = YES;
    [_scrollView addSubview:tokens];
    self.tokensSectionView = tokens;

    self.tokensTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.tokensTitleLabel.text = @"币种";
    self.tokensTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.tokensTitleLabel.textColor = HexColor(0x111827);
    [tokens addSubview:self.tokensTitleLabel];

    NSArray<NSString *> *symbols = @[@"TRX", @"USDT", @"CNY"];
    NSMutableArray *rows = [NSMutableArray array];
    NSMutableArray *vals = [NSMutableArray array];
    NSMutableArray *fiats = [NSMutableArray array];
    NSMutableArray *prices = [NSMutableArray array];
    for (NSInteger i = 0; i < symbols.count; i++) {
        UILabel *valueLabel = nil;
        UILabel *fiatLabel = nil;
        UILabel *priceLabel = nil;
        UIView *row = [self rb_walletTokenRowWithSymbol:symbols[i] valueLabel:&valueLabel fiatLabel:&fiatLabel priceLabel:&priceLabel];
        [tokens addSubview:row];
        [rows addObject:row];
        if (valueLabel) {
            [vals addObject:valueLabel];
        }
        if (fiatLabel) {
            [fiats addObject:fiatLabel];
        }
        if (priceLabel) {
            [prices addObject:priceLabel];
        }
    }
    self.tokenRowViews = rows;
    self.tokenValueLabels = vals;
    self.tokenFiatLabels = fiats;
    self.tokenPriceLabels = prices;
    [self rb_updateCnyTokenValueWithBalanceText:self.balanceLabel.text];
    [self rb_applyTokenUnitPricePlaceholders];
}

- (UIButton *)rb_walletMenuButtonWithTitle:(NSString *)title systemImage:(NSString *)systemImage action:(SEL)action
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.backgroundColor = [UIColor clearColor];
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectZero];
    t.text = title;
    t.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    t.textColor = HexColor(0x111827);
    t.textAlignment = NSTextAlignmentCenter;
    t.tag = 9101;
    [btn addSubview:t];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectZero];
    UIImage *img = [UIImage systemImageNamed:systemImage];
    iv.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    iv.tintColor = HexColor(0x2563EB);
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.tag = 9102;
    [btn addSubview:iv];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (UIView *)rb_walletTokenRowWithSymbol:(NSString *)symbol valueLabel:(UILabel * __autoreleasing *)valueLabelOut fiatLabel:(UILabel * __autoreleasing *)fiatLabelOut priceLabel:(UILabel * __autoreleasing *)priceLabelOut
{
    UIView *row = [[UIView alloc] initWithFrame:CGRectZero];
    row.backgroundColor = [UIColor clearColor];

    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectZero];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tag = 9201;
    if ([symbol isEqualToString:@"TRX"]) {
        icon.image = [UIImage imageNamed:@"wallet_token_trx"];
    } else if ([symbol isEqualToString:@"USDT"]) {
        icon.image = [UIImage imageNamed:@"wallet_token_usdt"];
    } else if ([symbol isEqualToString:@"CNY"]) {
        icon.image = [UIImage imageNamed:@"wallet_token_cny"];
    }
    [row addSubview:icon];

    UILabel *s = [[UILabel alloc] initWithFrame:CGRectZero];
    s.text = symbol;
    s.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    s.textColor = HexColor(0x111827);
    s.tag = 9202;
    [row addSubview:s];

    UILabel *p = [[UILabel alloc] initWithFrame:CGRectZero];
    p.text = @"¥--";
    p.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    p.textColor = HexColor(0x6B7280);
    p.tag = 9205;
    [row addSubview:p];
    if (priceLabelOut) {
        *priceLabelOut = p;
    }

    UILabel *qty = [[UILabel alloc] initWithFrame:CGRectZero];
    qty.text = @"--";
    qty.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    qty.textColor = HexColor(0x111827);
    qty.textAlignment = NSTextAlignmentRight;
    qty.tag = 9203;
    [row addSubview:qty];
    if (valueLabelOut) {
        *valueLabelOut = qty;
    }

    UILabel *fiat = [[UILabel alloc] initWithFrame:CGRectZero];
    fiat.text = @"¥--";
    fiat.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    fiat.textColor = HexColor(0x6B7280);
    fiat.textAlignment = NSTextAlignmentRight;
    fiat.tag = 9206;
    [row addSubview:fiat];
    if (fiatLabelOut) {
        *fiatLabelOut = fiat;
    }

    UIView *sep = [[UIView alloc] initWithFrame:CGRectZero];
    sep.backgroundColor = HexColor(0xE5E7EB);
    sep.tag = 9204;
    [row addSubview:sep];

    return row;
}

- (void)rb_applyTokenUnitPricePlaceholders
{
    if (self.tokenPriceLabels.count < 3) {
        return;
    }
    self.tokenPriceLabels[0].text = @"¥--";
    self.tokenPriceLabels[1].text = @"¥--";
    self.tokenPriceLabels[2].text = @"¥1.00";
}

- (void)buildLingqianContent
{
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scrollView.showsVerticalScrollIndicator = YES;
    _scrollView.backgroundColor = HexColor(0xF5F5F5);
    [self.view addSubview:_scrollView];

    CGFloat w = self.view.bounds.size.width;
    CGFloat p = kPadding;

    // 上方区域：浅绿色圆角卡片（内含 我的零钱/财付通、余额、收益文案、充值/提现）
    UIView *topSection = [[UIView alloc] initWithFrame:CGRectZero];
    topSection.backgroundColor = HexColor(0xDCF4E6);
    topSection.layer.cornerRadius = 16;
    topSection.clipsToBounds = YES;
    [_scrollView addSubview:topSection];

    UILabel *lingqianTitle = [[UILabel alloc] init];
    lingqianTitle.text = @"我的零钱";
    lingqianTitle.font = [UIFont systemFontOfSize:14];
    lingqianTitle.textColor = HexColor(0x666666);
    lingqianTitle.tag = 8001;
    [topSection addSubview:lingqianTitle];

    UIImageView *caifutongLogo = [[UIImageView alloc] init];
    caifutongLogo.image = [UIImage imageNamed:@"caifutong_logo"];
    caifutongLogo.contentMode = UIViewContentModeScaleAspectFit;
    caifutongLogo.tag = 8002;
    [topSection addSubview:caifutongLogo];

    _balanceLabel = [[UILabel alloc] init];
    _balanceLabel.text = @"¥0.00";
    _balanceLabel.font = [UIFont systemFontOfSize:kBalanceFontSize weight:UIFontWeightBold];
    _balanceLabel.textColor = HexColor(0x333333);
    [topSection addSubview:_balanceLabel];

    _eyeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_eyeButton setImage:[UIImage systemImageNamed:@"eye"] forState:UIControlStateNormal];
    [_eyeButton setImage:[UIImage systemImageNamed:@"eye.slash"] forState:UIControlStateSelected];
    _eyeButton.tintColor = HexColor(0x555555);
    [_eyeButton addTarget:self action:@selector(toggleBalanceVisible:) forControlEvents:UIControlEventTouchUpInside];
    [topSection addSubview:_eyeButton];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.text = @"转入零钱通赚收益 七日年化2.50% ";
    _subtitleLabel.font = [UIFont systemFontOfSize:13];
    _subtitleLabel.textColor = HexColor(0x333333);
    [topSection addSubview:_subtitleLabel];

    _rechargeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_rechargeButton setTitle:@"充值" forState:UIControlStateNormal];
    _rechargeButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    _rechargeButton.backgroundColor = HexColor(0x07C160);
    [_rechargeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _rechargeButton.layer.cornerRadius = 8;
    [_rechargeButton addTarget:self action:@selector(onRechargeTapped) forControlEvents:UIControlEventTouchUpInside];
    [topSection addSubview:_rechargeButton];

    _withdrawButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_withdrawButton setTitle:@"提现" forState:UIControlStateNormal];
    _withdrawButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    _withdrawButton.backgroundColor = HexColor(0x06AD56);
    [_withdrawButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _withdrawButton.layer.cornerRadius = 8;
    [_withdrawButton addTarget:self action:@selector(onWithdrawTapped) forControlEvents:UIControlEventTouchUpInside];
    [topSection addSubview:_withdrawButton];

    _balanceLoadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [topSection addSubview:_balanceLoadingView];

    // 服务入口：四个独立白色圆角方框，容器内图标居中、文字在下方
    _serviceSectionView = [[UIView alloc] initWithFrame:CGRectZero];
    _serviceSectionView.backgroundColor = [UIColor clearColor];
    [_scrollView addSubview:_serviceSectionView];

    NSArray *serviceTitles = @[@"银行卡", @"亲属卡", @"支付分", @"安全保障"];
    NSArray *serviceIconNames = @[@"service_bankcard", @"service_relative_card", @"service_pay_score", @"service_safety"];
    NSMutableArray *serviceBtns = [NSMutableArray array];
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 5000 + i;
        btn.backgroundColor = [UIColor whiteColor];
        btn.layer.cornerRadius = 12;
        btn.clipsToBounds = YES;
        [btn addTarget:self action:@selector(onServiceAction:) forControlEvents:UIControlEventTouchUpInside];

        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.tag = 5100 + i;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        UIImage *iconImg = [UIImage imageNamed:serviceIconNames[i]];
        if (!iconImg && @available(iOS 13.0, *)) {
            NSArray *fallbackNames = @[@"creditcard", @"arrow.triangle.2.circlepath", @"star.circle", @"checkmark.shield"];
            iconImg = [[UIImage systemImageNamed:fallbackNames[i]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            iconView.tintColor = HexColor(0x444444);
        }
        iconView.image = iconImg;
        [btn addSubview:iconView];

        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.tag = 5200 + i;
        titleLabel.text = serviceTitles[i];
        titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        titleLabel.textColor = HexColor(0x333333);
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.numberOfLines = 1;
        [_serviceSectionView addSubview:titleLabel];

        [_serviceSectionView addSubview:btn];
        [serviceBtns addObject:btn];
    }
    _serviceButtons = [serviceBtns copy];

    // 账单区
    _billTitleLabel = [[UILabel alloc] init];
    _billTitleLabel.text = @"账单记录";
    _billTitleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    _billTitleLabel.textColor = HexColor(0x333333);
    [_scrollView addSubview:_billTitleLabel];

    _billTabsScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _billTabsScrollView.showsHorizontalScrollIndicator = NO;
    [_scrollView addSubview:_billTabsScrollView];
    CGFloat tabX = 0;
    for (NSInteger i = 0; i < _billTabTitles.count; i++) {
        UIButton *tabBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        tabBtn.tag = 6000 + i;
        [tabBtn setTitle:_billTabTitles[i] forState:UIControlStateNormal];
        tabBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [tabBtn setTitleColor:HexColor(0x999999) forState:UIControlStateNormal];
        [tabBtn setTitleColor:HexColor(0x333333) forState:UIControlStateSelected];
        [tabBtn sizeToFit];
        tabBtn.frame = CGRectMake(tabX, 8, tabBtn.bounds.size.width + 24, 24);
        tabX = CGRectGetMaxX(tabBtn.frame);
        [tabBtn addTarget:self action:@selector(onBillTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_billTabsScrollView addSubview:tabBtn];
        if (i == 0) tabBtn.selected = YES;
    }
    _billTabUnderlineView = [[UIView alloc] init];
    _billTabUnderlineView.backgroundColor = HexColor(0x07C160);
    _billTabUnderlineView.layer.cornerRadius = 1;
    [_billTabsScrollView addSubview:_billTabUnderlineView];

    NSDateFormatter *fm = [[NSDateFormatter alloc] init];
    fm.dateFormat = @"yyyy年M月";
    _monthButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_monthButton setTitle:[fm stringFromDate:_billMonth] forState:UIControlStateNormal];
    [_monthButton setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
    _monthButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    if (@available(iOS 13.0, *)) {
        [_monthButton setImage:[UIImage systemImageNamed:@"chevron.down"] forState:UIControlStateNormal];
        _monthButton.tintColor = HexColor(0x666666);
    }
    [_monthButton addTarget:self action:@selector(onMonthTapped) forControlEvents:UIControlEventTouchUpInside];
    [_scrollView addSubview:_monthButton];

    _statisticsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_statisticsButton setTitle:@"统计 >" forState:UIControlStateNormal];
    [_statisticsButton setTitleColor:HexColor(0x07C160) forState:UIControlStateNormal];
    _statisticsButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [_statisticsButton addTarget:self action:@selector(onStatisticsTapped) forControlEvents:UIControlEventTouchUpInside];
    [_scrollView addSubview:_statisticsButton];

    _billSummaryContainerView = [[UIView alloc] init];
    _billSummaryContainerView.backgroundColor = [UIColor clearColor];
    [_scrollView addSubview:_billSummaryContainerView];

    _billSummaryInnerView = [[UIView alloc] init];
    _billSummaryInnerView.backgroundColor = [UIColor whiteColor];
    [_billSummaryContainerView addSubview:_billSummaryInnerView];

    _expenseCardView = [[UIView alloc] init];
    _expenseCardView.backgroundColor = HexColor(0xFFF3E0);
    [_billSummaryInnerView addSubview:_expenseCardView];
    UILabel *expenseTitle = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, 120, 20)];
    expenseTitle.text = @"↑ 支出";
    expenseTitle.font = [UIFont systemFontOfSize:13];
    expenseTitle.textColor = HexColor(0xE65100);
    [_expenseCardView addSubview:expenseTitle];
    _expenseCardLabel = [[UILabel alloc] init];
    _expenseCardLabel.text = @"¥ 0";
    _expenseCardLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    _expenseCardLabel.textColor = HexColor(0x333333);
    [_expenseCardView addSubview:_expenseCardLabel];

    _incomeCardView = [[UIView alloc] init];
    _incomeCardView.backgroundColor = HexColor(0xE9F3EE);
    [_billSummaryInnerView addSubview:_incomeCardView];
    UILabel *incomeTitle = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, 120, 20)];
    incomeTitle.text = @"↓ 收入";
    incomeTitle.font = [UIFont systemFontOfSize:13];
    incomeTitle.textColor = HexColor(0x07C160);
    [_incomeCardView addSubview:incomeTitle];
    _incomeCardLabel = [[UILabel alloc] init];
    _incomeCardLabel.text = @"¥ 0";
    _incomeCardLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    _incomeCardLabel.textColor = HexColor(0x333333);
    [_incomeCardView addSubview:_incomeCardLabel];

    _billTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _billTableView.delegate = self;
    _billTableView.dataSource = self;
    _billTableView.scrollEnabled = NO;
    _billTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _billTableView.separatorColor = HexColor(0xEEEEEE);
    _billTableView.backgroundColor = [UIColor whiteColor];
    [_scrollView addSubview:_billTableView];
}

- (void)onRechargeTapped
{
    WalletRechargeViewController *vc = [[WalletRechargeViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onWithdrawTapped
{
    WalletWithdrawViewController *vc = [[WalletWithdrawViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onTapReceive
{
    WalletReceiveCodeViewController *vc = [[WalletReceiveCodeViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onTapTransfer
{
    WalletTransferViewController *vc = [[WalletTransferViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onTapSwap
{
    [BasicTool showUserDefintToast:@"敬请期待" view:self.view atHide:nil];
}

- (void)onTapRecord
{
    WalletLedgerViewController *vc = [[WalletLedgerViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onTapCopyAddress
{
    NSString *addr = self.trxAddress;
    if (addr.length == 0 || [addr isEqualToString:@"--"]) {
        [BasicTool showUserDefintToast:@"地址为空" view:self.view atHide:nil];
        return;
    }
    [UIPasteboard generalPasteboard].string = addr;
    [BasicTool showUserDefintToast:@"地址已复制" view:self.view atHide:nil];
}

- (void)onServiceAction:(UIButton *)sender
{
    NSInteger i = sender.tag - 5000;
    if (i == 0) {
        WalletCardWalletViewController *vc = [[WalletCardWalletViewController alloc] init];
        vc.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:vc animated:YES];
    } else if (i == 3) {
        [self showWalletMoreMenu];
    } else {
        [BasicTool showUserDefintToast:@"敬请期待" view:self.view atHide:nil];
    }
}

- (void)onBillTabTapped:(UIButton *)sender
{
    NSInteger idx = sender.tag - 6000;
    _selectedBillTabIndex = idx;
    for (UIView *v in _billTabsScrollView.subviews) {
        if ([v isKindOfClass:[UIButton class]]) {
            ((UIButton *)v).selected = (v.tag == sender.tag);
        }
    }
    [self loadBillData];
}

- (void)onMonthTapped
{
    __weak typeof(self) wself = self;
    [MonthYearPickerHelper showInView:self.view currentDate:_billMonth minYear:2024 completion:^(NSDate * _Nullable selectedDate) {
        if (!selectedDate || !wself) return;
        wself.billMonth = selectedDate;
        NSDateFormatter *fm = [[NSDateFormatter alloc] init];
        fm.dateFormat = @"yyyy年M月";
        [wself.monthButton setTitle:[fm stringFromDate:wself.billMonth] forState:UIControlStateNormal];
        [wself loadBillData];
    }];
}

- (void)onStatisticsTapped
{
    WalletLedgerViewController *vc = [[WalletLedgerViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)loadBillData
{
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSInteger year = [cal component:NSCalendarUnitYear fromDate:_billMonth];
    NSInteger month = [cal component:NSCalendarUnitMonth fromDate:_billMonth];

    NSInteger type = 0;
    if (_selectedBillTabIndex < _billTabTypes.count) {
        type = [_billTabTypes[_selectedBillTabIndex] integerValue];
    }
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"page": @1,
        @"page_size": @20,
        @"year": @(year),
        @"month": @(month)
    }];
    // 转账(3)、红包(5)不传类型参数，与「全部」一样拉全量，由客户端按类型过滤，避免服务端不支持多类型时返回空
    if (type > 0 && type != 3 && type != 5) {
        params[@"transaction_type"] = @(type);
    }
    __weak typeof(self) wself = self;
    NSInteger requestedType = type;
    [[HttpRestHelper sharedInstance] submitWalletLedgerListWithParams:params complete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && data && [data isKindOfClass:[NSDictionary class]]) {
                NSArray *list = data[@"list"];
                if ([list isKindOfClass:[NSArray class]]) {
                    // 若服务端未按类型筛选，客户端再过滤一次：转账只保留 3、4，红包只保留 5、6、7
                    NSArray *filtered = list;
                    if (requestedType == 3) {
                        filtered = [list filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, id _) {
                            NSInteger t = item[@"transaction_type"] ? [[item[@"transaction_type"] description] integerValue] : 0;
                            return (t == 3 || t == 4);
                        }]];
                    } else if (requestedType == 5) {
                        filtered = [list filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, id _) {
                            NSInteger t = item[@"transaction_type"] ? [[item[@"transaction_type"] description] integerValue] : 0;
                            return (t == 5 || t == 6 || t == 7);
                        }]];
                    }
                    [wself.ledgerList removeAllObjects];
                    [wself.ledgerList addObjectsFromArray:filtered];
                    wself.totalExpense = 0;
                    wself.totalIncome = 0;
                    for (NSDictionary *item in wself.ledgerList) {
                        double amount = 0;
                        if (item[@"amount"]) amount = [[item[@"amount"] description] doubleValue];
                        else if (item[@"amount_cent"]) amount = [item[@"amount_cent"] longLongValue] / 100.0;
                        NSInteger txType = item[@"transaction_type"] ? [[item[@"transaction_type"] description] integerValue] : 0;
                        BOOL isIncome = [wself isIncomeTransactionType:txType amount:amount];
                        if (isIncome) wself.totalIncome += fabs(amount);
                        else wself.totalExpense += fabs(amount);
                    }
                    wself.expenseCardLabel.text = [NSString stringWithFormat:@"¥ %@", [wself formatBillAmount:wself.totalExpense]];
                    wself.incomeCardLabel.text = [NSString stringWithFormat:@"¥ %@", [wself formatBillAmount:wself.totalIncome]];
                }
            }
            [wself.billTableView reloadData];
            [wself.view setNeedsLayout];
        });
    } hudParentView:nil];
}

- (NSString *)formatBillAmount:(double)amount
{
    if (amount >= 10000) return [NSString stringWithFormat:@"%.2f万", amount / 10000];
    return [NSString stringWithFormat:@"%.2f", amount];
}

- (BOOL)isIncomeTransactionType:(NSInteger)transactionType amount:(double)amount
{
    switch (transactionType) {
        case 1: return YES;
        case 2: return NO;
        case 3: return NO;
        case 4: return YES;
        case 5: return NO;
        case 6: return YES;
        case 7: return YES;
        default: return amount >= 0;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == _billTableView) return _ledgerList.count;
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kBillRowHeight;
}

- (NSString *)formatLedgerTime:(id)createTimeVal
{
    if (!createTimeVal) return @"";
    NSTimeInterval ts = 0;
    if ([createTimeVal isKindOfClass:[NSNumber class]]) {
        ts = [createTimeVal doubleValue];
    } else {
        ts = [[createTimeVal description] doubleValue];
    }
    if (ts <= 0) return @"";
    if (ts > 1e12) ts /= 1000.0;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:ts];
    NSDateFormatter *fm = [[NSDateFormatter alloc] init];
    fm.dateFormat = @"M月d日 HH:mm";
    return [fm stringFromDate:date];
}

- (NSString *)ledgerRelatedPartyName:(NSDictionary *)item relatedUid:(NSString *)relatedUid txType:(NSInteger)txType
{
    NSString *name = [item[@"related_user_nickname"] description];
    if (name.length > 0) return name;
    if (txType == 5 || txType == 6) {
        NSString *receiverName = [item[@"receiver_nickname"] description];
        NSString *senderName = [item[@"sender_nickname"] description];
        if (txType == 5 && receiverName.length > 0) return receiverName;
        if (txType == 6 && senderName.length > 0) return senderName;
    }
    if (relatedUid.length > 0) {
        FriendsListProvider *flp = [[IMClientManager sharedInstance] getFriendsListProvider];
        UserEntity *friendInfo = [flp getFriendInfoByUid2:relatedUid];
        if (friendInfo) return [friendInfo getNickNameWithRemark];
    }
    return @"对方";
}

- (NSString *)ledgerTitleForItem:(NSDictionary *)item txType:(NSInteger)txType relatedUid:(NSString *)relatedUid
{
    NSString *name = [self ledgerRelatedPartyName:item relatedUid:relatedUid txType:txType];
    if (txType == 3) return [NSString stringWithFormat:@"转账-转给%@", name];
    if (txType == 4) return [NSString stringWithFormat:@"转账-来自%@", name];
    if (txType == 5) {
        NSString *groupId = [item[@"group_id"] description];
        NSInteger receiverType = item[@"receiver_type"] ? [[item[@"receiver_type"] description] integerValue] : 0;
        if (receiverType == 2 || (groupId && groupId.length > 0)) return @"精聊Chat红包-发出群红包";
        return [NSString stringWithFormat:@"精聊Chat红包-发给%@", name];
    }
    if (txType == 6) return [NSString stringWithFormat:@"精聊Chat红包-来自%@", name];
    if (txType == 7) return @"精聊Chat红包-红包退回";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _billTableView) {
        static NSString *cid = @"bill_cell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            cell.backgroundColor = [UIColor whiteColor];
        }
        NSDictionary *item = _ledgerList[indexPath.row];
        NSInteger txType = item[@"transaction_type"] ? [[item[@"transaction_type"] description] integerValue] : 0;
        double amount = 0;
        if (item[@"amount"]) amount = [[item[@"amount"] description] doubleValue];
        else if (item[@"amount_cent"]) amount = [item[@"amount_cent"] longLongValue] / 100.0;
        BOOL isIncome = [self isIncomeTransactionType:txType amount:amount];
        NSString *typeName = @"交易";
        if (txType == 1) typeName = @"充值";
        else if (txType == 2) typeName = @"提现";
        else if (txType == 3 || txType == 4) typeName = @"转账";
        else if (txType >= 5 && txType <= 7) typeName = @"红包";
        NSString *relatedUid = [item[@"related_user_uid"] description];
        if (relatedUid.length == 0 && (txType == 5 || txType == 6)) {
            NSString *receiverUid = [item[@"receiver_uid"] description];
            NSString *senderUid = [item[@"sender_uid"] description];
            if (txType == 5 && receiverUid.length > 0) relatedUid = receiverUid;
            else if (txType == 6 && senderUid.length > 0) relatedUid = senderUid;
        }
        NSString *titleText = nil;
        if (txType == 3 || txType == 4 || (txType >= 5 && txType <= 7)) {
            titleText = [self ledgerTitleForItem:item txType:txType relatedUid:relatedUid];
        }
        if (!titleText.length) titleText = item[@"remark"] ?: item[@"description"] ?: typeName;
        id createTimeVal = item[@"create_time"] ?: item[@"created_at"];
        NSString *timeStr = [self formatLedgerTime:createTimeVal];

        CGFloat w = self.view.bounds.size.width;
        if (w <= 0) w = 375;
        const CGFloat avatarSize = 40.f;
        const CGFloat leftPad = kPadding;
        const CGFloat avatarTextGap = 12.f;

        UIImageView *avatarView = (UIImageView *)[cell.contentView viewWithTag:9002];
        if (!avatarView) {
            avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(leftPad, (kBillRowHeight - avatarSize) / 2, avatarSize, avatarSize)];
            avatarView.tag = 9002;
            avatarView.contentMode = UIViewContentModeScaleAspectFill;
            avatarView.clipsToBounds = YES;
            avatarView.layer.cornerRadius = 8.f;
            avatarView.backgroundColor = HexColor(0xEEEEEE);
            [cell.contentView addSubview:avatarView];
        }
        avatarView.frame = CGRectMake(leftPad, (kBillRowHeight - avatarSize) / 2, avatarSize, avatarSize);
        if (txType >= 5 && txType <= 7) {
            avatarView.image = [UIImage imageNamed:@"wallet_bill_red_packet"];
            avatarView.contentMode = UIViewContentModeScaleAspectFit;
        } else {
            avatarView.contentMode = UIViewContentModeScaleAspectFill;
            if (relatedUid.length > 0) {
                avatarView.image = nil;
                __weak UIImageView *wAvatar = avatarView;
                NSString *avatarUid = relatedUid;
                [FileDownloadHelper loadUserAvatarWithUID:avatarUid logTag:@"WalletBill" complete:^(BOOL sucess, UIImage *img) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (img && wAvatar) wAvatar.image = img;
                    });
                } donotLoadFromDisk:NO];
            } else {
                avatarView.image = [UIImage imageNamed:@"default_avatar_60"];
            }
        }

        UILabel *amountL = (UILabel *)[cell.contentView viewWithTag:9001];
        if (!amountL) {
            amountL = [[UILabel alloc] init];
            amountL.tag = 9001;
            amountL.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
            [cell.contentView addSubview:amountL];
        }
        amountL.text = isIncome ? [NSString stringWithFormat:@"+%.2f", fabs(amount)] : [NSString stringWithFormat:@"-%.2f", fabs(amount)];
        amountL.textColor = isIncome ? HexColor(0x34C759) : HexColor(0x333333);
        [amountL sizeToFit];
        CGFloat amountW = amountL.bounds.size.width;
        amountL.frame = CGRectMake(w - amountW - kPadding, (kBillRowHeight - amountL.bounds.size.height) / 2, amountW, amountL.bounds.size.height);

        CGFloat textLeft = leftPad + avatarSize + avatarTextGap;
        CGFloat textW = w - textLeft - amountW - kPadding - 8.f;

        UILabel *titleL = (UILabel *)[cell.contentView viewWithTag:9003];
        if (!titleL) {
            titleL = [[UILabel alloc] init];
            titleL.tag = 9003;
            titleL.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
            titleL.textColor = HexColor(0x333333);
            titleL.lineBreakMode = NSLineBreakByTruncatingTail;
            titleL.numberOfLines = 1;
            [cell.contentView addSubview:titleL];
        }
        titleL.text = titleText;
        titleL.frame = CGRectMake(textLeft, 12, textW, 20);

        UILabel *timeL = (UILabel *)[cell.contentView viewWithTag:9004];
        if (!timeL) {
            timeL = [[UILabel alloc] init];
            timeL.tag = 9004;
            timeL.font = [UIFont systemFontOfSize:12];
            timeL.textColor = HexColor(0x999999);
            [cell.contentView addSubview:timeL];
        }
        timeL.text = timeStr;
        timeL.frame = CGRectMake(textLeft, 34, textW, 18);

        cell.textLabel.text = nil;
        cell.detailTextLabel.text = nil;
        
        return cell;
    }
    return [[UITableViewCell alloc] init];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (tableView == _billTableView) {
            WalletLedgerViewController *vc = [[WalletLedgerViewController alloc] init];
            vc.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
    __weak typeof(self) wself = self;
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{
        [wself rb_applyCachedTrxAddressToLabel];
        [wself loadBalanceAndStatus];
        [wself loadBillData];
        [wself checkFundPasswordStatus];
    });
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([self rb_alarmsStyleMainTabNavigationBarIfInstalled]) {
        [self rb_alarmsStyleMainTabNavHostViewDidAppear:animated];
    } else {
        [self rb_plainCustomNavHostViewDidAppear:animated];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if ([self rb_alarmsStyleMainTabNavigationBarIfInstalled]) {
        [self rb_alarmsStyleMainTabNavHostViewWillDisappear:animated];
    } else {
        [self rb_plainCustomNavHostViewWillDisappear:animated];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (![self rb_alarmsStyleMainTabNavigationBarIfInstalled]) {
        [self rb_plainCustomNavHostViewDidDisappear:animated];
    }
}

- (NSString *)rb_localUserUid
{
    return [[IMClientManager sharedInstance] localUserInfo].user_uid;
}

- (NSString *)rb_readCachedBalanceDisplayText
{
    NSString *key = RBCachedWalletBalanceKey([self rb_localUserUid]);
    if (key.length == 0) {
        return nil;
    }
    return [[NSUserDefaults standardUserDefaults] stringForKey:key];
}

- (NSString *)rb_readCachedTrxAddress
{
    NSString *key = RBCachedWalletTrxAddressKey([self rb_localUserUid]);
    if (key.length == 0) {
        return nil;
    }
    return [[NSUserDefaults standardUserDefaults] stringForKey:key];
}

- (void)rb_saveCachedBalanceDisplayText:(NSString *)text
{
    if (text.length == 0) {
        return;
    }
    NSString *key = RBCachedWalletBalanceKey([self rb_localUserUid]);
    if (key.length == 0) {
        return;
    }
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:text forKey:key];
    [ud synchronize];
}

- (void)rb_saveCachedTrxAddress:(NSString *)text
{
    if (text.length == 0) {
        return;
    }
    NSString *key = RBCachedWalletTrxAddressKey([self rb_localUserUid]);
    if (key.length == 0) {
        return;
    }
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:text forKey:key];
    [ud synchronize];
}

- (void)rb_applyCachedBalanceToLabel
{
    if (self.balanceHidden) {
        return;
    }
    NSString *cached = [self rb_readCachedBalanceDisplayText];
    if (cached.length == 0) {
        return;
    }
    self.balanceLabel.text = cached;
    self.rb_walletBalanceFetchedOnce = YES;
    [self rb_updateCnyTokenValueWithBalanceText:cached];
}

- (void)rb_applyCachedTrxAddressToLabel
{
    NSString *cached = [self rb_readCachedTrxAddress];
    if (cached.length == 0) {
        return;
    }
    self.trxAddress = cached;
    self.addressValueLabel.text = cached;
}

- (void)rb_updateCnyTokenValueWithBalanceText:(NSString *)balanceText
{
    if (self.tokenValueLabels.count < 3 || self.tokenFiatLabels.count < 3) {
        return;
    }
    UILabel *qty = self.tokenValueLabels[2];
    UILabel *fiat = self.tokenFiatLabels[2];
    if (!qty || !fiat) {
        return;
    }
    NSString *fiatText = balanceText.length > 0 ? balanceText : @"¥--";
    NSString *qtyText = fiatText;
    if ([qtyText hasPrefix:@"¥"]) {
        qtyText = [qtyText substringFromIndex:1];
    }
    qtyText = [qtyText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (qtyText.length == 0) {
        qtyText = @"--";
    }
    qty.text = qtyText;
    fiat.text = fiatText;
}

- (void)loadBalanceAndStatus
{
    BOOL showBalanceSpinner = !self.rb_walletBalanceFetchedOnce;
    if (showBalanceSpinner) {
        [_balanceLoadingView startAnimating];
    }
    // 非首拉：不挂全屏网络等待，避免每次点进「钱包」整页蒙层闪一下
    UIView *hudHost = self.rb_walletBalanceFetchedOnce ? nil : self.view;

    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletBalanceWithComplete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (showBalanceSpinner) {
                [wself.balanceLoadingView stopAnimating];
            }
            wself.rb_walletBalanceFetchedOnce = YES;
            if (wself.balanceHidden) {
                wself.balanceLabel.text = @"****";
                return;
            }
            if (sucess && data) {
                id pb = data[@"available_balance"] ?: data[@"balance"] ?: data[@"platform_balance"] ?: data[@"platformBalance"];
                NSString *cny = ([[pb description] length] > 0) ? [pb description] : @"0.00";
                NSString *balanceText = [NSString stringWithFormat:@"¥%@", cny];
                wself.balanceLabel.text = balanceText;
                [wself rb_saveCachedBalanceDisplayText:balanceText];
                [wself rb_updateCnyTokenValueWithBalanceText:balanceText];

                if (wself.tokenPriceLabels.count >= 3) {
                    wself.tokenPriceLabels[0].text = @"--";
                    wself.tokenPriceLabels[1].text = @"--";
                    wself.tokenPriceLabels[2].text = @"¥1.00";
                }
                if (wself.tokenFiatLabels.count >= 3) {
                    wself.tokenFiatLabels[0].text = @"--";
                    wself.tokenFiatLabels[1].text = @"--";
                    NSDecimalNumber *cnyN = [NSDecimalNumber decimalNumberWithString:[cny stringByReplacingOccurrencesOfString:@"," withString:@""]];
                    wself.tokenFiatLabels[2].text = (cnyN && ![cnyN isEqualToNumber:[NSDecimalNumber notANumber]]) ? RBWalletFormatCNY(cnyN) : balanceText;
                }
            }

            if (!wself.rb_walletAddressFetchedOnce || wself.trxAddress.length == 0 || [wself.trxAddress isEqualToString:@"--"]) {
                [[HttpRestHelper sharedInstance] submitTrxWalletDepositAddressWithComplete:^(BOOL sucess2, NSDictionary *data2) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!(sucess2 && data2)) return;
                        NSString *addr2 = [data2[@"trx_address"] description];
                        if (addr2.length == 0) addr2 = [data2[@"trxAddress"] description];
                        if (addr2.length == 0) return;
                        wself.rb_walletAddressFetchedOnce = YES;
                        wself.trxAddress = addr2;
                        wself.addressValueLabel.text = addr2;
                        [wself rb_saveCachedTrxAddress:addr2];
                    });
                } hudParentView:nil];
            }
            
            [[HttpRestHelper sharedInstance] submitTrxWalletAssetBalanceWithComplete:^(BOOL sucess3, NSDictionary *data3) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!(sucess3 && [data3 isKindOfClass:[NSDictionary class]])) return;
                    NSDictionary *trxObj = [data3[@"trx"] isKindOfClass:[NSDictionary class]] ? data3[@"trx"] : nil;
                    NSDictionary *usdtObj = [data3[@"usdt"] isKindOfClass:[NSDictionary class]] ? data3[@"usdt"] : nil;
                    id trxV = trxObj[@"available_balance"] ?: trxObj[@"balance"];
                    id usdtV = usdtObj[@"available_balance"] ?: usdtObj[@"balance"];
                    NSString *trx = ([[trxV description] length] > 0) ? [trxV description] : @"";
                    NSString *usdt = ([[usdtV description] length] > 0) ? [usdtV description] : @"";
                    if (wself.tokenValueLabels.count >= 2) {
                        wself.tokenValueLabels[0].text = (trx.length > 0 ? trx : @"--");
                        wself.tokenValueLabels[1].text = (usdt.length > 0 ? usdt : @"--");
                    }
                });
            } hudParentView:nil];
        });
    } hudParentView:hudHost];
}

- (void)checkFundPasswordStatus
{
    [self checkFundPasswordStatusWithCompletion:nil];
}

- (void)checkFundPasswordStatusWithCompletion:(void (^)(void))completion
{
    // 方案1：尝试使用 action 36 查询资金密码状态
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletCheckFundPasswordStatusWithComplete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL oldState = wself.fundPasswordHasSet;
            BOOL detected = NO;
            
            if (sucess && data && [data isKindOfClass:[NSDictionary class]]) {
                id isSetValue = data[@"is_set"];
                NSLog(@"【资金密码状态检测-方案1】返回：success=%d, data=%@, is_set原始值=%@ (类型:%@)", sucess, data, isSetValue, NSStringFromClass([isSetValue class]));
                
                // 处理字符串和数字两种情况
                BOOL isSet = NO;
                if (isSetValue == nil) {
                    NSLog(@"【资金密码状态检测-方案1】is_set 为 nil");
                    isSet = NO;
                } else if ([isSetValue isKindOfClass:[NSString class]]) {
                    NSString *isSetStr = (NSString *)isSetValue;
                    isSet = [isSetStr isEqualToString:@"1"] || [isSetStr isEqualToString:@"true"] || [isSetStr.lowercaseString isEqualToString:@"yes"];
                    NSLog(@"【资金密码状态检测-方案1】字符串类型：isSetStr=%@, isSet=%d", isSetStr, isSet);
                } else if ([isSetValue isKindOfClass:[NSNumber class]]) {
                    NSNumber *isSetNum = (NSNumber *)isSetValue;
                    isSet = [isSetNum intValue] == 1 || [isSetNum boolValue] == YES;
                    NSLog(@"【资金密码状态检测-方案1】数字类型：isSetNum=%@, intValue=%d, boolValue=%d, isSet=%d", isSetNum, [isSetNum intValue], [isSetNum boolValue], isSet);
                } else {
                    NSString *isSetStr = [isSetValue description];
                    isSet = [isSetStr isEqualToString:@"1"] || [isSetStr intValue] == 1 || [isSetStr.lowercaseString isEqualToString:@"true"] || [isSetStr.lowercaseString isEqualToString:@"yes"];
                    NSLog(@"【资金密码状态检测-方案1】其他类型：isSetStr=%@, isSet=%d", isSetStr, isSet);
                }
                
                if (isSetValue != nil) {
                    wself.fundPasswordHasSet = isSet;
                    detected = YES;
                    NSLog(@"【资金密码状态-方案1】更新：oldState=%d -> newState=%d (isSet=%d, isSetValue=%@)", oldState, wself.fundPasswordHasSet, isSet, isSetValue);
                }
            } else {
                NSLog(@"【资金密码状态检测-方案1】接口失败：success=%d, data=%@ (类型:%@)，尝试方案2", sucess, data, NSStringFromClass([data class]));
            }
            
            // 方案2：如果方案1失败，使用验证密码接口（action 22）来推断
            if (!detected) {
                NSLog(@"【资金密码状态检测-方案2】使用验证密码接口推断状态");
                // 使用一个错误的密码来验证，如果返回 "0" 表示未设置，返回其他值（如 JSON）表示已设置
                [[HttpRestHelper sharedInstance] submitWalletVerifyFundPassword:@"000000" complete:^(BOOL sucess, NSString *msg) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        BOOL isSet = NO;
                        if (sucess && msg) {
                            NSString *trimmed = [msg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            if ([trimmed isEqualToString:@"0"]) {
                                // 返回 "0" 表示未设置
                                isSet = NO;
                                NSLog(@"【资金密码状态检测-方案2】返回\"0\"，判断为未设置");
                            } else if ([trimmed isEqualToString:@"1"]) {
                                // 返回 "1" 表示验证成功（已设置且密码正确，但这里用的是错误密码，所以不应该出现）
                                isSet = YES;
                                NSLog(@"【资金密码状态检测-方案2】返回\"1\"，判断为已设置");
                            } else {
                                // 返回 JSON 或其他值，表示已设置但验证失败
                                isSet = YES;
                                NSLog(@"【资金密码状态检测-方案2】返回其他值（%@），判断为已设置", trimmed);
                            }
                        } else {
                            // 接口失败，默认认为未设置
                            isSet = NO;
                            NSLog(@"【资金密码状态检测-方案2】接口失败，默认未设置");
                        }
                        
                        wself.fundPasswordHasSet = isSet;
                        NSLog(@"【资金密码状态-方案2】更新：oldState=%d -> newState=%d", oldState, wself.fundPasswordHasSet);
                        
                        // 强制触发 KVO（如果有监听）
                        [wself willChangeValueForKey:@"fundPasswordHasSet"];
                        [wself didChangeValueForKey:@"fundPasswordHasSet"];
                        
                        if (completion) {
                            completion();
                        }
                    });
                } hudParentView:nil showLocalErrorAlert:NO];
            } else {
                // 方案1成功，直接完成
                // 强制触发 KVO（如果有监听）
                [wself willChangeValueForKey:@"fundPasswordHasSet"];
                [wself didChangeValueForKey:@"fundPasswordHasSet"];
                
                if (completion) {
                    completion();
                }
            }
        });
    } hudParentView:nil];
}

- (void)toggleBalanceVisible:(UIButton *)sender
{
    _balanceHidden = !_balanceHidden;
    _eyeButton.selected = _balanceHidden;
    if (_balanceHidden) {
        _balanceLabel.text = @"****";
    } else {
        NSString *cached = [self rb_readCachedBalanceDisplayText];
        if (cached.length > 0) {
            _balanceLabel.text = cached;
        }
        [self loadBalanceAndStatus];
    }
}

- (void)onMenu:(id)sender
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"设置资金密码" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        WalletFundPasswordViewController *vc = [[WalletFundPasswordViewController alloc] init];
        vc.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:vc animated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"实名认证" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [BasicTool showUserDefintToast:@"实名认证功能敬请期待" view:self.view atHide:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.barButtonItem = sender;
    }
    [self presentViewController:alert animated:YES completion:nil];
}


- (void)showWalletMoreMenu
{
    // 先检测资金密码状态，然后再显示菜单
    __weak typeof(self) wself = self;
    NSLog(@"【更多菜单】开始显示，当前状态：fundPasswordHasSet=%d", self.fundPasswordHasSet);
    [self checkFundPasswordStatusWithCompletion:^{
        NSLog(@"【更多菜单】状态检测完成，准备显示菜单，当前状态：fundPasswordHasSet=%d", wself.fundPasswordHasSet);
        [wself showWalletMoreMenuInternal];
    }];
}

- (void)showWalletMoreMenuInternal
{
    UIView *win = self.view.window ?: [UIApplication sharedApplication].keyWindow;
    if (!win) return;
    
    CGRect bounds = win.bounds;
    CGFloat sheetH = 320.f;
    CGFloat cornerRadius = 16.f;
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = win.safeAreaInsets.bottom;
    }
    sheetH += safeBottom;
    
    // 半透明遮罩
    UIView *overlay = [[UIView alloc] initWithFrame:bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4f];
    overlay.alpha = 0;
    [win addSubview:overlay];
    self.moreSheetOverlay = overlay;
    
    UITapGestureRecognizer *tapDismiss = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissWalletMoreSheet)];
    [overlay addGestureRecognizer:tapDismiss];
    
    // 白色底栏（圆角在上方）
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(0, bounds.size.height, bounds.size.width, sheetH)];
    panel.backgroundColor = [UIColor whiteColor];
    panel.layer.cornerRadius = cornerRadius;
    if (@available(iOS 11.0, *)) {
        panel.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    }
    panel.clipsToBounds = YES;
    [win addSubview:panel];
    self.moreSheetPanel = panel;
    
    // 顶部拖拽条
    CGFloat barW = 36.f, barH = 4.f;
    UIView *handle = [[UIView alloc] initWithFrame:CGRectMake((panel.bounds.size.width - barW) / 2.f, 10.f, barW, barH)];
    handle.backgroundColor = HexColor(0xDDDDDD);
    handle.layer.cornerRadius = 2.f;
    [panel addSubview:handle];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.f, 24.f, panel.bounds.size.width - 40.f, 24.f)];
    titleLabel.text = @"更多功能";
    titleLabel.font = [UIFont boldSystemFontOfSize:18.f];
    titleLabel.textColor = HexColor(0x333333);
    [panel addSubview:titleLabel];
    
    // 根据资金密码状态显示不同的文字
    // 确保使用最新的状态值
    BOOL hasSet = self.fundPasswordHasSet;
    NSString *passwordTitle = hasSet ? @"修改资金密码" : @"设置资金密码";
    NSLog(@"【更多菜单】显示资金密码选项：fundPasswordHasSet=%d (直接访问:%d), title=%@ (当前时间:%@)", hasSet, _fundPasswordHasSet, passwordTitle, [NSDate date]);
    NSArray *rows = @[
        @[passwordTitle, @"lock.fill"],
        @[@"转账", @"arrow.left.arrow.right"]
    ];
    CGFloat rowH = 56.f;
    CGFloat y = 56.f;
    for (NSInteger i = 0; i < rows.count; i++) {
        NSArray *item = rows[i];
        NSString *title = item[0];
        NSString *iconName = item[1];
        UIButton *rowBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        rowBtn.frame = CGRectMake(0, y, panel.bounds.size.width, rowH);
        rowBtn.tag = 6000 + i;
        [rowBtn addTarget:self action:@selector(onMoreSheetRowTapped:) forControlEvents:UIControlEventTouchUpInside];
        rowBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        rowBtn.contentEdgeInsets = UIEdgeInsetsMake(0, 20.f, 0, 20.f);
        rowBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        [rowBtn setTitle:title forState:UIControlStateNormal];
        [rowBtn setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
        if (@available(iOS 13.0, *)) {
            UIImage *icon = [UIImage systemImageNamed:iconName];
            if (icon) {
                [rowBtn setImage:icon forState:UIControlStateNormal];
                rowBtn.tintColor = HexColor(0x1674FF);
                rowBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 12.f);
                rowBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 12.f, 0, 0);
            }
        }
        [panel addSubview:rowBtn];
        
        UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(20.f, y + rowH - 0.5f, panel.bounds.size.width - 40.f, 0.5f)];
        sep.backgroundColor = HexColor(0xEEEEEE);
        [panel addSubview:sep];
        
        y += rowH;
    }
    
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        overlay.alpha = 1;
        panel.frame = CGRectMake(0, bounds.size.height - sheetH, bounds.size.width, sheetH);
    } completion:nil];
}

- (void)dismissWalletMoreSheet
{
    UIView *panel = self.moreSheetPanel;
    UIView *overlay = self.moreSheetOverlay;
    if (!panel || !overlay) return;
    
    CGRect bounds = overlay.superview.bounds;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        overlay.alpha = 0;
        panel.frame = CGRectMake(0, bounds.size.height, bounds.size.width, panel.frame.size.height);
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
        [panel removeFromSuperview];
        self.moreSheetOverlay = nil;
        self.moreSheetPanel = nil;
    }];
}

- (void)onMoreSheetRowTapped:(UIButton *)sender
{
    NSInteger index = sender.tag - 6000;
    [self dismissWalletMoreSheet];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (index) {
            case 0: {
                // 根据按钮文字判断跳转到设置或修改页面
                // 按钮文字在显示菜单时已经根据状态动态设置，所以根据文字判断最准确
                NSString *buttonTitle = [sender titleForState:UIControlStateNormal];
                BOOL hasSet = self.fundPasswordHasSet;
                NSLog(@"【更多菜单点击】点击资金密码选项，按钮文字=%@, 当前状态：fundPasswordHasSet=%d", buttonTitle, hasSet);
                
                // 根据按钮文字判断：如果包含"修改"则跳转到修改页面，否则跳转到设置页面
                BOOL shouldGoToModify = NO;
                if (buttonTitle && buttonTitle.length > 0) {
                    // 检查按钮文字是否包含"修改"
                    NSRange range = [buttonTitle rangeOfString:@"修改"];
                    if (range.location != NSNotFound) {
                        shouldGoToModify = YES;
                        NSLog(@"【更多菜单点击】按钮文字包含\"修改\"，跳转到修改资金密码页面");
                    } else {
                        NSLog(@"【更多菜单点击】按钮文字不包含\"修改\"，跳转到设置资金密码页面");
                    }
                } else {
                    // 如果无法获取按钮文字，则根据状态值判断
                    shouldGoToModify = hasSet;
                    NSLog(@"【更多菜单点击】无法获取按钮文字，根据状态值判断：hasSet=%d", hasSet);
                }
                
                if (shouldGoToModify) {
                    // 跳转到修改密码页面
                    NSLog(@"【更多菜单点击】创建 WalletModifyFundPasswordViewController");
                    WalletModifyFundPasswordViewController *vc = [[WalletModifyFundPasswordViewController alloc] init];
                    vc.hidesBottomBarWhenPushed = YES;
                    [self.navigationController pushViewController:vc animated:YES];
                } else {
                    // 跳转到设置密码页面
                    NSLog(@"【更多菜单点击】创建 WalletFundPasswordViewController");
                    WalletFundPasswordViewController *vc = [[WalletFundPasswordViewController alloc] init];
                    vc.hidesBottomBarWhenPushed = YES;
                    [self.navigationController pushViewController:vc animated:YES];
                }
                break;
            }
            case 1: {
                WalletTransferViewController *vc = [[WalletTransferViewController alloc] init];
                vc.hidesBottomBarWhenPushed = YES;
                [self.navigationController pushViewController:vc animated:YES];
                break;
            }
            default:
                break;
        }
    });
}

@end
