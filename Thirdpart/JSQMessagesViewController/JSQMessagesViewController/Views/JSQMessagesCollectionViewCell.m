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


#import "JSQMessagesCollectionViewCell.h"

#import "JSQMessagesCollectionViewCellIncoming.h"
#import "JSQMessagesCollectionViewCellOutgoing.h"
#import "JSQMessagesCollectionViewLayoutAttributes.h"

#import "UIView+JSQMessages.h"
#import "UIDevice+JSQMessages.h"
#import "Default.h"

#import "JSQMessagesCollectionViewFlowLayout.h"// for kJSQMessagesCollectionViewCellNicknameLabelHeightDefault


//static NSMutableSet *jsqMessagesCollectionViewCellActions = nil;

const CGFloat kJSQMessagesCollectionViewCellQuoteContinerTopGapDefault = 5.0f;//4.0f;
// 有图时返回44（即内容40+顶部gap 4），仅文字时返回30（即内容26+顶部gap 4），无引用内容时返回0
const CGFloat kJSQMessagesCollectionViewCellQuoteContinerHeightDefault_onlyText = 28.0f;//26.0f;//30.0f
const CGFloat kJSQMessagesCollectionViewCellQuoteContinerHeightDefault_hasIcon = 42.0f;//44.0f
// 有图时返回35（即图30+左部gap 5），无图时返回0
const CGFloat kJSQMessagesCollectionViewCellQuoteIconContinerWidthDefault = 35.0f;


@interface JSQMessagesCollectionViewCell ()

@property (weak, nonatomic) IBOutlet JSQMessagesLabel *cellTopLabel;
@property (weak, nonatomic) IBOutlet JSQMessagesLabel *messageBubbleTopLabel;
@property (weak, nonatomic) IBOutlet JSQMessagesLabel *cellBottomLabel;

@property (weak, nonatomic) IBOutlet UIView *messageBubbleContainerView;
@property (weak, nonatomic) IBOutlet UIImageView *messageBubbleImageView;
//@property (weak, nonatomic) IBOutlet UILabel *cellNicknameLabel;
@property (weak, nonatomic) IBOutlet UITextField *cellNicknameLabel2;
@property (weak, nonatomic) IBOutlet JSQMessagesCellTextView *textView;

@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UIView *avatarContainerView;

/** 消息引用容器组件 */
@property (weak, nonatomic) IBOutlet UIView *quoteContainerView;
/** 消息引用文本内容组件 */
@property (weak, nonatomic) IBOutlet UILabel *quoteContentLabel;
/** 消息引用图标组件 */
@property (weak, nonatomic) IBOutlet UIImageView *quoteIconView;
/** 消息引用播放图标组件（用于引用的短视频消息时） */
@property (weak, nonatomic) IBOutlet UIImageView *quotePlayIconView;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageBubbleContainerWidthConstraint;
/** Incoming：气泡 leading = 头像 trailing + constant；无尾时 constant 加 2pt 右偏 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageBubbleContainerLeadingConstraint;
/** Outgoing：头像 leading = 气泡 trailing + constant（我方气泡不随无尾右偏，始终 7pt） */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageBubbleContainerTrailingConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textViewTopVerticalSpaceConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textViewBottomVerticalSpaceConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textViewAvatarHorizontalSpaceConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textViewMarginHorizontalSpaceConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cellTopLabelHeightConstraint;
// 昵称lable宽度约束（昵称目前用于群聊中收到的消息）
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cellNicknameLabelHeightConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageBubbleTopLabelHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cellBottomLabelHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cellBottomLabelLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cellBottomLabelTrailingConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *avatarContainerViewWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *avatarContainerViewHeightConstraint;

// 消息引用顶级容器顶部的空白高度约束
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *quoteContainerTopGapConstraint;
// 消息引用顶级容器高度约束
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *quoteContainerHeightConstraint;
// 消息引用图标容器宽度约束
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *quoteIconContainerWidthConstraint;

@property (assign, nonatomic) UIEdgeInsets textViewFrameInsets;

@property (assign, nonatomic) CGSize avatarViewSize;

@property (weak, nonatomic, readwrite) UITapGestureRecognizer *tapGestureRecognizer;

/** 长按手势（当前用于长按弹出菜单 —— 由JackJiang添加 */
@property (weak, nonatomic, readwrite) UILongPressGestureRecognizer *longPressGestureRecognizer;

/** 多选模式下的勾选框视图 */
@property (nonatomic, strong) UIView *multiSelectCheckbox;
@property (nonatomic, strong) CAShapeLayer *multiSelectCheckboxBorderLayer;
@property (nonatomic, strong) CAShapeLayer *multiSelectCheckboxFillLayer;
@property (nonatomic, strong) CAShapeLayer *multiSelectCheckboxCheckmarkLayer;
@property (nonatomic, strong) UIView *multiSelectEditingBackgroundView;
@property (nonatomic, strong) UIView *multiSelectSelectionOverlayView;
@property (nonatomic, assign) NSUInteger multiSelectAnimationToken;
/** 多选勾选框的 leading 约束（用于动画） */
@property (nonatomic, strong) NSLayoutConstraint *checkboxLeadingConstraint;
/** 多选模式下需要右移的 leading 约束数组（仅 Incoming cell 有值） */
@property (nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *multiSelectShiftConstraints;
/** 上述约束的原始 constant 值，与 multiSelectShiftConstraints 一一对应 */
@property (nonatomic, strong) NSMutableArray<NSNumber *> *multiSelectShiftOriginalConstants;

/** 多行时时间/已读是否与最后一行同行（从 layout attributes 传入，用于 layoutSubviews 中定位时间视图） */
@property (nonatomic, assign) BOOL rb_timeFitsOnSameLine;
/** 时间视图贴底约束（与 rb_bubbleTimeStatusCenterYConstraint 二选一生效） */
@property (nonatomic, strong) NSLayoutConstraint *rb_bubbleTimeStatusBottomConstraint;
/** 时间视图垂直居中偏移（与最后一行对齐时使用） */
@property (nonatomic, strong) NSLayoutConstraint *rb_bubbleTimeStatusCenterYConstraint;

- (void)jsq_handleTapGesture:(UITapGestureRecognizer *)tap;
- (void)jsq_updateMultiSelectCheckboxSelected:(BOOL)selected animated:(BOOL)animated;
- (UIBezierPath *)jsq_multiSelectCheckboxCirclePathForBounds:(CGRect)bounds inset:(CGFloat)inset;
- (UIBezierPath *)jsq_multiSelectCheckboxCheckmarkPathForBounds:(CGRect)bounds;

- (void)jsq_updateConstraint:(NSLayoutConstraint *)constraint withConstant:(CGFloat)constant;

/// 会话列表滚动中返回 YES；此时跳过 textView.layoutManager 路径，减轻 TextKit1 compatibility 日志与主线程排版开销。
- (BOOL)rb_hostCollectionViewIsActivelyScrolling;

@end


@implementation JSQMessagesCollectionViewCell

#pragma mark - Class methods

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
//        jsqMessagesCollectionViewCellActions = [NSMutableSet new];
    });
}

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];
}

+ (NSString *)cellReuseIdentifier
{
    return NSStringFromClass([self class]);
}

+ (NSString *)mediaCellReuseIdentifier
{
    return [NSString stringWithFormat:@"%@_JSQMedia", NSStringFromClass([self class])];
}

