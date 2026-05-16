//
//  CallIncomingPopupManager.m
//  RainbowChat4i
//
//  前台收到音视频来电时显示的顶部卡片弹窗。
//

#import "CallIncomingPopupManager.h"
#import "ViewControllerFactory.h"
#import "CallFloatingManager.h"
#import "CallSoundManager.h"
#import "IMClientManager.h"
#import "FriendsListProvider.h"
#import "UserEntity.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"

@interface CallIncomingPopupManager ()

@property (nonatomic, strong) UIView *popupContainerView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIImageView *bgImageView;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *ignoreButton;
@property (nonatomic, strong) UIButton *rejectButton;
@property (nonatomic, strong) UIButton *acceptButton;

@property (nonatomic, assign) CallType currentCallType;
@property (nonatomic, copy) NSString *remoteUserUid;
@property (nonatomic, copy) NSString *remoteUserNickname;
@property (nonatomic, assign, readwrite) BOOL isShowing;
@property (nonatomic, assign) CGFloat popupOriginalY;

@end

@implementation CallIncomingPopupManager

+ (instancetype)sharedInstance
{
    static CallIncomingPopupManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CallIncomingPopupManager alloc] init];
    });
    return instance;
}

#pragma mark - Public

- (void)showWithCallType:(CallType)callType
           remoteUserUid:(NSString *)remoteUserUid
      remoteUserNickname:(NSString *)remoteUserNickname
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isShowing) {
            [self hide];
        }
        
        self.currentCallType = callType;
        self.remoteUserUid = remoteUserUid ?: @"";
        self.remoteUserNickname = remoteUserNickname ?: @"";
        self.isShowing = YES;

        // 来电时播放铃声（循环），效果与旧版全屏来电一致
        [[CallSoundManager sharedInstance] playRingtone];
        
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat cardWidth = screenW - 24.0;
        CGFloat cardHeight = 132.0;
        
        CGFloat topInset = 0;
        UIWindow *baseWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive ||
                    scene.activationState == UISceneActivationStateForegroundInactive) {
                    for (UIWindow *w in scene.windows) {
                        if (w.isKeyWindow) {
                            baseWindow = w;
                            break;
                        }
                    }
                    if (baseWindow) { break; }
                }
            }
        }
        if (!baseWindow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            baseWindow = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
        }
        if (!baseWindow) {
            baseWindow = [UIApplication sharedApplication].windows.firstObject;
        }
        if (@available(iOS 11.0, *)) {
            topInset = baseWindow.safeAreaInsets.top;
        }
        
        CGFloat originX = (screenW - cardWidth) / 2.0;
        CGRect frame = CGRectMake(originX, topInset + 8.0, cardWidth, cardHeight);
        self.popupOriginalY = frame.origin.y;
        
        // 容器视图直接加在当前 keyWindow 上，这样毛玻璃能看到下面的内容
        self.popupContainerView = [[UIView alloc] initWithFrame:frame];
        self.popupContainerView.backgroundColor = [UIColor clearColor];
        self.popupContainerView.clipsToBounds = NO;
        [baseWindow addSubview:self.popupContainerView];
        
        self.contentView = [[UIView alloc] initWithFrame:self.popupContainerView.bounds];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.contentView.layer.cornerRadius = 24.0;
        self.contentView.clipsToBounds = YES;
        [self.popupContainerView addSubview:self.contentView];

        // 背景使用头像放大后的虚化图
        self.bgImageView = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
        self.bgImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.bgImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.bgImageView.clipsToBounds = YES;
        self.bgImageView.image = [UIImage imageNamed:@"default_avatar_70"];
        [self.contentView addSubview:self.bgImageView];

        // 液态玻璃背景（毛玻璃 + 轻微暗色调）
        UIBlurEffect *blurEffect;
        if (@available(iOS 13.0, *)) {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
        } else {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        }
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = self.contentView.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.layer.cornerRadius = 24.0;
        blurView.clipsToBounds = YES;
        [self.contentView addSubview:blurView];

        // 轻微暗色蒙层，让前景信息更突出，同时还能看清头像轮廓
        UIView *darkOverlay = [[UIView alloc] initWithFrame:self.contentView.bounds];
        darkOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        darkOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.15];
        darkOverlay.layer.cornerRadius = 24.0;
        darkOverlay.clipsToBounds = YES;
        [self.contentView addSubview:darkOverlay];
        
        // 头像
        CGFloat avatarSize = 50.0;
        self.avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(16.0, 18.0, avatarSize, avatarSize)];
        self.avatarView.layer.cornerRadius = 8.0;
        self.avatarView.clipsToBounds = YES;
        self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
        self.avatarView.image = [UIImage imageNamed:@"default_avatar_70"];
        [self.contentView addSubview:self.avatarView];
        
        // 文本
        CGFloat textStartX = CGRectGetMaxX(self.avatarView.frame) + 12.0;
        CGFloat textWidth = cardWidth - textStartX - 16.0;
        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(textStartX, 18.0, textWidth, 22.0)];
        self.nameLabel.textColor = [UIColor whiteColor];
        self.nameLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        self.nameLabel.text = self.remoteUserNickname.length > 0 ? self.remoteUserNickname : self.remoteUserUid;
        [self.contentView addSubview:self.nameLabel];
        
        self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(textStartX, CGRectGetMaxY(self.nameLabel.frame) + 4.0, textWidth, 18.0)];
        self.subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
        self.subtitleLabel.font = [UIFont systemFontOfSize:13];
        self.subtitleLabel.text = (callType == CallTypeVideo ? @"邀请你视频通话" : @"邀请你语音通话");
        [self.contentView addSubview:self.subtitleLabel];

        // 加载远端头像（用于头像和背景）
        [self loadRemoteAvatarForPopup];
        
        // 忽略按钮（灰色 pill）
        CGFloat ignoreHeight = 34.0;
        self.ignoreButton = [UIButton buttonWithType:UIButtonTypeCustom];
        // 先用 0 宽度占位，后面根据文字和图标实际宽度调整
        self.ignoreButton.frame = CGRectMake(16.0,
                                             cardHeight - ignoreHeight - 14.0,
                                             0,
                                             ignoreHeight);
        self.ignoreButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        self.ignoreButton.layer.cornerRadius = ignoreHeight / 2.0;
        self.ignoreButton.clipsToBounds = YES;
        // 图标和文字尺寸
        CGFloat horizontalPadding = 14.0;
        CGFloat innerSpacing = 6.0;
        CGFloat bellSize = 22.0; // 明显大于文字，接近系统来电样式
        CGFloat bellX = horizontalPadding;
        CGFloat bellY = (ignoreHeight - bellSize) / 2.0;
        UIImageView *bellView = [[UIImageView alloc] initWithFrame:CGRectMake(bellX, bellY, bellSize, bellSize)];
        bellView.image = [[UIImage imageNamed:@"call_ignore_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        bellView.tintColor = [UIColor whiteColor];
        bellView.contentMode = UIViewContentModeScaleAspectFit;
        [self.ignoreButton addSubview:bellView];

        // 文字
        NSString *ignoreText = @"忽略";
        UIFont *ignoreFont = [UIFont systemFontOfSize:14];
        CGSize textSize = [ignoreText sizeWithAttributes:@{NSFontAttributeName: ignoreFont}];
        CGFloat labelX = CGRectGetMaxX(bellView.frame) + innerSpacing;
        CGFloat labelWidth = textSize.width;
        UILabel *ignoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelX, 0, labelWidth, ignoreHeight)];
        ignoreLabel.text = @"忽略";
        ignoreLabel.font = ignoreFont;
        ignoreLabel.textColor = [UIColor whiteColor];
        ignoreLabel.textAlignment = NSTextAlignmentLeft;
        [self.ignoreButton addSubview:ignoreLabel];

        // 根据图标+文字内容动态调整按钮宽度
        CGFloat buttonWidth = horizontalPadding + bellSize + innerSpacing + labelWidth + horizontalPadding;
        CGRect btnFrame = self.ignoreButton.frame;
        btnFrame.size.width = buttonWidth;
        self.ignoreButton.frame = btnFrame;
        [self.ignoreButton addTarget:self action:@selector(onIgnoreTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:self.ignoreButton];
        
        // 拒绝 / 接听圆形按钮
        CGFloat circleSize = 48.0;
        CGFloat spacing = 18.0;
        CGFloat rightMargin = 22.0;
        CGFloat acceptX = cardWidth - rightMargin - circleSize;
        CGFloat rejectX = acceptX - spacing - circleSize;
        CGFloat circleY = cardHeight - circleSize - 14.0;
        
        self.rejectButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.rejectButton.frame = CGRectMake(rejectX, circleY, circleSize, circleSize);
        self.rejectButton.backgroundColor = [UIColor colorWithRed:0.95 green:0.22 blue:0.21 alpha:1.0];
        self.rejectButton.layer.cornerRadius = circleSize / 2.0;
        self.rejectButton.clipsToBounds = YES;
        UIImageSymbolConfiguration *rejectConfig = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
        UIImage *rejectImg = [UIImage systemImageNamed:@"phone.down.fill" withConfiguration:rejectConfig];
        [self.rejectButton setImage:rejectImg forState:UIControlStateNormal];
        self.rejectButton.tintColor = [UIColor whiteColor];
        [self.rejectButton addTarget:self action:@selector(onRejectTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:self.rejectButton];
        
        self.acceptButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.acceptButton.frame = CGRectMake(acceptX, circleY, circleSize, circleSize);
        self.acceptButton.backgroundColor = [UIColor colorWithRed:0.30 green:0.85 blue:0.39 alpha:1.0];
        self.acceptButton.layer.cornerRadius = circleSize / 2.0;
        self.acceptButton.clipsToBounds = YES;
        UIImageSymbolConfiguration *acceptConfig = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
        UIImage *acceptImg = [UIImage systemImageNamed:@"phone.fill" withConfiguration:acceptConfig];
        [self.acceptButton setImage:acceptImg forState:UIControlStateNormal];
        self.acceptButton.tintColor = [UIColor whiteColor];
        [self.acceptButton addTarget:self action:@selector(onAcceptTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:self.acceptButton];
        
        // 整体点击：进入全屏通话界面（不立即接听）
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onCardTapped)];
        tap.cancelsTouchesInView = NO;
        tap.delegate = self;
        [self.contentView addGestureRecognizer:tap];

        // 上下拖动手势：可上下滑动卡片，向上拉到一定距离自动最小化为浮窗
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPopupPan:)];
        pan.delegate = self;
        [self.contentView addGestureRecognizer:pan];
        
        self.popupContainerView.alpha = 0.0;
        [UIView animateWithDuration:0.25
                         animations:^{
            self.popupContainerView.alpha = 1.0;
        }];
        
        // 监听 CallManager 状态
        [CallManager sharedInstance].delegate = self;
    });
}

