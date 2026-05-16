//telegram @wz662
#import "BigFileUploadManager.h"


@interface BigFileUploadManager ()

// 大文件上传任务的并发队列(如果对GCD多线程不熟悉，请见资料：https://www.jianshu.com/p/2d57c72016c6)
@property (nonatomic, strong) dispatch_queue_t taskQueue;
// 任务列表
@property (nonatomic, strong) NSMutableDictionary<NSString *, BigFileUploadTask *> *taskList;

// 文件任务状态改变观察者：用于UI及时刷新文件上传状态在界面上的显示（每种需要支持大文件消息的聊天界面，都应该设置或取消设置本观察者）
@property (nonatomic, copy) ObserverCompletion mFileStatusChangedObserver;

@end


@implementation BigFileUploadManager

+ (instancetype)sharedInstance
{
    static BigFileUploadManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BigFileUploadManager alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.taskQueue = dispatch_queue_create("rainbowchat.bigfile.upload.q", DISPATCH_QUEUE_CONCURRENT);
        self.taskList = [NSMutableDictionary dictionary];
    }
    return self;
}

// 添加上传任务
- (void) addUploadTask:(BigFileUploadTask *)uploadTask
{
    if (uploadTask != nil && ![self isUploadingTask:uploadTask])
    {
        [uploadTask setUploadStatus:BFUT_UPLOAD_STATUS_INIT];
        
        // 保存上传task列表
        [self.taskList setObject:uploadTask forKey:[uploadTask getTid]];
        // 异步线程中后台执行
        dispatch_async(self.taskQueue, ^{
            [uploadTask run];
        });
    }
}

- (BOOL) isUploadingTask:(BigFileUploadTask *)task
{
    if (task != nil)
    {
        if ([task getUploadStatus] == BFUT_UPLOAD_STATUS_UPLOADING)
            return YES;
    }
    return NO;
}

- (BOOL) isUploading:(NSString *)tid
{
    return [self isUploadingTask:[self getUploadTask:tid]];
}

// 获得指定的task
- (BigFileUploadTask *) getUploadTask:(NSString *)tid
{
    BigFileUploadTask *currTask = [self.taskList objectForKey:tid];
    if (currTask == nil)
    {
//        currTask = parseEntity2Task(new BigFileUploadTask.Builder().build());
//        // 放入task list中
//        mCurrentTaskList.put(id, currTask);
    }

    return currTask;
}

// 暂停上传任务
- (void) pause:(NSString *)tid
{
    BigFileUploadTask *task = [self getUploadTask:tid];
    if (task != nil)
    {
        [task setUploadStatus:BFUT_UPLOAD_STATUS_PAUSE];
    }
}

// 重新开始已经暂停的上传任务
- (void) resume:(NSString *)tid
{
    BigFileUploadTask *task = [self getUploadTask:tid];
    if (task != nil)
    {
        [self addUploadTask:task];
    }
}

- (void) setFileStatusChangedObserver:(ObserverCompletion)fileStatusChangedObserver
{
    self.mFileStatusChangedObserver = fileStatusChangedObserver;
}
- (ObserverCompletion) getFileStatusChangedObserver
{
    return self.mFileStatusChangedObserver;
}

@end
