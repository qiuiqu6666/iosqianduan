//telegram @wz662
#import "HttpRestHelper.h"
#import "EVAToolKits.h"
#import "DataFromClient.h"
#import "AFNetworking.h"
#import "DataFromServer.h"
#import "EVACharsetHelper.h"
#import "HttpServiceFactory.h"
#import "MyProcessorConst.h"
#import "SysActionConst.h"
#import "UserRegisterDTO.h"
#import "EVACharsetHelper.h"
#import "IMClientManager.h"
#import "UserEntity.h"
#import "Default.h"
#import "JobDispatchConst.h"

/// 1008-26-41 / 26-42 与服务端 SysActionConst 扩展对齐（actionId 41 / 42）
static const int kActionChatMsgSearchInConversation = 41;
static const int kActionChatMsgSearchGlobal = 42;
static const int kJobDispatchGroupNotifications = 33;
static const int kActionQueryGroupNotifications = 7;
static const int kActionGetGroupNotificationDetail = 8;
static const int kActionQueryAllGroupNotifications = 9;

static NSString *RBWalletSanitizeServerMessage(NSString *rawMessage, NSString *fallback)
{
    NSString *msg = [[rawMessage ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    if (msg.length == 0) return fallback;

    if ([msg containsString:@"可用余额不足"] || [msg containsString:@"余额不足"]) {
        return @"余额不足";
    }
    if ([msg containsString:@"请先设置资金密码"]) {
        return @"请先设置资金密码";
    }
    if ([msg containsString:@"密码错误"]) {
        return @"密码错误";
    }

    NSRange lineBreakRange = [msg rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]];
    if (lineBreakRange.location != NSNotFound) {
        msg = [[msg substringToIndex:lineBreakRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    NSArray<NSString *> *exceptionMarkers = @[
        @"java.lang.IllegalArgumentException:",
        @"java.lang.RuntimeException:",
        @"java.lang.Exception:",
        @"IllegalArgumentException:",
        @"RuntimeException:",
        @"Exception:"
    ];
    for (NSString *marker in exceptionMarkers) {
        NSRange r = [msg rangeOfString:marker];
        if (r.location != NSNotFound) {
            NSString *candidate = [[msg substringFromIndex:NSMaxRange(r)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            msg = candidate.length > 0 ? candidate : fallback;
            break;
        }
    }

    if ([msg containsString:@"可用余额不足"] || [msg containsString:@"余额不足"]) {
        return @"余额不足";
    }
    if (msg.length == 0 || [msg containsString:@"java."] || [msg containsString:@"Exception"]) {
        return fallback;
    }
    return msg;
}

static NSDictionary *RBHttpParseWrappedJSONObject(NSString *returnValue)
{
    if (![returnValue isKindOfClass:[NSString class]] || returnValue.length == 0) {
        return nil;
    }
    NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
    id rootObj = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];
    if (![rootObj isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *root = (NSDictionary *)rootObj;
    id innerObj = root[@"returnValue"];
    if ([innerObj isKindOfClass:[NSString class]] && [((NSString *)innerObj) length] > 0) {
        NSData *innerData = [((NSString *)innerObj) dataUsingEncoding:NSUTF8StringEncoding];
        id parsedInner = [NSJSONSerialization JSONObjectWithData:innerData options:0 error:nil];
        if ([parsedInner isKindOfClass:[NSDictionary class]]) {
            return (NSDictionary *)parsedInner;
        }
    }
    return root;
}

static BOOL RBHttpWrappedResponseIsSuccess(NSDictionary *json)
{
    if (![json isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    id codeVal = json[@"code"];
    if ([codeVal respondsToSelector:@selector(integerValue)] && [codeVal integerValue] != 0) {
        return NO;
    }
    id successVal = json[@"success"];
    if ([successVal isKindOfClass:[NSNumber class]] && ![(NSNumber *)successVal boolValue]) {
        return NO;
    }
    if ([successVal isKindOfClass:[NSString class]]) {
        NSString *sv = [(NSString *)successVal lowercaseString];
        if ([sv isEqualToString:@"false"] || [sv isEqualToString:@"0"]) {
            return NO;
        }
    }
    return YES;
}

@implementation HttpRestHelper

+ (instancetype)sharedInstance
{
    static HttpRestHelper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HttpRestHelper alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        // 设置http rest框架的默认核心服务地址，通常RainbowChat的http rest服务端的通用http接口只有一个统一的默认服务
        // * 本方法只需要执行一次，后面使用时请直接使用 [HttpServiceFactory getDefaultService];
        [HttpServiceFactory addServices:HTTP_SERVER_REST_URL];
    }
    return self;
}

// 【接口1017】HTTP登陆认证请求接口调用（v2版）.
- (void)submitLoginToServerV2:(LoginInfo2 *)ai complete:(void (^)(BOOL sucess, NSDictionary *retMap))complete hudParentView:(UIView *)view showLocalErrorAlert:(BOOL)showLocalErrorAlert completeForLocalError:(void (^)(NSString *errorLog))completeForLocalError
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIN_4ALL_V2 andDispatch:-1 andAction:-1 withNewData:ai andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        // 服务端接口处理完成请求
        if(sucess)
        {
//            // 将服务端返回的returnValue里的JSON文本反射成对象，方便调用
//            UserEntity *rosterElementEntiry = [EVAToolKits fromJSON:returnValue withClazz:UserEntity.class];
//            // 通知回调
//            complete(YES, rosterElementEntiry);
            
            // V2版接口中返回的是一个Map对象，这里需将JSON转成OC的Dictionary
            NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *retMap = [NSJSONSerialization JSONObjectWithData:rdata options:NSJSONReadingMutableContainers error:nil];
            
            // 通知回调
            complete(YES, retMap);
        }
        // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
        else
        {
            complete(NO, nil);
        }
    } hudParentView:view showLocalErrorAlert:showLocalErrorAlert completeForLocalError:completeForLocalError];
}

// 【接口-2】注销登陆认证请求接口调用.
- (void)submitLogoutToServer:(LogoutInfo *)ao
{
    // 此接口无需理会返回值等，只管调用即可
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGOUT andDispatch:-1 andAction:-1 withNewData:ao complete:nil hudParentView:nil];
}

#pragma mark - 钱包接口（processor_id=1018, job_dispatch=30）

// 查询余额（action 7）
// 接口文档：返回 {"balance":"1000.00","frozen_amount":"0.00","available_balance":"1000.00"}
- (void)submitWalletBalanceWithComplete:(void (^)(BOOL, NSDictionary *))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND1 withNewData:@"{}" andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = nil;
        if (sucess && returnValue && returnValue.length > 0) {
            // 尝试解析为 JSON
            NSData *rd = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            if (rd) {
                NSError *error = nil;
                NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:rd options:0 error:&error];
                if (parsed && [parsed isKindOfClass:[NSDictionary class]]) {
                    // 检查是否是包装格式 {"code":0,"data":{...}}
                    if ([parsed[@"code"] intValue] == 0 && parsed[@"data"]) {
                        data = parsed[@"data"];
                    } else if (parsed[@"balance"] || parsed[@"available_balance"]) {
                        // 直接是余额数据格式 {"balance":"1000.00",...}
                        data = parsed;
                    } else {
                        // 其他格式，尝试使用整个对象
                        data = parsed;
                    }
                }
            }
        }
        
        NSLog(@"【余额查询】返回：success=%d, returnValue=%@, data=%@", sucess, returnValue, data);
        
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

// 查询资金密码是否设置（action 36）
// 接口文档：返回 {"is_set":"1"或"0","set_time":"..."}
- (void)submitWalletCheckFundPasswordStatusWithComplete:(void (^)(BOOL, NSDictionary *))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:36 withNewData:@"{}" andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = nil;
        if (sucess && returnValue && returnValue.length > 0) {
            NSLog(@"【资金密码状态查询】原始返回：returnValue=%@ (长度:%lu)", returnValue, (unsigned long)returnValue.length);
            
            // 尝试解析为 JSON
            NSData *rd = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            if (rd) {
                NSError *error = nil;
                NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:rd options:0 error:&error];
                if (error) {
                    NSLog(@"【资金密码状态查询】JSON解析错误：%@", error.localizedDescription);
                }
                
                if (parsed && [parsed isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"【资金密码状态查询】解析成功：parsed=%@", parsed);
                    
                    // 检查是否是包装格式 {"code":0,"data":{...}}
                    if ([parsed[@"code"] intValue] == 0 && parsed[@"data"] && [parsed[@"data"] isKindOfClass:[NSDictionary class]]) {
                        data = parsed[@"data"];
                        NSLog(@"【资金密码状态查询】使用包装格式的data字段");
                    } else if (parsed[@"is_set"]) {
                        // 直接是密码状态格式 {"is_set":"1",...}
                        data = parsed;
                        NSLog(@"【资金密码状态查询】使用直接格式");
                    } else {
                        // 其他格式，尝试使用整个对象
                        data = parsed;
                        NSLog(@"【资金密码状态查询】使用整个parsed对象");
                    }
                } else {
                    NSLog(@"【资金密码状态查询】解析结果不是字典类型：%@", NSStringFromClass([parsed class]));
                }
            }
        } else {
            NSLog(@"【资金密码状态查询】请求失败或返回为空：success=%d, returnValue=%@", sucess, returnValue);
        }
        
        NSLog(@"【资金密码状态查询】最终结果：success=%d, data=%@ (类型:%@)", sucess, data, NSStringFromClass([data class]));
        if (data && [data isKindOfClass:[NSDictionary class]]) {
            id isSetValue = data[@"is_set"];
            NSLog(@"【资金密码状态查询】data详情：is_set=%@ (类型:%@), set_time=%@, 所有keys=%@", isSetValue, NSStringFromClass([isSetValue class]), data[@"set_time"], [data allKeys]);
            
            // 如果 is_set 不存在，尝试其他可能的字段名
            if (!isSetValue) {
                isSetValue = data[@"isSet"] ?: data[@"is_set"] ?: data[@"isset"] ?: data[@"hasSet"];
                if (isSetValue) {
                    NSLog(@"【资金密码状态查询】找到备用字段：isSetValue=%@", isSetValue);
                }
            }
        } else {
            NSLog(@"【资金密码状态查询】警告：data 不是字典类型，data=%@", data);
        }
        
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitWalletSetFundPassword:(NSString *)newPassword complete:(void (^)(BOOL, NSString *))complete hudParentView:(UIView *)view
{
    NSDictionary *body = @{ @"fund_password": newPassword ?: @"" };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND2 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSString *msg = nil;
        BOOL isSuccess = NO;
        if (returnValue.length > 0) {
            // 尝试解析JSON
            NSDictionary *root = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            if (root) {
                // JSON格式：{"code":0,"msg":"..."}
                if ([root[@"code"] intValue] == 0) {
                    isSuccess = YES;
                }
                msg = root[@"msg"];
            } else {
                // 字符串格式："1"表示成功
                if ([returnValue isEqualToString:@"1"]) {
                    isSuccess = YES;
                    msg = @"设置成功";
                } else {
                    msg = returnValue;
                }
            }
        }
        if (complete) complete(sucess && isSuccess, msg);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

- (void)submitWalletVerifyFundPassword:(NSString *)password complete:(void (^)(BOOL, NSString *))complete hudParentView:(UIView *)view
{
    [self submitWalletVerifyFundPassword:password complete:complete hudParentView:view showLocalErrorAlert:YES];
}

#pragma mark - TRX 链上钱包接口（processor_id=1019, job_dispatch=30）

- (NSDictionary *)rb_dictionaryFromJSONString:(NSString *)json
{
    if (json.length == 0) return nil;
    NSData *rd = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (!rd) return nil;
    id obj = [NSJSONSerialization JSONObjectWithData:rd options:0 error:nil];
    if ([obj isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)obj;
    }
    if ([obj isKindOfClass:[NSString class]]) {
        return [self rb_dictionaryFromJSONString:(NSString *)obj];
    }
    return nil;
}

- (NSDictionary *)rb_parseTrxWalletResponseDataFromReturnValue:(NSString *)returnValue
{
    if (returnValue.length == 0) return nil;
    NSDictionary *dict = [self rb_dictionaryFromJSONString:returnValue];
    if (!dict) {
        NSString *s = returnValue;
        if ([s hasPrefix:@"\""] && [s hasSuffix:@"\""] && s.length >= 2) {
            s = [s substringWithRange:NSMakeRange(1, s.length - 2)];
        }
        if ([s rangeOfString:@"\\\""].location != NSNotFound) {
            NSString *u = [s stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
            u = [u stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
            u = [u stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
            dict = [self rb_dictionaryFromJSONString:u];
        }
    }
    if (!dict) return nil;
    
    id inner = dict[@"returnValue"];
    if ([inner isKindOfClass:[NSString class]] && [(NSString *)inner length] > 0) {
        NSData *rdInner = [(NSString *)inner dataUsingEncoding:NSUTF8StringEncoding];
        if (rdInner) {
            id parsedInner = [NSJSONSerialization JSONObjectWithData:rdInner options:0 error:nil];
            if ([parsedInner isKindOfClass:[NSDictionary class]]) {
                dict = (NSDictionary *)parsedInner;
            }
        }
    }
    
    id data = dict[@"data"];
    if ([dict[@"code"] intValue] == 0 && [data isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)data;
    }
    if ([dict[@"trx_address"] isKindOfClass:[NSString class]] || dict[@"balance_trx"] || dict[@"balance_usdt"] || dict[@"platform_balance"]) {
        return dict;
    }
    if ([data isKindOfClass:[NSString class]]) {
        NSData *rd2 = [(NSString *)data dataUsingEncoding:NSUTF8StringEncoding];
        if (rd2) {
            id parsed2 = [NSJSONSerialization JSONObjectWithData:rd2 options:0 error:nil];
            if ([parsed2 isKindOfClass:[NSDictionary class]]) {
                return (NSDictionary *)parsed2;
            }
        }
    }
    return dict;
}

- (void)submitTrxWalletFullInfoWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_TRX_WALLET andDispatch:LOGIC_WALLET andAction:109 withNewData:@"{}" andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = sucess ? [self rb_parseTrxWalletResponseDataFromReturnValue:returnValue] : nil;
        if (!(sucess && data)) {
            [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:109 withNewData:@"{}" andOldData:nil progress:nil complete:^(BOOL sucess2, NSString *returnValue2) {
                NSDictionary *data2 = sucess2 ? [self rb_parseTrxWalletResponseDataFromReturnValue:returnValue2] : nil;
                if (complete) complete(sucess2 && data2 != nil, data2);
            } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
            return;
        }
        if (complete) complete(YES, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitTrxWalletCreateOrGetWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_TRX_WALLET andDispatch:LOGIC_WALLET andAction:102 withNewData:@"{}" andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = sucess ? [self rb_parseTrxWalletResponseDataFromReturnValue:returnValue] : nil;
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitTrxWalletRealtimeBalanceWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_TRX_WALLET andDispatch:LOGIC_WALLET andAction:103 withNewData:@"{}" andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = sucess ? [self rb_parseTrxWalletResponseDataFromReturnValue:returnValue] : nil;
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitTrxWalletDepositAddressWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_TRX_WALLET andDispatch:LOGIC_WALLET andAction:104 withNewData:@"{}" andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = sucess ? [self rb_parseTrxWalletResponseDataFromReturnValue:returnValue] : nil;
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitTrxWalletWithdrawToAddress:(NSString *)toAddress assetType:(NSString *)assetType amount:(NSString *)amount complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view
{
    NSDictionary *body = @{
        @"to_address": toAddress ?: @"",
        @"asset_type": assetType ?: @"TRX",
        @"amount": amount ?: @""
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_TRX_WALLET andDispatch:LOGIC_WALLET andAction:105 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = [self rb_parseTrxWalletResponseDataFromReturnValue:returnValue];
        BOOL ok = sucess && data != nil;
        if (complete) complete(ok, data);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

- (void)submitTrxWalletAssetBalanceWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_TRX_WALLET andDispatch:LOGIC_WALLET andAction:110 withNewData:@"{}" andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = sucess ? [self rb_parseTrxWalletResponseDataFromReturnValue:returnValue] : nil;
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitTrxWalletDepositRecords:(int)page pageSize:(int)pageSize complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view
{
    NSDictionary *body = @{ @"page": @(MAX(1, page)), @"page_size": @(MAX(1, pageSize)) };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_TRX_WALLET andDispatch:LOGIC_WALLET andAction:107 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *root = sucess ? [self rb_dictionaryFromJSONString:returnValue] : nil;
        NSDictionary *data = nil;
        if ([root isKindOfClass:[NSDictionary class]]) {
            id d = root[@"data"];
            data = [d isKindOfClass:[NSDictionary class]] ? d : root;
        }
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitTrxWalletWithdrawRecords:(int)page pageSize:(int)pageSize complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view
{
    NSDictionary *body = @{ @"page": @(MAX(1, page)), @"page_size": @(MAX(1, pageSize)) };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_TRX_WALLET andDispatch:LOGIC_WALLET andAction:108 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *root = sucess ? [self rb_dictionaryFromJSONString:returnValue] : nil;
        NSDictionary *data = nil;
        if ([root isKindOfClass:[NSDictionary class]]) {
            id d = root[@"data"];
            data = [d isKindOfClass:[NSDictionary class]] ? d : root;
        }
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitTrxWalletAssetFlows:(NSString *)assetType flowType:(NSString *)flowType page:(int)page pageSize:(int)pageSize complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view
{
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (assetType.length > 0) body[@"asset_type"] = assetType;
    if (flowType.length > 0) body[@"flow_type"] = flowType;
    body[@"page"] = @(MAX(1, page));
    body[@"page_size"] = @(MAX(1, pageSize));
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_TRX_WALLET andDispatch:LOGIC_WALLET andAction:111 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *root = sucess ? [self rb_dictionaryFromJSONString:returnValue] : nil;
        NSDictionary *data = nil;
        if ([root isKindOfClass:[NSDictionary class]]) {
            id d = root[@"data"];
            data = [d isKindOfClass:[NSDictionary class]] ? d : root;
        }
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitTrxWalletHotWalletInfoWithComplete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_TRX_WALLET andDispatch:LOGIC_WALLET andAction:112 withNewData:@"{}" andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *root = sucess ? [self rb_dictionaryFromJSONString:returnValue] : nil;
        NSDictionary *data = nil;
        if ([root isKindOfClass:[NSDictionary class]]) {
            id d = root[@"data"];
            data = [d isKindOfClass:[NSDictionary class]] ? d : root;
        }
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitTrxWalletWithdrawFeeConfig:(NSString *)assetType complete:(void (^)(BOOL sucess, NSDictionary *data))complete hudParentView:(UIView *)view
{
    NSDictionary *body = @{ @"asset_type": assetType ?: @"" };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_TRX_WALLET andDispatch:LOGIC_WALLET andAction:113 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *root = sucess ? [self rb_dictionaryFromJSONString:returnValue] : nil;
        NSDictionary *data = nil;
        if ([root isKindOfClass:[NSDictionary class]]) {
            id d = root[@"data"];
            data = [d isKindOfClass:[NSDictionary class]] ? d : root;
        }
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

// 内部方法：用于检测密码状态，不显示错误提示
- (void)submitWalletVerifyFundPassword:(NSString *)password complete:(void (^)(BOOL, NSString *))complete hudParentView:(UIView *)view showLocalErrorAlert:(BOOL)showAlert
{
    NSDictionary *body = @{ @"fund_password": password ?: @"" };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND4 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSString *msg = nil;
        // 根据文档：returnValue 可能是 "0"（未设置）、"1"（验证成功）或 JSON 字符串（验证失败）
        // 注意：returnValue 是字符串，可能是 "0"、"1" 或 JSON 字符串
        if (returnValue && returnValue.length > 0) {
            // 先尝试作为纯字符串处理（"0" 或 "1"）
            NSString *trimmed = [returnValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([trimmed isEqualToString:@"0"] || [trimmed isEqualToString:@"1"]) {
                msg = trimmed;
            } else {
                // 尝试解析为 JSON
                NSData *rd = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                if (rd) {
                    NSError *error = nil;
                    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:rd options:0 error:&error];
                    if (root && [root isKindOfClass:[NSDictionary class]]) {
                        // JSON 格式，提取 msg 或直接使用 returnValue
                        msg = root[@"msg"] ?: returnValue;
                    } else {
                        // 无法解析，直接使用 returnValue
                        msg = returnValue;
                    }
                } else {
                    msg = returnValue;
                }
            }
        }
        if (complete) complete(sucess, msg);
    } hudParentView:view showLocalErrorAlert:showAlert completeForLocalError:nil];
}

- (void)submitWalletTransferToUid:(NSString *)toUid amountCent:(long long)amountCent remark:(NSString *)remark idempotentKey:(NSString *)idempotentKey fundPassword:(NSString *)fundPassword groupId:(NSString *)groupId complete:(void (^)(BOOL, NSDictionary *))complete hudParentView:(UIView *)view
{
    // 兼容旧接口：如果传入了amountCent，转换为amount字符串（元）
    NSString *amountStr = [NSString stringWithFormat:@"%.2f", amountCent / 100.0];
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
        @"to_uid": toUid ?: @"",
        @"amount": amountStr,
        @"remark": remark ?: @"",
        @"fund_password": fundPassword ?: @""
    }];
    if (idempotentKey.length > 0) body[@"idempotent_key"] = idempotentKey;
    if (groupId.length > 0) body[@"group_id"] = groupId;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    // 对接文档：成功 returnValue "1"，失败 "0"=资金密码未传/未设置，"-1"=资金密码错误
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND11 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSString *trimmed = [returnValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        BOOL ok = sucess && [trimmed isEqualToString:@"1"];
        if (ok) {
            if (complete) complete(YES, @{});
            return;
        }
        NSString *msg = @"转账失败";
        if ([trimmed isEqualToString:@"0"]) {
            msg = @"请先设置资金密码";
        } else if ([trimmed isEqualToString:@"-1"]) {
            msg = @"密码错误";
        } else if (trimmed.length > 0) {
            if ([trimmed hasPrefix:@"{"] && [trimmed containsString:@"msg"]) {
                NSDictionary *root = [NSJSONSerialization JSONObjectWithData:[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                if ([root isKindOfClass:[NSDictionary class]] && root[@"msg"]) {
                    msg = [root[@"msg"] description];
                } else {
                    msg = trimmed;
                }
            } else {
                msg = trimmed;
            }
            msg = RBWalletSanitizeServerMessage(msg, msg.length > 0 ? msg : @"转账失败");
        }
        if (complete) complete(NO, @{ @"msg": msg });
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

- (void)submitWalletLedgerListWithParams:(NSDictionary *)params complete:(void (^)(BOOL, NSDictionary *))complete hudParentView:(UIView *)view
{
    // 兼容旧参数名：pageSize -> page_size
    NSMutableDictionary *newParams = [NSMutableDictionary dictionaryWithDictionary:params ?: @{}];
    if (newParams[@"pageSize"] && !newParams[@"page_size"]) {
        newParams[@"page_size"] = newParams[@"pageSize"];
        [newParams removeObjectForKey:@"pageSize"];
    }
    if (newParams[@"transactionType"] && !newParams[@"transaction_type"]) {
        newParams[@"transaction_type"] = newParams[@"transactionType"];
        [newParams removeObjectForKey:@"transactionType"];
    }
    // 若传入 transaction_types 数组（转账 3+4、红包 5+6+7），兼容只认 transaction_type 的后端：转为逗号分隔字符串
    id typesArr = newParams[@"transaction_types"];
    if ([typesArr isKindOfClass:[NSArray class]] && [(NSArray *)typesArr count] > 0) {
        NSMutableArray *nums = [NSMutableArray array];
        for (id n in (NSArray *)typesArr) {
            if ([n isKindOfClass:[NSNumber class]]) {
                [nums addObject:[(NSNumber *)n stringValue]];
            } else if (n != nil) {
                [nums addObject:[n description]];
            }
        }
        if (nums.count > 0) {
            newParams[@"transaction_type"] = [nums componentsJoinedByString:@","];
            [newParams removeObjectForKey:@"transaction_types"];
        }
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:newParams options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND15 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = nil;
        if (sucess && returnValue.length > 0) {
            NSLog(@"【交易记录查询】原始返回：returnValue=%@", returnValue);
            
            // 尝试解析为 JSON
            NSData *rd = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            if (rd) {
                NSError *error = nil;
                NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:rd options:0 error:&error];
                if (error) {
                    NSLog(@"【交易记录查询】JSON解析错误：%@", error.localizedDescription);
                }
                
                if (parsed && [parsed isKindOfClass:[NSDictionary class]]) {
                    // 检查是否是包装格式 {"code":0,"data":{...}}
                    if ([parsed[@"code"] intValue] == 0 && parsed[@"data"] && [parsed[@"data"] isKindOfClass:[NSDictionary class]]) {
                        data = parsed[@"data"];
                        NSLog(@"【交易记录查询】使用包装格式的data字段");
                    } else if (parsed[@"list"] || parsed[@"total"]) {
                        // 直接是交易记录格式 {"total":10,"page":1,"page_size":20,"list":[...]}
                        data = parsed;
                        NSLog(@"【交易记录查询】使用直接格式");
                    } else {
                        // 其他格式，尝试使用整个对象
                        data = parsed;
                        NSLog(@"【交易记录查询】使用整个parsed对象");
                    }
                } else {
                    NSLog(@"【交易记录查询】解析结果不是字典类型：%@", NSStringFromClass([parsed class]));
                }
            }
        } else {
            NSLog(@"【交易记录查询】请求失败或返回为空：success=%d, returnValue=%@", sucess, returnValue);
        }
        
        NSLog(@"【交易记录查询】最终结果：success=%d, data=%@", sucess, data);
        if (data && [data isKindOfClass:[NSDictionary class]]) {
            NSArray *list = data[@"list"];
            NSLog(@"【交易记录查询】data详情：total=%@, page=%@, page_size=%@, list.count=%lu", data[@"total"], data[@"page"], data[@"page_size"], (unsigned long)(list ? list.count : 0));
            // 若服务端返回 ledger_type(1~6) 未返回 transaction_type，统一映射为前端约定 1~7，便于 Tab 筛选与展示
            if ([list isKindOfClass:[NSArray class]] && list.count > 0) {
                NSMutableDictionary *dataMut = [data isKindOfClass:[NSMutableDictionary class]] ? (NSMutableDictionary *)data : [data mutableCopy];
                NSMutableArray *normalized = [NSMutableArray arrayWithCapacity:list.count];
                static const int kLedgerToTransaction[] = { 0, 4, 3, 5, 6, 1, 2 }; // ledger_type 1→4 2→3 3→5 4→6 5→1 6→2
                for (id one in list) {
                    NSDictionary *item = [one isKindOfClass:[NSDictionary class]] ? (NSDictionary *)one : @{};
                    NSMutableDictionary *m = [item isKindOfClass:[NSMutableDictionary class]] ? [item mutableCopy] : [item mutableCopy];
                    if (m[@"transaction_type"] == nil) {
                        id ltObj = m[@"ledger_type"] ?: m[@"ledgerType"];
                        if (ltObj != nil) {
                            int lt = [ltObj isKindOfClass:[NSNumber class]] ? [ltObj intValue] : [[ltObj description] intValue];
                            if (lt >= 1 && lt <= 6) m[@"transaction_type"] = @(kLedgerToTransaction[lt]);
                        }
                    }
                    if (m[@"related_user_uid"] == nil && m[@"opposite_uid"] != nil)
                        m[@"related_user_uid"] = m[@"opposite_uid"];
                    [normalized addObject:m];
                }
                dataMut[@"list"] = normalized;
                data = dataMut;
            }
        }
        
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

- (void)submitWalletResolvePayeeByCode:(NSString *)code complete:(void (^)(BOOL, NSDictionary *))complete hudParentView:(UIView *)view
{
    NSDictionary *body = @{ @"code": code ?: @"" };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND5 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = nil;
        if (sucess && returnValue.length > 0) {
            NSDictionary *root = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            if ([root[@"code"] intValue] == 0 && root[@"data"]) data = root[@"data"];
        }
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

// 修改资金密码（action 9）. 需短信验证：old_psw+psw+phone_num+sms_code。uid 可选
- (void)submitWalletModifyFundPasswordWithOldPassword:(NSString *)oldPsw newPassword:(NSString *)psw uid:(NSString *)uid phoneNum:(NSString *)phoneNum smsCode:(NSString *)smsCode complete:(void (^)(BOOL, NSString *))complete hudParentView:(UIView *)view
{
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
        @"old_psw": oldPsw ?: @"",
        @"psw": psw ?: @""
    }];
    if (uid.length > 0) body[@"uid"] = uid;
    // 添加短信验证码参数
    if (smsCode && smsCode.length > 0) {
        body[@"sms_code"] = smsCode;
    }
    // 手机号自动从用户信息中获取（用户绑定的手机号），不需要用户输入
    UserEntity *localUser = [IMClientManager sharedInstance].localUserInfo;
    NSString *finalPhoneNum = phoneNum;
    if (!finalPhoneNum || finalPhoneNum.length == 0) {
        // 如果没有提供手机号，从当前用户信息获取
        finalPhoneNum = localUser.phoneNum;
    }
    if (finalPhoneNum && finalPhoneNum.length > 0) {
        body[@"phone_num"] = finalPhoneNum;
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    
    NSLog(@"【修改资金密码】提交：uid=%@, phone_num=%@, sms_code=%@", uid, body[@"phone_num"], smsCode);
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND3 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSString *msg = nil;
        BOOL isSuccess = NO;
        if (returnValue.length > 0) {
            // 先尝试作为纯字符串处理（"0"、"1"、"2"等）
            NSString *trimmed = [returnValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([trimmed isEqualToString:@"1"]) {
                isSuccess = YES;
                msg = @"修改成功";
            } else {
                // 尝试解析为 JSON
                NSDictionary *root = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                if (root && [root isKindOfClass:[NSDictionary class]]) {
                    if ([root[@"code"] intValue] == 0) {
                        isSuccess = YES;
                    }
                    msg = root[@"msg"] ?: returnValue;
                } else {
                    // 直接使用 returnValue 作为错误信息
                    msg = returnValue;
                }
            }
        }
        NSLog(@"【修改资金密码】返回：success=%d, returnValue=%@, msg=%@", sucess && isSuccess, returnValue, msg);
        if (complete) complete(sucess && isSuccess, msg);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

// 申请充值（action 23）
// 接口文档：https://docs/充值功能-前端对接文档.md
// actionId: 23, 返回 "1" 成功 / "0" 失败 / 其他为错误信息
- (void)submitWalletRecharge:(NSString *)amount complete:(void (^)(BOOL, NSString *))complete hudParentView:(UIView *)view
{
    // 参数校验：金额必须>0，格式化为两位小数
    if (!amount || amount.length == 0) {
        if (complete) complete(NO, @"充值金额不能为空");
        return;
    }
    
    double amountValue = [amount doubleValue];
    if (amountValue <= 0 || isnan(amountValue) || isinf(amountValue)) {
        if (complete) complete(NO, @"充值金额必须大于0");
        return;
    }
    
    // 格式化为两位小数（符合接口要求）
    NSString *amountFormatted = [NSString stringWithFormat:@"%.2f", amountValue];
    
    NSDictionary *body = @{ @"amount": amountFormatted };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    
    NSLog(@"【充值】提交充值申请：金额=%@", amountFormatted);
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND5 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        // 接口返回 "1" 表示成功，"0" 表示失败，其他为错误信息（见接口文档）
        BOOL isSuccess = NO;
        NSString *msg = nil;
        
        if (!sucess) {
            // HTTP 请求失败
            msg = returnValue ?: @"网络请求失败";
            if (complete) complete(NO, msg);
            return;
        }
        
        if (returnValue && returnValue.length > 0) {
            NSString *trimmed = [returnValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if ([trimmed isEqualToString:@"1"]) {
                // 成功
                isSuccess = YES;
                msg = @"充值申请已提交，请等待审核";
            } else if ([trimmed isEqualToString:@"0"]) {
                // 失败
                isSuccess = NO;
                msg = @"提交失败，请重试";
            } else {
                // 其他情况：可能是错误信息（如"充值金额不能为空"、"充值金额必须大于0"等）
                isSuccess = NO;
                msg = trimmed; // 直接使用服务端返回的错误信息
            }
        } else {
            isSuccess = NO;
            msg = @"充值失败";
        }
        
        NSLog(@"【充值】接口返回：success=%d, returnValue=%@, msg=%@", isSuccess, returnValue, msg);
        
        if (complete) complete(isSuccess, msg);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

// 申请提现（action 24）
- (void)submitWalletWithdraw:(NSString *)withdrawalMethodId amount:(NSString *)amount fundPassword:(NSString *)fundPassword complete:(void (^)(BOOL, NSString *))complete hudParentView:(UIView *)view
{
    NSDictionary *body = @{
        @"withdrawal_method_id": withdrawalMethodId ?: @"",
        @"amount": amount ?: @"0.00",
        @"fund_password": fundPassword ?: @""
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND6 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSString *msg = nil;
        if (returnValue.length > 0) {
            NSDictionary *root = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            msg = root[@"msg"];
        }
        if (complete) complete(sucess, msg);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

// 绑定提款方式（action 25）
- (void)submitWalletBindWithdrawMethod:(int)methodType accountName:(NSString *)accountName accountNumber:(NSString *)accountNumber qrCodeUrl:(NSString *)qrCodeUrl bankName:(NSString *)bankName complete:(void (^)(BOOL, NSString *))complete hudParentView:(UIView *)view
{
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
        @"method_type": @(methodType),
        @"account_name": accountName ?: @"",
        @"account_number": accountNumber ?: @""
    }];
    if (qrCodeUrl.length > 0) body[@"qr_code_url"] = qrCodeUrl;
    if (bankName.length > 0) body[@"bank_name"] = bankName;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND7 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSString *msg = nil;
        if (returnValue.length > 0) {
            // 解析returnValue：可能是简单字符串"1"或"0"，也可能是JSON
            NSString *trimmed = [returnValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([trimmed isEqualToString:@"1"]) {
                msg = @"绑定成功";
            } else if ([trimmed isEqualToString:@"0"]) {
                msg = @"绑定失败";
            } else {
                // 尝试解析JSON
                NSDictionary *root = [NSJSONSerialization JSONObjectWithData:[trimmed dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                if (root && root[@"msg"]) {
                    msg = root[@"msg"];
                } else {
                    msg = trimmed; // 使用原始返回值作为错误信息
                }
            }
        }
        if (complete) complete(sucess, msg);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

// 查询提款方式列表（接口 1018-30-14，processorId=1018 jobDispatchId=30 actionId=26）
// 请求 newData 可为 "{}"，无需其它参数。returnValue 解析后为数组，或 { code:0, data: 数组 }。
- (void)submitWalletGetWithdrawMethodsWithComplete:(void (^)(BOOL, NSArray *))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND8 withNewData:@"{}" andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSArray *data = nil;
        if (sucess && returnValue.length > 0) {
            id json = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            if ([json isKindOfClass:[NSArray class]]) {
                data = (NSArray *)json;
            } else if ([json isKindOfClass:[NSDictionary class]]) {
                NSDictionary *root = (NSDictionary *)json;
                if ([root[@"code"] intValue] == 0 && [root[@"data"] isKindOfClass:[NSArray class]]) {
                    data = root[@"data"];
                }
            }
        }
        if (complete) complete(sucess && data != nil, data ?: @[]);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

// 删除提款方式（action 27）
- (void)submitWalletDeleteWithdrawMethod:(NSString *)methodId complete:(void (^)(BOOL, NSString *))complete hudParentView:(UIView *)view
{
    NSDictionary *body = @{ @"id": methodId ?: @"" };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND9 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSString *msg = nil;
        if (returnValue.length > 0) {
            NSDictionary *root = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            msg = root[@"msg"];
        }
        if (complete) complete(sucess, msg);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

// 设置默认提款方式（action 28）
- (void)submitWalletSetDefaultWithdrawMethod:(NSString *)methodId complete:(void (^)(BOOL, NSString *))complete hudParentView:(UIView *)view
{
    NSDictionary *body = @{ @"id": methodId ?: @"" };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND10 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSString *msg = nil;
        if (returnValue.length > 0) {
            NSDictionary *root = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            msg = root[@"msg"];
        }
        if (complete) complete(sucess, msg);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

// 解析发红包接口 returnValue：成功为 {"packet_id":"1"}，失败为 "0" / {"success":false,"fail_count":3} / {"success":false,"frozen_remaining":86400}
- (NSDictionary *)parseRedPacketSendReturnValue:(NSString *)returnValue success:(BOOL)sucess
{
    NSMutableDictionary *outDict = [NSMutableDictionary dictionary];
    if (sucess && returnValue.length > 0) {
        NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        NSString *packetId = [parsed isKindOfClass:[NSDictionary class]] ? ([parsed[@"packet_id"] description] ?: @"") : nil;
        if (packetId.length > 0) {
            outDict[@"_success"] = @YES;
            outDict[@"packet_id"] = packetId;
            return outDict;
        }
    }
    outDict[@"_success"] = @NO;
    NSString *msg = @"红包发送失败";
    if (!sucess && returnValue.length > 0) {
        if ([returnValue isEqualToString:@"0"]) {
            msg = @"请先设置资金密码";
            outDict[@"need_set_fund_password"] = @YES;  // 未设置资金密码，应跳转设置页
        } else {
            NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            if ([parsed isKindOfClass:[NSDictionary class]]) {
                if (parsed[@"fail_count"] != nil) {
                    int n = [parsed[@"fail_count"] intValue];
                    msg = [NSString stringWithFormat:@"资金密码错误，剩余%d次", n];
                    outDict[@"fail_count"] = @(n);
                } else if (parsed[@"frozen_remaining"] != nil) {
                    int sec = [parsed[@"frozen_remaining"] intValue];
                    int hour = (sec + 3599) / 3600;
                    msg = [NSString stringWithFormat:@"资金密码已冻结，%d小时后可重试", hour];
                    outDict[@"frozen_remaining"] = @(sec);
                } else if (parsed[@"msg"] != nil) {
                    msg = RBWalletSanitizeServerMessage([parsed[@"msg"] description], msg);
                }
            } else {
                msg = RBWalletSanitizeServerMessage(returnValue, msg);
            }
        }
    }
    outDict[@"msg"] = msg;
    return outDict;
}

// 解析抢红包接口 returnValue：成功为 {"amount":"10.00"}，失败为纯字符串如 "红包不存在或已过期"
- (NSDictionary *)parseRedPacketGrabReturnValue:(NSString *)returnValue success:(BOOL)sucess
{
    NSMutableDictionary *outDict = [NSMutableDictionary dictionary];
    if (sucess && returnValue.length > 0) {
        NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        NSString *amount = [parsed isKindOfClass:[NSDictionary class]] ? ([parsed[@"amount"] description] ?: @"") : nil;
        if (amount.length > 0) {
            outDict[@"_success"] = @YES;
            outDict[@"amount"] = amount;
            return outDict;
        }
    }
    outDict[@"_success"] = @NO;
    outDict[@"msg"] = (returnValue.length > 0 ? returnValue : @"抢红包失败");
    return outDict;
}

// 发普通红包（接口1018-30-18，action 30）
- (void)submitWalletSendNormalRedPacket:(int)receiverType receiverUid:(NSString *)receiverUid groupId:(NSString *)groupId totalAmount:(NSString *)totalAmount totalCount:(int)totalCount message:(NSString *)message fundPassword:(NSString *)fundPassword exclusiveReceiverUid:(NSString *)exclusiveReceiverUid complete:(void (^)(BOOL, NSDictionary *))complete hudParentView:(UIView *)view
{
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
        @"receiver_type": @(receiverType),
        @"receiver_uid": (receiverType == 1 && receiverUid.length > 0) ? receiverUid : @"",
        @"group_id": (receiverType == 2 && groupId.length > 0) ? groupId : @"",
        @"total_amount": totalAmount ?: @"0.00",
        @"total_count": @(totalCount),
        @"message": message ?: @"",
        @"fund_password": fundPassword ?: @""
    }];
    if (receiverType == 2 && exclusiveReceiverUid.length > 0) {
        body[@"exclusive_receiver_uid"] = exclusiveReceiverUid;
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND12 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = [self parseRedPacketSendReturnValue:returnValue success:sucess];
        if (complete) complete([data[@"_success"] boolValue], data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

// 发拼手气红包（接口1018-30-19，action 31）
- (void)submitWalletSendLuckyRedPacket:(int)receiverType receiverUid:(NSString *)receiverUid groupId:(NSString *)groupId totalAmount:(NSString *)totalAmount totalCount:(int)totalCount message:(NSString *)message fundPassword:(NSString *)fundPassword exclusiveReceiverUid:(NSString *)exclusiveReceiverUid complete:(void (^)(BOOL, NSDictionary *))complete hudParentView:(UIView *)view
{
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
        @"receiver_type": @(receiverType),
        @"receiver_uid": (receiverType == 1 && receiverUid.length > 0) ? receiverUid : @"",
        @"group_id": (receiverType == 2 && groupId.length > 0) ? groupId : @"",
        @"total_amount": totalAmount ?: @"0.00",
        @"total_count": @(totalCount),
        @"message": message ?: @"",
        @"fund_password": fundPassword ?: @""
    }];
    if (receiverType == 2 && exclusiveReceiverUid.length > 0) {
        body[@"exclusive_receiver_uid"] = exclusiveReceiverUid;
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND13 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = [self parseRedPacketSendReturnValue:returnValue success:sucess];
        if (complete) complete([data[@"_success"] boolValue], data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

// 抢红包（接口1018-30-20，action 32）
- (void)submitWalletGrabRedPacket:(NSString *)packetId complete:(void (^)(BOOL, NSDictionary *))complete hudParentView:(UIView *)view
{
    NSDictionary *body = @{ @"packet_id": packetId ?: @"" };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:ACTION_APPEND14 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = [self parseRedPacketGrabReturnValue:returnValue success:sucess];
        if (complete) complete([data[@"_success"] boolValue], data);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

// 查询红包记录（action 34）
- (void)submitWalletGetRedPacketList:(int)page pageSize:(int)pageSize type:(int)type complete:(void (^)(BOOL, NSDictionary *))complete hudParentView:(UIView *)view
{
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
        @"page": @(page),
        @"page_size": @(pageSize)
    }];
    if (type >= 0) body[@"type"] = @(type);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    // actionId 34 直接使用数字，因为ACTION_APPEND15=33已被交易记录使用
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:34 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = nil;
        if (sucess && returnValue.length > 0) {
            NSDictionary *root = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            if ([root[@"code"] intValue] == 0 && root[@"data"]) data = root[@"data"];
        }
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

// 查询红包详情（action 35）
- (void)submitWalletGetRedPacketDetail:(NSString *)packetId complete:(void (^)(BOOL, NSDictionary *))complete hudParentView:(UIView *)view
{
    NSDictionary *body = @{ @"packet_id": packetId ?: @"" };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *jsonStr = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{}";
    // actionId 35 直接使用数字
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_WALLET andDispatch:LOGIC_WALLET andAction:35 withNewData:jsonStr andOldData:nil progress:nil complete:^(BOOL sucess, NSString *returnValue) {
        NSDictionary *data = nil;
        if (sucess && returnValue.length > 0) {
            NSDictionary *root = [NSJSONSerialization JSONObjectWithData:[returnValue dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            if ([root isKindOfClass:[NSDictionary class]]) {
                if ([root[@"code"] intValue] == 0 && root[@"data"]) data = root[@"data"];
                else if (root[@"sender_uid"] != nil || root[@"id"] != nil) data = root; // 服务端直接返回详情对象
            }
        }
        if (complete) complete(sucess && data != nil, data);
    } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];
}

// 【接口1008-1-27】获取短信验证码接口调用.
- (void)submitGetSMS:(NSString *)phoneNum bizType:(NSString *)bizType complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view showLocalErrorAlert:(BOOL)showLocalErrorAlert completeForLocalError:(void (^)(NSString *errorLog))completeForLocalError
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_APPEND9
                                                withNewData:@{
                                                        @"phone_num": phoneNum,
                                                        @"biz_type": bizType,
                                                    }
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue){
                                                       // 服务端接口处理完成请求
                                                       if(sucess){
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else{
                                                           complete(NO, nil);
                                                       }
                                                    }
                                              hudParentView:view
                                        showLocalErrorAlert:showLocalErrorAlert
                                      completeForLocalError:completeForLocalError];
}


// 【接口1008-2-7】获取用户好友列表接口调用.
- (void)submitGetRosterToServer:(NSString *)uid complete:(void (^)(BOOL sucess, NSArray<UserEntity *> *rosterList))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_ROSTER
                                                  andAction:ACTION_APPEND1
                                                withNewData:uid
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        // 服务端接口处理完成请求
        if(sucess)
        {
            // 返回结果是Java的Vector<RosterElementEntity>形式的数组转JSON后的结果
            if (returnValue !=nil)
            {
                // 将JSON转成OC的2维数组(使用苹果官方的JSON API转2维数组强大一些，EVA框架选用的JSON库RMMapper比较简洁，不太支持这种复杂数据结构)
                NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                NSArray *vec = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];

                // 再将2维数据按服务端的接口返回情况组装成对象列表，方便调用者使用
                NSMutableArray<UserEntity *> *list  = [[NSMutableArray<UserEntity *> alloc] init];
                for (NSDictionary *row in vec)
                {
                    // 将2维数组的每个单元（字典对象）反射成对象
                    UserEntity *e = [EVAToolKits fromDictionaryToObject:row withClass:UserEntity.class];
                    if (row[@"is_starred"] != nil) {
                        e.is_starred = [row[@"is_starred"] description];
                    }
                    if (row[@"onlineStartTime"] != nil && row[@"onlineStartTime"] != [NSNull null]) {
                        e.onlineStartTime = [row[@"onlineStartTime"] description];
                    } else {
                        e.onlineStartTime = nil;
                    }
                    e.offlineTime = nil;
                    if (!e.is_starred || e.is_starred.length == 0) {
                        e.is_starred = @"0";
                    }
                    [list addObject:e];
                }
                // 星标好友置顶（后端不排序，前端按 is_starred 分组后星标在前）
                [list sortUsingComparator:^NSComparisonResult(UserEntity *a, UserEntity *b) {
                    BOOL aStar = [a.is_starred isEqualToString:@"1"];
                    BOOL bStar = [b.is_starred isEqualToString:@"1"];
                    if (aStar && !bStar) return NSOrderedAscending;
                    if (!aStar && bStar) return NSOrderedDescending;
                    return NSOrderedSame;
                }];

                complete(YES, list);
            }
            // 此接口在服务端的定义是一定不会返回Nil，哪怕是个空数组
            else
            {
                complete(NO, nil);
            }
        }
        // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
        else
        {
            complete(NO, nil);
        }
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];// showLocalErrorAlert 为NO表示当出现本地网等异常时不显示提示AlertView，老弹框会影响用户体验
}

//【接口1008-2-8】更新好友信息中的备注、描述等的接口调用.
- (void)submitRosterRemarkModifiyToServer:(NSString *)remark mobileNum:(NSString *)mobile_num moreDesc:(NSString *)more_desc localUid:(NSString *)localUid friendUid:(NSString *)friend_user_uid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_ROSTER
                                                  andAction:ACTION_APPEND2
                                                withNewData:@{
                                                        @"remark": remark,
                                                        @"mobile_num": mobile_num,
                                                        @"more_desc": more_desc,
                                                        @"user_uid": localUid,
                                                        @"friend_user_uid": friend_user_uid
                                                    }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess){
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else{
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

// 【接口1008-4-8】获取离线聊天消息的接口调用.
- (void)submitGetOfflineChatMessagesToServer:(NSString *)user_uid friend:(NSString *)from_user_uid complete:(void (^)(BOOL sucess, NSArray<OfflineMsgDTO *> *offlineMsgList))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:ACTION_APPEND2
                                                withNewData:from_user_uid == nil?@{@"user_uid":user_uid, @"include_fp":@"1"}:@{@"user_uid":user_uid, @"from_user_uid":from_user_uid, @"include_fp":@"1"}
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        // 服务端接口处理完成请求
        if(sucess)
        {
            // 返回结果是Java的Vector<OfflineMsgDTO>形式的数组转JSON后的结果
            if (returnValue !=nil)
            {
                // 将JSON转成OC的2维数组(使用苹果官方的JSON API转2维数组强大一些，EVA框架选用的JSON库RMMapper比较简洁，不太支持这种复杂数据结构)
                NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                NSArray *vec = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];

                // 再将2维数据按服务端的接口返回情况组装成对象列表，方便调用者使用
                NSMutableArray<OfflineMsgDTO *> *list  = [[NSMutableArray<OfflineMsgDTO *> alloc] init];
                for (NSDictionary *row in vec)
                {
                    // 将2维数组的每个单元（字典对象）反射成对象
                    OfflineMsgDTO *e = [EVAToolKits fromDictionaryToObject:row withClass:OfflineMsgDTO.class];

//                    NSLog(@"[1]》》》》》》》》》》》》》》》》http返回的离线消息列表中每一行 row.class：%@, row：%@, 反射后e：%@", row.class, row, e);

                    // 加入到返回值集合中
                    [list addObject:e];
                }

//                NSLog(@"[2]》》》》》》》》》》》》》》》》->http返回的离线消息组装完的list：%@", list);

                // 通知回调
                complete(YES, list);
            }
            // 此接口在服务端的定义是一定不会返回Nil，哪怕是个空数组
            else
            {
                complete(NO, nil);
            }
        }
        // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
        else
        {
            complete(NO, nil);
        }
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];// showLocalErrorAlert 为NO表示当出现本地网等异常时不显示提示AlertView，老弹框会影响用户体验
}

// 【接口1008-4-26】清空用户的所有消息记录接口调用.
- (void)submitClearAllMessagesToServer:(NSString *)uid complete:(void (^)(BOOL sucess, long long clearTime))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:ACTION_APPEND8
                                                withNewData:@{@"uid": uid}
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if(sucess && returnValue != nil) {
            NSData *jsonData = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            if(dict) {
                NSNumber *code = dict[@"code"];
                if(code && [code intValue] == 0) {
                    long long clearTime = 0;
                    NSNumber *ct = dict[@"clear_time"];
                    if(ct) {
                        clearTime = [ct longLongValue];
                    }
                    complete(YES, clearTime);
                    return;
                }
            }
            complete(NO, 0);
        } else {
            complete(NO, 0);
        }
    } hudParentView:view];
}

// 【接口1008-5-7】删除指定的好友接口调用.
- (void)submitDeleteFriendToServer:(NSString *)localUserUid friend:(NSString *)fromUserUid complete:(void (^)(BOOL sucess))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_DELETE_FRIEND
                                                  andAction:ACTION_APPEND1
                                                withNewData:@{@"local_uid":localUserUid, @"friend_uid":fromUserUid}
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        // 服务端接口处理完成请求
        if(sucess)
        {
            complete(YES);
        }
        // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
        else
        {
            complete(NO);
        }
    } hudParentView:view];
}

// 【接口1008-3-23】查找好友功能子接口：获取“随机查找好友”结果的接口调用.
- (void)submitGetRandomFindFriendsToServer:(NSString *)local_uid sex:(NSString *)sex_condition online:(NSString *)online_condition complete:(void (^)(BOOL sucess, NSArray<UserEntity *> *rosterList))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_SNS
                                                  andAction:ACTION_APPEND5
                                                withNewData:@{
                                                              // 本地用户的uid：用于查询结果中排除“自已”
                                                              @"local_uid":local_uid,
                                                              // 性别查询条件：-1 表示不使用本条件(即ALL)，1  表只查男性，0  表只查女性
                                                              @"sex_condition":sex_condition,
                                                              // 在线状态查询条件：-1 表示不使用本条件(即ALL)，1  表只查在线，0 表只查离线
                                                              @"online_condition":online_condition
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        // 服务端接口处理完成请求
        if(sucess)
        {
            // 返回结果是Java的Vector<RosterElementEntity>形式的数组转JSON后的结果
            if (returnValue !=nil)
            {
                // 将JSON转成OC的1维数组(使用苹果官方的JSON API转2维数组强大一些，EVA框架选用的JSON库RMMapper比较简洁，不太支持这种复杂数据结构)
                NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                NSArray *vec = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];

                // 再将1维数组按服务端的接口返回情况组装成对象列表，方便调用者使用
                NSMutableArray<UserEntity *> *list  = [[NSMutableArray<UserEntity *> alloc] init];
                for (NSDictionary *row in vec)
                {
                    // 将1维数组的每个单元（字典对象）反射成对象
                    UserEntity *e = [EVAToolKits fromDictionaryToObject:row withClass:UserEntity.class];

//                    NSLog(@"[1]》》》》》》》》》》》》》》》》http返回的查找好友列表中每一行 row.class：%@, row：%@, 反射后e：%@", row.class, row, e);

                    // 加入到返回值集合中
                    [list addObject:e];
                }

//                NSLog(@"[2]》》》》》》》》》》》》》》》》->http返回的组装完的list：%@", list);

                // 通知回调
                complete(YES, list);
            }
            // 此接口在服务端的定义是一定不会返回Nil，哪怕是个空数组
            else
            {
                complete(NO, nil);
            }
        }
        // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
        else
        {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1008-3-8】获取用户/好友的个人信息接口调用.
- (void)submitGetFriendInfoToServer:(BOOL)use_mail mail:(NSString *)friend_mail uid:(NSString *)friend_uid complete:(void (^)(BOOL sucess, UserEntity *userInfo))complete hudParentView:(UIView *)view
{
    NSString *myUid = nil;
    if([IMClientManager sharedInstance].localUserInfo != nil)
        myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_SNS
                                                  andAction:ACTION_APPEND2
                                                withNewData:@{
                                                              // "1"表示用好友的mail地址查找，否则表示用好友的uid查找
                                                              @"use_mail":use_mail?@"1":@"0",
                                                              // 用户或好友的mail地址（use_mail为YES时本参数必须不为空哦）
                                                              @"friend_mail":(friend_mail == nil ?@"":friend_mail),
                                                              // 用户或好友的uid（use_mail为NO时本参数必须不为空哦）
                                                              @"friend_uid":(friend_uid == nil?@"":friend_uid),
                                                              // 查询发起人的uid，这个uid指的是客户端提起这个查询时的当前登陆者uid，
                                                              // 指明此uid后本sql将同时提供被查询作为好友的额外信息。本参数可为null（表示不需要查询好友的额外信息）
                                                              @"my_uid": myUid
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        // 服务端接口处理完成请求
        if(sucess)
        {
            // 将服务端返回的returnValue里的JSON文本反射成对象，方便调用
            UserEntity *rosterElementEntiry = [EVAToolKits fromJSON:returnValue withClazz:UserEntity.class];

            // 通知回调
            complete(YES, rosterElementEntiry);
        }
        // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
        else
        {
            complete(NO, nil);
        }
    } hudParentView:view];
}

- (void)submitGetFriendInfoByPhoneToServer:(NSString *)phone complete:(void (^)(BOOL sucess, UserEntity *userInfo))complete hudParentView:(UIView *)view
{
    NSString *myUid = nil;
    if([IMClientManager sharedInstance].localUserInfo != nil)
        myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_SNS
                                                  andAction:ACTION_APPEND2
                                                withNewData:@{
                                                              @"use_mail":@"2",
                                                              @"friend_mail":@"",
                                                              @"friend_uid":@"",
                                                              @"friend_phone":(phone == nil?@"":phone),
                                                              @"my_uid": myUid
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if(sucess)
        {
            UserEntity *rosterElementEntiry = returnValue.length > 0 ? [EVAToolKits fromJSON:returnValue withClazz:UserEntity.class] : nil;
            if (complete) complete(YES, rosterElementEntiry);
        }
        else
        {
            if (complete) complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1008-10-7】删除个人相册、个人介绍语音留言等2进制资料的接口调用.
- (void)submitDeleteProfileBinaryToServer:(NSString *)resourceId fname:(NSString *)fileName type:(NSString *)resType complete:(void (^)(BOOL sucess))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MGR_PROFILE
                                                  andAction:ACTION_APPEND1
                                                withNewData:@{
                                                              @"resourceId":resourceId,
                                                              @"fileName":fileName,
                                                              @"resType":resType
                                                              }
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           complete(YES);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO);
                                                       }
                                                   } hudParentView:view showLocalErrorAlert:YES completeForLocalError:nil];// showLocalErrorAlert 为NO表示当出现本地网等异常时不显示提示AlertView，老弹框会影响用户体验
}

// 【接口1008-10-8】查询个人相册、个人介绍语音留言预览数量的接口调用.
- (void)queryPhotosOrVoicesCountFromServer:(NSString *)user_uid complete:(void (^)(BOOL sucess, int photosCount, int pvoiceCount))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MGR_PROFILE
                                                  andAction:ACTION_APPEND2
                                                withNewData:@{
                                                              @"user_uid":user_uid
                                                              }
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue){

         int _photosCnt = 0;
         int _pvoiceCnt = 0;

         // 服务端接口处理完成请求
         if(sucess)
         {
             // 返回结果是Java的Vector<RosterElementEntity>形式的数组转JSON后的结果
             if (returnValue !=nil)
             {
                 // 将JSON转成OC的1维数组(使用苹果官方的JSON API转2维数组强大一些，EVA框架选用的JSON库RMMapper比较简洁，不太支持这种复杂数据结构)
                 NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                 NSArray *vec = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];

                 // 整个返回数据形如“[[“0”,个人相片总数],[“1”,个人语音介绍总数]]”的2维数组，具体请参见服务端【接口1008-10-8】
                 for (NSArray *row in vec)
                 {
                     // 将1维数组的每个单元取出来(各单元数据含义请参见服务端【接口1008-10-8】)
                     NSString *count = (NSString *)[row objectAtIndex:0];
                     NSString *resType = (NSString *)[row objectAtIndex:1];

                     if(![BasicTool isStringEmpty:resType])
                     {
                         // 找到个人相片数
                         if([@"0" isEqualToString:resType])
                             _photosCnt = [BasicTool getIntValue:count];
                         // 找到了个人语音数
                         else if([@"1" isEqualToString:resType])
                             _pvoiceCnt = [BasicTool getIntValue:count];
                         else
                         {
                             DDLogWarn(@"【HttpRestHelper.queryPhotosOrVoicesCountFromServer】未知的resType=%@", resType);
                         }
                     }
                 }

                 DDLogDebug(@"[2]》》》》》》》》》》》》》》》》->http返回的最终数据结果：photosCnt=%d, pvoiceCnt=%d", _photosCnt, _pvoiceCnt);

                 // 通知回调
                 complete(YES, _photosCnt, _pvoiceCnt);
             }
             // 此接口在服务端的定义是一定不会返回Nil，哪怕是个空数组
             else
             {
                 complete(NO, _photosCnt, _pvoiceCnt);
             }
         }
         // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
         else
         {
             complete(NO, _photosCnt, _pvoiceCnt);
         }
     } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];// showLocalErrorAlert 为NO表示当出现本地网等异常时不显示提示AlertView，老弹框会影响用户体验
}

// 【接口1008-10-9】查询个人相册、个人介绍语音留言的完整数据列表（目前用于客户端个人信息查看界面中显示照片和语音完整列表时使用）的接口调用.
- (void)queryPhotosOrVoicesListFromServer:(NSString *)resourceOfUid resourceType:(int)resourceType complete:(void (^)(BOOL sucess, NSArray<PhotosOrVoiecesDTO *> *datas))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MGR_PROFILE
                                                  andAction:ACTION_APPEND3
                                                withNewData:@{
                                                              @"user_uid":resourceOfUid,
                                                              @"res_type":[NSString stringWithFormat:@"%d",resourceType]
                                                              }
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue){

        // 将1维数组按服务端的接口返回情况组装成对象列表，方便调用者使用
        NSMutableArray<PhotosOrVoiecesDTO *> *list  = [[NSMutableArray<PhotosOrVoiecesDTO *> alloc] init];

        // 服务端接口处理完成请求
        if(sucess)
        {
            // 返回结果是Java的Vector<RosterElementEntity>形式的数组转JSON后的结果
            if (returnValue !=nil)
            {
                // 将JSON转成OC的1维数组(使用苹果官方的JSON API转2维数组强大一些，EVA框架选用的JSON库RMMapper比较简洁，不太支持这种复杂数据结构)
                NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                NSArray *vec = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];

                // 整个返回数据形如：“[[resourceId、资源文件名、资源大小(人类可读)、资源大 小(单位:字节)、被查看数、上传时间]]”
                // 的2维数组，具体请参见服务端【接口1008-10-9】
                for (NSArray *row in vec)
                {
                    // 将1维数组的每个单元取出来(各单元数据含义请参见http rest接口手册【接口1008-10-9】)
                    int j = 0;
                    NSString *resource_id = (NSString *)[row objectAtIndex:j++];
                    NSString *res_file_name = (NSString *)[row objectAtIndex:j++];
                    NSString *res_human_size = (NSString *)[row objectAtIndex:j++];
                    NSString *res_size = (NSString *)[row objectAtIndex:j++];
                    NSString *view_count = (NSString *)[row objectAtIndex:j++];
                    NSString *create_time = (NSString *)[row objectAtIndex:j++];

                    PhotosOrVoiecesDTO *cr = [[PhotosOrVoiecesDTO alloc] init];
                    cr.resource_id = resource_id;
                    cr.user_uid = resourceOfUid;
                    cr.res_type = [NSString stringWithFormat:@"%d",resourceType];
                    cr.res_file_name = res_file_name;
                    cr.res_human_size = res_human_size;
                    cr.res_size = res_size;
                    cr.view_count = view_count;
                    cr.create_time = create_time;

                    [list addObject:cr];
                }

                // 通知回调
                complete(YES, list);
            }
            //
            else
            {
                complete(NO, list);
            }
        }
        // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
        else
        {
            complete(NO, list);
        }
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];// showLocalErrorAlert 为NO表示当出现本地网等异常时不显示提示AlertView，老弹框会影响用户体验
}

//【接口1008-10-22】查询好友信息中个人相册的预览图片列表（目前用于客户端个人信息查看界面中显示照片和语音预览列表时使用，通常最多只返回该用户的最新4张照片）的接口调用.
- (void)queryPhotosPreviewListFromServer:(NSString *)resourceOfUid complete:(void (^)(BOOL sucess, NSArray<NSArray<NSString *> *> *fileNameList))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MGR_PROFILE
                                                  andAction:ACTION_APPEND4
                                                withNewData:@{
                                                              @"user_uid":resourceOfUid
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

        // 服务端接口处理完成请求
        if(sucess)
        {
            // 返回结果是Java的Vector<Vector<String>>形式的数组转JSON后的结果
            if (returnValue !=nil)
            {
                // 将JSON转成OC的1维数组(使用苹果官方的JSON API转2维数组强大一些，EVA框架选用的JSON库RMMapper比较简洁，不太支持这种复杂数据结构)
                NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                // 整个返回数据形如“[[33232jk2j32k3k.jpg],[3eweweew32k3k.jpg]]”的2维数组，具体请参见服务端【接口1008-10-22】
                NSArray<NSArray<NSString *> *> *vec = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];

                DDLogDebug(@"[2]》》》》》》》》》》》》》》》》->http返回的最终数据结果：vec=%@", vec);

                // 通知回调
                complete(YES, vec);
            }
            // 此接口在服务端的定义是一定不会返回Nil，哪怕是个空数组
            else
            {
                complete(NO, nil);
            }
        }
        // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
        else
        {
            complete(NO, nil);
        }
    } hudParentView:view];
}

//【接口1015-23-7】获取指定md5码的大文件上传信息的接口调用.
- (void)queryBigFileInfoFromServer:(NSString *)fileMd5 userUid:(NSString *)userUid fileType:(int)fileType complete:(void (^)(BOOL sucess, NSString *retCode, int chunkCount))complete hudParentView:(UIView *)view completeForLocalError:(void (^)(NSString *errorLog))completeForLocalError
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_FILE
                                                andDispatch:LOGIC_FILE_MGR
                                                  andAction:ACTION_APPEND1
                                                withNewData:@{
                                                              @"file_md5":fileMd5,
                                                              @"user_uid":userUid,
                                                              @"file_type":[NSString stringWithFormat:@"%d",fileType]
                                                              }
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue){

        
         NSString *_retCode = @"-1";
         NSString *_chunkCountInServer = @"0";

         // 服务端接口处理完成请求
         if(sucess)
         {
             // 返回结果是Java的Vector<RosterElementEntity>形式的数组转JSON后的结果
             if (returnValue !=nil)
             {
                 // 将JSON转成OC的1维数组(使用苹果官方的JSON API转2维数组强大一些，EVA框架选用的JSON库RMMapper比较简洁，不太支持这种复杂数据结构)
                 NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
//                 NSArray *vec = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];
                 NSDictionary* jsonData = [NSJSONSerialization JSONObjectWithData:rdata options:NSJSONReadingMutableContainers error:nil];

                 // 服服务返回的查询结果码（详见http文档中“【接口1015-23-7】”的详细说明）：
                 // * 0 表示该文件不存在(未被上传过)
                 // * 1 表示该文件已经存在且已上传完成（无需再次上传）
                 // * 2 表示该文件已经存在查未上传完成（此时chunkCountInServer才有意义）
                _retCode = [jsonData objectForKey:@"retCode"];
                 // 该文件在服务端已传完的分块个数（为>=0的整数）
                _chunkCountInServer = [jsonData objectForKey:@"chunkCount"];

                 DDLogDebug(@"[2]》》》》》》》》》》》》》》》》->http返回的最终数据结果：_retCode=%@, _chunkCountInServer=%@", _retCode, _chunkCountInServer);

                 // 通知回调
                 complete(YES, _retCode, [BasicTool getIntValue:_chunkCountInServer defaultVal:1]);
             }
             // 此接口在服务端的定义是一定不会返回Nil，哪怕是个空数组
             else
             {
                 complete(NO, _retCode, [BasicTool getIntValue:_chunkCountInServer defaultVal:1]);
             }
         }
         // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
         else
         {
             complete(NO, _retCode, [BasicTool getIntValue:_chunkCountInServer defaultVal:1]);
         }
     } hudParentView:view showLocalErrorAlert:NO completeForLocalError:completeForLocalError];// showLocalErrorAlert 为NO表示当出现本地网等异常时不显示提示AlertView，老弹框会影响用户体验
}

