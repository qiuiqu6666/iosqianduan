#import "WalletTransferViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "WalletFundPasswordViewController.h"
#import "WalletFundPasswordInputViewController.h"
#import "MessageHelper.h"
#import "ChatDataHelper.h"
#import "TMessageHelper.h"
#import "TChatDataHelper.h"
#import "AlarmsProvider.h"
#import "AlarmType.h"
#import "MsgBody4Friend.h"
#import "MsgBody4Guest.h"
#import "Protocal.h"
#import "EVAToolKits.h"
#import "JSQMessage.h"
#import "ErrorCode.h"
#import "IMClientManager.h"
#import "ViewControllerFactory.h"
#import "GroupMemberViewController.h"
#import "GroupMemberEntity.h"
#import "GroupsProvider.h"
#import "FileDownloadHelper.h"
#import "FriendsListProvider.h"
#import "UserEntity.h"
#import "ChatRootViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"
#import "LPActionSheet.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]
#define WXRed       HexColor(0xE64340)
#define CardBgGray  HexColor(0xEDEDED)
#define WXGreen     HexColor(0x07C160)   // 设计图：绿色光标/转账按钮
#define HintBlueGray HexColor(0x576B95)  // 设计图：添加转账说明浅蓝灰
static const CGFloat kCardMargin = 12.0f;
static const CGFloat kCardRadius = 8.0f;
static const CGFloat kAmountCardRadius = 20.0f;  // 金额卡片大圆角、无边距延伸到底
static const CGFloat kAmountCardHorzPad = 30.0f; // 卡片内文字/输入左右间距
static const CGFloat kAmountFieldHeight = 60.0f; // 金额输入框高度
static const CGFloat kCardLeftPad = 16.0f;
static const CGFloat kCardRightPad = 16.0f;
static const CGFloat kRowH = 52.0f;
static const CGFloat kKeypadHeight = 280.0f;   // 底部固定键盘高度
static const CGFloat kKeypadKeyRadius = 6.0f;

static BOOL RBWalletFundPasswordIsSetFromResponse(NSDictionary *data) {
    if (![data isKindOfClass:[NSDictionary class]]) return NO;
    id isSetValue = data[@"is_set"];
    if ([isSetValue isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)isSetValue;
        return [s isEqualToString:@"1"] || [s isEqualToString:@"true"] || [s.lowercaseString isEqualToString:@"yes"];
    }
    if ([isSetValue isKindOfClass:[NSNumber class]]) {
        return ([isSetValue intValue] == 1 || [isSetValue boolValue] == YES);
    }
    if (isSetValue != nil) {
        NSString *s = [isSetValue description];
        return [s isEqualToString:@"1"] || [s intValue] == 1 || [s.lowercaseString isEqualToString:@"true"] || [s.lowercaseString isEqualToString:@"yes"];
    }
    return NO;
}

@interface WalletTransferViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
/// 用户信息区域（设计图：浅灰背景、左双行文案 + 右侧圆角方形头像，信息确认防误转）
@property (nonatomic, strong) UIView *userInfoArea;
@property (nonatomic, strong) UILabel *userInfoTitleLabel;   // 转账给 XXX，大号加粗深色
@property (nonatomic, strong) UILabel *userInfoSubtitleLabel; // 微信号: xxx，小号浅灰
@property (nonatomic, strong) UIImageView *userInfoAvatarView;
/// 无收款人时内容区顶栏（选择收款人 / 输入 Chat ID）
@property (nonatomic, strong) UIView *recipientBar;
@property (nonatomic, strong) UILabel *selectRecipientHint;
@property (nonatomic, strong) UITextField *toUidField;
@property (nonatomic, strong) UILabel *chevronLabel;
@property (nonatomic, strong) UIView *assetSelectorBar;
@property (nonatomic, strong) UILabel *assetSelectorTitleLabel;
@property (nonatomic, strong) UILabel *assetSelectorAmountLabel;
@property (nonatomic, strong) UILabel *assetSelectorValueLabel;
@property (nonatomic, strong) UILabel *assetSelectorChevronLabel;
@property (nonatomic, strong) UIImageView *assetSelectorIconImageView;

@property (nonatomic, strong) UIView *amountCard;            // 卡片式金额输入（白卡+弱阴影）
@property (nonatomic, strong) UILabel *amountRowLabel;
@property (nonatomic, strong) UITextField *amountField;
@property (nonatomic, strong) UILabel *amountFieldAssetLabel;
@property (nonatomic, strong) UIView *amountSeparatorLine;   // 金额输入框下方分割线
@property (nonatomic, strong) UILabel *remarkRowLabel;     // 添加转账说明
@property (nonatomic, strong) UITextField *remarkField;

/// 底部固定自定义数字键盘
@property (nonatomic, strong) UIView *keypadContainer;
@property (nonatomic, strong) UIButton *transferButton;

@property (nonatomic, copy) NSMutableString *amountStr;
@property (nonatomic, copy) NSString *selectedAssetType;
@property (nonatomic, copy) NSString *cnyAssetBalanceText;
@property (nonatomic, copy) NSString *trxAssetBalanceText;
@property (nonatomic, copy) NSString *usdtAssetBalanceText;
@property (nonatomic, strong) UIView *assetPickerOverlayView;
@property (nonatomic, strong) UIView *assetPickerPanelView;
@property (nonatomic, strong) UIScrollView *assetPickerScrollView;
@property (nonatomic, assign) BOOL rb_isCheckingFundPasswordGate;
@end

