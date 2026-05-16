//
//  ChatMessageModeMenu.m
//  RainbowChat4i
//

#import "ChatMessageModeMenu.h"
#import <objc/runtime.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
#import <UIKit/UIGlassEffect.h>
#endif

static const void *kChatMessageModeMenuHolderKey = &kChatMessageModeMenuHolderKey;

@interface ChatMessageModeMenu ()
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) ChatMessageModeMenuSelectBlock selectBlock;
@property (nonatomic, strong) UIView *overlay;
@property (nonatomic, strong) UIView *capsule;
@end

@implementation ChatMessageModeMenu

#pragma mark - 导航栏「搜索+更多」胶囊（两页共用）

+ (UIView *)navSearchMoreCapsuleWithSearchTarget:(id)searchTarget
                                    searchAction:(SEL)searchAction
                                      moreTarget:(id)moreTarget
                                       moreAction:(SEL)moreAction
{
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 88, 32)];
    container.backgroundColor = [UIColor clearColor];
    container.layer.cornerRadius = 16.f;
    container.layer.masksToBounds = YES;

    UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    searchBtn.frame = CGRectMake(8, 0, 32, 32);
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"magnifyingglass"];
        searchBtn.tintColor = [UIColor blackColor];
        [searchBtn setImage:img forState:UIControlStateNormal];
    } else {
        [searchBtn setTitle:@"🔍" forState:UIControlStateNormal];
    }
    searchBtn.backgroundColor = [UIColor clearColor];
    [searchBtn addTarget:searchTarget action:searchAction forControlEvents:UIControlEventTouchUpInside];

    UIButton *moreBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    moreBtn.frame = CGRectMake(48, 0, 32, 32);
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"ellipsis"];
        moreBtn.tintColor = [UIColor blackColor];
        [moreBtn setImage:img forState:UIControlStateNormal];
    } else {
        [moreBtn setTitle:@"⋯" forState:UIControlStateNormal];
    }
    moreBtn.backgroundColor = [UIColor clearColor];
    [moreBtn addTarget:moreTarget action:moreAction forControlEvents:UIControlEventTouchUpInside];

    [container addSubview:searchBtn];
    [container addSubview:moreBtn];
    return container;
}

+ (UIView *)navSearchOnlyButtonWithTarget:(id)searchTarget action:(SEL)searchAction
{
    static const CGFloat kSide = 36.f;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kSide, kSide)];
    container.backgroundColor = [UIColor clearColor];

    UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    searchBtn.frame = container.bounds;
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"magnifyingglass"];
        searchBtn.tintColor = [UIColor blackColor];
        [searchBtn setImage:img forState:UIControlStateNormal];
    } else {
        [searchBtn setTitle:@"🔍" forState:UIControlStateNormal];
    }
    searchBtn.backgroundColor = [UIColor clearColor];
    [searchBtn addTarget:searchTarget action:searchAction forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:searchBtn];
    return container;
}

#pragma mark - 弹窗

