//telegram @wz662
#import "EVACharsetHelper.h"
#import "rbRMMapper.h"

@implementation EVACharsetHelper

+ (NSString *) getString:(NSData *)data
{
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSData *) getJSONBytesWithDictionary:(NSDictionary *)keyValuesForJASON
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:keyValuesForJASON
                                    options:0 // 使用 NSJSONWritingPrettyPrinted 会在NSLog下打出缩进了的JSON格式，但传到服务端时会带上\n换行符哦
                                      error:&error];
    
    if(error != nil)
        NSLog(@"【IMCORE】将字典对象转成JSON数据时出错了：%@", error);
    return jsonData;
}

+ (NSData *) getJSONBytesWithArray:(NSArray *)array
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:array
                                                       options:0 // 使用 NSJSONWritingPrettyPrinted 会在NSLog下打出缩进了的JSON格式，但传到服务端时会带上\n换行符哦
                                                         error:&error];

    if(error != nil)
        NSLog(@"【IMCORE】将数组对象转成JSON数据时出错了：%@", error);
    return jsonData;
}

+ (NSData *) getJSONBytesWithObjectsArray:(NSArray<id> *)objectsArray
{
    if(objectsArray != nil)
    {
        // 因ios不能直接支持NSArray<对象>形式的数组转json，只能先把数据中的对象转成字典对象后，再转JSON
        NSMutableArray<NSDictionary *> *arrayWithDic = [NSMutableArray array];
        // 将数组中的每个对象转字典后，加入到新的数组中备用
        for(id obj in objectsArray)
        {
            NSDictionary *objToDic = [rbRMMapper dictionaryForObject:obj];
            [arrayWithDic addObject:objToDic];
        }

        // 开始将转换完成的NSArray<NSDictionary>形式的数组转JSON了！
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:arrayWithDic//array
                                                           options:0 // 使用 NSJSONWritingPrettyPrinted 会在NSLog下打出缩进了的JSON格式，但传到服务端时会带上\n换行符哦
                                                             error:&error];

        if(error != nil)
            NSLog(@"【IMCORE】将数组对象转成JSON数据时出错了：%@", error);
        return jsonData;
    }
    else
        return nil;
}



+ (NSData *) getBytesWithString:(NSString *)str
{
    return [str dataUsingEncoding:NSUTF8StringEncoding];
}

@end
