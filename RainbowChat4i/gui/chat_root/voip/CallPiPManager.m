//
//  CallPiPManager.m
//  RainbowChat4i
//
//  视频通话画中画（PiP）。
//
//  策略：
//  1. prepare 只创建 view + 设 delegate
//  2. 在 attachPiPSourceViewToContainerView 时创建控制器（view 已在通话页、前台）
//  3. 整通通话复用控制器，不销毁
//  4. 退后台直接 startPictureInPicture
//

#import "CallPiPManager.h"
#import "CallManager.h"
#import "AgoraManager.h"
#import "AgoraSampleBufferView.h"
#import "ViewControllerFactory.h"
#import "CallViewController.h"
#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <AgoraRtcKit/AgoraRtcEngineKit.h>

@interface CallPiPManager () <AgoraVideoFrameDelegate, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate>
@property (nonatomic, strong) AgoraSampleBufferView *sampleBufferView;
@property (nonatomic, strong) AVPictureInPictureController *pipController API_AVAILABLE(ios(15.0));
@property (nonatomic, assign, readwrite) BOOL isPiPActive;
@property (nonatomic, assign) BOOL prepared;
@property (nonatomic, assign) int64_t frameCount;
@property (nonatomic, assign) BOOL isRestoringUI;
@end

@implementation CallPiPManager

+ (instancetype)sharedInstance {
    static CallPiPManager *inst;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ inst = [CallPiPManager new]; });
    return inst;
}

#pragma mark - 对外 API

- (void)preparePiPForVideoCall {
    if (self.prepared) return;

    if ([NSThread isMainThread]) {
        self.sampleBufferView = [[AgoraSampleBufferView alloc] initWithFrame:CGRectMake(0,0,160,90)];
        self.sampleBufferView.backgroundColor = UIColor.blackColor;
        self.prepared = YES;
        [[AgoraManager sharedInstance] setPipVideoFrameDelegate:self];
        UIViewController *top = [ViewControllerFactory topMostViewController];
        if ([top isKindOfClass:[CallViewController class]]) {
            [self attachPiPSourceViewToContainerView:top.view];
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.prepared) return;
            self.sampleBufferView = [[AgoraSampleBufferView alloc] initWithFrame:CGRectMake(0,0,160,90)];
            self.sampleBufferView.backgroundColor = UIColor.blackColor;
            self.prepared = YES;
            [[AgoraManager sharedInstance] setPipVideoFrameDelegate:self];
            UIViewController *top = [ViewControllerFactory topMostViewController];
            if ([top isKindOfClass:[CallViewController class]]) {
                [self attachPiPSourceViewToContainerView:top.view];
            }
        });
    }
}

- (void)attachPiPSourceViewToContainerView:(UIView *)containerView {
    if (!containerView || !self.sampleBufferView) return;
    if (self.sampleBufferView.superview == containerView) return;
    [self.sampleBufferView removeFromSuperview];
    self.sampleBufferView.frame = CGRectMake(0, 0, 1, 1);
    self.sampleBufferView.alpha = 0;
    [containerView addSubview:self.sampleBufferView];

    if (@available(iOS 15.0, *)) {
        if (!self.pipController) {
            AVSampleBufferDisplayLayer *layer = self.sampleBufferView.sampleBufferDisplayLayer;
            if (layer) {
                AVPictureInPictureControllerContentSource *src =
                    [[AVPictureInPictureControllerContentSource alloc]
                     initWithSampleBufferDisplayLayer:layer playbackDelegate:self];
                self.pipController = [[AVPictureInPictureController alloc] initWithContentSource:src];
                self.pipController.delegate = self;
                self.pipController.canStartPictureInPictureAutomaticallyFromInline = YES;
                self.pipController.requiresLinearPlayback = YES;
                [self.pipController invalidatePlaybackState];
            }
        }
    }
}

- (void)startPiPWhenPossible {
    if (@available(iOS 15.0, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.isPiPActive && self.pipController.isPictureInPictureActive) return;
            self.isPiPActive = NO;
            if (!self.pipController) return;
            [self.pipController startPictureInPicture];
        });
    }
}

- (void)stopPiP {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL stillInCall = ([CallManager sharedInstance].currentState == CallStateConnected &&
                            [CallManager sharedInstance].currentCallType == CallTypeVideo);
        if (@available(iOS 15.0, *)) {
            if (self.pipController && self.isPiPActive) {
                [self.pipController stopPictureInPicture];
            }
        }
        self.isPiPActive = NO;

        if (stillInCall) return;
        [self teardown];
    });
}

#pragma mark - 内部

- (void)teardown {
    self.frameCount = 0;
    self.prepared = NO;
    [[AgoraManager sharedInstance] setPipVideoFrameDelegate:nil];
    [self.sampleBufferView removeFromSuperview];
    [self.sampleBufferView flush];
    if (@available(iOS 15.0, *)) { self.pipController = nil; }
    self.sampleBufferView = nil;
}

