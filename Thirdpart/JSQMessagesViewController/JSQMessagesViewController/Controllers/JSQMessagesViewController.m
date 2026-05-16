//telegram @wz662
//  ----------------------------------------------------------------------
//  Copyright (C) 2018  即时通讯网(52im.net) & Jack Jiang.
//  The RainbowChat Project. All rights reserved.
//
//  > 文档地址: http://www.52im.net/thread-19-1-1.html
//  > 即时通讯技术社区：http://www.52im.net/
//  > 即时通讯技术交流群：320837163 (http://www.52im.net/topic-qqgroup.html)
//
//  "即时通讯网(52im.net) - 即时通讯开发者社区!" 推荐IM工程。
//
//  如需联系作者，请发邮件至 jack.jiang@52im.net 或 jb2011@163.com.
//  ----------------------------------------------------------------------
//
//  【版权申明】：本类原作者为JSQ作者，因原工程已停止更新，当前由JackJiang修改并用于RainbowChat等工程中，感谢原作者。


#import "JSQMessagesViewController.h"

#import "JSQMessagesCollectionViewFlowLayoutInvalidationContext.h"

#import "JSQMessage.h"
#import "JSQMessagesBubbleImage.h"
//#import "JSQMessagesAvatarImage.h"

#import "JSQMessagesCollectionViewCellIncoming.h"
#import "JSQMessagesCollectionViewCellOutgoing.h"

#import "JSQMessagesTypingIndicatorFooterView.h"
#import "JSQMessagesLoadEarlierHeaderView.h"

#import "JSQMessagesToolbarContentView.h"
#import "JSQMessagesInputToolbar.h"
#import "JSQMessagesComposerTextView.h"

#import "NSString+JSQMessages.h"
#import "UIColor+JSQMessages.h"
#import "UIDevice+JSQMessages.h"
#import "NSBundle+JSQMessages.h"
#import <objc/runtime.h>
#import "Masonry.h"
#import "JSQAudioMediaItem.h"
#import "rbSystemInfoCollectionViewCell.h"
#import "MsgBodyRoot.h"
#import "RevokedMeta.h"

#import "EmojiUtil.h"


@interface JSQMessagesViewController (RainbowChatSoftScroll)
- (void)rb_setChatCollectionViewContentOffset:(CGPoint)targetOffset animated:(BOOL)animated;
@end

const CGFloat k_RBBottomBoxViewHeight = 208;

// 悬浮输入条与更多面板（方案 C）常量
static const CGFloat kRBFloatingBarHorizontalInset = 12.f;
/// 悬浮条距屏幕物理底部的留白（正值=往上一点，避免贴得太下）
static const CGFloat kRBFloatingBarBottomInset = 10.f;
/// 悬浮条休息位置时 toolbarBottomLayoutGuide 的 constant（safeArea.bottom = toolbar.bottom + constant）
static inline CGFloat rb_floatingBarRestConstant(void) {
    return -(CGFloat)[BasicTool getSafeAreaInsets_bottom] + kRBFloatingBarBottomInset;
}
static const CGFloat kRBFloatingBarCornerRadius = 20.f;
static const CGFloat kRBFloatingMorePanelGapAboveToolbar = 4.f;

// Fixes rdar://26295020
// See issue #1247 and Peter Steinberger's comment:
// https://github.com/jessesquires/JSQMessagesViewController/issues/1247#issuecomment-219386199
// Gist with workaround: https://gist.github.com/steipete/b00fc02aa9f1c66c11d0f996b1ba1265
// Forgive me
static IMP JSQReplaceMethodWithBlock(Class c, SEL origSEL, id block) {
    NSCParameterAssert(block);

    // get original method
    Method origMethod = class_getInstanceMethod(c, origSEL);
    NSCParameterAssert(origMethod);

    // convert block to IMP trampoline and replace method implementation
    IMP newIMP = imp_implementationWithBlock(block);

    // Try adding the method if not yet in the current class
    if (!class_addMethod(c, origSEL, newIMP, method_getTypeEncoding(origMethod))) {
        return method_setImplementation(origMethod, newIMP);
    } else {
        return method_getImplementation(origMethod);
    }
}

static void JSQInstallWorkaroundForSheetPresentationIssue26295020(void) {
    __block void (^removeWorkaround)(void) = ^{};
    const void (^installWorkaround)(void) = ^{
        const SEL presentSEL = @selector(presentViewController:animated:completion:);
        __block IMP origIMP = JSQReplaceMethodWithBlock(UIViewController.class, presentSEL, ^(UIViewController *self, id vC, BOOL animated, id completion) {
            UIViewController *targetVC = self;
            while (targetVC.presentedViewController) {
                targetVC = targetVC.presentedViewController;
            }
            ((void (*)(id, SEL, id, BOOL, id))origIMP)(targetVC, presentSEL, vC, animated, completion);
        });
        removeWorkaround = ^{
            Method origMethod = class_getInstanceMethod(UIViewController.class, presentSEL);
            NSCParameterAssert(origMethod);
            class_replaceMethod(UIViewController.class,
                                presentSEL,
                                origIMP,
                                method_getTypeEncoding(origMethod));
        };
    };

    const SEL presentSheetSEL = NSSelectorFromString(@"presentSheetFromRect:");
    const void (^swizzleOnClass)(Class k) = ^(Class klass) {
        const __block IMP origIMP = JSQReplaceMethodWithBlock(klass, presentSheetSEL, ^(id self, CGRect rect) {
            // Before calling the original implementation, we swizzle the presentation logic on UIViewController
            installWorkaround();
            // UIKit later presents the sheet on [view.window rootViewController];
            // See https://github.com/WebKit/webkit/blob/1aceb9ed7a42d0a5ed11558c72bcd57068b642e7/Source/WebKit2/UIProcess/ios/WKActionSheet.mm#L102
            // Our workaround forwards this to the topmost presentedViewController instead.
            ((void (*)(id, SEL, CGRect))origIMP)(self, presentSheetSEL, rect);
            // Cleaning up again - this workaround would swallow bugs if we let it be there.
            removeWorkaround();
        });
    };

    // _UIRotatingAlertController
    Class alertClass = NSClassFromString([NSString stringWithFormat:@"%@%@%@", @"_U", @"IRotat", @"ingAlertController"]);
    if (alertClass) {
        swizzleOnClass(alertClass);
    }

    // WKActionSheet
    Class actionSheetClass = NSClassFromString([NSString stringWithFormat:@"%@%@%@", @"W", @"KActio", @"nSheet"]);
    if (actionSheetClass) {
        swizzleOnClass(actionSheetClass);
    }
}

static void * kJSQMessagesKeyValueObservingContext = &kJSQMessagesKeyValueObservingContext;


@interface JSQMessagesViewController () <UIGestureRecognizerDelegate>

@property (weak, nonatomic) IBOutlet JSQMessagesCollectionView *collectionView;
@property (weak, nonatomic) IBOutlet JSQMessagesInputToolbar *inputToolbar;

//@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toolbarHeightConstraint;
// toolbarBottomLayoutGuide 已移至 .h 供子类使用

//@property (weak, nonatomic) UIView *snapshotView;

@property (assign, nonatomic) BOOL jsq_isObserving;

// 此变量是原库中用来存放长按事件菜单的cell索引的，但它原如设计针对的是文本消息中，且受限于UIConlectionView中长
// 按回调不起效的限制，本变量的值一直不能被正确设置，自v4.3起，此变量干脆就取消掉！
//@property (strong, nonatomic) NSIndexPath *selectedIndexPathForMenu;

// navigationController自带的侧滑手势
@property (weak, nonatomic) UIGestureRecognizer *currentInteractivePopGestureRecognizer;

@property (assign, nonatomic) BOOL textViewWasFirstResponderDuringInteractivePop;

// 底部“更多”功能面板区
@property (strong, nonatomic) UIView *bottomBoxContainerView;
// 系统通知的圆角背景图
@property (strong, nonatomic) UIImage *systemInfoBubbleBgImage;

// 底部未读新消息提示ui上的未读数量计数器
@property (assign, nonatomic) int unreadCount;// TODO: 将重构为messageUnreadBallonCount

// 悬浮更多菜单 overlay（方案 C）
@property (nonatomic, strong) UIView *rb_moreMenuOverlayContainerView;
@property (nonatomic, strong) UIView *rb_moreMenuPanelView;

/// 是否已做过 collectionView 底部贴齐 view 底部的约束替换（避免重复执行）
@property (nonatomic, assign) BOOL rb_didFixCollectionViewBottomToView;

/// 悬浮条背景 wrapper（子类用 TGInputBar 时可隐藏，避免底部露出灰条）
@property (nonatomic, weak) UIView *rb_floatingBarWrapperView;
/// 输入栏下方到屏幕底的填充 view（子类可设 backgroundColor 与聊天背景一致，避免深色条）
@property (nonatomic, weak) UIView *rb_toolbarBottomFillerView;

@end


@implementation JSQMessagesViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([JSQMessagesViewController class])
                          bundle:[NSBundle bundleForClass:[JSQMessagesViewController class]]];
}

+ (instancetype)messagesViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([JSQMessagesViewController class])
                                          bundle:[NSBundle bundleForClass:[JSQMessagesViewController class]]];
}

+ (void)initialize {
    [super initialize];
    if (self == [JSQMessagesViewController self]) {
        JSQInstallWorkaroundForSheetPresentationIssue26295020();
    }
}


#pragma mark - Initialization

