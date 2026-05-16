//telegram @wz662
//
//  rbContactMediaItem.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2020/4/24.
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import "JSQMediaItem.h"
#import "ContactMeta.h"

NS_ASSUME_NONNULL_BEGIN

@interface rbContactMediaItem : JSQMediaItem <NSCopying>

/**
 *  名片的头像，默认为nil.
 */
@property (copy, nonatomic) UIImage *image;

- (instancetype)initWithData:(nonnull ContactMeta *)fileMeta;

@end

NS_ASSUME_NONNULL_END
