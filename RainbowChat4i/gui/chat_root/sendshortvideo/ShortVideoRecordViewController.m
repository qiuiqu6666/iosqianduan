//telegram @wz662
//
//  ShortVideoRecordViewController.m
//  AVFoundationTest
//
//  Created by Jack Jiang on 2019/10/19.
//  Copyright © 2019 wqb. All rights reserved.
//
//  原始代码参考了：https://blog.csdn.net/hero_wqb/article/details/77620684
//

#import "ShortVideoRecordViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "HWVideoProgress.h"
#import "FileTool.h"
#import "BasicTool.h"
#import "Default.h"
#import "NotificationCenterFactory.h"
#import "PromtHelper.h"

/** 录制时间、“录制中..”图标的UI刷新时间间隔（单位：秒） */
const float TIMMER_INTERVAL  = 0.5f;// 1.0f

@interface ShortVideoRecordViewController ()<AVCaptureFileOutputRecordingDelegate>

/** 录制的视频的保存目录(目录结尾带"反斜线"了哦) */
@property (nonatomic, retain) NSString *saveDirForInit;

// 定时器
@property (nonatomic, strong) NSTimer *timer;
// 负责输入和输出设置之间的数据传递
@property (nonatomic, strong) AVCaptureSession *captureSession;
// 负责从AVCaptureDevice获得输入数据
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
// 视频输出流
@property (nonatomic, strong) AVCaptureMovieFileOutput *captureMovieFileOutput;
// 相机拍摄预览图层
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

// 后台任务标识
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;

// 文件路径
@property (nonatomic, copy) NSString *path;
// 录制时长
@property (nonatomic, assign) float time;

// 摄像头等初始化是否成功
@property (nonatomic, assign) BOOL initOK;
// 是否已退出录制（因为录制完成的代理是异步被调用的，本标识用于在录制完成的代理被调用时，能知道该代理被调用时是否是因退出录制而引起的）
@property (nonatomic, assign) BOOL cancelledRecording;

@end

@implementation ShortVideoRecordViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withSaveDir:(NSString *)saveDir
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    // 初始化
    if (self)
    {
        self.saveDirForInit = saveDir;
        self.initOK = NO;
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 留海屏的安全区下方衬距
    CGFloat safeAreaInsets_bottom = [BasicTool getSafeAreaInsets_bottom];
    // 设置底部操作按钮组件父view的高度约束（当运行于刘海屏iPhone时，要加上safeArea的高度，这样就能让底部操作区的背景充满整个底部，好看一点）
    self.bottomContainerHeightConstraint.constant = self.bottomContainerHeightConstraint.constant + safeAreaInsets_bottom;
    
    // 针对ios 26的优化：不需要单独的背景色液态玻璃效果更好
    if (@available(iOS 26, *)) {
    } else {
        [self.btnClose setBackgroundColor:RGBACOLOR(255,255,255, 26)];
        [self.btnCameraSwitch setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    }
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:self.btnClose];
    [BasicTool setClearGlassBgnConfig:self.btnCameraSwitch];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // 隐藏导导航栏
    [self hideNavigation];
    
//    // 初始化信息
//    [self initRecordVideo];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // 初始化信息
    [self initRecordVideo];
    
    [self startCarmera];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // 取消隐藏导航栏
    [self showNavigation];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self stopVideoRecoding];
    [self removeRecordTimer];
    
    [self removeNotification];
    [self stopCarmera];
}

