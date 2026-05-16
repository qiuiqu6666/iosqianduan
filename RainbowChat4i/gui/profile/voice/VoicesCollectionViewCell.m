//telegram @wz662
#import "VoicesCollectionViewCell.h"

@implementation VoicesCollectionViewCell

- (void)awakeFromNib
{
    [super awakeFromNib];

}

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];
}

+ (NSString *)cellReuseIdentifier
{
    return NSStringFromClass([self class]);
}

@end
