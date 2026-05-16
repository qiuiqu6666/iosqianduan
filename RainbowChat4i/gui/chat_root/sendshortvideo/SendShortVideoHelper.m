//telegram @wz662
//
//  SendShortVideoHelper.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2019/11/13.
//  Copyright © 2019 JackJiang. All rights reserved.
//

#import "SendShortVideoHelper.h"
#import "FileTool.h"
#import "MBProgressHUD.h"
#import "ReceivedShortVideoHelper.h"
#import "ShortVideoUploadTaskListenerForChat.h"
#import "BigFileUploadManager.h"
#import "UserEntity.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "BigFileType.h"
#import "FileUploadHelper.h"

@implementation SendShortVideoHelper


#pragma mark - 公开方法

// 发送前的检查
+ (BOOL) beforeSend_check:(NSString *)filePath vc:(UIViewController *)vc
{
    // 文件是否存的检查
    if(filePath == nil || ![FileTool fileExists:filePath])
    {
        DDLogWarn(@"【短视频上传-beforeSend_check】要发送的短视频文件“%@”不存在，本地发送没有继续！", filePath);
        [BasicTool showAlertWarn:@"短视频文件不存在，发送已被取消！" parent:vc];
        return NO;
    }
    
    // 是否文件夹检查
    BOOL isDir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir];
    if(isDir)
    {
        DDLogWarn(@"【短视频上传-beforeSend_check】要发送的“%@”不是文件，本地发送没有继续！", filePath);
        [BasicTool showAlertWarn:@"不是短视频文件，发送已被取消！" parent:vc];
        return NO;
    }
    
    // 允许发送的最大文件大小的检查
    long long fileSixe = [FileTool fileSizeAtPath:filePath];
    if(fileSixe > SEND_SHORT_VIDEO_DATA_MAX_LENGTH || fileSixe <= 0)
    {
        DDLogWarn(@"【短视频上传-beforeSend_check】要发送的短视频文件“%@”大小非法，(MAX=“%d”字节)，本地发送没有继续！", filePath, SEND_SHORT_VIDEO_DATA_MAX_LENGTH);
        [BasicTool showAlert:@"短视频文件超限提示" content:[NSString stringWithFormat:@"短视频文件过大，当前允许最大发送 %@ 的文件，本次发送已取消！", [FileTool getConvenientFileSize:fileSixe]] btnTitle:@"知道了" parent:vc];
        return NO;
    }
    
    DDLogInfo(@"【短视频上传-beforeSend_check】短视频文件：“%@”的前置检查完成，马上进入MD5码计算...", filePath);

    return YES;
}

// 计算文件的md5码（异步线程中执行，提升用户体验）
+ (void) beforeSend_calculateMD5:(NSString *)filePath parent:(UIView *)parent complete:(void (^)(BOOL sucess, NSString *fileMD5))complete
{
    // 显示进度提示菊花
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:parent animated:YES];
    hud.label.text = @"短视频准备中..";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),^{
        @try
        {
            // 开始计算md5码
            NSString *md5ForFile = [FileTool getFileMD5WithPath:filePath];
            
            // 计算完成后在主线程中进行回h调通知
            dispatch_async(dispatch_get_main_queue(), ^{
                DDLogInfo(@"【短视频上传-beforeSend_calculateMD5】大文件：“%@”的md5码计算完成，结果：“%@”", filePath, md5ForFile);
                
                // 隐藏进度提示菊花
                [hud hideAnimated:NO];
                // 回调通知
                complete(YES, md5ForFile);
            });
        }
        @catch (NSException* e)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                // 隐藏进度提示菊花
                [hud hideAnimated:NO];
                // 回调通知
                complete(NO, nil);
            });
            return;
        }
    });
}

