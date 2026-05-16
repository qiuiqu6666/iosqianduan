//
//  ChatRootViewController+Send.m
//  发送：文本/图片/语音/视频/文件/名片/位置/收藏等。
//

#import "ChatRootViewController+Send.h"
#import "ChatRootViewController+MessageList.h"
#import "Quote4InputWrapper.h"
#import "SendImageHelper.h"
#import "SendVoiceHelper.h"
#import "SendFileHelper.h"
#import "SendShortVideoHelper.h"
#import "ReceivedShortVideoHelper.h"
#import "TMessageHelper.h"
#import "GMessageHelper.h"
#import "ChatDataHelper.h"
#import "GChatDataHelper.h"
#import "TChatDataHelper.h"
#import "LocationUtils.h"
#import "FileTool.h"
#import "BasicTool.h"
#import "PromtHelper.h"
#import "MessageHelper.h"
#import "AppDelegate.h"
#import "ViewControllerFactory.h"
#import "FavPickerViewController.h"
#import "ContactMeta.h"
#import "LocationMeta.h"
#import "GetLocationViewController.h"
#import "IQAudioRecorderViewController.h"
#import "ShortVideoRecordViewController.h"
#import "GroupEntity.h"
#import "TargetEntity.h"
#import "QRCodeScheme.h"
#import "FileMeta.h"
#import "rbFileMediaItem.h"
#import "rbContactMediaItem.h"
#import "rbLocationMediaItem.h"
#import "FileDownloadHelper.h"
#import "JSQMessage.h"
#import "JSQPhotoMediaItem.h"
#import "SDImageCache.h"
#import "UIImageView+WebCache.h"
#import "IMClientManager.h"
#import "UserEntity.h"
#import "MessagesProvider.h"
#import "AlarmsProvider.h"
#import "AlarmType.h"
#import "BigFileUploadManager.h"
#import "ReceivedFileHelper.h"
#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>

// 与主文件收藏同步类型一致，供 submitFavoriteToServerWithContent 使用
static const int kFavTypeText = 0, kFavTypeImage = 1, kFavTypeVoice = 2, kFavTypeVideo = 3, kFavTypeFile = 4, kFavTypeLocation = 5;
static const NSUInteger kRBMaxOutgoingTextChunkLength = 2048;

@interface ChatRootViewController (RBShortVideoForwardBridge)
- (void)reSendShortVideoMessage:(BOOL)forForward toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName filePath:(NSString *)filePath md5:(NSString *)fileMD5 quoteMeta:(QuoteMeta *)quoteMeta;
@end

static inline double RBChatSendTraceNowMs(void)
{
    return CFAbsoluteTimeGetCurrent() * 1000.0;
}

#define RBForwardHexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static NSString *RBForwardPreviewTextForMessage(JSQMessage *message) {
    if (message == nil) return @"";
    switch (message.msgType) {
        case TM_TYPE_TEXT:
            return (message.text.length > 0 ? message.text : @"(空文本)");
        case TM_TYPE_IMAGE:
            return @"";
        case TM_TYPE_VOICE:
            return @"语音消息";
        case TM_TYPE_SHORTVIDEO:
            return @"";
        case TM_TYPE_FILE: {
            NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(message.text);
            if (jsonUse.length == 0) jsonUse = message.text ?: @"";
            FileMeta *fm = [FileMeta fromJSON:jsonUse];
            return (fm.fileName.length > 0 ? fm.fileName : @"文件消息");
        }
        case TM_TYPE_LOCATION:
            return @"位置消息";
        case TM_TYPE_CONTACT:
            return @"个人名片";
        default:
            return (message.text.length > 0 ? message.text : @"消息内容");
    }
}

@interface RBForwardConfirmSheetViewController : UIViewController
@property (nonatomic, strong) NSArray<TargetEntity *> *targets;
@property (nonatomic, strong) NSArray<JSQMessage *> *messages;
@property (nonatomic, copy) dispatch_block_t confirmBlock;
@property (nonatomic, strong) UIControl *maskView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *targetAvatarView;
@property (nonatomic, strong) UILabel *targetNameLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) NSLayoutConstraint *previewHeightConstraint;
@end

@implementation RBForwardConfirmSheetViewController

