//telegram @wz662
#import "EVAToolKits.h"
#import "EVACharsetHelper.h"
#import "rbRMMapper.h"
#import "IMClientManager.h"

@implementation EVAToolKits


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 其它实用方法
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// 对AF3进行的Authorization字段支持的设置
+ (void) setupAuthorization:(AFHTTPSessionManager *)manager {
    if(manager != nil) {
        // v7.1版开始，为了规范文件上传token传递规范，统一使用RFC标准的Authorization http头形式传输             
        [manager.requestSerializer setValue:[IMClientManager sharedInstance].localUserInfo.token forHTTPHeaderField:@"Authorization"];
    }
}

// 对AF3进行的https支持的设置
+ (void) setupHttps:(AFURLSessionManager *)manager
{
    if(manager != nil)
    {
        // [针对HTTPS的额外设置]设置非校验证书模式（无证书、不校验的HTTPS）
        manager.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        manager.securityPolicy.allowInvalidCertificates = YES;
        manager.securityPolicy.validatesDomainName=NO;
    }
}

// 指定的http url地址是否是Https协议
+ (BOOL)isHttps:(NSString *)httpFullURL
{
    BOOL ret = NO;

    if(httpFullURL != nil)
    {
        ret = [[httpFullURL lowercaseString] hasPrefix:@"https://"];
    }

    return ret;
}

// 指定对象是否是字符串
+ (BOOL)isString:(id)obj
{
    return obj != nil && [obj isKindOfClass:[NSString class]];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - JSON转换相关方法
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// 一个将JSON文本转成DTO数据内容对象的公开方法.
+ (id) fromJSON:(NSString *)objWithJSON withClazz:(Class)clazz
{
    if(objWithJSON != nil || clazz != nil)
    {
        NSData *objWithBytes = [EVACharsetHelper getBytesWithString:objWithJSON];
        NSDictionary *objWithDic = [EVAToolKits fromJSONBytesToDictionary:objWithBytes];
        // 反射成对象
        return [EVAToolKits fromDictionaryToObject:objWithDic withClass:clazz];
    }
    return nil;
}

// 一个将DTO数据内容对象转成JSON文本的的公开方法
// * 重要说明：本方法不支持形如NSArray<id>，如需支持请使用“toJSONForObjectsArray:” 方法，原因是
// *        ios转json的能力很弱，标准的方法针对数组，是不能直接将NSArray<id>形式的对象数据弄JSON的。
+ (NSString *) toJSON:(id)anyObj
{
    if(anyObj == nil)
        return nil;

    // 本来就是字符串了，那就不需要转了啊
    if([anyObj isKindOfClass:NSString.class])
        return anyObj;
    if([anyObj isKindOfClass:NSDictionary.class])
        return [EVAToolKits toJSONString:[EVAToolKits toJSONBytesWithDictionary:(NSDictionary* )anyObj]];
    else if([anyObj isKindOfClass:NSArray.class])
        return [EVAToolKits toJSONString:[EVAToolKits toJSONBytesWithArray:(NSArray* )anyObj]];
    else if([anyObj isKindOfClass:NSData.class])
        return [EVAToolKits toJSONString:(NSData *)anyObj];
    else
        return [EVAToolKits toJSONString:[EVAToolKits toJSONBytesWithDictionary:[EVAToolKits toMutableDictionary:anyObj]]];
}

// 一个将对象数组转成JSON文本的的公开方法(对象数组形如：NSArray<id>).
// * 重要说明：除对象数组转JSON外，其它转json的时请使用方法“toJSON:”。
+ (NSString *) toJSONForObjectsArray:(NSArray<id> *)objectsArray
{
    return [EVAToolKits toJSONString:[EVAToolKits toJSONBytesWithObjectsArray:objectsArray]];
}

+ (NSString *) toJSONString:(NSData *)datas
{
    if(datas != nil)
    {
        // 将2进制数据转JSON字符串
        NSString *jsonStr = [EVACharsetHelper getString:datas];
        return jsonStr;
    }
    else
        return nil;
}

+ (NSData *) toJSONBytesWithDictionary:(NSDictionary *)dic
{
    if(dic != nil)
    {
        // 再将Dictionary转成JSON的2进制表示
        NSData *jsonData = [EVACharsetHelper getJSONBytesWithDictionary:dic];
        return jsonData;
    }
    else
        return nil;
}

+ (NSData *) toJSONBytesWithArray:(NSArray *)array
{
    if(array != nil)
    {
        // 再将数组转成JSON的2进制表示
        NSData *jsonData = [EVACharsetHelper getJSONBytesWithArray:array];
        return jsonData;
    }
    else
        return nil;
}

+ (NSData *) toJSONBytesWithObjectsArray:(NSArray<id> *)array
{
    if(array != nil)
    {
        // 再将数组转成JSON的2进制表示
        NSData *jsonData = [EVACharsetHelper getJSONBytesWithObjectsArray:array];
        return jsonData;
    }
    else
        return nil;
}

+ (NSMutableDictionary *) toMutableDictionary:(id)obj
{
    if(obj != nil)
    {
        // 对象先转key-values
        NSMutableDictionary *dic = [rbRMMapper mutableDictionaryForObject:obj];
        return dic;
    }
    else
        return nil;
}

+ (NSDictionary *) fromJSONBytesToDictionary:(NSData *)jsonBytes
{
    return jsonBytes != nil ? [NSJSONSerialization JSONObjectWithData:jsonBytes options:0 error:nil] : nil;
}
+ (id) fromDictionaryToObject:(NSDictionary *)dic withClass:(Class)clazz
{
    return (dic == nil || clazz == nil)? nil : [rbRMMapper objectWithClass:clazz fromDictionary:dic];
}


@end
