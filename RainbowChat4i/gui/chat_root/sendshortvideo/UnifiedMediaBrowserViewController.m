// Copyright (C) 2026 即时通讯网(52im.net) & Jack Jiang.
// The RainbowChat Project. All rights reserved.

#import "UnifiedMediaBrowserViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "SDImageCache.h"
#import "UIImageView+WebCache.h"
#import "FileDownloadHelper.h"
#import "ReceivedShortVideoHelper.h"
#import "FileTool.h"
#import "TimeTool.h"
#import "ShortVideoPlayViewController.h"
#import "ViewControllerFactory.h"
#import "MsgBodyRoot.h"
#import "MSSBrowseModel.h"
#import "BasicTool.h"

#define SCREEN_WIDTH  [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

static NSInteger const kImageViewTag  = 1001;
static NSInteger const kScrollViewTag = 1002;
static NSInteger const kVideoTagBase  = 2000; // for video type indicator

#pragma mark - ZoomableScrollView（图片缩放容器）

/** 高/宽超过此比例视为超长图，全屏预览时按原比例展示，需上下滑动查看；以下常见截图比例一屏适配无需滑动 */
static const CGFloat kLongImageAspectRatioThreshold = 2.5f;

@interface ZoomableScrollView : UIScrollView <UIScrollViewDelegate>
@property (nonatomic, strong) UIImageView *imageView;
/// 普通图/截图一屏适配；超长图（高宽比>2.5）按原比例可上下滑动查看
- (void)layoutForImage:(UIImage *)image;
@end

@implementation ZoomableScrollView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.delegate = self;
        self.minimumZoomScale = 1.0;
        self.maximumZoomScale = 5.0;
        self.showsVerticalScrollIndicator   = YES;
        self.showsHorizontalScrollIndicator = NO;
        self.bouncesZoom = YES;
        self.backgroundColor = [UIColor clearColor];
        
        _imageView = [[UIImageView alloc] initWithFrame:frame];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.clipsToBounds = YES;
        [self addSubview:_imageView];
    }
    return self;
}

