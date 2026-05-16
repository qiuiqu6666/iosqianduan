//
//  MediaBrowserViewController.h
//  RainbowChat4i
//
//  图片与视频浏览器 — 以网格形式展示聊天中的所有图片和视频。
//

#import "CommonViewController.h"

@interface MediaBrowserViewController : CommonViewController

- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId;

/// 10001 收藏夹多媒体：从服务端收藏接口拉取（图片+视频），网格展示
@property (nonatomic, assign) BOOL useServerFavoritesFor10001;

@end
