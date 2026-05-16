//telegram @wz662
#import "BigFileDownloadTask.h"
#import "FileTool.h"


@interface BigFileDownloadTask ()

@property(nonatomic , strong) NSURLSessionDataTask * downloadTask;
@property(nonatomic , strong) NSURLSession * downloadSession;
@property(nonatomic , strong) NSMutableURLRequest * request;
@property(nonatomic , strong) NSOutputStream * outputStream;

@property (nonatomic, weak) id<BigFileDownloadTaskDelegate> delegate;
@property (nonatomic, retain) NSString *fileURL;
@property (nonatomic, retain) NSString *saveDir;
@property (nonatomic, retain) NSString *fileName;
@property (nonatomic, assign) long long fileSize;

@property (nonatomic, retain) NSString *savedFilePath;
// 当前文件已经保存的总大小：仅用于进度报告
@property (nonatomic, assign) long long cumulationSize;
// 当前下载任务是否已完成（成功或失败都算完成）
@property (nonatomic, assign) BOOL complete;

@end


@implementation BigFileDownloadTask

- (id)initWith:(NSString *)fileURL saveDir:(NSString *)saveDir fileName:(NSString *)fileName fileSize:(long long)fileSize delegate:(id<BigFileDownloadTaskDelegate>)delegate
{
    if (![super init])
        return nil;

    DDLogDebug(@"【大文件下载】传入的参数：fileURL=%@, saveDir=%@, fileName=%@, fileSize=%lld", fileURL, saveDir, fileName, fileSize);

    NSParameterAssert(fileURL != nil);
    NSParameterAssert(saveDir != nil);
    NSParameterAssert(fileName != nil);
    NSParameterAssert(fileSize > 0);

    self.fileURL = fileURL;
    self.saveDir = saveDir;
    self.fileName = fileName;
    self.fileSize = fileSize;
    self.delegate = delegate;

    self.cumulationSize = 0;
    self.complete = NO;

    [self initTask];

    return self;
}

- (void) initTask
{
    self.downloadSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];

    self.request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.fileURL] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:0];

    // 如果要保存的目录不存在，则先尝试创建之
    [FileTool tryCreateDirs:self.saveDir];
    // 文件的保存绝对路径
    self.savedFilePath = [NSString stringWithFormat:@"%@/%@", self.saveDir, self.fileName];
    DDLogDebug(@"【大文件下载】\tDowload saveFilePath=%@", self.savedFilePath);

    // 初始化该文件已经下载的长度（本次将会从此断点开始下载并保存）
    self.cumulationSize = [FileTool fileSizeAtPath:self.savedFilePath];
    DDLogDebug(@"【大文件下载】\t本次下载前，此文件已被下载的长度为：%lld/%lld", self.cumulationSize, self.fileSize);

    // 文件输出流初始化（注意：append=YES）
    self.outputStream = [[NSOutputStream alloc] initToFileAtPath:self.savedFilePath append:YES];

    // 创建task
    self.downloadTask = [self.downloadSession dataTaskWithRequest:self.request];
}

- (void) start
{
    if(self.delegate)
       [self.delegate onDownloadTaskPreExecute];

    // 开始下载
    [self.downloadTask resume];
}


//-----------------------------------------------------------------------------------------
#pragma mark - NSURLSessionDataDelegate

// 服务端首次响应的回调
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    DDLogDebug(@"【大文件下载】\t已收到请求服务端下载文件%@的响应(%@)...", self.fileName, [httpResponse allHeaderFields]);

    [self.outputStream open];
    completionHandler(NSURLSessionResponseAllow);
}

// 下载中的回调
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    // 写数据
    [self.outputStream write:data.bytes maxLength:data.length];
    // 累加已下载字节数
    self.cumulationSize += data.length;

//    DDLogDebug(@"【大文件下载】\t%@正在下载中，累计下载总长度为：%lld/%ld", self.fileName, self.cumulationSize, self.fileSize);

//    dispatch_sync(dispatch_get_main_queue(), ^{
        if(self.delegate)
        {
            // 下载进度：0~1.0f
            float pv = 1.0 * self.cumulationSize / self.fileSize;
//            self.progressView.progress = pv;
            // 通知代理对象刷新下载进度
            [self.delegate onDownloadTaskProgressUpdate:pv];
        }
//    });
}

// 下载结束
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
//    NSLog(@"%s-----%@",__func__, error.description);
    BOOL sucess = (task.state == NSURLSessionTaskStateCompleted && error == nil);

    DDLogDebug(@"【大文件下载】\t[END]下载成功？【%d】, 文件%@本次下载结束，当前文件度为：%lld/%lld (task.state=%ld)", sucess, self.fileName, [FileTool fileSizeAtPath:self.savedFilePath], self.fileSize, (long)task.state);

    if(self.cumulationSize > self.fileSize)
        DDLogWarn(@"【大文件下载】\t%@下载虽已完成，但累计下载总长度为：%lld/%lld，此累计下载长度已超过文件原始总长，服务端文件数据被破坏？？", self.fileName, self.cumulationSize, self.fileSize);

    // 下载成功完成
    if (sucess)
    {
        DDLogDebug(@"【大文件下载】\t本次下载成功完成【OK】！保存位置：%@", self.savedFilePath);

        // 通知代理对象文件下载成功
        if(self.delegate)
            [self.delegate onDownloadTaskExecuteComplete_onSucess:self.savedFilePath];
    }
    // 下载出错
    else
    {
        DDLogWarn(@"【大文件下载】\t本次下载已停止【NO】，停止原因是：%@(地址：%@)", error.description, self.fileURL);

        // 通知代理对象文件下载失败
        if(self.delegate)
            [self.delegate onDownloadTaskExecuteComplete_onException:error];
    }

    self.complete = YES;

    [self.outputStream close];
    self.outputStream = nil;
    self.downloadSession = nil;
    self.downloadTask = nil;
}


//-----------------------------------------------------------------------------------------
#pragma mark - 其它方法

// 取消当前下载任务
- (void) cancel
{
//    if(self.downloadTask != nil)
    if(self.downloadSession != nil)
    {
//        [self.downloadTask cancel];
        [self.downloadSession invalidateAndCancel];
        self.downloadSession = nil;
    }

    if(self.downloadTask != nil)
    {
        [self.downloadTask cancel];
        self.downloadTask = nil;
    }

    if(self.outputStream != nil)
    {
       [self.outputStream close];
        self.outputStream = nil;
    }
}

// 强制性地走下载完成这个流程
- (void) forceComplete
{
    NSString *fileSavedPath = self.savedFilePath;
    if(fileSavedPath != nil && self.delegate != nil)
    {
        [self.delegate onDownloadTaskExecuteComplete_onSucess:fileSavedPath];
    }
}

- (BOOL) isComplete
{
    return self.complete;
}

- (NSString *)getTAG
{
    return NSStringFromClass([self class]);
}



@end