- (void)layoutForImage:(UIImage *)image {
    if (image == nil || image.size.width <= 0 || image.size.height <= 0) return;
    CGSize containerSize = self.bounds.size;
    CGFloat aspectRatio = image.size.height / image.size.width;
    if (aspectRatio > kLongImageAspectRatioThreshold) {
        // 超长图：宽度铺满屏幕，高度按原比例，需上下滑动查看
        CGFloat displayWidth  = containerSize.width;
        CGFloat displayHeight = containerSize.width * aspectRatio;
        self.contentSize = CGSizeMake(displayWidth, displayHeight);
        self.imageView.frame = CGRectMake(0, 0, displayWidth, displayHeight);
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.minimumZoomScale = 1.0;
        self.zoomScale = 1.0;
        self.contentOffset = CGPointZero;
    } else {
        // 普通图/截图：一屏内完整显示，无需滑动
        self.contentSize = containerSize;
        self.imageView.frame = CGRectMake(0, 0, containerSize.width, containerSize.height);
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.minimumZoomScale = 1.0;
        self.zoomScale = 1.0;
        self.contentOffset = CGPointZero;
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    // 缩放时保持图片居中
    CGFloat offsetX = MAX((scrollView.bounds.size.width  - scrollView.contentSize.width)  / 2.0, 0);
    CGFloat offsetY = MAX((scrollView.bounds.size.height - scrollView.contentSize.height) / 2.0, 0);
    self.imageView.center = CGPointMake(scrollView.contentSize.width  / 2.0 + offsetX,
                                        scrollView.contentSize.height / 2.0 + offsetY);
}

// 双击缩放
- (void)zoomToPoint:(CGPoint)point {
    if (self.zoomScale > self.minimumZoomScale) {
        [self setZoomScale:self.minimumZoomScale animated:YES];
    } else {
        CGFloat newScale = self.maximumZoomScale;
        CGFloat w = self.bounds.size.width  / newScale;
        CGFloat h = self.bounds.size.height / newScale;
        [self zoomToRect:CGRectMake(point.x - w / 2, point.y - h / 2, w, h) animated:YES];
    }
}

@end

#pragma mark - UnifiedMediaBrowserViewController

@interface UnifiedMediaBrowserViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate>

@property (nonatomic, strong) NSArray<NSDictionary *> *mediaDataArray;
@property (nonatomic, strong) NSArray<MSSBrowseModel *> *browseItems; // keep for API compatibility
@property (nonatomic, assign) NSInteger currentIndex;

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIView   *bgView;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *moreButton;
@property (nonatomic, strong) UILabel  *countLabel;

// 视频播放相关
@property (nonatomic, strong) AVPlayer      *currentPlayer;
@property (nonatomic, strong) AVPlayerLayer *currentPlayerLayer;
@property (nonatomic, assign) NSInteger      currentPlayingIndex;

@end

@implementation UnifiedMediaBrowserViewController

#pragma mark - Init

- (instancetype)initWithMediaDataArray:(NSArray<NSDictionary *> *)mediaDataArray
                          currentIndex:(NSInteger)currentIndex
                           browseItems:(NSArray<MSSBrowseModel *> *)browseItems
{
    self = [super init];
    if (self) {
        self.mediaDataArray     = mediaDataArray;
        self.browseItems        = browseItems;
        self.currentIndex       = currentIndex;
        self.currentPlayingIndex = -1;
        self.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    }
    return self;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    [self setupCollectionView];
    [self scrollToCurrentIndex];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.view.backgroundColor = [UIColor blackColor];
    
    // 背景视图
    self.bgView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.bgView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.bgView];
    
    // 关闭按钮（左上角 X）
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat safeTop = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = [UIApplication sharedApplication].keyWindow.safeAreaInsets.top;
    }
    self.closeButton.frame = CGRectMake(16, safeTop + 8, 36, 36);
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
        UIImage *xImg = [UIImage systemImageNamed:@"xmark" withConfiguration:cfg];
        [self.closeButton setImage:xImg forState:UIControlStateNormal];
        self.closeButton.tintColor = [UIColor whiteColor];
    } else {
        [self.closeButton setImage:[UIImage imageNamed:@"mss_close2"] forState:UIControlStateNormal];
    }
    self.closeButton.layer.cornerRadius = 18;
    self.closeButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    [self.closeButton addTarget:self action:@selector(closeButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];
    
    // 更多按钮（右上角）
    self.moreButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.moreButton.frame = CGRectMake(SCREEN_WIDTH - 16 - 36, safeTop + 8, 36, 36);
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
        UIImage *moreImg = [UIImage systemImageNamed:@"ellipsis.circle" withConfiguration:cfg];
        [self.moreButton setImage:moreImg forState:UIControlStateNormal];
        self.moreButton.tintColor = [UIColor whiteColor];
    } else {
        UIImage *moreImg = [UIImage imageNamed:@"mss_more"];
        if (moreImg) {
            [self.moreButton setImage:moreImg forState:UIControlStateNormal];
        } else {
            [self.moreButton setTitle:@"⋯" forState:UIControlStateNormal];
            [self.moreButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            self.moreButton.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightMedium];
        }
    }
    self.moreButton.layer.cornerRadius = 18;
    self.moreButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    [self.moreButton addTarget:self action:@selector(moreButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.moreButton];
    
    // 计数标签
    self.countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, safeTop + 12, SCREEN_WIDTH, 24)];
    self.countLabel.textAlignment = NSTextAlignmentCenter;
    self.countLabel.textColor = [UIColor whiteColor];
    self.countLabel.font = [BasicTool getSystemFontOfSize:16];
    [self updateCountLabel];
    [self.view addSubview:self.countLabel];
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing      = 0;
    layout.minimumInteritemSpacing  = 0;
    layout.itemSize = CGSizeMake(SCREEN_WIDTH, SCREEN_HEIGHT);
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.pagingEnabled   = YES;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.dataSource = self;
    self.collectionView.delegate   = self;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"MediaCell"];
    [self.view insertSubview:self.collectionView aboveSubview:self.bgView];
    
    // 长按保存图片（当前预览的图片或视频封面）
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressToSaveImage:)];
    longPress.minimumPressDuration = 0.5;
    [self.collectionView addGestureRecognizer:longPress];
    
    // 确保关闭按钮、更多按钮和计数标签在最前面
    [self.view bringSubviewToFront:self.closeButton];
    [self.view bringSubviewToFront:self.moreButton];
    [self.view bringSubviewToFront:self.countLabel];
}