- (void)hideWithCompletion:(dispatch_block_t)completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.isShowing && self.popupContainerView == nil) {
            if (completion) {
                completion();
            }
            return;
        }
        self.isShowing = NO;
        
        [UIView animateWithDuration:0.2 animations:^{
            self.popupContainerView.alpha = 0.0;
        } completion:^(BOOL finished) {
            // 停止来电铃声
            [[CallSoundManager sharedInstance] stopAll];

            [self.popupContainerView removeFromSuperview];
            self.popupContainerView = nil;
            self.contentView = nil;
            self.avatarView = nil;
            self.nameLabel = nil;
            self.subtitleLabel = nil;
            self.bgImageView = nil;
            self.ignoreButton = nil;
            self.rejectButton = nil;
            self.acceptButton = nil;
            
            if ([CallManager sharedInstance].delegate == self) {
                [CallManager sharedInstance].delegate = nil;
            }
            
            if (completion) {
                completion();
            }
        }];
    });
}

- (void)hide
{
    [self hideWithCompletion:nil];
}

#pragma mark - 头像加载（用于背景虚化）

- (void)loadRemoteAvatarForPopup
{
    if (self.remoteUserUid.length == 0) return;
    FriendsListProvider *friendsProvider = [[IMClientManager sharedInstance] getFriendsListProvider];
    UserEntity *friendInfo = [friendsProvider getFriendInfoByUid:self.remoteUserUid];
    NSString *fileName = friendInfo.userAvatarFileName;
    [RBAvatarView setAvatarWithFileName:fileName uid:self.remoteUserUid onImageView:self.avatarView placeholder:nil];
    [RBAvatarView setAvatarWithFileName:fileName uid:self.remoteUserUid onImageView:self.bgImageView placeholder:nil];
}

