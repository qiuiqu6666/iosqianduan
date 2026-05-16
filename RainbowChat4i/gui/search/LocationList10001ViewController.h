//
//  LocationList10001ViewController.h
//  RainbowChat4i
//
//  收藏夹内「位置」Tab：与 10001 会话中的位置消息列表，列表 UI，点击跳转聊天定位。
//

#import "CommonViewController.h"

@interface LocationList10001ViewController : CommonViewController

/// 10001 收藏夹时使用服务端位置列表（fav_type=5），列表为图标+标题+地址+时间，点击跳转聊天定位
@property (nonatomic, assign) BOOL useServerFavoritesFor10001;

- (instancetype)initWithChatType:(int)chatType dataId:(NSString *)dataId;

@end
