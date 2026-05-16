//telegram @wz662
//
//  ShortVideoPlayViewController.m
//  AVFoundationTest
//
//  Created by Jack Jiang on 2019/10/19.
//  Copyright © 2019 wqb. All rights reserved.
//

#import "ShortVideoPlayViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "HWVideoProgress.h"
#import "BasicTool.h"
#import "Default.h"
#import "FileTool.h"
#import "FileDownloadHelper.h"
#import "ReceivedShortVideoHelper.h"


@interface ShortVideoPlayViewController () <UIGestureRecognizerDelegate>

/** 视频来源 */
@property (nonatomic, assign) VideoDataType mVideoDataType;
/**
 * 视频数据源地址：
 * <p>
 * 1）当来自VideoDataType.FILE_PATH时，开发者传入的本字段值为视频文件的本地绝对路径；
 * 2）当来自VideoDataType.FILE_URL时，开发者传入的本字段值为视频文件的网络下载URL。
 */
@property (nonatomic, retain) NSString *mVideoDataSrc;
/** 下载的视频的保存目录（如果mVideoDataType == VideoDataType.URL时本字段才有意义）*/
@property (nonatomic, retain) NSString *mSavedDir;
// 本字段保存的是视频的文件本地绝对路径（当视频文件来自网络时，本字段将在文件下载成功完成后被设置，否则初始化时就会被设置）
@property (nonatomic, copy) NSString *mVideoFileSavedPath;
// 视频时长(单位：秒)
@property (nonatomic, assign) NSInteger mVideoDurationTime;
// 视频文件名（用于下载时指定文件名）
@property (nonatomic, retain) NSString *mVideoFileName;
// 视频文件MD5（用于下载后校验）
@property (nonatomic, retain) NSString *mVideoFileMd5;

// 短视频播放器的封装类
@property (nonatomic, retain) VideoPlayWrapper *videoPlayWrapper;
// 当没有视频或视频载入时的ui显示包装类
@property (nonatomic, retain) NoVideoWrapper *noVideoWrapper;

@property (nonatomic, retain) NSURLSessionDownloadTask *downloadTask__;

/** 本会话短视频列表（仅 initWithVideoArray 路径非空） */
@property (nonatomic, copy) NSArray<NSDictionary *> *rb_videoPlaylist;
@property (nonatomic, assign) NSInteger rb_playlistIndex;
@property (nonatomic, copy) NSArray<UISwipeGestureRecognizer *> *rb_playlistSwipeRecognizers;
@property (nonatomic, retain) UILabel *rb_playlistPageLabel;

/** 轻微上下滑退出全屏播放 */
@property (nonatomic, retain) UIPanGestureRecognizer *rb_verticalDismissPan;

@end

@implementation ShortVideoPlayViewController

# pragma mark 主要方法

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil duaration:(int)durationWithSecond videoDataType:(VideoDataType)videoDataType videoDataSrc:(NSString *)videoDataSrc savedDir:(NSString *)savedDir
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.mVideoDurationTime = durationWithSecond;
        
        self.mVideoDataType = videoDataType;
        self.mVideoDataSrc = videoDataSrc;
        self.mSavedDir = savedDir;
    }
    return self;
}

// 初始化方法（支持多个视频的左右滑动切换）
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil videoDataArray:(NSArray<NSDictionary *> *)videoDataArray currentIndex:(NSInteger)currentIndex savedDir:(NSString *)savedDir
{
    if (videoDataArray == nil || videoDataArray.count == 0) {
        DDLogError(@"【视频播放】videoDataArray为空，无法初始化");
        return nil;
    }
    
    NSInteger idx = currentIndex;
    if (idx < 0 || idx >= (NSInteger)videoDataArray.count) {
        idx = 0;
    }
    
    NSDictionary *videoData = [videoDataArray objectAtIndex:(NSUInteger)idx];
    if (videoData == nil) {
        DDLogError(@"【视频播放】videoData为空，无法初始化");
        return nil;
    }
    
    int duration = [[videoData objectForKey:@"duration"] intValue];
    VideoDataType videoType = [[videoData objectForKey:@"videoType"] intValue];
    NSString *videoDataSrc = [videoData objectForKey:@"videoDataSrc"];
    
    if (videoDataSrc == nil || videoDataSrc.length == 0) {
        DDLogError(@"【视频播放】videoDataSrc为空，无法初始化");
        return nil;
    }
    
    if (duration <= 0) {
        DDLogError(@"【视频播放】duration无效（%d），无法初始化", duration);
        return nil;
    }
    
    self = [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil duaration:duration videoDataType:videoType videoDataSrc:videoDataSrc savedDir:savedDir];
    if (self) {
        _rb_videoPlaylist = [videoDataArray copy];
        _rb_playlistIndex = idx;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 初始化播放相关的UI等逻辑
    [self initPlayUILogic];
    [self rb_attachSeekPanGestureDelegateIfNeeded];
    [self rb_setupPlaylistPagingIfNeeded];
    [self rb_setupVerticalDismissPan];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // 隐藏导导航栏
    [self hideNavigation];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // 取消隐藏导导航栏
    [self showNavigation];
}

- (void)dealloc
{
    [self.videoPlayWrapper removeObserversAndNotification];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // 1 表示播放中，0 表示暂停播放
//  if (self.player.rate == 1)
    if([self.videoPlayWrapper isPlaying])
       [self.videoPlayWrapper doPause];
    
    // 对于下载中的任务，要即时退出
    if(self.downloadTask__ != nil)
        [self.downloadTask__ cancel];
}

- (void)initPlayUILogic
{
    //** 视频播放的UI和功能逻辑初始化
    ShortVideoPlayCompletionBlock playCompletetion = ^(BOOL withError) {
        if(withError)
            [self shitHintForException:@"视频播放出错，请稍后再试！"];
        else{
            // 在此可以实现视频播放完成后该做的事。。
        }
    };
    self.videoPlayWrapper = [[VideoPlayWrapper alloc] initWith:self.player_viewVideo btnPlay:self.player_btnPlay progressPlaying:self.player_progressPlaying lbCurrentVideoTime:self.player_lbCurrentVideoTime lbTotalVideoTime:self.player_lbTotalVideoTime videoDuration:self.mVideoDurationTime withCompletion:playCompletetion];
    [self.videoPlayWrapper initGUI];
//    [self.videoPlayWrapper initPlay];
    
    //** 视频加载时的UI和功能逻辑初始化
    self.noVideoWrapper = [[NoVideoWrapper alloc] initWith:self.player_layoutVideoView layoutOfNoVideo:self.noVideo_layoutOfNoVideo viewIcon:self.noVideo_viewIcon progressForDownload:self.noVideo_progressForDownload viewHint:self.noVideo_viewHint];
    
    // 针对ios 26的优化：不需要单独的背景色液态玻璃效果更好
    if (@available(iOS 26, *)) {
    } else {
        [self.player_btnClose setBackgroundColor:RGBACOLOR(255,255,255, 26)];
//        [self.btnCameraSwitch setBackgroundColor:RGBACOLOR(255,255,255, 26)];
        
        [self.player_btnPlay setBackgroundImage:[UIImage imageNamed:@"common_short_video_player_continue_play_ico_bg_nor_ios26"] forState:UIControlStateNormal];
        [self.player_btnPlay setBackgroundImage:[UIImage imageNamed:@"common_short_video_player_continue_play_ico_bg_pressed_ios26"] forState:UIControlStateHighlighted];
    }
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:self.player_btnClose];
    [BasicTool setClearGlassBgnConfig:self.player_btnPlay];
    
    //** 关键参数检查与按当前条目加载（含列表切换复用）
    [self rb_reloadVideoFromCurrentPlaylistItem];
}

