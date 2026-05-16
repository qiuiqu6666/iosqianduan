//telegram @wz662
//
//  ReceivedShortVideoHelper.h
//  AVFoundationTest
//
//  Created by Jack Jiang on 2019/10/24.
//  Copyright © 2019 52im.net. All rights reserved.
//

/**
 * 收到短视频消息的实用工具类。
 *
 * @author Jack Jiang
 * @since 3.0
 */

#import <Foundation/Foundation.h>


@interface ReceivedShortVideoHelper : NSObject

/**
 * 获取视频对应的预览图文件名（用于客户端本地存放时）.
 *
 * @param videoFileName 含文件扩展名的视频文件名（形如："30000_ewewewewew23123213213.mp4"）
 * @return 返回文件名
 */
+ (NSString *)constructShortVideoThumbName_localSaved:(NSString *)videoFileName;

/**
 * 获取视频对应的预览图文件名（用于服务端存放时）.
 *
 * @param videoFileMd5 不含文件扩展名的视频文件名
 * @return 返回文件名
 */
+ (NSString *)constructShortVideoThumbName_toServer:(NSString *)videoFileMd5;

/**
 * 根据本类支持视频格式类型返回视频文件名.
 *
 * @param duration 视频时长（单位：秒）
 * @param videoFileMd5 视频文件md5码
 * @return 规范的短视频文件名
 */
+ (NSString *) constructShortVideoFileName:(int)duration md5:(NSString *)videoFileMd5;

/**
 * 返回存储收到的短视频的目录（结尾带反斜线）.
 *
 * @return 如果SDCard等正常则返回目标路径，否则返回null
 */
+ (NSString *)getReceivedFileSavedDirHasSlash;

/**
 * 返回存储收到的短视频的目录.
 *
 * @return 如果SDCard等正常则返回目标路径，否则返回null
 */
+ (NSString *)getReceivedFileSavedDir;

/**
 * 获得短视频消息的视频文件下载服务的完整http地址.
 * <p>
 * 形如：“http://192.168.1.195:8080/rainbowchat_pro/ShortVideoDownloader?user_uid=400007
 * &file_name=8990_dsjdsdsdjskdskdkj2232.mp4&file_md5=1aa7e1cc0405e3d5a52ae25d9eb6fbbb”。
 *
 * @param file_name 要下载的视频文件名
 * @param fileMd5 要下载的文件md5码
 * @return 完整的http文件下载地址
 */
+ (NSString *)getShortVideoDownloadURL:(NSString *)file_name md5:(NSString *)fileMd5;

/**
 * 异步获取短视频消息的视频文件下载地址（从服务器接口获取video_url）.
 * <p>
 * 后端接口返回格式：
 * {
 *   "code": 0,
 *   "data": {
 *     "video_url": "https://...",
 *     "file_name": "...",
 *     "file_md5": "..."
 *   },
 *   "message": "success"
 * }
 *
 * @param file_name 要下载的视频文件名
 * @param fileMd5 要下载的文件md5码
 * @param complete 完成回调，返回video_url（成功时）或nil（失败时）
 */
+ (void)getShortVideoDownloadURLAsync:(NSString *)file_name md5:(NSString *)fileMd5 complete:(void (^)(NSString *video_url))complete;

/**
 * 获得短视频消息的视频首帧预览图片文件下载服务的完整http地址.
 * <p>
 * 形如：““http://192.168.1.195:8080/rainbowchat/ShortVideoDownloader?user_uid=400007
 * &file_name=8990_dsjdsdsdjskdskdkj2232.mp4&file_md5=1aa7e1cc0405e3d5a52ae25d9eb6fbbb”。
 *
 * @param thumbImageFileName 要下载的图片文件名
 * @param videofileMd5 要下载的视频文件md5码
 * @return 完整的http文件下载地址
 */
+ (NSString *)getShortVideoThumbDownloadURL:(NSString *)thumbImageFileName videofileMd5:(NSString *)videofileMd5;

@end

