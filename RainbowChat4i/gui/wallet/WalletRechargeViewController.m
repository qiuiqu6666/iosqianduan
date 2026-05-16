#import "WalletRechargeViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]
static const CGFloat kRechargePadding = 16.f;
static const CGFloat kRechargeAmountLabelH = 20.f;
static const CGFloat kRechargeAmountLabelFieldGap = 8.f;
static const CGFloat kRechargeAmountRowH = 52.f;
static const CGFloat kRechargeFieldCorner = 10.f;
static const CGFloat kRechargeFieldBorderW = 0.5f;
static const NSInteger kRechargeGreen = 0x07C160;
static const NSInteger kRechargeFieldBorderGray = 0xE5E5E5;
static const NSInteger kRechargePlaceholderGray = 0xADB5BD;

@interface WalletRechargeViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *tipCard;
@property (nonatomic, strong) UIView *amountCard;
@property (nonatomic, strong) UIView *amountContainerView;
@property (nonatomic, strong) UILabel *currencyLabel;
@property (nonatomic, strong) UITextField *amountField;
@property (nonatomic, strong) UILabel *quickLabel;
@property (nonatomic, strong) UIView *quickAmountView;
@property (nonatomic, strong) UIButton *submitButton;
@end

@implementation WalletRechargeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = HexColor(0xF5F5F5);
    self.navigationItem.title = @"充值";

    [self buildUI];

    [_amountField addTarget:self action:@selector(amountFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_amountField addTarget:self action:@selector(amountFieldDidEndEditing:) forControlEvents:UIControlEventEditingDidEnd];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)buildUI
{
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.showsVerticalScrollIndicator = YES;
    _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:_scrollView];

    _tipCard = [[UIView alloc] init];
    _tipCard.backgroundColor = [UIColor whiteColor];
    _tipCard.layer.cornerRadius = 12;
    _tipCard.layer.shadowColor = [UIColor blackColor].CGColor;
    _tipCard.layer.shadowOffset = CGSizeMake(0, 1);
    _tipCard.layer.shadowOpacity = 0.06;
    _tipCard.layer.shadowRadius = 6;
    [_scrollView addSubview:_tipCard];

    UIImageView *iconView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        iconView.image = [UIImage systemImageNamed:@"plus.circle.fill"];
        iconView.tintColor = HexColor(kRechargeGreen);
    }
    iconView.tag = 2001;
    [_tipCard addSubview:iconView];

    UILabel *tipTitleLabel = [[UILabel alloc] init];
    tipTitleLabel.text = @"充值到钱包";
    tipTitleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    tipTitleLabel.textColor = HexColor(0x333333);
    tipTitleLabel.tag = 2002;
    [_tipCard addSubview:tipTitleLabel];

    UILabel *tipDescLabel = [[UILabel alloc] init];
    tipDescLabel.text = @"提交后请等待审核通过";
    tipDescLabel.font = [UIFont systemFontOfSize:13];
    tipDescLabel.textColor = HexColor(0x999999);
    tipDescLabel.tag = 2003;
    [_tipCard addSubview:tipDescLabel];

    _amountCard = [[UIView alloc] init];
    _amountCard.backgroundColor = [UIColor whiteColor];
    _amountCard.layer.cornerRadius = 12;
    _amountCard.layer.shadowColor = [UIColor blackColor].CGColor;
    _amountCard.layer.shadowOffset = CGSizeMake(0, 1);
    _amountCard.layer.shadowOpacity = 0.06;
    _amountCard.layer.shadowRadius = 6;
    [_scrollView addSubview:_amountCard];

    UILabel *amountTitleLabel = [[UILabel alloc] init];
    amountTitleLabel.text = @"充值金额";
    amountTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    amountTitleLabel.textColor = HexColor(0x333333);
    amountTitleLabel.tag = 3001;
    [_amountCard addSubview:amountTitleLabel];

    _amountContainerView = [[UIView alloc] init];
    _amountContainerView.backgroundColor = [UIColor clearColor];
    _amountContainerView.layer.cornerRadius = kRechargeFieldCorner;
    _amountContainerView.layer.borderWidth = kRechargeFieldBorderW;
    _amountContainerView.layer.borderColor = HexColor(kRechargeFieldBorderGray).CGColor;
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
    _amountField.tintColor = HexColor(kRechargeGreen);
    if (@available(iOS 13.0, *)) {
        NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
        ps.alignment = NSTextAlignmentLeft;
        _amountField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"0.00" attributes:@{ NSForegroundColorAttributeName: HexColor(kRechargePlaceholderGray), NSParagraphStyleAttributeName: ps }];
    }
    [_amountContainerView addSubview:_amountField];

    _quickLabel = [[UILabel alloc] init];
    _quickLabel.text = @"快捷金额";
    _quickLabel.font = [UIFont systemFontOfSize:14];
    _quickLabel.textColor = HexColor(0x999999);
    [_scrollView addSubview:_quickLabel];

    _quickAmountView = [[UIView alloc] init];
    [_scrollView addSubview:_quickAmountView];

    NSArray *quickAmounts = @[@"100", @"500", @"1000", @"5000"];
    for (NSInteger i = 0; i < quickAmounts.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:[NSString stringWithFormat:@"¥%@", quickAmounts[i]] forState:UIControlStateNormal];
        [btn setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        btn.backgroundColor = [UIColor whiteColor];
        btn.layer.cornerRadius = 10;
        btn.layer.borderWidth = 1;
        btn.layer.borderColor = HexColor(0xE5E5E5).CGColor;
        btn.tag = 1000 + i;
        [btn addTarget:self action:@selector(onQuickAmount:) forControlEvents:UIControlEventTouchUpInside];
        [_quickAmountView addSubview:btn];
    }

    _submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_submitButton setTitle:@"确认充值" forState:UIControlStateNormal];
    _submitButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    _submitButton.backgroundColor = HexColor(kRechargeGreen);
    [_submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _submitButton.layer.cornerRadius = 12;
    _submitButton.layer.shadowColor = HexColor(kRechargeGreen).CGColor;
    _submitButton.layer.shadowOffset = CGSizeMake(0, 2);
    _submitButton.layer.shadowOpacity = 0.25;
    _submitButton.layer.shadowRadius = 6;
    [_submitButton addTarget:self action:@selector(onSubmit) forControlEvents:UIControlEventTouchUpInside];
    [self updateSubmitButtonState];
    [self.view addSubview:_submitButton];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat p = kRechargePadding;
    CGFloat safeTop = 0, safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = self.view.safeAreaInsets.top;
        safeBottom = self.view.safeAreaInsets.bottom;
    }

    CGFloat btnH = 52.f;
    _submitButton.frame = CGRectMake(p, h - safeBottom - btnH - 20.f, w - p * 2.f, btnH);

    CGFloat scrollBottom = h - safeBottom - btnH - 20.f - 16.f;
    _scrollView.frame = CGRectMake(0, 0, w, scrollBottom);

    CGFloat y = 20.f;

    _tipCard.frame = CGRectMake(p, y, w - p * 2.f, 72.f);
    UIImageView *iconView = [_tipCard viewWithTag:2001];
    UILabel *tipTitleLabel = [_tipCard viewWithTag:2002];
    UILabel *tipDescLabel = [_tipCard viewWithTag:2003];
    if (iconView) iconView.frame = CGRectMake(16.f, 16.f, 40.f, 40.f);
    if (tipTitleLabel) tipTitleLabel.frame = CGRectMake(64.f, 14.f, _tipCard.bounds.size.width - 80.f, 22.f);
    if (tipDescLabel) tipDescLabel.frame = CGRectMake(64.f, 38.f, _tipCard.bounds.size.width - 80.f, 18.f);

    y += 72.f + 16.f;

    CGFloat amountCardH = 16.f + kRechargeAmountLabelH + kRechargeAmountLabelFieldGap + kRechargeAmountRowH + 16.f;
    _amountCard.frame = CGRectMake(p, y, w - p * 2.f, amountCardH);
    UILabel *amountTitleLabel = [_amountCard viewWithTag:3001];
    if (amountTitleLabel) amountTitleLabel.frame = CGRectMake(16.f, 16.f, _amountCard.bounds.size.width - 32.f, kRechargeAmountLabelH);
    CGFloat containerY = 16.f + kRechargeAmountLabelH + kRechargeAmountLabelFieldGap;
    _amountContainerView.frame = CGRectMake(16.f, containerY, _amountCard.bounds.size.width - 32.f, kRechargeAmountRowH);
    _currencyLabel.frame = CGRectMake(12.f, 0, 24.f, kRechargeAmountRowH);
    _amountField.frame = CGRectMake(40.f, 0, _amountContainerView.bounds.size.width - 52.f, kRechargeAmountRowH);

    y += amountCardH + 20.f;

    _quickLabel.frame = CGRectMake(p, y, w - p * 2.f, 20.f);
    y += 28.f;

    CGFloat quickSpacing = 10.f;
    CGFloat quickRowH = 48.f;
    NSInteger cols = 2;
    CGFloat quickW = (w - p * 2.f - quickSpacing) / 2.f;
    _quickAmountView.frame = CGRectMake(p, y, w - p * 2.f, quickRowH * 2.f + quickSpacing);
    for (NSInteger i = 0; i < _quickAmountView.subviews.count; i++) {
        UIView *view = _quickAmountView.subviews[i];
        if ([view isKindOfClass:[UIButton class]]) {
            NSInteger row = i / cols;
            NSInteger col = i % cols;
            view.frame = CGRectMake((CGFloat)col * (quickW + quickSpacing), (CGFloat)row * (quickRowH + quickSpacing), quickW, quickRowH);
        }
    }
    y += quickRowH * 2.f + quickSpacing + 24.f;

    _scrollView.contentSize = CGSizeMake(w, y);
}

