//telegram @wz662
//  ----------------------------------------------------------------------
//  Copyright (C) 2018  即时通讯网(52im.net) & Jack Jiang.
//  The RainbowChat Project. All rights reserved.
//
//  > 文档地址: http://www.52im.net/thread-19-1-1.html
//  > 即时通讯技术社区：http://www.52im.net/
//  > 即时通讯技术交流群：320837163 (http://www.52im.net/topic-qqgroup.html)
//
//  "即时通讯网(52im.net) - 即时通讯开发者社区!" 推荐IM工程。
//
//  如需联系作者，请发邮件至 jack.jiang@52im.net 或 jb2011@163.com.
//  ----------------------------------------------------------------------
//
//  【版权申明】：本类原作者为JSQ作者，因原工程已停止更新，当前由JackJiang修改并用于RainbowChat等工程中，感谢原作者。


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 *  A constant defining the default height of a `JSQMessagesTypingIndicatorFooterView`.
 */
FOUNDATION_EXPORT const CGFloat kJSQMessagesTypingIndicatorFooterViewHeight;

/**
 *  The `JSQMessagesTypingIndicatorFooterView` class implements a reusable view that can be placed
 *  at the bottom of a `JSQMessagesCollectionView`. This view represents a typing indicator 
 *  for incoming messages.
 */
@interface JSQMessagesTypingIndicatorFooterView : UICollectionReusableView

#pragma mark - Class methods

/**
 *  Returns the `UINib` object initialized for the collection reusable view.
 *
 *  @return The initialized `UINib` object or `nil` if there were errors during
 *  initialization or the nib file could not be located.
 */
+ (UINib *)nib;

/**
 *  Returns the default string used to identify the reusable footer view.
 *
 *  @return The string used to identify the reusable footer view.
 */
+ (NSString *)footerReuseIdentifier;

#pragma mark - Typing indicator

/**
 *  Configures the receiver with the specified attributes for the given collection view. 
 *  Call this method after dequeuing the footer view.
 *
 *  @param ellipsisColor       The color of the typing indicator ellipsis. This value must not be `nil`.
 *  @param messageBubbleColor  The color of the typing indicator message bubble. This value must not be `nil`.
 *  @param shouldDisplayOnLeft Specifies whether the typing indicator displays on the left or right side of the collection view when displayed.
 *  @param collectionView      The collection view in which the footer view will appear. This value must not be `nil`.
 */
- (void)configureWithEllipsisColor:(UIColor *)ellipsisColor
                messageBubbleColor:(UIColor *)messageBubbleColor
               shouldDisplayOnLeft:(BOOL)shouldDisplayOnLeft
                 forCollectionView:(UICollectionView *)collectionView;

@end