- (instancetype)initWithTargets:(NSArray<TargetEntity *> *)targets
                       messages:(NSArray<JSQMessage *> *)messages
                   confirmBlock:(dispatch_block_t)confirmBlock
{
    self = [super init];
    if (self) {
        self.targets = targets ?: @[];
        self.messages = messages ?: @[];
        self.confirmBlock = confirmBlock;
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    UIControl *mask = [[UIControl alloc] init];
    mask.translatesAutoresizingMaskIntoConstraints = NO;
    mask.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.32];
    mask.alpha = 0.0;
    [mask addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:mask];
    self.maskView = mask;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 20.0f;
    if (@available(iOS 11.0, *)) {
        card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    }
    card.clipsToBounds = YES;
    [self.view addSubview:card];
    self.cardView = card;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    titleLabel.textColor = RBForwardHexColor(0x111111);
    titleLabel.text = @"发送给";
    [card addSubview:titleLabel];

    UIImageView *avatarView = [[UIImageView alloc] init];
    avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarView.backgroundColor = RBForwardHexColor(0xEDEEF2);
    avatarView.layer.cornerRadius = 22.f;
    avatarView.clipsToBounds = YES;
    avatarView.contentMode = UIViewContentModeScaleAspectFill;
    avatarView.image = [UIImage imageNamed:@"default_avatar_60"];
    [card addSubview:avatarView];
    self.targetAvatarView = avatarView;

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    nameLabel.textColor = RBForwardHexColor(0x111111);
    [card addSubview:nameLabel];
    self.targetNameLabel = nameLabel;

    UILabel *chevronLabel = [[UILabel alloc] init];
    chevronLabel.translatesAutoresizingMaskIntoConstraints = NO;
    chevronLabel.font = [UIFont systemFontOfSize:24];
    chevronLabel.textColor = RBForwardHexColor(0xA0A4AB);
    chevronLabel.text = @"›";
    [card addSubview:chevronLabel];

    UIView *contentPanel = [[UIView alloc] init];
    contentPanel.translatesAutoresizingMaskIntoConstraints = NO;
    contentPanel.backgroundColor = [UIColor whiteColor];
    contentPanel.layer.cornerRadius = 14.f;
    [card addSubview:contentPanel];

    UILabel *contentLabel = [[UILabel alloc] init];
    contentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    contentLabel.font = [UIFont systemFontOfSize:16];
    contentLabel.textColor = RBForwardHexColor(0x1F2329);
    contentLabel.numberOfLines = 6;
    [contentPanel addSubview:contentLabel];
    self.contentLabel = contentLabel;

    UIImageView *previewImageView = [[UIImageView alloc] init];
    previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
    previewImageView.contentMode = UIViewContentModeScaleAspectFill;
    previewImageView.layer.cornerRadius = 10.f;
    previewImageView.clipsToBounds = YES;
    previewImageView.hidden = YES;
    [contentPanel addSubview:previewImageView];
    self.previewImageView = previewImageView;

    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    cancelButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    [cancelButton setTitleColor:RBForwardHexColor(0x111111) forState:UIControlStateNormal];
    cancelButton.backgroundColor = RBForwardHexColor(0xEFEFEF);
    cancelButton.layer.cornerRadius = 14.f;
    cancelButton.clipsToBounds = YES;
    [cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:cancelButton];

    UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    sendButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [sendButton setTitle:@"发送" forState:UIControlStateNormal];
    [sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sendButton.backgroundColor = RBForwardHexColor(0x07C160);
    sendButton.layer.cornerRadius = 14.f;
    sendButton.clipsToBounds = YES;
    [sendButton addTarget:self action:@selector(confirmTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:sendButton];

    self.previewHeightConstraint = [previewImageView.heightAnchor constraintEqualToConstant:0];

    [NSLayoutConstraint activateConstraints:@[
        [mask.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [mask.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [mask.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [mask.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],

        [avatarView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:14],
        [avatarView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [avatarView.widthAnchor constraintEqualToConstant:44],
        [avatarView.heightAnchor constraintEqualToConstant:44],

        [nameLabel.centerYAnchor constraintEqualToAnchor:avatarView.centerYAnchor],
        [nameLabel.leadingAnchor constraintEqualToAnchor:avatarView.trailingAnchor constant:14],
        [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevronLabel.leadingAnchor constant:-10],

        [chevronLabel.centerYAnchor constraintEqualToAnchor:avatarView.centerYAnchor],
        [chevronLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],

        [contentPanel.topAnchor constraintEqualToAnchor:avatarView.bottomAnchor constant:14],
        [contentPanel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [contentPanel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],

        [contentLabel.topAnchor constraintEqualToAnchor:contentPanel.topAnchor constant:20],
        [contentLabel.leadingAnchor constraintEqualToAnchor:contentPanel.leadingAnchor constant:14],
        [contentLabel.trailingAnchor constraintEqualToAnchor:contentPanel.trailingAnchor constant:-14],

        [previewImageView.topAnchor constraintEqualToAnchor:contentLabel.bottomAnchor constant:14],
        [previewImageView.leadingAnchor constraintEqualToAnchor:contentLabel.leadingAnchor],
        [previewImageView.trailingAnchor constraintEqualToAnchor:contentLabel.trailingAnchor],
        self.previewHeightConstraint,
        [previewImageView.bottomAnchor constraintEqualToAnchor:contentPanel.bottomAnchor constant:-20],

        [cancelButton.topAnchor constraintEqualToAnchor:contentPanel.bottomAnchor constant:28],
        [cancelButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [cancelButton.heightAnchor constraintEqualToConstant:56],
        [cancelButton.bottomAnchor constraintEqualToAnchor:card.safeAreaLayoutGuide.bottomAnchor constant:-20],

        [sendButton.topAnchor constraintEqualToAnchor:cancelButton.topAnchor],
        [sendButton.leadingAnchor constraintEqualToAnchor:cancelButton.trailingAnchor constant:18],
        [sendButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [sendButton.widthAnchor constraintEqualToAnchor:cancelButton.widthAnchor],
        [sendButton.heightAnchor constraintEqualToAnchor:cancelButton.heightAnchor],
        [sendButton.bottomAnchor constraintEqualToAnchor:cancelButton.bottomAnchor]
    ]];

    [self refreshSheetContent];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.view layoutIfNeeded];
    self.cardView.transform = CGAffineTransformMakeTranslation(0.0, CGRectGetHeight(self.cardView.bounds) + self.view.safeAreaInsets.bottom + 20.0);
    [UIView animateWithDuration:0.22 animations:^{
        self.maskView.alpha = 1.0;
        self.cardView.transform = CGAffineTransformIdentity;
    }];
}

- (void)refreshSheetContent
{
    if (self.targets.count == 1) {
        TargetEntity *target = self.targets.firstObject;
        self.targetNameLabel.text = target.targetName.length > 0 ? target.targetName : @"当前聊天";
        self.targetAvatarView.image = [UIImage imageNamed:@"default_avatar_60"];
        if (target.targetChatType == CHAT_TYPE_GROUP_CHAT) {
            __weak typeof(self) weakSelf = self;
            [FileDownloadHelper loadGroupAvatar:target.targetId logTag:@"ForwardConfirm-GroupAvatar" complete:^(BOOL sucess, UIImage *img) {
                if (sucess && img != nil) weakSelf.targetAvatarView.image = img;
            }];
        } else {
            __weak typeof(self) weakSelf = self;
            [FileDownloadHelper loadUserAvatarWithUID:target.targetId logTag:@"ForwardConfirm-UserAvatar" complete:^(BOOL sucess, UIImage *img) {
                if (sucess && img != nil) weakSelf.targetAvatarView.image = img;
            } donotLoadFromDisk:NO];
        }
    } else {
        self.targetNameLabel.text = [NSString stringWithFormat:@"已选择 %lu 个目标", (unsigned long)self.targets.count];
        self.targetAvatarView.image = [UIImage imageNamed:@"default_avatar_60"];
    }

    JSQMessage *firstMessage = self.messages.firstObject;
    NSString *contentText = nil;
    if (self.messages.count > 1) {
        contentText = [NSString stringWithFormat:@"共 %lu 条消息", (unsigned long)self.messages.count];
    } else {
        contentText = RBForwardPreviewTextForMessage(firstMessage);
    }
    self.contentLabel.text = contentText ?: @"";
    self.contentLabel.hidden = (self.contentLabel.text.length == 0);
    self.previewImageView.hidden = YES;
    self.previewImageView.image = nil;
    self.previewHeightConstraint.constant = 0;

    if (self.messages.count == 1 && firstMessage != nil) {
        if (firstMessage.msgType == TM_TYPE_IMAGE) {
            NSString *fileName = firstMessage.text ?: @"";
            if (fileName.length > 0) {
                NSString *previewName = [NSString stringWithFormat:@"pv_%@", fileName];
                NSString *thumbURL = [SendImageHelper getImageDownloadURL:previewName dump:NO];
                if (thumbURL.length > 0) {
                    self.previewImageView.hidden = NO;
                    self.previewHeightConstraint.constant = 190;
                    [self.previewImageView sd_setImageWithURL:[NSURL URLWithString:thumbURL] placeholderImage:nil];
                }
            }
        } else if (firstMessage.msgType == TM_TYPE_SHORTVIDEO) {
            NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(firstMessage.text);
            if (jsonUse.length == 0) jsonUse = firstMessage.text ?: @"";
            FileMeta *fm = [FileMeta fromJSON:jsonUse];
            if (fm.fileName.length > 0 && fm.fileMd5.length > 0) {
                NSString *thumbName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:fm.fileName];
                NSString *thumbURL = [ReceivedShortVideoHelper getShortVideoThumbDownloadURL:thumbName videofileMd5:fm.fileMd5];
                self.previewImageView.hidden = NO;
                self.previewHeightConstraint.constant = 190;
                self.previewImageView.image = [UIImage imageNamed:@"default_short_video_thumb"];
                __weak typeof(self) weakSelf = self;
                [FileDownloadHelper loadChattingShortVideoPreviewImgWithURL:thumbURL logTag:@"ForwardConfirm-ShortVideo" complete:^(BOOL sucess, UIImage *img) {
                    if (sucess && img != nil) weakSelf.previewImageView.image = img;
                }];
            }
        }
    }
}

- (void)dismissSheetAnimatedWithCompletion:(dispatch_block_t)completion
{
    void (^finish)(void) = ^{
        [self dismissViewControllerAnimated:NO completion:completion];
    };
    [UIView animateWithDuration:0.18 animations:^{
        self.maskView.alpha = 0.0;
        self.cardView.transform = CGAffineTransformMakeTranslation(0.0, CGRectGetHeight(self.cardView.bounds) + self.view.safeAreaInsets.bottom + 20.0);
    } completion:^(BOOL finished) {
        finish();
    }];
}

- (void)cancelTapped
{
    [self dismissSheetAnimatedWithCompletion:nil];
}

- (void)confirmTapped
{
    dispatch_block_t block = self.confirmBlock;
    [self dismissSheetAnimatedWithCompletion:^{
        if (block) block();
    }];
}

@end

@interface ChatRootViewController (SendPrivate)
@property (nonatomic, strong) Quote4InputWrapper *quote4InputWrapper;
@property (nonatomic, strong) AtModel *atCache;
- (void)clearDraft;
- (void)sendPlainTextMessage:(NSString *)text forSucess:(void (^)(id, id))block;
- (void)sendPlainTextMessage:(NSString *)message toChatType:(int)chatType toId:(NSString *)toId quoteMeta:(QuoteMeta *)quoteMeta forSucess:(ObserverCompletion)sucessObs;
- (void)finishSendingMessageAnimated:(BOOL)animated;
- (void)rb_refreshItemAtIndexPath:(NSIndexPath *)indexPath;
- (NSString *)jsq_currentlyComposedMessageText;
- (UITextView *)rb_currentComposerTextView;
- (void)gotoVoiceRecord;
- (void)didPressRightButton:(UIButton *)sender withMessageText:(NSString *)text senderId:(NSString *)senderId senderDisplayName:(NSString *)senderDisplayName date:(NSDate *)date;
- (void)submitFavoriteToServerWithMessage:(JSQMessage *)cme sourceChatType:(int)sourceChatType onSyncSuccess:(void (^)(void))onSyncSuccess onComplete:(void (^)(BOOL success))onComplete;
- (void)submitFavoriteToServerWithContent:(NSString *)content favType:(int)favType sourceChatType:(int)sourceChatType onSyncSuccess:(void (^)(void))onSyncSuccess;
- (void)refresh10001FavoritesListIfNeeded;
- (void)forward:(JSQMessage *)cme toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forSucess:(void (^)(id, id))sucessObs;
- (void)processAtChooseCompleteImpl:(TargetEntity *)ue needInsertAitInText:(BOOL)needInsertAitInText;
- (void)reSendImageMessage:(BOOL)forForward toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName fileName:(NSString *)imageFileName quoteMeta:(QuoteMeta *)quoteMeta;
- (void)reSendVoiceMessage:(BOOL)forForward toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName fileName:(NSString *)voiceFileName quoteMeta:(QuoteMeta *)quoteMeta;
- (void)reSendLocationMessage:(BOOL)forForward toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName lm:(LocationMeta *)meta quoteMeta:(QuoteMeta *)quoteMeta;
- (void)rb_updateLocalConversationAlarmForOutgoingRawContent:(NSString *)rawContent msgType:(int)msgType chatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName;
- (void)rb_presentForwardConfirmAfterTargetPickerDismissWithTargets:(NSArray<TargetEntity *> *)targets messages:(NSArray<JSQMessage *> *)messages;
- (void)rb_executeForwardMessages:(NSArray<JSQMessage *> *)messages toTargets:(NSArray<TargetEntity *> *)targets;
@end

@implementation ChatRootViewController (Send)

static BOOL rb_shouldSuppressSendFailureToastCode(NSInteger code)
{
    return (code == RBLocalSendCodeFriendshipRequired
            || code == MT70_OF_FRIENDSHIP_REQUIRED_SEND_FAIL_HINT);
}

static NSArray<NSString *> *rb_splitOutgoingTextIntoChunks(NSString *text, NSUInteger maxChunkLength)
{
    if (text.length == 0 || maxChunkLength == 0) return @[];

    NSMutableArray<NSString *> *chunks = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    __block NSUInteger currentCount = 0;

    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
        if (substring.length == 0) return;
        if (currentCount >= maxChunkLength) {
            if (current.length > 0) {
                [chunks addObject:[current copy]];
            }
            [current setString:@""];
            currentCount = 0;
        }
        [current appendString:substring];
        currentCount += 1;
        if (currentCount >= maxChunkLength) {
            [chunks addObject:[current copy]];
            [current setString:@""];
            currentCount = 0;
        }
    }];

    if (current.length > 0) {
        [chunks addObject:[current copy]];
    }
    return [chunks copy];
}

- (void)rb_updateLocalConversationAlarmForOutgoingRawContent:(NSString *)rawContent msgType:(int)msgType chatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName
{
    if (toId.length == 0) return;
    int alarmType = -1;
    switch (chatType) {
        case CHAT_TYPE_FREIDN_CHAT:
            alarmType = AMT_friendChatMessage;
            [AlarmsProvider addSingleChatMsgAlarmForLocal:toId
                                               friendName:toName
                                                  withMsg:(rawContent ?: @"")
                                                  andType:msgType
                                            withAlarmType:AMT_friendChatMessage];
            break;
        case CHAT_TYPE_GUEST_CHAT:
            alarmType = AMT_guestChatMessage;
            [AlarmsProvider addSingleChatMsgAlarmForLocal:toId
                                               friendName:toName
                                                  withMsg:(rawContent ?: @"")
                                                  andType:msgType
                                            withAlarmType:AMT_guestChatMessage];
            break;
        case CHAT_TYPE_GROUP_CHAT:
            alarmType = AMT_groupChatMessage;
            [AlarmsProvider addAGroupChatMsgAlarmForLocal:msgType gid:toId gname:toName msg:(rawContent ?: @"")];
            break;
        default:
            break;
    }
}

//---------------------------------------------------------------------------------------------------
#pragma mark - JSQMessagesViewController method overrides

/**
 * 消息输入框上触发的软键盘“Send”按钮事件。
 * @text The message text.
 */
- (void)didPressSendButtonInKeybord:(NSString *)text
{
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    if(text != nil && [text length] > 0)
    {
        DDLogInfo(@"[SendTrace][InputSendPressed] t=%.3f textLen=%lu chatType=%d toId=%@",
                  RBChatSendTraceNowMs(),
                  (unsigned long)text.length,
                  self.chatType,
                  self.toId ?: @"-");
        [JSQSystemSoundPlayer jsq_playMessageSentSound];

        NSArray<NSString *> *segments = rb_splitOutgoingTextIntoChunks(text, kRBMaxOutgoingTextChunkLength);
        if (segments.count == 0) {
            [APP showToastInfo:@"请输入要发送的文字！"];
            return;
        }
        DDLogInfo(@"[SendTrace][InputSendSegmentsReady] t=%.3f segmentCount=%lu firstLen=%lu",
                  RBChatSendTraceNowMs(),
                  (unsigned long)segments.count,
                  (unsigned long)(segments.firstObject.length));

        QuoteMeta *quoteMeta = (self.quote4InputWrapper != nil ? [self.quote4InputWrapper getQuoteMeta:self.chatType with:self.toId] : nil);
        ObserverCompletion completion = ^(id observerble, id arg1) {
            int code = [arg1 intValue];
            DDLogInfo(@"[SendTrace][InputSendNetworkCallback] t=%.3f code=%d",
                      RBChatSendTraceNowMs(),
                      code);
            if(code != 0 && !rb_shouldSuppressSendFailureToastCode(code))
                [APP showToastWarn:[NSString stringWithFormat:@"聊天消息没有成功送出，原因是：code=%d", code]];
        };

        for (NSUInteger idx = 0; idx < segments.count; idx++) {
            NSString *segment = segments[idx];
            DDLogInfo(@"[SendTrace][InputSendDispatchSegment] t=%.3f idx=%lu len=%lu",
                      RBChatSendTraceNowMs(),
                      (unsigned long)idx,
                      (unsigned long)segment.length);
            QuoteMeta *segmentQuoteMeta = (idx == 0 ? quoteMeta : nil);
            [self sendPlainTextMessage:segment
                            toChatType:self.chatType
                                  toId:self.toId
                             quoteMeta:segmentQuoteMeta
                             forSucess:completion];
        }

        DDLogInfo(@"[SendTrace][InputSendBeforeFinishSending] t=%.3f",
                  RBChatSendTraceNowMs());
        [self finishSendingMessageAnimated:YES];
        [self jsq_refreshRightBarButtonIcon];

        if(safeSelf.quote4InputWrapper != nil) {
            [safeSelf.quote4InputWrapper cancelQuote:nil];
        }
        if ( ![GroupEntity isWorldChat:safeSelf.toId] && safeSelf.atCache != nil) {
            [safeSelf.atCache clean];
        }
        [safeSelf clearDraft];
    }
    else
    {
        [APP showToastInfo:@"请输入要发送的文字！"];
    }
}

// 按钮事件：左侧为加号（更多面板），右侧为语音（见 didPressRightBarButton）
- (void)didPressLeftButton:(UIButton *)sender
{
    [self didPressRightButton:sender
             withMessageText:[self jsq_currentlyComposedMessageText]
                    senderId:self.senderId
           senderDisplayName:self.senderDisplayName
                        date:[NSDate date]];
}

- (void)messagesInputToolbar:(JSQMessagesInputToolbar *)toolbar didPressRightBarButton:(UIButton *)sender
{
    NSString *composedText = [self jsq_currentlyComposedMessageText] ?: @"";
    NSString *trimmed = [composedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length > 0) {
        DDLogInfo(@"[SendTrace][RightButtonSendTap] t=%.3f textLen=%lu",
                  RBChatSendTraceNowMs(),
                  (unsigned long)composedText.length);
        [self didPressSendButtonInKeybord:composedText];
        return;
    }

    [self gotoVoiceRecord];
}

/// 根据输入框内容刷新右侧按钮：无内容显示语音，有内容显示发送
- (void)jsq_refreshRightBarButtonIcon
{
    UIButton *rightBtn = self.inputToolbar.contentView.rightBarButtonItem;
    if (!rightBtn) return;
    [rightBtn setBackgroundImage:nil forState:UIControlStateNormal];
    [rightBtn setBackgroundImage:nil forState:UIControlStateHighlighted];
    NSString *composedText = [self jsq_currentlyComposedMessageText] ?: @"";
    BOOL hasContent = ([[composedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0);

    UIImage *targetImage = nil;
    NSString *targetTitle = nil;
    UIColor *targetTintColor = nil;
    UIColor *targetBackgroundColor = nil;

    if (hasContent) {
        UIImage *sendImg = [UIImage imageNamed:@"yyds"];
        if (sendImg) {
            targetImage = [sendImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        } else {
            UIImageSymbolConfiguration *sendCfg = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightSemibold];
            sendImg = [UIImage systemImageNamed:@"paperplane.fill" withConfiguration:sendCfg];
            if (!sendImg) {
                sendImg = [UIImage systemImageNamed:@"arrow.up" withConfiguration:sendCfg];
            }
            if (sendImg) {
                targetImage = [sendImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            } else {
                targetTitle = @"➤";
            }
        }
        targetTintColor = (targetImage != nil && [UIImage imageNamed:@"yyds"] != nil) ? nil : [UIColor whiteColor];
        targetBackgroundColor = ([UIImage imageNamed:@"yyds"] != nil) ? [UIColor clearColor] : [UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0];
    } else {
        UIImageSymbolConfiguration *micCfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
        UIImage *micImg = [UIImage imageNamed:@"yuyin"];
        if (!micImg) {
            micImg = [UIImage systemImageNamed:@"mic.fill" withConfiguration:micCfg];
        } else {
            micImg = [micImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        targetImage = micImg;
        if (@available(iOS 13.0, *)) {
            targetTintColor = [UIColor labelColor];
        } else {
            targetTintColor = [UIColor darkGrayColor];
        }
        targetBackgroundColor = [UIColor clearColor];
    }

    [rightBtn setImage:targetImage forState:UIControlStateNormal];
    [rightBtn setImage:targetImage forState:UIControlStateHighlighted];
    [rightBtn setImage:targetImage forState:UIControlStateSelected];
    [rightBtn setTitle:targetTitle forState:UIControlStateNormal];
    [rightBtn setTitle:targetTitle forState:UIControlStateHighlighted];
    [rightBtn setTitle:targetTitle forState:UIControlStateSelected];
    rightBtn.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    [rightBtn setTitleColor:targetTintColor forState:UIControlStateNormal];
    [rightBtn setTitleColor:targetTintColor forState:UIControlStateHighlighted];
    [rightBtn setTitleColor:targetTintColor forState:UIControlStateSelected];
    rightBtn.tintColor = targetTintColor;
    rightBtn.backgroundColor = targetBackgroundColor;
    BOOL usesCustomSendImage = (hasContent && [UIImage imageNamed:@"yyds"] != nil);
    rightBtn.layer.cornerRadius = usesCustomSendImage ? 0.f : (CGRectGetHeight(rightBtn.bounds) * 0.5f);
    rightBtn.clipsToBounds = !usesCustomSendImage;
}

/// 左侧「更多」：优先 Assets（chat_plus_icon / gengduo.svg），缺失时 SF Symbols
- (void)jsq_refreshLeftBarButtonIcon
{
    UIButton *leftBtn = self.inputToolbar.contentView.leftBarButtonItem;
    if (!leftBtn) return;
    [leftBtn setBackgroundImage:nil forState:UIControlStateNormal];
    [leftBtn setBackgroundImage:nil forState:UIControlStateHighlighted];
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    UIImage *plusImg = [UIImage imageNamed:@"chat_plus_icon"];
    if (!plusImg) {
        plusImg = [UIImage systemImageNamed:@"plus.circle.fill" withConfiguration:symCfg];
    } else {
        plusImg = [plusImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [leftBtn setImage:plusImg forState:UIControlStateNormal];
    [leftBtn setImage:plusImg forState:UIControlStateHighlighted];
    if (@available(iOS 13.0, *)) {
        leftBtn.tintColor = [UIColor labelColor];
    } else {
        leftBtn.tintColor = [UIColor darkGrayColor];
    }
}

//---------------------------------------------------------------------------------------------------
#pragma mark - RBImagePickerCompleteDelegate 图片消息相关的其它方法

// 实现图片选择结果代理方法：图片（来自相册的图片、来自拍照的图片）消息的发送实现方法。
- (void)processImagePickerComplete:(UIImage *)photo withTag:(NSString *)tag
{
    __weak typeof(self) safeSelf = self;
    int chatType = self.chatType;
    NSString *toId = [self.toId copy];
    NSString *toName = [self.toName copy];

    // 根治：先准备出最终文件名，再创建/入库正式图片消息，避免 tmp 状态进入消息模型和 SQLite。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *fileNameWillUpload = [SendImageHelper preparedImageForUpload:photo forPhoto:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(safeSelf) sself = safeSelf;
            if (!sself) return;
            [sself processImagePickerCompleteImpl:fileNameWillUpload
                                      toChatType:chatType
                                            toId:toId
                                          toName:toName
                                      forForward:NO
                                         withTag:tag];
        });
    });
}

// 实现多图片选择结果代理方法：从相册选择多张图片（最多9张）后逐一发送图片消息。
- (void)processMultiImagePickerComplete:(NSArray<UIImage *> *)photos withTag:(NSString *)tag
{
    if (photos == nil || photos.count == 0) {
        return;
    }
    
    DDLogDebug(@"【%@】开始处理多张图片发送，共%lu张", tag, (unsigned long)photos.count);
    
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    // 在后台线程逐一处理每张图片（缩放、压缩、上传、发送）
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        for (NSUInteger i = 0; i < photos.count; i++) {
            UIImage *photo = photos[i];
            NSString *itemTag = [NSString stringWithFormat:@"%@(%lu/%lu)", tag, (unsigned long)(i + 1), (unsigned long)photos.count];
            
            //** 进行基本的图片处理：缩放、质量压缩、计算MD5码并重命名等
            NSString *fileNameWillUpload = [SendImageHelper preparedImageForUpload:photo forPhoto:NO];
            
            [safeSelf processImagePickerCompleteImpl:fileNameWillUpload toChatType:safeSelf.chatType toId:safeSelf.toId toName:safeSelf.toName forForward:NO withTag:itemTag];
        }
    });
}

- (void)processImagePickerCompleteImpl:(NSString *)fileNameWillUpload toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward withTag:(NSString *)tag
{
    [self processImagePickerCompleteImpl:fileNameWillUpload toChatType:chatType toId:toId toName:toName forForward:forForward withTag:tag quoteMeta:nil];
}

- (void)processImagePickerCompleteImpl:(NSString *)fileNameWillUpload toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward withTag:(NSString *)tag quoteMeta:(QuoteMeta *)quoteMeta
{
    __weak typeof(self) safeSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{

        if(fileNameWillUpload != nil)
        {
            DDLogDebug(@"【%@】要上传的图片文件准备成功，文件名=%@", tag, fileNameWillUpload);
            
            [JSQSystemSoundPlayer jsq_playMessageSentSound];

            NSString *fingerPring = [Protocal genFingerPrint];
            
            JSQMessage *entity = [JSQMessage createChatMsgEntity_OUTGO_IMAGE:fileNameWillUpload withFingerPrint:fingerPring];
            if (quoteMeta != nil) {
                [entity setQuoteMeta:quoteMeta];
                // 收藏/转发到 10001 时，统一按来源用户显示（左侧气泡）
                if (chatType == CHAT_TYPE_FREIDN_CHAT
                    && toId != nil
                    && [toId isEqualToString:@"10001"]
                    && quoteMeta.quote_sender_uid.length > 0) {
                    entity.senderId = quoteMeta.quote_sender_uid;
                    if (quoteMeta.quote_sender_nick.length > 0) {
                        entity.senderDisplayName = quoteMeta.quote_sender_nick;
                    }
                }
            }
            
            if(forForward) {
                entity.sendStatusSecondary = SendStatusSecondary_NONE;
            }
            
            // 用于正式聊天
            if(CHAT_TYPE_FREIDN_CHAT == chatType) {
                [ChatDataHelper addChatMessageData_outgoing:toId withData:entity];
            }
            // 用于临时聊天
            else if(CHAT_TYPE_GUEST_CHAT == chatType) {
                [TChatDataHelper addChatMessageData_outgoing:toId withData:entity];
            }
            // 用于群组聊天
            else if(CHAT_TYPE_GROUP_CHAT == chatType) {
                [GChatDataHelper addChatMessageData_outgoing:toId withData:entity];
            }

            [safeSelf rb_updateLocalConversationAlarmForOutgoingRawContent:fileNameWillUpload
                                                                   msgType:TM_TYPE_IMAGE
                                                                  chatType:chatType
                                                                      toId:toId
                                                                    toName:toName];

            // 先插入列表立刻刷新气泡；upload 的 processing 回调会再次 finishSending 以更新「发送中」等状态
            if (!forForward) {
                [safeSelf finishSendingMessageAnimated:YES];
            }
            
            // 文件成功上传完成后的回调block
            void (^uploadedComplete)() = ^{
                // 设置“处理成功(完成)”状态
                entity.sendStatusSecondary = SendStatusSecondary_PROCESS_OK;
                
                // 消息发送完成后的回调block
                ObserverCompletion completion = ^(id observerble, id arg1) {
                    int code = [arg1 intValue];
                    // 为0表示消息已成功送出！
                    if(code != 0 && !rb_shouldSuppressSendFailureToastCode(code))
                        [APP showToastWarn:[NSString stringWithFormat:@"图片消息没有成功送出，原因是：code=%d", code]];
                    else if (!forForward && chatType == CHAT_TYPE_FREIDN_CHAT && [toId isEqualToString:@"10001"])
                        [safeSelf submitFavoriteToServerWithContent:fileNameWillUpload favType:kFavTypeImage sourceChatType:chatType onSyncSuccess:^{ [safeSelf refresh10001FavoritesListIfNeeded]; }];

                    if(!forForward) {
                        // 刷新消息气泡的UI显示
                        [safeSelf finishSendingMessageAnimated:YES];
                    }
                };

                //** 图片上传上传成功后立即发送即时消息给对方（之前图片已成功上传到服务端罗！）
                
                // 用于正式聊天
                if(CHAT_TYPE_FREIDN_CHAT == chatType) {
                    [MessageHelper sendImageMessageAsync:toId withImage:fileNameWillUpload fp:fingerPring forSucess:completion];
                }
                // 用于临时聊天
                else if(CHAT_TYPE_GUEST_CHAT == chatType) {
                    [TMessageHelper sendImageMessageAsync:toId tuname:toName withImage:fileNameWillUpload fp:fingerPring forSucess:completion];
                }
                // 用于群组聊天
                else if(CHAT_TYPE_GROUP_CHAT == chatType) {
                    [GMessageHelper sendImageMessageAsync:toId withImage:fileNameWillUpload fp:fingerPring forSucess:completion];
                }

                if(!forForward) {
                    // 刷新消息气泡的UI显示
                    [safeSelf finishSendingMessageAnimated:YES];
                }
            };
            
            // 如果是用于消息转发，需要直接跳过文件的处理过程（因为当转发的是收到的文件时，很可能这个文件还没下载过，
            // 而且转发的逻辑，本来就是只转发成功被发送的消息，所以不走文件处理流程完全合理）
            if(forForward) {
                uploadedComplete();
            }
            // 否则需要正常执行文件的上传操作
            else {
                //** 以后台的形式开始上传图片文件
                [SendImageHelper processImageUpload:fileNameWillUpload forPhoto:NO processing:^{
                    // 设置“处理中”状态
                    entity.sendStatusSecondary = SendStatusSecondary_PROCESSING;
                    // 刷新消息气泡的UI显示
                    [safeSelf finishSendingMessageAnimated:YES];
                } processFaild:^{
                    // 设置“处理失败”状态
                    entity.sendStatusSecondary = SendStatusSecondary_PROCESS_FAILD;
                    // 刷新消息气泡的UI显示
                    [safeSelf finishSendingMessageAnimated:YES];
                } processOk:uploadedComplete];
            }
        }
        else
        {
            DDLogDebug(@"【%@】要上传的图片文件准备失败，本次图片消息发送不能继续！", tag);
        }
    });
}

// 实现视频选择结果代理方法：视频（来自相册的视频）消息的发送实现方法。
- (void)processVideoPickerComplete:(NSString *)videoFilePath duration:(int)duration withTag:(NSString *)tag
{
    // 构建好短视频消息元数据对象
    ShortVideoRecordedDTO *dto = [[ShortVideoRecordedDTO alloc] init];
    dto.savedPath = videoFilePath;
    dto.duration = duration;//[TimeTool getDurationFromVideoFile:videoFilePath];
    dto.reachedMaxRecordTime = NO;
    
    if(dto.duration <= 0)
    {
        [BasicTool showAlertWarn:@"所选视频时长太短，该视频文件无效，无法处理！" parent:self];
        return;
    }
    
    // 直接走短视频消息的完整处理流程
    [self shortVideoRecordCompleteWithData:dto fromCamera:NO];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - IQAudioRecorderViewControllerDelegate（语音留言录制的相关代理方法）

- (void)audioRecorderController:(IQAudioRecorderViewController *)controller didFinishWithAudioAtPath:(NSString *)originalAudioPath
{
    __weak typeof(self) wself = self;
    NSString *cafPath = [originalAudioPath copy];
    [controller dismissViewControllerAnimated:YES completion:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *amrfilePath =  [IQAudioRecorderViewController convertCAFtoAMR:cafPath toDir:[SendVoiceHelper getSendVoiceSavedDir]];
            NSString *amrfileName = [amrfilePath lastPathComponent];
            [FileTool removeFile:cafPath];
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) sself = wself;
                if (!sself) return;
                if (amrfileName.length > 0) {
                    [sself processVoiceMessageSend:amrfileName playSentSound:NO];
                }
            });
        });
    }];
}

