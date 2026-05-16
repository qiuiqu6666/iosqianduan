//
//  ChatRootViewController+GroupChat.m
//  群聊（展示分组已关闭）、@ 功能、@我 悬浮提示、回到底部按钮。
//

#import "ChatRootViewController+GroupChat.h"
#import "ChatRootViewController+MessageList.h"
#import "JSQMessage.h"
#import "JSQMessages.h"
#import "JSQMessagesCollectionView.h"
#import "JSQMessagesCollectionViewFlowLayout.h"
#import "BasicTool.h"
#import "ClientCoreSDK.h"
#import "Default.h"
#import "NotificationCenterFactory.h"
#import "HttpRestHelper.h"
#import "GroupsProvider.h"
#import "GroupsMessagesProvider.h"
#import "GroupEntity.h"
#import "IMClientManager.h"
#import "QoS4ReciveDaemon.h"
#import "GroupsMessagesProvider.h"
#import <UIKit/UIKit.h>

@class TargetEntity;

@interface ChatRootViewController ()
@property (nonatomic, assign) CFTimeInterval rb_atMeHintScrollThrottleLastTs;
@end

@interface ChatRootViewController (GroupChatPrivate)
@property (nonatomic, strong) UIButton *scrollToBottomButton;
@property (nonatomic, strong) UILabel *scrollToBottomBadgeLabel;
@property (nonatomic, strong) NSLayoutConstraint *scrollToBottomBadgeWidthConstraint;
- (void)rb_updateScrollToBottomButtonUnreadBadge;
@property (nonatomic, assign) BOOL isUserDragging;
@property (nonatomic, assign) BOOL pendingFocusAfterAtChoose;
@property (nonatomic, strong) TargetEntity *pendingAtUserForKeyboard;
@property (nonatomic, strong) NSMutableString *pendingAtUserPrefixForKeyboard;
@property (nonatomic, strong) id atUserInsertKeyboardObserverToken;
- (NSMutableArray<JSQMessage *> *)getChattingDatasList;
- (void)scrollToBottomAnimated:(BOOL)animated;
/// 点击「回到底部」专用：先强制布局再滚底，并在下一 runloop 二次校正（避免 contentSize 未刷新导致末条露出不全）
- (void)rb_scrollChatToBottomAfterEnsuringLayoutAnimated:(BOOL)animated;
- (nullable JSQMessage *)parseHistoryMsgFromDict:(NSDictionary *)dict localUid:(NSString *)localUid;
@end

@implementation ChatRootViewController (GroupChat)

static inline NSString *RBAtMeTrackTrimmedString(NSString *value)
{
    return [BasicTool trim:value];
}

static NSString *RBAtMeTrackingKeyForMessage(JSQMessage *message)
{
    if (message == nil) return @"";
    NSString *fp = RBAtMeTrackTrimmedString(message.fingerPrintOfProtocal);
    if (fp.length > 0) return fp;
    NSString *parentFp = RBAtMeTrackTrimmedString(message.fingerPrintOfParent);
    if (parentFp.length > 0) return parentFp;
    NSString *sender = RBAtMeTrackTrimmedString(message.senderId);
    long long time2 = message.date != nil ? (long long)([message.date timeIntervalSince1970] * 1000) : 0;
    NSString *text = RBAtMeTrackTrimmedString(message.text);
    if (text.length > 24) {
        text = [text substringToIndex:24];
    }
    return [NSString stringWithFormat:@"fallback|%@|%d|%lld|%@", sender ?: @"", message.msgType, time2, text ?: @""];
}

- (NSInteger)rb_indexOfAtMeTrackedMessageKey:(NSString *)messageKey inMessages:(NSArray<JSQMessage *> *)messages
{
    if (messageKey.length == 0 || messages.count == 0) return NSNotFound;
    for (NSInteger i = 0; i < messages.count; i++) {
        if ([RBAtMeTrackingKeyForMessage(messages[i]) isEqualToString:messageKey]) {
            return i;
        }
    }
    return NSNotFound;
}

//---------------------------------------------------------------------------------------------------
#pragma mark - 群聊消息分组（已关闭）

/// 原逻辑：同发送者、5 分钟内、同类型等合并为一条「展示链」，昵称仅首条显示等。
/// 现改为每条独立（position 恒为 0、groupStart 恒为自身 index），布局与单聊一致，不再做链式合并。
- (NSInteger)rb_messageGroupPositionForItemAtIndex:(NSInteger)index {
    (void)index;
    return 0;
}

- (NSInteger)rb_groupStartIndexForItemAtIndex:(NSInteger)index {
    return index;
}

