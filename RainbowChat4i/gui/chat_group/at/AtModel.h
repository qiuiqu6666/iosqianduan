//telegram @wz662
//
//  NIMInputAtManager.h
//  NIMKit
//
//  Created by xxx on 2016/12/8.
//  Copyright © 2016年 xxx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TargetEntity.h"
#import "TargetChooseViewController.h"


#define NIMInputAtStartChar  @"@"
#define NIMInputAtEndChar    @"\u2004"

@interface AtBlock : NSObject

@property (nonatomic,copy) NSString *name;

@property (nonatomic,copy) NSString *uid;

@property (nonatomic,assign) NSRange range;

@end

@interface AtModel : NSObject

- (instancetype)initWith:(NSString *)gid;

- (void)clean;

//- (void)addAtItem:(AtItem *)item;
//
//- (AtItem *)item:(NSString *)name;
//
//- (AtItem *)removeName:(NSString *)name;

- (AtBlock *)delRangeForAt:(UITextView *)textView;

//- (NSRange)rangeForPrefix:(NSString *)prefix suffix:(NSString *)suffix target:(UITextView *)textView;

- (void)addAtUser:(TargetEntity *)selectedUser target:(UITextView *)textView;

- (void)addAtUser:(TargetEntity *)selectedUser prefix:(NSMutableString *)str target:(UITextView *)textView;

- (NSArray<NSString *> *)getAtUsers:(NSString *)sendText;

- (void)showAtUserActivity:(BOOL)needInsertAitInText nav:(UINavigationController *)navigationController delegate:(id<UserChooseCompleteDelegate>)userChooseCompleteDelegate;

@end
