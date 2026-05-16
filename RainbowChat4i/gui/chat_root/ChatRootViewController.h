//telegram @wz662
/**
 * 聊天根界面实现类。
 * 一对一好友聊天、一对一陌生人聊天、多对多世界频道、多对多群聊的聊天界面继承本类实现自已的相关逻辑即可。
 *
 * @author Jack Jiang
 * @since 4.3
 */

#import <UIKit/UIKit.h>
#import "JSQMessages.h"
#import "JSQMessagesViewController.h"
#import "IQAudioRecorderViewController.h"
#import "RBImagePickerWrapper.h"
#import "TargetChooseViewController.h"
#import "GetLocationViewController.h"
#import "EVAToolKits.h"
#import "AtModel.h"
#import "TargetEntity.h"
#import "RBChromeNavigationBar.h"

// 用于“名片”消息功能时，选择目标时的请求码
#define TARGET_CHOOSE_REQUEST_CODE_FOR_CONTACT 1
// 用于消息“转发”功能时，选择目标时的请求码
#define TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD 2
// 用于消息 “@” 功能时，选择目标时的请求码
#define TARGET_CHOOSE_REQUEST_CODE_FOR_AT      3

@class TGInputBar;

@interface ChatRootViewController : JSQMessagesViewController<IQAudioRecorderViewControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegate, RBImagePickerCompleteDelegate, UIDocumentPickerDelegate, UserChooseCompleteDelegate, LocationChooseCompleteDelegate, UITextViewDelegate>

/** 聊天类型（用于区分是好友聊天、陌生人聊天或者群聊）。@see {@link MsgBodyRoot} */
@property (nonatomic, assign) int chatType;
/** 聊天id（一对一聊天时是存放的是对方的uid，群聊时是群id ）*/
@property (nonatomic, retain) NSString *toId;
/** 聊天名（一对一陌生人聊天时是存放的是对方的昵称，群聊时是群名称） */
@property (nonatomic, retain) NSString *toName;

/** 该指纹码的消息将高亮显示一次（该指纹码当前通过初始化时传入，当前主要用于搜索功能中进入聊天界面时）*/
@property (nonatomic, retain) NSString *highlightOnceMsgFingerprint;
/** 搜索跳转时目标消息的时间锚点。当前用于在首批消息未命中目标指纹时补载对应消息窗口。 */
@property (nonatomic, strong, nullable) NSDate *highlightAnchorMessageDate;

@property (nonatomic, assign) int rb_initialSessionUnreadCount;

/** 同步「搜索跳转待高亮」指纹：打开会话时传入非空 fp 会写入待处理表；传入 nil/空 则清除该 uid 的待处理项（用于列表进聊天不打断上次搜索跳转）。工厂创建 VC 时应调用。*/
+ (void)rb_syncPendingSearchJumpHighlightFingerprint:(NSString * _Nullable)highlight fpForUid:(NSString *)uid;
/** 同步「搜索跳转待定位」时间锚点：供聊天页在首批消息未命中 fp 时恢复到目标消息附近的本地窗口。 */
+ (void)rb_syncPendingSearchJumpAnchorMessageDate:(NSDate * _Nullable)anchorMessageDate forUid:(NSString *)uid;

/** 图片选择处理封装对象（用于图片消息中从相机或相册中选择图片的各种处理）*/
@property (nonatomic, strong) RBImagePickerWrapper *imagePickerWrapper;

/** 用于存放当前选定的"@"对象，"@"功能仅用于群聊中 */
@property (nonatomic, strong) AtModel *atCache;

/** 存放尚未被用户处理的@我消息稳定标识（优先指纹，避免历史加载/裁剪后 index 漂移） */
@property (nonatomic, strong) NSMutableArray<NSString *> *pendingAtMeIndexes;
/** "有人@我"悬浮提示按钮 */
@property (nonatomic, strong) UIButton *btnAtMeHint;

/** Telegram 风格输入栏；仅当 `ChatRootViewController.m` 内 `kRBChatUseTGInputBar==YES` 时创建，否则为 nil（使用原版 JSQ 输入栏） */
@property (nonatomic, strong, nullable) TGInputBar *tgInputBar;

// 聊天消息数据模型变动观察者实现block
@property (nonatomic, copy) ObserverCompletion chattingDatasObserver;

// 设置{@link BigFileUploadManager}中大文件任务状态改变观察者block(主要用于“我”发送的大文件消息)，
// 用于UI及时刷新文件上传状态在界面上的显示（本观察者通常由对应的UI界面设置，界面退到后台消失时取消设置）
@property (nonatomic, copy) ObserverCompletion fileStatusChangedObserver;

