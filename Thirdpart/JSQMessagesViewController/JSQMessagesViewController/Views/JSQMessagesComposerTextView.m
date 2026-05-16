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


#import "JSQMessagesComposerTextView.h"
#import <QuartzCore/QuartzCore.h>
#import "NSString+JSQMessages.h"


@interface JSQMessagesComposerTextView ()
@property (nonatomic, assign) BOOL rb_adjustingContentOffset;
@property (nonatomic, assign) NSUInteger rb_lastKnownTextLength;
@property (nonatomic, assign) BOOL rb_shouldLockCaretAfterDeletion;
@end

@implementation JSQMessagesComposerTextView


#pragma mark - Initialization

- (void)jsq_configureTextView
{
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];

    CGFloat cornerRadius = 8.0f;// 输入框圆角（原 19，改小）

    // 输入框背景颜色（微信风格：白框）
    self.backgroundColor = UI_DEFAULT_CHAT_INPUT_FIELD_BG;//[UIColor whiteColor];

    // border设置（不显示边框）
    self.layer.borderWidth = 0;
    self.layer.borderColor = UI_DEFAULT_CHAT_INPUT_FIELD_BORDER.CGColor;

    // 圆角设置
    self.layer.cornerRadius = cornerRadius;

    // 取消滚条导致的空白内衬
    self.scrollIndicatorInsets = UIEdgeInsetsMake(cornerRadius, 0.0f, cornerRadius, 0.0f);

    // 右侧留出空间给输入框内的表情按钮（约 28pt 按钮 + 8pt 间距）
    self.textContainerInset = UIEdgeInsetsMake(9.0f, 10.0f, 4.0f, 36.0f);//UIEdgeInsetsMake(4.0f, 2.0f, 4.0f, 2.0f);
//    self.contentInset = UIEdgeInsetsMake(5.0f, 0.0f, 1.0f, 0.0f);// UIEdgeInsetsMake(3.0f, 0.0f, 1.0f, 0.0f);

    self.scrollEnabled = YES;
    self.scrollsToTop = NO;
    self.userInteractionEnabled = YES;
    self.editable = YES;
    self.selectable = YES;
    self.font = MESSAGE_COMPOSER_TEXT_VIEW_DEFAULT_FONT;//[UIFont systemFontOfSize:16.0f];
    
//    [self.attributedText setValue:[UIFont systemFontOfSize:16.0f] forKey:NSFontAttributeName];// TODO: !!!!!!!
    
    self.textColor = [UIColor blackColor];
    self.textAlignment = NSTextAlignmentNatural;

    self.contentMode = UIViewContentModeRedraw;
    self.dataDetectorTypes = UIDataDetectorTypeNone;
    self.keyboardAppearance = UIKeyboardAppearanceDefault;
    self.keyboardType = UIKeyboardTypeDefault;
    // 以下代码会将输入法中的"return"按键显示成"发送"
    self.returnKeyType = UIReturnKeySend;//UIReturnKeyDefault;
    
//    self.allowsEditingTextAttributes = YES;

    self.text = nil;
    self.rb_lastKnownTextLength = 0;
    self.rb_shouldLockCaretAfterDeletion = NO;

    _placeHolder = nil;
    _placeHolderTextColor = HexColor(0xbfc1c4);//HexColor(0xc4c4c4);//[UIColor lightGrayColor];

    // 添加点击手势，修复使用自定义inputView时点击文字无法定位光标的问题
    UITapGestureRecognizer *tapForCursor = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(jsq_handleTapForCursorPosition:)];
    tapForCursor.numberOfTapsRequired = 1;
    tapForCursor.delegate = self; // 允许与UITextView内置手势共存
    [self addGestureRecognizer:tapForCursor];

    [self jsq_addTextViewNotificationObservers];
}

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer
{
    self = [super initWithFrame:frame textContainer:textContainer];
    if (self) {
        [self jsq_configureTextView];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self jsq_configureTextView];
}

- (void)dealloc
{
    [self jsq_removeTextViewNotificationObservers];
}


#pragma mark - Composer text view

- (BOOL)hasText
{
    return ([[self.text jsq_stringByTrimingWhitespace] length] > 0);
}

