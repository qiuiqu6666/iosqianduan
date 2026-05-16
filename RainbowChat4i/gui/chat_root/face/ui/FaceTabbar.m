//telegram @wz662

#import "FaceTabbar.h"
#import "FaceDataProvider.h"

@interface FaceTabbar ()

@property (nonatomic, strong) FaceBoardConfig *config;

@end

@implementation FaceTabbar

- (instancetype)initWithConfig:(FaceBoardConfig * _Nonnull)config {
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];  // 使用系统 inputView 背景，不再自定义画布
        self.config = config;
        _selectedTabIndex = 0;
        
        // === 左侧 Tab 按钮区域 ===
        
        // Emoji Tab：与输入栏旁表情按钮同一资源 chat_face_icon（xiaolian.svg）；无则 biaoqing，再无则 SF Symbol
        self.emojiTabButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *emojiIcon = [UIImage imageNamed:@"chat_face_icon"];
        if (!emojiIcon) emojiIcon = [UIImage imageNamed:@"biaoqing"];
        if (!emojiIcon) {
            emojiIcon = [UIImage systemImageNamed:@"face.smiling"];
        } else {
            emojiIcon = [emojiIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        [self.emojiTabButton setImage:emojiIcon forState:UIControlStateNormal];
        self.emojiTabButton.imageEdgeInsets = UIEdgeInsetsMake(8, 8, 8, 8);
        self.emojiTabButton.tintColor = [UIColor darkGrayColor];
        [self.emojiTabButton addTarget:self action:@selector(clickedEmojiTabAction:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.emojiTabButton];
        
        // Sticker Tab 按钮（爱心/贴纸图标）
        self.stickerTabButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *stickerIcon = [UIImage systemImageNamed:@"star.fill"];
        [self.stickerTabButton setImage:stickerIcon forState:UIControlStateNormal];
        self.stickerTabButton.tintColor = [UIColor lightGrayColor];
        [self.stickerTabButton addTarget:self action:@selector(clickedStickerTabAction:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.stickerTabButton];
        
        // === 右侧按钮区域 ===
        
        // 表情管理按钮（齿轮/设置图标）— 仅在 sticker tab 显示
        self.manageButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *manageIcon = [UIImage systemImageNamed:@"plus.circle"];
        [self.manageButton setImage:manageIcon forState:UIControlStateNormal];
        self.manageButton.tintColor = [UIColor grayColor];
        [self.manageButton addTarget:self action:@selector(clickedManageAction:) forControlEvents:UIControlEventTouchUpInside];
        self.manageButton.hidden = YES; // 默认隐藏（emoji tab 模式下）
        [self addSubview:self.manageButton];
        
        // 发送按钮
        self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.sendButton.backgroundColor = config.sendButtonBackgroundColor;
        [self.sendButton setTitleColor:config.sendButtonTitleColor forState:UIControlStateNormal];
        self.sendButton.titleLabel.font = config.sendButtonTitleFont;
        [self.sendButton setTitle:self.config.sendButtonTitle forState:UIControlStateNormal];
        [self.sendButton setImage:self.config.sendButtonImage forState:UIControlStateNormal];
        [self.sendButton addTarget:self action:@selector(clickedSendButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.sendButton];
        // 按钮下时的背景
        [self.sendButton setBackgroundImage:[UIImage imageNamed:@"common_btn_hilight_bg"] forState:UIControlStateHighlighted];
        
        // 在整个tabbar的上方加一个ui装饰横线（透明，与系统背景一致）
        UIView *separatorViewTop = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetMinX(self.frame), CGRectGetMinY(self.frame), ScreenWidth, 0.5)];
        separatorViewTop.backgroundColor = [UIColor clearColor];
        separatorViewTop.tag = 9999;
        [self addSubview:separatorViewTop];
        
        [self updateTabSelection];
    }
    return self;
}

#pragma mark - Tab 切换

- (void)clickedEmojiTabAction:(UIButton *)sender {
    if (self.selectedTabIndex == 0) return;
    self.selectedTabIndex = 0;
    [self updateTabSelection];
    if (_delegate && [_delegate respondsToSelector:@selector(tabbar:didSelectEmojiTab:)]) {
        [_delegate tabbar:self didSelectEmojiTab:sender];
    }
}

- (void)clickedStickerTabAction:(UIButton *)sender {
    if (self.selectedTabIndex == 1) return;
    self.selectedTabIndex = 1;
    [self updateTabSelection];
    if (_delegate && [_delegate respondsToSelector:@selector(tabbar:didSelectStickerTab:)]) {
        [_delegate tabbar:self didSelectStickerTab:sender];
    }
}

- (void)updateTabSelection {
    if (self.selectedTabIndex == 0) {
        // Emoji 选中
        self.emojiTabButton.tintColor = [UIColor darkGrayColor];
        self.emojiTabButton.backgroundColor = HexColor(0xE8E8E8);
        self.stickerTabButton.tintColor = [UIColor lightGrayColor];
        self.stickerTabButton.backgroundColor = [UIColor clearColor];
        self.manageButton.hidden = YES;
    } else {
        // Sticker 选中
        self.emojiTabButton.tintColor = [UIColor lightGrayColor];
        self.emojiTabButton.backgroundColor = [UIColor clearColor];
        self.stickerTabButton.tintColor = [UIColor darkGrayColor];
        self.stickerTabButton.backgroundColor = HexColor(0xE8E8E8);
        self.manageButton.hidden = NO;
    }
}

// 点击发送
- (void)clickedSendButtonAction:(UIButton *)sender {
    if (_delegate && [_delegate respondsToSelector:@selector(tabbar:clickedSendAction:)]) {
        [_delegate tabbar:self clickedSendAction:sender];
    }
}

// 点击管理
- (void)clickedManageAction:(UIButton *)sender {
    if (_delegate && [_delegate respondsToSelector:@selector(tabbar:didClickManageAction:)]) {
        [_delegate tabbar:self didClickManageAction:sender];
    }
}

// 重写父类方法
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = UIScreen.mainScreen.bounds.size.height >= 812 ? self.config.tabBarHeigh - 20 : self.config.tabBarHeigh;
    CGFloat tabBtnSize = h;
    
    // Tab 按钮布局（左侧）
    self.emojiTabButton.frame = CGRectMake(0, 0, tabBtnSize, h);
    self.emojiTabButton.layer.cornerRadius = 4;
    self.stickerTabButton.frame = CGRectMake(tabBtnSize, 0, tabBtnSize, h);
    self.stickerTabButton.layer.cornerRadius = 4;
    
    // 发送按钮布局（最右侧）
    self.sendButton.frame = CGRectMake(self.bounds.size.width - self.config.sendButtonWidth, 0, self.config.sendButtonWidth, h);
    
    // 管理按钮布局（发送按钮左边）
    self.manageButton.frame = CGRectMake(self.bounds.size.width - self.config.sendButtonWidth - tabBtnSize - 4, 0, tabBtnSize, h);
    
    // 在发送按钮左边加一个装饰竖线
    float separatorViewForSendButtonGap = 7;
    // 移除旧的分隔线（避免重复添加）
    for (UIView *sv in self.subviews) {
        if (sv.tag == 8888) [sv removeFromSuperview];
    }
    UIView *separatorViewForSendButton = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetMinX(self.sendButton.frame), separatorViewForSendButtonGap, 0.5, h - separatorViewForSendButtonGap * 2)];
    separatorViewForSendButton.backgroundColor = [UIColor clearColor];  // 使用系统背景，不再自定义
    separatorViewForSendButton.tag = 8888;
    [self addSubview:separatorViewForSendButton];
    
    // 更新顶部分隔线
    UIView *topLine = [self viewWithTag:9999];
    topLine.frame = CGRectMake(0, 0, self.bounds.size.width, 0.5);
}

@end