- (void)jsq_configureMessagesViewController
{
    // 与聊天列表背景一致；输入栏下缘至屏底由 rb_toolbarBottomFillerView 铺成与工具栏同色，避免 Home 条区域露底
    self.view.backgroundColor = UI_DEFAULT_CHATTING_BG;
    
    // add by jackjiang 20170408
    self.collectionView.backgroundColor = UI_DEFAULT_CHATTING_BG;
    
    self.jsq_isObserving = NO;
    
    self.toolbarHeightConstraint.constant = [self.inputToolbar getPreferredDefaultHeight];
    
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    
    self.inputToolbar.delegate = self;
    self.inputToolbar.contentView.textView.placeHolder = @""; // 不显示默认占位文字
    self.inputToolbar.contentView.textView.accessibilityLabel = [NSBundle jsq_localizedStringForKey:@"new_message"];
    self.inputToolbar.contentView.textView.delegate = self;
    // 底部输入区域背景（微信风格 #F7F7F7）
    self.inputToolbar.contentView.backgroundColor = UI_DEFAULT_CHAT_INPUT_BAR_BG;
    
    self.automaticallyScrollsToMostRecentMessage = YES;
    self.automaticallyScrollsToMostRecentMessage_ignoreOnce = NO;
    
    self.outgoingCellIdentifier = [JSQMessagesCollectionViewCellOutgoing cellReuseIdentifier];
    self.outgoingMediaCellIdentifier = [JSQMessagesCollectionViewCellOutgoing mediaCellReuseIdentifier];
    
    self.incomingCellIdentifier = [JSQMessagesCollectionViewCellIncoming cellReuseIdentifier];
    self.incomingMediaCellIdentifier = [JSQMessagesCollectionViewCellIncoming mediaCellReuseIdentifier];
    
    // NOTE: let this behavior be opt-in for now
    // [JSQMessagesCollectionViewCell registerMenuAction:@selector(delete:)];
    
    self.showTypingIndicator = NO;
    
    self.showLoadEarlierMessagesHeader = NO;
    
    self.topContentAdditionalInset = 0.0f;
    
    [self jsq_updateCollectionViewInsets];
    
    // Don't set keyboardController if client creates custom content view via -loadToolbarContentView
    if (self.inputToolbar.contentView.textView != nil) {
        self.keyboardController = [[JSQMessagesKeyboardController alloc] initWithTextView:self.inputToolbar.contentView.textView
                                                                              contextView:self.view
                                                                     panGestureRecognizer:self.collectionView.panGestureRecognizer
                                                                                 delegate:self];
    }
    
    // 输入框下方的更多功能区UI实现
    [self configureBottomBoxContainerView];
    
    // 输入栏下方到屏幕底部的填充条：与输入栏同色（Home Indicator 区域），避免底部露出聊天背景形成「白条/花纹带」
    UIView *toolbarBottomFiller = [[UIView alloc] init];
    toolbarBottomFiller.backgroundColor = UI_DEFAULT_CHAT_INPUT_BAR_BG;
    toolbarBottomFiller.userInteractionEnabled = NO;
    self.rb_toolbarBottomFillerView = toolbarBottomFiller;
    [self.view insertSubview:toolbarBottomFiller aboveSubview:self.collectionView];
    [toolbarBottomFiller mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.inputToolbar.mas_bottom);
        make.leading.trailing.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_bottom);
    }];
    
    // collectionView 底部贴齐 view 底部改在 viewDidLayoutSubviews 首次布局后执行，确保约束能正确找到并替换
    
    // 系统消息的圆角背景图延后加载，减轻进入聊天页首帧主线程压力（不在此处 reloadData，避免与气泡图/reloadData 顺序冲突）
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(wself) self = wself;
        if (!self) return;
        self.systemInfoBubbleBgImage = [UIImage imageNamed:@"chat_info_bg_normal3"];
    });
    
    // 给聊天列表底部可能出现的新的未数消息数气泡组件添加点击手势识别器
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fireOnClickUnreadBallon:)];
    [self.unreadMessageBallonContainer addGestureRecognizer:tapGesture];
    
    // 点击输入框上方区域 → 关闭底部面板（更多菜单 / 键盘 / 表情）
    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(jsq_handleDismissTap:)];
    dismissTap.cancelsTouchesInView = NO; // 不阻断其他控件的点击事件（如消息气泡点击）
    dismissTap.delegate = self;
    [self.view addGestureRecognizer:dismissTap];
}

// 自动滚动到最新的消息（也就是将列表滚动到最后）
- (void)autoScrollsToMostRecentMessageForInit {
    if (self.automaticallyScrollsToMostRecentMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.automaticallyScrollsToMostRecentMessage_ignoreOnce)
                self.automaticallyScrollsToMostRecentMessage_ignoreOnce = NO;
            else {
                [self scrollToBottomAnimated:NO];
            }
            
            [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
        });
    }
}

- (void)dealloc
{
    [self jsq_registerForNotifications:NO];
    [self jsq_removeObservers];
    
    _collectionView.dataSource = nil;
    _collectionView.delegate = nil;
    
    _inputToolbar.contentView.textView.delegate = nil;
    _inputToolbar.delegate = nil;
    
    [_keyboardController endListeningForKeyboard];
    _keyboardController = nil;
}


#pragma mark - Setters

- (void)setShowTypingIndicator:(BOOL)showTypingIndicator
{
    if (_showTypingIndicator == showTypingIndicator) {
        return;
    }
    
    _showTypingIndicator = showTypingIndicator;
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)setShowLoadEarlierMessagesHeader:(BOOL)showLoadEarlierMessagesHeader
{
    if (_showLoadEarlierMessagesHeader == showLoadEarlierMessagesHeader) {
        return;
    }
    
    _showLoadEarlierMessagesHeader = showLoadEarlierMessagesHeader;
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self.collectionView reloadData];
}

- (void)setTopContentAdditionalInset:(CGFloat)topContentAdditionalInset
{
    _topContentAdditionalInset = topContentAdditionalInset;
    [self jsq_updateCollectionViewInsets];
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[[self class] nib] instantiateWithOwner:self options:nil];
    
    [self jsq_configureMessagesViewController];
    [self jsq_registerForNotifications:YES];
    
    [self rb_configureFloatingInputBarIfNeeded];
}

- (void)rb_configureFloatingInputBarIfNeeded
{
    if (!self.rb_useFloatingMorePanel || !self.inputToolbar || !self.toolbarBottomLayoutGuide) return;
    
    for (NSLayoutConstraint *c in self.view.constraints) {
        if (c.firstItem == self.inputToolbar && c.firstAttribute == NSLayoutAttributeLeading) {
            c.constant = kRBFloatingBarHorizontalInset;
        } else if (c.secondItem == self.inputToolbar && c.secondAttribute == NSLayoutAttributeTrailing) {
            c.constant = kRBFloatingBarHorizontalInset;
        }
    }
    // 贴齐屏幕物理底部：constant 为负 safeArea 高度，使 toolbar.bottom 对齐 view.bottom（带 Home 条机型不再留空）
    self.toolbarBottomLayoutGuide.constant = rb_floatingBarRestConstant();
    
    UIView *wrapper = [[UIView alloc] init];
    wrapper.backgroundColor = UI_DEFAULT_CHAT_INPUT_BAR_BG;
    wrapper.layer.cornerRadius = kRBFloatingBarCornerRadius;
    wrapper.layer.shadowColor = [UIColor blackColor].CGColor;
    wrapper.layer.shadowOffset = CGSizeMake(0, -1);
    wrapper.layer.shadowRadius = 4.f;
    wrapper.layer.shadowOpacity = 0.08f;
    wrapper.translatesAutoresizingMaskIntoConstraints = NO;
    self.rb_floatingBarWrapperView = wrapper;
    [self.view insertSubview:wrapper belowSubview:self.inputToolbar];
    [wrapper mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(self.inputToolbar.mas_leading);
        make.trailing.equalTo(self.inputToolbar.mas_trailing);
        make.top.equalTo(self.inputToolbar.mas_top);
        make.bottom.equalTo(self.inputToolbar.mas_bottom);
    }];
    
    self.inputToolbar.layer.cornerRadius = kRBFloatingBarCornerRadius;
    self.inputToolbar.clipsToBounds = YES;
}

- (BOOL)jsq_shouldSkipHeavyWillAppearLayout
{
    return NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    NSParameterAssert(self.senderId != nil);
    NSParameterAssert(self.senderDisplayName != nil);
    
    [super viewWillAppear:animated];
    self.toolbarHeightConstraint.constant = [self.inputToolbar getPreferredDefaultHeight];

    BOOL skipHeavy = [self jsq_shouldSkipHeavyWillAppearLayout];
    if (!skipHeavy) {
        [self.view layoutIfNeeded];
        [self.collectionView.collectionViewLayout invalidateLayout];

        // 自动滚动到最新的消息（也就是将列表滚动到最后）
        [self autoScrollsToMostRecentMessageForInit];
    }

    //  [self jsq_updateKeyboardTriggerPoint];

    // 见 viewWillDisappear: 方法中“_bottomBoxContainerView.hidden = YES” 那一行的代码说明
    _bottomBoxContainerView.hidden = NO;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self rb_fixCollectionViewBottomToViewIfNeeded];
    // 悬浮条：首次布局后按实际 safe area 再设一次底部 constant（view 入窗后 safe area 才正确）
    if (self.rb_useFloatingMorePanel && self.toolbarBottomLayoutGuide && !self.inputToolbar.contentView.textView.isFirstResponder) {
        CGFloat want = rb_floatingBarRestConstant();
        if (self.toolbarBottomLayoutGuide.constant != want) {
            self.toolbarBottomLayoutGuide.constant = want;
        }
    }
}

/// 将 collectionView 底部从 Safe Area 底部改为贴齐 view 底部，使聊天背景铺满到屏幕最底部（仅执行一次）
- (void)rb_fixCollectionViewBottomToViewIfNeeded
{
    if (self.rb_didFixCollectionViewBottomToView || !self.collectionView) return;
    if (@available(iOS 11.0, *)) {
        NSLayoutConstraint *toRemove = nil;
        for (NSLayoutConstraint *c in self.view.constraints) {
            if (c.firstAttribute != NSLayoutAttributeBottom || c.secondAttribute != NSLayoutAttributeBottom) continue;
            id first = c.firstItem, second = c.secondItem;
            BOOL hasCollection = (first == self.collectionView || second == self.collectionView);
            BOOL hasSafeGuide = ([first isKindOfClass:[UILayoutGuide class]] || [second isKindOfClass:[UILayoutGuide class]]);
            if (hasCollection && hasSafeGuide) {
                toRemove = c;
                break;
            }
        }
        if (toRemove) {
            [self.view removeConstraint:toRemove];
        }
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.collectionView
                                                             attribute:NSLayoutAttributeBottom
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeBottom
                                                            multiplier:1 constant:0]];
        self.rb_didFixCollectionViewBottomToView = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self jsq_addObservers];
    [self jsq_addActionToInteractivePopGestureRecognizer:YES];
    [self.keyboardController beginListeningForKeyboard];
    
    //    if ([UIDevice jsq_isCurrentDeviceBeforeiOS8]) {
    //        [self.snapshotView removeFromSuperview];
    //    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //  self.collectionView.collectionViewLayout.springinessEnabled = NO;
    
    // Bug FIX:  20180306 by Jack Jiang
    // 当界面back时，界面转场过程中_bottomBoxContainerView一直处于可见状态（像一块牛皮癣一样），暂时原因不明，
    // 难道是.xib加载的界面中，通过代码添加的View会出现这种情况？但强制在本方法中设置hidden属性可解决此问题
    _bottomBoxContainerView.hidden = YES;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self jsq_addActionToInteractivePopGestureRecognizer:NO];
    [self jsq_removeObservers];
    [self.keyboardController endListeningForKeyboard];
    
    // 在聊天界面将要不可见之前，如果存在正在播放中的语音消息，则通知其停止播放（不然在后台还会播放的罗）
    [JSQAudioMediaItem stopPlayRequestNotificatin_POST:[NSString stringWithFormat:@"%lu", [self hash]]];
    
    // 尝试关闭“(+)更多”功能面板，否则从“好友信息”等界面中回来时，底部面板仍然显示且内容中空的，就是bug了
    [self hideBottomBoxAnim:NO];
}


#pragma mark - 输入框下方的更多功能区UI实现

