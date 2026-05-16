//
//  ChatRootViewController+MessageMenu.m
//  长按菜单、多选、撤回/删除、收藏同步到服务端。
//

#import "ChatRootViewController+MessageMenu.h"
#import "ChatRootViewController.h"
#import "ChatRootViewController+Send.h"
#import "BasicTool.h"
#import "JSQMessage.h"
#import "JSQMessagesCollectionView.h"
#import "JSQMessagesCollectionViewCell.h"
#import "ViewControllerFactory.h"
#import "TargetSourceFilterFactory.h"
#import "Quote4InputWrapper.h"
#import "MessageRevokingProgess.h"
#import "MessageRevokingManager.h"
#import "MessageHelper.h"
#import "TMessageHelper.h"
#import "GMessageHelper.h"
#import "Protocal.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "EVAToolKits.h"
#import "StickerManager.h"
#import "SDWebImageManager.h"
#import "FileMeta.h"
#import "TimeTool.h"
#import "GroupsProvider.h"
#import "AlarmsProvider.h"
#import "AlarmType.h"
#import "TimeTool.h"
#import "RevokedMeta.h"
#import "RevokeCMDRecievedDTO.h"
#import "MessageBeRevoke.h"
#import "MessagesProvider.h"
#import "SendRetryManager.h"
#import "SendImageHelper.h"
#import "FaceBoardView.h"
#import "Default.h"
#import "JSQAudioMediaItem.h"
#import "MsgBodyRoot.h"
#import "AppDelegate.h"
#import "Protocal.h"
#import "CocoaLumberjack.h"
#import <UIKit/UIKit.h>

@interface ChatRootViewController (MessageMenuPrivate)
@property (strong, nonatomic) NSIndexPath *selectedIndexPathForMenu;
@property (strong, nonatomic) MessageRevokingProgess *messageRevokingDialogProgess;
@property (strong, nonatomic) Quote4InputWrapper *quote4InputWrapper;
@property (nonatomic, strong) UIView *multiSelectToolbar;
@property (nonatomic, strong) NSMutableSet<NSString *> *multiSelectedFingerprints;
@property (nonatomic, assign) BOOL isMultiSelectMode;
@property (nonatomic, strong) UIView *navTitleBubble;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIView *navBadgeLabel;
@property (nonatomic, strong) UIButton *navAvatarButton;
@property (nonatomic, assign) BOOL automaticallyScrollsToMostRecentMessage_ignoreOnce;
@property (nonatomic, strong) FaceBoardView *faceBoard;
- (NSMutableArray<JSQMessage *> *)getChattingDatasList;
- (BOOL)isOutgoingMessage:(JSQMessage *)entity;
- (void)hideBottomBoxAnim:(BOOL)anim;
- (void)resetLeftButton2Style;
- (UIImage *)loadLocalImg:(NSString *)fileName msgType:(int)msgType withTag:(NSString *)tag;
- (NSString *)getImageMessageDownloadURL:(NSString *)fileName;
- (UIBarButtonItem *)customRightBarButtonItemForRestore;
- (void)rb_restoreMinimalBackButton;
- (void)refreshNavBadge;
- (void)submitFavoriteToServerWithMessage:(JSQMessage *)cme sourceChatType:(int)sourceChatType onSyncSuccess:(void (^)(void))onSyncSuccess onComplete:(void (^)(BOOL success))onComplete;
- (void)refresh10001FavoritesListIfNeeded;
- (void)submitFavoriteToServerWithContent:(NSString *)content favType:(int)favType sourceChatType:(int)sourceChatType onSyncSuccess:(void (^)(void))onSyncSuccess;
- (void)didTapMessageBubble:(JSQMessage *)entity orClickedTheQuote:(BOOL)orClickedTheQuote currentMessageIndex:(NSInteger)index;
- (void)uploadImageAsSticker:(UIImage *)image;
- (void)forward:(JSQMessage *)cme toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forSucess:(void (^)(id observerble, id arg1))sucessObs;
- (JSQMessage *)rb_safeMessageAtIndex:(NSInteger)idx;
- (NSArray<NSString *> *)rb_allSelectableMultiSelectFingerprints;
@end

@implementation ChatRootViewController (MessageMenu)

static const CGFloat kChatMultiSelectActionBarHeight = 72.0f;

#pragma mark - iOS 13+ UIContextMenu（卡片式长按菜单）

// ★ 禁用 UIContextMenu — 改用自定义画布式长按菜单
- (UIContextMenuConfiguration *)collectionView:(UICollectionView *)collectionView
    contextMenuConfigurationForItemAtIndexPath:(NSIndexPath *)indexPath
                                        point:(CGPoint)point API_AVAILABLE(ios(13.0))
{
    return nil;
}

#pragma mark - ★ 自定义画布式长按菜单（替代 UIContextMenu / UIMenuController）

static const NSInteger kCustomMenuOverlayTag = 89757;

// 长按消息列表单元回调通知
- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView didLongPressCellAtIndexPath:(NSIndexPath *)indexPath touchLocation:(CGPoint)touchLocation cell:(UICollectionViewCell *)cell
{
    if (self.isMultiSelectMode) return;
    // 防止重复弹出
    if ([self.view.window viewWithTag:kCustomMenuOverlayTag]) return;
    
    NSIndexPath *realIndexPath = [collectionView indexPathForCell:cell];
    if (realIndexPath != nil) {
        indexPath = realIndexPath;
    }
    
    NSArray *dataList = [self getChattingDatasList];
    if (indexPath.item >= (NSInteger)dataList.count) return;
    
    JSQMessage *entity = dataList[indexPath.item];
    if (entity == nil || [entity isControl]) return;
    
    self.selectedIndexPathForMenu = indexPath;
    
    // 收起键盘/面板
    if ([self.inputToolbar.contentView.textView isFirstResponder]) {
        self.inputToolbar.contentView.textView.inputView = nil;
        [self.inputToolbar.contentView.textView resignFirstResponder];
    }
    [self hideBottomBoxAnim:NO];
    [self resetLeftButton2Style];
    
    // 触觉反馈
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    
    // —— 获取气泡快照和屏幕坐标 ——
    JSQMessagesCollectionViewCell *msgCell = ([cell isKindOfClass:[JSQMessagesCollectionViewCell class]])
        ? (JSQMessagesCollectionViewCell *)cell : nil;
    if (msgCell == nil) return;
    
    UIView *bubbleContainer = msgCell.messageBubbleContainerView;
    if (bubbleContainer == nil || CGRectIsEmpty(bubbleContainer.bounds)) return;
    
    [msgCell.contentView layoutIfNeeded];
    [bubbleContainer layoutIfNeeded];
    UIView *snapshot = [bubbleContainer snapshotViewAfterScreenUpdates:YES];
    if (snapshot == nil) return;
    
    CGRect bubbleFrameInWindow = [bubbleContainer convertRect:bubbleContainer.bounds toView:nil];
    UIWindow *window = self.view.window;
    CGRect windowBounds = window.bounds;
    // 长按触点在窗口中的位置（长内容时菜单位置以触点为准，不跟气泡顶/底绑死）
    CGPoint touchInWindow = [cell convertPoint:touchLocation toView:nil];
    
    // ======== 1. 全屏叠加层（液态玻璃，参考语音通话背景） ========
    UIView *overlay = [[UIView alloc] initWithFrame:windowBounds];
    overlay.tag = kCustomMenuOverlayTag;
    overlay.backgroundColor = [UIColor clearColor];
    
    // 液态毛玻璃：与来电弹窗/语音通话一致
    UIBlurEffect *blurEffect = nil;
    if (@available(iOS 13.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = windowBounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [overlay addSubview:blurView];
    
    // 轻微暗色蒙层，让前景气泡与菜单更突出（与语音通话 darkOverlay 一致）
    UIView *darkOverlay = [[UIView alloc] initWithFrame:windowBounds];
    darkOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    darkOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
    [overlay addSubview:darkOverlay];
    
    // 点击蒙层关闭
    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(jsq_dismissCustomMenu)];
    [darkOverlay addGestureRecognizer:dismissTap];
    
    // ======== 2. 气泡快照 ========
    snapshot.frame = bubbleFrameInWindow;
    snapshot.layer.shadowColor = [UIColor blackColor].CGColor;
    snapshot.layer.shadowOpacity = 0.15;
    snapshot.layer.shadowOffset = CGSizeMake(0, 4);
    snapshot.layer.shadowRadius = 12;
    [overlay addSubview:snapshot];
    
    // ======== 3. 菜单卡片 ========
    // 先统计菜单项数，用于精确计算高度
    BOOL isFavorites10001Chat = (self.chatType == CHAT_TYPE_FREIDN_CHAT
                                 && [self.toId isEqualToString:@"10001"]);
    NSInteger mainItemCount = 1; // 删除（始终存在）
    if ([entity isFavoriteEnabled] && !isFavorites10001Chat)  mainItemCount++;
    if ([entity isQuoteEnabled])     mainItemCount++;
    if (entity.msgType == TM_TYPE_TEXT) mainItemCount++;
    if ([entity isForwardEnabled])   mainItemCount++;
    if (entity.msgType == TM_TYPE_IMAGE) mainItemCount++; // 添加到表情
    if (entity.msgType == TM_TYPE_VOICE) mainItemCount++;
    if ([self messageCanBeRevoke:entity]) mainItemCount++;
    
    CGFloat rowHeight = 44.0;
    // 菜单高度 = (主项 + 选择) × 行高
    CGFloat menuHeight = (mainItemCount + 1) * rowHeight;
    
    UIView *menuCard = [self jsq_createMenuCardForEntity:entity];
    
    // 菜单宽度
    CGFloat menuWidth = 200;
    CGFloat menuX;
    BOOL isOutgoing = [self isOutgoingMessage:entity];
    if (isOutgoing) {
        menuX = CGRectGetMaxX(bubbleFrameInWindow) - menuWidth;
    } else {
        menuX = CGRectGetMinX(bubbleFrameInWindow);
    }
    menuX = MAX(12, MIN(menuX, windowBounds.size.width - menuWidth - 12));
    
    // 菜单位置：以长按触点为准，长内容时菜单紧贴手指附近；触点下方优先，不够再放上方
    CGFloat spaceBelowTouch = windowBounds.size.height - touchInWindow.y;
    CGFloat spaceAboveTouch = touchInWindow.y;
    CGFloat menuY;
    if (spaceBelowTouch >= menuHeight + 16) {
        menuY = touchInWindow.y + 12;
    } else if (spaceAboveTouch >= menuHeight + 16) {
        menuY = touchInWindow.y - menuHeight - 12;
    } else {
        // 上下都不够时：优先下方贴底，或上方贴顶
        if (spaceBelowTouch >= spaceAboveTouch) {
            menuY = windowBounds.size.height - menuHeight - 12;
        } else {
            menuY = 12;
        }
    }
    menuY = MAX(12, MIN(menuY, windowBounds.size.height - menuHeight - 12));
    
    menuCard.frame = CGRectMake(menuX, menuY, menuWidth, menuHeight);
    [overlay addSubview:menuCard];
    
    // ======== 4. 弹出动画 ========
    [window addSubview:overlay];
    
    overlay.alpha = 0;
    snapshot.transform = CGAffineTransformMakeScale(0.92, 0.92);
    menuCard.transform = CGAffineTransformMakeScale(0.85, 0.85);
    menuCard.alpha = 0;
    
    [UIView animateWithDuration:0.35 delay:0
         usingSpringWithDamping:0.78 initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        overlay.alpha = 1;
        snapshot.transform = CGAffineTransformIdentity;
        menuCard.transform = CGAffineTransformIdentity;
        menuCard.alpha = 1;
    } completion:nil];
    }
    