- (NSInteger)collectionView:(JSQMessagesCollectionView *)collectionView
                     layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout messageGroupPositionAtIndexPath:(NSIndexPath *)indexPath {
    (void)collectionView;
    (void)collectionViewLayout;
    (void)indexPath;
    return 0;
}

//---------------------------------------------------------------------------------------------------
#pragma mark - 大群读扩散（MT45 仅推 pull + seq，须 HTTP 拉取后写入聊天列表）

/// 将 1016-25-25 单行字段对齐到 parseHistoryMsgFromDict 所需键（实现迁至 GroupsProvider 供登录同步共用）
- (NSDictionary *)rb_normalizedDictFromLargeGroupFetchRow:(NSDictionary *)raw gid:(NSString *)gid
{
    return [GroupsProvider rb_normalizedDictFromLargeGroupFetchRow:raw gid:gid];
}

/// 从大群接口增量拉取并 putMessage（递归直至 has_more=false）
- (void)rb_pullLargeGroupMessagesFromSeq:(long long)fromSeq gid:(NSString *)gid
{
    if (gid.length == 0) return;
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitFetchLargeGroupMessagesFromServer:gid
                                                                    fromSeq:fromSeq
                                                                      limit:200
                                                                  direction:nil
                                                                   complete:^(BOOL success, NSArray<NSDictionary *> *messages, BOOL hasMore) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) s = wself;
            if (!s) return;
            if (!success || !messages || messages.count == 0) {
                return;
            }
            NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid ?: @"";
            NSArray *sorted = [messages sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                long long sa = [a[@"seq"] longLongValue];
                long long sb = [b[@"seq"] longLongValue];
                if (sa < sb) return NSOrderedAscending;
                if (sa > sb) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            long long maxSeq = fromSeq;
            GroupsMessagesProvider *gmp = [[IMClientManager sharedInstance] getGroupsMessagesProvider];
            for (NSDictionary *raw in sorted) {
                long long seq = [raw[@"seq"] longLongValue];
                if (seq > maxSeq) maxSeq = seq;

                NSDictionary *norm = [GroupsProvider rb_normalizedDictFromLargeGroupFetchRow:raw gid:gid];
                JSQMessage *msg = [GroupsProvider rb_jsqMessageFromLargeGroupNormalizedDict:norm localUid:localUid];
                if (!msg) continue;

                NSString *fp = msg.fingerPrintOfProtocal ?: @"";
                if (fp.length > 0 && [[QoS4ReciveDaemon sharedInstance] hasRecieved:fp]) {
                    if ([gmp findMessageByFingerPrint:gid fp:fp]) {
                        continue;
                    }
                }

                [gmp putMessage:gid withData:msg];

                if (fp.length > 0) {
                    [[QoS4ReciveDaemon sharedInstance] addRecievedWithFingerPrint:fp];
                }
            }
            if (maxSeq > fromSeq) {
                [GroupsProvider saveLastSeq:maxSeq forGroup:gid];
            }
            if (hasMore && maxSeq > fromSeq) {
                [s rb_pullLargeGroupMessagesFromSeq:maxSeq gid:gid];
            }
        });
    } hudParentView:nil];
}

