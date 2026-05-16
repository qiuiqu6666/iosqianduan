//
//  TGInputBar.m
//  RainbowChat4i
//
//  Telegram 风格聊天输入栏：浮动白条、自动高度、🎤/发送切换、键盘跟随由外部约束驱动。
//

#import "TGInputBar.h"
#import "Default.h"
#import "Masonry.h"
#import "EmojiUtil.h"

static const CGFloat kTGInputBarCornerRadius = 20.f;   // 输入框圆角
static const CGFloat kTGInputBarHorizontalInset = 12.f;
static const CGFloat kTGInputBarMinHeight = 34.f;       // 最小高度略小
static const NSUInteger kTGInputBarMaxLines = 5;
static const CGFloat kTGInputBarButtonSide = 34.f;
static const CGFloat kTGInputBarPaddingVertical = 5.f;
static const CGFloat kTGInputBarTextViewHorizontalPadding = 10.f;
static const CGFloat kTGInputBarTextViewTopBottomPadding = 7.f;   // 单行文字垂直居中
static const CGFloat kTGInputBarEmojiButtonSide = 28.f;          // 输入框内表情图标尺寸
static const CGFloat kTGInputBarEmojiLeadingInset = 8.f;           // 表情距输入框左边距
// 液态按钮：按下缩放比例、弹性恢复参数
static const CGFloat kTGInputBarLiquidPressScale = 0.88f;
static const CGFloat kTGInputBarLiquidSpringDamping = 0.5f;
static const CGFloat kTGInputBarLiquidSpringVelocity = 0.4f;
// 整条输入栏高度变化时的液态弹性参数
static const CGFloat kTGInputBarBarSpringDamping = 0.72f;
static const CGFloat kTGInputBarBarSpringVelocity = 0.5f;

@interface TGInputBar ()
@property (nonatomic, strong) UIView *bgView;
@property (nonatomic, strong) UIVisualEffectView *blurOverlay;  // 液态毛玻璃蒙层（参考语音通话背景）
@property (nonatomic, strong) UIView *tintOverlay;               // 毛玻璃上的轻微白色蒙层
@property (nonatomic, strong) UIButton *emojiButton;             // 输入框内表情按钮
@property (nonatomic, assign, readwrite) CGFloat currentBarHeight;
/// 无内容时：输入框不往右铺满，右按钮在框外
@property (nonatomic, strong) NSLayoutConstraint *bgViewTrailingNoContent;
@property (nonatomic, strong) NSLayoutConstraint *emojiTrailingNoContent;
/// 有内容时：输入框往右铺满，发送按钮在框内
@property (nonatomic, strong) NSLayoutConstraint *bgViewTrailingWithContent;
@property (nonatomic, strong) NSLayoutConstraint *emojiTrailingWithContent;
/// 发送按钮（在输入框内，有内容时才显示）
@property (nonatomic, strong) UIButton *sendButton;
/// 单行：与发送同逻辑相对 bgView 垂直居中；多行：贴底（与旧注释「不随多行变高而位移」一致）
@property (nonatomic, strong) NSLayoutConstraint *emojiButtonCenterY;
@property (nonatomic, strong) NSLayoutConstraint *emojiButtonBottom;
/// 单行时居中、多行时贴底
@property (nonatomic, strong) NSLayoutConstraint *sendButtonCenterY;
@property (nonatomic, strong) NSLayoutConstraint *sendButtonBottom;
/// 加号、语音：单行与输入框同高（居中），多行贴底
@property (nonatomic, strong) NSLayoutConstraint *leftButtonCenterY;
@property (nonatomic, strong) NSLayoutConstraint *leftButtonBottom;
@property (nonatomic, strong) NSLayoutConstraint *rightButtonCenterY;
@property (nonatomic, strong) NSLayoutConstraint *rightButtonBottom;
/// 与 textViewDidChange 中单行栏高度一致；不用 contentSize 判定，避免 inset 在两种策略间跳变导致文字忽上忽下
@property (nonatomic, assign) BOOL tg_singleLineBarActive;
/// 是否展示回复引用预览（影响白条总高度）
@property (nonatomic, assign) BOOL tg_replyPreviewVisible;
@property (nonatomic, strong) UIView *replyPreviewContainer;
@property (nonatomic, strong) UIView *replyAccentLine;
@property (nonatomic, strong) UILabel *replyTitleLabel;
@property (nonatomic, strong) UILabel *replySnippetLabel;
@property (nonatomic, strong) UIButton *replyCloseButton;
/// 空内容占位（与 textView 内边距对齐，置于 textView 下方图层）
@property (nonatomic, strong) UILabel *placeholderLabel;
/// 仅删除导致内容收缩时，才把可视区域跟回光标，避免用户手动上滑阅读长文本时被强制拉回底部
@property (nonatomic, assign) BOOL tg_shouldScrollCaretAfterDelete;
@property (nonatomic, strong) UIImage *voiceButtonImage;
@property (nonatomic, strong) UIImage *sendButtonImage;
@property (nonatomic, assign) BOOL tg_rightButtonShowsSend;
@property (nonatomic, assign) BOOL tg_usesCustomSendButtonImage;

