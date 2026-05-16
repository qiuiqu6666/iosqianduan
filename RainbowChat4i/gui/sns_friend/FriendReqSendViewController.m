//telegram @wz662
#import "FriendReqSendViewController.h"
#import "UserEntity.h"
#import "UITextView+ZWPlaceHolder.h"
#import "UITextView+ZWLimitCounter.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "IMClientManager.h"
#import "MessageHelper.h"
#import "BasicTool.h"
#import "Default.h"
#import "AppDelegate.h"
#import "MoreViewController.h"
#import "UIViewController+RBPlainCustomNav.h"

@interface FriendReqSendViewController ()
@property (nonatomic, retain) UserEntity *friendInfoForInit;
/** 添加来源（如 search_uid, card, group, qrcode 等） */
@property (nonatomic, retain) NSString *addSource;
@end

@implementation FriendReqSendViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withDatas:(UserEntity *)userInfo addSource:(NSString *)addSource
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.friendInfoForInit = userInfo;
        self.addSource = addSource;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initGUI];
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

- (void)initGUI
{
    self.title = @"加为好友";
    // 与用户详情页一致的背景色（仅页面内容区，导航栏保持白色）
    self.view.backgroundColor = HexColor(0xF0F0F0);
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @"加为好友"];
    
    // 昵称
    self.viewNickname.text = self.friendInfoForInit.nickname;
    // UID（与参考图一致格式）
    self.viewUid.text = [NSString stringWithFormat:@"ID: %@", self.friendInfoForInit.user_uid ?: @""];
    // 性别图标（昵称右侧）
    [self.imgSex setImage:[UIImage imageNamed:[self.friendInfoForInit isMan] ? @"sns_friend_list_form_item_male_img" : @"sns_friend_list_form_item_female_img"]];
    // 个性签名（优先 whatsUp，其次 userDesc，无则显示占位文案）
    NSString *signature = self.friendInfoForInit.whatsUp.length > 0 ? self.friendInfoForInit.whatsUp : (self.friendInfoForInit.userDesc ?: @"");
    self.viewSignature.text = signature.length > 0 ? signature : @"暂无个性签名";
    
    // 设置输入框架的placeholder和输入字数限制
    NSString *placeHolderStr = [NSString stringWithFormat:@"对%@说点什么...", self.friendInfoForInit.nickname];
    self.editContent.zw_placeHolder = placeHolderStr;
    // 字数限制
    self.editContent.zw_limitCount = 100;
    // 设置字数限制提示ui的字体
    [self.editContent.zw_inputLimitLabel setFont:[BasicTool getSystemFontOfSize:12]];
    
    // 内容缩进为零（去除左右边距），上下留少量内边距便于阅读
    self.editContent.textContainer.lineFragmentPadding = 0.0;
    self.editContent.textContainerInset = UIEdgeInsetsMake(4, 0, 4, 0);
    
    // 头像圆形（xib 约束为 60×60）
    self.imgAvadar.layer.cornerRadius = 30.0f;
    self.imgAvadar.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.imgAvadar.layer.cornerCurve = kCACornerCurveCircular;
    }
    
    // 验证信息白卡片：轻微圆角，更贴近微信分组样式
    self.viewBzContainer.layer.cornerRadius = 8.0f;
    self.viewBzContainer.layer.masksToBounds = YES;
    
    // 按需载入用户头像
    [self loadAvatar];
    
    // 添加发送按钮处理事件
    [self.btnSend addTarget:self action:@selector(doSendRequest:) forControlEvents:UIControlEventTouchUpInside];
    
    // 实现点击空白处取消键盘显示
    self.view.userInteractionEnabled = YES;
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)];
    [self.view addGestureRecognizer:singleTap];
    
    // 实现下滑手势隐藏输入键盘
    UISwipeGestureRecognizer *recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(fingerSwipeFrom:)];
    [recognizer setDirection:(UISwipeGestureRecognizerDirectionDown)];
    [[self view] addGestureRecognizer:recognizer];
    
//    // 添加导航栏左边的“发送请求”按钮
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"发送请求"
//                                                                              style:UIBarButtonItemStylePlain
//                                                                             target:self
//                                                                             action:@selector(doSendRequest:)];
//    // “发送请求”按钮字体颜色
//    [self.navigationItem.rightBarButtonItem setTintColor:UI_DEFAULT_PLAINT_BUTTON_LIGHT_GREEN_COLOR];
//    // “发送请求”按钮字体大小
//    [self.navigationItem.rightBarButtonItem setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:15], NSFontAttributeName,nil] forState:(UIControlStateNormal)];
    
    // 为头像组件添加点击事件
    [BasicTool addFingerClick:self.imgAvadar action:@selector(fingerTappedUserAvatar:) target:self];
    
    // 微信风格：白底卡片无边框，按钮已在 xib 中设为微信绿
}

