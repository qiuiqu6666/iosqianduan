//telegram @wz662
//
//  EditProfile.h
//  iHiChat
//
//  Created by Maurice Fatio on 2017/4/18.
//  Copyright © 2017年 Maurice Fatio. All rights reserved.
//

#import <Foundation/Foundation.h>
 
//-------------------------------------------------------------------------------------------------------------------------------------------------
@interface Image : NSObject
//-------------------------------------------------------------------------------------------------------------------------------------------------

+ (UIImage *)square:(UIImage *)image size:(CGFloat)size;

+ (UIImage *)resize:(UIImage *)image width:(CGFloat)width height:(CGFloat)height scale:(CGFloat)scale;

@end