/// 根据 self.mVideoDataType / mVideoDataSrc 等加载或播放当前条目（可与列表滑动切换共用）。
- (void)rb_reloadVideoFromCurrentPlaylistItem
{
    //** 关键参数检查
    if(self.mVideoDataSrc == nil || self.mVideoDataSrc.length == 0)
    {
       [self shitHintForException:@"参数错误，无法播放！"];
       return;
    }
    
    //** 根据不同的视频数据来源，决定视频数据该如何加载
    switch (self.mVideoDataType)
    {
        // 视频来自本地文件（直接播放）
        case VideoDataType_FILE_PATH:
        {
            self.mVideoFileSavedPath = self.mVideoDataSrc;
            
            // 检查文件是否存在
            if(self.mVideoFileSavedPath == nil || self.mVideoFileSavedPath.length == 0)
            {
                [self shitHintForException:@"视频文件路径无效，无法播放！"];
                return;
            }
            
            if(![FileTool fileExists:self.mVideoFileSavedPath])
            {
                [self shitHintForException:@"视频文件不存在，无法播放！"];
                return;
            }
            
            // 检查文件大小，确保文件有效
            long long fileSize = [FileTool fileSizeAtPath:self.mVideoFileSavedPath];
            if(fileSize <= 0)
            {
                [self shitHintForException:@"视频文件无效或已损坏，无法播放！"];
                return;
            }
            
            // 直接开始播放
            [self.videoPlayWrapper initPlay:self.mVideoFileSavedPath];
            [self rb_attachSeekPanGestureDelegateIfNeeded];
            [self playVideoFromFile];
            break;
        }
        // 视频来自远程网络文件（先下载后，再播放）
        case VideoDataType_URL:
        {
            // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
            __weak typeof(self) safeSelf = self;
            
            NSLog(@"【查看视频界面】马上开始从网络加载视频%@。。。。", self.mVideoDataSrc);
            
            // 显示进度提示
            [self.noVideoWrapper setVisible:YES progressVisible:YES];
            [self.noVideoWrapper setIcon:@"null_pic"];
            [self.noVideoWrapper setText:@"视频加载中 ..."];
            
            // 判断mVideoDataSrc是否是旧的构建URL（包含ShortVideoDownloader），如果是则需要先获取video_url
            NSString *fileDownloadURL = self.mVideoDataSrc;
            if(fileDownloadURL != nil && [fileDownloadURL containsString:@"ShortVideoDownloader"])
            {
                // 这是旧的构建URL，需要先调用接口获取video_url
                // 从URL中提取file_name和file_md5
                NSURLComponents *components = [NSURLComponents componentsWithString:fileDownloadURL];
                NSString *fileName = nil;
                NSString *fileMd5 = nil;
                
                for(NSURLQueryItem *item in components.queryItems)
                {
                    if([item.name isEqualToString:@"file_name"])
                    {
                        fileName = item.value;
                    }
                    else if([item.name isEqualToString:@"file_md5"])
                    {
                        fileMd5 = item.value;
                    }
                }
                
                if(fileName != nil && fileMd5 != nil)
                {
                    // 保存文件名和MD5，用于下载和校验
                    safeSelf.mVideoFileName = fileName;
                    safeSelf.mVideoFileMd5 = fileMd5;
                    
                    // 调用新方法获取video_url
                    [ReceivedShortVideoHelper getShortVideoDownloadURLAsync:fileName md5:fileMd5 complete:^(NSString *video_url) {
                        // 确保在主线程执行UI操作
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if(video_url != nil && video_url.length > 0)
                            {
                                // 获取到video_url，开始下载
                                [safeSelf downloadVideoWithURL:video_url fileName:fileName fileMd5:fileMd5];
                            }
                            else
                            {
                                [safeSelf shitHintForException:@"获取视频下载地址失败，请稍后重试！"];
                            }
                        });
                    }];
                    return; // 等待异步回调
                }
                else
                {
                    [self shitHintForException:@"视频参数无效，无法获取下载地址！"];
                    return;
                }
            }
            else
            {
                // 直接是video_url，可以直接下载
                // 注意：如果是直接传入video_url，可能没有fileName和fileMd5信息
                // 这种情况下，我们尝试从mVideoDataSrc中提取，或者使用默认处理
                [self downloadVideoWithURL:fileDownloadURL fileName:nil fileMd5:nil];
            }
            break;
        }
        default:
        {
            [self shitHintForException:@"不支持的视频数据来源类型！"];
            break;
        }
    }
}

- (void)rb_setupPlaylistPagingIfNeeded
{
    if (self.rb_videoPlaylist == nil || self.rb_videoPlaylist.count < 2) {
        return;
    }
    
    UILabel *lab = [[UILabel alloc] init];
    lab.translatesAutoresizingMaskIntoConstraints = NO;
    lab.textColor = [UIColor whiteColor];
    lab.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    lab.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];
    lab.layer.cornerRadius = 10;
    lab.layer.masksToBounds = YES;
    lab.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:lab];
    self.rb_playlistPageLabel = lab;
    
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [lab.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [lab.topAnchor constraintEqualToAnchor:guide.topAnchor constant:12],
        [lab.heightAnchor constraintEqualToConstant:28],
        [lab.widthAnchor constraintGreaterThanOrEqualToConstant:56],
    ]];
    
    UISwipeGestureRecognizer *swLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(rb_playlistSwipeNext:)];
    swLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    UISwipeGestureRecognizer *swRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(rb_playlistSwipePrev:)];
    swRight.direction = UISwipeGestureRecognizerDirectionRight;
    
    [self.player_viewVideo addGestureRecognizer:swLeft];
    [self.player_viewVideo addGestureRecognizer:swRight];
    self.rb_playlistSwipeRecognizers = @[ swLeft, swRight ];
    
    [self rb_updatePlaylistPageLabel];
    [self.videoPlayWrapper rb_requirePlaylistSwipeGesturesToFailBeforeSeekPan:self.rb_playlistSwipeRecognizers];
}

- (void)rb_setupVerticalDismissPan
{
    if (self.rb_verticalDismissPan != nil || self.player_viewVideo == nil) {
        return;
    }
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rb_handleVerticalDismissPan:)];
    pan.maximumNumberOfTouches = 1;
    pan.delegate = self;
    [self.player_viewVideo addGestureRecognizer:pan];
    self.rb_verticalDismissPan = pan;
}

- (void)rb_attachSeekPanGestureDelegateIfNeeded
{
    UIPanGestureRecognizer *seek = [self.videoPlayWrapper rb_seekPanGestureRecognizer];
    if (seek != nil) {
        seek.delegate = self;
    }
}

- (void)rb_handleVerticalDismissPan:(UIPanGestureRecognizer *)pan
{
    if (pan.state != UIGestureRecognizerStateEnded && pan.state != UIGestureRecognizerStateCancelled) {
        return;
    }
    CGPoint t = [pan translationInView:self.player_viewVideo];
    CGPoint v = [pan velocityInView:self.player_viewVideo];
    CGFloat ax = fabs(t.x);
    CGFloat ay = fabs(t.y);
    CGFloat vy = fabs(v.y);
    // 轻微上下滑即可退出：位移略大于水平分量，或纵向甩动速度足够
    BOOL verticalIntent = ay > ax + 6.0;
    BOOL farEnough = ay > 36.0 && verticalIntent;
    BOOL flick = vy > 320.0 && verticalIntent;
    if (farEnough || flick) {
        [self btnCloseOnClick:nil];
    }
}

