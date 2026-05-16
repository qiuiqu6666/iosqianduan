#import "WalletCardWalletViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "WalletBindWithdrawMethodViewController.h"
#import "WalletWithdrawMethodViewController.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]
static const NSInteger kCardWalletGreen = 0x07C160;
static const CGFloat kCardPadding = 16.f;
static const CGFloat kTabHeight = 44.f;
static const CGFloat kSingleCardH = 160.f;
static const CGFloat kPayCardH = 80.f;  // 微信/支付宝单条高度
static const CGFloat kPayCardIconW = 40.f;
static const CGFloat kPayCardIconLeft = 16.f;
static const CGFloat kPayCardIconTextGap = 12.f;  // 图标与文字间距
static const NSInteger kBankCardViewTagBase = 6000;
static const NSInteger kWechatCardViewTagBase = 6100;
static const NSInteger kAlipayCardViewTagBase = 6200;

@interface WalletCardWalletViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *tabScrollView;
@property (nonatomic, strong) UIView *tabUnderlineView;
@property (nonatomic, strong) NSArray<NSString *> *tabTitles;
@property (nonatomic, assign) NSInteger selectedTabIndex;
@property (nonatomic, strong) UIScrollView *contentScrollView;
@property (nonatomic, strong) UIView *bankCardContainerView;
@property (nonatomic, strong) UIView *wechatContainerView;
@property (nonatomic, strong) UIView *alipayContainerView;
@property (nonatomic, strong) UIView *addMethodView;
@property (nonatomic, strong) UIView *wechatAddView;
@property (nonatomic, strong) UIView *alipayAddView;
@property (nonatomic, strong) NSArray *withdrawMethods;
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation WalletCardWalletViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.title = @"卡包";
    _tabTitles = @[@"银行卡", @"微信", @"支付宝"];
    _selectedTabIndex = 0;

    [self buildTabs];
    [self buildBankCardContent];
    [self buildWechatContent];
    [self buildAlipayContent];
    [self updateBankCardDisplay];
    [self updateWechatDisplay];
    [self updateAlipayDisplay];
}

- (void)buildTabs
{
    _tabScrollView = [[UIScrollView alloc] init];
    _tabScrollView.showsHorizontalScrollIndicator = NO;
    _tabScrollView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_tabScrollView];

    CGFloat x = kCardPadding;
    for (NSInteger i = 0; i < _tabTitles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:_tabTitles[i] forState:UIControlStateNormal];
        [btn setTitleColor:HexColor(0x999999) forState:UIControlStateNormal];
        [btn setTitleColor:HexColor(kCardWalletGreen) forState:UIControlStateSelected];
        btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        btn.tag = 7000 + i;
        [btn addTarget:self action:@selector(onTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [btn sizeToFit];
        CGFloat w = btn.bounds.size.width + 24.f;
        btn.frame = CGRectMake(x, 8.f, w, 28.f);
        [_tabScrollView addSubview:btn];
        if (i == 0) btn.selected = YES;
        if (i == 2) {
            UILabel *newBadge = [[UILabel alloc] init];
            newBadge.text = @"NEW";
            newBadge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
            newBadge.textColor = [UIColor whiteColor];
            newBadge.backgroundColor = HexColor(0xFF3B30);
            newBadge.layer.cornerRadius = 4.f;
            newBadge.clipsToBounds = YES;
            newBadge.tag = 7010;
            [newBadge sizeToFit];
            CGFloat badgeW = newBadge.bounds.size.width + 8.f;
            newBadge.frame = CGRectMake(CGRectGetMaxX(btn.frame) - 4.f, 4.f, badgeW, 16.f);
            [_tabScrollView addSubview:newBadge];
        }
        x += w + 8.f;
    }
    _tabScrollView.contentSize = CGSizeMake(x + kCardPadding, kTabHeight);

    _tabUnderlineView = [[UIView alloc] init];
    _tabUnderlineView.backgroundColor = HexColor(kCardWalletGreen);
    _tabUnderlineView.layer.cornerRadius = 1.5f;
    [_tabScrollView addSubview:_tabUnderlineView];

    _contentScrollView = [[UIScrollView alloc] init];
    _contentScrollView.showsVerticalScrollIndicator = YES;
    _contentScrollView.pagingEnabled = NO;
    [self.view addSubview:_contentScrollView];
}

