//telegram @wz662
//
//  ShortVideoUploadTaskListenerForChat.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2019/11/13.
//  Copyright © 2019 JackJiang. All rights reserved.
//

#import "ShortVideoUploadTaskListenerForChat.h"
#import "BigFileUploadManager.h"
#import "ReceivedShortVideoHelper.h"
#import "FileTool.h"
#import "IMClientManager.h"
#import "FileUploadHelper.h"


@interface ShortVideoUploadTaskListenerForChat ()

// 该条短视频消息的数据传输对象（用于聊天界面中，相当于聊天消息的数据模型）
@property (nonatomic, retain) JSQMessage *entityInChatListView;
// 短视频文件任务上传完成观察者：用于该短视频文件所有块上传成功完成后的通知，以及UI及时刷新显示
@property (nonatomic, copy) ObserverCompletion mFileUploadedSucessObserver;

@end


@implementation ShortVideoUploadTaskListenerForChat

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
    DDLogDebug(@"【短视频文件上传-onUploading-[%d/%d]-%%%d】%@,上传进度：%d", (chunk), chunks, percent, fileName, percent);

    // 更新本次文件上传任务所对应的聊天列表中的数据单元对象
    self.entityInChatListView.sendStatusSecondary = SendStatusSecondary_PROCESSING;
    self.entityInChatListView.sendStatusSecondaryProgress = percent;// 1~100的整数（100表示%100）

    // 通知观察者，尝试刷新UI界面上的上传进度显示
    [self notificateStatusChangedObserver:fileName fileMd5:fileMd5 fileFullPath:fileFullPath];
}