// ios的AVFoundation实现视频录制，基本上以下代码都是标准套路，如果对AVFoundation的使用不熟悉，可以查阅相关资料，熟悉后再看代码
- (void)initRecordVideo
{
    // 获得输入设备（后置摄像头）
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (!captureDevice) {
        NSLog(@"【短视频录制】取得后置摄像头时出现问题(发生于：getCameraDeviceWithPosition:)！");
        return;
    }
    // 添加一个音频输入设备
    AVCaptureDevice *audioCaptureDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    NSError *error = nil;
    // 根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"【短视频录制】取得录像设备输入对象时出错，错误原因：%@", error.localizedDescription);
        return;
    }
    AVCaptureDeviceInput *audioCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioCaptureDevice error:&error];
    if (error) {
        NSLog(@"【短视频录制】取得录音设备输入对象时出错，错误原因：%@", error.localizedDescription);
        return;
    }
    
    // 初始化设备输出对象，用于获得输出数据
    _captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    // 不设置这个属性，超过10s的视频会没有声音
    _captureMovieFileOutput.movieFragmentInterval = kCMTimeInvalid;
    
    // 设置默认的最长录制时间（如：第一个参数10表示10秒，第二个参数1表示时间精度（此处不需要到小数，所以填为1））
    _captureMovieFileOutput.maxRecordedDuration = CMTimeMakeWithSeconds(SHORT_VIDEO_RECORD_MAX_TIME, 1);
    
    // 初始化会话
    _captureSession = [[AVCaptureSession alloc] init];
    // 设置录制分辨率
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset640x480;// TODO: 视频10s为4MB左右大小，还可以进行优化，看看需要调什么参数！
    }
    
    // 将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
        [_captureSession addInput:audioCaptureDeviceInput];
        AVCaptureConnection *captureConnection = [_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoStabilizationSupported]) {
            captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
    }
    
    // 将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    // 创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    
    // 摄像头方向
    AVCaptureConnection *captureConnection = [self.captureVideoPreviewLayer connection];
    captureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    CALayer *layer = _viewVideoContainer.layer;
    layer.masksToBounds = YES;
 
    //
//    layer.frame = CGRectMake(_viewVideoContainer.frame.origin.x, _viewVideoContainer.frame.origin.y
//    , ScreenWidth,ScreenHeight),
    
    // 注意：本frame依赖于父组件的宽高，页父组件又依赖于ios的autolayout的约束，而约束的自动拉伸生效是在viewController的viewDiaAppear时，
    //     所以，一定要注意主frame的设计，一定要在viewController的viewDiaAppear里或之后的代码里调用才能获得正确的大小
    _captureVideoPreviewLayer.frame = layer.bounds;
    
    // 填充模式
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    // 将视频预览层添加到界面中
    [layer insertSublayer:_captureVideoPreviewLayer below:self.imgFocusCursor.layer];
    
    [self addNotificationToCaptureDevice:captureDevice];
    [self addGenstureRecognizer];
    
    self.initOK = YES;
}

// 启动相机（启动机机并不是开始录制视频哦）
- (void) startCarmera
{
    if(self.captureSession != nil)
        [self.captureSession startRunning];
    else
    {
        [BasicTool showAlert:NSLocalizedString(@"general_tip", @"") content:@"相机启动失败，请检查您的设备（如果您当前正在模拟器中使用本功能，请换到真机后再试）！" btnTitle:NSLocalizedString(@"general_confirm_btn", @"") parent:self handler:^(UIAlertAction *action) {
             [self back];
        }];
    }
}

// 关停相机
- (void) stopCarmera
{
    if(self.captureSession != nil)
        [self.captureSession stopRunning];
}

