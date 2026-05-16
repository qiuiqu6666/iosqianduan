//telegram @wz662
/**
 * 指令body：群聊时，向所有除修改者的群员通知群名被修改的通知协议内容.
 *
 * @author Jack Jiang
 * @since 4.3
 */

#import <Foundation/Foundation.h>

@interface CMDBody4GroupNameChangedNotification : NSObject

@property (nonatomic, retain) NSString *changedByUid;
@property (nonatomic, retain) NSString *nnewGroupName;
@property (nonatomic, retain) NSString *notificationContent;
@property (nonatomic, retain) NSString *gid;

@end
