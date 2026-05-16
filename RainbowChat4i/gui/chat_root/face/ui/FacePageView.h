//telegram @wz662

#import <UIKit/UIKit.h>
#import "FaceBoardConfig.h"
#import "EmojiUtil.h"
#import "FaceItemView.h"

NS_ASSUME_NONNULL_BEGIN

@class FacePageView;
@protocol FacePageViewDelegate<NSObject>

// 点击表情
- (void)pageView:(FacePageView *)pageView clickedEmojiWith:(FaceMeta *)emoji;

// 点击删除
- (void)pageView:(FacePageView *)pageView clickedDeleteWith:(UIButton *)button;

@end

@interface FacePageView : UIView

- (instancetype)initWithConfig:(FaceBoardConfig * _Nonnull)config;

- (void)configFaceItemsWith:(NSArray<FaceMeta *> *)facesData pageIndex:(NSInteger)pageIndex;

@property (nonatomic, weak) id<FacePageViewDelegate>delegate;

@end

NS_ASSUME_NONNULL_END