@implementation WalletTransferViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = CardBgGray;
    _amountStr = [NSMutableString stringWithString:@"0"];
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"转账"];
    self.selectedAssetType = (self.presetAssetType.length > 0 ? self.presetAssetType.uppercaseString : @"CNY");
    self.cnyAssetBalanceText = @"--";
    self.trxAssetBalanceText = @"--";
    self.usdtAssetBalanceText = @"--";

    // 用户信息区域（设计图：浅灰背景、左「转账给+微信号」右头像、留白简洁）
    self.userInfoArea = [[UIView alloc] initWithFrame:CGRectZero];
    self.userInfoArea.backgroundColor = CardBgGray;
    [self.contentView addSubview:self.userInfoArea];
    self.userInfoTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.userInfoTitleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    self.userInfoTitleLabel.textColor = HexColor(0x333333);
    self.userInfoTitleLabel.textAlignment = NSTextAlignmentLeft;
    self.userInfoTitleLabel.numberOfLines = 1;
    [self.userInfoArea addSubview:self.userInfoTitleLabel];
    self.userInfoSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.userInfoSubtitleLabel.font = [UIFont systemFontOfSize:14];
    self.userInfoSubtitleLabel.textColor = HexColor(0x999999);
    self.userInfoSubtitleLabel.textAlignment = NSTextAlignmentLeft;
    self.userInfoSubtitleLabel.numberOfLines = 1;
    [self.userInfoArea addSubview:self.userInfoSubtitleLabel];
    self.userInfoAvatarView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.userInfoAvatarView.backgroundColor = HexColor(0xE5E5E5);
    self.userInfoAvatarView.layer.cornerRadius = 8;
    self.userInfoAvatarView.clipsToBounds = YES;
    self.userInfoAvatarView.contentMode = UIViewContentModeScaleAspectFill;
    [self.userInfoArea addSubview:self.userInfoAvatarView];

    // 无收款人时：内容区顶栏（选择收款人 / 输入 Chat ID）
    self.recipientBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.recipientBar.backgroundColor = [UIColor whiteColor];
    self.recipientBar.layer.cornerRadius = kCardRadius;
    [self.recipientBar addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onHeaderCardTapped)]];
    self.recipientBar.userInteractionEnabled = YES;
    self.selectRecipientHint = [[UILabel alloc] initWithFrame:CGRectZero];
    self.selectRecipientHint.text = @"选择收款人";
    self.selectRecipientHint.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    self.selectRecipientHint.textColor = HintBlueGray;
    [self.recipientBar addSubview:self.selectRecipientHint];
    self.chevronLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.chevronLabel.text = @"›";
    self.chevronLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightMedium];
    self.chevronLabel.textColor = HexColor(0xC7C7CC);
    [self.recipientBar addSubview:self.chevronLabel];
    self.toUidField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.toUidField.placeholder = @"收款方 Chat ID";
    self.toUidField.font = [UIFont systemFontOfSize:16];
    self.toUidField.textColor = HexColor(0x333333);
    self.toUidField.borderStyle = UITextBorderStyleNone;
    self.toUidField.hidden = YES;
    self.toUidField.delegate = self;
    self.toUidField.returnKeyType = UIReturnKeyDone;
    [self.recipientBar addSubview:self.toUidField];

    self.assetSelectorBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.assetSelectorBar.backgroundColor = HexColor(0xECECEC);
    self.assetSelectorBar.layer.cornerRadius = 14.f;
    UITapGestureRecognizer *assetTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAssetSelectorTapped)];
    assetTap.cancelsTouchesInView = NO;
    [self.assetSelectorBar addGestureRecognizer:assetTap];
    self.assetSelectorBar.userInteractionEnabled = YES;

    self.assetSelectorTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.assetSelectorTitleLabel.hidden = YES;
    [self.assetSelectorBar addSubview:self.assetSelectorTitleLabel];

    self.assetSelectorIconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.assetSelectorIconImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.assetSelectorBar addSubview:self.assetSelectorIconImageView];

    self.assetSelectorAmountLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.assetSelectorAmountLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.assetSelectorAmountLabel.textColor = HexColor(0x111111);
    self.assetSelectorAmountLabel.textAlignment = NSTextAlignmentRight;
    [self.assetSelectorBar addSubview:self.assetSelectorAmountLabel];

    self.assetSelectorValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.assetSelectorValueLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.assetSelectorValueLabel.textColor = HexColor(0x111111);
    self.assetSelectorValueLabel.textAlignment = NSTextAlignmentLeft;
    [self.assetSelectorBar addSubview:self.assetSelectorValueLabel];

    self.assetSelectorChevronLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.assetSelectorChevronLabel.text = @"›";
    self.assetSelectorChevronLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    self.assetSelectorChevronLabel.textColor = HexColor(0xC7C7CC);
    [self.assetSelectorBar addSubview:self.assetSelectorChevronLabel];

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.scrollView];
    self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.scrollView addSubview:self.contentView];
    [self.contentView addSubview:self.userInfoArea];
    [self.contentView addSubview:self.recipientBar];

    // ② 中部金额区域：整块白底，只保留顶部圆角
    self.amountCard = [[UIView alloc] initWithFrame:CGRectZero];
    self.amountCard.backgroundColor = [UIColor whiteColor];
    self.amountCard.layer.cornerRadius = 20.f;
    self.amountCard.layer.shadowOpacity = 0.f;
    self.amountCard.clipsToBounds = YES;
    [self.contentView addSubview:self.amountCard];
    [self.amountCard addSubview:self.assetSelectorBar];

    self.amountRowLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.amountRowLabel.text = @"转账金额";
    self.amountRowLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    self.amountRowLabel.textColor = HexColor(0x333333);
    [self.amountCard addSubview:self.amountRowLabel];

    self.amountField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.amountField.placeholder = @"0.0";
    self.amountField.font = [UIFont systemFontOfSize:28 weight:UIFontWeightSemibold];
    self.amountField.textColor = HexColor(0x333333);
    self.amountField.tintColor = WXGreen;
    self.amountField.borderStyle = UITextBorderStyleNone;
    self.amountField.delegate = self;
    self.amountField.textAlignment = NSTextAlignmentLeft;
    self.amountField.inputView = [[UIView alloc] init];
    self.amountField.rightViewMode = UITextFieldViewModeNever;
    [self.amountField addTarget:self action:@selector(amountFieldDidChange) forControlEvents:UIControlEventEditingChanged];
    [self.amountCard addSubview:self.amountField];

    self.amountSeparatorLine = [[UIView alloc] initWithFrame:CGRectZero];
    self.amountSeparatorLine.backgroundColor = HexColor(0xE5E5E5);
    [self.amountCard addSubview:self.amountSeparatorLine];

    self.remarkRowLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.remarkRowLabel.text = @"添加转账说明";
    self.remarkRowLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.remarkRowLabel.textColor = HintBlueGray;
    [self.amountCard addSubview:self.remarkRowLabel];

    self.remarkField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.remarkField.placeholder = @"选填";
    self.remarkField.font = [UIFont systemFontOfSize:15];
    self.remarkField.textColor = HexColor(0x333333);
    self.remarkField.borderStyle = UITextBorderStyleNone;
    self.remarkField.delegate = self;
    self.remarkField.returnKeyType = UIReturnKeyDone;
    [self.amountCard addSubview:self.remarkField];

    // ③ 底部固定自定义数字键盘（功能强化型）：背景浅灰、转账3格高、0键2格宽
    [self buildKeypad];

    [self updateAssetSelectorUI];
    [self updateRecipientUI];
    [self syncAmountFromField];
    [self rb_loadAssetBalances];
}