- (void)scrollToCurrentIndex {
    if (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.mediaDataArray.count) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:self.currentIndex inSection:0];
        [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
    }
}

- (void)updateCountLabel {
    if (self.mediaDataArray.count > 1) {
        self.countLabel.text = [NSString stringWithFormat:@"%ld / %lu", (long)(self.currentIndex + 1), (unsigned long)self.mediaDataArray.count];
        self.countLabel.hidden = NO;
    } else {
        self.countLabel.hidden = YES;
    }
}

#pragma mark - Actions

- (void)closeButtonClicked {
    [self stopCurrentVideo];
    [self dismissWithAnimation];
}

- (void)moreButtonClicked {
    NSInteger index = self.currentIndex;
    if (index < 0 || index >= (NSInteger)self.mediaDataArray.count) {
        return;
    }
    NSDictionary *mediaData = self.mediaDataArray[index];
    int mediaType = [[mediaData objectForKey:@"type"] intValue];
    NSNumber *messageIndexNum = mediaData[@"messageIndex"];
    NSInteger messageIndexInChat = messageIndexNum != nil ? [messageIndexNum integerValue] : -1;
    
    __weak typeof(self) wself = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *saveTitle = (mediaType == TM_TYPE_SHORTVIDEO) ? @"保存视频" : @"保存图片";
    NSString *forwardTitle = (mediaType == TM_TYPE_SHORTVIDEO) ? @"转发视频" : @"转发图片";
    [alert addAction:[UIAlertAction actionWithTitle:saveTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (mediaType == TM_TYPE_SHORTVIDEO) {
            int videoType = [[mediaData objectForKey:@"videoType"] intValue];
            NSString *videoSrc = [mediaData objectForKey:@"videoDataSrc"];
            BOOL canSaveLocalVideo = (videoType == VideoDataType_FILE_PATH && videoSrc.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:videoSrc]);
            if (canSaveLocalVideo) {
                UISaveVideoAtPathToSavedPhotosAlbum(videoSrc, wself, @selector(video:didFinishSavingWithError:contextInfo:), nil);
            } else {
                [BasicTool showUserDefintToast:@"当前视频需先下载完成后才能保存" view:wself.view atHide:nil];
            }
            return;
        }
        UIImage *image = [wself currentVisibleImage];
        if (image) {
            UIImageWriteToSavedPhotosAlbum(image, wself, @selector(image:didFinishSavingWithError:contextInfo:), nil);
        } else {
            [BasicTool showUserDefintToast:@"暂无图片可保存" view:wself.view atHide:nil];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:forwardTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [wself stopCurrentVideo];
        [wself dismissWithAnimationCompletion:^{
            if (wself.onForwardBlock != nil) {
                wself.onForwardBlock(messageIndexInChat);
            }
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"在对话中查看" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [wself stopCurrentVideo];
        [wself dismissWithAnimationCompletion:^{
            if (wself.onViewInConversationBlock != nil) {
                wself.onViewInConversationBlock(messageIndexInChat);
            }
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.moreButton;
        alert.popoverPresentationController.sourceRect = self.moreButton.bounds;
        alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dismissWithAnimation {
    [self dismissWithAnimationCompletion:nil];
}

- (void)dismissWithAnimationCompletion:(void (^)(void))completion {
    [UIView animateWithDuration:0.25 animations:^{
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:completion];
    }];
}

- (void)showBrowserViewController {
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *presentingViewController = rootViewController;
    while (presentingViewController.presentedViewController) {
        presentingViewController = presentingViewController.presentedViewController;
    }
    
    // 入场动画：淡入
    self.view.alpha = 0;
    [presentingViewController presentViewController:self animated:NO completion:^{
        [UIView animateWithDuration:0.25 animations:^{
            self.view.alpha = 1.0;
        }];
    }];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.mediaDataArray.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MediaCell" forIndexPath:indexPath];
    
    // 清除之前的内容
    for (UIView *subview in cell.contentView.subviews) {
        if ([subview isKindOfClass:[AVPlayerLayer class]]) {
            [(AVPlayerLayer *)subview removeFromSuperlayer];
        }
        [subview removeFromSuperview];
    }
    cell.contentView.backgroundColor = [UIColor blackColor];
    
    NSDictionary *mediaData = [self.mediaDataArray objectAtIndex:indexPath.item];
    int mediaType = [[mediaData objectForKey:@"type"] intValue];
    
    if (mediaType == TM_TYPE_IMAGE) {
        [self setupImageCell:cell mediaData:mediaData indexPath:indexPath];
    } else if (mediaType == TM_TYPE_SHORTVIDEO) {
        [self setupVideoCell:cell mediaData:mediaData indexPath:indexPath];
    }
    
    return cell;
}

#pragma mark - 图片 Cell（支持缩放 + 点击关闭 + 双击缩放）

- (void)setupImageCell:(UICollectionViewCell *)cell mediaData:(NSDictionary *)mediaData indexPath:(NSIndexPath *)indexPath {
    ZoomableScrollView *zoomView = [[ZoomableScrollView alloc] initWithFrame:cell.contentView.bounds];
    zoomView.tag = kScrollViewTag;
    zoomView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    UIImageView *imageView = zoomView.imageView;
    imageView.backgroundColor = [UIColor blackColor];
    
    // 加载图片（完成后对超长图做按原比例、可上下滑动的布局）
    NSString *imageUrl = [mediaData objectForKey:@"imageUrl"];
    if (imageUrl && imageUrl.length > 0) {
        __weak ZoomableScrollView *weakZoom = zoomView;
        [imageView sd_setImageWithURL:[NSURL URLWithString:imageUrl]
                     placeholderImage:nil
                              options:SDWebImageRetryFailed | SDWebImageLowPriority
                            completed:^(UIImage *img, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
            if (img && weakZoom) {
                [weakZoom layoutForImage:img];
            }
        }];
    } else {
        UIImage *localImg = imageView.image;
        if (localImg) {
            [zoomView layoutForImage:localImg];
        }
    }
    
    [cell.contentView addSubview:zoomView];
    
    // 单击关闭
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageSingleTapped:)];
    singleTap.numberOfTapsRequired = 1;
    [zoomView addGestureRecognizer:singleTap];
    
    // 双击缩放
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageDoubleTapped:)];
    doubleTap.numberOfTapsRequired = 2;
    [zoomView addGestureRecognizer:doubleTap];
    
    // 单击需要双击失败后才触发
    [singleTap requireGestureRecognizerToFail:doubleTap];
}

- (void)imageSingleTapped:(UITapGestureRecognizer *)gesture {
    [self dismissWithAnimation];
}

- (void)imageDoubleTapped:(UITapGestureRecognizer *)gesture {
    ZoomableScrollView *zoomView = (ZoomableScrollView *)gesture.view;
    if ([zoomView isKindOfClass:[ZoomableScrollView class]]) {
        CGPoint point = [gesture locationInView:zoomView.imageView];
        [zoomView zoomToPoint:point];
    }
}

#pragma mark - 视频 Cell（预览图 + 播放按钮）

- (void)setupVideoCell:(UICollectionViewCell *)cell mediaData:(NSDictionary *)mediaData indexPath:(NSIndexPath *)indexPath {
    // 视频预览图
    UIImageView *previewImageView = [[UIImageView alloc] initWithFrame:cell.contentView.bounds];
    previewImageView.contentMode = UIViewContentModeScaleAspectFit;
    previewImageView.backgroundColor = [UIColor blackColor];
    previewImageView.tag = kImageViewTag;
    previewImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    NSString *thumbUrl = [mediaData objectForKey:@"imageUrl"];
    if (thumbUrl && thumbUrl.length > 0) {
        [previewImageView sd_setImageWithURL:[NSURL URLWithString:thumbUrl]
                            placeholderImage:nil];
    }
    
    [cell.contentView addSubview:previewImageView];
    
    // 播放按钮（居中大圆圈）
    UIButton *playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat btnSize = 64;
    playButton.frame = CGRectMake((SCREEN_WIDTH - btnSize) / 2, (SCREEN_HEIGHT - btnSize) / 2, btnSize, btnSize);
    
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightMedium];
        UIImage *playImg = [UIImage systemImageNamed:@"play.circle.fill" withConfiguration:cfg];
        [playButton setImage:playImg forState:UIControlStateNormal];
        playButton.tintColor = [UIColor whiteColor];
    } else {
        [playButton setImage:[UIImage imageNamed:@"chat_short_video_preview_play_icon"] forState:UIControlStateNormal];
    }
    
    playButton.layer.shadowColor   = [UIColor blackColor].CGColor;
    playButton.layer.shadowOffset  = CGSizeMake(0, 1);
    playButton.layer.shadowRadius  = 4;
    playButton.layer.shadowOpacity = 0.5;
    [playButton addTarget:self action:@selector(playVideoButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    playButton.tag = indexPath.item;
    [cell.contentView addSubview:playButton];
    
    // 点击预览图：进入播放（与微信等产品一致）；关闭请用左上角关闭按钮
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(videoPreviewTapped:)];
    tap.cancelsTouchesInView = NO;
    [previewImageView setUserInteractionEnabled:YES];
    [previewImageView addGestureRecognizer:tap];
}

- (void)videoPreviewTapped:(UITapGestureRecognizer *)gesture {
    UIView *walk = gesture.view;
    while (walk != nil && ![walk isKindOfClass:[UICollectionViewCell class]]) {
        walk = walk.superview;
    }
    if (![walk isKindOfClass:[UICollectionViewCell class]]) return;
    NSIndexPath *ip = [self.collectionView indexPathForCell:(UICollectionViewCell *)walk];
    if (ip == nil) return;
    [self playVideoAtIndex:ip.item];
}

#pragma mark - 长按弹出保存菜单

- (void)handleLongPressToSaveImage:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIImage *image = [self currentVisibleImage];
    if (!image) {
        [BasicTool showUserDefintToast:@"暂无图片可保存" view:self.view atHide:nil];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存图片" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.collectionView;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.collectionView.bounds), CGRectGetMidY(self.collectionView.bounds), 1, 1);
        alert.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

/// 当前页对应的图片：图片消息为原图，视频消息为封面图
- (UIImage *)currentVisibleImage {
    NSInteger index = self.currentIndex;
    if (index < 0 || index >= (NSInteger)self.mediaDataArray.count) return nil;
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
    if (!cell) return nil;
    NSDictionary *mediaData = self.mediaDataArray[index];
    int mediaType = [[mediaData objectForKey:@"type"] intValue];
    if (mediaType == TM_TYPE_IMAGE) {
        ZoomableScrollView *zoomView = [cell.contentView viewWithTag:kScrollViewTag];
        if ([zoomView isKindOfClass:[ZoomableScrollView class]] && zoomView.imageView.image)
            return zoomView.imageView.image;
    } else if (mediaType == TM_TYPE_SHORTVIDEO) {
        UIImageView *iv = [cell.contentView viewWithTag:kImageViewTag];
        if ([iv isKindOfClass:[UIImageView class]] && iv.image)
            return iv.image;
    }
    return nil;
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSString *text = error ? @"保存失败" : @"保存成功";
    [BasicTool showUserDefintToast:text view:self.view atHide:nil];
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSString *text = error ? @"视频保存失败" : @"视频保存成功";
    [BasicTool showUserDefintToast:text view:self.view atHide:nil];
}

- (void)playVideoButtonClicked:(UIButton *)sender {
    NSInteger index = sender.tag;
    [self playVideoAtIndex:index];
}

#pragma mark - UICollectionViewDelegate（翻页切换）

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    NSInteger index = (NSInteger)(scrollView.contentOffset.x / SCREEN_WIDTH);
    if (index != self.currentIndex) {
        // 重置之前图片的缩放状态
        [self resetZoomForIndex:self.currentIndex];
        [self stopCurrentVideo];
        self.currentIndex = index;
        [self updateCountLabel];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSInteger index = (NSInteger)(scrollView.contentOffset.x / SCREEN_WIDTH);
    if (index != self.currentPlayingIndex && self.currentPlayingIndex >= 0) {
        [self stopCurrentVideo];
    }
}

- (void)resetZoomForIndex:(NSInteger)index {
    NSIndexPath *ip = [NSIndexPath indexPathForItem:index inSection:0];
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:ip];
    if (cell) {
        ZoomableScrollView *zv = [cell.contentView viewWithTag:kScrollViewTag];
        if ([zv isKindOfClass:[ZoomableScrollView class]]) {
            [zv setZoomScale:1.0 animated:NO];
        }
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(SCREEN_WIDTH, SCREEN_HEIGHT);
}

#pragma mark - 视频播放

- (void)playVideoAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.mediaDataArray.count) return;
    
    NSDictionary *mediaData = [self.mediaDataArray objectAtIndex:index];
    if ([[mediaData objectForKey:@"type"] intValue] != TM_TYPE_SHORTVIDEO) return;
    
    [self stopCurrentVideo];
    
    int duration       = [[mediaData objectForKey:@"duration"] intValue];
    int videoType      = [[mediaData objectForKey:@"videoType"] intValue];
    NSString *videoSrc = [mediaData objectForKey:@"videoDataSrc"];
    
    if (videoSrc == nil || videoSrc.length == 0) return;
    
    // 构建所有视频列表（仅视频），传给专用播放器
    NSMutableArray<NSDictionary *> *videoDataArray = [NSMutableArray array];
    NSInteger currentVideoIndex = 0;
    
    for (NSInteger i = 0; i < (NSInteger)self.mediaDataArray.count; i++) {
        NSDictionary *media = [self.mediaDataArray objectAtIndex:i];
        if ([[media objectForKey:@"type"] intValue] == TM_TYPE_SHORTVIDEO) {
            NSMutableDictionary *vd = [NSMutableDictionary dictionary];
            vd[@"duration"]    = [media objectForKey:@"duration"];
            vd[@"videoType"]   = [media objectForKey:@"videoType"];
            vd[@"videoDataSrc"] = [media objectForKey:@"videoDataSrc"];
            [videoDataArray addObject:vd];
            if (i == index) {
                currentVideoIndex = videoDataArray.count - 1;
            }
        }
    }
    
    // 必须在 dismiss 之前解析导航栈：dismiss 完成后 keyWindow / presenting 链可能不可靠（尤其 iOS 13+ 多 Scene）
    UINavigationController *navHost = self.playbackNavigationController ?: [self rb_navigationControllerFromPresentingChain];
    __weak typeof(self) wself = self;
    [self dismissViewControllerAnimated:NO completion:^{
        UINavigationController *navController = navHost;
        if (navController == nil && wself != nil) {
            navController = [wself rb_navigationControllerFromKeyWindowFallback];
        }
        if (navController == nil) {
            NSLog(@"【统一媒体浏览】无法取得 UINavigationController，无法打开短视频播放页（请确认是从聊天页正常弹出本浏览器）");
            return;
        }

        if (videoDataArray.count > 1) {
            [ViewControllerFactory goShortVideoPlayerViewController_withVideoArray:navController videoDataArray:videoDataArray currentIndex:currentVideoIndex];
        } else {
            if (videoType == VideoDataType_FILE_PATH) {
                [ViewControllerFactory goShortVideoPlayerViewController_fromFile:navController duaration:duration videoFilePath:videoSrc];
            } else if (videoType == VideoDataType_URL) {
                [ViewControllerFactory goShortVideoPlayerViewController_fromUrl:navController duaration:duration httpUrl:videoSrc];
            }
        }
    }];
}

