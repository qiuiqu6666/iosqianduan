#import "WalletFundPasswordInputViewController.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static const CGFloat kKeypadNumSize = 26.f;
static const CGFloat kKeypadRowSpacing = 10.f;
static const CGFloat kKeypadBtnH = 48.f;

static UIColor *RBFPInputHexColor(NSInteger hex) {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1.0];
}

@interface WalletFundPasswordInputViewController ()
@property (nonatomic, strong) UIView *maskView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *grabberView;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *amountCardView;
@property (nonatomic, strong) UILabel *amountLabel;
@property (nonatomic, strong) UIView *dotsContainer;
@property (nonatomic, strong) NSMutableArray<UIView *> *dotViews;
@property (nonatomic, strong) NSMutableString *password;
@property (nonatomic, strong) UIView *keyboardView;
@property (nonatomic, assign) BOOL didAnimateIn;
@end

@implementation WalletFundPasswordInputViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        _password = [NSMutableString string];
        _dotViews = [NSMutableArray array];
    }
    return self;
}

- (CGFloat)sheetHeight {
    CGFloat safeBottom = 0;
    if (self.view.window && @available(iOS 11.0, *)) { safeBottom = self.view.safeAreaInsets.bottom; }
    if (safeBottom <= 0) safeBottom = 34;
    CGFloat keyboardHeight = 4 * kKeypadBtnH + 3 * kKeypadRowSpacing + safeBottom;
    CGFloat amountCardHeight = self.amountText.length > 0 ? 74.f : 0.f;
    CGFloat topHeight = 68.f;
    CGFloat passwordAreaHeight = 88.f;
    return topHeight + amountCardHeight + passwordAreaHeight + 10.f + keyboardHeight;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];

    _maskView = [[UIView alloc] initWithFrame:self.view.bounds];
    _maskView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_maskView];

    _contentView = [[UIView alloc] initWithFrame:CGRectZero];
    _contentView.backgroundColor = RBFPInputHexColor(0xF5F5F5);
    _contentView.layer.cornerRadius = 22;
    _contentView.layer.shadowColor = [UIColor blackColor].CGColor;
    _contentView.layer.shadowOffset = CGSizeMake(0, -4);
    _contentView.layer.shadowOpacity = 0.08f;
    _contentView.layer.shadowRadius = 20.f;
    if (@available(iOS 11.0, *)) {
        _contentView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    }
    _contentView.clipsToBounds = YES;
    [self.view addSubview:_contentView];

    _grabberView = [[UIView alloc] initWithFrame:CGRectZero];
    _grabberView.backgroundColor = RBFPInputHexColor(0xD1D5DB);
    _grabberView.layer.cornerRadius = 2.5f;
    [_contentView addSubview:_grabberView];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    _closeButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [_closeButton setTitleColor:RBFPInputHexColor(0x6B7280) forState:UIControlStateNormal];
    [_closeButton addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:_closeButton];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.text = self.titleText.length > 0 ? self.titleText : @"支付验证";
    _titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    _titleLabel.textColor = HexColor(0x333333);
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [_contentView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _subtitleLabel.text = @"请输入 6 位支付密码";
    _subtitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    _subtitleLabel.textColor = RBFPInputHexColor(0x9CA3AF);
    _subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [_contentView addSubview:_subtitleLabel];

    _amountCardView = [[UIView alloc] initWithFrame:CGRectZero];
    _amountCardView.backgroundColor = [UIColor whiteColor];
    _amountCardView.layer.cornerRadius = 18.f;
    _amountCardView.hidden = (self.amountText.length == 0);
    [_contentView addSubview:_amountCardView];

    _amountLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _amountLabel.font = [UIFont systemFontOfSize:30 weight:UIFontWeightSemibold];
    _amountLabel.textColor = RBFPInputHexColor(0x111827);
    _amountLabel.textAlignment = NSTextAlignmentCenter;
    _amountLabel.text = self.amountText ?: @"";
    _amountLabel.hidden = (self.amountText.length == 0);
    [_amountCardView addSubview:_amountLabel];

    _dotsContainer = [[UIView alloc] initWithFrame:CGRectZero];
    [_contentView addSubview:_dotsContainer];
    for (int i = 0; i < 6; i++) {
        UIView *box = [[UIView alloc] initWithFrame:CGRectZero];
        box.backgroundColor = [UIColor whiteColor];
        box.layer.cornerRadius = 14;
        box.layer.borderWidth = 1.0;
        box.layer.borderColor = RBFPInputHexColor(0xE5E7EB).CGColor;
        UILabel *dot = [[UILabel alloc] initWithFrame:CGRectZero];
        dot.text = @"•";
        dot.font = [UIFont systemFontOfSize:28 weight:UIFontWeightMedium];
        dot.textColor = HexColor(0x333333);
        dot.textAlignment = NSTextAlignmentCenter;
        dot.hidden = YES;
        dot.tag = 1;
        [box addSubview:dot];
        [_dotsContainer addSubview:box];
        [_dotViews addObject:box];
    }

    _keyboardView = [[UIView alloc] initWithFrame:CGRectZero];
    _keyboardView.backgroundColor = [UIColor clearColor];
    [_contentView addSubview:_keyboardView];

    NSArray *keys = @[@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"",@"0",@"delete"];
    for (NSInteger i = 0; i < 12; i++) {
        NSString *key = keys[i];
        if ([key isEqualToString:@"delete"]) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            if (@available(iOS 13.0, *)) {
                UIImage *img = [UIImage systemImageNamed:@"delete.left"];
                [btn setImage:img forState:UIControlStateNormal];
            } else {
                [btn setTitle:@"删除" forState:UIControlStateNormal];
            }
            btn.tintColor = HexColor(0x333333);
            btn.backgroundColor = [UIColor whiteColor];
            btn.layer.cornerRadius = 16.f;
            btn.layer.shadowColor = [UIColor blackColor].CGColor;
            btn.layer.shadowOffset = CGSizeMake(0, 4);
            btn.layer.shadowOpacity = 0.04f;
            btn.layer.shadowRadius = 10.f;
            btn.tag = 300 + i;
            [btn addTarget:self action:@selector(onDelete) forControlEvents:UIControlEventTouchUpInside];
            [_keyboardView addSubview:btn];
        } else if (key.length > 0) {
            UIButton *btn = [self keyButtonWithTitle:key];
            btn.tag = 300 + i;
            [btn addTarget:self action:@selector(onKeyTap:) forControlEvents:UIControlEventTouchUpInside];
            [_keyboardView addSubview:btn];
        } else {
            UIView *placeholder = [[UIView alloc] initWithFrame:CGRectZero];
            placeholder.tag = 300 + i;
            [_keyboardView addSubview:placeholder];
        }
    }

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onMaskTap)];
    [_maskView addGestureRecognizer:tap];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_didAnimateIn) return;
    _didAnimateIn = YES;
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = _contentView.bounds.size.height;
    CGRect finalFrame = CGRectMake(0, self.view.bounds.size.height - h, w, h);
    _contentView.frame = CGRectMake(0, self.view.bounds.size.height, w, h);
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.contentView.frame = finalFrame;
    } completion:nil];
}