#pragma mark - UIGestureRecognizerDelegate（纵向退出 vs 横向 seek 分流）

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    UIPanGestureRecognizer *dismissPan = self.rb_verticalDismissPan;
    UIPanGestureRecognizer *seekPan = [self.videoPlayWrapper rb_seekPanGestureRecognizer];
    UIView *ref = self.player_viewVideo;
    if (ref == nil) {
        return YES;
    }
    if (gestureRecognizer == dismissPan) {
        CGPoint tr = [(UIPanGestureRecognizer *)gestureRecognizer translationInView:ref];
        return fabs(tr.y) > fabs(tr.x) + 8.0;
    }
    if (seekPan != nil && gestureRecognizer == seekPan) {
        CGPoint tr = [(UIPanGestureRecognizer *)gestureRecognizer translationInView:ref];
        return fabs(tr.x) >= fabs(tr.y) + 8.0;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return NO;
}

- (void)rb_updatePlaylistPageLabel
{
    if (self.rb_playlistPageLabel == nil || self.rb_videoPlaylist == nil) {
        return;
    }
    self.rb_playlistPageLabel.text = [NSString stringWithFormat:@"%ld / %lu", (long)(self.rb_playlistIndex + 1), (unsigned long)self.rb_videoPlaylist.count];
    [self.view bringSubviewToFront:self.rb_playlistPageLabel];
}

- (void)rb_playlistSwipeNext:(UISwipeGestureRecognizer *)g
{
    if (self.rb_videoPlaylist == nil || self.rb_videoPlaylist.count < 2) {
        return;
    }
    NSInteger n = self.rb_playlistIndex + 1;
    if (n >= (NSInteger)self.rb_videoPlaylist.count) {
        return;
    }
    [self rb_switchToPlaylistIndex:n];
}

- (void)rb_playlistSwipePrev:(UISwipeGestureRecognizer *)g
{
    if (self.rb_videoPlaylist == nil || self.rb_videoPlaylist.count < 2) {
        return;
    }
    NSInteger n = self.rb_playlistIndex - 1;
    if (n < 0) {
        return;
    }
    [self rb_switchToPlaylistIndex:n];
}

- (void)rb_switchToPlaylistIndex:(NSInteger)idx
{
    if (self.rb_videoPlaylist == nil || self.rb_videoPlaylist.count < 2) {
        return;
    }
    if (idx < 0 || idx >= (NSInteger)self.rb_videoPlaylist.count) {
        return;
    }
    if (idx == self.rb_playlistIndex) {
        return;
    }
    
    if (self.downloadTask__ != nil) {
        [self.downloadTask__ cancel];
        self.downloadTask__ = nil;
    }
    
    [self.videoPlayWrapper doPause];
    
    NSDictionary *videoData = self.rb_videoPlaylist[(NSUInteger)idx];
    NSString *src = [videoData objectForKey:@"videoDataSrc"];
    if (src == nil || src.length == 0) {
        [self shitHintForException:@"视频地址无效，无法切换！"];
        return;
    }
    NSInteger dur = [[videoData objectForKey:@"duration"] integerValue];
    if (dur <= 0) {
        dur = self.mVideoDurationTime;
    }
    
    self.rb_playlistIndex = idx;
    self.mVideoDurationTime = dur;
    self.mVideoDataType = (VideoDataType)[[videoData objectForKey:@"videoType"] intValue];
    self.mVideoDataSrc = src;
    self.mVideoFileSavedPath = nil;
    self.mVideoFileName = nil;
    self.mVideoFileMd5 = nil;
    
    [self.videoPlayWrapper rb_resetPlayerShellAndSeekUIForNewDeclaredDuration:self.mVideoDurationTime];
    [self rb_attachSeekPanGestureDelegateIfNeeded];
    [self rb_reloadVideoFromCurrentPlaylistItem];
    [self rb_updatePlaylistPageLabel];
    [self.videoPlayWrapper rb_requirePlaylistSwipeGesturesToFailBeforeSeekPan:self.rb_playlistSwipeRecognizers];
}

// 使用video_url下载视频文件的辅助方法
- (void)downloadVideoWithURL:(NSString *)fileDownloadURL fileName:(NSString *)fileName fileMd5:(NSString *)fileMd5
{
    if(fileDownloadURL == nil || fileDownloadURL.length == 0)
    {
        [self shitHintForException:@"视频下载地址无效，无法播放！"];
        return;
    }
    
    // 保存文件名和MD5（如果提供了）
    if(fileName != nil)
    {
        self.mVideoFileName = fileName;
    }
    if(fileMd5 != nil)
    {
        self.mVideoFileMd5 = fileMd5;
    }
    
    __weak typeof(self) safeSelf = self;
    
    // 从服务器下载视频文件
    self.downloadTask__ = [FileDownloadHelper downloadCommonFile:fileDownloadURL
                toDir:self.mSavedDir
                fileName:fileName
                pg:^(NSProgress *dp) {

                    dispatch_async(dispatch_get_main_queue(), ^{
                        // 下载进度：0~1.0f
                        float pv = 1.0 * dp.completedUnitCount / dp.totalUnitCount;
                        [safeSelf.noVideoWrapper setProgress:pv];
                });

            } complete:^(BOOL sucess, NSURL *fileSavedPath) {
                
                NSLog(@"【查看视频界面】从网络加载视频%@完成(保存位置: %@)！【成功了吗？%d】", safeSelf.mVideoDataSrc, [fileSavedPath path], sucess);

                if(sucess && fileSavedPath != nil)
                {
                    NSString *savedPath = [fileSavedPath path];
                    
                    // 检查文件路径是否有效
                    if(savedPath == nil || savedPath.length == 0)
                    {
                        [safeSelf shitHintForException:@"视频文件路径无效，无法播放！"];
                        return;
                    }
                    
                    // 检查文件是否存在
                    if(![FileTool fileExists:savedPath])
                    {
                        [safeSelf shitHintForException:@"视频文件不存在，无法播放！"];
                        return;
                    }
                    
                    [safeSelf.noVideoWrapper setProgress:1.0f];
                    
                    // 隐藏下载进度条
                    [safeSelf.noVideoWrapper setVisible:NO];
                    
                    // 将本次下载保存成后的路径暂存待播放时使用
                    safeSelf.mVideoFileSavedPath = savedPath;
                    
                    // 检查文件大小，确保下载的文件有效
                    long long fileSize = [FileTool fileSizeAtPath:savedPath];
                    if(fileSize <= 0)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [safeSelf shitHintForException:@"视频文件下载不完整或已损坏，无法播放！"];
                        });
                        return;
                    }
                    
                    // 如果提供了MD5，进行文件完整性校验
                    if(safeSelf.mVideoFileMd5 != nil && safeSelf.mVideoFileMd5.length > 0)
                    {
                        // 在后台线程计算MD5
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            NSString *calculatedMD5 = [FileTool getFileMD5WithPath:savedPath];
                            
                            if(calculatedMD5 == nil || calculatedMD5.length == 0)
                            {
                                // MD5计算失败
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [safeSelf shitHintForException:@"视频文件校验失败，无法播放！"];
                                });
                                return;
                            }
                            
                            // 比较MD5（不区分大小写）
                            if(![calculatedMD5.lowercaseString isEqualToString:safeSelf.mVideoFileMd5.lowercaseString])
                            {
                                // MD5不匹配，文件可能损坏
                                DDLogError(@"【视频下载】MD5校验失败！期望：%@，实际：%@", safeSelf.mVideoFileMd5, calculatedMD5);
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [safeSelf shitHintForException:@"视频文件校验失败，文件可能已损坏！"];
                                });
                                return;
                            }
                            
                            DDLogDebug(@"【视频下载】MD5校验成功：%@", calculatedMD5);
                            
                            // MD5校验通过，开始播放（确保在主线程执行）
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [safeSelf.videoPlayWrapper initPlay:safeSelf.mVideoFileSavedPath];
                                [safeSelf rb_attachSeekPanGestureDelegateIfNeeded];
                                [safeSelf playVideoFromFile];
                            });
                        });
                    }
                    else
                    {
                        // 没有提供MD5，跳过校验，直接播放
                        DDLogDebug(@"【视频下载】未提供MD5，跳过文件校验");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [safeSelf.videoPlayWrapper initPlay:safeSelf.mVideoFileSavedPath];
                            [safeSelf rb_attachSeekPanGestureDelegateIfNeeded];
                            [safeSelf playVideoFromFile];
                        });
                    }
                }
                else
                {
                    [safeSelf shitHintForException:@"视频已失效或被移除，载入失败"];
                    return;
                }
            }];
}


