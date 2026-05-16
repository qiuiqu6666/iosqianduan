//
//  CallFloatingManager.m
//  RainbowChat4i
//
//  通话浮窗管理器实现。
//

#import "CallFloatingManager.h"
#import "CallManager.h"
#import "AgoraManager.h"
#import "CallSoundManager.h"
#import "CallViewController.h"
#import "ViewControllerFactory.h"
#import "IMClientManager.h"
#import "FileDownloadHelper.h"
#import "Default.h"

/// 视频浮窗尺寸
static const CGFloat kFloatVideoWidth   = 110.0;
static const CGFloat kFloatVideoHeight  = 150.0;

/// 语音浮窗尺寸
static const CGFloat kFloatVoiceWidth   = 70.0;
static const CGFloat kFloatVoiceHeight  = 70.0;

/// 浮窗圆角
static const CGFloat kFloatCornerRadius = 12.0;

/// 浮窗边距
static const CGFloat kFloatMargin       = 8.0;

/// 获取当前 keyWindow（与 ViewControllerFactory 一致，兼容 iOS 13+ 多 Scene）
static UIWindow * _Nullable keyWindowForFloating(void)
{
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive ||
                scene.activationState == UISceneActivationStateForegroundInactive) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                if (window) break;
            }
        }
        if (!window) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                if (window) break;
            }
        }
    }
    if (!window) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    }
    if (!window) {
        window = [UIApplication sharedApplication].windows.firstObject;
    }
    return window;
}

@interface CallFloatingManager () <CallManagerDelegate, AgoraManagerDelegate>

@property (nonatomic, strong) UIWindow *floatingWindow;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *videoView;          ///< 视频渲染视图
@property (nonatomic, strong) UIImageView *avatarView;    ///< 语音头像
@property (nonatomic, strong) UILabel *timerLabel;        ///< 通话时长
@property (nonatomic, strong) UIView *greenDot;           ///< 通话中指示灯

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) CallType currentCallType;
@property (nonatomic, copy) NSString *remoteUserUid;
@property (nonatomic, copy) NSString *remoteUserNickname;
@property (nonatomic, assign, readwrite) BOOL isShowing;

@end

@implementation CallFloatingManager

#pragma mark - 单例

+ (instancetype)sharedInstance
{
    static CallFloatingManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CallFloatingManager alloc] init];
    });
    return instance;
}

#pragma mark - 显示浮窗

