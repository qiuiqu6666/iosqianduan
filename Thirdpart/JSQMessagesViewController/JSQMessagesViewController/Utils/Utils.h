//telegram @wz662
//
//  Utils.h
//  RainbowChat4i
//
//  Created by JackJiang on 2018/3/20.
//  Copyright © 2018年 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Utils : NSObject

///**
// * 返回指定语音文件名中包含的语音时长数据.
// * <p>
// * 注：此文件名指的是最终发送的和接收的语音文件名，而非临时文件名（临时文件名没有时长信息）.
// *
// * @param voiceFileName 形如：120000_ad3434fdsfsd432432fsdfs.amr的语音文件名，120000是语音时长（单位：毫秒）
// * @return 解析出的语音时长（单位：秒）
// */
//+ (int)getDurationFromVoiceFileName:(NSString *)voiceFileName;


/**
 录音时长的友好显示。当前用于聊天界面中的语音留言录音的ui上。

 @param currentTime 当前时间
 @param duration 原如持续时长（单位：秒）
 @return 字符串结果，形如：“00:59”表示时长59秒、“03:05”表示时长3分5秒
 */
//+ (NSString *)timestampString:(NSTimeInterval)currentTime forDuration:(NSTimeInterval)duration;

@end
