//telegram @wz662
#import "RBImagePickerWrapper.h"
#import "TZImagePickerController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import "TZImageManager.h"
#import "AppDelegate.h"
#import "MBProgressHUD.h"
#import "BasicTool.h"


@interface RBImagePickerWrapper ()
/** 父view控制器对象引用 */
//### Bug FIX: 20191119, 由strong 改为 weak
//      注意：因作为主类的parentViewController中会引用 RBImagePickerWrapper，那么作为2级子类的RBImagePickerWrapper
//      中肯定再不能使用strong来引用上级父界面，不然就会出现循环引用而导致父界面无法在内存中被释放的问题.
@property (nonatomic, weak) UIViewController *parentViewController;//### Bug FIX: END
/** 拍完照或相册选取完成后的预览界面 */
@property (nonatomic, strong) UIImagePickerController *imagePickerVc;
/** 是否允许裁剪图片（可用于用户头像的图片处理时），默认NO */
@property (nonatomic, assign) BOOL enableCrop;
@end


@implementation RBImagePickerWrapper 

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
// 实例化imagePickerVc对象，此对象的UI显示就是拍完照或相册选取完成后的预览界面
- (UIImagePickerController *)imagePickerVc
{
    if (_imagePickerVc == nil)
    {
        _imagePickerVc = [[UIImagePickerController alloc] init];
        _imagePickerVc.delegate = self;
        // set appearance / 改变相册选择页的导航栏外观
        _imagePickerVc.navigationBar.barTintColor = self.parentViewController.navigationController.navigationBar.barTintColor;
        _imagePickerVc.navigationBar.tintColor = self.parentViewController.navigationController.navigationBar.tintColor;
        UIBarButtonItem *tzBarItem, *BarItem;
        if (@available(iOS 9, *))
        {
            tzBarItem = [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[TZImagePickerController class]]];
            BarItem = [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UIImagePickerController class]]];
        }
        else
        {
            tzBarItem = [UIBarButtonItem appearanceWhenContainedIn:[TZImagePickerController class], nil];
            BarItem = [UIBarButtonItem appearanceWhenContainedIn:[UIImagePickerController class], nil];
        }
        NSDictionary *titleTextAttributes = [tzBarItem titleTextAttributesForState:UIControlStateNormal];
        [BarItem setTitleTextAttributes:titleTextAttributes forState:UIControlStateNormal];

    }
    return _imagePickerVc;
}

- (id)initWithParent:(UIViewController *)parentViewController delegate:(id<RBImagePickerCompleteDelegate>)imagePickerCompleteDelegate
{
    // 默认不支持图片裁剪
    return [self initWithParent:parentViewController delegate:imagePickerCompleteDelegate crop:NO];
}

- (id)initWithParent:(UIViewController *)parentViewController delegate:(id<RBImagePickerCompleteDelegate>)imagePickerCompleteDelegate crop:(BOOL)enableCrop
{
    if (![super init])
        return nil;

    self.parentViewController = parentViewController;
    self.imagePickerCompleteDelegate = imagePickerCompleteDelegate;
    self.enableCrop = enableCrop;

    DDLogDebug(@"[图片选择wrapper] RBImagePickerWrapper已经init了！");

    return self;
}


//---------------------------------------------------------------------------------------------------
#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) { // 去设置界面，开启相机访问权限
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - UIImagePickerController

// 使用相机拍照并发送图片消息入口方法
- (void)takePhoto
{
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if ((authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)) {
        // 无相机权限 做一个友好的提示
        UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"无法使用相机" message:@"请在iPhone的""设置-隐私-相机""中允许访问相机" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
        [alert show];
    } else if (authStatus == AVAuthorizationStatusNotDetermined) {
        // fix issue 466, 防止用户首次拍照拒绝授权时相机页黑屏
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self takePhoto];
                });
            }
        }];
        // 拍照之前还需要检查相册权限
    } else if ([PHPhotoLibrary authorizationStatus] == 2) { // 已被拒绝，没有相册权限，将无法保存拍的照片
        UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"无法访问相册" message:@"请在iPhone的""设置-隐私-相册""中允许访问相册" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
        [alert show];
    } else if ([PHPhotoLibrary authorizationStatus] == 0) { // 未请求过相册权限
        [[TZImageManager manager] requestAuthorizationWithCompletion:^{
            [self takePhoto];
        }];
    } else { // 调用相机
//        UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
//        if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
//            self.imagePickerVc.sourceType = sourceType;
//            if(iOS8Later) {
//                _imagePickerVc.modalPresentationStyle = UIModalPresentationOverCurrentContext;
//            }
//            [self.parentViewController presentViewController:_imagePickerVc animated:YES completion:nil];
//        } else {
//            AlertInfo(@"【图片选择wrapper处理时从相机】模拟器中无法打开照相机,请在真机中使用");
//        }
        
        [self pushImagePickerController];
    }
}

