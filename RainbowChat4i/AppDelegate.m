//telegram @wz662
#import "AppDelegate.h"
#import "ClientCoreSDK.h"
#import "ToolKits.h"
#import "PErrorResponse.h"
#import "CharsetHelper.h"
#import "Protocal.h"
#import "ClientCoreSDK.h"
#import "ChatMessageEventImpl.h"
#import "ChatBaseEventImpl.h"
#import "MessageQoSEventImpl.h"
#import "KeepAliveDaemon.h"
#import "AutoReLoginDaemon.h"
#import "ConfigEntity.h"
#import "LoginViewController.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "MainTabsViewController.h"
#import "UIViewController+Ext.h"
//#import "TempChatMsgDTO.h"
#import "NavigationController.h"
#import "HcdGuideView.h"
#import "MyDataBase.h"
#import "UserDefaultsToolKits.h"
#import "LocalPushHelper.h"
#import "BigFileDownloadManager.h"
#import "MBProgressHUD.h"
#import "BasicTool.h"
#import "CallKitManager.h"
#import "AFNetworkReachabilityManager.h"
#import <AudioToolbox/AudioToolbox.h>

#include <arpa/inet.h>
#import <AMapFoundationKit/AMapFoundationKit.h>

// ========== 多IP轮询 & 指数退避重连 ==========
#import "IMServerAddressManager.h"
#import "IMReconnectPolicy.h"
// ========== SyncKey 多端增量同步 ==========
#import "QoS4ReciveDaemon.h"
#import "QueryOfflineChatMsgAsync.h"
#import "Default.h"
#import "NotificationCenterFactory.h"
// ========== 推送点击导航 ==========
#import "ViewControllerFactory.h"
#import "AlarmsViewController.h"
#import "AlarmType.h"
#import "CallManager.h"
#import "CallPiPManager.h"
#import "PhoneAlbumLibrarySync.h"

//#import "HttpBigFileDownloadTask.h"
//#import "ReceivedFileHelper.h"


@interface AppDelegate ()

/// 在 `makeKeyAndVisible` 后下一主线程 runloop 再执行，减轻首帧前主线程压力
- (void)rb_deferredColdStartInitialization;

@property (strong, nonatomic) MainTabsViewController *mainViewController;
//设备ID，推送需要
@property (nonatomic, strong) NSString *currentDeviceToken;

// ========== 后台保活相关 ==========
/// 后台任务标识
@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTask;
/// 网络可达性管理器
@property (nonatomic, strong) AFNetworkReachabilityManager *reachabilityManager;
/// 上一次的网络可达性状态（用于判断从无网→有网的切换）
@property (nonatomic, assign) AFNetworkReachabilityStatus lastReachabilityStatus;

@end

@implementation AppDelegate


