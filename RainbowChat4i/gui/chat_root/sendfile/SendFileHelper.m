//telegram @wz662
#import "SendFileHelper.h"
#import "BigFileUploadTaskListenerForChat.h"
#import "BigFileUploadManager.h"
#import "UserEntity.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "BigFileType.h"
#import "FileTool.h"
#import "MBProgressHUD.h"
#import "ReceivedFileHelper.h"

@implementation SendFileHelper

#pragma mark - 公开方法

// 发送前的检查
+ (BOOL) beforeSend_check:(NSString *)filePath vc:(UIViewController *)vc
{
    // 文件是否存的检查
    if(filePath == nil || ![FileTool fileExists:filePath])
    {
        DDLogWarn(@"【大文件上传-beforeSend_check】要发送的文件“%@”不存在，本地发送没有继续！", filePath);
        [BasicTool showAlertWarn:@"文件不存在，发送已被取消！" parent:vc];
        return NO;
    }
    
    // 是否文件夹检查
    BOOL isDir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir];
    if(isDir)
    {
        DDLogWarn(@"【大文件上传-beforeSend_check】要发送的“%@”不是文件，本地发送没有继续！", filePath);
        [BasicTool showAlertWarn:@"不是文件，发送已被取消！" parent:vc];
        return NO;
    }
    
    // 允许发送的最大文件大小的检查
    long long fileSixe = [FileTool fileSizeAtPath:filePath];
    if(fileSixe > SEND_FILE_DATA_MAX_LENGTH || fileSixe <= 0)
    {
        DDLogWarn(@"【大文件上传-beforeSend_check】要发送的文件“%@”大小非法，(MAX=“%d”字节)，本地发送没有继续！", filePath, SEND_FILE_DATA_MAX_LENGTH);
        [BasicTool showAlert:@"文件超限提示" content:[NSString stringWithFormat:@"文件过大，当前允许最大发送 %@ 的文件，本次发送已取消！", [FileTool getConvenientFileSize:fileSixe]] btnTitle:@"知道了" parent:vc];
        return NO;
    }
    
    DDLogInfo(@"【大文件上传-beforeSend_check】大文件：“%@”的前置检查完成，马上进入MD5码计算...", filePath);

    return YES;
}

