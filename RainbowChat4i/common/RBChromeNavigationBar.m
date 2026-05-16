//
//  RBChromeNavigationBar.m
//

#import "RBChromeNavigationBar.h"
#import "BasicTool.h"
#import "Default.h"

static UIColor *RBChromeNavigationBarBackgroundColor(void)
{
    return [UIColor colorWithRed:237.f / 255.f green:237.f / 255.f blue:237.f / 255.f alpha:1.f];
}

@interface RBChromeNavigationBar ()
@property (nonatomic, assign) RBChromeNavigationBarBottomPinStyle rb_pinStyle;
@property (nonatomic, strong) UIView *rb_contentView;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UIButton *backButton;
@property (nonatomic, strong, readwrite) UIButton *multiSelectCancelButton;
@property (nonatomic, strong, readwrite) UIView *leftAccessoryContainer;
@property (nonatomic, strong, readwrite) UIView *rightAccessoryContainer;
@property (nonatomic, strong, readwrite, nullable) UIView *backdropView;
@property (nonatomic, strong) NSLayoutConstraint *rb_leftWrapWidthConstraint;
@property (nonatomic, assign) BOOL rb_chatStyleApplied;
@end

@implementation RBChromeNavigationBar

- (instancetype)initWithBottomPinStyle:(RBChromeNavigationBarBottomPinStyle)pinStyle
{
    self = [super initWithFrame:CGRectZero];
    if (!self) {
        return nil;
    }
    _rb_pinStyle = pinStyle;
    _contentRowHeight = 44.f;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = [UIColor clearColor];

    UIView *backdrop = [[UIView alloc] init];
    backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    backdrop.userInteractionEnabled = NO;
    backdrop.backgroundColor = RBChromeNavigationBarBackgroundColor();
    [self insertSubview:backdrop atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [backdrop.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [backdrop.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [backdrop.topAnchor constraintEqualToAnchor:self.topAnchor],
        [backdrop.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];
    _backdropView = backdrop;

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.backgroundColor = [UIColor clearColor];
    [self addSubview:content];
    _rb_contentView = content;

    UIView *leftWrap = [[UIView alloc] init];
    leftWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:leftWrap];
    _leftAccessoryContainer = leftWrap;

    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.translatesAutoresizingMaskIntoConstraints = NO;
    backBtn.tintColor = [UIColor blackColor];
    backBtn.adjustsImageWhenHighlighted = NO;
    [leftWrap addSubview:backBtn];
    _backButton = backBtn;

    UIButton *cancelMulti = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelMulti.translatesAutoresizingMaskIntoConstraints = NO;
    cancelMulti.hidden = YES;
    [cancelMulti setTitle:NSLocalizedString(@"general_cancel", @"取消") forState:UIControlStateNormal];
    cancelMulti.titleLabel.font = [UIFont systemFontOfSize:17];
    [leftWrap addSubview:cancelMulti];
    _multiSelectCancelButton = cancelMulti;

    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.translatesAutoresizingMaskIntoConstraints = NO;
    titleLab.font = [BasicTool getBoldSystemFontOfSize:16.0f];
    titleLab.textAlignment = NSTextAlignmentCenter;
    titleLab.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
    titleLab.lineBreakMode = NSLineBreakByTruncatingTail;
    [content addSubview:titleLab];
    _titleLabel = titleLab;

    UIView *rightHost = [[UIView alloc] init];
    rightHost.translatesAutoresizingMaskIntoConstraints = NO;
    rightHost.backgroundColor = [UIColor clearColor];
    [content addSubview:rightHost];
    _rightAccessoryContainer = rightHost;

    UILayoutGuide *pinSafe = self.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [content.heightAnchor constraintEqualToConstant:_contentRowHeight],

        [leftWrap.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:4.f],
        [leftWrap.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [leftWrap.heightAnchor constraintEqualToConstant:44.f],

        [backBtn.centerXAnchor constraintEqualToAnchor:leftWrap.centerXAnchor],
        [backBtn.centerYAnchor constraintEqualToAnchor:leftWrap.centerYAnchor],
        [backBtn.widthAnchor constraintEqualToConstant:36.f],
        [backBtn.heightAnchor constraintEqualToConstant:36.f],

        [cancelMulti.centerXAnchor constraintEqualToAnchor:leftWrap.centerXAnchor],
        [cancelMulti.centerYAnchor constraintEqualToAnchor:leftWrap.centerYAnchor],

        [titleLab.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [titleLab.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [titleLab.leadingAnchor constraintGreaterThanOrEqualToAnchor:leftWrap.trailingAnchor constant:8.f],
        [titleLab.trailingAnchor constraintLessThanOrEqualToAnchor:rightHost.leadingAnchor constant:-8.f],

        [rightHost.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-4.f],
        [rightHost.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [rightHost.heightAnchor constraintEqualToConstant:44.f],
        [rightHost.widthAnchor constraintGreaterThanOrEqualToConstant:40.f],
    ]];

    NSLayoutConstraint *lw = [leftWrap.widthAnchor constraintEqualToConstant:44.f];
    lw.active = YES;
    _rb_leftWrapWidthConstraint = lw;

    return self;
}

- (void)rb_applyChatWhiteTranslucentBackdrop
{
    self.rb_chatStyleApplied = YES;
    UIView *backdrop = self.backdropView;
    if (!backdrop) {
        return;
    }
    for (UIView *sub in [backdrop.subviews copy]) {
        [sub removeFromSuperview];
    }
    backdrop.backgroundColor = [UIColor clearColor];

    UIBlurEffect *blurEffect = nil;
    if (@available(iOS 13.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialLight];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    [backdrop addSubview:blurView];
    [NSLayoutConstraint activateConstraints:@[
        [blurView.leadingAnchor constraintEqualToAnchor:backdrop.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:backdrop.trailingAnchor],
        [blurView.topAnchor constraintEqualToAnchor:backdrop.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:backdrop.bottomAnchor],
    ]];

    UIView *veil = [[UIView alloc] init];
    veil.translatesAutoresizingMaskIntoConstraints = NO;
    veil.userInteractionEnabled = NO;
    // 聊天顶栏：略降白罩 alpha，比 0.42 更透一点，仍保留浅色条可读性
    veil.backgroundColor = [UIColor colorWithWhite:1.f alpha:0.26f];
    [backdrop addSubview:veil];
    [NSLayoutConstraint activateConstraints:@[
        [veil.leadingAnchor constraintEqualToAnchor:backdrop.leadingAnchor],
        [veil.trailingAnchor constraintEqualToAnchor:backdrop.trailingAnchor],
        [veil.topAnchor constraintEqualToAnchor:backdrop.topAnchor],
        [veil.bottomAnchor constraintEqualToAnchor:backdrop.bottomAnchor],
    ]];
}

- (void)rb_applyChatTitleStyleIfNeeded
{
    if (!self.rb_chatStyleApplied || self.rb_isMainTabRootChromeStyle) {
        return;
    }
    if (!self.titleLabel) {
        return;
    }
    self.titleLabel.font = [BasicTool getBoldSystemFontOfSize:16.0f];
    self.titleLabel.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self rb_applyChatTitleStyleIfNeeded];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self rb_applyChatTitleStyleIfNeeded];
}

- (void)setContentRowHeight:(CGFloat)contentRowHeight
{
    if (contentRowHeight <= 0) {
        contentRowHeight = 44.f;
    }
    _contentRowHeight = contentRowHeight;
    for (NSLayoutConstraint *c in self.rb_contentView.constraints) {
        if (c.firstItem == self.rb_contentView && c.firstAttribute == NSLayoutAttributeHeight) {
            c.constant = contentRowHeight;
            break;
        }
    }
}

- (void)installInHostView:(UIView *)hostView
{
    if (!hostView || self.superview) {
        return;
    }
    [hostView addSubview:self];
    UILayoutGuide *safe = hostView.safeAreaLayoutGuide;
    CGFloat bottomOffset = (self.rb_pinStyle == RBChromeNavigationBarBottomPinStyleExtendedSafeAreaTop) ? 0.f : self.contentRowHeight;
    [NSLayoutConstraint activateConstraints:@[
        [self.topAnchor constraintEqualToAnchor:hostView.topAnchor],
        [self.leadingAnchor constraintEqualToAnchor:hostView.leadingAnchor],
        [self.trailingAnchor constraintEqualToAnchor:hostView.trailingAnchor],
        [self.bottomAnchor constraintEqualToAnchor:safe.topAnchor constant:bottomOffset],
    ]];
    [hostView bringSubviewToFront:self];
}

- (void)setBackButtonTarget:(id)target action:(SEL)action
{
    [self.backButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    if (target && action) {
        [self.backButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }
    self.backButton.hidden = NO;
    self.backButton.tintColor = [UIColor blackColor];
    self.backButton.adjustsImageWhenHighlighted = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
        [self.backButton setImage:[UIImage systemImageNamed:@"chevron.left" withConfiguration:cfg] forState:UIControlStateNormal];
        [self.backButton setTitle:nil forState:UIControlStateNormal];
    } else {
        [self.backButton setTitle:@"<" forState:UIControlStateNormal];
        self.backButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [self.backButton setImage:nil forState:UIControlStateNormal];
    }
}

- (void)clearRightAccessorySubviews
{
    if (!self.rightAccessoryContainer) {
        return;
    }
    for (UIView *sub in self.rightAccessoryContainer.subviews) {
        [sub removeFromSuperview];
    }
}

- (void)attachRightAccessoryView:(UIView *)view
{
    if (!view || !self.rightAccessoryContainer) {
        return;
    }
    [self clearRightAccessorySubviews];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.rightAccessoryContainer addSubview:view];

    [view.centerYAnchor constraintEqualToAnchor:self.rightAccessoryContainer.centerYAnchor].active = YES;

    // UIButton：宽度随标题变化（创建群/选择目标里「确定(n)」等），固定 width 会导致文字被裁切
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        [btn setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [btn setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [view.leadingAnchor constraintEqualToAnchor:self.rightAccessoryContainer.leadingAnchor].active = YES;
        [view.trailingAnchor constraintEqualToAnchor:self.rightAccessoryContainer.trailingAnchor].active = YES;
        return;
    }

    CGFloat w = CGRectGetWidth(view.bounds);
    CGFloat h = CGRectGetHeight(view.bounds);
    if (w <= 0 || h <= 0) {
        CGSize intrinsic = view.intrinsicContentSize;
        if (w <= 0 && intrinsic.width > 0) {
            w = intrinsic.width;
        }
        if (h <= 0 && intrinsic.height > 0) {
            h = intrinsic.height;
        }
    }
    if (w <= 0) {
        w = 44.f;
    }
    if (h <= 0) {
        h = 44.f;
    }
    [NSLayoutConstraint activateConstraints:@[
        [view.trailingAnchor constraintEqualToAnchor:self.rightAccessoryContainer.trailingAnchor],
        [view.widthAnchor constraintEqualToConstant:w],
        [view.heightAnchor constraintEqualToConstant:h],
    ]];
}

- (void)attachCircularRightAccessoryView:(UIView *)container sideLength:(CGFloat)side trailingInsetFromRight:(CGFloat)trailingInset
{
    if (!container || !self.rightAccessoryContainer || side <= 0) {
        return;
    }
    [self clearRightAccessorySubviews];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.layer.cornerRadius = side * 0.5f;
    container.clipsToBounds = YES;
    [self.rightAccessoryContainer addSubview:container];
    [NSLayoutConstraint activateConstraints:@[
        [container.widthAnchor constraintEqualToConstant:side],
        [container.heightAnchor constraintEqualToConstant:side],
        [container.trailingAnchor constraintEqualToAnchor:self.rightAccessoryContainer.trailingAnchor constant:-trailingInset],
        [container.centerYAnchor constraintEqualToAnchor:self.rightAccessoryContainer.centerYAnchor],
    ]];
}

- (void)setMultiSelectModeVisualActive:(BOOL)active
{
    self.backButton.hidden = active || self.rb_isMainTabRootChromeStyle;
    self.multiSelectCancelButton.hidden = !active;
}

- (void)rb_applyMainTabRootChromeStyle
{
    self.rb_isMainTabRootChromeStyle = YES;
    [self.backButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    self.backButton.hidden = YES;
    self.multiSelectCancelButton.hidden = YES;
    if (self.rb_leftWrapWidthConstraint) {
        self.rb_leftWrapWidthConstraint.constant = 0.f;
    }
}

@end
