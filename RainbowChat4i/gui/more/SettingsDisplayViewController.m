//telegram @wz662
#import "SettingsDisplayViewController.h"
#import "UserDefaultsToolKits.h"
#import "LPActionSheet.h"
#import "BasicTool.h"
#import "FontSizePreviewViewController.h"
#import "UIViewController+RBPlainCustomNav.h"
#import <objc/runtime.h>

// 用于存储原始字体大小的关联对象key
static char kOriginalFontSizeKey;

@interface SettingsDisplayViewController ()

@end

@implementation SettingsDisplayViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self rb_installPlainCustomNavigationBarWithTitle:@"界面与显示"];

    // 加载保存的设置
    [self loadSettings];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self rb_plainCustomNavHostViewWillAppear:animated];

    // 刷新字体大小（如果从其他界面返回，字体设置可能已更改）
    [self refreshAllFonts];
    
    // 监听语言切换通知
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(onLanguageChanged) 
                                                 name:@"AppLanguageDidChangeNotification" 
                                                 object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self rb_plainCustomNavHostViewWillDisappear:animated];

    // 移除通知监听
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AppLanguageDidChangeNotification" object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

- (void)onLanguageChanged
{
    // 语言切换后，刷新界面文本
    // 注意：由于 iOS 的限制，NSLocalizedString 需要重启应用才能完全生效
    // 但我们可以刷新当前界面的标签文本
    [self refreshLanguageLabel];
    
    // 刷新导航栏标题（如果使用了本地化字符串）
    // self.title = NSLocalizedString(@"settings_display_title", @"界面与显示");
}

- (void)loadSettings
{
    // 加载主题设置
    [self refreshThemeLabel];
    
    // 加载字体大小设置
    [self refreshFontSizeLabel];
    
    // 加载多语言设置
    [self refreshLanguageLabel];
}

- (void)refreshThemeLabel
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *themeModeKey = @"APP_THEME_MODE"; // 0: 跟随系统, 1: 日间模式, 2: 深色模式
    NSInteger themeMode = [userDefaults integerForKey:themeModeKey];
    
    // 如果未设置，默认为跟随系统
    if ([userDefaults objectForKey:themeModeKey] == nil) {
        themeMode = 0;
        [userDefaults setInteger:0 forKey:themeModeKey];
        [userDefaults synchronize];
    }
    
    // 根据模式显示对应的文字
    if (themeMode == 0) {
        self.themeLabel.text = @"跟随系统";
    } else if (themeMode == 1) {
        self.themeLabel.text = @"日间模式";
    } else if (themeMode == 2) {
        self.themeLabel.text = @"深色模式";
    } else {
        self.themeLabel.text = @"跟随系统";
    }
}

- (void)refreshFontSizeLabel
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *fontSizeKey = @"APP_FONT_SIZE"; // 0~4: 小、较小、标准、较大、大
    NSInteger fontSize = [userDefaults integerForKey:fontSizeKey];
    
    if ([userDefaults objectForKey:fontSizeKey] == nil) {
        fontSize = 2;
        [userDefaults setInteger:2 forKey:fontSizeKey];
        [userDefaults synchronize];
    }
    
    NSArray *fontSizeNames = @[@"小", @"较小", @"标准", @"较大", @"大"];
    if (fontSize >= 0 && fontSize < (NSInteger)fontSizeNames.count) {
        self.fontSizeLabel.text = fontSizeNames[fontSize];
    } else {
        self.fontSizeLabel.text = @"标准";
    }
}

