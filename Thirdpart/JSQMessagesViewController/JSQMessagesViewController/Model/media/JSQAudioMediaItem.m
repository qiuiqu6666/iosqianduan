//telegram @wz662

#import "JSQAudioMediaItem.h"

#import "JSQMessagesMediaPlaceholderView.h"
#import "JSQMessagesMediaViewBubbleImageMasker.h"

#import "UIImage+JSQMessages.h"
#import "UIColor+JSQMessages.h"

#import "Utils.h"
#import "SendVoiceHelper.h"
#import "BasicTool.h"
#include "amrFileCodec.h"
#import "FileDownloadHelper.h"
#import "JSQMessagesBubbleImage.h"
#import "JSQMessagesBubbleImageFactory.h"
#import "PromtHelper.h"
#import "FileTool.h"
#import "TimeTool.h"
#import <Speech/Speech.h>

NSString * const RBVoiceTranscriptDidUpdateNotification = @"RBVoiceTranscriptDidUpdateNotification";

// 其它MediaItem发过来的“停止播放”通知key（用此通知来保证聊天界面中一次只有一个
// 语音在播放，降低代码偶合、防止内存泄漏风险，这是目前想到最好的办法）。
// * 【当前保证一次只播放一个音频的原理是】：
// *  (1)播放时加上通知观察者；
// *  (2)播放完成时去掉观察者(保证添加了观察者的item永远只有当前正在播放中的item
//       ，不会应Item变动时因观察者太多而消耗性能)；
// *  (3)当用户播放其它音频时由其它item发出通知（那么本item就能收到通知并关闭当前
//       播放，同时去掉当前item的观察者，现在被点击的那个item开始下一次逻辑）。
#define kNotificationCenter_For_stopPlayRequest @"__kNotificationCenter_For_stopPlayRequest__"

// 播放动画UIImageView的宽高
#define kPlayeImageWidthAndHeight 28

// 语音气泡宽度：最短、最长、每秒增加宽度（与微信类似）
static const CGFloat kAudioBubbleMinWidth = 140.0f;
static const CGFloat kAudioBubbleMaxWidth = 360.0f;
static const CGFloat kAudioBubbleWidthPerSecond = 6.0f;

// 语音气泡高度：与单行文本气泡一致（单行 = lineHeight + 8+8+2 ≈ 38）
static const CGFloat kAudioBubbleHeightSameAsText = 56.0f;

// 衬距（上、左、下、右），使 上+播放图高度+下 = kAudioBubbleHeightSameAsText，保证气泡完整
const UIEdgeInsets controlInsets = {8, 12, 8, 16};


@interface JSQAudioMediaItem ()
// 整个ui父容器View
@property (strong, nonatomic) UIView *cachedMediaView;
@property (strong, nonatomic) UIButton *rb_playButton;
@property (strong, nonatomic) UIView *rb_waveformView;
@property (strong, nonatomic) NSMutableArray<UIView *> *rb_waveBars;
@property (strong, nonatomic) UILabel *rb_progressTextLabel;

// 下载进度条（如果需要下载时才会显示）
@property (strong, nonatomic) UIProgressView *progressView;
// 音频时长
@property (strong, nonatomic) UILabel *progressLabel;

@property (strong, nonatomic) AVAudioPlayer *audioPlayer;

// 加载的音频数据（不播放的时候本对象为nil，播放时才加载并设置，播放完成立即置nil，释放资源）
@property (nonatomic, strong, nullable) NSData *audioData2;

// 此条语音留言消息对应的音频文件名（此文件可能缓存于本地、也可能在服务端）
@property (strong, nonatomic) NSString *audioFileName;

@property (nonatomic, assign) BOOL rb_paused;
@property (nonatomic, strong) NSTimer *rb_progressTimer;
@property (nonatomic, assign) NSTimeInterval rb_totalDurationHint;

@property (nonatomic, copy) NSString *rb_transcriptText;
@property (nonatomic, strong) UILabel *rb_transcriptLabel;
@property (nonatomic, assign) BOOL rb_transcribing;
@property (nonatomic, strong) SFSpeechRecognitionTask *rb_speechTask;
@property (nonatomic, strong) SFSpeechRecognizer *rb_speechRecognizer;

