#import "WalletRedPacketSendViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "WalletFundPasswordViewController.h"
#import "WalletFundPasswordInputViewController.h"
#import "MessageHelper.h"
#import "GMessageHelper.h"
#import "ChatDataHelper.h"
#import "GChatDataHelper.h"
#import "AlarmsProvider.h"
#import "AlarmType.h"
#import "MsgBody4Friend.h"
#import "MsgBody4Group.h"
#import "Protocal.h"
#import "EVAToolKits.h"
#import "JSQMessage.h"
#import "ErrorCode.h"
#import "IMClientManager.h"
#import "GroupsProvider.h"
#import "GroupEntity.h"
#import "ViewControllerFactory.h"
#import "GroupMemberViewController.h"
#import "GroupMemberEntity.h"
#import "ChatRootViewController.h"
#import "LPActionSheet.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]
#define WXRed       HexColor(0xE64340)  // 微信红包红
#define OrangeRed   HexColor(0xFF6B00)  // 设计图主按钮橙色
#define TypeGold    HexColor(0xC9A227)  // 切换红包类型文案与箭头的金橙色
#define CardBgGray  HexColor(0xF5F5F5)  // 设计图卡片浅灰背景

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

@interface WalletRedPacketSendViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIView *typeSelectorBarView;  // 群聊时：导航栏下方切换类型条（普通/拼手气 + ∨）
@property (nonatomic, strong) UILabel *paymentMethodSectionLabel;
@property (nonatomic, strong) UIView *assetSelectorBarView;
@property (nonatomic, strong) UIImageView *assetSelectorIconImageView;
@property (nonatomic, strong) UILabel *assetSelectorTitleLabel;
@property (nonatomic, strong) UILabel *assetSelectorValueLabel;
@property (nonatomic, strong) UILabel *assetSelectorChevronLabel;
@property (nonatomic, strong) UILabel *assetSelectorHintLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *card1;  // 红包设置（个数+总金额 或 仅总金额）
@property (nonatomic, strong) UIView *card2;  // 祝福语
@property (nonatomic, strong) UIView *card3;  // 红包封面（设计图第三行，可点击）
@property (nonatomic, strong) UIImageView *redPacketTopBgView;  // 红包区域顶部背景图（红色信封顶部）
@property (nonatomic, strong) UIView *redPacketCountIconView;   // 红色方块+白圆
@property (nonatomic, strong) UIView *totalAmountIconView;      // 橙色方块+白字「拼」
@property (nonatomic, strong) UILabel *countRowLabel;           // 「红包个数」
@property (nonatomic, strong) UITextField *totalCountField;
@property (nonatomic, strong) UILabel *countUnitLabel;          // 「个」
@property (nonatomic, strong) UILabel *groupMemberCountLabel;   // 「本群共X人」
@property (nonatomic, strong) UIView *exclusiveRowView;         // 专属红包：指定领取人一行（可点选人）
@property (nonatomic, strong) UILabel *exclusiveRowLabel;
@property (nonatomic, strong) UILabel *exclusiveValueLabel;
@property (nonatomic, copy) NSString *exclusiveReceiverUid;     // 专属红包选中的群成员 uid
@property (nonatomic, copy) NSString *exclusiveReceiverDisplayName;
@property (nonatomic, strong) UIView *card1Separator;
@property (nonatomic, strong) UILabel *totalAmountRowLabel;      // 「总金额」或「单个金额」
@property (nonatomic, strong) UITextField *totalAmountField;
@property (nonatomic, strong) UILabel *totalAmountFieldAssetLabel;
@property (nonatomic, strong) UITextField *messageField;
@property (nonatomic, strong) UILabel *bottomAmountLabel;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UILabel *tipLabel;
@property (nonatomic, strong) UIImageView *messageSmileyView;   // 祝福语右侧表情图标
@property (nonatomic, assign) int packetType;
@property (nonatomic, assign) BOOL isPrivateChat;
@property (nonatomic, assign) BOOL hasShownCountExceedHint;  // 个数超出群人数时是否已提示过
@property (nonatomic, copy) NSString *selectedAssetType;
@property (nonatomic, copy) NSString *cnyAssetBalanceText;
@property (nonatomic, copy) NSString *trxAssetBalanceText;
@property (nonatomic, copy) NSString *usdtAssetBalanceText;
@property (nonatomic, strong) UIView *assetPickerOverlayView;
@property (nonatomic, strong) UIView *assetPickerPanelView;
@property (nonatomic, strong) UIScrollView *assetPickerScrollView;
@property (nonatomic, assign) BOOL rb_isCheckingFundPasswordGate;
@end

@implementation WalletRedPacketSendViewController

- (UIView *)makeRedCountIconView
{
    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    icon.image = [UIImage imageNamed:@"red_packet_count_icon" inBundle:[NSBundle mainBundle] compatibleWithTraitCollection:nil];
    icon.contentMode = UIViewContentModeScaleAspectFill;
    icon.clipsToBounds = YES;
    icon.layer.cornerRadius = 4;
    return icon;
}

- (UIView *)makeTotalAmountIconView
{
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    box.backgroundColor = OrangeRed;
    box.layer.cornerRadius = 4;
    box.clipsToBounds = YES;
    UILabel *l = [[UILabel alloc] initWithFrame:box.bounds];
    l.text = @"拼";
    l.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    l.textColor = [UIColor whiteColor];
    l.textAlignment = NSTextAlignmentCenter;
    [box addSubview:l];
    return box;
}

- (NSString *)packetTypeDisplayName
{
    switch (self.packetType) {
        case 1: return @"普通红包";
        case 2: return @"拼手气红包";
        case 3: return @"专属红包";
        default: return @"普通红包";
    }
}

- (void)updateTypeTitleView
{
    UILabel *l = [self.typeSelectorBarView viewWithTag:9001];
    if ([l isKindOfClass:[UILabel class]]) {
        l.text = [self packetTypeDisplayName];
    }
}

- (void)onTypeTitleTapped
{
    if (self.isPrivateChat) return;
    __weak typeof(self) wself = self;
    // 使用 LPActionSheet：从底部全宽弹起、白底圆角、三选项+取消带间距，与设计图一致（避免 iPad 上系统 ActionSheet 显示为居中带尾的 popover）
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"拼手气红包", @"普通红包", @"专属红包"]
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == 0) return; // 取消
        int prev = wself.packetType;
        if (index == 1) wself.packetType = 2;      // 拼手气
        else if (index == 2) wself.packetType = 1;  // 普通
        else if (index == 3) wself.packetType = 3; // 专属
        [wself updateTypeTitleView];
        [wself applyTypeChangedFromType:prev];
    }];
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

