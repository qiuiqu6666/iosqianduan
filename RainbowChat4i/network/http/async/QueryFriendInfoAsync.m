//telegram @wz662
#import "QueryFriendInfoAsync.h"
#import "HttpRestHelper.h"
#import "ViewControllerFactory.h"
#import "FriendsListProvider.h"
#import "IMClientManager.h"
#import "AlarmType.h"
#import "BasicTool.h"

@implementation QueryFriendInfoAsync

+ (void)rb_handleQueryResultWithSuccess:(BOOL)sucess
                               userInfo:(UserEntity *)userInfo
                                useMail:(BOOL)use_mail
                             friendMail:(NSString *)friend_mail
                                navCtrl:(UINavigationController *)navigationController
                            canOpenChat:(BOOL)canOpenChat
                              addSource:(NSString *)addSource
                        groupMemberInfo:(GroupMemberEntity *)memberInfo
{
    if(sucess && userInfo != nil)
    {
        FriendsListProvider *flp =[[IMClientManager sharedInstance] getFriendsListProvider];
        if(flp != nil && [flp isUserInRoster2:userInfo.user_uid]) {
            UserEntity *existing = [flp getFriendInfoByUid2:userInfo.user_uid];
            if (existing != nil) {
                if (existing.is_starred != nil && existing.is_starred.length > 0) {
                    userInfo.is_starred = existing.is_starred;
                }
                if ([BasicTool isStringEmpty:userInfo.latest_login_time] && ![BasicTool isStringEmpty:existing.latest_login_time]) {
                    userInfo.latest_login_time = existing.latest_login_time;
                }
            }
            [flp putFriend:userInfo];
        }
        else{
            AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
            if(ap != nil){
                [ap updateAlarmTitleAndExtra1:AMT_guestChatMessage dataId:userInfo.user_uid newTitle:userInfo.nickname newExtra1:userInfo.userAvatarFileName needUpdateSqlite:YES];
            }
        }
        [ViewControllerFactory goFriendInfoViewController:navigationController withDatas:userInfo canOpenChat:canOpenChat addSource:addSource groupMemberInfo:memberInfo];
    }
    else
    {
        if(use_mail)
        {
            [BasicTool areYouSureAlert:@"此邮件未注册过账号" content:@"您想要向此邮箱发送一封邀请使用APP的邮件吗？" okBtnTitle:@"邀请" cancelBtnTitle:NSLocalizedString(@"general_cancel", @"") parent:navigationController okHandler:^(UIAlertAction * _Nullable action) {
                [ViewControllerFactory goInviteFriendViewController:navigationController withMail:friend_mail];
            } cancelHandler:^(UIAlertAction * _Nullable action) {
            } cencelActionStyle:UIAlertActionStyleCancel];
        }
        else
        {
            AlertInfo(@"用户不存在或对方关闭了该搜索方式！");
        }
    }
}

+ (void)doIt:(NSString *)friend_uid hudParentView:(UIView *)view complete:(void (^)(BOOL sucess, UserEntity *userInfo))complete
{
    [[HttpRestHelper sharedInstance] submitGetFriendInfoToServer:NO
                                                            mail:nil
                                                             uid:(NSString *)friend_uid
                                                        complete:^(BOOL sucess, UserEntity *userInfo)
     {
         if(complete)
             complete(sucess, userInfo);
         
     } hudParentView:view];
}

+ (void)doIt:(BOOL)use_mail mail:(NSString *)friend_mail uid:(NSString *)friend_uid hudParentView:(UIView *)view withNC:(UINavigationController *)navigationController canOpenChat:(BOOL)canOpenChat
{
    [self doIt:use_mail mail:friend_mail uid:friend_uid hudParentView:view withNC:navigationController canOpenChat:canOpenChat addSource:nil];
}

+ (void)doIt:(BOOL)use_mail mail:(NSString *)friend_mail uid:(NSString *)friend_uid hudParentView:(UIView *)view withNC:(UINavigationController *)navigationController canOpenChat:(BOOL)canOpenChat addSource:(NSString *)addSource
{
    [self doIt:use_mail mail:friend_mail uid:friend_uid hudParentView:view withNC:navigationController canOpenChat:canOpenChat addSource:addSource groupMemberInfo:nil];
}

+ (void)doIt:(BOOL)use_mail mail:(NSString *)friend_mail uid:(NSString *)friend_uid hudParentView:(UIView *)view withNC:(UINavigationController *)navigationController canOpenChat:(BOOL)canOpenChat addSource:(NSString *)addSource groupMemberInfo:(GroupMemberEntity *)memberInfo
{
    [[HttpRestHelper sharedInstance] submitGetFriendInfoToServer:use_mail
                                                            mail:friend_mail
                                                             uid:friend_uid
                                                        complete:^(BOOL sucess, UserEntity *userInfo)
     {
         [QueryFriendInfoAsync rb_handleQueryResultWithSuccess:sucess userInfo:userInfo useMail:use_mail friendMail:friend_mail navCtrl:navigationController canOpenChat:canOpenChat addSource:addSource groupMemberInfo:memberInfo];
    } hudParentView:view];
}

