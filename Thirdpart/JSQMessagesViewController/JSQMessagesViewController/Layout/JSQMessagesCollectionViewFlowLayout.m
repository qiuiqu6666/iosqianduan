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


#import "JSQMessagesCollectionViewFlowLayout.h"

//#import "JSQMessageData.h"

#import "JSQMessagesCollectionView.h"
#import "JSQMessagesCollectionViewCell.h"

#import "JSQMessagesCollectionViewLayoutAttributes.h"
#import "JSQMessagesCollectionViewFlowLayoutInvalidationContext.h"
#import "JSQMessagesBubblesSizeCalculator.h"

#import "UIImage+JSQMessages.h"
#import "BasicTool.h"
#import "JSQMessage.h"
#import "MsgBodyRoot.h"
#import "UserDefaultsToolKits.h"

// 可选：聊天 VC 提供「显示群成员昵称」缓存，避免布局热路径读 UserDefaults（RainbowChat P0-3）
@protocol JSQMessagesChatDataSourceShowNicknameOptional <NSObject>
@optional
- (BOOL)rb_showGroupMemberNicknameForCurrentChat;
@end

// 消息气泡上的时间默认高度
const CGFloat kJSQMessagesCollectionViewCellLabelHeightDefault = 34.0f;//20.0f;
// 消息气泡上的昵称默认高度(此高度不：label本身的高度)
const CGFloat kJSQMessagesCollectionViewCellNicknameLabelHeightDefault = 17.0f;
// 头像默认大小（改变此值将决定头像的显示大小）
const CGFloat kJSQMessagesCollectionViewAvatarSizeDefault = 40.0f;// before v10.0 36.0f
// 同一分组内相邻气泡的垂直间距（分组间仍用 minimumLineSpacing）
const CGFloat kJSQMessagesGroupInnerLineSpacing = 6.0f;
// 单条 cell 最小高度，避免 size 为 0 导致 flow layout 把后续 cell 叠在一起（快速滑动/数据短暂不一致时防护）
const CGFloat kJSQMessagesMinimumCellHeight = 34.0f;
static const CGFloat kRBSystemInfoMinimumCellHeight = 24.0f;


@interface JSQMessagesCollectionViewFlowLayout ()

@property (strong, nonatomic) NSMutableSet *visibleIndexPaths;
@property (assign, nonatomic) CGFloat latestDelta;
/// 同一 layout pass 内 sizeForItem 结果缓存，invalidation 时清空，减轻重复计算（P0-2）
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSValue *> *jsq_sizeCache;
/// 同一 layout pass 内「分组改 Y」后的 cell frame 缓存，根治堆叠：Y 只由此处 + layoutAttributesForItem 决定，ElementsInRect 只同步此结果
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSValue *> *jsq_attributesFrameCache;

@end



@implementation JSQMessagesCollectionViewFlowLayout

// 告诉编译器，不自动生成getter/setter方法
@dynamic collectionView;

@synthesize bubbleSizeCalculator = _bubbleSizeCalculator;


#pragma mark - Initialization

- (void)jsq_configureFlowLayout
{
    // 表格是垂直方向
    self.scrollDirection = UICollectionViewScrollDirectionVertical;
    
    // 针对ios 26的优化：因ios 26新的标题导航栏是沉浸式（没有背景和下划线），如果设置top衬距的话第一条聊天消息跟标题导航栏间的视角空白就显的有点大，所以要设置top为0
    if (@available(iOS 26, *)) {
        // 决定每行的四周衬距（调小以收紧气泡间隙）
        self.sectionInset = UIEdgeInsetsMake(0.0f, 6.0f, 6.0f, 6.0f);
    }
    // 低版本系统因使用的是传统标题导航栏，保持原先的设置即可
    else {
        // 决定每行的四周衬距（调小以收紧气泡间隙）
        self.sectionInset = UIEdgeInsetsMake(6.0f, 6.0f, 6.0f, 6.0f);
    }
    
    // 垂直滚动时相邻两行之间的最小垂直间距（调小以收紧气泡间隙，实际值由 ChatRootViewController 覆盖）
    self.minimumLineSpacing = 4.0f;
    
    // 聊天正文字体：跟随「设置-界面与显示-字体大小」（小/标准/大），基础 17pt
    _messageBubbleFont = [BasicTool getSystemFontOfSize:17.0f];

    // 改变_messageBubbleLeftRightMargin值将决定消息气泡左或右末尾与屏幕边缘的距离（调小以收紧气泡间隙）
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        _messageBubbleLeftRightMargin = 240.0f;
    }
    else {
        _messageBubbleLeftRightMargin = 44.0f;
    }
    
    _messageBubbleTextViewFrameInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);//UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 6.0f);