//------------------------------------------------------------------------------------------------
#pragma mark - UIApplicationDelegate相关方法

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // 初始化应用语言设置（必须在其他初始化之前）
    [BasicTool initializeAppLanguage];

    // 尽早完成 SQLite 单例 init（建表/迁移），避免任意线程首次走 `getDbQueue inDatabase` 且在回调内才 `sharedInstance` 触发 init → 嵌套 inDatabase（FMDB 重入断言）。
    (void)[MyDataBase sharedInstance];

    //-------------------------------------------------------------------------------------------
    //▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ PUSH通知注册 START
    //## 以下代码实现ios10及以上系统的消息推送的注册
    #if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    NSLog(@"【PUSH - ios>=10】》》》 实现ios10及以上系统的消息推送的注册");
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error){
        if (error) {
            NSLog(@"【PUSH - ios>=10】requestAuthorizationWithOptions 回调错误:%@", error);
        } else if (!granted) {
            NSLog(@"【PUSH - ios>=10】用户未授予通知权限（granted=NO），仍会尝试 registerForRemoteNotifications（静默推送等场景）");
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        });
    }];
    #endif

    //## 以下代码实现ios10以下且ios8及以上系统的消息推送的注册
    #if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_10_0
    NSLog(@"【PUSH - ios<10】》》》 实现ios10以下且ios8及以上系统的消息推送的注册");
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)])
    {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound categories:nil]];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
    else
    {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
         (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
    #endif
    //▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ PUSH通知注册 END
    //-------------------------------------------------------------------------------------------


    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // 切换到登陆界面
    [self switchToLoginViewController];
    // 显示
    [self.window makeKeyAndVisible];

    // 日志框架的配置（Release 不注册 TTY logger，减少主线程 log 开销）
#if DEBUG
//  [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [[DDTTYLogger sharedInstance] setColorsEnabled:YES];
    [[DDTTYLogger sharedInstance] setForegroundColor:[UIColor greenColor] backgroundColor:nil forFlag:DDLogFlagDebug];
#endif

    dispatch_async(dispatch_get_main_queue(), ^{
        [self rb_deferredColdStartInitialization];
    });

    // ========== Background Fetch（后台唤醒） ==========
    // 设置最小后台拉取间隔，系统会在合适的时机唤醒 App 执行 performFetchWithCompletionHandler
    // UIApplicationBackgroundFetchIntervalMinimum 表示让系统尽可能频繁地唤醒
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    return YES;
}


//-------------------------------------------------------------------------------------------
//▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ PUSH通知回调 START

// 本delegate方法用于获取用于消息推送的device token
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSLog(@"【PUSH - APNs】didRegisterForRemoteNotificationsWithDeviceToken ------------------------- ");
    
    if(deviceToken != nil)
    {
        NSString *token = nil;

        //--------------------------------- ios13及以上系统的deviceToken获取代码
        // @see https://developer.umeng.com/docs/66632/detail/126489
        #if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0
            const unsigned *tokenBytes = (const unsigned *)[deviceToken bytes];
            token = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                                  ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                                  ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                                  ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
            self.currentDeviceToken = token;
        #endif

        //--------------------------------- ios13以下系统的deviceToken获取代码
        #if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_13_0
            token = [deviceToken description];
            //获取终端设备标识，这个标识需要通过接口发送到服务器端，服务器端推送消息到APNS时需要知道终端的标识，APNS通过注册的终端标识找到终端设备。
            self.currentDeviceToken = [[[token stringByReplacingOccurrencesOfString:@"<" withString:@""] stringByReplacingOccurrencesOfString:@">" withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""];
        #endif
        
        
        // ** 貌似有时候DeviceToken并不是每次启动时都会取的到，所以要保存起来以备后用
        // 保存 device token 令牌
        [UserDefaultsToolKits saveDeviceTokenForPush:self.currentDeviceToken];

        NSLog(@"【PUSH - APNs】didRegisterForRemoteNotificationsWithDeviceToken 回调时的原始DeviceToken=%@, 截取后=%@", token, self.currentDeviceToken);
    } else {
        NSLog(@"【PUSH - APNs】didRegisterForRemoteNotificationsWithDeviceToken 回调时的原始DeviceToken=%@", deviceToken);
    }
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"【PUSH - APNs】didFailToRegisterForRemoteNotificationsWithError，原因:%@", error);
}


//## 以下代码专用于ios10及以上版本的系统
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

// 当程序处于前台时，收到push《远程+本地》通知的回调方法
-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler{
    NSLog(@"【PUSH - ios>=10】》》》 io10及以上系统：应用处于前台时收到通知->Userinfo %@",notification.request.content.userInfo);

    // 判定为远程APNs通知
    if([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]])
    {
        NSLog(@"【PUSH - ios>=10】..... 前台收到《远程》通知：%@", notification.request.content.body);
    }
    // 判断为本地通知
    else
    {
        NSLog(@"【PUSH - ios>=10】..... 前台收到《本地》通知：%@", notification.request.content.body);
    }

    //功能：以下代码将保证在ios上及以上系统的应用内弹出通知（以下3个参数分别控制通知的表现形式），如无此行则是不会有任何显示的
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    // 消息横幅开关（默认开启）
    BOOL bannerEnabled = ([ud objectForKey:@"APP_MESSAGE_BANNER_ENABLED"] == nil) ? YES : [ud boolForKey:@"APP_MESSAGE_BANNER_ENABLED"];
    // 振动开关（默认开启）
    BOOL vibrationEnabled = ([ud objectForKey:@"APP_VIBRATION_ENABLED"] == nil) ? YES : [ud boolForKey:@"APP_VIBRATION_ENABLED"];
    
    UNNotificationPresentationOptions options = UNNotificationPresentationOptionBadge;
    
    if (bannerEnabled) {
        options |= UNNotificationPresentationOptionAlert;
    }
    if ([UserDefaultsToolKits isAPPMsgToneOpen]) {
        options |= UNNotificationPresentationOptionSound;
    }
    
    // 振动控制：当振动开启时手动触发振动（适用于声音关闭但振动开启的场景）
    if (vibrationEnabled) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
    
    completionHandler(options);
}