// 配置底部内容面板的父View
- (void)configureBottomBoxContainerView
{
    // CGRectGetMaxY表示返回组件底部的Y坐值
    UIView *cv = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.inputToolbar.frame), CGRectGetWidth(self.view.frame), k_RBBottomBoxViewHeight + [BasicTool getSafeAreaInsets_bottom])];
    
    // ## ----------------------------------------------------------------------
    // ## 【适配iPhoneX及以上刘海屏手机上聊天界面的底部（不适配则会被safe area挡住一点）】 - 20190816
    // ## 适配实现方法：
    // ## >第一步：JSQMessageViewController.xib中，将Input Toolbar的"Bottom space to"由"SuperView"改为"Safe Area", 确保输入工具栏的底随safe area自动上移；
    // ## >第二步：为 BottomBoxContainerView 设置clipsToBounds=yes，目的是当 BottomBoxContainerView 高度为0时，防止子UI组件还显示出来；
    // ## >第三步：为 BottomBoxContainerView 的bottom，设置 "Bottom space to" 为"Safe Area"，确保 BottomBoxContainerView的底部不会超出safe area（不然就“漏”出来了）。
    // ## ----------------------------------------------------------------------
    
    // 【适配说明详见上方文字】此为第二步：为 BottomBoxContainerView 设置clipsToBounds=yes
    // ，目的是当 BottomBoxContainerView 高度为0时，防止子UI组件还显示出来；
    [cv setClipsToBounds:YES]; // 为iphonx适配而加的代码 - 20190816
    
    
    //## 以下注释掉的代码，是v6.0前实现底部内容面板显示代码，但跟inputToolbar的bottom constrains有冲突，最佳实践就是
    //## 将_bottomBoxContainerView 放在xib里，让inputToolbar的bottom constrains直接相对于_bottomBoxContainerView的top
    //## constrains，这样就不会冲突，但这样做就显的复杂了。v6.0后，就跟表情面板一样，底部的这个内容面板利用textView的inputView
    //## 来实现它的显示控制，这就优雅多了、代码也简单多了，也少了很多跟留海屏、safeArea的显示兼容问题。
    
    //    [self.view addSubview:cv];
    //    [self.view bringSubviewToFront:cv];
    //
    //    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    //    __weak typeof(self) safeSelf = self;
    //
    //    [cv mas_makeConstraints:^(MASConstraintMaker *make) {
    //        make.top.equalTo(safeSelf.inputToolbar.mas_bottom);// FIXME: 这句会导致constrains冲突
    //
    //        make.width.equalTo(safeSelf.view.mas_width);
    ////      make.bottom.equalTo(safeSelf.view.mas_bottom);// iphonx适配前的代码 - 20190816
    //
    //        // 【适配说明详见上方文字】此为第三步：为 BottomBoxContainerView 的bottom，设置 "Bottom space to"
    //        // 为"Safe Area"，确保 BottomBoxContainerView的底部不会超出safe area（不然就“漏”出来了）
    //        if (@available(iOS 11.0, *)){
    //            make.bottom.equalTo(safeSelf.view.mas_safeAreaLayoutGuideBottom);
    //        } else {
    //            make.bottom.equalTo(safeSelf.view.mas_bottom);
    //        }
    //    }];
    
    _bottomBoxContainerView = cv;
    // 原版 JSQ/早期 Rainbow：与输入工具栏同色灰底条，无大圆角（不与 TG 悬浮白卡片混用）
    _bottomBoxContainerView.backgroundColor = UI_DEFAULT_CHAT_INPUT_BAR_BG;
    _bottomBoxContainerView.layer.cornerRadius = 0.f;
    _bottomBoxContainerView.clipsToBounds = YES;
    
    [self createBottomBoxMore];
}

// 配置底部“更多”内容面板的View
- (void)createBottomBoxMore
{
    if(_bottomBoxMoreView == nil)
    {
        kmMoreMenuView *vin = [[kmMoreMenuView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(_bottomBoxContainerView.frame), k_RBBottomBoxViewHeight)];
        vin.backgroundColor = [UIColor clearColor];
        
        [_bottomBoxContainerView addSubview:vin];
        
        [vin mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(_bottomBoxContainerView.mas_top);
            make.width.equalTo(_bottomBoxContainerView.mas_width);
            make.bottom.equalTo(_bottomBoxContainerView.mas_bottom);
        }];
        _bottomBoxMoreView = vin;
    }
}

//## 以下被注释的代码用于v6.0前的底部面板显示逻辑，目前已废弃，日后删除之
//- (void)toggleBottomBoxWith:(RBBottomBoxContentViewState)state
//{
//    // 先取消文本的输入状态（如果正在输入文字的话）：
//    // 当前“更多”功能显示模式和软键盘（文本输入模式）是互斥的，打开了“更多”功能显示则强制取消文本输入模式【2/2】
//    [self.inputToolbar.contentView.textView resignFirstResponder];
//
//    // 如果本次点击的state跟上次的相同（等于是再次点击同一个按钮），就给示取消此state(点一次打开、再点一次关闭，很全理的逻辑)
//    if(self.bottomBoxContentViewState == state)
//    {
//        self.bottomBoxContentViewState = RBBottomBoxContentViewStateNone;
//    }
//    else
//    {
//        self.bottomBoxContentViewState = state;
//
//        switch(state)
//        {
//            case RBBottomBoxContentViewStateNone:
//                break;
//            case RBBottomBoxContentViewStateMore:
//            {
//                CGRect frame = self.bottomBoxMoreView.frame;
//                frame.origin.y = CGRectGetHeight(self.bottomBoxContainerView.frame);
//                self.bottomBoxMoreView.frame = frame;
//                [self.bottomBoxContainerView bringSubviewToFront:self.bottomBoxMoreView];
//                break;
//            }
////            case RBBottomBoxContentViewStateEmoji:
////                // TODO: 表情的内容面板UI显示逻辑后绪版本中再实现
////                break;
//        }
//    }
//
//    // 根据sate决定bottom box 上的view的显示情况
//    [self refreshBottomBoxVisible];
//
//    // F表情 还原leftbtn2及inputview -- by Freeman
//    self.inputToolbar.contentView.textView.inputView = nil;
//    [self resetLeftButton2Style];
//}

//## 以下被注释的代码用于v6.0前的底部面板显示逻辑，目前已废弃，日后删除之
//- (void)refreshBottomBoxVisible
//{
//    switch(self.bottomBoxContentViewState)
//    {
//        // 取消内容面板的显示
//        case RBBottomBoxContentViewStateNone:
//        {
//            [UIView animateWithDuration:0.4 animations:^{
//                [self jsq_setToolbarBottomLayoutGuideConstant:0];
//            }];
////            [self scrollToBottomAnimated:YES];
//            break;
//        }
//        // “(+)更多”内容面板的显示
//        case RBBottomBoxContentViewStateMore:
//        {
//            [UIView animateWithDuration:0.4 animations:^{
//                [self jsq_setToolbarBottomLayoutGuideConstant:k_RBBottomBoxViewHeight];
//            }];
//            [self scrollToBottomAnimated:YES];
//            break;
//        }
////        case RBBottomBoxContentViewStateEmoji:
////            break;
//    }
//}

#pragma mark - 悬浮更多菜单 Overlay（方案 C）

// 创建更多面板 overlay 的 container 与 panel。与 inputToolbar 的约束已移至 rb_showMoreMenuOverlay 且改为相对 self.view，
// 避免控制台崩溃：NSInternalInconsistencyException "couldn't find a common superview for <UIView> and <JSQMessagesInputToolbar>"。
- (void)rb_ensureMoreMenuOverlayCreated
{
    if (self.rb_moreMenuOverlayContainerView != nil) return;
    if (!_bottomBoxContainerView || !self.inputToolbar) return;
    
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3f];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rb_moreMenuOverlayDimmedTapped:)];
    [container addGestureRecognizer:tap];
    
    UIView *panel = [[UIView alloc] init];
    // 与表情面板 FaceBoardView 一致：白底 80% 不透明 + 圆角 16
    panel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
    panel.layer.cornerRadius = 16.f;
    panel.clipsToBounds = YES;
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:panel];
    
    _bottomBoxContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:_bottomBoxContainerView];
    [_bottomBoxContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(panel);
    }];
    // 与 inputToolbar 的约束延后到 rb_showMoreMenuOverlay 中 container 已 add 到 self.view 后再添加，避免 common superview 崩溃
    self.rb_moreMenuOverlayContainerView = container;
    self.rb_moreMenuPanelView = panel;
}

- (void)rb_moreMenuOverlayDimmedTapped:(UITapGestureRecognizer *)gr
{
    [self hideBottomBoxAnim:YES];
}

- (void)rb_showMoreMenuOverlay
{
    [self rb_ensureMoreMenuOverlayCreated];
    UIView *container = self.rb_moreMenuOverlayContainerView;
    UIView *panel = self.rb_moreMenuPanelView;
    if (!container || container.superview != nil) return;
    
    if (_bottomBoxContainerView.superview != self.rb_moreMenuPanelView) {
        _bottomBoxContainerView.translatesAutoresizingMaskIntoConstraints = NO;
        _bottomBoxContainerView.backgroundColor = [UIColor clearColor]; // 透出 panel 的 80% 白，与表情面板一致
        [self.rb_moreMenuPanelView addSubview:_bottomBoxContainerView];
        [_bottomBoxContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.rb_moreMenuPanelView);
        }];
    }
    
    [self.view addSubview:container];
    [self.view bringSubviewToFront:container];
    [container mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    // 控制台崩溃：NSInternalInconsistencyException "couldn't find a common superview for panel and JSQMessagesInputToolbar"。
    // 使用 TGInputBar 时 inputToolbar 可能与 panel 不在同一 view 层级，故 panel 约束只相对 self.view，避免 common superview 报错。
    if (panel) {
        CGFloat toolbarH = (self.inputToolbar.bounds.size.height > 0) ? self.inputToolbar.bounds.size.height : 44.f;
        CGFloat restC = rb_floatingBarRestConstant();
        [panel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.leading.equalTo(self.view.mas_leading).offset(kRBFloatingBarHorizontalInset);
            make.trailing.equalTo(self.view.mas_trailing).offset(-kRBFloatingBarHorizontalInset);
            make.bottom.equalTo(self.view.mas_bottom).offset(restC - toolbarH - kRBFloatingMorePanelGapAboveToolbar);
            make.height.mas_equalTo(k_RBBottomBoxViewHeight + [BasicTool getSafeAreaInsets_bottom]);
        }];
    }
    
    container.alpha = 0.f;
    self.rb_moreMenuPanelView.transform = CGAffineTransformMakeTranslation(0, 30);
    [UIView animateWithDuration:0.25 animations:^{
        container.alpha = 1.f;
        self.rb_moreMenuPanelView.transform = CGAffineTransformIdentity;
    }];
}

- (void)rb_hideMoreMenuOverlayWithCompletion:(void (^)(void))completion
{
    UIView *container = self.rb_moreMenuOverlayContainerView;
    if (!container || container.superview == nil) {
        if (completion) completion();
        return;
    }
    [_bottomBoxContainerView removeFromSuperview];
    [UIView animateWithDuration:0.25 animations:^{
        container.alpha = 0.f;
        self.rb_moreMenuPanelView.transform = CGAffineTransformMakeTranslation(0, 30);
    } completion:^(BOOL finished) {
        [container removeFromSuperview];
        if (completion) completion();
    }];
}

