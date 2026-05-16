//telegram @wz662
//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import "JSQVideoMediaItem.h"
#import "JSQMessagesMediaPlaceholderView.h"
#import "JSQMessagesMediaViewBubbleImageMasker.h"
#import "UIImage+JSQMessages.h"
#import "PWProgressView.h"
#import "JSQMessagesBubbleImage.h"
#import "JSQMessagesBubbleImageFactory.h"

// 衬距，以收到的消息气泡为准（上、左、下、右）
//const UIEdgeInsets JSQVideoMediaItem_controlInsets = {3.5f, 10.5f, 3.5f, 3.5f};// v4.5
const UIEdgeInsets JSQVideoMediaItem_controlInsets = {0.0f, 4.0f, 0.0f, 0.0f};    // v7.1

//// 消息气泡右边的3角形尾巴的宽度（值的定义见：JSQMessagesCollectionViewCellOutgoing.xib），以发出的消息气泡为准
//const CGFloat JSQVideoMediaItem_msgBaloonTrialGap = 10.5f;//6;


@interface JSQVideoMediaItem ()

// 短视频文件消息元数据对象引用
@property (strong, nonatomic) FileMeta *fileMeta;

// 整个ui父容器View
@property (strong, nonatomic) UIView *cachedMediaView;
// 视频预览图View
@property (strong, nonatomic) UIImageView *previewImageView;
// 播放图标View
@property (strong, nonatomic) UIImageView *playIconImageView;
// 上传进度View（仅用于发出的消息）
@property (strong, nonatomic) PWProgressView *progressView;

@end


@implementation JSQVideoMediaItem

#pragma mark - Initialization

- (instancetype)initWithData:(FileMeta *)fileMeta previewImage:(UIImage *)image
{
    self = [super init];
    if (self) {
        _cachedMediaView = nil;
        _fileMeta = fileMeta;
        _image = image;
    }
    return self;
}

- (void)dealloc
{
    _fileMeta = nil;
    _image = nil;

    [self clearCachedMediaViews];
}

- (void)clearCachedMediaViews
{
    _cachedMediaView = nil;
    _previewImageView = nil;
    _playIconImageView = nil;
    _progressView = nil;
    
    [super clearCachedMediaViews];
}


#pragma mark - Setters

- (void)setImage:(UIImage *)image
{
    _image = [image copy];
    _cachedMediaView = nil;
}

- (void)setAppliesMediaViewMaskAsOutgoing:(BOOL)appliesMediaViewMaskAsOutgoing
{
    [super setAppliesMediaViewMaskAsOutgoing:appliesMediaViewMaskAsOutgoing];
    _cachedMediaView = nil;
}


#pragma mark - JSQMessageMediaData protocol

- (CGSize)mediaViewDisplaySize
{
//    return CGSizeMake(210.0f, 150.0f);
    return CGSizeMake(100.0f, 140.0f);
}

- (UIView *)mediaView
{
    if (self.fileMeta != nil && self.cachedMediaView == nil)
    {
        BOOL isOutgoing = self.appliesMediaViewMaskAsOutgoing;
        
        //# create container view for the various controls
        CGSize mainSize = [self mediaViewDisplaySize];
        UIView * containerView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, mainSize.width, mainSize.height)];
        containerView.backgroundColor = [UIColor clearColor];
        containerView.contentMode = UIViewContentModeCenter;
        containerView.clipsToBounds = YES;
        
        //# 气泡背景底图（从v7.1版开始，为了ui的简洁，不显示气泡背景了）
//        UIImageView *bubbleImageBgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, mainSize.width, mainSize.height)];
//        bubbleImageBgView.contentMode = UIViewContentModeScaleToFill;
//        bubbleImageBgView.userInteractionEnabled = NO;
//        JSQMessagesBubbleImageFactory *bubbleImageFactory = [[JSQMessagesBubbleImageFactory alloc] init];
//        JSQMessagesBubbleImage *bubbleImageData =(isOutgoing?[bubbleImageFactory outgoingMessagesBubbleImage_light]:[bubbleImageFactory incomingMessagesBubbleImage]);
//        bubbleImageBgView.image = bubbleImageData.messageBubbleImage;
//        bubbleImageBgView.highlightedImage = bubbleImageData.messageBubbleHighlightedImage;
//        [containerView addSubview:bubbleImageBgView];
        
        //# 预览图4周的衬距
        CGFloat leftInset, rightInset, topInset, bottomInset;
        if (isOutgoing) {
            leftInset = JSQVideoMediaItem_controlInsets.right + 0.5f;// 0.5是个硬偏移量，因为ui上总差那么一点点，所以就硬编码调整一下;
            rightInset = JSQVideoMediaItem_controlInsets.left - 0.5f;// 0.5是个硬偏移量，因为ui上总差那么一点点，所以就硬编码调整一下;
        } else {
            leftInset = JSQVideoMediaItem_controlInsets.left;
            rightInset = JSQVideoMediaItem_controlInsets.right;
        }
        topInset = JSQVideoMediaItem_controlInsets.top;
        bottomInset = JSQVideoMediaItem_controlInsets.bottom;
        
        //# 视频预览图
        CGSize size = mainSize;//[self mediaViewDisplaySize];
        CGRect previewImageFrame = CGRectMake(leftInset, topInset, size.width - leftInset - rightInset, size.height - topInset - bottomInset);
        self.previewImageView = [[UIImageView alloc] initWithImage:self.image];
        self.previewImageView.frame = previewImageFrame;//CGRectMake(0.0f, 0.0f, size.width, size.height);
        self.previewImageView.layer.cornerRadius = 14.0f;//5;
        self.previewImageView.layer.masksToBounds = YES;
        self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.previewImageView.clipsToBounds = YES;
        // 为图片加一个边框
        self.previewImageView.layer.borderColor = HexColor(0xd8d8d8).CGColor;//[UIColor whiteColor].CGColor;
        self.previewImageView.layer.borderWidth = 0.5f;
        [containerView addSubview:self.previewImageView];
        
        //# 播放图标
        CGSize playIconSize = CGSizeMake(40.0f, 40.0f);
        CGFloat playIconX = 0.0f, playIconY = (mainSize.height - playIconSize.height)/2;