// 调用相机（同时支持拍照和录制视频，最长60秒）
- (void)pushImagePickerController {
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        self.imagePickerVc.sourceType = sourceType;
        
        // 同时启用拍照和录像
        NSMutableArray *mediaTypes = [NSMutableArray array];
        [mediaTypes addObject:(NSString *)kUTTypeImage];
        [mediaTypes addObject:(NSString *)kUTTypeMovie];
        _imagePickerVc.mediaTypes = mediaTypes;
        
        // 视频最长录制60秒
        _imagePickerVc.videoMaximumDuration = 60.0;
        // 视频质量：中等（平衡清晰度和文件大小）
        _imagePickerVc.videoQuality = UIImagePickerControllerQualityTypeMedium;
        
        [self.parentViewController presentViewController:_imagePickerVc animated:YES completion:nil];
    } else {
        NSLog(@"【图片选择wrapper处理时从相机】模拟器中无法打开照相机,请在真机中使用");
        [BasicTool showAlertInfo:@"模拟器中无法打开照相机,请在真机中使用！" parent:self.parentViewController];
    }
}

// 使用相机拍照/录像回调：相机拍完照片或录制完视频后的回调代理方法
- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    __weak typeof(self) weakSelf = self;
    
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
    
    // ========== 拍照结果处理 ==========
    if ([type isEqualToString:(NSString *)kUTTypeImage])
    {
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        NSDictionary *meta = [info objectForKey:UIImagePickerControllerMediaMetadata];
        
        DDLogDebug(@"【图片选择wrapper处理时从相机】照片拍摄完成，马上进入下一步处理 ...");
        
        TZImagePickerController *tzImagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:1 delegate:self];
        tzImagePickerVc.sortAscendingByModificationDate = YES;
        [tzImagePickerVc showProgressHUD];
        
        // save photo and get asset / 保存图片，获取到asset
        [[TZImageManager manager] savePhotoWithImage:image meta:meta location:nil completion:^(PHAsset *asset, NSError *error){
            [tzImagePickerVc hideProgressHUD];
            if (error)
            {
                DDLogDebug(@"【图片选择wrapper处理时从相机】拍好照片后，因裁剪需要保存到相册，但保存失败：%@",error);
            }
            else
            {
                // 头像场景也不裁剪，直接上传；非头像场景同样直接上传
                [weakSelf.imagePickerCompleteDelegate processImagePickerComplete:image withTag:@"图片选择wrapper处理完成从【相机】"];
            }
        }];
    }
    // ========== 录像结果处理 ==========
    else if ([type isEqualToString:(NSString *)kUTTypeMovie])
    {
        NSURL *videoURL = info[UIImagePickerControllerMediaURL];
        if (videoURL)
        {
            DDLogDebug(@"【视频录制wrapper处理时从相机】视频录制完成，路径：%@", videoURL.path);
            
            // 获取视频时长
            AVURLAsset *videoAsset = [AVURLAsset assetWithURL:videoURL];
            CMTime duration = videoAsset.duration;
            int durationSeconds = (int)ceil(CMTimeGetSeconds(duration));
            if (durationSeconds <= 0) durationSeconds = 1;
            
            DDLogDebug(@"【视频录制wrapper处理时从相机】视频时长：%d秒", durationSeconds);
            
            // 通过视频代理方法回调
            if ([weakSelf.imagePickerCompleteDelegate respondsToSelector:@selector(processVideoPickerComplete:duration:withTag:)]) {
                [weakSelf.imagePickerCompleteDelegate processVideoPickerComplete:videoURL.path
                                                                       duration:durationSeconds
                                                                        withTag:@"视频录制完成从【相机】"];
            }
        }
        else
        {
            DDLogDebug(@"【视频录制wrapper处理时从相机】视频URL为空，无法处理！");
        }
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - TZImagePickerController

// 使用相册并发送图片消息入口方法
- (void)takeAlbum:(BOOL)allowPickingVideo
{
    // 最多可选择9张图片（如果是裁剪模式则只允许选1张）
    NSInteger maxCount = self.enableCrop ? 1 : 9;
    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:maxCount columnNumber:4 delegate:self pushPhotoPickerVc:YES];

    imagePickerVc.isSelectOriginalPhoto = YES;
    // 在内部显示拍照按钮
    imagePickerVc.allowTakePicture = NO;
    // 在内部显示拍视频按
    imagePickerVc.allowTakeVideo = NO;

    // 2. Set the appearance
    // 2. 在这里设置imagePickerVc的外观 （为了UI视觉的一致性，以下导航栏的样式设定，请与 NavigationController.m 中保持一致哦！）
    imagePickerVc.navigationBar.translucent = NO;
    // ** 针对ios 26的优化：为了适配ios 26最新标题栏沉浸式效果，背景等属于用系统默认的会更好 - add by jackjiang 20250933
    if (@available(iOS 26, *)) {
        // 顶部导航栏标题栏背景色
        imagePickerVc.navigationBar.barTintColor = [UIColor clearColor];//RGBCOLOR(255, 255, 255);
        
        // 顶部导航栏上的“返回”、“取消”等文字按钮的字体颜色
        imagePickerVc.barItemTextColor = HexColor(0x181a1c);
        // 顶部导航栏上的“返回”、“取消”等文字按钮的字体大小
        imagePickerVc.barItemTextFont = [BasicTool getSystemFontOfSize:17];
    }
    else {
        // 顶部导航栏标题栏背景色
        imagePickerVc.navigationBar.barTintColor = UI_DEFAULT_TITLE_BG_COLOR;//RGBCOLOR(255, 255, 255);
        // 设置顶部导航栏上按钮的颜色
        imagePickerVc.navigationBar.tintColor = UI_DEFAULT_HILIGHT_COLOR;
    //    imagePickerVc.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName:UI_DEFAULT_HILIGHT_COLOR};
        // 顶部导航栏标题字体大小和标题颜色
        [imagePickerVc.navigationBar setTitleTextAttributes:@{NSFontAttributeName:[BasicTool getSystemFontOfSize:UI_DEFAULT_TITLE_FONT_SIZE]//20]
                                                     ,NSForegroundColorAttributeName:UI_DEFAULT_TITLE_FONT_COLOR}];
        // 设置 navigationBar 下面的横线（记住要用@2x、@3x命名，否则按@1x进行填充时显示的线条不只一个像素高度，就很难看。另，
        // 也不建议用春色UIImage对象，因为代码中设置的像素高度并不是绝对像素，所以会存在横线显示高度粗线难控制的问题）
        [imagePickerVc.navigationBar setShadowImage:[UIImage imageNamed:@"navigation_bar_shadow_image"]];
        
        // 顶部导航栏上的“返回”、“取消”等文字按钮的字体颜色
        imagePickerVc.barItemTextColor = UI_DEFAULT_HILIGHT_COLOR;
        // 顶部导航栏上的“返回”、“取消”等文字按钮的字体大小
        imagePickerVc.barItemTextFont = [BasicTool getSystemFontOfSize:17];
    }
    
    // 未选中时确认按钮为灰色，选中时为红色
    imagePickerVc.oKButtonTitleColorDisabled = [UIColor grayColor];
    imagePickerVc.oKButtonTitleColorNormal = HexColor(0xc1342d);
    imagePickerVc.doneBtnTitleStr = @"确认";
    
    // 确认按钮整体下移一点（视觉上更靠下）
    imagePickerVc.photoPickerPageDidLayoutSubviewsBlock = ^(UICollectionView *collectionView, UIView *bottomToolBar, UIButton *previewButton, UIButton *originalPhotoButton, UILabel *originalPhotoLabel, UIButton *doneButton, UIImageView *numberImageView, UILabel *numberLabel, UIView *divideLine) {
        CGRect r = doneButton.frame;
        if (r.size.height > 0) {
            CGFloat downOffset = 8.0;
            doneButton.frame = CGRectMake(r.origin.x, r.origin.y + downOffset, r.size.width, r.size.height);
        }
    };
    
    // 状态栏文字颜色（不设的话，将默认设为白色）
    imagePickerVc.navigationBar.barStyle = UIBarStyleDefault;
    
    // 设置系统最上方的状态栏字体颜色（默认是NO，表示用的是白色，即UIStatusBarStyleLightContent）
    imagePickerVc.isStatusBarDefault = YES;
    

    // 3. Set allow picking video & photo & originalPhoto or not
    // 3. 设置是否可以选择视频/图片/原图
    // 头像场景：允许显示视频相册和视频资源（选视频时仅提示请选图片/GIF），其它场景按参数
    BOOL showVideo = self.enableCrop ? YES : allowPickingVideo;
    imagePickerVc.allowPickingVideo = showVideo;
    imagePickerVc.allowPickingImage = YES;
    imagePickerVc.allowPickingOriginalPhoto = self.preferAlbumOriginalPhotoForRecognition ? YES : NO;

    // 头像场景：单选、允许 GIF，不裁剪直接上传
    if(self.enableCrop)
    {
        imagePickerVc.allowCrop = NO;   // 不需要裁剪，选完直接上传
        imagePickerVc.allowPickingGif = YES;
    }
    else
    {
        imagePickerVc.allowPickingGif = NO;
    }
    

    // 4. 照片排列按修改时间升序
    imagePickerVc.sortAscendingByModificationDate = YES;

    /// 5. Single selection mode, valid when maxImagesCount = 1
    /// 5. 单选模式,maxImagesCount为1时才生效；多选模式需要显示选择按钮
    imagePickerVc.showSelectBtn = (maxCount > 1) ? YES : NO;

    // You can get the photos by block, the same as by delegate.
    // 你可以通过block或者代理，来得到用户选择的照片.
    [imagePickerVc setDidFinishPickingPhotosHandle:^(NSArray<UIImage *> *photos, NSArray *assets, BOOL isSelectOriginalPhoto) {

    }];

    imagePickerVc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self.parentViewController presentViewController:imagePickerVc animated:YES completion:nil];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - TZImagePickerControllerDelegate

