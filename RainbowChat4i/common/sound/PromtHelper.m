//telegram @wz662
#import "PromtHelper.h"
#import "JSQSystemSoundPlayer.h"
#import "UserDefaultsToolKits.h"
#import <AVFoundation/AVFoundation.h>
#import "UserDefaultsToolKits.h"


@interface PromtHelper ()
// 做成全局变量，否则还没等声音播放则AVAudioPlayer就被回收而无法播放出声音
@property (strong, nonatomic) AVAudioPlayer *avAudioPlayer;
@end


@implementation PromtHelper

// 本类的单例对象
static PromtHelper *instance = nil;

+ (PromtHelper *)sharedInstance
{
    if (instance == nil)
    {
        instance = [[super allocWithZone:NULL] init];
    }
    return instance;
}

- (void)scanQRPromt
{
    [self rb_playSoundFromJSQMessagesBundleWithName:@"scan_qr_beep" type:@"wav"];
}

- (void)tixintPromt
{
    [self rb_playSoundFromJSQMessagesBundleWithName:@"audio_msg" type:@"wav"];
}

- (void)newFriendAddSucessPromt
{
    [self rb_playSoundFromJSQMessagesBundleWithName:@"audio_new_friend_add_sucess" type:@"wav"];
}

- (void)audioRecordingPromt
{
    [self rb_playSoundFromJSQMessagesBundleWithName:@"audio_voice_recording" type:@"wav"];
}

- (void)msgSendPromt
{
    [self rb_playSoundFromJSQMessagesBundleWithName:@"audio_voice_send" type:@"wav"];
}

- (void)audioPlayEndPromt
{
    [self rb_playSoundFromJSQMessagesBundleWithName:@"audio_voice_stoped" type:@"wav"];
}

- (void)rb_playSoundFromJSQMessagesBundleWithName:(NSString *)soundName type:(NSString *)type
{
    if(![UserDefaultsToolKits isAPPMsgToneOpen])
        return;
        
    //从budle路径下读取音频文件
    NSString *string = [[NSBundle mainBundle] pathForResource:soundName ofType:type];
    //把音频文件转换成url格式
    NSURL *url = [NSURL fileURLWithPath:string];

    NSLog(@"[PromtHelper] 提示音要播放的声音文件完整url=%@", url);

    //## Bug FIX since v4.2：此行代码将导致短视频消息中录制出的视频没有声音，注释掉此行后解决问题！
//  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    //## Bug FIX END

    if(self.avAudioPlayer != nil)
    {
        if([self.avAudioPlayer isPlaying])
            [self.avAudioPlayer stop];
        self.avAudioPlayer = nil;
    }

    //初始化音频类 并且添加播放文件
    self.avAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
//  self.avAudioPlayer.volume = 1.0f;
    [self.avAudioPlayer prepareToPlay];
    // 开始播放
    [self.avAudioPlayer play];
}

@end
