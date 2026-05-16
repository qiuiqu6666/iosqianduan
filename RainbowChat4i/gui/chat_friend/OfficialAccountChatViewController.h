//
//  OfficialAccountChatViewController.h
//  RainbowChat4i
//
//  只读官方账号（10000、400069、400070）专用聊天页，样式与单聊一致，仅无输入栏与更多入口，进入更轻。
//

#import "ChatRootViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface OfficialAccountChatViewController : ChatRootViewController

- (instancetype)initWithUid:(NSString *)uid nickname:(NSString *)nickname;

@end

NS_ASSUME_NONNULL_END