- (void)buildBankCardContent
{
    _bankCardContainerView = [[UIView alloc] init];
    [_contentScrollView addSubview:_bankCardContainerView];

    _addMethodView = [[UIView alloc] init];
    _addMethodView.backgroundColor = [UIColor whiteColor];
    _addMethodView.layer.cornerRadius = 12.f;
    _addMethodView.layer.masksToBounds = NO;
    CAShapeLayer *dashLayer = [CAShapeLayer layer];
    dashLayer.strokeColor = HexColor(0xCCCCCC).CGColor;
    dashLayer.fillColor = nil;
    dashLayer.lineDashPattern = @[@4, @4];
    dashLayer.lineWidth = 1.5f;
    [_addMethodView.layer addSublayer:dashLayer];
    objc_setAssociatedObject(_addMethodView, "dashLayer", dashLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [_bankCardContainerView addSubview:_addMethodView];

    UITapGestureRecognizer *addTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAddPaymentTapped)];
    [_addMethodView addGestureRecognizer:addTap];
    _addMethodView.userInteractionEnabled = YES;

    UIImageView *addIcon = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        addIcon.image = [UIImage systemImageNamed:@"creditcard.and.123"];
        addIcon.tintColor = HexColor(0x999999);
    }
    addIcon.tag = 9001;
    addIcon.contentMode = UIViewContentModeScaleAspectFit;
    [_addMethodView addSubview:addIcon];

    UILabel *addTitle = [[UILabel alloc] init];
    addTitle.text = @"添加付款方式";
    addTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    addTitle.textColor = HexColor(0x333333);
    addTitle.tag = 9002;
    [_addMethodView addSubview:addTitle];

    UILabel *addDesc = [[UILabel alloc] init];
    addDesc.text = @"购买/出售数字货币需要绑定付款方式";
    addDesc.font = [UIFont systemFontOfSize:13];
    addDesc.textColor = HexColor(0x999999);
    addDesc.numberOfLines = 0;
    addDesc.tag = 9003;
    [_addMethodView addSubview:addDesc];
}

- (UIView *)newAddMethodViewWithTag:(NSInteger)tag
{
    UIView *addView = [[UIView alloc] init];
    addView.backgroundColor = [UIColor whiteColor];
    addView.layer.cornerRadius = 12.f;
    addView.layer.masksToBounds = NO;
    addView.tag = tag;
    CAShapeLayer *dashLayer = [CAShapeLayer layer];
    dashLayer.strokeColor = HexColor(0xCCCCCC).CGColor;
    dashLayer.fillColor = nil;
    dashLayer.lineDashPattern = @[@4, @4];
    dashLayer.lineWidth = 1.5f;
    [addView.layer addSublayer:dashLayer];
    objc_setAssociatedObject(addView, "dashLayer", dashLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAddPaymentTapped)];
    [addView addGestureRecognizer:tap];
    addView.userInteractionEnabled = YES;
    UIImageView *icon = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        icon.image = [UIImage systemImageNamed:@"creditcard.and.123"];
        icon.tintColor = HexColor(0x999999);
    }
    icon.tag = 9001;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [addView addSubview:icon];
    UILabel *title = [[UILabel alloc] init];
    title.text = @"添加付款方式";
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    title.textColor = HexColor(0x333333);
    title.tag = 9002;
    [addView addSubview:title];
    UILabel *desc = [[UILabel alloc] init];
    desc.text = @"购买/出售数字货币需要绑定付款方式";
    desc.font = [UIFont systemFontOfSize:13];
    desc.textColor = HexColor(0x999999);
    desc.numberOfLines = 0;
    desc.tag = 9003;
    [addView addSubview:desc];
    return addView;
}

