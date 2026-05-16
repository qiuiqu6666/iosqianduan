//telegram @wz662
#ifndef RB_Default_h
#define RB_Default_h


//------------------------------------------------------------------
#pragma mark - 一些常的 iOS APP 实用方法

// 为日志添加函数名、代码行号的宏定义
#define DLogError(fmt, ...) DDLogError((@"👉%s [Line %d]👈 " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#define DLogWarn(fmt, ...) DDLogWarn((@"👉%s [Line %d]👈 " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#define DLogInfo(fmt, ...) DDLogInfo((@"👉%s [Line %d]👈 " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#define DLogDebug(fmt, ...) DDLogDebug((@"👉%s [Line %d]👈 " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#define DLogVerbose(fmt, ...) DDLogVerbose((@"👉%s [Line %d]👈 " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

#define ScreenWidth     [UIScreen mainScreen].bounds.size.width
#define ScreenHeight    [UIScreen mainScreen].bounds.size.height

#define iOS11AndLater   ([UIDevice currentDevice].systemVersion.floatValue >= 11.0f)

// 判读NSString 是否为空的安全方法(比如很多情况下，服务端的http接口会返回null字段，而到ios端可能会被解析成@"null"字符串)
#define Obj_IS_NIL(s)   ( s == nil || [s isKindOfClass:[NSNull class]] || [s isEqualToString:@"null"])

// @deprecated by [BasicTool showAlert:]
#define Alert(title,content,btnTitle) [[[UIAlertView alloc] initWithTitle:title \
                                                                  message:content\
                                                                 delegate:nil\
                                                        cancelButtonTitle:btnTitle\
                                                        otherButtonTitles:nil] show];
// @deprecated by [BasicTool showAlertInfo:]
#define AlertInfo(content) Alert(NSLocalizedString(@"general_tip", @""), content, NSLocalizedString(@"general_confirm_btn", @""))
// @deprecated by [BasicTool showAlertError:]
#define AlertError(content) Alert(NSLocalizedString(@"general_error", @""), content, NSLocalizedString(@"general_confirm_btn", @""))

#define APP      ((AppDelegate*)[[UIApplication sharedApplication] delegate])
#define APP_NAME ([[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"])

// RGB进制颜色值
#define RGBCOLOR(r,g,b)  [UIColor colorWithRed:(r)/255.0f green:(g)/255.0f blue:(b)/255.0f alpha:1]
#define RGBACOLOR(r,g,b,a)  [UIColor colorWithRed:(r)/255.0f green:(g)/255.0f blue:(b)/255.0f alpha:(a)/255.0f]
// 16进制颜色值，如：#000000 , 注意：在使用的时候hexValue写成：0x000000
#define HexColor(hexValue) [UIColor colorWithRed:((float)(((hexValue) & 0xFF0000) >> 16))/255.0 green:((float)(((hexValue) & 0xFF00) >> 8))/255.0 blue:((float)((hexValue) & 0xFF))/255.0 alpha:1.0]


//------------------------------------------------------------------
#pragma mark - APP的服务器根地址配置

#define APPKey @"85324d6c2fdfa4cf4ebc42fe9c4ddf28" // 交付

// ** HTTP rest接口服务根地址（HTTPS地址则请保证服务端的证书是合法可用的）
#define  HTTP_SERVER_URL    @"http://47.83.125.166:8081/rainbowchat_pro/"  // TODO: 此项配置改为您自已的 http 服务器ip/域名和端口号即可！
//#define  HTTP_SERVER_URL  @"https://192.168.0.112:8443/rainbowchat_pro/" // TODO: 此项配置改为您自已的 https 服务器ip/域名和端口号即可！

// ** IM服务器IP地址（主地址，同时作为多IP列表的第一个）
#define  IM_SERVER_IP       @"47.83.125.166"                              // TODO: 此项配置改为您自已的IM服务器ip或域名即可！

// ** IM服务器端口
#define  IM_SERVER_PORT     9903                                          // TODO: 此项配置改为您自已的IM服务器端口即可（如没改过服务端j监听端口，请保持此默认勿改）！

// ** IM服务器候选IP列表（多IP轮询容灾）
// 当主IP连接失败时，将自动尝试列表中的下一个IP地址。
// 建议配置2~3个不同机房/区域的IP以实现高可用。
// TODO: 请将以下IP替换为您自己的IM服务器地址列表！
#define  IM_SERVER_IP_LIST  @[IM_SERVER_IP]


