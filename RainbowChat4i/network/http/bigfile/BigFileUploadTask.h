//telegram @wz662
/*
* 大文件上传任务封装实现类(支持大文件断点分块上传)。
*
* <pre>
* 【大文件上传的技术难点】：
* 因为标准的http协议中并未包含文件的断点上传，这也就意味着各主流http库（比如ios端的AFN、
* 服务端的apache fileupload库等）都不能原生支持断点上传（即指定字节索引位置的文件数据上传），非
* 得让它们支持那就得直接改它们的源码了，这样无论是日后的升级、维护还是更换方案，代价都太大了。
*
* 【本类的大文件实现思路】：
* 1）客户端将文件分成块，按块逐块上传到服务端；
* 2）服务端先将各块临时保存；
* 3）服务端判定所有块都上传完成后，将这些块临时文件拼合成正式的文件（并删除临时文件）。
*
* 【本类的大文件实现特色】：
* 1）技术原理简单易行：不需要改任何http标准通用类代码，直接就用；
* 2）实际应用稳定可靠：在网络不好的情况下，如果需要断点上传，只需要从上次上传完成的最后一块的前推一块上传（前推
*    一块上传的目的是怕最后一块的数据因上次任务中断而不完整），技术上很经济。
* </pre>
*
* @author Jack Jiang
* @since 2.1
*/

#import <Foundation/Foundation.h>


#define BFUT_UPLOAD_STATUS_INIT       0
#define BFUT_UPLOAD_STATUS_UPLOADING  1
#define BFUT_UPLOAD_STATUS_PAUSE      2
#define BFUT_UPLOAD_STATUS_SUCCESS    3
#define BFUT_UPLOAD_STATUS_ERROR      -1


/**
  大文件上传任务的状态delegate类定义。
 */
@protocol BigFileUploadTaskDelegate <NSObject>

@required//必须实现的代理方法

/**
 * 上传中
 *
 * @param percent    上传进度百分比（0~100的整数）
 */
- (void) onUploading:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath percent:(int)percent chunk:(int) chunk chunks:(int)chunks;

/**
 * 上传成功
 */
- (void) onUploadSuccess:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath chunk:(int)chunk chunks:(int)chunks;

/**
 * 上传失败
 *
 * @param errorCode 错误码
 */
- (void) onError:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath errorCode:(int)errorCode chunk:(int)chunk chunks:(int)chunks;

/**
 * 上传暂停
 */
- (void) onPause:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath chunck:(int)chunck chuncks:(int)chuncks;

@end


@interface BigFileUploadTask : NSObject

- (id) initWith:(NSString *)tid url:(NSString *)url fileName:(NSString *)fileName filePath:(NSString *)filePath fileMd5:(NSString *)fileMd5 chunck:(int)chunck delegate:(id<BigFileUploadTaskDelegate>)delegate userPropeties:(NSDictionary<NSString *, NSString *> *)userPropeties;

- (void) run;

- (NSString *) getTid;
- (NSString *) getUrl;
- (NSString *) getFileName;
- (void) setUploadStatus:(int)uploadStatus;
- (int) getUploadStatus;

@end