#pragma mark - Actions

- (void)onIgnoreTapped
{
    // 忽略：最小化为通话浮窗（如果仍在通话流程中）
    CallType callType = self.currentCallType;
    NSString *uid = self.remoteUserUid;
    NSString *nickname = self.remoteUserNickname;
    
    [self hideWithCompletion:^{
        if (![[CallManager sharedInstance] isInCall] || uid.length == 0) {
            return;
        }
        
        [[CallFloatingManager sharedInstance] showWithCallType:callType
                                                remoteUserUid:uid
                                           remoteUserNickname:nickname];
    }];
}

- (void)onRejectTapped
{
    [[CallManager sharedInstance] rejectCall];
    [self hide];
}

- (void)onAcceptTapped
{
    CallType callType = self.currentCallType;
    NSString *uid = self.remoteUserUid;
    NSString *nickname = self.remoteUserNickname;
    
    if (uid.length == 0) {
        return;
    }
    
    [self hideWithCompletion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [ViewControllerFactory goCallViewController:uid
                                      remoteUserNickname:nickname
                                                callType:callType
                                                isCaller:NO];
            
            // 确保 CallViewController 完成初始化后再接听
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CallManager sharedInstance] acceptCall];
            });
        });
    }];
}

- (void)onCardTapped
{
    // 点击整块卡片：仅进入全屏来电界面，不立即接听
    CallType callType = self.currentCallType;
    NSString *uid = self.remoteUserUid;
    NSString *nickname = self.remoteUserNickname;
    
    if (uid.length == 0) {
        return;
    }
    
    [self hideWithCompletion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [ViewControllerFactory goCallViewController:uid
                                      remoteUserNickname:nickname
                                                callType:callType
                                                isCaller:NO];
        });
    }];
}