- (NSString *)paymentMethodSubtitleForType:(NSString *)assetType
{
    if ([assetType isEqualToString:@"TRX"]) {
        return @"Tron(TRC20)";
    }
    if ([assetType isEqualToString:@"USDT"]) {
        return @"Tron(TRC20)";
    }
    return @"平台币余额";
}

- (NSString *)paymentMethodPrimaryTitle
{
    return @"我的钱包";
}

- (NSString *)paymentMethodBalanceDisplay
{
    NSString *balance = [self assetBalanceTextForType:[self displayAssetType]];
    return [NSString stringWithFormat:@"%@ %@", balance, [self displayAssetType]];
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

- (NSArray<NSDictionary *> *)paymentMethodItems
{
    return @[
        @{ @"asset_type": @"CNY", @"title": @"CNY", @"subtitle": @"平台币余额" },
        @{ @"asset_type": @"USDT", @"title": @"USDT", @"subtitle": @"Tron(TRC20)" },
        @{ @"asset_type": @"TRX", @"title": @"TRX", @"subtitle": @"Tron(TRC20)" }
    ];
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
    NSInteger index = tap.view.tag - 12000;
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
    panel.layer.cornerRadius = 22.f;
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
        row.tag = 12000 + i;
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
        fiatLabel.text = [assetType isEqualToString:@"CNY"] ? [NSString stringWithFormat:@"¥%@", [self assetBalanceTextForType:assetType]] : @"$0.00";
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
    self.assetSelectorTitleLabel.text = [self paymentMethodPrimaryTitle];
    self.assetSelectorValueLabel.text = [self paymentMethodBalanceDisplay];
    self.assetSelectorHintLabel.text = @"";
    self.assetSelectorHintLabel.hidden = YES;
    self.assetSelectorIconImageView.image = [self walletTokenIconForAssetType:[self displayAssetType]];
    self.totalAmountFieldAssetLabel.text = @"";
    [self onAmountChanged];
}

- (void)onAssetSelectorTapped
{
    [self rb_presentAssetPicker];
}

- (void)applyTypeChangedFromType:(int)previousType
{
    if (self.isPrivateChat) return;
    self.totalCountField.enabled = YES;
    if (self.packetType == 2 && (self.totalCountField.text.length == 0 || [self.totalCountField.text isEqualToString:@"1"])) {
        self.totalCountField.text = @"";
    }
    if (self.packetType == 3) {
        self.totalCountField.text = @"1";
        if (self.initialExclusiveReceiverUid.length > 0) {
            self.exclusiveReceiverUid = self.initialExclusiveReceiverUid;
            self.exclusiveReceiverDisplayName = (self.initialExclusiveReceiverDisplayName.length > 0) ? self.initialExclusiveReceiverDisplayName : self.initialExclusiveReceiverUid;
            self.exclusiveValueLabel.text = self.exclusiveReceiverDisplayName;
            self.exclusiveValueLabel.textColor = HexColor(0x333333);
        } else {
            self.exclusiveReceiverUid = nil;
            self.exclusiveReceiverDisplayName = nil;
            self.exclusiveValueLabel.text = @"请选择";
        }
    }
    self.totalAmountRowLabel.text = (self.packetType == 1) ? @"单个金额" : @"总金额";

    // 普通↔拼手气 切换时，按含义换算金额并更新输入框与底部展示
    double numVal = [[self amountNumberStringFromField] doubleValue];
    NSString *countStr = [self.totalCountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    int count = countStr.length > 0 ? [countStr intValue] : 0;

    if (previousType == 1 && self.packetType == 2) {
        // 普通 → 拼手气：当前是单个金额，总金额 = 单个 × 个数
        double total = numVal * (count > 0 ? count : 1);
        self.totalAmountField.text = [NSString stringWithFormat:@"%.2f", total];
    } else if (previousType == 2 && self.packetType == 1) {
        // 拼手气 → 普通：当前是总金额，单个 = 总金额 / 个数
        if (count > 0 && numVal > 0) {
            double single = numVal / (double)count;
            self.totalAmountField.text = [NSString stringWithFormat:@"%.2f", single];
        }
    }

    [self onAmountChanged];
    [self.view setNeedsLayout];
}

- (BOOL)isSingleAmountType
{
    return (self.packetType == 1 && !self.isPrivateChat);
}

- (void)updateAmountRowLabelForCurrentType
{
    if (self.isPrivateChat) {
        self.totalAmountRowLabel.text = @"金额";
    } else {
        self.totalAmountRowLabel.text = [self isSingleAmountType] ? @"单个金额" : @"总金额";
    }
}

- (void)onCoverRowTapped
{
    [BasicTool showAlertInfo:@"红包封面功能敬请期待" parent:self];
}

- (void)onExclusiveRowTapped
{
    if (self.packetType != 3 || self.groupId.length == 0) return;
    GroupMemberViewController *vc = [ViewControllerFactory goGroupMemberViewController:self.navigationController
                                                                               usedFor:USED_FOR_SELECT_FOR_WALLET_TRANSFER
                                                                                   gid:self.groupId
                                                                          isGroupOwner:NO
                                                                   defaultSelectedUid:self.exclusiveReceiverUid];
    __weak typeof(self) wself = self;
    vc.onSingleMemberSelected = ^(GroupMemberEntity * _Nullable member) {
        if (member && member.user_uid.length > 0) {
            wself.exclusiveReceiverUid = member.user_uid;
            wself.exclusiveReceiverDisplayName = [GroupsProvider getNickNameInGroup:member.nickname and:member.nickname_ingroup] ?: member.user_uid;
            wself.exclusiveValueLabel.text = wself.exclusiveReceiverDisplayName;
            wself.exclusiveValueLabel.textColor = HexColor(0x333333);
        }
    };
}

- (void)onCancelTapped
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = HexColor(0xF2F2F2);
    if (self.initialPacketType >= 1 && self.initialPacketType <= 3) {
        self.packetType = self.initialPacketType;
    } else {
        self.packetType = 2;  // 默认拼手气红包
    }
    self.isPrivateChat = (self.receiverType == 1);
    self.selectedAssetType = (self.presetAssetType.length > 0 ? self.presetAssetType.uppercaseString : @"CNY");
    self.cnyAssetBalanceText = @"--";
    self.trxAssetBalanceText = @"--";
    self.usdtAssetBalanceText = @"--";
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"发红包"];
    RBChromeNavigationBar *chrome = [self rb_plainChromeNavigationBarIfInstalled];
    if (chrome != nil) {
        [chrome setBackButtonTarget:self action:@selector(onCancelTapped)];
    }

    if (!self.isPrivateChat) {
        self.typeSelectorBarView = [[UIView alloc] initWithFrame:CGRectZero];
        self.typeSelectorBarView.backgroundColor = [UIColor clearColor];
        UILabel *typeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        typeLabel.tag = 9001;
        typeLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        typeLabel.textColor = TypeGold;
        typeLabel.text = [self packetTypeDisplayName];  // 默认「拼手气红包」
        [self.typeSelectorBarView addSubview:typeLabel];
        UIImageView *arrowView = [[UIImageView alloc] initWithFrame:CGRectZero];
        arrowView.tag = 9002;
        if (@available(iOS 13.0, *)) {
            arrowView.image = [UIImage systemImageNamed:@"chevron.down"];
        }
        arrowView.tintColor = TypeGold;
        arrowView.contentMode = UIViewContentModeCenter;
        [self.typeSelectorBarView addSubview:arrowView];
        [self.typeSelectorBarView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTypeTitleTapped)]];
        self.typeSelectorBarView.userInteractionEnabled = YES;
        [self.view addSubview:self.typeSelectorBarView];
    }

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.scrollView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentView.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.contentView];

    self.paymentMethodSectionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.paymentMethodSectionLabel.text = @"付款方式";
    self.paymentMethodSectionLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.paymentMethodSectionLabel.textColor = HexColor(0x111111);
    [self.contentView addSubview:self.paymentMethodSectionLabel];

    self.assetSelectorBarView = [[UIView alloc] initWithFrame:CGRectZero];
    self.assetSelectorBarView.backgroundColor = [UIColor whiteColor];
    self.assetSelectorBarView.layer.cornerRadius = 14.f;
    self.assetSelectorBarView.clipsToBounds = YES;
    [self.assetSelectorBarView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAssetSelectorTapped)]];
    self.assetSelectorBarView.userInteractionEnabled = YES;
    [self.contentView addSubview:self.assetSelectorBarView];

    self.assetSelectorIconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.assetSelectorIconImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.assetSelectorBarView addSubview:self.assetSelectorIconImageView];

    self.assetSelectorTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.assetSelectorTitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.assetSelectorTitleLabel.textColor = HexColor(0x333333);
    [self.assetSelectorBarView addSubview:self.assetSelectorTitleLabel];

    self.assetSelectorValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.assetSelectorValueLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.assetSelectorValueLabel.textColor = HexColor(0x111111);
    self.assetSelectorValueLabel.textAlignment = NSTextAlignmentLeft;
    [self.assetSelectorBarView addSubview:self.assetSelectorValueLabel];

    self.assetSelectorHintLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.assetSelectorHintLabel.font = [UIFont systemFontOfSize:12];
    self.assetSelectorHintLabel.textColor = HexColor(0x9CA3AF);
    self.assetSelectorHintLabel.textAlignment = NSTextAlignmentLeft;
    self.assetSelectorHintLabel.hidden = YES;
    [self.assetSelectorBarView addSubview:self.assetSelectorHintLabel];

    self.assetSelectorChevronLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.assetSelectorChevronLabel.text = @"更换 >";
    self.assetSelectorChevronLabel.font = [UIFont systemFontOfSize:15];
    self.assetSelectorChevronLabel.textColor = HexColor(0x9CA3AF);
    self.assetSelectorChevronLabel.textAlignment = NSTextAlignmentRight;
    [self.assetSelectorBarView addSubview:self.assetSelectorChevronLabel];

    // 红包区域顶部背景图（红色信封顶部，含年份与吉祥文案）
    self.redPacketTopBgView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.redPacketTopBgView.image = [UIImage imageNamed:@"red_packet_top_bg"];
    self.redPacketTopBgView.contentMode = UIViewContentModeScaleAspectFill;
    self.redPacketTopBgView.clipsToBounds = YES;
    self.redPacketTopBgView.hidden = YES;  // 不展示顶部红色区域
    [self.contentView addSubview:self.redPacketTopBgView];

    CGFloat margin = 12;
    CGFloat cardW = self.view.bounds.size.width - margin * 2;
    CGFloat leftPad = 16;
    CGFloat rightPad = 16;
    CGFloat rowH = 52;
    const CGFloat iconSize = 24;

    // ---------- 第一张卡：红包设置（设计图浅灰卡片）----------
    self.card1 = [[UIView alloc] initWithFrame:CGRectZero];
    self.card1.backgroundColor = [UIColor whiteColor];
    self.card1.layer.cornerRadius = 16.f;
    self.card1.clipsToBounds = YES;
    [self.contentView addSubview:self.card1];

    if (!self.isPrivateChat) {
        self.redPacketCountIconView = [self makeRedCountIconView];
        [self.card1 addSubview:self.redPacketCountIconView];

        self.countRowLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.countRowLabel.text = @"红包个数";
        self.countRowLabel.font = [UIFont systemFontOfSize:17];
        self.countRowLabel.textColor = HexColor(0x333333);
        [self.card1 addSubview:self.countRowLabel];

        self.totalCountField = [[UITextField alloc] initWithFrame:CGRectZero];
        self.totalCountField.placeholder = @"填写红包个数";
        self.totalCountField.keyboardType = UIKeyboardTypeNumberPad;
        self.totalCountField.font = [UIFont systemFontOfSize:17];
        self.totalCountField.textAlignment = NSTextAlignmentRight;
        self.totalCountField.textColor = HexColor(0x333333);
        [self.totalCountField addTarget:self action:@selector(onAmountChanged) forControlEvents:UIControlEventEditingChanged];
        [self.card1 addSubview:self.totalCountField];

        self.countUnitLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.countUnitLabel.text = @"个";
        self.countUnitLabel.font = [UIFont systemFontOfSize:17];
        self.countUnitLabel.textColor = HexColor(0x333333);
        [self.card1 addSubview:self.countUnitLabel];

        self.groupMemberCountLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.groupMemberCountLabel.font = [UIFont systemFontOfSize:13];
        self.groupMemberCountLabel.textColor = HexColor(0x999999);
        GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.groupId];
        int n = ge.g_member_count.length > 0 ? [ge.g_member_count intValue] : 0;
        self.groupMemberCountLabel.text = [NSString stringWithFormat:@"本群共%d人", n];
        [self.card1 addSubview:self.groupMemberCountLabel];

        self.card1Separator = [[UIView alloc] init];
        self.card1Separator.backgroundColor = HexColor(0xE5E5E5);
        [self.card1 addSubview:self.card1Separator];

        self.exclusiveRowView = [[UIView alloc] initWithFrame:CGRectZero];
        self.exclusiveRowLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.exclusiveRowLabel.text = @"指定领取人";
        self.exclusiveRowLabel.font = [UIFont systemFontOfSize:17];
        self.exclusiveRowLabel.textColor = HexColor(0x333333);
        [self.exclusiveRowView addSubview:self.exclusiveRowLabel];
        self.exclusiveValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.exclusiveValueLabel.text = @"请选择";
        self.exclusiveValueLabel.font = [UIFont systemFontOfSize:17];
        self.exclusiveValueLabel.textColor = HexColor(0x999999);
        self.exclusiveValueLabel.textAlignment = NSTextAlignmentRight;
        [self.exclusiveRowView addSubview:self.exclusiveValueLabel];
        [self.exclusiveRowView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onExclusiveRowTapped)]];
        self.exclusiveRowView.userInteractionEnabled = YES;
        [self.card1 addSubview:self.exclusiveRowView];
        // 从群聊头像长按「发送专属红包」进入时，预设指定领取人
        if (self.packetType == 3 && self.initialExclusiveReceiverUid.length > 0) {
            self.exclusiveReceiverUid = self.initialExclusiveReceiverUid;
            self.exclusiveReceiverDisplayName = (self.initialExclusiveReceiverDisplayName.length > 0) ? self.initialExclusiveReceiverDisplayName : self.initialExclusiveReceiverUid;
            self.exclusiveValueLabel.text = self.exclusiveReceiverDisplayName;
            self.exclusiveValueLabel.textColor = HexColor(0x333333);
        }
    }

    self.totalAmountIconView = [self makeTotalAmountIconView];
    [self.card1 addSubview:self.totalAmountIconView];

    self.totalAmountRowLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [self updateAmountRowLabelForCurrentType];
    self.totalAmountRowLabel.font = [UIFont systemFontOfSize:17];
    self.totalAmountRowLabel.textColor = HexColor(0x333333);
    [self.card1 addSubview:self.totalAmountRowLabel];

    self.totalAmountField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.totalAmountField.text = @"";
    self.totalAmountField.textAlignment = NSTextAlignmentRight;
    self.totalAmountField.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    self.totalAmountField.textColor = HexColor(0x333333);
    self.totalAmountField.placeholder = @"0.00";
    self.totalAmountField.keyboardType = UIKeyboardTypeDecimalPad;
    self.totalAmountField.delegate = self;
    UIView *amountRightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 86, rowH)];
    self.totalAmountFieldAssetLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 78, rowH)];
    self.totalAmountFieldAssetLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    self.totalAmountFieldAssetLabel.textColor = HexColor(0x333333);
    self.totalAmountFieldAssetLabel.textAlignment = NSTextAlignmentRight;
    [amountRightView addSubview:self.totalAmountFieldAssetLabel];
    self.totalAmountField.rightView = amountRightView;
    self.totalAmountField.rightViewMode = UITextFieldViewModeNever;
    [self.totalAmountField addTarget:self action:@selector(onAmountChanged) forControlEvents:UIControlEventEditingChanged];
    [self.card1 addSubview:self.totalAmountField];

    // ---------- 第二张卡：祝福语（设计图浅灰卡片 + 右侧表情）----------
    self.card2 = [[UIView alloc] initWithFrame:CGRectZero];
    self.card2.backgroundColor = [UIColor whiteColor];
    self.card2.layer.cornerRadius = 16.f;
    self.card2.clipsToBounds = YES;
    [self.contentView addSubview:self.card2];

    self.messageField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.messageField.placeholder = @"恭喜发财，大吉大利";
    self.messageField.font = [UIFont systemFontOfSize:17];
    self.messageField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"恭喜发财，大吉大利"
                                                                              attributes:@{ NSForegroundColorAttributeName: HexColor(0x999999) }];
    self.messageField.textColor = HexColor(0x333333);
    self.messageField.text = @"";
    self.messageField.textAlignment = NSTextAlignmentLeft;
    self.messageField.delegate = self;
    self.messageField.returnKeyType = UIReturnKeyDone;
    [self.messageField addTarget:self action:@selector(onMessageFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.card2 addSubview:self.messageField];
    self.messageSmileyView = [[UIImageView alloc] initWithFrame:CGRectZero];
    if (@available(iOS 13.0, *)) {
        self.messageSmileyView.image = [UIImage systemImageNamed:@"face.smiling"];
    }
    self.messageSmileyView.tintColor = HexColor(0x999999);
    self.messageSmileyView.contentMode = UIViewContentModeCenter;
    self.messageSmileyView.hidden = YES;
    [self.card2 addSubview:self.messageSmileyView];

    // ---------- 第三张卡：红包封面（设计图）----------
    self.card3 = [[UIView alloc] initWithFrame:CGRectZero];
    self.card3.backgroundColor = CardBgGray;
    self.card3.layer.cornerRadius = 8;
    self.card3.clipsToBounds = YES;
    [self.card3 addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onCoverRowTapped)]];
    self.card3.userInteractionEnabled = YES;
    self.card3.hidden = YES;  // 不展示红包封面区域
    [self.contentView addSubview:self.card3];
    UILabel *coverLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    coverLabel.tag = 8001;
    coverLabel.text = @"红包封面";
    coverLabel.font = [UIFont systemFontOfSize:17];
    coverLabel.textColor = HexColor(0x333333);
    [self.card3 addSubview:coverLabel];
    UIImageView *coverArrow = [[UIImageView alloc] initWithFrame:CGRectZero];
    coverArrow.tag = 8002;
    if (@available(iOS 13.0, *)) {
        coverArrow.image = [UIImage systemImageNamed:@"chevron.right"];
    }
    coverArrow.tintColor = HexColor(0x999999);
    coverArrow.contentMode = UIViewContentModeCenter;
    [self.card3 addSubview:coverArrow];

    // ---------- 底部 ----------
    self.bottomAmountLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bottomAmountLabel.font = [UIFont systemFontOfSize:48 weight:UIFontWeightMedium];
    self.bottomAmountLabel.textAlignment = NSTextAlignmentCenter;
    self.bottomAmountLabel.textColor = HexColor(0x111111);
    self.bottomAmountLabel.text = [NSString stringWithFormat:@"%@ 0.00", [self displayAssetType]];
    [self.contentView addSubview:self.bottomAmountLabel];

    self.submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.submitButton setTitle:@"塞钱进红包" forState:UIControlStateNormal];
    [self.submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    self.submitButton.backgroundColor = HexColor(0xFF2B2B);
    self.submitButton.layer.cornerRadius = 12.f;
    [self.submitButton addTarget:self action:@selector(onSubmit) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.submitButton];

    self.tipLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.tipLabel.text = [NSString stringWithFormat:@"对方可领取的红包金额为0.01%@起", [self displayAssetType]];
    self.tipLabel.font = [UIFont systemFontOfSize:12];
    self.tipLabel.textAlignment = NSTextAlignmentCenter;
    self.tipLabel.textColor = HexColor(0x999999);
    self.tipLabel.numberOfLines = 2;
    self.tipLabel.hidden = YES;
    [self.contentView addSubview:self.tipLabel];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    [self applyTypeChangedFromType:self.packetType];
    [self updateAmountRowLabelForCurrentType];
    [self updateAssetSelectorUI];
    [self rb_loadAssetBalances];
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

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat safeTop = 0;
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = self.view.safeAreaInsets.top;
        safeBottom = self.view.safeAreaInsets.bottom;
    }

    const CGFloat typeBarH = 44;
    if (self.typeSelectorBarView) {
        self.typeSelectorBarView.frame = CGRectMake(0, safeTop, w, typeBarH);
        UILabel *typeLabel = [self.typeSelectorBarView viewWithTag:9001];
        UIView *arrowView = [self.typeSelectorBarView viewWithTag:9002];
        const CGFloat typeBarLeft = 16;
        const CGFloat typeLabelW = 90;
        const CGFloat arrowWidth = 20;
        if ([typeLabel isKindOfClass:[UILabel class]]) {
            typeLabel.frame = CGRectMake(typeBarLeft, 0, typeLabelW, typeBarH);
            typeLabel.textAlignment = NSTextAlignmentLeft;
        }
        if (arrowView) {
            arrowView.frame = CGRectMake(typeBarLeft + typeLabelW, 0, arrowWidth, typeBarH);
        }
    }

    CGFloat scrollTop = safeTop + (self.typeSelectorBarView ? typeBarH : 0);
    self.scrollView.frame = CGRectMake(0, scrollTop, w, h - scrollTop);
    self.contentView.frame = CGRectMake(0, 0, w, 0);

    CGFloat margin = 20;
    CGFloat cardW = w - margin * 2;
    CGFloat leftPad = 16;
    CGFloat rightPad = 16;
    CGFloat rowH = 64;
    const CGFloat iconSize = 24;
    const CGFloat cardGap = 16;
    const CGFloat topBgH = 0;  // 顶部红色区域已隐藏

    self.redPacketTopBgView.frame = CGRectMake(0, 0, w, topBgH);
    CGFloat y = 16;

    // ---------- 第一张卡 ----------
    CGFloat card1Y = 0;
    CGFloat card1H;
    if (self.isPrivateChat) {
        card1H = rowH;
        self.totalAmountIconView.hidden = YES;
        self.totalAmountRowLabel.frame = CGRectMake(leftPad, 0, 110, rowH);
        self.totalAmountField.frame = CGRectMake(leftPad + 110, 0, cardW - leftPad - rightPad - 110, rowH);
    } else {
        BOOL isExclusive = (self.packetType == 3);
        self.exclusiveRowView.hidden = !isExclusive;
        self.redPacketCountIconView.hidden = YES;
        self.countRowLabel.hidden = isExclusive;
        self.totalCountField.hidden = isExclusive;
        self.countUnitLabel.hidden = isExclusive;
        self.groupMemberCountLabel.hidden = isExclusive;
        self.card1Separator.hidden = NO;

        CGFloat subY = 0;
        if (isExclusive) {
            self.exclusiveRowView.frame = CGRectMake(0, 0, cardW, rowH);
            self.exclusiveRowLabel.frame = CGRectMake(leftPad, 0, 100, rowH);
            self.exclusiveValueLabel.frame = CGRectMake(leftPad + 100, 0, cardW - leftPad - rightPad - 100, rowH);
            subY = rowH + 10;
        } else {
            self.countRowLabel.frame = CGRectMake(leftPad, 0, 80, rowH);
            self.countUnitLabel.frame = CGRectMake(cardW - rightPad - 24, 0, 20, rowH);
            self.totalCountField.frame = CGRectMake(cardW - rightPad - 24 - 118, 0, 115, rowH);
            subY = rowH + 6;
            self.groupMemberCountLabel.frame = CGRectMake(leftPad, subY, cardW - leftPad - rightPad, 18);
            subY += 18 + 10;
        }
        self.card1Separator.frame = CGRectMake(leftPad, subY - 0.5, cardW - leftPad * 2, 0.5);
        subY += 10;
        self.totalAmountIconView.hidden = YES;
        self.totalAmountRowLabel.frame = CGRectMake(leftPad, subY, 110, rowH);
        self.totalAmountField.frame = CGRectMake(leftPad + 110, subY, cardW - leftPad - rightPad - 110, rowH);
        card1H = subY + rowH;
    }
    self.totalAmountField.rightView.frame = CGRectMake(0, 0, 86, rowH);
    self.totalAmountFieldAssetLabel.frame = CGRectMake(0, 0, 78, rowH);
    self.card1.frame = CGRectMake(margin, y, cardW, card1H);
    y += card1H + cardGap;

    // ---------- 第二张卡 ----------
    self.card2.frame = CGRectMake(margin, y, cardW, rowH);
    self.messageSmileyView.frame = CGRectZero;
    self.messageField.frame = CGRectMake(leftPad, 0, cardW - leftPad - rightPad, rowH);
    y += rowH + cardGap;

    self.paymentMethodSectionLabel.frame = CGRectMake(margin, y + 2, cardW, 24);
    y += 30;

    CGFloat paymentCardH = 76.f;
    self.assetSelectorBarView.frame = CGRectMake(margin, y, cardW, paymentCardH);
    self.assetSelectorIconImageView.frame = CGRectMake(leftPad, 18, 40, 40);
    self.assetSelectorTitleLabel.frame = CGRectMake(leftPad + 50, 17, 92, 20);
    self.assetSelectorValueLabel.frame = CGRectMake(leftPad + 50, 38, cardW - leftPad - rightPad - 116, 22);
    self.assetSelectorHintLabel.frame = CGRectMake(0, 0, 0, 0);
    self.assetSelectorChevronLabel.frame = CGRectMake(cardW - rightPad - 52, 0, 52, paymentCardH);
    y += paymentCardH + 28;

    // ---------- 第三张卡：红包封面（已隐藏，不占位）----------
    self.card3.frame = CGRectMake(margin, y, cardW, 0);
    self.card3.hidden = YES;
    UILabel *coverLabel = [self.card3 viewWithTag:8001];
    UIImageView *coverArrow = [self.card3 viewWithTag:8002];
    if ([coverLabel isKindOfClass:[UILabel class]]) {
        coverLabel.frame = CGRectMake(leftPad, 0, 120, rowH);
    }
    if (coverArrow) {
        coverArrow.frame = CGRectMake(cardW - rightPad - 20, 0, 20, rowH);
    }
    y += 0;  // 不占高度

    // ---------- 底部 ----------
    self.bottomAmountLabel.frame = CGRectMake(0, y, w, 72);
    y += 88;
    CGFloat btnW = MIN(180.f, cardW);
    CGFloat btnH = 56.f;
    self.submitButton.frame = CGRectMake((w - btnW) * 0.5f, y, btnW, btnH);
    y += btnH + 20;
    self.tipLabel.frame = CGRectMake(margin, y, cardW, 36);
    y = CGRectGetMaxY(self.tipLabel.frame) + 16 + safeBottom;

    self.contentView.frame = CGRectMake(0, 0, w, y);
    self.scrollView.contentSize = CGSizeMake(w, y);
}