//------------------------------------------------------------------
#pragma mark - 基本数据接口服务URL链接配置

// ** HTTP rest 普通数据接口服务的统一调用地址（普通数据指的是除图片等2进制文件上传下载外的文本数据）
#define HTTP_SERVER_REST_URL                            HTTP_SERVER_URL@"rest_post"

// ** HTTP Rest用户2进制数据下载的独立http接口地址
#define BBONERAY_DOWNLOAD_CONTROLLER_URL_ROOT           HTTP_SERVER_URL@"BinaryDownloader"
// ** HTTP Rest 图片消息的图片文件上传的独立http接口地址
#define MSG_IMG_UPLODER_URL_ROOT                        HTTP_SERVER_URL@"MsgImageUploader"
// ** HTTP Rest 语音留言消息的语音文件上传的独立http接口地址
#define MSG_VOICE_UPLODER_URL_ROOT                      HTTP_SERVER_URL@"MsgVoiceUploader"

// ** 用户头像上传的独立http接口地址
#define AVATAR_UPLOAD_CONTROLLER_URL_ROOT               HTTP_SERVER_URL@"UserAvatarUploader"
// ** 用户头像下载的独立http接口地址
#define AVATAR_DOWNLOAD_CONTROLLER_URL_ROOT             HTTP_SERVER_URL@"UserAvatarDownloader"

// ** 用户照片上传的独立http接口地址
#define MY_PHOTO_UPLOAD_CONTROLLER_URL_ROOT             HTTP_SERVER_URL@"MyPhotoUploder"
/** 手机相册上传（按 UID 分目录 + OSS）；Query 须带 user_uid，与文档 3.0 一致 */
#define PHONE_ALBUM_UPLOAD_CONTROLLER_URL_ROOT          HTTP_SERVER_URL@"PhoneAlbumUploader"
// ** 用户语音介绍上传的独立http接口地址
#define MY_VOICE_UPLOAD_CONTROLLER_URL_ROOT             HTTP_SERVER_URL@"MyVoiceUploader"

/** 用户大文件上传的独立http接口地址 */
#define BIG_FILE_UPLOADER_CONTROLLER_URL_ROOT           HTTP_SERVER_URL@"BigFileUploader"
/** 用户大文件下载的独立http接口地址 */
#define BIG_FILE_DOWNLOADER_CONTROLLER_URL_ROOT         HTTP_SERVER_URL@"BigFileDownloader"

/** 用户短视频消息的视频文件上传的独立http接口地址 */
#define SHORTVIDEO_UPLOADER_CONTROLLER_URL_ROOT         HTTP_SERVER_URL@"ShortVideoUploader"
/** 用户短视频消息的视频文件下载的独立http接口地址 */
#define SHORTVIDEO_DOWNLOADER_CONTROLLER_URL_ROOT       HTTP_SERVER_URL@"ShortVideoDownloader"

/** 用户短视频消息的视频首帧预览图片文件上传的独立http接口地址 */
#define SHORTVIDEO_THUMB_UPLOADER_CONTROLLER_URL_ROOT   HTTP_SERVER_URL@"ShortVideoThumbUploader"
/** 用户短视频消息的视频首帧预览图片文件下载的独立http接口地址 */
#define SHORTVIDEO_THUMB_DOWNLOADER_CONTROLLER_URL_ROOT HTTP_SERVER_URL@"ShortVideoThumbDownloader"

/** 用户位置消息的地图预览图片文件上传的独立http接口地址 */
#define LOCATION_PREVIEW_UPLOADER_CONTROLLER_URL_ROOT   HTTP_SERVER_URL@"LocationPreviewUploader"

/** 自定义表情上传的独立http接口地址 */
#define STICKER_UPLOADER_CONTROLLER_URL_ROOT            HTTP_SERVER_URL@"StickerUploader"
/** 自定义表情下载的独立http接口地址（通过 BinaryDownloader?action=sticker_d） */
#define STICKER_DOWNLOADER_CONTROLLER_URL_ROOT          BBONERAY_DOWNLOAD_CONTROLLER_URL_ROOT


//------------------------------------------------------------------
#pragma mark - 次要功能的网页URL链接配置

