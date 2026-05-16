// 

/**
 * 发送短视频消息的各种实用方法辅助类.
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 * @since 3.0
 */

#import <Foundation/Foundation.h>
#import "JSQMessage.h"

@interface SendShortVideoHelper : NSObject

/**
 * 发送前的检查。
 *
 * @return true表示检查通过，否则不合法的文件不应被发送
 */
+ (BOOL) beforeSend_check:(NSString *)filePath vc:(UIViewController *)vc;

/// 计算文件的md5码（异步线程中执行，提升用户体验）。
///
/// @param filePath 文件完整路径
/// @param parent 要显示的进度菊花所依赖的w父view
/// @param complete 计算完成后的回调通知
+ (void) beforeSend_calculateMD5:(NSString *)filePath parent:(UIView *)parent complete:(void (^)(BOOL sucess, NSString *fileMD5))complete;

/**
 * 将临时视频文件重命名.
 *
 * @param tempFileSavedPath 录制完成后的原始临时短视频文件完整路径
 * @param fileMd5 视频文件的码
 * @param durationOfVideo 视频时长（单位：秒）
 * @return 重命名成功则返回新文件完整路径，否则返回nil
 */
+ (NSString *) renameUseMD5:(NSString *)tempFileSavedPath md5:(NSString *)fileMd5 duration:(int)durationOfVideo;

/**
 * 实现大文件消息中的大文件数据数据上传（支持断点续传逻辑），以及上传完成后的处理等全流程。
 *
 * @param videoFileName 要上传的文件名
 * @param videoFilePath 要上传文件的完整路径
 * @param videoFileMd5 文件的md5码
 * @param cme 对应聊天界面中一条大文件消息的数据模型
 * @param observerForFileUploadProcessOK 观察者：用于文件上传完成时通知本方法的调用者来做余下的事（把这个观察者当回调来理解就好了）
 */
+ (void) processShortVideoUpload:(NSString *)videoFileName filePath:(NSString *)videoFilePath fileMd5:(NSString *)videoFileMd5 cme:(JSQMessage *)cme uploadedSucessObserver:(ObserverCompletion)observerForFileUploadProcessOK;

@end
