//telegram @wz662
#import "IMClientManager.h"
#import "ConfigEntity.h"
#import "HttpRestHelper.h"
#import "AutoReLoginDaemon.h"
#import "IMServerAddressManager.h"


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface IMClientManager ()

/* MobileIMSDK是否已被初始化. true表示已初化完成，否则未初始化. */
@property (nonatomic) BOOL _init;

/**
 * MobileIMSDK的基础通信消息的回调事件实现类（回调事件可以是：登陆成功事件 通知、掉线事件通知等）。
 * <p>
 * 通过 [ClientCoreSDK setChatBaseEvent:] 方法设置之，可实现回调事件的通知和处理。
 */
@property (strong, nonatomic) ChatBaseEventImpl *baseEventListener;

/**
 * MobileIMSDK的通用数据通信消息的回调事件接口（回调事件可以是：收到聊天数据事件 通知、服务端返回的
 * 错误信息事件通知等）。
 * <p>
 * 通过 [ClientCoreSDK setChatTransDataEvent:] 方法设置之，可实现回调事件的通知和处理。
 */
@property (strong, nonatomic) ChatMessageEventImpl *transDataListener;

/**
 * MobileIMSDK的QoS质量保证机制的回调事件实现类。
 * <p>
 * 通过 [ClientCoreSDK setMessageQoSEvent:] 方法设置之，可实现消息已被收到或未成功送出的通知和处理。
 */
@property (strong, nonatomic) MessageQoSEventImpl *messageQoSListener;

/** 一对一聊天(含好友聊天、陌生人聊天)消息数据提供者(key=uid，value=与每个好友或陌生人的消息集合)。 */
@property (strong, nonatomic) MessagesProvider *messagesProvider;
/** 普通群聊/世界频道聊天消息的数据提供者(key=gid，value=与每个群的消息集合)*/
@property (strong, nonatomic) GroupsMessagesProvider *groupsMessagesProvider;
/** 首页“消息”提示信息的数据提供者 */
@property (nonatomic) AlarmsProvider *alarmsProvider;
/** "我"的好友列表数据提供者 */
@property (nonatomic) FriendsListProvider *friendsListProvider;
/** "我"的群组信息列表数据提供者 */
@property (strong, nonatomic) GroupsProvider *groupsProvider;
/** F表情 */
@property (nonatomic) FaceDataProvider *faceDataProvider;
/** 加好友请求数据提供者 */
@property (nonatomic) FriendsReqProvider *friendsReqProvider;

/** 消息"撤回"管理器 */
@property (strong, nonatomic) MessageRevokingManager *messageRevokingManager;

/**
 * 好友上下线通知观察者。
 *
 * 本对象用于保存好友的上下线通知观察者哦（全局只有一个这样的观察者）.
 * <b>说明：</b>本观察者被通知时，update方法的data参数收到的将是一个String[]数组：元素0是昵称、元素1是上下线状态、元素2是uid.
 * @see RosterElementEntity.LIVE_STATUS_ONLINE
 * @see RosterElementEntity.LIVE_STATUS_OFFLINE
 */
@property (nonatomic, copy) ObserverCompletion liveStatusChangeObs;// block代码块一定要用copy属性，否则报错！

@end


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation IMClientManager

// 本类的单例对象
static IMClientManager *instance = nil;

+ (IMClientManager *)sharedInstance
{
    if (instance == nil){
        @synchronized (self) {
            if (instance == nil) {
                instance = [[super allocWithZone:NULL] init];
            }
        }
    }
    return instance;
}

/*
 *  重写init实例方法实现。
 *
 *  @return
 *  @see [NSObject init:]
 */
- (id)init
{
    if (![super init])
        return nil;
    
    return self;
}

/**
 * IM框架初始化方法，本方法在退出APP前必须被调用1次，否则IM底层框架将无法工作。
 */
- (void)initMobileIMSDK
{
    if(!self._init)
    {        
        // ========== 多IP轮询管理器初始化 ==========
        // 使用候选IP列表初始化多IP管理器，支持连接失败时自动切换到下一个IP
        [[IMServerAddressManager sharedInstance] setupWithIPList:IM_SERVER_IP_LIST defaultPort:IM_SERVER_PORT];
        
        // 从多IP管理器获取当前最优服务器地址
        IMServerAddress *bestServer = [[IMServerAddressManager sharedInstance] currentServer];
        NSString *serverIp = bestServer ? bestServer.ip : IM_SERVER_IP;
        int serverPort = bestServer ? bestServer.port : IM_SERVER_PORT;
        
        // 设置IM聊天服务端IP地址或域名
        [ConfigEntity setServerIp:serverIp];
        // 设置IM聊天服务端的UDP监听端口（不设置则默认是9903）
        [ConfigEntity setServerPort:serverPort];
        
        NSLog(@"【IMClientManager】IM服务器地址已设置: %@:%d (候选IP总数: %lu)",
              serverIp, serverPort, (unsigned long)[[IMServerAddressManager sharedInstance] serverCount]);
        
        // 设置重连尝试间隔为2秒
        [AutoReLoginDaemon setAUTO_RE_LOGIN_INTERVAL:2000];
        
        // 设置本地客户端的网络兼听端口，此端口可随便设置，只要不与其它手机端程
        // 序端口冲突即可（不设置则默认是8901，如果设置为-1则表示由系统自动分配端口）
//      [ConfigEntity setLocalUdpSendAndListeningPort:8901];

        // MobileIMSDK核心IM框架的敏感度模式设置
        [ConfigEntity setSenseMode:SenseMode5S];
        
        // 开始/关闭SDK的Debug信息
        [ClientCoreSDK setENABLED_DEBUG:NO];
        
        // 设置最大TCP帧内容长度（不设置则默认最大是 6 * 1024字节）
//      [TCPFrameCodec setTCP_FRAME_MAX_BODY_LENGTH:60 * 1024];
        
        // 开启SSL/TLS加密传输（请务必确保服务端也已开启SSL，否则将无法完成SSL握手）
//      [ClientCoreSDK setSSL:YES];
        
        // 设置事件回调
        self.baseEventListener = [[ChatBaseEventImpl alloc] init];
        self.transDataListener = [[ChatMessageEventImpl alloc] init];
        self.messageQoSListener = [[MessageQoSEventImpl alloc] init];
        [ClientCoreSDK sharedInstance].chatBaseEvent = self.baseEventListener;
        [ClientCoreSDK sharedInstance].chatMessageEvent = self.transDataListener;
        [ClientCoreSDK sharedInstance].messageQoSEvent = self.messageQoSListener;

        // 清空本量中的关键全局变量
        self.localUserInfo = nil;
        self.currentFrontChattingUserUID = nil;

        // 重置关键数据模型变量
        self.messagesProvider = [[MessagesProvider alloc] init];
        self.groupsMessagesProvider = [[GroupsMessagesProvider alloc] init];
        self.alarmsProvider = [[AlarmsProvider alloc] init];
        self.friendsListProvider = [[FriendsListProvider alloc] init];
        self.groupsProvider = [[GroupsProvider alloc] init];
        // F表情
        self.faceDataProvider = [[FaceDataProvider alloc] init];
        self.friendsReqProvider = [[FriendsReqProvider alloc] init];
        
        // 实例化消息"撤回"管理器
        self.messageRevokingManager = [[MessageRevokingManager alloc] init];

        self._init = YES;
    }
}

