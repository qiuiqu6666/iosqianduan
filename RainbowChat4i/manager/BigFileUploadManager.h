//telegram @wz662
/**
 * 大文件上传管理器
 *
 * @author Jack Jiang
 * @since 2.1
 */

#import <Foundation/Foundation.h>
#import "BigFileUploadTask.h"

@interface BigFileUploadManager : NSObject

+ (instancetype)sharedInstance;

/**
 * 添加上传任务
 *
 * @param uploadTask 上传任务
 */
- (void) addUploadTask:(BigFileUploadTask *)uploadTask;

- (BOOL) isUploading:(NSString *)tid;

/**
 * 获得指定的task。
 *
 * @param tid task id
 * @return 如果存在对应tid的任务则返回，否则返回nil！
 */
- (BigFileUploadTask *) getUploadTask:(NSString *)tid;

/**
 * 暂停上传任务
 *
 * @param tid 任务id
 */
- (void) pause:(NSString *)tid;

/**
 * 重新开始已经暂停的上传任务
 *
 * @param tid 任务id
 */
- (void) resume:(NSString *)tid;

- (void) setFileStatusChangedObserver:(ObserverCompletion)fileStatusChangedObserver;
- (ObserverCompletion) getFileStatusChangedObserver;

@end

