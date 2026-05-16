//telegram @wz662
//
//  RootViewController.m
//  RainbowChat4i
//
//  Created by JackJiang on 2025/8/14.
//  Copyright © 2025 JackJiang. All rights reserved.
//

#import "RootViewController.h"
#import "UIBarButtonItem+XYMenu.h"
#import "QRCodeScheme.h"
#import "ViewControllerFactory.h"
#import "QRCodeScheme.h"
#import "SearchViewController.h"
#import "FriendsContent.h"
#import "GroupsContent.h"
#import "MsgDetailContent.h"
#import "MsgSummaryContent.h"
#import "BasicTool.h"

@implementation RootViewController

- (void)initGUI
{
    UIBarButtonItem *addButton = nil;
    // ios 26上“+”弹出的是系统自带的菜单（液态玻璃效果较好）
    if (@available(iOS 26, *)) {
        addButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"alarms_add_friends2"]
                                                                         menu:[self createMoresMenu_ios26]];
    }
    // 老版本上“+”弹出的是普通自定义菜单
    else
    {
        addButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"alarms_add_friends2"]
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(doMores:)];
    }

    UIBarButtonItem *searchButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"alarms_search"]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(doSearch:)];
    // 标题栏右边的“+”按钮、搜索按钮
    self.navigationItem.rightBarButtonItems = @[addButton, searchButton];
}

// 点击标题导航栏右边“+”按钮的事件处理
- (void)doMores:(id)sender
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;

    NSArray *imageArr = @[@"main_alarms_floatmenu_adduser", @"main_alarms_floatmenu_addgroup", @"main_alarms_floatmenu_scan"];
    NSArray *titleArr = @[@"添加好友", @"创建群聊", @"扫一扫"];

    void (^onPick)(NSInteger) = ^(NSInteger index) {
        if (index == 1) {
            [safeSelf gotoAddFriends];
        } else if (index == 2) {
            [safeSelf gotoCreateGroup];
        } else if (index == 3) {
            [safeSelf gotoScan];
        }
    };

    if ([sender isKindOfClass:[UIView class]]) {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:(UIView *)sender];
        [item xy_showMenuWithImages:imageArr titles:titleArr menuType:XYMenuRightNavBar currentNavVC:self.navigationController withItemClickIndex:^(NSInteger index) {
            onPick(index);
        }];
        return;
    }
    if ([sender isKindOfClass:[UIBarButtonItem class]]) {
        [(UIBarButtonItem *)sender xy_showMenuWithImages:imageArr titles:titleArr menuType:XYMenuRightNavBar currentNavVC:self.navigationController withItemClickIndex:^(NSInteger index) {
            onPick(index);
        }];
        return;
    }
}

// 点击标题导航栏右边“搜索”按钮的事件处理
- (void)doSearch:(id)sender
{
    (void)sender;
    [ViewControllerFactory goSearchViewController:self.navigationController supportedSearchableContens:@[[[FriendsContent alloc] init], [[GroupsContent alloc] init], [[MsgSummaryContent alloc] init]] keyword:nil showAllResult:NO];
}

- (void)gotoAddFriends
{
    [ViewControllerFactory goFindFriendViewController:self.navigationController];
}

- (void)gotoCreateGroup
{
    [ViewControllerFactory goGroupMemberViewController:self.navigationController usedFor:USED_FOR_CREATE_GROUP gid:nil isGroupOwner:YES defaultSelectedUid:nil];
}

- (void)gotoScan
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    // 进入“扫一扫”界面
    [QRCodeScheme gotoQrCodeScan:self.navigationController scanComplete:^(NSString *qrResult) {
        DLogDebug(@"%@", [NSString stringWithFormat:@"2维码扫描的结果是：%@", qrResult]);
        // 开始解析2维码内容并进入相应的处理逻辑
        [QRCodeScheme processQRCodeScanResult:qrResult nav:safeSelf.navigationController view:safeSelf.view vc:safeSelf];
    }];
}

