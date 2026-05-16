//telegram @wz662
#import "HttpService.h"
#import "DataFromClient.h"
#import "EVAToolKits.h"
#import "DataFromServer.h"
#import "EVACharsetHelper.h"
#import "UserEntity.h"
#import "MBProgressHUD.h"
#import "IMClientManager.h"

@interface HttpService ()

@property (nonatomic, retain) AFHTTPSessionManager *manager;
@property (nonatomic, retain) NSString *url;

@end

// 静态变量：记录上次弹出网络错误提示的时间（用于防重复弹出）
static NSTimeInterval sLastNetworkErrorAlertTime = 0;
static const NSTimeInterval kNetworkErrorAlertInterval = 20.0; // 20秒内只弹出一次


@implementation HttpService

- (id)initWithURL:(NSString *)httpURL
{
    if (![super init])
        return nil;

    self.url = httpURL;

    NSParameterAssert(self.url != nil);



    // 内部变量初始化
    [self initManager:[EVAToolKits isHttps:self.url]];

    NSLog(@"[EVA.HTTP] HttpService已经init了！");

    return self;
}

- (void) initManager:(BOOL)supportHttps
{
    self.manager = [HttpService getManager:supportHttps];

//    // 请求超时设定
//    self.manager.requestSerializer.timeoutInterval = kTimeOutInterval;
//    self.manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
//    [self.manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
////    [self.manager.requestSerializer setValue:url.absoluteString forHTTPHeaderField:@"Referer"];
//    self.manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/plain", @"text/javascript", @"text/json", @"text/html", nil];
//    self.manager.securityPolicy.allowInvalidCertificates = YES;
}