- (NSString *)displayNameForUid:(NSString *)uid
{
    if (uid.length == 0) return @"";
    NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid ?: @"";
    if ([uid isEqualToString:localUid]) {
        UserEntity *me = [[IMClientManager sharedInstance] localUserInfo];
        return (me.nickname.length > 0 ? me.nickname : @"我");
    }
    UserEntity *friend = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:uid];
    if (friend) {
        NSString *nick = [friend getNickNameWithRemark];
        return (nick.length > 0 ? nick : @"用户");
    }
    return @"用户";
}

- (NSString *)resolveRecipientDisplayName
{
    if (self.recipientDisplayName.length > 0) return self.recipientDisplayName;
    return [self displayNameForUid:self.toUid ?: @""];
}

- (NSArray<NSString *> *)supportedAssetTypes
{
    return @[@"CNY", @"TRX", @"USDT"];
}

- (NSString *)displayAssetType
{
    return (self.selectedAssetType.length > 0 ? self.selectedAssetType : @"CNY");
}

- (NSString *)assetBalanceTextForType:(NSString *)assetType
{
    if ([assetType isEqualToString:@"TRX"]) {
        return (self.trxAssetBalanceText.length > 0 ? self.trxAssetBalanceText : @"--");
    }
    if ([assetType isEqualToString:@"USDT"]) {
        return (self.usdtAssetBalanceText.length > 0 ? self.usdtAssetBalanceText : @"--");
    }
    return (self.cnyAssetBalanceText.length > 0 ? self.cnyAssetBalanceText : @"--");
}

- (NSString *)assetOptionTitleForType:(NSString *)assetType
{
    return [NSString stringWithFormat:@"%@ %@", assetType, [self assetBalanceTextForType:assetType]];
}

- (NSArray<NSDictionary *> *)paymentMethodItems
{
    return @[
        @{ @"asset_type": @"CNY", @"title": @"CNY", @"subtitle": @"平台币余额" },
        @{ @"asset_type": @"USDT", @"title": @"USDT", @"subtitle": @"Tron(TRC20)" },
        @{ @"asset_type": @"TRX", @"title": @"TRX", @"subtitle": @"Tron(TRC20)" }
    ];
}

- (NSString *)fiatDisplayTextForAssetType:(NSString *)assetType
{
    NSString *balance = [self assetBalanceTextForType:assetType];
    if ([assetType isEqualToString:@"CNY"]) {
        return [NSString stringWithFormat:@"¥%@", balance];
    }
    return @"$0.00";
}

- (UIImage *)walletTokenIconForAssetType:(NSString *)assetType
{
    NSString *imageName = @"wallet_token_cny";
    if ([assetType isEqualToString:@"TRX"]) {
        imageName = @"wallet_token_trx";
    } else if ([assetType isEqualToString:@"USDT"]) {
        imageName = @"wallet_token_usdt";
    }
    return [UIImage imageNamed:imageName];
}

- (NSArray<NSString *> *)assetOptionTitles
{
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    for (NSString *assetType in [self supportedAssetTypes]) {
        [titles addObject:[self assetOptionTitleForType:assetType]];
    }
    return titles;
}

- (NSString *)rb_displayBalanceTextFromValue:(id)value
{
    NSString *text = nil;
    if (value && value != [NSNull null]) {
        text = [[value description] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return (text.length > 0 ? text : @"--");
}

- (void)rb_loadAssetBalances
{
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletBalanceWithComplete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!(sucess && [data isKindOfClass:[NSDictionary class]])) return;
            id pb = data[@"available_balance"] ?: data[@"balance"] ?: data[@"platform_balance"] ?: data[@"platformBalance"];
            wself.cnyAssetBalanceText = [wself rb_displayBalanceTextFromValue:pb];
            [wself updateAssetSelectorUI];
        });
    } hudParentView:nil];

    [[HttpRestHelper sharedInstance] submitTrxWalletAssetBalanceWithComplete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!(sucess && [data isKindOfClass:[NSDictionary class]])) return;
            NSDictionary *trxObj = [data[@"trx"] isKindOfClass:[NSDictionary class]] ? data[@"trx"] : nil;
            NSDictionary *usdtObj = [data[@"usdt"] isKindOfClass:[NSDictionary class]] ? data[@"usdt"] : nil;
            id trxV = trxObj[@"available_balance"] ?: trxObj[@"balance"];
            id usdtV = usdtObj[@"available_balance"] ?: usdtObj[@"balance"];
            wself.trxAssetBalanceText = [wself rb_displayBalanceTextFromValue:trxV];
            wself.usdtAssetBalanceText = [wself rb_displayBalanceTextFromValue:usdtV];
            [wself updateAssetSelectorUI];
        });
    } hudParentView:nil];
}

