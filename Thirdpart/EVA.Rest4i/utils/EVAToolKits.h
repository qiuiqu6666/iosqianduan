//telegram @wz662
#import <Foundation/Foundation.h>
#import "AFHTTPSessionManager.h"

/*!
 * 实用工具类。
 *
 * @author Jack Jiang, 2014-10-22
 * @version 1.0
 */
@interface EVAToolKits : NSObject


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 其它实用方法
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 对AF3进行的Authorization字段支持的设置。
 
 @param manager AFURLSessionManager对象
 */
+ (void) setupAuthorization:(AFHTTPSessionManager *)manager;

/**
对AF3进行的https支持的设置。

@param manager AFURLSessionManager对象
*/
+ (void) setupHttps:(AFURLSessionManager *)manager;

/**
 指定的http url地址是否是Https协议。

 @param httpFullURL http地址
 @return YES表示是https协议，否则是普通的http
 */
+ (BOOL)isHttps:(NSString *)httpFullURL;

/**
 指定对象是否是字符串。

 @param obj 对象实例
 @return YES表示是，否则不是
 */
+ (BOOL)isString:(id)obj;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - JSON转换相关方法
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
* 一个将JSON文本转成DTO数据内容对象的公开方法.
*
* @param anyObj 一个可以转JSON的数据传输对象
* @retrun 转成JSON后的字符串
* @see getBytesWithString:
* @see fromJSONBytesToDictionary:
* @see fromDictionaryToObject:
*/
+ (id) fromJSON:(NSString *)objWithJSON withClazz:(Class)clazz;

/*
 * 一个将DTO数据内容对象转成JSON文本的的公开方法。
 * 重要说明：本方法不支持形如NSArray<id>，如需支持请使用“toJSONForObjectsArray:” 方法，原因是
 *         ios转json的能力很弱，标准的方法针对数组，是不能直接将NSArray<id>形式的对象数据弄JSON的。
 *
 * @param anyObj 一个可以转JSON的数据传输对象，因目前找到的JSON转换库能力有限，目前本对象仅支
 *               持扁平对象、NSData、NSDictionary类（及其子类）、NSArray类（及其子类），NSArray<NSArray>类（及其子类）的嵌套多维数组对象
 * @retrun 转成JSON后的字符串
 * @see toMutableDictionary:
 * @see toJSONBytesWithDictionary:
 * @see toJSONString:
 */
+ (NSString *) toJSON:(id)anyObj;

/*
 * 一个将对象数组转成JSON文本的的公开方法(对象数组形如：NSArray<id>).
 * 重要说明：除对象数组转JSON外，其它转json的时请使用方法“toJSON:”。
 *
 * @param objectsArray 对象数组形如：NSArray<id>
 * @retrun 转成JSON后的字符串
 * @see toMutableDictionary:
 * @see toJSONBytesWithDictionary:
 * @see toJSONString:
 */
+ (NSString *) toJSONForObjectsArray:(NSArray<id> *)objectsArray;

/*!
 * 将2进制数数据形式的字典对象转换成JSON字符串.
 *
 * @return
 * @see toBytes:
 */
+ (NSString *) toJSONString:(NSData *)datas;

/*!
 * 将字典对象转换成JSON表示的byte数组（以便网络传输）.
 *
 * @return
 * @see toMutableDictionary:
 * @see toGsonString:
 */
+ (NSData *) toJSONBytesWithDictionary:(NSDictionary *)dic;

/*!
 * 将数组对象转换成JSON表示的byte数组（以便网络传输），支持1维数组NSArray、2维数组NSArray<NSArray>等嵌套数组形式.
 * 重要说明：本方法不支持形如NSArray<id>，如需支持请使用“toJSONBytesWithObjectsArray:” 方法，原因是
 *         ios转json的能力很弱，标准的方法针对数组，是不能直接将NSArray<id>形式的对象数据弄JSON的。
 *
 * @return
 */
+ (NSData *) toJSONBytesWithArray:(NSArray *)array;

/*!
 * 将数组对象转换成JSON表示的byte数组（以便网络传输），仅支持NSArray<id>对象数组形式.
 * 原因是ios转json的能力很弱，标准的方法针对数组，是不能直接将NSArray<id>形式的对象数据弄JSON的，
 * 所以不能直接调用“toJSONBytesWithArray:“方法来实现。
 *
 * @return
 */
+ (NSData *) toJSONBytesWithObjectsArray:(NSArray<id> *)array;

/*!
 * 将指定对象序列化成NSMutableDictionary。
 *
 * @param obj
 * @return 成功则返回，否则返回nil
 */
+ (NSMutableDictionary *) toMutableDictionary:(id)obj;

/*!
 * 将JSON格式的byte数组转成NSDictionary.
 * 本方法是 toJSONBytesWithDictionary:的逆方法.
 *
 * @param jsonBytes SON格式的byte数组
 * @return 转换成功则返回，否则返回nil
 * @see toJSONBytesWithDictionary:
 */
+ (NSDictionary *) fromJSONBytesToDictionary:(NSData *)jsonBytes;

/*!
 * 将Dictionary描述的Key-values数据反序列化成对象.
 *
 * @param dic key-values
 * @param clazz 要反射的类
 * @return 成功则返回反序列完成的对象，否则返回nil
 */
+ (id) fromDictionaryToObject:(NSDictionary *)dic withClass:(Class)clazz;


@end