# pragma mark 其它方法

// 播放视频
- (void) playVideoFromFile
{
    // 检查videoPlayWrapper是否已初始化
    if(self.videoPlayWrapper == nil)
    {
        [self shitHintForException:@"视频播放器初始化失败，无法播放！"];
        return;
    }
    
    // 检查视频文件路径是否有效
    if(self.mVideoFileSavedPath == nil || self.mVideoFileSavedPath.length == 0)
    {
        [self shitHintForException:@"视频文件路径无效，无法播放！"];
        return;
    }
    
    // 再次检查文件是否存在（防止文件在下载后被删除）
    if(![FileTool fileExists:self.mVideoFileSavedPath])
    {
        [self shitHintForException:@"视频文件不存在，无法播放！"];
        return;
    }
    
    // 检查videoPlayWrapper是否成功初始化了播放器
    // 通过检查hasInitPlay__属性来判断（如果VideoPlayWrapper有该属性）
    // 或者通过检查player是否存在来判断
    // 这里我们通过调用doPlay，在doPlay内部会进行beforePlayingCheck检查
    
    self.player_layoutVideoView.hidden = NO;
    [self.noVideoWrapper setVisible:NO];

    [self.videoPlayWrapper doPlay];
}

// 显示异常信息
- (void) shitHintForException:(NSString *)msg
{
    [self.noVideoWrapper setVisible:YES progressVisible:NO];
    [self.noVideoWrapper setIcon:@"common_short_video_player_error_icon"];
    [self.noVideoWrapper setText:msg];
}

// 返回(关闭)按钮处理方法
- (IBAction)btnCloseOnClick:(id)sender
{
    if([self.videoPlayWrapper isPlaying])
        [self.videoPlayWrapper doStop];
    [self.navigationController popViewControllerAnimated:YES];
}

//-(void)hideNavigation
//{
//    [self.navigationController setNavigationBarHidden:YES animated:NO];
//}
//
//-(void)showNavigation
//{
//    [self.navigationController setNavigationBarHidden:NO animated:NO];
//}

@end



#pragma mark - VideoPlayWrapper UI封装

/**
 * 短视频播放器封装类。
 */
@interface VideoPlayWrapper ()

// 视频预览图层
@property (nonatomic, retain) UIView *viewVideo;
// 播放/暂停按钮
@property (nonatomic, retain) UIButton *btnPlay;
// 快退按钮
@property (nonatomic, retain) UIButton *btnRewind;
// 快进按钮
@property (nonatomic, retain) UIButton *btnForward;
// 播放进度
@property (nonatomic, retain) HWVideoProgress *progressPlaying;
// 视频当前播放时长
@property (nonatomic, retain) UILabel *lbCurrentVideoTime;
// 视频总时长
@property (nonatomic, retain) UILabel *lbTotalVideoTime;

// 短视频播放完成时额外要调用的block
@property (nonatomic, copy) ShortVideoPlayCompletionBlock mPlayCompletetion;

// 播放器对象
@property (nonatomic, retain) AVPlayer *player;
// 播放器内容对象
@property (nonatomic, retain) AVPlayerItem *playerItem;

// 要播放的视频绝对路径，本参数目前由调用 initPlay: 方法时传入
@property (nonatomic, copy) NSString *videoFilePath;

// 视频时长(单位：秒)
@property (nonatomic, assign) NSInteger time;

@property (nonatomic, retain) id playerTimeObserver__;
@property (nonatomic, assign) BOOL hasInitPlay__;

// 快进/快退相关
@property (nonatomic, retain) UIPanGestureRecognizer *seekGestureRecognizer;
@property (nonatomic, retain) UILabel *seekTimeLabel; // 显示快进/快退时间的标签
@property (nonatomic, assign) CGFloat seekStartX; // 手势开始时的X坐标
@property (nonatomic, assign) BOOL isSeeking; // 是否正在快进/快退

@end

@implementation VideoPlayWrapper

#pragma mark 主要方法

- (id)initWith:(UIView *)viewVideo btnPlay:(UIButton *)btnPlay progressPlaying:(HWVideoProgress *)progressPlaying lbCurrentVideoTime:(UILabel *)lbCurrentVideoTime lbTotalVideoTime:(UILabel *)lbTotalVideoTime videoDuration:(NSInteger)videoDuration withCompletion:(ShortVideoPlayCompletionBlock)playCompletetion
{
    if(self = [super init])
    {
        self.hasInitPlay__ = NO;
        
        self.viewVideo = viewVideo;
        self.btnPlay = btnPlay;
        self.progressPlaying = progressPlaying;
        self.lbCurrentVideoTime = lbCurrentVideoTime;
        self.lbTotalVideoTime = lbTotalVideoTime;
        
        self.mPlayCompletetion = playCompletetion;
        
//        self.path = videoPath;
        self.time = videoDuration;
    }
    return self;
}

- (void)initGUI
{
    // 初始化进度条颜色等
    [self.progressPlaying set:[[UIColor whiteColor] colorWithAlphaComponent:0.3f] progressColor:[UIColor whiteColor] cornerRadius:2.0f];
    // 实现点击空白处播放或暂停视频
    [BasicTool addFingerClick:self.viewVideo action:@selector(playBtnOnClick:) target:self];
    // 实现点击中央图标播放或暂停视频
    [self.btnPlay addTarget:self action:@selector(playBtnOnClick:) forControlEvents:UIControlEventTouchUpInside];
    
    // 添加快进/快退手势识别
    [self setupSeekGesture];

    // 添加快进/快退按钮（使用 iOS 原生 UIButton，基于 AVPlayer 快进/快退）
    [self setupSeekButtons];
}

