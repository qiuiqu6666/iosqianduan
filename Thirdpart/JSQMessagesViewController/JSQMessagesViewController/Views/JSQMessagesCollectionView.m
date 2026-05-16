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


#import "JSQMessagesCollectionView.h"

#import "JSQMessagesCollectionViewFlowLayout.h"
#import "JSQMessagesCollectionViewCellIncoming.h"
#import "JSQMessagesCollectionViewCellOutgoing.h"

#import "JSQMessagesTypingIndicatorFooterView.h"
#import "JSQMessagesLoadEarlierHeaderView.h"
#import "rbSystemInfoCollectionViewCell.h"

#import "UIColor+JSQMessages.h"


@interface JSQMessagesCollectionView () <JSQMessagesLoadEarlierHeaderViewDelegate>

- (void)jsq_configureCollectionView;

@end


@implementation JSQMessagesCollectionView

@dynamic dataSource;
@dynamic delegate;
@dynamic collectionViewLayout;

#pragma mark - Initialization

- (void)jsq_configureCollectionView
{
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];

    self.backgroundColor = [UIColor whiteColor];
    self.keyboardDismissMode = UIScrollViewKeyboardDismissModeNone;
    // 这句话的意思是为了不管集合视图里面的单元多不多都可以滚动，解决了值少了集合视图不能滚动的问题
    self.alwaysBounceVertical = YES;
    // 弹簧效果
    self.bounces = YES;
    
    [self registerNib:[JSQMessagesCollectionViewCellIncoming nib]
          forCellWithReuseIdentifier:[JSQMessagesCollectionViewCellIncoming cellReuseIdentifier]];
    
    [self registerNib:[JSQMessagesCollectionViewCellOutgoing nib]
          forCellWithReuseIdentifier:[JSQMessagesCollectionViewCellOutgoing cellReuseIdentifier]];
    
    [self registerNib:[JSQMessagesCollectionViewCellIncoming nib]
          forCellWithReuseIdentifier:[JSQMessagesCollectionViewCellIncoming mediaCellReuseIdentifier]];
    
    [self registerNib:[JSQMessagesCollectionViewCellOutgoing nib]
          forCellWithReuseIdentifier:[JSQMessagesCollectionViewCellOutgoing mediaCellReuseIdentifier]];

    [self registerNib:[rbSystemInfoCollectionViewCell nib]
        forCellWithReuseIdentifier:[rbSystemInfoCollectionViewCell cellReuseIdentifier]];
    
    [self registerNib:[JSQMessagesTypingIndicatorFooterView nib]
          forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
          withReuseIdentifier:[JSQMessagesTypingIndicatorFooterView footerReuseIdentifier]];
    
    [self registerNib:[JSQMessagesLoadEarlierHeaderView nib]
          forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
          withReuseIdentifier:[JSQMessagesLoadEarlierHeaderView headerReuseIdentifier]];

    _typingIndicatorDisplaysOnLeft = YES;
    _typingIndicatorMessageBubbleColor = [UIColor jsq_messageBubbleLightGrayColor];
    _typingIndicatorEllipsisColor = [_typingIndicatorMessageBubbleColor jsq_colorByDarkeningColorWithValue:0.3f];

    _loadEarlierMessagesHeaderTextColor = [UIColor jsq_messageBubbleBlueColor];
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
    self = [super initWithFrame:frame collectionViewLayout:layout];
    if (self) {
        [self jsq_configureCollectionView];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self jsq_configureCollectionView];
}

#pragma mark - Typing indicator

- (JSQMessagesTypingIndicatorFooterView *)dequeueTypingIndicatorFooterViewForIndexPath:(NSIndexPath *)indexPath
{
    JSQMessagesTypingIndicatorFooterView *footerView = [super dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                                                                 withReuseIdentifier:[JSQMessagesTypingIndicatorFooterView footerReuseIdentifier]
                                                                                        forIndexPath:indexPath];

    [footerView configureWithEllipsisColor:self.typingIndicatorEllipsisColor
                        messageBubbleColor:self.typingIndicatorMessageBubbleColor
                       shouldDisplayOnLeft:self.typingIndicatorDisplaysOnLeft
                         forCollectionView:self];

    return footerView;
}

#pragma mark - Load earlier messages header

