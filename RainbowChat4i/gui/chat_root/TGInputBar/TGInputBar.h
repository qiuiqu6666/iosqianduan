//
//  TGInputBar.h
//  RainbowChat4i
//
//  Telegram 风格聊天输入栏，可商用级结构。拖入项目即可复用。
//  结构：[ + ] [ 输入框（自动变高，最多5行）] [ 🎤 / ➤ ]
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TGInputBar : UIView <UITextViewDelegate>

@property (nonatomic, strong, readonly) UITextView *textView;
@property (nonatomic, strong, readonly) UIButton *leftButton;
@property (nonatomic, strong, readonly) UIButton *rightButton;

/// 发送文案（有内容时右按钮为发送）
@property (nonatomic, copy) void (^ _Nullable onSend)(NSString *text);
/// 左侧「+」附件
@property (nonatomic, copy) void (^ _Nullable onPlusClick)(void);
/// 输入框内表情按钮
@property (nonatomic, copy) void (^ _Nullable onEmojiClick)(void);
/// 右侧语音（无内容时右按钮为语音）
@property (nonatomic, copy) void (^ _Nullable onVoiceClick)(void);
/// 高度变化时回调（便于键盘跟随时更新约束）参数：当前总高度
@property (nonatomic, copy) void (^ _Nullable onHeightChange)(CGFloat height);

/// 用户点击回复预览条右侧关闭（应与 Quote4InputWrapper cancelQuote 等联动）
@property (nonatomic, copy) void (^ _Nullable onReplyPreviewClose)(void);

/// 将部分 UITextViewDelegate 交给外层：`shouldChangeTextInRange`（回车之后）、`textViewDidBegin/EndEditing`、`textViewDidChangeSelection`（用于 @、表情/更多面板切键盘等）
@property (nonatomic, weak, nullable) id<UITextViewDelegate> tg_forwardTextDelegate;

/// 最小高度（默认 50），最大高度由最大行数决定
@property (nonatomic, assign) CGFloat minHeight;
/// 最大行数（默认 5），超过可滚动
@property (nonatomic, assign) NSUInteger maxLines;

/// 输入框为空时的占位文案（默认「输入消息」）
@property (nonatomic, copy, nullable) NSString *composerPlaceholderText;

/// 当前整条输入栏高度（与 onHeightChange 一致）；外层 toolbarHeightConstraint 应与此同步，勿用另一套公式
@property (nonatomic, assign, readonly) CGFloat currentBarHeight;
/// 单行、空内容时的默认总高度：minHeight + 输入框纵向 padding + 栏外上下留白（与内部约束一致）
- (CGFloat)tg_preferredDefaultToolbarHeight;

- (void)resetInput;
/// 当外部以编程方式直接写入 textView/attributedText 后，调用此方法同步发送/语音按钮与占位态。
- (void)refreshInputStateForCurrentTextAnimated:(BOOL)animated;

/// Telegram 风格「回复」预览：顶部蓝条 +「回复 昵称」+ 摘要一行 + 关闭；与输入区同圆角白底内
- (void)setReplyPreviewVisible:(BOOL)visible senderNick:(nullable NSString *)nick snippetPlain:(nullable NSString *)snippetPlain;

@end

NS_ASSUME_NONNULL_END
