//telegram @wz662
#import <Foundation/Foundation.h>

@interface LogoutInfo : NSObject

/** 用户的uid */
@property (nonatomic, retain) NSString *uid;

/**
 * 用于记录用户的登出设备信息，比如手机型号等
 * （本字段主要用于信息记录和传递，非核心字段，可为null） */
@property (nonatomic, retain) NSString *deviceInfo;

/**
 * 设备系统类型.
 * <p>
 * 当前约定：0-Android客户端，1-iOS客户端，2-Web客户端 .
 * <p>
 * 注意：请尽量确保本字段的含义与 {@link LoginInfo2}中的osType字段相同。
 *
 *@deprecated
 */
@property (nonatomic, retain) NSString *osType; // TODO: 本字段以于250514日废弃，日后将删除之！

/**
 * 是否不清除Device token（0-清除，1-不清除，默认清除）。
 * 目前用于iOS端在APP被强杀时，提交注销登陆时可以告诉服务端不需要清除设备id，以便能收到APNs推送。
 *
 * @since 7.1
 */
@property (nonatomic, retain) NSString *dontClearDeviceToken;

@end
