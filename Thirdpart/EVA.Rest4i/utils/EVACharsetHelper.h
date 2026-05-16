//telegram @wz662
#import <Foundation/Foundation.h>

/*!
 * 数据交互的编解码实现类。
 *
 * @author Jack Jiang, 2014-10-22
 * @version 1.0
 */
@interface EVACharsetHelper : NSObject

/*!
 * 将byte数组按UTF-8编码组织成字符串并返回.
 *
 * @param data
 * @return 成功解码完成则返回字符串，否则返回nil
 */
+ (NSString *) getString:(NSData *)data;

/*!
 * 将key-values的字典对象转换成JSON表示的byte数组（以便网络传输待场景下）.
 *
 * @param keyValuesForJASON
 * @return 如果JSON转换成功则返回JSON表示的byte数组，否则返回nil
 */
+ (NSData *) getJSONBytesWithDictionary:(NSDictionary *)keyValuesForJASON;

/*!
 * 将数组对象转换成JSON表示的byte数组（以便网络传输待场景下），支持1维数组NSArray、2维数组NSArray<NSArray>，
 * 不支持NSArray<id>对象数组形式，如果支持NSArray<id>对象数组形式请使用方法“getJSONBytesWithObjectsArray:”。
 *
 * @param array 数组
 * @return 如果JSON转换成功则返回JSON表示的byte数组，否则返回nil
 */
+ (NSData *) getJSONBytesWithArray:(NSArray *)array;

/*!
 * 将数组对象转换成JSON表示的byte数组（以便网络传输待场景下），仅支持NSArray<id>对象数组形式.
 * 原因是ios转json的能力很弱，标准的方法针对数组，是不能直接将NSArray<id>形式的对象数据弄JSON的，
 * 所以不能直接调用“getJSONBytesWithArray:“方法来实现。
 *
 * @param objectsArray 数组
 * @return 如果JSON转换成功则返回JSON表示的byte数组，否则返回nil
 */
+ (NSData *) getJSONBytesWithObjectsArray:(NSArray<id> *)objectsArray;

/*!
 *  将字符串按UTF-8编码成byte数组。
 *
 *  @param str 字符串
 *
 *  @return 编码后的byte数组结果
 */
+ (NSData *) getBytesWithString:(NSString *)str;

@end
