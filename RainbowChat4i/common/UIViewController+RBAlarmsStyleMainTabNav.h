//
//  UIViewController+RBAlarmsStyleMainTabNav.h
//  主 Tab 根页顶栏：与 AlarmsViewController「消息」列表同款（厚材质模糊底 + 左侧大标题 + 右侧搜索/加号胶囊）。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (RBAlarmsStyleMainTabNav)

/// 已安装则返回顶栏容器，否则 nil
- (nullable UIView *)rb_alarmsStyleMainTabNavigationBarIfInstalled;

/// 安装与消息页一致的顶栏（加号点按 `doMores:`）
- (void)rb_installAlarmsStyleMainTabNavigationBarWithLocalizedTitleKey:(NSString *)key;

/// 安装与消息页一致的顶栏。`addButtonMenu` 非空且 iOS 14+ 时用于加号 `UIButton.menu`；否则点按走 `doMores:`
- (void)rb_installAlarmsStyleMainTabNavigationBarWithLocalizedTitleKey:(NSString *)key
                                                       addButtonMenu:(nullable UIMenu *)addButtonMenu;

- (void)rb_alarmsStyleMainTabNavHostViewWillAppear:(BOOL)animated;
- (void)rb_alarmsStyleMainTabNavHostViewDidAppear:(BOOL)animated;
- (void)rb_alarmsStyleMainTabNavHostViewWillDisappear:(BOOL)animated;
/// 在 `viewDidLayoutSubviews` 末尾调用：更新顶栏高度、渐变遮罩与 iOS11～14 水平边距
- (void)rb_alarmsStyleMainTabNavHostViewDidLayoutSubviews;

@end

NS_ASSUME_NONNULL_END
