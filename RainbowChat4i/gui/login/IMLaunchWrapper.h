//telegram @wz662
//
//  IMLaunchWrapper.h
//  TalkM_visitor
//
//  Created by JackJiang on 17/4/11.
//  Copyright © 2017年 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IMServerConnector : NSObject<UIAlertViewDelegate>

- (id)initWith:(UIViewController *)parentViewController;

/**
 * IM服务器连接的相关配置初始化代码，在真正连接IM之前，本方法必须首先被调用。
 */
- (void)initConnectToIMServer;

/**
 * 连接到IM服务器实现代码。
 *
 * @param loginUserId 用于连接IM服务器时作为唯一用户id使用
 * @param loginToken 用于连接IM服务器时作为身份验证之用（此token通常由先前的SSO单点登陆接口返回并定义接下来的验证策略）
 */
- (void)connectToIMServer:(NSString *)loginUserId andToken:(NSString *)loginToken;

/**
 进入一对一聊天界面。
 */
- (void)gotoChatViewController;

@end