#pragma mark - CallManagerDelegate

- (void)callManager:(id)manager didChangeState:(CallState)newState
{
    if (newState == CallStateIdle || newState == CallStateConnected) {
        [self hide];
    }
}

- (void)callManagerDidRemoteCancel:(id)manager
{
    [self hide];
}

- (void)callManagerDidRemoteHangup:(id)manager
{
    [self hide];
}

- (void)callManagerDidRemoteReject:(id)manager
{
    [self hide];
}

- (void)callManagerDidTimeout:(id)manager
{
    [self hide];
}

- (void)callManager:(id)manager didOccurError:(NSString *)errorMsg
{
    [self hide];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    // 如果触摸发生在按钮（接听/拒绝/忽略）上，则不触发整卡片点击手势
    UIView *view = touch.view;
    while (view && view != self.contentView) {
        if ([view isKindOfClass:[UIButton class]]) {
            return NO;
        }
        view = view.superview;
    }
    return YES;
}

#pragma mark - 弹窗拖拽

- (void)onPopupPan:(UIPanGestureRecognizer *)gesture
{
    if (!self.popupContainerView) return;
    UIView *superview = self.popupContainerView.superview;
    if (!superview) return;

    CGPoint translation = [gesture translationInView:superview];

    if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat newY = self.popupOriginalY + translation.y;
        // 允许向上最多拖 80pt，向下最多拖 40pt
        CGFloat minY = self.popupOriginalY - 280.0;
        CGFloat maxY = self.popupOriginalY + 640.0;
        if (newY < minY) newY = minY;
        if (newY > maxY) newY = maxY;

        CGRect frame = self.popupContainerView.frame;
        frame.origin.y = newY;
        self.popupContainerView.frame = frame;
    } else if (gesture.state == UIGestureRecognizerStateEnded ||
               gesture.state == UIGestureRecognizerStateCancelled) {
        CGFloat currentY = self.popupContainerView.frame.origin.y;
        CGFloat velocityY = [gesture velocityInView:superview].y;
        CGFloat minimizeThresholdY = self.popupOriginalY - 40.0;

        if (currentY <= minimizeThresholdY || velocityY < -600.0) {
            // 触发最小化：与点击「忽略」行为一致
            [self onIgnoreTapped];
        } else {
            // 回弹到原始位置
            [UIView animateWithDuration:0.2 animations:^{
                CGRect frame = self.popupContainerView.frame;
                frame.origin.y = self.popupOriginalY;
                self.popupContainerView.frame = frame;
            }];
        }
    }
}

@end