// 取消底部内容面板的显示（无动画，直接关闭）
- (void)hideBottomBoxAnim:(BOOL)animation
{
    [self hideBottomBoxAnim:animation completion:nil];
}

- (void)hideBottomBoxAnim:(BOOL)animation completion:(void (^)(void))completion
{
    // 不再做动画，直接关闭；悬浮更多面板若正在显示，rb_hideMoreMenuOverlayWithCompletion 内有 0.25s 收起动画
    if (self.rb_useFloatingMorePanel && self.rb_moreMenuOverlayContainerView.superview != nil) {
        [self rb_hideMoreMenuOverlayWithCompletion:^{
            [self jsq_setToolbarBottomLayoutGuideConstant:self.rb_useFloatingMorePanel ? rb_floatingBarRestConstant() : 0.f];
            if (completion) completion();
        }];
        return;
    }
    CGFloat restConstant = self.rb_useFloatingMorePanel ? rb_floatingBarRestConstant() : 0.f;
    [self jsq_setToolbarBottomLayoutGuideConstant:restConstant];
    self.inputToolbar.contentView.textView.inputView = nil;
    if (completion) completion();
}

// 取消底部内容面板的显示
- (void)hideBottomBox {
    [self hideBottomBoxAnim:NO completion:nil];
}

// 点击输入框上方区域时：关闭底部面板（更多菜单 / 键盘 / 表情面板）
- (void)jsq_handleDismissTap:(UITapGestureRecognizer *)tap
{
    // 判断点击位置是否在 inputToolbar 上方（即消息列表区域）
    CGPoint point = [tap locationInView:self.view];
    if (point.y >= CGRectGetMinY(self.inputToolbar.frame)) {
        return; // 点击在输入框及其以下区域，不处理（避免干扰输入框按钮操作）
    }
    
    // 如果键盘或底部面板正在显示，则关闭
    if (self.inputToolbar.contentView.textView.isFirstResponder) {
        [self.inputToolbar.contentView.textView resignFirstResponder];
    }
    // 关闭底部更多/表情面板
    [self hideBottomBoxAnim:YES];
    [self resetLeftButton2Style];
}

// UIGestureRecognizerDelegate — 允许 dismissTap 与 collectionView 内部手势同时识别
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

// 重置第二个按钮为表情样式。该按钮之前用于发送图片，居于inputToolBar的左部第二位置，所以命名为
// LeftButton2，现已改为用作表情面板的打开及切换，移动到了inputToolBar的右部。优先使用 App 提供的 chat_face_icon（SVG）
// 使用 TGInputBar 时原 inputToolbar 的 contentView/leftBarButton2Item 可能未参与布局，需判空避免闪退
- (void)resetLeftButton2Style
{
    UIButton *btn = self.inputToolbar.contentView.leftBarButton2Item;
    if (!btn) return;
    UIImage *faceIcon = [UIImage imageNamed:@"chat_face_icon"];
    if (faceIcon) {
        [btn setBackgroundImage:faceIcon forState:UIControlStateNormal];
        [btn setBackgroundImage:faceIcon forState:UIControlStateHighlighted];
    } else {
        [btn setBackgroundImage:[UIImage imageNamed:@"chat_face_icon_normal"] forState:UIControlStateNormal];
        [btn setBackgroundImage:[UIImage imageNamed:@"chat_face_icon_pressed"] forState:UIControlStateHighlighted];
    }
}

// 设置第二个按钮为键盘样式（使用 App 提供的 chat_keyboard_icon，支持 SVG 矢量）
- (void)setLeftButton2ToKeyboardStyle
{
    UIButton *btn = self.inputToolbar.contentView.leftBarButton2Item;
    if (!btn) return;
    UIImage *icon = [UIImage imageNamed:@"chat_keyboard_icon"];
    if (icon) {
        [btn setBackgroundImage:icon forState:UIControlStateNormal];
        [btn setBackgroundImage:icon forState:UIControlStateHighlighted];
    } else {
        [btn setBackgroundImage:[UIImage imageNamed:@"chat_keyboard_icon_normal"] forState:UIControlStateNormal];
        [btn setBackgroundImage:[UIImage imageNamed:@"chat_keyboard_icon_pressed"] forState:UIControlStateHighlighted];
    }
}


#pragma mark - Messages view controller（消息列表UICollectionView的UI代理方法）

- (void)didPressSendButtonInKeybord:(NSString *)text
{
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

// 点击下方的“+”按钮的事件处理
- (void)didPressRightButton:(UIButton *)button
            withMessageText:(NSString *)text
                   senderId:(NSString *)senderId
          senderDisplayName:(NSString *)senderDisplayName
                       date:(NSDate *)date
{
    if (self.rb_useFloatingMorePanel) {
        if (self.inputToolbar.contentView.textView) {
            [self.inputToolbar.contentView.textView resignFirstResponder];
        }
        if (self.rb_moreMenuOverlayContainerView.superview != nil) {
            [self hideBottomBoxAnim:YES];
        } else {
            [self rb_showMoreMenuOverlay];
        }
        [self resetLeftButton2Style];
        return;
    }
    
    // ★ 性能优化：避免 becomeFirstResponder + reloadInputViews 双重动画
    UITextView *textView = self.inputToolbar.contentView.textView;
    BOOL isAlreadyFirstResponder = [textView isFirstResponder];
    
    if (textView.inputView != _bottomBoxContainerView) {
        textView.inputView = _bottomBoxContainerView;
        self.jsq_didJustOpenCustomInputView = YES;
        [textView reloadInputViews];
        if (isAlreadyFirstResponder) {
        } else {
            [textView becomeFirstResponder];
        }
    } else {
        textView.inputView = nil;
        [textView resignFirstResponder];
    }
    
    [self resetLeftButton2Style];
}

- (void)didPressLeftButton:(UIButton *)sender
{
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

- (void)didPressLeftButton2:(UIButton *)sender
{
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

- (void)finishSendingMessage
{
    [self finishSendingMessageAnimated:YES];
}

- (void)finishSendingMessageAnimated:(BOOL)animated {
    
    UITextView *textView = self.inputToolbar.contentView.textView;
    textView.text = nil;
    // 重新设置一下输入框的默认字体大小，不然因为表情富文本的影响，发送表情后输入
    // 框的字体会变的很小，暂时原因不明，只能强行重置字体大小来纠正
    textView.font = MESSAGE_COMPOSER_TEXT_VIEW_DEFAULT_FONT;
    
    [textView.undoManager removeAllActions];
    
    //  [self.inputToolbar toggleSendButtonEnabled];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:textView];
    
    //    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    //    [self.collectionView reloadData];
    [self refreshCollectionView];
    
    if (self.automaticallyScrollsToMostRecentMessage) {
        // ★ Bug FIX: reloadData 后强制完成布局，确保 contentSize 已更新，
        //   再更新 collectionView 的 insets（输入框高度可能因清空文字而变化），
        //   然后再滚动到底部，避免最后一条消息底部被输入框遮盖
        [self.collectionView layoutIfNeeded];
        [self jsq_updateCollectionViewInsets];
        [self scrollToBottomAnimated:animated];
    }
}

- (void)finishReceivingMessage
{
    [self finishReceivingMessageAnimated:YES];
}

- (void)finishReceivingMessageAnimated:(BOOL)animated  {
    [self finishReceivingMessageAnimated:animated forceDontScrollToBottom:NO];
}

- (void)finishReceivingMessageAnimated:(BOOL)animated forceDontScrollToBottom:(BOOL)forceDontScrollToBottom   {

    self.showTypingIndicator = NO;

//    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
//    [self.collectionView reloadData];
    [self refreshCollectionView];

    if (!forceDontScrollToBottom && self.automaticallyScrollsToMostRecentMessage && ![self jsq_isMenuVisible]) {
        // ★ Bug FIX: reloadData 后强制完成布局 + 更新 insets，
        //   防止最后一条消息底部被输入框遮盖
        [self.collectionView layoutIfNeeded];
        [self jsq_updateCollectionViewInsets];
        [self scrollToBottomAnimated:animated];
    }
}

// 刷新表格，即时显示内容 - @since 9.0
- (void)refreshCollectionView
{
    // ★ 使用 invalidateFlowLayoutMessagesCache = YES 清除气泡大小缓存，
    //   确保异步下载完图片后能按照图片实际尺寸重新计算气泡大小
    //  （否则收到的图片因为首次计算时 image 为 nil 会用默认尺寸，之后被缓存不再更新）
    JSQMessagesCollectionViewFlowLayoutInvalidationContext *ctx = [JSQMessagesCollectionViewFlowLayoutInvalidationContext context];
    ctx.invalidateFlowLayoutMessagesCache = YES;
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:ctx];
    [self.collectionView reloadData];
}

// 自动滚动到表格的最后一行
// ★ 性能优化：使用 setContentOffset 直接计算目标偏移量，O(1) 复杂度，
//   避免旧方案 scrollToIndexPath → sizeForItemAtIndexPath 在消息量大时耗时数百毫秒的问题
- (void)scrollToBottomAnimated:(BOOL)animated
{
    if ([self.collectionView numberOfSections] == 0) {
        return;
    }
    NSInteger items = [self.collectionView numberOfItemsInSection:0];
    if (items == 0) {
        return;
    }
    
    // ★ 使用 adjustedContentInset（iOS 11+）获取完整的内边距（包含安全区域）
    //   在 iOS 26+ 上 contentInset.top 为 0，但系统通过 adjustedContentInset 自动加了导航栏安全区，
    //   如果只用 contentInset 会导致消息滚动到导航栏后面
    CGFloat topInset, bottomInset;
    if (@available(iOS 11.0, *)) {
        topInset    = self.collectionView.adjustedContentInset.top;
        bottomInset = self.collectionView.adjustedContentInset.bottom;
    } else {
        topInset    = self.collectionView.contentInset.top;
        bottomInset = self.collectionView.contentInset.bottom;
    }
    
    CGFloat contentHeight = self.collectionView.contentSize.height;
    CGFloat frameHeight   = CGRectGetHeight(self.collectionView.bounds);
    
    // 目标偏移 = 内容总高度 + 底部内边距 - 可视区域高度
    CGFloat maxOffsetY = contentHeight + bottomInset - frameHeight;
    CGFloat visibleHeight = frameHeight - topInset - bottomInset;
    BOOL contentFills = (contentHeight >= visibleHeight - 1.0f);
    
    if (contentFills && maxOffsetY > -topInset) {
        if ([self respondsToSelector:@selector(rb_setChatCollectionViewContentOffset:animated:)]) {
            [(id)self rb_setChatCollectionViewContentOffset:CGPointMake(0, maxOffsetY) animated:animated];
        } else {
            [self.collectionView setContentOffset:CGPointMake(0, maxOffsetY) animated:animated];
        }
    } else if (contentFills) {
        if ([self respondsToSelector:@selector(rb_setChatCollectionViewContentOffset:animated:)]) {
            [(id)self rb_setChatCollectionViewContentOffset:CGPointMake(0, -topInset) animated:animated];
        } else {
            [self.collectionView setContentOffset:CGPointMake(0, -topInset) animated:animated];
        }
    } else {
        // 内容不足：保持 contentOffset.y = 0，配合大 topInset 使最新消息贴底、从下往上排
        if ([self respondsToSelector:@selector(rb_setChatCollectionViewContentOffset:animated:)]) {
            [(id)self rb_setChatCollectionViewContentOffset:CGPointMake(0, 0) animated:animated];
        } else {
            [self.collectionView setContentOffset:CGPointMake(0, 0) animated:animated];
        }
    }
}

- (void)scrollToIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    if ([self.collectionView numberOfSections] <= indexPath.section) {
        return;
    }

    NSInteger numberOfItems = [self.collectionView numberOfItemsInSection:indexPath.section];
    if (numberOfItems == 0) {
        return;
    }

    CGFloat collectionViewContentHeight = [self.collectionView.collectionViewLayout collectionViewContentSize].height;
    BOOL isContentTooSmall = (collectionViewContentHeight < CGRectGetHeight(self.collectionView.bounds));

    if (isContentTooSmall) {
        //  workaround for the first few messages not scrolling
        //  when the collection view content size is too small, `scrollToItemAtIndexPath:` doesn't work properly
        //  this seems to be a UIKit bug, see #256 on GitHub
        [self.collectionView scrollRectToVisible:CGRectMake(0.0, collectionViewContentHeight - 1.0f, 1.0f, 1.0f)
                                        animated:animated];
        return;
    }

    NSInteger item = MAX(MIN(indexPath.item, numberOfItems - 1), 0);
    indexPath = [NSIndexPath indexPathForItem:item inSection:0];

    //  workaround for really long messages not scrolling
    //  if last message is too long, use scroll position bottom for better appearance, else use top
    //  possibly a UIKit bug, see #480 on GitHub
    CGSize cellSize = [self.collectionView.collectionViewLayout sizeForItemAtIndexPath:indexPath];
    // ★ Bug FIX: contentInset.bottom 已包含输入框高度（由 jsq_updateCollectionViewInsets 设置），
    //   不再额外减去 inputToolbar.bounds.height，避免重复扣减导致可见区域计算偏小
    CGFloat maxHeightForVisibleMessage = CGRectGetHeight(self.collectionView.bounds)
                                         - self.collectionView.contentInset.top
                                         - self.collectionView.contentInset.bottom;
    UICollectionViewScrollPosition scrollPosition = (cellSize.height > maxHeightForVisibleMessage) ? UICollectionViewScrollPositionBottom : UICollectionViewScrollPositionTop;

    [self.collectionView scrollToItemAtIndexPath:indexPath
                                atScrollPosition:scrollPosition
                                        animated:animated];
}

// 获取表格中最后一行的位置信息 - @since 7.0 Jack Jiang
- (NSIndexPath *)getLastCellIndexPath {
    return [NSIndexPath indexPathForItem:([self.collectionView numberOfItemsInSection:0] - 1) inSection:0];
}

// 表格中最后一行是否处于可见状态 - @since 7.0 Jack Jiang
- (BOOL)isLastCellVisible {
    BOOL result = NO;
    
    // 消息列表最后一行的位置
    NSIndexPath *lastCell = [self getLastCellIndexPath];
    // 当前消息列表中所有可见的items
    NSArray<NSIndexPath *> *indexPathsForVisibleItems = self.collectionView.indexPathsForVisibleItems;
    // 遍历当前所有可见的items，看看最后一行是否也在其中（如果在，就表示最后一行当前是处于可见状态）。
    // 注：之所以要这样去判断是因为UICollectionView并没有现成的判断最后一特是否可见的方法可用。
    if(indexPathsForVisibleItems != nil) {
        for(NSIndexPath *index in indexPathsForVisibleItems) {
            
            // 以下代码仅有于v7.0版时Debug，您可删除之 START
//            NSLog(@"[isLastCellVisible] #################### 当前消息列表可视item总数：%ld", [indexPathsForVisibleItems count]);
//            NSLog(@"[isLastCellVisible]【1/4】index.item=%ld, index.row=%ld, index.section=%ld", index.item, index.row, index.section);
//            NSLog(@"[isLastCellVisible]【2/4】last.item=%ld, last.row=%ld, last.section=%ld", lastCell.item, lastCell.row, lastCell.section);
//            NSLog(@"[isLastCellVisible]【3/4】结相等吗？%ld", [index compare:lastCell]);
            // --------------------------------- END
            
            if([index compare:lastCell] == NSOrderedSame) {
                result = YES;
//                NSLog(@"[isLastCellVisible]【4/4】结果已经判断相等了，本次循环结束！");
//                NSLog(@"[isLastCellVisible] #################### END");
                break;
            }
        }
    }
    
    return result;
}

//
- (BOOL)isOutgoingMessage:(JSQMessage *)messageItem
{
    NSString *messageSenderId = [messageItem senderId];
    NSParameterAssert(messageSenderId != nil);

    return [messageSenderId isEqualToString:self.senderId];
}


#pragma mark - JSQMessages collection view data source（消息列表的数据模型代理，其实是从CollectionView的数据源代码中细分出来的）

- (JSQMessage *)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didDeleteMessageAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
}

