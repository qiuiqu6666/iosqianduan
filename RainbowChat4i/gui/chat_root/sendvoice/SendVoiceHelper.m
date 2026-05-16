//telegram @wz662
#import "SendVoiceHelper.h"
#import "AppDelegate.h"
#import "FileUploadHelper.h"
#import "UploadPVoiceHelper.h"
#import "FileTool.h"

@implementation SendVoiceHelper

+ (NSString *)getSendVoiceSavedDirHasSlash
{
    NSString *dir = [SendVoiceHelper getSendVoiceSavedDir];
    return dir ==  nil? nil : [NSString stringWithFormat:@"%@/", dir];
}

+ (NSString *)getSendVoiceSavedDir
{
    NSString *dir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_SENDVOICE_RELATIVE_DIR];
//    NSString *dir = [BasicTool getCachedPath]; // FIXME: 稍后需实现语音留言放置在../voice/这样的子目录中
    return dir;
}

+ (NSString *)getVoiceDownloadURL:(NSString *)file_name dump:(BOOL)needDump
{
//    NSLog(@"[ClientCoreSDK sharedInstance].currentLoginExtra=%@", [ClientCoreSDK sharedInstance].currentLoginExtra);

    NSString *fileURL = nil;
    if( [ClientCoreSDK sharedInstance].currentLoginUserId != nil)
    {
        fileURL = [NSString stringWithFormat:@"%@?action=voice_d&user_uid=%@&file_name=%@&need_dump=%@", BBONERAY_DOWNLOAD_CONTROLLER_URL_ROOT, [ClientCoreSDK sharedInstance].currentLoginUserId, file_name, (needDump?@"1":@"0")];
    }

    NSLog(@"[SendVoiceHelper] 拼接完成的语音留言下载地址是：%@", fileURL);

    return fileURL;
}

+ (void)processVoiceUpload:(NSString *)voiceFileName usedFor:(BOOL)usedForUploadProfilePVoice processing:(void (^)())processing processFaild:(void (^)())processFaild processOk:(void (^)())processOk
{
    // 将处理结果通知观察者
    if(processing != nil)
        processing();

    if(voiceFileName == nil)
    {
        DDLogWarn(@"【SendVoice%@】要上传的语音文件名居然是null!", usedForUploadProfilePVoice?@"-个人语音介绍":@"");
        // 将处理结果通知观察者
        if(processFaild != nil)
            processFaild();
        return;
    }

    @try
    {
        NSString *fp = usedForUploadProfilePVoice?[NSString stringWithFormat:@"%@%@", [UploadPVoiceHelper getSendVoiceSavedDirHasSlash], voiceFileName]:[NSString stringWithFormat:@"%@%@", [SendVoiceHelper getSendVoiceSavedDirHasSlash], voiceFileName];
        DDLogDebug(@"【SendVoice%@】要上传的语音留言文件全路径为：%@", usedForUploadProfilePVoice?@"-个人语音介绍":@"", fp);

        long long fileSize = [FileTool fileSizeAtPath:fp];

        if(fileSize <= 0)
        {
            DDLogWarn(@"【SendVoice%@】要发送的语音大小为0，本次语音留言上传没有继续！", usedForUploadProfilePVoice?@"-个人语音介绍":@"");
            [APP showToastWarn:usedForUploadProfilePVoice?@"上传的语音文件大小为0，上传失败！":@"发送的语音文件大小为0，发送失败！"];

            // 将处理结果通知观察者
            if(processFaild != nil)
                processFaild();

            return;
        }
        else if(fileSize > (usedForUploadProfilePVoice?LOCAL_PVOICE_FILE_DATA_MAX_LENGTH:LOCAL_VOICE_FILE_DATA_MAX_LENGTH))
        {
            DDLogWarn(@"【SendVoice%@】语音大小大于%d字节，上传（到服务端）没有继续！", usedForUploadProfilePVoice?@"-个人语音介绍":@"", LOCAL_VOICE_FILE_DATA_MAX_LENGTH);
            [APP showToastWarn:usedForUploadProfilePVoice?@"上传的图片过大，上传失败！":@"发送的图片过大，发送失败！"];

            // 将处理结果通知观察者
            if(processFaild != nil)
                processFaild();

            return;
        }
        else
        {
            NSString *localUid = [ClientCoreSDK sharedInstance].currentLoginUserId;
            // 正式开始文件上传
            [SendVoiceHelper uploadMsgVoiceFile:voiceFileName localUid:localUid usedFor:usedForUploadProfilePVoice completeFail:^(NSError *error) {
                // 将处理结果通知观察者
                if(processFaild != nil)
                    processFaild();
            } completeSucess:^(id responseObject) {
                // 将处理结果通知观察者
                if(processOk != nil)
                    processOk();
            }];
        }
    }
    @catch (NSException * e)
    {
        DDLogError(@"【SendVoice%@】Exception: %@", usedForUploadProfilePVoice?@"-个人语音介绍":@"", e);
        return;
    }
}

