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


#import "JSQMessagesCollectionViewLayoutAttributes.h"

@implementation JSQMessagesCollectionViewLayoutAttributes

#pragma mark - Init

- (instancetype)init {
    self = [super init];
    if (self) {
    _messageBubbleFont = [UIFont systemFontOfSize:16.0f]; // 实际由 FlowLayout 赋值，此处仅占位
        _messageBubbleContainerViewWidth = 320.0f;
        _messageBubbleContainerViewHeight = 0.0f;
    }
    return self;
}

#pragma mark - Setters

- (void)setMessageBubbleFont:(UIFont *)messageBubbleFont
{
    NSParameterAssert(messageBubbleFont != nil);
    _messageBubbleFont = messageBubbleFont;
}

- (void)setMessageBubbleContainerViewWidth:(CGFloat)messageBubbleContainerViewWidth
{
    // FIXME: 240827 jack偶现了一次打开聊天界面查看离线消息时崩溃的问题，原因就是以下Assert失败，暂时还未找到复现的方法，
    //        目前绕开这个bug的方法，先暂时回避这个assert，给个强行纠正的值，后面找到复现方法后，再一并彻底解决之！
//    NSParameterAssert(messageBubbleContainerViewWidth > 0.0f);// 以上bug彻底解决后去掉以下的if段并恢复本assert()代码行！
    //* FIXME: START
    if(messageBubbleContainerViewWidth <= 0.0f){
        messageBubbleContainerViewWidth = 320.0f;
        NSLog(@"FIXME：【bug复现】错误的messageBubbleContainerViewWidth=%f，详见方法 “setMessageBubbleContainerViewWidth: ”", messageBubbleContainerViewWidth);
    }
    //* FIXME: END
    
    _messageBubbleContainerViewWidth = ceilf(messageBubbleContainerViewWidth);
}

- (void)setIncomingAvatarViewSize:(CGSize)incomingAvatarViewSize
{
    NSParameterAssert(incomingAvatarViewSize.width >= 0.0f && incomingAvatarViewSize.height >= 0.0f);
    _incomingAvatarViewSize = [self jsq_correctedAvatarSizeFromSize:incomingAvatarViewSize];
}

- (void)setOutgoingAvatarViewSize:(CGSize)outgoingAvatarViewSize
{
    NSParameterAssert(outgoingAvatarViewSize.width >= 0.0f && outgoingAvatarViewSize.height >= 0.0f);
    _outgoingAvatarViewSize = [self jsq_correctedAvatarSizeFromSize:outgoingAvatarViewSize];
}

- (void)setCellTopLabelHeight:(CGFloat)cellTopLabelHeight
{
    NSParameterAssert(cellTopLabelHeight >= 0.0f);
    _cellTopLabelHeight = [self jsq_correctedLabelHeightForHeight:cellTopLabelHeight];
}

- (void)setCellNicknameLabelHeight:(CGFloat)cellNicknameLabelHeight
{
    NSParameterAssert(cellNicknameLabelHeight >= 0.0f);
    _cellNicknameLabelHeight = [self jsq_correctedLabelHeightForHeight:cellNicknameLabelHeight];
}

- (void)setMessageBubbleTopLabelHeight:(CGFloat)messageBubbleTopLabelHeight
{
    NSParameterAssert(messageBubbleTopLabelHeight >= 0.0f);
    _messageBubbleTopLabelHeight = [self jsq_correctedLabelHeightForHeight:messageBubbleTopLabelHeight];
}

- (void)setCellBottomLabelHeight:(CGFloat)cellBottomLabelHeight
{
    NSParameterAssert(cellBottomLabelHeight >= 0.0f);
    _cellBottomLabelHeight = [self jsq_correctedLabelHeightForHeight:cellBottomLabelHeight];
}

- (void)setQuoteContainerTopGap:(CGFloat)quoteContainerTopGap
{
    NSParameterAssert(quoteContainerTopGap >= 0.0f);
    _quoteContainerTopGap = [self jsq_correctedLabelHeightForHeight:quoteContainerTopGap];
}

- (void)setQuoteContainerHeight:(CGFloat)quoteContainerHeight
{
    NSParameterAssert(quoteContainerHeight >= 0.0f);
    _quoteContainerHeight = [self jsq_correctedLabelHeightForHeight:quoteContainerHeight];
}

- (void)setQuoteIconContainerWidth:(CGFloat)quoteIconContainerWidth
{
    NSParameterAssert(quoteIconContainerWidth >= 0.0f);
    _quoteIconContainerWidth = [self jsq_correctedLabelHeightForHeight:quoteIconContainerWidth];
}

