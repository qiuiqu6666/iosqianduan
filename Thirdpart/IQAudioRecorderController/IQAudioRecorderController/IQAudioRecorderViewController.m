//telegram @wz662

#import "IQAudioRecorderViewController.h"
#import "NSString+IQTimeIntervalFormatter.h"
#import "IQMessageDisplayView.h"
//#import "SCSiriWaveformView.h"
#import <AVFoundation/AVFoundation.h>

#import "Masonry.h"
#import "IQVoiceMeterView.h"
#import "PromtHelper.h"

#include "amrFileCodec.h"

/************************************/

@interface IQAudioRecorderViewController() <AVAudioRecorderDelegate,AVAudioPlayerDelegate,IQMessageDisplayViewDelegate>
{
    BOOL _isFirstTime;
    
    //** Recording...
    AVAudioRecorder *_audioRecorder;
    NSString *_recordingFilePath;
    CADisplayLink *meterUpdateDisplayLink;

    //** 语音录制相关组件
    UIView *viewMainRecording;
    // 旋转动画图片组件
    UIImageView *rotateBgImageView;
    UIButton *sendAudioButton;
    UIButton *cancelAudioButton;
    UILabel *progressLabel;
    IQVoiceMeterView *meterImageView;
    NSTimer *_meterUpdateTimer;

    //** Access
    IQMessageDisplayView *viewMicrophoneDenied;
    
    //** Private variables
    NSString *_oldSessionCategory;
    BOOL _wasIdleTimerDisabled;
}

@end


@implementation IQAudioRecorderViewController

@dynamic title;