@end


@implementation JSQAudioMediaItem

#pragma mark - Initialization

- (instancetype)initWithData:(NSString *)audioFileName
{
    self = [super init];
    if (self) {
        _cachedMediaView = nil;
        _audioFileName = audioFileName;
    }
    return self;
}

- (void)dealloc
{
    _audioData2 = nil;
    _audioFileName = nil;

    [self clearCachedMediaViews];
}

- (void)clearCachedMediaViews
{
    [self stopAudio];
    [self rb_stopSpeech];

    _rb_playButton = nil;
    _rb_waveformView = nil;
    _rb_waveBars = nil;
    _rb_progressTextLabel = nil;
    _rb_transcriptLabel = nil;
    _progressView = nil;
    _progressLabel = nil;
    _cachedMediaView = nil;

    [super clearCachedMediaViews];
}

- (UIImage *)rb_symbolImageNamed:(NSString *)name pointSize:(CGFloat)pt
{
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:pt weight:UIImageSymbolWeightSemibold];
        return [UIImage systemImageNamed:name withConfiguration:cfg];
    }
    return nil;
}

- (NSString *)rb_mmssForSeconds:(NSTimeInterval)sec
{
    NSInteger s = (NSInteger)lrint(MAX(0.0, sec));
    NSInteger m = s / 60;
    NSInteger r = s % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)m, (long)r];
}

- (void)rb_updateWaveformProgress:(double)progress
{
    if (self.rb_waveBars.count == 0) return;
    progress = MAX(0.0, MIN(1.0, progress));
    NSInteger played = (NSInteger)lrint(progress * (double)self.rb_waveBars.count);
    UIColor *active = [UIColor colorWithRed:(0x2F/255.0f) green:(0x80/255.0f) blue:(0xED/255.0f) alpha:1.0f];
    UIColor *inactive = [UIColor colorWithRed:(0x2F/255.0f) green:(0x80/255.0f) blue:(0xED/255.0f) alpha:0.28f];
    for (NSInteger i = 0; i < (NSInteger)self.rb_waveBars.count; i++) {
        UIView *bar = self.rb_waveBars[i];
        bar.backgroundColor = (i < played) ? active : inactive;
    }
}

- (void)rb_updateAudioUI
{
    BOOL playing = [self isPlaying];
    BOOL paused = [self isPaused];
    BOOL canSymbol = (@available(iOS 13.0, *));
    if (self.rb_playButton) {
        UIImage *img = nil;
        if (canSymbol) {
            img = [self rb_symbolImageNamed:(playing ? @"pause.fill" : @"play.fill") pointSize:16.0f];
        }
        [self.rb_playButton setImage:img forState:UIControlStateNormal];
        self.rb_playButton.hidden = (img == nil);
    }
    NSTimeInterval total = self.audioPlayer ? self.audioPlayer.duration : self.rb_totalDurationHint;
    if (total < 0.5) total = 0;
    NSTimeInterval cur = 0;
    if (self.audioPlayer) {
        cur = self.audioPlayer.currentTime;
        if (total < 0.5) total = self.audioPlayer.duration;
    }
    if (self.rb_progressTextLabel) {
        self.rb_progressTextLabel.text = [NSString stringWithFormat:@"%@/%@",
                                          [self rb_mmssForSeconds:cur],
                                          [self rb_mmssForSeconds:total]];
    }
    double p = (total > 0.01) ? (cur / total) : 0.0;
    if (!playing && !paused) p = 0.0;
    [self rb_updateWaveformProgress:p];
    if (self.rb_transcriptLabel) {
        if (self.rb_transcribing) {
            self.rb_transcriptLabel.text = @"转写中…";
        } else {
            self.rb_transcriptLabel.text = self.rb_transcriptText ?: @"";
        }
    }
}

- (void)rb_startProgressTimer
{
    [self rb_stopProgressTimer];
    self.rb_progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(rb_onProgressTimer) userInfo:nil repeats:YES];
}

