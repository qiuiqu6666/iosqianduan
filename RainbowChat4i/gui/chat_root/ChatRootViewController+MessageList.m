//
//  ChatRootViewController+MessageList.m
//  消息列表加载更多、排序与窗口裁剪（仅 SQLite）。
//

#import "ChatRootViewController+MessageList.h"
#import "ChatRootViewController+ReadReceipt.h"
#import "MessagesProvider.h"
#import "Default.h"
#import "BasicTool.h"
#import "NSMutableArrayObservableEx.h"
#import "IMClientManager.h"
#import "FriendsListProvider.h"
#import "GroupEntity.h"
#import "JSQMessage.h"
#import "MsgBodyRoot.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface ChatRootViewController (RBOlderHistoryPrefetch)
- (void)rb_clearOlderHistoryExhausted;
- (void)rb_markOlderHistoryExhaustedStoppingPrefetchWithToast:(BOOL)showToast;
@end

// 主类在 .m 的 class extension 中声明的属性/方法，Category 编译时不可见，此处声明以便编译通过
@interface ChatRootViewController ()
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, assign) BOOL isRefreshing;
@property (nonatomic, assign) BOOL serverHistoryFetched;
@property (nonatomic, assign) BOOL rb_olderHistoryExhausted;
@property (nonatomic, assign) BOOL rb_pendingPreserveScrollAfterOlderSqliteLoad;
@property (nonatomic, assign) CGFloat rb_olderLoadAnchorContentHeight;
@property (nonatomic, assign) CGPoint rb_olderLoadAnchorContentOffset;
@property (nonatomic, assign) BOOL rb_pendingPrefetchOlderHistory;
@end

/// 距列表顶部（含 safe area）小于该距离即考虑预拉更早历史（不宜过大，否则 reload 后 offset 未同步时易误判）
static CGFloat RB_prefetchNearTopThreshold(CGFloat viewportHeight)
{
    if (viewportHeight < 1.0) return 330.0;
    return MAX(330.0, MIN(viewportHeight * 0.50, 600.0));
}

static NSString *RBMessageListStableKey(JSQMessage *message)
{
    if (message == nil) return @"";
    NSString *fp = [BasicTool trim:message.fingerPrintOfProtocal];
    if (fp.length > 0) return fp;
    NSString *sender = [BasicTool trim:message.senderId];
    long long time2 = message.date != nil ? (long long)([message.date timeIntervalSince1970] * 1000) : 0;
    NSString *text = [BasicTool trim:message.text];
    if (text.length > 24) {
        text = [text substringToIndex:24];
    }
    return [NSString stringWithFormat:@"fallback|%@|%d|%lld|%@", sender ?: @"", message.msgType, time2, text ?: @""];
}

@interface ChatRootViewController (MessageListPrivate)
- (void)rb_markChatCollectionItemCountSynced;
- (BOOL)isLastCellVisible;
- (BOOL)rb_isChatScrolledToBottomApproximatelyWithTolerance:(CGFloat)tolerance;
- (void)scrollToBottomAnimated:(BOOL)animated;
- (void)jsq_updateCollectionViewInsets;
@end

@implementation ChatRootViewController (MessageList)

- (UIView *)rb_olderHistoryLoadingView
{
    return objc_getAssociatedObject(self, @selector(rb_olderHistoryLoadingView));
}

