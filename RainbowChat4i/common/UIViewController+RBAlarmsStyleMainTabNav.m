//
//  UIViewController+RBAlarmsStyleMainTabNav.m
//  布局与视觉对齐 AlarmsViewController -rb_setupAlarmsCustomNavBar / viewDidLayoutSubviews 中顶栏相关逻辑。
//

#import "UIViewController+RBAlarmsStyleMainTabNav.h"
#import "BasicTool.h"
#import "Default.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// 与 AlarmsViewController.m 中同名常量一致
static const CGFloat kRBAlarmsStyleNavContentHeight = 26.0f;
static const CGFloat kRBAlarmsStyleNavButtonSize = 44.0f;
static const CGFloat kRBAlarmsStyleNavSideInsetFallback = 12.0f;
static const CGFloat kRBAlarmsStyleNavContentBottomOffset = 36.0f;

static const void *kRBAlarmsStyleBarKey = &kRBAlarmsStyleBarKey;
static const void *kRBAlarmsStyleHeightKey = &kRBAlarmsStyleHeightKey;
static const void *kRBAlarmsStyleBackdropKey = &kRBAlarmsStyleBackdropKey;
static const void *kRBAlarmsStyleLeftTitleKey = &kRBAlarmsStyleLeftTitleKey;
static const void *kRBAlarmsStyleLeftLeadingKey = &kRBAlarmsStyleLeftLeadingKey;
static const void *kRBAlarmsStyleRightPillTrailingKey = &kRBAlarmsStyleRightPillTrailingKey;
static const void *kRBAlarmsStyleCenterTitleKey = &kRBAlarmsStyleCenterTitleKey;
static const void *kRBAlarmsStyleMaskLayerKey = &kRBAlarmsStyleMaskLayerKey;
static const void *kRBAlarmsStyleTitleKeyCopyKey = &kRBAlarmsStyleTitleKeyCopyKey;

@implementation UIViewController (RBAlarmsStyleMainTabNav)

- (UIView *)rb_alarmsStyleMainTabNavigationBarIfInstalled
{
    return objc_getAssociatedObject(self, kRBAlarmsStyleBarKey);
}

- (void)rb_installAlarmsStyleMainTabNavigationBarWithLocalizedTitleKey:(NSString *)key
{
    [self rb_installAlarmsStyleMainTabNavigationBarWithLocalizedTitleKey:key addButtonMenu:nil];
}