- (void)rb_stopProgressTimer
{
    if (self.rb_progressTimer) {
        [self.rb_progressTimer invalidate];
        self.rb_progressTimer = nil;
    }
}

- (void)rb_onProgressTimer
{
    [self rb_updateAudioUI];
}


#pragma mark - Setters

- (void)setAppliesMediaViewMaskAsOutgoing:(BOOL)appliesMediaViewMaskAsOutgoing
{
    [super setAppliesMediaViewMaskAsOutgoing:appliesMediaViewMaskAsOutgoing];
    _cachedMediaView = nil;
}


#pragma mark - Private

- (void)onPlayButton:(UIButton *)sender
{
//    NSLog(@"@@@@@@@@@@@@@@@@@@@!!!! _audioFileName=%@", self.audioFileName);

    if ([self isPlaying]) {
        [self pauseAudio];
        return;
    }
    if ([self isPaused]) {
        [self resumeAudio];
        return;
    }

        // 音频文件路径
        NSString *audioFilePath = [NSString stringWithFormat:@"%@%@", [SendVoiceHelper getSendVoiceSavedDirHasSlash], self.audioFileName];
        // 文件是否已存在于本地缓存中（方便无网时离线使用）
        BOOL exists = [FileTool fileExists:audioFilePath];

        DLogDebug(@"[音频准备] 要播放的音频文件路径：%@【是否已在本地？%d】", audioFilePath, exists);

        // 存在就直接播放
        if(exists)
        {
            // 本地文件直接播放
            @try{
                // 转码
                _audioData2 = DecodeAMRToWAVE([NSData dataWithContentsOfFile:audioFilePath]);
                // 开始播放
                [self playAudio];
            } @catch (NSException *exception){
                NSLog(@"%@",exception);
                _audioData2 = nil;
                AlertInfo(@"语音留言播放失败，可能是文件已失效！");
            }
        }
        // 文件不存在
        else
        {
//            // 自已发出的文件不存在了，那估计是被手机清除了
//            if(self.appliesMediaViewMaskAsOutgoing)
//            {
//                AlertInfo(@"播放失败，语音数据已失效或被移除！");
//                return;
//            }
//            // 如果是收到好友发过来的文件，则尝试从网络下载
//            else
            {
                
                // @since 8.0：本地发出的消息，有可能来自收到的消息的转发，转发的当然就不存在本地缓存，所以需要加上这个url以备从网络
                // 加载。所以为了达成这一可能，目前发出的（没有转发功能以前只读本地缓存文件）和收到的消息，如果本地不存在都可以从网络加载
                
                // 显示进度条
                if(self.progressView != nil)
                    self.progressView.hidden = NO;

//                NSString *fileDownloadURL = [SendVoiceHelper getVoiceDownloadURL:self.audioFileName dump:YES];
                // dump字段使用NO比较合理，这样在群聊以及后面将要实现的消息转发情况下，就不至于被1个人读后就被dump掉而导致后面的人无法下载了
                NSString *fileDownloadURL = [SendVoiceHelper getVoiceDownloadURL:self.audioFileName dump:NO];
                
                DLogDebug(@"[音频准备] 马上下载要播放的音频文件，下载地址：%@", fileDownloadURL);
                
                // 从服务器下载
                [FileDownloadHelper downloadCommonFile:fileDownloadURL
                    toDir:[SendVoiceHelper getSendVoiceSavedDir]
                    pg:^(NSProgress *dp) {
                        float pv = 1.0 * dp.completedUnitCount / dp.totalUnitCount;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if(self.progressView != nil)
                                self.progressView.progress = pv;
                        });
                } complete:^(BOOL sucess, NSURL *fileSavedPath) {

                    NSLog(@"sucess=%d, fileSavedPath=%@", sucess, [fileSavedPath path]);

                    if(sucess)
                    {
                        if(self.progressView != nil)
                            self.progressView.progress = 1.0;

                        // 下载完成后直接播放
                        @try{
                            // 转码
                            _audioData2 = DecodeAMRToWAVE([NSData dataWithContentsOfFile:[fileSavedPath path]]);
                            // 开始播放
                            [self playAudio];
                        } @catch (NSException *exception){
                            NSLog(@"%@",exception);
                            _audioData2 = nil;
                            AlertInfo(@"语音留言播放失败（网络下载完成后）！");
                        }
                    }
                    else
                    {
                        AlertInfo(@"语音留言文件下载失败！");
                        return;
                    }

                    if(self.progressView != nil)
                    {
                        // 隐藏进度条
                        self.progressView.hidden = YES;
                    }
                }];
            }
        }
}


