//telegram @wz662
//
//  QRCodeGenerateViewController.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/8.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "QRCodeGenerateViewController.h"
#import "QRCodeScheme.h"
#import "UserEntity.h"
#import "IMClientManager.h"
#import "BasicTool.h"
#import "LBXScanNative.h"
#import "FileDownloadHelper.h"
#import "LPActionSheet.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"

@interface QRCodeGenerateViewController ()
// 调用者传进来的二维码scheme
@property (nonatomic, retain) NSString *schemeFromIntent;
// 调用者传进来的用户uid或群id
@property (nonatomic, retain) NSString *idFromIntent;

- (void)rb_qrApplyChromeNavigationBar;
@end

@implementation QRCodeGenerateViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withScheme:(NSString *)scheme andId:(NSString *)theId {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.schemeFromIntent = scheme;
        self.idFromIntent = theId;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // 设置按钮样式
    [self setupButtons];
    
    // 刷新界面数据显示
    [self refreshDatas];
    // 显示头像
    [self loadAvatar];

    [self rb_qrApplyChromeNavigationBar];
    
//  [self hideNavigation];
}

- (void)rb_qrApplyChromeNavigationBar
{
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = @"";

    UIImage *moreImg = [UIImage imageNamed:@"common_more_ico"];
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @"" rightButtonImage:moreImg target:self action:@selector(gotoMore)];
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (bar != nil) {
        [bar setBackButtonTarget:self action:@selector(doBack)];
    }
}

- (void)doBack
{
    if (self.navigationController != nil) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self rb_plainCustomNavHostViewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

/**
 * 设置按钮样式
 */
- (void)setupButtons {
    // 设置保存图片按钮样式
    if (self.btnSaveImage) {
        // 圆角已在XIB中设置，这里只需要设置其他样式
        CGFloat fontSize = [BasicTool getAdjustedFontSize:16.0];
        self.btnSaveImage.titleLabel.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium];
        // 添加边框，与二维码卡片风格一致
        self.btnSaveImage.layer.borderWidth = 0.5;
        self.btnSaveImage.layer.borderColor = [UIColor colorWithRed:0.90980392156862744 green:0.9137254901960784 blue:0.91764705882352937 alpha:1.0].CGColor;
    }
    
    // 设置扫一扫按钮样式
    if (self.btnScan) {
        // 圆角已在XIB中设置，这里只需要设置其他样式
        CGFloat fontSize = [BasicTool getAdjustedFontSize:16.0];
        self.btnScan.titleLabel.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium];
        // 添加边框，与二维码卡片风格一致
        self.btnScan.layer.borderWidth = 0.5;
        self.btnScan.layer.borderColor = [UIColor colorWithRed:0.90980392156862744 green:0.9137254901960784 blue:0.91764705882352937 alpha:1.0].CGColor;
    }
}

/**
 * 刷新界面数据的显示。
 */
