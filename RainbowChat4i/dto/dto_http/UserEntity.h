//telegram @wz662
/**
 * 用户/好友个人信息封装类。
 * <p>
 * 本类中的大部分字段意义以数据字典中“用户信息/MISSU_USERS”表保持一致。
 *
 * @author Jack Jiang
 * @version 2.0
 */

#import <Foundation/Foundation.h>

/** RainbowChat中约定uid为"-1"表示默认的无效用户uid. */
#define DEFAULT_INVALID_UID_VALUE "-1"

/** 用户在线状态常量：在线 */
#define LIVE_STATUS_ONLINE  1
/** 用户在线状态常量：离线 */
#define LIVE_STATUS_OFFLINE 0

/** 用户性别常量：男 */
#define SEX_MAN   "1"
/** 用户性别常量：女 */
#define SEX_WOMAN "0"


@interface UserEntity : NSObject

/**
 * 当前仅用作为服务端转发加好友请求（给B）时存放验证说明文本使用（包括离线消息）.
 *
 * @since 2.2
 */
// 注意：_ex1这种首字母带下划线的形式，fastjson转json时会忽略此字段！
@property (nonatomic, retain) NSString *ex1;

/**
 * 本字段当前仅用作服务端转发加好友请求（给B）时存放“加好友请求发起时间戳”使用（包括离线时的好友请求）.
 *
 * @since 4.2
 */
@property (nonatomic, retain) NSString *ex10;

/** 保留字段11：留作协议升级时备用，生产环境下备用字段将能在协议升级时起到兼容旧版本的作用。 */
@property (nonatomic, retain) NSString *ex11;
/** 保留字段12：留作协议升级时备用，生产环境下备用字段将能在协议升级时起到兼容旧版本的作用。 */
@property (nonatomic, retain) NSString *ex12;
/** 保留字段13：留作协议升级时备用，生产环境下备用字段将能在协议升级时起到兼容旧版本的作用。 */
@property (nonatomic, retain) NSString *ex13;
/** 保留字段14：留作协议升级时备用，生产环境下备用字段将能在协议升级时起到兼容旧版本的作用。 */
@property (nonatomic, retain) NSString *ex14;
/** 保留字段15：留作协议升级时备用，生产环境下备用字段将能在协议升级时起到兼容旧版本的作用。 */
@property (nonatomic, retain) NSString *ex15;

/**
 * 存放于文件服务器的用户头像文件名。
 * <p>
 * 用户客户端缓存时使用，因为用户头像读取的HTTP服务URL并不是静态地址，而是复杂的动态查询URL，
 * 在缓存文件时就无法通过URL通取到文件名称，所以本参数的作用就是缓存时用于文件名称哦）。
 * <p>
 * 详见数据字典中“用户信息/MISSU_USERS”表的设计说明。
 */
@property (nonatomic, retain) NSString *userAvatarFileName;

/**
 * 存放用户心情（60个字符哦）。
 * <p>
 * 详见数据字典中“用户信息/MISSU_USERS”表的设计说明。
 */
@property (nonatomic, retain) NSString *whatsUp;

/**
 * 存放该用户允许的最多好友个数。
 * <p>
 * 说明：本字段存放的是String表示的整数。详见数据字典中
 * “用户信息/MISSU_USERS”表的设计说明。
 *
 * @since 2.0,
 */
@property (nonatomic, retain) NSString *maxFriend;

/**
 * 存放该用户的个人其它说明文字。
 * <p>
 * 详见数据字典中“用户信息/MISSU_USERS”表的设计说明。
 *
 * @since 2.5
 */
@property (nonatomic, retain) NSString *userDesc;

/**
 * 存放该用户的用户类型（无符号整数）。
 * <p>
 * 本字段目前主要用于区分普通IM用户和公司运营后台用户。具体意义详见
 * 数据字典中表“用户信息/MISSU_USERS”中user_type字段的定义。
 *
 * @since 2.5.1
 */
@property (nonatomic, retain) NSString *userType;

/**
 * 本字段为RainbowChat系统中的用户唯id，是全系统的唯一标识。
 * <p>
 * 无论用户登陆时使用什么（可能是邮件地址、手机号、或者直接像qq一样用唯一id号），
 * 此id在任何情况下都是一个用户的唯一合法身份标识。
 * <p>
 * 为配合RainbowChat升级MobileIMSDK v3时而增加，本对象如果是由登陆接口返回，则将
 * 随后与 {@link #token} 一起在返回到客户端后，分别作为loginUserId和loginToken
 * 来登陆连接IM服务器之用。
 */
@property (nonatomic, retain) NSString *user_uid;
/**
 * 用户的邮箱地址。
 * <p>
 * 详见数据字典中“用户信息/MISSU_USERS”表的设计说明。
 */
@property (nonatomic, retain) NSString *user_mail;

/**
 * 用户的昵称。
 * <p>
 * 详见数据字典中“用户信息/MISSU_USERS”表的设计说明。
 */
@property (nonatomic, retain) NSString *nickname;
/**
 * 用户的性别。
 * <p>
 * 详见数据字典中“用户信息/MISSU_USERS”表的设计说明。
 */
@property (nonatomic, retain) NSString *user_sex;
/**
 * 用户的注册时间。
 * <p>
 * 详见数据字典中“用户信息/MISSU_USERS”表的设计说明。
 */
@property (nonatomic, retain) NSString *register_time;

