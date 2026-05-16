//telegram @wz662
/**
 * iOS客户端使用的HTTP服务工厂类.<br>
 * <p>
 * 在不特殊指明的情况下，使用默认服务即可，在使服对应服务前必须保证已经添加了对应的服务实例到
 * 列表中（调用  {@link #addServices(String, String, String, boolean)}等）  ，之后直接调
 * 用 {@link #getService(String)}即可取得指定的服务实例、调用 {@link #getServices()}
 * 取得默认服务实例引用.<br><br>
 *
 * <b>特别注意：</b>现时HttpService的设计思路，允许多个HTTP服务（MVC控制器）存在，但必须确保它们
 * 处于同一个WEB模块下（不允许连接到不同的WEB应用模块上）。
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
 * @author Jack Jiang, 2017-02-25
 * @version 1.0
 */

#import <Foundation/Foundation.h>
#import "HttpService.h"

/** 默认服务存放于服务实例列表中的键名 */
#define DEFAULT_SERVICE_NAME "default_service"


@interface HttpServiceFactory : NSObject

/**
 * 添加一个默认服务实例到列表中（默认不允许覆盖列表中的同名服务实例）.
 * serviceName为默认值 DEFAULT_SERVICE_NAME。
 *
 * @param httpURL http rest服务的URL地址，形如: http://127.0.0.1:8080/rest
 * @see #addServices(String, String, String, boolean)
 */
+ (void) addServices:(NSString *)httpURL;

/**
 * 添加一个服务实例到列表中（默认不允许覆盖列表中的同名服务实例）.
 *
 * @param serviceName 服务名
 * @param httpURL http rest服务的URL地址，形如: http://127.0.0.1:8080/rest
 * @see #addServices(String, String, String, boolean)
 */
+ (void) addServices:(NSString *)serviceName withURL:(NSString *)httpURL;

/**
 * 添加一个服务实例到列表中.
 *
 * @param serviceName 服务名
 * @param httpURL http rest服务的URL地址，形如: http://127.0.0.1:8080/rest
 * @param overWrite 如果要添加的服务已经添加到列表中了（据服务名称）
 * 	，是重写还是抛出异常（不允许重写），true表示无条件用新服务实例覆盖已经存在服务实例，否则抛出异常（不允许覆盖）
 */
+ (void) addServices:(NSString *)serviceName withURL:(NSString *)httpURL overWriteIfExists:(bool)overWrite;

/**
 * 获取指定服务名的服务实例引用.
 * @param serviceName 服务名
 * @return  如果该服务实例已经被实例化并放入了列表中则返回它的引用，否则返回null
 */
+ (HttpService *) getService:(NSString *)serviceName;

/**
 * 获得默认的服务实例.
 * @return 如果该默认服务实例已经被实例化并放入了列表中则返回它的引用，否则返回null
 * @see #DEFAULT_SERVICE_NAME
 */
+ (HttpService *) getDefaultService;

/**
 * 获得服务实例列表对象.
 * @return 实例列表
 */
+ (NSMutableDictionary<NSString *, HttpService *> *) getServices;

@end
