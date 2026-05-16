//
//  CallViewController.m
//  RainbowChat4i
//
//  微信风格音视频通话UI界面实现。
//  支持左右滑动最小化到浮窗，点击浮窗恢复全屏。
//

#import "CallViewController.h"
#import "CallManager.h"
#import "AgoraManager.h"
#import "CallFloatingManager.h"
#import "IMClientManager.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "Default.h"
#import "CallSoundManager.h"
#import "CallPiPManager.h"

// 尺寸常量
static const CGFloat kAvatarSize          = 90.0;
static const CGFloat kBtnSize             = 72.0;   // 普通底部按钮尺寸（静音/免提/翻转/接听/挂断/拒绝）
static const CGFloat kPrimaryBtnSize      = 72.0;   // 主操作按钮尺寸（目前与普通一致）
static const CGFloat kBtnIconPointSize    = 30.0;   // 底部按钮图标 SF Symbol 字号（静音/挂断/免提等）
static const CGFloat kSmallVideoWidth     = 110.0;
static const CGFloat kSmallVideoHeight    = 150.0;
static const CGFloat kSmallVideoCorner    = 10.0;
static const CGFloat kSmallVideoMargin    = 16.0;

@interface CallViewController () <CallManagerDelegate, AgoraManagerDelegate>

// ===== 背景 =====
@property (nonatomic, strong) UIImageView *bgAvatarView;
@property (nonatomic, strong) UIVisualEffectView *blurOverlay;
@property (nonatomic, strong) UIView *darkOverlay;

// ===== 中心内容 =====
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *timerLabel;

// ===== 顶部 =====
@property (nonatomic, strong) UIButton *minimizeButton;

// ===== 底部按钮（同一行）=====
@property (nonatomic, strong) UIStackView *bottomButtonsStack;

@property (nonatomic, strong) UIView *muteContainer;
@property (nonatomic, strong) UIButton *muteButton;
@property (nonatomic, strong) UILabel *muteLabel;

@property (nonatomic, strong) UIView *speakerContainer;
@property (nonatomic, strong) UIButton *speakerButton;
@property (nonatomic, strong) UILabel *speakerLabel;

@property (nonatomic, strong) UIView *cameraContainer;
@property (nonatomic, strong) UIButton *switchCameraButton;
@property (nonatomic, strong) UILabel *switchCameraLabel;

@property (nonatomic, strong) UIView *hangupContainer;
@property (nonatomic, strong) UIButton *hangupButton;
@property (nonatomic, strong) UILabel *hangupLabel;

@property (nonatomic, strong) UIView *acceptContainer;
@property (nonatomic, strong) UIButton *acceptButton;
@property (nonatomic, strong) UILabel *acceptLabel;

@property (nonatomic, strong) UIView *rejectContainer;
@property (nonatomic, strong) UIButton *rejectButton;
@property (nonatomic, strong) UILabel *rejectLabel;

// ===== 视频相关 =====
@property (nonatomic, strong) UIView *localVideoView;
@property (nonatomic, strong) UIView *remoteVideoView;

// ===== 状态 =====
@property (nonatomic, strong) NSTimer *durationTimer;
@property (nonatomic, assign) BOOL isMuted;
@property (nonatomic, assign) BOOL isSpeakerOn;
@property (nonatomic, assign) BOOL isMinimizing;
/// P1-1：延后到布局完成后执行小窗动画，避免 safeArea 未就绪
@property (nonatomic, assign) BOOL needsAnimateLocalVideoToSmallWindow;

@end

@implementation CallViewController

#pragma mark - 初始化

- (instancetype)initWithCallType:(CallType)callType
                   remoteUserUid:(NSString *)remoteUserUid
              remoteUserNickname:(NSString *)remoteUserNickname
                        isCaller:(BOOL)isCaller
{
    self = [super init];
    if (self) {
        _callType = callType;
        _remoteUserUid = remoteUserUid;
        _remoteUserNickname = remoteUserNickname;
        _isCaller = isCaller;
        _isMuted = NO;
        _isSpeakerOn = (callType == CallTypeVideo);
        _isMinimizing = NO;
    }
    return self;
}

