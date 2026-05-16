//telegram @wz662

#import <UIKit/UIKit.h>
#import "FaceMeta.h"
#import "FaceBoardConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface FacePreviewView : UIImageView

- (instancetype)initWithConfig:(FaceBoardConfig * _Nonnull)config;

- (void)setEmojiItemModel:(FaceMeta *)emojiModel;

@end

NS_ASSUME_NONNULL_END