// 将临时视频文件重命名
+ (NSString *) renameUseMD5:(NSString *)tempFileSavedPath md5:(NSString *)fileMd5 duration:(int)durationOfVideo
{
    NSString *fileAfterRename = nil;
    
    if(fileMd5 != nil && tempFileSavedPath != nil)
    {
        // 存放于数据库、本地缓存的文件名格式："时长_MD5码.mp4",形如:"120000_0b272fca28252641231a94f63d8e25fa.mp4"
        NSString *fileNameUsedMd5 = [ReceivedShortVideoHelper constructShortVideoFileName:durationOfVideo md5:fileMd5];
        
        NSString *destDir = [ReceivedShortVideoHelper getReceivedFileSavedDir];
        [FileTool tryCreateDirs:destDir];
        fileAfterRename = [NSString stringWithFormat:@"%@/%@", destDir, fileNameUsedMd5];
        
        BOOL renameSucess = [FileTool renameFile:tempFileSavedPath toFilePath:fileAfterRename];
        if(!renameSucess)
        {
            DDLogDebug(@"【短视频上传-renameUseMD5】将临时文件%@重命名失败了，上传将不能继续！", tempFileSavedPath);
            // 如果重命名失败，就尝试把这个文件删除（没有必要留了）
            [FileTool removeFile:fileAfterRename];
            [FileTool removeFile:tempFileSavedPath];
            return nil;
        }
    }
    
    return fileAfterRename;
}

