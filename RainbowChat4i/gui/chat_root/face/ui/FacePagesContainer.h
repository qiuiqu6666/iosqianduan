//telegram @wz662

#import <UIKit/UIKit.h>
#import "FaceBoardConfig.h"
#import "FacePageView.h"
#import "IMClientManager.h"

NS_ASSUME_NONNULL_BEGIN

@class FacePagesContainer;
@protocol FacePagesContainerDelegate<NSObject>

// 滚动pageView, 用于外部更新pageControl
- (void)contentView:(FacePagesContainer *)contentView didScrollViewToIndex:(NSInteger)index;

@end

@interface FacePagesContainer : UIView

@property (nonatomic, weak) id<FacePagesContainerDelegate>delegate;

@property (nonatomic, strong) FacePageView *leftPageView;
@property (nonatomic, strong) FacePageView *centerPageView;
@property (nonatomic, strong) FacePageView *rightPageView;

- (instancetype)initWithConfig:(FaceBoardConfig * _Nonnull)config;

// 设置表情
- (void)setFacesWith:(NSArray<FaceMeta *> *)allFaceMetas totalPage:(NSInteger)totalPage;

@end

NS_ASSUME_NONNULL_END
