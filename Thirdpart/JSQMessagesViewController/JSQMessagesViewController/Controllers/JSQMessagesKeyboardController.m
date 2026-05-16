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


#import "JSQMessagesKeyboardController.h"
#import "UIDevice+JSQMessages.h"


typedef void (^JSQAnimationCompletionBlock)(BOOL finished);


@interface JSQMessagesKeyboardController () <UIGestureRecognizerDelegate>

//@property (assign, nonatomic) BOOL jsq_isObserving;

@property (strong, nonatomic) UIView *keyboardView;

@end



@implementation JSQMessagesKeyboardController

#pragma mark - Initialization

- (instancetype)initWithTextView:(UITextView *)textView
                     contextView:(UIView *)contextView
            panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer
                        delegate:(id<JSQMessagesKeyboardControllerDelegate>)delegate
{
    NSParameterAssert(textView != nil);
    NSParameterAssert(contextView != nil);
    NSParameterAssert(panGestureRecognizer != nil);

    self = [super init];
    if (self) {
        _textView = textView;
        _contextView = contextView;
        _panGestureRecognizer = panGestureRecognizer;
        _delegate = delegate;

        // 添加滑动手势监听
        [self.panGestureRecognizer addTarget:self action:@selector(jsq_handlePanGestureRecognizer:)];
    }
    return self;
}

- (void)dealloc
{
//    [self jsq_removeKeyboardFrameObserver];
    [self jsq_unregisterForNotifications];

    // 移除滑动手势监听
    [self.panGestureRecognizer removeTarget:self action:NULL];

    _panGestureRecognizer = nil;
    _delegate = nil;
}


#pragma mark - Getters

- (BOOL)keyboardIsVisible
{
    return self.keyboardView != nil;
}

- (CGRect)currentKeyboardFrame
{
    if (!self.keyboardIsVisible) {
        return CGRectNull;
    }

    return self.keyboardView.frame;
}


#pragma mark - Keyboard controller

- (void)beginListeningForKeyboard
{
    NSLog(@"【JSQ-RB】beginListeningForKeyboard调用了");

    //## Bug FIX: 20250920 by jackjiang，这里不应该使用inputAccessoryView，因为它本来就是输入法软键盘上方的那块快键区域，在iOS26上这块区域上方会自带一个圆角效果
    //            且独立于自定义inputAccessoryView的内容之上（会漏出来，很丑！），而且根据UITextView的定义，在inputView上实现自定义输入面板内容区肯定是更合理的，
    //            ，所以自v10.2开始，为了兼容ios 26（防止聊天更多面板上方漏出那块系统自带的圆角效果）而将原inputAccessoryView改为了inputView
//    if (self.textView.inputAccessoryView == nil) {
//        self.textView.inputAccessoryView = [[UIView alloc] init];
//    }
    // 仅当 inputView 为空且当前不是第一响应者时才设占位 view，避免刚打开表情/更多面板后 viewDidAppear 等再次触发时覆盖为空白导致误弹出键盘
    if (self.textView.inputView == nil && ![self.textView isFirstResponder]) {
        self.textView.inputView = [[UIView alloc] init];
    }

    [self jsq_registerForNotifications];
}

- (void)endListeningForKeyboard
{
    NSLog(@"【JSQ-RB】endListeningForKeyboard调用了");

    [self jsq_unregisterForNotifications];
    [self jsq_setKeyboardViewHidden:NO];
    self.keyboardView = nil;
}


#pragma mark - 软键盘的显示、取消显示的通知处理

- (void)jsq_registerForNotifications
{
    [self jsq_unregisterForNotifications];

    // ★ 核心改动：使用 UIKeyboardWillChangeFrameNotification 替代 DidShow/DidHide
    //   WillChangeFrame 在键盘动画**开始前**触发，携带动画参数（duration/curve），
    //   可以让工具栏与键盘**同步动画**，避免"键盘先出来、UI后移动"的卡顿感
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(jsq_didReceiveKeyboardWillChangeFrameNotification:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];

    // DidShow 仅用于获取键盘 View（供手势交互使用），不再触发 delegate 布局更新
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(jsq_didReceiveKeyboardDidShowNotification:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];

    // DidHide 仅用于清理键盘 View 引用
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(jsq_didReceiveKeyboardDidHideNotification:)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];
}

- (void)jsq_unregisterForNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillChangeFrameNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidHideNotification
                                                  object:nil];
}

// ★ 核心：键盘动画开始前触发 — 提取动画参数并通知 delegate
- (void)jsq_didReceiveKeyboardWillChangeFrameNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    CGRect keyboardEndFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    if (CGRectIsNull(keyboardEndFrame)) {
        return;
    }
    
    // 提取键盘动画参数，供 delegate 同步动画使用
    _keyboardAnimationDuration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    _keyboardAnimationCurve = (UIViewAnimationCurve)[userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    // 坐标转换后通知 delegate 进行布局（delegate 应在动画块中使用上述参数）
    CGRect keyboardEndFrameConverted = [self.contextView convertRect:keyboardEndFrame fromView:nil];
    [self jsq_notifyKeyboardFrameNotificationForFrame:keyboardEndFrameConverted];
}