- (void)tg_updatePlaceholderVisibility;
- (void)tg_layoutPlaceholderLabel;
- (NSString *)tg_resolvedPlaceholderText;
- (void)tg_updateRightButtonAppearanceAnimated:(BOOL)animated;
@end

static const NSTimeInterval kTGInputBarVoiceSendAnimDuration = 0.25;
/// 回复预览条高度（与 setReplyPreviewVisible 内约束一致）
static const CGFloat kTGReplyPreviewHeight = 56.f;
static const CGFloat kTGReplyAccentWidth = 3.f;

@implementation TGInputBar

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _minHeight = kTGInputBarMinHeight;
        _maxLines = kTGInputBarMaxLines;
        _tg_singleLineBarActive = YES;  // 初始为默认单行栏高
        [self setupUI];
        _currentBarHeight = [self tg_preferredDefaultToolbarHeight];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];

    // 背景：液态毛玻璃蒙层（参考语音通话/来电的 UIVisualEffectView + 轻微蒙层）
    _bgView = [[UIView alloc] init];
    // 给一个浅色底，避免在透明父视图下毛玻璃不渲染；毛玻璃与 tint 叠在上方
    _bgView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.45f];
    _bgView.layer.cornerRadius = kTGInputBarCornerRadius;
    _bgView.clipsToBounds = YES;
    _bgView.layer.shadowColor = [UIColor blackColor].CGColor;
    _bgView.layer.shadowOpacity = 0.08f;
    _bgView.layer.shadowRadius = 10.f;
    _bgView.layer.shadowOffset = CGSizeMake(0, -2);
    [self addSubview:_bgView];

    UIBlurEffect *blurEffect;
    if (@available(iOS 13.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    _blurOverlay = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    // 不在此处设 cornerRadius/clipsToBounds，由 _bgView 统一裁剪，避免毛玻璃不渲染
    [_bgView addSubview:_blurOverlay];

    _tintOverlay = [[UIView alloc] init];
    _tintOverlay.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.28f];
    _tintOverlay.userInteractionEnabled = NO;
    [_bgView addSubview:_tintOverlay];

    // 回复预览（Telegram 风格，默认收起）
    _replyPreviewContainer = [[UIView alloc] init];
    _replyPreviewContainer.backgroundColor = [UIColor colorWithRed:0.90f green:0.96f blue:0.91f alpha:0.55f];
    _replyPreviewContainer.hidden = YES;
    _replyPreviewContainer.clipsToBounds = YES;
    [_bgView addSubview:_replyPreviewContainer];

    _replyAccentLine = [[UIView alloc] init];
    _replyAccentLine.backgroundColor = [UIColor colorWithRed:0.2f green:0.5f blue:1.0f alpha:1.f];
    _replyAccentLine.layer.cornerRadius = 1.f;
    _replyAccentLine.clipsToBounds = YES;
    [_replyPreviewContainer addSubview:_replyAccentLine];

    _replyTitleLabel = [[UILabel alloc] init];
    _replyTitleLabel.numberOfLines = 1;
    _replyTitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [_replyPreviewContainer addSubview:_replyTitleLabel];

    _replySnippetLabel = [[UILabel alloc] init];
    _replySnippetLabel.numberOfLines = 1;
    _replySnippetLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _replySnippetLabel.textColor = [UIColor colorWithWhite:0.22f alpha:1.f];
    _replySnippetLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_replyPreviewContainer addSubview:_replySnippetLabel];

    _replyCloseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_replyCloseButton setTitle:@"✕" forState:UIControlStateNormal];
    _replyCloseButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    _replyCloseButton.tintColor = [UIColor colorWithWhite:0.55f alpha:1.f];
    [_replyCloseButton addTarget:self action:@selector(tg_replyCloseTapped) forControlEvents:UIControlEventTouchUpInside];
    [_replyPreviewContainer addSubview:_replyCloseButton];

    // 输入框内表情图标：优先 Assets（chat_face_icon / xiaolian.svg）
    _emojiButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *emojiCfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular];
    UIImage *emojiSym = [UIImage imageNamed:@"chat_face_icon"];
    if (!emojiSym) {
        emojiSym = [UIImage systemImageNamed:@"face.smiling" withConfiguration:emojiCfg];
    } else {
        emojiSym = [emojiSym imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [_emojiButton setImage:emojiSym forState:UIControlStateNormal];
    _emojiButton.tintColor = [UIColor secondaryLabelColor];
    _emojiButton.backgroundColor = [UIColor clearColor];
    _emojiButton.adjustsImageWhenHighlighted = NO;
    [_emojiButton addTarget:self action:@selector(emojiClick) forControlEvents:UIControlEventTouchUpInside];
    [_bgView addSubview:_emojiButton];

    // 左按钮「更多」：优先 Assets（chat_plus_icon / gengduo.svg）
    _leftButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *plusCfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    UIImage *plusSym = [UIImage imageNamed:@"chat_plus_icon"];
    if (!plusSym) {
        plusSym = [UIImage systemImageNamed:@"plus.circle.fill" withConfiguration:plusCfg];
    } else {
        plusSym = [plusSym imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [_leftButton setImage:plusSym forState:UIControlStateNormal];
    _leftButton.tintColor = [UIColor labelColor];
    _leftButton.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.8f];
    _leftButton.clipsToBounds = YES;  // cornerRadius 在 layoutSubviews 中按高度设，保持圆形
    _leftButton.adjustsImageWhenHighlighted = NO;
    [_leftButton addTarget:self action:@selector(plusClick) forControlEvents:UIControlEventTouchUpInside];
    [_leftButton addTarget:self action:@selector(tg_liquidButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [_leftButton addTarget:self action:@selector(tg_liquidButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self addSubview:_leftButton];

    // 语音按钮：优先 Assets 矢量 yuyin.svg，缺失时回退 SF Symbols
    _rightButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *micCfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    UIImage *micSym = [UIImage imageNamed:@"yuyin"];
    if (!micSym) {
        micSym = [UIImage systemImageNamed:@"mic.fill" withConfiguration:micCfg];
    } else {
        micSym = [micSym imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    _voiceButtonImage = micSym;
    UIImage *sendSym = [UIImage imageNamed:@"yyds"];
    if (sendSym) {
        _sendButtonImage = [sendSym imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        _tg_usesCustomSendButtonImage = YES;
    } else {
        UIImageSymbolConfiguration *sendCfg = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold];
        sendSym = [UIImage systemImageNamed:@"paperplane.fill" withConfiguration:sendCfg];
        if (!sendSym) {
            sendSym = [UIImage systemImageNamed:@"arrow.up" withConfiguration:sendCfg];
        }
        _sendButtonImage = [sendSym imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [_rightButton setImage:_voiceButtonImage forState:UIControlStateNormal];
    _rightButton.tintColor = [UIColor labelColor];
    _rightButton.backgroundColor = [UIColor clearColor];
    _rightButton.clipsToBounds = YES;
    _rightButton.adjustsImageWhenHighlighted = NO;
    [_rightButton addTarget:self action:@selector(rightButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [_rightButton addTarget:self action:@selector(tg_liquidButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [_rightButton addTarget:self action:@selector(tg_liquidButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [_bgView addSubview:_rightButton];

    // 发送按钮 ➤（在输入框内，有内容时才显示）
    _sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_sendButton setTitle:@"➤" forState:UIControlStateNormal];
    _sendButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    _sendButton.tintColor = [UIColor whiteColor];
    _sendButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0];
    _sendButton.clipsToBounds = YES;
    _sendButton.adjustsImageWhenHighlighted = NO;
    _sendButton.alpha = 0;
    _sendButton.hidden = YES;
    _sendButton.userInteractionEnabled = NO;
    [_sendButton addTarget:self action:@selector(sendClick) forControlEvents:UIControlEventTouchUpInside];
    [_sendButton addTarget:self action:@selector(tg_liquidButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [_sendButton addTarget:self action:@selector(tg_liquidButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [_bgView addSubview:_sendButton];

    // 输入框
    _textView = [[UITextView alloc] init];
    _textView.delegate = self;
    _textView.scrollEnabled = NO;
    _textView.font = [UIFont systemFontOfSize:16];
    _textView.returnKeyType = UIReturnKeySend;
    _textView.enablesReturnKeyAutomatically = YES;
    _textView.backgroundColor = [UIColor clearColor];
    _textView.textContainerInset = UIEdgeInsetsMake(kTGInputBarTextViewTopBottomPadding, 4, kTGInputBarTextViewTopBottomPadding, 4);
    if (@available(iOS 11.0, *)) {
        _textView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [_bgView addSubview:_textView];

    _placeholderLabel = [[UILabel alloc] init];
    _placeholderLabel.text = @"输入消息";
    _placeholderLabel.textColor = [UIColor colorWithWhite:0.62f alpha:1.f];
    _placeholderLabel.font = _textView.font;
    _placeholderLabel.numberOfLines = 1;
    _placeholderLabel.userInteractionEnabled = NO;
    [_bgView insertSubview:_placeholderLabel belowSubview:_textView];

    [self setupConstraints];
    [self tg_updatePlaceholderVisibility];
}

- (void)setupConstraints {
    // 高度仅由外层 inputToolbar 的 toolbarHeightConstraint 决定（与 inputToolbar 顶底对齐），不在此再加 heightAnchor，避免与父约束冲突导致文字区高度抖动

    [self tg_setupReplyPreviewConstraints];

    // 加号、语音：单行与输入框同高（居中），多行贴底
    [_leftButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(self.mas_leading).offset(kTGInputBarHorizontalInset);
        make.size.mas_equalTo(CGSizeMake(_minHeight, _minHeight));
    }];
    _leftButtonCenterY = [NSLayoutConstraint constraintWithItem:_leftButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_bgView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
    _leftButtonBottom = [NSLayoutConstraint constraintWithItem:_leftButton attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1 constant:-kTGInputBarPaddingVertical];
    [self addConstraint:_leftButtonCenterY];
    [self addConstraint:_leftButtonBottom];
    _leftButtonBottom.active = NO;

    [_rightButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.trailing.equalTo(_bgView.mas_trailing).offset(-6);
        make.size.mas_equalTo(CGSizeMake(_minHeight, _minHeight));
    }];
    _rightButtonCenterY = [NSLayoutConstraint constraintWithItem:_rightButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_textView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
    _rightButtonBottom = [NSLayoutConstraint constraintWithItem:_rightButton attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_bgView attribute:NSLayoutAttributeBottom multiplier:1 constant:-kTGInputBarPaddingVertical];
    [_bgView addConstraint:_rightButtonCenterY];
    [_bgView addConstraint:_rightButtonBottom];
    _rightButtonBottom.active = NO;

    // 输入框白底始终铺到右侧，表情和语音/发送都收进白底内，增加可输入宽度。
    [_bgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(_leftButton.mas_trailing).offset(8);
        make.bottom.equalTo(self.mas_bottom);
        make.height.mas_equalTo(_minHeight + kTGInputBarPaddingVertical);
    }];
    _bgViewTrailingNoContent = [NSLayoutConstraint constraintWithItem:_bgView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_rightButton attribute:NSLayoutAttributeLeading multiplier:1 constant:-8];
    _bgViewTrailingWithContent = [NSLayoutConstraint constraintWithItem:_bgView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTrailing multiplier:1 constant:-kTGInputBarHorizontalInset];
    [self addConstraint:_bgViewTrailingNoContent];
    [self addConstraint:_bgViewTrailingWithContent];
    _bgViewTrailingNoContent.active = NO;
    _bgViewTrailingWithContent.active = YES;

    [_blurOverlay mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_bgView);
    }];
    [_tintOverlay mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_bgView);
    }];

    // 表情：单行与发送一致用 centerY；多行改贴底，避免误切多行时发送/表情顶到白条顶部
    [_emojiButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(kTGInputBarEmojiButtonSide, kTGInputBarEmojiButtonSide));
    }];
    _emojiButtonCenterY = [NSLayoutConstraint constraintWithItem:_emojiButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_textView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
    _emojiButtonBottom = [NSLayoutConstraint constraintWithItem:_emojiButton attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_bgView attribute:NSLayoutAttributeBottom multiplier:1 constant:-kTGInputBarPaddingVertical];
    [_bgView addConstraint:_emojiButtonCenterY];
    [_bgView addConstraint:_emojiButtonBottom];
    _emojiButtonBottom.active = NO;
    _emojiTrailingNoContent = [NSLayoutConstraint constraintWithItem:_emojiButton attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_bgView attribute:NSLayoutAttributeTrailing multiplier:1 constant:-kTGInputBarEmojiLeadingInset];
    _emojiTrailingWithContent = [NSLayoutConstraint constraintWithItem:_emojiButton attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_rightButton attribute:NSLayoutAttributeLeading multiplier:1 constant:-4];
    [_bgView addConstraint:_emojiTrailingNoContent];
    [_bgView addConstraint:_emojiTrailingWithContent];
    _emojiTrailingNoContent.active = NO;
    _emojiTrailingWithContent.active = YES;

    [_sendButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.trailing.equalTo(_bgView.mas_trailing).offset(-6);
        make.size.mas_equalTo(CGSizeMake(_minHeight, _minHeight));
    }];
    _sendButtonCenterY = [NSLayoutConstraint constraintWithItem:_sendButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_textView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
    _sendButtonBottom = [NSLayoutConstraint constraintWithItem:_sendButton attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_bgView attribute:NSLayoutAttributeBottom multiplier:1 constant:-kTGInputBarPaddingVertical];
    [_bgView addConstraint:_sendButtonCenterY];
    [_bgView addConstraint:_sendButtonBottom];
    _sendButtonBottom.active = NO;  // 单行用居中，多行再切贴底

    [_textView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(_bgView.mas_leading).offset(kTGInputBarTextViewHorizontalPadding);
        make.trailing.equalTo(_emojiButton.mas_leading).offset(-6);
        make.top.equalTo(_replyPreviewContainer.mas_bottom);
        make.bottom.equalTo(_bgView.mas_bottom);
    }];
}

- (void)tg_setupReplyPreviewConstraints {
    [_replyPreviewContainer mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.leading.trailing.equalTo(_bgView);
        make.height.mas_equalTo(0);
    }];

    [_replyCloseButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.trailing.equalTo(_replyPreviewContainer.mas_trailing).offset(-4);
        make.centerY.equalTo(_replyPreviewContainer);
        make.width.height.mas_equalTo(32);
    }];

    [_replyAccentLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(_replyPreviewContainer.mas_leading).offset(12);
        make.top.equalTo(_replyPreviewContainer.mas_top).offset(8);
        make.bottom.equalTo(_replyPreviewContainer.mas_bottom).offset(-8);
        make.width.mas_equalTo(kTGReplyAccentWidth);
    }];

    [_replyTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(_replyAccentLine.mas_trailing).offset(8);
        make.trailing.lessThanOrEqualTo(_replyCloseButton.mas_leading).offset(-4);
        make.top.equalTo(_replyPreviewContainer.mas_top).offset(8);
    }];

    [_replySnippetLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(_replyTitleLabel);
        make.trailing.lessThanOrEqualTo(_replyCloseButton.mas_leading).offset(-4);
        make.top.equalTo(_replyTitleLabel.mas_bottom).offset(2);
    }];
}

#pragma mark - Placeholder

- (NSString *)tg_resolvedPlaceholderText {
    if (self.composerPlaceholderText.length > 0) {
        return self.composerPlaceholderText;
    }
    return @"输入消息";
}

- (void)setComposerPlaceholderText:(NSString *)composerPlaceholderText {
    _composerPlaceholderText = [composerPlaceholderText copy];
    if (_placeholderLabel) {
        _placeholderLabel.text = [self tg_resolvedPlaceholderText];
    }
}

- (void)tg_layoutPlaceholderLabel {
    if (!_placeholderLabel || _placeholderLabel.hidden) {
        return;
    }
    UIEdgeInsets inset = _textView.textContainerInset;
    CGFloat linePad = _textView.textContainer.lineFragmentPadding;
    CGRect inner = UIEdgeInsetsInsetRect(_textView.bounds, inset);
    inner.origin.x += linePad;
    inner.size.width = MAX(0.f, inner.size.width - 2.f * linePad);
    inner.size.height = MAX(_placeholderLabel.font.lineHeight, 18.f);
    CGRect r = [_bgView convertRect:inner fromView:_textView];
    _placeholderLabel.frame = r;
}

- (void)tg_updatePlaceholderVisibility {
    if (!_placeholderLabel) {
        return;
    }
    _placeholderLabel.text = [self tg_resolvedPlaceholderText];
    _placeholderLabel.font = _textView.font;
    BOOL show = (_textView.text.length == 0 && _textView.markedTextRange == nil);
    _placeholderLabel.hidden = !show;
    if (show) {
        [self tg_layoutPlaceholderLabel];
    }
}

- (CGFloat)tg_preferredDefaultToolbarHeight {
    return _minHeight + kTGInputBarPaddingVertical + 2.f * kTGInputBarPaddingVertical;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat r = MIN(_leftButton.bounds.size.width, _leftButton.bounds.size.height) / 2.f;
    if (r > 0) {
        _leftButton.layer.cornerRadius = r;
        _rightButton.layer.cornerRadius = (self.tg_rightButtonShowsSend && !self.tg_usesCustomSendButtonImage) ? r : 0.f;
    }
    CGFloat sr = MIN(_sendButton.bounds.size.width, _sendButton.bounds.size.height) / 2.f;
    if (sr > 0) _sendButton.layer.cornerRadius = sr;
    else _sendButton.layer.cornerRadius = _minHeight / 2.f;

    // 单行栏：inset 只由「设计上的 bg 高度 + 字体行高」算出，禁止读 textView.bounds（动画/约束中间帧会导致 tvHeight 微变 → inset 跳 → 文字忽上忽下）
    // 多行栏：固定上下 padding
    if (self.tg_singleLineBarActive) {
        CGFloat bgDesignH = _minHeight + kTGInputBarPaddingVertical;
        CGFloat lh = _textView.font.lineHeight ?: 20.f;
        CGFloat insetV = floor((bgDesignH - lh) * 0.5f + 0.25f);
        insetV = MAX(0.f, insetV);
        _textView.textContainerInset = UIEdgeInsetsMake(insetV, 4.f, insetV, 4.f);
    } else {
        _textView.textContainerInset = UIEdgeInsetsMake(kTGInputBarTextViewTopBottomPadding, 4.f, kTGInputBarTextViewTopBottomPadding, 4.f);
    }
    [self tg_layoutPlaceholderLabel];
}

#pragma mark - 液态按钮效果

- (void)tg_liquidButtonTouchDown:(UIButton *)sender {
    [UIView animateWithDuration:0.12 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        sender.transform = CGAffineTransformMakeScale(kTGInputBarLiquidPressScale, kTGInputBarLiquidPressScale);
    } completion:nil];
}

- (void)tg_liquidButtonTouchUp:(UIButton *)sender {
    [UIView animateWithDuration:0.4
                          delay:0
         usingSpringWithDamping:kTGInputBarLiquidSpringDamping
          initialSpringVelocity:kTGInputBarLiquidSpringVelocity
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Actions

- (void)plusClick {
    if (self.onPlusClick) self.onPlusClick();
}

- (void)emojiClick {
    if (self.onEmojiClick) self.onEmojiClick();
}

- (void)voiceClick {
    if (self.onVoiceClick) self.onVoiceClick();
}

- (void)rightButtonTapped {
    if (self.tg_rightButtonShowsSend) {
        [self sendClick];
    } else {
        [self voiceClick];
    }
}

- (void)sendClick {
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length > 0 && self.onSend) {
        self.onSend(self.textView.text);
        [self resetInput];
    }
}

- (void)tg_updateRightButtonAppearanceAnimated:(BOOL)animated {
    BOOL shouldShowSend = (_textView.text.length > 0);
    if (_tg_rightButtonShowsSend == shouldShowSend) {
        return;
    }

    _tg_rightButtonShowsSend = shouldShowSend;
    void (^applyState)(void) = ^{
        UIImage *targetImage = shouldShowSend ? self.sendButtonImage : self.voiceButtonImage;
        [_rightButton setImage:targetImage forState:UIControlStateNormal];
        [_rightButton setImage:targetImage forState:UIControlStateHighlighted];
        [_rightButton setImage:targetImage forState:UIControlStateSelected];
        [_rightButton setImage:targetImage forState:UIControlStateDisabled];
        NSString *targetTitle = shouldShowSend && targetImage == nil ? @"➤" : nil;
        [_rightButton setTitle:targetTitle forState:UIControlStateNormal];
        [_rightButton setTitle:targetTitle forState:UIControlStateHighlighted];
        [_rightButton setTitle:targetTitle forState:UIControlStateSelected];
        [_rightButton setTitle:targetTitle forState:UIControlStateDisabled];
        _rightButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
        _rightButton.tintColor = (shouldShowSend && self.tg_usesCustomSendButtonImage) ? nil : (shouldShowSend ? [UIColor whiteColor] : [UIColor labelColor]);
        [_rightButton setTitleColor:_rightButton.tintColor forState:UIControlStateNormal];
        [_rightButton setTitleColor:_rightButton.tintColor forState:UIControlStateHighlighted];
        [_rightButton setTitleColor:_rightButton.tintColor forState:UIControlStateSelected];
        [_rightButton setTitleColor:_rightButton.tintColor forState:UIControlStateDisabled];
        _rightButton.backgroundColor = shouldShowSend
            ? (self.tg_usesCustomSendButtonImage ? [UIColor clearColor] : [UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0])
            : [UIColor clearColor];
    };

    if (!animated) {
        applyState();
        return;
    }

    [UIView transitionWithView:_rightButton
                      duration:kTGInputBarVoiceSendAnimDuration
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                    animations:^{
        applyState();
    } completion:nil];
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if (textView != _textView) return YES;
    // 中文等 IME 组字期间回车用于上屏，勿当发送
    if (textView.markedTextRange != nil) return YES;
    if ([text isEqualToString:@"\n"]) {
        [self sendClick];
        return NO;
    }
    BOOL isDeleteAction = (text.length == 0 && range.location != NSNotFound && (range.length > 0 || range.location > 0));
    self.tg_shouldScrollCaretAfterDelete = isDeleteAction;
    if ([self.tg_forwardTextDelegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]) {
        BOOL allow = [self.tg_forwardTextDelegate textView:textView shouldChangeTextInRange:range replacementText:text];
        if (!allow) {
            self.tg_shouldScrollCaretAfterDelete = NO;
            return NO;
        }
    }
    return YES;
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    if (textView != _textView) return;
    [self tg_updatePlaceholderVisibility];
    if ([self.tg_forwardTextDelegate respondsToSelector:@selector(textViewDidBeginEditing:)]) {
        [self.tg_forwardTextDelegate textViewDidBeginEditing:textView];
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    if (textView != _textView) return;
    [self tg_updatePlaceholderVisibility];
    if ([self.tg_forwardTextDelegate respondsToSelector:@selector(textViewDidEndEditing:)]) {
        [self.tg_forwardTextDelegate textViewDidEndEditing:textView];
    }
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
    if (textView != _textView) return;
    if (textView.markedTextRange != nil) {
        _placeholderLabel.hidden = YES;
    } else {
        [self tg_updatePlaceholderVisibility];
    }
    if ([self.tg_forwardTextDelegate respondsToSelector:@selector(textViewDidChangeSelection:)]) {
        [self.tg_forwardTextDelegate textViewDidChangeSelection:textView];
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    if (textView != _textView) return;

    CGFloat previousBarHeight = _currentBarHeight;

    BOOL hasContent = (textView.text.length > 0);

    [self tg_updateRightButtonAppearanceAnimated:YES];

    // 白底内右侧保留「表情 + 语音/发送」两段空间，确保文本不会压到按钮区域。
    CGFloat rightSpace = 6.f + kTGInputBarEmojiButtonSide + 4.f + _minHeight + 6.f;
    CGFloat maxWidth = CGRectGetWidth(_bgView.bounds) - (kTGInputBarTextViewHorizontalPadding + rightSpace);
    if (maxWidth <= 0) maxWidth = [UIScreen mainScreen].bounds.size.width - 140;
    CGSize size = [textView sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
    CGFloat lineHeight = textView.font.lineHeight ?: 20;
    // 单行高度用固定 padding，不读 textContainerInset，避免与 layoutSubviews 动态 inset 形成反馈环导致每字抖动
    CGFloat fixedSingleLineContentHeight = lineHeight + 2.f * kTGInputBarTextViewTopBottomPadding;
    CGFloat defaultBgHeight = _minHeight + kTGInputBarPaddingVertical;
    BOOL isSingleLineContent = (size.height <= fixedSingleLineContentHeight + 2.f);
    CGFloat newTextViewHeight;
    CGFloat newBgHeight;
    if (isSingleLineContent) {
        newTextViewHeight = defaultBgHeight;
        newBgHeight = defaultBgHeight;
    } else {
        CGFloat maxHeight = lineHeight * (CGFloat)self.maxLines + 2.f * kTGInputBarTextViewTopBottomPadding;
        newTextViewHeight = MIN(MAX(size.height, fixedSingleLineContentHeight), maxHeight);
        newBgHeight = MAX(newTextViewHeight, defaultBgHeight);
    }
    CGFloat replyExtra = self.tg_replyPreviewVisible ? kTGReplyPreviewHeight : 0;
    CGFloat fullBgHeight = replyExtra + newBgHeight;
    CGFloat newBarHeight = fullBgHeight + kTGInputBarPaddingVertical * 2;

    // 内容超过当前可视高度（已达 maxLines 上限）时允许上下滑动；否则关闭滚动，避免单行时误滑
    BOOL needsVerticalScroll = (size.height > newTextViewHeight + 1.f);
    _textView.scrollEnabled = needsVerticalScroll;
    _textView.showsVerticalScrollIndicator = needsVerticalScroll;
    _textView.alwaysBounceVertical = needsVerticalScroll;
    if (!needsVerticalScroll) {
        _textView.contentOffset = CGPointZero;
    }

    // 与 layoutSubviews 共用同一套「单行栏」语义，避免依赖 contentSize 导致文字垂直位置跳变
    self.tg_singleLineBarActive = (newBgHeight <= defaultBgHeight + 0.5f);

    // 单行：发送/加号/语音相对白条垂直居中；多行：贴底。
    // 必须用与 tg_singleLineBarActive 相同的阈值：newBgHeight 因 sizeThatFits/像素取整略大于 39 时，若用严格 > 会误判多行并打开 sendBottom，34pt 圆钮会顶到白条顶部（贴顶、底部大留白）。
    BOOL isMultiLine = (newBgHeight > defaultBgHeight + 0.5f);
    if (isMultiLine && _sendButtonCenterY.active) {
        _sendButtonCenterY.active = NO;
        _sendButtonBottom.active = YES;
        _emojiButtonCenterY.active = NO;
        _emojiButtonBottom.active = YES;
        _leftButtonCenterY.active = NO;
        _leftButtonBottom.active = YES;
        _rightButtonCenterY.active = NO;
        _rightButtonBottom.active = YES;
    } else if (!isMultiLine && _sendButtonBottom.active) {
        _sendButtonBottom.active = NO;
        _sendButtonCenterY.active = YES;
        _emojiButtonBottom.active = NO;
        _emojiButtonCenterY.active = YES;
        _leftButtonBottom.active = NO;
        _leftButtonCenterY.active = YES;
        _rightButtonBottom.active = NO;
        _rightButtonCenterY.active = YES;
    }

    [_bgView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(fullBgHeight);  // 含回复预览条 + 文本区高度
    }];

    _currentBarHeight = newBarHeight;

    BOOL barHeightChanged = (fabs(newBarHeight - previousBarHeight) > 0.5f);
    // 单行每字输入高度通常不变：不要再跑弹簧动画，否则 layoutIfNeeded 中间帧 + 父级 toolbar 动画会让文字区垂直位置漂移
    if (self.onHeightChange) {
        self.onHeightChange(newBarHeight);
    }
    [self setNeedsUpdateConstraints];

    void (^finalizeLayout)(void) = ^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    };

    if (barHeightChanged) {
        [UIView animateWithDuration:0.42
                              delay:0
             usingSpringWithDamping:kTGInputBarBarSpringDamping
              initialSpringVelocity:kTGInputBarBarSpringVelocity
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            [self layoutIfNeeded];
        } completion:^(BOOL finished) {
            finalizeLayout();
        }];
    } else {
        [self layoutIfNeeded];
        finalizeLayout();
    }

    if (needsVerticalScroll && self.tg_shouldScrollCaretAfterDelete) {
        NSRange sel = textView.selectedRange;
        if (sel.location != NSNotFound) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [textView scrollRangeToVisible:sel];
            });
        }
    }
    self.tg_shouldScrollCaretAfterDelete = NO;
}

#pragma mark - 回复预览（Telegram 风格）

- (void)tg_replyCloseTapped {
    if (self.onReplyPreviewClose) {
        self.onReplyPreviewClose();
    }
}

- (void)setReplyPreviewVisible:(BOOL)visible senderNick:(NSString *)nick snippetPlain:(NSString *)snippetPlain {
    self.tg_replyPreviewVisible = visible;
    if (!visible) {
        _replyTitleLabel.attributedText = nil;
        _replyTitleLabel.text = nil;
        _replySnippetLabel.attributedText = nil;
        _replySnippetLabel.text = nil;
        _replyPreviewContainer.hidden = YES;
        [_replyPreviewContainer mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(0);
        }];
        [self textViewDidChange:_textView];
        return;
    }

    UIColor *accentBlue = [UIColor colorWithRed:0.2f green:0.5f blue:1.f alpha:1.f];
    NSString *prefix = @"回复 ";
    NSString *namePart = nick.length ? nick : @"";
    NSString *titlePlain = [prefix stringByAppendingString:namePart];
    _replyTitleLabel.attributedText = [[NSAttributedString alloc] initWithString:titlePlain attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: accentBlue
    }];

    if (snippetPlain.length > 0) {
        NSDictionary *snippetAttrs = @{
            NSFontAttributeName: [UIFont systemFontOfSize:14],
            NSForegroundColorAttributeName: [UIColor colorWithWhite:0.22f alpha:1.f]
        };
        _replySnippetLabel.attributedText = [EmojiUtil replaceEmojiWithPlanString:snippetPlain attributes:snippetAttrs];
    } else {
        _replySnippetLabel.attributedText = nil;
        _replySnippetLabel.text = @"";
    }

    _replyPreviewContainer.hidden = NO;
    [_replyPreviewContainer mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(kTGReplyPreviewHeight);
    }];
    [self textViewDidChange:_textView];
}

#pragma mark - Reset

- (void)resetInput {
    _textView.text = @"";
    [self textViewDidChange:_textView];
}

- (void)refreshInputStateForCurrentTextAnimated:(BOOL)animated
{
    [self tg_updateRightButtonAppearanceAnimated:animated];
    [self tg_updatePlaceholderVisibility];
    [self textViewDidChange:_textView];
}

@end
