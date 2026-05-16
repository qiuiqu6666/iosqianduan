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


#import <UIKit/UIKit.h>

#import "JSQMessagesLabel.h"
#import "JSQMessagesCellTextView.h"

@class JSQMessagesCollectionViewCell;

/** 表格单元中消息引用内容容器顶部的空白高度 */
FOUNDATION_EXPORT const CGFloat kJSQMessagesCollectionViewCellQuoteContinerTopGapDefault;
/** 表格单元中消息引用内容容器默认高度（仅文本，无图标的情况） */
FOUNDATION_EXPORT const CGFloat kJSQMessagesCollectionViewCellQuoteContinerHeightDefault_onlyText;
/** 表格单元中消息引用内容容器默认高度（有文本且有图标的情况） */
FOUNDATION_EXPORT const CGFloat kJSQMessagesCollectionViewCellQuoteContinerHeightDefault_hasIcon;
/** 表格单元中消息引用内容中图标容器的默认宽度 */
FOUNDATION_EXPORT const CGFloat kJSQMessagesCollectionViewCellQuoteIconContinerWidthDefault;


/**
 *  The `JSQMessagesCollectionViewCellDelegate` protocol defines methods that allow you to manage
 *  additional interactions within the collection view cell.
 */
@protocol JSQMessagesCollectionViewCellDelegate <NSObject>

@required

/**
 *  Tells the delegate that the avatarImageView of the cell has been tapped.
 *
 *  @param cell The cell that received the tap touch event.
 */
- (void)messagesCollectionViewCellDidTapAvatar:(UICollectionViewCell *)cell;

/**
 *  Tells the delegate that the message bubble of the cell has been tapped.
 *
 *  @param cell The cell that received the tap touch event.
 */
- (void)messagesCollectionViewCellDidTapMessageBubble:(UICollectionViewCell *)cell;

/**
 *  Tells the delegate that the cell has been tapped at the point specified by position.
 *
 *  @param cell The cell that received the tap touch event.
 *  @param position The location of the received touch in the cell's coordinate system.
 *
 *  @discussion This method is *only* called if position is *not* within the bounds of the cell's
 *  avatar image view or message bubble image view. In other words, this method is *not* called when the cell's
 *  avatar or message bubble are tapped.
 *
 *  @see `messagesCollectionViewCellDidTapAvatar:`
 *  @see `messagesCollectionViewCellDidTapMessageBubble:`
 */
- (void)messagesCollectionViewCellDidTapCell:(UICollectionViewCell *)cell atPosition:(CGPoint)position;

/**
 * 告之delegate该列表cell已被长按的位置等信息。
 *
 * @since 4.3
 */
- (void)rb_messagesCollectionViewCellDidLongPressCell:(UICollectionViewCell *)cell atPosition:(CGPoint)position;

/**
 *  Tells the delegate that the 消息引用内容 of the cell has been tapped.
 *
 *  @param cell The cell that received the tap touch event.
 *  @since 9.0
 */
- (void)rb_messagesCollectionViewCellDidTapQuote:(UICollectionViewCell *)cell;// add by jackjiang

// since v4.3，原库中的长按菜单仅针对的是文本消息（准确地说是文本消息气泡中的TextView组件），且这个事件并不能按官
// 方的说明准确定制等，所以目前已取消。由v4.3开始的聊天消息统一长按手势及相关逻辑取代。
///**
// *  Tells the delegate that an actions has been selected from the menu of this cell.
// *  This method is automatically called for any registered actions.
// *
// *  @param cell The cell that displayed the menu.
// *  @param action The action that has been performed.
// *  @param sender The object that initiated the action.
// *
// *  @see `JSQMessagesCollectionViewCell`
// */
//- (void)messagesCollectionViewCell:(UICollectionViewCell *)cell didPerformAction:(SEL)action withSender:(id)sender;

@end


/**
 *  The `JSQMessagesCollectionViewCell` is an abstract base class that presents the content for
 *  a single message data item when that item is within the collection view’s visible bounds.
 *  The layout and presentation of cells is managed by the collection view and its corresponding layout object.
 *
 *  @warning This class is intended to be subclassed. You should not use it directly.
 *
 *  @see JSQMessagesCollectionViewCellIncoming.
 *  @see JSQMessagesCollectionViewCellOutgoing.
 */
@interface JSQMessagesCollectionViewCell : UICollectionViewCell

/**
 *  The object that acts as the delegate for the cell.
 */
@property (weak, nonatomic) id<JSQMessagesCollectionViewCellDelegate> delegate;

/**
 *  Returns the label that is pinned to the top of the cell.
 *  This label is most commonly used to display message timestamps.
 */
@property (weak, nonatomic, readonly) JSQMessagesLabel *cellTopLabel;

/**
 *  Returns the label that is pinned just above the messageBubbleImageView, and below the cellTopLabel.
 *  This label is most commonly used to display the message sender.
 */
@property (weak, nonatomic, readonly) JSQMessagesLabel *messageBubbleTopLabel;

/**
 *  Returns the label that is pinned to the bottom of the cell.
 *  This label is most commonly used to display message delivery status.
 */
@property (weak, nonatomic, readonly) JSQMessagesLabel *cellBottomLabel;