// DidShow 仅用于获取键盘 View（供手势交互），不再触发 delegate 布局更新
- (void)jsq_didReceiveKeyboardDidShowNotification:(NSNotification *)notification
{
    UIView *keyboardViewProxy = self.textView.inputView.superview;
    
    if ([UIDevice jsq_isCurrentDeviceAfteriOS9]) {
        NSPredicate *windowPredicate = [NSPredicate predicateWithFormat:@"self isMemberOfClass: %@", NSClassFromString(@"UIRemoteKeyboardWindow")];
        UIWindow *keyboardWindow = [[UIApplication sharedApplication].windows filteredArrayUsingPredicate:windowPredicate].firstObject;

        for (UIView *subview in keyboardWindow.subviews) {
            for (UIView *hostview in subview.subviews) {
                if ([hostview isMemberOfClass:NSClassFromString(@"UIInputSetHostView")]) {
                    keyboardViewProxy = hostview;
                    break;
                }
            }
        }
        
        self.keyboardView = keyboardViewProxy;
    }
    
    [self jsq_setKeyboardViewHidden:NO];
    // ★ 注意：不再调用 jsq_handleKeyboardNotification:，布局更新已由 WillChangeFrame 处理
}

// DidHide 仅清理键盘 View 引用
- (void)jsq_didReceiveKeyboardDidHideNotification:(NSNotification *)notification
{
    self.keyboardView = nil;
    // ★ 注意：不再调用 jsq_handleKeyboardNotification:，布局更新已由 WillChangeFrame 处理
}

- (void)jsq_handleKeyboardNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    CGRect keyboardEndFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];

    if (CGRectIsNull(keyboardEndFrame)) {
        return;
    }

    CGRect keyboardEndFrameConverted = [self.contextView convertRect:keyboardEndFrame fromView:nil];
    [self jsq_notifyKeyboardFrameNotificationForFrame:keyboardEndFrameConverted];
}

#pragma mark - 实用方法

- (void)jsq_setKeyboardViewHidden:(BOOL)hidden
{
    // ★ 性能优化：移除热路径日志
    // NSLog(@"【JSQ-RB】jsq_setKeyboardViewHidden：hidden？%d, w=%f、h=%f, x=%f、y=%f, screenHeight=%f"
    //       , self.keyboardView.hidden
    //       , self.keyboardView.frame.size.width, self.keyboardView.frame.size.height
    //       , self.keyboardView.frame.origin.x, self.keyboardView.frame.origin.y
    //       , ScreenHeight);
    
    // 判断当前是否处于模拟器中运行，且输入法是使用“Connect to hardware keybord”，
    // 因为当处于这种模式下，下方的 “self.keyboardView.hidden = hidden;”调用时会导致程序崩溃（说是contrains设置不合理什么的）。
    // 目前没有更好的方法来捕获这个异常或者判断是否处于这种模式，因为通过y坐标的方式来判断。
    BOOL isInMoniqiAndUseHarwareKeybord = NO;
    if(self.keyboardView.frame.origin.y >= ScreenHeight)
    {
        // NSLog(@"【JSQ-RB】【!】当前正处于模拟器中，且正在使用硬件键盘进行输入！"); // ★ 性能优化
        isInMoniqiAndUseHarwareKeybord = YES;
    }
    
    if(!isInMoniqiAndUseHarwareKeybord) // ## Bug FIX: 解决处于模拟器中运行，且输入法是使用“Connect to hardware keybord”的崩溃问题
        self.keyboardView.hidden = hidden;
    self.keyboardView.userInteractionEnabled = !hidden;
}

- (void)jsq_resetKeyboardAndTextView
{
    [self jsq_setKeyboardViewHidden:YES];
    [self.textView resignFirstResponder];
}

- (void)jsq_notifyKeyboardFrameNotificationForFrame:(CGRect)frame
{
    [self.delegate keyboardController:self keyboardDidChangeFrame:frame];
}


#pragma mark - 滑动手势处理

// 滑动手势
- (void)jsq_handlePanGestureRecognizer:(UIPanGestureRecognizer *)pan
{
//    NSLog(@"【JSQ-RB】手势在滑动了！");

    switch (pan.state)
    {
        case UIGestureRecognizerStateChanged:
            break;

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {            
            // 复位键盘输入
            [self jsq_resetKeyboardAndTextView];
            // 其它需要复位的内容
            [self.delegate keyboardController:self gestureComplete:YES];

            break;
        }

        default:
            break;
    }
}

@end