- (void)rb_installAlarmsStyleMainTabNavigationBarWithLocalizedTitleKey:(NSString *)key
                                                       addButtonMenu:(UIMenu *)addButtonMenu
{
    if (self.rb_alarmsStyleMainTabNavigationBarIfInstalled) {
        return;
    }
    objc_setAssociatedObject(self, kRBAlarmsStyleTitleKeyCopyKey, [key copy], OBJC_ASSOCIATION_COPY_NONATOMIC);

    UIView *view = self.view;
    UIView *bar = [[UIView alloc] init];
    bar.backgroundColor = [UIColor clearColor];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:bar];
    objc_setAssociatedObject(self, kRBAlarmsStyleBarKey, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIVisualEffectView *backdrop = nil;
    if (@available(iOS 13.0, *)) {
        backdrop = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
        backdrop.translatesAutoresizingMaskIntoConstraints = NO;
        backdrop.userInteractionEnabled = NO;
        [bar insertSubview:backdrop atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [backdrop.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
            [backdrop.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
            [backdrop.topAnchor constraintEqualToAnchor:bar.topAnchor],
            [backdrop.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
        ]];
        objc_setAssociatedObject(self, kRBAlarmsStyleBackdropKey, backdrop, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        bar.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.65f];
    }

    NSLayoutConstraint *heightConstraint = [bar.heightAnchor constraintEqualToConstant:kRBAlarmsStyleNavContentHeight];
    heightConstraint.active = YES;
    objc_setAssociatedObject(self, kRBAlarmsStyleHeightKey, heightConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:view.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
    ]];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.backgroundColor = [UIColor clearColor];
    [bar addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-kRBAlarmsStyleNavContentBottomOffset],
        [content.heightAnchor constraintEqualToConstant:kRBAlarmsStyleNavContentHeight],
    ]];

    UILabel *leftNavTitle = [[UILabel alloc] init];
    leftNavTitle.translatesAutoresizingMaskIntoConstraints = NO;
    leftNavTitle.text = NSLocalizedString(key, nil);
    CGFloat leftTitlePt = [BasicTool getAdjustedFontSize:22.f];
    leftNavTitle.font = [UIFont systemFontOfSize:leftTitlePt weight:UIFontWeightSemibold];
    if (@available(iOS 13.0, *)) {
        leftNavTitle.textColor = [UIColor labelColor];
    } else {
        leftNavTitle.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
    }
    leftNavTitle.backgroundColor = [UIColor clearColor];
    leftNavTitle.userInteractionEnabled = NO;
    [content addSubview:leftNavTitle];
    objc_setAssociatedObject(self, kRBAlarmsStyleLeftTitleKey, leftNavTitle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSLayoutConstraint *leftLeading = nil;
    if (@available(iOS 15.0, *)) {
        leftLeading = [leftNavTitle.leadingAnchor constraintEqualToAnchor:view.readableContentGuide.leadingAnchor];
    } else if (@available(iOS 11.0, *)) {
        leftLeading = [leftNavTitle.leadingAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.leadingAnchor constant:kRBAlarmsStyleNavSideInsetFallback];
    } else {
        leftLeading = [leftNavTitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:kRBAlarmsStyleNavSideInsetFallback];
    }
    leftLeading.active = YES;
    objc_setAssociatedObject(self, kRBAlarmsStyleLeftLeadingKey, leftLeading, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [NSLayoutConstraint activateConstraints:@[
        [leftNavTitle.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
    ]];

    static const CGFloat kPillHeight = 44.0f;
    static const CGFloat kPillCornerRadius = 22.0f;
    static const CGFloat kPillPaddingH = 10.0f;
    static const CGFloat kPillBtnGap = 8.0f;
    static const CGFloat kPillBtnSize = 32.0f;
    static const CGFloat kPillWidth = kPillPaddingH + kPillBtnSize + kPillBtnGap + kPillBtnSize + kPillPaddingH;

    UIView *rightPill = [[UIView alloc] init];
    rightPill.backgroundColor = [UIColor clearColor];
    rightPill.layer.cornerRadius = kPillCornerRadius;
    rightPill.clipsToBounds = YES;
    rightPill.translatesAutoresizingMaskIntoConstraints = NO;
    [rightPill setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [content addSubview:rightPill];

    UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    searchBtn.translatesAutoresizingMaskIntoConstraints = NO;
    searchBtn.tintColor = [UIColor blackColor];
    searchBtn.backgroundColor = [UIColor clearColor];
    [searchBtn setImage:[[UIImage imageNamed:@"alarms_search"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [searchBtn addTarget:self action:@selector(doSearch:) forControlEvents:UIControlEventTouchUpInside];
    [rightPill addSubview:searchBtn];

    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    addBtn.translatesAutoresizingMaskIntoConstraints = NO;
    addBtn.tintColor = [UIColor blackColor];
    addBtn.backgroundColor = [UIColor clearColor];
    [addBtn setImage:[[UIImage imageNamed:@"alarms_add_friends2"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    if (@available(iOS 14.0, *)) {
        if (addButtonMenu != nil) {
            addBtn.menu = addButtonMenu;
            addBtn.showsMenuAsPrimaryAction = YES;
        } else {
            [addBtn addTarget:self action:@selector(doMores:) forControlEvents:UIControlEventTouchUpInside];
        }
    } else {
        [addBtn addTarget:self action:@selector(doMores:) forControlEvents:UIControlEventTouchUpInside];
    }
    [rightPill addSubview:addBtn];

    NSLayoutConstraint *pillWidthConstraint = [rightPill.widthAnchor constraintEqualToConstant:kPillWidth];
    pillWidthConstraint.priority = UILayoutPriorityRequired;

    NSLayoutConstraint *pillTrailing = nil;
    if (@available(iOS 15.0, *)) {
        pillTrailing = [rightPill.trailingAnchor constraintEqualToAnchor:view.readableContentGuide.trailingAnchor];
    } else if (@available(iOS 11.0, *)) {
        pillTrailing = [rightPill.trailingAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.trailingAnchor constant:-kRBAlarmsStyleNavSideInsetFallback];
    } else {
        pillTrailing = [rightPill.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-kRBAlarmsStyleNavSideInsetFallback];
    }
    pillTrailing.active = YES;
    objc_setAssociatedObject(self, kRBAlarmsStyleRightPillTrailingKey, pillTrailing, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [NSLayoutConstraint activateConstraints:@[
        [rightPill.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        pillWidthConstraint,
        [rightPill.heightAnchor constraintEqualToConstant:kPillHeight],
        [searchBtn.leadingAnchor constraintEqualToAnchor:rightPill.leadingAnchor constant:kPillPaddingH],
        [searchBtn.centerYAnchor constraintEqualToAnchor:rightPill.centerYAnchor],
        [searchBtn.widthAnchor constraintEqualToConstant:kPillBtnSize],
        [searchBtn.heightAnchor constraintEqualToConstant:kPillBtnSize],
        [addBtn.leadingAnchor constraintEqualToAnchor:searchBtn.trailingAnchor constant:kPillBtnGap],
        [addBtn.centerYAnchor constraintEqualToAnchor:rightPill.centerYAnchor],
        [addBtn.widthAnchor constraintEqualToConstant:kPillBtnSize],
        [addBtn.heightAnchor constraintEqualToConstant:kPillBtnSize],
        [addBtn.trailingAnchor constraintEqualToAnchor:rightPill.trailingAnchor constant:-kPillPaddingH],
    ]];

    UIVisualEffectView *pillBackdrop = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *effect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        pillBackdrop = [[UIVisualEffectView alloc] initWithEffect:effect];
    } else
#endif
    if (@available(iOS 13.0, *)) {
        pillBackdrop = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
    }
    if (pillBackdrop) {
        pillBackdrop.layer.cornerRadius = kPillCornerRadius;
        pillBackdrop.clipsToBounds = YES;
        pillBackdrop.userInteractionEnabled = NO;
        UIView *pillBlurHost = [[UIView alloc] init];
        pillBlurHost.translatesAutoresizingMaskIntoConstraints = NO;
        pillBlurHost.backgroundColor = [UIColor clearColor];
        pillBlurHost.userInteractionEnabled = NO;
        [rightPill insertSubview:pillBlurHost atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [pillBlurHost.leadingAnchor constraintEqualToAnchor:rightPill.leadingAnchor],
            [pillBlurHost.trailingAnchor constraintEqualToAnchor:rightPill.trailingAnchor],
            [pillBlurHost.topAnchor constraintEqualToAnchor:rightPill.topAnchor],
            [pillBlurHost.bottomAnchor constraintEqualToAnchor:rightPill.bottomAnchor],
        ]];
        pillBackdrop.translatesAutoresizingMaskIntoConstraints = YES;
        pillBackdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        pillBackdrop.frame = pillBlurHost.bounds;
        [pillBlurHost addSubview:pillBackdrop];
    } else {
        rightPill.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.9f];
    }

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"";
    titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    titleLabel.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:titleLabel];
    objc_setAssociatedObject(self, kRBAlarmsStyleCenterTitleKey, titleLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [titleLabel.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:leftNavTitle.trailingAnchor constant:10.0f],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:rightPill.leadingAnchor constant:-10.0f],
    ]];

    self.navigationItem.title = @"";
    self.additionalSafeAreaInsets = UIEdgeInsetsMake(kRBAlarmsStyleNavButtonSize, 0, 0, 0);

    [view bringSubviewToFront:bar];
}

- (void)rb_alarmsStyleMainTabNavHostViewWillAppear:(BOOL)animated
{
    if (!self.rb_alarmsStyleMainTabNavigationBarIfInstalled) {
        return;
    }
    BOOL inNavTransition = (self.transitionCoordinator != nil);
    if (inNavTransition && self.transitionCoordinator) {
        id<UIViewControllerTransitionCoordinator> tc = self.transitionCoordinator;
        __weak typeof(self) wself = self;
        [tc animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if ([context isCancelled]) {
                return;
            }
            __strong typeof(wself) sself = wself;
            if (!sself.navigationController) {
                return;
            }
            [sself.navigationController setNavigationBarHidden:YES animated:NO];
        }];
    } else {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
    UIView *bar = self.rb_alarmsStyleMainTabNavigationBarIfInstalled;
    if (bar) {
        [self.view bringSubviewToFront:bar];
    }
    UILabel *left = objc_getAssociatedObject(self, kRBAlarmsStyleLeftTitleKey);
    if (left) {
        CGFloat pt = [BasicTool getAdjustedFontSize:22.f];
        left.font = [UIFont systemFontOfSize:pt weight:UIFontWeightSemibold];
    }
    UILabel *center = objc_getAssociatedObject(self, kRBAlarmsStyleCenterTitleKey);
    if (center) {
        center.font = [UIFont boldSystemFontOfSize:17.0f];
    }
}

- (void)rb_alarmsStyleMainTabNavHostViewDidAppear:(BOOL)animated
{
    if (!self.rb_alarmsStyleMainTabNavigationBarIfInstalled) {
        return;
    }
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)rb_alarmsStyleMainTabNavHostViewWillDisappear:(BOOL)animated
{
    if (!self.rb_alarmsStyleMainTabNavigationBarIfInstalled) {
        return;
    }
    BOOL leavingStack = self.isMovingFromParentViewController || self.isBeingDismissed;
    if (!leavingStack && self.navigationController) {
        [self.navigationController setNavigationBarHidden:NO animated:animated];
    }
}

static void RBAlarmsStyleUpdateHorizontalInsetsForNonReadableGuide(UIViewController *selfVC)
{
    if (@available(iOS 15.0, *)) {
        return;
    }
    NSLayoutConstraint *leftLeading = objc_getAssociatedObject(selfVC, kRBAlarmsStyleLeftLeadingKey);
    NSLayoutConstraint *rightTrail = objc_getAssociatedObject(selfVC, kRBAlarmsStyleRightPillTrailingKey);
    if (!leftLeading) {
        return;
    }
    CGFloat lead = kRBAlarmsStyleNavSideInsetFallback;
    CGFloat trail = kRBAlarmsStyleNavSideInsetFallback;
    UINavigationBar *nb = selfVC.navigationController.navigationBar;
    if (nb != nil) {
        UIEdgeInsets m = nb.layoutMargins;
        if (m.left >= 4.f && m.left <= 48.f) {
            lead = m.left;
        }
        if (m.right >= 4.f && m.right <= 48.f) {
            trail = m.right;
        }
        if (@available(iOS 11.0, *)) {
            NSDirectionalEdgeInsets d = nb.directionalLayoutMargins;
            if (d.leading >= 4.f && d.leading <= 48.f) {
                lead = d.leading;
            }
            if (d.trailing >= 4.f && d.trailing <= 48.f) {
                trail = d.trailing;
            }
        }
    }
    leftLeading.constant = lead;
    if (rightTrail) {
        rightTrail.constant = -trail;
    }
}

- (void)rb_alarmsStyleMainTabNavHostViewDidLayoutSubviews
{
    UIView *bar = self.rb_alarmsStyleMainTabNavigationBarIfInstalled;
    if (!bar) {
        return;
    }
    NSLayoutConstraint *heightConstraint = objc_getAssociatedObject(self, kRBAlarmsStyleHeightKey);
    if (!heightConstraint) {
        return;
    }
    CGFloat topInset = self.view.safeAreaInsets.top;
    heightConstraint.constant = topInset + kRBAlarmsStyleNavContentHeight;
    self.additionalSafeAreaInsets = UIEdgeInsetsMake(kRBAlarmsStyleNavButtonSize, 0, 0, 0);

    UIVisualEffectView *backdrop = objc_getAssociatedObject(self, kRBAlarmsStyleBackdropKey);
    if (backdrop && backdrop.superview && backdrop.bounds.size.height > 0) {
        CAGradientLayer *maskLayer = objc_getAssociatedObject(self, kRBAlarmsStyleMaskLayerKey);
        if (!maskLayer) {
            maskLayer = [CAGradientLayer layer];
            maskLayer.colors = @[
                (id)[UIColor colorWithWhite:1.0f alpha:0.96f].CGColor,
                (id)[UIColor colorWithWhite:1.0f alpha:0.92f].CGColor,
                (id)[UIColor colorWithWhite:1.0f alpha:0.88f].CGColor,
                (id)[UIColor colorWithWhite:1.0f alpha:0.84f].CGColor,
                (id)[UIColor colorWithWhite:1.0f alpha:0.0f].CGColor
            ];
            maskLayer.locations = @[ @0.0f, @0.25f, @0.5f, @0.75f, @1.0f ];
            maskLayer.startPoint = CGPointMake(0.5, 0);
            maskLayer.endPoint = CGPointMake(0.5, 1);
            objc_setAssociatedObject(self, kRBAlarmsStyleMaskLayerKey, maskLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            backdrop.layer.mask = maskLayer;
        }
        if (!CGRectEqualToRect(maskLayer.frame, backdrop.bounds)) {
            maskLayer.frame = backdrop.bounds;
        }
    }

    RBAlarmsStyleUpdateHorizontalInsetsForNonReadableGuide(self);
}

@end
