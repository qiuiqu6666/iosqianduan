//telegram @wz662
//
//  Quote4InputWrapper.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2024/3/14.
//  Copyright © 2024 JackJiang. All rights reserved.
//

#import "Quote4InputWrapper.h"
#import "GroupsProvider.h"
#import "IMClientManager.h"
#import "BasicTool.h"
#import "EmojiUtil.h"
#import "JSQMessagesCollectionViewFlowLayoutInvalidationContext.h"
#import "ChatRootViewController.h"
#import "TGInputBar.h"

@interface Quote4InputWrapper ()

/** 寄生的主类AlarmsViewController的引用 */
@property (nonatomic, strong) JSQMessagesViewController *messagesViewController;

/** 消息引用文本内容显示组件 */
@property (nonatomic, strong) UILabel *quoteContentView;
/** 消息引用文本内容取消按钮 */
@property (nonatomic, strong) UIImageView *quoteCancelView;

/** 消息引用的显示组件父view的高度约束（当不需要显示此组件时，本值设为0即可）.  */
@property (nonatomic, strong) NSLayoutConstraint *quoteContainerHeightConstraint;
/** 消息引用的显示组件父view的底部空白约束（当不需要显示消息引用组件时，本值设为0即可）. */
@property (nonatomic, strong) NSLayoutConstraint *quoteContainerBottomGapConstraint;

@property (nonatomic, strong) JSQMessage *beQuoteMessage;

@end


@implementation Quote4InputWrapper

- (id)initWith:(JSQMessagesViewController *)messagesViewController {
    if(self = [super init]) {
        self.messagesViewController = messagesViewController;
        [self initViews];
        [self initListeners];
    }
    return self;
}

- (void)initViews {
    self.quoteContentView = self.messagesViewController.inputToolbar.contentView.quoteContentView;
    self.quoteCancelView = self.messagesViewController.inputToolbar.contentView.quoteCancelView;
    self.quoteContainerHeightConstraint = self.messagesViewController.inputToolbar.contentView.quoteContainerHeightConstraint;
    self.quoteContainerBottomGapConstraint = self.messagesViewController.inputToolbar.contentView.quoteContainerBottomGapConstraint;
}

- (void)initListeners {
    // 为清空图标增加点击事件处理
    [BasicTool addFingerClick:self.quoteCancelView action:@selector(cancelQuote:) target:self];
}

- (void)doQuote:(int)chatType to:(NSString *)toId with:(JSQMessage *)beQuoteMessage {
    if(beQuoteMessage != nil) {
        self.beQuoteMessage = beQuoteMessage;

        NSString *messageContentForShow = @"";
        if(beQuoteMessage.text != nil) {
            // 消息内容的显示（比如图片消息会显示"[图片]"这样的字串）
            messageContentForShow = [JSQMessage parseMessageContentPreview:beQuoteMessage.text withType:beQuoteMessage.msgType];;
        } else {
            messageContentForShow = @"[未知内容]";
        }

        NSString *sendderNick = [Quote4InputWrapper getQuoteNick:chatType to:toId quoteUid:beQuoteMessage.senderId quoteNick:beQuoteMessage.senderDisplayName];

        // TG 输入栏：引用预览做在白条内（Telegram 风格），不走原 inputToolbar 下方引用条
        if ([self.messagesViewController isKindOfClass:[ChatRootViewController class]]) {
            ChatRootViewController *crc = (ChatRootViewController *)self.messagesViewController;
            if (crc.tgInputBar != nil) {
                [crc.tgInputBar setReplyPreviewVisible:YES senderNick:sendderNick snippetPlain:messageContentForShow];
                [crc jsq_updateCollectionViewInsets];
                // 引用后直接进入输入：弹出系统键盘并显示光标，无需再点输入框（延后一帧，等回复条高度与 inset 布局稳定）
                __weak typeof(crc) weakCrc = crc;
                dispatch_async(dispatch_get_main_queue(), ^{
                    ChatRootViewController *s = weakCrc;
                    if (!s || !s.tgInputBar) return;
                    UITextView *tv = s.tgInputBar.textView;
                    tv.inputView = nil;
                    [tv reloadInputViews];
                    if (![tv isFirstResponder]) {
                        [tv becomeFirstResponder];
                    }
                });
                return;
            }
        }

        [self setQuoteContainerVisible:YES];

        NSString *toShow = [NSString stringWithFormat:@"%@%@", (![BasicTool isStringEmpty: sendderNick] ? [NSString stringWithFormat:@"%@：", sendderNick] : @""), messageContentForShow];

        // 含有emoji表情图片的富文本支持 by Freeman
        if(![BasicTool isStringEmpty:toShow]){
            // 【有效代码】：参考聊天气泡中显示表情的办法，表情图标显示大小正常
            NSDictionary *attributes = @{NSFontAttributeName:self.quoteContentView.font};

            self.quoteContentView.attributedText = [EmojiUtil replaceEmojiWithPlanString:toShow attributes:attributes];
        } else {
            self.quoteContentView.text = toShow;
        }
    } else {
        [BasicTool showAlertWarn:@"无效的数据！" parent:self.messagesViewController];
    }
}