//【接口1008-1-7】用户注册接口调用.
- (void)submitRegisterToServer:(UserRegisterDTO *)registerData complete:(void (^)(BOOL sucess, NSDictionary *registerResult))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_APPEND1
                                                withNewData:registerData
                                                   complete:^(BOOL sucess, NSString *returnValue){

       // 服务端接口处理完成请求
       if(sucess)
       {
           // 返回结果是Java的Vector<Vector<String>>形式的数组转JSON后的结果
           if (returnValue !=nil)
           {
               // 将服务端返回的returnValue里的JSON文本反射成对象，方便调用
               NSDictionary *dic = [EVAToolKits fromJSONBytesToDictionary:[EVACharsetHelper getBytesWithString:returnValue]];

               DDLogDebug(@"[2]》》》》》》》》》》》》》》》》->http返回的最终数据结果：dic=%@", dic);

               // 通知回调
               complete(YES, dic);
           }
           // 此接口在服务端的定义是一定不会返回Nil，哪怕是个空数组
           else
           {
               complete(NO, nil);
           }
       }
       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
       else
       {
           complete(NO, nil);
       }
    } hudParentView:view];
}

//【接口1008-3-9】“密记密码”邮件请求接口调用.
- (void)submitForgotPasswordToServer:(NSString *)receiveProcessedMail complete:(void (^)(BOOL sucess))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_SNS
                                                  andAction:ACTION_APPEND3
                                                withNewData:receiveProcessedMail
                                                   complete:^(BOOL sucess, NSString *returnValue){
                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                            complete(YES);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO);
                                                       }
                                                   }
                                              hudParentView:view];
}