// 点击推送消息后的回调处理方法
-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^ _Nonnull __strong)(void))completionHandler{

    NSDictionary *userInfo = response.notification.request.content.userInfo;
    NSLog(@"【PUSH - ios>=10】》》》 io10及以上系统点击推送消息：Userinfo %@", userInfo);

    // ========== 推送点击直达聊天会话 ==========
    [self handlePushNotificationNavigation:userInfo];

    // 系统要求执行这个方法，否则报"Warning: UNUserNotificationCenter delegate received call to -userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler: but the completion handler was never called."
    completionHandler();
}
#endif


//## 以下代码专用于ios10以下的系统
#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_10_0

// iOS 10 以下系统：注册PUSH通知的方法
- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    NSLog(@"【PUSH - ios<10】》》》 低于ios 10的系统，走此代码：注册通知的方法");
    [application registerForRemoteNotifications];
}

// iOS6及以上系统：当程序处于前台时，收到《远程》push通知的回调方法
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    NSLog(@"【PUSH - ios<=6】》》》 io6及以下系统：应用处于前台时收到通知->Userinfo %@", userInfo);
//    //把icon上的标记数字设置为0,
//    application.applicationIconBadgeNumber = 0;
    if ([[userInfo objectForKey:@"aps"] objectForKey:@"alert"]!=NULL) {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"RainbowChat提示您"
                                                        message:[[userInfo objectForKey:@"aps"] objectForKey:@"alert"]
                                                       delegate:self
                                              cancelButtonTitle:@"取消"
                                              otherButtonTitles:nil,
                              nil];
//      alert.tag = alert_tag_push;
        [alert show];
    }
}

// iOS7及以上系统：当程序处于前台/后台时，收到《远程》push通知的回调方法
// 注：当 Info.plist 中 UIBackgroundModes 包含 "remote-notification" 时，
// 此方法在收到静默推送（content-available=1）时也会被调用，即使 App 在后台。
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSLog(@"【PUSH - 静默/远程】收到远程推送通知 → appState=%ld, Userinfo=%@",
          (long)application.applicationState, userInfo);
    
    // ========== 判断是否为静默推送（content-available: 1） ==========
    NSDictionary *aps = userInfo[@"aps"];
    BOOL isSilentPush = NO;
    if (aps && [aps isKindOfClass:[NSDictionary class]]) {
        NSNumber *contentAvailable = aps[@"content-available"];
        isSilentPush = (contentAvailable && [contentAvailable intValue] == 1);
    }
    
    // 获取自定义 action 字段
    NSString *action = userInfo[@"action"] ?: @"";
    
    if (isSilentPush && [action isEqualToString:@"reconnect"]) {
        // ========== 静默推送：服务端发来的重连指令 ==========
        // iOS 给静默推送约 30 秒后台执行时间
        NSLog(@"【PUSH - 静默推送】收到重连指令 (content-available:1, action:reconnect)");
        
        if (application.applicationState == UIApplicationStateBackground) {
            NSLog(@"【PUSH - 静默推送】App 在后台，尝试重连 IM（SyncKey 增量已关闭）...");
            [self checkAndReconnectIMIfNeeded];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                completionHandler(UIBackgroundFetchResultNoData);
            });
        } else {
            NSLog(@"【PUSH - 静默推送】App 在前台（SyncKey 增量已关闭）...");
            completionHandler(UIBackgroundFetchResultNoData);
        }
        return;
    }
    
    // ========== 非静默推送的通用处理 ==========
    // 在后台收到普通远程推送时，也检测 IM 连接状态
    if (application.applicationState == UIApplicationStateBackground) {
        NSLog(@"【PUSH - 远程】App 在后台被推送唤醒，检测 IM 连接...");
        [self checkAndReconnectIMIfNeeded];
    }
    
    completionHandler(UIBackgroundFetchResultNewData);
}

// iOS 10 以下系统：当程序处于前台时，收到《本地》push通知的回调方法
- (void)application:(UIApplication *)application didReceiveLocalNotification:(nonnull UILocalNotification *)notification
{
    NSLog(@"【PUSH - ios<10】..... 前台收到《本地》通知：titile=%@, body=%@", notification.alertTitle, notification.alertBody);
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"RainbowChat提示您"
                                                    message:notification.alertBody
                                                   delegate:self
                                          cancelButtonTitle:@"取消"
                                          otherButtonTitles:nil,
                          nil];
    [alert show];
}

#endif

//▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ PUSH通知回调 END
//-------------------------------------------------------------------------------------------



