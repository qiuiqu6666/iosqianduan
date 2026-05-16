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

/**
 *  A `JSQMessagesCollectionViewLayoutAttributes` is an object that manages the layout-related attributes
 *  for a given `JSQMessagesCollectionViewCell` in a `JSQMessagesCollectionView`.
 */
@interface JSQMessagesCollectionViewLayoutAttributes : UICollectionViewLayoutAttributes <NSCopying>

/**
 *  The font used to display the body of a text message in a message bubble within a `JSQMessagesCollectionViewCell`.
 *  This value must not be `nil`.
 */
@property (strong, nonatomic) UIFont *messageBubbleFont;

/**
 *  The width of the `messageBubbleContainerView` of a `JSQMessagesCollectionViewCell`.
 *  This value should be greater than `0.0`.
 *
 *  @see JSQMessagesCollectionViewCell.
 */
@property (assign, nonatomic) CGFloat messageBubbleContainerViewWidth;

/**
 *  媒体消息在 `setMediaView:` 中会移除 bubble 底图与 textView，XIB 里原本依赖二者撑起 `messageBubbleContainerView` 高度；
 *  若为 0 则沿用自动布局；非 0 时对气泡容器施加固定高度（与 `messageBubbleSize.height` 一致）。
 */
@property (assign, nonatomic) CGFloat messageBubbleContainerViewHeight;

/**
 *  The inset of the text container's layout area within the text view's content area in a `JSQMessagesCollectionViewCell`. 
 *  The specified inset values should be greater than or equal to `0.0`.
 */
@property (assign, nonatomic) UIEdgeInsets textViewTextContainerInsets;

/**
 *  The inset of the frame of the text view within a `JSQMessagesCollectionViewCell`. 
 *  
 *  @discussion The inset values should be greater than or equal to `0.0` and are applied in the following ways:
 *
 *  1. The right value insets the text view frame on the side adjacent to the avatar image 
 *  (or where the avatar would normally appear). For outgoing messages this is the right side, 
 *  for incoming messages this is the left side.
 *
 *  2. The left value insets the text view frame on the side opposite the avatar image 
 *  (or where the avatar would normally appear). For outgoing messages this is the left side, 
 *  for incoming messages this is the right side.
 *
 *  3. The top value insets the top of the frame.
 *
 *  4. The bottom value insets the bottom of the frame.
 */
@property (assign, nonatomic) UIEdgeInsets textViewFrameInsets;

/**
 *  The size of the `avatarImageView` of a `JSQMessagesCollectionViewCellIncoming`.
 *  The size values should be greater than or equal to `0.0`.
 *
 *  @see JSQMessagesCollectionViewCellIncoming.
 */
@property (assign, nonatomic) CGSize incomingAvatarViewSize;

/**
 *  The size of the `avatarImageView` of a `JSQMessagesCollectionViewCellOutgoing`.
 *  The size values should be greater than or equal to `0.0`.
 *
 *  @see `JSQMessagesCollectionViewCellOutgoing`.
 */
@property (assign, nonatomic) CGSize outgoingAvatarViewSize;

/**
 *  The height of the `cellTopLabel` of a `JSQMessagesCollectionViewCell`.
 *  This value should be greater than or equal to `0.0`.
 *
 *  @see JSQMessagesCollectionViewCell.
 */
@property (assign, nonatomic) CGFloat cellTopLabelHeight;

/**
 *  The height of the `messageBubbleTopLabel` of a `JSQMessagesCollectionViewCell`.
 *  This value should be greater than or equal to `0.0`.
 *
 *  @see JSQMessagesCollectionViewCell.
 */
@property (assign, nonatomic) CGFloat messageBubbleTopLabelHeight;

/** 昵称的高度约束 */
@property (assign, nonatomic) CGFloat cellNicknameLabelHeight;

/**
 *  The height of the `cellBottomLabel` of a `JSQMessagesCollectionViewCell`.
 *  This value should be greater than or equal to `0.0`.
 *
 *  @see JSQMessagesCollectionViewCell.
 */
@property (assign, nonatomic) CGFloat cellBottomLabelHeight;

/** 消息引用顶级容器顶部的空白高度约束 */
@property (assign, nonatomic) CGFloat quoteContainerTopGap;
/** 消息引用顶级容器高度约束 */
@property (assign, nonatomic) CGFloat quoteContainerHeight;
/** 消息引用图标容器宽度约束 */
@property (assign, nonatomic) CGFloat quoteIconContainerWidth;

/** 多行文本时：YES 表示时间/已读与最后一行同行（右侧有空白），NO 表示换行显示在下方 */
@property (assign, nonatomic) BOOL messageBubbleTimeFitsOnSameLine;

/** YES：文本等非媒体消息，时间条在气泡下方；NO：媒体消息，时间条在气泡内右下角（与引用区约束一致） */
@property (assign, nonatomic) BOOL rb_bubbleTimeStatusBelowTextBubble;

/** 群聊分组位置：0=single 1=top 2=middle 3=bottom，用于预留头像边距时隐藏头像图片（仅 1、2 隐藏） */
@property (assign, nonatomic) NSInteger messageGroupPosition;

/** 无尾气泡水平右偏 pt（仅 top/middle 为 2，其余 0），用于与头像对齐 */
@property (assign, nonatomic) CGFloat messageBubbleHorizontalOffset;

@end
