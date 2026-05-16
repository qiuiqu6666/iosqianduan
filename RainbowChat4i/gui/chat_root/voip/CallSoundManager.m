//
//  CallSoundManager.m
//  RainbowChat4i
//
//  通话铃声/提示音管理器实现。
//  使用 AVAudioPlayer 播放程序内存生成的 WAV 音频数据。
//

#import "CallSoundManager.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

/// WAV 文件头大小（字节）
#define WAV_HEADER_SIZE 44
/// 采样率
#define SAMPLE_RATE 16000
/// 音量幅度（0~32767）
#define TONE_AMPLITUDE 12000

@interface CallSoundManager ()

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, assign, readwrite) BOOL isPlaying;

@end

@implementation CallSoundManager

#pragma mark - 单例

+ (instancetype)sharedInstance
{
    static CallSoundManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CallSoundManager alloc] init];
    });
    return instance;
}

#pragma mark - 公开方法

- (void)playRingbackTone
{
    // 呼出等待铃声：440Hz 嘟声 1秒 + 静音 3秒，循环播放
    NSData *wavData = [self generateRingbackToneData];
    [self playWavData:wavData loops:-1]; // 无限循环
}

- (void)playRingtone
{
    // 来电铃声：双音交替 (800Hz/640Hz)，节奏感更强
    NSData *wavData = [self generateRingtoneData];
    [self playWavData:wavData loops:-1]; // 无限循环
}

- (void)playConnectedTone
{
    // 接通提示音：短促升调 (400→600Hz, 0.15秒)
    NSData *wavData = [self generateConnectedToneData];
    [self playWavData:wavData loops:0]; // 播放1次
}

- (void)playEndedTone
{
    // 结束提示音：短促降调 (500→350Hz, 0.3秒)
    NSData *wavData = [self generateEndedToneData];
    [self playWavData:wavData loops:0]; // 播放1次
}

- (void)playBusyTone
{
    // 忙线音：480Hz+620Hz 双音，0.5秒响+0.5秒静，重复3次
    NSData *wavData = [self generateBusyToneData];
    [self playWavData:wavData loops:0]; // 播放1次（内部已包含3次重复）
}

- (void)stopAll
{
    if (self.audioPlayer) {
        [self.audioPlayer stop];
        self.audioPlayer = nil;
    }
    self.isPlaying = NO;
    
    // 释放音频会话的"活跃"状态，让声网 RTC SDK 可以完全接管音频
    // 如果不释放，AVAudioPlayer 的残留音频会话可能阻止声网的音频路由正常工作
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setActive:NO
                                   withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                         error:&error];
    if (error) {
        NSLog(@"【CallSoundManager】释放音频会话失败（不影响功能）：%@", error);
    }
}

#pragma mark - 播放

- (void)playWavData:(NSData *)wavData loops:(NSInteger)loops
{
    [self stopAll];
    
    NSError *error = nil;
    
    // ⚠️ 使用 PlayAndRecord 模式而非 Playback，避免与声网 RTC 的音频会话冲突
    // Playback 模式会禁用麦克风，导致通话接通后对方听不到声音
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                     withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetooth
                                           error:&error];
    if (error) {
        NSLog(@"【CallSoundManager】设置音频会话失败：%@", error);
    }
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    self.audioPlayer = [[AVAudioPlayer alloc] initWithData:wavData error:&error];
    if (error) {
        NSLog(@"【CallSoundManager】创建AVAudioPlayer失败：%@", error);
        return;
    }
    
    self.audioPlayer.numberOfLoops = loops;
    self.audioPlayer.volume = 0.8;
    [self.audioPlayer prepareToPlay];
    [self.audioPlayer play];
    self.isPlaying = YES;
    
    // 单次播放的音效（接通/结束），同时触发震动
    if (loops == 0) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}

#pragma mark - 音频数据生成

