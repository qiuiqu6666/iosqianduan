//telegram @wz662
//
//  CommonViewController.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/9.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CommonViewController : UIViewController

// 获取可重用的table cell
- (id)tableCell:(UITableView *)tableView withIdenfity:(NSString *)idenfity xibName:(NSString *)xibName c:(Class)c;

// 从当前界面退出
- (void)doBack:(BOOL)animated;

// 统一的错误信息提示
- (void)promtAndFinish:(NSString *)promtMsg;

// 隐藏导航栏
-(void)hideNavigation;

// 显示导航栏
-(void)showNavigation;

/**
 * 刷新当前界面所有控件的字体大小（根据全局字体设置）
 * 递归遍历所有子视图，更新UILabel、UIButton、UITextField、UITextView的字体
 */
- (void)refreshAllFonts;

/// 递归刷新指定视图及其子视图的字体；子类可重写以跳过部分子树（例如 UITableView 内的会话列表）。
- (void)refreshFontsForView:(UIView *)view;

@end

