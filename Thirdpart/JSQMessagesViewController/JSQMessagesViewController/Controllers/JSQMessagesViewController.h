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


#import <UIKit/UIKit.h>
#import "JSQMessagesCollectionView.h"
#import "JSQMessagesCollectionViewFlowLayout.h"
#import "JSQMessagesInputToolbar.h"
#import "JSQMessagesKeyboardController.h"

#import "kmMoreMenuView.h"

/**
 *  输入框下方（底部）“更多”功能面板区默认高度.
 * @author Add by JackJiang 20180302
 */
FOUNDATION_EXPORT const CGFloat k_RBBottomBoxViewHeight;

/**
 *  The `JSQMessagesViewController` class is an abstract class that represents a view controller whose content consists of
 *  a `JSQMessagesCollectionView` and `JSQMessagesInputToolbar` and is specialized to display a messaging interface.
 *
 *  @warning This class is intended to be subclassed. You should not use it directly.
 */
@interface JSQMessagesViewController : UIViewController <JSQMessagesCollectionViewDataSource,
                                                         JSQMessagesCollectionViewDelegateFlowLayout,
                                                         UITextViewDelegate,
                                                         JSQMessagesInputToolbarDelegate,
                                                         JSQMessagesKeyboardControllerDelegate
                                                        >//,UIGestureRecognizerDelegate

/**
 *  Returns the collection view object managed by this view controller.
 *  This view controller is the collection view's data source and delegate.
 */
@property (weak, nonatomic, readonly) JSQMessagesCollectionView *collectionView;

/**
 *  Returns the input toolbar view object managed by this view controller.
 *  This view controller is the toolbar's delegate.
 */
@property (weak, nonatomic, readonly) JSQMessagesInputToolbar *inputToolbar;

/**
 *  Returns the keyboard controller object used to manage the software keyboard.
 */
@property (strong, nonatomic) JSQMessagesKeyboardController *keyboardController;

/**
 *  本地发送者id（The string identifier that uniquely identifies the current user sending messages）.
 *
 *  @discussion This property is used to determine if a message is incoming or outgoing.
 *  All message data objects returned by `collectionView:messageDataForItemAtIndexPath:` are
 *  checked against this identifier. This value must not be `nil`.
 */
@property (copy, nonatomic) NSString *senderId;

/**
 *  本地发送者昵称（The display name of the current user who is sending messages）.
 *
 *  @discussion This value does not have to be unique. This value must not be `nil`.
 */
@property (copy, nonatomic) NSString *senderDisplayName;

/**
 *  Specifies whether or not the view controller should automatically scroll to the most recent message
 *  when the view appears and when sending, receiving, and composing a new message.
 *
 *  @discussion The default value is `YES`, which allows the view controller to scroll automatically to the most recent message.
 *  Set to `NO` if you want to manage scrolling yourself.
 */
@property (assign, nonatomic) BOOL automaticallyScrollsToMostRecentMessage;

/**
 *  用途：本标识用于额外控件聊天列表自动滚动时使用。
 *  场景：当将聊天列表上滚，以便查看诸如老的短视频消息时，从短视频播放界面回来时，会因 automaticallyScrollsToMostRecentMessage=YES而总是自
 *  动滚动到最下的面，这将影响用户体验，因为用户可能还想接着看其它的老消息。要解决这个问题，可以在进入短视频播放界面前设置本标识为YES，而
 *  当从播放界面回来时将会自动忽略一次自动滚动，并同时恢复本标识为默认值NO。
 *
 *  @discussion The default value is `YES`, which allows the view controller to scroll automatically to the most recent message.
 *  Set to `NO` if you want to manage scrolling yourself.
 *  @since 3.0
 */
@property (assign, nonatomic) BOOL automaticallyScrollsToMostRecentMessage_ignoreOnce;

/**
 *  The collection view cell identifier to use for dequeuing outgoing message collection view cells 
 *  in the collectionView for text messages.
 *
 *  @discussion This cell identifier is used for outgoing text message data items.
 *  The default value is the string returned by `[JSQMessagesCollectionViewCellOutgoing cellReuseIdentifier]`.
 *  This value must not be `nil`.
 *
 *  @see JSQMessagesCollectionViewCellOutgoing.
 *
 *  @warning Overriding this property's default value is *not* recommended. 
 *  You should only override this property's default value if you are proividing your own cell prototypes.
 *  These prototypes must be registered with the collectionView for reuse and you are then responsible for 
 *  completely overriding many delegate and data source methods for the collectionView, 
 *  including `collectionView:cellForItemAtIndexPath:`.
 */
