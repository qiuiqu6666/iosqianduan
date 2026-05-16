//telegram @wz662
#import "OnLoginProgress.h"
#import "CompletionDefine.h"
#import "MBProgressHUD.h"


////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 静态全局类变量
////////////////////////////////////////////////////////////////////////////////////////////

/* 登陆超时时间定义(建议在TCP协议中用10秒，UDP协议下用6秒左右就可以了) */
static int RETRY_DELAY = 10000;// 6000


//////////////////////////////////////////////////////////////////////////////////////////////
//#pragma mark - 私有API
//////////////////////////////////////////////////////////////////////////////////////////////
//
//@interface OnLoginProgress (){
//    MBProgressHUD *HUD;
//}
//
///* 登陆超时定时器 */
//@property (nonatomic, retain) NSTimer *timer;
//
//@end


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
/////////////////////////////////////////////////////////////////////////////////////////////

@implementation OnLoginProgress

- (id)init
{
    if(self = [super initWith:RETRY_DELAY contentString:@"正在连接 "]){
        //
    }
    return self;
}

///*
// * 登陆超时后要调用的方法。
// */
//- (void)onTimeout
//{
//    if(self.onLoginTimeoutObserver != nil)
//        self.onLoginTimeoutObserver(nil, nil);
//}
//
//- (void)showProgressing:(BOOL)show onParent:(UIView *)view
//{
//    // 显示进度提示的同时即启动超时提醒线程
//    if(show)
//    {
//        [self showLoginProgressGUI:YES onParent:view];
//
//        // 先无论如何保证timer在启动前肯定是处于停止状态
//        [self stopTimer];
//        // 启动(注意：执行延迟的单位是秒哦)
//        self.timer = [NSTimer scheduledTimerWithTimeInterval:RETRY_DELAY / 1000.0f
//                                                      target:self
//                                                    selector:@selector(onTimeout)
//                                                    userInfo:nil
//                                                     repeats:NO];
//    }
//    // 关闭进度提示
//    else
//    {
//        // 无条件停掉延迟重试任务
//        [self stopTimer];
//
//        [self showLoginProgressGUI:NO onParent:view];
//    }
//}
//
//- (void)stopTimer
//{
//    if(self.timer != nil)
//    {
//        if([self.timer isValid])
//            [self.timer invalidate];
//
//        self.timer = nil;
//    }
//}
//
///*
// * 进度提示时要显示或取消显示的GUI内容。
// *
// * @param show true表示显示gui内容，否则表示结速gui内容显示
// */
//- (void)showLoginProgressGUI:(BOOL)show onParent:(UIView *)view
//{
//    // 显示登陆提示信息
//    if(show)
//    {
//        if(HUD == nil)
//        {
//            // 实例化一个菊花。。。
//            HUD = [[MBProgressHUD alloc] initWithView:view];
//            [view addSubview:HUD];
//
//            HUD.label.text = @"IM服务器连接中 ...";
//        }
//
//        [HUD showAnimated:YES];
//    }
//    // 关闭登陆提示信息
//    else
//    {
//        if(HUD != nil)
//           [HUD hideAnimated:NO];
//    }
//}

@end