+ (void)showFromViewController:(UIViewController *)viewController
                    anchorView:(UIView *)anchorView
                 onSelectIndex:(ChatMessageModeMenuSelectBlock)block
{
    if (!viewController || !anchorView || !block) return;
    ChatMessageModeMenu *holder = [[ChatMessageModeMenu alloc] init];
    holder.viewController = viewController;
    holder.selectBlock = block;
    objc_setAssociatedObject(viewController, kChatMessageModeMenuHolderKey, holder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [holder showWithAnchorView:anchorView];
}

- (void)showWithAnchorView:(UIView *)anchorView
{
    UIView *hostView = self.viewController.view.window ?: self.viewController.view;
    CGRect hostBounds = hostView.bounds;

    UIView *overlay = [[UIView alloc] initWithFrame:hostBounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = [UIColor clearColor];
    [overlay addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)]];
    [hostView addSubview:overlay];
    self.overlay = overlay;

    static const CGFloat kCapsuleWidth = 200;
    static const CGFloat kRowHeight = 48;
    static const CGFloat kCornerRadius = 24.f;
    CGFloat capsuleHeight = kRowHeight * 2;

    CGRect navRect = [anchorView.superview convertRect:anchorView.frame toView:hostView];
    CGFloat x = CGRectGetMaxX(navRect) - kCapsuleWidth;
    CGFloat y = CGRectGetMaxY(navRect) + 8;
    if (y + capsuleHeight > hostBounds.size.height - 24) {
        y = CGRectGetMinY(navRect) - capsuleHeight - 8;
    }
    if (x < 16) x = 16;
    if (x + kCapsuleWidth > hostBounds.size.width - 16) x = hostBounds.size.width - 16 - kCapsuleWidth;

    UIView *capsuleWrapper = [[UIView alloc] initWithFrame:CGRectMake(x, y, kCapsuleWidth, capsuleHeight)];
    capsuleWrapper.backgroundColor = [UIColor clearColor];
    capsuleWrapper.layer.cornerRadius = kCornerRadius;
    if (@available(iOS 13.0, *)) {
        capsuleWrapper.layer.cornerCurve = kCACornerCurveContinuous;
    }
    capsuleWrapper.layer.shadowColor = [UIColor blackColor].CGColor;
    capsuleWrapper.layer.shadowOffset = CGSizeMake(0, 6);
    capsuleWrapper.layer.shadowRadius = 20;
    capsuleWrapper.layer.shadowOpacity = 0.22f;
    [overlay addSubview:capsuleWrapper];
    self.capsule = capsuleWrapper;

    UIView *contentHost = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *glassEffect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:glassEffect];
        glassView.frame = capsuleWrapper.bounds;
        glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        glassView.layer.cornerRadius = kCornerRadius;
        glassView.layer.cornerCurve = kCACornerCurveContinuous;
        glassView.layer.masksToBounds = YES;
        glassView.clipsToBounds = YES;
        [capsuleWrapper addSubview:glassView];
        contentHost = glassView.contentView;
    } else
#endif
    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
        blur.frame = capsuleWrapper.bounds;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blur.layer.cornerRadius = kCornerRadius;
        blur.layer.cornerCurve = kCACornerCurveContinuous;
        blur.layer.masksToBounds = YES;
        blur.clipsToBounds = YES;
        [capsuleWrapper addSubview:blur];
        blur.contentView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.25];
        contentHost = blur.contentView;
    } else {
        UIView *solid = [[UIView alloc] initWithFrame:capsuleWrapper.bounds];
        solid.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.92];
        solid.layer.cornerRadius = kCornerRadius;
        solid.clipsToBounds = YES;
        [capsuleWrapper addSubview:solid];
        contentHost = solid;
    }

    NSArray *titles = @[ @"以聊天模式查看", @"以消息模式查看" ];
    for (NSInteger i = 0; i < 2; i++) {
        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
        row.frame = CGRectMake(16, i * kRowHeight, kCapsuleWidth - 32, kRowHeight);
        row.tag = i;
        [row setTitle:titles[i] forState:UIControlStateNormal];
        [row setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        row.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.titleEdgeInsets = UIEdgeInsetsMake(0, 32, 0, 0);
        [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
        row.backgroundColor = [UIColor clearColor];

        UIImageView *check = [[UIImageView alloc] initWithFrame:CGRectMake(0, (kRowHeight - 20) / 2, 20, 20)];
        check.tag = 100;
        if (@available(iOS 13.0, *)) {
            check.image = [UIImage systemImageNamed:@"checkmark"];
            check.tintColor = [UIColor labelColor];
        }
        check.hidden = (i != 1);
        [row addSubview:check];
        [contentHost addSubview:row];
    }

    capsuleWrapper.transform = CGAffineTransformMakeScale(0.82, 0.82);
    capsuleWrapper.alpha = 0;
    overlay.alpha = 0;

    [UIView animateWithDuration:0.52 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.4 options:0 animations:^{
        overlay.alpha = 1;
        capsuleWrapper.alpha = 1;
        capsuleWrapper.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)rowTapped:(UIButton *)sender
{
    NSInteger index = sender.tag;
    ChatMessageModeMenuSelectBlock block = self.selectBlock;
    [self dismiss];
    if (block) block(index);
}

- (void)dismiss
{
    UIView *overlay = self.overlay;
    UIView *capsule = self.capsule;
    self.overlay = nil;
    self.capsule = nil;
    if (self.viewController) {
        objc_setAssociatedObject(self.viewController, kChatMessageModeMenuHolderKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (!overlay || !capsule) return;

    [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        overlay.alpha = 0;
        capsule.alpha = 0;
        capsule.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

@end
