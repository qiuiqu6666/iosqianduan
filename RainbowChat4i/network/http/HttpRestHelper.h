//telegram @wz662
#import <Foundation/Foundation.h>
#import "AFHTTPSessionManager.h"
#import "HttpService.h"
#import "LoginInfo2.h"
#import "UserEntity.h"
//#import "TempChatMsgDTO.h"
#import "UserRegisterDTO.h"
#import "OfflineMsgDTO.h"
#import "GroupEntity.h"
#import "GroupMemberEntity.h"
#import "PhotosOrVoiecesDTO.h"
#import "LogoutInfo.h"

@interface HttpRestHelper : NSObject

+ (instancetype)sharedInstance;

/**
 【接口1017】HTTP登陆认证请求接口调用（v2版）.

 @param ai 要提交的登陆信息
 @param complete 服务器返回结果回调
 @param view http请求的执行进度提示父view（此参数不为空时将自动显示进度提示菊花）
 */
- (void)submitLoginToServerV2:(LoginInfo2 *)ai complete:(void (^)(BOOL sucess, NSDictionary *retMap))complete hudParentView:(UIView *)view showLocalErrorAlert:(BOOL)showLocalErrorAlert completeForLocalError:(void (^)(NSString *errorLog))completeForLocalError;

// 【接口-2】注销登陆认证请求接口调用.
- (void)submitLogoutToServer:(LogoutInfo *)ao;

#pragma mark - 钱包接口（processor_id=1018, job_dispatch=30）

/** 钱包-余额查询（action 7）. complete 返回 sucess 与 NSDictionary *data@{ @"balance", @"frozen_amount", @"available_balance" } */
- (void)submitWalletBalanceWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;
/** 钱包-查询资金密码是否设置（action 36）. 返回 NSDictionary *data@{ @"is_set":@"1"或@"0", @"set_time":@"..." } */
- (void)submitWalletCheckFundPasswordStatusWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;
/** 钱包-设置资金密码（action 8）. 返回 "1" 成功，"0" 表示已设置过（可转修改流程）. 参数 fund_password */
- (void)submitWalletSetFundPassword:(NSString *)newPassword complete:(void (^)(BOOL sucess, NSString *msg))complete hudParentView:(UIView *)view;
/** 钱包-校验资金密码（action 22）. 用于转账/发红包/提现前，参数名fund_password */
- (void)submitWalletVerifyFundPassword:(NSString *)password complete:(void (^)(BOOL sucess, NSString *msg))complete hudParentView:(UIView *)view;
/** 钱包-校验资金密码（内部方法，用于检测密码状态，不显示错误提示） */
- (void)submitWalletVerifyFundPassword:(NSString *)password complete:(void (^)(BOOL sucess, NSString *msg))complete hudParentView:(UIView *)view showLocalErrorAlert:(BOOL)showAlert;
/** 钱包-转账（action 29）. to_uid, amount(元字符串), remark, fund_password；可选 group_id */
- (void)submitWalletTransferToUid:(NSString *)toUid amountCent:(long long)amountCent remark:(NSString *)remark idempotentKey:(NSString *)idempotentKey fundPassword:(NSString *)fundPassword groupId:(NSString *)groupId complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;
/** 钱包-交易记录（action 33）. 参数：page, page_size, transaction_type(可选) */
- (void)submitWalletLedgerListWithParams:(NSDictionary *)params complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;
/** 钱包-收款码解析（action 23）. code 当前为收款方 user_uid，返回 payeeUid, nickname */
- (void)submitWalletResolvePayeeByCode:(NSString *)code complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;
/** 钱包-修改资金密码（action 9）. 与修改登陆密码一致：old_psw+psw，无需短信。uid 可选，不传则用 token 对应用户 */
- (void)submitWalletModifyFundPasswordWithOldPassword:(NSString *)oldPsw newPassword:(NSString *)psw uid:(NSString *)uid phoneNum:(NSString *)phoneNum smsCode:(NSString *)smsCode complete:(void (^)(BOOL sucess, NSString *msg))complete hudParentView:(UIView *)view;
/** 钱包-申请充值（action 23）. amount 金额字符串（元） */
- (void)submitWalletRecharge:(NSString *)amount complete:(void (^)(BOOL sucess, NSString *msg))complete hudParentView:(UIView *)view;
/** 钱包-申请提现（action 24）. withdrawalMethodId, amount, fundPassword */
- (void)submitWalletWithdraw:(NSString *)withdrawalMethodId amount:(NSString *)amount fundPassword:(NSString *)fundPassword complete:(void (^)(BOOL sucess, NSString *msg))complete hudParentView:(UIView *)view;
/** 钱包-绑定提款方式（action 25）. methodType(1=支付宝,2=微信,3=银行卡), accountName, accountNumber, qrCodeUrl(可选), bankName(银行卡必填) */
- (void)submitWalletBindWithdrawMethod:(int)methodType accountName:(NSString *)accountName accountNumber:(NSString *)accountNumber qrCodeUrl:(NSString *)qrCodeUrl bankName:(NSString *)bankName complete:(void (^)(BOOL sucess, NSString *msg))complete hudParentView:(UIView *)view;
/** 钱包-查询提款方式列表（接口 1018-30-14，actionId=26）. 返回当前用户已绑定的收款方式数组，元素含 id/method_type/account_name/account_number/qr_code_url/bank_name/is_default/create_time */
- (void)submitWalletGetWithdrawMethodsWithComplete:(void (^)(BOOL sucess, NSArray *methods))complete hudParentView:(UIView *)view;
/** 钱包-删除提款方式（action 27）. methodId */
- (void)submitWalletDeleteWithdrawMethod:(NSString *)methodId complete:(void (^)(BOOL sucess, NSString *msg))complete hudParentView:(UIView *)view;
/** 钱包-设置默认提款方式（action 28）. methodId */
- (void)submitWalletSetDefaultWithdrawMethod:(NSString *)methodId complete:(void (^)(BOOL sucess, NSString *msg))complete hudParentView:(UIView *)view;
/** 钱包-发普通红包（action 30）. 群专属时传 exclusiveReceiverUid 且 totalCount=1 即指定人直接到账 */
- (void)submitWalletSendNormalRedPacket:(int)receiverType receiverUid:(NSString *)receiverUid groupId:(NSString *)groupId totalAmount:(NSString *)totalAmount totalCount:(int)totalCount message:(NSString *)message fundPassword:(NSString *)fundPassword exclusiveReceiverUid:(NSString *)exclusiveReceiverUid complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;
/** 钱包-发拼手气红包（action 31）. 群专属时传 exclusiveReceiverUid 且 totalCount=1 即指定人直接到账 */
- (void)submitWalletSendLuckyRedPacket:(int)receiverType receiverUid:(NSString *)receiverUid groupId:(NSString *)groupId totalAmount:(NSString *)totalAmount totalCount:(int)totalCount message:(NSString *)message fundPassword:(NSString *)fundPassword exclusiveReceiverUid:(NSString *)exclusiveReceiverUid complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;
/** 钱包-抢红包（action 32）. packetId */
- (void)submitWalletGrabRedPacket:(NSString *)packetId complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;
/** 钱包-查询红包记录（action 34）. page, pageSize, type(可选) */
- (void)submitWalletGetRedPacketList:(int)page pageSize:(int)pageSize type:(int)type complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;
/** 钱包-查询红包详情（action 35）. packetId */
- (void)submitWalletGetRedPacketDetail:(NSString *)packetId complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