- (void)cancelQuote:(UITapGestureRecognizer *)gestureRecognizer {
    if ([self.messagesViewController isKindOfClass:[ChatRootViewController class]]) {
        ChatRootViewController *crc = (ChatRootViewController *)self.messagesViewController;
        if (crc.tgInputBar != nil) {
            [crc.tgInputBar setReplyPreviewVisible:NO senderNick:nil snippetPlain:nil];
            self.beQuoteMessage = nil;
            [crc jsq_updateCollectionViewInsets];
            return;
        }
    }

    [self setQuoteContainerVisible:NO];
    self.quoteContentView.text = nil;
    self.beQuoteMessage = nil;
        
//    [self.messagesViewController.inputToolbar setNeedsUpdateConstraints];
    
//    [self.messagesViewController.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
////    [self.messagesViewController.view layoutIfNeeded];
//    [self.messagesViewController.collectionView.collectionViewLayout invalidateLayout];
    
//    [self.messagesViewController jsq_updateCollectionViewInsets];//!!!!!!!!!!!
//    [self.messagesViewController.collectionView setNeedsUpdateConstraints];
//    [self.messagesViewController.collectionView layoutIfNeeded];
}

- (void)setQuoteContainerVisible:(BOOL)visible {
    // 消息引用ui正处于显示中，即表示当前已经存在了引用内容
    BOOL isQuoting = (self.quoteContainerHeightConstraint.constant > 0);
    UIScrollView *scrollView = self.messagesViewController.collectionView;
    [self.messagesViewController.view layoutIfNeeded];
    CGFloat previousDistanceFromBottom = MAX((scrollView.contentSize.height + scrollView.contentInset.bottom) - (scrollView.contentOffset.y + CGRectGetHeight(scrollView.bounds)), 0.0f);
    BOOL wasPinnedToBottom = (previousDistanceFromBottom <= 2.0f);
        
    self.quoteContainerHeightConstraint.constant = (visible ? kJSQMessagesToolbarQuoteContainerHeightDefault : 0);
    self.quoteContainerBottomGapConstraint.constant = (visible ? kJSQMessagesToolbarQuoteContainerBottomGapDefault : 0);
    
    if(visible) {
        if(!isQuoting) {
            self.messagesViewController.toolbarHeightConstraint.constant = (self.messagesViewController.toolbarHeightConstraint.constant + kJSQMessagesToolbarQuoteContainerHeightDefault + kJSQMessagesToolbarQuoteContainerBottomGapDefault);
        }
    } else {
        if(isQuoting) {
            self.messagesViewController.toolbarHeightConstraint.constant = (self.messagesViewController.toolbarHeightConstraint.constant - kJSQMessagesToolbarQuoteContainerHeightDefault - kJSQMessagesToolbarQuoteContainerBottomGapDefault);
        }
    }
    
    // 在引用条显隐前后保持用户与底部的相对视口，避免发完引用后列表需要再刷新一次才“归位”。
    [self.messagesViewController.view layoutIfNeeded];
    [self.messagesViewController jsq_updateCollectionViewInsets];
    [self.messagesViewController.view layoutIfNeeded];
    CGFloat minOffsetY = -scrollView.contentInset.top;
    CGFloat maxOffsetY = MAX(minOffsetY, scrollView.contentSize.height + scrollView.contentInset.bottom - CGRectGetHeight(scrollView.bounds));
    CGFloat targetOffsetY = wasPinnedToBottom ? maxOffsetY : (maxOffsetY - previousDistanceFromBottom);
    targetOffsetY = MIN(MAX(targetOffsetY, minOffsetY), maxOffsetY);
    [scrollView setContentOffset:CGPointMake(scrollView.contentOffset.x, targetOffsetY) animated:NO];

//    [self.messagesViewController.inputToolbar setNeedsUpdateConstraints];
//    [self.messagesViewController.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
////        [self.messagesViewController.view layoutIfNeeded];
//    [self.messagesViewController.collectionView.collectionViewLayout invalidateLayout];
}