- (JSQMessagesBubbleImage *)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (UIImage *)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}


#pragma mark - Collection view data source（消息列表数据源代理方法）

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 0;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *messageItem = [collectionView.dataSource collectionView:collectionView messageDataForItemAtIndexPath:indexPath];
    NSParameterAssert(messageItem != nil);

    UICollectionViewCell *cellRet = nil;

    // 系统通知、被撤回的消息的cell ui数据设定
    if(messageItem.msgType == TM_TYPE_SYSTEAM_INFO || messageItem.msgType == TM_TYPE_REVOKE)
    {
        rbSystemInfoCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[rbSystemInfoCollectionViewCell cellReuseIdentifier] forIndexPath:indexPath];
        
        NSString *showText = @"";
        // 被撤回消息的内容显示需要特殊处理
        if(messageItem.msgType == TM_TYPE_REVOKE){
            showText = [JSQMessage getMessageContentPreviewForRevoked:[RevokedMeta fromJSON:[messageItem text]]];
        }
        else
            showText = [messageItem text];
        
        // 不需要识别链接等
        cell.textView.dataDetectorTypes = UIDataDetectorTypeNone;
        
        // 文本内容显示
        cell.textView.text = showText;
        // 时间、昵称这些内容的显示
        cell.cellTopLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForCellTopLabelAtIndexPath:indexPath];
        
        // 组件的背景色设置
        cell.cellTopLabel.backgroundColor = [UIColor clearColor];
        cell.backgroundColor = [UIColor clearColor];
        cell.textView.backgroundColor = [UIColor clearColor];

        // 圆角背景图（不走样拉伸）
        [BasicTool setStretchImage:cell.messageBubbleImageView capInsets:UIEdgeInsetsMake(12, 12, 12, 12) img:self.systemInfoBubbleBgImage];

        cellRet = cell;
    }
    // 普通聊消息的cell ui设定
    else
    {
        JSQMessagesCollectionViewCell *cell = nil;

        BOOL isOutgoingMessage = [self isOutgoingMessage:messageItem];
        BOOL isMediaMessage = [messageItem isMediaMessage];

        NSString *cellIdentifier = nil;
        if (isMediaMessage) {
            cellIdentifier = isOutgoingMessage ? self.outgoingMediaCellIdentifier : self.incomingMediaCellIdentifier;
        }
        else {
            cellIdentifier = isOutgoingMessage ? self.outgoingCellIdentifier : self.incomingCellIdentifier;
        }

        cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
        cell.delegate = collectionView;

        // 文本消息的背景气泡图显示
        if (!isMediaMessage) {
            cell.textView.text = [messageItem text];

            NSParameterAssert(cell.textView.text != nil);

            // 微信风格：我方/对方气泡内文字均为黑色 #000000
            cell.textView.textColor = isOutgoingMessage ? HexColor(0x000000) : HexColor(0x000000);

            JSQMessagesBubbleImage *bubbleImageDataSource = [collectionView.dataSource collectionView:collectionView messageBubbleImageDataForItemAtIndexPath:indexPath];
            cell.messageBubbleImageView.image = [bubbleImageDataSource messageBubbleImage];
            cell.messageBubbleImageView.highlightedImage = [bubbleImageDataSource messageBubbleHighlightedImage];
        }
        // 媒体消息的显示
        else {
            JSQMediaItem *messageMedia = [messageItem media];
            cell.mediaView = [messageMedia mediaView] ?: [messageMedia mediaPlaceholderView];
            NSParameterAssert(cell.mediaView != nil);
            // 媒体消息也按 dataSource 设置气泡图（分组时可为无尾）
            JSQMessagesBubbleImage *bubbleImageDataSource = [collectionView.dataSource collectionView:collectionView messageBubbleImageDataForItemAtIndexPath:indexPath];
            cell.messageBubbleImageView.image = [bubbleImageDataSource messageBubbleImage];
            cell.messageBubbleImageView.highlightedImage = [bubbleImageDataSource messageBubbleHighlightedImage];
        }

        // 是否需要显示头像
        BOOL needsAvatar = YES;
        if (isOutgoingMessage && CGSizeEqualToSize(collectionView.collectionViewLayout.outgoingAvatarViewSize, CGSizeZero)) {
            needsAvatar = NO;
        }
        else if (!isOutgoingMessage && CGSizeEqualToSize(collectionView.collectionViewLayout.incomingAvatarViewSize, CGSizeZero)) {
            needsAvatar = NO;
        }

        // 头像的UI显示
        if (needsAvatar)
            // 单独的方法里处理头像显示逻辑 - 20180528 by JackJiang
            [self rb_collectionView:collectionView cellForItemAtIndexPath_avatar:indexPath withImageView:cell.avatarImageView];

        // 时间、昵称这些内容的显示
        cell.cellTopLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForCellTopLabelAtIndexPath:indexPath];
        cell.messageBubbleTopLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:indexPath];
        cell.cellBottomLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForCellBottomLabelAtIndexPath:indexPath];
        NSString *nickname = [self rb_collectionView:collectionView cellForItemAtIndexPath_nickname:indexPath withCell:cell];
        cell.cellNicknameLabel2.text = nickname;
        
        // 昵称文本显示空白设置（避开头像嘛）
    //  CGFloat bubbleTopLabelInset = (avatarImageDataSource != nil) ? 60.0f : 15.0f;
        CGFloat bubbleTopLabelInset = needsAvatar ? 60.0f : 15.0f;
        if (isOutgoingMessage) {
            cell.messageBubbleTopLabel.textInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, bubbleTopLabelInset);
        }
        else {
            cell.messageBubbleTopLabel.textInsets = UIEdgeInsetsMake(0.0f, bubbleTopLabelInset, 0.0f, 0.0f);
        }

        // 只自动识别超链接和邮箱，不识别手机号码和IP地址
        cell.textView.dataDetectorTypes = UIDataDetectorTypeLink;

        cell.backgroundColor = [UIColor clearColor];
        // 关闭 shouldRasterize 以减轻上下滑动卡顿（栅格化在消息内容多变时易触发重绘，反而掉帧）
        cell.layer.shouldRasterize = NO;
        
        // 从搜索进入聊天时，该条消息一直高亮显示（灰色背景+圆角）；非高亮消息清空样式，避免复用 cell 误显高亮
        if ([messageItem isHighlightOnce]) {
            [BasicTool highlightOnceMessageItem:cell forMsg:messageItem];
        } else {
            cell.layer.backgroundColor = [UIColor clearColor].CGColor;
            cell.layer.cornerRadius = 0;
            cell.layer.masksToBounds = NO;
        }

