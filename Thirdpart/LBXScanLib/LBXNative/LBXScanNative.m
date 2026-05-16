//telegram @wz662



#import "LBXScanNative.h"
#import <Vision/Vision.h>
#import <CoreImage/CoreImage.h>



@interface LBXScanNative()<AVCaptureMetadataOutputObjectsDelegate>
{
    BOOL bNeedScanResult;
}

@property (assign,nonatomic)AVCaptureDevice * device;
@property (strong,nonatomic)AVCaptureDeviceInput * input;
@property (strong,nonatomic)AVCaptureMetadataOutput * output;
@property (strong,nonatomic)AVCaptureSession * session;
@property (strong,nonatomic)AVCaptureVideoPreviewLayer * preview;

@property(nonatomic,strong)  AVCaptureStillImageOutput *stillImageOutput;//拍照

@property(nonatomic,assign)BOOL isNeedCaputureImage;

//扫码结果
@property (nonatomic, strong) NSMutableArray<LBXScanResult*> *arrayResult;

//扫码类型
@property (nonatomic, strong) NSArray* arrayBarCodeType;

/**
 @brief  视频预览显示视图
 */
@property (nonatomic,weak)UIView *videoPreView;


/*!
 *  扫码结果返回
 */
@property(nonatomic,copy)void (^blockScanResult)(NSArray<LBXScanResult*> *array);


@end

@implementation LBXScanNative

static dispatch_queue_t rbLBXScanSessionQueue(void)
{
    static dispatch_queue_t q;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        q = dispatch_queue_create("com.rainbowchat.lb_scan.avcapturesession", DISPATCH_QUEUE_SERIAL);
    });
    return q;
}


- (void)setNeedCaptureImage:(BOOL)isNeedCaputureImg
{
    _isNeedCaputureImage = isNeedCaputureImg;
}


- (instancetype)initWithPreView:(UIView*)preView ObjectType:(NSArray*)objType cropRect:(CGRect)cropRect success:(void(^)(NSArray<LBXScanResult*> *array))block
{
    if (self = [super init]) {
        [self initParaWithPreView:preView ObjectType:objType cropRect:cropRect success:block];
    }
    return self;
}

- (instancetype)initWithPreView:(UIView*)preView ObjectType:(NSArray*)objType success:(void(^)(NSArray<LBXScanResult*> *array))block
{
    if (self = [super init]) {
        
        [self initParaWithPreView:preView ObjectType:objType cropRect:CGRectZero success:block];
    }
    
    return self;
}


- (void)initParaWithPreView:(UIView*)videoPreView ObjectType:(NSArray*)objType cropRect:(CGRect)cropRect success:(void(^)(NSArray<LBXScanResult*> *array))block
{
    self.arrayBarCodeType = objType;
    self.blockScanResult = block;
    self.videoPreView = videoPreView;
    
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    if (!_device) {
        return;
    }
    
    // Input
    _input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    if ( !_input  )
        return ;
    
    
    bNeedScanResult = YES;
    
    // Output
    _output = [[AVCaptureMetadataOutput alloc]init];
    [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    
    if ( !CGRectEqualToRect(cropRect,CGRectZero) )
    {
        _output.rectOfInterest = cropRect;
    }
    
    /*
    // Setup the still image file output
     */
//    AVCapturePhotoOutput
    
    _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    AVVideoCodecJPEG, AVVideoCodecKey,
                                    nil];
    [_stillImageOutput setOutputSettings:outputSettings];
    
    // Session
    _session = [[AVCaptureSession alloc]init];
    [_session setSessionPreset:AVCaptureSessionPresetHigh];
    
   // _session.
    
   // videoScaleAndCropFactor
    
    if ([_session canAddInput:_input])
    {
        [_session addInput:_input];
    }
    
    if ([_session canAddOutput:_output])
    {
        [_session addOutput:_output];
    }

    if ([_session canAddOutput:_stillImageOutput])
    {
        [_session addOutput:_stillImageOutput];
    }
    
 
 
    
    // 条码类型 AVMetadataObjectTypeQRCode
   // _output.metadataObjectTypes =@[AVMetadataObjectTypeQRCode];
    
    if (!objType) {
        objType = [self defaultMetaDataObjectTypes];
    }
    
    _output.metadataObjectTypes = objType;
    
    // Preview
    _preview =[AVCaptureVideoPreviewLayer layerWithSession:_session];
    _preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    //_preview.frame =CGRectMake(20,110,280,280);
    
    CGRect frame = videoPreView.frame;
    frame.origin = CGPointZero;
    _preview.frame = frame;
    
    [videoPreView.layer insertSublayer:self.preview atIndex:0];
    
 
    
    AVCaptureConnection *videoConnection = [self connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self stillImageOutput] connections]];