#pragma mark - TRX 链上钱包接口（processor_id=1019, job_dispatch=30）

/** TRX 钱包-获取钱包完整信息（action 109）. data@{ trx_address,balance_trx,balance_usdt,balance_cny,key_index,create_time } */
- (void)submitTrxWalletFullInfoWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

/** TRX 钱包-创建/获取钱包（action 102）. data@{ trx_address,key_index } */
- (void)submitTrxWalletCreateOrGetWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

/** TRX 钱包-查询链上余额(实时)（action 103）. data@{ trx_address,balance_trx,balance_usdt,price_usdt_cny,price_trx_cny } */
- (void)submitTrxWalletRealtimeBalanceWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

/** TRX 钱包-获取充值地址（action 104）. data@{ trx_address,qr_code_url,deposit_enabled } */
- (void)submitTrxWalletDepositAddressWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

/** TRX 钱包-申请链上提现/转账（action 105）. 参数 to_address, asset_type(TRX/USDT), amount；返回 data@{ withdraw_id,status } */
- (void)submitTrxWalletWithdrawToAddress:(NSString *)toAddress assetType:(NSString *)assetType amount:(NSString *)amount complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

/** TRX 钱包-获取用户资产余额（action 110）. data@{ trx:{available_balance,...}, usdt:{available_balance,...} } */
- (void)submitTrxWalletAssetBalanceWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

/** TRX 钱包-查询充值记录（action 107） */
- (void)submitTrxWalletDepositRecords:(int)page pageSize:(int)pageSize complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

/** TRX 钱包-查询提现记录（action 108） */
- (void)submitTrxWalletWithdrawRecords:(int)page pageSize:(int)pageSize complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

/** TRX 钱包-获取资产流水（action 111）. assetType/TRX/USDT 可空；flowType 可空 */
- (void)submitTrxWalletAssetFlows:(NSString *)assetType flowType:(NSString *)flowType page:(int)page pageSize:(int)pageSize complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

/** TRX 钱包-获取热钱包信息（action 112） */
- (void)submitTrxWalletHotWalletInfoWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

/** TRX 钱包-获取提现手续费配置（action 113）. assetType/TRX/USDT */
- (void)submitTrxWalletWithdrawFeeConfig:(NSString *)assetType complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-1-27】获取短信验证码接口调用.
 *
 * @param phoneNum 手机号码
 * @param bizType 业务类型（0 表示用于验证码登录功能中，1 表示用于注册新账号功能中， 2 表示用于手机号+验证码重置密码功能中）
 * 返回 DataFromServer中sucess参数：true表示本次接口成功完成、否则表失败，returnValue：1 表示更新成功，否则失败。具体返回值详见接口文档！
 */
- (void)submitGetSMS:(NSString *)phoneNum bizType:(NSString *)bizType complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view showLocalErrorAlert:(BOOL)showLocalErrorAlert completeForLocalError:(void (^)(NSString *errorLog))completeForLocalError;

/**
 * 【接口1008-2-7】获取用户好友列表接口调用.
 */
- (void)submitGetRosterToServer:(NSString *)uid complete:(void (^)(BOOL sucess, NSArray<UserEntity *> *rosterList))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-2-8】更新好友信息中的备注、描述等的接口调用.
 *
 * @param remark 好友备注
 * @param mobile_num 手机号
 * @param more_desc 更多描述
 * @param localUid 本地用户的uid
 * @param friend_user_uid 好友的uid
 * @param complete 请求返回后的结果回调
 * @since 4.3
 */
- (void)submitRosterRemarkModifiyToServer:(NSString *)remark mobileNum:(NSString *)mobile_num moreDesc:(NSString *)more_desc localUid:(NSString *)localUid friendUid:(NSString *)friend_user_uid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 【接口1008-4-8】获取离线聊天消息的接口调用.

 @param user_uid 本地用户uid
 @param from_user_uid 聊天对象的uid
 @param complete 服务器返回结果回调
 @param view http请求的执行进度提示父view（此参数不为空时将自动显示进度提示菊花）
 */
- (void)submitGetOfflineChatMessagesToServer:(NSString *)user_uid friend:(NSString *)from_user_uid complete:(void (^)(BOOL sucess, NSArray<OfflineMsgDTO *> *offlineMsgList))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-4-26】清空用户的所有消息记录接口调用.
 * 清空后服务端不再返回清空时间点之前的任何消息（离线消息、会话列表、聊天记录漫游）。
 *
 * @param uid 当前用户的UID
 * @param complete 服务器返回结果回调。sucess为YES时，clearTime为服务端返回的清空时间戳（毫秒）
 * @param view http请求的执行进度提示父view
 */
- (void)submitClearAllMessagesToServer:(NSString *)uid complete:(void (^)(BOOL sucess, long long clearTime))complete hudParentView:(UIView *)view;

/**
 【接口1008-5-7】删除指定的好友接口调用.

 @param localUserUid 本地用户uid
 @param fromUserUid 好友的的uid
 @param complete 服务器返回结果回调
 @param view http请求的执行进度提示父view（此参数不为空时将自动显示进度提示菊花）
 */
- (void)submitDeleteFriendToServer:(NSString *)localUserUid friend:(NSString *)fromUserUid complete:(void (^)(BOOL sucess))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-3-23】查找好友功能子接口：获取“随机查找好友”结果的接口调用.
 * <p>
 * <b>关于”随机查找“好友的说明：</b><br>
 * 这个功能其实是参考QQ的查找好友功能来做的，”随机“可以给这种陌生人交友带来新鲜感，
 * 试想，一个传统的”查找所有线上好友“的界面里，每次点进来第一页都是之前看过的人，就
 * 太乏味了！
 * <br>
 * UI界面上可以仿照早期的qq随机查找好友方式：在结果页面上加一个”换一批“，每点一次都是
 * 一个随机结果，这就有意思、有意义多了。
 * </p>
 *
 * @param local_uid 本地用户的uid：用于查询结果中排除“自已”
 * @param sex_condition 性别查询条件：-1 表示不使用本条件(即ALL)，1  表只查男性，0  表只查女性
 * @param online_condition 在线状态查询条件：-1 表示不使用本条件(即ALL)，1  表只查在线，0 表只查离线
 * @param complete 请求返回后的结果回调
 */
