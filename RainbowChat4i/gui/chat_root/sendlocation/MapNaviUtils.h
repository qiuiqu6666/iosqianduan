//telegram @wz662
//
//  MapNaviUtils.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2020/5/28.
//  Copyright © 2020 JackJiang. All rights reserved.
//
/**
 * 打开第3方地图导航的实用类。
 *
 * 本类代码参考了以下帖子：
 * https://www.jianshu.com/p/b10b10c90985
 * https://www.jianshu.com/p/1768de507727
 * https://blog.csdn.net/i996573526/article/details/82117862
 * https://blog.csdn.net/Ever69/article/details/82427085
 *
 */

#import <Foundation/Foundation.h>
#import <MAMapKit/MAMapKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MapNaviUtils : NSObject

// 参考资料：https://www.jianshu.com/p/b10b10c90985
+ (void)openAppleMap:(CLLocationCoordinate2D)srcCoor destCoor:(CLLocationCoordinate2D)destCoor destName:(NSString *)destName;

// 参见官方资料：https://lbs.qq.com/webApi/uriV1/uriGuide/uriOverview
+ (void)openTencentNavi:(double)dlat dlon:(double)dlon dname:(NSString *)dname;

// 参见官方资料：http://lbsyun.baidu.com/index.php?title=uri/api/ios
+ (void)openBaiduNavi:(double)dlat dlon:(double)dlon dname:(NSString *)dname;

// 参见官方资料：https://lbs.amap.com/api/amap-mobile/guide/ios/ios-uri-information
+ (void)openGaoDeNavi:(double)dlat dlon:(double)dlon dname:(NSString *)dname;

@end

NS_ASSUME_NONNULL_END
