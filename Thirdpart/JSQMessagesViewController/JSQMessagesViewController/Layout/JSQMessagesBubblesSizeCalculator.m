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


#import "JSQMessagesBubblesSizeCalculator.h"

#import "JSQMessagesCollectionView.h"
#import "JSQMessagesCollectionViewDataSource.h"
#import "JSQMessagesCollectionViewFlowLayout.h"
//#import "JSQMessage.h"

#import "UIImage+JSQMessages.h"
#import "rbSystemInfoCollectionViewCell.h"
#import "MsgBodyRoot.h"
#import "IMClientManager.h"

// 仅通过 content 判断是否为红包 JSON（与 ChatRootViewController 的 rb_isRedPacketContent 逻辑一致，便于 msg_type 错误时仍按红包尺寸布局）
static BOOL jsq_isRedPacketContent(NSString *text) {
    if (!text || text.length == 0 || ![text hasPrefix:@"{"]) return NO;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return NO;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![obj isKindOfClass:[NSDictionary class]]) return NO;
    id pid = [(NSDictionary *)obj objectForKey:@"packet_id"];
    if (pid == nil || [pid isKindOfClass:[NSNull class]]) return NO;
    NSString *s = [pid isKindOfClass:[NSString class]] ? (NSString *)pid : [pid description];
    return (s.length > 0 && ![s isEqualToString:@"<null>"] && ![s isEqualToString:@"(null)"]);
}

// 仅通过 content 判断是否为转账 JSON（如 {"amount":"11.00","to_uid":"400204","remark":""}）
static BOOL jsq_isTransferContent(NSString *text) {
    if (!text || text.length == 0 || ![text hasPrefix:@"{"]) return NO;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return NO;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![obj isKindOfClass:[NSDictionary class]]) return NO;
    id amt = [(NSDictionary *)obj objectForKey:@"amount"];
    return (amt != nil && ![amt isKindOfClass:[NSNull class]]);
}

/// 与 ChatRootViewController 普通文本气泡一致（NSLineBreakByCharWrapping）。仅用 NSFont 做 boundingRect 时
/// 系统默认按词换行，在窄气泡（对方+左侧头像）下会比 UITextView 少算行数，表现为对方消息底部被裁切而我方完整。
static CGFloat jsq_rbChatBubbleTargetLineHeight(UIFont *font)
{
    if (!font) return 0;
    CGFloat lh = MAX(font.lineHeight, font.pointSize * 1.25f);
    return ceilf(MAX(lh, 0));
}

static NSParagraphStyle *jsq_rbChatBubbleParagraphStyle(UIFont *font)
{
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 16;
    });
    CGFloat targetLH = jsq_rbChatBubbleTargetLineHeight(font);
    NSString *key = [NSString stringWithFormat:@"%.1f_%.0f", font.pointSize, targetLH];
    NSParagraphStyle *cached = [cache objectForKey:key];
    if (cached) return cached;
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.lineBreakMode = NSLineBreakByCharWrapping;
    ps.minimumLineHeight = targetLH;
    ps.maximumLineHeight = targetLH;
    NSParagraphStyle *style = [ps copy];
    [cache setObject:style forKey:key];
    return style;
}

static NSDictionary *jsq_rbChatBubbleBoundingAttrs(UIFont *font)
{
    return @{ NSFontAttributeName: font, NSParagraphStyleAttributeName: jsq_rbChatBubbleParagraphStyle(font) };
}