// ★ 构建菜单卡片（半透明毛玻璃）
- (UIView *)jsq_createMenuCardForEntity:(JSQMessage *)entity
{
    BOOL isFavorites10001Chat = (self.chatType == CHAT_TYPE_FREIDN_CHAT
                                 && [self.toId isEqualToString:@"10001"]);
    // 毛玻璃容器
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:blur];
    card.layer.cornerRadius = 13;
    card.layer.masksToBounds = YES;
    
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.contentView.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:card.contentView.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:card.contentView.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:card.contentView.bottomAnchor],
    ]];
    
    // —— 菜单项 ——
    NSMutableArray *items = [NSMutableArray array];
    
    if ([entity isQuoteEnabled]) {
        [items addObject:@[@"回复", @"arrowshape.turn.up.left", @"doMessageQuote:", @NO]];
    }
    if (entity.msgType == TM_TYPE_TEXT) {
        [items addObject:@[@"复制", @"doc.on.doc", @"doMesssageCopy:", @NO]];
    }
    if ([entity isFavoriteEnabled] && !isFavorites10001Chat) {
        [items addObject:@[@"收藏", @"star", @"doMessageFavorite:", @NO]];
    }
    if ([entity isForwardEnabled]) {
        [items addObject:@[@"转发", @"arrowshape.turn.up.right", @"doMessageForward:", @NO]];
    }
    if (entity.msgType == TM_TYPE_VOICE) {
        [items addObject:@[@"转文字", @"character.textbox", @"doVoiceToText:", @NO]];
    }
    // 图片消息可以添加到自定义表情
    if (entity.msgType == TM_TYPE_IMAGE) {
        [items addObject:@[@"添加到表情", @"face.smiling", @"doAddToSticker:", @NO]];
    }
    if ([self messageCanBeRevoke:entity]) {
        [items addObject:@[@"撤回", @"arrow.uturn.backward", @"doMessageRevoke:", @NO]];
    }
    // 我方发出的消息且仍在发送中（转圈）：显示「取消发送」；已发出或失败则显示「删除」
    if ([self isOutgoingMessage:entity] && entity.sendStatus == SendStatus_SNEDING) {
        [items addObject:@[@"取消发送", @"xmark.circle", @"doMessageCancelSend:", @NO]];
    } else {
        [items addObject:@[@"删除", @"trash", @"doMessageDelete:", @YES]];
    }
    
    for (NSUInteger i = 0; i < items.count; i++) {
        NSArray *item = items[i];
        [stack addArrangedSubview:[self jsq_createMenuRowWithTitle:item[0]
                                                          sfSymbol:item[1]
                                                          selector:NSSelectorFromString(item[2])
                                                     isDestructive:[item[3] boolValue]]];
    }
    
    // 选择（多选）
    [stack addArrangedSubview:[self jsq_createMenuRowWithTitle:@"选择"
                                                      sfSymbol:@"checkmark.circle"
                                                      selector:@selector(doEnterMultiSelect:)
                                                 isDestructive:NO]];
    
    return card;
}