//+ (void)registerMenuAction:(SEL)action
//{
//    [jsqMessagesCollectionViewCellActions addObject:NSStringFromSelector(action)];
//}

#pragma mark - Initialization

- (void)awakeFromNib
{
    [super awakeFromNib];

    //###### Fix by JackJiang at 20240327：
    //# 注释掉此行代码的原因是，如果设置此属性为NO，则控制台下将报“Changing the translatesAutoresizingMaskIntoConstraints property of a UICollectionViewCell that is managed by a UICollectionView is not supported, and will result in incorrect self-sizing”这样的警告，去掉后则不会报。
    //# 注释掉此行后带来的影响，需要进一步测试的观察，如对消息气泡的大小显示有影响，则应撤销此次注释！
//  [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    //###### END

    self.backgroundColor = [UIColor whiteColor];

    UIView *editingBg = [[UIView alloc] initWithFrame:CGRectZero];
    editingBg.userInteractionEnabled = NO;
    editingBg.backgroundColor = [UIColor clearColor];
    editingBg.hidden = YES;
    [self.contentView insertSubview:editingBg atIndex:0];
    self.multiSelectEditingBackgroundView = editingBg;

    UIView *selectionOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    selectionOverlay.userInteractionEnabled = NO;
    selectionOverlay.backgroundColor = UI_DEFAULT_TABLE_VIEW_SELECTED_BG_COLOR;
    selectionOverlay.hidden = YES;
    selectionOverlay.alpha = 0.0f;
    [self.contentView insertSubview:selectionOverlay aboveSubview:editingBg];
    self.multiSelectSelectionOverlayView = selectionOverlay;
    // 容器背景跟随 cell 背景，保持不透明 → UIContextMenu 动画时无透明区域无黑边

//    self.cellTopLabelHeightConstraint.constant = 0.0f;
//    self.messageBubbleTopLabelHeightConstraint.constant = 0.0f;
//    self.cellBottomLabelHeightConstraint.constant = 0.0f;

    self.avatarViewSize = CGSizeZero;

    // 气泡尾巴在下方：对背景图做垂直翻转（仅翻转 imageView，文字等子视图不受影响）
    if (self.messageBubbleImageView) {
        self.messageBubbleImageView.transform = CGAffineTransformMakeScale(1.0, -1.0);
    }

    self.cellTopLabel.textAlignment = NSTextAlignmentCenter;
    self.cellTopLabel.font = [UIFont boldSystemFontOfSize:12.0f];
    self.cellTopLabel.textColor = [UIColor lightGrayColor];

    self.messageBubbleTopLabel.font = [UIFont systemFontOfSize:12.0f];
    self.messageBubbleTopLabel.textColor = [UIColor lightGrayColor];

    self.cellBottomLabel.font = [UIFont systemFontOfSize:11.0f];
    self.cellBottomLabel.textColor = [UIColor lightGrayColor];

    // 点击手势
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(jsq_handleTapGesture:)];
    [self addGestureRecognizer:tap];
    self.tapGestureRecognizer = tap;
    
    // 长按手势 — 所有 iOS 版本均使用自定义画布式菜单
    {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(jsq_handleLongPressGesture:)];
        longPress.minimumPressDuration = .3;
        [self.messageBubbleContainerView addGestureRecognizer:longPress];
        self.longPressGestureRecognizer = longPress;
    }
    
    // ====== 气泡内的时间+已读状态视图 ======
    [self jsq_setupBubbleTimeStatusView];
    
    // 多行文本时：textView 底部预留时间/已读行高度（默认 18）；是否与最后一行同行由 applyLayoutAttributes 根据 messageBubbleTimeFitsOnSameLine 再设
    static const CGFloat kTimeReadRowAreaHeight = 18.0f;
    if (self.textViewBottomVerticalSpaceConstraint) {
        self.textViewBottomVerticalSpaceConstraint.constant = kTimeReadRowAreaHeight;
    }
    
    // ====== 多选模式勾选框 ======
    [self jsq_setupMultiSelectCheckbox];
    
    // ====== 收集 Incoming cell 中需要在多选模式下右移的 leading 约束 ======
    [self jsq_collectMultiSelectShiftConstraints];
}

- (void)jsq_setupBubbleTimeStatusView
{
    UIView *tsView = [[UIView alloc] init];
    tsView.translatesAutoresizingMaskIntoConstraints = NO;
    tsView.backgroundColor = [UIColor clearColor];
    tsView.userInteractionEnabled = NO;
    tsView.hidden = YES;
    
    // 时间标签 (tag=1001)
    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    timeLabel.font = [UIFont systemFontOfSize:10.0f];
    timeLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    timeLabel.tag = 1001;
    [tsView addSubview:timeLabel];
    
    // 已读/未读图标 (tag=1002)
    UIImageView *statusIcon = [[UIImageView alloc] init];
    statusIcon.translatesAutoresizingMaskIntoConstraints = NO;
    statusIcon.contentMode = UIViewContentModeScaleAspectFit;
    statusIcon.tag = 1002;
    [tsView addSubview:statusIcon];
    
    // 文字状态标签 - 用于"发送失败"/"上传中"等 (tag=1003)
    UILabel *statusTextLabel = [[UILabel alloc] init];
    statusTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusTextLabel.font = [UIFont systemFontOfSize:10.0f];
    statusTextLabel.tag = 1003;
    statusTextLabel.hidden = YES;
    [tsView addSubview:statusTextLabel];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 时间标签在左侧
        [timeLabel.leadingAnchor constraintEqualToAnchor:tsView.leadingAnchor],
        [timeLabel.centerYAnchor constraintEqualToAnchor:tsView.centerYAnchor],
        
        // 已读/未读图标在时间标签右侧
        [statusIcon.leadingAnchor constraintEqualToAnchor:timeLabel.trailingAnchor constant:3],
        [statusIcon.trailingAnchor constraintEqualToAnchor:tsView.trailingAnchor],
        [statusIcon.centerYAnchor constraintEqualToAnchor:tsView.centerYAnchor],
        [statusIcon.widthAnchor constraintEqualToConstant:12],
        [statusIcon.heightAnchor constraintEqualToConstant:9],
        
        // 文字状态标签（与图标互斥显示）
        [statusTextLabel.leadingAnchor constraintEqualToAnchor:timeLabel.trailingAnchor constant:3],
        [statusTextLabel.centerYAnchor constraintEqualToAnchor:tsView.centerYAnchor],
    ]];
    
    [self.messageBubbleContainerView addSubview:tsView];
    
    // 时间+已读贴气泡右侧；用 container.bottom 以兼容媒体消息（媒体时 textView 会被移除）
    NSLayoutConstraint *bottomC = [tsView.bottomAnchor constraintEqualToAnchor:self.messageBubbleContainerView.bottomAnchor constant:0];
    self.rb_bubbleTimeStatusCenterYConstraint = [tsView.centerYAnchor constraintEqualToAnchor:self.messageBubbleContainerView.centerYAnchor constant:0];
    NSLayoutConstraint *hC = [tsView.heightAnchor constraintEqualToConstant:14];
    hC.priority = UILayoutPriorityDefaultHigh; // 与「同行 centerY」并存时，极矮气泡上避免与父视图高度硬冲突
    [NSLayoutConstraint activateConstraints:@[
        [tsView.trailingAnchor constraintEqualToAnchor:self.messageBubbleContainerView.trailingAnchor constant:-8],
        bottomC,
        hC,
    ]];
    self.rb_bubbleTimeStatusBottomConstraint = bottomC;
    self.bubbleTimeStatusView = tsView;
}

