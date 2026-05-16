//
//  UIViewController+RBPlainCustomNav.m
//

#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"
#import "BasicTool.h"
#import <objc/runtime.h>

static const void *kRBPlainCustomNavBarKey = &kRBPlainCustomNavBarKey;

static RBChromeNavigationBar *RBPlainNavGetBar(UIViewController *self)
{
    return objc_getAssociatedObject(self, kRBPlainCustomNavBarKey);
}

/// 当前 VC 为转场中的 from 时：隐藏本页 RBChrome 返回键，避免与 to 页叠成双箭头；结束或取消后恢复。
static void RBPlainCustomNavHideOutgoingChromeBackArrowIfNeeded(UIViewController *selfVC)
{
    if (selfVC == nil) {
        return;
    }
    id<UIViewControllerTransitionCoordinator> tc = selfVC.transitionCoordinator;
    if (tc == nil || !tc.isAnimated) {
        return;
    }
    UIViewController *fromT = [tc viewControllerForKey:UITransitionContextFromViewControllerKey];
    if (fromT != selfVC) {
        return;
    }
    RBChromeNavigationBar *bar = RBPlainNavGetBar(fromT);
    if (bar == nil) {
        return;
    }
    bar.backButton.hidden = YES;
    __weak RBChromeNavigationBar *wbar = bar;
    [tc animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        RBChromeNavigationBar *b = wbar;
        if (b != nil) {
            b.backButton.hidden = b.rb_isMainTabRootChromeStyle;
        }
    }];
}

/// 当前 VC 为转场中的 to 时：隐藏下层 from 页顶栏返回键，只保留本页（上一页）返回可见；结束或取消后恢复 from 页箭头。
static void RBPlainCustomNavHideUnderlyingChromeBackArrowIfNeeded(UIViewController *selfVC)
{
    if (selfVC == nil) {
        return;
    }
    id<UIViewControllerTransitionCoordinator> tc = selfVC.transitionCoordinator;
    if (tc == nil || !tc.isAnimated) {
        return;
    }
    UIViewController *fromT = [tc viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toT = [tc viewControllerForKey:UITransitionContextToViewControllerKey];
    if (toT != selfVC || fromT == nil || fromT == selfVC) {
        return;
    }
    RBChromeNavigationBar *fromBar = RBPlainNavGetBar(fromT);
    if (fromBar == nil) {
        return;
    }
    fromBar.backButton.hidden = YES;
    __weak RBChromeNavigationBar *wFromBar = fromBar;
    [tc animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        RBChromeNavigationBar *b = wFromBar;
        if (b != nil) {
            b.backButton.hidden = b.rb_isMainTabRootChromeStyle;
        }
    }];
}