//    CGFloat maxScale = videoConnection.videoMaxScaleAndCropFactor;
     CGFloat scale = videoConnection.videoScaleAndCropFactor;
    NSLog(@"%f",scale);
//    CGFloat zoom = maxScale / 50;
//    if (zoom < 1.0f || zoom > maxScale)
//    {
//        return;
//    }
//    videoConnection.videoScaleAndCropFactor += zoom;
//    CGAffineTransform transform = videoPreView.transform;
//    videoPreView.transform = CGAffineTransformScale(transform, zoom, zoom);

    
    
    //先进行判断是否支持控制对焦,不开启自动对焦功能，很难识别二维码。
    if (_device.isFocusPointOfInterestSupported &&[_device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        [_input.device lockForConfiguration:nil];
        [_input.device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        [_input.device unlockForConfiguration];
    }
}

- (CGFloat)getVideoMaxScale
{
    [_input.device lockForConfiguration:nil];
    AVCaptureConnection *videoConnection = [self connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self stillImageOutput] connections]];
    CGFloat maxScale = videoConnection.videoMaxScaleAndCropFactor;
    [_input.device unlockForConfiguration];
    
    return maxScale;
}

- (void)setVideoScale:(CGFloat)scale
{
    [_input.device lockForConfiguration:nil];
    
    AVCaptureConnection *videoConnection = [self connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self stillImageOutput] connections]];
    
    CGFloat zoom = scale / videoConnection.videoScaleAndCropFactor;
    
    videoConnection.videoScaleAndCropFactor = scale;
    
    [_input.device unlockForConfiguration];
    
    CGAffineTransform transform = _videoPreView.transform;
    
    _videoPreView.transform = CGAffineTransformScale(transform, zoom, zoom);
}

- (void)setScanRect:(CGRect)scanRect
{
    //识别区域设置
    if (_output) {
        _output.rectOfInterest = [self.preview metadataOutputRectOfInterestForRect:scanRect];
    }
    
}

- (void)changeScanType:(NSArray*)objType
{    
    _output.metadataObjectTypes = objType;
}

- (void)startScan
{
    bNeedScanResult = YES;
    if (!_input || !_session) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(rbLBXScanSessionQueue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (strongSelf.session.isRunning) {
            return;
        }
        [strongSelf.session startRunning];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) inner = weakSelf;
            if (!inner || !inner.videoPreView || !inner.preview) {
                return;
            }
            if (inner.preview.superlayer != inner.videoPreView.layer) {
                [inner.videoPreView.layer insertSublayer:inner.preview atIndex:0];
            }
        });
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( object == _input.device ) {
        
        NSLog(@"flash change");
    }
}

- (void)stopScan
{
    bNeedScanResult = NO;
    if (!_session) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(rbLBXScanSessionQueue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (strongSelf.session.isRunning) {
            [strongSelf.session stopRunning];
        }
    });
}

- (void)setTorch:(BOOL)torch {   
    
    [self.input.device lockForConfiguration:nil];
    self.input.device.torchMode = torch ? AVCaptureTorchModeOn : AVCaptureTorchModeOff;
    [self.input.device unlockForConfiguration];
}

- (void)changeTorch
{
    AVCaptureTorchMode torch = self.input.device.torchMode;
   
    switch (_input.device.torchMode) {
        case AVCaptureTorchModeAuto:
            break;
        case AVCaptureTorchModeOff:
            torch = AVCaptureTorchModeOn;
            break;
        case AVCaptureTorchModeOn:
            torch = AVCaptureTorchModeOff;
            break;
        default:
            break;
    }
    
    [_input.device lockForConfiguration:nil];
    _input.device.torchMode = torch;
    [_input.device unlockForConfiguration];
}


