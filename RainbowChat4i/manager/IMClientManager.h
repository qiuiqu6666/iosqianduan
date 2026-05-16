//telegram @wz662
#import <Foundation/Foundation.h>
#import "ChatBaseEventImpl.h"
#import "ChatMessageEventImpl.h"
#import "MessageQoSEventImpl.h"
#import "MessagesProvider.h"
#import "AlarmsProvider.h"
#import "UserEntity.h"
#import "FriendsListProvider.h"
#import "GroupsProvider.h"
#import "GroupsMessagesProvider.h"
#import "MessageRevokingManager.h"
#import "FaceDataProvider.h"
#import "FriendsReqProvider.h"


@interface IMClientManager : NSObject

/**
 当前登陆用户的个人信息全局对象。
 本对象在用户登陆成功后被设置，后绪的个人信息显示、更新等统一使用本对象来完成即可。
 */
@property (strong, nonatomic) UserEntity *localUserInfo;

/**
 * 当前正在聊天中的用户UID.
 * <p>
 * <b>重要说明：</b>此变量只在{@link ChatActivity}处于前景（即在onResume()方法调用的情况下）被
 * 设置、在{@link ChatActivity}处于非激活或关闭（即在onPause()方法调用的情况下）被取消设置（置成null）
 */
@property (strong, nonatomic) NSString *currentFrontChattingUserUID;

/**
 * 当前正在临时聊天中的用户UID.
 * <p>
 * <b>重要说明：</b>此变量只在{@link TempChatActivity}处于前景（即在onResume()方法调用的情况下）被
 * 设置、在{@link TempChatActivity}处于非激活或关闭（即在onPause()方法调用的情况下）被取消设置（置成null）
 */
// 不与currentFrontChattingUserUID共用一个表示处于聊天界面时，是因为正式聊天和临时聊天是
// 2个界面，正好处于正式聊天也不意味着临时聊天进行中，所以不能撒（相反也一样）
@property (strong, nonatomic) NSString *currentFrontTempChattingUserUID;

/**
 * 当前正在群组聊天中的groupId.
 * <p>
 * 目前其实没有完全实现群组聊天功能，但BBS功能是群组聊天的前身，目前为了实现BBS功能已把群组聊天的有些基础设施部分实现了.
 * 目前所叫的“群组”聊天实际是可以理解为BBS专用聊天，而非完全的群组（多群组）聊天功能哦。
 * <p>
 * <b>重要说明：</b>此变量只在{@link GroupChattingActivity}处于前景（即在onResume()方法调用的情况下）被
 * 设置、在{@link TempChatActivity}处于非激活或关闭（即在onPause()方法调用的情况下）被取消设置（置成null）
 *
 */
@property (strong, nonatomic) NSString *currentFrontGroupChattingGroupID;

/*!
 * 取得本类实例的唯一公开方法。
 * <p>
 * 本类目前在APP运行中是以单例的形式存活，请一定注意这一点哦。
 *
 * @return 当前对象的实例引用
 */
+ (IMClientManager *)sharedInstance;

/**
 * IM框架初始化方法，本方法在连接IM服务器前必须被调用1次，否则IM底层框架将无法工作。
 */
- (void)initMobileIMSDK;

- (ChatMessageEventImpl *) getTransDataListener;
- (ChatBaseEventImpl *) getBaseEventListener;
- (MessageQoSEventImpl *) getMessageQoSListener;

- (MessagesProvider *) getMessagesProvider;
- (GroupsMessagesProvider *)getGroupsMessagesProvider;
- (AlarmsProvider *) getAlarmsProvider;
- (FriendsListProvider *) getFriendsListProvider;
- (GroupsProvider *) getGroupsProvider;
- (FaceDataProvider *) getFaceDataProvider; /// 表情
- (FriendsReqProvider *) getFriendsReqProvider;

- (MessageRevokingManager *) getMessageRevokingManager;

- (void)setLiveStatusChangeObs:(ObserverCompletion)liveStatusChangeObs;
- (ObserverCompletion) getLiveStatusChangeObs;

/**
 * 是本地用户。
 *
 * @param uid 用户uid
 * @return true表示是本地用户，否则不是
 */
- (BOOL)isLocalUser:(NSString *)uid;

/**
 * 退出IM服务器连接并释放IM所占的所有资源（含退出IM框架连接、再释放IM框架所占的资源）。
 * <p>
 * 在切换账号等功能场景下，使用本方法可以保证重新登陆时IM框架已回到重初状态，从而完全正常的重新登陆。
 */
- (void)doLogoutIMServer;

@end
