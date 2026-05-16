//telegram @wz662
//
//  rbContactMediaItem.h
//  RainbowChat4i
//
//  Created by Jack Jiang.
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import "JSQMediaItem.h"
#import "LocationMeta.h"

NS_ASSUME_NONNULL_BEGIN

@interface rbLocationMediaItem : JSQMediaItem <NSCopying>

/**
 * 预览图，默认为nil.
 */
@property (copy, nonatomic) UIImage *image;

- (instancetype)initWithData:(nonnull LocationMeta *)locationMeta;

@end

NS_ASSUME_NONNULL_END