-(UIImage *)getImageFromLayer:(CALayer *)layer size:(CGSize)size
{
    UIGraphicsBeginImageContextWithOptions(size, YES, [[UIScreen mainScreen]scale]);
    [layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections
{
    for ( AVCaptureConnection *connection in connections ) {
        for ( AVCaptureInputPort *port in [connection inputPorts] ) {
            if ( [[port mediaType] isEqual:mediaType] ) {
                return connection;
            }
        }
    }
    return nil;
}

- (void)captureImage
{
    AVCaptureConnection *stillImageConnection = [self connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self stillImageOutput] connections]];
    
    
    [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:stillImageConnection
                                                         completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error)
     {
         [self stopScan];
         
         if (imageDataSampleBuffer)
         {
             NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
             
             UIImage *img = [UIImage imageWithData:imageData];
             
             for (LBXScanResult* result in _arrayResult) {
                 
                 result.imgScanned = img;
             }
         }
         
         if (_blockScanResult)
         {
             _blockScanResult(_arrayResult);
         }
         
     }];
}


#pragma mark AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput2:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
   
    
    //识别扫码类型
    for(AVMetadataObject *current in metadataObjects)
    {
        if ([current isKindOfClass:[AVMetadataMachineReadableCodeObject class]] )
        {
            
            NSString *scannedResult = [(AVMetadataMachineReadableCodeObject *) current stringValue];
            NSLog(@"type:%@",current.type);
            NSLog(@"result:%@",scannedResult);
            
            
            
         
            
            //测试可以同时识别多个二维码
        }
    }
    
   
    
}
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (!bNeedScanResult) {
        return;
    }
    
    bNeedScanResult = NO;
    
    if (!_arrayResult) {
        
        self.arrayResult = [NSMutableArray arrayWithCapacity:1];
    }
    else
    {
        [_arrayResult removeAllObjects];
    }
    
    //识别扫码类型
    for(AVMetadataObject *current in metadataObjects)
    {
        if ([current isKindOfClass:[AVMetadataMachineReadableCodeObject class]] )
        {
            bNeedScanResult = NO;
            
            NSLog(@"type:%@",current.type);
            NSString *scannedResult = [(AVMetadataMachineReadableCodeObject *) current stringValue];
            
            if (scannedResult && ![scannedResult isEqualToString:@""])
            {
                LBXScanResult *result = [LBXScanResult new];
                result.strScanned = scannedResult;
                result.strBarCodeType = current.type;
                
                [_arrayResult addObject:result];
            }
            //测试可以同时识别多个二维码
        }
    }
    
    if (_arrayResult.count < 1)
    {
        bNeedScanResult = YES;
        return;
    }
    
    if (_isNeedCaputureImage)
    {
        [self captureImage];
    }
    else
    {
        [self stopScan];
        
        if (_blockScanResult) {
            _blockScanResult(_arrayResult);
        }
    }
}


/**
 @brief  默认支持码的类别
 @return 支持类别 数组
 */
- (NSArray *)defaultMetaDataObjectTypes
{
    NSMutableArray *types = [@[AVMetadataObjectTypeQRCode,
                               AVMetadataObjectTypeUPCECode,
                               AVMetadataObjectTypeCode39Code,
                               AVMetadataObjectTypeCode39Mod43Code,
                               AVMetadataObjectTypeEAN13Code,
                               AVMetadataObjectTypeEAN8Code,
                               AVMetadataObjectTypeCode93Code,
                               AVMetadataObjectTypeCode128Code,
                               AVMetadataObjectTypePDF417Code,
                               AVMetadataObjectTypeAztecCode] mutableCopy];
    
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_8_0)
    {
        [types addObjectsFromArray:@[
                                     AVMetadataObjectTypeInterleaved2of5Code,
                                     AVMetadataObjectTypeITF14Code,
                                     AVMetadataObjectTypeDataMatrixCode
                                     ]];
    }
    
    return types;
}

#pragma mark --识别条码图片

