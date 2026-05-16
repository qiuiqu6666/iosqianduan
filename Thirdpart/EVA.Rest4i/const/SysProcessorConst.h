//telegram @wz662
/**
 * <p>
 * EVA.EPC框架之预定义系统保留的processor_id常量表.<br>
 * 它们对应于系统级的processor的id.<br>
 * 注：1000以内的processor_id用作系统保留，自定义的processor_id只能使用1000以外的，使用
 * 时推荐继承本常量表后再自定义自已的常量。
 * </p>
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
 * @author Jack Jiang, 2017-03-08
 * @version 1.0
 */

#ifndef SysProcessorConst_h
#define SysProcessorConst_h


#endif /* SysProcessorConst_h */


/** 系统登陆 */
#define PROCESSSOR_LOGIN   -1
/** 退出登陆 */
#define PROCESSSOR_LOGOUT  -2

/** 系统一些默认功能的处理器id *///就是以前的PROCESSSOR_FRAME
#define PROCESSSOR_FW_BASE  0//0xf423f;
#define PROCESSSOR_AUTH     1//1001;
#define PROCESSSOR_OA       2//2001;
#define PROCESSSOR_NOTICE   3//9001;
/** 文件管理 */
#define PROCESSSOR_DOC      4//1003;
/** 工作流管理 */
#define PROCESSSOR_WORKFLOW 5
