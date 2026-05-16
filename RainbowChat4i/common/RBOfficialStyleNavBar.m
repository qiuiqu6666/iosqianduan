//
//  RBOfficialStyleNavBar.m
//  RainbowChat4i
//
//  可复用的「官方客服风格」导航栏：磨砂渐变到透明、液态/毛玻璃圆钮、中间胶囊标题。
//

#import "RBOfficialStyleNavBar.h"
#import "RBAvatarView.h"
#import "Default.h"
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
#import <UIKit/UIGlassEffect.h>
#endif

static const CGFloat kContentHeight = 26.0f;
static const CGFloat kButtonSize = 44.0f;
static const CGFloat kContentMargin = 12.0f;
static const CGFloat kContentBottomOffset = 18.0f;
static const CGFloat kCapsuleHeight = 44.0f;
static const CGFloat kCapsuleHPadding = 12.0f;
static const CGFloat kCapsuleVPadding = 6.0f;
static const CGFloat kCapsuleMinWidth = 200.0f;

@interface RBOfficialStyleNavBar ()
@property (nonatomic, strong) UIView *barView;
@property (nonatomic, strong) UIView *gradientContainerView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) CAGradientLayer *blurMaskLayer;
@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *leftButtonContainer;
@property (nonatomic, strong) UIView *rightButtonContainer;
@property (nonatomic, strong) UIButton *rightIconButton;
@property (nonatomic, strong) UIView *rightAvatarBorderView;
@property (nonatomic, strong) UIImageView *rightAvatarImageView;
@property (nonatomic, strong) UIView *capsuleWrapper;
@property (nonatomic, strong) UIView *capsuleView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@end

@implementation RBOfficialStyleNavBar

- (CGFloat)contentHeight { return kContentHeight; }

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        _showRightButton = NO;
    }
    return self;
}

- (void)addToView:(UIView *)containerView
{
    [self buildIfNeeded];
    [containerView addSubview:self];
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [self.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [self.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
    ]];
    _heightConstraint = [self.heightAnchor constraintEqualToConstant:kContentHeight];
    [_heightConstraint setActive:YES];
}

- (void)setBarHeight:(CGFloat)height
{
    if (_heightConstraint) _heightConstraint.constant = height;
}

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
    _titleLabel.text = _title ?: @"";
}

- (void)setSubtitle:(NSString *)subtitle
{
    _subtitle = [subtitle copy];
    _subtitleLabel.text = _subtitle ?: @"";
    _subtitleLabel.hidden = (_subtitle.length == 0);
}

- (void)setShowRightButton:(BOOL)showRightButton
{
    _showRightButton = showRightButton;
    _rightButtonContainer.hidden = !showRightButton;
}

- (void)restoreCapsuleFonts
{
    if (_titleLabel) {
        _titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        _titleLabel.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
    }
    if (_subtitleLabel) {
        _subtitleLabel.font = [UIFont systemFontOfSize:12.0f weight:UIFontWeightRegular];
        _subtitleLabel.textColor = [UIColor colorWithWhite:0.45f alpha:1.0f];
    }
}

- (void)updateBlurMaskForScrollProgress:(CGFloat)progress
{
    if (!_blurMaskLayer) return;
    progress = MAX(0.0f, MIN(1.0f, progress));
    _blurMaskLayer.locations = @[
        @0.0f,
        @(0.2f - 0.08f * progress),
        @(0.5f - 0.12f * progress),
        @(0.8f - 0.1f * progress),
        @1.0f
    ];
}