/// 相册图常见 imageOrientation≠Up，直接 CIImage(CGImage) 像素方向错误会导致 CIDetector 识别失败；部分 UIImage 无 CGImage 时需先绘制出位图。
+ (UIImage *)lbx_imageNormalizedForQRDetection:(UIImage *)image
{
    if (!image) return nil;
    if (image.CGImage && image.imageOrientation == UIImageOrientationUp)
        return image;
    CGSize sz = image.size;
    if (sz.width < 1 || sz.height < 1)
        return image;
    UIGraphicsBeginImageContextWithOptions(sz, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, sz.width, sz.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: image;
}

/// 相册缩略图/截图过小时 CIDetector、Vision 均容易失败，适当放大像素。
+ (UIImage *)lbx_scaleUpImageIfPixelsTooSmall:(UIImage *)img minPixelMaxDimension:(CGFloat)minDim
{
    if (!img) return nil;
    CGFloat w = img.size.width * img.scale;
    CGFloat h = img.size.height * img.scale;
    CGFloat m = MAX(w, h);
    if (m >= minDim)
        return img;
    CGFloat factor = (minDim / MAX(m, 1.0)) * 1.02;
    CGSize newSize = CGSizeMake(ceil(img.size.width * factor), ceil(img.size.height * factor));
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [img drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: img;
}

/// 截图常为 Display P3 / 扩展动态范围，CIDetector/Vision 对 CGImage 解析不如相机预览稳定；压到标准动态范围再识别。
+ (UIImage *)lbx_standardBitmapFromImage:(UIImage *)image
{
    if (!image) return nil;
    CGSize sz = image.size;
    if (sz.width < 1 || sz.height < 1)
        return image;
    CGFloat sc = image.scale > 0 ? image.scale : [UIScreen mainScreen].scale;
    if (@available(iOS 12.0, *)) {
        UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat];
        fmt.opaque = NO;
        fmt.scale = sc;
        fmt.preferredRange = UIGraphicsImageRendererFormatRangeStandard;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:sz format:fmt];
        return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
            [image drawInRect:CGRectMake(0, 0, sz.width, sz.height)];
        }] ?: image;
    }
    UIGraphicsBeginImageContextWithOptions(sz, NO, sc);
    [image drawInRect:CGRectMake(0, 0, sz.width, sz.height)];
    UIImage *legacy = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return legacy ?: image;
}

/// 美化码、彩色码降低对比度；转灰并拉高对比有利于离线识别。
+ (UIImage *)lbx_ciColorControlsImage:(UIImage *)img saturation:(CGFloat)sat contrast:(CGFloat)con brightness:(CGFloat)br
{
    if (!img.CGImage)
        return nil;
    CIImage *ci = [CIImage imageWithCGImage:img.CGImage];
    if (!ci)
        return nil;
    CIFilter *f = [CIFilter filterWithName:@"CIColorControls"];
    [f setValue:ci forKey:kCIInputImageKey];
    [f setValue:@(sat) forKey:kCIInputSaturationKey];
    [f setValue:@(con) forKey:kCIInputContrastKey];
    [f setValue:@(br) forKey:kCIInputBrightnessKey];
    CIImage *out = f.outputImage;
    if (!out)
        return nil;
    CGRect extent = CGRectIntegral(ci.extent);
    CIContext *ctx = [CIContext contextWithOptions:nil];
    CGImageRef cgOut = [ctx createCGImage:out fromRect:extent];
    if (!cgOut)
        return nil;
    UIImage *u = [UIImage imageWithCGImage:cgOut scale:img.scale orientation:UIImageOrientationUp];
    CGImageRelease(cgOut);
    return u;
}