#pragma mark - 生命周期

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:25/255.0 green:25/255.0 blue:35/255.0 alpha:1.0];
    self.navigationController.navigationBarHidden = YES;
    
    [self setupBackground];
    [self setupUI];
    [self setupSwipeGestures];
    
    [CallManager sharedInstance].delegate = self;
    [AgoraManager sharedInstance].delegate = self;
    
    if (self.callType == CallTypeVideo) {
        [self setupVideoViews];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rb_onAgoraEngineRebuilt:) name:RBAgoraEngineDidRebuildNotification object:nil];
        if (!self.isRestoringFromFloat) {
            [self startLocalCameraPreview];
        }
    }
    
    [self loadRemoteAvatar];
    
    if (self.isRestoringFromFloat) {
        [self restoreFromFloat];
    } else {
        // 如果此时通话已经结束（极端情况下对方很快挂断），直接退出
        if ([CallManager sharedInstance].currentState == CallStateIdle) {
            [self dismissSelfAfterDelay:0.1];
            return;
        }
        
        [self updateUIForCurrentState];
        
        if (self.callType == CallTypeVideo && [AgoraManager sharedInstance].isInitialized) {
            [[AgoraManager sharedInstance] setEnableSpeakerphone:self.isSpeakerOn];
        }
        
        // 仅主叫方在全屏界面播放呼出回铃音；被叫方的来电铃声在 CallIncomingPopupManager 中播放
        if (self.isCaller) {
            [[CallSoundManager sharedInstance] playRingbackTone];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = NO;

    // 系统左滑返回或其他方式退出时，若仍在视频通话中则启动 PiP
    if (!self.isMinimizing
        && self.callType == CallTypeVideo
        && [CallManager sharedInstance].currentState == CallStateConnected) {
        self.isMinimizing = YES;
        [self stopDurationTimer];
        [[CallPiPManager sharedInstance] startPiPWhenPossible];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.callType == CallTypeVideo) {
        [[CallPiPManager sharedInstance] attachPiPSourceViewToContainerView:self.view];
    }
    if (self.needsAnimateLocalVideoToSmallWindow && self.callType == CallTypeVideo && self.localVideoView) {
        self.needsAnimateLocalVideoToSmallWindow = NO;
        [self animateLocalVideoToSmallWindow];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RBAgoraEngineDidRebuildNotification object:nil];
    [self stopDurationTimer];
    if (!self.isMinimizing) {
        [[CallSoundManager sharedInstance] stopAll];
        [CallManager sharedInstance].delegate = nil;
        [AgoraManager sharedInstance].delegate = nil;
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - 从浮窗恢复

- (void)restoreFromFloat
{
    CallState state = [CallManager sharedInstance].currentState;
    
    if (state == CallStateConnected) {
        [self layoutForConnected];
        
        if (self.callType == CallTypeVideo) {
            // 恢复本地预览
            [[AgoraManager sharedInstance] setupLocalVideoView:self.localVideoView];
            
            // 恢复远端视频
            NSUInteger remoteUid = [AgoraManager sharedInstance].lastRemoteUid;
            if (remoteUid > 0) {
                self.remoteVideoView.hidden = NO;
                [[AgoraManager sharedInstance] setupRemoteVideoView:self.remoteVideoView forUid:remoteUid];
            }
            
            self.needsAnimateLocalVideoToSmallWindow = YES;
        }
    } else if (state == CallStateOutgoingCalling) {
        [self layoutForOutgoing];
        
        // 视频呼出时恢复本地预览
        if (self.callType == CallTypeVideo) {
            [[AgoraManager sharedInstance] setupLocalVideoView:self.localVideoView];
        }
        
        [[CallSoundManager sharedInstance] playRingbackTone];
    } else if (state == CallStateIncomingCalling) {
        [self layoutForIncoming];
        [[CallSoundManager sharedInstance] playRingtone];
    } else {
        [self dismissSelf];
    }
}

#pragma mark - 滑动手势

- (void)setupSwipeGestures
{
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onSwipeToMinimize:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeLeft];
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onSwipeToMinimize:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];
    
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onSwipeToMinimize:)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:swipeDown];
}

- (void)onSwipeToMinimize:(UISwipeGestureRecognizer *)gesture
{
    [self minimizeToFloatingWindow];
}