// 用 TextKit 计算最后一行的「已用宽度」，用于判断右侧是否放得下时间/已读
static CGFloat jsq_lastLineUsedWidth(NSString *text, UIFont *font, CGFloat maxWidth) {
    if (!text || text.length == 0 || maxWidth <= 0) return 0;
    NSTextStorage *storage = [[NSTextStorage alloc] initWithString:text];
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    NSTextContainer *tc = [[NSTextContainer alloc] initWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)];
    tc.lineFragmentPadding = 0;
    [lm addTextContainer:tc];
    [storage addLayoutManager:lm];
    NSRange full = NSMakeRange(0, storage.length);
    [storage addAttribute:NSFontAttributeName value:font range:full];
    [storage addAttribute:NSParagraphStyleAttributeName value:jsq_rbChatBubbleParagraphStyle(font) range:full];
    (void)[lm glyphRangeForTextContainer:tc];
    NSRange fullRange = [lm glyphRangeForTextContainer:tc];
    if (fullRange.length == 0) return 0;
    NSUInteger lastGlyphIndex = fullRange.location + fullRange.length - 1;
    CGRect lastLineRect = [lm lineFragmentUsedRectForGlyphAtIndex:lastGlyphIndex effectiveRange:NULL];
    return lastLineRect.size.width;
}

/// 用 TextKit 取排版高度，贴近气泡内 UITextView（boundingRect 在中文+长 URL、窄宽、字间距下偶发比真实少 1～数行，对方气泡更易裁尾）
static CGFloat jsq_rbTextKitUsedHeightForWidth(NSString *text, CGFloat maxWidth, UIFont *font)
{
    if (text.length == 0 || maxWidth <= 0 || font == nil) {
        return 0;
    }
    NSTextStorage *storage = [[NSTextStorage alloc] initWithString:text attributes:jsq_rbChatBubbleBoundingAttrs(font)];
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    NSTextContainer *tc = [[NSTextContainer alloc] initWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)];
    tc.lineFragmentPadding = 0;
    [lm addTextContainer:tc];
    [storage addLayoutManager:lm];
    (void)[lm glyphRangeForTextContainer:tc];
    CGRect used = [lm usedRectForTextContainer:tc];
    return ceilf(MAX(used.size.height, 0));
}

@interface JSQMessagesBubblesSizeCalculator ()

@property (strong, nonatomic, readonly) NSCache *cache;
/** 缓存 isMultiLine 结果，避免布局时与 size 计算重复做 emoji+boundingRect */
@property (strong, nonatomic, readonly) NSCache *multiLineCache;

@property (assign, nonatomic, readonly) NSUInteger minimumBubbleWidth;

@property (assign, nonatomic, readonly) BOOL usesFixedWidthBubbles;

@property (assign, nonatomic, readonly) NSInteger additionalInset;

@property (assign, nonatomic) CGFloat layoutWidthForFixedWidthBubbles;

/** 最近一次 messageBubbleSizeForMessageData 计算出的「多行时时间/已读是否与最后一行同行」，供 FlowLayout 传给 cell */
@property (nonatomic, assign) BOOL lastTimeFitsOnSameLine;
/** 按 messageHash 缓存 timeFitsOnSameLine，尺寸走缓存时也需恢复该值，否则时间/已读不会下移 */
@property (strong, nonatomic, readonly) NSCache *timeFitsOnSameLineCache;

@end


@implementation JSQMessagesBubblesSizeCalculator

#pragma mark - Init

- (instancetype)initWithCache:(NSCache *)cache
           minimumBubbleWidth:(NSUInteger)minimumBubbleWidth
        usesFixedWidthBubbles:(BOOL)usesFixedWidthBubbles
{
    NSParameterAssert(cache != nil);
    NSParameterAssert(minimumBubbleWidth > 0);

    self = [super init];
    if (self) {
        _cache = cache;
        _minimumBubbleWidth = minimumBubbleWidth;
        _usesFixedWidthBubbles = usesFixedWidthBubbles;
        _layoutWidthForFixedWidthBubbles = 0.0f;
        _multiLineCache = [NSCache new];
        _multiLineCache.name = @"JSQMessagesBubblesSizeCalculator.multiLineCache";
        _multiLineCache.countLimit = 200;
        _timeFitsOnSameLineCache = [NSCache new];
        _timeFitsOnSameLineCache.name = @"JSQMessagesBubblesSizeCalculator.timeFitsOnSameLineCache";
        _timeFitsOnSameLineCache.countLimit = 200;

        // this extra inset value is needed because `boundingRectWithSize:` is slightly off
        // see comment below
        _additionalInset = 2;
    }
    return self;
}