//【接口1008-1-28】手机号+验证码重置密码接口调用.
- (void)submitResetPasswordByPhoneToServer:(NSString *)phoneNum smsCode:(NSString *)smsCode newPassword:(NSString *)newPassword complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_APPEND10
                                                withNewData:@{
                                                              @"phone_num":phoneNum,
                                                              @"sms_code":smsCode,
                                                              @"psw":newPassword
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

//【接口1008-3-7】发送邀请朋友邮件接口调用.
- (void)submitInviteFriendToServer:(NSString *)receiver_mail
                         localNick:(NSString *)local_nickname
                         localMail:(NSString *)local_mail
                          localUid:(NSString *)local_uid
                          complete:(void (^)(BOOL sucess))complete
                     hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_SNS
                                                  andAction:ACTION_APPEND1
                                                withNewData:@{
                                                              @"receiver_mail":receiver_mail,
                                                              @"local_nickname":local_nickname,
                                                              @"local_mail":local_mail,
                                                              @"local_uid":local_uid
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){
                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           complete(YES);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO);
                                                       }
                                                   }
                                              hudParentView:view];
}

// 【接口1008-4-7】获取离线加好友请求的接口调用.
- (void)submitGetOfflineAddFriendsReqToServer:(NSString *)local_uid complete:(void (^)(BOOL sucess, NSArray<UserEntity *> *reqList))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:ACTION_APPEND1
                                                withNewData:local_uid
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
       // 服务端接口处理完成请求
       if(sucess)
       {
           // 返回结果是Java的Vector<RosterElementEntity>形式的数组转JSON后的结果
           if (returnValue !=nil)
           {
               // 将JSON转成OC的1维数组(使用苹果官方的JSON API转2维数组强大一些，EVA框架选用的JSON库RMMapper比较简洁，不太支持这种复杂数据结构)
               NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
               NSArray *vec = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];

               // 再将1维数组按服务端的接口返回情况组装成对象列表，方便调用者使用
               NSMutableArray<UserEntity *> *list  = [[NSMutableArray<UserEntity *> alloc] init];
               for (NSDictionary *row in vec)
               {
                   // 将1维数组的每个单元（字典对象）反射成对象
                   UserEntity *e = [EVAToolKits fromDictionaryToObject:row withClass:UserEntity.class];

//                   NSLog(@"[1]》》》》》》》》》》》》》》》》http返回的查找好友列表中每一行 row.class：%@, row：%@, 反射后e：%@", row.class, row, e);

                   // 加入到返回值集合中
                   [list addObject:e];
               }

//               NSLog(@"[2]》》》》》》》》》》》》》》》》->http返回的组装完的list：%@", list);

               // 通知回调
               complete(YES, list);
           }
           // 此接口在服务端的定义是一定不会返回Nil，哪怕是个空数组
           else
           {
               complete(NO, nil);
           }
       }
       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
       else
       {
           complete(NO, nil);
       }
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];// showLocalErrorAlert 为NO表示当出现本地网等异常时不显示提示AlertView，老弹框会影响用户体验
}

