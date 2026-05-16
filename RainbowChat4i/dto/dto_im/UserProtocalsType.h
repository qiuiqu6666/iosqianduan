//telegram @wz662
/**
 * RainbowChat中的用户自定义聊天消息、指令等IM通信协议类型常量表（之
 * 所以称为”用户自定义“，是为了区别于MobileIMSDK框架级的协议类型，仅此而已）。
 * <p>
 * 本表中的常量用途，对应用MobileIMSDK的net.openmob.mobileimsdk.server.protocal.Protocal
 * 对象的typeu字段（详见MobileIMSDK的文档：http://docs.52im.net/extend/docs/api/mobileimsdk/server/）。
 *
 * @author Jack Jiang(http://www.52im.net/space-uid-1.html)
 * @since 0.9
 */


/** 上线通知报文头 */
#define MT01_OF_ONLINE_NOTIVICATION     1
/** 下线通知报文头 */
#define MT02_OF_OFFLINE_NOTIVICATION    2

/** 普通一对一聊天消息的报文头（聊天消息可能是：文本、图片、语音留言、礼物等）
 * @see {MsgBody4Friend} */
#define MT03_OF_CHATTING_MESSAGE        3

/** 客户端发出的用户加好友请求报文头（由添加好友请求的发起人发出） */
#define MT05_OF_ADD_FRIEND_REQUEST_A_TO_SERVER                        5
/** 由服务端反馈给加好友发起人的错误信息头(出错的可能是：该好友已经存在于我的好友列表中、插入好友请求到db中时出错等) */
#define MT06_OF_ADD_FRIEND_REQUEST_RESPONSE_FOR_ERROR_SERVER_TO_A     6
/** 由服务端转发的加好友请求消息给在线目标用户（离线用户是不需要的哦） */
#define MT07_OF_ADD_FRIEND_REQUEST_INFO_SERVER_TO_B                   7
/** 被添加者【同意】加好友请求的消息头（由B发给服务端） */
#define MT08_OF_PROCESS_ADD_FRIEND_REQ_B_TO_SERVER_AGREE              8
/** 被添加者【拒绝】加好友请求的消息头（由B发给服务端） */
#define MT09_OF_PROCESS_ADD_FRIEND_REQ_B_TO_SERVER_REJECT             9
/**
 * 将【拒绝】的加好友结果传回给原请求用户的消息头（由服务端发回给A），此消息发送的
 * 前提条件是A必须此时必须在线，否则将不会实时发送给客户端 */
#define MT12_OF_PROCESS_ADD_FRIEND_REQ_SERVER_TO_A_REJECT_RESULT      12
/** 免验证加好友：你被对方直接添加为好友（由服务端发给被添加者B） */
#define MT13_OF_BE_ADDED_AS_FRIEND_NOTIFY_SERVER_TO_B                  13
/**
 * 新好友已成功被添加信息头（此场景是被请求用户同意了加好友的请求时，由服务端把双
 * 方的好友信息及时交给对方（如果双方有人在线的话）） */
#define MT10_OF_PROCESS_ADD_FRIEND_REQ_FRIEND_INFO_SERVER_TO_CLIENT   10
/**
 * 由服务端反馈给B处理（包括同意和拒绝两种情况下）加好友请求处理时的错误信
 * 息头(出错的可能是：B在提交同意A的加好友请求时出错了等) */
#define MT11_OF_PROCESS_ADD_FRIEND_REQ_RESPONSE_FOR_ERROR_SERVER_TO_B 11

/** 视频聊天进行中：结束本次音视频聊天 */
#define MT14_OF_VIDEO_VOICE_END_CHATTING                     14
/** 视频聊天进行中：切换到纯音频聊天模式 */
#define MT15_OF_VIDEO_VOICE_SWITCH_TO_VOICE_ONLY             15
/** 视频聊天进行中：切换回音视频聊天模式 */
#define MT16_OF_VIDEO_VOICE_SWITCH_TO_VOICE_AND_VIDEO        16

/** 视频聊天呼叫中：请求视频聊天(发起方A) */
#define MT17_OF_VIDEO_VOICE_REQUEST_REQUESTING_FROM_A        17
/** 视频聊天呼叫中：取消视频聊天请求(发起发A) */
#define MT18_OF_VIDEO_VOICE_REQUEST_ABRORT_FROM_A            18
/** 视频聊天呼叫中：同意视频聊天请求(接收方B) */
#define MT19_OF_VIDEO_VOICE_REQUEST_ACCEPT_TO_A              19
/** 视频聊天呼叫中：拒绝视频聊天请求(接收方B) */
#define MT20_OF_VIDEO_VOICE_REQUEST_REJECT_TO_A              20

/** 实时语音聊天呼叫中：请求实时语音聊天(发起方A) */
#define MT31_OF_REAL_TIME_VOICE_REQUEST_REQUESTING_FROM_A    31
/** 实时语音聊天呼叫中：取消实时语音聊天请求(发起发A) */
#define MT32_OF_REAL_TIME_VOICE_REQUEST_ABRORT_FROM_A        32
/** 实时语音聊天呼叫中：同意实时语音聊天请求(接收方B) */
#define MT33_OF_REAL_TIME_VOICE_REQUEST_ACCEPT_TO_A          33
/** 实时语音聊天呼叫中：拒绝实时语音聊天请求(接收方B) */
#define MT34_OF_REAL_TIME_VOICE_REQUEST_REJECT_TO_A          34
/** 实时语音聊天进行中：结束本次实时语音聊天 */
#define MT35_OF_REAL_TIME_VOICE_END_CHATTING                 35

