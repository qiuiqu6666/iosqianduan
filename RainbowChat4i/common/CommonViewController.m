//telegram @wz662
//
//  CommonViewController.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/9.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "CommonViewController.h"
#import "BasicTool.h"
#import <objc/runtime.h>

// 用于存储原始字体大小的关联对象key
static char kOriginalFontSizeKey;

@interface CommonViewController ()

@end

@implementation CommonViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // 自动刷新字体大小（根据全局字体设置）
    [self refreshAllFonts];
}

// 获取可重用的table cell
- (id)tableCell:(UITableView *)tableView withIdenfity:(NSString *)idenfity xibName:(NSString *)xibName c:(Class)c {
    id cell = [tableView dequeueReusableCellWithIdentifier:idenfity];
    if(cell == nil) {
        NSArray* arr = [[NSBundle mainBundle] loadNibNamed:xibName owner:self options:nil];
        for (id obj in arr) {
            if ([obj isKindOfClass:c]) {
                cell = obj;
            }
        }
    }
    
    return cell;
}

// 从当前界面退出
- (void)doBack:(BOOL)animated {
    [self.navigationController popViewControllerAnimated:animated];
}

// 统一的错误信息提示
- (void)promtAndFinish:(NSString *)promtMsg {
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak typeof(self) safeSelf = self;
    // 显示信息提示框
//    [BasicTool showAlert:@"出错了" content:promtMsg btnTitle:@"确认" parent:self handler:^(UIAlertAction *action) {
//        [safeSelf doBack:YES];
//    }];
}

// 隐藏导航栏
-(void)hideNavigation
{
    [self.navigationController setNavigationBarHidden:YES animated:YES];//no
}

// 显示导航栏
-(void)showNavigation
{
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}

// 刷新当前界面所有控件的字体大小（根据全局字体设置）
- (void)refreshAllFonts
{
    [self refreshFontsForView:self.view];
    
    // 刷新导航栏标题字体
    if (self.navigationController && self.navigationController.navigationBar) {
        NSMutableDictionary *titleTextAttributes = [self.navigationController.navigationBar.titleTextAttributes mutableCopy];
        if (!titleTextAttributes) {
            titleTextAttributes = [NSMutableDictionary dictionary];
        }
        UIFont *currentFont = titleTextAttributes[NSFontAttributeName];
        if (currentFont) {
            CGFloat baseSize = currentFont.pointSize;
            titleTextAttributes[NSFontAttributeName] = [BasicTool getSystemFontOfSize:baseSize];
            self.navigationController.navigationBar.titleTextAttributes = titleTextAttributes;
        }
    }
}

// 递归刷新视图及其子视图的字体
- (void)refreshFontsForView:(UIView *)view
{
    // 刷新当前视图的字体（如果是文本控件）
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.font) {
            // 获取或保存原始字体大小
            NSNumber *originalSizeObj = objc_getAssociatedObject(label, &kOriginalFontSizeKey);
            CGFloat originalSize;
            
            if (originalSizeObj == nil) {
                // 第一次设置，保存原始字体大小
                originalSize = label.font.pointSize;
                // 如果当前字体已经被调整过（不是标准倍数），需要还原到原始大小
                CGFloat currentMultiplier = [BasicTool getAppFontSizeMultiplier];
                if (currentMultiplier != 1.0 && originalSize > 0) {
                    // 尝试还原：如果当前字体大小接近调整后的值，则还原
                    CGFloat expectedSize = originalSize * currentMultiplier;
                    if (fabs(label.font.pointSize - expectedSize) < 0.1) {
                        // 当前字体已经被调整过，需要还原
                        originalSize = label.font.pointSize / currentMultiplier;
                    }
                }
                objc_setAssociatedObject(label, &kOriginalFontSizeKey, @(originalSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else {
                originalSize = [originalSizeObj floatValue];
            }
            
            if (originalSize > 0) {
                label.font = [BasicTool getSystemFontOfSize:originalSize];
            }
        }
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        if (button.titleLabel && button.titleLabel.font) {
            // 获取或保存原始字体大小
            NSNumber *originalSizeObj = objc_getAssociatedObject(button, &kOriginalFontSizeKey);
            CGFloat originalSize;
            
            if (originalSizeObj == nil) {
                // 第一次设置，保存原始字体大小
                originalSize = button.titleLabel.font.pointSize;
                // 如果当前字体已经被调整过，需要还原
                CGFloat currentMultiplier = [BasicTool getAppFontSizeMultiplier];
                if (currentMultiplier != 1.0 && originalSize > 0) {
                    CGFloat expectedSize = originalSize * currentMultiplier;
                    if (fabs(button.titleLabel.font.pointSize - expectedSize) < 0.1) {
                        originalSize = button.titleLabel.font.pointSize / currentMultiplier;
                    }
                }
                objc_setAssociatedObject(button, &kOriginalFontSizeKey, @(originalSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else {
                originalSize = [originalSizeObj floatValue];
            }
            
            if (originalSize > 0) {
                button.titleLabel.font = [BasicTool getSystemFontOfSize:originalSize];
            }
        }
    } else if ([view isKindOfClass:[UITextField class]]) {
        UITextField *textField = (UITextField *)view;
        if (textField.font) {
            NSNumber *originalSizeObj = objc_getAssociatedObject(textField, &kOriginalFontSizeKey);
            CGFloat originalSize;
            
            if (originalSizeObj == nil) {
                originalSize = textField.font.pointSize;
                CGFloat currentMultiplier = [BasicTool getAppFontSizeMultiplier];
                if (currentMultiplier != 1.0 && originalSize > 0) {
                    CGFloat expectedSize = originalSize * currentMultiplier;
                    if (fabs(textField.font.pointSize - expectedSize) < 0.1) {
                        originalSize = textField.font.pointSize / currentMultiplier;
                    }
                }
                objc_setAssociatedObject(textField, &kOriginalFontSizeKey, @(originalSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else {
                originalSize = [originalSizeObj floatValue];
            }
            
            if (originalSize > 0) {
                textField.font = [BasicTool getSystemFontOfSize:originalSize];
            }
        }
    } else if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        if (textView.font) {
            NSNumber *originalSizeObj = objc_getAssociatedObject(textView, &kOriginalFontSizeKey);
            CGFloat originalSize;
            
            if (originalSizeObj == nil) {
                originalSize = textView.font.pointSize;
                CGFloat currentMultiplier = [BasicTool getAppFontSizeMultiplier];
                if (currentMultiplier != 1.0 && originalSize > 0) {
                    CGFloat expectedSize = originalSize * currentMultiplier;
                    if (fabs(textView.font.pointSize - expectedSize) < 0.1) {
                        originalSize = textView.font.pointSize / currentMultiplier;
                    }
                }
                objc_setAssociatedObject(textView, &kOriginalFontSizeKey, @(originalSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else {
                originalSize = [originalSizeObj floatValue];
            }
            
            if (originalSize > 0) {
                textView.font = [BasicTool getSystemFontOfSize:originalSize];
            }
        }
    }
    
    // 递归处理所有子视图
    for (UIView *subview in view.subviews) {
        [self refreshFontsForView:subview];
    }
}

@end