- (void)jsq_setupMultiSelectCheckbox
{
    UIView *checkbox = [[UIView alloc] init];
    checkbox.translatesAutoresizingMaskIntoConstraints = NO;
    checkbox.userInteractionEnabled = NO;
    checkbox.hidden = YES;
    checkbox.backgroundColor = UIColor.clearColor;
    
    [self.contentView addSubview:checkbox];
    
    // 勾选框位置向归档编辑态靠齐：留出固定左侧编辑区域。
    self.checkboxLeadingConstraint = [checkbox.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:-40];
    [NSLayoutConstraint activateConstraints:@[
        self.checkboxLeadingConstraint,
        [checkbox.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [checkbox.widthAnchor constraintEqualToConstant:26],
        [checkbox.heightAnchor constraintEqualToConstant:26],
    ]];
    
    self.multiSelectCheckbox = checkbox;

    CGRect layerBounds = CGRectMake(0, 0, 26.0f, 26.0f);
    CAShapeLayer *borderLayer = [CAShapeLayer layer];
    borderLayer.frame = layerBounds;
    borderLayer.path = [self jsq_multiSelectCheckboxCirclePathForBounds:layerBounds inset:1.6f].CGPath;
    borderLayer.fillColor = UIColor.clearColor.CGColor;
    borderLayer.strokeColor = [UIColor colorWithWhite:0.74f alpha:1.0f].CGColor;
    borderLayer.lineWidth = 1.8f;
    borderLayer.contentsScale = UIScreen.mainScreen.scale;
    [checkbox.layer addSublayer:borderLayer];
    self.multiSelectCheckboxBorderLayer = borderLayer;

    CAShapeLayer *fillLayer = [CAShapeLayer layer];
    fillLayer.frame = layerBounds;
    fillLayer.path = [self jsq_multiSelectCheckboxCirclePathForBounds:layerBounds inset:1.6f].CGPath;
    fillLayer.fillColor = [UIColor colorWithRed:0.20f green:0.49f blue:0.96f alpha:1.0f].CGColor;
    fillLayer.strokeColor = [UIColor colorWithRed:0.20f green:0.49f blue:0.96f alpha:1.0f].CGColor;
    fillLayer.lineWidth = 1.0f;
    fillLayer.opacity = 0.0f;
    fillLayer.transform = CATransform3DMakeScale(0.2f, 0.2f, 1.0f);
    fillLayer.contentsScale = UIScreen.mainScreen.scale;
    [checkbox.layer addSublayer:fillLayer];
    self.multiSelectCheckboxFillLayer = fillLayer;

    CAShapeLayer *checkmarkLayer = [CAShapeLayer layer];
    checkmarkLayer.frame = layerBounds;
    checkmarkLayer.path = [self jsq_multiSelectCheckboxCheckmarkPathForBounds:layerBounds].CGPath;
    checkmarkLayer.fillColor = UIColor.clearColor.CGColor;
    checkmarkLayer.strokeColor = UIColor.whiteColor.CGColor;
    checkmarkLayer.lineWidth = 2.2f;
    checkmarkLayer.lineCap = kCALineCapRound;
    checkmarkLayer.lineJoin = kCALineJoinRound;
    checkmarkLayer.strokeEnd = 0.0f;
    checkmarkLayer.contentsScale = UIScreen.mainScreen.scale;
    [checkbox.layer addSublayer:checkmarkLayer];
    self.multiSelectCheckboxCheckmarkLayer = checkmarkLayer;
}

/// 收集 Incoming cell 中在多选模式下需要右移的 leading 约束
/// 这些约束连接的是 avatarContainerView / cellBottomLabel / quoteContainerView 到 cell/contentView 左边缘
- (void)jsq_collectMultiSelectShiftConstraints
{
    self.multiSelectShiftConstraints = [NSMutableArray array];
    self.multiSelectShiftOriginalConstants = [NSMutableArray array];
    
    // 仅 Incoming cell 需要右移（Outgoing cell 头像在右侧，不需要处理）
    if (![self isKindOfClass:[JSQMessagesCollectionViewCellIncoming class]]) {
        return;
    }
    
    // 需要右移的视图集合
    NSMutableSet *viewsToShift = [NSMutableSet set];
    if (self.avatarContainerView)  [viewsToShift addObject:self.avatarContainerView];
    if (self.cellBottomLabel)      [viewsToShift addObject:self.cellBottomLabel];
    if (self.quoteContainerView)   [viewsToShift addObject:self.quoteContainerView];
    
    if (viewsToShift.count == 0) return;
    
    // 在 cell 本身和 contentView 上都搜索约束（XIB 加载后约束可能在任一层级）
    NSArray<UIView *> *constraintSources = @[self, self.contentView];
    
    for (UIView *source in constraintSources) {
        for (NSLayoutConstraint *c in source.constraints) {
            // 查找模式: view.leading = parent.leading + constant
            // 或等效模式: view.left = parent.left + constant
            BOOL isLeadingOrLeft = (c.firstAttribute == NSLayoutAttributeLeading || c.firstAttribute == NSLayoutAttributeLeft);
            BOOL secondIsLeadingOrLeft = (c.secondAttribute == NSLayoutAttributeLeading || c.secondAttribute == NSLayoutAttributeLeft);
            BOOL secondIsParent = (c.secondItem == self || c.secondItem == self.contentView);
            
            if (isLeadingOrLeft && secondIsLeadingOrLeft && secondIsParent
                && [viewsToShift containsObject:c.firstItem]) {
                [self.multiSelectShiftConstraints addObject:c];
                [self.multiSelectShiftOriginalConstants addObject:@(c.constant)];
            }
        }
    }
    
    NSLog(@"【MultiSelect】收集到 %lu 个需要右移的约束（%@）",
          (unsigned long)self.multiSelectShiftConstraints.count,
          NSStringFromClass([self class]));
}

/// 根据选中状态返回对应的SF Symbol图标
- (UIBezierPath *)jsq_multiSelectCheckboxCirclePathForBounds:(CGRect)bounds inset:(CGFloat)inset
{
    CGRect circleRect = CGRectInset(bounds, inset, inset);
    return [UIBezierPath bezierPathWithOvalInRect:circleRect];
}

- (UIBezierPath *)jsq_multiSelectCheckboxCheckmarkPathForBounds:(CGRect)bounds
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = CGRectGetWidth(bounds);
    CGFloat h = CGRectGetHeight(bounds);
    [path moveToPoint:CGPointMake(w * 0.30f, h * 0.54f)];
    [path addLineToPoint:CGPointMake(w * 0.46f, h * 0.69f)];
    [path addLineToPoint:CGPointMake(w * 0.74f, h * 0.37f)];
    return path;
}