- (void)buildIfNeeded
{
    if (_barView) return;

    UIView *bar = [[UIView alloc] init];
    bar.backgroundColor = [UIColor clearColor];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:bar];
    _barView = bar;

    UIView *gradContainer = [[UIView alloc] init];
    gradContainer.userInteractionEnabled = NO;
    gradContainer.backgroundColor = [UIColor clearColor];
    gradContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:gradContainer];
    _gradientContainerView = gradContainer;

    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
    blur.userInteractionEnabled = NO;
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    [gradContainer addSubview:blur];
    _blurView = blur;

    [NSLayoutConstraint activateConstraints:@[
        [blur.leadingAnchor constraintEqualToAnchor:gradContainer.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:gradContainer.trailingAnchor],
        [blur.topAnchor constraintEqualToAnchor:gradContainer.topAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:gradContainer.bottomAnchor],
        [gradContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
        [gradContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [gradContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [gradContainer.heightAnchor constraintEqualToAnchor:bar.heightAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:self.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [bar.heightAnchor constraintEqualToAnchor:self.heightAnchor],
    ]];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.backgroundColor = [UIColor clearColor];
    [bar addSubview:content];
    _contentView = content;
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-kContentBottomOffset],
        [content.heightAnchor constraintEqualToConstant:kContentHeight],
    ]];

    UIButton *backIcon = [UIButton buttonWithType:UIButtonTypeCustom];
    backIcon.tintColor = [UIColor blackColor];
    backIcon.adjustsImageWhenHighlighted = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
        [backIcon setImage:[UIImage systemImageNamed:@"chevron.left" withConfiguration:cfg] forState:UIControlStateNormal];
    } else {
        [backIcon setTitle:@"<" forState:UIControlStateNormal];
        backIcon.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    }
    [backIcon addTarget:self action:@selector(p_backTapped) forControlEvents:UIControlEventTouchUpInside];
    UIView *leftBtn = [self p_glassButtonContainerWithSize:kButtonSize iconButton:backIcon];
    [content addSubview:leftBtn];
    _leftButtonContainer = leftBtn;
    [NSLayoutConstraint activateConstraints:@[
        [leftBtn.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:kContentMargin],
        [leftBtn.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [leftBtn.widthAnchor constraintEqualToConstant:kButtonSize],
        [leftBtn.heightAnchor constraintEqualToConstant:kButtonSize],
    ]];

    UIButton *moreIcon = [UIButton buttonWithType:UIButtonTypeCustom];
    moreIcon.tintColor = [UIColor blackColor];
    moreIcon.adjustsImageWhenHighlighted = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
        [moreIcon setImage:[UIImage systemImageNamed:@"ellipsis.circle" withConfiguration:cfg] forState:UIControlStateNormal];
    } else {
        [moreIcon setTitle:@"⋯" forState:UIControlStateNormal];
        moreIcon.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightRegular];
    }
    [moreIcon addTarget:self action:@selector(p_rightTapped) forControlEvents:UIControlEventTouchUpInside];
    _rightIconButton = moreIcon;
    UIView *rightBtn = [self p_glassButtonContainerWithSize:kButtonSize iconButton:moreIcon];
    [content addSubview:rightBtn];
    _rightButtonContainer = rightBtn;
    rightBtn.hidden = !_showRightButton;
    [NSLayoutConstraint activateConstraints:@[
        [rightBtn.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-kContentMargin],
        [rightBtn.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [rightBtn.widthAnchor constraintEqualToConstant:kButtonSize],
        [rightBtn.heightAnchor constraintEqualToConstant:kButtonSize],
    ]];

    UIView *capsuleWrapper = [[UIView alloc] init];
    capsuleWrapper.translatesAutoresizingMaskIntoConstraints = NO;
    capsuleWrapper.backgroundColor = [UIColor clearColor];
    capsuleWrapper.layer.shadowColor = [UIColor blackColor].CGColor;
    capsuleWrapper.layer.shadowOffset = CGSizeMake(0, 1);
    capsuleWrapper.layer.shadowOpacity = 0.08f;
    capsuleWrapper.layer.shadowRadius = 4.0f;
    [content addSubview:capsuleWrapper];
    _capsuleWrapper = capsuleWrapper;

    UIView *capsule = [[UIView alloc] init];
    capsule.translatesAutoresizingMaskIntoConstraints = NO;
    capsule.backgroundColor = [UIColor clearColor];
    capsule.clipsToBounds = YES;
    [capsuleWrapper addSubview:capsule];
    _capsuleView = capsule;

    UIVisualEffect *capsuleEffect;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        capsuleEffect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
    } else