- (void)minimizeToFloatingWindow
{
    if (![CallManager sharedInstance].isInCall) return;

    // 视频通话：使用系统 PiP 画中画
    if (self.callType == CallTypeVideo && [CallManager sharedInstance].currentState == CallStateConnected) {
        self.isMinimizing = YES;
        [self stopDurationTimer];
        [[CallPiPManager sharedInstance] startPiPWhenPossible];
        if (self.navigationController) {
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        return;
    }

    // 语音通话或未接通：仍用自定义浮窗
    self.isMinimizing = YES;
    [self stopDurationTimer];

    [[CallFloatingManager sharedInstance] showWithCallType:self.callType
                                            remoteUserUid:self.remoteUserUid
                                       remoteUserNickname:self.remoteUserNickname];

    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - 背景设置

- (void)setupBackground
{
    self.bgAvatarView = [[UIImageView alloc] init];
    self.bgAvatarView.frame = self.view.bounds;
    self.bgAvatarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.bgAvatarView.contentMode = UIViewContentModeScaleAspectFill;
    self.bgAvatarView.clipsToBounds = YES;
    self.bgAvatarView.image = [UIImage imageNamed:@"default_avatar_70"];
    [self.view addSubview:self.bgAvatarView];
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.blurOverlay = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurOverlay.frame = self.view.bounds;
    self.blurOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.blurOverlay];
    
    self.darkOverlay = [[UIView alloc] init];
    self.darkOverlay.frame = self.view.bounds;
    self.darkOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.darkOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    [self.view addSubview:self.darkOverlay];
}

#pragma mark - UI构建

- (void)setupUI
{
    // ===== 头像 =====
    self.avatarImageView = [[UIImageView alloc] init];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.layer.cornerRadius = 12;
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.image = [UIImage imageNamed:@"default_avatar_70"];
    [self.view addSubview:self.avatarImageView];

    // ===== 昵称 =====
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.text = self.remoteUserNickname ?: @"未知用户";
    self.nameLabel.textColor = [UIColor whiteColor];
    self.nameLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.nameLabel];
    
    // ===== 状态文字 =====
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];
    
    // ===== 通话时长 =====
    self.timerLabel = [[UILabel alloc] init];
    self.timerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timerLabel.textColor = [UIColor whiteColor];
    self.timerLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightRegular];
    self.timerLabel.textAlignment = NSTextAlignmentCenter;
    self.timerLabel.hidden = YES;
    [self.view addSubview:self.timerLabel];
    
    // ===== 最小化按钮 =====
    self.minimizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.minimizeButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *minImage = [[UIImage imageNamed:@"call_minimize_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.minimizeButton setImage:minImage forState:UIControlStateNormal];
    self.minimizeButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.minimizeButton.tintColor = [UIColor whiteColor];
    // 缩小图标在 44x44 按钮中的占比
    self.minimizeButton.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    [self.minimizeButton addTarget:self action:@selector(onMinimizeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.minimizeButton];
    
    // ===== 构建底部按钮（同一行）=====
    [self setupBottomButtons];
    
    // ===== 布局约束 =====
    [NSLayoutConstraint activateConstraints:@[
        [self.minimizeButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.minimizeButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.minimizeButton.widthAnchor constraintEqualToConstant:44],
        [self.minimizeButton.heightAnchor constraintEqualToConstant:44],
        
        [self.avatarImageView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.avatarImageView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:100],
        [self.avatarImageView.widthAnchor constraintEqualToConstant:kAvatarSize],
        [self.avatarImageView.heightAnchor constraintEqualToConstant:kAvatarSize],
        
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.avatarImageView.bottomAnchor constant:18],
        [self.nameLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.nameLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:30],
        [self.nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-30],
        
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:8],
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:30],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-30],
        
        [self.timerLabel.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:6],
        [self.timerLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];
}

#pragma mark - 底部按钮（同一水平行）

- (void)setupBottomButtons
{
    // 静音
    self.muteContainer = [self createButtonWithSystemImage:@"mic.fill" title:@"静音"
                            bgColor:[UIColor colorWithWhite:1.0 alpha:0.2]
                          tintColor:[UIColor whiteColor] action:@selector(onMuteTapped)
                         buttonSize:kBtnSize
                          outButton:&_muteButton outLabel:&_muteLabel];
    
    // 免提
    self.speakerContainer = [self createButtonWithSystemImage:@"speaker.wave.2.fill" title:@"免提"
                               bgColor:[UIColor colorWithWhite:1.0 alpha:0.2]
                             tintColor:[UIColor whiteColor] action:@selector(onSpeakerTapped)
                            buttonSize:kBtnSize
                             outButton:&_speakerButton outLabel:&_speakerLabel];
    
    // 翻转摄像头
    self.cameraContainer = [self createButtonWithSystemImage:@"camera.rotate" title:@"翻转"
                              bgColor:[UIColor colorWithWhite:1.0 alpha:0.2]
                            tintColor:[UIColor whiteColor] action:@selector(onSwitchCameraTapped)
                           buttonSize:kBtnSize
                            outButton:&_switchCameraButton outLabel:&_switchCameraLabel];
    
    // 挂断（红色）
    self.hangupContainer = [self createButtonWithSystemImage:@"phone.down.fill" title:@"挂断"
                              bgColor:[UIColor colorWithRed:0.95 green:0.22 blue:0.21 alpha:1.0]
                            tintColor:[UIColor whiteColor] action:@selector(onHangupTapped)
                           buttonSize:kPrimaryBtnSize
                            outButton:&_hangupButton outLabel:&_hangupLabel];
    
    // 接听（绿色）
    self.acceptContainer = [self createButtonWithSystemImage:@"phone.fill" title:@"接听"
                              bgColor:[UIColor colorWithRed:0.30 green:0.85 blue:0.39 alpha:1.0]
                            tintColor:[UIColor whiteColor] action:@selector(onAcceptTapped)
                           buttonSize:kBtnSize
                            outButton:&_acceptButton outLabel:&_acceptLabel];
    
    // 拒绝（红色）
    self.rejectContainer = [self createButtonWithSystemImage:@"phone.down.fill" title:@"拒绝"
                              bgColor:[UIColor colorWithRed:0.95 green:0.22 blue:0.21 alpha:1.0]
                            tintColor:[UIColor whiteColor] action:@selector(onRejectTapped)
                           buttonSize:kPrimaryBtnSize
                            outButton:&_rejectButton outLabel:&_rejectLabel];
    
    // 底部 StackView（初始为空，每次切换状态时动态填充）
    self.bottomButtonsStack = [[UIStackView alloc] init];
    self.bottomButtonsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomButtonsStack.axis = UILayoutConstraintAxisHorizontal;
    self.bottomButtonsStack.distribution = UIStackViewDistributionFillEqually;
    self.bottomButtonsStack.alignment = UIStackViewAlignmentCenter;
    self.bottomButtonsStack.spacing = 0;
    [self.view addSubview:self.bottomButtonsStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomButtonsStack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-50],
        [self.bottomButtonsStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.bottomButtonsStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
    ]];
}

