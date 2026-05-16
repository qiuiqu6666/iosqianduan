//telegram @wz662
/**
 * 查询指定用户的个人信息.
 *
 * 【注意】：本类当前主要用于实现“查找好友”功能界面中的精确查找（
 * 即只精确查找一个好友的个人信息）等场景下.
 *
 * @author Jack Jiang, 2017-11-28
 * @version 1.0
 */

#import <Foundation/Foundation.h>
#import "UserEntity.h"
#import "GroupMemberEntity.h"

@interface QueryFriendInfoAsync : NSObject


/**
 开始查询个人信息.

 @param friend_uid 被查询者的UID
 @param view 为nil表示不显示网络请求进度提示菊花，否则显示
 @param complete 查询结果回调
 */
+ (void)doIt:(NSString *)friend_uid hudParentView:(UIView *)view complete:(void (^)(BOOL sucess, UserEntity *userInfo))complete;

/**
 开始查询个人信息(如此查到此人信息则跳到用户信息查看界面，否则如果使用的是邮件则跳到邮件邀请界面)。

 @param use_mail 是否使用注珊邮箱查找
 @param friend_mail 被查询者的注册邮箱(use_mail=YES时有意义)
 @param friend_uid 被查询者的UID(use_mail=NO时有意义)
 @param view 为nil表示不显示网络请求进度提示菊花，否则显示
 @param navigationController 查询成功后跳转界面时的父界面的UINavigationController对象，用于界面切换时使用
 @param canOpenChat YES表示界面上显示打开聊天界面按钮，否则不显示
 */
+ (void)doIt:(BOOL)use_mail mail:(NSString *)friend_mail uid:(NSString *)friend_uid  hudParentView:(UIView *)view withNC:(UINavigationController *)navigationController canOpenChat:(BOOL)canOpenChat;

/**
 开始查询个人信息(带添加来源透传)。
 */
+ (void)doIt:(BOOL)use_mail mail:(NSString *)friend_mail uid:(NSString *)friend_uid  hudParentView:(UIView *)view withNC:(UINavigationController *)navigationController canOpenChat:(BOOL)canOpenChat addSource:(NSString *)addSource;

+ (void)doItWithPhone:(NSString *)phone hudParentView:(UIView *)view withNC:(UINavigationController *)navigationController canOpenChat:(BOOL)canOpenChat addSource:(NSString *)addSource;

/**
 * 查看用户资料（方法内部将根据有网、无网等情况智能判断并进行相应的信息加载逻辑，确保最大限度查看的是最新数据）。
 *
 * @param uid 用户uid
 * @param userInfo 用户信息数据，如果此数据不为空，将优先查看此数据
 */
+ (void)gotoWatchUserInfo:(NSString *)uid withInfo:(nullable UserEntity *)userInfo nav:(UINavigationController *)nav view:(UIView *)v vc:(UIViewController *)vc;

/**
 * 查看用户资料（带添加来源透传）。
 */
+ (void)gotoWatchUserInfo:(NSString *)uid withInfo:(nullable UserEntity *)userInfo nav:(UINavigationController *)nav view:(UIView *)v vc:(UIViewController *)vc addSource:(NSString *)addSource;

/**
 * 查看用户资料（带群成员信息，用于显示入群时间和邀请人）。
 */
+ (void)gotoWatchUserInfo:(NSString *)uid withInfo:(nullable UserEntity *)userInfo nav:(UINavigationController *)nav view:(UIView *)v vc:(UIViewController *)vc addSource:(NSString *)addSource groupMemberInfo:(nullable GroupMemberEntity *)memberInfo;

/// 直接进入“发送加好友请求”页面；内部会先拉取最新用户资料。
+ (void)gotoAddFriendRequestPage:(NSString *)uid
                             nav:(UINavigationController *)nav
                            view:(UIView *)view
                              vc:(UIViewController *)vc
                       addSource:(NSString *)addSource;

@end