- (void)refreshDatas {
    
    self.nameTextView.text = @"";
    self.descView.text = @"";
    self.sexView.hidden = YES;
    self.layoutQrLogo.hidden = NO;
    
//    // 大于320屏宽的手机，内容父view就设成330宽（默认在小屏上了320宽度），这个宽度是最佳ui设计效果
//    if ([UIScreen mainScreen].bounds.size.width > 320 ) {
//        self.layoutContent_width.constant = 330;
//    }
    
//    // 内部区图片背景因为有圆角效果，所以需要矢量拉伸，不然就变形了
//    [BasicTool setStretchImage:self.layoutContentBg capInsets:UIEdgeInsetsMake(30, 30, 30, 30) img:self.layoutContentBg.image];
    [BasicTool setBorder:self.layoutContent width:1.0f color:HexColor(0xf2f4f7) radius:26.0f];
    
    // 当前生成的是"我的2维码"
    if ([QRCodeScheme isAddUserQRCode:self.schemeFromIntent]) {
        // 本地用户信息
        UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
        if (localUserInfo != nil) {
            self.nameTextView.text = localUserInfo.nickname;
            // 确保在昵称很长的情况下，能为右边性别图标留出刚好的显示位置
            self.nameTextView_rightGap.constant = 21;
            self.descView.text = [NSString stringWithFormat:@"ID号：%@", localUserInfo.user_uid];
            
            // 设置性别图标
            [self.sexView setImage:nil];
            
            // 性别图标
            [self.sexView setImage:[UIImage imageNamed:[localUserInfo isMan]?@"sns_friend_list_form_item_male_img":@"sns_friend_list_form_item_female_img"]];
            self.sexView.hidden = NO;
        }
        
        self.title = @"我的二维码";
        self.labelDescLine1.text = @"扫描二维码";
        self.labelDescLine2.text = @"添加我为联系人";
    }
    // 当前生成的是"群聊2维码"
    else if([QRCodeScheme isJoinGroupQRCode:self.schemeFromIntent]){
        // 取出群信息
        GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.idFromIntent];
        if(ge != nil){
            self.nameTextView.text = ge.g_name;
            // 确保在群名称很长的情况下，直接顶到头
            self.nameTextView_rightGap.constant = 0;
            self.descView.text = [NSString stringWithFormat:@"创建于：%@", ge.create_time];
        }
        
        self.title = @"群聊二维码";
        self.labelDescLine1.text = @"扫描二维码";
        self.labelDescLine2.text = @"加入群聊";
    } else {
        [self promtAndFinish:[NSString stringWithFormat:@"无效的schemeFromIntent=%@", self.schemeFromIntent]];
    }
    
    // 显示2维码图片
    @try {
        NSString *qrCodeStr = [self rb_currentQRCodeString];
        UIImage *bitmap = [self rb_standardQRCodeImageForString:qrCodeStr];
        if (bitmap != nil) {
            self.viewQrcode.image = bitmap;
        }
    } @catch (NSException *e) {
        DLogError(@"出错了，exception=%@", e);
    }
}

- (NSString *)rb_currentQRCodeString
{
    if([QRCodeScheme isJoinGroupQRCode:self.schemeFromIntent]) {
        NSString *sharedByUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        return [QRCodeScheme constructJoinGroupCodeStr:self.idFromIntent sharedByUid:sharedByUid];
    }
    return [QRCodeScheme constructAddUserCodeStr:self.idFromIntent];
}

- (UIImage *)rb_standardQRCodeImageForString:(NSString *)qrStr
{
    if (qrStr.length == 0) return nil;
    CGFloat sc = [UIScreen mainScreen].scale;
    CGSize pxSize = CGSizeMake(ceil(self.viewQrcode.bounds.size.width * sc), ceil(self.viewQrcode.bounds.size.height * sc));
    if (pxSize.width < 10 || pxSize.height < 10) return nil;
    UIImage *raw = [LBXScanNative createQRWithString:qrStr QRSize:pxSize QRColor:[UIColor blackColor] bkColor:[UIColor whiteColor]];
    if (!raw) return nil;
    if (raw.CGImage) return [UIImage imageWithCGImage:raw.CGImage scale:sc orientation:UIImageOrientationUp];
    return raw;
}

/**
 * 尝试异步加载头像.
 */
- (void)loadAvatar {
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    self.layoutQrLogo.hidden = NO;
    self.layoutQrLogo.layer.cornerRadius = 11;
    self.layoutQrLogo.layer.masksToBounds = YES;
    self.viewAvatarLogo.layer.cornerRadius = 7;
    self.viewAvatarLogo.layer.masksToBounds = YES;
    UIImage *platformLogo = [UIImage imageNamed:@"about_logo"];
    if (platformLogo) {
        [self.viewAvatarLogo setImage:platformLogo];
    }

    // 当前生成的是"我的2维码"
    if ([QRCodeScheme isAddUserQRCode:self.schemeFromIntent]) {
        // 左上边的用户头像圆角
        self.viewAvatar.layer.cornerRadius = 32.5;
        self.viewAvatar.layer.masksToBounds = YES;
        
        // 本地用户信息
        UserEntity *u = [IMClientManager sharedInstance].localUserInfo;
        // 用户头像文件名不为空，表示已设置头像，才需要加载头像啦
        if (u != nil && ![BasicTool isStringEmpty:[BasicTool trim:u.userAvatarFileName]]) {
            // 显示上方的用户头像（只更新左上角头像，不更新二维码中心 logo）
            [FileDownloadHelper loadUserAvatarIntelligent:u.userAvatarFileName
                                                      uid:u.user_uid
                                                   logTag:@"QRCodeGenerateViewController-AI1"
                                                 complete:^(BOOL sucess, UIImage *img) {
                if(sucess && img != nil) {
                    [safeSelf.viewAvatar setImage:img];
                }
            }
             // 跳过磁盘缓存，这种情况可确保在app重启时不从磁盘加载（从而有机会从网络加载一次），用户至少有机会在下次重启时更新图片显示
                                        donotLoadFromDisk:YES];
        }
    }
    // 当前生成的是"群聊2维码"
    else if([QRCodeScheme isJoinGroupQRCode:self.schemeFromIntent]){
        
        // 左上边的群组头像圆角
        self.viewAvatar.layer.cornerRadius = 7;
        self.viewAvatar.layer.masksToBounds = YES;
        
        // 加载群头像
        [FileDownloadHelper loadGroupAvatar:self.idFromIntent logTag:@"QRCodeGenerateViewController-AI3"
            complete:^(BOOL sucess, UIImage *img) {
                if(sucess && img != nil)
                    [safeSelf.viewAvatar setImage:img];
        }];
    }
}

