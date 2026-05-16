//telegram @wz662
#import "PhotosOrVoiecesDTO.h"

@implementation PhotosOrVoiecesDTO

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.downloadStatus = [[VoieceDownloadStatus alloc] init];
    }
    return self;
}

@end
