//telegram @wz662
#import "UserViewController.h"
#import "UserEntity.h"
#import "IMClientManager.h"
#import "FileDownloadHelper.h"
#import "BasicTool.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "RBImagePickerWrapper.h"
#import "RBAvatarView.h"
#import "AvatarHelper.h"
#import "MBProgressHUD.h"
#import "ViewControllerFactory.h"
#import "UserEditViewController.h"
#import "MoreViewController.h"
#import "LPActionSheet.h"
#import "UserDefaultsToolKits.h"
#import "UIViewController+RBPlainCustomNav.h"

@interface UserViewController ()
// 图片选择处理封装对象（用于修改用户头像时从相机或相册中选择图片的各种处理）
@property (nonatomic, strong) RBImagePickerWrapper *imagePickerWrapper;
/// 支持图片/视频的头像展示（叠在 viewAvatar 上，视频时直接播放）
@property (nonatomic, strong) RBAvatarView *avatarView;
@end

@implementation UserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self rb_installPlainCustomNavigationBarWithTitle:@"个人资料"];
    [self initGUI];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (self.avatarView && self.viewAvatar) {
        self.avatarView.frame = self.viewAvatar.bounds;
    }
    // 个性签名内容区宽度，便于多行正确换行与完整显示
    if (self.viewWhatsup && self.view.bounds.size.width > 0) {
        self.viewWhatsup.preferredMaxLayoutWidth = self.view.bounds.size.width - 52;
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self rb_plainCustomNavHostViewWillAppear:animated];

    // 当界面每次回到前台时就及时刷新本界面中的数据显示
    [self refreshDatas];
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

- (void)initGUI
{
    // 背景色
    self.view.backgroundColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.941 alpha:1.0]; // #F0F0F0

    // 个人头像修改时的图片处理封装对象
    self.imagePickerWrapper = [[RBImagePickerWrapper alloc] initWithParent:self delegate:self crop:YES];

    // 头像图片圆角方形
    self.viewAvatar.layer.cornerRadius = 8;
    self.viewAvatar.layer.masksToBounds = YES;

    // 支持图片/短视频的头像视图（视频直接播放），与 viewAvatar 同框
    self.avatarView = [[RBAvatarView alloc] initWithFrame:self.viewAvatar.bounds];
    self.avatarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.avatarView.cornerRadius = 8;
    self.avatarView.placeholderImage = [UIImage imageNamed:@"default_avatar_yuan_50"];
    [self.viewAvatar addSubview:self.avatarView];

    // 尝试异步加载本地用户头像
    [self loadAvatar];

    // 为头像组件添加点击事件
    [BasicTool addFingerClick:self.viewAvatar action:@selector(fingerTappedUserAvatar:) target:self];
}

// 点击用户头像，查看头像大图
-(void)fingerTappedUserAvatar:(UITapGestureRecognizer *)gestureRecognizer
{
    [MoreViewController showLocalUserAvatarBigImage:self];
}

// 用户本界面中的主要数据显示
- (void)refreshDatas
{
    UserEntity * u = [IMClientManager sharedInstance].localUserInfo;

    // 名字
    self.viewNickname.text = u.nickname;
    // 微信号（使用uid）
    self.viewUid.text = u.user_uid;
    // 手机号
    if(![BasicTool isStringEmpty:u.phoneNum])
        self.viewPhone.text = u.phoneNum;
    else
        self.viewPhone.text = @"未绑定";
    // 邮箱
    if(![BasicTool isStringEmpty:u.user_mail])
        self.viewEmail.text = u.user_mail;
    else
        self.viewEmail.text = @"未绑定";
    // 性别
    self.viewSex.text = [u isMan]? @"男" : @"女";
    // 签名
    if(![BasicTool isStringEmpty:u.whatsUp])
        self.viewWhatsup.text = u.whatsUp;
    else
        self.viewWhatsup.text = @"未填写";
}

// 尝试异步加载本地用户头像（图片/GIF 显示静态图，短视频直接播放）
- (void)loadAvatar
{
    UserEntity *u = [IMClientManager sharedInstance].localUserInfo;
    [self.avatarView setAvatarWithFileName:u.userAvatarFileName uid:u.user_uid];
}

// 按钮事件：修改本地用户头像
- (IBAction)clickAvatar:(id)sender
{
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"拍照", @"从手机相册选择"]
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
                                        if(index == 1){
                                            [self.imagePickerWrapper takePhoto];
                                        }
                                        else if(index == 2){
                                            [self.imagePickerWrapper takeAlbum:NO];
                                        }
                                    }];
}

- (IBAction)clickMyQR:(id)sender
{
    [ViewControllerFactory goQRCodeGenerateMyViewController:self.navigationController];
}

- (IBAction)clickNickname:(id)sender
{
    [ViewControllerFactory goUserEditViewController:self.navigationController withChangeType:IS_CHANGE_NICKNAME];
}