+ (UIImage *)lbx_rotateUIImage90CW:(UIImage *)image
{
    if (!image) return nil;
    CGSize s = image.size;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s.height, s.width), NO, image.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, s.height, 0);
    CGContextRotateCTM(ctx, (CGFloat)(M_PI / 2.0));
    [image drawInRect:CGRectMake(0, 0, s.width, s.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: image;
}

+ (UIImage *)lbx_rotateUIImage90CCW:(UIImage *)image
{
    if (!image) return nil;
    CGSize s = image.size;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s.height, s.width), NO, image.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, 0, s.width);
    CGContextRotateCTM(ctx, (CGFloat)(-M_PI / 2.0));
    [image drawInRect:CGRectMake(0, 0, s.width, s.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: image;
}

/// iOS 11+ Vision；同一朝向先试 CGImage 再试 CIImage（截图色域下偶有差异）。
+ (NSString *)lbx_runVisionQROnceWithHandler:(VNImageRequestHandler *)handler API_AVAILABLE(ios(11.0))
{
    VNDetectBarcodesRequest *req = [[VNDetectBarcodesRequest alloc] initWithCompletionHandler:^(__unused VNRequest *request, NSError *error) {
        (void)error;
    }];
    req.symbologies = @[VNBarcodeSymbologyQR];
    NSError *err = nil;
    if (![handler performRequests:@[req] error:&err])
        return nil;
    for (VNBarcodeObservation *obs in req.results) {
        NSString *s = obs.payloadStringValue;
        NSString *t = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length > 0)
            return t;
    }
    return nil;
}

+ (NSString *)lbx_firstVisionQRFromUIImageOneOrientation:(UIImage *)u API_AVAILABLE(ios(11.0))
{
    CGImageRef cg = u.CGImage;
    if (cg) {
        VNImageRequestHandler *h = [[VNImageRequestHandler alloc] initWithCGImage:cg options:@{}];
        NSString *pay = [self lbx_runVisionQROnceWithHandler:h];
        if (pay.length > 0)
            return pay;
        CIImage *ci = [CIImage imageWithCGImage:cg];
        if (ci) {
            VNImageRequestHandler *h2 = [[VNImageRequestHandler alloc] initWithCIImage:ci options:@{}];
            NSString *pay2 = [self lbx_runVisionQROnceWithHandler:h2];
            if (pay2.length > 0)
                return pay2;
        }
    }
    return nil;
}

/// Vision + 90°/270°（截图保存方向）。
+ (NSString *)lbx_firstQRPayloadVisionWithRotations:(UIImage *)img API_AVAILABLE(ios(11.0))
{
    NSArray<UIImage *> *candidates = @[img, [self lbx_rotateUIImage90CW:img], [self lbx_rotateUIImage90CCW:img]];
    for (UIImage *u in candidates) {
        NSString *t = [self lbx_firstVisionQRFromUIImageOneOrientation:u];
        if (t.length > 0)
            return t;
    }
    return nil;
}

+ (NSString *)lbx_firstPayloadCIDetectorWithCGImage:(CGImageRef)cg detector:(CIDetector *)detector
{
    if (!cg || !detector)
        return nil;
    NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:cg]];
    for (NSUInteger i = 0; i < features.count; i++) {
        CIQRCodeFeature *feature = features[i];
        NSString *scannedResult = feature.messageString;
        if (![scannedResult isKindOfClass:[NSString class]])
            continue;
        NSString *trimmed = [scannedResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0)
            return trimmed;
    }
    return nil;
}

/// 去重加入候选（指针不同即视为不同图）。
+ (void)lbx_addVariant:(UIImage *)img to:(NSMutableArray<UIImage *> *)list
{
    if (!img.CGImage)
        return;
    CGImageRef cg = img.CGImage;
    for (UIImage *ex in list) {
        if (ex.CGImage == cg)
            return;
    }
    [list addObject:img];
}

