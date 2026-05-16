//telegram @wz662
#import "FriendReqProcessViewController.h"
#import "BasicTool.h"
#import "ViewControllerFactory.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "IMClientManager.h"
#import "MessageHelper.h"
#import "QueryFriendInfoAsync.h"
#import "NotificationCenterFactory.h"
#import "AppDelegate.h"
#import "FriendsReqViewController.h"

@interface FriendReqProcessViewController ()
@property (nonatomic, retain) UserEntity *friendInfoForInit;
@end

@implementation FriendReqProcessViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withDatas:(UserEntity *)userInfo
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.friendInfoForInit = userInfo;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"验证请求";

    // 初始化界面
    [self initGUI];

    // 初始化界面数据显示
    [self initViewsData];
}

- (void)initGUI
{
    // 头像图片圆角
    self.viewFace.layer.cornerRadius = 30;
    self.viewFace.layer.masksToBounds = YES;
    
    // 内容缩进为零（去除左右边距）
    self.viewBz.textContainer.lineFragmentPadding = 0.0;
//    //去除上下边距
//    self.viewBz.textContainerInset = UIEdgeInsetsZero;
    
    // 为附加信息父布局添加边框
    [BasicTool setBorder:self.viewBzContainer width:1.0f color:UI_DEFAULT_SETTING_ITEM_BUTTON_BORDER_COLOR radius:16.0f];
    // 为按钮父布局添加边框
    [BasicTool setBorder:self.btnContainer width:1.0f color:UI_DEFAULT_SETTING_ITEM_BUTTON_BORDER_COLOR radius:25.0f];
    
//    // 给按钮设置液态玻璃效果
//    [BasicTool setClearGlassBgnConfig:self.btnAgree];
//    [BasicTool setClearGlassBgnConfig:self.btnReject];
}

- (void)initViewsData
{
    if(self.friendInfoForInit != nil)
    {
        self.viewNickname.text = self.friendInfoForInit.nickname;
        self.viewUid.text = [NSString stringWithFormat:@"ID：%@", self.friendInfoForInit.user_uid];
//        [self.viewFace setImage: [UIImage imageNamed:[self.friendInfoForInit isMan]?@"head_man_online":@"head_woman_online"]];

        // 验证说明文本（ex1）+ 添加来源（ex11）
        {
            NSMutableString *bzText = [NSMutableString string];

            // 验证说明
            if (![BasicTool isStringEmpty:self.friendInfoForInit.ex1]) {
                [bzText appendString:self.friendInfoForInit.ex1];
            } else {
                [bzText appendString:@"请求加你为好友"];
            }

            // 添加来源
            NSString *sourceText = [FriendsReqViewController addSourceDisplayText:self.friendInfoForInit.ex11];
            if (sourceText != nil) {
                [bzText appendFormat:@"\n来源：%@", sourceText];
            }

            self.viewBz.text = bzText;
        }

        // 载入用户头像（支持视频头像播放）
        [RBAvatarView setAvatarWithFileName:self.friendInfoForInit.userAvatarFileName uid:self.friendInfoForInit.user_uid onImageView:self.viewFace placeholder:nil];

        // 若为「我发出的」添加请求（pending_out），不显示拒绝/通过按钮
        if ([self.friendInfoForInit.ex12 isEqualToString:@"pending_out"]) {
            self.btnContainer.hidden = YES;
        } else {
            self.btnContainer.hidden = NO;
        }
    }
    else
    {
        AlertError(@"无效数据！");
        [self doBack];
    }
}

- (void)doBack
{
    // 退出本界面
    [self.navigationController popViewControllerAnimated:YES];
}

// 查看用户信息按钮事件处理
- (IBAction)clickSeeFriendInfo:(id)sender
{
    if(self.friendInfoForInit != nil)
    {
//        [ViewControllerFactory goFriendInfoViewController:self.navigationController withDatas:self.friendInfoForInit];
        // 查询并查看该用户的最新信息
        [QueryFriendInfoAsync gotoWatchUserInfo:self.friendInfoForInit.user_uid withInfo:nil nav:self.navigationController view:self.view vc:self];
//      [QueryFriendInfoAsync doIt:NO mail:nil uid:self.friendInfoForInit.user_uid hudParentView:self.view withNC:self.navigationController canOpenChat:YES];
    }
}