// 【接口1008-4-31】添加好友记录总览：查询当前用户全部添加好友记录.
- (void)submitGetAllAddFriendRecordsToServer:(NSString *)user_uid complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *records))complete hudParentView:(UIView *)view
{
    if (!user_uid || user_uid.length == 0) {
        if (complete) complete(NO, nil);
        return;
    }
    NSDictionary *newData = @{ @"user_uid": user_uid };
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:ACTION_APPEND13
                                                withNewData:newData
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (!sucess || !returnValue || returnValue.length == 0) {
            if (complete) complete(NO, nil);
            return;
        }
        NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *root = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];
        if (![root isKindOfClass:[NSDictionary class]]) {
            if (complete) complete(NO, nil);
            return;
        }
        // 兼容外层包装：可能直接是 { code, records } 或 { returnValue: "{\"code\":0,\"records\":[...]}" }
        NSDictionary *inner = root;
        if (root[@"returnValue"] && [root[@"returnValue"] isKindOfClass:[NSString class]]) {
            NSData *innerData = [root[@"returnValue"] dataUsingEncoding:NSUTF8StringEncoding];
            inner = [NSJSONSerialization JSONObjectWithData:innerData options:0 error:nil];
            if (![inner isKindOfClass:[NSDictionary class]]) inner = root;
        }
        NSNumber *codeNum = inner[@"code"];
        if (codeNum && [codeNum integerValue] != 0) {
            if (complete) complete(NO, nil);
            return;
        }
        NSArray *records = inner[@"records"];
        if (![records isKindOfClass:[NSArray class]]) {
            records = @[];
        }
        if (complete) complete(YES, records);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