- (void)audioRecorderControllerDidCancel:(IQAudioRecorderViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)processVoiceMessageSend:(NSString *)fileNameWillUpload
{
    [self processVoiceMessageSend:fileNameWillUpload playSentSound:YES];
}

- (void)processVoiceMessageSend:(NSString *)fileNameWillUpload playSentSound:(BOOL)playSentSound
{
    [self processVoiceMessageSend:fileNameWillUpload toChatType:self.chatType toId:self.toId toName:self.toName forForward:NO playSentSound:playSentSound];
}

// 语音留言消息的发送实现方法。
- (void)processVoiceMessageSend:(NSString *)fileNameWillUpload toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward
{
    [self processVoiceMessageSend:fileNameWillUpload toChatType:chatType toId:toId toName:toName forForward:forForward quoteMeta:nil];
}

- (void)processVoiceMessageSend:(NSString *)fileNameWillUpload toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward quoteMeta:(QuoteMeta *)quoteMeta
{
    [self processVoiceMessageSend:fileNameWillUpload toChatType:chatType toId:toId toName:toName forForward:forForward playSentSound:YES quoteMeta:quoteMeta];
}

- (void)processVoiceMessageSend:(NSString *)fileNameWillUpload toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward playSentSound:(BOOL)playSentSound
{
    [self processVoiceMessageSend:fileNameWillUpload toChatType:chatType toId:toId toName:toName forForward:forForward playSentSound:playSentSound quoteMeta:nil];
}