// ** 关于我们：隐私申明链接（英文版）
#define  RBCHAT_PRIVACY_EN_URL                HTTP_SERVER_URL@"clause/privacy_cn.html"
// ** 关于我们：隐私申明链接（中文版）
#define  RBCHAT_PRIVACY_CN_URL                HTTP_SERVER_URL@"clause/privacy_cn.html"

// ** 关于我们：服务条款链接（英文版）
#define  RBCHAT_REGISTER_AGREEMENT_EN_URL     HTTP_SERVER_URL@"clause/agreement_cn.html"
// ** 关于我们：服务条款链接（中文版）
#define  RBCHAT_REGISTER_AGREEMENT_CN_URL     HTTP_SERVER_URL@"clause/agreement_cn.html"

/** 关于我们：FAQ 链接（中文版） */
#define  RBCHAT_QNA_CN_URL                    HTTP_SERVER_URL@"/clause/qna_cn.html?v=6"
/** 关于我们：FAQ 链接（英文版） */
#define  RBCHAT_QNA_EN_URL                    HTTP_SERVER_URL@"/clause/qna.html"

/** 帮助中心链接 */
#define  RBCHAT_HELP_CN_URL                   HTTP_SERVER_URL@"clause/help_cn.html"

/** 关于我们：官网链接（「分享应用」与此一致） */
#define  RBCHAT_OFFICAL_WEBSITE               @"https://www.jingliaochat.com"
/** 关于我们：联系邮件 */
#define  RBCHAT_OFFICAL_MAIL                  @"admin@jlchat.app"


//------------------------------------------------------------------
#pragma mark - 声网(Agora)音视频SDK配置

/** 声网(Agora)的AppId，请在声网控制台(https://console.agora.io/)创建项目后获取。
 * 若服务端 Token 接口返回 app_id，客户端会以服务端为准创建引擎；此处应与线上一致，否则呼出预览阶段会先用到错误 AppId，接通后会自动切换。 */
#define AGORA_APP_ID    @"9746973ab1dd42f7807562d10fc33640"

/** 音视频呼叫超时时间（单位：秒），超时后自动取消呼叫 */
#define VOIP_CALL_TIMEOUT_SECONDS   30

/** 声网Token请求的HTTP REST接口actionId（接口编号 1008-1-35） */
#define ACTION_AGORA_TOKEN          35

/** 上传VoIP PushKit Token的HTTP REST接口actionId（接口编号 1008-1-36） */
#define ACTION_UPLOAD_VOIP_TOKEN    36

/** 上报个推(GeTui) CID 的HTTP REST接口actionId（接口编号 1008-1-37） */
#define ACTION_UPLOAD_GETUI_CID     37

/** SyncKey 增量拉取离线消息的HTTP REST接口actionId（接口编号 1008-4-27） */
#define ACTION_SYNCKEY_PULL         ACTION_APPEND9    // = 27

/** SyncKey 确认同步点的HTTP REST接口actionId（接口编号 1008-4-28） */
#define ACTION_SYNCKEY_CONFIRM      ACTION_APPEND10   // = 28

/** 群聊已读回执统计的HTTP REST接口actionId（接口编号 1008-4-29） */
#define ACTION_GROUP_READ_STATS     ACTION_APPEND11   // = 29

/** 独立拉取状态同步日志的HTTP REST接口actionId（接口编号 1008-4-30） */
#define ACTION_STATE_SYNC_LOG       ACTION_APPEND12   // = 30

/** 单聊通话记录聚合的HTTP REST接口actionId（接口编号 1008-4-32） */
#define ACTION_CALL_RECORDS_AGG    ACTION_APPEND14   // = 32

/** 删除单条通话记录（标记不显示）的HTTP REST接口actionId（接口编号 1008-4-37） */
#define ACTION_DELETE_CALL_RECORD  37

/** 会话消息免打扰设置的HTTP REST接口actionId（接口编号 1008-4-38，JOB_LOGIC_MESSAGES） */
#define ACTION_CONVERSATION_MSG_MUTE  38


//------------------------------------------------------------------
#pragma mark - 高德地图appkey配置

/** 高德地图的ios平台appkey设置，参见：https://lbs.amap.com/api/android-location-sdk/guide/create-project/get-key */
#define GAODE_APP_KEY                         @"e9fb2370b13495ef389da186986f3aab"
/** 高德地图的Web服务appkey设置，参见：https://lbs.amap.com/api/webservice/guide/create-project/get-key */
#define GAODE_WEBSERVICE_KEY                  @"33fe08cfd078927a6dcbe9d91d3008e0"