// ★ 构建单个菜单行
- (UIView *)jsq_createMenuRowWithTitle:(NSString *)title
                              sfSymbol:(NSString *)sfSymbol
                              selector:(SEL)selector
                         isDestructive:(BOOL)isDestructive
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    
    UIColor *textColor = isDestructive ? [UIColor systemRedColor] : [UIColor labelColor];
    
    // 图标
    UIImageView *icon = [[UIImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = textColor;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
    icon.image = [UIImage systemImageNamed:sfSymbol withConfiguration:config];
    [btn addSubview:icon];
    
    // 文字
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    label.textColor = textColor;
    [btn addSubview:label];
    
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:btn.leadingAnchor constant:16],
        [icon.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:20],
        [icon.heightAnchor constraintEqualToConstant:20],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],
        [label.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:btn.trailingAnchor constant:-12],
        [btn.heightAnchor constraintEqualToConstant:44],
    ]];
    
    // 高亮效果
    [btn addTarget:self action:@selector(jsq_menuRowHighlight:) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:self action:@selector(jsq_menuRowUnhighlight:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    
    // 点击动作
    btn.tag = (NSInteger)selector;
    [btn addTarget:self action:@selector(jsq_menuRowTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    return btn;
}

- (void)jsq_menuRowHighlight:(UIButton *)btn {
    btn.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.15];
}
- (void)jsq_menuRowUnhighlight:(UIButton *)btn {
    btn.backgroundColor = [UIColor clearColor];
}

// ★ 菜单行点击 — 先关闭菜单再执行动作
- (void)jsq_menuRowTapped:(UIButton *)btn {
    SEL action = (SEL)btn.tag;
    [self jsq_dismissCustomMenuWithCompletion:^{
        if ([self respondsToSelector:action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:action withObject:nil];
#pragma clang diagnostic pop
        }
    }];
}

// ★ 关闭自定义菜单（外部点击）
- (void)jsq_dismissCustomMenu {
    [self jsq_dismissCustomMenuWithCompletion:^{
        self.selectedIndexPathForMenu = nil;
    }];
}

// ★ 关闭自定义菜单（带完成回调）
- (void)jsq_dismissCustomMenuWithCompletion:(void (^)(void))completion {
    UIView *overlay = [self.view.window viewWithTag:kCustomMenuOverlayTag];
    if (overlay == nil) {
        if (completion) completion();
        return;
    }
    
    [UIView animateWithDuration:0.25 delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        overlay.alpha = 0;
        // 找到菜单卡片和快照，做缩小动画
        for (UIView *sub in overlay.subviews) {
            if (![sub isKindOfClass:[UIVisualEffectView class]]) {
                sub.transform = CGAffineTransformMakeScale(0.92, 0.92);
            }
        }
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
        if (completion) completion();
    }];
}

// 点击消息列表单元中的消息引用内容的回调通知
- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView didTapQuoteAtIndexPath:(NSIndexPath *)indexPath cell:(UICollectionViewCell *)cell
{
//    NSLog(@"点击消息引用内容！！！！！！！！！！！！！！！1!");
    JSQMessage *entity = [self rb_safeMessageAtIndex:indexPath.item];
    if (!entity) return;
    [self didTapMessageBubble:entity orClickedTheQuote:YES currentMessageIndex:indexPath.item];
}

// @Override - 重写父类的方法：实现当长按弹出菜单隐藏时，进行变量的复位操作
- (void)didReceiveMenuWillHideNotification:(NSNotification *)notification
{
    [super didReceiveMenuWillHideNotification:notification];
    
    // 长按弹出菜单隐藏时同时复位菜单Item的 - add by JackJiang 20211115
    UIMenuController *menu = [UIMenuController sharedMenuController];
    [menu setMenuItems:nil];
    // 清除选中的行索引值
    self.selectedIndexPathForMenu = nil;
}

// 复制功能
-(void)doMesssageCopy:(UIMenuController *)sender
{
    if(self.selectedIndexPathForMenu != nil){
        JSQMessage *entity = [self rb_safeMessageAtIndex:self.selectedIndexPathForMenu.item];
        if (!entity) return;
        if(entity.msgType == TM_TYPE_TEXT){
//          DDLogDebug(@">>>>>>>>> fp=%@", entity.fingerPrintOfProtocal);
            [[UIPasteboard generalPasteboard] setString:[entity text]];
            [APP showUserDefineToast_OK:@"复制成功"];
        }
    }
}

- (void)doVoiceToText:(UIMenuController *)sender
{
    if (self.selectedIndexPathForMenu == nil) return;
    NSArray *list = [self getChattingDatasList];
    if (self.selectedIndexPathForMenu.item >= (NSInteger)list.count) return;
    JSQMessage *entity = list[self.selectedIndexPathForMenu.item];
    if (entity == nil || entity.msgType != TM_TYPE_VOICE) return;
    if (![entity.media isKindOfClass:[JSQAudioMediaItem class]]) return;
    JSQAudioMediaItem *item = (JSQAudioMediaItem *)entity.media;
    [item requestVoiceToText];
}
    
// 该消息是否可被撤回（子类可重写本方法实现自已的“撤回”功能权限可用逻辑）
-(BOOL)messageCanBeRevoke:(JSQMessage *)d
{
    if(d != nil){
        if (d.msgType == TM_TYPE_RED_PACKET || d.msgType == TM_TYPE_TRANSFER || d.msgType == TM_TYPE_VOIP_RECORD) {
            return NO;
        }
        // 只能撤回自已发出的 且 在撤回时限内的消息
        if([d isRevokeEnabled] && d.fingerPrintOfProtocal != nil) {
            return [ChatRootViewController messageIsNotTimeoutForRevoke:d];
        }
    }
    
    return NO;
}

// 撤回功能
-(void)doMessageRevoke:(UIMenuController *)sender
{
    if(self.selectedIndexPathForMenu != nil){
        JSQMessage *entity = [self rb_safeMessageAtIndex:self.selectedIndexPathForMenu.item];
        if(entity != nil) {
            [self doMessageRevokeImpl:entity];
        } else
            DDLogWarn(@"选中的entity=nil (selectedIndexPathForMenu=%@, 位于方法：%s)！", self.selectedIndexPathForMenu, __PRETTY_FUNCTION__);
    } else {
        DDLogWarn(@"选中的selectedIndexPathForMenu=nil ( 位于方法：%s)！", __PRETTY_FUNCTION__);
    }
}

// 撤回功能实现方法（请在子类中实现之）
-(void)doMessageRevokeImpl:(JSQMessage *)d
{
//    // 本方法请在子类中实现，父类中默认什么也不做！
//    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
    
    // 用于正式聊天
    if(CHAT_TYPE_FREIDN_CHAT == self.chatType) {
        [self processMessageRevoke:CHAT_TYPE_FREIDN_CHAT message:d toId:self.toId toName:nil];
    }
    // 用于临时聊天
    else if(CHAT_TYPE_GUEST_CHAT == self.chatType) {
        [self processMessageRevoke:CHAT_TYPE_GUEST_CHAT message:d toId:self.toId toName:self.toName];
    }
    // 用于群组聊天
    else if(CHAT_TYPE_GROUP_CHAT == self.chatType) {
        [self processMessageRevoke:CHAT_TYPE_GROUP_CHAT message:d toId:self.toId toName:nil];
    }
}

// 取消发送（仅发送中时显示；已发出则提示无法取消）
- (void)doMessageCancelSend:(UIMenuController *)sender
{
    if (self.selectedIndexPathForMenu == nil) return;
    NSArray *list = [self getChattingDatasList];
    if (self.selectedIndexPathForMenu.item >= (NSInteger)list.count) return;
    JSQMessage *entity = list[self.selectedIndexPathForMenu.item];
    if (entity == nil) return;
    if (entity.sendStatus != SendStatus_SNEDING) {
        [APP showToastWarn:@"消息已发送，无法取消"];
        return;
    }
    [self processMessageCancelSendImpl:entity];
}

// 删除功能
-(void)doMessageDelete:(UIMenuController *)sender
{
    if(self.selectedIndexPathForMenu != nil){
        JSQMessage *entity = [self rb_safeMessageAtIndex:self.selectedIndexPathForMenu.item];
        if(entity != nil){
            [self doMessageDeleteImpl:entity];
        } else
            DDLogWarn(@"选中的entity=nil (selectedIndexPathForMenu=%@, 位于方法：%s)！", self.selectedIndexPathForMenu, __PRETTY_FUNCTION__);
    } else {
        DDLogWarn(@"选中的selectedIndexPathForMenu=nil ( 位于方法：%s)！", __PRETTY_FUNCTION__);
    }
}

// 删除功能实现方法（请在子类中实现之）
-(void)doMessageDeleteImpl:(JSQMessage *)d
{
//    // 本方法请在子类中实现，父类中默认什么也不做！
//    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
    
    // 用于正式聊天
    if(CHAT_TYPE_FREIDN_CHAT == self.chatType) {
        [self processMessageDelete:CHAT_TYPE_FREIDN_CHAT fp:d.fingerPrintOfProtocal forId:self.toId];
    }
    // 用于临时聊天
    else if(CHAT_TYPE_GUEST_CHAT == self.chatType) {
        [self processMessageDelete:CHAT_TYPE_GUEST_CHAT fp:d.fingerPrintOfProtocal forId:self.toId];
    }
    // 用于群组聊天
    else if(CHAT_TYPE_GROUP_CHAT == self.chatType) {
        [self processMessageDelete:CHAT_TYPE_GROUP_CHAT fp:d.fingerPrintOfProtocal forId:self.toId];
    }
}

// 转发功能
-(void)doMessageForward:(UIMenuController *)sender
{
    if(self.selectedIndexPathForMenu != nil){
        JSQMessage *entity = [self rb_safeMessageAtIndex:self.selectedIndexPathForMenu.item];
        if(entity != nil) {
            // 从用户信息查看界面回来时，不需要自动滚动到聊天列表最底部，不然如果刚才看的文件是位于列表的上部时，每次回来想再看还得再往上翻页，影响体验
            self.automaticallyScrollsToMostRecentMessage_ignoreOnce = YES;
            
            // 进入转发目标选择界面
            [ViewControllerFactory goTargetChooseViewController:self.navigationController
                                          supportedTargetSource:TargetSourceLatestChatting | TargetSourceFriend | TargetSourceGroup
                                           latestChattingFilter:[TargetSourceFilterFactory createTargetSourceFilterLatestChatting4MsgForward:self.chatType toId:self.toId]
                                                   friendFilter:[TargetSourceFilterFactory createTargetSourceFilterFriend4MsgForward:self.chatType toId:self.toId]
                                                    groupFilter:[TargetSourceFilterFactory createTargetSourceFilterGroup4MsgForward:self.chatType toId:self.toId]
                                              groupMemberFilter:nil
                                                       extraObj:entity
                                                            gid:nil
                                                    requestCode:TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD
                                                       delegate:self];
        } else {
            DDLogWarn(@"选中的entity=nil (selectedIndexPathForMenu=%@, 位于方法：%s)！", self.selectedIndexPathForMenu, __PRETTY_FUNCTION__);
        }
    } else {
        DDLogWarn(@"选中的selectedIndexPathForMenu=nil ( 位于方法：%s)！", __PRETTY_FUNCTION__);
    }
}

// 引用功能
-(void)doMessageQuote:(UIMenuController *)sender
{
    if(self.selectedIndexPathForMenu != nil){
        JSQMessage *entity = [self rb_safeMessageAtIndex:self.selectedIndexPathForMenu.item];
        if(entity != nil) {
            if(self.quote4InputWrapper != nil)  {
                // 显示引用内容
                [self.quote4InputWrapper doQuote:self.chatType to:self.toId with:entity];
                
                // 输入框获得交点并弹出输入法
//                if(![self.inputToolbar.contentView.textView isFirstResponder])
//                {
//                    [self.inputToolbar.contentView.textView becomeFirstResponder];
//                }
                self.inputToolbar.contentView.textView.inputView = nil;//# Bug FIX 251020: ios26下，解决进入聊天界面后，首先使用引用功能时不会弹出输入法软键盘的问题
                if(![self.inputToolbar.contentView.textView isFirstResponder]){
                    [self.inputToolbar.contentView.textView becomeFirstResponder];
                }
                // 如果之前就已经是焦点状态了，则必须调用reloadInputViews才会弹出输入法。见系统inputView注释
                else {
                    [self.inputToolbar.contentView.textView reloadInputViews];
                    [self.inputToolbar.contentView.textView becomeFirstResponder];
                }
            }
            
        } else {
            DDLogWarn(@"选中的entity=nil (selectedIndexPathForMenu=%@, 位于方法：%s)！", self.selectedIndexPathForMenu, __PRETTY_FUNCTION__);
        }
    } else {
        DDLogWarn(@"选中的selectedIndexPathForMenu=nil ( 位于方法：%s)！", __PRETTY_FUNCTION__);
    }
}

// 收藏功能
-(void)doMessageFavorite:(UIMenuController *)sender
{
    if(self.selectedIndexPathForMenu != nil){
        JSQMessage *entity = [self rb_safeMessageAtIndex:self.selectedIndexPathForMenu.item];
        if(entity != nil) {
            [self doMessageFavoriteImpl:entity];
        } else {
            DDLogWarn(@"选中的entity=nil (selectedIndexPathForMenu=%@, 位于方法：%s)！", self.selectedIndexPathForMenu, __PRETTY_FUNCTION__);
        }
    } else {
        DDLogWarn(@"选中的selectedIndexPathForMenu=nil ( 位于方法：%s)！", __PRETTY_FUNCTION__);
    }
}

// 添加到表情功能
-(void)doAddToSticker:(UIMenuController *)sender
{
    if(self.selectedIndexPathForMenu != nil){
        JSQMessage *entity = [self rb_safeMessageAtIndex:self.selectedIndexPathForMenu.item];
        if(entity != nil && entity.msgType == TM_TYPE_IMAGE) {
            [self doAddToStickerImpl:entity];
        } else {
            DDLogWarn(@"选中的entity=nil或不是图片消息 (selectedIndexPathForMenu=%@, 位于方法：%s)！", self.selectedIndexPathForMenu, __PRETTY_FUNCTION__);
        }
    } else {
        DDLogWarn(@"选中的selectedIndexPathForMenu=nil ( 位于方法：%s)！", __PRETTY_FUNCTION__);
    }
}

// 添加到表情功能实现（静默处理）
-(void)doAddToStickerImpl:(JSQMessage *)entity
{
    if (entity.msgType != TM_TYPE_IMAGE) {
        return;
    }
    
    NSString *imageFileName = entity.text;
    if (!imageFileName || imageFileName.length == 0) {
        return;
    }
    
    // 先尝试从本地加载图片
    UIImage *localImage = [self loadLocalImg:imageFileName msgType:TM_TYPE_IMAGE withTag:@"添加到表情"];
    
    if (localImage) {
        // 本地图片存在，直接上传
        [self uploadImageAsSticker:localImage];
    } else {
        // 本地图片不存在，需要从网络下载
        NSString *imageUrl = [self getImageMessageDownloadURL:imageFileName];
        if (!imageUrl || imageUrl.length == 0) {
            return;
        }
        
        // 使用 SDWebImage 下载图片（静默下载）
        NSURL *url = [NSURL URLWithString:imageUrl];
        SDWebImageManager *manager = [SDWebImageManager sharedManager];
        [manager loadImageWithURL:url
                          options:SDWebImageRetryFailed
                         progress:nil
                        completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
            if (finished && image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self uploadImageAsSticker:image];
                });
            }
        }];
    }
}

