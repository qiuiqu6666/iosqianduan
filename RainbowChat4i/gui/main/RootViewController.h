//telegram @wz662
//
//  RootViewController.h
//  RainbowChat4i
//
//  Created by JackJiang on 2025/8/14.
//  Copyright © 2025 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CommonViewController.h"

@interface RootViewController : CommonViewController

/// iOS 26+ 主 Tab FabBar 嵌在根页底部时，为列表/内容预留的额外底部 safe area（由 MainTabsViewController 维护）
@property (nonatomic, assign) CGFloat rb_mainTabFabBottomInset;

- (void)initGUI;

// 点击标题导航栏右边"搜索"按钮的事件处理（支持 UIBarButtonItem / 自定义顶栏内 UIButton）
- (void)doSearch:(id)sender;

// 点击标题导航栏右边"+"按钮的事件处理（支持 UIBarButtonItem / 自定义顶栏内 UIView）
- (void)doMores:(id)sender;

/// iOS 26+ 导航栏「+」系统菜单（子类如群组页复用）
- (UIMenu *)createMoresMenu_ios26 API_AVAILABLE(ios(13.0));

- (void)gotoAddFriends;
- (void)gotoCreateGroup;
- (void)gotoScan;

// 创建搜索框 Header View（用于设置到 tableView.tableHeaderView）
- (UIView *)createSearchBarHeader;

@end