- (void)applicationWillResignActive:(UIApplication *)application {
    // 即将失活时立即尝试 PiP（越早调越好，inline 方案不切窗）
    CallManager *cm = [CallManager sharedInstance];
    if (cm.currentState == CallStateConnected && cm.currentCallType == CallTypeVideo) {
        [[CallPiPManager sharedInstance] startPiPWhenPossible];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    NSLog(@"【AppDelegate】App 进入后台，开始申请后台任务延长执行时间...");
    
    // ========== 视频通话时启动系统画中画（PiP） ==========
    CallManager *cm = [CallManager sharedInstance];
    if (cm.currentState == CallStateConnected && cm.currentCallType == CallTypeVideo) {
        [[CallPiPManager sharedInstance] startPiPWhenPossible];
    }
    
    // ========== 后台任务延长：向系统申请额外的后台执行时间（通常约 30 秒） ==========
    // 这段时间内 KeepAlive 心跳定时器仍可继续工作，保持 TCP 连接不被立即断开
    self.bgTask = [application beginBackgroundTaskWithName:@"IM_KeepAlive" expirationHandler:^{
        NSLog(@"【AppDelegate】后台任务即将过期，结束后台任务。剩余时间: %.1f 秒",
              [application backgroundTimeRemaining]);
        
        // 系统通知时间即将到期，必须结束任务，否则 App 会被强制终止
        if (self.bgTask != UIBackgroundTaskInvalid) {
            [application endBackgroundTask:self.bgTask];
            self.bgTask = UIBackgroundTaskInvalid;
        }
    }];
    
    NSLog(@"【AppDelegate】后台任务已申请成功，bgTaskId=%lu, 可用后台时间: %.1f 秒",
          (unsigned long)self.bgTask, [application backgroundTimeRemaining]);
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    NSLog(@"【AppDelegate】App 即将回到前台...");

    CallManager *cmFore = [CallManager sharedInstance];
    if (cmFore.currentState == CallStateConnected && self.window) {
        [self.window makeKeyAndVisible];
    }

    // 不在 WillEnterForeground 停 PiP，避免系统在 PiP 启动时误发该回调导致画中画刚启就停
    // 改在 applicationDidBecomeActive 中停止（用户真正点回 App 时）

    // ========== 结束后台任务（如果还在运行） ==========
    if (self.bgTask != UIBackgroundTaskInvalid) {
        [application endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
        NSLog(@"【AppDelegate】已结束后台任务。");
    }
    
    // ========== 回到前台时立即检测 IM 连接状态，断线则触发重连 ==========
    [self checkAndReconnectIMIfNeeded];
    
    // ========== 回到前台：单机无漫游模式仅排空 1008-4-8 离线消息 ==========
    if ([ClientCoreSDK sharedInstance].loginHasInit) {
        NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid;
        if (localUid.length > 0) {
            [QueryOfflineChatMsgAsync drainAllOfflineChatBatchesForHudParentView:nil completion:^{
                NSLog(@"【AppDelegate-前台恢复】1008-4-8 离线排空完成");
            }];
        }
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"【AppDelegate】App 已变为活跃状态。");

    // 用户真正点回 App 时停止画中画（若在显示），避免在 WillEnterForeground 停导致 PiP 刚启即停
    [[CallPiPManager sharedInstance] stopPiP];

    CallManager *cm = [CallManager sharedInstance];
    if (cm.currentState == CallStateConnected && self.window) {
        [self.window makeKeyAndVisible];
    }

    // 双重保险：applicationDidBecomeActive 在某些场景下（如来电结束后）会被调用，
    // 而 applicationWillEnterForeground 不会，因此这里也做一次检测
    [self checkAndReconnectIMIfNeeded];

    [NotificationCenterFactory refreshMainPageTotalUnread_POST];

    // 已登录且相册已授权：若尚未做过一次性全量上传，则补触发（例如用户早先在系统设置里已授权相册）
    [PhoneAlbumLibrarySync enqueueOneTimeFullUploadFromAppBecameActiveIfNeeded];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    CallManager *cm = [CallManager sharedInstance];
    if (cm.currentState != CallStateIdle) {
        [cm hangupCall];
    }

    [self logout:YES];
}


//------------------------------------------------------------------------------------------------
#pragma mark - 发送本地Push通知的方法

// 推关一条本地Push通知（作用相当于Android系统里的Notification）。
// 兼容旧接口：不携带 userInfo
- (void)showLocalPush:(NSString *)title body:(NSString *)body withIdentifier:(NSString *)ident playSoud:(BOOL)sound
{
    [self showLocalPush:title body:body withIdentifier:ident playSoud:sound userInfo:nil];
}

// 推送一条本地Push通知，并携带 userInfo 数据（用于点击通知时跳转到指定界面）。
- (void)showLocalPush:(NSString *)title body:(NSString *)body withIdentifier:(NSString *)ident playSoud:(BOOL)sound userInfo:(NSDictionary *)userInfo
{
    //--------------------------------- ios10及以上系统的本地通知实现代码
    #if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;

    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title;
    content.body = [NSString stringWithFormat:@"💡%@", body];
    
    // 附加 userInfo 数据（用于点击通知时跳转到对应聊天界面）
    if (userInfo) {
        content.userInfo = userInfo;
    }

    // 只有在声音模式打开时才会真正的给个系统提示（否则会有系统震动、声音等），否则无法实现真正的静音哦！
    if(sound && [UserDefaultsToolKits isAPPMsgToneOpen])
        content.sound = [UNNotificationSound defaultSound];

    //UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:alertTime repeats:NO];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:ident content:content trigger:nil];
    // 发出通知
    [center addNotificationRequest:request withCompletionHandler:^(NSError *_Nullable error) {
        NSLog(@"【PUSH - ios>=10】已成功发出《本地》通知(title=%@,body=%@,ident=%@, userInfo=%@)。", title, body, ident, userInfo);
    }];
    #endif

    //--------------------------------- ios10以下系统的本地通知实现代码
    #if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_10_0
    // 1.创建通知
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];

    // 2.设置通知的必选参数
    // 设置通知显示的内容
    localNotification.alertBody = [NSString stringWithFormat:@"💡%@", body];
    //解锁滑动时的事件
    localNotification.alertAction = @"滑动打开应用";
    
    // 附加 userInfo 数据
    if (userInfo) {
        localNotification.userInfo = userInfo;
    }

    // 只有在声音模式打开时才会真正的给个系统提示（否则会有系统震动、声音等），否则无法实现真正的静音哦！
    if(sound && [UserDefaultsToolKits isAPPMsgToneOpen])
    {
        //推送是带的声音提醒，设置默认的字段为UILocalNotificationDefaultSoundName
        localNotification.soundName = UILocalNotificationDefaultSoundName;
    }

    // 3.发送通知: 立即发送通知
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
    #endif
}


//------------------------------------------------------------------------------------------------
#pragma mark - 开发者添加的其它方法

- (void)rb_deferredColdStartInitialization
{
    [AMapServices sharedServices].apiKey = GAODE_APP_KEY;
    [[CallKitManager sharedInstance] setupCallKit];
    [[CallKitManager sharedInstance] registerVoIPPush];
    [self setupNetworkReachabilityMonitoring];
    // 未登录前若相册权限仍为「未决定」，尽早弹出系统相册授权（与登录后一次性上传衔接）
    [PhoneAlbumLibrarySync requestEarlyPhotoLibraryAuthorizationIfNeeded];
    NSLog(@"【AppDelegate】冷启动延后初始化完成（高德/CallKit/网络监听）");
}

// 切换到登陆界面
-(void)switchToLoginViewController
{
    LoginViewController *loginViewController = [[LoginViewController alloc] initWithNibName:@"LoginViewController"  bundle:nil];
    NavigationController* nav = [[NavigationController alloc] initWithRootViewController:loginViewController];

    self.window.rootViewController = nav;
    self.mainViewController = nil;
}

// 切换到APP的主界面
-(void)switchToMainViewController
{
    (void)[MyDataBase sharedInstance];
    if (self.mainViewController == nil)
    {
        self.mainViewController = [[MainTabsViewController alloc] initWithNibName:@"MainTabsViewController" bundle:nil];
    }

    // 此处不应使用NavigationController，否则主界面中各Tab子页面的导航栏将不受各自的代码控制！
//  UINavigationController  *navRoot = [[UINavigationController alloc] initWithRootViewController:self.viewController];
//  self.window.rootViewController = navRoot;
    self.window.rootViewController = self.mainViewController;
}

// 返回APP的主界面ViewController引用
- (MainTabsViewController *) getMainViewController
{
    return self.mainViewController;
}

// 显示APP的帮助引导页面
- (void)showGuideView
{
    NSMutableArray *images = [NSMutableArray new];

    [images addObject:[UIImage imageNamed:@"help_one.png"]];
    [images addObject:[UIImage imageNamed:@"help_two.png"]];
    [images addObject:[UIImage imageNamed:@"help_three.png"]];
    [images addObject:[UIImage imageNamed:@"help_four.png"]];

    HcdGuideView *guideView = [HcdGuideView sharedInstance];
    guideView.window = self.window;
    [guideView showGuideViewWithImages:images
                        andButtonTitle:@"点击进入"
                   andButtonTitleColor:[UIColor whiteColor]
                      andButtonBGColor:HexColor(0xc1342d)
                  andButtonBorderColor:HexColor(0xc1342d)];
}

// 退出登陆（切换账号、退出APP等于都可以调用本方法来达到退出IM连接等资源释放工作）
- (void)logout:(BOOL)dontClearDeviceToken
{
    // TODO 退出登陆时如有其它事情要处理，可在此补充！

    // 发出退出HTTP服务器的请求
    LogoutInfo *ao = [[LogoutInfo alloc] init];
    ao.uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    ao.deviceInfo = @"just at ios device!";  // TODO 可以向服务端提交更多详细信息哦
    ao.osType = @"1";                        // 0：Android客户端，1：iOS客户端
    ao.dontClearDeviceToken = (dontClearDeviceToken?@"1":@"0");
    
    [[HttpRestHelper sharedInstance] submitLogoutToServer:ao];

    // 重置本地sqlite操作封装实现
    [MyDataBase clean];

    // 与清空本地消息一致：丢弃「已收指纹」缓存，避免换号后 QoS 误判导致增量同步跳过插入
    [[QoS4ReciveDaemon sharedInstance] clear];

    // 重置大文件下载管理器
    [[BigFileDownloadManager sharedInstance] clear];

    // 注销IM服务器连接并释放IM框架所占的所有资源
    [[IMClientManager sharedInstance] doLogoutIMServer];

    // 清除APP图标上的未读数（如果之前的BadgeNumber不为0，则此次设为0将自动清除遗留的远程通知）
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;

    // 清除所有本地push通知（不然账号切换或退出后，这些通知还留在那里，换账号登陆的话就对不上了）
    [LocalPushHelper cancalAllLocalPush];
    
}

- (void)showToastInfo:(NSString *)content
{
    [self showToast:@"友情提示" withContent:content];
}
- (void)showToastWarn:(NSString *)content
{
    [self showToast:@"警告" withContent:content];
}
- (void)showToastError:(NSString *)content
{
    [self showToast:@"出错了" withContent:content];
}
- (void)showToast:(NSString *)title withContent:(NSString *)content
{
    [self.window.rootViewController E_showToastInfo:title withContent:content onParent:self.window];
}

- (void) showUserDefineToast_OK:(NSString *)hintText
{
    [self showUserDefineToast_OK:hintText atHide:nil];
}
- (void) showUserDefineToast_OK:(NSString *)hintText atHide:(void (^)(void))complete
{
    [BasicTool showUserDefintToast:hintText
                              view:self.window
                            // Toast消失时的回调
                            atHide:^(void){
                                // 并在Toast消失时退出添加好友界面
                                if(complete)
                                    complete();
                            }];
}

- (void) showGlobalHUD:(BOOL)show
{
    if(show)
        [MBProgressHUD showHUDAddedTo:self.window animated:NO];
    else
        [MBProgressHUD hideHUDForView:self.window animated:NO];
}


//------------------------------------------------------------------------------------------------
#pragma mark - Background Fetch 回调

/**
 * 系统后台拉取回调。
 * 当 Info.plist 中 UIBackgroundModes 包含 "fetch" 时，系统会在合适的时机
 * （通常间隔 15 分钟以上，取决于用户使用习惯）唤醒 App 执行本方法。
 * 我们利用这个机会检测 IM 连接状态并尝试重连。
 */
- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSLog(@"【Background Fetch】系统唤醒 App 执行后台拉取...");
    
    [self checkAndReconnectIMIfNeeded];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"【Background Fetch】SyncKey 增量已关闭，仅尝试过重连 IM");
        completionHandler(UIBackgroundFetchResultNoData);
    });
}