- (JSQMessagesLoadEarlierHeaderView *)dequeueLoadEarlierMessagesViewHeaderForIndexPath:(NSIndexPath *)indexPath
{
    JSQMessagesLoadEarlierHeaderView *headerView = [super dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                                             withReuseIdentifier:[JSQMessagesLoadEarlierHeaderView headerReuseIdentifier]
                                                                                    forIndexPath:indexPath];

    headerView.loadButton.tintColor = self.loadEarlierMessagesHeaderTextColor;
    headerView.delegate = self;

    return headerView;
}

#pragma mark - Load earlier messages header delegate

- (void)headerView:(JSQMessagesLoadEarlierHeaderView *)headerView didPressLoadButton:(UIButton *)sender
{
    if ([self.delegate respondsToSelector:@selector(collectionView:header:didTapLoadEarlierMessagesButton:)]) {
        [self.delegate collectionView:self header:headerView didTapLoadEarlierMessagesButton:sender];
    }
}

#pragma mark - Messages collection view cell delegate

- (void)messagesCollectionViewCellDidTapAvatar:(UICollectionViewCell *)cell
{
    NSIndexPath *indexPath = [self indexPathForCell:cell];
    if (indexPath == nil) {
        return;
    }

    // 是普通聊天消息
    if([cell isKindOfClass:JSQMessagesCollectionViewCell.class])
    {
        JSQMessagesCollectionViewCell *theCell = (JSQMessagesCollectionViewCell *)cell;
        [self.delegate collectionView:self
                didTapAvatarImageView:theCell.avatarImageView
                          atIndexPath:indexPath];
    }
}

- (void)messagesCollectionViewCellDidTapMessageBubble:(UICollectionViewCell *)cell
{
    NSIndexPath *indexPath = [self indexPathForCell:cell];
    if (indexPath == nil) {
        return;
    }

    // 是普通聊天消息
    if([cell isKindOfClass:JSQMessagesCollectionViewCell.class])
    {
//        JSQMessagesCollectionViewCell *theCell = (JSQMessagesCollectionViewCell *)cell;
        [self.delegate collectionView:self didTapMessageBubbleAtIndexPath:indexPath];
    }
}

- (void)messagesCollectionViewCellDidTapCell:(UICollectionViewCell *)cell atPosition:(CGPoint)position
{
    NSIndexPath *indexPath = [self indexPathForCell:cell];
    if (indexPath == nil) {
        return;
    }

    // 是普通聊天消息
    if([cell isKindOfClass:JSQMessagesCollectionViewCell.class])
    {
        [self.delegate collectionView:self
                didTapCellAtIndexPath:indexPath
                        touchLocation:position];
    }
}

- (void)rb_messagesCollectionViewCellDidLongPressCell:(UICollectionViewCell *)cell atPosition:(CGPoint)position
{
    NSIndexPath *indexPath = [self indexPathForCell:cell];
    if (indexPath == nil) {
        return;
    }

    // 是普通聊天消息
    if([cell isKindOfClass:JSQMessagesCollectionViewCell.class])
    {
        [self.delegate rb_collectionView:self
                didLongPressCellAtIndexPath:indexPath
                           touchLocation:position cell:cell];
    }
}

/**
 *  Tells the delegate that the 消息引用内容 of the cell has been tapped.
 *
 *  @param cell The cell that received the tap touch event.
 *  @since 9.0
 */
- (void)rb_messagesCollectionViewCellDidTapQuote:(UICollectionViewCell *)cell// add by jackjiang
{
    NSIndexPath *indexPath = [self indexPathForCell:cell];
    if (indexPath == nil) {
        return;
    }

    // 是普通聊天消息
    if([cell isKindOfClass:JSQMessagesCollectionViewCell.class])
    {
        [self.delegate rb_collectionView:self
                didTapQuoteAtIndexPath:indexPath cell:cell];
    }
}

// since v4.3，原库中的长按菜单仅针对的是文本消息（准确地说是文本消息气泡中的TextView组件），且这个事件并不能按官
// 方的说明准确定制等，所以目前已取消。由v4.3开始的聊天消息统一长按手势及相关逻辑取代。
//- (void)messagesCollectionViewCell:(UICollectionViewCell *)cell didPerformAction:(SEL)action withSender:(id)sender
//{
//    NSIndexPath *indexPath = [self indexPathForCell:cell];
//    if (indexPath == nil) {
//        return;
//    }
//
//    // 是普通聊天消息
//    if([cell isKindOfClass:JSQMessagesCollectionViewCell.class])
//    {
//        [self.delegate collectionView:self
//                        performAction:action
//                   forItemAtIndexPath:indexPath
//                           withSender:sender];
//    }
//}

@end