// 【接口1008-4-32】单聊通话记录聚合：查询当前用户单聊通话记录（拨出/接听/未接、音视频、时长）.
- (void)submitGetCallRecordsToServer:(NSString *)user_uid
                               page:(NSInteger)page
                           pageSize:(NSInteger)page_size
                           peerUid:(NSString *)peer_uid
                        sinceTime2:(NSString *)since_time2
                           complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *records))complete
                      hudParentView:(UIView *)view
{
    if (!user_uid || user_uid.length == 0) {
        if (complete) complete(NO, nil);
        return;
    }
    NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithObject:user_uid forKey:@"user_uid"];
    if (page >= 1) {
        newData[@"page"] = @(page);
    }
    if (page_size >= 1) {
        newData[@"page_size"] = @(page_size);
    }
    if (peer_uid && peer_uid.length > 0) {
        newData[@"peer_uid"] = peer_uid;
    }
    if (since_time2 && since_time2.length > 0) {
        newData[@"since_time2"] = since_time2;
    }
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:ACTION_APPEND14
                                                withNewData:newData
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (!sucess || !returnValue || returnValue.length == 0) {
            if (complete) complete(NO, nil);
            return;
        }
        NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *root = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];
        if (![root isKindOfClass:[NSDictionary class]]) {
            if (complete) complete(NO, nil);
            return;
        }
        NSDictionary *inner = root;
        if (root[@"returnValue"] && [root[@"returnValue"] isKindOfClass:[NSString class]]) {
            NSData *innerData = [root[@"returnValue"] dataUsingEncoding:NSUTF8StringEncoding];
            inner = [NSJSONSerialization JSONObjectWithData:innerData options:0 error:nil];
            if (![inner isKindOfClass:[NSDictionary class]]) inner = root;
        }
        NSNumber *codeNum = inner[@"code"];
        if (codeNum && [codeNum integerValue] != 0) {
            if (complete) complete(NO, nil);
            return;
        }
        NSArray *records = inner[@"records"];
        if (![records isKindOfClass:[NSArray class]]) {
            records = @[];
        }
        if (complete) complete(YES, records);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

// 【接口1008-4-37】删除单条通话记录（标记不显示）.
- (void)submitDeleteCallRecordToServer:(NSString *)user_uid
                           fingerprint:(NSString *)fingerprint
                              complete:(void (^)(BOOL success, NSString *msg))complete
                         hudParentView:(UIView *)view
{
    if (!user_uid || user_uid.length == 0 || !fingerprint || fingerprint.length == 0) {
        if (complete) complete(NO, @"缺少user_uid或fingerprint");
        return;
    }
    NSDictionary *newData = @{ @"user_uid": user_uid, @"fingerprint": fingerprint };
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:37  // ACTION_DELETE_CALL_RECORD 1008-4-37
                                                withNewData:newData
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (!complete) return;
        if (!sucess || !returnValue || returnValue.length == 0) {
            complete(NO, @"网络异常");
            return;
        }
        NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *root = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];
        if (![root isKindOfClass:[NSDictionary class]]) {
            complete(NO, @"解析失败");
            return;
        }
        NSDictionary *inner = root;
        if (root[@"returnValue"] && [root[@"returnValue"] isKindOfClass:[NSString class]]) {
            NSData *innerData = [root[@"returnValue"] dataUsingEncoding:NSUTF8StringEncoding];
            inner = [NSJSONSerialization JSONObjectWithData:innerData options:0 error:nil];
            if (![inner isKindOfClass:[NSDictionary class]]) inner = root;
        }
        NSNumber *codeNum = inner[@"code"];
        NSString *msg = inner[@"msg"];
        if (codeNum && [codeNum integerValue] != 0) {
            complete(NO, msg.length ? msg : @"删除失败");
            return;
        }
        id successVal = inner[@"success"];
        if (successVal && [successVal isKindOfClass:[NSNumber class]] && ![successVal boolValue]) {
            complete(NO, msg.length ? msg : @"删除未生效");
            return;
        }
        complete(YES, nil);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

//【接口1008-1-8】用户基本信息修改接口调用.
- (void)submitUserBaseInfoModifiyToServer:(NSString *)localUid nick:(NSString *)nickName sex:(NSString *)sex complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_APPEND2
                                                withNewData:@{
                                                              @"nickName":nickName,
                                                              @"sex":sex,
                                                              @"uid":localUid
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

//【接口1008-26-35】昵称是否可用（实时校验）.
- (void)submitNicknameAvailableCheck:(NSString *)uid nickname:(NSString *)nickname complete:(void (^)(BOOL sucess, BOOL available, NSString *msg))complete hudParentView:(UIView *)view
{
    NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithObject:(nickname ?: @"") forKey:@"nickname"];
    if (uid.length > 0) {
        newData[@"uid"] = uid;
    }
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MSG_ROAMING
                                                  andAction:35
                                                withNewData:newData
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (!complete) return;
        if (!sucess || !returnValue || returnValue.length == 0) {
            complete(NO, NO, @"网络异常");
            return;
        }
        NSError *err = nil;
        NSData *data = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
        if (err || ![json isKindOfClass:[NSDictionary class]]) {
            complete(YES, NO, @"解析失败");
            return;
        }
        NSNumber *codeNum = json[@"code"];
        NSNumber *availNum = json[@"available"];
        NSString *msg = [json[@"msg"] isKindOfClass:[NSString class]] ? json[@"msg"] : nil;
        if (!msg) msg = @"";
        BOOL available = (availNum != nil && [availNum boolValue]) || (codeNum != nil && [codeNum integerValue] == 0);
        complete(YES, available, msg);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

//【接口1008-1-9】修改登陆密码接口调用.
- (void)submitUserPasswordModifiyToServer:(NSString *)localUid old:(NSString *)oldPassword new:(NSString *)newPassword smsCode:(NSString *)smsCode complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithDictionary:@{
                                                              @"uid":localUid,
                                                              @"old_psw":oldPassword,
                                                              @"psw":newPassword
                                                              }];
    // 添加短信验证码参数
    if (smsCode && smsCode.length > 0) {
        [newData setObject:smsCode forKey:@"sms_code"];
    }
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_APPEND3
                                                withNewData:newData
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

//【接口1008-1-22】用户What'sUp（个性签名）修改接口调用.
- (void)submitUserWhatsUpModifiyToServer:(NSString *)localUid whatsUp:(NSString *)whats_up complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_APPEND4
                                                withNewData:@{
                                                              @"whats_up":whats_up,
                                                              @"uid":localUid
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

//【接口1008-1-27扩展】发送邮箱验证码接口调用.
- (void)submitGetEmailCode:(NSString *)email uid:(NSString *)uid bizType:(NSString *)bizType complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_APPEND9
                                                withNewData:@{
                                                              @"email": email,
                                                              @"uid": uid,
                                                              @"biz_type": bizType
                                                              }
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue){
                                                       // 服务端接口处理完成请求
                                                       if(sucess){
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败
                                                       else{
                                                           complete(NO, nil);
                                                       }
                                                    }
                                              hudParentView:view
                                        showLocalErrorAlert:NO
                                      completeForLocalError:nil];
}

