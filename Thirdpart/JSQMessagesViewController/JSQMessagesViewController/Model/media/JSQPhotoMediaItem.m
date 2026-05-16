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

#import "JSQPhotoMediaItem.h"

#import "JSQMessagesMediaPlaceholderView.h"
#import "JSQMessagesMediaViewBubbleImageMasker.h"
#import "JSQMessagesBubbleImage.h"
#import "JSQMessagesBubbleImageFactory.h"
#import "UIColor+JSQMessages.h"
#import "UIImage+JSQMessages.h"


// （该衬距是以收到的消息的UI为基准的哦），衬距以收到的消息气泡为准（上、左、下、右）
//const UIEdgeInsets PhotoMediaItemControlInsets = {3.5f, 10.5f, 3.5f, 3.5f}; // v4.5
const UIEdgeInsets PhotoMediaItemControlInsets = {0.0f, 4.0f, 0.0f, 0.0f};    // v7.1


@interface JSQPhotoMediaItem ()

//@property (strong, nonatomic) UIImageView *cachedImageView;
@property (strong, nonatomic) UIView *cachedMediaView;

// 预览图组件
@property (strong, nonatomic) UIImageView *imageView;

@end


@implementation JSQPhotoMediaItem

#pragma mark - Initialization

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super init];
    if (self) {
        _image = [image copy];
        _cachedMediaView = nil;
    }
    return self;
}

- (void)clearCachedMediaViews
{
    [super clearCachedMediaViews];
    _cachedMediaView = nil;
    _imageView = nil;
}


#pragma mark - Setters Getters

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

// 长图判定：高/宽超过此比例时，在对话气泡中单独限制，避免单条占屏过多
static const CGFloat kLongImageAspectRatioThreshold = 2.0f;
// 长图在对话气泡中的固定预览尺寸（只显示顶部一段，点击可全屏看完整长图）
static const CGFloat kLongImageBubbleWidth_iPhone  = 100.0f;
static const CGFloat kLongImageBubbleHeight_iPhone = 160.0f;
static const CGFloat kLongImageBubbleWidth_iPad    = 140.0f;
static const CGFloat kLongImageBubbleHeight_iPad   = 220.0f;

// ★ 动态计算图片显示尺寸（纯粹基于宽高比，无论原图还是缩略图都产生一致的气泡尺寸）
//
// 设计原则：
//   - 发出的图片用本地原图（如 800×1732），收到的图片用缩略图（如 100×217）
//   - 两者宽高比相同，所以气泡大小应该完全一致
//   - 关键：始终按宽高比缩放到 maxWidth × maxHeight 范围内，不受像素大小的影响
//   - 长图（高/宽 > 2）在对话中单独限制最大高度，避免气泡过高
- (CGSize)mediaViewDisplaySize
{
    // 尺寸限制
    CGFloat maxWidth = 180.0f;
    CGFloat maxHeight = 240.0f;
    CGFloat minWidth = 80.0f;
    CGFloat minHeight = 80.0f;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        maxWidth = 270.0f;
        maxHeight = 360.0f;
        minWidth = 120.0f;
        minHeight = 120.0f;
    }
    
    // 图片为空时返回默认尺寸
    if (self.image == nil) {
        return CGSizeMake(maxWidth, 150.0f);
    }
    
    CGFloat imageWidth = self.image.size.width;
    CGFloat imageHeight = self.image.size.height;
    
    if (imageWidth <= 0 || imageHeight <= 0) {
        return CGSizeMake(maxWidth, 150.0f);
    }
    
    // 长图（如 592×2560）：气泡内固定为「宽×高」预览，只显示顶部一段，点击全屏可看完整
    if (imageHeight / imageWidth > kLongImageAspectRatioThreshold) {
        CGFloat w = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
            ? kLongImageBubbleWidth_iPad : kLongImageBubbleWidth_iPhone;
        CGFloat h = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
            ? kLongImageBubbleHeight_iPad : kLongImageBubbleHeight_iPhone;
        return CGSizeMake(w, h);
    }
    
    // ★ 普通图：按宽高比缩放到 maxWidth × maxHeight 范围内
    CGFloat widthRatio = maxWidth / imageWidth;
    CGFloat heightRatio = maxHeight / imageHeight;
    CGFloat scale = MIN(widthRatio, heightRatio);
    
    CGFloat displayWidth = imageWidth * scale;
    CGFloat displayHeight = imageHeight * scale;
    
    if (displayWidth < minWidth) {
        CGFloat minScale = minWidth / imageWidth;
        displayWidth = imageWidth * minScale;
        displayHeight = imageHeight * minScale;
        if (displayHeight > maxHeight) {
            displayHeight = maxHeight;
            displayWidth = imageWidth * (maxHeight / imageHeight);
        }
    }
    if (displayHeight < minHeight) {
        CGFloat minScale = minHeight / imageHeight;
        displayWidth = imageWidth * minScale;
        displayHeight = imageHeight * minScale;
        if (displayWidth > maxWidth) {
            displayWidth = maxWidth;
            displayHeight = imageHeight * (maxWidth / imageWidth);
        }
    }
    
    return CGSizeMake(ceil(displayWidth), ceil(displayHeight));
}

