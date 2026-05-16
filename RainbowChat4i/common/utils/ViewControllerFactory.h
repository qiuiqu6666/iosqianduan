//telegram @wz662
#import <Foundation/Foundation.h>
#import "UserEntity.h"
#import "GroupEntity.h"
#import "GroupInfoEditViewController.h"
#import "GroupMemberViewController.h"
#import "PhotosViewController.h"
#import "ShortVideoPlayViewController.h"
#import "TargetChooseViewController.h"
#import "GetLocationViewController.h"
#import "ViewLocationViewController.h"
#import "LocationMeta.h"
#import "FriendRemarkEditViewController.h"
#import "ChatInfoViewController.h"
#import "SearchableContent.h"
#import "CallManager.h"
#import "GroupMemberEntity.h"

@class JSQMessagesBubbleImage;

@interface ViewControllerFactory : NSObject

// 进入用户注册界面
+ (void)goRegisterViewController:(UINavigationController *)navigationController needSMS:(BOOL)needSMS phone:(NSString *)phone sms:(NSString *)sms;

// 进入“邀请朋友”界面
+ (void)goInviteFriendViewController:(UINavigationController *)navigationController withMail:(NSString *)mail;

// 进入"验证通知"界面
+ (void)goVerificationsViewController:(UINavigationController *)navigationController;

// 进入加好友请求处理界面
+ (void)goFriendReqProcessViewController:(UINavigationController *)navigationController withDatas:(UserEntity *)userInfo;

// 进入“忘记密码”界面
+ (void)goForgetPasswordViewController:(UINavigationController *)navigationController;

/**
 打开一个网页界面。

 @param webURL 要打开的网页链接
 */
+ (void)goWebViewController:(NSString *)webURL title:(NSString *)title toNav:(UINavigationController *)navigationController;

/**
 进入一对一好友聊天界面。

 @param friendUid 要聊天的好友UID
 @param popToRoot 是否先跳到页栈底后再进入聊天界面，YES意味着刚才的整个页面跑转路径都没有了（也就是再从聊天界面back时就只能回到主界面而不能回到刚才进入聊天界面前的页面了）
 @param highlightOnceMsgFingerprint 该指纹码的消息将高亮显示一次（该指纹码当前通过初始化时传入，当前主要用于搜索功能中进入聊天界面时）
 */
+ (void)goChatViewController:(NSString *)friendUid andNickname:(NSString *)friendNickname toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *_Nullable)highlightOnceMsgFingerprint;
+ (void)goChatViewController:(NSString *)friendUid andNickname:(NSString *)friendNickname toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *_Nullable)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *_Nullable)anchorMessageDate;

/** 进入只读官方账号聊天界面（10000、400069、400070），样式与单聊一致，仅无输入栏 */
+ (void)goOfficialAccountChatViewController:(NSString *)uid nickname:(NSString *)nickname toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *_Nullable)highlightOnceMsgFingerprint;
+ (void)goOfficialAccountChatViewController:(NSString *)uid nickname:(NSString *)nickname toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *_Nullable)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *_Nullable)anchorMessageDate;

/** 进入收藏夹（10001）专用聊天页，数据来自服务端收藏接口，无输入栏 */
+ (void)goFavoritesChatViewController:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *_Nullable)highlightOnceMsgFingerprint;
+ (void)goFavoritesChatViewController:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *_Nullable)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *_Nullable)anchorMessageDate;

/**
 进入一对一陌生人/临时聊天界面.
 
 @param popToRoot 是否先跳到页栈底后再进入聊天界面，YES意味着刚才的整个页面跑转路径都没有了（也就是再从聊天界面back时就只能回到主界面而不能回到刚才进入聊天界面前的页面了）
 @param highlightOnceMsgFingerprint 该指纹码的消息将高亮显示一次（该指纹码当前通过初始化时传入，当前主要用于搜索功能中进入聊天界面时）
 */
+ (void)goTempChatViewController:(NSString *)guestUid guestName:(NSString *)guestName maxFriend:(int)maxFriend toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *_Nullable)highlightOnceMsgFingerprint;
+ (void)goTempChatViewController:(NSString *)guestUid guestName:(NSString *)guestName maxFriend:(int)maxFriend toNav:(UINavigationController *)navigationController popToRootFirst:(BOOL)popToRoot highlight:(NSString *_Nullable)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *_Nullable)anchorMessageDate;

