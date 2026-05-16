//telegram @wz662
#import "RBAvatarView.h"
#import "FileDownloadHelper.h"
#import "AvatarHelper.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const void *kRBAvatarViewKey = &kRBAvatarViewKey;

@interface RBAvatarView ()
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *videoContainer;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *observedPlayerItem;
@property (nonatomic, strong) id playerEndObserver;
/** 上次设置的 fileName/uid，用于从预览返回时恢复视频播放 */
@property (nonatomic, copy) NSString *lastAvatarFileName;
@property (nonatomic, copy) NSString *lastAvatarUid;
@property (nonatomic, assign) BOOL isRestoringVideo;
/** 为 YES 时动态头像只显示静态首帧，不播放视频（如消息对话列表） */
@property (nonatomic, assign) BOOL staticPreviewOnly;
/** 每次 setAvatar 递增；异步完成时须与此刻一致才赋图，避免 cell 复用后旧请求覆盖新 uid */
@property (nonatomic, assign) NSUInteger avatarLoadGeneration;
@end

@implementation RBAvatarView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    _cornerRadius = 0;
    _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    [self addSubview:_imageView];

    _videoContainer = [[UIView alloc] initWithFrame:self.bounds];
    _videoContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _videoContainer.backgroundColor = [UIColor clearColor]; // 加载中/失败时透出底层占位图，避免黑块
    _videoContainer.hidden = YES;
    [self addSubview:_videoContainer];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.layer.cornerRadius != _cornerRadius) {
        self.layer.cornerRadius = _cornerRadius;
        self.layer.masksToBounds = YES;
    }
    for (CALayer *s in _videoContainer.layer.sublayers) {
        s.frame = _videoContainer.bounds;
    }
}

- (void)setPlaceholderImage:(UIImage *)placeholderImage
{
    _placeholderImage = placeholderImage;
    if (_imageView.image == nil && _videoContainer.hidden) {
        _imageView.image = placeholderImage;
    }
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    _cornerRadius = cornerRadius;
    self.layer.cornerRadius = cornerRadius;
    self.layer.masksToBounds = (cornerRadius > 0);
}

- (void)setAvatarWithFileName:(NSString *)fileName uid:(NSString *)uid
{
    [self stopVideo];
    _videoContainer.hidden = YES;
    _imageView.hidden = NO;
    _lastAvatarFileName = [fileName copy];
    _lastAvatarUid = [uid copy];

    self.avatarLoadGeneration++;
    NSUInteger loadToken = self.avatarLoadGeneration;

    if (uid.length == 0) {
        _imageView.image = _placeholderImage;
        return;
    }

    // 冷启动等场景下可能只有 uid 没有 fileName（如好友列表尚未加载），仍优先从本地缓存按 uid 加载
    if (fileName.length == 0) {
        _imageView.image = _placeholderImage;
        __weak typeof(self) wself = self;
        [FileDownloadHelper loadUserAvatarWithUID:uid logTag:@"RBAvatarView-UID" complete:^(BOOL sucess, UIImage *img) {
            if (wself == nil) return;
            if (wself.avatarLoadGeneration != loadToken) return;
            if (sucess && img != nil) {
                wself.imageView.image = img;
            } else {
                wself.imageView.image = wself.placeholderImage;
            }
        } donotLoadFromDisk:NO];
        return;
    }

    // 不支持视频头像，仅显示占位
    if ([FileDownloadHelper isVideoAvatarFileName:fileName]) {
        _imageView.image = _placeholderImage;
        return;
    }

    __weak typeof(self) wself = self;
    [FileDownloadHelper loadUserAvatarWithFileName:fileName uid:uid logTag:@"RBAvatarView" complete:^(BOOL sucess, UIImage *img) {
        if (wself == nil) return;
        if (wself.avatarLoadGeneration != loadToken) return;
        if (sucess && img != nil) {
            wself.imageView.image = img;
        } else {
            wself.imageView.image = wself.placeholderImage;
        }
    }];
}

