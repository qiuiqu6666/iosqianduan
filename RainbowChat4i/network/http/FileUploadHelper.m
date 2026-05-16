//telegram @wz662
#import "FileUploadHelper.h"
#import "EVAToolKits.h"

@implementation FileUploadHelper

+ (void) uploadFileImpl:(NSString *)filePath
               withName:(NSString *)fileName
                 andUrl:(NSString *)uploadUrl
          andParameters:(NSDictionary *)params
               progress:(nullable void (^)(NSProgress * _Nonnull))uploadProgress
                success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    // 创建管理者对象
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];

    // 设置文件上传超时时间
    manager.requestSerializer.timeoutInterval = 20.0f; // 20秒超时

    // 使用的是https
    if([EVAToolKits isHttps:uploadUrl])
    {
        // 支持https需要的额外设置
        [EVAToolKits setupHttps:manager];
    }
    
    // 为http请求头设置token，以备服务端检验请求合法性
    [EVAToolKits setupAuthorization:manager];

    // 开始上传
    [manager POST:uploadUrl parameters:params headers:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileURL:[NSURL fileURLWithPath:filePath] name:@"file" fileName:fileName mimeType:@"application/octet-stream" error:nil];
    } progress:uploadProgress success:success failure:failure];
}

+ (void) uploadDataImpl:(NSData *)fileData
               withName:(NSString *)fileName
                 andUrl:(NSString *)uploadUrl
          andParameters:(NSDictionary *)params
               progress:(nullable void (^)(NSProgress * _Nonnull))uploadProgress
                success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    // 创建管理者对象
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];

    // 设置文件上传超时时间
    manager.requestSerializer.timeoutInterval = 20.0f; // 20秒超时

    // 使用的是https
    if([EVAToolKits isHttps:uploadUrl])
    {
        // 支持https需要的额外设置
        [EVAToolKits setupHttps:manager];
    }
    
    // 为了解决上传大文件时，通过 parameters 参数传递的文件名在服务端取出乱码的问题，以下两行代码的设置方法是无法解决的，解决方法请见服务端！
//    manager.requestSerializer.stringEncoding = NSUTF8StringEncoding;
//    [manager.requestSerializer setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    
    // 为http请求头设置token，以备服务端检验请求合法性
    [EVAToolKits setupAuthorization:manager];

    // 开始上传
    [manager POST:uploadUrl parameters:params headers:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:fileData name:@"mFile" fileName:fileName mimeType:@"application/octet-stream"];
    } progress:uploadProgress success:success failure:failure];
}

@end
