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
//  【用途说明】：本类就是JSQ官方实现的聊天文本输入框组件实现类（可支持多行输入等）。
//  【版权申明】：本类原作者为JSQ作者，因原工程已停止更新，当前由JackJiang修改并用于RainbowChat等工程中，感谢原作者。


#import <UIKit/UIKit.h>

// 输入文本框的默认字体
#define MESSAGE_COMPOSER_TEXT_VIEW_DEFAULT_FONT [UIFont systemFontOfSize:16.0f]

@class JSQMessagesComposerTextView;

/**
 *  A delegate object used to notify the receiver of paste events from a `JSQMessagesComposerTextView`.
 */
@protocol JSQMessagesComposerTextViewPasteDelegate <NSObject>

/**
 *  Asks the delegate whether or not the `textView` should use the original implementation of `-[UITextView paste]`.
 *
 *  @discussion Use this delegate method to implement custom pasting behavior. 
 *  You should return `NO` when you want to handle pasting. 
 *  Return `YES` to defer functionality to the `textView`.
 */
- (BOOL)composerTextView:(JSQMessagesComposerTextView *)textView shouldPasteWithSender:(id)sender;

@end

/**
 *  An instance of `JSQMessagesComposerTextView` is a subclass of `UITextView` that is styled and used 
 *  for composing messages in a `JSQMessagesViewController`. It is a subview of a `JSQMessagesToolbarContentView`.
 */
@interface JSQMessagesComposerTextView : UITextView <UIGestureRecognizerDelegate>

/**
 *  The text to be displayed when the text view is empty. The default value is `nil`.
 */
@property (copy, nonatomic) NSString *placeHolder;

/**
 *  The color of the place holder text. The default value is `[UIColor lightGrayColor]`.
 */
@property (strong, nonatomic) UIColor *placeHolderTextColor;

/**
 *  The object that acts as the paste delegate of the text view.
 */
@property (weak, nonatomic) id<JSQMessagesComposerTextViewPasteDelegate> pasteDelegate;

/**
 *  Determines whether or not the text view contains text after trimming white space 
 *  from the front and back of its string.
 *
 *  @return `YES` if the text view contains text, `NO` otherwise.
 */
- (BOOL)hasText;

/**
 插入文本。
 
 @since 9.0
 */
- (void)insertTextStr:(NSString *)text;

/**
 删除文本。
 
 @since 9.0
 */
- (void)deleteTextStr:(NSRange)range;

@end