// 开始录制
- (void)startVideoRecording
{
    if(!self.initOK)
    {
        [BasicTool showAlertError:@"初始化失败，无法录制视频！" parent:self];
        return;
    }
    
    _path = [self getTempVideoPath];
    if(_path == nil)
    {
        [BasicTool showAlertError:@"保存目录创建失败，无法录制视频！" parent:self];
        return;
    }
    
    _cancelledRecording = NO;
    
    // 不再播放「开始录制」提示音，否则该声音会被正在录制的麦克风录进视频
    // dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),^{
    //     [[PromtHelper sharedInstance] audioRecordingPromt];
    // });
    
    // 更新UI显示
    [self refreshControlUI:YES];
    
    // 根据设备输出获得连接
    AVCaptureConnection *captureConnection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
    // 如果正在录制，则重新录制，先暂停
    [self stopVideoRecoding];
    
    // 如果支持多任务则开始多任务
    if ([[UIDevice currentDevice] isMultitaskingSupported]) {
        self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
    }
    
    // 预览图层和视频方向保持一致
    captureConnection.videoOrientation = [self.captureVideoPreviewLayer connection].videoOrientation;
    
    // 添加路径
    NSURL *fileUrl = [NSURL fileURLWithPath:_path];
    [self.captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    
    // 添加定时器
//  [self removeRecordTimer];
    [self addRecordTimer];
}

// 结束录制
- (void)stopVideoRecoding
{
    if ([self isRecording] && self.captureMovieFileOutput != nil)
        [self.captureMovieFileOutput stopRecording];
    
    if(self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
    
//  // 移除定时器
//  [self removeRecordTimer];
}

- (void)cancelRecordingNoConfirm:(BOOL)deleteFile
{
    _cancelledRecording = YES;
    
    if([self isRecording])
    {
        NSLog(@"【短视频录制】当前正在录制中，cancelRecording时需先停止录制相关逻辑(deleteFile?%d)。。。", deleteFile);
        
        // 停止视频录制
        [self stopVideoRecoding];
        // 刷新UI
        [self refreshControlUI:NO];
        
        // 如果需要删除录制完成的文件
        NSString *filePath = _path;
        if(deleteFile && filePath != nil && [FileTool fileExists:filePath])
        {
            BOOL sucess = [FileTool removeFile:filePath];
            NSLog(@"【短视频录制】录制的临时视频 %@ 文件删除成功了吗？%d", filePath, sucess);
        }
    }
    else
    {
        NSLog(@"【短视频录制】当前未在录制中，cancelRecording时直接通出当前界面即可。");
    }
}

- (void) refreshControlUI:(BOOL)start
{
    if(start)
    {
        // 更新UI显示
        self.lbRecordTime.text = @"00:00";
        [self.btnRecordControl setBackgroundImage:[UIImage imageNamed:@"common_short_video_recordvideo_stop"] forState:UIControlStateNormal];
        self.btnCameraSwitch.hidden = YES;
    }
    else
    {
        // 移除定时器
        [self removeRecordTimer];
        
        // 更新界面
        [self.imgRecording setImage:[UIImage imageNamed:@"common_short_video_recordvideo_start_amination_normal"]];
//      self.imgRecording.hidden = NO;
        [self.btnRecordControl setBackgroundImage:[UIImage imageNamed:@"common_short_video_recordvideo_start"] forState:UIControlStateNormal];
        self.btnCameraSwitch.hidden = NO;
    }
}


#pragma mark - 视频录制计时器

// 添加定时器
- (void)addRecordTimer
{
    _time = 0;
    _timer = [NSTimer scheduledTimerWithTimeInterval:TIMMER_INTERVAL target:self selector:@selector(recordTimerAction) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

// 定时器事件
- (void)recordTimerAction
{
    _time += TIMMER_INTERVAL;
    
    [self.imgRecording setImage:[UIImage imageNamed:@"common_short_video_recordvideo_start_amination_light"]];
    self.imgRecording.hidden = !self.imgRecording.hidden;
    self.lbRecordTime.text = [NSString stringWithFormat:@"%@", [self strWithTime:_time]];
}

// 移除定时器
- (void)removeRecordTimer
{
    if(_timer != nil)
        [_timer invalidate];
    _timer = nil;
}

// 时长长度转时间字符串
- (NSString *)strWithTime:(double)time
{
    int minute = time / 60;
    int second = (int)time % 60;
    
    return [NSString stringWithFormat:@"%02d:%02d", minute, second];
}


#pragma mark - 视频输出代理

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    NSLog(@"【短视频录制】开始录制，保存路径：%@", _path);
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    if(!_cancelledRecording)
    {
        // 原始的视频录制时长
        CMTime durOriginal = captureOutput.recordedDuration;
        // 计算结果 +1 是为了保整强行取整计算的舍入问题，不然ui上的10秒这里计算后，就只有9秒了（实际上录制出来的10秒视频确实可能只有9.49这样，连四舍五入都不好做）
        int durReal = ((int)(durOriginal.value / durOriginal.timescale)) + 1;
        
        NSLog(@"【短视频录制】视频录制完成, val=%lld, timescale=%d, realDuration=%d秒.", durOriginal.value, durOriginal.timescale, durReal);
            
        // 刷新UI显示
        [self refreshControlUI:NO];
        
        // 本次录制的时长（秒）
        int recordDuration = (durReal <=0 ?0 : durReal);
        
        NSLog(@"【短视频录制】视频录制完成(时长:%d秒)，保存路径是：%@", recordDuration, _path);
        
        if(recordDuration <= 0)
        {
            [BasicTool showAlertWarn:@"视频时间太短，本次录制无效，请重新录制！" parent:self];
            return;
        }
        else
        {
            ShortVideoRecordedDTO *dto = [[ShortVideoRecordedDTO alloc] init];
            dto.savedPath = _path;
            dto.duration = recordDuration;
            dto.reachedMaxRecordTime = (recordDuration >= SHORT_VIDEO_RECORD_MAX_TIME ? YES : NO);
            
            // 通知聊天界面处理录制好的短视频以便继续短视频消息的余下其它流程
            [NotificationCenterFactory shortVideoRecordComplete_POST:dto];
            
            [self backOnly];
        }
    }
    else
    {
        NSLog(@"【短视频录制】当前录制是用户主动取消的，本次视频录制完成的代理调用通知，将被忽略！");
    }
}


#pragma mark - 摄像头切换

// 取得指定位置的摄像头
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition)position
{
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position] == position) {
            return camera;
        }
    }
    
    return nil;
}

