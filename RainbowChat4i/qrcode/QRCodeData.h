//telegram @wz662
//
//  QRCodeData.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/6.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 * 2维码解析后的对象。
 */

#import <Foundation/Foundation.h>

@interface QRCodeData : NSObject

@property (nonatomic, retain) NSString *scheme;
@property (nonatomic, retain) NSString *value;

@end

