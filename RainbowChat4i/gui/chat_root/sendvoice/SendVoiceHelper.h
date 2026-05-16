//telegram @wz662
#import <Foundation/Foundation.h>

@interface SendVoiceHelper : NSObject

+ (NSString *)getSendVoiceSavedDir;

+ (NSString *)getSendVoiceSavedDirHasSlash;

+ (NSString *)getVoiceDownloadURL:(NSString *)file_name dump:(BOOL)needDump;

/**
 * 语音留言上传开始：本地用户（语音留言消息发送方）的语音留言消息中语音数据的上传实现方法.
 * <p>
 * 本方法中用关语音留言上传处理的任何结果都将试图通知参数{@link result}, 因而如果
 * 需要针对语音留言数据上传结果进行客外处理的请<b>一定要实现{@link SendStatusSecondaryResult}类并作
 * 为参数传过来</b>.
 *
 * @param voiceFileName 服务端收到文件数据后要保存的文件名，<b>此参数为必须！</b>
 * @param usedForUploadProfilePhoto YES表示用于用户个人语音介绍上传时，否则用于语音留言聊天消息的语音文件上传
 */
+ (void)processVoiceUpload:(NSString *)voiceFileName usedFor:(BOOL)usedForUploadProfilePVoice processing:(void (^)())processing processFaild:(void (^)())processFaild processOk:(void (^)())processOk;

@end