- (void)requestWithMethod:(HTTPMethod)method
                   params:(NSDictionary*)params
                 progress:(void (^)(NSProgress * _Nonnull))downloadProgress
                  success:(void (^)(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject))sucess
                  failure:(void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure
{
    switch (method)
    {
        case GET:
        {
            [self.manager GET:self.url parameters:params headers:nil progress:downloadProgress success:sucess failure:failure];
            break;
        }
        case POST:
        {
            [self.manager POST:self.url parameters:params headers:nil progress:downloadProgress success:sucess failure:failure];
            break;
        }
        default:
            break;
    }
}

- (void)sendObjToServer:(int)processorId
            andDispatch:(int)jobDispatchId
              andAction:(int)actionId
            withNewData:(id)newObj
               complete:(void (^)(BOOL sucess, NSString *returnValue))complete
          hudParentView:(UIView *)view
{
    [self sendObjToServer:processorId andDispatch:jobDispatchId andAction:actionId withNewData:newObj progress:nil complete:complete hudParentView:view];
}

- (void)sendObjToServer:(int)processorId
            andDispatch:(int)jobDispatchId
              andAction:(int)actionId
            withNewData:(id)newObj
               progress:(void (^)(float progressValue))progress
               complete:(void (^)(BOOL sucess, NSString *returnValue))complete
          hudParentView:(UIView *)view
{
    [self sendObjToServer:processorId andDispatch:jobDispatchId andAction:actionId withNewData:newObj andOldData:nil progress:progress complete:complete hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

- (void)sendObjToServer:(int)processorId
            andDispatch:(int)jobDispatchId
              andAction:(int)actionId
            withNewData:(id)newObj
             andOldData:(id)oldData
               progress:(void (^)(float progressValue))progress
               complete:(void (^)(BOOL sucess, NSString *returnValue))complete
          hudParentView:(UIView *)view
    showLocalErrorAlert:(BOOL)showLocalErrorAlert
  completeForLocalError:(void (^)(NSString *errorLog))completeForLocalError
{
    // 全局静默请求：不显示转圈 HUD，所有接口统一不弹 loading
    view = nil;
    DataFromClient *dfs = [[DataFromClient alloc] init];
    dfs.processorId = processorId;
    dfs.jobDispatchId = jobDispatchId;
    dfs.actionId = actionId;
    dfs.device = 1; // 当前默认的约定是：0 android平台、1 ios平台、2 web平台。
    dfs.token = [IMClientManager sharedInstance].localUserInfo.token;// token for http auth
    // 未启用 token 校验时：登录可能返回 token "N/A"，请求钱包等接口用 user_uid 作为 token 兜底（见 API 文档 1.2）
    if (!dfs.token || dfs.token.length == 0 || [dfs.token isEqualToString:@"N/A"]) {
        NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        if (uid && uid.length > 0) dfs.token = uid;
    }

    NSString *newDataToJSON = nil;
    NSString *oldDataToJSON = nil;
    if(newObj)
    {
        // 如果传进来的就是个字符串，那就没有必要再转成JSON字符串了，否则也转不了啊，神精病了
        newDataToJSON = [EVAToolKits isString:newObj]?newObj : [EVAToolKits toJSON:newObj];
    }
    if(oldData)
    {
        // 如果传进来的就是个字符串，那就没有必要再转成JSON字符串了，否则也转不了啊，神精病了
        oldDataToJSON = [EVAToolKits isString:oldData]?oldData : [EVAToolKits toJSON:oldData];
    }

//    NSLog(@"[EVA.HTTP] 要发送的数据内容：newDataJSON=%@, oldDataJSON=%@", newDataToJSON, oldDataToJSON);

    NSMutableDictionary *dfsDic = [EVAToolKits toMutableDictionary:dfs];

    // 因与ios中的newData关键字冲突，此处手动往字典中加一条newData属性
    if(newDataToJSON)
        [dfsDic setObject:newDataToJSON forKey:@"newData"];

    NSLog(@"[EVA.HTTP]【接口%@】发送给服务端的JSON：%@", [HttpService printRestNum:processorId dispatchid:jobDispatchId actionid:actionId], dfsDic);

    // 决定是否要显示进度提示菊花
    if (view != nil) {
        if (![NSThread isMainThread]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD showHUDAddedTo:view animated:NO];
            });
        }
        else {
            [MBProgressHUD showHUDAddedTo:view animated:NO];
        }
    }

    // 开始将http请交提交网络
    [self requestWithMethod:POST
                   params:dfsDic
                 progress:^(NSProgress * _Nonnull uploadProgress) {
                     float pv = 1.0 * uploadProgress.completedUnitCount / uploadProgress.totalUnitCount;
//                   NSLog(@"[EVA.HTTP] 数据发送进度> %lf", pv);

                     if(progress)
                     {
                         // 上传进度回调
                         progress(pv);
                     }
                 } success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable _responseObject) {

                     // 将http返回结果处理代码独立成一个block，便于下方的重用（而不用copy而产生冗余代码）
                     void (^resultProcessBlock)(id _Nullable resultObj) = ^(id _Nullable resultObj) {

                         // 服务端有数据返回，表示hTTP请求已正常送达并被EVA框架处理完成
                         if(resultObj)
                         {
                             NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:resultObj options:NSJSONReadingMutableContainers error:nil];

                             // 从服务端返回的结果数据中反射成DataFromServer对象方便使用
                             DataFromServer *dfs = [EVAToolKits fromDictionaryToObject:dict withClass:DataFromServer.class];

                             // ## Bug FIX: 20171114 by JackJiang START
                             // 因服务端接口返回的Java null值，在iOS端被反序列化成JSON字串时会把java的null值变成OC的@"null"字串，
                             // 所以此处要处理掉@"null"情况，以便使用http接口的代码不会被此误倒而导致代码判断失效
                             if(Obj_IS_NIL([dfs returnValue]))
                                 dfs.returnValue = nil;
                             // ## Bug FIX: 20171114 by JackJiang END

                             // 服务端处理成功了
                             if([dfs success])
                             {
                                 NSLog(@"[EVA.HTTP] 【服务端处理成功完成】请求返回了, retValue=%@", [dfs returnValue]);
                                 if(complete)
                                     complete(YES, [dfs returnValue]);
                             }
                             // 服务端处理失败了
                             else
                             {
                                 // 根据接口约定，当返回code=1时，表示“无效的token”错误，此处单独处理，无需将错误穿透到应用层调用者
                                 if(dfs.code == 1) {
                                     // 显示提示信息
                                     [BasicTool showAlertAndGotoLogin:@"请重新登录" content:@"Token已失效，请重新登陆后再试。点击下方按钮将自动跳转到登录界面。"];
                                     
                                 } else {
                                     NSLog(@"[EVA.HTTP] 【服务端处理完成但出错了】请求返回了, retValue=%@", [dfs returnValue]);
                                     if(complete)
                                         complete(NO, [dfs returnValue]);
                                 }
                             }
                         }
                         // 没有数据返回，这是不正常的（EVA框架一定会保证发送回DataFromServer对象的JSON形式）
                         else
                         {
                             NSString *errorLog = [NSString stringWithFormat:@"[EVA.HTTP] 【错误】请求成功返回了，但无返回数据，%@", resultObj];
                             NSLog(@"%@",errorLog);

                             if(complete)
                                 complete(NO, errorLog);
                         }
                     };

                     // 如果显示了HUD菊花，则要退出菊花的显示
                     if (view != nil)
                     {
                         if (![NSThread isMainThread])
                         {
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 // 退出菊花
                                 [MBProgressHUD hideHUDForView:view animated:NO];

                                 // 真正的http返回结果处理
                                 resultProcessBlock(_responseObject);
                             });
                             return;
                         }
                         else
                         {
                             [MBProgressHUD hideHUDForView:view animated:NO];
                         }
                     }

                     // 真正的http返回结果处理
                     resultProcessBlock(_responseObject);

                 }  // 本地发生了错误：比如连接超时、本地网络有问题、发送的数据有问题等等请求还没送到服务器前的这些错误
                    failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {

                     // 如果显示了HUD菊花，则要退出菊花的显示
                     if (view != nil)
                     {
                         if (![NSThread isMainThread])
                         {
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 // 退出菊花
                                 [MBProgressHUD hideHUDForView:view animated:NO];
                             });
                             return;
                         }
                         else
                         {
                             [MBProgressHUD hideHUDForView:view animated:NO];
                         }
                     }

                     NSString *errorLog = [NSString stringWithFormat:@"[EVA.HTTP] HTTP请求失败了：%@", error];
                     NSLog(@"%@",errorLog);
        
