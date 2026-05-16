//telegram @wz662

#import "EmojiUtil.h"
#import "EmojiTextAttachment.h"
#import "FaceDataProvider.h"
#import "IMClientManager.h"

@implementation EmojiUtil

+ (NSMutableAttributedString *)replaceEmojiWithPlanString:(NSString *)planString attributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes {
    if (!planString) return nil;
    if (planString.length == 0) {
        return [[NSMutableAttributedString alloc] initWithString:@"" attributes:attributes];
    }
    NSAttributedString *attStr = [[NSAttributedString alloc] initWithString:planString attributes:attributes];
    return [self replaceEmojiWithAttributedString:attStr attributes:attributes];
}

+ (NSMutableAttributedString *)replaceEmojiWithAttributedString:(NSAttributedString *)attributedString attributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes {
    if (attributedString.length == 0) {
        return nil;
    }
    NSMutableAttributedString *targetAttStr = [[NSMutableAttributedString alloc] initWithAttributedString:attributedString];
    if (attributes) {
        [targetAttStr addAttributes:attributes range:NSMakeRange(0, attributedString.length)];
    }
    NSString *plain = attributedString.string ?: @"";
    if ([plain rangeOfString:@"[/"].location == NSNotFound && [plain rangeOfString:@"［／"].location == NSNotFound) {
        return targetAttStr;
    }
    static NSRegularExpression *regExp = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        NSString *pattern = @"\\[/[^\\]]+\\]|［／[^］]+］";
        regExp = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    });
    if (regExp != nil) {
        NSArray *resultArr = [regExp matchesInString:plain options:0 range:NSMakeRange(0, attributedString.length)];
        UIFont *font = attributes[NSFontAttributeName];
        NSUInteger base = 0;
        FaceDataProvider *faceProvider = [[IMClientManager sharedInstance] getFaceDataProvider];
        for (NSTextCheckingResult *result in resultArr) {
            NSAttributedString *emojStr = [attributedString attributedSubstringFromRange:result.range];
            NSString *emojKey = emojStr.string;
            // 全角匹配到的需转成半角 key 再查表（face_data 里是半角 [/xxx]）
            if ([emojKey hasPrefix:@"［／"] && [emojKey hasSuffix:@"］"]) {
                emojKey = [[@"[/" stringByAppendingString:[emojKey substringWithRange:NSMakeRange(2, emojKey.length - 3)]] stringByAppendingString:@"]"];
            }
            FaceMeta *emoji = [faceProvider getFaceWithDesc:emojKey];
            if (emoji) {
                EmojiTextAttachment *attachment = [EmojiTextAttachment attachmentWith:emoji font:font];
                NSAttributedString *tempAttributedStr = [NSAttributedString attributedStringWithAttachment:attachment];
                [targetAttStr replaceCharactersInRange:NSMakeRange(result.range.location - base, result.range.length) withAttributedString:tempAttributedStr];
                base = base + emojStr.length - tempAttributedStr.length;
            }
        }
    }
    return targetAttStr;
}

+ (NSString *)plainStringWith:(nonnull UITextView *)textView {
    NSMutableString *planString = [textView.textStorage.string mutableCopy];
    __block NSUInteger base = 0;
    [textView.textStorage enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, textView.textStorage.length) options:0 usingBlock:^(EmojiTextAttachment * _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        if (value && [value isKindOfClass:[EmojiTextAttachment class]]) {
            [planString replaceCharactersInRange:NSMakeRange(range.location + base, range.length) withString:value.desc];
            base = base + value.desc.length - 1;
        }
    }];
    return planString;
}

+ (NSString *)plainStringWith:(NSAttributedString *)attributedString range:(NSRange)range {
    NSMutableString *planString = [[NSMutableString alloc] init];
    if (range.length == 0) {
        return planString;
    }
    NSString *string = attributedString.string;
    [attributedString enumerateAttribute:NSAttachmentAttributeName inRange:range options:kNilOptions usingBlock:^(EmojiTextAttachment *value, NSRange range, BOOL *stop) {
        if (value && [value isKindOfClass:[EmojiTextAttachment class]]) {
            [planString appendString:value.desc];
        } else {
            [planString appendString:[string substringWithRange:range]];
        }
    }];
    return planString;
}





@end
