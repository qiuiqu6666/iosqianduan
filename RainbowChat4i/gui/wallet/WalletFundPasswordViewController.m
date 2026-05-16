#import "WalletFundPasswordViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "IMClientManager.h"
#import "UserEntity.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static const CGFloat kDotRadius = 8.f;
static const CGFloat kDotSpacing = 24.f;
static const CGFloat kKeypadNumSize = 28.f;
static const CGFloat kKeypadRowSpacing = 16.f;
static const CGFloat kKeypadButtonHeight = 54.f;

static UIColor *RBFPHexColor(NSInteger hex) {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1.0];
}

@interface WalletFundPasswordViewController ()
@property (nonatomic, strong) UIView *heroCardView;
@property (nonatomic, strong) UIView *passwordCardView;
@property (nonatomic, strong) UILabel *passwordHintLabel;
@property (nonatomic, strong) UILabel *securityTipLabel;
@property (nonatomic, strong) UIView *logoView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *dotsContainerView;
@property (nonatomic, strong) NSArray<UIView *> *dotViews;
@property (nonatomic, strong) UIView *keypadContainerView;
@property (nonatomic, strong) UIButton *actionButton;

@property (nonatomic, assign) NSInteger step;
@property (nonatomic, copy) NSString *firstPassword;
@property (nonatomic, strong) NSMutableString *currentInput;
@property (nonatomic, assign) BOOL hasSetPassword;
@end