- (void)processVoiceMessageSend:(NSString *)fileNameWillUpload toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward playSentSound:(BOOL)playSentSound quoteMeta:(QuoteMeta *)quoteMeta
{
    __weak typeof(self) safeSelf = self;
    
    if(fileNameWillUpload != nil)
    {
        DDLogDebug(@"【语音留言】要上传的语音文件准备成功，文件名=%@", fileNameWillUpload);
        
        if (playSentSound)
            [JSQSystemSoundPlayer jsq_playMessageSentSound];

        NSString *fingerPring = [Protocal genFingerPrint];

        JSQMessage *entity = [JSQMessage createChatMsgEntity_OUTGO_VOICE:fileNameWillUpload withFingerPrint:fingerPring];
        if (quoteMeta != nil) {
            [entity setQuoteMeta:quoteMeta];
            if (chatType == CHAT_TYPE_FREIDN_CHAT
                && toId != nil
                && [toId isEqualToString:@"10001"]
                && quoteMeta.quote_sender_uid.length > 0) {
                entity.senderId = quoteMeta.quote_sender_uid;
                if (quoteMeta.quote_sender_nick.length > 0) {
                    entity.senderDisplayName = quoteMeta.quote_sender_nick;
                }
            }
        }
        
        if(forForward) {
            entity.sendStatusSecondary = SendStatusSecondary_NONE;
        }
        
        // 用于正式聊天
        if(CHAT_TYPE_FREIDN_CHAT == chatType) {
            [ChatDataHelper addChatMessageData_outgoing:toId withData:entity];
        }
        // 用于临时聊天
        else if(CHAT_TYPE_GUEST_CHAT == chatType) {
            [TChatDataHelper addChatMessageData_outgoing:toId withData:entity];
        }
        // 用于群组聊天
        else if(CHAT_TYPE_GROUP_CHAT == chatType) {
            [GChatDataHelper addChatMessageData_outgoing:toId withData:entity];
        }

        [safeSelf rb_updateLocalConversationAlarmForOutgoingRawContent:fileNameWillUpload
                                                               msgType:TM_TYPE_VOICE
                                                              chatType:chatType
                                                                  toId:toId
                                                                toName:toName];
        
        // 文件成功上传完成后的回调block
        void (^uploadedComplete)() = ^{
            // 设置“处理成功(完成)”状态
            entity.sendStatusSecondary = SendStatusSecondary_PROCESS_OK;
            
            // 消息发送完成后的回调block
            ObserverCompletion completion = ^(id observerble, id arg1) {
                int code = [arg1 intValue];
                // 为0表示消息已成功送出！
                if(code != 0 && !rb_shouldSuppressSendFailureToastCode(code))
                    [APP showToastWarn:[NSString stringWithFormat:@"语音消息没有成功送出，原因是：code=%d", code]];
                else if (!forForward && chatType == CHAT_TYPE_FREIDN_CHAT && [toId isEqualToString:@"10001"])
                    [safeSelf submitFavoriteToServerWithContent:fileNameWillUpload favType:kFavTypeVoice sourceChatType:chatType onSyncSuccess:^{ [safeSelf refresh10001FavoritesListIfNeeded]; }];

                if(!forForward) {
                    // 刷新消息气泡的UI显示
                    [safeSelf finishSendingMessageAnimated:YES];
                }
            };

            //** 语音上传上传成功后立即发送即时消息给对方（之前语音已成功上传到服务端罗！）
            
            // Bug: 转发消息时，会因[MessageHelper send...]导致转发完成后自动滚动到最后一行（百思不解），目前没有更好的解决办法
            //       （用automaticallyScrollsToMostRecentMessage_ignoreOnce=YES也无解），暂时先搁置留待以后考虑吧。（250828日v10.0起，此Bug已解决，是ACK应答包导致的!）
            
            // 用于正式聊天
            if(CHAT_TYPE_FREIDN_CHAT == chatType) {
                [MessageHelper sendVoiceMessageAsync:toId withVoice:fileNameWillUpload fp:fingerPring forSucess:completion];
            }
            // 用于临时聊天
            else if(CHAT_TYPE_GUEST_CHAT == chatType) {
                [TMessageHelper sendVoiceMessageAsync:toId tuname:toName withVoice:fileNameWillUpload fp:fingerPring forSucess:completion];
            }
            // 用于群组聊天
            else if(CHAT_TYPE_GROUP_CHAT == chatType) {
                [GMessageHelper sendVoiceMessageAsync:toId withVoice:fileNameWillUpload fp:fingerPring forSucess:completion];
            }

            if(!forForward) {
                // 刷新消息气泡的UI显示
                [safeSelf finishSendingMessageAnimated:YES];
            }
        };

        // 如果是用于消息转发，需要直接跳过文件的处理过程（因为当转发的是收到的文件时，很可能这个文件还没下载过，
        // 而且转发的逻辑，本来就是只转发成功被发送的消息，所以不走文件处理流程完全合理）
        if(forForward) {
            uploadedComplete();
        }
        // 否则需要正常执行文件的上传操作
        else {
            //** 开始上传语音文件
            [SendVoiceHelper processVoiceUpload:fileNameWillUpload usedFor:NO processing:^{
                // 设置“处理中”状态
                entity.sendStatusSecondary = SendStatusSecondary_PROCESSING;
                // 刷新消息气泡的UI显示
                [safeSelf finishSendingMessageAnimated:YES];
            } processFaild:^{
                // 设置“处理失败”状态
                entity.sendStatusSecondary = SendStatusSecondary_PROCESS_FAILD;
                // 刷新消息气泡的UI显示
                [safeSelf finishSendingMessageAnimated:YES];
            } processOk:uploadedComplete];
        }
    }
    else
    {
        DDLogDebug(@"【语音留言】要上传的语音文件准备失败，本次语音消息发送不能继续！");
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - UIDocumentPickerDelegate（大文件选择相关代码方法及辅助方法）

// 从iOS的系统“文件”管理器中选中文件后，将会来到本代码方法中。。。
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    // 完成后必须 stopAccessingSecurityScopedResource: 哦
    BOOL fileUrlAuthozied = [url startAccessingSecurityScopedResource];
    if(fileUrlAuthozied)
    {
        NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] init];
        NSError *error;
        
        [fileCoordinator coordinateReadingItemAtURL:url options:0 error:&error byAccessor:^(NSURL *newURL) {
            
            NSString *fileName = [newURL lastPathComponent];
            NSString *_filePath = newURL.path;
            long long fileLength = [FileTool fileSizeAtPath:_filePath];
            
            DDLogDebug(@"【大文件上传-聊天界面中】本次选中的源文件名：“%@”，源路径：“%@”，大小：“%lld”字节", fileName, _filePath, fileLength);
                        
            if(error != nil)
            {
                [BasicTool showAlertWarn:@"选择文件失败了，请销后再试！" parent:safeSelf];
            }
            else
            {
                //** 文件前置检查
                BOOL beforeSendOK = [SendFileHelper beforeSend_check:_filePath vc:safeSelf];
                if(beforeSendOK)
                {
                    //** 首次尝试复制文件（此步很关键！）。
                    ///
                    /// 之所以要进行复制的原因是：因为RainbowChat的文件发送，支持跨沙箱的文件读取，而其它应用的
                    /// 沙箱目不录每次启动都有可能会变化（这是ios文件系统的安全机制），为了保证本地发送的跨沙箱文
                    /// 件能被本地用户正常预览，所以需要在发送文件前进行复制尝试，这样因为复制到了RainbowChat自
                    /// 已的沙箱内，所以也就不存在权限以及源沙箱目录发生变动而导致无法在本地预览该文件的问题了）。
                    NSString *destFilePath = [NSString stringWithFormat:@"%@/%@", [ReceivedFileHelper getReceivedFileSavedDir], fileName];
                    // 如果要复制的目标目录不存在，则先尝试创建之
                    [FileTool tryCreateDirs:[ReceivedFileHelper getReceivedFileSavedDir]];
                    // 开始复制文件
                    BOOL fileReady = [SendFileHelper tryCopy:_filePath destPath:destFilePath];
                    
                    if(fileReady)
                    {
                        //** md5码计算
                        [SendFileHelper beforeSend_calculateMD5:destFilePath parent:safeSelf.view complete:^(BOOL sucess, NSString *fileMD5) {
                            if(sucess)
                            {
//                                // 检查一下此md5码的文件是否正在上传中，如果真在上传中就不允许本次再发了（强行再次上传会打乱
//                                // 上个上传的断点算法和逻辑，而且从实际意义来说同一个文件完全没必要重复上传，等上一次发的传完再发不迟！）
//                                BigFileUploadManager *um = [BigFileUploadManager sharedInstance];
//                                if ([um isUploading:fileMD5])
//                                {
//                                    DDLogDebug(@"【大文件上传-md5计算完成后】要上传的大文件：“%@”， 已存在相同的上传任务，本次任务没有继续！", destFilePath);
//                                    [BasicTool showAlertWarn:[NSString stringWithFormat:@"文件“%@”已经在发送中，无需重复发送！", fileName] parent:safeSelf];
//                                    return;
//                                }
                                
                                // 上述大文件上传的前置检查、md5码计算等工作已完成，接下来就是真正的大文件上传和处理完整逻辑了！
                                [safeSelf processBigFileMessageSend:destFilePath fileName:fileName md5:fileMD5 fileLength:fileLength];
                            }
                            else
                            {
                                [BasicTool showAlertWarn:@"文件的MD5码计算失败，本次上传无法继续！" parent:safeSelf];
                                return;
                            }
                        }];
                    }
                    else
                    {
                        [BasicTool showAlertWarn:@"文件准备失败，本次上传无法继续！" parent:self];
                    }
                }
            }
            
            // 文件选择完成后关闭之
            [controller dismissViewControllerAnimated:YES completion:NULL];
        }];
        
        // 注意：本行代码务必要在述复制文件动作完成后才被调用，否则文件还未复制未完成（比如复制是放在异步里执行的），
        //      就调用了本方法的话，复制时就会报没有读取权限的问题（20191008日晚，在没有添加上述复制代码前，计算md5
        //      码是在异步线程里实现，而本代码在异步线程执行前就被调用，导致一直md5计算因没有读取权限而无法完成，就是这个原因！）
        [url stopAccessingSecurityScopedResource];
    }
    else
    {
        // 授权失败
        [BasicTool showAlertInfo:@"无法打开文件选择器！" parent:self];
    }
}