- (UIView *)createButtonWithSystemImage:(NSString *)systemImage
                                  title:(NSString *)title
                                bgColor:(UIColor *)bgColor
                              tintColor:(UIColor *)tintColor
                                 action:(SEL)action
                             buttonSize:(CGFloat)buttonSize
                              outButton:(UIButton *__strong *)outBtn
                               outLabel:(UILabel *__strong *)outLbl
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = bgColor;
    btn.layer.cornerRadius = buttonSize / 2;
    btn.clipsToBounds = YES;
    
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:kBtnIconPointSize weight:UIImageSymbolWeightMedium];
    UIImage *img = [UIImage systemImageNamed:systemImage withConfiguration:config];
    [btn setImage:img forState:UIControlStateNormal];
    btn.tintColor = tintColor;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:btn];
    
    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text = title;
    lbl.font = [UIFont systemFontOfSize:11];
    lbl.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    lbl.textAlignment = NSTextAlignmentCenter;
    [container addSubview:lbl];
    
    [NSLayoutConstraint activateConstraints:@[
        [btn.topAnchor constraintEqualToAnchor:container.topAnchor],
        [btn.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [btn.widthAnchor constraintEqualToConstant:buttonSize],
        [btn.heightAnchor constraintEqualToConstant:buttonSize],
        
        [lbl.topAnchor constraintEqualToAnchor:btn.bottomAnchor constant:6],
        [lbl.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [lbl.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    
    *outBtn = btn;
    *outLbl = lbl;
    
    return container;
}

#pragma mark - 视频视图

- (void)setupVideoViews
{
    self.remoteVideoView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.remoteVideoView.backgroundColor = [UIColor blackColor];
    self.remoteVideoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.remoteVideoView.hidden = YES;
    [self.view insertSubview:self.remoteVideoView aboveSubview:self.darkOverlay];
    
    self.localVideoView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.localVideoView.backgroundColor = [UIColor colorWithRed:25/255.0 green:25/255.0 blue:35/255.0 alpha:1.0];
    self.localVideoView.clipsToBounds = YES;
    self.localVideoView.hidden = NO;
    [self.view insertSubview:self.localVideoView aboveSubview:(self.remoteVideoView ?: self.darkOverlay)];
    
    // 确保 UI 控件在视频层之上
    [self.view bringSubviewToFront:self.avatarImageView];
    [self.view bringSubviewToFront:self.nameLabel];
    [self.view bringSubviewToFront:self.statusLabel];
    [self.view bringSubviewToFront:self.timerLabel];
    [self.view bringSubviewToFront:self.minimizeButton];
    [self.view bringSubviewToFront:self.bottomButtonsStack];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLocalViewPan:)];
    [self.localVideoView addGestureRecognizer:pan];
}

/// Token 返回后若切换了声网 AppId，引擎会重建，须重新绑定本地预览（否则黑屏）
- (void)rb_onAgoraEngineRebuilt:(NSNotification *)notification
{
    (void)notification;
    if (self.callType != CallTypeVideo || self.localVideoView == nil) {
        return;
    }
    [[AgoraManager sharedInstance] enableVideo:YES];
    [[AgoraManager sharedInstance] setupLocalVideoView:self.localVideoView];
    NSUInteger remoteUid = [AgoraManager sharedInstance].lastRemoteUid;
    if (remoteUid > 0 && self.remoteVideoView != nil && !self.remoteVideoView.hidden) {
        [[AgoraManager sharedInstance] setupRemoteVideoView:self.remoteVideoView forUid:remoteUid];
    }
}

- (void)startLocalCameraPreview
{
    if (![AgoraManager sharedInstance].isInitialized) {
        [[AgoraManager sharedInstance] initialize];
    }
    [[AgoraManager sharedInstance] enableVideo:YES];
    [[AgoraManager sharedInstance] setupLocalVideoView:self.localVideoView];
}

- (void)animateLocalVideoToSmallWindow
{
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat topInset = self.view.safeAreaInsets.top;
    CGRect smallFrame = CGRectMake(screenWidth - kSmallVideoWidth - kSmallVideoMargin,
                                    topInset + kSmallVideoMargin,
                                    kSmallVideoWidth, kSmallVideoHeight);
    
    [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.localVideoView.frame = smallFrame;
        self.localVideoView.layer.cornerRadius = kSmallVideoCorner;
        self.localVideoView.layer.shadowColor = [UIColor blackColor].CGColor;
        self.localVideoView.layer.shadowOffset = CGSizeMake(0, 4);
        self.localVideoView.layer.shadowOpacity = 0.4;
        self.localVideoView.layer.shadowRadius = 8;
    } completion:^(BOOL finished) {
        [self.view bringSubviewToFront:self.localVideoView];
    }];
}

- (void)handleLocalViewPan:(UIPanGestureRecognizer *)gesture
{
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint center = self.localVideoView.center;
    center.x += translation.x;
    center.y += translation.y;
    
    CGFloat halfW = self.localVideoView.frame.size.width / 2;
    CGFloat halfH = self.localVideoView.frame.size.height / 2;
    CGFloat maxX = self.view.bounds.size.width - halfW - 8;
    CGFloat maxY = self.view.bounds.size.height - halfH - 8;
    CGFloat minX = halfW + 8;
    CGFloat minY = self.view.safeAreaInsets.top + halfH + 8;
    
    center.x = MAX(minX, MIN(maxX, center.x));
    center.y = MAX(minY, MIN(maxY, center.y));
    
    self.localVideoView.center = center;
    [gesture setTranslation:CGPointZero inView:self.view];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:0 animations:^{
            CGRect frame = self.localVideoView.frame;
            CGFloat screenW = self.view.bounds.size.width;
            if (CGRectGetMidX(frame) < screenW / 2) {
                frame.origin.x = kSmallVideoMargin;
            } else {
                frame.origin.x = screenW - frame.size.width - kSmallVideoMargin;
            }
            self.localVideoView.frame = frame;
        } completion:nil];
    }
}

