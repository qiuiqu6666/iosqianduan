//telegram @wz662
/**
 * <p>
 *  <b>一个封装了与指定HTTP服务通信及相关操作方法的Http操作类.</b><br>
 *  使用本类即可完成与任一远程HTTP服务通信的功能.<br><br>
 *
 *  <b>特别注意：</b>现时HttpService的设计思路，允许多个HTTP服务（MVC控制器）存在，但必须确保它们
 *     处于同一个WEB模块下（不允许连接到不同的WEB应用模块上）。
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
#import "AFHTTPSessionManager.h"

@interface HttpService : NSObject

// 网络请求超时时间
#define kTimeOutInterval 10

// 网络请求方法define
typedef enum {
    GET,
    POST,
    PUT,
    DELETE,
    HEAD
} HTTPMethod;


- (id)initWithURL:(NSString *)httpURL;

/**
 EVA框架的iOS版HTTP REST数据请求方法。

 @param processorId 必填参数，HTTP REST 框架需要的processorId
 @param jobDispatchId 非必填参数，HTTP REST 框架需要的jobDispatchId，如未无请填-1
 @param actionId 非必填参数，HTTP REST 框架需要的actionId，如未无请填-1
 @param newObj 发送到服务端的newData对象（本方法内部会自动将对象转成JSON文本）。注：因目前找到的JSON转换库能力有限，目前本对象仅支
               持扁平对象、NSData、NSDictionary类（及其子类）、NSArray类（及其子类），NSArray类（及其子类）的嵌套多维数组等数
               据传输对象，你也可以在传进来前自已想办法转成本方法支持的对象即可。
 @param complete 数据回调，参数 sucess表示请求有无处理成功、returnValue表示返回数据（当sucess==YES时为真的数据，否则为错误原因），
                 returnValue返回的一定是NSString文本（可能是JSON文本，也可能只是普通的字串，具体由上层业务逻辑视情况使用）
 @param view 本参数为nil表示不显示请求处理中的菊花，否则表示要显示菊花

 */
- (void)sendObjToServer:(int)processorId
            andDispatch:(int)jobDispatchId
              andAction:(int)actionId
            withNewData:(id)newObj
               complete:(void (^)(BOOL sucess, NSString *returnValue))complete
          hudParentView:(UIView *)view;

/**
 EVA框架的iOS版HTTP REST数据请求方法。

 @param processorId 必填参数，HTTP REST 框架需要的processorId
 @param jobDispatchId 非必填参数，HTTP REST 框架需要的jobDispatchId，如未无请填-1
 @param actionId 非必填参数，HTTP REST 框架需要的actionId，如未无请填-1
 @param newObj 发送到服务端的newData对象（本方法内部会自动将对象转成JSON文本）。注：因目前找到的JSON转换库能力有限，目前本对象仅支
               持扁平对象、NSData、NSDictionary类（及其子类）、NSArray类（及其子类），NSArray类（及其子类）的嵌套多维数组等数
               据传输对象，你也可以在传进来前自已想办法转成本方法支持的对象即可。
 @param progress 上传进度回调block，参数progressValue的值为0~1.0的浮点数（1.0表示上传完成）
 @param complete 数据回调，参数 sucess表示请求有无处理成功、returnValue表示返回数据（当sucess==YES时为真的数据，否则为错误原因），
                 returnValue返回的一定是NSString文本（可能是JSON文本，也可能只是普通的字串，具体由上层业务逻辑视情况使用）
 @param view 本参数为nil表示不显示请求处理中的菊花，否则表示要显示菊花
 */
- (void)sendObjToServer:(int)processorId
            andDispatch:(int)jobDispatchId
              andAction:(int)actionId
            withNewData:(id)newObj
               progress:(void (^)(float progressValue))progress
               complete:(void (^)(BOOL sucess, NSString *returnValue))complete
          hudParentView:(UIView *)view;

/**
 EVA框架的iOS版HTTP REST数据请求方法。

 @param processorId 必填参数，HTTP REST 框架需要的processorId
 @param jobDispatchId 非必填参数，HTTP REST 框架需要的jobDispatchId，如未无请填-1
 @param actionId 非必填参数，HTTP REST 框架需要的actionId，如未无请填-1
 @param newObj 发送到服务端的newData对象（本方法内部会自动将对象转成JSON文本）。注：因目前找到的JSON转换库能力有限，目前本对象仅支
               持扁平对象、NSData、NSDictionary类（及其子类）、NSArray类（及其子类），NSArray类（及其子类）的嵌套多维数组等数
               据传输对象，你也可以在传进来前自已想办法转成本方法支持的对象即可。
 @param oldData 发送到服务端的oldData对象（本方法内部会自动将对象转成JSON文本）。注：因目前找到的JSON转换库能力有限，目前本对象仅支
               持扁平对象、NSData、NSDictionary类（及其子类）、NSArray类（及其子类），NSArray类（及其子类）的嵌套多维数组等数
               据传输对象，你也可以在传进来前自已想办法转成本方法支持的对象即可。
 @param progress 上传进度回调block，参数progressValue的值为0~1.0的浮点数（1.0表示上传完成）
 @param complete 数据回调，参数 sucess表示请求有无处理成功、returnValue表示返回数据（当sucess==YES时为真的数据，否则为错误原因），
                 returnValue返回的一定是NSString文本（可能是JSON文本，也可能只是普通的字串，具体由上层业务逻辑视情况使用）
 @param view 本参数为nil表示不显示请求处理中的菊花，否则表示要显示菊花
 @param showLocalErrorAlert 本地发生了错误：比如连接超时、本地网络有问题、发送的数据有问题等等请求还没送到服务器前的这些错误时是否显示一个错误提示框，如不理解本参数含义请设为YES
 @param completeForLocalError 本地发生了错误：比如连接超时、本地网络有问题、发送的数据有问题等等请求还没送到服务器前的这些错误时是否调用本参数指明的回调，如不理解本参数含义请设为nil
 */
- (void)sendObjToServer:(int)processorId
            andDispatch:(int)jobDispatchId
              andAction:(int)actionId
            withNewData:(id)newObj
             andOldData:(id)oldData
               progress:(void (^)(float progressValue))progress
               complete:(void (^)(BOOL sucess, NSString *returnValue))complete
          hudParentView:(UIView *)view
    showLocalErrorAlert:(BOOL)showLocalErrorAlert
  completeForLocalError:(void (^)(NSString *errorLog))completeForLocalError;


@end