// 插入文本。 @since 9.0 by JackJiang
- (void)insertTextStr:(NSString *)text
//# Big FIX 240930 by JackJiang：原方法为insertText，错误地覆盖了父类中的同名方法而导致文本框中输入数字、英文时无法触发textDidChange:回调的问题（经过两天多才找出原因）！
{
    NSString *current = self.text ?: @"";
    NSRange range = self.selectedRange;
    // 搜狗等第三方输入法在 resign 后可能把 text 清空但 selectedRange 仍为旧值，导致越界崩溃；此处做范围保护
    if (range.location > current.length)
        range = NSMakeRange(current.length, 0);
    if (range.location + range.length > current.length)
        range.length = (current.length - range.location);
    NSString *replaceText = [current stringByReplacingCharactersInRange:range withString:(text ?: @"")];
    NSRange newSel = NSMakeRange(range.location + (text ? text.length : 0), 0);
    DDLogDebug(@"【@插入-搜狗】insertTextStr: currentLen=%lu range=(%lu,%lu) insertLen=%lu resultLen=%lu", (unsigned long)current.length, (unsigned long)range.location, (unsigned long)range.length, (unsigned long)(text ? text.length : 0), (unsigned long)replaceText.length);
    self.text = replaceText;
    self.selectedRange = newSel;
}

// 删除文本。 @since 9.0 by JackJiang
- (void)deleteTextStr:(NSRange)range
{
    NSString *text = self.text;
    if (range.location + range.length <= [text length]
        && range.location != NSNotFound && range.length != 0)
    {
        NSString *newText = [text stringByReplacingCharactersInRange:range withString:@""];
        NSRange newSelectRange = NSMakeRange(range.location, 0);
        self.rb_shouldLockCaretAfterDeletion = YES;
        [self setText:newText];
        self.selectedRange = newSelectRange;
    }
}


#pragma mark - Setters

- (void)setPlaceHolder:(NSString *)placeHolder
{
    if ([placeHolder isEqualToString:_placeHolder]) {
        return;
    }

    _placeHolder = [placeHolder copy];
    [self setNeedsDisplay];
}

- (void)setPlaceHolderTextColor:(UIColor *)placeHolderTextColor
{
    if ([placeHolderTextColor isEqual:_placeHolderTextColor]) {
        return;
    }

    _placeHolderTextColor = placeHolderTextColor;
    [self setNeedsDisplay];
}


#pragma mark - UITextView overrides

- (void)setText:(NSString *)text
{
    [super setText:text];
    self.rb_lastKnownTextLength = self.text.length;
    [self setNeedsDisplay];
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    [super setAttributedText:attributedText];
    self.rb_lastKnownTextLength = self.text.length;
    [self setNeedsDisplay];
}

- (void)setFont:(UIFont *)font
{
    [super setFont:font];
    [self setNeedsDisplay];
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment
{
    [super setTextAlignment:textAlignment];
    [self setNeedsDisplay];
}

- (void)paste:(id)sender
{
    if (!self.pasteDelegate || [self.pasteDelegate composerTextView:self shouldPasteWithSender:sender]) {
        [super paste:sender];
    }
}


#pragma mark - Drawing
// 重写UIView的draw方法，实现placeHolderText在合适的时机显示
- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];

    if ([self.text length] == 0 && self.placeHolder) {
        [self.placeHolderTextColor set];

        [self.placeHolder drawInRect:CGRectInset(rect, 14.0f, 9.0f)//CGRectInset(rect, 7.0f, 7.0f)
                      withAttributes:[self jsq_placeholderTextAttributes]];
    }
}


#pragma mark - Notifications
// 本类中的Notifications作用是在文本输入事件触发时及时通知UI重绘（重绘时将自动决定是否显示placeHolderText，请见方法 drawRect: ）

- (void)jsq_addTextViewNotificationObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(jsq_didReceiveTextViewNotification:)
                                                 name:UITextViewTextDidChangeNotification
                                               object:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(jsq_didReceiveTextViewNotification:)
                                                 name:UITextViewTextDidBeginEditingNotification
                                               object:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(jsq_didReceiveTextViewNotification:)
                                                 name:UITextViewTextDidEndEditingNotification
                                               object:self];
}

