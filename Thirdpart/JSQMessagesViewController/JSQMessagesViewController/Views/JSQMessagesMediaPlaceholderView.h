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
 *  A `JSQMessagesMediaPlaceholderView` object represents a loading or placeholder
 *  view for media message objects whose media attachments are not yet available. 
 *  When sending or receiving media messages that must be uploaded or downloaded from the network,
 *  you may display this view temporarily until the media attachement is available.
 *  You should return an instance of this class from the `mediaPlaceholderView` method in
 *  the `JSQMessageMediaData` protocol.
 *
 *  @see JSQMessageMediaData.
 */
@interface JSQMessagesMediaPlaceholderView : UIView

/**
 *  Returns the activity indicator view for this placeholder view, or `nil` if it does not exist.
 */
@property (nonatomic, weak, readonly) UIActivityIndicatorView *activityIndicatorView;

/**
 *  Returns the image view for this placeholder view, or `nil` if it does not exist.
 */
@property (nonatomic, weak, readonly) UIImageView *imageView;

/**
 *  Creates a media placeholder view object with a light gray background and
 *  a centered activity indicator.
 *
 *  @discussion When initializing a `JSQMessagesMediaPlaceholderView` with this method,
 *  its imageView property will be nil.
 *
 *  @return An initialized `JSQMessagesMediaPlaceholderView` object if successful, `nil` otherwise.
 */
+ (instancetype)viewWithActivityIndicator;

/**
 *  Creates a media placeholder view object with a light gray background and
 *  a centered paperclip attachment icon.
 *
 *  @discussion When initializing a `JSQMessagesMediaPlaceholderView` with this method,
 *  its activityIndicatorView property will be nil.
 *
 *  @return An initialized `JSQMessagesMediaPlaceholderView` object if successful, `nil` otherwise.
 */
+ (instancetype)viewWithAttachmentIcon;

/**
 *  Creates a media placeholder view having the given frame, backgroundColor, and activityIndicatorView.
 *
 *  @param frame                 A rectangle defining the frame of the view. This value must be a non-zero, non-null rectangle.
 *  @param backgroundColor       The background color of the view. This value must not be `nil`.
 *  @param activityIndicatorView An initialized activity indicator to be added and centered in the view. This value must not be `nil`.
 *
 *  @return An initialized `JSQMessagesMediaPlaceholderView` object if successful, `nil` otherwise.
 */
- (instancetype)initWithFrame:(CGRect)frame
              backgroundColor:(UIColor *)backgroundColor
        activityIndicatorView:(UIActivityIndicatorView *)activityIndicatorView;

/**
 *  Creates a media placeholder view having the given frame, backgroundColor, and imageView.
 *
 *  @param frame           A rectangle defining the frame of the view. This value must be a non-zero, non-null rectangle.
 *  @param backgroundColor The background color of the view. This value must not be `nil`.
 *  @param imageView       An initialized image view to be added and centered in the view. This value must not be `nil`.
 *
 *  @return An initialized `JSQMessagesMediaPlaceholderView` object if successful, `nil` otherwise.
 */
- (instancetype)initWithFrame:(CGRect)frame
              backgroundColor:(UIColor *)backgroundColor
                    imageView:(UIImageView *)imageView;

@end
