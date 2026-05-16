//telegram @wz662
//
//
//  
//
//  Created by lbxia on 15/10/21.
//  Copyright © 2015年 lbxia. All rights reserved.
//

#import "LBXScanViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import "MBProgressHUD.h"

@interface LBXScanViewController ()

// 图片选择处理封装对象（用于上传照片时从相机或相册中选择图片的各种处理） */
@property (nonatomic, strong) RBImagePickerWrapper *imagePickerWrapper;

@end

@implementation LBXScanViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.view.backgroundColor = [UIColor blackColor];
    
    self.title = @"二维码/条形码";
    
//    // 仅用于模拟器测试时显示模拟的背景图，方便截运行图 // for DEBUG
//    UIImage *img = [UIImage imageNamed:@"CodeScan.bundle/x3"];
//    UIImageView *imgView = [[UIImageView alloc] initWithImage:img];
//    imgView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
//    imgView.contentMode = UIViewContentModeScaleAspectFill;
//    [self.view addSubview:imgView];
    
    [self drawScanView];
    // 从相册选取二维码的图片处理封装对象（原图更清晰，利于识别二维码）
    self.imagePickerWrapper = [[RBImagePickerWrapper alloc] initWithParent:self delegate:self crop:NO];
    self.imagePickerWrapper.preferAlbumOriginalPhotoForRecognition = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // ** 注意：将[self drawScanView]方法提前至viewDidLoad中，能减少黑屏延迟，提升体验。
    //         而为了让子类中调用 requestCameraPemissionWithResult尽可能晚于ui的设置，
    //         所以不在此自动调用，应用子类自行在ui设置完成后自行调用！ - by JackJiang 20220910
    
    
//    [self drawScanView];
//    [self requestCameraPemissionWithResult:^(BOOL granted) {
//        if (granted) {
//            //不延时，可能会导致界面黑屏并卡住一会
//            [self performSelector:@selector(startScan) withObject:nil afterDelay:0.3];
//
//        }else{
//            [_qRScanView stopDeviceReadying];
//        }
//    }];
}

//绘制扫描区域
- (void)drawScanView
{
    if (!_qRScanView)
    {
        CGRect rect = self.view.frame;
        rect.origin = CGPointMake(0, 0);
        self.qRScanView = [[LBXScanView alloc]initWithFrame:rect style:_style];
        [self.view addSubview:_qRScanView];
    }
    
    if (!_cameraInvokeMsg) {
//        _cameraInvokeMsg = NSLocalizedString(@"wating...", nil);
    }
    
    [_qRScanView startDeviceReadyingWithText:_cameraInvokeMsg];
}

- (void)reStartDevice
{
    switch (_libraryType) {
        case SLT_Native:
        {
            [_scanObj startScan];
        }
            break;
        default:
            break;
    }
    
}

- (void)startScanNow {
    [self requestCameraPemissionWithResult:^(BOOL granted) {
        if (granted) {
            //不延时，可能会导致界面黑屏并卡住一会
            [self performSelector:@selector(startScan) withObject:nil afterDelay:0];//0.3 (0 by jackjiang modified)

        }else{
            [_qRScanView stopDeviceReadying];
        }
    }];
}

//启动设备
- (void)startScan
{
    UIView *videoView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame))];
    videoView.backgroundColor = [UIColor clearColor];
    [self.view insertSubview:videoView atIndex:0];
    __weak __typeof(self) weakSelf = self;
    
    switch (_libraryType) {
        case SLT_Native:
        {
            if (!_scanObj )
            {
                CGRect cropRect = CGRectZero;
                if (_isOpenInterestRect) {
                    //设置只识别框内区域
                    cropRect = [LBXScanView getScanRectWithPreView:self.view style:_style];
                }

                NSString *strCode = AVMetadataObjectTypeQRCode;
                if (_scanCodeType != SCT_BarCodeITF ) {
                    strCode = [self nativeCodeWithType:_scanCodeType];
                }
                
                //AVMetadataObjectTypeITF14Code 扫码效果不行,另外只能输入一个码制，虽然接口是可以输入多个码制
                self.scanObj = [[LBXScanNative alloc]initWithPreView:videoView ObjectType:@[strCode] cropRect:cropRect success:^(NSArray<LBXScanResult *> *array) {
                    
                    [weakSelf scanResultWithArray:array];
                }];
                [_scanObj setNeedCaptureImage:_isNeedScanImage];
            }
            [_scanObj startScan];
        }
            break;
        default:
            break;
    }
    
    [_qRScanView stopDeviceReadying];
    [_qRScanView startScanAnimation];
    
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
 
    [self stopScan];
    
    [_qRScanView stopScanAnimation];
}

- (void)stopScan
{
    switch (_libraryType) {
        case SLT_Native:
        {
            [_scanObj stopScan];
            break;
        }
        default:
            break;
    }

}

#pragma mark -扫码结果处理

- (void)scanResultWithArray:(NSArray<LBXScanResult*>*)array
{
    //设置了委托的处理
    if (_delegate) {
        [_delegate scanResultWithArray:array];
    }
    
    //也可以通过继承LBXScanViewController，重写本方法即可
}



//开关闪光灯
- (void)openOrCloseFlash
{
    switch (_libraryType) {
        case SLT_Native:
        {
            [_scanObj changeTorch];
            break;
        }
        default:
            break;
    }
    self.isOpenFlash =!self.isOpenFlash;
}


//---------------------------------------------------------------------------------------------------
#pragma mark - RBImagePickerCompleteDelegate（by JackJiang 20220910，重启app后首次使用时不会像原作者代码那样卡住很久，体验提升很多）