+ (void)doItWithPhone:(NSString *)phone hudParentView:(UIView *)view withNC:(UINavigationController *)navigationController canOpenChat:(BOOL)canOpenChat addSource:(NSString *)addSource
{
    [[HttpRestHelper sharedInstance] submitGetFriendInfoByPhoneToServer:phone complete:^(BOOL sucess, UserEntity *userInfo) {
        [QueryFriendInfoAsync rb_handleQueryResultWithSuccess:sucess userInfo:userInfo useMail:NO friendMail:nil navCtrl:navigationController canOpenChat:canOpenChat addSource:addSource groupMemberInfo:nil];
    } hudParentView:view];
}

// 查看用户资料（方法内部将根据有网、无网等情况智能判断并进行相应的信息加载逻辑，确保最大限度查看的是最新数据）
+ (void)gotoWatchUserInfo:(NSString *)uid withInfo:(nullable UserEntity *)userInfo nav:(UINavigationController *)nav view:(UIView *)v vc:(UIViewController *)vc  {
    [self gotoWatchUserInfo:uid withInfo:userInfo nav:nav view:v vc:vc addSource:nil];
}

+ (void)gotoWatchUserInfo:(NSString *)uid withInfo:(nullable UserEntity *)userInfo nav:(UINavigationController *)nav view:(UIView *)v vc:(UIViewController *)vc addSource:(NSString *)addSource {
    [self gotoWatchUserInfo:uid withInfo:userInfo nav:nav view:v vc:vc addSource:addSource groupMemberInfo:nil];
}

+ (void)gotoWatchUserInfo:(NSString *)uid withInfo:(nullable UserEntity *)userInfo nav:(UINavigationController *)nav view:(UIView *)v vc:(UIViewController *)vc addSource:(NSString *)addSource groupMemberInfo:(GroupMemberEntity *)memberInfo {

    // 如是本地用户，则直接跳转到本地用户的"个人中心"界面
    if([[IMClientManager sharedInstance] isLocalUser:uid]){
        [ViewControllerFactory goUserViewController:nav];
        return;
    }

    // 如果userInfo内容不为空，由直接查看
    if(userInfo != nil){
        // 直接转到好友或陌生人信息查看界面（带添加来源和群成员信息透传）
        [ViewControllerFactory goFriendInfoViewController:nav withDatas:userInfo canOpenChat:YES addSource:addSource groupMemberInfo:memberInfo];
        return;
    }

    // 有网络的情况下，优先从网络加载最新数据
    if([ClientCoreSDK sharedInstance].connectedToServer){
        [QueryFriendInfoAsync doIt:NO mail:nil uid:uid hudParentView:v withNC:nav canOpenChat:YES addSource:addSource groupMemberInfo:memberInfo];
        return;
    }
    // 否则，就读取好友的缓存数据
    else{
        FriendsListProvider *flp = [[IMClientManager sharedInstance] getFriendsListProvider];
        if([flp isUserInRoster2:uid]) {
            UserEntity *friendInfo = [flp getFriendInfoByUid2:uid];
            if(friendInfo != nil) {
                // 转到好友信息查看界面（带添加来源和群成员信息透传）
                [ViewControllerFactory goFriendInfoViewController:nav withDatas:friendInfo canOpenChat:YES addSource:addSource groupMemberInfo:memberInfo];
                return;
            }
        }
    }
    
    [BasicTool showAlertInfo:@"您的网络不给力，请稍后再试！" parent:vc];
}

+ (void)gotoAddFriendRequestPage:(NSString *)uid
                             nav:(UINavigationController *)nav
                            view:(UIView *)view
                              vc:(UIViewController *)vc
                       addSource:(NSString *)addSource
{
    if ([[IMClientManager sharedInstance] isLocalUser:uid]) {
        [ViewControllerFactory goUserViewController:nav];
        return;
    }

    [QueryFriendInfoAsync doIt:uid hudParentView:view complete:^(BOOL sucess, UserEntity *userInfo) {
        if (sucess && userInfo != nil) {
            [ViewControllerFactory goFriendReqSendViewController:nav withDatas:userInfo addSource:addSource];
        } else {
            [BasicTool showAlertInfo:@"用户不存在或对方关闭了该搜索方式！" parent:vc];
        }
    }];
}

@end