- (void)showWithCallType:(CallType)callType
           remoteUserUid:(NSString *)remoteUserUid
      remoteUserNickname:(NSString *)remoteUserNickname
{
    if (self.isShowing) {
        [self hide];
    }
    
    self.currentCallType = callType;
    self.remoteUserUid = remoteUserUid;
    self.remoteUserNickname = remoteUserNickname;
    self.isShowing = YES;
    
    // 计算浮窗尺寸
    CGFloat width, height;
    if (callType == CallTypeVideo) {
        width = kFloatVideoWidth;
        height = kFloatVideoHeight;
    } else {
        width = kFloatVoiceWidth;
        height = kFloatVoiceHeight;
    }
    
    // 计算浮窗初始位置（屏幕右上角），使用与 ViewControllerFactory 一致的 keyWindow 取 safeArea
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat topInset = 0;
    if (@available(iOS 11.0, *)) {
        UIWindow *keyWin = keyWindowForFloating();
        if (keyWin) topInset = keyWin.safeAreaInsets.top;
    }
    
    CGRect frame = CGRectMake(screenW - width - kFloatMargin, topInset + 60, width, height);
    
    // 创建浮窗 UIWindow
    self.floatingWindow = [[UIWindow alloc] initWithFrame:frame];
    self.floatingWindow.windowLevel = UIWindowLevelAlert + 100;
    self.floatingWindow.backgroundColor = [UIColor clearColor];
    self.floatingWindow.clipsToBounds = NO;
    
    // 必须给 UIWindow 一个 rootViewController
    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    rootVC.view.frame = CGRectMake(0, 0, width, height);
    self.floatingWindow.rootViewController = rootVC;
    
    // 内容视图
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    self.contentView.backgroundColor = [UIColor colorWithRed:30/255.0 green:30/255.0 blue:40/255.0 alpha:1.0];
    self.contentView.layer.cornerRadius = kFloatCornerRadius;
    self.contentView.clipsToBounds = YES;
    
    // 阴影（加在 rootVC.view 上，因为 contentView clipsToBounds）
    rootVC.view.layer.shadowColor = [UIColor blackColor].CGColor;
    rootVC.view.layer.shadowOffset = CGSizeMake(0, 4);
    rootVC.view.layer.shadowOpacity = 0.4;
    rootVC.view.layer.shadowRadius = 10;
    
    [rootVC.view addSubview:self.contentView];
    
    if (callType == CallTypeVideo) {
        [self setupVideoFloating:width height:height];
    } else {
        [self setupVoiceFloating:width height:height];
    }
    
    // 手势
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onFloatingTapped)];
    [self.contentView addGestureRecognizer:tap];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onFloatingPan:)];
    [self.contentView addGestureRecognizer:pan];
    
    // 显示浮窗（带弹入动画）
    self.floatingWindow.transform = CGAffineTransformMakeScale(0.5, 0.5);
    self.floatingWindow.alpha = 0;
    self.floatingWindow.hidden = NO;
    
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
        self.floatingWindow.transform = CGAffineTransformIdentity;
        self.floatingWindow.alpha = 1.0;
    } completion:nil];
    
    // 开始计时
    [self startTimer];
    
    // 接管代理
    [CallManager sharedInstance].delegate = self;
    [AgoraManager sharedInstance].delegate = self;
}

#pragma mark - 视频浮窗内容

- (void)setupVideoFloating:(CGFloat)width height:(CGFloat)height
{
    // 视频渲染视图
    self.videoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    self.videoView.backgroundColor = [UIColor blackColor];
    [self.contentView addSubview:self.videoView];
    
    // 根据通话状态决定显示本地或远端视频
    CallState state = [CallManager sharedInstance].currentState;
    NSUInteger remoteUid = [AgoraManager sharedInstance].lastRemoteUid;
    
    if (state == CallStateConnected && remoteUid > 0) {
        // 已接通：显示远端视频
        [[AgoraManager sharedInstance] setupRemoteVideoView:self.videoView forUid:remoteUid];
    } else {
        // 未接通（呼出中）：显示本地摄像头预览
        [[AgoraManager sharedInstance] setupLocalVideoView:self.videoView];
    }
    
    // 底部时长标签（半透明背景）
    self.timerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, height - 22, width, 22)];
    self.timerLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightMedium];
    self.timerLabel.textColor = [UIColor whiteColor];
    self.timerLabel.textAlignment = NSTextAlignmentCenter;
    self.timerLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    [self.contentView addSubview:self.timerLabel];
    
    // 绿色通话指示边框
    self.contentView.layer.borderColor = [UIColor colorWithRed:0.30 green:0.85 blue:0.39 alpha:1.0].CGColor;
    self.contentView.layer.borderWidth = 2.0;
}

#pragma mark - 语音浮窗内容

- (void)setupVoiceFloating:(CGFloat)width height:(CGFloat)height
{
    // 绿色背景
    self.contentView.backgroundColor = [UIColor colorWithRed:0.30 green:0.85 blue:0.39 alpha:1.0];
    
    // 通话图标
    CGFloat iconSize = 28;
    UIImageView *phoneIcon = [[UIImageView alloc] initWithFrame:CGRectMake((width - iconSize) / 2, 12, iconSize, iconSize)];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    phoneIcon.image = [UIImage systemImageNamed:@"phone.fill" withConfiguration:config];
    phoneIcon.tintColor = [UIColor whiteColor];
    phoneIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:phoneIcon];
    
    // 时长标签
    self.timerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, iconSize + 18, width, 16)];
    self.timerLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    self.timerLabel.textColor = [UIColor whiteColor];
    self.timerLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.timerLabel];
    
    // 呼吸动画（脉冲效果）
    [self startPulseAnimation];
}