#pragma mark - 头像加载

- (void)loadRemoteAvatar
{
    UserEntity *friendInfo = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid:self.remoteUserUid];
    NSString *fileName = friendInfo.userAvatarFileName;
    [RBAvatarView setAvatarWithFileName:fileName uid:self.remoteUserUid onImageView:self.avatarImageView placeholder:nil];
    [RBAvatarView setAvatarWithFileName:fileName uid:self.remoteUserUid onImageView:self.bgAvatarView placeholder:nil];
}


#pragma mark - UI状态更新

- (void)updateUIForCurrentState
{
    CallState state = [CallManager sharedInstance].currentState;
    switch (state) {
        case CallStateOutgoingCalling: [self layoutForOutgoing]; break;
        case CallStateIncomingCalling: [self layoutForIncoming]; break;
        case CallStateConnected:       [self layoutForConnected]; break;
        case CallStateIdle: break;
    }
}

/// 动态设置底部按钮行：移除所有旧的 arrangedSubviews，只添加需要显示的按钮
- (void)setBottomButtons:(NSArray<UIView *> *)buttons
{
    // 移除所有旧的 arrangedSubviews
    for (UIView *v in [self.bottomButtonsStack.arrangedSubviews copy]) {
        [self.bottomButtonsStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    // 添加新的
    for (UIView *btn in buttons) {
        [self.bottomButtonsStack addArrangedSubview:btn];
    }
}

/// 呼出中：[静音] [取消(红)] [免提]（语音）  /  [免提] [取消(红)] [翻转]（视频）
- (void)layoutForOutgoing
{
    NSString *typeStr = (self.callType == CallTypeVideo) ? @"视频" : @"语音";
    self.statusLabel.text = [NSString stringWithFormat:@"正在等待对方接受%@通话邀请...", typeStr];
    self.hangupLabel.text = @"取消";
    self.timerLabel.hidden = YES;
    self.minimizeButton.hidden = NO;
    
    // 显示头像和文字
    self.avatarImageView.hidden = NO;
    self.nameLabel.hidden = NO;
    self.statusLabel.hidden = NO;
    
    if (self.callType == CallTypeVideo) {
        // 视频呼出：摄像头背景 + 头像叠加
        self.bgAvatarView.hidden = YES;
        self.blurOverlay.hidden = YES;
        self.darkOverlay.hidden = YES;
        
        // 按钮：[免提] [取消] [翻转]
        [self setBottomButtons:@[self.speakerContainer, self.hangupContainer, self.cameraContainer]];
    } else {
        // 语音呼出：模糊背景
        // 按钮：[静音] [取消] [免提]
        [self setBottomButtons:@[self.muteContainer, self.hangupContainer, self.speakerContainer]];
    }
    
    [self updateSpeakerButtonState];
}

/// 来电中：[拒绝(红)] ... [接听(绿)]
- (void)layoutForIncoming
{
    NSString *typeStr = (self.callType == CallTypeVideo) ? @"视频" : @"语音";
    self.statusLabel.text = [NSString stringWithFormat:@"邀请你进行%@通话", typeStr];
    self.timerLabel.hidden = YES;
    self.minimizeButton.hidden = NO;
    
    self.avatarImageView.hidden = NO;
    self.nameLabel.hidden = NO;
    self.statusLabel.hidden = NO;
    
    // 按钮：[拒绝] [接听]
    [self setBottomButtons:@[self.rejectContainer, self.acceptContainer]];
    
    if (self.callType == CallTypeVideo) {
        self.bgAvatarView.hidden = NO;
        self.blurOverlay.hidden = NO;
        self.darkOverlay.hidden = NO;
    }

    // 确保最小化按钮在最前，避免被背景或视频层盖住
    [self.view bringSubviewToFront:self.minimizeButton];
    [self.view bringSubviewToFront:self.bottomButtonsStack];
}

/// 通话中：[静音] [挂断(红)] [免提]（语音）  /  [静音] [挂断(红)] [免提] [翻转]（视频）
- (void)layoutForConnected
{
    [[CallSoundManager sharedInstance] stopAll];
    
    NSString *typeStr = (self.callType == CallTypeVideo) ? @"视频通话中" : @"语音通话中";
    self.statusLabel.text = typeStr;
    self.timerLabel.hidden = NO;
    self.minimizeButton.hidden = NO;
    self.hangupLabel.text = @"挂断";
    
    if (self.callType == CallTypeVideo) {
        // 视频通话中：[静音] [挂断] [免提] [翻转]
        [self setBottomButtons:@[self.muteContainer, self.hangupContainer, self.speakerContainer, self.cameraContainer]];
    } else {
        // 语音通话中：[静音] [挂断] [免提]
        [self setBottomButtons:@[self.muteContainer, self.hangupContainer, self.speakerContainer]];
    }
    
    [self updateSpeakerButtonState];
    [self startDurationTimer];
    
    // 语音/视频均确保状态、计时器、按钮在最前，避免被背景或其它视图盖住
    self.statusLabel.hidden = NO;
    self.timerLabel.hidden = NO;
    [self.view bringSubviewToFront:self.statusLabel];
    [self.view bringSubviewToFront:self.timerLabel];
    [self.view bringSubviewToFront:self.minimizeButton];
    [self.view bringSubviewToFront:self.bottomButtonsStack];
    
    if (self.callType == CallTypeVideo) {
        self.avatarImageView.hidden = YES;
        self.nameLabel.hidden = YES;
        self.remoteVideoView.hidden = NO;
        self.bgAvatarView.hidden = YES;
        self.blurOverlay.hidden = YES;
        self.darkOverlay.hidden = YES;
        
        if (!self.isRestoringFromFloat) {
            self.needsAnimateLocalVideoToSmallWindow = YES;
            // 接听时不会再次触发 viewDidAppear，需在此主动执行小窗动画，否则本地画面一直全屏盖住远端和按钮
            __weak typeof(self) wself = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (wself.needsAnimateLocalVideoToSmallWindow && wself.callType == CallTypeVideo && wself.localVideoView) {
                    wself.needsAnimateLocalVideoToSmallWindow = NO;
                    [wself animateLocalVideoToSmallWindow];
                }
            });
        }
    }
}

