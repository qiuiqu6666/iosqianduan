//telegram @wz662
//
//  md5.m
//  iHiChat
//
//  Created by Maurice Fatio on 2017/4/18.
//  Copyright © 2017年 Maurice Fatio. All rights reserved.
//

#import "md5.h"
#include <CommonCrypto/CommonDigest.h>

@implementation md5
//-------------------------------------------------------------------------------------------------------------------------------------------------
+ (NSString *)md5HashOfData:(NSData *)data
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    if (data != nil)
    {
        unsigned char digest[CC_MD5_DIGEST_LENGTH];
        NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
        
        CC_MD5(data.bytes, (CC_LONG)data.length, digest);
        
        for (int i=0; i<CC_MD5_DIGEST_LENGTH; i++)
        {
            [output appendFormat:@"%02x", digest[i]];
        }
        return output;
    }
    return nil;
}
@end