@property (copy, nonatomic) NSString *outgoingCellIdentifier;

/**
 *  The collection view cell identifier to use for dequeuing outgoing message collection view cells
 *  in the collectionView for media messages.
 *
 *  @discussion This cell identifier is used for outgoing media message data items.
 *  The default value is the string returned by `[JSQMessagesCollectionViewCellOutgoing mediaCellReuseIdentifier]`.
 *  This value must not be `nil`.
 *
 *  @see JSQMessagesCollectionViewCellOutgoing.
 *
 *  @warning Overriding this property's default value is *not* recommended.
 *  You should only override this property's default value if you are proividing your own cell prototypes.
 *  These prototypes must be registered with the collectionView for reuse and you are then responsible for
 *  completely overriding many delegate and data source methods for the collectionView,
 *  including `collectionView:cellForItemAtIndexPath:`.
 */
@property (copy, nonatomic) NSString *outgoingMediaCellIdentifier;

/**
 *  The collection view cell identifier to use for dequeuing incoming message collection view cells 
 *  in the collectionView for text messages.
 *
 *  @discussion This cell identifier is used for incoming text message data items.
 *  The default value is the string returned by `[JSQMessagesCollectionViewCellIncoming cellReuseIdentifier]`.
 *  This value must not be `nil`.
 *
 *  @see JSQMessagesCollectionViewCellIncoming.
 *
 *  @warning Overriding this property's default value is *not* recommended. 
 *  You should only override this property's default value if you are proividing your own cell prototypes. 
 *  These prototypes must be registered with the collectionView for reuse and you are then responsible for 
 *  completely overriding many delegate and data source methods for the collectionView, 
 *  including `collectionView:cellForItemAtIndexPath:`.
 */
@property (copy, nonatomic) NSString *incomingCellIdentifier;

/**
 *  The collection view cell identifier to use for dequeuing incoming message collection view cells 
 *  in the collectionView for media messages.
 *
 *  @discussion This cell identifier is used for incoming media message data items.
 *  The default value is the string returned by `[JSQMessagesCollectionViewCellIncoming mediaCellReuseIdentifier]`.
 *  This value must not be `nil`.
 *
 *  @see JSQMessagesCollectionViewCellIncoming.
 *
 *  @warning Overriding this property's default value is *not* recommended.
 *  You should only override this property's default value if you are proividing your own cell prototypes.
 *  These prototypes must be registered with the collectionView for reuse and you are then responsible for
 *  completely overriding many delegate and data source methods for the collectionView,
 *  including `collectionView:cellForItemAtIndexPath:`.
 */
@property (copy, nonatomic) NSString *incomingMediaCellIdentifier;

/**
 *  Specifies whether or not the view controller should show the typing indicator for an incoming message.
 *
 *  @discussion Setting this property to `YES` will animate showing the typing indicator immediately.
 *  Setting this property to `NO` will animate hiding the typing indicator immediately. You will need to scroll
 *  to the bottom of the collection view in order to see the typing indicator. You may use `scrollToBottomAnimated:` for this.
 */
@property (assign, nonatomic) BOOL showTypingIndicator;

/**
 *  Specifies whether or not the view controller should show the "load earlier messages" header view.
 *
 *  @discussion Setting this property to `YES` will show the header view immediately.
 *  Settings this property to `NO` will hide the header view immediately. You will need to scroll to
 *  the top of the collection view in order to see the header.
 */
@property (assign, nonatomic) BOOL showLoadEarlierMessagesHeader;

/**
 *  Specifies an additional inset amount to be added to the collectionView's contentInsets.top value.
 *
 *  @discussion Use this property to adjust the top content inset to account for a custom subview at the top of your view controller.
 */
@property (assign, nonatomic) CGFloat topContentAdditionalInset;

@property (weak, nonatomic, readonly) kmMoreMenuView *bottomBoxMoreView;
/** 更多面板容器（子类可设为 textView.inputView，与表情面板一样从底部顶起，不悬浮） */
@property (nonatomic, readonly, strong) UIView *bottomBoxContainerView;

