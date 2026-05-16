//telegram @wz662
#import "GroupInfoEditViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"
#import "FileDownloadHelper.h"
#import "GroupsProvider.h"
#import "BasicTool.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"
#import "AppDelegate.h"
#import "GChatDataHelper.h"
#import "GMessageHelper.h"
#import "GroupInfoViewController.h"
#import "TimeTool.h"

@interface GroupInfoEditViewController () <UITextFieldDelegate, UITextViewDelegate>
// 本次修改的内容
@property (nonatomic, assign) int changeType;
// 群信息
@property (nonatomic, retain) GroupEntity *groupInfo;

// UI组件
@property (nonatomic, strong) UITextField *editField;       // 用于群名称 / 群昵称
@property (nonatomic, strong) UILabel *charCountLabel;      // 字数统计
@property (nonatomic, strong) UITextView *editTextView;     // 用于群公告
@property (nonatomic, strong) UILabel *noticeCountLabel;    // 群公告字数统计

// 群公告 - 修改人信息
@property (nonatomic, strong) UIView *editorInfoView;
@property (nonatomic, strong) UIImageView *editorAvatarView;
@property (nonatomic, strong) UILabel *editorNameLabel;
@property (nonatomic, strong) UILabel *editorTimeLabel;

@property (nonatomic, assign) BOOL canSave;
@end


@implementation GroupInfoEditViewController

#pragma mark - 初始化

- (id)initWithChangeType:(int)changeType andGroupInfo:(GroupEntity *)groupInfo
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.changeType = changeType;
        self.groupInfo = groupInfo;
    }
    return self;
}

// 兼容旧的调用方式
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withChangeType:(int)changeType andGroupInfo:(GroupEntity *)groupInfo
{
    return [self initWithChangeType:changeType andGroupInfo:groupInfo];
}

- (void)loadView
{
    self.view = [[UIView alloc] init];
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = HexColor(0xF0F0F0);

    NSString *plainTitle = @"";
    switch (self.changeType) {
        case IS_CHANGE_GROUP_NAME:
            plainTitle = @"群名称";
            break;
        case IS_CHANGE_MY_NICKNAME_IN_GROUP:
            plainTitle = @"我在本群的昵称";
            break;
        case IS_CHANGE_GROUP_REMARK:
            plainTitle = @"备注";
            break;
        case IS_CHANGE_GROUP_NOTICE:
            plainTitle = @"群公告";
            break;
        default:
            break;
    }

    self.navigationItem.titleView = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:plainTitle];

    BOOL isGroupOwner = [GroupsProvider isGroupOwner:self.groupInfo.g_owner_user_uid];
    self.canSave = YES;

    switch (self.changeType) {
        case IS_CHANGE_GROUP_NAME:
            [self buildGroupNameUI];
            if (!isGroupOwner) {
                self.canSave = NO;
                self.editField.enabled = NO;
                self.editField.textColor = [UIColor grayColor];
            }
            break;
        case IS_CHANGE_MY_NICKNAME_IN_GROUP:
        case IS_CHANGE_GROUP_REMARK:
            [self buildNicknameUI];
            break;
        case IS_CHANGE_GROUP_NOTICE:
            [self buildNoticeUI];
            if (!isGroupOwner) {
                self.canSave = NO;
                self.editTextView.editable = NO;
                self.editTextView.textColor = [UIColor grayColor];
            }
            break;
    }

    if (self.canSave) {
        [self groupInfoEdit_attachSaveToChromeNav];
    }

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)groupInfoEdit_attachSaveToChromeNav
{
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (!bar) {
        return;
    }
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"保存" forState:UIControlStateNormal];
    btn.tintColor = [UIColor blackColor];
    [btn addTarget:self action:@selector(doSave:) forControlEvents:UIControlEventTouchUpInside];
    [btn sizeToFit];
    CGFloat w = MAX(48.f, CGRectGetWidth(btn.bounds) + 8.f);
    btn.bounds = CGRectMake(0, 0, w, 44.f);
    [bar attachRightAccessoryView:btn];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor whiteColor];
        appearance.shadowColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
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
    if (self.isMovingFromParentViewController && @available(iOS 13.0, *)) {
        UINavigationBarAppearance *barApp = [[UINavigationBarAppearance alloc] init];
        barApp.backgroundColor = HexColor(0xfafafa);
        barApp.backgroundEffect = nil;
        barApp.shadowImage = [UIImage imageNamed:@"navigation_bar_shadow_image"];
        self.navigationController.navigationBar.scrollEdgeAppearance = barApp;
        self.navigationController.navigationBar.standardAppearance = barApp;
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}


