//telegram @wz662


#import <Foundation/Foundation.h>
#import "FaceMeta.h"

NS_ASSUME_NONNULL_BEGIN

@interface EmojiUtil : NSObject


+ (NSMutableAttributedString *)replaceEmojiWithPlanString:(NSString *)planString attributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes;

+ (NSMutableAttributedString *)replaceEmojiWithAttributedString:(NSAttributedString *)attributedString attributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes;

+ (NSString *)plainStringWith:(nonnull UITextView *)textView;

+ (NSString *)plainStringWith:(NSAttributedString *)attributedString range:(NSRange)range;


@end

NS_ASSUME_NONNULL_END