//  _messageBubbleTextViewTextContainerInsets = UIEdgeInsetsMake(7.0f, 14.0f, 7.0f, 14.0f);
//    _messageBubbleTextViewTextContainerInsets = UIEdgeInsetsMake(9.0f, 14.0f, 9.0f, 14.0f);// @since 4.1
//    _messageBubbleTextViewTextContainerInsets = UIEdgeInsetsMake(11.0f, 14.0f, 11.0f, 14.0f);// @since 7.1
    // 单行默认：右侧留时间+已读(56)；多行在 jsq_configureMessageCellLayoutAttributes 里改；上 2 昵称与正文间隙，下 3 减小气泡高度
    _messageBubbleTextViewTextContainerInsets = UIEdgeInsetsMake(4.0f, 12.0f, 4.0f, 12.0f);
    
    CGSize defaultAvatarSize = CGSizeMake(kJSQMessagesCollectionViewAvatarSizeDefault, kJSQMessagesCollectionViewAvatarSizeDefault);
    _incomingAvatarViewSize = defaultAvatarSize;
    _outgoingAvatarViewSize = defaultAvatarSize;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(jsq_didReceiveApplicationMemoryWarningNotification:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self jsq_configureFlowLayout];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self jsq_configureFlowLayout];
}

+ (Class)layoutAttributesClass
{
    return [JSQMessagesCollectionViewLayoutAttributes class];
}

