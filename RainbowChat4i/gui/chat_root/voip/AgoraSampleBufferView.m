//
//  AgoraSampleBufferView.m
//  RainbowChat4i
//
//  用于 PiP：AVSampleBufferDisplayLayer + CVPixelBuffer -> CMSampleBuffer 入队。
//

#import "AgoraSampleBufferView.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>


static void *kPiPQueueLabel = "com.rainbowchat.pip.samplebuffer";

@interface AgoraSampleBufferView ()
@property (nonatomic, strong) dispatch_queue_t sampleQueue;
@property (nonatomic, assign) int64_t frameCount;
@end

@implementation AgoraSampleBufferView

+ (Class)layerClass
{
    return [AVSampleBufferDisplayLayer class];
}

- (AVSampleBufferDisplayLayer *)sampleBufferLayer
{
    return (AVSampleBufferDisplayLayer *)self.layer;
}

- (AVSampleBufferDisplayLayer *)sampleBufferDisplayLayer
{
    return [self sampleBufferLayer];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _sampleQueue = dispatch_queue_create(kPiPQueueLabel, DISPATCH_QUEUE_SERIAL);
        _frameCount = 0;
        self.backgroundColor = [UIColor blackColor];
        AVSampleBufferDisplayLayer *layer = [self sampleBufferLayer];
        layer.videoGravity = AVLayerVideoGravityResizeAspect;
        if (@available(iOS 11.0, *)) {
            layer.preventsCapture = NO;
        }
    }
    return self;
}

- (void)enqueuePixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (!pixelBuffer) return;
    
    CVPixelBufferRef buf = pixelBuffer;
    CVPixelBufferRetain(buf);
    
    dispatch_async(self.sampleQueue, ^{
        CMVideoFormatDescriptionRef formatDesc = NULL;
        OSStatus err = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, buf, &formatDesc);
        if (err != noErr || !formatDesc) {
            CVPixelBufferRelease(buf);
            return;
        }
        
        CMSampleTimingInfo timing = {
            .duration = CMTimeMake(1, 30),
            .presentationTimeStamp = CMTimeMake(self.frameCount++, 30),
            .decodeTimeStamp = kCMTimeInvalid
        };
        
        CMSampleBufferRef sampleBuffer = NULL;
        err = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, buf, formatDesc, &timing, &sampleBuffer);
        CFRelease(formatDesc);
        CVPixelBufferRelease(buf);
        
        if (err != noErr || !sampleBuffer) return;

        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
        if (attachments && CFArrayGetCount(attachments) > 0) {
            CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            if (dict) {
                CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
            }
        }

        AVSampleBufferDisplayLayer *layer = [self sampleBufferLayer];
        if (layer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            dispatch_async(dispatch_get_main_queue(), ^{ [layer flush]; });
        }
        [layer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    });
}

- (void)flush
{
    dispatch_async(self.sampleQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self sampleBufferLayer] flush];
        });
    });
}

@end
