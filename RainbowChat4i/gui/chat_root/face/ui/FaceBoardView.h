//telegram @wz662

#import <UIKit/UIKit.h>
#import "FaceBoardConfig.h"
#import "FaceTabbar.h"
#import "FacePagesContainer.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 表情面板主视图
 * Created by Freeman
 * 各视图组件结构关系:
  FaceBoardView
      │
      └───FaceTabbar（底部标签栏，含 emoji/sticker tab切换）
      │
      └───FacePageControl（emoji 模式的页面指示器）
      │
      └───FacePagesContainerView（emoji 模式的表情页面）
      │
      └───StickerCollectionView（sticker 模式的自定义表情网格）
*/

@class FaceBoardView;
@protocol FaceBoardViewDelegate<NSObject>

// 点击emoji表情
- (void)faceBoardView:(FaceBoardView *)faceBoardView clickedEmojiWith:(FaceMeta *)emoji;

// 点击删除
- (void)faceBoardView:(FaceBoardView *)faceBoardView clickedDeleteWith:(UIButton *)button;

// 点击发送
- (void)faceBoardView:(FaceBoardView *)faceBoardView clickedSendWith:(UIButton *)button;

@optional
// 点击自定义表情（发送表情消息）
- (void)faceBoardView:(FaceBoardView *)faceBoardView clickedStickerWith:(NSDictionary *)stickerInfo;

// 点击表情管理按钮
- (void)faceBoardViewDidClickManage:(FaceBoardView *)faceBoardView;

@end

@interface FaceBoardView : UIView

@property (nonatomic, strong) FacePagesContainer *contentView;

@property (nonatomic, strong) UIPageControl *pageControl;

@property (nonatomic, strong) FaceTabbar *tabbar;

@property (nonatomic, strong) UICollectionView *stickerCollectionView;

@property (nonatomic, weak, nullable) id<FaceBoardViewDelegate>delegate;

- (instancetype)initWithFrame:(CGRect)frame;

- (instancetype)initWithFrame:(CGRect)frame config:(FaceBoardConfig * _Nonnull)config;

- (instancetype)initWithDlegate:(_Nonnull id <FaceBoardViewDelegate>)delegate;

- (instancetype)initWithFrame:(CGRect)frame config:(FaceBoardConfig * _Nonnull)config delegate:(nullable id <FaceBoardViewDelegate>)delegate;

/// 刷新自定义表情列表
- (void)reloadStickerData;

@end

NS_ASSUME_NONNULL_END