@implementation WalletFundPasswordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = RBFPHexColor(0xF5F5F5);
    self.navigationItem.title = @"";
    if (self.navigationController) {
        self.navigationController.navigationBar.backItem.title = @"";
    }

    _step = 1;
    _currentInput = [NSMutableString string];
    
    // 检查登录状态和token
    if (![self checkLoginStatus]) {
        return;
    }
    
    // 此页面仅用于首次设置资金密码，修改密码请使用 WalletModifyFundPasswordViewController
    [self rb_installPlainCustomNavigationBarWithTitle:@"设置资金密码"];
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (bar) {
        CGFloat pt0 = [BasicTool getAdjustedFontSize:17.f];
        bar.titleLabel.font = [UIFont boldSystemFontOfSize:pt0];
        bar.titleLabel.textColor = [UIColor labelColor];
    }

    _heroCardView = [[UIView alloc] initWithFrame:CGRectZero];
    _heroCardView.backgroundColor = [UIColor whiteColor];
    _heroCardView.layer.cornerRadius = 20.f;
    _heroCardView.layer.shadowColor = [UIColor blackColor].CGColor;
    _heroCardView.layer.shadowOffset = CGSizeMake(0, 8);
    _heroCardView.layer.shadowOpacity = 0.05f;
    _heroCardView.layer.shadowRadius = 18.f;
    [self.view addSubview:_heroCardView];

    _passwordCardView = [[UIView alloc] initWithFrame:CGRectZero];
    _passwordCardView.backgroundColor = [UIColor whiteColor];
    _passwordCardView.layer.cornerRadius = 20.f;
    _passwordCardView.layer.shadowColor = [UIColor blackColor].CGColor;
    _passwordCardView.layer.shadowOffset = CGSizeMake(0, 8);
    _passwordCardView.layer.shadowOpacity = 0.05f;
    _passwordCardView.layer.shadowRadius = 18.f;
    [self.view addSubview:_passwordCardView];

    _logoView = [[UIView alloc] initWithFrame:CGRectZero];
    _logoView.backgroundColor = RBFPHexColor(0x1674FF);
    _logoView.layer.cornerRadius = 28.f;
    _logoView.layer.masksToBounds = YES;
    [_heroCardView addSubview:_logoView];
    UIImageView *logoImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    if (@available(iOS 13.0, *)) {
        logoImageView.image = [[UIImage systemImageNamed:@"lock.shield.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        logoImageView.tintColor = [UIColor whiteColor];
    } else {
        logoImageView.image = [UIImage imageNamed:@"n_rainbowchat_login_logo_v9_2"];
    }
    logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    logoImageView.tag = 100;
    [_logoView addSubview:logoImageView];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.text = @"设置交易密码";
    _titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    _titleLabel.textColor = HexColor(0x333333);
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [_heroCardView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _subtitleLabel.text = @"用于红包、转账与提现验证，请设置 6 位数字密码";
    _subtitleLabel.font = [UIFont systemFontOfSize:14];
    _subtitleLabel.textColor = HexColor(0x999999);
    _subtitleLabel.textAlignment = NSTextAlignmentCenter;
    _subtitleLabel.numberOfLines = 0;
    [_heroCardView addSubview:_subtitleLabel];

    _passwordHintLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _passwordHintLabel.text = @"请输入 6 位数字交易密码";
    _passwordHintLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _passwordHintLabel.textColor = RBFPHexColor(0x333333);
    _passwordHintLabel.textAlignment = NSTextAlignmentCenter;
    [_passwordCardView addSubview:_passwordHintLabel];

    _dotsContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    [_passwordCardView addSubview:_dotsContainerView];
    NSMutableArray *dots = [NSMutableArray arrayWithCapacity:6];
    for (NSInteger i = 0; i < 6; i++) {
        UIView *dot = [[UIView alloc] initWithFrame:CGRectZero];
        dot.layer.cornerRadius = kDotRadius;
        dot.layer.borderWidth = 1.f;
        dot.layer.borderColor = RBFPHexColor(0xE5E7EB).CGColor;
        dot.backgroundColor = [UIColor whiteColor];
        dot.tag = 200 + i;
        [_dotsContainerView addSubview:dot];
        [dots addObject:dot];
    }
    _dotViews = [dots copy];

    _actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_actionButton setTitle:@"下一步" forState:UIControlStateNormal];
    [_actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _actionButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    _actionButton.backgroundColor = HexColor(0x1674FF);
    _actionButton.layer.cornerRadius = 24.f;
    _actionButton.clipsToBounds = YES;
    _actionButton.hidden = YES;
    [_actionButton addTarget:self action:@selector(onActionButton) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_actionButton];

    _keypadContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    _keypadContainerView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_keypadContainerView];
    NSArray *keys = @[@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"",@"0",@"delete"];
    for (NSInteger i = 0; i < 12; i++) {
        NSString *key = keys[i];
        if ([key isEqualToString:@"delete"]) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            if (@available(iOS 13.0, *)) {
                [btn setImage:[UIImage systemImageNamed:@"delete.left"] forState:UIControlStateNormal];
            } else {
                [btn setTitle:@"删除" forState:UIControlStateNormal];
                [btn setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
            }
            btn.tintColor = HexColor(0x333333);
            btn.backgroundColor = [UIColor whiteColor];
            btn.layer.cornerRadius = 16.f;
            btn.layer.shadowColor = [UIColor blackColor].CGColor;
            btn.layer.shadowOffset = CGSizeMake(0, 4);
            btn.layer.shadowOpacity = 0.04f;
            btn.layer.shadowRadius = 10.f;
            btn.tag = 300 + i;
            [btn addTarget:self action:@selector(onKeypadDelete) forControlEvents:UIControlEventTouchUpInside];
            [_keypadContainerView addSubview:btn];
        } else if (key.length > 0) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            [btn setTitle:key forState:UIControlStateNormal];
            [btn setTitleColor:HexColor(0x333333) forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:kKeypadNumSize weight:UIFontWeightRegular];
            btn.backgroundColor = [UIColor whiteColor];
            btn.layer.cornerRadius = 16.f;
            btn.layer.shadowColor = [UIColor blackColor].CGColor;
            btn.layer.shadowOffset = CGSizeMake(0, 4);
            btn.layer.shadowOpacity = 0.04f;
            btn.layer.shadowRadius = 10.f;
            btn.tag = 300 + i;
            [btn addTarget:self action:@selector(onKeypadNumber:) forControlEvents:UIControlEventTouchUpInside];
            [_keypadContainerView addSubview:btn];
        } else {
            UIView *placeholder = [[UIView alloc] initWithFrame:CGRectZero];
            placeholder.tag = 300 + i;
            [_keypadContainerView addSubview:placeholder];
        }
    }

    _securityTipLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _securityTipLabel.text = @"请勿使用生日、手机号等简单数字组合";
    _securityTipLabel.font = [UIFont systemFontOfSize:13];
    _securityTipLabel.textColor = RBFPHexColor(0x9CA3AF);
    _securityTipLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_securityTipLabel];
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

