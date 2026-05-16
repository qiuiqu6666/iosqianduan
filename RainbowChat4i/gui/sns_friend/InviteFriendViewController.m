//telegram @wz662
#import "InviteFriendViewController.h"
#import "BasicTool.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"

@interface InviteFriendViewController ()
/** 要邀请的好友邮件地址：本字段仅用于保存初始化时传进来的mail(比如有添加指定好时，对应的邮箱没有被注册，则
 如要跳出本邀请界面并自动带上这个邮箱，到了这个邀请好友界面时就不用重复填入刚才的邮箱了) */
@property (nonatomic, retain) NSString *sendToMailForInit;
@end

@implementation InviteFriendViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withMail:(NSString *)mail
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.sendToMailForInit = mail;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"邀请朋友下载使用";

    // 已准备好了要邀请的人的邮箱
    if(self.sendToMailForInit != nil)
    {
        // 将传过来的要邀请的好友邮件地件初始化到ui组件上（当前此场景用于
        // 在添加好友时，对应邮件地址没有注册的情况下——就邀请它注册）
        self.editSendToMail.text = self.sendToMailForInit;
    }
    
//    // 设置输入文本区的拉伸背景图（不然图片因组件在autolayout下自适配屏幕后而变形）
//    [BasicTool setStretchImage:self.editSendToMailBg capInsets:UIEdgeInsetsMake(7, 7, 7, 7) img:self.editSendToMailBg.image];

    // 实现点击空白处取消键盘显示
    self.view.userInteractionEnabled = YES;
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)];
    [self.view addGestureRecognizer:singleTap];
    
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:self.btnInvite];
}

-(void)fingerTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    [self.view endEditing:YES];
}

// 发送邮件按钮事件处理
- (IBAction)clickSendMail:(id)sender
{
    // 收起软键盘
    [self fingerTapped:nil];

    NSString *mail = [BasicTool trim:self.editSendToMail.text];

    if([BasicTool isStringEmpty:mail]) {
        [BasicTool showAlertInfo:@"请输入被邀请人的邮箱..." parent:self];
        return;
    }

    if(![BasicTool isValidEmail:mail]) {
        [BasicTool showAlertInfo:@"无效的邮箱格式，请更正后再试！" parent:self];
        return;
    }

    UserEntity *locanUserInfo = [IMClientManager sharedInstance].localUserInfo;
    // 发送邀请邮件
    [[HttpRestHelper sharedInstance] submitInviteFriendToServer:mail localNick:locanUserInfo.nickname localMail:locanUserInfo.user_mail localUid:locanUserInfo.user_uid complete:^(BOOL sucess) {
        if(sucess) {
            // 发送成功后，显示一个提示Toast
            [BasicTool showUserDefintToast:@"邀请已发出"
                                      view:self.navigationController.view
                                    // Toast消失时的回调
                                    atHide:^(void){
                                        // 并在Toast消失时自动退出本界面
                                        [self.navigationController popViewControllerAnimated:YES];
                                    }];
        } else {
            [BasicTool showAlertInfo:@"邮件发送失败了，您可稍后再重试！" parent:self];
        }
    } hudParentView:nil];
}

@end