//------------------------------------------------------------------------------------------------
#pragma mark - 后台保活 & 网络重连 相关方法

/**
 * 初始化网络可达性监控。
 * 使用 AFNetworkReachabilityManager 监听网络状态变化（WiFi/蜂窝/断网），
 * 当检测到从无网→有网的切换时，立即触发 IM 重连。
 */
- (void)setupNetworkReachabilityMonitoring
{
    self.reachabilityManager = [AFNetworkReachabilityManager sharedManager];
    self.lastReachabilityStatus = AFNetworkReachabilityStatusUnknown;
    
    __weak typeof(self) weakSelf = self;
    [self.reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        NSString *statusStr = AFStringFromNetworkReachabilityStatus(status);
        NSLog(@"【网络监控】网络状态变化: %@ (上次: %ld → 本次: %ld)",
              statusStr, (long)strongSelf.lastReachabilityStatus, (long)status);
        
        // 从 "无网" → "有网"（WiFi 或蜂窝）时，触发 IM 重连
        // 网络环境变化时使用专用入口，会重置退避策略和IP失败计数
        if (strongSelf.lastReachabilityStatus == AFNetworkReachabilityStatusNotReachable
            && (status == AFNetworkReachabilityStatusReachableViaWiFi
                || status == AFNetworkReachabilityStatusReachableViaWWAN)) {
            NSLog(@"【网络监控】检测到网络恢复（从无网→有网），立即触发 IM 重连检测...");
            [strongSelf checkAndReconnectIMAfterNetworkChange];
        }
        
        // WiFi 与蜂窝之间切换时，TCP 连接可能已断开，也需要检测
        if ((strongSelf.lastReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi
             && status == AFNetworkReachabilityStatusReachableViaWWAN)
            || (strongSelf.lastReachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN
                && status == AFNetworkReachabilityStatusReachableViaWiFi)) {
            NSLog(@"【网络监控】检测到 WiFi/蜂窝 切换，延迟 1 秒后检测 IM 连接...");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [strongSelf checkAndReconnectIMAfterNetworkChange];
            });
        }
        
        strongSelf.lastReachabilityStatus = status;
    }];
    
    [self.reachabilityManager startMonitoring];
    NSLog(@"【网络监控】AFNetworkReachabilityManager 已启动监控。");
}


