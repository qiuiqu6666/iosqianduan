//telegram @wz662
//
//  MAHeatMapVectorGridOverlayRenderer.h
//  MAMapKit
//
//  Created by ldj on 2019/7/26.
//  Copyright © 2019 Amap. All rights reserved.
//
#import "MAConfig.h"
#if MA_INCLUDE_OVERLAY_HEATMAP

#import "MAOverlayRenderer.h"
#import "MAHeatMapVectorGridOverlay.h"

///矢量热力图绘制类
@interface MAHeatMapVectorGridOverlayRenderer : MAOverlayRenderer

///关联的MAHeatMapVectorOverlay
@property (nonatomic, readonly) MAHeatMapVectorGridOverlay *heatOverlay;

/**
 * @brief 根据指定的MAHeatMapVectorOverlay生成一个Renderer
 * @param heatOverlay 指定MAHeatMapVectorOverlay
 * @return 新生成的MAHeatMapVectorOverlayRender
 */
- (instancetype)initWithHeatOverlay:(MAHeatMapVectorGridOverlay *)heatOverlay;
@end

#endif
