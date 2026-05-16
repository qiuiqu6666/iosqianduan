//telegram @wz662
#import "ChatBaseEventImpl.h"
#import "AppDelegate.h"
//#import "MainViewController.h"
#import "IMClientManager.h"
#import "QueryOfflineChatMsgAsync.h"
#import "QueryOfflineBeAddFriendsReqAsync.h"
#import "BasicTool.h"
#import "MoreViewController.h"
#import "UserDefaultsToolKits.h"
#import "AppDelegate.h"
#import "MainTabsViewController.h"
#import "HttpServiceFactory.h"
#import "MyProcessorConst.h"
#import "CallKitManager.h"
#import "IMServerAddressManager.h"
#import "IMReconnectPolicy.h"
#import "AlarmsProvider.h"
#import "MessagesProvider.h"
#import "Default.h"

static void RBPerformFrontChatDatabaseResyncAfterReconnect(void)
{
    RBDrainAllChatSaveHistoryQueues();
    IMClientManager *imc = [IMClientManager sharedInstance];
    NSString *fuid = imc.currentFrontChattingUserUID;
    if (fuid.length > 0) {
        [[imc getMessagesProvider] rb_reloadLatestPageFromDatabaseAndNotifyForChatUid:fuid];
    }
    NSString *tempUid = imc.currentFrontTempChattingUserUID;
    if (tempUid.length > 0) {
        [[imc getMessagesProvider] rb_reloadLatestPageFromDatabaseAndNotifyForChatUid:tempUid];
    }
    NSString *fgid = imc.currentFrontGroupChattingGroupID;
    if (fgid.length > 0) {
        [[imc getGroupsMessagesProvider] rb_reloadLatestPageFromDatabaseAndNotifyForChatUid:fgid];
    }
}

@implementation ChatBaseEventImpl

/*!
 @Override
 * 与服务端的通信断开的回调事件通知。
 *
 * <br>
 * 该消息只有在客户端连接服务器成功之后网络异常中断之时触发。
 * 导致与与服务端的通信断开的原因有（但不限于）：无线网络信号不稳定、WiFi与2G/3G/4G等同开情
 * 况下的网络切换、手机系统的省电策略等。
 *
 * @param errorCode 本回调参数表示表示连接断开的原因，目前错误码没有太多意义，仅作保留字段，目前通常为-1
 */
- (void) onLinkClose:(int)errorCode
{
    DDLogDebug(@"【ChatBaseEventImpl】服务器连接已断开，error：%d", errorCode);

    // 通知网络连接状态观察者
    if(self.networkStatusObserver != nil)
        self.networkStatusObserver(nil, nil);

    // @see [RosterProvider offlineAll]的注释说明
    [[[IMClientManager sharedInstance] getFriendsListProvider] offlineAll];
}

/*!
 @Override
 * 本地用户的登陆结果回调事件通知。
 *
 * @param errorCode 服务端反馈的登录结果：0 表示登陆成功，否则为服务端自定义的出错代码（按照约定通常为>=1025的数）
 */
- (void) onLoginResponse:(int)errorCode
{
    // 登陆成功或掉线重连成功
    if (errorCode == 0)
    {
        DDLogDebug(@"【ChatBaseEventImpl】连接IM服务器成功！服务端响应码=%d", errorCode);

        // ========== 多IP轮询：标记当前服务器为健康 ==========
        [[IMServerAddressManager sharedInstance] markCurrentServerSuccess];
        
        // ========== 指数退避：重置退避策略 ==========
        [[IMReconnectPolicy sharedInstance] reset];

        if (self.loginOkForLaunchObserver != nil)
            self.loginOkForLaunchObserver(nil, [NSNumber numberWithInt:errorCode]);

        [self afterLinkSucess];
    }
    else
    {
        [APP showToastError:[NSString stringWithFormat:@"与服务器连接失败，error code:%d", errorCode]];
        DDLogDebug(@"【ChatBaseEventImpl】与IM服务器连接失败，错误代码：%d", errorCode);
        
        // token检验失败
        if(errorCode == 1025) {
            DDLogDebug(@"【ChatBaseEventImpl】与IM服务器连接失败，原因是token校验失败，马上提示用户并告之重新登录！");
            
            // 释放长连接相关的资源
            [[ClientCoreSDK sharedInstance] releaseCore];
            // 并显示提示信息
            [BasicTool showAlertAndGotoLogin:@"请重新登录" content:@"长连接Token已失效，请重新登陆后再试。点击下方按钮将自动跳转到登录界面。"];
        }
    }

    // 通知网络连接状态观察者
    if(self.networkStatusObserver != nil)
        self.networkStatusObserver(nil, nil);
}