// 从相册选取图片回调：用户点击了取消按钮时的回调代码实现方法
- (void)tz_imagePickerControllerDidCancel:(TZImagePickerController *)picker
{
    DDLogDebug(@"【图片选择wrapper处理时从相册选图】cancel");
}

// 从相册选取图片回调：选取图片正常完成后的回调代理方法
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingPhotos:(NSArray *)photos sourceAssets:(NSArray *)assets isSelectOriginalPhoto:(BOOL)isSelectOriginalPhoto
{
    // for debug：打印图片名字
    DDLogDebug(@"【图片选择wrapper处理时从相册选图】assets》选中了%lu张图片", (unsigned long)[photos count]);
//    [self printAssetsName:assets];

    if([photos count] <= 0)
    {
        [APP showToastWarn:@"没有选中任何图片，无法发送图片消息！"];
        return;
    }

    // 多张图片选择：优先调用多图代理方法
    if ([photos count] > 1 && [self.imagePickerCompleteDelegate respondsToSelector:@selector(processMultiImagePickerComplete:withTag:)]) {
        [self.imagePickerCompleteDelegate processMultiImagePickerComplete:photos withTag:@"图片选择wrapper处理完成从【相册】"];
    }
    // 扫一扫等：用 Photos 框架请求高质量 imageData，避免仅用 TZ 列表里的预览图导致二维码识别失败
    else if (self.preferAlbumOriginalPhotoForRecognition && [photos count] == 1 && [assets count] >= 1 && [assets[0] isKindOfClass:[PHAsset class]]) {
        PHAsset *asset = (PHAsset *)assets[0];
        __weak typeof(self) weakSelf = self;
        PHImageRequestOptions *opt = [[PHImageRequestOptions alloc] init];
        opt.networkAccessAllowed = YES;
        opt.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        opt.resizeMode = PHImageRequestOptionsResizeModeNone;
        [[PHImageManager defaultManager] requestImageDataForAsset:asset options:opt resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            BOOL cancelled = [[info objectForKey:PHImageCancelledKey] boolValue];
            UIImage *img = nil;
            if (!cancelled && imageData.length > 0) {
                img = [UIImage imageWithData:imageData];
                if (img) {
                    img = [[TZImageManager manager] fixOrientation:img];
                }
            }
            if (!img) {
                img = photos[0];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakSelf.imagePickerCompleteDelegate && [weakSelf.imagePickerCompleteDelegate respondsToSelector:@selector(processImagePickerComplete:withTag:)]) {
                    [weakSelf.imagePickerCompleteDelegate processImagePickerComplete:img withTag:@"图片选择wrapper处理完成从【相册】"];
                }
            });
        }];
        return;
    }
    // 单张：头像场景下若是 GIF 则走 GIF 回调（不裁剪，原图上传）
    else if (self.enableCrop && [photos count] == 1 && [assets count] >= 1) {
        id firstAsset = assets[0];
        if ([firstAsset isKindOfClass:[PHAsset class]]) {
            __weak typeof(self) weakSelf = self;
            [[TZImageManager manager] getOriginalPhotoDataWithAsset:(PHAsset *)firstAsset completion:^(NSData *data, NSDictionary *info, BOOL isDegraded) {
                if (isDegraded || !data || data.length < 6) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf.imagePickerCompleteDelegate processImagePickerComplete:(UIImage *)photos[0] withTag:@"图片选择wrapper处理完成从【相册】"];
                    });
                    return;
                }
                const char *bytes = (const char *)data.bytes;
                BOOL isGif = (bytes[0]=='G' && bytes[1]=='I' && bytes[2]=='F' && bytes[3]=='8' && (bytes[4]=='7'||bytes[4]=='9') && bytes[5]=='a');
                if (isGif && [weakSelf.imagePickerCompleteDelegate respondsToSelector:@selector(processImagePickerCompleteWithGifFileURL:withTag:)]) {
                    NSString *tmp = NSTemporaryDirectory();
                    NSString *gifPath = [tmp stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
                    gifPath = [gifPath stringByAppendingPathExtension:@"gif"];
                    NSError *err = nil;
                    if ([data writeToFile:gifPath options:NSDataWritingAtomic error:&err]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf.imagePickerCompleteDelegate processImagePickerCompleteWithGifFileURL:[NSURL fileURLWithPath:gifPath] withTag:@"图片选择wrapper处理完成从【相册】GIF"];
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf.imagePickerCompleteDelegate processImagePickerComplete:(UIImage *)photos[0] withTag:@"图片选择wrapper处理完成从【相册】"];
                        });
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf.imagePickerCompleteDelegate processImagePickerComplete:(UIImage *)photos[0] withTag:@"图片选择wrapper处理完成从【相册】"];
                    });
                }
            }];
            return;
        }
        [self.imagePickerCompleteDelegate processImagePickerComplete:(UIImage *)photos[0] withTag:@"图片选择wrapper处理完成从【相册】"];
    }
    else {
        UIImage *fallback = photos[0];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.imagePickerCompleteDelegate processImagePickerComplete:fallback withTag:@"图片选择wrapper处理完成从【相册】"];
        });
    }
}