- (void)updateAssetSelectorUI
{
    self.assetSelectorAmountLabel.text = [self assetBalanceTextForType:[self displayAssetType]];
    self.assetSelectorValueLabel.text = [self displayAssetType];
    self.assetSelectorIconImageView.image = [self walletTokenIconForAssetType:[self displayAssetType]];
}

- (void)rb_dismissAssetPicker
{
    if (!self.assetPickerOverlayView || self.assetPickerOverlayView.superview == nil) return;
    CGFloat panelHeight = self.assetPickerPanelView.bounds.size.height;
    [UIView animateWithDuration:0.25 animations:^{
        self.assetPickerOverlayView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.0];
        self.assetPickerPanelView.frame = CGRectOffset(self.assetPickerPanelView.frame, 0, panelHeight);
    } completion:^(BOOL finished) {
        [self.assetPickerOverlayView removeFromSuperview];
    }];
}

- (void)rb_assetPickerBackgroundTapped
{
    [self rb_dismissAssetPicker];
}

- (void)rb_assetOptionTapped:(UITapGestureRecognizer *)tap
{
    NSInteger index = tap.view.tag - 16000;
    NSArray<NSDictionary *> *items = [self paymentMethodItems];
    if (index < 0 || index >= (NSInteger)items.count) return;
    NSString *assetType = [items[index][@"asset_type"] description];
    if (assetType.length > 0) {
        self.selectedAssetType = assetType;
        [self updateAssetSelectorUI];
    }
    [self rb_dismissAssetPicker];
}

- (void)rb_presentAssetPicker
{
    if (self.assetPickerOverlayView.superview != nil) return;

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    UIView *overlay = [[UIView alloc] initWithFrame:self.view.bounds];
    overlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.0];
    [overlay addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rb_assetPickerBackgroundTapped)]];

    UIView *panel = [[UIView alloc] initWithFrame:CGRectZero];
    panel.backgroundColor = [UIColor whiteColor];
    panel.layer.cornerRadius = 18.f;
    panel.clipsToBounds = YES;
    [overlay addSubview:panel];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.text = @"选择付款方式";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    titleLabel.textColor = HexColor(0x111111);
    [panel addSubview:titleLabel];

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scrollView.showsVerticalScrollIndicator = NO;
    [panel addSubview:scrollView];

    NSArray<NSDictionary *> *items = [self paymentMethodItems];
    CGFloat margin = 16.f;
    CGFloat rowH = 86.f;
    CGFloat rowGap = 14.f;
    CGFloat panelW = w;
    CGFloat panelMaxH = MIN(h * 0.72f, 130.f + items.count * (rowH + rowGap));
    CGFloat scrollTop = 64.f;
    CGFloat scrollH = panelMaxH - scrollTop - 12.f;
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *item = items[i];
        NSString *assetType = [item[@"asset_type"] description];
        NSString *title = [item[@"title"] description];
        NSString *subtitle = [item[@"subtitle"] description];

        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(margin, i * (rowH + rowGap), panelW - margin * 2, rowH)];
        row.tag = 16000 + i;
        row.backgroundColor = [UIColor whiteColor];
        row.layer.cornerRadius = 14.f;
        row.layer.borderWidth = [[self displayAssetType] isEqualToString:assetType] ? 2.f : 1.f;
        row.layer.borderColor = ([[self displayAssetType] isEqualToString:assetType] ? HexColor(0x2F5DFF) : HexColor(0xE5E7EB)).CGColor;
        row.userInteractionEnabled = YES;
        [row addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rb_assetOptionTapped:)]];

        UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(16, 20, 46, 46)];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.image = [self walletTokenIconForAssetType:assetType];
        [row addSubview:iconView];

        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(76, 16, 150, 24)];
        nameLabel.text = title;
        nameLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        nameLabel.textColor = HexColor(0x111111);
        [row addSubview:nameLabel];

        UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(76, 44, 170, 20)];
        subLabel.text = subtitle;
        subLabel.font = [UIFont systemFontOfSize:13];
        subLabel.textColor = HexColor(0x9CA3AF);
        [row addSubview:subLabel];

        UILabel *amountLabel = [[UILabel alloc] initWithFrame:CGRectMake(row.bounds.size.width - 116, 16, 96, 24)];
        amountLabel.text = [self assetBalanceTextForType:assetType];
        amountLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        amountLabel.textColor = HexColor(0x111111);
        amountLabel.textAlignment = NSTextAlignmentRight;
        [row addSubview:amountLabel];

        UILabel *fiatLabel = [[UILabel alloc] initWithFrame:CGRectMake(row.bounds.size.width - 116, 44, 96, 18)];
        fiatLabel.text = [self fiatDisplayTextForAssetType:assetType];
        fiatLabel.font = [UIFont systemFontOfSize:12];
        fiatLabel.textColor = HexColor(0x9CA3AF);
        fiatLabel.textAlignment = NSTextAlignmentRight;
        [row addSubview:fiatLabel];

        [scrollView addSubview:row];
    }
    scrollView.contentSize = CGSizeMake(panelW, items.count * (rowH + rowGap));

    self.assetPickerOverlayView = overlay;
    self.assetPickerPanelView = panel;
    self.assetPickerScrollView = scrollView;

    titleLabel.frame = CGRectMake(20, 18, panelW - 40, 30);
    scrollView.frame = CGRectMake(0, scrollTop, panelW, scrollH);
    panel.frame = CGRectMake(0, h, panelW, panelMaxH);
    [self.view addSubview:overlay];

    [UIView animateWithDuration:0.25 animations:^{
        overlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.42];
        panel.frame = CGRectMake(0, h - panelMaxH, panelW, panelMaxH);
    }];
}