+ (Class)invalidationContextClass
{
    return [JSQMessagesCollectionViewFlowLayoutInvalidationContext class];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Setters

- (void)setBubbleSizeCalculator:(id<JSQMessagesBubbleSizeCalculating>)bubbleSizeCalculator
{
    NSParameterAssert(bubbleSizeCalculator != nil);
    _bubbleSizeCalculator = bubbleSizeCalculator;
}

- (void)setMessageBubbleFont:(UIFont *)messageBubbleFont
{
    NSParameterAssert(messageBubbleFont != nil);
    // 不设早退：字号变更时须始终清空气泡尺寸缓存；仅凭 pointSize/fontName 判断易与 refreshFonts 改 UITextView 的时机交织导致漏失效。
    _messageBubbleFont = messageBubbleFont;
    // 气泡尺寸计算器按 messageHash 等缓存 CGSize，键不含字号；仅 invalidateLayout 无法清空该缓存，
    // 全局字号变更后若仍命中旧缓存会导致 cell 高度偏小、气泡内文字底部被裁（设置-字体大小）。
    [self.bubbleSizeCalculator prepareForResettingLayout:self];
    [self invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
}

- (void)setMessageBubbleLeftRightMargin:(CGFloat)messageBubbleLeftRightMargin
{
    NSParameterAssert(messageBubbleLeftRightMargin >= 0.0f);
    _messageBubbleLeftRightMargin = ceilf(messageBubbleLeftRightMargin);
    [self invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
}

- (void)setMessageBubbleTextViewTextContainerInsets:(UIEdgeInsets)messageBubbleTextContainerInsets
{
    if (UIEdgeInsetsEqualToEdgeInsets(_messageBubbleTextViewTextContainerInsets, messageBubbleTextContainerInsets)) {
        return;
    }
    
    _messageBubbleTextViewTextContainerInsets = messageBubbleTextContainerInsets;
    [self invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
}

- (void)setIncomingAvatarViewSize:(CGSize)incomingAvatarViewSize
{
    if (CGSizeEqualToSize(_incomingAvatarViewSize, incomingAvatarViewSize)) {
        return;
    }
    
    _incomingAvatarViewSize = incomingAvatarViewSize;
    [self invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
}

- (void)setOutgoingAvatarViewSize:(CGSize)outgoingAvatarViewSize
{
    if (CGSizeEqualToSize(_outgoingAvatarViewSize, outgoingAvatarViewSize)) {
        return;
    }
    
    _outgoingAvatarViewSize = outgoingAvatarViewSize;
    [self invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
}


#pragma mark - Getters

- (CGFloat)itemWidth
{
//    NSLog(@"final>>>>> CGRectGetWidth(self.collectionView.frame)=%f,self.sectionInset.left=%f, self.sectionInset.right=%f", CGRectGetWidth(self.collectionView.frame), self.sectionInset.right, self.sectionInset.left);

    return CGRectGetWidth(self.collectionView.frame) - self.sectionInset.left - self.sectionInset.right;
}

- (NSMutableSet *)visibleIndexPaths
{
    if (!_visibleIndexPaths) {
        _visibleIndexPaths = [NSMutableSet new];
    }
    return _visibleIndexPaths;
}

- (id<JSQMessagesBubbleSizeCalculating>)bubbleSizeCalculator
{
    if (_bubbleSizeCalculator == nil) {
        _bubbleSizeCalculator = [JSQMessagesBubblesSizeCalculator new];
    }

    return _bubbleSizeCalculator;
}


#pragma mark - Notifications

- (void)jsq_didReceiveApplicationMemoryWarningNotification:(NSNotification *)notification
{
    [self jsq_resetLayout];
}


#pragma mark - Collection view flow layout

- (void)invalidateLayoutWithContext:(JSQMessagesCollectionViewFlowLayoutInvalidationContext *)context
{
    if (context.invalidateDataSourceCounts) {
        context.invalidateFlowLayoutAttributes = YES;
        context.invalidateFlowLayoutDelegateMetrics = YES;
    }

    if (context.invalidateFlowLayoutMessagesCache) {
        [self jsq_resetLayout];
    }
    [self.jsq_sizeCache removeAllObjects];
    [super invalidateLayoutWithContext:context];
}

- (void)prepareLayout
{
    // 每轮布局开始时清空缓存，避免上一轮数据导致堆叠
    [self.jsq_sizeCache removeAllObjects];
    [self.jsq_attributesFrameCache removeAllObjects];
    [super prepareLayout];
    
    // 按可见范围、从 0 到 maxItem 顺序预填 frame 缓存，避免「同一分组条数很多」时深递归导致 Y 错乱或堆叠
    NSInteger numberOfSections = [self.collectionView numberOfSections];
    if (numberOfSections == 0) return;
    NSInteger count = [self.collectionView numberOfItemsInSection:0];
    if (count == 0) return;
    CGRect visibleRect = CGRectMake(self.collectionView.contentOffset.x, self.collectionView.contentOffset.y,
                                   self.collectionView.bounds.size.width, self.collectionView.bounds.size.height);
    NSArray *attrsInRect = [super layoutAttributesForElementsInRect:visibleRect];
    NSInteger maxItem = -1;
    for (UICollectionViewLayoutAttributes *a in attrsInRect) {
        if (a.representedElementCategory == UICollectionElementCategoryCell && a.indexPath.section == 0) {
            if (a.indexPath.item > maxItem) maxItem = a.indexPath.item;
        }
    }
    if (maxItem < 0) return;
    NSInteger endItem = (maxItem < count) ? maxItem : (count - 1);
    if (!self.jsq_attributesFrameCache) self.jsq_attributesFrameCache = [NSMutableDictionary dictionary];
    CGFloat prevMaxY = -CGFLOAT_MAX;
    NSInteger prevGroupPos = -1;
    for (NSInteger i = 0; i <= endItem; i++) {
        NSIndexPath *path = [NSIndexPath indexPathForItem:i inSection:0];
        JSQMessagesCollectionViewLayoutAttributes *attr = (JSQMessagesCollectionViewLayoutAttributes *)[[super layoutAttributesForItemAtIndexPath:path] copy];
        if (attr.representedElementCategory != UICollectionElementCategoryCell) continue;
        [self jsq_configureMessageCellLayoutAttributes:attr];
        if (i > 0 && attr.messageGroupPosition >= 1 && prevGroupPos != 3) {
            CGFloat newY = prevMaxY + kJSQMessagesGroupInnerLineSpacing;
            attr.frame = CGRectMake(CGRectGetMinX(attr.frame), newY, CGRectGetWidth(attr.frame), CGRectGetHeight(attr.frame));
        }
        prevMaxY = CGRectGetMaxY(attr.frame);
        prevGroupPos = attr.messageGroupPosition;
        NSString *key = [NSString stringWithFormat:@"0_%ld", (long)i];
        [self.jsq_attributesFrameCache setObject:[NSValue valueWithCGRect:attr.frame] forKey:key];
    }
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSArray *attributesInRect = [[super layoutAttributesForElementsInRect:rect] copy];

    for (JSQMessagesCollectionViewLayoutAttributes *attr in attributesInRect) {
        if (attr.representedElementCategory == UICollectionElementCategoryCell) {
            [self jsq_configureMessageCellLayoutAttributes:attr];
            // 根治堆叠：frame 只由此处单源写入。从下往上滑头像消失：messageGroupPosition 也由此单源覆盖，避免 rect/枚举顺序导致 attr 与 canonical 不一致（头像 1/2 隐藏、0/3 显示）
            UICollectionViewLayoutAttributes *canonical = [self layoutAttributesForItemAtIndexPath:attr.indexPath];
            attr.frame = canonical.frame;
            if ([canonical isKindOfClass:[JSQMessagesCollectionViewLayoutAttributes class]]) {
                attr.messageGroupPosition = ((JSQMessagesCollectionViewLayoutAttributes *)canonical).messageGroupPosition;
            }
        } else {
            attr.zIndex = -1;
        }
    }

    return attributesInRect;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *key = [NSString stringWithFormat:@"%ld_%ld", (long)indexPath.section, (long)indexPath.item];
    NSValue *cachedFrame = [self.jsq_attributesFrameCache objectForKey:key];
    
    JSQMessagesCollectionViewLayoutAttributes *customAttributes = (JSQMessagesCollectionViewLayoutAttributes *)[[super layoutAttributesForItemAtIndexPath:indexPath] copy];
    
    if (customAttributes.representedElementCategory != UICollectionElementCategoryCell) {
        return customAttributes;
    }
    
    [self jsq_configureMessageCellLayoutAttributes:customAttributes];
    
    if (cachedFrame != nil) {
        customAttributes.frame = [cachedFrame CGRectValue];
        return customAttributes;
    }
    
    // 同一分组内气泡间隙 2pt（当前为 top/middle/bottom 时与上一条同组）；Y 只在此处计算并缓存，ElementsInRect 只同步此结果
    if (indexPath.item > 0 && customAttributes.messageGroupPosition >= 1) {
        NSIndexPath *prevPath = [NSIndexPath indexPathForItem:indexPath.item - 1 inSection:indexPath.section];
        UICollectionViewLayoutAttributes *prevAttr = [self layoutAttributesForItemAtIndexPath:prevPath];
        NSInteger prevGroupPos = 3;
        if ([prevAttr isKindOfClass:[JSQMessagesCollectionViewLayoutAttributes class]]) {
            prevGroupPos = ((JSQMessagesCollectionViewLayoutAttributes *)prevAttr).messageGroupPosition;
        }
        if (prevGroupPos != 3) {
            CGFloat newY = CGRectGetMaxY(prevAttr.frame) + kJSQMessagesGroupInnerLineSpacing;
            customAttributes.frame = CGRectMake(CGRectGetMinX(customAttributes.frame), newY, CGRectGetWidth(customAttributes.frame), CGRectGetHeight(customAttributes.frame));
        }
    }
    
    if (!self.jsq_attributesFrameCache) self.jsq_attributesFrameCache = [NSMutableDictionary dictionary];
    [self.jsq_attributesFrameCache setObject:[NSValue valueWithCGRect:customAttributes.frame] forKey:key];
    return customAttributes;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    CGRect oldBounds = self.collectionView.bounds;
    if (CGRectGetWidth(newBounds) != CGRectGetWidth(oldBounds)) {
        return YES;
    }
    return NO;
}

- (void)invalidateLayout
{
    [self.jsq_sizeCache removeAllObjects];
    [self.jsq_attributesFrameCache removeAllObjects];
    [super invalidateLayout];
}

- (void)prepareForCollectionViewUpdates:(NSArray *)updateItems
{
    [super prepareForCollectionViewUpdates:updateItems];
    
    [updateItems enumerateObjectsUsingBlock:^(UICollectionViewUpdateItem *updateItem, NSUInteger index, BOOL *stop) {
        if (updateItem.updateAction == UICollectionUpdateActionInsert) {

            CGFloat collectionViewHeight = CGRectGetHeight(self.collectionView.bounds);
            
            JSQMessagesCollectionViewLayoutAttributes *attributes = [JSQMessagesCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:updateItem.indexPathAfterUpdate];
            
            if (attributes.representedElementCategory == UICollectionElementCategoryCell) {
                [self jsq_configureMessageCellLayoutAttributes:attributes];
            }
            
            attributes.frame = CGRectMake(0.0f,
                                          collectionViewHeight + CGRectGetHeight(attributes.frame),
                                          CGRectGetWidth(attributes.frame),
                                          CGRectGetHeight(attributes.frame));
        }
    }];
}


#pragma mark - Invalidation utilities

- (void)jsq_resetLayout
{
    [self.bubbleSizeCalculator prepareForResettingLayout:self];
}


#pragma mark - Message cell layout utilities

- (CGSize)messageBubbleSizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *messageItem = [self.collectionView.dataSource collectionView:self.collectionView
                                                      messageDataForItemAtIndexPath:indexPath];
    // 数据源返回 nil 时（如 index 短暂越界）不交给 calculator，避免返回 CGSizeZero 导致气泡堆叠
    if (messageItem == nil) {
        CGFloat w = MAX(self.itemWidth * 0.3f, 60.0f);
        return CGSizeMake(w, kJSQMessagesMinimumCellHeight);
    }

    return [self.bubbleSizeCalculator messageBubbleSizeForMessageData:messageItem
                                                          atIndexPath:indexPath
                                                           withLayout:self];
}

// 这是整个JSQ中决定整个ConlectionView的Cell大小的唯一方法，要理解cell的大小是如何计算出来的，顺着本方法读代码即可
- (CGSize)sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *key = [NSString stringWithFormat:@"%ld_%ld", (long)indexPath.section, (long)indexPath.item];
    NSValue *cached = [self.jsq_sizeCache objectForKey:key];
    if (cached != nil) {
        return [cached CGSizeValue];
    }

    CGSize messageBubbleSize = [self messageBubbleSizeForItemAtIndexPath:indexPath];
    // 直接向 delegate 取各区域高度，避免调用 layoutAttributesForItemAtIndexPath 造成递归与重复计算（P0-2）
    id<UICollectionViewDelegateFlowLayout> delegate = (id)self.collectionView.delegate;
    CGFloat cellTop = 0, msgBubbleTop = 0, nickname = 0, cellBottom = 0, quoteGap = 0, quoteH = 0;
    if ([delegate respondsToSelector:@selector(collectionView:layout:heightForCellTopLabelAtIndexPath:)]) {
        cellTop = [(id)delegate collectionView:self.collectionView layout:self heightForCellTopLabelAtIndexPath:indexPath];
    }
    if ([delegate respondsToSelector:@selector(collectionView:layout:heightForMessageBubbleTopLabelAtIndexPath:)]) {
        msgBubbleTop = [(id)delegate collectionView:self.collectionView layout:self heightForMessageBubbleTopLabelAtIndexPath:indexPath];
    }
    if ([delegate respondsToSelector:@selector(collectionView:layout:heightForCellNicknameLabelAtIndexPath:)]) {
        nickname = [(id)delegate collectionView:self.collectionView layout:self heightForCellNicknameLabelAtIndexPath:indexPath];
    }
    if ([delegate respondsToSelector:@selector(collectionView:layout:heightForCellBottomLabelAtIndexPath:)]) {
        cellBottom = [(id)delegate collectionView:self.collectionView layout:self heightForCellBottomLabelAtIndexPath:indexPath];
    }
    if ([delegate respondsToSelector:@selector(collectionView:layout:topGapForQuoteContainerAtIndexPath:)]) {
        quoteGap = [(id)delegate collectionView:self.collectionView layout:self topGapForQuoteContainerAtIndexPath:indexPath];
    }
    if ([delegate respondsToSelector:@selector(collectionView:layout:heightForQuoteContainerAtIndexPath:)]) {
        quoteH = [(id)delegate collectionView:self.collectionView layout:self heightForQuoteContainerAtIndexPath:indexPath];
    }

    CGFloat finalHeight = messageBubbleSize.height + cellTop + msgBubbleTop + nickname + cellBottom + quoteGap + quoteH;
    JSQMessage *message = [self.collectionView.dataSource collectionView:self.collectionView messageDataForItemAtIndexPath:indexPath];
    BOOL isSystemInfoMessage = (message.msgType == TM_TYPE_SYSTEAM_INFO || message.msgType == TM_TYPE_REVOKE);
    CGFloat minimumHeight = isSystemInfoMessage ? kRBSystemInfoMinimumCellHeight : kJSQMessagesMinimumCellHeight;
    finalHeight = MAX(finalHeight, minimumHeight);
    CGSize size = CGSizeMake(self.itemWidth, ceilf(finalHeight));
    if (!self.jsq_sizeCache) self.jsq_sizeCache = [NSMutableDictionary dictionary];
    [self.jsq_sizeCache setObject:[NSValue valueWithCGSize:size] forKey:key];
    return size;
}

// 准备整个消息气泡中各ui组件的基本属性（此值将最终在各cell实现类的applyLayoutAttributes:方法中被使用，从而设定cell中各ui组件的最终大小等）
- (void)jsq_configureMessageCellLayoutAttributes:(JSQMessagesCollectionViewLayoutAttributes *)layoutAttributes
{
    NSIndexPath *indexPath = layoutAttributes.indexPath;
    
    CGSize messageBubbleSize = [self messageBubbleSizeForItemAtIndexPath:indexPath];

    // 目前此属性也同时被系统通知共用（以便设置文本显示区的显示宽度）
    layoutAttributes.messageBubbleContainerViewWidth = messageBubbleSize.width;
    layoutAttributes.textViewFrameInsets = self.messageBubbleTextViewFrameInsets;
    UIEdgeInsets textContainerInsets = self.messageBubbleTextViewTextContainerInsets;
    JSQMessage *message = [self.collectionView.dataSource collectionView:self.collectionView messageDataForItemAtIndexPath:indexPath];
    // 先取昵称行高，用于区分带昵称(紧凑)与单聊无昵称(稍大 insets)
    CGFloat cellNicknameLabelHeight = [self.collectionView.delegate collectionView:self.collectionView layout:self heightForCellNicknameLabelAtIndexPath:indexPath];
    // 群聊/收藏夹：若昵称比气泡宽，则加长气泡以完整显示昵称（与气泡内昵称字体 14pt Semibold 一致）
    id dataSource = self.collectionView.dataSource;
    NSString *toId = [dataSource valueForKey:@"toId"];
    NSNumber *chatTypeNum = [dataSource valueForKey:@"chatType"];
    if (message && [dataSource respondsToSelector:@selector(senderId)] && toId != nil && chatTypeNum != nil
        && ![message.senderId isEqualToString:[dataSource senderId]]) {
        NSInteger chatType = [chatTypeNum integerValue];
        BOOL showNickname = NO;
        if ([dataSource conformsToProtocol:@protocol(JSQMessagesChatDataSourceShowNicknameOptional)] &&
            [dataSource respondsToSelector:@selector(rb_showGroupMemberNicknameForCurrentChat)]) {
            id<JSQMessagesChatDataSourceShowNicknameOptional> opt = (id)dataSource;
            showNickname = (chatType == CHAT_TYPE_GROUP_CHAT && [opt rb_showGroupMemberNicknameForCurrentChat])
                || (chatType == CHAT_TYPE_FREIDN_CHAT && [toId isEqualToString:@"10001"]);
        } else {
            showNickname = (chatType == CHAT_TYPE_GROUP_CHAT && [UserDefaultsToolKits getShowGroupMemberNickname:toId])
                || (chatType == CHAT_TYPE_FREIDN_CHAT && [toId isEqualToString:@"10001"]);
        }
        // 须与 heightForCellNicknameLabelAtIndexPath 一致：无昵称行高时不应加宽气泡（收藏夹图片/视频等有 senderDisplayName 但不展示昵称）
        if (showNickname && [message.senderDisplayName length] > 0 && cellNicknameLabelHeight > 1.0e-3f) {
            UIFont *nicknameFont = [UIFont systemFontOfSize:14.0f weight:UIFontWeightSemibold];
            CGFloat nicknameW = [message.senderDisplayName boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, 20.0f)
                                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                                    attributes:@{ NSFontAttributeName : nicknameFont }
                                                                       context:nil].size.width;
            CGFloat nicknamePadding = 12.0f + 12.0f;
            CGFloat minWidthForNickname = ceilf(nicknameW) + nicknamePadding;
            if (layoutAttributes.messageBubbleContainerViewWidth < minWidthForNickname) {
                CGFloat maxBubbleW = self.itemWidth - 2.0f * self.messageBubbleLeftRightMargin - self.incomingAvatarViewSize.width - 8.0f;
                CGFloat candidateW = MAX(layoutAttributes.messageBubbleContainerViewWidth, minWidthForNickname);
                layoutAttributes.messageBubbleContainerViewWidth = MIN(candidateW, maxBubbleW);
            }
        }
    }
    if (message.msgType == TM_TYPE_VOIP_RECORD && message.text.length > 0) {
        NSString *s = [NSString stringWithFormat:@" %@", message.text];
        CGFloat textW = [s boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, 28.0f)
                                        options:NSStringDrawingUsesLineFragmentOrigin
                                     attributes:@{ NSFontAttributeName : self.messageBubbleFont }
                                        context:nil].size.width;
        CGFloat iconW = 24.0f;
        CGFloat contentW = ceilf(textW) + iconW + 8.0f;
        CGFloat bubbleW = contentW
            + self.messageBubbleTextViewFrameInsets.left + self.messageBubbleTextViewFrameInsets.right
            + 14.0f + 14.0f;
        CGFloat avatarW = 0.0f;
        if ([dataSource respondsToSelector:@selector(senderId)] && [message.senderId isEqualToString:[dataSource senderId]]) {
            avatarW = self.outgoingAvatarViewSize.width;
        } else {
            avatarW = self.incomingAvatarViewSize.width;
        }
        CGFloat maxBubbleW = self.itemWidth - 2.0f * self.messageBubbleLeftRightMargin - avatarW - 8.0f;
        CGFloat candidateW = MAX(layoutAttributes.messageBubbleContainerViewWidth, bubbleW);
        layoutAttributes.messageBubbleContainerViewWidth = MIN(candidateW, maxBubbleW);
    }
    if (message.msgType == TM_TYPE_VOIP_RECORD) {
        // 音视频通话记录气泡高度 38pt：正文需同时容纳字体与左侧图标（24pt），并在气泡内垂直居中
        CGFloat lineH = self.messageBubbleFont.lineHeight;
        CGFloat contentH = MAX(lineH, 24.0f);
        CGFloat half = (38.0f - contentH) / 2.0f;
        CGFloat topV = floorf(half);
        CGFloat bottomV = ceilf(half);
        textContainerInsets = UIEdgeInsetsMake(MAX(2.0f, topV), 14.0f, MAX(2.0f, bottomV), 14.0f);
    } else if ([self.bubbleSizeCalculator respondsToSelector:@selector(isMultiLineForMessage:atIndexPath:withLayout:)]) {
        BOOL multiLine = [(id)self.bubbleSizeCalculator isMultiLineForMessage:message atIndexPath:indexPath withLayout:self];
        BOOL timeFitsOnSameLine = NO;
        if ([self.bubbleSizeCalculator isKindOfClass:[JSQMessagesBubblesSizeCalculator class]]) {
            timeFitsOnSameLine = [(JSQMessagesBubblesSizeCalculator *)self.bubbleSizeCalculator lastTimeFitsOnSameLine];
        }
        layoutAttributes.messageBubbleTimeFitsOnSameLine = timeFitsOnSameLine;
        CGFloat topPt = textContainerInsets.top;
        CGFloat bottomPt;
        if (cellNicknameLabelHeight > 0) {
            // 带昵称：紧凑
            bottomPt = multiLine ? (timeFitsOnSameLine ? 2.0f : 20.0f) : 2.0f;
        } else {
            // 单聊无昵称：上下稍大，与 BubblesSizeCalculator 一致
            topPt = 6.0f;
            bottomPt = multiLine ? (timeFitsOnSameLine ? 2.0f : 22.0f) : 6.0f;
        }
        if (multiLine) {
            // 右侧不再整段加大 inset（会与时间不同行时出现大片空白）；右下角避让改由 Cell 内 exclusionPaths 实现
            textContainerInsets = UIEdgeInsetsMake(topPt, 14.0f, bottomPt, 14.0f);
        } else {
            textContainerInsets = UIEdgeInsetsMake(topPt, 14.0f, bottomPt, textContainerInsets.right);
            if (self.messageBubbleTimeAreaRightInset > 0) textContainerInsets.right = self.messageBubbleTimeAreaRightInset;
        }
    } else if (self.messageBubbleTimeAreaRightInset > 0) {
        textContainerInsets.right = self.messageBubbleTimeAreaRightInset;
    }
    layoutAttributes.messageBubbleFont = self.messageBubbleFont;
    // 群聊分组：仅分组最后一条显示头像（0=single 3=bottom 显示；1=top 2=middle 隐藏）
    layoutAttributes.messageGroupPosition = 0;
    layoutAttributes.messageBubbleHorizontalOffset = 0.0f;
    if (chatTypeNum != nil && [chatTypeNum integerValue] == CHAT_TYPE_GROUP_CHAT
        && [self.collectionView.delegate respondsToSelector:@selector(collectionView:layout:messageGroupPositionAtIndexPath:)]) {
        layoutAttributes.messageGroupPosition = [(id)self.collectionView.delegate collectionView:self.collectionView layout:self messageGroupPositionAtIndexPath:indexPath];
        if (layoutAttributes.messageGroupPosition == 1 || layoutAttributes.messageGroupPosition == 2) {
            layoutAttributes.messageBubbleHorizontalOffset = 2.0f;
        }
    }
    layoutAttributes.incomingAvatarViewSize = self.incomingAvatarViewSize;
    layoutAttributes.outgoingAvatarViewSize = self.outgoingAvatarViewSize;
    layoutAttributes.textViewTextContainerInsets = textContainerInsets;
    // 目前此属性也同时被系统通知共用（以便设置日期时间组件的显示宽度）
    layoutAttributes.cellTopLabelHeight = [self.collectionView.delegate collectionView:self.collectionView
                                                                                layout:self
                                                      heightForCellTopLabelAtIndexPath:indexPath];
    layoutAttributes.cellNicknameLabelHeight = cellNicknameLabelHeight;
    layoutAttributes.messageBubbleTopLabelHeight = [self.collectionView.delegate collectionView:self.collectionView
                                                                                         layout:self
                                                      heightForMessageBubbleTopLabelAtIndexPath:indexPath];
    layoutAttributes.cellBottomLabelHeight = [self.collectionView.delegate collectionView:self.collectionView
                                                                                   layout:self
                                                      heightForCellBottomLabelAtIndexPath:indexPath];
    
    layoutAttributes.quoteContainerTopGap = [self.collectionView.delegate collectionView:self.collectionView
                                                                                  layout:self
                                                      topGapForQuoteContainerAtIndexPath:indexPath];
    layoutAttributes.quoteContainerHeight = [self.collectionView.delegate collectionView:self.collectionView
                                                                                  layout:self
                                                      heightForQuoteContainerAtIndexPath:indexPath];
    layoutAttributes.quoteIconContainerWidth = [self.collectionView.delegate collectionView:self.collectionView
                                                                                     layout:self
                                                      widthForQuoteIconContainerAtIndexPath:indexPath];
}

@end