- (void)jsq_updateMultiSelectCheckboxSelected:(BOOL)selected animated:(BOOL)animated
{
    if (self.multiSelectCheckbox == nil) {
        return;
    }
    [self.multiSelectCheckbox.layer removeAllAnimations];
    [self.multiSelectCheckboxBorderLayer removeAllAnimations];
    [self.multiSelectCheckboxFillLayer removeAllAnimations];
    [self.multiSelectCheckboxCheckmarkLayer removeAllAnimations];

    NSUInteger animationToken = self.multiSelectAnimationToken + 1;
    self.multiSelectAnimationToken = animationToken;

    if (!animated || self.multiSelectCheckbox.hidden) {
        self.multiSelectCheckbox.transform = CGAffineTransformIdentity;
        self.multiSelectCheckbox.alpha = 1.0f;
        self.multiSelectCheckboxBorderLayer.opacity = selected ? 0.0f : 1.0f;
        self.multiSelectCheckboxFillLayer.opacity = selected ? 1.0f : 0.0f;
        self.multiSelectCheckboxFillLayer.transform = CATransform3DIdentity;
        self.multiSelectCheckboxCheckmarkLayer.strokeEnd = selected ? 1.0f : 0.0f;
        return;
    }

    self.multiSelectCheckbox.transform = CGAffineTransformIdentity;
    CABasicAnimation *borderOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    borderOpacity.duration = selected ? 0.10 : 0.14;
    borderOpacity.fromValue = @(self.multiSelectCheckboxBorderLayer.opacity);
    borderOpacity.toValue = @(selected ? 0.0f : 1.0f);
    self.multiSelectCheckboxBorderLayer.opacity = selected ? 0.0f : 1.0f;
    [self.multiSelectCheckboxBorderLayer addAnimation:borderOpacity forKey:@"opacity"];

    if (selected) {
        CABasicAnimation *fillOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fillOpacity.duration = 0.11;
        fillOpacity.fromValue = @(self.multiSelectCheckboxFillLayer.opacity);
        fillOpacity.toValue = @1.0f;
        fillOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        self.multiSelectCheckboxFillLayer.opacity = 1.0f;
        [self.multiSelectCheckboxFillLayer addAnimation:fillOpacity forKey:@"opacity"];
        self.multiSelectCheckboxFillLayer.transform = CATransform3DIdentity;

        __weak typeof(self) wself = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.09 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (!sself || sself.multiSelectAnimationToken != animationToken || !sself.multiSelected) {
                return;
            }
            CABasicAnimation *checkmarkStroke = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            checkmarkStroke.duration = 0.20;
            checkmarkStroke.fromValue = @(sself.multiSelectCheckboxCheckmarkLayer.strokeEnd);
            checkmarkStroke.toValue = @1.0f;
            checkmarkStroke.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            sself.multiSelectCheckboxCheckmarkLayer.strokeEnd = 1.0f;
            [sself.multiSelectCheckboxCheckmarkLayer addAnimation:checkmarkStroke forKey:@"strokeEnd"];
        });
    } else {
        CABasicAnimation *checkmarkStroke = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        checkmarkStroke.duration = 0.10;
        checkmarkStroke.fromValue = @(self.multiSelectCheckboxCheckmarkLayer.strokeEnd);
        checkmarkStroke.toValue = @0.0f;
        checkmarkStroke.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        self.multiSelectCheckboxCheckmarkLayer.strokeEnd = 0.0f;
        [self.multiSelectCheckboxCheckmarkLayer addAnimation:checkmarkStroke forKey:@"strokeEnd"];

        __weak typeof(self) wself = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (!sself || sself.multiSelectAnimationToken != animationToken || sself.multiSelected) {
                return;
            }
            CABasicAnimation *fillOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
            fillOpacity.duration = 0.14;
            fillOpacity.fromValue = @(sself.multiSelectCheckboxFillLayer.opacity);
            fillOpacity.toValue = @0.0f;
            fillOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            sself.multiSelectCheckboxFillLayer.opacity = 0.0f;
            [sself.multiSelectCheckboxFillLayer addAnimation:fillOpacity forKey:@"opacity"];
        });
    }
    self.multiSelectCheckbox.alpha = 1.0f;
}


- (void)dealloc
{
    _delegate = nil;

    _cellTopLabel = nil;
    _messageBubbleTopLabel = nil;
    _cellBottomLabel = nil;

    _textView = nil;
    _messageBubbleImageView = nil;
    _mediaView = nil;

    _avatarImageView = nil;
    
    _quoteContentLabel = nil;
    _quoteIconView = nil;
    _quotePlayIconView = nil;
    
    _bubbleTimeStatusView = nil;
    _multiSelectCheckbox = nil;
    _multiSelectCheckboxBorderLayer = nil;
    _multiSelectCheckboxFillLayer = nil;
    _multiSelectCheckboxCheckmarkLayer = nil;

    [_tapGestureRecognizer removeTarget:nil action:NULL];
    _tapGestureRecognizer = nil;
    
    [_longPressGestureRecognizer removeTarget:nil action:NULL];
    _longPressGestureRecognizer = nil;
}


#pragma mark - Collection view cell

// 当cell从可视区滑出时，把内容清掉，防止表格显示错乱，这是常识
- (void)prepareForReuse
{
    [super prepareForReuse];

    self.cellTopLabel.text = nil;
    self.messageBubbleTopLabel.text = nil;
    self.cellBottomLabel.text = nil;

    self.textView.dataDetectorTypes = UIDataDetectorTypeNone;
    self.textView.text = nil;
    self.textView.attributedText = nil;

    self.avatarImageView.image = nil;
    self.avatarImageView.highlightedImage = nil;
    
    self.quoteContentLabel.text = nil;
    self.quoteIconView.image = nil;
    self.quoteIconView.highlightedImage = nil;
    self.quotePlayIconView.image = nil;
    self.quotePlayIconView.highlightedImage = nil;
    
    // 重置多选状态
    // 注意：不重置 multiSelectMode，因为它由外部控制
    self.multiSelected = NO;
    self.multiSelectAnimationToken += 1;
    self.multiSelectEditingBackgroundView.hidden = !self.multiSelectMode;
    self.multiSelectSelectionOverlayView.hidden = YES;
    self.multiSelectSelectionOverlayView.alpha = 0.0f;
    [self setSelected:NO];
    
    // 重置气泡内时间+状态视图
    if (self.bubbleTimeStatusView) {
        self.bubbleTimeStatusView.hidden = YES;
        self.bubbleTimeStatusView.backgroundColor = [UIColor clearColor];
        UILabel *timeLabel = [self.bubbleTimeStatusView viewWithTag:1001];
        timeLabel.text = nil;
        timeLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        UIImageView *statusIcon = [self.bubbleTimeStatusView viewWithTag:1002];
        statusIcon.image = nil;
        statusIcon.hidden = NO;
        UILabel *statusText = [self.bubbleTimeStatusView viewWithTag:1003];
        statusText.text = nil;
        statusText.hidden = YES;
    }
    
    self.textView.textContainer.exclusionPaths = nil;
    
//    // 清除选中状态
//    [self setSelected:NO];// !!!
}

- (BOOL)rb_hostCollectionViewIsActivelyScrolling
{
    for (UIView *v = self.superview; v != nil; v = v.superview) {
        if ([v isKindOfClass:[UICollectionView class]]) {
            UICollectionView *cv = (UICollectionView *)v;
            return cv.dragging || cv.decelerating || cv.tracking;
        }
    }
    return NO;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat editAreaWidth = 44.0f;
    self.multiSelectEditingBackgroundView.frame = CGRectMake(0, 0, editAreaWidth, CGRectGetHeight(self.contentView.bounds));
    self.multiSelectSelectionOverlayView.frame = self.contentView.bounds;
    if ([self rb_hostCollectionViewIsActivelyScrolling]) {
        return;
    }
    [self rb_layoutBubbleTimeStatusAndExclusionConverged];
    // 首次 layout 时 NSLayoutManager 可能尚未就绪，下一 runloop 再更新一次以保证位置一致（滚动中不派发，避免反复触达 layoutManager）
    if (self.rb_timeFitsOnSameLine && self.textView.superview == self.messageBubbleContainerView
        && (self.textView.text.length > 0 || self.textView.attributedText.length > 0)) {
        __weak typeof(self) wself = self;
        NSString *contentSignature = [self.textView.attributedText.string copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (!sself || ![sself.textView.attributedText.string isEqualToString:contentSignature]) return;
            if ([sself rb_hostCollectionViewIsActivelyScrolling]) return;
            [sself rb_layoutBubbleTimeStatusAndExclusionConverged];
        });
    }
}

