//telegram @wz662
#import "VoieceDownloadStatus.h"

@implementation VoieceDownloadStatus

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.status = VoiceDownloadStatus_NONE;
        self.progress = 0;
    }
    return self;
}

@end
