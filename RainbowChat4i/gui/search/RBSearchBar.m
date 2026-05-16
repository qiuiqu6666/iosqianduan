//telegram @wz662
//
//  RBSearchBar.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/21.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "RBSearchBar.h"
#import "BasicTool.h"

@interface RBSearchBar () <UITextFieldDelegate>
@end

@implementation RBSearchBar


#pragma mark - Initialization

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    [self initViews];
}

- (void)initViews {
    // 为清空图标增加点击事件处理
    [BasicTool addFingerClick:self.viewClear action:@selector(doClear:) target:self];
    // 为取消按钮添加事件处理
    [self.btnCancel addTarget:self action:@selector(doCancel:) forControlEvents:UIControlEventTouchUpInside];
    // 文本输入内容变化的监听
    [self.viewEdit addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    // 回车关闭键盘
    self.viewEdit.delegate = self;
}


#pragma mark - 内部方法

- (void)handleClearView:(NSString *)s {
    self.viewClear.hidden = [BasicTool isStringEmpty:s];
}

// 监听输入事件，实现手机号码、更多描述的字数统计和最大输入字数限制
- (void) textFieldDidChange:(UITextField *)textField {
    [self handleClearView:textField.text];
    if(self.delegate != nil)
       [self.delegate searchTextChangedForRBSearchbar:self withText:textField.text];
}

- (void)doClear:(UIView *)v {
    self.viewEdit.text = nil;
    // 设置text属性时是不会触发事件的，所以这里强行调用输入内容改变
    [self textFieldDidChange:self.viewEdit];
}

- (void)doCancel:(UIButton *)sender {
    if(self.delegate != nil)
       [self.delegate cancelForRBSearchbar:self];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}


#pragma mark - 公开的方法

- (void)setKeyword:(NSString *)s {
    self.viewEdit.text = s;
    // 光标移到末尾
    [self setCursorToEnd];
    // 设置text属性时是不会触发事件的，所以这里强行调用输入内容改变
    [self textFieldDidChange:self.viewEdit];
}

- (void)setCursorToEnd {
    // 将光标移至文字末尾
    [BasicTool setCursorToEnd:self.viewEdit];
}

@end