// 实现短视频消息中的短视频文件数据数据上传（支持断点续传逻辑），以及上传完成后的处理等全流程
+ (void) processShortVideoUpload:(NSString *)videoFileName filePath:(NSString *)videoFilePath fileMd5:(NSString *)videoFileMd5 cme:(JSQMessage *)cme uploadedSucessObserver:(ObserverCompletion)observerForFileUploadOK
{
    // 短视频文件上传状态监听器
    ShortVideoUploadTaskListenerForChat *utl = [[ShortVideoUploadTaskListenerForChat alloc] initWith:cme];
    [utl setFileUploadedSucessObserver:observerForFileUploadOK];
    
    //    // 通过回调通知ui，及时将大文件上传进度条显示出来（此时肯定是进度为0啦），让用户知道文件已在上传处理中，提升体验
    //    [utl onUploading:fileName fileMd5:fileMd5 fileFullPath:filePath percent:0 chunk:-1 chunks:-1];
    
    BigFileUploadManager *um = [BigFileUploadManager sharedInstance];
    // 检查文件是否正在上传中（确保相同md5的任务只有一个在上传中）
    if([um isUploading:videoFileMd5])
    {
        DDLogWarn(@"【短视频文件上传-SendShortVideoHelper】要上传短视频文件：“%@”， 已存在相同的上传任务，本次任务没有继续！", videoFilePath);
        [utl onError:videoFileName fileMd5:videoFileMd5 fileFullPath:videoFilePath errorCode:-1 chunk:-1 chunks:-1];
        return;
    }
    
    // 检查参数的合法性
    if (videoFilePath == nil || videoFileName == nil || videoFileMd5 == nil)
    {
        DDLogWarn(@"【短视频文件上传-SendShortVideoHelper】相关参数不能为空，本次上传取消（filePath=%@, fileName=%@, fileMd5=%@）!", videoFilePath, videoFileName, videoFileMd5);
        [utl onError:videoFileName fileMd5:videoFileMd5 fileFullPath:videoFilePath errorCode:-1 chunk:-1 chunks:-1];
        return;
    }
    
    // TODO: 文件是否存在、文件大小、文件长度等前置检查已经在SendFileProcessor中做过了，本方法中就不需要重复做了
    
    // 本地用户信息
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    if (localUser != nil)
    {
        //** 首先向服务端提交短视频文件信息查询请求（看看是否需要上传，或者要从第几块开始上传——即断点上传，断点上传原理请见：BigFileUploadTask.h的类说明）
        [[HttpRestHelper sharedInstance] queryBigFileInfoFromServer:videoFileMd5 userUid:localUser.user_uid fileType:BigFileType_SHORT_VIDEO complete:^(BOOL sucess, NSString *retCode, int chunkCount) {
            
            if(sucess)
            {
                // 本次开始上传的分块索引起始块
                int startChunck = 1;
                
                // 服服务返回的查询结果码（详见http文档中“【接口1015-23-7】”的详细说明）：
                // * 0 表示该文件不存在(未被上传过)
                // * 1 表示该文件已经存在且已上传完成（无需再次上传）
                // * 2 表示该文件已经存在查未上传完成（此时chunkCountInServer才有意义）
                NSString *returnCode = retCode;
                // 该文件在服务端已传完的分块个数（为>=0的整数）
                int chunkCountInServer = chunkCount;

                DDLogInfo(@"【短视频文件上传-SendShortVideoHelper】从服务端查询该文件的断点续传信息成功返回，数据结果：retCode=%@, chunkCountInServer=%d（filePath=%@, fileName=%@, fileMd5=%@）", retCode, chunkCountInServer, videoFilePath, videoFileName, videoFileMd5);

                // 该md5码对应的文件已经存在于服务器上了（不需要重复上传）
                if ([@"1" isEqualToString:returnCode])
                {
                    DDLogInfo(@"【短视频文件上传-SendShortVideoHelper】短视频文件：“%@”已经存在于服务器，本次不需要重复上传文件了！【END】", videoFilePath);
                    [utl onUploadSuccess:videoFileName fileMd5:videoFileMd5 fileFullPath:videoFilePath chunk:-1 chunks:-1];
                    
                    // 不需要上传了，直接return
                    return;
                }
                // 表示该文件已经存在查未上传完成（此时chunkCountInServer才有意义）
                else if ([@"2" isEqualToString:returnCode])
                {
                    // 比如“chunkCountInServer”=2时，表示当前服务端已经上传了2块，但因为无法确定最后一块
                    // 是否已被正常上传完成，所以本次的上传应该重传这最后一块，即本次应从“第2块”开始传
                    startChunck = chunkCountInServer;

                    DDLogInfo(@"【短视频文件上传-SendShortVideoHelper】短视频文件：“%@”的第%d块已经上传，本次将从第%d块续传。。。", videoFilePath, chunkCountInServer, startChunck);
                }
                // 表示该文件不存在(未被上传过)
                else
                {
                    DDLogDebug(@"【短视频文件上传-SendShortVideoHelper】短视频文件：“%@”从未被上传过，本次将从第%d块开始从头上传。。。。。。", videoFilePath, startChunck);
                }
                
                
                //** 检查完成，开始决定文件数据的上传了
                // 至此，真正的文件数据上传还没开始，此时的 onUploading: 回调是为了让应用层的UI上能及时显示为上传初始状态，体升用户体验
                [utl onUploading:videoFileName fileMd5:videoFileMd5 fileFullPath:videoFilePath percent:0 chunk:-1 chunks:-1];
                DDLogInfo(@"【短视频文件上传-SendShortVideoHelper】要上传的短视频文件路径是：“%@”， 上传马上开始.......", videoFilePath);
                
                
                //------------------------------ START 短视频上传成功后，接着就是上传首帧预览图了（确保首帧在视频上传前上传完成，不然用户可能先收到消息后，首帧还没传上去）
                // 视频首帧预览图的文件名（服务端保存的名）
                NSString *imgtToServerName = [ReceivedShortVideoHelper constructShortVideoThumbName_toServer:videoFileMd5];
                // 视频首帧预览图的文件名（本地保存的名）
                NSString *imgtLocalSavedName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:videoFileName];
                // 视频首帧预览图的保存目录
                NSString *imgLocalSavedDir = [ReceivedShortVideoHelper getReceivedFileSavedDirHasSlash];
                // 视频首帧预览图保存的完整路径
                 NSString *imgFilePath = [NSString stringWithFormat:@"%@%@", imgLocalSavedDir, imgtLocalSavedName];
                
                DDLogInfo(@"【短视频上传-上传首帧预览图-SendShortVideoHelper】预览图路径：%@", imgFilePath);
                
                // 首帧预览图已在之前准备好了（可以进入上传逻辑）
                if([FileTool fileExists:imgFilePath])
                {
                    DDLogInfo(@"【短视频上传-上传首帧预览图-SendShortVideoHelper】首帧预览图已存在，马上进入上传逻辑....（文件位置：%@）", imgFilePath);

                    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
                    
                    // 额外参数
                    NSMutableDictionary *parameter = [NSMutableDictionary dictionary];
                    parameter[@"user_uid"] = uid;
                    parameter[@"file_name"] = imgtToServerName;
                    // 通过 Authorization header 传递 token（由 FileUploadHelper 中 setupAuthorization 设置）
                    
                    // 原本想用信号量来控制，确保首帧图先传而视频文件后传，但实测中会发生界面卡死的问题，用这个多线程争用风险很大，暂时不用！
                    
//                    // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
//                    // 【原因】：因AFNetworking3.x不支持同步调用，而视频的上传必须保证首帧预览图上传完成后才进行
//                    // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
//                    // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
//                    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0); //【1】创建信号量
                    
                    [FileUploadHelper uploadFileImpl:imgFilePath
                                     withName:imgtToServerName
                                       andUrl:SHORTVIDEO_THUMB_UPLOADER_CONTROLLER_URL_ROOT
                                andParameters:parameter
                                     progress:^(NSProgress * _Nonnull uploadProgress) {
                                         //打印下上传进度
                                         DDLogDebug(@"【短视频上传-上传首帧预览图-SendShortVideoHelper】上传进度> %lf", 1.0 * uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
                                     }
                                      success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                                          //请求成功
                                          DDLogDebug(@"【短视频上传-上传首帧预览图-SendShortVideoHelper】首帧文件上传成功【OK】：%@", responseObject);
                        
//                                            // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
//                                            // 【原因】：因AFNetworking3.x不支持同步调用，而视频的上传必须保证首帧预览图上传完成后才进行
//                                            // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
//                                            // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
//                                            dispatch_semaphore_signal(semaphore);//【3】发送信号（不管请求状态是什么，都得发送信号，否则会一直卡着线程）
                                      }
                                      failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                          //请求失败
                                          DDLogDebug(@"【短视频上传-上传首帧预览图-SendShortVideoHelper】首帧文件上传失败【NO】：%@", error);

//                                            // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
//                                            // 【原因】：因AFNetworking3.x不支持同步调用，而视频的上传必须保证首帧预览图上传完成后才进行
//                                            // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
//                                            // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
//                                            dispatch_semaphore_signal(semaphore);//【3】发送信号（不管请求状态是什么，都得发送信号，否则会一直卡着线程）
                                      }
                    ];
                    
//                    DDLogDebug(@"【短视频上传-上传首帧预览图-SendShortVideoHelper】GCD信号量正在等待预览图上传完成 ....");
                    
//                    // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
//                    // 【原因】：因AFNetworking3.x不支持同步调用，而视频的上传必须保证首帧预览图上传完成后才进行
//                    // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
//                    // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
//                    dispatch_semaphore_wait(semaphore,DISPATCH_TIME_FOREVER);  //【2】等待信号（直到调用 dispatch_semaphore_signal(..)后）
                    
//                    DDLogDebug(@"【短视频上传-上传首帧预览图-SendShortVideoHelper】GCD信号量解除等待，预览图上传已完成。");
                }
                else
                {
                    DDLogWarn(@"【短视频上传-上传首帧预览图-SendShortVideoHelper】首帧预览图文件不存，本次上传没有明治继续【NO】!");
                }
                //------------------------------ END
                
                
                // 新建一个上传任务
                BigFileUploadTask *ub = [[BigFileUploadTask alloc] initWith:videoFileMd5 url:SHORTVIDEO_UPLOADER_CONTROLLER_URL_ROOT fileName:videoFileName filePath:videoFilePath fileMd5:videoFileMd5 chunck:startChunck delegate:utl userPropeties:nil];
                // 加入任务并由开始线程调度和真正的执行
                [um addUploadTask:ub];
            }
            else
            {
                DDLogWarn(@"【短视频文件上传-SendShortVideoHelper】从服务端查询并返回该文件的信息失败了，本次任务没有继续！（filePath=%@, fileName=%@, fileMd5=%@）", videoFilePath, videoFileName, videoFileMd5);
                [utl onError:videoFileName fileMd5:videoFileMd5 fileFullPath:videoFilePath errorCode:-1 chunk:-1 chunks:-1];
                return;
            }
        } hudParentView:nil completeForLocalError:^(NSString *errorLog) {
            DDLogWarn(@"【短视频文件上传-SendShortVideoHelper】本地网络故障（%@），本次任务没有继续！（filePath=%@, fileName=%@, fileMd5=%@）", errorLog, videoFilePath, videoFileName, videoFileMd5);
            [utl onError:videoFileName fileMd5:videoFileMd5 fileFullPath:videoFilePath errorCode:-1 chunk:-1 chunks:-1];
            return;
        }];
    }
    
}

@end