- (void)onUploadSuccess:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath chunk:(int)chunk chunks:(int)chunks
{
    DDLogDebug(@"【短视频文件上传-onUploadSuccess】%@, chunk/chunks=%d/%d", fileName, (chunk - 1), chunks);

    // 更新本次文件上传任务所对应的聊天列表中的数据单元对象
    self.entityInChatListView.sendStatusSecondary = SendStatusSecondary_PROCESS_OK;
    self.entityInChatListView.sendStatusSecondaryProgress = 100;// 100表示%100

    // 通知观察者，尝试刷新UI界面上的上传进度显示
    [self notificateStatusChangedObserver:fileName fileMd5:fileMd5 fileFullPath:fileFullPath];
    
    
//    //------------------------------ START 短视频上传成功后，接着就是上传首帧预览图了
//    
//    // 视频首帧预览图的文件名（服务端保存的名）
//    NSString *imgtToServerName = [ReceivedShortVideoHelper constructShortVideoThumbName_toServer:fileMd5];
//    // 视频首帧预览图的文件名（本地保存的名）
//    NSString *imgtLocalSavedName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:fileName];
//    // 视频首帧预览图的保存目录
//    NSString *imgLocalSavedDir = [ReceivedShortVideoHelper getReceivedFileSavedDirHasSlash];
//    // 视频首帧预览图保存的完整路径
//     NSString *imgFilePath = [NSString stringWithFormat:@"%@%@", imgLocalSavedDir, imgtLocalSavedName];
//    
//    // 首帧预览图已在之前准备好了（可以进入上传逻辑）
//    if([FileTool fileExists:imgFilePath])
//    {
//        DDLogInfo(@"【短视频上传-上传首帧预览图-ShortVideoUploadTaskListenerForChat】首帧预览图已存在，马上进入上传逻辑....（文件位置：%@）", imgFilePath);
//
//        NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
//        
//        // 额外参数
//        NSMutableDictionary *parameter = [NSMutableDictionary dictionary];
//        parameter[@"user_uid"] = uid;
//        parameter[@"file_name"] = imgtToServerName;
//        parameter[@"token"] = @"999999999999999_token"; // just for test
//        
//        // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
//        // 【原因】：因AFNetworking3.x不支持同步调用，而大文件上传必须保证按块顺序上传
//        // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
//        // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
//        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0); //【1】创建信号量
//        
//        [FileUploadHelper uploadFileImpl:imgFilePath
//                         withName:imgtToServerName
//                           andUrl:SHORTVIDEO_THUMB_UPLOADER_CONTROLLER_URL_ROOT
//                    andParameters:parameter
//                         progress:^(NSProgress * _Nonnull uploadProgress) {
//                             //打印下上传进度
//                             DDLogDebug(@"【短视频上传-上传首帧预览图-ShortVideoUploadTaskListenerForChat】上传进度> %lf", 1.0 * uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
//                         }
//                          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
//                              //请求成功
//                              DDLogDebug(@"【短视频上传-上传首帧预览图-ShortVideoUploadTaskListenerForChat】首帧文件上传成功【OK】：%@", responseObject);
//            
//                                // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
//                                // 【原因】：因AFNetworking3.x不支持同步调用，而大文件上传必须保证按块顺序上传
//                                // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
//                                // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
//                                dispatch_semaphore_signal(semaphore);//【3】发送信号（不管请求状态是什么，都得发送信号，否则会一直卡着线程）
//                          }
//                          failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
//                              //请求失败
//                              DDLogDebug(@"【短视频上传-上传首帧预览图-ShortVideoUploadTaskListenerForChat】首帧文件上传失败【NO】：%@", error);
//            
//                                // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
//                                // 【原因】：因AFNetworking3.x不支持同步调用，而大文件上传必须保证按块顺序上传
//                                // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
//                                // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
//                                dispatch_semaphore_signal(semaphore);//【3】发送信号（不管请求状态是什么，都得发送信号，否则会一直卡着线程）
//                          }
//        ];
//        
//        DDLogDebug(@"【短视频上传-上传首帧预览图】GCD信号量正在等待预览图上传完成 ....");
//        
//        // 【作用】：使用GCD多线程技术中的信号量，实现AFNetworking3.x的同步请求
//        // 【原因】：因AFNetworking3.x不支持同步调用，而大文件上传必须保证按块顺序上传
//        // 【解决】：使用GCD多线程技术中的信号量可以实现将AFNetworking3.x的异步执行同步化
//        // 【资料】：如对GCD不熟悉，请系统学习之：https://www.jianshu.com/p/2d57c72016c6
//        dispatch_semaphore_wait(semaphore,DISPATCH_TIME_FOREVER);  //【2】等待信号（直到调用 dispatch_semaphore_signal(..)后）
//        
//        DDLogDebug(@"【短视频上传-上传首帧预览图】GCD信号量解除等待，预览图上传已完成。");
//    }
//    else
//    {
//        DDLogWarn(@"【短视频上传-上传首帧预览图-ShortVideoUploadTaskListenerForChat】首帧预览图文件不存，本次上传没有明治继续【NO】!");
//    }
//    
//    //------------------------------ END
    
    
    // 上传任务成功完成后的通知
    self.mFileUploadedSucessObserver(nil, nil);
    
    DDLogDebug(@"TODO 【短视频文件上传成功了，该向对方发送文件消息了！！！！！！】");
}

- (void)onError:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath errorCode:(int)errorCode chunk:(int)chunk chunks:(int)chunks
{
    DDLogDebug(@"【短视频文件上传-onError】errorCode=%d,file=%@, chunk/chunks=%d/%d", errorCode, fileName, (chunk - 1), chunks);

    // 更新本次文件上传任务所对应的聊天列表中的数据单元对象
    self.entityInChatListView.sendStatusSecondary = SendStatusSecondary_PROCESS_FAILD;
    // 并直接像微信一样标识整个消息的发送状态为失败
    self.entityInChatListView.sendStatus = SendStatus_SEND_FAILD;

    // 通知观察者，尝试刷新UI界面上的上传进度显示
    [self notificateStatusChangedObserver:fileName fileMd5:fileMd5 fileFullPath:fileFullPath];
}

- (void)onPause:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileFullPath:(NSString *)fileFullPath chunck:(int)chunck chuncks:(int)chuncks
{
    DDLogDebug(@"【短视频文件上传-onPause】%@, chunk/chunks=%d/%d", fileName, (chunck - 1), chuncks);
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
