//telegram @wz662
#import <Foundation/Foundation.h>

#define VoiceDownloadStatus_NONE          0
/** 处理中 */
#define VoiceDownloadStatus_PROCESSING    1
/** 成功处理完成 */
#define VoiceDownloadStatus_PROCESS_OK    2
/** 处理失败 */
#define VoiceDownloadStatus_PROCESS_FAILD 3


@interface VoieceDownloadStatus : NSObject

@property (nonatomic, assign) int status;
@property (nonatomic, assign) float progress;

@end