- (instancetype)init
{
    NSCache *cache = [NSCache new];
    cache.name = @"JSQMessagesBubblesSizeCalculator.cache";
    cache.countLimit = 200;
    return [self initWithCache:cache
            minimumBubbleWidth:[UIImage jsq_bubbleCompactImage].size.width
         usesFixedWidthBubbles:NO];
}

#pragma mark - NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: cache=%@, minimumBubbleWidth=%@ usesFixedWidthBubbles=%@>",
            [self class], self.cache, @(self.minimumBubbleWidth), @(self.usesFixedWidthBubbles)];
}

#pragma mark - JSQMessagesBubbleSizeCalculating

- (void)prepareForResettingLayout:(JSQMessagesCollectionViewFlowLayout *)layout
{
    [self.cache removeAllObjects];
    [self.multiLineCache removeAllObjects];
    [self.timeFitsOnSameLineCache removeAllObjects];
    _layoutWidthForFixedWidthBubbles = 0.0f;
}

// 聊天消息或系统通知的核心部分：即气泡+文本文本区的大小就是通过本方法计算出来的，这是唯一的决定此区大小的代码
- (CGSize)messageBubbleSizeForMessageData:(JSQMessage *)messageData
                              atIndexPath:(NSIndexPath *)indexPath
                               withLayout:(JSQMessagesCollectionViewFlowLayout *)layout
{
    // ★ 媒体消息始终重新计算尺寸，不使用缓存。
    //   原因：图片等媒体异步下载，首次布局时 image 为 nil 会返回默认尺寸(180×150)，
    //   如果缓存了这个默认尺寸，即使图片后来下载完成也不会更新气泡大小。
    //   mediaViewDisplaySize 仅做简单算术运算，性能开销可忽略。
    if ([messageData isMediaMessage]) {
        CGSize finalSize = [[messageData media] mediaViewDisplaySize];
        return finalSize;
    }

    CGFloat layoutWidth = [self textBubbleWidthForLayout:layout];
    // 单聊无昵称与群聊/收藏夹带昵称使用不同上下边距，缓存需区分
    CGFloat nicknameHeight = 0;
    if ([layout.collectionView.delegate respondsToSelector:@selector(collectionView:layout:heightForCellNicknameLabelAtIndexPath:)]) {
        nicknameHeight = [(id)layout.collectionView.delegate collectionView:layout.collectionView layout:layout heightForCellNicknameLabelAtIndexPath:indexPath];
    }
    BOOL hasNickname = (nicknameHeight > 0);
    NSString *cacheKey = [NSString stringWithFormat:@"%llu_%d_%d", (unsigned long long)[messageData messageHash], (int)(layoutWidth * 100), hasNickname ? 1 : 0];
    // 多行标记仅与「消息 + 列表可用宽度」有关，须与 isMultiLineForMessage:atIndexPath: 共用此键，避免与 messageHash 单键混用导致对方窄气泡 textInset 错配而裁字
    NSString *multiLineLayoutCacheKey = [NSString stringWithFormat:@"%llu_%d", (unsigned long long)[messageData messageHash], (int)(layoutWidth * 100)];
    NSValue *cachedSize = [self.cache objectForKey:cacheKey];
    NSNumber *cachedFits = [self.timeFitsOnSameLineCache objectForKey:cacheKey];
    if (cachedSize != nil && cachedFits != nil) {
        self.lastTimeFitsOnSameLine = [cachedFits boolValue];
        return [cachedSize CGSizeValue];
    }

    CGSize finalSize = CGSizeZero;

    // 系统通知、被撤回的消息
    if(messageData.msgType == TM_TYPE_SYSTEAM_INFO || messageData.msgType == TM_TYPE_REVOKE)
    {
        // 文本区的左右空白
        CGFloat horizontalContainerInsets = rbSystemInfoCollectionViewCell_textView_textContainerInset_LEFT + rbSystemInfoCollectionViewCell_textView_textContainerInset_RIGHT;
//        CGFloat horizontalFrameInsets = layout.messageBubbleTextViewFrameInsets.left + layout.messageBubbleTextViewFrameInsets.right;

        // 水平总空白
        CGFloat horizontalInsetsTotal = horizontalContainerInsets;// + horizontalFrameInsets;
        // 计算出的文本可显示内容区的最大宽度（[self textBubbleWidthForLayout:layout]是在FLowLayout里整个CollectionView宽减去layput中设置的表格衬距宽后的结果）
        CGFloat maximumTextWidth = [self textBubbleWidthForLayout:layout] - horizontalInsetsTotal;
        
        NSString *showText = @"";
        // 被撤回消息的内容显示需要特殊处理
        if(messageData.msgType == TM_TYPE_REVOKE){
            showText = [JSQMessage getMessageContentPreviewForRevoked:[RevokedMeta fromJSON:[messageData text]]];
        }
        else
            showText = [messageData text];

        // 计算文字占的UI空间：
        // 参数1: 自适应尺寸,提供一个宽度,去自适应高度
        // 参数2: 自适应设置 (以行为矩形区域自适应,以字体字形自适应)
        // 参数3: 文字属性,通常这里面需要知道是字体大小
        // 参数4: 绘制文本上下文,做底层排版时使用,填nil即可
        CGRect stringRect = [showText boundingRectWithSize:CGSizeMake(maximumTextWidth, CGFLOAT_MAX)
                                                             options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                                          attributes:@{ NSFontAttributeName : [rbSystemInfoCollectionViewCell getRbSystemInfoCollectionViewCell_textViewFont]}
                                                             context:nil];

        // 此值计算出来的是字符串的净高+上每一行的行前和行后衬距后的结果，但不包含 UITextView的textContainerInset的top和bottom值哦，这点一定要注意！
        CGSize stringSize = CGRectIntegral(stringRect).size;

        // 文本区的上下空白（整个段前和段后，不是行哦）
        CGFloat verticalContainerInsets = rbSystemInfoCollectionViewCell_textView_textContainerInset_TOP + rbSystemInfoCollectionViewCell_textView_textContainerInset_BOTTOM;
        CGFloat verticalFrameInsets = 0;//layout.messageBubbleTextViewFrameInsets.top + layout.messageBubbleTextViewFrameInsets.bottom;

        // 文本区的总上下空白
        CGFloat verticalInsets = verticalContainerInsets + verticalFrameInsets;// + self.additionalInset;

        // 最终文本宽度(“1”只是个随手填的数，目的是让此width按照字串的真实宽度来决定哦)
        CGFloat finalWidth = MAX(stringSize.width + horizontalInsetsTotal, 1);//self.minimumBubbleWidth);// + self.additionalInset;

        // 注意：最终的整个气泡（含文本区）的高度是字串净高+文本区的上下空白总值哦，不要忘记加上此空白！
        finalSize = CGSizeMake(finalWidth, stringSize.height + verticalInsets);

    }
    // 红包消息：固定卡片尺寸（略增大，容纳底部时间与更宽松排版），与文本气泡分开计算（含按 content 兜底）
    else if (messageData.msgType == TM_TYPE_RED_PACKET || jsq_isRedPacketContent([messageData text]))
    {
        CGFloat redPacketWidth = 270.0f;
        CGFloat redPacketHeight = 90.0f;
        return CGSizeMake(redPacketWidth, redPacketHeight);
    }
    // 转账消息：固定卡片尺寸（与红包一致略增大）（含按 content 兜底）
    else if (messageData.msgType == TM_TYPE_TRANSFER || jsq_isTransferContent([messageData text]))
    {
        CGFloat transferWidth = 270.0f;
        CGFloat transferHeight = 90.0f;
        return CGSizeMake(transferWidth, transferHeight);
    }
    // 普通聊天消息等
    else
    {
        CGSize avatarSize = [self jsq_avatarSizeForMessageData:messageData withLayout:layout];

        //  from the cell xibs, there is a 2 point space between avatar and bubble
        CGFloat spacingBetweenAvatarAndBubble = 2.0f;
        static const CGFloat kTimeReadRightInset = 56.0f;
        // 与 FlowLayout jsq_configureMessageCellLayoutAttributes 一致：单行/多行同行 上下 2pt，多行换行底 20pt（由下方 topInset/bottomInset 统一用 layout 与常量）
        static const CGFloat kTimeReadBottomSameLine = 2.0f;
        static const CGFloat kTimeReadBottomSingleLine = 2.0f; // 单行上下 2pt，与 cell 显示一致以减小气泡高度
        static const CGFloat kTimeReadBottomMulti = 20.0f;     // 多行换行时底 20pt
        static const CGFloat kTextBubbleMinimumWidth = 56.0f;
        CGFloat minimumBubbleWidth = MAX(self.minimumBubbleWidth, kTextBubbleMinimumWidth);
        CGFloat leftInset = layout.messageBubbleTextViewTextContainerInsets.left;
        CGFloat rightInset = (messageData.msgType == TM_TYPE_VOIP_RECORD) ? 14.0f : (layout.messageBubbleTimeAreaRightInset > 0 ? layout.messageBubbleTimeAreaRightInset : layout.messageBubbleTextViewTextContainerInsets.right);
        CGFloat horizontalContainerInsets = leftInset + rightInset;
        CGFloat horizontalFrameInsets = layout.messageBubbleTextViewFrameInsets.left + layout.messageBubbleTextViewFrameInsets.right;

        CGFloat horizontalInsetsTotal = horizontalContainerInsets + horizontalFrameInsets + spacingBetweenAvatarAndBubble;
        CGFloat maximumTextWidth = [self textBubbleWidthForLayout:layout] - avatarSize.width - layout.messageBubbleLeftRightMargin - horizontalInsetsTotal;
        
        /// TODO: 消息中含有表情，同时文本长度超过一行最大数从而产生换行，无法正确计算消息气泡高度
        // Freeman添加：消息体中可能含有表情标记符，如：你好啊[/呲牙]  处理思路：先将表情符清除，计算纯文本宽度，再加上所有表情图片宽度之和
        /// FFF TODO: 以下计算方法在7plus iOS13.3中出现计算出的长度少了一个字的长度，待查找原因
        // 该BUG已修复：原因为自动换行问题导致，修复环节在业务层ChatRootViewController->cellForItemAtIndexPath
        NSString *msgAllStr = [messageData text]; //完整的消息内容
        NSMutableString *msgTxt = [NSMutableString stringWithString:msgAllStr];// 替换表情符后的消息文字部分
//      NSDictionary *attributes = @{ NSFontAttributeName : layout.messageBubbleFont };
//      UIFont *font = attributes[NSFontAttributeName];
        NSError *error = nil;
        NSRegularExpression *regExp = [[NSRegularExpression alloc] initWithPattern:@"\\[/\\w+\\]" options:NSRegularExpressionCaseInsensitive error:&error];
        if (!error && msgTxt != nil && msgTxt.length != 0) {
            NSArray *resultArr = [regExp matchesInString:msgTxt options:0 range:NSMakeRange(0, msgTxt.length)];
            NSMutableArray *emojiStrArray = [[NSMutableArray alloc]init];
            for (NSTextCheckingResult *result in resultArr) {
                ///> 要替换的字符串
                NSString *emojiStr = [msgTxt substringWithRange:result.range];
                //                NSLog(@"--------emojStr=%@",emojiStr);
                ///> 判断表情包里边是否包含该表情
                FaceMeta *emoji = [[[IMClientManager sharedInstance]getFaceDataProvider] getFaceWithDesc:emojiStr];
                if (emoji) {    ///> 如果表情包里边有该表情:1. msgTxt替换表情符字符串为任意2个字符； 2. 计入表情总宽度
//                  [msgTxt replaceCharactersInRange:result.range withString:@""];//不可使用此方法，因为首次替换后，原字符串及真正的range已经变了
//                  [msgTxt stringByReplacingOccurrencesOfString:emojStr withString:@""];
                    [emojiStrArray addObject:emojiStr];
//                  NSLog(@"------检测到含有表情符--emojStr=%@",emojiStr);
                }
            }
            for(NSString *emojiStr in emojiStrArray){
                // 用"12"来代替emoji表情计算出的长度偏小,用"2B"替代后计算出的长度偏大
                [msgTxt replaceOccurrencesOfString:emojiStr withString:@"2b" options:NSCaseInsensitiveSearch  range:NSMakeRange(0, msgTxt.length)];
            }
        }
//      NSLog(@"--------msgAllStr=%@,msgTxt=%@,emojisWidth=%f",msgAllStr,msgTxt,emojisWidth);
        /////////////////////////////////-表情符处理-e-////////////////////////////////

        // 气泡上不再预留时间和消息回执的空间，按正文宽度计算气泡

        // 计算文字占的UI空间：
        // 参数1: 自适应尺寸,提供一个宽度,去自适应高度
        // 参数2: 自适应设置 (以行为矩形区域自适应,以字体字形自适应)
        // 参数3: 文字属性,通常这里面需要知道是字体大小
        // 参数4: 绘制文本上下文,做底层排版时使用,填nil即可
//      CGRect stringRect = [[messageData text] boundingRectWithSize:CGSizeMake(maximumTextWidth, CGFLOAT_MAX)
//                                                             options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
//                                                          attributes:@{ NSFontAttributeName : layout.messageBubbleFont }
//                                                             context:nil];
        CGRect stringRect = [msgTxt boundingRectWithSize:CGSizeMake(maximumTextWidth, CGFLOAT_MAX)
                                                                     options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                                                  attributes:jsq_rbChatBubbleBoundingAttrs(layout.messageBubbleFont)
                                                                     context:nil];

        CGSize stringSize = CGRectIntegral(stringRect).size;
        CGFloat lineHeight = layout.messageBubbleFont.lineHeight;
        BOOL isMultiLine = (stringSize.height > lineHeight * 1.5);

        // 多行：时间+已读换行到底部，右侧与左一致；若最后一行右侧空间够则时间/已读显示在右侧，否则换行。单行：时间在行尾，与多行同行一致用 2pt 底
        BOOL timeFitsOnSameLine = NO;
        CGFloat timeAreaMinWidth = (layout.messageBubbleTimeAreaRightInset > 0 ? MAX(layout.messageBubbleTimeAreaRightInset, kTimeReadRightInset) : 0.0f);
        CGFloat lastLineWForBubble = 0.0f;
        if (isMultiLine) {
            rightInset = layout.messageBubbleTextViewTextContainerInsets.right;
            horizontalContainerInsets = leftInset + rightInset;
            horizontalInsetsTotal = horizontalContainerInsets + horizontalFrameInsets + spacingBetweenAvatarAndBubble;
            maximumTextWidth = [self textBubbleWidthForLayout:layout] - avatarSize.width - layout.messageBubbleLeftRightMargin - horizontalInsetsTotal;
            stringRect = [msgTxt boundingRectWithSize:CGSizeMake(maximumTextWidth, CGFLOAT_MAX)
                                             options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                          attributes:jsq_rbChatBubbleBoundingAttrs(layout.messageBubbleFont)
                                             context:nil];
            stringSize = CGRectIntegral(stringRect).size;
            if (timeAreaMinWidth > 0.0f) {
                lastLineWForBubble = jsq_lastLineUsedWidth(msgTxt, layout.messageBubbleFont, maximumTextWidth);
                timeFitsOnSameLine = (maximumTextWidth - lastLineWForBubble >= timeAreaMinWidth);
            } else {
                timeFitsOnSameLine = YES;
            }
            self.lastTimeFitsOnSameLine = timeFitsOnSameLine;
        } else {
            // 单行：时间在行尾同行显示，与多行「同行」一致，避免单行时间位置偏下
            self.lastTimeFitsOnSameLine = YES;
        }

        CGFloat bottomInset = isMultiLine ? (timeFitsOnSameLine ? kTimeReadBottomSameLine : kTimeReadBottomMulti) : kTimeReadBottomSingleLine;
        CGFloat topInset;
        if (hasNickname) {
            // 带昵称：紧凑，与 FlowLayout 一致
            topInset = layout.messageBubbleTextViewTextContainerInsets.top;
        } else {
            // 单聊无昵称：上下稍大，避免气泡过扁
            static const CGFloat kSingleChatTopInset = 6.0f;
            static const CGFloat kSingleChatBottomSingleLine = 6.0f;
            static const CGFloat kSingleChatBottomMulti = 22.0f;
            topInset = kSingleChatTopInset;
            if (!isMultiLine) bottomInset = kSingleChatBottomSingleLine;
            else if (!timeFitsOnSameLine) bottomInset = kSingleChatBottomMulti;
        }
        CGFloat verticalContainerInsets = topInset + bottomInset;
        CGFloat verticalFrameInsets = layout.messageBubbleTextViewFrameInsets.top + layout.messageBubbleTextViewFrameInsets.bottom;
        CGFloat verticalInsets = verticalContainerInsets + verticalFrameInsets + self.additionalInset;

        CGFloat finalWidth;
        if (isMultiLine) {
            CGFloat widestLine = ceilf(stringSize.width);
            CGFloat innerTextNeeded;
            if (timeFitsOnSameLine) {
                innerTextNeeded = MAX(widestLine, ceilf(lastLineWForBubble) + timeAreaMinWidth);
            } else {
                innerTextNeeded = widestLine;
            }
            innerTextNeeded = MIN(innerTextNeeded, maximumTextWidth);
            CGFloat candidate = innerTextNeeded + horizontalInsetsTotal;
            finalWidth = MAX(candidate, minimumBubbleWidth) + self.additionalInset;
        } else {
            finalWidth = MAX(stringSize.width + horizontalInsetsTotal, minimumBubbleWidth) + self.additionalInset;
        }

        // ★ VoIP 通话记录消息：气泡中渲染时会在文字前插入 SF Symbol 图标（18pt）+ 空格（~4pt），
        //   纯文字测量宽度不包含图标占位，需额外补偿，避免文字被气泡右边界截断
        if (messageData.msgType == TM_TYPE_VOIP_RECORD) {
            finalWidth += 24.0f; // 18pt icon + 4pt space + 2pt margin
        }

        // 音视频通话记录气泡高度与语音气泡一致（38pt，见 JSQAudioMediaItem kAudioBubbleHeightSameAsText）
        static const CGFloat kVoipRecordBubbleHeight = 38.0f;
        CGFloat bodyH = CGRectIntegral(stringRect).size.height;
        CGFloat tkH = jsq_rbTextKitUsedHeightForWidth(msgTxt, maximumTextWidth, layout.messageBubbleFont);
        bodyH = MAX(bodyH, tkH);
        // 多行且时间/已读与末行同行时，cell 内会对 textView 设 exclusionPaths，实际折行可能多于纯宽矩形测量；略加余量避免底部裁字
        if (isMultiLine && timeFitsOnSameLine) {
            bodyH += ceilf(lineHeight * 0.5f);
        }
        CGFloat bubbleHeight = (messageData.msgType == TM_TYPE_VOIP_RECORD) ? kVoipRecordBubbleHeight : (bodyH + verticalInsets);
        finalSize = CGSizeMake(finalWidth, bubbleHeight);
        [self.multiLineCache setObject:@(isMultiLine) forKey:multiLineLayoutCacheKey];
        [self.timeFitsOnSameLineCache setObject:@(self.lastTimeFitsOnSameLine) forKey:cacheKey];
    }
    
    [self.cache setObject:[NSValue valueWithCGSize:finalSize] forKey:cacheKey];

    return finalSize;
}

