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


#import "JSQMessagesInputToolbar.h"
#import "JSQMessagesComposerTextView.h"
//#import "JSQMessagesToolbarButtonFactory.h"
#import "UIColor+JSQMessages.h"
#import "UIImage+JSQMessages.h"
#import "UIView+JSQMessages.h"

//static void * kJSQMessagesInputToolbarKeyValueObservingContext = &kJSQMessagesInputToolbarKeyValueObservingContext;


@interface JSQMessagesInputToolbar ()

//@property (assign, nonatomic) BOOL jsq_isObserving;

@end



@implementation JSQMessagesInputToolbar

@dynamic delegate;

#pragma mark - Initialization

- (void)awakeFromNib
{
    [super awakeFromNib];

    // 设置视图自动调整尺寸的掩码是否转化为基于约束布局的约束(一般设为NO，不然会让布局变的复杂，而且本类中不需要)
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];

//    self.jsq_isObserving = NO;
//    self.sendButtonOnRight = YES;

    // 初始化输入框工具栏上的UI
    JSQMessagesToolbarContentView *toolbarContentView = [self loadToolbarContentView];
    toolbarContentView.frame = self.frame;
    [self addSubview:toolbarContentView];
    [self jsq_pinAllEdgesOfSubview:toolbarContentView];
    [self setNeedsUpdateConstraints];
    _contentView = toolbarContentView;

    // 【重要说明】：preferredDefaultHeight的值是JSQMessagesViewController.xib中
    //            设置的JSQMessagesToolbarContentView工具栏的高度，而不是JSQMessagesToolbarContentView.xib
    //            中的高度，因为JSQMessagesToolbarContentView使用时是使用组件放在JSQMessagesViewController.xib中的，
    //            所以它的_contentView.bounds已不受JSQMessagesToolbarContentView.xib控制，一定要注意！
//  self.preferredDefaultHeight = CGRectGetHeight(_contentView.bounds);// 50.0f
    self.preferredDefaultHeight_noQuote = CGRectGetHeight(_contentView.bounds);
    self.maximumHeight = NSNotFound;
    
    // 不显示UIToolbar顶部默认的深灰色横线（参考资料：https://blog.csdn.net/stubbornness1219/article/details/49701961）
    self.clipsToBounds = YES;

//    // add by jackjiang 20170408
//    toolbarContentView.backgroundColor = HexColor(0xffffff);//HexColor(0x3090d0);

    // 添加KVO属性观察者
//    [self jsq_addObservers];

//    // JSQ作者默认实现的按钮（开发者可以自行在代码中设置为自已定义的按钮）
//    self.contentView.leftBarButtonItem = [JSQMessagesToolbarButtonFactory defaultAccessoryButtonItem];
//    self.contentView.leftBarButton2Item = [JSQMessagesToolbarButtonFactory defaultAccessoryButton2Item];
//    self.contentView.rightBarButtonItem = [JSQMessagesToolbarButtonFactory defaultSendButtonItem];

//    [self toggleSendButtonEnabled];

    [self.contentView.leftBarButtonItem addTarget:self
                                           action:@selector(jsq_leftBarButtonPressed:)
                                 forControlEvents:UIControlEventTouchUpInside];
    [self.contentView.leftBarButton2Item addTarget:self
                                            action:@selector(jsq_leftBarButton2Pressed:)
                                  forControlEvents:UIControlEventTouchUpInside];
    [self.contentView.rightBarButtonItem addTarget:self
                                            action:@selector(jsq_rightBarButtonPressed:)
                                  forControlEvents:UIControlEventTouchUpInside];
}

// 加载默认的聊天界面下方输入框工具栏的View内容（之所以说是默认，因为JSQ的高可扩展性允许子类自已覆盖并实现自已的实现）
- (JSQMessagesToolbarContentView *)loadToolbarContentView
{
    // 加载xib
    NSArray *nibViews = [[NSBundle bundleForClass:[JSQMessagesInputToolbar class]] loadNibNamed:NSStringFromClass([JSQMessagesToolbarContentView class]) owner:nil options:nil];
    return nibViews.firstObject;
}

// 总的默认高度应该是加上消息引用ui及其空白后的结果
- (CGFloat) getPreferredDefaultHeight
{
    DDLogDebug(@"【计算聊天界面InputToolBar默认高度】 preferredDefaultHeight_noQuote=%f, quoteContainerHeightConstraint=%f, quoteContainerBottomGapConstraint=%f", self.preferredDefaultHeight_noQuote, self.contentView.quoteContainerHeightConstraint.constant, self.contentView.quoteContainerBottomGapConstraint.constant);
    
    return self.preferredDefaultHeight_noQuote
        // 消息消息ui内容区高度
        + self.contentView.quoteContainerHeightConstraint.constant
        // 消息消息ui内容区下方的空白高度
        + self.contentView.quoteContainerBottomGapConstraint.constant;
}

- (void)dealloc
{
//    [self jsq_removeObservers];
}


//#pragma mark - Setters
//
//- (void)setPreferredDefaultHeight:(CGFloat)preferredDefaultHeight
//{
//    NSParameterAssert(preferredDefaultHeight > 0.0f);
//    _preferredDefaultHeight = preferredDefaultHeight;
//}