- (void)setRb_olderHistoryLoadingView:(UIView *)view
{
    objc_setAssociatedObject(self, @selector(rb_olderHistoryLoadingView), view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIActivityIndicatorView *)rb_olderHistoryLoadingSpinner
{
    return objc_getAssociatedObject(self, @selector(rb_olderHistoryLoadingSpinner));
}

- (void)setRb_olderHistoryLoadingSpinner:(UIActivityIndicatorView *)spinner
{
    objc_setAssociatedObject(self, @selector(rb_olderHistoryLoadingSpinner), spinner, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIView *)rb_ensureOlderHistoryLoadingView
{
    UIView *loadingView = [self rb_olderHistoryLoadingView];
    if (loadingView != nil) {
        return loadingView;
    }

    loadingView = [[UIView alloc] init];
    loadingView.translatesAutoresizingMaskIntoConstraints = NO;
    loadingView.hidden = YES;
    loadingView.alpha = 0.0f;
    loadingView.userInteractionEnabled = NO;
    loadingView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.06f];
    loadingView.layer.cornerRadius = 16.0f;
    loadingView.clipsToBounds = YES;

    UIActivityIndicatorViewStyle style = UIActivityIndicatorViewStyleMedium;
    if (@available(iOS 13.0, *)) {
        style = UIActivityIndicatorViewStyleMedium;
    } else {
        style = UIActivityIndicatorViewStyleGray;
    }
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:style];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        spinner.color = [UIColor systemBlueColor];
    } else {
        spinner.color = HexColor(0x1677FF);
    }
    [loadingView addSubview:spinner];

    [self.view addSubview:loadingView];
    [NSLayoutConstraint activateConstraints:@[
        [loadingView.centerXAnchor constraintEqualToAnchor:self.collectionView.centerXAnchor],
        [loadingView.topAnchor constraintEqualToAnchor:self.collectionView.topAnchor constant:10.0f],
        [loadingView.widthAnchor constraintEqualToConstant:32.0f],
        [loadingView.heightAnchor constraintEqualToConstant:32.0f],

        [spinner.centerXAnchor constraintEqualToAnchor:loadingView.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:loadingView.centerYAnchor],
    ]];

    [self setRb_olderHistoryLoadingView:loadingView];
    [self setRb_olderHistoryLoadingSpinner:spinner];
    return loadingView;
}

- (UIVisualEffectView *)rb_noMoreOlderHistoryHintView
{
    return objc_getAssociatedObject(self, @selector(rb_noMoreOlderHistoryHintView));
}

- (void)setRb_noMoreOlderHistoryHintView:(UIVisualEffectView *)view
{
    objc_setAssociatedObject(self, @selector(rb_noMoreOlderHistoryHintView), view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)rb_showNoMoreOlderHistoryHint
{
    UIVisualEffectView *existingView = [self rb_noMoreOlderHistoryHintView];
    if (existingView.superview != nil) {
        return;
    }

    UIBlurEffect *blurEffect = nil;
    if (@available(iOS 13.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    UIVisualEffectView *hintView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    hintView.translatesAutoresizingMaskIntoConstraints = NO;
    hintView.alpha = 0.0f;
    hintView.userInteractionEnabled = NO;
    hintView.clipsToBounds = YES;
    hintView.layer.cornerRadius = 16.0f;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"没有更多历史消息";
    label.textColor = HexColor(0x3C4350);
    label.font = [UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium];
    [hintView.contentView addSubview:label];

    [self.view addSubview:hintView];
    [NSLayoutConstraint activateConstraints:@[
        [hintView.centerXAnchor constraintEqualToAnchor:self.collectionView.centerXAnchor],
        [hintView.topAnchor constraintEqualToAnchor:self.collectionView.topAnchor constant:10.0f],
        [hintView.heightAnchor constraintEqualToConstant:32.0f],

        [label.leadingAnchor constraintEqualToAnchor:hintView.contentView.leadingAnchor constant:14.0f],
        [label.trailingAnchor constraintEqualToAnchor:hintView.contentView.trailingAnchor constant:-14.0f],
        [label.centerYAnchor constraintEqualToAnchor:hintView.contentView.centerYAnchor],
    ]];

    [self setRb_noMoreOlderHistoryHintView:hintView];
    hintView.transform = CGAffineTransformMakeTranslation(0.0f, -8.0f);
    [self.view bringSubviewToFront:hintView];

    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }

    [UIView animateWithDuration:0.28
                          delay:0.0
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        hintView.alpha = 1.0f;
        hintView.transform = CGAffineTransformIdentity;
    } completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.85 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIVisualEffectView *strongHintView = [self rb_noMoreOlderHistoryHintView];
        if (strongHintView.superview == nil) {
            return;
        }
        [UIView animateWithDuration:0.20 animations:^{
            strongHintView.alpha = 0.0f;
            strongHintView.transform = CGAffineTransformMakeTranslation(0.0f, -6.0f);
        } completion:^(__unused BOOL finished) {
            [strongHintView removeFromSuperview];
            [self setRb_noMoreOlderHistoryHintView:nil];
        }];
    });
}