- (void)onQuickAmount:(UIButton *)sender
{
    NSArray *amounts = @[@"100", @"500", @"1000", @"5000"];
    NSInteger index = sender.tag - 1000;
    if (index >= 0 && index < amounts.count) {
        NSString *amount = amounts[index];
        _amountField.text = amount;
        [self updateQuickAmountButtons];
        [self updateSubmitButtonState];
    }
}

- (void)amountFieldDidChange:(UITextField *)field
{
    NSString *text = field.text;
    if (text.length > 0) {
        NSRange dot = [text rangeOfString:@"."];
        if (dot.location != NSNotFound && text.length - dot.location > 3) {
            field.text = [text substringToIndex:dot.location + 3];
        }
    }
    [self updateQuickAmountButtons];
    [self updateSubmitButtonState];
}

- (void)amountFieldDidEndEditing:(UITextField *)field
{
    // 格式化金额显示（保留两位小数）
    NSString *text = field.text;
    if (text.length > 0) {
        double amount = [text doubleValue];
        if (amount > 0) {
            NSString *formatted = [NSString stringWithFormat:@"%.2f", amount];
            field.text = formatted;
            // 格式化后更新按钮状态
            [self updateQuickAmountButtons];
            [self updateSubmitButtonState];
        } else {
            field.text = @"";
            [self updateSubmitButtonState];
        }
    }
}

