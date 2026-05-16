//telegram @wz662
//
//  FriendRemarkEditViewController.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/12/4.
//  Copyright © 2021 JackJiang. All rights reserved.
//

#import "FriendRemarkEditViewController.h"
#import "UserEntity.h"
#import "BasicTool.h"
#import "UITextView+ZWPlaceHolder.h"
#import "UITextView+ZWLimitCounter.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "AlarmType.h"
#import "NotificationCenterFactory.h"
#import "UIViewController+RBPlainCustomNav.h"
#import "RBChromeNavigationBar.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

// 好友备注最大字符数(汉字)
static const int FRIEND_REMARK_MAX_LENGTH = 16;
// 手机号码最大字符数
static const int FRIEND_MOBILE_NUM_LENGTH = 25;
// 更多描述最大字符数
static const int FRIEND_MORE_DESC_LENGTH  = 200;


@interface FriendRemarkEditViewController ()
// 好友的uid（来自调用者传参）
@property (nonatomic, retain) NSString *friendUidForInit;
// 好友列表中的好友信息对象引用
@property (nonatomic, retain) UserEntity *friendInfo;
// 字数统计标签
@property (nonatomic, strong) UILabel *remarkCountLabel;
@property (nonatomic, strong) UILabel *mobileCountLabel;
@property (nonatomic, weak) UIButton *rbRemarkDoneChromeButton;
@end

@implementation FriendRemarkEditViewController

#pragma mark - 初始化

- (id)initWithUid:(NSString *)friendUid
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.friendUidForInit = friendUid;
    }
    return self;
}

// 兼容旧的调用方式
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withUid:(NSString *)friendUid
{
    return [self initWithUid:friendUid];
}

- (void)loadView
{
    self.view = [[UIView alloc] init];
}

