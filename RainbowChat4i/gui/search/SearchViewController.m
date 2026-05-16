//telegram @wz662
//
//  SearchViewController.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/17.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "SearchViewController.h"
#import "BasicTool.h"
#import "RBSearchBar.h"
#import "Masonry.h"
#import "TableViewCellData.h"
#import "SearchCompleteData.h"
#import "SeeMoreTableViewCell.h"


@interface SearchViewController () <RBSearchBarDelegate>

/** 支持的搜索内容（每个SearchableContent对象表示一种支持的搜索内容） */
@property (nonatomic, strong) NSArray<SearchableContent *> *supportedSearchableContens;
/** 调用者传进来的：搜索关键字 */
@property (nonatomic, retain) NSString *keywordFromInit;
/** 调用者传进来的：是否显示全部结果（YES表显示全部，NO表只显示有限数量，其它需点击"查看更多"） */
@property (nonatomic, assign) BOOL showAllResultFromInit;

/** 搜索结果数据字典（该字典将按搜索内容类型进行聚合，特别注意数据是这样组织的：key=可搜索内容类型常量、value=该搜索内容对应的数据结果）*/
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSArray<TableViewCellData *> *> *resultDatas;

/** 搜索输入控件 */
@property (nonatomic, retain) RBSearchBar *rbSearchBar;

/** 当前正在搜索中的关键字（仅用于防止重复提交搜索请求时作判断之用，别无它用） */
@property (nonatomic, retain) NSString *keywordForSearching;

@end


@implementation SearchViewController

#pragma mark - 界面初始化相关方法

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil supportedSearchableContens:(NSArray<SearchableContent *> *)searchableContens keyword:(NSString *)keyword showAllResult:(BOOL)showAllResult {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.supportedSearchableContens = searchableContens;
        self.keywordFromInit = keyword;
        self.showAllResultFromInit = showAllResult;
        self.resultDatas = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initGUI];
    [self initActions];
    [self initDatas];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 隐藏导导航栏
    [self hideNavigation];
    // 隐藏导航栏后系统会自动禁用右滑返回手势，需要手动重新启用
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 取消隐藏导航栏
    [self showNavigation];
}

// ui初始化工作请放本方法中
- (void)initGUI {
    // 表格基本设置
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    // 去掉空白行的显示
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    // 让表格行分隔线从左边指定像素处绘制
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 67, 0, 0);
    // 表格的背景色
    self.tableView.backgroundColor = UI_DEFAULT_BG;
    // 表格分隔线的颜色
    self.tableView.separatorColor = [UIColor whiteColor];//UI_DEFAULT_TABLE_VIEW_DIVIDER_GRAY;
    if (@available(iOS 15, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
        
    // 初始化搜索栏上的UI及布局
    self.rbSearchBar = [self loadRBSearchBar];
    self.rbSearchBar.delegate = self;
    [self.searchBarLayout addSubview:self.rbSearchBar];
    // 为搜索栏控件添加布局约束
    [self.rbSearchBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.searchBarLayout);
        make.bottom.equalTo(self.searchBarLayout);
        make.left.equalTo(self.searchBarLayout);
        make.right.equalTo(self.searchBarLayout);
    }];
    
    // 实现点击信息提示组件空白处取消键盘显示
    self.hintLinearLayout.userInteractionEnabled = YES;
    self.noDataLinearLayout.userInteractionEnabled = YES;
    [self.hintLinearLayout addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)]];
    [self.noDataLinearLayout addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fingerTapped:)]];

    // 实现信息提示组件下滑手势隐藏输入键盘
    UISwipeGestureRecognizer *recognizer1 = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(fingerSwipeFrom:)];
    [recognizer1 setDirection:(UISwipeGestureRecognizerDirectionDown)];
    UISwipeGestureRecognizer *recognizer2 = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(fingerSwipeFrom:)];
    [recognizer2 setDirection:(UISwipeGestureRecognizerDirectionDown)];
    [[self hintLinearLayout] addGestureRecognizer:recognizer1];
    [[self noDataLinearLayout] addGestureRecognizer:recognizer2];
}

// 加载默认的聊天界面下方输入框工具栏的View内容（之所以说是默认，因为JSQ的高可扩展性允许子类自已覆盖并实现自已的实现）
- (RBSearchBar *)loadRBSearchBar {
    // 加载xib
    NSArray *nibViews = [[NSBundle bundleForClass:[RBSearchBar class]] loadNibNamed:NSStringFromClass([RBSearchBar class]) owner:nil options:nil];
    return nibViews.firstObject;
}