- (void)submitGetRandomFindFriendsToServer:(NSString *)local_uid sex:(NSString *)sex_condition online:(NSString *)online_condition complete:(void (^)(BOOL sucess, NSArray<UserEntity *> *rosterList))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-3-8】获取用户/好友的个人信息接口调用.
 *
 * @param use_mail "1"表示用好友的mail地址查找，否则表示用好友的uid查找
 * @param friend_mail 用户或好友的mail地址（use_mail为true时本参数必须不为空哦）
 * @param friend_uid 用户或好友的uid（use_mail为false时本参数必须不为空哦）
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败
 */
- (void)submitGetFriendInfoToServer:(BOOL)use_mail mail:(NSString *)friend_mail uid:(NSString *)friend_uid complete:(void (^)(BOOL sucess, UserEntity *userInfo))complete hudParentView:(UIView *)view;

- (void)submitGetFriendInfoByPhoneToServer:(NSString *)phone complete:(void (^)(BOOL sucess, UserEntity *userInfo))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-10-7】删除个人相册、个人介绍语音留言等2进制资料的接口调用.
 *
 * @param resourceId 要删除的资源对应的数据库id
 * @param fileName 要删除的资源文件名
 * @param resType "0"个人介绍相册照片，"1"个人语音介绍，"2"手机相册（2 需服务端支持）
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败
 */
- (void)submitDeleteProfileBinaryToServer:(NSString *)resourceId fname:(NSString *)fileName type:(NSString *)resType complete:(void (^)(BOOL sucess))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-10-8】查询个人相册、个人介绍语音留言预览数量的接口调用.
 *
 * @param user_uid 被查询人的UID
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败
 */
- (void)queryPhotosOrVoicesCountFromServer:(NSString *)user_uid complete:(void (^)(BOOL sucess, int photosCount, int pvoiceCount))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-10-9】查询个人相册、个人介绍语音留言的完整数据列表（
 * 目前用于客户端个人信息查看界面中显示照片和语音完整列表时使用）的接口调用.
 *
 * @param resourceType 要查询的资源类型：0个人介绍相册、1个人语音介绍、2手机相册（2 需服务端在 1008-10-9 中支持）
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败
 */
- (void)queryPhotosOrVoicesListFromServer:(NSString *)resourceOfUid resourceType:(int)resourceType complete:(void (^)(BOOL sucess, NSArray<PhotosOrVoiecesDTO *> *datas))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-10-22】查询好友信息中个人相册的预览图片列表（
 * 目前用于客户端个人信息查看界面中显示照片和语音预览列表时
 * 使用，通常最多只返回该用户的最新4张照片）的接口调用.
 *
 * @param resourceOfUid 相册的所有者UID
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，fileNameList是参数：形如“[[33232jk2j32k3k.jpg],[3eweweew32k3k.jpg]]”的2维数组，一行一个图片的文件名
 */
- (void)queryPhotosPreviewListFromServer:(NSString *)resourceOfUid complete:(void (^)(BOOL sucess, NSArray<NSArray<NSString *> *> *fileNameList))complete hudParentView:(UIView *)view;

/**
 * 【接口1015-23-7】获取指定md5码的大文件上传信息的接口调用.
 *
 * @param fileMd5 要上传文件的md5码
 * @param userUid 上传者的uid（非必须参数）
 * @param fileType 上传文件类型（0：表示普通大文件、1：表示短视频文件）
 * @since 2.1
*/
- (void)queryBigFileInfoFromServer:(NSString *)fileMd5 userUid:(NSString *)userUid fileType:(int)fileType complete:(void (^)(BOOL sucess, NSString *retCode, int chunkCount))complete hudParentView:(UIView *)view completeForLocalError:(void (^)(NSString *errorLog))completeForLocalError;

/**
 * 【接口1008-1-7】用户注册接口调用.
 *
 * @param registerData 用户的个人注册信息数据传输对象
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，registerResult参数：形如“{“new_uid”：“400079”}”的对象，内含此用户的用户ID
 */
- (void)submitRegisterToServer:(UserRegisterDTO *)registerData complete:(void (^)(BOOL sucess, NSDictionary *registerResult))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-3-9】"密记密码"邮件请求接口调用.
 * <p>
 * 友情提示：因为发送邮件是个比较慢的过程，为了提升客户端体验，建议在使用本接口时无需等待网络请求完成的回
 * 调，这样带给用户的体验会好一点。调用时只是表示邮件请求已发到服务器，但至于服务器有没有成功发出，那
 * 就不知道了，否则需要等到服务端发送邮件完成的话，会等更多时间，这样就影响用户体验了。
 *
 * @param receiveProcessedMail 接收"忘记密码"处理邮件的邮箱地址
 */
- (void)submitForgotPasswordToServer:(NSString *)receiveProcessedMail complete:(void (^)(BOOL sucess))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-1-28】手机号+验证码重置密码接口调用.
 *
 * @param phoneNum 手机号码
 * @param smsCode 短信验证码（4位数字）
 * @param newPassword 新密码（明文）
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示重置成功，0 表示失败，2 表示手机号未注册，3 表示验证码无效，4 表示新密码为空。具体返回值详见接口文档！
 */
- (void)submitResetPasswordByPhoneToServer:(NSString *)phoneNum smsCode:(NSString *)smsCode newPassword:(NSString *)newPassword complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-3-7】发送邀请朋友邮件接口调用.
 * <p>
 * 注意：因为发送邮件是个比较慢的过程，为了提升客户端体验，此次的接口调用时服务端
 * 返回了只是表示邮件请求已发到服务器，但至于服务器有没有成功发出，那就不知道了，
 * 否则需要等到服务端发送邮件完成的话，会等更多时间，这样就影响用户体验了。
 *
 * @param receiver_mail 接收邀请的email地址
 * @param local_nickname 发起邀请人的昵称
 * @param local_mail 发起邀请人的email（作为被邀请人加好友的凭证）
 * @param local_uid 发起邀请人的uid（作为被邀请人加好友的凭证）
 */
- (void)submitInviteFriendToServer:(NSString *)receiver_mail
                         localNick:(NSString *)local_nickname
                         localMail:(NSString *)local_mail
                          localUid:(NSString *)local_uid
                          complete:(void (^)(BOOL sucess))complete
                     hudParentView:(UIView *)view;

/**
 * 【接口1008-4-7】获取离线加好友请求的接口调用.
 *
 * @param local_uid 发起邀请人的uid（作为被邀请人加好友的凭证）
 */