/** 临时聊天消息：由发送人A发给服务端【步骤1/2】 */
#define MT42_OF_TEMP_CHAT_MSG_A_TO_SERVER                    42
/** 临时聊天消息：由服务端转发给接收人B的【步骤2/2】 */
#define MT43_OF_TEMP_CHAT_MSG_SERVER_TO_B                    43

/** 群聊/世界频道聊天消息：由发送人A发给服务端【步骤1/2】 */
#define MT44_OF_GROUP_CHAT_MSG_A_TO_SERVER                   44
/** 群聊/世界频道聊天消息：由服务端转发给所有在线接收人B的【步骤2/2】 */
#define MT45_OF_GROUP_CHAT_MSG_SERVER_TO_B                   45

/** 群聊系统指令：加群(建群或被邀请时)成功后通知被加群者（由Server发出，所有被加群者接收） */
#define MT46_OF_GROUP_SYSCMD_MYSELF_BE_INVITE_FROM_SERVER    46
/** 群聊系统指令：通用的系统信息给指定群员（由Server发出，指定群员接收） */
#define MT47_OF_GROUP_SYSCMD_COMMON_INFO_FROM_SERVER         47
/** 群聊系统指令：群已被解散（由Server发出，除解散者外的所有人接收） */
#define MT48_OF_GROUP_SYSCMD_DISMISSED_FROM_SERVER           48
/** 群聊系统指令："你"被踢出群聊（由Server发出，被踢者接收） */
#define MT49_OF_GROUP_SYSCMD_YOU_BE_KICKOUT_FROM_SERVER      49
/** 群聊系统指令："别人"主动退出或被群主踢出群聊（由Server发出，其它群员接收） */
#define MT50_OF_GROUP_SYSCMD_SOMEONEB_REMOVED_FROM_SERVER    50
/** 群聊系统指令：群名被修改的系统通知（由Server发出，所有除修改者外的群员接收） */
#define MT51_OF_GROUP_SYSCMD_GROUP_NAME_CHANGED_FROM_SERVER  51
/** 群通知：入群申请通知（由Server发出，管理员/群主接收） */
#define MT52_OF_GROUP_NOTIFY_JOIN_REQUEST                    52
/** 群通知：入群审核结果通知（由Server发出，申请人接收） */
#define MT53_OF_GROUP_NOTIFY_JOIN_REVIEW_RESULT              53
/** 群通知：群管理操作通知（由Server发出，相关人员接收） */
#define MT54_OF_GROUP_NOTIFY_ADMIN_OPERATION                 54
/** 群聊系统指令：群头像被修改（由Server发出，所有除修改者外的群员接收） */
#define MT55_OF_GROUP_SYSCMD_GROUP_AVATAR_CHANGED_FROM_SERVER 55
/** 群聊系统指令：群禁言模式变更（由Server发出，群成员接收） */
#define MT56_OF_GROUP_SYSCMD_GROUP_MUTE_MODE_CHANGED_FROM_SERVER 56
/** 群聊系统指令：邀请权限变更（由Server发出，群成员接收） */
#define MT57_OF_GROUP_SYSCMD_GROUP_INVITE_PERMISSION_CHANGED_FROM_SERVER 57
/** 群聊系统指令：成员隐私保护变更（由Server发出，群成员接收） */
#define MT58_OF_GROUP_SYSCMD_GROUP_MEMBER_PRIVACY_CHANGED_FROM_SERVER 58
/** 群聊系统指令：管理员设置/取消（由Server发出，群成员接收） */
#define MT59_OF_GROUP_SYSCMD_GROUP_ADMIN_CHANGED_FROM_SERVER 59
/** 群聊系统指令：入群方式变更（由Server发出，群成员接收） */
#define MT60_OF_GROUP_SYSCMD_GROUP_JOIN_MODE_CHANGED_FROM_SERVER 60

/**
 * 服务端下发的聊天消息体同步（JSON 与 {@link MT03_OF_CHATTING_MESSAGE} 的 MsgBodyRoot 同构；发送方 userid 常为 "0"）。
 * 用于服务端回显/多端同步等；若按「非法」丢弃会导致当前会话 UI 与送达状态偶发不同步（见 rizhi：typeu=65）。
 * @since 协议扩展 2026
 */
#define MT65_OF_CHATTING_MESSAGE_SERVER_SYNC                   65

//---------------------------------------------------------------------------- 已读与送达（IM）START
/** 已读回执通知：对方已读后实时通知消息发送方 */
#define MT61_OF_READ_RECEIPT_NOTIFY                          61
/**
 * 多端/服务端状态同步（IM）：外层 JSON 含 `action`、`data`（`data` 常为 JSON 字符串需二次解析）。
 * 常见 action：`read_receipt`、`delete_single`、`delete_conversation`、`clear_all` 等。
 * 与 MT61 互补：MT61 偏实时已读通知（reader_uid/chat_partner_id）；MT62 偏 state_ops 同构（partner_id 等）。
 */
#define MT62_OF_READ_RECEIPT_STATE_SYNC_FROM_SERVER          62
/** 已送达回执：消息已被对方设备接收（QoS ACK 后触发） */
#define MT63_OF_DELIVERY_RECEIPT                             63
/** 已读回执：客户端经 IM 上报（dataContent JSON 与 HTTP 1008-4-24 一致，服务端共落库） */
#define MT64_OF_READ_RECEIPT_CLIENT_TO_SERVER                64
/** 发送失败通知：因对方已不是好友而被服务端拦截。 */
#define MT70_OF_FRIENDSHIP_REQUIRED_SEND_FAIL_HINT           70
//---------------------------------------------------------------------------- 已读与送达（IM）END