- (void)dismissKeyboard
{
    [self.view endEditing:YES];
}

- (NSString *)rb_truncatedString:(NSString *)text maxComposedLength:(NSUInteger)maxLength
{
    if (text.length == 0 || maxLength == 0) return @"";
    __block NSUInteger count = 0;
    __block NSRange finalRange = NSMakeRange(0, 0);
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
        if (count >= maxLength) {
            *stop = YES;
            return;
        }
        finalRange.length = NSMaxRange(substringRange);
        count += 1;
    }];
    if (finalRange.length <= 0 || finalRange.length >= text.length) {
        return text;
    }
    return [text substringToIndex:finalRange.length];
}

- (NSUInteger)rb_composedLengthOfString:(NSString *)text
{
    if (text.length == 0) return 0;
    __block NSUInteger count = 0;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(__unused NSString * _Nullable substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL * _Nonnull stop) {
        count += 1;
    }];
    return count;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == self.messageField) {
        // 中文/第三方输入法组字期间先放行，待上屏后再统一做长度裁剪，避免输入法状态被打断卡住。
        if (textField.markedTextRange != nil) {
            return YES;
        }
        NSString *current = textField.text ?: @"";
        NSString *next = [current stringByReplacingCharactersInRange:range withString:string ?: @""];
        if ([self rb_composedLengthOfString:next] <= 10) {
            return YES;
        }
        textField.text = [self rb_truncatedString:next maxComposedLength:10];
        return NO;
    }
    if (textField != self.totalAmountField) return YES;
    NSString *current = textField.text ?: @"";
    NSString *newNum = [current stringByReplacingCharactersInRange:range withString:string ?: @""];
    NSMutableString *digits = [NSMutableString string];
    BOOL hasDot = NO;
    for (NSUInteger i = 0; i < newNum.length; i++) {
        unichar c = [newNum characterAtIndex:i];
        if (c >= '0' && c <= '9') [digits appendFormat:@"%C", c];
        else if (c == '.' && !hasDot) { [digits appendString:@"."]; hasDot = YES; }
    }
    // 最多 2 位小数
    NSRange dotRange = [[digits copy] rangeOfString:@"."];
    if (dotRange.location != NSNotFound) {
        NSUInteger afterDot = digits.length - (dotRange.location + 1);
        if (afterDot > 2) {
            [digits setString:[[digits substringToIndex:dotRange.location + 1 + 2] copy]];
        }
    }
    NSString *displayNum = [digits copy];
    if ([displayNum isEqualToString:@"."]) displayNum = @"0.";
    if (displayNum.length == 0) displayNum = @"";  // 默认不显示 0，让用户输入
    textField.text = displayNum;
    [self onAmountChanged];  // 下方金额跟着更新
    return NO;
}