// 如果按钮事件等事件需要添加，请在此方法中加入
- (void)initActions {
}

// 初始化数据
- (void)initDatas {
    // 可搜索内容描述对象集合不为空时
    if(self.supportedSearchableContens != nil && [self.supportedSearchableContens count] > 0){
        NSMutableString *hintContent = [NSMutableString string];
        
        // 遍历可搜索内容描述对象集合
        for(int i =0; i < [self.supportedSearchableContens count]; i++){
            SearchableContent *c = [self.supportedSearchableContens objectAtIndex:i];
            
            // 根据传进来的showAllResultFromIntent字段，设置各可搜索内容描述对象的对应字段
            c.showAllResult = self.showAllResultFromInit;
            
            // 组装可搜索内容的catlog
            [hintContent appendString:[c getContentDescription]];
            // 如果是最后一个就不需要加顿号分隔了
            if(i != [self.supportedSearchableContens count] - 1){
                [hintContent appendString:@"、"];
            }
        }
        
        // 更新搜索结果列表中没有开始搜索前的提示信息
        [self updateHint:[NSString stringWithFormat:@"支持搜索%@", hintContent]];
    }
    
    // 如果存在初始关键字，就设置上去（并自动触发搜索）
    if (![BasicTool isStringEmpty:self.keywordFromInit]) {
        // 设置默认的搜索关键词并触发默认搜索
        [self.rbSearchBar setKeyword:self.keywordFromInit];
        // 让输入框失去焦点，不然它自动弹出输入法，很影响体验
        [self.rbSearchBar.viewEdit resignFirstResponder];
    }
}


#pragma mark - UIScrollViewDelegate

// 表格滑动时结束输入状态（将同时隐藏输入法）
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    // 隐藏输入法
    [self hideInputMethod];
}


#pragma mark - Table view delegate

// 每个section中有多少个cell
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // 取出section对应的数组
    NSArray<TableViewCellData *> *resultDataOfSection = [self getResultDataOfSection:section];
    return resultDataOfSection != nil ? [resultDataOfSection count] : 0;
}

// 表格中共有多少个section
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // 取出最终搜索结果字典中的所有key（这些key就是对应搜索结果的SearchableContent对象的content type常量的字符串形式）
    NSArray<NSString *> *keys = [self resultDataKeys];
    return keys != nil ? [keys count] : 0;
}

// section标题的高度
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40;//30;
}

// section标题的显示内容
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title;
   
    // 取出该section对应总数据字典中的key
    NSString *key = [self getKeyOfSection:section];
    if(key != nil) {
        // 该section对应的搜索内容描述对象
        SearchableContent *searchableContent = [self getSearchableContentByKey:key];
        if(searchableContent != nil)
            title = [searchableContent getContentDescription];
    }
    
    if (title == nil || title.length == 0) {
        return nil;
    }
    
    // 总高度
    float height = 40;
    // 文本标签高度
    float labelHeight = 32;
    // 右边的空白
    float leftInset = 16;
    // 上边的空白
    float topInset = 8;
    
    // section标题栏父布局
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, height)];
    view.backgroundColor = HexColor(0xf5f7fa);
    
    // section标题栏文本组件白色背景
    UIView *labelBg = [[UIView alloc] initWithFrame:CGRectMake(0, topInset, self.view.frame.size.width, labelHeight)];
    labelBg.backgroundColor = [UIColor whiteColor];;
    [view addSubview:labelBg];
    
    // section标题栏文本组件（用于显示首字母的）
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(leftInset,topInset, self.view.frame.size.width, labelHeight)];
    label.font = [BasicTool getSystemFontOfSize:13.0f];
    label.textColor = HexColor(0x979ca6);
    label.textAlignment = NSTextAlignmentLeft;
    label.text = [NSString stringWithFormat:@"%@", title];
    [view addSubview:label];
    
    // 底部分隔线
    UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(leftInset, height-1, self.view.frame.size.width, 0.5f)];
    lineView.backgroundColor = UI_DEFAULT_TABLE_VIEW_DIVIDER_GRAY;
    [view addSubview:lineView];
    
    return view;
}

// 数据cell的高度
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 取出section对应的数组
    NSArray<TableViewCellData *> *resultDataOfSection = [self getResultDataOfSection:indexPath.section];
    if(resultDataOfSection != nil && indexPath.row >=0 && indexPath.row < [resultDataOfSection count]){
        // 表格单元数据对象
        TableViewCellData *cellDto = [resultDataOfSection objectAtIndex:indexPath.row];
        // 如果是“查看更多”cell
        if(cellDto != nil && [cellDto isSeeMoreCell]) {
            return 45;
        }
    }
    
    return 60;
}

