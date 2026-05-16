//
//  TypeFilteredMessagesViewController.h
//  RainbowChat4i
//
//  按消息类型（如文本/语音等）分页展示当前会话内的消息列表，用于 10001 收藏夹里的「对话」「语音」等分类。
//

#import "CommonViewController.h"

@interface TypeFilteredMessagesViewController : CommonViewController

- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId
                        msgTypes:(NSArray<NSNumber *> *)msgTypes
                       emptyText:(NSString *)emptyText;

/// 对话模式：按 msgTypes 展示，且排除文本内容含 URL 的消息（与链接 Tab 不重复）
- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId
                        msgTypes:(NSArray<NSNumber *> *)msgTypes
                       emptyText:(NSString *)emptyText
        excludeTextContainingURL:(BOOL)excludeTextContainingURL;

/// 链接模式：仅展示文本内容包含 URL 的消息（与 msgTypes 二选一，linkOnly=YES 时忽略 msgTypes）
- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId
                       emptyText:(NSString *)emptyText
                        linkOnly:(BOOL)linkOnly;

/// 外部设置搜索关键字（仅过滤当前页面已加载的消息）
- (void)updateSearchKeyword:(NSString *)keyword;

/// 当前展示的消息条数（含关键词过滤后），供收藏夹搜索条「共 N 条消息」使用
- (NSInteger)currentDisplayedCount;

/// 10001 收藏夹「对话」等 Tab 使用服务端收藏接口数据（名称、内容、头像均为服务端返回）。创建后设置，再 load 生效。
@property (nonatomic, assign) BOOL useServerFavoritesFor10001;
/// 服务端收藏类型：0 文本 1 图片 2 语音 3 视频 4 文件 5 位置，-1 全部
@property (nonatomic, assign) int serverFavType;
/// 多类型分组时用：只保留 fav_type 在此集合内的项（如 多媒体=@[@1,@3]）。非空时请求用 favType=-1 再客户端过滤
@property (nonatomic, copy) NSArray<NSNumber *> *serverFavTypeFilter;
/// 链接 Tab：仅保留文本且 content 含 http 的收藏
@property (nonatomic, assign) BOOL serverLinkOnlyFilter;

@end

