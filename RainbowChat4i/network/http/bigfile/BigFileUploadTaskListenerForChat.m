//telegram @wz662
#import "BigFileUploadTaskListenerForChat.h"
#import "BigFileUploadManager.h"


@interface BigFileUploadTaskListenerForChat ()

// 该条大文件消息的数据传输对象（用于聊天界面中，相当于聊天消息的数据模型）
@property (nonatomic, retain) JSQMessage *entityInChatListView;
// 文件任务上传完成观察者：用于该大文件所有块上传成功完成后的通知，以及UI及时刷新显示
@property (nonatomic, copy) ObserverCompletion mFileUploadedSucessObserver;

@end


@implementation BigFileUploadTaskListenerForChat

- (id)initWith:(JSQMessage *)entityInChatListView
{
    if(self = [super init])
    {
        // 属性初始化
        self.entityInChatListView = entityInChatListView;
    }
    return self;
}


//---------------------------------------------------------------------------------------------------
#pragma mark - BigFileUploadTaskDelegate实现代码

- (void)onUploading:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath percent:(int)percent chunk:(int)chunk chunks:(int)chunks
{
    DDLogDebug(@"【大文件上传-onUploading-[%d/%d]-%%%d】%@,上传进度：%d", (chunk), chunks, percent, fileName, percent);

    // 更新本次文件上传任务所对应的聊天列表中的数据单元对象
    self.entityInChatListView.sendStatusSecondary = SendStatusSecondary_PROCESSING;
    self.entityInChatListView.sendStatusSecondaryProgress = percent;// 1~100的整数（100表示%100）

    // 通知观察者，尝试刷新UI界面上的上传进度显示
    [self notificateStatusChangedObserver:fileName fileMd5:fileMd5 fileFullPath:fileFullPath];
}

- (void)onUploadSuccess:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath chunk:(int)chunk chunks:(int)chunks
{
    DDLogDebug(@"【大文件上传-onUploadSuccess】%@, chunk/chunks=%d/%d", fileName, (chunk - 1), chunks);

    // 更新本次文件上传任务所对应的聊天列表中的数据单元对象
    self.entityInChatListView.sendStatusSecondary = SendStatusSecondary_PROCESS_OK;
    self.entityInChatListView.sendStatusSecondaryProgress = 100;// 100表示%100

    // 通知观察者，尝试刷新UI界面上的上传进度显示
    [self notificateStatusChangedObserver:fileName fileMd5:fileMd5 fileFullPath:fileFullPath];
    
    // 上传任务成功完成后的通知
    self.mFileUploadedSucessObserver(nil, nil);
    
    DDLogDebug(@"TODO 【大文件上传成功了，该向对方发送文件消息了！！！！！！】");
}

- (void)onError:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath errorCode:(int)errorCode chunk:(int)chunk chunks:(int)chunks
{
    DDLogDebug(@"【大文件上传-onError】errorCode=%d,file=%@, chunk/chunks=%d/%d", errorCode, fileName, (chunk - 1), chunks);

    // 更新本次文件上传任务所对应的聊天列表中的数据单元对象
    self.entityInChatListView.sendStatusSecondary = SendStatusSecondary_PROCESS_FAILD;
    // 并直接像微信一样标识整个消息的发送状态为失败
    self.entityInChatListView.sendStatus = SendStatus_SEND_FAILD;

    // 通知观察者，尝试刷新UI界面上的上传进度显示
    [self notificateStatusChangedObserver:fileName fileMd5:fileMd5 fileFullPath:fileFullPath];
}

- (void)onPause:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath chunck:(int)chunck chuncks:(int)chuncks
{
    DDLogDebug(@"【大文件上传-onPause】%@, chunk/chunks=%d/%d", fileName, (chunck - 1), chuncks);
}

- (void) notificateStatusChangedObserver:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath
{
    // 通知观察者，尝试刷新UI界面上的上传进度显示
    ObserverCompletion fileStatusChangedObserver = [[BigFileUploadManager sharedInstance] getFileStatusChangedObserver];
    if(fileStatusChangedObserver != nil)
        fileStatusChangedObserver(nil, @[fileName, fileMd5, fileFullPath]);
}

- (void) setFileUploadedSucessObserver:(ObserverCompletion)fileUploadedSucessObserver
{
    self.mFileUploadedSucessObserver = fileUploadedSucessObserver;
}
- (ObserverCompletion) getFileUploadedSucessObserver
{
    return self.mFileUploadedSucessObserver;
}

@end