- (void)dismissFromBottom {
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = _contentView.bounds.size.height;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.contentView.frame = CGRectMake(0, self.view.bounds.size.height, w, h);
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

- (UIButton *)keyButtonWithTitle:(NSString *)title {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:kKeypadNumSize weight:UIFontWeightRegular];
    [btn setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor whiteColor];
    btn.layer.cornerRadius = 16.f;
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOffset = CGSizeMake(0, 4);
    btn.layer.shadowOpacity = 0.04f;
    btn.layer.shadowRadius = 10.f;
    return btn;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) { safeBottom = self.view.safeAreaInsets.bottom; }
    CGFloat keyboardHeight = 4 * kKeypadBtnH + 3 * kKeypadRowSpacing + safeBottom;
    CGFloat contentHeight = [self sheetHeight];
    CGRect frame = CGRectMake(0, self.view.bounds.size.height - contentHeight, w, contentHeight);
    if (!_didAnimateIn) {
        frame.origin.y = self.view.bounds.size.height;
    }
    _contentView.frame = frame;
    CGFloat contentWidth = w;

    _grabberView.frame = CGRectMake((contentWidth - 40.f) / 2.f, 8.f, 40.f, 5.f);
    _closeButton.frame = CGRectMake(contentWidth - 60.f, 12.f, 48.f, 24.f);
    _titleLabel.frame = CGRectMake(20.f, 24.f, contentWidth - 40.f, 22.f);
    _subtitleLabel.frame = CGRectMake(20.f, 46.f, contentWidth - 40.f, 16.f);
    CGFloat y = 72.f;
    if (_amountLabel.text.length > 0) {
        _amountCardView.hidden = NO;
        _amountCardView.frame = CGRectMake(16.f, y, contentWidth - 32.f, 62.f);
        _amountLabel.frame = CGRectMake(16.f, 14.f, CGRectGetWidth(_amountCardView.bounds) - 32.f, 30.f);
        y += 70.f;
    } else {
        _amountCardView.hidden = YES;
    }
    CGFloat dotW = floor((contentWidth - 32.f - 5.f * 10.f) / 6.f);
    CGFloat dotGap = 10.f;
    CGFloat totalDotsW = 6 * dotW + 5 * dotGap;
    _dotsContainer.frame = CGRectMake((contentWidth - totalDotsW) / 2, y, totalDotsW, 46.f);
    for (NSInteger i = 0; i < 6; i++) {
        UIView *box = _dotViews[i];
        box.frame = CGRectMake(i * (dotW + dotGap), 0, dotW, 46.f);
        UILabel *dot = [box viewWithTag:1];
        dot.frame = box.bounds;
    }
    y += 56.f;
    _keyboardView.frame = CGRectMake(0, y, contentWidth, keyboardHeight);

    CGFloat side = 16.f;
    CGFloat gap = 12.f;
    CGFloat btnW = floor((contentWidth - side * 2 - gap * 2) / 3.f);
    for (NSInteger row = 0; row < 4; row++) {
        for (NSInteger col = 0; col < 3; col++) {
            NSInteger idx = row * 3 + col;
            if (idx >= 12) break;
            CGFloat x = side + col * (btnW + gap);
            CGFloat y0 = row * (kKeypadBtnH + kKeypadRowSpacing);
            UIView *v = [_keyboardView viewWithTag:300 + idx];
            if (v) {
                v.frame = CGRectMake(x, y0, btnW, kKeypadBtnH);
            }
        }
    }
}