- (void)rb_setOlderHistoryLoadingVisible:(BOOL)visible
{
    self.refreshControl.tintColor = [UIColor clearColor];
    self.refreshControl.attributedTitle = nil;
    UIView *loadingView = [self rb_ensureOlderHistoryLoadingView];
    UIActivityIndicatorView *spinner = [self rb_olderHistoryLoadingSpinner];
    if (visible) {
        if (self.refreshControl.refreshing) {
            [loadingView.layer removeAllAnimations];
            loadingView.alpha = 0.0f;
            loadingView.hidden = YES;
            [spinner stopAnimating];
            return;
        }
        [spinner startAnimating];
        loadingView.hidden = NO;
        [self.view bringSubviewToFront:loadingView];
        [UIView animateWithDuration:0.15 animations:^{
            loadingView.alpha = 1.0f;
        }];
    } else {
        [UIView animateWithDuration:0.15 animations:^{
            loadingView.alpha = 0.0f;
        } completion:^(__unused BOOL finished) {
            [spinner stopAnimating];
            loadingView.hidden = YES;
        }];
    }
}

- (void)sortSomeoneMessagesByDateAscending:(NSMutableArrayObservableEx *)someoneMessages
{
    if (!someoneMessages || [[someoneMessages getDataList] count] == 0) return;
    NSArray *sorted = [[someoneMessages getDataList] sortedArrayUsingComparator:^NSComparisonResult(JSQMessage *m1, JSQMessage *m2) {
        return [m1.date compare:m2.date];
    }];
    [someoneMessages putDataList:sorted needNotify:NO];
}

- (BOOL)rb_pendingPrefetchOlderHistory
{
    NSNumber *n = objc_getAssociatedObject(self, @selector(rb_pendingPrefetchOlderHistory));
    return n.boolValue;
}

- (void)setRb_pendingPrefetchOlderHistory:(BOOL)v
{
    objc_setAssociatedObject(self, @selector(rb_pendingPrefetchOlderHistory), @(v), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)rb_olderLoadAnchorFirstMessageKey
{
    return objc_getAssociatedObject(self, @selector(rb_olderLoadAnchorFirstMessageKey));
}

- (void)setRb_olderLoadAnchorFirstMessageKey:(NSString *)value
{
    objc_setAssociatedObject(self, @selector(rb_olderLoadAnchorFirstMessageKey), value, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)rb_trimChattingMemoryWindowIfNeededKeepingOlderMessages:(BOOL)keepingOlderMessages
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self rb_trimChattingMemoryWindowIfNeededKeepingOlderMessages:keepingOlderMessages];
        });
        return;
    }
    if (self.toId.length == 0) {
        return;
    }
    id provider = [MessagesProvider getMessageProiderInstance:self.chatType];
    if (provider == nil) {
        return;
    }
    NSMutableArrayObservableEx *list = [provider getMessages:self.toId];
    if (list == nil) {
        return;
    }
    NSUInteger n = [list getDataList].count;
    if (n <= CHATTING_MESSAGE_WINDOW_MAX) {
        return;
    }
    [provider trimMessageWindowToMaxCount:CHATTING_MESSAGE_WINDOW_MAX forUid:self.toId trimNewestFirst:keepingOlderMessages];
}

- (void)rb_sortAndTrimMessageList
{
    [self rb_sortAndTrimMessageListPreferKeepingOlder:NO];
}

- (void)rb_sortAndTrimMessageListPreferKeepingOlder:(BOOL)preferKeepingOlder
{
    (void)preferKeepingOlder;
    id provider = [MessagesProvider getMessageProiderInstance:self.chatType];
    NSMutableArrayObservableEx *list = [provider getMessages:self.toId];
    if (list != nil) {
        [self sortSomeoneMessagesByDateAscending:list];
    }
}