- (void)dismissKeyboard
{
    [self.view endEditing:YES];
}

- (void)updateSubmitButtonState
{
    NSString *amountStr = [_amountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (amountStr.length == 0) {
        _submitButton.enabled = NO;
        _submitButton.alpha = 0.5;
        _submitButton.backgroundColor = HexColor(0xCCCCCC);
        return;
    }
    
    double amount = [amountStr doubleValue];
    BOOL enabled = amount > 0 && !isnan(amount) && !isinf(amount);
    
    _submitButton.enabled = enabled;
    _submitButton.alpha = enabled ? 1.0 : 0.5;
    _submitButton.backgroundColor = enabled ? HexColor(kRechargeGreen) : HexColor(0xCCCCCC);
}

- (void)updateQuickAmountButtons
{
    NSString *currentAmount = [_amountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (currentAmount.length == 0) {
        // 清空所有选中状态
        for (UIView *view in _quickAmountView.subviews) {
            if ([view isKindOfClass:[UIButton class]]) {
                UIButton *btn = (UIButton *)view;
                btn.backgroundColor = [UIColor whiteColor];
                btn.layer.borderColor = HexColor(0xE5E5E5).CGColor;
                [btn setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
            }
        }
        return;
    }
    
    // 将当前金额转为数字进行比较（兼容 "100" 和 "100.00"）
    double currentValue = [currentAmount doubleValue];
    
    for (UIView *view in _quickAmountView.subviews) {
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            NSArray *amounts = @[@"100", @"500", @"1000", @"5000"];
            NSInteger index = btn.tag - 1000;
            if (index >= 0 && index < amounts.count) {
                double btnValue = [amounts[index] doubleValue];
                BOOL isSelected = (fabs(currentValue - btnValue) < 0.01);
                btn.backgroundColor = isSelected ? HexColor(0xE9F3EE) : [UIColor whiteColor];
                btn.layer.borderColor = isSelected ? HexColor(kRechargeGreen).CGColor : HexColor(0xE5E5E5).CGColor;
                [btn setTitleColor:isSelected ? HexColor(kRechargeGreen) : HexColor(0x333333) forState:UIControlStateNormal];
            }
        }
    }
}

- (void)onSubmit
{
    // 检查按钮是否可用
    if (!_submitButton.enabled) {
        [BasicTool showAlertInfo:@"请输入有效的充值金额" parent:self];
        return;
    }
    
    NSString *amountStr = [_amountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (amountStr.length == 0) {
        [BasicTool showAlertInfo:@"请输入充值金额" parent:self];
        return;
    }
    
    double amount = [amountStr doubleValue];
    if (amount <= 0 || isnan(amount) || isinf(amount)) {
        [BasicTool showAlertInfo:@"充值金额必须大于0" parent:self];
        return;
    }
    
    // 格式化金额为两位小数（接口要求：字符串格式，保留两位小数）
    NSString *amountFormatted = [NSString stringWithFormat:@"%.2f", amount];
    
    NSLog(@"【充值页面】提交充值申请，金额：%@", amountFormatted);
    
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletRecharge:amountFormatted complete:^(BOOL sucess, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess) {
                // 成功：显示提示并返回上一页
                [BasicTool showAlertInfo:msg ?: @"充值申请已提交，请等待审核" parent:wself];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [wself.navigationController popViewControllerAnimated:YES];
                });
            } else {
                // 失败：显示服务端返回的错误信息（如"充值金额不能为空"、"充值金额必须大于0"等）
                [BasicTool showAlertInfo:msg ?: @"充值失败" parent:wself];
            }
        });
    } hudParentView:self.view];
}

@end
