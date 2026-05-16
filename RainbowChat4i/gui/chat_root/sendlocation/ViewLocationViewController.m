//telegram @wz662
#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import <AMapSearchKit/AMapSearchKit.h>
#import "ViewLocationViewController.h"
#import "GroupMemberViewController.h"
#import "BasicTool.h"
#import "LocationUtils.h"
#import "EVAToolKits.h"
#import "POIResultTableViewCell.h"
#import "LocationMeta.h"
#import "IMClientManager.h"
#import "GetLocationViewController.h"
#import "LPActionSheet.h"
#import "MapNaviUtils.h"


@interface ViewLocationViewController ()<MAMapViewDelegate, AMapLocationManagerDelegate>

// 要查看的位置信息原始数据
@property (nonatomic, strong) LocationMeta *destLocationMeta;

// 地图
@property (nonatomic, strong) MAMapView *mapView;

// GPS定位管理器
@property (nonatomic, strong) AMapLocationManager *locationManager;
// 通过定位获取到的“我”当前位置坐标
@property (nonatomic, assign) CLLocationCoordinate2D currentLocationCoordinate;
// “我”当前位置坐标是否已通过定位成功获取到
@property (nonatomic, assign) BOOL currentLocationPrepared;

@property (nonatomic, retain) UIButton *btnOK;

@end

@implementation ViewLocationViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil dest:(LocationMeta *)destLocationMeta;
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.destLocationMeta = destLocationMeta;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 默认值
    self.currentLocationPrepared = NO;

    [self initBaseGUI];
    [self initMap];
    [self initLocalLocationManager];
    [self initDatas];

    [self.layoutMapContainer bringSubviewToFront:self.btnBackDestLocation];
    [self.layoutMapContainer bringSubviewToFront:self.viewTopRoundBgShadow];
}

- (void)initBaseGUI
{
    // 标题文字
    self.title = @"位置信息";
    // 去掉navigationController返回键文字
//  self.navigationController.navigationBar.topItem.title = @"聊天";
    
    // 添加导航栏右边的“更多”按钮（无背景图标样式）
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"common_more_ico"]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(gotoNavi)];
    
    // 点击“回到我的当前位置”事件处理
    [self.btnBackDestLocation addTarget:self action:@selector(doBackDestLocation:) forControlEvents:UIControlEventTouchUpInside];
    // 点击“第3方导航中打开”事件处理
    [self.btnGotoNavi addTarget:self action:@selector(doGotoNavi:) forControlEvents:UIControlEventTouchUpInside];
    
    [BasicTool setStretchImage:self.viewTopRoundBgShadow capInsets:UIEdgeInsetsMake(18, 18, 0, 18) imgName:@"common_top_rount_white_bg_shadow"];
    
    // 给按钮设置液态玻璃效果
//    [BasicTool setClearGlassBgnConfig:self.btnGotoNavi];
//    [BasicTool setClearGlassBgnConfig:self.btnBackDestLocation];
}

// 请参考官方手册：https://lbs.amap.com/api/ios-sdk/guide/create-map/show-map
- (void)initMap
{
    // 高德官方要求，地图sdk v8.1.0后，必须进行隐私合规检查，否则无法使用，见官方文档：
    // https://lbs.amap.com/api/ios-sdk/guide/create-project/note#t1
    [MAMapView updatePrivacyShow:AMapPrivacyShowStatusDidShow privacyInfo:AMapPrivacyInfoStatusDidContain];
    // 默认接受隐私条款
    [MAMapView updatePrivacyAgree:AMapPrivacyAgreeStatusDidAgree];
    
    self.mapView = [[MAMapView alloc] initWithFrame:self.layoutMapContainer.bounds];
//  self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    self.mapView.showsScale = NO;
//  此处若设置放大级别时，会多触发 regionDidChangeAnimated: 回调2次，这没有好处
//  self.mapView.zoomLevel = DefaultZoomLevel;
    self.mapView.showsCompass = NO;
    // 显示定位蓝点
//    self.mapView.showsUserLocation = YES;
////  self.mapView.userTrackingMode = MAUserTrackingModeFollowWithHeading;
    [self.layoutMapContainer addSubview:self.mapView];
}

