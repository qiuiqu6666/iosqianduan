//
//  CallSoundManager.h
//  RainbowChat4i
//
//  通话铃声/提示音管理器（单例）。
//  使用程序生成的音频数据，不依赖外部音频文件。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CallSoundManager : NSObject

+ (instancetype)sharedInstance;

/// 播放呼出等待铃声（嘟...嘟...循环）
- (void)playRingbackTone;

/// 播放来电铃声（循环）
- (void)playRingtone;

/// 播放通话接通提示音（短促）
- (void)playConnectedTone;

/// 播放通话结束提示音（短促）
- (void)playEndedTone;

/// 播放忙线提示音（短促）
- (void)playBusyTone;

/// 停止所有铃声
- (void)stopAll;

/// 是否正在播放
@property (nonatomic, assign, readonly) BOOL isPlaying;

@end

NS_ASSUME_NONNULL_END