- (void)onAssetSelectorTapped
{
    [self rb_presentAssetPicker];
}

- (BOOL)rb_shouldSendAsFriendChatToUid:(NSString *)uid
{
    if (uid.length == 0) return NO;
    return [[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster:uid];
}

- (void)rb_notifyPreviousChatIfNeeded
{
    UIViewController *prev = nil;
    if (self.navigationController.viewControllers.count >= 2) {
        prev = self.navigationController.viewControllers[self.navigationController.viewControllers.count - 2];
    }
    if ([prev isKindOfClass:[ChatRootViewController class]]) {
        [(ChatRootViewController *)prev rb_notifyExternalOutgoingMessageAppended];
    }
}

- (void)rb_appendOutgoingTransferMessageWithJSON:(NSString *)mJson
                                            toUid:(NSString *)toUid
                                           amount:(NSString *)amountStr
                                           remark:(NSString *)remark
{
    NSString *safeUid = toUid ?: @"";
    if (safeUid.length == 0 || mJson.length == 0) return;

    NSString *fp = [Protocal genFingerPrint];
    NSString *displayName = [self displayNameForUid:safeUid];

    if ([self rb_shouldSendAsFriendChatToUid:safeUid]) {
        NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid;
        MsgBody4Friend *msgBody = [MsgBody4Friend constructFriendChatMsgBody:localUid t:safeUid m:mJson ty:TM_TYPE_TRANSFER];
        int code = [MessageHelper sendChatMessage:safeUid withMessage:msgBody finger:fp];
        if (code == COMMON_CODE_OK) {
            JSQMessage *entity = [JSQMessage createChatMsgEntity_OUTGO_JSONContent:mJson msgType:TM_TYPE_TRANSFER withFingerPrint:fp];
            [ChatDataHelper addChatMessageData_outgoing:safeUid withData:entity];
            [AlarmsProvider addSingleChatMsgAlarmForLocal:safeUid friendName:displayName withMsg:@"[转账]" andType:TM_TYPE_TRANSFER withAlarmType:AMT_friendChatMessage];
            [self rb_notifyPreviousChatIfNeeded];
        }
        return;
    }

    MsgBody4Guest *guestBody = [TMessageHelper constructTempChatMsgDTOForSend:TM_TYPE_TRANSFER friendUid:safeUid withMsg:mJson];
    int code = [TMessageHelper sendTempChatMsg_A_TO_SERVER_Message:guestBody qos:YES fp:fp];
    if (code == COMMON_CODE_OK) {
        JSQMessage *entity = [JSQMessage createChatMsgEntity_OUTGO_JSONContent:mJson msgType:TM_TYPE_TRANSFER withFingerPrint:fp];
        [TChatDataHelper addChatMessageData_outgoing:safeUid withData:entity];
        [AlarmsProvider addSingleChatMsgAlarmForLocal:safeUid friendName:displayName withMsg:@"[转账]" andType:TM_TYPE_TRANSFER withAlarmType:AMT_guestChatMessage];
        [self rb_notifyPreviousChatIfNeeded];
    }
}

- (void)buildKeypad
{
    self.keypadContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.keypadContainer.backgroundColor = CardBgGray;
    [self.view addSubview:self.keypadContainer];

    CGFloat pad = 8.f;
    CGFloat w = self.view.bounds.size.width;
    if (w <= 0) w = 375;
    CGFloat keyW = (w - pad * 5) / 4.f;
    CGFloat keyH = (kKeypadHeight - pad * 5 - 34) / 4.f;
    if (keyH > 56) keyH = 56;

    NSArray *row1 = @[@"1", @"2", @"3"];
    NSArray *row2 = @[@"4", @"5", @"6"];
    NSArray *row3 = @[@"7", @"8", @"9"];
    NSArray *row4 = @[@"0", @"."];
    NSArray *rows = @[row1, row2, row3, row4];
    for (NSInteger r = 0; r < rows.count; r++) {
        NSArray *arr = rows[r];
        for (NSInteger c = 0; c < arr.count; c++) {
            NSString *title = arr[c];
            UIButton *btn = [self keypadButtonWithTitle:title];
            btn.frame = CGRectMake(pad + c * (keyW + pad), 34 + pad + r * (keyH + pad), keyW, keyH);
            [btn addTarget:self action:@selector(onKeypadDigit:) forControlEvents:UIControlEventTouchUpInside];
            [self.keypadContainer addSubview:btn];
        }
    }
    UIButton *delBtn = [self keypadButtonWithTitle:@""];
    [delBtn setImage:[self keypadDeleteImage] forState:UIControlStateNormal];
    delBtn.tintColor = [UIColor blackColor];
    delBtn.frame = CGRectMake(w - pad - keyW, 34 + pad, keyW, keyH);
    [delBtn addTarget:self action:@selector(onKeypadDelete) forControlEvents:UIControlEventTouchUpInside];
    [self.keypadContainer addSubview:delBtn];

    self.transferButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.transferButton setTitle:@"转账" forState:UIControlStateNormal];
    [self.transferButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.transferButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    self.transferButton.backgroundColor = WXGreen;
    self.transferButton.layer.cornerRadius = kKeypadKeyRadius;
    self.transferButton.frame = CGRectMake(w - pad - keyW, 34 + pad + (keyH + pad), keyW, keyH * 3 + pad * 2);
    [self.transferButton addTarget:self action:@selector(onTransfer) forControlEvents:UIControlEventTouchUpInside];
    [self.keypadContainer addSubview:self.transferButton];
}

- (UIButton *)keypadButtonWithTitle:(NSString *)title
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightRegular];
    btn.backgroundColor = [UIColor whiteColor];
    btn.layer.cornerRadius = kKeypadKeyRadius;
    btn.layer.borderWidth = 0.5f;
    btn.layer.borderColor = HexColor(0xE5E5E5).CGColor;
    return btn;
}

