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
//  【用途说明】：本类是聊天界面中文本输入区的工具栏实现类（本类将的UI逻辑默认由JSQMessagesComposerTextView实现，子类也可自已实现）。
//  【版权申明】：本类原作者为JSQ作者，因原工程已停止更新，当前由JackJiang修改并用于RainbowChat等工程中，感谢原作者。


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JSQMessagesToolbarContentView.h"

@class JSQMessagesInputToolbar;


/**
 *  The `JSQMessagesInputToolbarDelegate` protocol defines methods for interacting with
 *  a `JSQMessagesInputToolbar` object.
 */
@protocol JSQMessagesInputToolbarDelegate <UIToolbarDelegate>

@required

/**
 *  Tells the delegate that the toolbar's `leftBarButtonItem` has been pressed.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 *  @param sender  The button that received the touch event.
 */
- (void)messagesInputToolbar:(JSQMessagesInputToolbar *)toolbar
       didPressLeftBarButton:(UIButton *)sender;

- (void)messagesInputToolbar:(JSQMessagesInputToolbar *)toolbar
       didPressLeftBarButton2:(UIButton *)sender;

/**
 *  Tells the delegate that the toolbar's `rightBarButtonItem` has been pressed.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 *  @param sender  The button that received the touch event.
 */
- (void)messagesInputToolbar:(JSQMessagesInputToolbar *)toolbar
      didPressRightBarButton:(UIButton *)sender;

@end


/**
 *  An instance of `JSQMessagesInputToolbar` defines the input toolbar for
 *  composing a new message. It is displayed above and follow the movement of the system keyboard.
 */
@interface JSQMessagesInputToolbar : UIToolbar

/**
 *  The object that acts as the delegate of the toolbar.
 */
@property (weak, nonatomic) id<JSQMessagesInputToolbarDelegate> delegate;

/**
 *  Returns the content view of the toolbar. This view contains all subviews of the toolbar.
 */
@property (weak, nonatomic, readonly) JSQMessagesToolbarContentView *contentView;

///**
// *  A boolean value indicating whether the send button is on the right side of the toolbar or not.
// *
// *  @discussion The default value is `YES`, which indicates that the send button is the right-most subview of
// *  the toolbar's `contentView`. Set to `NO` to specify that the send button is on the left. This
// *  property is used to determine which touch events correspond to which actions.
// *
// *  @warning Note, this property *does not* change the positions of buttons in the toolbar's content view.
// *  It only specifies whether the `rightBarButtonItem `or the `leftBarButtonItem` is the send button.
// *  The other button then acts as the accessory button.
// */
//@property (assign, nonatomic) BOOL sendButtonOnRight;

/**
 *  Specifies the default (minimum) height for the toolbar. The default value is `44.0f`. This value must be positive.
 */
@property (assign, nonatomic) CGFloat preferredDefaultHeight_noQuote;// 不包含消息引用ui前的默认高度

/**
 *  Specifies the maximum height for the toolbar. The default value is `NSNotFound`, which specifies no maximum height.
 */
@property (assign, nonatomic) NSUInteger maximumHeight;

///**
// *  Enables or disables the send button based on whether or not its `textView` has text.
// *  That is, the send button will be enabled if there is text in the `textView`, and disabled otherwise.
// */
//- (void)toggleSendButtonEnabled;

/**
 *  Loads the content view for the toolbar.
 *
 *  @discussion Override this method to provide a custom content view for the toolbar.
 *
 *  @return An initialized `JSQMessagesToolbarContentView` if successful, otherwise `nil`.
 */
- (JSQMessagesToolbarContentView *)loadToolbarContentView;

// 总的默认高度应该是加上消息引用ui及其空白后的结果 - add by js 24240315
- (CGFloat) getPreferredDefaultHeight;

@end