#endif
    { capsuleEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]; }
    UIVisualEffectView *capsuleBlur = [[UIVisualEffectView alloc] initWithEffect:capsuleEffect];
    capsuleBlur.userInteractionEnabled = NO;
    capsuleBlur.translatesAutoresizingMaskIntoConstraints = NO;
    [capsule addSubview:capsuleBlur];
    UIView *capsuleTint = [[UIView alloc] init];
    capsuleTint.backgroundColor = [UIColor colorWithRed:0.85f green:0.92f blue:0.78f alpha:0.35f];
    capsuleTint.userInteractionEnabled = NO;
    capsuleTint.translatesAutoresizingMaskIntoConstraints = NO;
    [capsule addSubview:capsuleTint];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = _title ?: @"";
    titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    titleLabel.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [capsule addSubview:titleLabel];
    _titleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = _subtitle ?: @"";
    subtitleLabel.font = [UIFont systemFontOfSize:12.0f weight:UIFontWeightRegular];
    subtitleLabel.textColor = [UIColor colorWithWhite:0.45f alpha:1.0f];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [capsule addSubview:subtitleLabel];
    _subtitleLabel = subtitleLabel;
    subtitleLabel.hidden = (_subtitle.length == 0);

    [NSLayoutConstraint activateConstraints:@[
        [capsuleWrapper.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [capsuleWrapper.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [capsuleWrapper.leadingAnchor constraintEqualToAnchor:capsule.leadingAnchor],
        [capsuleWrapper.trailingAnchor constraintEqualToAnchor:capsule.trailingAnchor],
        [capsuleWrapper.topAnchor constraintEqualToAnchor:capsule.topAnchor],
        [capsuleWrapper.bottomAnchor constraintEqualToAnchor:capsule.bottomAnchor],
        [capsule.leadingAnchor constraintGreaterThanOrEqualToAnchor:leftBtn.trailingAnchor constant:8],
        [capsule.trailingAnchor constraintLessThanOrEqualToAnchor:rightBtn.leadingAnchor constant:-8],
        [capsule.widthAnchor constraintGreaterThanOrEqualToConstant:kCapsuleMinWidth],
        [capsule.heightAnchor constraintEqualToConstant:kCapsuleHeight],
    ]];
    NSLayoutConstraint *wEqual = [capsule.widthAnchor constraintEqualToAnchor:titleLabel.widthAnchor constant:2.0f * kCapsuleHPadding];
    wEqual.priority = UILayoutPriorityRequired - 1;
    [wEqual setActive:YES];
    [NSLayoutConstraint activateConstraints:@[
        [capsuleBlur.leadingAnchor constraintEqualToAnchor:capsule.leadingAnchor],
        [capsuleBlur.trailingAnchor constraintEqualToAnchor:capsule.trailingAnchor],
        [capsuleBlur.topAnchor constraintEqualToAnchor:capsule.topAnchor],
        [capsuleBlur.bottomAnchor constraintEqualToAnchor:capsule.bottomAnchor],
        [capsuleTint.leadingAnchor constraintEqualToAnchor:capsule.leadingAnchor],
        [capsuleTint.trailingAnchor constraintEqualToAnchor:capsule.trailingAnchor],
        [capsuleTint.topAnchor constraintEqualToAnchor:capsule.topAnchor],
        [capsuleTint.bottomAnchor constraintEqualToAnchor:capsule.bottomAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:capsule.topAnchor constant:kCapsuleVPadding],
        [titleLabel.leadingAnchor constraintEqualToAnchor:capsule.leadingAnchor constant:kCapsuleHPadding],
        [titleLabel.trailingAnchor constraintEqualToAnchor:capsule.trailingAnchor constant:-kCapsuleHPadding],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:1.0f],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:capsule.leadingAnchor constant:kCapsuleHPadding],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:capsule.trailingAnchor constant:-kCapsuleHPadding],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:capsule.bottomAnchor constant:-kCapsuleVPadding],
    ]];

    [self bringSubviewToFront:gradContainer];
    [self bringSubviewToFront:bar];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (_blurView.superview && _blurView.bounds.size.height > 0) {
        if (!_blurMaskLayer) {
            CAGradientLayer *mask = [CAGradientLayer layer];
            mask.frame = _blurView.bounds;
            mask.colors = @[
                (id)[UIColor colorWithWhite:1 alpha:0.9f].CGColor,
                (id)[UIColor colorWithWhite:1 alpha:0.7f].CGColor,
                (id)[UIColor colorWithWhite:1 alpha:0.5f].CGColor,
                (id)[UIColor colorWithWhite:1 alpha:0.3f].CGColor,
                (id)[UIColor colorWithWhite:1 alpha:0].CGColor
            ];
            mask.locations = @[ @0.0f, @0.2f, @0.5f, @0.8f, @1.0f ];
            mask.startPoint = CGPointMake(0.5, 0);
            mask.endPoint = CGPointMake(0.5, 1);
            _blurMaskLayer = mask;
            _blurView.layer.mask = mask;
        } else {
            _blurMaskLayer.frame = _blurView.bounds;
        }
    }
    if (_capsuleView.bounds.size.height > 0) {
        CGFloat r = _capsuleView.bounds.size.height / 2.0f;
        _capsuleView.layer.cornerRadius = r;
        if (_capsuleView.subviews.count > 0) {
            _capsuleView.subviews[0].layer.cornerRadius = r;
            ((UIView *)_capsuleView.subviews[0]).clipsToBounds = YES;
        }
        if (_capsuleWrapper.bounds.size.width > 0 && _capsuleWrapper.bounds.size.height > 0) {
            _capsuleWrapper.layer.cornerRadius = r;
            _capsuleWrapper.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_capsuleWrapper.bounds cornerRadius:r].CGPath;
        }
    }
}