#pragma mark - 按钮事件

- (void)onHangupTapped
{
    [[CallSoundManager sharedInstance] stopAll];
    [[CallSoundManager sharedInstance] playEndedTone];
    
    CallState state = [CallManager sharedInstance].currentState;
    if (state == CallStateOutgoingCalling) {
        [[CallManager sharedInstance] cancelCall];
    } else {
        [[CallManager sharedInstance] hangupCall];
    }
    [self dismissSelf];
}

- (void)onAcceptTapped
{
    [[CallSoundManager sharedInstance] stopAll];
    // ★ 不再重复调用 setupVideoViews / startLocalCameraPreview
    // viewDidLoad 中已经为视频通话创建了视频视图并启动了本地预览
    [[CallManager sharedInstance] acceptCall];
    [self updateUIForCurrentState];
}

- (void)onRejectTapped
{
    [[CallSoundManager sharedInstance] stopAll];
    [[CallManager sharedInstance] rejectCall];
    [self dismissSelf];
}

- (void)onMuteTapped
{
    self.isMuted = !self.isMuted;
    [[AgoraManager sharedInstance] muteLocalAudio:self.isMuted];
    
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:kBtnIconPointSize weight:UIImageSymbolWeightMedium];
    if (self.isMuted) {
        self.muteButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        [self.muteButton setImage:[UIImage systemImageNamed:@"mic.slash.fill" withConfiguration:config] forState:UIControlStateNormal];
        self.muteLabel.text = @"已静音";
    } else {
        self.muteButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
        [self.muteButton setImage:[UIImage systemImageNamed:@"mic.fill" withConfiguration:config] forState:UIControlStateNormal];
        self.muteLabel.text = @"静音";
    }
}

