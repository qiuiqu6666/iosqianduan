//telegram @wz662
//
//  kmMoreMenuItem.h
//  JSQMessages
//
//  Created by Keye Myria on 10/7/15.
//  Copyright © 2015 Hexed Bits. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface kmMoreMenuItem : NSObject

/** 本item的id值（用于点击时识别此item） */
@property (nonatomic, assign) int actionId;

/** YES 时更多面板图标使用略小尺寸（红包/转账）；勿再用 actionId 猜语义（单聊与群聊编号不一致） */
@property (nonatomic, assign) BOOL usesWalletStyleIcon;

/** YES 时图标比默认更小（收藏、红包）；优先级高于 usesWalletStyleIcon */
@property (nonatomic, assign) BOOL usesCompactMenuIcon;

@property (nonatomic, strong) UIImage *normalIconImage;
@property (nonatomic, strong) UIImage *highlightIconImage;
@property (nonatomic, copy) NSString *title;

- (instancetype)initWithNormalIconImage:(UIImage *)normalIconImage
                                  title:(NSString *)title
                               actionId:(int)acid;

- (instancetype)initWithNormalIconImage:(UIImage *)normalIconImage
                     highlightIconImage:(UIImage *)highlightIconImage
                                  title:(NSString *)title
                               actionId:(int)acid;

@end
