//telegram @wz662
#import <UIKit/UIKit.h>

@interface PhotosCollectionViewCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIImageView *viewImageBg;
@property (weak, nonatomic) IBOutlet UIImageView *viewImage;
@property (weak, nonatomic) IBOutlet UILabel *viewCount;
@property (weak, nonatomic) IBOutlet UILabel *viewSize;

@property (weak, nonatomic) IBOutlet UIButton *btnDel;

+ (UINib *)nib;
+ (NSString *)cellReuseIdentifier;

@end