// 创建搜索框 Header View（用于设置到 tableView.tableHeaderView）
- (UIView *)createSearchBarHeader
{
    CGFloat headerHeight = 52;
    CGFloat hPadding = 16;
    CGFloat vPadding = 6;
    
    // 外层容器
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, headerHeight)];
    headerView.backgroundColor = [UIColor clearColor];
    
    // 内层搜索框背景
    UIView *searchBg = [[UIView alloc] init];
    searchBg.backgroundColor = HexColor(0xF5F7FA);
    searchBg.layer.cornerRadius = (headerHeight - vPadding * 2) / 2.0;
    searchBg.translatesAutoresizingMaskIntoConstraints = NO;
    searchBg.userInteractionEnabled = NO;
    [headerView addSubview:searchBg];
    
    // 搜索图标
    UIImageView *searchIcon = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
        searchIcon.image = [[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    searchIcon.tintColor = HexColor(0x979CA6);
    searchIcon.contentMode = UIViewContentModeScaleAspectFit;
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    searchIcon.userInteractionEnabled = NO;
    [headerView addSubview:searchIcon];
    
    // 占位文字
    UILabel *placeholderLabel = [[UILabel alloc] init];
    placeholderLabel.text = @"搜索";
    placeholderLabel.textColor = HexColor(0x979CA6);
    placeholderLabel.font = [BasicTool getSystemFontOfSize:15];
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderLabel.userInteractionEnabled = NO;
    [headerView addSubview:placeholderLabel];
    
    // 约束：搜索框背景
    [NSLayoutConstraint activateConstraints:@[
        [searchBg.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor constant:hPadding],
        [searchBg.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor constant:-hPadding],
        [searchBg.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:vPadding],
        [searchBg.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-vPadding],
    ]];
    
    // 约束：搜索图标
    [NSLayoutConstraint activateConstraints:@[
        [searchIcon.leadingAnchor constraintEqualToAnchor:searchBg.leadingAnchor constant:12],
        [searchIcon.centerYAnchor constraintEqualToAnchor:searchBg.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:18],
        [searchIcon.heightAnchor constraintEqualToConstant:18],
    ]];
    
    // 约束：占位文字
    [NSLayoutConstraint activateConstraints:@[
        [placeholderLabel.leadingAnchor constraintEqualToAnchor:searchIcon.trailingAnchor constant:6],
        [placeholderLabel.centerYAnchor constraintEqualToAnchor:searchBg.centerYAnchor],
    ]];
    
    // 点击手势
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(searchBarTapped:)];
    [headerView addGestureRecognizer:tap];
    
    return headerView;
}

// 搜索框点击事件处理
- (void)searchBarTapped:(UITapGestureRecognizer *)sender
{
    [self doSearch:nil];
}

// 创建标题导航栏右边"+"按钮的菜单 (用于iOS 26)
- (UIMenu *)createMoresMenu_ios26 API_AVAILABLE(ios(13.0))
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    if (@available(iOS 14, *)) {
        UIAction *action1 = [UIAction actionWithTitle:@"添加好友" image:[UIImage imageNamed:@"main_alarms_floatmenu_adduser_ios26"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [safeSelf gotoAddFriends];
        }];
        
        UIAction *action2 = [UIAction actionWithTitle:@"创建群聊" image:[UIImage imageNamed:@"main_alarms_floatmenu_addgroup_ios26"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [safeSelf gotoCreateGroup];
        }];
        
        UIAction *action3 = [UIAction actionWithTitle:@"扫一扫" image:[UIImage imageNamed:@"main_alarms_floatmenu_scan_ios26"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [safeSelf gotoScan];
        }];
        
        UIMenu *menu = [UIMenu menuWithChildren:@[action1, action2, action3]];
        
        return menu;
    }
    
    return nil;
}

@end
