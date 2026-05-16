//telegram @wz662
#import <UIKit/UIKit.h>
#import "JSQMessages.h"
#import "NSMutableArrayObservableEx.h"
#import "TZImagePickerController.h"
#import "IQAudioRecorderViewController.h"
#import "UserEntity.h"
#import "RBImagePickerWrapper.h"
#import "kmMoreMenuView.h"
#import "ChatRootViewController.h"
#import "GetLocationViewController.h"


@interface ChatViewController :ChatRootViewController<UINavigationControllerDelegate, kmMoreMenuViewDelegate>

- (instancetype _Nonnull )initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil chatWith:(NSString *)friendUID andNickname:(NSString *)friendNickname;

///**
// * 当前正在聊天者的uid（本方法目前仅用于跳转到聊天界面时，判断页面栈中的聊天界面是否要跳转的目标聊天者，暂无他用，详见：[ViewControllerFactory goChatViewController:]方法）。
// *
// * @return 返回当前正在聊天者的uid
// */
//- (NSString *)getTargetId;

@end
