//telegram @wz662
//
//
//
//
//  Created by lbxia on 15/10/21.
//  Copyright © 2015年 lbxia. All rights reserved.
//

#import "QQLBXScanViewController.h"
#import "CreateBarCodeViewController.h"
#import "LBXScanVideoZoomView.h"
#import "LBXPermission.h"
#import "LBXPermissionSetting.h"
#import "ViewControllerFactory.h"
#import "LPActionSheet.h"
#import <AudioToolbox/AudioToolbox.h>
#import "PromtHelper.h"

@interface QQLBXScanViewController ()
@property (nonatomic, strong) LBXScanVideoZoomView *zoomView;
@end

@implementation QQLBXScanViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    self.view.backgroundColor = [UIColor blackColor];
    
    //设置扫码后需要扫码图像
    self.isNeedScanImage = NO;// YES
    
    self.title = @"扫一扫";

  [self drawTitleItems];
    [self drawBottomItems];
    [self.view bringSubviewToFront:_titleItemsView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // ** ui的设置放在viewDidLoad中能减少界面黑屏延迟，提升体验
    
//    self.title = @"扫一扫";

    // 由于self.view.safeAreaInsets.top值只能在此方法中正确获取到，所以title栏只能放在此方法中显示了
//  [self drawTitleItems];
    DDLogDebug(@"QQLBXScanViewController中，self.view.safeAreaInsets.top=%f", self.view.safeAreaInsets.top);
    // 设置状态栏高度frame，用于支持流海屏下的标题栏显示（因self.view.safeAreaInsets.top值只能在viewDidAppear中正确获取到，所以这里来设置它的frame才正确）
    self.titleItemsView.frame = CGRectMake(0, self.view.safeAreaInsets.top, CGRectGetWidth(self.view.frame), 50.0f);
    
//    [self drawBottomItems];
//    [self.view bringSubviewToFront:_titleItemsView];
    
    [self startScanNow];
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
    // 取消隐藏导航栏
    [self showNavigation];
}

////绘制扫描区域
//- (void)drawTitle
//{
//    if (!_bottomLabel)
//    {
//        self.bottomLabel = [[UILabel alloc]init];
//        _bottomLabel.bounds = CGRectMake(0, 0, 320, 20);
//        _bottomLabel.center = CGPointMake(CGRectGetWidth(self.view.frame)/2, 50);
//
//        //3.5inch iphone
//        if ([UIScreen mainScreen].bounds.size.height <= 568 )
//        {
//            _bottomLabel.center = CGPointMake(CGRectGetWidth(self.view.frame)/2, 38);
//            _bottomLabel.font = [UIFont systemFontOfSize:14];
//        }
//
//        _bottomLabel.textAlignment = NSTextAlignmentCenter;
//        _bottomLabel.numberOfLines = 0;
//        _bottomLabel.text = @"手机对准二维码，将自动扫描识别";
//        _bottomLabel.textColor = HexColor(0xC0C0C0);//[UIColor whiteColor];
//
//        _bottomLabel.backgroundColor = [UIColor redColor];
//
//        [self.view addSubview:_bottomLabel];
//    }
//}

- (void)cameraInitOver
{
    if (self.isVideoZoom) {
        [self zoomView];
    }
}

- (LBXScanVideoZoomView*)zoomView
{
    if (!_zoomView)
    {
        CGRect frame = self.view.frame;
        
        int XRetangleLeft = self.style.xScanRetangleOffset;
        
        CGSize sizeRetangle = CGSizeMake(frame.size.width - XRetangleLeft*2, frame.size.width - XRetangleLeft*2);
        
        if (self.style.whRatio != 1)
        {
            CGFloat w = sizeRetangle.width;
            CGFloat h = w / self.style.whRatio;
            
            NSInteger hInt = (NSInteger)h;
            h  = hInt;
            
            sizeRetangle = CGSizeMake(w, h);
        }
        
        CGFloat videoMaxScale = [self.scanObj getVideoMaxScale];
        
        //扫码区域Y轴最小坐标
        CGFloat YMinRetangle = frame.size.height / 2.0 - sizeRetangle.height/2.0 - self.style.centerUpOffset;
        CGFloat YMaxRetangle = YMinRetangle + sizeRetangle.height;
        
        CGFloat zoomw = sizeRetangle.width + 40;
        _zoomView = [[LBXScanVideoZoomView alloc]initWithFrame:CGRectMake((CGRectGetWidth(self.view.frame)-zoomw)/2, YMaxRetangle + 40, zoomw, 18)];
        
        [_zoomView setMaximunValue:videoMaxScale/4];
        
        
        __weak __typeof(self) weakSelf = self;
        _zoomView.block= ^(float value)
        {            
            [weakSelf.scanObj setVideoScale:value];
        };
        [self.view addSubview:_zoomView];
                
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tap)];
        [self.view addGestureRecognizer:tap];
    }
    
    return _zoomView;
   
}

