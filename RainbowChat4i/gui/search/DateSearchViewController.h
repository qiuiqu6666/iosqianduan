//
//  DateSearchViewController.h
//  RainbowChat4i
//
//  按日期搜索消息 — 选择日期后展示当天所有聊天消息。
//

#import "CommonViewController.h"

@interface DateSearchViewController : CommonViewController

- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId;

@end