- (void)buildWechatContent
{
    _wechatContainerView = [[UIView alloc] init];
    [_contentScrollView addSubview:_wechatContainerView];
    _wechatAddView = [self newAddMethodViewWithTag:0];
    [_wechatContainerView addSubview:_wechatAddView];
    _wechatContainerView.hidden = YES;
}

- (void)buildAlipayContent
{
    _alipayContainerView = [[UIView alloc] init];
    [_contentScrollView addSubview:_alipayContainerView];
    _alipayAddView = [self newAddMethodViewWithTag:0];
    [_alipayContainerView addSubview:_alipayAddView];
    _alipayContainerView.hidden = YES;
}

- (void)layoutAddMethodView:(UIView *)addView cardW:(CGFloat)cardW addH:(CGFloat)addH
{
    CAShapeLayer *dashLayer = objc_getAssociatedObject(addView, "dashLayer");
    if ([dashLayer isKindOfClass:[CAShapeLayer class]]) {
        CGRect b = addView.bounds;
        dashLayer.frame = b;
        dashLayer.path = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:12.f].CGPath;
    }
    UIImageView *icon = [addView viewWithTag:9001];
    UILabel *title = [addView viewWithTag:9002];
    UILabel *desc = [addView viewWithTag:9003];
    if (icon) icon.frame = CGRectMake((cardW - 40.f) / 2.f, 16.f, 40.f, 28.f);
    if (title) title.frame = CGRectMake(16.f, 50.f, cardW - 32.f, 22.f);
    if (desc) desc.frame = CGRectMake(16.f, 74.f, cardW - 32.f, 18.f);
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    if (w <= 0.f) return;

    CGFloat safeTop = 0.f, safeBottom = 0.f;
    if (@available(iOS 11.0, *)) {
        safeTop = self.view.safeAreaInsets.top;
        safeBottom = self.view.safeAreaInsets.bottom;
    }

    _tabScrollView.frame = CGRectMake(0, safeTop, w, kTabHeight);
    UIButton *selTab = (UIButton *)[_tabScrollView viewWithTag:7000 + _selectedTabIndex];
    if (selTab && [selTab isKindOfClass:[UIButton class]] && _tabUnderlineView) {
        _tabUnderlineView.frame = CGRectMake(CGRectGetMinX(selTab.frame) + 12.f, 36.f, CGRectGetWidth(selTab.frame) - 24.f, 2.f);
    }

    CGFloat contentTop = safeTop + kTabHeight;
    CGFloat cardW = w - kCardPadding * 2.f;
    CGFloat cardH = kSingleCardH;
    CGFloat addH = 100.f;
    CGFloat y = 16.f;
    NSMutableArray *cardViews = [NSMutableArray array];
    for (UIView *sub in _bankCardContainerView.subviews) {
        if (sub == _addMethodView) continue;
        if (sub.tag >= kBankCardViewTagBase && sub.tag < kBankCardViewTagBase + 100) {
            [cardViews addObject:sub];
        }
    }
    [cardViews sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return (NSComparisonResult)(a.tag - b.tag);
    }];
    for (UIView *sub in cardViews) {
        sub.frame = CGRectMake(kCardPadding, y, cardW, cardH);
        UILabel *numLabel = [sub viewWithTag:1];
        UILabel *nameLabel = [sub viewWithTag:2];
        if (numLabel) numLabel.frame = CGRectMake(20.f, 56.f, cardW - 40.f, 26.f);
        if (nameLabel) nameLabel.frame = CGRectMake(20.f, cardH - 20.f - 18.f, cardW - 100.f, 18.f);
        y += cardH + 16.f;
    }

    _addMethodView.frame = CGRectMake(kCardPadding, y, cardW, addH);
    y += addH + 24.f;
    CAShapeLayer *dashLayer = objc_getAssociatedObject(_addMethodView, "dashLayer");
    if ([dashLayer isKindOfClass:[CAShapeLayer class]]) {
        CGRect b = _addMethodView.bounds;
        dashLayer.frame = b;
        dashLayer.path = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:12.f].CGPath;
    }
    UIImageView *addIcon = [_addMethodView viewWithTag:9001];
    UILabel *addTitle = [_addMethodView viewWithTag:9002];
    UILabel *addDesc = [_addMethodView viewWithTag:9003];
    if (addIcon) addIcon.frame = CGRectMake((cardW - 40.f) / 2.f, 16.f, 40.f, 28.f);
    if (addTitle) addTitle.frame = CGRectMake(16.f, 50.f, cardW - 32.f, 22.f);
    if (addDesc) addDesc.frame = CGRectMake(16.f, 74.f, cardW - 32.f, 18.f);

    _bankCardContainerView.frame = CGRectMake(0, 0, w, y);
    _bankCardContainerView.hidden = (_selectedTabIndex != 0);

    y = 16.f;
    NSMutableArray *wechatCards = [NSMutableArray array];
    for (UIView *sub in _wechatContainerView.subviews) {
        if (sub == _wechatAddView) continue;
        if (sub.tag >= kWechatCardViewTagBase && sub.tag < kWechatCardViewTagBase + 100) [wechatCards addObject:sub];
    }
    [wechatCards sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) { return (NSComparisonResult)(a.tag - b.tag); }];
    CGFloat textX = kPayCardIconLeft + kPayCardIconW + kPayCardIconTextGap;
    CGFloat textW = cardW - textX - kCardPadding;
    for (UIView *sub in wechatCards) {
        sub.frame = CGRectMake(kCardPadding, y, cardW, kPayCardH);
        UILabel *nameLabel = [sub viewWithTag:1];
        UILabel *numLabel = [sub viewWithTag:2];
        if (nameLabel) nameLabel.frame = CGRectMake(textX, 16.f, textW, 22.f);
        if (numLabel) numLabel.frame = CGRectMake(textX, 42.f, textW, 18.f);
        UIImageView *icon = [sub viewWithTag:3];
        if (icon) icon.frame = CGRectMake(kPayCardIconLeft, (kPayCardH - kPayCardIconW) / 2.f, kPayCardIconW, kPayCardIconW);
        y += kPayCardH + 12.f;
    }
    _wechatAddView.frame = CGRectMake(kCardPadding, y, cardW, addH);
    [self layoutAddMethodView:_wechatAddView cardW:cardW addH:addH];
    y += addH + 24.f;
    _wechatContainerView.frame = CGRectMake(0, 0, w, y);
    _wechatContainerView.hidden = (_selectedTabIndex != 1);

    y = 16.f;
    NSMutableArray *alipayCards = [NSMutableArray array];
    for (UIView *sub in _alipayContainerView.subviews) {
        if (sub == _alipayAddView) continue;
        if (sub.tag >= kAlipayCardViewTagBase && sub.tag < kAlipayCardViewTagBase + 100) [alipayCards addObject:sub];
    }
    [alipayCards sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) { return (NSComparisonResult)(a.tag - b.tag); }];
    for (UIView *sub in alipayCards) {
        sub.frame = CGRectMake(kCardPadding, y, cardW, kPayCardH);
        UILabel *nameLabel = [sub viewWithTag:1];
        UILabel *numLabel = [sub viewWithTag:2];
        if (nameLabel) nameLabel.frame = CGRectMake(textX, 16.f, textW, 22.f);
        if (numLabel) numLabel.frame = CGRectMake(textX, 42.f, textW, 18.f);
        UIImageView *icon = [sub viewWithTag:3];
        if (icon) icon.frame = CGRectMake(kPayCardIconLeft, (kPayCardH - kPayCardIconW) / 2.f, kPayCardIconW, kPayCardIconW);
        y += kPayCardH + 12.f;
    }
    _alipayAddView.frame = CGRectMake(kCardPadding, y, cardW, addH);
    [self layoutAddMethodView:_alipayAddView cardW:cardW addH:addH];
    y += addH + 24.f;
    _alipayContainerView.frame = CGRectMake(0, 0, w, y);
    _alipayContainerView.hidden = (_selectedTabIndex != 2);

    UIView *visibleContainer = (_selectedTabIndex == 0) ? _bankCardContainerView : (_selectedTabIndex == 1) ? _wechatContainerView : _alipayContainerView;
    _contentScrollView.frame = CGRectMake(0, contentTop, w, self.view.bounds.size.height - contentTop - safeBottom);
    _contentScrollView.contentSize = CGSizeMake(w, visibleContainer.frame.size.height);
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self loadWithdrawMethods];
}