- (void)submitGetOfflineAddFriendsReqToServer:(NSString *)local_uid complete:(void (^)(BOOL sucess, NSArray<UserEntity *> *reqList))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-4-31】添加好友记录总览：查询当前用户全部添加好友记录（pending_out / pending_in / accepted_current）.
 * @param user_uid 当前用户 UID
 * @param complete sucess=YES 时 records 为 NSArray<NSDictionary *>，每项含 status, requester_uid, target_uid, peer_uid, peer_nickname, be_desc, add_source, event_time
 */
- (void)submitGetAllAddFriendRecordsToServer:(NSString *)user_uid complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *records))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-4-32】单聊通话记录聚合：查询当前用户单聊通话记录（拨出/接听/未接、音视频、时长）.
 * @param user_uid 必填，当前用户 UID
 * @param page 可选，页码，默认 1
 * @param page_size 可选，每页条数，默认 50，最大 200
 * @param peer_uid 可选，传了则只看与某用户的通话
 * @param since_time2 可选，增量时间戳
 * @param complete sucess=YES 时 records 为 NSArray<NSDictionary *>，每项含 collect_id, msg_time, msg_time2, sender_uid, sender_nickname, sender_avatar, receiver_uid, receiver_nickname, receiver_avatar, direction, call_type, call_status, duration, duration_text, raw_content, fingerprint 等
 */
- (void)submitGetCallRecordsToServer:(NSString *)user_uid
                               page:(NSInteger)page
                           pageSize:(NSInteger)page_size
                           peerUid:(NSString *)peer_uid
                        sinceTime2:(NSString *)since_time2
                           complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *records))complete
                      hudParentView:(UIView *)view;

/**
 * 【接口1008-4-37】删除单条通话记录（标记不显示）.
 * @param user_uid 当前用户 UID
 * @param fingerprint 该条通话记录的消息指纹（来自 1008-4-32 返回的 fingerprint）
 * @param complete success=YES 表示服务端删除成功；NO 时 msg 为失败原因
 */
- (void)submitDeleteCallRecordToServer:(NSString *)user_uid
                           fingerprint:(NSString *)fingerprint
                              complete:(void (^)(BOOL success, NSString *msg))complete
                         hudParentView:(UIView *)view;

/**
 * 【接口1008-1-8】用户基本信息修改接口调用.
 *
 * @param localUid 本地用户的uid
 * @param nickName 要修改的昵称
 * @param sex 要修改的性别（1表示男性，0表示女性）
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示更新成功，否则失败。具体返回值详见接口文档！
 */
- (void)submitUserBaseInfoModifiyToServer:(NSString *)localUid nick:(NSString *)nickName sex:(NSString *)sex complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-26-35】昵称是否可用（实时校验，不修改数据）.
 * @param uid 当前登录用户 UID，可选；传入时与自己当前昵称相同视为可用
 * @param nickname 待检测的昵称
 * @param complete available: 是否可用；msg: 服务端提示
 */
- (void)submitNicknameAvailableCheck:(NSString *)uid nickname:(NSString *)nickname complete:(void (^)(BOOL sucess, BOOL available, NSString *msg))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-1-9】修改登陆密码接口调用.
 *
 * @param localUid 本地用户的uid
 * @param oldPassword 原密码（用于服务端验证原密码的正确性）
 * @param newPassword 新密码
 * @param smsCode 短信验证码（4位数字）
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示更新成功，0 表示失败，2 表示原密码不正确，3 表示手机号不存在，4 表示短信验证码无效。具体返回值详见接口文档！
 */
- (void)submitUserPasswordModifiyToServer:(NSString *)localUid old:(NSString *)oldPassword new:(NSString *)newPassword smsCode:(NSString *)smsCode complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-1-22】用户What'sUp（个性签名）修改接口调用.
 *
 * @param localUid 本地用户的uid
 * @param whats_up 要修改的个性签名内容
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示更新成功，否则失败。具体返回值详见接口文档！
 */
- (void)submitUserWhatsUpModifiyToServer:(NSString *)localUid whatsUp:(NSString *)whats_up complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-1-27扩展】发送邮箱验证码接口调用.
 *
 * @param email 邮箱地址
 * @param uid 用户UID
 * @param bizType 业务类型（3 表示用于修改/绑定邮箱）
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示发送成功，否则失败。具体返回值详见接口文档！
 */
- (void)submitGetEmailCode:(NSString *)email uid:(NSString *)uid bizType:(NSString *)bizType complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-1-29】修改/绑定手机号接口调用.
 *
 * @param uid 用户UID
 * @param newPhoneNum 新手机号
 * @param newPhoneSmsCode 新手机号验证码
 * @param oldPhoneSmsCode 旧手机号验证码（如果用户已有手机号，则必填；如果用户没有手机号，则传nil）
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示修改成功，0 表示失败，2 表示新手机号已被使用，3 表示旧手机号验证码无效，4 表示新手机号验证码无效，5 表示用户不存在。具体返回值详见接口文档！
 */
- (void)submitModifyPhoneToServer:(NSString *)uid newPhoneNum:(NSString *)newPhoneNum newPhoneSmsCode:(NSString *)newPhoneSmsCode oldPhoneSmsCode:(NSString *)oldPhoneSmsCode complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-1-30】修改/绑定邮箱接口调用.
 *
 * @param uid 用户UID
 * @param newEmail 新邮箱地址
 * @param newEmailCode 新邮箱验证码
 * @param oldEmailCode 旧邮箱验证码（如果用户已有邮箱，则必填；如果用户没有邮箱，则传nil）
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示修改成功，0 表示失败，2 表示新邮箱已被使用，3 表示旧邮箱验证码无效，4 表示新邮箱验证码无效，5 表示用户不存在。具体返回值详见接口文档！
 */
- (void)submitModifyEmailToServer:(NSString *)uid newEmail:(NSString *)newEmail newEmailCode:(NSString *)newEmailCode oldEmailCode:(NSString *)oldEmailCode complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1008-1-24】用户的其它说明修改接口调用.
 * <p>
 * 个性签名与其它说明的区别：个性签名可能经常但每天会改（比如用户每日的心态
 * 和感悟等），但这个其它说明或许不常修改。
 *
 * @param localUid 本地用户的uid
 * @param otherCaption 要修改的个人其它说明
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示更新成功，否则失败。具体返回值详见接口文档！
 */
- (void)submitUserOtherCaptionModifiyToServer:(NSString *)localUid otherCaption:(NSString *)otherCaption complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-25-7】获取用户的群组列表的接口调用.
 *
 * @param uid 被查者的uid
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，groupsList：群组列表集合数据。具体返回值详见接口文档！
 */
- (void)submitGetGroupsListFromServer:(NSString *)uid complete:(void (^)(BOOL sucess, NSArray<GroupEntity *> *groupsList))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-25-8】查询群基本信息的接口调用..
 *
 * @param gid 查询的群id
 * @param myUserId 非必须参数，如果本参数不为空，则表示要同时把”我“在该群中的昵称给查出来，否则不需要查
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，groupInfo：群基本信息封装对象。具体返回值详见接口文档！
 */