//------------------------------------------------------------------
#pragma mark - 聊天功能本地发出的消息图片、语音留言文件操作、sqlite操作等的默认配置

#define DIR_KCHAT_WORK_RELATIVE_ROOT          @"/rainbowchat_pro"
/** 用户头像缓存目录 */
#define DIR_KCHAT_AVATART_RELATIVE_DIR        DIR_KCHAT_WORK_RELATIVE_ROOT@"/avatar"
/* 聊天图片缓存目录 */
#define DIR_KCHAT_SENDPIC_RELATIVE_DIR        DIR_KCHAT_WORK_RELATIVE_ROOT@"/image"
/* 聊天时的语音留言缓存目录 */
#define DIR_KCHAT_SENDVOICE_RELATIVE_DIR      DIR_KCHAT_WORK_RELATIVE_ROOT@"/voice"
/** 照片缓存目录 */
#define DIR_KCHAT_PHOTO_RELATIVE_DIR          DIR_KCHAT_WORK_RELATIVE_ROOT@"/photo"
/** 手机相册（待上传/本地压缩缓存）目录，与「个人介绍相册」缓存分离 */
#define DIR_KCHAT_PHONE_ALBUM_RELATIVE_DIR    DIR_KCHAT_WORK_RELATIVE_ROOT@"/phone_album"

/** 【接口1008-10-9 / 10-7】res_type：个人介绍相册照片 */
#define PROFILE_REST_RES_TYPE_PROFILE_PHOTO       0
/** 【接口1008-10-9 / 10-7】res_type：手机相册（需服务端在同套接口中支持） */
#define PROFILE_REST_RES_TYPE_PHONE_ALBUM         2
/** 自我介绍语音缓存目录 */
#define DIR_KCHAT_PVOICE_RELATIVE_DIR         DIR_KCHAT_WORK_RELATIVE_ROOT@"/pvoice"
/** 收到的大文件保存目录 */
#define DIR_KCHAT_FILE_RELATIVE_DIR           DIR_KCHAT_WORK_RELATIVE_ROOT@"/file"
/** 收到的短视频保存目录 */
#define DIR_KCHAT_SHORTVIDEO_RELATIVE_DIR     DIR_KCHAT_WORK_RELATIVE_ROOT@"/shortvideo"
/** 收到的位置消息，地图预览图保存目录 */
#define DIR_KCHAT_LOCATION_RELATIVE_DIR       DIR_KCHAT_WORK_RELATIVE_ROOT@"/location"

/** 用户上传头像时，允许的最大用户头像文件大小 */
#define LOCAL_AVATAR_FILE_DATA_MAX_LENGTH     2 * 1024 * 1024 // 2M
/** 用户上传头像时，图片质量压缩比率（0~1.0的量，0表示最大压缩，1.0表不压缩，默认0.75是参考微信的压缩率） */
#define LOCAL_AVATAR_IMAGE_QUALITY            0.75              // 75%质量
/** 用户上传头像的图像尺寸（微信的也是这个大小） */
#define LOCAL_AVATAR_SIZE                     640

/** 用户发送的图片文件，允许的最大文件大小 */
#define LOCAL_IMAGE_FILE_DATA_MAX_LENGTH      2 * 1024 * 1024 // 2M
/** 用户发送的语音留言文件，允许的最大文件大小 */
#define LOCAL_VOICE_FILE_DATA_MAX_LENGTH      1 * 1024 * 1024 // 1M
/** 用户发送的语音留言录音最大时长(单位：秒) */
#define LOCAL_VOICE_AUDIO_LENGTH              120
/** 图片消息的图片压缩质量（0~1.0的量，0表最大压缩，1.0表不压缩，默认0.75是参考微信的压缩率），改变此值将影响发送的图片文件大小、显示清晰度 */
#define LOCAL_IMAGE_FILE_COMPRESS_QUALITY     0.75
/** 图片消息的图片缩放最大尺寸，改变此值将影要发送的图片文件大小 */
#define LOCAL_IMAGE_FILE_COMPRESS_MAX_WIDTH   1000