// 使用「查询提款方式列表」接口（1018-30-14，actionId=26）拉取用户已绑定的收款方式
- (void)loadWithdrawMethods
{
    if (_isLoading) return;
    _isLoading = YES;
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletGetWithdrawMethodsWithComplete:^(BOOL sucess, NSArray *methods) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!wself) return;
            wself.isLoading = NO;
            @try {
                wself.withdrawMethods = ([methods isKindOfClass:[NSArray class]] && methods) ? methods : @[];
            } @catch (NSException *e) {
                wself.withdrawMethods = @[];
            }
            [wself updateBankCardDisplay];
            [wself updateWechatDisplay];
            [wself updateAlipayDisplay];
        });
    } hudParentView:nil];
}

- (NSString *)maskedCardNumber:(NSString *)num
{
    if (!num || num.length == 0) return @"****  ****  ****  ****";
    if (num.length <= 4) return num;
    NSMutableString *masked = [NSMutableString string];
    NSInteger len = num.length;
    for (NSInteger i = 0; i < len; i += 4) {
        if (i + 4 <= len) {
            if (masked.length) [masked appendString:@"  "];
            [masked appendString:[num substringWithRange:NSMakeRange((NSUInteger)i, 4)]];
        }
    }
    return masked;
}

- (UIView *)newBankCardViewWithMethod:(NSDictionary *)method index:(NSInteger)index
{
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = HexColor(0x2C2C2E);
    card.layer.cornerRadius = 12.f;
    card.clipsToBounds = YES;
    card.tag = kBankCardViewTagBase + index;
    card.userInteractionEnabled = YES;
    objc_setAssociatedObject(card, "withdrawMethod", method, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onBankCardSwipeToDelete:)];
    swipe.direction = UISwipeGestureRecognizerDirectionLeft;
    [card addGestureRecognizer:swipe];

    id numVal = method[@"account_number"];
    NSString *num = (numVal == nil || [numVal isKindOfClass:[NSNull class]]) ? @"" : [NSString stringWithFormat:@"%@", numVal];
    id nameVal = method[@"account_name"];
    NSString *name = (nameVal == nil || [nameVal isKindOfClass:[NSNull class]]) ? @"" : [NSString stringWithFormat:@"%@", nameVal];

    UILabel *numLabel = [[UILabel alloc] init];
    numLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    numLabel.textColor = [UIColor whiteColor];
    numLabel.textAlignment = NSTextAlignmentLeft;
    numLabel.text = [self maskedCardNumber:num];
    numLabel.tag = 1;
    [card addSubview:numLabel];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.font = [UIFont systemFontOfSize:13];
    nameLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    nameLabel.textAlignment = NSTextAlignmentLeft;
    nameLabel.text = (name.length > 0) ? name : @"持卡人姓名";
    nameLabel.tag = 2;
    [card addSubview:nameLabel];

    return card;
}

