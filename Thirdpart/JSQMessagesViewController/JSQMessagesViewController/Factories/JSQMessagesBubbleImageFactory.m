//telegram @wz662

#import "JSQMessagesBubbleImageFactory.h"

#import "UIImage+JSQMessages.h"
#import "UIColor+JSQMessages.h"


@interface JSQMessagesBubbleImageFactory ()

@property (strong, nonatomic, readonly) UIImage *bubbleImage;

@end


@implementation JSQMessagesBubbleImageFactory

#pragma mark - Initialization

- (instancetype)init
{
    self = [super init];
    if (self) {
    }
    return self;
}


#pragma mark - Public

- (JSQMessagesBubbleImage *)outgoingMessagesBubbleImage
{
    return [self jsq_messagesBubbleImage:NO lightBg:NO];
}

- (JSQMessagesBubbleImage *)outgoingMessagesBubbleImage_light
{
    return [self jsq_messagesBubbleImage:NO lightBg:YES];
}

- (JSQMessagesBubbleImage *)outgoingMessagesBubbleImage_wechatGreen
{
    UIColor *fill = [UIColor colorWithRed:(200.0f/255.0f) green:(225.0f/255.0f) blue:(255.0f/255.0f) alpha:1.0f];
    UIColor *border = [fill jsq_colorByDarkeningColorWithValue:0.22f];
    UIColor *fillHigh = [fill jsq_colorByDarkeningColorWithValue:0.12f];
    UIColor *borderHigh = [fillHigh jsq_colorByDarkeningColorWithValue:0.22f];

    UIImage *normalMask = [UIImage imageNamed:@"chatto_bg_light_normal"];
    UIImage *pressedMask = [UIImage imageNamed:@"chatto_bg_light_pressed"];
    UIImage *normalBubble = jsq_messagesBubbleCompositeImageWithFillBorder(normalMask, fill, border, 2.0f);
    UIImage *highlightedBubble = jsq_messagesBubbleCompositeImageWithFillBorder(pressedMask, fillHigh, borderHigh, 2.0f);

    normalBubble = [normalBubble jsq_imageFlippedVertically];
    highlightedBubble = [highlightedBubble jsq_imageFlippedVertically];
    UIEdgeInsets eiNormal = UIEdgeInsetsMake(21, 14, 14, 18);
    eiNormal = jsq_edgeInsetsWithTopBottomSwapped(eiNormal);
    normalBubble = [normalBubble resizableImageWithCapInsets:eiNormal resizingMode:UIImageResizingModeStretch];
    highlightedBubble = [highlightedBubble resizableImageWithCapInsets:eiNormal resizingMode:UIImageResizingModeStretch];
    return [[JSQMessagesBubbleImage alloc] initWithMessageBubbleImage:normalBubble highlightedImage:highlightedBubble];
}

- (JSQMessagesBubbleImage *)outgoingMessagesBubbleImage_white
{
    return [self jsq_messagesBubbleImageWithColor:[UIColor whiteColor] flippedForIncoming:NO];
}

- (JSQMessagesBubbleImage *)incomingMessagesBubbleImage
{
    return [self jsq_messagesBubbleImage:YES lightBg:NO];
}

- (JSQMessagesBubbleImage *)incomingMessagesBubbleImage_white
{
    return [self jsq_messagesBubbleImageWithColor:[UIColor whiteColor] flippedForIncoming:YES];
}


#pragma mark - Private

// 气泡尾巴改在下方：垂直翻转后需交换 cap insets 的 top/bottom
static UIEdgeInsets jsq_edgeInsetsWithTopBottomSwapped(UIEdgeInsets ei) {
    return UIEdgeInsetsMake(ei.bottom, ei.left, ei.top, ei.right);
}