// 表格cell的ui显示相关设置
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *theCell = nil;
    
    // 取出该section对应总数据字典中的key（这个key对应的就是SearchContent对象的content type）
    NSString *key = [self getKeyOfSection:indexPath.section];
    // 取出section对应的数组
    NSArray<TableViewCellData *> *resultDataOfSection = [self getResultDataOfSection:indexPath.section];
    
    if(resultDataOfSection != nil && key != nil){
        // 该section对应的搜索内容描述对象
        SearchableContent *searchableContent = [self getSearchableContentByKey:key];
        // 表格单元数据对象
        TableViewCellData *cellDto = [resultDataOfSection objectAtIndex:indexPath.row];
                
        // 如果是“查看更多”cell
        if(cellDto.seeMoreCell) {
            theCell = [self tableCell:tableView withIdenfity:@"seeMoreCell" xibName:@"SeeMoreTableViewCell" c:[SeeMoreTableViewCell class]];
            if(theCell != nil){
                SeeMoreTableViewCell *frtCell = (SeeMoreTableViewCell *)theCell;
                [frtCell baseSetup];
                frtCell.viewSeeMore.text = [NSString stringWithFormat:@"查看更多%@", (searchableContent != nil ? [searchableContent getContentDescription] : @"")];
            }
        }
        // 否则是正常数据cell
        else {
            if(searchableContent != nil) {
                theCell = [searchableContent onTableViewCell:self contentDTO:cellDto.contentData];
            }
        }
    }

    return theCell;
}


#pragma mark - Table view delegate

// 点击表格行时要调用的方法
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 取出该section对应总据字母中的key（这个key对应的就是SearchContent对象的content type）
    NSString *key = [self getKeyOfSection:indexPath.section];
    // 取出section对应的数组
    NSArray<TableViewCellData *> *resultDataOfSection = [self getResultDataOfSection:indexPath.section];
    if(resultDataOfSection != nil && key != nil){
        // 取出数组中对应行索引的对象
        TableViewCellData *cellDto = [resultDataOfSection objectAtIndex:indexPath.row];
        // 如果是“查看更多”行
        if(cellDto.seeMoreCell) {
            SearchableContent *cParent = [self getSearchableContentByKey:key];
            if(cParent != nil)
                [cParent doClickMore:self];
        } else {
            SearchableContent *c = [self getSearchableContentByKey:key];
            if(c != nil) {
                [c doClick:self cell:nil contentDTO:cellDto.contentData];
            }
        }
    } else {
        DLogWarn(@"resultDataOfSection为nil（%@） 或 key为nil（%@）!", resultDataOfSection, key);
    }
    
    // 取消选中状态（没有此行代码，从别的界面回来后，该cell将仍然显示选中时的背景色，很难看）
    [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
}


#pragma mark - 用于tableView中读取和解析搜索结果数据的相关方法

// 返回指定section对应的于总数据集合中的key（这个key对应的就是SearchContent对象的content type）
- (NSString *)getKeyOfSection:(NSInteger)section {
    NSArray<NSString *> *keys = [self resultDataKeys];
    if(keys != nil && section >= 0 && section < [keys count]) {
        // 表格中的section是按总数据集合中的key排序的，所以section顺序变是key在集合中的顺序
        NSString *key = (NSString *)[keys objectAtIndex:section];
        return key;
    } else {
        DLogWarn(@"无效的section=%ld !", section);
    }
    return nil;
}

// 获得对应section的数据集合
- (NSArray<TableViewCellData *> *)getResultDataOfSection:(NSInteger)section {
    // 表格中的section是按总数据集合中的key排序的，所以section顺序变是key在集合中的顺序
    NSString *key = [self getKeyOfSection:section];
    if(key != nil){
        return [self.resultDatas objectForKey:key];
    }
    return nil;
}

// 获得指定类型的搜索内容描述对象（注：本界面中数据字母中的key对应的就是搜索内容描述对象的content type）
- (SearchableContent *)getSearchableContentByKey:(NSString *)key {
    if(self.supportedSearchableContens != nil && [self.supportedSearchableContens count] > 0 && key != nil) {
        for(SearchableContent *c in self.supportedSearchableContens) {
            if(c != nil && [key isEqualToString:[self getContentTypeStr:[c getContentType]]]) {
                return c;
            }
        }
    }
    return nil;
}