// "同意"按钮事件处理
- (IBAction)clickAgree:(id)sender
{
    UserEntity *local = [IMClientManager sharedInstance].localUserInfo;
    // 系统允许的最多好同时拥有的好友数
    int maxFriend = [BasicTool getIntValue:local.maxFriend defaultVal:1];

    // 要处理的该好友已经存在于好友列表中了（那就不需要再发往服务端去处理了）
    if([[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster:self.friendInfoForInit.user_uid])
    {
        AlertInfo(@"提示:此账号已经是你的好友了。");

        //** Bug FIX 20170406: 注销掉以下代码用于解决好加友请求在已是好友的情况下，不提
        //**                   交服务端处理已经存在历史请求，而导致该请求一直存在DB中的问题
//      return;
        //** Bug FIX 20170406: END
    }
    // 只允许与N个人结成伴侣关系！
    else if([[[IMClientManager sharedInstance] getFriendsListProvider] size] >= maxFriend)
    {
        NSString *content = [NSString stringWithFormat:@"当前最多只允许拥有%d个好友, 您可删除不常联系的好友后再试", maxFriend];
        Alert(@"超过好友数上限", content, @"确认");
        return;
    }

    // 提交处理好友请求的指令到服务端
    int code = [MessageHelper sendProcessAdd_Friend_Req_B_To_Server_AGREEMessage:[self getProcessFriendRequestMeta]];
    // 消息发送成功
    if(code == COMMON_CODE_OK)
    {
        // 显示提示信息
        [APP showUserDefineToast_OK:@"已同意" atHide:nil];
        // 调用本次处理完成方法
        [self processedCompelte];
    }
    else
    {
        NSString *error = [NSString stringWithFormat:@"出错了，错误码这%d", code];
        AlertError(error);
    }
}

// “拒绝””按钮事件处理
- (IBAction)clickReject:(id)sender
{
    // 要处理的该好友已经存在于好友列表中了（那就不需要再发往服务端去处理了）
    if([[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster:self.friendInfoForInit.user_uid])
    {
        AlertInfo(@"提示:此账号已经是你的好友了。");

        //** Bug FIX 20170406: 注销掉以下代码用于解决好加友请求在已是好友的情况下，不提
        //**                   交服务端处理已经存在历史请求，而导致该请求一直存在DB中的问题
//      return;
        //** Bug FIX 20170406: END
    }

    // 提交处理好友请求的指令到服务端
    int code = [MessageHelper sendProcessAdd_Friend_Req_B_To_Server_REJECTMessage:[self getProcessFriendRequestMeta]];
    // 消息发送成功
    if(code == COMMON_CODE_OK)
    {
        NSString *hint = [NSString stringWithFormat:@"已拒绝 %@(%@)的好友请求.", self.friendInfoForInit.nickname, self.friendInfoForInit.user_uid];
        AlertInfo(hint);

        // 本次处理完成
        [self processedCompelte];
    }
    else
    {
        NSString *hint = [NSString stringWithFormat:@"拒绝%@(%@)的好友请求发送失败(错误码: %d）!", self.friendInfoForInit.nickname, self.friendInfoForInit.user_uid, code];
        AlertError(hint);
    }
}

// 处理完成：退出本界面并向前一个界面（即验证通知列表界面）发出一个带着当前处理数据的系统Notification
- (void)processedCompelte
{
    // 发出通知：好友请求处理界面回来时（用于通知前一个界面——即未处理验证通知列表界面中清除掉本条已处理完成的请求(而不需要再次从网络加载列表数据，提升体验））
    [NotificationCenterFactory processCompleteFriendReq_POST:self.friendInfoForInit.user_uid];

    // 退出当前界面
    [self doBack];
}

// 本方法返回要提交到服务端的处理加好友请求的元数据
- (CMDBody4ProcessFriendRequest *)getProcessFriendRequestMeta
{
    UserEntity *local = [IMClientManager sharedInstance].localUserInfo;

    // 要提交到服务端的处理加好友请求数据
    CMDBody4ProcessFriendRequest *pfrm = [[CMDBody4ProcessFriendRequest alloc] init];
    pfrm.localUserUid = local.user_uid;
    pfrm.srcUserUid = self.friendInfoForInit.user_uid;
    pfrm.localUserNickName = local.nickname;

    return pfrm;
}

@end