- (void)submitGetGroupInfoToServer:(NSString *)gid myUserId:(NSString *)myUserId complete:(void (^)(BOOL sucess, GroupEntity *groupInfo))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-24-8】修改群名称接口调用.
 *
 * @param group_name 本次要修改成的新群名
 * @param gid 被修改的群id
 * @param modify_by_uid 修改者的uid
 * @param modify_by_nickname 修改者的昵称
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示更新成功，否则失败。具体返回值详见接口文档！
 */
- (void)submitGroupNameModifiyToServer:(NSString *)group_name gid:(NSString *)gid modify_by_uid:(NSString *)modify_by_uid modify_by_nickname:(NSString *)modify_by_nickname complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-24-9】修改"我"的群昵称接口调用.
 *
 * @param nickname_ingroup 新的群内昵称
 * @param gid 我所在的群id
 * @param user_uid 被修改的用户uid
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示更新成功，否则失败。具体返回值详见接口文档！
 */
- (void)submitGroupNickNameModifiyToServer:(NSString *)nickname_ingroup gid:(NSString *)gid user_uid:(NSString *)user_uid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-24-22】修改群公告接口调用.
 *
 * @param g_notice 新的公告
 * @param g_notice_updateuid 本次公告修改人
 * @param gid 被修改的群id
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示更新成功，否则失败。具体返回值详见接口文档！
 */
- (void)submitGroupNoticeModifiyToServer:(NSString *)g_notice g_notice_updateuid:(NSString *)g_notice_updateuid gid:(NSString *)gid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-24-23】删除群成员或退群接口调用.
 *
 * @param del_opr_uid 本次删除或退群的操作人uid（群主踢人时本参数为群主，如果是用户自已退出退路时本参数为退出者自已）
 * @param del_opr_nickname 本次删除或退群的操作人昵称
 * @param membersBeDelete 要删除或退群的群员（如果只是个人退群时，本参数就是只有一行的2维数组）
 * @param gid 本次删除发生的群id
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示更新成功，否则失败。具体返回值详见接口文档！
 */
- (void)submitDeleteOrQuitGroupToServer:(NSString *)del_opr_uid del_opr_nickname:(NSString *)del_opr_nickname gid:(NSString *)gid membersBeDelete:(NSArray<NSArray *> *)membersBeDelete complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-24-26】解散群（仅开放给群主）接口调用.
 *
 * @param owner_uid 群主uid
 * @param gid 将要被解散的群
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示更新成功，否则失败(其中2表示解散发起人已不是群主，本次解散失败)。具体返回值详见接口文档！
 */
- (void)submitDismissGroupToServer:(NSString *)owner_uid owner_nickname:(NSString *)owner_nickname gid:(NSString *)gid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-25-9】查询群成员列表的接口调用.
 *
 * @param gid 群ID
 * @param requestUid 请求者UID（传入时会根据隐私保护设置过滤结果，传nil则不过滤）
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，groupMembersList：群成员列表集合数据
 */
- (void)submitGetGroupMembersListFromServer:(NSString *)gid requestUid:(NSString *)requestUid complete:(void (^)(BOOL sucess, NSMutableArray<GroupMemberEntity *> *groupMembersList))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-25-9】查询群成员列表（分页）. 大群时需多次调用合并结果；单次最多 500 条.
 * @param page 页码，从 1 开始；传 0 时与 pageSize 一起表示不分页（服务端对超过 500 人的群仍只返回前 500）
 * @param pageSize 每页条数，建议 500；传 0 表示不分页
 */
- (void)submitGetGroupMembersListFromServer:(NSString *)gid requestUid:(NSString *)requestUid page:(int)page pageSize:(int)pageSize complete:(void (^)(BOOL sucess, NSMutableArray<GroupMemberEntity *> *groupMembersList))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-24-7】创建群组的接口调用.
 *
 * @param localUserUid 创建者（群主）的uid
 * @param localUserNickname 群主昵称
 * @param membersOfNewGroup 群成员
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，newGroupInfo：表示新建成功后的新群基本信息。具体返回值详见接口文档！
 */
- (void)submitCreateGroupToServer:(NSString *)localUserUid localUserNickname:(NSString *)localUserNickname members:(NSArray<GroupMemberEntity *> *)membersOfNewGroup complete:(void (^)(BOOL sucess, GroupEntity *newGroupInfo))complete hudParentView:(UIView *)view;

- (void)submitCreateGroupToServer:(NSString *)localUserUid localUserNickname:(NSString *)localUserNickname groupName:(NSString *)groupName avatarUrl:(NSString *)avatarUrl members:(NSArray<GroupMemberEntity *> *)membersOfNewGroup complete:(void (^)(BOOL sucess, GroupEntity *newGroupInfo))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-24-24】邀请入群的接口调用.
 *
 * @param srcFrom 加群来源，"0"表示通过邀请加群、"1"表示通过扫描二维码加群、"2"表示通过分享的群名片加群，默认可为null（为null将默认是通过邀请加群）
 * @param invite_uid 邀请发起人或二维码分享者的的uid
 * @param invite_nickname 邀请发起人或二维码分享者的昵称
 * @param invite_to_gid 邀请至群
 * @param members 被邀请的成员，2维数组：[[gid, uid, nickname], [...], [...], [...]]
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示更新成功，否则失败。具体返回值详见接口文档！
 */
- (void)submitInviteToGroupToServer:(NSString *)srcFrom invite_uid:(NSString *)invite_uid invite_nickname:(NSString *)invite_nickname invite_to_gid:(NSString *)invite_to_gid  members:(NSArray<NSArray *> *)members complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

/**
 * 【接口1016-24-25】转让本群（仅开放给群主）接口调用.
 *
 * @param old_owner_uid 原群主uid
 * @param new_owner_uid 新群主uid（即将被转让为群主）
 * @param gid 转让发生的群
 * @param complete sucess参数：YES表示本次接口成功完成、否则表失败，resultCode：1 表示更新成功，否则失败。具体返回值详见接口文档！
 */
- (void)submitTransferGroupToServer:(NSString *)old_owner_uid new_owner_uid:(NSString *)new_owner_uid new_owner_nickname:(NSString *)new_owner_nickname gid:(NSString *)gid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;


// ========================== 群聊管理新增接口 ==========================

/**
 * 【接口1016-24-27】设置/取消管理员的接口调用.
 *
 * @param oprUid 操作者UID（必须是群主）
 * @param targetUid 目标用户UID
 * @param gid 群ID
 * @param role 1=设为管理员，0=取消管理员
 * @param complete 返回值：@"1"成功，@"0"失败，@"-2"非群主无权限，@"-3"不能修改自己，@"-4"目标不是群成员，@"-5"role不合法
 */
