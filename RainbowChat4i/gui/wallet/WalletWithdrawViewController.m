#import "WalletWithdrawViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "WalletFundPasswordViewController.h"
#import "WalletWithdrawMethodViewController.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

// MARK: - 常量
static const CGFloat kWDPadding = 16.f;
static const CGFloat kWDCardCorner = 14.f;
static const CGFloat kWDCardShadowRadius = 10.f;
static const CGFloat kWDTipCardH = 88.f;
static const CGFloat kWDTipIconSize = 40.f;
static const CGFloat kWDMethodRowH = 84.f;
static const CGFloat kWDMethodTableMaxH = 252.f;
static const CGFloat kWDMethodEmptyH = 164.f;
static const CGFloat kWDAmountLabelH = 20.f;
static const CGFloat kWDAmountLabelFieldGap = 8.f;
static const CGFloat kWDAmountRowH = 52.f;   // 与添加收款方式输入框高度一致
static const CGFloat kWDAmountCardH = 112.f; // 16+labelH+gap+rowH+16
static const CGFloat kWDAmountInputH = kWDAmountRowH;
static const CGFloat kWDFieldCorner = 10.f;
static const CGFloat kWDFieldBorderW = 0.5f;
static const NSInteger kWDFieldBorderGray = 0xE5E5E5;  // 与添加收款方式一致
static const NSInteger kWDPlaceholderGray = 0xADB5BD;
static const CGFloat kWDSubmitH = 52.f;
static const NSInteger kWDBlue = 0x1674FF;
static const NSInteger kWDGreen = 0x22BB44;
static const NSInteger kWDTextDark = 0x111827;
static const NSInteger kWDTextGray = 0x6B7280;
static const NSInteger kWDBorderGray = 0xE5E7EB;
static const NSInteger kWDBgLight = 0xF9FAFB;
static const NSInteger kWDCellBg = 0xFAFBFF;
static const NSInteger kWDTagTipIcon = 2001;
static const NSInteger kWDTagTipTitle = 2002;
static const NSInteger kWDTagTipDesc = 2003;
static const NSInteger kWDTagMethodTitle = 3001;
static const NSInteger kWDTagEmptyIcon = 4001;
static const NSInteger kWDTagEmptyLabel = 4002;
static const NSInteger kWDTagEmptyBtn = 4003;
static const NSInteger kWDTagAmountTitle = 5001;
static const NSInteger kWDTagCellCard = 1000;
static const NSInteger kWDTagCellIcon = 1001;
static const NSInteger kWDTagCellType = 1002;
static const NSInteger kWDTagCellName = 1003;
static const NSInteger kWDTagCellIndicator = 1004;
static const NSInteger kWDTagCellCheck = 1005;

// MARK: - Safe 取值
static NSString *WDSafeString(id value) {
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : @"";
}
static NSDictionary *WDSafeDictionary(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? (NSDictionary *)value : nil;
}
static NSArray *WDSafeArray(id value) {
    return [value isKindOfClass:[NSArray class]] ? (NSArray *)value : @[];
}
static NSInteger WDSafeInteger(id value) {
    if ([value isKindOfClass:[NSNumber class]]) return [(NSNumber *)value integerValue];
    if ([value isKindOfClass:[NSString class]]) return [(NSString *)value integerValue];
    return 0;
}

@interface WalletWithdrawViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *tipCard;
@property (nonatomic, strong) UIView *amountCard;
@property (nonatomic, strong) UIView *amountContainerView;
@property (nonatomic, strong) UILabel *currencyLabel;
@property (nonatomic, strong) UITextField *amountField;
@property (nonatomic, strong) UIView *methodCardView;
@property (nonatomic, strong) UITableView *methodTableView;
@property (nonatomic, strong) NSArray *withdrawMethods;
@property (nonatomic, strong) NSDictionary *selectedMethod;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIView *emptyMethodView;
@property (nonatomic, assign) BOOL uiBuilt;
@property (nonatomic, assign) BOOL didFirstAppear;
@property (nonatomic, assign) BOOL isLoadingMethods;
@end