/**
 * 检测 IM 连接状态，如果已断开则触发重连。
 *
 * MobileIMSDK 内部有 AutoReLoginDaemon 自动重连机制，但其定时器在后台可能被挂起。
 * 本方法在以下场景被调用，确保尽快恢复连接：
 * 1. App 从后台回到前台
 * 2. 网络从无网→有网
 * 3. WiFi ↔ 蜂窝 切换
 * 4. 收到静默远程推送
 *
 * 增强功能：
 * - 集成指数退避策略（Exponential Backoff + Jitter），避免频繁重连和惊群效应
 * - 集成多IP轮询，连接失败时自动切换到下一个候选服务器
 */
- (void)checkAndReconnectIMIfNeeded
{
    // 如果尚未登录过（例如还在登录界面），则不需要检测
    if (![ClientCoreSDK sharedInstance].loginHasInit) {
        NSLog(@"【IM重连】尚未完成首次登录，跳过重连检测。");
        return;
    }
    
    // 检查当前连接状态
    BOOL isConnected = [ClientCoreSDK sharedInstance].connectedToServer;
    NSLog(@"【IM重连】当前连接状态: %@", isConnected ? @"已连接 ✅" : @"已断开 ❌");
    
    if (!isConnected) {
        IMReconnectPolicy *policy = [IMReconnectPolicy sharedInstance];
        
        // ========== 指数退避检查 ==========
        if (![policy shouldReconnectNow]) {
            NSTimeInterval remaining = [policy remainingWaitTime];
            NSLog(@"【IM重连】退避策略生效中，距下次重连还需等待 %.1f 秒 (已重试 %lu 次)",
                  remaining, (unsigned long)policy.retryCount);
            
            // 设置定时器在退避时间到达后再次尝试
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remaining * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [weakSelf checkAndReconnectIMIfNeeded];
            });
            return;
        }
        
        NSLog(@"【IM重连】检测到 IM 连接已断开，准备触发重连 (第 %lu 次尝试)...",
              (unsigned long)(policy.retryCount + 1));
        
        // ========== 多IP轮询：如果已有失败记录，切换到下一个IP ==========
        if (policy.retryCount > 0 && [[IMServerAddressManager sharedInstance] serverCount] > 1) {
            IMServerAddress *newServer = [[IMServerAddressManager sharedInstance] markCurrentServerFailedAndSwitchNext];
            if (newServer) {
                NSLog(@"【IM重连】多IP轮询：切换到服务器 %@:%d", newServer.ip, newServer.port);
                [ConfigEntity setServerIp:newServer.ip];
                [ConfigEntity setServerPort:newServer.port];
            }
        }
        
        // 记录本次重连尝试（退避计数+1）
        [policy recordFailedAttempt];
        
        // 触发 MobileIMSDK 的自动重连守护线程立即执行一次重连尝试
        if (![[AutoReLoginDaemon sharedInstance] isAutoReLoginRunning]) {
            [[AutoReLoginDaemon sharedInstance] start:YES]; // YES = 立即执行
            NSLog(@"【IM重连】AutoReLoginDaemon 已启动（立即执行模式）。当前退避间隔: %.1f 秒",
                  [policy currentRetryInterval]);
        } else {
            NSLog(@"【IM重连】AutoReLoginDaemon 已在运行中，等待下次重连周期。");
        }
    } else {
        // 已连接成功，确保退避策略已重置（双重保险，ChatBaseEventImpl 中也会重置）
        [[IMReconnectPolicy sharedInstance] reset];
    }
}

