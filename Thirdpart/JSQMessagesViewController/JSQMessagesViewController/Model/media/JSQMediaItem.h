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

//#import "JSQMessageMediaData.h"

/**
 *  The `JSQMediaItem` class is an abstract base class for media item model objects that represents
 *  a single media attachment for a user message. It provides some default behavior for media items,
 *  including a default mediaViewDisplaySize, a default mediaPlaceholderView, and view masking as
 *  specified by appliesMediaViewMaskAsOutgoing. 
 *
 *  @warning This class is intended to be subclassed. You should not use it directly.
 *
 *  @see JSQLocationMediaItem.
 *  @see JSQPhotoMediaItem.
 *  @see JSQVideoMediaItem.
 */
@interface JSQMediaItem : NSObject <NSCopying, NSCoding>

/**
 *  A boolean value indicating whether this media item should apply
 *  an outgoing or incoming bubble image mask to its media views.
 *  Specify `YES` for an outgoing mask, and `NO` for an incoming mask.
 *  The default value is `YES`.
 */
@property (assign, nonatomic) BOOL appliesMediaViewMaskAsOutgoing;

/**
 *  Initializes and returns a media item with the specified value for maskAsOutgoing.
 *
 *  @param maskAsOutgoing A boolean value indicating whether this media item should apply
 *  an outgoing or incoming bubble image mask to its media views.
 *
 *  @return An initialized `JSQMediaItem` object if successful, `nil` otherwise.
 */
- (instancetype)initWithMaskAsOutgoing:(BOOL)maskAsOutgoing;

/**
 *  Clears any media view or media placeholder view that the item has cached.
 */
- (void)clearCachedMediaViews;


/**
 *  @return An initialized `UIView` object that represents the data for this media object.
 *
 *  @discussion You may return `nil` from this method while the media data is being downloaded.
 */
- (UIView *)mediaView;

/**
 *  @return The frame size for the mediaView when displayed in a `JSQMessagesCollectionViewCell`.
 *
 *  @discussion You should return an appropriate size value to be set for the mediaView's frame
 *  based on the contents of the view, and the frame and layout of the `JSQMessagesCollectionViewCell`
 *  in which mediaView will be displayed.
 *
 *  @warning You must return a size with non-zero, positive width and height values.
 */
- (CGSize)mediaViewDisplaySize;

/**
 *  @return A placeholder media view to be displayed if mediaView is not yet available, or `nil`.
 *  For example, if mediaView will be constructed based on media data that must be downloaded,
 *  this placeholder view will be used until mediaView is not `nil`.
 *
 *  @discussion If you do not need support for a placeholder view, then you may simply return the
 *  same value here as mediaView. Otherwise, consider using `JSQMessagesMediaPlaceholderView`.
 *
 *  @warning You must not return `nil` from this method.
 *
 *  @see JSQMessagesMediaPlaceholderView.
 */
- (UIView *)mediaPlaceholderView;

/**
 *  @return An integer that can be used as a table address in a hash table structure.
 *
 *  @discussion This value must be unique for each media item with distinct contents.
 *  This value is used to cache layout information in the collection view.
 */
- (NSUInteger)mediaHash;

/**
 * 此标识用于告诉UI显示层，media数据已正常加载完成(正常是指：比如图片消息中的UIImage对象已正常加载完成，而不包括media对象
 * 已建立，但内容数据是空的这种情况（比如图片还在从网络下载中，但界面上的消息总是要先显示出来）)，不需要再次加载了。
 * <p>
 * 这种情况用于在加载图片这样的场景下：比如收到好友的图片消息，但是消息气泡已经显示在界面中了，而图片实际上还没有从网上下载完成，
 * 那么在下载完成时，刷新表格显示的时候就可以重新创建media对象，以便即时显示已下载完成的图片。但既然已经下载完成了，则在下次表格
 * 刷新时就不需要UIImage的加载过程，直接用之前已完成加载图片后的media对象就可以了，这样可以让列表变的更高效顺滑，而不需要每次刷
 * 新表格都无条件重建media对象！
 *
 * @author add by JackJiang
 */
@property (assign, nonatomic) BOOL loadComplete;

@end