+ (void)recognizeImage:(UIImage*)image success:(void(^)(NSArray<LBXScanResult*> *array))block;
{
    if ([[[UIDevice currentDevice]systemVersion]floatValue] < 8.0 )
    {
        if (block) {
            LBXScanResult *result = [[LBXScanResult alloc]init];
            result.strScanned = @"只支持ios8.0之后系统";
            block(@[result]);
        }
        return;
    }

    UIImage *work = [self lbx_imageNormalizedForQRDetection:image];
    work = [self lbx_scaleUpImageIfPixelsTooSmall:work minPixelMaxDimension:960];
    if (!work.CGImage) {
        if (block) block(@[]);
        return;
    }

    NSMutableArray<UIImage *> *variants = [NSMutableArray array];
    [self lbx_addVariant:work to:variants];
    UIImage *std = [self lbx_standardBitmapFromImage:work];
    [self lbx_addVariant:std to:variants];
    UIImage *g1 = [self lbx_ciColorControlsImage:work saturation:0 contrast:1.38 brightness:0];
    [self lbx_addVariant:g1 to:variants];
    UIImage *g2 = [self lbx_ciColorControlsImage:work saturation:0 contrast:1.85 brightness:0.03];
    [self lbx_addVariant:g2 to:variants];

    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];

    NSMutableArray<LBXScanResult *> *mutableArray = [[NSMutableArray alloc] initWithCapacity:1];

    void (^tryVariants)(NSArray<UIImage *> *) = ^(NSArray<UIImage *> *imgs) {
        if (mutableArray.count > 0)
            return;
        for (UIImage *v in imgs) {
            NSString *cid = [self lbx_firstPayloadCIDetectorWithCGImage:v.CGImage detector:detector];
            if (cid.length > 0) {
                NSLog(@"LBXScanNative CIDetector result:%@", cid);
                LBXScanResult *item = [[LBXScanResult alloc] init];
                item.strScanned = cid;
                item.strBarCodeType = CIDetectorTypeQRCode;
                item.imgScanned = v;
                [mutableArray addObject:item];
                return;
            }
            if (@available(iOS 11.0, *)) {
                NSString *vid = [self lbx_firstQRPayloadVisionWithRotations:v];
                if (vid.length > 0) {
                    NSLog(@"LBXScanNative Vision result:%@", vid);
                    LBXScanResult *item = [[LBXScanResult alloc] init];
                    item.strScanned = vid;
                    item.strBarCodeType = CIDetectorTypeQRCode;
                    item.imgScanned = v;
                    [mutableArray addObject:item];
                    return;
                }
            }
        }
    };

    tryVariants(variants);

    if (mutableArray.count == 0) {
        UIImage *big = [self lbx_scaleUpImageIfPixelsTooSmall:work minPixelMaxDimension:1400];
        NSMutableArray<UIImage *> *variants2 = [NSMutableArray array];
        [self lbx_addVariant:big to:variants2];
        [self lbx_addVariant:[self lbx_standardBitmapFromImage:big] to:variants2];
        [self lbx_addVariant:[self lbx_ciColorControlsImage:big saturation:0 contrast:1.38 brightness:0] to:variants2];
        [self lbx_addVariant:[self lbx_ciColorControlsImage:big saturation:0 contrast:1.85 brightness:0.03] to:variants2];
        tryVariants(variants2);
    }

    if (block) {
        block(mutableArray);
    }
}

#pragma mark --生成条码

//下面引用自 https://github.com/yourtion/Demo_CustomQRCode
#pragma mark - InterpolatedUIImage
+ (UIImage *)createNonInterpolatedUIImageFormCIImage:(CIImage *)image withSize:(CGFloat) size {
    CGRect extent = CGRectIntegral(image.extent);
    CGFloat scale = MIN(size/CGRectGetWidth(extent), size/CGRectGetHeight(extent));
    // 创建bitmap;
    size_t width = CGRectGetWidth(extent) * scale;
    size_t height = CGRectGetHeight(extent) * scale;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CGColorSpaceRelease(cs);
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:image fromRect:extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    // 保存bitmap到图片
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    UIImage *aImage = [UIImage imageWithCGImage:scaledImage];
    CGImageRelease(scaledImage);
    return aImage;
}

#pragma mark - QRCodeGenerator
+ (CIImage *)createQRForString:(NSString *)qrString {
    NSData *stringData = [qrString dataUsingEncoding:NSUTF8StringEncoding];
    // 创建filter
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    // 设置内容和纠错级别
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"H" forKey:@"inputCorrectionLevel"];
    // 返回CIImage
    return qrFilter.outputImage;
}


#pragma mark - 生成二维码，背景色及二维码颜色设置