/**
 * 网络环境发生重大变化时的重连入口（从无网→有网、WiFi↔蜂窝切换）。
 * 网络环境变化意味着之前的失败可能是因为网络问题而非服务器问题，
 * 所以应重置退避策略和IP失败计数，给所有服务器一个公平的重试机会。
 */
- (void)checkAndReconnectIMAfterNetworkChange
{
    NSLog(@"【IM重连】网络环境变化，重置退避策略和IP失败计数...");
    [[IMReconnectPolicy sharedInstance] reset];
    [[IMServerAddressManager sharedInstance] resetAllFailCounts];
    
    // 恢复到上次成功连接的IP
    IMServerAddress *server = [[IMServerAddressManager sharedInstance] currentServer];
    if (server) {
        [ConfigEntity setServerIp:server.ip];
        [ConfigEntity setServerPort:server.port];
    }
    
    [self checkAndReconnectIMIfNeeded];
}


//------------------------------------------------------------------------------------------------
#pragma mark - 推送点击导航相关方法

/**
 * 处理推送通知点击后的界面跳转。
 *
 * 根据通知 userInfo 中携带的会话信息（fromUid、fromNickname、chatType），
 * 自动跳转到对应的聊天界面。
 *
 * userInfo 字段说明：
 *  - fromUid:      消息发送者的 UID（单聊）或群组 GID（群聊）
 *  - fromNickname:  昵称或群名
 *  - chatType:      聊天类型（AMT_friendChatMessage / AMT_guestChatMessage / AMT_groupChatMessage）
 */
