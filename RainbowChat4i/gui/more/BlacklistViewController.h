//
//  BlacklistViewController.h
//  RainbowChat4i
//
//  通讯录黑名单页面。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BlacklistViewController : UIViewController

@end

/// 黑名单管理工具类（本地缓存 + 服务端 API 对接）
@interface BlacklistManager : NSObject

+ (instancetype)sharedInstance;

/// 添加用户到黑名单（调用服务端接口 + 乐观更新本地缓存）
- (void)addUserToBlacklist:(NSString *)uid nickname:(NSString *)nickname avatarFileName:(nullable NSString *)avatarFileName;

/// 从黑名单中移除用户（调用服务端接口）
- (void)removeUserFromBlacklist:(NSString *)uid;

/// 从黑名单中移除用户（调用服务端接口，带回调）
- (void)removeUserFromBlacklist:(NSString *)uid complete:(nullable void (^)(BOOL success))complete hudParentView:(nullable UIView *)view;

/// 获取本地缓存的黑名单列表（返回 NSDictionary 数组，字段：user_uid, nickname, avatar, what_s_up, block_time）
- (NSArray<NSDictionary *> *)getBlacklist;

/// 检查用户是否在黑名单中（基于本地缓存）
- (BOOL)isUserInBlacklist:(NSString *)uid;

/// 从服务端刷新黑名单列表并更新本地缓存
- (void)refreshBlacklistFromServer:(nullable void (^)(BOOL success, NSArray<NSDictionary *> * _Nullable list))complete hudParentView:(nullable UIView *)view;

@end

NS_ASSUME_NONNULL_END