// 切换前后摄像头
- (IBAction)cameraSwitchBtnOnClick:(id)sender
{
    AVCaptureDevice *currentDevice = [self.captureDeviceInput device];
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    [self removeNotificationFromCaptureDevice:currentDevice];
    
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionBack;
    if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionBack) {
        toChangePosition = AVCaptureDevicePositionFront;
    }
    toChangeDevice = [self getCameraDeviceWithPosition:toChangePosition];
    [self addNotificationToCaptureDevice:toChangeDevice];
    
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.captureSession beginConfiguration];
    //移除原有输入对象
    [self.captureSession removeInput:self.captureDeviceInput];
    //添加新的输入对象
    if ([self.captureSession canAddInput:toChangeDeviceInput]) {
        [self.captureSession addInput:toChangeDeviceInput];
        self.captureDeviceInput = toChangeDeviceInput;
    }
    //提交会话配置
    [self.captureSession commitConfiguration];
}


#pragma mark - 通知

//给输入设备添加通知
- (void)addNotificationToCaptureDevice:(AVCaptureDevice *)captureDevice
{
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled = YES;
    }];
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    // 捕获区域发生改变(设备中场景改变时发出通知，既预览发生变化)，详见资料：https://www.jianshu.com/p/a9c500d74a4b
    [notificationCenter addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}

- (void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}

//改变设备属性的统一操作方法
- (void)changeDeviceProperty:(void (^)(AVCaptureDevice *))propertyChange
{
    AVCaptureDevice *captureDevice = [self.captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else {
        NSLog(@"【短视频录制】设置设备属性过程发生错误，错误信息：%@", error.localizedDescription);
        [BasicTool showAlertWarn:@"出错了，请检查您的设备！" parent:self];
    }
}

//已捕获区域改变
- (void)areaChange:(NSNotification *)notification
{
    NSLog(@"【短视频录制】已捕获区域改变....");
}


# pragma mark - 点击手势及对焦功能

// 添加点按手势，点按时进行相机的对焦
- (void)addGenstureRecognizer
{
    [self.viewVideoContainer addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapScreen:)]];
}

