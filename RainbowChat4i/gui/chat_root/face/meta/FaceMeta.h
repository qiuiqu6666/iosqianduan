//telegram @wz662

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FaceMeta : NSObject

@property (nonatomic, copy) NSString *desc;
@property (nonatomic, copy) NSString *imageName;
@property (nonatomic, strong) UIImage *image;

- (instancetype)initWithDict:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
