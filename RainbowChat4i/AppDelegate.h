//telegram @wz662
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

@class MainTabsViewController;


@interface AppDelegate : UIResponder <UIApplicationDelegate,UNUserNotificationCenterDelegate>

@property (nonatomic, strong) UIWindow *window;

// 切换到登陆界面
-(void)switchToLoginViewController;

// 切换到APP的主界面
-(void)switchToMainViewController;

// 返回APP的主界面ViewController引用
- (MainTabsViewController *) getMainViewController;

// 显示APP的帮助引导页面
- (void)showGuideView;

- (void)logout:(BOOL)dontClearDeviceToken;

- (void)showToastInfo:(NSString *)content;
- (void)showToastWarn:(NSString *)content;
- (void)showToastError:(NSString *)content;
- (void)showToast:(NSString *)title withContent:(NSString *)content;

// 显示一个延迟关闭的大提示Toast，Toast类型是OK。
- (void) showUserDefineToast_OK:(NSString *)hintText;
- (void) showUserDefineToast_OK:(NSString *)hintText atHide:(void (^)(void))complete;

// 显示一个全局的转动菊花
- (void) showGlobalHUD:(BOOL)show;

/**
 推关一条本地Push通知（作用相当于Android系统里的Notification）。

 @param title 通知标题
 @param body 通知内容
 @param ident 唯一标识
 */
- (void)showLocalPush:(NSString *)title body:(NSString *)body withIdentifier:(NSString *)ident playSoud:(BOOL)sound;

/**
 推送一条本地Push通知，并携带 userInfo 数据（用于点击通知时跳转到指定界面）。

 @param title 通知标题
 @param body 通知内容
 @param ident 唯一标识
 @param sound 是否播放声音
 @param userInfo 附加数据字典，可包含 fromUid/fromNickname/chatType 等信息
 */
- (void)showLocalPush:(NSString *)title body:(NSString *)body withIdentifier:(NSString *)ident playSoud:(BOOL)sound userInfo:(NSDictionary *)userInfo;

@end