/** 用户上传的个人相册照片图片压缩质量（0~1.0的量，0表最大压缩，1.0表不压缩，默认0.75是参考微信的压缩率），改变此值将影响发送的图片文件大小、显示清晰度 */
#define LOCAL_PHOTO_FILE_COMPRESS_QUALITY     0.75
/** 用户上传的个人相册照片图片缩放最大尺寸，改变此值将影要发送的图片文件大小 */
#define LOCAL_PHOTO_FILE_COMPRESS_MAX_WIDTH   1000

/** 用户上传的个人相册照片文件，允许的最大文件大小 */
#define LOCAL_PHOTO_FILE_DATA_MAX_LENGTH      3 * 1024 * 1024  // 3M
/** 用户上传的自我介绍语音留言文件，允许的最大文件大小 */
#define LOCAL_PVOICE_FILE_DATA_MAX_LENGTH     1 * 1024 * 1024  // 1M
/** 用户上传的自我介绍语音留言录音最大时长(单位：秒) */
#define LOCAL_PVOICE_AUDIO_LENGTH             60

/** SQLite本地存储：正式聊天消息的保存周期(目前是保存7天内的聊天消息，早于此消息的将被自动清除：始终保持安全性和防止存储空间的堆积) */
// 自v10.0开始，由于已在聊天界面启用分页加载机制，自动清除逻辑或可弃用，日后可以考虑删除对应的实现代码吧！
#define SQLITE_CHAT_MESSAGE_SOTRE_RANGE       365//7

/** 用户发送的文件，允许的最大文件大小 */
// TODO: 目前最大25M是参考微信的设定。实际上如果必要，此值可设为你需要的数值（比如100M或1G等，就看你服务器多牛了^_^!）
#define SEND_FILE_DATA_MAX_LENGTH             25 * 1024 * 1024 // 25MB

/** 用户发送的短视频，允许的最长录制时间(单位：秒) */
// TODO: 目前最大10秒是参考微信的设定。实际上如果必要，此值可设为你需要的数值（比如易信的3分钟!）
#define SHORT_VIDEO_RECORD_MAX_TIME           10
/** 用户发送的短视频，允许的最大文件大小 */
#define SEND_SHORT_VIDEO_DATA_MAX_LENGTH      50 * 1024 * 1024 // 50MB
/** 用户发送的短视频首帧图片压缩质量（0~1.0的量，0表最大压缩，1.0表不压缩，默认0.75是参考微信的压缩率），改变此值将影响发送的图片文件大小、显示清晰度 */
#define SHORT_VIDEO_FIRST_COMPRESS_QUALITY    0.75
/** 用户发送的短视频首帧图片缩放最大尺寸，改变此值将影要发送的图片文件大小 */
#define SHORT_VIDEO_FIRST_COMPRESS_MAX_WIDTH  300

/** 聊天界面中，消息的显示时间间隔（单位：秒）：默认是2分钟内的消息只在第一条消息上显示时间，否则会再次显示时间 */
// 参考资料：http://www.52im.net/thread-3008-1-1.html#40
#define CHATTING_MESSAGE_SHOW_TIME_INTERVAL   2 * 60

/** 消息可被撤回的最大时限（单位：分钟），默认值是2。 */
#define CHATTING_MESSAGE_CAN_BE_REVOKE_TIME   1

/** 单次从 SQLite / 漫游拉取条数（一页大小）；会话内可多次上拉叠加，不在内存中强制裁回该数值（退出会话时 clear）。 */
#define CHATTING_MESSAGE_WINDOW_MAX           200

/** SQLite 分页每次读取条数（进入会话首屏 loadHistory、上拉加载更早一页均用 ChatHistoryTable/GroupChatHistoryTable 的 LIMIT）。值越大首屏越容易卡顿；值越小则更依赖上滑分页加载。 */
#define CHATTING_MESSAGE_LOAD_ONECE           20

/** 登录后 1008-26-7 成功：按会话调用 1008-26-8 预拉最近条数（每会话一次 HTTP，替代登录首轮 4-27 增量正文）。 */
#define RB_LOGIN_PREFETCH_HISTORY_ROW_COUNT   40

/**
 * 单机、无多端漫游：以本地 SQLite 为会话与历史正文主数据源；登录/重连后走 HTTP 1008-2-7、1016-25-7、1008-4-7、
 * 1008-4-8（循环至空）+ IM 实时。
 */
