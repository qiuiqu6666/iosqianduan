//telegram @wz662
//
//  GetSMSButton.h
//  RainbowChat4i
//
//  Created by JackJiang on 2025/8/23.
//  Copyright © 2025 JackJiang. All rights reserved.
//
/**
 * 获取短信验证码通用组件。
 *
 * @author JackJiang
 * @since 10.0
 */

#import <Foundation/Foundation.h>

@protocol GetSMSButtonDelegate <NSObject>
@required

/** 短信验证码用于的业务类型（0 表示用于验证码登录功能中，1 表示用于注册新账号功能中， 2 表示用于手机号+验证码重置密码功能中） */
- (NSString *)getSmsBizType;
/** 手机号码 */
- (NSString *)getPhoneNum;
/** 验证码请求发出后，将输入焦点设置到验证码输入框里 */
- (void)focusToInput;

@optional
/** 跳转到注册页面 */
- (void)gotoRegisterPage;

@end


@interface GetSMSButton : UIButton

@property (nonatomic, strong) UIViewController *parentVC;
@property (nonatomic, weak) id<GetSMSButtonDelegate> delegate;


@end