// 搜索内容类型整数的字符串表示（因为放到字典对象中作为key时，只用用字符串啦）
- (NSString *)getContentTypeStr:(int)cellType {
    return [NSString stringWithFormat:@"%d", cellType];
}

// 取出最终搜索结果字典中的所有key（这些key就是对应搜索结果的SearchableContent对象的content type常量的字符串形式）
- (NSArray<NSString *> *)resultDataKeys {
    if(self.resultDatas != nil) {
        NSArray<NSString *> *keys = [[self.resultDatas allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 compare:obj2 options:NSNumericSearch];
        }];
        return keys;
    } else {
        DLogWarn(@"self.resultDatas是nil！");
    }
    return nil;
}


#pragma mark - 开始搜索、搜索完成、处理搜索数据相关方法

// 开始搜索（聊天记录 MsgDetail/MsgSummary 走服务端 1008-26-41/42；好友/群等仍走 SQLite）
- (void)doSearch:(NSString *)k {
    [self clearResult];
    self.hintLinearLayout.hidden = YES;
    
    if ([BasicTool isStringEmpty:k]) {
        DLogWarn(@"无效的搜索关键字，k=null !");
        return;
    }
    
    if (self.keywordForSearching != nil && [self.keywordForSearching isEqualToString:k]) {
        DLogWarn(@"重复的关键字搜索，本次搜索任务被忽略（k=%@） !", k);
        return;
    }
    
    self.keywordForSearching = k;
    __weak typeof(self) safeSelf = self;
    
    NSMutableArray<SearchableContent *> *serverContents = [NSMutableArray array];
    NSMutableArray<SearchableContent *> *dbContents = [NSMutableArray array];
    for (SearchableContent *c in safeSelf.supportedSearchableContens) {
        if ([c rb_messageSearchUsesServer]) {
            [serverContents addObject:c];
        } else {
            [dbContents addObject:c];
        }
    }
    
    dispatch_group_t grp = dispatch_group_create();
    __block BOOL matchedAny = NO;
    
    for (SearchableContent *c in serverContents) {
        dispatch_group_enter(grp);
        [c rb_doServerMessageSearch:k searchAll:c.isShowAllResult complete:^(NSMutableArray * _Nullable r) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([k isEqualToString:safeSelf.keywordForSearching] && r != nil && [r count] > 0) {
                    matchedAny = YES;
                    SearchCompleteData *searchResult = [[SearchCompleteData alloc] init];
                    searchResult.searchableContent = c;
                    searchResult.searchedCompleteDatas = r;
                    [safeSelf onSearchComplete:searchResult];
                }
                dispatch_group_leave(grp);
            });
        }];
    }
    
    if (dbContents.count > 0) {
        dispatch_group_enter(grp);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
                NSMutableArray<NSDictionary *> *dbHits = [NSMutableArray array];
                @try {
                    for (SearchableContent *c in dbContents) {
                        NSMutableArray *r = [c doSearch:k searchAll:c.isShowAllResult db:db];
                        if ([k isEqualToString:safeSelf.keywordForSearching] && r != nil && [r count] > 0) {
                            [dbHits addObject:@{ @"c": c, @"r": r }];
                        }
                    }
                } @finally {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        for (NSDictionary *hit in dbHits) {
                            matchedAny = YES;
                            SearchCompleteData *searchResult = [[SearchCompleteData alloc] init];
                            searchResult.searchableContent = hit[@"c"];
                            searchResult.searchedCompleteDatas = hit[@"r"];
                            [safeSelf onSearchComplete:searchResult];
                        }
                        dispatch_group_leave(grp);
                    });
                }
            }];
        });
    }
    
    dispatch_group_notify(grp, dispatch_get_main_queue(), ^{
        if ([k isEqualToString:safeSelf.keywordForSearching] && !matchedAny) {
            [safeSelf onSearchComplete:nil];
        }
        safeSelf.keywordForSearching = nil;
    });
}

/**
 * 搜索完成后的结果回调。
 *
 * @param result 搜索结果数据封装对象
 */
- (void)onSearchComplete:(SearchCompleteData *)result {
    // 如果搜索结果是空的，就显示空数据ui提示布局
    if (result == nil || [result.searchedCompleteDatas count] <= 0) {
        self.tableView.hidden = YES;
        self.noDataLinearLayout.hidden = NO;
        return;
    } else {
        self.tableView.hidden = NO;
        self.noDataLinearLayout.hidden = YES;
    }

    // 将搜索结果设置到列表的adapter中，以便刷新列表ui的显示
    [self addSearchResult:result];
}