/// 时间条位置与 exclusionPaths 互相影响排版，单次 layout 可能未对齐末行；少量迭代收敛。
- (void)rb_layoutBubbleTimeStatusAndExclusionConverged
{
    if ([self rb_hostCollectionViewIsActivelyScrolling]) {
        return;
    }
    [self rb_updateTimeViewPositionIfOnSameLine];
    [self rb_applyTimeAreaExclusionPathIfNeeded];
    [self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
}

- (void)rb_refreshBubbleTimeLayoutIfNeeded
{
    if ([self rb_hostCollectionViewIsActivelyScrolling]) return;
    if (!self.bubbleTimeStatusView || self.bubbleTimeStatusView.hidden) return;
    if (!self.rb_timeFitsOnSameLine) return;
    if (self.textView.superview != self.messageBubbleContainerView) return;
    NSString *plain = self.textView.text;
    if (plain.length == 0 && self.textView.attributedText.length > 0) {
        plain = self.textView.attributedText.string;
    }
    if (plain.length == 0) return;
    [self rb_layoutBubbleTimeStatusAndExclusionConverged];
}

/// 仅在「时间与最后一行同行」时，对右下角时间+已读区域设置 exclusionPaths，避免文字叠在时间上图标上；不设整段 textContainerInset.right，以免长文右侧大块留白
- (void)rb_applyTimeAreaExclusionPathIfNeeded
{
    NSTextContainer *tc = self.textView.textContainer;
    if ([self rb_hostCollectionViewIsActivelyScrolling]) {
        tc.exclusionPaths = nil;
        return;
    }
    if (!tc || self.textView.superview != self.messageBubbleContainerView || self.textView.text.length == 0
        || self.bubbleTimeStatusView.hidden || !self.rb_timeFitsOnSameLine) {
        tc.exclusionPaths = nil;
        return;
    }
    CGRect timeInTV = [self.textView convertRect:self.bubbleTimeStatusView.bounds fromView:self.bubbleTimeStatusView];
    if (timeInTV.size.width < 1.f || timeInTV.size.height < 1.f) {
        tc.exclusionPaths = nil;
        return;
    }
    UIEdgeInsets inset = self.textView.textContainerInset;
    CGFloat lp = self.textView.textContainer.lineFragmentPadding;
    CGRect exclusion = CGRectMake(
        CGRectGetMinX(timeInTV) - inset.left - lp,
        CGRectGetMinY(timeInTV) - inset.top,
        timeInTV.size.width,
        timeInTV.size.height
    );
    CGFloat cw = CGRectGetWidth(self.textView.bounds) - inset.left - inset.right - 2.f * lp;
    CGFloat ch = CGRectGetHeight(self.textView.bounds) - inset.top - inset.bottom;
    if (cw < 8.f || ch < 8.f) {
        tc.exclusionPaths = nil;
        return;
    }
    exclusion = CGRectInset(exclusion, -2.f, -2.f);
    exclusion = CGRectIntersection(exclusion, CGRectMake(0.f, 0.f, cw, ch));
    if (CGRectIsEmpty(exclusion) || exclusion.size.width < 2.f || exclusion.size.height < 2.f) {
        tc.exclusionPaths = nil;
        return;
    }
    tc.exclusionPaths = @[[UIBezierPath bezierPathWithRect:CGRectIntegral(exclusion)]];
}

/// 当 rb_timeFitsOnSameLine 时，将时间/已读视图与最后一行文字垂直对齐（避免有的正确有的偏下）
- (void)rb_updateTimeViewPositionIfOnSameLine
{
    if (!self.bubbleTimeStatusView || !self.messageBubbleContainerView) return;
    if ([self rb_hostCollectionViewIsActivelyScrolling]) {
        if (self.rb_bubbleTimeStatusBottomConstraint) self.rb_bubbleTimeStatusBottomConstraint.active = YES;
        if (self.rb_bubbleTimeStatusCenterYConstraint) self.rb_bubbleTimeStatusCenterYConstraint.active = NO;
        return;
    }
    NSString *plain = self.textView.text;
    if (plain.length == 0 && self.textView.attributedText.length > 0) {
        plain = self.textView.attributedText.string;
    }
    if (!self.rb_timeFitsOnSameLine || self.textView.superview != self.messageBubbleContainerView || plain.length == 0) {
        if (self.rb_bubbleTimeStatusBottomConstraint) self.rb_bubbleTimeStatusBottomConstraint.active = YES;
        if (self.rb_bubbleTimeStatusCenterYConstraint) self.rb_bubbleTimeStatusCenterYConstraint.active = NO;
        return;
    }
    NSLayoutManager *lm = self.textView.layoutManager;
    NSTextContainer *tc = self.textView.textContainer;
    [lm ensureLayoutForTextContainer:tc];
    NSRange glyphRange = [lm glyphRangeForTextContainer:tc];
    if (glyphRange.length == 0) {
        if (self.rb_bubbleTimeStatusBottomConstraint) self.rb_bubbleTimeStatusBottomConstraint.active = YES;
        if (self.rb_bubbleTimeStatusCenterYConstraint) self.rb_bubbleTimeStatusCenterYConstraint.active = NO;
        return;
    }
    // 避免正文以换行结尾时「最后一个 glyph」落在空行上，导致时间条对齐到错误垂直位置
    NSInteger lastCharIdx = (NSInteger)plain.length - 1;
    for (; lastCharIdx >= 0; lastCharIdx--) {
        unichar c = [plain characterAtIndex:(NSUInteger)lastCharIdx];
        if ([[NSCharacterSet newlineCharacterSet] characterIsMember:c]) {
            continue;
        }
        break;
    }
    if (lastCharIdx < 0) {
        if (self.rb_bubbleTimeStatusBottomConstraint) self.rb_bubbleTimeStatusBottomConstraint.active = YES;
        if (self.rb_bubbleTimeStatusCenterYConstraint) self.rb_bubbleTimeStatusCenterYConstraint.active = NO;
        return;
    }
    NSUInteger glyphForLastChar = [lm glyphIndexForCharacterAtIndex:(NSUInteger)lastCharIdx];
    NSUInteger lastGlyph = glyphForLastChar;
    if (lastGlyph < glyphRange.location || lastGlyph >= glyphRange.location + glyphRange.length) {
        lastGlyph = glyphRange.location + glyphRange.length - 1;
    }
    CGRect lastLineRect = [lm lineFragmentUsedRectForGlyphAtIndex:lastGlyph effectiveRange:NULL];
    // NSLayoutManager 返回的是 textContainer 坐标系，需加上 textContainerInset 得到 textView 内坐标，再转换到 container
    UIEdgeInsets inset = self.textView.textContainerInset;
    CGRect lastLineInTextView = CGRectMake(lastLineRect.origin.x + inset.left, lastLineRect.origin.y + inset.top, lastLineRect.size.width, lastLineRect.size.height);
    CGRect lastLineInContainer = [self.messageBubbleContainerView convertRect:lastLineInTextView fromView:self.textView];
    CGFloat containerH = self.messageBubbleContainerView.bounds.size.height;
    if (containerH < 1.0f) return;
    // 气泡区过矮时无法同时满足「高度 14 + 相对中心 Y 对齐」；改回贴底，避免 Outgoing 等场景下 Auto Layout 破约束
    static const CGFloat kRBBubbleTimeMinHForCenterY = 18.0f;
    if (containerH < kRBBubbleTimeMinHForCenterY) {
        if (self.rb_bubbleTimeStatusBottomConstraint) self.rb_bubbleTimeStatusBottomConstraint.active = YES;
        if (self.rb_bubbleTimeStatusCenterYConstraint) self.rb_bubbleTimeStatusCenterYConstraint.active = NO;
        return;
    }
    CGFloat timeViewHalfH = 7.0f;
    static const CGFloat kTimeReadSameLineOffsetDown = 5.0f; // 时间/已读再往下一点
    CGFloat constant = (CGRectGetMidY(lastLineInContainer) - containerH * 0.5f) + kTimeReadSameLineOffsetDown;
    CGFloat maxConstant = (containerH * 0.5f - timeViewHalfH);
    constant = (CGFloat)MIN((double)maxConstant, (double)MAX((double)(-maxConstant), (double)constant));
    if (self.rb_bubbleTimeStatusCenterYConstraint) {
        self.rb_bubbleTimeStatusCenterYConstraint.constant = constant;
        self.rb_bubbleTimeStatusCenterYConstraint.active = YES;
    }
    if (self.rb_bubbleTimeStatusBottomConstraint) {
        self.rb_bubbleTimeStatusBottomConstraint.active = NO;
    }
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    return layoutAttributes;
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];

    JSQMessagesCollectionViewLayoutAttributes *customAttributes = (JSQMessagesCollectionViewLayoutAttributes *)layoutAttributes;

    if (self.textView.font != customAttributes.messageBubbleFont) {
        self.textView.font = customAttributes.messageBubbleFont;
    }

    if (!UIEdgeInsetsEqualToEdgeInsets(self.textView.textContainerInset, customAttributes.textViewTextContainerInsets)) {
        self.textView.textContainerInset = customAttributes.textViewTextContainerInsets;
    }

    self.textViewFrameInsets = customAttributes.textViewFrameInsets;

    self.rb_timeFitsOnSameLine = customAttributes.messageBubbleTimeFitsOnSameLine;
    if (self.textViewBottomVerticalSpaceConstraint) {
        // 时间同行时只留 2pt；换行时 textView 贴底，时间行在 textView 的 25pt 底部 inset 内，不再额外留 18pt 避免位置偏下
        self.textViewBottomVerticalSpaceConstraint.constant = self.rb_timeFitsOnSameLine ? 2.0f : 0.0f;
    }

    [self jsq_updateConstraint:self.messageBubbleContainerWidthConstraint
                  withConstant:customAttributes.messageBubbleContainerViewWidth];

    [self jsq_updateConstraint:self.cellTopLabelHeightConstraint
                  withConstant:customAttributes.cellTopLabelHeight];
    
    // 昵称行高 = xib 中 top(2pt) + 昵称 label 高度；此处设 label 高度，故减 2 与 Incoming xib 一致
    [self jsq_updateConstraint:self.cellNicknameLabelHeightConstraint
                  withConstant:MAX(0.0f, customAttributes.cellNicknameLabelHeight - 2.0f)];
    
    if (self.textViewTopVerticalSpaceConstraint) {
        if ([self isKindOfClass:[JSQMessagesCollectionViewCellIncoming class]]) {
            self.textViewTopVerticalSpaceConstraint.constant = (customAttributes.cellNicknameLabelHeight > 0.1f) ? 0.0f : -2.0f;
        } else {
            self.textViewTopVerticalSpaceConstraint.constant = 0.0f;
        }
    }

    [self jsq_updateConstraint:self.messageBubbleTopLabelHeightConstraint
                  withConstant:customAttributes.messageBubbleTopLabelHeight];

    [self jsq_updateConstraint:self.cellBottomLabelHeightConstraint
                  withConstant:customAttributes.cellBottomLabelHeight];
    
    [self jsq_updateConstraint:self.quoteContainerTopGapConstraint
                  withConstant:customAttributes.quoteContainerTopGap];
    [self jsq_updateConstraint:self.quoteContainerHeightConstraint
                  withConstant:customAttributes.quoteContainerHeight];
    [self jsq_updateConstraint:self.quoteIconContainerWidthConstraint
                  withConstant:customAttributes.quoteIconContainerWidth];

    if ([self isKindOfClass:[JSQMessagesCollectionViewCellIncoming class]]) {
        self.avatarViewSize = customAttributes.incomingAvatarViewSize;
        if (self.cellNicknameLabel2) {
            self.cellNicknameLabel2.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        }
    }
    else if ([self isKindOfClass:[JSQMessagesCollectionViewCellOutgoing class]]) {
        self.avatarViewSize = customAttributes.outgoingAvatarViewSize;
    }

    if (!self.multiSelectMode) {
        static const CGFloat kJSQBubbleAvatarGap = 7.0f;
        static const CGFloat kJSQCellBottomLabelExtraInset = 6.0f;
        CGFloat offset = customAttributes.messageBubbleHorizontalOffset;
        CGFloat bubbleLeadingInset = self.avatarViewSize.width + kJSQBubbleAvatarGap + offset + kJSQCellBottomLabelExtraInset;
        CGFloat bubbleTrailingInset = self.avatarViewSize.width + kJSQBubbleAvatarGap + kJSQCellBottomLabelExtraInset;
        
        if ([self isKindOfClass:[JSQMessagesCollectionViewCellIncoming class]]) {
            if (self.cellBottomLabelLeadingConstraint) {
                self.cellBottomLabelLeadingConstraint.constant = bubbleLeadingInset;
                for (NSUInteger i = 0; i < self.multiSelectShiftConstraints.count; i++) {
                    NSLayoutConstraint *c = self.multiSelectShiftConstraints[i];
                    if (c == self.cellBottomLabelLeadingConstraint && i < self.multiSelectShiftOriginalConstants.count) {
                        self.multiSelectShiftOriginalConstants[i] = @(bubbleLeadingInset);
                    }
                }
            }
        } else if ([self isKindOfClass:[JSQMessagesCollectionViewCellOutgoing class]]) {
            if (self.cellBottomLabelTrailingConstraint) {
                self.cellBottomLabelTrailingConstraint.constant = bubbleTrailingInset;
            }
        }
    }
    // 我方发出不显示头像；入站：群聊分组仅最后一条显示头像（1=top 2=middle 隐藏，0=single 3=bottom 显示）
    if ([self isKindOfClass:[JSQMessagesCollectionViewCellOutgoing class]]) {
        self.avatarImageView.hidden = YES;
    } else {
        NSInteger pos = customAttributes.messageGroupPosition;
        self.avatarImageView.hidden = (pos == 1 || pos == 2);
    }

    // 无尾气泡往右偏移 2pt（仅对方/入站气泡；我方发出不偏移）
    CGFloat offset = customAttributes.messageBubbleHorizontalOffset;
    static const CGFloat kJSQBubbleAvatarGap = 7.0f;
    if (self.messageBubbleContainerLeadingConstraint) {
        [self jsq_updateConstraint:self.messageBubbleContainerLeadingConstraint withConstant:kJSQBubbleAvatarGap + offset];
    }
    if (self.messageBubbleContainerTrailingConstraint) {
        [self jsq_updateConstraint:self.messageBubbleContainerTrailingConstraint withConstant:kJSQBubbleAvatarGap];
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    if (self.multiSelectMode) {
        self.avatarImageView.highlighted = NO;
        self.messageBubbleImageView.highlighted = NO;
        return;
    }
    self.avatarImageView.highlighted = highlighted;
    self.messageBubbleImageView.highlighted = highlighted;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    if (self.multiSelectMode) {
        self.avatarImageView.highlighted = NO;
        self.messageBubbleImageView.highlighted = NO;
    } else {
        self.avatarImageView.highlighted = selected;
        self.messageBubbleImageView.highlighted = selected;
    }
    BOOL showOverlay = (self.multiSelectMode && selected);
    self.multiSelectSelectionOverlayView.hidden = !showOverlay;
    self.multiSelectSelectionOverlayView.alpha = showOverlay ? 1.0f : 0.0f;
}

//  FIXME: radar 18326340
//         remove when fixed
//         hack for Xcode6 / iOS 8 SDK rendering bug that occurs on iOS 7.x
//         see issue #484
//         https://github.com/jessesquires/JSQMessagesViewController/issues/484
//
- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];

    if ([UIDevice jsq_isCurrentDeviceBeforeiOS8]) {
        self.contentView.frame = bounds;
    }
}


