//telegram @wz662
//
//  GetSMSButton.m
//  RainbowChat4i
//
//  Created by JackJiang on 2025/8/23.
//  Copyright © 2025 JackJiang. All rights reserved.
//

#import "GetSMSButton.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "PuzzleSliderCaptchaViewController.h"

// 每次获取验证码的倒计时等待时间
#define TIME_TO_WAITE 60

@interface GetSMSButton ()

@property (nonatomic, strong) NSTimer *countdownTimer;
@property (nonatomic, assign) NSTimeInterval sendCodeTime;

/** 短信验证码请求等待中 */
@property (nonatomic, assign) BOOL smsWaiting;

@end

@implementation GetSMSButton

- (void)awakeFromNib {
    [super awakeFromNib];
    [self configureView];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self configureView];
    }
    return self;
}

- (void)dealloc {
    if (self.countdownTimer) {
        [self.countdownTimer invalidate];
        self.countdownTimer = nil;
    }
}

- (void)configureView {
//    self
//    self.buttonType = UIButtonTypeCustom;
//    [self setFont: [UIFont systemFontOfSize:13.0]];
//    self.titleLabel.text = @"获取验证码";
    
    // 初始化
    self.smsWaiting = NO;
    
    // 按钮添加边框
    [BasicTool setBorder:self width:1.0f color:HexColor(0xF1F3F6) radius:17.0f];
    // 添加按钮事件处理
    [self addTarget:self action:@selector(doGetSMS:) forControlEvents:UIControlEventTouchUpInside];
    
}

/**
   * 用于短信验证码登录时。
   *
   * @returns
   */
 -(BOOL) isBizType4Login {
    return [@"0" isEqualToString:[self.delegate getSmsBizType]];
  }

  /**
   * 用于注册时。
   *
   * @returns
   */
-(BOOL) isBizType4Register {
    return [@"1" isEqualToString:[self.delegate getSmsBizType]];
}

-(void)refreshForGetStart
{
    self.smsWaiting = YES;
    [self setTitle:@"短信发送中" forState:UIControlStateNormal];
    self.enabled = NO;
}

-(void)refreshForGetTiming:(int)remainSecond
{
    [self setTitle: [NSString stringWithFormat:@"%ds后重发", TIME_TO_WAITE - remainSecond] forState:UIControlStateNormal];
}

-(void)refreshForGetEnd
{
    self.smsWaiting = NO;
    [self setTitle:@"获取验证码" forState:UIControlStateNormal];
    self.enabled = YES;
}

- (void)updateCountdown:(id)sender
{
    int second = (int)([NSDate date].timeIntervalSince1970 - self.sendCodeTime);
    [self refreshForGetTiming:second];
//    [self.sendCodeBtn setTitle:[NSString stringWithFormat:@"%ds", 60-second] forState:UIControlStateNormal];
    if (second >= TIME_TO_WAITE) {
        [self.countdownTimer invalidate];
        self.countdownTimer = nil;
        [self refreshForGetEnd];
//        self.smsWaiting = NO;
//        [self.sendCodeBtn setTitle:@"获取验证码" forState:UIControlStateNormal];
//        self.sendCodeBtn.enabled = YES;
    }
}


// "获取验证码"按钮事件处理
- (void)doGetSMS:(UIButton *)sender
{
    // 先无条件隐藏软键盘
    [BasicTool hideSoftInputMethod];
    
    if (self.smsWaiting) {
        [BasicTool showAlertWarn:@"验证码正在获取中，请稍后再试！" parent:self.parentVC];
        return;
    }
    
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf1 = self;
    __weak typeof(self.parentVC) safeParent = self.parentVC;
    
    NSString *phoneNum = [self.delegate getPhoneNum];
    NSString *smsBizType = [self.delegate getSmsBizType];
    
    if([BasicTool isStringEmpty:smsBizType]) {
        [BasicTool showAlertWarn:@"无效的参数，业务类型smsBizType未设定！" parent:self.parentVC];
        return;
    }
    if([BasicTool isStringEmpty:phoneNum]) {
        [BasicTool showAlertWarn:@"请输入手机号码！" parent:self.parentVC];
        return;
    }
    if(![BasicTool verifyChineseMainlandPhone:phoneNum]) {
        [BasicTool showAlertWarn:@"请输入正确的中国大陆手机号码！" parent:self.parentVC];
        return;
    }
    
    if (!safeParent) {
        [self reallySubmitGetSMS];
        return;
    }
    PuzzleSliderCaptchaViewController *captcha = [[PuzzleSliderCaptchaViewController alloc] init];
    captcha.modalPresentationStyle = UIModalPresentationOverFullScreen;
    captcha.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    captcha.onVerifySuccess = ^{
        [safeSelf1 reallySubmitGetSMS];
    };
    captcha.onCancel = ^{ };
    [safeParent presentViewController:captcha animated:YES completion:nil];
}

