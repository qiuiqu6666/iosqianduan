//telegram @wz662
//
//  ReceivedShortVideoHelper.m
//  AVFoundationTest
//
//  Created by Jack Jiang on 2019/10/24.
//  Copyright © 2019 52im.net. All rights reserved.
//

/**
 * 收到短视频消息的实用工具类。
 *
 * @author Jack Jiang
 * @since 2.1
 */

#import "ReceivedShortVideoHelper.h"
#import "FileTool.h"
#import "Default.h"
#import "UserEntity.h"
#import "IMClientManager.h"

@implementation ReceivedShortVideoHelper

// 获取视频对应的预览图文件名（用于客户端本地存放时）
+ (NSString *)constructShortVideoThumbName_localSaved:(NSString *)videoFileName
{
    if(videoFileName == nil)
    {
        DDLogWarn(@"无效的参数：videoFileName == nil!");
        return nil;
    }
    
    return [NSString stringWithFormat:@"%@.jpg", [FileTool getFileNameWithoutExt:videoFileName]];
}

// 获取视频对应的预览图文件名（用于服务端存放时）
+ (NSString *)constructShortVideoThumbName_toServer:(NSString *)videoFileMd5
{
    if(videoFileMd5 == nil)
    {
        DDLogWarn(@"无效的参数：videoFileMd5 == nil!");
        return nil;
    }

    return [NSString stringWithFormat:@"%@.jpg", videoFileMd5];
}

// 根据本类支持视频格式类型返回视频文件名
+ (NSString *) constructShortVideoFileName:(int)duration md5:(NSString *)videoFileMd5
{
    if(videoFileMd5 == nil)
    {
        DDLogDebug(@"无效的参数：fileNameNoExt == nil!");
        return nil;
    }

    // 文件名形如：120000_asd343jdfdsjf324k234kjkdsfs.mp4（120000是视频文件时长（单位：毫秒））
    return [NSString stringWithFormat:@"%d_%@.mp4", (duration * 1000), videoFileMd5];
}

// 返回存储收到的短视频的目录（结尾带反斜线）
+ (NSString *)getReceivedFileSavedDirHasSlash
{
    NSString *dir = [ReceivedShortVideoHelper getReceivedFileSavedDir];
    return dir ==  nil? nil : [NSString stringWithFormat:@"%@/", dir];
}

// 返回存储收到的短视频的目录
+ (NSString *)getReceivedFileSavedDir
{
    NSString *dir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_SHORTVIDEO_RELATIVE_DIR];
    return dir;
}

// 获得短视频消息的视频文件下载服务的完整http地址.
+ (NSString *)getShortVideoDownloadURL:(NSString *)file_name md5:(NSString *)fileMd5
{
    NSString *fileURL = nil;
    
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    if(localUserInfo != nil)
    {
        fileURL = [NSString stringWithFormat:@"%@?user_uid=%@&file_name=%@&file_md5=%@", SHORTVIDEO_DOWNLOADER_CONTROLLER_URL_ROOT
        , localUserInfo.user_uid
        , file_name, fileMd5];
    }
    return fileURL;
}

// 获得短视频消息的视频首帧预览图片文件下载服务的完整http地址.
// 说明：OSS 启用后，服务端返回 302 重定向到 OSS 地址，客户端自动跟随。
//
// 参数说明（对应服务端 ShortVideoThumbDownloader 的参数）：
//   - video_file_md5：视频文件的MD5值，服务端用 {video_file_md5}.jpg 定位预览图文件
//   - thumb_image_file_name：预览图文件名，返回给客户端用于本地保存
//   - default_thumb_if_no：预览图不存在时返回默认图片
+ (NSString *)getShortVideoThumbDownloadURL:(NSString *)thumbImageFileName videofileMd5:(NSString *)videofileMd5
{
    NSString *fileURL = nil;
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    if(localUserInfo != nil)
    {
        // 服务端通过 video_file_md5 参数在服务端查找 {video_file_md5}.jpg 作为预览图文件
        // thumb_image_file_name 用于客户端本地保存时的文件名
        fileURL = [NSString stringWithFormat:@"%@?user_uid=%@&video_file_md5=%@&thumb_image_file_name=%@&default_thumb_if_no=1"
                   , SHORTVIDEO_THUMB_DOWNLOADER_CONTROLLER_URL_ROOT
                   , localUserInfo.user_uid
                   , videofileMd5
                   , (thumbImageFileName != nil ? thumbImageFileName : @"")];
    }
    return fileURL;
}

// 获取短视频消息的视频文件下载地址
// 说明：服务端已集成 OSS，所有下载请求返回 HTTP 302 重定向到 OSS 地址，
//      播放器 / 下载器会自动跟随 302，因此只需返回服务端 Servlet URL 即可。
+ (void)getShortVideoDownloadURLAsync:(NSString *)file_name md5:(NSString *)fileMd5 complete:(void (^)(NSString *video_url))complete
{
    if(file_name == nil || file_name.length == 0 || fileMd5 == nil || fileMd5.length == 0)
    {
        DDLogError(@"【获取视频URL】参数无效，file_name=%@, fileMd5=%@", file_name, fileMd5);
        if(complete)
            complete(nil);
        return;
    }
    
    // 直接构造下载 URL（服务端返回 302 重定向到 OSS，客户端自动跟随）
    NSString *downloadURL = [ReceivedShortVideoHelper getShortVideoDownloadURL:file_name md5:fileMd5];
    DDLogDebug(@"【获取视频URL】构造的下载URL：%@", downloadURL);
    
    if(complete)
        complete(downloadURL);
}

@end
