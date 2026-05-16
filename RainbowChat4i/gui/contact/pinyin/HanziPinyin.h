//telegram @wz662
#import <Foundation/Foundation.h>

@interface HanziPinyin : NSObject

+ (BOOL)isChinese:(NSString *)text;

+ (NSMutableDictionary *)getPinyinOfHanziCache;

+ (NSString *)getFirstUpperLetter:(NSString *)hanzi;
+ (NSString *)getFirstUpperLetterFromPinyin:(NSString *)pinyin;

/**
 取出汉字对应的拼音。
 
 @param hanzi 汉字字符串
 @return 汉字对应的拼音字符串
 */
+ (NSString *)pinyinOfHanzi:(NSString *)hanzi;

@end