//      [self collectionView:collectionView accessibilityForCell:cell indexPath:indexPath message:messageItem];
    
        // 为聊天列表item的消息引用子ui设置显示内容（文本引用 + 转发消息的原发送者）
        if(messageItem.msgType == TM_TYPE_TEXT || (messageItem.quote_content != nil && messageItem.quote_content.length > 0)) {
            [self rb_collectionView:collectionView cellForItemAtIndexPath_quote:indexPath withCell:cell andQuote:messageItem];
        }

        cellRet = cell;
    }

    return cellRet;
}

// 单独的方法里处理头像显示逻辑，方便子类以更大的自由度实现自已的显示逻辑 - 20180528 by JackJiang
- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath_avatar:(NSIndexPath *)indexPath withImageView:(UIImageView *)avatarView
{
    avatarView.layer.cornerRadius = kJSQMessagesCollectionViewAvatarSizeDefault * 0.5f;
    avatarView.layer.masksToBounds = YES;
    // 头像的UI显示
    UIImage *avatarImageDataSource = [collectionView.dataSource collectionView:collectionView avatarImageDataForItemAtIndexPath:indexPath];
    if (avatarImageDataSource != nil) {

        UIImage *avatarImage = avatarImageDataSource;
        if (avatarImage == nil) {
            avatarView.image = [UIImage imageNamed:@"jsq_avatar_placholder"];//[avatarImageDataSource avatarPlaceholderImage];
//          cell.avatarImageView.highlightedImage = nil;
        }
        else {
            avatarView.image = avatarImage;
//          cell.avatarImageView.highlightedImage = [avatarImageDataSource avatarHighlightedImage];
        }
    }
}

// 昵称的显示逻辑 - 20250801 by JackJiang
- (NSString *)rb_collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath_nickname:(NSIndexPath *)indexPath withCell:(JSQMessagesCollectionViewCell *)cell
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

// 单独的方法里处理被引用消息的显示逻辑，方便子类以更大的自由度实现自已的显示逻辑 - 20240316 by JackJiang
- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath_quote:(NSIndexPath *)indexPath withCell:(JSQMessagesCollectionViewCell *)cell andQuote:(QuoteMeta *)quoteMeta
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
}

- (UICollectionReusableView *)collectionView:(JSQMessagesCollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
    if (self.showTypingIndicator && [kind isEqualToString:UICollectionElementKindSectionFooter]) {
        return [collectionView dequeueTypingIndicatorFooterViewForIndexPath:indexPath];
    }
    else if (self.showLoadEarlierMessagesHeader && [kind isEqualToString:UICollectionElementKindSectionHeader]) {
        return [collectionView dequeueLoadEarlierMessagesViewHeaderForIndexPath:indexPath];
    }

    return nil;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    if (!self.showTypingIndicator) {
        return CGSizeZero;
    }

    return CGSizeMake([collectionViewLayout itemWidth], kJSQMessagesTypingIndicatorFooterViewHeight);
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    if (!self.showLoadEarlierMessagesHeader) {
        return CGSizeZero;
    }

    return CGSizeMake([collectionViewLayout itemWidth], kJSQMessagesLoadEarlierHeaderViewHeight);
}


#pragma mark - Collection view delegate（长按消息气泡的快捷菜单相关）
#pragma mark - 20211115经JackJiang证实，以下长按气泡原本纯粹是针对文本消息内的TextView组件，对于全局长按弹出气泡根本不起效！

// 以下delegate方法持起来像是可以在UICollectionView上长按任何cell而被触发，实际上是不会触发，实测ios15，因而本方法目前来说没有卵用！！！！
//- (BOOL)collectionView:(JSQMessagesCollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath
//{
//    //  disable menu for media messages
//    JSQMessage *messageItem = [collectionView.dataSource collectionView:collectionView messageDataForItemAtIndexPath:indexPath];
//    if ([messageItem isMediaMessage]) {
//        return NO;
//    }
//
//    self.selectedIndexPathForMenu = indexPath;
//
//    UICollectionViewCell *theCell = [collectionView cellForItemAtIndexPath:indexPath];
//
//    // 是普通聊天消息
//    if([theCell isKindOfClass:JSQMessagesCollectionViewCell.class])
//    {
//        //  textviews are selectable to allow data detectors
//        //  however, this allows the 'copy, define, select' UIMenuController to show
//        //  which conflicts with the collection view's UIMenuController
//        //  temporarily disable 'selectable' to prevent this issue
//        JSQMessagesCollectionViewCell *selectedCell = (JSQMessagesCollectionViewCell *)theCell;
//        selectedCell.textView.selectable = NO;
//    }
//
//    return YES;
//}
//
//- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
//{
//    if (action == @selector(copy:) || action == @selector(delete:)) {
//        return YES;
//    }
//
//    return NO;
//}
//
//- (void)collectionView:(JSQMessagesCollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
//{
//    if (action == @selector(copy:)) {
//        JSQMessage *messageData = [collectionView.dataSource collectionView:collectionView messageDataForItemAtIndexPath:indexPath];
//        [[UIPasteboard generalPasteboard] setString:[messageData text]];
//    }
//    else if (action == @selector(delete:)) {
//        [collectionView.dataSource collectionView:collectionView didDeleteMessageAtIndexPath:indexPath];
//
//        [collectionView deleteItemsAtIndexPaths:@[indexPath]];
//        [collectionView.collectionViewLayout invalidateLayout];
//    }
//}


#pragma mark - Collection view delegate flow layout

- (CGSize)collectionView:(JSQMessagesCollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionViewLayout sizeForItemAtIndexPath:indexPath];
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellNicknameLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout topGapForQuoteContainerAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForQuoteContainerAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout widthForQuoteIconContainerAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
 didTapAvatarImageView:(UIImageView *)avatarImageView
           atIndexPath:(NSIndexPath *)indexPath { }

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath { }

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapCellAtIndexPath:(NSIndexPath *)indexPath touchLocation:(CGPoint)touchLocation { }

- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView didLongPressCellAtIndexPath:(NSIndexPath *)indexPath touchLocation:(CGPoint)touchLocation cell:(UICollectionViewCell *)cell { }

- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView didTapQuoteAtIndexPath:(NSIndexPath *)indexPath cell:(UICollectionViewCell *)cell { }


#pragma mark - Input toolbar delegate（输入框所在的工具栏相关的代理方法实现）

- (void)messagesInputToolbar:(JSQMessagesInputToolbar *)toolbar didPressLeftBarButton:(UIButton *)sender
{
//    if (toolbar.sendButtonOnRight) {
        [self didPressLeftButton:sender];
//    }
//    else {
//        [self didPressSendButton:sender
//                 withMessageText:[self jsq_currentlyComposedMessageText]
//                        senderId:self.senderId
//               senderDisplayName:self.senderDisplayName
//                            date:[NSDate date]];
//    }
}

- (void)messagesInputToolbar:(JSQMessagesInputToolbar *)toolbar didPressLeftBarButton2:(UIButton *)sender
{
    [self didPressLeftButton2:sender];
}

- (void)messagesInputToolbar:(JSQMessagesInputToolbar *)toolbar didPressRightBarButton:(UIButton *)sender
{
//    if (toolbar.sendButtonOnRight) {
        [self didPressRightButton:sender
                 withMessageText:[self jsq_currentlyComposedMessageText]
                        senderId:self.senderId
               senderDisplayName:self.senderDisplayName
                            date:[NSDate date]];
//    }
//    else {
//        [self didPressAccessoryButton:sender];
//    }
}

// 返回当前文本框中输入的文本内容 -- Freeman改造为返回富文本内容
- (NSString *)jsq_currentlyComposedMessageText
{
    if (self.inputToolbar.contentView.textView.attributedText.length == 0) {
        return nil;
    }
    
    //添加表情支持 方法参数传入的text为纯文本内容，无法获取表情图片附件信息，所以弃用，将重新获取输入框的数据 by Freeman
    NSAttributedString *attributedString = self.inputToolbar.contentView.textView.attributedText;
    NSString *plainString = [EmojiUtil plainStringWith:attributedString range:NSMakeRange(0, attributedString.length)];
    
    //  auto-accept any auto-correct suggestions
    [self.inputToolbar.contentView.textView.inputDelegate selectionWillChange:self.inputToolbar.contentView.textView];
    [self.inputToolbar.contentView.textView.inputDelegate selectionDidChange:self.inputToolbar.contentView.textView];

//  return [self.inputToolbar.contentView.textView.text jsq_stringByTrimingWhitespace];
//  return [plainString jsq_stringByTrimingWhitespace];
    return plainString;// @since 9.0 取消了去掉内容前后的空白符的作法
}


#pragma mark - Text view delegate（文本框输入事件相关的代理方法实现）

- (void)textViewDidBeginEditing:(UITextView *)textView
{
//    NSLog(@"!!!!!!!!!!!!!!!!!-1-textViewDidBeginEditing");
    
    if (textView != self.inputToolbar.contentView.textView) {
        return;
    }

    [textView becomeFirstResponder];

    if (self.automaticallyScrollsToMostRecentMessage) {
        [self scrollToBottomAnimated:YES];
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
//    NSLog(@"!!!!!!!!!!!!!!!!!-3-textViewDidChange");
    
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
//    if (textView != self.inputToolbar.contentView.textView) {
//        return;
//    }
//
////  [self.inputToolbar toggleSendButtonEnabled];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
//    NSLog(@"!!!!!!!!!!!!!!!!!-2-textViewDidEndEditing");
    
    if (textView != self.inputToolbar.contentView.textView) {
        return;
    }

    [textView resignFirstResponder];
}

// 实现键键盘上的“Send”键处理（add by JackJiang 20180302）
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return YES;
}


#pragma mark - Notifications

- (void)jsq_handleDidChangeStatusBarFrameNotification:(NSNotification *)notification
{
    if (self.keyboardController.keyboardIsVisible) {
        [self jsq_setToolbarBottomLayoutGuideConstant:CGRectGetHeight(self.keyboardController.currentKeyboardFrame)];
    }
}

