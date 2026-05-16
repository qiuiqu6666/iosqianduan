//telegram @wz662
/**
 * 大文件下载实用类（支持断点续传）。
 *
 * @author JackJiang
 * @since 4.3
 */

#import <Foundation/Foundation.h>

/**
 大文件下载任务的delegate类定义。
 */
@protocol BigFileDownloadTaskDelegate <NSObject>

@required//必须实现的代理方法

/**
 下载任务已启动但还未真正进行数据通信和下载前的回调（应用层可在此回调里实现下载进度条的UI显示等）。
 */
- (void) onDownloadTaskPreExecute;

/**
 下载进度更新（应用层可在此回调里实现下载进度的UI刷新等）。
 @param progress 进度值为0~1.0f的浮点数
 */
- (void) onDownloadTaskProgressUpdate:(float)progress;

/**
 下载已完成，但发生了异常（即没有成功完成）。
 @param error 异常原因
 */
- (void) onDownloadTaskExecuteComplete_onException:(NSError *)error;

/**
 下载已成功完成；
 @param fileSavedPath 文件保存的绝对路径
 */
- (void) onDownloadTaskExecuteComplete_onSucess:(NSString *)fileSavedPath;
@end


@interface BigFileDownloadTask : NSObject<NSURLSessionDelegate>

- (id)initWith:(NSString *)fileURL saveDir:(NSString *)saveDir fileName:(NSString *)fileName fileSize:(long long)fileSize delegate:(id<BigFileDownloadTaskDelegate>)delegate;

/**
 * 启动当前下载任务。
 */
- (void) start;

/**
 * 取消当前下载任务。
 */
- (void) cancel;

/**
 * 强制性地走下载完成这个流程。
 * <p>
 * 因为有些情况下，文件明明已经下载完成，而被拉起了一次任务，那么此次任务就不需要
 * 真的从网络请求数据，只需要强制调用这个完成方法就能保持正常一致的表现了。
 */
- (void) forceComplete;

@end





