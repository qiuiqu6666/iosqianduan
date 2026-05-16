//telegram @wz662
//
//  HttpBigFileUploadTask.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2019/9/30.
//  Copyright © 2019 JackJiang. All rights reserved.
//

#import "BigFileUploadTask.h"
#import "FileTool.h"
#import "UserEntity.h"
#import "IMClientManager.h"
#import "FileUploadHelper.h"

/** 较大文件的分块大小：1M */
const int FILE_BLOCK_LENGTH_BIGFILE   = 1024 * 1024;
/** 较小文件的分块大小：250KB */
const int FILE_BLOCK_LENGTH_SMALLFILE = 250 * 1024;


@interface BigFileUploadTask ()

// 注意“strong”修饰，如果是weak的话，传入的delegate很快将被回收而变为nil而使得后绪的run:方法调用中的回调失效
@property (nonatomic, strong) id<BigFileUploadTaskDelegate> delegate;

// task id
@property (nonatomic, retain) NSString *mTid;
// file upload url
@property (nonatomic, retain) NSString *mUrl;
// File name when saving
@property (nonatomic, retain) NSString *mFileName;
// 文件数据绝对路径
@property (nonatomic, retain) NSString *mFilePath;
// 总文件的md5码
@property (nonatomic, retain) NSString *mFileMd5;
// 用户要额外上传的参数
@property (nonatomic, retain) NSDictionary<NSString *, NSString *> *mUserPropeties;

// 上传状态
@property (nonatomic, assign) int mUploadStatus;
// 当前是第几块（注意：基数是从1开始）
@property (nonatomic, assign) int mChunck;
// 文件分块的总块数
@property (nonatomic, assign) int mChuncks;

@end


@implementation BigFileUploadTask

- (id) initWith:(NSString *)tid url:(NSString *)url fileName:(NSString *)fileName filePath:(NSString *)filePath fileMd5:(NSString *)fileMd5 chunck:(int)chunck delegate:(id<BigFileUploadTaskDelegate>)delegate userPropeties:(NSDictionary<NSString *, NSString *> *)userPropeties
{
    if (![super init])
        return nil;
    
    self.mTid = tid;
    self.mUrl = url;
    self.mFileName = fileName;
    self.mFilePath = filePath;
    self.mFileMd5 = fileMd5;
    self.mUserPropeties = userPropeties;
    
    self.mUploadStatus = BFUT_UPLOAD_STATUS_INIT;
    self.mChunck = chunck;
    
    self.delegate = delegate;
    
    return self;
}