static UIImage *jsq_messagesBubbleCompositeImageWithFillBorder(UIImage *maskImage, UIColor *fillColor, UIColor *borderColor, CGFloat borderPixels)
{
    UIImage *borderImg = [maskImage jsq_imageMaskedWithColor:borderColor];
    UIImage *fillImg = [maskImage jsq_imageMaskedWithColor:fillColor];
    CGFloat inset = borderPixels / MAX(1.0f, maskImage.scale);
    CGRect bounds = (CGRect){CGPointZero, borderImg.size};
    UIGraphicsBeginImageContextWithOptions(borderImg.size, NO, borderImg.scale);
    [borderImg drawInRect:bounds];
    [fillImg drawInRect:CGRectInset(bounds, inset, inset)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: borderImg;
}

- (JSQMessagesBubbleImage *)jsq_messagesBubbleImageWithColor:(UIColor *)color flippedForIncoming:(BOOL)flippedForIncoming
{
    NSString *normalName = flippedForIncoming ? @"chatfrom_bg_normal" : @"chatto_bg_light_normal";
    NSString *pressedName = flippedForIncoming ? @"chatfrom_bg_pressed" : @"chatto_bg_light_pressed";
    UIColor *borderColor = [color jsq_colorByDarkeningColorWithValue:0.22f];
    UIColor *highlightFill = [color jsq_colorByDarkeningColorWithValue:0.12f];
    UIColor *highlightBorder = [highlightFill jsq_colorByDarkeningColorWithValue:0.22f];
    UIImage *normalBubble = jsq_messagesBubbleCompositeImageWithFillBorder([UIImage imageNamed:normalName], color, borderColor, 2.0f);
    UIImage *highlightedBubble = jsq_messagesBubbleCompositeImageWithFillBorder([UIImage imageNamed:pressedName], highlightFill, highlightBorder, 2.0f);
    // 垂直翻转，尾巴从上改到下
    normalBubble = [normalBubble jsq_imageFlippedVertically];
    highlightedBubble = [highlightedBubble jsq_imageFlippedVertically];
    UIEdgeInsets eiNormal = flippedForIncoming ? UIEdgeInsetsMake(21, 18, 14, 14) : UIEdgeInsetsMake(21, 14, 14, 18);
    eiNormal = jsq_edgeInsetsWithTopBottomSwapped(eiNormal);
    UIEdgeInsets eiHighlighted = eiNormal;
    normalBubble = [normalBubble resizableImageWithCapInsets:eiNormal resizingMode:UIImageResizingModeStretch];
    highlightedBubble = [highlightedBubble resizableImageWithCapInsets:eiHighlighted resizingMode:UIImageResizingModeStretch];
    return [[JSQMessagesBubbleImage alloc] initWithMessageBubbleImage:normalBubble highlightedImage:highlightedBubble];
}

- (JSQMessagesBubbleImage *)jsq_messagesBubbleImage:(BOOL)flippedForIncoming lightBg:(BOOL)useLight
{
    // 发出的消息气泡图片
    UIImage *normalBubble = [UIImage imageNamed:useLight?@"chatto_bg_light_normal":@"chatto_bg_normal"];
    UIImage *highlightedBubble = [UIImage imageNamed:useLight?@"chatto_bg_light_pressed":@"chatto_bg_pressed"];

//    // 发出的消息气泡图片拉伸衬距
//    // 补充说明：UIEdgeInsetsMake的PC像素值是：上50、左19、下18、右30，当前图是@2x，所以此时代
//    //         码中的结果都是要除以2哦(具体取值请见/RainbowChat/doc目录下的“Rainbowchat当前聊
//    //         天消息气泡的UIEdgeInsets拉伸区.png”截图).
//    UIEdgeInsets eiNormal = UIEdgeInsetsMake(25, 9, 8,15);
//    UIEdgeInsets eiHighlighted = UIEdgeInsetsMake(25, 9, 8,15);
    
    // 发出的消息气泡图片拉伸衬距
    // 补充说明：UIEdgeInsetsMake的PC像素值是：上63、左42、下42、右54，当前图是@3x，所以此时代
    //         码中的结果都是要除以3哦(具体取值请见/RainbowChat/doc目录下的“Rainbowchat当前聊
    //         天消息气泡的UIEdgeInsets拉伸区-v7.1.png”截图).
    UIEdgeInsets eiNormal = UIEdgeInsetsMake(21, 14, 14, 18);
    UIEdgeInsets eiHighlighted = UIEdgeInsetsMake(21, 14, 14, 18);

    // 收到的消息气泡图片和图片拉伸衬距
    if (flippedForIncoming) {
        normalBubble = [UIImage imageNamed:@"chatfrom_bg_normal"];
        highlightedBubble = [UIImage imageNamed:@"chatfrom_bg_pressed"];

        // 收到的消息图片拉伸衬距是跟发出的消息图片一右一左的区别，其它都相同
//        eiNormal = UIEdgeInsetsMake(25, 15, 8,9);
//        eiHighlighted = UIEdgeInsetsMake(25, 15, 8,9);
        eiNormal = UIEdgeInsetsMake(21, 18, 14, 14);
        eiHighlighted = UIEdgeInsetsMake(21, 18, 14, 14);
    }

    // 垂直翻转，尾巴从上改到下
    normalBubble = [normalBubble jsq_imageFlippedVertically];
    highlightedBubble = [highlightedBubble jsq_imageFlippedVertically];
    eiNormal = jsq_edgeInsetsWithTopBottomSwapped(eiNormal);
    eiHighlighted = jsq_edgeInsetsWithTopBottomSwapped(eiHighlighted);

    normalBubble = [normalBubble resizableImageWithCapInsets:eiNormal resizingMode:UIImageResizingModeStretch];
    highlightedBubble = [highlightedBubble resizableImageWithCapInsets:eiHighlighted resizingMode:UIImageResizingModeStretch];
    return [[JSQMessagesBubbleImage alloc] initWithMessageBubbleImage:normalBubble highlightedImage:highlightedBubble];
}

#pragma mark - 无尾气泡（分组 top/middle 用，仅显示头像的气泡才显示尾巴）

static const CGFloat kJSQBubbleNoTailCornerRadius = 12.0f;
static const CGFloat kJSQBubbleNoTailSize = 40.0f;

+ (UIImage *)jsq_roundedRectBubbleImageWithColor:(UIColor *)color size:(CGFloat)size cornerRadius:(CGFloat)radius
{
    UIGraphicsImageRendererFormat *fmt = [[UIGraphicsImageRendererFormat alloc] init];
    fmt.scale = [UIScreen mainScreen].scale;
    fmt.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:fmt];
    UIImage *img = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size) cornerRadius:radius];
        [color setFill];
        [path fill];
    }];
    CGFloat cap = radius + 1.0f;
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(cap, cap, cap, cap) resizingMode:UIImageResizingModeStretch];
}