- (void)initObservers;

/**
 返回聊天列表数据集合对象引用（本方法请在子类中实现，父类中默认返回一个空集合！）

 @return 聊天列表数据集合对象引用
 */
- (NSMutableArray<JSQMessage *> *) getChattingDatasList;

/** 下拉加载更多历史（子类可重写，如 10001 收藏夹改为服务端分页） */
- (void)onLoadMoreHistory;

/** 收藏夹（10001）按 source_from_uid 显示头像时，子类可重写以返回已拉取的 user_avatar_file_name，用于拼头像下载地址；未实现或返回 nil 时仅用 uid 调接口 */
- (nullable NSString *)avatarFileNameForSourceUidInFavorites:(NSString *)uid;

/** 子类可重写，用于延后初始化「更多」之外的首帧非必需 UI（如群聊 initMuteOverlay）。基类空实现。 */
- (void)rb_deferredSetupAfterMoreContent;
/** 子类重写以初始化「更多」面板；基类空实现，由 rb_deferredSetupAfterFirstFrame 延后调用。 */
- (void)initMoreContentView;

/** 在 reloadData/insertItems 前调用，清空布局阶段列表缓存，确保下一 layout 使用最新数据（卡顿优化用）。 */
- (void)rb_invalidateChattingListLayoutCache;

/** 滚动结束后刷新可见消息 cell 的气泡时间/已读与文字避让区（长文与末行同行时，cell 在滚动中会跳过 layoutManager 更新）。 */
- (void)rb_refreshVisibleBubbleTimeLayouts;

/** 布局/数据源回调中应使用本方法取列表，保证同一 layout pass 内与 numberOfItemsInSection 一致，避免快速滑动时堆叠错位。 */
- (NSArray<JSQMessage *> *)rb_chattingListForLayout;

/** 当前会话是否显示群成员昵称（布局前已缓存，供 FlowLayout/昵称高度等使用，避免热路径读 UserDefaults）。 */
- (BOOL)rb_showGroupMemberNicknameForCurrentChat;

/** 首屏若当前会话正在做 SQLite bootstrap 且列表为空，则先跳过那次空列表 reload，等 bootstrap 到达后再首刷。 */
@property (nonatomic, assign) BOOL rb_shouldDeferInitialChatListReloadUntilSqliteBootstrap;

/** 外部页面（如红包发送页）往当前会话追加了「我方发出」消息后调用：回到会话时刷新列表并滚到底部。 */
- (void)rb_notifyExternalOutgoingMessageAppended;

/** 在导航控制器真正发起 pop 前调用：若返回目标是消息列表，则提前把底层列表刷新到最新排序。 */
- (void)rb_prepareForNavigationPopToViewController:(UIViewController * _Nullable)toViewController reason:(NSString * _Nullable)reason;

- (void)rb_scrollChatToBottomAfterEnsuringLayoutAnimated:(BOOL)animated;
/** 当前聊天列表是否已近似停在底部（容忍一定误差），供返回页面后按需决定是否自动贴底。 */
- (BOOL)rb_isChatScrolledToBottomApproximatelyWithTolerance:(CGFloat)tolerance;

/** TGInputBar 模式下为 tg 内 textView，否则为 inputToolbar 内 textView（@、表情、发送等需统一走此入口）。 */
- (UITextView *)rb_currentComposerTextView;

///**
// * 当前正在单聊者的uid或群聊id（本方法目前仅用于跳转到聊天界面时，判断页面栈中的聊天界面是否要跳转的目标聊天类型，暂无他用，详见：[ViewControllerFactory goChatViewController:]等方法）。
// *
// * @return 返回当前正在聊天者的uid
// */
//- (NSString *)getTargetId;

/**
 子类可在本代理方法中实现聊天列表中的用户头像图片的获取逻辑。

 @param collectionView collectionView description
 @param indexPath indexPath description
 @return return value description
 */
- (UIImage *)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath;


//---------------------------------------------------------------------------------------------------
#pragma mark - Responding to collection view tap events（聊天列表的其它相关代理方法）

/**
 * 该消息是否可被撤回（子类可重写本方法实现自已的“撤回”功能权限可用逻辑）.
 *
 * @parem d 选中的消息数据对象引用
 * @return YES将在长按消息气泡时显示“撤回”功能，否则不显示
 */
-(BOOL)messageCanBeRevoke:(JSQMessage *)d;