#pragma mark - JSQMessageMediaData protocol

- (CGSize)mediaViewDisplaySize
{
    int duration = 1;
    if (self.audioFileName.length > 0) {
        duration = [TimeTool getDurationFromVoiceFileName:self.audioFileName];
        if (duration <= 0) duration = 1;
    }
    CGFloat width = kAudioBubbleMinWidth + (CGFloat)duration * kAudioBubbleWidthPerSecond;
    width = MIN(kAudioBubbleMaxWidth, MAX(kAudioBubbleMinWidth, width));
    CGFloat bubbleH = kAudioBubbleHeightSameAsText;
    CGFloat height = bubbleH;
    NSString *t = nil;
    if (self.rb_transcribing) {
        t = @"转写中…";
    } else if (self.rb_transcriptText.length > 0) {
        t = self.rb_transcriptText;
    }
    if (t.length > 0) {
        CGFloat transcriptBubbleW = MIN(width, MAX(160.0f, width - 30.0f));
        CGFloat textW = MAX(40.0f, transcriptBubbleW - 24.0f);
        UIFont *font = [UIFont systemFontOfSize:15.0f];
        CGRect r = [t boundingRectWithSize:CGSizeMake(textW, 1000.0f)
                                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                attributes:@{NSFontAttributeName: font}
                                   context:nil];
        CGFloat maxH = font.lineHeight * 3.0f;
        CGFloat th = MIN(maxH, ceil(r.size.height));
        height += (6.0f + 10.0f + th + 10.0f);
    }
    return CGSizeMake(width, height);
}