- (void)tap
{
    _zoomView.hidden = !_zoomView.hidden;
}

- (void)drawTitleItems
{
    if (_titleItemsView) {
        return;
    }
    
//  float titleItemsViewH = 50.0f, buttonW = 60.0f, buttonH = titleItemsViewH;
//  float titleItemsViewH = 50.0f, buttonW = 50.0f, buttonH = titleItemsViewH;
    float buttonW = 36.0f, buttonH = buttonW;
    // 标题功能按钮左右的空白间距
//  float buttonLeftOrRightGap  = 15.0f;
    float buttonLeftOrRightGap  = 25.0f;
    
    // 状态栏高度（用于支持流海屏下的标题栏显示）
    float statusBarH = 20;
    if (@available(iOS 11.0, *)) {
        // 注意：此值只能在viewDidAppear中获取，否则是获取不到的
        statusBarH = self.view.safeAreaInsets.top;
        DDLogDebug(@"QQLBXScanViewController中，self.view.safeAreaInsets.top=%f", self.view.safeAreaInsets.top);
    }
    
    // 总体父布局组件
//  self.titleItemsView = [[UIView alloc]initWithFrame:CGRectMake(0, statusBarH, CGRectGetWidth(self.view.frame), titleItemsViewH)];
    self.titleItemsView = [[UIView alloc]initWithFrame:CGRectZero];// 这个frame将在viewDidAppear中被设置，因它的高度依赖的safeAreaInsets.top只在此时才能正确获取到结果
    _titleItemsView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];//[UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];
    [self.view addSubview:_titleItemsView];
    
    //** 返回按钮
    UIButton *btnBack = [UIButton buttonWithType:UIButtonTypeCustom];
//    btnBack.layer.cornerRadius = buttonH/2.0f;//6;
//    btnBack.layer.masksToBounds = YES;
    btnBack.frame = CGRectMake(buttonLeftOrRightGap, 0, buttonW, buttonH);
//    [btnBack setImage:[UIImage imageNamed:@"CodeScan.bundle/widget_title_btn_back_light_normal"] forState:UIControlStateNormal];
//    [btnBack setImage:[UIImage imageNamed:@"CodeScan.bundle/widget_title_btn_back_light_pressed"] forState:UIControlStateHighlighted];
    [btnBack setImage:[UIImage imageNamed:@"CodeScan.bundle/widget_title_btn_back_light_ios26"] forState:UIControlStateNormal];
//    [btnBack setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    [btnBack.layer setCornerRadius:18];// 10
    [btnBack addTarget:self action:@selector(doBack) forControlEvents:UIControlEventTouchUpInside];
    [_titleItemsView addSubview:btnBack];
    
    //** 更多按钮
    UIButton *btnMore = [UIButton buttonWithType:UIButtonTypeCustom];
//    btnMore.layer.cornerRadius = buttonH/2.0f;;
//    btnMore.layer.masksToBounds = YES;
    btnMore.frame = CGRectMake(CGRectGetWidth(self.view.frame) - buttonW - buttonLeftOrRightGap, 0, buttonW, buttonH);
//    [btnMore setImage:[UIImage imageNamed:@"CodeScan.bundle/widget_title_btn_more_light_normal"] forState:UIControlStateNormal];
//    [btnMore setImage:[UIImage imageNamed:@"CodeScan.bundle/widget_title_btn_more_light_pressed"] forState:UIControlStateHighlighted];
    [btnMore setImage:[UIImage imageNamed:@"CodeScan.bundle/widget_title_btn_more_light_ios26"] forState:UIControlStateNormal];
//    [btnMore setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    [btnMore.layer setCornerRadius:18];// 10
    [btnMore addTarget:self action:@selector(doMore) forControlEvents:UIControlEventTouchUpInside];
    [_titleItemsView addSubview:btnMore];
    
    // 针对ios 26的优化：不需要单独的背景色液态玻璃效果更好
    if (@available(iOS 26, *)) {
    } else {
        [btnBack setBackgroundColor:RGBACOLOR(255,255,255, 26)];
        [btnMore setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    }
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:btnBack];
    [BasicTool setClearGlassBgnConfig:btnMore];
    
//    //** 标题文字组件
//    UILabel *titleLabel = [[UILabel alloc]init];
//    titleLabel.bounds = CGRectMake(0, 0, 200, titleItemsViewH);
//    // titleItemsViewH/2表示titleLabel高度的一半，因为这里设置的是中心坐标（不是Y坐标），不加入这个偏移就不对了
//    titleLabel.center = CGPointMake(CGRectGetWidth(_titleItemsView.frame)/2, titleItemsViewH/2);
//    titleLabel.textAlignment = NSTextAlignmentCenter;
//    titleLabel.numberOfLines = 0;
//    titleLabel.text = self.title;//@"扫一扫";
//    [titleLabel setFont:[UIFont boldSystemFontOfSize:18.0]];
//    titleLabel.textColor = HexColor(0xffffff);
//    titleLabel.backgroundColor = [UIColor clearColor];//[UIColor redColor];
//    [_titleItemsView addSubview:titleLabel];
}