// 撤回功能实现方法（请在子类中实现之）
-(void)doMessageRevokeImpl:(JSQMessage *)d;

// 删除功能实现方法（请在子类中实现之）
-(void)doMessageDeleteImpl:(JSQMessage *)d;

// 子类重写本方法，实现自已的图片消息转储参数配置等
- (NSString *) getImageMessageDownloadURL:(NSString *)fileName;

// 该消息是否未超出撤回时限
+ (BOOL)messageIsNotTimeoutForRevoke:(JSQMessage *)d;

/** 根据在线状态与最近登录时间生成导航栏副标题文案（供子类统一使用） */
+ (NSString *)navSubtitleForOnline:(BOOL)isOnline latestLoginTime2:(NSString *)time2Str;


//---------------------------------------------------------------------------------------------------
#pragma mark - 有关图片消息处理的方法

/**
 实现图片选择结果代理方法：图片（来自相册的图片、来自拍照的图片）消息的发送实现方法。
 <p>
 本代码方法被调用，即意味着已成功获得图片，其它乱七八糟的前置处理已经在中RBImagePickerWrapper封
 装处理好了。

 @param photo 图片对象
 @param tag debug的TAG
 */
- (void)processImagePickerComplete:(UIImage *)photo withTag:(NSString *)tag;


//---------------------------------------------------------------------------------------------------
#pragma mark - 有关语音留言处理和发送的方法

/**
  进入语音留言的录音功能。
 */
- (void)gotoVoiceRecord;

/**
 * 语音留言消息的发送实现方法。
 *
 * @param fileNameWillUpload 要上传的语音文件名
 */
- (void)processVoiceMessageSend:(NSString *)fileNameWillUpload;


//---------------------------------------------------------------------------------------------------
#pragma mark - 有关大文件处理和发送的方法

/**
  进入大文件消息的文件选择功能。
 */
- (void)openFilePicker;

// 大文件消息的发送实现方法。
- (void)processBigFileMessageSend:(NSString *)filePath fileName:(NSString *)fileName md5:(NSString *)fileMD5 fileLength:(long long)fileLength;


//---------------------------------------------------------------------------------------------------
#pragma mark - 有关短视频处理和发送的方法

/**
  打开短视频录制界面.
 */
- (void)openShortVideoRecorder;

// 短视频消息的发送实现方法。
- (void)processShortVideoMessageSend:(NSString *)videoSavedFilePath duration:(int)duration reachedMax:(BOOL)reachedMaxRecordTime fileName:(NSString *)fileName md5:(NSString *)fileMD5 fileLength:(long long)fileLength;


//---------------------------------------------------------------------------------------------------
#pragma mark - 有关名片消息处理的方法

/**
  打开好友选择列表界面（以便选择要发送的名片）。
 */
- (void)openUserChoose;

/**
  打开群选择列表界面（以便选择要发送的群名片）。
 */
- (void)openGroupChoose;

/**
 * 好友选择结果代理方法：可以在此方法中处理从用户选择列表中选择的用户进行进一步处理。
 *
 * @param selectedUser 选中的好友
 */
- (void)processUserChooseComplete:(ContactMeta *)selectedUser;


//---------------------------------------------------------------------------------------------------
#pragma mark - 收藏选择器

/**
 打开收藏选择器（弹出收藏列表，点击即发送到当前会话）。
*/
- (void)openFavoritesPicker;


//---------------------------------------------------------------------------------------------------
#pragma mark - 有关位置消息处理的方法

/**
 打开位置选择界面（以便选择要发送的位置）。
*/
- (void)openLocationChoose;

/**
 * 位置选择结果代理方法：可以在此方法中处理从地图选择的位置进行进一步处理。
 *
 * @param selectedLocation 选中的位置
 */
- (void)processLocationChooseComplete:(LocationMeta *)selectedLocation;


//---------------------------------------------------------------------------------------------------
#pragma mark - 消息”撤回”功能对应的方法

/**
 * 显示进度提示框。
 *
 * @param fpForMessage 被撤回消息对应的指纹码（如果是群聊，则此指纹码实际指的是父指纹码——即fingerPrintOfParent）
 */
- (void) showMessageRevokingProgess:(NSString *)fpForMessage;

/**
 * 隐藏进度提示框的显示。
 *
 * @param enforce true表示无条件强制进度提示框的显示，false表示只有当 fpForMessage 参数与当前正在撤回的指纹码一致才会取消显示哦
 * @param fpForMessage 被撤回消息对应的指纹码（如果是群聊，则此指纹码实际指的是父指纹码——即fingerPrintOfParent）
 */
