//telegram @wz662
//
//  GetLocationViewController.m
//  RainbowChat4i
//
//  Created by Jack Jiang.
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import <AMapSearchKit/AMapSearchKit.h>
#import "GetLocationViewController.h"
#import "GroupMemberViewController.h"
#import "BasicTool.h"
#import "LocationUtils.h"
#import "EVAToolKits.h"
#import "POIResultTableViewCell.h"
#import "LocationMeta.h"
#import "IMClientManager.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"


/*
 * 底部数据显示区的UI显示状态常量.
 */
typedef NS_ENUM(NSInteger, POIResultShow){
    POIResultShow_data     = 0,
    POIResultShow_noData   = 1,
    POIResultShow_progress = 2
};


@interface GetLocationViewController ()<MAMapViewDelegate, AMapLocationManagerDelegate, AMapSearchDelegate,UITableViewDelegate,UITableViewDataSource>

// 地图
@property (nonatomic, strong) MAMapView *mapView;

// GPS定位管理器
@property (nonatomic, strong) AMapLocationManager *locationManager;
// 通过定位获取到的“我”当前位置坐标
@property (nonatomic, assign) CLLocationCoordinate2D currentLocationCoordinate;
// 通过定位获取到的“我”当前位置的详细逆地理信息（内含所属城市信息等）
@property (nonatomic, strong) AMapLocationReGeocode *currentLocationRegeocode;
// “我”当前位置坐标是否已通过定位成功获取到
@property (nonatomic, assign) BOOL currentLocationPrepared;

// 当前地图中心的位置坐标
//@property (nonatomic, assign) CLLocationCoordinate2D selectedLocationCoordinate;

// POI搜索
@property (nonatomic ,strong) AMapSearchAPI *poiSearch;
//// POI搜索请求
//@property (nonatomic ,strong) AMapPOIAroundSearchRequest *poiSearchRequest;
// POI搜索结果数据集合
@property (nonatomic ,strong) NSMutableArray *poiSearchResultArray;
// 当前选中的POI结果行索引号
@property (nonatomic, assign) long selectPoiSearchResultPosition;

// 逆地理搜索请求
@property (nonatomic ,strong) AMapReGeocodeSearchRequest *reGeoSearchRequest;

/** 是否搜索地址数据 */
@property (nonatomic, assign) BOOL isSearchData;

@property (nonatomic, retain) UIButton *btnOK;

@end

@implementation GetLocationViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil delegate:(id<LocationChooseCompleteDelegate>)locationChooseCompleteDelegate
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.locationChooseCompleteDelegate = locationChooseCompleteDelegate;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 默认值
    self.isSearchData = YES;
    self.currentLocationPrepared = NO;
    self.poiSearchResultArray = [NSMutableArray arrayWithCapacity:50];
    self.selectPoiSearchResultPosition = -1;

    [self initBaseGUI];
    [self initMap];
    [self initLocalLocationManager];
//    [self initPOISearch];
    [self initReGeoSearch];

    [self.layoutMapContainer bringSubviewToFront:self.containerCenterPin];
    [self.layoutMapContainer bringSubviewToFront:self.btnBackMySelfLocation];
    [self.layoutMapContainer bringSubviewToFront:self.viewTopRoundBgShadow];
}

- (void)initBaseGUI
{
    // 标题文字
    self.title = @"选择位置";
    // 去掉navigationController返回键文字
//    self.navigationController.navigationBar.topItem.title = @"聊天";
    
    // 表格基本设置
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    // 去掉空白行的显示
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    // 表格背景色
    self.tableView.backgroundColor = UI_DEFAULT_BG;
//  // 让表格行分隔线从左边指定像素处绘制
//  [self.tableView setSeparatorInset:UIEdgeInsetsMake(0, 15, 0, 0)];
//  // 表格分隔线的颜色
//  self.tableView.separatorColor = UI_DEFAULT_TABLE_VIEW_DIVIDER_GRAY;
    // 不显示分隔线
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    // ok发送按钮
    self.btnOK = [GroupMemberViewController createCunstomNavigationBuntton];
    [self.btnOK addTarget:self action:@selector(doSend:) forControlEvents:UIControlEventTouchUpInside];
    // 设置ok按钮的初始状态
    [self _setOkButtonEnable:NO];
    [self rb_getLocationSyncPlainChromeNav];
    
    // 点击“回到我的当前位置”事件处理
    [self.btnBackMySelfLocation addTarget:self action:@selector(doBackMyselfLocation:) forControlEvents:UIControlEventTouchUpInside];
    
    [BasicTool setStretchImage:self.viewTopRoundBgShadow capInsets:UIEdgeInsetsMake(18, 18, 0, 18) imgName:@"common_top_rount_white_bg_shadow"];
}