#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = RGBACOLOR(0, 0, 0, 176);

    _isFirstTime = YES;

    // Define the recorder setting
    {
        NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];

        NSString *globallyUniqueString = [NSProcessInfo processInfo].globallyUniqueString;

        if (self.audioFormat == IQAudioFormatDefault || self.audioFormat == IQAudioFormat_m4a)
        {
            _recordingFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.m4a",globallyUniqueString]];

            recordSettings[AVFormatIDKey] = @(kAudioFormatMPEG4AAC);
        }
        else if (self.audioFormat == IQAudioFormat_caf)
        {
            _recordingFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.caf",globallyUniqueString]];

            recordSettings[AVFormatIDKey] = @(kAudioFormatLinearPCM);
        }
        
        if (self.sampleRate > 0.0f)
            recordSettings[AVSampleRateKey] = @(self.sampleRate);
        else
            recordSettings[AVSampleRateKey] = @44100.0f;

        if (self.numberOfChannels >0)
            recordSettings[AVNumberOfChannelsKey] = @(self.numberOfChannels);
        else
            recordSettings[AVNumberOfChannelsKey] = @1;

        if (self.audioQuality != IQAudioQualityDefault)
            recordSettings[AVEncoderAudioQualityKey] = @(self.audioQuality);

        if (self.bitRate > 0)
            recordSettings[AVEncoderBitRateKey] = @(self.bitRate);

        // Initiate and prepare the recorder
        _audioRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:_recordingFilePath] settings:recordSettings error:nil];
        _audioRecorder.delegate = self;
        _audioRecorder.meteringEnabled = YES;
    }

    // 录制界面主UI
    {
        CGFloat mainViewWidth = 200;
        CGFloat mainViewHeight = 200;

        // 主view
        viewMainRecording = [[UIView alloc] init];
//        sv.backgroundColor = [UIColor greenColor];
        [self.view addSubview:viewMainRecording];
        [viewMainRecording mas_makeConstraints:^(MASConstraintMaker *make) {
            // 水平居中于父组件
            make.centerX.equalTo(self.view);
            // 底部相对于父组件-70（即向上移70像素）的位置处
            make.bottom.equalTo(self.view).with.offset(-120);// -70
            make.size.mas_equalTo(CGSizeMake(mainViewWidth, mainViewHeight));
        }];

        // 旋转光环动画图片组件
        CGFloat rotateBgImageViewWidth = 120;
        CGFloat rotateBgImageViewHeight = 120;
        rotateBgImageView = [[UIImageView alloc] initWithFrame:CGRectMake((mainViewWidth - rotateBgImageViewWidth)/2, 0, rotateBgImageViewWidth, rotateBgImageViewHeight)];
        rotateBgImageView.image = [UIImage imageNamed:@"chatting_list_view_record_frame_btn_light"];
        [viewMainRecording addSubview:rotateBgImageView];

        // 发送语音的圆形图片按钮
        CGFloat sendVoiceButtonWidth = 105;
        CGFloat sendVoiceButtonHeight = 105;
        sendAudioButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [sendAudioButton setFrame:CGRectMake((mainViewWidth - sendVoiceButtonWidth)/2, 7.5, sendVoiceButtonWidth, sendVoiceButtonHeight)];
        // 针对ios 26的优化：给按钮设置液态玻璃效果就不需要单独设置背景图了
        if (@available(iOS 26, *)) {
            // 给按钮设置液态玻璃效果
            [BasicTool setClearGlassBgnConfig:sendAudioButton];
        }
        else {
            [sendAudioButton setBackgroundImage:(self.sendButtonImage==nil?[UIImage imageNamed:@"chatting_list_view_record_frame_btn_speech"]:self.sendButtonImage) forState:UIControlStateNormal];
            [sendAudioButton setBackgroundImage:(self.sendButtonImageHighlight==nil?[UIImage imageNamed:@"chatting_list_view_record_frame_btn_speech_hover"]:self.sendButtonImageHighlight) forState:UIControlStateHighlighted];
        }
        
        // 按下即停止录音，避免松手时的系统点击声被录入；松手再回调 delegate
        [sendAudioButton addTarget:self action:@selector(doneButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [sendAudioButton addTarget:self action:@selector(doneAction:) forControlEvents:UIControlEventTouchUpInside];
        [viewMainRecording addSubview:sendAudioButton];

        // 当前录音时长组件
        CGSize labelSize = CGSizeMake(50, 20);// 50,
        CGRect labelFrame = CGRectMake((mainViewWidth-labelSize.width)/2
                                       , CGRectGetMaxY(rotateBgImageView.frame)+20
                                       , labelSize.width
                                       , labelSize.height);
        progressLabel = [[UILabel alloc] initWithFrame:labelFrame];
        progressLabel.textAlignment = NSTextAlignmentCenter;
//        progressLabel.adjustsFontSizeToFitWidth = YES;
        progressLabel.textColor = HexColor(0xffffff);
        progressLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
        progressLabel.text = @"00:00";
        // 阴影颜色
        progressLabel.shadowColor = RGBACOLOR(14, 15, 15, 221);//[UIColor redColor];
        // 阴影偏移  x，y为正表示向右下偏移
        progressLabel.shadowOffset = CGSizeMake(1, 1);
        [viewMainRecording addSubview:progressLabel];

        // 取消发送按钮
        CGFloat cancelVoiceButtonWidth = 120;
        CGFloat cancelVoiceButtonHeight = 36;// 35
        cancelAudioButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [cancelAudioButton setFrame:CGRectMake((mainViewWidth - cancelVoiceButtonWidth)/2, CGRectGetMaxY(progressLabel.frame)+5, cancelVoiceButtonWidth, cancelVoiceButtonHeight)];
        // 针对ios 26的优化：给按钮设置液态玻璃效果就不需要单独设置背景图了
        if (@available(iOS 26, *)) {
            // 设置圆角
            [cancelAudioButton.layer setCornerRadius:cancelVoiceButtonHeight/2.0f];
            // 给按钮设置液态玻璃效果
            [BasicTool setClearGlassBgnConfig:cancelAudioButton];
            // 文字颜色
            [cancelAudioButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [cancelAudioButton setTitleColor:RGBACOLOR(255, 255, 255, 128) forState:UIControlStateHighlighted];
            // 字号
            cancelAudioButton.titleLabel.font = [UIFont systemFontOfSize: 14.0 weight:UIFontWeightSemibold];
        }
        // 低版本系统上用图片作为按钮背景
        else {
            // 设置按钮背景
            [cancelAudioButton setBackgroundImage:[UIImage imageNamed:@"btn_style_alert_dialog_button_normal2"] forState:UIControlStateNormal];
            [cancelAudioButton setBackgroundImage:[UIImage imageNamed:@"btn_style_alert_dialog_button_pressed"] forState:UIControlStateHighlighted];
            // 文字颜色
            [cancelAudioButton setTitleColor:HexColor(0x222222) forState:UIControlStateNormal];
            [cancelAudioButton setTitleColor:RGBACOLOR(34, 34, 34, 128) forState:UIControlStateHighlighted];
            // 字号
            cancelAudioButton.titleLabel.font = [UIFont systemFontOfSize: 14.0];
        }
        [cancelAudioButton setTitle:(self.cancelButtonText == nil?@"取消录制":self.cancelButtonText) forState:UIControlStateNormal];
        // 点击事件处理
        [cancelAudioButton addTarget:self action:@selector(cancelAction:) forControlEvents:UIControlEventTouchUpInside];
        [viewMainRecording addSubview:cancelAudioButton];

        // 录音音量动画图片组件
        CGFloat meterImageViewWidth = 38;
        CGFloat meterImageViewHeight = 49;//56;
        meterImageView = [[IQVoiceMeterView alloc] initWithFrame:CGRectMake((mainViewWidth - meterImageViewWidth)/2, CGRectGetMinY(sendAudioButton.frame)+15, meterImageViewWidth, meterImageViewHeight)];
        meterImageView.image = [UIImage imageNamed:@"record_animate_01"];
        meterImageView.contentMode = UIViewContentModeCenter;
        [viewMainRecording addSubview:meterImageView];

        // “点击发送”显示标签
        CGSize sendHintLabelSize = CGSizeMake(100, 16);
        CGRect sendHintLabelFrame = CGRectMake((mainViewWidth-sendHintLabelSize.width)/2
                                       , CGRectGetMaxY(meterImageView.frame)+5
                                       , sendHintLabelSize.width
                                       , sendHintLabelSize.height);
        UILabel *sendHintLabel = [[UILabel alloc] initWithFrame:sendHintLabelFrame];
        sendHintLabel.textAlignment = NSTextAlignmentCenter;
        sendHintLabel.textColor = (self.sendButtonTextColor==nil?HexColor(0xffffff):self.sendButtonTextColor);
        sendHintLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
        sendHintLabel.text = (self.sendButtonText == nil? @"点击发送": self.sendButtonText);
        [viewMainRecording addSubview:sendHintLabel];
    }

    // 当没有录音权限时，要显示的提示内容
    {
        viewMicrophoneDenied = [[IQMessageDisplayView alloc] initWithFrame:self.view.bounds];
        viewMicrophoneDenied.translatesAutoresizingMaskIntoConstraints = NO;
        viewMicrophoneDenied.delegate = self;
        viewMicrophoneDenied.alpha = 0.0;
        viewMicrophoneDenied.tintColor = HexColor(0xFF3300);//RGBACOLOR(255, 0, 0, 255);//UI_DEFAULT_HILIGHT_COLOR;//[UIColor darkGrayColor];

        viewMicrophoneDenied.image = [[UIImage imageNamed:@"microphone_access" inBundle:[NSBundle bundleForClass:self.class] compatibleWithTraitCollection:nil] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        viewMicrophoneDenied.title = @"无法录音!";
        viewMicrophoneDenied.message = @"请在iPhone的\"设置-隐私-麦克风\"选项中，允许精聊Chat访问你的手机麦克风。";
        viewMicrophoneDenied.buttonTitle = @"点此手动设置";

        [self.view addSubview:viewMicrophoneDenied];
        [viewMicrophoneDenied mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(self.view);
            make.centerY.equalTo(self.view);
            make.width.equalTo(self.view).with.offset(-20);
        }];
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self startUpdatingMeter];

    // 保存锁屏设定开关
    _wasIdleTimerDisabled = [[UIApplication sharedApplication] isIdleTimerDisabled];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActiveNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [self validateMicrophoneAccess];
    
    if (_isFirstTime)
    {
        _isFirstTime = NO;

        // 开始录音
        [self recordingButtonAction:nil];
    }
}

//- (void)viewDidAppear:(BOOL)animated
//{
//    [super viewDidAppear:animated];
//
//    // 等UI显示后再启动录音，体验好一些，不然会瞬间卡住一下下，因为启动录音需要时间
//    if (_isFirstTime)
//    {
//        _isFirstTime = NO;
//
//        // 开始录音
//        [self recordingButtonAction:nil];
//    }
//}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];

    _audioRecorder.delegate = nil;
    [_audioRecorder stop];
    _audioRecorder = nil;
    
    [self stopUpdatingMeter];
    
    [UIApplication sharedApplication].idleTimerDisabled = _wasIdleTimerDisabled;
}


#pragma mark - 光圈旋转动画

- (void)startRotateImageAnimation
{
    CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    // 旋转角度
    rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0 ];
    // 旋转一周的时间（单位：秒）
    rotationAnimation.duration = 3;
    // 旋转累加角度
    rotationAnimation.cumulative = YES;
    // 旋转次数
    rotationAnimation.repeatCount = ULLONG_MAX;

    [rotateBgImageView.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
}

-(void)stopRotateImageAnimation
{
    [rotateBgImageView.layer removeAllAnimations];
}


#pragma mark - Update Meters

- (void)updateMeters
{
    if (_audioRecorder.isRecording)
    {
        [_audioRecorder updateMeters];

        float ff = [_audioRecorder averagePowerForChannel:0];
//        CGFloat normalizedValue = pow (10,  ff/ 20);

        CGFloat progress = //(1.0/160)*(ff + 160);
        meterImageView.progress = (ff + 160);//progress;

//        float fakePower = (float)(1+arc4random()%99)/100;

//        NSLog(@"KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK ff=%f, progress=%f, (ff + 160)=%f", ff, progress, (ff + 160));

        // 刷新录制时间显示
        progressLabel.text = [NSString timeStringForTimeInterval:_audioRecorder.currentTime];
    }
    else
    {
        meterImageView.progress = 0;
    }
}

-(void)startUpdatingMeter
{
    [self meterUpdateTimer];
}

-(void)stopUpdatingMeter
{
    [[self meterUpdateTimer] invalidate];
    _meterUpdateTimer  = nil;
}


#pragma mark - Audio Record

- (void)recordingButtonAction:(UIBarButtonItem *)item
{
    /*
     录音对象配置
     */
    if ([[NSFileManager defaultManager] fileExistsAtPath:_recordingFilePath])
        [[NSFileManager defaultManager] removeItemAtPath:_recordingFilePath error:nil];
    _oldSessionCategory = [AVAudioSession sharedInstance].category;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
    // 不锁屏
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [_audioRecorder prepareToRecord];
    // 开始录音
    if (self.maximumRecordDuration <=0)
        [_audioRecorder record];
    else
        [_audioRecorder recordForDuration:self.maximumRecordDuration];

    /*
     启动光圈旋转动画
     */
    [self startRotateImageAnimation];
}


#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    // 停止光圈旋转动画
    [self stopRotateImageAnimation];
    // 停止音量的闪动
    [self stopUpdatingMeter];

    if (flag)
    {
        // 延迟恢复音频会话，避免恢复瞬间系统可能产生的提示音被误认为“叮”声；同时避免与 delegate 回调、dismiss 重叠
        NSString *savedCategory = _oldSessionCategory;
        BOOL savedIdleTimer = _wasIdleTimerDisabled;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (savedCategory != nil && savedCategory.length > 0)
                [[AVAudioSession sharedInstance] setCategory:savedCategory error:nil];
            [UIApplication sharedApplication].idleTimerDisabled = savedIdleTimer;
        });
    }
    else
    {
        [[NSFileManager defaultManager] removeItemAtPath:_recordingFilePath error:nil];
    }
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
    //    NSLog(@"%@: %@",NSStringFromSelector(_cmd),error);
}