- (CGSize)jsq_avatarSizeForMessageData:(JSQMessage *)messageData
                            withLayout:(JSQMessagesCollectionViewFlowLayout *)layout
{
    NSString *messageSender = [messageData senderId];

    if ([messageSender isEqualToString:[layout.collectionView.dataSource senderId]]) {
        return layout.outgoingAvatarViewSize;
    }

    return layout.incomingAvatarViewSize;
}

- (CGFloat)textBubbleWidthForLayout:(JSQMessagesCollectionViewFlowLayout *)layout
{
    if (self.usesFixedWidthBubbles) {
        return [self widthForFixedWidthBubblesWithLayout:layout];
    }

    return layout.itemWidth;
}

- (CGFloat)widthForFixedWidthBubblesWithLayout:(JSQMessagesCollectionViewFlowLayout *)layout {
    NSInteger horizontalInsets = layout.sectionInset.left + layout.sectionInset.right + self.additionalInset;
    CGFloat width = CGRectGetWidth(layout.collectionView.bounds) - horizontalInsets;
    CGFloat height = CGRectGetHeight(layout.collectionView.bounds) - horizontalInsets;
    CGFloat candidate = MIN(width, height);
    // 仅在 collectionView 已有有效宽度时缓存，避免 viewDidLoad 阶段 bounds 为 0 时缓存错误值导致官方账号/收藏夹长文本宽度不对
    if (candidate > 100.0f) {
        self.layoutWidthForFixedWidthBubbles = candidate;
    }
    if (self.layoutWidthForFixedWidthBubbles > 0.0f) {
        return self.layoutWidthForFixedWidthBubbles;
    }
    return MAX(candidate, 0.0f);
}