- (void)rb_getLocationSyncPlainChromeNav
{
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @""];
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (!bar || !self.btnOK) {
        return;
    }
    [bar attachRightAccessoryView:self.btnOK];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self rb_plainCustomNavHostViewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
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
    self.mapView.delegate = self;
    self.mapView.showsScale = NO;
//  此处若设置放大级别时，会多触发 regionDidChangeAnimated: 回调2次，这没有好处
//  self.mapView.zoomLevel = DefaultZoomLevel;
    self.mapView.showsCompass = NO;
    // 显示定位蓝点
    self.mapView.showsUserLocation = YES;
//  self.mapView.userTrackingMode = MAUserTrackingModeFollowWithHeading;
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

//// 请参考官方手册：https://lbs.amap.com/api/ios-sdk/guide/map-data/poi
//- (void)initPOISearch
//{
//    self.poiSearch = [[AMapSearchAPI alloc] init];
//    self.poiSearch.delegate = self;
    
//    self.poiSearchRequest = [[AMapPOIAroundSearchRequest alloc] init];
////    self.poiSearchRequest.keywords  = @"商务住宅|餐饮服务|生活服务";
//    /* 按照距离排序. */
//    self.poiSearchRequest.sortrule = 0;
//    self.poiSearchRequest.offset = 50;
//    self.poiSearchRequest.requireExtension = YES;
//}