#pragma mark - 生命周期

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"设置备注和标签";
    self.view.backgroundColor = HexColor(0xF0F0F0);
    self.navigationItem.titleView = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @"设置备注和标签"];
    [self friendRemark_attachDoneToChromeNav];

    [self buildUI];
    [self initData];
    [self refreshToView:self.friendInfo];
    [self _setOkButtonEnable:NO];

    // 点击空白处收起键盘
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)friendRemark_attachDoneToChromeNav
{
    RBChromeNavigationBar *bar = [self rb_plainChromeNavigationBarIfInstalled];
    if (!bar) {
        return;
    }
    UIButton *done = [UIButton buttonWithType:UIButtonTypeCustom];
    [done setTitle:@"完成" forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [done setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [done setTitleColor:[UIColor colorWithWhite:0.55 alpha:1] forState:UIControlStateDisabled];
    [done addTarget:self action:@selector(doSave:) forControlEvents:UIControlEventTouchUpInside];
    [done sizeToFit];
    CGFloat dw = MAX(44.f, CGRectGetWidth(done.bounds) + 12.f);
    done.bounds = CGRectMake(0, 0, dw, 44.f);
    self.rbRemarkDoneChromeButton = done;
    [bar attachRightAccessoryView:done];
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
    // 顶栏 didAppear 会统一刷右侧按钮样式，这里再同步一次「完成」可用态
    [self setOkButtonForChanged];
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

#pragma mark - 构建UI

- (void)buildUI
{
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    if (@available(iOS 11.0, *)) {
        scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:scrollView];
    
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];

    RBChromeNavigationBar *chrome = [self rb_plainChromeNavigationBarIfInstalled];
    NSLayoutYAxisAnchor *scrollTopRef = chrome != nil ? chrome.bottomAnchor : self.view.safeAreaLayoutGuide.topAnchor;
    
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:scrollTopRef],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],
    ]];
    
    // ========== Section 1: 备注 ==========
    UIView *remarkSection = [self buildRemarkSection];
    remarkSection.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:remarkSection];
    
    // ========== Section 2: 更多描述 ==========
    UIView *descSection = [self buildDescSection];
    descSection.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:descSection];
    
    [NSLayoutConstraint activateConstraints:@[
        [remarkSection.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [remarkSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [remarkSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        
        [descSection.topAnchor constraintEqualToAnchor:remarkSection.bottomAnchor constant:10],
        [descSection.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [descSection.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        
        [descSection.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-30],
    ]];
}

#pragma mark - 备注区域

- (UIView *)buildRemarkSection
{
    UIView *section = [[UIView alloc] init];
    section.backgroundColor = [UIColor whiteColor];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"备注名";
    titleLabel.font = [UIFont systemFontOfSize:14];
    titleLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    [section addSubview:titleLabel];
    
    // 字数统计
    self.remarkCountLabel = [[UILabel alloc] init];
    self.remarkCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.remarkCountLabel.font = [UIFont systemFontOfSize:12];
    self.remarkCountLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    self.remarkCountLabel.textAlignment = NSTextAlignmentRight;
    [section addSubview:self.remarkCountLabel];
    
    // 输入框
    self.editRemark = [[UITextField alloc] init];
    self.editRemark.translatesAutoresizingMaskIntoConstraints = NO;
    self.editRemark.font = [UIFont systemFontOfSize:17];
    self.editRemark.textColor = [UIColor blackColor];
    self.editRemark.placeholder = @"请输入备注名";
    self.editRemark.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.editRemark.returnKeyType = UIReturnKeyDone;
    [self.editRemark addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [section addSubview:self.editRemark];
    
    // 底部分隔线
    UIView *sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = HexColor(0xE6E6E6);
    [section addSubview:sep];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:section.topAnchor constant:14],
        [titleLabel.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        
        [self.remarkCountLabel.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [self.remarkCountLabel.trailingAnchor constraintEqualToAnchor:section.trailingAnchor constant:-20],
        
        [self.editRemark.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
        [self.editRemark.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [self.editRemark.trailingAnchor constraintEqualToAnchor:section.trailingAnchor constant:-20],
        [self.editRemark.heightAnchor constraintEqualToConstant:36],
        [self.editRemark.bottomAnchor constraintEqualToAnchor:section.bottomAnchor constant:-14],
        
        [sep.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
        [sep.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [sep.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [sep.heightAnchor constraintEqualToConstant:0.5],
    ]];
    
    return section;
}

#pragma mark - 手机号码区域

- (UIView *)buildMobileSection
{
    UIView *section = [[UIView alloc] init];
    section.backgroundColor = [UIColor whiteColor];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"手机号码";
    titleLabel.font = [UIFont systemFontOfSize:14];
    titleLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    [section addSubview:titleLabel];
    
    // 字数统计
    self.mobileCountLabel = [[UILabel alloc] init];
    self.mobileCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.mobileCountLabel.font = [UIFont systemFontOfSize:12];
    self.mobileCountLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    self.mobileCountLabel.textAlignment = NSTextAlignmentRight;
    [section addSubview:self.mobileCountLabel];
    
    // 输入框
    self.editMobileNum = [[UITextField alloc] init];
    self.editMobileNum.translatesAutoresizingMaskIntoConstraints = NO;
    self.editMobileNum.font = [UIFont systemFontOfSize:17];
    self.editMobileNum.textColor = [UIColor blackColor];
    self.editMobileNum.placeholder = @"请输入手机号码";
    self.editMobileNum.keyboardType = UIKeyboardTypePhonePad;
    self.editMobileNum.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self.editMobileNum addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [section addSubview:self.editMobileNum];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:section.topAnchor constant:14],
        [titleLabel.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        
        [self.mobileCountLabel.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [self.mobileCountLabel.trailingAnchor constraintEqualToAnchor:section.trailingAnchor constant:-20],
        
        [self.editMobileNum.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
        [self.editMobileNum.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [self.editMobileNum.trailingAnchor constraintEqualToAnchor:section.trailingAnchor constant:-20],
        [self.editMobileNum.heightAnchor constraintEqualToConstant:36],
        [self.editMobileNum.bottomAnchor constraintEqualToAnchor:section.bottomAnchor constant:-14],
    ]];
    
    return section;
}

#pragma mark - 更多描述区域

- (UIView *)buildDescSection
{
    UIView *section = [[UIView alloc] init];
    section.backgroundColor = [UIColor whiteColor];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"描述";
    titleLabel.font = [UIFont systemFontOfSize:14];
    titleLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    [section addSubview:titleLabel];
    
    // 文本输入区
    self.editMoreDesc = [[UITextView alloc] init];
    self.editMoreDesc.translatesAutoresizingMaskIntoConstraints = NO;
    self.editMoreDesc.font = [UIFont systemFontOfSize:17];
    self.editMoreDesc.textColor = [UIColor blackColor];
    self.editMoreDesc.backgroundColor = [UIColor clearColor];
    self.editMoreDesc.delegate = self;
    self.editMoreDesc.scrollEnabled = NO;
    self.editMoreDesc.textContainerInset = UIEdgeInsetsZero;
    self.editMoreDesc.textContainer.lineFragmentPadding = 0;
    [section addSubview:self.editMoreDesc];
    
    // 设置placeholder和字数限制
    self.editMoreDesc.zw_placeHolder = @"添加更多描述信息";
    self.editMoreDesc.zw_limitCount = FRIEND_MORE_DESC_LENGTH;
    [self.editMoreDesc.zw_inputLimitLabel setFont:[UIFont systemFontOfSize:12]];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:section.topAnchor constant:14],
        [titleLabel.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        
        [self.editMoreDesc.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
        [self.editMoreDesc.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:20],
        [self.editMoreDesc.trailingAnchor constraintEqualToAnchor:section.trailingAnchor constant:-20],
        [self.editMoreDesc.heightAnchor constraintGreaterThanOrEqualToConstant:80],
        [self.editMoreDesc.bottomAnchor constraintEqualToAnchor:section.bottomAnchor constant:-14],
    ]];
    
    return section;
}


#pragma mark - 数据初始化

- (void)initData
{
    if (self.friendUidForInit != nil) {
        self.friendInfo = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:self.friendUidForInit];
    }
    
    if (self.friendInfo == nil) {
        DDLogWarn(@"设置好友备注界面中，this.friendInfo == null！");
        [BasicTool showAlertWarn:@"无效的好友信息！" parent:self];
        [self doBack:YES];
    }
}

- (void)refreshToView:(UserEntity *)friendInfo
{
    if (friendInfo != nil) {
        // 如果已有备注则显示备注，否则自动填充用户昵称方便修改
        if (![BasicTool isStringEmpty:friendInfo.friendRemark]) {
            self.editRemark.text = friendInfo.friendRemark;
        } else {
            self.editRemark.text = friendInfo.nickname;
        }
        self.editMoreDesc.text = friendInfo.friendMoreDesc;
    } else {
        DDLogWarn(@"设置好友备注界面中，refreshToView时，friendInfo == nil！");
        [BasicTool showAlertWarn:@"无效的好友信息，无法刷新界面的相关显示！" parent:self];
    }
    
    // 将光标移至文字末尾
    [BasicTool setCursorToEnd:self.editRemark];
    
    // 显示初始的输入字数统计值等
    [self textFieldDidChange:self.editRemark];
}


#pragma mark - UITextField输入事件处理

- (NSString *)getEditStringLengthStr:(UITextField *)v max:(int)maxLength
{
    long length = 0;
    NSString *s = v.text;
    if (s != nil) {
        length = s.length;
    }
    return [NSString stringWithFormat:@"%ld/%d", length, maxLength];
}

// 监听输入事件
- (void)textFieldDidChange:(UITextField *)textField
{
    if (textField == self.editRemark) {
        if (self.editRemark.text.length > FRIEND_REMARK_MAX_LENGTH) {
            self.editRemark.text = [self.editRemark.text substringToIndex:FRIEND_REMARK_MAX_LENGTH];
        }
        self.remarkCountLabel.text = [self getEditStringLengthStr:self.editRemark max:FRIEND_REMARK_MAX_LENGTH];
    }
    [self setOkButtonForChanged];
}


#pragma mark - UITextView的输入事件回调

- (void)textViewDidChange:(UITextView *)textView
{
    [self setOkButtonForChanged];
}


#pragma mark - 手势事件处理

- (void)fingerTapped:(UITapGestureRecognizer *)gestureRecognizer
{
    [self.view endEditing:YES];
}


#pragma mark - 数据提交相关方法

- (void)doSave:(id)sender
{
    __weak typeof(self) safeSelf = self;
    
    UserEntity *localRee = [IMClientManager sharedInstance].localUserInfo;
    if (localRee == nil)
        return;
    
    NSString *remark = [BasicTool trim:self.editRemark.text];
    NSString *moreDesc = [BasicTool trim:self.editMoreDesc.text];
    
    [[HttpRestHelper sharedInstance] submitRosterRemarkModifiyToServer:remark mobileNum:@"" moreDesc:moreDesc localUid:localRee.user_uid friendUid:self.friendUidForInit complete:^(BOOL sucess, NSString *resultCode) {
        
        if (sucess && [@"1" isEqualToString:resultCode]) {
            // 更新缓存在内存里的好友信息
            safeSelf.friendInfo.friendRemark = remark;
            safeSelf.friendInfo.friendMoreDesc = moreDesc;

            // 更新首页"消息"列表中的显示
            AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
            if (ap != nil) {
                [ap updateAlarmTitle:AMT_friendChatMessage dataId:safeSelf.friendInfo.user_uid newTitle:[safeSelf.friendInfo getNickNameWithRemark] needUpdateSqlite:YES];
            }
            
            // 通知ui界面进行刷新
            [NotificationCenterFactory friendRemarkChanged_POST:safeSelf.friendInfo];

            [APP showUserDefineToast_OK:@"更新成功"];
            [safeSelf doBack:YES];
        } else {
            [BasicTool showAlertWarn:@"更新失败，可能是网络原因导致，您可稍后重试！" parent:safeSelf];
        }
            
    } hudParentView:self.view];
}


#pragma mark - 其它UI处理方法

- (BOOL)contentHasChanged
{
    if (self.friendInfo == nil)
        return NO;
    
    NSString *remark = [BasicTool trim:self.editRemark.text];
    NSString *moreDesc = [BasicTool trim:self.editMoreDesc.text];
    
    NSString *oldRemark = self.friendInfo.friendRemark;
    NSString *oldMoreDesc = self.friendInfo.friendMoreDesc;
    
    BOOL remarkChanged = (oldRemark != nil && ![oldRemark isEqualToString:remark]) || (oldRemark == nil && ![BasicTool isStringEmpty:remark]);
    BOOL moreDescChanged = (oldMoreDesc != nil && ![oldMoreDesc isEqualToString:moreDesc]) || (oldMoreDesc == nil && ![BasicTool isStringEmpty:moreDesc]);
    
    return remarkChanged || moreDescChanged;
}

- (void)_setOkButtonEnable:(BOOL)enabled
{
    UIButton *done = self.rbRemarkDoneChromeButton;
    if (done != nil) {
        done.enabled = enabled;
        done.alpha = enabled ? 1.f : 0.5f;
    }
}

- (void)setOkButtonForChanged
{
    [self _setOkButtonEnable:[self contentHasChanged]];
}

- (void)doBack:(BOOL)animated
{
    [self.navigationController popViewControllerAnimated:animated];
}

@end