/// MT45 大群轻量通知：`NotificationCenterFactory` 的 object 为 @{ gid, seq }
- (void)rb_onLargeGroupPullNotify:(NSNotification *)note
{
    if (self.chatType != CHAT_TYPE_GROUP_CHAT) return;
    if (![note.object isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *payload = (NSDictionary *)note.object;
    NSString *gid = payload[@"gid"];
    if (![gid isKindOfClass:[NSString class]] || gid.length == 0 || ![gid isEqualToString:self.toId]) return;
    if ([GroupEntity isWorldChat:gid]) return;

    GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];
    if (ge == nil || ![ge isLargeGroup]) return;

    long long fromSeq = [GroupsProvider getLastSeqForGroup:gid];
    [self rb_pullLargeGroupMessagesFromSeq:fromSeq gid:gid];
}

//---------------------------------------------------------------------------------------------------
#pragma mark - ”@“ 功能相关方法

// @Override - 重写了父类中的方法，用于补充 “@” 功能相关的逻辑！
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    DDLogDebug(@"【JSQ-RB-ROOT】走到shouldChangeTextInRange这里了吗？replacementText：text=%@", text);
    
    UITextView *composer = [self rb_currentComposerTextView];
    if (textView != composer) {
        return YES;
    }

    // 触发消息发送功能
    if ([text isEqualToString:@"\n"]){
        DDLogDebug(@"【JSQ-RB-ROOT】点击了软键盘上的\"Send\"按钮！");
        
        NSString *composedText = [super jsq_currentlyComposedMessageText];
        NSString *trimmedText = [composedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        // 输入框为空时：不发送，直接收起键盘
        if (trimmedText.length == 0) {
            [composer resignFirstResponder];
            return NO;
        }
        
        // 有内容时：正常发送
        [self didPressSendButtonInKeybord:composedText];
        return NO;
    } else {
        // 只有群聊中需要处理"@"功能相关的逻辑
        if(self.chatType == CHAT_TYPE_GROUP_CHAT && ![GroupEntity isWorldChat:self.toId]) {
            // 触发"@"功能
            if ([text isEqualToString:NIMInputAtStartChar]) {
                DDLogDebug(@"【JSQ-RB-ROOT-"@"功能】触发了文本输入框中的@功能！");
                
                // 显示被 @ 者的选择界面
                [self.atCache showAtUserActivity:NO nav:self.navigationController delegate:self];
            }
            // 当文本被删除时，replacementText是空字符串
            else if([text isEqualToString:@""] && range.length == 1 ) {
                DDLogDebug(@"【JSQ-RB-ROOT-"@"功能】触发了文本输入框中的删除文字功能！！！！！！！");
                
                // 尝试看看删的是否是 “@ 某人“
                AtBlock *item = [self.atCache delRangeForAt:composer];
                if (item != nil) {
                    range = item.range;
                    if ([composer isKindOfClass:[JSQMessagesComposerTextView class]]) {
                        [(JSQMessagesComposerTextView *)composer deleteTextStr:range];
                    } else {
                        NSString *txt = composer.text ?: @"";
                        if (range.location != NSNotFound && range.length > 0
                            && NSMaxRange(range) <= txt.length) {
                            composer.text = [txt stringByReplacingCharactersInRange:range withString:@""];
                            composer.selectedRange = NSMakeRange(range.location, 0);
                        }
                        id<UITextViewDelegate> del = composer.delegate;
                        if ([del respondsToSelector:@selector(textViewDidChange:)]) {
                            [del textViewDidChange:composer];
                        }
                    }
                    return NO;//YES;
                }
            }
        } else {
            DDLogDebug(@"【JSQ-RB-ROOT-"@"功能】只有群聊支持@功能，本次@字符被忽略！");
        }
    }

    return YES;
}

/**
 * 好友选择结果代理方法：可以在此方法中处理从用户选择列表中选择的用户进行进一步处理。
 *
 * @param te 选中的目标
 *
 * 为何系统输入法正常、搜狗等第三方输入法只显示 @ 不显示昵称？
 * - 系统键盘与 UITextView 同属系统，程序里直接改 text 即可，键盘不会覆盖。
 * - 搜狗等第三方输入法有独立缓冲区：用户输入的 @"@" 在去选人前可能还在缓冲区里。
 *   返回后我们先插入 @"@昵称"，输入法随后把自己的缓冲区（只有 @"@"）写回文本框，把昵称覆盖掉。
 * 处理方式：在 flushPendingAtUserInsertIfNeeded 里先 resignFirstResponder（键盘收起、输入法脱离），
 * 再在下一 runloop 插入文本，再 becomeFirstResponder，这样插入时没有输入法在写回，就不会被覆盖。
 */
- (void)processAtChooseCompleteImpl:(TargetEntity *)ue needInsertAitInText:(BOOL) needInsertAitInText
{
    NSMutableString *str = [[NSMutableString alloc] initWithString:needInsertAitInText ? @"@" : @""];//@""
    
    // 仅当页面已处于最前可见时立刻拉起键盘；否则延迟到 viewDidAppear 再处理，避免输入框与键盘错位
    BOOL isTopVisible = (self.isViewLoaded && self.view.window != nil && self.navigationController.topViewController == self);
    // 两种分支都只设「待插入」，由 flushPendingAtUserInsertIfNeeded 统一做 resign → 插入 → Toast，且不自动弹键盘，避免搜狗覆盖
    self.pendingAtUserForKeyboard = ue;
    self.pendingAtUserPrefixForKeyboard = str;
    if (isTopVisible) {
        UITextView *composer = [self rb_currentComposerTextView];
        composer.inputView = nil;
        if (![composer isFirstResponder]) {
            [composer becomeFirstResponder];
        } else {
            [composer reloadInputViews];
        }
        [self addAtUserInsertKeyboardObserverIfNeeded];
        __weak typeof(self) wself = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [wself flushPendingAtUserInsertIfNeeded];
        });
    } else {
        self.pendingFocusAfterAtChoose = YES;
    }
}