#pragma mark - Menu actions

//# Bug Fix 240329-ios1 by JackJiang, 解决新发图片等消息后长按不显示菜单直到表格刷新时长按才会显示的问题
- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
//    if ([jsqMessagesCollectionViewCellActions containsObject:NSStringFromSelector(aSelector)]) {
//        return YES;
//    }

    return [super respondsToSelector:aSelector];
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
//    if ([jsqMessagesCollectionViewCellActions containsObject:NSStringFromSelector(anInvocation.selector)]) {
//        __unsafe_unretained id sender;
//        [anInvocation getArgument:&sender atIndex:0];
//        [self.delegate messagesCollectionViewCell:self didPerformAction:anInvocation.selector withSender:sender];
//    }
//    else
    {
        [super forwardInvocation:anInvocation];
    }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
//    if ([jsqMessagesCollectionViewCellActions containsObject:NSStringFromSelector(aSelector)]) {
//        return [NSMethodSignature signatureWithObjCTypes:"v@:@"];
//    }

    return [super methodSignatureForSelector:aSelector];
}


#pragma mark - Setters

- (void)setMultiSelectMode:(BOOL)multiSelectMode
{
    if (_multiSelectMode == multiSelectMode) return;
    _multiSelectMode = multiSelectMode;
    
    // 多选模式下内容右移的偏移量，向归档编辑态左侧勾选区对齐。
    static const CGFloat kMultiSelectContentOffset = 40.0;
    
    if (multiSelectMode) {
        // 显示勾选框
        self.multiSelectCheckbox.hidden = NO;
        self.checkboxLeadingConstraint.constant = 14;
        self.multiSelectEditingBackgroundView.hidden = NO;
        
        // 将 Incoming cell 的头像、底部标签、引用容器等整体右移，避免与勾选框重叠
        for (NSUInteger i = 0; i < self.multiSelectShiftConstraints.count; i++) {
            NSLayoutConstraint *c = self.multiSelectShiftConstraints[i];
            CGFloat original = self.multiSelectShiftOriginalConstants[i].doubleValue;
            c.constant = original + kMultiSelectContentOffset;
        }
    } else {
        // 隐藏勾选框
        self.multiSelectCheckbox.hidden = YES;
        self.checkboxLeadingConstraint.constant = -40;
        self.multiSelectEditingBackgroundView.hidden = YES;
        self.multiSelectSelectionOverlayView.hidden = YES;
        self.multiSelectSelectionOverlayView.alpha = 0.0f;
        self.multiSelected = NO;
        [self setSelected:NO];
        
        // 恢复所有约束的原始 constant
        for (NSUInteger i = 0; i < self.multiSelectShiftConstraints.count; i++) {
            NSLayoutConstraint *c = self.multiSelectShiftConstraints[i];
            CGFloat original = self.multiSelectShiftOriginalConstants[i].doubleValue;
            c.constant = original;
        }
    }
    
    [UIView animateWithDuration:0.25 animations:^{
        [self layoutIfNeeded];
    }];
}