#pragma mark - Cancel or Done

/// 按下“发送”按钮时立即停止录音，避免松手时的点击声被录入
-(void)doneButtonTouchDown:(id)sender
{
    if (_audioRecorder && _audioRecorder.isRecording) {
        [_audioRecorder stop];
    }
}

-(void)cancelAction:(UIBarButtonItem*)item
{
    // 先停止录音
    [_audioRecorder stop];

    // 再删除临时文件
    [[NSFileManager defaultManager] removeItemAtPath:_recordingFilePath error:nil];
    // 更新录制时间显示
    progressLabel.text = [NSString timeStringForTimeInterval:_audioRecorder.currentTime];

    // 并通知代理对象
    if ([self.delegate respondsToSelector:@selector(audioRecorderControllerDidCancel:)])
        [self.delegate audioRecorderControllerDidCancel:self];
    else
        [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)doneAction:(UIBarButtonItem*)item
{
    // 先尝试停止录音
    [_audioRecorder stop];

    // 再通知代理对象
    if ([self.delegate respondsToSelector:@selector(audioRecorderController:didFinishWithAudioAtPath:)])
        [self.delegate audioRecorderController:self didFinishWithAudioAtPath:_recordingFilePath];
    else
        [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - Message Display View

// 打开APP在iPhone的权限设置界面
-(void)messageDisplayViewDidTapOnButton:(IQMessageDisplayView *)displayView
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}


#pragma mark - Private helper

-(void)updateUI
{

}

- (void)validateMicrophoneAccess
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    [session requestRecordPermission:^(BOOL granted) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            viewMicrophoneDenied.alpha = !granted;
            viewMainRecording.alpha = granted;
        });
    }];
}