@implementation WalletWithdrawViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = HexColor(0xF6F7FB);
    self.navigationItem.title = @"提现";

    _uiBuilt = NO;
    _didFirstAppear = NO;
    _isLoadingMethods = NO;
    _withdrawMethods = @[];

    [self buildUI];

    [_amountField addTarget:self action:@selector(amountFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_amountField addTarget:self action:@selector(amountFieldDidEndEditing:) forControlEvents:UIControlEventEditingDidEnd];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)buildUI {
    if (_uiBuilt) return;

    [self buildTipCard];
    [self buildMethodSection];
    [self buildAmountSection];
    [self buildSubmitButton];
}

- (void)buildTipCard {
    _tipCard = [[UIView alloc] init];
    _tipCard.backgroundColor = [UIColor whiteColor];
    _tipCard.layer.cornerRadius = kWDCardCorner;
    _tipCard.layer.shadowColor = [UIColor blackColor].CGColor;
    _tipCard.layer.shadowOffset = CGSizeMake(0, 2);
    _tipCard.layer.shadowOpacity = 0.05;
    _tipCard.layer.shadowRadius = kWDCardShadowRadius;
    [self.view addSubview:_tipCard];

    UIImageView *iconView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        iconView.image = [UIImage systemImageNamed:@"arrow.down.circle.fill"];
    } else {
        iconView.backgroundColor = HexColor(kWDGreen);
        iconView.layer.cornerRadius = 20;
    }
    iconView.tintColor = HexColor(kWDGreen);
    iconView.tag = kWDTagTipIcon;
    [_tipCard addSubview:iconView];

    UILabel *tipTitle = [[UILabel alloc] init];
    tipTitle.text = @"提现到账户";
    tipTitle.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    tipTitle.textColor = HexColor(kWDTextDark);
    tipTitle.tag = kWDTagTipTitle;
    [_tipCard addSubview:tipTitle];

    UILabel *tipDesc = [[UILabel alloc] init];
    tipDesc.text = @"提现申请提交后，请等待审核通过";
    tipDesc.font = [UIFont systemFontOfSize:13];
    tipDesc.textColor = HexColor(kWDTextGray);
    tipDesc.tag = kWDTagTipDesc;
    [_tipCard addSubview:tipDesc];
}

- (void)buildMethodSection {
    _methodCardView = [[UIView alloc] init];
    _methodCardView.backgroundColor = [UIColor whiteColor];
    _methodCardView.layer.cornerRadius = kWDCardCorner;
    _methodCardView.layer.shadowColor = [UIColor blackColor].CGColor;
    _methodCardView.layer.shadowOffset = CGSizeMake(0, 2);
    _methodCardView.layer.shadowOpacity = 0.05;
    _methodCardView.layer.shadowRadius = kWDCardShadowRadius;
    [self.view addSubview:_methodCardView];

    UILabel *methodTitle = [[UILabel alloc] init];
    methodTitle.text = @"选择提款方式";
    methodTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    methodTitle.textColor = HexColor(kWDTextDark);
    methodTitle.tag = kWDTagMethodTitle;
    [_methodCardView addSubview:methodTitle];

    _methodTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _methodTableView.delegate = self;
    _methodTableView.dataSource = self;
    _methodTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _methodTableView.backgroundColor = [UIColor clearColor];
    _methodTableView.scrollEnabled = NO;
    [_methodCardView addSubview:_methodTableView];

    _emptyMethodView = [[UIView alloc] init];
    _emptyMethodView.backgroundColor = [UIColor clearColor];
    _emptyMethodView.hidden = YES;
    [_methodCardView addSubview:_emptyMethodView];

    UIImageView *emptyIcon = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        emptyIcon.image = [UIImage systemImageNamed:@"creditcard"];
    } else {
        emptyIcon.backgroundColor = HexColor(0xCCCCCC);
        emptyIcon.layer.cornerRadius = 30;
    }
    emptyIcon.tintColor = HexColor(0xCCCCCC);
    emptyIcon.tag = kWDTagEmptyIcon;
    [_emptyMethodView addSubview:emptyIcon];

    UILabel *emptyLabel = [[UILabel alloc] init];
    emptyLabel.text = @"暂无提款方式";
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.textColor = HexColor(0x999999);
    emptyLabel.font = [UIFont systemFontOfSize:14];
    emptyLabel.tag = kWDTagEmptyLabel;
    [_emptyMethodView addSubview:emptyLabel];

    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [addBtn setTitle:@"添加提款方式" forState:UIControlStateNormal];
    addBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [addBtn setTitleColor:HexColor(kWDBlue) forState:UIControlStateNormal];
    addBtn.layer.cornerRadius = 16;
    addBtn.layer.borderWidth = 1;
    addBtn.layer.borderColor = HexColor(kWDBlue).CGColor;
    [addBtn addTarget:self action:@selector(onManageMethods) forControlEvents:UIControlEventTouchUpInside];
    addBtn.tag = kWDTagEmptyBtn;
    [_emptyMethodView addSubview:addBtn];
}