- (void)initPlay:(NSString *)videoFilePath
{
    // 检查文件路径是否有效
    if(videoFilePath == nil || videoFilePath.length == 0)
    {
        NSLog(@"【短视频播放器】视频文件路径为空，无法初始化播放器！");
        [self playingFinishedWithError];
        return;
    }
    
    // 检查文件是否存在
    if(![FileTool fileExists:videoFilePath])
    {
        NSLog(@"【短视频播放器】视频文件不存在，无法初始化播放器！(filepath=%@)", videoFilePath);
        [self playingFinishedWithError];
        return;
    }
    
    // 检查文件大小，空文件或损坏文件可能导致崩溃
    long long fileSize = [FileTool fileSizeAtPath:videoFilePath];
    if(fileSize <= 0)
    {
        NSLog(@"【短视频播放器】视频文件大小为0或无效，无法初始化播放器！(filepath=%@, size=%lld)", videoFilePath, fileSize);
        [self playingFinishedWithError];
        return;
    }
    
    self.videoFilePath = videoFilePath;
    
    NSLog(@"【短视频播放器】正在准备播放，视频时长：%ld，文件路径：%@，文件大小：%lld", self.time, self.videoFilePath, fileSize);
    
    // 创建文件URL，确保路径有效
    NSURL *fileURL = [NSURL fileURLWithPath:self.videoFilePath];
    if(fileURL == nil)
    {
        NSLog(@"【短视频播放器】无法创建文件URL，文件路径可能无效！(filepath=%@)", self.videoFilePath);
        [self playingFinishedWithError];
        return;
    }
    
    if(self.hasInitPlay__)
    {
        [self removeObserversAndNotification];
        
        // 检查player是否已初始化
        if(self.player == nil)
        {
            NSLog(@"【短视频播放器】player未初始化，无法替换播放项！");
            [self playingFinishedWithError];
            return;
        }
        
        self.playerItem  = [AVPlayerItem playerItemWithURL:fileURL];
        if(self.playerItem == nil)
        {
            NSLog(@"【短视频播放器】无法创建AVPlayerItem，文件可能已损坏！(filepath=%@)", self.videoFilePath);
            [self playingFinishedWithError];
            return;
        }
        
        [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
        
        [self addObserversAndNotification];
        [self setupSeekGesture];
        [self setupSeekButtons];
    }
    else
    {
        self.playerItem = [AVPlayerItem playerItemWithURL:fileURL];
        if(self.playerItem == nil)
        {
            NSLog(@"【短视频播放器】无法创建AVPlayerItem，文件可能已损坏！(filepath=%@)", self.videoFilePath);
            [self playingFinishedWithError];
            return;
        }
        
        self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
        if(self.player == nil)
        {
            NSLog(@"【短视频播放器】无法创建AVPlayer，初始化失败！");
            // 清理已创建的playerItem
            self.playerItem = nil;
            [self playingFinishedWithError];
            return;
        }
        
        self.player.volume = 1.0f;
        
//        self.player.automaticallyWaitsToMinimizeStalling = NO;///!!!!!1!!!!
        
        // 检查viewVideo是否为nil
        if(self.viewVideo == nil)
        {
            NSLog(@"【短视频播放器】viewVideo为nil，无法创建播放器层！");
            self.player = nil;
            self.playerItem = nil;
            [self playingFinishedWithError];
            return;
        }
        
        //创建播放器层
        AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
        if(playerLayer == nil)
        {
            NSLog(@"【短视频播放器】无法创建AVPlayerLayer，初始化失败！");
            self.player = nil;
            self.playerItem = nil;
            [self playingFinishedWithError];
            return;
        }
        
        // 说明：此处使用主屏的全屏大小，而不是self.viewVideo.bounds，原因是 initPlay:将在viewDidLoad:中调用，而
        //      viewDidLoad:被系统调用时，AutoLayout还未启效，此时取到的self.viewVideo.bounds肯定不是自适应手机
        //      屏幕后的结果。而如果将initPlay:放到 viewDidAppare: 中时，会应ios系统调用 viewDidAppare: 的延迟（大约数十到数百毫秒）
        //      则使得视频的自动播放有一段灰屏而影响用户体验。所以，最终就使用了取整个窗口的大小作为视频大小。
        //      以上说明，针对的是直接播放本地视频的情况，而从网络加载的视频，因视频加载完成时整个界面早就加载完成，所以不存在上面说的情形。
        playerLayer.frame = [UIScreen mainScreen].bounds;//self.viewVideo.bounds;

        playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.viewVideo.layer addSublayer:playerLayer];
   
        [self addObserversAndNotification];
        
        self.hasInitPlay__ = YES;
    }
}

- (void)addObserversAndNotification
{
    [self addObserverToPlayer];
    [self addObserverToPlayerItem:self.playerItem];
    [self addNotification];
}

- (void)removeObserversAndNotification
{
    [self removeObserverToPlayer];
    [self removeObserverFromPlayerItem:self.playerItem];
    [self removeNotification];
    
    // 移除手势识别器
    if (self.seekGestureRecognizer != nil && self.viewVideo != nil) {
        [self.viewVideo removeGestureRecognizer:self.seekGestureRecognizer];
        self.seekGestureRecognizer = nil;
    }
    
    // 移除提示标签
    if (self.seekTimeLabel != nil) {
        [self.seekTimeLabel removeFromSuperview];
        self.seekTimeLabel = nil;
    }
    
    // 移除快进/快退按钮
    if (self.btnRewind != nil) {
        [self.btnRewind removeFromSuperview];
        self.btnRewind = nil;
    }
    if (self.btnForward != nil) {
        [self.btnForward removeFromSuperview];
        self.btnForward = nil;
    }
}

- (void)rb_resetPlayerShellAndSeekUIForNewDeclaredDuration:(NSInteger)seconds
{
    [self removeObserversAndNotification];
    
    if (self.player != nil) {
        [self.player pause];
        self.player = nil;
    }
    self.playerItem = nil;
    self.hasInitPlay__ = NO;
    self.videoFilePath = nil;
    self.time = seconds;
    
    if (self.lbTotalVideoTime != nil) {
        self.lbTotalVideoTime.text = [self strWithTime:seconds];
    }
    if (self.lbCurrentVideoTime != nil) {
        self.lbCurrentVideoTime.text = [self strWithTime:0];
    }
    if (self.progressPlaying != nil) {
        [self.progressPlaying setProgress:0 duration:0];
    }
    
    for (CALayer *sub in [self.viewVideo.layer.sublayers copy]) {
        if ([sub isKindOfClass:[AVPlayerLayer class]]) {
            [sub removeFromSuperlayer];
        }
    }
    
    [self setupSeekGesture];
    [self setupSeekButtons];
}

- (void)rb_requirePlaylistSwipeGesturesToFailBeforeSeekPan:(NSArray<UISwipeGestureRecognizer *> *)swipes
{
    if (self.seekGestureRecognizer == nil || swipes == nil || swipes.count == 0) {
        return;
    }
    for (UISwipeGestureRecognizer *g in swipes) {
        if (g != nil) {
            [self.seekGestureRecognizer requireGestureRecognizerToFail:g];
        }
    }
}

- (UIPanGestureRecognizer *)rb_seekPanGestureRecognizer
{
    return self.seekGestureRecognizer;
}

// 播放前的关键参数检查
- (BOOL)beforePlayingCheck
{
    BOOL checkSucess = NO;
    
    if(self.videoFilePath == nil)
        NSLog(@"【短视频播放器】[play]没有读取到视频文件信息，本次播放不能继续！(file=null)");
    else if(![FileTool fileExists:self.videoFilePath])
        NSLog(@"【短视频播放器】[play]视频文件不存在，本次播放不能继续！(filepath=%@)", self.videoFilePath);
    else if(self.player == nil)
        NSLog(@"【短视频播放器】[play]player居然=nil，它不是在initPlay里就实化好了吗？");
    else if(self.time <= 0)
        NSLog(@"【短视频播放器】[play]视频时长不正常(dudation=%ld)，视频无法播放哦！", self.time);
    else
        checkSucess = YES;
    
    return checkSucess;
}

// 开始播放视频
- (void)doPlay
{
    if(![self beforePlayingCheck])
    {
        [self playingFinishedWithError];
        return;
    }
    
    //更新界面（播放时隐藏所有控制按钮）
    self.btnPlay.hidden = YES;
    self.btnRewind.hidden = YES;
    self.btnForward.hidden = YES;
    
    self.lbTotalVideoTime.text = [self strWithTime:_time];
    [self.progressPlaying setProgress:0 duration:0];

    // 全新播放或从头开始播放
    if(self.player != nil && self.playerItem != nil)
    {
        [self.playerItem seekToTime:kCMTimeZero];
        [self.player play];
    }
    else
    {
        NSLog(@"【短视频播放器】player或playerItem为nil，无法播放！");
        [self playingFinishedWithError];
    }
}

