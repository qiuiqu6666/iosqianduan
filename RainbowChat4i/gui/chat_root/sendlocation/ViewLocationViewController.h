//telegram @wz662
/**
 * 查看地理位置。支持打开第3方地图导航功能。
 *
 * @author JackJiang
 * @since 4.0
 */
#import <UIKit/UIKit.h>
#import "LocationMeta.h"


@interface ViewLocationViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIView *layoutMapContainer;

/** 回到"我自已的当前位置"按钮 */
@property (weak, nonatomic) IBOutlet UIButton *btnBackDestLocation;
/** 底部的半透明圆角u背景 */
@property (weak, nonatomic) IBOutlet UIImageView *viewTopRoundBgShadow;

@property (weak, nonatomic) IBOutlet UILabel *viewDestLocationTitle;
@property (weak, nonatomic) IBOutlet UILabel *viewDestLocationContent;
@property (weak, nonatomic) IBOutlet UIButton *btnGotoNavi;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil dest:(LocationMeta *)destLocationMeta;

@end