- (void)onSpeakerTapped
{
    self.isSpeakerOn = !self.isSpeakerOn;
    [[AgoraManager sharedInstance] setEnableSpeakerphone:self.isSpeakerOn];
    [self updateSpeakerButtonState];
}

- (void)updateSpeakerButtonState
{
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:kBtnIconPointSize weight:UIImageSymbolWeightMedium];
    if (self.isSpeakerOn) {
        self.speakerButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        [self.speakerButton setImage:[UIImage systemImageNamed:@"speaker.wave.3.fill" withConfiguration:config] forState:UIControlStateNormal];
        self.speakerLabel.text = @"已开启";
    } else {
        self.speakerButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
        [self.speakerButton setImage:[UIImage systemImageNamed:@"speaker.wave.2.fill" withConfiguration:config] forState:UIControlStateNormal];
        self.speakerLabel.text = @"免提";
    }
}

- (void)onSwitchCameraTapped
{
    [[AgoraManager sharedInstance] switchCamera];
}

- (void)onMinimizeTapped
{
    [self minimizeToFloatingWindow];
}

#pragma mark - CallManagerDelegate

- (void)callManager:(id)manager didChangeState:(CallState)newState
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateUIForCurrentState];
        if (newState == CallStateConnected && self.callType == CallTypeVideo) {
            [[CallPiPManager sharedInstance] attachPiPSourceViewToContainerView:self.view];
        }
    });
}

- (void)callManagerDidRemoteAccept:(id)manager
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[CallSoundManager sharedInstance] stopAll];
        self.statusLabel.text = @"对方已接听，正在连接...";
    });
}

- (void)callManagerDidRemoteReject:(id)manager
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[CallSoundManager sharedInstance] stopAll];
        [[CallSoundManager sharedInstance] playBusyTone];
        NSString *typeStr = (self.callType == CallTypeVideo) ? @"视频" : @"语音";
        self.statusLabel.text = [NSString stringWithFormat:@"对方已拒绝%@通话", typeStr];
        [self dismissSelfAfterDelay:0.5];
    });
}

- (void)callManagerDidRemoteCancel:(id)manager
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[CallSoundManager sharedInstance] stopAll];
        [[CallSoundManager sharedInstance] playEndedTone];
        self.statusLabel.text = @"对方已取消呼叫";
        [self dismissSelfAfterDelay:0.5];
    });
}

- (void)callManagerDidRemoteHangup:(id)manager
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[CallSoundManager sharedInstance] stopAll];
        [[CallSoundManager sharedInstance] playEndedTone];
        
        NSInteger duration = [[CallManager sharedInstance] getCallDuration];
        NSString *durationStr = @"";
        if (duration > 0) {
            durationStr = [NSString stringWithFormat:@"，通话时长 %02ld:%02ld", (long)(duration / 60), (long)(duration % 60)];
        }
        self.statusLabel.text = [NSString stringWithFormat:@"通话已结束%@", durationStr];
        self.statusLabel.hidden = NO;
        [self stopDurationTimer];
        [self dismissSelfAfterDelay:0.5];
    });
}

- (void)callManagerDidTimeout:(id)manager
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[CallSoundManager sharedInstance] stopAll];
        [[CallSoundManager sharedInstance] playBusyTone];
        self.statusLabel.text = @"对方暂时无法接听，请稍后再试";
        [self dismissSelfAfterDelay:0.8];
    });
}

