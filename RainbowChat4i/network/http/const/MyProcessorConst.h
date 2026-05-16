//telegram @wz662
/**
 * 本文件中的常量为RainbowChat的Http Rest接口的Processor id常量定义表。
 *
 * 注：1000以内的processor_id用作系统保留，自定义的processor_id只能使用1000以外的，使用
 * 时推存继承SysProcessorConst常量表后再自定义自已的常量。
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
 * @author Jack Jiang, 2017-11-10
 * @version 1.0
 */


#ifndef MyProcessorConst_h
#define MyProcessorConst_h

#import "SysProcessorConst.h"
#import "JobDispatchConst.h"

/** 业务逻辑功能的processor_id常量 */
#define PROCESSOR_LOGIC          1008
/** 用户上传2进制数据（包括图片、语音留言等）的processor_id常量 */
#define PROCESSOR_UPLOAD_BINARY  1011
/** 礼品、积分相关请求的processor_id常量 */
#define PROCESSOR_GIFT           1012
/** 登陆认证请求的processor_id常量（本接口Android、iOS等客户端均使用） */
#define PROCESSOR_LOGIN_4ALL     1013
/** 一些专用于后台管理的特权接口的processor_id常量（原则上特权接口禁止客户端调用） */
#define PROCESSOR_ADMIN          1014

/** 大文件信息本询等请求的处理器id */
#define PROCESSOR_FILE           1015
/** 群组聊天相关http请求的处理器id */
#define PROCESSOR_GROUP_CHAT     1016

/**
 *登陆认证请求处理器id（本接口Android、iOS等客户端均使用） v2版
 *
 * @since 10.0
 */
#define PROCESSOR_LOGIN_4ALL_V2  1017

/** 钱包相关请求的 processor_id（资金密码、余额、转账、流水等）. @since 零钱功能 */
#define PROCESSOR_WALLET         1018

/** TRX 链上钱包相关请求的 processor_id（地址、TRX/USDT 余额、充值/提现等）. */
#define PROCESSOR_TRX_WALLET     1019

/** 注册登陆认证请求的processor_id常量（本接口Android、iOS等客户端均使用） */
#define PROCESSOR_LOGOUT         -2


#endif /* MyProcessorConst_h */


