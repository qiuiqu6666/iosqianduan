//
//  MessageSearch10001ViewController.h
//  RainbowChat4i
//
//  10001 专用查找消息页面，参考收藏夹设计：标题+副标题、右侧搜索+更多、横向分类 Tab、列表展示。
//

#import "CommonViewController.h"

@interface MessageSearch10001ViewController : CommonViewController

- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId
                     partnerName:(NSString *)partnerName;

/// 设为 YES 时，viewDidAppear 后会自动弹出搜索框（供从聊天页点搜索进入时使用）
@property (nonatomic, assign) BOOL showSearchBarOnAppear;
/// 进入时携带的搜索关键词（与 showSearchBarOnAppear 配合，弹出搜索框后自动填入并执行搜索）
@property (nonatomic, copy) NSString *initialSearchKeyword;

@end