- (void)drawBottomItems
{
    if (_bottomItemsView) {
        return;
    }

    // 提示文字到下方手电筒按钮间的空白间距
    float labelToFlashButtonGap = 15.0f;
    // 提示文字到下方功能按钮间的空白间距
    float buttonTopToLabelGap = 30.0f;
    // 下方功能按钮左右的空白间距
    float buttonLeftOrRightGap  = 30.0f;
    // 下方功能按钮距离底部的空白间距
    float buttonBottomGap = 40.0f;//50.0f;
    
    // 下方功能按钮的长和宽
    float buttonWH = 48.0f;
    // 手遇筒按钮的的长和宽
    float buttonFlashWH = 40.0f;
    // 提示文字组件的高度
    float labelTitleH = 16.0f;
    
    // 总体父布局的高度
    float bottonItemsViewHeight = buttonBottomGap + buttonWH + buttonTopToLabelGap + labelTitleH + labelToFlashButtonGap + buttonFlashWH;
    // 总体父布局组件
    self.bottomItemsView = [[UIView alloc]initWithFrame:CGRectMake(0
                                                                   , CGRectGetMaxY(self.view.bounds) - bottonItemsViewHeight - [BasicTool getSafeAreaInsets_bottom]//kTabbarSafeBottomMargin
                                                                   , CGRectGetWidth(self.view.frame), bottonItemsViewHeight)];
    _bottomItemsView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];//[UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];
    [self.view addSubview:_bottomItemsView];
        
    //** 手电筒按钮
    self.btnFlash = [[UIButton alloc]init];
    _btnFlash.frame = CGRectMake(CGRectGetWidth(_bottomItemsView.frame)/2 - buttonFlashWH/2, 0, buttonFlashWH, buttonFlashWH);
     [_btnFlash setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_flash_off"] forState:UIControlStateNormal];
    [_btnFlash addTarget:self action:@selector(openOrCloseFlash) forControlEvents:UIControlEventTouchUpInside];
    [_bottomItemsView addSubview:_btnFlash];
    
    //** 提示文字组件
    self.bottomLabel = [[UILabel alloc]init];
    _bottomLabel.bounds = CGRectMake(0, CGRectGetMaxY(_btnFlash.frame) + labelToFlashButtonGap, 320, labelTitleH);
    // 20/2表示topTitle高度的一半，因为这里设置的是中心坐标（不是Y坐标），不加入这个偏移就不对了
    _bottomLabel.center = CGPointMake(CGRectGetWidth(_bottomItemsView.frame)/2, CGRectGetMaxY(_btnFlash.frame) + labelToFlashButtonGap + labelTitleH/2);
    _bottomLabel.textAlignment = NSTextAlignmentCenter;
    _bottomLabel.numberOfLines = 0;
    _bottomLabel.text = @"手机对准二维码，将自动扫描识别";
    [_bottomLabel setFont:[UIFont systemFontOfSize:14.0]];
    _bottomLabel.textColor = HexColor(0xC0C0C0);//[UIColor whiteColor];
    _bottomLabel.backgroundColor = [UIColor clearColor];//[UIColor redColor];
    [_bottomItemsView addSubview:_bottomLabel];
    
    //** 我的二维码功能按钮
    self.btnMyQR = [[UIButton alloc]init];
    _btnMyQR.frame = CGRectMake(buttonLeftOrRightGap, CGRectGetMaxY(_bottomLabel.frame)+buttonTopToLabelGap, buttonWH, buttonWH);
//    [_btnMyQR setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_my_card_ico"] forState:UIControlStateNormal];
//    [_btnMyQR setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_my_card_ico_pressed"] forState:UIControlStateHighlighted];
    [_btnMyQR setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_my_card_ico_ios26"] forState:UIControlStateNormal];
//   [_btnMyQR setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    [_btnMyQR.layer setCornerRadius:24];// 10
    [_btnMyQR addTarget:self action:@selector(myQRCode) forControlEvents:UIControlEventTouchUpInside];
    [_bottomItemsView addSubview:_btnMyQR];
    
    //** 从相册读取二维码功能按钮
    self.btnPhoto = [[UIButton alloc]init];
    _btnPhoto.frame = CGRectMake(CGRectGetWidth(self.view.frame) - buttonLeftOrRightGap - buttonWH, CGRectGetMaxY(_bottomLabel.frame)+buttonTopToLabelGap, buttonWH, buttonWH);
//    [_btnPhoto setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_from_galerry_ico"] forState:UIControlStateNormal];
//    [_btnPhoto setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_from_galerry_ico_pressed"] forState:UIControlStateHighlighted];
    [_btnPhoto setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_from_galerry_ico_ios26"] forState:UIControlStateNormal];
//   [_btnPhoto setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    [_btnPhoto.layer setCornerRadius:24];// 10
    [_btnPhoto addTarget:self action:@selector(openPhoto) forControlEvents:UIControlEventTouchUpInside];
    [_bottomItemsView addSubview:_btnPhoto];
    
    // 针对ios 26的优化：不需要单独的背景色液态玻璃效果更好
    if (@available(iOS 26, *)) {
    } else {
        [_btnMyQR setBackgroundColor:RGBACOLOR(255,255,255, 26)];
        [_btnPhoto setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    }
    // 给按钮设置液态玻璃效果
//    [BasicTool setClearGlassBgnConfig:self.btnFlash];
    [BasicTool setClearGlassBgnConfig:self.btnMyQR];
    [BasicTool setClearGlassBgnConfig:self.btnPhoto];
}

- (void)showError:(NSString*)str
{
    [LBXAlertAction showAlertWithTitle:@"提示" msg:str buttonsStatement:@[@"知道了"] chooseBlock:nil];
}

- (void)scanResultWithArray:(NSArray<LBXScanResult*>*)array
{
    if (array.count < 1)
    {
        [self popAlertMsgWithScanResult:nil];
        return;
    }
    
    // 经测试，可以同时识别2个二维码，不能同时识别二维码和条形码
    for (LBXScanResult *result in array) {
        NSLog(@"scanResult:%@",result.strScanned);
    }
    
    LBXScanResult *scanResult = array[0];
    NSString*strResult = scanResult.strScanned;
    self.scanImage = scanResult.imgScanned;
    
    if (!strResult) {
        [self popAlertMsgWithScanResult:nil];
        return;
    }
    
    // 声音提醒
    [[PromtHelper sharedInstance] scanQRPromt]; //[LBXScanWrapper systemSound];
    // 震动提醒
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);// [LBXScanWrapper systemVibrate];

    [self showNextVCWithScanResult:scanResult];
}

- (void)popAlertMsgWithScanResult:(NSString*)strResult
{
    if (!strResult) {
        strResult = @"识别失败";
    }
    
    __weak __typeof(self) weakSelf = self;
    [LBXAlertAction showAlertWithTitle:@"扫码内容" msg:strResult buttonsStatement:@[@"知道了"] chooseBlock:^(NSInteger buttonIdx) {
        [weakSelf reStartDevice];
    }];
}

- (void)showNextVCWithScanResult:(LBXScanResult*)strResult
{
    [self.navigationController popViewControllerAnimated:NO];
    self.scanResult(strResult.strScanned);
}


#pragma mark - 标题栏功能项

- (void)doBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)doMore
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    //### 标题栏右边的“更多”按钮对应的弹出菜单功能事件处理block
    LPActionSheetBlock moreActionSheetHandler = ^(LPActionSheet *actionSheet, NSInteger index) {
        // 点击的是“从相册中选取"
        if(index == 1){
            [safeSelf openPhoto];
        }
    };

    //### 仿微信的弹出菜单：用于显示标题栏右边的“更多”按钮对应功能
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"从相册中选取"]
                                    handler:moreActionSheetHandler];
}


