//telegram @wz662
//
//  SearchableContent.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/22.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 * 可搜索内容描述对象实现类。
 * 继承此类可实现不同搜索内容的表格单元显示逻辑、点击事件处理逻辑等。
 *
 * @author Jack Jiang
 * @since 6.0
 */

#import <Foundation/Foundation.h>
#import "IMClientManager.h"
#import "FileDownloadHelper.h"
#import "SearchViewController.h"

@class SearchViewController;


/** 常量定义：好友可搜索内容 */
extern int const SEARCH_CONTENT_TYPE_FRIEND;
/** 常量定义：群聊可搜索内容 */
extern int const SEARCH_CONTENT_TYPE_GROUP;
/** 常量定义：聊天记录可搜索内容（数据不聚合显示，有多少条就显示多少条）*/
extern int const SEARCH_CONTENT_TYPE_MSG_DETAIL;
/** 常量定义：聊天记录可搜索内容（数据将聚合显示） */
extern int const SEARCH_CONTENT_TYPE_MSG_SUMMARY;

/** 在列表中本搜索内容对应的默认最多显示item条数 */
extern int const SEARCH_RESULT_LIST_ITEM_DEFAULT_SHOW_COUNT;


@interface SearchableContent : NSObject

/** 当前搜索的关键词（每次搜索时保存此次搜索的关键词以备后绪点击事件等逻辑中使用） */
@property (nonatomic, retain) NSString *currentKeyword ;
/**
 * 是否显示所有搜索结果（YES表示显示所有结果，NO表示只显示限定数据的结果
 * （见 {@link #RESULT_LIST_ITEM_DEFAULT_SHOW_COUNT}），，多余部分用“查看更多”这样的cell由用户点进去进一步查看。
 */
@property (nonatomic, assign, getter=isShowAllResult) BOOL showAllResult;


/**
 * TODO: 默认是空方法，请在子类中实现之！
 * 用于SearchViewController中的tableView:cellForRowAtIndexPath:方法调用，从而实现不同搜索内容的表格cell内容显示。
 *
 * @param vc 对应的搜索主界面对象应用
 * @param dto 表格单元对应的数据对象
 * @return 返回对应的表格ceell对象
 */
- (UITableViewCell *) onTableViewCell:(SearchViewController *)vc contentDTO:(id)dto;

/**
 * 点击事件处理。
 *
 * @param vc 对应的搜索主界面对象应用
 * @param cell   表格单元对象引用
 * @param dto 表格单元对应的数据对象
 * @see {@link #doClickImpl: }
 */
- (void)doClick:(SearchViewController *)vc cell:(UITableViewCell *)cell contentDTO:(id)dto;

/**
 * 点击"查看更多"事件处理。
 *
 * @param vc 对应的搜索主界面对象应用
 * @see {@link #doClickMoreImpl: }
 */
- (void)doClickMore:(SearchViewController *)vc;

/**
 * TODO: 默认是空方法，请在子类中实现之！
 * 点击事件真正的实施方法。子类可重写本方法实现自已的逻辑。
 *
 * @param vc 对应的搜索主界面对象应用
 * @param cell   表格单元对象引用
 * @param dto 表格单元对应的数据对象
 */
- (void)doClickImpl:(SearchViewController *)vc cell:(UITableViewCell *)cell contentDTO:(id)dto;

/**
 * TODO: 默认是空方法，请在子类中实现之！
 * 点击"查看更多"事件真正的实施方法。子类可重写本方法实现自已的逻辑。
 *
 * @param vc 对应的搜索主界面对象应用
 */
- (void)doClickMoreImpl:(SearchViewController *)vc;

/**
 * 开始搜索。
 *
 * @param keyword 要搜索的关键词
 * @param searchAll YES表示显示所有结果，NO表示只显示限定数据的结果（多余部分用“查看更多”这样的cell由用户点进去进一步查看）
 * @return 返回的搜索结果集 (List<R>)
 * @see #doSearchImpl(String)
 */
- (NSMutableArray *)doSearch:(NSString *)keyword searchAll:(BOOL)searchAll db:(FMDatabase *)db;

/**
 * TODO: 默认是空方法，请在子类中实现之！
 * 搜索实施方法。
 *
 * @param keyword 要搜索的关键词
 * @param searchAll YES表示显示所有结果，NO表示只显示限定数据的结果（多余部分用“查看更多”这样的cell由用户点进去进一步查看）
 * @return 返回的搜索结果集 (List<R>)
 */
- (NSMutableArray *)doSearchImpl:(NSString *)keyword searchAll:(BOOL)searchAll db:(FMDatabase *)db;

/// YES：聊天记录类搜索走服务端 1008-26-41/42，不在 SQLite 中执行 doSearchImpl。
- (BOOL)rb_messageSearchUsesServer;

/// 服务端搜索完成回调（主线程约定由调用方 `SearchViewController` 保证在回调内 dispatch 到主线程后再更新 UI）。
- (void)rb_doServerMessageSearch:(NSString *)keyword searchAll:(BOOL)searchAll complete:(void (^)(NSMutableArray * _Nullable results))complete;

/**
 * TODO: 默认是空方法，请在子类中实现之！
 * 返回本搜索内容显示在结果列表界面中时的对应的搜索内容类型常量。
 *
 * @return 返回搜索内容类型常量
 */
- (int)getContentType;

/**
 * TODO: 默认是空方法，请在子类中实现之！
 * 返回对应搜索内容的文字描述。
 *
 * @return 对应搜索内容的文字描述
 */
- (NSString *)getContentDescription;

@end