// 上传图片为表情（静默处理）
-(void)uploadImageAsSticker:(UIImage *)image
{
    if (!image) {
        return;
    }
    
    // 静默上传，不显示任何提示
    [[StickerManager sharedInstance] uploadSticker:image complete:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                // 通知表情面板刷新（如果已打开）
                if (self.faceBoard) {
                    [self.faceBoard reloadStickerData];
                }
            }
        });
    }];
}

// 收藏功能实现：与「转发到收藏夹」一致，将消息发到 10001 会话（IM）；各类型发送成功后的服务端收藏同步仍由 ChatRootViewController+Send 中发往 10001 的回调负责
-(void)doMessageFavoriteImpl:(JSQMessage *)entity
{
    if (!entity || ![entity isFavoriteEnabled]) {
        [APP showUserDefineToast_OK:@"该消息不支持收藏"];
        return;
    }
    [self forward:entity toChatType:CHAT_TYPE_FREIDN_CHAT toId:@"10001" toName:@"收藏夹" forSucess:nil];
    [APP showUserDefineToast_OK:@"已转发到收藏夹"];
}

//---------------------------------------------------------------------------------------------------
#pragma mark - 消息"多选"功能（长按菜单触发）

/// 长按菜单中点击"多选"
-(void)doEnterMultiSelect:(UIMenuController *)sender
{
    // 先记录当前长按选中的消息，进入多选模式后自动预选中它
    NSString *preSelectedFp = nil;
    if(self.selectedIndexPathForMenu != nil){
        JSQMessage *entity = [self rb_safeMessageAtIndex:self.selectedIndexPathForMenu.item];
        if(entity != nil && entity.fingerPrintOfProtocal != nil) {
            preSelectedFp = entity.fingerPrintOfProtocal;
        }
    }
    
    [self enterMultiSelectMode];
    
    // 预选中长按的那条消息
    if(preSelectedFp != nil) {
        [self.multiSelectedFingerprints addObject:preSelectedFp];
        [self rb_invalidateChattingListLayoutCache];
        [self.collectionView reloadData];
        [self updateMultiSelectToolbarState];
    }
}

/// 进入多选模式
- (void)enterMultiSelectMode
{
    if(self.isMultiSelectMode) return;
    self.isMultiSelectMode = YES;
    
    // 初始化已选集合
    self.multiSelectedFingerprints = [NSMutableSet set];
    
    // 隐藏输入工具栏
    self.inputToolbar.hidden = YES;
    
    // 创建并显示底部多选工具栏
    [self setupMultiSelectToolbar];
    
    [self rb_navBeginMultiSelectMode];
    [self updateMultiSelectTitle];
    
    // 刷新列表显示checkbox
    [self rb_invalidateChattingListLayoutCache];
    [self.collectionView reloadData];
}

/// 退出多选模式
- (void)exitMultiSelectMode
{
    if(!self.isMultiSelectMode) return;
    self.isMultiSelectMode = NO;
    
    // 清理已选集合
    [self.multiSelectedFingerprints removeAllObjects];
    self.multiSelectedFingerprints = nil;
    
    // 移除底部多选工具栏
    if(self.multiSelectToolbar) {
        [self.multiSelectToolbar removeFromSuperview];
        self.multiSelectToolbar = nil;
    }
    
    // 恢复输入工具栏显示
    if (![BasicTool isReadOnlyOfficialAccount:self.toId]) {
        self.inputToolbar.hidden = NO;
    }
    
    [self rb_navRestoreAfterExitMultiSelect];
    if (self.navBadgeLabel.superview) {
        [self refreshNavBadge];
    }
    
    // 刷新列表隐藏checkbox
    [self rb_invalidateChattingListLayoutCache];
    [self.collectionView reloadData];
}