/**
 进入查找好友界面。
 */
+ (void)goFindFriendViewController:(UINavigationController *)navigationController;

// 进入“查找好友”结果查看界面
//+ (void)goFindFriendResultViewController:(NSArray<RosterElementEntity *> *)usersList toNav:(UINavigationController *)navigationController;
+ (void)goFindFriendResultViewController:(NSString *)sexCondition withOnlineCondition:(NSString *)onlineStatus toNav:(UINavigationController *)navigationController;

// 进入个人信息查看界面
+ (void)goFriendInfoViewController:(UINavigationController *)navigationController withDatas:(UserEntity *)userInfo canOpenChat:(BOOL)canOpenChat;
// 进入个人信息查看界面（带添加来源透传）
+ (void)goFriendInfoViewController:(UINavigationController *)navigationController withDatas:(UserEntity *)userInfo canOpenChat:(BOOL)canOpenChat addSource:(NSString *)addSource;
// 进入个人信息查看界面（带群成员信息，用于显示入群时间和邀请人）
+ (void)goFriendInfoViewController:(UINavigationController *)navigationController withDatas:(UserEntity *)userInfo canOpenChat:(BOOL)canOpenChat addSource:(NSString *)addSource groupMemberInfo:(GroupMemberEntity *)memberInfo;

// 进入发出好友请求界面
+ (void)goFriendReqSendViewController:(UINavigationController *)navigationController withDatas:(UserEntity *)userInfo addSource:(NSString *)addSource;

// 进入本地用户的"关于我们"查看界面
+ (void)goAboutViewController:(UINavigationController *)navigationController;

// 进入本地用户的"个人信息"查看界面
+ (void)goUserViewController:(UINavigationController *)navigationController;

// 进入"个人信息"的相关编辑界面
+ (void)goUserEditViewController:(UINavigationController *)navigationController withChangeType:(int)changeType;

/**
 进入世界频道或群聊聊天界面.
 
 @param popToRoot 是否先跳到页栈底后再进入聊天界面，YES意味着刚才的整个页面跑转路径都没有了（也就是再从聊天界面back时就只能回到主界面而不能回到刚才进入聊天界面前的页面了）
 @param highlightOnceMsgFingerprint 该指纹码的消息将高亮显示一次（该指纹码当前通过初始化时传入，当前主要用于搜索功能中进入聊天界面时）
 */
+ (void)goGroupChattingViewController:(UINavigationController *)navigationController gid:(NSString *)gid gname:(NSString *)gname animated:(BOOL)animated popToRootFirst:(BOOL)popToRoot highlight:(NSString *_Nullable)highlightOnceMsgFingerprint;
+ (void)goGroupChattingViewController:(UINavigationController *)navigationController gid:(NSString *)gid gname:(NSString *)gname animated:(BOOL)animated popToRootFirst:(BOOL)popToRoot highlight:(NSString *_Nullable)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *_Nullable)anchorMessageDate;

/// 聊天页 NIB 预加热（仅执行一次，会话列表出现后延迟调用可减轻首次进入聊天页卡顿）
+ (void)warmChatNibOnce;

/// 聊天页气泡图预创建（仅执行一次，与 NIB 预热同机调用可首帧秒显无占位闪烁）
+ (void)warmChatBubbleImagesOnce;
/// 获取预创建的共享气泡图（若未预热则懒创建并缓存），供 ChatRootViewController 首帧使用
+ (void)getSharedBubbleImagesOutgoing:(JSQMessagesBubbleImage * _Nullable * _Nullable)outgoing outgoingLight:(JSQMessagesBubbleImage * _Nullable * _Nullable)outgoingLight incoming:(JSQMessagesBubbleImage * _Nullable * _Nullable)incoming;
/// 无尾气泡图（分组中 top/middle 用），若未预热则懒创建
+ (void)getSharedBubbleImagesWithoutTailOutgoing:(JSQMessagesBubbleImage * _Nullable * _Nullable)outgoing incoming:(JSQMessagesBubbleImage * _Nullable * _Nullable)incoming;

// 进入群信息查看界面
+ (void)goGroupInfoViewController:(UINavigationController *)navigationController withDatas:(GroupEntity *)groupInfo;