// 点击“更多”按钮时调用的方法
- (void)gotoMore
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    //### 标题栏右边的“更多”按钮对应的弹出菜单功能事件处理block
    LPActionSheetBlock moreActionSheetHandler = ^(LPActionSheet *actionSheet, NSInteger index) {
        // 点击的是“保存到手机"
        if(index == 1){
            UIImage *image = [safeSelf rb_snapshotQRContentCardImage];
            if (image) {
                [safeSelf saveImage:image];
            }
        }
        // 点击的是“扫描二维码”
        else if(index == 2) {
            // 进入“扫一扫”界面
            [QRCodeScheme gotoQrCodeScan:safeSelf.navigationController scanComplete:^(NSString *qrResult) {
                DLogDebug(@"%@", [NSString stringWithFormat:@"2维码扫描的结果是：%@", qrResult]);
                // 开始解析2维码内容并进入相应的处理逻辑
                [QRCodeScheme processQRCodeScanResult:qrResult nav:safeSelf.navigationController view:safeSelf.view vc:safeSelf];
            }];
        }
    };

    //### 仿微信的弹出菜单：用于显示标题栏右边的“更多”按钮对应功能
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"保存到手机", @"扫描二维码"]
                                    handler:moreActionSheetHandler];
}

// 保存二维码图片到手机相册
- (void)saveImage:(UIImage *)img {
    UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

/// 与底部「保存图片」一致：仅导出二维码卡片 layoutContent，按屏 scale 渲染。
- (UIImage *)rb_snapshotQRContentCardImage {
    CGSize sz = self.layoutContent.bounds.size;
    if (sz.width < 1 || sz.height < 1) {
        return nil;
    }
    NSString *qrStr = [self rb_currentQRCodeString];
    UIImage *oldQr = self.viewQrcode.image;
    if (qrStr.length > 0) {
        UIImage *plain = [self rb_standardQRCodeImageForString:qrStr];
        if (plain != nil) {
            self.viewQrcode.image = plain;
        }
    }
    UIGraphicsBeginImageContextWithOptions(sz, NO, [UIScreen mainScreen].scale);
    [self.layoutContent.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    self.viewQrcode.image = oldQr;
    return image;
}

// 保存二维码图片到手机相册的结果回调
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSString *text = nil;
    if(error) {
        text = @"保存失败";
    } else {
        text = @"保存成功";
    }
    
    [BasicTool showUserDefintToast:text
                              view:self.view
                            // Toast消失时的回调
                            atHide:^(void){
                            }];
}

// 保存图片按钮点击事件
- (IBAction)clickSaveImage:(id)sender {
    UIImage *image = [self rb_snapshotQRContentCardImage];
    if (image) {
        [self saveImage:image];
    }
}

// 扫一扫按钮点击事件
- (IBAction)clickScan:(id)sender {
    // 为了在block代码中安全地使用本类"self"，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    // 进入"扫一扫"界面
    [QRCodeScheme gotoQrCodeScan:self.navigationController scanComplete:^(NSString *qrResult) {
        DLogDebug(@"%@", [NSString stringWithFormat:@"2维码扫描的结果是：%@", qrResult]);
        // 开始解析2维码内容并进入相应的处理逻辑
        [QRCodeScheme processQRCodeScanResult:qrResult nav:safeSelf.navigationController view:safeSelf.view vc:safeSelf];
    }];
}

@end