#pragma mark - Utilities

- (CGSize)jsq_correctedAvatarSizeFromSize:(CGSize)size
{
    return CGSizeMake(ceilf(size.width), ceilf(size.height));
}

- (CGFloat)jsq_correctedLabelHeightForHeight:(CGFloat)height
{
    return ceilf(height);
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    
    if (self.representedElementCategory == UICollectionElementCategoryCell) {
        JSQMessagesCollectionViewLayoutAttributes *layoutAttributes = (JSQMessagesCollectionViewLayoutAttributes *)object;
        
        if (![layoutAttributes.messageBubbleFont isEqual:self.messageBubbleFont]
            || !UIEdgeInsetsEqualToEdgeInsets(layoutAttributes.textViewFrameInsets, self.textViewFrameInsets)
            || !UIEdgeInsetsEqualToEdgeInsets(layoutAttributes.textViewTextContainerInsets, self.textViewTextContainerInsets)
            || !CGSizeEqualToSize(layoutAttributes.incomingAvatarViewSize, self.incomingAvatarViewSize)
            || !CGSizeEqualToSize(layoutAttributes.outgoingAvatarViewSize, self.outgoingAvatarViewSize)
            || (int)layoutAttributes.messageBubbleContainerViewWidth != (int)self.messageBubbleContainerViewWidth
            || (int)layoutAttributes.cellTopLabelHeight != (int)self.cellTopLabelHeight
            || (int)layoutAttributes.cellNicknameLabelHeight != (int)self.cellNicknameLabelHeight
            || (int)layoutAttributes.messageBubbleTopLabelHeight != (int)self.messageBubbleTopLabelHeight
            || (int)layoutAttributes.cellBottomLabelHeight != (int)self.cellBottomLabelHeight
            || (int)layoutAttributes.quoteContainerTopGap != (int)self.quoteContainerTopGap
            || (int)layoutAttributes.quoteContainerHeight != (int)self.quoteContainerHeight
            || (int)layoutAttributes.quoteIconContainerWidth != (int)self.quoteIconContainerWidth
            || layoutAttributes.messageBubbleTimeFitsOnSameLine != self.messageBubbleTimeFitsOnSameLine
            || layoutAttributes.rb_bubbleTimeStatusBelowTextBubble != self.rb_bubbleTimeStatusBelowTextBubble
            || layoutAttributes.messageGroupPosition != self.messageGroupPosition
            || (int)layoutAttributes.messageBubbleHorizontalOffset != (int)self.messageBubbleHorizontalOffset)
        {
            return NO;
        }
    }
    
    return [super isEqual:object];
}

- (NSUInteger)hash
{
    return [self.indexPath hash];
}


#pragma mark - NSCopying
// 实现深拷贝
- (instancetype)copyWithZone:(NSZone *)zone
{
    JSQMessagesCollectionViewLayoutAttributes *copy = [super copyWithZone:zone];
    
    if (copy.representedElementCategory != UICollectionElementCategoryCell) {
        return copy;
    }
    
    copy.messageBubbleFont = self.messageBubbleFont;
    copy.messageBubbleContainerViewWidth = self.messageBubbleContainerViewWidth;
    copy.messageBubbleContainerViewHeight = self.messageBubbleContainerViewHeight;
    copy.textViewFrameInsets = self.textViewFrameInsets;
    copy.textViewTextContainerInsets = self.textViewTextContainerInsets;
    copy.incomingAvatarViewSize = self.incomingAvatarViewSize;
    copy.outgoingAvatarViewSize = self.outgoingAvatarViewSize;
    copy.cellTopLabelHeight = self.cellTopLabelHeight;
    copy.cellNicknameLabelHeight = self.cellNicknameLabelHeight;
    copy.messageBubbleTopLabelHeight = self.messageBubbleTopLabelHeight;
    copy.cellBottomLabelHeight = self.cellBottomLabelHeight;
    copy.quoteContainerTopGap = self.quoteContainerTopGap;
    copy.quoteContainerHeight = self.quoteContainerHeight;
    copy.quoteIconContainerWidth = self.quoteIconContainerWidth;
    copy.messageBubbleTimeFitsOnSameLine = self.messageBubbleTimeFitsOnSameLine;
    copy.rb_bubbleTimeStatusBelowTextBubble = self.rb_bubbleTimeStatusBelowTextBubble;
    copy.messageGroupPosition = self.messageGroupPosition;
    copy.messageBubbleHorizontalOffset = self.messageBubbleHorizontalOffset;
    
    return copy;
}

@end