//【接口1008-1-29】修改/绑定手机号接口调用.
- (void)submitModifyPhoneToServer:(NSString *)uid newPhoneNum:(NSString *)newPhoneNum newPhoneSmsCode:(NSString *)newPhoneSmsCode oldPhoneSmsCode:(NSString *)oldPhoneSmsCode complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithDictionary:@{
                                                              @"uid": uid,
                                                              @"new_phone_num": newPhoneNum,
                                                              @"new_phone_sms_code": newPhoneSmsCode
                                                              }];
    // 如果用户已有手机号，添加旧手机号验证码
    if (oldPhoneSmsCode && oldPhoneSmsCode.length > 0) {
        [newData setObject:oldPhoneSmsCode forKey:@"old_phone_sms_code"];
    }
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_APPEND11
                                                withNewData:newData
                                                   complete:^(BOOL sucess, NSString *returnValue){
                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

//【接口1008-1-30】修改/绑定邮箱接口调用.
- (void)submitModifyEmailToServer:(NSString *)uid newEmail:(NSString *)newEmail newEmailCode:(NSString *)newEmailCode oldEmailCode:(NSString *)oldEmailCode complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithDictionary:@{
                                                              @"uid": uid,
                                                              @"new_email": newEmail,
                                                              @"new_email_code": newEmailCode
                                                              }];
    // 如果用户已有邮箱，添加旧邮箱验证码
    if (oldEmailCode && oldEmailCode.length > 0) {
        [newData setObject:oldEmailCode forKey:@"old_email_code"];
    }
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_APPEND12
                                                withNewData:newData
                                                   complete:^(BOOL sucess, NSString *returnValue){
                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

//【接口1008-1-24】用户的其它说明修改接口调用.
- (void)submitUserOtherCaptionModifiyToServer:(NSString *)localUid otherCaption:(NSString *)otherCaption complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_APPEND6
                                                withNewData:@{
                                                              @"user_desc":otherCaption,
                                                              @"uid":localUid
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

// 【接口1016-25-7】获取用户的群组列表的接口调用.
- (void)submitGetGroupsListFromServer:(NSString *)uid complete:(void (^)(BOOL sucess, NSArray<GroupEntity *> *groupsList))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT andDispatch:LOGIC_GROUP_QUERY_MGR
                                                  andAction:ACTION_APPEND1
                                                withNewData:uid
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        // 服务端接口处理完成请求
        if(sucess)
        {
            // 返回结果是Java的Vector<GroupEntity>形式的数组转JSON后的结果
            if (returnValue !=nil)
            {
                // 将JSON转成OC的2维数组(使用苹果官方的JSON API转2维数组强大一些，EVA框架选用的JSON库RMMapper比较简洁，不太支持这种复杂数据结构)
                NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                NSArray *vec = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];

                // 再将2维数据按服务端的接口返回情况组装成对象列表，方便调用者使用
                NSMutableArray<GroupEntity *> *list  = [[NSMutableArray<GroupEntity *> alloc] init];
                for (NSDictionary *row in vec)
                {
                    // 将2维数组的每个单元（字典对象）反射成对象
                    GroupEntity *e = [EVAToolKits fromDictionaryToObject:row withClass:GroupEntity.class];

#if DEBUG
                    NSLog(@"【群列表】gid=%@, gname=%@, group_mode=%d, row_keys=%@",
                          e.g_id, e.g_name, e.group_mode, [row allKeys]);
#endif

                    // 加入到返回值集合中
                    [list addObject:e];
                }

//                NSLog(@"[2]》》》》》》》》》》》》》》》》->http返回的组装完的list：%@", list);

                // 通知回调
                complete(YES, list);
            }
            // 此接口在服务端的定义是一定不会返回Nil，哪怕是个空数组
            else
            {
                complete(NO, nil);
            }
        }
        // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
        else
        {
            complete(NO, nil);
        }
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];// showLocalErrorAlert 为NO表示当出现本地网等异常时不显示提示AlertView，老弹框会影响用户体验
}

