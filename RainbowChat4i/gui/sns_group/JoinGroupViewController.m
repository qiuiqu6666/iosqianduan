//telegram @wz662
//
//  JoinGroupViewController.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/7.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "JoinGroupViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "GroupEntity.h"
#import "UserEntity.h"
#import "BasicTool.h"
#import "FileDownloadHelper.h"
#import "IMClientManager.h"
#import "ViewControllerFactory.h"
#import "HttpRestHelper.h"
#import "GroupMemberViewController.h"
#import "GChatDataHelper.h"
#import "NotificationCenterFactory.h"
#import "AppDelegate.h"

@interface JoinGroupViewController ()

/** 调用者传过来的gid */
@property (nonatomic, retain) NSString *gid;
/** 调用者传过来的2维码分享者uid */
@property (nonatomic, retain) NSString *sharedByUid;
/** 调用者传过来的加群途径 */
@property (nonatomic, assign) int joinBy;

/** 对应的群基本信息 */
@property (nonatomic, retain) GroupEntity *groupInfo;
/** 对应的2维码分享者用户资料 */
@property (nonatomic, retain) UserEntity *sharedByUser;

@end

@implementation JoinGroupViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil with:(NSString *)qrcodeValue joinBy:(int)by {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // 群2维码内容组织，请见[QRCodeScheme constructJoinGroupCodeStr:]方法
        if (qrcodeValue != nil) {
            @try {
                char *lastChar = "_";
                int lastIndex = [BasicTool lastIndex:qrcodeValue of:lastChar];
                if(lastIndex != -1) {
                    // 群id
                    self.gid = [qrcodeValue substringWithRange:NSMakeRange(0, lastIndex)];
                    // 群二维码分享者的uid
                    self.sharedByUid = [qrcodeValue substringWithRange:NSMakeRange(lastIndex + 1, [qrcodeValue length]-(lastIndex+1))];
                    
                    DLogDebug(@"qrcodeValue解析完成：gid=%@, sharedByUid=%@", self.gid, self.sharedByUid);
                } else {
                    DDLogError(@"无效的qrcodeValue=%@，无法完成解析！", qrcodeValue);
                }
            } @catch (NSException *e) {
                DLogError(@"无效的qrcodeValue，解析失败，Exception: %@", e);
            }
        }
        
        self.joinBy = by;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.titleView = nil;
    self.navigationItem.rightBarButtonItems = nil;
    self.navigationItem.leftBarButtonItems = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"群聊邀请"];

    [self initViews];
    
    // 检查传进来的参数合法性
    if([BasicTool isStringEmpty:[BasicTool trim:self.gid]] || [BasicTool isStringEmpty:[BasicTool trim:self.sharedByUid]]){
        DLogWarn(@"无效的群id=%@和sharedByUid=%@（joinBy=%d）！", self.gid, self.sharedByUid, self.joinBy);
        [self promtAndFinish:@"无效的群二维码！"];
    } else{
        [self initDatas];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self rb_plainCustomNavHostViewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

// ui初始化工作请放本方法中
- (void)initViews {
    // 标题由 RBChromeNavigationBar 展示，勿再写 self.title 以免与系统导航叠影
    
    // 头像图片圆角(半径是宽高的一半就是圆角了)
    self.viewIcon.layer.cornerRadius = 8;
    self.viewIcon.layer.masksToBounds = YES;
    
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:self.btnOk];
}

// 数据初始化工作请放本方法中
- (void)initDatas {
    [self loadGroupIcon];
    
    // 如果已经加入了该群，则直接用缓存的群信息刷新ui数据显示（缓存列表中能找到该群信息即可认为已加入该群）
    GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.gid];
    if(ge != nil){
        [self.btnOk setTitle:@"进入群聊" forState:UIControlStateNormal];
        
        // 针对ios 26的优化：给按钮设置液态玻璃效果后它会将原背景色变淡，所以在ios 26下就将愿意颜色设置的深一点，不然视觉上太淡了
        if (@available(iOS 26, *)) {
            [self.btnOk setBackgroundColor:HexColor(0xd8dade)];// -rgb颜色值各减26
        }
        else {
            [self.btnOk setBackgroundColor:HexColor(0xf2f4f8)];
        }
        [self.btnOk setTitleColor:HexColor(0xff6432) forState:UIControlStateNormal];

        [self resreshDatas:ge];
    }
    // 如果没加入过该群，则通过网络加载该群基本信息
    else{
        [self.btnOk setTitle:@"加入群聊" forState:UIControlStateNormal];
        [self.btnOk setBackgroundColor:HexColor(0xda3e28)];
        [self.btnOk setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        
        // 从服务器端加载该群信息
        [self loadGroupInfo];
    }
    
    // 如果分享二维码的人是本地用户自已（则直接读取本地用户信息缓存）
    if(self.sharedByUid != nil && [self.sharedByUid isEqualToString:[IMClientManager sharedInstance].localUserInfo.user_uid]){
        self.sharedByUser = [IMClientManager sharedInstance].localUserInfo;
        DLogDebug(@"2维码分享者正是本地用户自已：sharedByUid=%@", self.sharedByUid);
    }
    // 如果分享二维码的人是好友（则直接从好友缓存列表中读取用户信息）
    else if([[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster2:self.sharedByUid]){
        self.sharedByUser = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:self.sharedByUid];
        DLogDebug(@"2维码分享者是好友：sharedByUid=%@，sharedByUser=%@", self.sharedByUid, self.sharedByUser);
    }
    // 以上情况都不是，那就只能从网格加载该二维码分享者的基础信息
    else{
        DLogDebug(@"2维码分享者是陌生人，马上开始从网络加载......");
        [self loadSharedByUserInfo];
    }
}