//- (void)cancelQuote:(UITapGestureRecognizer *)gestureRecognizer{
//    [self setQuoteContainerVisible:NO];
//    self.quoteContentView.text = nil;
//    self.beQuoteMessage = nil;
//}

- (QuoteMeta *)getQuoteMeta:(int)chatType with:(NSString *)toId {
    QuoteMeta *quoteMeta = nil;
    if(self.beQuoteMessage != nil) {
        quoteMeta = [[QuoteMeta alloc] init];
        
        // 如果是群聊，则存放的是被引用群聊消息被服务端扩散写前的原始指纹码（也就是群成员收到的此条群聊消息的父指纹码）
        quoteMeta.quote_fp = (chatType == CHAT_TYPE_GROUP_CHAT
                              ? self.beQuoteMessage.fingerPrintOfParent : self.beQuoteMessage.fingerPrintOfProtocal);
        quoteMeta.quote_sender_uid = self.beQuoteMessage.senderId;
        
        NSString *sendderNick = self.beQuoteMessage.senderDisplayName;//getQuoteNick(parentActivity, chatType, toId, beQuoteMessage.getSenderId(), beQuoteMessage.getSenderDisplayName());
        if([self.beQuoteMessage  isOutgoing]) {
            UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
            if (localUser != nil)
                sendderNick = localUser.nickname;
        }
        
        quoteMeta.quote_sender_nick = sendderNick;
        quoteMeta.quote_content = self.beQuoteMessage.text;
        quoteMeta.quote_type = self.beQuoteMessage.msgType;
    }
    return quoteMeta;
}

+ (NSString *)getQuoteNick:(int)chatType to:(NSString *)toId quoteUid:(NSString *)quoteSenderId quoteNick:(NSString *)quoteSenderNick {
    if(quoteSenderId !=  nil) {
        @try {
            NSString *sendderNick = quoteSenderNick;
            // 如果是"我"发出的消息
            if ([JSQMessage isOutgoing:quoteSenderId]) {
                if (chatType == CHAT_TYPE_GROUP_CHAT) {
                    sendderNick = [GroupsProvider getMyNickNameInGroupEx:toId];
                } else {
                    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
                    if (localUser != nil)
                        sendderNick = localUser.nickname;
                }
            } else {
                // 优先尝试从好友数据中读取好友信息
                UserEntity *friendRee = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:quoteSenderId];
                // 是好友
                if(friendRee != nil) {
                    sendderNick = [friendRee getNickNameWithRemark];
                }
            }
            
            return sendderNick;
        } @catch (NSException *exception) {
            NSLog(@"%@",exception);
        }
    }
    return nil;
}

@end