// 本方法打开的文件系统文件选择器，选择文件后将自动进入 UIDocumentPickerDelegate 中
- (void) openFilePicker
{
    // 进入文件选择（ios11及以上系统版里，才有“文件”浏览器这个东西）
    if(iOS11AndLater)
    {
//        NSArray*documentTypes =@[
//                @"public.content",
//                @"public.data",
//                @"com.microsoft.powerpoint.ppt",
//                @"com.microsoft.word.doc",
//                @"com.microsoft.excel.xls",
//                @"com.microsoft.powerpoint.pptx",
//                @"com.microsoft.word.docx",
//                @"com.microsoft.excel.xlsx",
//                @"public.avi",
//                @"public.3gpp",
//                @"public.mpeg-4",
//                @"com.compuserve.gif",
//                @"public.jpeg",
//                @"public.png",
//                @"public.plain-text",
//                @"com.adobe.pdf"
//                ];
//
//        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes inMode:UIDocumentPickerModeOpen];
//        
//        NSLog(@"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
//        
//        picker.delegate = self;
//        
//        if (@available(iOS 11.0, *)) {
//            picker.allowsMultipleSelection = YES;
//        }
//        
//        picker.modalPresentationStyle = UIModalPresentationFullScreen;
////        [navi presentViewController:picker animated:YES completion:nil];
//        
//        [self.navigationController presentViewController:picker animated:YES completion:nil];
////        [self presentViewController:picker animated:YES completion:nil];
//        
    
        
        //能选择的更多文件类型定义请见：https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html#//apple_ref/doc/uid/TP40009259
        NSArray <NSString *> *documentTypes = @[
            @"public.content",
            @"public.text",
            @"public.source-code",
            @"public.audio",
            @"public.image",
            @"public.movie",
            @"public.archive",
            @"public.executable",
            @"public.audiovisual-content",
            @"com.adobe.pdf",
            @"com.apple.keynote.key",
            @"com.microsoft.word.doc",
            @"com.microsoft.excel.xls",
            @"com.microsoft.powerpoint.ppt",
        ];
//        
//        NSArray<UTType *> *contentTypes = @[
//                [UTType typeWithIdentifier:@"public.item"],
//                [UTType typeWithIdentifier:@"public.data"],
//                [UTType typeWithIdentifier:@"public.content"],
//            ];
//    
        // 显示系统自带的”文件“管理器（ios11及以后系统中自带）
        UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes inMode:UIDocumentPickerModeOpen];
////        
//        UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:contentTypes asCopy:YES];
////        
        documentPicker.delegate = self;
////        // UIModalPresentationFullScreen在ios16.4的模拟器中，没有效果，无法全屏，在真机上未知！
        documentPicker.modalPresentationStyle = UIModalPresentationFullScreen;
//        documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;//UIModalPresentationFullScreen;//;//UIModalPresentationPageSheet;
////        [self presentViewController:documentPicker animated:YES completion:nil];
        [self.navigationController presentViewController:documentPicker animated:YES completion:nil];
    }
    // ios11以下版本就不存在什么文件上传了
    else
    {
        [BasicTool showAlertInfo:@"您的系统版本低于 iOS 11，无法使用大文件上传功能哦！" parent:self];
    }
}

/// 大文件消息的发送实现方法（本方法请在子类中实现，父类中默认什么也不做！）。
///
/// @param filePath 要发送的文件完整路径（父类中的代码将保证此文件的父目录是本app的沙箱地址，防止因Ios的文件安全机制而发生文件无法读取的y问题）
/// @param fileName 文件名
/// @param fileMD5 文件md5码
/// @param fileLength 文件长度（单位：字节）
- (void)processBigFileMessageSend:(NSString *)filePath fileName:(NSString *)fileName md5:(NSString *)fileMD5 fileLength:(long long)fileLength
{
    [self processBigFileMessageSend:filePath fileName:fileName md5:fileMD5 fileLength:fileLength toChatType:self.chatType toId:self.toId toName:self.toName forForward:NO];
}

/// 大文件消息的发送实现方法（本方法请在子类中实现，父类中默认什么也不做！）。
///
/// @param filePath 要发送的文件完整路径（父类中的代码将保证此文件的父目录是本app的沙箱地址，防止因Ios的文件安全机制而发生文件无法读取的y问题）
/// @param fileName 文件名
/// @param fileMD5 文件md5码
/// @param fileLength 文件长度（单位：字节）
- (void)processBigFileMessageSend:(NSString *)filePath fileName:(NSString *)fileName md5:(NSString *)fileMD5 fileLength:(long long)fileLength toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward
{
    [self processBigFileMessageSend:filePath fileName:fileName md5:fileMD5 fileLength:fileLength toChatType:chatType toId:toId toName:toName forForward:forForward quoteMeta:nil];
}

