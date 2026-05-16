//telegram @wz662
//
//  MessageRevokingProgess.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/11/13.
//  Copyright © 2021 JackJiang. All rights reserved.
//

#import "MessageRevokingProgess.h"
#import "BasicTool.h"


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 静态全局类变量
////////////////////////////////////////////////////////////////////////////////////////////

/* 消息撤回指令应答超时间（单位：毫秒） */
static int ACK_DELAY = 10000;


////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
////////////////////////////////////////////////////////////////////////////////////////////

@interface MessageRevokingProgess ()

/** 被撤回消息对应的指纹码（如果是群聊，则此指纹码实际指的是父指纹码——即fingerPrintOfParent） */
@property (nonatomic, retain) NSString *fpForMessage;

@property (nonatomic, retain) UIViewController *parentViewController;

@end


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
/////////////////////////////////////////////////////////////////////////////////////////////

@implementation MessageRevokingProgess

- (id)initWith:(UIViewController *)parentViewController
{
    if(self = [super initWith:ACK_DELAY contentString:@"消息撤回中"]){
        self.parentViewController = parentViewController;
    }
    return self;
}

// 显示进度提示框
- (void)show:(NSString *)fpForMessage
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    // 如果已经显示则强制取消显示
    if([self isShowing]){
        [self hide:YES fp:nil];
    }
    
    self.fpForMessage = fpForMessage;
    
    // 设置定时观察者
    self.onTimeoutObserver = ^(id observerble, id arg1) {
        // 乐观更新：不再弹“撤回失败”提示，超时仅默默关闭进度框
        [safeSelf hide:YES fp:nil];
    };
    // 显示进度提示框
    [self showProgressing:YES onParent:safeSelf.parentViewController.view];
}

// 隐藏进度提示框的显示
- (BOOL)hide:(BOOL)enforce fp:(NSString *)fpForMessage
{
    DDLogInfo(@"【MessageRevokingProgess】正在hide进度提示框（enforce=%d, fpForMessage=%@）。。。", enforce, fpForMessage);
    
    if(enforce){
        [self showProgressing:NO onParent:self.parentViewController.view];
        self.fpForMessage = nil;
        return YES;
    }
    else {
        if (self.fpForMessage != nil && [self.fpForMessage isEqualToString:fpForMessage]) {
            DDLogInfo(@"【MessageRevokingProgess】hide进度提示框成功（fpForMessage == this.fpForMessage == %@）。。。", fpForMessage);
            [self showProgressing:NO onParent:self.parentViewController.view];
            self.fpForMessage = nil;
            return YES;
        }
        else{
            DDLogInfo(@"【MessageRevokingProgess】hide进度提示框失败，（fpForMessage != self.fpForMessage，fpForMessage=%@、self.fpForMessage=>%@）。。。", fpForMessage, self.fpForMessage);
        }
        return NO;
    }
}

@end
