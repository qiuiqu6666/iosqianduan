//telegram @wz662

#import "EmojiTextAttachment.h"

@implementation EmojiTextAttachment

+ (EmojiTextAttachment *)attachmentWith:(FaceMeta *)emoji font:(UIFont *)font {
    EmojiTextAttachment *attachment = [[EmojiTextAttachment alloc] init];
    attachment.desc = emoji.desc;
    attachment.imageName = emoji.imageName;
    UIFont *effectiveFont = font ?: [UIFont systemFontOfSize:17];
    attachment.bounds = CGRectMake(0, effectiveFont.descender, effectiveFont.lineHeight, effectiveFont.lineHeight);
    attachment.image = emoji.image;
    return attachment;
}


@end