#pragma mark - 群名称 UI

- (void)buildGroupNameUI
{
    UIView *card = [self buildCard];
    [self.view addSubview:card];
    
    // 提示标签
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.text = @"修改群聊名称后，将在群内通知其他成员。";
    hintLabel.font = [UIFont systemFontOfSize:13];
    hintLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    hintLabel.numberOfLines = 0;
    [self.view addSubview:hintLabel];
    
    // 输入框
    self.editField = [[UITextField alloc] init];
    self.editField.translatesAutoresizingMaskIntoConstraints = NO;
    self.editField.font = [UIFont systemFontOfSize:16];
    self.editField.textColor = [UIColor blackColor];
    self.editField.placeholder = @"请输入群名称";
    self.editField.text = self.groupInfo.g_name;
    self.editField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.editField.returnKeyType = UIReturnKeyDone;
    self.editField.delegate = self;
    [self.editField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [card addSubview:self.editField];
    
    // 字数统计
    self.charCountLabel = [[UILabel alloc] init];
    self.charCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.charCountLabel.font = [UIFont systemFontOfSize:12];
    self.charCountLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    self.charCountLabel.textAlignment = NSTextAlignmentRight;
    [self updateCharCount:self.editField.text maxLen:30];
    [card addSubview:self.charCountLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [self.editField.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [self.editField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [self.editField.trailingAnchor constraintEqualToAnchor:self.charCountLabel.leadingAnchor constant:-8],
        [self.editField.heightAnchor constraintEqualToConstant:28],
        
        [self.charCountLabel.centerYAnchor constraintEqualToAnchor:self.editField.centerYAnchor],
        [self.charCountLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [self.charCountLabel.widthAnchor constraintEqualToConstant:50],
        
        [self.editField.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
        
        [hintLabel.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:10],
        [hintLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [hintLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
    ]];
}


#pragma mark - 我在本群的昵称 UI

- (void)buildNicknameUI
{
    UIView *card = [self buildCard];
    [self.view addSubview:card];
    
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.text = @"设置后，此昵称将在本群内显示。";
    hintLabel.font = [UIFont systemFontOfSize:13];
    hintLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    hintLabel.numberOfLines = 0;
    [self.view addSubview:hintLabel];
    
    self.editField = [[UITextField alloc] init];
    self.editField.translatesAutoresizingMaskIntoConstraints = NO;
    self.editField.font = [UIFont systemFontOfSize:16];
    self.editField.textColor = [UIColor blackColor];
    self.editField.placeholder = @"请输入群昵称";
    self.editField.text = self.groupInfo.nickname_ingroup;
    self.editField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.editField.returnKeyType = UIReturnKeyDone;
    self.editField.delegate = self;
    [self.editField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [card addSubview:self.editField];
    
    self.charCountLabel = [[UILabel alloc] init];
    self.charCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.charCountLabel.font = [UIFont systemFontOfSize:12];
    self.charCountLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    self.charCountLabel.textAlignment = NSTextAlignmentRight;
    [self updateCharCount:self.editField.text maxLen:20];
    [card addSubview:self.charCountLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [self.editField.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [self.editField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [self.editField.trailingAnchor constraintEqualToAnchor:self.charCountLabel.leadingAnchor constant:-8],
        [self.editField.heightAnchor constraintEqualToConstant:28],
        
        [self.charCountLabel.centerYAnchor constraintEqualToAnchor:self.editField.centerYAnchor],
        [self.charCountLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [self.charCountLabel.widthAnchor constraintEqualToConstant:50],
        
        [self.editField.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
        
        [hintLabel.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:10],
        [hintLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [hintLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
    ]];
}


#pragma mark - 群公告 UI

- (void)buildNoticeUI
{
    // 修改人信息区域
    BOOL hasEditorInfo = ![BasicTool isStringEmpty:self.groupInfo.g_notice_updateuid];
    
    if (hasEditorInfo) {
        self.editorInfoView = [[UIView alloc] init];
        self.editorInfoView.translatesAutoresizingMaskIntoConstraints = NO;
        self.editorInfoView.backgroundColor = [UIColor whiteColor];
        [self.view addSubview:self.editorInfoView];
        
        self.editorAvatarView = [[UIImageView alloc] init];
        self.editorAvatarView.translatesAutoresizingMaskIntoConstraints = NO;
        self.editorAvatarView.image = [UIImage imageNamed:@"default_avatar_60"];
        self.editorAvatarView.contentMode = UIViewContentModeScaleAspectFill;
        self.editorAvatarView.layer.cornerRadius = 20;
        self.editorAvatarView.layer.masksToBounds = YES;
        [self.editorInfoView addSubview:self.editorAvatarView];
        
        self.editorNameLabel = [[UILabel alloc] init];
        self.editorNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.editorNameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        self.editorNameLabel.textColor = [UIColor blackColor];
        self.editorNameLabel.text = self.groupInfo.g_notice_updatenick;
        [self.editorInfoView addSubview:self.editorNameLabel];
        
        self.editorTimeLabel = [[UILabel alloc] init];
        self.editorTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.editorTimeLabel.font = [UIFont systemFontOfSize:12];
        self.editorTimeLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        self.editorTimeLabel.text = self.groupInfo.g_notice_updatetime;
        [self.editorInfoView addSubview:self.editorTimeLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.editorInfoView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [self.editorInfoView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.editorInfoView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            
            [self.editorAvatarView.topAnchor constraintEqualToAnchor:self.editorInfoView.topAnchor constant:14],
            [self.editorAvatarView.leadingAnchor constraintEqualToAnchor:self.editorInfoView.leadingAnchor constant:20],
            [self.editorAvatarView.widthAnchor constraintEqualToConstant:40],
            [self.editorAvatarView.heightAnchor constraintEqualToConstant:40],
            [self.editorAvatarView.bottomAnchor constraintEqualToAnchor:self.editorInfoView.bottomAnchor constant:-14],
            
            [self.editorNameLabel.topAnchor constraintEqualToAnchor:self.editorAvatarView.topAnchor constant:1],
            [self.editorNameLabel.leadingAnchor constraintEqualToAnchor:self.editorAvatarView.trailingAnchor constant:10],
            [self.editorNameLabel.trailingAnchor constraintEqualToAnchor:self.editorInfoView.trailingAnchor constant:-20],
            
            [self.editorTimeLabel.bottomAnchor constraintEqualToAnchor:self.editorAvatarView.bottomAnchor constant:-1],
            [self.editorTimeLabel.leadingAnchor constraintEqualToAnchor:self.editorAvatarView.trailingAnchor constant:10],
            [self.editorTimeLabel.trailingAnchor constraintEqualToAnchor:self.editorInfoView.trailingAnchor constant:-20],
        ]];
        
        // 加载头像
        [FileDownloadHelper loadUserAvatarWithUID:self.groupInfo.g_notice_updateuid logTag:@"GroupInfoEditVC-UID" complete:^(BOOL sucess, UIImage *img) {
            if (sucess && img != nil) {
                [self.editorAvatarView setImage:img];
            }
        } donotLoadFromDisk:YES];
    }
    
    // 输入卡片
    UIView *card = [self buildCard];
    [self.view addSubview:card];
    
    self.editTextView = [[UITextView alloc] init];
    self.editTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.editTextView.font = [UIFont systemFontOfSize:16];
    self.editTextView.textColor = [UIColor blackColor];
    self.editTextView.text = self.groupInfo.g_notice;
    self.editTextView.backgroundColor = [UIColor clearColor];
    self.editTextView.delegate = self;
    self.editTextView.textContainerInset = UIEdgeInsetsZero;
    self.editTextView.textContainer.lineFragmentPadding = 0;
    [card addSubview:self.editTextView];
    
    // placeholder
    if ([BasicTool isStringEmpty:self.editTextView.text]) {
        self.editTextView.text = @"";
    }
    
    // 字数统计
    self.noticeCountLabel = [[UILabel alloc] init];
    self.noticeCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.noticeCountLabel.font = [UIFont systemFontOfSize:12];
    self.noticeCountLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    self.noticeCountLabel.textAlignment = NSTextAlignmentRight;
    [self updateNoticeCount:self.editTextView.text];
    [card addSubview:self.noticeCountLabel];
    
    UIView *topAnchorView = hasEditorInfo ? self.editorInfoView : nil;
    
    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:(topAnchorView ? topAnchorView.bottomAnchor : self.view.safeAreaLayoutGuide.topAnchor)],
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [self.editTextView.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [self.editTextView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [self.editTextView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [self.editTextView.heightAnchor constraintGreaterThanOrEqualToConstant:120],
        
        [self.noticeCountLabel.topAnchor constraintEqualToAnchor:self.editTextView.bottomAnchor constant:8],
        [self.noticeCountLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [self.noticeCountLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12],
    ]];
}


#pragma mark - UI Helpers

- (UIView *)buildCard
{
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor whiteColor];
    return card;
}

- (void)updateCharCount:(NSString *)text maxLen:(NSInteger)maxLen
{
    NSInteger len = text.length;
    self.charCountLabel.text = [NSString stringWithFormat:@"%ld/%ld", (long)len, (long)maxLen];
    if (len > maxLen) {
        self.charCountLabel.textColor = [UIColor redColor];
    } else {
        self.charCountLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    }
}

- (void)updateNoticeCount:(NSString *)text
{
    NSInteger len = text.length;
    self.noticeCountLabel.text = [NSString stringWithFormat:@"%ld/500", (long)len];
    if (len > 500) {
        self.noticeCountLabel.textColor = [UIColor redColor];
    } else {
        self.noticeCountLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    }
}


#pragma mark - UITextField Delegate

- (void)textFieldDidChange:(UITextField *)textField
{
    NSInteger maxLen = (self.changeType == IS_CHANGE_GROUP_NAME) ? 30 : 20;
    [self updateCharCount:textField.text maxLen:maxLen];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSInteger maxLen = (self.changeType == IS_CHANGE_GROUP_NAME) ? 30 : 20;
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (newText.length > maxLen) {
        return NO;
    }
    return YES;
}


#pragma mark - UITextView Delegate

- (void)textViewDidChange:(UITextView *)textView
{
    [self updateNoticeCount:textView.text];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    // 空内容按回车：仅收起键盘，不插入换行
    if ([text isEqualToString:@"\n"]) {
        NSString *trimmed = [textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) {
            [textView resignFirstResponder];
            return NO;
        }
    }

    NSString *newText = [textView.text stringByReplacingCharactersInRange:range withString:text];
    if (newText.length > 500) {
        return NO;
    }
    return YES;
}


#pragma mark - 手势事件

- (void)fingerTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    [self.view endEditing:YES];
}


#pragma mark - 保存逻辑

- (void)doSave:(id)sender
{
    switch (self.changeType) {
        case IS_CHANGE_GROUP_NAME:
            [self doSaveForGroupName];
            break;
        case IS_CHANGE_MY_NICKNAME_IN_GROUP:
        case IS_CHANGE_GROUP_REMARK:
            [self doSaveForNicknameInGroup];
            break;
        case IS_CHANGE_GROUP_NOTICE:
            [self doSaveForNotice];
            break;
    }
}

// 提交修改：群名称
- (void)doSaveForGroupName
{
    __weak typeof(self) safeSelf = self;
    
    NSString *newGname = [BasicTool trim:self.editField.text];
    NSString *oldGname = self.groupInfo.g_name;
    
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    
    if ([BasicTool isStringEmpty:newGname]) {
        [APP showToastWarn:@"群名称不能为空!"];
        return;
    }
    
    if ([BasicTool isStringEmpty:oldGname] || ![oldGname isEqualToString:newGname]) {
        [[HttpRestHelper sharedInstance] submitGroupNameModifiyToServer:newGname gid:self.groupInfo.g_id modify_by_uid:localUserInfo.user_uid modify_by_nickname:localUserInfo.nickname complete:^(BOOL sucess, NSString *resultCode) {
            if (sucess && [@"1" isEqualToString:resultCode]) {
                self.groupInfo.g_name = newGname;
                [GChatDataHelper addSystemInfo_groupNameChangedForLocalUser:self.groupInfo.g_id newGroupname:self.groupInfo.g_name];
                [self showSucessHintAndBack];
            } else {
                [BasicTool showAlertInfo:@"保存失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
            }
        } hudParentView:self.view];
    } else {
        [self doBack:YES];
    }
}

// 提交修改：我的群昵称
- (void)doSaveForNicknameInGroup
{
    __weak typeof(self) safeSelf = self;
    
    NSString *newNicknameInGroup = [BasicTool trim:self.editField.text];
    NSString *oldNicknameInGroup = self.groupInfo.nickname_ingroup;
    
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    
    if ([BasicTool isStringEmpty:oldNicknameInGroup] || ![oldNicknameInGroup isEqualToString:newNicknameInGroup]) {
        [[HttpRestHelper sharedInstance] submitGroupNickNameModifiyToServer:newNicknameInGroup gid:self.groupInfo.g_id user_uid:localUserInfo.user_uid complete:^(BOOL sucess, NSString *resultCode) {
            if (sucess && [@"1" isEqualToString:resultCode]) {
                self.groupInfo.nickname_ingroup = newNicknameInGroup;
                [self showSucessHintAndBack];
            } else {
                [BasicTool showAlertInfo:@"保存失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
            }
        } hudParentView:self.view];
    } else {
        [self doBack:YES];
    }
}

// 提交修改：群公告
- (void)doSaveForNotice
{
    __weak typeof(self) safeSelf = self;
    
    NSString *newNotice = [BasicTool trim:self.editTextView.text];
    NSString *oldNotice = self.groupInfo.g_notice;
    
    UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
    
    if ([BasicTool isStringEmpty:oldNotice] || ![oldNotice isEqualToString:newNotice]) {
        [[HttpRestHelper sharedInstance] submitGroupNoticeModifiyToServer:newNotice g_notice_updateuid:localUserInfo.user_uid gid:self.groupInfo.g_id complete:^(BOOL sucess, NSString *resultCode) {
            if (sucess) {
                if ([@"2" isEqualToString:resultCode]) {
                    [BasicTool showAlertInfo:@"您已不是群主，本次修改失败！" parent:safeSelf];
                }
                else if ([@"1" isEqualToString:resultCode]) {
                    NSString *fullNoticeContent = newNotice;
                    
                    self.groupInfo.g_notice = fullNoticeContent;
                    self.groupInfo.g_notice_updateuid = localUserInfo.user_uid;
                    self.groupInfo.g_notice_updatenick = localUserInfo.nickname;
                    self.groupInfo.g_notice_updatetime = [TimeTool getTimeString:[TimeTool getIOSDefaultDate] format:@"yyyy-MM-dd HH:mm"];
                    [[[IMClientManager sharedInstance] getGroupsProvider] updateGroup:self.groupInfo];
                    
                    if (![BasicTool isStringEmpty:[BasicTool trim:fullNoticeContent]]) {
                        [BasicTool areYouSureAlert:@"通知确认" content:@"该公告已修改成功，是否通知全部群成员？" okBtnTitle:@"通知" cancelBtnTitle:NSLocalizedString(@"general_cancel", @"") parent:safeSelf okHandler:^(UIAlertAction * _Nullable action) {
                            
                            NSString *noticeUpdateMsg = [NSString stringWithFormat:@"@所有人\n【群公告】%@", [BasicTool truncString:fullNoticeContent maxLen:450]];
                            
                            [GMessageHelper sendPlainTextMessageAsync:self.groupInfo.g_id
                                                          withMessage:noticeUpdateMsg
                                                                   at:@[@"0"]
                                                                quote:nil
                                                            forSucess:^(id observerble, id arg1) {
                                int code = [arg1 intValue];
                                if (code != 0) {
                                    [APP showToastWarn:[NSString stringWithFormat:@"公告消息没有成功送出，原因是：code=%d", code]];
                                } else {
                                    [self doBack:NO];
                                    if (self.resultBackdelegate) {
                                        [self.resultBackdelegate onViewControllerResultBack:REQUEST_CODE_FOR_EDIT_NOTICE resultCode:ViewControllerResultBack_RESULT_OK withData:self.groupInfo];
                                    }
                                }
                            }];
                        } cancelHandler:^(UIAlertAction * _Nullable action) {
                            if (safeSelf.resultBackdelegate) {
                                [safeSelf.resultBackdelegate onViewControllerResultBack:REQUEST_CODE_FOR_EDIT_NOTICE resultCode:ViewControllerResultBack_RESULT_OK withData:safeSelf.groupInfo];
                            }
                            [safeSelf doBack:YES];
                        } cencelActionStyle:UIAlertActionStyleCancel];
                    } else {
                        if (self.resultBackdelegate) {
                            [self.resultBackdelegate onViewControllerResultBack:REQUEST_CODE_FOR_EDIT_NOTICE resultCode:ViewControllerResultBack_RESULT_OK withData:self.groupInfo];
                        }
                        [self showSucessHintAndBack];
                    }
                } else {
                    [BasicTool showAlertInfo:@"保存失败，请稍后再试！" parent:safeSelf];
                }
            } else {
                [BasicTool showAlertInfo:@"保存失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
            }
        } hudParentView:self.view];
    } else {
        [self doBack:YES];
    }
}


#pragma mark - 导航

- (void)showSucessHintAndBack
{
    [APP showUserDefineToast_OK:@"保存成功" atHide:nil];
    [self doBack:YES];
}

- (void)doBack:(BOOL)animated
{
    [self.navigationController popViewControllerAnimated:animated];
}

@end
