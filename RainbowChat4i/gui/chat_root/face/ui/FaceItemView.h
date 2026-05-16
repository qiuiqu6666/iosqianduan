//telegram @wz662

#import <UIKit/UIKit.h>
#import "FaceMeta.h"

NS_ASSUME_NONNULL_BEGIN

@interface FaceItemView : UIView

@property (nonatomic, strong) FaceMeta *emoji;

@property (nonatomic, assign) BOOL isShowTitle;

- (void)addTarget:(nullable id)target action:(SEL)action;

@end

NS_ASSUME_NONNULL_END