- (UIView *)mediaView
{
    if (self.audioFileName != nil && self.cachedMediaView == nil)
    {
        BOOL isOutgoing = self.appliesMediaViewMaskAsOutgoing;

        CGFloat leftInset = 12.0f;
        CGFloat rightInset = 12.0f;
        CGFloat bubbleH = kAudioBubbleHeightSameAsText;
        
        // create container view for the various controls
        CGSize mainSize = [self mediaViewDisplaySize];
        UIView * playView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, mainSize.width, mainSize.height)];
        playView.backgroundColor = [UIColor clearColor];
        playView.contentMode = UIViewContentModeCenter;
        playView.clipsToBounds = YES;

        // 气泡背景底图：使用与文本一致、尾巴朝下的气泡图
        UIImageView *bubbleImageBgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, mainSize.width, bubbleH)];
        bubbleImageBgView.contentMode = UIViewContentModeScaleToFill;
        bubbleImageBgView.userInteractionEnabled = YES;
        // 与文本气泡一致：背景图 view 再做一次垂直翻转，保持尾巴位置完全对齐
        bubbleImageBgView.transform = CGAffineTransformMakeScale(1.0, -1.0);
        JSQMessagesBubbleImageFactory *bubbleImageFactory = [[JSQMessagesBubbleImageFactory alloc] init];
        JSQMessagesBubbleImage *bubbleImageData = isOutgoing
            ? [bubbleImageFactory outgoingMessagesBubbleImage_wechatGreen]
            : [bubbleImageFactory incomingMessagesBubbleImage_white];
        bubbleImageBgView.image = bubbleImageData.messageBubbleImage;
        bubbleImageBgView.highlightedImage = bubbleImageData.messageBubbleHighlightedImage;

        [playView addSubview:bubbleImageBgView];
        [bubbleImageBgView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onPlayButton:)]];

        // 从文件名解析时长（用于时长文案）
        int duration = [TimeTool getDurationFromVoiceFileName:self.audioFileName];
        if (duration <= 0) duration = 1;
        self.rb_totalDurationHint = (NSTimeInterval)duration;

        CGFloat btnSize = 40.0f;
        CGFloat btnX = leftInset;
        CGFloat btnY = (bubbleH - btnSize) / 2.0f;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(btnX, btnY, btnSize, btnSize);
        btn.layer.cornerRadius = btnSize * 0.5f;
        btn.clipsToBounds = YES;
        btn.backgroundColor = [UIColor colorWithRed:(0x2F/255.0f) green:(0x80/255.0f) blue:(0xED/255.0f) alpha:1.0f];
        btn.tintColor = [UIColor whiteColor];
        [btn addTarget:self action:@selector(onPlayButton:) forControlEvents:UIControlEventTouchUpInside];
        [playView addSubview:btn];
        self.rb_playButton = btn;

        CGFloat waveX = CGRectGetMaxX(btn.frame) + 10.0f;
        CGFloat waveW = MAX(0.0f, mainSize.width - waveX - rightInset);
        CGFloat waveH = 18.0f;
        CGFloat ptH = 14.0f;
        CGFloat vGap = 4.0f;
        CGFloat contentH = waveH + vGap + ptH;
        CGFloat baseY = (bubbleH - contentH) / 2.0f;
        if (baseY < 8.0f) baseY = 8.0f;
        CGFloat waveY = baseY;
        UIView *wave = [[UIView alloc] initWithFrame:CGRectMake(waveX, waveY, waveW, waveH)];
        wave.backgroundColor = [UIColor clearColor];
        [playView addSubview:wave];
        self.rb_waveformView = wave;
        self.rb_waveBars = [NSMutableArray array];
        NSInteger bars = 24;
        if (waveW > 10.0f) {
            bars = (NSInteger)floor(waveW / 6.0f);
            if (bars < 18) bars = 18;
            if (bars > 48) bars = 48;
        }
        CGFloat gap = 2.0f;
        CGFloat barW = floor((waveW - gap * (bars - 1)) / (CGFloat)bars);
        if (barW < 1.0f) barW = 1.0f;
        NSArray<NSNumber *> *pattern = @[@4,@7,@10,@6,@12,@8,@14,@9,@11,@7,@15,@8,@12,@6,@11,@7,@13,@7,@10,@6,@9,@5,@8,@5];
        for (NSInteger i = 0; i < bars; i++) {
            CGFloat h = (CGFloat)(pattern[i % pattern.count].doubleValue);
            if (h > waveH) h = waveH;
            CGFloat x = (barW + gap) * i;
            UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(x, waveH - h, barW, h)];
            bar.layer.cornerRadius = 1.0f;
            bar.clipsToBounds = YES;
            [wave addSubview:bar];
            [self.rb_waveBars addObject:bar];
        }
        
        CGFloat ptY = waveY + waveH + vGap;
        UILabel *pt = [[UILabel alloc] initWithFrame:CGRectMake(waveX, ptY, waveW, ptH)];
        pt.font = [UIFont systemFontOfSize:12.0f];
        pt.textColor = [UIColor colorWithRed:(0x2F/255.0f) green:(0x80/255.0f) blue:(0xED/255.0f) alpha:1.0f];
        pt.textAlignment = NSTextAlignmentLeft;
        [playView addSubview:pt];
        self.rb_progressTextLabel = pt;

        // 下载进度条（只在从网络加载收到的语音留言消息时显示并使用）
        if(!isOutgoing)
        {
            CGFloat controlPadding = 6;
            self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
            CGFloat xOffset = waveX;
            CGFloat width = MAX(0.0f, waveW);
            self.progressView.frame = CGRectMake(xOffset, (bubbleH - self.progressView.frame.size.height) / 2,
                                                 width, self.progressView.frame.size.height);
            self.progressView.tintColor = UI_DEFAULT_BIGFILE_PROGRESS_FORGROUND_LIGHT_GREEN_COLOR;//[UIColor jsq_messageBubbleBlueColor];
            self.progressView.hidden = YES;// 默认是不可见的
            [playView addSubview:self.progressView];
        }

        NSString *transcriptDisplay = self.rb_transcribing ? @"转写中…" : (self.rb_transcriptText ?: @"");
        if (transcriptDisplay.length > 0) {
            CGFloat gapY = 6.0f;
            CGFloat transcriptBubbleW = MIN(mainSize.width, MAX(160.0f, mainSize.width - 30.0f));
            CGFloat transcriptX = isOutgoing ? (mainSize.width - transcriptBubbleW) : 0.0f;
            CGFloat maxTextW = MAX(40.0f, transcriptBubbleW - 24.0f);
            UIFont *tf = [UIFont systemFontOfSize:15.0f];
            CGRect r = [transcriptDisplay boundingRectWithSize:CGSizeMake(maxTextW, 1000.0f)
                                                      options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                                   attributes:@{NSFontAttributeName: tf}
                                                      context:nil];
            CGFloat maxH = tf.lineHeight * 3.0f;
            CGFloat textH = MIN(maxH, ceil(r.size.height));
            CGFloat bubbleY = bubbleH + gapY;
            CGFloat bubbleH2 = 10.0f + textH + 10.0f;

            UIView *tb = [[UIView alloc] initWithFrame:CGRectMake(transcriptX, bubbleY, transcriptBubbleW, bubbleH2)];
            tb.backgroundColor = [UIColor whiteColor];
            tb.layer.cornerRadius = 10.0f;
            tb.layer.borderWidth = 1.0f / [UIScreen mainScreen].scale;
            tb.layer.borderColor = [UIColor colorWithWhite:0 alpha:0.08].CGColor;
            tb.clipsToBounds = YES;
            [playView addSubview:tb];

            UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(12.0f, 10.0f, transcriptBubbleW - 24.0f, textH)];
            tl.font = tf;
            tl.textColor = [UIColor blackColor];
            tl.numberOfLines = 3;
            tl.textAlignment = NSTextAlignmentLeft;
            tl.text = transcriptDisplay;
            [tb addSubview:tl];
            self.rb_transcriptLabel = tl;
        }

        self.cachedMediaView = playView;
        [self rb_updateAudioUI];
    }

    return self.cachedMediaView;
}

