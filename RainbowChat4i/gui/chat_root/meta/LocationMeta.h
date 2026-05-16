//telegram @wz662
//
//  LocationMeta.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2020/5/22.
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LocationMeta : NSObject

/** 位置主描述 */
@property (nonatomic, retain) NSString *locationTitle;
/** 位置详细描述 */
@property (nonatomic, retain) NSString *locationContent;
/** 经度 */
@property (nonatomic, assign) double longitude;
/** 纬度 */
@property (nonatomic, assign) double latitude;

/** 地图预览图缓存文件名（此字段可为空，为空表示发送者没有成功截屏到此预览图） */
@property (nonatomic, retain) NSString *prewviewImgFileName;

+ (LocationMeta *)fromJSON:(NSString *)jsonOfLocationMeta;

@end

NS_ASSUME_NONNULL_END