- (void)playVideoWithURL:(NSURL *)url
{
    [self stopVideo];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    _player = [AVPlayer playerWithPlayerItem:item];
    _player.muted = YES;
    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:_player];
    layer.frame = _videoContainer.bounds;
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    layer.backgroundColor = [UIColor clearColor].CGColor;
    for (CALayer *s in [_videoContainer.layer.sublayers copy]) {
        [s removeFromSuperlayer];
    }
    [_videoContainer.layer addSublayer:layer];

    __weak typeof(self) wself = self;
    _playerEndObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:item queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [wself.player seekToTime:kCMTimeZero];
        [wself.player play];
    }];

    _observedPlayerItem = item;
    [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    [_player play];
}

- (void)stopVideo
{
    if (_playerEndObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_playerEndObserver];
        _playerEndObserver = nil;
    }
    if (_observedPlayerItem) {
        [_observedPlayerItem removeObserver:self forKeyPath:@"status"];
        _observedPlayerItem = nil;
    }
    [_player pause];
    _player = nil;
    for (CALayer *s in [_videoContainer.layer.sublayers copy]) {
        [s removeFromSuperlayer];
    }
}

- (void)pauseVideo
{
    if (_player) {
        [_player pause];
    }
}

- (void)resumeVideo
{
    if (_player) {
        [_player play];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"status"] && [object isKindOfClass:[AVPlayerItem class]]) {
        AVPlayerItem *item = (AVPlayerItem *)object;
        if (item.status == AVPlayerItemStatusFailed) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.videoContainer.hidden = YES;
                self.imageView.hidden = NO;
                self.imageView.image = self.placeholderImage;
                [self stopVideo];
            });
        }
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window == nil) {
        [self stopVideo];
    }
}

- (void)dealloc
{
    [self stopVideo];
}

#pragma mark - 在已有 UIImageView 上挂载

+ (void)setAvatarWithFileName:(NSString *)fileName uid:(NSString *)uid onImageView:(UIImageView *)imageView placeholder:(UIImage *)placeholder
{
    [self setAvatarWithFileName:fileName uid:uid onImageView:imageView placeholder:placeholder staticPreviewOnly:NO];
}

+ (void)setAvatarWithFileName:(NSString *)fileName uid:(NSString *)uid onImageView:(UIImageView *)imageView placeholder:(UIImage *)placeholder staticPreviewOnly:(BOOL)staticPreviewOnly
{
    if (imageView == nil) return;
    RBAvatarView *avatarView = objc_getAssociatedObject(imageView, kRBAvatarViewKey);
    if (avatarView == nil) {
        avatarView = [[RBAvatarView alloc] initWithFrame:imageView.bounds];
        avatarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        avatarView.placeholderImage = placeholder;
        avatarView.cornerRadius = imageView.layer.cornerRadius;
        [imageView addSubview:avatarView];
        objc_setAssociatedObject(imageView, kRBAvatarViewKey, avatarView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    avatarView.frame = imageView.bounds;
    avatarView.placeholderImage = placeholder;
    avatarView.staticPreviewOnly = staticPreviewOnly;
    if (imageView.layer.cornerRadius > 0) {
        avatarView.cornerRadius = imageView.layer.cornerRadius;
    }
    [avatarView setAvatarWithFileName:fileName uid:uid];
}

+ (void)pauseVideoForAvatarInImageView:(UIImageView *)imageView
{
    if (imageView == nil) return;
    RBAvatarView *avatarView = objc_getAssociatedObject(imageView, kRBAvatarViewKey);
    [avatarView pauseVideo];
}

+ (void)resumeVideoForAvatarInImageView:(UIImageView *)imageView
{
    if (imageView == nil) return;
    RBAvatarView *avatarView = objc_getAssociatedObject(imageView, kRBAvatarViewKey);
    [avatarView resumeVideo];
}

+ (void)removeAvatarFromImageView:(UIImageView *)imageView
{
    if (imageView == nil) return;
    RBAvatarView *avatarView = objc_getAssociatedObject(imageView, kRBAvatarViewKey);
    if (avatarView) {
        [avatarView removeFromSuperview];
        objc_setAssociatedObject(imageView, kRBAvatarViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

@end
