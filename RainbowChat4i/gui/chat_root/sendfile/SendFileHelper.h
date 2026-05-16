//telegram @wz662
#import <Foundation/Foundation.h>
#import "JSQMessage.h"

@interface SendFileHelper : NSObject

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
 * 实现大文件消息中的大文件数据数据上传（支持断点续传逻辑），以及上传完成后的处理等全流程。
 *
 * @param fileName 要上传的文件名
 * @param filePath 要上传文件的完整路径
 * @param fileMd5 文件的md5码
 * @param cme 对应聊天界面中一条大文件消息的数据模型
 * @param observerForFileUploadProcessOK 观察者：用于文件上传完成时通知本方法的调用者来做余下的事（把这个观察者当回调来理解就好了）
 */
+ (void) processBigFileUpload:(NSString *)fileName filePath:(NSString *)filePath fileMd5:(NSString *)fileMd5 cme:(JSQMessage *)cme uploadedSucessObserver:(ObserverCompletion)observerForFileUploadProcessOK;

/// 尝试复制文件。
///
/// 之所以要进行复制的原因是：因为RainbowChat的文件发送，支持跨沙箱的文件读取，而其它应用的
/// 沙箱目不录每次启动都有可能会变化（这是ios文件系统的安全机制），为了保证本地发送的跨沙箱文
/// 件能被本地用户正常预览，所以需要在发送文件前进行复制尝试，这样因为复制到了RainbowChat自
/// 已的沙箱内，所以也就不存在权限以及源沙箱目录发生变动而导致无法在本地预览该文件的问题了）。
///
/// @param srcPath 源文件完整路径（含文件名）
/// @param destPath 要复制到的目地路径（含文件名）
/// @return YES表示复制成功，否则复制失败
+ (BOOL) tryCopy:(NSString *)srcPath destPath:(NSString *)destPath;

@end
