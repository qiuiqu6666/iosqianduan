//telegram @wz662

#import <UIKit/UIKit.h>
#import "FaceBoardConfig.h"
#import "EmojiUtil.h"

#import "IMClientManager.h"

NS_ASSUME_NONNULL_BEGIN

@class FaceTabbar;
@protocol FaceTabbarDelegate<NSObject>

// 点击发送按钮
- (void)tabbar:(FaceTabbar *)tabbar clickedSendAction:(UIButton *)button;

@optional
// 切换到 Emoji 标签页
- (void)tabbar:(FaceTabbar *)tabbar didSelectEmojiTab:(UIButton *)button;
// 切换到自定义表情标签页
- (void)tabbar:(FaceTabbar *)tabbar didSelectStickerTab:(UIButton *)button;
// 点击表情管理（设置）按钮
- (void)tabbar:(FaceTabbar *)tabbar didClickManageAction:(UIButton *)button;

@end

@interface FaceTabbar : UIView

@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIButton *emojiTabButton;
@property (nonatomic, strong) UIButton *stickerTabButton;
@property (nonatomic, strong) UIButton *manageButton;

@property (nonatomic, weak) id<FaceTabbarDelegate>delegate;

/// 当前选中的 tab 索引：0=emoji, 1=sticker
@property (nonatomic, assign) NSInteger selectedTabIndex;

- (instancetype)initWithConfig:(FaceBoardConfig * _Nonnull)config;

/// 更新 tab 选中状态外观
- (void)updateTabSelection;

@end

NS_ASSUME_NONNULL_END