- (void)jsq_removeTextViewNotificationObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UITextViewTextDidChangeNotification
                                                  object:self];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UITextViewTextDidBeginEditingNotification
                                                  object:self];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UITextViewTextDidEndEditingNotification
                                                  object:self];
}

- (CGFloat)rb_targetContentOffsetYForCaretBottom
{
    if (self.text.length == 0) return 0.0f;
    if (self.selectedRange.length != 0) return self.contentOffset.y;
    if (self.markedTextRange != nil) return self.contentOffset.y;

    UITextRange *sel = self.selectedTextRange;
    if (!sel) return self.contentOffset.y;
    UITextPosition *pos = sel.end;
    if (!pos) return self.contentOffset.y;

    CGRect caret = [self caretRectForPosition:pos];
    CGFloat bottomInset = self.textContainerInset.bottom;
    CGFloat visibleH = CGRectGetHeight(self.bounds) - bottomInset;
    if (visibleH <= 0.0f) return self.contentOffset.y;

    CGFloat yMax = self.contentSize.height - CGRectGetHeight(self.bounds);
    if (yMax < 0.0f) yMax = 0.0f;
    CGFloat targetY = CGRectGetMaxY(caret) - visibleH;
    if (targetY < 0.0f) targetY = 0.0f;
    if (targetY > yMax) targetY = yMax;
    return targetY;
}

- (void)rb_applyCaretLockIfNeeded
{
    if (!self.rb_shouldLockCaretAfterDeletion) return;
    if (!self.isFirstResponder) return;
    if (!self.scrollEnabled) return;
    if (self.isDragging || self.isDecelerating) return;
    if (self.contentSize.height <= CGRectGetHeight(self.bounds) + 1.0f) return;
    if (self.selectedRange.length != 0) return;
    if (self.markedTextRange != nil) return;

    CGFloat targetY = [self rb_targetContentOffsetYForCaretBottom];
    if (fabs(self.contentOffset.y - targetY) <= 0.5f) {
        self.rb_shouldLockCaretAfterDeletion = NO;
        return;
    }
    if (self.rb_adjustingContentOffset) return;

    self.rb_adjustingContentOffset = YES;
    [UIView performWithoutAnimation:^{
        [super setContentOffset:CGPointMake(self.contentOffset.x, targetY)];
    }];
    self.rb_adjustingContentOffset = NO;
    self.rb_shouldLockCaretAfterDeletion = NO;
}

- (void)jsq_didReceiveTextViewNotification:(NSNotification *)notification
{
    [self setNeedsDisplay];
    if ([notification.name isEqualToString:UITextViewTextDidChangeNotification]) {
        NSUInteger currentLength = self.text.length;
        BOOL textShortened = (currentLength < self.rb_lastKnownTextLength);
        self.rb_shouldLockCaretAfterDeletion = textShortened;
        self.rb_lastKnownTextLength = currentLength;
        if (!textShortened) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self rb_applyCaretLockIfNeeded];
        });
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self rb_applyCaretLockIfNeeded];
}

- (void)setSelectedRange:(NSRange)selectedRange
{
    [super setSelectedRange:selectedRange];
    [self rb_applyCaretLockIfNeeded];
}

- (void)setSelectedTextRange:(UITextRange *)selectedTextRange
{
    [super setSelectedTextRange:selectedTextRange];
    [self rb_applyCaretLockIfNeeded];
}