/// Plain 顶栏：标题与返回为黑色；右侧/左侧槽内文字按钮除「删除所有」为红外一律黑色（含仅图标按钮的 tint）。
static void RBPlainChromeApplyDefaultNavTextColors(RBChromeNavigationBar *bar)
{
    if (bar == nil) {
        return;
    }
    bar.titleLabel.textColor = [UIColor blackColor];
    bar.backButton.tintColor = [UIColor blackColor];

    UIButton *multi = bar.multiSelectCancelButton;
    if (multi != nil && !multi.hidden) {
        NSString *mt = [multi titleForState:UIControlStateNormal];
        if ([mt isEqualToString:@"删除所有"]) {
            if (@available(iOS 13.0, *)) {
                multi.tintColor = [UIColor systemRedColor];
                [multi setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
            } else {
                multi.tintColor = [UIColor redColor];
                [multi setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
            }
        } else {
            multi.tintColor = [UIColor blackColor];
            if (mt.length > 0) {
                [multi setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            }
        }
    }

    void (^styleTitleButton)(UIButton *) = ^(UIButton *b) {
        NSString *t = [b titleForState:UIControlStateNormal] ?: @"";
        if ([t isEqualToString:@"删除所有"]) {
            if (@available(iOS 13.0, *)) {
                b.tintColor = [UIColor systemRedColor];
                [b setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
            } else {
                b.tintColor = [UIColor redColor];
                [b setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
            }
        } else {
            b.tintColor = [UIColor blackColor];
            if (t.length > 0) {
                [b setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            }
        }
    };

    __block void (^walk)(UIView *);
    walk = ^(UIView *v) {
        if (v == nil) {
            return;
        }
        for (UIView *sub in v.subviews) {
            if ([sub isKindOfClass:[UIButton class]]) {
                styleTitleButton((UIButton *)sub);
            }
            walk(sub);
        }
    };
    walk(bar.rightAccessoryContainer);
}

static void RBPlainNavSetBar(UIViewController *self, RBChromeNavigationBar *bar)
{
    objc_setAssociatedObject(self, kRBPlainCustomNavBarKey, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UIViewController (RBPlainCustomNav)

- (nullable RBChromeNavigationBar *)rb_plainChromeNavigationBarIfInstalled
{
    return RBPlainNavGetBar(self);
}

- (void)rb_plainCustomNavPopBack
{
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)rb_installPlainCustomNavigationBarWithTitle:(NSString *)title
{
    RBChromeNavigationBar *bar = RBPlainNavGetBar(self);
    if (bar) {
        bar.titleLabel.text = title ?: @"";
        [self rb_plainCustomNavUpdateTitleFont];
        return;
    }

    bar = [[RBChromeNavigationBar alloc] initWithBottomPinStyle:RBChromeNavigationBarBottomPinStyleExtendedSafeAreaTop];
    bar.contentRowHeight = 44.f;
    bar.titleLabel.text = title ?: @"";
    [bar setBackButtonTarget:self action:@selector(rb_plainCustomNavPopBack)];
    RBPlainNavSetBar(self, bar);

    self.navigationItem.title = @"";
    self.additionalSafeAreaInsets = UIEdgeInsetsMake(44.f, 0, 0, 0);
    [bar installInHostView:self.view];
    [self rb_plainCustomNavUpdateTitleFont];
}

- (void)rb_installPlainCustomNavigationBarWithTitle:(NSString *)title
                                  rightButtonImage:(UIImage *)image
                                            target:(id)target
                                            action:(SEL)action
{
    RBChromeNavigationBar *bar = RBPlainNavGetBar(self);
    if (!bar) {
        bar = [[RBChromeNavigationBar alloc] initWithBottomPinStyle:RBChromeNavigationBarBottomPinStyleExtendedSafeAreaTop];
        bar.contentRowHeight = 44.f;
        [bar setBackButtonTarget:self action:@selector(rb_plainCustomNavPopBack)];
        RBPlainNavSetBar(self, bar);
    }
    bar.titleLabel.text = title ?: @"";
    [bar clearRightAccessorySubviews];
    if (image && target && action) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(0, 0, 44.f, 44.f);
        [btn setImage:image forState:UIControlStateNormal];
        btn.tintColor = [UIColor blackColor];
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        [bar attachRightAccessoryView:btn];
    }

    self.navigationItem.title = @"";
    self.additionalSafeAreaInsets = UIEdgeInsetsMake(44.f, 0, 0, 0);
    if (!bar.superview) {
        [bar installInHostView:self.view];
    }
    [self rb_plainCustomNavUpdateTitleFont];
}

- (void)rb_installPlainCustomNavigationBarForMainTabRootWithLocalizedTitleKey:(NSString *)key
                                                           rightAccessoryView:(UIView *)rightAccessoryView
{
    NSString *title = NSLocalizedString(key, nil);
    RBChromeNavigationBar *bar = RBPlainNavGetBar(self);
    if (!bar) {
        bar = [[RBChromeNavigationBar alloc] initWithBottomPinStyle:RBChromeNavigationBarBottomPinStyleExtendedSafeAreaTop];
        bar.contentRowHeight = 44.f;
        bar.titleLabel.text = title ?: @"";
        RBPlainNavSetBar(self, bar);
        self.navigationItem.title = @"";
        self.additionalSafeAreaInsets = UIEdgeInsetsMake(44.f, 0, 0, 0);
        [bar installInHostView:self.view];
        [bar rb_applyMainTabRootChromeStyle];
        [self rb_plainCustomNavUpdateTitleFont];
    } else {
        bar.titleLabel.text = title ?: @"";
        [bar rb_applyMainTabRootChromeStyle];
        [self rb_plainCustomNavUpdateTitleFont];
    }
    [bar clearRightAccessorySubviews];
    if (rightAccessoryView) {
        [bar attachRightAccessoryView:rightAccessoryView];
    }
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
}

- (void)rb_plainCustomNavHostViewWillAppear:(BOOL)animated
{
    RBChromeNavigationBar *bar = RBPlainNavGetBar(self);
    if (!bar) {
        return;
    }
    [UIView performWithoutAnimation:^{
        bar.hidden = NO;
        UIEdgeInsets need = UIEdgeInsetsMake(44.f, 0, 0, 0);
        if (!UIEdgeInsetsEqualToEdgeInsets(self.additionalSafeAreaInsets, need)) {
            self.additionalSafeAreaInsets = need;
        }
        if (!bar.superview) {
            [bar installInHostView:self.view];
        }
        [self.view bringSubviewToFront:bar];
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }];
    RBPlainCustomNavHideUnderlyingChromeBackArrowIfNeeded(self);
}

- (void)rb_plainCustomNavUpdateTitleFont
{
    RBChromeNavigationBar *bar = RBPlainNavGetBar(self);
    if (!bar) {
        return;
    }
    [UIView performWithoutAnimation:^{
        CGFloat pt = [BasicTool getAdjustedFontSize:17.f];
        bar.titleLabel.font = [UIFont boldSystemFontOfSize:pt];
        RBPlainChromeApplyDefaultNavTextColors(bar);
    }];
}

- (void)rb_plainCustomNavHostViewDidAppear:(BOOL)animated
{
    [UIView performWithoutAnimation:^{
        if (self.navigationController) {
            [self.navigationController setNavigationBarHidden:YES animated:NO];
        }
        [self rb_plainCustomNavUpdateTitleFont];
    }];
}

- (void)rb_plainCustomNavHostViewWillDisappear:(BOOL)animated
{
    RBPlainCustomNavHideOutgoingChromeBackArrowIfNeeded(self);
    BOOL leavingStack = self.isMovingFromParentViewController || self.isBeingDismissed;
    // 不再在此处 setNavigationBarHidden:NO：会闪出系统导航栏并改变安全区，导致 RBChrome 标题在 push/pop 边界抖动；子页 willAppear 会继续保持隐藏。
    // 自定义 push 转场会同时露出下层页：下层若仍显示自己的 RBChrome 顶栏会与当前页双返回，盖住时再隐藏
    if (!leavingStack && self.navigationController && self.navigationController.viewControllers.lastObject != self) {
        RBChromeNavigationBar *bar = RBPlainNavGetBar(self);
        if (bar) {
            bar.hidden = YES;
        }
    }
}

- (void)rb_plainCustomNavHostViewDidDisappear:(BOOL)animated
{
    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        self.additionalSafeAreaInsets = UIEdgeInsetsZero;
    }
}

- (void)rb_plainCustomNavSetBackHiddenDuringNavigationTransitionIfAnimated
{
    RBChromeNavigationBar *bar = RBPlainNavGetBar(self);
    if (bar == nil) {
        return;
    }
    id<UIViewControllerTransitionCoordinator> tc = self.transitionCoordinator;
    if (tc == nil || !tc.isAnimated) {
        return;
    }
    bar.backButton.hidden = YES;
    __weak RBChromeNavigationBar *wbar = bar;
    [tc animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        RBChromeNavigationBar *b = wbar;
        if (b != nil) {
            b.backButton.hidden = b.rb_isMainTabRootChromeStyle;
        }
    }];
}

@end
