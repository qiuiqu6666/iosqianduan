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


#import "JSQMessagesToolbarContentView.h"
#import "UIView+JSQMessages.h"


//const CGFloat kJSQMessagesToolbarContentViewHorizontalSpacingDefault = 5.0f;

const CGFloat kJSQMessagesToolbarQuoteContainerHeightDefault = 25.0f;
const CGFloat kJSQMessagesToolbarQuoteContainerBottomGapDefault = 8.0f;

// 表情、+ 号菜单按钮可点击区域向外扩展的边距（仅扩大响应区域，不改变布局）
static const CGFloat kToolbarButtonHitAreaInset = 18.0f;


@interface JSQMessagesToolbarContentView ()

//@property (weak, nonatomic) IBOutlet JSQMessagesComposerTextView *textView;

//@property (weak, nonatomic) IBOutlet UIView *leftBarButtonContainerView;
///* xib里通过IBOutlet关联的左按钮的宽度约束（而按钮的高度由代码自行计算决定，用户无需设置，
//   具体请见JSQMessagesToolbarContentView.h中leftBarButtonItem等的注释说明）*/
//@property (weak, nonatomic) IBOutlet NSLayoutConstraint *leftBarButtonContainerViewWidthConstraint;

//@property (weak, nonatomic) IBOutlet UIView *leftBarButton2ContainerView;
///* xib里通过IBOutlet关联的左按钮2的宽度约束（而按钮的高度由代码自行计算决定，用户无需设置，
//   具体请见JSQMessagesToolbarContentView.h中leftBarButtonItem等的注释说明）*/
//@property (weak, nonatomic) IBOutlet NSLayoutConstraint *leftBarButton2ContainerViewWidthConstraint;

//@property (weak, nonatomic) IBOutlet UIView *rightBarButtonContainerView;
///* xib里通过IBOutlet关联的右按钮的宽度约束（而按钮的高度由代码自行计算决定，用户无需设置，
//   具体请见JSQMessagesToolbarContentView.h中leftBarButtonItem等的注释说明）*/
//@property (weak, nonatomic) IBOutlet NSLayoutConstraint *rightBarButtonContainerViewWidthConstraint;

//// 工具栏距离左边屏幕的距离（默认在JSQMessagesToolbarContentView.xib中设置的值为4，开发者可在代码中动态控制此值哦）
//@property (weak, nonatomic) IBOutlet NSLayoutConstraint *leftHorizontalSpacingConstraint;
//// 工具栏距离右边屏幕的距离（默认在JSQMessagesToolbarContentView.xib中设置的值为4，开发者可在代码中动态控制此值哦）
//@property (weak, nonatomic) IBOutlet NSLayoutConstraint *rightHorizontalSpacingConstraint;

@end



@implementation JSQMessagesToolbarContentView

- (void)rb_alignActionButtonsToBottom
{
    UIView *inputWrap = self.textView.superview;
    if (inputWrap == nil || inputWrap == self) return;

    NSArray *containers = @[
        self.leftBarButtonItem ? self.leftBarButtonItem.superview : (id)kCFNull,
        self.leftBarButton2Item ? self.leftBarButton2Item.superview : (id)kCFNull,
        self.rightBarButtonItem ? self.rightBarButtonItem.superview : (id)kCFNull
    ];

    NSMutableArray<NSLayoutConstraint *> *deactivate = [NSMutableArray array];
    for (id v in containers) {
        if (v == (id)kCFNull) continue;
        UIView *container = (UIView *)v;
        for (NSLayoutConstraint *c in self.constraints) {
            if ((c.firstItem == container && c.firstAttribute == NSLayoutAttributeCenterY) ||
                (c.secondItem == container && c.secondAttribute == NSLayoutAttributeCenterY)) {
                [deactivate addObject:c];
            }
        }
    }
    if (deactivate.count > 0) {
        [NSLayoutConstraint deactivateConstraints:deactivate];
    }

    NSMutableArray<NSLayoutConstraint *> *activate = [NSMutableArray array];
    for (id v in containers) {
        if (v == (id)kCFNull) continue;
        UIView *container = (UIView *)v;
        if (container.superview != self) continue;
        [activate addObject:[container.bottomAnchor constraintEqualToAnchor:inputWrap.bottomAnchor]];
    }
    if (activate.count > 0) {
        [NSLayoutConstraint activateConstraints:activate];
    }
}

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([JSQMessagesToolbarContentView class])
                          bundle:[NSBundle bundleForClass:[JSQMessagesToolbarContentView class]]];
}


