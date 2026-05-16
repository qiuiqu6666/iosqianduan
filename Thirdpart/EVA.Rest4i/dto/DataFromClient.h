//telegram @wz662
/**
 * <p>
 * 为了简化系统逻辑，本对象是EVA.EPC框架发送给服务端的唯一对像类型，所以要发送
 * 给服务器的对象都必须是此类（及其子类）的实例.<br>
 *
 * 关于整个MVC框架捕获和处理客户端请求的流程，请参见：{@link com.eva.epc.core.ends.Controller}.
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
 * @author Jack Jiang
 * @version 1.0
 */


#import <Foundation/Foundation.h>

@interface DataFromClient : NSObject

/**
 * 客户端是否需要读取服务端返回的数据（对服务端而言就是是否需要写返回写据给客户端
 * ，服务端将据此决定是否要写回数据），本字段对应于 HttpURLConnection.setDoInput(boolean)
 * 并与之保持一致。
 * 注：本字段仅用于底层数据通信，请勿作其它用途！ */
@property (nonatomic, assign) bool doInput;

/** 业务处理器id
 * @see  com.eva.epc.Controller.ends.core.Controller */
@property (nonatomic, assign) int processorId;
/** 作业调度器id
 * @see  com.eva.epc.Controller.ends.core.Controller */
@property (nonatomic, assign) int jobDispatchId;
/** 动作id
 * @see  com.eva.epc.Controller.ends.core.Controller */
@property (nonatomic, assign) int actionId;

/** 具体业务中：客端发送过来的本次修改新数据(可能为空，理论上与oldData不会同时空）*/
@property (nonatomic, retain) NSString *data; // TODO: newData在OC里有特殊意义，所以此处不能写成newData!
/** 具体业务中：客端发送过来的本次修改前的老数据(可能为空，理论上与newData不会同时空）*/
@property (nonatomic, retain) NSString *oldData;

/**
 * 可用于REST请求时客户端携带到服务端作为身份验证之用。
 * <p>
 * 本字段可由框架使用者按需使用，非EVA框架必须的。
 *
 * @since 20170223
 */
@property (nonatomic, retain) NSString *token;

/**
 * 发起HTTP请求的设备类型（默认值为-1，表示未定义）.
 * 此字段为保留字段，具体意义由开发者可自行决定。
 * <p>
 * 当前默认的约定是：0 android平台、1 ios平台、2 web平台。
 */
@property (nonatomic, assign) int device;

@end