- (void)didReceiveMenuWillShowNotification:(NSNotification *)notification
{
//    NSLog(@"QQQQQQQQQQQ didReceiveMenuWillShowNotification！！！！！");
    
//    NSLog(@"QQQQQQQQQQQ theCell=%@", self.selectedIndexPathForMenu);
//    if (!self.selectedIndexPathForMenu) {
//        return;
//    }

//    UICollectionViewCell *theCell = [self.collectionView cellForItemAtIndexPath:self.selectedIndexPathForMenu];
//
//    NSLog(@"PPPPPPPPPPPPPPP theCell=%@", theCell.class);
//
//    // 是普通聊天消息
//    if([theCell isKindOfClass:JSQMessagesCollectionViewCell.class])
//    {
//        [[NSNotificationCenter defaultCenter] removeObserver:self
//                                                        name:UIMenuControllerWillShowMenuNotification
//                                                      object:nil];
//
//        UIMenuController *menu = [notification object];
//
//        //!---------------------------------------------------------------------------------------------------------------------------------------------------
//        menu.menuItems = @[
//            [[UIMenuItem alloc] initWithTitle:@"Custom Action哦2" action:@selector(customAction:)]
//        ];
//
//
//        [menu setMenuVisible:NO animated:NO];
//
//        JSQMessagesCollectionViewCell *selectedCell = (JSQMessagesCollectionViewCell *)theCell;
//        CGRect selectedCellMessageBubbleFrame = [selectedCell convertRect:selectedCell.messageBubbleContainerView.frame toView:self.view];
//
//        [menu setTargetRect:selectedCellMessageBubbleFrame inView:self.view];
//        [menu setMenuVisible:YES animated:YES];
//
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(didReceiveMenuWillShowNotification:)
//                                                     name:UIMenuControllerWillShowMenuNotification
//                                                   object:nil];
//    }
}

- (void)didReceiveMenuWillHideNotification:(NSNotification *)notification
{
//    NSLog(@"QQQQQQQQQQQ didReceiveMenuWillHideNotification！！！！！");
    
//    if (!self.selectedIndexPathForMenu) {
//        return;
//    }
//
//    UICollectionViewCell *theCell = [self.collectionView cellForItemAtIndexPath:self.selectedIndexPathForMenu];
//
//    // 是普通聊天消息
//    if([theCell isKindOfClass:JSQMessagesCollectionViewCell.class])
//    {
//        //  per comment above in 'shouldShowMenuForItemAtIndexPath:'
//        //  re-enable 'selectable', thus re-enabling data detectors if present
//        JSQMessagesCollectionViewCell *selectedCell = (JSQMessagesCollectionViewCell *)theCell;
//        selectedCell.textView.selectable = YES;
//        self.selectedIndexPathForMenu = nil;
//    }
}


#pragma mark - Key-value observing（多行文本导致文本区高度发生改变的KVO通知处理）

static inline BOOL rb_jsq_isCollectionViewNearBottom(JSQMessagesViewController *vc, CGFloat tolerance)
{
    UIScrollView *cv = vc.collectionView;
    if (!cv) return YES;
    CGFloat topInset = 0.0f, bottomInset = 0.0f;
    if (@available(iOS 11.0, *)) {
        topInset = cv.adjustedContentInset.top;
        bottomInset = cv.adjustedContentInset.bottom;
    } else {
        topInset = cv.contentInset.top;
        bottomInset = cv.contentInset.bottom;
    }
    CGFloat contentHeight = cv.contentSize.height;
    CGFloat frameHeight = CGRectGetHeight(cv.bounds);
    CGFloat visibleHeight = frameHeight - topInset - bottomInset;
    BOOL contentFills = (contentHeight >= visibleHeight - 1.0f);
    CGFloat maxOffsetY = contentHeight + bottomInset - frameHeight;
    if (!contentFills) return YES;
    return fabs(cv.contentOffset.y - maxOffsetY) <= tolerance;
}

// 收到文本输入框contentSize属性变化的KVO通知
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kJSQMessagesKeyValueObservingContext) {

        if (object == self.inputToolbar.contentView.textView
            && [keyPath isEqualToString:NSStringFromSelector(@selector(contentSize))]) {

            CGSize oldContentSize = [[change objectForKey:NSKeyValueChangeOldKey] CGSizeValue];
            CGSize newContentSize = [[change objectForKey:NSKeyValueChangeNewKey] CGSizeValue];

            BOOL userWasAtBottom = rb_jsq_isCollectionViewNearBottom(self, 24.0f);
            CGFloat scale = [UIScreen mainScreen].scale;
            CGFloat oldH = round(oldContentSize.height * scale) / scale;
            CGFloat newH = round(newContentSize.height * scale) / scale;
            CGFloat dy = newH - oldH;
            
            // FFF 解决当输入框开头输入emoji表情时，富文本附件导致输入框高度被撑大的问题 ---2020.8.3
            // 设置10是根据测试字体大小为16时，oldContentSize高度为26，emoji富文本导致高度为32,这个设值应在新旧差值(6)与行高之间
            // 小于10肯定是没换行了，这个值其实只要比行高小就可以
            CGFloat lineH = self.inputToolbar.contentView.textView.font.lineHeight;
            if (lineH <= 0) lineH = 19.0f;
            if (fabs(dy) < lineH * 0.6f) dy = 0;
            if (dy == 0) {
                return;
            }

            [self jsq_adjustInputToolbarForComposerTextViewContentSizeChange:dy];
            [self jsq_updateCollectionViewInsets];
            if (self.automaticallyScrollsToMostRecentMessage && userWasAtBottom) {
                [self scrollToBottomAnimated:NO];
            }
        }
    }
}


#pragma mark - KeyboardController的代理方法实现（软键盘的显示或取消显示时以下方法被调用）

// 用户的上下滑动消息列表动作完成。
// 开发者可在此类中实现的功能行为如：下滑关闭消息输入、复位底部（+）More”面板、复位表情面板等，就像微信中所表现的一样。
- (void)keyboardController:(JSQMessagesKeyboardController *)keyboardController gestureComplete:(BOOL)complete
{
//    NSLog(@"【JSQ-RB】到这里了吗: rb_keyboardController_gestureComplete!");

    //## 以下被注释的代码用于v6.0前的底部面板显示逻辑，目前已废弃，日后删除之
    // 取消底部更多功能面板的显示
//  [self toggleBottomBoxWith:RBBottomBoxContentViewStateNone];
////  [self scrollToBottomAnimated:YES];
    
    // 隐藏底部功能区的显示
    [self hideBottomBoxAnim:YES];
    // 重置表情按钮的图标显示
    [self resetLeftButton2Style];
}

// ★ 键盘帧变化回调 — 现在由 UIKeyboardWillChangeFrameNotification 驱动（动画开始前触发）
//   使用键盘系统提供的动画参数，让工具栏、聊天记录与键盘同步动画，消除"键盘先出来 UI 后动"的卡顿
- (void)keyboardController:(JSQMessagesKeyboardController *)keyboardController keyboardDidChangeFrame:(CGRect)keyboardFrame
{
    CGFloat restConstant = self.rb_useFloatingMorePanel ? rb_floatingBarRestConstant() : 0.0;
    if (![self.inputToolbar.contentView.textView isFirstResponder] && self.toolbarBottomLayoutGuide.constant == restConstant) {
        return;
    }
    
    // 计算输入工具栏底部偏移（与 xib 中 toolbar.bottom ↔ safeArea.bottom 约束一致）。
    // 注意：rb_fixCollectionViewBottomToViewIfNeeded 已将 collectionView 底部贴 view 底，不能再沿用「collection 贴 safeArea」时的 (maxY+safeBottom)-kb-safeBottom，
    // 否则会少减一次 safeBottom，constant 偏大 → 输入栏整体偏高，键盘与输入框之间出现大块空白。
    CGFloat keyboardMinY = CGRectGetMinY(keyboardFrame);
    CGFloat restingToolbarBottomY = CGRectGetMaxY(self.view.safeAreaLayoutGuide.layoutFrame);
    CGFloat heightFromBottom = restingToolbarBottomY - keyboardMinY;
    heightFromBottom = MAX(0.0f, heightFromBottom);

    BOOL toHide = (floor(heightFromBottom) == 0.0f);

    if (toHide && self.rb_useFloatingMorePanel) {
        heightFromBottom = rb_floatingBarRestConstant();
    }

    // ★ 使用与键盘/更多面板相同的动画时长与曲线，让工具栏与系统视图同步移动，避免露出背景
    NSTimeInterval duration = keyboardController.keyboardAnimationDuration;
    UIViewAnimationCurve curve = keyboardController.keyboardAnimationCurve;
    // 将 UIViewAnimationCurve 转为 UIViewAnimationOptions（左移 16 位）
    UIViewAnimationOptions options = ((NSUInteger)curve << 16) | UIViewAnimationOptionBeginFromCurrentState;
    
    // 设置约束新值
    self.toolbarBottomLayoutGuide.constant = heightFromBottom;
    [self.view setNeedsUpdateConstraints];
    
    [UIView animateWithDuration:duration
                          delay:0
                        options:options
                     animations:^{
        [self.view layoutIfNeeded];
        // 在动画块内更新 insets，与工具栏同步，避免露出背景
        [self jsq_updateCollectionViewInsets];
    } completion:nil];
    
    // 键盘弹出时滚动到底部（使用 NO 避免额外动画叠加）
    if(!toHide)
    {
        [self scrollToBottomAnimated:NO];
    }
}

- (void)jsq_setToolbarBottomLayoutGuideConstant:(CGFloat)constant
{
//    NSLog(@"【RB】bb jsq_setToolbarBottomLayoutGuideConstant被调用了，constant=%f", constant);

    self.toolbarBottomLayoutGuide.constant = constant;
    [self.view setNeedsUpdateConstraints];
    [self.view layoutIfNeeded];

    [self jsq_updateCollectionViewInsets];
}

//- (void)jsq_updateKeyboardTriggerPoint
//{
//    self.keyboardController.keyboardTriggerPoint = CGPointMake(0.0f, CGRectGetHeight(self.inputToolbar.bounds));
//}


