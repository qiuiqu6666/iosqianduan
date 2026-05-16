//telegram @wz662
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
#import <UIKit/UIGlassEffect.h>
#endif
#import "ChatRootViewController.h"
#import "ChatRootViewController+MessageList.h"
#import "ChatRootViewController+Send.h"
#import "ChatRootViewController+GroupChat.h"
#import "ChatRootViewController+ReadReceipt.h"
#import "ChatRootViewController+Sync.h"
#import "ChatRootViewController+MessageMenu.h"
#import "IMClientManager.h"
#import "ClientCoreSDK.h"
#import "Protocal.h"
#import "AppDelegate.h"
#import "SDImageCache.h"
#import "SDWebImageManager.h"
#import "MSSBrowseModel.h"
#import "MSSBrowseNetworkViewController.h"
#import "TZImagePickerController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import "TZImageManager.h"
#import "SendImageHelper.h"
#import "ChatDataHelper.h"
#import "SendVoiceHelper.h"
#import "JSQAudioMediaItem.h"
#import "ViewControllerFactory.h"
#import "UserEntity.h"
#import "NotificationCenterFactory.h"
#import "kmMoreMenuItem.h"
#import "FileDownloadHelper.h"
#import "PromtHelper.h"
#import "MessageHelper.h"
#import "IQVoiceMeterView.h"
#import "MSSBrowseLocalViewController.h"
#import "FileTool.h"
#import "FileMeta.h"
#import "rbFileMediaItem.h"
#import "ReceivedFileHelper.h"
#import "SendFileHelper.h"
#import "BigFileUploadManager.h"
#import "ShortVideoRecordViewController.h"
#import "SendShortVideoHelper.h"
#import "JSQVideoMediaItem.h"
#import "ReceivedShortVideoHelper.h"
#import "rbContactMediaItem.h"
#import "QueryFriendInfoAsync.h"
#import "QueryGroupInfoAsync.h"
#import "rbLocationMediaItem.h"
#import "LocationUtils.h"
#import "MessageRevokingProgess.h"
#import "BasicTool.h"
#import "MessageRevokingManager.h"
#import "TMessageHelper.h"
#import "GMessageHelper.h"
#import "AlarmType.h"
#import "TimeTool.h"
#import "FaceDataProvider.h"
#import "FaceBoardView.h"
#import "MessagesProvider.h"
#import "TargetSourceFilterFactory.h"
#import "QRCodeScheme.h"
#import "JoinGroupViewController.h"
#import "GChatDataHelper.h"
#import "TChatDataHelper.h"
#import "Quote4InputWrapper.h"
#import "UIImageView+WebCache.h"
#import "BigFileViewerController.h"
#import "GroupsViewController.h"
#import "AlarmsViewController.h"
#import "rbSystemInfoCollectionViewCell.h"
#import "HttpRestHelper.h"
#import "EmojiUtil.h"
#import "MyDataBase.h"
#import "VoipRecordMeta.h"
#import "CallManager.h"
#import "ChatBackgroundViewController.h"
#import "UserDefaultsToolKits.h"
#import "StickerManager.h"
#import "StickerManageViewController.h"
#import "FavPickerViewController.h"
#import "ContactMeta.h"
#import "LocationMeta.h"
#import "UnifiedMediaBrowserViewController.h"
#import "AlarmsProvider.h"
#import "WalletRedPacketDetailViewController.h"
#import "RedPacketPopupViewController.h"
#import "WalletTransferDetailViewController.h"
#import "RBAvatarView.h"
#import "RBNicknameColor.h"
#import "JSQMessagesCollectionViewCell.h"
#import "JSQMessage+RBConversationSeq.h"
#import "TGInputBar.h"
#import "Masonry.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "Default.h"
#import "RBChromeNavigationBar.h"

/// NO：使用原版 JSQ 底部输入栏（`JSQMessagesToolbarContentView.xib`，灰底+白框+内嵌表情）；YES：使用 Telegram 风格 `TGInputBar`（当前工程默认改回原版）
static const BOOL kRBChatUseTGInputBar = NO;
static NSString * const kRBMentionUserURLScheme = @"rbmention-user";
static NSString * const kRBMentionGroupURLScheme = @"rbmention-group";
static const int kRBInitialUnreadBannerMinCountExclusive = 20;

static inline BOOL RBShouldShowInitialUnreadBanner(int unreadCount)
{
    return unreadCount > kRBInitialUnreadBannerMinCountExclusive;
}

static NSRegularExpression *RbMentionIdRegex(void)
{
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"(?<![A-Za-z0-9_])@([A-Za-z0-9]{10}|[0-9]{5,20})(?![A-Za-z0-9_])" options:NSRegularExpressionCaseInsensitive error:nil];
    });
    return regex;
}

static inline double RBChatTraceNowMs(void)
{
    return CFAbsoluteTimeGetCurrent() * 1000.0;
}

static inline NSString *RBChatTraceSafeFp(JSQMessage *message)
{
    NSString *fp = [BasicTool trim:message.fingerPrintOfProtocal];
    return (fp.length > 0 ? fp : @"-");
}

static const NSTimeInterval kRBOutgoingTextCustomAppearDuration = 0.12;

/** 采样缩略位图：是否存在明显透明/半透明像素（用于区分「白底 JPG」与「透明底 PNG」） */
static BOOL RbChatPatternImageHasTranslucentPixels(UIImage *pattern)
{
    CGImageRef cg = pattern.CGImage;
    if (!cg) {
        return NO;
    }
    CGImageAlphaInfo ai = CGImageGetAlphaInfo(cg);
    if (ai == kCGImageAlphaNone || ai == kCGImageAlphaNoneSkipLast || ai == kCGImageAlphaNoneSkipFirst) {
        return NO;
    }
    CGFloat maxSide = 48.0;
    CGFloat w = pattern.size.width;
    CGFloat h = pattern.size.height;
    CGFloat k = MIN(MIN(maxSide / w, maxSide / h), 1.0);
    size_t tw = (size_t)MAX((NSInteger)floor(w * k), 1);
    size_t th = (size_t)MAX((NSInteger)floor(h * k), 1);
    NSMutableData *data = [NSMutableData dataWithLength:tw * th * 4];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(data.mutableBytes, tw, th, 8, tw * 4, cs, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    if (!ctx) {
        return YES;
    }
    CGContextSetInterpolationQuality(ctx, kCGInterpolationLow);
    CGContextDrawImage(ctx, CGRectMake(0, 0, tw, th), cg);
    CGContextRelease(ctx);
    const UInt8 *bytes = data.bytes;
    NSUInteger count = tw * th;
    for (NSUInteger i = 0; i < count; i++) {
        if (bytes[i * 4 + 3] < 250) {
            return YES;
        }
    }
    return NO;
}

/** 将默认纹理与聊天底色合成一张图：不透明资源用 Multiply（浅底灰线叠在 #EDEDED 上与 TG 一致）；透明 PNG 则铺底再绘制。 */
static UIImage *RbChatCompositePatternWithChatBgColor(UIImage *pattern, UIColor *bgColor)
{
    if (!pattern || !bgColor) {
        return nil;
    }
    BOOL translucent = RbChatPatternImageHasTranslucentPixels(pattern);
    CGSize size = pattern.size;
    CGFloat scale = pattern.scale > 0 ? pattern.scale : [UIScreen mainScreen].scale;

    if (!translucent) {
        UIGraphicsBeginImageContextWithOptions(size, YES, scale);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        if (ctx) {
            CGContextSetFillColorWithColor(ctx, bgColor.CGColor);
            CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));
            [pattern drawInRect:CGRectMake(0, 0, size.width, size.height) blendMode:kCGBlendModeMultiply alpha:1.0];
        }
        UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return [out imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }

    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (ctx) {
        CGContextSetFillColorWithColor(ctx, bgColor.CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));
        [pattern drawInRect:CGRectMake(0, 0, size.width, size.height) blendMode:kCGBlendModeNormal alpha:1.0];
    }
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [out imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

static UIImage *RbChatCachedComposedPatternImage(void)
{
    static UIImage *cached;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIImage *raw = [UIImage imageNamed:@"chat_bg_pattern_light"];
        cached = RbChatCompositePatternWithChatBgColor(raw, UI_DEFAULT_CHATTING_BG);
    });
    return cached;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface ChatRootViewController ()<FaceBoardViewDelegate, StickerManageDelegate, UISearchBarDelegate, UIGestureRecognizerDelegate> // F表情面板代理

/// 定义于 JSQMessagesViewController.m，公有头文件未导出；嵌套 block 内调用需前置声明方能通过编译。
- (BOOL)jsq_isMenuVisible;
/// 定义于 JSQMessagesViewController.m（未读条数），头文件未导出。
- (int)getUnreadCount;

@property (strong, nonatomic) JSQMessagesBubbleImage *outgoingBubbleImageData;
@property (strong, nonatomic) JSQMessagesBubbleImage *outgoingBubbleImageData_light;
@property (strong, nonatomic) JSQMessagesBubbleImage *outgoingBubbleImageData_white;
@property (strong, nonatomic) JSQMessagesBubbleImage *incomingBubbleImageData;
/** 首帧气泡未就绪时返回的轻量占位，避免返回 nil */
@property (strong, nonatomic) JSQMessagesBubbleImage *rb_placeholderBubbleImageData;

// F表情
@property (nonatomic, strong) FaceBoardView *faceBoard;
@property (nonatomic, strong) NSDictionary *inputTextAttributes;
/** “更多”面板是否已完成一次菜单项构建；改为点击时懒初始化，避免首屏批量创建按钮/图片/标题。 */
@property (nonatomic, assign) BOOL rb_didInitMoreContentView;

/** 标记当前滚动是否为用户手动拖拽（用于区分自动滚动和手动滚动，决定是否清除@我追踪） */
@property (nonatomic, assign) BOOL isUserDragging;

/** 自定义聊天背景图片视图 */
@property (nonatomic, strong) UIImageView *chatBgImageView;
/** 聊天背景图底部约束（constant = safeAreaInsets.bottom，使背景延伸到物理屏底） */
@property (nonatomic, strong) NSLayoutConstraint *chatBgImageViewBottomConstraint;
/** 默认聊天背景：容器内底层纯色 + 上层带透明通道的纹理图（有会话自定义壁纸时整层隐藏） */
@property (nonatomic, strong) UIView *chatBgPatternContainerView;
@property (nonatomic, strong) UIView *chatBgPatternSolidView;
@property (nonatomic, strong) UIImageView *chatBgPatternImageView;
@property (nonatomic, strong) NSLayoutConstraint *chatBgPatternContainerBottomConstraint;

// 消息气泡长按菜单时，选中的列表单元索引（此变量仅用的是JSQ原库中的变量同名，但仅是同名，没有关联哦） @since 4.3
@property (strong, nonatomic) NSIndexPath *selectedIndexPathForMenu;

// 消息"撤回"功能对应的进度提示框
@property (strong, nonatomic) MessageRevokingProgess *messageRevokingDialogProgess;

/** 消息引用功能的输入框功能封装类 */
@property (strong, nonatomic) Quote4InputWrapper *quote4InputWrapper;

/**
 * 下拉刷新控件组件。 @since 10.0
 */
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic, assign) BOOL isRefreshing;

/**
 * 对方已读到的最新消息时间戳（毫秒），用于判断"我"发出的消息是否已被对方阅读。
 * 来源：通过接口 1008-4-25 查询获得。
 * @since 11.x
 */
@property (nonatomic, copy) NSString *partnerLastReadTime2;

@property (nonatomic, assign) BOOL rb_pendingScrollToBottomAfterVoipRecord;

/** 标记本次VC生命周期内是否已触发过漫游（防止 viewWillAppear/viewDidAppear 重复触发）@since 11.x */
@property (nonatomic, assign) BOOL serverHistoryFetched;

/** 标记是否正在从服务端拉取聊天记录（防重入）@since 11.x */
@property (nonatomic, assign) BOOL serverHistoryFetching;

/** 更早历史已穷尽（本地+服务端均无新条），避免在顶部反复 prefetch/reload 造成「重复重建」 */
@property (nonatomic, assign) BOOL rb_olderHistoryExhausted;
/** 本次穷尽周期内是否已提示「没有更早消息」，下拉刷新后会清零以便再试 */
@property (nonatomic, assign) BOOL rb_noMoreOlderHistoryToastShown;

/** SQLite 拉更早一页前记录的 collection 高度/偏移，用于 reload 后抵消 prepend 造成的跳动 */
@property (nonatomic, assign) BOOL rb_pendingPreserveScrollAfterOlderSqliteLoad;
@property (nonatomic, assign) CGFloat rb_olderLoadAnchorContentHeight;
@property (nonatomic, assign) CGPoint rb_olderLoadAnchorContentOffset;

@property (nonatomic, assign) BOOL rb_deferredOlderHistoryFinishPending;
@property (nonatomic, assign) BOOL rb_deferredOlderHistoryFinishMergedNewRows;
@property (nonatomic, assign) BOOL rb_deferredOlderHistoryFinishShowToast;

/**
 * 上次已读回执上报的时间（用于节流）。
 * 群聊场景下为避免高频请求，两次上报间隔至少 5 秒。
 * @since 11.x
 */
@property (nonatomic, assign) NSTimeInterval lastReadReceiptReportTime;
/// 上一次 HTTP 查询对方已读水位的时间（秒），用于与对方连续发消息叠加时的查询节流 @since perf
@property (nonatomic, assign) NSTimeInterval lastPartnerReadReceiptQueryWallTime;

/** @我 滚动检测节流：scrollViewDidScroll 极高频时降低 refreshAtMeHintVisibility 调用次数 @since perf */
@property (nonatomic, assign) CFTimeInterval rb_atMeHintScrollThrottleLastTs;

/** 消息底部时间标签的格式化器（HH:mm），缓存避免重复创建 */
@property (nonatomic, strong) NSDateFormatter *bottomLabelTimeFormatter;

/** "回到底部"浮动按钮（上滑查看历史消息时显示，点击一键滚动到最新消息） */
@property (nonatomic, strong) UIButton *scrollToBottomButton;
/** 回到底部按钮右上角未读条数角标（与 JSQ 「X条新消息」共用 getUnreadCount） */
@property (nonatomic, strong) UILabel *scrollToBottomBadgeLabel;
@property (nonatomic, strong) NSLayoutConstraint *scrollToBottomBadgeWidthConstraint;
@property (nonatomic, strong) UIButton *rb_bottomNewMsgBanner;
@property (nonatomic, strong) UILabel *rb_bottomNewMsgLabel;
@property (nonatomic, strong) UIButton *rb_topUnreadBanner;
@property (nonatomic, strong) UILabel *rb_topUnreadLabel;
@property (nonatomic, assign) BOOL rb_topUnreadBannerDismissed;
@property (nonatomic, assign) NSInteger rb_unreadDividerIndex;
@property (nonatomic, assign) NSInteger rb_newMsgDividerIndex;
@property (nonatomic, copy) NSString *rb_unreadDividerAnchorFp;
@property (nonatomic, copy) NSString *rb_newMsgDividerAnchorFp;
@property (nonatomic, assign) NSInteger rb_dividerKnownListCount;
/** @选择返回后，是否需要在页面真正可见时再拉起键盘（避免键盘与输入栏错位） */
@property (nonatomic, assign) BOOL pendingFocusAfterAtChoose;
/** 搜狗等第三方输入法：@选人返回后待插入的用户与前缀，等键盘真正弹出后再插入 */
@property (nonatomic, strong) TargetEntity *pendingAtUserForKeyboard;
@property (nonatomic, strong) NSMutableString *pendingAtUserPrefixForKeyboard;
@property (nonatomic, strong) id atUserInsertKeyboardObserverToken;

/** 中间气泡标题区域的宽度约束（用于随文字长度更新） */
@property (nonatomic, strong) NSLayoutConstraint *navTitleBubbleWidthConstraint;

/** 聊天页顶部弹出的搜索框（点击导航栏搜索图标时显示） */
@property (nonatomic, strong) UIView *chatSearchBarContainer;
@property (nonatomic, strong) UISearchBar *chatSearchBar;
@property (nonatomic, strong) NSLayoutConstraint *chatSearchBarHeightConstraint;
@property (nonatomic, assign) BOOL chatSearchBarVisible;

/** 搜索匹配结果列表（指纹），当前高亮索引、键盘上方数量条与上下条按钮 */
@property (nonatomic, copy) NSArray<NSString *> *searchMatchFingerprints;
@property (nonatomic, assign) NSInteger searchMatchCurrentIndex;
@property (nonatomic, strong) UIView *chatSearchResultStrip;
@property (nonatomic, strong) UILabel *chatSearchResultCountLabel;
@property (nonatomic, strong) UIButton *chatSearchResultListModeButton; /// 以列表模式查看，跳收藏夹搜索并携带关键词
@property (nonatomic, strong) UIButton *chatSearchResultPrevButton;
@property (nonatomic, strong) UIButton *chatSearchResultNextButton;
/** 仅下一次高亮定位使用平缓滚动动画，主要给“点击引用回到原消息”使用。 */
@property (nonatomic, assign) BOOL rb_animateHighlightScrollOnce;
/** 分段滚动 token，新动画开始时使旧的分段动画链自动失效。 */
@property (nonatomic, assign) NSUInteger rb_highlightScrollAnimationToken;

/** 全屏右滑返回手势（屏幕任意区域右滑即可返回） */
@property (nonatomic, strong) UIPanGestureRecognizer *rb_fullScreenPopPanGesture;
/** 点击任意区域收起键盘（仅键盘/表情/更多显示时生效，点击输入栏区域不触发） */
@property (nonatomic, strong) UITapGestureRecognizer *rb_dismissKeyboardTap;
/** 点击消息列表区域收起键盘/表情/更多（与 rb_dismissKeyboardTap 互补，解决列表区域点击被 scroll 抢占导致未关闭的问题） */
@property (nonatomic, strong) UITapGestureRecognizer *rb_dismissKeyboardTapOnCollectionView;

/** @高亮用正则（复用，避免 cell 内重复创建） */
@property (nonatomic, strong) NSRegularExpression *rb_atHighlightRegex;

/** Emoji 富文本缓存（key=消息原文，避免重复 replaceEmoji 计算） */
@property (nonatomic, strong) NSCache<NSString *, NSAttributedString *> *rb_emojiAttrCache;

/** 合并刷新：待刷新的 indexPaths，主线程合并后一次 reload，减轻连续 reload 卡顿 */
@property (nonatomic, strong) NSMutableSet<NSIndexPath *> *rb_pendingRefreshIndexPaths;
@property (nonatomic, assign) BOOL rb_refreshCoalesceScheduled;
/** viewDidAppear 时记录，用于进入聊天后短时延迟 flush，避免与转场/布局交织导致图片气泡闪烁 */
@property (nonatomic, assign) NSTimeInterval rb_viewDidAppearTime;
/** 右滑返回手势取消时（未真正 pop）：不刷新列表、不回到初始化状态。viewWillDisappear 置 YES，viewDidDisappear 置 YES 表示已完全离开；若只 will 未 did 则视为取消返回 */
@property (nonatomic, assign) BOOL rb_hadWillDisappear;
@property (nonatomic, assign) BOOL rb_hadDidDisappear;
/** 是否已做过首次导航栏无动画布局（后续 viewWillAppear 只做 transform/按钮重挂，不做 layoutIfNeeded 减负） */
@property (nonatomic, assign) BOOL rb_didPerformFirstNavBarLayout;
/** 是否已执行过 rb_deferredSetupAfterFirstFrame（仅执行一次，由子类在数据就绪后调用） */
@property (nonatomic, assign) BOOL rb_didDeferredSetupFirstFrame;
/** push 期间隐藏了列表，需在 viewDidAppear（转场结束瞬间）恢复 alpha=1，避免「从右上方飘下来」 */
@property (nonatomic, assign) BOOL rb_didHideCollectionViewForPush;
/** 本次会话是否已执行过自动滚到底部（仅首次进入时滚一次，后续 viewWillAppear 不再滚，减轻主线程） */
@property (nonatomic, assign) BOOL rb_didAutoScrollToBottomOnce;
/** 本次会话是否已执行过 viewDidAppear（用于首次进入时跳过 invalidateLayout+reloadData，避免气泡时间闪烁） */
@property (nonatomic, assign) BOOL rb_didFirstViewDidAppear;
/** 上次在聊天页应用的 global 字号倍率（BasicTool），未初始化时为 -1；未变化则跳过 refreshFontsForView 与整表气泡字体刷新 */
@property (nonatomic, assign) CGFloat rb_cachedChatGlobalFontMultiplier;
/** 是否已经延后调度过 IQVoiceMeterView 图片预热，避免首个 viewDidAppear 抢主线程。 */
@property (nonatomic, assign) BOOL rb_didScheduleVoiceMeterPreload;

/** 布局/数据源回调阶段缓存的列表引用，同一 layout pass 内复用，减少 getChattingDatasList 重复调用（卡顿优化） */
@property (nonatomic, strong) NSArray<JSQMessage *> *rb_cachedChattingListForLayout;
/** 聊天布局热路径里复用每条消息的元信息，避免同一轮 layout 重复计算多个高度/宽度代理。 */
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary<NSString *, NSNumber *> *> *rb_cachedLayoutMetaByMessageKey;
/** 最近一次已与 UICollectionView 对齐的消息条数（增量 insert/reload 后更新）。用于判断「仅多一条」：数据源与 numberOfItems 同源时 cvCount 已含新条，listCount==cvCount+1 永远不成立 */
@property (nonatomic, assign) NSInteger rb_appliedChatItemCount;
@property (nonatomic, assign) BOOL rb_needRefreshAndScrollToBottomOnAppear;
@property (nonatomic, strong) NSMutableSet<NSString *> *rb_animatedOutgoingTextFingerprints;

/** 群聊「显示成员昵称」开关缓存，避免布局热路径中频繁读 UserDefaults（P0-3 卡顿优化） */
@property (nonatomic, assign) BOOL rb_cachedShowGroupMemberNickname;

/** 键盘可见时保存的 toolbar 底部 constant，供 viewDidLayoutSubviews 恢复（基类会按原 textView 非 firstResponder 重置为 rest） */
@property (nonatomic, assign) CGFloat rb_tgInputBar_lastToolbarConstant;

/** 聊天页首屏 SQLite bootstrap 期间的骨架遮罩，仅在当前会话列表为空时显示。 */
@property (nonatomic, strong) UIView *rb_chatFirstScreenSkeletonCover;
@property (nonatomic, strong) UIView *rb_chatFirstScreenSkeletonContentView;
/** 搜索跳转定位恢复：正在后台补载目标消息窗口。 */
@property (nonatomic, assign) BOOL rb_searchJumpContextLoadInFlight;
/** 搜索跳转定位恢复：同一条指纹最多自动补载一次，避免 viewDidAppear/deferred 重复触发。 */
@property (nonatomic, assign) NSInteger rb_searchJumpRecoveryAttemptCount;
@property (nonatomic, copy) NSString *rb_searchJumpRecoveryFingerprint;

@end

@interface ChatRootViewController (RoamingFirstScreenSkeleton)
- (BOOL)rb_shouldShowChatFirstScreenSkeleton;
- (void)rb_buildChatFirstScreenSkeletonIfNeeded;
- (void)rb_startChatFirstScreenSkeletonAnimating;
- (void)rb_evaluateChatFirstScreenSkeletonCover;
- (void)rb_removeChatFirstScreenSkeleton;
@end

@interface ChatRootViewController (SearchJumpRecovery)
- (BOOL)rb_tryRecoverSearchJumpContextIfNeededWithFingerprint:(NSString *)fingerprint;
@end

@implementation ChatRootViewController (RoamingFirstScreenSkeleton)

- (BOOL)rb_shouldShowChatFirstScreenSkeleton
{
    if (!self.isViewLoaded || self.collectionView == nil) {
        return NO;
    }
    NSInteger listCount = (NSInteger)[self getChattingDatasList].count;
    NSInteger cvCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
    return (self.rb_shouldDeferInitialChatListReloadUntilSqliteBootstrap || self.rb_searchJumpContextLoadInFlight)
        && listCount == 0
        && cvCount == 0;
}

- (void)rb_buildChatFirstScreenSkeletonIfNeeded
{
    if (self.rb_chatFirstScreenSkeletonCover || self.collectionView == nil) {
        return;
    }

    UIView *cover = [[UIView alloc] init];
    cover.translatesAutoresizingMaskIntoConstraints = NO;
    cover.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.74f];
    cover.userInteractionEnabled = YES;
    [self.view addSubview:cover];
    self.rb_chatFirstScreenSkeletonCover = cover;

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.backgroundColor = [UIColor clearColor];
    [cover addSubview:content];
    self.rb_chatFirstScreenSkeletonContentView = content;

    [NSLayoutConstraint activateConstraints:@[
        [cover.topAnchor constraintEqualToAnchor:self.collectionView.topAnchor],
        [cover.leadingAnchor constraintEqualToAnchor:self.collectionView.leadingAnchor],
        [cover.trailingAnchor constraintEqualToAnchor:self.collectionView.trailingAnchor],
        [cover.bottomAnchor constraintEqualToAnchor:self.collectionView.bottomAnchor],
        [content.topAnchor constraintEqualToAnchor:cover.topAnchor constant:18.f],
        [content.leadingAnchor constraintEqualToAnchor:cover.leadingAnchor constant:16.f],
        [content.trailingAnchor constraintEqualToAnchor:cover.trailingAnchor constant:-16.f],
        [content.bottomAnchor constraintLessThanOrEqualToAnchor:cover.bottomAnchor constant:-12.f],
    ]];

    UIColor *primary = [UIColor colorWithWhite:0.89 alpha:1.0];
    UIColor *secondary = [UIColor colorWithWhite:0.84 alpha:1.0];
    NSArray<NSNumber *> *incomingWidths = @[ @(0.44f), @(0.31f), @(0.52f), @(0.36f) ];
    NSArray<NSNumber *> *outgoingWidths = @[ @(0.40f), @(0.47f), @(0.28f), @(0.34f) ];

    NSInteger rows = 6;
    CGFloat height = CGRectGetHeight(self.collectionView.bounds);
    if (height > 260.f) {
        NSInteger estimated = (NSInteger)floor((height - 20.f) / 88.f);
        rows = MAX(5, MIN(8, estimated));
    }

    UIView *previousRow = nil;
    for (NSInteger i = 0; i < rows; i++) {
        BOOL incoming = (i % 2 == 0);
        UIView *row = [[UIView alloc] init];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        row.backgroundColor = [UIColor clearColor];
        [content addSubview:row];

        [NSLayoutConstraint activateConstraints:@[
            [row.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
            [row.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
            previousRow
                ? [row.topAnchor constraintEqualToAnchor:previousRow.bottomAnchor constant:12.f]
                : [row.topAnchor constraintEqualToAnchor:content.topAnchor],
            [row.heightAnchor constraintEqualToConstant:(incoming ? 78.f : 64.f)],
        ]];
        if (i == rows - 1) {
            [row.bottomAnchor constraintEqualToAnchor:content.bottomAnchor].active = YES;
        }
        previousRow = row;

        if (incoming) {
            UIView *avatar = [[UIView alloc] init];
            avatar.translatesAutoresizingMaskIntoConstraints = NO;
            avatar.backgroundColor = primary;
            avatar.layer.cornerRadius = 19.f;
            avatar.clipsToBounds = YES;
            [row addSubview:avatar];

            UIView *nameLine = [[UIView alloc] init];
            nameLine.translatesAutoresizingMaskIntoConstraints = NO;
            nameLine.backgroundColor = secondary;
            nameLine.layer.cornerRadius = 4.f;
            nameLine.clipsToBounds = YES;
            [row addSubview:nameLine];

            UIView *bubble = [[UIView alloc] init];
            bubble.translatesAutoresizingMaskIntoConstraints = NO;
            bubble.backgroundColor = primary;
            bubble.layer.cornerRadius = 18.f;
            bubble.clipsToBounds = YES;
            [row addSubview:bubble];

            UIView *bubbleLine = [[UIView alloc] init];
            bubbleLine.translatesAutoresizingMaskIntoConstraints = NO;
            bubbleLine.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4f];
            bubbleLine.layer.cornerRadius = 4.f;
            bubbleLine.clipsToBounds = YES;
            [bubble addSubview:bubbleLine];

            CGFloat widthMult = [incomingWidths[i % incomingWidths.count] doubleValue];
            [NSLayoutConstraint activateConstraints:@[
                [avatar.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
                [avatar.topAnchor constraintEqualToAnchor:row.topAnchor constant:10.f],
                [avatar.widthAnchor constraintEqualToConstant:38.f],
                [avatar.heightAnchor constraintEqualToConstant:38.f],
                [nameLine.leadingAnchor constraintEqualToAnchor:avatar.trailingAnchor constant:10.f],
                [nameLine.topAnchor constraintEqualToAnchor:avatar.topAnchor constant:1.f],
                [nameLine.widthAnchor constraintEqualToConstant:68.f],
                [nameLine.heightAnchor constraintEqualToConstant:10.f],
                [bubble.leadingAnchor constraintEqualToAnchor:nameLine.leadingAnchor],
                [bubble.topAnchor constraintEqualToAnchor:nameLine.bottomAnchor constant:10.f],
                [bubble.widthAnchor constraintEqualToAnchor:row.widthAnchor multiplier:widthMult],
                [bubble.heightAnchor constraintEqualToConstant:36.f],
                [bubbleLine.leadingAnchor constraintEqualToAnchor:bubble.leadingAnchor constant:14.f],
                [bubbleLine.trailingAnchor constraintEqualToAnchor:bubble.trailingAnchor constant:-18.f],
                [bubbleLine.centerYAnchor constraintEqualToAnchor:bubble.centerYAnchor],
                [bubbleLine.heightAnchor constraintEqualToConstant:8.f],
            ]];
        } else {
            UIView *timeLine = [[UIView alloc] init];
            timeLine.translatesAutoresizingMaskIntoConstraints = NO;
            timeLine.backgroundColor = secondary;
            timeLine.layer.cornerRadius = 4.f;
            timeLine.clipsToBounds = YES;
            [row addSubview:timeLine];

            UIView *bubble = [[UIView alloc] init];
            bubble.translatesAutoresizingMaskIntoConstraints = NO;
            bubble.backgroundColor = primary;
            bubble.layer.cornerRadius = 18.f;
            bubble.clipsToBounds = YES;
            [row addSubview:bubble];

            UIView *bubbleLine = [[UIView alloc] init];
            bubbleLine.translatesAutoresizingMaskIntoConstraints = NO;
            bubbleLine.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4f];
            bubbleLine.layer.cornerRadius = 4.f;
            bubbleLine.clipsToBounds = YES;
            [bubble addSubview:bubbleLine];

            CGFloat widthMult = [outgoingWidths[i % outgoingWidths.count] doubleValue];
            [NSLayoutConstraint activateConstraints:@[
                [timeLine.topAnchor constraintEqualToAnchor:row.topAnchor constant:8.f],
                [timeLine.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-6.f],
                [timeLine.widthAnchor constraintEqualToConstant:48.f],
                [timeLine.heightAnchor constraintEqualToConstant:10.f],
                [bubble.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
                [bubble.topAnchor constraintEqualToAnchor:timeLine.bottomAnchor constant:10.f],
                [bubble.widthAnchor constraintEqualToAnchor:row.widthAnchor multiplier:widthMult],
                [bubble.heightAnchor constraintEqualToConstant:36.f],
                [bubbleLine.leadingAnchor constraintEqualToAnchor:bubble.leadingAnchor constant:14.f],
                [bubbleLine.trailingAnchor constraintEqualToAnchor:bubble.trailingAnchor constant:-18.f],
                [bubbleLine.centerYAnchor constraintEqualToAnchor:bubble.centerYAnchor],
                [bubbleLine.heightAnchor constraintEqualToConstant:8.f],
            ]];
        }
    }

    [self rb_startChatFirstScreenSkeletonAnimating];
}

- (void)rb_startChatFirstScreenSkeletonAnimating
{
    CALayer *layer = self.rb_chatFirstScreenSkeletonContentView.layer;
    if (layer == nil) {
        return;
    }
    [layer removeAnimationForKey:@"rb_chat_first_screen_skeleton_pulse"];
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    anim.fromValue = @(0.72f);
    anim.toValue = @(1.0f);
    anim.duration = 0.95f;
    anim.autoreverses = YES;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:anim forKey:@"rb_chat_first_screen_skeleton_pulse"];
}

- (void)rb_evaluateChatFirstScreenSkeletonCover
{
    if (![self rb_shouldShowChatFirstScreenSkeleton]) {
        [self rb_removeChatFirstScreenSkeleton];
        return;
    }
    [self rb_buildChatFirstScreenSkeletonIfNeeded];
    self.collectionView.hidden = NO;
    self.collectionView.alpha = 0.0f;
    self.rb_chatFirstScreenSkeletonCover.hidden = NO;
    [self.view bringSubviewToFront:self.rb_chatFirstScreenSkeletonCover];
}

- (void)rb_removeChatFirstScreenSkeleton
{
    self.collectionView.hidden = NO;
    self.collectionView.alpha = 1.0f;
    if (self.rb_chatFirstScreenSkeletonContentView.layer) {
        [self.rb_chatFirstScreenSkeletonContentView.layer removeAnimationForKey:@"rb_chat_first_screen_skeleton_pulse"];
    }
    if (self.rb_chatFirstScreenSkeletonCover) {
        [self.rb_chatFirstScreenSkeletonCover removeFromSuperview];
        self.rb_chatFirstScreenSkeletonCover = nil;
        self.rb_chatFirstScreenSkeletonContentView = nil;
    }
}
@end


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation ChatRootViewController

static NSMutableDictionary *RBSearchJumpPendingFpByUid(void) {
    static NSMutableDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = [NSMutableDictionary dictionary];
    });
    return d;
}

static NSMutableDictionary *RBSearchJumpPendingAnchorDateByUid(void) {
    static NSMutableDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = [NSMutableDictionary dictionary];
    });
    return d;
}

static NSString *RBPeekPendingSearchJumpFpForUid(NSString *uid) {
    NSString *u = [BasicTool trim:uid];
    if (u.length == 0) return nil;
    NSMutableDictionary *d = RBSearchJumpPendingFpByUid();
    @synchronized(d) {
        NSString *fp = d[u];
        return ([BasicTool trim:fp].length > 0) ? [fp copy] : nil;
    }
}

static NSDate *RBPeekPendingSearchJumpAnchorDateForUid(NSString *uid) {
    NSString *u = [BasicTool trim:uid];
    if (u.length == 0) return nil;
    NSMutableDictionary *d = RBSearchJumpPendingAnchorDateByUid();
    @synchronized(d) {
        id value = d[u];
        return [value isKindOfClass:[NSDate class]] ? value : nil;
    }
}

static void RBClearPendingSearchJumpFpForUid(NSString *uid) {
    NSString *u = [BasicTool trim:uid];
    if (u.length == 0) return;
    NSMutableDictionary *d = RBSearchJumpPendingFpByUid();
    @synchronized(d) {
        [d removeObjectForKey:u];
    }
}

static void RBClearPendingSearchJumpAnchorDateForUid(NSString *uid) {
    NSString *u = [BasicTool trim:uid];
    if (u.length == 0) return;
    NSMutableDictionary *d = RBSearchJumpPendingAnchorDateByUid();
    @synchronized(d) {
        [d removeObjectForKey:u];
    }
}

+ (void)rb_syncPendingSearchJumpHighlightFingerprint:(NSString *)highlight fpForUid:(NSString *)uid {
    NSString *u = [BasicTool trim:uid];
    if (u.length == 0) return;
    NSMutableDictionary *d = RBSearchJumpPendingFpByUid();
    NSString *fp = [BasicTool trim:highlight];
    @synchronized(d) {
        if (fp.length == 0) {
            [d removeObjectForKey:u];
            NSLog(@"【RB-SEARCH-JUMP】pendingFp CLEAR uid=%@", u);
        } else {
            d[u] = [fp copy];
            NSLog(@"【RB-SEARCH-JUMP】pendingFp SET uid=%@ fp=%@", u, fp);
        }
    }
}

+ (void)rb_syncPendingSearchJumpAnchorMessageDate:(NSDate *)anchorMessageDate forUid:(NSString *)uid
{
    NSString *u = [BasicTool trim:uid];
    if (u.length == 0) return;
    NSMutableDictionary *d = RBSearchJumpPendingAnchorDateByUid();
    @synchronized(d) {
        if (anchorMessageDate == nil) {
            [d removeObjectForKey:u];
            NSLog(@"【RB-SEARCH-JUMP】pendingAnchor CLEAR uid=%@", u);
        } else {
            d[u] = anchorMessageDate;
            NSLog(@"【RB-SEARCH-JUMP】pendingAnchor SET uid=%@ ts=%.0f", u, [anchorMessageDate timeIntervalSince1970]);
        }
    }
}

/// 若 VC 属性未带上指纹（个别初始化顺序下会丢），从工厂写入的 pending 表补回，避免首帧按「无指纹」滚到底部。
- (void)rb_mergePendingSearchJumpHighlightFingerprintIfNeeded {
    if ([BasicTool trim:self.toId].length == 0) return;
    if ([BasicTool trim:self.highlightOnceMsgFingerprint].length == 0) {
        NSString *peek = RBPeekPendingSearchJumpFpForUid(self.toId);
        if ([BasicTool trim:peek].length > 0) {
            self.highlightOnceMsgFingerprint = peek;
            NSLog(@"【RB-SEARCH-JUMP】merge pending -> VC.highlight fp=%@ toId=%@", peek, self.toId);
        }
    }
    if (self.highlightAnchorMessageDate == nil) {
        NSDate *pendingDate = RBPeekPendingSearchJumpAnchorDateForUid(self.toId);
        if (pendingDate != nil) {
            self.highlightAnchorMessageDate = pendingDate;
            NSLog(@"【RB-SEARCH-JUMP】merge pending -> VC.anchor ts=%.0f toId=%@", [pendingDate timeIntervalSince1970], self.toId);
        }
    }
}

//---------------------------------------------------------------------------------------------------
#pragma mark - 未读条数（与 JSQ 「X条新消息」共用计数；回到底部按钮角标）

- (void)setUnreadCount:(int)unreadCount
{
    [super setUnreadCount:unreadCount];
    [self rb_updateBottomNewMsgBannerVisibility];
}

- (void)rb_updateScrollToBottomButtonUnreadBadge
{
    UILabel *b = self.scrollToBottomBadgeLabel;
    NSLayoutConstraint *wconstraint = self.scrollToBottomBadgeWidthConstraint;
    if (!b || !wconstraint) {
        return;
    }
    int n = [self getUnreadCount];
    if (n <= 0) {
        b.hidden = YES;
        return;
    }
    b.hidden = NO;
    b.text = (n > 99) ? @"99+" : [NSString stringWithFormat:@"%d", n];
    CGSize sz = [b.text sizeWithAttributes:@{ NSFontAttributeName : b.font }];
    CGFloat textW = ceil(sz.width);
    CGFloat w = MAX(18.0, textW + 10.0);
    if (n > 99) {
        w = MAX(w, 28.0);
    }
    wconstraint.constant = w;
}

- (void)rb_initUnreadBanners
{
    if (self.rb_bottomNewMsgBanner != nil || self.rb_topUnreadBanner != nil) return;
    
    UIButton *bottom = [UIButton buttonWithType:UIButtonTypeCustom];
    bottom.translatesAutoresizingMaskIntoConstraints = NO;
    bottom.hidden = YES;
    bottom.alpha = 0;
    bottom.backgroundColor = HexColor(0x00C777);
    bottom.layer.cornerRadius = 0;
    bottom.layer.masksToBounds = NO;
    bottom.layer.shadowColor = [UIColor blackColor].CGColor;
    bottom.layer.shadowOffset = CGSizeMake(0, 2);
    bottom.layer.shadowOpacity = 0.18;
    bottom.layer.shadowRadius = 4;
    [bottom addTarget:self action:@selector(rb_onBottomNewMsgBannerTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:bottom];
    [self.view bringSubviewToFront:bottom];
    
    UIImageView *bottomIcon = [[UIImageView alloc] init];
    bottomIcon.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    UIImage *downIcon = [[UIImage systemImageNamed:@"arrow.down" withConfiguration:symCfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    bottomIcon.image = downIcon;
    bottomIcon.tintColor = [UIColor whiteColor];
    [bottom addSubview:bottomIcon];
    
    UILabel *bottomLabel = [[UILabel alloc] init];
    bottomLabel.translatesAutoresizingMaskIntoConstraints = NO;
    bottomLabel.textColor = [UIColor whiteColor];
    bottomLabel.font = [UIFont boldSystemFontOfSize:13];
    bottomLabel.textAlignment = NSTextAlignmentLeft;
    [bottom addSubview:bottomLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [bottomIcon.leadingAnchor constraintEqualToAnchor:bottom.leadingAnchor constant:12],
        [bottomIcon.centerYAnchor constraintEqualToAnchor:bottom.centerYAnchor],
        [bottomIcon.widthAnchor constraintEqualToConstant:16],
        [bottomIcon.heightAnchor constraintEqualToConstant:16],
        
        [bottomLabel.leadingAnchor constraintEqualToAnchor:bottomIcon.trailingAnchor constant:6],
        [bottomLabel.trailingAnchor constraintEqualToAnchor:bottom.trailingAnchor constant:-12],
        [bottomLabel.topAnchor constraintEqualToAnchor:bottom.topAnchor constant:6],
        [bottomLabel.bottomAnchor constraintEqualToAnchor:bottom.bottomAnchor constant:-6],
        
        [bottom.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:0],
        [bottom.bottomAnchor constraintEqualToAnchor:self.inputToolbar.topAnchor constant:-10],
    ]];
    
    UIButton *top = [UIButton buttonWithType:UIButtonTypeCustom];
    top.translatesAutoresizingMaskIntoConstraints = NO;
    top.hidden = YES;
    top.alpha = 0;
    top.backgroundColor = HexColor(0x00C777);
    top.layer.cornerRadius = 0;
    top.layer.masksToBounds = NO;
    top.layer.shadowColor = [UIColor blackColor].CGColor;
    top.layer.shadowOffset = CGSizeMake(0, 2);
    top.layer.shadowOpacity = 0.18;
    top.layer.shadowRadius = 4;
    [top addTarget:self action:@selector(rb_onTopUnreadBannerTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:top];
    [self.view bringSubviewToFront:top];
    
    UIImageView *topIcon = [[UIImageView alloc] init];
    topIcon.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *topSymCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    UIImage *topUpIcon = [[UIImage systemImageNamed:@"arrow.up" withConfiguration:topSymCfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    topIcon.image = topUpIcon;
    topIcon.tintColor = [UIColor whiteColor];
    [top addSubview:topIcon];
    
    UILabel *topLabel = [[UILabel alloc] init];
    topLabel.translatesAutoresizingMaskIntoConstraints = NO;
    topLabel.textColor = [UIColor whiteColor];
    topLabel.font = [UIFont boldSystemFontOfSize:13];
    topLabel.textAlignment = NSTextAlignmentLeft;
    [top addSubview:topLabel];
    
    NSLayoutYAxisAnchor *topAnchor = self.view.safeAreaLayoutGuide.topAnchor;
    if (self.rb_chromeNavigationBar) {
        topAnchor = self.rb_chromeNavigationBar.bottomAnchor;
    }
    [NSLayoutConstraint activateConstraints:@[
        [topIcon.leadingAnchor constraintEqualToAnchor:top.leadingAnchor constant:12],
        [topIcon.centerYAnchor constraintEqualToAnchor:top.centerYAnchor],
        [topIcon.widthAnchor constraintEqualToConstant:16],
        [topIcon.heightAnchor constraintEqualToConstant:16],
        
        [topLabel.leadingAnchor constraintEqualToAnchor:topIcon.trailingAnchor constant:6],
        [topLabel.trailingAnchor constraintEqualToAnchor:top.trailingAnchor constant:-12],
        [topLabel.topAnchor constraintEqualToAnchor:top.topAnchor constant:6],
        [topLabel.bottomAnchor constraintEqualToAnchor:top.bottomAnchor constant:-6],
        
        [top.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:0],
        [top.topAnchor constraintEqualToAnchor:topAnchor constant:8],
    ]];
    
    self.rb_bottomNewMsgBanner = bottom;
    self.rb_bottomNewMsgLabel = bottomLabel;
    self.rb_topUnreadBanner = top;
    self.rb_topUnreadLabel = topLabel;
    [self rb_updateUnreadBannerMasks];
}

- (void)rb_ensureUnreadBannersIfNeeded
{
    if (![NSThread isMainThread]) {
        __weak typeof(self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [wself rb_ensureUnreadBannersIfNeeded];
        });
        return;
    }
    if (self.rb_bottomNewMsgBanner != nil || self.rb_topUnreadBanner != nil) return;
    BOOL needBottom = ([self getUnreadCount] > 0);
    BOOL needTop = (RBShouldShowInitialUnreadBanner(self.rb_initialSessionUnreadCount) && !self.rb_topUnreadBannerDismissed);
    if (!needBottom && !needTop) return;
    [self rb_initUnreadBanners];
}

- (void)rb_updateUnreadBannerMasks
{
    [self rb_applyLeftRoundedMaskToView:self.rb_bottomNewMsgBanner radius:16.0];
    [self rb_applyLeftRoundedMaskToView:self.rb_topUnreadBanner radius:16.0];
}

- (void)rb_applyLeftRoundedMaskToView:(UIView *)v radius:(CGFloat)radius
{
    if (!v) return;
    CGRect b = v.bounds;
    if (CGRectIsEmpty(b)) return;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:b
                                             byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerBottomLeft)
                                                   cornerRadii:CGSizeMake(radius, radius)];
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.frame = b;
    mask.path = path.CGPath;
    v.layer.mask = mask;
}

- (void)rb_showBanner:(UIView *)v
{
    if (!v || !v.hidden) return;
    v.hidden = NO;
    [UIView animateWithDuration:0.2 animations:^{
        v.alpha = 1.0;
    }];
}

- (void)rb_hideBanner:(UIView *)v
{
    if (!v || v.hidden) return;
    [UIView animateWithDuration:0.2 animations:^{
        v.alpha = 0;
    } completion:^(BOOL finished) {
        if (finished) {
            v.hidden = YES;
        }
    }];
}

- (void)rb_updateBottomNewMsgBannerVisibility
{
    [self rb_ensureUnreadBannersIfNeeded];
    if (!self.rb_bottomNewMsgBanner || !self.rb_bottomNewMsgLabel) return;
    int n = [self getUnreadCount];
    if (n <= 0) {
        [self rb_hideBanner:self.rb_bottomNewMsgBanner];
        self.rb_newMsgDividerIndex = NSNotFound;
        self.rb_newMsgDividerAnchorFp = nil;
        [self rb_maybeUpdateDividerIndices];
        return;
    }
    BOOL over99 = n > 99;
    self.rb_bottomNewMsgLabel.text = over99 ? @"99+条新消息" : [NSString stringWithFormat:@"%d条新消息", n];
    [self rb_showBanner:self.rb_bottomNewMsgBanner];
    [self rb_maybeUpdateDividerIndices];
}

- (void)rb_updateTopUnreadBannerVisibility
{
    [self rb_ensureUnreadBannersIfNeeded];
    if (!self.rb_topUnreadBanner || !self.rb_topUnreadLabel) return;
    if (self.rb_topUnreadBannerDismissed) {
        [self rb_hideBanner:self.rb_topUnreadBanner];
        [self rb_maybeUpdateDividerIndices];
        return;
    }
    int n = self.rb_initialSessionUnreadCount;
    if (!RBShouldShowInitialUnreadBanner(n)) {
        [self rb_hideBanner:self.rb_topUnreadBanner];
        [self rb_maybeUpdateDividerIndices];
        return;
    }
    BOOL over99 = n > 99;
    self.rb_topUnreadLabel.text = over99 ? @"99+条未读消息" : [NSString stringWithFormat:@"%d条未读消息", n];
    [self rb_showBanner:self.rb_topUnreadBanner];
    [self rb_maybeUpdateDividerIndices];
}

- (void)rb_maybeUpdateDividerIndices
{
    NSInteger count = (NSInteger)[self getChattingDatasList].count;
    BOOL countChanged = (self.rb_dividerKnownListCount != count);
    BOOL needUnread = (RBShouldShowInitialUnreadBanner(self.rb_initialSessionUnreadCount) && !self.rb_topUnreadBannerDismissed);
    BOOL needNew = ([self getUnreadCount] > 0) || (self.rb_newMsgDividerAnchorFp.length > 0);
    BOOL need = countChanged;
    if (needUnread) {
        need = need || (self.rb_unreadDividerAnchorFp.length == 0) || (self.rb_unreadDividerIndex == NSNotFound);
    }
    if (needNew) {
        need = need || (self.rb_newMsgDividerAnchorFp.length == 0) || (self.rb_newMsgDividerIndex == NSNotFound);
    } else {
        need = need || (self.rb_newMsgDividerAnchorFp.length > 0) || (self.rb_newMsgDividerIndex != NSNotFound);
    }
    if (!need) return;
    [self rb_updateDividerIndicesIfNeeded];
}

- (void)rb_updateDividerIndicesIfNeeded
{
    NSArray<JSQMessage *> *list = [self getChattingDatasList];
    NSInteger count = (NSInteger)list.count;
    if (count <= 0) {
        self.rb_unreadDividerIndex = NSNotFound;
        self.rb_newMsgDividerIndex = NSNotFound;
        self.rb_unreadDividerAnchorFp = nil;
        self.rb_newMsgDividerAnchorFp = nil;
        self.rb_dividerKnownListCount = 0;
        return;
    }
    
    NSInteger oldUnreadIdx = self.rb_unreadDividerIndex;
    NSInteger oldNewIdx = self.rb_newMsgDividerIndex;
    NSInteger oldCount = self.rb_dividerKnownListCount;
    BOOL allowFullScan = (oldCount <= 0 || llabs((long long)count - (long long)oldCount) > 8 || count < oldCount);
    
    int n = [self getUnreadCount];
    BOOL needUnreadDivider = RBShouldShowInitialUnreadBanner(self.rb_initialSessionUnreadCount) && !self.rb_topUnreadBannerDismissed;
    if (!needUnreadDivider) {
        self.rb_unreadDividerAnchorFp = nil;
    } else if (self.rb_unreadDividerAnchorFp.length == 0 && self.rb_initialSessionUnreadCount < count) {
        NSInteger idx = count - self.rb_initialSessionUnreadCount;
        JSQMessage *m = (idx >= 0 && idx < count) ? list[idx] : nil;
        if (m.fingerPrintOfProtocal.length > 0) {
            self.rb_unreadDividerAnchorFp = m.fingerPrintOfProtocal;
        }
    }
    
    if (n > 0 && self.rb_newMsgDividerAnchorFp.length == 0 && n < count) {
        NSInteger idx = count - n;
        JSQMessage *m = (idx >= 0 && idx < count) ? list[idx] : nil;
        if (m.fingerPrintOfProtocal.length > 0) {
            self.rb_newMsgDividerAnchorFp = m.fingerPrintOfProtocal;
            self.rb_newMsgDividerIndex = idx;
        }
    }
    
    self.rb_unreadDividerIndex = NSNotFound;
    if (self.rb_unreadDividerAnchorFp.length > 0) {
        if (!allowFullScan && oldUnreadIdx != NSNotFound && oldUnreadIdx < count) {
            JSQMessage *m = list[oldUnreadIdx];
            if (m.fingerPrintOfProtocal.length > 0 && [m.fingerPrintOfProtocal isEqualToString:self.rb_unreadDividerAnchorFp]) {
                self.rb_unreadDividerIndex = oldUnreadIdx;
            }
        }
        if (self.rb_unreadDividerIndex == NSNotFound && !allowFullScan && oldUnreadIdx != NSNotFound) {
            NSInteger start = MAX(0, oldUnreadIdx - 60);
            NSInteger end = MIN(count - 1, oldUnreadIdx + 60);
            for (NSInteger i = start; i <= end; i++) {
                JSQMessage *m = list[i];
                if (m.fingerPrintOfProtocal.length > 0 && [m.fingerPrintOfProtocal isEqualToString:self.rb_unreadDividerAnchorFp]) {
                    self.rb_unreadDividerIndex = i;
                    break;
                }
            }
        }
        if (self.rb_unreadDividerIndex == NSNotFound) {
            for (NSInteger i = 0; i < count; i++) {
                JSQMessage *m = list[i];
                if (m.fingerPrintOfProtocal.length > 0 && [m.fingerPrintOfProtocal isEqualToString:self.rb_unreadDividerAnchorFp]) {
                    self.rb_unreadDividerIndex = i;
                    break;
                }
            }
        }
    }
    
    if (!(self.rb_newMsgDividerAnchorFp.length > 0 && self.rb_newMsgDividerIndex != NSNotFound && self.rb_newMsgDividerIndex < count)) {
        self.rb_newMsgDividerIndex = NSNotFound;
    }
    if (self.rb_newMsgDividerAnchorFp.length > 0) {
        if (!allowFullScan && oldNewIdx != NSNotFound && oldNewIdx < count) {
            JSQMessage *m = list[oldNewIdx];
            if (m.fingerPrintOfProtocal.length > 0 && [m.fingerPrintOfProtocal isEqualToString:self.rb_newMsgDividerAnchorFp]) {
                self.rb_newMsgDividerIndex = oldNewIdx;
            }
        }
        if (self.rb_newMsgDividerIndex == NSNotFound && !allowFullScan && oldNewIdx != NSNotFound) {
            NSInteger start = MAX(0, oldNewIdx - 60);
            NSInteger end = MIN(count - 1, oldNewIdx + 60);
            for (NSInteger i = start; i <= end; i++) {
                JSQMessage *m = list[i];
                if (m.fingerPrintOfProtocal.length > 0 && [m.fingerPrintOfProtocal isEqualToString:self.rb_newMsgDividerAnchorFp]) {
                    self.rb_newMsgDividerIndex = i;
                    break;
                }
            }
        }
        if (self.rb_newMsgDividerIndex == NSNotFound) {
            for (NSInteger i = 0; i < count; i++) {
                JSQMessage *m = list[i];
                if (m.fingerPrintOfProtocal.length > 0 && [m.fingerPrintOfProtocal isEqualToString:self.rb_newMsgDividerAnchorFp]) {
                    self.rb_newMsgDividerIndex = i;
                    break;
                }
            }
        }
    }
    self.rb_dividerKnownListCount = count;
    
    if (self.collectionView.window && (oldUnreadIdx != self.rb_unreadDividerIndex || oldNewIdx != self.rb_newMsgDividerIndex)) {
        if (oldUnreadIdx != NSNotFound && oldUnreadIdx < count) [self rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:oldUnreadIdx inSection:0]];
        if (self.rb_unreadDividerIndex != NSNotFound && self.rb_unreadDividerIndex < count) [self rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:self.rb_unreadDividerIndex inSection:0]];
        if (oldNewIdx != NSNotFound && oldNewIdx < count) [self rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:oldNewIdx inSection:0]];
        if (self.rb_newMsgDividerIndex != NSNotFound && self.rb_newMsgDividerIndex < count) [self rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:self.rb_newMsgDividerIndex inSection:0]];
    }
}

- (void)rb_reloadItemsImmediatelyAtIndexPaths:(NSArray<NSIndexPath *> *)paths
{
    if (paths.count == 0) return;
    if (![NSThread isMainThread]) {
        NSArray<NSIndexPath *> *ps = [paths copy];
        dispatch_async(dispatch_get_main_queue(), ^{ [self rb_reloadItemsImmediatelyAtIndexPaths:ps]; });
        return;
    }
    if (!self.collectionView.window) return;
    NSInteger cnt = (NSInteger)[self getChattingDatasList].count;
    if (cnt <= 0) return;
    NSInteger cvCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
    if (cvCount != cnt) return;
    NSMutableSet<NSIndexPath *> *valid = [NSMutableSet set];
    for (NSIndexPath *p in paths) {
        if (![p isKindOfClass:[NSIndexPath class]]) continue;
        if (p.section != 0) continue;
        if (p.item < 0 || p.item >= cnt) continue;
        [valid addObject:p];
    }
    if (valid.count == 0) return;
    NSArray<NSIndexPath *> *validPaths = [valid allObjects];
    [UIView performWithoutAnimation:^{
        [self.rb_cachedLayoutMetaByMessageKey removeAllObjects];
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView reloadItemsAtIndexPaths:validPaths];
        [self.collectionView layoutIfNeeded];
    }];
}

- (void)rb_onBottomNewMsgBannerTapped:(id)sender
{
    NSInteger oldIdx = self.rb_newMsgDividerIndex;
    [self resetUnreadCount];
    self.rb_newMsgDividerIndex = NSNotFound;
    self.rb_newMsgDividerAnchorFp = nil;
    NSInteger cnt = (NSInteger)[self getChattingDatasList].count;
    if (oldIdx != NSNotFound && oldIdx < cnt) {
        [self rb_reloadItemsImmediatelyAtIndexPaths:@[[NSIndexPath indexPathForItem:oldIdx inSection:0]]];
    } else {
        [self.collectionView.collectionViewLayout invalidateLayout];
    }
    [self rb_scrollChatToBottomAfterEnsuringLayoutAnimated:YES];
}

- (void)rb_onTopUnreadBannerTapped:(id)sender
{
    int n = self.rb_initialSessionUnreadCount;
    NSArray<JSQMessage *> *list = [self getChattingDatasList];
    NSInteger count = (NSInteger)list.count;
    if (RBShouldShowInitialUnreadBanner(n) && count > 0 && n < count) {
        NSInteger idx = MAX(0, count - n);
        NSIndexPath *path = [NSIndexPath indexPathForItem:idx inSection:0];
        __weak typeof(self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) s = wself;
            if (!s) return;
            [s.collectionView layoutIfNeeded];
            if ([s.collectionView numberOfItemsInSection:0] > idx) {
                [s.collectionView scrollToItemAtIndexPath:path atScrollPosition:UICollectionViewScrollPositionTop animated:YES];
            } else {
                [s rb_scrollChatToBottomAfterEnsuringLayoutAnimated:YES];
            }
        });
    } else {
        [self rb_scrollChatToBottomAfterEnsuringLayoutAnimated:YES];
    }
    self.rb_topUnreadBannerDismissed = YES;
    [self rb_hideBanner:self.rb_topUnreadBanner];
}

//---------------------------------------------------------------------------------------------------
#pragma mark - Initialization

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    if(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.chatType = -1;
        // 直接记录当前全局字号倍率，避免首次进入会话被误判为字号变化而触发整表 reload。
        self.rb_cachedChatGlobalFontMultiplier = [BasicTool getAppFontSizeMultiplier];
    }
    return self;
}

// @Override - 重写父类方法，实现额外的业务逻辑
- (void)autoScrollsToMostRecentMessageForInit
{
    // 仅首次进入会话时自动滚到底部，后续 viewWillAppear（如从子页面返回）不再执行，减轻主线程
    if (self.rb_didAutoScrollToBottomOnce) {
        return;
    }
    // YES表示高亮成功（高亮当前用于从搜索功能中进入到聊天界面中，从而让搜索到的消息高亮显示并自将将该条滚动到列表可视区）
    BOOL highlightOnceMessage = [self doHighlightOnceMessage];
    if (highlightOnceMessage) {
        return; // 高亮消息时 doHighlightOnceMessage 已处理滚动，无需额外操作
    }
    
    if (!self.automaticallyScrollsToMostRecentMessage) {
        return;
    }
    
    // 右滑取消返回时：ignoreOnce 为 YES，用 skipScroll 贯穿整段避免第二次滚到底部
    BOOL skipScroll = self.automaticallyScrollsToMostRecentMessage_ignoreOnce;
    if (skipScroll) {
        self.automaticallyScrollsToMostRecentMessage_ignoreOnce = NO;
    }
    // 首帧仅做一轮同步滚底，避免重复 invalidate/layout/scroll 把主线程压满。
    if (!skipScroll) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        @try {
            [UIView performWithoutAnimation:^{
                [self.view setNeedsLayout];
                [self.view layoutIfNeeded];
                [self jsq_updateCollectionViewInsets];
                if ([self.collectionView numberOfItemsInSection:0] > 0) {
                    [self scrollToBottomAnimated:NO];
                }
            }];
        } @finally {
            [CATransaction commit];
        }
        self.rb_didAutoScrollToBottomOnce = YES;
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 一些主要方法

- (void)viewDidLoad
{
    self.rb_useFloatingMorePanel = NO;  // 更多面板与表情一致，用 inputView 从底部顶起，不悬浮
    [super viewDidLoad];
    self.rb_appliedChatItemCount = -1;

    // 本地发送者id
    self.senderId = [[ClientCoreSDK sharedInstance] currentLoginUserId];
    // 本地发送者昵称
    self.senderDisplayName = @"我";
    
    // 应用自定义聊天背景
    [self applyChatBackground];

    // 两条消息之间的空白，再增大一点让列表更透气
    self.collectionView.collectionViewLayout.minimumLineSpacing = 14.0f;

    // 气泡图（6+ imageNamed + 蒙版）延后到 rb_deferredSetupAfterFirstFrame 首行，减轻 viewDidLoad 主线程压力

    // 图片处理的封装对象
    self.imagePickerWrapper = [[RBImagePickerWrapper alloc] initWithParent:self delegate:self];
    
    // 用于存放当前选定的 “@” 对象， “@” 功能仅用于群聊中
    self.atCache = [[AtModel alloc] initWith:self.toId];

    // 初始化引用功能的输入框功能封装类
    self.quote4InputWrapper = [[Quote4InputWrapper alloc] initWith:self];
    
    // 初始化消息底部时间格式化器（HH:mm），缓存避免重复创建
    self.bottomLabelTimeFormatter = [[NSDateFormatter alloc] init];
    self.bottomLabelTimeFormatter.dateFormat = @"HH:mm";
    
    // 注册通知：短视频录制成功完成后，从录制界面回来时（用于通知前一个界面——继续进行短视频的文件上传等后续处理）
    [NotificationCenterFactory shortVideoRecordComplete_ADD:self selector:@selector(shortVideoRecordComplete:)];
    // 注册通知：消息"撤回"功能中当收到撤回指令的应答
    [NotificationCenterFactory revokeCMDRecieved_ADD:self selector:@selector(revokeCMDRecievedComplete:)];
    
    // 注册通知：聊天背景变更
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onChatBackgroundChanged:)
                                                 name:kNotificationCenter_For_ChatBackgroundChanged
                                               object:nil];
    
    // 🆕 注册通知：MT61 已读回执实时通知（对方已读了我的消息 → 更新 ✓✓ 已读状态）
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onReadReceiptUpdated:)
                                                 name:@"kNotificationReadReceiptUpdated"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(rb_onVoipRecordAppended:)
                                                 name:[CallManager rb_notificationNameVoipRecordAppended]
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(rb_onVoiceTranscriptDidUpdate:)
                                                 name:RBVoiceTranscriptDidUpdateNotification
                                               object:nil];
    
    // 秒开：首帧设置（气泡+reloadData+导航栏等）由子类在 viewDidLoad 中数据就绪后立即调用 rb_deferredSetupAfterFirstFrame，不再延后到下一 Run Loop，避免首帧空列表滞后感
    
    // 已显示表情/更多时，点击输入框切回系统键盘（textViewDidBeginEditing 仅在首次成为第一响应者时触发，故需单独检测点击）
    UITapGestureRecognizer *tapToShowKeyboard = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(jsq_handleInputAreaTapWhenCustomPanelShowing:)];
    tapToShowKeyboard.numberOfTapsRequired = 1;
    tapToShowKeyboard.cancelsTouchesInView = NO;
    tapToShowKeyboard.delaysTouchesBegan = NO;
    tapToShowKeyboard.delaysTouchesEnded = NO;
    tapToShowKeyboard.delegate = self;
    [self.inputToolbar.contentView.textView addGestureRecognizer:tapToShowKeyboard];
    
    // 设置输入框最大高度为6行文字
    {
        UIFont *composerFont = self.inputToolbar.contentView.textView.font ?: MESSAGE_COMPOSER_TEXT_VIEW_DEFAULT_FONT;
        CGFloat lineHeight = composerFont.lineHeight; // 约19pt（16pt字体）
        UIEdgeInsets textInset = self.inputToolbar.contentView.textView.textContainerInset; // 默认{9,10,4,8}
        // 6行文字内容高度 + 文本框内上下边距
        CGFloat maxTextViewHeight = ceil(lineHeight * 6) + textInset.top + textInset.bottom;
        // 工具栏总高度 = 文本框高度 + 工具栏上下padding（各8pt）
        self.inputToolbar.maximumHeight = (NSUInteger)(maxTextViewHeight + 16);
    }
    
    // 配置下拉加载更新历史记录控件
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [UIColor clearColor];
    [self.refreshControl addTarget:self action:@selector(onLoadMoreHistory) forControlEvents:UIControlEventValueChanged];
    // iOS10+使用collectionView.refreshControl属性，低版本需手动添加
    if (@available(iOS 10.0, *)) {
        self.collectionView.refreshControl = self.refreshControl;
    } else {
        [self.collectionView addSubview:self.refreshControl];
    }

    // 上下滑动消息列表时让键盘/面板跟随手势平滑下移，避免 OnDrag 突然收起带来的生硬感
    self.collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    // 显式使用更柔和的减速率，让上下浏览历史消息时惯性更自然
    self.collectionView.decelerationRate = UIScrollViewDecelerationRateNormal;
    
    // 点击任意区域收起键盘/表情/更多（仅键盘或自定义 inputView 显示时生效，点击输入栏不触发）
    self.rb_dismissKeyboardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rb_dismissKeyboard)];
    self.rb_dismissKeyboardTap.cancelsTouchesInView = NO;
    self.rb_dismissKeyboardTap.delegate = self;
    [self.view addGestureRecognizer:self.rb_dismissKeyboardTap];
    // 点击消息列表区域也收起（列表区域点击易被 collectionView/scroll 抢占，单独加一份保证点击空白能关闭）
    self.rb_dismissKeyboardTapOnCollectionView = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rb_dismissKeyboard)];
    self.rb_dismissKeyboardTapOnCollectionView.cancelsTouchesInView = NO;
    self.rb_dismissKeyboardTapOnCollectionView.delegate = self;
    [self.collectionView addGestureRecognizer:self.rb_dismissKeyboardTapOnCollectionView];
    // 让滚动手势在「点击收起」失败后再识别，这样轻点对话区域会先触发收起，拖动仍正常滚动
    [self.collectionView.panGestureRecognizer requireGestureRecognizerToFail:self.rb_dismissKeyboardTapOnCollectionView];
    
    // 只读官方账号（10000、400070）：隐藏输入框，只允许查看消息
    // 客服账号（400069）保留输入框，允许发送消息
    if ([BasicTool isReadOnlyOfficialAccount:self.toId]) {
        self.inputToolbar.hidden = YES;
        self.toolbarHeightConstraint.constant = 0;
        [self.view setNeedsUpdateConstraints];
        [self.view layoutIfNeeded];
        // 调整 collectionView 底部 inset 使消息列表不留空白
        [self jsq_updateCollectionViewInsets];
    } else if (kRBChatUseTGInputBar) {
        [self rb_setupTGInputBarIfNeeded];
    }

    [self rb_mergePendingSearchJumpHighlightFingerprintIfNeeded];
}
#pragma mark - UIScrollViewDelegate（子类若实现 scrollViewDidScroll，请先调 super）

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [super scrollViewDidScroll:scrollView];
    [self rb_updateBottomNewMsgBannerVisibility];
    [self rb_updateTopUnreadBannerVisibility];
    if (scrollView == self.collectionView) {
        int n = [self getUnreadCount];
        CGFloat bottomTol = (self.chatType == CHAT_TYPE_GROUP_CHAT) ? 72.0 : 22.0;
        BOOL atBottom = [self isLastCellVisible] || [self rb_isChatScrolledToBottomApproximatelyWithTolerance:bottomTol];
        if (atBottom && n > 0) {
            NSInteger oldIdx = self.rb_newMsgDividerIndex;
            [self resetUnreadCount];
            if (oldIdx != NSNotFound) {
                NSInteger cnt = (NSInteger)[self getChattingDatasList].count;
                if (oldIdx < cnt) {
                    [self rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:oldIdx inSection:0]];
                }
            }
        } else if (atBottom && n <= 0 && self.rb_newMsgDividerAnchorFp.length > 0) {
            NSInteger oldIdx = self.rb_newMsgDividerIndex;
            self.rb_newMsgDividerAnchorFp = nil;
            self.rb_newMsgDividerIndex = NSNotFound;
            if (oldIdx != NSNotFound) {
                NSInteger cnt = (NSInteger)[self getChattingDatasList].count;
                if (oldIdx < cnt) {
                    [self rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:oldIdx inSection:0]];
                }
            }
        }
    }
    if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
        [self rb_groupChat_scrollViewDidScroll:scrollView];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
        [self rb_groupChat_scrollViewWillBeginDragging:scrollView];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [self rb_handleOlderHistoryPullReleaseForScrollView:scrollView];
    if (!decelerate) {
        [self rb_applyDeferredOlderHistoryIfNeeded];
        [self rb_refreshVisibleBubbleTimeLayouts];
    }
    if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
        [self rb_groupChat_scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self rb_applyDeferredOlderHistoryIfNeeded];
    [self rb_refreshVisibleBubbleTimeLayouts];
    if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
        [self rb_groupChat_scrollViewDidEndDecelerating:scrollView];
    }
}

- (void)rb_refreshVisibleBubbleTimeLayouts
{
    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        if ([cell isKindOfClass:[JSQMessagesCollectionViewCell class]]) {
            [(JSQMessagesCollectionViewCell *)cell rb_refreshBubbleTimeLayoutIfNeeded];
        }
    }
}

#pragma mark - TGInputBar 接入

static const CGFloat kRBTGFloatingBarBottomInset = 10.f;

- (void)rb_setupTGInputBarIfNeeded
{
    if (self.tgInputBar != nil) return;
    if (!self.inputToolbar || !self.toolbarBottomLayoutGuide) return;

    TGInputBar *bar = [[TGInputBar alloc] initWithFrame:CGRectZero];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bar];
    self.tgInputBar = bar;
    bar.tg_forwardTextDelegate = self;

    // 与原有 inputToolbar 同位置同尺寸，原栏仅参与布局、不显示
    [bar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(self.inputToolbar.mas_leading);
        make.trailing.equalTo(self.inputToolbar.mas_trailing);
        make.top.equalTo(self.inputToolbar.mas_top);
        make.bottom.equalTo(self.inputToolbar.mas_bottom);
    }];
    self.inputToolbar.alpha = 0;
    // 隐藏原悬浮条灰底 wrapper，避免输入框下方露出「原先的底部导航」灰条
    if (self.rb_floatingBarWrapperView) {
        self.rb_floatingBarWrapperView.hidden = YES;
    }
    // 底部 Home 条区域与输入栏同色，避免透出聊天背景图
    if (self.rb_toolbarBottomFillerView) {
        self.rb_toolbarBottomFillerView.backgroundColor = UI_DEFAULT_CHAT_INPUT_BAR_BG;
    }

    // 与 TGInputBar 内部单行默认总高度严格一致（勿用 minHeight+10，会与 TG 内 newBarHeight 差 5pt 导致约束打架、文字忽上忽下）
    if (self.toolbarHeightConstraint) {
        self.toolbarHeightConstraint.constant = [bar tg_preferredDefaultToolbarHeight];
        [self.view setNeedsUpdateConstraints];
    }

    __weak typeof(self) wself = self;
    bar.onSend = ^(NSString *text) {
        NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0) {
            [wself didPressSendButtonInKeybord:text];
            [wself.tgInputBar resetInput];
        }
    };
    bar.onPlusClick = ^{
        [wself rb_tgInputBar_toggleMorePanel];
    };
    bar.onEmojiClick = ^{
        [wself rb_tgInputBar_toggleFaceBoard];
    };
    bar.onVoiceClick = ^{
        [wself gotoVoiceRecord];
    };
    bar.onHeightChange = ^(CGFloat height) {
        if (!wself.toolbarHeightConstraint) return;
        // 高度未变时跳过，避免每字触发整页约束刷新；与 TG 内「高度不变不跑弹簧」一致，减轻垂直抖动
        if (fabs(wself.toolbarHeightConstraint.constant - height) < 0.5) return;
        wself.toolbarHeightConstraint.constant = height;
        [wself.view setNeedsUpdateConstraints];
        [wself jsq_updateCollectionViewInsets];
    };
    bar.onReplyPreviewClose = ^{
        if (wself.quote4InputWrapper != nil) {
            [wself.quote4InputWrapper cancelQuote:nil];
        }
    };

    // TG 输入框获焦时由我们响应键盘，更新底部约束（基类只监听原 textView）
    [[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(rb_tgInputBar_keyboardWillChangeFrame:)
                                             name:UIKeyboardWillChangeFrameNotification
                                           object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(rb_tgInputBar_keyboardDidShow:)
                                             name:UIKeyboardDidShowNotification
                                           object:nil];
}

/**
 * 系统链路说明：JSQ 在 jsq_addObservers 里对「隐藏的」inputToolbar.contentView.textView.contentSize 做了 KVO，
 * 变化时会 jsq_adjustInputToolbarHeightConstraintByDelta: 改 toolbarHeightConstraint。
 * 实际输入在 TGInputBar.textView 上时，隐藏 textView 的 contentSize 仍可能随布局波动，或与 TG 的 onHeightChange 不同步，
 * 导致 inputToolbar 高度与 TG 内 bgView/textView 高度不一致 → textView.bounds 变化 → layoutSubviews 里 textContainerInset 忽变 → 文字忽上忽下。
 * 使用 TG 时直接忽略该 KVO。
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (self.tgInputBar
        && self.inputToolbar.contentView.textView
        && object == self.inputToolbar.contentView.textView
        && [keyPath isEqualToString:NSStringFromSelector(@selector(contentSize))]) {
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

/// 覆盖基类：使用 TGInputBar 时由本类统一处理键盘，避免基类因原 textView 非 firstResponder 直接 return 导致不更新
- (void)keyboardController:(JSQMessagesKeyboardController *)keyboardController keyboardDidChangeFrame:(CGRect)keyboardFrame
{
    if (self.tgInputBar) {
        [self rb_tgInputBar_applyKeyboardFrameWithConvertedFrame:keyboardFrame
                                                 keyboardController:keyboardController];
        return;
    }
    [super keyboardController:keyboardController keyboardDidChangeFrame:keyboardFrame];
}

- (void)rb_tgInputBar_applyKeyboardFrameWithConvertedFrame:(CGRect)keyboardFrame
                                       keyboardController:(JSQMessagesKeyboardController *)keyboardController
{
    if (!self.toolbarBottomLayoutGuide) return;
    CGFloat safeBottom = (CGFloat)[BasicTool getSafeAreaInsets_bottom];
    CGFloat keyboardTopY = CGRectGetMinY(keyboardFrame);
    BOOL toHide = (keyboardTopY >= self.view.bounds.size.height - 1.0f);  // 键盘在屏外或几乎贴底视为收起
    CGFloat heightFromBottom;
    if (toHide && self.rb_useFloatingMorePanel) {
        heightFromBottom = -(CGFloat)[BasicTool getSafeAreaInsets_bottom] + kRBTGFloatingBarBottomInset;
        self.rb_tgInputBar_lastToolbarConstant = -CGFLOAT_MAX;
    } else if (!toHide) {
        // 与 JSQ 路径一致：toolbar 底对齐键盘顶（不再额外 +10pt，否则会出现输入框与键盘之间大块空白）
        heightFromBottom = (self.view.bounds.size.height - safeBottom) - keyboardTopY;
        heightFromBottom = MAX(0.0f, heightFromBottom);
        self.rb_tgInputBar_lastToolbarConstant = heightFromBottom;
    } else {
        heightFromBottom = 0;
    }

    self.toolbarBottomLayoutGuide.constant = heightFromBottom;
    [self.view setNeedsUpdateConstraints];

    NSTimeInterval duration = keyboardController.keyboardAnimationDuration;
    UIViewAnimationCurve curve = keyboardController.keyboardAnimationCurve;
    UIViewAnimationOptions options = ((NSUInteger)curve << 16) | UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:duration delay:0 options:options animations:^{
        [self.view layoutIfNeeded];
        [self jsq_updateCollectionViewInsets];
    } completion:nil];

    // 只在用户已经在看底部时才自动跟随键盘滚动到底部，不要强制覆盖用户滑动到上面看历史消息
    if (!toHide) {
        CGFloat bottomTol = (self.chatType == CHAT_TYPE_GROUP_CHAT) ? 72.0 : 22.0;
        if ([self isLastCellVisible] || [self rb_isChatScrolledToBottomApproximatelyWithTolerance:bottomTol]) {
            [self scrollToBottomAnimated:NO];
        }
    }
}

- (void)rb_tgInputBar_keyboardWillChangeFrame:(NSNotification *)notification
{
    if (!self.tgInputBar || ![self.tgInputBar.textView isFirstResponder]) return;
    NSDictionary *userInfo = notification.userInfo;
    if (!userInfo) return;
    [self rb_tgInputBar_applyKeyboardFrame:userInfo animate:YES];
}

- (void)rb_tgInputBar_keyboardDidShow:(NSNotification *)notification
{
    if (!self.tgInputBar || ![self.tgInputBar.textView isFirstResponder]) return;
    NSDictionary *userInfo = notification.userInfo;
    if (!userInfo) return;
    [self rb_tgInputBar_applyKeyboardFrame:userInfo animate:NO];
}

- (void)rb_tgInputBar_applyKeyboardFrame:(NSDictionary *)userInfo animate:(BOOL)animate
{
    if (!self.toolbarBottomLayoutGuide) return;
    NSValue *frameValue = userInfo[UIKeyboardFrameEndUserInfoKey];
    if (!frameValue) return;
    CGRect keyboardEndFrame = [frameValue CGRectValue];
    if (CGRectIsNull(keyboardEndFrame)) return;

    CGRect frameInView = [self.view convertRect:keyboardEndFrame fromView:nil];
    CGFloat safeBottom = (CGFloat)[BasicTool getSafeAreaInsets_bottom];
    CGFloat keyboardTopY = CGRectGetMinY(frameInView);
    BOOL toHide = (keyboardTopY >= self.view.bounds.size.height - 1.0f);

    CGFloat heightFromBottom;
    if (toHide && self.rb_useFloatingMorePanel) {
        heightFromBottom = -(CGFloat)[BasicTool getSafeAreaInsets_bottom] + kRBTGFloatingBarBottomInset;
    } else if (!toHide) {
        heightFromBottom = (self.view.bounds.size.height - safeBottom) - keyboardTopY;
        heightFromBottom = MAX(0.0f, heightFromBottom);
    } else {
        heightFromBottom = 0;
    }

    self.toolbarBottomLayoutGuide.constant = heightFromBottom;
    [self.view setNeedsUpdateConstraints];

    if (animate) {
        NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        UIViewAnimationCurve curve = (UIViewAnimationCurve)[userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
        UIViewAnimationOptions options = ((NSUInteger)curve << 16) | UIViewAnimationOptionBeginFromCurrentState;
        [UIView animateWithDuration:duration delay:0 options:options animations:^{
            [self.view layoutIfNeeded];
            [self jsq_updateCollectionViewInsets];
        } completion:nil];
    } else {
        [self.view layoutIfNeeded];
        [self jsq_updateCollectionViewInsets];
    }

    if (!toHide) {
        [self scrollToBottomAnimated:NO];
    }
}

- (NSString *)jsq_currentlyComposedMessageText
{
    if (self.tgInputBar) {
        return self.tgInputBar.textView.text ?: @"";
    }
    return [super jsq_currentlyComposedMessageText];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    // 基类在 viewDidLayoutSubviews 里会因「原 textView 非 firstResponder」把 toolbar 底部 constant 重置为 rest，覆盖键盘回调里设的值；此处恢复
    if (self.tgInputBar && [self.tgInputBar.textView isFirstResponder] && self.toolbarBottomLayoutGuide && self.rb_tgInputBar_lastToolbarConstant > 0) {
        self.toolbarBottomLayoutGuide.constant = self.rb_tgInputBar_lastToolbarConstant;
        [self jsq_updateCollectionViewInsets];
    }
    // 聊天背景图延伸至物理屏底：view 底部可能止于 safe area，用 constant 把背景再往下铺 safeAreaInsets.bottom
    if (self.chatBgImageViewBottomConstraint && @available(iOS 11.0, *)) {
        CGFloat bottom = self.view.safeAreaInsets.bottom;
        if (self.chatBgImageViewBottomConstraint.constant != bottom) {
            self.chatBgImageViewBottomConstraint.constant = bottom;
        }
    }
    if (self.chatBgPatternContainerBottomConstraint && @available(iOS 11.0, *)) {
        CGFloat bottom = self.view.safeAreaInsets.bottom;
        if (self.chatBgPatternContainerBottomConstraint.constant != bottom) {
            self.chatBgPatternContainerBottomConstraint.constant = bottom;
        }
    }
    [self rb_updateUnreadBannerMasks];
}

- (BOOL)jsq_shouldSkipHeavyWillAppearLayout
{
    return self.rb_hadWillDisappear && !self.rb_hadDidDisappear;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self rb_mergePendingSearchJumpHighlightFingerprintIfNeeded];
    self.rb_newMsgDividerAnchorFp = nil;
    self.rb_newMsgDividerIndex = NSNotFound;
    self.rb_unreadDividerAnchorFp = nil;
    self.rb_unreadDividerIndex = NSNotFound;

    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = @"";
    if (self.rb_chromeNavigationBar) {
        [self.view bringSubviewToFront:self.rb_chromeNavigationBar];
    }

    BOOL rbInteractivePopCancelled = (self.rb_hadWillDisappear && !self.rb_hadDidDisappear);
    // 右滑取消时：父类 JSQ viewWillAppear 曾会 invalidateLayout，导致气泡文字重排抖动；通过 jsq_shouldSkipHeavyWillAppearLayout 跳过
    if (rbInteractivePopCancelled) {
        self.automaticallyScrollsToMostRecentMessage_ignoreOnce = YES;
    }
    // 仅从子页返回时排序+reload；右滑取消返回时不排序，避免列表与布局抖动
    // （首进数据已在 loadHistory 里按时间升序排好，且 viewDidLoad 已做唯一一次 reloadData + scrollToBottom）
    if (!rbInteractivePopCancelled && self.rb_didFirstViewDidAppear) {
        [self sortCurrentSessionMessagesIfNeeded];
    }
    [super viewWillAppear:animated];

    // 基类会把 toolbarHeightConstraint 设为原 inputToolbar 高度；使用 TG 时恢复为 TG 当前算出的高度（与 onHeightChange/currentBarHeight 一致）
    if (self.tgInputBar && self.toolbarHeightConstraint) {
        self.toolbarHeightConstraint.constant = self.tgInputBar.currentBarHeight;
    }

    // 导航容器背景与聊天背景一致，避免底部或转场时露出白条（系统链路：window → nav.view → self.view）
    if (self.navigationController) {
        self.navigationController.view.backgroundColor = UI_DEFAULT_CHATTING_BG;
    }

    // 进入/返回时刷新「显示群成员昵称」缓存，供布局与 cell 使用（P0-3）
    if (self.toId.length > 0) {
        self.rb_cachedShowGroupMemberNickname = [UserDefaultsToolKits getShowGroupMemberNickname:self.toId];
    }
    
    if (self.toId.length > 0 && [CallManager rb_consumePendingScrollToBottomForChatUid:self.toId]) {
        self.rb_needRefreshAndScrollToBottomOnAppear = YES;
    }

    if (self.rb_needRefreshAndScrollToBottomOnAppear) {
        self.rb_needRefreshAndScrollToBottomOnAppear = NO;
        NSInteger listCount = (NSInteger)[self getChattingDatasList].count;
        NSInteger cvCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
        if (self.collectionView.window && listCount != cvCount) {
            [self refreshCollectionView];
        }
        [self rb_scrollChatToBottomAfterEnsuringLayoutAnimated:NO];
    }

    // 右滑返回手势取消：不执行 setTitleTextAttributes/applyChatBackground 等会触发整页重绘的逻辑，避免取消瞬间整页闪烁
    if (rbInteractivePopCancelled) {
        self.rb_hadWillDisappear = NO;
        [self jsq_refreshRightBarButtonIcon];
        [self resetLeftButton2Style];
        [self jsq_refreshLeftBarButtonIcon];
        return;
    }

    if (self.rb_chromeNavigationBar) {
        self.rb_chromeNavigationBar.titleLabel.font = [BasicTool getBoldSystemFontOfSize:16.0f];
        self.rb_chromeNavigationBar.titleLabel.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
    }

    // 刷新自定义聊天背景（从背景设置页返回时需要刷新）
    [self applyChatBackground];
    
    // 字体+气泡 layout+reload 已延后到 viewDidAppear，减轻 viewWillAppear 主线程压力
    // 漫游、@我 追踪等延后到 viewDidAppear，减轻 viewWillAppear 主线程压力，进入单聊更丝滑
    // （进页不再拉漫游；单聊已读水位查询在 viewDidAppear；@我 提示仍在 viewDidAppear 刷新）

    // 在即将显示前就刷新工具栏图标，避免进入页面时先显示 xib 默认图再闪成新图
    [self jsq_refreshRightBarButtonIcon];
    [self resetLeftButton2Style];
    [self jsq_refreshLeftBarButtonIcon];
    
    // 恢复草稿内容
    [self restoreDraft];
    self.rb_hadWillDisappear = NO;
}

// UI界面视图已经显示完成了
- (void)viewDidAppear:(BOOL)animated
{
    CFAbsoluteTime rbAppearBeginTime = CFAbsoluteTimeGetCurrent();
    [super viewDidAppear:animated];
    self.rb_viewDidAppearTime = CFAbsoluteTimeGetCurrent();
    if (!self.rb_didScheduleVoiceMeterPreload) {
        self.rb_didScheduleVoiceMeterPreload = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [IQVoiceMeterView preloadImages];
        });
    }
    
    // 右滑返回手势取消：未真正 pop，不触发漫游/已读/@我 等刷新，保持当前列表与滚动位置
    if (self.rb_hadWillDisappear && !self.rb_hadDidDisappear) {
        NSInteger listCount = (NSInteger)[self getChattingDatasList].count;
        NSInteger cvCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
        if (self.collectionView.window && listCount != cvCount) {
            CGFloat bottomTol = (self.chatType == CHAT_TYPE_GROUP_CHAT) ? 72.0 : 22.0;
            BOOL userWasAtBottom = [self isLastCellVisible]
                || [self rb_isChatScrolledToBottomApproximatelyWithTolerance:bottomTol];
            [self refreshCollectionView];
            if (userWasAtBottom) {
                [self rb_scrollChatToBottomAfterEnsuringLayoutAnimated:NO];
            }
        }
        self.rb_hadWillDisappear = NO;
        self.rb_hadDidDisappear = NO;
        return;
    }

    [self resetUnreadCount];
    [self rb_updateTopUnreadBannerVisibility];
    [self rb_updateBottomNewMsgBannerVisibility];
    
    // 首次进入只记录字号倍率缓存，不在 viewDidAppear 里做 invalidateLayout + reloadData。
    // 否则会在首帧之后立刻再打一轮整表布局，表现为“刚进会话顿一下”。
    CGFloat fontMult = [BasicTool getAppFontSizeMultiplier];
    BOOL hasCachedFontMultiplier = (self.rb_cachedChatGlobalFontMultiplier >= -0.5f);
    BOOL fontMultiplierChanged = (hasCachedFontMultiplier && fabs(fontMult - self.rb_cachedChatGlobalFontMultiplier) > 0.001f);
    if (!hasCachedFontMultiplier) {
        self.rb_cachedChatGlobalFontMultiplier = fontMult;
    }
    if (fontMultiplierChanged) {
        // 1) 先更新 FlowLayout 气泡字体重算 cell 高并 reload；2) refreshFonts 必须跳过 collectionView 子树，
        //    否则递归会改气泡 UITextView.font，与 cell 内 attributedText 字体系不一致 → 裁字/抖动。
        // 就绪条件用 deferred 或已 appear：避免仅因右滑返回取消等导致 rb_didFirstViewDidAppear 未置位而永远不刷新气泡。
        BOOL bubbleFontPipelineReady = (self.rb_didDeferredSetupFirstFrame || self.rb_didFirstViewDidAppear);
        if (bubbleFontPipelineReady && self.collectionView) {
            id layout = self.collectionView.collectionViewLayout;
            if ([layout respondsToSelector:@selector(setMessageBubbleFont:)]) {
                [self.rb_emojiAttrCache removeAllObjects];
                UIFont *chatFont = [BasicTool getSystemFontOfSize:17.0f];
                [layout setMessageBubbleFont:chatFont];
                if ([layout isKindOfClass:[JSQMessagesCollectionViewFlowLayout class]]) {
                    JSQMessagesCollectionViewFlowLayoutInvalidationContext *ctx = [JSQMessagesCollectionViewFlowLayoutInvalidationContext context];
                    ctx.invalidateFlowLayoutMessagesCache = YES;
                    [(JSQMessagesCollectionViewFlowLayout *)layout invalidateLayoutWithContext:ctx];
                }
                [self rb_invalidateChattingListLayoutCache];
                [UIView performWithoutAnimation:^{
                    [self.collectionView reloadData];
                    [self.collectionView layoutIfNeeded];
                }];
            }
        }
        [BasicTool refreshFontsForView:self.view skippingDescendantsOfView:self.collectionView];
        if (self.rb_chromeNavigationBar) {
            self.rb_chromeNavigationBar.titleLabel.font = [BasicTool getBoldSystemFontOfSize:16.0f];
            self.rb_chromeNavigationBar.titleLabel.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
        }
        self.rb_cachedChatGlobalFontMultiplier = fontMult;
    }

    if (self.rb_pendingScrollToBottomAfterVoipRecord) {
        self.rb_pendingScrollToBottomAfterVoipRecord = NO;
        [self rb_scrollChatToBottomAfterEnsuringLayoutAnimated:NO];
    }
    // 首进时恢复 collectionView 的 layer.actions，后续滚动/交互动画正常
    if (!self.rb_didFirstViewDidAppear) {
        self.collectionView.layer.actions = nil;
    }
    
    /// 进页不再执行：1008-26-8 漫游、预入库（仅复位状态避免骨架遮罩常驻）；已读仍须在单聊进页查询对方水位兜底
    self.serverHistoryFetching = NO;
    self.serverHistoryFetched = YES;
    [self roamingRestoreCollectionViewAlpha];
    [self rb_evaluateChatFirstScreenSkeletonCover];

    // 单聊：拉对方 last_read_time2。partnerLastReadTime2 仅存内存，不重进页查询则仅靠 SQLite read_by_partner，未落库/时序会导致列表返回再进仍单勾。
    if ((self.chatType == CHAT_TYPE_FREIDN_CHAT || self.chatType == CHAT_TYPE_GUEST_CHAT)
        && self.toId.length > 0
        && ![self.toId isEqualToString:@"10001"]) {
        [self queryPartnerReadReceiptBypassThrottle:YES];
    }

    // 进入会话时重建@我追踪（用于从会话列表点进来时也能看到“有人@我”提示）
    [self rebuildAtMeTrackingFromCurrentMessagesIfNeeded];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshAtMeHintVisibility];
    });

    // @选择页面返回后（当时 !isTopVisible）：统一走「resign → 插入 @昵称 → Toast」，不自动弹键盘，避免搜狗覆盖
    if (self.pendingFocusAfterAtChoose) {
        self.pendingFocusAfterAtChoose = NO;
        [self flushPendingAtUserInsertIfNeeded];
        [self jsq_refreshRightBarButtonIcon]; // 插入 @ 后可能有文字，需刷新右侧发送/语音图标
    }

    if (self.rb_needRefreshAndScrollToBottomOnAppear) {
        self.rb_needRefreshAndScrollToBottomOnAppear = NO;
        NSInteger listCountForNeedRefresh = (NSInteger)[self getChattingDatasList].count;
        NSInteger cvCountForNeedRefresh = (NSInteger)[self.collectionView numberOfItemsInSection:0];
        if (self.collectionView.window && listCountForNeedRefresh != cvCountForNeedRefresh) {
            [self refreshCollectionView];
        }
        [self rb_scrollChatToBottomAfterEnsuringLayoutAnimated:NO];
    }

    NSInteger listCount = (NSInteger)[self getChattingDatasList].count;
    NSInteger cvCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
    if (self.rb_didFirstViewDidAppear && self.collectionView.window && listCount != cvCount) {
        CGFloat bottomTol = (self.chatType == CHAT_TYPE_GROUP_CHAT) ? 72.0 : 22.0;
        BOOL userWasAtBottom = [self isLastCellVisible]
            || [self rb_isChatScrolledToBottomApproximatelyWithTolerance:bottomTol];
        [self refreshCollectionView];
        if (userWasAtBottom) {
            [self rb_scrollChatToBottomAfterEnsuringLayoutAnimated:NO];
        }
    }
    
    self.rb_hadWillDisappear = NO;
    self.rb_hadDidDisappear = NO; // 本次已完整出现，下次右滑取消时才能正确识别
    // 首帧滚到底部已改在 viewWillAppear 内用 CFRunLoopPerformBlock 在本 runloop 末尾执行，不再在 viewDidAppear 做延迟滚动，避免「先显示再更新一次才到底部」
    // 搜索进会话：预加载与首帧 layout 竞态时 viewWillAppear 内高亮可能失败；下一拍主队列再试一次（指纹已在 MessagesProvider 内按 trim+忽略大小写匹配）。
    if (!self.rb_didFirstViewDidAppear && [BasicTool trim:self.highlightOnceMsgFingerprint].length > 0) {
        NSLog(@"【RB-SEARCH-JUMP】viewDidAppear schedule async doHighlight toId=%@", self.toId ?: @"-");
        __weak typeof(self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            ChatRootViewController *s = wself;
            if (!s || [BasicTool trim:s.highlightOnceMsgFingerprint].length == 0) return;
            (void)[s doHighlightOnceMessage];
        });
    }
    NSLog(@"[ChatEnter][viewDidAppear] uid=%@ first=%d listCount=%ld cvCount=%ld cost=%.2fms",
          self.toId ?: @"",
          self.rb_didFirstViewDidAppear ? 1 : 0,
          (long)listCount,
          (long)cvCount,
          (CFAbsoluteTimeGetCurrent() - rbAppearBeginTime) * 1000.0);
    self.rb_didFirstViewDidAppear = YES; // 标记已执行过 viewDidAppear，后续从子页返回时会做气泡字体刷新
    // Just for Screen DEBUG！
    /*// 显示一个确认对话框，让用户确认是否发送该短视频
    [BasicTool areYouSureAlert:@"短视频录制完成" content:@"文件大小为：2.15MB，是否发送该短视频消息？" okBtnTitle:NSLocalizedString(@"general_ok", @"") cancelBtnTitle:NSLocalizedString(@"general_cancel", @"") parent:self okHandler:^(UIAlertAction * _Nullable action) {
    } cancelHandler:^(UIAlertAction * _Nullable action) {
    } cencelActionStyle:UIAlertActionStyleDestructive];*/
}

- (void)rb_notifyExternalOutgoingMessageAppended
{
    self.rb_needRefreshAndScrollToBottomOnAppear = YES;
}

- (void)rb_prepareForNavigationPopToViewController:(UIViewController *)toViewController reason:(NSString *)reason
{
    UIViewController *targetVC = toViewController;
    if (targetVC == nil && self.navigationController.viewControllers.count >= 2) {
        NSUInteger selfIndex = [self.navigationController.viewControllers indexOfObject:self];
        if (selfIndex != NSNotFound && selfIndex > 0) {
            targetVC = self.navigationController.viewControllers[selfIndex - 1];
        }
    }
    if (![targetVC isKindOfClass:[AlarmsViewController class]]) {
        return;
    }
    [(AlarmsViewController *)targetVC rb_prepareForUnderlyingPopDisplay];
}

// 注意：本类中的dealloc方法可能并不会被最终调用，为了实现界面退出时的清理动作，目前是借助本回调中通过（ [self isMovingFromParentViewController] || [self.navigationController isBeingDismissed]）这样的判断来实现检测页面真正的退出动作的
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.rb_hadWillDisappear = YES;

    // 恢复导航栏标题样式（与 NavigationController 默认一致）
    [self.navigationController.navigationBar setTitleTextAttributes:@{ NSFontAttributeName: [BasicTool getSystemFontOfSize:UI_DEFAULT_TITLE_FONT_SIZE],
                                                                        NSForegroundColorAttributeName: UI_DEFAULT_TITLE_FONT_COLOR }];

    [self cancelPendingAtUserInsert];

    // 保存草稿内容（在清理之前保存）
    [self saveDraft];

    // 【v11.x 新增】退出聊天窗口时强制上报最后一次已读回执（无视节流）
    // 确保退出前看到的最新消息的已读水位线被上报给服务端，用于会话列表 unread_count 归零
    [self reportReadReceiptIfNeededWithForce:YES];

    UIViewController *underlyingVC = nil;
    if (self.navigationController.viewControllers.count >= 2) {
        NSUInteger selfIndex = [self.navigationController.viewControllers indexOfObject:self];
        if (selfIndex != NSNotFound && selfIndex > 0) {
            underlyingVC = self.navigationController.viewControllers[selfIndex - 1];
        }
    }
    if ([underlyingVC isKindOfClass:[AlarmsViewController class]]) {
        [self rb_prepareForNavigationPopToViewController:underlyingVC reason:@"viewWillDisappear"];
    }

    // 本界面退出时执行清理操作
    // 注意：交互式返回开始时 isMovingFromParentViewController 可能已为 YES，但最终用户可能取消返回。
    // 真正释放聊天页相关资源（尤其 clearMessages 清空会话内存桶）必须延后到 viewDidDisappear，
    // 否则取消返回后当前页面仍在，但会话内存已被清空，后续收发消息只剩 DB 旧快照，气泡不会继续新增。
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.rb_hadDidDisappear = YES;

    if ([self isMovingFromParentViewController] || [self.navigationController isBeingDismissed]) {
        [self deallocImpl];
    }
}

// “viewDidUnload:”方法已在ios6后被废弃（且它只在系统内存低时才被调用），资源释放等工作正确的方式是放到 “dealloc:"中处理
// 250828日，本方法已废弃，见 viewWillDisappear:

#pragma mark - 自定义聊天背景

- (void)rb_ensureChatBgPatternView
{
    if (self.chatBgPatternContainerView) {
        return;
    }
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [UIColor clearColor];
    container.opaque = NO;

    UIView *solid = [[UIView alloc] init];
    solid.translatesAutoresizingMaskIntoConstraints = NO;
    solid.backgroundColor = UI_DEFAULT_CHATTING_BG;
    [container addSubview:solid];

    UIImageView *patternIv = [[UIImageView alloc] init];
    patternIv.translatesAutoresizingMaskIntoConstraints = NO;
    patternIv.contentMode = UIViewContentModeScaleAspectFill;
    patternIv.clipsToBounds = YES;
    patternIv.backgroundColor = [UIColor clearColor];
    patternIv.opaque = NO;
    /* 默认聊天叠图纹理（线稿/噪声 PNG + 底色合成）——暂关闭，后续可恢复：去掉 hidden，并恢复下方 image 赋值 */
    patternIv.hidden = YES;
#if 0
    patternIv.image = RbChatCachedComposedPatternImage();
#endif
    [container addSubview:patternIv];

    [NSLayoutConstraint activateConstraints:@[
        [solid.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [solid.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [solid.topAnchor constraintEqualToAnchor:container.topAnchor],
        [solid.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [patternIv.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [patternIv.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [patternIv.topAnchor constraintEqualToAnchor:container.topAnchor],
        [patternIv.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    self.chatBgPatternContainerView = container;
    self.chatBgPatternSolidView = solid;
    self.chatBgPatternImageView = patternIv;

    [self.view insertSubview:container belowSubview:self.collectionView];
    if (self.chatBgImageView) {
        [self.view insertSubview:container aboveSubview:self.chatBgImageView];
    }
    CGFloat bottomExtra = 0;
    if (@available(iOS 11.0, *)) {
        bottomExtra = self.view.safeAreaInsets.bottom;
    }
    self.chatBgPatternContainerBottomConstraint = [container.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:bottomExtra];
    [NSLayoutConstraint activateConstraints:@[
        [container.leadingAnchor constraintEqualToAnchor:self.collectionView.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.collectionView.trailingAnchor],
        [container.topAnchor constraintEqualToAnchor:self.collectionView.topAnchor],
        self.chatBgPatternContainerBottomConstraint,
    ]];
}

- (void)applyChatBackground
{
    // 默认：底层纯色 UIView + 上层 PNG（透明处透出纯色）；collectionView 透明
    [self rb_ensureChatBgPatternView];
    self.chatBgPatternSolidView.backgroundColor = UI_DEFAULT_CHATTING_BG;
#if 0
    self.chatBgPatternImageView.hidden = NO;
    self.chatBgPatternImageView.image = RbChatCachedComposedPatternImage();
#else
    self.chatBgPatternImageView.hidden = YES;
    self.chatBgPatternImageView.image = nil;
#endif
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.chatBgPatternContainerView.hidden = NO;

    if (self.chatBgImageView) {
        self.chatBgImageView.hidden = YES;
        self.chatBgImageView.image = nil;
    }

    NSString *currentToId = [self.toId copy];
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *bgImage = [ChatBackgroundViewController backgroundImageForChatId:currentToId];
        // 仅当用户在背景设置中为当前会话选了图时才显示图片；默认使用纯色 UI_DEFAULT_CHATTING_BG，不用 chat_bg_default 等资源图
        UIImage *imageToShow = bgImage;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) self = wself;
            if (!self) return;
            if (![currentToId isEqualToString:self.toId]) return;
            if (imageToShow) {
                BOOL isSolidPreset = [ChatBackgroundViewController isSolidColorChatBackgroundForChatId:currentToId];
                UIColor *solidTint = [ChatBackgroundViewController solidChatBackgroundColorForChatId:currentToId];

                self.collectionView.backgroundColor = [UIColor clearColor];
                if (!self.chatBgImageView) {
                    self.chatBgImageView = [[UIImageView alloc] init];
                    self.chatBgImageView.contentMode = UIViewContentModeScaleAspectFill;
                    self.chatBgImageView.clipsToBounds = YES;
                    self.chatBgImageView.translatesAutoresizingMaskIntoConstraints = NO;
                    [self.view insertSubview:self.chatBgImageView belowSubview:self.collectionView];
                    self.view.clipsToBounds = NO;
                    CGFloat bottomExtra = 0;
                    if (@available(iOS 11.0, *)) {
                        bottomExtra = self.view.safeAreaInsets.bottom;
                    }
                    self.chatBgImageViewBottomConstraint = [self.chatBgImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:bottomExtra];
                    [NSLayoutConstraint activateConstraints:@[
                        [self.chatBgImageView.leadingAnchor constraintEqualToAnchor:self.collectionView.leadingAnchor],
                        [self.chatBgImageView.trailingAnchor constraintEqualToAnchor:self.collectionView.trailingAnchor],
                        [self.chatBgImageView.topAnchor constraintEqualToAnchor:self.collectionView.topAnchor],
                        self.chatBgImageViewBottomConstraint,
                    ]];
                }

                self.chatBgImageView.image = imageToShow;
                self.chatBgImageView.hidden = NO;

                if (isSolidPreset && solidTint) {
                    self.chatBgPatternSolidView.backgroundColor = solidTint;
#if 0
                    UIImage *rawPat = [UIImage imageNamed:@"chat_bg_pattern_light"];
                    self.chatBgPatternImageView.hidden = NO;
                    self.chatBgPatternImageView.image = RbChatCompositePatternWithChatBgColor(rawPat, solidTint);
#else
                    self.chatBgPatternImageView.hidden = YES;
                    self.chatBgPatternImageView.image = nil;
#endif
                    self.chatBgPatternContainerView.hidden = NO;
                    [self.view insertSubview:self.chatBgPatternContainerView aboveSubview:self.chatBgImageView];
                } else {
                    self.chatBgPatternContainerView.hidden = YES;
                }

                if (self.rb_toolbarBottomFillerView) self.rb_toolbarBottomFillerView.backgroundColor = UI_DEFAULT_CHAT_INPUT_BAR_BG;
            } else {
                self.chatBgPatternSolidView.backgroundColor = UI_DEFAULT_CHATTING_BG;
                self.chatBgPatternContainerView.hidden = NO;
                self.collectionView.backgroundColor = [UIColor clearColor];
                self.chatBgImageView.hidden = YES;
                self.chatBgImageView.image = nil;
            }
        });
    });
}

- (void)onChatBackgroundChanged:(NSNotification *)notification
{
    NSString *chatId = notification.userInfo[@"chatId"];
    // 只处理当前聊天对象的背景变更
    if (chatId && [chatId isEqualToString:self.toId]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applyChatBackground];
        });
    }
}

// 界面退出时的清理动作
- (void)deallocImpl
{
    // 取消注册通知：短视频录制成功完成后，从录制界面回来时（用于通知前一个界面——继续进行短视频的文件上传等后续处理）
    [NotificationCenterFactory shortVideoRecordComplete_REMOVE:self];
    // 取消注册通知：消息"撤回"功能中当收到撤回指令的应答
    [NotificationCenterFactory revokeCMDRecieved_REMOVE:self];
    // 取消注册通知：导航栏未读数
    [NotificationCenterFactory refreshMainPageTotalUnread_REMOVE:self];
    // 取消注册通知：聊天背景变更
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationCenter_For_ChatBackgroundChanged object:nil];
    // 🆕 取消注册通知：已读回执相关
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kNotificationReadReceiptUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[CallManager rb_notificationNameVoipRecordAppended] object:nil];
    // TGInputBar 键盘监听
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
    
    // 重置"@"功级封装对象
    if ( ![GroupEntity isWorldChat:self.toId] && self.atCache != nil) {
        [self.atCache clean];
    }
    
    // 清理多选模式资源
    if(self.isMultiSelectMode) {
        [self exitMultiSelectMode];
    }
    self.multiSelectedFingerprints = nil;
    if(self.multiSelectToolbar) {
        [self.multiSelectToolbar removeFromSuperview];
        self.multiSelectToolbar = nil;
    }
    
    // 退出聊天界面时清空本会话内存列表（下次进入再由 SQLite 加载首屏一页）；会话内上拉可叠加多页，不在此限制总条数
    if (self.toId.length > 0) {
        [[MessagesProvider getMessageProiderInstance:self.chatType] clearMessages:self.toId];
    }
    [self rb_removeChatFirstScreenSkeleton];
}

- (void)rb_onVoipRecordAppended:(NSNotification *)n
{
    NSString *uid = n.userInfo[@"uid"];
    if (uid.length == 0 || self.toId.length == 0 || ![uid isEqualToString:self.toId]) {
        return;
    }
    self.rb_pendingScrollToBottomAfterVoipRecord = YES;
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(wself) s = wself;
        if (!s) return;
        if (!s.collectionView.window) return;
        [s refreshCollectionView];
        [s rb_scrollChatToBottomAfterEnsuringLayoutAnimated:NO];
    });
}

- (void)rb_onVoiceTranscriptDidUpdate:(NSNotification *)n
{
    if (![n.object isKindOfClass:[JSQAudioMediaItem class]]) {
        return;
    }
    JSQAudioMediaItem *item = (JSQAudioMediaItem *)n.object;
    NSArray<JSQMessage *> *list = [self getChattingDatasList];
    NSInteger idx = NSNotFound;
    for (NSInteger i = 0; i < (NSInteger)list.count; i++) {
        JSQMessage *m = list[i];
        if (m.msgType != TM_TYPE_VOICE) continue;
        if (m.media == item) {
            idx = i;
            break;
        }
    }
    if (idx == NSNotFound) {
        return;
    }
    [self.collectionView.collectionViewLayout invalidateLayout];
    NSIndexPath *ip = [NSIndexPath indexPathForItem:idx inSection:0];
    [self rb_refreshItemAtIndexPath:ip];
}

/// 与 JSQMessagesViewController `-scrollToBottomAnimated:` 内计算的目标 `contentOffset.y` 一致（复制算法，避免改动第三方 Pod）。
- (CGFloat)rb_targetContentOffsetYForScrollingToBottom
{
    UICollectionView *cv = self.collectionView;
    if (!cv || [cv numberOfSections] == 0) return 0;
    if ([cv numberOfItemsInSection:0] == 0) return 0;

    CGFloat topInset, bottomInset;
    if (@available(iOS 11.0, *)) {
        topInset = cv.adjustedContentInset.top;
        bottomInset = cv.adjustedContentInset.bottom;
    } else {
        topInset = cv.contentInset.top;
        bottomInset = cv.contentInset.bottom;
    }
    CGFloat contentHeight = cv.contentSize.height;
    CGFloat frameHeight = CGRectGetHeight(cv.bounds);
    CGFloat visibleHeight = frameHeight - topInset - bottomInset;
    BOOL contentFills = (contentHeight >= visibleHeight - 1.0f);
    CGFloat maxOffsetY = contentHeight + bottomInset - frameHeight;

    if (contentFills && maxOffsetY > -topInset) {
        return maxOffsetY;
    }
    if (contentFills) {
        return -topInset;
    }
    return 0;
}

/// 用户是否已停在「最新消息」一侧（与滚底目标一致）。用于补足 `isLastCellVisible`：末条有时未出现在 `indexPathsForVisibleItems`（气泡过高 / inset）但仍已贴底。
- (BOOL)rb_isChatScrolledToBottomApproximatelyWithTolerance:(CGFloat)tolerance
{
    CGFloat target = [self rb_targetContentOffsetYForScrollingToBottom];
    return fabs(self.collectionView.contentOffset.y - target) <= tolerance;
}

- (void)initObservers
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;

    self.chattingDatasObserver = ^(id observerble, id arg1) {
        if (![NSThread isMainThread]) {
            id o = observerble;
            id a = arg1;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (safeSelf && safeSelf.chattingDatasObserver) {
                    safeSelf.chattingDatasObserver(o, a);
                }
            });
            return;
        }
//        NSLog(@"收到聊天列表UI数据更新通知了...(observerble=%@, UpdateTypeToObserverADD=%ld, arg1=%@)", observerble, (long)UpdateTypeToObserverADD, arg1);
//
//        // 没有此行则表格的ui显示内容不会刷新哦
//        [safeSelf finishReceivingMessageAnimated:YES];
        
        if (RBChatObserverExtraHasReason(arg1, RBChatObserverReasonSqliteBootstrap)) {
            CGFloat bottomTol = (safeSelf.chatType == CHAT_TYPE_GROUP_CHAT) ? 72.0 : 22.0;
            NSInteger cvCountBeforeRefresh = (NSInteger)[safeSelf.collectionView numberOfItemsInSection:0];
            BOOL userWasAtBottom = (cvCountBeforeRefresh == 0)
                || [safeSelf isLastCellVisible]
                || [safeSelf rb_isChatScrolledToBottomApproximatelyWithTolerance:bottomTol];
            [safeSelf rb_restorePartnerReadWatermarkAndApplyToCurrentListIfNeeded];
            safeSelf.rb_shouldDeferInitialChatListReloadUntilSqliteBootstrap = NO;

            if (cvCountBeforeRefresh == 0) {
                [safeSelf refreshCollectionView];
                [safeSelf.collectionView layoutIfNeeded];
                [safeSelf rb_markChatCollectionItemCountSynced];
                if (userWasAtBottom && [BasicTool trim:safeSelf.highlightOnceMsgFingerprint].length == 0) {
                    [safeSelf rb_scrollChatToBottomAfterEnsuringLayoutAnimated:NO];
                }
            } else {
                [safeSelf finishReceivingMessageAnimated:NO forceDontScrollToBottom:!userWasAtBottom];
            }
            return;
        }

        if(arg1 != nil) {
            JSQMessage *m = (JSQMessage *)arg1;
            NSInteger updateType = [observerble isKindOfClass:[NSNumber class]] ? [(NSNumber *)observerble integerValue] : UpdateTypeToObserverUNKNOW;
            BOOL isAdd = (updateType == UpdateTypeToObserverADD);
            if (safeSelf.chatType == CHAT_TYPE_GROUP_CHAT) {
                DDLogInfo(@"[RBGroupSysTrace][UIObserver] gid=%@ updateType=%ld isAdd=%@ outgoing=%@ fp=%@ parentFp=%@ msgType=%d msg=%@ listCount=%ld cvCount=%ld",
                          safeSelf.toId,
                          (long)updateType,
                          isAdd ? @"YES" : @"NO",
                          [m isOutgoing] ? @"YES" : @"NO",
                          m.fingerPrintOfProtocal,
                          m.fingerPrintOfParent,
                          m.msgType,
                          m.text,
                          (long)[[safeSelf getChattingDatasList] count],
                          (long)[safeSelf.collectionView numberOfItemsInSection:0]);
            }

            if (updateType == UpdateTypeToObserverREMOVE) {
                [safeSelf rb_reconcileChatCollectionAfterRemoveIfNeeded];
                return;
            }

            // QoS 送达等：仅内存字段变更，对 outgoing 单行 reload，立即去掉发送中转圈
            if ([m isOutgoing] && updateType == UpdateTypeToObserverSET) {
                NSMutableArray<JSQMessage *> *list = [safeSelf getChattingDatasList];
                NSInteger idx = list ? [list indexOfObjectIdenticalTo:m] : NSNotFound;
                if (idx == NSNotFound && list) {
                    idx = [list indexOfObject:m];
                }
                if (idx != NSNotFound && safeSelf.collectionView.window != nil) {
                    @try {
                        [safeSelf rb_invalidateChattingListLayoutCache];
                        NSIndexPath *ip = [NSIndexPath indexPathForItem:idx inSection:0];
                        [UIView performWithoutAnimation:^{
                            [safeSelf.collectionView reloadItemsAtIndexPaths:@[ip]];
                        }];
                    } @catch (__unused NSException *ex) {
                        [safeSelf refreshCollectionView];
                    }
                } else {
                    [safeSelf refreshCollectionView];
                }
                return;
            }

            // 添加到聊天界面中的是"我"自已发出的消息
            if ([m isOutgoing]) {
                DDLogInfo(@"[SendTrace][ObserverOutgoing] t=%.3f fp=%@ isAdd=%@ msgType=%d listCount=%ld cvCount=%ld",
                          RBChatTraceNowMs(),
                          RBChatTraceSafeFp(m),
                          isAdd ? @"YES" : @"NO",
                          m.msgType,
                          (long)[[safeSelf getChattingDatasList] count],
                          (long)[safeSelf.collectionView numberOfItemsInSection:0]);
                // 常规发送在 putMessage 之后由 finishSendingMessageAnimated 统一 insert + 滚底 + rb_markChatCollectionItemCountSynced。
                // 此处勿再 finishReceiving：会与 finishSending 各 insert 一条（batch completion 晚于下一帧时 rb_applied 未更新），致二次插入异常或列表与数据源错位。
                // 但「通话记录」属于本地追加的 outgoing 系统消息，不走发送流程（不会触发 finishSending），需要在此处增量插入并滚底。
                if (isAdd && m.msgType == TM_TYPE_VOIP_RECORD) {
                    safeSelf.rb_pendingScrollToBottomAfterVoipRecord = YES;
                    [safeSelf finishReceivingMessageAnimated:YES forceDontScrollToBottom:NO];
                }
            } else {
//                DDLogDebug(@">>>>>>>>>>>>>>>>>> ([safeSelf getChattingDatasList].count=%ld, [self.collectionView numberOfSections]=%ld", [safeSelf getChattingDatasList].count, [safeSelf.collectionView numberOfSections]);
                
                UIScrollView *cvUnread = safeSelf.collectionView;
                CGFloat distFromBottomUnread = cvUnread.contentSize.height - cvUnread.contentOffset.y - CGRectGetHeight(cvUnread.bounds);
                CGFloat nearBottomTol = (safeSelf.chatType == CHAT_TYPE_GROUP_CHAT) ? 40.0 : 20.0;
                BOOL atBottom = (distFromBottomUnread <= nearBottomTol);
                NSInteger listCount = (NSInteger)[safeSelf getChattingDatasList].count;
                if (listCount >= 1 && !atBottom) {
                    if (isAdd) {
                        [safeSelf addUnreadCount:1];
                        NSInteger count = [safeSelf getChattingDatasList].count;
                        if (count > 0 && safeSelf.collectionView.window) {
                            [safeSelf rb_invalidateChattingListLayoutCache];
                            NSIndexPath *ip = [NSIndexPath indexPathForItem:(NSInteger)count - 1 inSection:0];
                            __weak typeof(safeSelf) wself2 = safeSelf;
                            @try {
                                [safeSelf.collectionView performBatchUpdates:^{
                                    [wself2.collectionView insertItemsAtIndexPaths:@[ip]];
                                } completion:^(__unused BOOL finished) {
                                    __strong typeof(wself2) s2 = wself2;
                                    if (!s2) return;
                                    [s2 rb_markChatCollectionItemCountSynced];
                                }];
                            } @catch (__unused NSException *ex) {
                                [safeSelf refreshCollectionView];
                            }
                        } else {
                            [safeSelf refreshCollectionView];
                        }
                    }
                } else {
                    [safeSelf finishReceivingMessageAnimated:YES];
                }
                
                // 【关键】始终检查@我消息（不管用户是否在底部）
                // 因为即使用户在底部看到了@我的消息，后续新消息也可能将其推出可见区域
                if (isAdd) {
                    NSInteger newMsgIndex = [safeSelf getChattingDatasList].count - 1;
                    // 如果是@我的消息，加入追踪列表
                    [safeSelf checkAndTrackAtMeMessage:m atIndex:newMsgIndex];
                    // 对所有新消息（包括非@我的消息）都触发延迟刷新，
                    // 因为新消息可能将之前的@我消息推出可见区域
                    [safeSelf scheduleAtMeHintRefresh];
                }
                
                // 【v11.x 新增】收到对方新消息且窗口在前台时，上报已读回执 + 刷新对方已读状态
                if (isAdd) {
                    [safeSelf reportReadReceiptIfNeeded];
                    // 同时查询对方是否已读"我"之前发出的消息（对方读了消息后回复时，需要刷新"✓✓ 已读"状态）
                    [safeSelf queryPartnerReadReceiptBypassThrottle:NO];
                }
            }
        } else {
            // arg1==nil：SyncKey 批量末尾 notifyAllObserver(UNKNOW)、loadHistory 完成通知等。原先一律 forceDontScrollToBottom:YES，
            // 会导致当前会话若用户本就贴底，整表 reload 后仍停在旧 offset，大群/多端增量时尤其明显（不像单条 ADD 会滚底）。
            // 转发 ACK 仍希望不误滚：仅当用户已在底部时才允许滚底；若在看历史则保持不动。
            CGFloat bottomTol = (safeSelf.chatType == CHAT_TYPE_GROUP_CHAT) ? 72.0 : 22.0;
            BOOL userWasAtBottom = [safeSelf isLastCellVisible]
                || [safeSelf rb_isChatScrolledToBottomApproximatelyWithTolerance:bottomTol];
            [safeSelf rb_restorePartnerReadWatermarkAndApplyToCurrentListIfNeeded];
            [safeSelf finishReceivingMessageAnimated:YES forceDontScrollToBottom:!userWasAtBottom];
        }
    };
    
    self.fileStatusChangedObserver = ^(id observerble, id arg1) {
        if (![NSThread isMainThread]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (safeSelf) {
                    [safeSelf finishSendingMessageAnimated:YES];
                }
            });
            return;
        }
        // 没有此行则表格的ui显示内容不会刷新哦
        [safeSelf finishSendingMessageAnimated:YES];
    };
}

// 返回聊天列表数据集合对象引用（本方法请在子类中实现，父类中默认返回一个空集合！）
- (NSMutableArray<JSQMessage *> *) getChattingDatasList
{
    // 本方法请在子类中实现，父类中默认返回一个空集合！
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
    return [NSMutableArray array];
}

- (void)rb_resetChattingListLayoutSnapshot
{
    self.rb_cachedChattingListForLayout = nil;
    [self.rb_cachedLayoutMetaByMessageKey removeAllObjects];
}

- (void)rb_invalidateChattingListLayoutCache {
    [self rb_resetChattingListLayoutSnapshot];
    // 强制 layout 下一轮重新计算 frame，避免 reload/insert 后仍用旧 attributes 导致气泡堆叠
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (BOOL)rb_messageCachedIsRedPacket:(JSQMessage *)message
{
    if (message.msgType == TM_TYPE_RED_PACKET) return YES;
    if (message.rb_cachedIsRedPacketNumber != nil) {
        return message.rb_cachedIsRedPacketNumber.boolValue;
    }
    NSDictionary *dict = rb_messageJSONObject(message.text);
    BOOL isRedPacket = (rb_safeStringFromJSONDict(dict, @"packet_id").length > 0);
    message.rb_cachedIsRedPacketNumber = @(isRedPacket);
    return isRedPacket;
}

- (BOOL)rb_messageCachedIsTransfer:(JSQMessage *)message
{
    if (message.msgType == TM_TYPE_TRANSFER) return YES;
    if (message.rb_cachedIsTransferNumber != nil) {
        return message.rb_cachedIsTransferNumber.boolValue;
    }
    NSDictionary *dict = rb_messageJSONObject(message.text);
    BOOL isTransfer = (dict[@"amount"] != nil && ![dict[@"amount"] isKindOfClass:[NSNull class]]);
    message.rb_cachedIsTransferNumber = @(isTransfer);
    return isTransfer;
}

- (NSString *)rb_renderCacheKeyForMessage:(JSQMessage *)message font:(UIFont *)font lineHeight:(CGFloat)lineHeight includeAtHighlight:(BOOL)includeAtHighlight
{
    NSString *fp = [BasicTool trim:message.fingerPrintOfProtocal];
    NSString *identity = (fp.length > 0 ? fp : [NSString stringWithFormat:@"%p", message]);
    return [NSString stringWithFormat:@"text_v1|%@|%.1f|%.1f|%d|%@",
            identity,
            font.pointSize,
            lineHeight,
            includeAtHighlight ? 1 : 0,
            rb_renderCacheSafeKeyText(message.text)];
}

- (NSAttributedString *)rb_renderedTextForMessage:(JSQMessage *)message
                                      bubbleFont:(UIFont *)bubbleFont
                                      lineHeight:(CGFloat)lineHeight
{
    BOOL shouldHighlightAt = (self.chatType == CHAT_TYPE_GROUP_CHAT);
    NSString *cacheKey = [self rb_renderCacheKeyForMessage:message font:bubbleFont lineHeight:lineHeight includeAtHighlight:shouldHighlightAt];
    if ([message.rb_renderContentCacheKey isEqualToString:cacheKey] && message.rb_renderContentAttributedText != nil) {
        return message.rb_renderContentAttributedText;
    }

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByCharWrapping;
    paragraphStyle.minimumLineHeight = lineHeight;
    paragraphStyle.maximumLineHeight = lineHeight;
    NSDictionary *attributes = @{
        NSFontAttributeName: bubbleFont,
        NSParagraphStyleAttributeName: paragraphStyle
    };

    NSAttributedString *emojiAttrText = nil;
    if (message.text.length > 0 && message.text.length < 2048) {
        if (!self.rb_emojiAttrCache) self.rb_emojiAttrCache = [[NSCache alloc] init];
        NSString *emojiCacheKey = [NSString stringWithFormat:@"emoji_v4_%.1f_%.0f_%@", bubbleFont.pointSize, lineHeight, message.text];
        emojiAttrText = [self.rb_emojiAttrCache objectForKey:emojiCacheKey];
        if (!emojiAttrText) {
            emojiAttrText = [EmojiUtil replaceEmojiWithPlanString:message.text attributes:attributes];
            if (emojiAttrText) {
                [self.rb_emojiAttrCache setObject:emojiAttrText forKey:emojiCacheKey];
            }
        }
    } else if (message.text.length > 0) {
        emojiAttrText = [EmojiUtil replaceEmojiWithPlanString:message.text attributes:attributes];
    }

    if (!emojiAttrText && message.text.length > 0) {
        emojiAttrText = [[NSAttributedString alloc] initWithString:message.text attributes:attributes];
    }

    NSMutableAttributedString *mutableAttr = emojiAttrText.length > 0 ? [emojiAttrText mutableCopy] : nil;
    if (mutableAttr.length > 0) {
        [mutableAttr addAttribute:NSForegroundColorAttributeName value:[UIColor blackColor] range:NSMakeRange(0, mutableAttr.length)];
    }
    NSAttributedString *finalText = mutableAttr ?: emojiAttrText;
    if (shouldHighlightAt && mutableAttr.length > 0) {
        NSString *plainText = mutableAttr.string;
        if (!self.rb_atHighlightRegex) {
            NSString *atPattern = [NSString stringWithFormat:@"%@[^%@]+%@", NIMInputAtStartChar, NIMInputAtEndChar, NIMInputAtEndChar];
            self.rb_atHighlightRegex = [NSRegularExpression regularExpressionWithPattern:atPattern options:0 error:nil];
        }
        NSArray<NSTextCheckingResult *> *matches = [self.rb_atHighlightRegex matchesInString:plainText options:0 range:NSMakeRange(0, plainText.length)];
        if (matches.count > 0) {
            UIColor *atMentionColor = HexColor(0x0078fe);
            for (NSTextCheckingResult *match in matches) {
                [mutableAttr addAttribute:NSForegroundColorAttributeName value:atMentionColor range:match.range];
            }
        }
        finalText = mutableAttr;
    }
    if (mutableAttr.length > 0) {
        NSString *plainText = mutableAttr.string ?: @"";
        NSArray<NSTextCheckingResult *> *idMatches = [RbMentionIdRegex() matchesInString:plainText options:0 range:NSMakeRange(0, plainText.length)];
        for (NSTextCheckingResult *match in idMatches) {
            if (match.numberOfRanges < 2) {
                continue;
            }
            NSRange idRange = [match rangeAtIndex:1];
            if (idRange.location == NSNotFound || NSMaxRange(idRange) > plainText.length) {
                continue;
            }
            NSString *targetId = [plainText substringWithRange:idRange];
            NSString *scheme = [self rb_shouldOpenMentionAsGroup:targetId] ? kRBMentionGroupURLScheme : kRBMentionUserURLScheme;
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", scheme, targetId]];
            if (url != nil) {
                [mutableAttr addAttribute:NSLinkAttributeName value:url range:match.range];
            }
        }
        finalText = mutableAttr;
    }

    message.rb_renderContentCacheKey = cacheKey;
    message.rb_renderContentAttributedText = finalText;
    return finalText;
}

- (BOOL)rb_shouldOpenMentionAsGroup:(NSString *)targetId
{
    NSString *trimmed = [BasicTool trim:targetId];
    if (trimmed.length == 0) {
        return NO;
    }
    GroupEntity *group = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:trimmed];
    if (group != nil) {
        return YES;
    }
    return NO;
}

- (BOOL)rb_handleMentionURL:(NSURL *)url
{
    if (url == nil) {
        return NO;
    }
    NSString *scheme = [BasicTool trim:url.scheme.lowercaseString];
    NSString *targetId = [BasicTool trim:url.host];
    if (targetId.length == 0) {
        targetId = [BasicTool trim:url.path];
        if ([targetId hasPrefix:@"/"]) {
            targetId = [targetId substringFromIndex:1];
        }
    }
    if (targetId.length == 0) {
        return NO;
    }
    if ([scheme isEqualToString:kRBMentionGroupURLScheme]) {
        [QueryGroupInfoAsync gotoWatchGroupInfo:targetId withInfo:nil nav:self.navigationController view:self.view vc:self];
        return YES;
    }
    if ([scheme isEqualToString:kRBMentionUserURLScheme]) {
        [QueryFriendInfoAsync gotoWatchUserInfo:targetId withInfo:nil nav:self.navigationController view:self.view vc:self];
        return YES;
    }
    return NO;
}

- (NSAttributedString *)rb_renderedQuoteText:(NSString *)quoteText font:(UIFont *)font cacheHost:(JSQMessage *)cacheHost
{
    NSString *cacheKey = [NSString stringWithFormat:@"quote_v1|%.1f|%@", font.pointSize, rb_renderCacheSafeKeyText(quoteText)];
    if ([cacheHost.rb_renderQuoteCacheKey isEqualToString:cacheKey] && cacheHost.rb_renderQuoteAttributedText != nil) {
        return cacheHost.rb_renderQuoteAttributedText;
    }
    NSDictionary *attributes = @{ NSFontAttributeName: font };
    NSAttributedString *attributed = [EmojiUtil replaceEmojiWithPlanString:quoteText attributes:attributes];
    if (attributed == nil && quoteText.length > 0) {
        attributed = [[NSAttributedString alloc] initWithString:quoteText attributes:attributes];
    }
    cacheHost.rb_renderQuoteCacheKey = cacheKey;
    cacheHost.rb_renderQuoteAttributedText = attributed;
    return attributed;
}

- (NSArray<JSQMessage *> *)rb_chattingListForLayout {
    return self.rb_cachedChattingListForLayout ?: [self getChattingDatasList];
}

- (NSString *)rb_layoutMetaCacheKeyForMessage:(JSQMessage *)message index:(NSInteger)index listCount:(NSInteger)listCount
{
    NSString *fp = [BasicTool trim:message.fingerPrintOfProtocal];
    if (fp.length > 0) {
        return [NSString stringWithFormat:@"%@_%ld_%ld", fp, (long)index, (long)listCount];
    }
    return [NSString stringWithFormat:@"mem_%p_%ld_%ld", (void *)message, (long)index, (long)listCount];
}

- (NSDictionary<NSString *, NSNumber *> *)rb_layoutMetaForMessageAtIndex:(NSInteger)index
{
    NSArray<JSQMessage *> *list = [self rb_chattingListForLayout];
    if (index < 0 || index >= (NSInteger)list.count) return nil;
    JSQMessage *entity = list[index];
    if (entity == nil) return nil;
    if (self.rb_cachedLayoutMetaByMessageKey == nil) {
        self.rb_cachedLayoutMetaByMessageKey = [NSMutableDictionary dictionary];
    }
    NSString *cacheKey = [self rb_layoutMetaCacheKeyForMessage:entity index:index listCount:list.count];
    NSDictionary<NSString *, NSNumber *> *cached = self.rb_cachedLayoutMetaByMessageKey[cacheKey];
    if (cached != nil) {
        return cached;
    }

    BOOL isFavoriteChat = (self.chatType == CHAT_TYPE_FREIDN_CHAT
                           && self.toId != nil
                           && [self.toId isEqualToString:@"10001"]);
    BOOL isMediaMessage = [entity isMediaMessage];
    BOOL isText = (entity.msgType == TM_TYPE_TEXT);
    BOOL isVoiceOrVoip = (entity.msgType == TM_TYPE_VOICE || entity.msgType == TM_TYPE_VOIP_RECORD);
    BOOL isSystemText = (entity.msgType == TM_TYPE_SYSTEAM_INFO || entity.msgType == TM_TYPE_REVOKE);
    BOOL isRedPacket = [self rb_messageCachedIsRedPacket:entity];
    BOOL isTransfer = [self rb_messageCachedIsTransfer:entity];
    BOOL hasQuote = (!isFavoriteChat && ![BasicTool isStringEmpty:entity.quote_content]);

    CGFloat topLabelHeight = entity.showTopTime ? kJSQMessagesCollectionViewCellLabelHeightDefault : 0.0f;

    CGFloat nicknameHeight = 0.0f;
    if (isText && !isMediaMessage && !isRedPacket && !isTransfer) {
        if (isFavoriteChat) {
            if (rb_resolvedIncomingNicknameForDisplay(entity) != nil) {
                nicknameHeight = kRBNicknameLabelHeight;
            }
        } else if (self.chatType == CHAT_TYPE_GROUP_CHAT && self.rb_cachedShowGroupMemberNickname) {
            NSInteger groupStart = [self rb_groupStartIndexForItemAtIndex:index];
            if (groupStart == index && groupStart >= 0 && groupStart < (NSInteger)list.count) {
                JSQMessage *firstMsg = list[groupStart];
                BOOL firstIsText = (firstMsg.msgType == TM_TYPE_TEXT);
                BOOL firstIsMedia = [firstMsg isMediaMessage];
                BOOL firstIsRedPacket = [self rb_messageCachedIsRedPacket:firstMsg];
                BOOL firstIsTransfer = [self rb_messageCachedIsTransfer:firstMsg];
                if (firstIsText && !firstIsMedia && !firstIsRedPacket && !firstIsTransfer
                    && rb_resolvedIncomingNicknameForDisplay(firstMsg) != nil) {
                    nicknameHeight = kRBNicknameLabelHeight;
                }
            }
        }
    }

    CGFloat bottomLabelHeight = 0.0f;
    if (entity.date != nil) {
        if (isVoiceOrVoip) {
            bottomLabelHeight = 16.0f;
        } else if (isText && !isMediaMessage && !isSystemText && !isRedPacket && !isTransfer) {
            bottomLabelHeight = 16.0f;
        }
    }

    CGFloat quoteTopGap = hasQuote ? kJSQMessagesCollectionViewCellQuoteContinerTopGapDefault : 0.0f;
    CGFloat quoteHeight = 0.0f;
    CGFloat quoteIconWidth = 0.0f;
    if (hasQuote) {
        if (entity.quote_status == 1) {
            quoteHeight = kJSQMessagesCollectionViewCellQuoteContinerHeightDefault_onlyText;
        } else {
            switch (entity.quote_type) {
                case TM_TYPE_IMAGE:
                case TM_TYPE_VOICE:
                case TM_TYPE_FILE:
                case TM_TYPE_SHORTVIDEO:
                case TM_TYPE_CONTACT:
                case TM_TYPE_LOCATION:
                    quoteHeight = kJSQMessagesCollectionViewCellQuoteContinerHeightDefault_hasIcon;
                    quoteIconWidth = kJSQMessagesCollectionViewCellQuoteIconContinerWidthDefault;
                    break;
                default:
                    quoteHeight = kJSQMessagesCollectionViewCellQuoteContinerHeightDefault_onlyText;
                    break;
            }
        }
    }

    NSDictionary<NSString *, NSNumber *> *meta = @{
        @"top": @(topLabelHeight),
        @"nickname": @(nicknameHeight),
        @"bottom": @(bottomLabelHeight),
        @"quoteTopGap": @(quoteTopGap),
        @"quoteHeight": @(quoteHeight),
        @"quoteIconWidth": @(quoteIconWidth),
    };
    self.rb_cachedLayoutMetaByMessageKey[cacheKey] = meta;
    return meta;
}

- (BOOL)rb_showGroupMemberNicknameForCurrentChat {
    return self.rb_cachedShowGroupMemberNickname;
}

- (void)refreshCollectionView {
    [self rb_invalidateChattingListLayoutCache];
    [super refreshCollectionView];
    [self rb_markChatCollectionItemCountSynced];
    [self rb_evaluateChatFirstScreenSkeletonCover];
}

/// 数据源与列表 UI 条数一致后调用（整表 reload、加载更多后）
- (void)rb_markChatCollectionItemCountSynced
{
    self.rb_appliedChatItemCount = (NSInteger)[self getChattingDatasList].count;
}

- (void)rb_reconcileChatCollectionAfterRemoveIfNeeded
{
    CGFloat bottomTol = (self.chatType == CHAT_TYPE_GROUP_CHAT) ? 72.0 : 22.0;
    BOOL userWasAtBottom = [self isLastCellVisible]
        || [self rb_isChatScrolledToBottomApproximatelyWithTolerance:bottomTol];
    [self rb_restorePartnerReadWatermarkAndApplyToCurrentListIfNeeded];
    [UIView performWithoutAnimation:^{
        [self refreshCollectionView];
        [self.collectionView layoutIfNeeded];
    }];
    if (userWasAtBottom && [BasicTool trim:self.highlightOnceMsgFingerprint].length == 0) {
        [self rb_scrollChatToBottomAfterEnsuringLayoutAnimated:NO];
    }
}

/// 用于判断是否「只追加了一条」：优先用上次的 applied，避免与数据源同时读到同一 count
- (NSInteger)rb_priorAppliedChatItemCountForIncrementalCompare
{
    if (self.rb_appliedChatItemCount >= 0) {
        return self.rb_appliedChatItemCount;
    }
    return (NSInteger)[self.collectionView numberOfItemsInSection:0];
}

/// 拉到更早历史成功或漫游写入新消息后调用，允许再次向顶部请求
- (void)rb_clearOlderHistoryExhausted
{
    self.rb_olderHistoryExhausted = NO;
    self.rb_noMoreOlderHistoryToastShown = NO;
    self.refreshControl.enabled = YES;
    self.refreshControl.attributedTitle = nil;
}

/// 本地/SQLite 与 HTTP 均无更早记录时调用；停止顶部无限 prefetch + reload。toast 仅在首次穷尽或用户未手动下拉重置前提示一次。
- (void)rb_markOlderHistoryExhaustedStoppingPrefetchWithToast:(BOOL)showToast
{
    self.rb_olderHistoryExhausted = YES;
    (void)showToast;
    self.rb_noMoreOlderHistoryToastShown = YES;
    self.refreshControl.enabled = NO;
    self.refreshControl.attributedTitle = nil;
}

/// 统一的聊天列表程序化滚动动画：比系统默认 setContentOffset(animated:) 更柔和，且支持打断当前动画平滑接续。
- (void)rb_setChatCollectionViewContentOffset:(CGPoint)targetOffset animated:(BOOL)animated
{
    UICollectionView *cv = self.collectionView;
    if (cv == nil) return;
    if (!animated) {
        [cv setContentOffset:targetOffset animated:NO];
        return;
    }

    if (fabs(cv.contentOffset.y - targetOffset.y) <= 0.5f && fabs(cv.contentOffset.x - targetOffset.x) <= 0.5f) {
        return;
    }

    [cv.layer removeAllAnimations];
    [UIView animateWithDuration:0.28
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        [cv setContentOffset:targetOffset animated:NO];
        [cv layoutIfNeeded];
    } completion:nil];
}

- (void)rb_continueSegmentedHighlightScrollToOffset:(CGPoint)targetOffset token:(NSUInteger)token deadline:(CFTimeInterval)deadline
{
    UICollectionView *cv = self.collectionView;
    if (cv == nil) return;
    if (token != self.rb_highlightScrollAnimationToken) return;

    CGFloat deltaY = targetOffset.y - cv.contentOffset.y;
    if (fabs(deltaY) <= 1.0f) {
        [cv setContentOffset:targetOffset animated:NO];
        return;
    }

    CGFloat viewportH = MAX(CGRectGetHeight(cv.bounds), 1.0f);
    CGFloat maxStep = MAX(140.0f, viewportH * 0.72f);
    CGFloat stepY = (fabs(deltaY) > maxStep) ? (cv.contentOffset.y + (deltaY > 0 ? maxStep : -maxStep)) : targetOffset.y;
    CGPoint nextOffset = CGPointMake(targetOffset.x, stepY);
    CFTimeInterval now = CACurrentMediaTime();
    NSTimeInterval remainingBudget = MAX(0.0, deadline - now);
    if (remainingBudget <= 0.001) {
        [cv setContentOffset:targetOffset animated:NO];
        return;
    }
    NSInteger segmentsRemaining = MAX(1, (NSInteger)ceil(fabs(deltaY) / maxStep));
    NSTimeInterval duration = remainingBudget / (NSTimeInterval)segmentsRemaining;
    duration = MAX(0.04, MIN(duration, remainingBudget));

    [cv.layer removeAllAnimations];
    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        [cv setContentOffset:nextOffset animated:NO];
        [cv layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (!finished) return;
        __weak typeof(self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (!sself) return;
            [sself rb_continueSegmentedHighlightScrollToOffset:targetOffset token:token deadline:deadline];
        });
    }];
}

- (void)rb_scrollChatCollectionViewContentOffsetSegmentedTo:(CGPoint)targetOffset
{
    UICollectionView *cv = self.collectionView;
    if (cv == nil) return;
    self.rb_highlightScrollAnimationToken += 1;
    [self rb_continueSegmentedHighlightScrollToOffset:targetOffset
                                                token:self.rb_highlightScrollAnimationToken
                                             deadline:(CACurrentMediaTime() + 0.24)];
}

/// 增量插入完成后滚底（拆出以避免嵌套 block 内触发 Clang「scalar expression」编译错误）
- (void)rb_scrollToBottomAfterIncrementalInsertIfNeeded:(BOOL)animated
                              forceDontScrollToBottom:(BOOL)forceDontScrollToBottom
                                             finished:(BOOL)batchFinished
{
    // batch 未完成时（布局被无效化、嵌套 updates、瞬时状态不一致等），若仍不刷新则 rb_applied 永远落后数据源，
    // 后续 finishSending/收消息会走错「listCount == prevApplied+1」分支 → 不插 cell、QoS 触发的 reload 也不对齐 → 一直转圈、再发也不出气泡；重进会话整表 reload 才恢复。
    if (!batchFinished) {
        [self rb_invalidateChattingListLayoutCache];
        [self refreshCollectionView];
        if (!forceDontScrollToBottom && self.automaticallyScrollsToMostRecentMessage && ![self jsq_isMenuVisible]) {
            [self.collectionView layoutIfNeeded];
            [self jsq_updateCollectionViewInsets];
            [self scrollToBottomAnimated:animated];
        }
        return;
    }
    [self rb_markChatCollectionItemCountSynced];
    if (forceDontScrollToBottom) return;
    if (!self.automaticallyScrollsToMostRecentMessage) return;
    if ([self jsq_isMenuVisible]) return;
    [self.collectionView layoutIfNeeded];
    [self jsq_updateCollectionViewInsets];
    [self scrollToBottomAnimated:animated];
}

- (void)rb_animateOutgoingTextBubbleAtIndexPath:(NSIndexPath *)indexPath
                                    fingerprint:(NSString *)fingerPrint
                                     retryCount:(NSInteger)retryCount
{
    NSString *fp = [BasicTool trim:fingerPrint];
    if (!indexPath || fp.length == 0) return;
    if (self.rb_animatedOutgoingTextFingerprints == nil) {
        self.rb_animatedOutgoingTextFingerprints = [NSMutableSet set];
    }
    if ([self.rb_animatedOutgoingTextFingerprints containsObject:fp]) {
        return;
    }

    UICollectionViewCell *rawCell = [self.collectionView cellForItemAtIndexPath:indexPath];
    if (![rawCell isKindOfClass:[JSQMessagesCollectionViewCell class]]) {
        if (retryCount > 0) {
            __weak typeof(self) wself = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) s = wself;
                if (!s) return;
                [s rb_animateOutgoingTextBubbleAtIndexPath:indexPath fingerprint:fp retryCount:(retryCount - 1)];
            });
        }
        return;
    }

    JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)rawCell;
    UIView *animView = rawCell;
    if (animView == nil) return;

    [self.rb_animatedOutgoingTextFingerprints addObject:fp];
    [animView.layer removeAllAnimations];
    CGFloat travel = MAX(44.f, CGRectGetHeight(cell.bounds) * 0.55f);
    animView.alpha = 1.f;
    animView.transform = CGAffineTransformMakeTranslation(0.f, travel);
    [UIView animateWithDuration:0.24
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        animView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

/// 用户点击「回到底部」或需强制对齐末条：与 Roaming reload 后逻辑一致——先失效气泡尺寸缓存并 layout，再滚底；下一 runloop 再滚一次并尝试 scrollToItem 末条，避免 contentSize 滞后导致「贴底却看不到最新一条」。
- (void)rb_scrollChatToBottomAfterEnsuringLayoutAnimated:(BOOL)animated
{
    UICollectionView *cv = self.collectionView;
    [self rb_invalidateChattingListLayoutCache];

    JSQMessagesCollectionViewFlowLayoutInvalidationContext *ctx = [JSQMessagesCollectionViewFlowLayoutInvalidationContext context];
    ctx.invalidateFlowLayoutMessagesCache = YES;
    [cv.collectionViewLayout invalidateLayoutWithContext:ctx];

    [cv layoutIfNeeded];
    [self jsq_updateCollectionViewInsets];
    [cv layoutIfNeeded];

    [self scrollToBottomAnimated:animated];

    __weak typeof(self) wself = self;
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{
        __strong typeof(wself) s = wself;
        if (!s) return;
        UICollectionView *cv2 = s.collectionView;
        [cv2 layoutIfNeeded];
        [s jsq_updateCollectionViewInsets];
        NSInteger items = [cv2 numberOfItemsInSection:0];
        if (items == 0) return;

        NSIndexPath *lastPath = [NSIndexPath indexPathForItem:items - 1 inSection:0];
        @try {
            [UIView performWithoutAnimation:^{
                [cv2 scrollToItemAtIndexPath:lastPath atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
            }];
        } @catch (__unused NSException *ex) {
        }
        [UIView performWithoutAnimation:^{
            [s scrollToBottomAnimated:NO];
        }];
    });
}

/// 发送完成：清空输入框；列表刷新尽量不用整表 reloadData（与「乐观插入 putMessage → 观察者先增量插一条」衔接，避免文本发送后二次全表布局）。
- (void)finishSendingMessageAnimated:(BOOL)animated
{
    JSQMessage *lastMessage = [[self getChattingDatasList] lastObject];
    DDLogInfo(@"[SendTrace][FinishSendingStart] t=%.3f animated=%@ lastFp=%@ listCount=%ld cvCount=%ld window=%@",
              RBChatTraceNowMs(),
              animated ? @"YES" : @"NO",
              RBChatTraceSafeFp(lastMessage),
              (long)[[self getChattingDatasList] count],
              (long)(self.collectionView ? [self.collectionView numberOfItemsInSection:0] : 0),
              self.collectionView.window ? @"YES" : @"NO");
    void (^clearComposerBlock)(void) = ^{
        UITextView *textView = self.inputToolbar.contentView.textView;
        textView.text = nil;
        textView.font = MESSAGE_COMPOSER_TEXT_VIEW_DEFAULT_FONT;
        [textView.undoManager removeAllActions];
        textView.contentOffset = CGPointZero;
        [self jsq_refreshRightBarButtonIcon];
        // 发送首帧优先，输入栏高度收口延后到下一轮主循环，
        // 避免同步触发 textViewDidChange/emoji 替换链与列表插入抢同一拍。
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:textView];
        });
    };

    NSInteger listCount = (NSInteger)[self getChattingDatasList].count;
    NSInteger cvCount = 0;
    if (self.collectionView != nil) {
        cvCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
    }

    BOOL scrollOnlyInBatchCompletion = NO;

    if (self.collectionView.window != nil && listCount > 0) {
        // 必须以「数据源条数 vs collection 已应用条数」为准：rb_applied 在首进漫游 reloadData 等路径可能未 rb_mark，仍用 prevApplied+1 会误判，走「只 reload 末行」分支，乐观 putMessage 后新气泡不插入（消息已发出、列表条数已变）。
        BOOL oneNewRowReadyForInsert = (listCount == cvCount + 1);
        if (oneNewRowReadyForInsert) {
            NSIndexPath *insertPath = [NSIndexPath indexPathForItem:listCount - 1 inSection:0];
            [self rb_resetChattingListLayoutSnapshot];
            __weak typeof(self) wself = self;
            BOOL scrollAnimated = animated;
            BOOL useFastOutgoingTextInsert = ([lastMessage isOutgoing] && lastMessage.msgType == TM_TYPE_TEXT);
            DDLogInfo(@"[SendTrace][FinishSendingInsertPrepare] t=%.3f insertItem=%ld lastFp=%@ listCount=%ld cvCount=%ld",
                      RBChatTraceNowMs(),
                      (long)insertPath.item,
                      RBChatTraceSafeFp(lastMessage),
                      (long)listCount,
                      (long)cvCount);
            @try {
                if (useFastOutgoingTextInsert) {
                    [UIView performWithoutAnimation:^{
                        [wself.collectionView insertItemsAtIndexPaths:@[insertPath]];
                        [wself.collectionView layoutIfNeeded];
                    }];
                    [self jsq_updateCollectionViewInsets];
                    [self scrollToBottomAnimated:NO];
                    [self rb_markChatCollectionItemCountSynced];
                    DDLogInfo(@"[SendTrace][FinishSendingFastTextInsert] t=%.3f lastFp=%@ listCount=%ld cvCount=%ld",
                              RBChatTraceNowMs(),
                              RBChatTraceSafeFp(lastMessage),
                              (long)[[self getChattingDatasList] count],
                              (long)[self.collectionView numberOfItemsInSection:0]);
                    if (animated) {
                        [self rb_animateOutgoingTextBubbleAtIndexPath:insertPath
                                                          fingerprint:lastMessage.fingerPrintOfProtocal
                                                           retryCount:4];
                    }
                } else {
                    // 非文本消息保持系统默认 insert 过渡。
                    [wself.collectionView performBatchUpdates:^{
                        [wself.collectionView insertItemsAtIndexPaths:@[insertPath]];
                    } completion:^(BOOL finished) {
                        __strong typeof(wself) s = wself;
                        if (s == nil) return;
                        DDLogInfo(@"[SendTrace][FinishSendingInsertCompletion] t=%.3f finished=%@ lastFp=%@ listCount=%ld cvCount=%ld",
                                  RBChatTraceNowMs(),
                                  finished ? @"YES" : @"NO",
                                  RBChatTraceSafeFp([[s getChattingDatasList] lastObject]),
                                  (long)[[s getChattingDatasList] count],
                                  (long)[s.collectionView numberOfItemsInSection:0]);
                        [s rb_scrollToBottomAfterIncrementalInsertIfNeeded:scrollAnimated forceDontScrollToBottom:NO finished:finished];
                    }];
                }
                clearComposerBlock();
                scrollOnlyInBatchCompletion = YES;
            } @catch (__unused NSException *ex) {
                DDLogInfo(@"[SendTrace][FinishSendingInsertCatchRefresh] t=%.3f lastFp=%@",
                          RBChatTraceNowMs(),
                          RBChatTraceSafeFp(lastMessage));
                clearComposerBlock();
                [self refreshCollectionView];
            }
        } else if (listCount == cvCount && cvCount > 0) {
            DDLogInfo(@"[SendTrace][FinishSendingReloadLastItem] t=%.3f lastFp=%@ listCount=%ld cvCount=%ld",
                      RBChatTraceNowMs(),
                      RBChatTraceSafeFp(lastMessage),
                      (long)listCount,
                      (long)cvCount);
            [self rb_resetChattingListLayoutSnapshot];
            NSIndexPath *lastPath = [NSIndexPath indexPathForItem:cvCount - 1 inSection:0];
            [UIView performWithoutAnimation:^{
                [self.collectionView reloadItemsAtIndexPaths:@[lastPath]];
            }];
            clearComposerBlock();
        } else {
            DDLogInfo(@"[SendTrace][FinishSendingRefreshAll] t=%.3f lastFp=%@ listCount=%ld cvCount=%ld",
                      RBChatTraceNowMs(),
                      RBChatTraceSafeFp(lastMessage),
                      (long)listCount,
                      (long)cvCount);
            clearComposerBlock();
            [self refreshCollectionView];
        }
    } else {
        DDLogInfo(@"[SendTrace][FinishSendingRefreshAllNoWindow] t=%.3f lastFp=%@ listCount=%ld cvCount=%ld",
                  RBChatTraceNowMs(),
                  RBChatTraceSafeFp(lastMessage),
                  (long)listCount,
                  (long)cvCount);
        clearComposerBlock();
        [self refreshCollectionView];
    }

    if (self.automaticallyScrollsToMostRecentMessage && !scrollOnlyInBatchCompletion) {
        [self.collectionView layoutIfNeeded];
        [self jsq_updateCollectionViewInsets];
        [self scrollToBottomAnimated:animated];
    }
    if (!scrollOnlyInBatchCompletion) {
        [self rb_markChatCollectionItemCountSynced];
    }
    DDLogInfo(@"[SendTrace][FinishSendingEnd] t=%.3f scrollOnlyInCompletion=%@ lastFp=%@ listCount=%ld cvCount=%ld",
              RBChatTraceNowMs(),
              scrollOnlyInBatchCompletion ? @"YES" : @"NO",
              RBChatTraceSafeFp([[self getChattingDatasList] lastObject]),
              (long)[[self getChattingDatasList] count],
              (long)(self.collectionView ? [self.collectionView numberOfItemsInSection:0] : 0));
}

/// 收到消息并在底部展示时：若数据源恰好多 1 条且在窗口上，则用 insertItems 代替整表 reloadData + 清空全部气泡缓存；插入走系统动画以保顺滑。
- (void)finishReceivingMessageAnimated:(BOOL)animated forceDontScrollToBottom:(BOOL)forceDontScrollToBottom
{
    self.showTypingIndicator = NO;

    NSInteger listCount = (NSInteger)[self getChattingDatasList].count;
    NSInteger cvCount = 0;
    if (self.collectionView != nil) {
        cvCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
    }

    BOOL useIncremental = (!forceDontScrollToBottom
                           && listCount > 0
                           && listCount == cvCount + 1
                           && self.collectionView.window != nil);

    if (useIncremental) {
        NSIndexPath *insertPath = [NSIndexPath indexPathForItem:listCount - 1 inSection:0];
        [self rb_resetChattingListLayoutSnapshot];
        __weak typeof(self) wself = self;
        BOOL scrollAnimated = animated;
        CGFloat bottomTol = (self.chatType == CHAT_TYPE_GROUP_CHAT) ? 72.0 : 22.0;
        BOOL atBottomBeforeInsert = [self isLastCellVisible] || [self rb_isChatScrolledToBottomApproximatelyWithTolerance:bottomTol];
        BOOL noScrollForced = forceDontScrollToBottom || !atBottomBeforeInsert;
        @try {
            // 不使用 performWithoutAnimation：保留 UICollectionView 默认 insert 过渡，贴近微信式「内容上顶」
            [wself.collectionView performBatchUpdates:^{
                [wself.collectionView insertItemsAtIndexPaths:@[insertPath]];
            } completion:^(BOOL finished) {
                __strong typeof(wself) s = wself;
                if (s == nil) return;
                [s rb_scrollToBottomAfterIncrementalInsertIfNeeded:scrollAnimated
                                           forceDontScrollToBottom:noScrollForced
                                                          finished:finished];
            }];
            return;
        } @catch (__unused NSException *ex) {
            /* 回退整表刷新 */
        }
    }

    [super finishReceivingMessageAnimated:animated forceDontScrollToBottom:forceDontScrollToBottom];
}

/**
 * 加载更多历史记录（下拉刷新触发）→ 已迁至 ChatRootViewController+MessageList
 */

- (NSString *)avatarFileNameForSourceUidInFavorites:(NSString *)uid {
    return nil;
}

//---------------------------------------------------------------------------------------------------
#pragma mark - JSQMessages CollectionView DataSource（JSQMessagesViewController的聊天列表UI构建相关实现主法，在这里实现数据的准备等）

- (JSQMessage *)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray<JSQMessage *> *list = [self rb_chattingListForLayout];
    JSQMessage *entity = (indexPath.item < (NSInteger)list.count) ? list[indexPath.item] : nil;
    if (!entity) {
        DDLogWarn(@"[ChatDataSource] messageDataForItemAtIndexPath out-of-range index=%ld listCount=%ld cvCount=%ld",
                  (long)indexPath.item,
                  (long)list.count,
                  (long)[collectionView numberOfItemsInSection:indexPath.section]);
        __weak typeof(self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (!sself) return;
            NSInteger listCount = (NSInteger)[sself getChattingDatasList].count;
            NSInteger cvCount = (NSInteger)[sself.collectionView numberOfItemsInSection:0];
            if (listCount != cvCount) {
                [sself rb_reconcileChatCollectionAfterRemoveIfNeeded];
            }
        });

        JSQMessage *fallback = [list lastObject];
        if (fallback != nil) {
            return fallback;
        }

        JSQMessage *placeholder = [[JSQMessage alloc] initWithSenderId:self.senderId
                                                     senderDisplayName:self.senderDisplayName
                                                                  date:[NSDate date]
                                                                  text:@""
                                                             andIsCome:NO];
        placeholder.msgType = TM_TYPE_SYSTEAM_INFO;
        return placeholder;
    }

    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak ChatRootViewController *safeSelf = self;

    // 如果是图片消息
    if(entity.msgType == TM_TYPE_IMAGE)
    {
        // media为nil表示还没有加载过多媒体数据、isLoadComplete为NO表示虽然media已创建
        // 但它的内容物还没有加载完成（给它再次创建media的机会，从而即时刷新UI显示）
        if(entity.media == nil || entity.media.loadComplete == NO)
        {
            JSQPhotoMediaItem *photoItem = [[JSQPhotoMediaItem alloc] initWithImage:nil];
            
            UIImage *image = nil;
            NSString *imgName = entity.text;
            // 列表气泡：下载预览档（savePreviewJpegMaxEdge：pv_ + 原文件名，长边≤1280、保持宽高比，非强制正方形）；全图仅在统一浏览器/保存等（getImageMessageDownloadURL）
            NSString *fullDownloadPath = [SendImageHelper getImageDownloadURL:imgName dump:NO];
            NSString *previewDownloadPath = [SendImageHelper getImageDownloadURL:[NSString stringWithFormat:@"pv_%@", imgName] dump:NO];

            image = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:previewDownloadPath];
            if (image == nil) {
                image = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:fullDownloadPath];
            }

            // 内存未命中时，把磁盘缓存/本地文件读取放到后台，只有 miss 后才继续走网络。
            if (image == nil) {
                photoItem.loadComplete = YES;
                __weak JSQPhotoMediaItem *weakPhotoItem = photoItem;
                __weak JSQMessage *weakEntity = entity;
                [self rb_loadLocalImageInBackgroundForImageWithImgName:imgName
                                                   previewDownloadPath:previewDownloadPath
                                                      fullDownloadPath:fullDownloadPath
                                                               msgType:entity.msgType
                                                                   tag:@"图片消息"
                                                             photoItem:photoItem
                                                             indexPath:indexPath
                                                                onMiss:^{
                    JSQPhotoMediaItem *strongPhotoItem = weakPhotoItem;
                    JSQMessage *strongEntity = weakEntity;
                    __weak ChatRootViewController *wself = safeSelf;
                    if (!wself || !strongPhotoItem || !strongEntity) return;
                    [FileDownloadHelper loadChattingImgWithURL:previewDownloadPath logTag:@"图片消息" complete:^(BOOL sucess, UIImage *imageDlownload) {
                        void (^finishDecodeAndRefresh)(UIImage *) = ^(UIImage *srcImg) {
                            __weak ChatRootViewController *wself2 = wself;
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                UIImage *decoded = [wself2 rb_forceDecodeImage:srcImg];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (!wself2 || !strongPhotoItem) return;
                                    [strongPhotoItem setImage:(decoded ?: srcImg)];
                                    strongPhotoItem.loadComplete = YES;
                                    NSInteger idx = [[wself2 getChattingDatasList] indexOfObject:strongEntity];
                                    if (idx != NSNotFound) {
                                        [wself2 rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:idx inSection:0]];
                                    }
                                });
                            });
                        };
                        if (sucess && imageDlownload != nil) {
                            finishDecodeAndRefresh(imageDlownload);
                        } else {
                            DDLogWarn(@"【图片消息】预览档失败，回退全图下载 %@", fullDownloadPath);
                            [FileDownloadHelper loadChattingImgWithURL:fullDownloadPath logTag:@"图片消息-全图回退" complete:^(BOOL sucess2, UIImage *img2) {
                                if (sucess2 && img2 != nil) {
                                    finishDecodeAndRefresh(img2);
                                } else {
                                    strongPhotoItem.image = [UIImage imageNamed:@"common_default_img_no_border_fail_120dp"];
                                    strongPhotoItem.loadComplete = NO;
                                    DDLogWarn(@"【图片消息】预览档与全图均失败");
                                    NSInteger idx = [[safeSelf getChattingDatasList] indexOfObject:strongEntity];
                                    if (idx != NSNotFound) {
                                        [safeSelf rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:idx inSection:0]];
                                    }
                                }
                            }];
                        }
                    }];
                }];
            }
            
            // 如果图片已读取到则直接显示之
            if(image != nil) {
//              photoItem = [[JSQPhotoMediaItem alloc] initWithImage:image];
                photoItem.image = image;

                // 设置此标识，保证下次刷新被刷新时，不需要再次走UIImage加载的过程，使得列表显示更高效顺滑
                photoItem.loadComplete = YES;

                // 【关键修复】同步更新 entity.media：performBatchUpdates 增量插入时 cellForItemAtIndexPath 不会立即被调用，
                // entity.media 仍为 nil，导致 cell 复用时走 entity.media != nil 分支但里无 image，致占位图。
                // 更新 entity.media 后，即使是延迟创建 cell，entity.media 也已指向有 image 的 photoItem，显示正常。
                entity.media = photoItem;
            } else {
                // image == nil 时走下载路径，仅在此时设置 entity.media（photoItem.image 将在异步回调里设置）
                entity.media = photoItem;
            }
            
            // 如果是收到的图片消息
            if(![entity isOutgoing])
            {
                // 没有此行代码则气泡的箭头方向会错误哦
                photoItem.appliesMediaViewMaskAsOutgoing = NO;
            }
            
            // 保存起来，下次就不需要再加载了
            // entity.media 已在 if/else 分支内设置，此处不再重复赋值
            // 不再在此处统一 dispatch_async 刷新：缓存命中时当前 cell 已带图，再 reload 会导致气泡闪烁；异步加载会在完成回调里 rb_refreshItemAtIndexPath
        }
    }
    else if(entity.msgType == TM_TYPE_VOICE)
    {
        NSString *audioFileName = entity.text;

        // 没有加载过多媒体数据
        if(entity.media == nil)
        {
            JSQAudioMediaItem *audioItem = [[JSQAudioMediaItem alloc] initWithData:audioFileName];
            // 是“我”收到的语音留言消息
            if(![entity isOutgoing])
                audioItem.appliesMediaViewMaskAsOutgoing = NO; // 默认值是YES
            entity.media = audioItem;
        }

        return entity;//m;
    }
    // 发出或收到的大文件消息
    else if(entity.msgType == TM_TYPE_FILE)
    {
        // 文件消息中的消息内容存放的是FileMeta对象的JSON字串形式
        FileMeta *fileMeta = [FileMeta fromJSON:entity.text];

        // 没有加载过多媒体数据
        if(entity.media == nil)
        {
            rbFileMediaItem *fileItem = [[rbFileMediaItem alloc] initWithData:fileMeta];
            // 是“我”收到的消息
            if(![entity isOutgoing])
                fileItem.appliesMediaViewMaskAsOutgoing = NO; // 默认值是YES
            entity.media = fileItem;
        }
        
        // 针对发出的大文件消息，及时刷新上传进度条的显示
        if([entity isOutgoing])
        {
            [((rbFileMediaItem *)entity.media) refreshUploadProgress:entity.sendStatusSecondary sendStatusSecondaryProgress:entity.sendStatusSecondaryProgress];
        }

        return entity;
    }
    // 如果是短视频消息
    else if(entity.msgType == TM_TYPE_SHORTVIDEO)
    {
        // media为nil表示还没有加载过多媒体数据、isLoadComplete为NO表示虽然media已创建
        // 但它的内容物还没有加载完成（给它再次创建media的机会，从而即时刷新UI显示）
        if(entity.media == nil || entity.media.loadComplete == NO)
        {
            // 漫游/SQLite 中文本可能与服务端字段略有差异；与 MessagesProvider 历史解析保持一致
            NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(entity.text);
            if (jsonUse.length == 0) {
                jsonUse = entity.text;
            }
            FileMeta *fileMeta = [FileMeta fromJSON:jsonUse];
            
            JSQVideoMediaItem *photoItem = [[JSQVideoMediaItem alloc] initWithData:fileMeta previewImage:[UIImage imageNamed:@"default_short_video_thumb"]];
            
            UIImage *image = nil;
            NSString *fileName = fileMeta.fileName;
            NSString *fileMd5 = fileMeta.fileMd5;
            if (fileName.length > 0 && fileMd5.length > 0) {
                NSString *imgLocalSavedName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:fileName];
                NSString *fileDownloadPath = [ReceivedShortVideoHelper getShortVideoThumbDownloadURL:imgLocalSavedName videofileMd5:fileMd5];
                
                image = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:fileDownloadPath];

                // 我方发出的消息：先走内存，未命中时后台回源本地/磁盘，miss 后再 HTTP 拉预览图。
                if (image == nil) {
                    photoItem.loadComplete = YES;
                    __weak JSQVideoMediaItem *weakPhotoItem = photoItem;
                    __weak JSQMessage *weakEntity = entity;
                    [self rb_loadLocalImageInBackgroundForShortVideoWithPreviewName:imgLocalSavedName fileDownloadPath:fileDownloadPath msgType:entity.msgType tag:@"短视频首帧预览图" photoItem:photoItem indexPath:indexPath onMiss:^{
                        JSQVideoMediaItem *strongPhotoItem = weakPhotoItem;
                        JSQMessage *strongEntity = weakEntity;
                        __weak ChatRootViewController *wself = safeSelf;
                        if (!wself || !strongPhotoItem || !strongEntity) return;
                        [FileDownloadHelper loadChattingShortVideoPreviewImgWithURL:fileDownloadPath logTag:@"短视频消息" complete:^(BOOL sucess, UIImage *imageDlownload) {
                            if (sucess && imageDlownload != nil) {
                                __weak ChatRootViewController *wself2 = wself;
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                    UIImage *decoded = [wself2 rb_forceDecodeImage:imageDlownload];
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        if (!wself2 || !strongPhotoItem) return;
                                        if (decoded) strongPhotoItem.image = decoded; else strongPhotoItem.image = imageDlownload;
                                        strongPhotoItem.loadComplete = YES;
                                        NSInteger idx = [[wself2 getChattingDatasList] indexOfObject:strongEntity];
                                        if (idx != NSNotFound) {
                                            [wself2 rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:idx inSection:0]];
                                        }
                                    });
                                });
                            } else {
                                strongPhotoItem.loadComplete = NO;
                                NSInteger idx = [[safeSelf getChattingDatasList] indexOfObject:strongEntity];
                                if (idx != NSNotFound) {
                                    [safeSelf rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:idx inSection:0]];
                                }
                            }
                        }];
                    }];
                }
            }
        
            if (image != nil) {
                photoItem.image = image;
                photoItem.loadComplete = YES;
            }
            
            if(![entity isOutgoing]) {
                photoItem.appliesMediaViewMaskAsOutgoing = NO;
            }
            
            entity.media = photoItem;
        }
        
        // 如果是发出的短视频消息则即时刷新可能的文件上传进度显示（ios特有的那种圆形进度条）
        if([entity isOutgoing]) {
            // 针对发出的短视频文件消息，及时刷新上传进度条的显示
            [((JSQVideoMediaItem *)entity.media) refreshUploadProgress:entity.sendStatusSecondary sendStatusSecondaryProgress:entity.sendStatusSecondaryProgress];
        }
    }
    // 发出或收到的名片消息
    else if(entity.msgType == TM_TYPE_CONTACT)
    {
        // 名片消息中的消息内容存放的是ContactMeta对象的JSON字串形式
        ContactMeta *contactMeta = [ContactMeta fromJSON:entity.text];
    
        // media为nil表示还没有加载过多媒体数据、isLoadComplete为NO表示虽然media已创建
        // 但它的内容物还没有加载完成（给它再次创建media的机会，从而即时刷新UI显示）
        if(entity.media == nil || entity.media.loadComplete == NO)
        {
            int contactType = contactMeta.type;
            NSString *defaultImgName = (contactType == CONTACT_TYPE_USER ? @"chat_avatar_default" : @"groupchat_groups_icon_default");
            rbContactMediaItem *contactItem = [[rbContactMediaItem alloc] initWithData:contactMeta];
            
            // 设置此标识，保证下次刷新被刷新时，不需要再次走UIImage加载的过程，使得列表显示更高效顺滑
            contactItem.loadComplete = YES;
            
            // 加载名片消息上的头像
            if(contactMeta.uid != nil)
            {
                void (^completionBlock)(BOOL, UIImage *) = ^(BOOL sucess, UIImage *img){
                    if(sucess) {
                        [contactItem setImage:(img == nil?[UIImage imageNamed:defaultImgName]:img)];
                        contactItem.loadComplete = YES;
                    } else {
                        [contactItem setImage:[UIImage imageNamed:defaultImgName]];
                        contactItem.loadComplete = NO;
                    }
                    NSInteger idx = [[safeSelf getChattingDatasList] indexOfObject:entity];
                    if (idx != NSNotFound) {
                        [safeSelf rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:idx inSection:0]];
                    }
                };
                
                // 如果是"个人名片"消息
                if(contactType == CONTACT_TYPE_USER) {
                    // 加载用户头像  // TODO: 后绪版本或可参考消息引用ui的显示，直接使用sd_setImageWithURL方法进行图片的下载、缓存和显示
                    [FileDownloadHelper loadUserAvatarWithUID:contactMeta.uid logTag:@"ChatRootViewControler-UID" complete:completionBlock donotLoadFromDisk:NO];// 优先从磁盘缓存读取，打开即显示；后台异步拉取最新头像更新
                } else {
                    // 尝试为群组加载群头像
                    [FileDownloadHelper loadGroupAvatar:contactMeta.uid logTag:@"ChatRootViewControler" complete:completionBlock];
                }
            } else {
                [contactItem setImage:[UIImage imageNamed:defaultImgName]];
            }
            
            // 是“我”收到的消息
            if(![entity isOutgoing])
                contactItem.appliesMediaViewMaskAsOutgoing = NO; // 默认值是YES
            entity.media = contactItem;
        }

        return entity;
    }
    // 如果是位置消息
    else if(entity.msgType == TM_TYPE_LOCATION)
    {
        // 位置消息中的消息内容存放的是LocationMeta对象的JSON字串形式
        LocationMeta *locationMeta = [LocationMeta fromJSON:entity.text];
        
        NSString *prewviewImgFileName = locationMeta.prewviewImgFileName;
        // 经度
        double longitude = locationMeta.longitude;
        // 纬度
        double latitude = locationMeta.latitude;
        
        // media为nil表示还没有加载过多媒体数据、isLoadComplete为NO表示虽然media已创建
        // 但它的内容物还没有加载完成（给它再次创建media的机会，从而即时刷新UI显示）
        if(entity.media == nil || entity.media.loadComplete == NO)
        {
            rbLocationMediaItem *locationItem = [[rbLocationMediaItem alloc] initWithData:locationMeta];
            // 默认显示一个占位图片
            [locationItem setImage:[UIImage imageNamed:@"chatting_location_preview_default"]];
            
            UIImage *image = nil;
            
            NSString *fileDownloadPath = nil;
            // 预览图文件名为空这种情况主要是Web产品发过来的消息，因为web不像app产品可以本地截预览图
            if([BasicTool isStringEmpty:prewviewImgFileName])
                fileDownloadPath = [LocationUtils getPreviewImageDownloadURL2:longitude lat:latitude];
            else
                fileDownloadPath = [LocationUtils getPreviewImageDownloadURL:prewviewImgFileName dump:NO];
            
            if (image == nil) {
                image = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:fileDownloadPath];
            }
            
            // 如果仍未读取到，则再接着从网络读取
            if(image == nil)
            {
                // 设置此标识，保证下次刷新被刷新时，不需要再次走UIImage加载的过程，使得列表显示更高效顺滑
                locationItem.loadComplete = YES;

                __weak rbLocationMediaItem *weakLocationItem = locationItem;
                __weak JSQMessage *weakEntity = entity;
                [self rb_loadLocalImageInBackgroundForLocationPreviewName:prewviewImgFileName fileDownloadPath:fileDownloadPath msgType:entity.msgType tag:@"位置预览图" locationItem:locationItem indexPath:indexPath onMiss:^{
                    rbLocationMediaItem *strongLocationItem = weakLocationItem;
                    JSQMessage *strongEntity = weakEntity;
                    __weak ChatRootViewController *wself = safeSelf;
                    if (!wself || !strongLocationItem || !strongEntity) return;
                    [FileDownloadHelper loadChattingImgWithURL:fileDownloadPath logTag:@"位置消息" complete:^(BOOL sucess, UIImage *imageDlownload) {
                        if (sucess && imageDlownload != nil) {
                            __weak ChatRootViewController *wself2 = wself;
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                UIImage *decoded = [wself2 rb_forceDecodeImage:imageDlownload];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (!wself2 || !strongLocationItem) return;
                                    [strongLocationItem setImage:(decoded ?: imageDlownload)];
                                    strongLocationItem.loadComplete = YES;
                                    NSInteger idx = [[wself2 getChattingDatasList] indexOfObject:strongEntity];
                                    if (idx != NSNotFound) {
                                        [wself2 rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:idx inSection:0]];
                                    }
                                });
                            });
                        } else {
                            strongLocationItem.loadComplete = NO;
                            NSInteger idx = [[safeSelf getChattingDatasList] indexOfObject:strongEntity];
                            if (idx != NSNotFound) {
                                [safeSelf rb_refreshItemAtIndexPath:[NSIndexPath indexPathForItem:idx inSection:0]];
                            }
                        }
                    }];
                }];
                
                // 设置此标识，保证下次刷新被刷新时，不需要再次走UIImage加载的过程，使得列表显示更高效顺滑
//              photoItem.loadComplete = YES;
            }
            
            // 如果图片已读取到则直接显示之
            if(image != nil) {
                locationItem.image = image;

                // 设置此标识，保证下次刷新被刷新时，不需要再次走UIImage加载的过程，使得列表显示更高效顺滑
                locationItem.loadComplete = YES;
            }
            
            if(![entity isOutgoing])
                locationItem.appliesMediaViewMaskAsOutgoing = NO;
            
            entity.media = locationItem;
            // 不再此处统一 dispatch_async 刷新，避免气泡闪烁；异步加载在完成回调里 rb_refreshItemAtIndexPath
        }
    }
    // 实时音视频聊天记录消息 → 解析 VoipRecordMeta 并友好显示（图标在 cellForItemAtIndexPath 中用 SF Symbol 渲染）
    else if(entity.msgType == TM_TYPE_VOIP_RECORD) {
        // ★ 优先从缓存的 voipRecordMeta 读取；否则从 text（客户端简版或服务端 _cancelled JSON）解析并缓存
        VoipRecordMeta *vrm = entity.voipRecordMeta;
        if (vrm == nil && entity.text != nil && [entity.text hasPrefix:@"{"]) {
            vrm = [VoipRecordMeta fromJSON:entity.text];
            if (vrm == nil) vrm = [VoipRecordMeta fromServerCancelledJSON:entity.text]; // 服务端取消兜底格式
            entity.voipRecordMeta = vrm;
        }
        
        if (vrm != nil) {
            NSString *typeStr = (vrm.voipType == VOIP_TYPE_VIDEO) ? @"视频通话" : @"语音通话";
            NSString *statusStr = @"";
            switch (vrm.recordType) {
                case VOIP_RECORD_TYPE_REQUEST_CANCEL:
                    statusStr = [entity isOutgoing] ? @"已取消" : @"对方已取消";
                    break;
                case VOIP_RECORD_TYPE_REQUEST_REJECT:
                    statusStr = [entity isOutgoing] ? @"对方已拒绝" : @"已拒绝";
                    break;
                case VOIP_RECORD_TYPE_CALLING_TIMEOUT:
                    statusStr = @"对方无应答";
                    break;
                case VOIP_RECORD_TYPE_CHATTING_DURATION:
                    statusStr = (vrm.duration > 0) ? [TimeTool getVoipDurationFromSS:vrm.duration] : @"00:00";
                    break;
                default:
                    statusStr = @"";
                    break;
            }
            entity.text = statusStr.length > 0
                ? [NSString stringWithFormat:@"%@ %@", typeStr, statusStr]
                : typeStr;
        } else if ([entity.text isEqualToString:@"视频通话"] || [entity.text isEqualToString:@"语音通话"]) {
            // 旧版本或服务端生成的记录只有类型没有状态，补充"已结束"
            entity.text = [NSString stringWithFormat:@"%@ 已结束", entity.text];
        } else if (![entity.text containsString:@"通话"]) {
            entity.text = @"通话记录";
        }
    }
    // 其它不支持的消息类型则直接显示不支持的信息提示内容（不然就会显示为JSON字串了）
    else if(entity.msgType == TM_TYPE_GIFT_SEND || entity.msgType == TM_TYPE_GIFT_GET) {
        entity.text = [NSString stringWithFormat: @"[暂不支持类型为\"%d\"的消息，请在Android端接收和查看]", entity.msgType];
    }
    // 文本等支持的消息类型直接显示，不需要在此进一步处理
    else
    {
        // do nothing
//      md = [[JSQMessage alloc] initWithSenderId:entity.name senderDisplayName:entity.name date:entity.date text:entity.text];
    }

    return entity;
}

/// 与 layout 高度计算共用：展示名优先；缺省时用 senderId，避免高频 insert 时 rb_chattingListForLayout 与 getChattingDatasList 不同步、或服务端偶发空昵称时出现「有气泡无昵称」。
static NSString * _Nullable rb_resolvedIncomingNicknameForDisplay(JSQMessage *msg) {
    if (msg == nil || [msg isOutgoing] || [msg isControl]) return nil;
    if (![BasicTool isStringEmpty:msg.senderDisplayName]) return msg.senderDisplayName;
    if (![BasicTool isStringEmpty:msg.senderId]) return msg.senderId;
    return nil;
}

// 昵称的显示逻辑 - @since 10.0
- (NSString *)rb_collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath_nickname:(NSIndexPath *)indexPath withCell:(JSQMessagesCollectionViewCell *)cell {
    NSArray<JSQMessage *> *list = [self rb_chattingListForLayout];
    if (indexPath.item < 0 || indexPath.item >= (NSInteger)list.count) return nil;
    JSQMessage *entity = list[indexPath.item];
    if (entity == nil) return nil;

    // 收藏夹（10001）：左侧消息显示收藏来源人名称（与群聊一致）；图片、短视频不显示来源昵称
    if (self.chatType == CHAT_TYPE_FREIDN_CHAT && [self.toId isEqualToString:@"10001"]) {
        NSString *nick = rb_resolvedIncomingNicknameForDisplay(entity);
        if (nick != nil) {
            if (entity.msgType == TM_TYPE_IMAGE || entity.msgType == TM_TYPE_SHORTVIDEO) {
                return nil;
            }
            return nick;
        }
        return nil;
    }

    if(self.chatType == CHAT_TYPE_GROUP_CHAT)
    {
        if (!self.rb_cachedShowGroupMemberNickname) {
            return nil;
        }
        // 只有分组首条是文本时，才在首条气泡上显示昵称；其他气泡不显示（与 heightForCellNicknameLabel 一致）
        NSInteger groupStart = [self rb_groupStartIndexForItemAtIndex:indexPath.item];
        if (indexPath.item != groupStart) return nil;
        if (groupStart >= (NSInteger)list.count) return nil;
        JSQMessage *firstMsg = list[groupStart];
        if (firstMsg.msgType != TM_TYPE_TEXT || [firstMsg isMediaMessage]) return nil;
        if ([self rb_messageCachedIsRedPacket:firstMsg]) return nil;
        if ([self rb_messageCachedIsTransfer:firstMsg]) return nil;
        return rb_resolvedIncomingNicknameForDisplay(firstMsg);
    }

    return nil;
}

// 单独的方法里处理被引用消息的显示逻辑，方便子类以更大的自由度实现自已的显示逻辑 - 20240316 by JackJiang
- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath_quote:(NSIndexPath *)indexPath withCell:(JSQMessagesCollectionViewCell *)cell andQuote:(QuoteMeta *)quoteMeta
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
        
    // 如果有被引用的消息内容需要被显示（quote内容显示ui的可见性，已由专门的方法进行constains高度约束计算，本方法中的逻辑只处理ui内容的设置，不需要处理ui可见性逻辑）
    if(quoteMeta != nil && ![BasicTool isStringEmpty:quoteMeta.quote_content])
    {
        // 此状态表示被引用的原始消息已被撤回了
        if(quoteMeta.quote_status == 1) {
            NSString *quoteContentForShow = @"引用内容已撤回";
            cell.quoteIconView.image = [UIImage imageNamed:@"chatting_msg_item_quote_default"];
            cell.quoteContentLabel.text = quoteContentForShow;
            return;
        }
    }
    
    // 消息内容的显示（比如图片消息会显示"[图片]"这样的字串）
    NSString *quoteContentForShow = [JSQMessage parseMessageContentPreview:quoteMeta.quote_content withType:quoteMeta.quote_type];
    if([BasicTool isStringEmpty:quoteContentForShow]) {
        quoteContentForShow = @"未知内容";
    }
    
    // 被引用消息发送者的昵称
    NSString *quoteNick = [Quote4InputWrapper getQuoteNick:self.chatType to:self.toId quoteUid:quoteMeta.quote_sender_uid quoteNick:quoteMeta.quote_sender_nick];
    quoteNick = (![BasicTool isStringEmpty: quoteNick] ? [NSString stringWithFormat:@"%@: ", quoteNick] : @"");
    NSString *quoteNickToShow = [NSString stringWithFormat:@"%@%@", quoteNick, quoteContentForShow];
    
    // 被引用消息的消息类型
    switch(quoteMeta.quote_type)
    {
        case TM_TYPE_IMAGE:
        {
            cell.quoteIconView.image = [UIImage imageNamed:@"chatting_msg_item_quote_default"];
            cell.quotePlayIconView.hidden = YES;
            cell.quoteContentLabel.text = quoteNick;
            
            NSString *imageFileName = quoteMeta.quote_content;
            if (imageFileName != nil) {
                // 消息列表中引用预览：使用预览档（pv_ + 原文件名，savePreviewJpegMaxEdge）；点开大图时再拉全图
                NSString *fileName = [NSString stringWithFormat:@"pv_%@", imageFileName];
                NSString *fileDownloadPath = [SendImageHelper getImageDownloadURL:fileName dump:NO];
                
                // 异步下载此图片的预览图
                [cell.quoteIconView sd_setImageWithURL:[NSURL URLWithString:fileDownloadPath] placeholderImage:[UIImage imageNamed:@"chatting_msg_item_quote_default"] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
                    if(error){
                        DDLogWarn(@"【图片引用消息】图片加载失败(URL=%@)，原因是：%@", fileDownloadPath, error);
                    }
                }];
//                [FileDownloadHelper loadChattingImgWithURL:fileDownloadPath logTag:@"图片引用消息" complete:^(BOOL sucess, UIImage *imageDlownload) {
//                    // 成功下载完成
//                    if(sucess) {
//                        cell.quoteIconView.image = (imageDlownload == nil?[UIImage imageNamed:@"chatting_msg_item_quote_default"]:imageDlownload);
//
//                        // 刷新UI显示
//                        [safeSelf.collectionView reloadData];
//                    } else {
//                        cell.quoteIconView.image = [UIImage imageNamed:@"chatting_msg_item_quote_default"];
//                    }
//                }];
            }
            
            break;
        }
            // 语音留言消息
        case TM_TYPE_VOICE:
        {
            cell.quoteIconView.image = [UIImage imageNamed:@"chatting_msg_item_quote_voice"];
            cell.quotePlayIconView.hidden = YES;
            cell.quoteContentLabel.text = quoteNickToShow;
            break;
        }
        // “赠送的礼品”消息
        case TM_TYPE_GIFT_SEND:
        // “索取礼品”消息
        case TM_TYPE_GIFT_GET:
        {
            cell.quoteContentLabel.text = quoteNickToShow;
            break;
        }
        // 文件消息
        case TM_TYPE_FILE:
        {
            cell.quotePlayIconView.hidden = YES;
            
            NSString *fileName = @"文件数据被破坏";
            FileMeta *fileMeta = [FileMeta fromJSON:quoteMeta.quote_content];
            if(fileMeta != nil) {
                fileName = fileMeta.fileName;
            }
            // 显示文件信息
            cell.quoteContentLabel.text = quoteNickToShow;
            cell.quoteIconView.image = [BigFileViewerController getFileIconByExtention:fileMeta.fileName bigImage:NO];
            break;
        }
        // 短视频消息
        case TM_TYPE_SHORTVIDEO:
        {
            cell.quoteIconView.image = [UIImage imageNamed:@"chatting_msg_item_quote_default"];
            cell.quotePlayIconView.hidden = NO;
            cell.quotePlayIconView.image = [UIImage imageNamed:@"chatting_msg_item_quote_shortvideo_play_icon"];
            cell.quoteContentLabel.text = quoteNick;
            
            FileMeta *fileMeta = [FileMeta fromJSON:quoteMeta.quote_content];
            if(fileMeta != nil){
                NSString *fileName = fileMeta.fileName;
                NSString *fileMd5 = fileMeta.fileMd5;
                
                // 视频首帧预览图的文件名（本地保存的名）
                NSString *imgLocalSavedName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:fileName];
                
                NSString *fileDownloadPath = [ReceivedShortVideoHelper getShortVideoThumbDownloadURL:imgLocalSavedName videofileMd5:fileMd5];
                
                // 尝试异步下载此短视频的预览图
                [cell.quoteIconView sd_setImageWithURL:[NSURL URLWithString:fileDownloadPath] placeholderImage:[UIImage imageNamed:@"chatting_msg_item_quote_default"] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
                    if(error){
                        DDLogWarn(@"【图片引用消息】图片加载失败(URL=%@)，原因是：%@", fileDownloadPath, error);
                    }
                }];
//                [FileDownloadHelper loadChattingShortVideoPreviewImgWithURL:fileDownloadPath logTag:@"短视频引用消息" complete:^(BOOL sucess, UIImage *imageDlownload) {
//                    // 成功下载完成
//                    if(sucess){
//                        if(imageDlownload != nil) {
//                            cell.quoteIconView.image = imageDlownload;
//                        }
//                        
//                        // 刷新UI显示
//                        [safeSelf.collectionView reloadData];
//                    }
//                }];
            }
            
            break;
        }
        // 名片消息
        case TM_TYPE_CONTACT:
        {
            cell.quoteIconView.image = [UIImage imageNamed:@"chatting_msg_item_quote_default"];
            cell.quotePlayIconView.hidden = YES;
            cell.quoteContentLabel.text = [NSString stringWithFormat:@"%@ 未知用户", quoteNickToShow];
            
            ContactMeta *cm = [ContactMeta fromJSON:quoteMeta.quote_content];
            if(cm != nil) {
                NSString *uid = cm.uid;
                NSString *nickName = cm.nickName;
                if(![BasicTool isStringEmpty:nickName]) {
                    // 显示昵称
                    cell.quoteContentLabel.text = [NSString stringWithFormat:@"%@ %@", quoteNickToShow, nickName];
                }
                
                NSString *defaultIconName = nil;
                // 头像图片下载完整URL地址
                NSString *fileDownloadPath = nil;
                
                // 如果是"个人名片"消息
                if(cm.type == CONTACT_TYPE_USER) {
                    defaultIconName = @"chat_avatar_default";
                    // 头像图片下载完整URL地址
                    fileDownloadPath = [FileDownloadHelper getUserAvatarDownloadURLExt:NO fileName:nil uid:uid];
                } else {
                    defaultIconName = @"groupchat_groups_icon_default";
                    fileDownloadPath = [GroupsViewController getGroupAvatarDownloadURL:uid];
                }
                
                [cell.quoteIconView sd_setImageWithURL:[NSURL URLWithString:fileDownloadPath] placeholderImage:[UIImage imageNamed:defaultIconName] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
                    if(error){
                        DDLogWarn(@"【名片引用消息】头像图片加载失败(URL=%@)，原因是：%@", fileDownloadPath, error);
                    }
                }];
            }
            
            break;
        }
        // 位置消息
        case TM_TYPE_LOCATION:
        {
            cell.quotePlayIconView.hidden = YES;
            cell.quoteIconView.image = [UIImage imageNamed:@"chatting_msg_item_quote_location"];
            cell.quoteContentLabel.text = quoteNickToShow;
            break;
        }
        // 实时音视频聊天记录消息
        case TM_TYPE_VOIP_RECORD:
        {
            cell.quoteContentLabel.text = @"不支持的引用消息";
            DDLogWarn(@"不支持实时音视频聊天记录消息的引用和显示！");
            break;
        }
        // 所有未定义的消息都假设是文字，这样就不至于在不支持的消息时什么也不会显示了
        default:
        {
            // 【无效代码】：参考首页“消息”中显示表情的办法，会导致表情图标显示大小变的很大（跟控件本身的字体大小完全不一致）
//          NSDictionary *attributes = [cell.quoteContentLabel.attributedText attributesAtIndex:0 effectiveRange:nil];

            // 【有效代码】：参考聊天气泡中显示表情的办法，表情图标显示大小正常
            UIFont *quoteFont = cell.quoteContentLabel.font ?: [BasicTool getSystemFontOfSize:16.0f];
            cell.quoteContentLabel.attributedText = [self rb_renderedQuoteText:quoteNickToShow font:quoteFont cacheHost:(JSQMessage *)quoteMeta];
            break;;
        }
    }
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didDeleteMessageAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray<JSQMessage *> *list = [self getChattingDatasList];
    if (indexPath.item >= 0 && indexPath.item < (NSInteger)list.count) {
        [list removeObjectAtIndex:indexPath.item];
    }
}

- (JSQMessage *)rb_safeMessageAtIndex:(NSInteger)idx
{
    NSArray<JSQMessage *> *list = [self getChattingDatasList];
    if (idx < 0 || idx >= (NSInteger)list.count) return nil;
    JSQMessage *m = list[idx];
    return [m isKindOfClass:[JSQMessage class]] ? m : nil;
}

- (JSQMessagesBubbleImage *)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *entity = [self rb_safeMessageAtIndex:indexPath.item];
    if (!entity) {
        if (!self.rb_placeholderBubbleImageData) {
            JSQMessagesBubbleImageFactory *f = [[JSQMessagesBubbleImageFactory alloc] init];
            self.rb_placeholderBubbleImageData = [f incomingMessagesBubbleImage];
        }
        return self.rb_placeholderBubbleImageData;
    }
    BOOL isOutgoing = [entity.senderId isEqualToString:self.senderId];
    // 分组中仅显示头像的气泡（single/bottom）显示尾巴，top/middle 用无尾气泡
    NSInteger pos = [self rb_messageGroupPositionForItemAtIndex:indexPath.item];
    BOOL useNoTail = (pos == 1 || pos == 2);
    if (useNoTail) {
        JSQMessagesBubbleImage *outNoTail = nil, *inNoTail = nil;
        [ViewControllerFactory getSharedBubbleImagesWithoutTailOutgoing:&outNoTail incoming:&inNoTail];
        return isOutgoing ? outNoTail : inNoTail;
    }
    if (isOutgoing) {
        if (self.outgoingBubbleImageData_light) return self.outgoingBubbleImageData_light;
        if (!self.rb_placeholderBubbleImageData) {
            JSQMessagesBubbleImageFactory *f = [[JSQMessagesBubbleImageFactory alloc] init];
            self.rb_placeholderBubbleImageData = [f incomingMessagesBubbleImage];
        }
        return self.rb_placeholderBubbleImageData;
    }
    if (self.incomingBubbleImageData) return self.incomingBubbleImageData;
    if (!self.rb_placeholderBubbleImageData) {
        JSQMessagesBubbleImageFactory *f = [[JSQMessagesBubbleImageFactory alloc] init];
        self.rb_placeholderBubbleImageData = [f incomingMessagesBubbleImage];
    }
    return self.rb_placeholderBubbleImageData;
}

// 子类可在本代理方法中实现聊天列表中的用户头像 图片的获取逻辑
- (UIImage *)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *entity = [self rb_safeMessageAtIndex:indexPath.item];
    if (!entity) return nil;

    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;

    // 收藏夹（10001）：用每条记录的 source_from_uid 调现有用户头像接口（UserAvatarDownloader 带 user_uid）按需拉头像；或先批量查用户信息拿到 user_avatar_file_name 再拼下载地址
    if (self.chatType == CHAT_TYPE_FREIDN_CHAT && self.toId != nil && [self.toId isEqualToString:@"10001"]) {
        // 来源 uid：优先 senderId（服务端收藏列表），其次 quote_sender_uid（IM 转发消息）
        NSString *sourceUid = (entity.senderId.length > 0 && ![entity.senderId isEqualToString:@"0"]) ? entity.senderId : entity.quote_sender_uid;
        BOOL hasSource = (sourceUid.length > 0 && ![sourceUid isEqualToString:localUid]);
        if (hasSource) {
            // 有批量拉到的 user_avatar_file_name 时优先用文件名拼 URL，否则用 uid 调 UserAvatarDownloader
            NSString *fileName = [self avatarFileNameForSourceUidInFavorites:sourceUid];
            BOOL useFileName = (fileName.length > 0);
            NSString *cacheKey = [FileDownloadHelper getUserAvatarDownloadURLExt:useFileName fileName:fileName uid:sourceUid];
            if (cacheKey.length > 0) {
                // 先读内存（下载完成后会先入内存），再读磁盘，避免 reload 时磁盘未写完仍为 nil
                UIImage *cached = [FileDownloadHelper loadUserAvatarFromCacheOnly:cacheKey donotLoadFromDisk:YES];
                if (!cached) cached = [FileDownloadHelper loadUserAvatarFromCacheOnly:cacheKey donotLoadFromDisk:NO];
                if (cached) return cached;
            }
            __weak typeof(self) wself = self;
            NSIndexPath *path = [indexPath copy];
            [FileDownloadHelper loadUserAvatarIntelligent:fileName
                                                     uid:sourceUid
                                                  logTag:@"Chat10001-SourceAvatar"
                                                 complete:^(BOOL sucess, UIImage *img) {
                if (sucess && img && wself) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (![wself.collectionView.indexPathsForVisibleItems containsObject:path]) return;
                        // 直接设置当前可见 cell 的头像；不再在此处 reload，否则会重新走数据源可能仍返回占位图导致闪烁
                        UICollectionViewCell *cell = [wself.collectionView cellForItemAtIndexPath:path];
                        if ([cell isKindOfClass:[JSQMessagesCollectionViewCell class]]) {
                            UIImage *round = [JSQMessagesAvatarImageFactory avatarImageWithImage:img diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
                            ((JSQMessagesCollectionViewCell *)cell).avatarImageView.image = round;
                        }
                    });
                }
            } donotLoadFromDisk:NO];
            return [UIImage imageNamed:@"default_avatar_60"];
        }
        // 无来源或我方：用我方头像
        UIImage *avatar = nil;
        if ([self respondsToSelector:@selector(outgoingAvatarImage)]) {
            @try { avatar = [self valueForKey:@"outgoingAvatarImage"]; } @catch (NSException *e) {}
        }
        return avatar ?: [UIImage imageNamed:@"default_avatar_60"];
    }

    // 其它会话/普通消息：按 senderId 判断左右头像
    BOOL isOutgoing = (localUid != nil && [entity.senderId isEqualToString:localUid]);
    if (isOutgoing) {
        UIImage *avatar = nil;
        if ([self respondsToSelector:@selector(outgoingAvatarImage)]) {
            @try {
                avatar = [self valueForKey:@"outgoingAvatarImage"];
            } @catch (NSException *e) {}
        }
        if (!avatar) {
            avatar = [UIImage imageNamed:@"default_avatar_60"];
        }
        return avatar;
    } else {
        UIImage *avatar = [UIImage imageNamed:@"default_avatar_60"];
        return avatar;
    }
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *entity = [self rb_safeMessageAtIndex:indexPath.item];
    if (entity == nil || !entity.showTopTime) return nil;
    NSString *dateStr = [TimeTool getTimeStringAutoShort2:entity.date mustIncludeTime:NO timeWithSegment:NO];
    if (!dateStr.length) return nil;
    NSMutableParagraphStyle *para = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    para.alignment = NSTextAlignmentCenter;
    UIColor *timeColor = [UIColor blackColor];
    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:12.0f],
        NSForegroundColorAttributeName: timeColor,
        NSParagraphStyleAttributeName: para
    };
    return [[NSAttributedString alloc] initWithString:dateStr attributes:attrs];
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    // 返回nil表示聊天界面上不显示topLabel
    return nil;
}

// 配置气泡内的时间+已读/未读状态视图（时间在右下角，已读/未读勾在时间右侧；对方浅灰，我方白字白勾）
- (void)jsq_configureBubbleTimeStatus:(JSQMessagesCollectionViewCell *)cell withMessage:(JSQMessage *)message
{
    // 系统消息、撤回消息、红包、转账消息、音视频通话记录、语音消息：不显示时间与已读/未读状态（红包/转账含按 content 兜底）
    BOOL isRedPacket = [self rb_messageCachedIsRedPacket:message];
    BOOL isTransfer = [self rb_messageCachedIsTransfer:message];
    if (message.msgType == TM_TYPE_SYSTEAM_INFO || message.msgType == TM_TYPE_REVOKE || isRedPacket || isTransfer || message.msgType == TM_TYPE_VOIP_RECORD || message.msgType == TM_TYPE_VOICE) {
        cell.bubbleTimeStatusView.hidden = YES;
        return;
    }
    // 收藏夹（10001）：不显示已读回执与发送状态（单勾/双勾、上传中/处理中等）
    BOOL isFavorites10001 = [self.toId isEqualToString:@"10001"];

    cell.bubbleTimeStatusView.hidden = NO;
    [cell.messageBubbleContainerView bringSubviewToFront:cell.bubbleTimeStatusView];
    
    // 小号字体；对方浅灰，我方文本气泡上时间与已读勾为白色（媒体条上另设白字）
    static UIColor *s_timeStatusGray = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_timeStatusGray = [UIColor colorWithWhite:0.55 alpha:1.0]; // 浅灰，与气泡对比柔和
    });
    UIFont *timeFont = [UIFont systemFontOfSize:11.0f];
    
    // 1. 时间（气泡内右下，HH:mm）
    UILabel *timeLabel = [cell.bubbleTimeStatusView viewWithTag:1001];
    timeLabel.font = timeFont;
    if (message.date) {
        timeLabel.text = [self.bottomLabelTimeFormatter stringFromDate:message.date];
    } else {
        timeLabel.text = @"";
    }
    
    // 2. 状态（仅发出的消息：时间右侧单勾/双勾，同色）
    UIImageView *statusIcon = [cell.bubbleTimeStatusView viewWithTag:1002];
    UILabel *statusTextLabel = [cell.bubbleTimeStatusView viewWithTag:1003];
    
    BOOL isOutgoing = [message isOutgoing];
    BOOL isMediaMsg = [message isMediaMessage];
    /// 群聊不展示已送达/已读勾（单勾/双勾）；仍保留时间与媒体发送进度文案
    BOOL hideDeliveredReadTicksForGroup = (self.chatType == CHAT_TYPE_GROUP_CHAT);
    
    if (isOutgoing) {
        for (NSLayoutConstraint *c in statusIcon.constraints) {
            if (c.firstAttribute == NSLayoutAttributeWidth) c.constant = 12;
        }
        for (NSLayoutConstraint *c in cell.bubbleTimeStatusView.constraints) {
            if (c.firstItem == (id)statusIcon && c.firstAttribute == NSLayoutAttributeLeading) c.constant = 3;
        }
        // 收藏夹不显示已读回执与发送状态
        if (isFavorites10001) {
            statusIcon.hidden = YES;
            statusTextLabel.hidden = YES;
        } else {
        int sendStatus = message.sendStatus;
        int sendStatusSecondary = message.sendStatusSecondary;
        
        NSString *fileStatusStr = nil;
        UIColor *fileStatusColor = nil;
        if (isMediaMsg) {
            switch (sendStatusSecondary) {
                case SendStatusSecondary_PENDING:
                    fileStatusStr = @"处理中";
                    fileStatusColor = HexColor(0xF26C4F);
                    break;
                case SendStatusSecondary_PROCESSING:
                    fileStatusStr = @"上传中";
                    fileStatusColor = HexColor(0xF26C4F);
                    break;
                case SendStatusSecondary_PROCESS_FAILD:
                    fileStatusStr = @"上传失败";
                    fileStatusColor = HexColor(0xF26C4F);
                    break;
                default:
                    break;
            }
        }
        
        if (fileStatusStr) {
            statusIcon.hidden = YES;
            statusTextLabel.hidden = NO;
            statusTextLabel.text = fileStatusStr;
            statusTextLabel.textColor = fileStatusColor;
            statusTextLabel.font = timeFont;
        } else if (sendStatus == SendStatus_SEND_FAILD) {
            statusIcon.hidden = YES;
            statusTextLabel.hidden = NO;
            statusTextLabel.text = @"发送失败";
            statusTextLabel.textColor = HexColor(0xF26C4F);
            statusTextLabel.font = timeFont;
        } else if (sendStatus == SendStatus_BE_RECEIVED) {
            if (hideDeliveredReadTicksForGroup) {
                statusIcon.hidden = YES;
                statusTextLabel.hidden = YES;
            } else {
            statusTextLabel.hidden = YES;
            statusIcon.hidden = NO;
            UIImage *iconImg = nil;
            if (message.readByPartner) {
                iconImg = [UIImage imageNamed:@"s"]; // 已读（双勾）
            } else {
                iconImg = [UIImage imageNamed:@"d"]; // 已送达（单勾）
            }
            statusIcon.image = iconImg ? [iconImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : nil;
            statusIcon.tintColor = [UIColor blackColor];
            }
        } else {
            statusIcon.hidden = YES;
            statusTextLabel.hidden = YES;
        }
        }
        if (isRedPacket) {
            statusIcon.hidden = YES;
            statusTextLabel.hidden = YES;
            for (NSLayoutConstraint *c in statusIcon.constraints) {
                if (c.firstAttribute == NSLayoutAttributeWidth) c.constant = 0;
            }
            for (NSLayoutConstraint *c in cell.bubbleTimeStatusView.constraints) {
                if (c.firstItem == (id)statusIcon && c.firstAttribute == NSLayoutAttributeLeading) c.constant = 0;
            }
        }
    } else {
        statusIcon.hidden = YES;
        statusTextLabel.hidden = YES;
        for (NSLayoutConstraint *c in statusIcon.constraints) {
            if (c.firstAttribute == NSLayoutAttributeWidth) c.constant = 0;
        }
        for (NSLayoutConstraint *c in cell.bubbleTimeStatusView.constraints) {
            if (c.firstItem == (id)statusIcon && c.firstAttribute == NSLayoutAttributeLeading) c.constant = 0;
        }
    }
    
    if (!isMediaMsg) {
        cell.bubbleTimeStatusView.hidden = YES;
        return;
    }
    cell.bubbleTimeStatusView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    cell.bubbleTimeStatusView.layer.cornerRadius = 7;
    cell.bubbleTimeStatusView.clipsToBounds = YES;
    timeLabel.textColor = [UIColor whiteColor];
    statusTextLabel.textColor = statusTextLabel.textColor ?: [UIColor whiteColor];
    statusIcon.tintColor = [UIColor whiteColor];
    if (timeLabel.text.length > 0) {
        timeLabel.text = [NSString stringWithFormat:@" %@ ", timeLabel.text];
    }
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray<JSQMessage *> *list = [self rb_chattingListForLayout];
    JSQMessage *message = (indexPath.item < (NSInteger)list.count) ? list[indexPath.item] : nil;
    if (!message) return nil;
    BOOL isVoiceOrVoip = (message.msgType == TM_TYPE_VOICE || message.msgType == TM_TYPE_VOIP_RECORD);
    if (!isVoiceOrVoip) {
        if (message.msgType != TM_TYPE_TEXT || [message isMediaMessage]) return nil;
        if (message.msgType == TM_TYPE_SYSTEAM_INFO || message.msgType == TM_TYPE_REVOKE) return nil;
        if ([self rb_messageCachedIsRedPacket:message]) return nil;
        if ([self rb_messageCachedIsTransfer:message]) return nil;
    }

    NSString *timeText = @"";
    if (message.date) {
        timeText = [self.bottomLabelTimeFormatter stringFromDate:message.date] ?: @"";
    }
    if (timeText.length == 0) return nil;

    BOOL isOutgoing = [message isOutgoing];
    BOOL isFavorites10001 = [self.toId isEqualToString:@"10001"];
    BOOL isGroupChat = (self.chatType == CHAT_TYPE_GROUP_CHAT);

    NSString *statusText = nil;
    if (isOutgoing && !isFavorites10001 && !isGroupChat) {
        if (message.sendStatusSecondary == SendStatusSecondary_PENDING || message.sendStatusSecondary == SendStatusSecondary_PROCESSING) {
            statusText = @"发送中";
        } else if (message.sendStatus == SendStatus_SNEDING) {
            statusText = @"发送中";
        } else if (message.sendStatus == SendStatus_SEND_FAILD || message.sendStatusSecondary == SendStatusSecondary_PROCESS_FAILD) {
            statusText = @"发送失败";
        } else if (message.sendStatus == SendStatus_BE_RECEIVED) {
            statusText = message.readByPartner ? @"已读" : @"已送达";
        }
    }

    NSString *finalText = nil;
    if (statusText.length > 0) {
        finalText = [NSString stringWithFormat:@"%@  %@", timeText, statusText];
    } else {
        finalText = timeText;
    }

    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:11.0f],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:0.55 alpha:1.0],
    };
    return [[NSAttributedString alloc] initWithString:finalText attributes:attrs];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - UICollectionView DataSource（重写的几个聊天列表的表格数据源代理方法）

// 聊天消息行数（布局阶段在此缓存列表，后续 sizeForItem/messageData/cellForItem 等复用，减轻主线程卡顿）
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSArray<JSQMessage *> *list = [self getChattingDatasList];
    self.rb_cachedChattingListForLayout = list;  // 同一 layout pass 内数据源与群聊分组共用此快照，避免快速滑动堆叠错位
    return list.count;
}

#pragma mark - 红包消息卡片 UI

// 从 JSON 字典中安全取字符串，兼容 number/string，过滤 nil 与 NSNull
static NSString * _Nullable rb_safeStringFromRedPacketDict(NSDictionary *dict, NSString *key) {
    id val = dict[key];
    if (val == nil || [val isKindOfClass:[NSNull class]]) return nil;
    NSString *s = [val isKindOfClass:[NSString class]] ? val : [val description];
    if (s.length == 0 || [s isEqualToString:@"<null>"] || [s isEqualToString:@"(null)"]) return nil;
    return s;
}

// 仅通过 content 判断是否为红包 JSON（服务端若下发的 msg_type 为 0，仍能按红包展示与点击）
static BOOL rb_isRedPacketContent(NSString *text) {
    if (text.length == 0 || ![text hasPrefix:@"{"]) return NO;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return NO;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![dict isKindOfClass:[NSDictionary class]]) return NO;
    return (rb_safeStringFromRedPacketDict(dict, @"packet_id").length > 0);
}

// 仅通过 content 判断是否为转账 JSON（格式如 {"amount":"11.00","to_uid":"400204","remark":""}）
static BOOL rb_isTransferContent(NSString *text) {
    if (text.length == 0 || ![text hasPrefix:@"{"]) return NO;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return NO;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![dict isKindOfClass:[NSDictionary class]]) return NO;
    id amt = dict[@"amount"];
    return (amt != nil && ![amt isKindOfClass:[NSNull class]]);
}

- (NSString *)rb_parseRedPacketBlessingFromJSON:(NSString *)jsonText
{
    if (jsonText.length == 0) return @"恭喜发财，大吉大利";
    NSData *data = [jsonText dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return @"恭喜发财，大吉大利";
    NSError *err = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if (![dict isKindOfClass:[NSDictionary class]]) return @"恭喜发财，大吉大利";
    NSString *msg = rb_safeStringFromRedPacketDict(dict, @"message");
    return (msg.length > 0 ? msg : @"恭喜发财，大吉大利");
}

// 解析是否为专属红包及收款人信息（群聊专属红包消息里带 exclusive_receiver_uid / exclusive_receiver_display_name）
// packet_type 兼容 number 或 string（如 3 或 "3"）
- (BOOL)rb_parseRedPacketExclusiveFromJSON:(NSString *)jsonText receiverNameOut:(NSString * _Nullable * _Nonnull)nameOut receiverUidOut:(NSString * _Nullable * _Nonnull)uidOut
{
    if (nameOut) *nameOut = nil;
    if (uidOut) *uidOut = nil;
    if (jsonText.length == 0) return NO;
    NSData *data = [jsonText dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return NO;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![dict isKindOfClass:[NSDictionary class]]) return NO;
    id pt = dict[@"packet_type"];
    NSInteger packetType = [pt respondsToSelector:@selector(integerValue)] ? [pt integerValue] : 0;
    if (packetType != 3) return NO;
    NSString *uid = rb_safeStringFromRedPacketDict(dict, @"exclusive_receiver_uid");
    NSString *name = rb_safeStringFromRedPacketDict(dict, @"exclusive_receiver_display_name");
    if (uid.length > 0) {
        if (uidOut) *uidOut = uid;
        if (nameOut) *nameOut = (name.length > 0 ? name : nil);
        return YES;
    }
    return NO;
}

static const NSInteger kRedPacketExclusiveAvatarTag = 8890;

// 聊天红包气泡使用的图片资源名，若 Assets 中无此图则回退为代码绘制的卡片
static NSString * const kChatRedPacketBubbleImageName = @"chat_red_packet";
static const CGFloat kRBMoneyCardWidth = 270.0f;
static const CGFloat kRBMoneyCardHeight = 90.0f;

static NSString *rb_safeStringFromJSONDict(NSDictionary *dict, NSString *key) {
    id val = dict[key];
    if (val == nil || [val isKindOfClass:[NSNull class]]) return nil;
    NSString *s = [val isKindOfClass:[NSString class]] ? val : [val description];
    if (s.length == 0 || [s isEqualToString:@"<null>"] || [s isEqualToString:@"(null)"]) return nil;
    return s;
}

static NSDictionary *rb_messageJSONObject(NSString *text) {
    if (text.length == 0 || ![text hasPrefix:@"{"]) return nil;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [dict isKindOfClass:[NSDictionary class]] ? dict : nil;
}

static NSString *rb_renderCacheSafeKeyText(NSString *text) {
    return text ?: @"";
}

static NSString *rb_formatAssetAmountText(NSString *amount, NSString *assetType) {
    NSString *safeAmount = (amount.length > 0 ? amount : @"0.00");
    NSString *assetTypeText = (assetType.length > 0 ? assetType : @"CNY");
    NSString *safeAssetType = [assetTypeText uppercaseString];
    if (safeAssetType.length == 0) safeAssetType = @"CNY";
    if ([safeAssetType isEqualToString:@"CNY"]) {
        return [NSString stringWithFormat:@"¥%@", safeAmount];
    }
    return [NSString stringWithFormat:@"%@ %@", safeAmount, safeAssetType];
}

- (NSString *)rb_timeTextForMoneyCardMessage:(JSQMessage *)message
{
    if (message.date == nil) return @"";
    return [self.bottomLabelTimeFormatter stringFromDate:message.date] ?: @"";
}

- (void)rb_parseRedPacketAmountFromJSON:(NSString *)jsonText amountOut:(NSString * _Nullable * _Nonnull)amountOut assetTypeOut:(NSString * _Nullable * _Nonnull)assetTypeOut
{
    if (amountOut) *amountOut = @"0.00";
    if (assetTypeOut) *assetTypeOut = @"CNY";
    if (jsonText.length == 0) return;
    NSData *data = [jsonText dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![dict isKindOfClass:[NSDictionary class]]) return;

    NSString *amount = rb_safeStringFromRedPacketDict(dict, @"total_amount");
    NSString *assetType = rb_safeStringFromRedPacketDict(dict, @"asset_type");
    if (amountOut && amount.length > 0) *amountOut = amount;
    if (assetTypeOut && assetType.length > 0) *assetTypeOut = assetType;
}

// 专属红包卡片：背景用 chat_red_packet，左侧头像 + 「xxx的专属红包」+ 底部「专属红包」
- (UIView *)rb_redPacketCardViewExclusiveWithReceiverName:(NSString *)receiverName receiverUid:(NSString *)receiverUid amountText:(NSString *)amountText timeText:(NSString *)timeText size:(CGSize)size
{
    (void)receiverUid;
    CGFloat w = size.width;
    CGFloat h = size.height;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    card.clipsToBounds = YES;
    card.layer.cornerRadius = 6;

    UIImage *bubbleImage = [UIImage imageNamed:kChatRedPacketBubbleImageName];
    if (bubbleImage) {
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
        imgView.image = bubbleImage;
        imgView.contentMode = UIViewContentModeScaleToFill;
        [card addSubview:imgView];
    } else {
        card.backgroundColor = HexColor(0xE64340);
    }

    CGFloat leftPad = 10;
    CGFloat avatarSize = 30;
    UIImageView *avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(leftPad, 16, avatarSize, avatarSize)];
    avatarView.tag = kRedPacketExclusiveAvatarTag;
    avatarView.backgroundColor = [HexColor(0xF5E6C8) colorWithAlphaComponent:0.3];
    avatarView.layer.cornerRadius = avatarSize / 2;
    avatarView.clipsToBounds = YES;
    avatarView.contentMode = UIViewContentModeScaleAspectFill;
    avatarView.image = [UIImage imageNamed:@"default_avatar_60"];
    [card addSubview:avatarView];

    NSString *titleText = (receiverName.length > 0) ? [NSString stringWithFormat:@"%@的专属红包", receiverName] : @"专属红包";
    CGFloat titleLeft = leftPad + avatarSize + 8;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(titleLeft, 14, w - titleLeft - 12, 20)];
    titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    titleLabel.textColor = HexColor(0xF5E6C8);
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.text = titleText;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.7;
    [card addSubview:titleLabel];

    UILabel *amountLabel = [[UILabel alloc] initWithFrame:CGRectMake(titleLeft, 37, w - titleLeft - 12, 22)];
    amountLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    amountLabel.textColor = [UIColor whiteColor];
    amountLabel.textAlignment = NSTextAlignmentLeft;
    amountLabel.text = (amountText.length > 0 ? amountText : @"¥0.00");
    amountLabel.adjustsFontSizeToFitWidth = YES;
    amountLabel.minimumScaleFactor = 0.75;
    [card addSubview:amountLabel];

    CGFloat lineY = h - 30;
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(leftPad, lineY, w - leftPad * 2, 1)];
    line.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    [card addSubview:line];

    CGFloat bottomY = h - 23;
    CGFloat timeWidth = 56;
    UILabel *hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftPad, bottomY, w - leftPad * 2 - timeWidth - 6, 16)];
    hintLabel.font = [UIFont systemFontOfSize:12];
    hintLabel.textColor = HexColor(0xF5E6C8);
    hintLabel.textAlignment = NSTextAlignmentLeft;
    hintLabel.text = @"专属红包";
    [card addSubview:hintLabel];

    UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - leftPad - timeWidth, bottomY, timeWidth, 16)];
    timeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    timeLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.86];
    timeLabel.textAlignment = NSTextAlignmentRight;
    timeLabel.text = timeText ?: @"";
    [card addSubview:timeLabel];

    return card;
}

- (UIView *)rb_redPacketCardViewWithBlessing:(NSString *)blessing timeText:(NSString *)timeText size:(CGSize)size
{
    CGFloat w = size.width;
    CGFloat h = size.height;
    UIImage *bubbleImage = [UIImage imageNamed:kChatRedPacketBubbleImageName];
    if (bubbleImage) {
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
        container.clipsToBounds = YES;
        container.layer.cornerRadius = 6;
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
        imgView.image = bubbleImage;
        imgView.contentMode = UIViewContentModeScaleToFill;
        [container addSubview:imgView];
        CGFloat leftPad = 18;
        CGFloat iconW = 28;
        CGFloat iconH = 40;
        CGFloat iconY = 15;
        CGFloat labelH = 22;
        UIImageView *titleIcon = [[UIImageView alloc] initWithFrame:CGRectMake(leftPad, iconY, iconW, iconH)];
        titleIcon.image = [UIImage imageNamed:@"red_packet_count_icon"];
        titleIcon.contentMode = UIViewContentModeScaleAspectFill;
        titleIcon.clipsToBounds = YES;
        titleIcon.backgroundColor = [UIColor clearColor];
        [container addSubview:titleIcon];
        CGFloat labelY = iconY + (iconH - labelH) / 2;
        UILabel *blessingLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftPad + iconW + 4, labelY, w - leftPad - iconW - 4 - leftPad, labelH)];
        blessingLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
        blessingLabel.textColor = [UIColor whiteColor];
        blessingLabel.textAlignment = NSTextAlignmentLeft;
        blessingLabel.text = (blessing.length > 0 ? blessing : @"恭喜发财，大吉大利");
        blessingLabel.adjustsFontSizeToFitWidth = YES;
        blessingLabel.minimumScaleFactor = 0.7;
        [container addSubview:blessingLabel];
        CGFloat lineY = h - 30;
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(leftPad, lineY, w - leftPad * 2, 1)];
        line.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
        [container addSubview:line];
        CGFloat bottomY = h - 23;
        CGFloat timeWidth = 56;
        UILabel *hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftPad, bottomY, w - leftPad * 2 - timeWidth - 6, 16)];
        hintLabel.font = [UIFont systemFontOfSize:12];
        hintLabel.textColor = [UIColor whiteColor];
        hintLabel.textAlignment = NSTextAlignmentLeft;
        hintLabel.text = @"Chat精聊红包";
        [container addSubview:hintLabel];
        UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - leftPad - timeWidth, bottomY, timeWidth, 16)];
        timeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        timeLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.86];
        timeLabel.textAlignment = NSTextAlignmentRight;
        timeLabel.text = timeText ?: @"";
        [container addSubview:timeLabel];
        [container bringSubviewToFront:titleIcon];
        [container bringSubviewToFront:blessingLabel];
        [container bringSubviewToFront:line];
        [container bringSubviewToFront:hintLabel];
        [container bringSubviewToFront:timeLabel];
        return container;
    }
    // 无图片时使用代码绘制的红包卡片
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    card.backgroundColor = HexColor(0xE64340);  // 微信红包红
    card.layer.cornerRadius = 6;
    card.clipsToBounds = YES;

    CGFloat leftPad = 18;
    CGFloat iconW = 28;
    CGFloat iconH = 40;
    CGFloat iconY = 15;
    CGFloat labelH = 22;
    UIImageView *titleIcon = [[UIImageView alloc] initWithFrame:CGRectMake(leftPad, iconY, iconW, iconH)];
    titleIcon.image = [UIImage imageNamed:@"red_packet_count_icon"];
    titleIcon.contentMode = UIViewContentModeScaleAspectFill;
    titleIcon.clipsToBounds = YES;
    titleIcon.backgroundColor = [UIColor clearColor];
    [card addSubview:titleIcon];
    CGFloat labelY = iconY + (iconH - labelH) / 2;
    UILabel *blessingLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftPad + iconW + 4, labelY, w - leftPad - iconW - 4 - leftPad, labelH)];
    blessingLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    blessingLabel.textColor = [UIColor whiteColor];
    blessingLabel.textAlignment = NSTextAlignmentLeft;
    blessingLabel.text = (blessing.length > 0 ? blessing : @"恭喜发财，大吉大利");
    blessingLabel.adjustsFontSizeToFitWidth = YES;
    blessingLabel.minimumScaleFactor = 0.7;
    [card addSubview:blessingLabel];

    CGFloat lineY = h - 30;
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(leftPad, lineY, w - leftPad * 2, 1)];
    line.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    [card addSubview:line];

    CGFloat bottomY = h - 23;
    CGFloat timeWidth = 56;
    UILabel *hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftPad, bottomY, w - leftPad * 2 - timeWidth - 6, 16)];
    hintLabel.font = [UIFont systemFontOfSize:12];
    hintLabel.textColor = [UIColor whiteColor];
    hintLabel.textAlignment = NSTextAlignmentLeft;
    hintLabel.text = @"Chat精聊红包";
    [card addSubview:hintLabel];

    UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - leftPad - timeWidth, bottomY, timeWidth, 16)];
    timeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    timeLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.86];
    timeLabel.textAlignment = NSTextAlignmentRight;
    timeLabel.text = timeText ?: @"";
    [card addSubview:timeLabel];

    return card;
}

#pragma mark - 转账消息卡片 UI

- (void)rb_parseTransferFromJSON:(NSString *)jsonText amountOut:(NSString * _Nullable * _Nonnull)amountOut remarkOut:(NSString * _Nullable * _Nonnull)remarkOut assetTypeOut:(NSString * _Nullable * _Nonnull)assetTypeOut
{
    if (amountOut) *amountOut = @"0.00";
    if (remarkOut) *remarkOut = nil;
    if (assetTypeOut) *assetTypeOut = @"CNY";
    if (jsonText.length == 0) return;
    NSData *data = [jsonText dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return;
    NSError *err = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if (![dict isKindOfClass:[NSDictionary class]]) return;
    // amount：兼容 number/string，如 "11.00" 或 11.00
    id amtVal = dict[@"amount"];
    if (amountOut && amtVal != nil && ![amtVal isKindOfClass:[NSNull class]]) {
        if ([amtVal isKindOfClass:[NSNumber class]]) {
            *amountOut = [NSString stringWithFormat:@"%.2f", [amtVal doubleValue]];
        } else {
            NSString *s = [amtVal description];
            if (s.length > 0 && ![s isEqualToString:@"<null>"]) *amountOut = s;
        }
        if ((*amountOut).length == 0) *amountOut = @"0.00";
    }
    // remark：兼容 number/string，空串不设置
    NSString *rm = rb_safeStringFromRedPacketDict(dict, @"remark");
    if (remarkOut && rm.length > 0) *remarkOut = rm;
    NSString *assetType = rb_safeStringFromRedPacketDict(dict, @"asset_type");
    if (assetTypeOut && assetType.length > 0) *assetTypeOut = assetType;
}

- (UIView *)rb_transferCardViewWithAmount:(NSString *)amount remark:(NSString *)remark isOutgoing:(BOOL)isOutgoing timeText:(NSString *)timeText size:(CGSize)size
{
    (void)remark;
    CGFloat w = size.width;
    CGFloat h = size.height;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    card.backgroundColor = HexColor(0xFB9E3E);  // 转账气泡背景
    card.layer.cornerRadius = 6;
    card.clipsToBounds = YES;

    CGFloat leftPad = 18;
    CGFloat iconSize = 40;
    UIImageView *transferIcon = [[UIImageView alloc] initWithFrame:CGRectMake(leftPad, 18, iconSize, iconSize)];
    transferIcon.image = [UIImage imageNamed:@"transfer_bubble_icon"];
    transferIcon.contentMode = UIViewContentModeScaleAspectFit;
    transferIcon.clipsToBounds = YES;
    [card addSubview:transferIcon];

    CGFloat textLeft = leftPad + iconSize + 10;
    UILabel *amountLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLeft, 15, w - textLeft - 8, 24)];
    amountLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    amountLabel.textColor = [UIColor whiteColor];
    amountLabel.textAlignment = NSTextAlignmentLeft;
    amountLabel.text = [NSString stringWithFormat:@"¥%@", (amount.length > 0 ? amount : @"0.00")];
    [card addSubview:amountLabel];

    NSString *subText = isOutgoing ? @"你发起了一笔转账" : @"向你转账";
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLeft, 41, w - textLeft - 8, 18)];
    subLabel.font = [UIFont systemFontOfSize:13];
    subLabel.textColor = [UIColor whiteColor];
    subLabel.textAlignment = NSTextAlignmentLeft;
    subLabel.text = subText;
    [card addSubview:subLabel];

    CGFloat lineY = h - 30;
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(leftPad, lineY, w - leftPad * 2, 1)];
    line.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    [card addSubview:line];

    CGFloat bottomY = h - 23;
    CGFloat timeWidth = 56;
    UILabel *hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftPad, bottomY, w - leftPad * 2 - timeWidth - 6, 16)];
    hintLabel.font = [UIFont systemFontOfSize:12];
    hintLabel.textColor = [UIColor whiteColor];
    hintLabel.textAlignment = NSTextAlignmentLeft;
    hintLabel.text = @"转账";
    [card addSubview:hintLabel];

    UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - leftPad - timeWidth, bottomY, timeWidth, 16)];
    timeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    timeLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.86];
    timeLabel.textAlignment = NSTextAlignmentRight;
    timeLabel.text = timeText ?: @"";
    [card addSubview:timeLabel];

    return card;
}

// 实现不同聊天消息类型对应的消息气泡字体颜色等设置
- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *theCell = [super collectionView:collectionView cellForItemAtIndexPath:indexPath];

    // 是普通聊天消息
    if([theCell isKindOfClass:JSQMessagesCollectionViewCell.class])
    {
        JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)theCell;
        NSArray<JSQMessage *> *listForCell = [self rb_chattingListForLayout];
        JSQMessage *message = (indexPath.item < (NSInteger)listForCell.count) ? listForCell[indexPath.item] : nil;
        if (!message) return theCell;
        if ([message isOutgoing] && message.msgType == TM_TYPE_TEXT && indexPath.item == MAX((NSInteger)listForCell.count - 1, 0)) {
            DDLogInfo(@"[SendTrace][CellForLastOutgoingText] t=%.3f fp=%@ item=%ld listCount=%ld",
                      RBChatTraceNowMs(),
                      RBChatTraceSafeFp(message),
                      (long)indexPath.item,
                      (long)listForCell.count);
        }

        // 时间分组：仅居中文字（无胶囊/毛玻璃），复用时摘掉旧版胶囊残留
        static const NSInteger kTimeBubblePillTag = 9999;
        static const NSInteger kDividerFullWidthBgTag = 9998;
        UIView *existingPill = [cell.cellTopLabel viewWithTag:kTimeBubblePillTag];
        [existingPill removeFromSuperview];
        UIView *existingPillInContent = [cell.contentView viewWithTag:kTimeBubblePillTag];
        [existingPillInContent removeFromSuperview];
        UIView *existingDividerBg = [cell.contentView viewWithTag:kDividerFullWidthBgTag];
        [existingDividerBg removeFromSuperview];
        cell.cellTopLabel.backgroundColor = [UIColor clearColor];
        cell.cellTopLabel.layer.cornerRadius = 0;
        cell.cellTopLabel.clipsToBounds = NO;
        cell.cellTopLabel.layer.zPosition = 0.0f;
        if (!message.showTopTime) {
            cell.cellTopLabel.text = nil;
            cell.cellTopLabel.attributedText = nil;
        }

        cell.cellNicknameLabel2.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightSemibold];
        if (![message isOutgoing] && message.senderId.length > 0 && self.toId.length > 0) {
            BOOL showNickname = (self.chatType == CHAT_TYPE_GROUP_CHAT && self.rb_cachedShowGroupMemberNickname)
                || (self.chatType == CHAT_TYPE_FREIDN_CHAT && [self.toId isEqualToString:@"10001"]);
            if (showNickname) {
                cell.cellNicknameLabel2.textColor = [RBNicknameColor nicknameColorForUserId:message.senderId chatId:self.toId];
            } else {
                cell.cellNicknameLabel2.textColor = [UIColor darkGrayColor];
            }
        } else {
            cell.cellNicknameLabel2.textColor = [UIColor darkGrayColor];
        }

        cell.cellBottomLabel.textAlignment = [message isOutgoing] ? NSTextAlignmentRight : NSTextAlignmentLeft;

        // 移除可能复用的红包/转账卡片视图（cell 复用时）
        static const NSInteger kRedPacketCardViewTag = 8888;
        static const NSInteger kTransferCardViewTag = 8889;
        NSArray *bubbleSubs = [cell.messageBubbleContainerView.subviews copy];
        for (UIView *sub in bubbleSubs) {
            if (sub.tag == kRedPacketCardViewTag || sub.tag == kTransferCardViewTag) {
                [sub removeFromSuperview];
            }
        }
        cell.textView.hidden = NO;
        cell.messageBubbleImageView.hidden = NO;
        if (!cell.messageBubbleImageView.image || !cell.messageBubbleImageView.highlightedImage) {
            JSQMessagesBubbleImage *bubbleImageDataSource = [collectionView.dataSource collectionView:collectionView messageBubbleImageDataForItemAtIndexPath:indexPath];
            cell.messageBubbleImageView.image = [bubbleImageDataSource messageBubbleImage];
            cell.messageBubbleImageView.highlightedImage = [bubbleImageDataSource messageBubbleHighlightedImage];
        }

        // 多媒体类型不需要设置普通文本消息才有的几个字段的属性
        if([message isMediaMessage])
        {
            //
        }
        else
        {
            // 非媒体消息默认显示气泡背景（cell 复用时从红包/转账恢复）
            // ======== 红包消息：显示红包卡片 UI（专属红包显示收款人头像+昵称的专属红包，底部「专属红包」）。按 msgType 或 content 兜底 ========
            if ([self rb_messageCachedIsRedPacket:message]) {
                cell.messageBubbleImageView.hidden = YES;  // 隐藏默认白底气泡，避免红包卡片下方露出白边
                NSString *exclusiveName = message.rb_cachedRedPacketExclusiveName;
                NSString *exclusiveUid = message.rb_cachedRedPacketExclusiveUid;
                BOOL isExclusive = NO;
                if (exclusiveName != nil || exclusiveUid != nil) {
                    isExclusive = (exclusiveUid.length > 0);
                } else {
                    isExclusive = [self rb_parseRedPacketExclusiveFromJSON:message.text receiverNameOut:&exclusiveName receiverUidOut:&exclusiveUid];
                    message.rb_cachedRedPacketExclusiveName = exclusiveName;
                    message.rb_cachedRedPacketExclusiveUid = exclusiveUid;
                }
                NSString *cardTimeText = [self rb_timeTextForMoneyCardMessage:message];
                UIView *redPacketView = nil;
                if (isExclusive) {
                    NSString *redPacketAmount = message.rb_cachedRedPacketAmount;
                    NSString *redPacketAssetType = message.rb_cachedRedPacketAssetType;
                    if (redPacketAmount == nil && redPacketAssetType == nil) {
                        [self rb_parseRedPacketAmountFromJSON:message.text amountOut:&redPacketAmount assetTypeOut:&redPacketAssetType];
                        message.rb_cachedRedPacketAmount = redPacketAmount;
                        message.rb_cachedRedPacketAssetType = redPacketAssetType;
                    }
                    NSString *displayAmountText = rb_formatAssetAmountText(redPacketAmount, redPacketAssetType);
                    redPacketView = [self rb_redPacketCardViewExclusiveWithReceiverName:exclusiveName
                                                                             receiverUid:exclusiveUid
                                                                              amountText:displayAmountText
                                                                                timeText:cardTimeText
                                                                                    size:CGSizeMake(kRBMoneyCardWidth, kRBMoneyCardHeight)];
                    if (exclusiveUid.length > 0) {
                        __weak typeof(cell) wcell = cell;
                        [FileDownloadHelper loadUserAvatarWithUID:exclusiveUid logTag:@"RedPacket-Exclusive" complete:^(BOOL sucess, UIImage *img) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                UIView *card = [wcell.messageBubbleContainerView viewWithTag:kRedPacketCardViewTag];
                                UIImageView *av = (UIImageView *)[card viewWithTag:kRedPacketExclusiveAvatarTag];
                                if ([av isKindOfClass:[UIImageView class]] && img) av.image = img;
                            });
                        } donotLoadFromDisk:NO];
                    }
                } else {
                    NSString *blessing = message.rb_cachedRedPacketBlessing;
                    if (blessing == nil) {
                        blessing = [self rb_parseRedPacketBlessingFromJSON:message.text];
                        message.rb_cachedRedPacketBlessing = blessing;
                    }
                    redPacketView = [self rb_redPacketCardViewWithBlessing:blessing
                                                                  timeText:cardTimeText
                                                                      size:CGSizeMake(kRBMoneyCardWidth, kRBMoneyCardHeight)];
                }
                redPacketView.tag = kRedPacketCardViewTag;
                redPacketView.frame = CGRectMake(0, 0, cell.messageBubbleContainerView.bounds.size.width, cell.messageBubbleContainerView.bounds.size.height);
                redPacketView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [cell.messageBubbleContainerView addSubview:redPacketView];
                cell.textView.hidden = YES;
                cell.textView.attributedText = nil;
            }
            // ======== 转账消息：显示转账卡片 UI（橙琥珀底+白字+左侧双向箭头图标）。按 msgType 或 content 兜底 ========
            else if ([self rb_messageCachedIsTransfer:message]) {
                cell.messageBubbleImageView.hidden = YES;  // 隐藏默认白底气泡，避免转账卡片下方露出白边
                NSString *amount = message.rb_cachedTransferAmount;
                NSString *remark = message.rb_cachedTransferRemark;
                NSString *assetType = message.rb_cachedTransferAssetType;
                if (amount == nil && remark == nil && assetType == nil) {
                    [self rb_parseTransferFromJSON:message.text amountOut:&amount remarkOut:&remark assetTypeOut:&assetType];
                    message.rb_cachedTransferAmount = amount;
                    message.rb_cachedTransferRemark = remark;
                    message.rb_cachedTransferAssetType = assetType;
                }
                BOOL isOutgoing = [message.senderId isEqualToString:[IMClientManager sharedInstance].localUserInfo.user_uid];
                NSString *cardTimeText = [self rb_timeTextForMoneyCardMessage:message];
                UIView *transferView = [self rb_transferCardViewWithAmount:amount ?: @"0.00"
                                                                    remark:remark
                                                                isOutgoing:isOutgoing
                                                                  timeText:cardTimeText
                                                                      size:CGSizeMake(kRBMoneyCardWidth, kRBMoneyCardHeight)];
                transferView.tag = kTransferCardViewTag;
                transferView.frame = CGRectMake(0, 0, cell.messageBubbleContainerView.bounds.size.width, cell.messageBubbleContainerView.bounds.size.height);
                transferView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [cell.messageBubbleContainerView addSubview:transferView];
                cell.textView.hidden = YES;
                cell.textView.attributedText = nil;
            }
            // ======== 通话记录消息：使用 SF Symbol 图标区分语音/视频 ========
            else if (message.msgType == TM_TYPE_VOIP_RECORD) {
                // ★ 优先 voipRecordMeta；若已丢失则解析并缓存到 message，避免同一条消息在 cell 复用时重复 JSON 解析
                VoipRecordMeta *vrm = message.voipRecordMeta;
                if (vrm == nil && message.text != nil && [message.text hasPrefix:@"{"]) {
                    vrm = [VoipRecordMeta fromJSON:message.text];
                    if (vrm == nil) vrm = [VoipRecordMeta fromServerCancelledJSON:message.text];
                    if (vrm != nil) message.voipRecordMeta = vrm;
                }
                BOOL isVideoCall = (vrm != nil && vrm.voipType == VOIP_TYPE_VIDEO);
                if (vrm == nil && message.text.length > 0 && [message.text containsString:@"视频"]) {
                    isVideoCall = YES; // text 已是展示文案（如「已取消视频通话」）时兜底
                }
                
                // 使用资源图标：视频/语音，缓存裁剪结果避免每条消息都在主线程 UIGraphics
                static UIImage *s_voipIconVideo = nil;
                static UIImage *s_voipIconVoice = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    CGFloat iconSize = 24.0f;
                    CGFloat scale = [UIScreen mainScreen].scale;
                    CGSize targetSize = CGSizeMake(iconSize * scale, iconSize * scale);
                    CGFloat cropRatio = 0.6f;
                    for (NSString *name in @[@"chat_voip_icon_video", @"chat_voip_icon_voice"]) {
                        UIImage *raw = [UIImage imageNamed:name];
                        if (raw) {
                            UIImage *img = [raw imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
                            UIGraphicsBeginImageContextWithOptions(targetSize, NO, scale);
                            CGFloat drawW = targetSize.width / cropRatio, drawH = targetSize.height / cropRatio;
                            [img drawInRect:CGRectMake(-(drawW - targetSize.width) * 0.5f, -(drawH - targetSize.height) * 0.5f, drawW, drawH)];
                            UIImage *cropped = UIGraphicsGetImageFromCurrentImageContext();
                            UIGraphicsEndImageContext();
                            if ([name isEqualToString:@"chat_voip_icon_video"]) s_voipIconVideo = cropped ? [cropped imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] : img;
                            else s_voipIconVoice = cropped ? [cropped imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] : img;
                        }
                    }
                });
                CGFloat iconSize = 24.0f;
                UIImage *iconImg = isVideoCall ? s_voipIconVideo : s_voipIconVoice;
                if (iconImg == nil) {
                    NSString *iconName = isVideoCall ? @"chat_voip_icon_video" : @"chat_voip_icon_voice";
                    iconImg = [[UIImage imageNamed:iconName] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
                }
                if (iconImg == nil && @available(iOS 13.0, *)) {
                    NSString *sfName = isVideoCall ? @"video.fill" : @"phone.fill";
                    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
                    iconImg = [UIImage systemImageNamed:sfName withConfiguration:config];
                }
                
                UIFont *bubbleFont = collectionView.collectionViewLayout.messageBubbleFont;
                // 图标与文字同一水平：按字体中线对齐 attachment 的垂直位置
                CGFloat textCenterY = (bubbleFont.ascender + bubbleFont.descender) * 0.5f;
                CGFloat iconOriginY = textCenterY - iconSize * 0.5f;

                NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
                attachment.image = iconImg;
                attachment.bounds = CGRectMake(0, iconOriginY, iconSize, iconSize);

                BOOL voipOutgoing = [message isOutgoing];
                UIColor *voipTextColor = voipOutgoing ? [UIColor blackColor] : [UIColor blackColor];
                NSDictionary *textAttrs = @{
                    NSFontAttributeName : bubbleFont,
                    NSForegroundColorAttributeName : voipTextColor
                };

                NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] init];
                [attrStr appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
                [attrStr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", message.text]
                                                                               attributes:textAttrs]];
                // 整体往上偏移，使图标+文字显示在气泡垂直中间
                [attrStr addAttribute:NSBaselineOffsetAttributeName value:@(0) range:NSMakeRange(0, attrStr.length)];

                cell.textView.attributedText = attrStr;
                cell.textView.textColor = voipTextColor;
            }
            // ======== 普通文本消息 ========
            else {
                // 设置自动识别的各种链接的字体颜色（我方气泡改为浅色底）
                BOOL textOutgoing = [message isOutgoing];
                cell.textView.linkTextAttributes = textOutgoing
                    ? @{ NSForegroundColorAttributeName : HexColor(0x0078fe),
                         NSUnderlineStyleAttributeName : @(NSUnderlineStyleNone | NSUnderlinePatternSolid),
                         NSUnderlineColorAttributeName : [UIColor clearColor] }
                    : @{ NSForegroundColorAttributeName : HexColor(0x0078fe),
                         NSUnderlineStyleAttributeName : @(NSUnderlineStyleNone | NSUnderlinePatternSolid),
                         NSUnderlineColorAttributeName : [UIColor clearColor] };
                
                UIFont *bubbleFont = collectionView.collectionViewLayout.messageBubbleFont;
                CGFloat targetLineHeight = (CGFloat)ceil(MAX(bubbleFont.lineHeight, bubbleFont.pointSize * 1.25f));
                NSAttributedString *renderedText = [self rb_renderedTextForMessage:message bubbleFont:bubbleFont lineHeight:targetLineHeight];
                cell.textView.delegate = self;
                cell.textView.attributedText = renderedText;
                
    //          NSLog(@"------消息内容富文本=%@",cell.textView.attributedText);
                
                if (!(self.chatType == CHAT_TYPE_GROUP_CHAT && renderedText.length > 0)) {
                    cell.textView.textColor = [message isOutgoing] ? [UIColor blackColor] : [UIColor blackColor];
                }
            }
        }
        
        // 气泡上不再预留时间和消息回执的空间（已去掉末尾 NBSP 占位）

        // ====== 气泡内时间+已读状态 ======
        [self jsq_configureBubbleTimeStatus:cell withMessage:message];
        
        // ====== 发送中(1分钟内)气泡外显示转圈；超1分钟失败显示红色感叹号，点击重发 ======
        static const NSInteger kResendExclamationTag = 9000;
        static const NSInteger kSendingSpinnerTag = 9001;
        UIView *oldInBubble = [cell.messageBubbleContainerView viewWithTag:kResendExclamationTag];
        if (oldInBubble) [oldInBubble removeFromSuperview];
        UIView *oldSpinnerInBubble = [cell.messageBubbleContainerView viewWithTag:kSendingSpinnerTag];
        if (oldSpinnerInBubble) [oldSpinnerInBubble removeFromSuperview];
        // 收藏夹（10001）不显示发送转圈与失败重发按钮
        BOOL isFavorites10001 = [self.toId isEqualToString:@"10001"];
        BOOL showSendingSpinner = !isFavorites10001 && [message isOutgoing] && (message.sendStatus == SendStatus_SNEDING);
        BOOL showResendExclamation = !isFavorites10001 && [message isOutgoing] && (message.sendStatus == SendStatus_SEND_FAILD || (message.sendStatusSecondary == SendStatusSecondary_PROCESS_FAILD));
        UIActivityIndicatorView *spinner = (UIActivityIndicatorView *)[cell.contentView viewWithTag:kSendingSpinnerTag];
        if (showSendingSpinner) {
            if (!spinner) {
                spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
                spinner.tag = kSendingSpinnerTag;
                [cell.contentView addSubview:spinner];
            }
            [spinner startAnimating];
            CGFloat size = 20.f;
            CGFloat pad = 6.f;
            [cell setNeedsLayout];
            [cell layoutIfNeeded];
            CGRect bubbleFrame = cell.messageBubbleContainerView.frame;
            CGFloat x = CGRectGetMinX(bubbleFrame) - size - pad;
            CGFloat y = CGRectGetMidY(bubbleFrame) - size / 2.f;
            if (x < 2.f) x = 2.f;
            if (CGRectGetHeight(bubbleFrame) > 0.f) {
                spinner.frame = CGRectMake(x, y, size, size);
            } else {
                spinner.frame = CGRectMake(pad, (cell.contentView.bounds.size.height - size) / 2.f, size, size);
            }
            spinner.hidden = NO;
            [cell.contentView bringSubviewToFront:spinner];
        } else {
            if (spinner) { [spinner stopAnimating]; spinner.hidden = YES; }
        }
        UIButton *resendBtn = (UIButton *)[cell.contentView viewWithTag:kResendExclamationTag];
        if (showResendExclamation) {
            if (!resendBtn) {
                resendBtn = [UIButton buttonWithType:UIButtonTypeCustom];
                resendBtn.tag = kResendExclamationTag;
                resendBtn.backgroundColor = HexColor(0xff0000);
                resendBtn.layer.cornerRadius = 10.f;
                resendBtn.clipsToBounds = YES;
                [resendBtn setTitle:@"!" forState:UIControlStateNormal];
                [resendBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                resendBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14.f];
                [resendBtn addTarget:self action:@selector(jsq_onResendFailedMessageTap:) forControlEvents:UIControlEventTouchUpInside];
                [cell.contentView addSubview:resendBtn];
            }
            CGFloat size = 20.f;
            CGFloat pad = 6.f;
            [cell setNeedsLayout];
            [cell layoutIfNeeded];
            CGRect bubbleFrame = cell.messageBubbleContainerView.frame;
            CGFloat x = CGRectGetMinX(bubbleFrame) - size - pad;
            CGFloat y = CGRectGetMidY(bubbleFrame) - size / 2.f;
            if (x < 2.f) x = 2.f;
            if (CGRectGetHeight(bubbleFrame) > 0.f) {
                resendBtn.frame = CGRectMake(x, y, size, size);
            } else {
                resendBtn.frame = CGRectMake(pad, (cell.contentView.bounds.size.height - size) / 2.f, size, size);
            }
            resendBtn.hidden = NO;
            [cell.contentView bringSubviewToFront:resendBtn];
        } else {
            if (resendBtn) resendBtn.hidden = YES;
        }
        
        // ====== 多选模式状态配置 ======
        cell.multiSelectMode = self.isMultiSelectMode;
        if(self.isMultiSelectMode && message.fingerPrintOfProtocal != nil) {
            cell.multiSelected = [self.multiSelectedFingerprints containsObject:message.fingerPrintOfProtocal];
        }
    }

    // 系统通知、撤回消息等：纯文字（无液态胶囊/毛玻璃）
    if ([theCell isKindOfClass:[rbSystemInfoCollectionViewCell class]]) {
        rbSystemInfoCollectionViewCell *cell = (rbSystemInfoCollectionViewCell *)theCell;
        static const NSInteger kSystemInfoPillTag = 9998;
        UIView *existingPill = [cell.messageBubbleContainerView viewWithTag:kSystemInfoPillTag];
        [existingPill removeFromSuperview];
        cell.messageBubbleImageView.hidden = YES;
        UIView *container = cell.messageBubbleContainerView;
        container.layer.shadowOpacity = 0.0f;
        container.layer.shadowColor = nil;
        theCell.contentView.layer.shadowOpacity = 0.0f;
        theCell.contentView.layer.shadowColor = nil;
        [container bringSubviewToFront:cell.textView];
        cell.textView.backgroundColor = [UIColor clearColor];
        cell.textView.layer.zPosition = 1.0f;
        cell.textView.textColor = [UIColor blackColor];
    }

    return theCell;
}



//---------------------------------------------------------------------------------------------------
#pragma mark - Adjusting cell label heights（聊天列表的ui布局的相关代理方法）

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return [[self rb_layoutMetaForMessageAtIndex:indexPath.item][@"top"] ?: @(0.0f) doubleValue];
}

static const CGFloat kRBNicknameLabelHeight = 17.0f;

/**
 控制昵称的显示，0表示不显示。
 */
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellNicknameLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return [[self rb_layoutMetaForMessageAtIndex:indexPath.item][@"nickname"] ?: @(0.0f) doubleValue];
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return [[self rb_layoutMetaForMessageAtIndex:indexPath.item][@"bottom"] ?: @(0.0f) doubleValue];
}

// 消息引用内容的顶级容器顶部与消息气泡间的空白
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout topGapForQuoteContainerAtIndexPath:(NSIndexPath *)indexPath
{
    return [[self rb_layoutMetaForMessageAtIndex:indexPath.item][@"quoteTopGap"] ?: @(0.0f) doubleValue];
}

// 消息引用内容的顶级容器高度
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForQuoteContainerAtIndexPath:(NSIndexPath *)indexPath
{
    return [[self rb_layoutMetaForMessageAtIndex:indexPath.item][@"quoteHeight"] ?: @(0.0f) doubleValue];
}

// 消息引用内容的图标容器高度（当需要显示图标时，请返回相应的值）
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout widthForQuoteIconContainerAtIndexPath:(NSIndexPath *)indexPath
{
    return [[self rb_layoutMetaForMessageAtIndex:indexPath.item][@"quoteIconWidth"] ?: @(0.0f) doubleValue];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - Responding to collection view tap events（聊天列表的点击或长按事件代理方法）

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
                header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender
{
}

// 点击消息气泡边上的头像事件处理方法
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapAvatarImageView:(UIImageView *)avatarImageView atIndexPath:(NSIndexPath *)indexPath
{
    // 多选模式下：点击头像也切换选中状态
    if(self.isMultiSelectMode) {
        JSQMessage *entity = [self rb_safeMessageAtIndex:indexPath.item];
        if(entity != nil && entity.fingerPrintOfProtocal != nil) {
            NSString *fp = entity.fingerPrintOfProtocal;
            if([self.multiSelectedFingerprints containsObject:fp]) {
                [self.multiSelectedFingerprints removeObject:fp];
            } else {
                [self.multiSelectedFingerprints addObject:fp];
            }
            [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
            [self updateMultiSelectToolbarState];
        }
        return;
    }

    JSQMessage *entity = [self rb_safeMessageAtIndex:indexPath.item];
    if (!entity) return;

    // 仅在与 10001 对话时，对“来源头像”做特殊处理
    if (self.chatType == CHAT_TYPE_FREIDN_CHAT
        && self.toId != nil
        && [self.toId isEqualToString:@"10001"]
        && entity.quote_sender_uid != nil
        && entity.quote_sender_uid.length > 0) {

        NSString *sourceUid = entity.quote_sender_uid;

        // 如果来源人就是我自己，复用原有逻辑：打开个人中心
        NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        if (localUid != nil && [sourceUid isEqualToString:localUid]) {
            [ViewControllerFactory goUserViewController:self.navigationController];
            return;
        }

        // 仅当来源人在好友列表中时，才允许查看资料；否则静默返回
        FriendsListProvider *flp = [[IMClientManager sharedInstance] getFriendsListProvider];
        if (flp != nil && [flp isUserInRoster2:sourceUid]) {
            [QueryFriendInfoAsync gotoWatchUserInfo:sourceUid
                                           withInfo:nil
                                                nav:self.navigationController
                                               view:self.view
                                                 vc:self];
        }
        return;
    }
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
    if ([self rb_handleMentionURL:URL]) {
        return NO;
    }
    return YES;
}

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange interaction:(UITextItemInteraction)interaction
{
    if ([self rb_handleMentionURL:URL]) {
        return NO;
    }
    return YES;
}

#pragma mark - 视频/动态头像按可见性暂停与恢复（避免离屏仍播放导致卡顿）

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:[JSQMessagesCollectionViewCell class]]) {
        UIImageView *avatarImageView = [(JSQMessagesCollectionViewCell *)cell avatarImageView];
        [RBAvatarView resumeVideoForAvatarInImageView:avatarImageView];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:[JSQMessagesCollectionViewCell class]]) {
        UIImageView *avatarImageView = [(JSQMessagesCollectionViewCell *)cell avatarImageView];
        [RBAvatarView pauseVideoForAvatarInImageView:avatarImageView];
    }
}

/**
 点击消息气泡的事件处理。
 */
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath
{
    // 多选模式下：切换选中状态
    if(self.isMultiSelectMode) {
        JSQMessage *entity = [self rb_safeMessageAtIndex:indexPath.item];
        if(entity != nil && entity.fingerPrintOfProtocal != nil) {
            NSString *fp = entity.fingerPrintOfProtocal;
            if([self.multiSelectedFingerprints containsObject:fp]) {
                [self.multiSelectedFingerprints removeObject:fp];
            } else {
                [self.multiSelectedFingerprints addObject:fp];
            }
            // 刷新对应cell
            [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
            [self updateMultiSelectToolbarState];
        }
        return;
    }

    JSQMessage *entity = [self rb_safeMessageAtIndex:indexPath.item];
    [self didTapMessageBubble:entity orClickedTheQuote:NO currentMessageIndex:indexPath.item];
}

// 点击消息气泡或消息引用内容的事件处理实现方法
- (void)didTapMessageBubble:(JSQMessage *)entity orClickedTheQuote:(BOOL)clickedTheQuote currentMessageIndex:(NSInteger)currentMessageIndex
{
    if(entity == nil) {
        [BasicTool showAlertWarn:@"无效的消息数据对象！" parent:self];
        return;
    }
    
    // 点击的是引用消息内容，且原消息已被撤回，则不能查看内容哦
    if(clickedTheQuote && entity.quote_status == 1) {
        [BasicTool showAlertWarn:@"原消息已被撤回，无法查看！" parent:self];
        return;
    }
    
    // 点击引用区域：优先跳回原消息并高亮；若当前内存中没有，则尝试从 SQLite 把锚点消息及其后的消息补载进来。
    if (clickedTheQuote) {
        NSString *quotedFp = [BasicTool trim:entity.quote_fp];
        if (quotedFp.length == 0) {
            [APP showUserDefineToast_OK:@"未找到被引用的原消息"];
            return;
        }

        self.rb_animateHighlightScrollOnce = YES;
        self.highlightOnceMsgFingerprint = quotedFp;
        if ([self doHighlightOnceMessage]) {
            return;
        }

        MessagesProvider *msgProvider = [MessagesProvider getMessageProiderInstance:self.chatType];
        if (msgProvider == nil || self.toId.length == 0) {
            self.rb_animateHighlightScrollOnce = NO;
            self.highlightOnceMsgFingerprint = nil;
            [APP showUserDefineToast_OK:@"未找到被引用的原消息"];
            return;
        }

        __weak typeof(self) wself = self;
        [msgProvider loadMoreMessages:self.toId afterAndFingerPrint:quotedFp limit:NO complete:^(BOOL sucess) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) sself = wself;
                if (!sself) return;
                if (!sucess) {
                    sself.rb_animateHighlightScrollOnce = NO;
                    sself.highlightOnceMsgFingerprint = nil;
                    [APP showUserDefineToast_OK:@"未找到被引用的原消息"];
                    return;
                }
                [sself sortCurrentSessionMessagesIfNeeded];
                [sself refreshCollectionView];
                if (![sself doHighlightOnceMessage]) {
                    sself.rb_animateHighlightScrollOnce = NO;
                    sself.highlightOnceMsgFingerprint = nil;
                    [APP showUserDefineToast_OK:@"未找到被引用的原消息"];
                }
            });
        }];
        return;
    }
    
    int msgType = (clickedTheQuote ? entity.quote_type : entity.msgType);
    NSString *msgContent = (clickedTheQuote ? entity.quote_content : entity.text);
    
    // 短视频：直接进播放器自动播放；图片：统一媒体浏览器
    if (msgType == TM_TYPE_SHORTVIDEO) {
        [self openShortVideoDirectPlaybackForTappedMessageAtIndex:currentMessageIndex];
    } else if (msgType == TM_TYPE_IMAGE) {
        [self openUnifiedMediaBrowserForCurrentMessage:currentMessageIndex clickedQuote:clickedTheQuote entity:entity];
    }
    // 点击的是语言留言消息
    else if(msgType == TM_TYPE_VOICE)
    {
        // 如果点击的是被引用的语音消息，则要找到原语音消息的对象，接下来的播放要在原对象上处理（这是参照微信的功能逻辑实现的！）
        JSQMessage *beQuoteEntity = nil;
        if(clickedTheQuote) {
            if (self.chatType == CHAT_TYPE_FREIDN_CHAT || self.chatType == CHAT_TYPE_GUEST_CHAT) {
                beQuoteEntity = [[[IMClientManager sharedInstance] getMessagesProvider] findMessageByFingerPrint:self.toId fp:entity.quote_fp];
            } else if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
                beQuoteEntity = [[[IMClientManager sharedInstance] getGroupsMessagesProvider] findMessageByParentFingerPrint:self.toId fp:entity.quote_fp];
            }
            
            if(beQuoteEntity == nil) {
                [BasicTool showAlertWarn:@"原语音消息内容已不存在（可能被删除），无法查看！" parent:self];
                return;
            }
            
            if(beQuoteEntity.media != nil) {
                // 执行点击事件
                [((JSQAudioMediaItem *)beQuoteEntity.media) onPlayButton:nil];
            }
        }
    }
    // 点击的是大文件消息
    else if(msgType == TM_TYPE_FILE)
    {
        // 文件消息的内容里存放的是对象转json后的文本
        FileMeta *fileMeta = [FileMeta fromJSON:msgContent];
        if(fileMeta != nil)
        {
//          // “我”发出的文件，就不需要下载了，直接本地读取
//          BOOL isCome = ![entity isOutgoing];
                
            // 不管是“我”收到的文件还是发出的文件，都会处于本app自已的沙箱中（发出的文件如果涉及跨沙箱文件，
            // 则会被首先复制到本app的沙箱中，防止因ios文件系统安全机制导致的原沙箱目录变更而无法读取文件）
            NSString *fileDir = [ReceivedFileHelper getReceivedFileSavedDir];
            
            // 从文件下载界面回来时，不需要自动滚动到聊天列表最底部，不然如果刚才看的文件是位于列表的上部时，每次回来想再看还得再往上翻页，影响体验
            super.automaticallyScrollsToMostRecentMessage_ignoreOnce = YES;
            
            // 进入文件下载/查看界面
            [ViewControllerFactory goBigFileViewerController:self.navigationController
                                                    fileName:fileMeta.fileName
                                                     fileDir:fileDir
                                                     fileMd5:fileMeta.fileMd5
                                                  fileLength:fileMeta.fileLength
             // v9.0开始，因支持消息转发功能，所以此条"发出的"文件消息，可能来自于接收到的文件消息，
             // 而此时接收到的文件消息并未完成文件下载，则此条因转发而"发出的"消息，显示不能跟正常发
             // 出的文件消息一样的逻辑。于是，从v9.0开始，为了解决因转发而"发出的"的文件消息，所以
             // 无条件设置canDownload为true，也就是允许因转发而"发出的"的文件消息在查看时也能下载
                                                 canDownload:YES//(isCome?YES:NO)
            ];
        }
    }
    // 点击的是名片消息
    else if(msgType == TM_TYPE_CONTACT)
    {
        // 名片消息的内容里存放的是对象转json后的文本
        ContactMeta *contactMeta = [ContactMeta fromJSON:msgContent];
        if(contactMeta != nil && contactMeta.uid != nil)
        {
            // 从用户信息查看界面回来时，不需要自动滚动到聊天列表最底部，不然如果刚才看的文件是位于列表的上部时，每次回来想再看还得再往上翻页，影响体验
            super.automaticallyScrollsToMostRecentMessage_ignoreOnce = YES;
            
            if(contactMeta.type == CONTACT_TYPE_USER) {
                // 查询并查看该名片用户的最新信息（来源：名片推荐）
//              [QueryFriendInfoAsync doIt:NO mail:nil uid:contactMeta.uid hudParentView:self.view withNC:self.navigationController canOpenChat:YES];
                [QueryFriendInfoAsync gotoWatchUserInfo:contactMeta.uid withInfo:nil nav:self.navigationController view:self.view vc:self addSource:@"card"];
            } else {
                NSString *value = [QRCodeScheme constructJoinGroupCodeSubStr:contactMeta.uid sharedByUid:entity.senderId];
                // 进入加群界面
                [ViewControllerFactory goJoinGroupViewController:self.navigationController with:value joinBy:JOIN_BY_GROUP_CONTACT];
            }
        }
    }
    // 点击的是位置消息
    else if(msgType == TM_TYPE_LOCATION)
    {
        // 位置消息中的消息内容存放的是LocationMeta对象的JSON字串形式
        LocationMeta *locationMeta = [LocationMeta fromJSON:msgContent];
        if(locationMeta != nil) {
            // 从查看位置界面回来时，不需要自动滚动到聊天列表最底部，不然如果刚才看的文件是位于列表的上部时，每次回来想再看还得再往上翻页，影响体验
            super.automaticallyScrollsToMostRecentMessage_ignoreOnce = YES;
            // 查看位置
            [ViewControllerFactory goViewLocationViewController:self.navigationController dest:locationMeta];
        }
    }
    // 点击红包消息 → 群聊：已领过直接进详情，未领过先抢再进详情；单聊直接进详情（按 msgType 或 content 为红包 JSON 兜底）
    else if(msgType == TM_TYPE_RED_PACKET || rb_isRedPacketContent(msgContent))
    {
        NSString *packetId = nil;
        if (msgContent.length > 0) {
            NSData *data = [msgContent dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([dict isKindOfClass:[NSDictionary class]]) {
                packetId = rb_safeStringFromRedPacketDict(dict, @"packet_id");
            }
        }
        if (packetId.length > 0) {
            super.automaticallyScrollsToMostRecentMessage_ignoreOnce = YES;
            __weak typeof(self) wself = self;
            void (^pushRedPacketDetail)(void) = ^{
                WalletRedPacketDetailViewController *vc = [[WalletRedPacketDetailViewController alloc] init];
                vc.packetId = packetId;
                if (msgContent.length > 0) {
                    NSData *rawData = [msgContent dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *rawDict = [NSJSONSerialization JSONObjectWithData:rawData options:0 error:nil];
                    if ([rawDict isKindOfClass:[NSDictionary class]]) {
                        vc.assetTypeHint = rb_safeStringFromRedPacketDict(rawDict, @"asset_type");
                    }
                }
                vc.hidesBottomBarWhenPushed = YES;
                [wself.navigationController pushViewController:vc animated:YES];
            };
            void (^showRedPacketPopup)(void) = ^{
                RedPacketPopupViewController *popup = [[RedPacketPopupViewController alloc] initWithPacketId:packetId];
                __weak RedPacketPopupViewController *wpopup = popup;
                popup.onDismissBlock = ^(BOOL openDetail) {
                    [UIView animateWithDuration:0.2 animations:^{ wpopup.view.alpha = 0; } completion:^(BOOL finished) {
                        [wpopup.view removeFromSuperview];
                        [wpopup removeFromParentViewController];
                        if (openDetail) pushRedPacketDetail();
                    }];
                };
                [wself addChildViewController:popup];
                popup.view.frame = wself.view.bounds;
                popup.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                popup.view.alpha = 0;
                [wself.view addSubview:popup.view];
                [popup didMoveToParentViewController:wself];
                [UIView animateWithDuration:0.25 animations:^{ popup.view.alpha = 1; }];
            };
            // 先拉详情：已领取则直接进详情页，未领取则显示弹窗（可领取时点弹窗再进详情）
            [[HttpRestHelper sharedInstance] submitWalletGetRedPacketDetail:packetId complete:^(BOOL sucess, NSDictionary *data) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid ?: @"";
                    BOOL alreadyGrabbed = NO;
                    if (sucess && data && localUid.length > 0) {
                        NSArray *receives = data[@"receives"];
                        if ([receives isKindOfClass:[NSArray class]]) {
                            for (NSDictionary *rec in receives) {
                                NSString *ruid = rec[@"receiver_uid"] ? [rec[@"receiver_uid"] description] : @"";
                                if ([ruid isEqualToString:localUid]) {
                                    alreadyGrabbed = YES;
                                    break;
                                }
                            }
                        }
                    }
                    if (alreadyGrabbed) {
                        pushRedPacketDetail();
                    } else {
                        showRedPacketPopup();
                    }
                });
            } hudParentView:self.view];
        }
    }
    // 点击转账消息 → 进入转账详情页（按 msgType 或 content 为转账 JSON 兜底）
    else if(msgType == TM_TYPE_TRANSFER || rb_isTransferContent(msgContent))
    {
        NSString *amount = nil;
        NSString *remark = nil;
        NSString *assetType = nil;
        [self rb_parseTransferFromJSON:msgContent amountOut:&amount remarkOut:&remark assetTypeOut:&assetType];
        super.automaticallyScrollsToMostRecentMessage_ignoreOnce = YES;
        WalletTransferDetailViewController *vc = [[WalletTransferDetailViewController alloc] init];
        vc.amount = (amount.length > 0 ? amount : @"0.00");
        vc.assetType = assetType;
        vc.transferTime = entity.date;
        vc.receiptTime = entity.date;
        vc.isIncoming = ![entity isOutgoing];
        vc.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:vc animated:YES];
    }
    // 点击通话记录消息 → 发起同类型的通话
    else if(msgType == TM_TYPE_VOIP_RECORD)
    {
        // 仅在好友聊天中支持点击拨打（群聊/临时聊天中不适用）
        if (self.chatType == CHAT_TYPE_FREIDN_CHAT) {
            // ★ 优先从缓存的 voipRecordMeta 获取通话类型（最可靠），
            //   其次尝试解析 JSON，最后兜底用 text 字符串匹配
            CallType tapCallType = CallTypeVoice;
            if (entity.voipRecordMeta != nil) {
                tapCallType = (entity.voipRecordMeta.voipType == VOIP_TYPE_VIDEO) ? CallTypeVideo : CallTypeVoice;
            } else if (msgContent != nil && [msgContent hasPrefix:@"{"]) {
                VoipRecordMeta *vrm = [VoipRecordMeta fromJSON:msgContent];
                if (vrm == nil) vrm = [VoipRecordMeta fromServerCancelledJSON:msgContent];
                if (vrm != nil) {
                    tapCallType = (vrm.voipType == VOIP_TYPE_VIDEO) ? CallTypeVideo : CallTypeVoice;
                }
            } else if ([msgContent containsString:@"视频通话"]) {
                tapCallType = CallTypeVideo;
            }
            
            if ([[CallManager sharedInstance] isInCall]) {
                [BasicTool showAlertInfo:@"当前正在通话中，请先结束当前通话" parent:self];
            } else {
                // 点击音视频气泡直接同类型拨出，不再弹确认框
                [[CallManager sharedInstance] startCall:self.toId remoteNickname:self.toName callType:tapCallType];
                [ViewControllerFactory goCallViewController:self.toId
                                        remoteUserNickname:self.toName
                                                  callType:tapCallType
                                                  isCaller:YES];
            }
        }
    }
    else {
        // 如果被引用的消息是文字消息，则弹个框显示原消息内容
        if(clickedTheQuote && msgType == TM_TYPE_TEXT && ![BasicTool isStringEmpty:entity.quote_content]) {
            NSAttributedString *attributedText = [self rb_renderedQuoteText:entity.quote_content
                                                                       font:[BasicTool getSystemFontOfSize:13]
                                                                  cacheHost:entity];
            // 显示之
            [BasicTool showAlert:@"被引用的消息内容" content:attributedText btnTitle:@"确定" parent:self];
        }
    }
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapCellAtIndexPath:(NSIndexPath *)indexPath touchLocation:(CGPoint)touchLocation
{
//    NSLog(@"Tapped cell at %@!", NSStringFromCGPoint(touchLocation));
    
    // 多选模式下：点击cell空白区域也切换选中状态
    if(self.isMultiSelectMode) {
        JSQMessage *entity = [self rb_safeMessageAtIndex:indexPath.item];
        if(entity != nil && entity.fingerPrintOfProtocal != nil) {
            NSString *fp = entity.fingerPrintOfProtocal;
            if([self.multiSelectedFingerprints containsObject:fp]) {
                [self.multiSelectedFingerprints removeObject:fp];
            } else {
                [self.multiSelectedFingerprints addObject:fp];
            }
            [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
            [self updateMultiSelectToolbarState];
        }
    }
}



//---------------------------------------------------------------------------------------------------
#pragma mark - 消息”高亮”功能对应的方法（当前主要用于搜索功能中进入聊天界面时）

- (void)rb_reloadHighlightTransitionAtIndexPaths:(NSArray<NSIndexPath *> *)paths
{
    if (paths.count == 0) return;
    NSInteger listCount = (NSInteger)[self getChattingDatasList].count;
    NSInteger cvCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
    if (self.collectionView.window && listCount > 0 && listCount == cvCount) {
        [self rb_reloadItemsImmediatelyAtIndexPaths:paths];
    } else {
        [self rb_invalidateChattingListLayoutCache];
        [self.collectionView reloadData];
        [self.collectionView layoutIfNeeded];
    }
}

- (void)rb_scrollHighlightedMessageToVisibleAtIndexPath:(NSIndexPath *)targetPath
{
    if (targetPath == nil) return;
    BOOL animated = self.rb_animateHighlightScrollOnce;
    self.rb_animateHighlightScrollOnce = NO;
    [self jsq_updateCollectionViewInsets];
    [self.collectionView layoutIfNeeded];
    UICollectionViewLayoutAttributes *attrs = [self.collectionView layoutAttributesForItemAtIndexPath:targetPath];
    if (!attrs) {
        [self scrollToIndexPath:targetPath animated:animated];
        return;
    }

    CGFloat topInset = self.collectionView.safeAreaInsets.top + kChatSearchBarVisibleHeight;
    CGFloat desiredY = attrs.frame.origin.y - topInset;
    CGFloat minY = -self.collectionView.contentInset.top;
    CGFloat maxY = self.collectionView.contentSize.height - self.collectionView.bounds.size.height + self.collectionView.contentInset.bottom;
    desiredY = MAX(minY, MIN(desiredY, maxY));
    CGPoint targetOffset = CGPointMake(0, desiredY);
    if (!animated) {
        self.collectionView.contentOffset = targetOffset;
        return;
    }
    [self rb_scrollChatCollectionViewContentOffsetSegmentedTo:targetOffset];
}

- (BOOL)rb_applyHighlightOnceForMessage:(JSQMessage *)message
                                atIndex:(NSInteger)targetIndex
                                 inList:(NSArray<JSQMessage *> *)list
{
    if (message == nil || list.count == 0 || targetIndex == NSNotFound || targetIndex < 0 || targetIndex >= (NSInteger)list.count) {
        return NO;
    }

    NSMutableArray<NSIndexPath *> *pathsToReload = [NSMutableArray array];
    NSIndexPath *targetPath = [NSIndexPath indexPathForItem:targetIndex inSection:0];
    for (NSInteger i = 0; i < (NSInteger)list.count; i++) {
        JSQMessage *candidate = list[i];
        BOOL shouldHighlight = (candidate == message);
        if (candidate.highlightOnce != shouldHighlight) {
            candidate.highlightOnce = shouldHighlight;
            [pathsToReload addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        }
    }
    if (pathsToReload.count == 0) {
        [pathsToReload addObject:targetPath];
    }

    [self rb_reloadHighlightTransitionAtIndexPaths:pathsToReload];
    NSInteger itemCount = [self.collectionView numberOfItemsInSection:0];
    if (itemCount < 1) {
        message.highlightOnce = NO;
        return NO;
    }

    NSInteger clamped = MIN(MAX(targetIndex, 0), itemCount - 1);
    targetPath = [NSIndexPath indexPathForItem:clamped inSection:0];
    [self rb_scrollHighlightedMessageToVisibleAtIndexPath:targetPath];

    __weak typeof(self) wself = self;
    __weak JSQMessage *weakMessage = message;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wself) sself = wself;
        JSQMessage *msgToUnhighlight = weakMessage;
        if (!sself || !msgToUnhighlight) return;
        if (!msgToUnhighlight.highlightOnce) return;
        msgToUnhighlight.highlightOnce = NO;
        [sself rb_reloadHighlightTransitionAtIndexPaths:@[targetPath]];
    });
    return YES;
}

// 搜索跳转首批消息未命中目标 fp 时，再从本地库补载一页「包含该 fp 的窗口」。
- (BOOL)rb_tryRecoverSearchJumpContextIfNeededWithFingerprint:(NSString *)fingerprint
{
    NSString *targetFp = [BasicTool trim:fingerprint];
    NSString *chatUid = [BasicTool trim:self.toId];
    if (targetFp.length == 0 || chatUid.length == 0) {
        NSLog(@"【RB-SEARCH-JUMP】recover skip bad params toId=%@ fp=%@", chatUid, targetFp);
        return NO;
    }
    if (![self.rb_searchJumpRecoveryFingerprint isEqualToString:targetFp]) {
        self.rb_searchJumpRecoveryFingerprint = [targetFp copy];
        self.rb_searchJumpRecoveryAttemptCount = 0;
        self.rb_searchJumpContextLoadInFlight = NO;
    }
    if (self.rb_searchJumpContextLoadInFlight) {
        NSLog(@"【RB-SEARCH-JUMP】recover skip already in-flight toId=%@ fp=%@", chatUid, targetFp);
        return YES;
    }
    if (self.rb_searchJumpRecoveryAttemptCount >= 1) {
        NSLog(@"【RB-SEARCH-JUMP】recover skip reached max attempts toId=%@ fp=%@", chatUid, targetFp);
        return NO;
    }
    MessagesProvider *provider = [MessagesProvider getMessageProiderInstance:self.chatType];
    if (provider == nil) {
        NSLog(@"【RB-SEARCH-JUMP】recover skip provider nil chatType=%d toId=%@", self.chatType, chatUid);
        return NO;
    }
    NSMutableArrayObservableEx *bucket = [provider getMessages:chatUid];
    if (bucket == nil) {
        NSLog(@"【RB-SEARCH-JUMP】recover skip bucket nil toId=%@", chatUid);
        return NO;
    }

    self.rb_searchJumpRecoveryAttemptCount += 1;
    self.rb_searchJumpContextLoadInFlight = YES;
    NSDate *anchorDate = self.highlightAnchorMessageDate;
    BOOL useAnchorDate = (anchorDate != nil);
    long anchorMillis = useAnchorDate ? ((long)[TimeTool javaMillisFromNSDate:anchorDate] + 1L) : 0L;
    NSLog(@"【RB-SEARCH-JUMP】recover start toId=%@ fp=%@ mode=%@ anchorTs=%.0f",
          chatUid, targetFp, useAnchorDate ? @"anchorDate" : @"afterFpFallback", [anchorDate timeIntervalSince1970]);
    [self rb_evaluateChatFirstScreenSkeletonCover];

    __weak typeof(self) wself = self;
    void (^finishRecover)(BOOL) = ^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (!sself) {
                return;
            }
            sself.rb_searchJumpContextLoadInFlight = NO;
            [sself refreshCollectionView];
            BOOL highlighted = [sself doHighlightOnceMessage];
            [sself rb_evaluateChatFirstScreenSkeletonCover];
            NSLog(@"【RB-SEARCH-JUMP】recover finish toId=%@ fp=%@ success=%d highlighted=%d",
                  chatUid, targetFp, success ? 1 : 0, highlighted ? 1 : 0);
        });
    };
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (useAnchorDate) {
            [provider loadHistory:bucket
                           forUid:chatUid
              afterAndFingerPrint:nil
                beforeFingerPrint:nil
                   beforeDatetime:anchorMillis
                            limit:YES
                         complete:finishRecover];
        } else {
            [provider loadMoreMessages:chatUid afterAndFingerPrint:targetFp limit:YES complete:finishRecover];
        }
    });
    return YES;
}

// 设置指定的消息高亮显示一次、并让该条消息滚动到列表可视区（高亮特性目前仅用于搜索功能进到聊天界面时，设置搜索到到的包含关键字的消）
- (BOOL)doHighlightOnceMessage {
    BOOL sucess = NO;
    @try {
        NSString *fpForMessage = [self.highlightOnceMsgFingerprint copy];
        NSLog(@"【RB-SEARCH-JUMP】doHighlightOnce enter chatType=%d toId=%@ fp=%@", self.chatType, self.toId ?: @"-", [BasicTool trim:fpForMessage]);
        if (fpForMessage == nil || self.toId == nil) {
            DLogWarn(@"doHighlightOnceMessage()时无法继续，无效的参数：chatType=%d，fpForMessage=%@，forId=%@", self.chatType, fpForMessage, self.toId);
            NSLog(@"【RB-SEARCH-JUMP】doHighlightOnce ABORT bad params");
            return NO;
        }
        
        // 10001 收藏夹：列表与单聊一致为 getChattingDatasList（IM 会话），按 fp 查找并滚动到该条
        if ([self.toId isEqualToString:@"10001"]) {
            NSArray *list = [self getChattingDatasList];
            if (list == nil || list.count == 0) return NO; // 列表未加载完时保留 highlightOnceMsgFingerprint，由加载完成后再试
            NSInteger foundIndex = NSNotFound;
            for (NSInteger i = 0; i < (NSInteger)list.count; i++) {
                JSQMessage *msg = list[i];
                if ([msg isKindOfClass:[JSQMessage class]] && RBFingerprintStringsEqual(fpForMessage, msg.fingerPrintOfProtocal)) {
                    foundIndex = i;
                    break;
                }
            }
            if (foundIndex == NSNotFound) return NO;
            JSQMessage *msgToHighlight = list[foundIndex];
            sucess = [self rb_applyHighlightOnceForMessage:msgToHighlight atIndex:foundIndex inList:list];
            RBClearPendingSearchJumpFpForUid(self.toId);
            RBClearPendingSearchJumpAnchorDateForUid(self.toId);
            self.highlightOnceMsgFingerprint = nil;
            self.highlightAnchorMessageDate = nil;
            self.rb_searchJumpRecoveryAttemptCount = 0;
            self.rb_searchJumpRecoveryFingerprint = nil;
            self.rb_searchJumpContextLoadInFlight = NO;
            NSLog(@"【RB-SEARCH-JUMP】doHighlightOnce exit ok=1 case=10001");
            return YES;
        }
        
        // 普通会话：从 MessagesProvider 查找
        MessagesProvider *msgProvider = nil;
        if (self.chatType == CHAT_TYPE_FREIDN_CHAT || self.chatType == CHAT_TYPE_GUEST_CHAT) {
            msgProvider = [[IMClientManager sharedInstance] getMessagesProvider];
        } else if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
            msgProvider = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
        } else {
            DLogWarn(@"无效的chatType=%d，doHighlightOnceMessage无法继续！", self.chatType);
            NSLog(@"【RB-SEARCH-JUMP】doHighlightOnce exit ok=0 badChatType");
            return NO;
        }
        NSMutableArrayObservableEx *list = [msgProvider getMessages:self.toId];
        if (list != nil) {
            for (JSQMessage *m in [list getDataList]) {
                m.highlightOnce = NO;
            }
        }
        FindResult *r = [msgProvider findMessageByFingerPrintX:self.toId fp:fpForMessage];
        if (r == nil || r.message == nil) {
            NSLog(@"【RB-SEARCH-JUMP】doHighlightOnce MISS fp not in memory list toId=%@ fp=%@ listCount=%lu",
                  self.toId, [BasicTool trim:fpForMessage],
                  (unsigned long)(list != nil ? [[list getDataList] count] : 0));
            (void)[self rb_tryRecoverSearchJumpContextIfNeededWithFingerprint:fpForMessage];
        }
        if (r != nil && r.message != nil) {
            sucess = [self rb_applyHighlightOnceForMessage:r.message atIndex:r.index inList:[list getDataList]];
            if (sucess) {
                RBClearPendingSearchJumpFpForUid(self.toId);
                RBClearPendingSearchJumpAnchorDateForUid(self.toId);
                self.highlightOnceMsgFingerprint = nil;
                self.highlightAnchorMessageDate = nil;
                self.rb_searchJumpRecoveryAttemptCount = 0;
                self.rb_searchJumpRecoveryFingerprint = nil;
                self.rb_searchJumpContextLoadInFlight = NO;
            }
        }
    } @catch (NSException *e){
        DLogWarn(@"doHighlightOnceMessage: 时发生Exception：%@", e);
        NSLog(@"【RB-SEARCH-JUMP】doHighlightOnce EXCEPTION %@", e);
    }

    NSLog(@"【RB-SEARCH-JUMP】doHighlightOnce exit ok=%d", sucess ? 1 : 0);
    return sucess;
}

/// 聊天页不用系统导航栏时，列表顶部留白与自定义顶栏高度一致（含状态栏下内容区）
- (CGFloat)jsq_topInsetWhenContentDoesNotFill
{
    if (self.rb_chromeNavigationBar && !self.rb_chromeNavigationBar.hidden) {
        [self.rb_chromeNavigationBar layoutIfNeeded];
        CGFloat h = CGRectGetHeight(self.rb_chromeNavigationBar.bounds);
        if (h > 0.5f) {
            return h;
        }
    }
    return [super jsq_topInsetWhenContentDoesNotFill];
}

/**
 * 重写 JSQ：原版在「消息内容足够一屏」时把顶部 inset 设为 0（允许穿过系统导航栏）。
 * 本页使用自定义顶栏叠在列表上方，若不预留与顶栏同高的 inset，滚到最旧消息时会被导航遮住。
 */
- (void)jsq_updateCollectionViewInsets
{
    CGFloat bottomValue = CGRectGetMaxY(self.collectionView.frame) - CGRectGetMinY(self.inputToolbar.frame);
    CGFloat visibleHeight = self.collectionView.bounds.size.height - bottomValue;
    CGFloat contentHeight = self.collectionView.contentSize.height;
    CGFloat navTopMin = [self jsq_topInsetWhenContentDoesNotFill];
    CGFloat addInset = self.topContentAdditionalInset;
    CGFloat topValue;
    if (visibleHeight <= 0.f) {
        topValue = navTopMin + addInset;
    } else if (contentHeight >= visibleHeight - 1.0f) {
        topValue = navTopMin + addInset;
    } else {
        CGFloat topForBottomAlign = visibleHeight - contentHeight;
        CGFloat minTop = navTopMin;
        topValue = MAX(minTop, topForBottomAlign) + addInset;
    }
    if (topValue == 0.f && contentHeight < visibleHeight - 1.0f) {
        topValue = 44.0f;
    }
    // 与 JSQ jsq_setCollectionViewInsetsTopValue:bottomValue: 一致（父类该方法未在头文件声明，子类不宜直接调）
    UIEdgeInsets insets = UIEdgeInsetsMake(topValue, 0.0f, bottomValue, 0.0f);
    self.collectionView.contentInset = insets;
    self.collectionView.scrollIndicatorInsets = insets;
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 自定义导航栏（气泡标题 + 返回badge + 头像按钮）

- (void)rb_ensureChatCustomNavigationBarInstalled
{
    [self rb_setupChatCustomNavBarIfNeeded];
}

- (void)rb_setupChatCustomNavBarIfNeeded
{
    if (self.rb_chromeNavigationBar) {
        return;
    }
    RBChromeNavigationBar *bar = [[RBChromeNavigationBar alloc] initWithBottomPinStyle:RBChromeNavigationBarBottomPinStyleBelowSystemSafeArea];
    [bar rb_applyChatWhiteTranslucentBackdrop];
    [bar installInHostView:self.view];
    [bar.multiSelectCancelButton addTarget:self action:@selector(exitMultiSelectMode) forControlEvents:UIControlEventTouchUpInside];
    self.rb_chromeNavigationBar = bar;
    self.rb_chromeNavigationBar.titleLabel.font = [BasicTool getBoldSystemFontOfSize:16.0f];
    self.rb_chromeNavigationBar.titleLabel.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
}

- (void)rb_clearChatCustomNavRightHost
{
    [self rb_setupChatCustomNavBarIfNeeded];
    if (!self.rb_chromeNavigationBar) {
        return;
    }
    [self.rb_chromeNavigationBar clearRightAccessorySubviews];
}

- (void)rb_attachViewToChatCustomNavRight:(UIView *)view
{
    [self rb_setupChatCustomNavBarIfNeeded];
    if (!view || !self.rb_chromeNavigationBar) {
        return;
    }
    [self.rb_chromeNavigationBar attachRightAccessoryView:view];
}

/// 圆形头像专用：固定正方形边长并垂直居中，避免父容器 44pt 高将圆拉成椭圆；trailingInset 为距右侧容器右缘的内缩（头像整体左移）
- (void)rb_attachCircularAvatarViewToChatCustomNavRight:(UIView *)container sideLength:(CGFloat)side trailingInsetFromRight:(CGFloat)trailingInset
{
    [self rb_setupChatCustomNavBarIfNeeded];
    if (!container || !self.rb_chromeNavigationBar || side <= 0) {
        return;
    }
    [self.rb_chromeNavigationBar attachCircularRightAccessoryView:container sideLength:side trailingInsetFromRight:trailingInset];
}

- (UIView *)rb_anchorViewForChatNavMoreMenu
{
    if (!self.rb_chromeNavigationBar) {
        return nil;
    }
    UIView *first = self.rb_chromeNavigationBar.rightAccessoryContainer.subviews.firstObject;
    return first ?: self.rb_chromeNavigationBar.rightAccessoryContainer;
}

- (void)rb_navBeginMultiSelectMode
{
    [self rb_setupChatCustomNavBarIfNeeded];
    [self.rb_chromeNavigationBar setMultiSelectModeVisualActive:YES];
}

- (void)rb_navRestoreAfterExitMultiSelect
{
    [self rb_setupChatCustomNavBarIfNeeded];
    [self.rb_chromeNavigationBar setMultiSelectModeVisualActive:NO];
    self.navigationItem.title = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.title = self.toName;
    [self setupMinimalNavigationBar];
}

/// 首帧极简导航栏：自定义顶栏 + 隐藏系统导航栏（不在 navigationItem 上摆放控件）
- (void)setupMinimalNavigationBar
{
    [self rb_setupChatCustomNavBarIfNeeded];
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.title = @"";
    [self rb_restoreMinimalBackButton];
    self.rb_chromeNavigationBar.titleLabel.text = self.toName ?: @"";
    self.rb_chromeNavigationBar.titleLabel.font = [BasicTool getBoldSystemFontOfSize:16.0f];
    self.rb_chromeNavigationBar.titleLabel.textColor = UI_DEFAULT_TITLE_FONT_COLOR;
    UIBarButtonItem *moreItem = [self rb_minimalRightBarButtonItem];
    if (moreItem.customView) {
        [self rb_attachViewToChatCustomNavRight:moreItem.customView];
    }
    if (self.rb_chromeNavigationBar) {
        [self.view bringSubviewToFront:self.rb_chromeNavigationBar];
    }
    [self jsq_updateCollectionViewInsets];
}

/// 极简导航右侧「更多」按钮（仅用于取出 customView 挂到自定义顶栏）
- (UIBarButtonItem *)rb_minimalRightBarButtonItem
{
    CGFloat size = 36.0f;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, size, size);
    btn.tintColor = [UIColor blackColor];
    btn.adjustsImageWhenHighlighted = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
        [btn setImage:[UIImage systemImageNamed:@"ellipsis" withConfiguration:cfg] forState:UIControlStateNormal];
    } else {
        [btn setTitle:@"⋯" forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightRegular];
    }
    [btn addTarget:self action:@selector(onNavAvatarTapped) forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:btn];
}

- (UIBarButtonItem *)rb_rightCircularAvatarBarButtonItemWithAction:(SEL)action
{
    [self rb_setupChatCustomNavBarIfNeeded];
    static const CGFloat kNavAvatarSize = 40.f;
    static const CGFloat kNavAvatarTrailingInset = 10.f;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kNavAvatarSize, kNavAvatarSize)];
    container.backgroundColor = [UIColor colorWithWhite:0.92f alpha:1.f];
    container.layer.cornerRadius = kNavAvatarSize * 0.5f;
    container.clipsToBounds = YES;

    UIImageView *iv = [[UIImageView alloc] initWithFrame:container.bounds];
    iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    iv.userInteractionEnabled = NO;
    [container addSubview:iv];

    UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
    hit.frame = container.bounds;
    hit.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    hit.backgroundColor = [UIColor clearColor];
    hit.adjustsImageWhenHighlighted = NO;
    [hit addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:hit];

    self.navAvatarImageView = iv;
    self.navAvatarButton = hit;
    [self rb_attachCircularAvatarViewToChatCustomNavRight:container sideLength:kNavAvatarSize trailingInsetFromRight:kNavAvatarTrailingInset];
    return nil;
}

/// 恢复左侧返回按钮（自定义顶栏）
- (void)rb_restoreMinimalBackButton
{
    [self rb_setupChatCustomNavBarIfNeeded];
    if (!self.rb_chromeNavigationBar) {
        return;
    }
    [self.rb_chromeNavigationBar setMultiSelectModeVisualActive:NO];
    [self.rb_chromeNavigationBar setBackButtonTarget:self action:@selector(onNavBackTapped)];
}

- (void)rb_deferredSetupCustomNavigationBar
{
    [self setupCustomNavigationBar];
}

- (void)rb_didSetupCustomNavigationBar
{
    // 子类重写：设置右侧按钮、副标题等
}

- (void)setupCustomNavigationBar
{
    [self rb_setupChatCustomNavBarIfNeeded];
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.title = @"";

    self.navTitleBubble = nil;
    self.navTitleLabel = nil;
    self.navSubtitleLabel = nil;
    self.navTitleBubbleWidthConstraint = nil;

    [self rb_restoreMinimalBackButton];
    self.rb_chromeNavigationBar.titleLabel.text = self.toName ?: @"";
    self.rb_chromeNavigationBar.titleLabel.font = [BasicTool getBoldSystemFontOfSize:16.0f];
    self.rb_chromeNavigationBar.titleLabel.textColor = UI_DEFAULT_TITLE_FONT_COLOR;

    // 未读小圆点：叠在左上角区域（与旧版一致，供多选等逻辑引用 navBadgeLabel）
    if (!self.navBadgeLabel) {
        UILabel *badgeDot = [[UILabel alloc] init];
        badgeDot.translatesAutoresizingMaskIntoConstraints = NO;
        badgeDot.backgroundColor = [UIColor colorWithRed:1.0f green:0.23f blue:0.19f alpha:1.0f];
        badgeDot.layer.cornerRadius = 4.0f;
        badgeDot.clipsToBounds = YES;
        badgeDot.hidden = YES;
        badgeDot.text = @"";
        badgeDot.userInteractionEnabled = NO;
        [self.rb_chromeNavigationBar.leftAccessoryContainer addSubview:badgeDot];
        self.navBadgeLabel = badgeDot;
        [NSLayoutConstraint activateConstraints:@[
            [badgeDot.widthAnchor constraintEqualToConstant:8.f],
            [badgeDot.heightAnchor constraintEqualToConstant:8.f],
            [badgeDot.topAnchor constraintEqualToAnchor:self.rb_chromeNavigationBar.leftAccessoryContainer.topAnchor constant:-2.f],
            [badgeDot.trailingAnchor constraintEqualToAnchor:self.rb_chromeNavigationBar.leftAccessoryContainer.trailingAnchor constant:2.f],
        ]];
    }

    UIBarButtonItem *moreItem = [self rb_minimalRightBarButtonItem];
    if (moreItem.customView) {
        [self rb_attachViewToChatCustomNavRight:moreItem.customView];
        self.navAvatarButton = (UIButton *)moreItem.customView;
    }

    [NotificationCenterFactory refreshMainPageTotalUnread_ADD:self selector:@selector(refreshNavBadge)];
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [wself refreshNavBadge];
    });

    if (self.rb_chromeNavigationBar) {
        [self.view bringSubviewToFront:self.rb_chromeNavigationBar];
    }
    [self jsq_updateCollectionViewInsets];
}

- (void)onNavBackTapped
{
    [self doBack:YES];
}

- (void)rb_dismissKeyboard
{
    [self.view endEditing:YES];
}

#pragma mark - UIGestureRecognizerDelegate（全屏右滑返回）

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == self.rb_fullScreenPopPanGesture) {
        return YES;
    }
    if (gestureRecognizer == self.rb_dismissKeyboardTap) {
        UITextView *composer = [self rb_currentComposerTextView];
        if (!composer || ![composer isFirstResponder])
            return NO;
        CGPoint p = [gestureRecognizer locationInView:self.view];
        UIView *inputArea = self.tgInputBar ? (UIView *)self.tgInputBar : self.inputToolbar;
        CGRect inputFrame = [inputArea convertRect:inputArea.bounds toView:self.view];
        if (CGRectContainsPoint(inputFrame, p))
            return NO;
        return YES;
    }
    if (gestureRecognizer == self.rb_dismissKeyboardTapOnCollectionView) {
        UITextView *composer = [self rb_currentComposerTextView];
        return composer && [composer isFirstResponder];
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == self.rb_fullScreenPopPanGesture) {
        return YES;
    }
    // 允许“点击消息列表收起键盘”与 collectionView 的滚动手势同时识别，否则点击易被 scroll 抢占导致无法关闭表情/键盘
    if (gestureRecognizer == self.rb_dismissKeyboardTapOnCollectionView) {
        return YES;
    }
    return NO;
}

/// 全屏右滑触发返回：右滑距离超过阈值且主要为水平方向则 pop
- (void)rb_handleFullScreenPopPan:(UIPanGestureRecognizer *)pan
{
    if (self.navigationController.viewControllers.count <= 1) return;
    if (pan.state != UIGestureRecognizerStateEnded && pan.state != UIGestureRecognizerStateCancelled) return;
    CGPoint translation = [pan translationInView:self.view];
    CGPoint velocity = [pan velocityInView:self.view];
    static const CGFloat kMinRightTranslation = 80.0f;
    if (translation.x > kMinRightTranslation && velocity.x > 0) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)onNavTitleTapped
{
    [self onNavAvatarTapped];
}

- (void)onNavAvatarTapped
{
    // 子类重写以实现各自的跳转逻辑
}

/// 多选模式退出时，若子类返回非 nil 则用其作为右侧按钮（如 10001 的搜索按钮），否则恢复头像按钮
- (UIBarButtonItem *)customRightBarButtonItemForRestore
{
    return nil;
}

#pragma mark - 聊天页顶部搜索框（弹出式）

/// 与收藏夹 MessageSearch10001ViewController 的 kSearchContainerHeight 一致
static const CGFloat kChatSearchBarVisibleHeight = 28.f;

- (void)setupChatSearchBar
{
    if (self.chatSearchBarContainer) return;
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [UIColor clearColor];
    container.clipsToBounds = NO;
    container.hidden = YES;
    container.layer.zPosition = 1000;
    [self.view addSubview:container];
    self.chatSearchBarContainer = container;

    // 完全透明：不加液态/模糊层，仅保留搜索框且其背景透明以透出聊天背景
    UISearchBar *bar = [[UISearchBar alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.placeholder = @"搜索聊天内容";
    bar.searchBarStyle = UISearchBarStyleMinimal;
    bar.delegate = self;
    bar.showsCancelButton = YES;
    bar.backgroundColor = [UIColor clearColor];
    bar.barTintColor = [UIColor clearColor];
    bar.backgroundImage = [[UIImage alloc] init];
    bar.clipsToBounds = NO;
    // 关键：让 UISearchBar 在垂直方向可被压缩，否则其固有高度(约36pt)会覆盖我们的 28pt 约束
    [bar setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [bar setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [container addSubview:bar];
    self.chatSearchBar = bar;
    if (@available(iOS 13.0, *)) {
        UITextField *tf = bar.searchTextField;
        tf.backgroundColor = [UIColor clearColor];
        tf.layer.cornerRadius = 10;
        tf.clipsToBounds = NO;
        tf.font = [UIFont systemFontOfSize:14];
        [tf setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    }
    // 清除 UISearchBar 内部子视图的默认背景，并压低其垂直抗压缩优先级以便能压到 28pt
    __weak UISearchBar *weakBar = bar;
    dispatch_async(dispatch_get_main_queue(), ^{
        UISearchBar *b = weakBar;
        if (!b) return;
        for (UIView *v in b.subviews) {
            v.backgroundColor = [UIColor clearColor];
            [v setContentCompressionResistancePriority:1 forAxis:UILayoutConstraintAxisVertical];
            for (UIView *sub in v.subviews) {
                sub.backgroundColor = [UIColor clearColor];
                [sub setContentCompressionResistancePriority:1 forAxis:UILayoutConstraintAxisVertical];
            }
        }
    });

    // 与收藏夹一致：容器固定 28pt；搜索栏仅用 top+height+左右贴边，避免 bottom 与固有高度冲突
    NSLayoutConstraint *heightConstraint = [container.heightAnchor constraintEqualToConstant:0];
    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [container.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        heightConstraint,
        [bar.topAnchor constraintEqualToAnchor:container.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [bar.heightAnchor constraintEqualToConstant:kChatSearchBarVisibleHeight],
    ]];
    self.chatSearchBarHeightConstraint = heightConstraint;
    [self.view bringSubviewToFront:container];
    [self setupChatSearchResultStrip];
}

- (void)setupChatSearchResultStrip
{
    if (self.chatSearchResultStrip) return;
    static const CGFloat kStripHeight = 132.f;  // 容纳：上条+间隙+下条+间隙+以列表模式查看
    static const CGFloat kPillHeight = 34.f;
    static const CGFloat kPillLeftMargin = 12.f;
    static const CGFloat kBtnSize = 36.f;  // 上下条圆形按钮直径
    static const CGFloat kBtnGap = 14.f;
    static const CGFloat kBtnListGap = 8.f;  // 下条与「以列表模式查看」间距
    static const CGFloat kBtnRightMargin = 12.f;
    static const CGFloat kStripBottomMargin = 4.f;
    UIColor *chevronColor = [UIColor colorWithWhite:0.25f alpha:1.f];
    // 液态玻璃/模糊半透明：在容器内插入 UIVisualEffectView 作为底层
    void (^addGlassOrBlur)(UIView *container, CGFloat cornerRadius) = ^(UIView *container, CGFloat cornerRadius) {
        container.backgroundColor = [UIColor clearColor];
        UIVisualEffectView *effectView = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
        if (@available(iOS 26.0, *)) {
            UIGlassEffect *effect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
            effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
        } else
#endif
        if (@available(iOS 13.0, *)) {
            effectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
        }
        if (effectView) {
            effectView.frame = container.bounds;
            effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            effectView.layer.cornerRadius = cornerRadius;
            effectView.clipsToBounds = YES;
            effectView.userInteractionEnabled = NO;
            [container insertSubview:effectView atIndex:0];
        }
    };

    UIView *strip = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 400, kStripHeight)];
    strip.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    strip.backgroundColor = [UIColor clearColor];
    self.chatSearchResultStrip = strip;

    // 左下角：独立胶囊（图一）- 图标 + 「共 N 条消息」或「M/N」，与「以列表模式查看」同一行，液态玻璃半透明
    static const CGFloat kPillLabelLeft = 42.f;   // 图标 + 间距
    static const CGFloat kPillLabelRight = 10.f;
    static const CGFloat kPillMinWidth = 56.f;
    static const CGFloat kPillMaxWidth = 180.f;
    CGFloat bottomRowY = kStripHeight - kStripBottomMargin - kPillHeight;
    UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(kPillLeftMargin, bottomRowY, kPillMinWidth, kPillHeight)];
    pill.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    pill.layer.cornerRadius = kPillHeight / 2;
    pill.layer.masksToBounds = YES;
    addGlassOrBlur(pill, kPillHeight / 2);
    [strip addSubview:pill];

    UIImageView *iconView = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightMedium];
        UIImage *icon = [UIImage systemImageNamed:@"doc.text.magnifyingglass" withConfiguration:config];
        if (icon) {
            iconView = [[UIImageView alloc] initWithImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
            iconView.tintColor = [UIColor darkGrayColor];
            iconView.frame = CGRectMake(6, (kPillHeight - 28) / 2, 28, 28);
            [pill addSubview:iconView];
        }
    }
    CGFloat labelLeft = iconView ? kPillLabelLeft : 10.f;
    UILabel *countLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelLeft, 0, kPillMaxWidth - labelLeft - kPillLabelRight, kPillHeight)];
    countLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    countLabel.textColor = [UIColor darkGrayColor];
    countLabel.text = @"";
    countLabel.numberOfLines = 1;
    [pill addSubview:countLabel];
    self.chatSearchResultCountLabel = countLabel;

    // 右下角：「以列表模式查看」胶囊按钮（与数量胶囊同一行），液态玻璃半透明
    static const CGFloat kListBtnWidth = 130.f;
    CGFloat listBtnY = bottomRowY;
    CGFloat rightX = strip.bounds.size.width - kBtnRightMargin - kBtnSize;
    CGFloat listBtnX = strip.bounds.size.width - kBtnRightMargin - kListBtnWidth;
    UIButton *listModeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    listModeBtn.frame = CGRectMake(listBtnX, listBtnY, kListBtnWidth, kPillHeight);
    listModeBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    listModeBtn.layer.cornerRadius = kPillHeight / 2;
    listModeBtn.layer.masksToBounds = YES;
    addGlassOrBlur(listModeBtn, kPillHeight / 2);
    [listModeBtn setTitle:@"以列表模式查看" forState:UIControlStateNormal];
    [listModeBtn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    listModeBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [listModeBtn addTarget:self action:@selector(onChatSearchResultListMode:) forControlEvents:UIControlEventTouchUpInside];
    [strip addSubview:listModeBtn];
    self.chatSearchResultListModeButton = listModeBtn;

    // 以列表模式查看的上方：上一条、下一条两个圆形按钮，液态玻璃半透明
    CGFloat nextBtnY = listBtnY - kBtnListGap - kBtnSize;
    CGFloat prevBtnY = nextBtnY - kBtnGap - kBtnSize;
    UIButton *prevBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    prevBtn.frame = CGRectMake(rightX, prevBtnY, kBtnSize, kBtnSize);
    prevBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    prevBtn.layer.cornerRadius = kBtnSize / 2;
    prevBtn.layer.masksToBounds = NO;  // 保留阴影
    addGlassOrBlur(prevBtn, kBtnSize / 2);
    prevBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    prevBtn.layer.shadowOffset = CGSizeMake(0, 1);
    prevBtn.layer.shadowRadius = 2;
    prevBtn.layer.shadowOpacity = 0.12f;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *chevronConfig = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightSemibold];
        UIImage *up = [UIImage systemImageNamed:@"chevron.up" withConfiguration:chevronConfig];
        [prevBtn setImage:[up imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        prevBtn.tintColor = chevronColor;
    } else {
        [prevBtn setTitle:@"↑" forState:UIControlStateNormal];
        [prevBtn setTitleColor:chevronColor forState:UIControlStateNormal];
    }
    [prevBtn bringSubviewToFront:prevBtn.imageView];
    [prevBtn bringSubviewToFront:prevBtn.titleLabel];
    [prevBtn addTarget:self action:@selector(onChatSearchResultPrev:) forControlEvents:UIControlEventTouchUpInside];
    [strip addSubview:prevBtn];
    self.chatSearchResultPrevButton = prevBtn;

    UIButton *nextBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    nextBtn.frame = CGRectMake(rightX, nextBtnY, kBtnSize, kBtnSize);
    nextBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    nextBtn.layer.cornerRadius = kBtnSize / 2;
    nextBtn.layer.masksToBounds = NO;  // 保留阴影
    addGlassOrBlur(nextBtn, kBtnSize / 2);
    nextBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    nextBtn.layer.shadowOffset = CGSizeMake(0, 1);
    nextBtn.layer.shadowRadius = 2;
    nextBtn.layer.shadowOpacity = 0.12f;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *chevronConfig = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightSemibold];
        UIImage *down = [UIImage systemImageNamed:@"chevron.down" withConfiguration:chevronConfig];
        [nextBtn setImage:[down imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        nextBtn.tintColor = chevronColor;
    } else {
        [nextBtn setTitle:@"↓" forState:UIControlStateNormal];
        [nextBtn setTitleColor:chevronColor forState:UIControlStateNormal];
    }
    [nextBtn bringSubviewToFront:nextBtn.imageView];
    [nextBtn bringSubviewToFront:nextBtn.titleLabel];
    [nextBtn addTarget:self action:@selector(onChatSearchResultNext:) forControlEvents:UIControlEventTouchUpInside];
    [strip addSubview:nextBtn];
    self.chatSearchResultNextButton = nextBtn;

    if (@available(iOS 13.0, *)) {
        self.chatSearchBar.searchTextField.inputAccessoryView = strip;
    }
}

- (void)updateChatSearchResultStripWithTotalCount:(NSInteger)totalCount matchCount:(NSInteger)matchCount currentIndex:(NSInteger)currentIndex
{
    if (!self.chatSearchResultStrip) return;
    static const CGFloat kPillLabelLeft = 42.f;
    static const CGFloat kPillLabelRight = 10.f;
    static const CGFloat kPillMinWidth = 56.f;
    static const CGFloat kPillMaxWidth = 180.f;
    if (matchCount > 0) {
        self.chatSearchResultCountLabel.text = [NSString stringWithFormat:@"%ld/%ld", (long)(currentIndex + 1), (long)matchCount];
        self.chatSearchResultPrevButton.hidden = (currentIndex <= 0);
        self.chatSearchResultNextButton.hidden = (currentIndex >= matchCount - 1);
    } else {
        self.chatSearchResultCountLabel.text = totalCount >= 0 ? [NSString stringWithFormat:@"共 %ld 条消息", (long)totalCount] : @"";
        self.chatSearchResultPrevButton.hidden = YES;
        self.chatSearchResultNextButton.hidden = YES;
    }
    // 仅 10001 会话显示「以列表模式查看」，点击跳收藏夹搜索
    self.chatSearchResultListModeButton.hidden = ![self.toId isEqualToString:@"10001"];
    // 胶囊宽度随文字自适应，避免过长（首个子视图为液态玻璃 effectView，其次为图标、label）
    UIView *pill = self.chatSearchResultCountLabel.superview;
    if ([pill isKindOfClass:[UIView class]]) {
        CGFloat labelLeft = (pill.subviews.count >= 3) ? kPillLabelLeft : 10.f; // 有图标时留足左边距
        [self.chatSearchResultCountLabel sizeToFit];
        CGFloat labelW = (CGFloat)ceil(self.chatSearchResultCountLabel.bounds.size.width);
        CGFloat pillWidth = labelLeft + labelW + kPillLabelRight;
        pillWidth = MIN(MAX(pillWidth, kPillMinWidth), kPillMaxWidth);
        CGFloat pillHeight = pill.bounds.size.height;
        pill.frame = CGRectMake(pill.frame.origin.x, pill.frame.origin.y, pillWidth, pillHeight);
        self.chatSearchResultCountLabel.frame = CGRectMake(labelLeft, 0, pillWidth - labelLeft - kPillLabelRight, pillHeight);
        UIView *ev = pill.subviews.firstObject;
        if ([ev isKindOfClass:[UIVisualEffectView class]]) ev.frame = pill.bounds;
    }
}

- (void)onChatSearchResultPrev:(UIButton *)sender
{
    if (self.searchMatchFingerprints.count == 0 || self.searchMatchCurrentIndex <= 0) return;
    self.searchMatchCurrentIndex--;
    self.highlightOnceMsgFingerprint = self.searchMatchFingerprints[self.searchMatchCurrentIndex];
    [self doHighlightOnceMessage];
    [self updateChatSearchResultStripWithTotalCount:-1 matchCount:(NSInteger)self.searchMatchFingerprints.count currentIndex:self.searchMatchCurrentIndex];
}

- (void)onChatSearchResultListMode:(UIButton *)sender
{
    NSString *keyword = [self.chatSearchBar.searchTextField.text ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self hideChatSearchBarAnimated:YES];
    [ViewControllerFactory goMessageSearch10001ViewController:self.navigationController
                                                     chatType:self.chatType
                                                       dataId:self.toId ?: @""
                                                  partnerName:self.toName ?: @""
                                       showSearchBarWhenPushed:YES
                                          initialSearchKeyword:(keyword.length > 0 ? keyword : nil)];
}

- (void)onChatSearchResultNext:(UIButton *)sender
{
    if (self.searchMatchFingerprints.count == 0 || self.searchMatchCurrentIndex >= (NSInteger)self.searchMatchFingerprints.count - 1) return;
    self.searchMatchCurrentIndex++;
    self.highlightOnceMsgFingerprint = self.searchMatchFingerprints[self.searchMatchCurrentIndex];
    [self doHighlightOnceMessage];
    [self updateChatSearchResultStripWithTotalCount:-1 matchCount:(NSInteger)self.searchMatchFingerprints.count currentIndex:self.searchMatchCurrentIndex];
}

- (void)showChatSearchBarAnimated:(BOOL)animated
{
    if (self.chatSearchBarVisible) {
        [self.chatSearchBar becomeFirstResponder];
        return;
    }
    if (!self.chatSearchBarContainer) [self setupChatSearchBar];
    if (!self.chatSearchResultStrip) [self setupChatSearchResultStrip];
    self.chatSearchBarVisible = YES;
    self.chatSearchBarContainer.hidden = NO;
    self.chatSearchBarHeightConstraint.constant = kChatSearchBarVisibleHeight;
    [self.chatSearchBarContainer setNeedsLayout];
    [self.chatSearchBarContainer layoutIfNeeded];
    [self.view bringSubviewToFront:self.chatSearchBarContainer];
    [self updateChatSearchResultStripWithTotalCount:[self chatSearchTotalMessageCount] matchCount:0 currentIndex:0];
    if (self.rb_chromeNavigationBar) {
        self.rb_chromeNavigationBar.hidden = YES;
        [self jsq_updateCollectionViewInsets];
    }
    void (^animations)(void) = ^{ [self.view layoutIfNeeded]; };
    if (animated) {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:animations completion:^(BOOL finished) {
            [self.chatSearchBar becomeFirstResponder];
        }];
    } else {
        animations();
        [self.chatSearchBar becomeFirstResponder];
    }
}

- (void)hideChatSearchBarAnimated:(BOOL)animated
{
    if (!self.chatSearchBarVisible) return;
    [self.chatSearchBar resignFirstResponder];
    self.chatSearchBarVisible = NO;
    self.chatSearchBarHeightConstraint.constant = 0;
    if (self.rb_chromeNavigationBar) {
        self.rb_chromeNavigationBar.hidden = NO;
        [self jsq_updateCollectionViewInsets];
    }
    void (^animations)(void) = ^{ [self.view layoutIfNeeded]; };
    void (^completion)(BOOL) = ^(BOOL finished) { self.chatSearchBarContainer.hidden = YES; self.chatSearchBar.text = @""; };
    if (animated) {
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:animations completion:completion];
    } else {
        animations();
        completion(YES);
    }
}

/// 当前会话全部消息条数（用于键盘上方数量条「共 N 条消息」）
- (NSInteger)chatSearchTotalMessageCount
{
    if (!self.toId) return 0;
    id msgProvider = nil;
    if (self.chatType == CHAT_TYPE_FREIDN_CHAT || self.chatType == CHAT_TYPE_GUEST_CHAT) {
        msgProvider = [[IMClientManager sharedInstance] getMessagesProvider];
    } else if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
        msgProvider = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
    }
    if (!msgProvider) return 0;
    NSMutableArrayObservableEx *list = [msgProvider getMessages:self.toId];
    return (NSInteger)[[list getDataList] count];
}

/// 在当前聊天内按关键词查找匹配消息列表，滚动到当前条并高亮（供搜索按钮与输入实时搜索共用）
- (void)searchInCurrentChatAndScrollToMatchWithKeyword:(NSString *)keyword showToastWhenNoMatch:(BOOL)showToast
{
    NSInteger totalCount = [self chatSearchTotalMessageCount];
    if (!self.toId) {
        if (showToast) [APP showUserDefineToast_OK:@"未找到相关消息"];
        [self updateChatSearchResultStripWithTotalCount:(NSInteger)totalCount matchCount:0 currentIndex:0];
        return;
    }
    if (keyword.length == 0) {
        self.searchMatchFingerprints = @[];
        self.searchMatchCurrentIndex = 0;
        [self updateChatSearchResultStripWithTotalCount:(NSInteger)totalCount matchCount:0 currentIndex:0];
        return;
    }
    id msgProvider = nil;
    if (self.chatType == CHAT_TYPE_FREIDN_CHAT || self.chatType == CHAT_TYPE_GUEST_CHAT) {
        msgProvider = [[IMClientManager sharedInstance] getMessagesProvider];
    } else if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
        msgProvider = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
    }
    if (!msgProvider) {
        if (showToast) [APP showUserDefineToast_OK:@"未找到相关消息"];
        [self updateChatSearchResultStripWithTotalCount:(NSInteger)totalCount matchCount:0 currentIndex:0];
        return;
    }
    NSMutableArrayObservableEx *list = [msgProvider getMessages:self.toId];
    NSArray *dataList = [list getDataList];
    NSString *lowerKeyword = [keyword lowercaseString];
    NSMutableArray<NSString *> *fps = [NSMutableArray array];
    for (JSQMessage *m in dataList) {
        if (m.msgType != TM_TYPE_TEXT) continue;
        if (m.text.length > 0 && [[m.text lowercaseString] rangeOfString:lowerKeyword].location != NSNotFound) {
            if (m.fingerPrintOfProtocal.length > 0) [fps addObject:m.fingerPrintOfProtocal];
        }
    }
    self.searchMatchFingerprints = [fps copy];
    self.searchMatchCurrentIndex = 0;
    // 无匹配时显示「共 0 条消息」，有匹配时 strip 显示 M/N
    NSInteger displayTotal = (fps.count == 0) ? 0 : (NSInteger)totalCount;
    [self updateChatSearchResultStripWithTotalCount:displayTotal matchCount:(NSInteger)fps.count currentIndex:0];
    if (fps.count > 0) {
        self.highlightOnceMsgFingerprint = fps.firstObject;
        [self doHighlightOnceMessage];
    } else {
        if (showToast) [APP showUserDefineToast_OK:@"未找到相关消息"];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    NSString *keyword = [(searchText ? searchText : @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self searchInCurrentChatAndScrollToMatchWithKeyword:keyword showToastWhenNoMatch:NO];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    NSString *keyword = [(searchBar.text ? searchBar.text : @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self hideChatSearchBarAnimated:YES];
    [self searchInCurrentChatAndScrollToMatchWithKeyword:keyword showToastWhenNoMatch:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self hideChatSearchBarAnimated:YES];
}

- (void)updateNavBadgeCount:(int)count
{
    // 目前不再显示未读小圆点，保持隐藏即可（保留方法以兼容旧调用）
    if (!self.navBadgeLabel) return;
    self.navBadgeLabel.hidden = YES;
}

- (void)updateNavSubtitle:(NSString *)subtitle
{
    if (!self.navSubtitleLabel) return;
    self.navSubtitleLabel.text = subtitle ?: @"";
    
    if (subtitle.length > 0) {
        self.navTitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        for (NSLayoutConstraint *c in self.navTitleBubble.constraints) {
            if (c.firstItem == self.navTitleLabel && c.firstAttribute == NSLayoutAttributeTop) {
                c.constant = 5;
            }
        }
    } else {
        self.navTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        for (NSLayoutConstraint *c in self.navTitleBubble.constraints) {
            if (c.firstItem == self.navTitleLabel && c.firstAttribute == NSLayoutAttributeTop) {
                c.constant = 12;
            }
        }
    }
    [self updateNavTitleBubbleWidth];
}

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    if (self.navTitleLabel) {
        self.navTitleLabel.text = title ?: @"";
        [self updateNavTitleBubbleWidth];
    }
    if (self.rb_chromeNavigationBar) {
        self.rb_chromeNavigationBar.titleLabel.text = title ?: @"";
    }
}

- (void)updateNavTitleBubbleWidth
{
    if (!self.navTitleBubbleWidthConstraint || !self.navTitleLabel || !self.navSubtitleLabel) return;
    CGFloat padding = 32.0f; // 左右各 16
    CGFloat minW = 60.0f;
    CGFloat maxW = 240.0f;
    UIFont *titleFont = self.navTitleLabel.font ?: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    UIFont *subtitleFont = self.navSubtitleLabel.font ?: [UIFont systemFontOfSize:12];
    NSString *titleText = self.navTitleLabel.text ?: @"";
    NSString *subtitleText = self.navSubtitleLabel.text ?: @"";
    CGSize titleSize = [titleText boundingRectWithSize:CGSizeMake(maxW - padding, 24)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:@{ NSFontAttributeName: titleFont }
                                               context:nil].size;
    CGSize subtitleSize = [subtitleText boundingRectWithSize:CGSizeMake(maxW - 24, 20)
                                                      options:NSStringDrawingUsesLineFragmentOrigin
                                                   attributes:@{ NSFontAttributeName: subtitleFont }
                                                      context:nil].size;
    CGFloat needW = ceil(MAX(titleSize.width, subtitleSize.width) + padding);
    needW = MAX(minW, MIN(maxW, needW));
    self.navTitleBubbleWidthConstraint.constant = needW;
}

- (void)updateNavAvatarWithImage:(UIImage *)image
{
    if (!image) return;
    if (self.navAvatarImageView) {
        [RBAvatarView removeAvatarFromImageView:self.navAvatarImageView];
        self.navAvatarImageView.image = image;
        return;
    }
    if (!self.navAvatarButton) return;
    [self.navAvatarButton setImage:image forState:UIControlStateNormal];
}

- (void)refreshNavBadge
{
    AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
    int total = [ap getTotalFlagNum];
    [self updateNavBadgeCount:total];
}

/// 根据在线状态与最近登录时间生成导航副标题：在线 / X分钟前曾上线 / X小时前曾上线 / X天内曾上线 / 一个月内曾上线 / 很久没上线
+ (NSString *)navSubtitleForOnline:(BOOL)isOnline latestLoginTime2:(NSString *)time2Str
{
    if (isOnline) return @"在线";
    if (!time2Str || time2Str.length == 0) return @"";
    NSDate *lastDate = [TimeTool convertJavaTimestampToiOSDate:time2Str];
    if (lastDate == nil) return @"";
    NSTimeInterval seconds = [[NSDate date] timeIntervalSinceDate:lastDate];
    if (seconds < 0) return @"";
    if (seconds < 60) return @"在线";
    long minutes = (long)(seconds / 60);
    if (minutes < 60) return [NSString stringWithFormat:@"%ld分钟前在线", minutes];
    long hours = (long)(seconds / 3600);
    if (hours < 24) return [NSString stringWithFormat:@"%ld小时前在线", hours];
    long days = (long)(seconds / (24.0 * 3600.0));
    if (days < 30) return [NSString stringWithFormat:@"%ld天内曾上线", days];
    if (days < 60) return @"一个月内曾上线";
    return @"很久没上线";
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 其它方法

// 默认将聊天文本框中的内容作为发送指uid的用户.
- (void)sendPlainTextMessage:(NSString *)message toChatType:(int)chatType toId:(NSString *)toId forSucess:(ObserverCompletion)sucessObs
{
    [self sendPlainTextMessage:message toChatType:chatType toId:toId quoteMeta:nil forSucess:sucessObs];
}

- (void)sendPlainTextMessage:(NSString *)message toChatType:(int)chatType toId:(NSString *)toId quoteMeta:(QuoteMeta *)quoteMeta forSucess:(ObserverCompletion)sucessObs
{
    QuoteMeta *qm = (quoteMeta != nil ? quoteMeta : (self.quote4InputWrapper != nil ? [self.quote4InputWrapper getQuoteMeta:self.chatType with:self.toId] : nil));
    if(CHAT_TYPE_FREIDN_CHAT == chatType) {
        ObserverCompletion callback = sucessObs;
        if ([toId isEqualToString:@"10001"]) {
            __weak typeof(self) w = self;
            NSString *msgCopy = [message copy];
            callback = ^(id o, id arg) {
                if (sucessObs) sucessObs(o, arg);
                if (arg != nil && [arg intValue] == 0 && msgCopy.length > 0) {
                    [w submitFavoriteToServerWithContent:msgCopy favType:kFavTypeText sourceChatType:chatType onSyncSuccess:^{ [w refresh10001FavoritesListIfNeeded]; }];
                }
            };
        }
        [MessageHelper sendPlainTextMessageAsync:toId withMessage:message quote:qm forSucess:callback];
    }
    else if(CHAT_TYPE_GUEST_CHAT == chatType) {
        [TMessageHelper sendPlainTextMessageAsync:toId tuname:self.toName withMessage:message quote:qm forSucess:sucessObs];
    }
    else if(CHAT_TYPE_GROUP_CHAT == chatType) {
        NSArray *allAtUid = [self.atCache getAtUsers:message];
        [GMessageHelper sendPlainTextMessageAsync:toId withMessage:message at:allAtUid quote:qm forSucess:sucessObs];
    }
}

// 默认将聊天文本框中的内容作为发送内分给好友.
- (void)sendPlainTextMessage:(NSString *)message forSucess:(ObserverCompletion)sucessObs
{
    [self sendPlainTextMessage:message toChatType:self.chatType toId:self.toId forSucess:sucessObs];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 性能优化：局部刷新与后台图片加载

/// 在后台线程对图片做一次强制解码（使用 CGBitmapContext，可安全在子线程调用），避免列表首次绘制时才解码导致不渲染或卡顿。返回解码后的新图，失败或动图则返回原图。
- (UIImage *)rb_forceDecodeImage:(UIImage *)image
{
    if (!image) return nil;
    if (image.images.count > 1) return image; // 动图不在此路径解码
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return image;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0) return image;
    CGColorSpaceRef space = CGImageGetColorSpace(cgImage) ?: CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    size_t bytesPerRow = width * 4;
    CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, bytesPerRow, space, bitmapInfo);
    if (space != CGImageGetColorSpace(cgImage)) CGColorSpaceRelease(space);
    if (!ctx) return image;
    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgImage);
    CGImageRef decodedCgImage = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    if (!decodedCgImage) return image;
    UIImage *decoded = [UIImage imageWithCGImage:decodedCgImage scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(decodedCgImage);
    return decoded ?: image;
}

/// 仅刷新指定位置的 cell（避免整表 reloadData）。必须在主线程调用；若在数据源回调内请 dispatch_async(main) 再调。
/// 短时间内的多次调用会合并为一次 reload，减轻“多条图片同时加载完”导致的连续 reload 卡顿。
- (void)rb_refreshItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!indexPath) return;
    if (![NSThread isMainThread]) {
        NSIndexPath *path = [indexPath copy];
        dispatch_async(dispatch_get_main_queue(), ^{ [self rb_refreshItemAtIndexPath:path]; });
        return;
    }
    NSArray *list = [self getChattingDatasList];
    NSInteger count = list ? [list count] : 0;
    if (indexPath.section != 0 || indexPath.item < 0 || indexPath.item >= count) return;
    if (!self.collectionView.window) return;

    [self.rb_cachedLayoutMetaByMessageKey removeAllObjects];
    if (_rb_pendingRefreshIndexPaths == nil) _rb_pendingRefreshIndexPaths = [NSMutableSet set];
    [_rb_pendingRefreshIndexPaths addObject:indexPath];
    if (_rb_refreshCoalesceScheduled) return;
    _rb_refreshCoalesceScheduled = YES;
    __weak typeof(self) wself = self;
    // 进入聊天后 0.4s 内延迟 0.25s 再 flush，避免与导航转场、CollectionView 首帧布局交织导致图片气泡闪烁（IPS: 主线程在 UINib/布局上阻塞 ~265ms）
    NSTimeInterval sinceAppear = CFAbsoluteTimeGetCurrent() - self.rb_viewDidAppearTime;
    int64_t delayNs = (sinceAppear < 0.4) ? (int64_t)(0.25 * NSEC_PER_SEC) : 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayNs), dispatch_get_main_queue(), ^{
        [wself rb_flushPendingRefresh];
    });
}

- (void)rb_flushPendingRefresh
{
    if (_rb_pendingRefreshIndexPaths.count == 0) {
        self.rb_refreshCoalesceScheduled = NO;
        return;
    }
    if (!self.collectionView.window) {
        self.rb_refreshCoalesceScheduled = NO;
        return;
    }
    NSInteger listCount = (NSInteger)[self getChattingDatasList].count;
    NSInteger cvCount = (NSInteger)[self.collectionView numberOfItemsInSection:0];
    if (listCount != cvCount) {
        static const NSInteger kMaxRetry = 6;
        NSNumber *retryN = objc_getAssociatedObject(self, @selector(rb_flushPendingRefresh));
        NSInteger retry = retryN ? retryN.integerValue : 0;
        if (retry >= kMaxRetry) {
            NSArray<NSIndexPath *> *paths = [_rb_pendingRefreshIndexPaths allObjects];
            NSMutableArray<NSIndexPath *> *safePaths = [NSMutableArray array];
            NSInteger maxSafeCount = MIN(listCount, cvCount);
            for (NSIndexPath *path in paths) {
                if (path.section == 0 && path.item >= 0 && path.item < maxSafeCount) {
                    [safePaths addObject:path];
                }
            }
            [_rb_pendingRefreshIndexPaths removeAllObjects];
            objc_setAssociatedObject(self, @selector(rb_flushPendingRefresh), @(0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            self.rb_refreshCoalesceScheduled = NO;
            if (safePaths.count > 0) {
                [UIView performWithoutAnimation:^{
                    [self.rb_cachedLayoutMetaByMessageKey removeAllObjects];
                    [self.collectionView reloadItemsAtIndexPaths:safePaths];
                }];
            }
            return;
        }
        objc_setAssociatedObject(self, @selector(rb_flushPendingRefresh), @(retry + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak typeof(self) wself = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [wself rb_flushPendingRefresh];
        });
        return;
    }
    objc_setAssociatedObject(self, @selector(rb_flushPendingRefresh), @(0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSArray *paths = [_rb_pendingRefreshIndexPaths allObjects];
    [_rb_pendingRefreshIndexPaths removeAllObjects];
    self.rb_refreshCoalesceScheduled = NO;
    [UIView performWithoutAnimation:^{
        [self.rb_cachedLayoutMetaByMessageKey removeAllObjects];
        [self.collectionView reloadItemsAtIndexPaths:paths];
    }];
}

/// 后台加载图片消息的磁盘缓存/本地文件，命中后局部刷新；未命中时回调给网络回退逻辑。
- (void)rb_loadLocalImageInBackgroundForImageWithImgName:(NSString *)imgName previewDownloadPath:(NSString *)previewDownloadPath fullDownloadPath:(NSString *)fullDownloadPath msgType:(int)msgType tag:(NSString *)tag photoItem:(JSQPhotoMediaItem *)photoItem indexPath:(NSIndexPath *)indexPath onMiss:(dispatch_block_t)onMiss
{
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:previewDownloadPath];
        if (img == nil) {
            img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:fullDownloadPath];
        }
        if (img == nil) {
            img = [wself loadLocalImg:imgName msgType:msgType withTag:tag];
        }
        if (img == nil) {
            img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:fullDownloadPath];
        }
        if (img) {
            img = [wself rb_forceDecodeImage:img];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!wself || !photoItem) return;
            if (img) {
                photoItem.image = img;
                photoItem.loadComplete = YES;
                [[SDImageCache sharedImageCache] storeImage:img forKey:fullDownloadPath completion:nil];
                [[SDImageCache sharedImageCache] storeImage:img forKey:previewDownloadPath completion:nil];
                [wself rb_refreshItemAtIndexPath:indexPath];
            } else if (onMiss) {
                onMiss();
            }
        });
    });
}

/// 后台加载短视频首帧预览图，命中后局部刷新；未命中时回调给网络回退逻辑。
- (void)rb_loadLocalImageInBackgroundForShortVideoWithPreviewName:(NSString *)previewName fileDownloadPath:(NSString *)fileDownloadPath msgType:(int)msgType tag:(NSString *)tag photoItem:(JSQVideoMediaItem *)photoItem indexPath:(NSIndexPath *)indexPath onMiss:(dispatch_block_t)onMiss
{
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *img = [wself loadLocalImg:previewName msgType:msgType withTag:tag];
        if (img == nil) {
            img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:fileDownloadPath];
        }
        if (img) {
            img = [wself rb_forceDecodeImage:img];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!wself || !photoItem) return;
            if (img) {
                photoItem.image = img;
                photoItem.loadComplete = YES;
                [[SDImageCache sharedImageCache] storeImage:img forKey:fileDownloadPath completion:nil];
                [wself rb_refreshItemAtIndexPath:indexPath];
            } else if (onMiss) {
                onMiss();
            }
        });
    });
}

/// 后台加载位置消息预览图，命中后局部刷新；未命中时回调给网络回退逻辑。
- (void)rb_loadLocalImageInBackgroundForLocationPreviewName:(NSString *)previewName fileDownloadPath:(NSString *)fileDownloadPath msgType:(int)msgType tag:(NSString *)tag locationItem:(rbLocationMediaItem *)locationItem indexPath:(NSIndexPath *)indexPath onMiss:(dispatch_block_t)onMiss
{
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *img = nil;
        if (previewName.length > 0) {
            img = [wself loadLocalImg:previewName msgType:msgType withTag:tag];
        }
        if (img == nil) {
            img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:fileDownloadPath];
        }
        if (img) {
            img = [wself rb_forceDecodeImage:img];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!wself || !locationItem) return;
            if (img) {
                locationItem.image = img;
                locationItem.loadComplete = YES;
                [[SDImageCache sharedImageCache] storeImage:img forKey:fileDownloadPath completion:nil];
                [wself rb_refreshItemAtIndexPath:indexPath];
            } else if (onMiss) {
                onMiss();
            }
        });
    });
}

#pragma mark - 其它辅助方法

- (void)showBigImage4Received:(NSString *)imgHttpUrl
{
    //** 在独立的界面中查看大图（原图）
    [BasicTool showImageWithURL:imgHttpUrl];
}

- (void)showBigImage4Send:(UIImage *)img// withName:(NSString *)imgFileName
{
    //** 在独立的界面中查看大图（原图）
    [BasicTool showImage:img];
}

// 读取本地发出的消息图片（比如：图片消息中的图片、短视频的预览图、位置的预览图等），并尝试将其放入缓存中（放入SDImageCache缓存中管理是防止存在大量图片消息的情况下
// 不至于发生内存占用过大的问题，由SDImageCache智能管理内存），以备后绪使用。
- (UIImage *)loadLocalImg:(NSString *)fileName msgType:(int)msgType withTag:(NSString *)tag
{
    // 先看看该图片是否已在于SDWebImage有缓存中（内存或SD卡）
    UIImage *image = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:fileName];
    
    // 该图片不存
    if(image == nil)
    {
        NSString *dir = nil;
        switch (msgType)
        {
            case TM_TYPE_IMAGE:
                dir = [SendImageHelper getSendPicSavedDirHasSlash];
                break;
            case TM_TYPE_SHORTVIDEO:
                dir = [ReceivedShortVideoHelper getReceivedFileSavedDirHasSlash];
                break;
            case TM_TYPE_LOCATION:
                dir = [LocationUtils getLocationPreviewFileSavedDirHasSlash];
                break;
            default:
                // 未知类型不崩溃（如语音/文件等消息无预览图目录）
                break;
        }
        
        if (dir.length > 0) {
            NSString *imgLocalPath = [NSString stringWithFormat:@"%@%@", dir, fileName];
            image = [BasicTool loadImage:imgLocalPath];
        }
        // 本地图片读取成功
        if(image != nil)
        {
//          SDWebImageManager *manager = [SDWebImageManager sharedManager];
            // 把加载好的图片放到缓存中备用
//          [manager saveImageToCache:imgForLoad forURL:[NSURL URLWithString:fileName]];
            [[SDImageCache sharedImageCache] storeImage:image forKey:fileName completion:nil];
        }
    }

    return image;
}

- (void)gotoVoiceRecord
{
    [IQAudioRecorderViewController presentBlurredAudioRecorderViewControllerAnimated2:self delegate:self maxDuration:LOCAL_VOICE_AUDIO_LENGTH sendButtonText:nil cancelButtonText:nil sendButtonImage:nil sendButtonImageHighlight:nil sendButtonTextColor:nil];
}

// 从当前界面回退
- (void)doBack:(BOOL)animated
{
    [self.navigationController popViewControllerAnimated:animated];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 秒开：首帧设置（由子类在 viewDidLoad 数据就绪后立即调用，仅执行一次）
- (void)rb_deferredSetupAfterFirstFrame
{
    if (self.rb_didDeferredSetupFirstFrame) return;
    self.rb_didDeferredSetupFirstFrame = YES;
    BOOL shouldDeferInitialChatListReload = self.rb_shouldDeferInitialChatListReloadUntilSqliteBootstrap
        && [self getChattingDatasList].count == 0;
    // 布局前缓存「显示群成员昵称」开关，避免布局热路径中频繁读 UserDefaults（P0-3）
    if (self.toId.length > 0) {
        self.rb_cachedShowGroupMemberNickname = [UserDefaultsToolKits getShowGroupMemberNickname:self.toId];
    }
    // 先替换极简导航栏为完整自定义导航栏，再由子类设置右侧/副标题（无动画，直接显示，避免「呼吸」感）
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    @try {
        [UIView performWithoutAnimation:^{
            [self rb_deferredSetupCustomNavigationBar];
        }];
    } @finally {
        [CATransaction commit];
    }
    // 首帧即设置气泡字体，与 viewDidAppear 一致，避免 viewDidAppear 再 invalidate+reload 导致气泡时间闪烁
    id layout = self.collectionView.collectionViewLayout;
    if ([layout respondsToSelector:@selector(setMessageBubbleFont:)]) {
        [layout setMessageBubbleFont:[BasicTool getSystemFontOfSize:17.0f]];
    }
    // 秒显：使用预创建的共享气泡图，首帧即真实气泡、仅一次 reloadData；无动画执行，避免转场时列表「从右上飘下来」
    JSQMessagesBubbleImage *outgoing = nil, *outgoingLight = nil, *incoming = nil;
    [ViewControllerFactory getSharedBubbleImagesOutgoing:&outgoing outgoingLight:&outgoingLight incoming:&incoming];
    if (outgoing) self.outgoingBubbleImageData = outgoing;
    if (outgoingLight) self.outgoingBubbleImageData_light = outgoingLight;
    if (incoming) self.incomingBubbleImageData = incoming;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    @try {
        [UIView performWithoutAnimation:^{
        // 先让 view 树完成布局，collectionView 获得正确 bounds，首帧布局才能完整；整页（含聊天记录）一起显示，不分次加载
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        // 禁用首帧时 collectionView 的隐式动画，整页滑入时列表不单独「飘入」
        self.collectionView.layer.actions = @{ @"bounds": [NSNull null], @"position": [NSNull null], @"opacity": [NSNull null] };
        [self rb_resetChattingListLayoutSnapshot];
        [self rb_restorePartnerReadWatermarkAndApplyToCurrentListIfNeeded];
        if (!shouldDeferInitialChatListReload) {
            [self.collectionView reloadData];
        }
        // 首帧布局完成后重算 inset（此时 contentSize/safeArea 已就绪，避免初始化被穿过）
        [self jsq_updateCollectionViewInsets];
        // 搜索带指纹进会话：由 viewWillAppear 的 doHighlightOnceMessage 定位锚点，此处勿先滚到底部，否则与高亮滚动争抢导致错位
        if (!shouldDeferInitialChatListReload && [BasicTool trim:self.highlightOnceMsgFingerprint].length == 0) {
            [self scrollToBottomAnimated:NO];
        } else if (!shouldDeferInitialChatListReload) {
            NSLog(@"【RB-SEARCH-JUMP】firstFrame skip scrollToBottom (have fp) toId=%@", self.toId ?: @"-");
        }
    }];
    } @finally {
        [CATransaction commit];
    }
    [self rb_evaluateChatFirstScreenSkeletonCover];
    // 延后到转场动画结束后再执行，避免转场中二次 layout/reload 造成「飘下来」感（Push 约 0.28s）
    __weak typeof(self) wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.32 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [wself rb_deferredSetupRest];
    });
}

/// 首帧之后执行：导航栏补充、@ 提示、滚动到底部按钮、“更多”面板等（不阻塞首帧绘制）
- (void)rb_deferredSetupRest
{
    // 若首帧已从共享缓存拿到气泡图则不再创建、不再二次 reloadData；若有 reload 则无动画，避免「飘下来」
    if (self.outgoingBubbleImageData == nil) {
        JSQMessagesBubbleImageFactory *bubbleFactory = [[JSQMessagesBubbleImageFactory alloc] init];
        self.outgoingBubbleImageData = [bubbleFactory outgoingMessagesBubbleImage];
        self.outgoingBubbleImageData_light = [bubbleFactory outgoingMessagesBubbleImage_wechatGreen];
        self.outgoingBubbleImageData_white = [bubbleFactory outgoingMessagesBubbleImage_white];
        self.incomingBubbleImageData = [bubbleFactory incomingMessagesBubbleImage_white];
        [UIView performWithoutAnimation:^{
            [self rb_invalidateChattingListLayoutCache];
            [self.collectionView reloadData];
        }];
    }

    [self rb_didSetupCustomNavigationBar];
    __weak typeof(self) wself = self;
    // “@我提示 / 回到底部按钮”不影响首屏消息可见性，转场稳定后再挂上，避免与首帧列表布局抢主线程。
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wself) sself = wself;
        if (!sself || !sself.view.window) return;
        [sself initAtMeHintUI];
        [sself initScrollToBottomButton];
        [sself rb_deferredSetupAfterMoreContent];
    });
    // “更多”面板最重，继续往后错开，避免和首屏 collectionView reload/layout 同拍发生。
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        [sself rb_ensureMoreContentViewInitializedIfNeeded];
    });
    // 首帧后若补过气泡图会 reloadData，易抵消此前搜索锚点滚动；指纹仍在时再跑一次高亮定位（与 viewDidAppear 的异步重试互补）
    if ([BasicTool trim:self.highlightOnceMsgFingerprint].length > 0) {
        NSLog(@"【RB-SEARCH-JUMP】deferredSetupRest schedule redo doHighlight toId=%@", self.toId ?: @"-");
        dispatch_async(dispatch_get_main_queue(), ^{
            ChatRootViewController *s = wself;
            if (!s || [BasicTool trim:s.highlightOnceMsgFingerprint].length == 0) return;
            (void)[s doHighlightOnceMessage];
        });
    }
}

/// 子类可重写，用于延后初始化「更多」之外的首帧非必需 UI（如群聊 initMuteOverlay）
- (void)rb_deferredSetupAfterMoreContent
{
}

/// 基类空实现，子类重写以初始化「更多」面板（含多张 imageNamed，故延后调用）
- (void)initMoreContentView
{
}

/// 表情面板体积较大（表情页、贴纸数据、按钮事件），改为首次点击表情时再构建，避免进入会话就同步初始化。
- (void)rb_ensureFaceBoardInitializedIfNeeded
{
    if (self.faceBoard != nil) {
        return;
    }
    [self initFaceBoard];
}

/// “更多”面板会同步创建多张图片和标题按钮，日志已体现 UILabel/UIButton 布局热点，因此改为按需初始化。
- (void)rb_ensureMoreContentViewInitializedIfNeeded
{
    if (self.rb_didInitMoreContentView) {
        return;
    }
    [self initMoreContentView];
    [self.bottomBoxMoreView reloadData];
    self.rb_didInitMoreContentView = YES;
}

#pragma mark - 表情相关
- (void)initFaceBoard
{
//    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
//    paragraphStyle.lineSpacing = 2;// 字体的行间距
    UITextView *composerTextView = [self rb_currentComposerTextView];
    UIFont *composerFont = composerTextView.font ?: MESSAGE_COMPOSER_TEXT_VIEW_DEFAULT_FONT;
    self.inputTextAttributes = @{
            NSFontAttributeName:composerFont, //[UIFont systemFontOfSize:17]
//            NSParagraphStyleAttributeName:paragraphStyle
//            NSBaselineOffsetAttributeName:@0
        };
    CGRect rect = CGRectMake(0, 0, self.view.bounds.size.width, 296);//240
    FaceBoardConfig *config = [[FaceBoardConfig alloc] init];
    config.emojiLineCount = 4;
    config.emojiColumnCount = 7;
    self.faceBoard = [[FaceBoardView alloc] initWithFrame:rect config:config delegate:self];
    
    // 不再给输入框额外挂 tap 手势，避免干扰 UITextView 自带的双击选词/粘贴菜单手势。
    // 切回系统键盘的逻辑放到 textViewDidBeginEditing 中处理。
}

- (void)inputViewTapped:(UITextView *)textView
{
    [self jsq_switchToSystemKeyboardFromInputToolbar];
}

// 已显示表情/更多时点击输入框会触发（通过 tap 手势）；或由 inputViewTapped 调用
- (void)jsq_handleInputAreaTapWhenCustomPanelShowing:(UITapGestureRecognizer *)gesture
{
    UITextView *textView = self.inputToolbar.contentView.textView;
    if (textView.inputView == nil) return; // 已是键盘，无需处理
    [self jsq_switchToSystemKeyboardFromInputToolbar];
}

- (void)jsq_switchToSystemKeyboardFromInputToolbar
{
    UITextView *textView = self.inputToolbar.contentView.textView;
    textView.inputView = nil;
    if (![textView isFirstResponder]) {
        [textView becomeFirstResponder];
    } else {
        [textView reloadInputViews];
    }
    [self resetLeftButton2Style];
}

/// TGInputBar 内表情按钮：切换系统键盘与表情面板（与 didPressLeftButton2 逻辑一致，使用 tgInputBar.textView）
- (void)rb_tgInputBar_toggleFaceBoard
{
    if (!self.tgInputBar) return;
    [self rb_ensureFaceBoardInitializedIfNeeded];
    UITextView *textView = self.tgInputBar.textView;
    BOOL isAlreadyFirstResponder = [textView isFirstResponder];
    if (textView.inputView != self.faceBoard) {
        textView.inputView = self.faceBoard;
        self.jsq_didJustOpenCustomInputView = YES;
    } else {
        textView.inputView = nil;
    }
    [textView reloadInputViews];
    if (!isAlreadyFirstResponder) {
        [textView becomeFirstResponder];
    }
}

/// TGInputBar 内「更多」按钮：切换系统键盘与更多面板（与表情一致，用 inputView 从底部顶起，不悬浮）
- (void)rb_tgInputBar_toggleMorePanel
{
    [self rb_ensureMoreContentViewInitializedIfNeeded];
    if (!self.tgInputBar || !self.bottomBoxContainerView) return;
    UITextView *textView = self.tgInputBar.textView;
    BOOL isAlreadyFirstResponder = [textView isFirstResponder];
    if (textView.inputView != self.bottomBoxContainerView) {
        textView.inputView = self.bottomBoxContainerView;
        self.jsq_didJustOpenCustomInputView = YES;
    } else {
        textView.inputView = nil;
    }
    [textView reloadInputViews];
    if (!isAlreadyFirstResponder) {
        [textView becomeFirstResponder];
    }
}

// 按钮事件：表情的处理与发送实现方法
// ★ 性能优化：避免 reloadInputViews + becomeFirstResponder 造成双重动画
- (void)didPressLeftButton2:(UIButton *)sender
{
    [self rb_ensureFaceBoardInitializedIfNeeded];
    UITextView *textView = self.inputToolbar.contentView.textView;
    BOOL isAlreadyFirstResponder = [textView isFirstResponder];
    
    if (textView.inputView != self.faceBoard) {
        textView.inputView = self.faceBoard;
        [self setLeftButton2ToKeyboardStyle];
        self.jsq_didJustOpenCustomInputView = YES;  // 供 textViewDidBeginEditing 识别，避免误切回键盘
    } else {
        textView.inputView = nil;
        [self resetLeftButton2Style];
    }
    // 先 reloadInputViews 再 becomeFirstResponder，避免首次打开时误弹出系统键盘
    [textView reloadInputViews];
    if (isAlreadyFirstResponder) {
        // 已是第一响应者，reload 已足够切换面板
    } else {
        [textView becomeFirstResponder];
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - FaceBoardViewDelegate

/// 当前参与输入的 TextView（TGInputBar 时用 tg 的，否则用原 inputToolbar 的），供表情/发送等统一写入
- (UITextView *)rb_currentComposerTextView {
    return self.tgInputBar ? self.tgInputBar.textView : self.inputToolbar.contentView.textView;
}

// 点击emoji表情
- (void)faceBoardView:(FaceBoardView *)faceBoardView clickedEmojiWith:(FaceMeta *)emoji{
    UITextView *tv = [self rb_currentComposerTextView];
    NSRange selectedRange = tv.selectedRange;
    NSAttributedString *emojiAttributedString = [[NSAttributedString alloc] initWithString:emoji.desc];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithAttributedString:tv.attributedText];
    [attributedText replaceCharactersInRange:selectedRange withAttributedString:emojiAttributedString];//此处通过range进行replace实际上是追加
    tv.attributedText = attributedText;
    tv.selectedRange = NSMakeRange(selectedRange.location + emojiAttributedString.length, 0);
    [self textViewDidChange:tv];
    
//    // 重新设置一下输入框的默认字体大小，不然因为表情富文本的影响，全部表情删除完成后输入
//    // 框的字体会变的很小，暂时原因不明，只能强行重置字体大小来纠正
//    self.inputToolbar.contentView.textView.font = MESSAGE_COMPOSER_TEXT_VIEW_DEFAULT_FONT;
}

// 点击删除
- (void)faceBoardView:(FaceBoardView *)faceBoardView clickedDeleteWith:(UIButton *)button {
    UITextView *tv = [self rb_currentComposerTextView];
    NSRange selectedRange = tv.selectedRange;
    if (selectedRange.location == 0 && selectedRange.length == 0) {
        return;
    }
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithAttributedString:tv.attributedText];
    // selectedRange.length > 0 表示有文本内容处理高亮“选择”状态，否则表示没有内容被选中
    if (selectedRange.length > 0) {
        [attributedText deleteCharactersInRange:selectedRange];
        tv.attributedText = attributedText;
        tv.selectedRange = NSMakeRange(selectedRange.location, 0);
    } else {
//        NSUInteger deleteCharactersCount1 = 1;
        
        NSRange deleteCharactersRange = NSMakeRange(NSNotFound, 0);
        NSRange selectedRangeAfterDelete = NSMakeRange(NSNotFound, 0);
        
        //******************************* 先看看是否是表情 *******************************👇
        NSUInteger deleteEmojiCharactersCount = 0;
        // 下面这段正则匹配是用来匹配文本中的所有系统自带的 emoji 表情，以确认删除按钮将要删除的是否是 emoji。这个正则匹配可以匹配绝大部分的 emoji，得到该 emoji 的正确的 length 值；不过会将某些 combined emoji（如 �‍�‍�‍� �‍�‍�‍� �‍�‍�‍�），这种几个 emoji 拼在一起的 combined emoji 则会被匹配成几个个体，删除时会把 combine emoji 拆成个体。瑕不掩瑜，大部分情况下表现正确，至少也不会出现删除 emoji 时崩溃的问题了。
        NSString *emojiPattern1 = @"[\\u2600-\\u27BF\\U0001F300-\\U0001F77F\\U0001F900-\\U0001F9FF]";
        NSString *emojiPattern2 = @"[\\u2600-\\u27BF\\U0001F300-\\U0001F77F\\U0001F900–\\U0001F9FF]\\uFE0F";
        NSString *emojiPattern3 = @"[\\u2600-\\u27BF\\U0001F300-\\U0001F77F\\U0001F900–\\U0001F9FF][\\U0001F3FB-\\U0001F3FF]";
        NSString *emojiPattern4 = @"[\\rU0001F1E6-\\U0001F1FF][\\U0001F1E6-\\U0001F1FF]";
        NSString *pattern = [[NSString alloc] initWithFormat:@"%@|%@|%@|%@", emojiPattern4, emojiPattern3, emojiPattern2, emojiPattern1];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:kNilOptions error:NULL];
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:attributedText.string options:kNilOptions range:NSMakeRange(0, attributedText.string.length)];
        for (NSTextCheckingResult *match in matches) {
            if (match.range.location + match.range.length == selectedRange.location) {
                deleteEmojiCharactersCount = match.range.length;
                break;
            }
        }
        
        //****************************** 没有匹配到表情符号，再看看是否是 “@某人” ************👇
        if(deleteEmojiCharactersCount <= 0) {
            AtBlock *deleteAtItem = nil;
            
            // "@"功能当前仅用于群聊时
            if(self.chatType == CHAT_TYPE_GROUP_CHAT) {
                deleteAtItem = [self.atCache delRangeForAt:tv];
            }
            
            // 表示匹配到了 @某人 信息
            if(deleteAtItem != nil) {
                deleteCharactersRange = deleteAtItem.range;
                selectedRangeAfterDelete = NSMakeRange(deleteCharactersRange.location, 0);
            }
            // @某人 信息也没有匹配到的话，就按普通文本去删除
            else {
                deleteCharactersRange = NSMakeRange(selectedRange.location - 1, 1);
                selectedRangeAfterDelete = NSMakeRange(selectedRange.location - 1, 0);
            }
        }
        // 表示匹配到了表情符号
        else {
//          deleteCharactersCount1 = deleteEmojiCharactersCount;
            deleteCharactersRange = NSMakeRange(selectedRange.location - deleteEmojiCharactersCount, deleteEmojiCharactersCount);
            selectedRangeAfterDelete = NSMakeRange(selectedRange.location - deleteEmojiCharactersCount, 0);
        }
        
        if(deleteCharactersRange.location != NSNotFound && deleteCharactersRange.location >= 0 && deleteCharactersRange.length <= attributedText.string.length) {
            [attributedText deleteCharactersInRange:deleteCharactersRange
//          NSMakeRange(selectedRange.location - deleteCharactersCount, deleteCharactersCount)
            ];
        }
        tv.attributedText = attributedText;
        if(selectedRangeAfterDelete.location != NSNotFound) {
            tv.selectedRange = selectedRangeAfterDelete;//NSMakeRange(selectedRange.location - deleteCharactersCount, 0);
        }
    }
    [self textViewDidChange:tv];
    
//    // 重新设置一下输入框的默认字体大小，不然因为表情富文本的影响，全部表情删除完成后输入
//    // 框的字体会变的很小，暂时原因不明，只能强行重置字体大小来纠正
//    self.inputToolbar.contentView.textView.font = MESSAGE_COMPOSER_TEXT_VIEW_DEFAULT_FONT;
}

// 点击表情面板发送按钮
- (void)faceBoardView:(FaceBoardView *)faceBoardView clickedSendWith:(UIButton *)button {
    UITextView *tv = [self rb_currentComposerTextView];
    // 调用父类JSQ方法，而父类方法又会调用本root类的各子类方法didPressSendButtonInKeybord
    [self textView:tv shouldChangeTextInRange:NSMakeRange(0, tv.attributedText.length) replacementText:@"\n"]; // @"\n"即为软键盘的回车/发送键
}

// 点击自定义表情 → 作为图片消息发送
- (void)faceBoardView:(FaceBoardView *)faceBoardView clickedStickerWith:(NSDictionary *)stickerInfo {
    NSString *fileName = [stickerInfo objectForKey:@"file_name"];
    if (!fileName || fileName.length == 0) return;
    
    // 异步加载表情图片并作为图片消息发送
    [[StickerManager sharedInstance] loadStickerImage:stickerInfo complete:^(UIImage * _Nullable image) {
        if (image) {
            // 直接调用图片发送流程
            [self processImagePickerComplete:image withTag:@"sticker"];
        }
    }];
}

// 点击表情管理按钮 → 打开管理页面
- (void)faceBoardViewDidClickManage:(FaceBoardView *)faceBoardView {
    StickerManageViewController *vc = [[StickerManageViewController alloc] init];
    vc.manageDelegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - StickerManageDelegate

- (void)stickerManageDidChange {
    // 表情管理发生变更，刷新表情面板
    [self.faceBoard reloadStickerData];
}

// @Override - 重写了父类中的方法，用于补充表情相关的逻辑！
// 父类jsqMessageController使用了textview的代理，所以此处重写代理方法会被执行.其实此处内容没必要在代理中执行，完全可以在独立的自定义方法中执行，
// 因为此处为针对输入emoji图片表情而编写，而输入emoji图片表情不会自动执行代理方法，需手动调用。但是有个奇怪的现象，如果将此方法改名，使其为非代理方法，先输入表情，再输入文字，文字则会变小
// 经测试，当输入中文字符时，代理方法会被执行两次，当输入非中文字符时，代理方法执行一次，当点击emoji图片表情、点击表情面板的删除键改变textview的富文本时，代理方法不会执行，所以需手动调用
- (void)textViewDidChange:(UITextView *)textView {  
    if (textView != [self rb_currentComposerTextView]) {
        return;
    }
    
    if (!textView.markedTextRange) {
        NSString *plain = textView.attributedText.string ?: @"";
        BOOL containsEmojiToken = ([plain rangeOfString:@"[/"].location != NSNotFound
                                  || [plain rangeOfString:@"［／"].location != NSNotFound);
        if (!containsEmojiToken) {
            if (self.inputTextAttributes.count > 0) {
                textView.typingAttributes = self.inputTextAttributes;
            }
            [self jsq_refreshRightBarButtonIcon];
            return;
        }
        NSRange selectedRange = textView.selectedRange;
        NSAttributedString *attributedString = [EmojiUtil replaceEmojiWithAttributedString:textView.attributedText attributes:self.inputTextAttributes];
        NSUInteger offset = textView.attributedText.length - attributedString.length;
        textView.attributedText = attributedString;
        NSUInteger targetLocation = (selectedRange.location >= offset) ? (selectedRange.location - offset) : 0;
        textView.selectedRange = NSMakeRange(targetLocation, 0);
        if (self.inputTextAttributes.count > 0) {
            textView.typingAttributes = self.inputTextAttributes;
        }
    } else {
        // 输入汉字拼音未确定状态, 不做处理
    }

    [self jsq_refreshRightBarButtonIcon];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if (textView != [self rb_currentComposerTextView]) {
        return;
    }

    // 若本次成为第一响应者是因为刚点了「+」或表情按钮，不要清空 inputView，否则会先出面板再误弹出键盘；表情按钮已在 didPressLeftButton2 中切为键盘图标，此处不要再改回
    if (self.jsq_didJustOpenCustomInputView) {
        self.jsq_didJustOpenCustomInputView = NO;
        return;
    }

    // 若当前是自定义表情/更多面板，用户点入输入框后切回系统键盘
    if (textView.inputView != nil) {
        textView.inputView = nil;
        [textView reloadInputViews];
    }
    [self resetLeftButton2Style];
}


#pragma mark - 消息重发相关方法

/** 点击失败消息前的红点，触发重发；不论新发送成功或失败，都先删除原失败气泡再重发 */
- (void)jsq_onResendFailedMessageTap:(UIButton *)sender
{
    UIView *v = sender.superview;
    if (!v) return;
    JSQMessagesCollectionViewCell *cell = nil;
    if ([v.superview isKindOfClass:[JSQMessagesCollectionViewCell class]]) {
        cell = (JSQMessagesCollectionViewCell *)v.superview;
    } else if (v.superview.superview != nil && [v.superview.superview isKindOfClass:[JSQMessagesCollectionViewCell class]]) {
        cell = (JSQMessagesCollectionViewCell *)v.superview.superview;
    }
    if (!cell) return;
    NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
    if (!indexPath) return;
    JSQMessage *message = [self rb_safeMessageAtIndex:indexPath.item];
    if (!message) return;
    [self removeFailedMessageBeforeResend:message];
    [self reSend:NO message:message toChatType:self.chatType toId:self.toId toName:self.toName forSucess:nil];
}

/** 点击重发时删除原发送失败的消息气泡（内存 + 本地 DB），不论新发送成功或失败都先删再发 */
- (void)removeFailedMessageBeforeResend:(JSQMessage *)oldMessage
{
    if (oldMessage.fingerPrintOfProtocal.length == 0 || self.toId.length == 0) return;
    MessagesProvider *mp = nil;
    if (self.chatType == CHAT_TYPE_GROUP_CHAT) {
        mp = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
    } else {
        mp = [[IMClientManager sharedInstance] getMessagesProvider];
    }
    if (mp) {
        [mp removeMessage:self.toId fp:oldMessage.fingerPrintOfProtocal isDeleteLocalDatas:YES];
    }
}

/**
 * 消息重发统一接口。
 *
 * @param activity
 * @param cme
 * @param to
 */
- (void)reSend:(JSQMessage *)cme// toId:(NSString *)toId toName:(NSString *)toName
{
    [self reSend:NO message:cme toChatType:self.chatType toId:self.toId toName:self.toName forSucess:nil];
}

/**
 * 消息重发统一接口。
 * <p>
 * 注：目前为了重用代码，消息转发功能重用了消息重发功能的代码逻辑，日后如消息重发功能逻辑需独立演进，再考虑单
 * 独维护消息重发功能的代码不迟！
 *
 * @param activity
 * @param forForward true表示用于消息转发功能，否则不是
 * @param cme
 * @param to
 * @param sucessObsExtra 消息发送完成后，额外要做的事
 */
- (void)reSend:(BOOL)forForward message:(JSQMessage *)cme toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forSucess:(ObserverCompletion)sucessObs
{
    if(cme != nil && (forForward || [cme isOutgoing])) {
        // 仅在转发到 10001 时生成“消息来源”引用信息，其它转发不带来源
        BOOL needSourceFor10001 = (forForward
                                   && chatType == CHAT_TYPE_FREIDN_CHAT
                                   && toId != nil
                                   && [toId isEqualToString:@"10001"]);
        QuoteMeta *forwardQuoteMeta = needSourceFor10001 ? [[self class] quoteMetaFromForwardMessage:cme] : nil;
        // 重发（非转发）时带上原消息的引用，保证重发内容与发送内容一致
        QuoteMeta *resendQuoteMeta = nil;
        if (!forForward && (cme.quote_fp.length > 0 || (cme.quote_content.length > 0))) {
            resendQuoteMeta = [[QuoteMeta alloc] init];
            resendQuoteMeta.quote_fp = cme.quote_fp;
            resendQuoteMeta.quote_sender_uid = cme.quote_sender_uid;
            resendQuoteMeta.quote_sender_nick = cme.quote_sender_nick;
            resendQuoteMeta.quote_content = cme.quote_content;
            resendQuoteMeta.quote_type = cme.quote_type;
            resendQuoteMeta.quote_status = cme.quote_status;
        }
        QuoteMeta *quoteToUse = (forwardQuoteMeta != nil ? forwardQuoteMeta : resendQuoteMeta);
        switch (cme.msgType) {
            case TM_TYPE_TEXT:
                [self reSendTextMessage:chatType toId:toId message:(cme.text ?: @"") quoteMeta:quoteToUse forSucess:sucessObs];
                break;
            case TM_TYPE_IMAGE:
                [self reSendImageMessage:forForward toChatType:chatType toId:toId toName:toName fileName:cme.text quoteMeta:quoteToUse];
                break;
            case TM_TYPE_VOICE:
                [self reSendVoiceMessage:forForward toChatType:chatType toId:toId toName:toName fileName:cme.text quoteMeta:quoteToUse];
                break;
            case TM_TYPE_FILE: {
                FileMeta *fm = [FileMeta fromJSON:cme.text];
                NSString *filePath = [NSString stringWithFormat:@"%@/%@", [ReceivedFileHelper getReceivedFileSavedDir], fm.fileName];
                [self reSendFileMessage:forForward toChatType:chatType toId:toId toName:toName filePath:filePath fileName:fm.fileName md5:fm.fileMd5 fileLength:fm.fileLength quoteMeta:quoteToUse];
                break;
            }
            case TM_TYPE_SHORTVIDEO: {
                NSString *ju = RBNormalizeFileMetaJSONStringForHistory(cme.text);
                if (ju.length == 0) ju = cme.text ?: @"";
                FileMeta *fm = [FileMeta fromJSON:ju];
                NSString *filePath = [NSString stringWithFormat:@"%@/%@", [ReceivedShortVideoHelper getReceivedFileSavedDir], fm.fileName];
                [self reSendShortVideoMessage:forForward toChatType:chatType toId:toId toName:toName filePath:filePath md5:fm.fileMd5 quoteMeta:quoteToUse];
                break;
            }
            case TM_TYPE_CONTACT: {
                ContactMeta *cm = [ContactMeta fromJSON:cme.text];
                [self reSendContactMessage:chatType toId:toId toName:toName cm:cm];
                break;
            }
            case TM_TYPE_LOCATION: {
                LocationMeta *lm = [LocationMeta fromJSON:cme.text];
                [self reSendLocationMessage:forForward toChatType:chatType toId:toId toName:toName lm:lm quoteMeta:quoteToUse];
                break;
            }
            default:{
                [BasicTool showAlertWarn:[NSString stringWithFormat:@"暂时不支持%@类型为 %d 的消息！", (forForward ? "转发":"重发"), cme.msgType] parent:self];
                break;
            }
        }
    } else {
        [BasicTool showAlertWarn:[NSString stringWithFormat:@"数据不完整，无法进行消息%@！", (forForward ? "转发":"重发")] parent:self];
    }
}

/**
 * 重发文本消息。
 *
 * @param context Context
 * @param toUid 消息接收者
 * @param message 消息内容
 * @param sucessObsExtra 消息发送完成后，额外要做的事
 */
- (void)reSendTextMessage:(int)chatType toId:(NSString *)toId message:(NSString *)message quoteMeta:(QuoteMeta *)quoteMeta forSucess:(ObserverCompletion)sucessObs
{
    [self sendPlainTextMessage:message toChatType:chatType toId:toId quoteMeta:quoteMeta forSucess:sucessObs];
}

/**
 * 重发图片消息。
 *
 * @param toId 消息接收者
 * @param imageFileName 图片文件名
 * @param sucessObsExtra 消息发送完成后，额外要做的事
 */
- (void)reSendImageMessage:(BOOL)forForward toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName fileName:(NSString *)imageFileName quoteMeta:(QuoteMeta *)quoteMeta
{
    [self processImagePickerCompleteImpl:imageFileName toChatType:chatType toId:toId toName:self.toName forForward:forForward withTag:(forForward ? @"图片消息转发":@"图片消息重发") quoteMeta:quoteMeta];
}

/**
 * 重发语音留言消息。
 *
 * @param toId 消息接收者
 
 * @param voiceFileName 语音留言音视频文件名
 * @param sucessObsExtra 消息发送完成后，额外要做的事
 */
- (void)reSendVoiceMessage:(BOOL)forForward toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName fileName:(NSString *)voiceFileName quoteMeta:(QuoteMeta *)quoteMeta
{
    [self processVoiceMessageSend:voiceFileName toChatType:chatType toId:toId toName:toName forForward:forForward quoteMeta:quoteMeta];
}

/**
 * 重发大文件消息。
 *
 * @param toId 接者者uid
 * @param filePath 文件完整路径
 * @param fileMD5 文件md5码
 * @param fileLenForForward 文件大小（单位：字节），此字段目前仅用于消息转发时（其它情况请传0），因为转发收到的文件
 *      *                   消息时，因此时文件可能尚未下载，如果直接通过从本地文件信息中读大小那就不可能了
 * @param sucessObsExtra 消息发送完成后，额外要做的事
 */
- (void)reSendFileMessage:(BOOL)forForward toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName filePath:(NSString *)filePath fileName:(NSString *)fileName md5:(NSString *)fileMD5 fileLength:(long long)fileLengForForward quoteMeta:(QuoteMeta *)quoteMeta
{
    [self processBigFileMessageSend:filePath fileName:fileName md5:fileMD5 fileLength:fileLengForForward toChatType:chatType toId:toId toName:toName forForward:forForward quoteMeta:quoteMeta];
}

/**
 * 重发短视频消息。
 *
 * @param toId 接者者uid
 * @param filePath 文件完整路径
 * @param fileMD5 文件md5码
 * @param sucessObsExtra 消息发送完成后，额外要做的事
 */
- (void)reSendShortVideoMessage:(BOOL)forForward toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName filePath:(NSString *)filePath md5:(NSString *)fileMD5 quoteMeta:(QuoteMeta *)quoteMeta
{
    [self processShortVideoMessageSend:filePath fileName:[filePath lastPathComponent] md5:fileMD5 fileLength:0 toChatType:chatType toId:toId toName:toName forForward:forForward quoteMeta:quoteMeta];
}

/**
 * 重发"个人名片"消息。
 *
 * @param toId 消息接收者
 * @param meta 消息内容
 * @param sucessObsExtra 消息发送完成后，额外要做的事
 */
- (void)reSendContactMessage:(int)chatType toId:(NSString *)toId toName:(NSString *)toName cm:(ContactMeta *)meta
{
    [self processContactChooseCompleteImpl:meta toChatType:chatType toId:toId toName:toName];
}

/**
 * 重发"位置"消息。
 *
 * @param toId 消息接收者
 * @param meta 消息内容
 * @param sucessObsExtra 消息发送完成后，额外要做的事
 */
- (void)reSendLocationMessage:(BOOL)forForward toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName lm:(LocationMeta *)meta quoteMeta:(QuoteMeta *)quoteMeta
{
    [self processLocationChooseComplete:meta toChatType:chatType toId:toId toName:toName forForward:forForward quoteMeta:quoteMeta];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 消息转发相关方法

/// 从被转发的原消息构建引用元数据，用于在气泡上显示「原发送者」
+ (QuoteMeta *)quoteMetaFromForwardMessage:(JSQMessage *)cme
{
    if (cme == nil) return nil;
    QuoteMeta *qm = [[QuoteMeta alloc] init];
    qm.quote_fp = cme.fingerPrintOfProtocal ?: cme.fingerPrintOfParent;
    qm.quote_sender_uid = cme.senderId;
    qm.quote_sender_nick = cme.senderDisplayName;
    qm.quote_content = [JSQMessage parseMessageContentPreview:cme.text withType:cme.msgType];
    if (qm.quote_content.length == 0) qm.quote_content = @" ";
    qm.quote_type = cme.msgType;
    qm.quote_status = 0;
    return qm;
}

- (void)forward:(JSQMessage *)cme toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forSucess:(ObserverCompletion)sucessObs
{
    [self reSend:YES message:cme toChatType:chatType toId:toId toName:toName forSucess:sucessObs];
}

//---------------------------------------------------------------------------------------------------
#pragma mark - 短视频播放 / 统一媒体浏览

/**
 * 显示短视频播放器，支持多个视频的左右滑动切换
 *
 * @param videoDataArray 视频数据数组，每个元素包含 duration, videoType, videoDataSrc 等信息
 * @param currentIndex 当前要播放的视频索引
 */

/**
 * 点击短视频气泡：直接进入播放页并自动播放（收集本会话内全部可播短视频，便于在播放器内切换）。
 */
- (void)openShortVideoDirectPlaybackForTappedMessageAtIndex:(NSInteger)tappedMessageIndex
{
    NSMutableArray<JSQMessage *> *allMessages = [self getChattingDatasList];
    NSMutableArray<NSDictionary *> *videoDataArray = [NSMutableArray array];
    NSInteger currentVideoIndex = 0;
    BOOL matchedTap = NO;

    for (NSInteger i = 0; i < (NSInteger)allMessages.count; i++) {
        JSQMessage *msg = [allMessages objectAtIndex:i];
        if (msg.msgType != TM_TYPE_SHORTVIDEO) {
            continue;
        }

        NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(msg.text);
        if (jsonUse.length == 0) jsonUse = msg.text ?: @"";
        FileMeta *fileMeta = [FileMeta fromJSON:jsonUse];
        if (fileMeta == nil || fileMeta.fileName == nil || fileMeta.fileName.length == 0) {
            continue;
        }

        int duration = [TimeTool getDurationFromVoiceFileName:fileMeta.fileName];
        if (duration <= 0) {
            NSData *jd = [jsonUse dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *dic = jd ? [NSJSONSerialization JSONObjectWithData:jd options:0 error:nil] : nil;
            if ([dic isKindOfClass:[NSDictionary class]]) {
                id durObj = dic[@"duration"];
                if (durObj != nil) duration = [durObj intValue];
            }
        }
        if (duration <= 0) duration = 1;

        NSString *cachedFileDir  = [ReceivedShortVideoHelper getReceivedFileSavedDir];
        NSString *cachedFilePath = [NSString stringWithFormat:@"%@/%@", cachedFileDir, fileMeta.fileName];

        NSMutableDictionary *vd = [NSMutableDictionary dictionary];
        vd[@"duration"] = @(duration);

        if ([FileTool fileExists:cachedFilePath]) {
            vd[@"videoType"]    = @(VideoDataType_FILE_PATH);
            vd[@"videoDataSrc"] = cachedFilePath;
        } else {
            NSString *downloadURL = [ReceivedShortVideoHelper getShortVideoDownloadURL:fileMeta.fileName md5:fileMeta.fileMd5];
            if (downloadURL == nil || downloadURL.length == 0) {
                continue;
            }
            vd[@"videoType"]    = @(VideoDataType_URL);
            vd[@"videoDataSrc"] = downloadURL;
        }

        [videoDataArray addObject:vd];
        if (i == tappedMessageIndex) {
            currentVideoIndex = (NSInteger)videoDataArray.count - 1;
            matchedTap = YES;
        }
    }

    if (videoDataArray.count == 0) {
        DDLogWarn(@"【短视频直播】本会话没有可播放的短视频");
        [BasicTool showAlertWarn:@"暂无法播放该视频" parent:self];
        return;
    }
    if (!matchedTap) {
        currentVideoIndex = 0;
    }

    super.automaticallyScrollsToMostRecentMessage_ignoreOnce = ![self isLastCellVisible];
    [self showShortVideoPlayerWithVideoArray:videoDataArray currentIndex:currentVideoIndex];
}

/**
 * 打开统一媒体浏览器，收集聊天中的所有图片和视频按消息顺序排列，
 * 支持左右滑动在图片、视频之间无缝切换。
 */
- (void)openUnifiedMediaBrowserForCurrentMessage:(NSInteger)currentMessageIndex
                                    clickedQuote:(BOOL)clickedQuote
                                          entity:(JSQMessage *)entity
{
    NSMutableArray<JSQMessage *> *allMessages = [self getChattingDatasList];
    NSMutableArray<NSDictionary *> *mediaDataArray = [NSMutableArray array];
    NSInteger tappedMediaIndex = 0;
    
    for (NSInteger i = 0; i < (NSInteger)allMessages.count; i++) {
        JSQMessage *msg = [allMessages objectAtIndex:i];
        
        // ————— 图片消息 —————
        if (msg.msgType == TM_TYPE_IMAGE) {
            NSString *imageFileName = msg.text;
            if (imageFileName == nil || imageFileName.length == 0) continue;
            
            NSString *imgUrl = [self getImageMessageDownloadURL:imageFileName];
            
            // 确保本地图片存入 SDImageCache
            UIImage *localImg = [self loadLocalImg:imageFileName msgType:TM_TYPE_IMAGE withTag:@"统一媒体浏览"];
            if (localImg && imgUrl.length > 0) {
                [[SDImageCache sharedImageCache] storeImage:localImg forKey:imgUrl completion:nil];
            }
            
            NSMutableDictionary *item = [NSMutableDictionary dictionary];
            item[@"type"]     = @(TM_TYPE_IMAGE);
            item[@"imageUrl"] = (imgUrl ?: @"");
            item[@"messageIndex"] = @(i);
            [mediaDataArray addObject:item];
            
            if (i == currentMessageIndex) {
                tappedMediaIndex = mediaDataArray.count - 1;
            }
        }
        // ————— 短视频消息 —————
        else if (msg.msgType == TM_TYPE_SHORTVIDEO) {
            NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(msg.text);
            if (jsonUse.length == 0) jsonUse = msg.text ?: @"";
            FileMeta *fileMeta = [FileMeta fromJSON:jsonUse];
            if (fileMeta == nil || fileMeta.fileName == nil || fileMeta.fileName.length == 0) continue;
            
            int duration = [TimeTool getDurationFromVoiceFileName:fileMeta.fileName];
            if (duration <= 0) {
                NSData *jd = [jsonUse dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *dic = jd ? [NSJSONSerialization JSONObjectWithData:jd options:0 error:nil] : nil;
                if ([dic isKindOfClass:[NSDictionary class]]) {
                    id durObj = dic[@"duration"];
                    if (durObj != nil) duration = [durObj intValue];
                }
            }
            if (duration <= 0) duration = 1;
            
            // 视频缩略图 URL
            NSString *thumbLocalName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:fileMeta.fileName];
            NSString *thumbUrl = [ReceivedShortVideoHelper getShortVideoThumbDownloadURL:thumbLocalName videofileMd5:(fileMeta.fileMd5 ?: @"")];
            
            // 本地缩略图也放入 SDImageCache
            UIImage *localThumb = [self loadLocalImg:thumbLocalName msgType:TM_TYPE_SHORTVIDEO withTag:@"统一媒体浏览-视频缩略图"];
            if (localThumb && thumbUrl.length > 0) {
                [[SDImageCache sharedImageCache] storeImage:localThumb forKey:thumbUrl completion:nil];
            }
            
            // 视频源
            NSString *cachedFileDir  = [ReceivedShortVideoHelper getReceivedFileSavedDir];
            NSString *cachedFilePath = [NSString stringWithFormat:@"%@/%@", cachedFileDir, fileMeta.fileName];
            
            NSMutableDictionary *item = [NSMutableDictionary dictionary];
            item[@"type"]     = @(TM_TYPE_SHORTVIDEO);
            item[@"imageUrl"] = (thumbUrl ?: @"");
            item[@"duration"] = @(duration);
            item[@"fileName"] = fileMeta.fileName;
            item[@"fileMd5"]  = (fileMeta.fileMd5 ?: @"");
            item[@"messageIndex"] = @(i);
            
            if ([FileTool fileExists:cachedFilePath]) {
                item[@"videoType"]    = @(VideoDataType_FILE_PATH);
                item[@"videoDataSrc"] = cachedFilePath;
            } else {
                NSString *downloadURL = [ReceivedShortVideoHelper getShortVideoDownloadURL:fileMeta.fileName md5:fileMeta.fileMd5];
                if (downloadURL != nil && downloadURL.length > 0) {
                    item[@"videoType"]    = @(VideoDataType_URL);
                    item[@"videoDataSrc"] = downloadURL;
                } else {
                    continue; // 无法获取视频源，跳过
                }
            }
            
            [mediaDataArray addObject:item];
            
            if (i == currentMessageIndex) {
                tappedMediaIndex = mediaDataArray.count - 1;
            }
        }
    }
    
    if (mediaDataArray.count == 0) {
        DDLogWarn(@"【统一媒体浏览】未找到有效的图片或视频消息");
        return;
    }
    
    // 从媒体浏览界面返回时，不需要自动滚动到底部
    super.automaticallyScrollsToMostRecentMessage_ignoreOnce = ![self isLastCellVisible];
    
    // 确保索引合法
    if (tappedMediaIndex < 0 || tappedMediaIndex >= (NSInteger)mediaDataArray.count) {
        tappedMediaIndex = 0;
    }
    
    UnifiedMediaBrowserViewController *browser = [[UnifiedMediaBrowserViewController alloc]
                                                   initWithMediaDataArray:mediaDataArray
                                                   currentIndex:tappedMediaIndex
                                                   browseItems:nil];
    browser.playbackNavigationController = self.navigationController;
    __weak typeof(self) wself = self;
    browser.onForwardBlock = ^(NSInteger messageIndexInChat) {
        NSMutableArray<JSQMessage *> *list = [wself getChattingDatasList];
        if (messageIndexInChat < 0 || messageIndexInChat >= (NSInteger)list.count) return;
        JSQMessage *entity = list[messageIndexInChat];
        if (entity == nil || ![entity isForwardEnabled]) return;
        wself.automaticallyScrollsToMostRecentMessage_ignoreOnce = YES;
        [ViewControllerFactory goTargetChooseViewController:wself.navigationController
                                      supportedTargetSource:TargetSourceLatestChatting | TargetSourceFriend | TargetSourceGroup
                                       latestChattingFilter:[TargetSourceFilterFactory createTargetSourceFilterLatestChatting4MsgForward:wself.chatType toId:wself.toId]
                                               friendFilter:[TargetSourceFilterFactory createTargetSourceFilterFriend4MsgForward:wself.chatType toId:wself.toId]
                                                groupFilter:[TargetSourceFilterFactory createTargetSourceFilterGroup4MsgForward:wself.chatType toId:wself.toId]
                                          groupMemberFilter:nil
                                                   extraObj:entity
                                                        gid:nil
                                                requestCode:TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD
                                                   delegate:wself];
    };
    browser.onViewInConversationBlock = ^(NSInteger messageIndexInChat) {
        NSMutableArray<JSQMessage *> *list = [wself getChattingDatasList];
        if (messageIndexInChat < 0 || messageIndexInChat >= (NSInteger)list.count) return;
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:messageIndexInChat inSection:0];
        [wself.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredVertically
                                            animated:YES];
    };
    [browser showBrowserViewController];
}

- (void)showShortVideoPlayerWithVideoArray:(NSArray<NSDictionary *> *)videoDataArray currentIndex:(NSInteger)currentIndex
{
    if (videoDataArray == nil || videoDataArray.count == 0) {
        DDLogError(@"【视频播放】videoDataArray为空，无法播放");
        return;
    }
    
    if (self.navigationController == nil) {
        DDLogError(@"【视频播放】navigationController为nil，无法播放视频");
        [BasicTool showAlertWarn:@"无法播放视频，请稍后重试！" parent:self];
        return;
    }
    
    // 确保 currentIndex 在有效范围内
    if (currentIndex < 0 || currentIndex >= videoDataArray.count) {
        currentIndex = 0;
    }
    
    // 如果只有一个视频，直接播放
    if (videoDataArray.count == 1) {
        NSDictionary *videoData = [videoDataArray objectAtIndex:0];
        int duration = [[videoData objectForKey:@"duration"] intValue];
        VideoDataType videoType = [[videoData objectForKey:@"videoType"] intValue];
        NSString *videoDataSrc = [videoData objectForKey:@"videoDataSrc"];
        
        if (videoDataSrc == nil || videoDataSrc.length == 0) {
            DDLogError(@"【视频播放】videoDataSrc为空，无法播放");
            [BasicTool showAlertWarn:@"视频数据无效，无法播放！" parent:self];
            return;
        }
        
        if (duration <= 0) {
            DDLogError(@"【视频播放】duration无效（%d），无法播放", duration);
            [BasicTool showAlertWarn:@"视频时长无效，无法播放！" parent:self];
            return;
        }
        
        if (videoType == VideoDataType_FILE_PATH) {
            [ViewControllerFactory goShortVideoPlayerViewController_fromFile:self.navigationController duaration:duration videoFilePath:videoDataSrc];
        } else if (videoType == VideoDataType_URL) {
            [ViewControllerFactory goShortVideoPlayerViewController_fromUrl:self.navigationController duaration:duration httpUrl:videoDataSrc];
        }
        return;
    }
    
    // 使用支持多视频播放的方法
    [ViewControllerFactory goShortVideoPlayerViewController_withVideoArray:self.navigationController videoDataArray:videoDataArray currentIndex:currentIndex];
}

#pragma mark - 草稿保存和恢复

/**
 * 获取草稿的存储key
 */
- (NSString *)getDraftKey
{
    if (!self.toId || self.toId.length == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"chat_draft_%d_%@", self.chatType, self.toId];
}

/**
 * 保存草稿内容
 */
- (void)saveDraft
{
    if (!self.toId || self.toId.length == 0) {
        return;
    }
    
    // 获取当前输入框的文本内容（使用 self 以支持 TGInputBar）
    NSString *draftText = [self jsq_currentlyComposedMessageText];
    
    // 如果文本为空或只有空白字符，则清除草稿
    if (!draftText || draftText.length == 0 || [[draftText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0) {
        [self clearDraft];
        return;
    }
    
    // 保存草稿到 NSUserDefaults
    NSString *draftKey = [self getDraftKey];
    if (draftKey) {
        [[NSUserDefaults standardUserDefaults] setObject:draftText forKey:draftKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

/**
 * 恢复草稿内容
 */
- (void)restoreDraft
{
    if (!self.toId || self.toId.length == 0) {
        return;
    }
    UITextView *targetTextView = nil;
    if (self.tgInputBar) {
        targetTextView = self.tgInputBar.textView;
    } else if (self.inputToolbar.contentView.textView) {
        targetTextView = self.inputToolbar.contentView.textView;
    }
    if (!targetTextView) {
        return;
    }

    NSString *draftKey = [self getDraftKey];
    if (!draftKey) {
        return;
    }

    NSString *draftText = [[NSUserDefaults standardUserDefaults] objectForKey:draftKey];
    if (draftText && draftText.length > 0) {
        NSDictionary *attrs = self.inputTextAttributes;
        if (!attrs) {
            UIFont *font = targetTextView.font ?: [UIFont systemFontOfSize:17];
            attrs = @{ NSFontAttributeName: font };
        }
        NSAttributedString *attributedString = [EmojiUtil replaceEmojiWithPlanString:draftText attributes:attrs];
        targetTextView.attributedText = attributedString;

        if (self.tgInputBar) {
            [self.tgInputBar refreshInputStateForCurrentTextAnimated:NO];
        } else {
            [self jsq_refreshRightBarButtonIcon];
            [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:targetTextView];
        }
        __weak typeof(self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (wself.tgInputBar) {
                [wself.tgInputBar refreshInputStateForCurrentTextAnimated:NO];
            } else {
                [wself jsq_refreshRightBarButtonIcon];
                [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:targetTextView];
            }
            [wself jsq_forceRecalculateInputToolbarHeight];
        });
    }
}

/**
 * 强制重新计算输入框工具栏高度（用于草稿恢复等场景）
 * KVO的增量(dy)计算在viewWillAppear布局未完成时可能不准确，此方法直接根据contentSize计算最终高度。
 */
- (void)jsq_forceRecalculateInputToolbarHeight
{
    if (self.tgInputBar) {
        if (!self.toolbarHeightConstraint) return;
        CGFloat h = self.tgInputBar.currentBarHeight;
        if (fabs(self.toolbarHeightConstraint.constant - h) > 0.5) {
            self.toolbarHeightConstraint.constant = h;
            [self.view setNeedsUpdateConstraints];
            [self.view layoutIfNeeded];
        }
        [self.tgInputBar setNeedsLayout];
        [self.tgInputBar layoutIfNeeded];
        [self jsq_updateCollectionViewInsets];
        if (self.automaticallyScrollsToMostRecentMessage) {
            [self scrollToBottomAnimated:NO];
        }
        UITextView *tv = self.tgInputBar.textView;
        CGFloat textContentOffsetY = tv.contentSize.height - CGRectGetHeight(tv.bounds);
        if (textContentOffsetY > 0) {
            tv.contentOffset = CGPointMake(0, textContentOffsetY);
        }
        return;
    }

    UITextView *textView = self.inputToolbar.contentView.textView;
    if (!textView || !self.toolbarHeightConstraint) return;

    [textView layoutIfNeeded];

    CGFloat contentHeight = textView.contentSize.height;
    CGFloat defaultHeight = [self.inputToolbar getPreferredDefaultHeight];
    CGFloat defaultTextViewHeight = defaultHeight - 16.0;
    CGFloat dy = contentHeight - defaultTextViewHeight;
    if (dy < 0) dy = 0;

    CGFloat targetToolbarHeight = defaultHeight + dy;

    if (self.inputToolbar.maximumHeight != NSNotFound) {
        targetToolbarHeight = MIN(targetToolbarHeight, self.inputToolbar.maximumHeight);
    }

    if (self.toolbarHeightConstraint.constant != targetToolbarHeight) {
        self.toolbarHeightConstraint.constant = targetToolbarHeight;
        [self.view setNeedsUpdateConstraints];
        [self.view layoutIfNeeded];
    }

    [self jsq_updateCollectionViewInsets];

    if (self.automaticallyScrollsToMostRecentMessage) {
        [self scrollToBottomAnimated:NO];
    }

    CGFloat textContentOffsetY = textView.contentSize.height - CGRectGetHeight(textView.bounds);
    if (textContentOffsetY > 0) {
        textView.contentOffset = CGPointMake(0, textContentOffsetY);
    }
}

/**
 * 清除草稿内容
 */
- (void)clearDraft
{
    if (!self.toId || self.toId.length == 0) {
        return;
    }
    
    NSString *draftKey = [self getDraftKey];
    if (draftKey) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:draftKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

@end