-(void)didBecomeActiveNotification:(NSNotification*)notification
{
    [self validateMicrophoneAccess];
}

- (NSTimer *)meterUpdateTimer
{
    if (!_meterUpdateTimer) {
        _meterUpdateTimer =[NSTimer scheduledTimerWithTimeInterval:0.1f
                                                            target:self
                                                          selector:@selector(updateMeters)
                                                          userInfo:nil
                                                           repeats:YES];
    }
    return _meterUpdateTimer;
}

//@end
//
//
//@implementation UIViewController (IQAudioRecorderViewController)

//- (void)presentAudioRecorderViewControllerAnimated:(nonnull IQAudioRecorderViewController *)audioRecorderViewController
//{
////    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:audioRecorderViewController];
////
////    navigationController.toolbarHidden = NO;
////    navigationController.toolbar.translucent = YES;
////
////    navigationController.navigationBar.translucent = YES;
////
////    // This line is used to refresh UI of Audio Recorder View Controller
////    [self presentViewController:navigationController animated:NO completion:^{
////    }];
//}

//- (void)presentBlurredAudioRecorderViewControllerAnimated:(nonnull IQAudioRecorderViewController *)audioRecorderViewController
//{
//    // 20180613 by JS，说明：以下使用新的UINavigationController的方式来 presentViewController
//    // ，会导致语音留言界面的显示延迟很大（这个迟延差不多有1秒，太夸张了!），影响用户体验！
//
//    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:audioRecorderViewController];
//
//    navigationController.toolbarHidden = NO;
//    navigationController.toolbar.translucent = YES;
//    [navigationController.toolbar setBackgroundImage:[UIImage new] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
//    [navigationController.toolbar setShadowImage:[UIImage new] forToolbarPosition:UIBarPositionAny];
//
//    navigationController.navigationBar.translucent = YES;
//    [navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
//    [navigationController.navigationBar setShadowImage:[UIImage new]];
//
//    navigationController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
//    navigationController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;//UIModalTransitionStyleCoverVertical;//UIModalTransitionStyleCrossDissolve;
//
//    //This line is used to refresh UI of Audio Recorder View Controller
//    [self presentViewController:navigationController animated:YES completion:nil];
//}


