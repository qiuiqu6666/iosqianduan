//telegram @wz662
/**
 * 获取地图位置的实现类。
 * 有关高德地图的开发者手册，请见：https://lbs.amap.com/api/ios-sdk/summary
 *
 * 本类的实现参考了一下帖子中的资料：
 *  https://www.jianshu.com/p/c0ba4a06cdb8
 *  https://www.jianshu.com/p/42c79e1d7bb1
 *
 * @since 4.0
 */
#import <UIKit/UIKit.h>
#import "LocationMeta.h"


// 用户选择完成后的代理
@protocol LocationChooseCompleteDelegate <NSObject>
@optional

/**
 * 位置选择结果代理方法：可以在此方法中处理从地图选择的位置进行进一步处理。
 *
 * @param selectedLocation 选中的位置
 */
- (void)processLocationChooseComplete:(LocationMeta *)selectedLocation;

@end


@interface GetLocationViewController : UIViewController

@property (nonatomic, weak) id<LocationChooseCompleteDelegate> locationChooseCompleteDelegate;

@property (weak, nonatomic) IBOutlet UIView *layoutMapContainer;

/** 中心"大头针"组件的父容器 */
@property (weak, nonatomic) IBOutlet UIView *containerCenterPin;
/** 回到"我自已的当前位置"按钮 */
@property (weak, nonatomic) IBOutlet UIButton *btnBackMySelfLocation;
/** 底部的半透明圆角北景 */
@property (weak, nonatomic) IBOutlet UIImageView *viewTopRoundBgShadow;
/** 中心"大头针"图标 */
@property (weak, nonatomic) IBOutlet UIImageView *viewCenterPin;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (weak, nonatomic) IBOutlet UIImageView *progressView4Loading;
@property (weak, nonatomic) IBOutlet UIView *noDataUIContainer;
@property (weak, nonatomic) IBOutlet UITextView *noDataHintView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil delegate:(id<LocationChooseCompleteDelegate>)locationChooseCompleteDelegate;

@end