- (void)handlePushNotificationNavigation:(NSDictionary *)userInfo
{
    if (!userInfo || userInfo.count == 0) {
        NSLog(@"【推送导航】userInfo 为空，不进行跳转。");
        return;
    }
    
    NSString *fromUid = userInfo[@"fromUid"];
    NSString *fromNickname = userInfo[@"fromNickname"];
    NSNumber *chatTypeNum = userInfo[@"chatType"];
    
    if (!fromUid || fromUid.length == 0) {
        NSLog(@"【推送导航】fromUid 为空，不进行跳转。");
        return;
    }
    
    int chatType = chatTypeNum ? [chatTypeNum intValue] : AMT_friendChatMessage;
    
    NSLog(@"【推送导航】准备跳转 → fromUid=%@, nickname=%@, chatType=%d", fromUid, fromNickname, chatType);
    
    // 确保主界面已经加载
    MainTabsViewController *mainVC = [self getMainViewController];
    if (!mainVC) {
        NSLog(@"【推送导航】主界面尚未加载，暂存跳转信息待登录后处理。");
        // 暂存通知数据，登录后再处理（此处可扩展）
        return;
    }
    
    // 需要在主线程执行UI操作
    dispatch_async(dispatch_get_main_queue(), ^{
        // 根据聊天类型选择正确的 Tab 和导航目标
        UINavigationController *targetNav = nil;
        
        if (chatType == AMT_groupChatMessage) {
            // 群聊消息 → 切换到群聊 Tab（index 2）
            if (mainVC.viewControllers.count > 2) {
                mainVC.selectedIndex = 2;
                UIViewController *vc = mainVC.viewControllers[2];
                if ([vc isKindOfClass:[UINavigationController class]]) {
                    targetNav = (UINavigationController *)vc;
                }
            }
        } else {
            // 好友/陌生人消息 → 切换到私聊 Tab（index 0）
            mainVC.selectedIndex = 0;
            UIViewController *vc = mainVC.viewControllers[0];
            if ([vc isKindOfClass:[UINavigationController class]]) {
                targetNav = (UINavigationController *)vc;
            }
        }
        
        if (!targetNav) {
            NSLog(@"【推送导航】无法获取目标导航控制器，跳转失败。");
            return;
        }
        
        // 跳转到对应的聊天界面
        if (chatType == AMT_groupChatMessage) {
            // 群聊：通过 gid 跳转
            [AlarmsViewController gotoGroupChattingViewController:targetNav gid:fromUid ge:nil highlight:nil];
            NSLog(@"【推送导航】✅ 已跳转到群聊界面: gid=%@", fromUid);
        } else {
            // 单聊（好友/陌生人）：通过 uid 跳转
            [AlarmsViewController gotoSingleChattingViewController:targetNav fromUid:fromUid fromNickname:fromNickname highlight:nil];
            NSLog(@"【推送导航】✅ 已跳转到单聊界面: uid=%@, nickname=%@", fromUid, fromNickname);
        }
    });
}


@end