- (NSUInteger)mediaHash
{
    return self.hash;
}

- (NSUInteger)hash
{
    return super.hash;// ^ self.audioData.hash;
}

- (void)rb_stopSpeech
{
    if (self.rb_speechTask) {
        [self.rb_speechTask cancel];
        self.rb_speechTask = nil;
    }
}

- (void)rb_invalidateMediaLayoutCache
{
    self.cachedMediaView = nil;
    self.rb_playButton = nil;
    self.rb_waveformView = nil;
    self.rb_waveBars = nil;
    self.rb_progressTextLabel = nil;
    self.rb_transcriptLabel = nil;
    self.progressView = nil;
    self.progressLabel = nil;
}

- (void)requestVoiceToText
{
    if (self.rb_transcribing) {
        return;
    }
    self.rb_transcribing = YES;
    [self rb_invalidateMediaLayoutCache];
    [self rb_updateAudioUI];
    [[NSNotificationCenter defaultCenter] postNotificationName:RBVoiceTranscriptDidUpdateNotification object:self];

    __weak typeof(self) wself = self;
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        if (status != SFSpeechRecognizerAuthorizationStatusAuthorized) {
            dispatch_async(dispatch_get_main_queue(), ^{
                sself.rb_transcribing = NO;
                sself.rb_transcriptText = @"未授权语音识别";
                [sself rb_invalidateMediaLayoutCache];
                [sself rb_updateAudioUI];
                [[NSNotificationCenter defaultCenter] postNotificationName:RBVoiceTranscriptDidUpdateNotification object:sself];
            });
            return;
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong typeof(wself) gself = wself;
            if (!gself) return;

            NSString *audioFilePath = [NSString stringWithFormat:@"%@%@", [SendVoiceHelper getSendVoiceSavedDirHasSlash], gself.audioFileName ?: @""];
            if (![FileTool fileExists:audioFilePath]) {
                NSString *fileDownloadURL = [SendVoiceHelper getVoiceDownloadURL:gself.audioFileName dump:NO];
                [FileDownloadHelper downloadCommonFile:fileDownloadURL toDir:[SendVoiceHelper getSendVoiceSavedDir] pg:nil complete:^(BOOL ok, NSURL *fileSavedPath) {
                    if (!ok || fileSavedPath == nil) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong typeof(wself) s2 = wself;
                            if (!s2) return;
                            s2.rb_transcribing = NO;
                            s2.rb_transcriptText = @"语音下载失败";
                            [s2 rb_invalidateMediaLayoutCache];
                            [s2 rb_updateAudioUI];
                            [[NSNotificationCenter defaultCenter] postNotificationName:RBVoiceTranscriptDidUpdateNotification object:s2];
                        });
                        return;
                    }
                    [gself rb_transcribeLocalAudioFileAtPath:[fileSavedPath path]];
                }];
                return;
            }

            [gself rb_transcribeLocalAudioFileAtPath:audioFilePath];
        });
    }];
}