// 从相册选取 GIF 动图回调：用户在 TZGifPhotoPreviewController 点「完成」时走此路径，不会走 didFinishPickingPhotos
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingGifImage:(UIImage *)animatedImage sourceAssets:(PHAsset *)asset {
    if (!asset || ![self.imagePickerCompleteDelegate respondsToSelector:@selector(processImagePickerCompleteWithGifFileURL:withTag:)]) {
        if (animatedImage) {
            [self.imagePickerCompleteDelegate processImagePickerComplete:animatedImage withTag:@"图片选择wrapper处理完成从【相册】GIF预览"];
        }
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[TZImageManager manager] getOriginalPhotoDataWithAsset:asset completion:^(NSData *data, NSDictionary *info, BOOL isDegraded) {
        if (isDegraded || !data || data.length < 6) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (animatedImage)
                    [weakSelf.imagePickerCompleteDelegate processImagePickerComplete:animatedImage withTag:@"图片选择wrapper处理完成从【相册】GIF"];
            });
            return;
        }
        const char *bytes = (const char *)data.bytes;
        BOOL isGif = (bytes[0]=='G' && bytes[1]=='I' && bytes[2]=='F' && bytes[3]=='8' && (bytes[4]=='7'||bytes[4]=='9') && bytes[5]=='a');
        if (isGif) {
            NSString *tmp = NSTemporaryDirectory();
            NSString *gifPath = [tmp stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
            gifPath = [gifPath stringByAppendingPathExtension:@"gif"];
            NSError *err = nil;
            if ([data writeToFile:gifPath options:NSDataWritingAtomic error:&err]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.imagePickerCompleteDelegate processImagePickerCompleteWithGifFileURL:[NSURL fileURLWithPath:gifPath] withTag:@"图片选择wrapper处理完成从【相册】GIF"];
                });
                return;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (animatedImage)
                [weakSelf.imagePickerCompleteDelegate processImagePickerComplete:animatedImage withTag:@"图片选择wrapper处理完成从【相册】GIF"];
        });
    }];
}