- (void)processBigFileMessageSend:(NSString *)filePath fileName:(NSString *)fileName md5:(NSString *)fileMD5 fileLength:(long long)fileLength toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward quoteMeta:(QuoteMeta *)quoteMeta
{
    __weak typeof(self) safeSelf = self;
    
    if(!forForward) {
        BigFileUploadManager *um = [BigFileUploadManager sharedInstance];
        if ([um isUploading:fileMD5]) {
            DDLogDebug(@"【大文件上传-md5计算完成后】要上传的大文件：“%@”， 已存在相同的上传任务，本次任务没有继续！", filePath);
            [BasicTool showAlertWarn:[NSString stringWithFormat:@"文件“%@”已经在发送中，无需重复发送！", fileName] parent:safeSelf];
            return;
        }
    }
    
    [JSQSystemSoundPlayer jsq_playMessageSentSound];
    
    NSString *fingerPrint = [Protocal genFingerPrint];
    FileMeta *fm = [FileMeta initWith:fileName fileMd5:fileMD5 fileLength:fileLength];
    
    JSQMessage *cme = [JSQMessage createChatMsgEntity_OUTGO_FILE:fm withFingerPrint:fingerPrint];
    if (quoteMeta != nil) {
        [cme setQuoteMeta:quoteMeta];
        if (chatType == CHAT_TYPE_FREIDN_CHAT
            && toId != nil
            && [toId isEqualToString:@"10001"]
            && quoteMeta.quote_sender_uid.length > 0) {
            cme.senderId = quoteMeta.quote_sender_uid;
            if (quoteMeta.quote_sender_nick.length > 0) {
                cme.senderDisplayName = quoteMeta.quote_sender_nick;
            }
        }
    }
    // 用于正式聊天
    if(CHAT_TYPE_FREIDN_CHAT == chatType) {
        [ChatDataHelper addChatMessageData_outgoing:toId withData:cme];
    }
    // 用于临时聊天
    else if(CHAT_TYPE_GUEST_CHAT == chatType) {
        [TChatDataHelper addChatMessageData_outgoing:toId withData:cme];
    }
    // 用于群组聊天
    else if(CHAT_TYPE_GROUP_CHAT == chatType) {
        [GChatDataHelper addChatMessageData_outgoing:toId withData:cme];
    }

    NSString *fileAlarmContent = [EVAToolKits toJSON:fm];
    [safeSelf rb_updateLocalConversationAlarmForOutgoingRawContent:fileAlarmContent
                                                           msgType:TM_TYPE_FILE
                                                          chatType:chatType
                                                              toId:toId
                                                            toName:toName];
    
    // 观察者：用于文件上传完成时通知本方法的调用者来做余下的事（把这个观察者当回调来理解就好了）
    ObserverCompletion observerForFileUploadOK = ^(id observerble ,id data) {
        ObserverCompletion completion = ^(id observerble, id arg1) {
            int code = [arg1 intValue];
            // 为0表示消息已成功送出！
                if(code != 0 && !rb_shouldSuppressSendFailureToastCode(code))
                [APP showToastWarn:[NSString stringWithFormat:@"大文件消息没有成功送出，原因是：code=%d", code]];
            else if (!forForward && chatType == CHAT_TYPE_FREIDN_CHAT && [toId isEqualToString:@"10001"]) {
                NSString *fileContent = [EVAToolKits toJSON:@{ @"file_name": fileName ?: @"", @"file_md5": fileMD5 ?: @"", @"file_length": @(fileLength) }];
                if (fileContent.length) [safeSelf submitFavoriteToServerWithContent:fileContent favType:kFavTypeFile sourceChatType:chatType onSyncSuccess:([toId isEqualToString:@"10001"] ? ^{ [safeSelf refresh10001FavoritesListIfNeeded]; } : nil)];
            }
        };
        
        // 并发送一条文件消息给好友（文件上传逻辑已在“SendFileHelper.processBigFileUpload(..)”处理完）
        
        // 用于正式聊天
        if(CHAT_TYPE_FREIDN_CHAT == chatType) {
            [MessageHelper sendFileMessageAsync:toId withMeta:fm fp:fingerPrint forSucess:completion];
        }
        // 用于临时聊天
        else if(CHAT_TYPE_GUEST_CHAT == chatType) {
            [TMessageHelper sendFileMessageAsync:toId tuname:toName withMeta:fm fp:fingerPrint forSucess:completion];
        }
        // 用于群组聊天
        else if(CHAT_TYPE_GROUP_CHAT == chatType) {
            [GMessageHelper sendFileMessageAsync:toId withMeta:fm fp:fingerPrint forSucess:completion];
        }
    };
    
    if(!forForward) {
        // 开始处理真正的文件上传完整逻辑
        [SendFileHelper processBigFileUpload:fileName filePath:filePath fileMd5:fileMD5 cme:cme uploadedSucessObserver:observerForFileUploadOK];
    }
    // 如果是用于消息转发功能就不需要走文件的处理逻辑，直接ui显示
    else{
        //** 以下设置没在 observerForFileUploadOK 观察者里做的原因：是大文件型的上传不同于普通消息，普通消息是等到网络指
        //** 令发出成合后才会将Message对象插入到ui界面等，而大文件型的消息是无论文件有没有处理完成、网络指令有没
        //** 发出，它都会先将Message对象插入到ui界面（先显示），然后再通过消息上的各种状态是告之用户此条文件型消息的状态是到什么程度了。
        // 转发的消息不需要处理文件上传，直接默认就认为文件已经上传好了（因为功能就只允许转发成功发出的文件消息）
        cme.sendStatusSecondary = SendStatusSecondary_PROCESS_OK;
        // 设置标识，以便消息发送失败时，用户点击重传时进行特殊的逻辑处理
        cme.forwardOutgoing= YES;
        
        // 直接通知观察者刷新ui
        observerForFileUploadOK(nil, nil);
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 短视频相关代码

// 打开短视频录制界面
- (void) openShortVideoRecorder
{
    [ViewControllerFactory goShortVideoRecorderViewController:self.navigationController];
}

// 用于处理录制完成的短视频的后续步骤
- (void)shortVideoRecordComplete:(NSNotification*)notification
{
    ShortVideoRecordedDTO *dto = (ShortVideoRecordedDTO *)notification.object;
    [self shortVideoRecordCompleteWithData:dto fromCamera:YES];
}

// 用于处理录制完成的短视频的后续步骤
- (void)shortVideoRecordCompleteWithData:(ShortVideoRecordedDTO *)dto fromCamera:(BOOL)fromCamera
{
//  DDLogDebug(@"################# 短视频录制完成 ，dto=%@", dto);
    if(dto != nil)
    {
        DDLogDebug(@"【短视频%@完成回调】%@完成(时长：%d秒)，reachedMaxRecordTime？%d，存放路径为：%@", fromCamera?@"录制":@"选择", fromCamera?@"录制":@"选择", dto.duration, dto.reachedMaxRecordTime, dto.savedPath);
        
        // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
        __weak typeof(self) safeSelf = self;
        
        // 建议后绪处理时，延迟一点再进行，目的是保证在前面短视频录制界面彻底关闭完成后，不然感觉UI上前面的界面还没有back完毕，这边就开始弹出相应的ui有点不爽，仅此而已
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((fromCamera ? .1f : 0.0f) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            // 录制完成后，取到的视频基本信息
            NSString *originalPath = dto.savedPath;
            int duration = dto.duration;
            BOOL reachedMaxRecordTime = dto.reachedMaxRecordTime;
            
            if(originalPath != nil)
            {
                if([FileTool fileExists:originalPath])
                {
                    long long fsize = [FileTool fileSizeAtPath:originalPath];
                    
                    // 直接发送视频，不需要确认对话框
                    [safeSelf shortVideoRecordCompleteImpl:originalPath duration:duration reachedMaxRecordTime:reachedMaxRecordTime fsize:fsize parent:safeSelf];
                }
                else
                {
                    [BasicTool showAlertInfo:@"要发送的视频不存在，请稍后再试！" parent:safeSelf];
                    return;
                }
            }
            else
            {
                [BasicTool showAlertInfo:@"无效的参数，视频发送没有继续！" parent:safeSelf];
                return;
            }
        });
    }
}

- (void)shortVideoRecordCompleteImpl:(NSString *)originalPath duration:(int)duration reachedMaxRecordTime:(BOOL)reachedMaxRecordTime fsize:(long long) fsize parent:(UIViewController *)parent {
    //** 文件前置检查
    BOOL beforeSendOK = [SendShortVideoHelper beforeSend_check:originalPath vc:parent];
    if(beforeSendOK)
    {
        //** md5码计算
        [SendShortVideoHelper beforeSend_calculateMD5:originalPath parent:parent.view complete:^(BOOL sucess, NSString *fileMD5) {
            if(sucess)
            {
                //** 文件数据合规检查-------------------------------------------------
                // 使用文件的MD5码重命名文件
                NSString *filePathAfterRename = [SendShortVideoHelper renameUseMD5:originalPath md5:fileMD5 duration:duration];
                if(filePathAfterRename != nil)
                    DDLogDebug(@"【SendShortVideo】要发送的短视频文件重命名完成.");
                else
                {
                    DDLogWarn(@"【SendShortVideo】要发送的短视频重命名失败！");
                    [BasicTool showAlertInfo:@"短视频文件重命名失败，发送已被取消！" parent:parent];
                    return;
                }
                
                // 检查一下此md5码的文件是否正在上传中，如果真在上传中就不允许本次再发了（强行再次上传会打乱
                // 上个上传的断点算法和逻辑，而且从实际意义来说同一个文件完全没必要重复上传，等上一次发的传完再发不迟！）
                BigFileUploadManager *um = [BigFileUploadManager sharedInstance];
                if ([um isUploading:fileMD5])
                {
                    
                    DDLogDebug(@"【短视频上传-md5计算完成后】要上传的视频文件：“%@”， 已存在相同的上传任务，本次任务没有继续！", filePathAfterRename);
                    [BasicTool showAlertWarn:@"文件已经在发送中，无需重复发送！" parent:parent];
                    return;
                }
                
                
                //** 为视频生成首帧预览图并缓存到本地---------------------------------
                // 取出视频首帧图片
                UIImage *firstFrame = [FileTool getVideoPreViewImageFromPath:filePathAfterRename];
                if(firstFrame != nil)
                {
                    // 视频首帧预览图的文件名（本地保存的名）
                    NSString *imgtLocalSavedName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:filePathAfterRename];
                    // 视频首帧预览图的保存目录
                    NSString *imgLocalSavedDir = [ReceivedShortVideoHelper getReceivedFileSavedDirHasSlash];
                    
                    // 如果图片要保存的目录不存在，则首先尝试创建之
                    [FileTool tryCreateDirs:imgLocalSavedDir];
                    // 视频首帧预览图将要保存的完整路径
//                                        NSString *imgFilePath = [NSString stringWithFormat:@"%@%@", imgLocalSavedDir, imgtLocalSavedName];
                    
                    // 将图片进行尺寸压缩和质量压缩，不然默认图可能会太大，占内存不说，ui上看起来也很难看
                    NSString *filePathAfterCompress = [BasicTool imageCompressForQualityAndWidth:firstFrame
                                                                                   targetQuality:SHORT_VIDEO_FIRST_COMPRESS_QUALITY
                                                                                     targetWidth:SHORT_VIDEO_FIRST_COMPRESS_MAX_WIDTH
                                                                                       saveToDir:imgLocalSavedDir
                                                                                       savedName:imgtLocalSavedName];
                    DDLogDebug(@"【短视频上传-首帧预览图生成】图片压缩完成（成功了吗？%d），压缩后保存的路径为：%@", (filePathAfterCompress != nil), filePathAfterCompress);
                }
                else
                {
                    DDLogWarn(@"【短视频上传-首帧预览图生成】视频%@的首帧预览图保存失败！", filePathAfterRename);
                }
                
                
                //** 真正的短视频消息的上传和发送流程-----------------------------------
                // 从路径中获得完整的文件名（带后缀）
                NSString *videoFileNameAfterRename = [filePathAfterRename lastPathComponent];
                // 进入真正的短视频消息的上传和发送流程
                [(ChatRootViewController *)parent processShortVideoMessageSend:filePathAfterRename 
//                                                                      duration:duration reachedMax:reachedMaxRecordTime
                                                                      fileName:videoFileNameAfterRename md5:fileMD5 fileLength:fsize];
            }
            else
            {
                [BasicTool showAlertWarn:@"文件的MD5码计算失败，本次上传无法继续！" parent:parent];
                return;
            }
        }];
    }
}

/// 短视频消息的发送实现方法。
///
/// @param videoSavedFilePath 重命完成的短视频文件完整路径
/// @param duration 视频时长（单位：秒）
/// @param reachedMaxRecordTime 是否到达最大录制时间
- (void)processShortVideoMessageSend:(NSString *)videoSavedFilePath 
//                            duration:(int)duration reachedMax:(BOOL)reachedMaxRecordTime
                            fileName:(NSString *)fileName md5:(NSString *)fileMD5 fileLength:(long long)fileLength
{
    [self processShortVideoMessageSend:videoSavedFilePath 
                              //duration:duration reachedMax:NO
                              fileName:fileName md5:fileMD5 fileLength:fileLength toChatType:self.chatType toId:self.toId toName:self.toName forForward:NO];
}

/// 短视频消息的发送实现方法。
///
/// @param videoSavedFilePath 重命完成的短视频文件完整路径
/// @param duration 视频时长（单位：秒）
/// @param reachedMaxRecordTime 是否到达最大录制时间
- (void)processShortVideoMessageSend:(NSString *)videoSavedFilePath
                            fileName:(NSString *)fileName md5:(NSString *)fileMD5 fileLength:(long long)fileLength toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward
{
    [self processShortVideoMessageSend:videoSavedFilePath fileName:fileName md5:fileMD5 fileLength:fileLength toChatType:chatType toId:toId toName:toName forForward:forForward quoteMeta:nil];
}

