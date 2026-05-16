//telegram @wz662
//
//  MessageRevokingProgess.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/11/13.
//  Copyright © 2021 JackJiang. All rights reserved.
//
/**
 * 消息"撤回"功能对应的进度提示框（此进度框将在撤回指令发出时显示，撤回指令的ACK应答收到时取肖显示）。
 *
 * @author JackJiang
 * @since 4.3
 */

#import <Foundation/Foundation.h>
#import "ProgressHUDTimmer.h"

@interface MessageRevokingProgess : ProgressHUDTimmer

- (id)initWith:(UIViewController *)parentViewController;

/**
 * 显示进度提示框。
 *
 * @param fpForMessage 被撤回消息对应的指纹码（如果是群聊，则此指纹码实际指的是父指纹码——即fingerPrintOfParent）
 */
- (void)show:(NSString *)fpForMessage;

/**
 * 隐藏进度提示框的显示。
 *
 * @param enforce YES表示无条件强制进度提示框的显示，NO表示只有当 fpForMessage 参数与当前正在撤回的指纹码一致才会取消显示哦
 * @param fpForMessage 被撤回消息对应的指纹码（如果是群聊，则此指纹码实际指的是父指纹码——即fingerPrintOfParent）
 * @return YES表示正常hide完成
 */
- (BOOL)hide:(BOOL)enforce fp:(NSString *)fpForMessage;

@end


