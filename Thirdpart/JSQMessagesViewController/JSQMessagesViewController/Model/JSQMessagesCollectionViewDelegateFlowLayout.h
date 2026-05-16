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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class JSQMessagesCollectionView;
@class JSQMessagesCollectionViewFlowLayout;
@class JSQMessagesCollectionViewCell;
@class JSQMessagesLoadEarlierHeaderView;


/**
*  The `JSQMessagesCollectionViewDelegateFlowLayout` protocol defines methods that allow you to
*  manage additional layout information for the collection view and respond to additional actions on its items.
*  The methods of this protocol are all optional.
*/
@protocol JSQMessagesCollectionViewDelegateFlowLayout <UICollectionViewDelegateFlowLayout>

@optional

/**
 *  本方法返回的是`cellNicknameLabel`（也就是消息气泡上方的昵称标签）的高度，控制此值就可以控制时间标签的高度或可见性（0就不可见了）。
 */
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellNicknameLabelAtIndexPath:(NSIndexPath *)indexPath;

/**
 *  本方法返回的是`cellTopLabel`（也就是消息气泡上方的时间标签）的高度，控制此值就可以控制时间标签的高度或可见性（0就不可见了）。
 *  Asks the delegate for the height of the `cellTopLabel` for the item at the specified indexPath.
 *
 *  @param collectionView       The collection view object displaying the flow layout.
 *  @param collectionViewLayout The layout object requesting the information.
 *  @param indexPath            The index path of the item.
 *
 *  @return The height of the `cellTopLabel` for the item at indexPath.
 *
 *  @see JSQMessagesCollectionViewCell.
 */
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath;

/**
*  本方法返回的是`messageBubbleTopLabel`（也就是消息气泡上方的用户昵称标签）的高度，控制此值就可以控制用户昵称标签的高度或可见性（0就不可见了）。
 *  Asks the delegate for the height of the `messageBubbleTopLabel` for the item at the specified indexPath.
 *
 *  @param collectionView       The collection view object displaying the flow layout.
 *  @param collectionViewLayout The layout object requesting the information.
 *  @param indexPath            The index path of the item.
 *
 *  @return The height of the `messageBubbleTopLabel` for the item at indexPath.
 *
 *  @see JSQMessagesCollectionViewCell.
 */
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath;

/**
 *  Asks the delegate for the height of the `cellBottomLabel` for the item at the specified indexPath.
 *
 *  @param collectionView       The collection view object displaying the flow layout.
 *  @param collectionViewLayout The layout object requesting the information.
 *  @param indexPath            The index path of the item.
 *
 *  @return The height of the `cellBottomLabel` for the item at indexPath.
 *
 *  @see JSQMessagesCollectionViewCell.
 */
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath;

/**
 *  气泡下方「时间 + 已读/发送状态」条占用的额外高度（不含引用区 topGap，引用区仍用 topGapForQuoteContainer）。
 *  未实现时按 0 处理。须与 cell 内 bubbleTimeStatusView 的垂直占位一致。
 */
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForBubbleBelowTimeStatusStripAtIndexPath:(NSIndexPath *)indexPath;

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout topGapForQuoteContainerAtIndexPath:(NSIndexPath *)indexPath;

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForQuoteContainerAtIndexPath:(NSIndexPath *)indexPath;

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout widthForQuoteIconContainerAtIndexPath:(NSIndexPath *)indexPath;

/**
 *  群聊消息分组位置，用于控制头像/昵称等。仅群聊时布局会询问；未实现或非群聊不调用。
 *  返回值：0 = single（单独），1 = top（组内第一条），2 = middle（组内中间），3 = bottom（组内最后一条）。
 *  Layout 会根据 1、2 隐藏头像占位。
 */
- (NSInteger)collectionView:(JSQMessagesCollectionView *)collectionView
                     layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout messageGroupPositionAtIndexPath:(NSIndexPath *)indexPath;

/*
 *  Notifies the delegate that the avatar image view at the specified indexPath did receive a tap event.
 *
 *  @param collectionView  The collection view object that is notifying the delegate of the tap event.
 *  @param avatarImageView The avatar image view that was tapped.
 *  @param indexPath       The index path of the item for which the avatar was tapped.
 */
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapAvatarImageView:(UIImageView *)avatarImageView atIndexPath:(NSIndexPath *)indexPath;

/**
 *  Notifies the delegate that the message bubble at the specified indexPath did receive a tap event.
 *
 *  @param collectionView The collection view object that is notifying the delegate of the tap event.
 *  @param indexPath      The index path of the item for which the message bubble was tapped.
 */
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath;

/**
 *  Notifies the delegate that the cell at the specified indexPath did receive a tap event at the specified touchLocation.
 *
 *  @param collectionView The collection view object that is notifying the delegate of the tap event.
 *  @param indexPath      The index path of the item for which the message bubble was tapped.
 *  @param touchLocation  The location of the touch event in the cell's coordinate system.
 *
 *  @warning This method is *only* called if position is *not* within the bounds of the cell's
 *  avatar image view or message bubble image view. In other words, this method is *not* called when the cell's
 *  avatar or message bubble are tapped. There are separate delegate methods for these two cases.
 *
 *  @see `collectionView:didTapAvatarImageView:atIndexPath:`
 *  @see `collectionView:didTapMessageBubbleAtIndexPath:atIndexPath:`
 */
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapCellAtIndexPath:(NSIndexPath *)indexPath touchLocation:(CGPoint)touchLocation;

/**
 * 长按消息列表单元回调通知。
 *
 * @param collectionView The collection view object that is notifying the delegate of the long press event.
 * @param indexPath      The index path of the item for which the message bubble was tapped.
 * @param touchLocation  The location of the touch event in the cell's coordinate system.
 * @since 4.3
 */
- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView didLongPressCellAtIndexPath:(NSIndexPath *)indexPath touchLocation:(CGPoint)touchLocation cell:(UICollectionViewCell *)cell;

/**
 点击引用的消息内容。
 */
- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView didTapQuoteAtIndexPath:(NSIndexPath *)indexPath cell:(UICollectionViewCell *)cell;

/**
 *  Notifies the delegate that the collection view's header did receive a tap event.
 *
 *  @param collectionView The collection view object that is notifying the delegate of the tap event.
 *  @param headerView     The header view in the collection view.
 *  @param sender         The button that was tapped.
 */
- (void)collectionView:(JSQMessagesCollectionView *)collectionView
                header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender;

@end
