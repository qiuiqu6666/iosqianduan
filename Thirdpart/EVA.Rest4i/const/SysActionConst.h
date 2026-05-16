//telegram @wz662
/**
 * <p>
 * EVA.EPC框架之预定义action_id（操作动作id）常量表.<br>
 * 这些常量对应于EVA.EPC整个MVC框架中的action_id.<br>
 * 本常量表仅为了方便使用而作，没有更多却确含义，各常量意义视具体业务而定.
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

#ifndef SysActionConst_h
#define SysActionConst_h


#endif /* SysActionConst_h */


/** 新增 */
#define ACTION_NEW    0
/** 编辑 */
#define ACTION_EDIT   1
/** 删除 */
#define ACTION_REMOVE 2
/** 审核 */
#define ACTION_VERIFY 3
/** 打印 */
#define ACTION_PRINT  4
/** 查询 */
#define ACTION_QUERY  5

/** 附加备用常量 */
#define ACTION_APPEND1  7
#define ACTION_APPEND2  8
#define ACTION_APPEND3  9
#define ACTION_APPEND4  22
#define ACTION_APPEND5  23
#define ACTION_APPEND6  24
#define ACTION_APPEND7  25
#define ACTION_APPEND8  26
#define ACTION_APPEND9  27
#define ACTION_APPEND10 28
#define ACTION_APPEND11 29
#define ACTION_APPEND12 30
#define ACTION_APPEND13 31
#define ACTION_APPEND14 32
#define ACTION_APPEND15 33

/** 取消审核 */
#define ACTION_CANCEL_VERIFY 12
/** 批量删除 */
#define ACTION_MULTI_DEL     19
/** 批量增加 */
#define ACTION_MULTI_ADD     20
/** 批量审核 */
#define ACTION_MULTI_CHECK   21