- (BOOL)checkLoginStatus
{
    // 检查用户是否已登录
    UserEntity *userInfo = [IMClientManager sharedInstance].localUserInfo;
    if (!userInfo || !userInfo.user_uid || userInfo.user_uid.length == 0) {
        [BasicTool showAlertInfo:@"请先登录" parent:self];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.navigationController popViewControllerAnimated:YES];
        });
        return NO;
    }
    
    // 检查token是否存在
    if (!userInfo.token || userInfo.token.length == 0) {
        [BasicTool showAlertInfo:@"登录已过期，请重新登录" parent:self];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.navigationController popViewControllerAnimated:YES];
        });
        return NO;
    }
    
    return YES;
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

    CGFloat side = 16.f;
    CGFloat y = safeTop + 12.f;
    CGFloat cardW = w - side * 2;

    _heroCardView.frame = CGRectMake(side, y, cardW, 168.f);
    UIImageView *logoImageView = (UIImageView *)[_logoView viewWithTag:100];
    CGFloat logoSize = 56.f;
    _logoView.frame = CGRectMake((cardW - logoSize) / 2, 20.f, logoSize, logoSize);
    logoImageView.frame = CGRectMake(12.f, 12.f, logoSize - 24.f, logoSize - 24.f);

    [_titleLabel sizeToFit];
    _titleLabel.frame = CGRectMake(20.f,
                                   CGRectGetMaxY(_logoView.frame) + 16.f,
                                   cardW - 40.f,
                                   _titleLabel.bounds.size.height);

    CGSize subtitleSize = [_subtitleLabel sizeThatFits:CGSizeMake(cardW - 40.f, CGFLOAT_MAX)];
    _subtitleLabel.frame = CGRectMake(20.f,
                                      CGRectGetMaxY(_titleLabel.frame) + 10.f,
                                      cardW - 40.f,
                                      subtitleSize.height);
    y = CGRectGetMaxY(_heroCardView.frame) + 14.f;

    _passwordCardView.frame = CGRectMake(side, y, cardW, 132.f);
    _passwordHintLabel.frame = CGRectMake(20.f, 22.f, cardW - 40.f, 22.f);

    CGFloat totalDotsW = 6 * (kDotRadius * 2) + 5 * kDotSpacing;
    _dotsContainerView.frame = CGRectMake((cardW - totalDotsW) / 2, 66.f, totalDotsW, kDotRadius * 2);
    for (NSInteger i = 0; i < 6; i++) {
        UIView *dot = _dotViews[i];
        dot.frame = CGRectMake(i * (kDotRadius * 2 + kDotSpacing), 0, kDotRadius * 2, kDotRadius * 2);
    }
    y = CGRectGetMaxY(_passwordCardView.frame) + 18.f;

    _actionButton.frame = CGRectMake(side, y, cardW, 50.f);
    y += 50.f + 14.f;

    _securityTipLabel.frame = CGRectMake(20.f, y, w - 40.f, 18.f);
    y += 18.f + 14.f;

    CGFloat btnH = kKeypadButtonHeight;
    CGFloat horizontalGap = 12.f;
    CGFloat btnW = floor((cardW - horizontalGap * 2) / 3.f);
    CGFloat keypadH = 4 * btnH + 3 * kKeypadRowSpacing;
    CGFloat keypadTop = h - safeBottom - keypadH - 16;
    if (keypadTop < y + 20) keypadTop = y + 20;
    _keypadContainerView.frame = CGRectMake(side, keypadTop, cardW, keypadH);
    for (NSInteger row = 0; row < 4; row++) {
        for (NSInteger col = 0; col < 3; col++) {
            NSInteger idx = row * 3 + col;
            if (idx >= 12) break;
            CGFloat x = col * (btnW + horizontalGap);
            CGFloat y0 = row * (btnH + kKeypadRowSpacing);
            UIView *v = [_keypadContainerView viewWithTag:300 + idx];
            if (v) {
                v.frame = CGRectMake(x, y0, btnW, btnH);
            }
        }
    }
}