#pragma mark - AVPictureInPictureControllerDelegate

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)c API_AVAILABLE(ios(15.0)) {
    self.isPiPActive = YES;
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)c API_AVAILABLE(ios(15.0)) {
    self.isPiPActive = NO;
    if (self.isRestoringUI) {
        self.isRestoringUI = NO;
        return;
    }
    if ([CallManager sharedInstance].currentState == CallStateConnected) {
        [[CallManager sharedInstance] hangupCall];
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)c restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler API_AVAILABLE(ios(15.0)) {
    self.isRestoringUI = YES;
    CallManager *cm = [CallManager sharedInstance];
    if (cm.currentState == CallStateConnected) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *top = [ViewControllerFactory topMostViewController];
            if ([top isKindOfClass:[CallViewController class]]) {
                if (completionHandler) completionHandler(YES);
                return;
            }
            CallViewController *vc = [[CallViewController alloc] init];
            vc.callType = cm.currentCallType;
            vc.remoteUserUid = cm.remoteUserUid;
            vc.remoteUserNickname = cm.remoteUserNickname;
            vc.isCaller = cm.isCaller;
            vc.isRestoringFromFloat = YES;
            if (top.navigationController) {
                [top.navigationController pushViewController:vc animated:YES];
            } else {
                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                [top presentViewController:vc animated:YES completion:nil];
            }
            if (completionHandler) completionHandler(YES);
        });
    } else {
        if (completionHandler) completionHandler(NO);
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)c failedToStartPictureInPictureWithError:(NSError *)error API_AVAILABLE(ios(15.0)) {
    self.isPiPActive = NO;
    UIApplicationState s = UIApplication.sharedApplication.applicationState;
    if (s != UIApplicationStateActive) {
        __weak typeof(self) w = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (w.pipController && !w.isPiPActive) {
                [w.pipController startPictureInPicture];
            }
        });
    }
}

#pragma mark - AVPictureInPictureSampleBufferPlaybackDelegate

- (void)pictureInPictureController:(AVPictureInPictureController *)c setPlaying:(BOOL)p API_AVAILABLE(ios(15.0)) {}
- (CMTimeRange)pictureInPictureControllerTimeRangeForPlayback:(AVPictureInPictureController *)c API_AVAILABLE(ios(15.0)) {
    return CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(36000, 600));
}
- (BOOL)pictureInPictureControllerIsPlaybackPaused:(AVPictureInPictureController *)c API_AVAILABLE(ios(15.0)) { return NO; }
- (void)pictureInPictureController:(AVPictureInPictureController *)c didTransitionToRenderSize:(CMVideoDimensions)s API_AVAILABLE(ios(15.0)) {}
- (void)pictureInPictureController:(AVPictureInPictureController *)c skipByInterval:(CMTime)i completionHandler:(void (^)(void))h API_AVAILABLE(ios(15.0)) { if (h) h(); }

#pragma mark - AgoraVideoFrameDelegate

- (AgoraVideoFormat)getVideoFormatPreference { return AgoraVideoFormatDefault; }
- (AgoraVideoFramePosition)getObservedFramePosition { return AgoraVideoModulePositionPreRenderer; }
- (AgoraVideoFrameProcessMode)getVideoFrameProcessMode { return AgoraVideoFrameProcessModeReadOnly; }

- (BOOL)onRenderVideoFrame:(AgoraOutputVideoFrame *)videoFrame uid:(NSUInteger)uid channelId:(NSString *)channelId {
    CVPixelBufferRef px = NULL;
    if (videoFrame.pixelBuffer) {
        px = videoFrame.pixelBuffer; CVPixelBufferRetain(px);
    } else if (videoFrame.yBuffer && videoFrame.uBuffer && videoFrame.vBuffer && videoFrame.width > 0 && videoFrame.height > 0) {
        px = [self pixelBufferFromI420:videoFrame];
    }
    if (px && self.sampleBufferView) {
        self.frameCount++;
        [self.sampleBufferView enqueuePixelBuffer:px];
        CVPixelBufferRelease(px);
    }
    return YES;
}

- (CVPixelBufferRef)pixelBufferFromI420:(AgoraOutputVideoFrame *)f {
    int w = f.width, h = f.height;
    if (w <= 0 || h <= 0 || !f.yBuffer) return NULL;
    int ys = f.yStride > 0 ? f.yStride : w;
    int us = f.uStride > 0 ? f.uStride : w/2;
    int vs = f.vStride > 0 ? f.vStride : w/2;
    CVPixelBufferRef pb = NULL;
    NSDictionary *a = @{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}};
    if (CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_420YpCbCr8PlanarFullRange, (__bridge CFDictionaryRef)a, &pb) != kCVReturnSuccess) return NULL;
    CVPixelBufferLockBaseAddress(pb, 0);
    size_t s0 = CVPixelBufferGetBytesPerRowOfPlane(pb,0);
    size_t s1 = CVPixelBufferGetBytesPerRowOfPlane(pb,1);
    size_t s2 = CVPixelBufferGetBytesPerRowOfPlane(pb,2);
    uint8_t *dy = CVPixelBufferGetBaseAddressOfPlane(pb,0);
    uint8_t *du = CVPixelBufferGetBaseAddressOfPlane(pb,1);
    uint8_t *dv = CVPixelBufferGetBaseAddressOfPlane(pb,2);
    for (int r=0;r<h;r++) memcpy(dy+r*s0, f.yBuffer+r*ys, w);
    for (int r=0;r<h/2;r++) { memcpy(du+r*s1, f.uBuffer+r*us, w/2); memcpy(dv+r*s2, f.vBuffer+r*vs, w/2); }
    CVPixelBufferUnlockBaseAddress(pb, 0);
    return pb;
}

@end