- (void)callManager:(id)manager didOccurError:(NSString *)errorMsg
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[CallSoundManager sharedInstance] stopAll];
        [[CallSoundManager sharedInstance] playEndedTone];
        self.statusLabel.text = errorMsg;
        [self dismissSelfAfterDelay:0.8];
    });
}

#pragma mark - AgoraManagerDelegate

- (void)agoraManager:(id)manager didJoinedOfUid:(NSUInteger)uid
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"【CallVC】远端用户加入：%lu", (unsigned long)uid);
        if (self.callType == CallTypeVideo) {
            self.remoteVideoView.hidden = NO;
            [[AgoraManager sharedInstance] setupRemoteVideoView:self.remoteVideoView forUid:uid];
            [self.view bringSubviewToFront:self.localVideoView];
        }
    });
}

- (void)agoraManager:(id)manager didOfflineOfUid:(NSUInteger)uid
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"【CallVC】远端用户离开：%lu", (unsigned long)uid);
        if ([CallManager sharedInstance].currentState == CallStateConnected) {
            [[CallManager sharedInstance] onRemoteHangup:[CallManager sharedInstance].remoteUserUid];
        }
    });
}

- (void)agoraManager:(id)manager firstRemoteVideoDecodedOfUid:(NSUInteger)uid size:(CGSize)size
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.callType == CallTypeVideo) {
            self.remoteVideoView.hidden = NO;
            [[AgoraManager sharedInstance] setupRemoteVideoView:self.remoteVideoView forUid:uid];
        }
    });
}

- (void)agoraManager:(id)manager didJoinChannel:(NSString *)channel withUid:(NSUInteger)uid
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"【CallVC】✅ 已加入声网频道：%@，uid=%lu", channel, (unsigned long)uid);
        [[AgoraManager sharedInstance] setEnableSpeakerphone:self.isSpeakerOn];
        self.statusLabel.text = (self.callType == CallTypeVideo) ? @"视频通话中" : @"语音通话中";
        self.statusLabel.hidden = NO;
    });
}

- (void)agoraManager:(id)manager didOccurError:(NSInteger)errorCode
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"【CallVC】❌ 声网错误：%ld", (long)errorCode);
        NSString *errorDesc = @"";
        if (errorCode == 109 || errorCode == 110) {
            errorDesc = @"Token无效或已过期";
        } else if (errorCode == -17) {
            errorDesc = @"加入频道被拒绝（常与 Token、AppId、频道名不一致有关）";
        } else if (errorCode == 17) {
            errorDesc = @"已在频道中";
        } else {
            errorDesc = [NSString stringWithFormat:@"错误码:%ld", (long)errorCode];
        }
        self.statusLabel.text = [NSString stringWithFormat:@"音视频连接异常（%@）", errorDesc];
        self.statusLabel.hidden = NO;
        
        // Token / 加入失败：弹窗并提供重试（含 SDK 同步返回的错误码如 -17）
        if (errorCode == 109 || errorCode == 110 || errorCode == -17) {
            NSString *msg = [NSString stringWithFormat:@"%@，请检查网络后重试。", errorDesc];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:msg preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"重试" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[CallManager sharedInstance] retryJoinChannel];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"挂断" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [[CallSoundManager sharedInstance] stopAll];
                [[CallManager sharedInstance] hangupCall];
                [self dismissSelfAfterDelay:0.5];
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    });
}

- (void)agoraManagerTokenWillExpire:(id)manager
{
    NSLog(@"【CallVC】Token 即将过期，刷新中...");
    [[CallManager sharedInstance] refreshTokenIfNeeded];
}

#pragma mark - 计时器

- (void)startDurationTimer
{
    [self stopDurationTimer];
    __weak typeof(self) wself = self;
    self.durationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [wself updateDurationDisplay];
    }];
    [self updateDurationDisplay];
}

- (void)stopDurationTimer
{
    if (self.durationTimer) {
        [self.durationTimer invalidate];
        self.durationTimer = nil;
    }
}

- (void)updateDurationDisplay
{
    NSInteger duration = [[CallManager sharedInstance] getCallDuration];
    NSInteger minutes = duration / 60;
    NSInteger seconds = duration % 60;
    self.timerLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

#pragma mark - 退出

- (void)dismissSelf
{
    [self stopDurationTimer];
    
    if (self.callType == CallTypeVideo) {
        [[AgoraManager sharedInstance] setupLocalVideoView:nil];
    }
    
    if ([CallFloatingManager sharedInstance].isShowing) {
        [[CallFloatingManager sharedInstance] hide];
    }
    
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)dismissSelfAfterDelay:(NSTimeInterval)delay
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismissSelf];
    });
}

@end
