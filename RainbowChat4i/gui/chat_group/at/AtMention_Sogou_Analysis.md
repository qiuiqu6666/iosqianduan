# @ 选人 + 搜狗输入法：系统梳理与根因分析

## 1. 完整数据流（从用户输入 @ 到插入昵称）

```
用户输入 "@"
  → textView:shouldChangeTextInRange:replacementText: 被调，text == "@"
  → showAtUserActivity:NO（needInsertAitInText=NO，因为 "@" 由输入法插入）
  → return YES → "@" 留在文本框
  → push 选人页（TargetChooseViewController）

用户选人返回
  → processTargetChooseComplete: 被调，te=选中用户，extraObj=@(NO)
  → processAtChooseCompleteImpl:te needInsertAitInText:NO
  → str = ""，然后会在 addAtUser 里被改成 str = "昵称\u2004"（NIMInputAtEndChar=\u2004）
  → isTopVisible == YES 时：不立刻插入，设 pendingAtUserForKeyboard / pendingAtUserPrefixForKeyboard
  → 先 becomeFirstResponder（或 reloadInputViews），等键盘显示
  → 由 UIKeyboardDidShowNotification 或 0.7s 兜底触发 flushPendingAtUserInsertIfNeeded
```

## 2. flushPendingAtUserInsertIfNeeded 当前逻辑

```
1. 清空 pending，移除键盘观察者
2. textView resignFirstResponder（键盘收起，输入法脱离）
3. dispatch_async(main) {
     atCache addAtUser → insertTextStr("昵称\u2004" 或 "@昵称\u2004")
     dispatch_after(0.45s) { textView becomeFirstResponder }
   }
```

- **insertTextStr**：用当前 `text` 和 `selectedRange` 做替换；若 `range.location > text.length` 会做越界保护（resign 后搜狗可能清空 text 但 selectedRange 仍是旧值）。

## 3. 为何系统输入法正常、搜狗“只显示 @”？

| 环节 | 系统键盘 | 搜狗等第三方 |
|------|----------|--------------|
| 输入法与文本框 | 同属系统，text 即真相 | 输入法有独立**缓冲区**（未确认/已提交内容） |
| 用户输入 "@" | 直接进 text | "@" 可能在缓冲区，或已进 text |
| 程序里 set text | 无第二方写回 | 输入法在**重新挂载**（becomeFirstResponder）时会把缓冲区写回 text |
| 结果 | 我们插入的 "昵称" 保留 | 我们插入后，再弹键盘时搜狗用缓冲区（仅 "@"）覆盖整段 → 只看到 "@" |

即：**不是“换输入法逻辑不同”，而是第三方输入法在重新成为第一响应者时会按自己的缓冲区写回文本框，覆盖我们刚插入的昵称。**

## 4. 已做过的尝试与结果

- 延后插入（等键盘显示后再插）：仍被搜狗写回覆盖。
- 先 resign → 下一 runloop 插入 → 再 becomeFirstResponder：插入瞬间无输入法，但**再次 becomeFirstResponder 时搜狗仍会写回**。
- 延迟 0.45s 再 becomeFirstResponder：仍可能被覆盖（搜狗缓冲区保留时间可能更长）。
- insertTextStr 越界保护：避免 resign 后 text 为空、selectedRange 越界导致崩溃；不能解决“再弹键盘被覆盖”的问题。

## 5. 当前兜底策略（插入后不自动弹键盘）

- 插入完成后**不再调用 becomeFirstResponder**，避免搜狗立刻重新挂载并写回。
- 提示用户：“已添加 @xxx，点击输入框继续输入”。
- 用户点击输入框时再弹键盘；若此时搜狗仍覆盖，则需在“用户点击聚焦”路径上再做延迟或兼容（如延迟聚焦、或检测到为搜狗时采用不同策略）。

## 6. 调试建议

- 在 **flushPendingAtUserInsertIfNeeded**：resign 前打 log（text.length, selectedRange）；addAtUser 后再打 log（text.length, text 前若干字符）。
- 在 **insertTextStr**：打 log（current.length, range, textToInsert.length, result.length）。
- 若 log 显示插入后 text 已含昵称，但界面仍只显示 "@"，说明是**后续**被写回（如用户点击输入框时搜狗写回）；若插入后 text 就没有昵称，说明插入逻辑或时机仍有问题。