#pragma mark - Actions

- (void)jsq_leftBarButtonPressed:(UIButton *)sender
{
    [self.delegate messagesInputToolbar:self didPressLeftBarButton:sender];
}

- (void)jsq_leftBarButton2Pressed:(UIButton *)sender
{
    [self.delegate messagesInputToolbar:self didPressLeftBarButton2:sender];
}

- (void)jsq_rightBarButtonPressed:(UIButton *)sender
{
    [self.delegate messagesInputToolbar:self didPressRightBarButton:sender];
}


//#pragma mark - Input toolbar
//// 根据输入框中的文本内容是否存在，来决定发送按钮的可用性
//- (void)toggleSendButtonEnabled
//{
////    // 20170421 modified by jackjiang：为了让界面上的发送按钮一直处于可用状态而改
////    BOOL hasText = YES;//[self.contentView.textView hasText];
////
////    if (self.sendButtonOnRight) {
////        self.contentView.rightBarButtonItem.enabled = hasText;
////    }
////    else {
////        self.contentView.leftBarButtonItem.enabled = hasText;
////    }
//}


//#pragma mark - Key-value observing
//// 输入框架工具栏上的按钮被设置时本KVO观察者代理方法将被调用：此处将为设置的按钮添加点击事件处理等
//- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
//{
//    if (context == kJSQMessagesInputToolbarKeyValueObservingContext) {
//        if (object == self.contentView) {
//
//            if ([keyPath isEqualToString:NSStringFromSelector(@selector(leftBarButtonItem))]) {
//
//                [self.contentView.leftBarButtonItem removeTarget:self
//                                                          action:NULL
//                                                forControlEvents:UIControlEventTouchUpInside];
//
//                [self.contentView.leftBarButtonItem addTarget:self
//                                                       action:@selector(jsq_leftBarButtonPressed:)
//                                             forControlEvents:UIControlEventTouchUpInside];
//            }
//            else if ([keyPath isEqualToString:NSStringFromSelector(@selector(leftBarButton2Item))]) {
//
//                [self.contentView.leftBarButton2Item removeTarget:self
//                                                          action:NULL
//                                                forControlEvents:UIControlEventTouchUpInside];
//
//                [self.contentView.leftBarButton2Item addTarget:self
//                                                       action:@selector(jsq_leftBarButton2Pressed:)
//                                             forControlEvents:UIControlEventTouchUpInside];
//
////                [self.contentView.leftBarButton2Item addTarget:self
////                                                        action:@selector(jsq_leftBarButton2Pressed:)
////                                              forControlEvents:UIControlEventTouchUpInside];
//
//            }
//            else if ([keyPath isEqualToString:NSStringFromSelector(@selector(rightBarButtonItem))]) {
//
//                [self.contentView.rightBarButtonItem removeTarget:self
//                                                           action:NULL
//                                                 forControlEvents:UIControlEventTouchUpInside];
//
//                [self.contentView.rightBarButtonItem addTarget:self
//                                                        action:@selector(jsq_rightBarButtonPressed:)
//                                              forControlEvents:UIControlEventTouchUpInside];
//            }
//
//            [self toggleSendButtonEnabled];
//        }
//    }
//}

//// 为输入框架工具栏上的按钮添中KVO属性观察者（当设置它们时将通知观察者）
//- (void)jsq_addObservers
//{
//    if (self.jsq_isObserving) {
//        return;
//    }
//
//    [self.contentView addObserver:self
//                       forKeyPath:NSStringFromSelector(@selector(leftBarButtonItem))
//                          options:0
//                          context:kJSQMessagesInputToolbarKeyValueObservingContext];
//
//    [self.contentView addObserver:self
//                       forKeyPath:NSStringFromSelector(@selector(leftBarButton2Item))
//                          options:0
//                          context:kJSQMessagesInputToolbarKeyValueObservingContext];
//
//    [self.contentView addObserver:self
//                       forKeyPath:NSStringFromSelector(@selector(rightBarButtonItem))
//                          options:0
//                          context:kJSQMessagesInputToolbarKeyValueObservingContext];
//
//    self.jsq_isObserving = YES;
//}
//
//// 移除输入框架工具栏上的按钮添中KVO属性观察者
//- (void)jsq_removeObservers
//{
//    if (!_jsq_isObserving) {
//        return;
//    }
//
//    @try {
//        [_contentView removeObserver:self
//                          forKeyPath:NSStringFromSelector(@selector(leftBarButtonItem))
//                             context:kJSQMessagesInputToolbarKeyValueObservingContext];
//
//        [_contentView removeObserver:self
//                          forKeyPath:NSStringFromSelector(@selector(leftBarButton2Item))
//                             context:kJSQMessagesInputToolbarKeyValueObservingContext];
//
//        [_contentView removeObserver:self
//                          forKeyPath:NSStringFromSelector(@selector(rightBarButtonItem))
//                             context:kJSQMessagesInputToolbarKeyValueObservingContext];
//    }
//    @catch (NSException *__unused exception) { }
//
//    _jsq_isObserving = NO;
//}

@end