+ (UIImage *)jsq_roundedRectBubbleImageWithFillColor:(UIColor *)fillColor borderColor:(UIColor *)borderColor borderPixels:(CGFloat)borderPixels size:(CGFloat)size cornerRadius:(CGFloat)radius
{
    UIGraphicsImageRendererFormat *fmt = [[UIGraphicsImageRendererFormat alloc] init];
    fmt.scale = [UIScreen mainScreen].scale;
    fmt.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:fmt];
    UIImage *img = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        CGFloat borderW = borderPixels / MAX(1.0f, fmt.scale);
        CGFloat inset = borderW;
        CGFloat rr = MAX(0.0f, radius - inset);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(inset, inset, size - inset * 2.0f, size - inset * 2.0f) cornerRadius:rr];
        [fillColor setFill];
        [path fill];
        if (borderColor != nil && borderPixels > 0.0f) {
            UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(inset, inset, size - inset * 2.0f, size - inset * 2.0f) cornerRadius:rr];
            strokePath.lineWidth = borderW;
            [borderColor setStroke];
            [strokePath stroke];
        }
    }];
    CGFloat cap = radius + 1.0f;
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(cap, cap, cap, cap) resizingMode:UIImageResizingModeStretch];
}

- (JSQMessagesBubbleImage *)outgoingMessagesBubbleImage_wechatGreenWithoutTail
{
    UIColor *fill = [UIColor colorWithRed:(200.0f/255.0f) green:(225.0f/255.0f) blue:(255.0f/255.0f) alpha:1.0f];
    UIColor *border = [fill jsq_colorByDarkeningColorWithValue:0.22f];
    UIColor *highlightedFill = [fill jsq_colorByDarkeningColorWithValue:0.12f];
    UIColor *highlightedBorder = [highlightedFill jsq_colorByDarkeningColorWithValue:0.22f];
    UIImage *normal = [JSQMessagesBubbleImageFactory jsq_roundedRectBubbleImageWithFillColor:fill borderColor:border borderPixels:2.0f size:kJSQBubbleNoTailSize cornerRadius:kJSQBubbleNoTailCornerRadius];
    UIImage *highlighted = [JSQMessagesBubbleImageFactory jsq_roundedRectBubbleImageWithFillColor:highlightedFill borderColor:highlightedBorder borderPixels:2.0f size:kJSQBubbleNoTailSize cornerRadius:kJSQBubbleNoTailCornerRadius];
    return [[JSQMessagesBubbleImage alloc] initWithMessageBubbleImage:normal highlightedImage:highlighted];
}

- (JSQMessagesBubbleImage *)incomingMessagesBubbleImage_whiteWithoutTail
{
    UIColor *color = [UIColor whiteColor];
    UIColor *border = [color jsq_colorByDarkeningColorWithValue:0.22f];
    UIColor *highlightedColor = [color jsq_colorByDarkeningColorWithValue:0.12f];
    UIColor *highlightedBorder = [highlightedColor jsq_colorByDarkeningColorWithValue:0.22f];
    UIImage *normal = [JSQMessagesBubbleImageFactory jsq_roundedRectBubbleImageWithFillColor:color borderColor:border borderPixels:2.0f size:kJSQBubbleNoTailSize cornerRadius:kJSQBubbleNoTailCornerRadius];
    UIImage *highlighted = [JSQMessagesBubbleImageFactory jsq_roundedRectBubbleImageWithFillColor:highlightedColor borderColor:highlightedBorder borderPixels:2.0f size:kJSQBubbleNoTailSize cornerRadius:kJSQBubbleNoTailCornerRadius];
    return [[JSQMessagesBubbleImage alloc] initWithMessageBubbleImage:normal highlightedImage:highlighted];
}

@end