/// 呼出等待铃声：440Hz 嘟声 1秒 + 静音 3秒 = 4秒一个周期
- (NSData *)generateRingbackToneData
{
    double toneOnDuration = 1.0;   // 响铃1秒
    double toneOffDuration = 3.0;  // 静音3秒
    double totalDuration = toneOnDuration + toneOffDuration;
    
    int totalSamples = (int)(SAMPLE_RATE * totalDuration);
    int toneOnSamples = (int)(SAMPLE_RATE * toneOnDuration);
    
    NSMutableData *pcmData = [NSMutableData dataWithLength:totalSamples * sizeof(int16_t)];
    int16_t *samples = (int16_t *)[pcmData mutableBytes];
    
    double freq = 440.0; // A4音
    
    for (int i = 0; i < totalSamples; i++) {
        if (i < toneOnSamples) {
            double t = (double)i / SAMPLE_RATE;
            // 加淡入淡出，避免爆音
            double envelope = 1.0;
            int fadeSamples = SAMPLE_RATE / 20; // 50ms fade
            if (i < fadeSamples) {
                envelope = (double)i / fadeSamples;
            } else if (i > toneOnSamples - fadeSamples) {
                envelope = (double)(toneOnSamples - i) / fadeSamples;
            }
            samples[i] = (int16_t)(sin(2.0 * M_PI * freq * t) * TONE_AMPLITUDE * envelope);
        } else {
            samples[i] = 0; // 静音
        }
    }
    
    return [self wrapPCMDataToWAV:pcmData];
}

/// 来电铃声：双音交替节奏（更有辨识度）
/// 模式：800Hz 0.2秒 → 640Hz 0.2秒 → 800Hz 0.2秒 → 静音 1.4秒 = 2秒一个周期
- (NSData *)generateRingtoneData
{
    double totalDuration = 2.0;
    int totalSamples = (int)(SAMPLE_RATE * totalDuration);
    
    NSMutableData *pcmData = [NSMutableData dataWithLength:totalSamples * sizeof(int16_t)];
    int16_t *samples = (int16_t *)[pcmData mutableBytes];
    
    // 音调模式定义
    double tones[] = {800.0, 640.0, 800.0}; // 三段音调
    double toneDurations[] = {0.2, 0.2, 0.2}; // 每段时长
    int toneCount = 3;
    
    int sampleOffset = 0;
    for (int toneIdx = 0; toneIdx < toneCount; toneIdx++) {
        int toneSamples = (int)(SAMPLE_RATE * toneDurations[toneIdx]);
        int fadeSamples = SAMPLE_RATE / 40; // 25ms fade
        
        for (int i = 0; i < toneSamples && (sampleOffset + i) < totalSamples; i++) {
            double t = (double)i / SAMPLE_RATE;
            double envelope = 1.0;
            if (i < fadeSamples) {
                envelope = (double)i / fadeSamples;
            } else if (i > toneSamples - fadeSamples) {
                envelope = (double)(toneSamples - i) / fadeSamples;
            }
            samples[sampleOffset + i] = (int16_t)(sin(2.0 * M_PI * tones[toneIdx] * t) * TONE_AMPLITUDE * envelope);
        }
        sampleOffset += toneSamples;
    }
    
    // 剩余部分是静音
    for (int i = sampleOffset; i < totalSamples; i++) {
        samples[i] = 0;
    }
    
    return [self wrapPCMDataToWAV:pcmData];
}

/// 接通提示音：400Hz→600Hz 升调滑音 0.2秒
- (NSData *)generateConnectedToneData
{
    double duration = 0.2;
    int totalSamples = (int)(SAMPLE_RATE * duration);
    
    NSMutableData *pcmData = [NSMutableData dataWithLength:totalSamples * sizeof(int16_t)];
    int16_t *samples = (int16_t *)[pcmData mutableBytes];
    
    double freqStart = 400.0;
    double freqEnd = 600.0;
    int fadeSamples = SAMPLE_RATE / 40;
    
    for (int i = 0; i < totalSamples; i++) {
        double progress = (double)i / totalSamples;
        double freq = freqStart + (freqEnd - freqStart) * progress;
        double t = (double)i / SAMPLE_RATE;
        double envelope = 1.0;
        if (i < fadeSamples) envelope = (double)i / fadeSamples;
        if (i > totalSamples - fadeSamples) envelope = (double)(totalSamples - i) / fadeSamples;
        samples[i] = (int16_t)(sin(2.0 * M_PI * freq * t) * TONE_AMPLITUDE * 0.7 * envelope);
    }
    
    return [self wrapPCMDataToWAV:pcmData];
}