- (void)onMessageFieldChanged:(UITextField *)textField
{
    if (textField != self.messageField) {
        return;
    }
    if (textField.markedTextRange != nil) {
        return;
    }
    NSString *current = textField.text ?: @"";
    if ([self rb_composedLengthOfString:current] <= 10) {
        return;
    }
    textField.text = [self rb_truncatedString:current maxComposedLength:10];
}

- (void)onAmountChanged
{
    NSString *numPart = [self amountNumberStringFromField];
    double amount = [numPart doubleValue];
    NSString *show;
    if ([self isSingleAmountType]) {
        int count = [self.totalCountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0
            ? [self.totalCountField.text intValue] : 0;
        double total = amount * (count > 0 ? count : 1);
        show = [NSString stringWithFormat:@"%.2f", total];
    } else {
        show = numPart.length > 0 ? numPart : @"0.00";
    }
    NSString *amountText = [NSString stringWithFormat:@"%@ %@", show, [self displayAssetType]];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:amountText];
    NSRange assetRange = [amountText rangeOfString:[self displayAssetType] options:NSBackwardsSearch];
    [attr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:50 weight:UIFontWeightSemibold] range:NSMakeRange(0, show.length)];
    if (assetRange.location != NSNotFound) {
        [attr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:28 weight:UIFontWeightMedium] range:assetRange];
    }
    [attr addAttribute:NSForegroundColorAttributeName value:HexColor(0x111111) range:NSMakeRange(0, amountText.length)];
    self.bottomAmountLabel.attributedText = attr;
    // 设计图：底部提示随金额更新为「对方可领取的红包金额为0.01~XXX元」
    if (amount > 0) {
        double displayVal = [self isSingleAmountType] ? (amount * ([self.totalCountField.text intValue] ?: 1)) : amount;
        self.tipLabel.text = [NSString stringWithFormat:@"对方可领取的红包金额为0.01~%.2f%@", displayVal, [self displayAssetType]];
    } else {
        self.tipLabel.text = [NSString stringWithFormat:@"对方可领取的红包金额为0.01%@起", [self displayAssetType]];
    }
    // 群聊且非专属：个数输入超出群人数时提示（每轮只提示一次，改回不超后再超会再提示）
    if (!self.isPrivateChat && self.packetType != 3 && self.groupId.length > 0) {
        int count = [self.totalCountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0 ? [self.totalCountField.text intValue] : 0;
        GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.groupId];
        int groupMemberCount = (ge && ge.g_member_count.length > 0) ? [ge.g_member_count intValue] : 0;
        if (count <= groupMemberCount) {
            self.hasShownCountExceedHint = NO;
        } else if (groupMemberCount > 0 && !self.hasShownCountExceedHint) {
            self.hasShownCountExceedHint = YES;
            [BasicTool showAlertInfo:@"红包个数不能超过群人数" parent:self];
        }
    }
}