- (void) run
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    BOOL isException = NO;
    NSString *exceptionCause = nil;
    
    // 参数合法性检查
    if([BasicTool isStringEmpty: [BasicTool trim:self.mTid]]
            || [BasicTool isStringEmpty: [BasicTool trim:self.mUrl]]
            || [BasicTool isStringEmpty: [BasicTool trim:self.mFileName]]
            || [BasicTool isStringEmpty: [BasicTool trim:self.mFilePath]]
            || [BasicTool isStringEmpty: [BasicTool trim:self.mFileMd5]]
            || self.mChunck < 1)
    {
        NSString *logStr = [NSString stringWithFormat:@"[tid=%@, url=%@, fileName=%@, filePath=%@, fileMd5=%@, chunck=%d]", self.mTid, self.mUrl, self.mFileName, self.mFilePath, self.mFileMd5, self.mChunck];
        
        DDLogDebug(@"【大文件上传-BFUT】各参数值：%@", logStr);
        
        isException = YES;
        exceptionCause = [NSString stringWithFormat:@"无效的参数：%@", logStr];
    }
    
    long long fileLength = 0;
    if([FileTool fileExists:self.mFilePath])
        fileLength = [FileTool fileSizeAtPath:self.mFilePath];
    
    if(fileLength <= 0)
    {
        isException = YES;
        exceptionCause = [NSString stringWithFormat:@"无效的文件大小：fileName=%@, filePath=%@, tid=%@", self.mFileName, self.mFilePath, self.mTid];
    }
    
    // 当文件大小大于2M时，按大文件的分块大小处理，否则按小文件的分块大小处理
    int blockLength = (fileLength > 2 * 1024 * 1024 ? FILE_BLOCK_LENGTH_BIGFILE : FILE_BLOCK_LENGTH_SMALLFILE);

    if (fileLength % blockLength == 0) {
        self.mChuncks = (int) (fileLength / blockLength);
    } else {
        self.mChuncks = (int) (fileLength / blockLength) + 1;
    }
    DDLogInfo(@"【大文件上传-BFUT】本次要上传的文件：%@，文件大小：%lld, 分块数：%d, 默认每块大小：%d", self.mFilePath, fileLength, self.mChuncks, blockLength);
    
    BOOL uploadAllComplete = YES;
    while (self.mChunck <= self.mChuncks
            && self.mUploadStatus != BFUT_UPLOAD_STATUS_PAUSE
            && self.mUploadStatus != BFUT_UPLOAD_STATUS_ERROR)
    {
        self.uploadStatus = BFUT_UPLOAD_STATUS_UPLOADING;
        
        UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
        
        //** 附加上要上传的额外参数
        NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
        
        [params setObject:self.mFileName forKey:@"name"];
        // 以下代码对解决中文文件名到服务端后乱码问题，无卵用
//        [params setObject:[self.mFileName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:@"name"];
        
        [params setObject:[NSString stringWithFormat:@"%d", self.mChuncks] forKey:@"chunks"];
        [params setObject:[NSString stringWithFormat:@"%d", self.mChunck] forKey:@"chunk"];
        [params setObject:[NSString stringWithFormat:@"%lld", fileLength] forKey:@"totalLength"];
        
        if(self.mFileMd5 != nil && [self.mFileMd5 length] > 0)
            [params setObject:self.mFileMd5 forKey:@"totalFileMd5"];
        
        if(localUserInfo != nil) {
            // 默认带上token，用于服务端的安全检查，以便排除掉非法请求
            [params setObject:localUserInfo.token forKey:@"token"];
            [params setObject:localUserInfo.user_uid forKey:@"user_uid"];
        }
        
        // 用户附加的额外参数
        if(self.mUserPropeties != nil) {
            [params addEntriesFromDictionary:self.mUserPropeties];
        }
        
        NSData *mBlock = [FileTool readBlockFromFile:self.mFilePath offset:((self.mChunck - 1) * blockLength) blockSize:blockLength];
        // 没有读取到块数据，结束本次余下块的上传任务
        if(mBlock == nil){
            // 任何一个分块上传失败则直接停止后续分块的继续上传
            uploadAllComplete = NO;
            break;
        }
        
        
        // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
        // 【原因】：因AFNetworking3.x不支持同步调用，而大文件上传必须保证按块顺序上传
        // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
        // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0); //【1】创建信号量
        
        __block BOOL chunkUploadOk = NO;
        __block BOOL rbCompleted = NO;
        [FileUploadHelper uploadDataImpl:mBlock
                               withName:self.mFileName
                                 andUrl:self.mUrl
                          andParameters:params
                               progress:^(NSProgress * _Nonnull uploadProgress) {
                                   //打印下上传进度
                                   DDLogDebug(@"【大文件上传-BFUT】第%d\"块\"上传进度> %lf", safeSelf.mChunck, 1.0 * uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
                               }
                                success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
                                    @synchronized(semaphore) {
                                        if (rbCompleted) return;
                                        rbCompleted = YES;
                                        chunkUploadOk = YES;
                                    }
            
//                                  NSString *result = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            
                                    //请求成功
                                    DDLogDebug(@"【大文件上传-BFUT】第%d\"块\"上传成功完成。(result=%@)", safeSelf.mChunck, responseObject);
            
                                    // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
                                    // 【原因】：因AFNetworking3.x不支持同步调用，而大文件上传必须保证按块顺序上传
                                    // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
                                    // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
                                    dispatch_semaphore_signal(semaphore);//【3】发送信号（不管请求状态是什么，都得发送信号，否则会一直卡着线程）
                                }
                                failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            
                                    @synchronized(semaphore) {
                                        if (rbCompleted) return;
                                        rbCompleted = YES;
                                        chunkUploadOk = NO;
                                    }
            
                                    //请求失败
                                    DDLogDebug(@"【大文件上传-BFUT】第%d\"块\"上传失败：(error=%@", safeSelf.mChunck, error);
                                                            
                                    // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
                                    // 【原因】：因AFNetworking3.x不支持同步调用，而大文件上传必须保证按块顺序上传
                                    // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
                                    // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
                                    dispatch_semaphore_signal(semaphore);//【3】发送信号（不管请求状态是什么，都得发送信号，否则会一直卡着线程）
                                }
        ];
        
        DDLogDebug(@"【大文件上传-BFUT】GCD信号量正在等待第%d\"块\"的上传完成 ....", safeSelf.mChunck);
        
        // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
        // 【原因】：因AFNetworking3.x不支持同步调用，而大文件上传必须保证按块顺序上传
        // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
        // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
        dispatch_time_t rbDeadline = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC));
        long rbWait = dispatch_semaphore_wait(semaphore, rbDeadline);
        if (rbWait != 0) {
            @synchronized(semaphore) {
                if (!rbCompleted) {
                    rbCompleted = YES;
                    chunkUploadOk = NO;
                }
            }
        }
        
        DDLogDebug(@"【大文件上传-BFUT】GCD信号量解除等待，第%d\"块\"上传已成功完成(chunkUploadOk=%d)。", safeSelf.mChunck, chunkUploadOk);
        
        
        if(chunkUploadOk)
        {
            // 此处直接将百分比传过去，而不是在Hadler里实时取百分比，因为handler
            // 处于不同的线程中，等到handler取到时都走到下一步即chunck++完成了，
            // 这样就会导致handler实时取到的进度比实际chunck多1
            [safeSelf onCallBack:[safeSelf getDownLoadPercent]];
            safeSelf.mChunck++;
        }
        else
        {
            safeSelf.uploadStatus = BFUT_UPLOAD_STATUS_ERROR;
//          errorCode = response.code();
            [safeSelf onCallBack:[safeSelf getDownLoadPercent]];
                                                
            // 任何一个分块上传失败则直接停止后续分块的继续上传
            uploadAllComplete = NO;
            break;
        }
    }
    
    if(isException)
    {
        DDLogError(@"【大文件上传-BFUT】大文件上传中出错了，原因：%@", exceptionCause);
        self.uploadStatus = BFUT_UPLOAD_STATUS_ERROR;
        [self onCallBack:[self getDownLoadPercent]];
    }
    else
    {
        if(uploadAllComplete){
            DDLogInfo(@"【大文件上传-BFUT】【！成功完成】文件%@上传完成，chunck=%d, chuncks=%d, uploadStatus=%d", self.mFileName, (self.mChunck-1), self.mChuncks, self.mUploadStatus);
            self.uploadStatus = BFUT_UPLOAD_STATUS_SUCCESS;
            [self onCallBack:[self getDownLoadPercent]];
        } else{
            DDLogError(@"【大文件上传-BFUT】【！失败中断】文件%@上传失败，chunck=%d, chuncks=%d, uploadStatus=%d", self.mFileName, (self.mChunck-1), self.mChuncks, self.mUploadStatus);
            self.uploadStatus = BFUT_UPLOAD_STATUS_ERROR;
            [self onCallBack:[self getDownLoadPercent]];
        }
    }
}

