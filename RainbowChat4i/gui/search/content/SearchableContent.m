//telegram @wz662
//
//  SearchableContent.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/22.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "SearchableContent.h"


/** 可搜索内容常量定义：好友*/
int const SEARCH_CONTENT_TYPE_FRIEND      = 1;
/** 可搜索内容常量定义：群聊 */
int const SEARCH_CONTENT_TYPE_GROUP       = 2;
/** 可搜索内容常量定义：聊天记录（数据不聚合显示，有多少条就显示多少条）*/
int const SEARCH_CONTENT_TYPE_MSG_DETAIL  = 3;
/** 可搜索内容常量定义：聊天记录（数据将聚合显示） */
int const SEARCH_CONTENT_TYPE_MSG_SUMMARY = 4;

/** 在列表中本搜索内容对应的默认最多显示item条数 */
int const SEARCH_RESULT_LIST_ITEM_DEFAULT_SHOW_COUNT = 3;


@implementation SearchableContent

- (id)init {
    if(self = [super init]) {
        // 属性初始化
        self.showAllResult = NO;
    }
    return self;
}

// 用于SearchViewController中的tableView:cellForRowAtIndexPath:方法调用，从而实现不同搜索内容的表格cell内容显示。
- (UITableViewCell *) onTableViewCell:(SearchViewController *)vc contentDTO:(id)dto{
    // 本方法请在子类中实现，父类中默认什么也不做！
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
    return nil;
}

// 点击事件处理。
- (void)doClick:(SearchViewController *)vc cell:(UITableViewCell *)cell contentDTO:(id)dto {
//  WidgetUtils.hideInputMethod(fragment.getActivity(), view);
    [vc hideInputMethod];
    [self doClickImpl:vc cell:cell contentDTO:dto];
}

// 点击"查看更多"事件处理。
- (void)doClickMore:(SearchViewController *)vc {
    //   WidgetUtils.hideInputMethod(fragment.getActivity(), view);
    [vc hideInputMethod];
    [self doClickMoreImpl:vc];
}

// 点击事件真正的实施方法。子类可重写本方法实现自已的逻辑。
- (void)doClickImpl:(SearchViewController *)vc cell:(UITableViewCell *)cell contentDTO:(id)dto {
    // 本方法请在子类中实现，父类中默认什么也不做！
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

// 点击"查看更多"事件真正的实施方法。子类可重写本方法实现自已的逻辑。
- (void)doClickMoreImpl:(SearchViewController *)vc {
    // 本方法请在子类中实现，父类中默认什么也不做！
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

// 开始搜索。
- (NSMutableArray *)doSearch:(NSString *)keyword searchAll:(BOOL)searchAll db:(FMDatabase *)db {
    self.currentKeyword = keyword;
    return [self doSearchImpl:keyword searchAll:searchAll db:db];
}

// 搜索实施方法。
- (NSMutableArray *)doSearchImpl:(NSString *)keyword searchAll:(BOOL)searchAll db:(FMDatabase *)db  {
    // 本方法请在子类中实现，父类中默认什么也不做！
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
    return nil;
}

- (BOOL)rb_messageSearchUsesServer
{
    return NO;
}

- (void)rb_doServerMessageSearch:(NSString *)keyword searchAll:(BOOL)searchAll complete:(void (^)(NSMutableArray * _Nullable results))complete
{
    if (complete) {
        complete(nil);
    }
}

// 返回本搜索内容对应的内容类型常量
- (int)getContentType {
    // 本方法请在子类中实现，父类中默认什么也不做！
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
    return -1;
}

// 返回对应搜索内容的描述，可用于UITableView中的section标题上
- (NSString *)getContentDescription {
    // 本方法请在子类中实现，父类中默认什么也不做！
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
    return nil;
}

@end