- (void)submitSetGroupAdminToServer:(NSString *)oprUid
                          targetUid:(NSString *)targetUid
                                gid:(NSString *)gid
                               role:(int)role
                           complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                      hudParentView:(UIView *)view;

/**
 * 【接口1016-24-28】设置全群禁言模式的接口调用.
 *
 * @param oprUid 操作者UID
 * @param gid 群ID
 * @param muteMode 禁言模式：0=正常，1=仅管理员和群主可发言，2=仅群主可发言
 * @param complete 返回值：@"1"成功，@"0"失败，@"-2"权限不足，@"-3"参数不合法
 */
- (void)submitSetGroupMuteModeToServer:(NSString *)oprUid
                                   gid:(NSString *)gid
                              muteMode:(int)muteMode
                              complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                         hudParentView:(UIView *)view;

/**
 * 【接口1016-24-29】单人禁言的接口调用.
 *
 * @param oprUid 操作者UID
 * @param targetUid 被禁言用户UID
 * @param gid 群ID
 * @param muteUntil2 禁言到期时间戳（毫秒），0=永久禁言
 * @param complete 返回值：@"1"成功，@"0"失败，@"-2"权限不足，@"-3"不能禁言同级或上级，@"-4"目标不是群成员
 */
- (void)submitMuteGroupMemberToServer:(NSString *)oprUid
                            targetUid:(NSString *)targetUid
                                  gid:(NSString *)gid
                           muteUntil2:(long long)muteUntil2
                             complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                        hudParentView:(UIView *)view;

/**
 * 【接口1016-24-30】取消单人禁言的接口调用.
 *
 * @param oprUid 操作者UID
 * @param targetUid 被解除禁言的用户UID
 * @param gid 群ID
 * @param complete 返回值：@"1"成功，@"0"失败，@"-2"权限不足
 */
- (void)submitUnmuteGroupMemberToServer:(NSString *)oprUid
                              targetUid:(NSString *)targetUid
                                    gid:(NSString *)gid
                               complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                          hudParentView:(UIView *)view;

/**
 * 【接口1016-24-31】设置自定义群头像的接口调用.
 *
 * @param oprUid 操作者UID
 * @param gid 群ID
 * @param avatarUrl 群头像URL/文件名
 * @param complete 返回值：@"1"成功，@"0"失败，@"-2"权限不足
 */
- (void)submitSetGroupAvatarToServer:(NSString *)oprUid
                                 gid:(NSString *)gid
                           avatarUrl:(NSString *)avatarUrl
                            complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                       hudParentView:(UIView *)view;

/**
 * 【接口1016-24-32】修改群设置的接口调用.
 *
 * @param oprUid 操作者UID
 * @param gid 群ID
 * @param settings 要修改的群设置项（字典，只需传递要修改的字段）
 * @param complete 返回值：@"1"成功，@"0"没有要更新的字段/失败，@"-2"权限不足
 */
- (void)submitModifyGroupSettingsToServer:(NSString *)oprUid
                                      gid:(NSString *)gid
                                 settings:(NSDictionary *)settings
                                 complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                            hudParentView:(UIView *)view;

/**
 * 【接口1016-24-33】审核入群申请的接口调用.
 *
 * @param oprUid 审核人UID
 * @param gid 群ID
 * @param requestId 申请记录ID
 * @param decision 1=通过，2=拒绝
 * @param complete 返回值：@"1"成功，@"0"失败，@"-2"权限不足
 */
- (void)submitReviewJoinRequestToServer:(NSString *)oprUid
                                    gid:(NSString *)gid
                              requestId:(NSString *)requestId
                               decision:(int)decision
                               complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                          hudParentView:(UIView *)view;

/**
 * 【接口1016-25-22】查询待审核入群申请列表的接口调用.
 *
 * @param gid 群ID
 * @param oprUid 请求者UID
 * @param complete 返回值：待审核申请数组
 */
- (void)submitQueryJoinRequestsFromServer:(NSString *)gid
                                   oprUid:(NSString *)oprUid
                                 complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *requestList))complete
                            hudParentView:(UIView *)view;

/**
 * 【接口1016-25-23】查询群禁言成员列表的接口调用.
 *
 * @param gid 群ID
 * @param complete 返回值：禁言成员数组
 */
- (void)submitQueryMutedMembersFromServer:(NSString *)gid
                                 complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *mutedList))complete
                            hudParentView:(UIView *)view;

/**
 * 【接口1016-25-24】查询群完整设置的接口调用.
 *
 * @param gid 群ID
 * @param complete 返回值：群设置字典
 */
- (void)submitQueryGroupSettingsFromServer:(NSString *)gid
                                  complete:(void (^)(BOOL sucess, NSDictionary *settings))complete
                             hudParentView:(UIView *)view;

/**
 * 【接口1016-33-7】查询单个群的管理通知列表.
 *
 * @param gid 群ID
 * @param requestUid 当前请求用户UID
 * @param page 页码，从1开始
 * @param pageSize 每页条数
 * @param complete 返回值：服务端原始字典，至少包含 notifications/page/page_size/total
 */
- (void)submitQueryGroupAdminNotificationsFromServer:(NSString *)gid
                                          requestUid:(NSString *)requestUid
                                                page:(NSInteger)page
                                            pageSize:(NSInteger)pageSize
                                            complete:(void (^)(BOOL sucess, NSDictionary *result))complete
                                       hudParentView:(UIView *)view;

/**
 * 【接口1016-33-8】获取群管理通知详情.
 *
 * @param notificationId 通知ID
 * @param requestUid 当前请求用户UID
 * @param complete 返回值：通知详情字典
 */
- (void)submitGetGroupAdminNotificationDetailFromServer:(NSString *)notificationId
                                             requestUid:(NSString *)requestUid
                                               complete:(void (^)(BOOL sucess, NSDictionary *detail))complete
                                          hudParentView:(UIView *)view;

/**
 * 【接口1016-33-9】聚合查询当前用户所有群的通知.
 *
 * @param requestUid 当前请求用户UID
 * @param page 页码，从1开始
 * @param pageSize 每页条数
 * @param complete 返回值：服务端原始字典，至少包含 notifications/page/page_size/total
 */
- (void)submitQueryAllGroupNotificationsFromServer:(NSString *)requestUid
                                              page:(NSInteger)page
                                          pageSize:(NSInteger)pageSize
                                          complete:(void (^)(BOOL sucess, NSDictionary *result))complete
                                     hudParentView:(UIView *)view;


// ========================== 已读回执 ==========================

/**
 * 【接口1008-4-22】删除整个会话（软删除）的接口调用.
 * <p>
 * 单聊时仅在服务端标记删除时间点，之前的消息对该用户不可见，之后的新消息仍可见。
 * 群聊时行为不变（更新 group_members.msg_time_start）。
 *
 * @param luid 操作者 UID（"我"的 UID）
 * @param ruid 对方 UID（单聊时必填，群聊时传nil）
 * @param gid 群 ID（群聊时必填，单聊时传nil）
 * @param complete 返回值：@"1" 成功 / @"0" 失败
 * @since 11.x
 */