- (void)updateDotsDisplay
{
    NSUInteger len = _currentInput.length;
    for (NSInteger i = 0; i < 6; i++) {
        UIView *dot = _dotViews[i];
        if (i < len) {
            dot.backgroundColor = HexColor(0x333333);
            dot.layer.borderColor = HexColor(0x333333).CGColor;
        } else {
            dot.backgroundColor = [UIColor whiteColor];
            dot.layer.borderColor = RBFPHexColor(0xE5E7EB).CGColor;
        }
    }
    _actionButton.hidden = (len != 6);
    if (_step == 2) {
        [_actionButton setTitle:@"确认设置" forState:UIControlStateNormal];
        _passwordHintLabel.text = @"请再次输入 6 位数字交易密码";
        _subtitleLabel.text = @"再次确认密码后即可用于红包、转账与提现校验";
    } else {
        [_actionButton setTitle:@"下一步" forState:UIControlStateNormal];
        _passwordHintLabel.text = @"请输入 6 位数字交易密码";
        _subtitleLabel.text = @"用于红包、转账与提现验证，请设置 6 位数字密码";
    }
    [self.view setNeedsLayout];
}

- (void)onKeypadNumber:(UIButton *)sender
{
    if (_currentInput.length >= 6) return;
    NSString *num = [sender titleForState:UIControlStateNormal];
    if (num.length) {
        [_currentInput appendString:num];
        [self updateDotsDisplay];
    }
}

- (void)onKeypadDelete
{
    if (_currentInput.length == 0) return;
    [_currentInput deleteCharactersInRange:NSMakeRange(_currentInput.length - 1, 1)];
    [self updateDotsDisplay];
}


- (void)onActionButton
{
    if (_currentInput.length != 6) return;
    NSString *pw = [_currentInput copy];
    
    if (_step == 1) {
        // 第一步：输入密码，统一走两次确认（无单独查询密码状态接口）
        _firstPassword = pw;
        _step = 2;
        [_currentInput setString:@""];
        [self updateDotsDisplay];
    } else {
        // 第二步：确认密码（仅设置密码模式）
        if (![pw isEqualToString:_firstPassword]) {
            [BasicTool showAlertInfo:@"两次输入不一致" parent:self];
            return;
        }
        [self submitSetPassword:pw];
    }
}


- (void)submitSetPassword:(NSString *)password
{
    // 再次检查登录状态
    if (![self checkLoginStatus]) {
        return;
    }
    
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletSetFundPassword:password complete:^(BOOL sucess, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess) {
                [BasicTool showAlertInfo:@"设置成功" parent:wself];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [wself.navigationController popViewControllerAnimated:YES];
                });
            } else {
                // 设置(8) 返回 "0" 表示已设置过，提示用户使用修改密码页面
                if ([msg isEqualToString:@"0"]) {
                    [BasicTool showAlertInfo:@"资金密码已设置，如需修改请使用修改资金密码功能" parent:wself];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [wself.navigationController popViewControllerAnimated:YES];
                    });
                    return;
                }
                if ([msg isEqualToString:@"3"]) {
                    [BasicTool showAlertInfo:@"密码长度不足。本应用要求6位数字；若仍提示不足，请确认后台配置 PASSWORD_MIN_LENGTH=6（示例配置为8）。" parent:wself];
                    return;
                }
                NSString *errorMsg = msg ?: @"设置失败";
                NSString *lowerMsg = [errorMsg lowercaseString];
                // 仅当明确为 token 失效时才提示“登录已过期”；“无法获取用户 UID”多为服务端校验未启用，显示原始错误便于排查
                BOOL isTokenExpired = ([lowerMsg containsString:@"token已失效"] || [lowerMsg containsString:@"token无效"] || [lowerMsg containsString:@"请重新登录"]);
                if (isTokenExpired) {
                    [BasicTool showAlertInfo:@"登录已过期，请重新登录" parent:wself];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [wself.navigationController popViewControllerAnimated:YES];
                    });
                } else {
                    [BasicTool showAlertInfo:errorMsg parent:wself];
                }
            }
        });
    } hudParentView:self.view];
}

@end
