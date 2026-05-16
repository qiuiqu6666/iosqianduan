//telegram @wz662
//
//  rbSystemInfoCollectionViewCell.m
//  RainbowChat4i
//
//  Created by JackJiang on 2025/5/28.
//  Copyright © 2025年 JackJiang. All rights reserved.
//

#import "rbSystemInfoCollectionViewCell.h"
#import "JSQMessagesCollectionViewLayoutAttributes.h"


@implementation rbSystemInfoCollectionViewCell

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];
}

+ (NSString *)cellReuseIdentifier
{
    return NSStringFromClass([self class]);
}

+ (UIFont *)getRbSystemInfoCollectionViewCell_textViewFont
{
//    return [UIFont systemFontOfSize:12.0f];
    return [UIFont systemFontOfSize:13.0f];// 统信息消息的文本消息字体大小
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    //###### Fix: 注释掉此行代码的原因是，如果设置此属性为NO，则控制台下将报"Changing the translatesAutoresizingMaskIntoConstraints property of a UICollectionViewCell that is managed by a UICollectionView is not supported, and will result in incorrect self-sizing"这样的警告，去掉后则不会报。
    //# 注释掉此行后带来的影响，需要进一步测试的观察，如对消息气泡的大小显示有影响，则应撤销此次注释！
    //# 参考：JSQMessagesCollectionViewCell.m 中已经做了同样的修复
//    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    //###### END

//    self.backgroundColor = [UIColor grayColor];
//
//    self.cellTopLabel.textAlignment = NSTextAlignmentCenter;
//    self.cellTopLabel.font = [UIFont boldSystemFontOfSize:12.0f];
//    self.cellTopLabel.textColor = HexColor(0xdd5149);

    // 设置字体大小
    self.textView.font = [rbSystemInfoCollectionViewCell getRbSystemInfoCollectionViewCell_textViewFont];
}

- (void)dealloc
{
    _cellTopLabel = nil;
    _textView = nil;
}

#pragma mark - Collection view cell

// 当cell从可视区滑出时，把内容清掉，防止表格显示错乱，这是常识
- (void)prepareForReuse
{
    [super prepareForReuse];

    self.cellTopLabel.text = nil;

    self.textView.dataDetectorTypes = UIDataDetectorTypeNone;
    self.textView.text = nil;
    self.textView.attributedText = nil;
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    return layoutAttributes;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.textView.textContainerInset = UIEdgeInsetsMake(rbSystemInfoCollectionViewCell_textView_textContainerInset_TOP,
                                                        rbSystemInfoCollectionViewCell_textView_textContainerInset_LEFT,
                                                        rbSystemInfoCollectionViewCell_textView_textContainerInset_BOTTOM,
                                                        rbSystemInfoCollectionViewCell_textView_textContainerInset_RIGHT);
}

// 本方法将最终决定整个cell ui的显示效果（layoutAttributes是在JSQMessagesCollectionViewFlowLayout的
// jsq_configureMessageCellLayoutAttributes:方法中被计算并准备好了的，本方法中直接使用）
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];

    JSQMessagesCollectionViewLayoutAttributes *customAttributes = (JSQMessagesCollectionViewLayoutAttributes *)layoutAttributes;

//    if (self.textView.font != customAttributes.messageBubbleFont) {
//        self.textView.font = customAttributes.messageBubbleFont;
//    }

    // 文本区衬距，这个决定了文本区4周的空白（在JSQMessageBubbleSizeCalculator中计算时将计入此值）
    self.textView.textContainerInset = UIEdgeInsetsMake(rbSystemInfoCollectionViewCell_textView_textContainerInset_TOP
                                                        , rbSystemInfoCollectionViewCell_textView_textContainerInset_LEFT
                                                        , rbSystemInfoCollectionViewCell_textView_textContainerInset_BOTTOM
                                                        , rbSystemInfoCollectionViewCell_textView_textContainerInset_RIGHT);

//    NSLog(@"【前】self.textView.textContainerInset[%f,%f,%f,%f], customAttributes.textViewTextContainerInsets[%f,%f,%f,%f]", self.textView.textContainerInset.top, self.textView.textContainerInset.right, self.textView.textContainerInset.bottom, self.textView.textContainerInset.left, customAttributes.textViewTextContainerInsets.top, customAttributes.textViewTextContainerInsets.right, customAttributes.textViewTextContainerInsets.bottom, customAttributes.textViewTextContainerInsets.left);
//
//    if (!UIEdgeInsetsEqualToEdgeInsets(self.textView.textContainerInset, customAttributes.textViewTextContainerInsets)) {
//        self.textView.textContainerInset = customAttributes.textViewTextContainerInsets;
//    }
//
//    NSLog(@"【后】self.textView.textContainerInset[%f,%f,%f,%f]", self.textView.textContainerInset.top, self.textView.textContainerInset.right, self.textView.textContainerInset.bottom, self.textView.textContainerInset.left);

    

//    self.textViewFrameInsets = customAttributes.textViewFrameInsets;

    // 设置文本组件的实际显示宽度（通过约束实现的动态布局自适应），文本区计算的有多在就显示多大，这个约束是在XIB中设置好的哦！
    [self jsq_updateConstraint:self.messageBubbleContainerViewConstraint
                  withConstant:customAttributes.messageBubbleContainerViewWidth];
//
    // 设置日期时间显示组件的高度约束（共用了普通聊天消息的Attributes属性^_^），此值将会动态决定而非固定哦
    [self jsq_updateConstraint:self.cellTopLabelHeightConstraint
                  withConstant:customAttributes.cellTopLabelHeight];
//
//    [self jsq_updateConstraint:self.messageBubbleTopLabelHeightConstraint
//                  withConstant:customAttributes.messageBubbleTopLabelHeight];
//
//    [self jsq_updateConstraint:self.cellBottomLabelHeightConstraint
//                  withConstant:customAttributes.cellBottomLabelHeight];
//
//    if ([self isKindOfClass:[JSQMessagesCollectionViewCellIncoming class]]) {
//        self.avatarViewSize = customAttributes.incomingAvatarViewSize;
//    }
//    else if ([self isKindOfClass:[JSQMessagesCollectionViewCellOutgoing class]]) {
//        self.avatarViewSize = customAttributes.outgoingAvatarViewSize;
//    }

    
}


#pragma mark - Utilities

- (void)jsq_updateConstraint:(NSLayoutConstraint *)constraint withConstant:(CGFloat)constant
{
    if (constraint.constant == constant) {
        return;
    }

    constraint.constant = constant;
}


@end
