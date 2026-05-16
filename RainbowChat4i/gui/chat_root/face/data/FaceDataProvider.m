//telegram @wz662

#import "FaceDataProvider.h"
#import "EmojiUtil.h"

@interface FaceDataProvider ()

@property (strong, nonatomic) NSMutableArrayObservableEx *sFaceData;

@end

@implementation FaceDataProvider

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.sFaceData = [[NSMutableArrayObservableEx alloc] init];
        [self LoadFaceDataFromBundle];
    }
    return self;
}

- (void)putFaces:(NSArray<FaceMeta *> *)newDatas
{
    // 批量数据插入时先不更新ui（防止浪费性能）Freeman注: 注意：putDataList方法会先清空原有数据！！！
    [self.sFaceData putDataList:newDatas needNotify:NO];
    
    FaceMeta *lastFaceMeta = nil;
    if([[self.sFaceData getDataList] count] > 0)
    {
        // 取出最后一个数据单元
        lastFaceMeta = (FaceMeta *)[[self.sFaceData getDataList] objectAtIndex:([[self.sFaceData getDataList] count] - 1)];
    }
    
    // 数据全部插完后再更新UI
    [self.sFaceData notifyObservers:UpdateTypeToObserverUNKNOW
                         whithExtra:lastFaceMeta];// 用最后一个数据单元来通知观察者哦（观察者会不会使用这个data那是它的事）
}

- (NSMutableArrayObservableEx *)getFaceData
{
    return self.sFaceData;
}

///> 判断表情包所有key中是否含有相同的字符串(表情)
- (FaceMeta *)getFaceWithDesc:(NSString *)faceDesc {
    FaceMeta *emoji = nil;
    if(self.sFaceData){
        for (FaceMeta *emojiModel in [self.sFaceData getDataList]) {
            if ([faceDesc isEqualToString:emojiModel.desc]) {
                emoji = emojiModel;
                break;
            }
        }
    }
    return emoji;
}

// 表情数据
- (void)LoadFaceDataFromBundle {
    NSMutableArray<FaceMeta *> *faceData = [NSMutableArray array];
    NSBundle *faceBundle = [FaceDataProvider faceBundle];
    NSString *filePath = [faceBundle pathForResource:@"face_data" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
       
    for (NSDictionary *row in array) {
        FaceMeta *emojiModel = [[FaceMeta alloc] initWithDict:row];
        [faceData addObject:emojiModel];
    }
    [self putFaces:faceData];
}

+ (NSBundle*)faceBundle
{
    // 表情包路径
    NSString *faceBundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"FacePackage" ofType:@"bundle"];
    return [NSBundle bundleWithPath:faceBundlePath];
}

@end