- (void)loadAvatar
{
    [RBAvatarView setAvatarWithFileName:self.friendInfoForInit.userAvatarFileName uid:self.friendInfoForInit.user_uid onImageView:self.imgAvadar placeholder:nil];
}

// 触屏手势：点击空白关闭输入键盘
-(void)fingerTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    [self.view endEditing:YES];
}

// 下滑手势：下滑屏幕关闭输入键盘
-(void)fingerSwipeFrom:(UISwipeGestureRecognizer *)recognizer
{
    if(recognizer.direction==UISwipeGestureRecognizerDirectionDown)
    {
        DDLogDebug(@"swipe down");
        // 关闭输入键盘
        [self.editContent resignFirstResponder];
    }
}

// 点击用户头像，查看头像大图
-(void)fingerTappedUserAvatar:(UITapGestureRecognizer *)gestureRecognizer
{
    if([BasicTool isStringEmpty:self.friendInfoForInit.userAvatarFileName])
    {
//        AlertInfo(@"该用户没有设置头像！");
        [BasicTool showAlertInfo:@"该用户没有设置头像！" parent:self];
    }
    else
    {
        [MoreViewController showUserAvatarBigImage:self.friendInfoForInit.user_uid avatarFileName:self.friendInfoForInit.userAvatarFileName withParent:self];
    }
}

// 处理发送请求按钮事件
-(void)doSendRequest:(UIButton*)sender
{
    int maxFriend = [[[IMClientManager sharedInstance] localUserInfo].maxFriend  intValue];
    NSString *sayText = [self.editContent.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // 发出添加好友请求
    [FriendReqSendViewController sendAddFriendRequest:self.friendInfoForInit.user_uid
                                             nickname:self.friendInfoForInit.nickname
                                            maxFriend:maxFriend
                                                  say:sayText
                                            addSource:self.addSource
                                                 view:self.navigationController.view
                                             // 请求成功发出后的回调
                                             complete:^{

              // 提示信息
              [APP showUserDefineToast_OK:@"请求已发送" atHide:nil];
              // 退出当前界面
              [self.navigationController popViewControllerAnimated:YES];
    }];
}

/**
 * 发送添加好友请求的实施方法(前置检查合格后发送真正的IM加好友指令)。
 *
 * @param friendUserUid 对方的uid
 * @param friendUserNickName 对方的昵称
 * @param maxFriend 我"被允许的最大好友数，当<=0时将忽略本参数
 * @param saySomethingToHim 加好友时的验证消息（本消息实际使用时是可能为null的哦，表示可以不输入任何想说的内容就可以加好友）
 * @param complete 在请求成功发出后调用的回调（开发者可在此回调中实现提示信息、请求处理完成后的其它动作），不需要可设为nil
 */
+ (void)sendAddFriendRequest:(NSString *)friendUserUid
                    nickname:(NSString *)friendUserNickName
                   maxFriend:(int)maxFriend
                         say:(NSString *)saySomethingToHim
                   addSource:(NSString *)addSource
                        view:(UIView *)parentView
                    complete:(void (^)(void))complete
{
    if(friendUserUid == nil)
        return;

    // 要加的好友是自已（这种情况应该是查找好友是查的是自已的U号或邮件地址）
    if([friendUserUid isEqualToString:[[IMClientManager sharedInstance] localUserInfo].user_uid])
    {
        AlertInfo(@"不能添加自己为好友哦！");
        return;
    }
    else
    {
        // 检查当前要添加的好友是否已经存在于列表中（存在当然就不能重复加好友了）
        // * 注：其实最严谨的方法是服务端判断（实时根据数据结果查询），但通过网络
        // * 与服务端交互因网速原因会影响体验，所以先行在客户端做一个理论上不太严
        // * 谨的判断，先行处理掉可能的重复也是合情合理的
        if([[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster:friendUserUid])
        {
            NSString *hint = [NSString stringWithFormat:@"%@ 已经是你的好友了，不需要再添加！", friendUserNickName];
            AlertInfo(hint)
            return;
        }

        // 最大好友数检查
        if(maxFriend > 0)
        {
            // 不能超过最大好友数
            if([[[IMClientManager sharedInstance] getFriendsListProvider] size] >= maxFriend)
            {
                NSString * hint = [NSString stringWithFormat:@"当前的交友规则允许你拥有%d个好友！", maxFriend];
                Alert(@"不能再加更多好友了", hint, @"知道了");
                return;
            }
        }

        // 通过了客户端初步的合法性检查，可以进入真正的添加好友业务逻辑处理
        int code = [MessageHelper sendAddFriendRequestToServerMessage:friendUserUid say:saySomethingToHim addSource:addSource];
        if(code == COMMON_CODE_OK)
        {
            if(complete)
                complete();
        }
        else
        {
            AlertError(@"添加好友请求发送失败，您可以稍后再试！");
        }
    }
}

@end