/// 创建底部多选操作工具栏
- (void)setupMultiSelectToolbar
{
    if(self.multiSelectToolbar) {
        [self.multiSelectToolbar removeFromSuperview];
    }
    BOOL isFavorites10001Chat = (self.chatType == CHAT_TYPE_FREIDN_CHAT
                                 && [self.toId isEqualToString:@"10001"]);
    
    CGFloat toolbarHeight = kChatMultiSelectActionBarHeight + self.view.safeAreaInsets.bottom;
    UIView *toolbar = [[UIView alloc] init];
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    toolbar.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.96f];
    if (@available(iOS 13.0, *)) {
        toolbar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    }
    
    // 顶部分割线
    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.08f];
    [toolbar addSubview:separator];
    [NSLayoutConstraint activateConstraints:@[
        [separator.topAnchor constraintEqualToAnchor:toolbar.topAnchor],
        [separator.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor],
        [separator.heightAnchor constraintEqualToConstant:1.0f],
    ]];
    
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.distribution = UIStackViewDistributionFillEqually;
    stackView.alignment = UIStackViewAlignmentFill;
    stackView.spacing = 10.0f;
    [toolbar addSubview:stackView];
    
    UIButton *(^makeActionButton)(NSString *, SEL, UIColor *, NSInteger) = ^UIButton *(NSString *title, SEL action, UIColor *titleColor, NSInteger tag) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn setTitle:title forState:UIControlStateNormal];
        [btn setTitleColor:titleColor forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:15.0f weight:UIFontWeightSemibold];
        btn.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.04f];
        btn.layer.cornerRadius = 12.0f;
        btn.layer.masksToBounds = YES;
        btn.tag = tag;
        [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
        return btn;
    };

    UIColor *normalColor = [UIColor colorWithWhite:0.17f alpha:1.0f];
    UIButton *btnToggleSelect = makeActionButton(@"全选", @selector(rb_onChatBatchToggleSelectTapped:), normalColor, 1000);
    UIButton *btnForward = makeActionButton(@"转发", @selector(doMultiSelectForward), normalColor, 1001);
    UIButton *btnDelete = makeActionButton(@"删除", @selector(doMultiSelectDelete), [UIColor colorWithRed:0.89f green:0.23f blue:0.19f alpha:1.0f], 1002);
    UIButton *btnFavorite = makeActionButton(@"收藏", @selector(doMultiSelectFavorite), normalColor, 1003);

    [stackView addArrangedSubview:btnToggleSelect];
    [stackView addArrangedSubview:btnForward];
    [stackView addArrangedSubview:btnDelete];
    if (!isFavorites10001Chat) {
        [stackView addArrangedSubview:btnFavorite];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [stackView.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor constant:16.0f],
        [stackView.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor constant:-16.0f],
        [stackView.topAnchor constraintEqualToAnchor:toolbar.topAnchor constant:10.0f],
        [stackView.bottomAnchor constraintEqualToAnchor:toolbar.safeAreaLayoutGuide.bottomAnchor constant:-10.0f],
    ]];
    
    [self.view addSubview:toolbar];
    [NSLayoutConstraint activateConstraints:@[
        [toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [toolbar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [toolbar.heightAnchor constraintEqualToConstant:toolbarHeight],
    ]];
    
    self.multiSelectToolbar = toolbar;
    
    // 初始状态下按钮禁用
    [self updateMultiSelectToolbarState];
}

/// 更新多选工具栏按钮的启用/禁用状态
- (void)updateMultiSelectToolbarState
{
    BOOL hasSelection = (self.multiSelectedFingerprints.count > 0);
    NSArray<NSString *> *allFingerprints = [self rb_allSelectableMultiSelectFingerprints];
    BOOL hasRows = (allFingerprints.count > 0);
    BOOL allSelected = hasRows && (self.multiSelectedFingerprints.count == allFingerprints.count);
    if(self.multiSelectToolbar) {
        UIButton *btnToggleSelect = [self.multiSelectToolbar viewWithTag:1000];
        UIButton *btnForward = [self.multiSelectToolbar viewWithTag:1001];
        UIButton *btnDelete = [self.multiSelectToolbar viewWithTag:1002];
        UIButton *btnFavorite = [self.multiSelectToolbar viewWithTag:1003];
        if (btnToggleSelect) {
            NSString *toggleTitle = allSelected ? @"取消全选" : @"全选";
            [btnToggleSelect setTitle:toggleTitle forState:UIControlStateNormal];
            btnToggleSelect.enabled = hasRows;
            btnToggleSelect.alpha = hasRows ? 1.0f : 0.45f;
        }
        btnForward.enabled = hasSelection;
        btnDelete.enabled = hasSelection;
        btnForward.alpha = hasSelection ? 1.0f : 0.45f;
        btnDelete.alpha = hasSelection ? 1.0f : 0.45f;
        if (btnFavorite) {
            btnFavorite.enabled = hasSelection;
            btnFavorite.alpha = hasSelection ? 1.0f : 0.45f;
        }
    }
    [self updateMultiSelectTitle];
}

- (NSArray<NSString *> *)rb_allSelectableMultiSelectFingerprints
{
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    NSArray<JSQMessage *> *allMessages = [self getChattingDatasList];
    for (JSQMessage *msg in allMessages) {
        NSString *fp = [BasicTool trim:msg.fingerPrintOfProtocal];
        if (fp.length > 0) {
            [result addObject:fp];
        }
    }
    return result;
}

- (void)rb_onChatBatchToggleSelectTapped:(id)sender
{
    (void)sender;
    NSArray<NSString *> *allFingerprints = [self rb_allSelectableMultiSelectFingerprints];
    if (allFingerprints.count == 0) {
        return;
    }
    BOOL shouldSelectAll = (self.multiSelectedFingerprints.count != allFingerprints.count);
    [self.multiSelectedFingerprints removeAllObjects];
    if (shouldSelectAll) {
        [self.multiSelectedFingerprints addObjectsFromArray:allFingerprints];
    }
    [self rb_invalidateChattingListLayoutCache];
    [self.collectionView reloadData];
    [self updateMultiSelectToolbarState];
}

/// 更新导航栏标题为已选数量
- (void)updateMultiSelectTitle
{
    NSUInteger count = self.multiSelectedFingerprints.count;
    NSString *t = (count > 0)
        ? [NSString stringWithFormat:@"已选择 %lu 条", (unsigned long)count]
        : @"选择消息";
    self.title = t;
}

/// 获取当前多选中的消息对象列表（按在聊天列表中的顺序排列）
- (NSArray<JSQMessage *> *)getMultiSelectedMessages
{
    NSMutableArray<JSQMessage *> *result = [NSMutableArray array];
    if(self.multiSelectedFingerprints.count == 0) return result;
    
    NSArray<JSQMessage *> *allMessages = [self getChattingDatasList];
    for (JSQMessage *msg in allMessages) {
        if(msg.fingerPrintOfProtocal != nil && [self.multiSelectedFingerprints containsObject:msg.fingerPrintOfProtocal]) {
            [result addObject:msg];
        }
    }
    return result;
}

/// 批量转发
- (void)doMultiSelectForward
{
    NSArray<JSQMessage *> *selectedMessages = [self getMultiSelectedMessages];
    if(selectedMessages.count == 0) {
        [APP showUserDefineToast_OK:@"请先选择消息"];
        return;
    }
    
    // ★ 过滤不支持转发的消息类型（音视频通话记录、系统消息、撤回消息、发送失败的消息等）
    NSMutableArray<JSQMessage *> *forwardableMessages = [NSMutableArray array];
    NSMutableSet<NSString *> *skippedTypes = [NSMutableSet set];
    
    for (JSQMessage *msg in selectedMessages) {
        if ([msg isForwardEnabled]) {
            [forwardableMessages addObject:msg];
        } else {
            // 记录被跳过的消息类型名称，用于提示
            switch (msg.msgType) {
                case TM_TYPE_VOIP_RECORD:
                    [skippedTypes addObject:@"通话记录"];
                    break;
                case TM_TYPE_SYSTEAM_INFO:
                    [skippedTypes addObject:@"系统消息"];
                    break;
                case TM_TYPE_REVOKE:
                    [skippedTypes addObject:@"撤回消息"];
                    break;
                case TM_TYPE_RED_PACKET:
                    [skippedTypes addObject:@"红包"];
                    break;
                case TM_TYPE_TRANSFER:
                    [skippedTypes addObject:@"转账"];
                    break;
                default:
                    if ([msg isOutgoing] && msg.sendStatus != SendStatus_BE_RECEIVED) {
                        [skippedTypes addObject:@"发送失败的消息"];
                    } else {
                        [skippedTypes addObject:[NSString stringWithFormat:@"类型%d的消息", msg.msgType]];
                    }
                    break;
            }
        }
    }
    
    // 全部消息都不支持转发
    if (forwardableMessages.count == 0) {
        NSString *typesStr = [[skippedTypes allObjects] componentsJoinedByString:@"、"];
        [APP showUserDefineToast_OK:[NSString stringWithFormat:@"所选消息均不支持转发（%@）", typesStr]];
        return;
    }
    
    // 部分消息不支持转发，提示用户后继续转发可转发的部分
    if (skippedTypes.count > 0) {
        NSString *typesStr = [[skippedTypes allObjects] componentsJoinedByString:@"、"];
        NSString *hint = [NSString stringWithFormat:@"已自动跳过 %lu 条不支持转发的消息（%@）",
                          (unsigned long)(selectedMessages.count - forwardableMessages.count), typesStr];
        [APP showUserDefineToast_OK:hint];
    }
    
    // 从用户信息查看界面回来时，不需要自动滚动到聊天列表最底部
    self.automaticallyScrollsToMostRecentMessage_ignoreOnce = YES;
    
    // 进入转发目标选择界面，extraObj 传入过滤后的可转发消息数组
    [ViewControllerFactory goTargetChooseViewController:self.navigationController
                                  supportedTargetSource:TargetSourceLatestChatting | TargetSourceFriend | TargetSourceGroup
                                   latestChattingFilter:[TargetSourceFilterFactory createTargetSourceFilterLatestChatting4MsgForward:self.chatType toId:self.toId]
                                           friendFilter:[TargetSourceFilterFactory createTargetSourceFilterFriend4MsgForward:self.chatType toId:self.toId]
                                            groupFilter:[TargetSourceFilterFactory createTargetSourceFilterGroup4MsgForward:self.chatType toId:self.toId]
                                      groupMemberFilter:nil
                                               extraObj:forwardableMessages
                                                    gid:nil
                                            requestCode:TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD
                                               delegate:self];
}

/// 批量删除
- (void)doMultiSelectDelete
{
    NSArray<JSQMessage *> *selectedMessages = [self getMultiSelectedMessages];
    if(selectedMessages.count == 0) {
        [APP showUserDefineToast_OK:@"请先选择消息"];
        return;
    }
    
    NSString *confirmMsg = [NSString stringWithFormat:@"确定要删除选中的 %lu 条消息吗？", (unsigned long)selectedMessages.count];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"批量删除"
                                                                  message:confirmMsg
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if(!strongSelf) return;
        
        for (JSQMessage *msg in selectedMessages) {
            [strongSelf doMessageDeleteImpl:msg];
        }
        
        [APP showUserDefineToast_OK:[NSString stringWithFormat:@"已删除 %lu 条消息", (unsigned long)selectedMessages.count]];
        [strongSelf exitMultiSelectMode];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

/// 批量收藏
- (void)doMultiSelectFavorite
{
    NSArray<JSQMessage *> *selectedMessages = [self getMultiSelectedMessages];
    if(selectedMessages.count == 0) {
        [APP showUserDefineToast_OK:@"请先选择消息"];
        return;
    }
    
    // 过滤不支持收藏的消息类型（转账、音视频、红包、系统消息等）
    NSMutableArray<JSQMessage *> *favoritableMessages = [NSMutableArray array];
    NSMutableSet<NSString *> *skippedTypes = [NSMutableSet set];
    for (JSQMessage *msg in selectedMessages) {
        if ([msg isControl]) continue;
        if ([msg isFavoriteEnabled]) {
            [favoritableMessages addObject:msg];
        } else {
            switch (msg.msgType) {
                case TM_TYPE_VOIP_RECORD:
                    [skippedTypes addObject:@"通话记录"];
                    break;
                case TM_TYPE_SYSTEAM_INFO:
                    [skippedTypes addObject:@"系统消息"];
                    break;
                case TM_TYPE_REVOKE:
                    [skippedTypes addObject:@"撤回消息"];
                    break;
                case TM_TYPE_RED_PACKET:
                    [skippedTypes addObject:@"红包"];
                    break;
                case TM_TYPE_TRANSFER:
                    [skippedTypes addObject:@"转账"];
                    break;
                default:
                    [skippedTypes addObject:[NSString stringWithFormat:@"类型%d的消息", msg.msgType]];
                    break;
            }
        }
    }
    
    if (favoritableMessages.count == 0) {
        NSString *typesStr = [[skippedTypes allObjects] componentsJoinedByString:@"、"];
        [APP showUserDefineToast_OK:[NSString stringWithFormat:@"所选消息均不支持收藏（%@）", typesStr]];
        return;
    }
    
    if (skippedTypes.count > 0) {
        NSString *typesStr = [[skippedTypes allObjects] componentsJoinedByString:@"、"];
        NSString *hint = [NSString stringWithFormat:@"已自动跳过 %lu 条不支持收藏的消息（%@）",
                         (unsigned long)(selectedMessages.count - favoritableMessages.count), typesStr];
        [APP showUserDefineToast_OK:hint];
    }
    
    __weak typeof(self) weakSelf = self;
    __block NSUInteger successCount = 0;
    __block NSUInteger totalCount = favoritableMessages.count;
    
    for (JSQMessage *msg in favoritableMessages) {
        [self doMessageFavoriteImplSilent:msg completion:^(BOOL success) {
            if(success) successCount++;
            totalCount--;
            if(totalCount == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if(!strongSelf) return;
                    if(successCount > 0) {
                        [APP showUserDefineToast_OK:[NSString stringWithFormat:@"已收藏 %lu 条消息", (unsigned long)successCount]];
                    } else {
                        [APP showUserDefineToast_OK:@"收藏失败"];
                    }
                    [strongSelf exitMultiSelectMode];
                });
            }
        }];
    }
}