/**
 * 通过HTTP上传语音留言消息的语音文件的实现方法.
 *
 * @param fileName 服务端收到文件数据后要保存的文件名
 * @param localUserUid 上传者的uid（上传者也即是图片消息的发起人）
 * @param usedForUploadProfilePVoice YES表示用于用户个人语音留言介绍上传时，否则用于语音留言聊天消息的语音文件上传
 */
+ (void)uploadMsgVoiceFile:(NSString *)fileName localUid:(NSString *)localUserUid usedFor:(BOOL)usedForUploadProfilePVoice completeFail:(void (^)(NSError *error))failure completeSucess:(void (^)(id responseObject))success
{
    NSString *uid = localUserUid;

    // 原始文件路径
    NSString *fileFullPath = usedForUploadProfilePVoice?[NSString stringWithFormat:@"%@%@", [UploadPVoiceHelper getSendVoiceSavedDirHasSlash], fileName]:[NSString stringWithFormat:@"%@%@", [SendVoiceHelper getSendVoiceSavedDirHasSlash], fileName];
    DDLogDebug(@"【SendVoice%@】>>>>>>>>>>>>>> fileFullPath=%@", usedForUploadProfilePVoice?@"-个人语音介绍":@"",fileFullPath);

    // ** 注意：经反复测试，此url一定不能带参数，不然总是在上传时卡住（原因不清楚，可能是AF的bug！）
    NSString *urlString = usedForUploadProfilePVoice?MY_VOICE_UPLOAD_CONTROLLER_URL_ROOT:MSG_VOICE_UPLODER_URL_ROOT;

    // 额外参数
    // NSDictionary *dict = @{@"user_uid":@"1234"};
    NSMutableDictionary *parameter = [NSMutableDictionary dictionary];
    parameter[@"user_uid"] = uid;
    parameter[@"file_name"] = fileName;
    // 通过 Authorization header 传递 token（由 FileUploadHelper 中 setupAuthorization 设置）

    [FileUploadHelper uploadFileImpl:fileFullPath
                            withName:fileName
                              andUrl:urlString
                       andParameters:parameter
                            progress:^(NSProgress * _Nonnull uploadProgress) {
                                //打印下上传进度
                                DDLogDebug(@"【SendVoice%@】上传进度> %lf", usedForUploadProfilePVoice?@"-个人语音介绍":@"", 1.0 * uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
                            }
                             success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                                 //请求成功
                                 DDLogDebug(@"【SendVoice%@】请求成功：%@", usedForUploadProfilePVoice?@"-个人语音介绍":@"", responseObject);

                                 if(success)
                                     success(responseObject);
                             }
                             failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                 //请求失败
                                 DDLogDebug(@"【SendVoice%@】请求失败：%@", usedForUploadProfilePVoice?@"-个人语音介绍":@"", error);
                                 
                                 if(failure)
                                     failure(error);
                             }
     ];
}


@end