/** 仅子类使用：刚通过「+」或表情按钮打开自定义 inputView 时置 YES，textViewDidBeginEditing 中若为 YES 则不清空 inputView，避免先出面板再误弹出键盘 */
@property (nonatomic, assign) BOOL jsq_didJustOpenCustomInputView;

/** 为 YES 时使用悬浮输入条 + 悬浮更多菜单（overlay），不借助 inputView。子类在 viewDidLoad 前设为 YES。 */
@property (nonatomic, assign) BOOL rb_useFloatingMorePanel;

/**
 聊天界面上部提示信息的显示组件父view的高度约束（当不需要显示此组件时，本值设为0即可）。
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topExtraContainerHeightConstraint;
/**
 聊天界面上部提示信息的显示组件父view.  - add by JackJiang 20180618
 */
@property (weak, nonatomic) IBOutlet UIView *topExtraContainer;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toolbarHeightConstraint;
/** 输入栏底部与 safe area 的约束（子类如 TGInputBar 键盘跟随需读写 constant） */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toolbarBottomLayoutGuide;
/** 悬浮条背景 wrapper（子类用 TGInputBar 时可设 hidden=YES，避免底部露出灰条） */
@property (nonatomic, readonly, weak) UIView *rb_floatingBarWrapperView;
/** 输入栏下方到屏幕底的填充 view（子类可设 backgroundColor 与聊天背景一致） */
@property (nonatomic, readonly, weak) UIView *rb_toolbarBottomFillerView;

/**
 聊天界面底部未读消息数量显示组件（当消息列表最后一行处于不可见时的新消息（未读消息）提示ui）。
 */
@property (weak, nonatomic) IBOutlet UILabel *unreadMessageBallonLabel;
/**
 聊天界面底部未读消息数量提示信息的显示组件父view（当消息列表最后一行处于不可见时的新消息（未读消息）提示ui）。
 */
@property (weak, nonatomic) IBOutlet UIView *unreadMessageBallonContainer;


#pragma mark - Class methods

/**
 *  Returns the `UINib` object initialized for a `JSQMessagesViewController`.
 *
 *  @return The initialized `UINib` object or `nil` if there were errors during initialization
 *  or the nib file could not be located.
 *
 *  @discussion You may override this method to provide a customized nib. If you do,
 *  you should also override `messagesViewController` to return your
 *  view controller loaded from your custom nib.
 */
+ (UINib *)nib;

/**
 *  Creates and returns a new `JSQMessagesViewController` object.
 *
 *  @discussion This is the designated initializer for programmatic instantiation.
 *
 *  @return An initialized `JSQMessagesViewController` object if successful, `nil` otherwise.
 */
+ (instancetype)messagesViewController;


#pragma mark - Initialization

/**
 * 自动滚动到最新的消息（也就是将列表滚动到最后）。
 * 单独提炼出本方法的目的，是希望子类可以通过覆盖本方法，实现更多额外的逻辑。
 *
 * @since 6.0
 */
- (void)autoScrollsToMostRecentMessageForInit;


#pragma mark - Messages view controller

/**
 * 消息输入框上触发的软键盘“Send”按钮事件。
 *
 * @text The message text.
 * @author Add by JackJiang 20180302
 */
- (void)didPressSendButtonInKeybord:(NSString *)text;

/**
 *  This method is called when the user taps the send button on the inputToolbar
 *  after composing a message with the specified data.
 *
 *  @param button            The send button that was pressed by the user.
 *  @param text              The message text.
 *  @param senderId          The message sender identifier.
 *  @param senderDisplayName The message sender display name.
 *  @param date              The message date.
 */
- (void)didPressRightButton:(UIButton *)button
           withMessageText:(NSString *)text
                  senderId:(NSString *)senderId
         senderDisplayName:(NSString *)senderDisplayName
                      date:(NSDate *)date;

/**
 *  This method is called when the user taps the accessory button on the `inputToolbar`.
 *
 *  @param sender The accessory button that was pressed by the user.
 */
- (void)didPressLeftButton:(UIButton *)sender;

- (void)didPressLeftButton2:(UIButton *)sender;

/**
 *  Animates the sending of a new message. See `finishSendingMessageAnimated:` for more details.
 *
 *  @see `finishSendingMessageAnimated:`.
 */
