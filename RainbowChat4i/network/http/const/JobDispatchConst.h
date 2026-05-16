//telegram @wz662
/**
 * 本文件中的常量为RainbowChat的Http Rest接口的作业调度id常量定义表。
 *
 * 【关于Http Rest服务的请求处理逻辑说明】：
 * 目前RainbowChat的Http服务器基于EVA.PC的MVC框架编写，此框架的服务端处理逻辑为
 * 先根据Processor id（处理器id）找到对应用的Processor后，再据JobDispatchID（作业
 * 调度id）找到作业调度代码，最后再据ActionID（动作id）找到最终的rest接口实现代码，如
 * 下图所示。
 *
 * 【服务端HTTP Server的MVC之核心控制器实现逻辑图】：
 * -------------------------------------------- EVA.EPC系统数据处理逻辑流程 ----------------------------------------------
 * http请求 => Controller子类(MVC控制器) -> Processor子类(处理器) -> JobDispatcher方法(作业调度器) -> Action代码段(动作)
 *                                       |                        |                                |
 *                                [processor_id]        [job_dispatch_id]                  [action_id]
 * ---------------------------------------------------------------------------------------------------------------------
 *
 * @author Jack Jiang
 * @version 1.0
 */

#ifndef JobDispatchConst_h
#define JobDispatchConst_h

/** 注册相关的作业调度id */
#define JOB_LOGIC_REGISTER      1

/** 好友列表管理的作业调度id */
#define JOB_LOGIC_ROSTER        2

/** 好友关系管理的作业调度id */
#define JOB_LOGIC_SNS           3

/** 消息相关的作业调度id */
#define JOB_LOGIC_MESSAGES      4

/** 删除好友的作业调度id */
#define JOB_LOGIC_DELETE_FRIEND 5

/** 个人相册、个人介绍语音留言等的管理的作业调度id */
#define JOB_LOGIC_MGR_PROFILE   10

/** 礼品、积分相关的作业调度id */
#define JOB_LOGIC_GIFTANDSCORE  21

/**
 * 服务端对外提供的文件信息查询等接口的调度id.
 * @since 4.3
 */
#define LOGIC_FILE_MGR          23

/**
 * 服务端对外提供的群组基本管理接口的调度id.
 * @since 4.3
 */
#define LOGIC_GROUP_BASE_MGR    24

/**
 * 服务端对外提供的群组相关信息查询接口的调度id.
 * @since 4.3
 */
#define LOGIC_GROUP_QUERY_MGR   25

/**
 * 服务端对外提供的消息漫游（会话列表和聊天记录查询）接口的调度id.
 * @since 11.x
 */
#define JOB_LOGIC_MSG_ROAMING   26

/**
 * 收藏功能的作业调度id.
 */
#define JOB_LOGIC_FAVORITES     27

/**
 * 自定义表情包功能的作业调度id.
 */
#define JOB_LOGIC_STICKER       28

/**
 * 钱包相关作业调度id（资金密码、余额、转账、流水等）.
 * @since 零钱功能
 */
#define LOGIC_WALLET            30

#endif /* JobDispatchConst_h */