/**
 * 将群基本信息显示在ui上。
 *
 * @param ge 群基本信息
 */
- (void)resreshDatas:(GroupEntity *)ge {
    if(ge != nil){
        self.viewName.text = ge.g_name;
        self.viewDesc.text = [NSString stringWithFormat:@"（共%@人）", ge.g_member_count];
    }
}

// 按钮事件
- (IBAction)clickOk:(id)sender {
    // 如果已经加入了该群，则直接进入群聊（缓存列表中能找到该群信息即可认为已加入该群）
    GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:self.gid];
    if(ge != nil){
        // 直接进入群聊聊天界面
        [ViewControllerFactory goGroupChattingViewController:self.navigationController gid:ge.g_id gname:ge.g_name animated:NO popToRootFirst:YES highlight:nil];
        // 退出当前界面
        [self doBack:NO];
    }
    // 不存在该群信息，即表示尚未加入该群
    else{
        // 异步提交加群请求
        [self submitJoinGroup:self.gid sharedByUid:self.sharedByUid sharedByNickName:(self.sharedByUser == nil? self.sharedByUid:self.sharedByUser.nickname)];
    }
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 其它方法

// 向服务端异步提交加群请求
- (void)submitJoinGroup:(NSString *)gid sharedByUid:(NSString *)sharedByUid sharedByNickName:(NSString *)sharedByNickName {
    
    DLogDebug(@"submitJoinGroup。。。。");
    
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    
    UserEntity *locaUserInfo = [IMClientManager sharedInstance].localUserInfo;
    // 如果本地用户信息读取异常，则直接返回失败的结果给ui层
    if(locaUserInfo != nil){
        // 组织将要提交给服务端的加群请求数据
        NSMutableArray<NSMutableArray *> *items = [NSMutableArray array];
        // 以下字段及顺序请确保与http"【接口1016-24-24】"保持一致（接口参数详见接口方法说明）！
        NSMutableArray<NSString *> *row = [NSMutableArray array];
        [row addObject:gid];
        [row addObject:locaUserInfo.user_uid];
        [row addObject:locaUserInfo.nickname];
        // 将加群者信息暂存以备提交给服务端（默认的加群接口是支持多人加群的，所以实际上此时扫码加群时这个加群者集合中只有"我"一个加群的人）
        [items addObject:row];
        
        NSString *joinBy = (self.joinBy == JOIN_BY_SCAN_QRCODE ? @"1":@"2");
        // 向服务端提交加群请求
        [[HttpRestHelper sharedInstance] submitInviteToGroupToServer:joinBy invite_uid:sharedByUid invite_nickname:sharedByNickName invite_to_gid:gid members:items complete:^(BOOL sucess, NSString *resultCode) {
            // 服务端处理成功完成——直接入群
            if(sucess && [@"1" isEqualToString:resultCode])
            {
                if(safeSelf.groupInfo != nil) {
                    // 将刚成功加入的群聊基本信息对象放入本地群聊列表缓存中
                    [[[IMClientManager sharedInstance] getGroupsProvider] putGroup:safeSelf.groupInfo];
                    // 更新群信息里的群成员数+1
                    [GroupMemberViewController updateCurrentGroupMemberGroupAfterSubmit:safeSelf.gid deltaCount:1];
                    // 往聊天界面中显示一条被"我"通过扫描二维码加入群聊成功的提示信息（此通知并非服务器发出，而是本地准备好的，仅用UI显示）
                    [GChatDataHelper addSystemInfo_joinGroupSucess:safeSelf.joinBy
                                                            sharedByNickname:(safeSelf.sharedByUser == nil?nil:safeSelf.sharedByUser.nickname)
                                                                         gid:safeSelf.gid
                                                                       gname:safeSelf.groupInfo.g_name
                                                                 memberCount:[BasicTool getIntValue:safeSelf.groupInfo.g_member_count defaultVal:0]];
                    // 发送通知：重置群组头像缓存(用于保证本地影响群头像生成的操作，能在其它UI界面中及时将群头像刷新为最新，因为删除群员
                    //         、邀请群员等操作会在服务端重新生成群头像，此广播就是以低耦合的方式实现本地聊头像UI刷新的通知，仅此而已)
                    [NotificationCenterFactory resetGroupAvatarCache_POST:safeSelf.gid];
        
                    // 提示信息
                    [APP showUserDefineToast_OK:@"加群成功" atHide:nil];
                    
                    // 进入刚建好的这个群组聊天界面
                    [ViewControllerFactory goGroupChattingViewController:safeSelf.navigationController gid:safeSelf.gid gname:safeSelf.groupInfo.g_name animated:NO popToRootFirst:YES highlight:nil];
                    
                    // 退出当前界面
                    [safeSelf doBack:NO];
                    
                    return;
                }
            }
            
            // 已提交审核（群设置了需管理员审核入群）
            if (sucess && [@"2" isEqualToString:resultCode])
            {
                [APP showUserDefineToast_OK:@"申请已提交，等待管理员/群主审批" atHide:nil];
                [safeSelf doBack:YES];
                return;
            }
            
            // 无权限邀请（群设置了仅管理员和群主可邀请）
            if (sucess && [@"-2" isEqualToString:resultCode])
            {
                [BasicTool showAlertInfo:@"加群失败，该群仅管理员和群主可邀请新成员" parent:safeSelf];
                return;
            }
            
            DLogError(@"扫码加群失败，原因是：sucess=%d, resultCode=%@, groupInfo=%@", sucess, resultCode, safeSelf.groupInfo);
            [BasicTool showAlertInfo:@"加群失败" parent:safeSelf];
        } hudParentView:self.view];
    }
}

