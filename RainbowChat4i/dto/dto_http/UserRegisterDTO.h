//telegram @wz662
/**
 * 用户信息DTO.
 *
 * @author Jack Jiang, 2017-12-19
 * @version 1.0
 */

#import <Foundation/Foundation.h>

@interface UserRegisterDTO : NSObject

/** tYES表示注册信息需要提供手机号、短信验证码（同时服务端的保存注册信息时也会验证手机号和验证码），否则不需要（服务端也不会验证手机号和验证码）。*/
@property (nonatomic, assign) bool neadPhone;
/** 注册手机号 */
@property (nonatomic, retain) NSString *phoneNum;
/** 注册时的短信验证码 */
@property (nonatomic, retain) NSString *phoneSms;

@property (nonatomic, retain) NSString *user_uid;
@property (nonatomic, retain) NSString *user_mail;
@property (nonatomic, retain) NSString *nickname;
@property (nonatomic, retain) NSString *user_psw;
@property (nonatomic, retain) NSString *user_sex;

@end