- (void)submitDeleteConversationToServer:(NSString *)luid
                                    ruid:(NSString *)ruid
                                     gid:(NSString *)gid
                                complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                           hudParentView:(UIView *)view;

/**
 * 【接口1008-4-23】删除单条消息（软删除）的接口调用.
 * <p>
 * 仅在服务端记录该消息对当前用户不可见，对方不受影响。
 *
 * @param luid 操作者 UID
 * @param fpForMessage 被删除消息的指纹码（fingerprint）
 * @param complete 返回值：@"1" 成功 / @"0" 失败
 * @since 11.x
 */
- (void)submitDeleteSingleMessageToServer:(NSString *)luid
                            fpForMessage:(NSString *)fpForMessage
                                complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                           hudParentView:(UIView *)view;

/**
 * 【接口1008-4-24】上报已读回执的接口调用.
 * <p>
 * 客户端打开某个聊天会话后上报已读；last_read_time2 为上报时刻（当前时间）的毫秒时间戳。
 * 服务端会使用 GREATEST 确保已读水位线只升不降。
 *
 * @param luid 当前用户 UID（"我"）
 * @param partnerId 聊天对象 UID 或群 ID
 * @param chatType 聊天类型："0"=好友，"1"=陌生人，"2"=群聊
 * @param lastReadTime2 上报时刻的时间戳（Java 毫秒，与消息 msg_time2 脱钩）
 * @param complete 返回值：@"1" 成功 / @"0" 失败
 * @since 11.x
 */
- (void)submitReportReadReceiptToServer:(NSString *)luid
                              partnerId:(NSString *)partnerId
                               chatType:(NSString *)chatType
                         lastReadTime2:(NSString *)lastReadTime2
                               complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                          hudParentView:(UIView *)view;

/**
 * 【接口1008-4-25】查询对方已读回执的接口调用.
 * <p>
 * 查询聊天对方已读到我的消息的时间戳，用于在消息气泡旁显示 ✓✓ 已读状态。
 *
 * @param luid 当前用户 UID（"我"）
 * @param partnerId 聊天对象 UID
 * @param chatType 聊天类型："0"=好友，"1"=陌生人，"2"=群聊
 * @param complete 返回值：last_read_time2 对方已读到的最新消息时间戳（毫秒），"0"=从未上报过已读
 * @since 11.x
 */
- (void)submitQueryReadReceiptFromServer:(NSString *)luid
                               partnerId:(NSString *)partnerId
                                chatType:(NSString *)chatType
                                complete:(void (^)(BOOL sucess, NSString *lastReadTime2))complete
                           hudParentView:(UIView *)view;

/**
 * 【接口1008-4-38】会话消息免打扰设置（与已读回执相同的 partner_id / chat_type 语义）.
 *
 * @param muteOn YES=开启免打扰（不响铃、会话列表按免打扰样式）；同步本地 UserDefaultsToolKits 时对应 setChatMsgToneOpen:NO
 */
- (void)submitConversationMsgMuteToServer:(NSString *)luid
                               partnerId:(NSString *)partnerId
                                chatType:(NSString *)chatType
                                  muteOn:(BOOL)muteOn
                                complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                           hudParentView:(UIView *)view;

/**
 * 【接口1008-26-8】分页查询单聊/群聊历史消息。
 *
 * @param localUid 当前用户 UID
 * @param remoteUid 单聊对端 UID；查群时传 nil
 * @param gid 群 ID；查单聊时传 nil
 * @param rowCount 每页条数
 * @param endTimestamp 向更早分页时的结束时间戳（毫秒字符串，可空）
 * @param endFingerprint 向更早分页时的结束消息指纹（可空，优先用于精确边界）
 * @param complete 回调：success / messages / hasMore
 */
- (void)submitQueryChatHistoryFromServer:(NSString *)localUid
                               remoteUid:(NSString * _Nullable)remoteUid
                                     gid:(NSString * _Nullable)gid
                                rowCount:(NSInteger)rowCount
                            endTimestamp:(NSString * _Nullable)endTimestamp
                          endFingerprint:(NSString * _Nullable)endFingerprint
                                complete:(void (^)(BOOL success, NSArray<NSArray *> * _Nullable messages, BOOL hasMore))complete
                           hudParentView:(UIView * _Nullable)view;

// ========================== 声网(Agora) Token ==========================

/**
 * 【接口1008-1-35】请求声网Agora RTC Token.
 *
 * @param uid 当前用户UID
 * @param calleeUid 被叫方UID（1v1通话）
 * @param complete 回调：success=是否成功, token=声网Token, channelName=频道名, appId=声网AppId, agoraUid=加入频道用的uid
 */
- (void)requestAgoraToken:(NSString *)uid
                calleeUid:(NSString *)calleeUid
                 complete:(void (^)(BOOL success, NSString *token, NSString *channelName, NSString *appId, NSUInteger agoraUid))complete;


// ========================== VoIP PushKit Token ==========================

/**
 * 【接口1008-1-36】上传 VoIP PushKit Token 到服务端.
 *
 * @param uid 当前用户UID
 * @param voipToken PushKit 注册获取的 VoIP 设备 Token（64位十六进制字符串）
 * @param complete 回调：success=是否成功
 */
- (void)uploadVoIPToken:(NSString *)uid
              voipToken:(NSString *)voipToken
               complete:(void (^)(BOOL success))complete;


// ========================== 收藏功能 ==========================

/**
 * 【接口1008-27-7】添加收藏接口调用.
 *
 * @param userUid 当前用户 UID
 * @param favType 收藏类型（0=文本，1=图片，2=语音，3=视频，4=文件，5=位置）
 * @param content 收藏内容
 * @param sourceFingerprint 原消息指纹 ID（可选）
 * @param sourceChatType 来源聊天类型：0=单聊，1=群聊（可选）
 * @param sourceFromUid 原消息发送者 UID（可选）
 * @param sourceFromNickname 原消息发送者昵称（可选）
 * @param memo 用户备注（可选）
 * @param complete 返回值：@"1" 成功
 */
- (void)submitAddFavoriteToServer:(NSString *)userUid
                          favType:(int)favType
                          content:(NSString *)content
                sourceFingerprint:(NSString *)sourceFingerprint
                   sourceChatType:(int)sourceChatType
                    sourceFromUid:(NSString *)sourceFromUid
               sourceFromNickname:(NSString *)sourceFromNickname
                             memo:(NSString *)memo
                         complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                    hudParentView:(UIView *)view;