- (void)buildAmountSection {
    _amountCard = [[UIView alloc] init];
    _amountCard.backgroundColor = [UIColor whiteColor];
    _amountCard.layer.cornerRadius = kWDCardCorner;
    _amountCard.layer.shadowColor = [UIColor blackColor].CGColor;
    _amountCard.layer.shadowOffset = CGSizeMake(0, 2);
    _amountCard.layer.shadowOpacity = 0.05;
    _amountCard.layer.shadowRadius = kWDCardShadowRadius;
    [self.view addSubview:_amountCard];

    UILabel *amountTitle = [[UILabel alloc] init];
    amountTitle.text = @"提现金额";
    amountTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    amountTitle.textColor = HexColor(0x333333);
    amountTitle.tag = kWDTagAmountTitle;
    [_amountCard addSubview:amountTitle];

    _amountContainerView = [[UIView alloc] init];
    _amountContainerView.backgroundColor = [UIColor clearColor];
    _amountContainerView.layer.cornerRadius = kWDFieldCorner;
    _amountContainerView.layer.borderWidth = kWDFieldBorderW;
    _amountContainerView.layer.borderColor = HexColor(kWDFieldBorderGray).CGColor;
    [_amountCard addSubview:_amountContainerView];

    _currencyLabel = [[UILabel alloc] init];
    _currencyLabel.text = @"¥";
    _currencyLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    _currencyLabel.textColor = HexColor(0x000000);
    [_amountContainerView addSubview:_currencyLabel];

    _amountField = [[UITextField alloc] init];
    _amountField.placeholder = @"0.00";
    _amountField.keyboardType = UIKeyboardTypeDecimalPad;
    _amountField.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    _amountField.textColor = HexColor(0x000000);
    _amountField.backgroundColor = [UIColor clearColor];
    _amountField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _amountField.tintColor = HexColor(kWDBlue);
    if (@available(iOS 13.0, *)) {
        NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
        ps.alignment = NSTextAlignmentLeft;
        _amountField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"0.00" attributes:@{ NSForegroundColorAttributeName: HexColor(kWDPlaceholderGray), NSParagraphStyleAttributeName: ps }];
    }
    [_amountContainerView addSubview:_amountField];
}