#pragma mark - Gesture recognizers（主界面的向右侧滑时以下方法被调用，其实就是新版ios里向右侧滑退出当前界面的那个侧滑事件）
// navigationController自带的侧滑手势处理（如果不处理这个手势，则当用户侧滑了一半又退出时，则文本框的位置就不能正常显示到输入法之上了哦）
- (void)jsq_handleInteractivePopGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state) {
        // 手势状态：手势已经开始，此时已经被识别，但是这个过程中可能发生变化，手势操作尚未完成
        case UIGestureRecognizerStateBegan:
        {
//            if ([UIDevice jsq_isCurrentDeviceBeforeiOS8]) {
//                [self.snapshotView removeFromSuperview];
//            }

            self.textViewWasFirstResponderDuringInteractivePop = [self.inputToolbar.contentView.textView isFirstResponder];

            [self.keyboardController endListeningForKeyboard];

//            if ([UIDevice jsq_isCurrentDeviceBeforeiOS8]) {
//                [self.inputToolbar.contentView.textView resignFirstResponder];
//                [UIView animateWithDuration:0.0
//                                 animations:^{
//                                     [self jsq_setToolbarBottomLayoutGuideConstant:0.0];
//                                 }];
//
//                UIView *snapshot = [self.view snapshotViewAfterScreenUpdates:YES];
//                [self.view addSubview:snapshot];
//                self.snapshotView = snapshot;
//            }
        }
            break;
        // 手势状态：手势状态发生改变
        case UIGestureRecognizerStateChanged:
            break;
        // 手势状态：手势被取消，恢复到默认状态
        case UIGestureRecognizerStateCancelled:
        // 手势状态：手势识别操作完成（此时已经松开手指）
        case UIGestureRecognizerStateEnded:
        // 手势状态：手势识别失败，恢复到默认状态
        case UIGestureRecognizerStateFailed:
            [self.keyboardController beginListeningForKeyboard];
            if (self.textViewWasFirstResponderDuringInteractivePop) {
                [self.inputToolbar.contentView.textView becomeFirstResponder];
            }

//          if ([UIDevice jsq_isCurrentDeviceBeforeiOS8]) {
//              [self.snapshotView removeFromSuperview];
//          }
            break;
        default:
            break;
    }
}


#pragma mark - Input toolbar utilities（当输入多行文本时，UI界面的自动适应和调用由以下实用方法实现）

- (BOOL)jsq_inputToolbarHasReachedMaximumHeight
{
    return CGRectGetMinY(self.inputToolbar.frame) == ([self getTopLayoutGuideLength] + self.topContentAdditionalInset);
}

- (void)jsq_adjustInputToolbarForComposerTextViewContentSizeChange:(CGFloat)dy
{
    if (dy == 0) return;

    CGFloat toolbarOriginY = CGRectGetMinY(self.inputToolbar.frame);
    CGFloat newToolbarOriginY = toolbarOriginY - dy;

    //  attempted to increase origin.Y above topLayoutGuide
    if (newToolbarOriginY <= [self getTopLayoutGuideLength] + self.topContentAdditionalInset) {
        dy = toolbarOriginY - ([self getTopLayoutGuideLength] + self.topContentAdditionalInset);
    }

    [self jsq_adjustInputToolbarHeightConstraintByDelta:dy];

//    [self jsq_updateKeyboardTriggerPoint];
}

// 调整输入框工具栏的高度（这通常发生在输入了多行文档或取消多行文本时）
- (void)jsq_adjustInputToolbarHeightConstraintByDelta:(CGFloat)dy
{
    CGFloat proposedHeight = self.toolbarHeightConstraint.constant + dy;

    CGFloat finalHeight = MAX(proposedHeight, [self.inputToolbar getPreferredDefaultHeight]);

    if (self.inputToolbar.maximumHeight != NSNotFound) {
        finalHeight = MIN(finalHeight, self.inputToolbar.maximumHeight);
    }

    if (self.toolbarHeightConstraint.constant != finalHeight) {
        self.toolbarHeightConstraint.constant = finalHeight;
        [self.view setNeedsUpdateConstraints];
        [self.view layoutIfNeeded];
    }
}

- (void)jsq_scrollComposerTextViewToBottomAnimated:(BOOL)animated
{
    UITextView *textView = self.inputToolbar.contentView.textView;
    CGFloat y = textView.contentSize.height - CGRectGetHeight(textView.bounds);
    if (y < 0.0f) y = 0.0f;
    CGPoint contentOffsetToShowLastLine = CGPointMake(0.0f, y);

    if (!animated) {
        textView.contentOffset = contentOffsetToShowLastLine;
        return;
    }

    [UIView animateWithDuration:0.01
                          delay:0.01
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         textView.contentOffset = contentOffsetToShowLastLine;
                     }
                     completion:nil];
}


#pragma mark - Collection view utilities

/// 内容不足、不允许穿过导航时使用的顶部 inset（安全区/导航下沿）
- (CGFloat)jsq_topInsetWhenContentDoesNotFill
{
    if (@available(iOS 11.0, *)) {
        return self.view.safeAreaInsets.top;
    }
    return self.topLayoutGuide.length;
}

- (void)jsq_updateCollectionViewInsets
{
    CGFloat bottomValue = CGRectGetMaxY(self.collectionView.frame) - CGRectGetMinY(self.inputToolbar.frame);
    CGFloat visibleHeight = self.collectionView.bounds.size.height - bottomValue;
    CGFloat contentHeight = self.collectionView.contentSize.height;
    CGFloat topValue;
    if (visibleHeight <= 0.f) {
        // 首帧 bounds 未就绪，保守留顶
        topValue = [self jsq_topInsetWhenContentDoesNotFill] + self.topContentAdditionalInset;
    } else if (contentHeight >= visibleHeight - 1.0f) {
        // 内容足够：允许穿过导航
        topValue = self.topContentAdditionalInset;
    } else {
        // 内容不足：顶部留白 = 可视高度 - 内容高度，使最新消息贴底、从下往上排，空在上方不穿过导航
        CGFloat topForBottomAlign = visibleHeight - contentHeight;
        CGFloat minTop = [self jsq_topInsetWhenContentDoesNotFill];
        topValue = MAX(minTop, topForBottomAlign) + self.topContentAdditionalInset;
    }
    if (topValue == 0.f && contentHeight < visibleHeight - 1.0f) {
        topValue = 44.0f;
    }
    [self jsq_setCollectionViewInsetsTopValue:topValue bottomValue:bottomValue];
}

- (void)jsq_setCollectionViewInsetsTopValue:(CGFloat)top bottomValue:(CGFloat)bottom
{
//    NSLog(@"----------------------- A2: top=%f, bottom=%f", top, bottom);
    UIEdgeInsets insets = UIEdgeInsetsMake(top, 0.0f, bottom, 0.0f);
    self.collectionView.contentInset = insets;
    self.collectionView.scrollIndicatorInsets = insets;
}

- (BOOL)jsq_isMenuVisible
{
    //  check if cell copy menu is showing
    //  it is only our menu if `selectedIndexPathForMenu` is not `nil`
    
    //## 自20211115起，selectedIndexPathForMenu及其逻辑都取消了！
//    return self.selectedIndexPathForMenu != nil && [[UIMenuController sharedMenuController] isMenuVisible];
    
    return NO;
}

//## Bug FIX: 自v10.2起，本界面中的所有self.topLayoutGuide.length在ios 26下都被替换成了0（低于ios 26系统中保持原样不变）
//            ，原因是它的值在iOS 26上会莫名其妙变成116（实际就应该是0），而且它也已过期，所以全部替换了！
- (CGFloat)getTopLayoutGuideLength
{
    // 针对ios 26的优化：ios26下UIScrollView这种东西（UITableView和UICollectionView也自带了它）它会自动避开上下的安全区，不需要手动适配，很神奇！
    if (@available(iOS 26, *)) {
        return 0.0f;
    }
    // 低于ios 26的保持原来的用法
    else {
        return self.topLayoutGuide.length;
    }
}


#pragma mark - Utilities

- (void)jsq_addObservers
{
    if (self.jsq_isObserving) {
        return;
    }

    [self.inputToolbar.contentView.textView addObserver:self
                                             forKeyPath:NSStringFromSelector(@selector(contentSize))
                                                options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                                                context:kJSQMessagesKeyValueObservingContext];

    self.jsq_isObserving = YES;
}

- (void)jsq_removeObservers
{
    if (!_jsq_isObserving) {
        return;
    }

    @try {
        [_inputToolbar.contentView.textView removeObserver:self
                                                forKeyPath:NSStringFromSelector(@selector(contentSize))
                                                   context:kJSQMessagesKeyValueObservingContext];
    }
    @catch (NSException * __unused exception) { }

    _jsq_isObserving = NO;
}

- (void)jsq_registerForNotifications:(BOOL)registerForNotifications
{
    if (registerForNotifications) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(jsq_handleDidChangeStatusBarFrameNotification:)
                                                     name:UIApplicationDidChangeStatusBarFrameNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveMenuWillShowNotification:)
                                                     name:UIMenuControllerWillShowMenuNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveMenuWillHideNotification:)
                                                     name:UIMenuControllerWillHideMenuNotification
                                                   object:nil];
    }
    else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIApplicationDidChangeStatusBarFrameNotification
                                                      object:nil];

        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIMenuControllerWillShowMenuNotification
                                                      object:nil];

        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIMenuControllerWillHideMenuNotification
                                                      object:nil];
    }
}

- (void)jsq_addActionToInteractivePopGestureRecognizer:(BOOL)addAction
{
    if (self.currentInteractivePopGestureRecognizer != nil) {
        [self.currentInteractivePopGestureRecognizer removeTarget:nil
                                                           action:@selector(jsq_handleInteractivePopGestureRecognizer:)];
        self.currentInteractivePopGestureRecognizer = nil;
    }
    
    if (addAction) {
        [self.navigationController.interactivePopGestureRecognizer addTarget:self
                                                                      action:@selector(jsq_handleInteractivePopGestureRecognizer:)];
        self.currentInteractivePopGestureRecognizer = self.navigationController.interactivePopGestureRecognizer;
    }
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//    if([self isLastCellVisible]) { // 通过isLastCellVisible来判断是否到底，性能不好
//        // 【当消息列表真滑动到最后一条可见时的处理3】设置“未读数”提示UI不可见（重置未读数为0）
//        [self resetUnreadCount];
//    }
}


#pragma mark - 当消息列表最后一行处于可见或不可见时的新消息（未读消息）提示ui的相关方法。

/*!
 *  点击消息未读数气泡事件处理。
 */
- (void)fireOnClickUnreadBallon:(UITapGestureRecognizer *)sender {
//- (IBAction)fireOnClickUnreadBallon:(id)sender {
    // 点击未读气泡时自动让消息列表滚动到最后一行
    [self finishReceivingMessageAnimated:YES];
    // 同时设置“未读数”提示UI不可见（重置未读数为0）
    [self resetUnreadCount];
}

/**
 * 设置当前总的未读数.
 *
 * @param unreadCount 总未读数
 */
- (void)setUnreadCount:(int)unreadCount
{
    if (unreadCount < 0)
        unreadCount = 0;
    _unreadCount = unreadCount;
    self.unreadMessageBallonContainer.hidden = YES;
}

/**
 * 重置总的未读数.
 */
- (void)resetUnreadCount
{
    [self setUnreadCount:0];
}

/**
 * 返回当前的未读数.
 *
 * @return unread count
 */
-(int)getUnreadCount
{
//    if([@"99+" isEqualToString:self.unreadMessageBallonLabel.text]) {
//        return 99;
//    } else {
//        return [BasicTool getIntValue:self.unreadMessageBallonLabel.text];
//    }
//    //        return CommonUtils.getIntValue(String.valueOf(viewUnreadBallon.getText()));
    return _unreadCount < 0 ? 0 : _unreadCount;
}

/**
 * 总未读数累加.
 *
 * @param countForAccumulate 要累加的值
 */
- (void)addUnreadCount:(int)countForAccumulate
{
    [self setUnreadCount:(countForAccumulate + [self getUnreadCount])];
}

@end
