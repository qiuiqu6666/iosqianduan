//telegram @wz662
//
//  MAHeatMapVectorGridOverlay.h
//  MAMapKit
//
//  Created by ldj on 2019/7/25.
//  Copyright © 2019 Amap. All rights reserved.
//  热力图网格覆盖物（通过顶点直接绘制）

#import "MAConfig.h"
#if MA_INCLUDE_OVERLAY_HEATMAP

#import "MAShape.h"
#import "MAOverlay.h"
#import "MAHeatMapVectorOverlay.h"

///单个点对象
@interface MAHeatMapVectorGridNode : NSObject
///经纬度
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@end

///单个网格
@interface MAHeatMapVectorGrid : NSObject
/// 网格顶点
@property (nonatomic, copy) NSArray<MAHeatMapVectorGridNode *> *inputNodes;

/// 网格颜色
@property (nonatomic, strong) UIColor *color;
@end

/// 该类用于定义热力图属性.
@interface MAHeatMapVectorGridOverlayOptions : NSObject

/// 热力图类型 (默认为蜂窝类型MAHeatMapTypeHoneycomb)
@property (nonatomic, assign) MAHeatMapType type;

/// option选项是否可见. (默认YES)
@property (nonatomic, assign) BOOL visible;

/// 网格数据
@property (nonatomic, copy) NSArray<MAHeatMapVectorGrid *> *inputGrids;

/// 最小显示级别 default 3
@property (nonatomic, assign) CGFloat minZoom;

/// 最大显示级别 default 20
@property (nonatomic, assign) CGFloat maxZoom;

@end

///矢量热力图，支持类型详见MAHeatMapType
@interface MAHeatMapVectorGridOverlay : MAShape<MAOverlay>


///热力图的配置属性
@property (nonatomic, strong) MAHeatMapVectorGridOverlayOptions *option;

/**
 * @brief 根据配置属性option生成MAHeatMapVectorGridOverlay
 * @param option 热力图配置属性option
 * @return 新生成的热力图MAHeatMapVectorGridOverlay
 */
+ (instancetype)heatMapOverlayWithOption:(MAHeatMapVectorGridOverlayOptions *)option;

@end

#endif