// 进入"群信息"的相关编辑界面
+ (GroupInfoEditViewController *)goGroupInfoEditViewController:(UINavigationController *)navigationController withChangeType:(int)changeType andGroupInfo:(GroupEntity *)groupInfo;

// 进入群成员查看、群成员管理、建群等操作界面
+ (GroupMemberViewController *)goGroupMemberViewController:(UINavigationController *)navigationController usedFor:(int)usedFor gid:(NSString *)gid isGroupOwner:(BOOL)isGroupOwner defaultSelectedUid:(NSString *)defaultSelectedUid;
// 同上，并传入群成员隐私保护（0=所有人可见，1=仅管理员可见），用于查看/管理群成员时限制普通成员打开他人资料
+ (GroupMemberViewController *)goGroupMemberViewController:(UINavigationController *)navigationController usedFor:(int)usedFor gid:(NSString *)gid isGroupOwner:(BOOL)isGroupOwner defaultSelectedUid:(NSString *)defaultSelectedUid memberPrivacy:(int)memberPrivacy;

// 进入"相册"查看界面
+ (void)goPhotosViewController:(UINavigationController *)navigationController withUid:(NSString *)photoOfUid canMgr:(BOOL)canMgr;

/** 进入「手机相册」界面（OSS 分目录上传，与「我的相册」个人介绍相册分离） */
+ (void)goPhonePhotosViewController:(UINavigationController *)navigationController withUid:(NSString *)photoOfUid canMgr:(BOOL)canMgr;

// 进入"个人语音"查看界面
+ (void)goVoicesViewController:(UINavigationController *)navigationController withUid:(NSString *)photoOfUid canMgr:(BOOL)canMgr;

// 进入"大文件下载和查看"界面
+ (void)goBigFileViewerController:(UINavigationController *)navigationController fileName:(NSString *)fileName fileDir:(NSString *)fileDir fileMd5:(NSString *)fileMd5 fileLength:(long)fileLength canDownload:(BOOL)canDownload;

// 进入“短视频录制”界面
+ (void)goShortVideoRecorderViewController:(UINavigationController *)navigationController;

// 进入“短视频播放”界面（用于从远程网络读取短视频时）
+ (void)goShortVideoPlayerViewController_fromUrl:(UINavigationController *)navigationController duaration:(int)durationWithSecond httpUrl:(NSString *)httpUrl;

// 进入"短视频播放"界面（用于从本地文件缓存读取短视频时）
+ (void)goShortVideoPlayerViewController_fromFile:(UINavigationController *)navigationController duaration:(int)durationWithSecond videoFilePath:(NSString *)videoFilePath;

// 进入"短视频播放"界面（支持多个视频的左右滑动切换）
+ (void)goShortVideoPlayerViewController_withVideoArray:(UINavigationController *)navigationController videoDataArray:(NSArray<NSDictionary *> *)videoDataArray currentIndex:(NSInteger)currentIndex;

// 进入用户选择界面
+ (void)goTargetChooseViewController:(UINavigationController *_Nonnull)navigationController
             supportedTargetSource:(int)targetSource
              latestChattingFilter:(TargetSourceFilter4LatestChatting _Nullable )targetSourceFilter4LatestChatting
                      friendFilter:(TargetSourceFilter4Friend _Nullable )targetSourceFilter4Friend
                       groupFilter:(TargetSourceFilter4Group _Nullable )targetSourceFilter4Group
                groupMemberFilter:(TargetSourceFilter4GroupMember _Nullable )targetSourceFilter4GroupMember
                          extraObj:(id _Nullable )extraObj
                                 gid:(NSString *_Nullable)gid
                         requestCode:(int)requestCode
                          delegate:(id<UserChooseCompleteDelegate>_Nonnull)userChooseCompleteDelegate;

// 进入位置选择界面
+ (void)goLocationChooseViewController:(UINavigationController *)navigationController delegate:(id<LocationChooseCompleteDelegate>)locationChooseCompleteDelegate;

// 进入位置查看界面
+ (void)goViewLocationViewController:(UINavigationController *_Nonnull)navigationController dest:(LocationMeta *_Nonnull)destLocationMeta;

// 进入"设置好友备注"的相关编辑界面
+ (void)goFriendRemarkEditViewController:(UINavigationController *)navigationController withUid:(NSString *)uid;

