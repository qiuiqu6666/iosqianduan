//telegram @wz662
/**
 * BBS(世界频道)专用的Alarm提示信息UI包装实现类.
 */

#import <Foundation/Foundation.h>
#import "AlarmsViewController.h"
#import "AlarmDto.h"

@interface BBSAlarmUIWrapper : NSObject

- (id)initWith:(AlarmsViewController *)alarmsViewController;

// 进入BBS聊天界面
- (void) gotoBBSChatting;

- (void) refreshSilenceUI;

- (void) onParentViewWillAppear;

- (void) refreshData:(AlarmDto *)data;

// 创建BBS聊天界面中导航栏上自定义静音设置按钮的方法
+ (UIButton *)createCunstomNavigationBunttonForBBSChatting:(UIImage *)btnImg action:(SEL)btnAction target:(nullable id)target;

@end
