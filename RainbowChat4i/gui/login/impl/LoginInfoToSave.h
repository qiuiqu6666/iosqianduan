//telegram @wz662
/**
* 用类用于自动登陆时存储用户的登陆账号信息（除此之外，无其它作用）。
*
* @author Jack Jiang
* @since 6.0
*/

#import <Foundation/Foundation.h>


@interface LoginInfoToSave : NSObject

/** 上次登陆时的登陆账号（也就是uid） */
@property (nonatomic, retain) NSString *loginName;

/**
   * 上次登陆时的登陆密码（明文）。
   *
   * @deprecated since v10.0 该字段暂时由于老版本兼容问题，暂时保留，日后将废弃
   */
@property (nonatomic, retain) NSString *loginPsw;

/**
   * 上次登陆时的登陆密码（密文）。
   * 自动登录提交给服务端时会优先读取loginPswCrypt字段，只有loginPswCrypt为空时才会使用loginPsw字段。
   *
   * @since 10.0
   */
@property (nonatomic, retain) NSString *loginPswCrypt;

/** 是否允许自动登陆（true表示允许，否则不允许） */
@property (nonatomic, assign) BOOL autoLogin;

/** 上次登陆时的手机号码（用于返回用户模式显示） */
@property (nonatomic, retain) NSString *phoneNum;

+ (id)initWith:(NSString *)loginName psw:(NSString *)loginPsw pswCrypt:(NSString *)loginPswCrypt;
+ (id)initWith:(NSString *)loginName psw:(NSString *)loginPsw pswCrypt:(NSString *)loginPswCrypt phone:(NSString *)phoneNum;
+ (NSString *)toJSON:(LoginInfoToSave *)li;
+ (LoginInfoToSave *)fromJSON:(NSString *)json;

@end