- (NSString *)amountNumberStringFromField
{
    NSString *t = [self.totalAmountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (t.length == 0) return @"0.00";
    double v = [t doubleValue];
    return [NSString stringWithFormat:@"%.2f", v >= 0 ? v : 0];
}

- (void)onSubmit
{
    NSString *amountStr = [self amountNumberStringFromField];
    NSString *message = [self.messageField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([self rb_composedLengthOfString:message] > 10) {
        message = [self rb_truncatedString:message maxComposedLength:10];
        self.messageField.text = message;
    }
    NSString *countStr = self.isPrivateChat ? @"1" : (self.packetType == 3 ? @"1" : [self.totalCountField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);

    if (self.packetType == 3 && self.exclusiveReceiverUid.length == 0) {
        [BasicTool showAlertInfo:@"请选择专属领取人" parent:self];
        return;
    }

    if (amountStr.length == 0) {
        NSString *msg = [self isSingleAmountType] ? @"请输入单个金额" : @"请输入红包总金额";
        [BasicTool showAlertInfo:msg parent:self];
        return;
    }

    double amount = [amountStr doubleValue];
    if (amount <= 0) {
        [BasicTool showAlertInfo:@"红包金额必须大于0" parent:self];
        return;
    }

    if (self.packetType != 3 && countStr.length == 0) {
        [BasicTool showAlertInfo:@"请输入红包个数" parent:self];
        return;
    }

    int count = (self.packetType == 3) ? 1 : [countStr intValue];
    if (self.packetType != 3 && count <= 0) {
        [BasicTool showAlertInfo:@"红包个数必须大于0" parent:self];
        return;
    }

    // 群聊时：红包个数不能超过群人数
    if (!self.isPrivateChat && self.packetType != 3 && self.groupId.length > 0) {
        GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.groupId];
        int groupMemberCount = (ge && ge.g_member_count.length > 0) ? [ge.g_member_count intValue] : 0;
        if (groupMemberCount > 0 && count > groupMemberCount) {
            [BasicTool showAlertInfo:@"红包个数不能超过群人数" parent:self];
            return;
        }
    }

    if (message.length == 0) {
        message = @"恭喜发财";
    }

    NSString *amountFormatted;
    NSString *amountDisplay;
    if ([self isSingleAmountType]) {
        double totalAmount = amount * count;
        amountFormatted = [NSString stringWithFormat:@"%.2f", totalAmount];
        amountDisplay = [NSString stringWithFormat:@"%@ %@", [self displayAssetType], amountFormatted];
    } else {
        amountFormatted = [NSString stringWithFormat:@"%.2f", amount];
        amountDisplay = [NSString stringWithFormat:@"%@ %@", [self displayAssetType], amountFormatted];
    }

    __weak typeof(self) wself = self;
    NSString *exclusiveUid = (self.packetType == 3 && self.exclusiveReceiverUid.length > 0) ? self.exclusiveReceiverUid : nil;
    // 发红包前先检测是否已设置资金密码，未设置则跳转设置页
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
            pwdVC.titleText = @"红包";
            pwdVC.amountText = amountDisplay;
            pwdVC.onComplete = ^(NSString *password) {
                [wself dismissViewControllerAnimated:YES completion:^{
                    [wself sendRedPacket:amountFormatted totalCount:count message:message fundPassword:password exclusiveReceiverUid:exclusiveUid];
                }];
            };
            pwdVC.onCancel = ^{};
            [wself presentViewController:pwdVC animated:YES completion:nil];
        });
    } hudParentView:self.view];
}