/// 在键盘已显示后再插入 @用户，避免搜狗等覆盖；收到 UIKeyboardDidShow 后延迟 0.15s 插入
- (void)addAtUserInsertKeyboardObserverIfNeeded
{
    if (self.atUserInsertKeyboardObserverToken != nil) return;
    __weak typeof(self) wself = self;
    self.atUserInsertKeyboardObserverToken = [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardDidShowNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        __strong typeof(wself) sself = wself;
        if (!sself || !sself.pendingAtUserForKeyboard) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [sself flushPendingAtUserInsertIfNeeded];
        });
    }];
}

/// 执行待插入的 @用户 并清理观察者与 pending 状态
/// 搜狗等第三方输入法会维护自己的缓冲区，在成为第一响应者后会把缓冲区内容写回文本框，覆盖我们插入的昵称。
/// 因此采用：先 resignFirstResponder（键盘收起、输入法脱离）→ 再插入文本。
/// 插入后不再自动 becomeFirstResponder，避免搜狗重新挂载时写回覆盖；提示用户点击输入框继续输入。
- (void)flushPendingAtUserInsertIfNeeded
{
    if (!self.pendingAtUserForKeyboard || !self.pendingAtUserPrefixForKeyboard) return;
    TargetEntity *ue = self.pendingAtUserForKeyboard;
    NSMutableString *str = self.pendingAtUserPrefixForKeyboard;
    self.pendingAtUserForKeyboard = nil;
    self.pendingAtUserPrefixForKeyboard = nil;
    if (self.atUserInsertKeyboardObserverToken != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.atUserInsertKeyboardObserverToken];
        self.atUserInsertKeyboardObserverToken = nil;
    }
    
    UITextView *textView = [self rb_currentComposerTextView];
    NSInteger lenBefore = textView.text.length;
    NSRange selBefore = textView.selectedRange;
    DDLogDebug(@"【@插入-搜狗】flushPending: resign 前 text.length=%ld selectedRange=(%lu,%lu)", (long)lenBefore, (unsigned long)selBefore.location, (unsigned long)selBefore.length);
    [textView resignFirstResponder];
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        UITextView *composer = [sself rb_currentComposerTextView];
        [sself.atCache addAtUser:ue prefix:str target:composer];
        NSInteger lenAfter = composer.text.length;
        NSString *preview = composer.text;
        if (preview.length > 50) preview = [[preview substringToIndex:50] stringByAppendingString:@"…"];
        DDLogDebug(@"【@插入-搜狗】flushPending: addAtUser 后 text.length=%ld preview=%@", (long)lenAfter, preview);
    });
}

/// 取消待插入的 @用户（如页面消失时），只清理状态与观察者，不插入
- (void)cancelPendingAtUserInsert
{
    self.pendingAtUserForKeyboard = nil;
    self.pendingAtUserPrefixForKeyboard = nil;
    if (self.atUserInsertKeyboardObserverToken != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.atUserInsertKeyboardObserverToken];
        self.atUserInsertKeyboardObserverToken = nil;
    }
}


//---------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------
#pragma mark - UIScrollViewDelegate（由主控制器统一转发到这里）

- (void)rb_groupChat_scrollViewDidScroll:(UIScrollView *)scrollView
{
    // refreshAtMeHintVisibility 内有循环与 UI；scrollViewDidScroll 极高频（60Hz），节流降低 CPU
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    static const CFAbsoluteTime kAtMeScrollThrottleSec = 0.12;
    if (now - self.rb_atMeHintScrollThrottleLastTs >= kAtMeScrollThrottleSec) {
        self.rb_atMeHintScrollThrottleLastTs = now;
        [self checkAtMeVisibilityOnScroll];
    }

    [self updateScrollToBottomButtonVisibility];
}

- (void)rb_groupChat_scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.isUserDragging = YES;
}

- (void)rb_groupChat_scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        self.isUserDragging = NO;
        [self rb_maybeTrimOldestMemoryWhenViewingLatestAfterScrollEnd:scrollView];
        [self rb_refreshVisibleBubbleTimeLayouts];
    }
}

- (void)rb_groupChat_scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    self.isUserDragging = NO;
    [self rb_maybeTrimOldestMemoryWhenViewingLatestAfterScrollEnd:scrollView];
    [self rb_refreshVisibleBubbleTimeLayouts];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - "有人@我"悬浮提示功能

/**
 * 初始化"有人@我"悬浮提示UI
 */
