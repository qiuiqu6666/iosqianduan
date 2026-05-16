//telegram @wz662
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, NotificationContentType) {
    NotificationContentTypeNotification = 0,  // 通知显示内容
    NotificationContentTypeBanner = 1,         // 横幅显示内容
};

@interface NotificationContentViewController : UIViewController

@property (nonatomic, assign) NotificationContentType contentType;

/** 获取指定类型当前选中的描述文本 */
+ (NSString *)descriptionForContentType:(NotificationContentType)type;

@end
