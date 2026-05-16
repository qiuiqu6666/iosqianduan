//telegram @wz662
//
//  rbFileMediaItem.h
//  RainbowChat4i
//
//  Created by JackJiang on 2018/8/18.
//  Copyright © 2018年 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JSQMediaItem.h"
#import "FileMeta.h"
#import "JSQMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface rbFileMediaItem : JSQMediaItem <NSCopying>

- (instancetype)initWithData:(nonnull FileMeta *)fileMeta;
- (void)refreshUploadProgress:(SendStatusSecondary)sendStatusSecondary sendStatusSecondaryProgress:(int)progress;

@end

NS_ASSUME_NONNULL_END