- (void)initAtMeHintUI
{
    // 初始化待处理的@我消息稳定标识数组
    self.pendingAtMeIndexes = [NSMutableArray array];
    
    // 创建"有人@我"悬浮提示按钮
    self.btnAtMeHint = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnAtMeHint.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnAtMeHint.hidden = YES;
    
    // 设置按钮样式：绿色胶囊型按钮
    self.btnAtMeHint.backgroundColor = HexColor(0x00DE7A); // 绿色背景，与现有的未读气泡一致
    self.btnAtMeHint.layer.cornerRadius = 18;
    self.btnAtMeHint.layer.masksToBounds = NO; // 不裁剪，让阴影可见
    self.btnAtMeHint.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    // 添加阴影使按钮更明显
    self.btnAtMeHint.layer.shadowColor = [UIColor blackColor].CGColor;
    self.btnAtMeHint.layer.shadowOffset = CGSizeMake(0, 2);
    self.btnAtMeHint.layer.shadowOpacity = 0.25;
    self.btnAtMeHint.layer.shadowRadius = 4;
    
    // 设置按钮文字样式
    [self.btnAtMeHint setTitle:@"有人@我" forState:UIControlStateNormal];
    [self.btnAtMeHint setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnAtMeHint.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    
    // 设置"@"图标
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold];
        UIImage *atImg = [[UIImage systemImageNamed:@"at" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self.btnAtMeHint setImage:atImg forState:UIControlStateNormal];
        self.btnAtMeHint.tintColor = [UIColor whiteColor];
        self.btnAtMeHint.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
    }
    
    // 添加点击事件
    [self.btnAtMeHint addTarget:self action:@selector(fireOnClickAtMeHint:) forControlEvents:UIControlEventTouchUpInside];
    
    // 添加到主视图（确保在最前面）
    [self.view addSubview:self.btnAtMeHint];
    [self.view bringSubviewToFront:self.btnAtMeHint];
    
    // 设置约束：右侧对齐，位于未读消息提示上方（参考"X条新消息"气泡的位置）
    [NSLayoutConstraint activateConstraints:@[
        [self.btnAtMeHint.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [self.btnAtMeHint.bottomAnchor constraintEqualToAnchor:self.inputToolbar.topAnchor constant:-70],
        [self.btnAtMeHint.heightAnchor constraintEqualToConstant:36],
    ]];
}

#pragma mark - "回到底部"浮动按钮

/**
 * 初始化"回到底部"浮动按钮
 * 用户上滑查看历史消息时显示，点击一键滚动到最新消息
 */
- (void)initScrollToBottomButton
{
    self.scrollToBottomButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.scrollToBottomButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollToBottomButton.clipsToBounds = NO;
    self.scrollToBottomButton.hidden = YES; // 默认隐藏，滚动超过阈值后显示
    self.scrollToBottomButton.alpha = 0;
    
    // 按钮样式：圆形 + 半透明背景 + 向下箭头
    self.scrollToBottomButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    self.scrollToBottomButton.layer.cornerRadius = 20;
    self.scrollToBottomButton.layer.masksToBounds = NO;
    
    // 阴影
    self.scrollToBottomButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.scrollToBottomButton.layer.shadowOffset = CGSizeMake(0, 2);
    self.scrollToBottomButton.layer.shadowOpacity = 0.3;
    self.scrollToBottomButton.layer.shadowRadius = 4;
    
    // 设置向下箭头图标
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
        UIImage *arrowImg = [[UIImage systemImageNamed:@"chevron.down" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self.scrollToBottomButton setImage:arrowImg forState:UIControlStateNormal];
        self.scrollToBottomButton.tintColor = [UIColor whiteColor];
    } else {
        [self.scrollToBottomButton setTitle:@"↓" forState:UIControlStateNormal];
        [self.scrollToBottomButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.scrollToBottomButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    }
    
    // 点击事件
    [self.scrollToBottomButton addTarget:self action:@selector(onScrollToBottomButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 未读条数角标（与「X条新消息」气泡同源：setUnreadCount / getUnreadCount）
    UILabel *badge = [[UILabel alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.hidden = YES;
    badge.textAlignment = NSTextAlignmentCenter;
    badge.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightBold];
    badge.textColor = [UIColor whiteColor];
    badge.backgroundColor = [UIColor colorWithRed:0.95 green:0.25 blue:0.22 alpha:1];
    badge.layer.cornerRadius = 9;
    badge.layer.masksToBounds = YES;
    badge.layer.borderWidth = 1.5;
    badge.layer.borderColor = [UIColor colorWithWhite:0.95 alpha:1].CGColor;
    [self.scrollToBottomButton addSubview:badge];
    self.scrollToBottomBadgeLabel = badge;
    self.scrollToBottomBadgeWidthConstraint = [badge.widthAnchor constraintEqualToConstant:18];
    self.scrollToBottomBadgeWidthConstraint.active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [badge.heightAnchor constraintEqualToConstant:18],
        [badge.trailingAnchor constraintEqualToAnchor:self.scrollToBottomButton.trailingAnchor constant:5],
        [badge.topAnchor constraintEqualToAnchor:self.scrollToBottomButton.topAnchor constant:-5],
    ]];
    
    // 添加到主视图
    [self.view addSubview:self.scrollToBottomButton];
    [self.view bringSubviewToFront:self.scrollToBottomButton];
    
    // 约束：右下角，在输入框上方
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollToBottomButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [self.scrollToBottomButton.bottomAnchor constraintEqualToAnchor:self.inputToolbar.topAnchor constant:-16],
        [self.scrollToBottomButton.widthAnchor constraintEqualToConstant:40],
        [self.scrollToBottomButton.heightAnchor constraintEqualToConstant:40],
    ]];

    [self rb_updateScrollToBottomButtonUnreadBadge];
}

/**
 * 根据当前滚动位置，显示或隐藏"回到底部"按钮
 * 当距离底部超过一屏高度时显示按钮，接近底部时隐藏
 */
- (void)updateScrollToBottomButtonVisibility
{
    UIScrollView *scrollView = self.collectionView;
    // 距离底部的距离 = 内容总高度 - 当前偏移 - 可视区高度
    CGFloat distanceFromBottom = scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.frame.size.height;
    
    // 当距离底部超过 300pt（约一屏半）时显示按钮
    BOOL shouldShow = (distanceFromBottom > 300);
    
    if (shouldShow && self.scrollToBottomButton.hidden) {
        self.scrollToBottomButton.hidden = NO;
        [UIView animateWithDuration:0.25 animations:^{
            self.scrollToBottomButton.alpha = 1.0;
        }];
    } else if (!shouldShow && !self.scrollToBottomButton.hidden) {
        [UIView animateWithDuration:0.25 animations:^{
            self.scrollToBottomButton.alpha = 0;
        } completion:^(BOOL finished) {
            if (finished) {
                self.scrollToBottomButton.hidden = YES;
            }
        }];
    }
    [self rb_updateScrollToBottomButtonUnreadBadge];
}

/**
 * 点击"回到底部"按钮：一键滚动到最新消息
 */
- (void)onScrollToBottomButtonTapped:(UIButton *)sender
{
    [self rb_scrollChatToBottomAfterEnsuringLayoutAnimated:YES];
}

/**
 * 点击"有人@我"悬浮提示按钮：滚动到第一个不可见的@我消息位置
 */
- (void)fireOnClickAtMeHint:(UIButton *)sender
{
    if (self.pendingAtMeIndexes.count == 0) {
        [self hideAtMeHintAnimated:YES];
        return;
    }
    
    NSArray<JSQMessage *> *allMessages = [self getChattingDatasList];
    
    // 按顺序跳转：每次点击都跳 pending 列表中的第一个
    while (self.pendingAtMeIndexes.count > 0) {
        NSString *targetMessageKey = self.pendingAtMeIndexes.firstObject ?: @"";
        NSInteger targetMsgIndex = [self rb_indexOfAtMeTrackedMessageKey:targetMessageKey inMessages:allMessages];
        JSQMessage *targetMsg = nil;
        if (targetMsgIndex >= 0 && targetMsgIndex < allMessages.count) {
            targetMsg = allMessages[targetMsgIndex];
        }
        // 先弹出当前目标（下一次点击自然跳到下一条）
        [self.pendingAtMeIndexes removeObjectAtIndex:0];
        
        if (targetMsgIndex == NSNotFound || targetMsgIndex < 0 || targetMsgIndex >= allMessages.count) {
            continue; // 索引失效则继续找下一条
        }
        
        // 记录“已处理到哪条@我”，避免后续重进会话时把旧@我再次统计
        [self markAtMeMessageHandled:targetMsg];
        
        DDLogDebug(@"【@我提示】点击顺序跳转，目标index=%ld key=%@，剩余待处理=%lu", (long)targetMsgIndex, targetMessageKey, (unsigned long)self.pendingAtMeIndexes.count);
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:targetMsgIndex inSection:0];
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredVertically
                                            animated:YES];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self refreshAtMeHintVisibility];
        });
        return;
    }
    
    // 全部跳完了
    [self hideAtMeHintAnimated:YES];
}