// 【接口1016-25-8】查询群基本信息的接口调用.
- (void)submitGetGroupInfoToServer:(NSString *)gid myUserId:(NSString *)myUserId complete:(void (^)(BOOL sucess, GroupEntity *groupInfo))complete hudParentView:(UIView *)view
{
    if (gid.length == 0) {
        if (complete) {
            complete(NO, nil);
        }
        return;
    }
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_QUERY_MGR
                                                  andAction:ACTION_APPEND2
                                                withNewData:@{
                                                              // 查询的群id
                                                              @"gid":gid,
                                                              // 非必须参数，如果本参数不为空，则表示要同时把”我“在该群中的昵称给查出来，否则不需要查
                                                              @"my_user_id":(myUserId == nil?@"":myUserId)
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 将服务端返回的returnValue里的JSON文本反射成对象，方便调用
                                                           GroupEntity *gi = [EVAToolKits fromJSON:returnValue withClazz:GroupEntity.class];

                                                           // 通知回调
                                                           complete(YES, gi);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

//【接口1016-24-8】修改群名称接口调用.
- (void)submitGroupNameModifiyToServer:(NSString *)group_name gid:(NSString *)gid modify_by_uid:(NSString *)modify_by_uid modify_by_nickname:(NSString *)modify_by_nickname complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND2
                                                withNewData:@{
                                                              @"group_name":group_name,
                                                              @"gid":gid,
                                                              @"modify_by_uid":modify_by_uid,
                                                              @"modify_by_nickname":modify_by_nickname
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

// 【接口1016-24-9】修改"我"的群昵称接口调用.
- (void)submitGroupNickNameModifiyToServer:(NSString *)nickname_ingroup gid:(NSString *)gid user_uid:(NSString *)user_uid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND3
                                                withNewData:@{
                                                              @"nickname_ingroup":nickname_ingroup,
                                                              @"gid":gid,
                                                              @"user_uid":user_uid
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

// 【接口1016-24-22】修改群公告接口调用.
- (void)submitGroupNoticeModifiyToServer:(NSString *)g_notice g_notice_updateuid:(NSString *)g_notice_updateuid gid:(NSString *)gid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND4
                                                withNewData:@{
                                                              @"g_notice":g_notice,
                                                              @"g_notice_updateuid":g_notice_updateuid,
                                                              @"g_id":gid
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

// 【接口1016-24-23】删除群成员或退群接口调用.
- (void)submitDeleteOrQuitGroupToServer:(NSString *)del_opr_uid del_opr_nickname:(NSString *)del_opr_nickname gid:(NSString *)gid membersBeDelete:(NSArray<NSArray *> *)membersBeDelete complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND5
                                                withNewData:@{
                                                              @"del_opr_uid":del_opr_uid,
                                                              @"del_opr_nickname":del_opr_nickname,
                                                              @"gid":gid,
//                                                              @"gname":gname,
                                                              @"members":[EVAToolKits toJSON:membersBeDelete]
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

// 【接口1016-24-26】解散群（仅开放给群主）接口调用.
- (void)submitDismissGroupToServer:(NSString *)owner_uid owner_nickname:(NSString *)owner_nickname gid:(NSString *)gid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND8
                                                withNewData:@{
                                                              @"owner_uid":owner_uid,
                                                              @"owner_nickname":owner_nickname,
                                                              @"g_id":gid,
//                                                              @"g_name":gname
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

// 【接口1016-25-9】查询群成员列表的接口调用（不分页，内部调用分页接口 page=0 pageSize=0）.
- (void)submitGetGroupMembersListFromServer:(NSString *)gid requestUid:(NSString *)requestUid complete:(void (^)(BOOL sucess, NSMutableArray<GroupMemberEntity *> *groupMembersList))complete hudParentView:(UIView *)view
{
    [self submitGetGroupMembersListFromServer:gid requestUid:requestUid page:0 pageSize:0 complete:complete hudParentView:view];
}

// 【接口1016-25-9】查询群成员列表（支持分页，page>0 且 pageSize>0 时传参；单次最多 500 条）.
- (void)submitGetGroupMembersListFromServer:(NSString *)gid requestUid:(NSString *)requestUid page:(int)page pageSize:(int)pageSize complete:(void (^)(BOOL sucess, NSMutableArray<GroupMemberEntity *> *groupMembersList))complete hudParentView:(UIView *)view
{
    // gid 为 nil 时 @{@"gid": gid} 会向 NSDictionary 插入 nil，触发 NSInvalidArgumentException（objects[0]）
    if (gid.length == 0) {
        if (complete) {
            complete(NO, nil);
        }
        return;
    }
    NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithDictionary:@{@"gid": gid}];
    if (requestUid != nil && requestUid.length > 0) {
        [newData setObject:requestUid forKey:@"request_uid"];
    }
    if (page > 0 && pageSize > 0) {
        [newData setObject:@(page) forKey:@"page"];
        [newData setObject:@(pageSize) forKey:@"page_size"];
    }

    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT andDispatch:LOGIC_GROUP_QUERY_MGR andAction:ACTION_APPEND3 withNewData:newData complete:^(BOOL sucess, NSString *returnValue) {
        // 服务端接口处理完成请求
        if(sucess)
        {
            // 返回结果是Java的Vector<GroupMemberEntity>形式的数组转JSON后的结果
            if (returnValue !=nil)
            {
                // 将JSON转成OC的2维数组(使用苹果官方的JSON API转2维数组强大一些，EVA框架选用的JSON库RMMapper比较简洁，不太支持这种复杂数据结构)
                NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                id vecObj = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];
                if (![vecObj isKindOfClass:[NSArray class]])
                {
                    complete(NO, nil);
                    return;
                }
                NSArray *vec = (NSArray *)vecObj;

                // 再将2维数据按服务端的接口返回情况组装成对象列表，方便调用者使用
                NSMutableArray<GroupMemberEntity *> *list  = [[NSMutableArray<GroupMemberEntity *> alloc] init];
                for (id row in vec)
                {
                    if (![row isKindOfClass:[NSDictionary class]]) continue;
                    // 将2维数组的每个单元（字典对象）反射成对象
                    GroupMemberEntity *e = [EVAToolKits fromDictionaryToObject:row withClass:GroupMemberEntity.class];

#if DEBUG
                    NSLog(@"[1]群成员列表每行 row.class:%@ row:%@ e:%@", [row class], row, e);
#endif
                    if (e == nil) continue;

                    // 加入到返回值集合中
                    [list addObject:e];
                }

#if DEBUG
                NSLog(@"[2]群成员列表组装完成 count=%lu", (unsigned long)list.count);
#endif

                // 通知回调
                complete(YES, list);
            }
            // 此接口在服务端的定义是一定不会返回Nil，哪怕是个空数组
            else
            {
                complete(NO, nil);
            }
        }
        // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
        else
        {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1016-24-7】创建群组的接口调用.
- (void)submitCreateGroupToServer:(NSString *)localUserUid localUserNickname:(NSString *)localUserNickname members:(NSArray<GroupMemberEntity *> *)membersOfNewGroup complete:(void (^)(BOOL sucess, GroupEntity *newGroupInfo))complete hudParentView:(UIView *)view
{
    [self submitCreateGroupToServer:localUserUid localUserNickname:localUserNickname groupName:nil avatarUrl:nil members:membersOfNewGroup complete:complete hudParentView:view];
}

- (void)submitCreateGroupToServer:(NSString *)localUserUid localUserNickname:(NSString *)localUserNickname groupName:(NSString *)groupName avatarUrl:(NSString *)avatarUrl members:(NSArray<GroupMemberEntity *> *)membersOfNewGroup complete:(void (^)(BOOL sucess, GroupEntity *newGroupInfo))complete hudParentView:(UIView *)view
{
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    data[@"owner_uid"] = localUserUid;
    data[@"owner_nickname"] = localUserNickname;
    data[@"members"] = [EVAToolKits toJSONForObjectsArray:membersOfNewGroup];
    if (groupName.length > 0) data[@"group_name"] = groupName;
    if (avatarUrl.length > 0) data[@"avatar_url"] = avatarUrl;
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND1
                                                withNewData:data
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 返回值“0”表示服务端虽成功处理完成接口请求，但建群是失败的！(详见"【接口1016-24-7】"文档)
                                                           if([@"0" isEqualToString:returnValue])
                                                           {
                                                               // 通知回调
                                                               complete(NO, nil);
                                                           }
                                                           else
                                                           {
                                                               // 将服务端返回的returnValue里的JSON文本反射成对象，方便调用
                                                               GroupEntity *gi = [EVAToolKits fromJSON:returnValue withClazz:GroupEntity.class];

                                                               // 通知回调
                                                               complete(YES, gi);
                                                           }
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

// 【接口1016-24-24】邀请入群的接口调用.
- (void)submitInviteToGroupToServer:(NSString *)srcFrom invite_uid:(NSString *)invite_uid invite_nickname:(NSString *)invite_nickname invite_to_gid:(NSString *)invite_to_gid  members:(NSArray<NSArray *> *)members complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND6
                                                withNewData:@{
                                                              // 加群来源
                                                              @"src_from":srcFrom,
                                                              // 邀请发起人的uid
                                                              @"invite_uid":invite_uid,
                                                              // 邀请发起人的昵称
                                                              @"invite_nickname":invite_nickname,
                                                              // 邀请至群
                                                              @"invite_to_gid":invite_to_gid,
                                                              // 被邀请的成员
                                                              @"members":[EVAToolKits toJSON:members]
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}

// 【接口1016-24-25】转让本群（仅开放给群主）接口调用.
- (void)submitTransferGroupToServer:(NSString *)old_owner_uid new_owner_uid:(NSString *)new_owner_uid new_owner_nickname:(NSString *)new_owner_nickname gid:(NSString *)gid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND7
                                                withNewData:@{
                                                              @"old_owner_uid":old_owner_uid,
//                                                              @"old_owner_nickname":old_owner_nickname,
                                                              @"new_owner_uid":new_owner_uid,
                                                              @"new_owner_nickname":new_owner_nickname,
                                                              @"g_id":gid,
//                                                              @"g_name":gname
                                                              }
                                                   complete:^(BOOL sucess, NSString *returnValue){

                                                       // 服务端接口处理完成请求
                                                       if(sucess)
                                                       {
                                                           // 通知回调
                                                           complete(YES, returnValue);
                                                       }
                                                       // 请求处理失败（表示请求已到服务端，但服务端的代码逻辑判定本次请求没有成功完成等）
                                                       else
                                                       {
                                                           complete(NO, nil);
                                                       }
                                                   } hudParentView:view];
}


// ========================== 群聊管理新增接口 ==========================

// 【接口1016-24-27】设置/取消管理员的接口调用.
- (void)submitSetGroupAdminToServer:(NSString *)oprUid
                          targetUid:(NSString *)targetUid
                                gid:(NSString *)gid
                               role:(int)role
                           complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                      hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND9
                                                withNewData:@{
                                                    @"opr_uid": oprUid,
                                                    @"target_uid": targetUid,
                                                    @"g_id": gid,
                                                    @"role": @(role)
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1016-24-28】设置全群禁言模式的接口调用.
- (void)submitSetGroupMuteModeToServer:(NSString *)oprUid
                                   gid:(NSString *)gid
                              muteMode:(int)muteMode
                              complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                         hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND10
                                                withNewData:@{
                                                    @"opr_uid": oprUid,
                                                    @"g_id": gid,
                                                    @"mute_mode": @(muteMode)
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1016-24-29】单人禁言的接口调用.
- (void)submitMuteGroupMemberToServer:(NSString *)oprUid
                            targetUid:(NSString *)targetUid
                                  gid:(NSString *)gid
                           muteUntil2:(long long)muteUntil2
                             complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                        hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND11
                                                withNewData:@{
                                                    @"opr_uid": oprUid,
                                                    @"target_uid": targetUid,
                                                    @"g_id": gid,
                                                    @"mute_until2": @(muteUntil2)
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1016-24-30】取消单人禁言的接口调用.
- (void)submitUnmuteGroupMemberToServer:(NSString *)oprUid
                              targetUid:(NSString *)targetUid
                                    gid:(NSString *)gid
                               complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                          hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND12
                                                withNewData:@{
                                                    @"opr_uid": oprUid,
                                                    @"target_uid": targetUid,
                                                    @"g_id": gid
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1016-24-31】设置自定义群头像的接口调用.
- (void)submitSetGroupAvatarToServer:(NSString *)oprUid
                                 gid:(NSString *)gid
                           avatarUrl:(NSString *)avatarUrl
                            complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                       hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND13
                                                withNewData:@{
                                                    @"opr_uid": oprUid,
                                                    @"g_id": gid,
                                                    @"avatar_url": avatarUrl
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1016-24-32】修改群设置的接口调用.
- (void)submitModifyGroupSettingsToServer:(NSString *)oprUid
                                      gid:(NSString *)gid
                                 settings:(NSDictionary *)settings
                                 complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                            hudParentView:(UIView *)view
{
    NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithDictionary:@{
        @"opr_uid": oprUid,
        @"g_id": gid
    }];
    // 合并需要修改的设置字段
    if (settings != nil) {
        [newData addEntriesFromDictionary:settings];
    }

    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND14
                                                withNewData:newData
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1016-24-33】审核入群申请的接口调用.
- (void)submitReviewJoinRequestToServer:(NSString *)oprUid
                                    gid:(NSString *)gid
                              requestId:(NSString *)requestId
                               decision:(int)decision
                               complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                          hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_BASE_MGR
                                                  andAction:ACTION_APPEND15
                                                withNewData:@{
                                                    @"opr_uid": oprUid,
                                                    @"g_id": gid,
                                                    @"request_id": requestId,
                                                    @"decision": @(decision)
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1016-25-22】查询待审核入群申请列表的接口调用.
- (void)submitQueryJoinRequestsFromServer:(NSString *)gid
                                   oprUid:(NSString *)oprUid
                                 complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *requestList))complete
                            hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_QUERY_MGR
                                                  andAction:ACTION_APPEND4
                                                withNewData:@{
                                                    @"g_id": gid,
                                                    @"opr_uid": oprUid
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            if (returnValue != nil && returnValue.length > 0) {
                NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                NSError *jsonError = nil;
                NSArray<NSDictionary *> *list = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:&jsonError];
                if (jsonError) {
                    DDLogWarn(@"【HttpRestHelper】submitQueryJoinRequestsFromServer JSON解析失败: %@", jsonError);
                    complete(NO, nil);
                } else {
                    complete(YES, list);
                }
            } else {
                complete(YES, @[]);
            }
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1016-25-23】查询群禁言成员列表的接口调用.
- (void)submitQueryMutedMembersFromServer:(NSString *)gid
                                 complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *mutedList))complete
                            hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_QUERY_MGR
                                                  andAction:ACTION_APPEND5
                                                withNewData:@{
                                                    @"g_id": gid
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            if (returnValue != nil && returnValue.length > 0) {
                NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                NSError *jsonError = nil;
                NSArray<NSDictionary *> *list = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:&jsonError];
                if (jsonError) {
                    DDLogWarn(@"【HttpRestHelper】submitQueryMutedMembersFromServer JSON解析失败: %@", jsonError);
                    complete(NO, nil);
                } else {
                    complete(YES, list);
                }
            } else {
                complete(YES, @[]);
            }
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1016-25-24】查询群完整设置的接口调用.
- (void)submitQueryGroupSettingsFromServer:(NSString *)gid
                                  complete:(void (^)(BOOL sucess, NSDictionary *settings))complete
                             hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_QUERY_MGR
                                                  andAction:ACTION_APPEND6
                                                withNewData:@{
                                                    @"g_id": gid
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            if (returnValue != nil && returnValue.length > 0) {
                NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                NSError *jsonError = nil;
                NSDictionary *settings = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:&jsonError];
                if (jsonError) {
                    DDLogWarn(@"【HttpRestHelper】submitQueryGroupSettingsFromServer JSON解析失败: %@", jsonError);
                    complete(NO, nil);
                } else {
                    complete(YES, settings);
                }
            } else {
                complete(YES, nil);
            }
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

- (void)submitQueryGroupAdminNotificationsFromServer:(NSString *)gid
                                          requestUid:(NSString *)requestUid
                                                page:(NSInteger)page
                                            pageSize:(NSInteger)pageSize
                                            complete:(void (^)(BOOL sucess, NSDictionary *result))complete
                                       hudParentView:(UIView *)view
{
    if (gid.length == 0 || requestUid.length == 0) {
        if (complete) complete(NO, nil);
        return;
    }

    NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithDictionary:@{
        @"g_id": gid,
        @"request_uid": requestUid
    }];
    if (page >= 1) {
        newData[@"page"] = @(page);
    }
    if (pageSize >= 1) {
        newData[@"page_size"] = @(pageSize);
    }

    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:kJobDispatchGroupNotifications
                                                  andAction:kActionQueryGroupNotifications
                                                withNewData:newData
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (!complete) return;
        NSDictionary *json = RBHttpParseWrappedJSONObject(returnValue);
        if (!sucess || !RBHttpWrappedResponseIsSuccess(json)) {
            complete(NO, nil);
            return;
        }
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:json ?: @{}];
        NSArray *notifications = json[@"notifications"];
        result[@"notifications"] = [notifications isKindOfClass:[NSArray class]] ? notifications : @[];
        complete(YES, result);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitGetGroupAdminNotificationDetailFromServer:(NSString *)notificationId
                                             requestUid:(NSString *)requestUid
                                               complete:(void (^)(BOOL sucess, NSDictionary *detail))complete
                                          hudParentView:(UIView *)view
{
    if (notificationId.length == 0 || requestUid.length == 0) {
        if (complete) complete(NO, nil);
        return;
    }

    NSDictionary *newData = @{
        @"notification_id": notificationId,
        @"request_uid": requestUid
    };

    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:kJobDispatchGroupNotifications
                                                  andAction:kActionGetGroupNotificationDetail
                                                withNewData:newData
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (!complete) return;
        NSDictionary *json = RBHttpParseWrappedJSONObject(returnValue);
        if (!sucess || !RBHttpWrappedResponseIsSuccess(json)) {
            complete(NO, nil);
            return;
        }
        complete(YES, json ?: @{});
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}

- (void)submitQueryAllGroupNotificationsFromServer:(NSString *)requestUid
                                              page:(NSInteger)page
                                          pageSize:(NSInteger)pageSize
                                          complete:(void (^)(BOOL sucess, NSDictionary *result))complete
                                     hudParentView:(UIView *)view
{
    if (requestUid.length == 0) {
        if (complete) complete(NO, nil);
        return;
    }

    NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithDictionary:@{
        @"request_uid": requestUid
    }];
    if (page >= 1) {
        newData[@"page"] = @(page);
    }
    if (pageSize >= 1) {
        newData[@"page_size"] = @(pageSize);
    }

    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:kJobDispatchGroupNotifications
                                                  andAction:kActionQueryAllGroupNotifications
                                                withNewData:newData
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (!complete) return;
        if (!sucess || ![returnValue isKindOfClass:[NSString class]] || returnValue.length == 0) {
            complete(NO, nil);
            return;
        }

        NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
        id rootObj = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];
        if (![rootObj isKindOfClass:[NSDictionary class]]) {
            complete(NO, nil);
            return;
        }

        NSDictionary *root = (NSDictionary *)rootObj;
        id successVal = root[@"success"];
        if ([successVal isKindOfClass:[NSNumber class]] && ![(NSNumber *)successVal boolValue]) {
            complete(NO, nil);
            return;
        }
        if ([successVal isKindOfClass:[NSString class]]) {
            NSString *sv = [(NSString *)successVal lowercaseString];
            if ([sv isEqualToString:@"false"] || [sv isEqualToString:@"0"]) {
                complete(NO, nil);
                return;
            }
        }

        NSDictionary *result = nil;
        id innerObj = root[@"returnValue"];
        if ([innerObj isKindOfClass:[NSDictionary class]]) {
            result = (NSDictionary *)innerObj;
        } else if ([innerObj isKindOfClass:[NSString class]] && [((NSString *)innerObj) length] > 0) {
            NSData *innerData = [((NSString *)innerObj) dataUsingEncoding:NSUTF8StringEncoding];
            id parsedInner = [NSJSONSerialization JSONObjectWithData:innerData options:0 error:nil];
            if ([parsedInner isKindOfClass:[NSDictionary class]]) {
                result = (NSDictionary *)parsedInner;
            }
        } else if ([root[@"notifications"] isKindOfClass:[NSArray class]]) {
            result = root;
        }

        if (![result isKindOfClass:[NSDictionary class]]) {
            complete(NO, nil);
            return;
        }

        NSMutableDictionary *normalized = [NSMutableDictionary dictionaryWithDictionary:result];
        NSArray *notifications = result[@"notifications"];
        normalized[@"notifications"] = [notifications isKindOfClass:[NSArray class]] ? notifications : @[];
        complete(YES, normalized);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}


// ========================== 消息漫游 · 本地删除 · 已读回执 ==========================

//【接口1008-4-22】删除整个会话（软删除）的接口调用.
- (void)submitDeleteConversationToServer:(NSString *)luid
                                    ruid:(NSString *)ruid
                                     gid:(NSString *)gid
                                complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                           hudParentView:(UIView *)view
{
    NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithDictionary:@{@"luid": luid}];
    if (ruid != nil && ruid.length > 0) {
        [newData setObject:ruid forKey:@"ruid"];
    }
    if (gid != nil && gid.length > 0) {
        [newData setObject:gid forKey:@"gid"];
    }

    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:ACTION_APPEND4
                                                withNewData:newData
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

//【接口1008-4-23】删除单条消息（软删除）的接口调用.
- (void)submitDeleteSingleMessageToServer:(NSString *)luid
                            fpForMessage:(NSString *)fpForMessage
                                complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                           hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:ACTION_APPEND5
                                                withNewData:@{
                                                    @"luid": luid,
                                                    @"fp_for_message": fpForMessage
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

//【接口1008-4-24】上报已读回执的接口调用.
- (void)submitReportReadReceiptToServer:(NSString *)luid
                              partnerId:(NSString *)partnerId
                               chatType:(NSString *)chatType
                         lastReadTime2:(NSString *)lastReadTime2
                               complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                          hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:ACTION_APPEND6
                                                withNewData:@{
                                                    @"luid": luid,
                                                    @"partner_id": partnerId,
                                                    @"chat_type": chatType,
                                                    @"last_read_time2": lastReadTime2
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

//【接口1008-4-25】查询对方已读回执的接口调用.
- (void)submitQueryReadReceiptFromServer:(NSString *)luid
                               partnerId:(NSString *)partnerId
                                chatType:(NSString *)chatType
                                complete:(void (^)(BOOL sucess, NSString *lastReadTime2))complete
                           hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:ACTION_APPEND7
                                                withNewData:@{
                                                    @"luid": luid,
                                                    @"partner_id": partnerId,
                                                    @"chat_type": chatType
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            if (returnValue != nil) {
                NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:rdata options:NSJSONReadingMutableContainers error:nil];
                NSString *lastReadTime2 = [jsonData objectForKey:@"last_read_time2"];
                complete(YES, lastReadTime2 != nil ? lastReadTime2 : @"0");
            } else {
                complete(YES, @"0");
            }
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

//【接口1008-4-38】会话消息免打扰设置（newData：luid、partner_id、chat_type、is_mute）
- (void)submitConversationMsgMuteToServer:(NSString *)luid
                               partnerId:(NSString *)partnerId
                                chatType:(NSString *)chatType
                                  muteOn:(BOOL)muteOn
                                complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                           hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:ACTION_CONVERSATION_MSG_MUTE
                                                withNewData:@{
                                                    @"luid": luid ?: @"",
                                                    @"partner_id": partnerId ?: @"",
                                                    @"chat_type": chatType ?: @"0",
                                                    @"is_mute": muteOn ? @"1" : @"0"
                                                }
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

- (void)submitQueryChatHistoryFromServer:(NSString *)localUid
                               remoteUid:(NSString *)remoteUid
                                     gid:(NSString *)gid
                                rowCount:(NSInteger)rowCount
                            endTimestamp:(NSString *)endTimestamp
                          endFingerprint:(NSString *)endFingerprint
                                complete:(void (^)(BOOL success, NSArray<NSArray *> * _Nullable messages, BOOL hasMore))complete
                           hudParentView:(UIView *)view
{
    if (localUid.length == 0 || (remoteUid.length == 0 && gid.length == 0)) {
        NSLog(@"【HttpRestHelper】submitQueryChatHistoryFromServer 参数非法 localUid=%@ remoteUid=%@ gid=%@",
              localUid ?: @"", remoteUid ?: @"", gid ?: @"");
        if (complete) complete(NO, nil, NO);
        return;
    }

    NSInteger safeRowCount = MAX(1, rowCount);
    NSMutableDictionary *newData = [NSMutableDictionary dictionaryWithDictionary:@{
        @"luid": localUid,
        @"orderby": @"1",
        @"rowcount": @(safeRowCount)
    }];
    if (gid.length > 0) {
        newData[@"gid"] = gid;
    } else {
        newData[@"ruid"] = remoteUid ?: @"";
    }
    if (endTimestamp.length > 0) {
        newData[@"endtimestamp"] = endTimestamp;
        newData[@"includeendtimestamp"] = @"0";
    }
    if (endFingerprint.length > 0) {
        newData[@"endfingerprint"] = endFingerprint;
    }

    NSLog(@"【HttpRestHelper】submitQueryChatHistoryFromServer 请求 newData=%@", newData);
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MSG_ROAMING
                                                  andAction:ACTION_APPEND2
                                                withNewData:newData
                                                 andOldData:nil
                                                   progress:nil
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (!sucess || returnValue.length == 0) {
            NSLog(@"【HttpRestHelper】submitQueryChatHistoryFromServer 请求失败 sucess=%d returnValue=%@", sucess, returnValue);
            if (complete) complete(NO, nil, NO);
            return;
        }

        NSError *jsonError = nil;
        NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
        id jsonObj = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:&jsonError];
        if (jsonError) {
            NSLog(@"【HttpRestHelper】submitQueryChatHistoryFromServer JSON解析失败: %@", jsonError);
            if (complete) complete(NO, nil, NO);
            return;
        }

        NSArray<NSArray *> *messages = nil;
        BOOL hasMore = NO;
        if ([jsonObj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *result = (NSDictionary *)jsonObj;
            id codeObj = result[@"code"];
            if (codeObj != nil && [codeObj respondsToSelector:@selector(integerValue)] && [codeObj integerValue] != 0) {
                NSLog(@"【HttpRestHelper】submitQueryChatHistoryFromServer 服务端返回错误: %@", result);
                if (complete) complete(NO, nil, NO);
                return;
            }
            id rows = result[@"messages"];
            if ([rows isKindOfClass:[NSArray class]]) {
                messages = (NSArray<NSArray *> *)rows;
            }
            id hasMoreObj = result[@"has_more"];
            if ([hasMoreObj isKindOfClass:[NSNumber class]]) {
                hasMore = [hasMoreObj boolValue];
            } else if ([hasMoreObj isKindOfClass:[NSString class]]) {
                hasMore = [((NSString *)hasMoreObj) boolValue];
            }
        } else if ([jsonObj isKindOfClass:[NSArray class]]) {
            messages = (NSArray<NSArray *> *)jsonObj;
            hasMore = messages.count >= safeRowCount;
        }

        NSLog(@"【HttpRestHelper】submitQueryChatHistoryFromServer 成功 rows=%lu hasMore=%d",
              (unsigned long)messages.count, hasMore ? 1 : 0);
        if (complete) complete(YES, messages ?: @[], hasMore);
    } hudParentView:view showLocalErrorAlert:NO completeForLocalError:nil];
}


// ========================== 声网(Agora) Token ==========================

//【接口1008-1-35】请求声网Agora RTC Token.
- (void)requestAgoraToken:(NSString *)uid
                calleeUid:(NSString *)calleeUid
                 complete:(void (^)(BOOL success, NSString *token, NSString *channelName, NSString *appId, NSUInteger agoraUid))complete
{
    if (uid == nil || uid.length == 0) {
        NSLog(@"【HttpRestHelper】requestAgoraToken 失败：uid 为空");
        if (complete) complete(NO, nil, nil, nil, 0);
        return;
    }
    
    // 构造 newData JSON 字符串：{"uid":"400202","callee_uid":"400204"}
    NSMutableDictionary *newDataDict = [NSMutableDictionary dictionary];
    [newDataDict setObject:uid forKey:@"uid"];
    if (calleeUid != nil && calleeUid.length > 0) {
        [newDataDict setObject:calleeUid forKey:@"callee_uid"];
    }
    
    NSLog(@"【HttpRestHelper】requestAgoraToken 发送请求: uid=%@, callee_uid=%@", uid, calleeUid);
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_AGORA_TOKEN
                                                withNewData:newDataDict
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        NSLog(@"【HttpRestHelper】requestAgoraToken 收到响应: sucess=%d, returnValue=%@", sucess, returnValue);
        
        if (sucess && returnValue != nil && returnValue.length > 0) {
            // 检查服务端错误返回
            if ([returnValue isEqualToString:@"agora_not_configured"]) {
                NSLog(@"【HttpRestHelper】requestAgoraToken 失败：服务端未配置声网App ID/Certificate");
                if (complete) complete(NO, nil, nil, nil, 0);
                return;
            }
            if ([returnValue isEqualToString:@"channel_name_required"]) {
                NSLog(@"【HttpRestHelper】requestAgoraToken 失败：未提供callee_uid或group_id");
                if (complete) complete(NO, nil, nil, nil, 0);
                return;
            }
            if ([returnValue isEqualToString:@"token_generate_failed"]) {
                NSLog(@"【HttpRestHelper】requestAgoraToken 失败：Token生成失败");
                if (complete) complete(NO, nil, nil, nil, 0);
                return;
            }
            
            // 解析 returnValue JSON
            // 期望格式：{"token":"007eJxT...","channel_name":"call_400202_400204","app_id":"xxx","uid":400202,"expire_seconds":3600}
            NSError *jsonError = nil;
            NSData *jsonData = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
            
            if (jsonError || ![result isKindOfClass:[NSDictionary class]]) {
                NSLog(@"【HttpRestHelper】requestAgoraToken JSON解析失败: %@", jsonError);
                if (complete) complete(NO, nil, nil, nil, 0);
                return;
            }
            
            NSString *token = result[@"token"];
            NSString *channelName = result[@"channel_name"];
            id appIdRaw = result[@"app_id"];
            NSString *appId = ([appIdRaw isKindOfClass:[NSString class]] && [(NSString *)appIdRaw length] > 0) ? (NSString *)appIdRaw : nil;
            NSUInteger agoraUid = [result[@"uid"] unsignedIntegerValue];
            
            if (token == nil || token.length == 0) {
                NSLog(@"【HttpRestHelper】requestAgoraToken 失败：返回的token为空");
                if (complete) complete(NO, nil, nil, nil, 0);
                return;
            }
            
            NSLog(@"【HttpRestHelper】requestAgoraToken 成功: channelName=%@, app_id=%@, agoraUid=%lu", channelName, appId ?: @"(缺省，客户端将用 Default.h AGORA_APP_ID)", (unsigned long)agoraUid);
            if (complete) complete(YES, token, channelName, appId, agoraUid);
        } else {
            NSLog(@"【HttpRestHelper】requestAgoraToken 请求失败或返回为空");
            if (complete) complete(NO, nil, nil, nil, 0);
        }
    } hudParentView:nil];
}


#pragma mark - VoIP PushKit Token 上传

- (void)uploadVoIPToken:(NSString *)uid
              voipToken:(NSString *)voipToken
               complete:(void (^)(BOOL success))complete
{
    if (uid == nil || uid.length == 0 || voipToken == nil || voipToken.length == 0) {
        NSLog(@"【HttpRestHelper】uploadVoIPToken 失败：uid 或 voipToken 为空");
        if (complete) complete(NO);
        return;
    }
    
    // 构造 newData JSON：{"uid":"400069","voip_token":"a1b2c3d4..."}
    NSDictionary *newDataDict = @{@"uid": uid, @"voip_token": voipToken};
    
    NSLog(@"【HttpRestHelper】uploadVoIPToken 发送请求: uid=%@, voip_token长度=%lu", uid, (unsigned long)voipToken.length);
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_REGISTER
                                                  andAction:ACTION_UPLOAD_VOIP_TOKEN
                                                withNewData:newDataDict
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        NSLog(@"【HttpRestHelper】uploadVoIPToken 收到响应: sucess=%d, returnValue=%@", sucess, returnValue);
        
        if (sucess && returnValue != nil && returnValue.length > 0) {
            // 尝试解析 returnValue，检查内层的 success 字段
            NSData *jsonData = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            if ([result isKindOfClass:[NSDictionary class]] && [[result objectForKey:@"success"] boolValue]) {
                NSLog(@"【HttpRestHelper】uploadVoIPToken 上传成功！");
                if (complete) complete(YES);
            } else {
                NSLog(@"【HttpRestHelper】uploadVoIPToken 服务端返回失败: %@", returnValue);
                if (complete) complete(NO);
            }
        } else {
            NSLog(@"【HttpRestHelper】uploadVoIPToken 请求失败或返回为空");
            if (complete) complete(NO);
        }
    } hudParentView:nil];
}


// ========================== 群聊已读回执统计 ==========================

// 【接口1008-4-29】查询群消息已读回执统计
- (void)submitGroupReadStatsFromServer:(NSString *)groupId
                              msgTime2:(NSString *)msgTime2
                                  luid:(NSString *)luid
                              complete:(void (^)(BOOL success, NSDictionary * _Nullable result))complete
{
    if (!groupId || groupId.length == 0 || !msgTime2 || msgTime2.length == 0 || !luid || luid.length == 0) {
        NSLog(@"【HttpRestHelper】群已读统计失败：参数为空 (gid=%@, time=%@, luid=%@)", groupId, msgTime2, luid);
        if (complete) complete(NO, nil);
        return;
    }
    
    NSDictionary *newDataDict = @{
        @"group_id":  groupId,
        @"msg_time2": msgTime2,
        @"luid":      luid
    };
    
    NSLog(@"【HttpRestHelper】群已读统计请求: gid=%@, msg_time2=%@, luid=%@", groupId, msgTime2, luid);
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_MESSAGES
                                                  andAction:ACTION_GROUP_READ_STATS
                                                withNewData:newDataDict
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess && returnValue != nil && returnValue.length > 0) {
            NSData *jsonData = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            
            if ([result isKindOfClass:[NSDictionary class]]) {
                NSNumber *code = result[@"code"];
                if (code && [code intValue] == 0) {
                    NSLog(@"【HttpRestHelper】群已读统计成功: read=%@, total=%@",
                          result[@"read_count"], result[@"total_members"]);
                    if (complete) complete(YES, result);
                    return;
                }
            }
        }
        
        NSLog(@"【HttpRestHelper】群已读统计失败: sucess=%d, returnValue=%@", sucess, returnValue);
        if (complete) complete(NO, nil);
    } hudParentView:nil];
}