- (void)tapScreen:(UITapGestureRecognizer *)tapGesture
{
    CGPoint point = [tapGesture locationInView:self.viewVideoContainer];
    
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint = [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

// 设置聚焦光标位置
- (void)setFocusCursorWithPoint:(CGPoint)point
{
    self.imgFocusCursor.center = point;
    self.imgFocusCursor.transform = CGAffineTransformMakeScale(1.5, 1.5);
    self.imgFocusCursor.alpha = 1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.imgFocusCursor.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.imgFocusCursor.alpha = 0;
    }];
}

// 设置聚焦点
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point
{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}


# pragma mark - 其它方法

// 视频是否正在录制中
- (BOOL) isRecording
{
    if(self.captureMovieFileOutput != nil)
        return [self.captureMovieFileOutput isRecording];
    return NO;
}

- (IBAction)btnRecordControlOnClick:(id)sender
{
    UIButton *btn = (UIButton *)sender;
    btn.enabled = NO;
        
    // 如果是“正在录制中”，则此时就是结束录制
    if ([self isRecording])
    {
        // 完成录制
//        [self finishBtnOnClick];
        
        // 完成录制
        {
            // 刷新UI
            [self refreshControlUI:NO];
            // 结束录制
            [self stopVideoRecoding];
        }
        
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [self startRecordVideo];
//        });
    }
    // 否则就是开始录制
    else
    {
        // 开始录制
        [self startVideoRecording];
    }
    
    btn.enabled = YES;
}

-(void)hideNavigation
{
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

-(void)showNavigation
{
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}

// 返回(关闭)按钮处理方法
- (IBAction)btnCloseOnClick:(id)sender
{
    [self back];
}

// 返回的处理方法
- (void)back
{
    if([self isRecording])
    {
        // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
        __weak typeof(self) safeSelf = self;
        
        // 确认对话框
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"友情提示" message:@"视频正在录制中，点击\"确认\"将取消本次录制并退出当前界面。" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okActin=[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action){
            [safeSelf cancelRecordingNoConfirm:YES];
            [safeSelf backOnly];
        }];
        UIAlertAction *cancelAction=[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        
        [alert addAction:okActin];
        [alert addAction:cancelAction];
        
        // 显示确认对话框架
        [self presentViewController:alert animated:YES completion:nil];
    }
    else
    {
        [self backOnly];
    }
}

- (void)backOnly
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)removeNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc
{
//    [self removeObserverFromPlayerItem:_player.currentItem];
    [self removeNotification];
}

- (NSString *)getTempVideoName
{
//    return "shortvideo_" + new SimpleDateFormat("YYYYMMdd_HHmmss").format(new Date()) + ".mp4";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYYMMdd_HHmmss"];
    return [NSString stringWithFormat:@"shortvideo_%@.mp4", [formatter stringFromDate:[NSDate date]]];
}

// 视频路径
- (NSString *)getTempVideoPath
{
    if(![FileTool fileExists:self.saveDirForInit])
    {
        NSLog(@"【短视频录制】视频保存目录 %@ 不存在，马上尝试创建之...", self.saveDirForInit);
        [FileTool tryCreateDirs:self.saveDirForInit];
    }
    
    if([FileTool fileExists:self.saveDirForInit])
        return [NSString stringWithFormat:@"%@%@", self.saveDirForInit, [self getTempVideoName]];
    return nil;
}

@end


#pragma mark - ShortVideoRecordedDTO数据传输对象

@implementation ShortVideoRecordedDTO

- (id)init
{
    if(self = [super init])
    {
        // 默认属性初始化
        self.reachedMaxRecordTime = NO;
    }
    return self;
}

@end

