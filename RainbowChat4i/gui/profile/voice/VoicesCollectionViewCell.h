//telegram @wz662
#import <UIKit/UIKit.h>

@interface VoicesCollectionViewCell : UICollectionViewCell

// 音频时长
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
// 音频播放动画效果的图片组件
@property (weak, nonatomic) IBOutlet UIImageView *playImage;

// 基本信息子组件view
@property (weak, nonatomic) IBOutlet UIView *sublayoutInfo;
// 查看数
@property (weak, nonatomic) IBOutlet UILabel *viewCount;
// 音频文件大小
@property (weak, nonatomic) IBOutlet UILabel *viewSize;

// 下载进度条（如果需要下载时才会显示）
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

// 删除按钮
@property (weak, nonatomic) IBOutlet UIButton *btnDel;
///** 删除按钮的父组件的宽度约束（当不需要显地此组件时，本值设为0即可） */
//@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cellDeleteLayoutWidthConstraint;

+ (UINib *)nib;
+ (NSString *)cellReuseIdentifier;

@end