// 恢复播放视频
- (void)doResume
{
    if(self.player != nil)
        [self.player play];
    else
    {
        [self playingFinishedWithError];
        return;
    }
    self.btnPlay.hidden = YES;
    self.btnRewind.hidden = YES;
    self.btnForward.hidden = YES;
}

// 暂停播放视频
- (void)doPause
{
    // 正在播放
    if(self.player != nil && [self isPlaying])
        [self.player pause];

    // 暂停时显示播放、快退、快进按钮
    self.btnPlay.hidden = NO;
    self.btnRewind.hidden = NO;
    self.btnForward.hidden = NO;
}

// 停止播放视频
- (void)doStop
{
    // 正在播放
    if(self.player != nil && self.playerItem != nil && [self isPlaying])
    {
        // AVPlayer没有真正的stop方法，回退到开始，然后pause就行了
        [self.playerItem seekToTime:kCMTimeZero];
        [self doPause];
    }
}

// 继续播放、暂停播放
- (void)playBtnOnClick:(UIButton *)btn
{
    // 播放暂停状态
//  if(self.player.rate == 0)
    if(![self isPlaying])
    {
        if([self isPlayedComplete])
            [self doPlay];
        else
            [self doResume];
    }
    // 播放中
    else if (self.player != nil && self.player.rate == 1)
        [self doPause];
}

- (BOOL)isPlaying
{
    if(self.player != nil)
    {
        if([[UIDevice currentDevice] systemVersion].intValue >= 10){
            return self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying;
        }else{
            return self.player.rate == 1;
        }
    }
    return NO;
}

- (BOOL)isPlayedComplete
{
    BOOL compelte = NO;
    
    if(self.player != nil && self.player.currentItem != nil)
    {
        CMTime currentTime = self.player.currentItem.currentTime;
        CMTime duration = self.player.currentItem.duration;
        
        // 检查时间是否有效
        if(CMTIME_IS_VALID(currentTime) && CMTIME_IS_VALID(duration) && CMTimeGetSeconds(duration) > 0)
        {
            //进度 当前时间/总时间
            CGFloat progress = CMTimeGetSeconds(currentTime) / CMTimeGetSeconds(duration);
            //播放百分比为1表示已经播放完毕
            if (progress >= 1.0f) {
                compelte = YES;
            }
        }
    }
    
    return compelte;
}


#pragma mark 各种播放通知

// 给播放器添加进度更新
- (void)addObserverToPlayer
{
    if(self.player == nil)
    {
        NSLog(@"【短视频播放器】player为nil，无法添加时间观察者！");
        return;
    }
    
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    //进度回调
    self.playerTimeObserver__ = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        
        // 当前已播放完成的时长（单位：秒）
        float current = CMTimeGetSeconds(time);
        if(current >= 0 && safeSelf != nil)
        {
            NSLog(@"【短视频播放器】当前已经播放 %.2f s.", current);
            if(safeSelf.lbCurrentVideoTime != nil)
            {
                safeSelf.lbCurrentVideoTime.text = [safeSelf strWithTime:(int)current];// interval:1.f];
            }
            
            if (current > 0 && safeSelf.progressPlaying != nil && safeSelf.time > 0)
            {
                [safeSelf.progressPlaying setProgress:(current / safeSelf.time) duration:1.f];
            }
        }
    }];
}

// 给AVPlayerItem添加监控
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    AVPlayerItem *playerItem = object;
    if(playerItem == nil)
    {
        return;
    }
    
    if ([keyPath isEqualToString:@"status"])
    {
        AVPlayerStatus status = [[change objectForKey:@"new"] intValue];
        if(status == AVPlayerStatusReadyToPlay)
        {
            CMTime duration = playerItem.duration;
            if(CMTIME_IS_VALID(duration))
            {
                NSLog(@"【短视频播放器】正在播放...，视频总长度:%.2f", CMTimeGetSeconds(duration));
            }
        }
        else if(status == AVPlayerStatusFailed)
        {
            NSLog(@"【短视频播放器】播放失败：%@", playerItem.error);
            [self playingFinishedWithError];
        }
    }
    else if ([keyPath isEqualToString:@"loadedTimeRanges"])
    {
        NSArray *array = playerItem.loadedTimeRanges;
        if(array != nil && array.count > 0)
        {
            //本次缓冲时间范围
            CMTimeRange timeRange = [array.firstObject CMTimeRangeValue];
            if(CMTIME_IS_VALID(timeRange.start) && CMTIME_IS_VALID(timeRange.duration))
            {
                float startSeconds = CMTimeGetSeconds(timeRange.start);
                float durationSeconds = CMTimeGetSeconds(timeRange.duration);
                //缓冲总长度
                NSTimeInterval totalBuffer = startSeconds + durationSeconds;
                NSLog(@"【短视频播放器】共缓冲：%.2f", totalBuffer);
            }
        }
    }
}

