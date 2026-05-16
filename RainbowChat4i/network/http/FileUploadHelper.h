//telegram @wz662
#import <Foundation/Foundation.h>
#import "AFNetworking.h"


@interface FileUploadHelper : NSObject

/**
 一个使用AFN 3.0上传文件的通用方法。

 @param filePath 要上传的文件的绝对路径
 @param fileName 要上传的文件名（此名将被服务端解析并用于保存文件时使用）
 @param uploadUrl 要上传文件的url地址
 @param params 额外的参数（可为nil）
 @param uploadProgress 上传进度回调
 @param success 上传成功后的回调
 @param failure 上传失败后的回调
 */
+ (void) uploadFileImpl:(NSString *_Nonnull)filePath
               withName:(NSString *_Nonnull)fileName
                 andUrl:(NSString *_Nonnull)uploadUrl
          andParameters:(NSDictionary *_Nullable)params
               progress:(nullable void (^)(NSProgress * _Nonnull))uploadProgress
                success:(void (^_Nullable)(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject))success
                failure:(void (^_Nullable)(NSURLSessionDataTask * _Nonnull task, NSError * _Nullable error))failure;

/**
 一个使用AFN 3.0上传文件块数据的方法（本方法多用于分片断点上传时）。

 @param fileData 要上传的文件块数据
 @param fileName 要上传的文件名（此名将被服务端解析并用于保存文件时使用）
 @param uploadUrl 要上传文件的url地址
 @param params 额外的参数（可为nil）
 @param uploadProgress 上传进度回调
 @param success 上传成功后的回调
 @param failure 上传失败后的回调
 @since 2.1
 */
+ (void) uploadDataImpl:(NSData *_Nonnull)fileData
               withName:(NSString *_Nonnull)fileName
                 andUrl:(NSString *_Nonnull)uploadUrl
          andParameters:(NSDictionary *_Nullable)params
               progress:(nullable void (^)(NSProgress * _Nonnull))uploadProgress
                success:(void (^_Nullable)(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject))success
                failure:(void (^_Nullable)(NSURLSessionDataTask * _Nonnull task, NSError * _Nullable error))failure;

@end