- (void)startPulseAnimation
{
    // 给整个浮窗添加脉冲动画
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @(1.0);
    pulse.toValue = @(1.05);
    pulse.duration = 1.0;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.contentView.layer addAnimation:pulse forKey:@"pulse"];
}

#pragma mark - 隐藏浮窗

- (void)hide
{
    if (!self.isShowing) return;
    
    [self stopTimer];
    
    [UIView animateWithDuration:0.2 animations:^{
        self.floatingWindow.alpha = 0;
        self.floatingWindow.transform = CGAffineTransformMakeScale(0.3, 0.3);
    } completion:^(BOOL finished) {
        self.floatingWindow.hidden = YES;
        self.floatingWindow.rootViewController = nil;
        self.floatingWindow = nil;
        self.contentView = nil;
        self.videoView = nil;
        self.avatarView = nil;
        self.timerLabel = nil;
        self.greenDot = nil;
        self.isShowing = NO;
    }];
}

#pragma mark - 手势处理

/// 点击浮窗：恢复全屏通话界面
- (void)onFloatingTapped
{
    if (![CallManager sharedInstance].isInCall) {
        [self hide];
        return;
    }
    
    // 隐藏浮窗前，解除本地与远端视频绑定（P2-1）
    if (self.currentCallType == CallTypeVideo) {
        NSUInteger lastRemoteUid = [AgoraManager sharedInstance].lastRemoteUid;
        if (lastRemoteUid > 0) {
            [[AgoraManager sharedInstance] setupRemoteVideoView:nil forUid:lastRemoteUid];
        }
        [[AgoraManager sharedInstance] setupLocalVideoView:nil];
    }
    
    [self stopTimer];
    self.floatingWindow.hidden = YES;
    self.isShowing = NO;
    
    // 打开全屏通话界面
    CallViewController *vc = [[CallViewController alloc] initWithCallType:self.currentCallType
                                                            remoteUserUid:self.remoteUserUid
                                                       remoteUserNickname:self.remoteUserNickname
                                                                 isCaller:[CallManager sharedInstance].isCaller];
    vc.isRestoringFromFloat = YES;
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    
    // 使用可靠的 topMostViewController 获取顶层 VC
    UIViewController *topVC = [ViewControllerFactory topMostViewController];
    
    if (topVC == nil) {
        NSLog(@"【CallFloatingManager】⚠️ topMostViewController 返回 nil，无法恢复通话界面！");
        return;
    }
    
    if (topVC.navigationController) {
        [topVC.navigationController pushViewController:vc animated:YES];
    } else if ([topVC isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)topVC pushViewController:vc animated:YES];
    } else if ([topVC isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabVC = (UITabBarController *)topVC;
        UINavigationController *navVC = (UINavigationController *)tabVC.selectedViewController;
        if ([navVC isKindOfClass:[UINavigationController class]]) {
            [navVC pushViewController:vc animated:YES];
        } else {
            [topVC presentViewController:vc animated:YES completion:nil];
        }
    } else {
        [topVC presentViewController:vc animated:YES completion:nil];
    }
    
    // 清理浮窗资源
    self.floatingWindow.rootViewController = nil;
    self.floatingWindow = nil;
    self.contentView = nil;
    self.videoView = nil;
    self.avatarView = nil;
    self.timerLabel = nil;
    self.greenDot = nil;
}