#pragma mark - 其它静态实用方法

// amr转换方法（将本类中录制的原始音频，转换成amr格式并存到指定路径处）
+ (NSString *)convertCAFtoAMR:(NSString *)originalAudioFilePath toDir:(NSString *)destAMRFileDir
{
    NSData *data = [NSData dataWithContentsOfFile:originalAudioFilePath];
    return  EncodeWAVEToAMR(data,1,16, destAMRFileDir);
}

// 进入语音录制界面
+ (void)presentBlurredAudioRecorderViewControllerAnimated2:(UIViewController *)parent delegate:(id<IQAudioRecorderViewControllerDelegate>)delegate maxDuration:(NSTimeInterval)maxDuration sendButtonText:(NSString *)sendButtonText cancelButtonText:(NSString *)cancelButtonText sendButtonImage:(UIImage *)sendButtonImage sendButtonImageHighlight:(UIImage *)sendButtonImageHighlight sendButtonTextColor:(UIColor *)sendButtonTextColor
{
    // 提示音（注意：提示音的播放因为涉及硬件的调用，会让语音留言录音界面的跳转多一些延迟，影响用户体验！）
    //    [[PromtHelper sharedInstance] audioRecordingPromt];

    //## 以下代码行是20180614前的方式，它会导致录音界面打开卡顿一秒以上（主要是presentViewController:方法的及其配合代码导致的)
    //    [self presentBlurredAudioRecorderViewControllerAnimated:controller];

    //## 以下代码行是20180614后的方式，解决录音界面打开卡卡顿的问题
    // 强制在主线程中执行，解决众所周之的 presentViewController 导致的界面延迟显示问题
    dispatch_async(dispatch_get_main_queue(), ^{

        IQAudioRecorderViewController *controller = [[IQAudioRecorderViewController alloc] init];
        controller.delegate = delegate;
        controller.audioFormat = IQAudioFormat_caf;
        controller.maximumRecordDuration = maxDuration;//LOCAL_VOICE_AUDIO_LENGTH;
        controller.sampleRate = 8000.0;
        controller.numberOfChannels = 1;
        controller.bitRate = 16;
        controller.sendButtonText = sendButtonText;
        controller.cancelButtonText = cancelButtonText;
        controller.sendButtonImage = sendButtonImage;
        controller.sendButtonImageHighlight = sendButtonImageHighlight;
        controller.sendButtonTextColor = sendButtonTextColor;

        // modalPresentationStyle设置为 UIModalPresentationOverFullScreen 可使其实现半透明效果
        controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
        // 转动画
        controller.modalTransitionStyle = UIModalTransitionStyleCoverVertical;//UIModalTransitionStyleFlipHorizontal;
        // 显示语音留言录制界面（使用本界面的"self presentViewController:"而不使用"self presentBlurredAudioRecorderViewControllerAnimated:"方法
        // 可解决之前录音界面显示多达1秒以上的延迟问题，那样的延迟对用户体验影响太大了！之前怀疑是因为开启录音对象导致的，实际Instrument表明此耗时只有几毫秒，根本不是它影响）
        [parent presentViewController:controller animated:YES completion:nil];
    });
}

@end