- (void)onKeyTap:(UIButton *)sender {
    if (_password.length >= 6) return;
    NSString *t = [sender currentTitle];
    if (t.length == 1 && [t characterAtIndex:0] >= '0' && [t characterAtIndex:0] <= '9') {
        [_password appendString:t];
        [self updateDots];
        if (_password.length == 6) {
            if (self.onComplete) self.onComplete([_password copy]);
            // 由调用方负责 dismiss，便于在 dismiss 完成后再发起请求，保证成功/失败提示能正常弹出
        }
    }
}

- (void)onDelete {
    if (_password.length > 0) {
        [_password deleteCharactersInRange:NSMakeRange(_password.length - 1, 1)];
        [self updateDots];
    }
}

- (void)updateDots {
    for (NSInteger i = 0; i < 6; i++) {
        UIView *box = _dotViews[i];
        UILabel *dot = [box viewWithTag:1];
        dot.hidden = (i >= _password.length);
        box.layer.borderColor = (i < _password.length ? RBFPInputHexColor(0x1674FF).CGColor : RBFPInputHexColor(0xE5E7EB).CGColor);
    }
}

- (void)onClose {
    if (self.onCancel) self.onCancel();
    [self dismissFromBottom];
}

- (void)onMaskTap {
    [self onClose];
}

@end
