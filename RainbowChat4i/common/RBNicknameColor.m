//
//  RBNicknameColor.m
//  RainbowChat4i
//
//  按 uid + chatId 确定性生成昵称颜色，纯前端、多端一致。
//

#import "RBNicknameColor.h"

#define UIColorFromRGB(rgb) \
    [UIColor colorWithRed:((rgb>>16)&0xFF)/255.0f green:((rgb>>8)&0xFF)/255.0f blue:((rgb)&0xFF)/255.0f alpha:1.0f]

static NSUInteger _hashString(NSString *s) {
    if (s.length == 0) return 0;
    NSUInteger h = 31;
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        h = h * 31u + (NSUInteger)c;
    }
    return h;
}

/// 固定调色板（16 个高对比色），保证多端一致
static UIColor * _paletteColorAtIndex(NSUInteger index) {
    static NSArray<UIColor *> *s_palette;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *nameColors = @[
            UIColorFromRGB(0xF44336),
            UIColorFromRGB(0xFF7043),
            UIColorFromRGB(0xFF9800),
            UIColorFromRGB(0xFFC107),
            UIColorFromRGB(0x8BC34A),
            UIColorFromRGB(0x4CAF50),
            UIColorFromRGB(0x009688),
            UIColorFromRGB(0x00BCD4),
            UIColorFromRGB(0x2196F3),
            UIColorFromRGB(0x3F51B5),
            UIColorFromRGB(0x673AB7),
            UIColorFromRGB(0x9C27B0),
            UIColorFromRGB(0xE91E63),
            UIColorFromRGB(0xEC407A),
            UIColorFromRGB(0x795548),
            UIColorFromRGB(0x607D8B),
        ];
        s_palette = nameColors;
    });
    return s_palette[index % s_palette.count];
}

@implementation RBNicknameColor

+ (UIColor *)nicknameColorForUserId:(NSString *)userId chatId:(NSString *)chatId
{
    NSString *combined = [NSString stringWithFormat:@"%@|%@", userId ?: @"", chatId ?: @""];
    NSUInteger h = _hashString(combined);
    return _paletteColorAtIndex(h);
}

@end