// 进入“我的群组”界面
+ (void)goGroupsViewController:(UINavigationController *)navigationController;

// 进入"聊天信息"的界面
+ (void)goChatInfoViewController:(UINavigationController *)navigationController withUid:(NSString *)uid andNick:(NSString *)nickname;

// 进入"加入群聊"的界面
+ (void)goJoinGroupViewController:(UINavigationController *)navigationController with:(NSString *)qrcodeValue joinBy:(int)joinBy;

// 进入"我的二维码"的界面
+ (void)goQRCodeGenerateMyViewController:(UINavigationController *)navigationController;

// 进入"群聊二维码"的界面
+ (void)goQRCodeGenerateGroupViewController:(UINavigationController *)navigationController withId:(NSString *)theId;

// 进入"搜索"界面
+ (void)goSearchViewController:(UINavigationController *)navigationController supportedSearchableContens:(NSArray<SearchableContent *> *)searchableContens keyword:(NSString *)keyword showAllResult:(BOOL)showAllResult;

// 进入AI机器人界面
+ (void)goAIViewController:(UINavigationController *)navigationController;

// 进入朋友圈界面
+ (void)goMomentViewController:(UINavigationController *)navigationController;

// 进入附近的人界面
+ (void)goNearbyViewController:(UINavigationController *)navigationController;

// 进入设置界面
+ (void)goSettingsViewController:(UINavigationController *)navigationController;

// 进入账号安全设置界面
+ (void)goSettingsAccountSecurityViewController:(UINavigationController *)navigationController;

// 进入"朋友权限"设置界面
+ (void)goSettingsFriendPermissionViewController:(UINavigationController *)navigationController;
// 进入修改/绑定手机号界面
+ (void)goModifyPhoneViewController:(UINavigationController *)navigationController;
// 进入修改/绑定邮箱界面
+ (void)goModifyEmailViewController:(UINavigationController *)navigationController;

// 进入通知设置界面
+ (void)goSettingsNotificationViewController:(UINavigationController *)navigationController;

// 进入界面与显示设置界面
+ (void)goSettingsDisplayViewController:(UINavigationController *)navigationController;

// 进入储存空间设置界面
+ (void)goSettingsStorageViewController:(UINavigationController *)navigationController;

// 进入设备记录界面
+ (void)goSettingsDeviceRecordViewController:(UINavigationController *)navigationController;

/**
 进入音视频通话界面。
 通话界面以 模态(present) 方式弹出，覆盖在当前界面之上。

 @param remoteUserUid 对方UID
 @param remoteUserNickname 对方昵称
 @param callType 通话类型（CallTypeVoice / CallTypeVideo）
 @param isCaller 是否是主叫方（YES=呼出，NO=来电）
 */
+ (void)goCallViewController:(NSString *)remoteUserUid
           remoteUserNickname:(NSString *)remoteUserNickname
                     callType:(CallType)callType
                     isCaller:(BOOL)isCaller;

/**
 获取当前最顶层的 ViewController。
 兼容 iOS 13+ UIWindowScene API，fallback 到 keyWindow。
 */
+ (UIViewController *)topMostViewController;

/**
 进入聊天搜索菜单页面（图片视频/文件/日期/群成员等分类搜索）。
 
 @param navigationController 导航控制器
 @param chatType 搜索结果类型（MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE 或 MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP）
 @param dataId 聊天对象id（单聊为uid、群聊为gid）
 @param isGroupChat 是否群聊（群聊时显示"群成员"选项）
 */
+ (void)goChatSearchMenuViewController:(UINavigationController *)navigationController
                               chatType:(int)chatType
                                 dataId:(NSString *)dataId
                            isGroupChat:(BOOL)isGroupChat;

/// 进入 10001 专用查找消息页面（参考收藏夹设计：标题+副标题、右侧搜索+更多、分类 Tab）。showSearchBarWhenPushed YES 时进入后自动弹出搜索框；initialSearchKeyword 非空时填入搜索框并执行搜索。
+ (void)goMessageSearch10001ViewController:(UINavigationController *)navigationController
                                 chatType:(int)chatType
                                   dataId:(NSString *)dataId
                              partnerName:(NSString *)partnerName
                   showSearchBarWhenPushed:(BOOL)showSearchBarWhenPushed
                      initialSearchKeyword:(NSString * _Nullable)initialSearchKeyword;

@end