- (void)onLoadMoreHistory
{
    if (self.rb_olderHistoryExhausted) {
        [self rb_setOlderHistoryLoadingVisible:NO];
        [self.refreshControl endRefreshing];
        return;
    }
    if (self.isRefreshing) {
        return;
    }
    self.isRefreshing = YES;
    [self rb_setOlderHistoryLoadingVisible:YES];
    self.rb_pendingPreserveScrollAfterOlderSqliteLoad = YES;
    self.rb_olderLoadAnchorContentHeight = self.collectionView.contentSize.height;
    self.rb_olderLoadAnchorContentOffset = self.collectionView.contentOffset;
    self.rb_olderLoadAnchorFirstMessageKey = RBMessageListStableKey([[self getChattingDatasList] firstObject]);

    __weak typeof(self) safeSelf = self;
    void (^finishLoadCycle)(BOOL sqliteMergedNewRows) = ^(BOOL sqliteMergedNewRows) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(safeSelf) strongSelf = safeSelf;
            if (!strongSelf) {
                return;
            }
            if (sqliteMergedNewRows) {
                [strongSelf rb_clearOlderHistoryExhausted];
            } else {
                [strongSelf rb_markOlderHistoryExhaustedStoppingPrefetchWithToast:YES];
            }
            [strongSelf completeLoadMoreHistorySafe];
            strongSelf.isRefreshing = NO;
        });
    };

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @try {
            [[MessagesProvider getMessageProiderInstance:safeSelf.chatType] loadMoreMessages:safeSelf.toId afterAndFingerPrint:nil limit:YES complete:^(BOOL sucess) {
                if (sucess) {
                    finishLoadCycle(YES);
                } else {
                    finishLoadCycle(NO);
                }
            }];
        } @catch (NSException *exception) {
            NSLog(@"%@", exception);
            finishLoadCycle(NO);
        }
    });
}

- (void)completeLoadMoreHistorySafe
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self completeLoadMoreHistory];
        });
    } else {
        [self completeLoadMoreHistory];
    }
}

- (void)completeLoadMoreHistory
{
    [self rb_setOlderHistoryLoadingVisible:NO];
    [self.refreshControl endRefreshing];
    [self rb_sortAndTrimMessageListPreferKeepingOlder:NO];
    BOOL preserveOlderScroll = self.rb_pendingPreserveScrollAfterOlderSqliteLoad;
    UICollectionView *cv = self.collectionView;
    CGFloat anchorH = self.rb_olderLoadAnchorContentHeight;
    CGPoint anchorOff = self.rb_olderLoadAnchorContentOffset;
    self.rb_pendingPreserveScrollAfterOlderSqliteLoad = NO;
    self.rb_olderLoadAnchorFirstMessageKey = nil;

    CGFloat beforeReloadH = (cv != nil) ? cv.contentSize.height : 0;
    CGPoint beforeReloadOff = (cv != nil) ? cv.contentOffset : CGPointZero;
    NSInteger beforeItemCount = (cv != nil) ? (NSInteger)[cv numberOfItemsInSection:0] : 0;
    NSArray<JSQMessage *> *messagesAfterMerge = [self getChattingDatasList];
    NSInteger afterItemCount = (NSInteger)messagesAfterMerge.count;

    [self rb_restorePartnerReadWatermarkAndApplyToCurrentListIfNeeded];
    NSInteger prependedCount = afterItemCount - beforeItemCount;
    // 历史分页 prepend 曾尝试走 insertItems 增量插入，但 JSQ 动态高度 cell（顶部时间/引用/底部时间状态）
    // 在 indexPath 整体后移时偶发出现旧高度参与本轮布局，表现为「突然闪一下」并伴随 Auto Layout 约束冲突。
    // 这里优先稳定性：统一走 reloadData + contentOffset 补偿，牺牲一点增量动画，换取不闪和不炸约束。
    BOOL canIncrementalPrepend = NO;

    [self rb_invalidateChattingListLayoutCache];
    if (canIncrementalPrepend) {
        NSMutableArray<NSIndexPath *> *insertedPaths = [NSMutableArray arrayWithCapacity:(NSUInteger)prependedCount];
        for (NSInteger i = 0; i < prependedCount; i++) {
            [insertedPaths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        }
        [UIView performWithoutAnimation:^{
            [cv performBatchUpdates:^{
                [cv insertItemsAtIndexPaths:insertedPaths];
            } completion:^(BOOL finished) {
                [cv layoutIfNeeded];
                CGFloat delta = cv.contentSize.height - beforeReloadH;
                if (fabs(delta) > 0.5) {
                    cv.contentOffset = CGPointMake(anchorOff.x, anchorOff.y + delta);
                }
                [self rb_markChatCollectionItemCountSynced];
            }];
        }];
        return;
    }

    [UIView performWithoutAnimation:^{
        [cv reloadData];
        [cv layoutIfNeeded];
    }];

    if (preserveOlderScroll && cv != nil && anchorH > 0.5) {
        CGFloat newH = cv.contentSize.height;
        CGFloat delta = newH - anchorH;
        if (fabs(delta) > 0.5) {
            cv.contentOffset = CGPointMake(anchorOff.x, anchorOff.y + delta);
        }
    } else if (!preserveOlderScroll && cv != nil && beforeReloadH > 0.5) {
        CGFloat delta = cv.contentSize.height - beforeReloadH;
        if (fabs(delta) > 0.5) {
            cv.contentOffset = CGPointMake(beforeReloadOff.x, beforeReloadOff.y + delta);
        }
    }

    [self rb_markChatCollectionItemCountSynced];
}

- (void)rb_handleOlderHistoryPullReleaseForScrollView:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) {
        return;
    }
    if (self.isRefreshing) {
        return;
    }

    CGFloat insetTop;
    if (@available(iOS 11.0, *)) {
        insetTop = scrollView.adjustedContentInset.top;
    } else {
        insetTop = scrollView.contentInset.top;
    }
    CGFloat pullDistance = -(scrollView.contentOffset.y + insetTop);
    if (pullDistance < 24.0f) {
        return;
    }

    if (self.rb_olderHistoryExhausted) {
        [self rb_showNoMoreOlderHistoryHint];
        return;
    }

    [self onLoadMoreHistory];
}

