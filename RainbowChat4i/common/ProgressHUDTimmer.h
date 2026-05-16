//telegram @wz662
/**
 * 一个可显示进度提示框的定时器（在开发者指定的时间后通知观察者）。
 *
 * @author JackJiang
 * @since 4.3
 */

#import <Foundation/Foundation.h>

@interface ProgressHUDTimmer : NSObject

@property (nonatomic, assign, getter=isShowing) BOOL showing;

/** 超时回调（观察者） */
@property (nonatomic, copy) ObserverCompletion onTimeoutObserver;// block代码块一定要用copy属性，否则报错！

- (id)initWith:(int)delay contentString:(NSString *)content;

/**
 * 显示进度提示.
 *
 * @param show YES表示马上显示，NO表示取消显示
 */
- (void)showProgressing:(BOOL)show onParent:(UIView *)view;

@end