// 给AVPlayerItem添加监控
- (void)addObserverToPlayerItem:(AVPlayerItem *)playerItem
{
    if(playerItem == nil)
    {
        NSLog(@"【短视频播放器】playerItem为nil，无法添加观察者！");
        return;
    }
    
    //监控状态属性，注意AVPlayer也有一个status属性，通过监控它的status也可以获得播放状态
    [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    //监控网络加载情况属性
    [playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
}

// 添加播放器通知
- (void)addNotification
{
    if(self.player != nil)
    {
        //给AVPlayerItem添加播放完成通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playingFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
    }
}

- (void)removeObserverToPlayer
{
    if(self.player != nil)
        [self.player removeTimeObserver:self.playerTimeObserver__];
}

- (void)removeObserverFromPlayerItem:(AVPlayerItem *)playerItem
{
    if(playerItem == nil)
    {
        return;
    }
    
    @try {
        [playerItem removeObserver:self forKeyPath:@"status"];
        [playerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    }
    @catch (NSException *exception) {
        NSLog(@"【短视频播放器】移除观察者时出错：%@", exception);
    }
}

- (void)removeNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// 正常播放完成的通知
- (void)playingFinished:(NSNotification *)notification
{
    NSLog(@"【短视频播放器】视频正常播放完成.");
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.progressPlaying setProgress:1 duration:1.f]; // 播放完成时强制满进度
        self.btnPlay.hidden = NO;
        self.btnRewind.hidden = NO;
        self.btnForward.hidden = NO;
//    });
    
    if(self.mPlayCompletetion)
        self.mPlayCompletetion(NO);
}

- (void)playingFinishedWithError
{
    NSLog(@"【短视频播放器】视频播放任务完成，原因是出错了.");
    
    if(self.mPlayCompletetion)
        self.mPlayCompletetion(YES);
}


#pragma mark 其它方法

// 时长长度转时间字符串
- (NSString *)strWithTime:(double)time
{
    int minute = time / 60;
    int second = (int)time % 60;
    
    return [NSString stringWithFormat:@"%02d:%02d", minute, second];
}

#pragma mark - 快进/快退功能

// 设置快进/快退按钮（显式按钮）
- (void)setupSeekButtons
{
    if (self.viewVideo == nil || self.btnPlay == nil) {
        return;
    }

    // 延迟创建按钮，确保布局已完成
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf == nil || weakSelf.viewVideo == nil || weakSelf.btnPlay == nil) {
            return;
        }
        
        // 获取 btnPlay 的父视图（应该是 player_layoutVideoView）
        UIView *parentView = weakSelf.btnPlay.superview;
        if (parentView == nil) {
            // 如果找不到父视图，使用 viewVideo
            parentView = weakSelf.viewVideo;
        }
        
        // 参考样式：中间暂停大、两侧快进/快退小，银灰半透明、带光泽感
        CGFloat buttonSize = 54.0f;  // 两侧按钮稍大，便于点击
        CGFloat spacing = 100.0f;     // 与中间播放按钮的水平间距
        
        // 将 btnPlay 的 center 坐标转换到 parentView 坐标系
        CGPoint center = [parentView convertPoint:weakSelf.btnPlay.center fromView:weakSelf.btnPlay.superview];
        
        // 统一：银灰半透明 + 轻微光泽（bubble）
        void (^applySeekButtonStyle)(UIButton *) = ^(UIButton *btn) {
            btn.layer.cornerRadius = buttonSize / 2.0f;
            btn.clipsToBounds = NO;
            btn.layer.masksToBounds = NO;
            // 银灰/浅灰半透明，透出背后视频
            btn.backgroundColor = [[UIColor colorWithWhite:0.4f alpha:1.0f] colorWithAlphaComponent:0.45f];
            btn.tintColor = [UIColor whiteColor];
            btn.layer.borderWidth = 0.5f;
            btn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5f].CGColor;
            // 轻微阴影营造气泡感
            btn.layer.shadowColor = [UIColor blackColor].CGColor;
            btn.layer.shadowOffset = CGSizeMake(0, 2);
            btn.layer.shadowRadius = 4;
            btn.layer.shadowOpacity = 0.35f;
        };
        
        // 快退按钮（15 秒）
        weakSelf.btnRewind = [UIButton buttonWithType:UIButtonTypeCustom];
        weakSelf.btnRewind.frame = CGRectMake(0, 0, buttonSize, buttonSize);
        weakSelf.btnRewind.center = CGPointMake(center.x - spacing, center.y);
        applySeekButtonStyle(weakSelf.btnRewind);
        
        if (@available(iOS 13.0, *)) {
            UIImage *rewindImage = [UIImage systemImageNamed:@"gobackward.15"];
            if (rewindImage) {
                [weakSelf.btnRewind setImage:rewindImage forState:UIControlStateNormal];
                weakSelf.btnRewind.imageView.contentMode = UIViewContentModeScaleAspectFit;
                weakSelf.btnRewind.imageEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
            } else {
                [weakSelf.btnRewind setTitle:@"-15" forState:UIControlStateNormal];
                weakSelf.btnRewind.titleLabel.font = [UIFont boldSystemFontOfSize:13.0f];
            }
        } else {
            [weakSelf.btnRewind setTitle:@"-15" forState:UIControlStateNormal];
            weakSelf.btnRewind.titleLabel.font = [UIFont boldSystemFontOfSize:13.0f];
        }
        [weakSelf.btnRewind addTarget:weakSelf action:@selector(onRewindTapped) forControlEvents:UIControlEventTouchUpInside];
        [parentView addSubview:weakSelf.btnRewind];
        
        // 快进按钮（15 秒）
        weakSelf.btnForward = [UIButton buttonWithType:UIButtonTypeCustom];
        weakSelf.btnForward.frame = CGRectMake(0, 0, buttonSize, buttonSize);
        weakSelf.btnForward.center = CGPointMake(center.x + spacing, center.y);
        applySeekButtonStyle(weakSelf.btnForward);
        
        if (@available(iOS 13.0, *)) {
            UIImage *forwardImage = [UIImage systemImageNamed:@"goforward.15"];
            if (forwardImage) {
                [weakSelf.btnForward setImage:forwardImage forState:UIControlStateNormal];
                weakSelf.btnForward.imageView.contentMode = UIViewContentModeScaleAspectFit;
                weakSelf.btnForward.imageEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
            } else {
                [weakSelf.btnForward setTitle:@"+15" forState:UIControlStateNormal];
                weakSelf.btnForward.titleLabel.font = [UIFont boldSystemFontOfSize:13.0f];
            }
        } else {
            [weakSelf.btnForward setTitle:@"+15" forState:UIControlStateNormal];
            weakSelf.btnForward.titleLabel.font = [UIFont boldSystemFontOfSize:13.0f];
        }
        [weakSelf.btnForward addTarget:weakSelf action:@selector(onForwardTapped) forControlEvents:UIControlEventTouchUpInside];
        [parentView addSubview:weakSelf.btnForward];
        
        // 默认隐藏，只有暂停时才与播放按钮一起显示
        weakSelf.btnRewind.hidden = YES;
        weakSelf.btnForward.hidden = YES;
        
        // 确保按钮在最上层
        [parentView bringSubviewToFront:weakSelf.btnRewind];
        [parentView bringSubviewToFront:weakSelf.btnForward];
        [parentView bringSubviewToFront:weakSelf.btnPlay];
    });
}

// 快退 15 秒
- (void)onRewindTapped
{
    [self seekBySeconds:-15];
}

// 快进 15 秒
- (void)onForwardTapped
{
    [self seekBySeconds:15];
}

// 按秒数快进/快退
- (void)seekBySeconds:(NSInteger)delta
{
    if (self.player == nil || self.playerItem == nil || self.time <= 0) {
        return;
    }

    CMTime currentTime = self.playerItem.currentTime;
    if (!CMTIME_IS_VALID(currentTime)) {
        currentTime = kCMTimeZero;
    }

    CGFloat currentSeconds = CMTimeGetSeconds(currentTime);
    if (currentSeconds < 0) {
        currentSeconds = 0;
    }

    CGFloat newSeconds = currentSeconds + delta;
    if (newSeconds < 0) {
        newSeconds = 0;
    } else if (newSeconds > self.time) {
        newSeconds = self.time;
    }

    CMTime seekTime = CMTimeMakeWithSeconds(newSeconds, NSEC_PER_SEC);
    [self.playerItem seekToTime:seekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];

    // 更新当前时间和进度 UI
    self.lbCurrentVideoTime.text = [self strWithTime:newSeconds];
    if (self.time > 0) {
        [self.progressPlaying setProgress:(newSeconds / self.time) duration:0];
    }
}

// 设置快进/快退手势
- (void)setupSeekGesture
{
    if (self.viewVideo == nil) {
        return;
    }
    
    // 创建滑动手势识别器（水平方向）
    self.seekGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSeekGesture:)];
    self.seekGestureRecognizer.minimumNumberOfTouches = 1;
    self.seekGestureRecognizer.maximumNumberOfTouches = 1;
    // 设置滑动手势需要的最小移动距离，避免与点击手势冲突
    // 注意：这个属性在 iOS 5.0+ 可用，但实际效果可能因系统版本而异
    // 我们通过在手势处理中判断移动距离来避免冲突
    [self.viewVideo addGestureRecognizer:self.seekGestureRecognizer];
    
    // 创建快进/快退提示标签
    self.seekTimeLabel = [[UILabel alloc] init];
    self.seekTimeLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7f];
    self.seekTimeLabel.textColor = [UIColor whiteColor];
    self.seekTimeLabel.font = [UIFont boldSystemFontOfSize:18.0f];
    self.seekTimeLabel.textAlignment = NSTextAlignmentCenter;
    self.seekTimeLabel.layer.cornerRadius = 8.0f;
    self.seekTimeLabel.layer.masksToBounds = YES;
    self.seekTimeLabel.hidden = YES;
    
    // 设置标签大小和位置（居中显示）
    CGFloat labelWidth = 120.0f;
    CGFloat labelHeight = 50.0f;
    self.seekTimeLabel.frame = CGRectMake(0, 0, labelWidth, labelHeight);
    
    // 延迟设置中心点，因为此时 viewVideo 的 bounds 可能还未确定
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.viewVideo != nil && self.seekTimeLabel != nil) {
            self.seekTimeLabel.center = CGPointMake(self.viewVideo.bounds.size.width / 2.0f, self.viewVideo.bounds.size.height / 2.0f);
        }
    });
    
    [self.viewVideo addSubview:self.seekTimeLabel];
    
    self.isSeeking = NO;
}