- (void)setMultiSelected:(BOOL)multiSelected
{
    if (_multiSelected == multiSelected) {
        return;
    }
    _multiSelected = multiSelected;
    [self setSelected:(self.multiSelectMode && multiSelected)];
    [self jsq_updateMultiSelectCheckboxSelected:multiSelected animated:self.multiSelectMode];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];

    self.cellTopLabel.backgroundColor = backgroundColor;
    self.messageBubbleTopLabel.backgroundColor = backgroundColor;
    self.cellBottomLabel.backgroundColor = backgroundColor;

    self.messageBubbleImageView.backgroundColor = backgroundColor;
    self.avatarImageView.backgroundColor = backgroundColor;

    self.messageBubbleContainerView.backgroundColor = [UIColor clearColor];
    self.avatarContainerView.backgroundColor = backgroundColor;
}

- (void)setAvatarViewSize:(CGSize)avatarViewSize
{
    if (CGSizeEqualToSize(avatarViewSize, self.avatarViewSize)) {
        return;
    }

    [self jsq_updateConstraint:self.avatarContainerViewWidthConstraint withConstant:avatarViewSize.width];
    [self jsq_updateConstraint:self.avatarContainerViewHeightConstraint withConstant:avatarViewSize.height];
}

- (void)setTextViewFrameInsets:(UIEdgeInsets)textViewFrameInsets
{
    if (UIEdgeInsetsEqualToEdgeInsets(textViewFrameInsets, self.textViewFrameInsets)) {
        return;
    }

    [self jsq_updateConstraint:self.textViewTopVerticalSpaceConstraint withConstant:textViewFrameInsets.top];
    [self jsq_updateConstraint:self.textViewBottomVerticalSpaceConstraint withConstant:textViewFrameInsets.bottom];
    [self jsq_updateConstraint:self.textViewAvatarHorizontalSpaceConstraint withConstant:textViewFrameInsets.right];
    [self jsq_updateConstraint:self.textViewMarginHorizontalSpaceConstraint withConstant:textViewFrameInsets.left];
}