/// 静默收藏单条消息（不弹toast，通过回调通知结果）
- (void)doMessageFavoriteImplSilent:(JSQMessage *)entity completion:(void (^)(BOOL success))completion
{
    if (!entity || ![entity isFavoriteEnabled]) {
        if (completion) completion(NO);
        return;
    }
    // 静默收藏：仅写入服务端收藏并刷新，不转发 IM，避免重复
    __weak typeof(self) weakSelf = self;
    void (^outCompletion)(BOOL) = completion;
    [self submitFavoriteToServerWithMessage:entity sourceChatType:self.chatType onSyncSuccess:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) [strongSelf refresh10001FavoritesListIfNeeded];
    } onComplete:^(BOOL success) {
        if (outCompletion) outCompletion(success);
    }];
}

#pragma mark - 收藏同步到服务端（多端同步）

// 服务端收藏类型见 ChatRootViewController+MessageMenu.h 中的 kFavType* 宏定义

/// 将一条消息同步写入服务端收藏（多端同步）。仅用于「收藏」操作，不发送 IM 到 10001，避免与「转发到 10001」重复写入。
/// @param onSyncSuccess 同步成功时在主线程回调（可选），用于刷新收藏列表并提示
/// @param onComplete 同步结束时的回调（可选），参数为是否成功，主线程
- (void)submitFavoriteToServerWithMessage:(JSQMessage *)cme sourceChatType:(int)sourceChatType onSyncSuccess:(void (^)(void))onSyncSuccess onComplete:(void (^)(BOOL success))onComplete
{
    if (!cme) return;
    NSString *userUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!userUid.length) return;

    int favType = -1;
    NSString *content = cme.text ?: @"";
    switch (cme.msgType) {
        case TM_TYPE_TEXT:
            favType = kFavTypeText;
            break;
        case TM_TYPE_IMAGE:
            favType = kFavTypeImage;
            break;
        case TM_TYPE_VOICE:
            favType = kFavTypeVoice;
            break;
        case TM_TYPE_SHORTVIDEO: {
            favType = kFavTypeVideo;
            FileMeta *fm = [FileMeta fromJSON:cme.text];
            if (fm && fm.fileName.length) {
                int duration = [TimeTool getDurationFromVoiceFileName:fm.fileName];
                if (duration <= 0) duration = 10;
                NSDictionary *videoInfo = @{
                    @"file_name": fm.fileName ?: @"",
                    @"file_md5": fm.fileMd5 ?: @"",
                    @"duration": @(duration)
                };
                content = [EVAToolKits toJSON:videoInfo] ?: cme.text;
            }
            break;
        }
        case TM_TYPE_FILE:
            favType = kFavTypeFile;
            break;
        case TM_TYPE_LOCATION:
            favType = kFavTypeLocation;
            break;
        case TM_TYPE_CONTACT:
            favType = kFavTypeText;
            // 存 ContactMeta JSON，便于 10001 列表加载时还原为名片气泡展示
            content = (cme.text.length > 0) ? cme.text : [NSString stringWithFormat:@"[名片] %@", [JSQMessage parseMessageContentPreview:cme.text withType:TM_TYPE_CONTACT]];
            break;
        case TM_TYPE_GIFT_SEND:
        case TM_TYPE_GIFT_GET:
            favType = kFavTypeText;
            content = [NSString stringWithFormat:@"[礼物] %@", [JSQMessage parseMessageContentPreview:cme.text withType:cme.msgType]];
            break;
        default:
            return; // 不支持的类型不写入服务端收藏
    }

    NSString *sourceUid = cme.senderId.length ? cme.senderId : userUid;
    NSString *sourceNick = cme.senderDisplayName.length ? cme.senderDisplayName : ([IMClientManager sharedInstance].localUserInfo.nickname ?: @"我");

    void (^onSuccess)(void) = onSyncSuccess;
    void (^onDone)(BOOL) = onComplete;
    [[HttpRestHelper sharedInstance] submitAddFavoriteToServer:userUid
                                                        favType:favType
                                                       content:content
                                             sourceFingerprint:cme.fingerPrintOfProtocal
                                                sourceChatType:sourceChatType
                                                 sourceFromUid:sourceUid
                                            sourceFromNickname:sourceNick
                                                          memo:nil
                                                      complete:^(BOOL sucess, NSString *resultCode) {
        if (!sucess) DDLogWarn(@"【收藏】同步到服务端失败");
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && onSuccess) onSuccess();
            if (onDone) onDone(sucess);
        });
    } hudParentView:nil];
}