- (void)buildSubmitButton {
    _submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_submitButton setTitle:@"确认提现" forState:UIControlStateNormal];
    _submitButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    _submitButton.backgroundColor = HexColor(0xCCCCCC);
    [_submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _submitButton.layer.cornerRadius = 12;
    _submitButton.enabled = NO;
    [_submitButton addTarget:self action:@selector(onSubmit) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_submitButton];
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!_uiBuilt) _uiBuilt = YES;

    CGFloat w = self.view.bounds.size.width;
    CGFloat safeTop = 0, safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = self.view.safeAreaInsets.top;
        safeBottom = self.view.safeAreaInsets.bottom;
    }

    CGFloat cardW = w - kWDPadding * 2;
    CGFloat y = safeTop + 12;

    _tipCard.frame = CGRectMake(kWDPadding, y, cardW, kWDTipCardH);
    UIImageView *tipIcon = [_tipCard viewWithTag:kWDTagTipIcon];
    UILabel *tipTitle = [_tipCard viewWithTag:kWDTagTipTitle];
    UILabel *tipDesc = [_tipCard viewWithTag:kWDTagTipDesc];
    if (tipIcon) tipIcon.frame = CGRectMake(kWDPadding, 24, kWDTipIconSize, kWDTipIconSize);
    if (tipTitle) tipTitle.frame = CGRectMake(64, 20, cardW - 80, 24);
    if (tipDesc) tipDesc.frame = CGRectMake(64, 46, cardW - 80, 20);

    y += kWDTipCardH + 16;

    NSInteger rows = _withdrawMethods.count;
    CGFloat methodTableH = rows > 0 ? MIN(rows * kWDMethodRowH, kWDMethodTableMaxH) : kWDMethodEmptyH;
    CGFloat methodCardH = 56 + methodTableH;
    _methodCardView.frame = CGRectMake(kWDPadding, y, cardW, methodCardH);
    UILabel *methodTitle = [_methodCardView viewWithTag:kWDTagMethodTitle];
    if (methodTitle) methodTitle.frame = CGRectMake(kWDPadding, 16, cardW - 32, 22);
    _methodTableView.frame = CGRectMake(0, 48, cardW, methodTableH);
    _emptyMethodView.frame = _methodTableView.frame;

    UIImageView *emptyIcon = [_emptyMethodView viewWithTag:kWDTagEmptyIcon];
    UILabel *emptyLabel = [_emptyMethodView viewWithTag:kWDTagEmptyLabel];
    UIButton *emptyBtn = [_emptyMethodView viewWithTag:kWDTagEmptyBtn];
    if (emptyIcon) emptyIcon.frame = CGRectMake((_emptyMethodView.bounds.size.width - 56) / 2, 20, 56, 56);
    if (emptyLabel) emptyLabel.frame = CGRectMake(0, 84, _emptyMethodView.bounds.size.width, 20);
    if (emptyBtn) emptyBtn.frame = CGRectMake((_emptyMethodView.bounds.size.width - 130) / 2, 116, 130, 34);

    y += methodCardH + 20;

    _amountCard.frame = CGRectMake(kWDPadding, y, cardW, kWDAmountCardH);
    UILabel *amountTitle = [_amountCard viewWithTag:kWDTagAmountTitle];
    if (amountTitle) amountTitle.frame = CGRectMake(kWDPadding, 16, cardW - 32, kWDAmountLabelH);
    CGFloat containerY = 16 + kWDAmountLabelH + kWDAmountLabelFieldGap;
    _amountContainerView.frame = CGRectMake(kWDPadding, containerY, cardW - kWDPadding * 2, kWDAmountRowH);
    _currencyLabel.frame = CGRectMake(12, 0, 24, kWDAmountRowH);
    _amountField.frame = CGRectMake(40, 0, _amountContainerView.bounds.size.width - 52, kWDAmountRowH);

    y += kWDAmountCardH + 20;

    CGFloat minBottomY = self.view.bounds.size.height - safeBottom - kWDSubmitH - 14;
    if (y < minBottomY) y = minBottomY;
    _submitButton.frame = CGRectMake(kWDPadding, y, cardW, kWDSubmitH);

    for (UITableViewCell *cell in _methodTableView.visibleCells) {
        UIView *cardView = [cell.contentView viewWithTag:kWDTagCellCard];
        UIImageView *check = [cell.contentView viewWithTag:kWDTagCellCheck];
        if (cardView && check && cardView.bounds.size.width > 0) {
            check.frame = CGRectMake(cardView.bounds.size.width - 34, 24, 24, 24);
        }
    }
}

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_uiBuilt && _didFirstAppear) [self loadWithdrawMethods];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!_didFirstAppear) {
        _didFirstAppear = YES;
        [self loadWithdrawMethods];
    }
}

#pragma mark - Data

