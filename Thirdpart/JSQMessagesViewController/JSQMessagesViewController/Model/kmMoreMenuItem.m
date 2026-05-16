//telegram @wz662
//
//  kmMoreMenuItem.m
//  JSQMessages
//
//  Created by Keye Myria on 10/7/15.
//  Copyright © 2015 Hexed Bits. All rights reserved.
//

#import "kmMoreMenuItem.h"

@implementation kmMoreMenuItem

- (instancetype)initWithNormalIconImage:(UIImage *)normalIconImage
								  title:(NSString *)title
                               actionId:(int)acid {
    return [self initWithNormalIconImage:normalIconImage highlightIconImage:nil title:title actionId:acid];
}

- (instancetype)initWithNormalIconImage:(UIImage *)normalIconImage
					 highlightIconImage:(UIImage *)highlightIconImage
                                  title:(NSString *)title
                               actionId:(int)acid {
	self = [super init];
	if (self) {
		self.normalIconImage = normalIconImage;
		self.highlightIconImage = highlightIconImage;
		self.title = title;
        self.actionId = acid;
        self.usesWalletStyleIcon = NO;
        self.usesCompactMenuIcon = NO;
	}
	return self;
}

- (void)dealloc {
	self.normalIconImage = nil;
	self.highlightIconImage = nil;
	self.title = nil;
}


@end