//                     complete(NO, errorLog);// 20191007取消了本行代码的注释状态！
        
                     // 单独设置是否需要在本地网络问题出现时通知回调
                     if(completeForLocalError)
                         completeForLocalError(errorLog);

                     // 不弹窗：静默重连，延迟后重新请求一次
                     if (showLocalErrorAlert) {
                         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                             [self sendObjToServer:processorId andDispatch:jobDispatchId andAction:actionId withNewData:newObj andOldData:oldData progress:progress complete:complete hudParentView:view showLocalErrorAlert:NO completeForLocalError:completeForLocalError];
                         });
                         return;
                     }
                     if (complete)
                         complete(NO, errorLog);
                 }
     ];
}

// 打印rest接口的编号，方便调试
+ (NSString *)printRestNum:(int)processorId dispatchid:(int)jobDispatchId actionid:(int)actionId
{
    NSMutableString *ret = [[NSMutableString alloc] initWithFormat:@""];
    if(processorId > 0)
        [ret appendFormat:@"%d", processorId];
    if(jobDispatchId > 0)
        [ret appendFormat:@"-%d", jobDispatchId];
    if(actionId > 0)
       [ret appendFormat:@"-%d", actionId];

    return ret;
}


#pragma mark - 创建请求者

+ (AFHTTPSessionManager *) getManager:(BOOL)supportHttps
{
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];

    // 声明上传的是json格式的参数，需要你和后台约定好，不然会出现后台无法获取到你上传的参数问题
    // manager.requestSerializer = [AFHTTPRequestSerializer serializer]; // 上传普通格式
    manager.requestSerializer = [AFJSONRequestSerializer serializer];    // 上传JSON格式

    // 声明获取到的数据格式
    // 个人建议还是自己解析的比较好，有时接口返回的数据不合格会报3840错误，大致是AFN无法解析返回来的数据
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];   // AFN不会解析,数据是data，需要自己解析
    // manager.responseSerializer = [AFJSONResponseSerializer serializer];// AFN会JSON解析返回的数据

    // 设置请求的超时时间
    manager.requestSerializer.timeoutInterval = kTimeOutInterval;

    // 支持https的额外设置
    if(supportHttps)
    {
        // 支持https需要的额外设置
        [EVAToolKits setupHttps:manager];
    }

    return manager;
}




@end
