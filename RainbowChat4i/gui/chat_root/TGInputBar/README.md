# TGInputBar — Telegram 风格输入栏

纯 OC、可商用级，拖入工程即可复用。

## 效果

- `[ + ]` `[ 输入框（自动变高，最多 5 行）]` `[ 🎤 / ➤ ]`
- 有文字时右按钮为发送 ➤，无文字时为语音 🎤
- 浮动白条 + 圆角 + 阴影
- 自动高度、键盘跟随由外部约束 + `onHeightChange` 驱动
- **回复引用预览**（Telegram 式）：白条顶部可显示「回复 + 昵称」蓝字、摘要一行、左侧蓝竖线、右侧关闭；`setReplyPreviewVisible:senderNick:snippetPlain:`，`onReplyPreviewClose` 与 `Quote4InputWrapper` 联动
- **占位符**：空内容时显示「输入消息」（可设 `composerPlaceholderText` 覆盖）

## 集成

1. 将 `TGInputBar` 文件夹拖入 Xcode 工程，勾选 Copy items、Target 选 RainbowChat4i。
2. 确保已依赖 `Default.h`、`Masonry`（与现有聊天页一致）。

## 使用示例

```objc
#import "TGInputBar.h"

// 创建（建议用约束贴底）
TGInputBar *inputBar = [[TGInputBar alloc] initWithFrame:CGRectZero];
inputBar.translatesAutoresizingMaskIntoConstraints = NO;
[self.view addSubview:inputBar];
[inputBar mas_makeConstraints:^(MASConstraintMaker *make) {
    make.leading.trailing.equalTo(self.view);
    make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
    make.height.mas_equalTo(66); // 初始高度，会随 onHeightChange 更新
}];

// 发送
inputBar.onSend = ^(NSString *text) {
    NSLog(@"发送：%@", text);
};
// +
inputBar.onPlusClick = ^{
    NSLog(@"打开附件");
};
// 🎤
inputBar.onVoiceClick = ^{
    NSLog(@"语音");
};
// 高度变化（键盘跟随时更新 bottom 或 height）
inputBar.onHeightChange = ^(CGFloat height) {
    [inputBar mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(height);
    }];
};
```

## 键盘跟随

用系统键盘通知更新输入栏的 bottom 或 height 即可，例如：

```objc
[[NSNotificationCenter defaultCenter] addObserver:self
  selector:@selector(keyboardWillChange:)
  name:UIKeyboardWillChangeFrameNotification object:nil];

- (void)keyboardWillChange:(NSNotification *)noti {
  CGRect frame = [noti.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  CGFloat keyboardY = frame.origin.y;
  CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
  // 更新 inputBar 的 bottom 约束为 screenH - keyboardY，或使用 onHeightChange 配合 height 约束
}
```

## 扩展

- 左/右按钮可替换为自定义图标（设置 `leftButton` / `rightButton` 的 image）。
- 可在本 view 上添加额外子视图（如交易按钮、Web3 入口），布局时预留空间即可。