// 请参考官方手册：https://lbs.amap.com/api/ios-sdk/guide/map-data/geo
// 注意：之前使用POI搜索获取poi列表的方式不合适，原因是POI搜索是查找某个“点”周边的poi信息，而该“点”的
//      信息无法获取，这会导致poi列表里出现的内容（尤其是首个item选中的）其实不是当前“点”内容。所以，使
//      用逆地理搜索则更合适，因为它获取的是当前“点”以及周末的poi数据。
- (void)initReGeoSearch
{
    // 高德官方要求，搜索sdk v8.1.0后，必须进行隐私合规检查，否则无法使用，见官方文档：
    // https://lbs.amap.com/api/ios-sdk/guide/create-project/note#t1
    [AMapSearchAPI updatePrivacyShow:AMapPrivacyShowStatusDidShow privacyInfo:AMapPrivacyInfoStatusDidContain];
    // 默认接受隐私条款
    [AMapSearchAPI updatePrivacyAgree:AMapPrivacyAgreeStatusDidAgree];
    
    self.poiSearch = [[AMapSearchAPI alloc] init];
    self.poiSearch.delegate = self;
    
    self.reGeoSearchRequest = [[AMapReGeocodeSearchRequest alloc] init];
    self.reGeoSearchRequest.requireExtension = YES;
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 其它方法

- (void)doSend:(UIBarButtonItem *)sender
{
    LocationMeta *lm = [self getSelectedItem];
    
    if(lm == nil)
    {
        [BasicTool showAlertInfo:@"无效的位置，请确认！" parent:self];
        return;
    }
    
    DDLogWarn(@"【位置消息-截图】AAAAAA， 本次要发送的位置lm=%@", [EVAToolKits toJSON:lm]);
    
    // 预览图的文件名（本地保存的名）
    NSString *fileName = [LocationUtils generateLocationPreviewFileName];
    lm.prewviewImgFileName = fileName;
        
    if(fileName != nil)
    {
        // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
        __weak typeof(self) safeSelf = self;
        
        __block UIImage *screenshotImage = nil;
        __block NSInteger resState = 0;
        
        // 设置此本地定位蓝点不可见，不然高德地图的截屏功能会把它也截进去，预览图就有点难看了
        self.mapView.showsUserLocation = NO;
        // 开始截图以及余下处理流程
        [self.mapView takeSnapshotInRect:self.mapView.bounds withCompletionBlock:^(UIImage *resultImage, NSInteger state) {
            screenshotImage = resultImage;
            resState = state; // state表示地图此时是否完整，0-不完整，1-完整
            
            DDLogWarn(@"【位置消息-截图-保存】BBBBB, resState=%ld, screenshotImage=%@", resState, screenshotImage);
            
            // 开始位置预览图的截图和保存
            [LocationUtils saveMapScreenShot:screenshotImage status:resState locationTitle:lm.locationTitle fileSavedName:fileName complete:^(BOOL sucess, NSString *imgFilePath){
                
                DDLogWarn(@"【位置消息-截图-保存完成】xxxx, sucess=%d, imgFilePath=%@", sucess, imgFilePath);
                
                // 图片保存成功，马上开始上传到服务器
                if(sucess)
                {
                    if(imgFilePath)
                    {
                        DDLogDebug(@"【位置消息】位置选择已就绪(预览图已备好)，imgFilePath=%@，马上开始真正的发送流程。。。。", imgFilePath);

                        // 通知代理
                        if(self.locationChooseCompleteDelegate != nil)
                        {
                            [self.locationChooseCompleteDelegate processLocationChooseComplete:lm];
                            [self doBack:YES];
                            return;
                        }
                    }
                    else
                        DDLogWarn(@"【位置消息-截图-保存】saveMapScreenShot：方法返回的文件保存路径是空，预览图上传无法继续。");
                }
                // 保存失败
                else
                {
                    DDLogWarn(@"【位置消息-截图-保存】截图保存文件失败，预览图上传无法继续。");
                }
                
                [BasicTool showAlertInfo:@"位置预览图没有成功截取或保存，请重试！" parent:safeSelf];
            }];
        }];
    }
    else
        DDLogWarn(@"【位置消息-截图-onMapScreenShot】生成的fileName为空，位置预览图无法成功保存哦！");

    DDLogWarn(@"【位置消息-截图】CCCCC");
 
}

- (LocationMeta *)getSelectedItem
{
    LocationMeta *lm = nil;
    
    if (nil != self.poiSearchResultArray && 0 < [self.poiSearchResultArray count])
    {
        long position = self.selectPoiSearchResultPosition;
        
        if (position < 0)
            position = 0;
        else if (position >[self.poiSearchResultArray count])
            position = [self.poiSearchResultArray count];
        
        AMapPOI *poiItem = [self.poiSearchResultArray objectAtIndex:position];
        
        if(poiItem == nil)
            return nil;

        lm = [[LocationMeta alloc] init];
        lm.locationTitle = [LocationUtils getPOIItemName:poiItem.name];
        lm.locationContent = [LocationUtils getPOIItemAddr:poiItem.address lng:poiItem.location.longitude lat:poiItem.location.latitude];
        
        CLLocationCoordinate2D locationCoordinate = CLLocationCoordinate2DMake(poiItem.location.latitude, poiItem.location.longitude);
        lm.latitude = locationCoordinate.latitude;
        lm.longitude = locationCoordinate.longitude;
    }

    return lm;
}

//// 开始POI搜索
//- (void)doPOISearch:(CLLocationCoordinate2D)location
//{
//    // 显示加载进度
//    [self showBottomContent:POIResultShow_progress];
//    self.poiSearchRequest.location = [AMapGeoPoint locationWithLatitude:location.latitude longitude:location.longitude];
////    self.currentPage = 1;
////    self.request.page = self.currentPage;
//    [self.poiSearch AMapPOIAroundSearch:self.poiSearchRequest];
//}

// 开始ReGeo逆地理搜索
- (void)doReGeoSearch:(CLLocationCoordinate2D)location
{
    // 显示加载进度
    [self showBottomContent:POIResultShow_progress];
    self.reGeoSearchRequest.location = [AMapGeoPoint locationWithLatitude:location.latitude longitude:location.longitude];
//    self.currentPage = 1;
//    self.request.page = self.currentPage;
    [self.poiSearch AMapReGoecodeSearch:self.reGeoSearchRequest];
}

// 设置当前选中的PIO列表行号
- (void)setSelectPosition:(int)position
{
    self.selectPoiSearchResultPosition = position;
    [self.tableView reloadData];
    [self _setOkButtonEnable:(self.selectPoiSearchResultPosition >=0)];
}

/**
 * 重置确认为初始状态：不可点击、文字内容显示为"确定"、以及按钮的UI样式为半透明效果。
 */
- (void) _resetOkButton
{
    UIColor *c = nil;
    // 针对ios 26的优化：更好地适配液态玻璃效果
    if (@available(iOS 26, *)) {
        c = RGBACOLOR(0, 0, 0, 100);
    } else {
        c = RGBACOLOR(255, 255, 255, 150);
    }
    
    [self.btnOK setTitleColor:c forState:UIControlStateNormal]; // 半透明的白色字体颜色
    [self.btnOK setEnabled:NO]; // 当设置按钮禁用时，系统会自动让其背景变成半透明效果，不需要单独设置禁用状态下的按钮背景图

    [self.btnOK setTitle:@"发送" forState:UIControlStateNormal];
}

/**
 * 决置确认按钮的可用性。
 *
 * @param enabled YES表示可用状态
 */
- (void) _setOkButtonEnable:(BOOL)enabled
{
    if(enabled)
    {
        UIColor *c = nil;
        // 针对ios 26的优化：更好地适配液态玻璃效果
        if (@available(iOS 26, *)) {
            c = [UIColor blackColor];
        } else {
            c = [UIColor whiteColor];
        }
        
        [self.btnOK setTitleColor:c forState:UIControlStateNormal];
        [self.btnOK setEnabled:YES];
    }
    else
        [self _resetOkButton];
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
    self.isSearchData = NO;
    [self toCenter:setZoomLevel locationCoordinate:self.currentLocationCoordinate];
    [self startCenterPinAnimator];
    
    // 开始POI搜索
//    [self doPOISearch:self.currentLocationCoordinate];
    // 开始逆地理搜索
    [self doReGeoSearch:self.currentLocationCoordinate];
}

/**
 “回到我的当前位置”事件处理.
 */
- (void)doBackMyselfLocation:(UIButton*)btn
{
    [self.btnBackMySelfLocation setBackgroundImage:[UIImage imageNamed:GV_BACK_MYSELF_LOCATION_IMG_RED] forState:UIControlStateNormal];

    if (!self.currentLocationPrepared)
        [self doOnceGetCurrentLocation];
    else
        [self doWhenMyselfLocationSucess:NO];
}

// 单次本地定位
- (void)doOnceGetCurrentLocation
{
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    // 检查定位服务是否可用
    if (![CLLocationManager locationServicesEnabled]) {
        DDLogError(@"【位置消息】定位服务未开启");
        [self showNoDataHintContent:@"定位服务未开启，请在设置中开启定位服务"];
        return;
    }
    
    // 检查定位权限状态
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        DDLogError(@"【位置消息】定位权限被拒绝，status: %d", (int)status);
        [self showNoDataHintContent:@"定位权限被拒绝，请在设置中允许应用使用定位服务"];
        return;
    }
    
    // 检查高德地图 apiKey 是否已设置
    NSString *apiKey = [AMapServices sharedServices].apiKey;
    if (!apiKey || apiKey.length == 0) {
        DDLogError(@"【位置消息】高德地图 apiKey 未设置");
        [self showNoDataHintContent:@"高德地图配置错误，请检查 apiKey 设置"];
        return;
    }
    
    DDLogInfo(@"【位置消息】开始获取位置，apiKey: %@, 定位权限状态: %d", apiKey, (int)status);
    
    // 显示进度提示（体升用户体验）
    [self showBottomContent:POIResultShow_progress];
    
    [self.locationManager requestLocationWithReGeocode:YES completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
        
        if (error)
        {
            DDLogError(@"【位置消息】location Error, ErrCode: %ld, errInfo:%@;", (long)error.code, error.localizedDescription);
            
            NSString *resultDesc = @"未知错误";
            
            // 根据错误码提供更友好的错误提示
            if (error.code == AMapLocationErrorTimeOut) {
                // 超时错误：可能是GPS信号弱或网络问题
                resultDesc = @"定位超时，请检查GPS信号或网络连接，稍后重试";
            } else if (error.code == AMapLocationErrorLocateFailed) {
                // 定位失败
                resultDesc = @"定位失败，请确保GPS已开启并允许应用使用定位服务";
            } else if (error.code == AMapLocationErrorReGeocodeFailed) {
                // 逆地理编码失败
                resultDesc = @"获取位置信息失败，请稍后重试";
            } else if (error.code == AMapLocationErrorNotConnectedToInternet) {
                // 网络连接异常
                resultDesc = @"网络连接异常，请检查网络设置";
            } else if (error.code == AMapLocationErrorCannotConnectToHost) {
                // 服务器连接失败
                resultDesc = @"无法连接到定位服务器，请检查网络连接";
            } else if (error.localizedDescription) {
                if([error.localizedDescription containsString:@"USER_DAILY_QUERY_OVER_LIMIT"]) {
                    resultDesc = @"当日免费额度耗尽，扩容请联系管理员购买高德商业授权!";
                } else {
                    resultDesc = error.localizedDescription;
                }
            }
            
            [safeSelf showNoDataHintContent:resultDesc];
            return;
        }
                
        if (location)
        {
            DDLogDebug(@"【位置消息】已正常获取到本地位置信息，location: %@ (经度 %f, 纬度 %f)，逆地理信息：%@", location, location.coordinate.longitude, location.coordinate.latitude, regeocode);
            
            safeSelf.currentLocationCoordinate = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude);
//          safeSelf.currentLocationCity = regeocode.city;
            safeSelf.currentLocationRegeocode = regeocode;
            safeSelf.currentLocationPrepared = YES;
            [safeSelf doWhenMyselfLocationSucess:YES];
        }
        else
        {
            DDLogDebug(@"【位置消息】获取到本地位置信息完成，但location是空的！");
            [safeSelf showNoDataHintContent:[NSString stringWithFormat:@"获取本地位置信息完成，但location是空的！"]];
        }
    }];
}

