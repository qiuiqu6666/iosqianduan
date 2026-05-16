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

#import "JSQMessagesMediaViewBubbleImageMasker.h"
#import "JSQMessagesBubbleImageFactory.h"


@implementation JSQMessagesMediaViewBubbleImageMasker

#pragma mark - Initialization

- (instancetype)init
{
    return [self initWithBubbleImageFactory:[[JSQMessagesBubbleImageFactory alloc] init]];
}

- (instancetype)initWithBubbleImageFactory:(JSQMessagesBubbleImageFactory *)bubbleImageFactory
{
    NSParameterAssert(bubbleImageFactory != nil);
    
    self = [super init];
    if (self) {
        _bubbleImageFactory = bubbleImageFactory;
    }
    return self;
}

#pragma mark - View masking

- (void)applyOutgoingBubbleImageMaskToMediaView:(UIView *)mediaView
{
    JSQMessagesBubbleImage *bubbleImageData = [self.bubbleImageFactory outgoingMessagesBubbleImage];
    [self jsq_maskView:mediaView withImage:[bubbleImageData messageBubbleImage]];
}

- (void)applyIncomingBubbleImageMaskToMediaView:(UIView *)mediaView
{
    JSQMessagesBubbleImage *bubbleImageData = [self.bubbleImageFactory incomingMessagesBubbleImage];
    [self jsq_maskView:mediaView withImage:[bubbleImageData messageBubbleImage]];
}

+ (void)applyBubbleImageMaskToMediaView:(UIView *)mediaView isOutgoing:(BOOL)isOutgoing
{
    JSQMessagesMediaViewBubbleImageMasker *masker = [[JSQMessagesMediaViewBubbleImageMasker alloc] init];
    
    if (isOutgoing) {
        [masker applyOutgoingBubbleImageMaskToMediaView:mediaView];
    }
    else {
        [masker applyIncomingBubbleImageMaskToMediaView:mediaView];
    }
}

#pragma mark - Private

// FIXME: START ---------------------------------------------------------------------------------------------------
// 【特别说明】：自20201113日起，因ios14上对于图片mask的使用无法正常工作，本方法自即日起将被建议停用，调用了本方法的代码请使用替代方法！！！
- (void)jsq_maskView:(UIView *)view withImage:(UIImage *)image
{
    NSParameterAssert(view != nil);
    NSParameterAssert(image != nil);

    if(@available(iOS 14.0, *))
    {
        //## 20201113日Jack Jiang注：在ios14真机上，以下代码能工作，但在模拟器上，不能正常工作！
        //## XCode 12（iOS SDK 14），以下代码能正常显示遮罩后的图片
        //## 以下解决方法代码，参考了文章：https://www.jianshu.com/p/35976722f807
        //## TODO: 【以下代码需更多真机测试，确保可靠性】：需更多测试的情况有xcode12编译后，运行在ios13及更老的手机上（不同ios版本、不同手机型号，测试覆盖面越广越好），不知道是否还能正常！
        CALayer *imageViewMaskLayer = [CALayer layer];
        imageViewMaskLayer.frame = CGRectInset(view.frame, 2.0f, 2.0f);
    
//        NSLog(@"A【1】: image.size.width=%f, image.size.height=%f", image.size.width, image.size.height);
//        NSLog(@"A【2】: view.frame.size.width=%f, view.frame.size.height=%f，view.frame.origin.x=%f, vview.frame.origin.y=%f", view.frame.size.width, view.frame.size.height, view.frame.origin.x, view.frame.origin.y);
        
        [imageViewMaskLayer setContents:(id)[self scaleImageToNewSize:image newSize:view.frame.size].CGImage];
        view.layer.mask = imageViewMaskLayer;
    }
    else
    {
        //## XCode 11（iOS SDK 13）以及前的版本，以下代码能正常显示遮罩后的图片
        //## 特别说明：此种情况，据说是Ios的bug，导致此问题的原理请参见：https://github.com/apache/incubator-weex/issues/3265
        UIImageView *imageViewMask = [[UIImageView alloc] initWithImage:image];
        imageViewMask.frame = CGRectInset(view.frame, 2.0f, 2.0f);
        view.layer.mask = imageViewMask.layer;
    }
}

/**
 * 将图片拉伸到新的尺寸。
 *
 * @param originImage 原始图片
 * @param newSize 新的尺寸
 */
- (UIImage *)scaleImageToNewSize:(UIImage *)originImage newSize:(CGSize)newSize
{
    if(originImage != nil)
    {
        UIImage *newImage = originImage;

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0);
        [newImage drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];

        newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        return newImage;
    }
    else
        return nil;
}
// FIXME: END ---------------------------------------------------------------------------------------------------

@end