/// 结束提示音：500Hz→350Hz 降调 0.3秒
- (NSData *)generateEndedToneData
{
    double duration = 0.3;
    int totalSamples = (int)(SAMPLE_RATE * duration);
    
    NSMutableData *pcmData = [NSMutableData dataWithLength:totalSamples * sizeof(int16_t)];
    int16_t *samples = (int16_t *)[pcmData mutableBytes];
    
    double freqStart = 500.0;
    double freqEnd = 350.0;
    int fadeSamples = SAMPLE_RATE / 40;
    
    for (int i = 0; i < totalSamples; i++) {
        double progress = (double)i / totalSamples;
        double freq = freqStart + (freqEnd - freqStart) * progress;
        double t = (double)i / SAMPLE_RATE;
        double envelope = 1.0;
        if (i < fadeSamples) envelope = (double)i / fadeSamples;
        if (i > totalSamples - fadeSamples) envelope = (double)(totalSamples - i) / fadeSamples;
        samples[i] = (int16_t)(sin(2.0 * M_PI * freq * t) * TONE_AMPLITUDE * 0.7 * envelope);
    }
    
    return [self wrapPCMDataToWAV:pcmData];
}

/// 忙线提示音：480Hz+620Hz 双音，0.5秒响+0.5秒静，重复3次 = 3秒
- (NSData *)generateBusyToneData
{
    int repeatCount = 3;
    double toneOn = 0.5;
    double toneOff = 0.5;
    double totalDuration = (toneOn + toneOff) * repeatCount;
    int totalSamples = (int)(SAMPLE_RATE * totalDuration);
    int cycleSamples = (int)(SAMPLE_RATE * (toneOn + toneOff));
    int onSamples = (int)(SAMPLE_RATE * toneOn);
    
    NSMutableData *pcmData = [NSMutableData dataWithLength:totalSamples * sizeof(int16_t)];
    int16_t *samples = (int16_t *)[pcmData mutableBytes];
    
    double freq1 = 480.0;
    double freq2 = 620.0;
    int fadeSamples = SAMPLE_RATE / 40;
    
    for (int i = 0; i < totalSamples; i++) {
        int posInCycle = i % cycleSamples;
        if (posInCycle < onSamples) {
            double t = (double)i / SAMPLE_RATE;
            double envelope = 1.0;
            if (posInCycle < fadeSamples) envelope = (double)posInCycle / fadeSamples;
            if (posInCycle > onSamples - fadeSamples) envelope = (double)(onSamples - posInCycle) / fadeSamples;
            double val = sin(2.0 * M_PI * freq1 * t) + sin(2.0 * M_PI * freq2 * t);
            samples[i] = (int16_t)(val * TONE_AMPLITUDE * 0.4 * envelope);
        } else {
            samples[i] = 0;
        }
    }
    
    return [self wrapPCMDataToWAV:pcmData];
}

#pragma mark - WAV 封装

/// 将原始 PCM 数据封装为 WAV 格式
- (NSData *)wrapPCMDataToWAV:(NSData *)pcmData
{
    int dataSize = (int)[pcmData length];
    int fileSize = WAV_HEADER_SIZE + dataSize;
    
    NSMutableData *wavData = [NSMutableData dataWithLength:fileSize];
    unsigned char *bytes = (unsigned char *)[wavData mutableBytes];
    
    // RIFF header
    memcpy(bytes + 0, "RIFF", 4);
    [self writeInt32:fileSize - 8 toBytes:bytes + 4];
    memcpy(bytes + 8, "WAVE", 4);
    
    // fmt chunk
    memcpy(bytes + 12, "fmt ", 4);
    [self writeInt32:16 toBytes:bytes + 16]; // chunk size
    [self writeInt16:1 toBytes:bytes + 20]; // PCM format
    [self writeInt16:1 toBytes:bytes + 22]; // mono
    [self writeInt32:SAMPLE_RATE toBytes:bytes + 24]; // sample rate
    [self writeInt32:SAMPLE_RATE * 2 toBytes:bytes + 28]; // byte rate (sampleRate * channels * bitsPerSample/8)
    [self writeInt16:2 toBytes:bytes + 32]; // block align (channels * bitsPerSample/8)
    [self writeInt16:16 toBytes:bytes + 34]; // bits per sample
    
    // data chunk
    memcpy(bytes + 36, "data", 4);
    [self writeInt32:dataSize toBytes:bytes + 40];
    
    // PCM data
    memcpy(bytes + WAV_HEADER_SIZE, [pcmData bytes], dataSize);
    
    return wavData;
}

- (void)writeInt32:(int)value toBytes:(unsigned char *)bytes
{
    bytes[0] = (value) & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
    bytes[2] = (value >> 16) & 0xFF;
    bytes[3] = (value >> 24) & 0xFF;
}

- (void)writeInt16:(int)value toBytes:(unsigned char *)bytes
{
    bytes[0] = (value) & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
}

@end
