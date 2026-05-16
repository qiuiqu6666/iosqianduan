//telegram @wz662
#import "DiscoverViewController.h"
#import "BasicTool.h"
#import "WebViewController.h"
//#import "RIButtonItem.h"
#import "IMClientManager.h"
#import "AppDelegate.h"
#import "UserDefaultsToolKits.h"
#import "FileDownloadHelper.h"
#import "ViewControllerFactory.h"
#import "HcdGuideView.h"
#import "AvatarHelper.h"
#import "SDImageCache.h"
#import "LPActionSheet.h"
#import "UserDefaultsToolKits.h"
#import "QRCodeScheme.h"

@interface DiscoverViewController ()

@end

@implementation DiscoverViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self initGUI];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // 即时刷新本界面中的数据显示
    [self refreshDatas];
}

// @Override
- (void)initGUI
{
    [super initGUI];
    
//    // 头像图片圆角
//    self.imgUserAvater.layer.cornerRadius = 30;
//    self.imgUserAvater.layer.masksToBounds = YES;
//
//    // 为头像组件添加点击事件
//    [BasicTool addFingerClick:self.imgUserAvater action:@selector(fingerTappedUserAvatar:) target:self];
//    
//    // 为退出登录按钮添加边框
//    [BasicTool setBorder:self.btnExit width:1.0f color:UI_DEFAULT_SETTING_ITEM_BUTTON_BORDER_COLOR radius:20.0f];
}

// 点击用户头像，查看头像大图
-(void)fingerTappedUserAvatar:(UITapGestureRecognizer *)gestureRecognizer
{
//    [MoreViewController showLocalUserAvatarBigImage:self];
}

// 用户本界面中的主要数据显示（建议本方法在界面每次处于前台时都被调用，这样将可使得诸如用户信息等数据在别的界面被改动时在本界面中能即时显示最新的结果）
- (void)refreshDatas
{
    // 个人信息的显示
//    UserEntity * curUser = [IMClientManager sharedInstance].localUserInfo;
//    [self.viewUserName setText:curUser.nickname];
//    [self.viewUserId setText:[NSString stringWithFormat:@"Chat ID: %@", curUser.user_uid]];
//
//    // 显示程序的版本号
//    NSBundle *mainBundle = [NSBundle mainBundle];
//    self.viewCurrentVersion.text = [NSString stringWithFormat:@"v%@(%@)"
//                                    , [[mainBundle infoDictionary] objectForKey:@"CFBundleShortVersionString"]
//                                    , [[mainBundle infoDictionary] objectForKey:@"CFBundleVersion"]];
//
//    // 根据本地数据设置是否选中
//    [self refreshMsgToneImage];
//
//    // 尝试异步加载本地用户头像
//    if(![BasicTool isStringEmpty:curUser.userAvatarFileName])
//    {
//        [FileDownloadHelper loadUserAvatarWithFileName:curUser.userAvatarFileName
//                                                   uid:curUser.user_uid
//                                                logTag:@"MoreViewController-MyAvatar"
//                                              complete:^(BOOL sucess, UIImage *img) {
//                                                  if(sucess && img != nil)
//                                                      // 设置最新头像
//                                                      [self.imgUserAvater setImage:img];
//                                              }];
//    }
}



- (IBAction)gotoMoment:(id)sender
{
    [ViewControllerFactory goMomentViewController:self.navigationController];
}

- (IBAction)gotoScan:(id)sender
{
    // 进入“扫一扫”界面
    [QRCodeScheme gotoQrCodeScan:self.navigationController scanComplete:^(NSString *qrResult) {
        DLogDebug(@"%@", [NSString stringWithFormat:@"2维码扫描的结果是：%@", qrResult]);
        // 开始解析2维码内容并进入相应的处理逻辑
        [QRCodeScheme processQRCodeScanResult:qrResult nav:self.navigationController view:self.view vc:self];
    }];
}

- (IBAction)gotoNearby:(id)sender
{
    [ViewControllerFactory goNearbyViewController:self.navigationController];
}

- (IBAction)gotoInvite:(id)sender
{
    // 进入“邀请朋友”界面
    [ViewControllerFactory goInviteFriendViewController:self.navigationController withMail:nil];
}

- (IBAction)gotoAI:(id)sender
{
    [ViewControllerFactory goAIViewController:self.navigationController];
}

@end