- (void)setContentOffset:(CGPoint)contentOffset
{
    if (self.rb_adjustingContentOffset) {
        [super setContentOffset:contentOffset];
        return;
    }
    if (self.rb_shouldLockCaretAfterDeletion && self.isFirstResponder && self.scrollEnabled && !self.isDragging && !self.isDecelerating && self.selectedRange.length == 0 && self.markedTextRange == nil && self.contentSize.height > CGRectGetHeight(self.bounds) + 1.0f) {
        CGFloat y = [self rb_targetContentOffsetYForCaretBottom];
        contentOffset = CGPointMake(contentOffset.x, y);
        self.rb_shouldLockCaretAfterDeletion = NO;
    }
    [super setContentOffset:contentOffset];
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated
{
    if (self.rb_adjustingContentOffset) {
        [super setContentOffset:contentOffset animated:animated];
        return;
    }
    if (self.rb_shouldLockCaretAfterDeletion && self.isFirstResponder && self.scrollEnabled && !self.isDragging && !self.isDecelerating && self.selectedRange.length == 0 && self.markedTextRange == nil && self.contentSize.height > CGRectGetHeight(self.bounds) + 1.0f) {
        CGFloat y = [self rb_targetContentOffsetYForCaretBottom];
        contentOffset = CGPointMake(contentOffset.x, y);
        self.rb_shouldLockCaretAfterDeletion = NO;
    }
    [super setContentOffset:contentOffset animated:NO];
}


#pragma mark - Utilities

- (NSDictionary *)jsq_placeholderTextAttributes
{
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = self.textAlignment;
    
    //** Bug FIX 250828：self.font存在概率性为nil的情况（修复方法为判断为空则使用默认值），这应该是系统bug，简直匪夷所思！复现的方法是：只插入1个表情然后删除就会出现。
    if(!self.font) {
        self.font = MESSAGE_COMPOSER_TEXT_VIEW_DEFAULT_FONT;
    }

    //** Bug FIX 250828：self.font存在概率性为nil的情况（修复方法为判断为空则使用默认值），这应该是系统bug，简直匪夷所思！
    return @{ NSFontAttributeName : self.font ? self.font : MESSAGE_COMPOSER_TEXT_VIEW_DEFAULT_FONT,
              NSForegroundColorAttributeName : self.placeHolderTextColor,
              NSParagraphStyleAttributeName : paragraphStyle };
}


#pragma mark - 点击定位光标

// 处理点击手势：将光标定位到用户点击的文字位置
- (void)jsq_handleTapForCursorPosition:(UITapGestureRecognizer *)tap
{
    if (tap.state != UIGestureRecognizerStateEnded) {
        return;
    }
    
    // 1) 先确保成为第一响应者（否则设置selectedRange无效）
    if (![self isFirstResponder]) {
        [self becomeFirstResponder];
    }
    
    // 2) 获取点击在文本视图中的坐标
    CGPoint tapPoint = [tap locationInView:self];
    
    // 3) 转换为 textContainer 内的坐标（减去 textContainerInset 和 lineFragmentPadding）
    CGPoint textPoint = tapPoint;
    textPoint.x -= self.textContainerInset.left;
    textPoint.y -= self.textContainerInset.top;
    textPoint.x -= self.textContainer.lineFragmentPadding;
    
    // 4) 通过 NSLayoutManager 精确计算点击位置对应的字符索引
    CGFloat fractionOfDistance = 0;
    NSUInteger charIndex = [self.layoutManager characterIndexForPoint:textPoint
                                                     inTextContainer:self.textContainer
                            fractionOfDistanceBetweenInsertionPoints:&fractionOfDistance];
    
    // 5) 如果点击在字符后半部分，光标移到下一个字符位置
    if (fractionOfDistance > 0.5 && charIndex < self.text.length) {
        charIndex += 1;
    }
    
    // 6) 确保不超过文本长度
    if (charIndex > self.text.length) {
        charIndex = self.text.length;
    }
    
    // 7) 设置光标位置
    self.selectedRange = NSMakeRange(charIndex, 0);
}

#pragma mark - UIGestureRecognizerDelegate

// 允许自定义点击手势与UITextView内置手势同时识别，避免互相阻塞
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

// 仅处理单击，双击（选词/菜单）交给 UITextView 系统手势处理，
// 否则会出现双击后又被单击手势把选区收回的问题。
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        if (touch.tapCount > 1) {
            return NO;
        }
    }
    return YES;
}


#pragma mark - UIMenuController

// 自20211115 v4.3起，此组件在聊天界面中不支持单独长按弹菜单，所以以下方法可以删掉！

- (BOOL)canBecomeFirstResponder
{
    return [super canBecomeFirstResponder];
}

- (BOOL)becomeFirstResponder
{
    return [super becomeFirstResponder];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    [UIMenuController sharedMenuController].menuItems = nil;
    return [super canPerformAction:action withSender:sender];
}

@end