/**
 * 当收到新消息时，检查是否为@我的消息并记录。
 * 只负责将@我消息加入追踪列表，不做可见性判断和移除。
 * 移除逻辑由用户主动滚动（scrollViewDidScroll + isUserDragging）或点击跳转按钮触发。
 */
- (void)checkAndTrackAtMeMessage:(JSQMessage *)message atIndex:(NSInteger)index
{
    // 仅在群聊中处理@我功能
    if (self.chatType != CHAT_TYPE_GROUP_CHAT) {
        return;
    }
    
    // 检查是否@我
    if (message != nil && [message isAtMe] && ![message isOutgoing]) {
        NSString *messageKey = RBAtMeTrackingKeyForMessage(message);
        if (messageKey.length > 0 && ![self.pendingAtMeIndexes containsObject:messageKey]) {
            [self.pendingAtMeIndexes addObject:messageKey];
        }
        DDLogDebug(@"【@我提示】收到一条@我的消息，index=%ld key=%@，当前待处理@我消息数=%lu", (long)index, messageKey, (unsigned long)self.pendingAtMeIndexes.count);
    }
}

/**
 * 在每条新消息（包括非@我消息）到达后，延迟刷新@我提示的显示/隐藏状态。
 * 延迟是为了等自动滚动动画完成后再判断@我消息是否仍然在可见区域。
 * 注意：此方法只刷新UI显示状态（show/hide），不会移除已追踪的@我消息索引。
 */
