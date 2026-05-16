//telegram @wz662

#import <Foundation/Foundation.h>
#import "FaceMeta.h"

#import "NSMutableArrayObservableEx.h"


@interface FaceDataProvider : NSObject

- (void)putFaces:(NSArray<FaceMeta *> *)newDatas;

- (NSMutableArrayObservableEx *)getFaceData;

- (FaceMeta *)getFaceWithDesc:(NSString *)faceDesc;

+ (NSBundle*)faceBundle;

@end