#pragma mark - Hit testing（扩大表情、+ 号菜单的可点击区域）

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    CGFloat inset = -kToolbarButtonHitAreaInset;

    if (self.leftBarButtonItem && !self.leftBarButtonItem.hidden) {
        CGRect rect = [self.leftBarButtonItem convertRect:self.leftBarButtonItem.bounds toView:self];
        if (CGRectContainsPoint(CGRectInset(rect, inset, inset), point))
            return self.leftBarButtonItem;
    }
    if (self.leftBarButton2Item && !self.leftBarButton2Item.hidden) {
        CGRect rect = [self.leftBarButton2Item convertRect:self.leftBarButton2Item.bounds toView:self];
        if (CGRectContainsPoint(CGRectInset(rect, inset, inset), point))
            return self.leftBarButton2Item;
    }
    return [super hitTest:point withEvent:event];
}

#pragma mark - Initialization

- (void)awakeFromNib
{
    [super awakeFromNib];

    [self setTranslatesAutoresizingMaskIntoConstraints:NO];

    // 输入框白底圆角容器；表情按钮在 xib 中已置于容器外（输入框与语音键之间）
    UIView *inputWrap = self.textView.superview;
    if (inputWrap != self && [inputWrap isKindOfClass:[UIView class]]) {
        inputWrap.backgroundColor = [UIColor whiteColor];
        inputWrap.layer.cornerRadius = 8.0f;
        inputWrap.layer.masksToBounds = YES;
        self.textView.backgroundColor = [UIColor clearColor];
    }

    [self rb_alignActionButtonsToBottom];

//    self.leftHorizontalSpacingConstraint.constant = kJSQMessagesToolbarContentViewHorizontalSpacingDefault;
////    self.left2HorizontalSpacingConstraint.constant = kJSQMessagesToolbarContentViewHorizontalSpacingDefault;
//    self.rightHorizontalSpacingConstraint.constant = kJSQMessagesToolbarContentViewHorizontalSpacingDefault;

//    // 相当于调用本类中实现的 setBackgroundColor: 方法设置默认背景色
//    self.backgroundColor = [UIColor clearColor];
}

//#pragma mark - Setters
//
//- (void)setBackgroundColor:(UIColor *)backgroundColor
//{
//    [super setBackgroundColor:backgroundColor];
//    self.leftBarButtonContainerView.backgroundColor = backgroundColor;
//    self.leftBarButton2ContainerView.backgroundColor = backgroundColor;
//    self.rightBarButtonContainerView.backgroundColor = backgroundColor;
//}