- (void) hideMessageRevokingProgess:(BOOL)enforce fp:(NSString *)fpForMessage;

/**
 * 消息"撤回"功能实现。
 *
 * @param chatType 聊天类型，see {@link ChatType}
 * @param message  要撤回的消息位于聊天列表数据模型中的消息对象
 * @param toId 群聊时这表示群id，否则表示好友或陌生人uid
 * @param toName 本参数仅用于陌生人聊天模下表示发送者昵称，其它模式下请传null即可
 */
- (void) processMessageRevoke:(int)chatType message:(JSQMessage *)message toId:(NSString *)toId toName:(NSString *)toName;


//---------------------------------------------------------------------------------------------------
#pragma mark - 消息”删除”功能对应的方法

/**
 * 消息"删除"功能实现（有确认对话框）。
 *
 * @param chatType 聊天类型，see {@link ChatType}
 * @param fpForMessage  被删除消息的指纹码
 * @param forId 群聊时这表示群id，否则表示好友或陌生人uid
 */
- (void) processMessageDelete:(int)chatType fp:(NSString *)fpForMessage forId:(NSString *)forId;

/** 消息删除具体实现（先服务端后本地），子类可重写（如 10001 收藏夹走删除收藏接口） */
- (void)processMessageDeleteImpl:(int)chatType fp:(NSString *)fpForMessage forId:(NSString *)forId;


//---------------------------------------------------------------------------------------------------
#pragma mark - 消息”高亮”功能对应的方法（当前主要用于搜索功能中进入聊天界面时）

/**
 * 设置指定的消息高亮显示一次、并让该条消息滚动到列表可视区（高亮特性目前仅用于搜索功能进到聊天界面时，设置搜索到到的包含关键字的消）。
 *
 * @return YES表示高亮成功，否则不成功
 * @since 6.0
 */
- (BOOL)doHighlightOnceMessage;


//---------------------------------------------------------------------------------------------------
#pragma mark - 其它方法

/**
 默认将聊天文本框中的内容作为发送指uid的用户.
 
 @param message 要发送的文本消息
 @param toId 要发送给的目标（可能是uid或群id）
 @param sucessObs 消息发送成功后的回调block，可为空
 */
- (void)sendPlainTextMessage:(NSString *)message toId:(NSString *)toId forSucess:(ObserverCompletion)sucessObs;

/**
 默认将聊天文本框中的内容作为发送内分给好友。
 
 @param message 要发送的文本消息
 @param sucessObs 消息发送成功后的回调block，可为空
 */
- (void)sendPlainTextMessage:(NSString *)message forSucess:(ObserverCompletion)sucessObs;


//---------------------------------------------------------------------------------------------------
#pragma mark - 其它辅助方法

///**
// * 默认将聊天文本框中的内容作为发送内分给好友.
// */
//- (void)sendPlainTextMessage:(NSString *)message forSucess:(ObserverCompletion)sucessObs;

- (void)showBigImage4Received:(NSString *)imgHttpUrl;

- (void)showBigImage4Send:(UIImage *)img;// withName:(NSString *)imgFileName;

/**
 读取本地发出的消息图片（比如：图片消息中的图片、短视频的预览图、位置的预览图等），并尝试将其放入缓存中（放入SDImageCache缓存中管理是防止存在大量图片消息的情况下
 不至于发生内存占用过大的问题，由SDImageCache智能管理内存），以备后绪使用。

 @param fileName 图片消息的图片存储的文件名
 @return 返回nil表示没有成功读取到图片，否则返回图片对象
 */
- (UIImage *)loadLocalImg:(NSString *)fileName msgType:(int)msgType withTag:(NSString *)tag;

// 从当前界面回退
- (void)doBack:(BOOL)animated;

//// amr转换方法
//+ (NSString *)convertCAFtoAMR:(NSString *)originalAudioFilePath toDir:(NSString *)destAMRFileDir;

// 界面退出时的清理动作
- (void)deallocImpl;


//---------------------------------------------------------------------------------------------------
#pragma mark - 自定义导航栏（气泡标题 + 返回badge + 头像按钮）