// 请参考官方手册：https://lbs.amap.com/api/ios-location-sdk/guide/get-location/singlelocation
- (void)initLocalLocationManager
{
    // 高德官方要求，定位sdk v2.8.0后，必须进行隐私合规检查，否则无法使用，见官方文档：
    // https://lbs.amap.com/api/ios-location-sdk/guide/create-project/ios-location-privacy
    [AMapLocationManager updatePrivacyShow:AMapPrivacyShowStatusDidShow privacyInfo:AMapPrivacyInfoStatusDidContain];
    // 默认接受隐私条款
    [AMapLocationManager updatePrivacyAgree:AMapPrivacyAgreeStatusDidAgree];
    
    self.locationManager = [[AMapLocationManager alloc] init];
    self.locationManager.delegate =  self;
    // 带逆地理信息的一次定位（定位精度用官方推荐的，参见：https://lbs.amap.com/api/ios-location-sdk/guide/get-location/singlelocation）
    // 使用百米精度，平衡定位速度和精度（在GPS信号弱时也能较快定位）
    [self.locationManager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
    // 设置定位超时时间（已增加到10秒，避免GPS信号弱时定位失败）
    self.locationManager.locationTimeout = DefaultLocationTimeout;
    // 设置逆地理编码超时时间（已增加到5秒）
    self.locationManager.reGeocodeTimeout = DefaultReGeocodeTimeout;
    // 允许后台定位（提高定位成功率）
    self.locationManager.pausesLocationUpdatesAutomatically = NO;
       // 进行单次定位
       [self doOnceGetCurrentLocation];
}

- (void)initDatas
{
    if(self.destLocationMeta != nil)
    {
        NSString *title = [LocationUtils getPOIItemName:self.destLocationMeta.locationTitle];
        NSString *content = [LocationUtils getPOIItemAddr:self.destLocationMeta.locationContent lng:self.destLocationMeta.longitude lat:self.destLocationMeta.latitude];
        
        self.viewDestLocationTitle.text = title;
        self.viewDestLocationContent.text = content;

        // 显示大头针（参见官方文档：https://lbs.amap.com/api/ios-sdk/guide/draw-on-map/draw-marker）
        MAPointAnnotation *pointAnnotation = [[MAPointAnnotation alloc] init];
        pointAnnotation.coordinate = CLLocationCoordinate2DMake(self.destLocationMeta.latitude, self.destLocationMeta.longitude);
        [self.mapView addAnnotation:pointAnnotation];
        
        // 移动地图中心到目标位置
        [self toDest];
    }
}

//-----------------------------------------------------------------------------------------------
#pragma mark - 其它方法

- (void)doGotoNavi:(UIBarButtonItem *)sender
{
    [self gotoNavi];
}

- (void)gotoNavi
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    //### 仿微信的弹出菜单
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"百度地图", @"高德地图", @"腾讯地图", @"Apple 地图"]
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
        
        if(safeSelf.destLocationMeta == nil)
        {
            [BasicTool showAlertInfo:@"无效的位置信息！" parent:safeSelf];
            return;
        }
        
        double lat = safeSelf.destLocationMeta.latitude;
        double lng = safeSelf.destLocationMeta.longitude;
        NSString *name = safeSelf.destLocationMeta.locationTitle;
        
        if(index == 1){
            [MapNaviUtils openBaiduNavi:lat dlon:lng dname:name];
        }
        else if(index == 2){
            [MapNaviUtils openGaoDeNavi:lat dlon:lng dname:name];
        }
        else if(index == 3){
            [MapNaviUtils openTencentNavi:lat dlon:lng dname:name];
        }
        else if(index == 4){
            [MapNaviUtils openAppleMap:safeSelf.currentLocationCoordinate destCoor:CLLocationCoordinate2DMake(lat, lng) destName:name];
        }
    }];
}

// 从当前界面回退
- (void)doBack:(BOOL)animated
{
    [self.navigationController popViewControllerAnimated:animated];
}


//-----------------------------------------------------------------------------------------------
#pragma mark - “我”的当前位置/定位等处理方法

// 当“我”的位置就绪后要做的事
- (void)doWhenMyselfLocationSucess:(BOOL)setZoomLevel
{
//    [self toCenter:setZoomLevel locationCoordinate:self.currentLocationCoordinate];
}