- (void)finishSendingMessage;

/**
 *  Completes the "sending" of a new message by resetting the `inputToolbar`, adding a new collection view cell in the collection view,
 *  reloading the collection view, and scrolling to the newly sent message as specified by `automaticallyScrollsToMostRecentMessage`.
 *  Scrolling to the new message can be animated as specified by the animated parameter.
 *
 *  @param animated Specifies whether the sending of a message should be animated or not. Pass `YES` to animate changes, `NO` otherwise.
 *
 *  @discussion You should call this method at the end of `didPressSendButton: withMessageText: senderId: senderDisplayName: date`
 *  after adding the new message to your data source and performing any related tasks.
 *
 *  @see `automaticallyScrollsToMostRecentMessage`.
 */
- (void)finishSendingMessageAnimated:(BOOL)animated;

/**
 *  Animates the receiving of a new message. See `finishReceivingMessageAnimated:` for more details.
 *
 *  @see `finishReceivingMessageAnimated:`.
 */
- (void)finishReceivingMessage;

/**
 *  Completes the "receiving" of a new message by showing the typing indicator, adding a new collection view cell in the collection view,
 *  reloading the collection view, and scrolling to the newly sent message as specified by `automaticallyScrollsToMostRecentMessage`.
 *  Scrolling to the new message can be animated as specified by the animated parameter.
 *
 *  @param animated Specifies whether the receiving of a message should be animated or not. Pass `YES` to animate changes, `NO` otherwise.
 *
 *  @discussion You should call this method after adding a new "received" message to your data source and performing any related tasks.
 *
 *  @see `automaticallyScrollsToMostRecentMessage`.
 */
- (void)finishReceivingMessageAnimated:(BOOL)animated;

/**
 *
 * @param forceDontScrollToBottom YES表示无论如何都不会自动滚动到最后一行，否则不强迫（依赖其它条件判断并按需滚动到最后一行）
 */
- (void)finishReceivingMessageAnimated:(BOOL)animated forceDontScrollToBottom:(BOOL)forceDontScrollToBottom;

/**
 刷新表格，即时显示内容。
 
 @author JackJiang
 @since 9.0
 */
- (void)refreshCollectionView;

/**
 *  Scrolls the collection view such that the bottom most cell is completely visible, above the `inputToolbar`.
 *
 *  @param animated Pass `YES` if you want to animate scrolling, `NO` if it should be immediate.
 */
- (void)scrollToBottomAnimated:(BOOL)animated;

/**
 获取表格中最后一行的位置信息。
 
 @since 7.0
 @author Jack Jiang
 */
- (NSIndexPath *)getLastCellIndexPath;

/**
 表格中最后一行是否处于可见状态。
 
 @since 7.0
 @author Jack Jiang
 */
- (BOOL)isLastCellVisible;

/**
 * Used to decide if a message is incoming or outgoing.
 *
 * @discussion The default implementation of this method compares the `senderId` of the message to the
 * value of the `senderId` property and returns `YES` if they are equal. Subclasses can override
 * this method to specialize the decision logic.
 */
- (BOOL)isOutgoingMessage:(JSQMessage *)messageItem;

/**
 * Scrolls the collection view so that the cell at the specified indexPath is completely visible above the `inputToolbar`.
 *
 * @param indexPath The indexPath for the cell that will be visible.
 * @param animated Pass `YES` if you want to animate scrolling, `NO` otherwise.
 */
- (void)scrollToIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;

/**
 Call to super required.
 */
- (void)viewDidLoad NS_REQUIRES_SUPER;

/**
 Call to super required.
 */
- (void)viewWillAppear:(BOOL)animated NS_REQUIRES_SUPER;

/**
 Call to super required.
 */
- (void)viewDidAppear:(BOOL)animated NS_REQUIRES_SUPER;

/**
 Call to super required.
 */
- (void)viewWillDisappear:(BOOL)animated NS_REQUIRES_SUPER;

/**
 Call to super required.
 */
- (void)viewDidDisappear:(BOOL)animated NS_REQUIRES_SUPER;

/**
 Called when `UIMenuControllerWillShowMenuNotification` is posted.

 @param notification The posted notification.
 */
- (void)didReceiveMenuWillShowNotification:(NSNotification *)notification;