- (IBAction)clickSex:(id)sender
{
    [ViewControllerFactory goUserEditViewController:self.navigationController withChangeType:IS_CHANGE_SEX];
}

- (IBAction)clickPhone:(id)sender
{
    [ViewControllerFactory goModifyPhoneViewController:self.navigationController];
}

- (IBAction)clickEmail:(id)sender
{
    [ViewControllerFactory goModifyEmailViewController:self.navigationController];
}

- (IBAction)clickWhatsup:(id)sender
{
    [ViewControllerFactory goUserEditViewController:self.navigationController withChangeType:IS_CHANGE_WHATSUP];
}

//---------------------------------------------------------------------------------------------------
#pragma mark - RBImagePickerCompleteDelegate

- (void)processImagePickerComplete:(UIImage *)photo withTag:(NSString *)tag
{
    if(photo == nil)
    {
        [BasicTool showAlertError:@"头像选择失败!" parent:self];
        return;
    }

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = @"头像压缩中..";

    NSString *fileNameWillUpload = [AvatarHelper preparedAvatarForUpload:photo];

    if(fileNameWillUpload != nil)
    {
        DDLogDebug(@"【%@】要上传的图片文件准备成功，文件名=%@", tag, fileNameWillUpload);

        [AvatarHelper processAvatarUpload:fileNameWillUpload
                               processing:^{
                                   hud.label.text = @"头像上传中..";
                               } processFaild:^{
                                   [hud hideAnimated:NO];
                                   [BasicTool showAlertError:@"头像上传失败，可能是您的网络不稳定！" parent:self];
                               } processOk:^{
                                   [hud hideAnimated:NO];
                                   [BasicTool showUserDefintToast:@"上传成功" view:self.view atHide:nil];
                                   [IMClientManager sharedInstance].localUserInfo.userAvatarFileName = fileNameWillUpload;
                                   [self loadAvatar];
                               }];
    }
    else
    {
        [hud hideAnimated:YES];
        DDLogDebug(@"【%@】要上传的头像文件准备失败，本次上传不能继续！", tag);
        [BasicTool showAlertError:@"要上传的头像文件准备失败，本次上传不能继续！" parent:self];
    }
}

- (void)processImagePickerCompleteWithGifFileURL:(NSURL *)fileURL withTag:(NSString *)tag
{
    if (fileURL == nil) {
        [BasicTool showAlertError:@"GIF 选择失败!" parent:self];
        return;
    }
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = @"头像准备中..";
    NSString *fileNameWillUpload = [AvatarHelper preparedAvatarForUploadGifAtURL:fileURL];
    // 临时文件可删除，不阻塞
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    if (fileNameWillUpload != nil) {
        DDLogDebug(@"【%@】GIF 头像文件准备成功，文件名=%@", tag, fileNameWillUpload);
        [AvatarHelper processAvatarUpload:fileNameWillUpload
                               processing:^{ hud.label.text = @"头像上传中.."; }
                               processFaild:^{
                                   [hud hideAnimated:NO];
                                   [BasicTool showAlertError:@"头像上传失败，可能是您的网络不稳定！" parent:self];
                               } processOk:^{
                                   [hud hideAnimated:NO];
                                   [BasicTool showUserDefintToast:@"上传成功" view:self.view atHide:nil];
                                   [IMClientManager sharedInstance].localUserInfo.userAvatarFileName = fileNameWillUpload;
                                   [self loadAvatar];
                               }];
    } else {
        [hud hideAnimated:YES];
        [BasicTool showAlertError:@"GIF 头像准备失败，请重试！" parent:self];
    }
}

// 短视频头像（≤5s）：导出后准备并上传，与《用户头像-前端对接文档》一致
- (void)processVideoPickerComplete:(NSString *)videoFilePath duration:(int)duration withTag:(NSString *)tag
{
    if (videoFilePath.length == 0) {
        [BasicTool showAlertError:@"视频准备失败!" parent:self];
        return;
    }
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = @"头像准备中..";
    NSString *fileNameWillUpload = [AvatarHelper preparedAvatarForUploadVideoAtPath:videoFilePath];
    if (fileNameWillUpload.length == 0) {
        [hud hideAnimated:YES];
        [BasicTool showAlertError:@"短视频头像准备失败，请重试！" parent:self];
        return;
    }
    DDLogDebug(@"【%@】短视频头像文件准备成功，文件名=%@", tag, fileNameWillUpload);
    [AvatarHelper processAvatarUpload:fileNameWillUpload
                           processing:^{ hud.label.text = @"头像上传中.."; }
                            processFaild:^{
                                [hud hideAnimated:NO];
                                [BasicTool showAlertError:@"头像上传失败，可能是您的网络不稳定！" parent:self];
                            } processOk:^{
                                [hud hideAnimated:NO];
                                [BasicTool showUserDefintToast:@"上传成功" view:self.view atHide:nil];
                                [IMClientManager sharedInstance].localUserInfo.userAvatarFileName = fileNameWillUpload;
                                [self loadAvatar];
                            }];
}

@end
