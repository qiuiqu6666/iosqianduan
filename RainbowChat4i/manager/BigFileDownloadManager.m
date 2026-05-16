//telegram @wz662
#import "BigFileDownloadManager.h"
#import "BigFileDownloadTask.h"
#import "ReceivedFileHelper.h"


@interface BigFileDownloadManager ()

@property (nonatomic, retain) NSString *fileName;
/** 文件存储的目录：此目录末尾不需带"/"反斜线 */
@property (nonatomic, retain) NSString *fileDir;
@property (nonatomic, retain) NSString *fileMd5;
@property (nonatomic, assign) long long fileLength;

// 当前任务的下载状态
@property (nonatomic, assign) int fileStatus;
// 当前任务上次下载时的进度值（此值仅用于优化UI界面刷新频率时，详见方法onDownloadTaskProgressUpdate:中的说明）
@property (nonatomic, assign) int oldProgress_100;

/** 下载任务异步执行AsyncTask */
@property (nonatomic, retain) BigFileDownloadTask *downloadTask;

@end


@implementation BigFileDownloadManager

// 本类的单例对象
static BigFileDownloadManager *instance = nil;

+ (BigFileDownloadManager *)sharedInstance
{
    if (instance == nil)
 {
        instance = [[super allocWithZone:NULL] init];
    }
    return instance;
}

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.oldProgress_100 = -1;
    }
    return self;
}


/**
 重置本下载管理器中的参数为初始状态。
 本方法的调用主要用于APP中切换账号时，防止数据污染。
 */
- (void)clear
{
    self.downloadTask = nil;

    self.fileName = nil;
    self.fileDir = nil;
    self.fileMd5 = nil;
    self.fileLength = 0;

    self.fileStatus = -1;
    self.oldProgress_100 = -1;
}

// 开始/继续下载
- (void) startTask:(NSString *)fileMd5 currentLength:(long long)currentLength fileDir:(NSString *)fileDir fileName:(NSString *)fileName fileLength:(long long)fileLength
{
    // 如果任务已经存在则无条件先退出前面的任务（只允许同时进行一个任务的下载）
    // * 注意：此行应放置本方法中的最前面，不然刚设置好this.fileXXXX这些后，
    // * cancelTask就把变量置空，就会导致此次下载无交参数的出现
    [self cancelTask:YES];

    // 本次下载的基本文件信息
    self.fileMd5 = fileMd5;
    self.fileDir = fileDir;
    self.fileName = fileName;
    self.fileLength = fileLength;

    // 下载链接
    NSString *downURL = [ReceivedFileHelper getBigFileDownloadURL:fileMd5 skip:currentLength];

    DDLogDebug(@"[大文件下载管理器]马上开始从%@下载文件数据了。。。。。。。。", downURL);
    [self printDebug];

    // 新建下载任务
    self.downloadTask = [[BigFileDownloadTask alloc] initWith:downURL saveDir:self.fileDir fileName:self.fileName fileSize:self.fileLength delegate:self];

    // 实际上文件已经下载完成，不需要真正的进行网络下载了，直接走任务完成逻辑即可
    if(currentLength == fileLength)
    {
        DDLogInfo(@"[大文件下载管理器] 文件%@已经下载完成了，本次任务不需要真的从网络下载！(_currentLength=%lld, _fileLength=%lld)", fileName, currentLength, fileLength);
        [self.downloadTask forceComplete];
    }
    else
    {
        // 执行下载任务
        [self.downloadTask start];
    }
}

// 取消本次下载任务
- (void) cancelTask:(BOOL) notificationObserver
{
    DDLogDebug(@"[大文件下载管理器] cancelTask()已被调用。。");
    [self printDebug];

    if (self.downloadTask != nil)// && !downloadTask.isComplete() && !downloadTask.isCancelled())
    {
        @try
        {
            [self.downloadTask cancel];

            // 重置
            [self clear];

            DDLogDebug(@"[大文件下载管理器] cancelTask()成功【OK】");
        }
        @catch(NSException *e)
        {
            DDLogDebug(@"[大文件下载管理器] cancelTask()时发生了异常【NO】（%@）", e.description);
        }
    }

    self.fileStatus = BFDM_FILE_STATUS_FILE_NOT_COMPLETE;

    if (notificationObserver && self.delegate != nil)
        [self.delegate onCancel:self.fileMd5];
}

