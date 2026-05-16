//telegram @wz662
/**
 * 大文件后台下载任管理类（基于性能、体验等考虑，当前大文件下载跟微信一样：一次只允许同时下载一个文件！）。
 *
 * @author Jack Jiang
 * @since 4.3
 */

#import <Foundation/Foundation.h>
#import "BigFileDownloadTask.h"


/** 文件已存在，无需下载 */
#define BFDM_FILE_STATUS_FILE_COMPLETE       0
/** 文件正在下载中 */
#define BFDM_FILE_STATUS_FILE_DOWNLOADING    1
/**　文件下载已暂停 */
#define BFDM_FILE_STATUS_FILE_DOWNLOAD_PAUSE 2
/** 文件处于未下载完成状态 */
#define BFDM_FILE_STATUS_FILE_NOT_COMPLETE   3


/**
 大文件下载管理器的delegate类定义。
 */
@protocol BigFileDownloadManagerDelegate <NSObject>

@required//必须实现的代理方法
- (void) onPreExecute:(NSString *)fileMd5InManager;
- (void) onProgressUpdate:(NSString *)fileMd5InManager withProgress:(float)progress;
- (void) onPostExecute_onException:(NSString *)fileMd5InManager withError:(NSError *) exception;
- (void) onPostExecute_onSucess:(NSString *)fileMd5InManager withSavedPath:(NSString *)fileSavedPath;
- (void) onCancel:(NSString *)fileMd5InManager;
- (void) onPause:(NSString *)fileMd5InManager;
@end


@interface BigFileDownloadManager : NSObject<BigFileDownloadTaskDelegate>

@property (nonatomic, weak) id<BigFileDownloadManagerDelegate> delegate;

/*!
 * 取得本类实例的唯一公开方法。
 * <p>
 * 本类目前在APP运行中是以单例的形式存活，请一定注意这一点哦。
 *
 * @return 单例
 */
+ (BigFileDownloadManager *)sharedInstance;

/**
 重置本下载管理器中的参数为初始状态。
 本方法的调用主要用于APP中切换账号时，防止数据污染。
 */
- (void)clear;

/**
 * 开始/继续下载。
 *
 * @param fileMd5 要下载文件的md码
 * @param currentLength 文件在此之前已被断点下载完成的大小
 * @param fileDir 下载保存目录
 * @param fileName 文件名
 * @param fileLength 文件总大小
 */
- (void) startTask:(NSString *)fileMd5 currentLength:(long long)currentLength fileDir:(NSString *)fileDir fileName:(NSString *)fileName fileLength:(long long)fileLength;

/**
 * 取消本次下载任务。
 *
 * @param notificationObserver 是否通知代理实现类
 */
- (void) cancelTask:(BOOL) notificationObserver;

/**
 * 暂时本次下载（与取消下载相比，唯一的区别是设置fileStatus状态的不同，进而界面UI上的显示会有不同，仅此而已）
 */
- (void) pauseTask;

/**
 * 是否有正在下载中的任务。
 *
 * @return YES表示有任务（下载中），否则表示无有效任务（已下载完成或未有过下载任务）
 */
- (BOOL) isDownloading;

/**
 * 是否有暂停中的任务。
 *
 * @return YES表示当前下载已暂停
 */
- (BOOL) isPause;

- (int) getFileStatus;

/**
 * 当前任务中的文件是否是指定文件。
 *
 * @param fileMd5 文件的md5码
 * @return YES表示是，否则不是
 */
- (BOOL) isCurrentFile:(NSString *)fileMd5;

- (NSString *) getFileName;

- (void) printDebug;

@end
