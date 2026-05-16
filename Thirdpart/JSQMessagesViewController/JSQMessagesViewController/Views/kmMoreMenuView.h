//telegram @wz662
//
//  kmMoreMenuView.h
//  JSQMessages
//
//  Created by Keye Myria on 10/7/15.
//  Copyright © 2015 Hexed Bits. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "kmMoreMenuItem.h"

/**
 * 代理方法。
 */
@protocol kmMoreMenuViewDelegate  <NSObject>
@optional
- (void)didSelecteMoreMenuItem:(kmMoreMenuItem *)shareMenuItem atIndex:(NSInteger)index;
@end

@interface kmMoreMenuView : UIView
@property (nonatomic, strong) NSArray *shareMenuItems;
@property (nonatomic, weak) id<kmMoreMenuViewDelegate> delegate;
- (void)reloadData;
@end
