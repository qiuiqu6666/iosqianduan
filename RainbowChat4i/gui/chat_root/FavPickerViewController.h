//
//  FavPickerViewController.h
//  RainbowChat4i
//
//  收藏内容选择器 —— 在聊天界面中弹出，选择后直接发送收藏内容。
//

#import <UIKit/UIKit.h>

/**
 * 收藏内容选择完成后的回调。
 *
 * @param selectedItem 用户选中的收藏条目（字典），包含 fav_type, content 等字段。传 nil 表示取消。
 */
typedef void(^FavPickerCompletion)(NSDictionary * _Nullable selectedItem);

@interface FavPickerViewController : UIViewController

/** 选择完成后的回调 */
@property (nonatomic, copy) FavPickerCompletion completion;
/** 当前发送目标名称 */
@property (nonatomic, copy) NSString *targetName;
/** 当前发送目标 id */
@property (nonatomic, copy) NSString *targetId;
/** 当前聊天类型 */
@property (nonatomic, assign) int targetChatType;

@end
