//telegram @wz662
#import "IMServerConnector.h"
#import "OnLoginProgress.h"
#import "CompletionDefine.h"
//#import "ChatViewController.h"
#import "IMClientManager.h"
#import "EVAToolKits.h"
#import "LocalDataSender.h"
#import "AppDelegate.h"
#import "MyDataBase.h"


////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
////////////////////////////////////////////////////////////////////////////////////////////

@interface IMServerConnector ()

/* 登陆进度提示 */
@property (nonatomic) OnLoginProgress *onLoginProgress;

/* 收到socket长连接服务端的登陆完成反馈时要通知的观察者（因登陆是异步实现，本观察者将由
 *  ChatBaseEvent 事件的处理者在收到服务端的登陆反馈后通知之）*/
@property (nonatomic, copy) ObserverCompletion onLoginSucessObserver;// block代码块一定要用copy属性，否则报错！
/* 登陆socket长连接服务端结束时要通知的观察者（无论是登陆成功、失败还是出错等，反正本次登陆有结果了都会通知） */
@property (nonatomic, copy) ObserverCompletion onLoginEndObserver;// block代码块一定要用copy属性，否则报错！

/* 将连接IM的loginUserId临时缓存起来，一备在连接超时后的重试时能再次使用 */
@property (nonatomic, retain) NSString *tempCachedLoginUidForRetry;
/* 将连接IM的loginToken临时缓存起来，一备在连接超时后的重试时能再次使用 */
@property (nonatomic, retain) NSString *tempCachedLoginTokenForRetry;

@property (nonatomic, retain) UIViewController *parentViewController;

@end


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
/////////////////////////////////////////////////////////////////////////////////////////////

@implementation IMServerConnector

- (id)initWith:(UIViewController *)parentViewController
{
    if(self = [super init])
    {
        // 属性初始化
        self.parentViewController = parentViewController;
    }
    return self;
}

- (void)initConnectToIMServer
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak IMServerConnector *safeSelf = self;
    // 实例化登陆进度提示封装类
    self.onLoginProgress = [[OnLoginProgress alloc] init];
    // 设置登陆超时回调（将在登陆进度提示封装类中使用）
    [self.onLoginProgress setOnTimeoutObserver:^(id observerble ,id data) {
        [[[UIAlertView alloc] initWithTitle:@"超时了"
                                    message:@"连接IM服务器超时，可能是网络或服务器故障，是否重试？"
                                   delegate:safeSelf
                          cancelButtonTitle:@"取消"
                          otherButtonTitles:@"重试！", nil]
         show];
    }];
    // 准备好异步登陆结果回调block（将在登陆方法中使用）
    self.onLoginSucessObserver = ^(id observerble ,id data) {
        // * 已收到服务端登陆反馈则当然应立即取消显示登陆进度条
        [safeSelf.onLoginProgress showProgressing:NO onParent:safeSelf.parentViewController.view];
        // 服务端返回的登陆结果值
        int code = [(NSNumber *)data intValue];
        // 登陆成功
        if(code == 0)
        {
            // TODO 提示：登陆IM服务器成功后的事情在此实现即可
            
            // 登陆结束，通知观察者
            if(safeSelf.onLoginEndObserver != nil)
                safeSelf.onLoginEndObserver(nil, nil);

            // 登陆im成功后，首先为app准备好sqlite缓存操作的封装类
            if(![MyDataBase sharedInstance])
                DDLogWarn(@"[sqlite-IMServerConnector] 本地sqlite缓存操作封装对象实例化失败。");

            // 进入主界面
            [APP switchToMainViewController];
        }
        // 登陆失败
        else
        {
            [[[UIAlertView alloc] initWithTitle:@"友情提示"
                                        message:[NSString stringWithFormat:@"Sorry，连接IM服务器失败，错误码=%d", code]
                                       delegate:safeSelf
                              cancelButtonTitle:@"知道了"
                              otherButtonTitles:nil]
             show];
            
            // 登陆结束，通知观察者
            if(safeSelf.onLoginEndObserver != nil)
                safeSelf.onLoginEndObserver(nil, nil);
        }

        //## try to bug FIX ! 20160810：此observer本身执行完成才设置为nil，解决之前过早被nil而导致有时怎么也无法跳过登陆界面的问题
        // * 取消设置好服务端反馈的登陆结果观察者（当客户端收到服务端反馈过来的登陆消息时将被通知）【1】
        [[[IMClientManager sharedInstance] getBaseEventListener] setLoginOkForLaunchObserver:nil];
    };
}

- (void)doLoginIMServer:(NSString *)loginUserId andToken:(NSString *)loginToken
{
    // * 立即显示登陆处理进度提示（并将同时启动超时检查线程）
    [self.onLoginProgress showProgressing:YES onParent:self.parentViewController.view];
    // * 设置好服务端反馈的登陆结果观察者（当客户端收到服务端反馈过来的登陆消息时将被通知）【2】
    [[[IMClientManager sharedInstance] getBaseEventListener] setLoginOkForLaunchObserver:self.onLoginSucessObserver];

    // 临时保存uid以备重试时再次使用
    self.tempCachedLoginUidForRetry = loginUserId;
    // 临时保存token以备重试时再次使用
    self.tempCachedLoginTokenForRetry = loginToken;
    
    // 将要提交的登陆信息对象
    PLoginInfo *loginInfo = [[PLoginInfo alloc] init];
    loginInfo.loginUserId = loginUserId;
    loginInfo.loginToken = loginToken;

    // * 发送登陆数据包(提交登陆名和密码)
    int code = [[LocalDataSender sharedInstance] sendLogin:loginInfo];
    if(code == COMMON_CODE_OK)
    {
//        [APP showToastInfo:@"连接IM服务器的请求已发出 ..."];
        DDLogDebug(@"【IM长连接】连接IM服务器的请求已发出 ...");
    }
    else
    {
        NSString *msg = [NSString stringWithFormat:@"连接IM服务器的请求发送失败，错误码：%d", code];
        [APP showToastError:msg];

        // * 登陆信息没有成功发出时当然无条件取消显示登陆进度条
        [self.onLoginProgress showProgressing:NO onParent:self.parentViewController.view];
        
        // 登陆结束，通知观察者
        if(self.onLoginEndObserver != nil)
            self.onLoginEndObserver(nil, nil);
    }
}

- (void)setOnLoginEndObserver:(ObserverCompletion)onLoginEndObserver
{
    _onLoginEndObserver = onLoginEndObserver;
}

//- (void)gotoChatViewController
//{
//    ChatViewController *vc = [[ChatViewController alloc] initWithNibName:nil bundle:nil];
//    [self.parentViewController.navigationController pushViewController:vc animated:YES];
//}


#pragma mark - UIAlertView delegate

/*
 * 在这里处理登陆超时时的UIAlertView提示对话框中的按钮被单击事件。
 */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex)
    {
        // 点击了取消按钮
        case 0:
        {
            // 不需要重试则要停止“登陆中”的进度提示哦
            [self.onLoginProgress showProgressing:NO onParent:self.parentViewController.view];
            
            // 登陆结束，通知观察者
            if(self.onLoginEndObserver != nil)
                self.onLoginEndObserver(nil, nil);
            
            break;
        }
        // 点确了确认按钮
        case 1:
        {
            // 确认要重试时（再次尝试连接哦）
            [self doLoginIMServer:self.tempCachedLoginUidForRetry andToken:self.tempCachedLoginTokenForRetry];
            break;
        }
        default:
            break;
    }
}

@end