// 从相册选取视频回调：选取视频正常完成后的回调代理方法 - @since 7.0
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingVideo:(UIImage *)coverImage sourceAssets:(PHAsset *)asset {
    // 头像场景：仅允许 5 秒以内的短视频作为头像（与《用户头像-前端对接文档》一致）
    if (self.enableCrop) {
        if (asset.duration > 5.0) {
            [APP showToastWarn:@"请选择5秒以内的视频，或图片、GIF作为头像"];
            return;
        }
        // ≤5s 短视频走 processVideoPickerComplete，由 delegate 上传为头像
    }
    // 显示进度提示菊花
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.parentViewController.view animated:YES];
    hud.label.text = @"视频准备中..";
    
    // open this code to send video / 打开这段代码发送视频
    // 使用 Passthrough 模式直接传输原始视频，不重编码，保持原画质
    [[TZImageManager manager] getVideoOutputPathWithAsset:asset presetName:AVAssetExportPresetPassthrough success:^(NSString *outputPath) {
        
        // 隐藏进度提示菊花
        [hud hideAnimated:NO];
        
        // NSData *data = [NSData dataWithContentsOfFile:outputPath];
        // Export completed, send video here, send by outputPath or NSData
        // 导出完成，在这里写上传代码，通过路径或者通过NSData上传
        
        int duration = [[NSNumber numberWithDouble:asset.duration] intValue];
        
        DDLogDebug(@"【图片选择wrapper处理时从相册选视频】assets》视频获取完成，沙盒路径为=%@, duration=%d", outputPath, duration);
        
        if(outputPath == nil) {
            [APP showToastWarn:@"没有选中任何视频，无法发送视频消息！"];
            return;
        }
        
        // 视频选择完成，交给开发者的代理方法去处理了
        [self.imagePickerCompleteDelegate processVideoPickerComplete:outputPath duration:duration withTag:@"视频选择wrapper处理完成从【相册】"];
    } failure:^(NSString *errorMessage, NSError *error) {
        NSLog(@"【图片选择wrapper处理时从相册选视频】视频导出失败: %@, error: %@",errorMessage, error);
    }];
}


////---------------------------------------------------------------------------------------------------
//#pragma mark - 其它方法
//
//// 打印图片名字
//- (void)printAssetsName:(NSArray *)assets {
//    NSString *fileName;
//    for (id asset in assets) {
//        if ([asset isKindOfClass:[PHAsset class]]) {
//            PHAsset *phAsset = (PHAsset *)asset;
//            fileName = [phAsset valueForKey:@"filename"];
//        } else if ([asset isKindOfClass:[ALAsset class]]) {
//            ALAsset *alAsset = (ALAsset *)asset;
//            fileName = alAsset.defaultRepresentation.filename;;
//        }
//        NSLog(@"【从相册选图】>> 选中的图片名字:%@",fileName);
//    }
//}

@end