- (void)setMediaView:(UIView *)mediaView
{
    [self.messageBubbleImageView removeFromSuperview];
    [self.textView removeFromSuperview];
    
    BOOL isOutgoing = [self isKindOfClass:[JSQMessagesCollectionViewCellOutgoing class]];
    
    if(isOutgoing)
    {
        [mediaView setTranslatesAutoresizingMaskIntoConstraints:NO];
        mediaView.frame = self.messageBubbleContainerView.bounds;
        
        [self.messageBubbleContainerView addSubview:mediaView];
        [self.messageBubbleContainerView jsq_pinAllEdgesOfSubview:mediaView];
    }
    else
    {
        [mediaView setTranslatesAutoresizingMaskIntoConstraints:NO];
        mediaView.frame = self.messageBubbleContainerView.bounds;

        [self.messageBubbleContainerView addSubview:mediaView];
        
        // 说明1：以下4个设置LayoutConstraint的方法，其实就是 [self.messageBubbleContainerView jsq_pinAllEdgesOfSubview:mediaView]的改造
        // 说明2：由于昵称这个组件在消息气泡里的位置有点特殊——它没办法放在 messageBubbleContainerView 这个消息气泡父布局这外（因为放在之外的话它就会高
        //       于头像的显示了，因为头像也在messageBubbleContainerView时），而当显示媒体消息时原来的逻辑是把 messageBubbleContainerView的内容都
        //       清空然后放入 mediaView，这就会导致除文本消息外，这个昵称就没法正常显示了（被mediaView撑死住），所以以下代码的作就是给 mediaView设置
        //       LayoutConstraint时，它的顶部top约束应跳过昵称的高度，这样就不会挡住昵称组件的显示了！
        
        [self.messageBubbleContainerView addConstraint:[NSLayoutConstraint constraintWithItem:self.messageBubbleContainerView
                                                                                    attribute:NSLayoutAttributeBottom
                                                                                    relatedBy:NSLayoutRelationEqual
                                                                                       toItem:mediaView
                                                                                    attribute:NSLayoutAttributeBottom
                                                                                   multiplier:1.0f
                                                                                     constant:0.0f]];
        [self.messageBubbleContainerView addConstraint:[NSLayoutConstraint constraintWithItem:self.messageBubbleContainerView
                                                                                    attribute:NSLayoutAttributeTop
                                                                                    relatedBy:NSLayoutRelationEqual
                                                                                       toItem:mediaView
                                                                                    attribute:NSLayoutAttributeTop
                                                                                   multiplier:1.0f
                                                                                     // 注意：这里的-17就相当于让mediaView的Y作标远离父布局17个像素，从而让出昵称的显示位置
                                                                                     constant:-_cellNicknameLabelHeightConstraint.constant]];
        [self.messageBubbleContainerView addConstraint:[NSLayoutConstraint constraintWithItem:self.messageBubbleContainerView
                                                                                    attribute:NSLayoutAttributeLeading
                                                                                    relatedBy:NSLayoutRelationEqual
                                                                                       toItem:mediaView
                                                                                    attribute:NSLayoutAttributeLeading
                                                                                   multiplier:1.0f
                                                                                     constant:0.0f]];
        [self.messageBubbleContainerView addConstraint:[NSLayoutConstraint constraintWithItem:self.messageBubbleContainerView
                                                                                    attribute:NSLayoutAttributeTrailing
                                                                                    relatedBy:NSLayoutRelationEqual
                                                                                       toItem:mediaView
                                                                                    attribute:NSLayoutAttributeTrailing
                                                                                   multiplier:1.0f
                                                                                     constant:0.0f]];
        
        //    [self.messageBubbleContainerView jsq_pinAllEdgesOfSubview:mediaView];
    }
    
    _mediaView = mediaView;
    // 长按图片/媒体区域也能弹出菜单（气泡容器上的长按在媒体消息时可能被 mediaView 遮挡）
    mediaView.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *mediaLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(jsq_handleLongPressGesture:)];
    mediaLongPress.minimumPressDuration = 0.3;
    [mediaView addGestureRecognizer:mediaLongPress];

    //  because of cell re-use (and caching media views, if using built-in library media item)
    //  we may have dequeued a cell with a media view and add this one on top
    //  thus, remove any additional subviews hidden behind the new media view
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSUInteger i = 0; i < self.messageBubbleContainerView.subviews.count; i++) {
            UIView *sub = self.messageBubbleContainerView.subviews[i];
            if (sub != _mediaView
                // 注意：媒体类型的消息时，昵称组件也不能remove掉哦
                && sub != _cellNicknameLabel2
                // 保留气泡内的时间+状态视图
                && sub != _bubbleTimeStatusView) {
                [sub removeFromSuperview];
            }
        }
        // 确保时间状态视图在最上层
        if (_bubbleTimeStatusView && _bubbleTimeStatusView.superview == self.messageBubbleContainerView) {
            [self.messageBubbleContainerView bringSubviewToFront:_bubbleTimeStatusView];
        }
    });
}


#pragma mark - Getters

- (CGSize)avatarViewSize
{
    return CGSizeMake(self.avatarContainerViewWidthConstraint.constant,
                      self.avatarContainerViewHeightConstraint.constant);
}

- (UIEdgeInsets)textViewFrameInsets
{
    return UIEdgeInsetsMake(self.textViewTopVerticalSpaceConstraint.constant,
                            self.textViewMarginHorizontalSpaceConstraint.constant,
                            self.textViewBottomVerticalSpaceConstraint.constant,
                            self.textViewAvatarHorizontalSpaceConstraint.constant);
}


#pragma mark - Utilities

- (void)jsq_updateConstraint:(NSLayoutConstraint *)constraint withConstant:(CGFloat)constant
{
    if (constraint.constant == constant) {
        return;
    }

    constraint.constant = constant;
}


#pragma mark - Gesture recognizers（点击手势处理方法）

// 点击手势处理方法
- (void)jsq_handleTapGesture:(UITapGestureRecognizer *)tap
{
    // 多选模式下，点击cell的任何位置均切换选中状态
    if (self.multiSelectMode) {
        self.multiSelected = !self.multiSelected;
        // 通过 delegate 通知外部（复用 didTapMessageBubble 回调）
        [self.delegate messagesCollectionViewCellDidTapMessageBubble:self];
        return;
    }
    
    CGPoint touchPt = [tap locationInView:self];

    // 点击的是头像
    if (CGRectContainsPoint(self.avatarContainerView.frame, touchPt)) {
        [self.delegate messagesCollectionViewCellDidTapAvatar:self];
    }
    // 点击的是消息内容
    else if (CGRectContainsPoint(self.messageBubbleContainerView.frame, touchPt)) {
        [self.delegate messagesCollectionViewCellDidTapMessageBubble:self];
    }
    // 点击的是消息引用内容
    else if (CGRectContainsPoint(self.quoteContainerView.frame, touchPt)) {
        [self.delegate rb_messagesCollectionViewCellDidTapQuote:self];
    }
    else {
        [self.delegate messagesCollectionViewCellDidTapCell:self atPosition:touchPt];
    }
}

// 长按手势处理方法 @since 4.3，由JackJiang添加
- (void)jsq_handleLongPressGesture:(UILongPressGestureRecognizer *)sender
{
    // 多选模式下禁止长按弹出菜单
    if (self.multiSelectMode) return;
    
//    if ([sender isKindOfClass:[UILongPressGestureRecognizer class]]) {
        UILongPressGestureRecognizer *recognizer = (UILongPressGestureRecognizer *)sender;
        if(recognizer.state == UIGestureRecognizerStateBegan) {
            CGPoint touchPt = [recognizer locationInView:self];
            NSLog(@"JSQMessagesCollectionViewCell.jsq_handleLongPressGesture - 正在长按聊天列表中的消息气泡(touchPt.x=%f, touchPt.y=%f)！", touchPt.x, touchPt.y);
            [self.delegate rb_messagesCollectionViewCellDidLongPressCell:self atPosition:touchPt];
        }
//    }
}

// 此方法实测中没有任何反应，不知作何用途！
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    CGPoint touchPt = [touch locationInView:self];

    if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return CGRectContainsPoint(self.messageBubbleContainerView.frame, touchPt);
    }
    
    return NO;
}

@end