/**
 * 释放IM框架所占用的资源，在退出登陆时请务必调用本方法，否则重
 * 新登陆将不能正常实现（指APP进程不退出时切换账号这种情况）。
 */
- (void)releaseMobileIMSDK
{
    // 释放IM核心库资源
    [[ClientCoreSDK sharedInstance] releaseCore];

    // 重置本类的初始化标识
    [self resetInitFlag];

    // 清空设置的回调
    [ClientCoreSDK sharedInstance].chatBaseEvent = nil;
    [ClientCoreSDK sharedInstance].chatMessageEvent = nil;
    [ClientCoreSDK sharedInstance].messageQoSEvent = nil;

    // 清空本量中的关键全局变量
    self.localUserInfo = nil;
    self.currentFrontChattingUserUID = nil;

    // 重置关键数据模型变量
    self.messagesProvider = nil;
    self.groupsMessagesProvider = nil;
    self.alarmsProvider = nil;
    self.friendsListProvider = nil;
    self.groupsProvider = nil;
    // F表情
    self.faceDataProvider = nil;
    self.friendsReqProvider = nil;
    
    // 清空撤回消息管理器中的数据集合
    [self.messageRevokingManager clear];
}

/**
 * 重置本类的初始化标识。
 */
- (void)resetInitFlag
{
    self._init = NO;
}

- (ChatMessageEventImpl *) getTransDataListener
{
    return self.transDataListener;
}
- (ChatBaseEventImpl *) getBaseEventListener
{
    return self.baseEventListener;
}
- (MessageQoSEventImpl *) getMessageQoSListener
{
    return self.messageQoSListener;
}

- (MessagesProvider *)getMessagesProvider
{
    return self.messagesProvider;
}

- (GroupsMessagesProvider *)getGroupsMessagesProvider
{
    return self.groupsMessagesProvider;
}

- (AlarmsProvider *)getAlarmsProvider
{
    return self.alarmsProvider;
}

- (FriendsListProvider *) getFriendsListProvider;
{
    return self.friendsListProvider;
}

- (GroupsProvider *) getGroupsProvider;
{
    return self.groupsProvider;
}

// F表情
- (FaceDataProvider *) getFaceDataProvider
{
    return self.faceDataProvider;
}

- (FriendsReqProvider *) getFriendsReqProvider
{
    return self.friendsReqProvider;
}

- (MessageRevokingManager *) getMessageRevokingManager;
{
    return self.messageRevokingManager;
}

- (void)setLiveStatusChangeObs:(ObserverCompletion)liveStatusChangeObs
{
    _liveStatusChangeObs = liveStatusChangeObs;
}
- (ObserverCompletion) getLiveStatusChangeObs
{
    return self.liveStatusChangeObs;
}

// 是否本地用户
- (BOOL)isLocalUser:(NSString *)uid{
    return (self.localUserInfo != nil && uid != nil && [uid isEqualToString:self.localUserInfo.user_uid]);
}

/**
 * 退出IM服务器连接并释放IM所占的所有资源（含退出IM框架连接、再释放IM框架所占的资源）。
 * <p>
 * 在切换账号等功能场景下，使用本方法可以保证重新登陆时IM框架已回到重初状态，从而完全正常的重新登陆。
 */
- (void)doLogoutIMServer
{
    // 发出退出IM服务器的请求包
    int code = [[LocalDataSender sharedInstance] sendLoginout];
    if(code == COMMON_CODE_OK){
        DDLogDebug(@"[IMClientManager.logoutIM] 注销IM服务器的登陆请求已完成。。。" );
    } else {
        DDLogWarn(@"[IMClientManager.logoutIM] 注销登陆请求发送失败，错误码：%d", code);
    }

    // 等待100毫秒，不然logout指令还没有发出去，IM资源（包括手机网络通信功能）就被释放罗
    [NSThread sleepForTimeInterval:0.100f];   // 100毫秒

    // 释放IM所占资源
    [self releaseMobileIMSDK];
}

@end
