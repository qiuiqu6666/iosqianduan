//telegram @wz662
//
//  SubLBXScanViewController.h
//
//  github:https://github.com/MxABC/LBXScan
//  Created by lbxia on 15/10/21.
//  Copyright © 2015年 lbxia. All rights reserved.
//

#import "LBXAlertAction.h"
#import "LBXScanViewController.h"

#pragma mark -模仿qq界面
//继承LBXScanViewController,在界面上绘制想要的按钮，提示语等
@interface QQLBXScanViewController : LBXScanViewController


#pragma mark --增加拉近/远视频界面
@property (nonatomic, assign) BOOL isVideoZoom;


#pragma mark - 标题栏上的功能
// 标题栏上显示的功能项父组件
@property (nonatomic, strong) UIView *titleItemsView;


#pragma mark - 底部几个功能：开启闪光灯、相册、我的二维码
// 底部显示的功能项
@property (nonatomic, strong) UIView *bottomItemsView;
// 扫码区域下方提示文字
@property (nonatomic, strong) UILabel *bottomLabel;
//相册
@property (nonatomic, strong) UIButton *btnPhoto;
//闪光灯
@property (nonatomic, strong) UIButton *btnFlash;
//我的二维码
@property (nonatomic, strong) UIButton *btnMyQR;

@property (nonatomic, copy) void (^scanResult)(NSString *strScanned);

@end
