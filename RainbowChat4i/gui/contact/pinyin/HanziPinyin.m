//telegram @wz662

#import "HanziPinyin.h"
#import "pinyin.h"

// 拼音汉字缓存（用于提升性能，但只缓存已经计算过的且不持久化存储之），key=汉字字符串、value=拼音组字符串
static NSMutableDictionary *pinyinOfHanziCache = nil;

@interface HanziPinyin ()
// 拼音汉字对照表，key=汉字(单字)、value=拼音
@property(nonatomic, strong)NSMutableDictionary *pinyinOfHanzeTable;
@end

@implementation HanziPinyin

+ (BOOL)isChinese:(NSString *)text
{
    NSString *match = @"(^[\u4e00-\u9fa5]+$)";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", match];
    return [predicate evaluateWithObject:text];
}

+ (NSMutableDictionary *)getPinyinOfHanziCache{
    if (pinyinOfHanziCache == nil) {
        pinyinOfHanziCache = [[NSMutableDictionary alloc] init];
    }
    return pinyinOfHanziCache;
}

+ (NSString *)getFirstUpperLetter:(NSString *)hanzi {
    NSString *pinyin = [HanziPinyin pinyinOfHanzi:hanzi];
    return [HanziPinyin getFirstUpperLetterFromPinyin:pinyin];
}

+ (NSString *)getFirstUpperLetterFromPinyin:(NSString *)pinyin {
//    NSString *pinyin = [HanziPinyin pinyinOfHanzi:hanzi];
    if(pinyin != nil && [pinyin length] > 0){
        NSString *firstUpperLetter = [[pinyin substringToIndex:1] uppercaseString];
        if ([firstUpperLetter compare:@"A"] != NSOrderedAscending &&
            [firstUpperLetter compare:@"Z"] != NSOrderedDescending) {
            return firstUpperLetter;
        }
    }
    
    return @"#";
}

/**
 取出汉字对应的拼音。
 
 @param hanzi 汉字字符串
 @return 汉字对应的拼音字符串
 */
+ (NSString *)pinyinOfHanzi:(NSString *)hanzi {
    if (!hanzi) {
        return @"";
    }
    
    NSString *pinYinResult = [[HanziPinyin getPinyinOfHanziCache] objectForKey:hanzi];
    if (pinYinResult) {
        return pinYinResult;
    }
    pinYinResult = [NSString string];
    for (int i = 0; i < hanzi.length; i++) {
        NSString *singlePinyinLetter = nil;
        if ([self isChinese:[hanzi substringWithRange:NSMakeRange(i, 1)]]) {
            singlePinyinLetter = [[NSString stringWithFormat:@"%c", pinyinFirstLetter([hanzi characterAtIndex:i])] uppercaseString];
        }else{
            singlePinyinLetter = [hanzi substringWithRange:NSMakeRange(i, 1)];
        }
        
        pinYinResult = [pinYinResult stringByAppendingString:singlePinyinLetter];
    }
    [[HanziPinyin getPinyinOfHanziCache] setObject:pinYinResult forKey:hanzi];
    return pinYinResult;
}

@end
