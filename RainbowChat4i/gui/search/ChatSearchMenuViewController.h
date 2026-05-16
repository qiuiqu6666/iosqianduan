//
//  ChatSearchMenuViewController.h
//  RainbowChat4i
//
//  聊天记录搜索菜单入口页，提供文字搜索、图片视频、文件、日期、群成员等搜索分类。
//

#import "CommonViewController.h"

@interface ChatSearchMenuViewController : CommonViewController

- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId
                     isGroupChat:(BOOL)isGroupChat;

@end