// 回到地图中心
- (void)toCenter:(BOOL)setZoomLevel locationCoordinate:(CLLocationCoordinate2D)locationCoordinate
{
    if(setZoomLevel)
        [self.mapView setZoomLevel:DefaultZoomLevel animated:NO];// 如动画设为YES时，将会多触发一次 regionDidChangeAnimated: 回调，这没有好处
    [self.mapView setCenterCoordinate:locationCoordinate animated:YES];
}

// 中心的大头针跳动动画
- (void)startCenterPinAnimator
{
    CGRect old = self.viewCenterPin.frame;
    CGFloat delta = 30;
    NSTimeInterval duration = 0.4;

    [UIView animateWithDuration:duration animations:^{
        self.viewCenterPin.frame = CGRectMake(self.viewCenterPin.frame.origin.x, self.viewCenterPin.frame.origin.y - delta, old.size.width, old.size.height);
    } completion:^(BOOL finished) {
        self.viewCenterPin.frame = old;
        }];
    
    [UIView animateWithDuration:duration delay:duration options:0 animations:^{
        self.viewCenterPin.frame = CGRectMake(self.viewCenterPin.frame.origin.x, self.viewCenterPin.frame.origin.y + delta, old.size.width, old.size.height);
    } completion:^(BOOL finished) {
        self.viewCenterPin.frame = old;
    }];
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 底部POI搜索结果显示区的UI相关方法

- (void)showNoDataHintContent:(NSString *)hint
{
    [self setNoDataHintText:hint];
    [self showBottomContent:POIResultShow_noData];
}

- (void)showBottomContent:(POIResultShow)t
{
    switch (t)
    {
        case POIResultShow_data:
        {
            self.tableView.hidden = NO;
            self.progressView4Loading.hidden = YES;
            self.noDataUIContainer.hidden = YES;
            [self stopProgressAnimation];
            break;
        }
        case POIResultShow_noData:
        {
            self.tableView.hidden = YES;
            self.progressView4Loading.hidden = YES;
            self.noDataUIContainer.hidden = NO;
            [self stopProgressAnimation];

            [self.poiSearchResultArray removeAllObjects];
//            self.selectPoiSearchResultPosition = -1;
            [self setSelectPosition:-1];
            break;
        }
        case POIResultShow_progress:
        {
            self.tableView.hidden = YES;
            self.noDataUIContainer.hidden = YES;
            
            if(self.progressView4Loading.hidden == YES)
            {
                self.progressView4Loading.hidden = NO;
                [self startProgressAnimation];
            }

            [self.poiSearchResultArray removeAllObjects];
//            self.selectPoiSearchResultPosition = -1;
            [self setSelectPosition:-1];
            break;
        }
    }
}

- (void)setNoDataHintText:(NSString *)hint
{
    self.noDataHintView.text = hint;
}

// 开始转动菊花
- (void)startProgressAnimation
{
    CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    // 旋转角度
    rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0 ];
    // 旋转一周的时间（单位：秒）
    rotationAnimation.duration = 1.0;
    // 旋转累加角度
    rotationAnimation.cumulative = YES;
    // 旋转次数
    rotationAnimation.repeatCount = ULLONG_MAX;

    [self.progressView4Loading.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
}

// 停止转动菊花
-(void)stopProgressAnimation
{
    [self.progressView4Loading.layer removeAllAnimations];
}


#pragma mark - MAMapViewDelegate

/**
 * @brief 地图区域改变完成后会调用此接口（拖动地图、缩放地图都会触发此回调）
 * @param mapView 地图View
 * @param animated 是否动画
 */
- (void)mapView:(MAMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    DDLogDebug(@"【位置消息-MAMapViewDelegate】regionDidChangeAnimated: 调用了！BB");
    
    CLLocationCoordinate2D centerCoordinate = mapView.region.center;
    
    if(self.isSearchData)
    {
        [self.btnBackMySelfLocation setBackgroundImage:[UIImage imageNamed:GV_BACK_MYSELF_LOCATION_IMG_BLACK] forState:UIControlStateNormal];
        
        // "跳动"大头针
        [self startCenterPinAnimator];
        // 开始POI搜索
//        [self doPOISearch:centerCoordinate];
        // 开始逆地理搜索
        [self doReGeoSearch:centerCoordinate];
    }
    
    if (!self.isSearchData)
        self.isSearchData = YES;
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


#pragma mark - AMapSearchDelegate （@see https://lbs.amap.com/api/ios-sdk/guide/map-data/poi）

/**
 * @brief 当请求发生错误时，会调用代理的此方法.
 * @param request 发生错误的请求.
 * @param error   返回的错误.
 */
- (void)AMapSearchRequest:(id)request didFailWithError:(NSError *)error
{
    NSLog(@"【高德地图】Error: %@ - %@", error, [LocationUtils errorDescriptionWithCode:error.code]);
    NSString *resultDesc = @"未知错误";
    if(error.localizedDescription) {
        if([error.localizedDescription containsString:@"USER_DAILY_QUERY_OVER_LIMIT"]) {
            resultDesc = @"当日免费额度耗尽，扩容请联系管理员购买高德商业授权!";
            [self showNoDataHintContent:resultDesc];
            return;
        }
//      else {
//            resultDesc = error.localizedDescription;
//        }
    }
    
    [self showNoDataHintContent:[LocationUtils errorDescriptionWithCode:error.code]];
}

/**
 * @brief 逆地理编码查询回调函数。 See：https://lbs.amap.com/api/ios-sdk/guide/map-data/geo
 * @param request  发起的请求，具体字段参考 AMapReGeocodeSearchRequest 。
 * @param response 响应结果，具体字段参考 AMapReGeocodeSearchResponse 。
 */
- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response
{
    if (response.regeocode == nil)
    {
        DDLogDebug(@"【位置消息-onReGeocodeSearchDone】返回结果为空。");
        [self showNoDataHintContent:@"没有返回正确的结果"];
        return;
    }
    
    AMapReGeocode *regeocode = response.regeocode;
    
    DDLogDebug(@"【位置消息-onReGeocodeSearchDone】查询完成，regeocode.formattedAddress=%@，POI结果行数：%lu", regeocode.formattedAddress, (unsigned long)regeocode.pois.count);
    
    [self showBottomContent:POIResultShow_data];
    
    // 先清空之前的结果
    [self.poiSearchResultArray removeAllObjects];
    
    // 将被查询的位置作为首行加入到poi列表
    AMapPOI *firstPOI = [LocationUtils changeToPoiItem:response location:request.location];
    if(firstPOI != nil)
        [self.poiSearchResultArray addObject:firstPOI];
    
    // 加入查询到的POI结果
    if(regeocode.pois.count > 0)
        [self.poiSearchResultArray addObjectsFromArray:regeocode.pois];
    
    DDLogDebug(@"【位置消息-onReGeocodeSearchDone】self.poiSearchResultArray合并完成的结果行数为：%lu", (unsigned long)self.poiSearchResultArray.count);
    
    // 刷新表格显示
    [self.tableView reloadData];
    // 默认选中第一条
    [self setSelectPosition:0];
}

///**
// * @brief POI查询回调函数
// * @param request  发起的请求，具体字段参考 AMapPOISearchBaseRequest 及其子类。
// * @param response 响应结果，具体字段参考 AMapPOISearchResponse 。
// */
//- (void)onPOISearchDone:(AMapPOISearchBaseRequest *)request response:(AMapPOISearchResponse *)response
//{
//    if (response.pois.count <= 0)
//    {
//        DDLogDebug(@"【位置消息-onPOISearchDone】返回结果为空。");
//        [self showNoDataHintContent:@"没有返回正确的结果"];
//        return;
//    }
//
//    DDLogDebug(@"【位置消息-onPOISearchDone】查询完成，结果行数：%lu", (unsigned long)response.pois.count);
//
//    [self showBottomContent:POIResultShow_data];
//
//    // 先清空之前的结果
//    [self.poiSearchResultArray removeAllObjects];
//    // 加入结果
//    [self.poiSearchResultArray addObjectsFromArray:response.pois];
//
//    DDLogDebug(@"【位置消息-onPOISearchDone】self.poiSearchResultArray合并完成的结果行数为：%lu", (unsigned long)self.poiSearchResultArray.count);
//
//    // 刷新表格显示
//    [self.tableView reloadData];
//    // 默认选中第一条
////    [self setSelectPoiSearchResultPosition:0];
//    [self setSelectPosition:0];
//}


#pragma mark - UITableViewDataSource

// 表格行数
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.poiSearchResultArray.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

// 表格行高
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 56;
}

// 表格行的UI显示内容
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    long rowNum = indexPath.section;
    AMapPOI *POIModel = nil;
    if(rowNum <= [self.poiSearchResultArray count]-1)
        POIModel = self.poiSearchResultArray[rowNum];

    
    //------------------------------------------------------ 【1】UI初始化
    UITableViewCell *theCell = nil;

    // 表格单元可重用ui
    static NSString *idenfity=@"CellMain";
    POIResultTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:idenfity];
    if(cell==nil) {
        NSArray* arr = [[NSBundle mainBundle] loadNibNamed:@"POIResultTableViewCell" owner:self options:nil];
        for (id obj in arr) {
            if ([obj isKindOfClass:[POIResultTableViewCell class]]) {
                cell = (POIResultTableViewCell *)obj;
            }
        }
    }
    theCell = cell;
    
    // 表格单元选中时的颜色
    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cell.selectedBackgroundView.backgroundColor = UI_DEFAULT_TABLE_VIEW_SELECTED_BG_COLOR;
    // 为了跟表格背景色一致，cell的背景设为透明
    cell.backgroundColor = [UIColor clearColor];
    
    // 设置选择框的可见性
    if (rowNum == self.selectPoiSearchResultPosition)
        cell.viewCheckIcon.hidden = NO;
    else
        cell.viewCheckIcon.hidden = YES;
    
    
    //------------------------------------------------------ 【2】UI值设置
    if(POIModel != nil)
    {
        cell.viewName.text = [LocationUtils getPOIItemName:POIModel.name];
        cell.viewId.text = [LocationUtils getPOIItemAddr:POIModel.address lng:POIModel.location.longitude lat:POIModel.location.latitude];
    }
    
    return theCell;
}


#pragma mark - UITableViewDelegate

// 表格行选择时
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.isSearchData = NO;
    [self.btnBackMySelfLocation setBackgroundImage:[UIImage imageNamed:GV_BACK_MYSELF_LOCATION_IMG_BLACK] forState:UIControlStateNormal];
    self.selectPoiSearchResultPosition = indexPath.section;
    
    [tableView reloadData];
    
    if(self.selectPoiSearchResultPosition > [self.poiSearchResultArray count]-1)
        self.selectPoiSearchResultPosition = [self.poiSearchResultArray count]-1;
    
    if(self.selectPoiSearchResultPosition >= 0)
    {
        AMapPOI *POIModel = self.poiSearchResultArray[self.selectPoiSearchResultPosition];
        CLLocationCoordinate2D locationCoordinate = CLLocationCoordinate2DMake(POIModel.location.latitude, POIModel.location.longitude);
        [self toCenter:NO locationCoordinate:locationCoordinate];
    }
}

@end
