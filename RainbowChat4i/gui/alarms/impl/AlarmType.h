//telegram @wz662
/**
 * 主页“消息”提示界面里的信息类型常量定义.
 */

#ifndef AlarmMessageType_h
#define AlarmMessageType_h


#define AMT_undefine            0

/** 添加好友请求 */
#define AMT_addFriendRequest    1
/** 加好友被拒绝 */
#define AMT_addFriendBeReject   2

/** 好友聊天消息 */
#define AMT_friendChatMessage   4

/** 系统预定义提示：Help */
#define AMT_systemDevTeam       6
/** 系统预定义提示：Q&A */
#define AMT_systemQNA           7

/** 临时(陌生人)聊天消息 */
#define AMT_guestChatMessage    8

/** 添加好友时服务端反馈的出错信息（比如服务端在执行的过程中出错等等，这肯定是要让好友请求发起方知道的，不然这请求到底去哪里了？对方有没有收到呢？） */
#define AMT_addFriendThrowError 9

/** 普通群聊聊天消息 */
#define AMT_groupChatMessage    10




#endif /* AlarmMessageType_h */
