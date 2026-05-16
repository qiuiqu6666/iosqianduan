//telegram @wz662

#import <UIKit/UIKit.h>
#import "FaceMeta.h"

NS_ASSUME_NONNULL_BEGIN

@interface EmojiTextAttachment : NSTextAttachment

+ (EmojiTextAttachment *)attachmentWith:(FaceMeta *)emoji font:(UIFont *)font;

@property (nonatomic, copy) NSString *desc;

@property (nonatomic, copy) NSString *imageName;

@end

NS_ASSUME_NONNULL_END
