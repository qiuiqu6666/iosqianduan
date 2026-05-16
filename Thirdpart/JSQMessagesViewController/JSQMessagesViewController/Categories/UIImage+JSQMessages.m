//telegram @wz662

#import "UIImage+JSQMessages.h"

#import "NSBundle+JSQMessages.h"


@implementation UIImage (JSQMessages)

// 返回用指定颜色遮罩2D绘制实现后的Image对象
- (UIImage *)jsq_imageMaskedWithColor:(UIColor *)maskColor
{
    NSParameterAssert(maskColor != nil);
    
    CGRect imageRect = CGRectMake(0.0f, 0.0f, self.size.width, self.size.height);
    UIImage *newImage = nil;
    
    UIGraphicsBeginImageContextWithOptions(imageRect.size, NO, self.scale);
    {
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextScaleCTM(context, 1.0f, -1.0f);
        CGContextTranslateCTM(context, 0.0f, -(imageRect.size.height));
        
        CGContextClipToMask(context, imageRect, self.CGImage);
        CGContextSetFillColorWithColor(context, maskColor.CGColor);
        CGContextFillRect(context, imageRect);
        
        newImage = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    
    return newImage;
}

// 垂直翻转，气泡尾巴从上改到下
- (UIImage *)jsq_imageFlippedVertically
{
    CGRect imageRect = CGRectMake(0.0f, 0.0f, self.size.width, self.size.height);
    UIGraphicsBeginImageContextWithOptions(imageRect.size, NO, self.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, 0.0f, imageRect.size.height);
    CGContextScaleCTM(ctx, 1.0f, -1.0f);
    CGContextDrawImage(ctx, imageRect, self.CGImage);
    UIImage *flipped = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return flipped;
}

+ (UIImage *)jsq_bubbleImageFromBundleWithName:(NSString *)name
{
    NSTimeInterval s = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;

    NSBundle *bundle = [NSBundle jsq_messagesAssetBundle];
    NSString *path = [bundle pathForResource:name ofType:@"png" inDirectory:@"Images"];
//    NSLog(@"正在加载图片》》》》》》》》》》》》》》》》》》》name=%@,path=%@ ", name, path);
    UIImage *img = [UIImage imageWithContentsOfFile:path];

    NSTimeInterval e = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;
    NSLog(@"[UIImage(JSQMessages)] 加载图片name=%@,path=%@,耗时：%f ms", name, path, (e - s));

    return img;
}

+ (UIImage *)jsq_bubbleRegularImage
{
    return [UIImage jsq_bubbleImageFromBundleWithName:@"bubble_regular"];
}

+ (UIImage *)jsq_bubbleRegularTaillessImage
{
    return [UIImage jsq_bubbleImageFromBundleWithName:@"bubble_tailless"];
}

+ (UIImage *)jsq_bubbleRegularStrokedImage
{
    return [UIImage jsq_bubbleImageFromBundleWithName:@"bubble_stroked"];
}

+ (UIImage *)jsq_bubbleRegularStrokedTaillessImage
{
    return [UIImage jsq_bubbleImageFromBundleWithName:@"bubble_stroked_tailless"];
}

+ (UIImage *)jsq_bubbleCompactImage
{
    return [UIImage jsq_bubbleImageFromBundleWithName:@"bubble_min"];
}

+ (UIImage *)jsq_bubbleCompactTaillessImage
{
    return [UIImage jsq_bubbleImageFromBundleWithName:@"bubble_min_tailless"];
}

+ (UIImage *)jsq_defaultAccessoryImage
{
    return [UIImage jsq_bubbleImageFromBundleWithName:@"clip"];
//    return [UIImage imageNamed:@"chatting_list_view_tempchat_sendimage_normal_icon"];
}

+ (UIImage *)jsq_defaultTypingIndicatorImage
{
    return [UIImage jsq_bubbleImageFromBundleWithName:@"typing"];
}

+ (UIImage *)jsq_defaultPlayImage
{
    return [UIImage jsq_bubbleImageFromBundleWithName:@"play"];
}

+ (UIImage *)jsq_defaultPauseImage
{
    return [UIImage jsq_bubbleImageFromBundleWithName:@"pause"];
}

@end