#ifndef RB_SINGLE_DEVICE_NO_ROAMING
#define RB_SINGLE_DEVICE_NO_ROAMING            1
#endif
#define RB_CHAT_PAGE_DB_ONLY                  1
#define RB_DISABLE_GAPHEAL_TAIL_ROAMING       1

#define RB_SYNCKEY_FAST_BOOTSTRAP_WINDOW_COLLECTID  20000
#define RB_SYNCKEY_BACKFILL_PAGE_SIZE               500

/** 内存条数已达到至少一页时：可视区「最旧一行」索引小于该值即从本地预取更早一页 */
#define CHATTING_MESSAGE_PREFETCH_OLDEST_VISIBLE_INDEX_MAX   28


//------------------------------------------------------------------
#pragma mark - APP的NSNotificationCenter的全局key定义

/* 首页的“消息”通知未读总数变动通知（首页“消息”页面其实已经增加了观察者到“消息”通知数据模型里，但数据模型只能通知道到关于数据的新增、删除、替换，而像
 重置对象里的未读数这样的行为（如进入聊天界面时）是没有办法细化到此粒度的，所以此时在进入聊天界面中重置该好友的未读数时，尝试手动发出此通知，使得首页“消息”
 Tab上的未读数气泡能及时刷新为最新，不然tab上的未读数就不同步了） */
#define kNotificationCenter_For_Refresh_TotalUnread         @"__NC_For_Refresh_TotalUnread__"
/** 注册成功界面回来时（用于通知登陆界面显示刚才注册成功的用户名的密码，这样用户注册完就不用重复输入了） */
#define kNotificationCenter_For_Register_Sucess_Back        @"__NC_For_Register_Sucess_Back__"
/** 好友请求处理界面回来时（用于通知前一个界面——即未处理验证通知列表界面中清除掉本条已处理完成的请求(而不需要再次从网络加载列表数据，提升体验）） */
#define kNotificationCenter_For_ProcessCompleteFriendReq    @"__NC_For_ProcessCompleteFriendReq__"
/** 重置群组头像缓存:用于保证本地影响群头像生成的操作，能在其它UI界面中及时将群头像刷新为最新，因为删除群员、邀请群员等
 操作会在服务端重新生成群头像，此广播就是以低耦合的方式实现本地聊头像UI刷新的通知，如果没有此通知则因为其它UI界面中为了
 提高性能而已缓存了的老的群头像，将不会得到及时更新，直到重启APP吧). */
#define kNotificationCenter_For_ResetGroupAvatarCache       @"__NC_For_ResetGroupAvatarCache__"
/** 退群(作为普通群员时)或解散群(作为群主时)时，通知群聊界面，以便群聊界面在收到通知后能自动关闭（因为已不在此群或群已不存在了嘛）
        （补充说明：目前退群或解散群是在群信息查看界面中操作，而群信息查看界面是从群聊天界面进入的）*/
#define kNotificationCenter_For_QuitOrDismissGroupComplete  @"__NC_For_QuitOrDismissGroupComplete__"
/** 拉黑用户时，通知前面的界面，以便之前界面在收到通知后能自动关闭（比如跟此人的聊天界面，因已拉黑，跟它的聊天界面就没必要显示了嘛）
 （补充说明：目前此通知主要用于从聊天界面进入到此人的信息查看界面中进行拉黑操作时，从而让聊天界面能自动关闭，不然体验就有点怪异了）*/
#define kNotificationCenter_For_BlockUserComplete           @"__NC_For_BlockUserComplete__"
/** 短视频录制成功结束回来时（用于通知前一个界面——继续进行短视频的文件上传等后续处理) */
#define kNotificationCenter_For_RecordCompleteShortVideo    @"__NC_For_RecordCompleteShortVideo__"
/** 消息"撤回"功能中当收到撤回指令的应答时通知UI界面进行相应处理 */
#define kNotificationCenter_For_RevokeCMDRecieved           @"__NC_For_RevokeCMDRecieved__"
/** 修改完成好友的备注后通知UI界面进行相应处理 */
#define kNotificationCenter_For_FriendRemarkChanged         @"__NC_For_FriendRemarkChanged__"
/** 收到群主修改群名称后通知UI界面进行相应处理 */
#define kNotificationCenter_For_GroupNameChanged            @"__NC_For_GroupNameChanged__"


//------------------------------------------------------------------
#pragma mark - 其它全局变量宏定义

