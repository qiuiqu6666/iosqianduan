//telegram @wz662

#import "FaceMeta.h"
#import "FaceDataProvider.h"

@implementation FaceMeta

- (instancetype)initWithDict:(NSDictionary *)dict {
    if (self = [super init]) {
        self.imageName = dict[@"fileName"];
        self.desc = dict[@"desc"];
        NSString *sourcePath = [[FaceDataProvider faceBundle] pathForResource:@"emoji" ofType:nil]; // 表情分类文件夹路径
        NSString *imagePath = [sourcePath stringByAppendingPathComponent:self.imageName];//表情文件路径
        self.image = [UIImage imageWithContentsOfFile:imagePath];
    }
    return self;
}

@end