/// 手指向上滑查看更早消息时，接近列表顶部自动加载一页历史
- (void)rb_tryPrefetchOlderHistoryForScrollView:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) return;
    if (self.rb_olderHistoryExhausted) return;
    if (self.isRefreshing) return;
    if (!scrollView.isDragging && !scrollView.isDecelerating) return;

    NSInteger memN = (NSInteger)[self getChattingDatasList].count;
    if (memN >= 180 && [scrollView isKindOfClass:[UICollectionView class]]) {
        UICollectionView *cv = (UICollectionView *)scrollView;
        NSArray<NSIndexPath *> *ips = [cv indexPathsForVisibleItems];
        NSInteger minRow = NSIntegerMax;
        for (NSIndexPath *ip in ips) {
            if (ip.section != 0) continue;
            if (ip.item < minRow) minRow = ip.item;
        }
        if (minRow != NSIntegerMax && minRow < (NSInteger)CHATTING_MESSAGE_PREFETCH_OLDEST_VISIBLE_INDEX_MAX) {
            self.rb_pendingPrefetchOlderHistory = YES;
            return;
        }
    }

    [scrollView layoutIfNeeded];

    CGFloat viewportH = CGRectGetHeight(scrollView.bounds);
    if (viewportH < 1.0) return;

    CGFloat insetTop;
    if (@available(iOS 11.0, *)) {
        insetTop = scrollView.adjustedContentInset.top;
    } else {
        insetTop = scrollView.contentInset.top;
    }

    CGFloat distFromTop = scrollView.contentOffset.y + insetTop;
    CGFloat th = RB_prefetchNearTopThreshold(viewportH);
    if (distFromTop > th) return;

    self.rb_pendingPrefetchOlderHistory = YES;
}

