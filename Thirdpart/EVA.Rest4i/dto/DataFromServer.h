//telegram @wz662
/**
 * <p>
 * 服务端返回数据的封装 对象(理论上服务端每次处理完后都会返回本对象，
 * 客户端可据此知道本次操作是否已经成功执行）.<br>
 * <p>
 *     处理成功则DataFromServer对象中的sucess字值会被设置成true且returnValue会设置成处理完成的返回的对象
 * ，否则sucess将被设置成false且returnValue里存放的将是错误消息文本（该文本不能保证一定不是null）
 * </p>
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
 * @author JackJiang
 */


#import <Foundation/Foundation.h>

@interface DataFromServer : NSObject

/** 处理成功与否的状态标识：true表示处理成功，反之表示失败 */
@property (nonatomic, assign) bool success;
/** 
 * 处理完成后的返回值（视具体业务而定
 * ，一般来讲，服务器端处理请求时如遇失败，则本对象默认是一个Exception对象）  */
@property (nonatomic, retain) NSString *returnValue;
/**
 * 返回码：
 * 1）-1：表示未设定（无意义）；
 * 2） 1：表示无效的token。
 *
 * @since 7.1
 */
@property (nonatomic, assign) int code;

@end