- (void)stopCurrentVideo {
    if (self.currentPlayer) {
        [self.currentPlayer pause];
        [self.currentPlayerLayer removeFromSuperlayer];
        self.currentPlayer      = nil;
        self.currentPlayerLayer = nil;
        self.currentPlayingIndex = -1;
    }
}

/// 从「谁 present 了本浏览器」解析聊天所用的 NavigationController（最可靠）
- (UINavigationController *)rb_navigationControllerFromPresentingChain {
    UIViewController *host = self.presentingViewController;
    if (host == nil) {
        return nil;
    }
    if ([host isKindOfClass:[UINavigationController class]]) {
        return (UINavigationController *)host;
    }
    // showBrowserViewController 从 keyWindow 顶层 present：经常是 UITabBarController，而不是 ChatVC
    if ([host isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tab = (UITabBarController *)host;
        UIViewController *sel = tab.selectedViewController;
        if ([sel isKindOfClass:[UINavigationController class]]) {
            return (UINavigationController *)sel;
        }
        return sel.navigationController;
    }
    if (host.navigationController != nil) {
        return host.navigationController;
    }
    for (UIViewController *p = host; p != nil; p = p.parentViewController) {
        if (p.navigationController != nil) {
            return p.navigationController;
        }
    }
    return nil;
}

/// keyWindow / Tab 根导航兜底（兼容旧逻辑 + iOS 13 多窗口）
- (UINavigationController *)rb_navigationControllerFromKeyWindowFallback {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) {
                continue;
            }
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) {
                    keyWindow = w;
                    break;
                }
            }
            if (keyWindow != nil) {
                break;
            }
        }
        if (keyWindow == nil) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) {
                    continue;
                }
                NSArray<UIWindow *> *windows = ((UIWindowScene *)scene).windows;
                if (windows.count > 0) {
                    keyWindow = windows.firstObject;
                    break;
                }
            }
        }
    }
    if (keyWindow == nil) {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    UIViewController *rootVC = keyWindow.rootViewController;
    if ([rootVC isKindOfClass:[UINavigationController class]]) {
        return (UINavigationController *)rootVC;
    }
    if ([rootVC isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tab = (UITabBarController *)rootVC;
        if ([tab.selectedViewController isKindOfClass:[UINavigationController class]]) {
            return (UINavigationController *)tab.selectedViewController;
        }
        UIViewController *sel = tab.selectedViewController;
        if (sel.navigationController != nil) {
            return sel.navigationController;
        }
    }
    UIViewController *top = rootVC;
    while (top.presentedViewController != nil) {
        top = top.presentedViewController;
    }
    if ([top isKindOfClass:[UINavigationController class]]) {
        return (UINavigationController *)top;
    }
    return top.navigationController;
}

#pragma mark - Dealloc

- (void)dealloc {
    [self stopCurrentVideo];
}

@end
