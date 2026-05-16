#import "MonthYearPickerHelper.h"
#import <objc/runtime.h>

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static const void *kMonthYearPickerHelperKey = &kMonthYearPickerHelperKey;

@interface MonthYearPickerHelper () <UIPickerViewDataSource, UIPickerViewDelegate>
@property (nonatomic, strong) UIView *overlay;
@property (nonatomic, strong) UIPickerView *picker;
@property (nonatomic, strong) NSArray<NSNumber *> *years;
@property (nonatomic, strong) NSArray<NSNumber *> *months;
@property (nonatomic, copy) void (^completion)(NSDate * _Nullable);
@end

@implementation MonthYearPickerHelper

+ (void)showInView:(UIView *)view
       currentDate:(NSDate *)currentDate
           minYear:(NSInteger)minYear
        completion:(void (^)(NSDate * _Nullable))completion
{
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comp = [cal components:NSCalendarUnitYear | NSCalendarUnitMonth fromDate:currentDate];
    NSInteger currentYear = [cal component:NSCalendarUnitYear fromDate:[NSDate date]];
    NSMutableArray<NSNumber *> *years = [NSMutableArray array];
    for (NSInteger y = minYear; y <= currentYear; y++) [years addObject:@(y)];
    NSMutableArray<NSNumber *> *months = [NSMutableArray array];
    for (NSInteger m = 1; m <= 12; m++) [months addObject:@(m)];

    MonthYearPickerHelper *helper = [[MonthYearPickerHelper alloc] init];
    helper.years = years;
    helper.months = months;
    helper.completion = completion;

    UIView *overlay = [[UIView alloc] initWithFrame:view.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    [view addSubview:overlay];
    helper.overlay = overlay;
    objc_setAssociatedObject(overlay, kMonthYearPickerHelperKey, helper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    CGFloat panelH = 260.f;
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) safeBottom = view.safeAreaInsets.bottom;
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(0, view.bounds.size.height - panelH - safeBottom, view.bounds.size.width, panelH + safeBottom)];
    panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    panel.backgroundColor = [UIColor whiteColor];
    [overlay addSubview:panel];

    UITapGestureRecognizer *tapDismiss = [[UITapGestureRecognizer alloc] initWithTarget:helper action:@selector(dismissWithCancel)];
    [overlay addGestureRecognizer:tapDismiss];

    CGFloat toolH = 44.f;
    UIView *toolbar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panel.bounds.size.width, toolH)];
    toolbar.backgroundColor = HexColor(0xF5F5F5);
    [panel addSubview:toolbar];

    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelBtn setTitle:@"取消" forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [cancelBtn addTarget:helper action:@selector(dismissWithCancel) forControlEvents:UIControlEventTouchUpInside];
    cancelBtn.frame = CGRectMake(16, 0, 60, toolH);
    [toolbar addSubview:cancelBtn];

    UIButton *doneBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [doneBtn setTitle:@"确定" forState:UIControlStateNormal];
    doneBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    doneBtn.tintColor = HexColor(0x07C160);
    doneBtn.frame = CGRectMake(panel.bounds.size.width - 76, 0, 60, toolH);
    [doneBtn addTarget:helper action:@selector(dismissWithDone) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:doneBtn];

    UIPickerView *picker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, toolH, panel.bounds.size.width, panelH - toolH)];
    picker.dataSource = helper;
    picker.delegate = helper;
    picker.backgroundColor = [UIColor whiteColor];
    [panel addSubview:picker];
    helper.picker = picker;

    NSInteger yearIdx = 0;
    for (NSInteger i = 0; i < years.count; i++) {
        if ([years[i] integerValue] == comp.year) { yearIdx = i; break; }
    }
    NSInteger monthIdx = (comp.month - 1);
    if (monthIdx < 0) monthIdx = 0;
    if (monthIdx > 11) monthIdx = 11;
    [picker selectRow:yearIdx inComponent:0 animated:NO];
    [picker selectRow:monthIdx inComponent:1 animated:NO];
}

- (void)dismissWithCancel
{
    if (self.completion) self.completion(nil);
    [self removeOverlay];
}

- (void)dismissWithDone
{
    UIPickerView *picker = self.picker;
    if (picker && self.years.count && self.months.count) {
        NSInteger yearIdx = [picker selectedRowInComponent:0];
        NSInteger monthIdx = [picker selectedRowInComponent:1];
        if (yearIdx < 0 || yearIdx >= (NSInteger)self.years.count) yearIdx = 0;
        if (monthIdx < 0 || monthIdx >= (NSInteger)self.months.count) monthIdx = 0;
        NSInteger year = [self.years[yearIdx] integerValue];
        NSInteger month = [self.months[monthIdx] integerValue];
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDateComponents *comp = [[NSDateComponents alloc] init];
        comp.year = year;
        comp.month = month;
        comp.day = 1;
        NSDate *date = [cal dateFromComponents:comp];
        if (date && self.completion) self.completion(date);
    } else if (self.completion) {
        self.completion(nil);
    }
    [self removeOverlay];
}

- (void)removeOverlay
{
    [self.overlay removeFromSuperview];
    objc_setAssociatedObject(self.overlay, kMonthYearPickerHelperKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.overlay = nil;
    self.completion = nil;
}

#pragma mark - UIPickerViewDataSource / UIPickerViewDelegate

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView { return 2; }

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if (component == 0) return self.years.count;
    return self.months.count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    if (component == 0 && row < (NSInteger)self.years.count)
        return [NSString stringWithFormat:@"%@年", self.years[row]];
    if (component == 1 && row < (NSInteger)self.months.count)
        return [NSString stringWithFormat:@"%@月", self.months[row]];
    return @"";
}

@end