/// 直接发送到 10001 时，将内容同步写入服务端收藏（供多端同步）。同步成功后调用 onSyncSuccess（主线程），用于刷新收藏列表使新消息立即显示。
- (void)submitFavoriteToServerWithContent:(NSString *)content
                                  favType:(int)favType
                          sourceChatType:(int)sourceChatType
                            onSyncSuccess:(void (^)(void))onSyncSuccess
{
    NSString *userUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!userUid.length || !content.length) return;
    NSString *nick = [IMClientManager sharedInstance].localUserInfo.nickname ?: @"我";
    void (^onSuccess)(void) = onSyncSuccess;
    [[HttpRestHelper sharedInstance] submitAddFavoriteToServer:userUid
                                                        favType:favType
                                                       content:content
                                             sourceFingerprint:nil
                                                sourceChatType:sourceChatType
                                                 sourceFromUid:userUid
                                            sourceFromNickname:nick
                                                          memo:nil
                                                      complete:^(BOOL sucess, NSString *resultCode) {
        if (!sucess) {
            DDLogWarn(@"【收藏】直接发送到 10001 同步服务端失败");
            return;
        }
        if (onSuccess) {
            dispatch_async(dispatch_get_main_queue(), ^{ onSuccess(); });
        }
    } hudParentView:nil];
}

/// 10001 收藏同步到服务端成功后调用，子类可重写以刷新收藏列表（如重新拉第一页），使刚发送的消息立即显示
- (void)refresh10001FavoritesListIfNeeded
{
}

//------------------------------ 以下代码是专为弹出菜单准备的（由系统调用） START
/**
 * 让xx具备成为第一响应者的资格（用天长按弹出菜单时）。注意：没有这个方法，系统不会让菜单弹出哦。
 *
 * @since 4.3
 */
- (BOOL)canBecomeFirstResponder
{
    return YES;
    
//    UIWindow *window = [[UIApplication sharedApplication].delegate window];
//        if ([window isKeyWindow] == NO)
//        {
//            [window becomeKeyWindow];
//            [window makeKeyAndVisible];
//        }
//        return YES;

}

-(BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if(self.selectedIndexPathForMenu != nil) {
        BOOL isFavorites10001Chat = (self.chatType == CHAT_TYPE_FREIDN_CHAT
                                     && [self.toId isEqualToString:@"10001"]);
        if (action == @selector(doMessageFavorite:) && isFavorites10001Chat) {
            return NO;
        }
        if (action == @selector(doMesssageCopy:)
            || action == @selector(doMessageRevoke:)
            || action == @selector(doMessageDelete:)
            || action == @selector(doMessageCancelSend:)
            || action == @selector(doMessageForward:)
            || action == @selector(doMessageQuote:)
            || action == @selector(doMessageFavorite:)
            || action == @selector(doAddToSticker:)
            || action == @selector(doEnterMultiSelect:))// FIXME: 添加菜单Item时，记得在此处添加一下判断逻辑，否则UI上不会显示该item哦！
        {
            return YES; //显示自定义的菜单项
        } else {
            return NO;
        }
    }
    
    if (action == @selector(paste:)) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        return pasteboard.string != nil;
    }
    return NO;
}

- (void)paste:(id)sender
{
    [self.inputToolbar.contentView.textView paste:sender];
}
//------------------------------ 以下代码是专为弹出菜单准备的 START

// 该消息是否未超出撤回时限
+ (BOOL)messageIsNotTimeoutForRevoke:(JSQMessage *)d
{
    NSDate *cur = [NSDate date];
    if (d.date != nil && [cur timeIntervalSince1970] - [d.date timeIntervalSince1970 ] < CHATTING_MESSAGE_CAN_BE_REVOKE_TIME * 60) {
        return YES;
    }
    return NO;
}

- (NSString *) getImageMessageDownloadURL:(NSString *)fileName
{
    return [SendImageHelper getImageDownloadURL:fileName dump:NO]; 
}

//---------------------------------------------------------------------------------------------------
#pragma mark - 消息”撤回”功能对应的方法

// 用于收到消息撤回指令应答的后续步骤
- (void)revokeCMDRecievedComplete:(NSNotification*)notification
{
    RevokeCMDRecievedDTO *dto = (RevokeCMDRecievedDTO *)notification.object;
    
//  DDLogDebug(@"################# 短视频录制完成 ，dto=%@", dto);
    if(dto != nil)
    {
        NSString *fpForRevokeCMD = dto.fpForRevokeCMD;
        NSString *fpForMessage = dto.fpForRMessage;
        DDLogInfo(@"【消息撤回】收到 fpForMessage=%@、fpForRevokeCMD=%@ 已通过QoS确认送达的广播通知！", fpForMessage, fpForRevokeCMD);

        // 取消消息撤回进度提示框的显示
        [self hideMessageRevokingProgess:NO fp:fpForMessage];
        // 刷新聊天列表UI显示
        [self rb_invalidateChattingListLayoutCache];
        [self.collectionView reloadData];
    }
    else
        DDLogWarn(@"【消息撤回】已收到消息撤回指令应答的通知，但传过来的dto对象是nil！");
}

// 显示进度提示框
- (void) showMessageRevokingProgess:(NSString *)fpForMessage
{
    if(self.messageRevokingDialogProgess != nil){
        [self.messageRevokingDialogProgess hide:YES fp:nil];
        self.messageRevokingDialogProgess = nil;
    }
    
    self.messageRevokingDialogProgess = [[MessageRevokingProgess alloc] initWith:self];
    [self.messageRevokingDialogProgess show:fpForMessage];
}

// 隐藏进度提示框的显示
- (void) hideMessageRevokingProgess:(BOOL)enforce fp:(NSString *)fpForMessage
{
    if(self.messageRevokingDialogProgess != nil){
        [self.messageRevokingDialogProgess hide:NO fp:fpForMessage];
        self.messageRevokingDialogProgess = nil;
    }
}