/**
 * 分发回调事件到ui层
 */
- (void) onCallBack:(int) percent
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [safeSelf onCallBackImpl:percent];
        });
    }
    else {
        [self onCallBackImpl:percent];
    }
}

- (void) onCallBackImpl:(int) percent
{
    switch (self.mUploadStatus)
    {
        // 上传失败
        case BFUT_UPLOAD_STATUS_ERROR:
            [self.delegate onError:self.mFileName fileMd5:self.mFileMd5 fileFullPath:self.mFilePath errorCode:-1 chunk:self.mChunck chunks:self.mChuncks];
            break;
        // 正在上传
        case BFUT_UPLOAD_STATUS_UPLOADING:
            [self.delegate onUploading:self.mFileName fileMd5:self.mFileMd5 fileFullPath:self.mFilePath percent:percent chunk:self.mChunck chunks:self.mChuncks];
            break;
        // 暂停上传
        case BFUT_UPLOAD_STATUS_PAUSE:
            [self.delegate onPause:self.mFileName fileMd5:self.mFileMd5 fileFullPath:self.mFilePath chunck:self.mChunck chuncks:self.mChuncks];
            break;
        // 暂停上传
        case BFUT_UPLOAD_STATUS_SUCCESS:
            [self.delegate onUploadSuccess:self.mFileName fileMd5:self.mFileMd5 fileFullPath:self.mFilePath chunk:self.mChunck chunks:self.mChuncks];
            break;
    }
}

/**
 * 获得当前下载百分比。
 *
 * @return 0~100的进度值
 */
- (int) getDownLoadPercent
{
    int baifenbi = 0;// 接受百分比的值
    if (self.mChunck >= self.mChuncks) {
        return 100;
    }
    float baiy = self.mChunck * 1.0f;
    float baiz = self.mChuncks * 1.0f;
    // 防止分母为0出现NoN
    if (baiz > 0) {
        float fen = (baiy / baiz) * 100;
        baifenbi = (int)fen;
    }
    return baifenbi;
}

- (NSString *) getTid
{
    if (![BasicTool isStringEmpty:self.mTid]) {
    } else {
        self.mTid = self.mUrl;
    }
    return self.mTid;
}

- (NSString *) getUrl
{
    return self.mUrl;
}

- (NSString *) getFileName
{
    return self.mFileName;
}

- (void) setUploadStatus:(int)uploadStatus
{
    self.mUploadStatus = uploadStatus;
}

- (int) getUploadStatus
{
    return self.mUploadStatus;
}

@end