///**
// * 昵称label（目前用于群聊中）.
// *
// * @since 10.0
// */
//@property (weak, nonatomic, readonly) UILabel *cellNicknameLabel;
/**
 * 昵称label（目前用于群聊中），从UILabel换成UITextField是因为UILabel中无法设置文本内容的垂直对方方式.
 *
 * @since 10.0
 */
@property (weak, nonatomic, readonly) UITextField *cellNicknameLabel2;

/**
 *  Returns the text view of the cell. This text view contains the message body text.
 *
 *  @warning If mediaView returns a non-nil view, then this value will be `nil`.
 */
@property (weak, nonatomic, readonly) JSQMessagesCellTextView *textView;

/**
 *  Returns the bubble image view of the cell that is responsible for displaying message bubble images.
 *
 *  @warning If mediaView returns a non-nil view, then this value will be `nil`.
 */
@property (weak, nonatomic, readonly) UIImageView *messageBubbleImageView;

/**
 *  Returns the message bubble container view of the cell. This view is the superview of
 *  the cell's textView and messageBubbleImageView.
 *
 *  @discussion You may customize the cell by adding custom views to this container view.
 *  To do so, override `collectionView:cellForItemAtIndexPath:`
 *
 *  @warning You should not try to manipulate any properties of this view, for example adjusting
 *  its frame, nor should you remove this view from the cell or remove any of its subviews.
 *  Doing so could result in unexpected behavior.
 */
@property (weak, nonatomic, readonly) UIView *messageBubbleContainerView;

/**
 *  Returns the avatar image view of the cell that is responsible for displaying avatar images.
 */
@property (weak, nonatomic, readonly) UIImageView *avatarImageView;

/**
 *  Returns the avatar container view of the cell. This view is the superview of the cell's avatarImageView.
 *
 *  @discussion You may customize the cell by adding custom views to this container view.
 *  To do so, override `collectionView:cellForItemAtIndexPath:`
 *
 *  @warning You should not try to manipulate any properties of this view, for example adjusting
 *  its frame, nor should you remove this view from the cell or remove any of its subviews.
 *  Doing so could result in unexpected behavior.
 */
@property (weak, nonatomic, readonly) UIView *avatarContainerView;

/** 消息引用容器组件 */
@property (weak, nonatomic, readonly) UIView *quoteContainerView;
/** 消息引用文本内容组件 */
@property (weak, nonatomic, readonly) UILabel *quoteContentLabel;
/** 消息引用图标组件 */
@property (weak, nonatomic, readonly) UIImageView *quoteIconView;
/** 消息引用播放图标组件（用于引用的短视频消息时） */
@property (weak, nonatomic, readonly) UIImageView *quotePlayIconView;

/**
 *  The media view of the cell. This view displays the contents of a media message.
 *
 *  @warning If this value is non-nil, then textView and messageBubbleImageView will both be `nil`.
 */
@property (weak, nonatomic) UIView *mediaView;

#pragma mark - 多选模式属性

/** 是否处于多选模式 */
@property (nonatomic, assign) BOOL multiSelectMode;

/** 在多选模式下，当前cell是否被选中 */
@property (nonatomic, assign) BOOL multiSelected;

/**
 *  气泡内部的时间+已读状态视图，显示在气泡右下角。
 *  内部包含：tag=1001 的 UILabel（时间）、tag=1002 的 UIImageView（已读/未读图标）、tag=1003 的 UILabel（文字状态）
 */
@property (nonatomic, strong) UIView *bubbleTimeStatusView;

/**
 *  列表滚动结束后调用：补算气泡内时间/已读与文字避让区。长文「与末行同行」时 layoutSubviews 在滚动中会跳过，避免与 layoutManager 反复交互。
 */
- (void)rb_refreshBubbleTimeLayoutIfNeeded;

/**
 *  Returns the underlying gesture recognizer for tap gestures in the avatarImageView of the cell.
 *  This gesture handles the tap event for the avatarImageView and notifies the cell's delegate.
 */
@property (weak, nonatomic, readonly) UITapGestureRecognizer *tapGestureRecognizer;

#pragma mark - Class methods

/**
 *  Returns the `UINib` object initialized for the cell.
 *
 *  @return The initialized `UINib` object or `nil` if there were errors during
 *  initialization or the nib file could not be located.
 */
+ (UINib *)nib;

/**
 *  Returns the default string used to identify a reusable cell for text message items.
 *
 *  @return The string used to identify a reusable cell.
 */
+ (NSString *)cellReuseIdentifier;

/**
 *  Returns the default string used to identify a reusable cell for media message items.
 *
 *  @return The string used to identify a reusable cell.
 */
+ (NSString *)mediaCellReuseIdentifier;

///**
// *  Registers an action to be available in the cell's menu.
// *
// *  @param action The selector to register with the cell.
// *
// *  @discussion Non-standard or non-system actions must be added to the `UIMenuController` manually.
// *  You can do this by creating a new `UIMenuItem` and adding it via the controller's `menuItems` property.
// *
// *  @warning Note that all message cells share the all actions registered here.
// */
// 20211115日JackJiang注：经实验和证实，此长按菜单，在原本的JSQ库中只是针对文本聊天消息（具全说只针对文本消息气泡那个TextView消息内容显示组件）
//                      ，且经参考此链接：https://github.com/jessesquires/JSQMessagesViewController/issues/1790，添加的定义MenuItem
//                      也并不生效。总之这个原为默认的长菜单及相关方法很鸡肋，干掉算了！！
//+ (void)registerMenuAction:(SEL)action;

@end