- (void)processShortVideoMessageSend:(NSString *)videoSavedFilePath
                            fileName:(NSString *)fileName md5:(NSString *)fileMD5 fileLength:(long long)fileLength toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward quoteMeta:(QuoteMeta *)quoteMeta
{
    __weak typeof(self) safeSelf = self;
    
    [JSQSystemSoundPlayer jsq_playMessageSentSound];
    
    NSString *fingerPrint = [Protocal genFingerPrint];
    FileMeta *fm = [FileMeta initWith:fileName fileMd5:fileMD5 fileLength:fileLength];
    JSQMessage *cme = [JSQMessage createChatMsgEntity_OUTGO_SHORTVIDEO:fm withFingerPrint:fingerPrint];
    if (quoteMeta != nil) {
        [cme setQuoteMeta:quoteMeta];
        if (chatType == CHAT_TYPE_FREIDN_CHAT
            && toId != nil
            && [toId isEqualToString:@"10001"]
            && quoteMeta.quote_sender_uid.length > 0) {
            cme.senderId = quoteMeta.quote_sender_uid;
            if (quoteMeta.quote_sender_nick.length > 0) {
                cme.senderDisplayName = quoteMeta.quote_sender_nick;
            }
        }
    }
    // 用于正式聊天
    if(CHAT_TYPE_FREIDN_CHAT == chatType) {
        [ChatDataHelper addChatMessageData_outgoing:toId withData:cme];
    }
    // 用于临时聊天
    else if(CHAT_TYPE_GUEST_CHAT == chatType) {
        [TChatDataHelper addChatMessageData_outgoing:toId withData:cme];
    }
    // 用于群组聊天
    else if(CHAT_TYPE_GROUP_CHAT == chatType) {
        [GChatDataHelper addChatMessageData_outgoing:toId withData:cme];
    }

    NSString *shortVideoAlarmContent = [EVAToolKits toJSON:fm];
    [safeSelf rb_updateLocalConversationAlarmForOutgoingRawContent:shortVideoAlarmContent
                                                           msgType:TM_TYPE_SHORTVIDEO
                                                          chatType:chatType
                                                              toId:toId
                                                            toName:toName];

    // 须立刻刷新列表：query 断点/首包上传回调前不会走 fileStatusChangedObserver，否则长时间无气泡
    if (!forForward) {
        [safeSelf finishSendingMessageAnimated:YES];
    }
    
    // 观察者：用于文件上传完成时通知本方法的调用者来做余下的事（把这个观察者当回调来理解就好了）
    ObserverCompletion observerForFileUploadOK = ^(id observerble ,id data) {
        
        // 并发送一条短视频消息给好友（文件上传逻辑已在“SendShortVideoHelper.processBigFileUpload(..)”处理完）
        
        ObserverCompletion completion = ^(id observerble, id arg1) {
            int code = [arg1 intValue];
            // 为0表示消息已成功送出！
            if(code != 0 && !rb_shouldSuppressSendFailureToastCode(code))
                [APP showToastWarn:[NSString stringWithFormat:@"短视频消息没有成功送出，原因是：code=%d", code]];
            else if (!forForward && chatType == CHAT_TYPE_FREIDN_CHAT && [toId isEqualToString:@"10001"]) {
                int duration = [TimeTool getDurationFromVoiceFileName:fileName];
                if (duration <= 0) duration = 10;
                NSString *videoContent = [EVAToolKits toJSON:@{ @"file_name": fileName ?: @"", @"file_md5": fileMD5 ?: @"", @"duration": @(duration) }];
                if (videoContent.length) [safeSelf submitFavoriteToServerWithContent:videoContent favType:kFavTypeVideo sourceChatType:chatType onSyncSuccess:([toId isEqualToString:@"10001"] ? ^{ [safeSelf refresh10001FavoritesListIfNeeded]; } : nil)];
            }
        };
        
        // 用于正式聊天
        if(CHAT_TYPE_FREIDN_CHAT == chatType) {
            [MessageHelper sendShortVideoMessageAsync:toId withMeta:fm fp:fingerPrint forSucess:completion];
        }
        // 用于临时聊天
        else if(CHAT_TYPE_GUEST_CHAT == chatType) {
            [TMessageHelper sendShortVideoMessageAsync:toId tuname:toName withMeta:fm fp:fingerPrint forSucess:completion];
        }
        // 用于群组聊天
        else if(CHAT_TYPE_GROUP_CHAT == chatType) {
            [GMessageHelper sendShortVideoMessageAsync:toId withMeta:fm fp:fingerPrint forSucess:completion];
        }
    };
    
    if(!forForward) {
        // 开始处理真正的短视频文件上传完整逻辑
        [SendShortVideoHelper processShortVideoUpload:fileName filePath:videoSavedFilePath fileMd5:fileMD5 cme:cme uploadedSucessObserver:observerForFileUploadOK];
    }
    // 如果是用于消息转发功能就不需要走文件的处理逻辑，直接ui显示
    else {
        //** 以下设置没在 observerForFileUploadOK 观察者里做的原因：是大文件型的上传不同于普通消息，普通消息是等到网络指
        //** 令发出成合后才会将Message对象插入到ui界面等，而大文件型的消息是无论文件有没有处理完成、网络指令有没
        //** 发出，它都会先将Message对象插入到ui界面（先显示），然后再通过消息上的各种状态是告之用户此条文件型消息的状态是到什么程度了。
        // 转发的消息不需要处理文件上传，直接默认就认为文件已经上传好了（因为功能就只允许转发成功发出的文件消息）
        cme.sendStatusSecondary = SendStatusSecondary_PROCESS_OK;
        // 设置标识，以便消息发送失败时，用户点击重传时进行特殊的逻辑处理
        cme.forwardOutgoing= YES;
        
        // 直接通知观察者刷新ui
        observerForFileUploadOK(nil, nil);
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 有关名片消息处理的方法

/**
  打开好友选择列表界面（以便选择要发送的个人名片）。
 */
- (void)openUserChoose
{
//    // 本方法请在子类中实现，父类中默认什么也不做！
//    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
    [ViewControllerFactory goTargetChooseViewController:self.navigationController
                                supportedTargetSource:TargetSourceFriend
                                 latestChattingFilter:nil
                                         friendFilter:[TargetSourceFilterFactory createTargetSourceFilter4UserContact:self.chatType toId:self.toId]
                                          groupFilter:nil
                                      groupMemberFilter:nil
                                               extraObj:nil
                                                    gid:nil
                                            requestCode:TARGET_CHOOSE_REQUEST_CODE_FOR_CONTACT
                                             delegate:self];
}

/**
  打开群选择列表界面（以便选择要发送的群名片）。
 */
- (void)openGroupChoose
{
//    // 本方法请在子类中实现，父类中默认什么也不做！
//    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
    [ViewControllerFactory goTargetChooseViewController:self.navigationController
                                supportedTargetSource:TargetSourceGroup
                                 latestChattingFilter:nil
                                         friendFilter:nil
                                          groupFilter:[TargetSourceFilterFactory createTargetSourceFilter4GroupContact:self.chatType toId:self.toId]
                                      groupMemberFilter:nil
                                               extraObj:nil
                                                    gid:nil
                                            requestCode:TARGET_CHOOSE_REQUEST_CODE_FOR_CONTACT
                                             delegate:self];
}

/**
 * 好友选择结果代理方法：可以在此方法中处理从用户选择列表中选择的用户进行进一步处理。
 *
 * @param te 选中的目标
 */
- (void)processTargetChooseComplete:(TargetEntity *)te extraObj:(id)obj requestCode:(int)requestCode
{
//    // 本方法请在子类中实现，父类中默认什么也不做！
//    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
    
    if(te != nil) {
        DLogDebug(@"【名片消息或消息转发】目标选择完成，requestCode=%ld、tagertType=%ld、tagertId=%@、tagertName=%@、otherInfo=%@", requestCode, te.targetChatType, te.targetId, te.targetName, te.targetOtherInfo);
        
        // 当前是为名片消息功能选择目标
        if(TARGET_CHOOSE_REQUEST_CODE_FOR_CONTACT == requestCode) {
            
            int contactType = CONTACT_TYPE_USER;
            if(te.targetChatType == CHAT_TYPE_GROUP_CHAT) {
                contactType = CONTACT_TYPE_GROUP;
            }
            
            ContactMeta *selectedContact = [ContactMeta initWith:contactType uid:te.targetId nickname:te.targetName desc:te.targetOtherInfo];
            [self processContactChooseCompleteImpl:selectedContact toChatType:self.chatType toId:self.toId toName:self.toName];
        }
        // 当前是为消息转发功能选择目标（单选兼容，支持多消息数组）
        else if(TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD == requestCode) {
            NSArray<JSQMessage *> *messagesToForward = nil;
            if ([obj isKindOfClass:[NSArray class]]) {
                messagesToForward = (NSArray<JSQMessage *> *)obj;
            } else if ([obj isKindOfClass:[JSQMessage class]]) {
                messagesToForward = @[(JSQMessage *)obj];
            }
            if (messagesToForward.count > 0) {
                [self rb_presentForwardConfirmAfterTargetPickerDismissWithTargets:@[te] messages:messagesToForward];
            }
        } 
        // 当前是为 "@" 功能选择目标
        else if(TARGET_CHOOSE_REQUEST_CODE_FOR_AT == requestCode) {
            // 选择 "@" 功能目标时，extraObj存放的是BOOL值，表示是否需要在插入文本框时加上 “@” 字符
            [self processAtChooseCompleteImpl:te needInsertAitInText:(obj != nil ? [obj boolValue] : NO)];
        }
        
        else {
            [BasicTool showAlertWarn:[NSString stringWithFormat:@"不支持的目标选择，requestCode=%d", requestCode] parent:self];
        }
    } else {
        DLogWarn(@"【名片消息或消息转发】目标选择失败，selectedTarget == nil!");
    }
}

/**
 * 用户选择结果代理方法（多选）：处理从用户选择列表中选择的多个目标。
 *
 * @param selectedTargets 选中的目标数组
 */
- (void)processMultiTargetChooseComplete:(NSArray<TargetEntity *> *)selectedTargets extraObj:(id)obj requestCode:(int)requestCode
{
    if (selectedTargets == nil || selectedTargets.count == 0) {
        DLogWarn(@"【多选目标选择】目标选择失败，selectedTargets 为空！");
        return;
    }
    
    DLogDebug(@"【多选目标选择】选择完成，共 %lu 个目标，requestCode=%d", (unsigned long)selectedTargets.count, requestCode);
    
    // 当前是为消息转发功能选择目标（多选）
    if (TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD == requestCode) {
        // 支持多选消息转发：extraObj 可能是单条 JSQMessage 或 NSArray<JSQMessage *>
        NSArray<JSQMessage *> *messagesToForward = nil;
        if ([obj isKindOfClass:[NSArray class]]) {
            messagesToForward = (NSArray<JSQMessage *> *)obj;
        } else if ([obj isKindOfClass:[JSQMessage class]]) {
            messagesToForward = @[(JSQMessage *)obj];
        }
        if (messagesToForward.count > 0) {
            [self rb_presentForwardConfirmAfterTargetPickerDismissWithTargets:selectedTargets messages:messagesToForward];
        }
    }
    // 当前是为 "@" 功能选择目标（多选）
    else if (TARGET_CHOOSE_REQUEST_CODE_FOR_AT == requestCode) {
        BOOL needInsertAitInText = (obj != nil ? [obj boolValue] : NO);
        for (NSUInteger i = 0; i < selectedTargets.count; i++) {
            TargetEntity *te = selectedTargets[i];
            if (i == 0) {
                // 第一个用户使用原始的 needInsertAitInText 值
                // （通过文本输入"@"触发时为NO，因为"@"已存在；通过"+"菜单触发时为YES）
                [self processAtChooseCompleteImpl:te needInsertAitInText:needInsertAitInText];
            } else {
                // 后续用户始终需要插入 "@" 前缀
                [self processAtChooseCompleteImpl:te needInsertAitInText:YES];
            }
        }
    }
    else {
        // 其他多选场景暂未支持，逐个回调单选代理方法
        for (TargetEntity *te in selectedTargets) {
            [self processTargetChooseComplete:te extraObj:obj requestCode:requestCode];
        }
    }
}

- (void)rb_presentForwardConfirmAfterTargetPickerDismissWithTargets:(NSArray<TargetEntity *> *)targets messages:(NSArray<JSQMessage *> *)messages
{
    if (targets.count == 0 || messages.count == 0) {
        return;
    }
    NSArray<TargetEntity *> *targetsCopy = [targets copy];
    NSArray<JSQMessage *> *messagesCopy = [messages copy];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        UIViewController *presentingVC = strongSelf.navigationController.topViewController ?: strongSelf;
        if (presentingVC.presentedViewController != nil) {
            return;
        }

        RBForwardConfirmSheetViewController *sheet = [[RBForwardConfirmSheetViewController alloc] initWithTargets:targetsCopy
                                                                                                        messages:messagesCopy
                                                                                                    confirmBlock:^{
            [strongSelf rb_executeForwardMessages:messagesCopy toTargets:targetsCopy];
            UIViewController *topVC = strongSelf.navigationController.topViewController;
            if (topVC != nil && topVC != strongSelf) {
                [strongSelf.navigationController popViewControllerAnimated:YES];
            }
        }];
        [presentingVC presentViewController:sheet animated:NO completion:nil];
    });
}

- (void)rb_executeForwardMessages:(NSArray<JSQMessage *> *)messages toTargets:(NSArray<TargetEntity *> *)targets
{
    if (messages.count == 0 || targets.count == 0) {
        return;
    }
    for (TargetEntity *te in targets) {
        for (JSQMessage *message in messages) {
            [self forward:message toChatType:te.targetChatType toId:te.targetId toName:te.targetName forSucess:nil];
        }
    }

    NSUInteger msgCount = messages.count;
    NSString *msg = nil;
    if (targets.count > 1 && msgCount > 1) {
        msg = [NSString stringWithFormat:@"已将 %lu 条消息转发给 %lu 位联系人", (unsigned long)msgCount, (unsigned long)targets.count];
    } else if (targets.count > 1) {
        msg = [NSString stringWithFormat:@"已转发给 %lu 位联系人", (unsigned long)targets.count];
    } else if (msgCount > 1) {
        msg = [NSString stringWithFormat:@"已转发 %lu 条消息", (unsigned long)msgCount];
    } else {
        msg = @"转发完成";
    }
    [APP showUserDefineToast_OK:msg atHide:nil];

    if (self.isMultiSelectMode) {
        [self exitMultiSelectMode];
    }
}