- (void)onBankCardSwipeToDelete:(UISwipeGestureRecognizer *)gr
{
    NSDictionary *method = objc_getAssociatedObject(gr.view, "withdrawMethod");
    if (![method isKindOfClass:[NSDictionary class]]) return;
    id idVal = method[@"id"];
    NSString *methodId = (idVal == nil || [idVal isKindOfClass:[NSNull class]]) ? nil : [NSString stringWithFormat:@"%@", idVal];
    if (!methodId || methodId.length == 0) {
        [BasicTool showAlertInfo:@"无法获取该记录" parent:self];
        return;
    }
    __weak typeof(self) wself = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"确定删除此银行卡？" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[HttpRestHelper sharedInstance] submitWalletDeleteWithdrawMethod:methodId complete:^(BOOL sucess, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (sucess) {
                    [BasicTool showAlertInfo:@"已删除" parent:wself];
                    [wself loadWithdrawMethods];
                } else {
                    [BasicTool showAlertInfo:msg ?: @"删除失败" parent:wself];
                }
            });
        } hudParentView:wself.view];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (UIView *)newPayCardViewWithMethod:(NSDictionary *)method index:(NSInteger)index isWechat:(BOOL)isWechat
{
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 12.f;
    card.layer.borderWidth = 0.5f;
    card.layer.borderColor = HexColor(0xE5E5E5).CGColor;
    card.clipsToBounds = YES;
    card.tag = isWechat ? (kWechatCardViewTagBase + index) : (kAlipayCardViewTagBase + index);
    card.userInteractionEnabled = YES;
    objc_setAssociatedObject(card, "withdrawMethod", method, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(card, "isWechat", @(isWechat), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onPayCardSwipeToDelete:)];
    swipe.direction = UISwipeGestureRecognizerDirectionLeft;
    [card addGestureRecognizer:swipe];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tag = 3;
    NSString *imgName = isWechat ? @"bind_wechat" : @"bind_alipay";
    UIImage *img = [UIImage imageNamed:imgName];
    if (img) img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    iconView.image = img;
    [card addSubview:iconView];

    id nameVal = method[@"account_name"];
    NSString *name = (nameVal == nil || [nameVal isKindOfClass:[NSNull class]]) ? @"" : [NSString stringWithFormat:@"%@", nameVal];
    id numVal = method[@"account_number"];
    NSString *num = (numVal == nil || [numVal isKindOfClass:[NSNull class]]) ? @"" : [NSString stringWithFormat:@"%@", numVal];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    nameLabel.textColor = HexColor(0x333333);
    nameLabel.text = (name.length > 0) ? name : @"姓名";
    nameLabel.tag = 1;
    [card addSubview:nameLabel];

    UILabel *numLabel = [[UILabel alloc] init];
    numLabel.font = [UIFont systemFontOfSize:14];
    numLabel.textColor = HexColor(0x666666);
    numLabel.text = (num.length > 0) ? num : @"账号";
    numLabel.tag = 2;
    [card addSubview:numLabel];

    return card;
}