// 消息"撤回"功能实现
- (void) processMessageRevoke:(int)chatType message:(JSQMessage *)message toId:(NSString *)toId toName:(NSString *)toName
{
    if(message == nil) {
        DDLogWarn(@"【消息撤回】doMessageRevoking中，message == null！");
        [BasicTool showAlertWarn:@"无法撤回消息，请重启应用后再试！" parent:self];
        return;
    }

    if (message.msgType == TM_TYPE_RED_PACKET || message.msgType == TM_TYPE_TRANSFER || message.msgType == TM_TYPE_VOIP_RECORD) {
        [BasicTool showAlertWarn:@"红包、转账与音视频通话记录不支持撤回" parent:self];
        return;
    }
    
    //** 最终再次进行消息撤回时限检查（含群主/管理员），防止菜单未关导致超时后仍可点撤回
    if(![ChatRootViewController messageIsNotTimeoutForRevoke:message]){
        [BasicTool showAlertWarn:[NSString stringWithFormat:@"只能撤回 %d 分钟内的消息", CHATTING_MESSAGE_CAN_BE_REVOKE_TIME] parent:self];
        return;
    }
    
    BOOL isGroupChat = (chatType == CHAT_TYPE_GROUP_CHAT);
    // 被撤回消息对应的指纹码（也就是唯一消息ID啦）
    NSString *fpForMessage = (isGroupChat ? message.fingerPrintOfParent :  message.fingerPrintOfProtocal);
    
    // 显示撤回进度提示框
    [self showMessageRevokingProgess:fpForMessage];
    
    // 准备好将要发出的"撤回"指令的指令内容
    RevokedMeta *contentForRevokeCMD = [MessageRevokingManager constructRevokedMetaForOperator:fpForMessage
                                        // 是群聊 且 撤回的是别人的消息时，需要传入被撤回消息发送者的uid
                                         beUid:(isGroupChat && ![message isOutgoing]?message.senderId:nil)
                                        // 是群聊 且 撤回的是别人的消息时，需要传入被撤回消息发送者的昵称
                                    beNickName:(isGroupChat && ![message isOutgoing]?message.senderDisplayName:nil)
    ];
    if(contentForRevokeCMD == nil)
        return;
    
    // 为将要发出的"撤回"指令准备好指纹码
    NSString *fpForRevokeCMD = [Protocal genFingerPrint];
    
    // 加入消息撤回管理器！
    MessageBeRevoke *messageWillBeRevoke = [MessageBeRevoke initWith:chatType toId:toId message:message];
    if(messageWillBeRevoke != nil) {
        // 撤回管理器中执行"开始"撤回逻辑
        MessageRevokingManager *mgr = [[IMClientManager sharedInstance] getMessageRevokingManager];
        [mgr revokeStart:fpForRevokeCMD messageBeRevoke:messageWillBeRevoke];
        
        // 发送撤回指令
        if(chatType == CHAT_TYPE_FREIDN_CHAT)
            [MessageHelper sendRevokeMessageAsync:fpForRevokeCMD friendUID:toId withMeta:contentForRevokeCMD forSucess:nil];
        else if(chatType == CHAT_TYPE_GUEST_CHAT)
            [TMessageHelper sendRevokeMessageAsync:fpForRevokeCMD tuid:toId tuname:toName withMeta:contentForRevokeCMD forSucess:nil];
        else if(chatType == CHAT_TYPE_GROUP_CHAT)
            [GMessageHelper sendRevokeMessageAsync:fpForRevokeCMD gid:toId withMeta:contentForRevokeCMD forSucess:nil];
        else
            DDLogWarn(@"【消息撤回】发送撤回指令，无效的chatType=%d", chatType);

        // 本端乐观更新：先本地标记为撤回态，后续收到 msg_type=91 或 QoS ACK 时再做二次对齐（已在 MessageRevokingManager 做幂等处理）
        [mgr fireRevokeSucess:fpForRevokeCMD messageBeRevoke:messageWillBeRevoke];
        // 立即关闭进度框，避免长时间显示“撤回中”
        [self hideMessageRevokingProgess:YES fp:nil];
    }
    else{
        DDLogWarn(@"【消息撤回】撤回指令发出前MessageBeRevoke.create后，messageBeRevoke==null!");
        [BasicTool showAlertWarn:@"无法撤回，请重启应用后再试！" parent:self];
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 消息”删除”功能对应的方法


// 取消发送：仅本地移除 + 取消重试，不调服务端（仅用于发送中的消息）
- (void)processMessageCancelSendImpl:(JSQMessage *)entity
{
    NSString *fp = entity.fingerPrintOfProtocal;
    NSString *forId = self.toId;
    int chatType = self.chatType;
    if ([BasicTool isStringEmpty:fp] || [BasicTool isStringEmpty:forId]) return;
    [[SendRetryManager sharedInstance] cancelRetryForFp:fp];
    RemoveResult *result = nil;
    int alrmType = -1;
    if (chatType == CHAT_TYPE_FREIDN_CHAT || chatType == CHAT_TYPE_GUEST_CHAT) {
        result = [[[IMClientManager sharedInstance] getMessagesProvider] removeMessage:forId fp:fp isDeleteLocalDatas:YES];
    } else if (chatType == CHAT_TYPE_GROUP_CHAT) {
        result = [[[IMClientManager sharedInstance] getGroupsMessagesProvider] removeMessage:forId fp:fp isDeleteLocalDatas:YES];
    } else {
        return;
    }
    if (result != nil && result.deletedSucess) {
        if (chatType == CHAT_TYPE_FREIDN_CHAT) alrmType = AMT_friendChatMessage;
        else if (chatType == CHAT_TYPE_GUEST_CHAT) alrmType = AMT_guestChatMessage;
        else if (chatType == CHAT_TYPE_GROUP_CHAT) alrmType = AMT_groupChatMessage;
        if (result.last) {
            JSQMessage *previousDeletedMessage = result.previousDeletedMessage;
            AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
            NSString *newAlarmContent = previousDeletedMessage != nil ? [JSQMessage parseMessageContentPreview:previousDeletedMessage.text withType:previousDeletedMessage.msgType] : @"";
            [ap updateAlarmContentAndTime:alrmType dataId:forId newContent:newAlarmContent newDate:(previousDeletedMessage == nil ? nil : [TimeTool getIOSDefaultDate]) needUpdateSqlite:YES];
        } else {
            JSQMessage *deletedMessage = result.deletedMessage;
            JSQMessage *behindDeletedMessage = result.behindDeletedMessage;
            if (deletedMessage.showTopTime && behindDeletedMessage != nil) {
                behindDeletedMessage.showTopTime = YES;
                [self rb_invalidateChattingListLayoutCache];
                [self.collectionView reloadData];
            }
        }
    }
}

// 消息"删除"功能实现（有确认对话框）。
- (void) processMessageDelete:(int)chatType fp:(NSString *)fpForMessage forId:(NSString *)forId
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    [BasicTool areYouSureAlert:NSLocalizedString(@"general_are_u_sure", @"") content:@"此操作将彻底删除消息，无法恢复，确认要这样做吗？" okBtnTitle:NSLocalizedString(@"general_ok", @"") cancelBtnTitle:NSLocalizedString(@"general_cancel", @"") parent:self okHandler:^(UIAlertAction * _Nullable action) {
        [safeSelf processMessageDeleteImpl:chatType fp:fpForMessage forId:forId];
    } cancelHandler:nil okActionStyle:UIAlertActionStyleDestructive cencelActionStyle:UIAlertActionStyleCancel];
}

/**
 * 消息"删除"功能实现。
 * <p>
 * 【v11.x 变更】先调用服务端 1008-4-23 软删除接口，成功后再执行本地删除。
 *
 * @param chatType 聊天类型，see {@link ChatType}
 * @param fpForMessage  被删除消息的指纹码
 * @param forId 群聊时这表示群id，否则表示好友或陌生人uid
 */
- (void) processMessageDeleteImpl:(int)chatType fp:(NSString *)fpForMessage forId:(NSString *)forId
{
    NSString *luid = self.senderId;
    if ([BasicTool isStringEmpty:luid] || [BasicTool isStringEmpty:fpForMessage]) {
        DDLogWarn(@"【消息删除】luid 或 fpForMessage 为空，无法继续！");
        return;
    }

    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;

    // ① 先调用服务端软删除接口 1008-4-23
    [[HttpRestHelper sharedInstance] submitDeleteSingleMessageToServer:luid
                                                         fpForMessage:fpForMessage
                                                             complete:^(BOOL sucess, NSString *resultCode) {
        // 不论服务端是否成功都继续执行本地删除（保证本地体验一致）
        if (!sucess) {
            DDLogWarn(@"【消息删除】服务端软删除接口调用失败，仍继续本地删除。fp=%@", fpForMessage);
        }

        // ② 回到主线程执行本地删除
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(safeSelf) strongSelf = safeSelf;
            if (!strongSelf) return;

            RemoveResult *result = nil;

            // 从内存中的消息列表中删除该消息对象（进而会通知ui层刷新聊天界面中的显示）
            int alrmType = -1;
            if(chatType == CHAT_TYPE_FREIDN_CHAT || chatType == CHAT_TYPE_GUEST_CHAT){
                result = [[[IMClientManager sharedInstance] getMessagesProvider] removeMessage:forId fp:fpForMessage isDeleteLocalDatas:YES];
            }
            else if(chatType == CHAT_TYPE_GROUP_CHAT){
                result = [[[IMClientManager sharedInstance] getGroupsMessagesProvider] removeMessage:forId fp:fpForMessage isDeleteLocalDatas:YES];
            }
            else{
                DDLogWarn(@"【消息删除】无效的chatType=%d，doMessageDelete无法继续！", chatType);
                return;
            }

            // 如果被删除的是最后一条消息，则要同时更新首页"消息"列表中的内容显示
            if(result != nil){
                if(result.deletedSucess){

                    if(chatType == CHAT_TYPE_FREIDN_CHAT){
                        alrmType = AMT_friendChatMessage;
                    }
                    else if(chatType == CHAT_TYPE_GUEST_CHAT){
                        alrmType = AMT_guestChatMessage;
                    }
                    else if(chatType == CHAT_TYPE_GROUP_CHAT){
                        alrmType = AMT_groupChatMessage;
                    }

                    DDLogInfo(@"【消息删除】》》》》》》》》》》》》result.last=%d", result.last);

                    if(result.last){
                        JSQMessage *previousDeletedMessage = result.previousDeletedMessage;
                        AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];

                        NSString *newAlarmContent = @"";
                        if(previousDeletedMessage != nil){
                            newAlarmContent = [JSQMessage parseMessageContentPreview:previousDeletedMessage.text withType:previousDeletedMessage.msgType];
                        }
                        [ap updateAlarmContentAndTime:alrmType dataId:forId newContent:newAlarmContent newDate:(previousDeletedMessage==nil? nil : [TimeTool getIOSDefaultDate]) needUpdateSqlite:YES];
                    }
                    else{
                        JSQMessage *deletedMessage = result.deletedMessage;
                        JSQMessage *behindDeletedMessage = result.behindDeletedMessage;
                        if(deletedMessage.showTopTime) {
                            if (behindDeletedMessage != nil){
                                behindDeletedMessage.showTopTime = YES;
                                [strongSelf rb_invalidateChattingListLayoutCache];
                                [strongSelf.collectionView reloadData];
                            }
                        }
                    }
                }
            }
        });
    } hudParentView:nil];
}

@end