- (UIImage *)keypadDeleteImage
{
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"delete.left"];
        if (img) return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(24, 24)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        [[UIColor blackColor] setStroke];
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(8, 12)];
        [p addLineToPoint:CGPointMake(16, 12)];
        p.lineWidth = 2;
        [p stroke];
        [[UIColor blackColor] setFill];
        UIBezierPath *arrow = [UIBezierPath bezierPath];
        [arrow moveToPoint:CGPointMake(10, 8)];
        [arrow addLineToPoint:CGPointMake(6, 12)];
        [arrow addLineToPoint:CGPointMake(10, 16)];
        [arrow fill];
    }];
}

- (void)onKeypadDigit:(UIButton *)sender
{
    NSString *ch = [sender titleForState:UIControlStateNormal];
    if (ch.length == 0) return;
    NSString *current = self.amountField.text ?: @"";
    NSString *newText = [current stringByAppendingString:ch];
    if ([ch isEqualToString:@"."]) {
        if ([current containsString:@"."] || current.length == 0) return;
    } else {
        NSArray *parts = [newText componentsSeparatedByString:@"."];
        if (parts.count > 2) return;
        if (parts.count == 2 && [(NSString *)parts[1] length] > 2) return;
        if ([current isEqualToString:@"0"] && ![ch isEqualToString:@"."]) newText = ch;
    }
    self.amountField.text = newText;
    [self amountFieldDidChange];
}

- (void)onKeypadDelete
{
    NSString *s = self.amountField.text ?: @"";
    if (s.length == 0) return;
    self.amountField.text = [s substringToIndex:s.length - 1];
    [self amountFieldDidChange];
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
    [self rb_checkFundPasswordGateAndRedirectIfNeeded];
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

- (void)rb_checkFundPasswordGateAndRedirectIfNeeded
{
    if (self.rb_isCheckingFundPasswordGate) return;
    if (self.navigationController.topViewController != self) return;
    self.rb_isCheckingFundPasswordGate = YES;
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletCheckFundPasswordStatusWithComplete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (!sself) return;
            sself.rb_isCheckingFundPasswordGate = NO;
            if (sself.navigationController.topViewController != sself) return;
            if (RBWalletFundPasswordIsSetFromResponse(data)) return;
            WalletFundPasswordViewController *vc = [[WalletFundPasswordViewController alloc] init];
            vc.hidesBottomBarWhenPushed = YES;
            [sself.navigationController pushViewController:vc animated:YES];
        });
    } hudParentView:nil];
}

- (void)updateRecipientUI
{
    BOOL hasRecipient = (self.toUid.length > 0 || self.recipientDisplayName.length > 0);
    BOOL fromGroupNoRecipient = (self.groupId.length > 0 && !hasRecipient);

    if (hasRecipient) {
        self.navigationItem.title = @"转账";
        NSString *name = [self resolveRecipientDisplayName];
        self.userInfoTitleLabel.text = [NSString stringWithFormat:@"转账给 %@", name];
        NSString *idStr = self.recipientWechatId.length > 0 ? self.recipientWechatId : (self.toUid ?: @"");
        self.userInfoSubtitleLabel.text = idStr.length > 0 ? [NSString stringWithFormat:@"Chat ID: %@", idStr] : @"";
        self.userInfoSubtitleLabel.hidden = (idStr.length == 0);
        self.userInfoAvatarView.image = [UIImage imageNamed:@"default_avatar_60"];
        if (self.toUid.length > 0) {
            __weak typeof(self) wself = self;
            [FileDownloadHelper loadUserAvatarWithUID:self.toUid logTag:@"Transfer-UserInfoAvatar" complete:^(BOOL sucess, UIImage *img) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (img && wself.userInfoAvatarView) wself.userInfoAvatarView.image = img;
                });
            } donotLoadFromDisk:NO];
        }
        self.userInfoArea.hidden = NO;
        self.recipientBar.hidden = YES;
    } else {
        self.navigationItem.title = fromGroupNoRecipient ? @"选择收款人" : @"转账";
        self.userInfoArea.hidden = YES;
        self.recipientBar.hidden = NO;
        self.selectRecipientHint.hidden = fromGroupNoRecipient ? NO : YES;
        self.chevronLabel.hidden = fromGroupNoRecipient ? NO : YES;
        self.toUidField.hidden = fromGroupNoRecipient ? YES : NO;
    }
}

- (void)onHeaderCardTapped
{
    if (self.groupId.length > 0 && self.toUid.length == 0) {
        [self openGroupMemberPicker];
    }
}

