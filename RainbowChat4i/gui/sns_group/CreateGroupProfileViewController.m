#import "CreateGroupProfileViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"
#import "RBImagePickerWrapper.h"
#import "BasicTool.h"
#import "AppDelegate.h"
#import "Default.h"
#import "FileTool.h"
#import "FileUploadHelper.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "GroupsProvider.h"
#import "AlarmsProvider.h"
#import "GChatDataHelper.h"
#import "ViewControllerFactory.h"
#import "FileDownloadHelper.h"
#import "NotificationCenterFactory.h"
#import "MBProgressHUD.h"

@interface CreateGroupProfileViewController () <RBImagePickerCompleteDelegate, UITextFieldDelegate>

@property (nonatomic, strong) NSArray<GroupMemberEntity *> *membersForCreate;
@property (nonatomic, strong) NSArray<GroupMemberEntity *> *membersWithoutLocal;

@property (nonatomic, strong) RBImagePickerWrapper *imagePickerWrapper;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UITextField *nameField;

@property (nonatomic, strong) UIImage *pickedAvatar;

@end

@implementation CreateGroupProfileViewController

- (id)initWithMembersForCreate:(NSArray<GroupMemberEntity *> *)membersForCreate membersWithoutLocal:(NSArray<GroupMemberEntity *> *)membersWithoutLocal
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.membersForCreate = membersForCreate ?: @[];
        self.membersWithoutLocal = membersWithoutLocal ?: @[];
    }
    return self;
}

