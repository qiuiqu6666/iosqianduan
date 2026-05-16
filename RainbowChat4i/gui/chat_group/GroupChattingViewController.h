//telegram @wz662
#import <Foundation/Foundation.h>
#import "ChatRootViewController.h"

@interface GroupChattingViewController : ChatRootViewController<kmMoreMenuViewDelegate>

- (instancetype _Nonnull )initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil gid:(NSString *_Nonnull)gid gname:(NSString *_Nonnull)gname;

/**
 * 以下代码用于往聊天界面上显示并组织消息列表上部的信息提示UI（用于大于iOS 26的系统中）。
 *
 *@since 10.2
 */
+ (void)attachTopExtraView_ios26:(JSQMessagesViewController *)parent hintText:(NSString *)hint;

/**
 * 以下代码用于往聊天界面上显示并组织消息列表上部的信息提示UI（用于低于iOS 26的系统中）
 */
+ (void)attachTopExtraView:(JSQMessagesViewController *_Nonnull)parent hintText:(NSString *_Nullable)hint view1:(UIView *_Nullable)view1;

@end
