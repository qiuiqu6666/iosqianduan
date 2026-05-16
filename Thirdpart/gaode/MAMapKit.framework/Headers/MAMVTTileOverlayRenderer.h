//telegram @wz662
//
//  MAMVTTileOverlayRenderer.h
//  MapKit_static
//
//  Created by Li Fei on 11/25/13.
//  Copyright © 2016 Amap. All rights reserved.
//

#import "MAConfig.h"
#if MA_INCLUDE_OVERLAY_TILE
#import "MATileOverlayRenderer.h"
#import "MAMVTTileOverlay.h"

/// 此类是将MAMVTOverlayRenderer中的覆盖tiles显示在地图上的Renderer
@interface MAMVTTileOverlayRenderer : MATileOverlayRenderer
@end

#endif