- (void)onPayCardSwipeToDelete:(UISwipeGestureRecognizer *)gr
{
    NSDictionary *method = objc_getAssociatedObject(gr.view, "withdrawMethod");
    NSNumber *isWechatNum = objc_getAssociatedObject(gr.view, "isWechat");
    BOOL isWechat = [isWechatNum boolValue];
    if (![method isKindOfClass:[NSDictionary class]]) return;
    id idVal = method[@"id"];
    NSString *methodId = (idVal == nil || [idVal isKindOfClass:[NSNull class]]) ? nil : [NSString stringWithFormat:@"%@", idVal];
    if (!methodId || methodId.length == 0) {
        [BasicTool showAlertInfo:@"无法获取该记录" parent:self];
        return;
    }
    __weak typeof(self) wself = self;
    NSString *msg = isWechat ? @"确定删除此微信？" : @"确定删除此支付宝？";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[HttpRestHelper sharedInstance] submitWalletDeleteWithdrawMethod:methodId complete:^(BOOL sucess, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (sucess) {
                    [BasicTool showAlertInfo:@"已删除" parent:wself];
                    [wself loadWithdrawMethods];
                } else {
                    [BasicTool showAlertInfo:msg ?: @"删除失败" parent:wself];
                }
            });
        } hudParentView:wself.view];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateWechatDisplay
{
    if (!_wechatContainerView || !_wechatAddView) return;
    NSArray *list = _withdrawMethods;
    if (![list isKindOfClass:[NSArray class]]) list = @[];
    for (UIView *sub in [_wechatContainerView.subviews copy]) {
        if (sub.tag >= kWechatCardViewTagBase && sub.tag < kWechatCardViewTagBase + 100) [sub removeFromSuperview];
    }
    NSMutableArray *wechatList = [NSMutableArray array];
    for (id obj in list) {
        if ([obj isKindOfClass:[NSDictionary class]] && [obj[@"method_type"] integerValue] == 2) [wechatList addObject:obj];
    }
    for (NSInteger i = 0; i < (NSInteger)wechatList.count; i++) {
        UIView *card = [self newPayCardViewWithMethod:wechatList[i] index:i isWechat:YES];
        [_wechatContainerView insertSubview:card atIndex:(NSUInteger)i];
    }
    [self.view setNeedsLayout];
}