// 处理快进/快退手势
- (void)handleSeekGesture:(UIPanGestureRecognizer *)gesture
{
    if (self.player == nil || self.playerItem == nil || self.time <= 0) {
        return;
    }
    
    CGPoint translation = [gesture translationInView:self.viewVideo];
    CGPoint location = [gesture locationInView:self.viewVideo];
    CGPoint velocity = [gesture velocityInView:self.viewVideo];
    
    // 计算水平移动距离，用于判断是否为有效的水平滑动
    CGFloat horizontalMovement = fabs(translation.x);
    CGFloat verticalMovement = fabs(translation.y);
    
    // 如果垂直移动距离大于水平移动距离，可能是上下滑动，不处理
    if (verticalMovement > horizontalMovement && gesture.state == UIGestureRecognizerStateBegan) {
        return;
    }
    
    // 如果水平移动距离太小（小于20像素），可能是点击而不是滑动，不处理
    if (horizontalMovement < 20.0f && gesture.state == UIGestureRecognizerStateChanged) {
        return;
    }
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
        {
            self.seekStartX = location.x;
            self.isSeeking = YES;
            self.seekTimeLabel.hidden = NO;
            
            // 暂停播放（如果正在播放）
            if ([self isPlaying]) {
                [self.player pause];
            }
            break;
        }
        case UIGestureRecognizerStateChanged:
        {
            // 计算滑动的距离（像素）
            CGFloat deltaX = location.x - self.seekStartX;
            
            // 将像素距离转换为时间（假设屏幕宽度对应视频总时长）
            // 使用更灵敏的比例：屏幕宽度的1/4对应视频总时长的1/4
            CGFloat screenWidth = self.viewVideo.bounds.size.width;
            if (screenWidth <= 0) {
                screenWidth = [UIScreen mainScreen].bounds.size.width;
            }
            
            // 计算时间偏移（秒）
            // 滑动屏幕宽度的1/4对应视频总时长的1/4
            CGFloat timeOffset = (deltaX / screenWidth) * self.time;
            
            // 获取当前播放时间
            CMTime currentTime = self.playerItem.currentTime;
            if (!CMTIME_IS_VALID(currentTime)) {
                currentTime = kCMTimeZero;
            }
            
            CGFloat currentSeconds = CMTimeGetSeconds(currentTime);
            if (currentSeconds < 0) {
                currentSeconds = 0;
            }
            
            // 计算新的播放时间
            CGFloat newSeconds = currentSeconds + timeOffset;
            
            // 限制在有效范围内 [0, self.time]
            if (newSeconds < 0) {
                newSeconds = 0;
            } else if (newSeconds > self.time) {
                newSeconds = self.time;
            }
            
            // 更新播放位置
            CMTime seekTime = CMTimeMakeWithSeconds(newSeconds, NSEC_PER_SEC);
            [self.playerItem seekToTime:seekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
            
            // 更新UI显示
            self.lbCurrentVideoTime.text = [self strWithTime:newSeconds];
            if (self.time > 0) {
                [self.progressPlaying setProgress:(newSeconds / self.time) duration:0];
            }
            
            // 更新提示标签
            int seekSeconds = (int)timeOffset;
            if (seekSeconds > 0) {
                self.seekTimeLabel.text = [NSString stringWithFormat:@"+%d秒", seekSeconds];
            } else if (seekSeconds < 0) {
                self.seekTimeLabel.text = [NSString stringWithFormat:@"%d秒", seekSeconds];
            } else {
                self.seekTimeLabel.text = @"0秒";
            }
            
            // 更新标签位置（跟随手指，但保持在屏幕中央区域）
            CGFloat screenHeight = self.viewVideo.bounds.size.height;
            if (screenHeight <= 0) {
                screenHeight = [UIScreen mainScreen].bounds.size.height;
            }
            
            CGFloat labelX = MAX(60.0f, MIN(location.x, screenWidth - 60.0f)); // 限制在屏幕左右边缘内
            CGFloat labelY = location.y - 80.0f; // 在手指上方显示
            if (labelY < 50.0f) {
                labelY = location.y + 80.0f; // 如果上方空间不够，显示在下方
            }
            // 确保标签不会超出屏幕
            labelY = MAX(50.0f, MIN(labelY, screenHeight - 50.0f));
            self.seekTimeLabel.center = CGPointMake(labelX, labelY);
            
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            self.isSeeking = NO;
            self.seekTimeLabel.hidden = YES;
            
            // 恢复播放（如果之前正在播放）
            // 注意：这里不自动恢复播放，让用户手动点击播放按钮
            // 如果需要自动恢复，可以取消下面的注释
            // if (self.player.rate == 0) {
            //     [self doResume];
            // }
            
            break;
        }
        default:
            break;
    }
}

@end



#pragma mark - NoVideoWrapper UI封装

/**
 * 当短视频未成功加载时显示的UI封装类。
 * 独立出本类的唯一原因，是为了让主类 {@link ShortVideoPlayerActivity} 的代码保持简洁，易于理解和维护，仅此而已，别无它用。
 */
@interface NoVideoWrapper ()

@property (nonatomic, retain) UIView *layoutVideoView;

@property (nonatomic, retain) UIView *layoutOfNoVideo;
@property (nonatomic, retain) UIImageView *viewIcon;
@property (nonatomic, retain) HWVideoProgress *progressForDownload;
@property (nonatomic, retain) UILabel *viewHint;

@end

@implementation NoVideoWrapper

- (id)initWith:(UIView *)layoutVideoView layoutOfNoVideo:(UIView *)layoutOfNoVideo viewIcon:(UIImageView *)viewIcon progressForDownload:(HWVideoProgress *)progressForDownload viewHint:(UILabel *)viewHint
{
    if(self = [super init])
    {
        self.layoutVideoView = layoutVideoView;
        self.layoutOfNoVideo = layoutOfNoVideo;
        self.viewIcon = viewIcon;
        self.progressForDownload = progressForDownload;
        self.viewHint = viewHint;
        
        // 初始化进度条的颜色等
        [self.progressForDownload set:RGBCOLOR(64, 64, 64) progressColor:RGBCOLOR(66, 201, 88) cornerRadius:5.0f];
    }
    return self;
}

- (NoVideoWrapper *)setVisible:(BOOL)visible
{
    if(visible)
    {
        self.layoutVideoView.hidden = YES;
        self.layoutOfNoVideo.hidden = NO;
    }
    else
        self.layoutOfNoVideo.hidden = YES;
    return self;
}

- (NoVideoWrapper *)setVisible:(BOOL)visible progressVisible:(BOOL)progressVisible
{
    [self setVisible:visible];

    if(progressVisible)
        self.progressForDownload.hidden = NO;
    else
        self.progressForDownload.hidden = YES;
    return self;
}

- (NoVideoWrapper *)setProgress:(CGFloat)progressOf1
{
    [self.progressForDownload setProgress:progressOf1 duration:0.1f];
    return self;
}

- (NoVideoWrapper *)setText:(NSString *)text
{
    self.viewHint.text = text;
    return self;
}

- (NoVideoWrapper *)setIcon:(NSString *)imgName
{
    self.viewIcon.image = [UIImage imageNamed:imgName];
    return self;
}

@end