/// 拖拽浮窗
- (void)onFloatingPan:(UIPanGestureRecognizer *)gesture
{
    CGPoint translation = [gesture translationInView:gesture.view.window];
    CGRect frame = self.floatingWindow.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    
    // 边界限制（safeArea 与 show 时一致，使用 keyWindowForFloating）
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    CGFloat topInset = 0;
    if (@available(iOS 11.0, *)) {
        UIWindow *keyWin = keyWindowForFloating();
        if (keyWin) topInset = keyWin.safeAreaInsets.top;
    }
    
    frame.origin.x = MAX(kFloatMargin, MIN(screenW - frame.size.width - kFloatMargin, frame.origin.x));
    frame.origin.y = MAX(topInset + kFloatMargin, MIN(screenH - frame.size.height - kFloatMargin - 40, frame.origin.y));
    
    self.floatingWindow.frame = frame;
    [gesture setTranslation:CGPointZero inView:gesture.view.window];
    
    // 松手后吸附到最近的屏幕边缘
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:0 animations:^{
            CGRect f = self.floatingWindow.frame;
            if (CGRectGetMidX(f) < screenW / 2) {
                f.origin.x = kFloatMargin;
            } else {
                f.origin.x = screenW - f.size.width - kFloatMargin;
            }
            self.floatingWindow.frame = f;
        } completion:nil];
    }
}

#pragma mark - 计时器

- (void)startTimer
{
    [self stopTimer];
    __weak typeof(self) wself = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [wself updateTimer];
    }];
    [self updateTimer];
}

- (void)stopTimer
{
    [self.timer invalidate];
    self.timer = nil;
}

- (void)updateTimer
{
    NSInteger duration = [[CallManager sharedInstance] getCallDuration];
    NSInteger min = duration / 60;
    NSInteger sec = duration % 60;
    self.timerLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)min, (long)sec];
}

#pragma mark - CallManagerDelegate

- (void)callManager:(id)manager didChangeState:(CallState)newState
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (newState == CallStateIdle) {
            [self hide];
        }
    });
}

- (void)callManagerDidRemoteHangup:(id)manager
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[CallSoundManager sharedInstance] stopAll];
        [[CallSoundManager sharedInstance] playEndedTone];
        [self hide];
    });
}

- (void)callManagerDidRemoteCancel:(id)manager
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[CallSoundManager sharedInstance] stopAll];
        [[CallSoundManager sharedInstance] playEndedTone];
        [self hide];
    });
}

- (void)callManagerDidTimeout:(id)manager
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[CallSoundManager sharedInstance] stopAll];
        [self hide];
    });
}

- (void)callManager:(id)manager didOccurError:(NSString *)errorMsg
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[CallSoundManager sharedInstance] stopAll];
        [self hide];
    });
}

#pragma mark - AgoraManagerDelegate

- (void)agoraManager:(id)manager didJoinedOfUid:(NSUInteger)uid
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.currentCallType == CallTypeVideo && self.videoView) {
            // 远端用户加入后，切换浮窗显示远端视频（先清除本地预览）
            [[AgoraManager sharedInstance] setupLocalVideoView:nil];
            [[AgoraManager sharedInstance] setupRemoteVideoView:self.videoView forUid:uid];
        }
    });
}

- (void)agoraManager:(id)manager didOfflineOfUid:(NSUInteger)uid
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([CallManager sharedInstance].currentState == CallStateConnected) {
            [[CallManager sharedInstance] onRemoteHangup:[CallManager sharedInstance].remoteUserUid];
        }
    });
}

- (void)agoraManager:(id)manager didJoinChannel:(NSString *)channel withUid:(NSUInteger)uid
{
    // 浮窗模式下不需要特殊处理
}

- (void)agoraManager:(id)manager didOccurError:(NSInteger)errorCode
{
    NSLog(@"【CallFloatingManager】声网错误：%ld", (long)errorCode);
}

- (void)agoraManagerTokenWillExpire:(id)manager
{
    [[CallManager sharedInstance] refreshTokenIfNeeded];
}

@end
