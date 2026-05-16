//telegram @wz662
//
//  ProgressHUDTimmer.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/11/13.
//  Copyright © 2021 JackJiang. All rights reserved.
//

#import "ProgressHUDTimmer.h"
#import "CompletionDefine.h"
#import "MBProgressHUD.h"


////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
////////////////////////////////////////////////////////////////////////////////////////////

@interface ProgressHUDTimmer (){
    MBProgressHUD *HUD;
}

/** 定时时间（单位：毫秒），默认值10秒 */
@property (nonatomic, assign) int delay;
/** 进度提示文字 */
@property (nonatomic, retain) NSString *content;
/* 登陆超时定时器 */
@property (nonatomic, retain) NSTimer *timer;

@end

/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
/////////////////////////////////////////////////////////////////////////////////////////////
///
@implementation ProgressHUDTimmer

- (id)initWith:(int)delay contentString:(NSString *)content
{
    if (![super init])
        return nil;
    
    self.delay = delay;
    if(self.delay <= 0){
        self.delay = 10000;
    }
    
    self.content = content;
    if(self.content == nil)
        self.content = @"加载中";

    return self;
}

/*
 * 登陆超时后要调用的方法。
 */
- (void)onTimeout
{
    if(self.onTimeoutObserver != nil)
        self.onTimeoutObserver(nil, nil);
}

- (void)showProgressing:(BOOL)show onParent:(UIView *)view
{
    // 显示进度提示的同时即启动超时提醒线程
    if(show)
    {
        [self showLoginProgressGUI:YES onParent:view];
        
        // 先无论如何保证timer在启动前肯定是处于停止状态
        [self stopTimer];
        // 启动(注意：执行延迟的单位是秒哦)
        self.timer = [NSTimer scheduledTimerWithTimeInterval:self.delay / 1000.0f
                                                      target:self
                                                    selector:@selector(onTimeout)
                                                    userInfo:nil
                                                     repeats:NO];
    }
    // 关闭进度提示
    else
    {
        // 无条件停掉延迟重试任务
        [self stopTimer];
        
        [self showLoginProgressGUI:NO onParent:view];
    }
}

- (void)stopTimer
{
    if(self.timer != nil)
    {
        if([self.timer isValid])
            [self.timer invalidate];
        
        self.timer = nil;
    }
}

/*
 * 进度提示时要显示或取消显示的GUI内容。
 *
 * @param show true表示显示gui内容，否则表示结速gui内容显示
 */
- (void)showLoginProgressGUI:(BOOL)show onParent:(UIView *)view
{
    // 显示登陆提示信息
    if(show)
    {
        if(HUD == nil)
        {
            // 实例化一个菊花。。。
            HUD = [[MBProgressHUD alloc] initWithView:view];
            [view addSubview:HUD];
            
            HUD.label.text = self.content;
        }
        
        [HUD showAnimated:YES];
        self.showing = YES;
    }
    // 关闭登陆提示信息
    else
    {
        if(HUD != nil){
           [HUD hideAnimated:NO];
            HUD = nil;
            self.showing = NO;
        }
    }
}

@end