/**
 “回到我的当前位置”事件处理.
 */
- (void)doBackDestLocation:(UIButton*)btn
{
//    [self.btnBackMySelfLocation setBackgroundImage:[UIImage imageNamed:GV_BACK_MYSELF_LOCATION_IMG_RED] forState:UIControlStateNormal];

//    if (!self.currentLocationPrepared)
//        [self doOnceGetCurrentLocation];
//    else
//        [self doWhenMyselfLocationSucess:NO];
    
    [self toDest];
}

// 单次本地定位
- (void)doOnceGetCurrentLocation
{
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    // 检查定位服务是否可用
    if (![CLLocationManager locationServicesEnabled]) {
        DDLogError(@"【位置消息】定位服务未开启");
        return;
    }
    
    // 检查定位权限状态
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        DDLogError(@"【位置消息】定位权限被拒绝，status: %d", (int)status);
        return;
    }
    
    // 检查高德地图 apiKey 是否已设置
    NSString *apiKey = [AMapServices sharedServices].apiKey;
    if (!apiKey || apiKey.length == 0) {
        DDLogError(@"【位置消息】高德地图 apiKey 未设置");
        return;
    }
    
    DDLogInfo(@"【位置消息】开始获取位置，apiKey: %@, 定位权限状态: %d", apiKey, (int)status);
    
    [self.locationManager requestLocationWithReGeocode:YES completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
        
        if (error)
        {
            DDLogError(@"【位置消息】location Error, ErrCode: %ld, errInfo:%@};", (long)error.code, error.localizedDescription);
            return;
        }
                
        if (location)
        {
            DDLogDebug(@"【位置消息】已正常获取到本地位置信息，location: %@ (经度 %f, 纬度 %f)，逆地理信息：%@", location, location.coordinate.longitude, location.coordinate.latitude, regeocode);
            
            safeSelf.currentLocationCoordinate = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude);
            safeSelf.currentLocationPrepared = YES;
            [safeSelf doWhenMyselfLocationSucess:YES];
        }
        else
            DDLogDebug(@"【位置消息】获取到本地位置信息完成，但location是空的！");
    }];
}

// 回到要查看的地图位置
- (void)toDest
{
    [self.mapView setZoomLevel:DefaultZoomLevel animated:YES];
    [self.mapView setCenterCoordinate:CLLocationCoordinate2DMake(self.destLocationMeta.latitude, self.destLocationMeta.longitude) animated:YES];
}


#pragma mark - MAMapViewDelegate

// 显示标注，参见官方手册：https://lbs.amap.com/api/ios-sdk/guide/draw-on-map/draw-marker
- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id <MAAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MAPointAnnotation class]])
    {
        static NSString *pointReuseIndentifier = @"pointReuseIndentifier";
        MAPinAnnotationView*annotationView = (MAPinAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndentifier];
        if (annotationView == nil)
            annotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndentifier];
        
        //设置标注动画显示，默认为NO
        annotationView.animatesDrop = YES;
//      annotationView.pinColor = MAPinAnnotationColorRed;
        annotationView.image = [UIImage imageNamed:@"chatting_location_current_pin_icon"];
        //设置中心点偏移，使得标注底部中间点成为经纬度对应点
        annotationView.centerOffset = CGPointMake(0, -21); // 图的尺寸是：w=23、h=42
        
        return annotationView;
    }
    return nil;
}


#pragma mark - AMapLocationManagerDelegate (@see https://lbs.amap.com/api/ios-location-sdk/guide/get-location/singlelocation)

/**
*  @brief 当plist配置NSLocationAlwaysUsageDescription或者NSLocationAlwaysAndWhenInUseUsageDescription，并且[CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined，会调用代理的此方法。
    此方法实现调用申请后台权限API即可：[locationManager requestAlwaysAuthorization](必须调用,不然无法正常获取定位权限)
*  @param manager 定位 AMapLocationManager 类。
*  @param locationManager  需要申请后台定位权限的locationManager。
*  @since 2.6.2
*/
- (void)amapLocationManager:(AMapLocationManager *)manager doRequireLocationAuth:(CLLocationManager*)locationManager
{
    // 请求定位权限（使用使用时定位权限即可）
    [locationManager requestWhenInUseAuthorization];
}

@end
