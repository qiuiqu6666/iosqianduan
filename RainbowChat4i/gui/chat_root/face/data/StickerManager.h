#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 自定义表情包管理器（单例）
 *
 * 负责：
 *  - 从服务端查询、删除、排序自定义表情
 *  - 上传新表情
 *  - 本地内存/磁盘缓存表情图片
 *  - 构造表情下载 URL
 */
@interface StickerManager : NSObject

+ (instancetype)sharedInstance;

/// 当前用户的自定义表情列表（每项为 NSDictionary：id, file_name, file_size, sort_order, create_time, url）
@property (nonatomic, strong, readonly) NSArray<NSDictionary *> *stickerList;

/// 表情列表是否已加载过
@property (nonatomic, assign, readonly) BOOL loaded;

/**
 * 从服务端刷新表情列表.
 * @param complete 回调：YES 成功
 */
- (void)refreshStickersFromServer:(void (^)(BOOL success))complete;

/**
 * 上传一张新表情图片.
 * @param image 表情图片
 * @param complete 回调：YES 成功
 */
- (void)uploadSticker:(UIImage *)image complete:(void (^)(BOOL success))complete;

/**
 * 删除表情（批量）.
 * @param ids 要删除的表情 ID 数组
 * @param complete 回调：YES 成功
 */
- (void)deleteStickers:(NSArray<NSString *> *)ids complete:(void (^)(BOOL success))complete;

/**
 * 获取表情原图的下载 URL.
 * @param stickerInfo 表情信息字典（优先使用 url 字段，否则拼接 BinaryDownloader URL）
 * @return 下载 URL 字符串
 */
- (NSString *)stickerDownloadURL:(NSDictionary *)stickerInfo;

/**
 * 获取表情缩略图的下载 URL.
 * @param stickerInfo 表情信息字典（优先使用 thumbnail_url 字段，否则退回原图 URL）
 * @return 缩略图下载 URL 字符串
 */
- (NSString *)stickerThumbnailURL:(NSDictionary *)stickerInfo;

/**
 * 获取表情图片的下载 URL（通过 file_name 和 user_uid）.
 * @param fileName 表情文件名
 * @param userUid 用户 UID
 * @return 下载 URL 字符串
 */
- (NSString *)stickerDownloadURLForFileName:(NSString *)fileName userUid:(NSString *)userUid;

/**
 * 从缓存中获取表情缩略图，如不存在则异步下载（用于表情面板展示）.
 * @param stickerInfo 表情信息字典
 * @param complete 回调：UIImage（可能为 nil）
 */
- (void)loadStickerThumbnail:(NSDictionary *)stickerInfo complete:(void (^)(UIImage * _Nullable image))complete;

/**
 * 从缓存中获取表情原图，如不存在则异步下载（用于发送消息/查看大图）.
 * @param stickerInfo 表情信息字典
 * @param complete 回调：UIImage（可能为 nil）
 */
- (void)loadStickerImage:(NSDictionary *)stickerInfo complete:(void (^)(UIImage * _Nullable image))complete;

/**
 * 本地缓存目录路径
 */
- (NSString *)stickerCacheDirectory;

@end

NS_ASSUME_NONNULL_END