- (void)rb_transcribeLocalAudioFileAtPath:(NSString *)audioFilePath
{
    NSData *amrData = [NSData dataWithContentsOfFile:audioFilePath];
    if (amrData.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.rb_transcribing = NO;
            self.rb_transcriptText = @"语音文件为空";
            [self rb_invalidateMediaLayoutCache];
            [self rb_updateAudioUI];
            [[NSNotificationCenter defaultCenter] postNotificationName:RBVoiceTranscriptDidUpdateNotification object:self];
        });
        return;
    }
    NSData *wavData = DecodeAMRToWAVE(amrData);
    if (wavData.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.rb_transcribing = NO;
            self.rb_transcriptText = @"语音格式不支持";
            [self rb_invalidateMediaLayoutCache];
            [self rb_updateAudioUI];
            [[NSNotificationCenter defaultCenter] postNotificationName:RBVoiceTranscriptDidUpdateNotification object:self];
        });
        return;
    }

    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"rb_stt_%@.wav", self.audioFileName ?: @"voice"]];
    [wavData writeToFile:tmp atomically:YES];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self rb_stopSpeech];
        if (self.rb_speechRecognizer == nil) {
            self.rb_speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"zh-CN"]];
        }
        NSURL *u = [NSURL fileURLWithPath:tmp];
        SFSpeechURLRecognitionRequest *req = [[SFSpeechURLRecognitionRequest alloc] initWithURL:u];
        req.shouldReportPartialResults = NO;
        __weak typeof(self) wself = self;
        self.rb_speechTask = [self.rb_speechRecognizer recognitionTaskWithRequest:req resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
            __strong typeof(wself) sself = wself;
            if (!sself) return;
            if (error) {
                sself.rb_transcribing = NO;
                sself.rb_transcriptText = @"转写失败";
                [sself rb_invalidateMediaLayoutCache];
                [sself rb_updateAudioUI];
                [[NSNotificationCenter defaultCenter] postNotificationName:RBVoiceTranscriptDidUpdateNotification object:sself];
                sself.rb_speechTask = nil;
                return;
            }
            if (result && result.isFinal) {
                sself.rb_transcribing = NO;
                sself.rb_transcriptText = result.bestTranscription.formattedString ?: @"";
                [sself rb_invalidateMediaLayoutCache];
                [sself rb_updateAudioUI];
                [[NSNotificationCenter defaultCenter] postNotificationName:RBVoiceTranscriptDidUpdateNotification object:sself];
                sself.rb_speechTask = nil;
            }
        }];
    });
}


#pragma mark - 音频播放相关方法

- (void)playAudio
{
    if (self.cachedMediaView != nil && self.audioData2 != nil)
    {
        [self stopAudio];

        // 基本播放配置
        NSError *error = nil;
        [[AVAudioSession sharedInstance] setCategory:@"AVAudioSessionCategoryPlayback"
                                         withOptions:AVAudioSessionCategoryOptionDuckOthers
                                                     |AVAudioSessionCategoryOptionDefaultToSpeaker
                                                     |AVAudioSessionCategoryOptionAllowBluetooth
                                               error:&error];

        [JSQAudioMediaItem stopPlayRequestNotificatin_POST:[NSString stringWithFormat:@"%lu", [self hash]]];
        [self stopPlayRequestNotificatin_ADD];

        // 重新起一个
        self.audioPlayer = [[AVAudioPlayer alloc] initWithData:self.audioData2 error:nil];
        self.audioPlayer.delegate = self;

        // 开始播放音频
        [self.audioPlayer play];
        self.rb_paused = NO;

        [self rb_startProgressTimer];
        [self rb_updateAudioUI];
    }
}