- (void)loadView
{
    self.view = [[UIView alloc] init];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = HexColor(0xF0F0F0);
    [self rb_installPlainCustomNavigationBarWithTitle:@"群聊信息"];

    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (bar) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:@"创建" forState:UIControlStateNormal];
        btn.tintColor = [UIColor blackColor];
        [btn addTarget:self action:@selector(doCreate:) forControlEvents:UIControlEventTouchUpInside];
        [btn sizeToFit];
        CGFloat w = MAX(48.f, CGRectGetWidth(btn.bounds) + 8.f);
        btn.bounds = CGRectMake(0, 0, w, 44.f);
        [bar attachRightAccessoryView:btn];
    } else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"创建" style:UIBarButtonItemStylePlain target:self action:@selector(doCreate:)];
    }

    self.imagePickerWrapper = [[RBImagePickerWrapper alloc] initWithParent:self delegate:self crop:YES];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:card];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onPickAvatar)];
    tap.cancelsTouchesInView = YES;

    UIImageView *av = [[UIImageView alloc] init];
    av.translatesAutoresizingMaskIntoConstraints = NO;
    av.backgroundColor = HexColor(0xEEEEEE);
    av.layer.cornerRadius = 32.0f;
    av.layer.masksToBounds = YES;
    av.contentMode = UIViewContentModeScaleAspectFill;
    av.userInteractionEnabled = YES;
    [av addGestureRecognizer:tap];
    [card addSubview:av];
    self.avatarView = av;

    UILabel *avatarHint = [[UILabel alloc] init];
    avatarHint.translatesAutoresizingMaskIntoConstraints = NO;
    avatarHint.text = @"设置群头像";
    avatarHint.textColor = HexColor(0x333333);
    avatarHint.font = [UIFont systemFontOfSize:16];
    [card addSubview:avatarHint];

    UITextField *tf = [[UITextField alloc] init];
    tf.translatesAutoresizingMaskIntoConstraints = NO;
    tf.placeholder = @"请输入群聊名称";
    tf.font = [UIFont systemFontOfSize:16];
    tf.textColor = [UIColor blackColor];
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.returnKeyType = UIReturnKeyDone;
    tf.delegate = self;
    [card addSubview:tf];
    self.nameField = tf;

    UIView *sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = HexColor(0xEAEAEA);
    [card addSubview:sep];

    UILabel *tip = [[UILabel alloc] init];
    tip.translatesAutoresizingMaskIntoConstraints = NO;
    tip.text = @"不设置头像将使用系统自定义头像";
    tip.textColor = HexColor(0x999999);
    tip.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:tip];

    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [card.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],

        [av.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [av.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [av.widthAnchor constraintEqualToConstant:64],
        [av.heightAnchor constraintEqualToConstant:64],

        [avatarHint.leadingAnchor constraintEqualToAnchor:av.trailingAnchor constant:12],
        [avatarHint.centerYAnchor constraintEqualToAnchor:av.centerYAnchor],

        [sep.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [sep.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [sep.topAnchor constraintEqualToAnchor:av.bottomAnchor constant:16],
        [sep.heightAnchor constraintEqualToConstant:1],

        [tf.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [tf.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [tf.topAnchor constraintEqualToAnchor:sep.bottomAnchor constant:12],
        [tf.heightAnchor constraintEqualToConstant:44],
        [tf.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12],

        [tip.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [tip.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [tip.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:10],
    ]];
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

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void)onPickAvatar
{
    [self.imagePickerWrapper takeAlbum:NO];
}

- (NSString *)rb_trimmedName
{
    NSString *n = [self.nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (n.length > 29) n = [n substringToIndex:29];
    return n;
}

- (void)doCreate:(id)sender
{
    NSString *name = [self rb_trimmedName];
    if (name.length == 0) {
        [BasicTool showAlertInfo:@"请输入群聊名称" parent:self];
        return;
    }

    if (self.pickedAvatar == nil) {
        [BasicTool showAlertInfo:@"请设置群头像" parent:self];
        return;
    }

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = @"建群中..";
    
    __weak typeof(self) safeSelf = self;
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    [[HttpRestHelper sharedInstance] submitCreateGroupToServer:localUserInfo.user_uid
                                             localUserNickname:localUserInfo.nickname
                                                       members:self.membersForCreate
                                                      complete:^(BOOL sucess, GroupEntity *newGroupInfo) {
        [hud hideAnimated:YES];
        if (newGroupInfo != nil) {
            newGroupInfo.g_name = name;
            [[[IMClientManager sharedInstance] getGroupsProvider] putGroup:newGroupInfo];
            [AlarmsProvider addAGroupChatMsgAlarmForLocal:TM_TYPE_TEXT gid:newGroupInfo.g_id gname:name msg:@"点此随时可开始群聊。"];
            [ViewControllerFactory goGroupChattingViewController:safeSelf.navigationController gid:newGroupInfo.g_id gname:name animated:NO popToRootFirst:YES highlight:nil];
            [APP showUserDefineToast_OK:@"建群成功" atHide:nil];
            [safeSelf rb_asyncSetGroupName:name gid:newGroupInfo.g_id];
            [safeSelf rb_asyncUploadAndSetGroupAvatar:safeSelf.pickedAvatar gid:newGroupInfo.g_id];
        } else {
            if (sucess) {
                [BasicTool showAlertError:@"建群失败，请稍后再试！" parent:safeSelf];
            } else {
                [BasicTool showAlertError:@"建群失败，请检查网络后重试！" parent:safeSelf];
            }
        }
    } hudParentView:self.view];
}

- (void)rb_asyncSetGroupName:(NSString *)groupName gid:(NSString *)gid
{
    if (groupName.length == 0 || gid.length == 0) return;
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitGroupNameModifiyToServer:groupName
                                                                gid:gid
                                                      modify_by_uid:localUserInfo.user_uid
                                                 modify_by_nickname:localUserInfo.nickname
                                                           complete:^(BOOL sucess, NSString *resultCode) {
        if (sucess && [@"1" isEqualToString:resultCode]) {
            GroupsProvider *gp = [[IMClientManager sharedInstance] getGroupsProvider];
            GroupEntity *ge = [gp getGroupInfoByGid:gid];
            if (ge != nil) {
                ge.g_name = groupName;
                [gp updateGroup:ge];
            }
            [NotificationCenterFactory groupNameChanged_POST:gid newGroupName:groupName];
        } else {
            __strong typeof(wself) sself = wself;
            if (sself) [APP showToastWarn:@"群名称设置失败"];
        }
    } hudParentView:nil];
}

- (void)rb_asyncUploadAndSetGroupAvatar:(UIImage *)photo gid:(NSString *)gid
{
    if (photo == nil || gid.length == 0) return;
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid ?: @"";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *savedDir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_AVATART_RELATIVE_DIR];
        [FileTool tryCreateDirs:savedDir];
        
        NSString *tempFileName = [NSString stringWithFormat:@"_temp_group_avatar_%@", gid];
        NSString *filePathAfterCompress = [BasicTool imageCompressForQualityAndWidth:photo
                                                                       targetQuality:LOCAL_AVATAR_IMAGE_QUALITY
                                                                         targetWidth:LOCAL_AVATAR_SIZE
                                                                           saveToDir:savedDir
                                                                           savedName:tempFileName];
        if (filePathAfterCompress == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [APP showToastWarn:@"群头像处理失败"];
            });
            return;
        }
        
        NSString *md5ForFile = [FileTool getFileMD5WithPath:filePathAfterCompress];
        if (md5ForFile == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [APP showToastWarn:@"群头像处理失败"];
            });
            return;
        }
        
        NSString *groupAvatarFileName = [NSString stringWithFormat:@"group_avatar_%@_%@.jpg", gid, md5ForFile];
        NSString *renamedPath = [NSString stringWithFormat:@"%@/%@", savedDir, groupAvatarFileName];
        [FileTool renameFile:filePathAfterCompress toFilePath:renamedPath];
        
        NSString *uploadUrl = MSG_IMG_UPLODER_URL_ROOT;
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"user_uid"] = localUid;
        params[@"file_name"] = groupAvatarFileName;
        
        [FileUploadHelper uploadFileImpl:renamedPath
                                withName:groupAvatarFileName
                                  andUrl:uploadUrl
                           andParameters:params
                                progress:nil
                                 success:^(__unused NSURLSessionDataTask *task, __unused id responseObject) {
            [[HttpRestHelper sharedInstance] submitSetGroupAvatarToServer:localUid
                                                                     gid:gid
                                                               avatarUrl:groupAvatarFileName
                                                                complete:^(BOOL sucess, NSString *resultCode) {
                if (sucess && [@"1" isEqualToString:resultCode]) {
                    GroupsProvider *gp = [[IMClientManager sharedInstance] getGroupsProvider];
                    GroupEntity *ge = [gp getGroupInfoByGid:gid];
                    if (ge != nil) {
                        ge.g_custom_avatar = groupAvatarFileName;
                        [gp updateGroup:ge];
                    }
                    [FileDownloadHelper clearGroupAvatarCache:gid];
                    [NotificationCenterFactory resetGroupAvatarCache_POST:gid];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [APP showToastWarn:@"群头像设置失败"];
                    });
                }
            } hudParentView:nil];
        } failure:^(__unused NSURLSessionDataTask *task, __unused NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [APP showToastWarn:@"群头像上传失败"];
            });
        }];
    });
}

- (void)processImagePickerComplete:(UIImage *)photo withTag:(NSString *)tag
{
    if (photo == nil) {
        [BasicTool showAlertError:@"图片选择失败!" parent:self];
        return;
    }
    self.pickedAvatar = photo;
    self.avatarView.image = photo;
}

@end
