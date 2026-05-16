//telegram @wz662
/**
 * 本类中用来替换原 {@link LoginInfo}类的，因原类里用了login_name、login_psw这样的
 * 字段，在使用JSON跨设备进行数据传输时，就无法反射成功了（跟setLoginName、setLoginPsw无法对应起来哦！）。
 * <p>
 * 封装用户登陆时提交的数据的类.<br>
 * 本类目前仅用于登陆验证时.
 *
 * @author Jack Jiang
 * @version 1.0
 */

#import <Foundation/Foundation.h>

/** 登录类型：密码登录。 @since 10.0 */
#define LOGIN_TYPE_PASSWORD @"0"
  /** 登录类型：手机短信验证码登录。 @since 10.0 */
#define LOGIN_TYPE_SMS      @"1"


@interface LoginInfo2 : NSObject

/**
 * 当客户端的APPKey与服务端允许的APPKey一致时，才允许许登录。
 *
 * @since 7.1
 */
@property (nonatomic, retain) NSString *appKey;

/** 客户端的版本号（ios端为保留字段） */
@property (nonatomic, retain) NSString *clientVersion;


/** 登录方式（默认是密码登录）。 @since 10.0 */
@property (nonatomic, retain) NSString *loginType;
/** 用户登陆名（密码登录时）或 用户手机号（手机短信验证码登录时） */
@property (nonatomic, retain) NSString *loginName;
/** 密码明文（密码登录时）或 手机短信验证码（手机短信验证码登录时） */
@property (nonatomic, retain) NSString *loginPsw;
/** 密码密文(主要用于客户端自动登录时)。 @since 10.0 */
@property (nonatomic, retain) NSString *loginPswCrypt;

/**
 * 用于记录用户的登陆设备信息，比如手机登陆时的手机型号等
 * （本字段主要用于信息记录和传递，非核心字段） */
@property (nonatomic, retain) NSString *deviceInfo;

/**
 * 设备系统类型.
 * <p>
 * 当前约定：0-Android客户端，1-iOS客户端，2-Web客户端 .
 * <p>
 * 注意：请尽量确保本字段的含义与 {@link LogoutInfo}中的osType字段相同。
 *
 *@deprecated
 */
@property (nonatomic, retain) NSString *osType;// TODO: 本字段以于250514日废弃，日后将删除之！

/** 设备标识码：用于唯一标识此设备的id，此体意义由应用层决定（ios端为保留字段） */
@property (nonatomic, retain) NSString *deviceID;

/**
 * 稳定设备标识（可选）。iOS 使用 IDFV，用于新设备判断时优先识别同一设备，减少卸载重装后被误判为新设备。
 * 未传时服务端按 device_token / device_type+device_info 等原逻辑判断。
 * @since 12.0
 */
@property (nonatomic, retain) NSString *hardware_id;

/**
 * 新设备登录时的短信验证码（仅在新设备验证时第二次登录携带）。
 * @since 12.0
 */
@property (nonatomic, retain) NSString *deviceVerifyCode;

/**
 * 是否短信验证码登录。
 */
- (BOOL)isSMSLogin;

@end