- (BOOL)isMultiLineForMessage:(id)messageData atIndexPath:(NSIndexPath *)indexPath withLayout:(JSQMessagesCollectionViewFlowLayout *)layout
{
    JSQMessage *msg = (JSQMessage *)messageData;
    if (![msg isKindOfClass:[JSQMessage class]]) return NO;
    if ([msg isMediaMessage] || msg.msgType == TM_TYPE_SYSTEAM_INFO || msg.msgType == TM_TYPE_REVOKE
        || msg.msgType == TM_TYPE_RED_PACKET || jsq_isRedPacketContent([msg text]) || msg.msgType == TM_TYPE_TRANSFER || jsq_isTransferContent([msg text]) || msg.msgType == TM_TYPE_VOIP_RECORD) {
        return NO;
    }
    CGFloat layoutWidth = [self textBubbleWidthForLayout:layout];
    NSString *multiKey = [NSString stringWithFormat:@"%llu_%d", (unsigned long long)[msg messageHash], (int)(layoutWidth * 100)];
    NSNumber *cached = [self.multiLineCache objectForKey:multiKey];
    if (cached != nil) {
        return [cached boolValue];
    }
    // 与 messageBubbleSizeForMessageData 共用一套两阶段宽度与 bottomInset 逻辑，避免 FlowLayout 用简化 bounding 误判单行 → textContainer 底边距过小 → 对方窄气泡底部裁字
    if (indexPath != nil) {
        (void)[self messageBubbleSizeForMessageData:msg atIndexPath:indexPath withLayout:layout];
        cached = [self.multiLineCache objectForKey:multiKey];
        if (cached != nil) {
            return [cached boolValue];
        }
    }
    return NO;
}

@end
