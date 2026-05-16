//telegram @wz662
#import "ChatRootViewController.h"


@interface TempChatViewController : ChatRootViewController<UINavigationControllerDelegate, kmMoreMenuViewDelegate>

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil guestUid:(NSString *)uid guestName:(NSString *)name maxFriend:(int)maxFriend;

///**
// * 当前正在聊天者的uid（本方法目前仅用于跳转到聊天界面时，判断页面栈中的聊天界面是否要跳转的目标聊天者，暂无他用，详见：[ViewControllerFactory goChatViewController:]方法）。
// *
// * @return 返回当前正在聊天者的uid
// */
//- (NSString *)getTargetId;

@end