+ (UIImage*)createQRWithString:(NSString*)text QRSize:(CGSize)size
{
    NSData *stringData = [text dataUsingEncoding: NSUTF8StringEncoding];
    
    //生成
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"H" forKey:@"inputCorrectionLevel"];
    
    
 
    
    CIImage *qrImage = qrFilter.outputImage;
    
    //绘制
    CGImageRef cgImage = [[CIContext contextWithOptions:nil] createCGImage:qrImage fromRect:qrImage.extent];
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, CGContextGetClipBoundingBox(context), cgImage);
    UIImage *codeImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGImageRelease(cgImage);
    
    return codeImage;
}
//引用自:http://www.jianshu.com/p/e8f7a257b612
+ (UIImage*)createQRWithString:(NSString*)text QRSize:(CGSize)size QRColor:(UIColor*)qrColor bkColor:(UIColor*)bkColor
{
    
    NSData *stringData = [text dataUsingEncoding: NSUTF8StringEncoding];
    
    //生成
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"H" forKey:@"inputCorrectionLevel"];
    
    
    //上色
    CIFilter *colorFilter = [CIFilter filterWithName:@"CIFalseColor"
                                       keysAndValues:
                             @"inputImage",qrFilter.outputImage,
                             @"inputColor0",[CIColor colorWithCGColor:qrColor.CGColor],
                             @"inputColor1",[CIColor colorWithCGColor:bkColor.CGColor],
                             nil];
    
    CIImage *qrImage = colorFilter.outputImage;
    
    //绘制
    CGImageRef cgImage = [[CIContext contextWithOptions:nil] createCGImage:qrImage fromRect:qrImage.extent];
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, CGContextGetClipBoundingBox(context), cgImage);
    UIImage *codeImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGImageRelease(cgImage);
    
    return codeImage;
}

+ (UIImage*)createBarCodeWithString:(NSString*)text QRSize:(CGSize)size
{
    
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:false];
    
    CIFilter *filter = [CIFilter filterWithName:@"CICode128BarcodeGenerator"];
    
    [filter setValue:data forKey:@"inputMessage"];
    
     CIImage *barcodeImage = [filter outputImage];
    
    // 消除模糊
    
    CGFloat scaleX = size.width / barcodeImage.extent.size.width; // extent 返回图片的frame
    
    CGFloat scaleY = size.height / barcodeImage.extent.size.height;
    
    CIImage *transformedImage = [barcodeImage imageByApplyingTransform:CGAffineTransformScale(CGAffineTransformIdentity, scaleX, scaleY)];
    
    return [UIImage imageWithCIImage:transformedImage];
    
}

#pragma mark - 生成自定义风格二维码（圆形数据点 + 圆形定位角）

