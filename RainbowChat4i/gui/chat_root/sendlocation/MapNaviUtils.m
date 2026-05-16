//telegram @wz662
//
//  MapNaviUtils.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2020/5/28.
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import "MapNaviUtils.h"

@implementation MapNaviUtils

// 参考资料：https://www.jianshu.com/p/b10b10c90985
+ (void)openAppleMap:(CLLocationCoordinate2D)srcCoor destCoor:(CLLocationCoordinate2D)destCoor destName:(NSString *)destName
{
    //起点坐标
    MKMapItem *currentLocation = [[MKMapItem alloc] initWithPlacemark:[[MKPlacemark alloc] initWithCoordinate:srcCoor addressDictionary:nil]];
    currentLocation.name = @"当前位置";
    //目的地的位置
    MKMapItem *toLocation = [[MKMapItem alloc] initWithPlacemark:[[MKPlacemark alloc] initWithCoordinate:destCoor addressDictionary:nil]];
    toLocation.name = destName;
    
    NSArray *items = [NSArray arrayWithObjects: toLocation, nil];
    NSDictionary *options = @{
                              MKLaunchOptionsMapTypeKey: [NSNumber numberWithInteger:MKMapTypeStandard],
                              MKLaunchOptionsShowsTrafficKey:@YES,
                              // 默认是驾车模式（不设置此key的话，弹出apple地图后会让用户自已选择导航模式）
                              MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDriving
                              };
    
    // 打开苹果自身地图应用，并呈现特定的item
    [MKMapItem openMapsWithItems:items launchOptions:options];
}

// 参见官方资料：https://lbs.qq.com/webApi/uriV1/uriGuide/uriOverview
+ (void)openTencentNavi:(double)dlat dlon:(double)dlon dname:(NSString *)dname
{
    NSString * urlString = @"";
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"qqmap://"]])
    {
        DDLogDebug(@"【打开第3方导航】正在进入腾讯地图进行导航，腾讯地图已安装【OK】");
        
        // 腾讯地图k唤起需要appkey，见：https://lbs.qq.com/dev/console/key/manage
        urlString = [[NSString stringWithFormat:@"qqmap://map/marker?marker=coord:%f,%f;title:%@;addr:%@&referer=%@", dlat, dlon, dname, dname, @"NCIBZ-SQMWX-JJA43-TIMUI-RUGPT-J6BBT"] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    }
    else
    {
        DDLogDebug(@"【打开第3方导航】正在进入腾讯地图进行导航，腾讯地图未安装【NO】");
        // 腾讯地图k唤起需要appkey，见：https://lbs.qq.com/dev/console/key/manage
        urlString = [[NSString stringWithFormat:@"https://apis.map.qq.com/uri/v1/marker?marker=coord:%f,%f;title:%@;addr:%@&referer=%@", dlat, dlon, dname, dname, @"NCIBZ-SQMWX-JJA43-TIMUI-RUGPT-J6BBT"] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    }
    
    [MapNaviUtils openURL:urlString];
}

// 参见官方资料：http://lbsyun.baidu.com/index.php?title=uri/api/ios
+ (void)openBaiduNavi:(double)dlat dlon:(double)dlon dname:(NSString *)dname
{
    NSString * urlString = @"";
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"baidumap://map"]])
    {
        DDLogDebug(@"【打开第3方导航】正在进入百度地图进行导航，百度地图已安装【OK】");
        
        // 默认打开后，用户可以选择a导航模式
//        urlString = [[NSString stringWithFormat:@"baidumap://map/marker?location=%f,%f&title=%@&content=%@&src=%@", dlat, dlon, dname, dname, @"ios.52im.rainbowchat_pro"] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        
        // 默认打开是“驾车模式”
        urlString = [[NSString stringWithFormat:@"baidumap://map/navi?location=%f,%f&coord_type=gcj02&type=BLK@&src=%@", dlat, dlon, @"ios.52im.rainbowchat_pro"] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    }
    else
    {
        DDLogDebug(@"【打开第3方导航】正在进入百度地图进行导航，百度地图未安装【NO】");
        urlString = [[NSString stringWithFormat:@"http://api.map.baidu.com/marker?location=%f,%f&title=%@&content=%@&output=html", dlat, dlon, dname, dname] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    }
    
    [MapNaviUtils openURL:urlString];
}

// 参见官方资料：https://lbs.amap.com/api/amap-mobile/guide/ios/ios-uri-information
+ (void)openGaoDeNavi:(double)dlat dlon:(double)dlon dname:(NSString *)dname
{
    NSString * urlString = @"";
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"iosamap://"]])
    {
        DDLogDebug(@"【打开第3方导航】正在进入高德地图进行导航，高德地图已安装【OK】");
        urlString = [[NSString stringWithFormat:@"iosamap://viewMap?sourceApplication=%@&poiname=%@&lat=%f&lon=%f&dev=1", APP_NAME , dname, dlat, dlon] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    }
    else
    {
        DDLogDebug(@"【打开第3方导航】正在进入高德地图进行导航，高德地图未安装【NO】");
        urlString = [[NSString stringWithFormat:@"http://uri.amap.com/marker?position=%f,%f&name=%@&coordinate=gaode&src=%@&callnative=0", dlat, dlon, dname, APP_NAME] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    }
    
    [MapNaviUtils openURL:urlString];
}

+ (void)openURL:(NSString *)url
{
    NSURL *myLocationScheme = [NSURL URLWithString:url];
    if ([[UIDevice currentDevice].systemVersion integerValue] >= 10)
    {
        // iOS10以后,使用新API
        [[UIApplication sharedApplication] openURL:myLocationScheme options:@{} completionHandler:^(BOOL success) {
            NSLog(@"[MapNaviUtils-openURL]scheme=%@调用结束，成功了吗？%d", url, success);
        }];
    }
    else
    {
        // iOS10以前,使用旧API
        [[UIApplication sharedApplication] openURL:myLocationScheme];
    }
}


@end
