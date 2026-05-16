//telegram @wz662
//
//  SearchViewController.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/17.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 * 搜索功能主界面（支持的搜索内容由决定 searchableContens 参数指定）。
 *
 * @author JackJiang
 * @since 6.0
 */

#import <UIKit/UIKit.h>
#import "CommonViewController.h"

@class SearchableContent;


@interface SearchViewController : CommonViewController<UITableViewDataSource,UITableViewDelegate>

/** 自定义searchbar的ui布局 */
@property (weak, nonatomic) IBOutlet UIView *searchBarLayout;
/** 搜索结果显示列表 */
@property (weak, nonatomic) IBOutlet UITableView *tableView;

/** 没有搜索到数据时要显示的ui布局 */
@property (weak, nonatomic) IBOutlet UIView *noDataLinearLayout;
/** 搜索开始前的提示信息显示ui布局 */
@property (weak, nonatomic) IBOutlet UIView *hintLinearLayout;
/** 搜索开始前的提示信息组件 */
@property (weak, nonatomic) IBOutlet UILabel *hintTextView;

/**
 init方法。
 
 @param searchableContens 支持的可搜索内容
 @param keyword 初始搜索关键（打开界面后自动搜索此关键字的结果1次），为nil表示没有初始关键字
 @param showAllResult YES表示显示所有结果，NO表示只显示限定数据的结果（多余部分用“查看更多”这样的cell由用户点进去进一步查看）
 */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil supportedSearchableContens:(NSArray<SearchableContent *> *)searchableContens keyword:(NSString *)keyword showAllResult:(BOOL)showAllResult;

/**
 隐藏输入法。
 */
- (void)hideInputMethod;

@end