- (void)refreshLanguageLabel
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *languageKey = @"APP_LANGUAGE"; // 语言代码，如 "zh-Hans", "en", "zh-Hant"
    NSString *language = [userDefaults stringForKey:languageKey];
    
    if ([language isEqualToString:@"zh-Hans"]) {
        self.languageLabel.text = @"简体中文";
    } else if ([language isEqualToString:@"zh-Hant"]) {
        self.languageLabel.text = @"繁体中文";
    } else if ([language isEqualToString:@"en"]) {
        self.languageLabel.text = @"English";
    } else {
        // 如果未设置，默认使用简体中文
        self.languageLabel.text = @"简体中文";
        // 同时设置默认语言
        [userDefaults setObject:@"zh-Hans" forKey:languageKey];
        [userDefaults synchronize];
        [BasicTool setAppLanguage:@"zh-Hans"];
    }
}

// 主题选择点击
- (IBAction)clickTheme:(id)sender
{
    [LPActionSheet showActionSheetWithTitle:@"选择主题"
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"深色模式", @"日间模式", @"跟随系统"]
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
                                        if (index > 0) {
                                            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                                            NSString *themeModeKey = @"APP_THEME_MODE";
                                            
                                            // index 1: 深色模式, 2: 日间模式, 3: 跟随系统
                                            if (index == 1) {
                                                [userDefaults setInteger:2 forKey:themeModeKey]; // 深色模式
                                            } else if (index == 2) {
                                                [userDefaults setInteger:1 forKey:themeModeKey]; // 日间模式
                                            } else if (index == 3) {
                                                [userDefaults setInteger:0 forKey:themeModeKey]; // 跟随系统
                                            }
                                            [userDefaults synchronize];
                                            
                                            [self refreshThemeLabel];
                                        }
                                    }];
}

// 字体大小点击：push 到字体大小预览页
- (IBAction)clickFontSize:(id)sender
{
    FontSizePreviewViewController *vc = [[FontSizePreviewViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

// 多语言选择点击
- (IBAction)clickLanguage:(id)sender
{
    [LPActionSheet showActionSheetWithTitle:@"选择语言"
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"简体中文", @"繁体中文", @"English"]
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
                                        if (index > 0) {
                                            // index 1: 简体中文, 2: 繁体中文, 3: English
                                            NSString *languageCode = nil;
                                            if (index == 1) {
                                                languageCode = @"zh-Hans";
                                            } else if (index == 2) {
                                                languageCode = @"zh-Hant";
                                            } else if (index == 3) {
                                                languageCode = @"en";
                                            }
                                            
                                            // 设置语言
                                            [BasicTool setAppLanguage:languageCode];
                                            
                                            [self refreshLanguageLabel];
                                        }
                                    }];
}

// 刷新当前界面所有控件的字体大小（根据全局字体设置）
- (void)refreshAllFonts
{
    [self refreshFontsForView:self.view];
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
                // 判断是否为粗体
                BOOL isBold = [label.font.fontName containsString:@"Bold"];
                BOOL isMedium = [label.font.fontName containsString:@"Medium"];
                
                if (isMedium) {
                    CGFloat adjustedSize = [BasicTool getAdjustedFontSize:originalSize];
                    label.font = [UIFont systemFontOfSize:adjustedSize weight:UIFontWeightMedium];
                } else if (isBold) {
                    label.font = [BasicTool getBoldSystemFontOfSize:originalSize];
                } else {
                    label.font = [BasicTool getSystemFontOfSize:originalSize];
                }
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
                BOOL isBold = [button.titleLabel.font.fontName containsString:@"Bold"];
                BOOL isMedium = [button.titleLabel.font.fontName containsString:@"Medium"];
                
                if (isMedium) {
                    CGFloat adjustedSize = [BasicTool getAdjustedFontSize:originalSize];
                    button.titleLabel.font = [UIFont systemFontOfSize:adjustedSize weight:UIFontWeightMedium];
                } else if (isBold) {
                    button.titleLabel.font = [BasicTool getBoldSystemFontOfSize:originalSize];
                } else {
                    button.titleLabel.font = [BasicTool getSystemFontOfSize:originalSize];
                }
            }
        }
    }
    
    // 递归处理所有子视图
    for (UIView *subview in view.subviews) {
        [self refreshFontsForView:subview];
    }
}

@end