- (void)p_backTapped
{
    if (self.onBackTap) self.onBackTap();
}

- (void)p_rightTapped
{
    if (self.onRightTap) self.onRightTap();
}

- (void)setRightButtonAvatarWithFileName:(NSString *)fileName uid:(NSString *)uid
{
    UIView *container = _rightButtonContainer;
    UIButton *btn = _rightIconButton;
    if (!container || !btn) return;
    if (fileName.length > 0 || uid.length > 0) {
        [btn setImage:nil forState:UIControlStateNormal];
        [btn setTitle:nil forState:UIControlStateNormal];
        CGFloat borderW = 1.0f / [UIScreen mainScreen].scale;
        UIView *borderRing = _rightAvatarBorderView;
        if (!borderRing) {
            borderRing = [[UIView alloc] init];
            borderRing.translatesAutoresizingMaskIntoConstraints = NO;
            borderRing.backgroundColor = [UIColor clearColor];
            borderRing.layer.cornerRadius = kButtonSize / 2.0f;
            borderRing.layer.borderWidth = borderW;
            borderRing.layer.borderColor = [UIColor colorWithWhite:4.0f alpha:0.8f].CGColor;
            borderRing.userInteractionEnabled = NO;
            [container addSubview:borderRing];
            [NSLayoutConstraint activateConstraints:@[
                [borderRing.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
                [borderRing.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
                [borderRing.topAnchor constraintEqualToAnchor:container.topAnchor],
                [borderRing.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
            ]];
            _rightAvatarBorderView = borderRing;
        }
        UIImageView *avatarIv = _rightAvatarImageView;
        if (!avatarIv) {
            avatarIv = [[UIImageView alloc] init];
            avatarIv.translatesAutoresizingMaskIntoConstraints = NO;
            avatarIv.contentMode = UIViewContentModeScaleAspectFill;
            avatarIv.clipsToBounds = YES;
            avatarIv.layer.cornerRadius = (kButtonSize - 2.0f * borderW) / 2.0f;
            avatarIv.userInteractionEnabled = NO;
            [container addSubview:avatarIv];
            [NSLayoutConstraint activateConstraints:@[
                [avatarIv.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:borderW],
                [avatarIv.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-borderW],
                [avatarIv.topAnchor constraintEqualToAnchor:container.topAnchor constant:borderW],
                [avatarIv.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-borderW],
            ]];
            _rightAvatarImageView = avatarIv;
        }
        _rightAvatarBorderView.hidden = NO;
        [container bringSubviewToFront:avatarIv];
        avatarIv.hidden = NO;
        [container layoutIfNeeded];
        UIImage *placeImg = [UIImage imageNamed:@"default_avatar_60"];
        [RBAvatarView setAvatarWithFileName:fileName uid:uid onImageView:avatarIv placeholder:placeImg];
    } else {
        if (_rightAvatarImageView) {
            [RBAvatarView removeAvatarFromImageView:_rightAvatarImageView];
            _rightAvatarImageView.hidden = YES;
        }
        _rightAvatarBorderView.hidden = YES;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
            [btn setImage:[UIImage systemImageNamed:@"ellipsis.circle" withConfiguration:cfg] forState:UIControlStateNormal];
        } else {
            [btn setTitle:@"⋯" forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightRegular];
        }
    }
}

- (void)setRightButtonAvatarWithImage:(UIImage *)image
{
    UIView *container = _rightButtonContainer;
    UIButton *btn = _rightIconButton;
    if (!container || !btn) return;
    if (image) {
        [btn setImage:nil forState:UIControlStateNormal];
        [btn setTitle:nil forState:UIControlStateNormal];
        CGFloat borderW = 1.0f / [UIScreen mainScreen].scale;
        UIView *borderRing = _rightAvatarBorderView;
        if (!borderRing) {
            borderRing = [[UIView alloc] init];
            borderRing.translatesAutoresizingMaskIntoConstraints = NO;
            borderRing.backgroundColor = [UIColor clearColor];
            borderRing.layer.cornerRadius = kButtonSize / 2.0f;
            borderRing.layer.borderWidth = borderW;
            borderRing.layer.borderColor = [UIColor colorWithWhite:4.0f alpha:0.8f].CGColor;
            borderRing.userInteractionEnabled = NO;
            [container addSubview:borderRing];
            [NSLayoutConstraint activateConstraints:@[
                [borderRing.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
                [borderRing.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
                [borderRing.topAnchor constraintEqualToAnchor:container.topAnchor],
                [borderRing.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
            ]];
            _rightAvatarBorderView = borderRing;
        }
        UIImageView *avatarIv = _rightAvatarImageView;
        if (!avatarIv) {
            avatarIv = [[UIImageView alloc] init];
            avatarIv.translatesAutoresizingMaskIntoConstraints = NO;
            avatarIv.contentMode = UIViewContentModeScaleAspectFill;
            avatarIv.clipsToBounds = YES;
            avatarIv.layer.cornerRadius = (kButtonSize - 2.0f * borderW) / 2.0f;
            avatarIv.userInteractionEnabled = NO;
            [container addSubview:avatarIv];
            [NSLayoutConstraint activateConstraints:@[
                [avatarIv.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:borderW],
                [avatarIv.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-borderW],
                [avatarIv.topAnchor constraintEqualToAnchor:container.topAnchor constant:borderW],
                [avatarIv.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-borderW],
            ]];
            _rightAvatarImageView = avatarIv;
        }
        _rightAvatarBorderView.hidden = NO;
        [container bringSubviewToFront:avatarIv];
        avatarIv.hidden = NO;
        avatarIv.image = image;
        [container layoutIfNeeded];
    } else {
        if (_rightAvatarImageView) {
            _rightAvatarImageView.image = nil;
            _rightAvatarImageView.hidden = YES;
        }
        _rightAvatarBorderView.hidden = YES;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
            [btn setImage:[UIImage systemImageNamed:@"ellipsis.circle" withConfiguration:cfg] forState:UIControlStateNormal];
        } else {
            [btn setTitle:@"⋯" forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightRegular];
        }
    }
}

- (UIView *)p_glassButtonContainerWithSize:(CGFloat)size iconButton:(UIButton *)iconBtn
{
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor clearColor];
    container.layer.cornerRadius = size / 2.0f;
    container.clipsToBounds = YES;
    container.translatesAutoresizingMaskIntoConstraints = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *effect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:effect];
        glass.layer.cornerRadius = size / 2.0f;
        glass.clipsToBounds = YES;
        glass.userInteractionEnabled = NO;
        glass.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:glass];
        [NSLayoutConstraint activateConstraints:@[
            [glass.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [glass.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [glass.topAnchor constraintEqualToAnchor:container.topAnchor],
            [glass.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        ]];
    } else
#endif
    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
        blur.layer.cornerRadius = size / 2.0f;
        blur.clipsToBounds = YES;
        blur.userInteractionEnabled = NO;
        blur.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:blur];
        [NSLayoutConstraint activateConstraints:@[
            [blur.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [blur.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [blur.topAnchor constraintEqualToAnchor:container.topAnchor],
            [blur.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        ]];
    } else {
        container.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.9f];
    }
    [container addSubview:iconBtn];
    iconBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [iconBtn.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [iconBtn.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [iconBtn.widthAnchor constraintEqualToConstant:size],
        [iconBtn.heightAnchor constraintEqualToConstant:size],
    ]];
    return container;
}

@end