/**
 * 【接口1008-27-8】删除收藏（批量）接口调用.
 *
 * @param userUid 当前用户 UID
 * @param ids 要删除的收藏 ID，多个用逗号分隔
 * @param complete 返回值：@"1" 成功
 */
- (void)submitDeleteFavoritesToServer:(NSString *)userUid
                                  ids:(NSString *)ids
                             complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                        hudParentView:(UIView *)view;

/**
 * 【接口1008-27-9】查询收藏列表（分页）接口调用.
 *
 * @param userUid 当前用户 UID
 * @param page 页码（从 1 开始）
 * @param pageSize 每页条数（最大 100）
 * @param favType 筛选类型：-1=全部，0~5=具体类型
 * @param complete 返回值：包含 total, page, page_size, list 的字典
 */
- (void)submitGetFavoritesFromServer:(NSString *)userUid
                                page:(int)page
                            pageSize:(int)pageSize
                             favType:(int)favType
                            complete:(void (^)(BOOL sucess, NSDictionary *result))complete
                       hudParentView:(UIView *)view;

/**
 * 【接口1008-27-22】修改收藏备注接口调用.
 *
 * @param userUid 当前用户 UID
 * @param favId 收藏记录 ID
 * @param memo 新的备注内容
 * @param complete 返回值：@"1" 成功
 */
- (void)submitModifyFavoriteMemoToServer:(NSString *)userUid
                                   favId:(NSString *)favId
                                    memo:(NSString *)memo
                                complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                           hudParentView:(UIView *)view;


// ========================== 自定义表情包 ==========================

/**
 * 【接口1008-28-7】查询自定义表情列表接口调用.
 *
 * @param userUid 当前用户 UID
 * @param complete 返回值：表情数组（每项包含 id, file_name, file_size, sort_order, create_time, url）
 */
- (void)submitGetStickersFromServer:(NSString *)userUid
                           complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *stickerList))complete
                      hudParentView:(UIView *)view;

/**
 * 【接口1008-28-8】删除自定义表情（批量）接口调用.
 *
 * @param userUid 当前用户 UID
 * @param ids 要删除的表情 ID，多个用逗号分隔
 * @param complete 返回值：@"1" 成功
 */
- (void)submitDeleteStickersToServer:(NSString *)userUid
                                 ids:(NSString *)ids
                            complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                       hudParentView:(UIView *)view;

/**
 * 【接口1008-28-9】调整自定义表情排序接口调用.
 *
 * @param userUid 当前用户 UID
 * @param stickerId 表情 ID
 * @param sortOrder 新的排序序号
 * @param complete 返回值：@"1" 成功
 */
- (void)submitSortStickerToServer:(NSString *)userUid
                        stickerId:(NSString *)stickerId
                        sortOrder:(int)sortOrder
                         complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                    hudParentView:(UIView *)view;

/**
 * 上传自定义表情图片（HTTP Multipart）.
 *
 * @param userUid 当前用户 UID
 * @param fileName 表情文件名（建议 MD5 命名）
 * @param imageData 表情图片数据
 * @param complete 返回值：YES 上传成功，NO 失败
 */
- (void)uploadStickerToServer:(NSString *)userUid
                     fileName:(NSString *)fileName
                    imageData:(NSData *)imageData
                     complete:(void (^)(BOOL success))complete;


// ========================== 大群消息（读扩散） ==========================

/**
 * 【接口1016-25-25 v2】拉取大群消息（读扩散模式）.
 *
 * 用于 group_mode=2 的大群，按 seq 拉取群消息。
 * v2 返回 JSON 对象 {messages:[...], has_more:bool, count:int}。
 *
 * @param gid       群 ID，必填
 * @param fromSeq   可选，默认 0；from_seq=0 表示返回最新 N 条消息
 * @param limit     可选，默认 200，最大 500
 * @param direction 可选，@"old"=加载更早消息（上滑翻页）；nil 或其他值=加载更新消息（增量拉取）
 * @param complete  返回值：success, 消息数组, hasMore（是否还有更多）
 */
- (void)submitFetchLargeGroupMessagesFromServer:(NSString *)gid
                                        fromSeq:(long long)fromSeq
                                          limit:(int)limit
                                      direction:(NSString * _Nullable)direction
                                       complete:(void (^)(BOOL success, NSArray<NSDictionary *> * _Nullable messages, BOOL hasMore))complete
                                  hudParentView:(UIView * _Nullable)view;

// ========================== 群聊已读回执统计 ==========================

/**
 * 【接口1008-4-29】查询群消息已读回执统计.
 *
 * @param groupId   群 ID
 * @param msgTime2  要查询的消息时间戳（毫秒字符串）
 * @param luid      查询者 UID
 * @param complete  返回字典包含 total_members, read_count, unread_count, read_members[]
 */
- (void)submitGroupReadStatsFromServer:(NSString *)groupId
                              msgTime2:(NSString *)msgTime2
                                  luid:(NSString *)luid
                              complete:(void (^)(BOOL success, NSDictionary * _Nullable result))complete;


// ========================== 黑名单管理 ==========================

/**
 * 【接口1008-2-27】拉黑用户接口调用.
 *
 * @param userUid 当前用户 UID（操作者）
 * @param blockedUid 要拉黑的目标用户 UID
 * @param complete 返回值：@"1" 成功 / 其他 失败
 */
- (void)submitBlockUserToServer:(NSString *)userUid
                     blockedUid:(NSString *)blockedUid
                       complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                  hudParentView:(UIView *)view;

/**
 * 【接口1008-2-28】取消拉黑接口调用.
 *
 * @param userUid 当前用户 UID
 * @param blockedUid 要取消拉黑的目标用户 UID
 * @param complete 返回值：@"1" 成功 / 其他 失败
 */
- (void)submitUnblockUserToServer:(NSString *)userUid
                       blockedUid:(NSString *)blockedUid
                         complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                    hudParentView:(UIView *)view;

/**
 * 【接口1008-2-29】查询黑名单列表接口调用.
 *
 * @param userUid 当前用户 UID
 * @param complete 返回值：黑名单用户数组（每项包含 user_uid, nickname, avatar, what_s_up, block_time）
 */
- (void)submitGetBlacklistFromServer:(NSString *)userUid
                            complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *blacklist))complete
                       hudParentView:(UIView *)view;

// ========================== 星标好友（1008-2-30 / 1008-2-31） ==========================

/** 【接口1008-2-30】星标好友。newData: user_uid, friend_user_uid。返回 "1" 成功，"0" 关系不存在 */
- (void)submitStarFriendToServer:(NSString *)userUid friendUid:(NSString *)friendUserUid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;
/** 【接口1008-2-31】取消星标好友。newData 同上。返回 "1" 成功，"0" 关系不存在 */
- (void)submitUnstarFriendToServer:(NSString *)userUid friendUid:(NSString *)friendUserUid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view;

@end
