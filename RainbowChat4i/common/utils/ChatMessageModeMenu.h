//
//  ChatMessageModeMenu.h
//  RainbowChat4i
//
//  收藏夹/聊天页共用的「以聊天模式查看 / 以消息模式查看」胶囊弹窗。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 0 = 以聊天模式查看，1 = 以消息模式查看
typedef void(^ChatMessageModeMenuSelectBlock)(NSInteger index);

@interface ChatMessageModeMenu : NSObject

/// 创建与收藏夹/聊天页一致的「搜索 + 更多」胶囊视图（88×32），用于导航栏右侧。调用方持有返回的 view 并设为 rightBarButtonItem.customView。
+ (UIView *)navSearchMoreCapsuleWithSearchTarget:(id)searchTarget
                                    searchAction:(SEL)searchAction
                                      moreTarget:(id)moreTarget
                                       moreAction:(SEL)moreAction;

/// 仅放大镜搜索按钮（36×36），与胶囊内单键视觉一致，用于在线客服 400069 等只需搜索、不要「更多」的场景。
+ (UIView *)navSearchOnlyButtonWithTarget:(id)searchTarget action:(SEL)searchAction;

/// 从某 VC 的锚点视图（如右上角胶囊）弹出，样式与收藏夹页一致。选中后回调 index（0 或 1），然后自动关闭。
+ (void)showFromViewController:(UIViewController *)viewController
                    anchorView:(UIView *)anchorView
               onSelectIndex:(ChatMessageModeMenuSelectBlock)block;

@end

NS_ASSUME_NONNULL_END