- (void)scheduleAtMeHintRefresh
{
    if (self.pendingAtMeIndexes.count == 0) {
        return;
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshAtMeHintVisibility) object:nil];
    [self performSelector:@selector(refreshAtMeHintVisibility) withObject:nil afterDelay:0.5];
}

/**
 * 刷新"有人@我"提示的可见性：
 * 只检查当前是否有不可见的@我消息来决定 show/hide，不会自动移除追踪项。
 * 追踪项的移除仅由用户主动滚动（isUserDragging）或点击跳转按钮触发。
 */
- (void)refreshAtMeHintVisibility
{
    if (self.pendingAtMeIndexes.count == 0) {
        [self hideAtMeHintAnimated:YES];
        return;
    }
    
    NSArray<JSQMessage *> *allMessages = [self getChattingDatasList];
    
    // 清理无效标识（当前列表中已找不到）
    NSMutableIndexSet *invalidIndexes = [NSMutableIndexSet indexSet];
    for (NSUInteger i = 0; i < self.pendingAtMeIndexes.count; i++) {
        NSString *messageKey = self.pendingAtMeIndexes[i];
        if ([self rb_indexOfAtMeTrackedMessageKey:messageKey inMessages:allMessages] == NSNotFound) {
            [invalidIndexes addIndex:i];
        }
    }
    if (invalidIndexes.count > 0) {
        [invalidIndexes enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
            [self.pendingAtMeIndexes removeObjectAtIndex:idx];
        }];
    }
    
    // 只要还有待处理@我消息就显示提示（不再依赖“是否可见”）
    [self showAtMeHintAnimated:YES];
}

/**
 * 滚动时检查@我消息的可见性：
 * - 如果是用户手动拖拽（isUserDragging），则移除当前可见的@我消息追踪项（用户已经看到了）
 * - 如果是程序自动滚动（如收到新消息自动滚动到底部），则只刷新提示的 show/hide 状态，不移除追踪项
 */
- (void)checkAtMeVisibilityOnScroll
{
    if (self.pendingAtMeIndexes.count == 0) {
        return;
    }
    // 仅刷新显示状态，不因可见/滚动自动移除追踪项（移除由点击跳转触发）
    [self refreshAtMeHintVisibility];
}

/**
 * 显示"有人@我"悬浮提示（带动画）
 */