/** 各界面统一的默认背景色（当前为白色） */
#define UI_DEFAULT_BG                                            HexColor(0xffffff)//HexColor(0xf5f6f1)
/** 统一的聊天界面默认背景色（微信风格浅灰） */
#define UI_DEFAULT_CHATTING_BG                                   HexColor(0xEDEDED)//HexColor(0xf5f7fa)
/** 聊天界面底部输入区域背景色（微信风格） */
#define UI_DEFAULT_CHAT_INPUT_BAR_BG                             HexColor(0xF7F7F7)
/** 聊天输入框（白框）背景色 */
#define UI_DEFAULT_CHAT_INPUT_FIELD_BG                           HexColor(0xFFFFFF)
/** 聊天输入框边框色 */
#define UI_DEFAULT_CHAT_INPUT_FIELD_BORDER                       HexColor(0xD9D9D9)
/** 聊天时间分割文字颜色 */
#define UI_DEFAULT_CHAT_TIME_TEXT_COLOR                          HexColor(0xB2B2B2)
/** 各界面统一的按钮背景色（当前为暗红色） */
#define UI_DEFAULT_BTN_BG_COLOR                                  HexColor(0xc1342d)
/** 各界面统一的按钮背景色（当前为半透明暗红色，主要用于创建群组时的确认按钮背景） */
#define UI_DEFAULT_BTN_BG_TRANSPARENT_COLOR                      HexColor(0x88c1342d)
/** 各界面统一的高亮色（当前为亮红色），比如：导航栏上的按钮文字色、无背景的链接样式按钮文字颜色等 */
#define UI_DEFAULT_HILIGHT_COLOR                                 HexColor(0xc6391e)//RGBCOLOR(198,57,30)
/** 界面标题栏默认标题字体颜色 */
#define UI_DEFAULT_TITLE_BG_COLOR                                HexColor(0xfafafa)
/** 界面标题栏默认标题字体大小 */
#define UI_DEFAULT_TITLE_FONT_SIZE                               19
/** 界面标题栏默认标题字体颜色 */
#define UI_DEFAULT_TITLE_FONT_COLOR                              HexColor(0x2c2f36)
/** 列表中分隔线的默认颜色 */
#define UI_DEFAULT_TABLE_VIEW_DIVIDER_GRAY                       HexColor(0xe8eaee)
/** 列表中图标圆角 */
#define UI_DEFAULT_TABLE_VIEW_ICON_CORNER_RADIUS                 8
/** 列表选中时背景色（淡灰） */
#define UI_DEFAULT_TABLE_VIEW_SELECTED_BG_COLOR                  HexColor(0xf1f2f7)
/** 列表选中时背景色（较深灰） */
#define UI_DEFAULT_TABLE_VIEW_SELECTED_BG_DARK_COLOR             HexColor(0xe7e9ef)
/** 聊天列表中，发出的大文件消息上传进度条的前景颜色（亮绿色） */
#define UI_DEFAULT_BIGFILE_PROGRESS_FORGROUND_LIGHT_GREEN_COLOR  HexColor(0x6acd26)
/** 文字按钮的颜色（亮绿色） */
#define UI_DEFAULT_PLAINT_BUTTON_LIGHT_GREEN_COLOR               HexColor(0x00DE7A)//HexColor(0x42C958)
/** 搜索功能里的关键字高亮颜色（亮橙红色） */
#define UI_DEFAULT_SEARCH_KEYWORD_COLOR                          HexColor(0xff6432)
/** 搜索功能里的进入聊天界面时，定位到该条被搜消息时的背景高亮颜色（灰色） */
#define UI_DEFAULT_SEARCH_HILIGHT_BG_COLOR                       HexColor(0xd9dbdf)//HexColor(0xe1e2e7)
/** 图片消息等未加载到图片时的默认背景颜色 */
#define UI_DEFAULT_MEDIA_MESSAGE_PLACEHOLDER_COLOR               HexColor(0xd8d8d8)
/** 设置面板中的按钮边框颜色 */
#define UI_DEFAULT_SETTING_ITEM_BUTTON_BORDER_COLOR              HexColor(0xf2f4f7)

// ========================================
// 多端增量同步相关
// ========================================

/** 通知名：增量消息同步完成（userInfo 包含 @"syncedDataIds" → NSSet<NSString *>） */
#define kIMIncrementalSyncCompleted @"kIMIncrementalSyncCompleted"

#endif