- (void)loadWithdrawMethods {
    if (!_uiBuilt || !_methodTableView || !self.view.window || _isLoadingMethods) return;
    if (!_withdrawMethods) _withdrawMethods = @[];
    _isLoadingMethods = YES;

    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletGetWithdrawMethodsWithComplete:^(BOOL sucess, NSArray *methods) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!wself) return;
            wself.isLoadingMethods = NO;
            if (!wself.methodTableView || !wself.view.window) return;

            if (sucess) {
                NSArray *raw = WDSafeArray(methods);
                NSMutableArray *list = [NSMutableArray arrayWithCapacity:raw.count];
                for (id item in raw) {
                    NSDictionary *d = WDSafeDictionary(item);
                    if (d) [list addObject:d];
                }
                wself.withdrawMethods = [list copy];
                if (wself.withdrawMethods.count > 0 && !WDSafeDictionary(wself.selectedMethod)) {
                    wself.selectedMethod = wself.withdrawMethods.firstObject;
                }
                wself.methodTableView.hidden = (wself.withdrawMethods.count == 0);
                wself.emptyMethodView.hidden = (wself.withdrawMethods.count > 0);
                [wself.methodTableView reloadData];
                [wself.view setNeedsLayout];
                [wself updateSubmitButtonState];
            } else {
                wself.withdrawMethods = @[];
                wself.methodTableView.hidden = YES;
                wself.emptyMethodView.hidden = NO;
                [wself.methodTableView reloadData];
                [wself.view setNeedsLayout];
                [wself updateSubmitButtonState];
            }
        });
    } hudParentView:nil];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return WDSafeArray(_withdrawMethods).count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kWDMethodRowH;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"wd_method_cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor clearColor];
        [self configureMethodCell:cell];
    }

    NSArray *list = WDSafeArray(_withdrawMethods);
    if (indexPath.row >= list.count) return cell;
    NSDictionary *method = WDSafeDictionary(list[indexPath.row]);
    if (!method) return cell;

    UIView *cardView = [cell.contentView viewWithTag:kWDTagCellCard];
    UIImageView *iconView = [cell.contentView viewWithTag:kWDTagCellIcon];
    UILabel *typeLabel = [cell.contentView viewWithTag:kWDTagCellType];
    UILabel *nameLabel = [cell.contentView viewWithTag:kWDTagCellName];
    UIView *indicator = [cell.contentView viewWithTag:kWDTagCellIndicator];
    UIImageView *checkIcon = [cell.contentView viewWithTag:kWDTagCellCheck];

    CGFloat cardW = tableView.bounds.size.width - 20;
    if (cardView) cardView.frame = CGRectMake(10, 6, cardW, 72);
    if (iconView) iconView.frame = CGRectMake(16, 18, 36, 36);
    if (typeLabel) typeLabel.frame = CGRectMake(62, 14, cardW - 120, 22);
    if (nameLabel) nameLabel.frame = CGRectMake(62, 40, cardW - 120, 18);
    if (indicator) indicator.frame = CGRectMake(0, 0, 4, 72);
    if (checkIcon && cardW > 0) checkIcon.frame = CGRectMake(cardW - 34, 24, 24, 24);

    NSInteger methodType = WDSafeInteger(method[@"method_type"]);
    NSString *typeName = @"";
    NSString *iconName = nil;
    if (methodType == 1) {
        typeName = @"支付宝";
        iconName = @"bind_alipay";
    } else if (methodType == 2) {
        typeName = @"微信";
        iconName = @"bind_wechat";
    } else if (methodType == 3) {
        typeName = @"银行卡";
        iconName = @"bind_bankcard";
    }
    if (iconView && iconName.length > 0) {
        UIImage *img = [UIImage imageNamed:iconName];
        if (img) img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        iconView.image = img;
        iconView.backgroundColor = [UIColor clearColor];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
    }
    if (typeLabel) typeLabel.text = typeName;
    if (nameLabel) nameLabel.text = [NSString stringWithFormat:@"%@ · %@", WDSafeString(method[@"account_name"]), WDSafeString(method[@"account_number"])];

    BOOL selected = NO;
    NSDictionary *sel = WDSafeDictionary(_selectedMethod);
    if (sel) selected = [WDSafeString(method[@"id"]) isEqualToString:WDSafeString(sel[@"id"])];
    if (indicator) indicator.hidden = !selected;
    if (checkIcon) checkIcon.hidden = !selected;

    return cell;
}

- (void)configureMethodCell:(UITableViewCell *)cell {
    UIView *cardView = [[UIView alloc] init];
    cardView.tag = kWDTagCellCard;
    cardView.backgroundColor = HexColor(kWDCellBg);
    cardView.layer.cornerRadius = 10;
    [cell.contentView addSubview:cardView];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.tag = kWDTagCellIcon;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [cardView addSubview:iconView];

    UILabel *typeLabel = [[UILabel alloc] init];
    typeLabel.tag = kWDTagCellType;
    typeLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    typeLabel.textColor = HexColor(kWDTextDark);
    [cardView addSubview:typeLabel];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.tag = kWDTagCellName;
    nameLabel.font = [UIFont systemFontOfSize:13];
    nameLabel.textColor = HexColor(kWDTextGray);
    [cardView addSubview:nameLabel];

    UIView *indicator = [[UIView alloc] init];
    indicator.tag = kWDTagCellIndicator;
    indicator.backgroundColor = HexColor(kWDBlue);
    indicator.hidden = YES;
    [cardView addSubview:indicator];

    UIImageView *checkIcon = [[UIImageView alloc] init];
    checkIcon.tag = kWDTagCellCheck;
    if (@available(iOS 13.0, *)) checkIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    else {
        checkIcon.backgroundColor = HexColor(kWDBlue);
        checkIcon.layer.cornerRadius = 12;
    }
    checkIcon.tintColor = HexColor(kWDBlue);
    checkIcon.hidden = YES;
    [cardView addSubview:checkIcon];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *list = WDSafeArray(_withdrawMethods);
    if (indexPath.row >= list.count) return;
    NSDictionary *method = WDSafeDictionary(list[indexPath.row]);
    if (method) {
        _selectedMethod = method;
        [tableView reloadData];
        [self updateSubmitButtonState];
    }
}