- (void)pauseAudio
{
    if (_audioPlayer == nil) {
        return;
    }
    if ([_audioPlayer isPlaying]) {
        [_audioPlayer pause];
        self.rb_paused = YES;
        [self rb_stopProgressTimer];
        [self rb_updateAudioUI];
    }
}

- (void)resumeAudio
{
    if (_audioPlayer == nil) {
        return;
    }
    if (self.rb_paused) {
        [_audioPlayer play];
        self.rb_paused = NO;
        [self rb_startProgressTimer];
        [self rb_updateAudioUI];
    }
}

- (void)stopAudio
{
    if(_audioPlayer != nil)
    {
        [self stopPlayRequestNotificatin_REMOVE];
        self.rb_paused = NO;

        [_audioPlayer stop];
        _audioPlayer = nil;
        _audioData2 = nil;
    }

    [self rb_stopProgressTimer];
    [self rb_updateAudioUI];
}

- (void)stopAudioforNotitication:(NSNotification *)nf
{
    NSString *hashForSourceItem = (NSString *)nf.object;

    NSLog(@"[语音播放] [!收到]收到来自其它item的通知！（当前hash=%lu, 来自源hash=%@）", [self mediaHash], hashForSourceItem);

    // 释放本次的播放资源
    [self stopAudio];
}

- (BOOL)isPlaying
{
    return self.audioPlayer != nil && [self.audioPlayer isPlaying];
}

- (BOOL)isPaused
{
    return self.audioPlayer != nil && ![self.audioPlayer isPlaying] && self.rb_paused;
}


#pragma mark - AVAudioPlayerDelegate（音频播放完成的回调通知）

// 音频正常播放完成后的回调
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    // 音频播放完成时移除观察者
    [self stopPlayRequestNotificatin_REMOVE];

    // 停止播放并释放资源
    [self stopAudio];

    // 播放完成后，显式置空播放数据，没有必要占用内存
    _audioData2 = nil;

    // 已关闭播放结束提示音，避免叮声打扰
    // [[PromtHelper sharedInstance] audioPlayEndPromt];
}

// 音频播放出错时的回调
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    NSLog(@"[语音播放] 【NO】播放音频文件%@时出错了，原因:%@", self.audioFileName, error);
}


#pragma mark - NSNotificationCenter通知相关方法

// 注册通知：接收其它MediaItem发过来的“停止播放”通知（用此通知来保证聊天界面中一次只有一个语音在播放，降低代码偶合、防止内存泄漏风险，这是目前想到最好的办法）
- (void)stopPlayRequestNotificatin_ADD
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopAudioforNotitication:)
                                                 name:kNotificationCenter_For_stopPlayRequest
                                               object:nil];

    NSLog(@"[语音播放] 【ADD\"停止播放\"通知】（当前itemhash=%lu）", [self mediaHash]);
}
// 取消注册通知：接收其它MediaItem发过来的“停止播放”通知
- (void)stopPlayRequestNotificatin_REMOVE
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationCenter_For_stopPlayRequest object:nil];

    NSLog(@"[语音播放] 【REMOVE\"停止播放\"通知】当前itemhash=%lu）", [self mediaHash]);
}
// 发出通知：接收其它MediaItem发过来的“停止播放”通知
// * 在聊天界面处于当前界面时：用此通知来保证聊天界面中一次只有一个语音在播放；
// * 在聊天界面马上要不可见时：如果存在正在播放中的语音消息，则通知其停止播放（不然在后台还会播放的罗）。
+ (void)stopPlayRequestNotificatin_POST:(NSString *)itemHashForDebug
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCenter_For_stopPlayRequest object:itemHashForDebug];
}

@end