@property (nonatomic, strong) UILabel  *navBadgeLabel;
@property (nonatomic, strong) UIView   *navTitleBubble;
@property (nonatomic, strong) UILabel  *navTitleLabel;
@property (nonatomic, strong) UILabel  *navSubtitleLabel;
@property (nonatomic, strong) UIButton *navAvatarButton;
/** 导航栏右侧头像图（与 navAvatarButton 叠放；供 RBAvatarView 挂载，勿用 UIButton.imageView） */
@property (nonatomic, strong, nullable) UIImageView *navAvatarImageView;
/** 与聊天同款磨砂自定义顶栏（系统 navigationItem 置空时使用）；标题用 rb_chromeNavigationBar.titleLabel */
@property (nonatomic, strong, nullable) RBChromeNavigationBar *rb_chromeNavigationBar;

/// 首帧极简导航栏（仅标题 + 返回），完整自定义导航栏延后到 rb_deferredSetupCustomNavigationBar
- (void)setupMinimalNavigationBar;
/// 仅恢复极简左侧返回按钮（子类重写 setupMinimalNavigationBar 时可调用）
- (void)rb_restoreMinimalBackButton;
/// 极简导航右侧「更多」按钮（子类重写 setupMinimalNavigationBar 时可调用）
- (UIBarButtonItem *)rb_minimalRightBarButtonItem;
/// 导航栏右侧圆形头像按钮（约 36pt；会赋值 self.navAvatarButton，便于 loadAvatar / 多选恢复）
- (UIBarButtonItem *)rb_rightCircularAvatarBarButtonItemWithAction:(SEL)action;
- (void)setupCustomNavigationBar;
/// 延后块内调用，用于替换极简导航栏为完整自定义导航栏；子类通过 rb_didSetupCustomNavigationBar 设置右侧/副标题等
- (void)rb_deferredSetupCustomNavigationBar;
/// 子类重写：在完整导航栏设置完成后设置右侧按钮、副标题等（如 loadPeerOnlineStatusForNav）
- (void)rb_didSetupCustomNavigationBar;

/** 聊天页自定义顶栏（隐藏系统 UINavigationBar 时使用）：将自定义视图放到右侧容器 */
- (void)rb_clearChatCustomNavRightHost;
- (void)rb_attachViewToChatCustomNavRight:(UIView *)view;
/** 弹出菜单锚点（如 10001 右侧胶囊）；无自定义顶栏时为 nil */
- (nullable UIView *)rb_anchorViewForChatNavMoreMenu;

/** 多选模式顶栏切换（避免 MessageMenu 分类访问私有 IBOutlet） */
- (void)rb_navBeginMultiSelectMode;
- (void)rb_navRestoreAfterExitMultiSelect;
/** 确保自定义顶栏已创建（陌生人聊天等仅改右侧时调用） */
- (void)rb_ensureChatCustomNavigationBarInstalled;
/// 首帧延后块：气泡图、reloadData、表情/回到底部等；子类重写时若需保留基类逻辑请调用 [super rb_deferredSetupAfterFirstFrame]
- (void)rb_deferredSetupAfterFirstFrame;
- (void)updateNavBadgeCount:(int)count;
- (void)updateNavSubtitle:(NSString *)subtitle;
- (void)updateNavAvatarWithImage:(UIImage *)image;
- (void)refreshNavBadge;
- (void)onNavBackTapped;
- (void)onNavAvatarTapped;
- (void)onNavTitleTapped;

/// 多选模式退出时，若子类返回非 nil 则用其作为右侧按钮（如 10001 的搜索按钮），否则恢复头像按钮
- (UIBarButtonItem *)customRightBarButtonItemForRestore;

/// 在聊天页顶部弹出/收起搜索框（子类在点击导航栏搜索图标时调用）
- (void)showChatSearchBarAnimated:(BOOL)animated;
- (void)hideChatSearchBarAnimated:(BOOL)animated;

//---------------------------------------------------------------------------------------------------
#pragma mark - 消息"多选"功能对应的属性和方法

/** 是否处于消息多选模式 */
@property (nonatomic, assign) BOOL isMultiSelectMode;

/** 多选模式下已选中消息的fingerprint集合 */
@property (nonatomic, strong) NSMutableSet<NSString *> *multiSelectedFingerprints;

/** 多选模式底部工具栏 */
@property (nonatomic, strong) UIView *multiSelectToolbar;

/** 进入消息多选模式 */
- (void)enterMultiSelectMode;

/** 退出消息多选模式 */
- (void)exitMultiSelectMode;

/** 多选模式下执行批量转发 */
- (void)doMultiSelectForward;

/** 多选模式下执行批量删除 */
- (void)doMultiSelectDelete;

/** 多选模式下执行批量收藏 */
- (void)doMultiSelectFavorite;


@end