- (void)openGroupMemberPicker
{
    GroupMemberViewController *vc = [ViewControllerFactory goGroupMemberViewController:self.navigationController
                                                                                 usedFor:USED_FOR_SELECT_FOR_WALLET_TRANSFER
                                                                                     gid:self.groupId
                                                                            isGroupOwner:NO
                                                                     defaultSelectedUid:nil];
    __weak typeof(self) wself = self;
    vc.onSingleMemberSelected = ^(GroupMemberEntity * _Nullable member) {
        if (member && member.user_uid.length > 0) {
            wself.toUid = member.user_uid;
            wself.recipientDisplayName = [GroupsProvider getNickNameInGroup:member.nickname and:member.nickname_ingroup] ?: member.user_uid;
            wself.recipientWechatId = nil;
            [wself updateRecipientUI];
        }
    };
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

    // 底部固定键盘
    CGFloat keypadH = kKeypadHeight + safeBottom;
    self.keypadContainer.frame = CGRectMake(0, h - keypadH, w, keypadH);
    CGFloat pad = 8.f;
    CGFloat keyW = (w - pad * 5) / 4.f;
    CGFloat keyH = (kKeypadHeight - pad * 5 - 34) / 4.f;
    if (keyH > 56) keyH = 56;
    CGFloat zeroW = keyW * 2 + pad;
    for (NSInteger i = 0; i < self.keypadContainer.subviews.count; i++) {
        UIView *v = self.keypadContainer.subviews[i];
        if ([v isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)v;
            if (btn == self.transferButton) {
                btn.frame = CGRectMake(w - pad - keyW, 34 + pad + (keyH + pad), keyW, keyH * 3 + pad * 2);
            } else if (btn.currentImage != nil) {
                btn.frame = CGRectMake(w - pad - keyW, 34 + pad, keyW, keyH);
            } else {
                NSString *title = [btn titleForState:UIControlStateNormal] ?: @"";
                if ([title isEqualToString:@"0"]) {
                    btn.frame = CGRectMake(pad, 34 + pad + 3 * (keyH + pad), zeroW, keyH);
                } else if ([title isEqualToString:@"."]) {
                    btn.frame = CGRectMake(pad + zeroW + pad, 34 + pad + 3 * (keyH + pad), keyW, keyH);
                } else {
                    NSInteger r = 0, c = 0;
                    if ([title isEqualToString:@"1"]) { r = 0; c = 0; }
                    else if ([title isEqualToString:@"2"]) { r = 0; c = 1; }
                    else if ([title isEqualToString:@"3"]) { r = 0; c = 2; }
                    else if ([title isEqualToString:@"4"]) { r = 1; c = 0; }
                    else if ([title isEqualToString:@"5"]) { r = 1; c = 1; }
                    else if ([title isEqualToString:@"6"]) { r = 1; c = 2; }
                    else if ([title isEqualToString:@"7"]) { r = 2; c = 0; }
                    else if ([title isEqualToString:@"8"]) { r = 2; c = 1; }
                    else if ([title isEqualToString:@"9"]) { r = 2; c = 2; }
                    else continue;
                    btn.frame = CGRectMake(pad + c * (keyW + pad), 34 + pad + r * (keyH + pad), keyW, keyH);
                }
            }
        }
    }

    // 上内容区：scrollView 在键盘上方
    CGFloat margin = kCardMargin;
    CGFloat cardW = w - margin * 2;
    CGFloat leftPad = kCardLeftPad;
    CGFloat rightPad = kCardRightPad;
    CGFloat rowH = kRowH;
    CGFloat y = 16;

    self.scrollView.frame = CGRectMake(0, 0, w, h - keypadH);

    CGFloat userInfoH = 72;
    CGFloat avatarSize = 48;
    if (!self.userInfoArea.hidden) {
        self.userInfoArea.frame = CGRectMake(0, y, w, userInfoH);
        CGFloat textW = w - margin * 2 - leftPad - rightPad - avatarSize - 12;
        self.userInfoTitleLabel.frame = CGRectMake(margin + leftPad, 20, textW, 22);
        self.userInfoSubtitleLabel.frame = CGRectMake(margin + leftPad, 42, textW, 18);
        self.userInfoAvatarView.frame = CGRectMake(w - margin - rightPad - avatarSize, (userInfoH - avatarSize) / 2, avatarSize, avatarSize);
        self.userInfoAvatarView.layer.cornerRadius = avatarSize * 0.5f;
        y += userInfoH + 12;
    } else {
        self.userInfoArea.frame = CGRectMake(0, y, w, 0);
    }

    CGFloat recipientBarH = 52;
    if (!self.recipientBar.hidden) {
        self.recipientBar.frame = CGRectMake(margin, y, cardW, recipientBarH);
        self.selectRecipientHint.frame = CGRectMake(leftPad, 0, cardW - leftPad - rightPad - 28, recipientBarH);
        self.chevronLabel.frame = CGRectMake(cardW - rightPad - 24, (recipientBarH - 28) / 2, 24, 28);
        self.toUidField.frame = CGRectMake(leftPad, 8, cardW - leftPad - rightPad, 36);
        y += recipientBarH + 12;
    } else {
        self.recipientBar.frame = CGRectMake(margin, y, cardW, 0);
    }

    y += 8;

    CGFloat amountRowH = kAmountFieldHeight;
    CGFloat amountTop = 14;
    CGFloat amountLabelH = 24;
    CGFloat contentBottom = h - keypadH;
    CGFloat amountCardH = 192.f;
    CGFloat cardWFull = w;
    CGFloat cardPad = 16.f;
    self.amountCard.frame = CGRectMake(0, y, cardWFull, amountCardH);
    self.amountCard.layer.cornerRadius = 20.f;
    if (@available(iOS 11.0, *)) {
        self.amountCard.layer.maskedCorners = (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner);
    }
    self.amountRowLabel.frame = CGRectMake(cardPad, amountTop, 90, amountLabelH);
    CGFloat chipW = MIN(196.f, cardW * 0.52f);
    CGFloat chipH = 42.f;
    self.assetSelectorBar.frame = CGRectMake(cardWFull - cardPad - chipW, 8.f, chipW, chipH);
    self.assetSelectorAmountLabel.frame = CGRectMake(10.f, 0, 44.f, chipH);
    self.assetSelectorIconImageView.frame = CGRectMake(56.f, 9.f, 24.f, 24.f);
    self.assetSelectorValueLabel.frame = CGRectMake(84.f, 0, chipW - 110.f, chipH);
    self.assetSelectorChevronLabel.frame = CGRectMake(chipW - 20.f, 0, 16.f, chipH);
    self.amountField.frame = CGRectMake(cardPad, 68.f, cardWFull - cardPad * 2, 40.f);
    CGFloat separatorY = 126.f;
    self.amountSeparatorLine.frame = CGRectMake(cardPad, separatorY, cardWFull - cardPad * 2, 0.5);
    CGFloat remarkY = separatorY + 0.5;
    CGFloat remarkRowH = kRowH;
    self.remarkRowLabel.frame = CGRectMake(cardPad, remarkY, 100, remarkRowH);
    self.remarkField.frame = CGRectMake(cardPad + 100, remarkY, cardWFull - cardPad * 2 - 100, remarkRowH);

    CGFloat contentH = CGRectGetMaxY(self.amountCard.frame) + 16.f;
    self.contentView.frame = CGRectMake(0, 0, w, MAX(contentBottom, contentH));
    self.scrollView.contentSize = CGSizeMake(w, self.contentView.bounds.size.height);
}

