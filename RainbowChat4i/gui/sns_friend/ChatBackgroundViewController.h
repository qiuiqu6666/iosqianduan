//telegram @wz662
/**
 * 聊天背景选择页面。
 * 支持从相册选择自定义背景、选择预设背景、恢复默认。
 *
 * @author Claude, 2026-02-10
 */

#import <UIKit/UIKit.h>

// 聊天背景变更通知
#define kNotificationCenter_For_ChatBackgroundChanged @"__NC_For_ChatBackgroundChanged__"

@interface ChatBackgroundViewController : UIViewController

/**
 * 初始化方法。
 *
 * @param chatId 聊天对象id（单聊时为对方uid，群聊时为gid）
 */
- (instancetype)initWithChatId:(NSString *)chatId;

/**
 * 获取指定聊天的自定义背景图片。
 *
 * @param chatId 聊天对象id
 * @return 自定义背景图片，如果没有设置则返回nil
 */
+ (UIImage *)backgroundImageForChatId:(NSString *)chatId;

/**
 * 删除指定聊天的自定义背景。
 *
 * @param chatId 聊天对象id
 */
+ (void)removeBackgroundForChatId:(NSString *)chatId;

/**
 * 获取聊天背景图片的存储路径。
 *
 * @param chatId 聊天对象id
 * @return 文件路径
 */
+ (NSString *)backgroundImagePathForChatId:(NSString *)chatId;

/// 当前会话是否在设置里选了「预设纯色」背景（非相册图、非推荐大图）
+ (BOOL)isSolidColorChatBackgroundForChatId:(NSString *)chatId;

/// 预设纯色对应的 RGB（与 UserDefaults 中 CHAT_BG_COLOR 一致）；非纯色背景返回 nil
+ (UIColor *)solidChatBackgroundColorForChatId:(NSString *)chatId;

@end