//        if(isOutgoing)
//            playIconX = (mainSize.width - playIconSize.width)/2 + JSQVideoMediaItem_msgBaloonTrialGap;
//        else
            playIconX = (mainSize.width - playIconSize.width)/2 + leftInset;
//      UIImage *playIcon = [[UIImage jsq_defaultPlayImage] jsq_imageMaskedWithColor:[UIColor lightGrayColor]];
        self.playIconImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"chat_short_video_preview_play_icon"]];
        self.playIconImageView.frame = CGRectMake(playIconX, playIconY, playIconSize.width, playIconSize.height);
        self.playIconImageView.contentMode = UIViewContentModeCenter;
        [containerView addSubview:self.playIconImageView];
//        if(isOutgoing)
//            self.playIconImageView.hidden = YES;
        
        //# 上传进度条（只在发出的短视频消息时时显示并使用）
        if(isOutgoing)
        {
            self.progressView = [[PWProgressView alloc] init];
            self.progressView.frame = previewImageFrame;//CGRectMake(0.0f, 0.0f, size.width, size.height);
            self.progressView.layer.cornerRadius = 14.0f;//5.0f;
            self.progressView.clipsToBounds = YES;
            [containerView addSubview:self.progressView];
            self.progressView.hidden = YES;
        }
        
        //# 短视频气泡不显示时长（收发均不显示）
        
//        [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:containerView isOutgoing:isOutgoing];
        self.cachedMediaView = containerView;
    }
    
    return self.cachedMediaView;
}

- (void)refreshUploadProgress:(SendStatusSecondary)sendStatusSecondary sendStatusSecondaryProgress:(int)progress
{
//    NSLog(@">>>>>>>>>>>>>>>>>>>>> 正在调用refreshUploadProgress，sendStatusSecondary=%ld、progress=%d", (long)sendStatusSecondary, progress);
    
    float progress_f = progress * 0.01f;
    
    switch(sendStatusSecondary)
    {
        case SendStatusSecondary_PROCESS_OK:
        {
//            self.progressView.progress = progress_f;
            self.progressView.progress = 1.0f;
            [self setPlayIconImageViewVisible:YES];
            break;
        }
        case SendStatusSecondary_NONE:
        {
            // 关闭上传进度提示ui
            self.progressView.hidden = YES;
            self.progressView.progress = 0.0f;
            [self setPlayIconImageViewVisible:YES];
            break;
        }
        // 如果是“等待处理“状态下的消息则意味着接下来需要：先上传到服务端、再发送消息给好友
        case SendStatusSecondary_PENDING:
        {
            // 显示上传进度提示ui
            self.progressView.hidden = NO;
            [self setPlayIconImageViewVisible:NO];
            break;
        }
        case SendStatusSecondary_PROCESSING:
        {
            // 显示上传进度提示ui
            self.progressView.hidden = NO;
            self.progressView.progress = progress_f;
            [self setPlayIconImageViewVisible:NO];
            break;
        }
        case SendStatusSecondary_PROCESS_FAILD:
        {
            // 关闭上传进度提示ui
            self.progressView.hidden = YES;
            [self setPlayIconImageViewVisible:YES];
            break;
        }
    }
}

- (void)setPlayIconImageViewVisible:(BOOL)visible
{
    if(self.playIconImageView != nil)
        self.playIconImageView.hidden = !visible;
}

- (NSUInteger)mediaHash
{
    return self.hash;
}

#pragma mark - NSObject

- (NSUInteger)hash
{
//    return super.hash ^ self.fileURL.hash;
    return super.hash;
}


@end