#pragma mark - 底部功能项
//打开相册
- (void)openPhoto
{
    __weak __typeof(self) weakSelf = self;
    [LBXPermission authorizeWithType:LBXPermissionType_Photos completion:^(BOOL granted, BOOL firstTime) {
        if (granted) {
            [weakSelf openLocalPhoto:NO];
        }
        else if (!firstTime )
        {
            [LBXPermissionSetting showAlertToDislayPrivacySettingWithTitle:@"提示" msg:@"没有相册权限，是否前往设置" cancel:@"取消" setting:@"设置"];
        }
    }];
}

//开关闪光灯
- (void)openOrCloseFlash
{
    [super openOrCloseFlash];
   
    if (self.isOpenFlash)
    {
        [_btnFlash setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_flash_on"] forState:UIControlStateNormal];
    }
    else
        [_btnFlash setImage:[UIImage imageNamed:@"CodeScan.bundle/qrcode_scan_flash_off"] forState:UIControlStateNormal];
}


#pragma mark - 底部功能项

- (void)myQRCode
{
//    CreateBarCodeViewController *vc = [CreateBarCodeViewController new];
//    vc.qrType = QRType_User;
//    [self.navigationController pushViewController:vc animated:YES];
    
    // "我的二维码"
    [ViewControllerFactory goQRCodeGenerateMyViewController:self.navigationController];
}



#pragma mark - 其它方法

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
