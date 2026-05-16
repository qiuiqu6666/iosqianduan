#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 年月选择器弹层，供钱包首页、账单记录页等复用
@interface MonthYearPickerHelper : NSObject

/// 在指定视图中弹出年月选择器
/// @param view 承载 overlay 的视图（一般为 self.view）
/// @param currentDate 当前选中的日期（仅取年、月）
/// @param minYear 年份范围起始年（含）
/// @param completion 用户点击「确定」时回调选中的日期（仅年月有效，日为1）；点击「取消」或点击空白关闭时传 nil
+ (void)showInView:(UIView *)view
       currentDate:(NSDate *)currentDate
           minYear:(NSInteger)minYear
        completion:(void(^)(NSDate * _Nullable selectedDate))completion;

@end

NS_ASSUME_NONNULL_END