/**
 从相册选取完成后将进入本代理方法。

 @param image 图片对象
 @param tag debug的TAG
 */
- (void)processImagePickerComplete:(UIImage *)image withTag:(NSString *)tag
{
    if(image == nil)
    {
        [BasicTool showAlertError:@"相册选择失败!" parent:self];
        return;
    }

    // 显示进度提示菊花
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = @"识别中..";

    __weak __typeof(self) weakSelf = self;
    
    // 开始进行二维码识别（异步线程中执行，提升体验）
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        @try{
            switch (_libraryType) {
                case SLT_Native:
                {
                    if ([[[UIDevice currentDevice]systemVersion]floatValue] >= 8.0)
                    {
                        [LBXScanNative recognizeImage:image success:^(NSArray<LBXScanResult *> *array) {
                            // recognizeImage 在后台线程同步回调；结果与 UI 必须回到主线程（原先若在主线程调用 success 则既不关 HUD 也不回调，相册路径会“扫不出来”）
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [hud hideAnimated:NO];
                                [weakSelf scanResultWithArray:array];
                            });
                        }];
                    }
                    else
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf showError:@"系统版本低于iOS 8.0时，将不支持从图片识别二维码！"];
                        });
                    }
                    break;
                }
                case SLT_ZXing:
                {
                    break;
                }
                    
                case SLT_ZBar:
                {
                    break;
                }
                default:
                    break;
            }
            
        } @catch(NSException *exception) {
            NSLog(@"%@",exception);
            dispatch_async(dispatch_get_main_queue(), ^{
                AlertInfo(@"清空失败，请稍后再试！");
            });
        } @finally {
            // 确保进度提示被及时关闭
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [hud hideAnimated:NO];
                });
            }
            else {
                [hud hideAnimated:NO];
            }
        }
    });
}


//# pragma mark --打开相册并识别图片（by LBXScan库作者，原先的判断相册权限并选取图片的方法会导致每次重启app后，首次打开相册时，会卡住起码5秒，严重影响体验）

/*!
 *  打开本地照片，选择图片识别
 */
- (void)openLocalPhoto:(BOOL)allowsEditing
{
//    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
//    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
//    picker.delegate = self;
//    //部分机型有问题
//    picker.allowsEditing = allowsEditing;
//
//    [self presentViewController:picker animated:YES completion:nil];
    
    // 进入相册选择图片（by JackJiang 20220910）
    [self.imagePickerWrapper takeAlbum:NO];
}
//
////当选择一张图片后进入这里
//-(void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
//{
//    [picker dismissViewControllerAnimated:YES completion:nil];
//
//    __block UIImage* image = [info objectForKey:UIImagePickerControllerEditedImage];
//
//    if (!image){
//        image = [info objectForKey:UIImagePickerControllerOriginalImage];
//    }
//
//    __weak __typeof(self) weakSelf = self;
//
//    switch (_libraryType) {
//        case SLT_Native:
//        {
//            if ([[[UIDevice currentDevice]systemVersion]floatValue] >= 8.0)
//            {
//                [LBXScanNative recognizeImage:image success:^(NSArray<LBXScanResult *> *array) {
//                    [weakSelf scanResultWithArray:array];
//                }];
//            }
//            else
//            {
//                [self showError:@"native低于ios8.0系统不支持识别图片条码"];
//            }
//        }
//            break;
//        case SLT_ZXing:
//        {
//
//        }
//            break;
//        case SLT_ZBar:
//        {
//        }
//            break;
//
//        default:
//            break;
//    }
//}
//- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
//{
//    NSLog(@"cancel");
//
//    [picker dismissViewControllerAnimated:YES completion:nil];
//}
//# pragma mark -------------------------------------------------------------------------

- (NSString*)nativeCodeWithType:(SCANCODETYPE)type
{
    switch (type) {
        case SCT_QRCode:
            return AVMetadataObjectTypeQRCode;
            break;
        case SCT_BarCode93:
            return AVMetadataObjectTypeCode93Code;
            break;
        case SCT_BarCode128:
            return AVMetadataObjectTypeCode128Code;
            break;
        case SCT_BarCodeITF:
            return @"ITF条码:only ZXing支持";
            break;
        case SCT_BarEAN13:
            return AVMetadataObjectTypeEAN13Code;
            break;

        default:
            return AVMetadataObjectTypeQRCode;
            break;
    }
}

- (void)showError:(NSString*)str
{
    
}

- (void)requestCameraPemissionWithResult:(void(^)( BOOL granted))completion
{
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)])
    {
        AVAuthorizationStatus permission =
        [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        
        switch (permission) {
            case AVAuthorizationStatusAuthorized:
                completion(YES);
                break;
            case AVAuthorizationStatusDenied:
            case AVAuthorizationStatusRestricted:
                completion(NO);
                break;
            case AVAuthorizationStatusNotDetermined:
            {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                         completionHandler:^(BOOL granted) {
                                             
                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                 if (granted) {
                                                     completion(true);
                                                 } else {
                                                     completion(false);
                                                 }
                                             });
                                             
                                         }];
            }
                break;
        }
    }
}

+ (BOOL)photoPermission
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 8.0)
    {
        ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];
        if ( author == ALAuthorizationStatusDenied ) {
            return NO;
        }
        return YES;
    }
    
    PHAuthorizationStatus authorStatus = [PHPhotoLibrary authorizationStatus];
    if ( authorStatus == PHAuthorizationStatusDenied ) {
        return NO;
    }
    return YES;
}

@end