- (void)reallySubmitGetSMS
{
    __weak typeof(self) safeSelf1 = self;
    __weak UIViewController *safeParent = self.parentVC;
    NSString *phoneNum = [self.delegate getPhoneNum];
    NSString *smsBizType = [self.delegate getSmsBizType];
    [safeSelf1 refreshForGetStart];
    [[HttpRestHelper sharedInstance] submitGetSMS:phoneNum bizType:smsBizType complete:^(BOOL sucess, NSString *retrunValue) {
        // 服务端处理成功完成
        if(sucess && ![BasicTool isStringEmpty:retrunValue])
        {
            // 将JSON转成OC的Dictionary(使用苹果官方的JSON API转2维数组强大一些，EVA框架选用的JSON库RMMapper比较简洁，不太支持这种复杂数据结构)
            NSData *rdata = [retrunValue dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary* jsonData = [NSJSONSerialization JSONObjectWithData:rdata options:NSJSONReadingMutableContainers error:nil];
            
            // 服服务返回的查询结果码（详见http文档中“【接口1008-1-27】”的详细说明）：
            NSString *code = [jsonData objectForKey:@"code"];
            NSString *desc = [jsonData objectForKey:@"desc"];
            
//                NSString *code = @"1";
//                NSString *desc = @"";
            
            // 短信验证码发送成功
            if([@"1" isEqualToString:code]) {
                // ToolKits.showToast('验证码已发送至 '+this.phoneNum+" ...");
                [APP showUserDefineToast_OK:@"验证码已发送"];
                
                // 开始倒计时
                safeSelf1.sendCodeTime = [NSDate date].timeIntervalSince1970;
                safeSelf1.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateCountdown:) userInfo:nil repeats:YES];
                [safeSelf1.countdownTimer fire];
                
                // 验证码输入框获得焦点
                [safeSelf1.delegate focusToInput];
            }
            // 错误码1：手机号格式不符合规范
            else if([@"-3" isEqualToString:code]) {
                [safeSelf1 refreshForGetEnd];
                [BasicTool showAlertWarn:@"请输入正确的中国大陆手机号码后再试！" parent:safeParent];
            }
            // 错误码2：手机号未注册
            else if([@"-2" isEqualToString:code]) {
                [safeSelf1 refreshForGetEnd];
                // 登录时手机号未注册的话，就显示提示并可跳转到注册页面
                if([safeSelf1 isBizType4Login]) {
                    NSString *hint = [NSString stringWithFormat:@"手机号%@尚未注册，是否现在注册账号？", phoneNum];
                    // 显示一个确认对话框
                    [BasicTool areYouSureAlert:@"请确认" content:hint okBtnTitle:NSLocalizedString(@"general_ok", @"") cancelBtnTitle:NSLocalizedString(@"general_cancel", @"") parent:safeParent okHandler:^(UIAlertAction * _Nullable action) {
                        // 进入注册页面
                        [safeSelf1.delegate gotoRegisterPage];
                    } cancelHandler:^(UIAlertAction * _Nullable action)  {
                        
                    } cencelActionStyle:UIAlertActionStyleCancel];
                }
            }
            // 错误码3：手机号已经注册
            else if([@"-1" isEqualToString:code]) {
                [safeSelf1 refreshForGetEnd];
                // 注册时如果发现手机号已经注册，直接提示用户就行了
                if([safeSelf1 isBizType4Register]) {
                    [BasicTool showAlertWarn:[NSString stringWithFormat:@"手机号%@已经注册，请从登录界面选择\"验证码登录\"即可。", phoneNum] parent:safeParent];
                }
            }
            // 错误码4：验证码发送失败
            else if([@"0" isEqualToString:code]) {
                if([@"isv.BUSINESS_LIMIT_CONTROL" isEqualToString:desc]) {
                    [BasicTool showAlertWarn:@"验证码发送失败，您的操作过于频繁，请稍后再试！" parent:safeParent];
                } else {
                    [BasicTool showAlertWarn:[NSString stringWithFormat:@"验证码发送失败，原因是 %@，请稍后再试！", desc] parent:safeParent];
                }
            }
        }
        else
        {
            [BasicTool showAlertWarn:@"请求失败，请稍后再试。" parent:safeParent];
            [safeSelf1 refreshForGetEnd];
        }
    } hudParentView:self.parentVC.view showLocalErrorAlert:YES completeForLocalError:^(NSString *errorLog) {
        [safeSelf1 refreshForGetEnd];
    }];
}



@end

