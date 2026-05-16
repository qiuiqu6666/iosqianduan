//
//  FileBrowserViewController.h
//  RainbowChat4i
//
//  文件浏览器 — 展示聊天中的所有文件消息。
//

#import "CommonViewController.h"

@interface FileBrowserViewController : CommonViewController

/// 10001 收藏夹时使用服务端文件列表（fav_type=4），列表样式为扩展名图标+文件名+大小+日期
@property (nonatomic, assign) BOOL useServerFavoritesFor10001;

- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId;

@end