#pragma mark - Actions

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)amountFieldDidChange:(UITextField *)field {
    [self updateSubmitButtonState];
}

- (void)amountFieldDidEndEditing:(UITextField *)field {
    NSString *text = field.text;
    if (text.length > 0) {
        double amount = [text doubleValue];
        if (amount > 0) field.text = [NSString stringWithFormat:@"%.2f", amount];
        else field.text = @"";
        [self updateSubmitButtonState];
    }
}

- (void)updateSubmitButtonState {
    if (!_submitButton) return;
    BOOL hasMethod = (WDSafeDictionary(_selectedMethod) != nil);
    NSString *amountStr = [_amountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (amountStr.length == 0) {
        _submitButton.enabled = NO;
        _submitButton.alpha = 0.5;
        _submitButton.backgroundColor = HexColor(0xCCCCCC);
        return;
    }
    double amount = [amountStr doubleValue];
    BOOL enabled = hasMethod && amount > 0 && !isnan(amount) && !isinf(amount);
    _submitButton.enabled = enabled;
    _submitButton.alpha = enabled ? 1.0 : 0.5;
    _submitButton.backgroundColor = enabled ? HexColor(kWDBlue) : HexColor(0xCCCCCC);
}

- (void)onManageMethods {
    WalletWithdrawMethodViewController *vc = [[WalletWithdrawMethodViewController alloc] init];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onSubmit {
    if (!_submitButton.enabled) {
        if (!WDSafeDictionary(_selectedMethod)) [BasicTool showAlertInfo:@"请选择提款方式" parent:self];
        else [BasicTool showAlertInfo:@"请输入有效的提现金额" parent:self];
        return;
    }
    if (!WDSafeDictionary(_selectedMethod)) {
        [BasicTool showAlertInfo:@"请选择提款方式" parent:self];
        return;
    }
    NSString *amountStr = [_amountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (amountStr.length == 0) {
        [BasicTool showAlertInfo:@"请输入提现金额" parent:self];
        return;
    }
    double amount = [amountStr doubleValue];
    if (amount <= 0 || isnan(amount) || isinf(amount)) {
        [BasicTool showAlertInfo:@"提现金额必须大于0" parent:self];
        return;
    }
    NSString *amountFormatted = [NSString stringWithFormat:@"%.2f", amount];
    NSString *methodId = WDSafeString(_selectedMethod[@"id"]);
    if (methodId.length == 0) {
        [BasicTool showAlertInfo:@"提款方式无效" parent:self];
        return;
    }

    __weak typeof(self) wself = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"输入资金密码" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"请输入资金密码";
        tf.secureTextEntry = YES;
        tf.keyboardType = UIKeyboardTypeNumberPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *pwd = alert.textFields.firstObject.text;
        if (pwd.length == 0) {
            [BasicTool showAlertInfo:@"请输入资金密码" parent:wself];
            return;
        }
        [wself submitWithdraw:methodId amount:amountFormatted fundPassword:pwd];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)submitWithdraw:(NSString *)methodId amount:(NSString *)amount fundPassword:(NSString *)fundPassword {
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletWithdraw:methodId amount:amount fundPassword:fundPassword complete:^(BOOL sucess, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [BasicTool showAlertInfo:sucess ? @"提现申请已提交，请等待审核" : (msg ?: @"提现失败") parent:wself];
            if (sucess) {
                wself.amountField.text = @"";
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [wself.navigationController popViewControllerAnimated:YES];
                });
            }
        });
    } hudParentView:self.view];
}

@end
