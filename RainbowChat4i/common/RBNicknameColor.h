//
//  RBNicknameColor.h
//  RainbowChat4i
//
//  按 uid + chatId 确定性生成昵称颜色，纯前端、多端一致。同一群内每人看到的颜色相同，同一用户在不同群颜色不同。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RBNicknameColor : NSObject

/// 根据用户 uid 和当前会话 id（群 id / 收藏夹 10001 等）返回确定性颜色，多端一致
+ (UIColor *)nicknameColorForUserId:(NSString *)userId chatId:(NSString *)chatId;

@end

NS_ASSUME_NONNULL_END