- (void)updateAlipayDisplay
{
    if (!_alipayContainerView || !_alipayAddView) return;
    NSArray *list = _withdrawMethods;
    if (![list isKindOfClass:[NSArray class]]) list = @[];
    for (UIView *sub in [_alipayContainerView.subviews copy]) {
        if (sub.tag >= kAlipayCardViewTagBase && sub.tag < kAlipayCardViewTagBase + 100) [sub removeFromSuperview];
    }
    NSMutableArray *alipayList = [NSMutableArray array];
    for (id obj in list) {
        if ([obj isKindOfClass:[NSDictionary class]] && [obj[@"method_type"] integerValue] == 1) [alipayList addObject:obj];
    }
    for (NSInteger i = 0; i < (NSInteger)alipayList.count; i++) {
        UIView *card = [self newPayCardViewWithMethod:alipayList[i] index:i isWechat:NO];
        [_alipayContainerView insertSubview:card atIndex:(NSUInteger)i];
    }
    [self.view setNeedsLayout];
}

- (void)updateBankCardDisplay
{
    if (!_bankCardContainerView || !_addMethodView) return;

    NSArray *list = _withdrawMethods;
    if (![list isKindOfClass:[NSArray class]]) list = @[];

    for (UIView *sub in [_bankCardContainerView.subviews copy]) {
        if (sub.tag >= kBankCardViewTagBase && sub.tag < kBankCardViewTagBase + 100) {
            [sub removeFromSuperview];
        }
    }

    NSMutableArray *bankCards = [NSMutableArray array];
    for (id obj in list) {
        if ([obj isKindOfClass:[NSDictionary class]] && [obj[@"method_type"] integerValue] == 3) {
            [bankCards addObject:obj];
        }
    }

    for (NSInteger i = 0; i < (NSInteger)bankCards.count; i++) {
        UIView *cardView = [self newBankCardViewWithMethod:bankCards[i] index:i];
        [_bankCardContainerView insertSubview:cardView atIndex:(NSUInteger)i];
    }

    [self.view setNeedsLayout];
}

- (void)onTabTapped:(UIButton *)sender
{
    NSInteger idx = sender.tag - 7000;
    if (idx < 0 || idx >= (NSInteger)_tabTitles.count) return;
    _selectedTabIndex = idx;
    for (UIView *v in _tabScrollView.subviews) {
        if ([v isKindOfClass:[UIButton class]]) {
            ((UIButton *)v).selected = (v.tag == sender.tag);
        }
    }
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (void)onAddPaymentTapped
{
    WalletBindWithdrawMethodViewController *vc = [[WalletBindWithdrawMethodViewController alloc] init];
    vc.methodToEdit = nil;
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