- (void)showAtMeHintAnimated:(BOOL)animated
{
    // 动态显示剩余数量，作为“有指示”
    NSString *title = [NSString stringWithFormat:@"有人@我(%lu)", (unsigned long)self.pendingAtMeIndexes.count];
    [self.btnAtMeHint setTitle:title forState:UIControlStateNormal];
    
    if (!self.btnAtMeHint.hidden) {
        return; // 已经显示了
    }
    
    self.btnAtMeHint.hidden = NO;
    // 确保按钮在最前面，不被其他视图遮挡
    [self.view bringSubviewToFront:self.btnAtMeHint];
    
    DDLogDebug(@"【@我提示】显示[有人@我]悬浮提示，当前待处理@我消息数=%lu", (unsigned long)self.pendingAtMeIndexes.count);
    
    if (animated) {
        self.btnAtMeHint.alpha = 0;
        self.btnAtMeHint.transform = CGAffineTransformMakeTranslation(60, 0);
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.btnAtMeHint.alpha = 1;
            self.btnAtMeHint.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

/**
 * 从当前会话消息中重建@我追踪列表（用于从会话列表进入聊天页时）。
 * 仅在群聊场景下生效；如果当前已有待处理追踪，则不重复重建。
 */
- (void)rebuildAtMeTrackingFromCurrentMessagesIfNeeded
{
    if (self.chatType != CHAT_TYPE_GROUP_CHAT) return;
    if (self.pendingAtMeIndexes.count > 0) return;
    
    NSArray<JSQMessage *> *list = [self getChattingDatasList];
    if (list.count == 0) return;
    
    NSDictionary *progress = [self loadAtMeProgress];
    NSString *lastHandledKey = RBAtMeTrackTrimmedString(progress[@"messageKey"]);
    NSString *lastHandledFp = RBAtMeTrackTrimmedString(progress[@"fp"]);
    long long lastHandledTime2 = [progress[@"time2"] longLongValue];
    BOOL hasKeyMarker = (lastHandledKey.length > 0 || lastHandledFp.length > 0);
    BOOL markerReached = !hasKeyMarker;
    BOOL markerFound = !hasKeyMarker;
    
    NSMutableArray<NSString *> *messageKeys = [NSMutableArray array];
    for (JSQMessage *msg in list) {
        
        // 使用稳定标识作为首选进度标记：仅统计“已处理标记之后”的@我消息
        if (!markerReached) {
            NSString *messageKey = RBAtMeTrackingKeyForMessage(msg);
            NSString *fp = RBAtMeTrackTrimmedString(msg.fingerPrintOfProtocal);
            if ((lastHandledKey.length > 0 && [messageKey isEqualToString:lastHandledKey])
                || (lastHandledFp.length > 0 && [fp isEqualToString:lastHandledFp])) {
                markerReached = YES;
                markerFound = YES;
            }
            continue;
        }
        
        if (msg != nil && [msg isAtMe] && ![msg isOutgoing]) {
            NSString *messageKey = RBAtMeTrackingKeyForMessage(msg);
            if (messageKey.length > 0) {
                [messageKeys addObject:messageKey];
            }
        }
    }
    
    if (hasKeyMarker && !markerFound && lastHandledTime2 > 0) {
        [messageKeys removeAllObjects];
        for (JSQMessage *msg in list) {
            if (!(msg != nil && [msg isAtMe] && ![msg isOutgoing])) continue;
            long long msgTime2 = (long long)([msg.date timeIntervalSince1970] * 1000);
            if (msgTime2 > lastHandledTime2) {
                NSString *messageKey = RBAtMeTrackingKeyForMessage(msg);
                if (messageKey.length > 0) {
                    [messageKeys addObject:messageKey];
                }
            }
        }
    }
    
    if (messageKeys.count > 0) {
        self.pendingAtMeIndexes = messageKeys;
        DDLogDebug(@"【@我提示】进入会话重建追踪完成，共 %lu 条", (unsigned long)messageKeys.count);
    }
}

- (NSString *)atMeProgressDefaultsKey
{
    NSString *uid = [[ClientCoreSDK sharedInstance] currentLoginUserId] ?: @"";
    NSString *target = self.toId ?: @"";
    return [NSString stringWithFormat:@"chat.atme.progress.%@.%d.%@", uid, self.chatType, target];
}

- (NSDictionary *)loadAtMeProgress
{
    NSString *key = [self atMeProgressDefaultsKey];
    id obj = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if ([obj isKindOfClass:[NSDictionary class]]) return (NSDictionary *)obj;
    return @{};
}

- (void)markAtMeMessageHandled:(JSQMessage *)message
{
    if (message == nil) return;
    NSString *key = [self atMeProgressDefaultsKey];
    NSString *messageKey = RBAtMeTrackingKeyForMessage(message);
    NSString *fp = RBAtMeTrackTrimmedString(message.fingerPrintOfProtocal);
    long long time2 = message.date != nil ? (long long)([message.date timeIntervalSince1970] * 1000) : 0;
    NSDictionary *payload = @{
        @"messageKey": messageKey ?: @"",
        @"fp": fp ?: @"",
        @"time2": @(time2)
    };
    [[NSUserDefaults standardUserDefaults] setObject:payload forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)hideAtMeHintAnimated:(BOOL)animated
{
    if (self.btnAtMeHint.hidden) return;
    if (animated) {
        [UIView animateWithDuration:0.25 animations:^{
            self.btnAtMeHint.alpha = 0;
            self.btnAtMeHint.transform = CGAffineTransformMakeTranslation(60, 0);
        } completion:^(BOOL finished) {
            self.btnAtMeHint.hidden = YES;
            self.btnAtMeHint.alpha = 1;
            self.btnAtMeHint.transform = CGAffineTransformIdentity;
        }];
    } else {
        self.btnAtMeHint.hidden = YES;
    }
}

@end