- (void)sendRedPacket:(NSString *)amount totalCount:(int)totalCount message:(NSString *)message fundPassword:(NSString *)fundPassword exclusiveReceiverUid:(NSString *)exclusiveReceiverUid
{
    __weak typeof(self) wself = self;
    void (^completeBlock)(BOOL, NSDictionary *) = ^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess) {
                NSString *packetId = [data isKindOfClass:[NSDictionary class]] ? ([data[@"packet_id"] description] ?: @"") : @"";
                if (packetId.length > 0) {
                    NSMutableDictionary *mDict = [NSMutableDictionary dictionaryWithDictionary:@{
                        @"packet_id": packetId,
                        @"total_amount": amount,
                        @"total_count": @(totalCount),
                        @"message": (message ?: @""),
                        @"packet_type": @(wself.packetType),
                        @"asset_type": [wself displayAssetType]
                    }];
                    if (wself.packetType == 3 && wself.exclusiveReceiverUid.length > 0) {
                        mDict[@"exclusive_receiver_uid"] = wself.exclusiveReceiverUid;
                        if (wself.exclusiveReceiverDisplayName.length > 0) {
                            mDict[@"exclusive_receiver_display_name"] = wself.exclusiveReceiverDisplayName;
                        }
                    }
                    NSString *mJson = [EVAToolKits toJSON:mDict];
                    NSString *fp = [Protocal genFingerPrint];
                    if (wself.receiverType == 1) {
                        NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid;
                        MsgBody4Friend *msgBody = [MsgBody4Friend constructFriendChatMsgBody:localUid t:wself.receiverUid m:mJson ty:TM_TYPE_RED_PACKET];
                        int code = [MessageHelper sendChatMessage:wself.receiverUid withMessage:msgBody finger:fp];
                        if (code == COMMON_CODE_OK) {
                            JSQMessage *entity = [JSQMessage createChatMsgEntity_OUTGO_JSONContent:mJson msgType:TM_TYPE_RED_PACKET withFingerPrint:fp];
                            [ChatDataHelper addChatMessageData_outgoing:wself.receiverUid withData:entity];
                            [AlarmsProvider addSingleChatMsgAlarmForLocal:wself.receiverUid friendName:wself.receiverUid withMsg:@"[红包]" andType:TM_TYPE_RED_PACKET withAlarmType:AMT_friendChatMessage];
                        }
                    } else if (wself.receiverType == 2 && wself.groupId.length > 0) {
                        MsgBody4Group *body = [GMessageHelper constructGroupChatMsgBodyForSend:fp msgType:TM_TYPE_RED_PACKET gid:wself.groupId msg:mJson at:nil];
                        int code = [GMessageHelper sendBBSChatMsg_A_TO_SERVER_Message:body qos:YES fp:fp];
                        if (code == COMMON_CODE_OK) {
                            JSQMessage *entity = [JSQMessage createChatMsgEntity_OUTGO_JSONContent:mJson msgType:TM_TYPE_RED_PACKET withFingerPrint:fp];
                            [GChatDataHelper addChatMessageData_outgoing:wself.groupId withData:entity];
                            NSString *gname = wself.groupId;
                            GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:wself.groupId];
                            if (ge && ge.g_name.length > 0) gname = ge.g_name;
                            [AlarmsProvider addAGroupChatMsgAlarmForLocal:TM_TYPE_RED_PACKET gid:wself.groupId gname:gname msg:@"[红包]"];
                        }
                    }
                    UIViewController *prev = nil;
                    if (wself.navigationController.viewControllers.count >= 2) {
                        prev = wself.navigationController.viewControllers[wself.navigationController.viewControllers.count - 2];
                    }
                    if ([prev isKindOfClass:[ChatRootViewController class]]) {
                        [(ChatRootViewController *)prev rb_notifyExternalOutgoingMessageAppended];
                    }
                }
                [wself.navigationController popViewControllerAnimated:YES];
            } else {
                if ([data isKindOfClass:[NSDictionary class]] && [data[@"need_set_fund_password"] boolValue]) {
                    [BasicTool showAlertInfo:@"请先设置资金密码" parent:wself];
                    WalletFundPasswordViewController *vc = [[WalletFundPasswordViewController alloc] init];
                    [wself.navigationController pushViewController:vc animated:YES];
                } else {
                    // 按接口文档错误码展示：未设置密码(上分支)、密码错误、已冻结、其他业务错误
                    NSString *msg = @"密码错误";  // 发红包失败且刚输入过密码，默认按密码错误提示
                    if ([data isKindOfClass:[NSDictionary class]]) {
                        NSString *serverMsg = data[@"msg"] ? [[data[@"msg"] description] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : nil;
                        if (data[@"frozen_remaining"] != nil && serverMsg.length > 0) {
                            msg = serverMsg;  // 资金密码已冻结，X小时后可重试
                        } else if (data[@"fail_count"] != nil) {
                            msg = @"密码错误";
                        } else if (serverMsg.length > 0) {
                            BOOL isPasswordRelated = [serverMsg isEqualToString:@"发送红包失败"] ||
                                [serverMsg isEqualToString:@"红包发送失败"] ||
                                [serverMsg rangeOfString:@"密码"].location != NSNotFound ||
                                [serverMsg rangeOfString:@"资金密码"].location != NSNotFound;
                            BOOL isBusinessError = [serverMsg rangeOfString:@"余额不足"].location != NSNotFound ||
                                [serverMsg rangeOfString:@"金额"].location != NSNotFound ||
                                [serverMsg rangeOfString:@"0.01"].location != NSNotFound ||
                                [serverMsg rangeOfString:@"接收"].location != NSNotFound ||
                                [serverMsg rangeOfString:@"群"].location != NSNotFound ||
                                [serverMsg rangeOfString:@"红包个数"].location != NSNotFound ||
                                [serverMsg rangeOfString:@"红包总金额"].location != NSNotFound;
                            if (isPasswordRelated) {
                                msg = @"密码错误";
                            } else if (isBusinessError) {
                                msg = serverMsg;  // 可用余额不足、参数错误等原文展示
                            } else {
                                msg = @"密码错误";  // 未识别的失败多为密码错误
                            }
                        }
                    }
                    [BasicTool showAlertInfo:msg parent:wself];
                }
            }
        });
    };

    NSString *exclusiveUid = (exclusiveReceiverUid.length > 0) ? exclusiveReceiverUid : nil;
    if (self.packetType == 2) {
        [[HttpRestHelper sharedInstance] submitWalletSendLuckyRedPacket:self.receiverType receiverUid:self.receiverUid groupId:self.groupId totalAmount:amount totalCount:totalCount message:message fundPassword:fundPassword exclusiveReceiverUid:exclusiveUid complete:completeBlock hudParentView:self.view];
    } else {
        // 普通红包(packetType==1)、专属红包(packetType==3，传 exclusive_receiver_uid 且 totalCount=1) 走普通红包接口
        [[HttpRestHelper sharedInstance] submitWalletSendNormalRedPacket:self.receiverType receiverUid:self.receiverUid groupId:self.groupId totalAmount:amount totalCount:totalCount message:message fundPassword:fundPassword exclusiveReceiverUid:exclusiveUid complete:completeBlock hudParentView:self.view];
    }
}

@end
