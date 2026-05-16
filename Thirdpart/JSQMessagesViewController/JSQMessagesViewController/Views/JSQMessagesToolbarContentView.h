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
//  【用途说明】：本类是聊天界面中文本输入区的工具栏内容封装实现类（本类将组合各种按钮、文本输入组件等组成完整的UI逻辑）。
//  【版权申明】：本类原作者为JSQ作者，因原工程已停止更新，当前由JackJiang修改并用于RainbowChat等工程中，感谢原作者。


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JSQMessagesComposerTextView.h"

///**
// *  A constant value representing the default spacing to use for the left and right edges 
// *  of the toolbar content view.
// */
//FOUNDATION_EXPORT const CGFloat kJSQMessagesToolbarContentViewHorizontalSpacingDefault;

/** 输入框下方的引用内容容器高度 */
FOUNDATION_EXPORT const CGFloat kJSQMessagesToolbarQuoteContainerHeightDefault;
/** 输入框下方的引用内容容器下部空白的高度 */
FOUNDATION_EXPORT const CGFloat kJSQMessagesToolbarQuoteContainerBottomGapDefault;

/**
 *  A `JSQMessagesToolbarContentView` represents the content displayed in a `JSQMessagesInputToolbar`.
 *  These subviews consist of a left button, a text view, and a right button. One button is used as
 *  the send button, and the other as the accessory button. The text view is used for composing messages.
 */
@interface JSQMessagesToolbarContentView : UIView

/**
 *  Returns the text view in which the user composes a message.
 */
@property (weak, nonatomic) IBOutlet JSQMessagesComposerTextView *textView;

/**
 *  A custom button item displayed on the left of the toolbar content view.
 *
 *  @discussion The frame height of this button is ignored. When you set this property, the button
 *  is fitted within a pre-defined default content view, the leftBarButtonContainerView,
 *  whose height is determined by the height of the toolbar. However, the width of this button
 *  will be preserved. You may specify a new width using `leftBarButtonItemWidth`.
 *  If the frame of this button is equal to `CGRectZero` when set, then a default frame size will be used.
 *  Set this value to `nil` to remove the button.
 */
@property (weak, nonatomic) IBOutlet UIButton *leftBarButtonItem;
@property (weak, nonatomic) IBOutlet UIButton *leftBarButton2Item;

///**
// *  Specifies the width of the leftBarButtonItem.
// *
// *  @discussion This property modifies the width of the leftBarButtonContainerView.
// */
//@property (assign, nonatomic) CGFloat leftBarButtonItemWidth;
//@property (assign, nonatomic) CGFloat leftBarButton2ItemWidth;

///**
// *  Specifies the amount of spacing between the content view and the leading edge of leftBarButtonItem.
// *
// *  @discussion The default value is `8.0f`.
// */
//@property (assign, nonatomic) CGFloat leftContentPadding;
//@property (assign, nonatomic) CGFloat left2ContentPadding;

///**
// *  The container view for the leftBarButtonItem.
// *
// *  @discussion
// *  You may use this property to add additional button items to the left side of the toolbar content view.
// *  However, you will be completely responsible for responding to all touch events for these buttons
// *  in your `JSQMessagesViewController` subclass.
// */
//@property (weak, nonatomic, readonly) UIView *leftBarButtonContainerView;
//@property (weak, nonatomic, readonly) UIView *leftBarButton2ContainerView;

/**
 *  A custom button item displayed on the right of the toolbar content view.
 *
 *  @discussion The frame height of this button is ignored. When you set this property, the button
 *  is fitted within a pre-defined default content view, the rightBarButtonContainerView,
 *  whose height is determined by the height of the toolbar. However, the width of this button
 *  will be preserved. You may specify a new width using `rightBarButtonItemWidth`.
 *  If the frame of this button is equal to `CGRectZero` when set, then a default frame size will be used.
 *  Set this value to `nil` to remove the button.
 */
@property (weak, nonatomic) IBOutlet UIButton *rightBarButtonItem;

/** 消息引用文本内容显示组件 */
@property (weak, nonatomic) IBOutlet UILabel *quoteContentView;
/** 消息引用文本内容取消按钮 */
@property (weak, nonatomic) IBOutlet UIImageView *quoteCancelView;

/**
 消息引用的显示组件父view的高度约束（当不需要显示此组件时，本值设为0即可）. - add by JackJiang 20240313
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *quoteContainerHeightConstraint;
/**
 消息引用的显示组件父view的底部空白约束（当不需要显示消息引用组件时，本值设为0即可）. - add by JackJiang 20240313
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *quoteContainerBottomGapConstraint;


///**
// *  Specifies the width of the rightBarButtonItem.
// *
// *  @discussion This property modifies the width of the rightBarButtonContainerView.
// */
//@property (assign, nonatomic) CGFloat rightBarButtonItemWidth;

///**
// *  Specifies the amount of spacing between the content view and the trailing edge of rightBarButtonItem.
// *
// *  @discussion The default value is `8.0f`.
// */
//@property (assign, nonatomic) CGFloat rightContentPadding;

///**
// *  The container view for the rightBarButtonItem.
// *
// *  @discussion 
// *  You may use this property to add additional button items to the right side of the toolbar content view.
// *  However, you will be completely responsible for responding to all touch events for these buttons
// *  in your `JSQMessagesViewController` subclass.
// */
//@property (weak, nonatomic, readonly) UIView *rightBarButtonContainerView;

#pragma mark - Class methods

/**
 *  Returns the `UINib` object initialized for a `JSQMessagesToolbarContentView`.
 *
 *  @return The initialized `UINib` object or `nil` if there were errors during
 *  initialization or the nib file could not be located.
 */
+ (UINib *)nib;

@end