/**
 * 实际存放的是数据库表missu_users中的latest_login_time2字段。<br>
 * 说明：本字段存放的是Java后台无时区时间戳的String表示的long整数，目的是让此时间在客户端显示为客户所在的时区.
 * <p>
 * 详见数据字典中“用户信息/MISSU_USERS”表的设计说明。
 *
 * @since 2.0
 */
@property (nonatomic, retain) NSString *latest_login_time;

/** 用户的在线状态：0 表示不在线，1 表示在线 */
@property (nonatomic, assign) int liveStatus;

@property (nonatomic, retain) NSString *onlineStartTime;

@property (nonatomic, retain) NSString *offlineTime;

/**
 * <b>用途1：用于IM的连接认证> </b>
 * <p>
 * 为了接下来客户端对接IM即时通讯框架而生成的token，主要用于安全策略，具体生成和使用方法由逻辑层定义。
 * 本字段仅在从登陆接口返回时有意义，其它情况下无意义。
 * <br>
 * 截止20170216日止，本字段暂作保留字段，未来在架构优化和升级和，在服务端性能能得到保证的前提下再启
 * 用此token的验证不迟。
 * <p>
 * 本字段为配合RainbowChat升级MobileIMSDK v3时而增加，将与 {@link #user_uid} 一起在返回到客户端
 * 后，分别作为loginUserId和loginToken来登陆连接IM服务器之用。<br>
 * TODO 为了便于解偶和对接IM实时框架的理解，未来可以考虑将http的登际认证接口独立为SSO单点登陆接口，
 * 而与SSO接口配合使用会让MobileIMSDK v3的理解更为直观和简单。
 * <p>
 * <b>用途2：用于HTTP REST接口调用时的合法身份标识> </b>
 * <p>
 * 基于HTTP REST接口调用的安全考虑，此token建议每次调用rest接口时带上，以便rest服务端检查此次rest
 * 表求的合法性。
 *
 * @since 4.0
 */
@property (nonatomic, retain) NSString *token;

/**
 * 好友备注。
 * <p>
 * <b>注：</b>本字段对应于数据库表“missu_roster”中的“remark”字段（详见数据库字典），
 * 当前仅用于客户端查询当前仅用于客户端查询好友列表数据时使用，其它情况下本字段无意义！
 * @since 7.3
 */
@property (nonatomic, retain) NSString *friendRemark;
/**
 * 好友手机号。
 * <p>
 * <b>注：</b>本字段对应于数据库表“missu_roster”中的“mobile_num”字段（详见数据库字典），
 * 当前仅用于客户端查询当前仅用于客户端查询好友列表数据时使用，其它情况下本字段无意义！
 * @since 7.3
 */
@property (nonatomic, retain) NSString *friendMobileNum;
/**
 * 好友更多描述。
 * <p>
 * <b>注：</b>本字段对应于数据库表“missu_roster”中的“more_desc”字段（详见数据库字典），
 * 当前仅用于客户端查询当前仅用于客户端查询好友列表数据时使用，其它情况下本字段无意义！
 * @since 7.3
 */
@property (nonatomic, retain) NSString *friendMoreDesc;
/**
 * 好友相关图片、名片（存放的是文件名，详见数据库字典中的字段说明） 。
 * <p>
 * <b>注：</b>本字段对应于数据库表“missu_roster”中的“pic_file_name”字段（详见数据库字典），
 * 当前仅用于客户端查询当前仅用于客户端查询好友列表数据时使用，其它情况下本字段无意义！
 * @since 7.3
 */
@property (nonatomic, retain) NSString *friendPicFileName;

/**
 * 是否星标好友。对应 missu_roster.is_starred，接口 1008-2-7 返回。
 * "0" 未星标，"1" 已星标。仅好友列表数据时有意义。
 */
@property (nonatomic, retain) NSString *is_starred;

/**
 * 用户的密码文密码，当前用于登录认证时，其它情况为nil。
 *
 * @since 10.0
 */
@property (nonatomic, retain) NSString *userPsw;

/**
 * 用户的注册手机号，当前用于登录认证时，其它情况为nil。
 *
 * @since 10.0
 */
@property (nonatomic, retain) NSString *phoneNum;

/**
 * 获取好友的备注昵称，当设置了好友备注时则返回的是备注，否则返回的是原昵称。
 *
 * @return 返回好友备注优先的昵称
 * @see #friendRemark
 * @see #nickname
 */
- (NSString *)getNickNameWithRemark;

/**
 * 用户上线设定方便方法.<br>
 * 通过此方法可同时实现设置用户在线状态.
 *
 * @see #setUser_id(int)
 * @see #setLiveStatus(int)
 */
- (void)online;

/**
 * 用户下线设定方便方法.<br>
 * 通过此方法可同时实现设置用户在线状态.
 *
 * @see #setUser_id(int)
 * @see #setLiveStatus(int)
 */
- (void)offline;

- (void)updateLiveStatus:(int)liveStatus;

/**
 * 是否在线.
 *
 * @return
 */
- (BOOL)isOnline;

/**
 * 该用户是否男性.
 *
 * @return true表示男性，否则表示女性
 */
- (BOOL)isMan;

/**
 * RosterElementEntity 深度对象克隆方法实现。
 *
 * @return 克隆完成后的新对象
 * @since 4.0, 20171116
 */
- (UserEntity *)clone;

/**
 将服务端的保存的最近登陆时间（是Java服务端生成的无时区时间戳长整数）转成iOS上的本地时区时间字符串（解决此时间在跨国用户的客户端显示问题）.

 @return 本地时区的时间字符串
 */
- (NSString *)getLatestLoginTimeStr;

@end