// 从服务端异步加载二维码分享者的基本信息
- (void)loadSharedByUserInfo {
    DLogDebug(@"loadSharedByUserInfo。。。。");
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    // 获取用户基本信息数据
    [[HttpRestHelper sharedInstance] submitGetFriendInfoToServer:NO
                                                            mail:nil
                                                             uid:self.sharedByUid
                                                        complete:^(BOOL sucess, UserEntity *userInfo) {
         if(sucess && userInfo != nil)  {
             safeSelf.sharedByUser = userInfo;
         } else {
             DLogError(@"无法获取sharedByUid=%@的用户信息（sucess=%d, userInfo=%@）", safeSelf.sharedByUid, sucess, userInfo);
         }
    } hudParentView:nil];
}

// 通过网络加载群基本信息
- (void)loadGroupInfo {
    DLogDebug(@"loadGroupInfo。。。。");
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    // 获取群基本信息数据
    [[HttpRestHelper sharedInstance] submitGetGroupInfoToServer:self.gid myUserId:nil complete:^(BOOL sucess, GroupEntity *groupInfo) {
        if(sucess) {
            if(groupInfo != nil) {
                safeSelf.groupInfo = groupInfo;
                [safeSelf resreshDatas:groupInfo];
            } else {
                // 该群不存在
                [safeSelf promtAndFinish:@"该群已不存在，请确认！"];
            }
        }
    } hudParentView:self.view];
}

// 异步加载群头像
- (void)loadGroupIcon {
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    // 尝试为群组加载群头像
    [FileDownloadHelper loadGroupAvatar:self.gid logTag:@"JoinGroupViewController"
        complete:^(BOOL sucess, UIImage *img) {
            if(sucess && img != nil)
                [safeSelf.viewIcon setImage:img];
    }];
}

//// 从当前界面退出
//- (void)doBack:(BOOL)animated {
//    [self.navigationController popViewControllerAnimated:animated];
//}
//
//// 统一的错误信息提示
//- (void)promtAndFinish:(NSString *)promtMsg {
//    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
//    __weak typeof(self) safeSelf = self;
//    // 显示信息提示框
//    [BasicTool showAlert:@"出错了" content:promtMsg btnTitle:@"确认" parent:self handler:^(UIAlertAction *action) {
//        [safeSelf doBack:YES];
//    }];
//}
    
@end