- (UIView *)mediaView
{
//    if (self.image == nil) {
//        return nil;
//    }
    
    if (self.cachedMediaView == nil) {
        
        BOOL isOutgoing = self.appliesMediaViewMaskAsOutgoing;

        BOOL isLongImage = (self.image != nil
                            && self.image.size.width > 0
                            && self.image.size.height / self.image.size.width > kLongImageAspectRatioThreshold);

        //# create container view for the various controls
        CGSize mainSize = [self mediaViewDisplaySize];
        UIView * playView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, mainSize.width, mainSize.height)];
        playView.backgroundColor = [UIColor clearColor];
        playView.contentMode = UIViewContentModeCenter;
        playView.clipsToBounds = YES;
        playView.userInteractionEnabled = NO;
        // 长图：imageView 高于容器，若仅用矩形裁切，底部会变成「平切」看不到圆角；容器与 imageView 同圆角，裁切轮廓为圆角矩形
        if (isLongImage) {
            playView.layer.cornerRadius = 14.0f;
        }
        
        //# 气泡背景底图（从v7.1版开始，为了ui的简洁，不显示气泡背景了）
//        UIImageView *bubbleImageBgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, mainSize.width, mainSize.height)];
//        bubbleImageBgView.contentMode = UIViewContentModeScaleToFill;
//        bubbleImageBgView.userInteractionEnabled = NO;
//        JSQMessagesBubbleImageFactory *bubbleImageFactory = [[JSQMessagesBubbleImageFactory alloc] init];
//        JSQMessagesBubbleImage *bubbleImageData =(isOutgoing?[bubbleImageFactory outgoingMessagesBubbleImage_light]:[bubbleImageFactory incomingMessagesBubbleImage]);
//        bubbleImageBgView.image = bubbleImageData.messageBubbleImage;
//        bubbleImageBgView.highlightedImage = bubbleImageData.messageBubbleHighlightedImage;
//        [playView addSubview:bubbleImageBgView];
        
        //# 内容图4周的衬距
        CGFloat leftInset, rightInset, topInset, bottomInset;
        if (isOutgoing) {
            leftInset = PhotoMediaItemControlInsets.right + 0.5f;
            rightInset = PhotoMediaItemControlInsets.left - 0.5f;
        } else {
            leftInset = PhotoMediaItemControlInsets.left;
            rightInset = PhotoMediaItemControlInsets.right;
        }
        topInset = PhotoMediaItemControlInsets.top;
        bottomInset = PhotoMediaItemControlInsets.bottom;
        
        CGSize size = [self mediaViewDisplaySize];
        CGFloat contentW = size.width - leftInset - rightInset;
        CGFloat contentH = size.height - topInset - bottomInset;
        CGRect imgFrame;
        if (isLongImage) {
            // 长图：imageView 按原比例高度，只显示顶部 contentH，底部被容器裁掉
            CGFloat fullHeight = contentW * (self.image.size.height / self.image.size.width);
            imgFrame = CGRectMake(leftInset, topInset, contentW, fullHeight);
        } else {
            imgFrame = CGRectMake(leftInset, topInset, contentW, contentH);
        }
        UIImage *img = (self.image != nil? self.image : [[UIImage imageNamed:@"common_default_img_no_border_120dp"] jsq_imageMaskedWithColor:UI_DEFAULT_MEDIA_MESSAGE_PLACEHOLDER_COLOR]);
        self.imageView = [[UIImageView alloc] initWithImage:img];
        self.imageView.frame = imgFrame;
        self.imageView.layer.cornerRadius = 14;
        self.imageView.layer.masksToBounds = YES;
        self.imageView.contentMode = isLongImage ? UIViewContentModeScaleAspectFit : UIViewContentModeScaleToFill;
        self.imageView.clipsToBounds = YES;
        // 为图片加一个边框
        self.imageView.layer.borderColor = HexColor(0xd8d8d8).CGColor;//[UIColor whiteColor].CGColor;
        self.imageView.layer.borderWidth = 0.5f;
        [playView addSubview:self.imageView];
        
//      [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:imageView isOutgoing:self.appliesMediaViewMaskAsOutgoing];
        
//      self.cachedImageView = imageView;
        self.cachedMediaView = playView;
    }
    else
    {
        self.imageView.image = self.image;
    }
    
//    return self.cachedImageView;
    return self.cachedMediaView;
}

- (NSUInteger)mediaHash
{
    return self.hash;
}


#pragma mark - NSObject

- (NSUInteger)hash
{
    return super.hash ^ self.image.hash;
}

//- (NSString *)description
//{
//    return [NSString stringWithFormat:@"<%@: image=%@, appliesMediaViewMaskAsOutgoing=%@>",
//            [self class], self.image, @(self.appliesMediaViewMaskAsOutgoing)];
//}
//
//
//#pragma mark - NSCoding
//
//- (instancetype)initWithCoder:(NSCoder *)aDecoder
//{
//    self = [super initWithCoder:aDecoder];
//    if (self) {
//        _image = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(image))];
//    }
//    return self;
//}
//
//- (void)encodeWithCoder:(NSCoder *)aCoder
//{
//    [super encodeWithCoder:aCoder];
//    [aCoder encodeObject:self.image forKey:NSStringFromSelector(@selector(image))];
//}
//
//
//#pragma mark - NSCopying
//
//- (instancetype)copyWithZone:(NSZone *)zone
//{
//    JSQPhotoMediaItem *copy = [[JSQPhotoMediaItem allocWithZone:zone] initWithImage:self.image];
//    copy.appliesMediaViewMaskAsOutgoing = self.appliesMediaViewMaskAsOutgoing;
//    return copy;
//}

@end