- (void)rb_consumePendingPrefetchOlderHistoryIfNeeded
{
    if (!self.rb_pendingPrefetchOlderHistory) {
        return;
    }
    if (self.rb_olderHistoryExhausted) {
        self.rb_pendingPrefetchOlderHistory = NO;
        return;
    }
    if (self.isRefreshing) {
        return;
    }
    UIScrollView *scrollView = self.collectionView;
    if (scrollView == nil) {
        self.rb_pendingPrefetchOlderHistory = NO;
        return;
    }

    [scrollView layoutIfNeeded];
    CGFloat viewportH = CGRectGetHeight(scrollView.bounds);
    if (viewportH < 1.0) {
        self.rb_pendingPrefetchOlderHistory = NO;
        return;
    }

    CGFloat insetTop;
    if (@available(iOS 11.0, *)) {
        insetTop = scrollView.adjustedContentInset.top;
    } else {
        insetTop = scrollView.contentInset.top;
    }
    CGFloat distFromTop = scrollView.contentOffset.y + insetTop;
    CGFloat th = RB_prefetchNearTopThreshold(viewportH);

    BOOL nearTop = (distFromTop <= th);
    NSInteger memN = (NSInteger)[self getChattingDatasList].count;
    if (!nearTop && memN >= 180 && [scrollView isKindOfClass:[UICollectionView class]]) {
        UICollectionView *cv = (UICollectionView *)scrollView;
        NSArray<NSIndexPath *> *ips = [cv indexPathsForVisibleItems];
        NSInteger minRow = NSIntegerMax;
        for (NSIndexPath *ip in ips) {
            if (ip.section != 0) continue;
            if (ip.item < minRow) minRow = ip.item;
        }
        if (minRow != NSIntegerMax && minRow < (NSInteger)CHATTING_MESSAGE_PREFETCH_OLDEST_VISIBLE_INDEX_MAX) {
            nearTop = YES;
        }
    }

    if (!nearTop) {
        self.rb_pendingPrefetchOlderHistory = NO;
        return;
    }

    self.rb_pendingPrefetchOlderHistory = NO;
    [self onLoadMoreHistory];
}

- (void)sortCurrentSessionMessagesIfNeeded
{
    if (!self.toId) return;
    id msgProvider = (self.chatType == CHAT_TYPE_GROUP_CHAT)
        ? [[IMClientManager sharedInstance] getGroupsMessagesProvider]
        : [[IMClientManager sharedInstance] getMessagesProvider];
    if (!msgProvider) return;
    NSMutableArrayObservableEx *someoneMessages = [msgProvider getMessages:self.toId];
    if (someoneMessages == nil || [[someoneMessages getDataList] count] <= 1) return;
    NSArray<JSQMessage *> *current = [someoneMessages getDataList];
    BOOL alreadySorted = YES;
    for (NSUInteger i = 1; i < current.count; i++) {
        JSQMessage *prev = current[i - 1];
        JSQMessage *next = current[i];
        if ([prev.date compare:next.date] == NSOrderedDescending) {
            alreadySorted = NO;
            break;
        }
    }
    if (alreadySorted) return;
    [self sortSomeoneMessagesByDateAscending:someoneMessages];
    [self rb_invalidateChattingListLayoutCache];
    [self.collectionView reloadData];
}

- (void)rb_applyDeferredOlderHistoryIfNeeded
{
    // 漫游禁用，直接完成
}

- (void)roamingRestoreCollectionViewAlpha
{
    // 漫游已禁用，此方法不再执行任何操作
}

- (void)rb_maybeTrimOldestMemoryWhenViewingLatestAfterScrollEnd:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) {
        return;
    }
    if (![NSThread isMainThread]) {
        __weak typeof(self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [wself rb_maybeTrimOldestMemoryWhenViewingLatestAfterScrollEnd:scrollView];
        });
        return;
    }
    if (self.toId.length == 0 || self.collectionView == nil) {
        return;
    }
    NSInteger n = (NSInteger)[self getChattingDatasList].count;
    if (n <= (NSInteger)CHATTING_MESSAGE_WINDOW_MAX) {
        return;
    }
    CGFloat bottomTol = (self.chatType == CHAT_TYPE_GROUP_CHAT) ? 72.0 : 22.0;
    BOOL viewingLatest = [self rb_isChatScrolledToBottomApproximatelyWithTolerance:bottomTol];
    if (!viewingLatest) {
        viewingLatest = [self isLastCellVisible];
    }
    if (!viewingLatest) {
        return;
    }
    NSUInteger before = (NSUInteger)n;
    [self rb_trimChattingMemoryWindowIfNeededKeepingOlderMessages:NO];
    NSUInteger after = (NSUInteger)[self getChattingDatasList].count;
    if (after < before) {
        [self rb_invalidateChattingListLayoutCache];
        [self.collectionView reloadData];
        [self.collectionView layoutIfNeeded];
        [self jsq_updateCollectionViewInsets];
        [self scrollToBottomAnimated:NO];
        [self rb_markChatCollectionItemCountSynced];
    }
}

@end