/*!
 @Override
 * 本的用户被服务端踢出的回调事件通知。
 *
 * @param kickoutInfo 被踢信息对象，{@link PKickoutInfo} 对象中的 code字段定义了被踢原因代码
 */
- (void) onKickout:(PKickoutInfo *)kickoutInfo
{
    NSLog(@"【DEBUG_UI】已收到服务端的\"被踢\"指令，kickoutInfo.code：%d", kickoutInfo.code);

    NSString *alertContent = @"";
    if(kickoutInfo.code == KICKOUT_FOR_DUPLICATE_LOGIN)
    {
        alertContent = @"账号已在其它设备登陆，当前会话已断开，请退出后重新登陆！";
    }
    else if(kickoutInfo.code == KICKOUT_FOR_ADMIN)
    {
        alertContent = @"已被管理员强行踢出聊天，当前会话已断开！";
    }
    else{
        alertContent = [NSString stringWithFormat:@"你已被踢出聊天，当前会话已断开（kickoutReason=%@）！", kickoutInfo.reason];
    }
    
    // 强行设置"自动登陆"为关闭
    [UserDefaultsToolKits setAutoLogin:NO];

    // 显示一个被踢提示对话框
    [BasicTool showAlertAndGotoLogin:@"你被踢了" content:alertContent];
//    [BasicTool showAlert:@"你被踢了" content:alertContent btnTitle:@"知道了！" parent:[APP getMainViewController] handler:^(UIAlertAction *action) {
//        // 退出当前登陆状态并跳转到登际界面（以便重新登陆）
//        [MoreViewController exitAndGotoLogin:NO];
//    }];
}

/**
 * 登陆/重连成功后要做的事：离线消息处理。
 */
- (void) afterLinkSucess
{
    [[[IMClientManager sharedInstance] getFriendsListProvider] refreshFriendsDataAsync:nil];

    [[[IMClientManager sharedInstance] getGroupsProvider] refreshGroupsList:nil];

    NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid;

    [QueryOfflineBeAddFriendsReqAsync doIt:nil];

    // 重连后补离线消息
    if (localUid.length > 0) {
        NSLog(@"【RB-MSGFLOW】afterLink：补离线消息 uid=%@", localUid);
        [QueryOfflineChatMsgAsync drainAllOfflineChatBatchesForHudParentView:nil completion:nil];
    }

    
    // 【v12.x 新增】登陆/重连成功后，查询用户隐私权限设置并缓存 allow_read_receipt
    [self fetchAndCachePrivacySettings:localUid];
    
    // 【v12.x 新增】登陆/重连成功后，上传缓存的 VoIP PushKit Token 到服务端
    [[CallKitManager sharedInstance] uploadCachedVoIPTokenIfNeeded];

    // 停留在聊天页时，离线等异步落库后内存仍可能是断网前快照；主线程排空写库队列后从 DB 再合并最新一页并通知当前会话 UI
    dispatch_async(dispatch_get_main_queue(), ^{
        RBPerformFrontChatDatabaseResyncAfterReconnect();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.85 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        RBPerformFrontChatDatabaseResyncAfterReconnect();
    });
}

/**
 * 从服务端查询用户隐私权限设置（1008-26-34），并将 allow_read_receipt 缓存到 NSUserDefaults。
 */
- (void)fetchAndCachePrivacySettings:(NSString *)uid
{
    if (!uid || uid.length == 0) return;
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:26
                                                  andAction:34
                                                withNewData:@{@"uid": uid}
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess && returnValue && returnValue.length > 0) {
            NSData *jsonData = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            NSError *error = nil;
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
            if (!error && [dict isKindOfClass:[NSDictionary class]]) {
                int allowReadReceipt = [[dict objectForKey:@"allow_read_receipt"] intValue];
                // 服务端返回 0 或 1，如果字段不存在则默认为 1（开启）
                if ([dict objectForKey:@"allow_read_receipt"] == nil) {
                    allowReadReceipt = 1;
                }
                [[NSUserDefaults standardUserDefaults] setBool:(allowReadReceipt == 1) forKey:@"privacy_allow_read_receipt"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                NSLog(@"【隐私权限】已缓存 allow_read_receipt=%d", allowReadReceipt);
            }
        }
    }
                                              hudParentView:nil
                                        showLocalErrorAlert:NO
                                      completeForLocalError:nil];
}

@end