+ (UIImage*)createStyledQRWithString:(NSString*)text QRSize:(CGSize)size QRColor:(UIColor*)qrColor bkColor:(UIColor*)bkColor
{
    // 生成原始二维码
    NSData *stringData = [text dataUsingEncoding:NSUTF8StringEncoding];
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"H" forKey:@"inputCorrectionLevel"];
    
    CIImage *qrImage = qrFilter.outputImage;
    if (!qrImage) {
        return nil;
    }
    
    // 获取二维码的原始尺寸
    CGRect extent = qrImage.extent;
    int qrWidth = (int)extent.size.width;
    int qrHeight = (int)extent.size.height;
    
    // 创建位图上下文来读取像素数据
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    uint8_t *rawData = (uint8_t *)calloc(qrWidth * qrHeight, sizeof(uint8_t));
    CGContextRef context = CGBitmapContextCreate(rawData, qrWidth, qrHeight, 8, qrWidth, colorSpace, kCGImageAlphaNone);
    CGColorSpaceRelease(colorSpace);
    
    CIContext *ciContext = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [ciContext createCGImage:qrImage fromRect:extent];
    CGContextDrawImage(context, CGRectMake(0, 0, qrWidth, qrHeight), cgImage);
    CGImageRelease(cgImage);
    CGContextRelease(context);
    
    // 计算缩放比例
    CGFloat scale = MIN(size.width / qrWidth, size.height / qrHeight);
    CGFloat moduleSize = scale;  // 每个模块的大小
    CGFloat dotRadius = moduleSize * 0.5;  // 圆点半径（内切于模块方形，覆盖率~78.5%）
    
    // 开始绘制
    UIGraphicsBeginImageContextWithOptions(size, YES, [UIScreen mainScreen].scale);
    CGContextRef drawContext = UIGraphicsGetCurrentContext();
    
    // 填充背景色
    [bkColor setFill];
    CGContextFillRect(drawContext, CGRectMake(0, 0, size.width, size.height));
    
    // 设置前景色
    [qrColor setFill];
    
    // 定位角的位置（左上、右上、左下）- 7x7 模块大小
    int finderSize = 7;
    CGPoint finderPositions[3] = {
        CGPointMake(0, 0),                          // 左上
        CGPointMake(qrWidth - finderSize, 0),       // 右上
        CGPointMake(0, qrHeight - finderSize)       // 左下
    };
    
    // 遍历每个像素点，绘制数据区的圆形点
    for (int y = 0; y < qrHeight; y++) {
        for (int x = 0; x < qrWidth; x++) {
            uint8_t pixel = rawData[y * qrWidth + x];
            
            // 黑色像素（值为0）
            if (pixel == 0) {
                // 检查是否在定位角区域（包含1模块宽的分隔带）
                BOOL isInFinder = NO;
                for (int i = 0; i < 3; i++) {
                    int fx = (int)finderPositions[i].x;
                    int fy = (int)finderPositions[i].y;
                    if (x >= fx && x < fx + finderSize && y >= fy && y < fy + finderSize) {
                        isInFinder = YES;
                        break;
                    }
                }
                
                if (!isInFinder) {
                    // 普通数据点 - 绘制圆形
                    CGFloat centerX = (x + 0.5) * moduleSize;
                    CGFloat centerY = (y + 0.5) * moduleSize;
                    CGContextFillEllipseInRect(drawContext, CGRectMake(centerX - dotRadius, centerY - dotRadius, dotRadius * 2, dotRadius * 2));
                }
            }
        }
    }
    
    // 绘制同心圆定位角（外圆黑 → 中圆白 → 内圆黑）
    for (int i = 0; i < 3; i++) {
        CGFloat fx = finderPositions[i].x;
        CGFloat fy = finderPositions[i].y;
        CGFloat centerX = (fx + finderSize / 2.0) * moduleSize;
        CGFloat centerY = (fy + finderSize / 2.0) * moduleSize;
        
        // 外圈黑色（7个模块宽，用方形填充确保扫描兼容性）
        CGFloat outerSizePx = finderSize * moduleSize;
        CGFloat outerOriginX = fx * moduleSize;
        CGFloat outerOriginY = fy * moduleSize;
        [qrColor setFill];
        CGContextFillRect(drawContext, CGRectMake(outerOriginX, outerOriginY, outerSizePx, outerSizePx));
        
        // 在方形基础上叠加圆形，使四角变圆（用背景色擦除四角）
        // 先画一个比外框稍大的圆来保留圆形区域，再用背景色填充四角
        // 使用裁剪方式：先用背景色填充整个外框区域的四角
        CGContextSaveGState(drawContext);
        // 创建圆形路径
        CGFloat outerRadius = outerSizePx / 2.0;
        UIBezierPath *outerCircle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX - outerRadius, centerY - outerRadius, outerRadius * 2, outerRadius * 2)];
        // 创建外框矩形路径
        UIBezierPath *outerRect = [UIBezierPath bezierPathWithRect:CGRectMake(outerOriginX, outerOriginY, outerSizePx, outerSizePx)];
        // 用背景色填充矩形与圆形之间的区域（即四角）
        [outerRect appendPath:outerCircle];
        outerRect.usesEvenOddFillRule = YES;
        [bkColor setFill];
        [outerRect fill];
        CGContextRestoreGState(drawContext);
        
        // 中圈白色（5个模块宽）
        CGFloat middleRadius = (5.0 / 2.0) * moduleSize;
        [bkColor setFill];
        CGContextFillEllipseInRect(drawContext, CGRectMake(centerX - middleRadius, centerY - middleRadius, middleRadius * 2, middleRadius * 2));
        
        // 内圈黑色（3个模块宽）
        CGFloat innerRadius = (3.0 / 2.0) * moduleSize;
        [qrColor setFill];
        CGContextFillEllipseInRect(drawContext, CGRectMake(centerX - innerRadius, centerY - innerRadius, innerRadius * 2, innerRadius * 2));
    }
    
    UIImage *styledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    free(rawData);
    
    return styledImage;
}


@end