/**
 * 好友选择结果代理方法：可以在此方法中处理从用户选择列表中选择的用户进行进一步处理。
 *
 * @param te 选中的目标
 */
- (void)processContactChooseCompleteImpl:(ContactMeta *)cm toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName
{
    __weak typeof(self) wself = self;
    BOOL isCurrentChat = (chatType == self.chatType && ((toId == nil && self.toId == nil) || [toId isEqualToString:self.toId]));
    ObserverCompletion uiObs = ^(id observer, id arg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!wself) return;
            if (isCurrentChat) {
                [wself finishSendingMessageAnimated:YES];
                [wself rb_scrollChatToBottomAfterEnsuringLayoutAnimated:YES];
            }
        });
    };
    ObserverCompletion contactSucessObs = uiObs;
    if (chatType == CHAT_TYPE_FREIDN_CHAT && [toId isEqualToString:@"10001"]) {
        contactSucessObs = ^(id observer, id arg) {
            uiObs(observer, arg);
            // 存 ContactMeta JSON，便于 10001 列表加载时还原为名片气泡展示
            NSString *content = [EVAToolKits toJSON:cm];
            if (content.length == 0) {
                NSString *preview = (cm.nickName.length > 0) ? cm.nickName : (cm.uid ?: @"");
                content = [NSString stringWithFormat:@"[名片] %@", preview];
            }
            [wself submitFavoriteToServerWithContent:content favType:kFavTypeText sourceChatType:chatType onSyncSuccess:^{ [wself refresh10001FavoritesListIfNeeded]; }];
        };
    }
    //** 真正发出"名片"消息
    if(chatType == CHAT_TYPE_FREIDN_CHAT) {
        [MessageHelper sendContactMessageAsync:toId withMeta:cm forSucess:contactSucessObs];
    } else if(chatType == CHAT_TYPE_GUEST_CHAT) {
        [TMessageHelper sendContactMessageAsync:toId tuname:toName withMeta:cm forSucess:contactSucessObs];
    } else if(chatType == CHAT_TYPE_GROUP_CHAT) {
        [GMessageHelper sendContactMessageAsync:toId withMeta:cm forSucess:contactSucessObs];
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 收藏选择器

- (void)openFavoritesPicker
{
    __weak typeof(self) weakSelf = self;
    
    FavPickerViewController *picker = [[FavPickerViewController alloc] init];
    picker.targetName = self.toName;
    picker.targetId = self.toId;
    picker.targetChatType = self.chatType;
    picker.completion = ^(NSDictionary * _Nullable selectedItem) {
        if (selectedItem == nil) return; // 用户取消
        [weakSelf sendFavoriteItem:selectedItem];
    };
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

/**
 * 根据收藏条目的类型，将其内容作为消息发送到当前会话。
 */
- (void)sendFavoriteItem:(NSDictionary *)item
{
    int favType = [item[@"fav_type"] intValue];
    NSString *content = item[@"content"] ?: @"";
    
    if (content.length == 0) {
        [APP showToastWarn:@"收藏内容为空，无法发送"];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    void (^refreshFavoriteBubbleNow)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf finishSendingMessageAnimated:YES];
        });
    };
    
    switch (favType) {
        // 文本消息
        case 0: {
            [self sendPlainTextMessage:content forSucess:^(id observerble, id arg1) {
                [weakSelf finishSendingMessageAnimated:YES];
            }];
            break;
        }
        // 图片消息（content = 图片文件名，文件已在服务器上，走转发路径跳过上传）
        case 1: {
            [self reSendImageMessage:YES toChatType:self.chatType toId:self.toId toName:self.toName fileName:content quoteMeta:nil];
            refreshFavoriteBubbleNow();
            break;
        }
        // 语音消息（content = 语音文件名，走转发路径跳过上传）
        case 2: {
            [self reSendVoiceMessage:YES toChatType:self.chatType toId:self.toId toName:self.toName fileName:content quoteMeta:nil];
            refreshFavoriteBubbleNow();
            break;
        }
        // 视频消息（content = FileMeta JSON，走转发路径跳过上传）
        case 3: {
            NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(content);
            if (jsonUse.length == 0) {
                jsonUse = content;
            }
            FileMeta *fm = [FileMeta fromJSON:jsonUse];
            NSString *fileName = fm.fileName ?: item[@"video_file_name"];
            NSString *fileMd5 = fm.fileMd5 ?: item[@"video_file_md5"];
            if (fileName.length == 0 || fileMd5.length == 0) {
                [APP showToastWarn:@"视频源文件信息不完整，无法发送"];
                break;
            }
            NSString *filePath = [NSString stringWithFormat:@"%@/%@", [ReceivedShortVideoHelper getReceivedFileSavedDir], fileName];
            [self reSendShortVideoMessage:YES toChatType:self.chatType toId:self.toId toName:self.toName filePath:filePath md5:fileMd5 quoteMeta:nil];
            refreshFavoriteBubbleNow();
            break;
        }
        // 位置消息（content = LocationMeta JSON）
        case 5: {
            @try {
                LocationMeta *lm = [LocationMeta fromJSON:content];
                if (lm != nil) {
                    [self reSendLocationMessage:YES toChatType:self.chatType toId:self.toId toName:self.toName lm:lm quoteMeta:nil];
                    refreshFavoriteBubbleNow();
                } else {
                    [APP showToastWarn:@"位置数据解析失败"];
                }
            } @catch (NSException *e) {
                [APP showToastWarn:@"位置数据格式错误"];
            }
            break;
        }
        // 文件等暂不支持直接发送
        default: {
            [APP showToastWarn:@"该类型收藏暂不支持直接发送"];
            break;
        }
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 位置消息处理的方法 & LocationChooseCompleteDelegate

- (void)openLocationChoose
{
    [ViewControllerFactory goLocationChooseViewController:self.navigationController delegate:self];
}

/**
 * 位置选择结果代理方法：可以在此方法中处理从地图选择的位置进行进一步处理。
 *
 * @param selectedLocation 选中的位置
 */
- (void)processLocationChooseComplete:(LocationMeta *)selectedLocation
{
    [self processLocationChooseComplete:selectedLocation toChatType:self.chatType toId:self.toId toName:self.toName forForward:NO];
}

/**
 * 位置选择结果代理方法：可以在此方法中处理从地图选择的位置进行进一步处理。
 *
 * @param selectedLocation 选中的位置
 */
- (void)processLocationChooseComplete:(LocationMeta *)selectedLocation toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward
{
    [self processLocationChooseComplete:selectedLocation toChatType:chatType toId:toId toName:toName forForward:forForward quoteMeta:nil];
}

- (void)processLocationChooseComplete:(LocationMeta *)selectedLocation toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward quoteMeta:(QuoteMeta *)quoteMeta
{
    __weak typeof(self) safeSelf = self;
    
    if(selectedLocation != nil)
    {
        DDLogDebug(@"【位置消息】要发送的位置数据准备成功，内容为：%@", [EVAToolKits toJSON:selectedLocation]);
        
        [JSQSystemSoundPlayer jsq_playMessageSentSound];
        
        NSString *fingerPring = [Protocal genFingerPrint];
        
        JSQMessage *entity = [JSQMessage createChatMsgEntity_OUTGO_LOCATION:selectedLocation withFingerPrint:fingerPring];
        if (quoteMeta != nil) {
            [entity setQuoteMeta:quoteMeta];
            if (chatType == CHAT_TYPE_FREIDN_CHAT
                && toId != nil
                && [toId isEqualToString:@"10001"]
                && quoteMeta.quote_sender_uid.length > 0) {
                entity.senderId = quoteMeta.quote_sender_uid;
                if (quoteMeta.quote_sender_nick.length > 0) {
                    entity.senderDisplayName = quoteMeta.quote_sender_nick;
                }
            }
        }
        // 用于正式聊天
        if(CHAT_TYPE_FREIDN_CHAT == chatType) {
            [ChatDataHelper addChatMessageData_outgoing:toId withData:entity];
        }
        // 用于临时聊天
        else if(CHAT_TYPE_GUEST_CHAT == chatType) {
            [TChatDataHelper addChatMessageData_outgoing:toId withData:entity];
        }
        // 用于群组聊天
        else if(CHAT_TYPE_GROUP_CHAT == chatType) {
            [GChatDataHelper addChatMessageData_outgoing:toId withData:entity];
        }

        NSString *locationAlarmContent = [EVAToolKits toJSON:selectedLocation];
        [safeSelf rb_updateLocalConversationAlarmForOutgoingRawContent:locationAlarmContent
                                                               msgType:TM_TYPE_LOCATION
                                                              chatType:chatType
                                                                  toId:toId
                                                                toName:toName];
        
        // 设置“处理中”状态
        entity.sendStatusSecondary = SendStatusSecondary_PROCESSING;
        
        void (^observerForFileUploadOK)(id) = ^(id responseObject) {
            // 设置“处理成功(完成)”状态
            entity.sendStatusSecondary = SendStatusSecondary_PROCESS_OK;
            
            ObserverCompletion completion = ^(id observerble, id arg1) {
                int code = [arg1 intValue];
                // 为0表示消息已成功送出！
                if(code != 0 && !rb_shouldSuppressSendFailureToastCode(code))
                    [APP showToastWarn:[NSString stringWithFormat:@"位置消息没有成功送出，原因是：code=%d", code]];
                else if (!forForward && chatType == CHAT_TYPE_FREIDN_CHAT && [toId isEqualToString:@"10001"]) {
                    NSString *locContent = [EVAToolKits toJSON:selectedLocation];
                    if (locContent.length) [safeSelf submitFavoriteToServerWithContent:locContent favType:kFavTypeLocation sourceChatType:chatType onSyncSuccess:([toId isEqualToString:@"10001"] ? ^{ [safeSelf refresh10001FavoritesListIfNeeded]; } : nil)];
                }
                
                if(!forForward) {
                    // 刷新消息气泡的UI显示
                    [safeSelf finishSendingMessageAnimated:YES];
                }
            };
            
            //** 预览图上传成功后立即发送即时消息给对方（之前语音已成功上传到服务端罗！）
            
            // 用于正式聊天
            if(CHAT_TYPE_FREIDN_CHAT == chatType) {
                [MessageHelper sendLocationMessageAsync:toId withMeta:selectedLocation fp:fingerPring forSucess:completion];
            }
            // 用于临时聊天
            else if(CHAT_TYPE_GUEST_CHAT == chatType) {
                [TMessageHelper sendLocationMessageAsync:toId tuname:toName withMeta:selectedLocation fp:fingerPring forSucess:completion];
            }
            // 用于群组聊天
            else if(CHAT_TYPE_GROUP_CHAT == chatType) {
                [GMessageHelper sendLocationMessageAsync:toId withMeta:selectedLocation fp:fingerPring forSucess:completion];
            }
            
            if(!forForward) {
                // 刷新消息气泡的UI显示
                [safeSelf finishSendingMessageAnimated:YES];
            }
        };
        
        if(!forForward) {
            // 位置预览图开始上传到服务端
            [LocationUtils uploadLocationPreviewFile:selectedLocation.prewviewImgFileName completeFail:^(NSError *error) {
                // 设置“处理失败”状态
                entity.sendStatusSecondary = SendStatusSecondary_PROCESS_FAILD;
                // 刷新消息气泡的UI显示
                [safeSelf finishSendingMessageAnimated:YES];
            } completeSucess:observerForFileUploadOK];
        }
        // 如果是用于消息转发功能就不需要走文件的处理逻辑，直接ui显示
        else {
            // 设置标识，以便消息发送失败时，用户点击重传时进行特殊的逻辑处理
            entity.forwardOutgoing= YES;
            
            // 直接通知观察者刷新ui
            observerForFileUploadOK(nil);
        }
    }
    else
    {
        DDLogDebug(@"【位置消息】要发送的位置数据准备失败，本次位置消息发送不能继续！");
    }
}

@end