/**
 Called when `UIMenuControllerWillHideMenuNotification` is posted.

 @param notification The posted notification.
 */
- (void)didReceiveMenuWillHideNotification:(NSNotification *)notification;

///**
// * 本次 keyboardController:keyboardDidChangeFrame: 调用是否要被忽略。
// * 本方法用途：子类可以实现本方法
// *
// * @return YES表示忽略本次，否则不忽略，默认返回NO
// */
//- (BOOL)rb_keyboardDidChangeFrame_ignore;

//// 用户的上下滑动消息列表动作完成
//- (void)rb_keyboardController_gestureComplete;


/**
 单独的方法里处理头像显示逻辑，方便子类以更大的自由度实现自已的显示逻辑 - 20180528 by JackJiang

 @param collectionView collectionView description
 @param indexPath indexPath description
 @param avatarView avatarView description
 */
- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath_avatar:(NSIndexPath *)indexPath withImageView:(UIImageView *)avatarView;

/**
 单独的方法里处理被引用消息的显示逻辑，方便子类以更大的自由度实现自已的显示逻辑 - 20240316 by JackJiang

 @param collectionView collectionView description
 @param indexPath indexPath description
 @param cell cell instance
 */
- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath_quote:(NSIndexPath *)indexPath withCell:(JSQMessagesCollectionViewCell *)cell andQuote:(QuoteMeta *)quoteMeta;

/**
 * 昵称的显示逻辑 - 20250801 by JackJiang
 */
- (NSString *)rb_collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath_nickname:(NSIndexPath *)indexPath withCell:(JSQMessagesCollectionViewCell *)cell;

/**
 设置聊天界面输入框工具栏下方的高度。
 通过设置此值可控制“(+)更多”、软键盘的显示和隐藏。

 @param constant 变化的高度
 @author JackJiag：20180301日起额外开放的方法
 */
- (void)jsq_setToolbarBottomLayoutGuideConstant:(CGFloat)constant;

- (void)jsq_updateCollectionViewInsets;

/** 内容不足时列表顶部留白基准（安全区顶）；子类可重写（例如自定义顶栏总高度） */
- (CGFloat)jsq_topInsetWhenContentDoesNotFill;

/** 
 返回当前文本框中输入的文本内容 -- Freeman改造为返回富文本内容。
 
 @return 输入的文本内容
 */
- (NSString *)jsq_currentlyComposedMessageText;

/**
 关闭（准确地说是隐藏）"(+)更多"功能面板（如果它现在正在显示着，否则什么也不做），支持动事的方式关闭。
 */
- (void)hideBottomBoxAnim:(BOOL)animation;

/**
 同上，但在悬浮更多面板完全收起后再回调（避免紧接着弹 LPActionSheet 仍叠在菜单下层）。
 */
- (void)hideBottomBoxAnim:(BOOL)animation completion:(void (^ _Nullable)(void))completion;

/**
 关闭（准确地说是隐藏）"(+)更多"功能面板（如果它现在正在显示着，否则什么也不做）。
 */
- (void)hideBottomBox;

/**
 重置第二个按钮为表情样式。该按钮之前用于发送图片
 */
- (void)resetLeftButton2Style;

/**
 设置第二个按钮为键盘样式
 */
- (void)setLeftButton2ToKeyboardStyle;


#pragma mark - 当消息列表最后一行处于可见或不可见时的新消息（未读消息）提示ui的相关方法。

///*!
// *  点击消息未读数气泡事件处理。
// */
//- (IBAction)fireOnClickUnreadBallon:(id)sender;

/**
 * 设置当前总的未读数.
 *
 * @param unreadCount 总未读数
 */
- (void)setUnreadCount:(int)unreadCount;

/**
 * 重置总的未读数.
 */
- (void)resetUnreadCount;

/**
 * 总未读数累加.
 *
 * @param countForAccumulate 要累加的值
 */
- (void)addUnreadCount:(int)countForAccumulate;

/**
 * 子类可重写：全屏右滑返回途中「取消」后再次触发 viewWillAppear 时返回 YES，
 * 基类将跳过对 collectionView 的 invalidateLayout / layoutIfNeeded，减轻聊天气泡文字抖动。
 * 默认 NO。
 */
- (BOOL)jsq_shouldSkipHeavyWillAppearLayout;

@end