// 计算文件的md5码（异步线程中执行，提升用户体验）
+ (void) beforeSend_calculateMD5:(NSString *)filePath parent:(UIView *)parent complete:(void (^)(BOOL sucess, NSString *fileMD5))complete
{
    // 显示进度提示菊花
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:parent animated:YES];
    hud.label.text = @"文件准备中，请稍候..";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),^{
        @try
        {
            // 开始计算md5码
            NSString *md5ForFile = [FileTool getFileMD5WithPath:filePath];
            
            // 计算完成后在主线程中进行回h调通知
            dispatch_async(dispatch_get_main_queue(), ^{
                DDLogInfo(@"【大文件上传-beforeSend_calculateMD5】大文件：“%@”的md5码计算完成，结果：“%@”", filePath, md5ForFile);
                
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

// 实现大文件消息中的大文件数据数据上传（支持断点续传逻辑），以及上传完成后的处理等全流程
+ (void) processBigFileUpload:(NSString *)fileName filePath:(NSString *)filePath fileMd5:(NSString *)fileMd5 cme:(JSQMessage *)cme uploadedSucessObserver:(ObserverCompletion)observerForFileUploadOK
{
    // 文件上传状态监听器
    BigFileUploadTaskListenerForChat *utl = [[BigFileUploadTaskListenerForChat alloc] initWith:cme];
    [utl setFileUploadedSucessObserver:observerForFileUploadOK];
    
//    // 通过回调通知ui，及时将大文件上传进度条显示出来（此时肯定是进度为0啦），让用户知道文件已在上传处理中，提升体验
//    [utl onUploading:fileName fileMd5:fileMd5 fileFullPath:filePath percent:0 chunk:-1 chunks:-1];
    
    BigFileUploadManager *um = [BigFileUploadManager sharedInstance];
    // 检查文件是否正在上传中（确保相同md5的任务只有一个在上传中）
    if([um isUploading:fileMd5])
    {
        DDLogWarn(@"【大文件上传-SendFileHelper】要上传大文件：“%@”， 已存在相同的上传任务，本次任务没有继续！", filePath);
        [utl onError:fileName fileMd5:fileMd5 fileFullPath:filePath errorCode:-1 chunk:-1 chunks:-1];
        return;
    }
    
    // 检查参数的合法性
    if (filePath == nil || fileName == nil || fileMd5 == nil)
    {
        DDLogWarn(@"【大文件上传-SendFileHelper】相关参数不能为空，本次上传取消（filePath=%@, fileName=%@, fileMd5=%@）!", filePath, fileName, fileMd5);
        [utl onError:fileName fileMd5:fileMd5 fileFullPath:filePath errorCode:-1 chunk:-1 chunks:-1];
        return;
    }
    
    // TODO: 文件是否存在、文件大小、文件长度等前置检查已经在SendFileProcessor中做过了，本方法中就不需要重复做了
    
    // 本地用户信息
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    if (localUser != nil)
    {
        //** 首先向服务端提交大文件信息查询请求（看看是否需要上传，或者要从第几块开始上传——即断点上传，断点上传原理请见：BigFileUploadTask.h的类说明）
        [[HttpRestHelper sharedInstance] queryBigFileInfoFromServer:fileMd5 userUid:localUser.user_uid fileType:BigFileType_COMMON_BIG_FILE complete:^(BOOL sucess, NSString *retCode, int chunkCount) {
            
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

                DDLogInfo(@"【大文件上传-SendFileHelper】从服务端查询该文件的断点续传信息成功返回，数据结果：retCode=%@, chunkCountInServer=%d（filePath=%@, fileName=%@, fileMd5=%@）", retCode, chunkCountInServer, filePath, fileName, fileMd5);

                // 该md5码对应的文件已经存在于服务器上了（不需要重复上传）
                if ([@"1" isEqualToString:returnCode])
                {
                    DDLogInfo(@"【大文件上传-SendFileHelper】大文件：“%@”已经存在于服务器，本次不需要重复上传文件了！【END】", filePath);
                    [utl onUploadSuccess:fileName fileMd5:fileMd5 fileFullPath:filePath chunk:-1 chunks:-1];
                    
                    // 不需要上传了，直接return
                    return;
                }
                // 表示该文件已经存在查未上传完成（此时chunkCountInServer才有意义）
                else if ([@"2" isEqualToString:returnCode])
                {
                    // 比如“chunkCountInServer”=2时，表示当前服务端已经上传了2块，但因为无法确定最后一块
                    // 是否已被正常上传完成，所以本次的上传应该重传这最后一块，即本次应从“第2块”开始传
                    startChunck = chunkCountInServer;

                    DDLogInfo(@"【大文件上传-SendFileHelper】大文件：“%@”的第%d块已经上传，本次将从第%d块续传。。。", filePath, chunkCountInServer, startChunck);
                }
                // 表示该文件不存在(未被上传过)
                else
                {
                    DDLogDebug(@"【大文件上传-SendFileHelper】大文件：“%@”从未被上传过，本次将从第%d块开始从头上传。。。。。。", filePath, startChunck);
                }
                
                
                //** 检查完成，开始决定文件数据的上传了
                DDLogInfo(@"【大文件上传-SendFileHelper】要上传的大文件路径是：“%@”， 上传马上开始.......", filePath);
                // 新建一个上传任务
                BigFileUploadTask *ub = [[BigFileUploadTask alloc] initWith:fileMd5 url:BIG_FILE_UPLOADER_CONTROLLER_URL_ROOT fileName:fileName filePath:filePath fileMd5:fileMd5 chunck:startChunck delegate:utl userPropeties:nil];
                // 加入任务并由开始线程调度和执行
                [um addUploadTask:ub];
            }
            else
            {
                DDLogWarn(@"【大文件上传-SendFileHelper】从服务端查询并返回该文件的信息失败了，本次任务没有继续！（filePath=%@, fileName=%@, fileMd5=%@）", filePath, fileName, fileMd5);
                [utl onError:fileName fileMd5:fileMd5 fileFullPath:filePath errorCode:-1 chunk:-1 chunks:-1];
                return;
            }
        } hudParentView:nil completeForLocalError:^(NSString *errorLog) {
            DDLogWarn(@"【大文件上传-SendFileHelper】本地网络故障（%@），本次任务没有继续！（filePath=%@, fileName=%@, fileMd5=%@）", errorLog, filePath, fileName, fileMd5);
            [utl onError:fileName fileMd5:fileMd5 fileFullPath:filePath errorCode:-1 chunk:-1 chunks:-1];
            return;
        }];
    }
}


#pragma mark - 私有方法

//+ (BOOL) getDestFilePath:(NSString *)srcPath
//{
//    NSString *fileName = [srcPath lastPathComponent];
//    [NSString stringWithFormat:@"%@/%@", [ReceivedFileHelper getReceivedFileSavedDir], fileName];
//}

// 尝试复制文件。
+ (BOOL) tryCopy:(NSString *)srcPath destPath:(NSString *)destPath
{
    BOOL fileReady = YES;
    
    NSString *destFileName = [destPath lastPathComponent];
    
    //
    if([FileTool fileExists:destPath])
        DDLogInfo(@"【大文件上传-beforeSend_tryCopy】大文件：“%@”已存在，无需从路径：“%@”处复制了。", destFileName, srcPath);
    else
    {
        fileReady = [FileTool copyFile:srcPath destPath:destPath];
        DDLogInfo(@"【大文件上传-beforeSend_tryCopy】大文件：“%@”复制成功了吗？【%d】", destFileName, fileReady);
    }
    
    return fileReady;
}

@end
