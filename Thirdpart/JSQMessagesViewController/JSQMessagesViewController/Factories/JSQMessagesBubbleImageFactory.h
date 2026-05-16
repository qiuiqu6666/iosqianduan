//telegram @wz662

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "JSQMessagesBubbleImage.h"

/**
 *  `JSQMessagesBubbleImageFactory` is a factory that provides a means for creating and styling 
 *  `JSQMessagesBubbleImage` objects to be displayed in a `JSQMessagesCollectionViewCell` of a `JSQMessagesCollectionView`.
 */
@interface JSQMessagesBubbleImageFactory : NSObject

/**
 *  Creates and returns a new instance of `JSQMessagesBubbleImageFactory` that uses the
 *  default bubble image assets and cap insets.
 *
 *  @return An initialized `JSQMessagesBubbleImageFactory` object if created successfully, `nil` otherwise.
 */
- (instancetype)init;

/**
 *  Creates and returns a `JSQMessagesBubbleImage` object with the specified color for *outgoing* message image bubbles.
 *  The `messageBubbleImage` property of the `JSQMessagesBubbleImage` is configured with a flat bubble image, masked to the given color.
 *  The `messageBubbleHighlightedImage` property is configured similarly, but with a darkened version of the given color.
 *
 *  @return An initialized `JSQMessagesBubbleImage` object if created successfully, `nil` otherwise.
 */
- (JSQMessagesBubbleImage *)outgoingMessagesBubbleImage;

- (JSQMessagesBubbleImage *)outgoingMessagesBubbleImage_light;

/** 我方气泡：蓝色（与 iMessage 风格接近；方法名保留以兼容现有调用） */
- (JSQMessagesBubbleImage *)outgoingMessagesBubbleImage_wechatGreen;

- (JSQMessagesBubbleImage *)outgoingMessagesBubbleImage_white;

/**
 *  Creates and returns a `JSQMessagesBubbleImage` object with the specified color for *incoming* message image bubbles.
 *  The `messageBubbleImage` property of the `JSQMessagesBubbleImage` is configured with a flat bubble image, masked to the given color.
 *  The `messageBubbleHighlightedImage` property is configured similarly, but with a darkened version of the given color.
 *
 *  @return An initialized `JSQMessagesBubbleImage` object if created successfully, `nil` otherwise.
 */
- (JSQMessagesBubbleImage *)incomingMessagesBubbleImage;

/** 对方气泡使用白色（微信风格，白底极浅灰边） */
- (JSQMessagesBubbleImage *)incomingMessagesBubbleImage_white;

/** 无尾气泡（分组中 top/middle 用）：我方蓝色，圆角矩形 */
- (JSQMessagesBubbleImage *)outgoingMessagesBubbleImage_wechatGreenWithoutTail;
/** 无尾气泡（分组中 top/middle 用）：对方白色，圆角矩形 */
- (JSQMessagesBubbleImage *)incomingMessagesBubbleImage_whiteWithoutTail;

@end