///**
// 设置左按钮。
// */
//- (void)setLeftBarButtonItem:(UIButton *)leftBarButtonItem
//{
////    // 如果已经设置过，则先把老的从父view中移除
////    if (_leftBarButtonItem) {
////        [_leftBarButtonItem removeFromSuperview];
////    }
////
////    // 如果本次设置为nil，则将预留给左按钮的相关UI空间设为0（即在UI上取消它的占位）
////    if (!leftBarButtonItem) {
////        _leftBarButtonItem = nil;
////        self.leftHorizontalSpacingConstraint.constant = 0.0f;
////        self.leftBarButtonItemWidth = 0.0f;
////        self.leftBarButtonContainerView.hidden = YES;
////        return;
////    }
//
////    // JSQ原作者留的人性化传值：当本次传入的左按钮size为CGRectZero，则将自
////    // 动把它设置为默认的父View大小（详见原作者在.h头文件中为leftBarButtonItem写的注释）
////    if (CGRectEqualToRect(leftBarButtonItem.frame, CGRectZero)) {
////        leftBarButtonItem.frame = self.leftBarButtonContainerView.bounds;
////    }
//
////    self.leftBarButtonContainerView.hidden = NO;
////    self.leftHorizontalSpacingConstraint.constant = kJSQMessagesToolbarContentViewHorizontalSpacingDefault;
////    self.leftBarButtonItemWidth = CGRectGetWidth(leftBarButtonItem.frame);
//
//    [leftBarButtonItem setTranslatesAutoresizingMaskIntoConstraints:NO];
//
//    // 将按钮放入父View中
//    [self.leftBarButtonContainerView addSubview:leftBarButtonItem];
//    [self.leftBarButtonContainerView jsq_pinAllEdgesOfSubview:leftBarButtonItem];
//    [self setNeedsUpdateConstraints];
//
//    _leftBarButtonItem = leftBarButtonItem;
//}
//
//- (void)setLeftBarButton2Item:(UIButton *)leftBarButton2Item
//{
////    if (_leftBarButton2Item) {
////        [_leftBarButton2Item removeFromSuperview];
////    }
////
////    if (!leftBarButton2Item) {
////        _leftBarButton2Item = nil;
//////        self.left2HorizontalSpacingConstraint.constant = 0.0f;
////        self.leftBarButton2ItemWidth = 0.0f;
////        self.leftBarButton2ContainerView.hidden = YES;
////        return;
////    }
////
////    if (CGRectEqualToRect(leftBarButton2Item.frame, CGRectZero)) {
////        leftBarButton2Item.frame = self.leftBarButton2ContainerView.bounds;
////    }
//
////    self.leftBarButton2ContainerView.hidden = NO;
////    self.left2HorizontalSpacingConstraint.constant = kJSQMessagesToolbarContentViewHorizontalSpacingDefault;
////    self.leftBarButton2ItemWidth = CGRectGetWidth(leftBarButton2Item.frame);
//
//    [leftBarButton2Item setTranslatesAutoresizingMaskIntoConstraints:NO];
//
//    [self.leftBarButton2ContainerView addSubview:leftBarButton2Item];
//    [self.leftBarButton2ContainerView jsq_pinAllEdgesOfSubview:leftBarButton2Item];
//    [self setNeedsUpdateConstraints];
//
//    _leftBarButton2Item = leftBarButton2Item;
//}
//
////- (void)setLeftBarButtonItemWidth:(CGFloat)leftBarButtonItemWidth
////{
////    self.leftBarButtonContainerViewWidthConstraint.constant = leftBarButtonItemWidth;
////    [self setNeedsUpdateConstraints];
////}
////
////- (void)setLeftBarButton2ItemWidth:(CGFloat)leftBarButton2ItemWidth
////{
////    self.leftBarButton2ContainerViewWidthConstraint.constant = leftBarButton2ItemWidth;
////    [self setNeedsUpdateConstraints];
////}
//
///**
// 设置右按钮。
// */
//- (void)setRightBarButtonItem:(UIButton *)rightBarButtonItem
//{
////    // 如果已经设置过，则先把老的从父view中移除
////    if (_rightBarButtonItem) {
////        [_rightBarButtonItem removeFromSuperview];
////    }
////
////    // 如果本次设置为nil，则将预留给左按钮的相关UI空间设为0（即在UI上取消它的占位）
////    if (!rightBarButtonItem) {
////        _rightBarButtonItem = nil;
////        self.rightHorizontalSpacingConstraint.constant = 0.0f;
////        self.rightBarButtonItemWidth = 0.0f;
////        self.rightBarButtonContainerView.hidden = YES;
////        return;
////    }
//
////    // JSQ原作者留的人性化传值：当本次传入的左按钮size为CGRectZero，则将自
////    // 动把它设置为默认的父View大小（详见原作者在.h头文件中为leftBarButtonItem写的注释）
////    if (CGRectEqualToRect(rightBarButtonItem.frame, CGRectZero)) {
////        rightBarButtonItem.frame = self.rightBarButtonContainerView.bounds;
////    }
//
////    self.rightBarButtonContainerView.hidden = NO;
////    self.rightHorizontalSpacingConstraint.constant = kJSQMessagesToolbarContentViewHorizontalSpacingDefault;
////    self.rightBarButtonItemWidth = CGRectGetWidth(rightBarButtonItem.frame);
//
//    [rightBarButtonItem setTranslatesAutoresizingMaskIntoConstraints:NO];
//
//    // 将按钮放入父View中
//    [self.rightBarButtonContainerView addSubview:rightBarButtonItem];
//    [self.rightBarButtonContainerView jsq_pinAllEdgesOfSubview:rightBarButtonItem];
//    [self setNeedsUpdateConstraints];
//
//    _rightBarButtonItem = rightBarButtonItem;
//}

//- (void)setRightBarButtonItemWidth:(CGFloat)rightBarButtonItemWidth
//{
//    self.rightBarButtonContainerViewWidthConstraint.constant = rightBarButtonItemWidth;
//    [self setNeedsUpdateConstraints];
//}
//
//- (void)setRightContentPadding:(CGFloat)rightContentPadding
//{
//    self.rightHorizontalSpacingConstraint.constant = rightContentPadding;
//    [self setNeedsUpdateConstraints];
//}
//
//- (void)setLeftContentPadding:(CGFloat)leftContentPadding
//{
//    self.leftHorizontalSpacingConstraint.constant = leftContentPadding;
//    [self setNeedsUpdateConstraints];
//}
//
//- (void)setLeft2ContentPadding:(CGFloat)left2ContentPadding
//{
////    self.left2HorizontalSpacingConstraint.constant = left2ContentPadding;
//    [self setNeedsUpdateConstraints];
//}

//#pragma mark - Getters
//
//- (CGFloat)leftBarButtonItemWidth
//{
//    return self.leftBarButtonContainerViewWidthConstraint.constant;
//}
//
//- (CGFloat)leftBarButton2ItemWidth
//{
//    return self.leftBarButton2ContainerViewWidthConstraint.constant;
//}
//
//- (CGFloat)rightBarButtonItemWidth
//{
//    return self.rightBarButtonContainerViewWidthConstraint.constant;
//}
//
//- (CGFloat)rightContentPadding
//{
//    return self.rightHorizontalSpacingConstraint.constant;
//}
//
//- (CGFloat)leftContentPadding
//{
//    return self.leftHorizontalSpacingConstraint.constant;
//}

//- (CGFloat)left2ContentPadding
//{
//    return self.left2HorizontalSpacingConstraint.constant;
//}

#pragma mark - UIView overrides

- (void)setNeedsDisplay
{
    [super setNeedsDisplay];
    [self.textView setNeedsDisplay];
}

@end