// ========================== 收藏功能 ==========================

// 【接口1008-27-7】添加收藏
- (void)submitAddFavoriteToServer:(NSString *)userUid
                          favType:(int)favType
                          content:(NSString *)content
                sourceFingerprint:(NSString *)sourceFingerprint
                   sourceChatType:(int)sourceChatType
                    sourceFromUid:(NSString *)sourceFromUid
               sourceFromNickname:(NSString *)sourceFromNickname
                             memo:(NSString *)memo
                         complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                    hudParentView:(UIView *)view
{
    NSMutableDictionary *newData = [NSMutableDictionary dictionary];
    newData[@"user_uid"] = userUid;
    newData[@"fav_type"] = @(favType);
    newData[@"content"] = content ?: @"";
    if (sourceFingerprint) newData[@"source_fingerprint"] = sourceFingerprint;
    newData[@"source_chat_type"] = @(sourceChatType);
    if (sourceFromUid) newData[@"source_from_uid"] = sourceFromUid;
    if (sourceFromNickname) newData[@"source_from_nickname"] = sourceFromNickname;
    newData[@"memo"] = memo ?: @"";
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_FAVORITES
                                                  andAction:ACTION_APPEND1
                                                withNewData:newData
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1008-27-8】删除收藏（批量）
- (void)submitDeleteFavoritesToServer:(NSString *)userUid
                                  ids:(NSString *)ids
                             complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                        hudParentView:(UIView *)view
{
    NSDictionary *newData = @{@"user_uid": userUid, @"ids": ids};
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_FAVORITES
                                                  andAction:ACTION_APPEND2
                                                withNewData:newData
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1008-27-9】查询收藏列表（分页）
- (void)submitGetFavoritesFromServer:(NSString *)userUid
                                page:(int)page
                            pageSize:(int)pageSize
                             favType:(int)favType
                            complete:(void (^)(BOOL sucess, NSDictionary *result))complete
                       hudParentView:(UIView *)view
{
    NSDictionary *newData = @{
        @"user_uid": userUid,
        @"page": @(page),
        @"page_size": @(pageSize),
        @"fav_type": @(favType)
    };
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_FAVORITES
                                                  andAction:ACTION_APPEND3
                                                withNewData:newData
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess && returnValue != nil) {
            NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];
            if ([dict isKindOfClass:[NSDictionary class]]) {
                complete(YES, dict);
            } else {
                complete(YES, @{@"total": @0, @"page": @(page), @"page_size": @(pageSize), @"list": @[]});
            }
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1008-27-22】修改收藏备注
- (void)submitModifyFavoriteMemoToServer:(NSString *)userUid
                                   favId:(NSString *)favId
                                    memo:(NSString *)memo
                                complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                           hudParentView:(UIView *)view
{
    NSDictionary *newData = @{@"user_uid": userUid, @"id": favId, @"memo": memo ?: @""};
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_FAVORITES
                                                  andAction:ACTION_APPEND4
                                                withNewData:newData
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}


// ========================== 黑名单管理 ==========================

// 【接口1008-2-27】拉黑用户
- (void)submitBlockUserToServer:(NSString *)userUid
                     blockedUid:(NSString *)blockedUid
                       complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                  hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_ROSTER
                                                  andAction:ACTION_APPEND9
                                                withNewData:@{@"user_uid": userUid, @"blocked_uid": blockedUid}
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1008-2-28】取消拉黑
- (void)submitUnblockUserToServer:(NSString *)userUid
                       blockedUid:(NSString *)blockedUid
                         complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                    hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_ROSTER
                                                  andAction:ACTION_APPEND10
                                                withNewData:@{@"user_uid": userUid, @"blocked_uid": blockedUid}
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) {
            complete(YES, returnValue);
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1008-2-30】星标好友
- (void)submitStarFriendToServer:(NSString *)userUid friendUid:(NSString *)friendUserUid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    NSDictionary *newData = @{@"user_uid": userUid ?: @"", @"friend_user_uid": friendUserUid ?: @""};
    NSString *jsonStr = [EVAToolKits toJSON:newData] ?: @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_ROSTER
                                                  andAction:30
                                                withNewData:jsonStr
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) complete(YES, returnValue);
        else complete(NO, nil);
    } hudParentView:view];
}

// 【接口1008-2-31】取消星标好友
- (void)submitUnstarFriendToServer:(NSString *)userUid friendUid:(NSString *)friendUserUid complete:(void (^)(BOOL sucess, NSString *resultCode))complete hudParentView:(UIView *)view
{
    NSDictionary *newData = @{@"user_uid": userUid ?: @"", @"friend_user_uid": friendUserUid ?: @""};
    NSString *jsonStr = [EVAToolKits toJSON:newData] ?: @"{}";
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_ROSTER
                                                  andAction:31
                                                withNewData:jsonStr
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess) complete(YES, returnValue);
        else complete(NO, nil);
    } hudParentView:view];
}

#pragma mark - 自定义表情包功能（jobDispatchId = 28）

// 【接口1008-28-7】查询自定义表情列表
- (void)submitGetStickersFromServer:(NSString *)userUid
                           complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *stickerList))complete
                      hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_STICKER
                                                  andAction:ACTION_APPEND1
                                                withNewData:userUid
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess && returnValue != nil) {
            NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            NSArray *arr = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];
            if ([arr isKindOfClass:[NSArray class]]) {
                complete(YES, arr);
            } else {
                complete(YES, @[]);
            }
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}

// 【接口1008-28-8】删除自定义表情（批量）
- (void)submitDeleteStickersToServer:(NSString *)userUid
                                 ids:(NSString *)ids
                            complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                       hudParentView:(UIView *)view
{
    NSDictionary *newDataDict = @{
        @"user_uid": userUid,
        @"ids": ids
    };
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_STICKER
                                                  andAction:ACTION_APPEND2
                                                withNewData:newDataDict
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        complete(sucess, returnValue);
    } hudParentView:view];
}

// 【接口1008-28-9】调整自定义表情排序
- (void)submitSortStickerToServer:(NSString *)userUid
                        stickerId:(NSString *)stickerId
                        sortOrder:(int)sortOrder
                         complete:(void (^)(BOOL sucess, NSString *resultCode))complete
                    hudParentView:(UIView *)view
{
    NSDictionary *newDataDict = @{
        @"user_uid": userUid,
        @"id": stickerId,
        @"sort_order": @(sortOrder)
    };
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_STICKER
                                                  andAction:ACTION_APPEND3
                                                withNewData:newDataDict
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        complete(sucess, returnValue);
    } hudParentView:view];
}

// 上传自定义表情图片（HTTP Multipart）
- (void)uploadStickerToServer:(NSString *)userUid
                     fileName:(NSString *)fileName
                    imageData:(NSData *)imageData
                     complete:(void (^)(BOOL success))complete
{
    NSString *uploadUrl = STICKER_UPLOADER_CONTROLLER_URL_ROOT;
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer.timeoutInterval = 20.0f;
    
    if ([EVAToolKits isHttps:uploadUrl]) {
        [EVAToolKits setupHttps:manager];
    }
    [EVAToolKits setupAuthorization:manager];
    
    // 服务端返回的不是JSON，而是空字符串或错误文本
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    NSDictionary *params = @{
        @"user_uid": userUid,
        @"file_name": fileName
    };
    
    [manager POST:uploadUrl parameters:params headers:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        NSString *mimeType = @"image/png";
        if ([fileName hasSuffix:@".gif"]) {
            mimeType = @"image/gif";
        } else if ([fileName hasSuffix:@".webp"]) {
            mimeType = @"image/webp";
        }
        [formData appendPartWithFileData:imageData name:@"file" fileName:fileName mimeType:mimeType];
    } progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        complete(YES);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        DDLogError(@"表情上传失败: %@", error);
        complete(NO);
    }];
}

// 【接口1008-2-29】查询黑名单列表
- (void)submitGetBlacklistFromServer:(NSString *)userUid
                            complete:(void (^)(BOOL sucess, NSArray<NSDictionary *> *blacklist))complete
                       hudParentView:(UIView *)view
{
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_LOGIC
                                                andDispatch:JOB_LOGIC_ROSTER
                                                  andAction:ACTION_APPEND11
                                                withNewData:userUid
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        if (sucess && returnValue != nil) {
            NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            NSArray *arr = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];
            if ([arr isKindOfClass:[NSArray class]]) {
                complete(YES, arr);
            } else {
                complete(YES, @[]);
            }
        } else {
            complete(NO, nil);
        }
    } hudParentView:view];
}


// ========================== 大群消息（读扩散） ==========================

// 【接口1016-25-25 v2】拉取大群消息（读扩散模式）
- (void)submitFetchLargeGroupMessagesFromServer:(NSString *)gid
                                        fromSeq:(long long)fromSeq
                                          limit:(int)limit
                                      direction:(NSString * _Nullable)direction
                                       complete:(void (^)(BOOL success, NSArray<NSDictionary *> * _Nullable messages, BOOL hasMore))complete
                                  hudParentView:(UIView * _Nullable)view
{
    NSLog(@"【HttpRestHelper】大群消息拉取请求: gid=%@, from_seq=%lld, limit=%d, direction=%@", gid, fromSeq, limit, direction);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"g_id"    : gid ?: @"",
        @"from_seq": @(fromSeq),
        @"limit"   : @(limit > 0 ? limit : 200)
    }];
    if (direction && direction.length > 0) {
        params[@"direction"] = direction;
    }
    
    [[HttpServiceFactory getDefaultService] sendObjToServer:PROCESSOR_GROUP_CHAT
                                                andDispatch:LOGIC_GROUP_QUERY_MGR
                                                  andAction:ACTION_APPEND7
                                                withNewData:params
                                                   complete:^(BOOL sucess, NSString *returnValue) {
        NSLog(@"【HttpRestHelper】大群消息拉取响应: sucess=%d, returnValue长度=%lu, 前300字符=%@",
              sucess,
              (unsigned long)(returnValue ? returnValue.length : 0),
              returnValue.length > 300 ? [returnValue substringToIndex:300] : returnValue);
        
        if (sucess && returnValue != nil && returnValue.length > 0) {
            NSData *rdata = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
            NSError *jsonError = nil;
            id parsed = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:&jsonError];
            
            if (jsonError) {
                NSLog(@"【HttpRestHelper】大群消息 JSON 解析失败: %@", jsonError);
                if (complete) complete(NO, nil, NO);
                return;
            }
            
            // v2 返回格式: {"messages":[...], "has_more":true, "count":200}
            // 同时兼容 v1 直接返回数组 [...]
            NSArray *arr = nil;
            BOOL hasMore = NO;
            
            if ([parsed isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dict = (NSDictionary *)parsed;
                NSLog(@"【HttpRestHelper】大群消息返回字典: keys=%@", dict.allKeys);
                
                id messagesField = dict[@"messages"];
                if ([messagesField isKindOfClass:[NSArray class]]) {
                    arr = (NSArray *)messagesField;
                }
                hasMore = [dict[@"has_more"] boolValue];
                
            } else if ([parsed isKindOfClass:[NSArray class]]) {
                // 兼容 v1：直接返回数组
                arr = (NSArray *)parsed;
                hasMore = NO;
            }
            
            if (arr != nil) {
                NSLog(@"【HttpRestHelper】大群消息解析成功: 共 %lu 条, hasMore=%d", (unsigned long)arr.count, hasMore);
                if (complete) complete(YES, arr, hasMore);
            } else {
                NSLog(@"【HttpRestHelper】大群消息解析失败: 返回数据格式异常, 类型=%@", NSStringFromClass([parsed class]));
                if (complete) complete(NO, nil, NO);
            }
        } else {
            NSLog(@"【HttpRestHelper】大群消息拉取无数据或失败: sucess=%d", sucess);
            if (complete) complete(sucess, @[], NO);
        }
    } hudParentView:view];
}

@end