- (void)syncAmountFromField
{
    NSString *t = [self.amountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (t.length > 0) [_amountStr setString:t];
    else [_amountStr setString:@"0"];
}

- (void)amountFieldDidChange
{
    [self syncAmountFromField];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField != self.amountField) return YES;
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (newText.length == 0) return YES;
    if ([newText hasPrefix:@"."]) return NO;
    NSArray *parts = [newText componentsSeparatedByString:@"."];
    if (parts.count > 2) return NO;
    if (parts.count == 2 && [(NSString *)parts[1] length] > 2) return NO;
    return YES;
}

- (void)onTransfer
{
    [self.view endEditing:YES];
    [self syncAmountFromField];
    NSString *toUid = self.toUid.length > 0 ? self.toUid : [self.toUidField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (toUid.length == 0) {
        if (self.groupId.length > 0) {
            [BasicTool showAlertInfo:@"请选择收款人" parent:self];
        } else {
            [BasicTool showAlertInfo:@"请填写收款方" parent:self];
        }
        return;
    }
    double yuan = [_amountStr doubleValue];
    if (yuan <= 0) {
        [BasicTool showAlertInfo:@"请输入转账金额" parent:self];
        return;
    }
    NSString *remark = [self.remarkField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    __weak typeof(self) wself = self;
    // 转账前先检测是否已设置资金密码，未设置则跳转设置页
    [[HttpRestHelper sharedInstance] submitWalletCheckFundPasswordStatusWithComplete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL hasSet = RBWalletFundPasswordIsSetFromResponse(data);
            if (!hasSet) {
                WalletFundPasswordViewController *vc = [[WalletFundPasswordViewController alloc] init];
                vc.hidesBottomBarWhenPushed = YES;
                [wself.navigationController pushViewController:vc animated:YES];
                return;
            }
            WalletFundPasswordInputViewController *pwdVC = [[WalletFundPasswordInputViewController alloc] init];
            pwdVC.titleText = @"转账";
            pwdVC.amountText = [NSString stringWithFormat:@"%@ %.2f", [wself displayAssetType], yuan];
            pwdVC.onComplete = ^(NSString *password) {
                [wself dismissViewControllerAnimated:YES completion:^{
                    [wself doTransferToUid:toUid amountYuan:yuan remark:remark fundPassword:password];
                }];
            };
            pwdVC.onCancel = ^{};
            [wself presentViewController:pwdVC animated:YES completion:nil];
        });
    } hudParentView:self.view];
}

- (void)doTransferToUid:(NSString *)toUid amountYuan:(double)yuan remark:(NSString *)remark fundPassword:(NSString *)fundPassword
{
    long long amountCent = (long long)(yuan * 100);
    NSString *idempotentKey = [NSString stringWithFormat:@"%@_%lld_%lld", toUid, (long long)amountCent, (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
    __weak typeof(self) wself = self;
    NSString *groupId = self.groupId.length > 0 ? self.groupId : nil;
    [[HttpRestHelper sharedInstance] submitWalletTransferToUid:toUid amountCent:amountCent remark:remark idempotentKey:idempotentKey fundPassword:fundPassword groupId:groupId complete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg = @"转账失败";
            if ([data isKindOfClass:[NSDictionary class]] && data[@"msg"]) {
                msg = [[data[@"msg"] description] length] > 0 ? [data[@"msg"] description] : msg;
            }
            if (!sucess) {
                if ([msg containsString:@"余额不足"] || [msg containsString:@"java."] || [msg containsString:@"Exception"]) {
                    msg = @"余额不足";
                }
                [BasicTool showAlertInfo:msg parent:wself];
            }
            if (sucess) {
                NSString *amountStr = [NSString stringWithFormat:@"%.2f", yuan];
                NSDictionary *mDict = @{ @"amount": amountStr,
                                         @"remark": (remark ?: @""),
                                         @"to_uid": (toUid ?: @""),
                                         @"asset_type": [wself displayAssetType] };
                NSString *mJson = [EVAToolKits toJSON:mDict];
                [wself rb_appendOutgoingTransferMessageWithJSON:mJson toUid:toUid amount:amountStr remark:remark];
                [wself.navigationController popViewControllerAnimated:YES];
            } else if ([msg isEqualToString:@"请先设置资金密码"]) {
                WalletFundPasswordViewController *vc = [[WalletFundPasswordViewController alloc] init];
                vc.hidesBottomBarWhenPushed = YES;
                [wself.navigationController pushViewController:vc animated:YES];
            }
        });
    } hudParentView:self.view];
}

@end