// 暂时本次下载（与取消下载相比，唯一的区别是设置fileStatus状态的不同，进而界面UI上的显示会有不同，仅此而已）
- (void) pauseTask
{
    DDLogDebug(@"[大文件下载管理器] pauseTask()已被调用。。");
    [self printDebug];

    if (self.downloadTask != nil)// && !downloadTask.isComplete() && !downloadTask.isCancelled())
    {
        @try
        {
            // 本类中的暂停其实就是停止下载任务
            [self.downloadTask cancel];
            self.downloadTask = nil;

            DDLogDebug(@"[大文件下载管理器] pauseTask()成功【OK】");
        }
        @catch(NSException *e)
        {
            DDLogDebug(@"[大文件下载管理器] pauseTask()时发生了异常【NO】（%@）", e.description);
        }
    }

    self.fileStatus = BFDM_FILE_STATUS_FILE_DOWNLOAD_PAUSE;

    if(self.delegate != nil)
        [self.delegate onPause:self.fileMd5];
}


//-----------------------------------------------------------------------------------------
#pragma mark - HttpBigFileDownloadTaskDelegate（实现下载任务的代理方法）

- (void) onDownloadTaskPreExecute
{
    DDLogDebug(@"[大文件下载管理器] onPreExecute -------------");
    [self printDebug];

    self.oldProgress_100 = -1;
    self.fileStatus = BFDM_FILE_STATUS_FILE_DOWNLOADING;

    if (self.delegate != nil)
        [self.delegate onPreExecute:self.fileMd5];
}

/**
 下载进度更新。
 @param progress 进度值为0~1.0f的浮点数
 */
- (void) onDownloadTaskProgressUpdate:(float)progress
{
    // 确保只有进度值发生变化时才通知观察者（刷新UI），不然在大文件下载时因每次下载的块较大，
    // 转成100以内的整数进度值时，这个值很久才会变成下一个进度，导致频繁无节致地通知观察者，
    // 从而导致UI刷新太频繁，使得APP用起来变的非常卡！
    if ((int)(progress* 100) != self.oldProgress_100)
    {
        DDLogDebug(@"[大文件下载管理器] onProgressUpdate(%f) -------------", progress);

        // 按照现在的逻辑，基本上0~100的值变化，再大的文件也就是会通知100次左右，app也不会卡了
        if (self != nil)
            [self.delegate onProgressUpdate:self.fileMd5 withProgress:progress];

        // 保存上一个进度值
        self.oldProgress_100 = (int)(progress* 100);
    }
}

- (void) onDownloadTaskExecuteComplete_onException:(NSError *)error
{
    DDLogError(@"[大文件下载管理器] onPostExecute_onException -------------");
    [self printDebug];

    // 异步发生时，就自动调用暂停逻辑
    [self pauseTask];

    if (self.delegate != nil)
        [self.delegate onPostExecute_onException:self.fileMd5 withError:error];
}

- (void) onDownloadTaskExecuteComplete_onSucess:(NSString *)fileSavedPath
{
    DDLogInfo(@"[大文件下载管理器] onPostExecute_onSucess(%@) -------------", fileSavedPath);
    [self printDebug];

    self.fileStatus = BFDM_FILE_STATUS_FILE_COMPLETE;

    if (self.delegate != nil)
        [self.delegate onPostExecute_onSucess:self.fileMd5 withSavedPath:fileSavedPath];
}


//-----------------------------------------------------------------------------------------
#pragma mark - 其它方法

// 是否有正在下载中的任务
- (BOOL) isDownloading
{
    return self.fileStatus == BFDM_FILE_STATUS_FILE_DOWNLOADING;
}

// 是否有暂停中的任务
- (BOOL) isPause
{
    return self.fileStatus == BFDM_FILE_STATUS_FILE_DOWNLOAD_PAUSE;
}

- (int) getFileStatus
{
    return self.fileStatus;
}

// 当前任务中的文件是否是指定文件
- (BOOL) isCurrentFile:(NSString *)fileMd5
{
    if (self.fileMd5 != nil
        && self.fileMd5 != nil
        && [[self.fileMd5 lowercaseString] isEqualToString:[fileMd5 lowercaseString]])
    {
        return YES;
    }

    return NO;
}

- (NSString *) getFileName
{
    return self.fileName;
}

- (void) printDebug
{
    DDLogDebug(@"[大文件下载管理器] [fileStatus=%d, isDownloading?%d]fileName=%@, fileDir=%@, fileMd5=%@, fileLen=%lld", self.fileStatus, [self isDownloading], self.fileName, self.fileDir, self.fileMd5, self.fileLength);
}

@end