/**
 * 添加搜索结果到总的数据集合并并刷新ui显示。
 *
 * @param r 搜索结果数据封装对象
 */
- (void)addSearchResult:(SearchCompleteData *)r {
    
    if (r.searchedCompleteDatas == nil || [r.searchedCompleteDatas count] == 0) {
        DLogDebug(@"submitSearResult时，查询结果是空的，result.result=%@", r.searchedCompleteDatas);
        return;
    }
    
    // 搜索内容对应的类型常量定义
    int contentType = [r.searchableContent getContentType];
    
    NSMutableArray<TableViewCellData *> *results = [NSMutableArray array];
    
    // 只显示默认数量的item
    for (int i = 0; i < [r getSearchedCompleteDatas]
         && (r.searchableContent.isShowAllResult || i < SEARCH_RESULT_LIST_ITEM_DEFAULT_SHOW_COUNT); i++) {
        id data = [r.searchedCompleteDatas objectAtIndex:i];
        
        TableViewCellData *dto = [[TableViewCellData alloc] init];
        dto.contentData = data;
        
        [results addObject:dto];
    }
    
    // 如果只显示有限数量的结果
    if(!r.searchableContent.isShowAllResult) {
        // 超过默认显示条数则加一条"查看更多"item
        if ([r getSearchedCompleteDatas] > SEARCH_RESULT_LIST_ITEM_DEFAULT_SHOW_COUNT) {
            TableViewCellData *di = [[TableViewCellData alloc] init];;
            di.seeMoreCell = YES;
            [results addObject:di];
        }
    }

    // 加入到总的搜索结果字典数据中时，key=搜索内容类型常量、value=该搜索内容对应的搜索结果，
    // 一定要注意理解这个数据结构，因为接下来界面上的tableView数据显示时都是按这个逻辑去读取的
    [self.resultDatas setObject:results forKey:[NSString stringWithFormat:@"%d", contentType]];
    
    // 刷新列表ui显示
    [self.tableView reloadData];
}


#pragma mark - 其它方法

// 实现点击空白处取消键盘显示
-(void)fingerTapped:(UITapGestureRecognizer *)gestureRecognizer {
    // 隐藏输入法
    [self hideInputMethod];
}

// 下滑手势：下滑屏幕关闭输入键盘
-(void)fingerSwipeFrom:(UISwipeGestureRecognizer *)recognizer {
    if(recognizer.direction==UISwipeGestureRecognizerDirectionDown){
        DDLogDebug(@"swipe down");
        // 关闭输入键盘
        [self.rbSearchBar.viewEdit resignFirstResponder];
    }
}

// 隐藏输入法
- (void)hideInputMethod {
    // 隐藏输入法
    [self.rbSearchBar.viewEdit endEditing:YES];
    // 隐藏输入法
//  [self.viewEdit resignFirstResponder];
}

// 清空搜索结果
- (void)clearResult {
    // 清除列表ui数据
    if(self.resultDatas != nil) {
        [self.resultDatas removeAllObjects];
        [self.tableView reloadData];
    }
    
    // 显示默认的提示信息
    self.hintLinearLayout.hidden = NO;
    // 隐藏无数据时的提示ui
    self.noDataLinearLayout.hidden = YES;
    // 隐藏结果列表
    self.tableView.hidden = YES;
}

/**
 * 更新搜索开始前的信息提示文字。
 *
 * @param hint 提示内容，如果为null则表示隐藏信息提示相关布局的显示，否则更新提示文字
 */
- (void)updateHint:(NSString *)hint {
    if([BasicTool isStringEmpty:hint]){
        self.hintLinearLayout.hidden = YES;
    }else{
        self.hintLinearLayout.hidden = NO;
        self.hintTextView.text = hint;
    }
}


#pragma mark - RBSearchBarDelegate（搜索框控件的delegate实现）

// 点击搜索框上的“取消”按钮时调用本delegate方法
- (void)cancelForRBSearchbar:(RBSearchBar *)searchBar {
    [self doBack:YES];
}

// 搜索框里的输入内容发生改变时调用本方法
- (void)searchTextChangedForRBSearchbar:(RBSearchBar *)searchBar withText:(NSString *)keyword {
    DLogDebug(@"搜索内容改变了哦：%@", keyword);
    if (![BasicTool isStringEmpty:keyword]) {
        [self doSearch:keyword];
    } else {
        [self clearResult];
    }
}

@end

